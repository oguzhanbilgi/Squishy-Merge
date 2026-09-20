extends Node
## SFX servisi + titreşim davranış testi (M8.5-15, M8.8-02 production seti). Dev aracı.
##
## Kullanım:
##   godot --headless --audio-driver Dummy --path . res://tools/audio_test.tscn
##
## Dummy sürücü gerçek zamanlı mix yapar: `playing` bayrağı, soğuma sayaçları
## ve gecikmeli katman zamanlayıcıları gerçek zamanla ilerler, o yüzden
## testler birkaç kare/ms bekler.
##
## KAYIT: ayar anahtarları save_game() çağırır. Kayıt dosyası test başında
## byte-byte yedeklenir ve sonunda geri yazılır (owner kaydı bozulmaz).

const GAME_BOARD_SOURCE: String = "res://scripts/game/game_board.gd"
const ROUND_RESULT_SOURCE: String = "res://scripts/ui/round_result.gd"
## Her çağrı noktasının kullandığı olaylar (production haritası; docs/audio/AUDIO_SYSTEM.md).
const PRODUCTION_EVENTS: Array[StringName] = [
	&"ui_tap", &"ui_tab", &"ui_modal_open", &"ui_modal_close", &"ui_toggle_on", &"ui_select",
	&"ui_purchase", &"ui_invalid", &"ui_equip",
	&"drop", &"land", &"merge", &"merge_body_light", &"merge_body_full", &"merge_body_large",
	&"merge_sparkle", &"merge_chime", &"tier_max", &"tier_max_box", &"tier_max_tail",
	&"annihilation", &"combo", &"danger", &"fail", &"round_lose", &"round_win", &"revive",
	&"power_arm", &"bomb_whoosh", &"bomb_impact", &"bomb_poof", &"upgrade", &"upgrade_transform",
	&"shake", &"clear_sweep", &"clear_puff",
	&"star_reveal", &"chest_open", &"reward_common", &"reward_rare", &"reward_epic",
	&"reward_epic_tail", &"reward_legendary", &"reward_legendary_box", &"reward_legendary_box_up",
	&"reward_legendary_tail", &"daily_reward", &"level_unlock",
]

var _fails: int = 0
var _save_backup: PackedByteArray = []
var _save_existed: bool = false


func _c(name: String, ok: bool) -> void:
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	_backup_save()
	await get_tree().process_frame
	await _test_loading()
	await _test_files_and_format()
	await _test_fallback()
	await _test_rng_isolation()
	await _test_merge_recipe()
	await _test_delayed_layers()
	await _test_cooldown_and_voices()
	await _test_priority()
	await _test_settings()
	await _test_haptics()
	await _test_merge_haptic_mapping()
	await _test_call_sites()
	await _test_gameplay_state_untouched()
	_restore_save()
	print("=== SONUC: %d kaldi ===" % _fails)
	get_tree().quit()


# --- Yükleme / eşleme ---

func _test_loading() -> void:
	_c("AudioManager autoload yüklü", AudioManager != null)
	_c("SFX bus var", AudioServer.get_bus_index(AudioManager.SFX_BUS) >= 0)
	_c("SFX bus'ında limiter", AudioServer.get_bus_effect_count(
		AudioServer.get_bus_index(AudioManager.SFX_BUS)) >= 1)
	var missing_map: PackedStringArray = []
	var missing_stream: PackedStringArray = []
	for id in PRODUCTION_EVENTS:
		if not AudioManager.EVENTS.has(id):
			missing_map.append(String(id))
		elif not AudioManager.has_stream(id):
			missing_stream.append(String(id))
	_c("bütün production olayları tabloda (%s)" % ", ".join(missing_map), missing_map.is_empty())
	_c("bütün production olaylarının akışı yüklü (%s)" % ", ".join(missing_stream), missing_stream.is_empty())
	_c("tabloda listelenmemiş olay yok (%d = %d)" % [AudioManager.EVENTS.size(), PRODUCTION_EVENTS.size()],
		AudioManager.EVENTS.size() == PRODUCTION_EVENTS.size())
	_c("açılışta eksik dosya uyarısı yok", AudioManager.missing_events().is_empty())
	# Bilinmeyen olay ve eksik akış çökertmez.
	_c("bilinmeyen olay false döner", AudioManager.play(&"boyle_bir_ses_yok") == false)
	AudioManager._streams.erase(&"ui_tab")
	_c("akışı silinen olay false döner, çökmez", AudioManager.play(&"ui_tab") == false)
	AudioManager._load_streams()
	_c("akış yeniden yüklendi", AudioManager.has_stream(&"ui_tab"))
	# Her tablo satırı geçerli öncelik / tavan / katman / gecikme taşıyor.
	var bad: int = 0
	for id: StringName in AudioManager.EVENTS:
		var e: Dictionary = AudioManager.EVENTS[id]
		if int(e.get("max_voices", 1)) < 1 or int(e.get("priority", 0)) < 0 \
				or int(e.get("priority", 0)) > AudioManager.Priority.CRITICAL \
				or int(e.get("delay_ms", 0)) < 0 or int(e.get("delay_ms", 0)) > 500:
			bad += 1
		for layer in e.get("layers", []):
			if not AudioManager.EVENTS.has(layer) or layer == id:
				bad += 1
		var fb: StringName = e.get("fallback", &"")
		if fb != &"" and not AudioManager.EVENTS.has(fb):
			bad += 1
	_c("tablo tutarlı (tavan/öncelik/katman/gecikme/fallback)", bad == 0)
	# Legacy/interim isimler tabloda yok.
	_c("eski merge_high olayı kalktı", not AudioManager.EVENTS.has(&"merge_high"))


