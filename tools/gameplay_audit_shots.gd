extends Node
## M8.7-01 — final gameplay experience audit capture harness. Dev aracı —
## oyun çalışırken kullanılmaz. `--headless` İLE ÇALIŞTIRILAMAZ (çekim).
##
## Gerçek GameBoard + production HUD üzerinde, deterministik yerleşimlerle
## §25'teki 29 durumu FİZİK KARESİ indeksli kare dizileri olarak yakalar,
## her senaryonun zamanlamasını (kare sayısı), ses olaylarını (AudioManager
## play_count farkı) ve titreşim isteklerini (Haptics sink) loglar; `perf`
## grubunda kare süresi / düğüm / tween / parçacık / fizik gövde ölçer.
##
## RUNTIME'A DOKUNMAZ: yalnızca mevcut board API'sini çağırır. Kayıt:
## SaveManager.data bellekte değiştirilir (güç stoğu), çıkışta dosyanın
## başlangıçtaki BYTE'ları geri yazılır (güç tüketimi save_game çağırır).
##
## Kullanım:
##   godot --path . res://tools/gameplay_audit_shots.tscn -- <çıktı> [GxY] [safe=61] [groups=drop,merge]
##
## Gruplar: states drop merge chain danger bomb upgrade shake cleaner protect goal perf
##          polish (M8.7-02: §24 önce/sonra dizileri — merge 01–03, zincir 04–06,
##          sarsıntı 07–09, Büyütücü 10–13, kazanma 14–16; fx/etiket/patlama ölçümleri)
## Dosya adı: <grup>/<NN>_<durum>[_fK]_<GxY>[_a36].png — K = senaryo başından
## itibaren fizik karesi (60 Hz → K/60 sn).

const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const SHOT_SIZE := Vector2i(720, 1280)
## Yerleşmiş sayılan hız eşiği (px/sn) — feel_shots/shell_shots ile aynı.
const SETTLE_SPEED: float = 4.0

var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _safe_top: float = -1.0
var _groups: PackedStringArray = PackedStringArray()
var _board: Node2D = null
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _saved_data: Dictionary = {}
## Senaryo başından itibaren fizik karesi sayacı.
var _pf: int = 0
## Bekleyen kareler: [dosya, Image] — PNG yazımı senaryo sonunda (yakalama
## sırasında fizik gerçek zamanda akmaya devam ettiği için yazma gecikmesi
## kare indekslerini bozmasın).
var _pending: Array = []
var _log_lines: PackedStringArray = PackedStringArray()
var _timings: Array[Dictionary] = []
var _audio_before: Dictionary = {}
var _haptic_log: Array[Dictionary] = []
var _shot_count: int = 0
## Perf ölçümü.
var _perf_active: bool = false
var _perf_frames: int = 0
var _perf_delta_max: float = 0.0
var _perf_delta_sum: float = 0.0
var _perf_delta_over_20ms: int = 0
var _perf_nodes_max: int = 0
var _perf_bodies_max: int = 0
var _perf_pairs_max: int = 0
var _perf_tweens_max: int = 0
var _perf_particles_max: int = 0
var _perf_fx_max: int = 0
var _perf_process_ms_max: float = 0.0
var _perf_physics_ms_max: float = 0.0
var _perf_process_ms_sum: float = 0.0
var _perf_physics_ms_sum: float = 0.0
var _perf_over_8ms: int = 0
var _perf_over_16ms: int = 0
## Duvar saati kare aralığı (µs): perf sırasında fps tavanı ve vsync KAPALI —
## "ne kadar hızlı çizebiliyor" ölçüsü; Godot'un process delta'sı jitter-fix
## ile sabit 16.67 ms raporladığı için kullanılamıyor.
var _perf_last_usec: int = 0
var _perf_wall_max_ms: float = 0.0
var _perf_wall_sum_ms: float = 0.0
var _perf_wall_over_16ms: int = 0
var _perf_wall_over_33ms: int = 0
## En uzun karenin senaryo içindeki fizik karesi indeksi (hangi olayla çakıştı?).
var _perf_wall_max_pf: int = -1
var _perf_pf0: int = 0
var _perf_results: Array[Dictionary] = []


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://gameplay_audit")
	for i in range(1, args.size()):
		var arg: String = String(args[i])
		if arg.begins_with("safe="):
			_safe_top = float(arg.trim_prefix("safe="))
		elif arg.begins_with("groups="):
			_groups = arg.trim_prefix("groups=").split(",", false)
		elif arg.contains("x"):
			var parts: PackedStringArray = arg.split("x")
			if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
				_size = Vector2i(int(parts[0]), int(parts[1]))
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(_size)
	# Kare = fizik adımı (60 Hz) olsun: kare indeksleri 1/60 sn anlamına gelsin.
	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 60

	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_saved_data = SaveManager.data.duplicate(true)
	# Güç stoğu bellekte şişirilir; skin varsayılan (temas denetimi skin'siz).
	var stock: Dictionary = {}
	for type in PowerUp.all():
		stock[PowerUp.save_key(type)] = 9
	SaveManager.data["powerups"] = stock
	SaveManager.data["equipped_skin"] = ""
	Haptics.set_sink(_on_haptic, true)
	Haptics.reset_counters()

	_log("=== gameplay_audit_shots %s safe=%.0f groups=%s ===" % [_tag(), _safe_top, ",".join(_groups)])
	_log("engine: godot %s  physics %d Hz  gravity %.0f" % [Engine.get_version_info()["string"],
		Engine.physics_ticks_per_second, ProjectSettings.get_setting("physics/2d/default_gravity")])
	await get_tree().process_frame
	await get_tree().process_frame

	if _want("states"):
		await _group_states()
	if _want("drop"):
		await _group_drop()
	if _want("merge"):
		await _group_merge()
	if _want("chain"):
		await _group_chain()
	if _want("danger"):
		await _group_danger()
	if _want("bomb"):
		await _group_bomb()
	if _want("upgrade"):
		await _group_upgrade()
	if _want("shake"):
		await _group_shake()
	if _want("cleaner"):
		await _group_cleaner()
	if _want("protect"):
		await _group_protect()
	if _want("goal"):
		await _group_goal()
	if _want("perf"):
		await _group_perf()
	if _want("polish"):
		await _group_polish()

	await _teardown()
	_write_reports()
	_restore_save()
	Haptics.set_sink(Callable(), false)
	print("bitti -> %s (%d kare)" % [_out_dir, _shot_count])
	get_tree().quit()


# --- Altyapı -------------------------------------------------------------------

func _want(group: String) -> bool:
	return _groups.is_empty() or _groups.has(group)


func _tag() -> String:
	return "%dx%d%s" % [_size.x, _size.y, "_a36" if _safe_top >= 0.0 else ""]


func _physics_process(_delta: float) -> void:
	_pf += 1


func _process(delta: float) -> void:
	if not _perf_active:
		return
	_perf_frames += 1
	var now_usec: int = Time.get_ticks_usec()
	if _perf_last_usec > 0:
		var wall_ms: float = float(now_usec - _perf_last_usec) / 1000.0
		if wall_ms > _perf_wall_max_ms:
			_perf_wall_max_ms = wall_ms
			_perf_wall_max_pf = _pf - _perf_pf0
		_perf_wall_sum_ms += wall_ms
		if wall_ms > 16.7:
			_perf_wall_over_16ms += 1
		if wall_ms > 33.4:
			_perf_wall_over_33ms += 1
	_perf_last_usec = now_usec
	_perf_delta_max = maxf(_perf_delta_max, delta)
	_perf_delta_sum += delta
	if delta > 0.020:
		_perf_delta_over_20ms += 1
	_perf_nodes_max = maxi(_perf_nodes_max, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	_perf_bodies_max = maxi(_perf_bodies_max, int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)))
	_perf_pairs_max = maxi(_perf_pairs_max, int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)))
	var pm: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var xm: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_perf_process_ms_max = maxf(_perf_process_ms_max, pm)
	_perf_physics_ms_max = maxf(_perf_physics_ms_max, xm)
	_perf_process_ms_sum += pm
	_perf_physics_ms_sum += xm
	if pm + xm > 8.0:
		_perf_over_8ms += 1
	if pm + xm > 16.0:
		_perf_over_16ms += 1
	_perf_tweens_max = maxi(_perf_tweens_max, get_tree().get_processed_tweens().size())
	if _board != null and is_instance_valid(_board):
		var particles: int = 0
		var fx: int = 0
		for child in _board.get_children():
			if child is CPUParticles2D and (child as CPUParticles2D).emitting:
				particles += 1
			elif child is Sprite2D or child is Label:
				fx += 1
			elif child.get_script() != null and child.name.begins_with("PopEffect"):
				particles += 1
			elif child.has_node("Dots"):
				particles += 1
		_perf_particles_max = maxi(_perf_particles_max, particles)
		_perf_fx_max = maxi(_perf_fx_max, fx)


func _on_haptic(duration_ms: int, amplitude: float) -> void:
	_haptic_log.append({"pf": _pf, "ms": duration_ms, "amp": amplitude})


func _log(line: String) -> void:
	print(line)
	_log_lines.append(line)


func _timing(scene: String, event: String, frames: int, note: String = "") -> void:
	_timings.append({"scene": scene, "event": event, "frames": frames,
		"ms": int(round(float(frames) * 1000.0 / 60.0)), "note": note})
	_log("  timing  %-14s %-34s %4d kare = %5d ms  %s" % [scene, event, frames,
		int(round(float(frames) * 1000.0 / 60.0)), note])


## Senaryo başlangıcı: kare sayacı, ses ve titreşim anlık görüntüsü.
func _begin(scene: String) -> void:
	_pf = 0
	_haptic_log.clear()
	_audio_before = AudioManager.play_count.duplicate(true)
	_log("--- %s ---" % scene)


## Senaryo sonu: ses olay farkı ve titreşim listesi loglanır.
func _end(scene: String) -> void:
	var diff: PackedStringArray = PackedStringArray()
	for id in AudioManager.play_count.keys():
		var n: int = int(AudioManager.play_count[id]) - int(_audio_before.get(id, 0))
		if n > 0:
			diff.append("%s×%d" % [id, n])
	diff.sort()
	var haptics: PackedStringArray = PackedStringArray()
	for h in _haptic_log:
		haptics.append("f%d:%dms@%.2f" % [h["pf"], h["ms"], h["amp"]])
	_log("  audio   %-14s %s" % [scene, " ".join(diff) if not diff.is_empty() else "(yok)"])
	_log("  haptic  %-14s %s" % [scene, " ".join(haptics) if not haptics.is_empty() else "(yok)"])


## Kareyi BELLEĞE alır; PNG yazımı _flush() ile.
func _shot(group: String, name: String, with_frame: bool = true) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var file: String = "%s_%s.png" % [name, _tag()]
	if with_frame:
		file = "%s_f%03d_%s.png" % [name, _pf, _tag()]
	_pending.append([group.path_join(file), img])


func _flush() -> void:
	for item in _pending:
		var rel: String = item[0]
		var dir: String = _out_dir.path_join(rel.get_base_dir())
		DirAccess.make_dir_recursive_absolute(dir)
		var err: int = (item[1] as Image).save_png(_out_dir.path_join(rel))
		_shot_count += 1
		print(("kaydedildi : " if err == OK else "HATA       : "), rel)
	_pending.clear()


func _make_board(level: String, keep_tutorial: bool = false) -> void:
	await _teardown()
	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(load(level))
	add_child(_board)
	await get_tree().process_frame
	if _safe_top >= 0.0:
		_board._apply_layout(Vector2(_size), _safe_top)
	if not keep_tutorial:
		_board._dismiss_tutorial()
	await get_tree().process_frame


func _teardown() -> void:
	if _board != null and is_instance_valid(_board):
		_board.queue_free()
		_board = null
		await get_tree().process_frame
		await get_tree().process_frame


func _spawn(tier: int, at: Vector2) -> Dumpling:
	return _board._spawn_dumpling(tier, at)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _max_speed() -> float:
	var best: float = 0.0
	for child in _board._dumpling_layer.get_children():
		var d := child as Dumpling
		if d != null and is_instance_valid(d) and not d.is_queued_for_deletion():
			best = maxf(best, d.linear_velocity.length())
	return best


