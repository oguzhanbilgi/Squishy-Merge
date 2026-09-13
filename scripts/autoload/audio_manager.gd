extends Node
## SFX servisi — bütün ses efektlerinin TEK çalma noktası (M8.5-15).
##
## Bus yapısı: Master -> SFX (HardLimiter) / Music (boş, v1 non-goal).
## Ayarlar -> "Ses Efektleri" SFX bus'ını susturuyor (bkz. set_sfx_enabled).
##
## Tasarım:
##   - Olay tablosu (`EVENTS`): çağrı noktaları OLAY kimliği bilir, dosya
##     yolu bilmez. Dosya değişimi yalnızca burada.
##   - Sabit sayıda ses kanalı (VOICE_COUNT) + öncelik tabanlı kanal çalma
##     (voice stealing): ödül/kutlama gibi CRITICAL sesler asla kesilmez.
##   - Olay başına soğuma (cooldown_ms) ve eşzamanlılık tavanı (max_voices):
##     10 parça aynı anda yığına inince 10 iniş sesi ÇIKMAZ.
##   - Kozmetik varyasyon (pitch/gain jitter, varyant havuzu) YEREL bir
##     RandomNumberGenerator'dan gelir. Global randf/randi ASLA kullanılmaz:
##     ses, drop_bag / gameplay determinizmini etkilememeli.
##   - Eksik dosya çökertmez: olay `fallback` olayına düşer; o da yoksa
##     sessizdir ve play() false döner. Eksikler açılışta TEK uyarıyla
##     listelenir (docs/AUDIO_ASSET_REQUIREMENTS.md'deki seam'ler).
##
## Asset durumu: `kenney_*` dosyaları Kenney CC0, `sfx_*` dosyaları
## tools/make_sfx.gd ile üretilmiş GEÇİCİ sentezler. Hiçbiri kulakla
## doğrulanmış final değildir — bkz. docs/AUDIO_AUDIT.md.

const SFX_BUS: StringName = &"SFX"
const MUSIC_BUS: StringName = &"Music"
## Aynı anda çalabilen ses sayısı. Mobil için ılımlı; en yoğun anda
## (zincir merge + iniş + UI) 8-9 kanal yetiyor, 12 pay bırakıyor.
const VOICE_COUNT: int = 12
## Sabit tohum: varyasyon deterministik ve gameplay RNG'sinden bağımsız.
const AUDIO_RNG_SEED: int = 0x5F1D

## Kanal çalma önceliği. Eşit öncelikte yalnızca NORMAL ve altı kesilebilir;
## HIGH yalnızca CRITICAL tarafından, CRITICAL hiçbir şey tarafından kesilmez.
enum Priority { LOW, NORMAL, HIGH, CRITICAL }

const SFX_ROOT: String = "res://assets/audio/sfx"

