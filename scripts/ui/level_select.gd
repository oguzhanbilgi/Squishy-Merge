extends CanvasLayer
## Harita sekmesi: level seçim ekranı. Kilitli level'lar devre dışı görünür.
## Koleksiyon butonu M8'de alt sekme çubuğuna taşındı.
## GAME_DESIGN.md §5.5'teki yol/düğüm görselleştirmesi ve unlock animasyonu
## henüz yok — bu ekran şimdilik işlevsel, görsel hâli owner asset'leriyle gelecek.

signal level_chosen(level: LevelData)

## Kilitli level düğümündeki kilit rozeti. 96x96'lık butonda köşeye sığacak
## kadar küçük, yazının üstüne binmeyecek kadar kenarda.
const LOCK_BADGE_SIZE: Vector2 = Vector2(30.0, 37.0)
const LOCK_BADGE_INSET: float = 5.0

var _levels: Array[LevelData] = []

@onready var _grid: GridContainer = $Margin/VBox/Grid
@onready var _endless_button: Button = $Margin/VBox/Endless
@onready var _record_label: RichTextLabel = $Margin/VBox/Record


func _ready() -> void:
	_levels = LevelLibrary.load_levels()
	_endless_button.pressed.connect(_on_endless_pressed)
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
		if button.disabled:
			_add_lock_badge(button)
		_grid.add_child(button)

	var endless_unlocked: bool = SaveManager.is_endless_unlocked(_levels.size())
	_endless_button.disabled = not endless_unlocked
	_endless_button.text = "Sonsuz Mod" if endless_unlocked else "Sonsuz Mod (Level %d'i bitir)" % _levels.size()
	_record_label.text = "[center]Sonsuz mod rekoru: %d   ·   %s   ·   Koleksiyon: %d/%d\n%s[/center]" % [
		SaveManager.endless_high_score(),
		UiIcons.labelled(UiIcons.DOUGH, "Hamur: %d" % SaveManager.dough()),
		SaveManager.owned_skins().size(), SkinLibrary.total_count(),
		UiIcons.labelled(UiIcons.FLAME,
			"Günlük seri: %d gün" % SaveManager.daily_streak())]


## Kilitli level düğümünün sağ-üst köşesine küçük kilit rozeti.
##
## Butonun kendi `icon` özelliği kullanılmadı: ikon yazıyla aynı akışa girip
## "10 / ☆☆☆" düzenini bozuyordu. Köşeye oturan ayrı bir katman hem yazıya
## dokunmuyor hem koleksiyon kartlarındaki kilit rozetiyle aynı dili konuşuyor.
func _add_lock_badge(button: Button) -> void:
	var badge := TextureRect.new()
	badge.texture = UiIcons.LOCK
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -LOCK_BADGE_SIZE.x - LOCK_BADGE_INSET
	badge.offset_top = LOCK_BADGE_INSET
	badge.offset_right = -LOCK_BADGE_INSET
	badge.offset_bottom = LOCK_BADGE_SIZE.y + LOCK_BADGE_INSET
	button.add_child(badge)


func _on_level_pressed(level: LevelData) -> void:
	level_chosen.emit(level)


func _on_endless_pressed() -> void:
	var endless := LevelLibrary.load_endless()
	if endless != null:
		level_chosen.emit(endless)