## Tüm parçalar SETTLE_SPEED altında ART ARDA `quiet` kare kalana kadar bekler
## (tek kare eşiği sekme tepesinde — hız ~0 — yanlış pozitif veriyordu).
func _settle(max_frames: int = 300, min_frames: int = 20, quiet: int = 8) -> int:
	var start: int = _pf
	var calm: int = 0
	for i in max_frames:
		await get_tree().physics_frame
		calm = calm + 1 if _max_speed() <= SETTLE_SPEED else 0
		if i >= min_frames and calm >= quiet:
			break
	return _pf - start


## Yığının en üst noktası (dünya y; küçük = yüksek).
func _pile_top() -> float:
	var top: float = _board.FLOOR_Y
	for child in _board._dumpling_layer.get_children():
		var d := child as Dumpling
		if d != null and is_instance_valid(d):
			top = minf(top, d.global_position.y - TierConfig.radius(d.tier))
	return top


func _count() -> int:
	var n: int = 0
	for child in _board._dumpling_layer.get_children():
		if child is Dumpling and not child.is_queued_for_deletion():
			n += 1
	return n


## Satır satır yığın (shell_shots ile aynı yerleşim): alttan üste tier listeleri.
func _pile(rows: Array, no_merge: bool = false) -> void:
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
			var piece: Dumpling = _spawn(t, Vector2(clampf(x, left + r, right - r), y - r))
			if no_merge:
				piece.is_merging = true
			x += r + 3.0
			row_h = maxf(row_h, r * 2.0)
		y -= row_h + 4.0
		await _frames(12)
	await _settle()


## Taşma çizgisine `gap` px kalana kadar küçük parçalar (1-2-3 döngüsü,
## kaydırmalı x) bırakır; taşma başlarsa en üst parçayı kaldırır. Gerçek
## oyundaki gibi merge olabilir — "taşmaya yakın yığın" bileşimi serbest.
func _fill_to_line(gap: float) -> void:
	var cx: float = _board._center_x()
	var half: float = _board.level.container_width * 0.5 - 60.0
	for i in 40:
		if _pile_top() - _board.overflow_line_y() <= gap:
			break
		var tier: int = 1 + (i % 3)
		var x: float = cx + half * sin(float(i) * 1.7)
		_spawn(tier, Vector2(x, _board.overflow_line_y() - 140.0))
		await _settle(150, 15)
	for attempt in 4:
		if not _board._is_overflowing():
			break
		var top_piece: Dumpling = null
		for child in _board._dumpling_layer.get_children():
			var d := child as Dumpling
			if d != null and (top_piece == null or d.global_position.y < top_piece.global_position.y):
				top_piece = d
		_board._pop_and_free(top_piece)
		await _settle()
	_board._overflow_elapsed = 0.0


func _find(tier: int, highest: bool = true) -> Dumpling:
	var best: Dumpling = null
	for child in _board._dumpling_layer.get_children():
		var d := child as Dumpling
		if d == null or not is_instance_valid(d) or d.tier != tier or d.is_merging:
			continue
		if best == null or (d.global_position.y < best.global_position.y) == highest:
			best = d
	return best


func _last_dumpling() -> Dumpling:
	var children: Array = _board._dumpling_layer.get_children()
	for i in range(children.size() - 1, -1, -1):
		var d := children[i] as Dumpling
		if d != null and is_instance_valid(d):
			return d
	return null


# --- states: 01–04 + temas dizilişleri --------------------------------------------

func _group_states() -> void:
	# 01 boş board + aktif tier 1 (önizleme görünür).
	_begin("01_empty")
	await _make_board("res://resources/levels/level_02.tres")
	_board._pending_tier = 1
	_board._next_tier = 2
	_board._refresh_preview()
	await _frames(2)
	await _shot("states", "01_empty_t1", false)
	_end("01_empty")

	# 01b level 1 ipucu (referans; approved UI, yalnız okunurluk bağlamı).
	await _make_board("res://resources/levels/level_01.tres", true)
	await _frames(2)
	await _shot("states", "01b_tutorial_l1", false)

	# 02 küçük yığın (5 parça).
	await _make_board("res://resources/levels/level_04.tres")
	await _pile([[3, 1, 4], [2, 3]])
	_begin("02_small")
	GameState.add_score(210)
	await _frames(2)
	await _shot("states", "02_small_pile", false)
	_end("02_small")

	# 03 orta yığın (11 parça).
	await _make_board("res://resources/levels/level_04.tres")
	await _pile([[5, 3, 5, 3], [2, 4, 2, 4], [1, 3, 1]])
	_begin("03_medium")
	GameState.add_score(1240)
	await _frames(2)
	await _shot("states", "03_medium_pile", false)
	_log("  pile top %.0f  (line %.0f, gap %.0f px)  overflowing=%s" % [_pile_top(),
		_board.overflow_line_y(), _pile_top() - _board.overflow_line_y(), _board._is_overflowing()])
	_end("03_medium")

	# 04 taşmaya yakın (en dar kap): çizginin hemen altında, taşma YOK.
	await _make_board("res://resources/levels/level_10.tres")
	await _pile([[7, 6], [5, 4, 3], [2, 1, 2]])
	await _fill_to_line(70.0)
	# Doldururken oluşan zincirin rozeti/etiketi sönsün (COMBO_WINDOW 1.2 s).
	await _frames(90)
	_begin("04_near_overflow")
	GameState.add_score(4810)
	await _frames(2)
	await _shot("states", "04_near_overflow", false)
	_log("  pile top %.0f  (line %.0f, gap %.0f px)  overflowing=%s  elapsed=%.2f" % [_pile_top(),
		_board.overflow_line_y(), _pile_top() - _board.overflow_line_y(), _board._is_overflowing(),
		_board._overflow_elapsed])
	_end("04_near_overflow")

	# Temas dizilişi: 8 tier tabanda yan yana (sonsuz mod kabı, iki grup).
	_begin("contact")
	await _make_board("res://resources/levels/endless.tres")
	var x: float = _board._left_x() + 8.0
	for tier in range(1, 6):
		var r: float = TierConfig.radius(tier)
		_spawn(tier, Vector2(x + r, _board.FLOOR_Y - r - 2.0))
		x += 2.0 * r + 2.0
	await _settle()
	await _shot("states", "contact_lineup_t1_t5", false)
	_log_contacts("lineup_t1_t5")
	await _make_board("res://resources/levels/endless.tres")
	x = _board._left_x() + 8.0
	for tier in range(6, 9):
		var r: float = TierConfig.radius(tier)
		_spawn(tier, Vector2(x + r, _board.FLOOR_Y - r - 2.0))
		x += 2.0 * r + 2.0
	await _settle()
	await _shot("states", "contact_lineup_t6_t8", false)
	_log_contacts("lineup_t6_t8")
	# Dikey temas: farklı tier'lar üst üste (merge yok) + duvar teması.
	await _make_board("res://resources/levels/level_04.tres")
	var cx: float = _board._center_x()
	_spawn(6, Vector2(cx, _board.FLOOR_Y - 65.0 - 2.0))
	_spawn(1, Vector2(_board._left_x() + 22.0, _board.FLOOR_Y - 22.0 - 2.0))
	_spawn(5, Vector2(_board._right_x() - 52.0, _board.FLOOR_Y - 52.0 - 2.0))
	await _settle()
	_spawn(4, Vector2(cx + 10.0, _board.FLOOR_Y - 130.0 - 42.0 - 60.0))
	await _settle()
	_spawn(2, Vector2(cx - 30.0, _board.FLOOR_Y - 130.0 - 84.0 - 27.0 - 60.0))
	await _settle()
	await _shot("states", "contact_stack", false)
	_log_contacts("stack")
	_end("contact")
	await _flush()


## Tabandaki parçaların fizik tabanı boşluğu ve yan yana boşlukları (dünya px).
func _log_contacts(label: String) -> void:
	var items: Array = []
	for child in _board._dumpling_layer.get_children():
		var d := child as Dumpling
		if d != null and is_instance_valid(d):
			items.append(d)
	items.sort_custom(func(a: Dumpling, b: Dumpling) -> bool: return a.global_position.x < b.global_position.x)
	var parts: PackedStringArray = PackedStringArray()
	for i in items.size():
		var d: Dumpling = items[i]
		var r: float = TierConfig.radius(d.tier)
		var floor_gap: float = _board.FLOOR_Y - (d.global_position.y + r)
		var side: String = ""
		if i + 1 < items.size():
			var e: Dumpling = items[i + 1]
			var gap: float = e.global_position.distance_to(d.global_position) - r - TierConfig.radius(e.tier)
			side = " →gap %.1f" % gap
		parts.append("T%d floor %.1f rot %.0f°%s" % [d.tier, floor_gap, rad_to_deg(d.rotation), side])
	_log("  contact %s: %s" % [label, " | ".join(parts)])


# --- drop: 05–07 ---------------------------------------------------------------------

func _group_drop() -> void:
	for spec in [[1, "t1_floor", []], [4, "t4_floor", []], [2, "t2_on_pile", [[4, 3, 4], [1]]]]:
		var tier: int = spec[0]
		var name: String = spec[1]
		var rows: Array = spec[2]
		_begin("drop_" + name)
		await _make_board("res://resources/levels/level_04.tres")
		if not rows.is_empty():
			await _pile(rows)
		var cx: float = _board._center_x()
		_board._pending_tier = tier
		_board._next_tier = 2
		_board._set_aim(cx + 8.0)
		_board._drop_cooldown = 0.0
		_board._refresh_preview()
		await _frames(2)
		_pf = 0
		await _shot("drop", "05_pre_drop_" + name)
		_board._drop()
		var d: Dumpling = _last_dumpling()
		var y0: float = d.global_position.y
		var release: int = _pf
		# Düşüş kareleri: her 6 karede bir, inişe kadar.
		var landed_pf: int = -1
		var vmax: float = 0.0
		var stretch_max: float = 0.0
		var visual: Node2D = d.get_node("Visual")
		var fit: Vector2 = visual.CONTACT_FIT[tier - 1]["scale"]
		for i in 240:
			await get_tree().physics_frame
			if not is_instance_valid(d):
				break
			vmax = maxf(vmax, d.linear_velocity.length())
			stretch_max = maxf(stretch_max, (visual.scale.y / maxf(0.001, visual.scale.x)) / (fit.y / fit.x))
			if d.has_landed:
				landed_pf = _pf
				break
			if (i + 1) % 8 == 0:
				await _shot("drop", "05_falling_" + name)
		if not is_instance_valid(d):
			_log("  HATA: parça düşerken birleşti/silindi (%s)" % name)
			_end("drop_" + name)
			await _flush()
			continue
		_timing("drop_" + name, "release→first impact", landed_pf - release,
			"vmax %.0f px/s, fall %.0f px, fall-stretch max %.3f" % [vmax, d.global_position.y - y0, stretch_max])
		await _shot("drop", "06_first_impact_" + name)
		# İniş sonrası: +1 +2 +4 +8 +16 kareler; sekme tepesi ve durulma.
		var apex: float = d.global_position.y
		var next_shots: Array = [1, 2, 4, 8, 16]
		var since: int = 0
		var settled_pf: int = -1
		var calm: int = 0
		for i in 300:
			await get_tree().physics_frame
			since += 1
			if not is_instance_valid(d):
				break
			apex = minf(apex, d.global_position.y)
			if next_shots.has(since):
				await _shot("drop", "06_after_impact_" + name)
			calm = calm + 1 if _max_speed() <= SETTLE_SPEED else 0
			if settled_pf < 0 and since > 6 and calm >= 8:
				settled_pf = _pf - 8
				break
		if not is_instance_valid(d):
			_log("  HATA: parça iniş sonrası silindi (%s)" % name)
			_end("drop_" + name)
			await _flush()
			continue
		var bounce_px: float = (d.global_position.y) - apex
		_timing("drop_" + name, "impact→settled (all <4 px/s)", settled_pf - landed_pf if settled_pf >= 0 else -1,
			"bounce apex %.1f px above rest%s" % [bounce_px, "" if settled_pf >= 0 else " - NOT settled within 300 frames (still rolling)"])
		await _shot("drop", "07_settle_" + name)
		# Mikro hareket: durulduktan sonra 90 kare boyunca en yüksek hız.
		var residual: float = 0.0
		var wake_frames: int = 0
		for i in 90:
			await get_tree().physics_frame
			var s: float = _max_speed()
			residual = maxf(residual, s)
			if s > SETTLE_SPEED:
				wake_frames += 1
		_log("  residual %s: max speed %.2f px/s over 90 frames after settle, %d frames >4 px/s, sleeping=%s" % [
			name, residual, wake_frames, d.sleeping])
		_end("drop_" + name)
		await _flush()

	# Nişan/hareket: sürükleme ile önizleme konumu (release tepkisi = anında).
	_begin("aim")
	await _make_board("res://resources/levels/level_04.tres")
	_board._pending_tier = 2
	_board._refresh_preview()
	_board._set_aim(_board._left_x() + 10.0)
	await _frames(2)
	await _shot("drop", "05_aim_left_clamped", false)
	_board._set_aim(_board._right_x() + 200.0)
	await _frames(2)
	await _shot("drop", "05_aim_right_clamped", false)
	_log("  aim clamp: pending T2 margin %.0f → x=%.0f (left %.0f) / x=%.0f (right %.0f)" % [
		TierConfig.radius(2), _board._left_x() + TierConfig.radius(2), _board._left_x(),
		_board._right_x() - TierConfig.radius(2), _board._right_x()])
	# Cooldown sırasında önizleme alfa 0.4.
	_board._set_aim(_board._center_x())
	_board._drop()
	await _frames(3)
	await _shot("drop", "05_cooldown_preview_dim", false)
	_log("  drop cooldown %.2f s → preview alpha %.2f during cooldown" % [_board.DROP_COOLDOWN, _board._preview.modulate.a])
	_end("aim")
	await _flush()


