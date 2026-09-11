extends Node2D
## Dumpling görseli: tier başına tek bir karakter sprite'ı.
##
## M8'de owner'ın kendi asset'lerine geçildi (ChatGPT ile üretilmiş 8 karakter,
## bkz. assets/visual/CREDITS.md). Önceki Kenney "Shape Characters" kurulumu
## nötr gri bir gövdeyi tier rengiyle tint'liyor, üstüne ayrı bir yüz sprite'ı
## koyuyordu. Yeni sprite'lar kendi rengiyle ve gövdeye gömülü yüzüyle geliyor:
##  - tint (modulate) UYGULANMIYOR
##  - ayrı yüz katmanı YOK
##  - parlama overlay'i YOK (sprite'ların kendi spekuler parlamaları var)
##
## M8.5'te takılı skin desteği eklendi. Skin'in NASIL çizildiği bu dosyada
## değil, `scripts/game/skin_visual.gd` içinde — orası bilerek değiştirilebilir
## bir katman. Burada yalnızca "hangi skin" sorusu cevaplanıyor.

## Tier -> sprite. Sıra TierConfig.TIERS ile aynı.
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/visual/dumpling_tier1.png"),
	preload("res://assets/visual/dumpling_tier2.png"),
	preload("res://assets/visual/dumpling_tier3.png"),
	preload("res://assets/visual/dumpling_tier4.png"),
	preload("res://assets/visual/dumpling_tier5.png"),
	preload("res://assets/visual/dumpling_tier6.png"),
	preload("res://assets/visual/dumpling_tier7.png"),
	preload("res://assets/visual/dumpling_tier8.png"),
]

var radius: float = 20.0

## --- Temas kalibrasyonu (M8.5-11) — COLLIDER DEGISMEDI ---
##
## Sprite'lar ~1.3-1.4 en/boy oranli genis bloblar, collider ise daire.
## M8'in geometrik-ortalama olcegi govdeyi dikeyde capin yalnizca %70-79'una
## sigdiriyordu: yatay temas ~1 px ama taban 3-13 px havada, dikey/capraz
## temaslarda 10-30 px gorunur bosluk ("fizik degiyor, sprite degmiyor").
## Seffaf padding hipotezi olculup ELENDI: dokularin alfa bbox'i tam doku.
##
## Tablo `python tools/contact_audit.py --fit` ciktisi (aksesuarsiz govde
## silueti esas alinarak):
##   scale.x : govde genisligi = 2r + 2 px (yan yana hafif overlap)
##   scale.y : govde yuksekligi 2r'nin %90'ina yaklasir, dikey uzama en fazla
##             1.25x (daha fazlasi karakteri bozar); T3/T8 neredeyse uniform
##   offset  : govde alt kenari collider alt kenarinin 1 px ustune (dunya px)
## Sonuc: gapAB -2 px (overlap), taban 1 px, duvar -1 px — sekiz tier'da.
## Dokular veya TierConfig yaricaplari degisirse tabloyu yeniden uret.
const CONTACT_FIT: Array[Dictionary] = [
	{"scale": Vector2(0.36800, 0.43516), "offset": Vector2(0.00, -2.72)},  # tier 1, stretch 1.18
	{"scale": Vector2(0.43411, 0.52826), "offset": Vector2(0.00, -2.26)},  # tier 2, stretch 1.22
	{"scale": Vector2(0.31250, 0.31250), "offset": Vector2(0.00, -3.41)},  # tier 3, stretch 1.00
	{"scale": Vector2(0.33992, 0.41538), "offset": Vector2(0.00, -4.48)},  # tier 4, stretch 1.22
	{"scale": Vector2(0.41569, 0.48497), "offset": Vector2(0.00, -1.13)},  # tier 5, stretch 1.17
	{"scale": Vector2(0.26036, 0.30000), "offset": Vector2(-0.39, -1.25)},  # tier 6, stretch 1.15
	{"scale": Vector2(0.31660, 0.36911), "offset": Vector2(-2.69, 0.27)},  # tier 7, stretch 1.17
	{"scale": Vector2(0.43723, 0.44554), "offset": Vector2(-2.19, -5.70)},  # tier 8, stretch 1.02
]

## Bu parçanın kullanacağı skin. null = varsayılan/orijinal görünüm.
##
## setup() sırasında doldurulmuyorsa SaveManager'daki takılı skin okunuyor —
## yani hem yeni drop'lar hem merge sonucu oluşan yeni tier'lar otomatik
## olarak aynı aktif skin'i kullanıyor. Testler ve önizleme araçları
## `override_skin()` ile SaveManager'dan bağımsız bir skin verebilir.
var _skin: SkinData = null
var _skin_overridden: bool = false

var _tween: Tween
var _sprite: Sprite2D


func _ready() -> void:
	_ensure_sprite()


