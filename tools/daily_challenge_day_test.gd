extends Node
## TASK/047 — MEYDAN OKUMA monoton gün testi (gerçek Main, gerçek board). Headless.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_daily_challenge_day/` altındaki
## bir yola yönlendirilir, sonda geri alınır; gerçek kayıt ailesi başta / sonda karşılaştırılır.
##
##   godot --headless --audio-driver Dummy --path . res://tools/daily_challenge_day_test.tscn
##
## Sözleşme: meydan okuma bir günü KABUL ETTİKTEN sonra (Ana Sayfa girişi / pencere / BAŞLA / tekrar o
## günü gösterdi ya da başlattı) cihaz saati geri alınırsa meydan okuma daha eski bir günü GÖSTERMEZ ve
## BAŞLATMAZ. Kabul, GÜNLÜK ÖDÜLLER'in mevcut gözlem API'siyle (`DailyRewards.observe_day()` — yalnız
## ileri, yalnız `last_seen_day_key`) kayda işlenir; ayrı saat / yeni alan YOK.
##
## Bölümler:
##   açık oturum  D → (uygulama açık) saat D+1 → Ana Sayfa D+1'i gösterir → saat D'ye geri: meydan okuma,
##                tek gün gerçeği (DailyRewards.day_key / Missions.accepted_day) ve Ana Sayfa D+1'de kalır
##   BAŞLA        pencere D+1'de açıldı, BAŞLA'dan önce saat D'ye geri → BAŞLA D+1'i başlatır, asla D'yi değil
##   tekrar       D+1 denemesi, saat D'ye geri, kayıp → "Gün değişti" DEĞİL; TEKRAR DENE D+1'i başlatır
##   tamamlanma   D+1 tamamlandı, saat geri → D açılmaz, +20 yeniden kazanılamaz
##   soğuk açılış (ölçüm) meydan okuma D+1'i kabul etti → uygulama kapandı → saat D → yeni süreç D+1'de;
##                kontrol: D+1'i öne dönüş gözlemlediyse de aynı
##   ileri / bozuk saat ileri gün hâlâ açılır; geçersiz saat kayda yazılmaz
##   ortak sistem meydan okumanın gün kabulü giriş ödülü / seri / günlük pencere / görev ilerlemesi /
##                görev ödülü / görev dönemi / onboarding / Hamur'a dokunmaz — yalnız last_seen ileri
##   eşdeğerlik   meydan okumanın kabulü, mevcut öne dönüş gözleminin AYNISI: kayıt baytı ve ortak okumalar
##                (gün, ilk gün kilidi, pencere 'due', görev dönemi, giriş / seri / Hamur) saat ileri ve geri

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DUMPLING_VISUAL: GDScript = preload("res://scripts/game/dumpling_visual.gd")
const DIR: String = "user://qa_daily_challenge_day"
const PATH: String = DIR + "/save.json"
const SECTIONS: int = 8
const MON: String = "2026-09-28"
const THU: String = "2026-10-01"
const FRI: String = "2026-10-02"
const SAT: String = "2026-10-03"

var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _finished: bool = false
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _popup_flag_before: bool = true
var _main: Node2D
var _main_script: GDScript


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	_popup_flag_before = DailyRewards.auto_popup_enabled
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_main_script = load("res://scripts/main.gd")
	_owner_state = _owner_snapshot()
	_saved_data = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	SaveManager.save_path = PATH
	get_tree().create_timer(300.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 300 s'de bitmedi — SaveManager geri alındı")
			if _main != null and is_instance_valid(_main):
				_main.free()
			_teardown()
			get_tree().quit(2))
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame

	await _open_session_rollback()
	await _start_path()
	await _retry_path()
	await _completion()
	await _cold_recreation()
	await _forward_and_invalid()
	await _shared_non_regression()
	await _equivalence()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	print("-- kayıt")
	await _teardown_main()
	_teardown()
	_c("SaveManager gerçek yola döndü, test klasörü silindi, saat kancası boş, otomatik pencere bayrağı geri",
		SaveManager.save_path == SaveManager.SAVE_PATH and not DirAccess.dir_exists_absolute(DIR)
		and DailyRewards.clock_override == "" and DailyRewards.auto_popup_enabled == _popup_flag_before)
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
	DailyRewards.auto_popup_enabled = _popup_flag_before
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	UiKit.set_banner_slot(0.0)
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- 1) Açık oturum: D → D+1 kabul → saat D'ye geri ------------------------------------------------