# --- merge: 08–11, her tier geçişi ------------------------------------------------

func _group_merge() -> void:
	for tier in range(1, 8):
		var name: String = "t%d_to_t%d" % [tier, tier + 1]
		_begin("merge_" + name)
		await _make_board("res://resources/levels/level_08.tres")
		var cx: float = _board._center_x()
		var r: float = TierConfig.radius(tier)
		var rest: Dumpling = _spawn(tier, Vector2(cx - r * 0.5, _board.FLOOR_Y - r - 6.0))
		await _settle(120)
		_pf = 0
		var falling: Dumpling = _spawn(tier, Vector2(cx - r * 0.5 + r * 0.55, _board.FLOOR_Y - r - 320.0))
		var merged_pf: int = -1
		var contact_pf: int = -1
		var near_shot: bool = false
		var merged: Array = [false]
		var cb := func(_t: int, _p: Vector2) -> void: merged[0] = true
		GameState.merge_performed.connect(cb)
		for i in 300:
			await get_tree().physics_frame
			if not merged[0] and is_instance_valid(falling) and is_instance_valid(rest):
				var dist: float = falling.global_position.distance_to(rest.global_position)
				if not near_shot and dist < 2.0 * r + 36.0:
					near_shot = true
					await _shot("merge", "08_approach_" + name)
				if contact_pf < 0 and dist <= 2.0 * r + 10.0:
					contact_pf = _pf
					await _shot("merge", "08_contact_" + name)
			if merged[0] and merged_pf < 0:
				merged_pf = _pf
				break
		GameState.merge_performed.disconnect(cb)
		if merged_pf < 0:
			_log("  HATA: merge olmadı (%s)" % name)
			_end("merge_" + name)
			await _flush()
			continue
		_timing("merge_" + name, "contact→resolve (deferred)", merged_pf - maxi(contact_pf, 0))
		# Yeni parça: aynı karede doğdu. Efekt kareleri.
		var born: Dumpling = _last_dumpling()
		await _shot("merge", "09_effect_" + name)
		var seq: Array = [1, 2, 3, 5, 8, 12, 20]
		var since: int = 0
		var shake_peak: float = _board._shake_strength
		var shake_end: int = -1
		var scale_max: float = 0.0
		var settled_at: int = -1
		var calm: int = 0
		var visual: Node2D = born.get_node("Visual") if is_instance_valid(born) else null
		for i in 150:
			await get_tree().physics_frame
			since += 1
			shake_peak = maxf(shake_peak, _board._shake_strength)
			if shake_end < 0 and shake_peak > 0.0 and _board._shake_strength <= 0.0:
				shake_end = _pf - merged_pf
			if visual != null and is_instance_valid(visual):
				scale_max = maxf(scale_max, visual.scale.x)
			calm = calm + 1 if _max_speed() <= SETTLE_SPEED else 0
			if settled_at < 0 and calm >= 8:
				settled_at = _pf - merged_pf - 8
			if seq.has(since):
				await _shot("merge", "09_effect_" + name)
			if since >= 24 and settled_at >= 0 and (shake_end >= 0 or shake_peak == 0.0):
				break
		_timing("merge_" + name, "camera shake decay", shake_end,
			"peak %.1f px (SHAKE_MIN_TIER %d)%s" % [shake_peak, _board.SHAKE_MIN_TIER,
			"" if shake_peak == 0.0 or shake_end >= 0 else " - not finished in window"])
		_log("  reveal %s: born tier %d, visual scale peak %.3f (play_reveal strength %.2f), pop score +%d, float label %s" % [
			name, born.tier if is_instance_valid(born) else -1, scale_max, 1.0 + 0.5 * _board._tier_t(tier + 1),
			TierConfig.merge_score(tier + 1), "yes" if tier + 1 >= _board.FLOAT_SCORE_MIN_TIER else "no (tier<4)"])
		_timing("merge_" + name, "resolve→new tier settled", settled_at,
			"" if settled_at >= 0 else "not settled in window")
		await _shot("merge", "10_settled_" + name)
		_end("merge_" + name)
		await _flush()


# --- chain: 12 ----------------------------------------------------------------------

func _group_chain() -> void:
	# Level 9 (hedef 8): 2+2 -> 3 (yaninda 3) -> 4 (yaninda 4) -> 5 = x3.
	# Dogan T4'un yanindaki T4'e ulasmasi yerlesme kaosuna bagli; birkac
	# deterministik x4 ofseti denenir, ilk x3 ureten tutulur (log'da).
	var got: int = 0
	for offset in [0.0, 6.0, -6.0, 12.0]:
		await _make_board("res://resources/levels/level_09.tres")
		var cx: float = _board._center_x()
		var y: float = _board.FLOOR_Y
		# Tabanda T3 | T4 yan yana; T2 ikisinin arasindaki vadide oturur.
		# Dusen T2 vadideki T2 ile birlesir -> dogan T3 alttaki T3'e deger ->
		# dogan T4 yandaki T4'e deger -> T5 (x3).
		var x3: float = cx - 60.0
		var x4: float = x3 + 34.0 + 42.0 + 1.0
		var x2: float = x3 + 30.0 + offset
		_spawn(3, Vector2(x3, y - 34.0 - 4.0))
		_spawn(4, Vector2(x4, y - 42.0 - 4.0))
		await _settle(90)
		_spawn(2, Vector2(x2, y - 120.0))
		await _settle(120)
		var valley: Dumpling = _find(2, true)
		x2 = valley.global_position.x if valley != null else x2
		_begin("chain_x3")
		_pf = 0
		_spawn(2, Vector2(x2, y - 27.0 - 300.0))
		var best: int = 0
		var merge_pfs: PackedInt32Array = PackedInt32Array()
		var merges: Array = [0]
		var cb := func(_t: int, _p: Vector2) -> void:
			merges[0] += 1
			merge_pfs.append(_pf)
		GameState.merge_performed.connect(cb)
		var last_count: int = 0
		var combo_zero_pf: int = -1
		var was_combo: bool = false
		var calm: int = 0
		for i in 320:
			await get_tree().physics_frame
			if merges[0] > last_count:
				last_count = merges[0]
				await _shot("chain", "12_chain_merge%d" % last_count)
				await _frames(3)
				await _shot("chain", "12_chain_merge%d_plus3" % last_count)
			if _board._combo_count > best:
				best = _board._combo_count
			if _board._combo_count >= 2:
				was_combo = true
			if was_combo and combo_zero_pf < 0 and _board._combo_count == 0:
				combo_zero_pf = _pf
			calm = calm + 1 if _max_speed() <= SETTLE_SPEED else 0
			if merges[0] >= 3 and combo_zero_pf >= 0 and calm >= 8:
				break
			if merges[0] < 3 and i > 200 and calm >= 8:
				break
		GameState.merge_performed.disconnect(cb)
		_log("  chain (x4 offset %+.0f): %d merges at frames %s, combo peak x%d, COMBO_WINDOW %.1f s" % [
			offset, merges[0], merge_pfs, best, _board.COMBO_WINDOW])
		for i in range(1, merge_pfs.size()):
			_timing("chain_x3", "merge %d -> merge %d gap" % [i, i + 1], merge_pfs[i] - merge_pfs[i - 1])
		if merge_pfs.size() > 0 and combo_zero_pf >= 0:
			_timing("chain_x3", "last merge -> combo badge cleared", combo_zero_pf - merge_pfs[merge_pfs.size() - 1],
				"COMBO_WINDOW %.1f s = %d frames" % [_board.COMBO_WINDOW, int(_board.COMBO_WINDOW * 60.0)])
		await _shot("chain", "12_chain_settled")
		_end("chain_x3")
		got = merges[0]
		if got >= 3:
			await _flush()
			break
		_pending.clear()
	if got < 3:
		_log("  UYARI: x3 zincir hicbir denemede olusmadi; son deneme kareleri yaziliyor")
		await _flush()

	# Eşzamanlı merge: iki ayrı çift AYNI karede birleşir (HUD skor pop tek label).
	await _make_board("res://resources/levels/level_09.tres")
	var cx: float = _board._center_x()
	var xl: float = cx - 110.0
	var xr: float = cx + 110.0
	_spawn(2, Vector2(xl, _board.FLOOR_Y - 27.0 - 4.0))
	_spawn(4, Vector2(xr, _board.FLOOR_Y - 42.0 - 4.0))
	await _settle(120)
	_begin("chain_simultaneous")
	_pf = 0
	# İki düşen parça aynı yükseklikten: T2 27 yarıçap, T4 42 → iniş aynı kareye
	# yakın olsun diye alt kenarları eşitlenir.
	# Esit dusus mesafesi (yerlesik parcanin tepesinden 200 px): ayni kare.
	_spawn(2, Vector2(xl + 4.0, _board.FLOOR_Y - 54.0 - 27.0 - 200.0))
	_spawn(4, Vector2(xr + 4.0, _board.FLOOR_Y - 84.0 - 42.0 - 200.0))
	var pfs: PackedInt32Array = PackedInt32Array()
	var cb2 := func(_t: int, _p: Vector2) -> void: pfs.append(_pf)
	GameState.merge_performed.connect(cb2)
	for i in 300:
		await get_tree().physics_frame
		if pfs.size() >= 1 and _pf == pfs[0]:
			await _shot("chain", "12_simultaneous_resolve")
		if pfs.size() >= 2:
			await _frames(2)
			await _shot("chain", "12_simultaneous_plus2")
			break
	GameState.merge_performed.disconnect(cb2)
	_log("  simultaneous: merges at frames %s (gap %d), HUD score pop text now '%s', combo x%d" % [
		pfs, (pfs[1] - pfs[0]) if pfs.size() >= 2 else -1, _board._score_pop.text, _board._combo_count])
	_end("chain_simultaneous")
	await _flush()


# --- danger: 13–16 -------------------------------------------------------------------

