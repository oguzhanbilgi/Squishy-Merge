extends Node
## SFX servisi — bütün ses efektlerinin TEK çalma noktası (M8.5-15, M8.8-02).
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
##   - Katmanlar (`layers`) ve gecikmeli katmanlar (`delay_ms`, M8.8-02):
##     bir olay birden fazla dosyayı, her biri çağrı anından itibaren kendi
##     ofsetiyle çalabilir (merge parıltısı +30 ms, tier 8 bloom +20 /
##     müzik kutusu +70 / kuyruk +120 ms). Gecikme SceneTreeTimer ile;
##     kalıcı _process döngüsü YOK. stop_all() bekleyenleri iptal eder.
##   - Kozmetik varyasyon (pitch/gain jitter, varyant havuzu) YEREL bir
##     RandomNumberGenerator'dan gelir. Global randf/randi ASLA kullanılmaz:
##     ses, drop_bag / gameplay determinizmini etkilememeli.
##   - Eksik dosya çökertmez: olay `fallback` olayına düşer; o da yoksa
##     sessizdir ve play() false döner. Eksikler açılışta TEK uyarıyla
##     listelenir.
##
## Asset durumu (M8.8-02): bütün dosyalar owner'ın dinleyip onayladığı
## production set — Kenney CC0 + Sonniss GDC 2026 kaynaklarından
## `tools/audio_production_build.py` ile bir kez üretildi. Kaynak/lisans:
## `assets/audio/CREDITS.md`; olay haritası: `docs/audio/AUDIO_SYSTEM.md`;
## merge ailesi: `docs/audio/MERGE_SOUND_FAMILY.md`.