func _open_session_rollback() -> void:
	print("-- açık oturum: meydan okuma D+1'i kabul etti, saat D'ye geri alındı")
	await _fresh(THU)
	var home: CanvasLayer = _main._screens[0]
	_c("ön koşul: perşembe (D) — Ana Sayfa T5 portresi, gün gerçeği D", DailyChallenge.current_day() == THU
		and home.challenge_portrait_texture() == DUMPLING_VISUAL.TEXTURES[4] and DailyRewards.day_key() == THU)
	# Uygulama açık kalır; saat gece yarısını geçer (D+1). Ana Sayfa girişini tazeleyen olağan geçiş.
	DailyRewards.clock_override = FRI
	await _home_transition()
	_c("saat D+1: Ana Sayfa D+1'i gösteriyor (cuma T6 portresi, '+20') — meydan okuma D+1'i kabul etti",
		home.challenge_portrait_texture() == DUMPLING_VISUAL.TEXTURES[5] and home.challenge_badge_text() == "+20"
		and DailyChallenge.current_day() == FRI)
	print("    ölçüm (geri almadan önce): last_seen_day_key='%s'" % SaveManager.daily_last_seen_day_key())
	DailyRewards.clock_override = THU
	var day_after: String = DailyChallenge.current_day()
	print("    ölçüm (saat D'ye geri): DailyChallenge.current_day()='%s' DailyRewards.day_key()='%s' Missions.accepted_day()='%s' last_seen='%s'"
		% [day_after, DailyRewards.day_key(), Missions.accepted_day(), SaveManager.daily_last_seen_day_key()])
	_c("saat D'ye geri alındı: meydan okuma günü D+1'de KALIR (geri gitmez)", day_after == FRI)
	_c("  … tek gün gerçeği de D+1: DailyRewards.day_key() ve Missions.accepted_day() geri gitmez",
		DailyRewards.day_key() == FRI and Missions.accepted_day() == FRI)
	var view: Dictionary = DailyChallenge.current_view()
	_c("  … görünüm D+1'in preset'i (cuma T6·540·36), D'nin (perşembe T5·420·15) değil",
		String(view.get("day_key", "")) == FRI and int(view.get("drop_budget", 0)) == 36)
	await _home_transition()
	_c("Ana Sayfa yeniden tazelendi: giriş D+1'de kalır (T6 portresi, '+20') — D'yi yeniden göstermez",
		home.challenge_portrait_texture() == DUMPLING_VISUAL.TEXTURES[5] and home.challenge_badge_text() == "+20")
	_sections_done += 1


# --- 2) BAŞLA: pencere D+1'de açıldı, saat BAŞLA'dan önce geri ---------------------------------------

func _start_path() -> void:
	print("-- BAŞLA: pencere D+1'de açık, saat D'ye geri, sonra BAŞLA")
	await _fresh(THU)
	DailyRewards.clock_override = FRI
	_main.open_daily_challenge()
	await _settle(3)
	var sheet: DailyChallengeOverlay = _main._challenge_sheet
	_c("ön koşul: pencere D+1'i gösteriyor ('Dev Dumpling yap · 36 hamlede')", sheet.visible
		and sheet.shown_day() == FRI and sheet.goal_text() == "Dev Dumpling yap · 36 hamlede")
	DailyRewards.clock_override = THU
	sheet.start_button().pressed.emit()
	await _settle(3)
	print("    ölçüm: board=%s challenge_day='%s' sheet_visible=%s sheet_day='%s'" % [str(_main._board != null),
		_main._challenge_day, str(sheet.visible), sheet.shown_day()])
	_c("BAŞLA (saat D'deyken) D+1'in meydan okumasını başlattı (bütçe 36), D'yi DEĞİL",
		_main._board != null and _main._board.is_daily_challenge() and _main._challenge_day == FRI
		and _main._board.drop_budget() == 36)
	_c("  … pencere D'ye tazelenmedi (D'yi göstermez)", not sheet.visible or sheet.shown_day() == FRI)
	_sections_done += 1


