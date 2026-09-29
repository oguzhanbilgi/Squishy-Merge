extends Node
## TASK/046 — Günlük / Haftalık Görevler V1 çekirdek testi. Headless.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_missions/` altındaki
## bir yola yönlendirilir (`save_path`, TASK/045.1 test dikişi) ve sonda geri alınır; gerçek
## kayıt ailesinin (kanonik + .tmp + .bak) baytları başta / sonda karşılaştırılır.
##
##   godot --headless --audio-driver Dummy --path . res://tools/missions_test.tscn
##
## Kontroller:
##   katalog     tam 6 görev (id / dönem / metrik / hedef / ödül / metin), 30 / 120 / 330 tavanı
##   gün/hafta   gün anahtarı doğrulama (artık yıl, ay sonu, biçim); pazartesi haftası: pazar →
##               pazartesi, aynı hafta, ay / yıl sınırı, artık yıl; 1200 ardışık günde kaba kuvvet
##   doğrulama   sözlük değil / sürüm / gün bozuk → dönem yok; JSON float; negatif / saçma büyük /
##               NaN / metin ilerleme; bilinmeyen / öteki dönem id; tekrar ödül işareti; sınırlı
##               ham dizi; tutarsız hafta; ödüllü = hedef; idempotent
##   dönem       aynı gün; ileri gün (günlük sıfır, haftalık aynen); ay / yıl sınırı; artık yıl;
##               pazar → pazartesi; geri alınan saat eski dönemi GETİRMEZ (gün ve hafta)
##   ilerleme    altı görevin yolu, kısmi, tam hedef, taşma kırpılır, tek sefer ödül, günlük +
##               haftalık aynı round (+50), altısı birden (+150), negatif / saçma büyük girdi
##   kayıt       eski kayıt → taze dönem (geriye dönük ilerleme / Hamur YOK), yüklemede yazma yok,
##               idempotent, doğal kayıtta kalıcı; bozuk yapı; yeni oyuncu; kanonik / .tmp / .bak
##               kurtarması görev durumunu taşır
##   saat        kabul edilen gün = DailyRewards.day_key(); geri alma yeni ödül / eski dönem
##               üretmez; bozuk "en yeni gün" → cihaz günü; ikisi de bozuk → kayıtlı dönem aynen
##               (yeniden ödül yok); ileri gün / pazartesi yeni dönem ödülü
##   round       gerçek Main: kazanma / kayıp / tekrar / sonsuz (kazanma dahil level sayılmaz) /
##               terk / yeniden başlatma / süreç ölümü / bitmemiş round / yinelenen kesinleştirme
##               / eski board; tek yazma; çoklu tamamlama + otomatik Hamur toplamı; yeni gün
##               yeniden ödül; görev ödülü XP / başarım / unvan / yıldız / tur DEĞİŞTİRMEZ
##   tutorial    tutorial tamamlanması 0 görev; öğretim round'u (gerçek Level 1) normal kurallarla
##   reklam      sahte arka uçla: kesinleştirme + görev ödülü sırasında arka uç çağrısı yok, sonuç
##               sonrası ödüllü / geçiş gösterimi yok, sonuç ekranında banner gizli; pencere
##               yüzey / banner değiştirmez; kaynak sözleşmesi (reklam / yaş / seri / XP / başarım yok, Main'de tek çağrı)

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_missions"
const PATH: String = DIR + "/save.json"
const TMP: String = PATH + SaveFile.TEMP_SUFFIX
const BAK: String = PATH + SaveFile.BACKUP_SUFFIX
const SECTIONS: int = 10
## Takvim: 2026-09-28 pazartesi.
const MON: String = "2026-09-28"
const TUE: String = "2026-09-29"
const WED: String = "2026-09-30"
const THU: String = "2026-10-01"
const FRI: String = "2026-10-02"
const SAT: String = "2026-10-03"
const SUN: String = "2026-10-04"
const NEXT_MON: String = "2026-10-05"
const NEXT_TUE: String = "2026-10-06"
const DAILY: StringName = Missions.PERIOD_DAILY
const WEEKLY: StringName = Missions.PERIOD_WEEKLY

var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _finished: bool = false
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _main: Node2D
var _main_script: GDScript


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_main_script = load("res://scripts/main.gd")
	_owner_state = _owner_snapshot()
	_saved_data = SaveManager.data.duplicate(true)
	_c("başlangıç: SaveManager gerçek kayıt yolunda, hata enjeksiyonu kapalı",
		SaveManager.save_path == SaveManager.SAVE_PATH and SaveFile.fault == SaveFile.Fault.NONE)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	SaveManager.save_path = PATH
	get_tree().create_timer(360.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 360 s'de bitmedi — SaveManager geri alındı")
			# Main ÖNCE gider: yol gerçek kayda döndükten sonra yarım kalmış bir akış oraya yazamaz.
			if _main != null and is_instance_valid(_main):
				_main.free()
			_teardown()
			get_tree().quit(2))

	_catalog()
	_keys()
	_sanitize_rules()
	_period_rules()
	_advance_rules()
	_persistence()
	_clock()
	await _round_flow()
	await _tutorial_round()
	await _ads_and_sources()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	print("-- kayıt")
	await _teardown_main()
	_teardown()
	_c("SaveManager gerçek yola döndü, test klasörü silindi, saat kancası / hata enjeksiyonu boş",
		SaveManager.save_path == SaveManager.SAVE_PATH and not DirAccess.dir_exists_absolute(DIR)
		and DailyRewards.clock_override == "" and SaveFile.fault == SaveFile.Fault.NONE)
	_c("sahibin gerçek kayıt ailesi (kanonik + .tmp + .bak) bayt-aynı", _owner_snapshot() == _owner_state)
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
	DailyRewards.clock_override = ""
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- 1) Katalog --------------------------------------------------------------------------

func _catalog() -> void:
	print("-- katalog (kilitli V1)")
	var expected: Array = [
		[&"daily_merges", DAILY, Missions.METRIC_MERGES, 15, 10, "15 birleşme yap"],
		[&"daily_rounds", DAILY, Missions.METRIC_ROUNDS, 2, 10, "2 tur tamamla"],
		[&"daily_clear", DAILY, Missions.METRIC_CLEARS, 1, 10, "1 level tamamla"],
		[&"weekly_merges", WEEKLY, Missions.METRIC_MERGES, 120, 40, "120 birleşme yap"],
		[&"weekly_rounds", WEEKLY, Missions.METRIC_ROUNDS, 12, 40, "12 tur tamamla"],
		[&"weekly_clears", WEEKLY, Missions.METRIC_CLEARS, 5, 40, "5 level tamamla"],
	]
	_c("tam altı görev (3 günlük + 3 haftalık)", Missions.CATALOG.size() == 6 and Missions.ids().size() == 6
		and Missions.ids_for(DAILY).size() == 3 and Missions.ids_for(WEEKLY).size() == 3)
	var ok: bool = true
	for i in expected.size():
		var want: Array = expected[i]
		var entry: Dictionary = Missions.CATALOG[i]
		if entry["id"] != want[0] or entry["period"] != want[1] or entry["metric"] != want[2] \
				or int(entry["target"]) != int(want[3]) or int(entry["reward"]) != int(want[4]) \
				or Missions.title(want[0]) != String(want[5]):
			ok = false
			print("    uyuşmuyor: ", entry, " ≠ ", want)
	_c("id / dönem / metrik / hedef / ödül / metin birebir (sıra = gösterim)", ok)
	_c("günlük tavan 30, haftalık 120 Hamur; haftada en fazla 7·30 + 120 = 330", Missions.max_reward(DAILY) == 30
		and Missions.max_reward(WEEKLY) == 120 and 7 * Missions.max_reward(DAILY) + Missions.max_reward(WEEKLY) == 330)
	_c("bilinmeyen id: katalogda yok, hedef 0, ödül 0, metin boş", not Missions.is_known(&"daily_bogus")
		and Missions.target_of(&"daily_bogus") == 0 and Missions.reward_of(&"daily_bogus") == 0
		and Missions.title(&"daily_bogus") == "")
	_c("sürüm 1", Missions.VERSION == 1)
	_sections_done += 1


# --- 2) Gün / hafta anahtarı ---------------------------------------------------------------

