extends Node
## TASK/043 — nötr yaş ekranı modeli + kaydı + UI deterministik testi (İNTERNET, CİHAZ,
## EKLENTİ YOK; saat `AgeGate.clock_override` ile enjekte edilir). docs/monetization/
## AGE_BAND_ROUTING.md.
##
##   TAKVİM     artık yıl (1900 / 2000 / 2024 / 2100), ay uzunlukları, geçersiz tarihler,
##              kesin YYYY-MM-DD ayrıştırma, gün numarası, 29 Şubat yıl dönümü -> 1 Mart
##   SINIRLAR   12y364g -> UNDER_13 · tam 13. yaş günü -> TEEN · 17 -> TEEN · 18'den bir
##              gün önce -> TEEN · tam 18. yaş günü -> ADULT · 25 -> ADULT · geçersiz /
##              gelecek / 120 yıldan eski -> bant YOK; 29 Şubat doğumlular; artık gün "bugün"
##   KAYIT      doğrulama + geçişler (UNDER_13 -> TEEN -> ADULT), bozuk / imkânsız / saçma
##              ileri / modelden eski / tutarsız değer -> UNKNOWN (ASLA ADULT), saat geri alma
##   SAVE       yeni kayıt · eski kayıt · TEEN / ADULT / UNDER_13 · geçiş kalıcılığı · bozuk
##              (yazma yok) · yeniden giriş; ham doğum tarihi kayıtta YOK
##   ROTA       owner tablosu birebir (UNKNOWN / UNDER_13 reklamsız, TEEN TEEN+T, ADULT
##              UNSPECIFIED+MA)
##   GİZLİLİK   yaş dosyalarında log / analitik / ağ çağrısı YOK; panel yalnız türetilmiş
##              sonucu yayar ve rakamları siler
##   UI         boş alanlar (hazır seçim yok), tuş takımı, kendiliğinden ilerleme, sil /
##              temizle, aynı nötr hata, onay adımı, kipler, yasaklı sözcükler, 720×1280 /
##              A36 / 320–360–390 dp pencerelerinde pencere ekranda ve içerik panelde
##
## Kayda yazar (SaveManager senaryoları) — başta yedekler, sonda byte-identical geri koyar.
##
##   godot --headless --audio-driver Dummy --path . res://tools/age_gate_test.tscn

const PANEL_SCENE: PackedScene = preload("res://scenes/ui/age_gate_panel.tscn")
const RESTRICTED_SCENE: PackedScene = preload("res://scenes/ui/age_restricted_screen.tscn")
const TODAY: String = "2026-09-27"
## 320 / 360 / 390 dp telefon oranları + 720×1280 (en kısa tuval) + A36.
const VIEWS: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(640, 1422), Vector2i(720, 1600),
	Vector2i(780, 1688), Vector2i(1080, 2340), Vector2i(540, 960)]
## Nötr ekranda GÖRÜNMEMESİ gereken ifadeler (eşik, reklam, ödül / oyun parası, kilit açma).
const FORBIDDEN_WORDS: Array[String] = ["13", "18", "yetişkin", "reklam", "ödül", "kilit", "altın",
	"sandık", "yıldız", "hediye", "hamur", "unlock", "bonus", "+", "yaş sınırı", "reşit", "çocuk"]

