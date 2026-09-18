extends CanvasLayer
## Bonus sandık bilgi penceresi (M8.6-03B). Ana Sayfa'daki Bonus Sandık
## madalyonu açar: kural GAME_DESIGN §5.2 (her 75 merge'de level'dan
## bağımsız bir sandık) ve oyuncunun o sandığa ilerlemesi. Yalnızca
## açıklar — sandık VERMEZ, kayda YAZMAZ; tek eylem OYNA (harita akışı).
##
## M8.6-08 dar cila: production iskelet v2 (`UiKit.modal_shell`, pembe
## kurdele + OTURMUŞ X), owner sandık sanatı altın candy kuyuda (ödül rengi,
## Mağaza ürün sunumuyla aynı aile), kural metni elle satır kırmadan
## (autowrap), altın ilerleme çubuğu + sayaç, OYNA altlıkta. İlerleme
## kaynağı (`merges_since_bonus_chest`), rota ve uygunluk mantığı DEĞİŞMEDİ.
##
## NOT (M8.6-07 bulgusu, burada DÜZELTİLMEDİ): "Sandık hazır" dalı runtime'da
## erişilemez görünüyor — `SaveManager.add_merges` sayacı `pending % 75`
## olarak saklar, sandık aynı çağrıda verilir; sayaç 75'e hiç ulaşmaz. Görsel
## işte ekonomi/ödül kuralına dokunulmaz; ayrıca belgelendi.

signal play_pressed
signal closed

const CHEST_ART: Texture2D = preload("res://assets/visual/ui/chest_closed.png")
const WELL_SIZE: float = 150.0
const WELL_ART: float = 112.0

var _frame: Control
var _well: Control
var _bar: ProgressBar
var _count: Label
var _remaining: Label
var _play: Button

@onready var _dim: ColorRect = $Center/Dim
@onready var _anchor: CenterContainer = $Center/Anchor


func _ready() -> void:
	visible = false
	_frame = UiKit.modal_shell("Bonus Sandık", 560.0, &"ribbon", false, true)
	_anchor.add_child(_frame)
	var body: VBoxContainer = _frame.get_meta(&"body")
	body.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	var well_host := Control.new()
	well_host.name = "ChestHost"
	well_host.custom_minimum_size = Vector2(0, WELL_SIZE + 22.0)
	well_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(well_host)
	_well = UiKit.candy_well(CHEST_ART, UiTokens.GOLD, WELL_SIZE, WELL_ART)
	_well.name = "Well"
	_well.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_well.offset_left = -WELL_SIZE * 0.5
	_well.offset_right = WELL_SIZE * 0.5
	_well.offset_top = -(WELL_SIZE + 6.0) * 0.5
	_well.offset_bottom = (WELL_SIZE + 6.0) * 0.5
	well_host.add_child(_well)
	var rule := UiKit.label("Her %d merge'de bir bonus sandık kazanırsın — hangi level'da olduğun fark etmez."
		% ChestSystem.MERGES_PER_BONUS_CHEST, &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	rule.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
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
	var footer: VBoxContainer = _frame.get_meta(&"footer")
	_play = UiKit.cta("OYNA", "", &"ButtonCTA", "play")
	_play.name = "Play"
	_play.pressed.connect(func() -> void:
		_hide()
		play_pressed.emit())
	footer.add_child(_play)
	(_frame.get_meta(&"close_button") as Button).pressed.connect(close_info)
	UiKit.attach_dim_close(_dim, close_info)
	UiKit.modal_relayout(_frame)


## Kayıt yalnızca OKUNUR.
func open_info() -> void:
	var merges: int = int(SaveManager.data.get("merges_since_bonus_chest", 0))
	var per_chest: int = ChestSystem.MERGES_PER_BONUS_CHEST
	_bar.value = float(merges) / float(per_chest)
	_count.text = "%d/%d" % [merges, per_chest]
	var left: int = maxi(per_chest - merges, 0)
	_remaining.text = "Sandığa %d merge kaldı" % left if left > 0 else "Sandık hazır — oyna ve al!"
	visible = true
	UiKit.modal_relayout(_frame)
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


## Testler için.
func play_button() -> Button:
	return _play


func count_text() -> String:
	return _count.text


func frame() -> Control:
	return _frame
