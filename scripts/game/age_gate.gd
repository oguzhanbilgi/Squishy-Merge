class_name AgeGate
extends RefCounted
## Yaş ekranı + yaş bandı reklam yönlendirmesinin TEK modeli (TASK/043 —
## docs/monetization/AGE_BAND_ROUTING.md). Owner iş kararı (2026-09-27): 13–17 reklam
## alır (TEEN işlemi + en yüksek derece T), 18+ olağan yetişkin yolu (UNSPECIFIED + MA),
## bilinmeyen yaş: reklam SDK'sı HİÇ başlamaz, UMP sorulmaz, reklam yok.
##
## TASK/046.1 (owner kararı, 2026-09-30 — ürün 13+): oyuncu yalnız 13 yaş ve üstünü
## gösteren bir doğum tarihi SEÇEBİLİR (`classify_selected_birth_date`, seçici aralığı
## `selectable_*`); normal giriş UNDER_13 üretmez, 13 altı kısıt / çıkış ekranı emekli.
## Eski kayıttaki UNDER_13 (TASK/043 dönemi) otomatik TEEN / ADULT'a ÇEVRİLMEZ, yaş TAHMİN
## EDİLMEZ: `resolve_stored` onu UNKNOWN'a indirir (reklam yok, zorunlu yaş ekranı yeniden).
## `classify_birth_date` ham sınıflandırıcı olarak kalır (UNDER_13 dönebilir — yalnız eski
## kayıt / test / QA sentetik bantları için; oyuncu girişi onu doğrudan kullanmaz).
##
## GİZLİLİK (veri azaltma): oyuncunun seçtiği doğum tarihi yalnız bellekte, yalnız
## sınıflandırma çağrısı boyunca yaşar; SAKLANMAZ, loglanmaz, analitiğe / reklama / Play Age
## Signals'a GİTMEZ. Kalıcı olan yalnız türetilmiş durum
## (SaveManager `age_ad_band` + `next_age_transition_date`):
##   TEEN     -> 18. yaş günü   (o gün ADULT olur, soğuk açılışta, SDK'dan ÖNCE)
##   ADULT    -> tarih YOK
##   (UNDER_13 -> 13. yaş günü: yalnız TASK/043 döneminden kalma kayıtlarda; artık yazılmaz)
## Dürüst not: TEEN için saklanan geçiş günü doğum gününden türetilir (18. yıl dönümü); o
## bantta doğum tarihine matematiksel olarak eşdeğerdir. Yalnız bu cihazda, oyuncunun kendi
## kayıt dosyasında durur; ADULT olunca silinir.
##
## TAKVİM KURALLARI (tarih-yalnız; saat / saat dilimi / "gün / 365" YOK):
##   - Yaş, takvim yıl dönümüyle: yıl dönümü günü yaş dolar (13. yaş günü TEEN,
##     18. yaş günü ADULT).
##   - 29 Şubat doğumlular artık olmayan yıllarda 1 Mart'ta yaş doldurur (koruyucu
##     yön: daha korumalı bant bir gün daha sürer).
##   - Geçersiz tarih (31 Nisan, 29 Şubat artık olmayan yılda, ay 13, gün 0), gelecek
##     tarih ve 120 yıldan eski tarih REDDEDİLİR — bant türetilmez, hiçbir şey saklanmaz.
##
## KAYIT DAYANIKLILIĞI (fail-closed): biçimsiz / imkânsız / saçma derecede ileri geçiş
## günü, bilinmeyen bant değeri ya da tutarsız çift -> UNKNOWN (reklam YOK, yaş yeniden
## sorulur), ASLA ADULT. Cihaz saati kimlik doğrulaması DEĞİLDİR: saati ileri almak
## (yeniden kurup başka tarih girmek gibi) engellenemez — bilinçli kabul, AGE_BAND_ROUTING §5.
## Saat modelin geldiği günden (MODEL_START_DAY) önceyi gösteriyorsa bozuktur: yaş o saatle
## sınıflandırılmaz (`clock_plausible`; Main yaş ekranını açmaz, panel girişi reddeder).
##
## PLAY AGE SIGNALS BURADA YOK ve hiçbir zaman buraya girmez (Age Signals şartları reklam
## / pazarlama / profilleme / analitik kullanımını yasaklıyor — GLOBAL_TEEN_AD_TREATMENT ⚠).

