extends "res://tools/result_shots.gd"
## M8.6-09.1 — A36 cihaz kapısı sürücüsü. Dev aracı; üretim APK'sında YOK
## (`tools/*` preset dışında), ayrı bir QA paketiyle yüklenir.
##
## result_shots.gd'nin durumlarını cihazda GERÇEK çözünürlükte açar ve her
## çekim noktasında DURUR: ekran görüntüsü dışarıdan (adb screencap) alınır,
## dokunma testleri (kart üstünde sürükleme, fling, buton) canlı pencerede
## yapılır. Komut kanalı `user://qa_cmd.txt` (adb run-as ile yazılır, okunan
## komut silinir), durum/istatistik `user://qa_state.txt`.
##
## Komutlar: start · next · stats · scroll_top · scroll_end · dup_show
## (aynı sonucu ikinci kez show_result — kopya pencere/kart üretmemeli) ·
## dup_finish (board._finish tekrar — guard, ikinci round_finished YOK) ·
## timeline (reveal'i yeniden başlatıp N kareyi user://qa_shots'a yazar) · quit
##
## Ek cihaz durumları:
##   D4 — 4 ödül (level sandığı + 3 bonus).
##   R1 — GERÇEK kanonik kazanma yolu: temiz ilerleme (Level 1 açık), bot
##        Level 1'i gerçek fizikle GERÇEK zamanda oynar; round_finished
##        Main'e GİDER → complete_level / record_stars / ChestSystem RNG /
##        add_merges / save_game → RESULT_DELAY → show_result. Öncesi/sonrası
##        kayıt özeti + dosya sha256 durum dosyasına yazılır.
##   R2 — GERÇEK kayıp yolu: bot yalnız ortaya bırakır → taşma → gerçek Devam
##        teklifi (cihazda BİTİR'e dokunulur) → round_finished(false) →
##        teselli → sonuç. Sürücü teklife dokunmaz.

const BOT_BRAIN = preload("res://tools/bot_brain.gd")
const CMD_PATH: String = "user://qa_cmd.txt"
const STATE_PATH: String = "user://qa_state.txt"
const ONLY_PATH: String = "user://qa_only.txt"
const LEVEL_01: String = "res://resources/levels/level_01.tres"
const LEVEL_02: String = "res://resources/levels/level_02.tres"
const POLL: float = 0.2
const TIMELINE_INTERVAL: float = 0.1
const TIMELINE_FRAMES: int = 36

var _hold: String = ""
var _last_args: Array = []
var _bot_active: bool = false
var _bot_center_only: bool = false
var _profile_deltas: PackedFloat32Array = PackedFloat32Array()
var _profile_start_msec: int = -1
var _star_msec: Array[int] = [-1, -1, -1]
var _card_appear_msec: Array[int] = []
var _card_open_msec: Array[int] = []
var _snapshot_before: Dictionary = {}
var _real_finish_msec: int = -1
var _real_result_msec: int = -1


