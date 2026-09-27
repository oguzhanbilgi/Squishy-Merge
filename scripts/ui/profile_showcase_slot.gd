class_name ProfileShowcaseSlot
extends Button
## Profil vitrini yuvası (TASK/044). Üç yuva bu TEK bileşenden; Koleksiyon
## kartıyla aynı malzeme ailesi (krem `card_bevel_soft` gövde, açık halka, erik
## gölge, kart yüzü).
##
##   DOLU  üstte yuva rozeti (ilk yuva altın "AVATAR", diğerleri lavanta
##         "2. YUVA" / "3. YUVA") → küçük `CollectibleStage` (rarity halesi +
##         kaide + nefes alan sanat) → Baloo ad → rarity etiketi.
##   BOŞ   buzlu lavanta gövde → açık lavanta kuyuda "+" → "BOŞ YUVA" →
##         "Koleksiyondan ekle".
##
## Dokunma yalnız `pressed` yayar; ekran rotayı seçer (dolu → Koleksiyon'da o
## parçanın detayı, boş → Koleksiyon). Kayda YAZMAZ. Gameplay'e etkisi YOK.
## `MOUSE_FILTER_PASS`: profil kaydırması yuvanın üstünden de başlar.

const SIZE: Vector2 = Vector2(216.0, 262.0)
## Alt pay 24: pişmiş dudak alt kenardan 11–22 px yukarıda (TASK/044 incelemesi).
const BODY_MARGIN: Vector4 = Vector4(10, 10, 10, 24)
const STAGE_SIZE: Vector2 = Vector2(150.0, 142.0)
const NAME_FONT_SIZE: int = 18
const AVATAR_TEXT: String = "AVATAR"
const SLOT_TEXT: String = "%d. YUVA"
const EMPTY_TITLE: String = "BOŞ YUVA"
const EMPTY_NOTE: String = "Koleksiyondan ekle"
const WELL_SIZE: float = 88.0
## Gövde tonları (tema `PanelCollectionCard` / `...Locked` ile aynı); iç pay
## BODY_MARGIN ile GERÇEKTEN uygulanır — içerik alt dudağa binmez.
const BODY_TINT: Color = UiTokens.CREAM
const BODY_TINT_EMPTY: Color = Color("f1e9dc")

var _slot: int = 0
var _entry: SkinEntry = null
var _rim: PanelContainer
var _body: PanelContainer
var _badge: PanelContainer
var _badge_label: Label
var _filled: VBoxContainer
var _stage: CollectibleStage
var _name_label: Label
var _tag_slot: Control
var _tag: PanelContainer
var _empty: VBoxContainer


func _init(slot: int = 0) -> void:
	_slot = slot
	name = "Slot%d" % (slot + 1)
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = SIZE
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	var shadow := UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.32))
	UiKit.inset(shadow, -12.0, -4.0, -12.0, -20.0)
	add_child(shadow)
	# Beyaz plaka + self_modulate: rarity rengi TEK kez uygulanır (Koleksiyon kartı gibi).
	_rim = UiKit.flat_plate("frame_round20", Color.WHITE)
	_rim.self_modulate = UiTokens.LAVENDER_LIGHT
	UiKit.inset(_rim, -4.0, -4.0, -4.0, -4.0)
	add_child(_rim)
	var contour := UiKit.flat_plate("frame_round20", Color(UiTokens.LAVENDER_DEEP, 0.5))
	UiKit.inset(contour, -2.0, -2.0, -2.0, -2.0)
	add_child(contour)
	_body = UiKit.panel(&"PanelCollectionCard")
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_body)
	UiKit.card_face(_body, BODY_MARGIN)
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(host)
	_build_filled(host)
	_build_empty(host)
	_build_badge()
	UiMotion.attach_press(self)


func _build_filled(host: Control) -> void:
	_filled = VBoxContainer.new()
	_filled.name = "Filled"
	_filled.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filled.set_anchors_preset(Control.PRESET_FULL_RECT)
	_filled.alignment = BoxContainer.ALIGNMENT_END
	_filled.add_theme_constant_override("separation", 2)
	host.add_child(_filled)
	var stage_host := Control.new()
	stage_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_host.custom_minimum_size = Vector2(0, STAGE_SIZE.y + 4.0)
	_filled.add_child(stage_host)
	_stage = CollectibleStage.new(false, true)
	_stage.name = "Stage"
	_stage.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_stage.offset_left = -STAGE_SIZE.x * 0.5
	_stage.offset_right = STAGE_SIZE.x * 0.5
	_stage.offset_top = -STAGE_SIZE.y
	_stage.offset_bottom = 0.0
	stage_host.add_child(_stage)
	_name_label = UiKit.label("", &"LabelSection", HORIZONTAL_ALIGNMENT_CENTER)
	_name_label.name = "Name"
	_name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_filled.add_child(_name_label)
	var tag_row := HBoxContainer.new()
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_filled.add_child(tag_row)
	_tag_slot = Control.new()
	_tag_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_row.add_child(_tag_slot)


