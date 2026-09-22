extends "res://tools/gameplay_audit_shots.gd"
## M8.7-02.1 — A36 cihaz kapısı sürücüsü (merge / güç efekt dili). Dev aracı;
## üretim APK'sında YOK (`tools/*` preset dışında), AYRI bir QA paketiyle
## (`com.example.squishymerge.qa`) yüklenir ve kendi veri dizininde çalışır —
## owner kaydına dokunamaz.
##
## Denetim harness'inin (gameplay_audit_shots) senaryolarını CİHAZDA komutla
## çalıştırır: `user://qa_cmd.txt` (adb run-as ile yazılır, okunan komut
## silinir), durum + son senaryonun log satırları `user://qa_state.txt`, kare
## dizileri `user://qa_shots/<grup>/…` (run-as tar ile alınır).
##
## Kare süresi = gerçek üretim adımlaması (vsync açık, fps tavanı yok — A36
## 120 Hz panel): `_process` arası duvar saati; ortalama / p95 / maks / >16.7 /
## >25 ms ve en uzun karenin fizik karesi. Titreşim: sink kaydeder VE
## platform çağrısını gerçekten yapar (`Input.vibrate_handheld`) — cihaz
## `dumpsys vibrator_manager` ile doğrulanır.
##
## Komutlar:
##   merge T            T+T → T+1 (1,3,5,7) — polish dizisi + kareler
##   chain2 · chain3 · near · shake · upgrade T (1,3,5,7) · win low|high|score
##   perf NAME          merge_t3 | merge_t8 | chain_x3 | upgrade_t4 | upgrade_t8 |
##                      shake_heavy | many_effects | level_open   (kare alınmaz)
##   t8x N · shakex N · upgradex N · mergex N   tekrar + birikim kontrolü
##   cleanup            geçici düğüm / tween / bellek sayımı (yerleşmiş board)
##   race CASE          same | other | pause | overflow | teardown
##   protect · drop     denetim grupları (koruma penceresi, fizik spot check)
##   interop            gerçek Main: L1 kazanma → sonuç TEK kez, ilerleme TEK kez
##   quit

const CMD_PATH: String = "user://qa_cmd.txt"
const STATE_PATH: String = "user://qa_state.txt"
const POLL: float = 0.2
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _main: Node = null
var _log_mark: int = 0
var _frame_ms: PackedFloat64Array = PackedFloat64Array()
## Her örneğin senaryo içi fizik karesi (en uzun kare hangi olaya denk geldi).
var _frame_pf: PackedInt32Array = PackedInt32Array()
var _last_usec: int = 0
var _perf_rows_dev: PackedStringArray = PackedStringArray()
var _haptic_events: PackedStringArray = PackedStringArray()
var _finished_count: int = 0
var _result_shown: int = 0


