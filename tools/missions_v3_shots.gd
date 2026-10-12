extends Node
## TASK/061 — Günlük & Görevler V3 görsel inceleme çekimleri. Dev aracı — oyun çalışırken kullanılmaz. `--headless` İLE
## ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn`, deterministik görev durumları, sabit gün (`DailyRewards.clock_override`, Salı 2026-09-29). Kayıt
## yolu `user://qa_missions_v3_shots/`'a YÖNLENDİRİLİR (Main'in yazmaları — talep / dönem teslimi — sahibin kaydına
## gitmez); sahibin kayıt ailesi başta / sonda bayt bayt karşılaştırılır, çıkışta yol / bellek / saat geri alınır.
## Banner kipinde yuva yalnız bu araçta yarı saydam plakayla işaretlenir (masaüstünde gerçek banner çizilmez).
##
##   H  Ana Sayfa  01 hiç tamamlanan yok · 02 iki görev tamam, ödül alınmadı (dikkat 2) · 03 dört tamam, biri alınabilir
##                 (dikkat 1) · 04 altısı tamam + hepsi alındı (nane 6/6)
##   M  Pencere    05 hepsi AKTİF (0) · 06 kısmi · 07 günlük alınabilir · 08 haftalık alınabilir · 09 iki alınabilir ·
##                 10 elle talep sonrası ALINDI (+ 10b "+10" yükselişi anı) · 11 6/6 hepsi alındı · 12 karışık (günlük +
##                 haftalık, üç durum) · 15 gün dönümü sonrası (önceki günün ödülü teslim, yeni gün) · 16 pazartesi dönümü
##                 sonrası · 17 alt (kaydırılmış)
##   R  Sonuç      13 bir görev tamamlandı (ödül alınmadı — "ÖDÜLÜ AL" yönlendirmesi) · 14 birden fazla görev
##
## Kipler: varsayılan masaüstü (yuva yok) · `banner` (yuva 112) · `a36` (üst pay 61 + yuva 112) · `a36nb` (üst pay 61).
##   godot --resolution GxY --path . res://tools/missions_v3_shots.tscn -- <çıktı> [GxY] [banner|a36|a36nb] [only=H|M|R]
## Her karenin piksel boyutu doğrulanır: tutmazsa "BOYUT HATASI" ve çıkış 3 (5 PNG yazılamadı, 6 hiç kare, 4 --headless).

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SHOT_SIZE := Vector2i(720, 1280)
const A36_SAFE_TOP: float = 61.0
const A36_BANNER_DP: int = 64
const A36_DENSITY: float = 2.625
const DIR: String = "user://qa_missions_v3_shots"
const PATH: String = DIR + "/save.json"
const DAY: String = "2026-09-29"
const NEXT_DAY: String = "2026-09-30"
const SUNDAY: String = "2026-10-04"
const MONDAY: String = "2026-10-05"

var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _safe_top: float = -1.0
var _banner: bool = false
var _mode: String = ""
var _only: String = ""
var _main: Node2D
var _main_script: GDScript = load("res://scripts/main.gd")
var _saved_data: Dictionary = {}
var _owner_family: Dictionary = {}
var _shots: int = 0
var _size_errors: int = 0
var _png_errors: int = 0
var _finished: bool = false
var _redirected: bool = false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("HATA: --headless ile çalışmaz (ekran görüntüsü). Kayda dokunulmadı.")
		_finished = true
		get_tree().quit(4)
		return
	DailyRewards.auto_popup_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://missions_v3_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_size = _shot_size(args)
	for arg in args:
		var a: String = String(arg)
		match a:
			"a36":
				_safe_top = A36_SAFE_TOP
				_banner = true
				_mode = "_a36"
			"a36nb":
				_safe_top = A36_SAFE_TOP
				_mode = "_a36nb"
			"banner":
				_banner = true
				_mode = "_banner"
		if a.begins_with("only="):
			_only = a.trim_prefix("only=")
	DisplayServer.window_set_size(_size)
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.window_get_size() != _size:
		push_warning("pencere %s istendi, %s çalışıyor — `--resolution %dx%d` ile başlatın" % [
			str(_size), str(DisplayServer.window_get_size()), _size.x, _size.y])

	_saved_data = SaveManager.data.duplicate(true)
	_owner_family = _family_snapshot()
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	SaveManager.save_path = PATH
	_redirected = true
	DailyRewards.clock_override = DAY
	get_tree().create_timer(840.0).timeout.connect(func() -> void:
		if not _finished:
			print("HATA: bekçi — çekim 840 s'de bitmedi, SaveManager geri alındı")
			_finish(2))
	_write_fixture()
	SaveManager.load_game()

	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	fake.adaptive_height_dp = A36_BANNER_DP if _banner else 0
	# Yuva tuval px'te A36 ile aynı (112): 720 pencerede A36 yoğunluğu gerçek dışı 168 px üretirdi.
	fake.density_value = A36_DENSITY * float(_size.x) / 1080.0
	_main_script.ads_backend_override = fake
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_main_script.ads_backend_override = null
	if _banner:
		fake.complete_consent_update(true)
		fake.complete_init()
		await _settle()
	_apply_safe_top()
	_build_banner_overlay()
	print("SHOT-INFO size=%s mode=%s safe_top=%d banner_slot=%d" % [str(_size), _mode, int(_safe_top), int(UiKit.banner_slot())])

	if _wants("H"):
		await _home_states()
	if _wants("M"):
		await _overlay_states()
	if _wants("R"):
		await _result_states()

	print("SHOT-OWNER-SAVE %s" % ("byte-identical" if _family_snapshot() == _owner_family else "DIFFERS"))
	print("bitti -> %s (%d kare, %d boyut hatası, %d PNG hatası)" % [_out_dir, _shots, _size_errors, _png_errors])
	_finish(3 if _size_errors > 0 else (5 if _png_errors > 0 else (6 if _shots == 0 else 0)))


