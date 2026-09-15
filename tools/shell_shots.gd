extends Node
## Gameplay shell QA çekimleri (M8.6-02). Dev aracı — oyun çalışırken
## kullanılmaz. `--headless` İLE ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek GameBoard + production HUD, deterministik yığınlar:
##   tutorial (L1) / empty / medium / heavy / armed (seçili güç) / zero (stok 0) / danger /
##   endless / skin_sade / skin_rare / skin_legendary
##
## KAYIT: SaveManager.data yalnızca BELLEKTE değiştirilir (stok, takılı
## skin) ve çıkışta geri konur; save_game() ÇAĞRILMAZ.
##
## Kullanım:
##   godot --path . res://tools/shell_shots.tscn -- <çıktı_klasörü> [GxY]

const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SHOT_SIZE := Vector2i(720, 1280)

var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _board: Node2D
var _saved_data: Dictionary = {}


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://shell_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_size = _shot_size(args)
	DisplayServer.window_set_size(_size)
	_saved_data = SaveManager.data.duplicate(true)
	await get_tree().process_frame
	await get_tree().process_frame

	await _shot_empty()
	await _shot_medium()
	await _shot_heavy()
	await _shot_armed()
	await _shot_zero()
	await _shot_danger()
	await _shot_endless()
	await _shot_skin("skin_sade", "")
	await _shot_skin("skin_rare", "rare_02")
	await _shot_skin("skin_legendary", "legendary_02")
	await _shot_pause_menu()

	SaveManager.data = _saved_data
	print("bitti -> ", _out_dir)
	get_tree().quit()


func _shot_size(args: PackedStringArray) -> Vector2i:
	if args.size() < 2:
		return SHOT_SIZE
	var parts: PackedStringArray = args[1].split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return SHOT_SIZE
	return Vector2i(int(parts[0]), int(parts[1]))


func _tag() -> String:
	return "%dx%d" % [_size.x, _size.y]


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var file: String = "%s_%s.png" % [name, _tag()]
	var err: int = img.save_png(_out_dir.path_join(file))
	print(("kaydedildi : " if err == OK else "HATA       : "), file)


func _make_board(level: String = "res://resources/levels/level_04.tres",
		keep_tutorial: bool = false) -> void:
	await _teardown()
	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(load(level))
	add_child(_board)
	await get_tree().process_frame
	if not keep_tutorial:
		_board._dismiss_tutorial()
	await get_tree().process_frame


func _teardown() -> void:
	if _board != null and is_instance_valid(_board):
		_board.queue_free()
		_board = null
		await get_tree().process_frame


func _spawn(tier: int, at: Vector2) -> Dumpling:
	return _board._spawn_dumpling(tier, at)


func _settle(max_frames: int = 240) -> void:
	for i in max_frames:
		await get_tree().physics_frame
		var moving: bool = false
		for child in _board._dumpling_layer.get_children():
			var d := child as Dumpling
			if d != null and d.linear_velocity.length() > 4.0:
				moving = true
				break
		if not moving and i > 30:
			return


## Satır satır yığın: `rows` alttan üste tier listeleri.
func _pile(rows: Array) -> void:
	var left: float = _board._left_x()
	var right: float = _board._right_x()
	var y: float = _board.FLOOR_Y - 40.0
	for row in rows:
		var tiers: Array = row
		var total_w: float = 0.0
		for t in tiers:
			total_w += TierConfig.radius(t) * 2.0 + 6.0
		var x: float = (left + right) * 0.5 - total_w * 0.5
		var row_h: float = 0.0
		for t in tiers:
			var r: float = TierConfig.radius(t)
			x += r + 3.0
			_spawn(t, Vector2(clampf(x, left + r, right - r), y - r))
			x += r + 3.0
			row_h = maxf(row_h, r * 2.0)
		y -= row_h + 4.0
		for i in 12:
			await get_tree().physics_frame
	await _settle()


