extends Node
## Profil QA çekimleri (TASK/044). Dev aracı — oyun çalışırken kullanılmaz.
## `--headless` İLE ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn` deterministik kayıt durumlarıyla çekiliyor. Profil kayda
## YAZMAZ; araç yine de kayıt dosyasını başta byte olarak okur, çıkışta AYNEN
## geri yazar; durum değerleri bellekte ve çıkışta geri konur. Her profil durumu
## iki kare: üst (kimlik + vitrin) ve kaydırma sonu (istatistik / güç / koleksiyon).
##
##   01_fresh[_bottom]         yeni oyuncu: 0 vitrin, kanonik avatar, "—" değerler
##   02_mid[_bottom]           orta ilerleme: 1 vitrin (avatar rare_02), level 5
##   03_late[_bottom]          geç ilerleme: 3 vitrin (Legendary avatar), sonsuz açık, 20/20
##   04_zero_showcase          orta ilerleme ama boş vitrin (üç BOŞ YUVA)
##   05_three_showcase         orta ilerleme, dolu vitrin (3/3)
##   06_legacy_partial_bottom  eski kayıt: tur sayacı "güncellemeden beri"
##   07_settings_from_profile  dişli çark → Ayarlar (Profil üstünde)
##   08_home_avatar_default    Ana Sayfa üst satırı: kanonik avatar
##   09_home_avatar_legendary  Ana Sayfa üst satırı: Legendary vitrin başı
##   10_slot_to_detail         dolu vitrin yuvası → Koleksiyon'da parça detayı
##
## Kullanım:
##   godot --path . res://tools/profile_shots.tscn -- <çıktı_klasörü> [GxY] [safe=61]
## `safe=N`: A36 punch-hole payı simülasyonu (tuval px; dosya adına `_a36`).

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SHOT_SIZE := Vector2i(720, 1280)

var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _main: Node2D
var _saved_data: Dictionary = {}
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _safe_top: float = -1.0


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://profile_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_size = _shot_size(args)
	for arg in args:
		if String(arg).begins_with("safe="):
			_safe_top = float(String(arg).trim_prefix("safe="))
	DisplayServer.window_set_size(_size)
	await get_tree().process_frame
	await get_tree().process_frame

	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_saved_data = SaveManager.data.duplicate(true)
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.data["onboarding_completed"] = true

	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	if _safe_top >= 0.0:
		_profile()._layout_with_safe_top(_safe_top)
		_main._screens[0]._layout_with_safe_top(_safe_top)
		_main._screens[2]._layout_with_safe_top(_safe_top)

	_apply_fresh()
	await _pair("01_fresh")
	_apply_mid()
	await _pair("02_mid")
	_apply_late()
	await _pair("03_late")
	_apply_mid()
	SaveManager.data["profile_showcase"] = []
	await _show()
	await _capture("04_zero_showcase")
	_apply_mid()
	SaveManager.data["profile_showcase"] = ["epic_01", "rare_02", "common_04"]
	await _show()
	await _capture("05_three_showcase")
	_apply_mid()
	SaveManager.data["profile_counters_partial"] = true
	SaveManager.data["total_rounds_played"] = 3
	await _show()
	await _scroll_bottom()
	await _capture("06_legacy_partial_bottom")

	_apply_mid()
	await _show()
	_profile().settings_button().pressed.emit()
	await _settle()
	await _capture("07_settings_from_profile")
	_main.close_settings()
	await _settle()

	_apply_fresh()
	_main._show_tab(4)
	_main._show_tab(0)
	await _settle()
	await _capture("08_home_avatar_default")
	_apply_late()
	_main._show_tab(4)
	_main._show_tab(0)
	await _settle()
	await _capture("09_home_avatar_legendary")

	_apply_mid()
	await _show()
	_profile().showcase_slots()[0].pressed.emit()
	await _settle()
	await _capture("10_slot_to_detail")
	_main._screens[2].close_detail(false)

	SaveManager.data = _saved_data
	_restore_save_file()
	print("bitti -> ", _out_dir)
	get_tree().quit()