## setup() _ready'den önce de çağrılabildiği için sprite tembel kuruluyor.
func _ensure_sprite() -> void:
	if _sprite != null:
		return
	_sprite = Sprite2D.new()
	add_child(_sprite)


func setup(tier: int) -> void:
	radius = TierConfig.radius(tier)
	_ensure_sprite()
	var texture: Texture2D = TEXTURES[tier - 1]
	_sprite.texture = texture
	# Eski formul (geometrik ortalama, M8) yerine olculmus temas kalibrasyonu
	# — gerekce CONTACT_FIT basliginda.
	var fit: Dictionary = CONTACT_FIT[tier - 1]
	_sprite.scale = fit["scale"]
	_fit_offset = fit["offset"]
	_sprite.position = _fit_offset
	_refresh_skin()


# --- Skin katmanı ---
#
# Buradaki tek iş DOĞRU SKIN'İ SEÇMEK. Skin'in nasıl göründüğü tamamen
# SkinVisual'ın işi (scripts/game/skin_visual.gd) — sanat tekniği değişirse
# bu dosyaya dokunulmayacak.

## Takılı skin yerine belirli bir skin kullan (QA/önizleme). null = varsayılan.
func override_skin(skin: SkinData) -> void:
	_skin = skin
	_skin_overridden = true
	_refresh_skin()


## Override'ı bırakıp tekrar SaveManager'daki takılı skin'e dön.
func use_equipped_skin() -> void:
	_skin_overridden = false
	_refresh_skin()


func _refresh_skin() -> void:
	if _sprite == null:
		return
	if not _skin_overridden:
		_skin = SaveManager.equipped_skin()
	SkinVisual.apply(_sprite, _skin)


## Gövde serbest dönüyor (M1 kilitli karar) ama yüz bu sprite'ların İÇİNDE
## gömülü — gövdeyle birlikte tam dönerse karakter baş aşağı kalıyor.
##
## Tam ters dönüş (rotation = -parent.rotation) denendi: yüz okunuyordu ama
## parçalar robotik biçimde dimdik duruyordu, yığın cansızlaşıyordu. Onun
## yerine sprite gövdeyi ±MAX_TILT'e kadar TAKİP EDİYOR, sonra sabitleniyor:
## küçük eğilmeler görünüyor, baş aşağı dönüş görünmüyor.
##
## lerp_angle ile yumuşatılıyor çünkü gövde 180°'yi geçerken hedef açı
## +MAX'tan -MAX'a atlıyor; doğrudan atansa görünür bir sıçrama olurdu.
const MAX_TILT: float = deg_to_rad(20.0)
## Hedefe yaklaşma hızı (1/sn). Yüksek = daha çevik, düşük = daha tembel.
const TILT_SPEED: float = 12.0

## Sprite'ın DÜNYA açısı (ebeveynin değil). Yumuşatma bunun üzerinden gidiyor.
var _tilt: float = 0.0


## --- Dusus gerilmesi (M8.5-11, yalnizca sunum) ---
##
## Hizli duserken govde dusme yonunde hafifce uzar (en fazla FALL_STRETCH),
## yere/yigina carpinca mevcut squash devreye giriyor. Gerilme HIZ'a bagli
## ve dunya dikeyinde: yatay hizli parcalar (sarsinti) uzamaz, dusen parca
## "RigidBody sprite" degil dusen squishy karakter gibi okunsun.
## Skala bilesimi: scale = _squash * (1 - k, 1 + k). Squash tween'i artik
## `scale`i degil `_squash`i animasyonluyor; ikisi birbirini ezmiyor.
const FALL_STRETCH: float = 0.10
const FALL_SPEED_MIN: float = 220.0
const FALL_SPEED_MAX: float = 1100.0
const FALL_SMOOTH: float = 18.0

var _squash: Vector2 = Vector2.ONE
var _fall: float = 0.0
## Bu tier'in CONTACT_FIT offset'i (sprite'in temel konumu).
var _fit_offset: Vector2 = Vector2.ZERO
## Squash'in cekim noktasi: 1 = alt kenar sabit (yere carpma), 0 = merkez.
var _squash_anchor: float = 0.0


func _process(delta: float) -> void:
	var parent := get_parent() as Node2D
	if parent == null:
		return
	var body_rotation: float = wrapf(parent.global_rotation, -PI, PI)
	var target: float = clampf(body_rotation, -MAX_TILT, MAX_TILT)
	_tilt = lerp_angle(_tilt, target, 1.0 - exp(-delta * TILT_SPEED))
	rotation = _tilt - parent.global_rotation

	var body := parent as RigidBody2D
	var fall_target: float = 0.0
	if body != null and not body.freeze:
		var vy: float = body.linear_velocity.y
		if vy > FALL_SPEED_MIN:
			fall_target = clampf((vy - FALL_SPEED_MIN) / (FALL_SPEED_MAX - FALL_SPEED_MIN), 0.0, 1.0)
	_fall = lerpf(_fall, fall_target, 1.0 - exp(-delta * FALL_SMOOTH))
	_apply_scale()


