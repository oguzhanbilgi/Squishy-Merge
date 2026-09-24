extends "res://tools/gameplay_device.gd"
## M8.8-02.1 — A36 production ses + titreşim cihaz kapısı sürücüsü. Dev aracı;
## üretim APK'sında YOK, AYRI bir QA paketiyle (`com.obappstudio.squishymerge.qa`,
## kendi veri dizini) yüklenir — owner kaydına dokunamaz.
##
## M8.7-02.1 sürücüsünün (gerçek board, komut döngüsü, gerçek titreşim, perf)
## üstüne: her komut boyunca SFX bus'ı AudioEffectCapture ile yakalanıp
## `user://qa_audio/<NN>_<komut>.wav` yazılır (tepe / kırpma / süre), olay
## sayaçları (play/drop farkı), her olayın ilk-son çalma anı (ms), en çok
## eşzamanlı kanal, bekleyen gecikmeli katman sayısı ve titreşim zaman
## çizelgesi loglanır. Owner dinleme paneli: ekranda 5 + 1 büyük düğme.
##
## Ek komutlar (gerisi gameplay_device'tan aynen: merge T, chain2/3, near,
## shake, upgrade T, perf …, t8x N, race …, interop, quit):
##   amerge T · aladder · at8x N · achain · aspam · adanger S
##   rmerge T · rbomb · rshake · rclear N · rupgrade T · rdanger
##   win · lose · fail · revive · chest · dough · rare · epic · legendary · ui
##   mute_t8 · hapoff_t8 · pause_t8 · leave_t8 · stop_t8 · bg_t8
##   perf clear_many · listen N (1 merge dizisi · 2 T8 · 3 Sarsıntı · 4 tehlike · 5 Legendary · 6 hepsi)

const AUDIO_DIR: String = "user://qa_audio"
const REC_TAIL_MS: int = 350
const REC_MAX_MS: int = 8000

var _capture: AudioEffectCapture
var _rec_active: bool = false
var _rec_t0: int = 0
var _rec_frames: PackedVector2Array = PackedVector2Array()
var _rec_index: int = 0
var _pc0: Dictionary = {}
var _dc0: Dictionary = {}
var _pc_last: Dictionary = {}
var _first_ms: Dictionary = {}
var _last_ms: Dictionary = {}
var _voices_max: int = 0
var _pending_max: int = 0
var _hap_ms: PackedStringArray = PackedStringArray()
var _busy: bool = false
var _panel: CanvasLayer


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(AUDIO_DIR))
	var sfx: int = AudioServer.get_bus_index(AudioManager.SFX_BUS)
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 2.0
	AudioServer.add_bus_effect(sfx, _capture)
	_build_panel()
	await super()


# --- yakalama / ölçüm ---------------------------------------------------------------------

func _process(delta: float) -> void:
	super(delta)
	if not _rec_active:
		return
	var available: int = _capture.get_frames_available()
	if available > 0:
		_rec_frames.append_array(_capture.get_buffer(available))
	_voices_max = maxi(_voices_max, _voices_playing())
	_pending_max = maxi(_pending_max, AudioManager.pending_delayed())
	var now: int = Time.get_ticks_msec() - _rec_t0
	for id in AudioManager.play_count:
		var n: int = int(AudioManager.play_count[id])
		if n > int(_pc_last.get(id, 0)):
			if not _first_ms.has(id):
				_first_ms[id] = now
			_last_ms[id] = now
			_pc_last[id] = n


func _voices_playing() -> int:
	var n: int = 0
	for voice in AudioManager._voices:
		if voice.playing:
			n += 1
	return n


func _on_device_haptic(duration_ms: int, amplitude: float) -> void:
	_hap_ms.append("+%d:%dms@%.2f" % [Time.get_ticks_msec() - _rec_t0, duration_ms, amplitude])
	super(duration_ms, amplitude)


func _rec_begin() -> void:
	AudioManager.play_count.clear()
	AudioManager.drop_count.clear()
	_pc0 = {}
	_dc0 = {}
	_pc_last = {}
	_first_ms = {}
	_last_ms = {}
	_hap_ms.clear()
	_voices_max = 0
	_pending_max = 0
	_capture.clear_buffer()
	_rec_frames = PackedVector2Array()
	_rec_t0 = Time.get_ticks_msec()
	_rec_active = true


