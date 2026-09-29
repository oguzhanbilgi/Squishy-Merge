extends Node
## Günlük / Haftalık Görevler QA çekimleri (TASK/046). Dev aracı — oyun çalışırken kullanılmaz.
## `--headless` İLE ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn`, deterministik görev durumları, sabit gün (`DailyRewards.clock_override`).
## SAHİBİN KAYDINA DOKUNMAZ: SaveManager çekim boyunca `user://qa_missions_shots/` altındaki bir
## yola yönlendirilir (TASK/045.1 test dikişi), çıkışta gerçek yola ve belleğe geri döner, test
## dosyaları silinir.
##
##   H  Ana Sayfa  01 GÖREVLER 0/6 · 02 3/6 (günlükler tamam) · 03 6/6 (nane rozet)
##   M  Pencere    04 ilerleme yok · 05 kısmi · 06 bir görev tamam · 07 günlükler tamam ·
##                 08 altısı tamam · 09 uzun metin provası (kırpma) · 10 alt (kaydırılmış)
##   R  Sonuç      11 bir günlük (+10) · 12 bir haftalık (+40) · 13 günlük + haftalık (+50) ·
##                 14 görev + seviye atlama + başarım birlikte
##
## Kullanım:
##   godot --resolution GxY --path . res://tools/missions_shots.tscn -- <çıktı> [GxY] [safe=61] [only=H|M|R]
## Her karenin piksel boyutu DOĞRULANIR; tutmazsa "BOYUT HATASI" ve çıkış kodu 3 (5 PNG
## yazılamadı, 6 hiç kare yok, 4 `--headless`).

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SHOT_SIZE := Vector2i(720, 1280)
const DIR: String = "user://qa_missions_shots"
const PATH: String = DIR + "/save.json"
const DAY: String = "2026-09-29"

var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _main: Node2D
var _saved_data: Dictionary = {}
var _safe_top: float = -1.0
var _only: String = ""
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
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://missions_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_size = _shot_size(args)
	for arg in args:
		if String(arg).begins_with("safe="):
			_safe_top = float(String(arg).trim_prefix("safe="))
		if String(arg).begins_with("only="):
			_only = String(arg).trim_prefix("only=")
	DisplayServer.window_set_size(_size)
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.window_get_size() != _size:
		push_warning("pencere %s istendi, %s çalışıyor — `--resolution %dx%d` ile başlatın" % [
			str(_size), str(DisplayServer.window_get_size()), _size.x, _size.y])

	_saved_data = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	SaveManager.save_path = PATH
	_redirected = true
	DailyRewards.clock_override = DAY
	# Bekçi dış koşucunun süre sınırından (run_shots.sh 900 s) KISA: takılırsa önce kendi test
	# dosyalarını silip SaveManager'ı geri alır. (Masaüstü ekranı uyurken çizim yavaşlar.)
	get_tree().create_timer(840.0).timeout.connect(func() -> void:
		if not _finished:
			print("HATA: bekçi — çekim 840 s'de bitmedi, SaveManager geri alındı")
			_finish(2))
	_write_fixture()
	SaveManager.load_game()

	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	if _safe_top >= 0.0:
		_main._screens[0]._layout_with_safe_top(_safe_top)
		_main._missions.layout_with_safe_top(_safe_top)

	if _wants("H"):
		await _home_states()
	if _wants("M"):
		await _overlay_states()
	if _wants("R"):
		await _result_states()

	print("bitti -> %s (%d kare, %d boyut hatası, %d PNG hatası)" % [_out_dir, _shots, _size_errors, _png_errors])
	if _shots == 0:
		print("HATA: hiç kare çekilmedi (only=%s geçersiz mi?)" % _only)
	_finish(3 if _size_errors > 0 else (5 if _png_errors > 0 else (6 if _shots == 0 else 0)))


func _finish(code: int) -> void:
	if _finished:
		return
	_finished = true
	# Main ÖNCE gider: yol gerçek kayda döndükten sonra yarım kalmış bir akış (bekçi yolu) oraya
	# yazamaz.
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


# --- H: Ana Sayfa ----------------------------------------------------------------------------

func _home_states() -> void:
	_missions(_raw({}, [], {}, []))
	await _show_home("01_home_missions_0of6")
	_missions(_raw({"daily_merges": 15, "daily_rounds": 2, "daily_clear": 1}, ["daily_merges", "daily_rounds", "daily_clear"],
		{"weekly_merges": 48, "weekly_rounds": 5, "weekly_clears": 2}, []))
	await _show_home("02_home_missions_3of6")
	_missions(_all_done())
	await _show_home("03_home_missions_6of6")


func _show_home(name: String) -> void:
	_main._show_tab(1)
	await get_tree().process_frame
	_main._show_tab(0)
	await _settle()
	await _capture(name)


# --- M: Pencere ------------------------------------------------------------------------------

