class_name FeatureTile
extends Button
## Squishy UI System V3 — kompakt oyun özelliği karosu (TASK/058, owner kararı K10 "TEXT-LIGHT / ICON-FIRST"). İlk
## üretim tüketicisi: Ana Sayfa'nın yan yana GÜNLÜK | MEYDAN karoları. Yazı yerine görsel dil:
##
##   ( candy ikon kuyusu )  TEK KELİME           [!]
##                          [ikon sayı] [ödül]
##
## İKON + TEK KELİME + SAYI / ROZET / DURUM: açıklayıcı alt yazı, › ve ikinci çerçeveli panel YOK. Durum cipleri
## (`set_chips`) ÇAĞIRANDAN gelir — bileşen ekonomi / gün bilmez. Karonun TAMAMI tek dokunma hedefi (ikon kuyusu,
## kelime, cipler fare almaz; isabet butonun dikdörtgeni — en az TOUCH_TARGET yükseklik). Basınca yüz dudağa iner +
## UiMotion squash; pasifte gri yüz, yazı TEXT_DISABLED, kuyu soluk. Alınacak bir şey varsa `set_glow` (vurgu renginde
## yumuşak hale) + köşeye oturan `badge()` (AttentionBadge). Eylem: `GestureGuard.on_pressed`.

## Toplam boy (dudak dahil). TOUCH_TARGET 84'ün üstünde: iki karo yan yana, OYNA'dan sonra ikinci kademe.
const HEIGHT: float = 108.0
const WELL: float = 80.0
const ART: float = 68.0
const TITLE_SIZE: int = 28
const CHIP_TEXT: int = 17
const CHIP_ICON: float = 20.0
const PAD: float = 12.0
const RADIUS: float = 26.0
## Cip türleri: gold = ödül / hazır · mint = tamam · info = sayı (seri, hamle) · muted = pasif durum ("YARIN").
const KIND_GOLD: StringName = &"gold"
const KIND_MINT: StringName = &"mint"
const KIND_INFO: StringName = &"info"
const KIND_MUTED: StringName = &"muted"

var _accent: Color = UiTokens.PINK
var _lip: float = UiTokens.LIP_CARD
var _pressed_visual: bool = false
var _glow_on: bool = false
var _halo: NinePatchRect
var _row: HBoxContainer
var _well: Control
var _art: TextureRect
var _title: Label
var _chips: HBoxContainer
var _chip_specs: Array = []
var _badge: AttentionBadge


func _init(title: String = "", accent: Color = UiTokens.PINK, art: Texture2D = null, icon_role: String = "") -> void:
	_accent = accent
	focus_mode = Control.FOCUS_NONE
	text = ""
	for style_name in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	custom_minimum_size = Vector2(0.0, HEIGHT)
	# Hazır hale: karonun ARKASINDA (show_behind_parent), yalnız `set_glow(true)` iken.
	_halo = UiKit.patch("popup_glow", Color(_accent, 0.62))
	_halo.name = "Glow"
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo.show_behind_parent = true
	_halo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_halo.offset_left = -22.0
	_halo.offset_right = 22.0
	_halo.offset_top = -18.0
	_halo.offset_bottom = 22.0
	_halo.visible = false
	add_child(_halo)
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_well = Control.new()
	_well.name = "Well"
	_well.custom_minimum_size = Vector2(WELL, WELL)
	_well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_well.draw.connect(_draw_well)
	_row.add_child(_well)
	_art = TextureRect.new()
	_art.name = "Art"
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_well.add_child(_art)
	set_art(art, icon_role)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(column)
	_title = UiType.v3_label(title, UiType.V3_CARD_TITLE, true, HORIZONTAL_ALIGNMENT_LEFT, TITLE_SIZE)
	_title.name = "Title"
	column.add_child(_title)
	_chips = HBoxContainer.new()
	_chips.name = "Chips"
	_chips.add_theme_constant_override("separation", UiTokens.SPACE_XS + 2)
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips.visible = false
	column.add_child(_chips)
	_badge = AttentionBadge.new()
	add_child(_badge)
	_badge.resized.connect(_place)
	button_down.connect(func() -> void: _set_pressed_visual(true))
	button_up.connect(func() -> void: _set_pressed_visual(false))
	mouse_exited.connect(func() -> void:
		if _pressed_visual and not button_pressed:
			_set_pressed_visual(false))
	resized.connect(_place)
	_row.minimum_size_changed.connect(_sync_min)
	UiMotion.attach_press(self)
	_sync_min()