# --- 3) Tekrar: D+1 denemesi, saat geri, kayıp -----------------------------------------------------------

func _retry_path() -> void:
	print("-- tekrar: D+1 denemesi, saat D'ye geri, kayıp, TEKRAR DENE")
	await _fresh(THU)
	DailyRewards.clock_override = FRI
	_c("ön koşul: D+1 denemesi başladı (cuma T6·540·36)", _main.start_daily_challenge() and _main._challenge_day == FRI)
	await _settle(3)
	var attempt: int = _main._challenge_attempt
	DailyRewards.clock_override = THU
	await _pile_kings()
	await _until_finished(900)
	await _wait_result()
	var result: CanvasLayer = _main._result
	print("    ölçüm: sonuç gövdesi='%s' birincil='%s'" % [result.challenge_body_text(), result.primary_text()])
	_c("kayıp sonucu 'Gün değişti' DEMEZ (gün geri gitmedi): 'Kap taştı. Sıra aynı, tekrar dene!' + TEKRAR DENE",
		result.visible and result.challenge_body_text() == "Kap taştı. Sıra aynı, tekrar dene!"
		and result.primary_text() == "TEKRAR DENE")
	_main._on_retry_pressed()
	await _settle(3)
	print("    ölçüm: tekrar sonrası challenge_day='%s' deneme %d → %d" % [_main._challenge_day, attempt,
		_main._challenge_attempt])
	_c("TEKRAR DENE D+1'i baştan başlattı (yeni deneme, bütçe 36), D'yi DEĞİL", _main._challenge_day == FRI
		and _main._challenge_attempt == attempt + 1 and _main._board != null and _main._board.drop_budget() == 36
		and _main._board.drops_used() == 0)
	_sections_done += 1


# --- 4) Tamamlanma: D+1 tamamlandı, saat geri ----------------------------------------------------------

func _completion() -> void:
	print("-- tamamlanma: D+1 tamamlandı, saat D'ye geri")
	await _fresh(THU)
	DailyRewards.clock_override = FRI
	_main.start_daily_challenge()
	await _settle(3)
	await _win()
	await _wait_result()
	_c("ön koşul: D+1 tamamlandı, +20 (335 → 355)", SaveManager.daily_challenge_completed_day() == FRI
		and SaveManager.dough() == 355)
	_main._on_exit_pressed()
	await _settle(3)
	DailyRewards.clock_override = THU
	var view: Dictionary = DailyChallenge.current_view()
	_c("saat geri: D açılmaz — görünüm D+1, tamamlandı", String(view.get("day_key", "")) == FRI
		and bool(view.get("completed", false)))
	_c("  … başlatma REDDEDİLİR, +20 yeniden kazanılamaz (D için de, D+1 için de)", not _main.start_daily_challenge()
		and not SaveManager.complete_daily_challenge(THU) and not SaveManager.complete_daily_challenge(FRI)
		and SaveManager.dough() == 355)
	await _home_transition()
	_c("  … Ana Sayfa: tik (tamamlandı), '+20' yok", _main._screens[0].is_challenge_done_shown()
		and _main._screens[0].challenge_badge_text() == "")
	_sections_done += 1


# --- 5) Soğuk açılış (ölçüm) ---------------------------------------------------------------------------