const SFX_BUS: StringName = &"SFX"
const MUSIC_BUS: StringName = &"Music"
## Aynı anda çalabilen ses sayısı. Mobil için ılımlı; en yoğun anda
## (tier 8 merge 5 katman + iniş + combo + UI) 8-9 kanal yetiyor, 12 pay bırakıyor.
const VOICE_COUNT: int = 12
## Sabit tohum: varyasyon deterministik ve gameplay RNG'sinden bağımsız.
const AUDIO_RNG_SEED: int = 0x5F1D
## Katman ağacı en fazla bu kadar derin açılır (döngü koruması).
const MAX_LAYER_DEPTH: int = 3

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
##   layers         bu olayla birlikte çalınacak ek olaylar (aynı pitch çarpanı;
##                  her katmanın kendi delay_ms'i çağrı anından ölçülür)
##   delay_ms       olayın kendi başlama ofseti (çağrı anından; 0 = hemen)
##
## Mix hiyerarşisi: merge pop / tier 8 / güç vuruşu en önde (-1…-4), iniş /
## satın alma / sandık / ödül ortada (-5…-9), tehlike -10, bırakma / UI sessiz
## (-11…-18). UI her zaman merge/güçlerden sessiz.
const EVENTS: Dictionary = {
	# ---------- UI (tek aile: Kenney Interface — TAP / CONFIRM / BACK / ERROR) ----------
	&"ui_tap": {"streams": ["ui/sfx_ui_tap_01.wav"], "gain_db": -11.0,
		"cooldown_ms": 40, "max_voices": 1, "steal_self": true, "priority": Priority.LOW},
	## Bağlı değil (alt sekme çubuğu M8.6-06'da kalktı); kayıt duruyor.
	&"ui_tab": {"streams": ["ui/sfx_ui_tap_01.wav"], "gain_db": -13.0, "pitch": 1.15,
		"cooldown_ms": 60, "max_voices": 1, "steal_self": true, "priority": Priority.LOW},
	## Pencere açılışı: CONFIRM ailesinin sessiz, hafif pes hâli (satın alma
	## -5 dB / 1.0× ile karışmasın). Kapanış = BACK.
	&"ui_modal_open": {"streams": ["ui/sfx_ui_confirm_01.wav"], "gain_db": -12.0, "pitch": 0.95,
		"cooldown_ms": 80, "max_voices": 1, "steal_self": true, "priority": Priority.NORMAL},
	&"ui_modal_close": {"streams": ["ui/sfx_ui_back_01.wav"], "gain_db": -11.0,
		"cooldown_ms": 80, "max_voices": 1, "steal_self": true, "priority": Priority.LOW},
	&"ui_toggle_on": {"streams": ["ui/sfx_ui_confirm_01.wav"], "gain_db": -12.0,
		"pitch": 1.2, "cooldown_ms": 80, "max_voices": 1, "priority": Priority.LOW},
	&"ui_select": {"streams": ["ui/sfx_ui_tap_01.wav"], "gain_db": -13.0,
		"pitch": 0.9, "cooldown_ms": 60, "max_voices": 1, "steal_self": true,
		"priority": Priority.LOW},
	&"ui_purchase": {"streams": ["ui/sfx_ui_confirm_01.wav"], "gain_db": -5.0,
		"cooldown_ms": 120, "max_voices": 1, "priority": Priority.HIGH},
	&"ui_invalid": {"streams": ["ui/sfx_ui_error_01.wav"], "gain_db": -9.0,
		"cooldown_ms": 150, "max_voices": 1, "priority": Priority.NORMAL},
	&"ui_equip": {"streams": ["ui/sfx_ui_confirm_01.wav"], "gain_db": -7.0,
		"pitch": 1.1, "cooldown_ms": 120, "max_voices": 1, "priority": Priority.NORMAL},

	# ---------- ÇEKİRDEK OYUN ----------
	## Bırakma: iniş malzemesinin tiz, çok sessiz "bıraktım" tik'i (DROP C).
	&"drop": {"streams": ["gameplay/sfx_land_01.wav"], "gain_db": -18.0, "pitch": 1.35,
		"pitch_jitter": 0.03, "cooldown_ms": 60, "max_voices": 2, "priority": Priority.LOW},
	## İniş (DROP C): seviye ve pitch play_landing() içinde hız/tier'a göre;
	## burada yalnızca tavan. max_voices 2 + 55 ms soğuma = yığın "makineli
	## tüfek" olmaz. steal_self false: fazlası ATILIR, kesilmez.
	&"land": {"streams": ["gameplay/sfx_land_01.wav"], "gain_db": -9.0,
		"pitch_jitter": 0.04, "gain_jitter_db": 1.0, "cooldown_ms": 55,
		"max_voices": 2, "priority": Priority.LOW},
	## Merge POP çekirdeği (owner A ailesi). Pitch tier'a göre
	## (TierConfig.merge_pitch, GAME_DESIGN §6); seviye MERGE_RECIPE'den.
	&"merge": {"streams": ["gameplay/sfx_merge_pop_01.wav", "gameplay/sfx_merge_pop_02.wav"],
		"gain_db": -1.0, "pitch_jitter": 0.02, "gain_jitter_db": 1.0,
		"cooldown_ms": 30, "max_voices": 4, "steal_self": true, "priority": Priority.NORMAL},
	## Merge gövdesi, tier bandına göre üç havuz (play_merge seçer; pitch ve
	## seviye MERGE_RECIPE'den, gain_db burada taban):
	##   light T1–T3 (Kenney generic_light) · full T4–T6 (plate) · large T7–T8 (punch).
	&"merge_body_light": {"streams": ["gameplay/sfx_merge_body_light_01.wav",
		"gameplay/sfx_merge_body_light_02.wav"], "gain_db": -12.0, "gain_jitter_db": 1.0,
		"cooldown_ms": 30, "max_voices": 3, "steal_self": true, "priority": Priority.NORMAL},
	&"merge_body_full": {"streams": ["gameplay/sfx_merge_body_full_01.wav",
		"gameplay/sfx_merge_body_full_02.wav"], "gain_db": -8.0, "gain_jitter_db": 1.0,
		"cooldown_ms": 30, "max_voices": 3, "steal_self": true, "priority": Priority.NORMAL,
		"fallback": &"merge_body_light"},
	&"merge_body_large": {"streams": ["gameplay/sfx_merge_body_large_01.wav"], "gain_db": -6.0,
		"gain_jitter_db": 1.0, "cooldown_ms": 30, "max_voices": 2, "steal_self": true,
		"priority": Priority.NORMAL, "fallback": &"merge_body_full"},
	## Küçük cam parıltısı, tier ≥ MERGE_SPARKLE_MIN_TIER; gövdeden +30 ms
	## sonra ("shine" olarak okunsun). 3 kardeş dosya + jitter = tik hissi yok.
	&"merge_sparkle": {"streams": ["gameplay/sfx_merge_sparkle_01.wav",
		"gameplay/sfx_merge_sparkle_02.wav", "gameplay/sfx_merge_sparkle_03.wav"],
		"gain_db": -14.0, "pitch_jitter": 0.03, "gain_jitter_db": 1.0, "delay_ms": 30,
		"cooldown_ms": 30, "max_voices": 3, "steal_self": true, "priority": Priority.NORMAL},
	## Yumuşak çan, tier ≥ MERGE_CHIME_MIN_TIER; +45 ms.
	&"merge_chime": {"streams": ["gameplay/sfx_merge_chime_01.wav"], "gain_db": -11.0,
		"gain_jitter_db": 0.5, "delay_ms": 45, "cooldown_ms": 60, "max_voices": 2,
		"steal_self": true, "priority": Priority.NORMAL},
	## Tier 8: sıcak çan bloom'u (+20 ms) + müzik kutusu notası (+70 ms) +
	## kısa parıltı kuyruğu (+120 ms). Daha GENİŞ ve UZUN, daha gürültülü
	## değil. CRITICAL: hiçbir katmanı kesilmez. max_voices 2 (M8.8-02.1 cihaz
	## kapısı): bloom 1.1 s sürer; ikinci bir T8 (zincir, Büyütücü, sonsuz yok
	## oluşu) 0.3–1.1 s içinde gelirse katmanları düşmesin — 300 ms soğuma aynı
	## karedeki çiftleri yine engeller.
	&"tier_max": {"streams": ["rewards/sfx_tier8_bloom_01.wav"], "gain_db": -7.0,
		"delay_ms": 20, "cooldown_ms": 300, "max_voices": 2, "priority": Priority.CRITICAL,
		"layers": [&"tier_max_box", &"tier_max_tail"]},
	&"tier_max_box": {"streams": ["rewards/sfx_tier8_box_01.wav"], "gain_db": -10.0,
		"delay_ms": 70, "cooldown_ms": 300, "max_voices": 2, "priority": Priority.CRITICAL},
	&"tier_max_tail": {"streams": ["rewards/sfx_tier8_tail_01.wav"], "gain_db": -14.0,
		"delay_ms": 120, "cooldown_ms": 300, "max_voices": 2, "priority": Priority.CRITICAL},
	## Sonsuz modda iki tier 8'in yok oluşu: en pes büyük gövde + tier 8 bloom'u.
	&"annihilation": {"streams": ["gameplay/sfx_merge_body_large_01.wav"], "gain_db": -3.0,
		"pitch": 0.75, "cooldown_ms": 100, "max_voices": 1, "priority": Priority.HIGH,
		"layers": [&"tier_max"]},
	## Combo: merge'in üstüne aynı cam parıltısı, zincir uzadıkça tizleşir
	## (play_combo). Müzikal cümle YOK (tekrar yorgunluğu).
	&"combo": {"streams": ["gameplay/sfx_merge_sparkle_01.wav",
		"gameplay/sfx_merge_sparkle_02.wav", "gameplay/sfx_merge_sparkle_03.wav"],
		"gain_db": -11.0, "cooldown_ms": 90, "max_voices": 2, "steal_self": true,
		"priority": Priority.NORMAL},
	## Tehlike: DANGER_TICK_INTERVAL (0.5 sn) ile tekrar eder; yumuşak
	## ahşap "tok" (bambu kap), iki varyant, alarm/siren değil.
	&"danger": {"streams": ["gameplay/sfx_danger_01.wav", "gameplay/sfx_danger_02.wav"],
		"gain_db": -10.0, "pitch_jitter": 0.02, "cooldown_ms": 400, "max_voices": 1,
		"priority": Priority.NORMAL},
	## Taşma anı (devam teklifi açılırken): FAIL B'nin hafif pes hâli.
	&"fail": {"streams": ["gameplay/sfx_round_lose_01.wav"], "gain_db": -7.0, "pitch": 0.94,
		"cooldown_ms": 500, "max_voices": 1, "priority": Priority.HIGH},
	&"round_lose": {"streams": ["gameplay/sfx_round_lose_01.wav"], "gain_db": -6.0,
		"cooldown_ms": 500, "max_voices": 1, "priority": Priority.HIGH},
	&"round_win": {"streams": ["rewards/sfx_round_win_01.wav"], "gain_db": -4.0,
		"cooldown_ms": 500, "max_voices": 1, "priority": Priority.CRITICAL},
	## Devam: WIN B'nin daha pes, daha sessiz hâli ("toparlandı", kazanma değil).
	&"revive": {"streams": ["rewards/sfx_round_win_01.wav"], "gain_db": -6.0, "pitch": 0.9,
		"cooldown_ms": 500, "max_voices": 1, "priority": Priority.CRITICAL},

	# ---------- GÜÇLER ----------
	## Hedefleme moduna giriş: CONFIRM ailesinin hafif, tiz "silahlandı" hâli.
	&"power_arm": {"streams": ["ui/sfx_ui_confirm_01.wav"], "gain_db": -13.0,
		"pitch": 1.15, "cooldown_ms": 80, "max_voices": 1, "steal_self": true,
		"priority": Priority.LOW},
	## Bomba (owner A): fırlatma inen ton → kompakt vuruş + 15 ms sonra
	## yumuşak puf. Gerçekçi patlama / bas gümbürtüsü YOK.
	&"bomb_whoosh": {"streams": ["powers/sfx_bomb_launch_01.wav"], "gain_db": -10.0,
		"cooldown_ms": 100, "max_voices": 1, "priority": Priority.NORMAL},
	&"bomb_impact": {"streams": ["powers/sfx_bomb_impact_01.wav"], "gain_db": -2.0,
		"pitch_jitter": 0.03, "cooldown_ms": 100, "max_voices": 1, "priority": Priority.HIGH,
		"layers": [&"bomb_poof"]},
	&"bomb_poof": {"streams": ["powers/sfx_bomb_poof_01.wav"], "gain_db": -10.0,
		"delay_ms": 15, "cooldown_ms": 100, "max_voices": 1, "priority": Priority.NORMAL},
	## Büyütücü (owner C, minimal): dokunuşta yükselen ton (150 ms anticipation'ı
	## kapsar), dönüşümde ölçülü hava süpürmesi + varılan tier'ın merge ailesi.
	&"upgrade": {"streams": ["powers/sfx_upgrade_charge_01.wav"], "gain_db": -9.0,
		"cooldown_ms": 150, "max_voices": 1, "priority": Priority.HIGH},
	&"upgrade_transform": {"streams": ["powers/sfx_upgrade_air_01.wav"], "gain_db": -14.0,
		"cooldown_ms": 150, "max_voices": 1, "priority": Priority.NORMAL},
	## Sarsıntı: jöle titremesi (375–1100 Hz warble), tek darbe.
	&"shake": {"streams": ["powers/sfx_shake_01.wav"], "gain_db": -5.0,
		"cooldown_ms": 200, "max_voices": 1, "priority": Priority.NORMAL},
	## Temizleyici (owner B, pop karakteri): aktivasyonda ince süpürme
	## (altta), parça başına yumuşak pop. Gameplay kademesi 45 ms
	## (CLEAR_STAGGER); soğuma 40 ms — 120 Hz'de kare hizalaması kademeyi
	## 41.7 ms'ye çekebiliyor, pop düşmesin. 3 kanal tavanı spam'i keser.
	&"clear_sweep": {"streams": ["powers/sfx_clear_sweep_01.wav"], "gain_db": -14.0,
		"cooldown_ms": 200, "max_voices": 1, "priority": Priority.NORMAL},
	&"clear_puff": {"streams": ["powers/sfx_clear_pop_01.wav", "powers/sfx_clear_pop_02.wav",
		"powers/sfx_clear_pop_03.wav"], "gain_db": -7.0, "pitch_jitter": 0.08,
		"gain_jitter_db": 1.5, "cooldown_ms": 40, "max_voices": 3, "priority": Priority.LOW},

	# ---------- İLERLEME / ÖDÜL ----------
	## Yıldızlar: merge parıltısının kendisi (sonuç ekranı = aynı aile).
	&"star_reveal": {"streams": ["gameplay/sfx_merge_sparkle_01.wav"], "gain_db": -8.0,
		"cooldown_ms": 100, "max_voices": 2, "priority": Priority.NORMAL},
	## Sandık (owner A, mandal): mix'te ölçülü.
	&"chest_open": {"streams": ["rewards/sfx_chest_open_01.wav"], "gain_db": -6.0,
		"cooldown_ms": 150, "max_voices": 1, "priority": Priority.NORMAL},
	## Ödül merdiveni, onaylı katmanlardan: Common = Hamur "ting"; Rare =
	## parıltı kuyruğu; Epic = müzik kutusu + kuyruk; Legendary = bloom +
	## müzik kutusu + yükselen ikinci nota + kuyruk (~1.2 s, T8 ailesi).
	&"reward_common": {"streams": ["rewards/sfx_reward_dough_01.wav"], "gain_db": -6.0,
		"cooldown_ms": 150, "max_voices": 1, "priority": Priority.HIGH},
	&"reward_rare": {"streams": ["rewards/sfx_tier8_tail_01.wav"], "gain_db": -6.0,
		"cooldown_ms": 150, "max_voices": 1, "priority": Priority.HIGH},
	&"reward_epic": {"streams": ["rewards/sfx_tier8_box_01.wav"], "gain_db": -6.0,
		"cooldown_ms": 150, "max_voices": 1, "priority": Priority.CRITICAL,
		"layers": [&"reward_epic_tail"]},
	&"reward_epic_tail": {"streams": ["rewards/sfx_tier8_tail_01.wav"], "gain_db": -7.0,
		"delay_ms": 60, "cooldown_ms": 150, "max_voices": 1, "priority": Priority.CRITICAL},
	&"reward_legendary": {"streams": ["rewards/sfx_tier8_bloom_01.wav"], "gain_db": -4.0,
		"cooldown_ms": 300, "max_voices": 1, "priority": Priority.CRITICAL,
		"layers": [&"reward_legendary_box", &"reward_legendary_box_up", &"reward_legendary_tail"]},
	&"reward_legendary_box": {"streams": ["rewards/sfx_tier8_box_01.wav"], "gain_db": -7.0,
		"delay_ms": 60, "cooldown_ms": 300, "max_voices": 1, "priority": Priority.CRITICAL},
	&"reward_legendary_box_up": {"streams": ["rewards/sfx_tier8_box_01.wav"], "gain_db": -8.0,
		"pitch": 1.335, "delay_ms": 220, "cooldown_ms": 300, "max_voices": 1,
		"priority": Priority.CRITICAL},
	&"reward_legendary_tail": {"streams": ["rewards/sfx_tier8_tail_01.wav"], "gain_db": -9.0,
		"delay_ms": 120, "cooldown_ms": 300, "max_voices": 1, "priority": Priority.CRITICAL},
	&"daily_reward": {"streams": ["rewards/sfx_reward_dough_01.wav"], "gain_db": -5.0,
		"pitch": 0.95, "cooldown_ms": 300, "max_voices": 1, "priority": Priority.HIGH},
	&"level_unlock": {"streams": ["rewards/sfx_tier8_tail_01.wav"], "gain_db": -7.0,
		"pitch": 1.05, "cooldown_ms": 300, "max_voices": 1, "priority": Priority.HIGH},
}

