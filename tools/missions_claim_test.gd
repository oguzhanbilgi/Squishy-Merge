extends Node
## TASK/061 — Günlük & Görevler V3: elle talep (ÖDÜLÜ AL) + dönem sonu teslimi + sürüm 1 → 2 göçü. Headless.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_missions_claim/` altındaki bir yola
## yönlendirilir (TASK/045.1 test dikişi) ve sonda geri alınır; gerçek kayıt ailesinin (kanonik + .tmp + .bak) baytları
## başta / sonda karşılaştırılır. Saat yalnız `DailyRewards.clock_override` ile (sonda boş), hata enjeksiyonu her
## bölümde temizlenir.
##
##   godot --headless --audio-driver Dummy --path . res://tools/missions_claim_test.tscn
##
## Bölümler:
##   1 model        Missions.claim (CLAIMED / ALREADY / NOT_COMPLETE / WRONG_PERIOD / UNKNOWN / NO_PERIOD, miktar katalogdan,
##                  ilerleme değişmez, girdi değişmez) · Missions.rollover matrisi (aynı gün, yeni gün, pazar → pazartesi,
##                  hafta atlama, ay / yıl sonu, artık yıl, geri / bozuk saat, idempotent, alınmış / eksik görev teslim
##                  edilmez, birden çok gün atlanınca tek teslim)
##   2 göç          sürüm 1 → 2 (ödenmiş = ALINDI, kısmi = AKTİF, sürüm 1 alınabilir ÜRETEMEZ) · bozuk veri fail-closed
##                  (bilinmeyen / çift / öteki dönem id, negatif, hedeften büyük, float, NaN, ±sonsuz, metin, bozuk gün /
##                  hafta, eksik blok, bilinmeyen sürüm — hiçbiri alınabilir görev EKLEMEZ) · diskten yükleme yazmaz, öteki
##                  kayıt alanları (Hamur, güç, level, yıldız, koleksiyon, XP, başarım) aynen · .tmp / .bak kurtarması
##   3 dönem işlemi SaveManager.settle_missions: normal gün yazmaz, teslimsiz yeni gün yazmaz, teslim TEK yazma (dönem +
##                  Hamur), ikinci çağrı no-op, yeniden açılış çift teslim etmez, çökme / yazma hatası matrisi (8 hata) →
##                  her durumda tam bir kez
##   4 talep        SaveManager.claim_mission_reward: geçerli / ikinci / eksik / bilinmeyen / yanlış dönem, art arda iki
##                  talep, gece yarısını açık geçen pencere (AUTO_CLAIMED), pazartesi, yazma hatası + yeniden açılış, kalıcılık,
##                  bozuk saat, yan etki yok (XP / başarım / güç / kota / günlük ödüller / meydan okuma)
##   5 gerçek Main  açılışta teslim, Ana Sayfa N/6 + dikkat sayısı, pencere başlığı, kart durumları, CTA dokunma alanı
##                  (≥ 84 = 48 dp), gerçek parmakla talep, çift dokunuş, iki CTA art arda, ACTION_CANCEL, dışarı sürükleme,
##                  CTA'dan başlayan kaydırma, uzun basış, basılıyken GERİ / ekran değişimi, kapanışta geç dokunuş, yeniden
##                  açılış + yeniden başlatma, pencere üst üste binmez, gece yarısı açık pencere, öne dönüş, sekme geçişi,
##                  round sırasında teslim yok (round kaydında), otomatik günlük pencere "due" kalır
##   6 ekonomi      bir haftalık oyun: elle + dönem sonu teslimi karışık → günde ≤ 30, haftalık ≤ 120, toplam tam 330;
##                  çift yol yok; görev ödülü XP / başarım / güç / sandık / kota vermez; kaynak sözleşmesi (reklam yok)

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_missions_claim"
const PATH: String = DIR + "/save.json"
const TMP: String = PATH + SaveFile.TEMP_SUFFIX
const BAK: String = PATH + SaveFile.BACKUP_SUFFIX
const SECTIONS: int = 6
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
const BASE_DOUGH: int = 500

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
	_c("başlangıç: SaveManager gerçek kayıt yolunda, hata enjeksiyonu kapalı, saat kancası boş",
		SaveManager.save_path == SaveManager.SAVE_PATH and SaveFile.fault == SaveFile.Fault.NONE
		and DailyRewards.clock_override == "")
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	SaveManager.save_path = PATH
	get_tree().create_timer(400.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 400 s'de bitmedi — SaveManager geri alındı")
			if _main != null and is_instance_valid(_main):
				_main.free()
			_teardown()
			get_tree().quit(2))

	_model()
	_migration()
	_settle_transactions()
	_claim_transactions()
	await _main_flows()
	_economy()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	print("-- kayıt")
	await _teardown_main()
	_teardown()
	_c("SaveManager gerçek yola döndü, test klasörü silindi, saat kancası / hata enjeksiyonu boş",
		SaveManager.save_path == SaveManager.SAVE_PATH and not DirAccess.dir_exists_absolute(DIR)
		and DailyRewards.clock_override == "" and SaveFile.fault == SaveFile.Fault.NONE
		and not DailyRewards.auto_popup_enabled)
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
	DailyRewards.auto_popup_enabled = false
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- 1) Model (saf) -----------------------------------------------------------------------------

