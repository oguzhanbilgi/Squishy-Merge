extends Node
## TASK/043 + TASK/046.1 — yaş ekranı modeli + kaydı + UI deterministik testi (İNTERNET, CİHAZ,
## EKLENTİ YOK; saat `AgeGate.clock_override` ile enjekte edilir). docs/monetization/
## AGE_BAND_ROUTING.md.
##
##   TAKVİM     artık yıl (1900 / 2000 / 2024 / 2100), ay uzunlukları, geçersiz tarihler,
##              kesin YYYY-MM-DD ayrıştırma, gün numarası, 29 Şubat yıl dönümü -> 1 Mart
##   SINIRLAR   ham sınıflandırıcı: 12y364g -> UNDER_13 · tam 13. yaş günü -> TEEN · 17 -> TEEN ·
##              18'den bir gün önce -> TEEN · tam 18. yaş günü -> ADULT · 25 -> ADULT · geçersiz /
##              gelecek / 120 yıldan eski -> bant YOK; 29 Şubat doğumlular; artık gün "bugün"
##   13+        (TASK/046.1) en genç / en eski seçilebilir doğum günü (29 Şubat "bugün"ü dahil),
##              ~1200 günde kaba kuvvet: en genç = TEEN, bir gün sonrası UNDER_13 ve SEÇİLEMEZ;
##              yıl / ay / gün aralıkları; uyarlama (takvim kırpılır: 31 → 30, 29 Şubat → 28;
##              aralıkla çelişen alan SIFIRLANIR — en genç izinli güne kaydırılmaz); seçim
##              sınıflandırıcısı ASLA UNDER_13 vermez
##   KAYIT      doğrulama + geçişler (TEEN -> ADULT), eski UNDER_13 -> UNKNOWN (TEEN / ADULT'a
##              ÇEVRİLMEZ), bozuk / imkânsız / saçma ileri / modelden eski / tutarsız değer ->
##              UNKNOWN (ASLA ADULT), saat geri alma
##   SAVE       yeni kayıt · eski kayıt · TEEN / ADULT · eski UNDER_13 (açılışta UNKNOWN + tarih
##              boş, `.bak` atılır, çevrilmez) ·
##              geçiş kalıcılığı · bozuk (yazma yok) · yeniden giriş; ham doğum tarihi kayıtta YOK
##   ROTA       owner tablosu birebir (UNKNOWN / UNDER_13 reklamsız, TEEN TEEN+T, ADULT
##              UNSPECIFIED+MA)
##   GİZLİLİK   yaş dosyalarında log / analitik / ağ çağrısı YOK; panel yalnız türetilmiş
##              sonucu yayar ve seçimi siler
##   UI         (TASK/046.1) boş seçiciler, yıl / ay / gün ızgaraları 13 altını HİÇ göstermez,
##              en genç izinli tarih seçilebilir, uyarlama + artık yıl, onay (DÜZELT seçimi korur,
##              ONAYLA tek sefer), bozuk saat / aralık dışı -> TEK nötr hata, kipler (zorunlu: X
##              yok, karartma / geri kapatmaz; yeniden giriş: X / Vazgeç / karartma / geri),
##              yatışma sinyalleri, nötr metin, 320×568 / 360×640 / 390×844 / 360×800 /
##              1080×2340 + A36 üst payı
##   EMEKLİ     13 altı kısıt / çıkış ekranı: dosyası yok, üretim kodunda metni / rotası yok
##
## Kayda yazar (SaveManager senaryoları) — başta yedekler, sonda byte-identical geri koyar.
##
##   godot --headless --audio-driver Dummy --path . res://tools/age_gate_test.tscn

const PANEL_SCENE: PackedScene = preload("res://scenes/ui/age_gate_panel.tscn")
const TODAY: String = "2026-09-27"
## 320×568 / 360×640 / 390×844 / 360×800 / 1080×2340 (A36) — TASK/046.1 istenen boyutlar.
const VIEWS: Array[Vector2i] = [Vector2i(320, 568), Vector2i(360, 640), Vector2i(390, 844), Vector2i(360, 800),
	Vector2i(1080, 2340)]
const A36_SAFE_TOP: float = 61.0
## Nötr ekranda GÖRÜNMEMESİ gereken ifadeler (eşik, reklam, ödül / oyun parası, kilit açma).
const FORBIDDEN_WORDS: Array[String] = ["13", "18", "yetişkin", "reklam", "ödül", "kilit", "altın",
	"sandık", "yıldız", "hediye", "hamur", "unlock", "bonus", "+", "yaş sınırı", "reşit", "çocuk", "genç", "teen",
	"adult", "üzgünüz", "oynanam", "uygun değil", "küçük", "yaş grubu", "tasarlanmadı", "çıkış"]

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
	_test_selectable_range()
	_test_resolve_stored()
	_test_routing_table()
	_test_save_format()
	_test_privacy_static()
	await _test_panel_entry()
	await _test_panel_adjust()
	await _test_panel_modes()
	await _test_panel_neutral_texts()
	await _test_panel_layout()
	_test_retired_flow()

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


# --- 13+ seçilebilir aralık (TASK/046.1) -----------------------------------------------------

func _sel_is(year: int, month: int, day: int, on_day: Dictionary, band: int, transition: String) -> bool:
	return _band_is(AgeGate.classify_selected_birth_date(year, month, day, on_day), band, transition)


func _sel_error(year: int, month: int, day: int, on_day: Dictionary) -> int:
	var out: Dictionary = AgeGate.classify_selected_birth_date(year, month, day, on_day)
	if bool(out["ok"]) or int(out["band"]) != AgeGate.Band.UNKNOWN or String(out["transition"]) != "":
		return -1
	return int(out["error"])