const _DEFAULTS: Dictionary = {
	"streams": [], "fallback": &"", "gain_db": 0.0, "gain_jitter_db": 0.0,
	"pitch": 1.0, "pitch_jitter": 0.0, "cooldown_ms": 0, "max_voices": 4,
	"steal_self": false, "priority": Priority.NORMAL, "layers": [], "delay_ms": 0,
}

## --- İniş parametreleri (yalnızca SUNUM; fizik dokunulmadı) ---
## İniş seviyesi: LAND_PUFF_SPEED'de -9 dB'nin altına LAND_GAIN_MIN kadar,
## LAND_SPEED_FULL'da tam seviye.
const LAND_GAIN_MIN_DB: float = -8.0
const LAND_SPEED_FULL: float = 950.0
## İniş pitch'i: küçük parça tiz/hafif, büyük parça pes/derin.
const LAND_PITCH_TIER1: float = 1.25
const LAND_PITCH_TIER8: float = 0.78

## --- Merge ailesi (owner onaylı A, docs/audio/MERGE_SOUND_FAMILY.md) ---
## Bu tier ve üstünde parıltı / çan katmanı eklenir.
const MERGE_SPARKLE_MIN_TIER: int = 3
const MERGE_CHIME_MIN_TIER: int = 5
## Tier başına reçete (index = tier - 1). POP pitch'i TierConfig.merge_pitch
## (kilitli 0.85 → 1.48); burada POP seviyesi, gövde havuzu + pitch + seviye
## (mutlak dB, havuzun gain_db'sinin yerine geçer), parıltı ve çan seviye/pitch.
## Tier 8: gövde + POP üstüne `tier_max` (bloom + kutu + kuyruk); parıltı ve
## çanın yerini bloom/kuyruk alır (5 kanal).
const MERGE_RECIPE: Array[Dictionary] = [
	{"pop_db": -3.0, "body": &"merge_body_light", "body_pitch": 1.15, "body_db": -16.0},
	{"pop_db": -2.0, "body": &"merge_body_light", "body_pitch": 1.08, "body_db": -14.0},
	{"pop_db": -1.0, "body": &"merge_body_light", "body_pitch": 1.00, "body_db": -12.0,
		"sparkle_pitch": 1.00, "sparkle_db": -14.0},
	{"pop_db": -1.0, "body": &"merge_body_full", "body_pitch": 0.95, "body_db": -10.0,
		"sparkle_pitch": 1.06, "sparkle_db": -12.0},
	{"pop_db": -1.0, "body": &"merge_body_full", "body_pitch": 0.90, "body_db": -8.0,
		"sparkle_pitch": 1.06, "sparkle_db": -12.0, "chime_pitch": 1.00, "chime_db": -11.0},
	{"pop_db": -1.0, "body": &"merge_body_full", "body_pitch": 0.84, "body_db": -8.0,
		"sparkle_pitch": 1.12, "sparkle_db": -11.0, "chime_pitch": 1.06, "chime_db": -9.0},
	{"pop_db": -1.0, "body": &"merge_body_large", "body_pitch": 0.90, "body_db": -7.0,
		"sparkle_pitch": 1.12, "sparkle_db": -11.0, "chime_pitch": 1.12, "chime_db": -8.0},
	{"pop_db": -3.0, "body": &"merge_body_large", "body_pitch": 0.80, "body_db": -7.0},
]
const COMBO_PITCH_STEP: float = 0.04
const COMBO_PITCH_MAX_COUNT: int = 8