## Disk üzerindeki her production dosyası tabloda kullanılıyor; tabloda
## kullanılan her dosya diskte; hepsi WAV 44.1 kHz mono 16-bit, loop kapalı.
func _test_files_and_format() -> void:
	var referenced: Dictionary = {}
	for id: StringName in AudioManager.EVENTS:
		for path in AudioManager.stream_paths(AudioManager.EVENTS[id]):
			referenced[path] = true
	var on_disk: Dictionary = {}
	_collect_wavs(AudioManager.SFX_ROOT, on_disk)
	var unreferenced: PackedStringArray = []
	for path in on_disk:
		if not referenced.has(path):
			unreferenced.append(path.get_file())
	var absent: PackedStringArray = []
	for path in referenced:
		if not on_disk.has(path):
			absent.append(path.get_file())
	_c("assets/audio/sfx'teki her dosya bir olayda kullanılıyor (%s)" % ", ".join(unreferenced),
		unreferenced.is_empty())
	_c("tablodaki her dosya diskte (%s)" % ", ".join(absent), absent.is_empty())
	_c("interim sentez / kenney_*.ogg dosyaları kalktı", not on_disk.keys().any(
		func(p: String) -> bool: return p.get_file().begins_with("kenney_") or p.ends_with(".ogg")))
	var bad_format: PackedStringArray = []
	var loops: int = 0
	var long_normal: PackedStringArray = []
	for path in referenced:
		var stream: AudioStream = load(path)
		if stream is AudioStreamWAV:
			var wav: AudioStreamWAV = stream
			if wav.mix_rate != 44100 or wav.stereo or wav.format != AudioStreamWAV.FORMAT_16_BITS:
				bad_format.append(path.get_file())
			if wav.loop_mode != AudioStreamWAV.LOOP_DISABLED:
				loops += 1
		else:
			bad_format.append(path.get_file())
	_c("hepsi WAV 44.1 kHz / mono / 16-bit PCM (%s)" % ", ".join(bad_format), bad_format.is_empty())
	_c("hiçbir akış loop'lu değil", loops == 0)
	# Sık çalan olayların dosyaları kısa (tekrar yorgunluğu): merge katmanları
	# ve pop'lar ≤ 0.5 s, tier 8 bloom'u ≤ 1.2 s.
	for id in [&"merge", &"merge_body_light", &"merge_body_full", &"merge_body_large",
			&"merge_sparkle", &"merge_chime", &"land", &"drop", &"clear_puff", &"danger", &"ui_tap"]:
		for path in AudioManager.stream_paths(AudioManager.EVENTS[id]):
			var wav: AudioStreamWAV = load(path)
			if wav.get_length() > 0.5:
				long_normal.append(path.get_file())
	_c("sık çalan katmanlar ≤ 0.5 s (%s)" % ", ".join(long_normal), long_normal.is_empty())
	var bloom: AudioStreamWAV = load(AudioManager.stream_paths(AudioManager.EVENTS[&"tier_max"])[0])
	_c("tier 8 bloom'u 0.8–1.2 s (özel = uzun, gürültülü değil)", bloom.get_length() >= 0.8 and bloom.get_length() <= 1.2)