func _cold_recreation() -> void:
	print("-- soğuk açılış: meydan okuma D+1'i kabul etti → uygulama kapandı → saat D → yeni süreç")
	await _fresh(THU)
	DailyRewards.clock_override = FRI
	_main.open_daily_challenge()
	await _settle(2)
	_main._challenge_sheet.start_button().pressed.emit()
	await _settle(3)
	_c("ön koşul: D+1 denemesi pencere + BAŞLA ile başladı (kabul)", _main._board != null and _main._challenge_day == FRI)
	_main.open_pause_menu()
	await _settle(1)
	_main.abandon_run()
	await _settle(2)
	await _teardown_main()
	var disk_seen: String = String((_disk().get("daily_rewards", {}) as Dictionary).get("last_seen_day_key", ""))
	DailyRewards.clock_override = THU
	SaveManager.load_game()
	await _boot()
	print("    ölçüm: diskteki last_seen='%s' → yeni süreçte (saat D) current_day='%s' day_key='%s'"
		% [disk_seen, DailyChallenge.current_day(), DailyRewards.day_key()])
	_c("yeni süreç (saat D): meydan okuma D+1'de kalır — kabul kalıcı (diskteki last_seen D+1)",
		disk_seen == FRI and DailyChallenge.current_day() == FRI and DailyRewards.day_key() == FRI)
	await _home_transition()
	_c("  … Ana Sayfa girişi D+1 (T6 portresi)", _main._screens[0].challenge_portrait_texture() == DUMPLING_VISUAL.TEXTURES[5])
	# Kontrol: D+1'i öne dönüş gözlemlediyse (mevcut yol) soğuk açılış zaten monoton.
	await _fresh(THU)
	DailyRewards.clock_override = FRI
	_main._notification(NOTIFICATION_APPLICATION_RESUMED)
	await _settle(2)
	await _teardown_main()
	DailyRewards.clock_override = THU
	SaveManager.load_game()
	await _boot()
	print("    ölçüm (kontrol, öne dönüş gözlemi): current_day='%s'" % DailyChallenge.current_day())
	_c("kontrol: öne dönüşün kaydettiği D+1 soğuk açılışta da korunur (mevcut taban)", DailyChallenge.current_day() == FRI)
	_sections_done += 1


# --- 6) İleri gün / bozuk saat ---------------------------------------------------------------------------

func _forward_and_invalid() -> void:
	print("-- ileri gün hâlâ açılır; geçersiz saat kayda yazılmaz")
	await _fresh(THU)
	DailyRewards.clock_override = FRI
	await _home_transition()
	DailyRewards.clock_override = SAT
	await _home_transition()
	_c("saat ileri (D+2): yeni gün açılır (cumartesi T6·480·32)", DailyChallenge.current_day() == SAT
		and int(DailyChallenge.current_view()["drop_budget"]) == 32)
	var seen: String = SaveManager.daily_last_seen_day_key()
	DailyRewards.clock_override = "bozuk-saat"
	DailyChallenge.current_view()
	await _home_transition()
	_c("geçersiz saat: last_seen bozulmaz (görülen en yeni gün aynen '%s')" % seen,
		SaveManager.daily_last_seen_day_key() == seen)
	DailyRewards.clock_override = THU
	_sections_done += 1


# --- 7) Ortak sistemler -----------------------------------------------------------------------------------

