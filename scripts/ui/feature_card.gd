class_name FeatureCard
extends Button
## Squishy UI System V3 (TASK/057) — özellik kartı (ileride Günlük / Meydan Okuma / Koleksiyon benzeri
## girişler — TASK/058 / 061 / 063 bağlar; bu görev yalnız bileşeni kurar).
##
##   [büyük sanat kuyusu]  BAŞLIK (kart başlığı, Baloo)        [rozet]
##                         tek satır alt yazı (isteğe bağlı)    [ › / CTA ]
##                         ▬▬▬▬▬▬ ilerleme (isteğe bağlı) 3/5
##
## Kartın TAMAMI tek dokunma hedefi (≥ TOUCH_TARGET yükseklik); yüzey V3 candy (koyu hub yüzeyi ya da
## krem), içinde İKİNCİ bir çerçeveli panel YOK (ilerleme ince ray, rozet köşede). Basınca yüz dudağa
## iner. Rozet `badge()` (AttentionBadge) sağ üst köşeye oturur. Eylem: `GestureGuard.on_pressed`.

const HEIGHT: float = 124.0
## TASK/057 Tur 2: ikon ve başlık önce okunsun (owner) — kuyu / sanat bir kademe büyük, başlık 27 px (hiyerarşi boyla;
## alt yazı koyu yüzeyde tam beyaz kalır — 16 px metinde ≥ 4.5:1).
const WELL: float = 96.0
const ART: float = 82.0
const TITLE_SIZE: int = 27
const CHEVRON: float = 44.0
const PAD: float = 18.0

var _on_light: bool = false
var _accent: Color = UiTokens.PINK
var _lip: float = UiTokens.LIP_CARD
var _pressed_visual: bool = false
var _selected: bool = false
var _row: HBoxContainer
var _well: Control
var _art: TextureRect
var _title: Label
var _subtitle: Label
var _progress_row: HBoxContainer
var _progress_bar: Control
var _progress_fill: float = 0.0
var _progress_label: Label
var _chevron: Control
var _cta: SquishyButton
var _badge: AttentionBadge


func _init(title: String = "", subtitle: String = "", accent: Color = UiTokens.PINK,
		art: Texture2D = null, icon_role: String = "", on_light: bool = false) -> void:
	_accent = accent
	_on_light = on_light
	focus_mode = Control.FOCUS_NONE
	text = ""
	for style_name in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	custom_minimum_size = Vector2(0.0, HEIGHT)
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.add_theme_constant_override("separation", UiTokens.SPACE_LG - 4)
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
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(column)
	_title = UiType.v3_label(title, UiType.V3_CARD_TITLE, not _on_light, HORIZONTAL_ALIGNMENT_LEFT, TITLE_SIZE)
	_title.name = "Title"
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_title)
	_subtitle = UiType.v3_label(subtitle, UiType.V3_SECONDARY, not _on_light)
	_subtitle.name = "Subtitle"
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if not _on_light:
		_subtitle.add_theme_color_override("font_color", UiTokens.TEXT_ON_DARK)
	_subtitle.visible = not subtitle.is_empty()
	column.add_child(_subtitle)
	_progress_row = HBoxContainer.new()
	_progress_row.name = "Progress"
	_progress_row.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_progress_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_row.visible = false
	column.add_child(_progress_row)
	_progress_bar = Control.new()
	_progress_bar.name = "Bar"
	_progress_bar.custom_minimum_size = Vector2(0.0, 12.0)
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bar.draw.connect(_draw_progress)
	_progress_row.add_child(_progress_bar)
	_progress_label = UiType.v3_label("", UiType.V3_META, not _on_light)
	_progress_label.name = "ProgressText"
	if not _on_light:
		_progress_label.add_theme_color_override("font_color", UiTokens.TEXT_ON_DARK)
	_progress_row.add_child(_progress_label)
	_chevron = Control.new()
	_chevron.name = "Chevron"
	_chevron.custom_minimum_size = Vector2(CHEVRON, CHEVRON)
	_chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chevron.draw.connect(_draw_chevron)
	_row.add_child(_chevron)
	var arrow := UiKit.icon("arrow_next", 24.0, UiTokens.NAV_ICON_SELECTED if not _on_light else UiTokens.TEXT_ON_DARK)
	arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	arrow.offset_left = -12.0
	arrow.offset_right = 12.0
	arrow.offset_top = -13.0
	arrow.offset_bottom = 11.0
	_chevron.add_child(arrow)
	_badge = AttentionBadge.new()
	add_child(_badge)
	# Hap rozeti (YENİ / 99+) büyüyünce kartın sağ kenarının içinde kalsın.
	_badge.resized.connect(_place)
	button_down.connect(func() -> void: _set_pressed_visual(true))
	button_up.connect(func() -> void: _set_pressed_visual(false))
	mouse_exited.connect(func() -> void:
		if _pressed_visual and not button_pressed:
			_set_pressed_visual(false))
	resized.connect(_place)
	# Kartın en küçük genişliği içerikten (kuyu + CTA / › + paylar): yan yana kartta CTA taşmaz, başlık sessizce
	# kırpılmaz (üç nokta yalnız gerçekten dar alanda).
	_row.minimum_size_changed.connect(_sync_min)
	UiMotion.attach_press(self)
	_sync_min()


