extends Node
## Entegre ses sisteminin masaüstü dinleme / teknik QA paketi (M8.8-02). DEV ARACI.
##
## AudioManager'ın GERÇEK olay tablosu, katmanları, gecikmeleri ve seviyeleri
## ile her senaryoyu çalar, SFX bus'ını (HardLimiter dahil) AudioEffectCapture
## ile yakalar ve senaryo başına bir WAV yazar. Kaynak dosyaları değil,
## oyuncunun duyacağı karışımı üretir — inceleme kanıtıdır, asset değildir.
##
## Kullanım:
##   godot --headless --audio-driver Dummy --path . res://tools/audio_event_render.tscn
##   çıktı: build/qa_m8.8-02/audition/<NN>_<senaryo>.wav + INDEX.md
##
## Kayıt dosyasına yazmaz (yalnız AudioManager çağrıları). Titreşim çağrıları
## sink'e yakalanır ve INDEX'te listelenir (ses/titreşim hizası görünür olsun).

const OUT_DIR: String = "res://build/qa_m8.8-02/audition"
const TAIL_S: float = 0.35
const MAX_S: float = 6.0

var _capture: AudioEffectCapture
var _pending_actions: int = 0
var _haptic_log: Array[String] = []
var _t0_ms: int = 0
var _index: Array[String] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var sfx: int = AudioServer.get_bus_index(AudioManager.SFX_BUS)
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = MAX_S + 1.0
	AudioServer.add_bus_effect(sfx, _capture)
	Haptics.set_sink(_on_haptic, true)
	Haptics.set_enabled(true)
	await get_tree().process_frame
	await get_tree().process_frame

	await _record("merge_T1", func() -> void: _merge(1))
	await _record("merge_T2", func() -> void: _merge(2))
	await _record("merge_T3", func() -> void: _merge(3))
	await _record("merge_T4", func() -> void: _merge(4))
	await _record("merge_T5", func() -> void: _merge(5))
	await _record("merge_T6", func() -> void: _merge(6))
	await _record("merge_T7", func() -> void: _merge(7))
	await _record("merge_T8", func() -> void: _merge(8))
	await _record("merge_chain_T1_to_T4_combo", func() -> void:
		for i in 4:
			_at(0.22 * i, func() -> void:
				_merge(1 + i)
				if i >= 1:
					AudioManager.play_combo(i + 1)))
	await _record("drop_and_land_T1_T5", func() -> void:
		AudioManager.play_drop()
		_at(0.30, func() -> void: AudioManager.play_landing(1, 520.0))
		_at(0.80, func() -> void: AudioManager.play_drop())
		_at(1.10, func() -> void: AudioManager.play_landing(5, 900.0)))
	await _record("buyutucu_normal_T4_to_T5", func() -> void:
		AudioManager.play(&"upgrade")
		_at(0.15, func() -> void:
			AudioManager.play(&"upgrade_transform")
			AudioManager.play_merge(5)
			Haptics.medium()))
	await _record("buyutucu_T7_to_T8", func() -> void:
		AudioManager.play(&"upgrade")
		_at(0.15, func() -> void:
			AudioManager.play(&"upgrade_transform")
			AudioManager.play_merge(8)
			Haptics.special()))
	await _record("bomba", func() -> void:
		AudioManager.play(&"power_arm")
		_at(0.40, func() -> void: AudioManager.play(&"bomb_whoosh"))
		_at(0.40 + 0.28, func() -> void:
			AudioManager.play(&"bomb_impact")
			Haptics.strong()))
	await _record("sarsinti", func() -> void:
		AudioManager.play(&"shake")
		Haptics.medium())
	await _record("temizleyici_8_pieces", func() -> void:
		Haptics.light()
		AudioManager.play(&"clear_sweep")
		for i in 8:
			_at(0.045 * i, func() -> void: AudioManager.play(&"clear_puff", 1.0 + 0.04 * float(1 + i % 2))))
	await _record("danger_4_ticks", func() -> void:
		for i in 4:
			_at(0.5 * i, func() -> void: AudioManager.play(&"danger")))
	await _record("fail_overflow_then_revive", func() -> void:
		AudioManager.play(&"fail")
		Haptics.medium()
		_at(1.2, func() -> void:
			AudioManager.play(&"revive")
			Haptics.medium()))
	await _record("win_round", func() -> void: AudioManager.play(&"round_win"))
	await _record("lose_round", func() -> void: AudioManager.play(&"round_lose"))
	await _record("stars_x3", func() -> void:
		for i in 3:
			_at(0.20 * i, func() -> void: AudioManager.play(&"star_reveal", 1.0 + 0.12 * float(i))))
	await _record("chest_open_then_dough", func() -> void:
		AudioManager.play(&"chest_open")
		_at(0.35, func() -> void:
			AudioManager.play_reward(SkinData.Rarity.COMMON)
			Haptics.light()))
	await _record("reward_dough", func() -> void: AudioManager.play_reward(SkinData.Rarity.COMMON))
	await _record("reward_rare", func() -> void:
		AudioManager.play_reward(SkinData.Rarity.RARE)
		Haptics.medium())
	await _record("reward_epic", func() -> void:
		AudioManager.play_reward(SkinData.Rarity.EPIC)
		Haptics.medium())
	await _record("reward_legendary", func() -> void:
		AudioManager.play_reward(SkinData.Rarity.LEGENDARY)
		Haptics.special())
	await _record("daily_reward", func() -> void: AudioManager.play(&"daily_reward"))
	await _record("level_unlock", func() -> void: AudioManager.play(&"level_unlock"))
	await _record("annihilation_endless", func() -> void:
		AudioManager.play(&"annihilation")
		Haptics.strong())
	await _record("ui_family_tap_confirm_back_error", func() -> void:
		AudioManager.play(&"ui_tap")
		_at(0.5, func() -> void: AudioManager.play(&"ui_purchase"))
		_at(1.1, func() -> void: AudioManager.play(&"ui_modal_close"))
		_at(1.6, func() -> void: AudioManager.play(&"ui_invalid"))
		_at(2.2, func() -> void: AudioManager.play(&"ui_modal_open"))
		_at(2.7, func() -> void: AudioManager.play(&"ui_toggle_on"))
		_at(3.2, func() -> void: AudioManager.play(&"ui_equip"))
		_at(3.7, func() -> void: AudioManager.play(&"power_arm")))
	await _record("mix_hierarchy_tap_vs_merge_T4_vs_bomb", func() -> void:
		AudioManager.play(&"ui_tap")
		_at(0.5, func() -> void: _merge(4))
		_at(1.2, func() -> void: AudioManager.play(&"bomb_impact")))

	_write_index()
	Haptics.set_sink(Callable(), false)
	print("=== audition bundle: %d files -> %s ===" % [_index.size(), OUT_DIR])
	get_tree().quit()


