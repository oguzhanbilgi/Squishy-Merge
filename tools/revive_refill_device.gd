extends "res://tools/revive_refill_shots.gd"
## M8.6-10.1 — A36 cihaz kapısı sürücüsü (Devam + Refill). Dev aracı; üretim
## APK'sında YOK (`tools/*` preset dışında), ayrı bir QA paketiyle yüklenir ve
## kendi veri dizininde çalışır (owner kaydına dokunamaz).
##
## Komut güdümlü: `user://qa_cmd.txt` (adb run-as ile yazılır, okunan komut
## silinir), durum `user://qa_state.txt`. Bütün buton dokunuşları CİHAZDA
## gerçek dokunuşla (adb input tap) yapılır — durum dosyası buton
## dikdörtgenlerini EKRAN pikseli olarak verir.
##
## Komutlar:
##   start · quit · stats · leave
##   board10 / board4      detached board (level 10 tehlike yığını / level 4 orta)
##   real10                GERÇEK kayıp yolu: main'e bağlı board, bot ortaya
##                         bırakır → gerçek taşma → gerçek Devam teklifi (cihazda
##                         karar) → round_finished → teselli → sonuç
##   offer N               devam teklifi (N = kullanılmış hak)
##   refill bomb|upgrade|shake|clear
##   provider on|off       test sağlayıcısı (talebi sayar, cevabı komut verir)
##   dough N · stock B U S C · quota 0|1   (belleğe + dosyaya yazar)
##   grant_revive · fail_revive · grant_power · fail_power · late_power
##   watch MS              MS boyunca 50 ms'de bir görünürlük zaman çizelgesi
##   idle S                S saniye dinlenme: düğüm/fps/bellek başta ve sonda
##
## SAHTE REKLAM YOK: `_QaProvider` yalnız test çiftidir, üretimde yoktur.

const CMD_PATH: String = "user://qa_cmd.txt"
const STATE_PATH: String = "user://qa_state.txt"
const POLL: float = 0.2


class _QaProvider extends RefCounted:
	var revive_requests: int = 0
	var power_requests: int = 0
	var last_type: int = -1
	var last_token: int = 0

	func show_rewarded_revive(_main: Node) -> void:
		revive_requests += 1

	func show_rewarded_power(_main: Node, type: int, token: int) -> void:
		power_requests += 1
		last_type = type
		last_token = token


var _provider: _QaProvider = _QaProvider.new()
var _provider_on: bool = false
var _last_grant: String = "-"
var _timeline: PackedStringArray = PackedStringArray()
var _idle: String = "-"
var _bot_active: bool = false
var _real_finish_msec: int = -1
var _real_result_msec: int = -1
var _finished_count: int = 0