func _build_empty(host: Control) -> void:
	_empty = VBoxContainer.new()
	_empty.name = "Empty"
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty.add_theme_constant_override("separation", 6)
	host.add_child(_empty)
	var well_host := Control.new()
	well_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well_host.custom_minimum_size = Vector2(0, WELL_SIZE + 10.0)
	_empty.add_child(well_host)
	var ring := UiKit.patch("btn_circle_flat", Color(UiTokens.LAVENDER_DEEP, 0.30))
	ring.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ring.offset_left = -WELL_SIZE * 0.5 - 4.0
	ring.offset_right = WELL_SIZE * 0.5 + 4.0
	ring.offset_top = -WELL_SIZE * 0.5 - 4.0
	ring.offset_bottom = WELL_SIZE * 0.5 + 4.0
	well_host.add_child(ring)
	var well := UiKit.patch("item_circle_inner", UiTokens.LAVENDER_LIGHT)
	well.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	well.offset_left = -WELL_SIZE * 0.5
	well.offset_right = WELL_SIZE * 0.5
	well.offset_top = -WELL_SIZE * 0.5
	well.offset_bottom = WELL_SIZE * 0.5
	well_host.add_child(well)
	var plus := UiKit.icon("plus", 40, UiTokens.LAVENDER_DEEP)
	plus.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	plus.offset_left = -20.0
	plus.offset_right = 20.0
	plus.offset_top = -20.0
	plus.offset_bottom = 20.0
	well_host.add_child(plus)
	var title := UiKit.label(EMPTY_TITLE, &"LabelSection", HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_empty.add_child(title)
	var note := UiKit.label(EMPTY_NOTE, &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", UiTokens.TEXT_TERTIARY)
	_empty.add_child(note)


## Yuva rozeti: kartın üst kenarına oturan küçük plaka (ilk yuva altın AVATAR).
func _build_badge() -> void:
	_badge = PanelContainer.new()
	_badge.name = "SlotBadge"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_theme_stylebox_override("panel", UiKit.style("frame_round20",
		UiTokens.GOLD if _slot == 0 else UiTokens.LAVENDER_SURFACE, Vector4(12, 2, 12, 4)))
	_badge_label = UiKit.label(AVATAR_TEXT if _slot == 0 else SLOT_TEXT % (_slot + 1),
		&"LabelBadge", HORIZONTAL_ALIGNMENT_CENTER)
	_badge_label.add_theme_font_size_override("font_size", 14)
	_badge_label.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	_badge.add_child(_badge_label)
	add_child(_badge)
	_badge.minimum_size_changed.connect(_layout_badge)
	resized.connect(_layout_badge)
	_layout_badge()


func _layout_badge() -> void:
	var min: Vector2 = _badge.get_combined_minimum_size()
	_badge.size = min
	_badge.position = Vector2((size.x - min.x) * 0.5, -min.y * 0.45)


## Yuvayı doldurur (null = boş yuva).
func set_entry(entry: SkinEntry) -> void:
	_entry = entry
	var filled: bool = entry != null and not entry.is_default()
	_filled.visible = filled
	_empty.visible = not filled
	_badge.visible = filled
	_body.theme_type_variation = &"PanelCollectionCard" if filled else &"PanelCollectionCardLocked"
	_body.add_theme_stylebox_override("panel", UiKit.style("card_bevel_soft",
		BODY_TINT if filled else BODY_TINT_EMPTY.lerp(UiTokens.LAVENDER_SURFACE, 0.38), BODY_MARGIN))
	if not filled:
		_rim.self_modulate = UiTokens.LAVENDER_LIGHT
		return
	_stage.setup(entry, true)
	_name_label.text = entry.display_name
	if _tag != null:
		_tag_slot.remove_child(_tag)
		_tag.queue_free()
	_tag = UiKit.rarity_tag(int(entry.rarity))
	(_tag.get_meta(&"title_label") as Label).add_theme_font_size_override("font_size", 14)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag_slot.add_child(_tag)
	_tag_slot.custom_minimum_size = _tag.get_combined_minimum_size()
	_tag.size = _tag_slot.custom_minimum_size
	match int(entry.rarity):
		SkinData.Rarity.RARE: _rim.self_modulate = UiTokens.RARITY_RARE.lerp(Color.WHITE, 0.25)
		SkinData.Rarity.EPIC: _rim.self_modulate = UiTokens.RARITY_EPIC.lerp(Color.WHITE, 0.22)
		SkinData.Rarity.LEGENDARY: _rim.self_modulate = UiTokens.GOLD
		_: _rim.self_modulate = UiTokens.LAVENDER_LIGHT


## ScrollContainer sürüklemeye başladı: basış ölçeğini bırak (Koleksiyon kartı).
func _notification(what: int) -> void:
	if what == NOTIFICATION_SCROLL_BEGIN:
		UiMotion.release(self)


# --- Testler / çekim aracı ----------------------------------------------------

func slot() -> int:
	return _slot


func entry() -> SkinEntry:
	return _entry


func is_filled() -> bool:
	return _filled.visible


func name_text() -> String:
	return _name_label.text if _filled.visible else ""


func badge_text() -> String:
	return _badge_label.text


func stage() -> CollectibleStage:
	return _stage