func _group_danger() -> void:
	_begin("danger")
	await _make_board("res://resources/levels/level_10.tres")
	var cx: float = _board._center_x()
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
	_pf = 0
	var top: Dumpling = _spawn(8, Vector2(cx, y - 100.0 - 4.0))
	# 13 tehlike başlangıcı: sayaç ilk kez > 0.
	var start_pf: int = -1
	var pulse_first_peak: int = -1
	var danger_audio_first: int = -1
	var audio_base: int = int(AudioManager.play_count.get(&"danger", 0))
	for i in 600:
		await get_tree().physics_frame
		if start_pf < 0 and _board._overflow_elapsed > 0.0:
			start_pf = _pf
			await _frames(2)
			await _shot("danger", "13_danger_start")
		if start_pf >= 0 and danger_audio_first < 0 and int(AudioManager.play_count.get(&"danger", 0)) > audio_base:
			danger_audio_first = _pf
		if start_pf >= 0 and pulse_first_peak < 0 and _board._danger_pulse > 0.95:
			pulse_first_peak = _pf
			await _shot("danger", "13_danger_first_peak")
		if start_pf >= 0 and _board._overflow_elapsed >= 0.7 and _board._danger_pulse > 0.9:
			await _shot("danger", "14_danger_sustained_peak")
			break
	_timing("danger", "top piece spawn → danger start", start_pf)
	_timing("danger", "danger start → first pulse peak", pulse_first_peak - start_pf)
	_timing("danger", "danger start → first danger tick audio", danger_audio_first - start_pf)
	# Nabız periyodu kaç kare (~1.9 Hz → 4.5 Hz): 0.4 sn ölç (grace dolmadan).
	var prev: float = _board._danger_pulse
	var rising: bool = false
	var peaks: PackedInt32Array = PackedInt32Array()
	for i in 24:
		await get_tree().physics_frame
		var p: float = _board._danger_pulse
		if p > prev:
			rising = true
		elif rising and p < prev:
			rising = false
			peaks.append(_pf)
		prev = p
	if peaks.size() >= 2:
		_timing("danger", "pulse period near grace end", peaks[peaks.size() - 1] - peaks[peaks.size() - 2],
			"peaks at %s, urgency %.2f" % [peaks, _board._danger_urgency])
	await _shot("danger", "14_danger_sustained_trough_or_peak")
	_log("  danger: elapsed %.2f / grace %.1f, pulse %.2f, urgency %.2f, wall glow peak alpha ≈ %.2f" % [
		_board._overflow_elapsed, _board.OVERFLOW_GRACE, _board._danger_pulse, _board._danger_urgency,
		lerpf(0.16, 0.48 + 0.14 * _board._danger_urgency, 1.0)])
	# 15 iyileşme: en üstteki parça kaldırılır → tehlike söner (anında mı?).
	var recover_pf: int = _pf
	var elapsed_at_removal: float = _board._overflow_elapsed
	_log("  recovery: removing top T8 at elapsed %.2f (fail_pending=%s)" % [elapsed_at_removal, _board.is_fail_pending()])
	_board._pop_and_free(top)
	var cleared_pf: int = -1
	for i in 120:
		await get_tree().physics_frame
		if cleared_pf < 0 and _board._overflow_elapsed == 0.0:
			cleared_pf = _pf
			await _shot("danger", "15_recovered")
			await _frames(1)
			await _shot("danger", "15_recovered")
			break
	_timing("danger", "top removed → danger cleared", cleared_pf - recover_pf if cleared_pf >= 0 else -1,
		"elapsed before removal %.2f; pulse after clear %.2f (fade-out? %s)" % [_board._overflow_elapsed if cleared_pf < 0 else 0.0,
		_board._danger_pulse, "no, snaps to 0" if _board._danger_pulse == 0.0 else "yes"])
	await _frames(20)
	await _shot("danger", "15_recovered_plus20")
	_end("danger")
	await _flush()

	# 16 taşma: grace dolana kadar bekle → fail-pending ("Taştı!", board donar).
	_begin("overflow")
	await _make_board("res://resources/levels/level_10.tres")
	y = _board.FLOOR_Y
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
	_pf = 0
	_spawn(8, Vector2(cx, y - 100.0 - 4.0))
	var d_start: int = -1
	var offered: Array = [-1]
	var cb := func(_remaining: int) -> void: offered[0] = _pf
	_board.revive_offered.connect(cb)
	var shots_done: Array = []
	for i in 900:
		await get_tree().physics_frame
		if d_start < 0 and _board._overflow_elapsed > 0.0:
			d_start = _pf
		if d_start >= 0:
			for mark in [0.5, 1.0, 1.4]:
				if not shots_done.has(mark) and _board._overflow_elapsed >= mark:
					shots_done.append(mark)
					await _shot("danger", "16_overflow_elapsed_%03d" % int(mark * 100.0))
		if offered[0] >= 0:
			break
	_board.revive_offered.disconnect(cb)
	_timing("overflow", "danger start → fail pending (grace)", offered[0] - d_start,
		"OVERFLOW_GRACE %.1f s = %d frames" % [_board.OVERFLOW_GRACE, int(_board.OVERFLOW_GRACE * 60.0)])
	await _frames(1)
	await _shot("danger", "16_overflow_fail_pending")
	await _frames(20)
	await _shot("danger", "16_overflow_fail_pending_plus20")
	_log("  overflow: fail_pending=%s frozen bodies=%d status='%s' danger_pulse %.2f (still pulsing while frozen? %s)" % [
		_board.is_fail_pending(), _count(), _board._status_label.text, _board._danger_pulse,
		"yes" if _board._overflow_elapsed > 0.0 else "no"])
	_end("overflow")
	await _flush()


# --- bomb: 17–18 ----------------------------------------------------------------------

func _group_bomb() -> void:
	await _make_board("res://resources/levels/level_06.tres")
	await _pile([[5, 3, 5, 3], [4, 2, 4, 2], [1, 3, 1]])
	_begin("bomb")
	_pf = 0
	_board._on_power_pressed(int(PowerUp.Type.BOMB))
	await _frames(1)
	await _shot("bomb", "17_bomb_armed")
	await _frames(5)
	await _shot("bomb", "17_bomb_armed_pulse")
	var targetable: int = 0
	for child in _board._dumpling_layer.get_children():
		if child is Dumpling and (child as Dumpling).get_node("Visual")._targetable:
			targetable += 1
	_log("  bomb armed: %d/%d targetable (pulse %.2f @ %.1f Hz), preview hidden=%s, slot armed=%s" % [
		targetable, _count(), 0.18, 6.0 / 2.0, not _board._preview.visible,
		_board._powerups.armed_type() == int(PowerUp.Type.BOMB)])
	var target: Dumpling = _find(4, false)
	if target == null:
		target = _find(3, false)
	var at: Vector2 = target.global_position
	var count_before: int = _count()
	_pf = 0
	_board._use_targeted_power(target)
	var use_pf: int = _pf
	await _shot("bomb", "18_bomb_lock_on")
	var seq: Array = [2, 4, 7, 10, 13, 15, 17, 18, 20, 23, 28, 36, 48]
	var removed_pf: int = -1
	var shake_peak: float = 0.0
	var since: int = 0
	for i in 60:
		await get_tree().physics_frame
		since += 1
		shake_peak = maxf(shake_peak, _board._shake_strength)
		if removed_pf < 0 and not is_instance_valid(target):
			removed_pf = _pf - use_pf
		if seq.has(since):
			await _shot("bomb", "18_bomb_seq")
	_timing("bomb", "use → target freed (travel)", removed_pf, "BOMB_TRAVEL %.2f s, shake peak %.1f px" % [_board.BOMB_TRAVEL, shake_peak])
	await _settle(200, 10)
	await _shot("bomb", "18_bomb_settled")
	_log("  bomb: pieces %d → %d, score %d (no score), stock bomb %d" % [count_before, _count(), GameState.score,
		SaveManager.powerup_count(PowerUp.Type.BOMB)])
	_end("bomb")
	await _flush()

	# İptal: silahlıyken boşluğa dokunma.
	await _make_board("res://resources/levels/level_06.tres")
	await _pile([[4, 3], [2]])
	_begin("bomb_cancel")
	_board._on_power_pressed(int(PowerUp.Type.BOMB))
	await _frames(2)
	var stock: int = SaveManager.powerup_count(PowerUp.Type.BOMB)
	_board._powerups.cancel()
	await _frames(2)
	await _shot("bomb", "17_bomb_cancelled", false)
	_log("  cancel: armed=%s stock %d→%d preview visible=%s" % [_board._powerups.is_armed(), stock,
		SaveManager.powerup_count(PowerUp.Type.BOMB), _board._preview.visible])
	_end("bomb_cancel")
	await _flush()


# --- upgrade: 19–21 -------------------------------------------------------------------

func _group_upgrade() -> void:
	for spec in [[3, "t3_to_t4", [[5, 3, 5], [2, 1, 2], [3]]], [7, "t7_to_t8", [[7, 6], [4, 3, 2]]]]:
		var tier: int = spec[0]
		var name: String = spec[1]
		await _make_board("res://resources/levels/level_08.tres")
		await _pile(spec[2])
		_begin("upgrade_" + name)
		_pf = 0
		_board._on_power_pressed(int(PowerUp.Type.UPGRADE))
		await _frames(1)
		await _shot("upgrade", "19_upgrade_armed_" + name)
		await _frames(5)
		await _shot("upgrade", "19_upgrade_armed_pulse_" + name)
		var t8s: int = 0
		var targetable: int = 0
		for child in _board._dumpling_layer.get_children():
			if child is Dumpling:
				if (child as Dumpling).tier >= 8:
					t8s += 1
				if (child as Dumpling).get_node("Visual")._targetable:
					targetable += 1
		_log("  upgrade armed (%s): %d/%d targetable (T8 count %d not targetable)" % [name, targetable, _count(), t8s])
		var target: Dumpling = _find(tier, true)
		var pos: Vector2 = target.global_position
		var count_before: int = _count()
		_pf = 0
		_board._use_targeted_power(target)
		await _shot("upgrade", "20_upgrade_transform_" + name if tier < 7 else "21_t7_to_t8")
		var born: Dumpling = _last_dumpling()
		var born_tier: int = born.tier if born != null else -1
		var visual: Node2D = born.get_node("Visual") if born != null else null
		var seq: Array = [1, 2, 4, 6, 9, 12, 18, 28, 40]
		var since: int = 0
		var scale_max: float = 0.0
		var shake_peak: float = 0.0
		for i in 48:
			await get_tree().physics_frame
			since += 1
			if visual != null and is_instance_valid(visual):
				scale_max = maxf(scale_max, visual.scale.x)
			shake_peak = maxf(shake_peak, _board._shake_strength)
			if seq.has(since):
				await _shot("upgrade", "20_upgrade_transform_" + name if tier < 7 else "21_t7_to_t8")
		_timing("upgrade_" + name, "transform (instant swap) + squash", 0,
			"squash 0.34/0.26 s, beam 0.46 s, ring 0.32 s; visual scale peak %.3f; shake peak %.1f px" % [scale_max, shake_peak])
		await _settle(200, 10)
		await _shot("upgrade", "20_upgrade_settled_" + name if tier < 7 else "21_t7_to_t8_settled")
		_log("  upgrade %s: born tier %d at same pos (Δ %.1f px), pieces %d→%d, score %d (no score), status '%s'" % [
			name, born_tier, born.global_position.distance_to(pos) if is_instance_valid(born) else -1.0,
			count_before, _count(), GameState.score, _board._status_label.text])
		_end("upgrade_" + name)
		await _flush()


# --- shake: 22–24 --------------------------------------------------------------------

func _group_shake() -> void:
	await _make_board("res://resources/levels/level_06.tres")
	await _pile([[6, 5, 4], [3, 4, 3, 2], [1, 2, 1, 3, 1], [2, 1, 2]])
	_begin("shake")
	_log("  pile: %d pieces after setup (pre-merges during stacking are before this window)" % _count())
	var top_before: float = _pile_top()
	var count_before: int = _count()
	var merges: Array = [0]
	var cb := func(_t: int, _p: Vector2) -> void: merges[0] += 1
	GameState.merge_performed.connect(cb)
	_pf = 0
	await _shot("shake", "22_shake_before")
	_board._use_shake()
	var use_pf: int = _pf
	await _shot("shake", "22_shake_start")
	var seq: Array = [2, 4, 6, 8, 12, 18, 30, 60, 120]
	var since: int = 0
	var vmax: float = 0.0
	var vmax_pf: int = 0
	var cam_max: float = 0.0
	var flash_end: int = -1
	var settled_pf: int = -1
	var top_min: float = _pile_top()
	for i in 240:
		await get_tree().physics_frame
		since += 1
		var s: float = _max_speed()
		if s > vmax:
			vmax = s
			vmax_pf = _pf - use_pf
		cam_max = maxf(cam_max, _board._camera.offset.length())
		top_min = minf(top_min, _pile_top())
		if flash_end < 0 and since > 1 and _board._shake_flash <= 0.0:
			flash_end = _pf - use_pf
		if settled_pf < 0 and since > 20 and s <= SETTLE_SPEED:
			settled_pf = _pf - use_pf
		if seq.has(since):
			await _shot("shake", "23_shake_seq")
		if settled_pf > 0 and since >= 120:
			break
	GameState.merge_performed.disconnect(cb)
	_timing("shake", "impulse → peak speed", vmax_pf, "vmax %.0f px/s, camera offset max %.1f px" % [vmax, cam_max])
	_timing("shake", "wall flash decay (visual)", maxi(flash_end, 0))
	_timing("shake", "impulse → all settled", maxi(settled_pf, 0))
	_log("  shake: pile top %.0f → min %.0f (lift %.0f px) → now %.0f; merges caused %d; pieces %d→%d; protection %.2f s; status '%s'" % [
		top_before, top_min, top_before - top_min, _pile_top(), merges[0], count_before, _count(),
		_board.SHAKE_OVERFLOW_GRACE, _board._status_label.text])
	await _shot("shake", "24_shake_settled")
	_end("shake")
	await _flush()