enum Band { UNKNOWN, UNDER_13, TEEN, ADULT }
## Doğum tarihi girişinin sonucu. Oyuncuya hepsi AYNI nötr mesajla gösterilir. TOO_YOUNG
## (TASK/046.1): seçilebilir aralığın dışında kalan (13 yaşından genç) tarih — seçici bunu hiç
## göstermez; buraya ancak bozuk / değişmiş bir saatle ulaşılır.
enum EntryError { NONE, INVALID, FUTURE, TOO_OLD, TOO_YOUNG }

## Kayıttaki değerler (indeks = Band). Başka her değer bozuk sayılır -> UNKNOWN.
const BAND_KEYS: Array[String] = ["UNKNOWN", "UNDER_13", "TEEN", "ADULT"]
const TEEN_AGE: int = 13
const ADULT_AGE: int = 18
## TASK/046.1 (owner kararı, 2026-09-30): ürün 13+ — yaş seçici bu yaştan genç bir doğum
## tarihini HİÇ sunmaz (13 altı kısıt / çıkış akışı emekli). Aralığın tek kaynağı bu sınıf
## (`youngest_allowed_birth_date` / `selectable_*` / `clamp_selection`); UI takvim hesabı yapmaz.
const MIN_SELECTABLE_AGE: int = TEEN_AGE
## Bundan eski doğum tarihi geçerli sayılmaz (yazım hatası koruması).
const MAX_AGE_YEARS: int = 120
## Saklanan geçiş gününün üst sınırında saat dilimi / küçük saat geri alma payı (gün).
## Pay yıl dönümünden ÖNCE eklenir (29 Şubat kenarında da tam 2 gün). Bunu aşan geri
## alma kaydı tutarsız yapar -> UNKNOWN (yeniden sorulur).
const TRANSITION_SLACK_DAYS: int = 2
## Model (TASK/043) bu gün geldi: saat bundan önceyi gösteriyorsa bozuktur — yaş o saatle
## sınıflandırılmaz, yaş ekranı açılmaz (bant UNKNOWN kalır: reklam yok, oyun açık).
const MODEL_START_DAY: String = "2026-09-27"
## Geçerli bir kayıttaki geçiş günü bundan ÖNCE olamaz: geçiş günü, sınıflandırıldığı
## günden sonradır ve sınıflandırma yalnız MODEL_START_DAY ve sonrasında yapılır. Daha
## eski bir gün bozuk kayıttır -> UNKNOWN, ASLA "çoktan yetişkin".
const EARLIEST_POSSIBLE_TRANSITION: String = "2026-09-28"

## Owner onaylı yönlendirme tablosu (TASK/043, 2026-09-27). Kod bunu okur; release kapısı
## (`routing_contract_problems`) birebir denetler. Özel reklam kategorisi kısıtı YOK.
const TEEN_MAX_AD_CONTENT_RATING: String = "T"
const ADULT_MAX_AD_CONTENT_RATING: String = "MA"

## Test / QA kancası: boş değilse "bugün" bu tarihtir (YYYY-MM-DD). Üretim kodu yazmaz.
static var clock_override: String = ""


# --- Bugün -------------------------------------------------------------------------------

## Cihazın yerel takvim günü {year, month, day} (ya da `clock_override`).
static func today() -> Dictionary:
	if not clock_override.is_empty():
		var forced: Dictionary = parse_day(clock_override)
		if not forced.is_empty():
			return forced
	var now: Dictionary = Time.get_date_dict_from_system()
	return {"year": int(now["year"]), "month": int(now["month"]), "day": int(now["day"])}


