extends Node
## Ana Sayfa hub QA çekimleri (M8.6-03B). Dev aracı — oyun çalışırken
## kullanılmaz. `--headless` İLE ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn` (ayarlar, günlük ödül, sandık bilgisi dahil)
## deterministik vitrin kayıt durumlarıyla çekiliyor:
##   01_home_mid         orta oyuncu (level 4 sırada, 335 Hamur, 2 seri, 6/20, 49/75)
##   02_home_fresh       yeni oyuncu (level 1, 0 Hamur, 0 seri, 0/20, 0/75)
##   03_home_endless     her şey bitmiş (Sonsuz açık, rekor 12 480, 20/20, 74/75)
##   04_daily_claimable  Günlük madalyonunda bildirim noktası (dün giriş yapılmış)
##   05_daily_claimed    Günlük madalyonundan alındıktan sonra (nokta yok)
##   06_feature_pressed  Koleksiyon madalyonu basılı (button_down)
##   07_play_pressed     OYNA basılı
##   08_settings         Ayarlar penceresi Ana Sayfa üstünde
##   09_daily_modal      Günlük ödül durum penceresi (madalyondan)
##   10_chest_modal      Bonus sandık bilgi penceresi (madalyondan)
##
## KAYIT: 05 için gerçek claim yolu koşar (kayda yazar). Araç kayıt
## dosyasını başta byte olarak okur, çıkışta AYNEN geri yazar. Vitrin
## değerleri bellekte (SaveManager.data) ve çıkışta geri konur.
##
## Kullanım:
##   godot --path . res://tools/home_shots.tscn -- <çıktı_klasörü> [GxY] [safe=61]
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
	# Otomatik GÜNLÜK ÖDÜLLER penceresi (M8.9-02) bu harness'in konusu değil.
	DailyRewards.auto_popup_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://home_shots")
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
	# main._ready günlük ödülü bugün alınmış saysın (kayda yazmasın).
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()

	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	if _main._daily != null:
		_main._daily.visible = false
	if _safe_top >= 0.0:
		_home()._layout_with_safe_top(_safe_top)

	_apply_showcase()
	await _show_home()
	await _capture("01_home_mid")
	_apply_fresh()
	await _show_home()
	await _capture("02_home_fresh")
	_apply_endless()
	await _show_home()
	await _capture("03_home_endless")

	_apply_showcase()
	SaveManager.data["last_login_date"] = _yesterday()
	await _show_home()
	await _capture("04_daily_claimable")
	# Gerçek claim yolu: madalyon → main → DailyReward (kayda yazar, sonda geri konur).
	_home().feature_button(&"daily").pressed.emit()
	await _settle()
	_main._daily.close_popup()
	await _show_home()
	await _capture("05_daily_claimed")

	_apply_showcase()
	await _show_home()
	await _shot_pressed(_home().feature_button(&"collection"), "06_feature_pressed")
	await _shot_pressed(_home().play_button(), "07_play_pressed")
	await _shot_settings()
	await _shot_daily_modal()
	await _shot_chest_modal()

	SaveManager.data = _saved_data
	_restore_save_file()
	print("bitti -> ", _out_dir)
	get_tree().quit()


func _restore_save_file() -> void:
	if not _had_save:
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()


## Yerel takvimde "dün" (DailyReward yerel günü okur; UTC türevi gece
## 00:00–03:00 arasında bir gün fazla geriye kayıyordu).
func _yesterday() -> String:
	var local_unix: int = Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system())
	return Time.get_date_string_from_unix_time(local_unix - 86400)


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
	await get_tree().create_timer(0.45).timeout
	await get_tree().process_frame


func _show_home() -> void:
	_main._show_tab(0)
	await _settle()


func _home() -> CanvasLayer:
	return _main._screens[0]


# --- Vitrin kayıt durumları (yalnızca bellekte) ---

func _apply_showcase() -> void:
	SaveManager.data["highest_level_unlocked"] = 4
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3}
	SaveManager.data["dough"] = 335
	SaveManager.data["daily_streak"] = 2
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.data["unlocked_skins"] = ["common_01", "common_02", "rare_02", "common_04", "rare_05", "epic_01"]
	SaveManager.data["equipped_skin"] = "rare_02"
	SaveManager.data["merges_since_bonus_chest"] = 49
	SaveManager.data["endless_high_score"] = 0


func _apply_fresh() -> void:
	SaveManager.data["highest_level_unlocked"] = 1
	SaveManager.data["level_stars"] = {}
	SaveManager.data["dough"] = 0
	SaveManager.data["daily_streak"] = 0
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.data["unlocked_skins"] = []
	SaveManager.data["equipped_skin"] = ""
	SaveManager.data["merges_since_bonus_chest"] = 0
	SaveManager.data["endless_high_score"] = 0


func _apply_endless() -> void:
	var all_ids: Array = []
	for skin in SkinLibrary.all():
		all_ids.append(String(skin.id))
	var stars: Dictionary = {}
	for i in LevelLibrary.load_levels().size():
		stars[str(i + 1)] = 3
	SaveManager.data["highest_level_unlocked"] = LevelLibrary.load_levels().size() + 1
	SaveManager.data["level_stars"] = stars
	SaveManager.data["dough"] = 99999
	SaveManager.data["daily_streak"] = 365
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.data["unlocked_skins"] = all_ids
	SaveManager.data["equipped_skin"] = "legendary_02"
	SaveManager.data["merges_since_bonus_chest"] = 74
	SaveManager.data["endless_high_score"] = 12480


# --- Durumlar ---

## Gerçek basış: fare olayı butonun merkezine (pressed gövde + basış ölçeği).
## Tuval -> pencere pikseli (1080x2340'ta tuval 1.5x küçük).
func _shot_pressed(button: BaseButton, name: String) -> void:
	if button == null:
		print(name, ": buton bulunamadı — atlandı")
		return
	var k: float = float(DisplayServer.window_get_size().x) / get_viewport().get_visible_rect().size.x
	var at: Vector2 = button.get_global_rect().get_center() * k
	_mouse(at, true)
	for i in 8:
		await get_tree().process_frame
	await _capture(name)
	_mouse(Vector2(-10, -10), false)
	await _settle()
	await _show_home()


func _mouse(at: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)


func _shot_settings() -> void:
	_main.open_settings()
	await _settle()
	await _capture("08_settings")
	_main.close_settings()
	await _settle()


func _shot_daily_modal() -> void:
	_home().feature_button(&"daily").pressed.emit()
	await _settle()
	await _capture("09_daily_modal")
	_main._daily.close_popup()
	await _show_home()


func _shot_chest_modal() -> void:
	_home().feature_button(&"chest").pressed.emit()
	await _settle()
	await _capture("10_chest_modal")
	_main._chest_info.close_info()
	await _show_home()