# --- cleaner: 25–27 -------------------------------------------------------------------

func _group_cleaner() -> void:
	await _make_board("res://resources/levels/level_06.tres")
	await _pile([[6, 5, 4, 3], [1, 2, 1, 2, 1], [2, 1, 2, 1], [1, 2, 1]])
	_begin("cleaner")
	var small: int = 0
	for child in _board._dumpling_layer.get_children():
		if child is Dumpling and (child as Dumpling).tier <= 2:
			small += 1
	var count_before: int = _count()
	_pf = 0
	await _shot("cleaner", "25_cleaner_before")
	_board._use_clear_small()
	var use_pf: int = _pf
	await _shot("cleaner", "25_cleaner_start")
	var total: int = int(ceil(float(small) * _board.CLEAR_STAGGER * 60.0))
	var seq: Array = [2, 4, 8, int(total * 0.5), total, total + 4, total + 12, total + 30]
	var since: int = 0
	var done_pf: int = -1
	for i in 120:
		await get_tree().physics_frame
		since += 1
		if done_pf < 0:
			var left: int = 0
			for child in _board._dumpling_layer.get_children():
				if child is Dumpling and (child as Dumpling).tier <= 2 and not child.is_queued_for_deletion():
					left += 1
			if left == 0:
				done_pf = _pf - use_pf
		if seq.has(since):
			await _shot("cleaner", "26_cleaner_seq" if since < total else "27_cleaner_done")
	_timing("cleaner", "start → last small piece freed", done_pf,
		"%d targets × CLEAR_STAGGER %.3f s = %.2f s" % [small, _board.CLEAR_STAGGER, float(small) * _board.CLEAR_STAGGER])
	await _settle(200, 10)
	await _shot("cleaner", "27_cleaner_settled")
	_log("  cleaner: %d small of %d pieces removed → %d left; sweep ring %s (min %d); status '%s'" % [
		small, count_before, _count(), "yes" if small >= _board.FX_SWEEP_MIN_TARGETS else "no", _board.FX_SWEEP_MIN_TARGETS,
		_board._status_label.text])
	_end("cleaner")
	await _flush()


# --- protect: §15 güç sonrası taşma koruması ------------------------------------------

func _group_protect() -> void:
	_begin("protect_shake")
	await _make_board("res://resources/levels/level_10.tres")
	var cx: float = _board._center_x()
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
	_spawn(8, Vector2(cx, y - 100.0 - 4.0))
	# Sayaç 0.8'e gelince sarsıntı.
	for i in 600:
		await get_tree().physics_frame
		if _board._overflow_elapsed >= 0.8:
			break
	_pf = 0
	var elapsed_before: float = _board._overflow_elapsed
	_board._use_shake()
	await _shot("protect", "15_protect_start")
	var trace: PackedStringArray = PackedStringArray()
	var protect_end: int = -1
	var resumed: int = -1
	var restack_pf: int = -1
	var restack_value: float = -1.0
	for i in 200:
		await get_tree().physics_frame
		if i % 6 == 0 or (protect_end < 0 and _board._shake_protection <= 0.0):
			trace.append("f%d p=%.2f e=%.2f o=%s" % [_pf, _board._shake_protection, _board._overflow_elapsed, _board._is_overflowing()])
		if i == 20:
			# İkinci sarsıntı: pencere uzamaz, aynı süreye yeniden kurulur.
			_board._use_shake()
			restack_pf = _pf
			restack_value = _board._shake_protection
			await _shot("protect", "15_protect_second_shake")
		if protect_end < 0 and _board._shake_protection <= 0.0 and restack_pf >= 0 and _pf > restack_pf:
			protect_end = _pf
			await _shot("protect", "15_protect_end")
		if protect_end >= 0 and resumed < 0 and _board._overflow_elapsed > 0.0:
			resumed = _pf
			await _frames(1)
			await _shot("protect", "15_protect_resumed")
		if resumed >= 0 and i > resumed + 30:
			break
	_log("  protect trace: %s" % " | ".join(trace))
	_timing("protect_shake", "shake#1 → shake#2 (restack test)", restack_pf,
		"protection after shake#2 = %.2f (expected 1.20, not 2.x)" % restack_value)
	_timing("protect_shake", "shake#2 → protection end", protect_end - restack_pf,
		"SHAKE_OVERFLOW_GRACE %.1f s = %d frames; elapsed before shake %.2f → 0" % [_board.SHAKE_OVERFLOW_GRACE, int(_board.SHAKE_OVERFLOW_GRACE * 60.0), elapsed_before])
	_timing("protect_shake", "protection end → overflow counting again", maxi(resumed - protect_end, 0),
		"fail_pending=%s finished=%s" % [_board.is_fail_pending(), _board.is_finished()])
	_end("protect_shake")
	await _flush()

	# Devam koruması (1.5 s): fail-pending → grant_revive → sayaç.
	_begin("protect_revive")
	await _make_board("res://resources/levels/level_10.tres")
	y = _board.FLOOR_Y
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
	_spawn(8, Vector2(cx, y - 100.0 - 4.0))
	for i in 900:
		await get_tree().physics_frame
		if _board.is_fail_pending():
			break
	await _frames(30)
	_pf = 0
	var count_before: int = _count()
	var ok: bool = _board.grant_revive()
	await _shot("protect", "15_revive_granted")
	var rp_end: int = -1
	var rp_resumed: int = -1
	for i in 200:
		await get_tree().physics_frame
		if rp_end < 0 and _board._revive_protection <= 0.0:
			rp_end = _pf
			await _shot("protect", "15_revive_protection_end")
		if rp_end >= 0 and _board._overflow_elapsed > 0.0:
			rp_resumed = _pf
			break
		if rp_end >= 0 and i > rp_end + 40:
			break
	_timing("protect_revive", "grant → revive protection end", rp_end,
		"REVIVE_PROTECTION %.1f s = %d frames; granted=%s; rescued %d of %d" % [_board.REVIVE_PROTECTION,
		int(_board.REVIVE_PROTECTION * 60.0), ok, count_before - _count(), count_before])
	_log("  revive: overflow counting again after end? %s (pile top %.0f vs line %.0f)" % [
		"yes at f%d" % rp_resumed if rp_resumed >= 0 else "no (board below line)", _pile_top(), _board.overflow_line_y()])
	await _frames(10)
	await _shot("protect", "15_revive_after")
	_end("protect_revive")
	await _flush()


# --- goal: 28–29 -----------------------------------------------------------------------

func _group_goal() -> void:
	await _make_board("res://resources/levels/level_01.tres")
	var r: float = TierConfig.radius(3)
	await _pile([[2, 3, 1]])
	_begin("goal")
	GameState.add_score(120)
	await _frames(2)
	await _shot("goal", "28_near_target", false)
	_log("  near target: reached tier %d / target %d, goal bar %.2f, score %d, strip reached %d" % [
		_board._max_tier_reached, _board.level.target_tier, _board._hud.goal_bar.value, GameState.score,
		_board._hud.strip.reached()])
	# Hedefi tamamla: T3 üstüne T3.
	var rest: Dumpling = _find(3, true)
	_pf = 0
	_spawn(3, Vector2(rest.global_position.x + r * 0.4, rest.global_position.y - r - 260.0))
	var finished_pf: int = -1
	for i in 300:
		await get_tree().physics_frame
		if _board.is_finished():
			finished_pf = _pf
			break
	await _shot("goal", "29_target_completed")
	var seq: Array = [3, 8, 15, 30, 48, 70]
	var since: int = 0
	for i in 72:
		await get_tree().physics_frame
		since += 1
		if seq.has(since):
			await _shot("goal", "29_target_completed")
	_timing("goal", "finish → RESULT_DELAY window (main opens result at 0.8 s)", 48,
		"celebration: plate pop 0.30 s, 22+14 particles, shake 5 px; status '%s'" % _board._status_label.text)
	_log("  goal: finished=%s goal bar %.2f, input closed=%s, preview hidden=%s" % [_board.is_finished(),
		_board._hud.goal_bar.value, _board._is_finished, not _board._preview.visible])
	_end("goal")
	await _flush()

	# Skor hedefli level (L8): hedef tier ulaşıldı ama skor eksik — HUD ne diyor?
	await _make_board("res://resources/levels/level_08.tres")
	await _pile([[7, 5], [4, 3, 2]])
	_begin("goal_score")
	GameState.add_score(3200)
	await _frames(2)
	await _shot("goal", "28_score_target_partial", false)
	_log("  score target: reached tier %d / target %d + %d score (have %d), bar %.2f, finished=%s, extra label '%s'" % [
		_board._max_tier_reached, _board.level.target_tier, _board.level.target_score, GameState.score,
		_board._hud.goal_bar.value, _board.is_finished(), _board._hud.goal_extra.text])
	_end("goal_score")
	await _flush()


# --- perf: §23 -------------------------------------------------------------------------

func _perf_begin() -> void:
	_perf_frames = 0
	_perf_delta_max = 0.0
	_perf_delta_sum = 0.0
	_perf_delta_over_20ms = 0
	_perf_nodes_max = 0
	_perf_bodies_max = 0
	_perf_pairs_max = 0
	_perf_tweens_max = 0
	_perf_particles_max = 0
	_perf_fx_max = 0
	_perf_process_ms_max = 0.0
	_perf_physics_ms_max = 0.0
	_perf_process_ms_sum = 0.0
	_perf_physics_ms_sum = 0.0
	_perf_over_8ms = 0
	_perf_over_16ms = 0
	_perf_last_usec = 0
	_perf_wall_max_ms = 0.0
	_perf_wall_sum_ms = 0.0
	_perf_wall_over_16ms = 0
	_perf_wall_over_33ms = 0
	_perf_wall_max_pf = -1
	_perf_pf0 = _pf
	_perf_active = true


func _perf_end(name: String, note: String = "") -> void:
	_perf_active = false
	var wall_avg: float = _perf_wall_sum_ms / maxf(1.0, float(_perf_frames - 1))
	var row: Dictionary = {"scene": name, "frames": _perf_frames,
		"wall_avg_ms": wall_avg, "wall_max_ms": _perf_wall_max_ms,
		"wall_fps_uncapped": 1000.0 / maxf(0.001, wall_avg),
		"wall_over_16ms": _perf_wall_over_16ms, "wall_over_33ms": _perf_wall_over_33ms,
		"wall_max_pf": _perf_wall_max_pf,
		"delta_avg_ms": _perf_delta_sum / maxf(1.0, float(_perf_frames)) * 1000.0,
		"delta_max_ms": _perf_delta_max * 1000.0, "frames_over_20ms": _perf_delta_over_20ms,
		"process_ms_max": _perf_process_ms_max, "physics_ms_max": _perf_physics_ms_max,
		"process_ms_avg": _perf_process_ms_sum / maxf(1.0, float(_perf_frames)),
		"physics_ms_avg": _perf_physics_ms_sum / maxf(1.0, float(_perf_frames)),
		"frames_cpu_over_8ms": _perf_over_8ms, "frames_cpu_over_16ms": _perf_over_16ms,
		"nodes_max": _perf_nodes_max, "bodies_active_max": _perf_bodies_max,
		"collision_pairs_max": _perf_pairs_max, "tweens_max": _perf_tweens_max,
		"particle_nodes_max": _perf_particles_max, "fx_sprites_labels_max": _perf_fx_max,
		"dumplings": _count(), "note": note}
	_perf_results.append(row)
	_log("  perf %-16s frames %4d  wall avg %5.2f ms (%4.0f fps uncapped) max %6.2f ms @pf%d  >16.7ms %3d >33ms %2d  | engine process max %6.2f physics max %5.2f ms | nodes %4d bodies %3d pairs %3d tweens %2d particles %2d fx %2d dumplings %2d  %s" % [
		name, row["frames"], row["wall_avg_ms"], row["wall_fps_uncapped"], row["wall_max_ms"], row["wall_max_pf"],
		row["wall_over_16ms"], row["wall_over_33ms"], row["process_ms_max"], row["physics_ms_max"],
		row["nodes_max"], row["bodies_active_max"], row["collision_pairs_max"], row["tweens_max"],
		row["particle_nodes_max"], row["fx_sprites_labels_max"], row["dumplings"], note])