func _shot_empty() -> void:
	await _make_board("res://resources/levels/level_01.tres", true)
	await _capture("00_tutorial_l1")
	await _make_board()
	GameState.add_score(0)
	await _capture("01_empty")


func _shot_medium() -> void:
	await _make_board()
	await _pile([[4, 3, 4, 3], [3, 2, 2, 3], [2, 1, 2]])
	GameState.add_score(1240)
	await get_tree().process_frame
	await _capture("02_medium")


func _shot_heavy() -> void:
	await _make_board("res://resources/levels/level_10.tres")
	await _pile([[8, 7], [6, 5, 4], [5, 4, 3, 4], [3, 2, 3, 2, 3], [2, 1, 2, 1, 2]])
	GameState.add_score(4810)
	await get_tree().process_frame
	await _capture("03_heavy")


func _shot_armed() -> void:
	await _make_board()
	SaveManager.data["powerups"] = {"bomb": 3, "upgrade": 1, "shake": 2, "clear_small": 5}
	_board._refresh_power_bar()
	await _pile([[5, 4, 3], [3, 2, 2]])
	_board._on_power_pressed(int(PowerUp.Type.BOMB))
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("04_armed_bomb")


func _shot_zero() -> void:
	await _make_board()
	SaveManager.data["powerups"] = {"bomb": 0, "upgrade": 0, "shake": 2, "clear_small": 0}
	_board._refresh_power_bar()
	await _pile([[4, 3, 3], [2, 2]])
	await get_tree().process_frame
	await _capture("05_zero_stock")


func _shot_danger() -> void:
	await _make_board("res://resources/levels/level_10.tres")
	await _pile([[7, 6, 5], [6, 5, 4, 5], [5, 4, 3, 4, 3], [4, 3, 3, 4, 3], [3, 2, 3, 2, 3, 2], [3, 2, 2, 3, 2]])
	# Taşma sayacını elle sürüp nabzı tepede yakala (fizik sayaçları
	# durdurulur, sunum aynı `_process` yolundan çizilir).
	_board.set_physics_process(false)
	_board._overflow_elapsed = 1.1
	for i in 90:
		await get_tree().process_frame
		if _board._danger_pulse > 0.95:
			break
	await _capture("06_danger")
	_board.set_physics_process(true)


func _shot_endless() -> void:
	await _make_board("res://resources/levels/endless.tres")
	await _pile([[8, 7, 6], [6, 5, 5, 4], [4, 3, 4, 3, 3], [2, 2, 3, 2, 1, 2]])
	GameState.add_score(9860)
	await get_tree().process_frame
	await _capture("07_endless")


## Mola penceresi: gerçek Main akışı (HUD Geri → PauseMenu), board donuk.
func _shot_pause_menu() -> void:
	await _teardown()
	var main: Node2D = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	if main._daily != null:
		main._daily.visible = false
	main._start_level(load("res://resources/levels/level_04.tres"))
	await get_tree().process_frame
	await get_tree().process_frame
	main._board._dismiss_tutorial()
	_board = main._board
	await _pile([[4, 3, 4, 3], [3, 2, 2, 3]])
	main._board.get_node("HUD").back_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	await _capture("09_pause_menu")
	_board = null
	main.queue_free()
	await get_tree().process_frame


func _shot_skin(name: String, skin_id: String) -> void:
	SaveManager.data["equipped_skin"] = skin_id
	if skin_id != "" and not SaveManager.owns_skin(StringName(skin_id)):
		var owned: Array = SaveManager.data.get("unlocked_skins", []).duplicate()
		owned.append(skin_id)
		SaveManager.data["unlocked_skins"] = owned
	await _make_board("res://resources/levels/level_06.tres")
	await _pile([[8, 7], [6, 5, 5], [4, 4, 3, 4], [3, 2, 2, 3], [2, 1, 1, 2, 1]])
	GameState.add_score(3320)
	await get_tree().process_frame
	await _capture("08_%s" % name)
	SaveManager.data["equipped_skin"] = ""
