class_name Missions
extends RefCounted
## Günlük / Haftalık Görevler V1 (TASK/046 — owner kararı, KİLİTLİ; GAME_DESIGN §5.10) —
## katalog + SAF kural katmanı (gün / hafta anahtarı, doğrulama, dönem, ilerleme). Kayda
## YAZMAZ: kalıcılık ve TEK mutasyon SaveManager'da (`record_mission_round`, round
## kesinleşmesinde); okuma kısayolları SaveManager'ın doğrulanmış durumunu kullanır.
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
##   Ödül     OTOMATİK — talep butonu yok. Görev hedefine dönemi içinde İLK kez ulaşınca
##            ödül işareti + Hamur, round kaydının TEK yazmasında. Bir görev bir dönemde en
##            fazla bir kez ödül verir. XP / sandık / parça / güç / başarım / unvan / reklam YOK.
##   Gün      GÜNLÜK ÖDÜLLER'in kabul edilen günü (`DailyRewards.day_key()`: saat geri
##            alınırsa görülen en yeni gün) — ayrı bir saat gerçeği YOK. Dönem ayrıca
##            kayıttaki dönemin gerisine hiç düşmez: geri alınan saat eski bir dönemi geri
##            getiremez, yeni ödül seti üretemez, tamamlanmış görevi yeniden ödüllendiremez.
##            Saati İLERİ almak çevrimdışı oyunda engellenemez (günlük ödüllerle aynı kabul).
##   Hafta    PAZARTESİ başlar; anahtar o haftanın pazartesi tarihi (`week_start`).
##   Seri     YOK — görev serisi / haftalık seri / çarpan yok (giriş serisi DailyReward'da aynen).

## Kayıttaki görev durumunun şema sürümü.
const VERSION: int = 1
const PERIOD_DAILY: StringName = &"daily"
const PERIOD_WEEKLY: StringName = &"weekly"
const METRIC_MERGES: StringName = &"merges"
const METRIC_ROUNDS: StringName = &"rounds"
const METRIC_CLEARS: StringName = &"clears"

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
## Geçerli gün anahtarının en küçük yılı: bundan eski cihaz saati bozuk sayılır (görev işlenmez).
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
## yeni gün" bozulmuş) cihaz günü; o da geçersizse boş → görev işlenmez, dönem değişmez.
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