func _ready() -> void:
	# Otomatik GÜNLÜK ÖDÜLLER penceresi (M8.9-02) bu harness'in konusu değil.
	DailyRewards.auto_popup_enabled = false
	# Denetim harness'inin _ready'si masaüstü gruplarını koşup çıkar — burada
	# çağrılmıyor; komut döngüsü var.
	_out_dir = ProjectSettings.globalize_path("user://qa_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_size = DisplayServer.window_get_size()
	Engine.physics_ticks_per_second = 60
	_remove(CMD_PATH)
	await get_tree().process_frame
	await get_tree().process_frame
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_saved_data = SaveManager.data.duplicate(true)
	var stock: Dictionary = {}
	for type in PowerUp.all():
		stock[PowerUp.save_key(type)] = 9
	SaveManager.data["powerups"] = stock
	SaveManager.data["equipped_skin"] = ""
	SaveManager.data["powerup_starter_granted"] = true
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	Haptics.set_sink(_on_device_haptic, true)
	Haptics.reset_counters()
	_log("=== gameplay_device %s view=%s hz=%.0f ===" % [_tag(), str(_size), DisplayServer.screen_get_refresh_rate()])
	_write_state("ready")
	while true:
		await get_tree().create_timer(POLL).timeout
		var cmd: String = _read_cmd()
		if cmd == "":
			continue
		if cmd == "quit":
			break
		_log_mark = _log_lines.size()
		_haptic_events.clear()
		await _handle(cmd)
		_write_state(cmd)
	_write_state("quit")
	await _teardown()
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	SaveManager.data = _saved_data
	_restore_save()
	Haptics.set_sink(Callable(), false)
	get_tree().quit()


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _read_cmd() -> String:
	if not FileAccess.file_exists(CMD_PATH):
		return ""
	var cmd: String = FileAccess.get_file_as_string(CMD_PATH).strip_edges()
	_remove(CMD_PATH)
	return cmd


## Titreşim: kaydet + GERÇEKTEN titreştir (sink platform çağrısının yerine geçer).
func _on_device_haptic(duration_ms: int, amplitude: float) -> void:
	_haptic_log.append({"pf": _pf, "ms": duration_ms, "amp": amplitude})
	_haptic_events.append("t%d:f%d:%dms@%.2f" % [Time.get_ticks_msec(), _pf, duration_ms, amplitude])
	Input.vibrate_handheld(duration_ms, amplitude)


func _process(delta: float) -> void:
	super(delta)
	var now: int = Time.get_ticks_usec()
	if _perf_active and _last_usec > 0:
		# İlk örnek _perf_begin ile aynı karedeki kurulumu da içerir (level
		# açılışında _ready hıçkırığı bilerek dahil) — denetim harness'inin
		# kendi max'ı bunu atlar, bu yüzden cihaz satırı KENDİ dizisinden yazılır.
		_frame_ms.append(float(now - _last_usec) / 1000.0)
		_frame_pf.append(_pf - _perf_pf0)
	_last_usec = now


## Denetim perf satırının cihaz özeti: p95 ve >25 ms de eklenir.
func _perf_end(name: String, note: String = "") -> void:
	super(name, note)
	var raw: PackedFloat64Array = _frame_ms.duplicate()
	var max_ms: float = 0.0
	var max_pf: int = -1
	var sum_ms: float = 0.0
	for i in raw.size():
		sum_ms += raw[i]
		if raw[i] > max_ms:
			max_ms = raw[i]
			max_pf = _frame_pf[i] if i < _frame_pf.size() else -1
	var arr: PackedFloat64Array = raw
	arr.sort()
	var n: int = arr.size()
	var p95: float = arr[int(floor(float(n - 1) * 0.95))] if n > 0 else 0.0
	var p50: float = arr[int(floor(float(n - 1) * 0.5))] if n > 0 else 0.0
	var over25: int = 0
	var over167: int = 0
	var over12: int = 0
	for v in arr:
		if v > 25.0:
			over25 += 1
		if v > 16.7:
			over167 += 1
		if v > 12.0:
			over12 += 1
	var row: Dictionary = _perf_results[_perf_results.size() - 1]
	row["p95_ms"] = p95
	row["p50_ms"] = p50
	row["over_25ms"] = over25
	row["over_12ms"] = over12
	row["dev_max_ms"] = max_ms
	row["dev_max_pf"] = max_pf
	row["dev_avg_ms"] = sum_ms / maxf(1.0, float(n))
	var line: String = "  devperf %-14s frames %4d  avg %5.2f  p50 %5.2f  p95 %5.2f  max %6.2f ms @pf%d  >12ms %d  >16.7ms %d  >25ms %d  | nodes %d tweens %d particles %d fx %d  %s" % [
		name, n, sum_ms / maxf(1.0, float(n)), p50, p95, max_ms, max_pf, over12, over167, over25,
		row["nodes_max"], row["tweens_max"], row["particle_nodes_max"], row["fx_sprites_labels_max"], note]
	_log(line)
	_perf_rows_dev.append(line.strip_edges())
	_frame_ms.clear()
	_frame_pf.clear()


func _perf_begin() -> void:
	super()
	_frame_ms.clear()
	_frame_pf.clear()


# --- komutlar ----------------------------------------------------------------------

func _handle(line: String) -> void:
	var parts: PackedStringArray = line.split(" ", false)
	var cmd: String = parts[0]
	var arg: String = parts[1] if parts.size() > 1 else ""
	_log("--- cmd: %s ---" % line)
	match cmd:
		"merge":
			await _polish_merge(int(arg))
		"chain2":
			await _polish_chain_x2()
		"chain3":
			await _polish_chain_x3()
		"near":
			await _polish_labels_near()
		"shake":
			await _polish_shake()
		"upgrade":
			var tier: int = int(arg)
			if tier == 3 or tier == 7:
				await _polish_upgrade(tier)
			else:
				await _upgrade_any(tier)
		"win":
			match arg:
				"low": await _polish_win_low()
				"high": await _polish_win_high()
				"score": await _polish_win_score()
		"perf":
			await _perf_scenario(arg)
		"t8x":
			await _repeat_t8(int(arg) if arg != "" else 10)
		"shakex":
			await _repeat_shake(int(arg) if arg != "" else 10)
		"upgradex":
			await _repeat_upgrade(int(arg) if arg != "" else 10)
		"mergex":
			await _repeat_merge(int(arg) if arg != "" else 10)
		"cleanup":
			await _cleanup_probe()
		"race":
			await _race(arg)
		"protect":
			await _group_protect()
		"drop":
			await _group_drop()
		"interop":
			await _interop()
		"leave":
			await _teardown()
		_:
			_log("  bilinmeyen komut: %s" % line)


## Büyütücü T1/T5 gibi ek hedefler: küçük yığın + hedef tier; dizi 10_/13_
## isimleriyle aynı yapıda ("1x_upgrade_tN").
func _upgrade_any(tier: int) -> void:
	var name: String = "1x_upgrade_t%d_to_t%d" % [tier, tier + 1]
	await _make_board("res://resources/levels/level_08.tres")
	await _pile([[6, 4], [2, tier, 3]] if tier != 5 else [[7, 5], [3, 2]])
	_begin("polish_" + name)
	_pf = 0
	_board._on_power_pressed(int(PowerUp.Type.UPGRADE))
	await _frames(3)
	await _shot("polish", name + "_target")
	var target: Dumpling = _find(tier, true)
	var pos: Vector2 = target.global_position
	var stock_before: int = SaveManager.powerup_count(PowerUp.Type.UPGRADE)
	_pf = 0
	_board._use_targeted_power(target)
	var since: int = 0
	var mutated: int = -1
	var born: Dumpling = null
	for i in 48:
		if mutated < 0 and not is_instance_valid(target):
			mutated = since
			born = _last_dumpling()
		if POLISH_UPGRADE_SEQ.has(since):
			await _shot("polish", name + ("_anticipation" if mutated < 0 else "_transform"))
		if since <= 12:
			_log_fx(name)
		await get_tree().physics_frame
		since += 1
	_timing("polish_" + name, "tap → tier transform (anticipation)", maxi(mutated, 0),
		"stock %d→%d, score %d" % [stock_before, SaveManager.powerup_count(PowerUp.Type.UPGRADE), GameState.score])
	_log("  upgrade %s: born tier %d at Δ %.1f px" % [name, born.tier if is_instance_valid(born) else -1,
		born.global_position.distance_to(pos) if is_instance_valid(born) else -1.0])
	await _settle(200, 10)
	await _shot("polish", name + "_settled")
	_end("polish_" + name)
	await _flush()


# --- perf senaryoları (kare alınmaz; üretim adımlaması) -------------------------------

func _perf_scenario(name: String) -> void:
	_begin("perf_" + name)
	match name:
		"level_open":
			await _teardown()
			_perf_begin()
			var t0: int = Time.get_ticks_usec()
			_board = GAME_BOARD_SCENE.instantiate()
			var t1: int = Time.get_ticks_usec()
			_board.setup(load("res://resources/levels/level_06.tres"))
			add_child(_board)
			var t2: int = Time.get_ticks_usec()
			await _frames(60)
			_perf_end("level_open", "instantiate %.1f ms + setup/add_child(_ready) %.1f ms, then 60 frames" % [
				float(t1 - t0) / 1000.0, float(t2 - t1) / 1000.0])
		"merge_t3", "merge_t8":
			var tier: int = 3 if name == "merge_t3" else 7
			await _make_board("res://resources/levels/level_08.tres")
			var cx: float = _board._center_x()
			var r: float = TierConfig.radius(tier)
			_spawn(tier, Vector2(cx - r * 0.5, _board.FLOOR_Y - r - 6.0))
			await _settle(90)
			var merge_pf: Array = [-1]
			var mcb := func(_t: int, _p: Vector2) -> void: merge_pf[0] = _pf - _perf_pf0
			GameState.merge_performed.connect(mcb)
			_perf_begin()
			_spawn(tier, Vector2(cx - r * 0.5 + r * 0.55, _board.FLOOR_Y - r - 320.0))
			await _frames(120)
			GameState.merge_performed.disconnect(mcb)
			_perf_end(name, "T%d+T%d → T%d; merge @pf%d" % [tier, tier, tier + 1, merge_pf[0]])
		"chain_x3":
			await _make_board("res://resources/levels/level_09.tres")
			var cx: float = _board._center_x()
			var y: float = _board.FLOOR_Y
			var x3: float = cx - 60.0
			var x4: float = x3 + 34.0 + 42.0 + 1.0
			_spawn(3, Vector2(x3, y - 34.0 - 4.0))
			_spawn(4, Vector2(x4, y - 42.0 - 4.0))
			await _settle(90)
			_spawn(2, Vector2(x3 + 30.0 - 6.0, y - 120.0))
			await _settle(120)
			var valley: Dumpling = _find(2, true)
			var merges: Array = [0]
			var mcb := func(_t: int, _p: Vector2) -> void: merges[0] += 1
			GameState.merge_performed.connect(mcb)
			_perf_begin()
			_spawn(2, Vector2(valley.global_position.x if valley != null else x3 + 24.0, y - 27.0 - 300.0))
			await _frames(120)
			GameState.merge_performed.disconnect(mcb)
			_perf_end("chain_x3", "merges %d, combo peak x%d" % [merges[0], _board._combo_count])
		"upgrade_t4", "upgrade_t8":
			var tier: int = 3 if name == "upgrade_t4" else 7
			await _make_board("res://resources/levels/level_08.tres")
			await _pile([[5, 3, 5], [2, 1, 2], [3]] if tier == 3 else [[7, 6], [4, 3, 2]])
			var target: Dumpling = _find(tier, true)
			_perf_begin()
			_board._powerups.request(PowerUp.Type.UPGRADE)
			_board._use_targeted_power(target)
			await _frames(120)
			_perf_end(name, "Büyütücü T%d→T%d: anticipation + dönüşüm%s" % [tier, tier + 1, " + kral parıltısı" if tier == 7 else ""])
		"shake_heavy":
			await _make_board("res://resources/levels/endless.tres")
			await _pile([[8, 7, 6], [6, 5, 5, 4], [4, 3, 4, 3, 3], [2, 2, 3, 2, 1, 2], [3, 2, 1, 2, 3, 1, 2],
				[1, 2, 1, 2, 1, 2, 1]])
			_perf_begin()
			_board._use_shake()
			await _frames(120)
			_perf_end("shake_heavy", "%d pieces" % _count())
		"many_effects":
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
		_:
			_log("  bilinmeyen perf: %s" % name)
	_end("perf_" + name)


# --- tekrar / birikim -----------------------------------------------------------------

## Tekrar senaryoları için stok (bellek + QA paketinin kendi kaydı).
func _refill_stock() -> void:
	var stock: Dictionary = {}
	for type in PowerUp.all():
		stock[PowerUp.save_key(type)] = 12
	SaveManager.data["powerups"] = stock


## Board çocuğu geçici efekt düğümleri + parçalara bağlı sprite'lar (bokeh hariç).
func _transients() -> Dictionary:
	var sprites: int = 0
	var labels: int = 0
	var particles: int = 0
	var pops: int = 0
	var attached: int = 0
	if _board != null and is_instance_valid(_board):
		for child in _board.get_children():
			if child == _board._bokeh:
				continue
			if child is Sprite2D:
				sprites += 1
			elif child is Label:
				labels += 1
			elif child is CPUParticles2D:
				particles += 1
			elif child.get_script() != null and child.has_node("Dots"):
				pops += 1
		for piece in _board._dumpling_layer.get_children():
			if piece is Dumpling:
				for c in piece.get_children():
					if c is Sprite2D:
						attached += 1
	return {"sprites": sprites, "labels": labels, "particles": particles, "pops": pops, "attached": attached,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"tweens": get_tree().get_processed_tweens().size(),
		"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0}


func _fmt_transients(t: Dictionary) -> String:
	return "sprites %d labels %d particles %d pops %d attached %d | nodes %d orphans %d tweens %d static %.1f MB" % [
		t["sprites"], t["labels"], t["particles"], t["pops"], t["attached"], t["nodes"], t["orphans"], t["tweens"], t["static_mb"]]


func _clear_pieces() -> void:
	for child in _board._dumpling_layer.get_children():
		child.queue_free()
	await _frames(3)


func _repeat_t8(n: int) -> void:
	_begin("t8x%d" % n)
	await _make_board("res://resources/levels/endless.tres")
	var cx: float = _board._center_x()
	var base: Dictionary = _transients()
	_log("  baseline: %s" % _fmt_transients(base))
	var maxes: PackedFloat64Array = PackedFloat64Array()
	for i in n:
		await _clear_pieces()
		_spawn(7, Vector2(cx - 40.0, _board.FLOOR_Y - 81.0 - 6.0))
		await _settle(90)
		var merge_pf: Array = [-1]
		var mcb := func(_t: int, _p: Vector2) -> void: merge_pf[0] = _pf - _perf_pf0
		GameState.merge_performed.connect(mcb)
		_perf_begin()
		_spawn(7, Vector2(cx - 40.0 + 44.0, _board.FLOOR_Y - 81.0 - 320.0))
		await _frames(90)
		GameState.merge_performed.disconnect(mcb)
		_perf_end("t8_#%d" % (i + 1), "merge @pf%d" % merge_pf[0])
		maxes.append(_perf_results[_perf_results.size() - 1]["dev_max_ms"])
		await _settle(120, 10)
		await _frames(30)
		_log("  after t8 #%d settled: %s" % [i + 1, _fmt_transients(_transients())])
	var final: Dictionary = _transients()
	_log("  t8x%d done: max frames %s | final %s | delta nodes %+d orphans %+d static %+.1f MB" % [n, maxes, _fmt_transients(final),
		final["nodes"] - base["nodes"], final["orphans"] - base["orphans"], final["static_mb"] - base["static_mb"]])
	_end("t8x%d" % n)


func _repeat_shake(n: int) -> void:
	_begin("shakex%d" % n)
	_refill_stock()
	await _make_board("res://resources/levels/endless.tres")
	# Birleşebilen ağır yığın (is_merging bayrağı YOK: bayraklı parçalar
	# shakeable() dışında kalır ve sarsıntı hiç uygulanmaz). Sarsıntılar
	# arasında merge olabilir — gerçek kullanım da böyle.
	await _pile([[8, 7, 6], [6, 5, 5, 4], [4, 3, 4, 3, 3], [2, 2, 3, 2, 1, 2], [3, 2, 1, 2, 3, 1, 2],
		[1, 2, 1, 2, 1, 2, 1]])
	var base: Dictionary = _transients()
	var base_pieces: int = _count()
	_log("  baseline (%d pieces): %s" % [_count(), _fmt_transients(base)])
	var maxes: PackedFloat64Array = PackedFloat64Array()
	var avgs: PackedFloat64Array = PackedFloat64Array()
	for i in n:
		_perf_begin()
		_board._use_shake()
		await _frames(45)
		_perf_end("shake_#%d" % (i + 1))
		maxes.append(_perf_results[_perf_results.size() - 1]["dev_max_ms"])
		avgs.append(_perf_results[_perf_results.size() - 1]["dev_avg_ms"])
		await _settle(120, 10)
	await _frames(30)
	var final: Dictionary = _transients()
	_log("  shakex%d done: max %s avg %s | final %s | pieces %d→%d (merges allowed) | stock shake %d | delta static %+.1f MB | protection %.2f" % [n, maxes, avgs,
		_fmt_transients(final), base_pieces, _count(), SaveManager.powerup_count(PowerUp.Type.SHAKE),
		final["static_mb"] - base["static_mb"], _board._shake_protection])
	_end("shakex%d" % n)


func _repeat_upgrade(n: int) -> void:
	_begin("upgradex%d" % n)
	_refill_stock()
	await _make_board("res://resources/levels/level_08.tres")
	var cx: float = _board._center_x()
	var base: Dictionary = _transients()
	_log("  baseline: %s" % _fmt_transients(base))
	var maxes: PackedFloat64Array = PackedFloat64Array()
	var stock0: int = SaveManager.powerup_count(PowerUp.Type.UPGRADE)
	for i in n:
		await _clear_pieces()
		var tier: int = 3 if i % 2 == 0 else 5
		var t: Dumpling = _spawn(tier, Vector2(cx, _board.FLOOR_Y - TierConfig.radius(tier) - 6.0))
		await _settle(60)
		_perf_begin()
		_board._powerups.request(PowerUp.Type.UPGRADE)
		_board._use_targeted_power(t)
		await _frames(60)
		_perf_end("upgrade_#%d" % (i + 1), "T%d→T%d" % [tier, tier + 1])
		maxes.append(_perf_results[_perf_results.size() - 1]["dev_max_ms"])
		await _settle(90, 10)
		_log("  after upgrade #%d: tiers %s, %s" % [i + 1, _tiers(), _fmt_transients(_transients())])
	var final: Dictionary = _transients()
	_log("  upgradex%d done: stock %d→%d (one per use), max %s | final %s | delta nodes %+d static %+.1f MB" % [n, stock0,
		SaveManager.powerup_count(PowerUp.Type.UPGRADE), maxes, _fmt_transients(final),
		final["nodes"] - base["nodes"], final["static_mb"] - base["static_mb"]])
	_end("upgradex%d" % n)


func _repeat_merge(n: int) -> void:
	_begin("mergex%d" % n)
	await _make_board("res://resources/levels/level_08.tres")
	var cx: float = _board._center_x()
	var base: Dictionary = _transients()
	_log("  baseline: %s" % _fmt_transients(base))
	var maxes: PackedFloat64Array = PackedFloat64Array()
	for i in n:
		await _clear_pieces()
		var tier: int = 1 + (i % 5)
		var r: float = TierConfig.radius(tier)
		_spawn(tier, Vector2(cx - r * 0.5, _board.FLOOR_Y - r - 6.0))
		await _settle(60)
		_perf_begin()
		_spawn(tier, Vector2(cx - r * 0.5 + r * 0.55, _board.FLOOR_Y - r - 220.0))
		await _frames(75)
		_perf_end("merge_#%d" % (i + 1), "T%d+T%d" % [tier, tier])
		maxes.append(_perf_results[_perf_results.size() - 1]["dev_max_ms"])
		await _settle(90, 10)
	await _frames(30)
	var final: Dictionary = _transients()
	_log("  mergex%d done: max %s | final %s | delta nodes %+d static %+.1f MB | score %d" % [n, maxes,
		_fmt_transients(final), final["nodes"] - base["nodes"], final["static_mb"] - base["static_mb"], GameState.score])
	_end("mergex%d" % n)


func _tiers() -> Array[int]:
	var out: Array[int] = []
	for child in _board._dumpling_layer.get_children():
		if child is Dumpling and not child.is_queued_for_deletion():
			out.append((child as Dumpling).tier)
	out.sort()
	return out


func _cleanup_probe() -> void:
	if _board == null or not is_instance_valid(_board):
		_log("  cleanup: board yok")
		return
	await _settle(120, 10)
	await _frames(60)
	_log("  cleanup: %s | pieces %d tiers %s" % [_fmt_transients(_transients()), _count(), _tiers()])


# --- Büyütücü yarış durumları ----------------------------------------------------------

func _race(kind: String) -> void:
	_begin("race_" + kind)
	await _make_board("res://resources/levels/level_10.tres" if kind == "overflow" else "res://resources/levels/level_08.tres")
	var cx: float = _board._center_x()
	var stock0: int = SaveManager.powerup_count(PowerUp.Type.UPGRADE)
	match kind:
		"same":
			var t: Dumpling = _spawn(3, Vector2(cx, _board.FLOOR_Y - 34.0 - 4.0))
			await _settle(60)
			_board._powerups.request(PowerUp.Type.UPGRADE)
			_board._use_targeted_power(t)
			# Pencerede: yeniden silahlan + AYNI hedefe 3 hızlı dokunuş.
			var locked_valid: bool = false
			for i in 3:
				_board._powerups.request(PowerUp.Type.UPGRADE)
				locked_valid = locked_valid or _board._powerups.is_valid_target(t)
				_board._use_targeted_power(t)
				await get_tree().physics_frame
			_board._powerups.cancel()
			await _frames(30)
			_log("  race same: stock %d→%d (beklenen -1), tiers %s (beklenen [4]), locked target valid during window=%s (beklenen false)" % [
				stock0, SaveManager.powerup_count(PowerUp.Type.UPGRADE), _tiers(), str(locked_valid)])
		"other":
			var a: Dumpling = _spawn(3, Vector2(cx - 80.0, _board.FLOOR_Y - 34.0 - 4.0))
			var b: Dumpling = _spawn(5, Vector2(cx + 80.0, _board.FLOOR_Y - 52.0 - 4.0))
			await _settle(60)
			_board._powerups.request(PowerUp.Type.UPGRADE)
			_board._use_targeted_power(a)
			await _frames(3)
			_board._powerups.request(PowerUp.Type.UPGRADE)
			_board._use_targeted_power(b)
			await _frames(30)
			_log("  race other: stock %d→%d (beklenen -2: iki ayrı hedef), tiers %s (beklenen [4, 6]), a valid=%s b valid=%s" % [
				stock0, SaveManager.powerup_count(PowerUp.Type.UPGRADE), _tiers(), str(is_instance_valid(a)), str(is_instance_valid(b))])
		"pause":
			var t: Dumpling = _spawn(3, Vector2(cx, _board.FLOOR_Y - 34.0 - 4.0))
			await _settle(60)
			_board._powerups.request(PowerUp.Type.UPGRADE)
			_board._use_targeted_power(t)
			await get_tree().physics_frame
			_board.set_menu_paused(true)
			await _frames(20)
			var frozen_after: String = str(_board._dumpling_layer.get_child(0).is_simulation_frozen()) if _board._dumpling_layer.get_child_count() > 0 else "-"
			var tiers_paused: Array[int] = _tiers()
			_board.set_menu_paused(false)
			await _frames(20)
			_log("  race pause: dönüşüm duraklamada gerçekleşti tiers=%s (beklenen [4]) frozen_while_paused=%s, çözüldü frozen=%s, stock %d→%d" % [
				tiers_paused, frozen_after, str(_board._dumpling_layer.get_child(0).is_simulation_frozen()),
				stock0, SaveManager.powerup_count(PowerUp.Type.UPGRADE)])
		"overflow":
			# Taşma sayacı 1.45 s'de: dokunuştan ~3 kare sonra fail-pending.
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
			for i in 600:
				await get_tree().physics_frame
				if _board._overflow_elapsed >= 1.40:
					break
			var t: Dumpling = _find(2, true)
			var offered: Array = [0]
			_board.revive_offered.connect(func(_r: int) -> void: offered[0] += 1)
			_board._powerups.request(PowerUp.Type.UPGRADE)
			_board._use_targeted_power(t)
			await _frames(30)
			var frozen: int = 0
			for child in _board._dumpling_layer.get_children():
				if child is Dumpling and (child as Dumpling).is_simulation_frozen():
					frozen += 1
			_log("  race overflow: fail_pending=%s offered=%d, stock %d→%d, tiers %s (T2 hedef → T3 var mı), frozen %d/%d, finished=%s" % [
				str(_board.is_fail_pending()), offered[0], stock0, SaveManager.powerup_count(PowerUp.Type.UPGRADE),
				_tiers(), frozen, _count(), str(_board.is_finished())])
		"teardown":
			var t: Dumpling = _spawn(3, Vector2(cx, _board.FLOOR_Y - 34.0 - 4.0))
			await _settle(60)
			var n0: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			_board._powerups.request(PowerUp.Type.UPGRADE)
			_board._use_targeted_power(t)
			await get_tree().physics_frame
			await _teardown()
			await _frames(30)
			_log("  race teardown: board pencerede silindi → nodes now %d (board öncesi %d), orphans %d, tweens %d, stock %d→%d" % [
				int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), n0,
				int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), get_tree().get_processed_tweens().size(),
				stock0, SaveManager.powerup_count(PowerUp.Type.UPGRADE)])
		_:
			_log("  bilinmeyen race: %s" % kind)
	_end("race_" + kind)


