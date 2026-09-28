extends Node
## TASK/045.1 — çökmeye dayanıklı kayıt (SaveFile) + SaveManager entegrasyonu testi. Headless.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: her dosya `user://qa_save_persistence/` altında;
## SaveManager test boyunca oradaki bir yola yönlendirilir (`save_path`) ve sonda geri
## alınır; gerçek kaydın ve kardeş `.tmp` / `.bak` adlarının durumu başta / sonda
## karşılaştırılır.
##
##   godot --headless --audio-driver Dummy --path . res://tools/save_persistence_test.tscn
##
## Kontroller:
##   işlem      ilk kayıt / üzerine kayıt (`.bak` = bir önceki kayıt), tekrarlı kayıt (40),
##              büyük kayıt (~1 MB), Unicode / kaçış karakterleri, bayt-aynı biçim, başarıda
##              `.tmp` YOK, okunamayan yük (JSON değil / sözlük değil / boş) hiç yazılmaz
##   hata       .tmp açılamadı / yarım yazma / sessiz kısa yazma / eski kayıt kenara alınamadı /
##              yerine konamadı (geri alma): false + aşama, önceki kanonik kayıt bayt-aynı,
##              `.tmp` kalmaz, sonraki kayıt normal
##   çökme      .tmp sonrası / .bak sonrası süreç ölümü + taahhüt ve geri alma birlikte başarısız
##              → disk durumu + okuma kuralı
##   çift hata  kurtarılacak tek kopya `.tmp` üzerine yazılmaz (önce terfi; terfi olmazsa
##              kayıt yok); bozuk kanonik duran `.bak`'ı ezmez; önceki kayıt yokken taahhüt
##              hatası yeni kaydı `.tmp`'de bırakır
##   kurtarma   geçerli kanonik kazanır (bayat .tmp silinir, .bak kalır); kanonik yok / bozuk /
##              boş / sözlük değil → geçerli .tmp, sonra geçerli .bak (yalnız kanonik ad dolu ya
##              da .tmp izi varken); bilerek silinmiş kayıt → temiz başlangıç; hiçbiri → NONE
##              (bozuk kanonik dosyaya dokunulmaz); kurtarma sonrası idempotent
##   SaveManager yeni oyuncu (başlangıç hediyesi), şema / biçim aynı, eski kayıt normal
##              yüklenir + TASK/044 göçü yazmasız, TASK/045 XP / başarım / unvan kalıcı,
##              başarısız kayıt önceki kaydı korur + bellek aynı, çökmeden kurtarma, bozuk
##              kanonik → bir önceki kayıt, kurtarılacak yoksa varsayılanlar (yazma yok),
##              kayıt silinince temiz başlangıç
##   sözleşme   SaveManager kanonik kaydı hiç WRITE açmaz; SaveFile'da tek WRITE açılışı
##              geçici dosyada; hata logu içerik taşımaz

const DIR: String = "user://qa_save_persistence"
const PATH: String = DIR + "/save.json"
const TMP: String = PATH + SaveFile.TEMP_SUFFIX
const BAK: String = PATH + SaveFile.BACKUP_SUFFIX
const SECTIONS: int = 5

var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _finished: bool = false
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	await get_tree().process_frame
	_owner_state = _owner_snapshot()
	_saved_data = SaveManager.data.duplicate(true)
	_c("başlangıç: SaveManager gerçek kayıt yolunda, hata enjeksiyonu kapalı",
		SaveManager.save_path == SaveManager.SAVE_PATH and SaveFile.fault == SaveFile.Fault.NONE)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()

	_transaction_basics()
	_fault_injection()
	_recovery_rules()
	_save_manager_integration()
	_contract()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	print("-- temizlik + sahibin kaydı")
	_teardown()
	_c("SaveManager gerçek yola döndü, bellek geri kondu", SaveManager.save_path == SaveManager.SAVE_PATH
		and SaveManager.data == _saved_data)
	_c("test klasörü silindi", not DirAccess.dir_exists_absolute(DIR))
	_c("sahibin gerçek kaydı ve kardeş .tmp / .bak adları DEĞİŞMEDİ", _owner_snapshot() == _owner_state)
	_finished = true
	print("\nSONUC: %d kontrol, %d hata" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _exit_tree() -> void:
	if _finished:
		return
	print("  [FAIL] test SONUC'tan önce ağaçtan çıktı — SaveManager geri alındı")
	_teardown()


func _teardown() -> void:
	SaveFile.fault = SaveFile.Fault.NONE
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- 1) İşlem -------------------------------------------------------------------------------

