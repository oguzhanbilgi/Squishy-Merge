extends Node
## Oyuncu İlerlemesi QA çekimleri (TASK/045). Dev aracı — oyun çalışırken kullanılmaz.
## `--headless` İLE ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn`, deterministik kayıt durumları (yalnız bellekte) + sabit RNG
## tohumu. Kayıt dosyası başta byte olarak okunur, çıkışta AYNEN geri yazılır.
##
##   P  Profil     01 yeni (LV 1, 0 XP, 0/12, varsayılan unvan) · 02 kısmi XP (LV 7,
##                 84/180) · 03 seviyeye 1 XP (179/180) · 04 tam sınır (0/200) ·
##                 05 LV 10+ · 06 LV 100+ · 07 bozukluk sınırı (LV 2,5 milyon) ·
##                 08 kısmi başarım + Efsane Birleştirici + 3 vitrin · 09 12/12 +
##                 uzun unvan · her birinin başarım bölümü (`_ach`) karesi
##   A  Başarımlar 10 kilitli (0/12) · 11 karışık üst · 12 karışık orta · 13 karışık
##                 alt · 14 hepsi tamam
##   T  Unvanlar   15 çoğu kilitli · 16 çoğu açık · 17 uzun seçili unvan (alt)
##   R  Sonuç      18 +XP · 19 seviye atlama · 20 başarım · 21 seviye + başarım ·
##                 22 çok seviye (+ başarımlar)
##
## Kullanım:
##   godot --resolution GxY --path . res://tools/progression_shots.tscn -- <çıktı> [GxY] [safe=61] [only=P|A|T|R]
## `--resolution` ŞART (TASK/044 dersi): pencere yöneticisiz X (xvfb) çalışma anındaki
## `window_set_size`'ı yok sayar. Araç her karenin piksel boyutunu DOĞRULAR; tutmazsa
## "BOYUT HATASI" basar ve çıkış kodu 3 olur.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SHOT_SIZE := Vector2i(720, 1280)

var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _main: Node2D
var _saved_data: Dictionary = {}
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _safe_top: float = -1.0
var _only: String = ""
var _shots: int = 0
var _size_errors: int = 0


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://progression_shots")
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

	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_saved_data = SaveManager.data.duplicate(true)
	_base()

	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	if _safe_top >= 0.0:
		_profile()._layout_with_safe_top(_safe_top)
		_main._screens[0]._layout_with_safe_top(_safe_top)

	if _wants("P"):
		await _profile_states()
	if _wants("A"):
		await _achievement_states()
	if _wants("T"):
		await _title_states()
	if _wants("R"):
		await _result_states()

	SaveManager.data = _saved_data
	_restore_save_file()
	print("bitti -> %s (%d kare, %d boyut hatası)" % [_out_dir, _shots, _size_errors])
	get_tree().quit(3 if _size_errors > 0 else 0)


func _wants(group: String) -> bool:
	return _only.is_empty() or _only.contains(group)


# --- P: Profil ------------------------------------------------------------------------

func _profile_states() -> void:
	_state(0, 0, 0, 0, 0, [])
	await _profile_pair("01_profile_fresh_lv1")
	_state(744, 400, 7, 5, 6, ["rare_02"])
	await _profile_pair("02_profile_partial_xp_lv7")
	_state(PlayerProgression.total_xp_for_level(8) - 1, 400, 7, 5, 6, ["rare_02"])
	await _profile_pair("03_profile_level_ready")
	_state(PlayerProgression.total_xp_for_level(8), 400, 7, 5, 6, ["rare_02"])
	await _profile_pair("04_profile_level_boundary")
	_state(PlayerProgression.total_xp_for_level(12) + 150, 1250, 18, 9, 11, ["legendary_02", "epic_03"])
	await _profile_pair("05_profile_lv12")
	_state(PlayerProgression.total_xp_for_level(137) + 222, 98765, 30, 11, 20, ["legendary_02", "epic_03", "rare_02"])
	await _profile_pair("06_profile_lv137")
	_state(PlayerProgression.MAX_XP, 98765, 30, 11, 20, ["legendary_02"])
	await _profile_pair("07_profile_corruption_bound")
	_state(3140, 1204, 16, 11, 11, ["epic_01", "rare_02", "common_04"])
	SaveManager.data["selected_title_id"] = "efsane_birlestirici"
	await _profile_pair("08_profile_partial_ach_long_title_full_showcase")
	_state(40000, 98765, 30, 11, 20, ["legendary_02", "epic_03", "rare_02"])
	SaveManager.data["selected_title_id"] = "squishy_arsivcisi"
	await _profile_pair("09_profile_all_ach_complete")


