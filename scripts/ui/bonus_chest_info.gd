extends CanvasLayer
## Bonus sandık bilgi penceresi (M8.6-03B). Ana Sayfa'daki Bonus Sandık
## madalyonu açar: kural GAME_DESIGN §5.2 (her 75 merge'de level'dan
## bağımsız bir sandık) ve oyuncunun o sandığa ilerlemesi. Yalnızca
## açıklar — sandık VERMEZ, kayda YAZMAZ; tek eylem OYNA (harita akışı).
##
## Production iskelet: `UiKit.modal_frame` (kurdele + krem gövde + kapat),
## owner sandık sanatı, altın ilerleme çubuğu (ödül rengi), ButtonCTA.

signal play_pressed
signal closed

const CHEST_ART: Texture2D = preload("res://assets/visual/ui/chest_closed.png")

var _frame: Control
var _bar: ProgressBar
var _count: Label
var _remaining: Label
var _play: Button

@onready var _dim: ColorRect = $Center/Dim
@onready var _anchor: CenterContainer = $Center/Anchor


func _ready() -> void:
	visible = false
	_frame = UiKit.modal_frame("Bonus Sandık", 560.0)
	_anchor.add_child(_frame)
	var body: VBoxContainer = _frame.get_meta(&"body")
	body.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	var chest := UiKit.art(CHEST_ART, 132)
	chest.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	chest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(chest)
	var rule := UiKit.label("Her %d merge'de bir bonus sandık kazanırsın —\nhangi level'da olduğun fark etmez."
		% ChestSystem.MERGES_PER_BONUS_CHEST, &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(rule)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(bar_row)
	_bar = UiKit.progress_bar(0.0, &"ProgressBarGold", 22.0)
	bar_row.add_child(_bar)
	_count = UiKit.label("0/%d" % ChestSystem.MERGES_PER_BONUS_CHEST, &"LabelStat")
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(_count)
	_remaining = UiKit.label("", &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(_remaining)
	_play = UiKit.cta("OYNA", "", &"ButtonCTA", "play")
	_play.pressed.connect(func() -> void:
		_hide()
		play_pressed.emit())
	body.add_child(_play)
	(_frame.get_meta(&"close_button") as Button).pressed.connect(close_info)
	_dim.gui_input.connect(_on_dim_input)


## Kayıt yalnızca OKUNUR.
func open_info() -> void:
	var merges: int = int(SaveManager.data.get("merges_since_bonus_chest", 0))
	var per_chest: int = ChestSystem.MERGES_PER_BONUS_CHEST
	_bar.value = float(merges) / float(per_chest)
	_count.text = "%d/%d" % [merges, per_chest]
	var left: int = maxi(per_chest - merges, 0)
	_remaining.text = "Sandığa %d merge kaldı" % left if left > 0 else "Sandık hazır — oyna ve al!"
	visible = true
	UiMotion.modal_open(_frame, _dim)
	AudioManager.play(&"ui_modal_open")


func close_info() -> void:
	if not visible:
		return
	_hide()
	AudioManager.play(&"ui_modal_close")
	closed.emit()


func _hide() -> void:
	visible = false


func _on_dim_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null and not touch.pressed:
		close_info()


## Testler için.
func play_button() -> Button:
	return _play


func count_text() -> String:
	return _count.text