func _transaction_basics() -> void:
	print("-- işlem: ilk / üzerine / tekrarlı / büyük / Unicode")
	var a: String = _payload({"n": 1, "who": "a"})
	_c("ilk kayıt (dosya yokken) true", SaveFile.write_save(PATH, a))
	_c("ilk kayıt: kanonik bayt-aynı yük, .tmp YOK, önceki kayıt olmadığı için .bak YOK",
		_bytes(PATH) == a.to_utf8_buffer() and _no_artifacts())
	var b: String = _payload({"n": 2, "who": "b", "list": [1, 2, 3]})
	_c("üzerine kayıt true", SaveFile.write_save(PATH, b))
	_c("üzerine kayıt: yeni yük kanonikte, .bak = bir önceki kayıt (a), .tmp YOK", _bytes(PATH) == b.to_utf8_buffer()
		and _bytes(BAK) == a.to_utf8_buffer() and not _exists(TMP))
	var read: Dictionary = SaveFile.read_save(PATH)
	_c("okuma: kanonik kaynak, veri aynı, canonical_exists; .bak'a dokunulmadı", read["source"] == SaveFile.Source.CANONICAL
		and _same(read["data"], JSON.parse_string(b)) and read["canonical_exists"] == true and _bytes(BAK) == a.to_utf8_buffer())
	var repeated_ok: bool = true
	var previous: String = b
	for i in 40:
		var p: String = _payload({"n": 100 + i, "pad": "x".repeat(i * 7)})
		if not SaveFile.write_save(PATH, p) or _bytes(PATH) != p.to_utf8_buffer() \
				or _bytes(BAK) != previous.to_utf8_buffer() or _exists(TMP):
			repeated_ok = false
		previous = p
	_c("tekrarlı kayıt ×40: her adımda kanonik = yeni, .bak = bir önceki, .tmp hiç kalmadı", repeated_ok)

	var big: Dictionary = {"blob": "ğ".repeat(400000), "rows": []}
	for i in 3000:
		(big["rows"] as Array).append({"id": "row_%d" % i, "v": i, "s": "Squishy ✨ %d" % i})
	var big_text: String = _payload(big)
	_c("büyük yük gerçekten büyük (%d bayt > 1 MB)" % big_text.to_utf8_buffer().size(),
		big_text.to_utf8_buffer().size() > 1_000_000)
	_c("büyük kayıt true, bayt-aynı, .tmp YOK", SaveFile.write_save(PATH, big_text)
		and _bytes(PATH) == big_text.to_utf8_buffer() and not _exists(TMP))
	read = SaveFile.read_save(PATH)
	_c("büyük kayıt geri okunur (3000 satır, blob uzunluğu aynı)", read["source"] == SaveFile.Source.CANONICAL
		and (read["data"]["rows"] as Array).size() == 3000 and String(read["data"]["blob"]).length() == 400000)

	var uni: Dictionary = {"tr": "Çağrı ığüşöç İĞÜŞÖÇ", "emoji": "🥟✨💖", "cjk": "饺子", "ar": "مرحبا",
		"quote": "\"tırnak\" \\ ters bölü / eğik", "ctrl": "satır\nsekme\tbitti", "title_id": "hamur_ustasi"}
	var uni_text: String = _payload(uni)
	_c("Unicode kayıt true, bayt-aynı (UTF-8)", SaveFile.write_save(PATH, uni_text)
		and _bytes(PATH) == uni_text.to_utf8_buffer())
	read = SaveFile.read_save(PATH)
	var uni_ok: bool = read["source"] == SaveFile.Source.CANONICAL
	for key in uni:
		uni_ok = uni_ok and String(read["data"].get(key, "")) == String(uni[key])
	_c("Unicode / tırnak / ters bölü / satır sonu alanları birebir geri okundu", uni_ok)
	var raw: PackedByteArray = _bytes(PATH)
	_c("dosya gerçekten UTF-8 çok baytlı (ğ = C4 9F dizisi var)", _has_sequence(raw, PackedByteArray([0xC4, 0x9F])))

	var before: PackedByteArray = _bytes(PATH)
	var bak_before: PackedByteArray = _bytes(BAK)
	var not_dict: bool = SaveFile.write_save(PATH, "[1, 2, 3]")
	_c("JSON dizisi (sözlük değil) yazılmaz: false, aşama payload", not not_dict and SaveFile.last_error_stage == "payload")
	var broken: bool = SaveFile.write_save(PATH, "{\"a\": 1,")
	var empty: bool = SaveFile.write_save(PATH, "")
	_c("bozuk JSON ve boş yük yazılmaz (false)", not broken and not empty)
	_c("okunamayan yükler kanonik kayda / .bak'a dokunmadı, .tmp YOK", _bytes(PATH) == before
		and _bytes(BAK) == bak_before and not _exists(TMP))
	_sections_done += 1