func _shared_non_regression() -> void:
	print("-- ortak sistemler: gün kabulü ödül / seri / pencere / görev / onboarding / Hamur'a dokunmaz")
	await _fresh(THU)
	DailyRewards.auto_popup_enabled = true
	var before: Dictionary = SaveManager.data.duplicate(true)
	var daily_before: Dictionary = (before["daily_rewards"] as Dictionary).duplicate()
	var missions_stored: String = JSON.stringify(_norm(before["missions"]))
	# Saat D+1 (uygulama açık). Meydan okumanın gün kabul yolları — sekme geçişi YOK (o, günlük pencereyi
	# mevcut kuralla açabilir; bu bölüm yalnız meydan okuma yolunu ölçer).
	DailyRewards.clock_override = FRI
	_main._screens[0].refresh_daily_challenge()
	_main.open_daily_challenge()
	await _settle(2)
	_c("meydan okuma penceresi D+1'de açıldı; günlük pencere AÇILMADI", _main._challenge_sheet.visible
		and _main._challenge_sheet.shown_day() == FRI and not _main._daily_rewards.visible)
	_main._challenge_sheet.start_button().pressed.emit()
	await _settle(3)
	_c("BAŞLA → D+1 board'u; günlük pencere AÇILMADI", _main._board != null and _main._challenge_day == FRI
		and not _main._daily_rewards.visible)
	await _pile_kings()
	await _until_finished(900)
	await _wait_result()
	var after: Dictionary = SaveManager.data.duplicate(true)
	var diff: Array[String] = _diff_keys(before, after)
	_c("kayıtta değişen YALNIZ daily_rewards (değişen: %s)" % str(diff), diff.is_empty() or _same(diff, ["daily_rewards"]))
	var daily_after: Dictionary = after["daily_rewards"]
	var daily_diff: Array[String] = _diff_keys(daily_before, daily_after)
	_c("  … daily_rewards içinde değişen YALNIZ last_seen_day_key (değişen: %s)" % str(daily_diff),
		daily_diff.is_empty() or _same(daily_diff, ["last_seen_day_key"]))
	_c("  … günlük kotalar / pencere işareti aynen (ücretsiz sandık, reklamlı sandık, Hamur reklamı, popup_seen)",
		String(daily_after["day_key"]) == String(daily_before["day_key"])
		and bool(daily_after["free_chest_claimed"]) == bool(daily_before["free_chest_claimed"])
		and int(daily_after["ad_chests_claimed"]) == int(daily_before["ad_chests_claimed"])
		and bool(daily_after["dough_ad_claimed"]) == bool(daily_before["dough_ad_claimed"])
		and String(daily_after["popup_seen_day"]) == String(daily_before["popup_seen_day"]))
	_c("  … giriş ödülü VERİLMEDİ, seri aynen (last_login aynı, seri 3), Hamur 335",
		String(after["last_login_date"]) == String(before["last_login_date"]) and int(after["daily_streak"]) == 3 and SaveManager.dough() == 335)
	_c("  … görev bloğu aynen (sayaç ilerlemedi, görev ödülü yok)", JSON.stringify(_norm(after["missions"])) == missions_stored)
	_c("  … onboarding alanları aynen", bool(after["onboarding_completed"]) == bool(before["onboarding_completed"])
		and String(after["onboarding_completed_day"]) == String(before["onboarding_completed_day"]))
	var disk: Dictionary = _disk()
	_c("  … diskte de görev / giriş / seri / Hamur / onboarding aynen",
		JSON.stringify(_norm(disk.get("missions"))) == missions_stored and String(disk.get("last_login_date", "")) == String(before["last_login_date"])
		and int(_norm(disk.get("daily_streak", 0))) == 3 and int(_norm(disk.get("dough", 0))) == 335
		and bool(disk.get("onboarding_completed", false)))
	# Saat geri: görev dönemi geri gitmez (D'nin ilerlemesi yeniden açılmaz), görev sayacı ilerlemez.
	DailyRewards.clock_override = THU
	var mstate: Dictionary = SaveManager.missions_state()
	print("    ölçüm (saat geri): görev dönemi='%s' kayıtlı dönem='%s'" % [String(mstate.get("day_key", "")),
		String((after["missions"] as Dictionary).get("day_key", ""))])
	_c("saat geri: görev dönemi D'ye dönmez (dönem D+1 ya da kayıtlı dönem — asla daha eski)",
		String(mstate.get("day_key", "")) >= String((before["missions"] as Dictionary).get("day_key", ""))
		and String(mstate.get("day_key", "")) != "" and JSON.stringify(_norm(SaveManager.data["missions"])) == missions_stored)
	_main._on_exit_pressed()
	await _settle(3)
	DailyRewards.auto_popup_enabled = false
	_sections_done += 1