# --- Takvim ------------------------------------------------------------------------------

static func is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or year % 400 == 0


## Ayın gün sayısı; geçersiz ay -> 0.
static func days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			return 29 if is_leap_year(year) else 28
	return 0


static func is_valid_date(year: int, month: int, day: int) -> bool:
	return year >= 1 and year <= 9999 and day >= 1 and day <= days_in_month(year, month)


static func make_date(year: int, month: int, day: int) -> Dictionary:
	return {"year": year, "month": month, "day": day}


## Kesin biçim YYYY-MM-DD + gerçek takvim günü; değilse {} (biçimsiz / imkânsız).
static func parse_day(text: Variant) -> Dictionary:
	if typeof(text) != TYPE_STRING:
		return {}
	var value: String = text
	if value.length() != 10 or value[4] != "-" or value[7] != "-":
		return {}
	var parts: PackedStringArray = [value.substr(0, 4), value.substr(5, 2), value.substr(8, 2)]
	for part in parts:
		if not part.is_valid_int() or part.contains("+") or part.contains("-"):
			return {}
	var date: Dictionary = make_date(int(parts[0]), int(parts[1]), int(parts[2]))
	return date if is_valid_date(date["year"], date["month"], date["day"]) else {}


## Önceki takvim günü.
static func previous_day(date: Dictionary) -> Dictionary:
	var year: int = int(date["year"])
	var month: int = int(date["month"])
	var day: int = int(date["day"]) - 1
	if day < 1:
		month -= 1
		if month < 1:
			month = 12
			year -= 1
		day = days_in_month(year, month)
	return make_date(year, month, day)


## Ertesi takvim günü.
static func next_day(date: Dictionary) -> Dictionary:
	var year: int = int(date["year"])
	var month: int = int(date["month"])
	var day: int = int(date["day"]) + 1
	if day > days_in_month(year, month):
		day = 1
		month += 1
		if month > 12:
			month = 1
			year += 1
	return make_date(year, month, day)


## Cihaz saati yaşı sınıflandırmaya elverişli mi: modelin geldiği günden önce DEĞİL.
static func clock_plausible(on_day: Dictionary) -> bool:
	return not on_day.is_empty() and compare(on_day, parse_day(MODEL_START_DAY)) >= 0


static func format_day(date: Dictionary) -> String:
	return "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]


## Proleptik Gregoryen gün numarası (1970-01-01 = 0) — tamsayı, işletim sistemi saatine
## ve saat dilimine bağlı değil (H. Hinnant, days_from_civil).
static func day_number(date: Dictionary) -> int:
	var y: int = int(date["year"])
	var m: int = int(date["month"])
	var d: int = int(date["day"])
	if m <= 2:
		y -= 1
	var era: int = floori(float(y) / 400.0)
	var yoe: int = y - era * 400
	var mp: int = (m + 9) % 12
	var doy: int = floori(float(153 * mp + 2) / 5.0) + d - 1
	var doe: int = yoe * 365 + floori(float(yoe) / 4.0) - floori(float(yoe) / 100.0) + doy
	return era * 146097 + doe - 719468


## a < b -> negatif, eşit -> 0, a > b -> pozitif.
static func compare(a: Dictionary, b: Dictionary) -> int:
	return day_number(a) - day_number(b)


## `date`'in `years` yıl sonraki (negatifse önceki) yıl dönümü. 29 Şubat artık olmayan
## yıla düşerse 1 Mart (koruyucu yön — sınıfın başındaki kural).
static func anniversary(date: Dictionary, years: int) -> Dictionary:
	var year: int = int(date["year"]) + years
	var month: int = int(date["month"])
	var day: int = int(date["day"])
	if month == 2 and day == 29 and not is_leap_year(year):
		return make_date(year, 3, 1)
	return make_date(year, month, day)


# --- Sınıflandırma (doğum tarihi -> bant) -------------------------------------------------