func _keys() -> void:
	print("-- gün / pazartesi haftası")
	var valid: Array = ["2026-09-29", "2028-02-29", "2000-02-29", "2026-12-31", "2027-01-01", "9999-12-31", "2000-01-01"]
	var invalid: Array = ["", "2026-9-29", "2026-02-29", "2100-02-29", "2026-13-01", "2026-00-10", "2026-04-31",
		"2026-09-00", "abcd-ef-gh", "1999-12-31", "2026-09-29T00:00:00", " 2026-09-29", "2026/09/29", "+026-09-29",
		20260929, 2026.0, null, [], {}, &"2026-09-29"]
	var valid_ok: bool = true
	for key: Variant in valid:
		if not Missions.is_day_key(key):
			valid_ok = false
			print("    reddedildi: ", key)
	var invalid_ok: bool = true
	for key: Variant in invalid:
		if Missions.is_day_key(key):
			invalid_ok = false
			print("    kabul edildi: ", key)
	_c("geçerli günler kabul (artık 2028-02-29, 2000-02-29, ay / yıl sonu)", valid_ok)
	_c("geçersiz günler reddedilir (2026-02-29, 2100-02-29, 13. ay, 31 nisan, biçim, metin olmayan, < 2000)", invalid_ok)
	var samples: Array = [
		[MON, MON], [TUE, MON], [SUN, MON], [NEXT_MON, NEXT_MON], [NEXT_TUE, NEXT_MON],
		[THU, MON], [WED, MON],
		["2026-12-31", "2026-12-28"], ["2027-01-01", "2026-12-28"], ["2027-01-03", "2026-12-28"],
		["2027-01-04", "2027-01-04"], ["2028-02-29", "2028-02-28"], ["2028-03-01", "2028-02-28"],
		["2024-03-03", "2024-02-26"], ["2000-01-01", "1999-12-27"],
	]
	var sample_ok: bool = true
	for pair: Array in samples:
		if Missions.week_start(pair[0]) != pair[1]:
			sample_ok = false
			print("    hafta(%s) = %s, beklenen %s" % [pair[0], Missions.week_start(pair[0]), pair[1]])
	_c("pazartesi haftası: aynı hafta, pazar → aynı pazartesi, ay sınırı (01 Eki → 28 Eyl), yıl sınırı (01 Oca 2027 → 28 Ara 2026), artık yıl (29 Şub 2028)", sample_ok)
	_c("pazar → pazartesi: 2026-10-04 haftası 09-28, 2026-10-05 haftası 10-05 (yeni hafta)",
		Missions.week_start(SUN) == MON and Missions.week_start(NEXT_MON) == NEXT_MON
		and Missions.week_start(SUN) != Missions.week_start(NEXT_MON))
	# Kaba kuvvet: 1200 ardışık gün (iki yıl sınırı + 2028 artık yılı dahil).
	var base: int = Time.get_unix_time_from_datetime_string("2025-12-01T00:00:00")
	var brute_ok: bool = true
	var previous_week: String = ""
	for i in 1200:
		var day: String = Time.get_date_string_from_unix_time(base + i * 86400)
		var week: String = Missions.week_start(day)
		var week_unix: int = Time.get_unix_time_from_datetime_string(week + "T00:00:00")
		var offset: int = (base + i * 86400 - week_unix) / 86400
		var monday: bool = int(Time.get_date_dict_from_unix_time(week_unix)["weekday"]) == 1
		var is_monday: bool = int(Time.get_date_dict_from_unix_time(base + i * 86400)["weekday"]) == 1
		var chained: bool = i == 0 or (week == day if is_monday else week == previous_week)
		if not monday or offset < 0 or offset > 6 or not chained:
			brute_ok = false
			print("    %s → %s (fark %d, pazartesi %s)" % [day, week, offset, str(monday)])
			break
		previous_week = week
	_c("1200 ardışık gün: hafta her zaman pazartesi, gün − hafta 0..6, yalnız pazartesi yeni hafta açar", brute_ok)
	_c("geçersiz günün haftası boş", Missions.week_start("2026-02-30") == "" and Missions.week_start("") == "")
	_sections_done += 1


# --- 3) Doğrulama ---------------------------------------------------------------------------

func _sanitize_rules() -> void:
	print("-- doğrulama (bozuk kayıt güvenli)")
	var fresh: Dictionary = Missions.fresh_state(TUE)
	_c("taze dönem: sürüm 1, gün TUE, hafta MON, 3 + 3 görev 0, ödül işareti yok", int(fresh["version"]) == 1
		and fresh["day_key"] == TUE and fresh["week_start_day_key"] == MON
		and fresh["daily_progress"] == {"daily_merges": 0, "daily_rounds": 0, "daily_clear": 0}
		and fresh["weekly_progress"] == {"weekly_merges": 0, "weekly_rounds": 0, "weekly_clears": 0}
		and (fresh["daily_rewarded"] as Array).is_empty() and (fresh["weekly_rewarded"] as Array).is_empty())
	var bad: Array = [null, [], "x", 5, {}, _raw(TUE, {}, [], {}, [], 2), _raw(TUE, {}, [], {}, [], 0),
		{"day_key": TUE, "week_start_day_key": MON}, _raw("garbage", {}, [], {}, []), _raw("2026-02-30", {}, [], {}, [])]
	var bad_raw: Dictionary = _raw(TUE, {}, [], {}, [])
	bad_raw["version"] = "1"
	bad.append(bad_raw)
	var int_day: Dictionary = _raw(TUE, {}, [], {}, [])
	int_day["day_key"] = 20260929
	bad.append(int_day)
	var rejected: bool = true
	for value: Variant in bad:
		if not Missions.sanitize(value).is_empty():
			rejected = false
			print("    kabul edildi: ", value)
	_c("sözlük değil / sürüm 0-2-'1' / sürümsüz / gün bozuk → kullanılabilir dönem yok (çökme yok)", rejected)
	var raw: Dictionary = {"version": 1.0, "day_key": TUE, "week_start_day_key": MON,
		"daily_progress": {"daily_merges": 7.0, "daily_rounds": -3, "daily_clear": "1", "daily_bogus": 5, "weekly_merges": 50},
		"daily_rewarded": ["weekly_merges", "bogus", 7, null],
		"weekly_progress": {"weekly_merges": 1e300, "weekly_rounds": 5, "weekly_clears": NAN},
		"weekly_rewarded": ["weekly_rounds", "weekly_rounds", "daily_merges", "weekly_bogus"], "extra": 1}
	var clean: Dictionary = Missions.sanitize(raw)
	var daily: Dictionary = clean.get("daily_progress", {})
	var weekly: Dictionary = clean.get("weekly_progress", {})
	_c("JSON float (sürüm 1.0, ilerleme 7.0) okunur: daily_merges 7", daily.get("daily_merges", -1) == 7)
	_c("negatif ilerleme → 0; metin ilerleme → 0", daily.get("daily_rounds", -1) == 0 and daily.get("daily_clear", -1) == 0)
	_c("bilinmeyen / öteki dönemin id'si ilerlemeden düştü (tam 3 anahtar)", daily.size() == 3 and not daily.has("daily_bogus")
		and not daily.has("weekly_merges"))
	_c("günlük ödül işareti: öteki dönem / bilinmeyen / metin olmayan düştü → boş", (clean["daily_rewarded"] as Array).is_empty())
	_c("saçma büyük ilerleme (1e300, ödülsüz) → hedef − 1 (119); NaN → 0", weekly.get("weekly_merges", -1) == 119
		and weekly.get("weekly_clears", -1) == 0)
	_c("ödüllü görev ilerlemesi = hedef (weekly_rounds 5 → 12)", weekly.get("weekly_rounds", -1) == 12)
	_c("tekrar eden ödül işareti tekilleşti, öteki dönem düştü → [weekly_rounds]", clean["weekly_rewarded"] == ["weekly_rounds"])
	_c("bilinmeyen üst anahtar düştü; biçim tam 7 anahtar", not clean.has("extra") and clean.size() == 7)
	_c("idempotent: doğrulanmışı yeniden doğrulamak aynı", Missions.sanitize(clean) == clean)
	var order: Dictionary = Missions.sanitize(_raw(TUE, {}, ["daily_rounds", "daily_merges", "daily_rounds"], {}, []))
	_c("ödül işaretleri katalog sırasında, tekrarsız: [daily_merges, daily_rounds]",
		order["daily_rewarded"] == ["daily_merges", "daily_rounds"]
		and order["daily_progress"] == {"daily_merges": 15, "daily_rounds": 2, "daily_clear": 0})
	var huge: Array = ["daily_clear"]
	for i in 100000:
		huge.append("junk_%d" % (i % 7))
	var start: int = Time.get_ticks_msec()
	var bounded: Dictionary = Missions.sanitize(_raw(TUE, {}, huge, {}, []))
	_c("100 001 öğelik ödül dizisi sınırlı okunur (%d ms): baştaki geçerli id kaldı" % (Time.get_ticks_msec() - start),
		bounded["daily_rewarded"] == ["daily_clear"] and Time.get_ticks_msec() - start < 1000)
	var late: Array = []
	for i in 40:
		late.append("junk")
	late.append("daily_merges")
	_c("tavan (%d) sonrasındaki id okunmaz (bozuk kayıt açılışı kilitlemez)" % Missions.RAW_CAP,
		(Missions.sanitize(_raw(TUE, {}, late, {}, []))["daily_rewarded"] as Array).is_empty())
	var odd_week: Dictionary = _raw(TUE, {"daily_merges": 4}, [], {"weekly_merges": 60}, ["weekly_clears"])
	odd_week["week_start_day_key"] = NEXT_MON
	var odd: Dictionary = Missions.sanitize(odd_week)
	_c("tutarsız hafta (gün TUE, hafta 10-05): haftalık kısım taze, günlük korunur, hafta = günün pazartesisi",
		odd["week_start_day_key"] == MON and odd["weekly_progress"]["weekly_merges"] == 0
		and (odd["weekly_rewarded"] as Array).is_empty() and odd["daily_progress"]["daily_merges"] == 4)
	var shapes: Dictionary = _raw(TUE, {}, [], {}, [])
	shapes["daily_progress"] = "bozuk"
	shapes["daily_rewarded"] = {"daily_merges": true}
	shapes["weekly_progress"] = [1, 2, 3]
	shapes["weekly_rewarded"] = "weekly_rounds"
	var shaped: Dictionary = Missions.sanitize(shapes)
	_c("sözlük olmayan ilerleme / dizi olmayan ödül işareti → sıfır / boş (çökme yok)", not shaped.is_empty()
		and shaped["daily_progress"]["daily_merges"] == 0 and (shaped["daily_rewarded"] as Array).is_empty()
		and shaped["weekly_progress"]["weekly_rounds"] == 0 and (shaped["weekly_rewarded"] as Array).is_empty())
	_sections_done += 1