func _merge(tier: int) -> void:
	AudioManager.play_merge(tier)
	Haptics.merge_tier(tier)


func _at(seconds: float, action: Callable) -> void:
	if seconds <= 0.0:
		action.call()
		return
	_pending_actions += 1
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		_pending_actions -= 1
		action.call())


func _on_haptic(duration_ms: int, amplitude: float) -> void:
	_haptic_log.append("+%d ms: %d ms @ %.2f" % [Time.get_ticks_msec() - _t0_ms, duration_ms, amplitude])


func _record(name: String, action: Callable) -> void:
	AudioManager.stop_all()
	Haptics.reset_counters()
	await get_tree().process_frame
	await get_tree().process_frame
	_capture.clear_buffer()
	_haptic_log.clear()
	AudioManager.play_count.clear()
	_t0_ms = Time.get_ticks_msec()
	var frames: PackedVector2Array = []
	action.call()
	var quiet_since_ms: int = -1
	while true:
		await get_tree().process_frame
		var available: int = _capture.get_frames_available()
		if available > 0:
			frames.append_array(_capture.get_buffer(available))
		var busy: bool = _pending_actions > 0 or AudioManager.pending_delayed() > 0 or _any_voice_playing()
		var now: int = Time.get_ticks_msec()
		if busy:
			quiet_since_ms = -1
		elif quiet_since_ms < 0:
			quiet_since_ms = now
		elif now - quiet_since_ms > int(TAIL_S * 1000.0) and now - _t0_ms > 400:
			break
		if now - _t0_ms > int(MAX_S * 1000.0):
			break
	var available: int = _capture.get_frames_available()
	if available > 0:
		frames.append_array(_capture.get_buffer(available))
	var path: String = "%s/%02d_%s.wav" % [OUT_DIR, _index.size() + 1, name]
	var peak: float = _write_wav(path, frames)
	var events: PackedStringArray = []
	var keys: Array = AudioManager.play_count.keys()
	keys.sort()
	for id in keys:
		events.append("%s×%d" % [id, AudioManager.play_count[id]])
	_index.append("| %02d | `%s` | %.2f s | %.1f dBFS | %s | %s |" % [_index.size() + 1, path.get_file(),
		float(frames.size()) / AudioServer.get_mix_rate(), linear_to_db(maxf(peak, 1e-6)),
		", ".join(events), ("; ".join(_haptic_log) if not _haptic_log.is_empty() else "yok")])
	print("  %s  %.2fs  peak %.1f dBFS  [%s]  haptic: %s" % [path.get_file(), float(frames.size()) / AudioServer.get_mix_rate(),
		linear_to_db(maxf(peak, 1e-6)), ", ".join(events), "; ".join(_haptic_log)])


func _any_voice_playing() -> bool:
	for voice in AudioManager._voices:
		if voice.playing:
			return true
	return false


## Stereo 16-bit WAV (yakalanan bus çıkışı). Dönüş: tepe (lineer).
func _write_wav(path: String, frames: PackedVector2Array) -> float:
	var data := PackedByteArray()
	data.resize(frames.size() * 4)
	var peak: float = 0.0
	for i in frames.size():
		var f: Vector2 = frames[i]
		peak = maxf(peak, maxf(absf(f.x), absf(f.y)))
		data.encode_s16(i * 4, int(clampf(f.x, -1.0, 1.0) * 32767.0))
		data.encode_s16(i * 4 + 2, int(clampf(f.y, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = int(AudioServer.get_mix_rate())
	wav.data = data
	wav.save_to_wav(path)
	return peak


func _write_index() -> void:
	var lines: PackedStringArray = [
		"# M8.8-02 integrated audio audition bundle",
		"",
		"Rendered by `tools/audio_event_render.gd` from the ACTUAL `AudioManager` (event table,",
		"layers, delays, gains, SFX bus HardLimiter) with the Dummy driver at %d Hz. Stereo 16-bit" % int(AudioServer.get_mix_rate()),
		"captures of the SFX bus; evidence for review only — not assets. Haptic column = what",
		"`Haptics` dispatched (sink), relative to the scenario start.",
		"",
		"| # | file | length | peak | events played | haptics |",
		"|---|---|---|---|---|---|",
	]
	lines.append_array(_index)
	lines.append("")
	var f := FileAccess.open("%s/INDEX.md" % OUT_DIR, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