func _collect_wavs(dir_path: String, out: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var full: String = "%s/%s" % [dir_path, name]
		if dir.current_is_dir():
			if not name.begins_with("."):
				_collect_wavs(full, out)
		elif name.ends_with(".wav") or name.ends_with(".ogg"):
			out[full] = true
		name = dir.get_next()
	dir.list_dir_end()


# --- Eksik dosya → fallback zinciri ---

func _test_fallback() -> void:
	AudioManager._streams.erase(&"merge_body_large")
	AudioManager._resolve_fallbacks()
	_c("large gövde eksikse full havuzuna düşer", AudioManager.has_stream(&"merge_body_large")
		and AudioManager._streams[&"merge_body_large"] == AudioManager._streams[&"merge_body_full"])
	AudioManager._streams.erase(&"merge_body_large")
	AudioManager._streams.erase(&"merge_body_full")
	AudioManager._resolve_fallbacks()
	_c("zincir: large → full → light", AudioManager.has_stream(&"merge_body_large")
		and AudioManager._streams[&"merge_body_large"] == AudioManager._streams[&"merge_body_light"]
		and AudioManager._streams[&"merge_body_full"] == AudioManager._streams[&"merge_body_light"])
	_c("fallback'li olay play() true döner", AudioManager.play(&"merge_body_large"))
	AudioManager._streams.erase(&"tier_max")
	AudioManager._resolve_fallbacks()
	_c("fallback'siz olay eksikse sessiz + false, çökmez", not AudioManager.has_stream(&"tier_max")
		and AudioManager.play(&"tier_max") == false)
	AudioManager._load_streams()
	_c("tam yükleme fallback'leri gerçek havuzlarla değiştirdi",
		AudioManager._streams[&"merge_body_large"] != AudioManager._streams[&"merge_body_full"]
		and AudioManager.has_stream(&"tier_max") and AudioManager.missing_events().is_empty())
	AudioManager.stop_all()
	await _settle()


# --- Yerel RNG: global gameplay RNG'sine dokunmaz ---

func _test_rng_isolation() -> void:
	seed(4242)
	var expected: Array[int] = [randi(), randi(), randi()]
	seed(4242)
	for i in 40:
		AudioManager.play_drop()
		AudioManager.play_landing(1 + i % 8, 500.0 + 40.0 * i)
		AudioManager.play_merge(1 + i % 8)
		AudioManager.play(&"clear_puff")
		if i % 10 == 0:
			AudioManager.play_reward(i / 10 % 4)
		await get_tree().process_frame
	# Gecikmeli katmanlar da ateşlensin (zamanlayıcı geri çağrıları yerel RNG kullanır).
	await get_tree().create_timer(0.3).timeout
	var actual: Array[int] = [randi(), randi(), randi()]
	_c("ses varyasyonu (gecikmeli katmanlar dahil) global RNG'yi tüketmedi", expected == actual)
	# Yerel RNG deterministik: aynı tohum aynı sıra.
	var a := RandomNumberGenerator.new()
	a.seed = AudioManager.AUDIO_RNG_SEED
	var b := RandomNumberGenerator.new()
	b.seed = AudioManager.AUDIO_RNG_SEED
	_c("yerel RNG tohumu deterministik", a.randf() == b.randf())
	AudioManager.stop_all()
	await _settle()


# --- Merge reçetesi: tier bandı gövde, parıltı / çan eşiği, tier 8 katmanları ---

func _count(id: StringName) -> int:
	return int(AudioManager.play_count.get(id, 0))


func _reset_counts() -> void:
	AudioManager.stop_all()
	AudioManager.play_count.clear()
	AudioManager.drop_count.clear()


func _test_merge_recipe() -> void:
	_c("reçete 8 tier", AudioManager.MERGE_RECIPE.size() == TierConfig.MAX_TIER)
	_c("parıltı eşiği 3, çan eşiği 5", AudioManager.MERGE_SPARKLE_MIN_TIER == 3
		and AudioManager.MERGE_CHIME_MIN_TIER == 5)
	var bands_ok: bool = true
	for t in range(1, 9):
		var body: StringName = AudioManager.merge_recipe(t)["body"]
		var want: StringName = &"merge_body_light" if t <= 3 else (&"merge_body_full" if t <= 6 else &"merge_body_large")
		if body != want:
			bands_ok = false
	_c("gövde havuzu tier bandı: light T1–3 / full T4–6 / large T7–8", bands_ok)
	# Gövde pitch'i tier arttıkça pesleşir (bant içinde), seviye artar; POP T1 en sessiz.
	var r1: Dictionary = AudioManager.merge_recipe(1)
	var r3: Dictionary = AudioManager.merge_recipe(3)
	var r8: Dictionary = AudioManager.merge_recipe(8)
	_c("T1 POP T3'ten sessiz, gövde seviyesi T1 < T8, T8 gövde pitch ≥ 0.8 (telefon bandı)",
		float(r1["pop_db"]) < float(r3["pop_db"]) and float(r1["body_db"]) < float(r8["body_db"])
		and float(r8["body_pitch"]) >= 0.8)
	# Her tier'ı tek tek çalıp hangi olayların gerçekten çaldığına bak
	# (gecikmeli katmanlar için 200 ms bekle).
	var per_tier: Dictionary = {}
	for t in range(1, 9):
		_reset_counts()
		await _settle()
		AudioManager.play_merge(t)
		await get_tree().create_timer(0.2).timeout
		per_tier[t] = AudioManager.play_count.duplicate()
	var pop_ok: bool = true
	var body_ok: bool = true
	var sparkle_ok: bool = true
	var chime_ok: bool = true
	for t in range(1, 9):
		var pc: Dictionary = per_tier[t]
		if int(pc.get(&"merge", 0)) != 1:
			pop_ok = false
		var want: StringName = &"merge_body_light" if t <= 3 else (&"merge_body_full" if t <= 6 else &"merge_body_large")
		if int(pc.get(want, 0)) != 1:
			body_ok = false
		var want_sparkle: int = 1 if (t >= 3 and t < 8) else 0
		if int(pc.get(&"merge_sparkle", 0)) != want_sparkle:
			sparkle_ok = false
		var want_chime: int = 1 if (t >= 5 and t < 8) else 0
		if int(pc.get(&"merge_chime", 0)) != want_chime:
			chime_ok = false
	_c("her tier'da POP tam bir kez", pop_ok)
	_c("her tier'da yalnız kendi bandının gövdesi", body_ok)
	_c("parıltı T3–T7'de var, T1–T2 ve T8'de yok", sparkle_ok)
	_c("çan T5–T7'de var, T1–T4 ve T8'de yok", chime_ok)
	var t8: Dictionary = per_tier[8]
	_c("T8: bloom + müzik kutusu + kuyruk (üçü de tam bir kez)", int(t8.get(&"tier_max", 0)) == 1
		and int(t8.get(&"tier_max_box", 0)) == 1 and int(t8.get(&"tier_max_tail", 0)) == 1)
	_c("T8: toplam 5 katman (pop + large gövde + 3 bloom katmanı)",
		_sum(t8) == 5 and int(t8.get(&"merge_body_large", 0)) == 1)
	_c("T7: 4 katman (pop + large + parıltı + çan), bloom YOK", _sum(per_tier[7]) == 4
		and int(per_tier[7].get(&"tier_max", 0)) == 0)
	_c("T1: 2 katman (pop + light gövde)", _sum(per_tier[1]) == 2)
	# Tier 8 ofsetleri: bloom +20, kutu +70, kuyruk +120 (çağrı anından).
	_c("T8 ofsetleri 20 / 70 / 120 ms", int(AudioManager.EVENTS[&"tier_max"]["delay_ms"]) == 20
		and int(AudioManager.EVENTS[&"tier_max_box"]["delay_ms"]) == 70
		and int(AudioManager.EVENTS[&"tier_max_tail"]["delay_ms"]) == 120)
	_c("parıltı +30 ms, çan +45 ms", int(AudioManager.EVENTS[&"merge_sparkle"]["delay_ms"]) == 30
		and int(AudioManager.EVENTS[&"merge_chime"]["delay_ms"]) == 45)
	# Tier 8 katmanları CRITICAL: hiçbir şey kesemez.
	_c("T8 katmanları CRITICAL", int(AudioManager.EVENTS[&"tier_max"]["priority"]) == AudioManager.Priority.CRITICAL
		and int(AudioManager.EVENTS[&"tier_max_box"]["priority"]) == AudioManager.Priority.CRITICAL
		and int(AudioManager.EVENTS[&"tier_max_tail"]["priority"]) == AudioManager.Priority.CRITICAL)
	# Büyütücü ile T8: aynı play_merge yolu → aynı katmanlar.
	_reset_counts()
	await _settle()
	AudioManager.play(&"upgrade")
	await get_tree().create_timer(0.15).timeout
	AudioManager.play(&"upgrade_transform")
	AudioManager.play_merge(8)
	await get_tree().create_timer(0.2).timeout
	_c("Büyütücü T7→T8: charge + air + pop + large + bloom/kutu/kuyruk", _count(&"upgrade") == 1
		and _count(&"upgrade_transform") == 1 and _count(&"tier_max") == 1
		and _count(&"tier_max_box") == 1 and _count(&"tier_max_tail") == 1)
	# Sonsuz yok oluşu: large gövde (pes) + tier 8 bloom ağacı (önceki T8'in
	# 300 ms soğuması geçsin).
	_reset_counts()
	await get_tree().create_timer(0.35).timeout
	AudioManager.play(&"annihilation")
	await get_tree().create_timer(0.2).timeout
	_c("annihilation: gövde + bloom + kutu + kuyruk (iç içe katman)", _count(&"annihilation") == 1
		and _count(&"tier_max") == 1 and _count(&"tier_max_box") == 1 and _count(&"tier_max_tail") == 1)
	# Ödül merdiveni.
	_reset_counts()
	await _settle()
	AudioManager.play_reward(SkinData.Rarity.LEGENDARY)
	await get_tree().create_timer(0.35).timeout
	_c("Legendary: bloom + kutu + yükselen kutu + kuyruk", _count(&"reward_legendary") == 1
		and _count(&"reward_legendary_box") == 1 and _count(&"reward_legendary_box_up") == 1
		and _count(&"reward_legendary_tail") == 1)
	_reset_counts()
	await _settle()
	AudioManager.play_reward(SkinData.Rarity.EPIC)
	await get_tree().create_timer(0.15).timeout
	_c("Epic: kutu + kuyruk; Common/Rare tek dosya", _count(&"reward_epic") == 1 and _count(&"reward_epic_tail") == 1
		and AudioManager.EVENTS[&"reward_common"].get("layers", []).is_empty()
		and AudioManager.EVENTS[&"reward_rare"].get("layers", []).is_empty())
	_reset_counts()
	await _settle()


func _sum(counts: Dictionary) -> int:
	var n: int = 0
	for v in counts.values():
		n += int(v)
	return n


# --- Gecikmeli katmanlar: zamanlayıcı, temizlik, process döngüsü yok ---

func _test_delayed_layers() -> void:
	_reset_counts()
	await _settle()
	_c("bekleyen gecikmeli katman 0'dan başlar", AudioManager.pending_delayed() == 0)
	AudioManager.play_merge(8)
	_c("T8 çağrısı anında: pop + gövde çaldı, 3 katman bekliyor", _count(&"merge") == 1
		and _count(&"merge_body_large") == 1 and _count(&"tier_max") == 0
		and AudioManager.pending_delayed() == 3)
	await get_tree().create_timer(0.05).timeout
	_c("+50 ms: bloom çaldı, kutu ve kuyruk bekliyor", _count(&"tier_max") == 1
		and _count(&"tier_max_box") == 0 and AudioManager.pending_delayed() == 2)
	await get_tree().create_timer(0.15).timeout
	_c("+200 ms: hepsi çaldı, bekleyen 0", _count(&"tier_max_box") == 1 and _count(&"tier_max_tail") == 1
		and AudioManager.pending_delayed() == 0)
	# stop_all bekleyenleri iptal eder: zamanlayıcı dolar ama çalmaz.
	_reset_counts()
	await _settle()
	AudioManager.play_merge(8)
	AudioManager.play(&"reward_legendary")
	var pending: int = AudioManager.pending_delayed()
	AudioManager.stop_all()
	await get_tree().create_timer(0.3).timeout
	_c("stop_all: %d bekleyen katman iptal (çalmadı), sayaç 0" % pending, pending == 6
		and _count(&"tier_max") == 0 and _count(&"tier_max_box") == 0 and _count(&"tier_max_tail") == 0
		and _count(&"reward_legendary_box") == 0 and AudioManager.pending_delayed() == 0)
	_c("AudioManager'da _process yok (gecikme SceneTreeTimer ile)",
		not AudioManager.has_method("_process") or not AudioManager.is_processing())
	# Gecikmeli katman kendi soğumasına uyar: 100 ms içinde iki T8 → ikinci
	# bloom ağacı atılır (cooldown 300).
	_reset_counts()
	await _settle()
	AudioManager.play(&"tier_max")
	AudioManager.play(&"tier_max")
	await get_tree().create_timer(0.2).timeout
	_c("gecikmeli katmanlar soğumaya uyar (2 çağrı → 1 bloom / 1 kutu / 1 kuyruk)",
		_count(&"tier_max") == 1 and _count(&"tier_max_box") == 1 and _count(&"tier_max_tail") == 1)
	_reset_counts()
	await _settle()


# --- Soğuma ve kanal tavanı ---

func _test_cooldown_and_voices() -> void:
	_reset_counts()
	await _settle()
	# 10 parça aynı karede iniyor: en fazla max_voices (2) ses.
	for i in 10:
		AudioManager.play_landing(2, 700.0)
	_c("10 eşzamanlı iniş -> en fazla 2 kanal", AudioManager.voices_playing(&"land") <= 2
		and AudioManager.voices_playing(&"land") >= 1)
	_c("fazla inişler atıldı (sayaç)", int(AudioManager.drop_count.get(&"land", 0)) >= 8)
	# Soğuma: 55 ms içinde ikinci iniş çalmaz, sonra çalar.
	AudioManager.stop_all()
	await get_tree().create_timer(0.1).timeout
	var first: bool = AudioManager.play(&"land")
	var second: bool = AudioManager.play(&"land")
	_c("soğuma içinde ikinci iniş reddedildi", first and not second)
	await get_tree().create_timer(0.09).timeout
	_c("soğuma geçince tekrar çalıyor", AudioManager.play(&"land"))
	# Merge steal_self: 4 tavanı; 5. çağrı en eskisini keser, toplam 4 kalır.
	AudioManager.stop_all()
	await _settle()
	var started: int = 0
	for i in 5:
		if AudioManager.play(&"merge"):
			started += 1
		await get_tree().create_timer(0.05).timeout
	_c("merge 5 çağrı -> en fazla 4 kanal (steal_self)", AudioManager.voices_playing(&"merge") <= 4)
	_c("merge çağrıları soğuma dışında kabul edildi", started == 5)
	# Temizleyici: 12 pop 20 ms arayla → soğuma 40 ms yarısını atar, tavan 3.
	_reset_counts()
	await _settle()
	for i in 12:
		AudioManager.play(&"clear_puff", 1.0 + 0.04 * float(1 + i % 2))
		await get_tree().create_timer(0.02).timeout
	_c("temizleyici pop'ları tavan 3 / soğuma 40 ms ile budandı", AudioManager.voices_playing(&"clear_puff") <= 3
		and _count(&"clear_puff") >= 3 and _count(&"clear_puff") <= 8)
	_c("temizleyici soğuması gameplay kademesinin (45 ms) altında", int(AudioManager.EVENTS[&"clear_puff"]["cooldown_ms"]) < 45)
	# Tehlike tik'i 0.5 s aralıkla tekrarlanır, soğuma 400 → her tik çalar; 0.1 s'de çift tik çalmaz.
	_reset_counts()
	await _settle()
	AudioManager.play(&"danger")
	AudioManager.play(&"danger")
	_c("tehlike: aynı anda ikinci tik reddedildi", _count(&"danger") == 1)
	AudioManager.stop_all()
	await _settle()


# --- Öncelik: CRITICAL kesilmez ---

func _test_priority() -> void:
	AudioManager.stop_all()
	await _settle()
	# Bütün kanalları LOW seslerle doldur.
	var filled: int = 0
	for i in AudioManager.VOICE_COUNT:
		if AudioManager.play(&"clear_puff" if i % 2 == 0 else &"drop"):
			filled += 1
		await get_tree().create_timer(0.065).timeout
	# Şimdi CRITICAL bir ses (Legendary bloom'u 1.1 s): kanal bulmalı.
	var crit: bool = AudioManager.play(&"reward_legendary")
	_c("CRITICAL ses kanal buldu", crit and AudioManager.voices_playing(&"reward_legendary") == 1)
	# CRITICAL çalarken kanalları doldur ve HIGH / NORMAL iste: CRITICAL kesilmemeli.
	for i in AudioManager.VOICE_COUNT:
		AudioManager.play(&"clear_puff" if i % 2 == 0 else &"drop")
		AudioManager.play(&"merge")
		await get_tree().create_timer(0.03).timeout
	AudioManager.play(&"bomb_impact")
	AudioManager.play(&"round_win")
	_c("CRITICAL ses HIGH / CRITICAL tarafından kesilmedi", AudioManager.voices_playing(&"reward_legendary") == 1)
	# Kesme politikası matrisi (statik).
	var P := AudioManager.Priority
	_c("kesme matrisi: CRITICAL kesilmez; HIGH yalnız CRITICAL'a; NORMAL/LOW eşit ve üstüne",
		not AudioManager._can_steal(P.CRITICAL, P.CRITICAL) and AudioManager._can_steal(P.HIGH, P.CRITICAL)
		and not AudioManager._can_steal(P.HIGH, P.HIGH) and AudioManager._can_steal(P.NORMAL, P.NORMAL)
		and AudioManager._can_steal(P.NORMAL, P.HIGH) and AudioManager._can_steal(P.LOW, P.NORMAL)
		and not AudioManager._can_steal(P.NORMAL, P.LOW) and AudioManager._can_steal(P.LOW, P.LOW))
	# Öncelik hiyerarşisi tabloda: UI LOW/NORMAL, merge NORMAL, güç vuruşu HIGH, T8 / kazanma / Legendary CRITICAL.
	_c("öncelik hiyerarşisi", int(AudioManager.EVENTS[&"ui_tap"]["priority"]) == AudioManager.Priority.LOW
		and int(AudioManager.EVENTS[&"merge"]["priority"]) == AudioManager.Priority.NORMAL
		and int(AudioManager.EVENTS[&"bomb_impact"]["priority"]) == AudioManager.Priority.HIGH
		and int(AudioManager.EVENTS[&"reward_legendary"]["priority"]) == AudioManager.Priority.CRITICAL
		and int(AudioManager.EVENTS[&"round_win"]["priority"]) == AudioManager.Priority.CRITICAL)
	# UI her zaman merge/güçlerden sessiz (mix hiyerarşisi).
	var ui_max: float = -100.0
	for id in [&"ui_tap", &"ui_modal_open", &"ui_modal_close", &"ui_select", &"ui_toggle_on", &"ui_equip", &"ui_invalid", &"power_arm"]:
		ui_max = maxf(ui_max, float(AudioManager.EVENTS[id]["gain_db"]))
	_c("UI ailesi merge POP / güç vuruşlarından sessiz", ui_max < float(AudioManager.EVENTS[&"merge"]["gain_db"])
		and ui_max < float(AudioManager.EVENTS[&"bomb_impact"]["gain_db"])
		and ui_max < float(AudioManager.EVENTS[&"shake"]["gain_db"])
		and ui_max < float(AudioManager.EVENTS[&"upgrade"]["gain_db"]) + 3.0)
	AudioManager.stop_all()
	await _settle()


# --- Ayarlar: SFX / titreşim kalıcılığı ---

func _test_settings() -> void:
	var sfx_index: int = AudioServer.get_bus_index(AudioManager.SFX_BUS)
	SaveManager.set_sfx_enabled(false)
	_c("SFX kapalı -> bus mute", AudioServer.is_bus_mute(sfx_index))
	_c("SFX kapalı -> is_sfx_enabled false", not AudioManager.is_sfx_enabled())
	SaveManager.load_game()
	_c("SFX ayarı kalıcı (false)", SaveManager.sfx_enabled() == false)
	# Kapalıyken play() ve gecikmeli katmanlar hâlâ çalışır (bus mute), çökmez.
	_reset_counts()
	await _settle()
	AudioManager.play_merge(8)
	await get_tree().create_timer(0.2).timeout
	_c("SFX kapalıyken T8 katmanları çökmeden akar (mute bus)", _count(&"tier_max_tail") == 1
		and AudioServer.is_bus_mute(sfx_index))
	SaveManager.set_sfx_enabled(true)
	_c("SFX açık -> bus unmute", not AudioServer.is_bus_mute(sfx_index))
	SaveManager.load_game()
	_c("SFX ayarı kalıcı (true)", SaveManager.sfx_enabled() == true)
	AudioManager.stop_all()

	SaveManager.set_haptics_enabled(false)
	_c("Haptics kapalı -> is_enabled false", not Haptics.is_enabled())
	SaveManager.load_game()
	_c("Haptics ayarı kalıcı (false)", SaveManager.haptics_enabled() == false)
	SaveManager.set_haptics_enabled(true)
	SaveManager.load_game()
	_c("Haptics ayarı kalıcı (true)", SaveManager.haptics_enabled() == true)
	_c("Haptics varsayılanı açık", bool(SaveManager.DEFAULT_DATA.get("haptics_enabled", false)))


# --- Titreşim politikası (sözlük, spam penceresi, SPECIAL) ---

func _test_haptics() -> void:
	var calls: Array = []
	var sink: Callable = func(ms: int, amp: float) -> void: calls.append([ms, amp])
	# Editor/masaüstü: desteklenmiyor, çağrı platforma gitmez, çökmez.
	Haptics.set_sink(Callable(), false)
	Haptics.reset_counters()
	Haptics.set_enabled(true)
	_c("editor'da desteklenmiyor", not Haptics.is_supported() or OS.has_feature("android"))
	_c("desteksiz ortamda light() false ve çökmez", Haptics.light() == false or Haptics.is_supported())
	_c("desteksiz ortamda special() çökmez", Haptics.special() == false or Haptics.is_supported())
	_c("desteksiz ortamda merge_tier(8) çökmez", Haptics.merge_tier(8) == false or Haptics.is_supported())
	_c("desteksiz ortamda platform çağrısı yok", Haptics.dispatch_count == 0 or Haptics.is_supported())

	# Destek zorlanmış + sink: politika mantığı.
	Haptics.set_sink(sink, true)
	Haptics.reset_counters()
	Haptics.set_enabled(false)
	Haptics.light(); Haptics.medium(); Haptics.strong(); Haptics.special(); Haptics.merge_tier(8)
	_c("Haptics kapalı -> hiçbir talep platforma gitmedi", calls.is_empty() and Haptics.dispatch_count == 0)
	Haptics.set_enabled(true)
	Haptics.reset_counters()
	_c("light() gönderildi", Haptics.light() and calls.size() == 1
		and calls[0][0] == Haptics.DURATION_MS[Haptics.Strength.LIGHT])
	# Spam penceresi: 70 ms içinde eşit/daha hafif darbe bastırılır.
	_c("70 ms içinde ikinci light bastırıldı", Haptics.light() == false and calls.size() == 1)
	# Daha güçlü darbe pencereyi deler.
	_c("daha güçlü darbe pencereyi deler", Haptics.strong() and calls.size() == 2
		and calls[1][0] == Haptics.DURATION_MS[Haptics.Strength.STRONG])
	await get_tree().create_timer(0.1).timeout
	# Zincir: 20 hızlı merge -> 1 darbe (tümü aynı güçte).
	Haptics.reset_counters()
	calls.clear()
	for i in 20:
		Haptics.light()
	_c("20 hızlı light -> 1 darbe", calls.size() == 1 and Haptics.suppressed_count == 19)
	await get_tree().create_timer(0.1).timeout
	calls.clear()
	Haptics.reset_counters()
	_c("special() ilk darbeyi hemen gönderdi", Haptics.special() and calls.size() == 1
		and calls[0][0] == Haptics.SPECIAL_PATTERN[0])
	await get_tree().create_timer(0.2).timeout
	_c("special() ikinci darbe geldi", calls.size() == 2 and calls[1][0] == Haptics.SPECIAL_PATTERN[2])
	var longest: int = 0
	for s in Haptics.DURATION_MS.values():
		longest = maxi(longest, int(s))
	_c("hiçbir darbe 60 ms'den uzun değil", longest <= 60 and Haptics.SPECIAL_PATTERN[0] <= 60
		and Haptics.SPECIAL_PATTERN[2] <= 60)
	_c("MIN_GAP_MS 70 korundu", Haptics.MIN_GAP_MS == 70)
	Haptics.set_sink(Callable(), false)
	Haptics.reset_counters()


# --- Merge titreşim eşlemesi (owner kararı): T1–3 yok, T4–5 LIGHT, T6–7 MEDIUM, T8 SPECIAL ---

func _test_merge_haptic_mapping() -> void:
	var calls: Array = []
	var sink: Callable = func(ms: int, _amp: float) -> void: calls.append(ms)
	Haptics.set_sink(sink, true)
	Haptics.set_enabled(true)
	var expected: Dictionary = {1: [], 2: [], 3: [],
		4: [Haptics.DURATION_MS[Haptics.Strength.LIGHT]], 5: [Haptics.DURATION_MS[Haptics.Strength.LIGHT]],
		6: [Haptics.DURATION_MS[Haptics.Strength.MEDIUM]], 7: [Haptics.DURATION_MS[Haptics.Strength.MEDIUM]],
		8: [Haptics.SPECIAL_PATTERN[0], Haptics.SPECIAL_PATTERN[2]]}
	for t in range(1, 9):
		Haptics.reset_counters()
		calls.clear()
		var sent: bool = Haptics.merge_tier(t)
		await get_tree().create_timer(0.15).timeout
		var want: Array = expected[t]
		var label: String = "yok" if want.is_empty() else ("SPECIAL" if want.size() == 2 else ("LIGHT" if want[0] == 18 else "MEDIUM"))
		_c("merge T%d titreşim: %s" % [t, label], calls == want and sent == (not want.is_empty()))
	# T1–T3 talep bile sayılmaz (spam penceresi dolmasın): request_count 0.
	Haptics.reset_counters()
	calls.clear()
	Haptics.merge_tier(1); Haptics.merge_tier(2); Haptics.merge_tier(3)
	_c("T1–T3 politika sayaçlarına girmez (pencereyi doldurmaz)", Haptics.request_count == 0 and calls.is_empty())
	# T3 hemen ardından T4: pencere boş olduğu için LIGHT geçer.
	_c("T3'ten hemen sonra T4 LIGHT geçer", Haptics.merge_tier(4) and calls == [18])
	await get_tree().create_timer(0.1).timeout
	_c("eşik sabitleri 4 / 6", Haptics.MERGE_LIGHT_MIN_TIER == 4 and Haptics.MERGE_MEDIUM_MIN_TIER == 6)
	Haptics.set_sink(Callable(), false)
	Haptics.reset_counters()


# --- Çağrı noktaları: gameplay/sonuç kaynağı beklenen olay + titreşimi kullanıyor ---

func _test_call_sites() -> void:
	var board: String = FileAccess.get_file_as_string(GAME_BOARD_SOURCE)
	var result: String = FileAccess.get_file_as_string(ROUND_RESULT_SOURCE)
	_c("kaynak dosyalar okundu", board.length() > 1000 and result.length() > 1000)
	_c("normal merge: play_merge + Haptics.merge_tier", _in_func(board, "_resolve_merge", "AudioManager.play_merge(new_tier)")
		and _in_func(board, "_resolve_merge", "Haptics.merge_tier(new_tier)")
		and not _in_func(board, "_resolve_merge", "Haptics.light()"))
	_c("Büyütücü: dokunuşta upgrade, dönüşümde upgrade_transform + play_merge, MEDIUM / T8 SPECIAL",
		_in_func(board, "_run_upgrade", 'AudioManager.play(&"upgrade")')
		and _in_func(board, "_finish_upgrade", 'AudioManager.play(&"upgrade_transform")')
		and _in_func(board, "_finish_upgrade", "AudioManager.play_merge(new_tier)")
		and _in_func(board, "_finish_upgrade", "Haptics.special()")
		and _in_func(board, "_finish_upgrade", "Haptics.medium()"))
	_c("Bomba: fırlatmada bomb_whoosh (titreşim yok), vuruşta bomb_impact + STRONG",
		_in_func(board, "_run_bomb", 'AudioManager.play(&"bomb_whoosh")')
		and not _in_func(board, "_run_bomb", "Haptics.")
		and _in_func(board, "_detonate_bomb", 'AudioManager.play(&"bomb_impact")')
		and _in_func(board, "_detonate_bomb", "Haptics.strong()"))
	_c("Sarsıntı: shake + tek MEDIUM", _in_func(board, "_use_shake", 'AudioManager.play(&"shake")')
		and _in_func(board, "_use_shake", "Haptics.medium()"))
	_c("Temizleyici: aktivasyonda clear_sweep + tek LIGHT, parça başına clear_puff (titreşimsiz)",
		_in_func(board, "_use_clear_small", 'AudioManager.play(&"clear_sweep")')
		and _in_func(board, "_use_clear_small", "Haptics.light()")
		and _in_func(board, "_pop_and_free", 'AudioManager.play(&"clear_puff"')
		and not _in_func(board, "_pop_and_free", "Haptics."))
	_c("bırakma / iniş / tehlike titreşimsiz", not _in_func(board, "_drop", "Haptics.")
		and not _in_func(board, "_on_impact_landed", "Haptics.")
		and board.find('AudioManager.play(&"danger")') >= 0)
	_c("sonsuz yok oluşu annihilation + STRONG", _in_func(board, "_resolve_annihilation", 'AudioManager.play(&"annihilation")')
		and _in_func(board, "_resolve_annihilation", "Haptics.strong()"))
	_c("taşma fail + MEDIUM, devam revive + MEDIUM, sonuç round_win/round_lose",
		board.find('AudioManager.play(&"fail")') >= 0 and board.find('AudioManager.play(&"revive")') >= 0
		and board.find('&"round_win" if won else &"round_lose"') >= 0)
	_c("ödül reveal: play_reward + Legendary SPECIAL / Epic MEDIUM", _in_func(result, "_play_reveal_feedback", "AudioManager.play_reward(rarity)")
		and _in_func(result, "_play_reveal_feedback", "Haptics.special()")
		and _in_func(result, "_play_reveal_feedback", "Haptics.medium()"))
	_c("eski MERGE_HIGH_MIN_TIER referansı yok", board.find("MERGE_HIGH_MIN_TIER") < 0)


## `needle`, `func_name` fonksiyonunun gövdesinde (bir sonraki `func ` başlığına kadar) geçiyor mu?
func _in_func(source: String, func_name: String, needle: String) -> bool:
	var start: int = source.find("func %s(" % func_name)
	if start < 0:
		return false
	var end: int = source.find("\nfunc ", start + 1)
	var body: String = source.substr(start, (end - start) if end > 0 else -1)
	return body.find(needle) >= 0


# --- Ses/titreşim gameplay durumuna dokunmaz ---

func _test_gameplay_state_untouched() -> void:
	var score_before: int = GameState.score
	var merges_before: int = GameState.merge_count
	var dough_before: int = SaveManager.dough()
	var powerups_before: Dictionary = (SaveManager.data.get("powerups", {}) as Dictionary).duplicate(true)
	Haptics.set_sink(func(_ms: int, _amp: float) -> void: pass, true)
	for i in 8:
		AudioManager.play_merge(1 + i)
		AudioManager.play_reward(i % 4)
		AudioManager.play_combo(i + 2)
		AudioManager.play(&"bomb_impact")
		AudioManager.play(&"clear_sweep")
		AudioManager.play(&"upgrade_transform")
		Haptics.merge_tier(1 + i)
		Haptics.special()
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	Haptics.set_sink(Callable(), false)
	_c("skor değişmedi", GameState.score == score_before)
	_c("merge sayacı değişmedi", GameState.merge_count == merges_before)
	_c("Hamur değişmedi", SaveManager.dough() == dough_before)
	_c("güç envanteri değişmedi", SaveManager.data.get("powerups", {}) == powerups_before)
	AudioManager.stop_all()
	await _settle()


# --- Yardımcılar ---

## Dummy sürücüde stop() sonrası `playing` bir kare geç düşebilir.
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _backup_save() -> void:
	_save_existed = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _save_existed:
		_save_backup = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)


func _restore_save() -> void:
	if _save_existed:
		var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(_save_backup)
		f.close()
	elif FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	SaveManager.load_game()