## Doğum tarihini `today` gününe göre sınıflandırır. Dönüş (doğum tarihi İÇERMEZ):
##   {"ok": bool, "error": EntryError, "band": Band, "transition": "YYYY-MM-DD" | ""}
## Hata varsa band UNKNOWN ve transition boş — çağıran hiçbir şey saklamaz.
static func classify_birth_date(year: int, month: int, day: int, on_day: Dictionary) -> Dictionary:
	var out: Dictionary = {"ok": false, "error": EntryError.INVALID, "band": Band.UNKNOWN, "transition": ""}
	if not is_valid_date(year, month, day):
		return out
	var birth: Dictionary = make_date(year, month, day)
	if compare(birth, on_day) > 0:
		out["error"] = EntryError.FUTURE
		return out
	if compare(birth, anniversary(on_day, -MAX_AGE_YEARS)) < 0:
		out["error"] = EntryError.TOO_OLD
		return out
	out["ok"] = true
	out["error"] = EntryError.NONE
	var turns_13: Dictionary = anniversary(birth, TEEN_AGE)
	var turns_18: Dictionary = anniversary(birth, ADULT_AGE)
	if compare(on_day, turns_13) < 0:
		out["band"] = Band.UNDER_13
		out["transition"] = format_day(turns_13)
	elif compare(on_day, turns_18) < 0:
		out["band"] = Band.TEEN
		out["transition"] = format_day(turns_18)
	else:
		out["band"] = Band.ADULT
	return out


# --- 13+ seçim aralığı (TASK/046.1) -------------------------------------------------------
#
# Oyuncunun seçebileceği doğum tarihleri: [oldest_allowed, youngest_allowed] (iki uç dahil).
# Bu fonksiyonlar `classify_birth_date`'in KENDİ kurallarından türer (yıl dönümü, 29 Şubat,
# MAX_AGE_YEARS): aralıktaki her tarih TEEN / ADULT sınıflanır, aralık dışındaki hiçbiri
# seçilemez. UI yalnız bunları okur.

## `on_day`'de en az MIN_SELECTABLE_AGE yaşında olan EN GEÇ doğum günü: `anniversary(d, 13)
## <= on_day` olan en büyük d. Çoğu gün `anniversary(on_day, -13)`; 29 Şubat "bugün"ünde 13
## yıl önce artık yıl değilse 28 Şubat (1 Mart doğumlunun 13. yaş günü henüz gelmedi).
static func youngest_allowed_birth_date(on_day: Dictionary) -> Dictionary:
	var year: int = int(on_day["year"]) - MIN_SELECTABLE_AGE
	var month: int = int(on_day["month"])
	var candidate: Dictionary = make_date(year, month, mini(int(on_day["day"]), days_in_month(year, month)))
	while compare(anniversary(candidate, MIN_SELECTABLE_AGE), on_day) > 0:
		candidate = previous_day(candidate)
	return candidate


## En eski kabul edilen doğum günü — `classify_birth_date`'in TOO_OLD sınırı (MAX_AGE_YEARS).
static func oldest_allowed_birth_date(on_day: Dictionary) -> Dictionary:
	return anniversary(on_day, -MAX_AGE_YEARS)


static func is_selectable_birth_date(year: int, month: int, day: int, on_day: Dictionary) -> bool:
	if not is_valid_date(year, month, day):
		return false
	var birth: Dictionary = make_date(year, month, day)
	return compare(birth, oldest_allowed_birth_date(on_day)) >= 0 \
		and compare(birth, youngest_allowed_birth_date(on_day)) <= 0


## Seçicinin yıl aralığı: Vector2i(en eski yıl, en genç yıl).
static func selectable_year_range(on_day: Dictionary) -> Vector2i:
	return Vector2i(int(oldest_allowed_birth_date(on_day)["year"]), int(youngest_allowed_birth_date(on_day)["year"]))