# --- Gerçek Main: kazanma → sonuç birlikte çalışma ---------------------------------------

func _interop() -> void:
	_begin("interop")
	await _teardown()
	if _main == null or not is_instance_valid(_main):
		_main = MAIN_SCENE.instantiate()
		add_child(_main)
		await get_tree().process_frame
		await get_tree().process_frame
		if _main._daily != null:
			_main._daily.visible = false
	_finished_count = 0
	_result_shown = 0
	var unlocked_before: int = SaveManager.highest_level_unlocked()
	var stars_before: Dictionary = SaveManager.data.get("level_stars", {}).duplicate(true)
	_main._start_level(load("res://resources/levels/level_01.tres"))
	await get_tree().process_frame
	await get_tree().process_frame
	var board: Node2D = _main._board
	board._dismiss_tutorial()
	board.round_finished.connect(func(_w: bool) -> void: _finished_count += 1)
	var cx: float = board._center_x()
	board._spawn_dumpling(3, Vector2(cx - 17.0, board.FLOOR_Y - 34.0 - 6.0))
	await _frames(40)
	var t0: int = Time.get_ticks_msec()
	board._spawn_dumpling(3, Vector2(cx - 17.0 + 19.0, board.FLOOR_Y - 34.0 - 220.0))
	var finished_ms: int = -1
	var result_ms: int = -1
	for i in 240:
		await get_tree().physics_frame
		if finished_ms < 0 and board.is_finished():
			finished_ms = Time.get_ticks_msec() - t0
		if result_ms < 0 and _main._result.visible:
			result_ms = Time.get_ticks_msec() - t0
			break
	await _frames(30)
	var transients: Dictionary = {}
	var fx_left: int = 0
	if is_instance_valid(board):
		for child in board.get_children():
			if child != board._bokeh and (child is Sprite2D or child is Label or child is CPUParticles2D):
				fx_left += 1
	_log("  interop: finished @%d ms, result visible @%d ms (RESULT_DELAY %.1f s), round_finished ×%d, result visible=%s mode=%s, unlocked %d→%d, stars %s→%s, dough %d, board fx left %d, win anchor %s" % [
		finished_ms, result_ms, _main.RESULT_DELAY, _finished_count, str(_main._result.visible),
		str(int(_main._result.mode())) if _main._result.visible else "-", unlocked_before, SaveManager.highest_level_unlocked(),
		JSON.stringify(stars_before), JSON.stringify(SaveManager.data.get("level_stars", {})), SaveManager.dough(), fx_left,
		str(board._win_anchor) if is_instance_valid(board) else "-"])
	# İkinci tetik: kopya sonuç / ilerleme yok.
	if is_instance_valid(board):
		board._check_objective(Vector2(cx, board.FLOOR_Y - 100.0))
	await _frames(60)
	_log("  interop second trigger: round_finished ×%d, unlocked %d, result visible=%s" % [_finished_count,
		SaveManager.highest_level_unlocked(), str(_main._result.visible)])
	_main._result.hide_result()
	_main.abandon_run()
	await get_tree().process_frame
	_main._show_tab(0)
	_end("interop")