var _streams: Dictionary = {}          # olay -> Array[AudioStream]
var _voices: Array[AudioStreamPlayer] = []
var _voice_event: Array[StringName] = []
var _voice_priority: Array[int] = []
var _voice_started_ms: Array[int] = []
var _last_played_ms: Dictionary = {}   # olay -> msec
var _missing_events: PackedStringArray = []
## Gecikmeli katmanlar: bekleyen sayaç + nesil. stop_all() nesli artırır;
## eski nesilden gelen zamanlayıcılar çalmaz (temizlik, test edilebilir).
var _pending_delayed: int = 0
var _delay_generation: int = 0
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
	_streams.clear()
	_missing_events.clear()
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
	_resolve_fallbacks()
	if not _missing_events.is_empty():
		push_warning("SFX dosyası eksik (sessiz ya da fallback): %s — bkz. docs/audio/AUDIO_SYSTEM.md"
			% ", ".join(_missing_events))


## Fallback çözümü: akışı olmayan olay, fallback'inin yüklü havuzunu paylaşır
## (zincirleme: fallback'in de fallback'i olabilir). Test bunu doğrudan çağırır.
func _resolve_fallbacks() -> void:
	for id: StringName in EVENTS:
		if _streams.has(id):
			continue
		var next: StringName = _field(id, "fallback")
		var hops: int = 0
		while next != &"" and hops < MAX_LAYER_DEPTH:
			if _streams.has(next):
				_streams[id] = _streams[next]
				break
			next = _field(next, "fallback") if EVENTS.has(next) else &""
			hops += 1