# --- 4) Dönem -----------------------------------------------------------------------------------

func _period_rules() -> void:
	print("-- dönem (günlük / pazartesi haftası / geri alma)")
	var s: Dictionary = _raw(TUE, {"daily_merges": 7, "daily_rounds": 2}, ["daily_rounds"],
		{"weekly_merges": 40, "weekly_clears": 5}, ["weekly_clears"])
	var copy: Dictionary = s.duplicate(true)
	_c("aynı gün: dönem aynen", Missions.for_day(s, TUE) == Missions.sanitize(s))
	var wed: Dictionary = Missions.for_day(s, WED)
	_c("ileri gün (aynı hafta): günlük sıfır + ödül işareti boş, haftalık aynen", wed["day_key"] == WED
		and wed["week_start_day_key"] == MON and _zero(wed, DAILY)
		and wed["weekly_progress"]["weekly_merges"] == 40 and wed["weekly_rewarded"] == ["weekly_clears"])
	_c("for_day girdiyi değiştirmez", s == copy)
	var month: Dictionary = Missions.for_day(_raw(WED, {"daily_clear": 1}, ["daily_clear"], {"weekly_rounds": 3}, []), THU)
	_c("ay sınırı (30 Eyl → 01 Eki): günlük sıfır, haftalık aynen (hafta 09-28)", _zero(month, DAILY)
		and month["week_start_day_key"] == MON and month["weekly_progress"]["weekly_rounds"] == 3)
	var monday: Dictionary = Missions.for_day(_raw(SUN, {"daily_rounds": 1}, [], {"weekly_rounds": 11, "weekly_clears": 5},
		["weekly_clears"]), NEXT_MON)
	_c("pazar → pazartesi: günlük VE haftalık sıfır, hafta 10-05", _zero(monday, DAILY) and _zero(monday, WEEKLY)
		and monday["week_start_day_key"] == NEXT_MON)
	var jump: Dictionary = Missions.for_day(s, NEXT_TUE)
	_c("hafta atlayan ileri gün (TUE → sonraki TUE): ikisi de sıfır", _zero(jump, DAILY) and _zero(jump, WEEKLY)
		and jump["week_start_day_key"] == NEXT_MON)
	var year: Dictionary = _raw("2026-12-31", {"daily_merges": 3}, [], {"weekly_merges": 70}, [])
	var new_year: Dictionary = Missions.for_day(year, "2027-01-01")
	var next_week: Dictionary = Missions.for_day(new_year, "2027-01-04")
	_c("yıl sınırı: 31 Ara → 01 Oca aynı hafta (12-28) haftalık aynen; 04 Oca pazartesi haftalık sıfır",
		_zero(new_year, DAILY) and new_year["week_start_day_key"] == "2026-12-28"
		and new_year["weekly_progress"]["weekly_merges"] == 70 and _zero(next_week, WEEKLY)
		and next_week["week_start_day_key"] == "2027-01-04")
	var leap: Dictionary = Missions.for_day(_raw("2028-02-28", {}, [], {"weekly_rounds": 4}, []), "2028-02-29")
	var march: Dictionary = Missions.for_day(leap, "2028-03-01")
	_c("artık yıl: 28 Şub → 29 Şub → 01 Mar aynı hafta (02-28), haftalık aynen", leap["day_key"] == "2028-02-29"
		and march["week_start_day_key"] == "2028-02-28" and march["weekly_progress"]["weekly_rounds"] == 4)
	var future: Dictionary = _raw(FRI, {"daily_rounds": 1}, ["daily_clear"], {"weekly_rounds": 6}, [])
	var rolled: Dictionary = Missions.for_day(future, WED)
	_c("geri alınan saat (kayıt FRI, gün WED): kayıttaki dönem aynen — eski dönem geri gelmez, ödül işareti korunur",
		rolled == Missions.sanitize(future) and rolled["day_key"] == FRI and rolled["daily_rewarded"] == ["daily_clear"])
	var newer_week: Dictionary = _raw(NEXT_TUE, {}, [], {"weekly_merges": 12}, ["weekly_rounds"])
	var back: Dictionary = Missions.for_day(newer_week, FRI)
	_c("yeni hafta kabul edildikten sonra saat önceki haftaya alındı: hafta 10-05 kalır (asla geri gitmez)",
		back["week_start_day_key"] == NEXT_MON and back["weekly_rewarded"] == ["weekly_rounds"]
		and back["weekly_progress"]["weekly_merges"] == 12)
	_c("kayıt yok / bozuk → kabul edilen günün taze dönemi", Missions.for_day(null, WED) == Missions.fresh_state(WED)
		and Missions.for_day("bozuk", WED) == Missions.fresh_state(WED))
	_c("kabul edilen gün yok (bozuk saat) → kayıt aynen; ikisi de yok → boş", Missions.for_day(s, "") == Missions.sanitize(s)
		and Missions.for_day(null, "").is_empty())
	_sections_done += 1


# --- 5) İlerleme ----------------------------------------------------------------------------------