# --- durum dosyası -------------------------------------------------------------------------

func _write_state(label: String) -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("label: %s" % label)
	lines.append("time: %s" % Time.get_time_string_from_system())
	lines.append("view: %s hz: %.0f physics: %d" % [str(DisplayServer.window_get_size()),
		DisplayServer.screen_get_refresh_rate(), Engine.physics_ticks_per_second])
	lines.append("haptics: request %d dispatch %d suppressed %d | events: %s" % [Haptics.request_count, Haptics.dispatch_count,
		Haptics.suppressed_count, " ".join(_haptic_events) if not _haptic_events.is_empty() else "(yok)"])
	lines.append("perf: nodes=%d orphans=%d static_mb=%.1f fps=%d tweens=%d" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		int(Performance.get_monitor(Performance.TIME_FPS)), get_tree().get_processed_tweens().size()])
	lines.append("shots: %d" % _shot_count)
	lines.append("--- log ---")
	for i in range(_log_mark, _log_lines.size()):
		lines.append(_log_lines[i])
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()
	# Tam log her komutta yenilenir (gate sonunda alınır).
	var full := FileAccess.open("user://qa_log_full.txt", FileAccess.WRITE)
	if full != null:
		full.store_string("\n".join(_log_lines) + "\n")
		full.close()
	var json := FileAccess.open("user://qa_perf.json", FileAccess.WRITE)
	if json != null:
		json.store_string(JSON.stringify({"perf": _perf_results, "timings": _timings}, "\t"))
		json.close()