## `year` yılında seçilebilecek aylar: Vector2i(ilk, son); yıl aralık dışındaysa boş (x > y).
static func selectable_month_range(year: int, on_day: Dictionary) -> Vector2i:
	var years: Vector2i = selectable_year_range(on_day)
	if year < years.x or year > years.y:
		return Vector2i(1, 0)
	var first: int = int(oldest_allowed_birth_date(on_day)["month"]) if year == years.x else 1
	var last: int = int(youngest_allowed_birth_date(on_day)["month"]) if year == years.y else 12
	return Vector2i(first, last)


## Seçilebilecek günler: Vector2i(ilk, son). `month` 0 = henüz seçilmedi (1..31); `year` 0 =
## henüz seçilmedi (ayın en uzun hali — Şubat 29). Ay o yıl seçilemiyorsa boş (x > y).
static func selectable_day_range(year: int, month: int, on_day: Dictionary) -> Vector2i:
	if month < 1 or month > 12:
		return Vector2i(1, 31)
	if year == 0:
		return Vector2i(1, 29 if month == 2 else days_in_month(2001, month))
	var months: Vector2i = selectable_month_range(year, on_day)
	if month < months.x or month > months.y:
		return Vector2i(1, 0)
	var first: int = 1
	var last: int = days_in_month(year, month)
	var young: Dictionary = youngest_allowed_birth_date(on_day)
	var old: Dictionary = oldest_allowed_birth_date(on_day)
	if year == int(young["year"]) and month == int(young["month"]):
		last = mini(last, int(young["day"]))
	if year == int(old["year"]) and month == int(old["month"]):
		first = maxi(first, int(old["day"]))
	return Vector2i(first, last)


## Oyuncu bir alanı değiştirdi: seçili diğer alanlar uyarlanır (0 = seçilmedi).
##   - TAKVİM uyarlaması kırpar: gün ayın son gününe (31 → 30; 29 Şubat → artık olmayan yılda
##     28 Şubat; yıl yokken Şubat 29).
##   - Seçilebilir ARALIKLA çelişen alan SIFIRLANIR ("Seç") — başka bir değere kaydırılmaz: ör.
##     15 Aralık seçiliyken en genç yıl seçilirse ay silinir, tarih kendiliğinden en genç izinli
##     güne (tam 13. yaş gününe) dönüşmez; oyuncunun seçmediği bir tarih oluşmaz, eşik ima edilmez.
## Dönüş {"day", "month", "year"} — üçü de doluysa sonuç her zaman seçilebilir bir tarihtir.
static func clamp_selection(day: int, month: int, year: int, on_day: Dictionary) -> Dictionary:
	if year != 0:
		var years: Vector2i = selectable_year_range(on_day)
		if year < years.x or year > years.y:
			year = 0
	if year != 0 and month != 0:
		var months: Vector2i = selectable_month_range(year, on_day)
		if month < months.x or month > months.y:
			month = 0
	if month != 0 and day != 0:
		var longest: int = days_in_month(year, month) if year != 0 else (29 if month == 2 else days_in_month(2001, month))
		day = mini(day, longest)
		var days: Vector2i = selectable_day_range(year, month, on_day)
		if day < days.x or day > days.y:
			day = 0
	return {"day": day, "month": month, "year": year}


## Oyuncu girişinin TEK sınıflandırıcısı (TASK/046.1): yalnız seçilebilir aralıktaki tarih
## bant alır (TEEN / ADULT). Aralık dışı: geçersiz / gelecek / çok eski / 13'ten genç ->
## hata, bant UNKNOWN, geçiş boş — oyuncuya hepsi AYNI nötr mesaj, hiçbir şey saklanmaz.
static func classify_selected_birth_date(year: int, month: int, day: int, on_day: Dictionary) -> Dictionary:
	var out: Dictionary = classify_birth_date(year, month, day, on_day)
	if not bool(out["ok"]):
		return out
	if int(out["band"]) == Band.UNDER_13 or not is_selectable_birth_date(year, month, day, on_day):
		return {"ok": false, "error": EntryError.TOO_YOUNG, "band": Band.UNKNOWN, "transition": ""}
	return out