func _profile_pair(name: String) -> void:
	await _show_profile()
	await _capture("P_" + name)
	var card: Control = _profile().content().get_node("AchievementsCard")
	var scroll: ScrollContainer = _profile().scroll()
	var header: Control = _profile().section(&"achievements")
	scroll.scroll_vertical = int(maxf(header.position.y - 12.0, 0.0))
	await _settle()
	if card != null:
		await _capture("P_" + name + "_ach")


# --- A: Başarımlar penceresi ----------------------------------------------------------

func _achievement_states() -> void:
	_state(0, 0, 0, 0, 0, [])
	await _show_profile()
	_profile().open_achievements()
	await _settle()
	await _capture("A_10_locked_0of12")
	_profile().achievements_overlay().close(false)
	_state(3000, 540, 16, 4, 11, ["rare_02"])
	await _show_profile()
	_profile().open_achievements()
	await _settle()
	await _capture("A_11_mixed_top")
	var scroll: ScrollContainer = _profile().achievements_overlay().scroll()
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value * 0.4)
	await _settle()
	await _capture("A_12_mixed_middle")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _settle()
	await _capture("A_13_mixed_bottom")
	_profile().achievements_overlay().close(false)
	_state(40000, 98765, 30, 11, 20, ["legendary_02"])
	await _show_profile()
	_profile().open_achievements()
	await _settle()
	await _capture("A_14_all_complete")
	_profile().achievements_overlay().close(false)


# --- T: Unvan seçici ------------------------------------------------------------------

func _title_states() -> void:
	_state(200, 120, 3, 1, 2, [])
	await _show_profile()
	_profile().open_title_selector()
	await _settle()
	await _capture("T_15_mostly_locked")
	_profile().title_selector().close(false)
	_state(20000, 1204, 30, 11, 12, ["legendary_02"])
	SaveManager.data["selected_title_id"] = "yildiz_ustasi"
	await _show_profile()
	_profile().open_title_selector()
	await _settle()
	await _capture("T_16_many_unlocked")
	_profile().title_selector().close(false)
	_state(20000, 1204, 30, 11, 12, ["legendary_02"])
	SaveManager.data["selected_title_id"] = "efsane_birlestirici"
	await _show_profile()
	_profile().open_title_selector()
	await _settle()
	await _capture("T_17_long_selected_top")
	var scroll: ScrollContainer = _profile().title_selector().scroll()
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _settle()
	await _capture("T_17_long_selected_bottom")
	_profile().title_selector().close(false)


# --- R: Sonuç ekranı ----------------------------------------------------------------------