# --- 8) Eşdeğerlik: meydan okumanın gün kabulü = mevcut öne dönüş gözlemi -----------------------------------

func _equivalence() -> void:
	print("-- eşdeğerlik: meydan okumanın gün kabulü, mevcut öne dönüş gözleminin AYNISI (ortak sistemler)")
	# Tutorial perşembe bitti (ilk gün kuralı perşembe kilitli), uygulama açık, saat cuma.
	var extra: Dictionary = {"onboarding_completed_day": THU, "last_login_date": THU}
	# a) Meydan okuma yolu: Ana Sayfa girişi cumayı gösterir (kabul).
	await _fresh(THU, extra)
	DailyRewards.clock_override = FRI
	_main._screens[0].refresh_daily_challenge()
	await _settle(1)
	var by_challenge: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var a: Dictionary = _shared_reading(FRI)
	DailyRewards.clock_override = THU
	var a_back: Dictionary = _shared_reading(THU)
	# b) Mevcut yol: öne dönüş (Main.NOTIFICATION_APPLICATION_RESUMED → DailyRewards.observe_day()).
	await _fresh(THU, extra)
	DailyRewards.clock_override = FRI
	_main._notification(NOTIFICATION_APPLICATION_RESUMED)
	await _settle(1)
	var by_resume: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var b: Dictionary = _shared_reading(FRI)
	DailyRewards.clock_override = THU
	var b_back: Dictionary = _shared_reading(THU)
	print("    ölçüm: meydan okuma kabulü %s | öne dönüş %s" % [str(a_back), str(b_back)])
	_c("kayıt dosyası BAYT-AYNI: meydan okumanın kabulü, öne dönüşün yazdığının aynısını yazar", by_challenge == by_resume
		and not by_challenge.is_empty())
	_c("saat cuma: ortak okumalar (gün, kilit, pencere 'due', görev dönemi, giriş durumu, Hamur) aynı", a == b)
	_c("saat perşembeye geri: ortak okumalar yine aynı (meydan okuma kabulü yeni ödül / ilerleme kuralı getirmez)",
		a_back == b_back)
	await _teardown_main()
	_sections_done += 1


## Ortak sistemlerin gün gerçeğinden okudukları (yalnız okur).
func _shared_reading(label: String) -> Dictionary:
	return {"label": label, "day_key": DailyRewards.day_key(), "accepted": Missions.accepted_day(),
		"clock_behind": DailyRewards.is_clock_behind(), "unlocked": Onboarding.daily_rewards_unlocked(),
		"popup_due_if_enabled": SaveManager.daily_popup_seen_day() != DailyRewards.day_key(),
		"missions_period": String(SaveManager.missions_state().get("day_key", "")),
		"missions_raw": JSON.stringify(_norm(SaveManager.data.get("missions"))),
		"last_login": SaveManager.last_login_date(), "streak": SaveManager.daily_streak(), "dough": SaveManager.dough(),
		"challenge_day": DailyChallenge.current_day()}


# --- Yardımcılar ------------------------------------------------------------------------------------------

func _fixture(extra: Dictionary = {}) -> Dictionary:
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 2},
		"endless_high_score": 0, "dough": 335, "total_merges": 40, "merges_since_bonus_chest": 10,
		"unlocked_skins": ["common_01", "rare_02"], "profile_showcase": ["rare_02"],
		"powerups": {"bomb": 2, "upgrade": 1, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "", "daily_streak": 3,
		"last_login_date": Time.get_date_string_from_system(), "age_ad_band": "ADULT", "next_age_transition_date": "",
		"player_meta_version": 1, "player_xp": 400, "total_rounds_played": 12, "highest_tier_created": 4,
		"unlocked_achievements": ["merge_10"],
		"daily_rewards": {"day_key": THU, "free_chest_claimed": true, "ad_chests_claimed": 2,
			"dough_ad_claimed": true, "popup_seen_day": THU, "last_seen_day_key": THU},
		"missions": {"version": 1, "day_key": THU, "week_start_day_key": MON,
			"daily_progress": {"daily_merges": 5, "daily_rounds": 1, "daily_clear": 0}, "daily_rewarded": [],
			"weekly_progress": {"weekly_merges": 30, "weekly_rounds": 4, "weekly_clears": 2}, "weekly_rewarded": []}}
	for key: String in extra:
		content[key] = extra[key]
	return content


