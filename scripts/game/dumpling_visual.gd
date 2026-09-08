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
