extends Node
## Game-feel kare dizileri (M8.5-11). Dev araci — oyun calisirken kullanilmaz.
##
## Dusus, inis, merge (cekim / pop / acilis), x3 zincir, tehlike, hedef
## tamam ve tier 7->8 anlarini KARE KARE yakalar; contact sheet'i
## tools/ altindaki degil scratch'teki python betigi kuruyor.
##
## Deterministik: parcalar sabit konumlara spawn ediliyor, bekleme fizik
## karesiyle. `--headless` ILE CALISTIRILAMAZ.
##
## Kullanim:
##   godot --path . res://tools/feel_shots.tscn -- <cikti_klasoru> [GxY]

const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const SHOT_SIZE := Vector2i(540, 960)

var _out_dir: String = ""
var _board: Node2D
var _merge_frames: int = -1


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(_shot_size(args))
	await get_tree().process_frame
	await _seq_drop()
	await _seq_merge(4, "merge")
	await _seq_combo()
	await _seq_danger()
	await _seq_goal()
	await _seq_merge(7, "king")
	print("bitti -> ", _out_dir)
	get_tree().quit()


func _shot_size(args: PackedStringArray) -> Vector2i:
	if args.size() < 2:
		return SHOT_SIZE
	var parts: PackedStringArray = args[1].split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return SHOT_SIZE
	return Vector2i(int(parts[0]), int(parts[1]))


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(_out_dir.path_join(file_name))
	print(("kaydedildi : " if err == OK else "HATA       : "), file_name)


func _make_board(level: String = "res://resources/levels/level_01.tres") -> void:
	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(load(level))
	add_child(_board)
	_board.get_node("Preview").visible = false
	_board._dismiss_tutorial()
	await get_tree().process_frame


func _teardown() -> void:
	if _board != null and is_instance_valid(_board):
		_board.queue_free()
	_board = null
	await get_tree().process_frame


func _spawn(tier: int, at: Vector2) -> Dumpling:
	return _board._spawn_dumpling(tier, at)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _settle(max_frames: int = 240) -> void:
	for i in max_frames:
		await get_tree().physics_frame
		var moving: bool = false
		for child in _board._dumpling_layer.get_children():
			var d := child as Dumpling
			if d != null and d.linear_velocity.length() > 4.0:
				moving = true
				break
		if not moving and i > 20:
			return


# --- 1) Dusus: on-carpma gerilmesi + inis squash ---

func _seq_drop() -> void:
	await _make_board()
	var cx: float = _board._center_x()
	var d: Dumpling = _spawn(3, Vector2(cx, _board.drop_line_y()))
	# Tabana ~70 px kala: dusus gerilmesi.
	var r: float = TierConfig.radius(3)
	for i in 240:
		await get_tree().physics_frame
		if d.global_position.y >= _board.FLOOR_Y - r - 70.0:
			break
	await _capture("07_drop_pre_impact.png")
	# Inis: has_landed olunca 2 kare sonra (squash tepe noktasi ~60 ms).
	for i in 60:
		await get_tree().physics_frame
		if d.has_landed:
			break
	await _frames(3)
	await _capture("08_landing_squash.png")
	await _settle()
	await _teardown()


# --- 2) Merge: temas -> cekim -> pop -> acilis ---

## Tabandaki parcanin ustune ayni tier'dan bir tane dusuruluyor.
func _seq_merge(tier: int, prefix: String) -> void:
	await _make_board()
	var cx: float = _board._center_x()
	var r: float = TierConfig.radius(tier)
	_spawn(tier, Vector2(cx - r - 4.0, _board.FLOOR_Y - r - 10.0))
	await _settle(90)
	# Tam ustune degil, hafif sagina: temas capraz olsun, cekim okunsun.
	var falling: Dumpling = _spawn(tier, Vector2(cx - r - 4.0 + r * 0.5, _board.FLOOR_Y - r - 300.0))
	_merge_frames = -1
	GameState.merge_performed.connect(_on_merge)
	# Temas karesi: yaklasirken (merkez mesafesi < 2r + 12) tek kare.
	var contact_shot: bool = false
	for i in 300:
		await get_tree().physics_frame
		if not contact_shot and is_instance_valid(falling):
			for child in _board._dumpling_layer.get_children():
				var other := child as Dumpling
				if other != null and other != falling and other.tier == tier \
						and other.global_position.distance_to(falling.global_position) < 2.0 * r + 40.0:
					await _capture(prefix + "_09_contact.png")
					contact_shot = true
					break
		if _merge_frames >= 0:
			break
	# Merge cozuldu (deferred): ayni karede hayalet cekimi + acilis basliyor.
	await _capture(prefix + "_10_pop.png")
	await _frames(4)
	await _capture(prefix + "_11_reveal.png")
	await _frames(10)
	await _capture(prefix + "_12_after.png")
	GameState.merge_performed.disconnect(_on_merge)
	await _settle()
	await _teardown()


