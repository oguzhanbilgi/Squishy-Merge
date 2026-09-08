extends Control
## Sandık ödül görseli: kapalı sandık → açılış → rarity efektleri.
##
## Akış (GAME_DESIGN.md §5.1 madde 3): kart belirdiğinde KAPALI sandık
## görünür, kısa bir bekleme sonra `open()` çağrılır; sandık açık görsele
## geçer ve rarity katmanları onun üstünde/çevresinde açılır.
##
## M3'te bu sadece "kart belirir"di, M8'de rarity katmanları eklendi ama
## efektler boş bir renk kutusunun üstünde oynuyordu. Artık gerçek sandığın
## üstünde oynuyorlar; rarity kademesi DEĞİŞMEDİ.

const CLOSED_TEXTURE: Texture2D = preload("res://assets/visual/ui/chest_closed.png")
const OPEN_TEXTURE: Texture2D = preload("res://assets/visual/ui/chest_open.png")
const DOT_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_dot.png")
const RING_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_ring.png")
const BURST_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_burst.png")
const SPARKLE_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_sparkle.png")

## Rarity'e göre yoğunluk (GAME_DESIGN.md §5.2 sırası: Common / Rare / Epic /
## Legendary). Bu tablo M8'de kalibre edildi, sandık entegrasyonunda
## DEĞİŞTİRİLMEDİ — sadece hangi görselin üstüne bindiği değişti.
##  glow  : arkadaki yumuşak parıltının alpha'sı
##  ring  : rarity çerçevesinin alpha'sı
##  rays  : dönen ışın katmanının alpha'sı (0 = yok)
##  spark : yayılan parıltı parçacığı sayısı (0 = yok)
##  pulse : sandığın nefes alma genliği (0 = sabit)
const RARITY_FX: Array[Dictionary] = [
	{"glow": 0.16, "ring": 0.30, "rays": 0.00, "spark": 0,  "pulse": 0.00},
	{"glow": 0.30, "ring": 0.55, "rays": 0.00, "spark": 7,  "pulse": 0.03},
	{"glow": 0.44, "ring": 0.75, "rays": 0.28, "spark": 13, "pulse": 0.05},
	{"glow": 0.62, "ring": 0.95, "rays": 0.60, "spark": 20, "pulse": 0.08},
]

## Görselin kutu ölçüsü. Parıltı ve ışınlar bunun DIŞINA taşar.
const GEM_SIZE: float = 80.0

var _fx: Dictionary
var _tint: Color = Color.WHITE
var _chest: TextureRect
var _rays: TextureRect
## Açılışta görünür hale gelen katmanlar (hedef alpha'larıyla birlikte).
var _hidden_layers: Array[Dictionary] = []
var _sparks: CPUParticles2D
var _opened: bool = false


## Teselli ödülü her zaman en sönük katmanı kullanır — kaybedilen round'un
## tesellisi legendary gibi parlamamalı.
static func fx_level(reward: ChestReward) -> int:
	return 0 if reward.is_consolation else int(reward.rarity)


func setup(reward: ChestReward) -> void:
	_fx = RARITY_FX[fx_level(reward)]
	_tint = reward.color()
	custom_minimum_size = Vector2(GEM_SIZE, GEM_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Katman sırası: parıltı → ışınlar → çerçeve → SANDIK → parçacıklar.
	_add_layer(DOT_TEXTURE, GEM_SIZE * 2.0, _tint, _fx["glow"])
	if _fx["rays"] > 0.0:
		_rays = _add_layer(BURST_TEXTURE, GEM_SIZE * 2.2,
			_tint.lerp(Color.WHITE, 0.35), _fx["rays"])
	_add_layer(RING_TEXTURE, GEM_SIZE * 1.5, _tint, _fx["ring"])

	_chest = TextureRect.new()
	_chest.texture = CLOSED_TEXTURE
	_chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_chest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_chest.size = Vector2(GEM_SIZE, GEM_SIZE)
	_chest.position = Vector2.ZERO
	_chest.pivot_offset = _chest.size * 0.5
	_chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chest)

	if _fx["spark"] > 0:
		_sparks = _make_sparks(int(_fx["spark"]))
		add_child(_sparks)


## Kapalı → açık geçişi + rarity katmanlarının açılması.
func open() -> void:
	if _opened or _chest == null:
		return
	_opened = true

	# Kapak "sıçrayarak" açılıyor: önce hafif çök, texture değiş, sonra pop.
	var pop := create_tween().bind_node(_chest)
	pop.tween_property(_chest, "scale", Vector2(0.88, 0.88), 0.08).set_trans(Tween.TRANS_SINE)
	pop.tween_callback(func() -> void: _chest.texture = OPEN_TEXTURE)
	pop.tween_property(_chest, "scale", Vector2(1.18, 1.18), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_chest, "scale", Vector2.ONE, 0.10)

	for entry in _hidden_layers:
		var layer: CanvasItem = entry["node"]
		if not is_instance_valid(layer):
			continue
		var fade := create_tween().bind_node(layer)
		fade.tween_property(layer, "modulate:a", entry["alpha"], 0.28).set_delay(0.08)

	if _rays != null:
		# Yavaş dönüş: sabit duran ışınlar cansız görünüyor.
		var spin := create_tween().set_loops().bind_node(_rays)
		spin.tween_property(_rays, "rotation", TAU, 14.0 - 6.0 * float(_fx["rays"]))

	if _fx["pulse"] > 0.0:
		var pulse := create_tween().set_loops().bind_node(self)
		var big: float = 1.0 + float(_fx["pulse"])
		pulse.tween_property(self, "scale", Vector2(big, big), 0.7).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(self, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)

	if _sparks != null:
		_sparks.emitting = true


## Ortalanmış, kutunun dışına taşan bir texture katmanı. Alpha 0'da başlar,
## open() ile hedef değerine açılır.
func _add_layer(texture: Texture2D, size: float, tint: Color, alpha: float) -> TextureRect:
	var layer := TextureRect.new()
	layer.texture = texture
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.size = Vector2(size, size)
	layer.position = Vector2((GEM_SIZE - size) * 0.5, (GEM_SIZE - size) * 0.5)
	layer.pivot_offset = layer.size * 0.5
	layer.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	_hidden_layers.append({"node": layer, "alpha": alpha})
	return layer


func _make_sparks(amount: int) -> CPUParticles2D:
	var sparks := CPUParticles2D.new()
	sparks.texture = SPARKLE_TEXTURE
	sparks.position = Vector2(GEM_SIZE * 0.5, GEM_SIZE * 0.5)
	sparks.amount = amount
	sparks.lifetime = 1.6
	sparks.explosiveness = 0.0
	# Açılır açılmaz parçacıklar zaten havada olsun, birikmeyi bekletmesin.
	sparks.preprocess = 1.6
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = GEM_SIZE * 0.45
	sparks.direction = Vector2.UP
	sparks.spread = 35.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 6.0
	sparks.initial_velocity_max = 20.0
	sparks.scale_amount_min = 0.06
	sparks.scale_amount_max = 0.16
	sparks.color = _tint.lerp(Color.WHITE, 0.5)
	sparks.emitting = false
	return sparks
