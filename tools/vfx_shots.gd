extends Node
## M8.5-07 gorsel QA cekimleri: dort gucun efektleri + dolu board + uzun
## portrait. Dev araci — oyun calisirken kullanilmaz.
##
## `--headless` ILE CALISTIRILAMAZ (dummy rasterizer, cekimler bos cikar).
##
## Kullanim:
##   godot --path . res://tools/vfx_shots.tscn -- <cikti_klasoru> [GxY]
##
## KAYIT DOSYASINA YAZMAZ: guc stogu bellekte sisiriliyor, save_game
## cagrilmiyor ve kosu sonunda eski stok geri konuyor.

const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const BOT_BRAIN = preload("res://tools/bot_brain.gd")

const SHOT_SIZE := Vector2i(540, 960)
## Uzun/dar modern telefon orani (9:19.5) — HUD tasmasi kontrolu.
const TALL_SIZE := Vector2i(540, 1170)

var _out_dir: String = ""
var _board: Node2D
var _drive: bool = false
var _stock_backup: Dictionary = {}


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(SHOT_SIZE)
	_inflate_stock()

	await get_tree().process_frame
	await _shot_gameplay()
	await _shot_full_board()
	await _shot_bomb()
	await _shot_upgrade()
	await _shot_shake()
	await _shot_clear()
	await _shot_stock_zero()
	await _shot_tall()

	_restore_stock()
	print("bitti -> ", _out_dir)
	get_tree().quit()


## Guc stoklari BELLEKTE sisiriliyor; save_game CAGRILMIYOR.
func _inflate_stock() -> void:
	_stock_backup = (SaveManager.data.get("powerups", {}) as Dictionary).duplicate(true)
	var stock: Dictionary = {}
	for type in PowerUp.all():
		stock[PowerUp.save_key(type)] = 9
	SaveManager.data["powerups"] = stock


func _restore_stock() -> void:
	SaveManager.data["powerups"] = _stock_backup


func _set_speed(factor: int) -> void:
	Engine.physics_ticks_per_second = 60 * factor
	Engine.time_scale = float(factor)
	Engine.max_physics_steps_per_frame = 16 * factor


func _make_board(level_number: int) -> void:
	var path: String = "res://resources/levels/endless.tres"
	if level_number > 0:
		path = "res://resources/levels/level_%02d.tres" % level_number
	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(load(path))
	add_child(_board)


func _teardown() -> void:
	_drive = false
	_set_speed(1)
	if _board != null and is_instance_valid(_board):
		_board.queue_free()
	_board = null
	await get_tree().process_frame


func _physics_process(_delta: float) -> void:
	if not _drive or _board == null or not is_instance_valid(_board):
		return
	if _board._is_finished or _board._is_paused() or _board._drop_cooldown > 0.0:
		return
	_board._set_aim(BOT_BRAIN.pick_x(_board, _board._pending_tier))
	_board._drop()


## Board'a N parca birakip yerlesmesini bekler.
func _fill(level_number: int, drops: int) -> void:
	_make_board(level_number)
	await get_tree().process_frame
	_set_speed(4)
	_drive = true
	var frames: int = 0
	var start: int = GameState.merge_count
	while frames < 60 * 90:
		await get_tree().process_frame
		frames += 1
		if _board == null or not is_instance_valid(_board) or _board._is_finished:
			break
		if _board._dumpling_layer.get_child_count() >= drops:
			break
	_drive = false
	# Yiginin oturmasi icin biraz daha bekle.
	for i in 40:
		await get_tree().process_frame
	_set_speed(1)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out_dir.path_join(file_name)
	var err: int = img.save_png(path)
	print(("kaydedildi : " if err == OK else "HATA       : "), path)


## En buyuk (en ust tier) parcayi dondurur — guc hedefi olarak kullanilir.
func _biggest() -> Dumpling:
	var best: Dumpling = null
	for node in _board._dumpling_layer.get_children():
		var d := node as Dumpling
		if d == null or not is_instance_valid(d) or d.is_queued_for_deletion():
			continue
		if not d.has_landed:
			continue
		if best == null or d.tier > best.tier:
			best = d
	return best


# --- 1) Normal oynanis ---

func _shot_gameplay() -> void:
	await _fill(3, 10)
	await _capture("v01_gameplay.png")
	await _teardown()


# --- 2) Dolu board / danger ---

func _shot_full_board() -> void:
	for attempt in 5:
		_make_board(10)
		await get_tree().process_frame
		_set_speed(4)
		_drive = true
		var caught: bool = false
		var frames: int = 0
		while frames < 60 * 150:
			await get_tree().process_frame
			frames += 1
			if _board == null or not is_instance_valid(_board):
				break
			if _board._is_finished or _board._is_paused():
				break
			if _board._overflow_elapsed > 0.7:
				caught = true
				break
		_drive = false
		_set_speed(1)
		if caught:
			await _capture("v02_danger_dolu.png")
			await _teardown()
			return
		await _teardown()
	printerr("danger yakalanamadi")


# --- 3) Bomba: hedefleme + carpma ---

func _shot_bomb() -> void:
	await _fill(10, 12)
	var target: Dumpling = _biggest()
	if target == null:
		printerr("bomba hedefi yok"); await _teardown(); return
	# Hedefleme modu: gecerli hedefler nabiz atiyor.
	_board._on_power_pressed(int(PowerUp.Type.BOMB))
	for i in 12:
		await get_tree().process_frame
	await _capture("v03_bomba_hedefleme.png")
	# Kilitlenme + mermi + carpma.
	_board._use_targeted_power(target)
	# BOMB_TRAVEL 0.28 sn; carpmadan hemen sonrasini yakala.
	await get_tree().create_timer(0.34).timeout
	await _capture("v04_bomba_carpma.png")
	await _teardown()


# --- 4) Buyutucu: donusum ---

func _shot_upgrade() -> void:
	await _fill(10, 12)
	var target: Dumpling = _biggest()
	if target == null:
		printerr("buyutucu hedefi yok"); await _teardown(); return
	_board._on_power_pressed(int(PowerUp.Type.UPGRADE))
	await get_tree().process_frame
	_board._use_targeted_power(target)
	await get_tree().create_timer(0.10).timeout
	await _capture("v05_buyutucu.png")
	await _teardown()


# --- 5) Sarsinti ---

func _shot_shake() -> void:
	await _fill(10, 14)
	_board._on_power_pressed(int(PowerUp.Type.SHAKE))
	await get_tree().create_timer(0.12).timeout
	await _capture("v06_sarsinti.png")
	await _teardown()


# --- 6) Temizleyici ---

func _shot_clear() -> void:
	await _fill(10, 16)
	_board._on_power_pressed(int(PowerUp.Type.CLEAR_SMALL))
	await get_tree().create_timer(0.16).timeout
	await _capture("v07_temizleyici.png")
	await _teardown()


# --- 7) Stok 0 guc cubugu ---

func _shot_stock_zero() -> void:
	var stock: Dictionary = SaveManager.data["powerups"]
	SaveManager.data["powerups"] = {}
	await _fill(10, 8)
	await _capture("v08_stok_sifir.png")
	await _teardown()
	SaveManager.data["powerups"] = stock


# --- 8) Uzun portrait ---

func _shot_tall() -> void:
	DisplayServer.window_set_size(TALL_SIZE)
	await get_tree().process_frame
	await _fill(3, 12)
	await _capture("v09_uzun_portrait.png")
	await _teardown()
	DisplayServer.window_set_size(SHOT_SIZE)