# --- API ------------------------------------------------------------------------

func set_title(value: String) -> void:
	_title.text = value


func title_text() -> String:
	return _title.text


func title_label() -> Label:
	return _title


## Kuyu sanatı: owner sanatı (`art`) ya da beyaz picto (`icon_role`).
func set_art(art: Texture2D, icon_role: String = "") -> void:
	var tex: Texture2D = art
	if tex == null and not icon_role.is_empty():
		tex = UiKit.icon_texture(icon_role)
	_art.texture = tex
	var box: float = ART if art != null else ART * 0.62
	_art.position = (Vector2(WELL, WELL) - Vector2(box, box)) * 0.5 - Vector2(0.0, 3.0)
	_art.size = Vector2(box, box)


func art_texture() -> Texture2D:
	return _art.texture


## Durum cipleri (soldan sağa): her biri {text, icon (Texture2D | null), kind (KIND_*)}. Boş dizi satırı gizler.
## `mint` cip ikon verilmezse tik pictosu alır. Metin ÇAĞIRANDAN — kısa tutulur (sayı ya da tek kelime).
func set_chips(specs: Array) -> void:
	_chip_specs = specs.duplicate(true)
	for child in _chips.get_children():
		_chips.remove_child(child)
		child.queue_free()
	for spec: Dictionary in specs:
		_chips.add_child(_make_chip(spec))
	_chips.visible = not specs.is_empty()


## Görünen cip metinleri (test / inceleme).
func chip_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for spec: Dictionary in _chip_specs:
		out.append(String(spec.get("text", "")))
	return out


func chip_kinds() -> Array:
	var out: Array = []
	for spec: Dictionary in _chip_specs:
		out.append(spec.get("kind", KIND_INFO))
	return out


func chips_row() -> HBoxContainer:
	return _chips


## Etkin ↔ pasif (tek API; `disabled`'ı doğrudan yazmayın).
func set_enabled(value: bool) -> void:
	disabled = not value
	_well.modulate.a = 1.0 if value else 0.55
	if value:
		_title.remove_theme_color_override("font_color")
	else:
		_title.add_theme_color_override("font_color", UiTokens.TEXT_DISABLED)
		set_glow(false)
	if not value and _pressed_visual:
		_set_pressed_visual(false)
		UiMotion.release(self)
	queue_redraw()


func is_enabled() -> bool:
	return not disabled


## Alınacak bir şey var: vurgu renginde yumuşak hale (rozetle birlikte; pasif karoda yok).
func set_glow(value: bool) -> void:
	_glow_on = value and not disabled
	_halo.visible = _glow_on


func is_glowing() -> bool:
	return _glow_on


func badge() -> AttentionBadge:
	return _badge


## İkon kuyusu (test: kuyuya dokunuş da karonun hedefi).
func well() -> Control:
	return _well


func is_pressed_visual() -> bool:
	return _pressed_visual


# --- Yerleşim / çizim ------------------------------------------------------------