func _finish(code: int) -> void:
	if _finished:
		return
	_finished = true
	# Main ÖNCE gider: yol gerçek kayda döndükten sonra yarım kalmış bir akış (bekçi yolu) oraya yazamaz.
	if _main != null and is_instance_valid(_main):
		_main.free()
	_restore()
	get_tree().quit(code)


func _exit_tree() -> void:
	if _finished:
		return
	_finished = true
	print("HATA: çekim bitmeden ağaçtan çıkıldı — SaveManager geri alındı")
	_restore()


func _restore() -> void:
	if not _redirected:
		return
	DailyRewards.clock_override = ""
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


func _wants(group: String) -> bool:
	return _only.is_empty() or _only.contains(group)


# --- H: Ana Sayfa -----------------------------------------------------------------------------

func _home_states() -> void:
	_put_missions(_state(DAY, {}, [], {}, []))
	await _show_home("01_home_none_completed")
	_put_missions(_state(DAY, {"daily_merges": 15, "daily_clear": 1, "daily_rounds": 1}, [], {"weekly_merges": 48}, []))
	await _show_home("02_home_two_completed_unclaimed")
	_put_missions(_state(DAY, {"daily_merges": 15, "daily_rounds": 2, "daily_clear": 1}, ["daily_merges", "daily_rounds"],
		{"weekly_rounds": 12, "weekly_merges": 60}, ["weekly_rounds"]))
	await _show_home("03_home_claimable_badge")
	_put_missions(_all_claimed())
	await _show_home("04_home_all_claimed")


func _show_home(name: String) -> void:
	_main._show_tab(1)
	await get_tree().process_frame
	_main._show_tab(0)
	_apply_safe_top()
	await _settle()
	await _capture(name)


# --- M: Pencere -------------------------------------------------------------------------------