var _fails: int = 0
var _checks: int = 0
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _saved: Dictionary = {}


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	await get_tree().process_frame
	# Önceki koşu yarıda kesildiyse (zaman aşımı / kill) yedeği ÖNCE geri koy.
	_recover_sidecar()
	_saved = SaveManager.data.duplicate(true)
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
		_write_sidecar(_save_bytes)

	_test_calendar()
	_test_boundaries()
	_test_leap_day_births()
	_test_invalid_entries()
	_test_resolve_stored()
	_test_routing_table()
	_test_save_format()
	_test_privacy_static()
	await _test_panel_entry()
	await _test_panel_corrections()
	await _test_panel_modes()
	await _test_panel_neutral_texts()
	await _test_panel_layout()
	await _test_restricted_screen()

	AgeGate.clock_override = ""
	get_window().size = Vector2i(720, 1280)
	SaveManager.data = _saved
	_restore_save_file()
	var restored: bool = not _had_save or FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == _save_bytes
	_c("kayıt dosyası test sonunda byte-identical geri kondu", restored)
	if restored:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SIDECAR_PATH))
	print("=== SONUC: %d/%d kontrol, %d kaldi ===" % [_checks - _fails, _checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


## Yarıda kesilen koşuya karşı yan yedek (kayıt dosyasının ham baytları).
const SIDECAR_PATH: String = "user://squishy_merge_save.json.age_gate_testbak"


func _write_sidecar(bytes: PackedByteArray) -> void:
	var file := FileAccess.open(SIDECAR_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()


func _recover_sidecar() -> void:
	if not FileAccess.file_exists(SIDECAR_PATH):
		return
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(SIDECAR_PATH)
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()
		SaveManager.load_game()
	print("  (önceki yarıda kalan koşunun kayıt yedeği geri kondu)")


func _restore_save_file() -> void:
	if _had_save:
		var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(_save_bytes)
		file.close()
	elif FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))


static func _d(text: String) -> Dictionary:
	return AgeGate.parse_day(text)


func _classify(dob: String, today: String) -> Dictionary:
	var d: Dictionary = _d(dob)
	return AgeGate.classify_birth_date(int(d["year"]), int(d["month"]), int(d["day"]), _d(today))


func _band_is(result: Dictionary, band: int, transition: String) -> bool:
	return bool(result["ok"]) and int(result["band"]) == band and String(result["transition"]) == transition


# --- Takvim ------------------------------------------------------------------------------

func _test_calendar() -> void:
	print("-- takvim: artık yıl, ay uzunluğu, geçerlilik, ayrıştırma, gün numarası, yıl dönümü")
	_c("artık yıl: 2000 / 2024 / 2028 evet; 1900 / 2100 / 2026 hayır", AgeGate.is_leap_year(2000)
		and AgeGate.is_leap_year(2024) and AgeGate.is_leap_year(2028) and not AgeGate.is_leap_year(1900)
		and not AgeGate.is_leap_year(2100) and not AgeGate.is_leap_year(2026))
	_c("ay uzunlukları: Şubat 28 / 29, Nisan 30, Ocak 31, ay 0 / 13 -> 0", AgeGate.days_in_month(2026, 2) == 28
		and AgeGate.days_in_month(2024, 2) == 29 and AgeGate.days_in_month(2026, 4) == 30
		and AgeGate.days_in_month(2026, 1) == 31 and AgeGate.days_in_month(2026, 0) == 0
		and AgeGate.days_in_month(2026, 13) == 0)
	_c("geçerli / geçersiz günler: 29.02.2024 evet; 29.02.2023, 30.02.2024, 31.04.2026, gün 0, yıl 0 hayır",
		AgeGate.is_valid_date(2024, 2, 29) and not AgeGate.is_valid_date(2023, 2, 29)
		and not AgeGate.is_valid_date(2024, 2, 30) and not AgeGate.is_valid_date(2026, 4, 31)
		and not AgeGate.is_valid_date(2026, 5, 0) and not AgeGate.is_valid_date(0, 1, 1))
	var malformed_ok: bool = true
	for bad: Variant in ["", "2026-9-01", "2026/09/01", "20260901", "2026-02-30", "abcd-ef-gh", "+026-01-01",
			" 2026-01-01", "2026-01-01 ", "2026-13-01", "2026-00-10", "2026-01-1a", 20260901, null]:
		if not AgeGate.parse_day(bad).is_empty():
			malformed_ok = false
			print("    kabul edilmemeliydi: ", bad)
	_c("kesin ayrıştırma: biçimsiz / imkânsız / tip dışı değer -> {}", malformed_ok)
	_c("ayrıştır + biçimle gidiş-dönüş", AgeGate.format_day(_d("2031-03-01")) == "2031-03-01"
		and AgeGate.format_day(AgeGate.make_date(7, 8, 9)) == "0007-08-09")
	_c("gün numarası: 1970-01-01 = 0, 2000-03-01 = 11017, 2026-09-27 = 20723",
		AgeGate.day_number(_d("1970-01-01")) == 0 and AgeGate.day_number(_d("2000-03-01")) == 11017
		and AgeGate.day_number(_d("2026-09-27")) == 20723)
	var consecutive: bool = true
	var day: Dictionary = _d("1999-12-25")
	var n: int = AgeGate.day_number(day)
	for i in 800:
		var next: Dictionary = AgeGate.make_date(day["year"], day["month"], day["day"] + 1)
		if not AgeGate.is_valid_date(next["year"], next["month"], next["day"]):
			next = AgeGate.make_date(day["year"], day["month"] + 1, 1)
			if not AgeGate.is_valid_date(next["year"], next["month"], next["day"]):
				next = AgeGate.make_date(day["year"] + 1, 1, 1)
		var m: int = AgeGate.day_number(next)
		consecutive = consecutive and m == n + 1 and AgeGate.compare(next, day) == 1
		day = next
		n = m
	_c("ardışık 800 gün (2000 artık yılı dahil): gün numarası tam +1, karşılaştırma tutarlı", consecutive)
	_c("gün numarası 1900 / 2100 (artık DEĞİL) ve 2000 (artık) Şubat sonu: +1 / +1 / +2",
		AgeGate.day_number(_d("1900-03-01")) - AgeGate.day_number(_d("1900-02-28")) == 1
		and AgeGate.day_number(_d("2100-03-01")) - AgeGate.day_number(_d("2100-02-28")) == 1
		and AgeGate.day_number(_d("2000-03-01")) - AgeGate.day_number(_d("2000-02-28")) == 2)
	var odd_ok: bool = true
	for bad: Variant in ["-001-01-01", "0000-01-01", "\u0662\u0660\u0662\u0666-01-01", "\uff12\uff10\uff12\uff16-01-01",
			"2026-\u0660\u0661-01", "2026-01--1", "2026-+1-01"]:
		if not AgeGate.parse_day(bad).is_empty():
			odd_ok = false
			print("    kabul edilmemeliydi: ", bad)
	_c("ayrıştırma: eksi işaret, 0000 yılı, ASCII dışı rakamlar (Arap-Hint / tam genişlik) -> {}", odd_ok)
	_c("ertesi gün: 28.02.2027 -> 01.03, 28.02.2028 -> 29.02, 31.12 -> 01.01",
		AgeGate.format_day(AgeGate.next_day(_d("2027-02-28"))) == "2027-03-01"
		and AgeGate.format_day(AgeGate.next_day(_d("2028-02-28"))) == "2028-02-29"
		and AgeGate.format_day(AgeGate.next_day(_d("2026-12-31"))) == "2027-01-01")
	_c("saat elverişli mi: model günü (2026-09-27) ve sonrası evet; 2026-09-26, 1970, boş hayır",
		AgeGate.clock_plausible(_d("2026-09-27")) and AgeGate.clock_plausible(_d("2031-01-01"))
		and not AgeGate.clock_plausible(_d("2026-09-26")) and not AgeGate.clock_plausible(_d("1970-01-01"))
		and not AgeGate.clock_plausible({}))
	_c("yıl dönümü: 29.02.2012 +13 -> 01.03.2025; +4 -> 29.02.2016; 28.02 +5 -> 28.02",
		AgeGate.format_day(AgeGate.anniversary(_d("2012-02-29"), 13)) == "2025-03-01"
		and AgeGate.format_day(AgeGate.anniversary(_d("2012-02-29"), 4)) == "2016-02-29"
		and AgeGate.format_day(AgeGate.anniversary(_d("2026-02-28"), 5)) == "2031-02-28"
		and AgeGate.format_day(AgeGate.anniversary(_d("2026-09-27"), -120)) == "1906-09-27")


# --- Sınırlar (owner test tablosu, TASK/043 §19) -------------------------------------------

func _test_boundaries() -> void:
	print("-- sınırlar (bugün %s, enjekte)" % TODAY)
	_c("12 yıl 364 gün -> UNDER_13, geçiş = yarınki 13. yaş günü", _band_is(_classify("2013-09-28", TODAY),
		AgeGate.Band.UNDER_13, "2026-09-28"))
	_c("tam 13. yaş günü -> TEEN, geçiş = 18. yaş günü", _band_is(_classify("2013-09-27", TODAY),
		AgeGate.Band.TEEN, "2031-09-27"))
	_c("17 yaş -> TEEN", _band_is(_classify("2009-03-15", TODAY), AgeGate.Band.TEEN, "2027-03-15"))
	_c("18. yaş gününden BİR GÜN önce -> TEEN, geçiş yarın", _band_is(_classify("2008-09-28", TODAY),
		AgeGate.Band.TEEN, "2026-09-28"))
	_c("tam 18. yaş günü -> ADULT, geçiş YOK", _band_is(_classify("2008-09-27", TODAY), AgeGate.Band.ADULT, ""))
	_c("25 yaş -> ADULT", _band_is(_classify("2001-05-05", TODAY), AgeGate.Band.ADULT, ""))
	_c("bugün doğan -> UNDER_13, geçiş 13 yıl sonra", _band_is(_classify(TODAY, TODAY),
		AgeGate.Band.UNDER_13, "2039-09-27"))
	_c("yıl sonu: 31.12.2008 -> 30.12.2026'da TEEN, 31.12.2026'da ADULT",
		_band_is(_classify("2008-12-31", "2026-12-30"), AgeGate.Band.TEEN, "2026-12-31")
		and _band_is(_classify("2008-12-31", "2026-12-31"), AgeGate.Band.ADULT, ""))
	_c("sonuç doğum tarihini TAŞIMAZ: yalnız ok / error / band / transition anahtarları",
		_classify("2009-03-15", TODAY).keys() == ["ok", "error", "band", "transition"])


func _test_leap_day_births() -> void:
	print("-- 29 Şubat doğumlular + artık gün 'bugün'")
	_c("29.02.2012: 28.02.2025'te UNDER_13 (13'ü 01.03.2025'te doldurur)",
		_band_is(_classify("2012-02-29", "2025-02-28"), AgeGate.Band.UNDER_13, "2025-03-01"))
	_c("29.02.2012: 01.03.2025'te TEEN, 18. yaş günü 01.03.2030",
		_band_is(_classify("2012-02-29", "2025-03-01"), AgeGate.Band.TEEN, "2030-03-01"))
	_c("29.02.2008: 28.02.2026'da TEEN (18'i 01.03.2026'da), 01.03.2026'da ADULT",
		_band_is(_classify("2008-02-29", "2026-02-28"), AgeGate.Band.TEEN, "2026-03-01")
		and _band_is(_classify("2008-02-29", "2026-03-01"), AgeGate.Band.ADULT, ""))
	_c("29.02.2016 doğumlu 29.02.2028'de (artık yıl) 12 -> UNDER_13, geçiş 01.03.2029",
		_band_is(_classify("2016-02-29", "2028-02-29"), AgeGate.Band.UNDER_13, "2029-03-01"))
	_c("bugün 29.02.2028: 28.02.2015 doğumlu TEEN (dün 13), 01.03.2015 doğumlu UNDER_13 (yarın 13)",
		_band_is(_classify("2015-02-28", "2028-02-29"), AgeGate.Band.TEEN, "2033-02-28")
		and _band_is(_classify("2015-03-01", "2028-02-29"), AgeGate.Band.UNDER_13, "2028-03-01"))
	# 13. ve 18. yıl dönümü hiçbir doğum için 29 Şubat'a düşmez (13 ve 18 dörde bölünmez).
	var never_feb29: bool = true
	var day: Dictionary = _d("1996-01-01")
	for i in 12 * 366:
		var t13: Dictionary = AgeGate.anniversary(day, 13)
		var t18: Dictionary = AgeGate.anniversary(day, 18)
		if (t13["month"] == 2 and t13["day"] == 29) or (t18["month"] == 2 and t18["day"] == 29):
			never_feb29 = false
		if AgeGate.format_day(AgeGate.anniversary(t13, 5)) != AgeGate.format_day(t18):
			never_feb29 = false
		var next: Dictionary = AgeGate.make_date(day["year"], day["month"], day["day"] + 1)
		if not AgeGate.is_valid_date(next["year"], next["month"], next["day"]):
			next = AgeGate.make_date(day["year"], day["month"] + 1, 1)
			if not AgeGate.is_valid_date(next["year"], next["month"], next["day"]):
				next = AgeGate.make_date(day["year"] + 1, 1, 1)
		day = next
	_c("1996–2007 her doğum günü: 13. / 18. yaş günü asla 29 Şubat; 18. = 13. + 5 yıl (UNDER_13 -> TEEN geçişi tam)",
		never_feb29)


func _test_invalid_entries() -> void:
	print("-- geçersiz girişler: bant YOK, saklanacak bir şey yok")
	var today: Dictionary = _d(TODAY)
	var invalid: Dictionary = AgeGate.classify_birth_date(2010, 2, 30, today)
	_c("30.02.2010 -> INVALID, UNKNOWN, geçiş boş", not invalid["ok"] and invalid["error"] == AgeGate.EntryError.INVALID
		and invalid["band"] == AgeGate.Band.UNKNOWN and invalid["transition"] == "")
	_c("ay 13 / gün 0 / yıl 0 / 31.04 -> INVALID", AgeGate.classify_birth_date(2010, 13, 1, today)["error"] == AgeGate.EntryError.INVALID
		and AgeGate.classify_birth_date(2010, 5, 0, today)["error"] == AgeGate.EntryError.INVALID
		and AgeGate.classify_birth_date(0, 5, 5, today)["error"] == AgeGate.EntryError.INVALID
		and AgeGate.classify_birth_date(2010, 4, 31, today)["error"] == AgeGate.EntryError.INVALID)
	var future: Dictionary = AgeGate.classify_birth_date(2026, 9, 28, today)
	_c("yarın doğum -> FUTURE, UNKNOWN", not future["ok"] and future["error"] == AgeGate.EntryError.FUTURE
		and future["band"] == AgeGate.Band.UNKNOWN and future["transition"] == "")
	_c("uzak gelecek (2090) -> FUTURE", AgeGate.classify_birth_date(2090, 1, 1, today)["error"] == AgeGate.EntryError.FUTURE)
	var old: Dictionary = AgeGate.classify_birth_date(1906, 9, 26, today)
	_c("120 yıldan bir gün eski -> TOO_OLD; tam 120 yıl -> ADULT", not old["ok"] and old["error"] == AgeGate.EntryError.TOO_OLD
		and _band_is(AgeGate.classify_birth_date(1906, 9, 27, today), AgeGate.Band.ADULT, ""))


# --- Kayıttaki durum ---------------------------------------------------------------------

func _resolve(band: Variant, transition: Variant, today: String) -> Dictionary:
	return AgeGate.resolve_stored(band, transition, _d(today))


func _is(result: Dictionary, band: int, transition: String, changed: bool, corrupt: bool) -> bool:
	return int(result["band"]) == band and String(result["transition"]) == transition \
		and bool(result["changed"]) == changed and bool(result["corrupt"]) == corrupt


func _test_resolve_stored() -> void:
	print("-- kayıt doğrulama + geçişler (bugün 2026-10-01)")
	var t: String = "2026-10-01"
	_c("UNKNOWN / boş -> UNKNOWN (bozuk değil)", _is(_resolve("UNKNOWN", "", t), AgeGate.Band.UNKNOWN, "", false, false))
	_c("ADULT / boş -> ADULT", _is(_resolve("ADULT", "", t), AgeGate.Band.ADULT, "", false, false))
	_c("ADULT + geçiş günü (tutarsız) -> UNKNOWN, bozuk", _is(_resolve("ADULT", "2027-01-01", t), AgeGate.Band.UNKNOWN, "", false, true))
	_c("TEEN, geçiş ileride -> TEEN aynen", _is(_resolve("TEEN", "2027-01-01", t), AgeGate.Band.TEEN, "2027-01-01", false, false))
	_c("TEEN, bugün 18. yaş günü -> ADULT (değişti, geçiş temizlendi)", _is(_resolve("TEEN", t, t), AgeGate.Band.ADULT, "", true, false))
	_c("TEEN, geçiş dün -> ADULT", _is(_resolve("TEEN", "2026-09-30", t), AgeGate.Band.ADULT, "", true, false))
	_c("TEEN, 18. yaş gününden bir gün önce -> TEEN", _is(_resolve("TEEN", "2026-10-02", t), AgeGate.Band.TEEN, "2026-10-02", false, false))
	_c("TEEN + geçiş yok -> UNKNOWN, bozuk", _is(_resolve("TEEN", "", t), AgeGate.Band.UNKNOWN, "", false, true))
	_c("TEEN: bugün + 5 yıl + 2 gün (saat dilimi payı) kabul; +3 gün -> bozuk",
		_is(_resolve("TEEN", "2031-10-03", t), AgeGate.Band.TEEN, "2031-10-03", false, false)
		and _is(_resolve("TEEN", "2031-10-04", t), AgeGate.Band.UNKNOWN, "", false, true))
	_c("TEEN + 29 Şubat geçişi (hiçbir 18. yaş günü olamaz) -> bozuk", _is(_resolve("TEEN", "2028-02-29", t), AgeGate.Band.UNKNOWN, "", false, true))
	_c("TEEN + imkânsız / biçimsiz tarih -> bozuk", _is(_resolve("TEEN", "2027-02-30", t), AgeGate.Band.UNKNOWN, "", false, true)
		and _is(_resolve("TEEN", "2027-1-01", t), AgeGate.Band.UNKNOWN, "", false, true)
		and _is(_resolve("TEEN", 20270101, t), AgeGate.Band.UNKNOWN, "", false, true))
	_c("TEEN + modelden eski geçiş (2026-09-27 < 2026-09-28) -> bozuk, ASLA 'çoktan yetişkin'",
		_is(_resolve("TEEN", "2026-09-27", t), AgeGate.Band.UNKNOWN, "", false, true)
		and _is(_resolve("UNDER_13", "1990-01-01", t), AgeGate.Band.UNKNOWN, "", false, true))
	_c("UNDER_13, geçiş ileride -> UNDER_13", _is(_resolve("UNDER_13", "2030-01-01", t), AgeGate.Band.UNDER_13, "2030-01-01", false, false))
	_c("UNDER_13, bugün 13. yaş günü -> TEEN, yeni geçiş = +5 yıl (18. yaş günü)",
		_is(_resolve("UNDER_13", t, t), AgeGate.Band.TEEN, "2031-10-01", true, false))
	_c("UNDER_13 çok önce kaydedildi (13. ve 18. yaş günü geçti) -> ADULT",
		_is(_resolve("UNDER_13", "2026-09-29", "2031-09-29"), AgeGate.Band.ADULT, "", true, false))
	_c("UNDER_13: bugün + 13 yıl + 2 gün kabul; +3 gün -> bozuk",
		_is(_resolve("UNDER_13", "2039-10-03", t), AgeGate.Band.UNDER_13, "2039-10-03", false, false)
		and _is(_resolve("UNDER_13", "2039-10-04", t), AgeGate.Band.UNKNOWN, "", false, true))
	var junk_ok: bool = true
	for junk: Variant in ["teen", "Teen", "CHILD", "ADULTS", "", 2, null, {"b": 1}, true]:
		junk_ok = junk_ok and _is(_resolve(junk, "2027-01-01", t), AgeGate.Band.UNKNOWN, "", false, true)
	_c("bilinmeyen bant değeri / tip (küçük harf, CHILD, sayı, null, sözlük, bool) -> UNKNOWN, bozuk", junk_ok)
	_c("saat 3 yıl GERİ alındı (TEEN geçişi artık > 5 yıl ileride) -> UNKNOWN (yaş yeniden sorulur, fail-closed)",
		_is(_resolve("TEEN", "2030-06-01", "2023-10-01"), AgeGate.Band.UNKNOWN, "", false, true))
	_c("saat biraz geri (bir gün) -> TEEN korunur", _is(_resolve("TEEN", "2030-06-01", "2026-09-30"), AgeGate.Band.TEEN, "2030-06-01", false, false))
	_c("saat İLERİ alındı (18. yaş gününü geçti) -> ADULT (yerel saat kimlik doğrulaması değil — kabul, AGE_BAND_ROUTING §5)",
		_is(_resolve("TEEN", "2030-06-01", "2031-01-01"), AgeGate.Band.ADULT, "", true, false))
	_c("en erken geçiş günü tam 2026-09-28 kabul (TEEN sürer), 2026-09-27 -> bozuk",
		_is(_resolve("TEEN", "2026-09-28", "2026-09-27"), AgeGate.Band.TEEN, "2026-09-28", false, false)
		and _is(_resolve("TEEN", "2026-09-27", "2026-09-27"), AgeGate.Band.UNKNOWN, "", false, true))
	_c("UNDER_13, 13. yaş gününden BİR gün önce -> UNDER_13 sürer (değişiklik yok)",
		_is(_resolve("UNDER_13", "2030-05-10", "2030-05-09"), AgeGate.Band.UNDER_13, "2030-05-10", false, false))
	_c("UNDER_13 zinciri: 18. yaş gününden bir gün önce TEEN (geçiş 18. yaş günü), o gün ADULT",
		_is(_resolve("UNDER_13", "2030-05-10", "2035-05-09"), AgeGate.Band.TEEN, "2035-05-10", true, false)
		and _is(_resolve("UNDER_13", "2030-05-10", "2035-05-10"), AgeGate.Band.ADULT, "", true, false))
	_c("29 Şubat kenarında 2 günlük pay tam: 2027-03-01'de kaydedilen TEEN (geçiş 2032-03-01), saat 2027-02-27 -> TEEN",
		_is(_resolve("TEEN", "2032-03-01", "2027-02-27"), AgeGate.Band.TEEN, "2032-03-01", false, false)
		and _is(_resolve("TEEN", "2032-03-01", "2027-02-26"), AgeGate.Band.UNKNOWN, "", false, true))


# --- Rota tablosu ------------------------------------------------------------------------

func _test_routing_table() -> void:
	print("-- owner yönlendirme tablosu (birebir)")
	var unknown: Dictionary = AgeGate.ad_route(AgeGate.Band.UNKNOWN)
	var under: Dictionary = AgeGate.ad_route(AgeGate.Band.UNDER_13)
	var teen: Dictionary = AgeGate.ad_route(AgeGate.Band.TEEN)
	var adult: Dictionary = AgeGate.ad_route(AgeGate.Band.ADULT)
	_c("UNKNOWN -> reklam YOK", not unknown["ads"])
	_c("UNDER_13 -> reklam YOK (CHILD ile sürdürmek YOK)", not under["ads"])
	_c("TEEN -> TFAT TEEN + derece T", teen["ads"] and teen["treatment"] == AdBackend.AgeRestrictedTreatment.TEEN
		and teen["max_ad_content_rating"] == "T")
	_c("ADULT -> TFAT UNSPECIFIED + derece MA", adult["ads"] and adult["treatment"] == AdBackend.AgeRestrictedTreatment.UNSPECIFIED
		and adult["max_ad_content_rating"] == "MA")
	_c("TEEN'e MA verilmez, hiçbir banda CHILD verilmez", teen["max_ad_content_rating"] != "MA"
		and teen["treatment"] != AdBackend.AgeRestrictedTreatment.CHILD and adult["treatment"] != AdBackend.AgeRestrictedTreatment.CHILD)
	_c("sözleşme denetimi temiz (release kapısı bunu okur)", AgeGate.routing_contract_problems().is_empty())
	_c("geçersiz bant değeri (ör. 9) -> reklam YOK", not AgeGate.ad_route(9)["ads"] and not AgeGate.ad_route(-1)["ads"])
	_c("kayıt çifti: TEEN / UNDER_13 geçişi tutar, ADULT / UNKNOWN tarih TUTMAZ",
		AgeGate.stored_pair(AgeGate.Band.TEEN, "2027-01-01") == ["TEEN", "2027-01-01"]
		and AgeGate.stored_pair(AgeGate.Band.UNDER_13, "2030-01-01") == ["UNDER_13", "2030-01-01"]
		and AgeGate.stored_pair(AgeGate.Band.ADULT, "2027-01-01") == ["ADULT", ""]
		and AgeGate.stored_pair(AgeGate.Band.UNKNOWN, "2027-01-01") == ["UNKNOWN", ""])


# --- Kayıt biçimi ------------------------------------------------------------------------

func _write_save(data: Dictionary) -> void:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _disk_text() -> String:
	return FileAccess.get_file_as_string(SaveManager.SAVE_PATH)


func _test_save_format() -> void:
	print("-- kayıt: anahtarlar, eski kayıt, kalıcılık, bozuk kayıt, yeniden giriş, ham tarih YOK")
	var today: Dictionary = _d("2026-10-01")
	_c("DEFAULT_DATA: age_ad_band UNKNOWN + next_age_transition_date boş (iki anahtar, doğum tarihi anahtarı yok)",
		SaveManager.DEFAULT_DATA["age_ad_band"] == "UNKNOWN" and SaveManager.DEFAULT_DATA["next_age_transition_date"] == ""
		and not _has_dob_key(SaveManager.DEFAULT_DATA))
	# Yeni kayıt (dosya yok).
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	SaveManager.load_game()
	_c("yeni kayıt -> UNKNOWN", SaveManager.stored_age_band(today) == AgeGate.Band.UNKNOWN
		and SaveManager.age_ad_band_raw() == "UNKNOWN")
	# Eski kayıt (anahtarsız, ilerlemeli).
	_write_save({"highest_level_unlocked": 6, "dough": 420, "onboarding_completed": true, "last_login_date": "2026-09-30",
		"powerup_starter_granted": true})
	var legacy_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	SaveManager.load_game()
	_c("eski kayıt dosyasında yaş anahtarı yok; yüklemede varsayılan UNKNOWN (bellekte), dosya değişmedi",
		not _disk_text().contains("age_ad_band") and SaveManager.age_ad_band_raw() == "UNKNOWN"
		and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == legacy_bytes)
	var legacy_band: int = SaveManager.resolve_age_band_at_launch(today)
	_c("eski kayıt (anahtar yok) -> UNKNOWN; açılışta YAZMA yok; ilerleme duruyor (level 6, 420 Hamur)",
		legacy_band == AgeGate.Band.UNKNOWN and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == legacy_bytes
		and SaveManager.highest_level_unlocked() == 6 and SaveManager.dough() == 420)
	# Sınıflandır + kaydet (TEEN): ham doğum tarihi kayda GİRMEZ.
	var teen: Dictionary = AgeGate.classify_birth_date(2009, 7, 23, today)
	SaveManager.store_age_band(teen["band"], teen["transition"])
	var text: String = _disk_text()
	_c("TEEN kaydedildi: diskte TEEN + 18. yaş günü, tek iki alan", text.contains("\"age_ad_band\": \"TEEN\"")
		and text.contains("\"next_age_transition_date\": \"2027-07-23\""))
	_c("ham doğum tarihi diskte YOK (2009-07-23 / 23.07.2009 / 2009 / doğum anahtarı)", not text.contains("2009-07-23")
		and not text.contains("23.07.2009") and not text.contains("2009") and not _has_dob_key(JSON.parse_string(text)))
	SaveManager.load_game()
	_c("yeniden yükle -> TEEN", SaveManager.stored_age_band(today) == AgeGate.Band.TEEN)
	# ADULT: tarih YOK.
	SaveManager.store_age_band(AgeGate.Band.ADULT, "2027-07-23")
	text = _disk_text()
	_c("ADULT kaydedildi, geçiş günü BOŞ (yetişkinde hiçbir tarih yok)", text.contains("\"age_ad_band\": \"ADULT\"")
		and text.contains("\"next_age_transition_date\": \"\"") and not text.contains("2027-07-23"))
	# UNDER_13.
	var child: Dictionary = AgeGate.classify_birth_date(2016, 4, 2, today)
	SaveManager.store_age_band(child["band"], child["transition"])
	SaveManager.load_game()
	_c("UNDER_13 kaydedildi (13. yaş günü) ve yeniden yüklendi", SaveManager.stored_age_band(today) == AgeGate.Band.UNDER_13
		and SaveManager.next_age_transition_raw() == "2029-04-02" and not _disk_text().contains("2016"))
	# Geçiş kalıcılığı (soğuk açılış).
	SaveManager.store_age_band(AgeGate.Band.TEEN, "2026-10-05")
	var before_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_c("18. yaş gününden önce açılış: TEEN, yazma YOK", SaveManager.resolve_age_band_at_launch(_d("2026-10-04")) == AgeGate.Band.TEEN
		and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == before_bytes)
	_c("tam 18. yaş günü açılış: ADULT kalıcılaştı (tek yazma), geçiş temizlendi",
		SaveManager.resolve_age_band_at_launch(_d("2026-10-05")) == AgeGate.Band.ADULT
		and _disk_text().contains("\"age_ad_band\": \"ADULT\"") and SaveManager.next_age_transition_raw() == "")
	SaveManager.store_age_band(AgeGate.Band.UNDER_13, "2026-10-05")
	_c("13. yaş günü açılış: UNDER_13 -> TEEN kalıcı, yeni geçiş 18. yaş günü",
		SaveManager.resolve_age_band_at_launch(_d("2026-10-05")) == AgeGate.Band.TEEN
		and SaveManager.age_ad_band_raw() == "TEEN" and SaveManager.next_age_transition_raw() == "2031-10-05")
	# Bozuk kayıt: UNKNOWN, YAZMA yok.
	SaveManager.data["age_ad_band"] = "ADULT"
	SaveManager.data["next_age_transition_date"] = "2031-01-01"
	SaveManager.save_game()
	var corrupt_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_c("bozuk kayıt (ADULT + tarih) -> UNKNOWN, diske yazma YOK", SaveManager.resolve_age_band_at_launch(today) == AgeGate.Band.UNKNOWN
		and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == corrupt_bytes)
	SaveManager.data["age_ad_band"] = 7
	_c("bozuk kayıt (sayı) -> UNKNOWN", SaveManager.stored_age_band(today) == AgeGate.Band.UNKNOWN)
	# Yeniden giriş (üzerine yazar).
	SaveManager.store_age_band(AgeGate.Band.ADULT, "")
	SaveManager.store_age_band(AgeGate.Band.TEEN, "2028-01-01")
	_c("yeniden giriş üzerine yazar: ADULT -> TEEN (tek kayıt, geçiş yeni)", SaveManager.age_ad_band_raw() == "TEEN"
		and SaveManager.next_age_transition_raw() == "2028-01-01")
	_c("store_age_band doğum tarihi parametresi ALMAZ (bant + geçiş)", _method_args(SaveManager, "store_age_band") == ["band", "transition"])


static func _has_dob_key(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	for key: String in data:
		var lower: String = key.to_lower()
		if lower.contains("birth") or lower.contains("dob") or lower.contains("dogum") or lower.contains("doğum") \
				or lower == "age" or lower.contains("birthday"):
			return true
	return false


static func _method_args(object: Object, method: String) -> Array:
	for info: Dictionary in object.get_method_list():
		if info["name"] == method:
			var names: Array = []
			for arg: Dictionary in info["args"]:
				names.append(arg["name"])
			return names
	return []


# --- Gizlilik (statik) -------------------------------------------------------------------

## Yorum satırları hariç kaynak satırları.
static func _code_lines(path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#") or stripped.is_empty():
			continue
		out.append(stripped)
	return out


func _test_privacy_static() -> void:
	print("-- gizlilik: yaş kodunda log / analitik / ağ YOK; panel yalnız türetilmiş sonucu yayar")
	var sinks: Array[String] = ["print(", "prints(", "printt(", "print_verbose(", "print_rich(", "printerr(", "printraw(",
		"print_debug(", "print_stack(", "push_warning(", "push_error(", "AdEvents.", "TutorialEvents.", "OS.alert(",
		"OS.add_logger(", "HTTPRequest", "HTTPClient", "StreamPeer", "PacketPeer", "WebSocket", "JavaScriptBridge",
		"OS.shell_open(", "clipboard_set(", "FileAccess.open(", "ResourceSaver.", "ConfigFile", ".save(", "save_game(",
		"Engine.get_singleton("]
	var hits: PackedStringArray = PackedStringArray()
	for path in ["res://scripts/game/age_gate.gd", "res://scripts/ui/age_gate_panel.gd",
			"res://scripts/ui/age_restricted_screen.gd"]:
		for line in _code_lines(path):
			for sink in sinks:
				if line.contains(sink):
					hits.append("%s: %s" % [path.get_file(), line])
	_c("age_gate.gd / age_gate_panel.gd / age_restricted_screen.gd: log, analitik olayı, ağ, dosya yazımı YOK %s" % str(hits),
		hits.is_empty())
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var start: int = main_src.find("# --- Nötr yaş ekranı + yaş bandı yönlendirmesi (TASK/043) ---")
	var end: int = main_src.find("\n# --- Ekranlar ---", start)
	var section: String = main_src.substr(start, end - start) if start != -1 and end != -1 else ""
	var main_hits: PackedStringArray = PackedStringArray()
	for sink in ["print(", "prints(", "printt(", "print_verbose(", "print_rich(", "printerr(", "printraw(",
			"print_debug(", "push_warning(", "push_error(", "OS.alert(", "clipboard_set(", "AdEvents.", "TutorialEvents."]:
		if section.contains(sink):
			main_hits.append(sink)
	_c("Main'in yaş bölümü bulundu ve log / analitik YOK %s" % str(main_hits), not section.is_empty() and main_hits.is_empty())
	var save_src: String = FileAccess.get_file_as_string("res://scripts/autoload/save_manager.gd")
	var s0: int = save_src.find("# --- Yaş bandı (TASK/043")
	var s1: int = save_src.find("# --- Günlük ödüller", s0)
	var save_section: String = save_src.substr(s0, s1 - s0) if s0 != -1 and s1 != -1 else ""
	_c("SaveManager yaş bölümü: log YOK, tek yazma yolu store_age_band", not save_section.is_empty()
		and not save_section.contains("print") and not save_section.contains("push_")
		and save_section.count("save_game()") == 1)
	var manager_src: String = FileAccess.get_file_as_string("res://scripts/ads/monetization_manager.gd")
	_c("reklam yöneticisi doğum tarihi / yaş sayısı bilmez (yalnız bant)", not manager_src.contains("birth")
		and not manager_src.contains("classify_birth_date") and manager_src.contains("func set_age_band(band: int)"))
	var panel: CanvasLayer = PANEL_SCENE.instantiate()
	var resolved_args: Array = []
	for info: Dictionary in panel.get_signal_list():
		if info["name"] == "resolved":
			for arg: Dictionary in info["args"]:
				resolved_args.append(arg["name"])
	panel.free()
	_c("panelin tek çıkışı resolved(band, transition) — doğum tarihi sinyalde YOK", resolved_args == ["band", "transition"])


# --- Panel ---------------------------------------------------------------------------------

func _make_panel() -> CanvasLayer:
	var panel: CanvasLayer = PANEL_SCENE.instantiate()
	add_child(panel)
	await get_tree().process_frame
	return panel


func _type(panel: CanvasLayer, digits: String) -> void:
	for ch in digits:
		(panel.key_button(ch) as Button).pressed.emit()


func _test_panel_entry() -> void:
	print("-- panel: boş alanlar, tuş takımı, kendiliğinden ilerleme, hata, onay")
	AgeGate.clock_override = TODAY
	var panel: CanvasLayer = await _make_panel()
	var got: Array = []
	panel.resolved.connect(func(band: int, transition: String) -> void: got.append([band, transition]))
	panel.open_required()
	await get_tree().process_frame
	_c("açıldı: ZORUNLU kip, GİRİŞ adımı, üç alan BOŞ (GG / AA / YYYY — hazır tarih YOK), etkin alan gün",
		panel.visible and panel.is_reentry() == false and panel.field_text(0) == "GG" and panel.field_text(1) == "AA"
		and panel.field_text(2) == "YYYY" and panel.field_lengths() == [0, 0, 0] and panel.active_field() == 0)
	_c("DEVAM pasif (eksik tarih), X ve Vazgeç YOK (zorunlu)", panel.continue_button().disabled
		and not panel.close_x().visible and not panel.cancel_button().visible)
	_type(panel, "23")
	_c("gün 2 hane -> ay alanına geçti", panel.field_text(0) == "23" and panel.active_field() == 1)
	_type(panel, "07")
	_c("ay 2 hane -> yıl alanına geçti", panel.field_text(1) == "07" and panel.active_field() == 2)
	_type(panel, "200")
	_c("yıl eksik -> DEVAM hâlâ pasif", panel.continue_button().disabled and panel.field_lengths() == [2, 2, 3])
	_type(panel, "99")
	_c("yıl 4 haneden fazlasını almaz; tarih tam -> DEVAM etkin", panel.field_text(2) == "2009"
		and not panel.continue_button().disabled)
	(panel.key_button("del") as Button).pressed.emit()
	(panel.key_button("del") as Button).pressed.emit()
	(panel.key_button("del") as Button).pressed.emit()
	(panel.key_button("del") as Button).pressed.emit()
	(panel.key_button("del") as Button).pressed.emit()
	_c("Sil: boş alandan önceki alana döner ve siler", panel.field_lengths() == [2, 1, 0] and panel.active_field() == 1)
	(panel.key_button("clear") as Button).pressed.emit()
	_c("Temizle: üç alan boş, etkin alan gün", panel.field_lengths() == [0, 0, 0] and panel.active_field() == 0)
	_type(panel, "5")
	_c("gün tek hane 4–9 -> hemen aya geçer", panel.field_text(0) == "5" and panel.active_field() == 1)
	_type(panel, "1")
	_c("ay '1' -> ikinci haneyi bekler", panel.active_field() == 1)
	(panel.key_button("clear") as Button).pressed.emit()
	panel.select_field(2)
	_type(panel, "2010")
	panel.select_field(0)
	_type(panel, "31")
	_type(panel, "02")
	_c("alana dokunup seçme çalışır (önce yıl, sonra gün / ay)", panel.field_text(2) == "2010"
		and panel.field_text(0) == "31" and panel.field_text(1) == "02")
	panel.continue_button().pressed.emit()
	await get_tree().process_frame
	_c("31.02.2010 -> nötr hata, GİRİŞ adımında kalır, sonuç yok", panel.error_visible() and panel.stage() == 0 and got.is_empty())
	var invalid_error: String = panel.error_text()
	(panel.key_button("clear") as Button).pressed.emit()
	_c("tuşa basınca hata gizlenir", not panel.error_visible())
	_type(panel, "01012027")
	panel.continue_button().pressed.emit()
	await get_tree().process_frame
	_c("gelecek tarih -> AYNI nötr hata metni (geçersizle aynı; sebep ayırt edilmez)", panel.error_visible() and got.is_empty()
		and panel.error_text() == invalid_error and invalid_error == panel.ERROR_TEXT)
	(panel.key_button("clear") as Button).pressed.emit()
	_type(panel, "01011890")
	panel.continue_button().pressed.emit()
	_c("120 yıldan eski -> yine AYNI nötr hata", panel.error_visible() and got.is_empty() and panel.error_text() == invalid_error)
	(panel.key_button("clear") as Button).pressed.emit()
	_type(panel, "23072009")
	panel.continue_button().pressed.emit()
	await get_tree().process_frame
	_c("geçerli -> ONAY adımı: '23 Temmuz 2009', tuş takımı gizli", panel.stage() == 1
		and panel.confirm_text() == "23 Temmuz 2009" and not (panel.key_button("1") as Button).is_visible_in_tree())
	panel.fix_button().pressed.emit()
	await get_tree().process_frame
	_c("DÜZELT -> girişe döner, giriş BOŞALTILDI (baştan girilir), etkin alan gün", panel.stage() == 0
		and panel.field_lengths() == [0, 0, 0] and panel.active_field() == 0 and panel.continue_button().disabled)
	_type(panel, "23072009")
	panel.continue_button().pressed.emit()
	panel.confirm_button().pressed.emit()
	await get_tree().process_frame
	_c("ONAYLA -> resolved(TEEN, 2027-07-23) tam bir kez", got.size() == 1 and got[0] == [AgeGate.Band.TEEN, "2027-07-23"])
	_c("onaydan sonra rakamlar SİLİNDİ (bellekte doğum tarihi yok), onay metni boş",
		panel.field_lengths() == [0, 0, 0] and panel.confirm_text() == "")
	panel.close_panel()
	# Her sınır aynı onay adımından geçer (yalnız bazı yaşlara onay = eşiği ele verirdi).
	var stages: Array = []
	for dob in ["28092013", "27092013", "27092008", "05052001"]:
		panel.open_required()
		_type(panel, dob)
		panel.continue_button().pressed.emit()
		stages.append(panel.stage())
		panel.confirm_button().pressed.emit()
	_c("12y364g / 13 / 18 / 25: hepsi AYNI onay adımı, sonuçlar UNDER_13 / TEEN / ADULT / ADULT",
		stages == [1, 1, 1, 1] and got.size() == 5 and got[1][0] == AgeGate.Band.UNDER_13 and got[2][0] == AgeGate.Band.TEEN
		and got[3][0] == AgeGate.Band.ADULT and got[4][0] == AgeGate.Band.ADULT and got[3][1] == "" and got[1][1] == "2026-09-28")
	panel.queue_free()
	await get_tree().process_frame


func _test_panel_corrections() -> void:
	print("-- panel: dolu alanı düzeltme, taşma, bozuk saat")
	AgeGate.clock_override = TODAY
	var panel: CanvasLayer = await _make_panel()
	var got: Array = []
	panel.resolved.connect(func(band: int, transition: String) -> void: got.append([band, transition]))
	panel.open_required()
	_type(panel, "23012009")
	panel.select_field(0)
	_type(panel, "2")
	_c("dolu GÜN alanına dokunup yazmak onu baştan yazar (ay / yıl dokunulmadı, ay 2 haneyi AŞMAZ)",
		panel.field_text(0) == "2" and panel.field_text(1) == "01" and panel.field_text(2) == "2009"
		and panel.field_lengths() == [1, 2, 4] and panel.active_field() == 0)
	_type(panel, "5")
	_type(panel, "7")
	_c("gün tamamlanınca fazla rakam dolu alanlara TAŞMAZ (yok sayılır): 25 / 01 / 2009",
		panel.field_text(0) == "25" and panel.field_text(1) == "01" and panel.field_text(2) == "2009"
		and panel.field_lengths() == [2, 2, 4])
	panel.select_field(2)
	(panel.key_button("del") as Button).pressed.emit()
	_c("dolu alanı seçip Sil: yalnız o alanın son hanesi silinir", panel.field_text(2) == "200" and panel.active_field() == 2)
	_type(panel, "8")
	_type(panel, "3")
	_c("yıl 4 haneyi aşmaz", panel.field_text(2) == "2008" and panel.field_lengths() == [2, 2, 4])
	panel.select_field(1)
	_type(panel, "12")
	_c("dolu AY alanını baştan yazma: 12 (asla 3 hane)", panel.field_text(1) == "12" and panel.field_lengths() == [2, 2, 4])
	panel.continue_button().pressed.emit()
	_c("düzeltilmiş tarih onayda: '25 Aralık 2008'", panel.stage() == 1 and panel.confirm_text() == "25 Aralık 2008")
	panel.fix_button().pressed.emit()
	_type(panel, "4")
	panel.select_field(0)
	_type(panel, "1")
	_c("tek haneli dolu gün (4) seçilip yazılınca baştan: '1', ikinci haneyi bekler", panel.field_text(0) == "1"
		and panel.active_field() == 0)
	(panel.key_button("clear") as Button).pressed.emit()
	# Bozuk saat (modelden önce): hiçbir tarih sınıflandırılmaz, AYNI nötr hata.
	AgeGate.clock_override = "2026-09-26"
	_type(panel, "01011990")
	panel.continue_button().pressed.emit()
	_c("saat modelden önce -> geçerli tarih de AYNI nötr hata, sonuç yok", panel.error_visible() and panel.stage() == 0
		and panel.error_text() == panel.ERROR_TEXT and got.is_empty())
	AgeGate.clock_override = TODAY
	panel.continue_button().pressed.emit()
	AgeGate.clock_override = "1970-01-01"
	panel.confirm_button().pressed.emit()
	_c("onay anında saat bozulduysa da sonuç YOK (yeniden sınıflandırma), rakamlar silindi", got.is_empty()
		and panel.stage() == 0 and panel.error_visible() and panel.field_lengths() == [0, 0, 0])
	AgeGate.clock_override = TODAY
	panel.close_panel()
	panel.queue_free()
	await get_tree().process_frame


func _test_panel_modes() -> void:
	print("-- panel: zorunlu / yeniden giriş kipleri, geri, tamam")
	AgeGate.clock_override = TODAY
	var panel: CanvasLayer = await _make_panel()
	var got: Array = []
	var closed: Array = []
	panel.resolved.connect(func(band: int, transition: String) -> void: got.append([band, transition]))
	panel.closed.connect(func() -> void: closed.append(true))
	panel.open_required()
	_c("zorunlu kipte geri tüketilmez (Main uygulamadan çıkar)", not panel.handle_back() and panel.visible)
	panel.close_panel()
	panel.open_reentry()
	await get_tree().process_frame
	_c("yeniden giriş: X + Vazgeç görünür, alanlar BOŞ (kayıtlı yaş / tarih GÖSTERİLMEZ)", panel.is_reentry()
		and panel.close_x().visible and panel.cancel_button().visible and panel.field_lengths() == [0, 0, 0])
	_type(panel, "12")
	panel.cancel_button().pressed.emit()
	_c("Vazgeç: kapandı, closed 1, sonuç YOK, rakamlar silindi", not panel.visible and closed.size() == 1 and got.is_empty()
		and panel.field_lengths() == [0, 0, 0])
	panel.open_reentry()
	_c("geri tuşu yeniden girişte vazgeç", panel.handle_back() and not panel.visible and closed.size() == 2)
	panel.open_reentry()
	_type(panel, "01011990")
	panel.continue_button().pressed.emit()
	panel.confirm_button().pressed.emit()
	_c("yeniden giriş sonucu yayıldı (ADULT)", got.size() == 1 and got[0][0] == AgeGate.Band.ADULT)
	panel.show_done(true)
	await get_tree().process_frame
	var done_next: PackedStringArray = panel.visible_texts()
	_c("TAMAM adımı + nötr not (NEXT_LAUNCH yalnız teşhiste)", panel.stage() == 2
		and panel.done_note_visible() and panel.done_next_launch() and panel.done_button().visible and not panel.close_x().visible)
	panel.done_button().pressed.emit()
	_c("TAMAM -> kapandı, closed", not panel.visible and closed.size() == 3)
	panel.open_reentry()
	panel.show_done(false)
	await get_tree().process_frame
	var done_same: PackedStringArray = panel.visible_texts()
	_c("değişiklik oturuma uygulanabildiyse de AYNI metin + not (ekran cevabı ele vermez)", panel.done_note_visible()
		and not panel.done_next_launch() and done_same == done_next)
	var done_bad: PackedStringArray = PackedStringArray()
	for text in done_next:
		for word in FORBIDDEN_WORDS:
			if text.to_lower().contains(word):
				done_bad.append("'%s' ⊃ %s" % [text, word])
	_c("'kaydedildi' adımında da yasaklı sözcük / eşik / reklam yok %s" % str(done_bad), done_bad.is_empty())
	panel.close_panel()
	panel.queue_free()
	await get_tree().process_frame


func _test_panel_neutral_texts() -> void:
	print("-- panel: nötr metin (eşik / reklam / ödül / kilit / yönlendirme YOK)")
	AgeGate.clock_override = TODAY
	var panel: CanvasLayer = await _make_panel()
	panel.open_required()
	await get_tree().process_frame
	var texts: PackedStringArray = panel.visible_texts()
	_type(panel, "31022010")
	panel.continue_button().pressed.emit()
	texts.append_array(panel.visible_texts())
	(panel.key_button("clear") as Button).pressed.emit()
	_type(panel, "15062011")
	panel.continue_button().pressed.emit()
	texts.append_array(panel.visible_texts())
	var bad: PackedStringArray = PackedStringArray()
	for text in texts:
		var lower: String = text.to_lower()
		for word in FORBIDDEN_WORDS:
			if lower.contains(word) and not (word == "13" and text == "15 Haziran 2011"):
				bad.append("'%s' ⊃ %s" % [text, word])
	_c("giriş + hata + onay adımlarında yasaklı sözcük / eşik yok %s" % str(bad), bad.is_empty())
	_c("başlık 'Doğum tarihin', istem nötr", texts.has("Doğum tarihin") and texts.has(panel.PROMPT))
	_c("tepelik (taç + yıldız sanatı) YOK — nötr pencere", panel.frame().get_node_or_null("Topper") == null)
	panel.close_panel()
	panel.queue_free()
	await get_tree().process_frame


func _test_panel_layout() -> void:
	print("-- panel: pencereler (720×1280 en kısa tuval, 320 / 360 / 390 dp oranları, A36)")
	AgeGate.clock_override = TODAY
	var panel: CanvasLayer = await _make_panel()
	for view in VIEWS:
		get_window().size = view
		await get_tree().process_frame
		await get_tree().process_frame
		panel.open_required()
		for i in 4:
			await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		var canvas: Rect2 = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		var frame: Control = panel.frame()
		var body_panel: Control = frame.get_meta(&"panel")
		var frame_rect: Rect2 = frame.get_global_rect()
		var inside: bool = canvas.encloses(frame_rect) and frame_rect.position.y - UiKit.MODAL_TOPPER_OVERHANG >= -0.5
		var keys_ok: bool = true
		for label in ["1", "5", "9", "0", "del", "clear"]:
			var key: Button = panel.key_button(label)
			keys_ok = keys_ok and body_panel.get_global_rect().encloses(key.get_global_rect()) and key.size.y >= 64.0
		for i in 3:
			keys_ok = keys_ok and body_panel.get_global_rect().encloses(panel.field_button(i).get_global_rect())
		var cta: Button = panel.continue_button()
		_c("%dx%d (tuval %dx%d): pencere ekranda, tuşlar + alanlar + DEVAM panelde, tuş ≥ 64 px, gövde kaydırılmıyor" % [
				view.x, view.y, int(canvas.size.x), int(canvas.size.y)],
			inside and keys_ok and body_panel.get_global_rect().encloses(cta.get_global_rect())
			and not bool(frame.get_meta(&"body_scrolls", false)))
		panel.close_panel()
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame
	panel.queue_free()
	await get_tree().process_frame


func _test_restricted_screen() -> void:
	print("-- 13 altı kısıt ekranı: nötr, eşik yok, tekrar dene yok, ödül yok")
	var screen: CanvasLayer = RESTRICTED_SCENE.instantiate()
	add_child(screen)
	await get_tree().process_frame
	var exits: Array = []
	screen.exit_requested.connect(func() -> void: exits.append(true))
	screen.open_screen()
	await get_tree().process_frame
	var texts: PackedStringArray = screen.visible_texts()
	var bad: PackedStringArray = PackedStringArray()
	for text in texts:
		for word in ["13", "18", "reklam", "tekrar", "dene", "değiştir", "ebeveyn", "izin", "ödül", "sandık", "hamur", "yıldız"]:
			if text.to_lower().contains(word):
				bad.append("'%s' ⊃ %s" % [text, word])
	_c("metinler nötr: eşik yaş, tekrar dene, ebeveyn izni, ödül YOK %s" % str(bad), bad.is_empty() and texts.size() >= 3)
	_c("katman 30 (her şeyin üstünde), tam ekran zemin dokunuşu durdurur", screen.layer == 30
		and (screen.get_node("Center/Backdrop") as Control).mouse_filter == Control.MOUSE_FILTER_STOP)
	_c("ilerleme notu var, tek eylem ÇIKIŞ", texts.has(screen.PROGRESS_NOTE) and screen.exit_button().text == "ÇIKIŞ")
	screen.exit_button().pressed.emit()
	_c("ÇIKIŞ -> exit_requested (Main uygulamadan çıkar)", exits.size() == 1)
	screen.queue_free()
	await get_tree().process_frame