func _make_chip(spec: Dictionary) -> PanelContainer:
	var kind: StringName = spec.get("kind", KIND_INFO)
	var chip := PanelContainer.new()
	chip.name = "Chip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg: Color = Color(UiTokens.NAVY_PURPLE_DEEP, 0.55)
	var fg: Color = UiTokens.TEXT_ON_DARK
	var border: int = 0
	match kind:
		KIND_GOLD:
			bg = UiTokens.GOLD
			fg = UiTokens.TEXT_ON_ACCENT
			border = 2
		KIND_MINT:
			bg = UiTokens.MINT
			fg = UiTokens.TEXT_ON_ACCENT
			border = 2
		KIND_MUTED:
			# Pasif karonun gri yüzünde okunur durum hapı: koyu gövde + açık yazı (gri üstüne gri ~2:1 kalıyordu).
			bg = Color(UiTokens.TEXT_DISABLED, 0.85)
			fg = UiTokens.TEXT_ON_DARK
	var box := UiKit.v3_chip(bg, border)
	box.content_margin_left = 9.0
	box.content_margin_right = 10.0
	chip.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	var icon: Texture2D = spec.get("icon", null)
	var tint := Color.WHITE
	if icon == null and kind == KIND_MINT:
		icon = UiKit.icon_texture("check")
		tint = UiTokens.TEXT_ON_ACCENT
	if icon != null:
		var rect := TextureRect.new()
		rect.name = "Icon"
		rect.texture = icon
		rect.self_modulate = tint
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		rect.custom_minimum_size = Vector2(CHIP_ICON, CHIP_ICON)
		rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rect)
	var label := UiType.v3_label(String(spec.get("text", "")), UiType.V3_BADGE, true, HORIZONTAL_ALIGNMENT_CENTER,
		CHIP_TEXT)
	label.name = "Text"
	label.add_theme_color_override("font_color", fg)
	row.add_child(label)
	return chip


func _sync_min() -> void:
	custom_minimum_size = Vector2(ceilf(_row.get_combined_minimum_size().x + PAD * 2.0), HEIGHT)


func _face_rect() -> Rect2:
	return Rect2(Vector2(0.0, UiTokens.LIP_CARD - _lip), Vector2(size.x, maxf(size.y - UiTokens.LIP_CARD, 1.0)))


func _place() -> void:
	var face: Rect2 = _face_rect()
	_row.position = face.position + Vector2(PAD, 0.0)
	_row.size = Vector2(maxf(face.size.x - PAD * 2.0, 0.0), face.size.y)
	_badge.place_at(Vector2(size.x - 12.0 - _badge.size.x * 0.5, 8.0))


func _draw() -> void:
	var face: Color = UiTokens.SURFACE_HUB
	var deep: Color = UiTokens.SURFACE_HUB_DEEP
	var rim: Color = UiTokens.LAVENDER_LIGHT
	if _glow_on:
		rim = _accent.lightened(0.35)
	if disabled:
		face = UiTokens.ROLE_DISABLED
		deep = UiTokens.ROLE_DISABLED_DEEP
		rim = UiTokens.BORDER_COLOR_DISABLED
	UiKit.draw_candy(self, Rect2(Vector2.ZERO, size), face, deep, RADIUS, _lip, UiTokens.LIP_CARD,
		UiTokens.DEPTH_ELEVATED, rim, float(UiTokens.BORDER_STANDARD), UiTokens.GLOSS_ALPHA * 0.45, 0.30)


func _draw_well() -> void:
	UiKit.draw_candy_circle(_well, Vector2(WELL, WELL) * 0.5, WELL - 6.0, _accent, _accent.darkened(0.38), 5.0, 5.0,
		UiTokens.DEPTH_RESTING, Color(1, 1, 1, 0.85), 3.0)


func _set_pressed_visual(value: bool) -> void:
	_pressed_visual = value and not disabled
	_lip = UiTokens.LIP_PRESSED if _pressed_visual else UiTokens.LIP_CARD
	_place()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCROLL_BEGIN and _pressed_visual:
		_set_pressed_visual(false)
		UiMotion.release(self)
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and _pressed_visual:
		_set_pressed_visual(false)