func _write_fixture(extra: Dictionary = {}) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(_fixture(extra), "\t"))
	file.close()


## Temiz kayıt (saat `day`, görülen en yeni gün perşembe) + Main.
func _fresh(day: String, extra: Dictionary = {}) -> void:
	await _teardown_main()
	_clean()
	DailyRewards.clock_override = day
	_write_fixture(extra)
	SaveManager.load_game()
	await _boot()


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


## Ana Sayfa'yı tazeleyen olağan geçiş (Harita → Ana Sayfa).
func _home_transition() -> void:
	_main._show_tab(1)
	await _settle(1)
	_main._show_tab(0)
	await _settle(2)


## Gerçek merge ile hedef: sağ kenarda tabandaki (hedef − 1) tier parçasının üstüne aynısı düşer.
func _win() -> void:
	var board: Node2D = _main._board
	var tier: int = board.level.target_tier - 1
	var r: float = TierConfig.radius(tier)
	var floor_y: float = float(board.get_script().get_script_constant_map()["FLOOR_Y"])
	var x: float = board._right_x() - r - 12.0
	board._spawn_dumpling(tier, Vector2(x, floor_y - r - 1.0))
	board._spawn_dumpling(tier, Vector2(x, floor_y - 3.0 * r - 30.0))
	var guard: int = 0
	while not board.is_finished() and guard < 400:
		await get_tree().physics_frame
		guard += 1


## Tier 8 ızgarası (level modunda birleşmez): 400'lük alan kesin taşar.
func _pile_kings() -> void:
	var board: Node2D = _main._board
	var left: float = board._left_x()
	var width: float = board.level.container_width
	var floor_y: float = float(board.get_script().get_script_constant_map()["FLOOR_Y"])
	for row in 3:
		for column in 2:
			board._spawn_dumpling(8, Vector2(left + width * (0.25 if column == 0 else 0.75),
				floor_y - 101.0 - 205.0 * float(row)))
	await _physics(4)


func _until_finished(max_frames: int) -> void:
	var guard: int = 0
	while _main._board != null and is_instance_valid(_main._board) and not _main._board.is_finished() \
			and guard < max_frames:
		await get_tree().physics_frame
		guard += 1


func _wait_result(extra: float = 0.25) -> void:
	var delay: float = float(_main_script.get_script_constant_map()["RESULT_DELAY"])
	await get_tree().create_timer(delay + extra).timeout
	await _settle(2)


func _diff_keys(a: Dictionary, b: Dictionary) -> Array[String]:
	var keys: Dictionary = {}
	for key: Variant in a:
		keys[str(key)] = true
	for key: Variant in b:
		keys[str(key)] = true
	var out: Array[String] = []
	for key: String in keys:
		if JSON.stringify(_norm(a.get(key))) != JSON.stringify(_norm(b.get(key))):
			out.append(key)
	out.sort()
	return out


## JSON sayı normalizasyonu: tam değerli float → int (bellek int, disk float okunur).
func _norm(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number: float = value
			return int(number) if is_equal_approx(number, roundf(number)) else number
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key: Variant in value:
				out[str(key)] = _norm(value[key])
			return out
		TYPE_ARRAY:
			var items: Array = []
			for item: Variant in value:
				items.append(_norm(item))
			return items
	return value


func _disk() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if parsed is Dictionary else {}


func _same(a: Array, b: Array) -> bool:
	return str(a) == str(b)


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _clean() -> void:
	for path in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for path in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out
