extends CanvasLayer
## Round sonu ekranı (GAME_DESIGN.md §5.1):
## sonuç -> yıldızlar tek tek gecikmeli reveal -> sandık açılışı.
## Butonlar baştan aktif: kaybedince "hemen tekrar dene" şartı bunu gerektiriyor,
## oyuncu animasyonu beklemek zorunda kalmasın.

signal retry_pressed
signal exit_pressed

const STAR_REVEAL_DELAY: float = 0.4
const CHEST_REVEAL_DELAY: float = 0.5
const STAR_FILLED_TEXTURE: Texture2D = preload("res://assets/visual/ui/ui_star_filled.png")
const STAR_EMPTY_TEXTURE: Texture2D = preload("res://assets/visual/ui/ui_star_empty.png")
## Sandık açılışı efektleri (GAME_DESIGN.md §5.1 "kapak, ışık, parçacık").
## M3'te placeholder'la anlamlı olmayacağı için ertelenmişti.
const BURST_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_burst.png")
const SPARKLE_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_sparkle.png")
const DOT_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_dot.png")
const RING_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_ring.png")

## Ödül görselinin rarity'e göre yoğunluğu (GAME_DESIGN.md §5.2 sırası:
## Common / Rare / Epic / Legendary). Düz renkli kare ödül anını sönük
## bırakıyordu; katmanlar rarity yükseldikçe devreye giriyor.
##  glow  : arkadaki yumuşak parıltının alpha'sı
##  ring  : rarity çerçevesinin alpha'sı
##  rays  : dönen ışın katmanının alpha'sı (0 = yok)
##  spark : sürekli yayılan parıltı parçacığı sayısı (0 = yok)
##  pulse : çekirdeğin nefes alma genliği (0 = sabit)
const RARITY_FX: Array[Dictionary] = [
	{"glow": 0.16, "ring": 0.30, "rays": 0.00, "spark": 0,  "pulse": 0.00},
	{"glow": 0.30, "ring": 0.55, "rays": 0.00, "spark": 7,  "pulse": 0.03},
	{"glow": 0.44, "ring": 0.75, "rays": 0.28, "spark": 13, "pulse": 0.05},
	{"glow": 0.62, "ring": 0.95, "rays": 0.60, "spark": 20, "pulse": 0.08},
]

## Ödül görselinin kutu ölçüsü. Parıltı ve ışınlar bunun DIŞINA taşar,
## o yüzden kartın yüksekliği buna göre ayarlı.
const GEM_SIZE: float = 64.0
## Kaynak sprite 64x60; kutu bu oranda tutuluyor ki yıldız ezilmesin.
const STAR_SIZE: Vector2 = Vector2(64.0, 60.0)

var _sequence_id: int = 0

@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _stars: HBoxContainer = $Center/Panel/VBox/Stars
@onready var _detail: Label = $Center/Panel/VBox/Detail
@onready var _chests: VBoxContainer = $Center/Panel/VBox/Chests
@onready var _dough: Label = $Center/Panel/VBox/Dough
@onready var _retry: Button = $Center/Panel/VBox/Buttons/Retry
@onready var _exit: Button = $Center/Panel/VBox/Buttons/Exit
@onready var _fx: Control = $FxLayer


func _ready() -> void:
	hide_result()
	_retry.pressed.connect(func() -> void: retry_pressed.emit())
	_exit.pressed.connect(func() -> void: exit_pressed.emit())


func hide_result() -> void:
	# Devam eden reveal varsa geçersiz kıl — tekrar dene'ye basılırsa
	# eski animasyon yeni ekrana yazmasın.
	_sequence_id += 1
	visible = false


func show_result(level: LevelData, won: bool, score: int, stars: int,
		rewards: Array[ChestReward], new_record: bool) -> void:
	_sequence_id += 1
	var sequence: int = _sequence_id

	if level.is_endless:
		_title.text = "Yeni rekor!" if new_record else "Bitti"
		_detail.text = "Skor: %d\nRekor: %d" % [score, SaveManager.endless_high_score()]
	else:
		# objective_text() zaten "Hedef: ..." ile başlıyor, tekrar ekleme.
		_title.text = ("Level %d tamam!" % level.level_number) if won else "Olmadı"
		_detail.text = "Skor: %d\n%s" % [score, level.objective_text()]

	_build_stars(level, stars)
	_build_chests(rewards)
	_refresh_dough()
	visible = true

	await _reveal_stars(sequence, stars)
	await _reveal_chests(sequence, rewards)


# --- Yıldızlar ---

