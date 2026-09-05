extends CanvasLayer
## Round sonu ekranı (GAME_DESIGN.md §5.1):
## sonuç -> yıldızlar tek tek gecikmeli reveal -> sandık açılışı.
## Butonlar baştan aktif: kaybedince "hemen tekrar dene" şartı bunu gerektiriyor,
## oyuncu animasyonu beklemek zorunda kalmasın.

signal retry_pressed
signal exit_pressed

const STAR_REVEAL_DELAY: float = 0.4
const CHEST_REVEAL_DELAY: float = 0.5
const STAR_FILLED: String = "★"
const STAR_EMPTY: String = "☆"

var _sequence_id: int = 0

@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _stars: HBoxContainer = $Center/Panel/VBox/Stars
@onready var _detail: Label = $Center/Panel/VBox/Detail
@onready var _chests: VBoxContainer = $Center/Panel/VBox/Chests
@onready var _dough: Label = $Center/Panel/VBox/Dough
@onready var _retry: Button = $Center/Panel/VBox/Buttons/Retry
@onready var _exit: Button = $Center/Panel/VBox/Buttons/Exit


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
	await _reveal_chests(sequence)


# --- Yıldızlar ---

func _build_stars(level: LevelData, stars: int) -> void:
	for child in _stars.get_children():
		child.queue_free()
	# Sonsuz modda yıldız kavramı yok (GAME_DESIGN.md §5.1).
	_stars.visible = not level.is_endless
	if level.is_endless:
		return
	for i in 3:
		var star := Label.new()
		star.text = STAR_FILLED if i < stars else STAR_EMPTY
		star.add_theme_font_size_override("font_size", 48)
		star.modulate = Color(1.0, 0.82, 0.3) if i < stars else Color(1, 1, 1, 0.25)
		# Kazanılan yıldızlar gizli başlar, tek tek açılır.
		star.scale = Vector2.ZERO if i < stars else Vector2.ONE
		star.pivot_offset = Vector2(24.0, 32.0)
		_stars.add_child(star)


func _reveal_stars(sequence: int, stars: int) -> void:
	for i in stars:
		await get_tree().create_timer(STAR_REVEAL_DELAY).timeout
		if sequence != _sequence_id or i >= _stars.get_child_count():
			return
		var star: Label = _stars.get_child(i)
		var tween := create_tween()
		tween.tween_property(star, "scale", Vector2(1.25, 1.25), 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(star, "scale", Vector2.ONE, 0.1)
		# "Pat" sesi — stream M6'da gelecek, pitch her yıldızda biraz yükseliyor.
		AudioManager.play_sfx(null, 1.0 + 0.12 * float(i))


# --- Sandıklar ---

func _build_chests(rewards: Array[ChestReward]) -> void:
	for child in _chests.get_children():
		child.queue_free()
	for reward in rewards:
		_chests.add_child(_make_chest_card(reward))


## Placeholder sandık kartı: rarity renginde bir kutu + iki satır yazı.
func _make_chest_card(reward: ChestReward) -> Control:
	var card := PanelContainer.new()
	card.modulate = Color(1, 1, 1, 0)
	card.custom_minimum_size = Vector2(0, 72)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	var swatch := ColorRect.new()
	swatch.color = reward.color()
	swatch.custom_minimum_size = Vector2(56, 56)
	row.add_child(swatch)

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


func _reveal_chests(sequence: int) -> void:
	for i in _chests.get_child_count():
		await get_tree().create_timer(CHEST_REVEAL_DELAY).timeout
		if sequence != _sequence_id or i >= _chests.get_child_count():
			return
		var card: Control = _chests.get_child(i)
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.8, 0.8)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(card, "modulate:a", 1.0, 0.18)
		tween.tween_property(card, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		AudioManager.play_sfx(null, 0.9)
		_refresh_dough()


func _refresh_dough() -> void:
	_dough.text = "Hamur: %d   ·   Koleksiyon: %d/%d" % [
		SaveManager.dough(), SaveManager.owned_skins().size(), SkinLibrary.total_count()]
