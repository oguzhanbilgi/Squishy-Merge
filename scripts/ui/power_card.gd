class_name PowerCard
extends Control
## Squishy UI System V3 (TASK/057) — güç kartı görsel primitifi (TASK/060 Gameplay HUD V3 + Ödüllü
## Güçler için temel; bu görev yalnız görünümü kurar — günlük reklam kotası, stok değişimi, ödül
## YOK).
##
##   ┌──────────────┐
##   │   (güç)   ③  │  büyük owner güç sanatı, vurgu renginde candy kuyu; stok SADECE rakam
##   │    BOMBA     │  ("x3" / "stok x3" YOK — Product Vision V3 §3)
##   │ [▶ REKLAM 0/2]│  isteğe bağlı ödüllü reklam CTA yuvası (SquishyButton REWARDED_AD COMPACT)
##   └──────────────┘
##
## Krem V3 yüzey (yükseltilmiş kart derinliği); seçili = kalın beyaz-altın halka; stok 0 = rakam
## soluk lavanta-gri (güç yine görünür). Kart kendisi dokunma almaz (yuvalar ayrı kontroller).

const WIDTH: float = 200.0
const WELL: float = 112.0
const ART: float = 92.0
const STOCK_SIZE: float = 46.0
const PAD: float = 14.0
const AD_TEXT: String = "REKLAM İZLE"

var _type: PowerUp.Type = PowerUp.Type.BOMB
var _stock: int = 0
var _selected: bool = false
var _column: VBoxContainer
var _well: Control
var _stock_bubble: Control
var _stock_label: Label
var _name: Label
var _ad: SquishyButton


func _init(type: int = PowerUp.Type.BOMB, stock: int = 0, with_ad: bool = true) -> void:
	_type = type as PowerUp.Type
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	var well_holder := Control.new()
	well_holder.name = "WellHolder"
	well_holder.custom_minimum_size = Vector2(WELL, WELL + 6.0)
	well_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	well_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(well_holder)
	_well = UiKit.candy_well(PowerUp.icon(_type), PowerUp.accent(_type), WELL, ART)
	_well.name = "Well"
	well_holder.add_child(_well)
	_stock_bubble = Control.new()
	_stock_bubble.name = "Stock"
	_stock_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stock_bubble.size = Vector2(STOCK_SIZE, STOCK_SIZE)
	_stock_bubble.position = Vector2(WELL - STOCK_SIZE * 0.62, -STOCK_SIZE * 0.22)
	_stock_bubble.draw.connect(_draw_stock)
	well_holder.add_child(_stock_bubble)
	_stock_label = UiType.v3_label("0", UiType.V3_BUTTON, true, HORIZONTAL_ALIGNMENT_CENTER, 28)
	_stock_label.name = "Count"
	_stock_label.position = Vector2(0.0, -3.0)
	_stock_label.size = Vector2(STOCK_SIZE, STOCK_SIZE)
	_stock_bubble.add_child(_stock_label)
	_name = UiType.v3_label(UiType.upper_tr(PowerUp.display_name(_type)), UiType.V3_CARD_TITLE, false,
		HORIZONTAL_ALIGNMENT_CENTER)
	_name.name = "Name"
	_column.add_child(_name)
	if with_ad:
		_ad = SquishyButton.new(AD_TEXT, SquishyButton.Kind.REWARDED_AD, SquishyButton.SizeClass.COMPACT)
		_ad.name = "AdCta"
		_ad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		# Kota / sayaç ÇAĞIRANDAN (reklam düğmesinin ilerleme API'si): bileşen hiçbir günlük kota
		# varsaymaz (GAME_DESIGN §5.7.3 bugün 1/gün dört güç toplamı; güç başına kota TASK/060 + owner kararı).
		_column.add_child(_ad)
	set_stock(stock)
	resized.connect(_place)
	_column.minimum_size_changed.connect(_sync_min)
	_sync_min()


func set_stock(value: int) -> void:
	_stock = maxi(value, 0)
	_stock_label.text = str(_stock)
	_stock_label.add_theme_color_override("font_color", UiTokens.TEXT_ON_DARK if _stock > 0 else UiTokens.TEXT_DISABLED)
	_stock_bubble.queue_redraw()


func stock() -> int:
	return _stock


func stock_text() -> String:
	return _stock_label.text


func name_text() -> String:
	return _name.text


func power_type() -> PowerUp.Type:
	return _type


## Ödüllü reklam CTA yuvası (with_ad = false ise null).
func ad_button() -> SquishyButton:
	return _ad


func set_selected(value: bool) -> void:
	_selected = value
	queue_redraw()


## Kaydırılan içerikte: reklam CTA'sı PASS (M8.6-06.3 kuralı).
func set_scrollable(value: bool) -> void:
	if _ad != null:
		_ad.set_scrollable(value)


func is_selected() -> bool:
	return _selected


func _sync_min() -> void:
	var inner: Vector2 = _column.get_combined_minimum_size()
	custom_minimum_size = Vector2(maxf(WIDTH, inner.x + PAD * 2.0), inner.y + PAD * 2.0 + UiTokens.LIP_CARD)
	_place()


func _place() -> void:
	_column.position = Vector2(PAD, PAD)
	_column.size = Vector2(maxf(size.x - PAD * 2.0, 0.0), maxf(size.y - PAD * 2.0 - UiTokens.LIP_CARD, 0.0))


func _draw() -> void:
	var rim: Color = UiTokens.LAVENDER_LIGHT
	var rim_w: float = float(UiTokens.BORDER_STANDARD)
	if _selected:
		rim = UiTokens.BORDER_COLOR_SELECTED
		rim_w = float(UiTokens.BORDER_SELECTED) + 1.0
	UiKit.draw_candy(self, Rect2(Vector2.ZERO, size), UiTokens.SURFACE_ELEVATED, UiTokens.SURFACE_NEUTRAL_DEEP,
		UiTokens.RADIUS_FEATURE, UiTokens.LIP_CARD, UiTokens.LIP_CARD, UiTokens.DEPTH_ELEVATED, rim, rim_w,
		UiTokens.GLOSS_ALPHA * 0.6)


func _draw_stock() -> void:
	var color: Color = UiTokens.NAVY_PURPLE if _stock > 0 else UiTokens.ROLE_DISABLED
	UiKit.draw_candy_circle(_stock_bubble, Vector2(STOCK_SIZE, STOCK_SIZE) * 0.5 - Vector2(0.0, 1.0),
		STOCK_SIZE - 4.0, color, color.darkened(0.35), 3.0, 3.0, UiTokens.DEPTH_RESTING, Color.WHITE, 3.0, 0.22)
