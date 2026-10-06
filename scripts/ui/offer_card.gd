class_name OfferCard
extends Control
## Squishy UI System V3 (TASK/057) — teklif kartı (TASK/062 Başlangıç Paketi / Mağaza paketleri için
## temel; bu görev GERÇEK teklif, fiyat, süre, satın alma ya da hak mantığı KURMAZ — fiyat ve süre
## ÇAĞIRANIN metnidir).
##
##   [süre cipi]                         [değer etiketi]
##            ★ BAŞLANGIÇ PAKETİ ★          altın premium başlık bandı
##     (güç)(güç)(güç)(güç)  (Hamur)      ödül içeriği: sanat + adet cipi (çerçevesiz)
##           [  fiyat CTA  ]              SquishyButton (CURRENCY ya da PRIMARY)
##
## Premium durum: altın kalın halka + altın parıltı (GLOW_PREMIUM) — yalnız teklif/premium anda
## (paletin altın kuralı). Kart dokunma almaz; tek eylem fiyat CTA'sı (`price_button()`).

const WIDTH_MIN: float = 560.0
const PAD: float = 22.0
const TILE: float = 84.0
const TILE_ART: float = 70.0
const BAND_HEIGHT: float = 58.0

var _premium: bool = true
var _column: VBoxContainer
var _band: Control
var _title: Label
var _rewards: HBoxContainer
var _price: SquishyButton
var _timer: PanelContainer
var _timer_label: Label
var _value_tag: PanelContainer
var _value_label: Label
var _glow: NinePatchRect


func _init(title: String = "", price_text: String = "", premium: bool = true) -> void:
	_premium = premium
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow = UiKit.patch("popup_glow", UiTokens.GLOW_PREMIUM)
	_glow.name = "Glow"
	_glow.show_behind_parent = true
	add_child(_glow)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override("separation", UiTokens.SPACE_MD + 2)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	_band = Control.new()
	_band.name = "Band"
	_band.custom_minimum_size = Vector2(0.0, BAND_HEIGHT)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.draw.connect(_draw_band)
	_column.add_child(_band)
	_title = UiType.v3_label(title, UiType.V3_SECTION, false, HORIZONTAL_ALIGNMENT_CENTER, 27)
	_title.name = "Title"
	_title.add_theme_color_override("font_color", UiTokens.TEXT_ON_ACCENT)
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.offset_bottom = -6.0
	_band.add_child(_title)
	_rewards = HBoxContainer.new()
	_rewards.name = "Rewards"
	_rewards.alignment = BoxContainer.ALIGNMENT_CENTER
	_rewards.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_rewards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_rewards)
	_price = SquishyButton.new("", SquishyButton.Kind.PRIMARY, SquishyButton.SizeClass.NORMAL)
	_price.name = "Price"
	_price.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(_price)
	set_price_text(price_text)
	_timer = _chip(UiTokens.NAVY_PURPLE, "TimerChip")
	_timer_label = _timer.get_child(0) as Label
	_timer.visible = false
	add_child(_timer)
	_value_tag = _chip(UiTokens.ATTENTION, "ValueTag")
	_value_label = _value_tag.get_child(0) as Label
	_value_tag.visible = false
	_value_tag.rotation_degrees = 6.0
	add_child(_value_tag)
	# Metin değişince (geri sayım) cip boyu bir kare sonra kesinleşir — yerleşim onu izler.
	_timer.minimum_size_changed.connect(_place)
	_value_tag.minimum_size_changed.connect(_place)
	resized.connect(_place)
	_column.minimum_size_changed.connect(_sync_min)
	set_premium(premium)
	_sync_min()


## Ödül içeriği karosu: owner sanatı + adet cipi (düz rakam metni çağırandan, ör. "3", "500").
func add_reward(art: Texture2D, amount: String) -> Control:
	var tile := Control.new()
	tile.name = "Reward%d" % _rewards.get_child_count()
	tile.custom_minimum_size = Vector2(TILE, TILE + 14.0)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.draw.connect(func() -> void:
		UiKit.draw_candy_circle(tile, Vector2(TILE, TILE) * 0.5, TILE - 6.0, UiTokens.LAVENDER_LIGHT,
			UiTokens.NAV_SELECTED_DEEP, 4.0, 4.0, {}, Color(0, 0, 0, 0), 0.0, 0.24))
	var picture := UiKit.art(art, TILE_ART)
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.position = (Vector2(TILE, TILE) - Vector2(TILE_ART, TILE_ART)) * 0.5 - Vector2(0.0, 2.0)
	picture.size = Vector2(TILE_ART, TILE_ART)
	tile.add_child(picture)
	var chip := _chip(UiTokens.NAVY_PURPLE, "Amount")
	(chip.get_child(0) as Label).text = amount
	tile.add_child(chip)
	chip.position = Vector2(0.0, TILE - 16.0)
	var center_chip := func() -> void:
		chip.size = chip.get_combined_minimum_size()
		chip.position = Vector2((TILE - chip.size.x) * 0.5, TILE - 14.0)
	chip.minimum_size_changed.connect(center_chip)
	center_chip.call()
	_rewards.add_child(tile)
	tile.set_meta(&"amount", amount)
	return tile