func _advance_rules() -> void:
	print("-- ilerleme + otomatik ödül (saf)")
	var base: Dictionary = Missions.fresh_state(TUE)
	var r1: Dictionary = Missions.advance(base, 7, 1, 0)
	var s1: Dictionary = r1["state"]
	_c("kısmi: merge 7 → günlük 7/15 + haftalık 7/120; tur 1/2 + 1/12; level 0; ödül yok",
		s1["daily_progress"] == {"daily_merges": 7, "daily_rounds": 1, "daily_clear": 0}
		and s1["weekly_progress"] == {"weekly_merges": 7, "weekly_rounds": 1, "weekly_clears": 0}
		and (r1["completed"] as Array).is_empty() and int(r1["dough"]) == 0)
	_c("advance girdiyi değiştirmez", base == Missions.fresh_state(TUE))
	var r2: Dictionary = Missions.advance(s1, 8, 1, 1)
	var s2: Dictionary = r2["state"]
	_c("tam hedef: 15 merge + 2 tur + 1 level → üç günlük görev tamamlandı (katalog sırası), +30",
		r2["completed"] == [&"daily_merges", &"daily_rounds", &"daily_clear"] and int(r2["dough"]) == 30
		and s2["daily_rewarded"] == ["daily_merges", "daily_rounds", "daily_clear"]
		and s2["daily_progress"] == {"daily_merges": 15, "daily_rounds": 2, "daily_clear": 1})
	_c("altı görevin yolu: haftalık merge 15/120, tur 2/12, level 1/5 aynı round'dan",
		s2["weekly_progress"] == {"weekly_merges": 15, "weekly_rounds": 2, "weekly_clears": 1})
	var r3: Dictionary = Missions.advance(s2, 50, 1, 1)
	var s3: Dictionary = r3["state"]
	_c("tek sefer: tamamlanan günlük görevler yeniden ödül vermez, ilerleme hedefte kalır",
		(r3["completed"] as Array).is_empty() and int(r3["dough"]) == 0
		and s3["daily_progress"] == s2["daily_progress"] and s3["daily_rewarded"] == s2["daily_rewarded"])
	_c("haftalık ilerlemeye devam: merge 65, tur 3, level 2", s3["weekly_progress"] == {"weekly_merges": 65,
		"weekly_rounds": 3, "weekly_clears": 2})
	var near: Dictionary = Missions.sanitize(_raw(TUE, {"daily_merges": 14}, [], {"weekly_merges": 119}, []))
	var pair: Dictionary = Missions.advance(near, 1, 0, 0)
	_c("örnek (brief): daily_merges +10 + weekly_merges +40 aynı round → +50", pair["completed"] == [&"daily_merges", &"weekly_merges"]
		and int(pair["dough"]) == 50)
	var edge: Dictionary = Missions.sanitize(_raw(TUE, {"daily_merges": 14, "daily_rounds": 1}, [],
		{"weekly_merges": 119, "weekly_rounds": 11, "weekly_clears": 4}, []))
	var all_six: Dictionary = Missions.advance(edge, 1, 1, 1)
	_c("altı görev tek round'da: 6 tamamlama, 3·10 + 3·40 = +150", (all_six["completed"] as Array).size() == 6
		and int(all_six["dough"]) == 150 and Missions.completed_count(all_six["state"]) == 6)
	var over: Dictionary = Missions.advance(Missions.fresh_state(TUE), 1000, 0, 0)
	_c("taşma kırpılır: 1000 merge → 15/15 + 120/120, iki ödül (+50), tur / level ilerlemedi",
		over["state"]["daily_progress"]["daily_merges"] == 15 and over["state"]["weekly_progress"]["weekly_merges"] == 120
		and int(over["dough"]) == 50 and over["state"]["daily_progress"]["daily_rounds"] == 0)
	var neg: Dictionary = Missions.advance(Missions.fresh_state(TUE), -5, -1, -3)
	_c("negatif girdi hiçbir şeyi değiştirmez", neg["state"] == Missions.fresh_state(TUE) and int(neg["dough"]) == 0)
	var massive: Dictionary = Missions.advance(Missions.fresh_state(TUE), 9223372036854775000, 0, 0)
	_c("saçma büyük merge sayısı int taşırmaz: 15 / 120 hedefte", massive["state"]["daily_progress"]["daily_merges"] == 15
		and massive["state"]["weekly_progress"]["weekly_merges"] == 120)
	var late: Dictionary = Missions.advance(Missions.sanitize(_raw(TUE, {"daily_merges": 14}, ["daily_rounds"], {}, [])), 1, 0, 0)
	_c("sonradan tamamlanan görev yine katalog sırasına girer: [daily_merges, daily_rounds]",
		late["state"]["daily_rewarded"] == ["daily_merges", "daily_rounds"])
	_c("boş durum (dönem yok) no-op", Missions.advance({}, 5, 1, 1)["state"].is_empty()
		and int(Missions.advance({}, 5, 1, 1)["dough"]) == 0)
	_sections_done += 1


# --- 6) Kayıt / göç / kurtarma ------------------------------------------------------------------

func _persistence() -> void:
	print("-- kayıt: göç / idempotent / bozuk / kurtarma (test yolu)")
	_clean()
	DailyRewards.clock_override = TUE
	_write(PATH, _legacy({}))
	var bytes: PackedByteArray = _bytes(PATH)
	SaveManager.load_game()
	var memory: Dictionary = SaveManager.data["missions"]
	_c("eski kayıt (görev yok): bellekte kabul edilen günün TAZE dönemi (TUE / MON, 0, ödül yok)",
		memory == Missions.fresh_state(TUE))
	_c("geriye dönük ilerleme YOK (812 merge, 3 level'lı kayıt) ve Hamur verilmedi (335)",
		Missions.completed_count(SaveManager.missions_state()) == 0 and SaveManager.dough() == 335
		and SaveManager.missions_state()["daily_progress"]["daily_merges"] == 0)
	_c("göç yüklemede diske YAZMADI (kanonik bayt-aynı, .tmp / .bak yok)", _bytes(PATH) == bytes and not _exists(TMP)
		and not _exists(BAK))
	SaveManager.load_game()
	_c("ikinci yükleme: aynı durum, yine yazma yok", SaveManager.data["missions"] == memory and _bytes(PATH) == bytes)
	SaveManager.save_game()
	var disk: Dictionary = _disk()
	_c("doğal kayıt görev durumunu kalıcılaştırdı (sürüm 1, gün TUE, hafta MON)", Missions.sanitize(disk.get("missions"))
		== memory and int((disk["missions"] as Dictionary)["version"]) == 1)
	SaveManager.load_game()
	_c("kalıcı kayıttan yükleme: aynı durum (kanonik)", SaveManager.data["missions"] == memory
		and SaveManager.load_source() == SaveFile.Source.CANONICAL)

	for bad: Variant in ["bozuk", [], 7, {"version": 2, "day_key": TUE}, {"version": 1, "day_key": "dün"}]:
		_write(PATH, _legacy({"missions": bad}))
		bytes = _bytes(PATH)
		SaveManager.load_game()
		_c("bozuk görev yapısı (%s) → taze dönem, çökme yok, yazma yok" % str(bad).left(40),
			SaveManager.data["missions"] == Missions.fresh_state(TUE) and _bytes(PATH) == bytes)
	var junk: Dictionary = _raw(TUE, {"daily_merges": 3.0, "bogus": 9}, ["daily_rounds", "daily_rounds", "x"], {}, [])
	_write(PATH, _legacy({"missions": junk}))
	bytes = _bytes(PATH)
	SaveManager.load_game()
	_c("geçerli ama kirli kayıt bellekte temizlendi (bilinmeyen id / tekrar düştü), yükleme yazmadı",
		SaveManager.data["missions"] == Missions.sanitize(junk) and _bytes(PATH) == bytes
		and SaveManager.data["missions"]["daily_rewarded"] == ["daily_rounds"])

	_clean()
	SaveManager.load_game()
	var new_disk: Dictionary = _disk()
	_c("yeni oyuncu: dosya yazıldı (başlangıç hediyesi), görev dönemi yok (gün boş) — okuma TUE'nin taze dönemi",
		(new_disk.get("missions", {}) as Dictionary).get("day_key", "x") == ""
		and SaveManager.missions_state() == Missions.fresh_state(TUE))
	var none_dough: int = SaveManager.dough()
	var first: Dictionary = SaveManager.record_mission_round(5, false)
	_c("yeni oyuncunun ilk round kaydı dönemi yazar (TUE) — ödül yok", Missions.sanitize(_disk().get("missions"))["day_key"] == TUE
		and (first["completed"] as Array).is_empty() and SaveManager.dough() == none_dough)

	# Kurtarma: görev durumu normal yükün parçası (SaveFile aynen).
	SaveManager.record_mission_round(3, false)
	var gen2: Dictionary = SaveManager.data["missions"].duplicate(true)
	_c("ön koşul: 5 + 3 merge = 8, 2 tur → daily_rounds tamamlandı (+10)", gen2["daily_progress"]["daily_merges"] == 8
		and gen2["daily_rewarded"] == ["daily_rounds"] and SaveManager.dough() == none_dough + 10)
	SaveManager.load_game()
	_c("kanonik: kaynak CANONICAL, görev durumu aynı", SaveManager.load_source() == SaveFile.Source.CANONICAL
		and SaveManager.data["missions"] == gen2)
	SaveFile.fault = SaveFile.Fault.CRASH_AFTER_BACKUP
	SaveManager.record_mission_round(4, false)
	var gen3: Dictionary = SaveManager.data["missions"].duplicate(true)
	_c("ön koşul: yer değiştirmede ölüm — kanonik ad boş, .tmp (yeni) + .bak (eski)", not _exists(PATH) and _exists(TMP)
		and _exists(BAK))
	SaveManager.load_game()
	_c("geçerli .tmp kurtarması görev durumunu taşır (TEMP, merge 12)", SaveManager.load_source() == SaveFile.Source.TEMP
		and SaveManager.data["missions"] == gen3 and gen3["daily_progress"]["daily_merges"] == 12)
	var torn: String = FileAccess.get_file_as_string(PATH).substr(0, 40)
	_put(PATH, torn.to_utf8_buffer())
	SaveManager.load_game()
	_c("bozuk kanonik → geçerli .bak kurtarması bir önceki kuşağın görev durumunu taşır (BACKUP, merge 8)",
		SaveManager.load_source() == SaveFile.Source.BACKUP and SaveManager.data["missions"] == gen2)
	SaveFile.fault = SaveFile.Fault.NONE
	_sections_done += 1


# --- 7) Saat --------------------------------------------------------------------------------------

