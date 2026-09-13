extends SceneTree
## GEÇİCİ (interim) sentez SFX üretici — M8.5-15. Dev aracı, oyunda KULLANILMAZ.
##
## NEDEN VAR: Repoda yalnızca 7 Kenney CC0 placeholder vardı ve bırakma /
## iniş / UI dokunuşu / parıltı / yumuşak hata gibi olaylar için hiçbir
## uygun kaynak yoktu. Sessizlik ya da "her şeye aynı thud" yerine burada
## saf sinüs / kısa gürültü tabanlı, kırpmasız, kısa ve YUMUŞAK sesler
## deterministik olarak üretiliyor. Çıktılar `assets/audio/sfx/**` altına
## yazılıyor ve `AudioManager.EVENTS` tablosunun beklediği DOSYA ADLARINI
## taşıyor: owner final tasarım örneğini aynı adla üzerine yazınca kod
## değişmeden devreye girer (docs/AUDIO_ASSET_REQUIREMENTS.md).
##
## BUNLAR FİNAL DEĞİL. Kulakla doğrulanmadılar (üretim ortamında ses çıkışı
## yok); ölçülebilir özellikleri (tepe ≤ -3 dBFS, kırpma 0, süre) ve
## karakter tarifi docs/AUDIO_AUDIT.md'de. Sınıflandırma: INTERIM/REPLACE.
##
## Determinizm: bütün gürültü tabanlı sesler sabit tohumlu yerel RNG
## kullanır; aynı betik aynı dosyayı byte-byte üretir.
##
## Kullanım:
##   godot --headless --path . --script res://tools/make_sfx.gd
##   ardından import: godot --headless --editor --quit --path .

const RATE: int = 44100
const OUT: String = "res://assets/audio/sfx"

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 8515
	_make_all()
	quit(0)


# --- DSP yardımcıları (PackedFloat32Array, mono, -1..1) ---