func _model() -> void:
	print("-- model: Missions.claim + Missions.rollover (saf)")
	var fresh: Dictionary = Missions.fresh_state(TUE)
	_c("taze dönemde ÖDÜLÜ AL: NOT_COMPLETE, Hamur 0", int(Missions.claim(fresh, &"daily_merges", TUE)["result"])
		== Missions.Claim.NOT_COMPLETE and int(Missions.claim(fresh, &"daily_merges", TUE)["dough"]) == 0)
	var ready: Dictionary = _v2(TUE, {"daily_merges": 15, "daily_rounds": 1}, [], {"weekly_rounds": 12}, [])
	var copy: Dictionary = ready.duplicate(true)
	_c("ön koşul: daily_merges + weekly_rounds alınabilir; durumlar AKTİF / ALINABİLİR doğru",
		Missions.claimable_ids(ready) == [&"daily_merges", &"weekly_rounds"]
		and Missions.status_of(ready, &"daily_merges") == Missions.STATUS_CLAIMABLE
		and Missions.status_of(ready, &"daily_rounds") == Missions.STATUS_ACTIVE)
	var first: Dictionary = Missions.claim(ready, &"daily_merges", TUE)
	var claimed: Dictionary = first["state"]
	_c("geçerli talep: CLAIMED, katalog ödülü +10, ödül işareti [daily_merges], ilerleme 15 aynen",
		int(first["result"]) == Missions.Claim.CLAIMED and int(first["dough"]) == 10
		and claimed["daily_rewarded"] == ["daily_merges"] and claimed["daily_progress"] == ready["daily_progress"]
		and claimed["weekly_progress"] == ready["weekly_progress"] and claimed["weekly_rewarded"] == ready["weekly_rewarded"])
	_c("talep girdiyi değiştirmez; durum ALINDI, tamamlandı sayılır", ready == copy
		and Missions.status_of(claimed, &"daily_merges") == Missions.STATUS_CLAIMED and Missions.is_completed(claimed, &"daily_merges"))
	var again: Dictionary = Missions.claim(claimed, &"daily_merges", TUE)
	_c("ikinci talep: ALREADY_CLAIMED, Hamur 0, durum aynen", int(again["result"]) == Missions.Claim.ALREADY_CLAIMED
		and int(again["dough"]) == 0 and again["state"] == claimed)
	_c("yanlış dönem anahtarı (dün / haftalıkta gün / boş) → WRONG_PERIOD",
		int(Missions.claim(ready, &"daily_merges", MON)["result"]) == Missions.Claim.WRONG_PERIOD
		and int(Missions.claim(ready, &"weekly_rounds", TUE)["result"]) == Missions.Claim.WRONG_PERIOD
		and int(Missions.claim(ready, &"daily_merges", "")["result"]) == Missions.Claim.WRONG_PERIOD)
	var weekly: Dictionary = Missions.claim(ready, &"weekly_rounds", MON)
	_c("haftalık görev pazartesi anahtarıyla: CLAIMED +40 (katalogdan)", int(weekly["result"]) == Missions.Claim.CLAIMED
		and int(weekly["dough"]) == 40 and weekly["state"]["weekly_rewarded"] == ["weekly_rounds"])
	_c("bilinmeyen id → UNKNOWN; dönem yok → NO_PERIOD", int(Missions.claim(ready, &"daily_bogus", TUE)["result"])
		== Missions.Claim.UNKNOWN and int(Missions.claim({}, &"daily_merges", TUE)["result"]) == Missions.Claim.NO_PERIOD)
	var all_ready: Dictionary = _v2(TUE, {"daily_merges": 15, "daily_rounds": 2, "daily_clear": 1}, [],
		{"weekly_merges": 120, "weekly_rounds": 12, "weekly_clears": 5}, [])
	var total: int = 0
	var walk: Dictionary = all_ready
	for id in Missions.ids():
		var r: Dictionary = Missions.claim(walk, id, Missions.period_key_of(walk, Missions.find(id)["period"]))
		total += int(r["dough"])
		walk = r["state"]
	_c("altı talep: toplam 3·10 + 3·40 = 150, 6/6 tamam, 0 alınabilir", total == 150
		and Missions.completed_count(walk) == 6 and Missions.claimable_count(walk) == 0)
	var row: Dictionary = Missions.rows(claimed)[0]
	_c("ekran satırı: completed / claimed / claimable / status / period_key", bool(row["completed"]) and bool(row["claimed"])
		and not bool(row["claimable"]) and row["status"] == Missions.STATUS_CLAIMED and row["period_key"] == TUE
		and Missions.rows(claimed)[3]["period_key"] == MON)

	# Dönem geçişi.
	var tue: Dictionary = _v2(TUE, {"daily_merges": 15, "daily_rounds": 2, "daily_clear": 0}, ["daily_rounds"],
		{"weekly_merges": 120, "weekly_rounds": 7}, [])
	var tue_copy: Dictionary = tue.duplicate(true)
	var same: Dictionary = Missions.rollover(tue, TUE)
	_c("aynı gün: dönem aynen, geçiş yok, teslim yok", not bool(same["rolled"]) and (same["auto_claimed"] as Array).is_empty()
		and int(same["dough"]) == 0 and same["state"] == Missions.sanitize(tue))
	var wed: Dictionary = Missions.rollover(tue, WED)
	_c("yeni gün (aynı hafta): kapanan günlük dönemin alınmamış tamamlanmışı teslim [daily_merges] +10 — alınmış (daily_rounds) ve eksik (daily_clear) teslim edilmez",
		bool(wed["rolled"]) and wed["auto_claimed"] == [&"daily_merges"] and int(wed["dough"]) == 10
		and wed["closed"] == {DAILY: TUE})
	_c("  … yeni gün taze; haftalık aynen (weekly_merges 120 ALINABİLİR kalır — hafta kapanmadı, teslim YOK)",
		_zero(wed["state"], DAILY) and wed["state"]["day_key"] == WED
		and Missions.is_claimable(wed["state"], &"weekly_merges") and wed["state"]["weekly_progress"]["weekly_rounds"] == 7)
	_c("rollover girdiyi değiştirmez", tue == tue_copy)
	var twice: Dictionary = Missions.rollover(wed["state"], WED)
	_c("idempotent: geçmiş durumu aynı günde yeniden işlemek teslim üretmez", not bool(twice["rolled"])
		and (twice["auto_claimed"] as Array).is_empty() and twice["state"] == wed["state"])
	var skip: Dictionary = Missions.rollover(tue, SAT)
	_c("birden çok gün atlandı (TUE → SAT): tek teslim (+10), dönem SAT", skip["auto_claimed"] == [&"daily_merges"]
		and int(skip["dough"]) == 10 and skip["state"]["day_key"] == SAT)
	var sun: Dictionary = _v2(SUN, {"daily_clear": 1}, [], {"weekly_merges": 120, "weekly_rounds": 12, "weekly_clears": 4},
		["weekly_rounds"])
	var mon: Dictionary = Missions.rollover(sun, NEXT_MON)
	_c("pazar → pazartesi: günlük + haftalık kapanır — daily_clear +10 + weekly_merges +40 = +50 (alınmış weekly_rounds, eksik weekly_clears yok)",
		mon["auto_claimed"] == [&"daily_clear", &"weekly_merges"] and int(mon["dough"]) == 50
		and mon["closed"] == {DAILY: SUN, WEEKLY: MON} and _zero(mon["state"], DAILY) and _zero(mon["state"], WEEKLY)
		and mon["state"]["week_start_day_key"] == NEXT_MON)
	var jump: Dictionary = Missions.rollover(tue, NEXT_TUE)
	_c("hafta atlayan gün (TUE → sonraki TUE): iki dönem de kapanır (+10 + 40)", jump["auto_claimed"] == [&"daily_merges",
		&"weekly_merges"] and int(jump["dough"]) == 50)
	var month: Dictionary = Missions.rollover(_v2(WED, {"daily_clear": 1}, [], {"weekly_clears": 5}, []), THU)
	_c("ay sonu (30 Eyl → 01 Eki, aynı hafta): yalnız günlük teslim (+10), haftalık alınabilir kalır",
		month["auto_claimed"] == [&"daily_clear"] and Missions.is_claimable(month["state"], &"weekly_clears"))
	var year: Dictionary = Missions.rollover(_v2("2026-12-31", {"daily_rounds": 2}, [], {"weekly_rounds": 12}, []),
		"2027-01-01")
	var new_week: Dictionary = Missions.rollover(year["state"], "2027-01-04")
	_c("yıl sonu: 31 Ara → 01 Oca aynı hafta (yalnız günlük +10); 04 Oca pazartesi haftalık +40",
		year["auto_claimed"] == [&"daily_rounds"] and Missions.is_claimable(year["state"], &"weekly_rounds")
		and new_week["auto_claimed"] == [&"weekly_rounds"] and int(new_week["dough"]) == 40)
	var leap: Dictionary = Missions.rollover(_v2("2028-02-28", {"daily_merges": 15}, [], {}, []), "2028-02-29")
	var leap2: Dictionary = Missions.rollover(_v2("2028-02-29", {"daily_clear": 1}, [], {}, []), "2028-03-01")
	_c("artık yıl: 28 Şub → 29 Şub ve 29 Şub → 01 Mar birer teslim", leap["auto_claimed"] == [&"daily_merges"]
		and leap["state"]["day_key"] == "2028-02-29" and leap2["auto_claimed"] == [&"daily_clear"])
	var back: Dictionary = Missions.rollover(_v2(FRI, {"daily_merges": 15}, [], {}, []), WED)
	_c("saat geri (kayıt FRI, gün WED): geçiş yok, teslim yok, alınabilir görev kalır", not bool(back["rolled"])
		and (back["auto_claimed"] as Array).is_empty() and Missions.is_claimable(back["state"], &"daily_merges"))
	var broken: Dictionary = Missions.rollover(tue, "")
	_c("bozuk saat (kabul edilen gün yok): kayıtlı dönem aynen, teslim yok", not bool(broken["rolled"])
		and broken["state"] == Missions.sanitize(tue))
	_c("kayıt yok: kabul edilen günün taze dönemi, teslim yok; ikisi de yok → boş",
		Missions.rollover(null, WED)["state"] == Missions.fresh_state(WED) and (Missions.rollover(null, WED)["auto_claimed"]
		as Array).is_empty() and (Missions.rollover(null, "")["state"] as Dictionary).is_empty())
	var legacy_paid: Dictionary = {"version": 1, "day_key": MON, "week_start_day_key": MON,
		"daily_progress": {"daily_merges": 15}, "daily_rewarded": ["daily_merges", "daily_rounds"],
		"weekly_progress": {"weekly_rounds": 12}, "weekly_rewarded": ["weekly_rounds"]}
	_c("sürüm 1 eski dönem (ödenmiş görevler) geçişte HİÇBİR şey teslim etmez", (Missions.rollover(legacy_paid, TUE)["auto_claimed"]
		as Array).is_empty() and (Missions.rollover(legacy_paid, NEXT_MON)["auto_claimed"] as Array).is_empty())
	var tampered: Dictionary = _v2(TUE, {"daily_merges": 16, "daily_rounds": 1e300, "daily_clear": -1}, [], {}, [])
	_c("bozuk eski dönem (hedeften büyük / saçma büyük / negatif) teslim üretmez (fail-closed)",
		(Missions.rollover(tampered, WED)["auto_claimed"] as Array).is_empty())
	_c("for_day = rollover'ın durumu (salt görünüm)", Missions.for_day(tue, WED) == wed["state"]
		and Missions.for_day(sun, NEXT_MON) == mon["state"])
	_sections_done += 1


# --- 2) Göç + bozuk veri ---------------------------------------------------------------------------