func _clock() -> void:
	print("-- saat: kabul edilen gün / geri alma / ileri gün / pazartesi")
	_clean()
	_write(PATH, _fixture({}))
	DailyRewards.clock_override = FRI
	SaveManager.load_game()
	DailyRewards.observe_day()
	_c("kabul edilen gün = DailyRewards.day_key() (FRI)", Missions.accepted_day() == DailyRewards.day_key()
		and Missions.accepted_day() == FRI)
	SaveManager.record_mission_round(1, false)
	var dough0: int = SaveManager.dough()
	DailyRewards.clock_override = WED
	_c("saat geri alındı (WED): DailyRewards ve görevler yine FRI", DailyRewards.day_key() == FRI
		and Missions.accepted_day() == FRI and SaveManager.missions_state()["day_key"] == FRI)
	var second: Dictionary = SaveManager.record_mission_round(1, false)
	_c("aynı (FRI) dönemde ikinci tur daily_rounds'u tamamlar (+10, meşru)", second["completed"] == [&"daily_rounds"]
		and SaveManager.dough() == dough0 + 10)
	var third: Dictionary = SaveManager.record_mission_round(1, false)
	_c("geri alınmış saatte yeni tur yeniden ödül VERMEZ; eski dönem (WED) geri gelmez",
		(third["completed"] as Array).is_empty() and SaveManager.dough() == dough0 + 10
		and SaveManager.missions_state()["day_key"] == FRI)
	# Görev günü "en yeni gün"ün ilerisinde (kesinleşme gece yarısını geçti, öne dönüş yok) + saat geri.
	var raw_daily: Dictionary = (SaveManager.data["daily_rewards"] as Dictionary).duplicate()
	raw_daily["last_seen_day_key"] = TUE
	SaveManager.data["daily_rewards"] = raw_daily
	_c("görev günü DailyRewards'ın en yeni gününün ilerisinde (kabul WED): dönem FRI kalır (asla geri gitmez)",
		DailyRewards.day_key() == WED and SaveManager.missions_state()["day_key"] == FRI
		and SaveManager.missions_state()["daily_rewarded"] == ["daily_rounds"])
	var floor_round: Dictionary = SaveManager.record_mission_round(3, false)
	_c("  … o durumda round FRI dönemine işlenir, tamamlanmış görev yeniden ödüllenmez",
		(floor_round["completed"] as Array).is_empty() and SaveManager.data["missions"]["day_key"] == FRI
		and SaveManager.dough() == dough0 + 10)
	raw_daily["last_seen_day_key"] = "bozuk"
	SaveManager.data["daily_rewards"] = raw_daily
	DailyRewards.clock_override = FRI
	_c("bozuk 'en yeni gün' → görev günü cihaz günü (FRI), dönem aynı", Missions.accepted_day() == FRI
		and SaveManager.missions_state()["day_key"] == FRI)
	raw_daily["last_seen_day_key"] = FRI
	SaveManager.data["daily_rewards"] = raw_daily
	# İleri gün: günlük yeni dönem → aynı görev yeniden ödül verebilir.
	DailyRewards.clock_override = SAT
	DailyRewards.observe_day()
	var sat: Dictionary = SaveManager.missions_state()
	_c("ileri gün (SAT): günlük sıfır + ödül işareti boş; haftalık aynen (tur 4)", _zero(sat, DAILY)
		and sat["weekly_progress"]["weekly_rounds"] == 4)
	var dough1: int = SaveManager.dough()
	SaveManager.record_mission_round(0, false)
	var again: Dictionary = SaveManager.record_mission_round(0, false)
	_c("yeni dönem ödülü: SAT'ta daily_rounds yeniden tamamlandı (+10)", again["completed"] == [&"daily_rounds"]
		and SaveManager.dough() == dough1 + 10)
	# Pazar → pazartesi: haftalık yeni dönem.
	DailyRewards.clock_override = SUN
	DailyRewards.observe_day()
	for i in 6:
		SaveManager.record_mission_round(0, false)
	var sun_state: Dictionary = SaveManager.missions_state()
	_c("ön koşul: pazar haftalık tur 12/12 tamamlandı (weekly_rounds ödüllü)", sun_state["weekly_rewarded"] == ["weekly_rounds"])
	DailyRewards.clock_override = NEXT_MON
	DailyRewards.observe_day()
	var mon_state: Dictionary = SaveManager.missions_state()
	_c("pazartesi: haftalık ilerleme + ödül işareti sıfır, hafta 10-05", _zero(mon_state, WEEKLY)
		and mon_state["week_start_day_key"] == NEXT_MON)
	var week_dough: int = SaveManager.dough()
	for i in 12:
		SaveManager.record_mission_round(0, false)
	_c("yeni hafta ödülü: weekly_rounds yeniden tamamlandı (+40, + günlük tur +10)",
		SaveManager.missions_state()["weekly_rewarded"] == ["weekly_rounds"] and SaveManager.dough() == week_dough + 50)
	# Yeni hafta kabul edildikten sonra saat önceki haftaya: hafta geri gitmez.
	raw_daily = (SaveManager.data["daily_rewards"] as Dictionary).duplicate()
	raw_daily["last_seen_day_key"] = ""
	SaveManager.data["daily_rewards"] = raw_daily
	DailyRewards.clock_override = FRI
	var dough2: int = SaveManager.dough()
	SaveManager.record_mission_round(0, false)
	_c("saat önceki haftada (FRI), en yeni gün boş: dönem 10-05 haftasında kalır, yeniden ödül yok",
		SaveManager.missions_state()["week_start_day_key"] == NEXT_MON and SaveManager.dough() == dough2
		and SaveManager.data["missions"]["day_key"] == NEXT_MON)
	# İleri alınan saat sınırlaması DailyRewards ile aynı (bilinçli kabul).
	DailyRewards.clock_override = "2027-06-01"
	DailyRewards.observe_day()
	DailyRewards.clock_override = NEXT_TUE
	_c("ileri alınan saat (2027-06-01) görülünce DailyRewards ve görevler aynı günde kalır (ortak kabul)",
		DailyRewards.day_key() == "2027-06-01" and Missions.accepted_day() == "2027-06-01"
		and SaveManager.missions_state()["day_key"] == "2027-06-01")
	# Bozuk saat: cihaz günü 2000 öncesi + "en yeni gün" bozuk → kabul edilen gün YOK. Yeni dönem
	# açılmaz; round kayıtlı döneme (10-05 haftası) işlenir, tamamlanmış görev yeniden ödüllenmez.
	raw_daily = (SaveManager.data["daily_rewards"] as Dictionary).duplicate()
	raw_daily["last_seen_day_key"] = "bozuk"
	SaveManager.data["daily_rewards"] = raw_daily
	DailyRewards.clock_override = "1999-12-31"
	var stored_day: String = String(SaveManager.data["missions"]["day_key"])
	var broken_dough: int = SaveManager.dough()
	var broken_merges: int = int(SaveManager.data["missions"]["daily_progress"]["daily_merges"])
	var broken: Dictionary = SaveManager.record_mission_round(2, false)
	_c("bozuk saat (1999 + bozuk en yeni gün): kabul edilen gün yok → yeni dönem açılmadı, round kayıtlı döneme işlendi, yeniden ödül yok",
		Missions.accepted_day() == "" and SaveManager.data["missions"]["day_key"] == stored_day and stored_day == NEXT_MON
		and int(SaveManager.data["missions"]["daily_progress"]["daily_merges"]) == broken_merges + 2
		and (broken["completed"] as Array).is_empty() and SaveManager.dough() == broken_dough)
	DailyRewards.clock_override = TUE
	_sections_done += 1


# --- 8) Gerçek Main: round kesinleştirme --------------------------------------------------------------