## --- OLAY TABLOSU ---
##
## Alanlar (hepsi opsiyonel, varsayılanlar `_DEFAULTS`):
##   streams        varyant havuzu; çalınacak dosya yerel RNG ile seçilir
##   fallback       dosyalar eksikse kullanılacak olay kimliği
##   gain_db        mix hiyerarşisi (0 = en öne çıkan, -14 = fısıltı)
##   gain_jitter_db ± rastgele seviye sapması
##   pitch          temel pitch çarpanı
##   pitch_jitter   ± rastgele pitch sapması (0.03 = %3)
##   cooldown_ms    aynı olayın iki çalışı arasındaki en kısa süre
##   max_voices     aynı olaydan aynı anda en fazla kaç kanal
##   steal_self     tavana gelince en eskisini kes (true) ya da yenisini at (false)
##   priority       Priority
##   layers         bu olayla birlikte çalınacak ek olaylar (aynı pitch çarpanı)
const EVENTS: Dictionary = {
	# ---------- UI ----------
	&"ui_tap": {"streams": ["ui/sfx_ui_tap_01.wav"], "gain_db": -13.0,
		"cooldown_ms": 40, "max_voices": 1, "steal_self": true, "priority": Priority.LOW},
	&"ui_tab": {"streams": ["ui/sfx_ui_tab_01.wav"], "gain_db": -15.0,
		"cooldown_ms": 60, "max_voices": 1, "steal_self": true, "priority": Priority.LOW},
	&"ui_modal_open": {"streams": ["ui/sfx_ui_modal_open_01.wav"], "gain_db": -10.0,
		"cooldown_ms": 80, "max_voices": 1, "steal_self": true, "priority": Priority.NORMAL},
	&"ui_modal_close": {"streams": ["ui/sfx_ui_modal_close_01.wav"], "gain_db": -12.0,
		"cooldown_ms": 80, "max_voices": 1, "steal_self": true, "priority": Priority.LOW},
	&"ui_toggle_on": {"streams": ["ui/kenney_pluck_01.ogg"], "gain_db": -12.0,
		"pitch": 1.2, "cooldown_ms": 80, "max_voices": 1, "priority": Priority.LOW},
	&"ui_select": {"streams": ["ui/kenney_pluck_01.ogg"], "gain_db": -14.0,
		"pitch": 0.85, "cooldown_ms": 60, "max_voices": 1, "steal_self": true,
		"priority": Priority.LOW},
	&"ui_purchase": {"streams": ["rewards/sfx_reward_chime_01.wav"], "gain_db": -5.0,
		"cooldown_ms": 120, "max_voices": 1, "priority": Priority.HIGH},
	&"ui_invalid": {"streams": ["ui/sfx_ui_invalid_01.wav"], "gain_db": -9.0,
		"cooldown_ms": 150, "max_voices": 1, "priority": Priority.NORMAL},
	&"ui_equip": {"streams": ["rewards/sfx_sparkle_up_01.wav"], "gain_db": -7.0,
		"pitch": 1.1, "cooldown_ms": 120, "max_voices": 1, "priority": Priority.NORMAL},

	# ---------- ÇEKİRDEK OYUN ----------
	&"drop": {"streams": ["gameplay/sfx_drop_01.wav", "gameplay/sfx_drop_02.wav",
		"gameplay/sfx_drop_03.wav"], "gain_db": -14.0, "pitch_jitter": 0.03,
		"cooldown_ms": 60, "max_voices": 2, "priority": Priority.LOW},
	## İniş: seviye ve pitch play_landing() içinde hız/tier'a göre; burada
	## yalnızca tavan. max_voices 2 + 55 ms soğuma = yığın "makineli tüfek"
	## olmaz. steal_self false: fazlası ATILIR, kesilmez.
	&"land": {"streams": ["gameplay/kenney_impact_soft_01.ogg"], "gain_db": -9.0,
		"pitch_jitter": 0.04, "gain_jitter_db": 1.0, "cooldown_ms": 55,
		"max_voices": 2, "priority": Priority.LOW},
	## Merge: imza ses. Pitch tier'a göre (TierConfig.merge_pitch, GAME_DESIGN §6).
	&"merge": {"streams": ["gameplay/sfx_merge_pop_01.wav", "gameplay/sfx_merge_pop_02.wav",
		"gameplay/sfx_merge_pop_03.wav"], "gain_db": -1.0, "pitch_jitter": 0.02,
		"cooldown_ms": 30, "max_voices": 4, "steal_self": true, "priority": Priority.NORMAL},
	## Merge'in pes gövdesi: büyük tier'da ağırlık. play_merge() tier'a göre
	## seviye/pitch vererek çalıyor (o yüzden `layers` ile bağlanmadı).
	&"merge_body": {"streams": ["gameplay/kenney_impact_soft_01.ogg"], "gain_db": -12.0,
		"cooldown_ms": 30, "max_voices": 3, "steal_self": true, "priority": Priority.NORMAL},
	## Tier ≥ 6 merge'e eklenen parıltı katmanı.
	&"merge_high": {"streams": ["rewards/sfx_sparkle_up_01.wav"], "gain_db": -8.0,
		"cooldown_ms": 120, "max_voices": 2, "priority": Priority.HIGH},
	## Tier 7 -> 8: premium kısa kutlama. CRITICAL: kesilmez.
	&"tier_max": {"streams": ["rewards/sfx_sparkle_big_01.wav"], "gain_db": -2.0,
		"cooldown_ms": 300, "max_voices": 1, "priority": Priority.CRITICAL},
	## Sonsuz modda iki tier 8'in yok oluşu: en pes merge + büyük parıltı.
	&"annihilation": {"streams": ["gameplay/sfx_merge_pop_01.wav"], "gain_db": -1.0,
		"pitch": 0.7, "cooldown_ms": 100, "max_voices": 1, "priority": Priority.HIGH,
		"layers": [&"tier_max"]},
	&"combo": {"streams": ["rewards/sfx_sparkle_up_01.wav"], "gain_db": -9.0,
		"cooldown_ms": 90, "max_voices": 2, "steal_self": true, "priority": Priority.NORMAL},
	## Tehlike: DANGER_TICK_INTERVAL (0.5 sn) ile tekrar eder; yumuşak ve kısık.
	&"danger": {"streams": ["gameplay/sfx_danger_soft_01.wav"], "gain_db": -10.0,
		"cooldown_ms": 400, "max_voices": 1, "priority": Priority.NORMAL},
	## Taşma anı (devam teklifi açılırken): kısa inen ton, sert değil.
	&"fail": {"streams": ["gameplay/sfx_fail_soft_01.wav"], "gain_db": -6.0,
		"cooldown_ms": 500, "max_voices": 1, "priority": Priority.HIGH},
	&"round_lose": {"streams": ["gameplay/kenney_jingle_lose_01.ogg"], "gain_db": -6.0,
		"cooldown_ms": 500, "max_voices": 1, "priority": Priority.HIGH},
	&"round_win": {"streams": ["rewards/kenney_jingle_win_01.ogg"], "gain_db": -4.0,
		"cooldown_ms": 500, "max_voices": 1, "priority": Priority.CRITICAL},
	&"revive": {"streams": ["gameplay/sfx_revive_01.wav"], "gain_db": -5.0,
		"cooldown_ms": 500, "max_voices": 1, "priority": Priority.CRITICAL},

	# ---------- GÜÇLER ----------
	&"power_arm": {"streams": ["ui/kenney_pluck_01.ogg"], "gain_db": -12.0,
		"pitch": 1.05, "cooldown_ms": 80, "max_voices": 1, "steal_self": true,
		"priority": Priority.LOW},
	&"bomb_whoosh": {"streams": ["powers/sfx_whoosh_01.wav"], "gain_db": -10.0,
		"cooldown_ms": 100, "max_voices": 1, "priority": Priority.NORMAL},
	&"bomb_impact": {"streams": ["powers/sfx_bomb_impact_01.wav"], "gain_db": -2.0,
		"pitch_jitter": 0.03, "cooldown_ms": 100, "max_voices": 1, "priority": Priority.HIGH,
		"layers": [&"merge_body"]},
	&"upgrade": {"streams": ["powers/sfx_upgrade_01.wav"], "gain_db": -4.0,
		"cooldown_ms": 150, "max_voices": 1, "priority": Priority.HIGH},
	&"shake": {"streams": ["powers/sfx_shake_01.wav"], "gain_db": -7.0,
		"cooldown_ms": 200, "max_voices": 1, "priority": Priority.NORMAL},
	## Temizleyici: çok parça art arda; 45 ms soğuma + 3 kanal tavanı spam'i keser.
	&"clear_puff": {"streams": ["powers/sfx_puff_01.wav"], "gain_db": -9.0,
		"pitch_jitter": 0.08, "gain_jitter_db": 1.5, "cooldown_ms": 45,
		"max_voices": 3, "priority": Priority.LOW},

	# ---------- İLERLEME / ÖDÜL ----------
	&"star_reveal": {"streams": ["ui/kenney_pluck_01.ogg"], "gain_db": -8.0,
		"cooldown_ms": 100, "max_voices": 2, "priority": Priority.NORMAL},
	&"chest_open": {"streams": ["rewards/kenney_open_01.ogg"], "gain_db": -6.0,
		"pitch": 0.9, "cooldown_ms": 150, "max_voices": 1, "priority": Priority.NORMAL},
	&"reward_common": {"streams": ["gameplay/sfx_merge_pop_02.wav"], "gain_db": -6.0,
		"pitch": 1.1, "cooldown_ms": 150, "max_voices": 1, "priority": Priority.HIGH},
	&"reward_rare": {"streams": ["rewards/sfx_sparkle_up_01.wav"], "gain_db": -5.0,
		"cooldown_ms": 150, "max_voices": 1, "priority": Priority.HIGH},
	&"reward_epic": {"streams": ["rewards/sfx_sparkle_up_01.wav"], "gain_db": -3.0,
		"pitch": 1.12, "cooldown_ms": 150, "max_voices": 1, "priority": Priority.CRITICAL,
		"layers": [&"ui_purchase"]},
	&"reward_legendary": {"streams": ["rewards/sfx_sparkle_big_01.wav"], "gain_db": -1.0,
		"cooldown_ms": 300, "max_voices": 1, "priority": Priority.CRITICAL},
	&"daily_reward": {"streams": ["rewards/sfx_reward_chime_01.wav"], "gain_db": -5.0,
		"pitch": 0.95, "cooldown_ms": 300, "max_voices": 1, "priority": Priority.HIGH},
	&"level_unlock": {"streams": ["rewards/sfx_sparkle_up_01.wav"], "gain_db": -6.0,
		"pitch": 1.05, "cooldown_ms": 300, "max_voices": 1, "priority": Priority.HIGH},
}