func _migration() -> void:
	print("-- göç: sürüm 1 → 2, bozuk veri fail-closed, yükleme yazmaz")
	var v1_partial: Dictionary = Missions.sanitize(_v1(TUE, {"daily_merges": 7, "daily_rounds": 1.0}, [], {"weekly_rounds": 4}, []))
	_c("sürüm 1 kısmi ilerleme → sürüm 2, AYNEN AKTİF (7, 1, 4), alınabilir yok", int(v1_partial["version"]) == 2
		and v1_partial["daily_progress"]["daily_merges"] == 7 and v1_partial["daily_progress"]["daily_rounds"] == 1
		and v1_partial["weekly_progress"]["weekly_rounds"] == 4 and Missions.claimable_count(v1_partial) == 0)
	var v1_paid: Dictionary = Missions.sanitize(_v1(TUE, {}, ["daily_merges", "daily_rounds", "daily_clear"], {},
		["weekly_merges", "weekly_rounds", "weekly_clears"]))
	_c("sürüm 1 bütün görevler ödenmiş → altısı ALINDI (6/6), ikinci ödül yolu yok", Missions.completed_count(v1_paid) == 6
		and Missions.claimable_count(v1_paid) == 0 and int(Missions.claim(v1_paid, &"daily_merges", TUE)["result"])
		== Missions.Claim.ALREADY_CLAIMED)
	var v1_one: Dictionary = Missions.sanitize(_v1(TUE, {"daily_merges": 15, "daily_rounds": 1}, ["daily_merges"], {}, []))
	_c("sürüm 1 örnek (brief): daily_merges ödenmiş → ALINDI; daily_rounds 1/2 → AKTİF", Missions.status_of(v1_one,
		&"daily_merges") == Missions.STATUS_CLAIMED and Missions.status_of(v1_one, &"daily_rounds") == Missions.STATUS_ACTIVE
		and v1_one["daily_progress"]["daily_rounds"] == 1)
	var v1_odd: Dictionary = Missions.sanitize(_v1(TUE, {"daily_merges": 15, "daily_clear": 1}, [], {"weekly_merges": 500}, []))
	_c("sürüm 1'de ödülsüz hedefte görev (kendi kodumuz üretmez) → hedef − 1: sürüm 1 alınabilir görev ÜRETEMEZ",
		v1_odd["daily_progress"]["daily_merges"] == 14 and v1_odd["daily_progress"]["daily_clear"] == 0
		and v1_odd["weekly_progress"]["weekly_merges"] == 119 and Missions.claimable_count(v1_odd) == 0)
	var v2_ready: Dictionary = Missions.sanitize(_raw(TUE, {"daily_merges": 15.0}, [], {}, [], 2.0))
	_c("sürüm 2 (JSON float 2.0 / 15.0) tamamlanmış ama alınmamış → ALINABİLİR", Missions.is_claimable(v2_ready, &"daily_merges"))
	var v2_claimed: Dictionary = Missions.sanitize(_v2(TUE, {"daily_merges": 3}, ["daily_merges"], {}, []))
	_c("sürüm 2 alınmış görev → ALINDI, ilerleme = hedef (alınmış ⇒ tamamlanmış)", Missions.is_claimed(v2_claimed, &"daily_merges")
		and v2_claimed["daily_progress"]["daily_merges"] == 15)
	var mixed: Dictionary = Missions.sanitize(_v2(TUE, {"daily_merges": 15, "daily_bogus": 9, "weekly_merges": 120},
		["daily_rounds", "daily_rounds", "weekly_merges", "bogus", 7, null], {"weekly_rounds": 12, "daily_clear": 1},
		["weekly_rounds", "daily_clear"]))
	_c("bilinmeyen id / çift talep id / öteki dönemin id'si düşer; tekrar tekilleşir",
		mixed["daily_rewarded"] == ["daily_rounds"] and mixed["weekly_rewarded"] == ["weekly_rounds"]
		and (mixed["daily_progress"] as Dictionary).size() == 3 and (mixed["weekly_progress"] as Dictionary).size() == 3
		and not (mixed["daily_progress"] as Dictionary).has("weekly_merges"))
	# Fail-closed: aralık dışı / biçimsiz ilerleme asla alınabilir görev olmaz.
	var corrupt_values: Array = [-1, -0.5, 16, 15.5, 1e300, -1e300, INF, -INF, NAN, "15", "x", true, [15], {"v": 15}, null]
	var corrupt_ok: bool = true
	for value: Variant in corrupt_values:
		var s: Dictionary = Missions.sanitize(_v2(TUE, {"daily_merges": value, "daily_clear": value}, [],
			{"weekly_merges": value}, []))
		if s.is_empty() or Missions.claimable_count(s) != 0 or int(s["daily_progress"]["daily_merges"]) != 0:
			corrupt_ok = false
			print("    bozuk değer kabul edildi: ", value, " → ", s.get("daily_progress"))
	_c("sürüm 2 bozuk ilerleme (negatif / hedeften büyük / ±1e300 / ±sonsuz / NaN / metin / bool / dizi / sözlük / null) → 0, alınabilir YOK",
		corrupt_ok)
	var floor_ok: Dictionary = Missions.sanitize(_v2(TUE, {"daily_merges": 7.9, "daily_rounds": 2.0}, [], {}, []))
	_c("sürüm 2 aralık içi float aşağı yuvarlanır (7.9 → 7); tam hedef float (2.0) tamamlandı",
		floor_ok["daily_progress"]["daily_merges"] == 7 and Missions.is_claimable(floor_ok, &"daily_rounds"))
	var bad_blocks: Array = [null, "bozuk", 5, [], {}, _raw(TUE, {}, [], {}, [], 3), _raw(TUE, {}, [], {}, [], 0),
		_raw(TUE, {}, [], {}, [], "2"), _raw("2026-02-30", {"daily_merges": 15}, [], {}, [], 2),
		_raw("garbage", {}, [], {}, [], 2)]
	var blocks_ok: bool = true
	for raw: Variant in bad_blocks:
		if not Missions.sanitize(raw).is_empty():
			blocks_ok = false
	_c("eksik blok / sözlük değil / bilinmeyen sürüm (3, 0, '2') / geçersiz takvim günü → dönem yok (taze, alınabilir YOK)", blocks_ok)
	var odd_week: Dictionary = _v2(TUE, {"daily_merges": 4}, [], {"weekly_merges": 120}, ["weekly_rounds"])
	odd_week["week_start_day_key"] = "2026-09-27"
	var odd: Dictionary = Missions.sanitize(odd_week)
	_c("geçersiz hafta anahtarı → haftalık kısım taze (alınabilir / alınmış taşınmaz), günlük korunur",
		_zero(odd, WEEKLY) and odd["week_start_day_key"] == MON and odd["daily_progress"]["daily_merges"] == 4)
	# Genel özellik: temiz (alınabilirsiz) bir taban üzerinde her bozulma alınabilir sayısını ARTIRMAZ.
	var base: Dictionary = _v2(TUE, {"daily_merges": 14, "daily_rounds": 1, "daily_clear": 0}, ["daily_clear"],
		{"weekly_merges": 119, "weekly_rounds": 11, "weekly_clears": 4}, [])
	var mutations: Array = []
	for key: String in ["daily_progress", "weekly_progress"]:
		for value: Variant in corrupt_values:
			var m: Dictionary = base.duplicate(true)
			for id: String in (m[key] as Dictionary).keys():
				(m[key] as Dictionary)[id] = value
			mutations.append(m)
	for key: String in ["daily_rewarded", "weekly_rewarded"]:
		for value: Variant in ["daily_merges", 5, null, {"a": 1}, ["weekly_merges", "weekly_merges"]]:
			var m2: Dictionary = base.duplicate(true)
			m2[key] = value
			mutations.append(m2)
	var prop_ok: bool = true
	for m: Dictionary in mutations:
		if Missions.claimable_count(Missions.sanitize(m)) > Missions.claimable_count(Missions.sanitize(base)):
			prop_ok = false
			print("    bozulma alınabilir ekledi: ", m)
	_c("%d bozulma: hiçbiri alınabilir görev EKLEMEDİ (bozuk veri ödül yolu değil)" % mutations.size(), prop_ok
		and Missions.claimable_count(Missions.sanitize(base)) == 0)

	# Diskten yükleme (gerçek SaveManager).
	_clean()
	DailyRewards.clock_override = TUE
	var legacy_file: Dictionary = _fixture({"dough": 335, "highest_level_unlocked": 6,
		"level_stars": {"1": 3, "2": 2, "3": 3, "4": 1, "5": 2}, "unlocked_skins": ["common_01", "rare_02"],
		"profile_showcase": ["rare_02"], "powerups": {"bomb": 3, "upgrade": 2, "shake": 0, "clear_small": 1},
		"player_xp": 932, "unlocked_achievements": ["first_merge"], "total_merges": 812,
		"missions": _v1(TUE, {"daily_merges": 15, "daily_rounds": 1}, ["daily_merges"], {"weekly_rounds": 4}, [])})
	_write(PATH, legacy_file)
	var bytes: PackedByteArray = _bytes(PATH)
	SaveManager.load_game()
	var m: Dictionary = SaveManager.data["missions"]
	_c("diskten sürüm 1 kayıt: bellekte sürüm 2 — daily_merges ALINDI, daily_rounds 1/2 AKTİF, haftalık tur 4",
		int(m["version"]) == 2 and Missions.is_claimed(m, &"daily_merges") and m["daily_progress"]["daily_rounds"] == 1
		and m["weekly_progress"]["weekly_rounds"] == 4 and Missions.claimable_count(SaveManager.missions_state()) == 0)
	_c("göç Hamur VERMEDİ (335)", SaveManager.dough() == 335)
	var stars_ok: bool = true
	for level: String in (legacy_file["level_stars"] as Dictionary).keys():
		stars_ok = stars_ok and SaveManager.stars_for_level(int(level)) == int(legacy_file["level_stars"][level])
	var powers_ok: bool = true
	for key: String in (legacy_file["powerups"] as Dictionary).keys():
		powers_ok = powers_ok and int((SaveManager.data["powerups"] as Dictionary).get(key, -1)) == int(legacy_file["powerups"][key])
	print("    level %d · yıldız %s · parça %s · vitrin %s · güç %s · XP %d · merge %d · başarım %s" % [
		SaveManager.highest_level_unlocked(), str(stars_ok), str(SaveManager.owned_skins()), str(SaveManager.profile_showcase()),
		str(powers_ok), SaveManager.player_xp(), SaveManager.total_merges(), str(SaveManager.unlocked_achievements())])
	_c("göç öteki alanlara dokunmadı: level 6, yıldızlar, koleksiyon, güçler, XP 932, toplam merge 812, başarım korunur",
		SaveManager.highest_level_unlocked() == 6 and stars_ok and SaveManager.owned_skins() == ["common_01", "rare_02"]
		and powers_ok and SaveManager.player_xp() == 932 and SaveManager.total_merges() == 812
		and SaveManager.unlocked_achievements().has(&"first_merge"))
	_c("göç yüklemede diske YAZMADI (bayt-aynı, .tmp / .bak yok)", _bytes(PATH) == bytes and not _exists(TMP) and not _exists(BAK))
	SaveManager.load_game()
	_c("ikinci yükleme: aynı sonuç (idempotent), yine yazma yok", SaveManager.data["missions"] == m and _bytes(PATH) == bytes)
	SaveManager.save_game()
	var disk: Dictionary = _disk()
	_c("doğal kayıt sürüm 2 bloğu kalıcılaştırdı; yeniden yükleme aynı", int((disk["missions"] as Dictionary)["version"]) == 2
		and Missions.sanitize(disk["missions"]) == m)
	var settle_old: Dictionary = SaveManager.settle_missions()
	_c("sürüm 1 kökenli dönem için dönem işlemi teslim etmez (ödenmiş = ALINDI)", (settle_old["auto_claimed"] as Array).is_empty()
		and SaveManager.dough() == 335)
	# Eski dönemden sürüm 1 (MON) → TUE açılışı: geçişte teslim YOK (ödenmişler zaten ödendi, eksikler ödüle dönüşmez).
	_write(PATH, _fixture({"dough": 335, "missions": _v1(MON, {"daily_merges": 15, "daily_rounds": 1},
		["daily_merges", "daily_clear"], {}, ["weekly_rounds"])}))
	SaveManager.load_game()
	var before_disk: PackedByteArray = _bytes(PATH)
	_arm_detector()
	var legacy_roll: Dictionary = SaveManager.settle_missions()
	_c("sürüm 1 eski gün (MON) → TUE: teslim yok, yazma girişimi yok, Hamur 335; görünüm taze TUE (haftalık ALINDI korunur)",
		(legacy_roll["auto_claimed"] as Array).is_empty() and _no_write() and _bytes(PATH) == before_disk
		and SaveManager.dough() == 335 and SaveManager.missions_state()["day_key"] == TUE
		and Missions.is_claimed(SaveManager.missions_state(), &"weekly_rounds"))
	_disarm()
	# .tmp / .bak kurtarması sürüm 2 durumunu (alınabilir / alınmış) taşır.
	_write(PATH, _fixture({"dough": 335, "missions": _v2(TUE, {"daily_merges": 15}, [], {}, [])}))
	SaveManager.load_game()
	SaveFile.fault = SaveFile.Fault.CRASH_AFTER_BACKUP
	var crash: Dictionary = SaveManager.claim_mission_reward(&"daily_merges", TUE)
	_c("ön koşul: talep yazması yer değiştirmede öldü (kanonik ad boş, .tmp yeni, .bak eski)", int(crash["result"])
		== Missions.Claim.CLAIMED and not bool(crash["saved"]) and not _exists(PATH) and _exists(TMP) and _exists(BAK))
	SaveManager.load_game()
	_c(".tmp kurtarması talebi taşır: ALINDI + Hamur 345 (tam bir kez)", SaveManager.load_source() == SaveFile.Source.TEMP
		and Missions.is_claimed(SaveManager.missions_state(), &"daily_merges") and SaveManager.dough() == 345
		and int(SaveManager.claim_mission_reward(&"daily_merges", TUE)["result"]) == Missions.Claim.ALREADY_CLAIMED
		and SaveManager.dough() == 345)
	_write(PATH, _fixture({"dough": 335, "missions": _v2(TUE, {"daily_merges": 15}, [], {}, [])}))
	SaveManager.load_game()
	SaveManager.claim_mission_reward(&"daily_merges", TUE)
	var torn: String = FileAccess.get_file_as_string(PATH).substr(0, 40)
	_put(PATH, torn.to_utf8_buffer())
	SaveManager.load_game()
	_c("bozuk kanonik → .bak (bir önceki kuşak: alınabilir, 335) — talep yeniden tam bir kez (+10)",
		SaveManager.load_source() == SaveFile.Source.BACKUP and Missions.is_claimable(SaveManager.missions_state(),
		&"daily_merges") and SaveManager.dough() == 335
		and int(SaveManager.claim_mission_reward(&"daily_merges", TUE)["claimed_dough"]) == 10 and SaveManager.dough() == 345)
	SaveFile.fault = SaveFile.Fault.NONE
	DailyRewards.clock_override = ""
	_sections_done += 1