func _on_merge(_tier: int, _p: Vector2) -> void:
	_merge_frames = 0


# --- 3) x3 zincir: 2+2 -> 3 (yaninda 3) -> 4 (yaninda 4) -> 5 ---

func _seq_combo() -> void:
	# Level 9: hedef tier 8, zincir 5'e kadar cikinca round bitmez.
	await _make_board("res://resources/levels/level_09.tres")
	var cx: float = _board._center_x()
	var y: float = _board.FLOOR_Y
	# Soldan saga tabanda birbirine degen T2, T3, T4; T2'nin ustune T2
	# dusuyor: 2+2=3 (yanindaki 3'e deger) -> 4 (yanindaki 4'e) -> 5 = x3.
	var x2: float = cx - 150.0
	var x3: float = x2 + 27.0 + 34.0 + 1.0
	var x4: float = x3 + 34.0 + 42.0 + 1.0
	_spawn(2, Vector2(x2, y - 27.0 - 4.0))
	_spawn(3, Vector2(x3, y - 34.0 - 4.0))
	_spawn(4, Vector2(x4, y - 42.0 - 4.0))
	await _settle(120)
	_spawn(2, Vector2(x2 + 6.0, y - 27.0 - 260.0))
	var best: int = 0
	for i in 240:
		await get_tree().physics_frame
		if _board._combo_count > best:
			best = _board._combo_count
			if best >= 2:
				await _frames(4)
				await _capture("13_combo.png")
		if best >= 3:
			break
	print("combo peak: x%d" % best)
	await _settle()
	await _teardown()


# --- 4) Tehlike: kap dolu, tasma sayaci yarida ---

func _seq_danger() -> void:
	await _make_board("res://resources/levels/level_10.tres")
	var cx: float = _board._center_x()
	# En dar kap (370): hepsi FARKLI tier (merge olmasin). Siralar:
	# T8+T7 (362 px yan yana, 200 yuksek) / T6+T5 (130) / T4+T3+T2 (84)
	# = 414 px > 400 px oynanabilir yukseklik -> ust sira tasma bandina girer.
	var rows: Array = [[8, 7], [6, 5], [4, 3, 2]]
	var y: float = _board.FLOOR_Y
	for row: Array in rows:
		var widths: float = 0.0
		for tier: int in row:
			widths += 2.0 * TierConfig.radius(tier)
		var x: float = cx - widths * 0.5
		var tallest: float = 0.0
		for tier: int in row:
			var r: float = TierConfig.radius(tier)
			_spawn(tier, Vector2(x + r, y - r - 4.0))
			x += 2.0 * r
			tallest = maxf(tallest, 2.0 * r)
		await _settle(90)
		y -= tallest
	# Ustune ikinci bir T8: level modunda T8'ler birlesmez (annihilation
	# yalnizca sonsuz modda), govdesi tasma cizgisine oturur.
	_spawn(8, Vector2(cx, y - 100.0 - 4.0))
	# Nabzin tepesine yakin bir kare: overflow >= 0.6 sn VE pulse > 0.85.
	for i in 400:
		await get_tree().physics_frame
		if _board._overflow_elapsed >= 0.6 and _board._danger_pulse > 0.85:
			break
	print("danger: overflow_elapsed %.2f  overflowing %s  bodies_in_area %d" % [
		_board._overflow_elapsed, _board._is_overflowing(),
		_board._overflow_area.get_overlapping_bodies().size()])
	await _capture("14_danger.png")
	await _teardown()


# --- 5) Hedef tamam: level 1 (tier 4) ---

func _seq_goal() -> void:
	await _make_board()
	var cx: float = _board._center_x()
	var r: float = TierConfig.radius(3)
	_spawn(3, Vector2(cx - r - 4.0, _board.FLOOR_Y - r - 10.0))
	await _settle(90)
	_spawn(3, Vector2(cx - r - 4.0 + r * 0.5, _board.FLOOR_Y - r - 240.0))
	for i in 300:
		await get_tree().physics_frame
		if _board._is_finished:
			break
	await _frames(12)
	await _capture("15_goal_complete.png")
	await _frames(20)
	await _teardown()
