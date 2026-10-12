class_name Missions
extends RefCounted
## Günlük / Haftalık Görevler (TASK/046 V1 katalog + TASK/061 V3 elle talep — owner kararı, KİLİTLİ; GAME_DESIGN §5.10)
## — katalog + SAF kural katmanı (gün / hafta anahtarı, doğrulama, dönem, ilerleme, talep, dönem sonu teslimi). Kayda
## YAZMAZ: kalıcılık ve mutasyonlar SaveManager'da (`record_mission_round` round kesinleşmesinde, `claim_mission_reward`
## ÖDÜLÜ AL'da, `settle_missions` dönem geçişinde); okuma kısayolları SaveManager'ın doğrulanmış durumunu kullanır.
##
##   Katalog  6 görev, kalıcı iç id (kayıtta durur — değiştirilmez, yeniden kullanılmaz):
##            GÜNLÜK    daily_merges 15 · daily_rounds 2 · daily_clear 1       → +10 Hamur
##            HAFTALIK  weekly_merges 120 · weekly_rounds 12 · weekly_clears 5 → +40 Hamur
##            En fazla 30 Hamur / gün + 120 Hamur / hafta = haftada 330.
##   Kaynak   YALNIZ kesinleşen round (Main._on_round_finished, round başına tam bir kez):
##            merge = TASK/045 XP'siyle AYNI gerçek merge sayısı (GameState.merge_count);
##            tur = +1 (kazanma / kayıp / sonsuz / tutorial'ın gerçek Level 1 round'u);
##            level = sabit level BAŞARIYLA bitti (tekrar dahil; kayıp ve sonsuz değil).
##            Terk edilen / yeniden başlatılan / yarım kalan round, Büyütücü hiç sayılmaz.
##   Durum    (TASK/061) AKTİF → TAMAMLANDI (ALINABİLİR) → ÖDÜLÜ AL → ALINDI. Hedefe ulaşmak Hamur VERMEZ; tamamlanma
##            ilerlemeden TÜRER (ilerleme == hedef). Ödül yalnız oyuncunun geçerli ÖDÜLÜ AL'ında (`claim`) ya da dönem
##            kapanırken (`rollover`: tamamlanmış + alınmamış ödül TAM BİR KEZ otomatik teslim) verilir; ödül işareti
##            (`*_rewarded` = ödülü VERİLMİŞ id'ler) bir görevin bir dönemde en fazla bir kez ödül vermesini sağlar.
##            XP / sandık / parça / güç / başarım / unvan / reklam YOK.
##   Gün      GÜNLÜK ÖDÜLLER'in kabul edilen günü (`DailyRewards.day_key()`: saat geri
##            alınırsa görülen en yeni gün) — ayrı bir saat gerçeği YOK. Dönem ayrıca
##            kayıttaki dönemin gerisine hiç düşmez: geri alınan saat eski bir dönemi geri
##            getiremez, yeni ödül seti üretemez, tamamlanmış görevi yeniden ödüllendiremez.
##            Saati İLERİ almak çevrimdışı oyunda engellenemez (günlük ödüllerle aynı kabul).
##   Hafta    PAZARTESİ başlar; anahtar o haftanın pazartesi tarihi (`week_start`).
##   Seri     YOK — görev serisi / haftalık seri / çarpan yok (giriş serisi DailyReward'da aynen).

## Kayıttaki görev durumunun şema sürümü (TASK/061: 2). Anahtarlar sürüm 1 ile AYNI; anlam farkı:
##   sürüm 1 (TASK/046, otomatik ödül)  `*_rewarded` = ödülü verilmiş = tamamlanmış görevler; ödülü verilmemiş görev
##                                      hedefe ULAŞAMAZ (ilerleme ≤ hedef − 1 okunur).
##   sürüm 2 (TASK/061, elle talep)     `*_rewarded` aynı anlam (ödül VERİLDİ: ÖDÜLÜ AL ya da dönem sonu teslimi);
##                                      ödülü verilmemiş görev hedefte olabilir = ALINABİLİR.
## Sürüm 1 kaydı sürüm 1 kurallarıyla okunur ve sürüm 2 olarak çıkar (`sanitize`): eski kayıtta kazanılmış bir ödül
## ALINDI kalır, eski kısmi ilerleme aynen AKTİF kalır — hiçbir sürüm 1 kaydı alınabilir görev üretemez.
const VERSION: int = 2
const LEGACY_VERSION: int = 1
const PERIOD_DAILY: StringName = &"daily"
const PERIOD_WEEKLY: StringName = &"weekly"
const METRIC_MERGES: StringName = &"merges"
const METRIC_ROUNDS: StringName = &"rounds"
const METRIC_CLEARS: StringName = &"clears"