func _test_selectable_range() -> void:
	print("-- 13+ seçilebilir aralık: en genç / en eski doğum günü, aralıklar, kırpma, seçim sınıflandırıcısı")
	var t: Dictionary = _d("2026-09-30")
	_c("bugün 2026-09-30: en genç izinli doğum günü 2013-09-30 (tam 13), en eski 1906-09-30 (120 yıl)",
		AgeGate.format_day(AgeGate.youngest_allowed_birth_date(t)) == "2013-09-30"
		and AgeGate.format_day(AgeGate.oldest_allowed_birth_date(t)) == "1906-09-30")
	_c("en genç izinli tarih TEEN (13. yaş günü bugün); bir gün sonrası ham sınıflandırıcıda UNDER_13 ve SEÇİLEMEZ",
		_band_is(_classify("2013-09-30", "2026-09-30"), AgeGate.Band.TEEN, "2031-09-30")
		and _band_is(_classify("2013-10-01", "2026-09-30"), AgeGate.Band.UNDER_13, "2026-10-01")
		and AgeGate.is_selectable_birth_date(2013, 9, 30, t) and not AgeGate.is_selectable_birth_date(2013, 10, 1, t))
	_c("seçim: tam 13 / 13. yaş günü bugün -> TEEN (geçiş 18. yaş günü); 17 -> TEEN",
		_sel_is(2013, 9, 30, t, AgeGate.Band.TEEN, "2031-09-30") and _sel_is(2009, 3, 15, t, AgeGate.Band.TEEN, "2027-03-15"))
	_c("seçim: 18. yaş günü bugün (30 Eylül 2008) -> ADULT; 18. yaş gününden bir gün önce -> TEEN (geçiş yarın); 30 -> ADULT",
		_sel_is(2008, 9, 30, t, AgeGate.Band.ADULT, "") and _sel_is(2008, 10, 1, t, AgeGate.Band.TEEN, "2026-10-01")
		and _sel_is(1996, 1, 1, t, AgeGate.Band.ADULT, ""))
	_c("seçim: 13'ten BİR gün genç -> TOO_YOUNG, bant UNKNOWN, geçiş boş (UNDER_13 ÜRETMEZ)",
		_sel_error(2013, 10, 1, t) == AgeGate.EntryError.TOO_YOUNG and _sel_error(2020, 1, 1, t) == AgeGate.EntryError.TOO_YOUNG)
	_c("seçim: en eski (1906-09-30) -> ADULT; bir gün eski -> TOO_OLD; gelecek -> FUTURE; imkânsız / boş -> INVALID",
		_sel_is(1906, 9, 30, t, AgeGate.Band.ADULT, "") and _sel_error(1906, 9, 29, t) == AgeGate.EntryError.TOO_OLD
		and _sel_error(2026, 10, 1, t) == AgeGate.EntryError.FUTURE and _sel_error(2010, 2, 30, t) == AgeGate.EntryError.INVALID
		and _sel_error(0, 0, 0, t) == AgeGate.EntryError.INVALID and _sel_error(2010, 13, 1, t) == AgeGate.EntryError.INVALID)
	_c("seçim sonucu doğum tarihini TAŞIMAZ (ok / error / band / transition)",
		AgeGate.classify_selected_birth_date(2009, 3, 15, t).keys() == ["ok", "error", "band", "transition"]
		and AgeGate.classify_selected_birth_date(2020, 3, 15, t).keys() == ["ok", "error", "band", "transition"])
	# 29 Şubat: "bugün" 29 Şubat (13 yıl önce artık yıl DEĞİL) ve 29 Şubat doğumlular.
	_c("bugün 29.02.2028: en genç 28.02.2015 (01.03.2015 doğumlu yarın 13); 29.02.2024: en genç 28.02.2011",
		AgeGate.format_day(AgeGate.youngest_allowed_birth_date(_d("2028-02-29"))) == "2015-02-28"
		and AgeGate.format_day(AgeGate.youngest_allowed_birth_date(_d("2024-02-29"))) == "2011-02-28"
		and not AgeGate.is_selectable_birth_date(2015, 3, 1, _d("2028-02-29")))
	_c("bugün 28.02.2025: 29.02.2012 SEÇİLEMEZ (13'ü 01.03.2025'te doldurur), en genç 28.02.2012; 01.03.2025'te seçilir -> TEEN",
		AgeGate.format_day(AgeGate.youngest_allowed_birth_date(_d("2025-02-28"))) == "2012-02-28"
		and not AgeGate.is_selectable_birth_date(2012, 2, 29, _d("2025-02-28"))
		and _sel_error(2012, 2, 29, _d("2025-02-28")) == AgeGate.EntryError.TOO_YOUNG
		and AgeGate.format_day(AgeGate.youngest_allowed_birth_date(_d("2025-03-01"))) == "2012-03-01"
		and _sel_is(2012, 2, 29, _d("2025-03-01"), AgeGate.Band.TEEN, "2030-03-01"))
	# Kaba kuvvet: 2024-01-01'den 1600 gün (2024 ve 2028 artık günleri dahil).
	var brute_ok: bool = true
	var bad_days: PackedStringArray = PackedStringArray()
	var day: Dictionary = _d("2024-01-01")
	for i in 1600:
		var young: Dictionary = AgeGate.youngest_allowed_birth_date(day)
		var younger: Dictionary = AgeGate.next_day(young)
		var old: Dictionary = AgeGate.oldest_allowed_birth_date(day)
		var older: Dictionary = AgeGate.previous_day(old)
		var years: Vector2i = AgeGate.selectable_year_range(day)
		var months: Vector2i = AgeGate.selectable_month_range(int(young["year"]), day)
		var days: Vector2i = AgeGate.selectable_day_range(int(young["year"]), int(young["month"]), day)
		var old_days: Vector2i = AgeGate.selectable_day_range(int(old["year"]), int(old["month"]), day)
		var ok: bool = _band_is(AgeGate.classify_birth_date(young["year"], young["month"], young["day"], day), AgeGate.Band.TEEN,
				AgeGate.format_day(AgeGate.anniversary(young, AgeGate.ADULT_AGE))) \
			and int(AgeGate.classify_birth_date(younger["year"], younger["month"], younger["day"], day)["band"]) == AgeGate.Band.UNDER_13 \
			and AgeGate.is_selectable_birth_date(young["year"], young["month"], young["day"], day) \
			and not AgeGate.is_selectable_birth_date(younger["year"], younger["month"], younger["day"], day) \
			and _sel_error(younger["year"], younger["month"], younger["day"], day) == AgeGate.EntryError.TOO_YOUNG \
			and _band_is(AgeGate.classify_birth_date(old["year"], old["month"], old["day"], day), AgeGate.Band.ADULT, "") \
			and AgeGate.classify_birth_date(older["year"], older["month"], older["day"], day)["error"] == AgeGate.EntryError.TOO_OLD \
			and not AgeGate.is_selectable_birth_date(older["year"], older["month"], older["day"], day) \
			and years == Vector2i(int(old["year"]), int(young["year"])) \
			and months.y == int(young["month"]) and days.y == int(young["day"]) and old_days.x == int(old["day"]) \
			and AgeGate.selectable_month_range(int(young["year"]) + 1, day).x > AgeGate.selectable_month_range(int(young["year"]) + 1, day).y
		if not ok:
			brute_ok = false
			if bad_days.size() < 5:
				bad_days.append(AgeGate.format_day(day))
		day = AgeGate.next_day(day)
	_c("1600 gün (2024-01-01 → 2028-05, iki artık gün): en genç = TEEN, +1 gün UNDER_13 + seçilemez + TOO_YOUNG; en eski ADULT, -1 gün TOO_OLD; aralık uçları tam %s"
		% str(bad_days), brute_ok)
	_c("aralıklar (2026-09-30): yıl 1906..2013; 2013 ayları 1..9; 1906 ayları 9..12; 2014 / 1905 boş",
		AgeGate.selectable_year_range(t) == Vector2i(1906, 2013) and AgeGate.selectable_month_range(2013, t) == Vector2i(1, 9)
		and AgeGate.selectable_month_range(1906, t) == Vector2i(9, 12) and AgeGate.selectable_month_range(2000, t) == Vector2i(1, 12)
		and AgeGate.selectable_month_range(2014, t).x > AgeGate.selectable_month_range(2014, t).y
		and AgeGate.selectable_month_range(1905, t).x > AgeGate.selectable_month_range(1905, t).y)
	_c("gün aralıkları: 2013-09 1..30, 2013-10 boş, 1906-09 30..30, Şubat 2012 1..29 / 2011 1..28, yıl yok Şubat 1..29, ay yok 1..31",
		AgeGate.selectable_day_range(2013, 9, t) == Vector2i(1, 30)
		and AgeGate.selectable_day_range(2013, 10, t).x > AgeGate.selectable_day_range(2013, 10, t).y
		and AgeGate.selectable_day_range(1906, 9, t) == Vector2i(30, 30) and AgeGate.selectable_day_range(2012, 2, t) == Vector2i(1, 29)
		and AgeGate.selectable_day_range(2011, 2, t) == Vector2i(1, 28) and AgeGate.selectable_day_range(0, 2, t) == Vector2i(1, 29)
		and AgeGate.selectable_day_range(0, 4, t) == Vector2i(1, 30) and AgeGate.selectable_day_range(2013, 0, t) == Vector2i(1, 31))
	_c("takvim kırpılır: 29 Şubat -> 2011'de 28; 2012'de 29 kalır; 31 -> Nisan'da 30; en genç tarih aynen",
		AgeGate.clamp_selection(29, 2, 2011, t) == {"day": 28, "month": 2, "year": 2011}
		and AgeGate.clamp_selection(29, 2, 2012, t) == {"day": 29, "month": 2, "year": 2012}
		and AgeGate.clamp_selection(31, 4, 2000, t) == {"day": 30, "month": 4, "year": 2000}
		and AgeGate.clamp_selection(30, 9, 2013, t) == {"day": 30, "month": 9, "year": 2013})
	_c("aralık çelişkisi SIFIRLAR (kaydırmaz): 31 / 15 Aralık -> yıl 2013: ay silinir, gün korunur (30 Eylül 2013'e DÖNÜŞMEZ); 1 Ekim 2013: ay silinir",
		AgeGate.clamp_selection(31, 12, 2013, t) == {"day": 31, "month": 0, "year": 2013}
		and AgeGate.clamp_selection(15, 12, 2013, t) == {"day": 15, "month": 0, "year": 2013}
		and AgeGate.clamp_selection(1, 10, 2013, t) == {"day": 1, "month": 0, "year": 2013})
	_c("aralık çelişkisi (en eski uç): 15 Eylül 1906 -> gün silinir (1906 Eylül'de yalnız 30); Ocak 1906 -> ay silinir",
		AgeGate.clamp_selection(15, 9, 1906, t) == {"day": 0, "month": 9, "year": 1906}
		and AgeGate.clamp_selection(1, 1, 1906, t) == {"day": 1, "month": 0, "year": 1906})
	_c("kısmi seçim: 31 Nisan (yıl yok) -> 30; 30 Şubat (yıl yok) -> 29; yalnız gün aynen; aralık dışı yıl (2020 / 1800) SİLİNİR",
		AgeGate.clamp_selection(31, 4, 0, t) == {"day": 30, "month": 4, "year": 0}
		and AgeGate.clamp_selection(30, 2, 0, t) == {"day": 29, "month": 2, "year": 0}
		and AgeGate.clamp_selection(15, 0, 0, t) == {"day": 15, "month": 0, "year": 0}
		and AgeGate.clamp_selection(0, 0, 2020, t) == {"day": 0, "month": 0, "year": 0}
		and AgeGate.clamp_selection(0, 0, 1800, t) == {"day": 0, "month": 0, "year": 0})
	# Uyarlanmış her seçim: alanlar ya aynen, ya silinmiş (0), ya da gün takvimce ayın son gününe
	# kırpılmış; üç alan doluysa tarih seçilebilir — oyuncunun seçmediği bir değer HİÇ oluşmaz.
	var clamp_ok: bool = true
	var bad_clamps: PackedStringArray = PackedStringArray()
	for year in [1800, 1906, 1907, 1960, 2000, 2011, 2012, 2013, 2014, 2026, 0]:
		for month in range(0, 13):
			for d in range(0, 32):
				var c: Dictionary = AgeGate.clamp_selection(d, month, year, t)
				var cy: int = int(c["year"])
				var cm: int = int(c["month"])
				var cd: int = int(c["day"])
				var longest: int = 0
				if cm != 0:
					longest = AgeGate.days_in_month(cy, cm) if cy != 0 else (29 if cm == 2 else AgeGate.days_in_month(2001, cm))
				var ok: bool = (cy == 0 or cy == year) and (cm == 0 or cm == month) \
					and (cd == 0 or cd == d or (cd < d and cd == longest))
				if cy != 0 and cm != 0 and cd != 0:
					ok = ok and AgeGate.is_selectable_birth_date(cy, cm, cd, t)
				if not ok:
					clamp_ok = false
					if bad_clamps.size() < 5:
						bad_clamps.append("%d.%d.%d -> %s" % [d, month, year, str(c)])
	_c("uyarlanmış her seçim (11 yıl × 13 ay × 32 gün, kısmi dahil): alan aynen / silinmiş / takvimce kırpılmış; tam seçim seçilebilir %s"
		% str(bad_clamps), clamp_ok)
	var never_under: bool = true
	var agrees: bool = true
	var probe: Dictionary = _d("2010-01-01")
	while AgeGate.compare(probe, _d("2027-01-01")) < 0:
		var out: Dictionary = AgeGate.classify_selected_birth_date(probe["year"], probe["month"], probe["day"], t)
		never_under = never_under and int(out["band"]) != AgeGate.Band.UNDER_13
		agrees = agrees and bool(out["ok"]) == AgeGate.is_selectable_birth_date(probe["year"], probe["month"], probe["day"], t)
		probe = AgeGate.next_day(probe)
	_c("2010–2026 her doğum günü: seçim sınıflandırıcısı ASLA UNDER_13 vermez; kabul <=> seçilebilir", never_under and agrees)