func _ready() -> void:
	_out_dir = ProjectSettings.globalize_path("user://qa_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_size = DisplayServer.window_get_size()
	if FileAccess.file_exists(ONLY_PATH):
		_only = FileAccess.get_file_as_string(ONLY_PATH).strip_edges().split(",", false)
	# Masaüstü kuru koşu: `-- only=01,05` de kabul edilir.
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("only="):
			_only = String(arg).trim_prefix("only=").split(",", false)
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
	if _main._daily != null:
		_main._daily.visible = false
	_apply_showcase()
	print("[qa] ready view=", _size, " only=", _only)
	_write_state("ready")
	await _wait_for("start")

	await _group_states()
	await _device_states()

	_write_state("done")
	print("[qa] done")
	await _wait_for("quit")
	SaveManager.data = _saved_data
	_restore_save_file()
	get_tree().quit()


# --- Komut kanalı ----------------------------------------------------------------

func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _read_cmd() -> String:
	if not FileAccess.file_exists(CMD_PATH):
		return ""
	var cmd: String = FileAccess.get_file_as_string(CMD_PATH).strip_edges()
	_remove(CMD_PATH)
	return cmd


func _wait_for(expected: String) -> void:
	while true:
		await get_tree().create_timer(POLL).timeout
		var cmd: String = _read_cmd()
		if cmd == expected:
			return
		if cmd != "":
			await _handle(cmd)


## Çekim noktası: dur, komutları işle, `next` gelince devam et.
func _capture(name: String) -> void:
	_hold = name
	await get_tree().process_frame
	_write_state("hold " + name)
	print("[qa] hold ", name)
	while true:
		await get_tree().create_timer(POLL).timeout
		var cmd: String = _read_cmd()
		if cmd == "":
			continue
		if cmd == "next":
			break
		await _handle(cmd)
	_hold = ""


func _handle(cmd: String) -> void:
	print("[qa] cmd ", cmd)
	match cmd:
		"stats":
			_write_state("hold " + _hold)
		"scroll_top":
			var scroll: ScrollContainer = _main._result.frame().get_meta(&"scroll")
			scroll.scroll_vertical = 0
		"scroll_end":
			var scroll2: ScrollContainer = _main._result.frame().get_meta(&"scroll")
			scroll2.scroll_vertical = int(scroll2.get_v_scroll_bar().max_value)
		"dup_show":
			if _last_args.size() == 8:
				_main._result.show_result(_last_args[0], _last_args[1], _last_args[2], _last_args[3],
					_last_args[4], _last_args[5], _last_args[6], _last_args[7])
				await _settle(0.5)
			_write_state("hold " + _hold + " after dup_show")
		"dup_finish":
			if _main._board != null and is_instance_valid(_main._board) and _last_args.size() == 8:
				_main._board._finish(_last_args[1])
				await _settle(1.2)
			_write_state("hold " + _hold + " after dup_finish")
		"timeline":
			await _timeline()
		_:
			print("[qa] bilinmeyen komut: ", cmd)


# --- Durum / istatistik --------------------------------------------------------------

func _result_layers() -> int:
	var n: int = 0
	for child in _main.get_children():
		if child is CanvasLayer and child.get_script() == _main._result.get_script():
			n += 1
	return n


func _save_sha() -> String:
	if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		return "(yok)"
	return FileAccess.get_sha256(SaveManager.SAVE_PATH)


func _save_summary() -> Dictionary:
	return {
		"dough": SaveManager.dough(),
		"highest": SaveManager.highest_level_unlocked(),
		"stars": SaveManager.data.get("level_stars", {}),
		"skins": SaveManager.owned_skins().size(),
		"skin_list": SaveManager.owned_skins(),
		"merges_since_bonus": int(SaveManager.data.get("merges_since_bonus_chest", 0)),
		"total_merges": int(SaveManager.data.get("total_merges", 0)),
		"endless_high": SaveManager.endless_high_score(),
		"file_sha256": _save_sha(),
	}


func _profile_summary() -> Dictionary:
	var n: int = _profile_deltas.size()
	if n == 0:
		return {"frames": 0}
	var total: float = 0.0
	var worst: float = 0.0
	var over25: int = 0
	var over40: int = 0
	for d in _profile_deltas:
		total += d
		worst = maxf(worst, d)
		if d > 0.025:
			over25 += 1
		if d > 0.040:
			over40 += 1
	return {"frames": n, "avg_ms": snappedf(total / float(n) * 1000.0, 0.1),
		"max_ms": snappedf(worst * 1000.0, 0.1), "over25ms": over25, "over40ms": over40,
		"span_s": snappedf(total, 0.01)}


func _write_state(label: String) -> void:
	var r: CanvasLayer = _main._result
	var cards: Array[ResultRewardCard] = r.cards()
	var opened: int = 0
	for card in cards:
		if card.is_opened():
			opened += 1
	var fx: int = r.fx_layer().get_child_count()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("label: %s" % label)
	lines.append("time: %s" % Time.get_time_string_from_system())
	lines.append("view: %s" % str(DisplayServer.window_get_size()))
	lines.append("result_visible: %s  result_layers: %d  mode: %d  title: %s" % [
		str(r.visible), _result_layers(), int(r.mode()) if r.visible else -1, r.title_text() if r.visible else ""])
	lines.append("cards: %d  opened: %d  reveal_done: %s  fx_children: %d" % [cards.size(), opened, str(r.is_reveal_done()), fx])
	lines.append("buttons: primary='%s' secondary='%s'" % [r.primary_text(), r.secondary_text()])
	lines.append("chips: score='%s' target='%s' record='%s' dough='%s' endless='%s'" % [
		r.score_text(), r.target_text(), r.record_text(), r.dough_text(), r.endless_score_text()])
	lines.append("unlock: '%s'  encourage: '%s'" % [r.unlock_text(), r.encourage_text()])
	if r.visible and bool(r.frame().get_meta(&"body_scrolls", false)):
		var scroll: ScrollContainer = r.frame().get_meta(&"scroll")
		lines.append("scroll: v=%d max=%d page=%d" % [scroll.scroll_vertical,
			int(scroll.get_v_scroll_bar().max_value), int(scroll.get_v_scroll_bar().page)])
	else:
		lines.append("scroll: (gövde kaymıyor)")
	lines.append("frame_rect: %s" % str(r.frame().get_global_rect()) if r.visible else "frame_rect: -")
	lines.append("nodes: %d  orphans: %d  static_mem_mb: %.1f  fps: %d" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		int(Performance.get_monitor(Performance.TIME_FPS))])
	lines.append("profile: %s" % JSON.stringify(_profile_summary()))
	lines.append("stars_msec: %s  card_appear_msec: %s  card_open_msec: %s" % [
		str(_star_msec), str(_card_appear_msec), str(_card_open_msec)])
	lines.append("save: %s" % JSON.stringify(_save_summary()))
	if not _snapshot_before.is_empty():
		lines.append("save_before: %s" % JSON.stringify(_snapshot_before))
		lines.append("real_path: finish->result %d ms" % (_real_result_msec - _real_finish_msec))
	lines.append("board: %s" % ("yok" if _main._board == null or not is_instance_valid(_main._board) else
		"finished=%s fail_pending=%s score=%d merges=%d" % [str(_main._board.is_finished()),
			str(_main._board.is_fail_pending()), GameState.score, GameState.merge_count]))
	lines.append("revive_visible: %s  pause_visible: %s  active_tab: %d" % [
		str(_main._revive.visible), str(_main._pause.visible), _main._active_tab])
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()