func _field(id: StringName, key: String) -> Variant:
	var event: Dictionary = EVENTS.get(id, {})
	return event.get(key, _DEFAULTS[key])


## Yüklenmiş (ya da fallback'le çözülmüş) bir akışı var mı?
func has_stream(id: StringName) -> bool:
	return _streams.has(id)


func missing_events() -> PackedStringArray:
	return _missing_events


# --- Çalma ---

## Olayı (ve katmanlarını) çalar. `pitch_mul` ve `gain_offset_db` tablodaki
## değerlerin üstüne biner (katmanlar pitch çarpanını alır, seviye ofsetini
## almaz). Dönüş: ana akış gerçekten başlatıldıysa ya da gecikmeye
## alındıysa true (soğuma, tavan, eksik dosya ya da kanal yokluğunda false —
## hata değil, politika).
func play(id: StringName, pitch_mul: float = 1.0, gain_offset_db: float = 0.0) -> bool:
	if not EVENTS.has(id):
		push_warning("Bilinmeyen SFX olayı: %s" % id)
		return false
	var started: bool = _play_event(id, pitch_mul, gain_offset_db)
	var visited: Dictionary = {id: true}
	_play_layers(id, pitch_mul, visited, 1)
	return started


## Katman ağacını açar; her katman kendi delay_ms'iyle çağrı anından ölçülür.
func _play_layers(id: StringName, pitch_mul: float, visited: Dictionary, depth: int) -> void:
	if depth > MAX_LAYER_DEPTH:
		return
	for layer: StringName in _field(id, "layers"):
		if visited.has(layer) or not EVENTS.has(layer):
			continue
		visited[layer] = true
		_play_event(layer, pitch_mul, 0.0)
		_play_layers(layer, pitch_mul, visited, depth + 1)