## Görev durumu (TASK/061; UI yalnız gösterir, saklanmaz).
const STATUS_ACTIVE: StringName = &"active"
const STATUS_CLAIMABLE: StringName = &"claimable"
const STATUS_CLAIMED: StringName = &"claimed"

## ÖDÜLÜ AL sonucu (`claim`; SaveManager.claim_mission_reward). Yalnız CLAIMED ve AUTO_CLAIMED Hamur verir.
##   CLAIMED         bu talep ödülü verdi (tam katalog ödülü, tek işlem)
##   AUTO_CLAIMED    talep anında dönem kapanmıştı: o görevin ödülü dönem sonu teslimiyle TAM BİR KEZ verildi
##   UNKNOWN         katalogda olmayan id
##   WRONG_PERIOD    gösterilen dönem artık geçerli dönem değil (ve o görev için teslim edilecek ödül yoktu)
##   NOT_COMPLETE    görev hedefe ulaşmadı
##   ALREADY_CLAIMED görev bu dönemde zaten ödül verdi
##   NO_PERIOD       kullanılabilir dönem yok (kayıt yok + bozuk saat)
enum Claim { CLAIMED, AUTO_CLAIMED, UNKNOWN, WRONG_PERIOD, NOT_COMPLETE, ALREADY_CLAIMED, NO_PERIOD }

## Katalog sırası = gösterim sırası = ödül işareti dizilerinin kanonik sırası.
const CATALOG: Array[Dictionary] = [
	{"id": &"daily_merges", "period": PERIOD_DAILY, "metric": METRIC_MERGES, "target": 15, "reward": 10},
	{"id": &"daily_rounds", "period": PERIOD_DAILY, "metric": METRIC_ROUNDS, "target": 2, "reward": 10},
	{"id": &"daily_clear", "period": PERIOD_DAILY, "metric": METRIC_CLEARS, "target": 1, "reward": 10},
	{"id": &"weekly_merges", "period": PERIOD_WEEKLY, "metric": METRIC_MERGES, "target": 120, "reward": 40},
	{"id": &"weekly_rounds", "period": PERIOD_WEEKLY, "metric": METRIC_ROUNDS, "target": 12, "reward": 40},
	{"id": &"weekly_clears", "period": PERIOD_WEEKLY, "metric": METRIC_CLEARS, "target": 5, "reward": 40},
]

## Oyuncu dili — iç id'den AYRI (id kayıtta durur, metin yalnız burada). Projenin tek üretim
## dili Türkçe (yerelleştirme / RTL katmanı yok); sayı hedeften gelir, metin ile hedef ayrışamaz.
const TITLE_FORMATS: Dictionary = {
	METRIC_MERGES: "%d birleşme yap",
	METRIC_ROUNDS: "%d tur tamamla",
	METRIC_CLEARS: "%d level tamamla",
}

## Durum anahtarları (kayıt biçimi).
const KEY_VERSION: String = "version"
const KEY_DAY: String = "day_key"
const KEY_WEEK: String = "week_start_day_key"
const KEY_DAILY_PROGRESS: String = "daily_progress"
const KEY_DAILY_REWARDED: String = "daily_rewarded"
const KEY_WEEKLY_PROGRESS: String = "weekly_progress"
const KEY_WEEKLY_REWARDED: String = "weekly_rewarded"
## Ham ödül işareti dizisinin okunan tavanı (bozuk kayıtta binlerce öğe açılışı kilitlemesin).
const RAW_CAP: int = 32
## Geçerli gün anahtarının en küçük yılı: bundan eski cihaz saati bozuk sayılır (yeni dönem
## açılmaz — bkz. `accepted_day`).
const MIN_YEAR: int = 2000
const SECONDS_PER_DAY: int = 86400