const _DEFAULTS: Dictionary = {
	"streams": [], "fallback": &"", "gain_db": 0.0, "gain_jitter_db": 0.0,
	"pitch": 1.0, "pitch_jitter": 0.0, "cooldown_ms": 0, "max_voices": 4,
	"steal_self": false, "priority": Priority.NORMAL, "layers": [],
}

## --- İniş / merge parametreleri (yalnızca SUNUM; fizik dokunulmadı) ---
## İniş seviyesi: LAND_PUFF_SPEED'de -9 dB'nin altına LAND_GAIN_MIN kadar,
## LAND_SPEED_FULL'da tam seviye.
const LAND_GAIN_MIN_DB: float = -8.0
const LAND_SPEED_FULL: float = 950.0
## İniş pitch'i: küçük parça tiz/hafif, büyük parça pes/derin.
const LAND_PITCH_TIER1: float = 1.25
const LAND_PITCH_TIER8: float = 0.78
## Merge gövde katmanı: tier büyüdükçe pes ve güçlü.
const MERGE_BODY_GAIN_TIER1_DB: float = -14.0
const MERGE_BODY_GAIN_TIER8_DB: float = -4.0
const MERGE_BODY_PITCH_TIER1: float = 1.15
const MERGE_BODY_PITCH_TIER8: float = 0.7
## Bu tier ve üstündeki merge'e parıltı katmanı eklenir.
const MERGE_HIGH_MIN_TIER: int = 6
const COMBO_PITCH_STEP: float = 0.04
const COMBO_PITCH_MAX_COUNT: int = 8