func _result_states() -> void:
	# +XP: LV 3 ortası, 14 merge + bitiş + 1 yeni yıldız = 44.
	_state(PlayerProgression.total_xp_for_level(3) + 30, 40, 2, 2, 2, [])
	await _play_result("R_18_plus_xp", 2, true, 14, "star2")
	# Seviye atlama: 1 XP eksik + 12 merge + bitiş.
	_state(PlayerProgression.total_xp_for_level(5) - 8, 60, 6, 3, 2, [])
	SaveManager.data["level_stars"] = {"1": 3, "2": 3, "3": 3, "4": 3}
	await _play_result("R_19_level_up", 4, true, 12, "star3")
	# Başarım: 99 merge + 5 → Hamur Isınıyor; seviye atlamaz.
	_state(PlayerProgression.total_xp_for_level(6) + 10, 95, 6, 3, 2, [])
	SaveManager.data["level_stars"] = {"1": 3, "2": 3, "3": 3, "4": 3}
	await _play_result("R_20_achievement", 4, false, 5, "")
	# Seviye + başarım birlikte.
	_state(PlayerProgression.total_xp_for_level(4) - 5, 95, 4, 2, 2, [])
	SaveManager.data["level_stars"] = {"1": 2, "2": 2}
	await _play_result("R_21_level_up_and_achievement", 3, true, 9, "star3")
	# Çok seviye + birden fazla başarım.
	_state(50, 480, 0, 0, 2, [])
	SaveManager.data["level_stars"] = {}
	await _play_result("R_22_multi_level", 1, true, 150, "star3")


## Gerçek round: kur, `merges` merge kaydı, skor (yıldız), bitir → Main'in gerçek
## kesinleştirmesi + sonuç (masaüstünde geçiş reklamı yok). Reveal + XP akışı bitince çek.
func _play_result(name: String, level_number: int, won: bool, merges: int, stars: String) -> void:
	_main._show_tab(0)
	await get_tree().process_frame
	var level: LevelData = _level(level_number)
	seed(4545)
	_main._start_level(level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in merges:
		GameState.register_merge(2 + (i % 3), Vector2(360, 700))
	match stars:
		"star3":
			GameState.add_score(level.star_3_threshold())
		"star2":
			GameState.add_score(level.star_2_threshold())
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


# --- Kayıt durumları (yalnız bellekte) -------------------------------------------------------

func _base() -> void:
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.data["onboarding_completed"] = true
	SaveManager.data["onboarding_completed_day"] = ""


## xp · merge · yıldız (10 level'a dağıtılır) · tamamlanan level · sahip olunan Squishy ·
## vitrin. Başarım listesi ve unvan her durumda sıfırdan (monoton liste önceki
## durumdan taşmasın); Profil açılışı gerçeklerden uzlaştırır.
func _state(xp: int, merges: int, stars: int, completed: int, owned: int, showcase: Array) -> void:
	_base()
	var star_map: Dictionary = {}
	var left: int = stars
	for n in range(1, 11):
		var give: int = mini(left, 3)
		if give > 0:
			star_map[str(n)] = give
		left -= give
	var owned_ids: Array = []
	for skin in SkinLibrary.all():
		if owned_ids.size() < owned:
			owned_ids.append(String(skin.id))
	for id in showcase:
		if not owned_ids.has(id):
			owned_ids.append(id)
	SaveManager.data["player_xp"] = xp
	SaveManager.data["unlocked_achievements"] = []
	SaveManager.data["selected_title_id"] = "birlestirici"
	SaveManager.data["total_merges"] = merges
	SaveManager.data["merges_since_bonus_chest"] = 0
	SaveManager.data["level_stars"] = star_map
	SaveManager.data["highest_level_unlocked"] = completed + 1
	SaveManager.data["unlocked_skins"] = owned_ids
	SaveManager.data["profile_showcase"] = showcase.duplicate()
	SaveManager.data["dough"] = 335
	SaveManager.data["powerups"] = {"bomb": 3, "upgrade": 1, "shake": 0, "clear_small": 2}
	SaveManager.data["endless_high_score"] = 12480 if completed >= 10 else 0
	SaveManager.data["total_rounds_played"] = 17
	SaveManager.data["highest_tier_created"] = 6
	SaveManager.data["profile_counters_partial"] = false


func _level(number: int) -> LevelData:
	for level in LevelLibrary.load_levels():
		if level.level_number == number:
			return level
	return null


# --- Çekim ----------------------------------------------------------------------------------

func _show_profile() -> void:
	_main._show_tab(0)
	await get_tree().process_frame
	_main._show_tab(4)
	await _settle()


func _profile() -> CanvasLayer:
	return _main._screens[4]


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


func _restore_save_file() -> void:
	if not _had_save:
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()