## Reveal profili: sonuç görünür ve reveal bitmemişken kare süreleri toplanır;
## yıldız/kart ilk görünme zamanları (show_result'a göre ms) kaydedilir.
func _process(delta: float) -> void:
	if _main == null or _main._result == null:
		return
	var r: CanvasLayer = _main._result
	if not r.visible:
		return
	if _profile_start_msec < 0:
		return
	var now: int = Time.get_ticks_msec() - _profile_start_msec
	if not r.is_reveal_done():
		_profile_deltas.append(delta)
	var strip: ResultStarStrip = r.star_strip()
	for i in 3:
		if _star_msec[i] < 0 and i < strip.stars().size() and strip.stars()[i].scale.x > 0.001 \
				and i < strip.earned():
			_star_msec[i] = now
	var cards: Array[ResultRewardCard] = r.cards()
	while _card_appear_msec.size() < cards.size():
		_card_appear_msec.append(-1)
		_card_open_msec.append(-1)
	for i in cards.size():
		if _card_appear_msec[i] < 0 and cards[i].modulate.a > 0.01:
			_card_appear_msec[i] = now
		if _card_open_msec[i] < 0 and cards[i].is_opened():
			_card_open_msec[i] = now


func _reset_profile() -> void:
	_profile_deltas = PackedFloat32Array()
	_profile_start_msec = Time.get_ticks_msec()
	_star_msec = [-1, -1, -1]
	_card_appear_msec = []
	_card_open_msec = []


## Aynı durumu yeniden açıp reveal'i kare kare kaydeder (viewport okuma —
## bu KAYIT sırasında kare süresi bozulur, zamanlama kanıtı için; akıcılık
## kararı profil + screenrecord ile).
func _timeline() -> void:
	if _last_args.size() != 8:
		return
	var frames: Array[Image] = []
	var stamps: PackedInt32Array = PackedInt32Array()
	_main._result.show_result(_last_args[0], _last_args[1], _last_args[2], _last_args[3],
		_last_args[4], _last_args[5], _last_args[6], _last_args[7])
	var t0: int = Time.get_ticks_msec()
	for i in TIMELINE_FRAMES:
		await get_tree().create_timer(TIMELINE_INTERVAL).timeout
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
		frames.append(img)
		stamps.append(Time.get_ticks_msec() - t0)
	for i in frames.size():
		frames[i].save_png(_out_dir.path_join("tl_%s_%02d_%04dms.png" % [_hold, i, stamps[i]]))
	print("[qa] timeline ", frames.size(), " kare -> ", _out_dir)
	_write_state("hold " + _hold + " after timeline")


# --- Durum açma (profil kancası) -------------------------------------------------------

func _open(level_path: String, won: bool, score: int, rewards: Array[ChestReward],
		new_record: bool, pile: Array = PILE_MEDIUM, newly_unlocked: bool = false,
		reached_tier: int = 0, wait: float = -1.0) -> void:
	_snapshot_before = {}
	await _start_board(level_path)
	await _pile(pile)
	GameState.reset_run()
	GameState.add_score(score)
	var board: Node2D = _main._board
	var level: LevelData = _main._current_level
	board._is_finished = false
	board._finish(won)
	_main._revive.hide_offer()
	var stars: int = level.stars_earned(won, score)
	_last_args = [level, won, score, stars, rewards, new_record, newly_unlocked, reached_tier]
	_reset_profile()
	_main._result.show_result(level, won, score, stars, rewards, new_record, newly_unlocked, reached_tier)
	if wait < 0.0:
		wait = REVEAL_BASE + REVEAL_PER_CARD * float(rewards.size()) + 0.5
	await _settle(wait)