func _ready() -> void:
	_out_dir = ProjectSettings.globalize_path("user://qa_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_size = DisplayServer.window_get_size()
	_remove(CMD_PATH)
	await get_tree().process_frame
	await get_tree().process_frame
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_saved_data = SaveManager.data.duplicate(true)
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_showcase()
	SaveManager.save_game()
	print("[qa] ready view=", _size)
	_write_state("ready")
	while true:
		await get_tree().create_timer(POLL).timeout
		var cmd: String = _read_cmd()
		if cmd == "":
			continue
		if cmd == "quit":
			break
		await _handle(cmd)
	_write_state("quit")
	SaveManager.data = _saved_data
	_restore_save_file()
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


func _type_of(word: String) -> int:
	match word:
		"bomb": return int(PowerUp.Type.BOMB)
		"upgrade": return int(PowerUp.Type.UPGRADE)
		"shake": return int(PowerUp.Type.SHAKE)
		"clear": return int(PowerUp.Type.CLEAR_SMALL)
	return -1


func _board() -> Node2D:
	return _main._board if _main._board != null and is_instance_valid(_main._board) else null


func _handle(line: String) -> void:
	var parts: PackedStringArray = line.split(" ", false)
	var cmd: String = parts[0]
	print("[qa] cmd ", line)
	match cmd:
		"start", "stats":
			pass
		"board10":
			await _leave_if_any()
			await _start_board(LEVEL_10, true)
			_hook_finished()
			await _pile(PILE_DANGER)
			GameState.reset_run()
			GameState.add_score(3120)
			_main._board._refresh_power_bar()
		"board4":
			await _leave_if_any()
			await _start_board(LEVEL_04, true)
			_hook_finished()
			await _pile(PILE_MEDIUM)
			GameState.reset_run()
			GameState.add_score(860)
			_main._board._refresh_power_bar()
		"real10":
			await _leave_if_any()
			await _real_fail()
		"offer":
			if _board() != null:
				await _open_offer(int(parts[1]) if parts.size() > 1 else 0)
		"refill":
			if _board() != null and parts.size() > 1:
				var t: int = _type_of(parts[1])
				if t >= 0:
					_main._board._on_power_refill_requested(t)
					await _settle(0.3)
		"provider":
			_provider_on = parts.size() > 1 and parts[1] == "on"
			_main.set_rewarded_provider(_provider if _provider_on else null)
			if _main._refill.visible:
				_main._refill.refresh(_provider_on)
		"dough":
			SaveManager.data["dough"] = int(parts[1])
			SaveManager.save_game()
			if _main._refill.visible:
				_main._refill.refresh(_provider_on)
		"stock":
			SaveManager.data["powerups"] = {"bomb": int(parts[1]), "upgrade": int(parts[2]),
				"shake": int(parts[3]), "clear_small": int(parts[4])}
			SaveManager.save_game()
			if _board() != null:
				_main._board._refresh_power_bar()
		"quota":
			_set_quota_used(parts.size() > 1 and parts[1] == "1")
			SaveManager.save_game()
			if _main._refill.visible:
				_main._refill.refresh(_provider_on)
		"grant_revive":
			_last_grant = "grant_revive=%s" % str(_main.grant_revive())
		"fail_revive":
			_main.notify_rewarded_unavailable("Reklam yüklenemedi (test).")
			_last_grant = "fail_revive"
		"grant_power":
			_last_grant = "grant_power(type=%d,token=%d)=%s" % [_provider.last_type, _provider.last_token,
				str(_main.grant_rewarded_power(_provider.last_type, _provider.last_token))]
		"late_power":
			_last_grant = "late_power(type=%d,token=%d)=%s" % [_provider.last_type, _provider.last_token,
				str(_main.grant_rewarded_power(_provider.last_type, _provider.last_token))]
		"fail_power":
			_main.notify_power_rewarded_unavailable("Reklam yüklenemedi (test).")
			_last_grant = "fail_power"
		"watch":
			await _watch(int(parts[1]) if parts.size() > 1 else 2000)
		"idle":
			await _idle_probe(float(parts[1]) if parts.size() > 1 else 15.0)
		"hide_offer":
			_main._revive.hide_offer()
		"offer_exhausted":
			# Savunma durumu: runtime hak yokken teklif AÇMAZ; pencerenin 0/2 hâli.
			_main._revive.show_offer(0, _main._board.max_revives() if _board() != null else 2, _provider_on)
		"overflow":
			# Gerçek kapı: hak bitmişse teklif açılmaz, round doğrudan biter.
			if _board() != null:
				_main._board._trigger_overflow_fail()
				await _settle(0.3)
		"leave":
			await _leave_if_any()
		_:
			print("[qa] bilinmeyen komut: ", line)
	await get_tree().process_frame
	_write_state(line)


func _hook_finished() -> void:
	_finished_count = 0
	if _board() != null:
		_main._board.round_finished.connect(func(_won: bool) -> void: _finished_count += 1)


func _leave_if_any() -> void:
	_bot_active = false
	if _board() != null or _main._result.visible:
		await _leave_board()
	_apply_showcase()


## Gerçek kayıp yolu: main'e BAĞLI board, bot ortaya bırakır, gerçek taşma →
## gerçek Devam teklifi. Sürücü teklife dokunmaz; karar cihazda verilir.
func _real_fail() -> void:
	_main._start_level(load(LEVEL_10))
	await get_tree().process_frame
	await get_tree().process_frame
	_main._board._dismiss_tutorial()
	_hook_finished()
	_apply_safe_top_to_board()
	_main._result.hide_result()
	_real_finish_msec = -1
	_real_result_msec = -1
	_bot_active = true
	var board: Node2D = _main._board
	var steps: int = 0
	while is_instance_valid(board) and not board.is_fail_pending() and not board.is_finished() and steps < 60 * 240:
		await get_tree().physics_frame
		steps += 1
	_bot_active = false
	print("[qa] real10: fail_pending=", str(is_instance_valid(board) and board.is_fail_pending()), " steps=", steps)


func _physics_process(_delta: float) -> void:
	if not _bot_active:
		return
	var board: Node2D = _board()
	if board == null or board.is_finished() or board.is_fail_pending():
		return
	if board._drop_cooldown > 0.0:
		return
	board._set_aim(board._center_x())
	board._drop()


func _watch(ms: int) -> void:
	_timeline.clear()
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 <= ms:
		var b: Node2D = _board()
		_timeline.append("%d:rev=%d res=%d ref=%d fin=%d fp=%d" % [Time.get_ticks_msec() - t0,
			1 if _main._revive.visible else 0, 1 if _main._result.visible else 0,
			1 if _main._refill.visible else 0, 1 if (b != null and b.is_finished()) else 0,
			1 if (b != null and b.is_fail_pending()) else 0])
		await get_tree().create_timer(0.05).timeout


func _idle_probe(seconds: float) -> void:
	var n0: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var m0: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var fps_min: int = 999
	var fps_max: int = 0
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		await get_tree().create_timer(0.5).timeout
		var fps: int = int(Performance.get_monitor(Performance.TIME_FPS))
		fps_min = mini(fps_min, fps)
		fps_max = maxi(fps_max, fps)
	var n1: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var m1: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	_idle = "idle %.0fs: nodes %d->%d orphans %d static_mb %.1f->%.1f fps %d..%d tweens_running %d" % [
		seconds, n0, n1, int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), m0, m1,
		fps_min, fps_max, _running_tweens()]