## Kayıttaki ham görev durumunu güvenli BİÇİME indirir — SAF, deterministik, sınırlı; dönem
## DEĞİŞTİRMEZ (bkz. `for_day`). Boş sözlük = kullanılabilir dönem yok (anahtar yok / sözlük
## değil / bilinmeyen sürüm / geçersiz gün): okuyan kabul edilen günün taze dönemini kullanır.
##   ilerleme       yalnız katalog görevleri; sayı değil / NaN → 0; negatif → 0; ödüllü görev
##                  = hedef, ödülsüz görev ≤ hedef − 1 (hedef, ödül işaretiyle birlikte gelir)
##   ödül işareti   yalnız o dönemin bilinen id'leri, tekrarsız, katalog sırası
##   hafta          kayıttaki hafta günün pazartesisi değilse (kendi kodumuz üretmez — bozuk)
##                  haftalık kısım taze kalır
static func sanitize(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var src: Dictionary = raw
	if not _is_current_version(src.get(KEY_VERSION)):
		return {}
	var day: Variant = src.get(KEY_DAY)
	if not is_day_key(day):
		return {}
	var out: Dictionary = fresh_state(day)
	_copy_period(src, out, PERIOD_DAILY)
	var week: Variant = src.get(KEY_WEEK)
	if typeof(week) == TYPE_STRING and String(week) == String(out[KEY_WEEK]):
		_copy_period(src, out, PERIOD_WEEKLY)
	return out


## `accepted` gününün dönemi — SAF. Kayıttaki gün kabul edilen günle aynıysa ya da ondan
## YENİYSE (saat geri alındı) kayıttaki dönem aynen kalır: dönem asla geri gitmez. Yeni gün →
## günlük sıfır; aynı pazartesi haftası → haftalık aynen; yeni hafta → haftalık da sıfır.
## Kullanılabilir dönem yoksa `accepted`'in taze dönemi; o da yoksa boş.
static func for_day(raw: Variant, accepted: String) -> Dictionary:
	var state: Dictionary = sanitize(raw)
	if state.is_empty():
		return fresh_state(accepted) if is_day_key(accepted) else {}
	if not is_day_key(accepted) or accepted <= String(state[KEY_DAY]):
		return state
	var out: Dictionary = fresh_state(accepted)
	if String(out[KEY_WEEK]) == String(state[KEY_WEEK]):
		out[KEY_WEEKLY_PROGRESS] = state[KEY_WEEKLY_PROGRESS]
		out[KEY_WEEKLY_REWARDED] = state[KEY_WEEKLY_REWARDED]
	return out


## Kesinleşen bir round'un gerçeklerini döneme işler — SAF (`state` değişmez; `for_day`
## çıktısı beklenir). Hedefine dönemi içinde İLK kez ulaşan görev ödül işaretini alır ve
## ödülü toplama girer; işaretli görev ilerlemez, ikinci kez ödül vermez. Negatif değer 0.
## Döner: {state, completed: Array[StringName] (katalog sırası), dough: int}.
static func advance(state: Dictionary, merges: int, rounds: int, clears: int) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	var completed: Array[StringName] = []
	var dough: int = 0
	if out.is_empty():
		return {"state": out, "completed": completed, "dough": dough}
	var deltas: Dictionary = {METRIC_MERGES: maxi(merges, 0), METRIC_ROUNDS: maxi(rounds, 0),
		METRIC_CLEARS: maxi(clears, 0)}
	for entry in CATALOG:
		var target: int = int(entry["target"])
		# Hedefle sınırlı: saçma büyük bir sayı toplamada int taşırmaz.
		var delta: int = mini(int(deltas[entry["metric"]]), target)
		if delta <= 0:
			continue
		var id: String = String(entry["id"])
		var rewarded: Array = out[rewarded_key(entry["period"])]
		if rewarded.has(id):
			continue
		var progress: Dictionary = out[progress_key(entry["period"])]
		var value: int = mini(int(progress.get(id, 0)) + delta, target)
		progress[id] = value
		if value >= target:
			rewarded.append(id)
			completed.append(entry["id"])
			dough += int(entry["reward"])
	for period: StringName in [PERIOD_DAILY, PERIOD_WEEKLY]:
		out[rewarded_key(period)] = _catalog_order(out[rewarded_key(period)], period)
	return {"state": out, "completed": completed, "dough": dough}


# --- Okuma (ekranlar) ------------------------------------------------------------------

## Kabul edilen gündeki doğrulanmış durum (SaveManager.missions_state) — YAZMAZ.
static func current() -> Dictionary:
	return SaveManager.missions_state()


## Görev ödüllendirildi mi (tamamlandı) — `state` for_day çıktısı.
static func is_completed(state: Dictionary, id: StringName) -> bool:
	var entry: Dictionary = find(id)
	if entry.is_empty() or state.is_empty():
		return false
	return (state.get(rewarded_key(entry["period"]), []) as Array).has(String(id))


## Görevin dönemdeki ilerlemesi (0..hedef).
static func progress_of(state: Dictionary, id: StringName) -> int:
	var entry: Dictionary = find(id)
	if entry.is_empty() or state.is_empty():
		return 0
	var progress: Dictionary = state.get(progress_key(entry["period"]), {})
	return clampi(int(progress.get(String(id), 0)), 0, int(entry["target"]))


## Tamamlanan (ödüllendirilen) görev sayısı — içinde bulunulan dönemlerde, 0..6.
static func completed_count(state: Dictionary) -> int:
	var count: int = 0
	for id in ids():
		if is_completed(state, id):
			count += 1
	return count


## Ekran satırları (katalog sırası): id, period, title, progress, target, reward, completed.
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
		})
	return out


# --- Yardımcılar -------------------------------------------------------------------------

static func _is_current_version(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return value == VERSION
		TYPE_FLOAT:
			return value == float(VERSION)
	return false


## Kayıttaki sayım → 0..cap (JSON sayıları float gelir). Sayı değil / NaN → 0; ±sonsuz kırpılır.
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


## Bir dönemin ilerlemesini ve ödül işaretlerini `src`'ten doğrulayarak `out`'a kopyalar.
static func _copy_period(src: Dictionary, out: Dictionary, period: StringName) -> void:
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
		else:
			progress[key] = mini(_clamp_count(progress_src.get(key), target), target - 1)
	out[progress_key(period)] = progress
	out[rewarded_key(period)] = rewarded


## Ödül işaretleri katalog sırasında, tekrarsız (deterministik kayıt).
static func _catalog_order(raw: Array, period: StringName) -> Array:
	var out: Array = []
	for id in ids_for(period):
		if raw.has(String(id)):
			out.append(String(id))
	return out