func _rec_end(label: String) -> void:
	# Sessizleşene kadar bekle (kanal + bekleyen katman), sonra kuyruk payı.
	var quiet_since: int = -1
	while true:
		await get_tree().process_frame
		var now: int = Time.get_ticks_msec()
		var busy: bool = _voices_playing() > 0 or AudioManager.pending_delayed() > 0
		if busy:
			quiet_since = -1
		elif quiet_since < 0:
			quiet_since = now
		elif now - quiet_since > REC_TAIL_MS:
			break
		if now - _rec_t0 > REC_MAX_MS:
			break
	var available: int = _capture.get_frames_available()
	if available > 0:
		_rec_frames.append_array(_capture.get_buffer(available))
	_rec_active = false
	_rec_index += 1
	var safe: String = label.replace(" ", "_").replace("/", "_")
	var path: String = "%s/%02d_%s.wav" % [AUDIO_DIR, _rec_index, safe]
	var stats: Dictionary = _write_wav(path, _rec_frames)
	var events: PackedStringArray = PackedStringArray()
	var keys: Array = AudioManager.play_count.keys()
	keys.sort()
	for id in keys:
		events.append("%s×%d@%d..%d" % [id, AudioManager.play_count[id], int(_first_ms.get(id, -1)), int(_last_ms.get(id, -1))])
	var dropped: PackedStringArray = PackedStringArray()
	var dkeys: Array = AudioManager.drop_count.keys()
	dkeys.sort()
	for id in dkeys:
		dropped.append("%s×%d" % [id, AudioManager.drop_count[id]])
	_log("  audio[%s]: %s | len %.2f s peak %.1f dBFS clip %d rms %.1f | voices_max %d pending_max %d pending_now %d" % [
		path.get_file(), (", ".join(events) if not events.is_empty() else "(olay yok)"), stats["len"], stats["peak_db"],
		stats["clip"], stats["rms_db"], _voices_max, _pending_max, AudioManager.pending_delayed()])
	_log("  dropped: %s | haptic: %s | sink request %d dispatch %d suppressed %d" % [
		(", ".join(dropped) if not dropped.is_empty() else "yok"), (" ".join(_hap_ms) if not _hap_ms.is_empty() else "yok"),
		Haptics.request_count, Haptics.dispatch_count, Haptics.suppressed_count])