# --- Ek cihaz durumları ------------------------------------------------------------------

func _device_states() -> void:
	var l4: LevelData = load(LEVEL_04)
	var s3: int = l4.star_3_threshold() + 40
	# D4: 4 ödül (level sandığı + 3 bonus sandık) — MANY_REWARDS eşiği (hızlı tempo).
	await _shot("D4", "rewards_4", LEVEL_04, true, s3,
		[_dough(SkinData.Rarity.RARE), _skin(SkinData.Rarity.COMMON, 3), _dough(SkinData.Rarity.EPIC),
			_dough(SkinData.Rarity.LEGENDARY)])
	if _wants("R1"):
		await _real_round(LEVEL_01, false, "R1_real_win")
	if _wants("R2"):
		await _real_round(LEVEL_02, true, "R2_real_fail_revive")
	_apply_showcase()


## Gerçek yol: temiz ilerleme dosyaya yazılır, level kanonik `_start_level`
## ile başlar, round_finished Main'e BAĞLI KALIR. Bot gerçek zamanda oynar
## (center_only=true → hep ortaya, taşma amaçlı). Round bitince Main'in
## RESULT_DELAY'i ve sonuç ekranı beklenir; kayıp yolunda önce Devam teklifi
## açılır ve sürücü bekler (BİTİR'e cihazda dokunulur).
func _real_round(level_path: String, center_only: bool, hold_name: String) -> void:
	SaveManager.data["highest_level_unlocked"] = 2 if center_only else 1
	SaveManager.data["level_stars"] = {"1": 2} if center_only else {}
	SaveManager.data["dough"] = 100
	SaveManager.data["unlocked_skins"] = ["common_01"]
	SaveManager.data["equipped_skin"] = ""
	SaveManager.data["merges_since_bonus_chest"] = 62
	SaveManager.data["total_merges"] = 300
	SaveManager.data["endless_high_score"] = 0
	SaveManager.data["powerups"] = {"bomb": 2, "upgrade": 1, "shake": 1, "clear_small": 1}
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.save_game()
	_snapshot_before = _save_summary()
	_last_args = []
	_real_finish_msec = -1
	_real_result_msec = -1
	_main._start_level(load(level_path))
	await get_tree().process_frame
	await get_tree().process_frame
	_main._board._dismiss_tutorial()
	_main._result.hide_result()
	_reset_profile()
	_profile_start_msec = -1
	_bot_center_only = center_only
	_bot_active = true
	var board: Node2D = _main._board
	var steps: int = 0
	while is_instance_valid(board) and not board.is_finished() and steps < 60 * 240:
		await get_tree().physics_frame
		steps += 1
		if board.is_fail_pending():
			# Gerçek Devam teklifi açık: bot durur, karar cihazda verilir.
			_bot_active = false
			_write_state("wait_revive " + hold_name)
			print("[qa] revive teklifi açık — BİTİR bekleniyor")
			while is_instance_valid(board) and board.is_fail_pending():
				await get_tree().process_frame
				var cmd: String = _read_cmd()
				if cmd != "":
					await _handle(cmd)
	_bot_active = false
	if not is_instance_valid(board):
		return
	_real_finish_msec = Time.get_ticks_msec()
	_profile_start_msec = Time.get_ticks_msec()
	while not _main._result.visible:
		await get_tree().process_frame
	_real_result_msec = Time.get_ticks_msec()
	var level: LevelData = _main._current_level
	var won: bool = not center_only
	_last_args = [level, won, GameState.score, level.stars_earned(won, GameState.score),
		_main._result._rewards, false, SaveManager.highest_level_unlocked() > int(_snapshot_before["highest"]), 0]
	await _settle(REVEAL_BASE + REVEAL_PER_CARD * float(_main._result.cards().size()) + 0.5)
	await _capture(hold_name)
	await _leave_board()


func _physics_process(_delta: float) -> void:
	if not _bot_active:
		return
	var board: Node2D = _main._board
	if board == null or not is_instance_valid(board) or board.is_finished() or board.is_fail_pending():
		return
	if board._drop_cooldown > 0.0:
		return
	if _bot_center_only:
		board._set_aim(board._center_x())
	else:
		board._set_aim(BOT_BRAIN.pick_x(board, board._pending_tier))
	board._drop()