func _group_perf() -> void:
	_begin("perf")
	# Perf boyunca fps tavanı ve vsync KAPALI (her senaryoda açıp kapamak
	# ~55 ms'lik sahte bir hıçkırık üretiyordu).
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _frames(10)
	# Level açılış hıçkırığı: instantiate + setup + add_child (_ready) süresi
	# doğrudan ölçülür, ardından ilk 30 karenin duvar saati.
	await _teardown()
	_perf_begin()
	var t0: int = Time.get_ticks_usec()
	_board = GAME_BOARD_SCENE.instantiate()
	var t1: int = Time.get_ticks_usec()
	_board.setup(load("res://resources/levels/level_06.tres"))
	add_child(_board)
	var t2: int = Time.get_ticks_usec()
	await _frames(30)
	_perf_end("board_open_30f", "instantiate %.1f ms + setup/add_child(_ready) %.1f ms, then first 30 frames (level 6)" % [
		float(t1 - t0) / 1000.0, float(t2 - t1) / 1000.0])
	# Aynı ölçüm ikinci kez (sıcak: shader/doku önbelleği dolu).
	await _teardown()
	_perf_begin()
	t0 = Time.get_ticks_usec()
	_board = GAME_BOARD_SCENE.instantiate()
	t1 = Time.get_ticks_usec()
	_board.setup(load("res://resources/levels/level_06.tres"))
	add_child(_board)
	t2 = Time.get_ticks_usec()
	await _frames(30)
	_perf_end("board_open_warm", "instantiate %.1f ms + add_child(_ready) %.1f ms (second board)" % [
		float(t1 - t0) / 1000.0, float(t2 - t1) / 1000.0])
	# Boş board referansı.
	await _frames(30)
	_perf_begin()
	await _frames(120)
	_perf_end("empty_board")

	# Normal 10 parça, yerleşmiş.
	await _make_board("res://resources/levels/level_06.tres")
	await _pile([[5, 4, 5, 3], [3, 4, 2, 3], [2, 1]])
	_perf_begin()
	await _frames(120)
	_perf_end("pile_10_idle")

	# Ağır yığın (35 canlı gövde, sonsuz kap). Merge KAPALI (is_merging
	# bayrağı, contact_rig'in pile_contact sahnesi gibi) — aksi hâlde yığın
	# kendini 14 parçaya eritiyor ve "ağır" olmuyor. Yalnız perf ölçümü.
	await _make_board("res://resources/levels/endless.tres")
	await _pile([[8, 7, 6], [6, 5, 5, 4], [4, 3, 4, 3, 3], [2, 2, 3, 2, 1, 2], [3, 2, 1, 2, 3, 1, 2],
		[1, 2, 1, 2, 1, 2, 1], [2, 1, 2, 1]], true)
	_perf_begin()
	await _frames(120)
	_perf_end("pile_35_idle", "%d live bodies, merge disabled" % _count())
	# Aynı yığına drop sürekli (bot) — aktif oyun.
	_perf_begin()
	for i in 12:
		if _board._is_finished:
			break
		_board._pending_tier = 1 + (i % 3)
		_board._set_aim(_board._left_x() + 60.0 + float(i % 6) * 100.0)
		_board._drop_cooldown = 0.0
		_board._drop()
		await _frames(10)
	_perf_end("pile_35_dropping", "12 drops")

	# Zincir merge (x3) — level 9 düzeni.
	await _make_board("res://resources/levels/level_09.tres")
	var cx: float = _board._center_x()
	var y: float = _board.FLOOR_Y
	var x2: float = cx - 150.0
	var x3: float = x2 + 62.0
	var x4: float = x3 + 77.0
	_spawn(2, Vector2(x2, y - 31.0))
	_spawn(3, Vector2(x3, y - 38.0))
	_spawn(4, Vector2(x4, y - 46.0))
	await _settle(120)
	_perf_begin()
	_spawn(2, Vector2(x2 + 6.0, y - 287.0))
	await _frames(120)
	_perf_end("chain_x3")

	# Çok efekt: tier 8 merge + bomba + büyütücü + sarsıntı aynı anda.
	await _make_board("res://resources/levels/level_08.tres")
	await _pile([[7, 6, 5], [4, 3, 4, 3], [2, 2, 1, 2, 1]])
	_perf_begin()
	var t7: Dumpling = _find(7, true)
	_spawn(7, Vector2(t7.global_position.x + 20.0, t7.global_position.y - 81.0 - 120.0))
	var t3: Dumpling = _find(3, true)
	var t4: Dumpling = _find(4, true)
	_board._powerups.request(PowerUp.Type.BOMB)
	_board._use_targeted_power(t3)
	_board._powerups.request(PowerUp.Type.UPGRADE)
	_board._use_targeted_power(t4)
	_board._use_shake()
	await _frames(120)
	_perf_end("many_effects", "T7+T7 merge + bomb + upgrade + shake")

	# M8.7-02 karşılaştırma satırları: tek normal merge (T3), tek T8 merge,
	# Büyütücü T7→T8 — efekt dili değişikliğinin kare maliyeti.
	for spec in [[3, "merge_t3_single"], [7, "merge_t8_single"]]:
		await _make_board("res://resources/levels/level_08.tres")
		var pcx: float = _board._center_x()
		var pr: float = TierConfig.radius(spec[0])
		_spawn(spec[0], Vector2(pcx - pr * 0.5, _board.FLOOR_Y - pr - 6.0))
		await _settle(90)
		_perf_begin()
		var merge_pf: Array = [-1]
		var mcb := func(_t: int, _p: Vector2) -> void: merge_pf[0] = _pf - _perf_pf0
		GameState.merge_performed.connect(mcb)
		_spawn(spec[0], Vector2(pcx - pr * 0.5 + pr * 0.55, _board.FLOOR_Y - pr - 320.0))
		await _frames(120)
		GameState.merge_performed.disconnect(mcb)
		_perf_end(spec[1], "T%d+T%d → T%d, düşüş + merge + efekt + yerleşme; merge @pf%d" % [spec[0], spec[0], spec[0] + 1, merge_pf[0]])
	await _make_board("res://resources/levels/level_08.tres")
	await _pile([[7, 6], [4, 3, 2]])
	var up7: Dumpling = _find(7, true)
	_perf_begin()
	_board._powerups.request(PowerUp.Type.UPGRADE)
	_board._use_targeted_power(up7)
	await _frames(120)
	_perf_end("upgrade_t8", "Büyütücü T7→T8: anticipation + dönüşüm + kral parıltısı")

	# Sarsıntı ağır yığında.
	await _make_board("res://resources/levels/endless.tres")
	await _pile([[8, 7, 6], [6, 5, 5, 4], [4, 3, 4, 3, 3], [2, 2, 3, 2, 1, 2], [3, 2, 1, 2, 3, 1, 2],
		[1, 2, 1, 2, 1, 2, 1]])
	_perf_begin()
	_board._use_shake()
	await _frames(120)
	_perf_end("shake_heavy")

	# Temizleyici ~20 küçük parça.
	await _make_board("res://resources/levels/endless.tres")
	await _pile([[6, 5, 4, 5], [2, 1, 2, 1, 2, 1, 2], [1, 2, 1, 2, 1, 2, 1], [2, 1, 2, 1, 2, 1]])
	var small: int = 0
	for child in _board._dumpling_layer.get_children():
		if child is Dumpling and (child as Dumpling).tier <= 2:
			small += 1
	_perf_begin()
	_board._use_clear_small()
	await _frames(120)
	_perf_end("cleaner_%d" % small, "%d small pieces" % small)
	# contact_rig "stress" deseninin aynısı (5 sıra × 7 parça, 15 kare arayla,
	# zincir merge) — rig'in TIME_PROCESS+TIME_PHYSICS "worst frame" değeri
	# duvar saatiyle karşılaştırılsın (monitörler tutarsız çıktı).
	await _make_board("res://resources/levels/level_01.tres")
	var cx3: float = _board._center_x()
	var pattern: Array[int] = [1, 1, 2, 1, 1, 2, 3]
	_perf_begin()
	for row in 5:
		for col in 7:
			var tier: int = pattern[(col + row) % pattern.size()]
			_spawn(tier, Vector2(cx3 + (col - 3) * 78.0, _board.FLOOR_Y - 60.0 - row * 90.0))
		await _frames(15)
	await _frames(90)
	_perf_end("stress_rig_35", "7 spawns/frame × 5 rows + chain merges (contact_rig stress pattern)")
	# Tek merge karesinin maliyeti: _resolve_merge doğrudan zamanlanır
	# (deferred çağrı fizik karesinin sonunda koşuyor — TIME_PHYSICS içinde).
	await _make_board("res://resources/levels/level_08.tres")
	var cx2: float = _board._center_x()
	for tier in [2, 5, 7]:
		var r: float = TierConfig.radius(tier)
		var a: Dumpling = _spawn(tier, Vector2(cx2 - r, _board.FLOOR_Y - r - 4.0))
		var b: Dumpling = _spawn(tier, Vector2(cx2 + r + 40.0, _board.FLOOR_Y - r - 4.0))
		await _settle(90)
		a.is_merging = true
		b.is_merging = true
		var m0: int = Time.get_ticks_usec()
		_board._resolve_merge(a, b, Vector2(cx2, _board.FLOOR_Y - r - 4.0))
		var m1: int = Time.get_ticks_usec()
		_log("  perf merge_resolve_t%d_to_t%d: _resolve_merge() direct cost %.2f ms (spawn + ghosts + flash + pop + label + score pop + audio)" % [
			tier, tier + 1, float(m1 - m0) / 1000.0])
		await _settle(120)
		for child in _board._dumpling_layer.get_children():
			child.queue_free()
		await _frames(3)
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	_end("perf")


# --- polish: M8.7-02 §24 önce/sonra dizileri ------------------------------------------
#
# Aynı runtime API'si, aynı yerleşimler; fark: efektin ilk 12 karesi sık
# örneklenir ve her senaryoda dünya efektleri (board'un çocuğu Sprite2D /
# Label / CPUParticles2D) doku adı, ölçek, alfa ve z ile loglanır — böylece
# "flash hangi dokuyu kullanıyor", "+N parçanın ne kadar üstünde",
# "kazanma patlaması merge noktasından kaç px uzakta" soruları kareye
# bakmadan da cevaplanır.

const POLISH_MERGE_SEQ: Array = [0, 1, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 30]
const POLISH_UPGRADE_SEQ: Array = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 16, 20, 28, 40]
const POLISH_WIN_SEQ: Array = [0, 3, 8, 15, 30, 48]


## Board'un çocuğu olan geçici efekt düğümleri (bokeh ve HUD hariç).
func _fx_nodes() -> Array:
	var out: Array = []
	if _board == null or not is_instance_valid(_board):
		return out
	for child in _board.get_children():
		if child == _board._bokeh:
			continue
		if child is Sprite2D or child is Label or child is CPUParticles2D \
				or (child.get_script() != null and child.has_node("Dots")):
			out.append(child)
	# Parçaya bağlanan efektler (Büyütücü anticipation halkası / sütunu,
	# M8.7-02): gövdenin doğrudan Sprite2D çocukları (Visual hariç).
	for piece in _board._dumpling_layer.get_children():
		if piece is Dumpling and is_instance_valid(piece):
			for child in piece.get_children():
				if child is Sprite2D:
					out.append(child)
	return out


