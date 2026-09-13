extends SceneTree
## Ses asset'i ölçüm aracı (M8.5-15). Dev aracı — oyunda KULLANILMAZ.
##
## Her SFX'i AudioEffectCapture'lı bir bus'tan geçirip tepe (dBFS), RMS,
## etkin süre ve baş/son sessizlik payını yazar. Kulakla dinleme mümkün
## olmayan ortamda (headless / CI) kırpma (clipping) ve süre sorunlarını
## sayısal olarak yakalar. Dummy sürücü gerçek zamanlı mix yapar; toplam
## süre asset'lerin süre toplamı kadardır.
##
## Kullanım:
##   godot --headless --audio-driver Dummy --path . --script res://tools/audio_probe.gd
##   (opsiyonel: -- <res://path.ogg|wav> ... yalnızca o dosyalar)
##
## Not: `AudioManager.EVENTS` üzerinden bütün eşlenmiş dosyalar ölçülür; çıktı
## docs/AUDIO_AUDIT.md tablosundaki sayıların kaynağıdır.

## Autoload'lar --script modunda yüklenmez; tablo doğrudan script'ten okunuyor.
const AUDIO_MANAGER := preload("res://scripts/autoload/audio_manager.gd")
const SILENCE_DB: float = -60.0
const MAX_SECONDS: float = 8.0

var _capture: AudioEffectCapture


func _init() -> void:
	_run()


func _run() -> void:
	var paths: PackedStringArray = []
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		paths = args
	else:
		var seen: Dictionary = {}
		for id: StringName in AUDIO_MANAGER.EVENTS:
			var event: Dictionary = AUDIO_MANAGER.EVENTS[id]
			for path: String in AUDIO_MANAGER.stream_paths(event):
				if not seen.has(path):
					seen[path] = true
					paths.append(path)
	paths.sort()

	var bus_index: int = AudioServer.bus_count
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, "Probe")
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = MAX_SECONDS + 1.0
	AudioServer.add_bus_effect(bus_index, _capture)

	var player := AudioStreamPlayer.new()
	player.bus = &"Probe"
	root.add_child(player)
	# İlk kare gelmeden root'a eklenen node "ağaçta" sayılmıyor; play() hata verir.
	await process_frame

	print("dosya | süre(sn) | tepe dBFS | RMS dBFS | baş sessizlik | kuyruk sessizlik | kırpma örnekleri")
	print("--- | --- | --- | --- | --- | --- | ---")
	for path in paths:
		if not ResourceLoader.exists(path):
			print("%s | EKSİK | | | | |" % path)
			continue
		var stream: AudioStream = load(path)
		if stream == null:
			print("%s | YÜKLENEMEDİ | | | | |" % path)
			continue
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = false
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
		await _measure(player, stream, path)
	quit(0)


func _measure(player: AudioStreamPlayer, stream: AudioStream, path: String) -> void:
	_capture.clear_buffer()
	var frames: PackedVector2Array = []
	player.stream = stream
	player.play()
	var mix_rate: float = AudioServer.get_mix_rate()
	var start_ms: int = Time.get_ticks_msec()
	var idle_frames: int = 0
	while true:
		await process_frame
		var available: int = _capture.get_frames_available()
		if available > 0:
			frames.append_array(_capture.get_buffer(available))
		if not player.playing:
			idle_frames += 1
			# Kuyruğu boşalt: playback bitince birkaç kare daha oku.
			if idle_frames > 6:
				break
		if Time.get_ticks_msec() - start_ms > int(MAX_SECONDS * 1000.0):
			player.stop()
			break
	var available: int = _capture.get_frames_available()
	if available > 0:
		frames.append_array(_capture.get_buffer(available))

	var peak: float = 0.0
	var sum_sq: float = 0.0
	var clipped: int = 0
	var first: int = -1
	var last: int = -1
	var threshold: float = db_to_linear(SILENCE_DB)
	for i in frames.size():
		var f: Vector2 = frames[i]
		var a: float = maxf(absf(f.x), absf(f.y))
		if a >= 0.999:
			clipped += 1
		peak = maxf(peak, a)
		sum_sq += f.x * f.x
		if a >= threshold:
			if first < 0:
				first = i
			last = i
	var total: float = float(frames.size()) / mix_rate
	var rms_db: float = linear_to_db(sqrt(sum_sq / maxf(1.0, float(frames.size())))) \
		if frames.size() > 0 else -100.0
	var lead: float = (float(first) / mix_rate) if first >= 0 else total
	var tail: float = (float(frames.size() - 1 - last) / mix_rate) if last >= 0 else 0.0
	var active: float = (float(last - first + 1) / mix_rate) if first >= 0 else 0.0
	print("%s | %.2f (etkin %.2f) | %.1f | %.1f | %.3f | %.3f | %d" % [
		path.get_file(), total, active, linear_to_db(maxf(peak, 1e-6)), rms_db,
		lead, tail, clipped])