# --- Kayıttaki durum ---------------------------------------------------------------------

func _resolve(band: Variant, transition: Variant, today: String) -> Dictionary:
	return AgeGate.resolve_stored(band, transition, _d(today))


func _is(result: Dictionary, band: int, transition: String, changed: bool, corrupt: bool) -> bool:
	return int(result["band"]) == band and String(result["transition"]) == transition \
		and bool(result["changed"]) == changed and bool(result["corrupt"]) == corrupt


## TASK/046.1: eski UNDER_13 -> UNKNOWN, değişiklik yok, bozuk değil, `legacy_under_13` işaretli.
func _is_legacy(result: Dictionary) -> bool:
	return _is(result, AgeGate.Band.UNKNOWN, "", false, false) and bool(result.get("legacy_under_13", false))


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
		_is(_resolve("TEEN", "2026-09-27", t), AgeGate.Band.UNKNOWN, "", false, true))
	_c("ESKİ UNDER_13 (geçiş ileride) -> UNKNOWN (yaş yeniden sorulur), legacy işaretli, UNDER_13 dönmez",
		_is_legacy(_resolve("UNDER_13", "2030-01-01", t)))
	_c("ESKİ UNDER_13, bugün 13. yaş günü -> yine UNKNOWN: TEEN'e ÇEVRİLMEZ (yaş tahmin edilmez)",
		_is_legacy(_resolve("UNDER_13", t, t)))
	_c("ESKİ UNDER_13 çok önce (13. ve 18. yaş günü geçti) -> UNKNOWN: ADULT'a ÇEVRİLMEZ",
		_is_legacy(_resolve("UNDER_13", "2026-09-29", "2031-09-29")))
	_c("ESKİ UNDER_13 + boş / biçimsiz / imkânsız / sayı geçiş -> yine UNKNOWN (tek yol: yeniden sor)",
		_is_legacy(_resolve("UNDER_13", "", t)) and _is_legacy(_resolve("UNDER_13", "1990-01-01", t))
		and _is_legacy(_resolve("UNDER_13", "2030-02-30", t)) and _is_legacy(_resolve("UNDER_13", 5, t)))
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
	_c("resolve_stored hiçbir girdide UNDER_13 DÖNMEZ (eski kayıt her zaman yeniden sorulur)",
		int(_resolve("UNDER_13", "2030-05-10", "2030-05-09")["band"]) != AgeGate.Band.UNDER_13
		and int(_resolve("UNDER_13", "2030-05-10", "2035-05-10")["band"]) == AgeGate.Band.UNKNOWN)
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
	_c("kayıt çifti: yalnız TEEN geçişi tutar; UNDER_13 (artık yazılmaz) / ADULT / UNKNOWN tarih TUTMAZ",
		AgeGate.stored_pair(AgeGate.Band.TEEN, "2027-01-01") == ["TEEN", "2027-01-01"]
		and AgeGate.stored_pair(AgeGate.Band.UNDER_13, "2030-01-01") == ["UNDER_13", ""]
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
	# UNDER_13 (TASK/046.1: normal giriş üretmez; gelirse tarih SAKLANMAZ, açılışta UNKNOWN).
	var child: Dictionary = AgeGate.classify_birth_date(2016, 4, 2, today)
	SaveManager.store_age_band(child["band"], child["transition"])
	SaveManager.load_game()
	_c("UNDER_13 yazılırsa 13. yaş günü SAKLANMAZ; okunurken UNKNOWN (yeniden sorulur)",
		SaveManager.stored_age_band(today) == AgeGate.Band.UNKNOWN and SaveManager.next_age_transition_raw() == ""
		and not _disk_text().contains("2029-04-02") and not _disk_text().contains("2016"))
	# Geçiş kalıcılığı (soğuk açılış).
	SaveManager.store_age_band(AgeGate.Band.TEEN, "2026-10-05")
	var before_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_c("18. yaş gününden önce açılış: TEEN, yazma YOK", SaveManager.resolve_age_band_at_launch(_d("2026-10-04")) == AgeGate.Band.TEEN
		and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == before_bytes)
	_c("tam 18. yaş günü açılış: ADULT kalıcılaştı (tek yazma), geçiş temizlendi",
		SaveManager.resolve_age_band_at_launch(_d("2026-10-05")) == AgeGate.Band.ADULT
		and _disk_text().contains("\"age_ad_band\": \"ADULT\"") and SaveManager.next_age_transition_raw() == "")
	# ESKİ UNDER_13 kaydı (TASK/043 biçimi: 13. yaş günüyle) — açılış.
	SaveManager.data["age_ad_band"] = "UNDER_13"
	SaveManager.data["next_age_transition_date"] = "2026-10-05"
	SaveManager.save_game()
	SaveManager.save_game()
	var legacy_bak: String = SaveManager.save_path + SaveFile.BACKUP_SUFFIX
	_c("(ön koşul) eski UNDER_13 kaydının bir önceki kuşak kopyası (.bak) da 13. yaş gününü taşıyor",
		FileAccess.file_exists(legacy_bak) and FileAccess.get_file_as_string(legacy_bak).contains("2026-10-05"))
	_c("ESKİ UNDER_13 (13. yaş günü bugün): açılış UNKNOWN, TEEN'e ÇEVRİLMEDİ; TEK yazmayla kayıt UNKNOWN + tarih boş, .bak atıldı, ilerleme duruyor",
		SaveManager.resolve_age_band_at_launch(_d("2026-10-05")) == AgeGate.Band.UNKNOWN
		and SaveManager.age_ad_band_raw() == "UNKNOWN" and SaveManager.next_age_transition_raw() == ""
		and _disk_text().contains("\"age_ad_band\": \"UNKNOWN\"") and not _disk_text().contains("2026-10-05")
		and not FileAccess.file_exists(legacy_bak) and SaveManager.highest_level_unlocked() == 6)
	var unknown_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_c("sonraki açılış: UNKNOWN, YAZMA yok (tek seferlik temizlik)", SaveManager.resolve_age_band_at_launch(_d("2026-10-06"))
		== AgeGate.Band.UNKNOWN and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == unknown_bytes)
	SaveManager.store_age_band(AgeGate.Band.TEEN, "2031-10-05")
	var bak_path: String = SaveManager.save_path + SaveFile.BACKUP_SUFFIX
	_c("temizlenmiş eski kaydın üzerine yeni 13+ giriş (TEEN) yazılır; eski 13. yaş günü hiçbir kopyada KALMAZ",
		SaveManager.age_ad_band_raw() == "TEEN" and SaveManager.next_age_transition_raw() == "2031-10-05"
		and not _disk_text().contains("2026-10-05")
		and (not FileAccess.file_exists(bak_path) or not FileAccess.get_file_as_string(bak_path).contains("2026-10-05")))
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
	for path in ["res://scripts/game/age_gate.gd", "res://scripts/ui/age_gate_panel.gd"]:
		for line in _code_lines(path):
			for sink in sinks:
				if line.contains(sink):
					hits.append("%s: %s" % [path.get_file(), line])
	_c("age_gate.gd / age_gate_panel.gd: log, analitik olayı, ağ, dosya yazımı YOK %s" % str(hits),
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


# --- Panel (TASK/046.1: GÜN / AY / YIL seçicileri) ---------------------------------------------

## Panel testlerinin "bugün"ü (TASK/046.1 örneği: 30 Eylül 2008 = 18. yaş günü bugün).
const UI_TODAY: String = "2026-09-30"


func _make_panel() -> CanvasLayer:
	var panel: CanvasLayer = PANEL_SCENE.instantiate()
	add_child(panel)
	await get_tree().process_frame
	return panel


## Seçiciye dokun -> ızgarada değeri seç. Değer ızgarada yoksa false (ızgara kapatılır).
func _pick(panel: CanvasLayer, field: int, value: int) -> bool:
	panel.selector_button(field).pressed.emit()
	if panel.picker_field() != field:
		return false
	var option: Button = panel.option_button(value)
	if option == null:
		panel.close_picker()
		return false
	option.pressed.emit()
	return panel.picker_field() == -1


## Yıl -> ay -> gün sırasıyla seçer (oyuncunun en doğal sırası).
func _select(panel: CanvasLayer, day: int, month: int, year: int) -> bool:
	return _pick(panel, 2, year) and _pick(panel, 1, month) and _pick(panel, 0, day)


## Açık ızgaranın değerleri (ızgarayı açar, okur, kapatır).
func _options_of(panel: CanvasLayer, field: int) -> Array[int]:
	panel.selector_button(field).pressed.emit()
	var values: Array[int] = panel.option_values()
	panel.close_picker()
	return values


## Dizi içeriği aynı mı (tipli / tipsiz dizi farkı gözetmeden).
static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


func _release_event() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	return ev


func _test_panel_entry() -> void:
	print("-- panel: boş seçiciler, 13+ ızgaralar, en genç izinli tarih, onay, DÜZELT, tek ONAYLA")
	AgeGate.clock_override = UI_TODAY
	var panel: CanvasLayer = await _make_panel()
	var got: Array = []
	var settles: Array = []
	panel.resolved.connect(func(band: int, transition: String) -> void: got.append([band, transition]))
	panel.settle_requested.connect(func() -> void: settles.append(true))
	panel.open_required()
	await get_tree().process_frame
	_c("açıldı: ZORUNLU kip, GİRİŞ adımı, üç seçici BOŞ ('Seç' — hazır tarih YOK), ızgara kapalı",
		panel.visible and not panel.is_reentry() and panel.stage() == panel.Stage.ENTRY and panel.selector_text(0) == "Seç"
		and panel.selector_text(1) == "Seç" and panel.selector_text(2) == "Seç" and _same(panel.selected_fields(), [false, false, false])
		and panel.picker_field() == -1 and panel.selection() == {"day": 0, "month": 0, "year": 0})
	_c("DEVAM ET pasif (eksik tarih); X ve Vazgeç YOK (zorunlu)", panel.continue_button().disabled
		and not panel.close_x().visible and not panel.cancel_button().visible)
	panel.continue_button().pressed.emit()
	_c("eksik tarihte DEVAM ET hiçbir şey yapmaz (hata / onay yok)", panel.stage() == panel.Stage.ENTRY
		and not panel.error_visible() and got.is_empty())
	# Yıl ızgarası.
	settles.clear()
	panel.selector_button(2).pressed.emit()
	var years: Array[int] = panel.option_values()
	var no_young_year: bool = true
	for y in years:
		no_young_year = no_young_year and y <= 2013 and y >= 1906
	_c("YIL ızgarası: en genç yıl İLK (2013), en eski son (1906), 108 yıl, 2014+ YOK; adım yatışması istendi",
		panel.stage() == panel.Stage.PICK and panel.picker_field() == 2 and years.size() == 108 and years[0] == 2013
		and years[-1] == 1906 and no_young_year and panel.option_button(2014) == null and settles.size() == 1)
	panel.selector_button(0).pressed.emit()
	_c("ızgara açıkken DEVAM ET görünmez, seçicilere ikinci dokunuş ızgarayı DEĞİŞTİRMEZ",
		not panel.continue_button().visible and panel.picker_field() == 2)
	panel.option_button(2013).pressed.emit()
	_c("2013 seçildi: ızgara kapandı, YIL seçicisi '2013', diğerleri boş", panel.picker_field() == -1
		and panel.selector_text(2) == "2013" and _same(panel.selected_fields(), [false, false, true]))
	panel.choose(2012)
	_c("ızgara kapalıyken choose() yok sayılır (çift dokunuşun ikincisi değer seçemez)", panel.selection()["year"] == 2013)
	var months: Array[int] = _options_of(panel, 1)
	_c("AY ızgarası (2013): yalnız Ocak..Eylül (Ekim / Kasım / Aralık 13 altı — GÖSTERİLMEZ)",
		_same(months, [1, 2, 3, 4, 5, 6, 7, 8, 9]))
	panel.selector_button(1).pressed.emit()
	_c("ay seçenekleri Türkçe ad taşır (Eylül)", (panel.option_button(9) as Button).text == "Eylül")
	panel.option_button(9).pressed.emit()
	var days: Array[int] = _options_of(panel, 0)
	_c("GÜN ızgarası (Eylül 2013): 1..30 — en genç izinli gün 30 (bugün tam 13)", days.size() == 30 and days[0] == 1
		and days[-1] == 30)
	_c("en genç izinli tarih seçilebilir: 30 Eylül 2013", _pick(panel, 0, 30) and panel.selector_text(0) == "30"
		and panel.selector_text(1) == "Eylül" and panel.selection() == {"day": 30, "month": 9, "year": 2013})
	_c("tam tarih: DEVAM ET etkin", not panel.continue_button().disabled)
	settles.clear()
	panel.continue_button().pressed.emit()
	_c("DEVAM ET -> onay adımı '30 Eylül 2013', DÜZELT + ONAYLA görünür, sonuç HENÜZ yok",
		panel.stage() == panel.Stage.CONFIRM and panel.confirm_text() == "30 Eylül 2013" and panel.fix_button().visible
		and panel.confirm_button().visible and not panel.continue_button().visible and got.is_empty() and settles.size() == 1)
	_c("onay metni 'Doğru mu?' sorusu ile", panel.visible_texts().has(panel.CONFIRM_QUESTION))
	panel.fix_button().pressed.emit()
	_c("DÜZELT: seçime döndü, seçim KORUNDU", panel.stage() == panel.Stage.ENTRY
		and panel.selection() == {"day": 30, "month": 9, "year": 2013} and panel.confirm_text() == "30 Eylül 2013")
	_c("DÜZELT sonrası bir alan değiştirilir: 2009 -> 30 Eylül 2009", _pick(panel, 2, 2009)
		and panel.selection() == {"day": 30, "month": 9, "year": 2009})
	panel.continue_button().pressed.emit()
	var consumed: bool = panel.handle_back()
	_c("geri tuşu onay adımında seçime döner (ÇIKMAZ), seçim korunur", consumed and panel.visible
		and panel.stage() == panel.Stage.ENTRY and panel.selection() == {"day": 30, "month": 9, "year": 2009})
	panel.continue_button().pressed.emit()
	panel.confirm_button().pressed.emit()
	panel.confirm_button().pressed.emit()
	_c("ONAYLA -> TEK sonuç TEEN (17 yaş, geçiş 30.09.2027); hızlı ikinci ONAYLA yok sayıldı (adım / hata değişmedi)",
		got.size() == 1 and got[0][0] == AgeGate.Band.TEEN and got[0][1] == "2027-09-30"
		and panel.stage() == panel.Stage.CONFIRM and not panel.error_visible())
	_c("onaydan sonra seçim bellekten SİLİNDİ (onay metni boş)", panel.selection() == {"day": 0, "month": 0, "year": 0}
		and panel.confirm_text() == "")
	panel.close_panel()
	# 18. yaş günü bugün / 13. yaş günü bugün / 18+ / en eski.
	var cases: Array = [[30, 9, 2008, AgeGate.Band.ADULT, ""], [30, 9, 2013, AgeGate.Band.TEEN, "2031-09-30"],
		[1, 10, 2008, AgeGate.Band.TEEN, "2026-10-01"], [15, 6, 1990, AgeGate.Band.ADULT, ""], [30, 9, 1906, AgeGate.Band.ADULT, ""]]
	var case_ok: bool = true
	for case: Array in cases:
		got.clear()
		panel.open_required()
		var picked: bool = _select(panel, case[0], case[1], case[2])
		panel.continue_button().pressed.emit()
		panel.confirm_button().pressed.emit()
		if not picked or got.size() != 1 or got[0][0] != case[3] or got[0][1] != case[4]:
			case_ok = false
			print("    beklenmeyen: ", case, " -> ", got)
		panel.close_panel()
	_c("ızgaradan: 30 Eylül 2008 (18. yaş günü bugün) ADULT · 30 Eylül 2013 TEEN · 1 Ekim 2008 TEEN · 1990 ADULT · en eski 30 Eylül 1906 ADULT",
		case_ok)
	panel.open_required()
	_c("en eski yıl 1906: ay ızgarası Eylül..Aralık, Eylül'de gün yalnız 30", _pick(panel, 2, 1906)
		and _same(_options_of(panel, 1), [9, 10, 11, 12]) and _pick(panel, 1, 9) and _same(_options_of(panel, 0), [30]))
	panel.close_panel()
	# Her ay × her gün (en genç yıl): ızgaradaki HİÇBİR tarih 13 altı değil.
	panel.open_required()
	var exposed: PackedStringArray = PackedStringArray()
	var today: Dictionary = AgeGate.today()
	_pick(panel, 2, 2013)
	for month in _options_of(panel, 1):
		_pick(panel, 1, month)
		for day in _options_of(panel, 0):
			var out: Dictionary = AgeGate.classify_birth_date(2013, month, day, today)
			if int(out["band"]) != AgeGate.Band.TEEN:
				exposed.append("%d.%d.2013" % [day, month])
	_c("en genç yılın bütün ay × gün seçenekleri TEEN (13 altı tarih ızgarada YOK) %s" % str(exposed), exposed.is_empty())
	panel.close_panel()
	panel.queue_free()
	await get_tree().process_frame


func _test_panel_adjust() -> void:
	print("-- panel: kırpma (yıl / ay değişince gün, artık yıl), bozuk saat ve aralık dışı -> TEK nötr hata")
	AgeGate.clock_override = TODAY
	var panel: CanvasLayer = await _make_panel()
	var got: Array = []
	panel.resolved.connect(func(band: int, transition: String) -> void: got.append([band, transition]))
	panel.open_required()
	_c("önce gün: yıl / ay yokken ızgara 1..31", _options_of(panel, 0).size() == 31)
	_pick(panel, 0, 31)
	_c("ay yokken ay ızgarası 12 ay (yıl bilinmiyor)", _options_of(panel, 1).size() == 12)
	_pick(panel, 1, 2)
	_c("31 + Şubat (yıl yok) -> gün 29'a kırpıldı", panel.selection() == {"day": 29, "month": 2, "year": 0}
		and panel.selector_text(0) == "29")
	_pick(panel, 2, 2011)
	_c("artık olmayan yıl (2011) -> 28 Şubat", panel.selection() == {"day": 28, "month": 2, "year": 2011})
	_pick(panel, 2, 2012)
	_c("artık yıla (2012) dönünce gün kendiliğinden BÜYÜMEZ (28), ızgarada 29 var", panel.selection()["day"] == 28
		and _options_of(panel, 0).size() == 29)
	_pick(panel, 0, 29)
	_pick(panel, 2, 2010)
	_c("29 Şubat 2012 -> yıl 2010: 28 Şubat 2010", panel.selection() == {"day": 28, "month": 2, "year": 2010})
	_pick(panel, 1, 12)
	_pick(panel, 0, 31)
	_pick(panel, 2, 2013)
	_c("31 Aralık 2010 -> yıl 2013 (bugün 27.09.2026): çelişen AY 'Seç'e döndü, gün 31 korundu — en genç izinli tarihe KAYDIRILMADI",
		panel.selection() == {"day": 31, "month": 0, "year": 2013} and panel.selector_text(1) == "Seç"
		and panel.continue_button().disabled)
	_c("2013 ay ızgarası yalnız Ocak..Eylül", _same(_options_of(panel, 1), range(1, 10)))
	_pick(panel, 1, 9)
	_c("Eylül seçilince gün 31 (takvimce 30, ama 28–30 Eylül 2013 = 13 altı) 'Seç'e döndü", panel.selection() == {"day": 0, "month": 9, "year": 2013}
		and panel.selector_text(0) == "Seç")
	_c("Eylül 2013 gün ızgarası 1..27 (28 Eylül 2013 = yarın 13 — YOK)", _same(_options_of(panel, 0), range(1, 28)))
	_pick(panel, 0, 27)
	panel.continue_button().pressed.emit()
	panel.confirm_button().pressed.emit()
	_c("27 Eylül 2013 (13. yaş günü bugün) -> TEEN, geçiş 27.09.2031", got.size() == 1 and got[0][0] == AgeGate.Band.TEEN
		and got[0][1] == "2031-09-27")
	panel.close_panel()
	# Aralık dışı (saat seçimden sonra bir gün geri): AYNI nötr hata, sonuç yok, eşik söylenmez.
	got.clear()
	AgeGate.clock_override = UI_TODAY
	panel.open_required()
	_select(panel, 30, 9, 2013)
	AgeGate.clock_override = "2026-09-29"
	panel.continue_button().pressed.emit()
	_c("seçimden sonra saat bir gün geri (tarih artık 13'ten genç) -> TEK nötr hata, onay YOK, sonuç YOK",
		panel.error_visible() and panel.error_text() == panel.ERROR_TEXT and panel.stage() == panel.Stage.ENTRY and got.is_empty())
	_c("nötr hata metni eşik / yaş söylemez", panel.ERROR_TEXT == "Tarihi kontrol edip tekrar dene.")
	_pick(panel, 2, 2012)
	_c("bir alan değişince hata kalkar", not panel.error_visible())
	panel.close_panel()
	# Bozuk saat (modelden önce): geçerli tarih de sınıflandırılmaz.
	AgeGate.clock_override = UI_TODAY
	panel.open_required()
	_select(panel, 15, 6, 1990)
	AgeGate.clock_override = "2026-09-26"
	panel.continue_button().pressed.emit()
	_c("saat modelden önce -> geçerli tarih de AYNI nötr hata, sonuç yok (ASLA ADULT çıkarımı)", panel.error_visible()
		and panel.stage() == panel.Stage.ENTRY and got.is_empty())
	AgeGate.clock_override = UI_TODAY
	panel.continue_button().pressed.emit()
	AgeGate.clock_override = "1970-01-01"
	panel.confirm_button().pressed.emit()
	_c("onay anında saat bozulduysa da sonuç YOK (yeniden sınıflandırma), seçim silindi, AYNI nötr hata",
		got.is_empty() and panel.stage() == panel.Stage.ENTRY and panel.error_visible()
		and panel.selection() == {"day": 0, "month": 0, "year": 0} and panel.selector_text(2) == "Seç")
	AgeGate.clock_override = UI_TODAY
	panel.continue_button().pressed.emit()
	var reselected: bool = _select(panel, 1, 1, 2000)
	panel.continue_button().pressed.emit()
	panel.confirm_button().pressed.emit()
	_c("hata sonrası panel yine kullanılabilir: 1 Ocak 2000 -> ADULT", reselected and got.size() == 1
		and got[0][0] == AgeGate.Band.ADULT and got[0][1] == "")
	panel.close_panel()
	panel.queue_free()
	await get_tree().process_frame


func _test_panel_modes() -> void:
	print("-- panel: zorunlu / yeniden giriş kipleri, geri, karartma, X, Vazgeç, tamam, yatışma sinyalleri")
	AgeGate.clock_override = UI_TODAY
	var panel: CanvasLayer = await _make_panel()
	var got: Array = []
	var closed: Array = []
	var opened: Array = []
	var settles: Array = []
	panel.resolved.connect(func(band: int, transition: String) -> void: got.append([band, transition]))
	panel.closed.connect(func() -> void: closed.append(true))
	panel.opened.connect(func() -> void: opened.append(true))
	panel.settle_requested.connect(func() -> void: settles.append(true))
	panel.open_required()
	panel.open_required()
	_c("zorunlu: açılış `opened` TEK kez (açıkken yeniden açma yaymaz)", opened.size() == 1)
	_c("zorunlu: geri tüketilir (true) ve pencere AÇIK kalır — uygulamadan ÇIKILMAZ", panel.handle_back() and panel.visible
		and panel.stage() == panel.Stage.ENTRY and closed.is_empty())
	panel.dim().gui_input.emit(_release_event())
	_c("zorunlu: karartmaya dokunmak KAPATMAZ, X / Vazgeç yok", panel.visible and closed.is_empty()
		and not panel.close_x().visible and not panel.cancel_button().visible)
	panel.selector_button(1).pressed.emit()
	_c("zorunlu: ızgara açıkken geri -> yalnız ızgara kapanır", panel.handle_back() and panel.visible
		and panel.picker_field() == -1 and panel.stage() == panel.Stage.ENTRY)
	panel.selector_button(1).pressed.emit()
	panel.dim().gui_input.emit(_release_event())
	_c("zorunlu: ızgara açıkken karartma da kapatmaz", panel.visible and panel.picker_field() == 1 and closed.is_empty())
	panel.close_picker()
	panel.selector_button(2).pressed.emit()
	panel.picker_back_button().pressed.emit()
	_c("zorunlu: Geri (ızgara başlığı) ızgarayı kapatır", panel.picker_field() == -1 and panel.visible)
	panel.close_panel()
	# Yeniden giriş.
	settles.clear()
	panel.open_reentry()
	await get_tree().process_frame
	_c("yeniden giriş: X + Vazgeç görünür, seçiciler BOŞ (kayıtlı yaş / tarih GÖSTERİLMEZ)", panel.is_reentry()
		and panel.close_x().visible and panel.cancel_button().visible and _same(panel.selected_fields(), [false, false, false]))
	_pick(panel, 2, 2000)
	panel.close_x().pressed.emit()
	_c("X: kapandı, closed 1, sonuç YOK, seçim silindi", not panel.visible and closed.size() == 1 and got.is_empty()
		and panel.selection() == {"day": 0, "month": 0, "year": 0})
	panel.open_reentry()
	_c("yeniden açılış yine BOŞ", panel.selector_text(2) == "Seç")
	_pick(panel, 1, 5)
	panel.cancel_button().pressed.emit()
	_c("Vazgeç: kapandı, closed 2, seçim silindi", not panel.visible and closed.size() == 2
		and panel.selection() == {"day": 0, "month": 0, "year": 0})
	panel.open_reentry()
	panel.dim().gui_input.emit(_release_event())
	_c("karartma (bırakınca): kapandı, closed 3", not panel.visible and closed.size() == 3)
	panel.open_reentry()
	var emu := _release_event()
	emu.device = InputEvent.DEVICE_ID_EMULATION
	panel.dim().gui_input.emit(emu)
	_c("emülasyon olayı karartmayı İKİNCİ kez tetiklemez", panel.visible and closed.size() == 3)
	panel.selector_button(2).pressed.emit()
	panel.dim().gui_input.emit(_release_event())
	_c("ızgara açıkken karartma: kapandı, closed 4", not panel.visible and closed.size() == 4)
	panel.open_reentry()
	_c("geri tuşu yeniden girişte vazgeç: closed 5", panel.handle_back() and not panel.visible and closed.size() == 5)
	panel.open_reentry()
	_select(panel, 1, 1, 1990)
	panel.continue_button().pressed.emit()
	panel.dim().gui_input.emit(_release_event())
	_c("onay adımında karartma kapatmaz (yanlış dokunuş), Vazgeç görünür", panel.visible
		and panel.stage() == panel.Stage.CONFIRM and panel.cancel_button().visible and closed.size() == 5)
	panel.confirm_button().pressed.emit()
	_c("yeniden giriş sonucu yayıldı (ADULT)", got.size() == 1 and got[0][0] == AgeGate.Band.ADULT)
	panel.show_done(true)
	await get_tree().process_frame
	var done_next: PackedStringArray = panel.visible_texts()
	_c("TAMAM adımı + nötr not; X yok (NEXT_LAUNCH yalnız teşhiste)", panel.stage() == panel.Stage.DONE
		and panel.done_note_visible() and panel.done_next_launch() and panel.done_button().visible and not panel.close_x().visible)
	panel.dim().gui_input.emit(_release_event())
	_c("TAMAM adımında karartma kapatmaz", panel.visible and closed.size() == 5)
	_c("TAMAM adımında geri = TAMAM -> kapandı, closed 6", panel.handle_back() and not panel.visible and closed.size() == 6)
	panel.open_reentry()
	panel.show_done(false)
	await get_tree().process_frame
	var done_same: PackedStringArray = panel.visible_texts()
	_c("değişiklik oturuma uygulanabildiyse de AYNI metin + not (ekran cevabı ele vermez)", panel.done_note_visible()
		and not panel.done_next_launch() and done_same == done_next)
	panel.done_button().pressed.emit()
	_c("TAMAM -> kapandı, closed 7", not panel.visible and closed.size() == 7)
	_c("her adım değişimi parmak yatışması istedi (ızgara aç / seç / kapat, onay, kaydedildi, kapanış) — %d sinyal"
		% settles.size(), settles.size() >= 20)
	var done_bad: PackedStringArray = PackedStringArray()
	for text in done_next:
		for word in FORBIDDEN_WORDS:
			if text.to_lower().contains(word):
				done_bad.append("'%s' ⊃ %s" % [text, word])
	_c("'kaydedildi' adımında da yasaklı sözcük / eşik / reklam yok %s" % str(done_bad), done_bad.is_empty())
	panel.queue_free()
	await get_tree().process_frame


func _forbidden_in(texts: PackedStringArray, skip: PackedStringArray) -> PackedStringArray:
	var bad: PackedStringArray = PackedStringArray()
	for text in texts:
		if skip.has(text):
			continue
		var lower: String = text.to_lower()
		for word in FORBIDDEN_WORDS:
			if lower.contains(word):
				bad.append("'%s' ⊃ %s" % [text, word])
	return bad


func _test_panel_neutral_texts() -> void:
	print("-- panel: nötr metin (eşik / reklam / ödül / kilit / yaş grubu / çıkış YOK), görsel dil")
	AgeGate.clock_override = UI_TODAY
	var panel: CanvasLayer = await _make_panel()
	panel.open_required()
	await get_tree().process_frame
	var texts: PackedStringArray = panel.explanatory_texts()
	_c("başlık 'YAŞINI DOĞRULA', alt başlık, gizlilik notu, DEVAM ET", texts.has("YAŞINI DOĞRULA")
		and texts.has("Devam etmek için doğum tarihini seç.") and texts.has("Doğum tarihin cihazından çıkmaz.")
		and texts.has("DEVAM ET") and texts.has("GÜN") and texts.has("AY") and texts.has("YIL"))
	for field in 3:
		panel.selector_button(field).pressed.emit()
		var pick_texts: PackedStringArray = panel.explanatory_texts()
		texts.append_array(pick_texts)
		_c("ızgara başlığı '%s' + 'Geri'" % panel.PICK_TITLES[field], pick_texts.has(panel.PICK_TITLES[field])
			and pick_texts.has("Geri"))
		panel.close_picker()
	_select(panel, 30, 9, 2008)
	panel.continue_button().pressed.emit()
	var confirm_texts: PackedStringArray = panel.explanatory_texts()
	texts.append_array(confirm_texts)
	_c("onay: 'Seçtiğin tarih' + '30 Eylül 2008' + 'Doğru mu?' + DÜZELT + ONAYLA", confirm_texts.has("Seçtiğin tarih")
		and confirm_texts.has("30 Eylül 2008") and confirm_texts.has("Doğru mu?") and confirm_texts.has("DÜZELT")
		and confirm_texts.has("ONAYLA"))
	panel.fix_button().pressed.emit()
	AgeGate.clock_override = "2026-09-26"
	panel.continue_button().pressed.emit()
	texts.append_array(panel.explanatory_texts())
	AgeGate.clock_override = UI_TODAY
	_c("hata adımı metni görünür ve nötr", panel.explanatory_texts().has(panel.ERROR_TEXT))
	var bad: PackedStringArray = _forbidden_in(texts, PackedStringArray(["30 Eylül 2008"]))
	_c("giriş + ızgara + onay + hata adımlarında yasaklı sözcük / eşik / yaş grubu / çıkış yok %s" % str(bad), bad.is_empty())
	_c("tepelik (taç + yıldız sanatı) YOK; üstte küçük nötr Squishy", panel.frame().get_node_or_null("Topper") == null
		and panel.frame().find_child("Squishy", true, false) != null)
	var squishy: TextureRect = panel.frame().find_child("Squishy", true, false)
	_c("Squishy küçük (≤ 100 px) ve bir tier sanatı (ödül / sandık / para / yıldız DEĞİL)", squishy != null
		and squishy.custom_minimum_size.y <= 100.0 and squishy.texture.resource_path.get_file().begins_with("dumpling_tier"))
	var ribbon_free: bool = true
	for node in panel.frame().find_children("*", "TextureRect", true, false):
		var tex: Texture2D = (node as TextureRect).texture
		if tex != null and (node as Control).is_visible_in_tree():
			var file: String = tex.resource_path.get_file().to_lower()
			for word in ["chest", "coin", "star", "crown", "confetti", "reward", "gift", "gold"]:
				if file.contains(word):
					ribbon_free = false
					print("    ödül sanatı: ", file)
	_c("pencerede ödül / sandık / para / yıldız / konfeti sanatı YOK", ribbon_free)
	panel.close_panel()
	panel.queue_free()
	await get_tree().process_frame


func _layout_problems(panel: CanvasLayer, safe_top: float) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var canvas: Rect2 = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var frame: Control = panel.frame()
	var body_panel: Control = frame.get_meta(&"panel")
	var scroll: ScrollContainer = frame.get_meta(&"scroll")
	var footer: Control = frame.get_meta(&"footer")
	var frame_rect: Rect2 = frame.get_global_rect()
	var overhang: float = float(frame.get_meta(&"overhang", UiKit.MODAL_RIBBON_OVERHANG))
	if not canvas.encloses(frame_rect):
		problems.append("pencere tuvalden taşıyor %s" % str(frame_rect))
	if frame_rect.position.y - overhang < safe_top - 0.5:
		problems.append("üst güvenli alana giriyor (%.0f < %.0f)" % [frame_rect.position.y - overhang, safe_top])
	var dim_rect: Rect2 = panel.dim().get_global_rect()
	if not dim_rect.encloses(canvas) or panel.dim().mouse_filter != Control.MOUSE_FILTER_STOP:
		problems.append("karartma tam ekran / dokunuş durduran değil")
	var backdrop: Control = panel.backdrop()
	var base := backdrop.get_node("Base") as ColorRect
	if not backdrop.is_visible_in_tree() or not backdrop.get_global_rect().encloses(canvas) or base.color.a < 0.999:
		problems.append("opak tam ekran zemin yok (arkadaki Ana Sayfa / Ayarlar kontrolleri görünür)")
	for node in backdrop.find_children("*", "Control", true, false):
		if (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			problems.append("zemin dokunuş alıyor: %s" % str(node.name))
	var box := body_panel.get_theme_stylebox("panel") as StyleBoxFlat
	var textured: bool = body_panel.get_theme_stylebox("panel") is StyleBoxTexture
	if box != null and box.bg_color.a < 0.999 and not textured:
		problems.append("pencere zemini saydam (arkadaki ekran içinden görünür)")
	var view: Rect2 = scroll.get_global_rect()
	var controls: Array[Control] = []
	var stage: int = int(panel.stage())
	if stage == panel.Stage.ENTRY:
		for i in 3:
			controls.append(panel.selector_button(i))
		controls.append(panel.frame().find_child("Note", true, false))
		var row_center: float = (panel.selector_button(0).get_global_rect().position.x
			+ panel.selector_button(2).get_global_rect().end.x) * 0.5
		if absf(row_center - frame_rect.get_center().x) > 1.5:
			problems.append("seçici satırı ortada değil (%.1f px kayık — içerik genişliğini aşıyor)" % (row_center - frame_rect.get_center().x))
		if panel.error_visible():
			controls.append(panel.frame().find_child("Error", true, false))
	elif stage == panel.Stage.PICK:
		controls.append(panel.picker_back_button())
		var values: Array[int] = panel.option_values()
		controls.append(panel.option_button(values[0]))
	elif stage == panel.Stage.CONFIRM:
		controls.append(panel.frame().find_child("Date", true, false))
	for control in controls:
		if control == null or not view.encloses(control.get_global_rect()):
			problems.append("kaydırma alanında görünmüyor: %s" % (str(control.name) if control != null else "null"))
		elif footer.visible and control.get_global_rect().end.y > footer.get_global_rect().position.y + 0.5:
			problems.append("altlığın altında: %s" % str(control.name))
	for button: Button in [panel.selector_button(0), panel.continue_button(), panel.confirm_button(), panel.fix_button(),
			panel.cancel_button(), panel.picker_back_button()]:
		if button.is_visible_in_tree():
			if not body_panel.get_global_rect().encloses(button.get_global_rect()):
				problems.append("panel dışında: %s" % str(button.name))
			if button.size.y < float(UiTokens.HEIGHT_NORMAL) - 0.5:
				problems.append("dokunma hedefi küçük: %s %.0f" % [str(button.name), button.size.y])
	if panel.stage() == panel.Stage.PICK:
		var first: Button = panel.option_button(panel.option_values()[0])
		if first.size.y < 60.0 or first.size.x < 60.0:
			problems.append("ızgara seçeneği küçük %s" % str(first.size))
	for label: Label in frame.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and label.autowrap_mode == TextServer.AUTOWRAP_OFF \
				and label.get_minimum_size().x > label.size.x + 1.0:
			problems.append("metin kırpılıyor: '%s'" % label.text)
	return problems


func _test_panel_layout() -> void:
	print("-- panel: 320×568 / 360×640 / 390×844 / 360×800 / 1080×2340 + A36 üst payı (61 px), her adımda")
	AgeGate.clock_override = UI_TODAY
	var panel: CanvasLayer = await _make_panel()
	var sizes: Array = []
	for view in VIEWS:
		sizes.append([view, -1.0])
	sizes.append([Vector2i(1080, 2340), A36_SAFE_TOP])
	for entry: Array in sizes:
		var view: Vector2i = entry[0]
		var safe_top: float = entry[1]
		get_window().size = view
		await get_tree().process_frame
		await get_tree().process_frame
		panel.layout_with_safe_top(safe_top)
		for mode in 2:
			if mode == 0:
				panel.open_required()
			else:
				panel.open_reentry()
			await _settle_frames()
			var tag: String = "%dx%d%s %s" % [view.x, view.y, " A36 üst 61" if safe_top >= 0.0 else "",
				"zorunlu" if mode == 0 else "yeniden giriş"]
			var min_top: float = maxf(safe_top, 0.0)
			var problems: PackedStringArray = _layout_problems(panel, min_top)
			_c("%s — boş: pencere ekranda, seçiciler + not + DEVAM kaydırma alanında ve altlığın üstünde, kırpma yok, gövde kaydırılmıyor %s"
				% [tag, str(problems)], problems.is_empty() and not bool(panel.frame().get_meta(&"body_scrolls", false)))
			var stage_problems: PackedStringArray = PackedStringArray()
			for field in [2, 1, 0]:
				panel.selector_button(field).pressed.emit()
				await _settle_frames()
				for p in _layout_problems(panel, min_top):
					stage_problems.append("ızgara %d: %s" % [field, p])
				var values: Array[int] = panel.option_values()
				panel.option_button(values[0]).pressed.emit()
				await _settle_frames()
			for p in _layout_problems(panel, min_top):
				stage_problems.append("kısmi/tam: " + p)
			panel.continue_button().pressed.emit()
			await _settle_frames()
			for p in _layout_problems(panel, min_top):
				stage_problems.append("onay: " + p)
			panel.fix_button().pressed.emit()
			AgeGate.clock_override = "2026-09-26"
			panel.continue_button().pressed.emit()
			AgeGate.clock_override = UI_TODAY
			await _settle_frames()
			for p in _layout_problems(panel, min_top):
				stage_problems.append("hata: " + p)
			_c("%s — yıl / ay / gün ızgarası, tam seçim, onay, nötr hata: hepsi ekranda ve panelde %s" % [tag, str(stage_problems)],
				stage_problems.is_empty())
			panel.close_panel()
	panel.layout_with_safe_top(-1.0)
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame
	panel.queue_free()
	await get_tree().process_frame


func _settle_frames() -> void:
	for i in 3:
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout


# --- Emekli 13 altı kısıt / çıkış ekranı (TASK/046.1) -----------------------------------------

func _collect_sources(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect_sources(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.ends_with(".gd") or file.ends_with(".tscn") or file.ends_with(".tres"):
			out.append(dir_path.path_join(file))


func _test_retired_flow() -> void:
	print("-- emekli: 13 altı kısıt / çıkış ekranı (dosya, metin, rota) üretim kodunda YOK")
	_c("age_restricted_screen.gd / .tscn dosyaları yok (import edilmiş kaynak da yok)",
		not FileAccess.file_exists("res://scripts/ui/age_restricted_screen.gd")
		and not ResourceLoader.exists("res://scenes/ui/age_restricted_screen.tscn")
		and not ResourceLoader.exists("res://scripts/ui/age_restricted_screen.gd"))
	var sources: PackedStringArray = PackedStringArray()
	_collect_sources("res://scripts", sources)
	_collect_sources("res://scenes", sources)
	# (TFAT `AgeRestrictedTreatment` / `age_restricted_treatment` reklam API adıdır — aranmaz.)
	var needles: Array[String] = ["Üzgünüz", "yaş grubun için", "tasarlanmadı", "ÇIKIŞ", "age_restricted_screen",
		"AGE_RESTRICTED_SCENE", "var _age_restricted:", "_age_restricted.", "exit_requested", "_show_age_restricted", "AgeRestrictedScreen"]
	var hits: PackedStringArray = PackedStringArray()
	for path in sources:
		var text: String = FileAccess.get_file_as_string(path)
		for needle in needles:
			if text.contains(needle):
				hits.append("%s ⊃ %s" % [path.get_file(), needle])
	_c("scripts/ + scenes/ (%d dosya): kısıt ekranı metni ('Üzgünüz' / 'yaş grubun için' / 'ÇIKIŞ') ve rotası YOK %s"
		% [sources.size(), str(hits)], sources.size() > 50 and hits.is_empty())
	var main_script: Script = load("res://scripts/main.gd")
	var main_methods: Array = []
	for info: Dictionary in main_script.get_script_method_list():
		main_methods.append(info["name"])
	_c("Main'de kısıt ekranı yöntemi yok; yaş ekranında geri uygulamadan ÇIKMAZ (handle_back tüketir, _quit_app çağrılmaz)",
		not main_methods.has("_show_age_restricted") and not main_methods.has("age_restricted_screen")
		and _main_age_back_branch_ok())
	var panel: CanvasLayer = PANEL_SCENE.instantiate()
	var panel_signals: Array = []
	for info: Dictionary in panel.get_signal_list():
		panel_signals.append(info["name"])
	panel.free()
	_c("panel sinyalleri: resolved / closed / opened / settle_requested — çıkış isteği sinyali YOK",
		panel_signals.has("resolved") and not panel_signals.has("exit_requested") and not panel_signals.has("quit_requested"))
	var gate_src: String = FileAccess.get_file_as_string("res://scripts/ui/age_gate_panel.gd")
	_c("panel resolved'ı yalnız seçim sınıflandırıcısından yayar (classify_selected_birth_date — UNDER_13 üretemez)",
		gate_src.contains("AgeGate.classify_selected_birth_date(") and not gate_src.contains("AgeGate.classify_birth_date("))


## Main'in geri işleyicisinde yaş paneli dalı: panel.handle_back() + return, _quit_app YOK.
func _main_age_back_branch_ok() -> bool:
	var src: String = FileAccess.get_file_as_string("res://scripts/main.gd").replace("\r\n", "\n")
	var branch: String = "\tif _age_panel != null and _age_panel.visible:\n\t\t_age_panel.handle_back()\n\t\treturn\n"
	return src.contains(branch)