## Efekt düğümlerini tek satırda logla: ad / doku / ölçek / alfa / z / konum.
func _log_fx(label: String) -> void:
	var parts: PackedStringArray = PackedStringArray()
	for node in _fx_nodes():
		if node is Sprite2D:
			var s := node as Sprite2D
			var tex: String = s.texture.resource_path.get_file() if s.texture != null else "?"
			parts.append("sprite(%s sc=%.2f a=%.2f z=%d @%.0f,%.0f)" % [tex, s.scale.x, s.modulate.a, s.z_index,
				s.global_position.x, s.global_position.y])
		elif node is Label:
			var l := node as Label
			var rect: Rect2 = Rect2(l.global_position, l.size * l.scale)
			parts.append("label('%s' sc=%.2f a=%.2f rect=%.0f,%.0f %.0fx%.0f)" % [l.text, l.scale.x, l.modulate.a,
				rect.position.x, rect.position.y, rect.size.x, rect.size.y])
		elif node is CPUParticles2D:
			var c := node as CPUParticles2D
			var tex: String = c.texture.resource_path.get_file() if c.texture != null else "?"
			parts.append("particles(%s n=%d life=%.2f sc=%.2f-%.2f @%.0f,%.0f)" % [tex, c.amount, c.lifetime,
				c.scale_amount_min, c.scale_amount_max, c.global_position.x, c.global_position.y])
		else:
			var dots: CPUParticles2D = node.get_node("Dots")
			var tex: String = dots.texture.resource_path.get_file() if dots.texture != null else "?"
			parts.append("pop(%s n=%d sc=%.4f-%.4f)" % [tex, dots.amount, dots.scale_amount_min, dots.scale_amount_max])
	_log("  fx %-24s f%03d  %s" % [label, _pf, " | ".join(parts) if not parts.is_empty() else "(yok)"])


## Dünya "+N" etiketleri (board'un çocuğu Label'lar).
func _float_labels() -> Array[Label]:
	var out: Array[Label] = []
	for node in _fx_nodes():
		if node is Label:
			out.append(node as Label)
	return out


## Etiket dikdörtgeni (ölçek dahil, pivot merkez).
static func _label_rect(l: Label) -> Rect2:
	var size: Vector2 = l.size * l.scale
	var center: Vector2 = l.global_position + l.size * 0.5
	return Rect2(center - size * 0.5, size)


## "+N" etiketinin parçaya göre yeri: etiket alt kenarı ile parçanın
## collider tepesi arasındaki boşluk (pozitif = parçanın üstünde).
func _log_label_vs_piece(label: String, piece: Dumpling) -> void:
	if piece == null or not is_instance_valid(piece):
		return
	var top: float = piece.global_position.y - TierConfig.radius(piece.tier)
	for l in _float_labels():
		var rect: Rect2 = _label_rect(l)
		_log("  label %-22s f%03d '%s' bottom-gap %.0f px above collider top (rect %.0f,%.0f %.0fx%.0f; piece r=%.0f @%.0f,%.0f)" % [
			label, _pf, l.text, top - rect.end.y, rect.position.x, rect.position.y, rect.size.x, rect.size.y,
			TierConfig.radius(piece.tier), piece.global_position.x, piece.global_position.y])


## Etiketler arası çakışma (piksel alanı) — zincir/eşzamanlı senaryolar.
func _log_label_overlap(label: String) -> void:
	var labels: Array[Label] = _float_labels()
	if labels.size() < 2:
		_log("  overlap %-20s f%03d labels=%d (tek etiket, çakışma yok)" % [label, _pf, labels.size()])
		return
	for i in labels.size():
		for j in range(i + 1, labels.size()):
			var a: Rect2 = _label_rect(labels[i])
			var b: Rect2 = _label_rect(labels[j])
			var inter: Rect2 = a.intersection(b)
			var area: float = inter.get_area() if inter.has_area() else 0.0
			_log("  overlap %-20s f%03d '%s' x '%s' = %.0f px² (dy %.0f px)" % [label, _pf, labels[i].text, labels[j].text,
				area, b.position.y - a.position.y])


func _group_polish() -> void:
	for tier in [1, 3, 7]:
		await _polish_merge(tier)
	await _polish_chain_x2()
	await _polish_chain_x3()
	await _polish_labels_near()
	await _polish_shake()
	await _polish_upgrade(3)
	await _polish_upgrade(7)
	await _polish_win_low()
	await _polish_win_high()
	await _polish_win_score()


## 01–03: T1→T2 / T3→T4 / T7→T8 (level 8, taban; merge grubuyla aynı yerleşim).
func _polish_merge(tier: int) -> void:
	var idx: String = {1: "01", 3: "02", 7: "03"}.get(tier, "0x")
	var name: String = "%s_merge_t%d_to_t%d" % [idx, tier, tier + 1]
	_begin("polish_" + name)
	await _make_board("res://resources/levels/level_08.tres")
	var cx: float = _board._center_x()
	var r: float = TierConfig.radius(tier)
	var rest: Dumpling = _spawn(tier, Vector2(cx - r * 0.5, _board.FLOOR_Y - r - 6.0))
	await _settle(120)
	_pf = 0
	var falling: Dumpling = _spawn(tier, Vector2(cx - r * 0.5 + r * 0.55, _board.FLOOR_Y - r - 320.0))
	var merged: Array = [false]
	var cb := func(_t: int, _p: Vector2) -> void: merged[0] = true
	GameState.merge_performed.connect(cb)
	var contact_pf: int = -1
	var merged_pf: int = -1
	for i in 300:
		await get_tree().physics_frame
		if not merged[0] and is_instance_valid(falling) and is_instance_valid(rest):
			var dist: float = falling.global_position.distance_to(rest.global_position)
			if contact_pf < 0 and dist <= 2.0 * r + 10.0:
				contact_pf = _pf
				await _shot("polish", name + "_contact")
		if merged[0]:
			merged_pf = _pf
			break
	GameState.merge_performed.disconnect(cb)
	if merged_pf < 0:
		_log("  HATA: merge olmadı (%s)" % name)
		_end("polish_" + name)
		await _flush()
		return
	var score_before: int = GameState.score
	var born: Dumpling = _last_dumpling()
	var visual: Node2D = born.get_node("Visual") if is_instance_valid(born) else null
	var since: int = 0
	var scale_max: float = 0.0
	var flash_seen: String = ""
	var flash_end: int = -1
	for i in 60:
		if POLISH_MERGE_SEQ.has(since):
			await _shot("polish", name)
		if since <= 2 or since == 8:
			_log_fx(name)
			_log_label_vs_piece(name, born)
		# Merge parlaması: board çocuğu Sprite2D (hayalet değil: doku fx/ klasöründen).
		var flash_alive: bool = false
		for node in _fx_nodes():
			if node is Sprite2D and (node as Sprite2D).texture != null \
					and (node as Sprite2D).texture.resource_path.contains("/fx/"):
				flash_alive = true
				if flash_seen.is_empty():
					flash_seen = (node as Sprite2D).texture.resource_path.get_file()
		if not flash_seen.is_empty() and not flash_alive and flash_end < 0:
			flash_end = since
		if visual != null and is_instance_valid(visual):
			scale_max = maxf(scale_max, visual.scale.x)
		await get_tree().physics_frame
		since += 1
	_timing("polish_" + name, "contact→resolve", merged_pf - maxi(contact_pf, 0))
	_timing("polish_" + name, "merge flash lifetime (sprite alive)", maxi(flash_end, 0), "texture %s" % flash_seen)
	_log("  merge %s: born tier %d (count %d), score %d, visual scale peak %.3f, flash texture %s" % [
		name, born.tier if is_instance_valid(born) else -1, _count(), GameState.score, scale_max, flash_seen])
	await _settle(200, 10)
	await _shot("polish", name + "_settled")
	_end("polish_" + name)
	await _flush()


## Zincir yardımcısı: merge sinyallerini kare indeksleriyle toplar, her merge
## karesinde ve +2'de kare alır, etiket çakışmasını loglar.
func _polish_run_chain(name: String, max_merges: int, frames: int) -> PackedInt32Array:
	var merge_pfs: PackedInt32Array = PackedInt32Array()
	var cb := func(_t: int, _p: Vector2) -> void: merge_pfs.append(_pf)
	GameState.merge_performed.connect(cb)
	var last: int = 0
	var pending_shots: Array = []
	var calm: int = 0
	var combo_peak: int = 0
	for i in frames:
		await get_tree().physics_frame
		combo_peak = maxi(combo_peak, _board._combo_count)
		if merge_pfs.size() > last:
			last = merge_pfs.size()
			await _shot("polish", "%s_merge%d" % [name, last])
			_log_fx("%s_merge%d" % [name, last])
			_log_label_overlap("%s_merge%d" % [name, last])
			_log_label_vs_piece("%s_merge%d" % [name, last], _last_dumpling())
			pending_shots.append([_pf + 2, "%s_merge%d_plus2" % [name, last]])
			pending_shots.append([_pf + 6, "%s_merge%d_plus6" % [name, last]])
			pending_shots.append([_pf + 12, "%s_merge%d_plus12" % [name, last]])
		for k in range(pending_shots.size() - 1, -1, -1):
			if pending_shots[k][0] <= _pf:
				await _shot("polish", pending_shots[k][1])
				_log_label_overlap(pending_shots[k][1])
				pending_shots.remove_at(k)
		calm = calm + 1 if _max_speed() <= SETTLE_SPEED else 0
		if merge_pfs.size() >= max_merges and pending_shots.is_empty() and calm >= 8 and i > 90:
			break
	GameState.merge_performed.disconnect(cb)
	_log("  %s: %d merges at frames %s, combo peak x%d, score %d" % [name, merge_pfs.size(), merge_pfs, combo_peak, GameState.score])
	for i in range(1, merge_pfs.size()):
		_timing("polish_" + name, "merge %d -> merge %d gap" % [i, i + 1], merge_pfs[i] - merge_pfs[i - 1])
	return merge_pfs


## 04: x2 — tabanda T3 | T4; T3 üstüne T3 düşer → doğan T4 yandaki T4'e değer → T5.
func _polish_chain_x2() -> void:
	var name: String = "04_chain_x2"
	await _make_board("res://resources/levels/level_09.tres")
	var cx: float = _board._center_x()
	var y: float = _board.FLOOR_Y
	var x3: float = cx - 50.0
	var x4: float = x3 + 34.0 + 42.0 + 1.0
	_spawn(3, Vector2(x3, y - 34.0 - 4.0))
	_spawn(4, Vector2(x4, y - 42.0 - 4.0))
	await _settle(90)
	var rest: Dumpling = _find(3, true)
	_begin("polish_" + name)
	_pf = 0
	_spawn(3, Vector2(rest.global_position.x + 12.0, y - 34.0 - 300.0))
	await _polish_run_chain(name, 2, 320)
	await _shot("polish", name + "_settled")
	_end("polish_" + name)
	await _flush()


## 05: x3 — chain grubunun vadi yerleşimi (ilk x3 üreten x4 ofseti tutulur).
func _polish_chain_x3() -> void:
	var name: String = "05_chain_x3"
	var got: int = 0
	for offset in [0.0, 6.0, -6.0, 12.0]:
		await _make_board("res://resources/levels/level_09.tres")
		var cx: float = _board._center_x()
		var y: float = _board.FLOOR_Y
		var x3: float = cx - 60.0
		var x4: float = x3 + 34.0 + 42.0 + 1.0
		var x2: float = x3 + 30.0 + offset
		_spawn(3, Vector2(x3, y - 34.0 - 4.0))
		_spawn(4, Vector2(x4, y - 42.0 - 4.0))
		await _settle(90)
		_spawn(2, Vector2(x2, y - 120.0))
		await _settle(120)
		var valley: Dumpling = _find(2, true)
		x2 = valley.global_position.x if valley != null else x2
		_begin("polish_" + name)
		_pf = 0
		_spawn(2, Vector2(x2, y - 27.0 - 300.0))
		var pfs: PackedInt32Array = await _polish_run_chain(name, 3, 320)
		_log("  x3 attempt (x4 offset %+.0f): %d merges" % [offset, pfs.size()])
		await _shot("polish", name + "_settled")
		_end("polish_" + name)
		got = pfs.size()
		if got >= 3:
			await _flush()
			break
		_pending.clear()
	if got < 3:
		_log("  UYARI: x3 zincir oluşmadı; son deneme kareleri yazılıyor")
		await _flush()