func _round_flow() -> void:
	print("-- round (gerçek Main, test yolu)")
	_clean()
	DailyRewards.clock_override = TUE
	_write(PATH, _fixture({}))
	SaveManager.load_game()
	await _boot()
	var level_2: LevelData = _level(2)

	# a) Sabit level kazanma: 12 merge, 3 yıldız.
	var dough0: int = SaveManager.dough()
	var xp0: int = SaveManager.player_xp()
	var title0: StringName = SaveManager.selected_title_id()
	await _finish_round(level_2, true, 12, level_2.star_3_threshold())
	var s: Dictionary = SaveManager.missions_state()
	_c("kazanma: merge 12/15 + 12/120, tur 1/2 + 1/12, level 1/1 (tamam) + 1/5",
		s["daily_progress"] == {"daily_merges": 12, "daily_rounds": 1, "daily_clear": 1}
		and s["weekly_progress"] == {"weekly_merges": 12, "weekly_rounds": 1, "weekly_clears": 1}
		and s["daily_rewarded"] == ["daily_clear"])
	_c("görev durumu round kaydında diskte (senkron kesinleşme)", Missions.sanitize(_disk().get("missions")) == SaveManager.data["missions"])
	await _wait_result()
	var summary: Dictionary = _main._result.progress_summary().get("missions", {})
	_c("sonuç özeti: tamamlanan [daily_clear], +10", summary.get("completed", []) == [&"daily_clear"]
		and int(summary.get("dough", -1)) == 10)
	_c("sonuç şeridi 'GÖREV TAMAMLANDI · +10 HAMUR'", _main._result.progress_strip().mission_text()
		== "GÖREV TAMAMLANDI · +10 HAMUR")
	_c("Hamur = başlangıç + görev 10 + sandık Hamur'u (otomatik, talep yok)", SaveManager.dough() == dough0 + 10 + _chest_dough())
	_c("görev XP VERMEZ: XP farkı yalnız round ödülü (12 + 20 + 3·10 = 62)", SaveManager.player_xp() - xp0 == 62
		and SaveManager.player_xp() - xp0 == PlayerProgression.round_xp_award(12, true, 0, 3))
	_c("görev unvan değiştirmez", SaveManager.selected_title_id() == title0)

	# b) Yinelenen kesinleştirme.
	var missions1: Dictionary = SaveManager.data["missions"].duplicate(true)
	var dough1: int = SaveManager.dough()
	var file1: PackedByteArray = _bytes(PATH)
	_main._on_round_finished(true)
	_main._on_round_finished(true)
	_main._board._finish(true)
	await _settle(1)
	_c("yinelenen kesinleştirme (2× _on_round_finished + 2. _finish): 0 ek ilerleme, 0 ek Hamur, disk aynı",
		SaveManager.data["missions"] == missions1 and SaveManager.dough() == dough1 and _bytes(PATH) == file1)
	await _leave()

	# c) Tekrar oynanış (kazanma) — level görevi yine sayılır.
	var dough2: int = SaveManager.dough()
	await _finish_round(level_2, true, 5, level_2.star_3_threshold())
	s = SaveManager.missions_state()
	_c("tekrar kazanma: haftalık level 2/5 (tekrar sayılır), günlük merge 17 → 15 tamam, tur 2/2 tamam",
		s["weekly_progress"]["weekly_clears"] == 2 and s["daily_progress"]["daily_merges"] == 15
		and s["daily_rewarded"] == ["daily_merges", "daily_rounds", "daily_clear"])
	await _wait_result()
	_c("iki günlük görev aynı round: '2 GÖREV TAMAMLANDI · +20 HAMUR'",
		_main._result.progress_strip().mission_text() == "2 GÖREV TAMAMLANDI · +20 HAMUR"
		and SaveManager.dough() == dough2 + 20 + _chest_dough())
	await _leave()

	# d) Kayıp: merge + tur sayılır, level sayılmaz.
	await _finish_round(level_2, false, 9, 10)
	s = SaveManager.missions_state()
	_c("kayıp: haftalık merge 26, tur 3; level görevi değişmedi (2/5)", s["weekly_progress"] == {"weekly_merges": 26,
		"weekly_rounds": 3, "weekly_clears": 2})
	await _wait_result()
	_c("kayıpta tamamlanan görev yok → görev rozeti yok", _main._result.progress_strip().mission_text() == "")
	await _leave()

	# e) Sonsuz: merge + tur, level ASLA (kazanma çağrısıyla bile).
	var endless: LevelData = LevelLibrary.load_endless()
	await _finish_round(endless, false, 30, 5000)
	s = SaveManager.missions_state()
	_c("sonsuz: haftalık merge 56, tur 4, level 2 (değişmedi)", s["weekly_progress"] == {"weekly_merges": 56,
		"weekly_rounds": 4, "weekly_clears": 2})
	await _leave()
	await _finish_round(endless, true, 0, 100)
	s = SaveManager.missions_state()
	_c("sonsuz round 'kazanma' ile bitse de level görevi ilerlemez (tur 5)", s["weekly_progress"]["weekly_clears"] == 2
		and s["weekly_progress"]["weekly_rounds"] == 5)
	await _leave()

	# f) Terk: Mola → Ana Menüye Dön.
	var before_abandon: Dictionary = SaveManager.data["missions"].duplicate(true)
	var disk_abandon: PackedByteArray = _bytes(PATH)
	_main._start_level(level_2)
	await _settle(2)
	for i in 8:
		GameState.register_merge(3, Vector2(360, 700))
	_c("bitmemiş round (8 merge, board canlı): görev durumu değişmedi", SaveManager.data["missions"] == before_abandon)
	_main.abandon_run()
	await _settle(2)
	_c("terk edilen round: 0 görev etkisi (bellek + disk)", SaveManager.data["missions"] == before_abandon
		and _bytes(PATH) == disk_abandon)

	# g) Yeniden başlatma (bitmeden): eski round sayılmaz, yeni round yalnız kendi merge'leriyle.
	_main._start_level(level_2)
	await _settle(2)
	for i in 6:
		GameState.register_merge(2, Vector2(360, 700))
	_main._on_pause_restart()
	await _settle(2)
	_c("bitmeden yeniden başlatma: 0 görev etkisi", SaveManager.data["missions"] == before_abandon)
	for i in 4:
		GameState.register_merge(2, Vector2(360, 700))
	_main._board._finish(false)
	await _settle(1)
	_c("yeniden başlatılan round bitince yalnız kendi 4 merge'i (56 → 60), tur 6",
		SaveManager.missions_state()["weekly_progress"]["weekly_merges"] == 60
		and SaveManager.missions_state()["weekly_progress"]["weekly_rounds"] == 6)
	await _leave()

	# h) Süreç ölümü (round ortası): diskte round izi yok.
	var before_kill: Dictionary = SaveManager.data["missions"].duplicate(true)
	var disk_kill: PackedByteArray = _bytes(PATH)
	_main._start_level(level_2)
	await _settle(2)
	for i in 7:
		GameState.register_merge(4, Vector2(360, 700))
	await _teardown_main()
	SaveManager.load_game()
	_c("round ortasında süreç öldü: disk aynı, yeniden açılışta görev durumu round öncesi", _bytes(PATH) == disk_kill
		and SaveManager.data["missions"] == before_kill)
	await _boot()

	# i) Eski board'un geç round_finished'i.
	_main._start_level(level_2)
	await _settle(2)
	var old_board: Node = _main._board
	_main._start_level(level_2)
	var stale_missions: Dictionary = SaveManager.data["missions"].duplicate(true)
	var stale_disk: PackedByteArray = _bytes(PATH)
	old_board.round_finished.emit(true)
	_c("eski board'un geç round_finished'i: 0 görev etkisi, disk aynı, yeni round kesinleşmedi",
		SaveManager.data["missions"] == stale_missions and _bytes(PATH) == stale_disk and not _main._round_finalized)
	await _leave()

	# j) Tek yazma: görev + Hamur round kaydına katlanır.
	var one_disk: PackedByteArray = _bytes(PATH)
	var one_dough: int = SaveManager.dough()
	SaveManager.data["missions"] = Missions.sanitize(_raw(TUE, {}, ["daily_merges", "daily_rounds", "daily_clear"],
		{"weekly_rounds": 11}, []))
	SaveManager.record_mission_round(0, false, false)
	_c("save=false: görev ilerlemesi + Hamur yalnız bellekte, disk DOKUNULMADI", _bytes(PATH) == one_disk
		and SaveManager.dough() == one_dough + 40 and SaveManager.data["missions"]["weekly_rewarded"] == ["weekly_rounds"])
	SaveManager.record_round_finished(0, 0)
	var one: Dictionary = _disk()
	_c("round kaydı görev durumunu + görev Hamur'unu TEK yazmada indirdi", int(one.get("dough", -1)) == one_dough + 40
		and Missions.sanitize(one.get("missions")) == SaveManager.data["missions"])

	# k) Çoklu tamamlama + otomatik toplam (gerçek Main).
	SaveManager.data["missions"] = Missions.sanitize(_raw(TUE, {"daily_merges": 14}, [], {"weekly_merges": 119}, []))
	SaveManager.save_game()
	var multi_dough: int = SaveManager.dough()
	await _finish_round(level_2, false, 1, 10)
	await _wait_result()
	summary = _main._result.progress_summary().get("missions", {})
	_c("günlük + haftalık aynı round: [daily_merges, weekly_merges], +50", summary.get("completed", []) == [&"daily_merges",
		&"weekly_merges"] and int(summary.get("dough", -1)) == 50)
	_c("sonuç şeridi '2 GÖREV TAMAMLANDI · +50 HAMUR'; Hamur = +50 + teselli 5",
		_main._result.progress_strip().mission_text() == "2 GÖREV TAMAMLANDI · +50 HAMUR"
		and SaveManager.dough() == multi_dough + 50 + _chest_dough() and _chest_dough() == ChestSystem.CONSOLATION_DOUGH)
	await _leave()
	SaveManager.data["missions"] = Missions.sanitize(_raw(TUE, {"daily_merges": 14, "daily_rounds": 1}, [],
		{"weekly_merges": 119}, []))
	SaveManager.save_game()
	await _finish_round(level_2, false, 2, 10)
	await _wait_result()
	_c("üç görev (2 günlük + 1 haftalık): '3 GÖREV TAMAMLANDI · +60 HAMUR'",
		_main._result.progress_strip().mission_text() == "3 GÖREV TAMAMLANDI · +60 HAMUR")
	await _leave()

	# l) Yeni gün: aynı görev yeniden ödül verir.
	DailyRewards.clock_override = WED
	var wed_dough: int = SaveManager.dough()
	await _finish_round(level_2, true, 0, level_2.star_3_threshold())
	s = SaveManager.missions_state()
	_c("yeni gün (WED): günlük dönem sıfırdan, level görevi yeniden tamamlandı (+10)", s["day_key"] == WED
		and s["daily_rewarded"] == ["daily_clear"] and s["daily_progress"]["daily_merges"] == 0)
	await _wait_result()
	_c("  … Hamur +10 + sandık", SaveManager.dough() == wed_dough + 10 + _chest_dough())
	await _leave()

	# m) Görev ödülü XP / başarım / unvan / yıldız / sayaç / sandık DEĞİŞTİRMEZ.
	SaveManager.data["missions"] = Missions.sanitize(_raw(WED, {"daily_merges": 14, "daily_rounds": 1}, ["daily_clear"],
		{"weekly_merges": 119, "weekly_rounds": 11, "weekly_clears": 4}, []))
	var snapshot: Dictionary = {"xp": SaveManager.player_xp(), "ach": SaveManager.unlocked_achievements(),
		"title": SaveManager.selected_title_id(), "stars": SaveManager.data["level_stars"].duplicate(),
		"rounds": SaveManager.total_rounds_played(), "merges": SaveManager.total_merges(),
		"skins": SaveManager.owned_skins().duplicate(), "powers": SaveManager.data["powerups"].duplicate(),
		"level": SaveManager.highest_level_unlocked(), "streak": SaveManager.daily_streak(),
		"login": SaveManager.last_login_date()}
	var big_dough: int = SaveManager.dough()
	var big: Dictionary = SaveManager.record_mission_round(1, true)
	_c("beş görev tek kayıtta: +10 +10 +40 +40 +40 = +140 Hamur", (big["completed"] as Array).size() == 5
		and int(big["dough"]) == 140 and SaveManager.dough() == big_dough + 140)
	var after: Dictionary = {"xp": SaveManager.player_xp(), "ach": SaveManager.unlocked_achievements(),
		"title": SaveManager.selected_title_id(), "stars": SaveManager.data["level_stars"].duplicate(),
		"rounds": SaveManager.total_rounds_played(), "merges": SaveManager.total_merges(),
		"skins": SaveManager.owned_skins().duplicate(), "powers": SaveManager.data["powerups"].duplicate(),
		"level": SaveManager.highest_level_unlocked(), "streak": SaveManager.daily_streak(),
		"login": SaveManager.last_login_date()}
	_c("görev ödülü: XP / başarım / unvan / yıldız / tur / merge / parça / güç / level / giriş serisi AYNEN", after == snapshot)
	await _teardown_main()
	_sections_done += 1