var _streams: Dictionary = {}          # olay -> Array[AudioStream]
var _voices: Array[AudioStreamPlayer] = []
var _voice_event: Array[StringName] = []
var _voice_priority: Array[int] = []
var _voice_started_ms: Array[int] = []
var _last_played_ms: Dictionary = {}   # olay -> msec
var _missing_events: PackedStringArray = []
## YEREL RNG — global randf/randi kullanılmaz (determinizm, bkz. dosya başı).
var _rng := RandomNumberGenerator.new()
## Test/QA: son play() kararları (olay -> kaç kez gerçekten çalındı / atıldı).
var play_count: Dictionary = {}
var drop_count: Dictionary = {}


func _ready() -> void:
	_rng.seed = AUDIO_RNG_SEED
	_load_streams()
	var bus: StringName = SFX_BUS if AudioServer.get_bus_index(SFX_BUS) >= 0 else &"Master"
	if bus != SFX_BUS:
		push_warning("SFX bus'ı bulunamadı, Master'a düşülüyor.")
	for i in VOICE_COUNT:
		var player := AudioStreamPlayer.new()
		player.bus = bus
		add_child(player)
		_voices.append(player)
		_voice_event.append(&"")
		_voice_priority.append(Priority.LOW)
		_voice_started_ms.append(0)


# --- Yükleme ---