func _build_stars(level: LevelData, stars: int) -> void:
	for child in _stars.get_children():
		child.queue_free()
	# Sonsuz modda yıldız kavramı yok (GAME_DESIGN.md §5.1).
	_stars.visible = not level.is_endless
	if level.is_endless:
		return
	for i in 3:
		var star := TextureRect.new()
		star.texture = STAR_FILLED_TEXTURE if i < stars else STAR_EMPTY_TEXTURE
		star.custom_minimum_size = STAR_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Dolu yıldız zaten sarı (Yellow paketi), tint gerekmiyor; boş olan soluk.
		star.modulate = Color(1, 1, 1, 1) if i < stars else Color(1, 1, 1, 0.35)
		# Kazanılan yıldızlar gizli başlar, tek tek açılır.
		star.scale = Vector2.ZERO if i < stars else Vector2.ONE
		star.pivot_offset = STAR_SIZE * 0.5
		_stars.add_child(star)


func _reveal_stars(sequence: int, stars: int) -> void:
	for i in stars:
		await get_tree().create_timer(STAR_REVEAL_DELAY).timeout
		if sequence != _sequence_id or i >= _stars.get_child_count():
			return
		var star: TextureRect = _stars.get_child(i)
		var tween := create_tween()
		tween.tween_property(star, "scale", Vector2(1.25, 1.25), 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(star, "scale", Vector2.ONE, 0.1)
		# "Pat" sesi — stream M6'da gelecek, pitch her yıldızda biraz yükseliyor.
		AudioManager.play_sfx(&"star_pat", 1.0 + 0.12 * float(i))


# --- Sandıklar ---

func _build_chests(rewards: Array[ChestReward]) -> void:
	for child in _chests.get_children():
		child.queue_free()
	for reward in rewards:
		_chests.add_child(_make_chest_card(reward))


## Sandık kartı: rarity'e göre katmanlı ödül görseli + iki satır yazı.
func _make_chest_card(reward: ChestReward) -> Control:
	var card := PanelContainer.new()
	# Diyalog paneli (başlık çubuklu, kalın üst payı olan) liste öğesi olarak
	# yanlış duruyor; kart kendi sade stilini kullanıyor.
	card.theme_type_variation = &"CardPanel"
	card.modulate = Color(1, 1, 1, 0)
	card.custom_minimum_size = Vector2(0, 72)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	row.add_child(_make_reward_gem(reward))

	var text := VBoxContainer.new()
	row.add_child(text)

	var rarity_label := Label.new()
	rarity_label.text = reward.title()
	rarity_label.modulate = reward.color()
	text.add_child(rarity_label)

	var detail_label := Label.new()
	detail_label.text = reward.description()
	text.add_child(detail_label)

	return card


## Ödül görseli: arkadan öne parıltı → ışınlar → çerçeve → çekirdek.
## Hangi katmanın görüneceği rarity'e bağlı (RARITY_FX).
func _make_reward_gem(reward: ChestReward) -> Control:
	var fx: Dictionary = RARITY_FX[_fx_level(reward)]
	var tint: Color = reward.color()

	var gem := Control.new()
	gem.custom_minimum_size = Vector2(GEM_SIZE, GEM_SIZE)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_add_layer(gem, DOT_TEXTURE, GEM_SIZE * 2.0, tint, fx["glow"])

	if fx["rays"] > 0.0:
		var rays: TextureRect = _add_layer(gem, BURST_TEXTURE, GEM_SIZE * 2.2,
			tint.lerp(Color.WHITE, 0.35), fx["rays"])
		# Yavaş dönüş: sabit duran ışınlar cansız görünüyor.
		var spin := create_tween().set_loops().bind_node(rays)
		spin.tween_property(rays, "rotation", TAU, 14.0 - 6.0 * float(fx["rays"]))

	_add_layer(gem, RING_TEXTURE, GEM_SIZE * 1.5, tint, fx["ring"])

	# Çekirdek: eski düz ColorRect yerine yuvarlatılmış, kenarı açık bir kutu.
	var core := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = tint
	box.corner_radius_top_left = 12
	box.corner_radius_top_right = 12
	box.corner_radius_bottom_right = 12
	box.corner_radius_bottom_left = 12
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = tint.lerp(Color.WHITE, 0.55)
	core.add_theme_stylebox_override("panel", box)
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var core_size: float = GEM_SIZE * 0.72
	core.size = Vector2(core_size, core_size)
	core.position = Vector2((GEM_SIZE - core_size) * 0.5, (GEM_SIZE - core_size) * 0.5)
	core.pivot_offset = core.size * 0.5
	gem.add_child(core)

	if fx["pulse"] > 0.0:
		var pulse := create_tween().set_loops().bind_node(core)
		var big: float = 1.0 + float(fx["pulse"])
		pulse.tween_property(core, "scale", Vector2(big, big), 0.7).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(core, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)

	if fx["spark"] > 0:
		gem.add_child(_make_gem_sparks(tint, int(fx["spark"])))

	return gem


## Teselli ödülü her zaman en sönük katmanı kullanır — kaybedilen round'un
## tesellisi legendary gibi parlamamalı.
func _fx_level(reward: ChestReward) -> int:
	return 0 if reward.is_consolation else int(reward.rarity)


## Ortalanmış, kutunun dışına taşan bir texture katmanı ekler.
func _add_layer(gem: Control, texture: Texture2D, size: float,
		tint: Color, alpha: float) -> TextureRect:
	var layer := TextureRect.new()
	layer.texture = texture
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.size = Vector2(size, size)
	layer.position = Vector2((GEM_SIZE - size) * 0.5, (GEM_SIZE - size) * 0.5)
	layer.pivot_offset = layer.size * 0.5
	layer.modulate = Color(tint.r, tint.g, tint.b, alpha)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.add_child(layer)
	return layer


func _make_gem_sparks(tint: Color, amount: int) -> CPUParticles2D:
	var sparks := CPUParticles2D.new()
	sparks.texture = SPARKLE_TEXTURE
	sparks.position = Vector2(GEM_SIZE * 0.5, GEM_SIZE * 0.5)
	sparks.amount = amount
	sparks.lifetime = 1.6
	sparks.explosiveness = 0.0
	# Kart açılır açılmaz parçacıklar zaten havada olsun.
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
	sparks.color = tint.lerp(Color.WHITE, 0.5)
	sparks.emitting = true
	return sparks


## Sandık açılışı: rarity renginde bir ışık patlaması + parıltı parçacıkları.
func _burst_at(center: Vector2, tint: Color, fx_level: int = 3) -> void:
	# 0 (common) -> 1 (legendary): patlamanın büyüklüğü ve parçacık sayısı.
	var t: float = float(fx_level) / 3.0
	var flash := TextureRect.new()
	flash.texture = BURST_TEXTURE
	flash.custom_minimum_size = Vector2(256, 256)
	flash.size = Vector2(256, 256)
	flash.pivot_offset = flash.size * 0.5
	flash.position = center - flash.size * 0.5
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate = Color(tint.r, tint.g, tint.b, lerpf(0.5, 0.95, t))
	flash.scale = Vector2(0.25, 0.25)
	_fx.add_child(flash)

	var tween := create_tween()
	tween.set_parallel(true)
	var peak: float = lerpf(0.9, 1.6, t)
	tween.tween_property(flash, "scale", Vector2(peak, peak), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "rotation", 0.6, 0.45)
	tween.tween_property(flash, "modulate:a", 0.0, 0.45).set_delay(0.08)
	tween.chain().tween_callback(flash.queue_free)

	var sparks := CPUParticles2D.new()
	sparks.texture = SPARKLE_TEXTURE
	sparks.position = center
	sparks.emitting = false
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.lifetime = 0.7
	sparks.amount = int(lerpf(8.0, 24.0, t))
	sparks.direction = Vector2.UP
	sparks.spread = 180.0
	sparks.gravity = Vector2(0.0, 420.0)
	sparks.initial_velocity_min = 120.0
	sparks.initial_velocity_max = 340.0
	sparks.scale_amount_min = 0.12
	sparks.scale_amount_max = 0.34
	sparks.color = tint.lerp(Color.WHITE, 0.5)
	_fx.add_child(sparks)
	sparks.emitting = true
	get_tree().create_timer(sparks.lifetime + 0.3).timeout.connect(sparks.queue_free)


func _reveal_chests(sequence: int, rewards: Array[ChestReward]) -> void:
	for i in _chests.get_child_count():
		await get_tree().create_timer(CHEST_REVEAL_DELAY).timeout
		if sequence != _sequence_id or i >= _chests.get_child_count() or i >= rewards.size():
			return
		var card: Control = _chests.get_child(i)
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.8, 0.8)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(card, "modulate:a", 1.0, 0.18)
		tween.tween_property(card, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# Işık patlaması sandığın rarity renginde — legendary belirgin şekilde
		# daha parlak bir an olsun.
		_burst_at(card.global_position + card.size * 0.5, rewards[i].color(),
			_fx_level(rewards[i]))
		AudioManager.play_sfx(&"chest_open", 0.9)
		_refresh_dough()


func _refresh_dough() -> void:
	_dough.text = "Hamur: %d   ·   Koleksiyon: %d/%d" % [
		SaveManager.dough(), SaveManager.owned_skins().size(), SkinLibrary.total_count()]