func _buffer(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	out.fill(0.0)
	return out


## Sinüs: frekans f0'dan f1'e `glide` sn'de üstel kayar, genlik `attack`
## sn'de açılır ve `decay` zaman sabitiyle üstel söner. `partials`:
## [[oran, genlik], ...] ek harmonikler (hafif detune için oran tam sayı
## olmayabilir).
func _tone(buf: PackedFloat32Array, start: float, length: float, f0: float,
		f1: float, glide: float, attack: float, decay: float, gain: float,
		partials: Array = []) -> void:
	var s0: int = int(start * RATE)
	var n: int = int(length * RATE)
	var phase: float = 0.0
	var phases: Array[float] = []
	for p in partials:
		phases.append(0.0)
	for i in n:
		var t: float = float(i) / RATE
		var k: float = clampf(t / maxf(glide, 1e-4), 0.0, 1.0)
		var f: float = f0 * pow(f1 / f0, k)
		var env: float = (minf(t / maxf(attack, 1e-4), 1.0)) * exp(-t / decay)
		phase += TAU * f / RATE
		var v: float = sin(phase)
		for j in partials.size():
			phases[j] += TAU * f * float(partials[j][0]) / RATE
			v += sin(phases[j]) * float(partials[j][1])
		var idx: int = s0 + i
		if idx < buf.size():
			buf[idx] += v * env * gain


## Beyaz gürültü, tek kutuplu alçak geçiren süzgeçten (cutoff c0'dan c1'e
## kayar), `attack`/`decay` zarflı; `hold` sn boyunca sönmez.
func _noise(buf: PackedFloat32Array, start: float, length: float, c0: float,
		c1: float, attack: float, decay: float, gain: float, hold: float = 0.0) -> void:
	var s0: int = int(start * RATE)
	var n: int = int(length * RATE)
	var y: float = 0.0
	for i in n:
		var t: float = float(i) / RATE
		var k: float = float(i) / float(maxi(n - 1, 1))
		var cutoff: float = c0 * pow(c1 / c0, k)
		var a: float = 1.0 - exp(-TAU * cutoff / RATE)
		y += a * (_rng.randf_range(-1.0, 1.0) - y)
		var env: float = minf(t / maxf(attack, 1e-4), 1.0)
		if t > hold:
			env *= exp(-(t - hold) / decay)
		var idx: int = s0 + i
		if idx < buf.size():
			buf[idx] += y * env * gain


## Tepe normalizasyonu + 2 ms baş/son fade (tık önleme).
func _finish(buf: PackedFloat32Array, peak_db: float) -> PackedFloat32Array:
	var peak: float = 0.0
	for v in buf:
		peak = maxf(peak, absf(v))
	var g: float = db_to_linear(peak_db) / maxf(peak, 1e-6)
	var fade: int = int(0.002 * RATE)
	for i in buf.size():
		var w: float = 1.0
		if i < fade:
			w = float(i) / fade
		elif i >= buf.size() - fade:
			w = float(buf.size() - 1 - i) / fade
		buf[i] = clampf(buf[i] * g * w, -1.0, 1.0)
	return buf


func _write(name: String, buf: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(round(buf[i] * 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	var path: String = "%s/%s" % [OUT, name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err: Error = wav.save_to_wav(path)
	print("%s %s (%.2f sn)" % ["OK  " if err == OK else "HATA", path, float(buf.size()) / RATE])


# --- Sesler ---

func _make_all() -> void:
	# UI dokunuşu: çok kısa, yumuşak sinüs tık. Ana ailenin tek üyesi.
	var b := _buffer(0.07)
	_tone(b, 0.0, 0.07, 1500.0, 1000.0, 0.03, 0.002, 0.016, 1.0, [[2.01, 0.15]])
	_write("ui/sfx_ui_tap_01.wav", _finish(b, -6.0))

	# Sekme geçişi: daha hafif ve tiz "tik".
	b = _buffer(0.05)
	_tone(b, 0.0, 0.05, 1900.0, 1400.0, 0.02, 0.002, 0.011, 1.0)
	_write("ui/sfx_ui_tab_01.wav", _finish(b, -8.0))

	# Pencere açılışı: kısa yumuşak "pop" + tiz kıvılcım.
	b = _buffer(0.16)
	_tone(b, 0.0, 0.14, 420.0, 640.0, 0.06, 0.004, 0.05, 1.0, [[2.0, 0.2]])
	_tone(b, 0.03, 0.1, 1800.0, 2200.0, 0.05, 0.003, 0.03, 0.25)
	_write("ui/sfx_ui_modal_open_01.wav", _finish(b, -7.0))

	# Pencere kapanışı: aynı pop, aşağı yönlü ve daha kısa.
	b = _buffer(0.12)
	_tone(b, 0.0, 0.12, 620.0, 380.0, 0.06, 0.004, 0.04, 1.0, [[2.0, 0.15]])
	_write("ui/sfx_ui_modal_close_01.wav", _finish(b, -9.0))

	# Yumuşak hata / yetersiz Hamur: tek pes "bonk", sert değil.
	b = _buffer(0.18)
	_tone(b, 0.0, 0.18, 270.0, 205.0, 0.07, 0.004, 0.06, 1.0, [[2.0, 0.3], [3.0, 0.08]])
	_write("ui/sfx_ui_invalid_01.wav", _finish(b, -8.0))

	# Satın alma / günlük ödül: iki notalı "ding-ding" (G6 -> C7).
	b = _buffer(0.55)
	_chime(b, 0.0, 1568.0, 0.22, 0.9)
	_chime(b, 0.09, 2093.0, 0.28, 1.0)
	_write("rewards/sfx_reward_chime_01.wav", _finish(b, -5.0))

	# Parıltı (tier-up / equip / unlock / Rare-Epic ödül): C6 E6 G6 C7 arpej.
	b = _buffer(0.6)
	var arp: Array[float] = [1046.5, 1318.5, 1568.0, 2093.0]
	for i in arp.size():
		_chime(b, 0.055 * i, arp[i], 0.17, 0.8 + 0.06 * i)
	_write("rewards/sfx_sparkle_up_01.wav", _finish(b, -4.5))

	# Büyük parıltı (Tier 8 / Legendary): altı nota + akor kuyruğu.
	b = _buffer(1.1)
	var big: Array[float] = [1046.5, 1318.5, 1568.0, 2093.0, 2637.0, 3136.0]
	for i in big.size():
		_chime(b, 0.06 * i, big[i], 0.30, 0.75 + 0.05 * i)
	_chime(b, 0.42, 1046.5, 0.45, 0.6)
	_chime(b, 0.42, 1568.0, 0.45, 0.5)
	_chime(b, 0.42, 2093.0, 0.45, 0.55)
	_write("rewards/sfx_sparkle_big_01.wav", _finish(b, -4.0))

	# Yumuşak kayıp: inen üç nota (E5 C5 A4), sinüs + hafif 3. harmonik.
	b = _buffer(0.85)
	_tone(b, 0.0, 0.3, 659.3, 659.3, 0.01, 0.01, 0.12, 0.8, [[3.0, 0.08]])
	_tone(b, 0.19, 0.3, 523.3, 523.3, 0.01, 0.01, 0.13, 0.8, [[3.0, 0.08]])
	_tone(b, 0.40, 0.45, 440.0, 425.0, 0.4, 0.01, 0.2, 0.9, [[3.0, 0.08]])
	_write("gameplay/sfx_fail_soft_01.wav", _finish(b, -6.0))

	# Bırakma "plop": 3 varyant, kısa inen sinüs.
	var drop_f: Array[float] = [500.0, 460.0, 540.0]
	for i in drop_f.size():
		b = _buffer(0.11)
		_tone(b, 0.0, 0.11, drop_f[i], drop_f[i] * 0.5, 0.05, 0.003, 0.04, 1.0, [[2.0, 0.12]])
		_write("gameplay/sfx_drop_%02d.wav" % (i + 1), _finish(b, -8.0))

	# Merge "squishy pop": hızlı inen pitch (balon patlaması) + pes gövde.
	var pop_f: Array[float] = [1100.0, 1000.0, 1200.0]
	for i in pop_f.size():
		b = _buffer(0.2)
		_tone(b, 0.0, 0.18, pop_f[i], 340.0, 0.03, 0.002, 0.055, 1.0, [[2.0, 0.18]])
		_tone(b, 0.004, 0.18, 190.0, 150.0, 0.08, 0.006, 0.07, 0.55)
		_write("gameplay/sfx_merge_pop_%02d.wav" % (i + 1), _finish(b, -3.5))

	# Temizleyici "puf": kısa süzülmüş gürültü.
	b = _buffer(0.1)
	_noise(b, 0.0, 0.1, 1400.0, 500.0, 0.004, 0.028, 1.0)
	_write("powers/sfx_puff_01.wav", _finish(b, -9.0))

	# Bomba mermisi "whoosh": cutoff'u yükselip inen yumuşak gürültü.
	b = _buffer(0.32)
	_noise(b, 0.0, 0.32, 350.0, 2400.0, 0.12, 0.06, 1.0, 0.16)
	_write("powers/sfx_whoosh_01.wav", _finish(b, -9.0))

	# Bomba patlaması (sevimli, kompakt): pop + kısa pes gövde + puf.
	b = _buffer(0.3)
	_tone(b, 0.0, 0.25, 700.0, 160.0, 0.05, 0.002, 0.08, 1.0, [[2.0, 0.2]])
	_noise(b, 0.0, 0.2, 2500.0, 500.0, 0.003, 0.05, 0.55)
	_write("powers/sfx_bomb_impact_01.wav", _finish(b, -3.0))

	# Sarsıntı: 12 Hz'de dalgalanan pes ton + hafif gürültü; telefon
	# hoparlöründe okunması için 140 Hz (70 Hz duyulmaz).
	b = _buffer(0.36)
	var n: int = b.size()
	for i in n:
		var t: float = float(i) / RATE
		var wob: float = 0.55 + 0.45 * sin(TAU * 12.0 * t)
		var env: float = minf(t / 0.03, 1.0) * exp(-t / 0.14)
		b[i] += sin(TAU * 140.0 * t) * wob * env * 0.9
		b[i] += sin(TAU * 210.0 * t) * wob * env * 0.25
	_noise(b, 0.0, 0.3, 600.0, 300.0, 0.02, 0.09, 0.3)
	_write("powers/sfx_shake_01.wav", _finish(b, -6.0))

	# Büyütücü: yükselen sinüs + parıltı (sihirli yükseliş).
	b = _buffer(0.55)
	_tone(b, 0.0, 0.45, 380.0, 1520.0, 0.32, 0.01, 0.22, 0.8, [[2.0, 0.2]])
	_chime(b, 0.28, 2093.0, 0.2, 0.6)
	_chime(b, 0.34, 2637.0, 0.2, 0.55)
	_write("powers/sfx_upgrade_01.wav", _finish(b, -5.0))

	# Devam (revive): yükselen parıltı — sparkle_up'tan ayrı karakter,
	# daha yumuşak ve daha uzun.
	b = _buffer(0.7)
	_tone(b, 0.0, 0.4, 520.0, 1040.0, 0.3, 0.02, 0.2, 0.7, [[2.0, 0.15]])
	_chime(b, 0.2, 1568.0, 0.25, 0.6)
	_chime(b, 0.3, 2093.0, 0.3, 0.7)
	_write("gameplay/sfx_revive_01.wav", _finish(b, -5.0))

	# Tehlike: yumuşak, kısa, pes iki nota "uyarı" (siren değil).
	b = _buffer(0.3)
	_tone(b, 0.0, 0.14, 330.0, 330.0, 0.01, 0.01, 0.05, 0.8, [[2.0, 0.2]])
	_tone(b, 0.13, 0.17, 262.0, 262.0, 0.01, 0.01, 0.06, 0.8, [[2.0, 0.2]])
	_write("gameplay/sfx_danger_soft_01.wav", _finish(b, -8.0))


## Çan benzeri kısa nota: temel + hafif detune'lu 2. + zayıf 3. harmonik.
func _chime(buf: PackedFloat32Array, start: float, freq: float, decay: float,
		gain: float) -> void:
	_tone(buf, start, decay * 3.5, freq, freq, 0.01, 0.003, decay, gain,
		[[2.003, 0.28], [3.0, 0.09]])