# --- Kayıttaki durum (doğrulama + geçişler) --------------------------------------------

## Kayıttaki ham değerleri `on_day` gününe göre doğrular ve geçişleri uygular. Dönüş:
##   {"band": Band, "transition": String, "changed": bool, "corrupt": bool, "legacy_under_13": bool}
## `changed` = geçiş oldu (TEEN -> ADULT, 18. yaş günü): çağıran kaydeder.
## `corrupt` = kayıt tutarsız: UNKNOWN döner (reklam yok, yaş yeniden sorulur), hiçbir
## şey yazılmaz — bir sonraki giriş üzerine yazar.
## `legacy_under_13` (TASK/046.1) = TASK/043 döneminden kalma UNDER_13: UNKNOWN döner (reklam
## yok, zorunlu yaş ekranı yeniden) — TEEN / ADULT'a ÇEVRİLMEZ, saklı 13. yaş günü okunmaz
## (yaş tahmin edilmez). Kayda yazılmaz; yeni giriş üzerine yazar.
static func resolve_stored(band_value: Variant, transition_value: Variant, on_day: Dictionary) -> Dictionary:
	var unknown: Dictionary = {"band": Band.UNKNOWN, "transition": "", "changed": false, "corrupt": false,
		"legacy_under_13": false}
	if typeof(band_value) != TYPE_STRING or not BAND_KEYS.has(String(band_value)):
		unknown["corrupt"] = true
		return unknown
	var transition_text: String = String(transition_value) if typeof(transition_value) == TYPE_STRING else "?"
	var band: int = BAND_KEYS.find(String(band_value))
	match band:
		Band.UNKNOWN:
			unknown["corrupt"] = not transition_text.is_empty()
			return unknown
		Band.UNDER_13:
			unknown["legacy_under_13"] = true
			return unknown
		Band.ADULT:
			if not transition_text.is_empty():
				unknown["corrupt"] = true
				return unknown
			return {"band": Band.ADULT, "transition": "", "changed": false, "corrupt": false, "legacy_under_13": false}
	var transition: Dictionary = parse_day(transition_text)
	if not _transition_plausible(transition, ADULT_AGE - TEEN_AGE, on_day):
		unknown["corrupt"] = true
		return unknown
	if compare(on_day, transition) >= 0:
		return {"band": Band.ADULT, "transition": "", "changed": true, "corrupt": false, "legacy_under_13": false}
	return {"band": Band.TEEN, "transition": format_day(transition), "changed": false, "corrupt": false,
		"legacy_under_13": false}


## Geçiş günü bu bant için mümkün mü: gerçek gün, 29 Şubat DEĞİL (13. / 18. yıl dönümü
## hiçbir zaman 29 Şubat'a düşmez — 29 Şubat doğumlu o yıllarda 1 Mart'ta yaş doldurur),
## modelden eski değil, ve bugünden en fazla `span_years` (+ küçük pay) ileride. Daha
## ilerisi imkânsız yaş ya da geri alınmış saat demektir -> tutarsız.
static func _transition_plausible(transition: Dictionary, span_years: int, on_day: Dictionary) -> bool:
	if transition.is_empty():
		return false
	if int(transition["month"]) == 2 and int(transition["day"]) == 29:
		return false
	if compare(transition, parse_day(EARLIEST_POSSIBLE_TRANSITION)) < 0:
		return false
	# Pay yıl dönümünden ÖNCE: saat en fazla TRANSITION_SLACK_DAYS geri ise sınıflandırma
	# günü <= bugün + pay, yıl dönümü tekdüze -> geçiş <= yıl dönümü(bugün + pay).
	var horizon: Dictionary = on_day
	for _i in TRANSITION_SLACK_DAYS:
		horizon = next_day(horizon)
	return compare(transition, anniversary(horizon, span_years)) <= 0