## Hemen ya da (delay_ms > 0) zamanlayıcıyla çalar.
func _play_event(id: StringName, pitch_mul: float, gain_offset_db: float) -> bool:
	var delay: int = _field(id, "delay_ms")
	if delay <= 0 or not is_inside_tree():
		return _play_single(id, pitch_mul, gain_offset_db)
	if not _streams.has(id):
		return false
	var generation: int = _delay_generation
	_pending_delayed += 1
	# SceneTreeTimer: process döngüsü yok, board/sahne değişse de güvenli
	# (yalnızca bu autoload'a bağlı). Nesil eşleşmezse (stop_all) sessizce düşer.
	get_tree().create_timer(float(delay) / 1000.0).timeout.connect(
		func() -> void:
			_pending_delayed = maxi(_pending_delayed - 1, 0)
			if generation == _delay_generation:
				_play_single(id, pitch_mul, gain_offset_db))
	return true


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


## Henüz ateşlenmemiş gecikmeli katman sayısı (test/QA).
func pending_delayed() -> int:
	return _pending_delayed


## Bütün kanalları durdurur; bekleyen gecikmeli katmanlar iptal olur.
func stop_all() -> void:
	_delay_generation += 1
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


## Tier reçetesi (test/QA için de açık).
static func merge_recipe(tier: int) -> Dictionary:
	return MERGE_RECIPE[clampi(tier, 1, TierConfig.MAX_TIER) - 1]


