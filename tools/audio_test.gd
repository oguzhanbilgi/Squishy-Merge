extends Node
## SFX servisi + titreşim davranış testi (M8.5-15). Dev aracı.
##
## Kullanım:
##   godot --headless --audio-driver Dummy --path . res://tools/audio_test.tscn
##
## Dummy sürücü gerçek zamanlı mix yapar: `playing` bayrağı ve soğuma
## sayaçları gerçek zamanla ilerler, o yüzden testler birkaç kare/ms bekler.
##
## KAYIT: ayar anahtarları save_game() çağırır. Kayıt dosyası test başında
## byte-byte yedeklenir ve sonunda geri yazılır (owner kaydı bozulmaz).

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
	await _test_rng_isolation()
	await _test_cooldown_and_voices()
	await _test_priority()
	await _test_settings()
	await _test_haptics()
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
	var expected: Array[StringName] = [&"ui_tap", &"ui_tab", &"ui_modal_open",
		&"ui_modal_close", &"ui_purchase", &"ui_invalid", &"ui_equip", &"drop",
		&"land", &"merge", &"merge_high", &"tier_max", &"combo", &"danger", &"fail",
		&"round_win", &"round_lose", &"revive", &"bomb_whoosh", &"bomb_impact",
		&"upgrade", &"shake", &"clear_puff", &"chest_open", &"reward_common",
		&"reward_rare", &"reward_epic", &"reward_legendary", &"daily_reward",
		&"level_unlock", &"star_reveal"]
	var missing_map: PackedStringArray = []
	var missing_stream: PackedStringArray = []
	for id in expected:
		if not AudioManager.EVENTS.has(id):
			missing_map.append(String(id))
		elif not AudioManager.has_stream(id):
			missing_stream.append(String(id))
	_c("beklenen olaylar tabloda (%s)" % ", ".join(missing_map), missing_map.is_empty())
	_c("beklenen olayların akışı yüklü (%s)" % ", ".join(missing_stream), missing_stream.is_empty())
	# Bilinmeyen olay ve eksik akış çökertmez.
	_c("bilinmeyen olay false döner", AudioManager.play(&"boyle_bir_ses_yok") == false)
	AudioManager._streams.erase(&"ui_tab")
	_c("akışı silinen olay false döner, çökmez", AudioManager.play(&"ui_tab") == false)
	AudioManager._load_streams()
	_c("akış yeniden yüklendi", AudioManager.has_stream(&"ui_tab"))
	# Her tablo satırı geçerli öncelik ve tavan taşıyor.
	var bad: int = 0
	for id: StringName in AudioManager.EVENTS:
		var e: Dictionary = AudioManager.EVENTS[id]
		if int(e.get("max_voices", 1)) < 1 or int(e.get("priority", 0)) < 0 \
				or int(e.get("priority", 0)) > AudioManager.Priority.CRITICAL:
			bad += 1
		for layer in e.get("layers", []):
			if not AudioManager.EVENTS.has(layer):
				bad += 1
	_c("tablo tutarlı (tavan/öncelik/katman)", bad == 0)


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
		await get_tree().process_frame
	var actual: Array[int] = [randi(), randi(), randi()]
	_c("ses varyasyonu global RNG'yi tüketmedi", expected == actual)
	# Yerel RNG deterministik: aynı tohum aynı sıra.
	var a := RandomNumberGenerator.new()
	a.seed = AudioManager.AUDIO_RNG_SEED
	var b := RandomNumberGenerator.new()
	b.seed = AudioManager.AUDIO_RNG_SEED
	_c("yerel RNG tohumu deterministik", a.randf() == b.randf())
	AudioManager.stop_all()
	await _settle()


# --- Soğuma ve kanal tavanı ---

func _test_cooldown_and_voices() -> void:
	AudioManager.stop_all()
	await _settle()
	AudioManager.play_count.clear()
	AudioManager.drop_count.clear()
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
		# Soğumayı aşmak için zamanı ilerlet.
		if AudioManager.play(&"merge"):
			started += 1
		await get_tree().create_timer(0.035).timeout
	_c("merge 5 çağrı -> en fazla 4 kanal (steal_self)", AudioManager.voices_playing(&"merge") <= 4)
	_c("merge çağrıları soğuma dışında kabul edildi", started == 5)
	AudioManager.stop_all()
	await _settle()


# --- Öncelik: CRITICAL kesilmez ---

func _test_priority() -> void:
	AudioManager.stop_all()
	await _settle()
	# Bütün kanalları LOW seslerle doldur (her biri farklı olay olsun diye
	# soğumayı aşarak aynı olayı tekrar tekrar kullanmak yerine drop/puff).
	var filled: int = 0
	for i in AudioManager.VOICE_COUNT:
		if AudioManager.play(&"clear_puff" if i % 2 == 0 else &"drop"):
			filled += 1
		await get_tree().create_timer(0.065).timeout
	# Şimdi CRITICAL bir ses: boş kanal yoksa LOW bir kanalı kesmeli.
	var crit: bool = AudioManager.play(&"tier_max")
	_c("CRITICAL ses kanal buldu (LOW kesildi)", crit and AudioManager.voices_playing(&"tier_max") == 1)
	# CRITICAL çalarken tüm kanalları doldur ve yeni HIGH iste: CRITICAL kesilmemeli.
	for i in AudioManager.VOICE_COUNT:
		AudioManager.play(&"clear_puff" if i % 2 == 0 else &"drop")
		await get_tree().create_timer(0.05).timeout
	AudioManager.play(&"bomb_impact")
	_c("CRITICAL ses HIGH tarafından kesilmedi", AudioManager.voices_playing(&"tier_max") == 1)
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
	SaveManager.set_sfx_enabled(true)
	_c("SFX açık -> bus unmute", not AudioServer.is_bus_mute(sfx_index))
	SaveManager.load_game()
	_c("SFX ayarı kalıcı (true)", SaveManager.sfx_enabled() == true)
	# Kapalıyken play() hâlâ çalışır (bus mute), çökmez.
	SaveManager.set_sfx_enabled(false)
	_c("SFX kapalıyken play() çökmez", AudioManager.play(&"ui_purchase") or true)
	SaveManager.set_sfx_enabled(true)
	AudioManager.stop_all()

	SaveManager.set_haptics_enabled(false)
	_c("Haptics kapalı -> is_enabled false", not Haptics.is_enabled())
	SaveManager.load_game()
	_c("Haptics ayarı kalıcı (false)", SaveManager.haptics_enabled() == false)
	SaveManager.set_haptics_enabled(true)
	SaveManager.load_game()
	_c("Haptics ayarı kalıcı (true)", SaveManager.haptics_enabled() == true)
	_c("Haptics varsayılanı açık", bool(SaveManager.DEFAULT_DATA.get("haptics_enabled", false)))


# --- Titreşim politikası ---

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
	_c("desteksiz ortamda platform çağrısı yok", Haptics.dispatch_count == 0 or Haptics.is_supported())

	# Destek zorlanmış + sink: politika mantığı.
	Haptics.set_sink(sink, true)
	Haptics.reset_counters()
	Haptics.set_enabled(false)
	Haptics.light(); Haptics.medium(); Haptics.strong(); Haptics.special()
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
	Haptics.set_sink(Callable(), false)
	Haptics.reset_counters()


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
		Haptics.medium()
		Haptics.special()
		await get_tree().process_frame
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