# --- 2) Hata / çökme / çift hata enjeksiyonu --------------------------------------------------

func _fault_injection() -> void:
	print("-- hata enjeksiyonu: önceki kayıt korunur")
	var prev: String = _payload({"gen": "prev", "xp": 5})
	var old: String = _payload({"gen": "old", "xp": 10})
	var new: String = _payload({"gen": "new", "xp": 20})
	var cases: Array = [
		[SaveFile.Fault.TEMP_OPEN, "temp", ".tmp açılamadı", true],
		[SaveFile.Fault.TEMP_WRITE, "temp", ".tmp yazımı yarıda kaldı", true],
		[SaveFile.Fault.TEMP_SHORT, "temp", ".tmp sessizce kısa yazıldı (geri okuma yakaladı)", true],
		[SaveFile.Fault.BACKUP_MOVE, "backup", "eski kayıt kenara alınamadı", true],
		[SaveFile.Fault.COMMIT, "commit", "yeni kayıt yerine konamadı → geri alındı", false],
	]
	for case in cases:
		_reset_with([prev, old])
		SaveFile.fault = case[0]
		var ok: bool = SaveFile.write_save(PATH, new)
		_c("%s: false, aşama '%s', enjeksiyon tek atımlık" % [case[2], case[1]], not ok
			and SaveFile.last_error_stage == case[1] and SaveFile.fault == SaveFile.Fault.NONE)
		# COMMIT: eski kayıt kenara alınıp geri taşındı — daha eski .bak kuşağı düşer, kanonik aynen.
		var bak_ok: bool = _bytes(BAK) == prev.to_utf8_buffer() if case[3] else not _exists(BAK)
		_c("%s: önceki kanonik kayıt bayt-aynı, .tmp YOK, .bak %s" % [case[2], "aynen" if case[3] else "geri taşındı"],
			_bytes(PATH) == old.to_utf8_buffer() and not _exists(TMP) and bak_ok)
		_c("%s: sonraki kayıt normal (takılı durum yok)" % case[2], SaveFile.write_save(PATH, new)
			and _bytes(PATH) == new.to_utf8_buffer() and _bytes(BAK) == old.to_utf8_buffer() and not _exists(TMP))

	print("-- çökme benzetimi: disk durumu + okuma kuralı")
	_reset_with([prev, old])
	SaveFile.fault = SaveFile.Fault.CRASH_AFTER_TEMP
	_c(".tmp sonrası ölüm: kanonik eski, .tmp = yeni (tam), .bak aynen", not SaveFile.write_save(PATH, new)
		and _bytes(PATH) == old.to_utf8_buffer() and _bytes(TMP) == new.to_utf8_buffer() and _bytes(BAK) == prev.to_utf8_buffer())
	var read: Dictionary = SaveFile.read_save(PATH)
	_c("  → yeniden açılış: geçerli kanonik KAZANIR (eski), bayat .tmp silindi, .bak kaldı",
		read["source"] == SaveFile.Source.CANONICAL and _same(read["data"], JSON.parse_string(old))
		and _bytes(PATH) == old.to_utf8_buffer() and not _exists(TMP) and _bytes(BAK) == prev.to_utf8_buffer())

	_reset_with([prev, old])
	SaveFile.fault = SaveFile.Fault.CRASH_AFTER_BACKUP
	_c(".bak sonrası ölüm: kanonik ad BOŞ, .tmp = yeni, .bak = eski", not SaveFile.write_save(PATH, new)
		and not _exists(PATH) and _bytes(TMP) == new.to_utf8_buffer() and _bytes(BAK) == old.to_utf8_buffer())
	read = SaveFile.read_save(PATH)
	_c("  → yeniden açılış: doğrulanmış yeni kayıt (.tmp) kanonik oldu, .bak = eski (bir önceki), .tmp yok",
		read["source"] == SaveFile.Source.TEMP and _same(read["data"], JSON.parse_string(new))
		and _bytes(PATH) == new.to_utf8_buffer() and _bytes(BAK) == old.to_utf8_buffer() and not _exists(TMP)
		and read["canonical_exists"] == false)

	_reset_with([prev, old])
	SaveFile.fault = SaveFile.Fault.COMMIT_AND_ROLLBACK
	var both: bool = SaveFile.write_save(PATH, new)
	_c("taahhüt + geri alma başarısız: false, aşama commit; .tmp (yeni) ve .bak (eski) SİLİNMEDİ", not both
		and SaveFile.last_error_stage == "commit" and not _exists(PATH) and _bytes(TMP) == new.to_utf8_buffer()
		and _bytes(BAK) == old.to_utf8_buffer())
	read = SaveFile.read_save(PATH)
	_c("  → yeniden açılış: .tmp kurtarıldı (kural 2), .bak = eski", read["source"] == SaveFile.Source.TEMP
		and _bytes(PATH) == new.to_utf8_buffer() and _bytes(BAK) == old.to_utf8_buffer() and not _exists(TMP))

	print("-- çift hata: kurtarılacak tek kopya korunur")
	var torn: String = old.substr(0, int(old.length() * 0.5))
	var only: String = _payload({"gen": "only_copy", "xp": 77})
	_state(torn, only, "")
	SaveFile.fault = SaveFile.Fault.COMMIT
	var lost_guard: bool = not SaveFile.write_save(PATH, new)
	read = SaveFile.read_save(PATH)
	_c("bozuk kanonik + tek geçerli .tmp: taahhüt de başarısızsa kurtarılacak kayıt KAYBOLMADI (önce terfi edildi)",
		lost_guard and read["source"] == SaveFile.Source.CANONICAL and _same(read["data"], JSON.parse_string(only)))
	_state(torn, only, "")
	_c("  … hata yokken: kayıt true, kanonik = yeni, .bak = kurtarılan kopya, .tmp yok", SaveFile.write_save(PATH, new)
		and _bytes(PATH) == new.to_utf8_buffer() and _bytes(BAK) == only.to_utf8_buffer() and not _exists(TMP))
	_state(torn, only, "")
	SaveFile.fault = SaveFile.Fault.RECOVER_MOVE
	var refused: bool = not SaveFile.write_save(PATH, new) and SaveFile.last_error_stage == "recover"
	_c("  … tek kopya terfi edilemezse kayıt YAPILMAZ: aşama recover, .tmp ve bozuk kanonik aynen", refused
		and _bytes(TMP) == only.to_utf8_buffer() and _bytes(PATH) == torn.to_utf8_buffer() and not _exists(BAK))
	read = SaveFile.read_save(PATH)
	_c("  … açılış yine o kopyayı kurtarır", read["source"] == SaveFile.Source.TEMP
		and _same(read["data"], JSON.parse_string(only)))

	_state(torn, "", prev)
	_c("bozuk kanonik + geçerli .bak iken kayıt: true, kanonik = yeni, .bak (bir önceki) EZİLMEDİ",
		SaveFile.write_save(PATH, new) and _bytes(PATH) == new.to_utf8_buffer() and _bytes(BAK) == prev.to_utf8_buffer()
		and not _exists(TMP))
	_state(torn, "", prev)
	SaveFile.fault = SaveFile.Fault.COMMIT
	var kept: bool = not SaveFile.write_save(PATH, new) and _bytes(BAK) == prev.to_utf8_buffer()
	read = SaveFile.read_save(PATH)
	_c("  … taahhüt de başarısızsa .bak bozuk kanonikle EZİLMEDİ; açılış .bak'ı kurtarır (varsayılan değil)",
		kept and read["source"] == SaveFile.Source.BACKUP and _same(read["data"], JSON.parse_string(prev)))

	_clean()
	SaveFile.fault = SaveFile.Fault.COMMIT
	_c("önceki kayıt YOKKEN taahhüt hatası: false; doğrulanmış yeni kayıt .tmp'de (tek kopya) kaldı",
		not SaveFile.write_save(PATH, new) and not _exists(PATH) and _bytes(TMP) == new.to_utf8_buffer() and not _exists(BAK))
	read = SaveFile.read_save(PATH)
	_c("  → açılış onu kurtarır (TEMP), veri kaybı yok", read["source"] == SaveFile.Source.TEMP
		and _bytes(PATH) == new.to_utf8_buffer() and not _exists(TMP))
	_clean()
	SaveFile.fault = SaveFile.Fault.TEMP_OPEN
	_c("önceki kayıt YOKKEN .tmp hatası: false, diskte hiçbir şey yok",
		not SaveFile.write_save(PATH, new) and not _exists(PATH) and _no_artifacts())
	_sections_done += 1


