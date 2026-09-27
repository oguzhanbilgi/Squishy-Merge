class_name AgeGate
extends RefCounted
## Nötr yaş ekranı + yaş bandı reklam yönlendirmesinin TEK modeli (TASK/043 —
## docs/monetization/AGE_BAND_ROUTING.md). Owner iş kararı (2026-09-27): 13–17 reklam
## alır (TEEN işlemi + en yüksek derece T), 18+ olağan yetişkin yolu (UNSPECIFIED + MA),
## 13 yaş altı ve bilinmeyen yaş: reklam SDK'sı HİÇ başlamaz, UMP sorulmaz, reklam yok.
##
## GİZLİLİK (veri azaltma): oyuncunun girdiği doğum tarihi yalnız bellekte, yalnız
## `classify_birth_date()` çağrısı boyunca yaşar; SAKLANMAZ, loglanmaz, analitiğe /
## reklama / Play Age Signals'a GİTMEZ. Kalıcı olan yalnız türetilmiş durum
## (SaveManager `age_ad_band` + `next_age_transition_date`):
##   UNDER_13 -> 13. yaş günü   (kısıt o gün kalkar)
##   TEEN     -> 18. yaş günü   (o gün ADULT olur, soğuk açılışta, SDK'dan ÖNCE)
##   ADULT    -> tarih YOK
## Dürüst not: UNDER_13 / TEEN için saklanan geçiş günü doğum gününden türetilir (13. /
## 18. yıl dönümü); o bantta doğum tarihine matematiksel olarak eşdeğerdir. Yalnız bu
## cihazda, oyuncunun kendi kayıt dosyasında durur; ADULT olunca silinir.
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
## Doğum tarihi girişinin sonucu. Oyuncuya hepsi AYNI nötr mesajla gösterilir.
enum EntryError { NONE, INVALID, FUTURE, TOO_OLD }

## Kayıttaki değerler (indeks = Band). Başka her değer bozuk sayılır -> UNKNOWN.
const BAND_KEYS: Array[String] = ["UNKNOWN", "UNDER_13", "TEEN", "ADULT"]
const TEEN_AGE: int = 13
const ADULT_AGE: int = 18
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


# --- Kayıttaki durum (doğrulama + geçişler) --------------------------------------------

## Kayıttaki ham değerleri `on_day` gününe göre doğrular ve geçişleri uygular. Dönüş:
##   {"band": Band, "transition": String, "changed": bool, "corrupt": bool}
## `changed` = geçiş oldu (UNDER_13 -> TEEN, TEEN -> ADULT): çağıran kaydeder.
## `corrupt` = kayıt tutarsız: UNKNOWN döner (reklam yok, yaş yeniden sorulur), hiçbir
## şey yazılmaz — bir sonraki giriş üzerine yazar.
static func resolve_stored(band_value: Variant, transition_value: Variant, on_day: Dictionary) -> Dictionary:
	var unknown: Dictionary = {"band": Band.UNKNOWN, "transition": "", "changed": false, "corrupt": false}
	if typeof(band_value) != TYPE_STRING or not BAND_KEYS.has(String(band_value)):
		unknown["corrupt"] = true
		return unknown
	var transition_text: String = String(transition_value) if typeof(transition_value) == TYPE_STRING else "?"
	var band: int = BAND_KEYS.find(String(band_value))
	match band:
		Band.UNKNOWN:
			unknown["corrupt"] = not transition_text.is_empty()
			return unknown
		Band.ADULT:
			if not transition_text.is_empty():
				unknown["corrupt"] = true
				return unknown
			return {"band": Band.ADULT, "transition": "", "changed": false, "corrupt": false}
	var transition: Dictionary = parse_day(transition_text)
	var span: int = TEEN_AGE if band == Band.UNDER_13 else ADULT_AGE - TEEN_AGE
	if not _transition_plausible(transition, span, on_day):
		unknown["corrupt"] = true
		return unknown
	var changed: bool = false
	if band == Band.UNDER_13 and compare(on_day, transition) >= 0:
		# Saklanan 13. yaş günü geldi: aynı (kendi beyanı) standartla TEEN kanıtlandı; 18. yaş
		# günü = 13. yaş günü + 5 yıl (13. yaş günü hiçbir zaman 29 Şubat değil — tam gün).
		band = Band.TEEN
		transition = anniversary(transition, ADULT_AGE - TEEN_AGE)
		changed = true
	if band == Band.TEEN and compare(on_day, transition) >= 0:
		return {"band": Band.ADULT, "transition": "", "changed": true, "corrupt": false}
	return {"band": band, "transition": format_day(transition), "changed": changed, "corrupt": false}


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

## Kayda gidecek (bant anahtarı, geçiş günü) çifti: ADULT / UNKNOWN için geçiş günü boş.
static func stored_pair(band: int, transition: String) -> Array[String]:
	var keep: bool = band == Band.UNDER_13 or band == Band.TEEN
	return [band_name(band), transition if keep else ""]


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
## liste = evet. Tek fark bile kapının 13–17 UYUM engelini açık tutar.
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
	return problems