# --- 3) Dönem işlemi (SaveManager.settle_missions) ------------------------------------------------------

func _settle_transactions() -> void:
	print("-- dönem işlemi: teslim tek yazma, no-op yazmaz, çökme / yazma hatası tam bir kez")
	DailyRewards.clock_override = TUE
	_reset_disk(_v2(TUE, {"daily_merges": 15, "daily_rounds": 2}, ["daily_rounds"], {"weekly_merges": 120}, []))
	var bytes: PackedByteArray = _bytes(PATH)
	_arm_detector()
	var normal: Dictionary = SaveManager.settle_missions()
	_c("normal gün: teslim yok, yazma girişimi yok, bellek aynı", (normal["auto_claimed"] as Array).is_empty() and _no_write()
		and _bytes(PATH) == bytes and SaveManager.dough() == BASE_DOUGH)
	_disarm()
	DailyRewards.clock_override = WED
	var memory: Dictionary = SaveManager.data["missions"].duplicate(true)
	var settled: Dictionary = SaveManager.settle_missions()
	var disk: Dictionary = _disk()
	_c("yeni gün: daily_merges TAM BİR KEZ teslim (+10), yazma başarılı; alınmış daily_rounds yok; haftalık alınabilir KALIR",
		settled["auto_claimed"] == [&"daily_merges"] and int(settled["dough"]) == 10 and bool(settled["saved"])
		and SaveManager.dough() == BASE_DOUGH + 10 and Missions.is_claimable(SaveManager.missions_state(), &"weekly_merges"))
	_c("  … TEK yazmada: diskte yeni dönem (WED) + Hamur 510 birlikte", int(disk.get("dough", -1)) == BASE_DOUGH + 10
		and String((disk["missions"] as Dictionary)["day_key"]) == WED and memory["day_key"] == TUE)
	bytes = _bytes(PATH)
	_arm_detector()
	var second: Dictionary = SaveManager.settle_missions()
	_c("ikinci çağrı (aynı gün): no-op, yazma girişimi yok", (second["auto_claimed"] as Array).is_empty() and _no_write()
		and _bytes(PATH) == bytes and SaveManager.dough() == BASE_DOUGH + 10)
	_disarm()
	SaveManager.load_game()
	_c("yeniden açılış + dönem işlemi: çift teslim yok (510)", (SaveManager.settle_missions()["auto_claimed"] as Array).is_empty()
		and SaveManager.dough() == BASE_DOUGH + 10)
	# Teslimsiz yeni gün: hiçbir şey yazılmaz, bellek değişmez (görünüm yeni günü gösterir).
	_reset_disk(_v2(WED, {"daily_merges": 14}, [], {"weekly_rounds": 6}, []))
	DailyRewards.clock_override = THU
	bytes = _bytes(PATH)
	var raw_before: Dictionary = SaveManager.data["missions"].duplicate(true)
	_arm_detector()
	var empty: Dictionary = SaveManager.settle_missions()
	_c("teslimsiz yeni gün (eksik 14/15): yazma yok, bellek aynı, görünüm THU taze — eksik ilerleme ödüle dönüşmedi",
		(empty["auto_claimed"] as Array).is_empty() and _no_write() and _bytes(PATH) == bytes
		and SaveManager.data["missions"] == raw_before and SaveManager.missions_state()["day_key"] == THU
		and _zero(SaveManager.missions_state(), DAILY) and SaveManager.dough() == BASE_DOUGH)
	_disarm()
	# Pazartesi: iki dönem birden.
	_reset_disk(_v2(SUN, {"daily_merges": 15, "daily_clear": 1}, ["daily_clear"], {"weekly_rounds": 12, "weekly_clears": 5},
		["weekly_clears"]))
	DailyRewards.clock_override = NEXT_MON
	var monday: Dictionary = SaveManager.settle_missions()
	_c("pazar → pazartesi: daily_merges +10 + weekly_rounds +40 = +50, alınmışlar teslim edilmez, iki dönem taze",
		monday["auto_claimed"] == [&"daily_merges", &"weekly_rounds"] and int(monday["dough"]) == 50
		and SaveManager.dough() == BASE_DOUGH + 50 and _zero(SaveManager.missions_state(), DAILY)
		and _zero(SaveManager.missions_state(), WEEKLY) and int(_disk().get("dough", -1)) == BASE_DOUGH + 50)
	# Saat geri: teslim edilmiş dönem geri gelmez.
	DailyRewards.clock_override = SUN
	_c("saat pazara geri alındı: dönem pazartesi kalır, yeni teslim yok", (SaveManager.settle_missions()["auto_claimed"]
		as Array).is_empty() and SaveManager.missions_state()["day_key"] == NEXT_MON and SaveManager.dough() == BASE_DOUGH + 50)

	# Çökme / yazma hatası matrisi: her durumda (yeniden açılış dahil) TAM BİR KEZ.
	var faults: Array = [SaveFile.Fault.CRASH_AFTER_TEMP, SaveFile.Fault.CRASH_AFTER_BACKUP, SaveFile.Fault.COMMIT,
		SaveFile.Fault.COMMIT_AND_ROLLBACK, SaveFile.Fault.TEMP_OPEN, SaveFile.Fault.TEMP_WRITE, SaveFile.Fault.TEMP_SHORT,
		SaveFile.Fault.BACKUP_MOVE]
	var matrix_ok: bool = true
	for fault: int in faults:
		DailyRewards.clock_override = TUE
		_reset_disk(_v2(TUE, {"daily_merges": 15, "daily_rounds": 2}, [], {}, []))
		DailyRewards.clock_override = WED
		SaveFile.fault = fault as SaveFile.Fault
		var failed: Dictionary = SaveManager.settle_missions()
		var memory_ok: bool = not bool(failed["saved"]) and SaveManager.dough() == BASE_DOUGH + 20
		var again: Dictionary = SaveManager.settle_missions()
		var no_double_in_memory: bool = (again["auto_claimed"] as Array).is_empty() and SaveManager.dough() == BASE_DOUGH + 20
		# Yeniden açılış (süreç ölümü / yazma hatası sonrası): kurtarılan kayıt ya eski dönem (teslim yeniden — tek kez)
		# ya yeni dönem (teslim edilmiş).
		SaveFile.fault = SaveFile.Fault.NONE
		SaveManager.load_game()
		SaveManager.settle_missions()
		SaveManager.settle_missions()
		var final_ok: bool = (SaveManager.dough() == BASE_DOUGH + 20 and SaveManager.missions_state()["day_key"] == WED
			and _zero(SaveManager.missions_state(), DAILY))
		SaveManager.save_game()
		var disk_ok: bool = int(_disk().get("dough", -1)) == BASE_DOUGH + 20
		if not (memory_ok and no_double_in_memory and final_ok and disk_ok):
			matrix_ok = false
			print("    hata %d: bellek %s / ikinci %s / son %s / disk %s (Hamur %d)" % [fault, str(memory_ok),
				str(no_double_in_memory), str(final_ok), str(disk_ok), SaveManager.dough()])
	_c("%d hata (çökme: .tmp sonrası / .bak sonrası; taşıma; geri alma; .tmp açma / yazma / kısa; yedek): her durumda +20 TAM BİR KEZ (bellek, yeniden açılış, disk)"
		% faults.size(), matrix_ok)
	SaveFile.fault = SaveFile.Fault.NONE
	DailyRewards.clock_override = ""
	_sections_done += 1


# --- 4) Talep (SaveManager.claim_mission_reward) ----------------------------------------------------------

