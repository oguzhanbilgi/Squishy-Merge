extends CanvasLayer
## Koleksiyon sekmesi (GAME_DESIGN.md §5.3): grid, kaç skin'den kaçı açıldı,
## açılmamışlar silüet. Skin listesi SkinLibrary'den geliyor — yeni .tres
## eklemek yeterli, bu ekran kod değişmeden büyür.

const COLUMNS: int = 4
const CARD_SIZE: Vector2 = Vector2(140.0, 150.0)

@onready var _grid: GridContainer = $Margin/VBox/Scroll/Grid
@onready var _progress: RichTextLabel = $Margin/VBox/Progress


func _ready() -> void:
	_grid.columns = COLUMNS
	refresh()


func refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()

	var owned_count: int = 0
	for skin in SkinLibrary.all():
		var owned: bool = SaveManager.owns_skin(skin.id)
		if owned:
			owned_count += 1
		_grid.add_child(_make_card(skin, owned))

	_progress.text = "[center]Koleksiyon: %d/%d   ·   %s[/center]" % [
		owned_count, SkinLibrary.total_count(),
		UiIcons.labelled(UiIcons.DOUGH, "Hamur: %d" % SaveManager.dough())]


func _make_card(skin: SkinData, owned: bool) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 6)

	# Açık skin: tint'inde bir daire (hâlâ placeholder). Kapalı skin: owner'ın
	# silüet görseli — tint uygulanmıyor, görselin kendi rengi var.
	var swatch := SkinSwatch.new()
	swatch.custom_minimum_size = Vector2(88.0, 88.0)
	swatch.setup(skin.tint, SkinData.rarity_color(skin.rarity), owned)
	card.add_child(swatch)

	var name_label := Label.new()
	name_label.text = skin.display_name if owned else "???"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.modulate = Color.WHITE if owned else Color(1, 1, 1, 0.45)
	card.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.text = SkinData.rarity_name(skin.rarity)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 12)
	rarity_label.modulate = SkinData.rarity_color(skin.rarity)
	if not owned:
		rarity_label.modulate.a = 0.4
	card.add_child(rarity_label)

	return card