# --- API ------------------------------------------------------------------------

func set_title(value: String) -> void:
	_title.text = value


func title_text() -> String:
	return _title.text


func set_subtitle(value: String) -> void:
	_subtitle.text = value
	_subtitle.visible = not value.is_empty()


func subtitle_text() -> String:
	return _subtitle.text if _subtitle.visible else ""


## Kuyu sanatı: owner sanatı (`art`) ya da beyaz picto (`icon_role`).
func set_art(art: Texture2D, icon_role: String = "") -> void:
	var tex: Texture2D = art
	if tex == null and not icon_role.is_empty():
		tex = UiKit.icon_texture(icon_role)
	_art.texture = tex
	var box: float = ART if art != null else ART * 0.62
	_art.position = (Vector2(WELL, WELL) - Vector2(box, box)) * 0.5 - Vector2(0.0, 3.0)
	_art.size = Vector2(box, box)


## İlerleme: 0..1 oran + metin ("3/5"); `ratio < 0` gizler.
func set_progress(ratio: float, label: String = "") -> void:
	_progress_row.visible = ratio >= 0.0
	_progress_fill = clampf(ratio, 0.0, 1.0)
	_progress_label.text = label
	_progress_label.visible = not label.is_empty()
	_progress_bar.queue_redraw()


func progress_ratio() -> float:
	return _progress_fill if _progress_row.visible else -1.0


## Sağ uç: CTA metni verilirse chevron yerine kompakt SquishyButton (görsel; kartın kendisi
## dokunma hedefi — CTA fare almaz, tek eylem). Boş metin chevron'a döner. CTA'nın düz durumu
## (pasif / alındı / tükendi / yok) KARTA yansır: kart da etkin olmaz.
func set_cta(value: String, kind: int = SquishyButton.Kind.PRIMARY,
		state: int = SquishyButton.State.NORMAL) -> void:
	if value.is_empty():
		if _cta != null:
			_row.remove_child(_cta)
			_cta.queue_free()
			_cta = null
		_chevron.visible = true
		set_enabled(true)
		return
	if _cta == null:
		_cta = SquishyButton.new(value, kind, SquishyButton.SizeClass.COMPACT)
		_cta.name = "Cta"
		_cta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_row.add_child(_cta)
	else:
		_cta.set_title(value)
		_cta.set_kind(kind)
	_cta.set_state(state)
	_chevron.visible = false
	set_enabled(_cta.is_enabled() or _cta.state() == SquishyButton.State.INSUFFICIENT)


## Etkin ↔ pasif (tek API; `disabled`'ı doğrudan yazmayın): pasifte yüz griye, içerik %55.
func set_enabled(value: bool) -> void:
	disabled = not value
	_row.modulate.a = 1.0 if value else 0.55
	if not value and _pressed_visual:
		_set_pressed_visual(false)
		UiMotion.release(self)
	queue_redraw()


func is_enabled() -> bool:
	return not disabled


func cta() -> SquishyButton:
	return _cta


func badge() -> AttentionBadge:
	return _badge


## Seçili (ör. sekme içi odak): beyaz-altın kalın halka.
func set_selected(value: bool) -> void:
	_selected = value
	queue_redraw()


