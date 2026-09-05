extends CanvasLayer
## Level seçim ekranı. Kilitli level'lar devre dışı görünür.
## GAME_DESIGN.md §5.5'teki yol/düğüm görselleştirmesi ve unlock animasyonu
## henüz yok — bu ekran şimdilik işlevsel, görsel hâli owner asset'leriyle gelecek.

signal level_chosen(level: LevelData)
signal collection_pressed

var _levels: Array[LevelData] = []

@onready var _grid: GridContainer = $Margin/VBox/Grid
@onready var _endless_button: Button = $Margin/VBox/Endless
@onready var _collection_button: Button = $Margin/VBox/Collection
@onready var _record_label: Label = $Margin/VBox/Record


func _ready() -> void:
	_levels = LevelLibrary.load_levels()
	_endless_button.pressed.connect(_on_endless_pressed)
	_collection_button.pressed.connect(func() -> void: collection_pressed.emit())
	refresh()


func refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()

	for level in _levels:
		var button := Button.new()
		# Kazanılmış yıldızlar burada görünsün, yoksa kayıtta duran veri
		# oyuncuya hiç yansımıyor.
		var earned: int = SaveManager.stars_for_level(level.level_number)
		var star_row: String = "★".repeat(earned) + "☆".repeat(3 - earned)
		button.text = "%d\n%s" % [level.level_number, star_row]
		button.custom_minimum_size = Vector2(96.0, 96.0)
		button.disabled = not SaveManager.is_level_unlocked(level.level_number)
		button.pressed.connect(_on_level_pressed.bind(level))
		_grid.add_child(button)

	var endless_unlocked: bool = SaveManager.is_endless_unlocked(_levels.size())
	_endless_button.disabled = not endless_unlocked
	_endless_button.text = "Sonsuz Mod" if endless_unlocked else "Sonsuz Mod (Level %d'i bitir)" % _levels.size()
	_record_label.text = "Sonsuz mod rekoru: %d   ·   Hamur: %d   ·   Koleksiyon: %d/%d" % [
		SaveManager.endless_high_score(), SaveManager.dough(),
		SaveManager.owned_skins().size(), SkinLibrary.total_count()]


func _on_level_pressed(level: LevelData) -> void:
	level_chosen.emit(level)


func _on_endless_pressed() -> void:
	var endless := LevelLibrary.load_endless()
	if endless != null:
		level_chosen.emit(endless)