## Merge (owner onaylı A ailesi): POP tier'a göre yükselen pitch'te
## (GAME_DESIGN §6) + tier bandına göre gövde havuzu; tier ≥ 3 +30 ms cam
## parıltısı, tier ≥ 5 +45 ms çan; tier 8 bloom + müzik kutusu + kuyruk.
## Gövde/parıltı/çan seviyeleri MERGE_RECIPE'de mutlak dB: havuzun tablo
## gain_db'si çıkarılıp ofset olarak veriliyor.
func play_merge(new_tier: int) -> void:
	var tier: int = clampi(new_tier, 1, TierConfig.MAX_TIER)
	var recipe: Dictionary = merge_recipe(tier)
	_play_event(&"merge", TierConfig.merge_pitch(tier),
		float(recipe["pop_db"]) - float(_field(&"merge", "gain_db")))
	var body: StringName = recipe["body"]
	_play_event(body, float(recipe["body_pitch"]),
		float(recipe["body_db"]) - float(_field(body, "gain_db")))
	if tier >= TierConfig.MAX_TIER:
		play(&"tier_max")
		return
	if tier >= MERGE_SPARKLE_MIN_TIER:
		_play_event(&"merge_sparkle", float(recipe["sparkle_pitch"]),
			float(recipe["sparkle_db"]) - float(_field(&"merge_sparkle", "gain_db")))
	if tier >= MERGE_CHIME_MIN_TIER:
		_play_event(&"merge_chime", float(recipe["chime_pitch"]),
			float(recipe["chime_db"]) - float(_field(&"merge_chime", "gain_db")))


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
