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
## Ödül görseli kendi dosyasında: sandık + rarity katmanları
## (scripts/ui/reward_gem.gd).
const REWARD_GEM := preload("res://scripts/ui/reward_gem.gd")

## Kart belirdikten kaç saniye sonra sandık açılıyor. Kapalı sandığın bir an
## görünmesi gerekiyor, yoksa "açılış" okunmuyor.
const CHEST_OPEN_DELAY: float = 0.35
## Kaynak sprite 64x60; kutu bu oranda tutuluyor ki yıldız ezilmesin.
const STAR_SIZE: Vector2 = Vector2(64.0, 60.0)

var _sequence_id: int = 0
## Kartlarla aynı sıradaki ödül görselleri — reveal sırasında open() için.
var _gems: Array[Control] = []

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
	_gems.clear()
	for reward in rewards:
		_chests.add_child(_make_chest_card(reward))


## Sandık kartı: rarity'e göre katmanlı ödül görseli + iki satır yazı.
func _make_chest_card(reward: ChestReward) -> Control:
	var card := PanelContainer.new()
	# Diyalog paneli (başlık çubuklu, kalın üst payı olan) liste öğesi olarak
	# yanlış duruyor; kart kendi sade stilini kullanıyor.
	card.theme_type_variation = &"CardPanel"
	card.modulate = Color(1, 1, 1, 0)
	# Sandık görseli 80 px; kart ona göre büyüdü (eskiden 72).
	card.custom_minimum_size = Vector2(0, 88)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	var gem: Control = REWARD_GEM.new()
	row.add_child(gem)
	gem.setup(reward)
	_gems.append(gem)

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
		# Kapalı sandık bir an görünsün, sonra açılsın.
		await get_tree().create_timer(CHEST_OPEN_DELAY).timeout
		if sequence != _sequence_id or i >= _gems.size():
			return
		_gems[i].open()
		_burst_at(card.global_position + card.size * 0.5, rewards[i].color(),
			REWARD_GEM.fx_level(rewards[i]))
		AudioManager.play_sfx(&"chest_open", 0.9)
		_refresh_dough()


func _refresh_dough() -> void:
	_dough.text = "Hamur: %d   ·   Koleksiyon: %d/%d" % [
		SaveManager.dough(), SaveManager.owned_skins().size(), SkinLibrary.total_count()]