func reward_count() -> int:
	return _rewards.get_child_count()


## Fiyat CTA metni (gerçek fiyat TASK/062'de; burada yalnız metin).
func set_price_text(value: String) -> void:
	_price.set_title(value)


func price_button() -> SquishyButton:
	return _price


func set_timer_text(value: String) -> void:
	_timer_label.text = value
	_timer.visible = not value.is_empty()
	_place()


func timer_text() -> String:
	return _timer_label.text if _timer.visible else ""


func set_value_tag(value: String) -> void:
	_value_label.text = value
	_value_tag.visible = not value.is_empty()
	_place()


func value_tag_text() -> String:
	return _value_label.text if _value_tag.visible else ""


func set_premium(value: bool) -> void:
	_premium = value
	_glow.visible = value
	_title.add_theme_color_override("font_color", UiTokens.TEXT_ON_ACCENT if value else UiTokens.TEXT_ON_DARK)
	queue_redraw()
	_band.queue_redraw()


func is_premium() -> bool:
	return _premium


func title_text() -> String:
	return _title.text


func set_title(value: String) -> void:
	_title.text = value


## Kaydırılan içerikte (Mağaza, M8.6-06.3 kuralı): fiyat CTA'sı PASS.
func set_scrollable(value: bool) -> void:
	_price.set_scrollable(value)


func _chip(color: Color, chip_name: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = chip_name
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", UiKit.v3_chip(color, 2))
	var label := UiType.v3_label("", UiType.V3_BADGE, true, HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_color_override("font_color", UiTokens.TEXT_ON_DARK)
	chip.add_child(label)
	return chip


func _sync_min() -> void:
	var inner: Vector2 = _column.get_combined_minimum_size()
	custom_minimum_size = Vector2(maxf(WIDTH_MIN, inner.x + PAD * 2.0), inner.y + PAD * 2.0 + UiTokens.LIP_CARD)
	_place()


func _place() -> void:
	_column.position = Vector2(PAD, PAD)
	_column.size = Vector2(maxf(size.x - PAD * 2.0, 0.0), maxf(size.y - PAD * 2.0 - UiTokens.LIP_CARD, 0.0))
	_glow.position = Vector2(-60.0, -50.0)
	_glow.size = size + Vector2(120.0, 100.0)
	if _timer != null:
		_timer.size = _timer.get_combined_minimum_size()
		_timer.position = Vector2(18.0, -_timer.size.y * 0.5)
	if _value_tag != null:
		_value_tag.size = _value_tag.get_combined_minimum_size()
		_value_tag.position = Vector2(size.x - _value_tag.size.x - 12.0, -_value_tag.size.y * 0.55)


func _draw() -> void:
	var rim: Color = UiTokens.BORDER_COLOR_PREMIUM if _premium else UiTokens.LAVENDER_LIGHT
	var rim_w: float = float(UiTokens.BORDER_PREMIUM if _premium else UiTokens.BORDER_STANDARD)
	UiKit.draw_candy(self, Rect2(Vector2.ZERO, size), UiTokens.SURFACE_ELEVATED, UiTokens.SURFACE_NEUTRAL_DEEP,
		UiTokens.RADIUS_FEATURE, UiTokens.LIP_CARD, UiTokens.LIP_CARD, UiTokens.DEPTH_FLOATING, rim, rim_w,
		UiTokens.GLOSS_ALPHA * 0.5)


func _draw_band() -> void:
	var face: Color = UiTokens.ROLE_PREMIUM if _premium else UiTokens.ROLE_SECONDARY
	var deep: Color = UiTokens.ROLE_PREMIUM_DEEP if _premium else UiTokens.ROLE_SECONDARY_DEEP
	UiKit.draw_candy(_band, Rect2(Vector2.ZERO, _band.size), face, deep, UiTokens.RADIUS_CONTROL, 5.0, 5.0,
		{}, Color(1, 1, 1, 0.7), 2.0)