# --- Katalog -----------------------------------------------------------------------

static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in CATALOG:
		out.append(entry["id"])
	return out


static func ids_for(period: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for entry in CATALOG:
		if entry["period"] == period:
			out.append(entry["id"])
	return out


## Katalog girişi; bilinmeyen id boş sözlük.
static func find(id: StringName) -> Dictionary:
	for entry in CATALOG:
		if entry["id"] == id:
			return entry
	return {}


static func is_known(id: StringName) -> bool:
	return not find(id).is_empty()


static func target_of(id: StringName) -> int:
	var entry: Dictionary = find(id)
	return int(entry["target"]) if not entry.is_empty() else 0


static func reward_of(id: StringName) -> int:
	var entry: Dictionary = find(id)
	return int(entry["reward"]) if not entry.is_empty() else 0


## Görünen görev metni ("15 birleşme yap"); bilinmeyen id boş.
static func title(id: StringName) -> String:
	var entry: Dictionary = find(id)
	if entry.is_empty():
		return ""
	return String(TITLE_FORMATS[entry["metric"]]) % int(entry["target"])


## Bir dönemin tüm görevleri bir kez tamamlanınca verilen en fazla Hamur (30 / 120).
static func max_reward(period: StringName) -> int:
	var total: int = 0
	for entry in CATALOG:
		if entry["period"] == period:
			total += int(entry["reward"])
	return total


static func progress_key(period: StringName) -> String:
	return KEY_DAILY_PROGRESS if period == PERIOD_DAILY else KEY_WEEKLY_PROGRESS


static func rewarded_key(period: StringName) -> String:
	return KEY_DAILY_REWARDED if period == PERIOD_DAILY else KEY_WEEKLY_REWARDED


# --- Gün / hafta ---------------------------------------------------------------------

## Görevlerin kabul edilen günü: GÜNLÜK ÖDÜLLER'in günü (`DailyRewards.day_key()` — saat geri
## alma koruması aynen, ayrı saat gerçeği YOK). O anahtar biçim olarak bozuksa (kayıttaki "en
## yeni gün" bozulmuş) cihaz günü; o da geçersizse boş → yeni dönem AÇILMAZ: kayıtlı bir dönem
## varsa round'lar o döneme işlenir (geri alınmış saatle aynı; ödül işaretleri geçerli), yoksa
## görev işlenmez.
static func accepted_day() -> String:
	var key: String = DailyRewards.day_key()
	if is_day_key(key):
		return key
	var today: String = DailyRewards.today_local()
	return today if is_day_key(today) else ""


## "YYYY-MM-DD" biçiminde GERÇEK bir takvim günü mü (2026-02-29 / 2026-13-01 / boş / metin
## olmayan → hayır; yıl MIN_YEAR..9999).
static func is_day_key(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text: String = value
	if text.length() != 10 or text[4] != "-" or text[7] != "-":
		return false
	for i: int in [0, 1, 2, 3, 5, 6, 8, 9]:
		var code: int = text.unicode_at(i)
		if code < 48 or code > 57:
			return false
	var year: int = text.substr(0, 4).to_int()
	var month: int = text.substr(5, 2).to_int()
	var day: int = text.substr(8, 2).to_int()
	if year < MIN_YEAR or month < 1 or month > 12 or day < 1:
		return false
	return day <= _days_in_month(year, month)


static func _days_in_month(year: int, month: int) -> int:
	if month == 2:
		var leap: bool = (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
		return 29 if leap else 28
	return 30 if month in [4, 6, 9, 11] else 31


## Günün haftasının PAZARTESİ tarihi (YYYY-MM-DD); geçersiz günde boş. Takvim tarihi UTC
## gece yarısı olarak çevrilir (saat dilimi / yaz saati kayması yok).
static func week_start(day_key: String) -> String:
	if not is_day_key(day_key):
		return ""
	var unix: int = Time.get_unix_time_from_datetime_string(day_key + "T00:00:00")
	# Godot: 0 = pazar … 6 = cumartesi → pazartesiden bu yana geçen gün.
	var since_monday: int = (int(Time.get_date_dict_from_unix_time(unix)["weekday"]) + 6) % 7
	return Time.get_date_string_from_unix_time(unix - since_monday * SECONDS_PER_DAY)


# --- Durum (SAF) ----------------------------------------------------------------------

## `day_key` gününün taze dönemi: ilerleme 0, ödül işareti yok.
static func fresh_state(day_key: String) -> Dictionary:
	var state: Dictionary = {
		KEY_VERSION: VERSION,
		KEY_DAY: day_key,
		KEY_WEEK: week_start(day_key),
	}
	for period: StringName in [PERIOD_DAILY, PERIOD_WEEKLY]:
		var progress: Dictionary = {}
		for id in ids_for(period):
			progress[String(id)] = 0
		state[progress_key(period)] = progress
		state[rewarded_key(period)] = []
	return state


## Kayıttaki ham görev durumunu güvenli BİÇİME indirir — SAF, deterministik, sınırlı; dönem DEĞİŞTİRMEZ (bkz.
## `rollover`). Çıktı her zaman sürüm 2. Boş sözlük = kullanılabilir dönem yok (anahtar yok / sözlük değil / bilinmeyen
## sürüm / geçersiz gün): okuyan kabul edilen günün taze dönemini kullanır.
##   ödül işareti   yalnız o dönemin bilinen id'leri, tekrarsız, katalog sırası; ödülü verilmiş görev = hedef
##   ilerleme       yalnız katalog görevleri;
##                  sürüm 1 (TASK/046)  ödülü verilmemiş görev ≤ hedef − 1 (sürüm 1'de hedefe ulaşan görev ödülünü
##                                      zaten ALMIŞTI — eski kayıt alınabilir görev ÜRETEMEZ); sayı değil / NaN → 0
##                  sürüm 2 (TASK/061)  ödülü verilmemiş görev 0..hedef; aralık DIŞI (negatif / hedeften büyük / NaN /
##                                      ±sonsuz / sayı değil) → 0 — bozuk değer asla alınabilir görev olmaz (fail-closed)
##   hafta          kayıttaki hafta günün pazartesisi değilse (kendi kodumuz üretmez — bozuk) haftalık kısım taze kalır
static func sanitize(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var src: Dictionary = raw
	var legacy: bool = _is_version(src.get(KEY_VERSION), LEGACY_VERSION)
	if not legacy and not _is_version(src.get(KEY_VERSION), VERSION):
		return {}
	var day: Variant = src.get(KEY_DAY)
	if not is_day_key(day):
		return {}
	var out: Dictionary = fresh_state(day)
	_copy_period(src, out, PERIOD_DAILY, legacy)
	var week: Variant = src.get(KEY_WEEK)
	if typeof(week) == TYPE_STRING and String(week) == String(out[KEY_WEEK]):
		_copy_period(src, out, PERIOD_WEEKLY, legacy)
	return out


## Dönem geçişi (TASK/061) — SAF, deterministik, idempotent (girdi değişmez). Kabul edilen gün `accepted`'in dönemi +
## KAPANAN dönem(ler)in teslim edilecek ödülleri. Kayıttaki gün kabul edilen günle aynıysa ya da ondan YENİYSE (saat
## geri alındı) dönem aynen kalır, teslim yok: dönem asla geri gitmez. Yeni gün → günlük dönem kapanır, aynı pazartesi
## haftasında haftalık aynen; yeni hafta → haftalık da kapanır. Kapanan dönemin TAMAMLANMIŞ ama ödülü VERİLMEMİŞ
## görevleri `auto_claimed`'e girer ve katalog ödülleri `dough`'da toplanır — ödül kaybolmaz, tam bir kez (yeni dönemde
## o görevler sıfırdan başlar; çağıran `state` + `dough`'u TEK yazmada saklar). Tamamlanmamış görevin ilerlemesi ödüle
## DÖNÜŞMEZ; ödülü verilmiş görev ikinci kez teslim edilmez. Kullanılabilir dönem yoksa `accepted`'in taze dönemi
## (teslim yok); o da yoksa boş durum.
## Döner: {state, auto_claimed: Array[StringName] (katalog sırası), dough: int, rolled: bool, closed: {dönem → kapanan
## dönemin anahtarı (günlük: eski gün, haftalık: eski pazartesi)}}.
static func rollover(raw: Variant, accepted: String) -> Dictionary:
	var auto: Array[StringName] = []
	var state: Dictionary = sanitize(raw)
	if state.is_empty():
		var fresh: Dictionary = fresh_state(accepted) if is_day_key(accepted) else {}
		return {"state": fresh, "auto_claimed": auto, "dough": 0, "rolled": false, "closed": {}}
	if not is_day_key(accepted) or accepted <= String(state[KEY_DAY]):
		return {"state": state, "auto_claimed": auto, "dough": 0, "rolled": false, "closed": {}}
	var out: Dictionary = fresh_state(accepted)
	var closed: Dictionary = {PERIOD_DAILY: String(state[KEY_DAY])}
	if String(out[KEY_WEEK]) == String(state[KEY_WEEK]):
		out[KEY_WEEKLY_PROGRESS] = state[KEY_WEEKLY_PROGRESS]
		out[KEY_WEEKLY_REWARDED] = state[KEY_WEEKLY_REWARDED]
	else:
		closed[PERIOD_WEEKLY] = String(state[KEY_WEEK])
	var dough: int = 0
	for entry in CATALOG:
		if closed.has(entry["period"]) and is_claimable(state, entry["id"]):
			auto.append(entry["id"])
			dough += int(entry["reward"])
	return {"state": out, "auto_claimed": auto, "dough": dough, "rolled": true, "closed": closed}


## `accepted` gününün dönemi — SAF, salt okuma görünümü (`rollover`'ın durumu; teslimi YAPMAZ). Ekranlar okur; dönem
## değişimi gösterimde görünür, kapanan dönemin ödülünü yalnız SaveManager'ın dönem işlemi teslim eder.
static func for_day(raw: Variant, accepted: String) -> Dictionary:
	return rollover(raw, accepted)["state"]


## Kesinleşen bir round'un gerçeklerini döneme işler — SAF (`state` değişmez; `rollover` / `for_day` çıktısı beklenir).
## TASK/061: hedefe ulaşmak Hamur VERMEZ — ilerleme hedefte sabitlenir, görev ALINABİLİR olur (ödül ÖDÜLÜ AL'da ya da
## dönem kapanırken). Hedefteki (alınabilir / alınmış) görev ilerlemez. Negatif değer 0.
## Döner: {state, completed: Array[StringName] — bu çağrıda hedefe İLK kez ulaşan görevler (katalog sırası)}.
static func advance(state: Dictionary, merges: int, rounds: int, clears: int) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	var completed: Array[StringName] = []
	if out.is_empty():
		return {"state": out, "completed": completed}
	var deltas: Dictionary = {METRIC_MERGES: maxi(merges, 0), METRIC_ROUNDS: maxi(rounds, 0),
		METRIC_CLEARS: maxi(clears, 0)}
	for entry in CATALOG:
		var target: int = int(entry["target"])
		# Hedefle sınırlı: saçma büyük bir sayı toplamada int taşırmaz.
		var delta: int = mini(int(deltas[entry["metric"]]), target)
		if delta <= 0:
			continue
		var id: String = String(entry["id"])
		var progress: Dictionary = out[progress_key(entry["period"])]
		var before: int = int(progress.get(id, 0))
		if before >= target or (out[rewarded_key(entry["period"])] as Array).has(id):
			continue
		var value: int = mini(before + delta, target)
		progress[id] = value
		if value >= target:
			completed.append(entry["id"])
	return {"state": out, "completed": completed}


## ÖDÜLÜ AL (TASK/061) — SAF (`state` değişmez; `rollover` çıktısı beklenir). `period_key` = arayüzün GÖSTERDİĞİ dönemin
## anahtarı (günlük görevde gün, haftalıkta pazartesi). Yalnız bilinen görev + geçerli dönem + tamamlanmış + ödülü
## verilmemiş görevde ödül işareti eklenir; ödül miktarı KATALOGDAN (arayüzün miktarına güvenilmez). İlerleme DEĞİŞMEZ.
## Döner: {result: Claim, state, dough} — CLAIMED değilse `state` girdinin aynısı, `dough` 0.
static func claim(state: Dictionary, id: StringName, period_key: String) -> Dictionary:
	var entry: Dictionary = find(id)
	if entry.is_empty():
		return {"result": Claim.UNKNOWN, "state": state, "dough": 0}
	if state.is_empty():
		return {"result": Claim.NO_PERIOD, "state": state, "dough": 0}
	var period: StringName = entry["period"]
	if period_key != period_key_of(state, period):
		return {"result": Claim.WRONG_PERIOD, "state": state, "dough": 0}
	if is_claimed(state, id):
		return {"result": Claim.ALREADY_CLAIMED, "state": state, "dough": 0}
	if not is_completed(state, id):
		return {"result": Claim.NOT_COMPLETE, "state": state, "dough": 0}
	var out: Dictionary = state.duplicate(true)
	var rewarded: Array = out[rewarded_key(period)]
	rewarded.append(String(id))
	out[rewarded_key(period)] = _catalog_order(rewarded, period)
	return {"result": Claim.CLAIMED, "state": out, "dough": int(entry["reward"])}


# --- Okuma (ekranlar) ------------------------------------------------------------------

## Kabul edilen gündeki doğrulanmış durum (SaveManager.missions_state) — YAZMAZ.
static func current() -> Dictionary:
	return SaveManager.missions_state()


## Bir dönemin anahtarı (günlük: gün, haftalık: pazartesi) — ÖDÜLÜ AL'ın dönem doğrulaması. Boş durumda boş.
static func period_key_of(state: Dictionary, period: StringName) -> String:
	if state.is_empty():
		return ""
	return String(state.get(KEY_DAY if period == PERIOD_DAILY else KEY_WEEK, ""))


## Görevin bu dönemdeki ödülü verildi mi (ÖDÜLÜ AL ya da dönem sonu teslimi — ALINDI).
static func is_claimed(state: Dictionary, id: StringName) -> bool:
	var entry: Dictionary = find(id)
	if entry.is_empty() or state.is_empty():
		return false
	return (state.get(rewarded_key(entry["period"]), []) as Array).has(String(id))


## Görev bu dönemde hedefe ulaştı mı (alınabilir ya da alınmış — TAMAMLANDI).
static func is_completed(state: Dictionary, id: StringName) -> bool:
	if is_claimed(state, id):
		return true
	var target: int = target_of(id)
	return target > 0 and progress_of(state, id) >= target


## Tamamlanmış ama ödülü verilmemiş — ÖDÜLÜ AL bekliyor.
static func is_claimable(state: Dictionary, id: StringName) -> bool:
	return is_completed(state, id) and not is_claimed(state, id)


## AKTİF / ALINABİLİR / ALINDI.
static func status_of(state: Dictionary, id: StringName) -> StringName:
	if is_claimed(state, id):
		return STATUS_CLAIMED
	return STATUS_CLAIMABLE if is_completed(state, id) else STATUS_ACTIVE


## Görevin dönemdeki ilerlemesi (0..hedef).
static func progress_of(state: Dictionary, id: StringName) -> int:
	var entry: Dictionary = find(id)
	if entry.is_empty() or state.is_empty():
		return 0
	var progress: Dictionary = state.get(progress_key(entry["period"]), {})
	return clampi(int(progress.get(String(id), 0)), 0, int(entry["target"]))


## Tamamlanan görev sayısı (alınabilir + alınmış) — içinde bulunulan dönemlerde, 0..6 (Ana Sayfa "N/6").
static func completed_count(state: Dictionary) -> int:
	var count: int = 0
	for id in ids():
		if is_completed(state, id):
			count += 1
	return count


## ÖDÜLÜ AL bekleyen görevler (katalog sırası) — Ana Sayfa dikkat rozeti / pencere başlığı.
static func claimable_ids(state: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in ids():
		if is_claimable(state, id):
			out.append(id)
	return out


static func claimable_count(state: Dictionary) -> int:
	return claimable_ids(state).size()


## Ekran satırları (katalog sırası): id, period, metric, title, progress, target, reward, completed, claimed, claimable,
## status, period_key.
static func rows(state: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in CATALOG:
		var id: StringName = entry["id"]
		out.append({
			"id": id,
			"period": entry["period"],
			"metric": entry["metric"],
			"title": title(id),
			"progress": progress_of(state, id),
			"target": int(entry["target"]),
			"reward": int(entry["reward"]),
			"completed": is_completed(state, id),
			"claimed": is_claimed(state, id),
			"claimable": is_claimable(state, id),
			"status": status_of(state, id),
			"period_key": period_key_of(state, entry["period"]),
		})
	return out


# --- Yardımcılar -------------------------------------------------------------------------

static func _is_version(value: Variant, version: int) -> bool:
	match typeof(value):
		TYPE_INT:
			return value == version
		TYPE_FLOAT:
			return value == float(version)
	return false


## Kayıttaki sayım → 0..cap (JSON sayıları float gelir). Sayı değil / NaN → 0; ±sonsuz kırpılır. (Sürüm 1 okuması.)
static func _clamp_count(value: Variant, cap: int) -> int:
	match typeof(value):
		TYPE_INT:
			return clampi(value, 0, cap)
		TYPE_FLOAT:
			var number: float = value
			if is_nan(number):
				return 0
			return int(clampf(number, 0.0, float(cap)))
	return 0


## Sürüm 2 okuması (fail-closed): yalnız 0..cap aralığındaki sonlu sayı (JSON float → aşağı yuvarlanır); aralık dışı /
## NaN / ±sonsuz / sayı değil → 0. Kendi kodumuz hedeften büyük ya da negatif ilerleme YAZMAZ — öyle bir değer bozuktur ve
## hedefe kırpılsaydı görevi bedavaya ALINABİLİR yapardı.
static func _strict_count(value: Variant, cap: int) -> int:
	match typeof(value):
		TYPE_INT:
			return value if (value >= 0 and value <= cap) else 0
		TYPE_FLOAT:
			var number: float = value
			if is_nan(number) or is_inf(number) or number < 0.0 or number > float(cap):
				return 0
			return int(floorf(number))
	return 0


## Bir dönemin ilerlemesini ve ödül işaretlerini `src`'ten doğrulayarak `out`'a kopyalar (`legacy`: sürüm 1 kuralı).
static func _copy_period(src: Dictionary, out: Dictionary, period: StringName, legacy: bool) -> void:
	var seen: Dictionary = {}
	var raw_rewarded: Variant = src.get(rewarded_key(period))
	if raw_rewarded is Array:
		var scanned: int = 0
		for item: Variant in raw_rewarded:
			scanned += 1
			if scanned > RAW_CAP:
				break
			if typeof(item) == TYPE_STRING or typeof(item) == TYPE_STRING_NAME:
				seen[String(item)] = true
	var raw_progress: Variant = src.get(progress_key(period))
	var progress_src: Dictionary = raw_progress if raw_progress is Dictionary else {}
	var progress: Dictionary = {}
	var rewarded: Array = []
	for id in ids_for(period):
		var key: String = String(id)
		var target: int = target_of(id)
		if seen.has(key):
			rewarded.append(key)
			progress[key] = target
		elif legacy:
			progress[key] = mini(_clamp_count(progress_src.get(key), target), target - 1)
		else:
			progress[key] = _strict_count(progress_src.get(key), target)
	out[progress_key(period)] = progress
	out[rewarded_key(period)] = rewarded


## Ödül işaretleri katalog sırasında, tekrarsız (deterministik kayıt).
static func _catalog_order(raw: Array, period: StringName) -> Array:
	var out: Array = []
	for id in ids_for(period):
		if raw.has(String(id)):
			out.append(String(id))
	return out