func _write_wav(path: String, frames: PackedVector2Array) -> Dictionary:
	var data := PackedByteArray()
	data.resize(frames.size() * 4)
	var peak: float = 0.0
	var clip: int = 0
	var sum_sq: float = 0.0
	for i in frames.size():
		var f: Vector2 = frames[i]
		var a: float = maxf(absf(f.x), absf(f.y))
		if a >= 0.999:
			clip += 1
		peak = maxf(peak, a)
		sum_sq += f.x * f.x
		data.encode_s16(i * 4, int(clampf(f.x, -1.0, 1.0) * 32767.0))
		data.encode_s16(i * 4 + 2, int(clampf(f.y, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = int(AudioServer.get_mix_rate())
	wav.data = data
	wav.save_to_wav(path)
	var n: int = maxi(frames.size(), 1)
	return {"len": float(frames.size()) / AudioServer.get_mix_rate(), "peak_db": linear_to_db(maxf(peak, 1e-6)),
		"clip": clip, "rms_db": linear_to_db(maxf(sqrt(sum_sq / float(n)), 1e-6))}


# --- komutlar ---------------------------------------------------------------------------------

func _handle(line: String) -> void:
	var parts: PackedStringArray = line.split(" ", false)
	var cmd: String = parts[0]
	var arg: String = parts[1] if parts.size() > 1 else ""
	_busy = true
	Haptics.reset_counters()
	_rec_begin()
	match cmd:
		"amerge":
			_merge_audio(int(arg))
			await _wait(0.9)
		"aladder":
			for t in range(1, 9):
				_merge_audio(t)
				await _wait(1.3)
		"at8x":
			var n: int = int(arg) if arg != "" else 5
			for i in n:
				_merge_audio(8)
				await _wait(0.45)
			await _wait(1.0)
		"achain":
			for i in 4:
				_merge_audio(2 + i)
				if i >= 1:
					AudioManager.play_combo(i + 1)
				await _wait(0.18)
			await _wait(0.8)
		"aspam":
			# 24 merge + 12 iniş 0.4 s içinde: kanal patlaması yok, tavanlar çalışır.
			for i in 24:
				AudioManager.play_merge(1 + (i * 7) % 8)
				Haptics.merge_tier(1 + (i * 7) % 8)
				if i % 2 == 0:
					AudioManager.play_landing(1 + i % 5, 700.0)
				await get_tree().process_frame
			await _wait(1.2)
		"adanger":
			var secs: float = float(arg) if arg != "" else 6.0
			var ticks: int = int(secs / 0.5)
			for i in ticks:
				AudioManager.play(&"danger")
				await _wait(0.5)
		"rmerge":
			await _real_merge(int(arg))
		"rbomb":
			await _real_bomb()
		"rshake":
			await _real_shake()
		"rclear":
			await _real_clear(int(arg) if arg != "" else 12)
		"rupgrade":
			await _real_upgrade(int(arg) if arg != "" else 4)
		"rdanger":
			await _real_danger()
		"win":
			AudioManager.play(&"round_win")
		"lose":
			AudioManager.play(&"round_lose")
		"fail":
			AudioManager.play(&"fail")
			Haptics.medium()
		"revive":
			AudioManager.play(&"revive")
			Haptics.medium()
		"chest":
			AudioManager.play(&"chest_open")
			await _wait(0.35)
			AudioManager.play_reward(SkinData.Rarity.COMMON)
			Haptics.light()
		"dough":
			AudioManager.play_reward(SkinData.Rarity.COMMON)
			Haptics.light()
		"rare":
			AudioManager.play_reward(SkinData.Rarity.RARE)
			Haptics.medium()
		"epic":
			AudioManager.play_reward(SkinData.Rarity.EPIC)
			Haptics.medium()
		"legendary":
			AudioManager.play_reward(SkinData.Rarity.LEGENDARY)
			Haptics.special()
		"ui":
			AudioManager.play(&"ui_tap")
			await _wait(0.5)
			AudioManager.play(&"ui_purchase")
			await _wait(0.6)
			AudioManager.play(&"ui_modal_close")
			await _wait(0.5)
			AudioManager.play(&"ui_invalid")
			await _wait(0.6)
			AudioManager.play(&"ui_modal_open")
			await _wait(0.5)
			AudioManager.play(&"power_arm")
		"mute_t8":
			await _mute_t8()
		"hapoff_t8":
			await _hapoff_t8()
		"pause_t8":
			await _state_t8("pause")
		"leave_t8":
			await _state_t8("leave")
		"stop_t8":
			_merge_audio(8)
			await get_tree().process_frame
			AudioManager.stop_all()
			_log("  stop_all bir kare sonra: pending %d" % AudioManager.pending_delayed())
			await _wait(0.6)
		"bg_t8":
			# Dışarıdan HOME basılır; harness 6 s boyunca ilk-çalma anlarını izler.
			_merge_audio(8)
			await _wait(6.0)
		"perf":
			if arg == "clear_many":
				await _perf_clear_many()
			else:
				await super(line)
		"listen":
			await _listen(int(arg) if arg != "" else 6)
		_:
			await super(line)
	await _rec_end(line)
	_busy = false


func _merge_audio(tier: int) -> void:
	AudioManager.play_merge(tier)
	Haptics.merge_tier(tier)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# --- gerçek board yolları (kare çekimi YOK) ------------------------------------------------

func _real_merge(tier: int) -> void:
	await _make_board("res://resources/levels/level_08.tres" if tier < 7 else "res://resources/levels/endless.tres")
	var cx: float = _board._center_x()
	var r: float = TierConfig.radius(tier)
	_spawn(tier, Vector2(cx - r * 0.5, _board.FLOOR_Y - r - 6.0))
	await _settle(90)
	var merged: Array = [-1]
	var cb := func(_t: int, _p: Vector2) -> void: merged[0] = Time.get_ticks_msec() - _rec_t0
	GameState.merge_performed.connect(cb)
	_spawn(tier, Vector2(cx - r * 0.5 + r * 0.55, _board.FLOOR_Y - r - 260.0))
	for i in 240:
		await get_tree().physics_frame
		if merged[0] >= 0:
			break
	GameState.merge_performed.disconnect(cb)
	_log("  rmerge T%d+T%d → merge_performed @%d ms; tiers %s; score %d" % [tier, tier, merged[0], _tiers(), GameState.score])
	await _wait(1.4)


func _real_bomb() -> void:
	_refill_stock()
	await _make_board("res://resources/levels/level_06.tres")
	await _pile([[5, 3, 5, 3], [4, 2, 4, 2], [1, 3, 1]])
	var target: Dumpling = _find(4, false)
	if target == null:
		target = _find(3, false)
	var n0: int = _count()
	_board._powerups.request(PowerUp.Type.BOMB)
	var t_use: int = Time.get_ticks_msec() - _rec_t0
	_board._use_targeted_power(target)
	await _wait(1.4)
	_log("  rbomb: use @%d ms, pieces %d→%d, score %d (0 beklenir)" % [t_use, n0, _count(), GameState.score])


func _real_shake() -> void:
	_refill_stock()
	await _make_board("res://resources/levels/endless.tres")
	await _pile([[8, 7, 6], [6, 5, 5, 4], [4, 3, 4, 3, 3], [2, 2, 3, 2, 1, 2]])
	var t_use: int = Time.get_ticks_msec() - _rec_t0
	_board._use_shake()
	await _wait(1.5)
	_log("  rshake: use @%d ms, protection %.2f, pieces %d" % [t_use, _board._shake_protection, _count()])


func _real_clear(small: int) -> void:
	_refill_stock()
	await _make_board("res://resources/levels/level_06.tres")
	# Satır paritesi dönüşümlü: yan yana ve üst üste aynı tier gelmesin (merge olmasın).
	var rows: Array = [[6, 5, 4, 3]]
	var left: int = small
	var k: int = 0
	while left > 0:
		var row: Array = []
		for i in mini(left, 6):
			row.append(1 + ((i + k) % 2))
		rows.append(row)
		left -= row.size()
		k += 1
	await _pile(rows)
	var n0: int = _count()
	var t_use: int = Time.get_ticks_msec() - _rec_t0
	_board._use_clear_small()
	await _wait(1.6)
	_log("  rclear: %d küçük parça, use @%d ms, pieces %d→%d" % [small, t_use, n0, _count()])


func _real_upgrade(tier: int) -> void:
	_refill_stock()
	await _make_board("res://resources/levels/level_08.tres" if tier < 7 else "res://resources/levels/endless.tres")
	var cx: float = _board._center_x()
	var t: Dumpling = _spawn(tier, Vector2(cx, _board.FLOOR_Y - TierConfig.radius(tier) - 6.0))
	await _settle(60)
	_board._powerups.request(PowerUp.Type.UPGRADE)
	var t_use: int = Time.get_ticks_msec() - _rec_t0
	_board._use_targeted_power(t)
	var mutated: int = -1
	for i in 60:
		await get_tree().physics_frame
		if mutated < 0 and not is_instance_valid(t):
			mutated = Time.get_ticks_msec() - _rec_t0
	_log("  rupgrade T%d→T%d: tap @%d ms, transform @%d ms (Δ %d ms), tiers %s, score %d" % [tier, tier + 1, t_use, mutated,
		mutated - t_use, _tiers(), GameState.score])
	await _wait(1.2)


func _real_danger() -> void:
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
	var offered: Array = [-1]
	_board.revive_offered.connect(func(_r: int) -> void: offered[0] = Time.get_ticks_msec() - _rec_t0)
	var t_top: int = Time.get_ticks_msec() - _rec_t0
	_spawn(8, Vector2(cx, y - 100.0 - 4.0))
	for i in 600:
		await get_tree().physics_frame
		if offered[0] >= 0:
			break
	_log("  rdanger: top piece @%d ms, revive offered @%d ms (taşma 1.5 s), fail_pending=%s" % [t_top, offered[0], str(_board.is_fail_pending())])
	await _wait(0.8)
	var granted: bool = _board.grant_revive()
	_log("  rdanger: grant_revive → %s" % str(granted))
	await _wait(1.5)


func _perf_clear_many() -> void:
	_refill_stock()
	_begin("perf_clear_many")
	await _make_board("res://resources/levels/level_06.tres")
	await _pile([[6, 5, 4], [1, 2, 1, 2, 1, 2, 1], [2, 1, 2, 1, 2, 1], [1, 2, 1, 2, 1], [2, 1, 2]])
	var small: int = 0
	for child in _board._dumpling_layer.get_children():
		if child is Dumpling and (child as Dumpling).tier <= 2:
			small += 1
	_perf_begin()
	_board._use_clear_small()
	await _frames(120)
	_perf_end("clear_many", "Temizleyici %d küçük parça (süpürme + pop dizisi)" % small)
	_end("perf_clear_many")


# --- ayar / uygulama durumu ----------------------------------------------------------------

func _mute_t8() -> void:
	_merge_audio(8)
	AudioManager.set_sfx_enabled(false)
	_log("  SFX OFF hemen: bus mute=%s" % str(not AudioManager.is_sfx_enabled()))
	await _wait(0.6)
	_log("  mute sırasında katmanlar: tier_max %d box %d tail %d, pending %d (mute bus'ta; katmanlar sessiz akar)" % [
		int(AudioManager.play_count.get(&"tier_max", 0)), int(AudioManager.play_count.get(&"tier_max_box", 0)),
		int(AudioManager.play_count.get(&"tier_max_tail", 0)), AudioManager.pending_delayed()])
	AudioManager.set_sfx_enabled(true)
	_log("  SFX ON: bus mute=%s → T4 çalınıyor" % str(not AudioManager.is_sfx_enabled()))
	_merge_audio(4)
	await _wait(0.8)


func _hapoff_t8() -> void:
	Haptics.set_enabled(false)
	_merge_audio(8)
	await _wait(0.5)
	_log("  Titreşim KAPALI: T8 → dispatch %d (0 beklenir), request %d" % [Haptics.dispatch_count, Haptics.request_count])
	Haptics.set_enabled(true)
	Haptics.reset_counters()
	_merge_audio(8)
	await _wait(0.5)
	_log("  Titreşim AÇIK: T8 → dispatch %d (2 beklenir: 35 + 60 ms)" % Haptics.dispatch_count)


func _state_t8(kind: String) -> void:
	await _make_board("res://resources/levels/endless.tres")
	var cx: float = _board._center_x()
	_spawn(7, Vector2(cx - 40.0, _board.FLOOR_Y - 81.0 - 6.0))
	await _settle(90)
	var merged: Array = [-1]
	var cb := func(_t: int, _p: Vector2) -> void: merged[0] = Time.get_ticks_msec() - _rec_t0
	GameState.merge_performed.connect(cb)
	_spawn(7, Vector2(cx - 40.0 + 44.0, _board.FLOOR_Y - 81.0 - 320.0))
	for i in 240:
		await get_tree().physics_frame
		if merged[0] >= 0:
			break
	GameState.merge_performed.disconnect(cb)
	var t_act: int = Time.get_ticks_msec() - _rec_t0
	if kind == "pause":
		_board.set_menu_paused(true)
	else:
		await _teardown()
	_log("  %s_t8: merge @%d ms → %s @%d ms; pending o an %d" % [kind, merged[0], kind, t_act, AudioManager.pending_delayed()])
	await _wait(0.7)
	_log("  %s_t8 +0.7 s: tier_max %d box %d tail %d, pending %d, voices %d" % [kind,
		int(AudioManager.play_count.get(&"tier_max", 0)), int(AudioManager.play_count.get(&"tier_max_box", 0)),
		int(AudioManager.play_count.get(&"tier_max_tail", 0)), AudioManager.pending_delayed(), _voices_playing()])
	if kind == "pause" and _board != null and is_instance_valid(_board):
		_board.set_menu_paused(false)
		await _wait(0.4)


# --- owner dinleme paneli ---------------------------------------------------------------------

func _build_panel() -> void:
	_panel = CanvasLayer.new()
	_panel.layer = 100
	add_child(_panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 40.0
	box.offset_right = -40.0
	box.offset_top = -1000.0
	box.offset_bottom = -180.0
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	var labels: Array = ["1 · Merge dizisi (T1–T5)", "2 · Tier 8 merge", "3 · Sarsıntı", "4 · Tehlike (6 sn)",
		"5 · Legendary ödül", "6 · Hepsi sırayla"]
	for i in labels.size():
		var b := Button.new()
		b.text = labels[i]
		b.custom_minimum_size = Vector2(0, 110)
		b.add_theme_font_size_override("font_size", 44)
		b.pressed.connect(_on_listen_pressed.bind(i + 1))
		box.add_child(b)


func _on_listen_pressed(n: int) -> void:
	if _busy:
		return
	_busy = true
	_log("--- panel: listen %d ---" % n)
	Haptics.reset_counters()
	_rec_begin()
	await _listen(n)
	await _rec_end("panel_listen_%d" % n)
	_write_state("panel listen %d" % n)
	_busy = false


func _listen(n: int) -> void:
	match n:
		1:
			for t in [1, 2, 3, 4, 5, 3, 2, 4]:
				_merge_audio(t)
				await _wait(0.75)
		2:
			_merge_audio(8)
			await _wait(1.8)
		3:
			AudioManager.play(&"shake")
			Haptics.medium()
			await _wait(1.2)
		4:
			for i in 12:
				AudioManager.play(&"danger")
				await _wait(0.5)
		5:
			AudioManager.play_reward(SkinData.Rarity.LEGENDARY)
			Haptics.special()
			await _wait(1.8)
		_:
			for k in range(1, 6):
				await _listen(k)
				await _wait(1.2)