## Squash ve dusus gerilmesini tek scale'de birlestirir. Alt kenar cekimi:
## dikey ezilme alt kenari yukari cekerdi; position.y ile telafi edilince
## parca yere BASILIYOR gibi okunuyor, havada eziliyor gibi degil.
func _apply_scale() -> void:
	var k: float = FALL_STRETCH * _fall
	scale = Vector2(_squash.x * (1.0 - k), _squash.y * (1.0 + k))
	# Telafi SPRITE'a uygulaniyor, bu dugume degil: Preview ayni script'i
	# tasiyor ve konumu GameBoard veriyor, buradan ezilmemeli. Dugum olcegi
	# sprite konumunu da olceklediginden pay 1/scale.y ile bolunuyor.
	if _sprite != null:
		var lift: float = 0.0
		if _squash_anchor > 0.0 and scale.y > 0.01:
			lift = radius * (1.0 - scale.y) / scale.y * _squash_anchor
		_sprite.position = _fit_offset + Vector2(0.0, lift)


# --- Güç hedefleme vurgusu (M8.5-03) ---
#
# Geçerli hedefler nabız atarak beliriyor; geçersizler HİÇ dokunulmadan
# kalıyor (highlight yok = hedeflenemez, ayrıca bir "geçersiz" işareti yok).

## Vurgu nabzının genliği ve hızı.
const TARGET_PULSE: float = 0.18
const TARGET_PULSE_SPEED: float = 6.0

var _targetable: bool = false
var _target_tween: Tween


func set_targetable(targetable: bool) -> void:
	if _targetable == targetable:
		return
	_targetable = targetable
	if _target_tween != null and _target_tween.is_valid():
		_target_tween.kill()
	if _sprite == null:
		return
	if not targetable:
		_sprite.modulate = Color.WHITE
		return
	# Beyaza doğru nabız: sprite'ların kendi renkleri korunuyor, üstlerine
	# yalnızca parlaklık biniyor.
	var bright := Color(1.0 + TARGET_PULSE, 1.0 + TARGET_PULSE, 1.0 + TARGET_PULSE)
	_target_tween = create_tween().set_loops().bind_node(_sprite)
	_target_tween.tween_property(_sprite, "modulate", bright,
		1.0 / TARGET_PULSE_SPEED).set_trans(Tween.TRANS_SINE)
	_target_tween.tween_property(_sprite, "modulate", Color.WHITE,
		1.0 / TARGET_PULSE_SPEED).set_trans(Tween.TRANS_SINE)


## Sprite'in bagimsiz bir kopyasi, dunya donusumuyle (M8.5-11 merge pull).
## Skin materyali de kopyalaniyor ki hayalet takili skinle ayni gorunsun.
func make_ghost() -> Sprite2D:
	var ghost := Sprite2D.new()
	if _sprite != null:
		ghost.texture = _sprite.texture
		ghost.material = _sprite.material
		ghost.transform = _sprite.global_transform
	return ghost


## Bomba kilitlenmesi: tek seferlik keskin bir büyüme.
func play_lock_on() -> void:
	set_targetable(false)
	if _sprite == null:
		return
	var tween := create_tween().bind_node(_sprite)
	tween.tween_property(_sprite, "modulate", Color(1.6, 1.3, 1.3), 0.08)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.12)


## Squash-stretch. Merge'de tam genlik (GAME_DESIGN.md §1: 1.0 -> 1.2/0.8 -> 1.0,
## ~150 ms); çarpmada aynı tween'in hıza orantılı hafif versiyonu.
## `anchored` (M8.5-11): carpma squash'i alt kenardan basilir (bkz. _apply_scale).
func play_squash(amount: float = 0.2, duration: float = 0.15, anchored: bool = false) -> void:
	# Önceki squash hâlâ oynuyorsa kes — üst üste binince titreşim oluyor.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_squash = Vector2.ONE
	_squash_anchor = 1.0 if anchored else 0.0
	var half: float = duration * 0.5
	_tween = create_tween()
	var squashed := Vector2(1.0 + amount, 1.0 - amount)
	_tween.tween_property(self, "_squash", squashed, half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_squash", Vector2.ONE, half).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void: _squash_anchor = 0.0)


## Merge'de dogan parcanin acilisi (M8.5-11): 0.7 -> 1.12 -> 1.0, ~190 ms.
## Eski merge squash'inin yerine — "yeni tier belirdi" hissi, ezilme degil.
## `strength` 1.0 = normal, >1 ust tier'lar icin biraz daha genis pop.
func play_reveal(strength: float = 1.0) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_squash_anchor = 0.0
	_squash = Vector2.ONE * 0.7
	_apply_scale()
	var peak: float = 1.0 + 0.12 * strength
	_tween = create_tween()
	_tween.tween_property(self, "_squash", Vector2.ONE * peak, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_squash", Vector2.ONE, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