# --- 3) Kurtarma kuralları --------------------------------------------------------------------

func _recovery_rules() -> void:
	print("-- kurtarma kuralları (deterministik)")
	var c: String = _payload({"src": "canonical"})
	var t: String = _payload({"src": "temp"})
	var k: String = _payload({"src": "backup"})
	var torn: String = c.substr(0, int(c.length() * 0.5))

	_state(c, t, "")
	var r: Dictionary = SaveFile.read_save(PATH)
	_c("geçerli kanonik + bayat GEÇERLİ .tmp → kanonik kazanır, .tmp silindi, kanonik bayt-aynı",
		_src(r, "canonical") and _bytes(PATH) == c.to_utf8_buffer() and _no_artifacts())
	_state(c, "{\"yarım\": ", "")
	r = SaveFile.read_save(PATH)
	_c("geçerli kanonik + bozuk .tmp → kanonik, .tmp silindi", _src(r, "canonical") and _no_artifacts())
	_state(c, "", k)
	r = SaveFile.read_save(PATH)
	_c("geçerli kanonik + .bak → kanonik; .bak bir önceki kayıt olarak KALDI", _src(r, "canonical")
		and _bytes(BAK) == k.to_utf8_buffer() and not _exists(TMP))
	_state(c, t, k)
	r = SaveFile.read_save(PATH)
	_c("geçerli kanonik + .tmp + .bak → kanonik; .tmp silindi, .bak kaldı", _src(r, "canonical")
		and _bytes(PATH) == c.to_utf8_buffer() and not _exists(TMP) and _bytes(BAK) == k.to_utf8_buffer())

	_state(torn, t, "")
	r = SaveFile.read_save(PATH)
	_c("bozuk (yarım) kanonik + geçerli .tmp → .tmp; kanonik artık .tmp içeriği", _src(r, "temp")
		and _bytes(PATH) == t.to_utf8_buffer() and _no_artifacts() and r["canonical_exists"] == true)
	_state("", t, k)
	r = SaveFile.read_save(PATH)
	_c("kanonik yok + .tmp + .bak → .tmp (daha yeni) kazanır, .bak bir önceki olarak kaldı", _src(r, "temp")
		and _bytes(PATH) == t.to_utf8_buffer() and _bytes(BAK) == k.to_utf8_buffer() and not _exists(TMP))
	_state(torn, "{\"yarım\": ", k)
	r = SaveFile.read_save(PATH)
	_c("bozuk kanonik + bozuk .tmp + geçerli .bak → .bak; bozuk kanonik ve .bak'a dokunulmadı, çöp .tmp silindi",
		_src(r, "backup") and _same(r["data"], JSON.parse_string(k)) and _bytes(PATH) == torn.to_utf8_buffer()
		and _bytes(BAK) == k.to_utf8_buffer() and not _exists(TMP))
	r = SaveFile.read_save(PATH)
	_c("  … sonraki kayda kadar her açılış aynı sonucu verir (deterministik)", _src(r, "backup"))
	_put(PATH, PackedByteArray())
	_put(BAK, k.to_utf8_buffer())
	r = SaveFile.read_save(PATH)
	_c("güç kaybı biçimi: 0 baytlık kanonik + önceki kayıt → .bak kurtarıldı (en kötü bir kayıt geri)",
		_src(r, "backup") and _same(r["data"], JSON.parse_string(k)))
	_state("", "{\"yarım\": ", k)
	r = SaveFile.read_save(PATH)
	_c("güç kaybı biçimi: kanonik ad boş + bozuk .tmp izi + .bak → .bak", _src(r, "backup") and not _exists(TMP))
	_put(PATH, PackedByteArray())
	_put(TMP, t.to_utf8_buffer())
	r = SaveFile.read_save(PATH)
	_c("0 baytlık kanonik + geçerli .tmp → .tmp", _src(r, "temp") and _bytes(PATH) == t.to_utf8_buffer())
	_state("[1, 2]", "", k)
	r = SaveFile.read_save(PATH)
	_c("kanonik geçerli JSON ama sözlük değil → geçersiz sayılır, .bak kurtarıldı", _src(r, "backup"))

	_state("", "", k)
	r = SaveFile.read_save(PATH)
	_c("kanonik ad boş + .tmp izi yok + yalnız .bak → kayıt bilerek silinmiş: temiz başlangıç (NONE), artık .bak silindi",
		_src(r, "none") and r["canonical_exists"] == false and r["data"] == null and _no_artifacts())
	_state("", "{\"yarım\": ", "")
	r = SaveFile.read_save(PATH)
	_c("kanonik yok + bozuk .tmp → NONE, canonical_exists false, çöp .tmp silindi", _src(r, "none")
		and r["canonical_exists"] == false and r["data"] == null and _no_artifacts() and not _exists(PATH))
	_state(torn, "", "")
	r = SaveFile.read_save(PATH)
	_c("bozuk kanonik, kurtarılacak yok → NONE, canonical_exists true, bozuk dosyaya DOKUNULMADI", _src(r, "none")
		and r["canonical_exists"] == true and _bytes(PATH) == torn.to_utf8_buffer())
	_state(torn, "{\"x\"", "garbage")
	r = SaveFile.read_save(PATH)
	_c("hepsi bozuk → NONE; çöp .tmp / .bak silindi, bozuk kanonik aynen", _src(r, "none")
		and _no_artifacts() and _bytes(PATH) == torn.to_utf8_buffer())

	_state(torn, t, "")
	SaveFile.read_save(PATH)
	r = SaveFile.read_save(PATH)
	_c("kurtarma sonrası ikinci okuma: kanonik (idempotent)", _src(r, "canonical") and _bytes(PATH) == t.to_utf8_buffer())
	_sections_done += 1


