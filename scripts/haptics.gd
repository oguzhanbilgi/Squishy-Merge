class_name Haptics
extends RefCounted
## Titreşim (haptik) servisi — M8.5-15. Autoload DEĞİL: durum `static var`,
## API `Haptics.light()` gibi statik çağrılar. Node gerektirmiyor.
##
## Küçük anlamsal sözlük: LIGHT / MEDIUM / STRONG / SPECIAL. Çağrı noktaları
## "kaç ms" bilmez, "ne kadar önemli" bilir. Süreler burada, tek yerde.
##
## Platform: Godot'un yerleşik `Input.vibrate_handheld(ms, amplitude)` —
## Android (VIBRATE izni export preset'inde AÇIK olmalı, M9), iOS ve Web.
## Editor / masaüstünde çağrı yapılmaz (`is_supported()` false), hiçbir
## şey çökmez. Zengin desenler (ör. Android VibrationEffect composition)
## için native plugin gerekir; bu turda bilinçli olarak EKLENMEDİ.
## SPECIAL = iki kısa darbe (35 ms + 60 ms boşluk + 60 ms) ile taklit
## ediliyor; cihaz amplitude desteklemiyorsa tek seviyeli çalışır.
##
## Spam koruması: iki darbe arası en az MIN_GAP_MS; bu pencere içinde
## yalnızca DAHA GÜÇLÜ bir darbe öncekinin yerine geçer (hafif olan atılır).
## Zincir merge'de titreşim yağmuru olmaz; Tier 8 / Legendary kaybolmaz.
##
## Merge eşlemesi (owner kararı, M8.8-02 — docs/audio/HAPTIC_MAPPING.md):
## titreşim BÜYÜK birleşmeleri taşır. T1–T3 YOK (sürekli olur, rahatlatıcı
## kimlik), T4–T5 LIGHT, T6–T7 MEDIUM, T8 SPECIAL. `merge_tier()` tek yer.
##
## Gameplay durumuna ASLA dokunmaz; SaveManager.set_haptics_enabled tek
## yazma noktası (ayar), Haptics.set_enabled onun uygulayıcısı.

enum Strength { LIGHT, MEDIUM, STRONG }

## Normal merge sonucu tier'a göre darbe: bu tier'dan itibaren LIGHT / MEDIUM;
## altı sessiz; TierConfig.MAX_TIER SPECIAL.
const MERGE_LIGHT_MIN_TIER: int = 4
const MERGE_MEDIUM_MIN_TIER: int = 6

## Darbe süreleri (ms). Uzun titreşim YOK: en uzunu 60 ms.
const DURATION_MS: Dictionary = {
	Strength.LIGHT: 18,
	Strength.MEDIUM: 32,
	Strength.STRONG: 55,
}
## Amplitude 0..1 (destekleyen Android cihazlarda; diğerlerinde yok sayılır).
const AMPLITUDE: Dictionary = {
	Strength.LIGHT: 0.35,
	Strength.MEDIUM: 0.65,
	Strength.STRONG: 1.0,
}
## SPECIAL deseni: [süre, boşluk, süre] ms.
const SPECIAL_PATTERN: Array[int] = [35, 60, 60]
const MIN_GAP_MS: int = 70

static var _enabled: bool = true
## Test/QA kancası: platform çağrısının yerine geçer. Varsayılan = gerçek.
## Callable(duration_ms: int, amplitude: float) -> void
static var _sink: Callable = Callable()
## Test: desteklenmeyen ortamda (editor) politika mantığını sınamak için.
static var _force_supported: bool = false
static var _last_pulse_ms: int = -100000
static var _last_strength: int = -1
## Test/QA sayaçları: politika kabul etti / platforma gitti / atıldı.
static var request_count: int = 0
static var dispatch_count: int = 0
static var suppressed_count: int = 0


static func is_supported() -> bool:
	if _force_supported:
		return true
	if OS.has_feature("editor"):
		return false
	return OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web")


static func set_enabled(enabled: bool) -> void:
	_enabled = enabled


static func is_enabled() -> bool:
	return _enabled


# --- Sözlük ---

static func light() -> bool:
	return _pulse(Strength.LIGHT)


static func medium() -> bool:
	return _pulse(Strength.MEDIUM)


static func strong() -> bool:
	return _pulse(Strength.STRONG)


## Normal merge (ve Büyütücü dışı tier ulaşımı): sonuç tier'ına göre
## T1–T3 hiç, T4–T5 LIGHT, T6–T7 MEDIUM, T8 SPECIAL. Dönüş: darbe gönderildi mi.
static func merge_tier(tier: int) -> bool:
	if tier >= TierConfig.MAX_TIER:
		return special()
	if tier >= MERGE_MEDIUM_MIN_TIER:
		return medium()
	if tier >= MERGE_LIGHT_MIN_TIER:
		return light()
	return false


## Tier 7 -> 8 ve Legendary reveal: iki darbeli kısa premium desen.
static func special() -> bool:
	if not _admit(Strength.STRONG):
		return false
	_dispatch(SPECIAL_PATTERN[0], AMPLITUDE[Strength.STRONG])
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return true
	var second: Callable = func() -> void:
		_dispatch(SPECIAL_PATTERN[2], AMPLITUDE[Strength.STRONG])
	loop.create_timer(float(SPECIAL_PATTERN[0] + SPECIAL_PATTERN[1]) / 1000.0) \
		.timeout.connect(second)
	return true


# --- İç ---

static func _pulse(strength: int) -> bool:
	if not _admit(strength):
		return false
	_dispatch(DURATION_MS[strength], AMPLITUDE[strength])
	return true


## Ayar kapalı / platform yok / spam penceresi -> false.
static func _admit(strength: int) -> bool:
	if not _enabled or not is_supported():
		return false
	request_count += 1
	var now: int = Time.get_ticks_msec()
	if now - _last_pulse_ms < MIN_GAP_MS and strength <= _last_strength:
		suppressed_count += 1
		return false
	_last_pulse_ms = now
	_last_strength = strength
	return true


static func _dispatch(duration_ms: int, amplitude: float) -> void:
	dispatch_count += 1
	if _sink.is_valid():
		_sink.call(duration_ms, amplitude)
		return
	Input.vibrate_handheld(duration_ms, amplitude)


## Test/QA: platform çağrısını yakala (boş Callable = gerçek platform).
static func set_sink(sink: Callable, force_supported: bool = false) -> void:
	_sink = sink
	_force_supported = force_supported


static func reset_counters() -> void:
	request_count = 0
	dispatch_count = 0
	suppressed_count = 0
	_last_pulse_ms = -100000
	_last_strength = -1