## Bir olayın tablodaki tam dosya yolları (fallback dahil DEĞİL).
static func stream_paths(event: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for rel: String in event.get("streams", []):
		out.append(rel if rel.begins_with("res://") else "%s/%s" % [SFX_ROOT, rel])
	return out


func _load_streams() -> void:
	for id: StringName in EVENTS:
		var loaded: Array[AudioStream] = []
		for path in stream_paths(EVENTS[id]):
			if not ResourceLoader.exists(path):
				continue
			var stream := load(path) as AudioStream
			if stream == null:
				continue
			# Tek atışlık efektler; loop açık kalırsa ses hiç bitmez.
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = false
			elif stream is AudioStreamWAV:
				(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
			loaded.append(stream)
		if not loaded.is_empty():
			_streams[id] = loaded
		else:
			_missing_events.append(String(id))
	# Fallback çözümü: eksik olay, fallback'in yüklü akışlarını paylaşır.
	for id: StringName in EVENTS:
		if _streams.has(id):
			continue
		var fallback: StringName = _field(id, "fallback")
		if fallback != &"" and _streams.has(fallback):
			_streams[id] = _streams[fallback]
	if not _missing_events.is_empty():
		push_warning("SFX dosyası eksik (sessiz ya da fallback): %s — bkz. docs/AUDIO_ASSET_REQUIREMENTS.md"
			% ", ".join(_missing_events))


func _field(id: StringName, key: String) -> Variant:
	var event: Dictionary = EVENTS.get(id, {})
	return event.get(key, _DEFAULTS[key])


## Yüklenmiş (ya da fallback'le çözülmüş) bir akışı var mı?
func has_stream(id: StringName) -> bool:
	return _streams.has(id)


func missing_events() -> PackedStringArray:
	return _missing_events


# --- Çalma ---

## Olayı çalar. `pitch_mul` ve `gain_offset_db` tablodaki değerlerin üstüne
## biner. Dönüş: gerçekten bir kanal başlatıldıysa true (soğuma, tavan,
## eksik dosya ya da kanal yokluğunda false — hata değil, politika).
func play(id: StringName, pitch_mul: float = 1.0, gain_offset_db: float = 0.0) -> bool:
	if not EVENTS.has(id):
		push_warning("Bilinmeyen SFX olayı: %s" % id)
		return false
	var started: bool = _play_single(id, pitch_mul, gain_offset_db)
	for layer: StringName in _field(id, "layers"):
		_play_single(layer, pitch_mul, 0.0)
	return started


func _play_single(id: StringName, pitch_mul: float, gain_offset_db: float) -> bool:
	var pool: Array = _streams.get(id, [])
	if pool.is_empty():
		return false
	var now: int = Time.get_ticks_msec()
	var cooldown: int = _field(id, "cooldown_ms")
	if cooldown > 0 and _last_played_ms.has(id) and now - int(_last_played_ms[id]) < cooldown:
		_count(drop_count, id)
		return false

	var priority: int = _field(id, "priority")
	var voice: int = _acquire_voice(id, priority, now)
	if voice < 0:
		_count(drop_count, id)
		return false

	var stream: AudioStream = pool[_rng.randi_range(0, pool.size() - 1)] if pool.size() > 1 else pool[0]
	var pitch: float = float(_field(id, "pitch")) * pitch_mul
	var pitch_jitter: float = _field(id, "pitch_jitter")
	if pitch_jitter > 0.0:
		pitch *= 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	var gain: float = float(_field(id, "gain_db")) + gain_offset_db
	var gain_jitter: float = _field(id, "gain_jitter_db")
	if gain_jitter > 0.0:
		gain += _rng.randf_range(-gain_jitter, gain_jitter)

	var player: AudioStreamPlayer = _voices[voice]
	player.stop()
	player.stream = stream
	player.pitch_scale = maxf(pitch, 0.05)
	player.volume_db = gain
	player.play()
	_voice_event[voice] = id
	_voice_priority[voice] = priority
	_voice_started_ms[voice] = now
	_last_played_ms[id] = now
	_count(play_count, id)
	return true


## Boş kanal, yoksa politika gereği kesilebilir bir kanal döner; -1 = yok.
func _acquire_voice(id: StringName, priority: int, now: int) -> int:
	var free_voice: int = -1
	var same_count: int = 0
	var oldest_same: int = -1
	var steal: int = -1
	for i in VOICE_COUNT:
		if not _voices[i].playing:
			if free_voice < 0:
				free_voice = i
			continue
		if _voice_event[i] == id:
			same_count += 1
			if oldest_same < 0 or _voice_started_ms[i] < _voice_started_ms[oldest_same]:
				oldest_same = i
		elif _can_steal(_voice_priority[i], priority):
			if steal < 0 or _voice_priority[i] < _voice_priority[steal] \
					or (_voice_priority[i] == _voice_priority[steal]
						and _voice_started_ms[i] < _voice_started_ms[steal]):
				steal = i
	# Olay başına tavan: fazlası ya en eskisini keser ya da atılır.
	var max_voices: int = _field(id, "max_voices")
	if same_count >= max_voices:
		return oldest_same if bool(_field(id, "steal_self")) else -1
	if free_voice >= 0:
		return free_voice
	if steal >= 0:
		return steal
	# Kanal yok, kesilecek düşük öncelikli de yok: aynı olayın en eskisi
	# (yalnızca steal_self ise), yoksa atılır.
	if oldest_same >= 0 and bool(_field(id, "steal_self")):
		return oldest_same
	return -1


## `victim` öncelikli çalan bir kanalı `incoming` kesebilir mi?
static func _can_steal(victim: int, incoming: int) -> bool:
	if victim == Priority.CRITICAL:
		return false
	if victim < incoming:
		return true
	return victim == incoming and victim <= Priority.NORMAL


static func _count(table: Dictionary, id: StringName) -> void:
	table[id] = int(table.get(id, 0)) + 1


## Şu anda bu olayı çalan kanal sayısı (test/QA).
func voices_playing(id: StringName) -> int:
	var n: int = 0
	for i in VOICE_COUNT:
		if _voices[i].playing and _voice_event[i] == id:
			n += 1
	return n


func stop_all() -> void:
	for player in _voices:
		player.stop()


# --- Oyun içi yardımcılar (parametreleri tek yerde tutmak için) ---

## Bırakma: hafif, sabit; her 0.4 sn'de olabildiğinden sessiz.
func play_drop() -> void:
	play(&"drop")


## İniş: seviye çarpma hızına, pitch tier'a bağlı. `speed` px/sn
## (Dumpling.impact_landed'den). Tavan/soğuma tabloda.
func play_landing(tier: int, speed: float) -> void:
	var t: float = clampf((speed - Dumpling.LAND_PUFF_SPEED)
		/ maxf(LAND_SPEED_FULL - Dumpling.LAND_PUFF_SPEED, 1.0), 0.0, 1.0)
	var pitch: float = lerpf(LAND_PITCH_TIER1, LAND_PITCH_TIER8,
		float(tier - 1) / float(TierConfig.MAX_TIER - 1))
	play(&"land", pitch, lerpf(LAND_GAIN_MIN_DB, 0.0, t))


## Merge: tier'a göre yükselen pop (GAME_DESIGN §6) + pesleşen gövde;
## tier ≥ 6 parıltı, tier 8 premium kutlama.
func play_merge(new_tier: int) -> void:
	var k: float = float(new_tier - 1) / float(TierConfig.MAX_TIER - 1)
	_play_single(&"merge", TierConfig.merge_pitch(new_tier), 0.0)
	_play_single(&"merge_body", lerpf(MERGE_BODY_PITCH_TIER1, MERGE_BODY_PITCH_TIER8, k),
		lerpf(MERGE_BODY_GAIN_TIER1_DB, MERGE_BODY_GAIN_TIER8_DB, k) - float(_field(&"merge_body", "gain_db")))
	if new_tier >= TierConfig.MAX_TIER:
		play(&"tier_max")
	elif new_tier >= MERGE_HIGH_MIN_TIER:
		play(&"merge_high", 0.9 + 0.05 * float(new_tier - MERGE_HIGH_MIN_TIER))


## Combo: merge'in üstüne, zincir uzadıkça hafifçe tizleşen parıltı.
func play_combo(count: int) -> void:
	play(&"combo", 1.0 + COMBO_PITCH_STEP * float(mini(count, COMBO_PITCH_MAX_COUNT)))


## Sandık ödülü reveal'i, rarity'e göre.
func play_reward(rarity: int) -> void:
	match rarity:
		SkinData.Rarity.LEGENDARY:
			play(&"reward_legendary")
		SkinData.Rarity.EPIC:
			play(&"reward_epic")
		SkinData.Rarity.RARE:
			play(&"reward_rare")
		_:
			play(&"reward_common")


# --- Bus / ayarlar ---

func set_bus_volume_db(bus: StringName, volume_db: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, volume_db)


## Ses efektlerini toptan kapatır/açar (Ayarlar → Ses Efektleri). Bus
## seviyesinde mute: çağrı noktaları değişmiyor, kapalıyken play()
## çalışıyor ama duyulmuyor. Kayıtla bağını SaveManager.set_sfx_enabled
## kuruyor; açılışta main.gd kayıttaki değeri buraya uyguluyor.
func set_sfx_enabled(enabled: bool) -> void:
	var index: int = AudioServer.get_bus_index(SFX_BUS)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, not enabled)


func is_sfx_enabled() -> bool:
	var index: int = AudioServer.get_bus_index(SFX_BUS)
	return index < 0 or not AudioServer.is_bus_mute(index)