func _overlay_states() -> void:
	_put_missions(_state(DAY, {}, [], {}, []))
	await _show_overlay("05_missions_all_active")
	_put_missions(_state(DAY, {"daily_merges": 7, "daily_rounds": 1}, [], {"weekly_merges": 46, "weekly_rounds": 5, "weekly_clears": 2}, []))
	await _show_overlay("06_missions_partial")
	_put_missions(_state(DAY, {"daily_merges": 9, "daily_rounds": 1, "daily_clear": 1}, [], {"weekly_merges": 52, "weekly_rounds": 6,
		"weekly_clears": 3}, []))
	await _show_overlay("07_missions_daily_claimable")
	_put_missions(_state(DAY, {"daily_merges": 9, "daily_rounds": 1}, [], {"weekly_merges": 74, "weekly_rounds": 12, "weekly_clears": 3}, []))
	await _show_overlay("08_missions_weekly_claimable")
	_put_missions(_state(DAY, {"daily_merges": 15, "daily_rounds": 1, "daily_clear": 1}, [], {"weekly_merges": 74, "weekly_rounds": 8,
		"weekly_clears": 3}, []))
	await _show_overlay("09_missions_two_claimable", false)
	# 10: gerçek talep yolu (Main → SaveManager.claim_mission_reward) — "+10" yükselişi anı ve oturmuş ALINDI.
	_main._on_mission_claim_requested(&"daily_merges", DAY)
	await get_tree().create_timer(0.22).timeout
	await _capture("10b_missions_claim_feedback")
	await get_tree().create_timer(UiMotion.POP_TIME + 0.9).timeout
	await _capture("10_missions_after_claim")
	_main._missions.close_missions(false)
	await _settle()
	_put_missions(_all_claimed())
	await _show_overlay("11_missions_all_claimed")
	_put_missions(_state(DAY, {"daily_merges": 15, "daily_rounds": 2, "daily_clear": 0}, ["daily_merges"],
		{"weekly_merges": 120, "weekly_rounds": 9, "weekly_clears": 5}, ["weekly_clears"]))
	await _show_overlay("12_missions_mixed_states")
	# 15: gün dönümü — Salı'nın alınmamış iki günlük ödülü Çarşamba açılışında (öne dönüş) tam bir kez teslim edilir.
	_put_missions(_state(DAY, {"daily_merges": 15, "daily_rounds": 2, "daily_clear": 0}, [], {"weekly_merges": 88, "weekly_rounds": 7},
		[]))
	SaveManager.save_game()
	DailyRewards.clock_override = NEXT_DAY
	_main._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _settle()
	await _show_overlay("15_missions_after_day_rollover")
	# 16: pazartesi dönümü — pazar günü + haftanın alınmamış ödülleri teslim, iki dönem taze.
	DailyRewards.clock_override = SUNDAY
	_put_missions(_state(SUNDAY, {"daily_clear": 1}, [], {"weekly_merges": 120, "weekly_rounds": 12, "weekly_clears": 4},
		["weekly_rounds"]))
	SaveManager.save_game()
	DailyRewards.clock_override = MONDAY
	_main._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _settle()
	await _show_overlay("16_missions_after_monday_rollover")
	DailyRewards.clock_override = DAY
	_restore_day()
	_put_missions(_state(DAY, {"daily_merges": 15, "daily_rounds": 1}, [], {"weekly_merges": 120, "weekly_rounds": 9, "weekly_clears": 5},
		["weekly_clears"]))
	await _show_overlay("", false)
	var scroll: ScrollContainer = _main._missions.scroll()
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _settle()
	await _capture("17_missions_bottom")
	_main._missions.close_missions(false)
	await _settle()


func _show_overlay(name: String, close_after: bool = true) -> void:
	_main._show_tab(1)
	await get_tree().process_frame
	_main._show_tab(0)
	_apply_safe_top()
	await get_tree().process_frame
	_main.open_missions()
	await get_tree().create_timer(UiMotion.MODAL_TIME + 0.4).timeout
	await get_tree().process_frame
	if name.is_empty():
		return
	await _capture(name)
	if close_after:
		_main._missions.close_missions(false)
		await _settle()


# --- R: Sonuç ---------------------------------------------------------------------------------

func _result_states() -> void:
	_meta(PlayerProgression.total_xp_for_level(4) + 40, 40)
	_put_missions(_state(DAY, {}, [], {}, []))
	await _play_result("13_result_one_mission", 2, true, 6, "star3")
	_meta(PlayerProgression.total_xp_for_level(4) + 40, 40)
	_put_missions(_state(DAY, {"daily_merges": 14, "daily_rounds": 1}, [], {"weekly_merges": 119}, []))
	await _play_result("14_result_many_missions", 2, false, 2, "")


## Gerçek round: kur, merge kaydı, skor, bitir → Main'in gerçek kesinleştirmesi + sonuç (masaüstünde geçiş reklamı yok).
func _play_result(name: String, level_number: int, won: bool, merges: int, stars: String) -> void:
	_main._show_tab(0)
	await get_tree().process_frame
	var level: LevelData = _level(level_number)
	seed(4646)
	_main._start_level(level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in merges:
		GameState.register_merge(2 + (i % 3), Vector2(360, 700))
	GameState.add_score(level.star_3_threshold() if stars == "star3" else 10)
	_main._board._finish(won)
	await get_tree().create_timer(_main.RESULT_DELAY + 0.2).timeout
	var result: CanvasLayer = _main._result
	var waited: int = 0
	while (not result.is_reveal_done() or result.progress_strip().level_bar().is_animating()) and waited < 60 * 14:
		await get_tree().process_frame
		waited += 1
	await get_tree().create_timer(0.8).timeout
	await _capture(name)
	result.hide_result()
	_main.abandon_run()
	await get_tree().process_frame


# --- Kayıt durumları --------------------------------------------------------------------------

func _write_fixture() -> void:
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 2},
		"endless_high_score": 0, "dough": 335, "total_merges": 40, "merges_since_bonus_chest": 10,
		"unlocked_skins": ["common_01", "rare_02"], "profile_showcase": ["rare_02"],
		"powerups": {"bomb": 2, "upgrade": 1, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "", "daily_streak": 3,
		"last_login_date": Time.get_date_string_from_system(), "age_ad_band": "ADULT", "next_age_transition_date": "",
		"player_meta_version": 1, "player_xp": 400, "total_rounds_played": 12, "highest_tier_created": 5,
		"daily_rewards": {"day_key": DAY, "free_chest_claimed": false, "ad_chests_claimed": 0, "dough_ad_claimed": false,
			"popup_seen_day": DAY, "last_seen_day_key": DAY}}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(content, "\t"))
	file.close()