# --- 4) SaveManager entegrasyonu ------------------------------------------------------------

func _save_manager_integration() -> void:
	print("-- SaveManager (test yoluna yönlendirildi)")
	_clean()
	SaveManager.save_path = PATH
	SaveManager.load_game()
	_c("yeni oyuncu: kaynak NONE, başlangıç hediyesi (her güçten 1), kayıt yazıldı, .tmp / .bak yok",
		SaveManager.load_source() == SaveFile.Source.NONE and SaveManager.powerup_count(PowerUp.Type.BOMB) == 1
		and SaveManager.powerup_count(PowerUp.Type.UPGRADE) == 1 and _exists(PATH) and _no_artifacts())
	var first: PackedByteArray = _bytes(PATH)
	var result: Variant = SaveManager.save_game()
	_c("save_game bool döner (true); .bak = bir önceki kayıt", typeof(result) == TYPE_BOOL and result == true
		and _bytes(BAK) == first and not _exists(TMP))
	_c("biçim aynı: dosya = JSON.stringify(data, sekme) baytları",
		_bytes(PATH) == JSON.stringify(SaveManager.data, "\t").to_utf8_buffer())
	var keys: Array = (JSON.parse_string(FileAccess.get_file_as_string(PATH)) as Dictionary).keys()
	keys.sort()
	var expected: Array = SaveManager.DEFAULT_DATA.keys()
	expected.sort()
	_c("şema aynı: yeni kaydın anahtarları = DEFAULT_DATA anahtarları (%d)" % expected.size(), keys == expected)

	# Eski (TASK/043 dönemi) kayıt: normal yüklenir, TASK/044 + TASK/045 göçleri bellekte.
	var legacy: Dictionary = {"highest_level_unlocked": 4, "level_stars": {"1": 2, "2": 3, "3": 3},
		"endless_high_score": 0, "dough": 335, "total_merges": 120, "merges_since_bonus_chest": 45,
		"powerups": {"bomb": 2, "upgrade": 1, "shake": 0, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "age_ad_band": "ADULT", "unlocked_skins": ["common_01", "rare_02"],
		"equipped_skin": "rare_02"}
	_put(PATH, JSON.stringify(legacy, "\t").to_utf8_buffer())
	var legacy_bytes: PackedByteArray = _bytes(PATH)
	var bak_bytes: PackedByteArray = _bytes(BAK)
	SaveManager.load_game()
	var expected_xp: int = PlayerProgression.bootstrap_xp(120, 8, 3)
	_c("eski kayıt normal yüklendi (kanonik): Hamur 335, level 4, güç stoğu aynı", SaveManager.load_source()
		== SaveFile.Source.CANONICAL and SaveManager.dough() == 335 and SaveManager.highest_level_unlocked() == 4
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == 2)
	_c("TASK/044 göçü: equipped_skin → vitrinin ilk yuvası, anahtar bellekten silindi",
		_showcase_rare02() and not SaveManager.data.has("equipped_skin"))
	_c("TASK/045 göçü: XP bootstrap %d (merge + 10·yıldız + 20·level)" % expected_xp,
		SaveManager.player_xp() == expected_xp)
	_c("yükleme diske YAZMADI (kanonik ve .bak bayt-aynı, .tmp yok)", _bytes(PATH) == legacy_bytes
		and _bytes(BAK) == bak_bytes and not _exists(TMP))

	# TASK/045 durumu kalıcı (unvan seçimi kendi tek yazmasıyla — SaveFile işleminden geçer).
	var achievements: Array[StringName] = SaveManager.unlocked_achievements()
	_c("göç başarımları sessizce açtı (merge_100 dahil, ≥ 4)", achievements.has(&"merge_100") and achievements.size() >= 4)
	SaveManager.data["player_xp"] = 1234
	_c("unvan seçimi (hamur_ustasi) SELECTED — tek yazma; .bak = eski kayıt", SaveManager.select_title(&"hamur_ustasi")
		== SaveManager.TitleResult.SELECTED and _bytes(BAK) == legacy_bytes and not _exists(TMP))
	SaveManager.load_game()
	_c("TASK/045 XP 1234 / başarımlar / unvan hamur_ustasi yeniden yüklemede aynı", SaveManager.player_xp() == 1234
		and SaveManager.unlocked_achievements() == achievements and SaveManager.selected_title_id() == &"hamur_ustasi")
	_c("vitrin (TASK/044) kalıcı kayıtta da aynı", _showcase_rare02()
		and not FileAccess.get_file_as_string(PATH).contains("equipped_skin"))

	# Başarısız kayıt önceki kaydı korur; bellek değişmez; sonraki kayıt yazar.
	var committed: PackedByteArray = _bytes(PATH)
	SaveManager.data["player_xp"] = 2000
	SaveFile.fault = SaveFile.Fault.COMMIT
	var failed: bool = SaveManager.save_game()
	_c("başarısız kayıt: save_game false, kanonik bayt-aynı (XP 1234), .tmp yok", not failed
		and _bytes(PATH) == committed and not _exists(TMP))
	_c("başarısız kayıt belleği değiştirmedi (XP hâlâ 2000)", SaveManager.player_xp() == 2000)
	SaveManager.load_game()
	_c("yeniden açılış: önceki geçerli kayıt (XP 1234) — sıfırlama / varsayılan YOK", SaveManager.player_xp() == 1234
		and SaveManager.dough() == 335 and SaveManager.load_source() == SaveFile.Source.CANONICAL)
	SaveManager.data["player_xp"] = 2000
	_c("sonraki kayıt yazar: XP 2000 kalıcı", SaveManager.save_game() and _xp_in(PATH) == 2000)

	# Süreç yer değiştirme anında öldü → açılış doğrulanmış yeni kaydı kurtarır.
	SaveManager.data["player_xp"] = 3000
	SaveFile.fault = SaveFile.Fault.CRASH_AFTER_BACKUP
	SaveManager.save_game()
	_c("yer değiştirmede ölüm: kanonik ad boş, .tmp + .bak var", not _exists(PATH) and _exists(TMP) and _exists(BAK))
	SaveManager.load_game()
	_c("load_game kurtardı: kaynak TEMP, XP 3000, Hamur 335; kanonik = 3000, .bak = 2000, .tmp yok",
		SaveManager.load_source() == SaveFile.Source.TEMP and SaveManager.player_xp() == 3000
		and SaveManager.dough() == 335 and _xp_in(PATH) == 3000 and _xp_in(BAK) == 2000 and not _exists(TMP))

	# Bozuk kanonik (ör. güç kaybı): bir önceki kayıt; kurtarılacak yoksa varsayılanlar, yazma yok.
	var torn: String = FileAccess.get_file_as_string(PATH).substr(0, 40)
	_put(PATH, torn.to_utf8_buffer())
	SaveManager.load_game()
	_c("bozuk kanonik + .bak: kaynak BACKUP, XP 2000 (bir önceki kayıt), bozuk dosyaya dokunulmadı",
		SaveManager.load_source() == SaveFile.Source.BACKUP and SaveManager.player_xp() == 2000
		and SaveManager.dough() == 335 and _bytes(PATH) == torn.to_utf8_buffer())
	_c("  … sonraki kayıt bozuk kanoniğin yerine geçer (.bak ezilmez)", SaveManager.save_game()
		and SaveFile.read_save(PATH)["source"] == SaveFile.Source.CANONICAL and _xp_in(PATH) == 2000
		and _xp_in(BAK) == 2000 and not _exists(TMP))
	_put(PATH, torn.to_utf8_buffer())
	DirAccess.remove_absolute(BAK)
	SaveManager.load_game()
	_c("bozuk kanonik, kurtarılacak yok: varsayılanlar (XP 0, Hamur 0), kaynak NONE", SaveManager.load_source()
		== SaveFile.Source.NONE and SaveManager.player_xp() == 0 and SaveManager.dough() == 0)
	_c("  … bozuk dosyaya yazılmadı (başlangıç hediyesi kaydı yok — eski davranış)", _bytes(PATH) == torn.to_utf8_buffer())

	# Kayıt bilerek silinirse (geliştirici / test sıfırlaması) duran .bak geri getirilmez.
	SaveManager.data["player_xp"] = 4000
	SaveManager.save_game()
	SaveManager.save_game()
	DirAccess.remove_absolute(PATH)
	_c("ön koşul: kanonik silindi, .bak duruyor", not _exists(PATH) and _exists(BAK) and not _exists(TMP))
	SaveManager.load_game()
	_c("kayıt silinince temiz başlangıç: yeni oyuncu (XP 0, başlangıç hediyesi), artık .bak silindi",
		SaveManager.load_source() == SaveFile.Source.NONE and SaveManager.player_xp() == 0
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == 1 and _exists(PATH) and _no_artifacts())
	_sections_done += 1


# --- 5) Sözleşme (kaynak) ---------------------------------------------------------------------

func _contract() -> void:
	print("-- sözleşme")
	var manager: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/autoload/save_manager.gd"))
	_c("SaveManager kaydı hiç WRITE açmaz; tek yazma SaveFile.write_save, tek okuma SaveFile.read_save",
		not manager.contains("FileAccess.WRITE") and not manager.contains("FileAccess.open(")
		and manager.count("SaveFile.write_save(") == 1 and manager.count("SaveFile.read_save(") == 1)
	_c("SaveManager yolu üretimde SAVE_PATH", manager.contains("var save_path: String = SAVE_PATH"))
	var file_src: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/autoload/save_file.gd"))
	_c("SaveFile'da tek WRITE açılışı ve o da geçici dosyada", file_src.count("FileAccess.WRITE") == 1
		and file_src.contains("FileAccess.open(temp, FileAccess.WRITE)"))
	var fail_fn: String = file_src.substr(file_src.find("static func _fail("))
	_c("hata logu içerik taşımaz (yalnız dosya adı + aşama + hata kodu)", fail_fn.contains("push_error(")
		and not fail_fn.contains("text") and not fail_fn.contains("bytes") and not fail_fn.contains("data"))
	_c("üretimde hata enjeksiyonu kapalı (enum varsayılanı NONE)", file_src.contains("static var fault: Fault = Fault.NONE"))
	_sections_done += 1


# --- Yardımcılar ------------------------------------------------------------------------------

func _payload(d: Dictionary) -> String:
	return JSON.stringify(d, "\t")


## Temiz başlar ve verilen yükleri sırayla kaydeder (son = kanonik, bir önceki = .bak).
func _reset_with(texts: Array) -> void:
	_clean()
	for text in texts:
		SaveFile.write_save(PATH, text)


## Kanonik / .tmp / .bak durumunu doğrudan kurar ("" = dosya yok).
func _state(canonical: String, temp: String, backup: String) -> void:
	_clean()
	if not canonical.is_empty():
		_put(PATH, canonical.to_utf8_buffer())
	if not temp.is_empty():
		_put(TMP, temp.to_utf8_buffer())
	if not backup.is_empty():
		_put(BAK, backup.to_utf8_buffer())


func _put(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _clean() -> void:
	for path in [PATH, TMP, BAK]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func _no_artifacts() -> bool:
	return not _exists(TMP) and not _exists(BAK)


func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


func _showcase_rare02() -> bool:
	var showcase: Array[StringName] = SaveManager.profile_showcase()
	return showcase.size() == 1 and showcase[0] == &"rare_02"


func _xp_in(path: String) -> int:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return int((parsed as Dictionary).get("player_xp", -1)) if parsed is Dictionary else -1


func _src(r: Dictionary, name: String) -> bool:
	var want: int = {"canonical": SaveFile.Source.CANONICAL, "temp": SaveFile.Source.TEMP,
		"backup": SaveFile.Source.BACKUP, "none": SaveFile.Source.NONE}[name]
	return int(r["source"]) == want


func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a) == JSON.stringify(b)


func _has_sequence(haystack: PackedByteArray, needle: PackedByteArray) -> bool:
	for i in haystack.size() - needle.size() + 1:
		if haystack.slice(i, i + needle.size()) == needle:
			return true
	return false


## Gerçek kayıt + kardeş ara dosya adları (varlık + bayt). Test bunlara hiç dokunmamalı.
func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for path in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out


func _strip_comments(code: String) -> String:
	var out: PackedStringArray = []
	for line in code.split("\n"):
		var hash: int = line.find("#")
		out.append(line if hash < 0 else line.substr(0, hash))
	return "\n".join(out)
