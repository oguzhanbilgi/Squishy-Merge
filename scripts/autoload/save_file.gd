class_name SaveFile
extends RefCounted
## Çökmeye dayanıklı yerel kayıt dosyası (TASK/045.1). Autoload DEĞİL: SaveManager'ın
## tek disk yolu; testler kendi test yollarıyla doğrudan çağırır. Yol, JSON biçimi ve
## şema SaveManager'da — burada yalnız dosya işlemi.
##
## YAZMA (`write_save`): kanonik dosya HİÇBİR ZAMAN yerinde kesilip yeniden yazılmaz.
##   1. Yükün tamamı bellekte; geri okunabilir bir JSON sözlüğü değilse hiçbir şey yazılmaz.
##   2. Aynı klasörde `<kayıt>.tmp`'ye yazılır, kapatılır, BAYT BAYT geri okunup doğrulanır
##      (FileAccess `close` hatası bildirmez — kısa / yarım yazma burada yakalanır).
##   3. Eski kanonik kayıt (varsa) `<kayıt>.bak`'a TAŞINIR (duran bir `.bak`'ın üzerine
##      yalnız GEÇERLİ bir kanonik taşınır; bozuk kanonik kenara alınmaz).
##   4. `.tmp` kanonik ada TAŞINIR — hedef bu anda boştur: her platformda düz bir taşıma.
##   5. `.bak` silinir. Başarıda klasörde yalnız kanonik dosya kalır.
##   Hata: false + push_error (içerik loglanmaz); önceki kanonik kayıt yerinde kalır (4
##   başarısızsa `.bak` geri taşınır), yarım / fazla `.tmp` silinir.
##
## Neden "kenara taşı + yerine taşı", doğrudan "üzerine yeniden adlandır" değil: Godot
## 4.6.3'te `DirAccess.rename` hedef varken Windows'ta hedefi ÖNCE siler, sonra taşır
## (DeleteFileW + MoveFileW — atomik değil); Android / Linux'ta `rename(2)` atomiktir. Bu
## sıra hiçbir platformda atomik üzerine yazmaya güvenmez.
##
## OKUMA (`read_save`, deterministik kurtarma — geçerli = okunabilir + JSON sözlüğü):
##   1. Kanonik geçerliyse O KAZANIR; artık `.tmp` / `.bak` silinir (yarım kalmış bir
##      işlemin taahhüt edilmemiş yeni kaydı da olsa).
##   2. Kanonik yok / bozuksa geçerli `.tmp`: yer değiştirme anında kesilen işlemin
##      doğrulanmış YENİ kaydı (yalnız 3 ile 4 arasında kalabilir) → kanonik ada taşınır.
##   3. Değilse geçerli `.bak`: son tamamlanmış kayıt → kanonik ada taşınır.
##   4. Hiçbiri: kurtarılacak kayıt yok (çağıran karar verir: kanonik dosya hiç yoksa yeni
##      oyuncu, varsa bozuk kayıt → varsayılanlar — TASK/045.1 öncesi davranış). Geçersiz
##      `.tmp` / `.bak` silinir; bozuk kanonik dosyaya DOKUNULMAZ.
##
## SINIR: Godot 4.6 FileAccess fsync sunmuyor (`flush` = fflush). İşlem süreç çökmesine /
## öldürülmesine / yazma hatasına karşı tutarlıdır; ani güç kaybında kalıcılık işletim
## sistemine / dosya sistemine bağlıdır.

const TEMP_SUFFIX: String = ".tmp"
const BACKUP_SUFFIX: String = ".bak"

## `read_save` sonucu: kayıt nereden okundu.
enum Source { NONE, CANONICAL, TEMP, BACKUP }

## YALNIZ testler: bir sonraki `write_save`'in bir aşamasında hata ya da süreç ölümü
## benzetimi (tek atımlık, çağrı başında sıfırlanır). Üretimde her zaman NONE.
## CRASH_* aşamaları "süreç orada öldü" gibi temizlik yapmadan döner.
enum Fault {
	NONE,
	TEMP_OPEN,           ## `.tmp` açılamadı
	TEMP_WRITE,          ## `.tmp` yazımı yarıda kaldı (yarım içerik, yazma hatası)
	TEMP_SHORT,          ## `.tmp` sessizce kısa yazıldı (yazma "başarılı") — geri okuma yakalar
	CRASH_AFTER_TEMP,    ## süreç `.tmp` tamamlanınca, eski kayda dokunmadan öldü
	BACKUP_MOVE,         ## eski kayıt `.bak`'a taşınamadı
	CRASH_AFTER_BACKUP,  ## süreç eski kayıt `.bak`'a taşınınca öldü (kanonik ad boş)
	COMMIT,              ## `.tmp` kanonik ada taşınamadı (geri alma çalışır)
	COMMIT_AND_ROLLBACK, ## taşıma da geri alma da başarısız
	CRASH_AFTER_COMMIT,  ## yeni kayıt yerinde, `.bak` silinmeden öldü
}
static var fault: Fault = Fault.NONE
## Son başarısız yazmanın aşaması (teşhis / testler); başarılı yazmada boş.
static var last_error_stage: String = ""