# --- Kayda yazılacak biçim ----------------------------------------------------------------
#
# Bu sınıf SAF kalır (autoload'a dokunmaz): release kapısı (tools/release, export eklentisi)
# yönlendirme tablosunu okumak için onu derler. Kalıcılık SaveManager'da
# (`resolve_age_band_at_launch`, `store_age_band`).

## Kayda gidecek (bant anahtarı, geçiş günü) çifti: yalnız TEEN geçiş günü (18. yaş günü)
## taşır; ADULT / UNKNOWN için boş. (TASK/046.1: UNDER_13 artık yazılmaz — gelirse geçiş günü
## saklanmaz, doğum gününe eşdeğer tarih kayda girmez.)
static func stored_pair(band: int, transition: String) -> Array[String]:
	return [band_name(band), transition if band == Band.TEEN else ""]


# --- Reklam yönlendirmesi ---------------------------------------------------------------

## Bandın reklam rotası (owner tablosu). "ads" false -> reklam SDK'sı başlamaz, UMP
## sorulmaz, hiçbir reklam yok (treatment / derece o zaman gönderilmez; yalnız
## tip bütünlüğü için dolu).
static func ad_route(band: int) -> Dictionary:
	match band:
		Band.TEEN:
			return {"ads": true, "treatment": AdBackend.AgeRestrictedTreatment.TEEN,
				"max_ad_content_rating": TEEN_MAX_AD_CONTENT_RATING}
		Band.ADULT:
			return {"ads": true, "treatment": AdBackend.AgeRestrictedTreatment.UNSPECIFIED,
				"max_ad_content_rating": ADULT_MAX_AD_CONTENT_RATING}
	return {"ads": false, "treatment": AdBackend.AgeRestrictedTreatment.UNSPECIFIED, "max_ad_content_rating": ""}


static func band_name(band: int) -> String:
	return BAND_KEYS[band] if band >= 0 and band < BAND_KEYS.size() else "?"


## Release kapısı (TASK/043): çalışma zamanı eşlemesi owner tablosuyla birebir mi? Boş
## liste = evet. Tek fark bile kapının 13–17 UYUM engelini açık tutar. TASK/046.1: yaş
## ekranının 13+ seçim sözleşmesi de burada denetlenir (fark -> CODE engeli).
static func routing_contract_problems() -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	for band in [Band.UNKNOWN, Band.UNDER_13]:
		if bool(ad_route(band)["ads"]):
			problems.append("%s reklam almamalı" % band_name(band))
	var teen: Dictionary = ad_route(Band.TEEN)
	if not teen["ads"] or teen["treatment"] != AdBackend.AgeRestrictedTreatment.TEEN \
			or teen["max_ad_content_rating"] != "T":
		problems.append("TEEN -> TFAT TEEN + derece T olmalı")
	var adult: Dictionary = ad_route(Band.ADULT)
	if not adult["ads"] or adult["treatment"] != AdBackend.AgeRestrictedTreatment.UNSPECIFIED \
			or adult["max_ad_content_rating"] != "MA":
		problems.append("ADULT -> TFAT UNSPECIFIED + derece MA olmalı")
	# TASK/046.1: yaş ekranı yalnız 13+ doğum tarihi sunar / kabul eder (tek kaynak bu sınıf).
	var probe: Dictionary = parse_day(MODEL_START_DAY)
	var youngest: Dictionary = youngest_allowed_birth_date(probe)
	var younger: Dictionary = next_day(youngest)
	if MIN_SELECTABLE_AGE != TEEN_AGE \
			or int(classify_birth_date(youngest["year"], youngest["month"], youngest["day"], probe)["band"]) != Band.TEEN \
			or bool(classify_selected_birth_date(younger["year"], younger["month"], younger["day"], probe)["ok"]):
		problems.append("yaş ekranı yalnız 13+ doğum tarihi kabul etmeli")
	return problems