func _running_tweens() -> int:
	var n: int = 0
	for tween in get_tree().get_processed_tweens():
		if tween.is_running():
			n += 1
	return n


func _rect_px(control: Control) -> String:
	if control == null or not control.is_visible_in_tree():
		return "-"
	var xf: Transform2D = get_viewport().get_screen_transform()
	var r: Rect2 = control.get_global_rect()
	var a: Vector2 = xf * r.position
	var b: Vector2 = xf * r.end
	var c: Vector2 = (a + b) * 0.5
	return "px[%d,%d-%d,%d c=%d,%d]" % [int(a.x), int(a.y), int(b.x), int(b.y), int(c.x), int(c.y)]


func _save_sha() -> String:
	return FileAccess.get_sha256(SaveManager.SAVE_PATH) if FileAccess.file_exists(SaveManager.SAVE_PATH) else "(yok)"


func _write_state(label: String) -> void:
	var lines: PackedStringArray = PackedStringArray()
	var rv: CanvasLayer = _main._revive
	var rf: CanvasLayer = _main._refill
	var b: Node2D = _board()
	lines.append("label: %s" % label)
	lines.append("time: %s" % Time.get_time_string_from_system())
	lines.append("view: %s canvas: %s scale: %s" % [str(DisplayServer.window_get_size()),
		str(get_viewport().get_visible_rect().size), str(get_viewport().get_screen_transform().get_scale())])
	lines.append("revive: visible=%s hearts=%d/%d text='%s' cta_disabled=%s pending=%s provider_ready=%s note='%s'" % [
		str(rv.visible), rv.hearts_available(), rv.hearts().size(), rv.remaining_text(),
		str(rv.continue_button().disabled), str(rv.is_request_pending()), str(rv.provider_ready()), rv.note_text()])
	lines.append("revive_rects: frame=%s continue=%s decline=%s" % [_rect_px(rv.frame()),
		_rect_px(rv.continue_button()), _rect_px(rv.decline_button())])
	lines.append("refill: visible=%s type=%d name='%s' ribbon='%s' stock='%s' price='%s' balance='%s' quota='%s'" % [
		str(rf.visible), rf.current_type(), rf.power_name_text(), rf.ribbon_text(), rf.stock_text(),
		rf.price_text(), rf.balance_text(), rf._quota.text])
	lines.append("refill_state: ad_disabled=%s ad_note='%s' dough_disabled=%s dough_note='%s' note='%s' pending=%s purchase_sent=%s" % [
		str(rf._ad.disabled), rf.ad_note_text(), str(rf._dough.disabled), rf.dough_note_text(), rf.note_text(),
		str(rf.is_request_pending()), str(rf.is_purchase_sent())])
	lines.append("refill_rects: frame=%s ad=%s dough=%s close=%s x=%s hero=%s" % [_rect_px(rf.frame()),
		_rect_px(rf._ad), _rect_px(rf._dough), _rect_px(rf._close), _rect_px(rf.close_button()), _rect_px(rf.hero_art())])
	if b != null:
		lines.append("slots: bomb=%s upgrade=%s shake=%s clear=%s hud_back=%s" % [
			_rect_px(b._power_bar.slot(int(PowerUp.Type.BOMB))), _rect_px(b._power_bar.slot(int(PowerUp.Type.UPGRADE))),
			_rect_px(b._power_bar.slot(int(PowerUp.Type.SHAKE))), _rect_px(b._power_bar.slot(int(PowerUp.Type.CLEAR_SMALL))),
			_rect_px(b._hud.back_button)])
	lines.append("board: %s" % ("yok" if b == null else "finished=%s fail_pending=%s refill_pending=%s revives_used=%d remaining=%d armed=%s bar_enabled=%s score=%d finished_count=%d" % [
		str(b.is_finished()), str(b.is_fail_pending()), str(b.is_refill_pending()), b.revives_used(),
		b.revives_remaining(), str(b._powerups.is_armed()), str(b._power_bar._enabled), GameState.score, _finished_count]))
	lines.append("provider: on=%s revive_requests=%d power_requests=%d last_type=%d last_token=%d main_pending_token=%d main_pending_type=%d last_grant=%s" % [
		str(_provider_on), _provider.revive_requests, _provider.power_requests, _provider.last_type,
		_provider.last_token, _main._refill_pending_token, _main._refill_pending_type, _last_grant])
	lines.append("result: visible=%s mode=%s  pause: %s  settings: %s  tab: %d" % [str(_main._result.visible),
		str(int(_main._result.mode())) if _main._result.visible else "-", str(_main._pause.visible),
		str(_main._settings.visible), _main._active_tab])
	lines.append("save: dough=%d powerups=%s rewarded_date='%s' grants=%d quota_left=%d sha256=%s" % [
		SaveManager.dough(), JSON.stringify(SaveManager.data.get("powerups", {})),
		String(SaveManager.data.get("rewarded_power_date", "")), int(SaveManager.data.get("rewarded_power_grants", 0)),
		RewardedPolicy.remaining_today(), _save_sha()])
	lines.append("perf: nodes=%d orphans=%d static_mb=%.1f fps=%d tweens_running=%d" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		int(Performance.get_monitor(Performance.TIME_FPS)), _running_tweens()])
	lines.append("idle: %s" % _idle)
	if not _timeline.is_empty():
		lines.append("timeline: %s" % " | ".join(_timeline))
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()