func _overlay_states() -> void:
	_missions(_raw({}, [], {}, []))
	await _show_overlay("04_missions_zero")
	_missions(_raw({"daily_merges": 7, "daily_rounds": 1}, [], {"weekly_merges": 46, "weekly_rounds": 5, "weekly_clears": 2}, []))
	await _show_overlay("05_missions_partial")
	_missions(_raw({"daily_merges": 9, "daily_rounds": 1, "daily_clear": 1}, ["daily_clear"],
		{"weekly_merges": 52, "weekly_rounds": 6, "weekly_clears": 3}, []))
	await _show_overlay("06_missions_one_complete")
	_missions(_raw({"daily_merges": 15, "daily_rounds": 2, "daily_clear": 1}, ["daily_merges", "daily_rounds", "daily_clear"],
		{"weekly_merges": 88, "weekly_rounds": 9, "weekly_clears": 4}, []))
	await _show_overlay("07_missions_daily_complete")
	_missions(_all_done())
	await _show_overlay("08_missions_all_complete")
	# Uzun metin provası (görsel): kart başlığı tek satır, üç noktayla kırpılır — kart taşmaz.
	_missions(_raw({"daily_merges": 7}, [], {}, []))
	await _show_overlay("", false)
	for card in _main._missions.cards():
		card.title_label().text = "Çok uzun bir görev metni: birleşme, tur ve level görevlerini birlikte tamamla"
	await _settle()
	await _capture("09_missions_long_text")
	_main._missions.close_missions(false)
	_missions(_raw({"daily_merges": 7, "daily_rounds": 1}, [], {"weekly_merges": 46, "weekly_rounds": 5, "weekly_clears": 2}, []))
	await _show_overlay("", false)
	var scroll: ScrollContainer = _main._missions.scroll()
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _settle()
	await _capture("10_missions_bottom")
	_main._missions.close_missions(false)
	await _settle()


func _show_overlay(name: String, close_after: bool = true) -> void:
	_main._show_tab(0)
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


# --- R: Sonuç ----------------------------------------------------------------------------------

func _result_states() -> void:
	_meta(PlayerProgression.total_xp_for_level(4) + 40, 40)
	_missions(_raw({}, [], {}, []))
	await _play_result("11_result_one_daily", 2, true, 6, "star3")
	_meta(PlayerProgression.total_xp_for_level(4) + 40, 40)
	_missions(_raw({"daily_merges": 15, "daily_rounds": 2, "daily_clear": 1}, ["daily_merges", "daily_rounds", "daily_clear"],
		{"weekly_rounds": 11}, []))
	await _play_result("12_result_one_weekly", 2, false, 3, "")
	_meta(PlayerProgression.total_xp_for_level(4) + 40, 40)
	_missions(_raw({"daily_merges": 14, "daily_clear": 1}, ["daily_clear"], {"weekly_merges": 119}, []))
	await _play_result("13_result_daily_weekly", 2, false, 2, "")
	# Görev + seviye atlama + başarım aynı şeritte (toplam merge 95 → 100: Hamur Isınıyor).
	_meta(PlayerProgression.total_xp_for_level(5) - 8, 95)
	_missions(_raw({"daily_merges": 14, "daily_rounds": 1}, [], {"weekly_merges": 119}, []))
	await _play_result("14_result_missions_levelup_achievement", 4, true, 12, "star3")


## Gerçek round: kur, merge kaydı, skor, bitir → Main'in gerçek kesinleştirmesi + sonuç
## (masaüstünde geçiş reklamı yok). Reveal + XP akışı bitince çek.
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
	match stars:
		"star3":
			GameState.add_score(level.star_3_threshold())
		_:
			GameState.add_score(10)
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


# --- Kayıt durumları -----------------------------------------------------------------------------

func _write_fixture() -> void:
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 2},
		"endless_high_score": 0, "dough": 335, "total_merges": 40, "merges_since_bonus_chest": 0,
		"unlocked_skins": ["common_01", "rare_02"], "profile_showcase": ["rare_02"],
		"powerups": {"bomb": 2, "upgrade": 1, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "", "daily_streak": 3,
		"last_login_date": Time.get_date_string_from_system(), "age_ad_band": "ADULT", "next_age_transition_date": "",
		"player_meta_version": 1, "player_xp": 400, "total_rounds_played": 12, "highest_tier_created": 5}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(content, "\t"))
	file.close()


func _meta(xp: int, merges: int) -> void:
	SaveManager.data["player_xp"] = xp
	SaveManager.data["total_merges"] = merges
	SaveManager.data["merges_since_bonus_chest"] = 0
	SaveManager.data["unlocked_achievements"] = []
	SaveManager.data["level_stars"] = {"1": 3, "2": 3, "3": 2}
	SaveManager.data["highest_level_unlocked"] = 5
	SaveManager.reconcile_achievements()


func _missions(state: Dictionary) -> void:
	SaveManager.data["missions"] = state


func _raw(daily: Dictionary, daily_rewarded: Array, weekly: Dictionary, weekly_rewarded: Array) -> Dictionary:
	return Missions.sanitize({"version": 1, "day_key": DAY, "week_start_day_key": Missions.week_start(DAY),
		"daily_progress": daily, "daily_rewarded": daily_rewarded, "weekly_progress": weekly,
		"weekly_rewarded": weekly_rewarded})


func _all_done() -> Dictionary:
	return _raw({}, ["daily_merges", "daily_rounds", "daily_clear"], {}, ["weekly_merges", "weekly_rounds", "weekly_clears"])


func _level(number: int) -> LevelData:
	for level in LevelLibrary.load_levels():
		if level.level_number == number:
			return level
	return null


# --- Çekim ---------------------------------------------------------------------------------------

func _settle() -> void:
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame


func _tag() -> String:
	return "%dx%d%s" % [_size.x, _size.y, "_a36" if _safe_top >= 0.0 else ""]


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


func _clean() -> void:
	for path in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