## 06: iki ayrı merge 1–3 kare arayla, etiketler yan yana (T4 +110 | T3 +90).
func _polish_labels_near() -> void:
	var name: String = "06_labels_near"
	await _make_board("res://resources/levels/level_09.tres")
	var cx: float = _board._center_x()
	var y: float = _board.FLOOR_Y
	var xa: float = cx - 34.0
	var xb: float = xa + 42.0 + 34.0 + 2.0
	_spawn(4, Vector2(xa, y - 42.0 - 4.0))
	_spawn(3, Vector2(xb, y - 34.0 - 4.0))
	await _settle(120)
	var a: Dumpling = _find(4, true)
	var b: Dumpling = _find(3, true)
	_begin("polish_" + name)
	_pf = 0
	# Düşüş mesafeleri eşit: iki merge aynı ya da ardışık karede.
	_spawn(4, Vector2(a.global_position.x + 3.0, a.global_position.y - 42.0 - 42.0 - 200.0))
	await get_tree().physics_frame
	_spawn(3, Vector2(b.global_position.x - 3.0, b.global_position.y - 34.0 - 34.0 - 200.0))
	await _polish_run_chain(name, 2, 300)
	await _shot("polish", name + "_settled")
	_end("polish_" + name)
	await _flush()


## 07–09: Sarsıntı başlangıç / tepe / yerleşme (shake grubunun yığını).
func _polish_shake() -> void:
	var name: String = "07_shake"
	await _make_board("res://resources/levels/level_06.tres")
	await _pile([[6, 5, 4], [3, 4, 3, 2], [1, 2, 1, 3, 1], [2, 1, 2]])
	_begin("polish_" + name)
	_pf = 0
	await _shot("polish", name + "_before")
	_board._use_shake()
	var seq: Array = [0, 1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 18, 24, 30, 45]
	var since: int = 0
	var ring_seen: String = ""
	var ring_max_px: float = 0.0
	var ring_end: int = -1
	for i in 130:
		if seq.has(since):
			await _shot("polish", name if since < 8 else ("08_shake_peak" if since < 24 else "09_shake_settle"))
		if since <= 6 or since == 12 or since == 18:
			_log_fx(name)
		var alive: bool = false
		for node in _fx_nodes():
			if node is Sprite2D and (node as Sprite2D).texture != null \
					and ((node as Sprite2D).texture.resource_path.ends_with("fx_ring.png")
					or (node as Sprite2D).texture.resource_path.ends_with("fx_dot.png")):
				alive = true
				ring_seen = (node as Sprite2D).texture.resource_path.get_file()
				ring_max_px = maxf(ring_max_px, (node as Sprite2D).scale.x * (node as Sprite2D).texture.get_size().x)
		if not ring_seen.is_empty() and not alive and ring_end < 0:
			ring_end = since
		await get_tree().physics_frame
		since += 1
	_timing("polish_" + name, "shake ring sprite lifetime", maxi(ring_end, 0),
		"texture %s, max texture px %.0f (container %.0f)" % [ring_seen, ring_max_px, _board.level.container_width])
	await _settle(200, 10)
	await _shot("polish", "09_shake_settle")
	_end("polish_" + name)
	await _flush()


## 10–13: Büyütücü — hedef / anticipation / dönüşüm (T3→T4) ve T7→T8 parıltısı.
func _polish_upgrade(tier: int) -> void:
	var name: String = "10_upgrade_t3_to_t4" if tier == 3 else "13_upgrade_t7_to_t8"
	var rows: Array = [[5, 3, 5], [2, 1, 2], [3]] if tier == 3 else [[7, 6], [4, 3, 2]]
	await _make_board("res://resources/levels/level_08.tres")
	await _pile(rows)
	_begin("polish_" + name)
	_pf = 0
	_board._on_power_pressed(int(PowerUp.Type.UPGRADE))
	await _frames(3)
	await _shot("polish", name + "_target")
	var target: Dumpling = _find(tier, true)
	var pos: Vector2 = target.global_position
	var count_before: int = _count()
	var stock_before: int = SaveManager.powerup_count(PowerUp.Type.UPGRADE)
	var score_before: int = GameState.score
	var merges: Array = [0]
	var cb := func(_t: int, _p: Vector2) -> void: merges[0] += 1
	GameState.merge_performed.connect(cb)
	_pf = 0
	_board._use_targeted_power(target)
	var stock_after_tap: int = SaveManager.powerup_count(PowerUp.Type.UPGRADE)
	var since: int = 0
	var mutated: int = -1
	var born: Dumpling = null
	var scale_max: float = 0.0
	var shake_peak: float = 0.0
	var sparkle_max: int = 0
	for i in 60:
		if mutated < 0 and not is_instance_valid(target):
			mutated = since
			born = _last_dumpling()
		if POLISH_UPGRADE_SEQ.has(since):
			await _shot("polish", name + ("_anticipation" if mutated < 0 else "_transform"))
		if since <= 12 or since == 16 or since == 20:
			_log_fx(name)
		var sparkles: int = 0
		for node in _fx_nodes():
			if node is Sprite2D and (node as Sprite2D).texture != null \
					and (node as Sprite2D).texture.resource_path.ends_with("fx_sparkle.png"):
				sparkles += 1
		sparkle_max = maxi(sparkle_max, sparkles)
		if born != null and is_instance_valid(born):
			scale_max = maxf(scale_max, (born.get_node("Visual") as Node2D).scale.x)
		shake_peak = maxf(shake_peak, _board._shake_strength)
		await get_tree().physics_frame
		since += 1
	GameState.merge_performed.disconnect(cb)
	_timing("polish_" + name, "tap → tier transform (anticipation)", maxi(mutated, 0),
		"stock %d→%d (tap) →%d, merges %d, score %d→%d" % [stock_before, stock_after_tap,
		SaveManager.powerup_count(PowerUp.Type.UPGRADE), merges[0], score_before, GameState.score])
	_log("  upgrade %s: born tier %d at Δ %.1f px, pieces %d→%d, visual scale peak %.3f, shake peak %.1f px, king sparkle sprites max %d, status '%s'" % [
		name, born.tier if is_instance_valid(born) else -1,
		born.global_position.distance_to(pos) if is_instance_valid(born) else -1.0, count_before, _count(),
		scale_max, shake_peak, sparkle_max, _board._status_label.text])
	await _settle(200, 10)
	await _shot("polish", name + "_settled")
	_end("polish_" + name)
	await _flush()


## Kazanma yardımcısı: bitiş karesini yakalar, patlama düğümlerinin merge
## noktasına uzaklığını loglar, WIN_SEQ karelerini alır.
func _polish_run_win(name: String) -> void:
	var win_point: Array = [Vector2.INF]
	var cb := func(_t: int, p: Vector2) -> void: win_point[0] = p
	GameState.merge_performed.connect(cb)
	var finished_pf: int = -1
	var finished_count: Array = [0]
	var fcb := func(_won: bool) -> void: finished_count[0] += 1
	_board.round_finished.connect(fcb)
	for i in 300:
		await get_tree().physics_frame
		if _board.is_finished():
			finished_pf = _pf
			break
	GameState.merge_performed.disconnect(cb)
	if finished_pf < 0:
		_log("  HATA: %s — round bitmedi" % name)
		_board.round_finished.disconnect(fcb)
		return
	# Patlama düğümleri (CPUParticles2D) — merge noktasına uzaklık.
	var bursts: PackedStringArray = PackedStringArray()
	for node in _fx_nodes():
		if node is CPUParticles2D:
			var c := node as CPUParticles2D
			var d: float = c.global_position.distance_to(win_point[0]) if win_point[0] != Vector2.INF else -1.0
			bursts.append("%s@%.0f,%.0f d=%.0f" % [c.texture.resource_path.get_file() if c.texture != null else "?",
				c.global_position.x, c.global_position.y, d])
	_log("  win %s: finished f%03d, winning merge point %s, pile top y %.0f, line y %.0f, container top y %.0f, bursts: %s" % [
		name, finished_pf, win_point[0], _pile_top(), _board.overflow_line_y(), _board.container_top_y(),
		" | ".join(bursts) if not bursts.is_empty() else "(yok)"])
	var since: int = 0
	for i in 50:
		if POLISH_WIN_SEQ.has(since):
			await _shot("polish", name)
		if since == 0 or since == 8:
			_log_fx(name)
		await get_tree().physics_frame
		since += 1
	_board.round_finished.disconnect(fcb)
	_log("  win %s: round_finished ×%d, status '%s', score %d" % [name, finished_count[0], _board._status_label.text, GameState.score])


## 14: düşük yığın (L1: T3+T3 → T4 hedef).
func _polish_win_low() -> void:
	var name: String = "14_win_low"
	await _make_board("res://resources/levels/level_01.tres")
	await _pile([[2, 3, 1]])
	var rest: Dumpling = _find(3, true)
	_begin("polish_" + name)
	_pf = 0
	_spawn(3, Vector2(rest.global_position.x + 34.0 * 0.4, rest.global_position.y - 34.0 - 260.0))
	await _polish_run_win(name)
	_end("polish_" + name)
	await _flush()


## 15: yüksek yığın (L2: birleşmeyen dolgu + tepede T3+T3 → T4).
func _polish_win_high() -> void:
	var name: String = "15_win_high"
	await _make_board("res://resources/levels/level_02.tres")
	await _pile([[5, 6, 5], [4, 5, 4], [3, 3]], true)
	var top_y: float = _pile_top()
	var cx: float = _board._center_x()
	var rest: Dumpling = _spawn(3, Vector2(cx, top_y - 34.0 - 4.0))
	await _settle(120)
	_begin("polish_" + name)
	_log("  high pile: top y %.0f (line y %.0f, %d pieces)" % [_pile_top(), _board.overflow_line_y(), _count()])
	_pf = 0
	_spawn(3, Vector2(rest.global_position.x + 10.0, rest.global_position.y - 34.0 - 200.0))
	await _polish_run_win(name)
	_end("polish_" + name)
	await _flush()


## 16: skor hedefi (L8: tier 7 var, skor eşiğini küçük bir merge geçiyor).
func _polish_win_score() -> void:
	var name: String = "16_win_score"
	await _make_board("res://resources/levels/level_08.tres")
	await _pile([[7, 5], [3, 2]])
	GameState.add_score(_board.level.target_score - 90 + 10)
	# Tier 7 board'a doğrudan konuldu (merge ile gelmedi): hedef bayrağı elle,
	# revive_test'in kazanma yolu gibi. Kazanmayı skoru geçen merge tetikler.
	_board._reached_target_tier = true
	await _frames(2)
	var rest: Dumpling = _find(3, true)
	_begin("polish_" + name)
	_log("  score target: reached tier %d / target %d, score %d / %d" % [_board._max_tier_reached,
		_board.level.target_tier, GameState.score, _board.level.target_score])
	_pf = 0
	_spawn(3, Vector2(rest.global_position.x + 12.0, rest.global_position.y - 34.0 - 240.0))
	await _polish_run_win(name)
	_end("polish_" + name)
	await _flush()


# --- Raporlar / kayıt ----------------------------------------------------------------

func _write_reports() -> void:
	var log_file := FileAccess.open(_out_dir.path_join("audit_log_%s.txt" % _tag()), FileAccess.WRITE)
	if log_file != null:
		log_file.store_string("\n".join(_log_lines) + "\n")
		log_file.close()
	var json := FileAccess.open(_out_dir.path_join("audit_data_%s.json" % _tag()), FileAccess.WRITE)
	if json != null:
		json.store_string(JSON.stringify({"tag": _tag(), "timings": _timings, "perf": _perf_results,
			"shots": _shot_count}, "\t"))
		json.close()


func _restore_save() -> void:
	SaveManager.data = _saved_data
	if _had_save:
		var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_save_bytes)
			file.close()
	elif FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	var restored: bool = not _had_save or FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == _save_bytes
	print("kayıt geri kondu: %s" % ("byte-identical" if restored else "FARKLI"))