func _claim_transactions() -> void:
	print("-- talep: tek yetkili işlem")
	DailyRewards.clock_override = TUE
	_reset_disk(_v2(TUE, {"daily_merges": 15, "daily_rounds": 1}, [], {"weekly_rounds": 12}, []))
	var side: Dictionary = _side_snapshot()
	var ok: Dictionary = SaveManager.claim_mission_reward(&"daily_merges", TUE)
	var disk: Dictionary = _disk()
	_c("geçerli talep: CLAIMED, +10, yazıldı; diskte ödül işareti + Hamur 510 aynı kayıtta", int(ok["result"])
		== Missions.Claim.CLAIMED and int(ok["dough"]) == 10 and int(ok["claimed_dough"]) == 10 and bool(ok["saved"])
		and SaveManager.dough() == BASE_DOUGH + 10 and int(disk.get("dough", -1)) == BASE_DOUGH + 10
		and ((disk["missions"] as Dictionary)["daily_rewarded"] as Array) == ["daily_merges"])
	_c("talep ilerlemeyi değiştirmedi (15, 1, 12)", SaveManager.missions_state()["daily_progress"]["daily_merges"] == 15
		and SaveManager.missions_state()["daily_progress"]["daily_rounds"] == 1
		and SaveManager.missions_state()["weekly_progress"]["weekly_rounds"] == 12)
	var bytes: PackedByteArray = _bytes(PATH)
	_arm_detector()
	var dup: Dictionary = SaveManager.claim_mission_reward(&"daily_merges", TUE)
	var incomplete: Dictionary = SaveManager.claim_mission_reward(&"daily_rounds", TUE)
	var unknown: Dictionary = SaveManager.claim_mission_reward(&"daily_bogus", TUE)
	var wrong: Dictionary = SaveManager.claim_mission_reward(&"weekly_rounds", TUE)
	_c("ikinci talep ALREADY_CLAIMED · eksik NOT_COMPLETE · bilinmeyen UNKNOWN · yanlış dönem WRONG_PERIOD — hepsi Hamur 0, yazma girişimi yok",
		int(dup["result"]) == Missions.Claim.ALREADY_CLAIMED and int(incomplete["result"]) == Missions.Claim.NOT_COMPLETE
		and int(unknown["result"]) == Missions.Claim.UNKNOWN and int(wrong["result"]) == Missions.Claim.WRONG_PERIOD
		and int(dup["dough"]) + int(incomplete["dough"]) + int(unknown["dough"]) + int(wrong["dough"]) == 0
		and _no_write() and _bytes(PATH) == bytes and SaveManager.dough() == BASE_DOUGH + 10)
	_disarm()
	var week: Dictionary = SaveManager.claim_mission_reward(&"weekly_rounds", MON)
	var week_again: Dictionary = SaveManager.claim_mission_reward(&"weekly_rounds", MON)
	_c("haftalık (pazartesi anahtarı): +40; hemen ardından aynı talep ikinci ödül vermez", int(week["result"])
		== Missions.Claim.CLAIMED and int(week_again["result"]) == Missions.Claim.ALREADY_CLAIMED
		and SaveManager.dough() == BASE_DOUGH + 50)
	var side_after: Dictionary = _side_snapshot()
	_c("talepler yalnız Hamur + ödül işareti yazdı: XP / başarım / unvan / güç / ödüllü kota / günlük ödüller / meydan okuma / yıldız / level / koleksiyon / sayaçlar AYNEN",
		side_after == side)
	SaveManager.load_game()
	_c("yeniden açılış: ALINDI kalıcı (daily_merges + weekly_rounds), Hamur 550", Missions.is_claimed(SaveManager.missions_state(),
		&"daily_merges") and Missions.is_claimed(SaveManager.missions_state(), &"weekly_rounds") and SaveManager.dough() == BASE_DOUGH + 50)

	# Gece yarısını açık geçen pencere: dokunulan görev kapanan dönemin teslimiyle TAM BİR KEZ.
	_reset_disk(_v2(TUE, {"daily_clear": 1, "daily_merges": 15, "daily_rounds": 1}, [], {"weekly_merges": 120}, []))
	DailyRewards.clock_override = WED
	var midnight: Dictionary = SaveManager.claim_mission_reward(&"daily_clear", TUE)
	_c("gece yarısı (gösterilen TUE, gün WED): AUTO_CLAIMED, dokunulan +10; kapanan günün iki alınabilirinin teslimi +20, TEK yazma",
		int(midnight["result"]) == Missions.Claim.AUTO_CLAIMED and int(midnight["claimed_dough"]) == 10
		and int(midnight["dough"]) == 20 and midnight["auto_claimed"] == [&"daily_merges", &"daily_clear"]
		and bool(midnight["saved"]) and SaveManager.dough() == BASE_DOUGH + 20 and int(_disk().get("dough", -1)) == BASE_DOUGH + 20)
	_c("  … dönem WED (taze), haftalık alınabilir kaldı; eski anahtarla yeni talep WRONG_PERIOD, Hamur yok",
		SaveManager.missions_state()["day_key"] == WED and Missions.is_claimable(SaveManager.missions_state(), &"weekly_merges")
		and int(SaveManager.claim_mission_reward(&"daily_clear", TUE)["result"]) == Missions.Claim.WRONG_PERIOD
		and SaveManager.dough() == BASE_DOUGH + 20)
	_reset_disk(_v2(TUE, {"daily_merges": 15, "daily_rounds": 1}, [], {}, []))
	DailyRewards.clock_override = WED
	var other: Dictionary = SaveManager.claim_mission_reward(&"daily_rounds", TUE)
	_c("gece yarısı + eksik göreve dokunuş: WRONG_PERIOD (dokunulan için Hamur yok) ama kapanan günün alınabiliri teslim (+10)",
		int(other["result"]) == Missions.Claim.WRONG_PERIOD and int(other["claimed_dough"]) == 0 and int(other["dough"]) == 10
		and SaveManager.dough() == BASE_DOUGH + 10)
	_reset_disk(_v2(SUN, {}, [], {"weekly_clears": 5}, []))
	DailyRewards.clock_override = NEXT_MON
	var monday: Dictionary = SaveManager.claim_mission_reward(&"weekly_clears", MON)
	_c("pazartesi gece yarısı: haftalık eski anahtarla AUTO_CLAIMED +40 (tam bir kez)", int(monday["result"])
		== Missions.Claim.AUTO_CLAIMED and int(monday["claimed_dough"]) == 40 and SaveManager.dough() == BASE_DOUGH + 40
		and int(SaveManager.claim_mission_reward(&"weekly_clears", MON)["dough"]) == 0)

	# Yazma hatası: bellek güncel, disk eski; yeniden açılışta tam bir kez.
	DailyRewards.clock_override = TUE
	_reset_disk(_v2(TUE, {"daily_merges": 15}, [], {}, []))
	SaveFile.fault = SaveFile.Fault.TEMP_OPEN
	var failed: Dictionary = SaveManager.claim_mission_reward(&"daily_merges", TUE)
	_c("yazma hatası: sonuç CLAIMED ama saved=false; bellek ALINDI + 510, disk eski (500, alınabilir)",
		int(failed["result"]) == Missions.Claim.CLAIMED and not bool(failed["saved"]) and SaveManager.dough() == BASE_DOUGH + 10
		and int(_disk().get("dough", -1)) == BASE_DOUGH and ((_disk()["missions"] as Dictionary)["daily_rewarded"] as Array).is_empty())
	_c("  … aynı oturumda tekrar talep ikinci ödül vermez", int(SaveManager.claim_mission_reward(&"daily_merges", TUE)["result"])
		== Missions.Claim.ALREADY_CLAIMED and SaveManager.dough() == BASE_DOUGH + 10)
	SaveFile.fault = SaveFile.Fault.NONE
	SaveManager.load_game()
	var retry: Dictionary = SaveManager.claim_mission_reward(&"daily_merges", TUE)
	_c("  … uygulama yazmadan kapandı → yeniden açılışta görev yine alınabilir; talep diskte TAM BİR KEZ (510)",
		int(retry["result"]) == Missions.Claim.CLAIMED and SaveManager.dough() == BASE_DOUGH + 10
		and int(_disk().get("dough", -1)) == BASE_DOUGH + 10)
	# Bozuk saat: kayıtlı dönemde talep çalışır; dönem yoksa NO_PERIOD.
	_reset_disk(_v2(TUE, {"daily_clear": 1}, [], {}, []))
	var raw_daily: Dictionary = (SaveManager.data["daily_rewards"] as Dictionary).duplicate()
	raw_daily["last_seen_day_key"] = "bozuk"
	SaveManager.data["daily_rewards"] = raw_daily
	DailyRewards.clock_override = "1999-12-31"
	_c("bozuk saat (kabul edilen gün yok): kayıtlı TUE döneminde talep CLAIMED (+10), yeni dönem açılmadı",
		Missions.accepted_day() == "" and int(SaveManager.claim_mission_reward(&"daily_clear", TUE)["result"])
		== Missions.Claim.CLAIMED and SaveManager.missions_state()["day_key"] == TUE)
	SaveManager.data["missions"] = DEFAULT_MISSIONS()
	_c("  … dönem yok + bozuk saat → NO_PERIOD (Hamur yok)", int(SaveManager.claim_mission_reward(&"daily_clear", TUE)["result"])
		== Missions.Claim.NO_PERIOD)
	DailyRewards.clock_override = ""
	_sections_done += 1


# --- 5) Gerçek Main -------------------------------------------------------------------------------------