# --- 9) Tutorial ------------------------------------------------------------------------------------

func _tutorial_round() -> void:
	print("-- tutorial: tamamlanma 0 görev; gerçek Level 1 round'u normal kurallarla")
	_clean()
	DailyRewards.clock_override = TUE
	SaveManager.load_game()
	var dough0: int = SaveManager.dough()
	await _boot()
	_c("ön koşul: yeni oyuncu, tutorial açık (gerçek Level 1 board'u)", _main.is_tutorial_active() and _main._board != null)
	_main.open_missions()
	await _settle(1)
	_c("tutorial koçluğu sırasında GÖREVLER penceresi açılmaz", not _main._missions.visible)
	var fresh: Dictionary = SaveManager.missions_state()
	_main._on_tutorial_completed(Onboarding.SOURCE_TUTORIAL)
	await _settle(1)
	_c("tutorial tamamlanması: 0 görev ilerlemesi, 0 Hamur", SaveManager.onboarding_completed()
		and SaveManager.missions_state() == fresh and Missions.completed_count(SaveManager.missions_state()) == 0
		and SaveManager.dough() == dough0)
	for i in 3:
		GameState.register_merge(2 + i, Vector2(360, 700))
	_main._board._finish(true)
	await _settle(1)
	var s: Dictionary = SaveManager.missions_state()
	_c("öğretim round'u (gerçek Level 1) kazanıldı: merge 3, tur 1, level görevi tamam", s["daily_progress"] == {
		"daily_merges": 3, "daily_rounds": 1, "daily_clear": 1} and s["daily_rewarded"] == ["daily_clear"]
		and s["weekly_progress"]["weekly_clears"] == 1)
	await _wait_result()
	_c("sonuç ekranında görev rozeti (tutorial yüzeyinde değil)", _main._result.progress_strip().mission_text()
		== "GÖREV TAMAMLANDI · +10 HAMUR" and not _main.is_tutorial_active())
	_main._result.hide_result()
	_main._on_exit_pressed()
	await _settle(2)
	_main._show_tab(0)
	await _settle(2)
	_c("normal Ana Sayfa'ya dönünce GÖREVLER girişi round'u yansıtır (1/6)", _main._screens[0].missions_count_text() == "1/6")
	await _teardown_main()
	_sections_done += 1


# --- 10) Reklam + kaynak sözleşmesi -----------------------------------------------------------------