## Yükü kanonik `path`'e çökmeye dayanıklı işlemle yazar. true = yeni kayıt kanonik
## dosyada; false = hiçbir şey taahhüt edilmedi, önceki geçerli kayıt korunuyor.
static func write_save(path: String, text: String) -> bool:
	var injected: Fault = fault
	fault = Fault.NONE
	last_error_stage = ""
	# 1. Bellekteki yük geri okunabilir bir sözlük değilse diske hiç inmez.
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return _fail(path, "payload", ERR_INVALID_DATA)
	var bytes: PackedByteArray = text.to_utf8_buffer()
	var temp: String = path + TEMP_SUFFIX
	var backup: String = path + BACKUP_SUFFIX
	# 2. Yeni kayıt geçici dosyaya; bayt bayt doğrulanır.
	var err: Error = _write_temp(temp, bytes, injected)
	if err != OK:
		_remove(temp)
		return _fail(path, "temp", err)
	if injected == Fault.CRASH_AFTER_TEMP:
		return false
	# 3. Eski kanonik kayıt kenara (varsa). Olmazsa kanonik kayıt yerinde, işlem yok. Duran
	#    bir `.bak` (terfisi olmamış bir kurtarmanın tek iyi kopyası olabilir) yalnız eski
	#    kanonik GEÇERLİYSE ezilir; bozuk kanonik kenara alınmaz, yeni kayıt onun yerine geçer.
	var moved_old: bool = false
	if FileAccess.file_exists(path) and (not FileAccess.file_exists(backup) or _read_dict(path) != null):
		err = ERR_FILE_CANT_WRITE if injected == Fault.BACKUP_MOVE else DirAccess.rename_absolute(path, backup)
		if err != OK:
			_remove(temp)
			return _fail(path, "backup", err)
		moved_old = true
		if injected == Fault.CRASH_AFTER_BACKUP:
			return false
	# 4. Yeni kayıt kanonik ada (hedef boş).
	var commit_fails: bool = injected == Fault.COMMIT or injected == Fault.COMMIT_AND_ROLLBACK
	err = ERR_FILE_CANT_WRITE if commit_fails else DirAccess.rename_absolute(temp, path)
	if err != OK:
		if not moved_old:
			_remove(temp)
		else:
			var back: Error = ERR_FILE_CANT_WRITE if injected == Fault.COMMIT_AND_ROLLBACK \
				else DirAccess.rename_absolute(backup, path)
			if back == OK:
				_remove(temp)
			# Geri alma da olmadıysa `.tmp` (yeni, doğrulanmış) + `.bak` (eski) diskte kalır:
			# `read_save` kurtarır (kural 2). Hiçbiri silinmez.
		return _fail(path, "commit", err)
	if injected == Fault.CRASH_AFTER_COMMIT:
		return true
	# 5. Yeni kayıt yerinde: eski kopya (ve önceki yarım işlemden kalan) gereksiz.
	_remove(backup)
	return true


## Kayıt okuma + kurtarma (başlıktaki kurallar). Dönüş:
##   data             Dictionary ya da null (kurtarılacak kayıt yok)
##   source           Source
##   canonical_exists okumadan ÖNCE kanonik ad dolu muydu (yeni oyuncu / bozuk kayıt ayrımı)
static func read_save(path: String) -> Dictionary:
	var temp: String = path + TEMP_SUFFIX
	var backup: String = path + BACKUP_SUFFIX
	var existed: bool = FileAccess.file_exists(path)
	var source: Source = Source.CANONICAL
	var data: Variant = _read_dict(path)
	if data == null:
		source = Source.TEMP
		data = _read_dict(temp)
	if data == null:
		source = Source.BACKUP
		data = _read_dict(backup)
	if data == null:
		source = Source.NONE
	match source:
		Source.CANONICAL:
			_remove(temp)
			_remove(backup)
		Source.TEMP:
			# Terfi: kanonik ad boşsa düz taşıma, bozuk dosya duruyorsa onun yerine. Olmazsa
			# `.tmp` tek iyi kopya olarak kalır; `.bak` ancak terfi olunca gereksizdir.
			if DirAccess.rename_absolute(temp, path) == OK:
				_remove(backup)
		Source.BACKUP:
			_remove(temp)
			DirAccess.rename_absolute(backup, path)
		Source.NONE:
			_remove(temp)
			_remove(backup)
	return {"data": data, "source": source, "canonical_exists": existed}


static func source_name(source: int) -> String:
	match source:
		Source.CANONICAL:
			return "kanonik"
		Source.TEMP:
			return "geçici (.tmp)"
		Source.BACKUP:
			return "yedek (.bak)"
	return "yok"


# --- İç ------------------------------------------------------------------------

static func _write_temp(temp: String, bytes: PackedByteArray, injected: Fault) -> Error:
	if injected == Fault.TEMP_OPEN:
		return ERR_FILE_CANT_OPEN
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var ok: bool
	match injected:
		Fault.TEMP_WRITE:
			file.store_buffer(bytes.slice(0, int(bytes.size() * 0.5)))
			ok = false
		Fault.TEMP_SHORT:
			ok = file.store_buffer(bytes.slice(0, bytes.size() - 1))
		_:
			ok = file.store_buffer(bytes)
	file.close()
	if not ok:
		return ERR_FILE_CANT_WRITE
	if FileAccess.get_file_as_bytes(temp) != bytes:
		return ERR_FILE_CORRUPT
	return OK


## Geçerli kayıt sözlüğü ya da null (yok / okunamıyor / boş / JSON değil / sözlük değil).
static func _read_dict(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	return json.data


static func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _fail(path: String, stage: String, err: Error) -> bool:
	last_error_stage = stage
	push_error("Kayıt yazılamadı (%s, aşama: %s): %s — önceki kayıt korunuyor." % [path.get_file(), stage,
		error_string(err)])
	return false