func is_selected() -> bool:
	return _selected


func face_offset() -> float:
	return UiTokens.LIP_CARD - _lip


func set_scrollable(value: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS if value else Control.MOUSE_FILTER_STOP


# --- Yerleşim / çizim ------------------------------------------------------------

func _sync_min() -> void:
	custom_minimum_size = Vector2(ceilf(_row.get_combined_minimum_size().x + PAD * 2.0), HEIGHT)


func _face_rect() -> Rect2:
	return Rect2(Vector2(0.0, UiTokens.LIP_CARD - _lip), Vector2(size.x, maxf(size.y - UiTokens.LIP_CARD, 1.0)))


func _place() -> void:
	var face: Rect2 = _face_rect()
	_row.position = face.position + Vector2(PAD, 0.0)
	_row.size = Vector2(maxf(face.size.x - PAD * 2.0, 0.0), face.size.y)
	_badge.place_at(Vector2(size.x - 12.0 - _badge.size.x * 0.5, 10.0))


func _draw() -> void:
	var face: Color = UiTokens.SURFACE_ELEVATED if _on_light else UiTokens.SURFACE_HUB
	var deep: Color = UiTokens.SURFACE_NEUTRAL_DEEP if _on_light else UiTokens.SURFACE_HUB_DEEP
	var rim: Color = UiTokens.LAVENDER_LIGHT
	var rim_w: float = float(UiTokens.BORDER_STANDARD)
	if _selected:
		rim = UiTokens.BORDER_COLOR_SELECTED
		rim_w = float(UiTokens.BORDER_SELECTED)
	if disabled:
		face = UiTokens.ROLE_DISABLED
		deep = UiTokens.ROLE_DISABLED_DEEP
		rim = UiTokens.BORDER_COLOR_DISABLED
	UiKit.draw_candy(self, Rect2(Vector2.ZERO, size), face, deep, UiTokens.RADIUS_FEATURE, _lip,
		UiTokens.LIP_CARD, UiTokens.DEPTH_ELEVATED, rim, rim_w, UiTokens.GLOSS_ALPHA * 0.45, 0.30)


func _draw_well() -> void:
	UiKit.draw_candy_circle(_well, Vector2(WELL, WELL) * 0.5 + Vector2(0.0, 0.0), WELL - 6.0, _accent,
		_accent.darkened(0.38), 5.0, 5.0, UiTokens.DEPTH_RESTING, Color(1, 1, 1, 0.85), 3.0)


func _draw_progress() -> void:
	var rect := Rect2(Vector2.ZERO, _progress_bar.size)
	_progress_bar.draw_style_box(UiKit.v3_box(Color(UiTokens.NAVY_PURPLE_DEEP, 0.55), rect.size.y * 0.5), rect)
	if _progress_fill > 0.0:
		var fill := Rect2(rect.position, Vector2(maxf(rect.size.x * _progress_fill, rect.size.y), rect.size.y))
		_progress_bar.draw_style_box(UiKit.v3_box(UiTokens.MINT, rect.size.y * 0.5), fill)
		_progress_bar.draw_style_box(UiKit.v3_box(Color(1, 1, 1, 0.35), 3.0),
			Rect2(fill.position + Vector2(4.0, 2.0), Vector2(maxf(fill.size.x - 8.0, 0.0), 3.0)))


func _draw_chevron() -> void:
	var c: Vector2 = _chevron.size * 0.5
	var color: Color = UiTokens.SURFACE_ELEVATED if not _on_light else UiTokens.ROLE_SECONDARY
	UiKit.draw_candy_circle(_chevron, c, CHEVRON - 4.0, color, color.darkened(0.22), 3.0, 3.0)


func _set_pressed_visual(value: bool) -> void:
	_pressed_visual = value and not disabled
	_lip = UiTokens.LIP_PRESSED if _pressed_visual else UiTokens.LIP_CARD
	_place()
	queue_redraw()


func is_pressed_visual() -> bool:
	return _pressed_visual


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCROLL_BEGIN and _pressed_visual:
		_set_pressed_visual(false)
		UiMotion.release(self)
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and _pressed_visual:
		_set_pressed_visual(false)
