extends Node
## Harita (yolculuk) ekranı QA çekimleri (M8.6-04). Dev aracı — oyun
## çalışırken kullanılmaz. `--headless` İLE ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn` deterministik vitrin kayıt durumlarıyla çekiliyor
## (yalnızca bellekte; kayıt dosyası başta byte olarak okunur, sonda AYNEN
## geri yazılır):
##   01_map_fresh          yeni oyuncu: level 1 sıradaki, 2-10 kilitli, Sonsuz kilitli
##   02_map_mid            orta oyuncu: 1-3 tamam (2/3/3 ★), 4 sıradaki, 5-10 kilitli
##   03_map_late           ileri: 1-8 tamam, 9 sıradaki, Sonsuz kilitli
##   04_map_endless_open   her şey bitmiş: 10/10, Sonsuz açık + rekor 12 480 (odak Sonsuz)
##   05_map_endless_fresh  10/10 bitmiş, Sonsuz açık, rekor yok ("Rekor bekliyor")
##   06_current_pressed    sıradaki düğüm basılı (gerçek fare olayı)
##   07_locked_tap         kilitli düğüme dokunuş (kilit sallanırken)
##   08_unlock_mid         açılış animasyonu ortası (3 → 4 bitmiş gibi tazeleme)
##   09_unlock_done        açılış animasyonu sonu
##   10_back_home          geri → Ana Sayfa (rota hedefi)
##   11_plus_shop          Hamur "+" → Mağaza (rota hedefi)
##
## Kullanım:
##   godot --path . res://tools/map_shots.tscn -- <çıktı_klasörü> [GxY] [safe=61]
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
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://map_shots")
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
		_map()._layout_with_safe_top(_safe_top)
		_main._screens[0]._layout_with_safe_top(_safe_top)

	_apply_progress(1, {}, 0)
	await _show_map()
	await _capture("01_map_fresh")
	_apply_progress(4, {"1": 2, "2": 3, "3": 3}, 0)
	await _show_map()
	await _capture("02_map_mid")
	_apply_progress(9, {"1": 2, "2": 3, "3": 3, "4": 3, "5": 2, "6": 3, "7": 1, "8": 3}, 0)
	await _show_map()
	await _capture("03_map_late")
	_apply_progress(11, _all_stars(), 12480)
	await _show_map()
	await _capture("04_map_endless_open")
	_apply_progress(11, _all_stars(), 0)
	await _show_map()
	await _capture("05_map_endless_fresh")

	_apply_progress(4, {"1": 2, "2": 3, "3": 3}, 0)
	await _show_map()
	await _shot_pressed(_map().focus_node(), "06_current_pressed")
	await _show_map()
	var locked: MapLevelNode = _map().nodes()[6]
	locked.pressed.emit()
	await get_tree().create_timer(0.08).timeout
	await _capture("07_locked_tap")
	await _settle()

	# Açılış animasyonu: orta durumu göster, sonra level 4 bitmiş gibi tazele.
	await _show_map()
	_apply_progress(5, {"1": 2, "2": 3, "3": 3, "4": 3}, 0)
	_map().refresh()
	await get_tree().create_timer(0.18).timeout
	await _capture("08_unlock_mid")
	await get_tree().create_timer(0.7).timeout
	await _capture("09_unlock_done")

	_apply_progress(4, {"1": 2, "2": 3, "3": 3}, 0)
	await _show_map()
	_map().top_bar().back_button().pressed.emit()
	await _settle()
	await _capture("10_back_home")
	await _show_map()
	_map().top_bar().add_button().pressed.emit()
	await _settle()
	await _capture("11_plus_shop")

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


func _show_map() -> void:
	_main._show_tab(0)
	await get_tree().process_frame
	_main._show_tab(1)
	await _settle()


func _map() -> CanvasLayer:
	return _main._screens[1]


# --- Vitrin kayıt durumları (yalnızca bellekte) ---

func _apply_progress(highest: int, stars: Dictionary, record: int) -> void:
	SaveManager.data["highest_level_unlocked"] = highest
	SaveManager.data["level_stars"] = stars
	SaveManager.data["endless_high_score"] = record
	SaveManager.data["dough"] = 335
	SaveManager.data["daily_streak"] = 2
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()


func _all_stars() -> Dictionary:
	var stars: Dictionary = {}
	for i in LevelLibrary.load_levels().size():
		stars[str(i + 1)] = 3
	return stars


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


func _mouse(at: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)
