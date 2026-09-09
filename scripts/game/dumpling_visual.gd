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
	# Sprite'lar dairesel DEĞİL (en/boy ~1.25), collider ise CircleShape2D.
	# Ölçek, görselin geometrik ortalamasını çapa eşitliyor: sadece genişliğe
	# göre ölçeklesek parçalar dikey boşlukla dururdu, sadece yüksekliğe göre
	# ölçeklesek yatayda taşıp üst üste binerdi. Bu ikisinin hatasını böler.
	# (tools/make_character_sprites.gd aynı formülü kullanarak küçültüyor.)
	var mean: float = sqrt(float(texture.get_width()) * float(texture.get_height()))
	_sprite.scale = Vector2.ONE * (radius * 2.0 / mean)
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


## Ölçek burada değiştirilmiyor — squash-stretch tween'i self.scale'i
## animasyonluyor ve ondan etkilenmemesi gerekiyor.
func _process(delta: float) -> void:
	var parent := get_parent() as Node2D
	if parent == null:
		return
	var body_rotation: float = wrapf(parent.global_rotation, -PI, PI)
	var target: float = clampf(body_rotation, -MAX_TILT, MAX_TILT)
	_tilt = lerp_angle(_tilt, target, 1.0 - exp(-delta * TILT_SPEED))
	rotation = _tilt - parent.global_rotation


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
func play_squash(amount: float = 0.2, duration: float = 0.15) -> void:
	# Önceki squash hâlâ oynuyorsa kes — üst üste binince titreşim oluyor.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	scale = Vector2.ONE
	var half: float = duration * 0.5
	_tween = create_tween()
	var squashed := Vector2(1.0 + amount, 1.0 - amount)
	_tween.tween_property(self, "scale", squashed, half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, half).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
