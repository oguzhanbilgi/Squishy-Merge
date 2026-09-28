class_name TitleRow
extends Button
## Unvan seçici satırı (TASK/045): candy kart satırı — solda unvanı açan başarımın
## rozeti (varsayılan unvanda tier 1 Squishy), ortada unvan adı (Baloo) + durum
## satırı, sağda seçim işareti.
##
##   SEÇİLİ   altın kenar + altın tik diski, "SEÇİLİ UNVAN".
##   AÇIK     lavanta kenar, boş halka; dokunmak seçer (TitleSelector yazar).
##   KİLİTLİ  soluk gövde + kilit; PASİF (dokunulamaz) — kaynak başarımın koşulu
##            yazılı ("Kilitli · Toplam 1000 birleşme yap."; rozet o başarımın rozeti).
##
## `MOUSE_FILTER_PASS`: pencere kaydırması satırın üstünden de başlar; kaydırma
## başlayınca basış görseli bırakılır (Koleksiyon kartı deseni).

const HEIGHT: float = 92.0
## Alt pay 24: `card_bevel_soft` pişmiş dudağı (TASK/044 ölçümü).
const BODY_MARGIN: Vector4 = Vector4(14, 10, 16, 24)
const BADGE_SIZE: float = 60.0
const MARK_SIZE: float = 40.0
const SELECTED_TEXT: String = "SEÇİLİ UNVAN"
const DEFAULT_TEXT: String = "Her zaman açık"
const OPEN_FORMAT: String = "Açıldı · %s"
const LOCKED_FORMAT: String = "Kilitli · %s"

var _title_id: StringName = &""
var _row: Dictionary = {}
var _rim: PanelContainer
var _body: PanelContainer
var _badge: AchievementBadge
var _name: Label
var _status: Label
var _mark_host: Control
var _mark_disc: PanelContainer
var _mark_icon: TextureRect


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(0, HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	var shadow := UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.22))
	UiKit.inset(shadow, -10.0, -4.0, -10.0, -16.0)
	add_child(shadow)
	_rim = UiKit.flat_plate("frame_round20", Color.WHITE)
	_rim.self_modulate = UiTokens.LAVENDER_LIGHT
	UiKit.inset(_rim, -4.0, -4.0, -4.0, -4.0)
	add_child(_rim)
	_body = UiKit.panel(&"PanelCollectionCard")
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.add_theme_stylebox_override("panel", UiKit.style("card_bevel_soft", UiTokens.CREAM, BODY_MARGIN))
	add_child(_body)
	UiKit.card_face(_body, BODY_MARGIN)
	_body.minimum_size_changed.connect(func() -> void:
		custom_minimum_size.y = maxf(HEIGHT, _body.get_combined_minimum_size().y))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	_body.add_child(row)
	_badge = AchievementBadge.new(BADGE_SIZE)
	row.add_child(_badge)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_name = UiKit.label("", &"LabelSection")
	_name.name = "TitleName"
	_name.add_theme_font_size_override("font_size", 22)
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_name)
	_status = UiKit.label("", &"LabelCaption")
	_status.name = "Status"
	_status.add_theme_font_size_override("font_size", 15)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_mark_host = Control.new()
	_mark_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark_host.custom_minimum_size = Vector2(MARK_SIZE, MARK_SIZE)
	_mark_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_mark_host)
	_mark_disc = PanelContainer.new()
	_mark_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark_disc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mark_host.add_child(_mark_disc)
	_mark_icon = UiKit.icon("check", MARK_SIZE * 0.6, UiTokens.TEXT_ON_ACCENT)
	_mark_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_mark_icon.offset_left = -MARK_SIZE * 0.3
	_mark_icon.offset_right = MARK_SIZE * 0.3
	_mark_icon.offset_top = -MARK_SIZE * 0.3 - 1.0
	_mark_icon.offset_bottom = MARK_SIZE * 0.3 - 1.0
	_mark_host.add_child(_mark_icon)
	UiMotion.attach_press(self)


## `row`: PlayerProfile.title_rows() öğesi.
func setup(row: Dictionary) -> void:
	_row = row
	_title_id = row.get("id", &"")
	name = "Title_%s" % String(_title_id)
	var unlocked: bool = bool(row.get("unlocked", false))
	var selected: bool = bool(row.get("selected", false))
	var source: StringName = row.get("source_id", &"")
	_badge.setup(source, unlocked)
	_name.text = String(row.get("name", ""))
	disabled = not unlocked
	if selected:
		_status.text = SELECTED_TEXT
	elif source == &"":
		_status.text = DEFAULT_TEXT
	elif unlocked:
		_status.text = OPEN_FORMAT % String(row.get("source_name", ""))
	else:
		_status.text = LOCKED_FORMAT % String(row.get("source_description", ""))
	_status.add_theme_color_override("font_color", UiTokens.GOLD_DEEP if selected
		else (UiTokens.TEXT_SECONDARY if unlocked else UiTokens.TEXT_TERTIARY))
	_name.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY if unlocked else UiTokens.DISABLED_DEEP)
	_rim.self_modulate = UiTokens.GOLD if selected else UiTokens.LAVENDER_LIGHT
	_body.add_theme_stylebox_override("panel", UiKit.style("card_bevel_soft",
		UiTokens.CREAM if unlocked else UiTokens.CREAM_DEEP, BODY_MARGIN))
	if selected:
		_mark_disc.add_theme_stylebox_override("panel", UiKit.style("btn_circle_flat", UiTokens.GOLD))
		_mark_icon.texture = UiKit.icon_texture("check")
		_mark_icon.self_modulate = UiTokens.TEXT_ON_ACCENT
		_mark_icon.visible = true
	elif unlocked:
		_mark_disc.add_theme_stylebox_override("panel", UiKit.style("btn_circle_flat", UiTokens.LAVENDER_SURFACE))
		_mark_icon.visible = false
	else:
		_mark_disc.add_theme_stylebox_override("panel", UiKit.style("btn_circle_flat", Color(UiTokens.DISABLED, 0.55)))
		_mark_icon.texture = UiKit.icon_texture("lock")
		_mark_icon.self_modulate = UiTokens.TEXT_ON_DARK
		_mark_icon.visible = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCROLL_BEGIN:
		UiMotion.release(self)


# --- Testler / çekim aracı ----------------------------------------------------

func title_id() -> StringName:
	return _title_id


func name_text() -> String:
	return _name.text


func status_text() -> String:
	return _status.text


func is_selected_shown() -> bool:
	return bool(_row.get("selected", false))


func badge() -> AchievementBadge:
	return _badge