func _main_flows() -> void:
	print("-- gerçek Main: Ana Sayfa + GÖREVLER penceresi + gerçek girdi")
	# a) Açılışta teslim (uygulama kapalıyken gün değişti).
	_clean()
	DailyRewards.clock_override = MON
	_write(PATH, _fixture({"missions": _v2(MON, {"daily_merges": 15, "daily_rounds": 2}, ["daily_rounds"], {}, [])}))
	SaveManager.load_game()
	DailyRewards.clock_override = TUE
	await _boot()
	var home: CanvasLayer = _main._screens[0]
	var overlay: MissionsOverlay = _main._missions
	_c("açılış (MON → TUE): daily_merges TAM BİR KEZ teslim (+10); Ana Sayfa Hamur hapı 510; diskte 510 + TUE",
		SaveManager.dough() == BASE_DOUGH + 10 and _pill_text(home) == str(BASE_DOUGH + 10)
		and int(_disk().get("dough", -1)) == BASE_DOUGH + 10 and String((_disk()["missions"] as Dictionary)["day_key"]) == TUE)
	_c("  … yeni gün rozetleri: 0/6, dikkat sayısı yok", home.missions_count_text() == "0/6"
		and not home.missions_attention().visible)

	# b) Ana Sayfa N/6 + dikkat sayısı ayrı anlam; pencere durumları.
	SaveManager.data["missions"] = Missions.sanitize(_v2(TUE, {"daily_merges": 15, "daily_rounds": 2, "daily_clear": 0},
		["daily_merges"], {"weekly_merges": 60}, []))
	await _show_home()
	_c("Ana Sayfa: 2 tamam (1 alındı + 1 alınabilir) → altın '2/6' + dikkat sayısı '1' (iki rozet, iki anlam)",
		home.missions_count_text() == "2/6" and home.missions_attention().visible and home.missions_attention().text() == "1"
		and home.missions_attention().mode() == AttentionBadge.Mode.COUNT)
	var medal: Control = home.missions_button()
	_c("  … dikkat rozeti madalyonun sol üst köşesinde, ekranda, altın rozetle çakışmıyor; madalyon boyu değişmedi",
		home.missions_attention().get_global_rect().get_center().distance_to(medal.get_global_rect().position + Vector2(7, 9)) < 2.0
		and home.missions_attention().get_global_rect().position.x >= 0.0
		and not home.missions_attention().get_global_rect().intersects(home.missions_badge().get_global_rect())
		and medal.size == HomeFeatureButton.SIZE)
	await _wait_settled()
	await _open()
	var merges_card: MissionCard = overlay.card(&"daily_merges")
	var rounds_card: MissionCard = overlay.card(&"daily_rounds")
	var clear_card: MissionCard = overlay.card(&"daily_clear")
	_c("başlık: '2 / 6' + alınabilir rozeti '1' + not 'Tamamla, ödülünü al!'", overlay.count_text() == "2 / 6"
		and overlay.claimable_badge().visible and overlay.claimable_badge().text() == "1"
		and overlay.note_text() == "Tamamla, ödülünü al!")
	_c("kart durumları: merge ALINDI ('ALINDI', tik) · tur ALINABİLİR ('ÖDÜLÜ AL', '+10', tik) · level AKTİF (ödül kutusu '+10', CTA yok)",
		merges_card.status() == Missions.STATUS_CLAIMED and merges_card.cta_text() == "ALINDI" and merges_card.is_done_shown()
		and rounds_card.status() == Missions.STATUS_CLAIMABLE and rounds_card.cta_text() == "ÖDÜLÜ AL"
		and rounds_card.claim_button().amount_text() == "+10" and rounds_card.is_done_shown()
		and clear_card.status() == Missions.STATUS_ACTIVE and clear_card.cta_text() == "" and clear_card.reward_box().visible
		and clear_card.reward_text() == "+10" and not clear_card.is_done_shown())
	_c("ALINDI CTA pasif (disabled) — ikinci dokunuş eylemsiz; AKTİF kartta basılabilir hedef yok",
		merges_card.claim_button().disabled and not clear_card.claim_button().is_visible_in_tree()
		and clear_card.reward_box().mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var cta: MissionCard.ClaimButton = rounds_card.claim_button()
	var hit: Rect2 = cta.hit_rect()
	_c("CTA dokunma alanı ≥ 84 tuval px (A36'da 48 dp; görsel %d), kartın içinde; görselin 8 px üstü de isabet" % int(cta.size.y),
		hit.size.y >= float(UiTokens.TOUCH_TARGET) - 0.5 and cta.size.y >= float(UiTokens.TOUCH_COMPACT) - 0.5
		and rounds_card.get_global_rect().grow(0.5).encloses(Rect2(cta.get_global_rect().position + hit.position, hit.size))
		and cta._has_point(Vector2(cta.size.x * 0.5, -8.0)))

	# c) Gerçek parmakla talep.
	var dough0: int = SaveManager.dough()
	await _finger_tap(_screen_center(cta))
	await _settle(2)
	_c("parmak: ÖDÜLÜ AL → +10 (bellek + disk), kart ALINDI, başlık rozeti gizli, Ana Sayfa dikkat sayısı gizli + Hamur hapı güncel",
		SaveManager.dough() == dough0 + 10 and int(_disk().get("dough", -1)) == dough0 + 10
		and rounds_card.status() == Missions.STATUS_CLAIMED and rounds_card.cta_text() == "ALINDI"
		and not overlay.claimable_badge().visible and not home.missions_attention().visible
		and _pill_text(home) == str(dough0 + 10))
	_c("  … candy geri bildirim: CTA üstünde '+10' yükselişi (Hamur sanatıyla), pencere AÇIK (tam ekran kutlama yok)",
		overlay.gain_feedback() != null and _label_texts(overlay.gain_feedback()).has("+10") and overlay.visible)
	# d) Çift dokunuş: ikinci dokunuş ALINDI'ya düşer.
	SaveManager.data["missions"] = Missions.sanitize(_v2(TUE, {"daily_clear": 1}, [], {"weekly_rounds": 12}, []))
	overlay.refresh()
	await _settle(2)
	dough0 = SaveManager.dough()
	var double_pos: Vector2 = _screen_center(overlay.card(&"daily_clear").claim_button())
	await _finger_tap(double_pos)
	await _finger_tap(double_pos)
	await _settle(2)
	_c("hızlı çift dokunuş: tek ödül (+10), ikinci dokunuş pasif ALINDI'ya düştü", SaveManager.dough() == dough0 + 10
		and int(_disk().get("dough", -1)) == dough0 + 10 and overlay.card(&"daily_clear").status() == Missions.STATUS_CLAIMED)
	# e) İki farklı CTA art arda.
	SaveManager.data["missions"] = Missions.sanitize(_v2(TUE, {"daily_merges": 15, "daily_rounds": 2}, [], {}, []))
	overlay.refresh()
	await _settle(2)
	dough0 = SaveManager.dough()
	await _finger_tap(_screen_center(overlay.card(&"daily_merges").claim_button()))
	await _finger_tap(_screen_center(overlay.card(&"daily_rounds").claim_button()))
	await _settle(2)
	_c("iki farklı CTA hızlı art arda: ikisi de tam bir kez (+20)", SaveManager.dough() == dough0 + 20
		and Missions.claimable_count(SaveManager.missions_state()) == 0)

	# f) İptal / sürükleme / kaydırma / uzun basış / GERİ / ekran değişimi.
	SaveManager.data["missions"] = Missions.sanitize(_v2(TUE, {"daily_rounds": 2}, [], {"weekly_clears": 5}, []))
	SaveManager.save_game()
	overlay.refresh()
	await _settle(2)
	dough0 = SaveManager.dough()
	var cancel_cta: Button = overlay.card(&"daily_rounds").claim_button()
	var bytes: PackedByteArray = _bytes(PATH)
	await _finger(_screen_center(cancel_cta), true)
	await _cancel(_screen_center(cancel_cta))
	_c("ACTION_CANCEL (iptal edilen bırakış): talep YOK, Hamur / disk aynı", SaveManager.dough() == dough0 and _bytes(PATH) == bytes
		and overlay.card(&"daily_rounds").status() == Missions.STATUS_CLAIMABLE)
	await _finger(_screen_center(cancel_cta), true)
	await _drag_to(_screen_center(cancel_cta), _screen_center(overlay.close_button()) + Vector2(0, 40) * _scale())
	await _finger(_screen_center(overlay.close_button()) + Vector2(0, 40) * _scale(), false)
	await _settle(2)
	_c("parmak CTA'dan dışarı sürüklenip bırakıldı: talep YOK", SaveManager.dough() == dough0
		and overlay.card(&"daily_rounds").status() == Missions.STATUS_CLAIMABLE and overlay.visible)
	await _wait_settled()
	await _hold_release(_screen_center(cancel_cta), 0.8)
	_c("uzun basış (0,8 s) + bırakış: bilinçli eylem — tam bir kez (+10)", SaveManager.dough() == dough0 + 10
		and overlay.card(&"daily_rounds").status() == Missions.STATUS_CLAIMED)
	# Kısa kullanılabilir alan (üst pay 300 tuval px — kısa ekran + banner benzeri; `expand` germe tuvali hiçbir zaman
	# 1280'den kısa yapmaz): gövde kayar; kaydırma ilk kartın CTA'sından başlar.
	overlay.layout_with_safe_top(300.0)
	await _settle(3)
	SaveManager.data["missions"] = Missions.sanitize(_v2(TUE, {"daily_merges": 15}, [], {}, []))
	overlay.refresh()
	await _settle(3)
	dough0 = SaveManager.dough()
	var scroll: ScrollContainer = overlay.scroll()
	var scroll_cta: Button = overlay.card(&"daily_merges").claim_button()
	var range_px: float = scroll.get_v_scroll_bar().max_value - scroll.size.y
	print("    görünüm %s · kaydırma %s · içerik %.0f · body_scrolls %s · pencere %s" % [str(get_viewport().get_visible_rect().size),
		str(scroll.size), scroll.get_v_scroll_bar().max_value, str(overlay.frame().get_meta(&"body_scrolls", false)),
		str(get_window().size)])
	var start: Vector2 = _screen_center(scroll_cta)
	await _finger(start, true)
	await _drag_to(start, start + Vector2(0, -90) * _scale())
	await _finger(start + Vector2(0, -90) * _scale(), false)
	await _settle(3)
	_c("kaydırma CTA'nın üstünden başladı (%d px aralık): içerik kaydı (%d), talep YOK" % [int(range_px), scroll.scroll_vertical],
		range_px > 0.0 and scroll.scroll_vertical > 0 and SaveManager.dough() == dough0
		and overlay.card(&"daily_merges").status() == Missions.STATUS_CLAIMABLE)
	scroll.scroll_vertical = 0
	overlay.layout_with_safe_top(-1.0)
	await _settle(3)
	var back_cta: Button = overlay.card(&"daily_merges").claim_button()
	await _wait_settled()
	await _finger(_screen_center(back_cta), true)
	_main._last_back_msec = -1000
	_main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(2)
	await _finger(_screen_center(back_cta), false)
	await _settle(2)
	_c("CTA basılıyken Android GERİ: pencere kapandı, bırakış talep ETMEDİ", not overlay.visible and SaveManager.dough() == dough0
		and Missions.is_claimable(SaveManager.missions_state(), &"daily_merges"))
	await _wait_settled()
	await _open()
	var held: Button = overlay.card(&"daily_merges").claim_button()
	await _finger(_screen_center(held), true)
	_main._show_tab(1)
	await _settle(2)
	await _finger(_screen_center(held), false)
	await _settle(2)
	_c("CTA basılıyken ekran değişti (Harita): pencere kapandı, talep YOK", not overlay.visible and SaveManager.dough() == dough0
		and _main._active_tab == 1)
	_main._show_tab(0)
	await _wait_settled()
	await _open()
	var late_pos: Vector2 = _screen_center(overlay.card(&"daily_merges").claim_button())
	await _finger_tap(_screen_center(overlay.close_button()))
	await _finger_tap(late_pos)
	await _settle(2)
	_c("X'in hemen ardından CTA'nın yerine geç dokunuş: pencere kapalı, talep YOK (300 ms yatışma)", not overlay.visible
		and SaveManager.dough() == dough0)
	await _wait_settled()
	# g) Yeniden açılış + yeniden başlatma: ALINDI kalıcı.
	await _open()
	await _finger_tap(_screen_center(overlay.card(&"daily_merges").claim_button()))
	await _settle(2)
	overlay.close_missions(false)
	await _wait_settled()
	await _open()
	_c("talepten sonra kapat → aç: ALINDI kalıcı (kanonik veriden)", overlay.card(&"daily_merges").status() == Missions.STATUS_CLAIMED
		and SaveManager.dough() == dough0 + 10)
	overlay.close_missions(false)
	await _teardown_main()
	SaveManager.load_game()
	await _boot()
	home = _main._screens[0]
	overlay = _main._missions
	await _wait_settled()
	await _open()
	_c("yeniden başlatma: ALINDI kalıcı, Hamur aynı", overlay.card(&"daily_merges").status() == Missions.STATUS_CLAIMED
		and SaveManager.dough() == dough0 + 10)
	# h) Pencereler üst üste binmez.
	_main.open_daily_rewards()
	_main._on_chest_requested()
	await _settle(2)
	_c("GÖREVLER açıkken günlük pencere / sandık bilgisi açılmaz", not _main._daily_rewards.visible
		and not _main._chest_info.visible and overlay.visible)
	overlay.close_missions(false)
	await _wait_settled()
	_main.open_daily_rewards()
	await _settle(2)
	_main.open_missions()
	await _settle(2)
	_c("günlük pencere açıkken GÖREVLER açılmaz", _main._daily_rewards.visible and not overlay.visible)
	_main._daily_rewards.close_popup()
	await _wait_settled()

	# i) Pencere açıkken gece yarısı: dokunuş ödülü tam bir kez verir, pencere yeni güne tazelenir.
	SaveManager.data["missions"] = Missions.sanitize(_v2(TUE, {"daily_clear": 1}, [], {}, []))
	SaveManager.save_game()
	await _open()
	var night_cta: Button = overlay.card(&"daily_clear").claim_button()
	DailyRewards.clock_override = WED
	dough0 = SaveManager.dough()
	await _finger_tap(_screen_center(night_cta))
	await _settle(2)
	_c("gece yarısı açık pencere: dokunuş → AUTO_CLAIMED +10 (tam bir kez), pencere WED'e tazelendi (level kartı 0 / 1 AKTİF), geri bildirim",
		SaveManager.dough() == dough0 + 10 and overlay.card(&"daily_clear").status() == Missions.STATUS_ACTIVE
		and overlay.card(&"daily_clear").progress_text() == "0 / 1" and overlay.gain_feedback() != null
		and int(_disk().get("dough", -1)) == dough0 + 10)
	overlay.close_missions(false)
	await _wait_settled()
	# j) Öne dönüş (arka planda gün değişti): teslim + rozet / pencere tazelenir; otomatik günlük pencere bastırılır.
	SaveManager.data["missions"] = Missions.sanitize(_v2(WED, {"daily_merges": 15}, [], {}, []))
	SaveManager.save_game()
	await _open()
	DailyRewards.clock_override = THU
	DailyRewards.auto_popup_enabled = true
	var raw: Dictionary = (SaveManager.data.get("daily_rewards", {}) as Dictionary).duplicate()
	raw["popup_seen_day"] = ""
	SaveManager.data["daily_rewards"] = raw
	dough0 = SaveManager.dough()
	_main._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _settle(3)
	_c("öne dönüş (WED → THU, pencere açık): daily_merges teslim +10, pencere THU'ya tazelendi, günlük pencere ÜSTE açılmadı (due kaldı)",
		SaveManager.dough() == dough0 + 10 and overlay.card(&"daily_merges").status() == Missions.STATUS_ACTIVE
		and overlay.visible and not _main._daily_rewards.visible and DailyRewards.popup_due())
	overlay.close_missions(false)
	DailyRewards.auto_popup_enabled = false
	await _wait_settled()
	# k) Sekme geçişi bir dönem noktası.
	SaveManager.data["missions"] = Missions.sanitize(_v2(THU, {"daily_rounds": 2}, [], {}, []))
	SaveManager.save_game()
	_main._show_tab(1)
	await _settle(2)
	DailyRewards.clock_override = FRI
	dough0 = SaveManager.dough()
	_main._show_tab(0)
	await _settle(2)
	_c("sekme geçişi (Harita → Ana Sayfa, gün değişti): teslim +10, Ana Sayfa hapı güncel, rozet yeni gün (0/6)",
		SaveManager.dough() == dough0 + 10 and _pill_text(home) == str(dough0 + 10) and home.missions_count_text() == "0/6")
	# l) Round sürerken teslim yok — round kaydında tek yazmada.
	SaveManager.data["missions"] = Missions.sanitize(_v2(FRI, {"daily_clear": 1}, [], {}, []))
	SaveManager.save_game()
	_main._start_level(_level(2))
	await _settle(2)
	DailyRewards.clock_override = SAT
	dough0 = SaveManager.dough()
	_main._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _settle(2)
	_c("round sürerken öne dönüş (FRI → SAT): oyunda teslim YOK (Hamur aynı)", SaveManager.dough() == dough0
		and SaveManager.data["missions"]["day_key"] == FRI)
	for i in 2:
		GameState.register_merge(2, Vector2(360, 700))
	_main._board._finish(false)
	await _settle(2)
	var summary: Dictionary = _main._result.progress_summary().get("missions", {}) if _main._result.has_method("progress_summary") else {}
	_c("round bitişi: FRI'nin alınmamış level ödülü round kaydında TAM BİR KEZ teslim (+10), round SAT'a işlendi; diskte aynı",
		SaveManager.dough() >= dough0 + 10 and int(_disk().get("dough", -1)) == SaveManager.dough()
		and SaveManager.missions_state()["day_key"] == SAT and SaveManager.missions_state()["daily_progress"]["daily_merges"] == 2)
	await get_tree().create_timer(_main.RESULT_DELAY + 0.3).timeout
	await _settle(2)
	summary = _main._result.progress_summary().get("missions", {})
	_c("  … sonuç özeti: teslim [daily_clear] +10; tamamlanan yok → görev rozeti yok (teslim sonuçta Hamur gibi gösterilmez)",
		summary.get("auto_claimed", []) == [&"daily_clear"] and int(summary.get("dough", -1)) == 10
		and _main._result.progress_strip().mission_text() == "")
	_main._result.hide_result()
	_main.abandon_run()
	await _settle(2)
	DailyRewards.clock_override = ""
	await _teardown_main()
	_sections_done += 1


# --- 6) Ekonomi + kaynak sözleşmesi ---------------------------------------------------------------------

func _economy() -> void:
	print("-- ekonomi: günde ≤ 30, haftalık ≤ 120, haftada tam 330; çift yol yok")
	DailyRewards.clock_override = MON
	_reset_disk(Missions.fresh_state(MON))
	var start: int = SaveManager.dough()
	var days: Array[String] = [MON, TUE, WED, THU, FRI, SAT, SUN]
	var daily_ok: bool = true
	var paid_daily: int = 0
	for i in days.size():
		DailyRewards.clock_override = days[i]
		var day_start: int = SaveManager.dough()
		# Önceki günün teslimi bu günün ilk round kaydında gelir — günlük payı ayrı ölçülür.
		var first: Dictionary = SaveManager.record_mission_round(15, true)
		var delivered: int = int(first["dough"])
		SaveManager.record_mission_round(0, false)
		# Tek günler elle, çift günler dönem sonu teslimine bırakılır.
		var manual: int = 0
		if i % 2 == 0:
			for id in Missions.ids_for(DAILY):
				manual += int(SaveManager.claim_mission_reward(id, days[i])["claimed_dough"])
		if i % 2 == 0 and manual != 30:
			daily_ok = false
		paid_daily += manual
		var gained: int = SaveManager.dough() - day_start
		if gained - delivered > Missions.max_reward(DAILY):
			daily_ok = false
	# Haftalık: 120 merge (8 gün × 15 = 105 → pazar + 15 eksik) — 7 gün × 15 = 105 < 120: son gün ek 15 merge.
	SaveManager.record_mission_round(15, true)
	var week_state: Dictionary = SaveManager.missions_state()
	_c("ön koşul: haftalık üç görev de tamamlandı (merge 120, tur ≥ 12, level ≥ 5)", Missions.is_completed(week_state, &"weekly_merges")
		and Missions.is_completed(week_state, &"weekly_rounds") and Missions.is_completed(week_state, &"weekly_clears"))
	var weekly_manual: int = int(SaveManager.claim_mission_reward(&"weekly_rounds", MON)["claimed_dough"])
	DailyRewards.clock_override = NEXT_MON
	var monday: Dictionary = SaveManager.settle_missions()
	var total: int = SaveManager.dough() - start
	_c("bir hafta (pazartesi teslimi dahil): görev Hamur'u TAM 7·30 + 120 = 330 (elle %d günlük + %d haftalık; kalanı dönem sonu teslimi — 3 gün × 30 + 80)"
		% [paid_daily, weekly_manual], total == 330 and weekly_manual == 40
		and monday["auto_claimed"] == [&"weekly_merges", &"weekly_clears"] and int(monday["dough"]) == 80)
	_c("hiçbir gün görevlerden 30'dan fazla vermedi; haftalık toplam 120", daily_ok
		and Missions.max_reward(WEEKLY) == 120 and Missions.max_reward(DAILY) == 30)
	_c("pazartesiden sonra eski haftanın hiçbir ödülü yeniden alınamaz", int(SaveManager.claim_mission_reward(&"weekly_merges",
		MON)["dough"]) == 0 and (SaveManager.settle_missions()["auto_claimed"] as Array).is_empty()
		and SaveManager.dough() - start == 330)
	_c("ödüllü güç kotası sözleşmesi değişmedi (güç başına 2/gün)", RewardedPolicy.DAILY_GRANTS_PER_POWER == 2)

	var ad_tokens: Array[String] = ["MonetizationManager", "AdEvents", "AdBackend", "_ads", "show_rewarded",
		"try_show_interstitial", "_rewarded_provider", "set_surface", "AgeGate", "consent", "age_ad_band", "agesignals",
		"age_signals", "player_xp", "unlocked_achievements", "grant_powerup", "ChestSystem", "grant_skin"]
	var save_src: String = FileAccess.get_file_as_string("res://scripts/autoload/save_manager.gd")
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var hits: Array[String] = []
	for pair: Array in [["claim_mission_reward", _function(save_src, "func claim_mission_reward(")],
			["settle_missions", _function(save_src, "func settle_missions(")],
			["Main._on_mission_claim_requested", _function(main_src, "func _on_mission_claim_requested(")],
			["Main._settle_missions_period", _function(main_src, "func _settle_missions_period(")],
			["mission_card.gd", FileAccess.get_file_as_string("res://scripts/ui/mission_card.gd")],
			["missions_overlay.gd", FileAccess.get_file_as_string("res://scripts/ui/missions_overlay.gd")]]:
		if String(pair[1]).is_empty():
			hits.append("%s: bulunamadı" % pair[0])
		for token in ad_tokens:
			if _strip_comments(String(pair[1])).contains(token):
				hits.append("%s: %s" % [pair[0], token])
	_c("talep / dönem işlemi / kart / pencere: reklam / yaş / rıza / XP / başarım / güç / sandık / parça YOK %s" % str(hits),
		hits.is_empty())
	var claim_fn: String = _strip_comments(_function(save_src, "func claim_mission_reward("))
	_c("ödül miktarı katalogdan (Missions.claim / reward_of), UI'dan gelen miktar parametresi yok",
		claim_fn.contains("Missions.claim(") and claim_fn.contains("func claim_mission_reward(id: StringName, period_key: String)"))
	var card_src: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/mission_card.gd"))
	var overlay_src: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/missions_overlay.gd"))
	_c("UI ödül VERMEZ: kart / pencere SaveManager yazmaz ve talep çağırmaz (yalnız sinyal)", not card_src.contains("SaveManager.")
		and not overlay_src.contains("claim_mission_reward") and not overlay_src.contains("save_game")
		and not overlay_src.contains("SaveManager.data"))
	_c("Main: talep tek yerde (_on_mission_claim_requested), dönem noktası round sürerken atlanır",
		_strip_comments(main_src).count("SaveManager.claim_mission_reward(") == 1
		and _strip_comments(_function(main_src, "func _settle_missions_period(")).contains("_board"))
	DailyRewards.clock_override = ""
	_sections_done += 1


# --- Yardımcılar ------------------------------------------------------------------------------------------

func DEFAULT_MISSIONS() -> Dictionary:
	return {"version": 2, "day_key": "", "week_start_day_key": "", "daily_progress": {}, "daily_rewarded": [],
		"weekly_progress": {}, "weekly_rewarded": []}


func _raw(day: String, daily: Dictionary, daily_rewarded: Array, weekly: Dictionary, weekly_rewarded: Array,
		version: Variant) -> Dictionary:
	return {"version": version, "day_key": day, "week_start_day_key": Missions.week_start(day),
		"daily_progress": daily.duplicate(), "daily_rewarded": daily_rewarded.duplicate(),
		"weekly_progress": weekly.duplicate(), "weekly_rewarded": weekly_rewarded.duplicate()}


func _v1(day: String, daily: Dictionary, daily_rewarded: Array, weekly: Dictionary, weekly_rewarded: Array) -> Dictionary:
	return _raw(day, daily, daily_rewarded, weekly, weekly_rewarded, 1)


func _v2(day: String, daily: Dictionary, daily_rewarded: Array, weekly: Dictionary, weekly_rewarded: Array) -> Dictionary:
	return _raw(day, daily, daily_rewarded, weekly, weekly_rewarded, 2)


func _zero(state: Dictionary, period: StringName) -> bool:
	var progress: Dictionary = state.get(Missions.progress_key(period), {})
	for id in Missions.ids_for(period):
		if int(progress.get(String(id), -1)) != 0:
			return false
	return (state.get(Missions.rewarded_key(period), [0]) as Array).is_empty()


## Yerleşik oyuncu: onboarding tamam, bugünün giriş ödülü alınmış (gerçek sistem günü — `DailyReward.claim_if_new_day`
## saat kancasını kullanmaz), yaş ADULT.
func _fixture(extra: Dictionary) -> Dictionary:
	var out: Dictionary = {"highest_level_unlocked": 11, "level_stars": {"1": 3}, "endless_high_score": 0,
		"dough": BASE_DOUGH, "total_merges": 0, "merges_since_bonus_chest": 0, "unlocked_skins": [],
		"powerups": {"bomb": 1, "upgrade": 1, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "", "daily_streak": 3,
		"last_login_date": Time.get_date_string_from_system(), "age_ad_band": "ADULT", "next_age_transition_date": "",
		"player_meta_version": 1, "player_xp": 0, "total_rounds_played": 0, "highest_tier_created": 0}
	for key in extra:
		out[key] = extra[key]
	return out


## Diskte temiz bir kayıt (yalnız kanonik) + bellekte yükle.
func _reset_disk(missions: Dictionary) -> void:
	_clean()
	_write(PATH, _fixture({"missions": missions}))
	SaveManager.load_game()


## Yazma girişimi dedektörü: tek atımlık hata kurulu kalırsa hiçbir write_save çağrılmadı.
func _arm_detector() -> void:
	SaveFile.fault = SaveFile.Fault.TEMP_OPEN


func _no_write() -> bool:
	return SaveFile.fault == SaveFile.Fault.TEMP_OPEN


func _disarm() -> void:
	SaveFile.fault = SaveFile.Fault.NONE


## Görev dışı kayıt alanları (talep bunlara dokunmamalı).
func _side_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for key: String in SaveManager.data.keys():
		if key == "dough" or key == "missions":
			continue
		out[key] = SaveManager.data[key].duplicate(true) if (SaveManager.data[key] is Dictionary
			or SaveManager.data[key] is Array) else SaveManager.data[key]
	return out


func _boot() -> void:
	await _teardown_main()
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _settle(3)


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _settle(2)


func _show_home() -> void:
	_main._show_tab(1)
	await _settle(1)
	_main._show_tab(0)
	await _settle(2)


func _open() -> void:
	_main.open_missions()
	await get_tree().create_timer(UiMotion.MODAL_TIME + 0.12).timeout
	await _settle(1)
	await _wait_settled()


func _level(number: int) -> LevelData:
	for level in LevelLibrary.load_levels():
		if level.level_number == number:
			return level
	return null


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


## Main'in geçiş sonrası parmak yatışması geçene kadar GERÇEK süre bekler.
func _wait_settled() -> void:
	var settle_msec: int = int(_main_script.get_script_constant_map().get("TOUCH_SETTLE_MSEC", 300))
	await get_tree().create_timer(float(settle_msec) / 1000.0 + 0.12).timeout
	await get_tree().process_frame


func _resize(view: Vector2i) -> void:
	get_window().size = view
	await _settle(2)


## Tuval px → pencere px ölçeği (başsız pencere küçük olabilir).
func _scale() -> float:
	return get_viewport().get_screen_transform().get_scale().y


func _screen_center(control: Control) -> Vector2:
	return get_viewport().get_screen_transform() * control.get_global_rect().get_center()


func _touch(pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = pos
	touch.pressed = pressed
	return touch


func _finger(pos: Vector2, pressed: bool) -> void:
	Input.parse_input_event(_touch(pos, pressed))
	Input.flush_buffered_events()
	await get_tree().process_frame


func _finger_tap(pos: Vector2) -> void:
	await _finger(pos, true)
	await _finger(pos, false)


## Android ACTION_CANCEL: bırakış `canceled == true` (Godot'nun Android yolu gibi).
func _cancel(pos: Vector2) -> void:
	var cancel := _touch(pos, false)
	cancel.canceled = true
	Input.parse_input_event(cancel)
	Input.flush_buffered_events()
	await _settle(2)


## Basılı parmağı adım adım sürükler (ScreenDrag).
func _drag_to(from: Vector2, to: Vector2) -> void:
	var steps: int = 6
	var last: Vector2 = from
	for i in range(1, steps + 1):
		var pos: Vector2 = from.lerp(to, float(i) / float(steps))
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = pos
		drag.relative = pos - last
		Input.parse_input_event(drag)
		Input.flush_buffered_events()
		last = pos
		await get_tree().process_frame


func _hold_release(pos: Vector2, seconds: float) -> void:
	await _finger(pos, true)
	await get_tree().create_timer(seconds).timeout
	await _finger(pos, false)
	await _settle(2)


## Ana Sayfa Hamur hapının yazısı (kanonik bakiye gösterimi).
func _pill_text(home: CanvasLayer) -> String:
	return (home.dough_pill().get_meta(&"value_label") as Label).text


func _label_texts(root: Node) -> Array[String]:
	var out: Array[String] = []
	if root is Label:
		out.append((root as Label).text)
	for child in root.get_children():
		out.append_array(_label_texts(child))
	return out


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