## Gün dönümü karelerinden sonra çekim günü Salı'ya döner (görülen en yeni gün de — yalnız bu araçta).
func _restore_day() -> void:
	SaveManager.data["daily_rewards"] = {"day_key": DAY, "free_chest_claimed": false, "ad_chests_claimed": 0,
		"dough_ad_claimed": false, "popup_seen_day": DAY, "last_seen_day_key": DAY}


func _meta(xp: int, merges: int) -> void:
	SaveManager.data["player_xp"] = xp
	SaveManager.data["total_merges"] = merges
	SaveManager.data["merges_since_bonus_chest"] = 0
	SaveManager.data["unlocked_achievements"] = []
	SaveManager.data["level_stars"] = {"1": 3, "2": 3, "3": 2}
	SaveManager.data["highest_level_unlocked"] = 5
	SaveManager.reconcile_achievements()


func _put_missions(state: Dictionary) -> void:
	SaveManager.data["missions"] = state


func _state(day: String, daily: Dictionary, daily_rewarded: Array, weekly: Dictionary, weekly_rewarded: Array) -> Dictionary:
	return Missions.sanitize({"version": Missions.VERSION, "day_key": day, "week_start_day_key": Missions.week_start(day),
		"daily_progress": daily, "daily_rewarded": daily_rewarded, "weekly_progress": weekly,
		"weekly_rewarded": weekly_rewarded})


func _all_claimed() -> Dictionary:
	return _state(DAY, {}, ["daily_merges", "daily_rounds", "daily_clear"], {},
		["weekly_merges", "weekly_rounds", "weekly_clears"])


func _level(number: int) -> LevelData:
	for level in LevelLibrary.load_levels():
		if level.level_number == number:
			return level
	return null


# --- Çekim ------------------------------------------------------------------------------------

func _apply_safe_top() -> void:
	if _safe_top < 0.0:
		return
	for screen in _main._screens:
		if screen.has_method("_layout_with_safe_top"):
			screen._layout_with_safe_top(_safe_top)
	_main._missions.layout_with_safe_top(_safe_top)
	if _main.has_method("global_nav"):
		_main.global_nav().relayout()


## Banner yuvası (yalnız bu araçta): yarı saydam plaka + etiket — içeriğin yuvaya göre konumu görünsün.
func _build_banner_overlay() -> void:
	var slot: float = UiKit.banner_slot()
	if slot <= 0.0:
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var view: Vector2 = get_viewport().get_visible_rect().size
	var rect := ColorRect.new()
	rect.color = Color(1.0, 1.0, 1.0, 0.16)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = Vector2(0.0, view.y - UiKit.safe_bottom(view) - slot)
	rect.size = Vector2(view.x, slot)
	layer.add_child(rect)
	var label := Label.new()
	label.text = "BANNER YUVASI %d px (yalnız çekim işareti)" % int(slot)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	label.add_theme_font_size_override("font_size", 20)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = rect.position
	label.size = rect.size
	layer.add_child(label)


func _settle() -> void:
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame


func _tag() -> String:
	return "%dx%d%s" % [_size.x, _size.y, _mode]


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var file: String = "%s_%s.png" % [name, _tag()]
	var err: int = img.save_png(_out_dir.path_join(file))
	_shots += 1
	if err != OK:
		_png_errors += 1
	if img.get_size() != _size:
		_size_errors += 1
		print("BOYUT HATASI: %s = %s, beklenen %s" % [file, str(img.get_size()), str(_size)])
	print(("kaydedildi : " if err == OK else "HATA       : "), file, " ", img.get_size())


func _shot_size(args: PackedStringArray) -> Vector2i:
	if args.size() < 2:
		return SHOT_SIZE
	var parts: PackedStringArray = args[1].split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return SHOT_SIZE
	return Vector2i(int(parts[0]), int(parts[1]))


func _family_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for p: String in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null
	return out


func _clean() -> void:
	for path in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