func _ads_and_sources() -> void:
	print("-- reklam yok (sahte arka uç) + kaynak sözleşmesi")
	_clean()
	DailyRewards.clock_override = TUE
	_write(PATH, _fixture({}))
	SaveManager.load_game()
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	await _boot(fake)
	fake.complete_consent_update(true)
	fake.complete_init()
	await _settle(2)
	var ads: MonetizationManager = _main._ads
	if fake.banner_loads > 0:
		fake.complete_banner_load(true)
	await _settle(2)
	_c("ön koşul: reklam yöneticisi hazır, Ana Sayfa'da banner", ads != null and ads.banner_state() == MonetizationManager.BannerState.SHOWN)
	var calls: int = fake.calls.size()
	var shows: int = fake.banner_shows.size()
	_main._screens[0].missions_button().pressed.emit()
	await _settle(2)
	_c("GÖREVLER penceresi açıldı: yüzey HOME aynen, arka uca çağrı yok, yeni banner gösterimi yok",
		_main._missions.visible and ads.surface() == MonetizationManager.Surface.HOME and fake.calls.size() == calls
		and fake.banner_shows.size() == shows)
	_main._missions.close_missions()
	await _settle(2)
	_c("pencere kapandı: arka uca çağrı yok", fake.calls.size() == calls)
	var level_2: LevelData = _level(2)
	_main._start_level(level_2)
	await _settle(2)
	for i in 3:
		GameState.register_merge(3, Vector2(360, 700))
	GameState.add_score(level_2.star_3_threshold())
	var before_finish: int = fake.calls.size()
	var rewarded_shows: int = fake.rewarded_shows.size()
	var interstitial_shows: int = fake.interstitial_shows.size()
	AdEvents.clear_recent()
	_main._board._finish(true)
	_c("görev tamamlayan kesinleşme (level görevi +10) sırasında reklam arka ucuna ÇAĞRI YOK, reklam olayı YOK",
		SaveManager.missions_state()["daily_rewarded"] == ["daily_clear"] and fake.calls.size() == before_finish
		and AdEvents.recent().is_empty())
	await _wait_result()
	_c("sonuç sonrası ödüllü talep / gösterim ya da geçiş gösterimi yok (görev reklam tetiklemez)",
		fake.rewarded_shows.size() == rewarded_shows and fake.interstitial_shows.size() == interstitial_shows
		and AdEvents.count(&"rewarded_requested") == 0 and AdEvents.count(&"rewarded_showed") == 0
		and AdEvents.count(&"interstitial_showed") == 0
		and _main._result.progress_strip().mission_text() == "GÖREV TAMAMLANDI · +10 HAMUR")
	_c("görev bildirimli sonuç ekranı: yüzey RESULT, banner gizli, yeni banner gösterimi yok",
		ads.surface() == MonetizationManager.Surface.RESULT and ads.banner_state() != MonetizationManager.BannerState.SHOWN
		and fake.banner_shows.size() == shows)
	await _leave()
	await _teardown_main()
	UiKit.set_banner_slot(0.0)

	# Kaynak sözleşmesi.
	var ad_tokens: Array[String] = ["MonetizationManager", "AdEvents", "AdBackend", "_ads", "show_rewarded",
		"try_show_interstitial", "_rewarded_provider", "set_surface", "AgeGate", "consent", "age_ad_band",
		"agesignals", "age_signals"]
	var mission_files: Array[String] = ["res://scripts/game/missions.gd", "res://scripts/ui/mission_card.gd",
		"res://scripts/ui/missions_overlay.gd"]
	var hits: Array[String] = []
	for path in mission_files:
		var code: String = _strip_comments(FileAccess.get_file_as_string(path))
		for token in ad_tokens:
			if code.contains(token):
				hits.append("%s: %s" % [path.get_file(), token])
	var save_src: String = FileAccess.get_file_as_string("res://scripts/autoload/save_manager.gd")
	var record_fn: String = _function(save_src, "func record_mission_round(")
	var state_fn: String = _function(save_src, "func missions_state(")
	var migrate_fn: String = _function(save_src, "func _migrate_missions(")
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var open_fn: String = _function(main_src, "func open_missions(")
	var home_src: String = FileAccess.get_file_as_string("res://scripts/ui/home_screen.gd")
	var home_fns: String = _function(home_src, "func _build_missions_entry(") + _function(home_src, "func refresh_missions(")
	for pair: Array in [["record_mission_round", record_fn], ["missions_state", state_fn], ["_migrate_missions", migrate_fn],
			["Main.open_missions", open_fn], ["Home görev girişi", home_fns]]:
		for token in ad_tokens:
			if _strip_comments(String(pair[1])).contains(token):
				hits.append("%s: %s" % [pair[0], token])
	_c("görev kodu reklam / yaş / rıza / Age Signals'a DOKUNMAZ %s" % str(hits), hits.is_empty()
		and not record_fn.is_empty() and not open_fn.is_empty() and not home_fns.is_empty())
	var record_code: String = _strip_comments(record_fn)
	var forbidden: Array[String] = []
	for token in ["player_xp", "unlocked_achievements", "selected_title_id", "_unlock_satisfied_achievements",
			"player_meta_changed", "ChestSystem", "grant_skin", "grant_powerup", "level_stars", "total_rounds_played",
			"daily_streak", "last_login_date"]:
		if record_code.contains(token):
			forbidden.append(token)
	_c("record_mission_round yalnız görev durumu + Hamur yazar (XP / başarım / unvan / sandık / güç / seri yok) %s" % str(forbidden),
		forbidden.is_empty() and record_code.contains("data[\"missions\"]") and record_code.contains("data[\"dough\"]"))
	var missions_code: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/game/missions.gd"))
	_c("Missions saf: kayda yazmaz (save_game / data[ yok), seri / çarpan yok, giriş ödülüne dokunmaz",
		not missions_code.contains("save_game(") and not missions_code.contains("SaveManager.data")
		and not missions_code.to_lower().contains("streak") and not missions_code.contains("DailyReward.")
		and not missions_code.contains("multiplier"))
	var main_code: String = _strip_comments(main_src)
	var finish_fn: String = _strip_comments(_function(main_src, "func _on_round_finished("))
	var guard_at: int = finish_fn.find("_round_finalized = true")
	var call_at: int = finish_fn.find("SaveManager.record_mission_round(merges, fixed_cleared, false)")
	var round_at: int = finish_fn.find("SaveManager.record_round_finished(")
	_c("Main: record_mission_round TEK çağrı, round kesinleşmesinde, koruma sonrası ve round kaydından ÖNCE (save=false)",
		main_code.count("record_mission_round(") == 1 and guard_at >= 0 and call_at > guard_at and round_at > call_at)
	_c("terk / yeniden başlatma yolları görev çağırmaz", not _strip_comments(_function(main_src, "func abandon_run(")).contains("mission")
		and not _strip_comments(_function(main_src, "func _on_pause_restart(")).contains("mission")
		and not _strip_comments(_function(main_src, "func _clear_board(")).contains("record_mission"))
	_sections_done += 1


# --- Yardımcılar -----------------------------------------------------------------------------------

## Ham görev durumu (kayıt biçimi). Hafta günün pazartesisi.
func _raw(day: String, daily: Dictionary, daily_rewarded: Array, weekly: Dictionary, weekly_rewarded: Array,
		version: int = 1) -> Dictionary:
	return {"version": version, "day_key": day, "week_start_day_key": Missions.week_start(day),
		"daily_progress": daily.duplicate(), "daily_rewarded": daily_rewarded.duplicate(),
		"weekly_progress": weekly.duplicate(), "weekly_rewarded": weekly_rewarded.duplicate()}


func _zero(state: Dictionary, period: StringName) -> bool:
	var progress: Dictionary = state.get(Missions.progress_key(period), {})
	for id in Missions.ids_for(period):
		if int(progress.get(String(id), -1)) != 0:
			return false
	return (state.get(Missions.rewarded_key(period), [0]) as Array).is_empty()


## TASK/046 öncesi eski kayıt (görev anahtarı yok, oynanmışlık kanıtı var).
func _legacy(extra: Dictionary) -> Dictionary:
	var out: Dictionary = {"highest_level_unlocked": 4, "level_stars": {"1": 2, "2": 2, "3": 2},
		"endless_high_score": 0, "dough": 335, "total_merges": 812, "merges_since_bonus_chest": 62,
		"unlocked_skins": ["common_01"], "powerups": {"bomb": 2, "upgrade": 1, "shake": 0, "clear_small": 1},
		"powerup_starter_granted": true, "onboarding_completed": true, "age_ad_band": "ADULT",
		"player_meta_version": 1, "player_xp": 932, "total_rounds_played": 40, "highest_tier_created": 6,
		"last_login_date": Time.get_date_string_from_system()}
	for key in extra:
		out[key] = extra[key]
	return out


## Round testleri için yerleşik oyuncu: onboarding tamam, bugünün giriş ödülü alınmış (gerçek
## sistem günü — `DailyReward.claim_if_new_day` saat kancasını kullanmaz), yaş ADULT.
func _fixture(extra: Dictionary) -> Dictionary:
	var out: Dictionary = {"highest_level_unlocked": 11, "level_stars": {}, "endless_high_score": 0, "dough": 500,
		"total_merges": 0, "merges_since_bonus_chest": 0, "unlocked_skins": [],
		"powerups": {"bomb": 1, "upgrade": 1, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "", "daily_streak": 3,
		"last_login_date": Time.get_date_string_from_system(), "age_ad_band": "ADULT", "next_age_transition_date": "",
		"player_meta_version": 1, "player_xp": 0, "total_rounds_played": 0, "highest_tier_created": 0}
	for key in extra:
		out[key] = extra[key]
	return out


func _boot(fake: FakeAdBackend = null) -> void:
	await _teardown_main()
	_main_script.set("ads_backend_override", fake)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _settle(3)
	_main_script.set("ads_backend_override", null)


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _settle(2)


## Round kur, gerçek merge kayıtları, skor, bitir (senkron kesinleşme bir karede).
func _finish_round(level: LevelData, won: bool, merges: int, score: int) -> void:
	_main._start_level(level)
	await _settle(2)
	for i in merges:
		GameState.register_merge(2 + (i % 3), Vector2(360, 700))
	GameState.add_score(score)
	_main._board._finish(won)
	await _settle(1)


func _wait_result() -> void:
	await get_tree().create_timer(_main.RESULT_DELAY + 0.3).timeout
	await _settle(2)


func _leave() -> void:
	_main._result.hide_result()
	_main.abandon_run()
	await _settle(1)


## Açık sonuç ekranındaki sandık / teselli Hamur'u (kura rastgele — toplam kanonikle kıyaslanır).
func _chest_dough() -> int:
	var total: int = 0
	for reward: ChestReward in _main._result._rewards:
		if not reward.is_skin_reward():
			total += reward.dough
	return total


func _level(number: int) -> LevelData:
	for level in LevelLibrary.load_levels():
		if level.level_number == number:
			return level
	return null


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _write(path: String, content: Dictionary) -> void:
	_put(path, JSON.stringify(content, "\t").to_utf8_buffer())


func _put(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


func _exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func _disk() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if parsed is Dictionary else {}


func _clean() -> void:
	for path in [PATH, TMP, BAK]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for path in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out


## `header` ile başlayan fonksiyonun gövdesi (bir sonraki üst düzey `func` / `static func`'a kadar).
func _function(src: String, header: String) -> String:
	var start: int = src.find(header)
	if start < 0:
		return ""
	var rest: String = src.substr(start + header.length())
	var ends: Array[int] = []
	for marker in ["\nfunc ", "\nstatic func ", "\n# ---"]:
		var at: int = rest.find(marker)
		if at >= 0:
			ends.append(at)
	var end: int = rest.length()
	for at in ends:
		end = mini(end, at)
	return header + rest.substr(0, end)


## Yorum satırları / satır sonu yorumları çıkarılır (yalnız kod taranır).
func _strip_comments(src: String) -> String:
	var out: PackedStringArray = []
	for line in src.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		var cut: int = line.find(" # ")
		out.append(line.substr(0, cut) if cut >= 0 else line)
	return "\n".join(out)