func _pair(name: String) -> void:
	await _show()
	await _capture(name)
	await _scroll_bottom()
	await _capture(name + "_bottom")


func _scroll_bottom() -> void:
	var scroll: ScrollContainer = _profile().scroll()
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _settle()


func _restore_save_file() -> void:
	if not _had_save:
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()


func _shot_size(args: PackedStringArray) -> Vector2i:
	if args.size() < 2:
		return SHOT_SIZE
	var parts: PackedStringArray = args[1].split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return SHOT_SIZE
	return Vector2i(int(parts[0]), int(parts[1]))


func _tag() -> String:
	return "%dx%d%s" % [_size.x, _size.y, "_a36" if _safe_top >= 0.0 else ""]


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var file: String = "%s_%s.png" % [name, _tag()]
	var err: int = img.save_png(_out_dir.path_join(file))
	print(("kaydedildi : " if err == OK else "HATA       : "), file)


func _settle() -> void:
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame


func _show() -> void:
	_main._show_tab(0)
	await get_tree().process_frame
	_main._show_tab(4)
	await _settle()


func _profile() -> CanvasLayer:
	return _main._screens[4]


# --- Kayıt durumları (yalnızca bellekte) ---

func _apply_fresh() -> void:
	SaveManager.data["highest_level_unlocked"] = 1
	SaveManager.data["level_stars"] = {}
	SaveManager.data["dough"] = 0
	SaveManager.data["unlocked_skins"] = []
	SaveManager.data["profile_showcase"] = []
	SaveManager.data["powerups"] = {"bomb": 1, "upgrade": 1, "shake": 1, "clear_small": 1}
	SaveManager.data["endless_high_score"] = 0
	SaveManager.data["total_merges"] = 0
	SaveManager.data["total_rounds_played"] = 0
	SaveManager.data["highest_tier_created"] = 0
	SaveManager.data["profile_counters_partial"] = false
	SaveManager.data["daily_streak"] = 0
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()


func _apply_mid() -> void:
	SaveManager.data["highest_level_unlocked"] = 5
	SaveManager.data["level_stars"] = {"1": 3, "2": 2, "3": 3, "4": 2}
	SaveManager.data["dough"] = 335
	SaveManager.data["unlocked_skins"] = ["common_01", "common_02", "rare_02", "common_04", "rare_05", "epic_01"]
	SaveManager.data["profile_showcase"] = ["rare_02"]
	SaveManager.data["powerups"] = {"bomb": 3, "upgrade": 1, "shake": 0, "clear_small": 2}
	SaveManager.data["endless_high_score"] = 0
	SaveManager.data["total_merges"] = 1234
	SaveManager.data["total_rounds_played"] = 17
	SaveManager.data["highest_tier_created"] = 5
	SaveManager.data["profile_counters_partial"] = false
	SaveManager.data["daily_streak"] = 2
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()


func _apply_late() -> void:
	var all_ids: Array = []
	for skin in SkinLibrary.all():
		all_ids.append(String(skin.id))
	var stars: Dictionary = {}
	for level in LevelLibrary.load_levels():
		stars[str(level.level_number)] = 3
	SaveManager.data["highest_level_unlocked"] = LevelLibrary.load_levels().size() + 1
	SaveManager.data["level_stars"] = stars
	SaveManager.data["dough"] = 99999
	SaveManager.data["unlocked_skins"] = all_ids
	SaveManager.data["profile_showcase"] = ["legendary_02", "epic_03", "rare_02"]
	SaveManager.data["powerups"] = {"bomb": 99, "upgrade": 12, "shake": 0, "clear_small": 7}
	SaveManager.data["endless_high_score"] = 12480
	SaveManager.data["total_merges"] = 98765
	SaveManager.data["total_rounds_played"] = 1250
	SaveManager.data["highest_tier_created"] = 8
	SaveManager.data["profile_counters_partial"] = false
	SaveManager.data["daily_streak"] = 365
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
