extends Node
## Temas / yigin test rig'i (M8.5-11). Dev araci — oyun calisirken kullanilmaz.
##
## Deterministik sahneler: parcalar sabit konumlara SPAWN ediliyor (drop
## bag / girdi yok), fizik ayni makinede ayni sonucu veriyor. Her sahne
## icin ekran goruntusu + olcum satiri basiliyor:
##
##   lineup_tN   : ayni tier'dan 10 parca tabana yan yana (merge KAPALI —
##                 temas geometrisi; owner'in yatay sira gorseli)
##   pile_contact: karisik 15 parca yigin, en dar kap (merge KAPALI)
##   pile_merge  : ayni yigin, merge ACIK (zincir sayisi, yukseklik)
##   wall_tN     : duvara yaslanan parca
##   large       : T7+T7+T8 temas
##   stress      : 34 canli parca + zincir merge (performans)
##
## Olcumler: settle suresi (tum govdeler uyuyana / |v| < 4 px/sn), yigin
## yuksekligi (en ust govde ust kenari -> taban), merge sayisi, kap disina
## kacan/tunelleyen govde, overlap artefakti (merkez mesafesi r1+r2-2'den
## kucuk cift), en uzun kare suresi.
##
## `--headless` ILE CALISTIRILAMAZ (cekimler bos cikar; olcumler basilir).
##
## Kullanim:
##   godot --path . res://tools/contact_rig.tscn -- <cikti_klasoru> [GxY]

const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const LEVEL_PATH: String = "res://resources/levels/level_01.tres"
const NARROW_LEVEL_PATH: String = "res://resources/levels/level_10.tres"
const SHOT_SIZE := Vector2i(540, 960)
const SETTLE_SPEED: float = 4.0
const SETTLE_MAX: float = 8.0

var _out_dir: String = ""
var _board: Node2D
var _worst_frame_ms: float = 0.0
var _merges: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(_shot_size(args))
	await get_tree().process_frame

	for tier in [1, 2, 4]:
		await _scene_lineup(tier)
	await _scene_pile(false)
	await _scene_pile(true)
	await _scene_wall(1)
	await _scene_wall(5)
	await _scene_large()
	await _scene_stress()
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


# --- Kurulum ---

func _make_board(level_path: String = LEVEL_PATH) -> void:
	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(load(level_path))
	add_child(_board)
	# HUD ve onizleme cekimde gereksiz; taban/duvar ve parcalar kalsin.
	_board.get_node("HUD").visible = false
	_board.get_node("Preview").visible = false
	await get_tree().process_frame


func _teardown() -> void:
	if _board != null and is_instance_valid(_board):
		_board.queue_free()
	_board = null
	await get_tree().process_frame


func _spawn(tier: int, at: Vector2, allow_merge: bool = true) -> Dumpling:
	var d: Dumpling = _board._spawn_dumpling(tier, at)
	if not allow_merge:
		# is_merging = true: _on_body_entered merge yolunu atlar, squash ve
		# fizik aynen calisir. Sadece temas geometrisine bakmak icin.
		d.is_merging = true
	return d


func _bodies() -> Array[Dumpling]:
	var out: Array[Dumpling] = []
	for child in _board._dumpling_layer.get_children():
		var d := child as Dumpling
		if d != null and is_instance_valid(d) and not d.is_queued_for_deletion():
			out.append(d)
	return out


## Deterministik bekleme: duvar saati degil fizik karesi (zamanlayici
## karelere gore kayip spawn'i bir kare oynatabiliyordu).
func _wait_physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


## Tum govdeler durana kadar bekler; gecen sureyi dondurur.
func _settle() -> float:
	var t: float = 0.0
	var start: int = Time.get_ticks_usec()
	while t < SETTLE_MAX:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var frame_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0 \
			+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		_worst_frame_ms = maxf(_worst_frame_ms, frame_ms)
		var moving: bool = false
		for d in _bodies():
			if d.linear_velocity.length() > SETTLE_SPEED:
				moving = true
				break
		if not moving and t > 0.5:
			break
	return t


func _pile_height() -> float:
	var top: float = _board.FLOOR_Y
	for d in _bodies():
		top = minf(top, d.global_position.y - TierConfig.radius(d.tier))
	return _board.FLOOR_Y - top


func _escaped() -> int:
	var n: int = 0
	for d in _bodies():
		var p: Vector2 = d.global_position
		if p.x < _board._left_x() - 2.0 or p.x > _board._right_x() + 2.0 \
				or p.y > _board.FLOOR_Y + 2.0:
			n += 1
	return n


## Merkez mesafesi yaricaplar toplaminin 2 px'ten fazla altina inen ciftler
## — fizik penetrasyonu (gorsel overlap DEGIL; o audit'te analitik).
func _overlap_artefacts() -> int:
	var list: Array[Dumpling] = _bodies()
	var n: int = 0
	for i in list.size():
		for j in range(i + 1, list.size()):
			var limit: float = TierConfig.radius(list[i].tier) + TierConfig.radius(list[j].tier) - 2.0
			if list[i].global_position.distance_to(list[j].global_position) < limit:
				n += 1
	return n


func _count_merge(_tier: int, _p: Vector2) -> void:
	_merges += 1


func _report(name: String, settle: float, merges: int) -> void:
	print("%-12s settle %.2fs  pile_h %6.1f  bodies %2d  merges %2d  escaped %d  overlap %d" % [
		name, settle, _pile_height(), _bodies().size(), merges, _escaped(), _overlap_artefacts()])


# --- Sahneler ---

## Ayni tier 10 parca, tabana yan yana. Merkezler 2r + 1 px arayla: fizik
## onlari tam temasa itiyor, sprite'lar arasi bosluk audit'in gapAB'si.
func _scene_lineup(tier: int) -> void:
	await _make_board()
	var r: float = TierConfig.radius(tier)
	var count: int = mini(10, int(floor(_board.level.container_width / (2.0 * r + 1.0))))
	var total: float = count * (2.0 * r + 1.0)
	var x0: float = _board._center_x() - total * 0.5 + r
	for i in count:
		_spawn(tier, Vector2(x0 + i * (2.0 * r + 1.0), _board.FLOOR_Y - r - 40.0), false)
	var settle: float = await _settle()
	_report("lineup_t%d" % tier, settle, 0)
	await _capture("lineup_t%d.png" % tier)
	await _teardown()


## Karisik 15 parca, EN DAR kapta (level 10, 370 px) — gercek bir yigin.
## `merge_on` false: yalnizca temas geometrisi (capraz/dikey temaslar);
## true: zincir merge sayisi ve yigin yuksekligi.
func _scene_pile(merge_on: bool) -> void:
	await _make_board(NARROW_LEVEL_PATH)
	_merges = 0
	GameState.merge_performed.connect(_count_merge)
	var pattern: Array[int] = [3, 1, 2, 4, 1, 3, 2, 5, 1, 2, 3, 1, 4, 2, 1]
	var cx: float = _board._center_x()
	for i in pattern.size():
		var x: float = cx + ((i % 3) - 1) * 110.0 + ((i / 3) % 2) * 35.0
		var y: float = _board.FLOOR_Y - 80.0 - (i / 3) * 120.0
		_spawn(pattern[i], Vector2(x, y), merge_on)
		if i % 3 == 2:
			await _wait_physics(24)
	var settle: float = await _settle()
	GameState.merge_performed.disconnect(_count_merge)
	var name: String = "pile_merge" if merge_on else "pile_contact"
	_report(name, settle, _merges)
	await _capture(name + ".png")
	await _teardown()


func _scene_wall(tier: int) -> void:
	await _make_board()
	var r: float = TierConfig.radius(tier)
	_spawn(tier, Vector2(_board._left_x() + r + 6.0, _board.FLOOR_Y - r - 60.0), false)
	_spawn(tier, Vector2(_board._right_x() - r - 6.0, _board.FLOOR_Y - r - 60.0), false)
	var settle: float = await _settle()
	_report("wall_t%d" % tier, settle, 0)
	await _capture("wall_t%d.png" % tier)
	await _teardown()


func _scene_large() -> void:
	await _make_board()
	var cx: float = _board._center_x()
	_spawn(7, Vector2(cx - 82.0, _board.FLOOR_Y - 81.0 - 20.0), false)
	_spawn(7, Vector2(cx + 82.0, _board.FLOOR_Y - 81.0 - 20.0), false)
	_spawn(8, Vector2(cx, _board.FLOOR_Y - 81.0 * 2.0 - 100.0 - 60.0), false)
	var settle: float = await _settle()
	_report("large", settle, 0)
	await _capture("large.png")
	await _teardown()


## 34 canli parca + zincir merge + guc efekti: en kotu kare suresi.
func _scene_stress() -> void:
	await _make_board()
	_worst_frame_ms = 0.0
	_merges = 0
	GameState.merge_performed.connect(_count_merge)
	var cx: float = _board._center_x()
	# 5 sira x 7 = 35 parca; ayni tier'lar yan yana -> zincir merge.
	var pattern: Array[int] = [1, 1, 2, 1, 1, 2, 3]
	for row in 5:
		for col in 7:
			var tier: int = pattern[(col + row) % pattern.size()]
			_spawn(tier, Vector2(cx + (col - 3) * 78.0, _board.FLOOR_Y - 60.0 - row * 90.0), true)
		await _wait_physics(15)
	var settle: float = await _settle()
	GameState.merge_performed.disconnect(_count_merge)
	_report("stress", settle, _merges)
	print("stress worst frame: %.1f ms" % _worst_frame_ms)
	await _capture("stress.png")
	await _teardown()
