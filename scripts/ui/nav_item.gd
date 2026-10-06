class_name NavItem
extends Button
## Squishy UI System V3 (TASK/057) — küresel gezinme öğesi (GlobalNav'ın tek düğme bileşeni).
##
##   yan öğe   ikon (beyaz picto + yumuşak gölge ya da oyuncu avatarı) + kısa etiket (beyaz, ≥ 4.5:1 tepside).
##             Seçili: tepsiden yükselen krem candy karo + mor ikon + koyu etiket (anında okunur); seçili
##             değil: düz, açık ikon.
##   merkez    büyük yuvarlak cyan candy düğme tepsinin üstüne taşar (Harita = oyunun ana yolu); ikon
##             lacivert (cyan üstünde ≥ 4.5:1, OYNA yazısıyla aynı kural); seçili: altın halka + altın hale.
##
## Dokunma alanı (`_has_point`): yan öğe yalnız seçili karonun üst kenarından aşağısı (tepsi + karo
## taşması); merkez yalnız daire + tepsi içindeki etiket şeridi — tepsi üstündeki görünür içeriğe (kaydırılan
## kartlar) dokunuş ÇALINMAZ. Basış: yüz dudağa iner (karo / daire; seçili olmayan öğede yarı saydam
## krem karo önizlemesi) + `UiMotion` squash + `ui_tap`. Pasif: %45 soluk, `disabled`. Rozet: `badge()`
## (AttentionBadge) ikonun sağ üst köşesine oturur. Eylem bağlama GlobalNav'da (`GestureGuard.on_pressed` —
## TASK/055). Odak yok (dokunmatik oyun).

const ICON: float = 54.0
const AVATAR: float = 56.0
const CENTER_DIAMETER: float = 92.0
const CENTER_ICON: float = 58.0
## Seçili karonun tepsi üstüne taşması.
const TILE_RISE: float = 14.0
## Merkez dairenin tepsi üstüne taşması.
const CENTER_RISE: float = 40.0
const TILE_INSET_X: float = 6.0
const LABEL_HEIGHT: float = 26.0
## Beyaz pictonun yumuşak gölgesi (düz "uygulama sekmesi" görünmesin — candy derinlik).
const ICON_SHADOW: Color = Color(0.10, 0.04, 0.22, 0.38)
const ICON_SHADOW_OFFSET: Vector2 = Vector2(0.0, 3.0)

var _tab: int = 0
var _center: bool = false
var _selected: bool = false
var _pressed_visual: bool = false
var _icon: TextureRect
var _icon_shadow: TextureRect
var _avatar: AvatarButton
var _label: Label
var _badge: AttentionBadge
## Öğenin dikdörtgeninde tepsi üst kenarının y'si (GlobalNav verir): merkez daire, seçili karo ve dokunma
## alanı buna göre.
var _tray_top: float = 0.0


func _init(tab: int, label_text: String, icon_role: String = "", center: bool = false,
		avatar: bool = false) -> void:
	_tab = tab
	_center = center
	name = "Nav%d" % tab
	focus_mode = Control.FOCUS_NONE
	text = ""
	for style_name in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	if avatar:
		_avatar = AvatarButton.new(AVATAR, false)
		_avatar.name = "Avatar"
		add_child(_avatar)
	else:
		_icon_shadow = _picto(icon_role)
		_icon_shadow.name = "IconShadow"
		_icon_shadow.self_modulate = ICON_SHADOW
		_icon_shadow.visible = not center
		add_child(_icon_shadow)
		_icon = _picto(icon_role)
		_icon.name = "Icon"
		add_child(_icon)
	_label = UiType.v3_label(label_text, UiType.V3_NAV, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label.name = "Label"
	add_child(_label)
	_badge = AttentionBadge.new()
	add_child(_badge)
	button_down.connect(func() -> void: _set_pressed_visual(true))
	button_up.connect(func() -> void: _set_pressed_visual(false))
	mouse_exited.connect(func() -> void:
		if _pressed_visual and not button_pressed:
			_set_pressed_visual(false))
	resized.connect(_place)
	UiMotion.attach_press(self)
	_apply()


static func _picto(role: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = UiKit.icon_texture(role)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func tab() -> int:
	return _tab


func is_center() -> bool:
	return _center


func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	_apply()
	if value:
		UiMotion.pop(_label, 1.08)


func is_selected() -> bool:
	return _selected


func set_item_enabled(value: bool) -> void:
	if not value:
		GestureGuard.invalidate(self)
	disabled = not value
	if not value and _pressed_visual:
		_set_pressed_visual(false)
		UiMotion.release(self)
	_apply()


## V3 ortak adı (SquishyButton / FeatureCard ile aynı).
func set_enabled(value: bool) -> void:
	set_item_enabled(value)


func is_enabled() -> bool:
	return not disabled


func badge() -> AttentionBadge:
	return _badge


func label_text() -> String:
	return _label.text


func label_node() -> Label:
	return _label


func icon_node() -> Control:
	return _avatar if _avatar != null else _icon


func avatar() -> AvatarButton:
	return _avatar


## Tepsi üst kenarı (öğe koordinatı). GlobalNav yerleşimde verir.
func set_tray_top(value: float) -> void:
	_tray_top = value
	_place()


func tray_top() -> float:
	return _tray_top


func is_pressed_visual() -> bool:
	return _pressed_visual


## Testler: basılıyken yüzün çökme miktarı (px).
func face_offset() -> float:
	return (UiTokens.LIP_REST - UiTokens.LIP_PRESSED) if _pressed_visual else 0.0


## Seçili karo / merkez daire dikdörtgeni (öğe koordinatı) — testler ve çizim.
func highlight_rect() -> Rect2:
	if _center:
		var top: float = _tray_top - CENTER_RISE
		return Rect2(Vector2((size.x - CENTER_DIAMETER) * 0.5, top),
			Vector2(CENTER_DIAMETER, CENTER_DIAMETER + UiTokens.LIP_REST))
	return Rect2(Vector2(TILE_INSET_X, _tray_top - TILE_RISE),
		Vector2(size.x - TILE_INSET_X * 2.0, size.y - _tray_top + TILE_RISE - 6.0))


## Dokunma alanı: tepsi üstündeki şeritte yalnız görünen kontrol (merkez daire / seçili karo payı) dokunuş
## alır; şeridin geri kalanı alttaki içeriğe (kaydırılan kartlar) kalır.
func _has_point(point: Vector2) -> bool:
	if point.x < 0.0 or point.x > size.x or point.y > size.y:
		return false
	if _center:
		var circle: Rect2 = highlight_rect()
		var center := Vector2(size.x * 0.5, circle.position.y + CENTER_DIAMETER * 0.5)
		return point.y >= _tray_top or point.distance_to(center) <= CENTER_DIAMETER * 0.5 + 4.0
	return point.y >= _tray_top - TILE_RISE


func _apply() -> void:
	var label_color: Color = UiTokens.NAV_LABEL_IDLE
	if _center:
		if _icon != null:
			_icon.self_modulate = UiTokens.TEXT_ON_ACCENT
	elif _selected:
		label_color = UiTokens.TEXT_PRIMARY
		if _icon != null:
			_icon.self_modulate = UiTokens.NAV_ICON_SELECTED
	elif _icon != null:
		_icon.self_modulate = UiTokens.NAV_ICON_IDLE
	if _icon_shadow != null:
		_icon_shadow.visible = not _center and not _selected
	_label.add_theme_color_override("font_color", label_color)
	# Seçili yan öğede etiket koyu (krem karo üstü): gölgesiz okunur.
	_label.add_theme_color_override("font_shadow_color",
		Color(0, 0, 0, 0) if (_selected and not _center) else UiTokens.TEXT_SHADOW)
	modulate.a = 0.45 if disabled else 1.0
	_place()
	queue_redraw()


func _place() -> void:
	if _label == null:
		return
	var drop: float = face_offset()
	var icon_box: float = CENTER_ICON if _center else (AVATAR if _avatar != null else ICON)
	var icon_center: Vector2
	if _center:
		var circle: Rect2 = highlight_rect()
		icon_center = Vector2(size.x * 0.5, circle.position.y + CENTER_DIAMETER * 0.5 + drop)
		_label.position = Vector2(0.0, circle.end.y - 2.0)
	else:
		var lift: float = TILE_RISE * 0.6 if _selected else 0.0
		icon_center = Vector2(size.x * 0.5, _tray_top + 32.0 - lift + drop)
		_label.position = Vector2(0.0, _tray_top + 56.0 - lift * 0.5 + drop)
	_label.size = Vector2(size.x, LABEL_HEIGHT)
	var icon_node_c: Control = icon_node()
	icon_node_c.size = Vector2(icon_box, icon_box)
	icon_node_c.position = icon_center - Vector2(icon_box, icon_box) * 0.5
	if _icon_shadow != null:
		_icon_shadow.size = icon_node_c.size
		_icon_shadow.position = icon_node_c.position + ICON_SHADOW_OFFSET
	_badge.place_at(icon_center + Vector2(icon_box * 0.42, -icon_box * 0.40))


func _draw() -> void:
	if _center:
		var circle: Rect2 = highlight_rect()
		var lip: float = UiTokens.LIP_PRESSED if _pressed_visual else UiTokens.LIP_REST
		var center := Vector2(size.x * 0.5, circle.position.y + (CENTER_DIAMETER + UiTokens.LIP_REST) * 0.5)
		if _selected:
			# Altın hale: seçili merkez tepsinin üstünde parlar.
			var halo := UiKit.v3_box(Color(UiTokens.GOLD_BRIGHT, 0.0), CENTER_DIAMETER)
			halo.shadow_color = Color(UiTokens.GOLD_BRIGHT, 0.55)
			halo.shadow_size = 18
			draw_style_box(halo, circle.grow(2.0))
		var rim: Color = UiTokens.GOLD_BRIGHT if _selected else Color(1, 1, 1, 0.92)
		var rim_w: float = 5.0 if _selected else 4.0
		UiKit.draw_candy_circle(self, center, CENTER_DIAMETER, UiTokens.ROLE_PRIMARY, UiTokens.ROLE_PRIMARY_DEEP,
			lip, UiTokens.LIP_REST, UiTokens.DEPTH_ELEVATED, rim, rim_w)
		return
	var lip_now: float = UiTokens.LIP_PRESSED if _pressed_visual else UiTokens.LIP_REST
	if _selected:
		UiKit.draw_candy(self, highlight_rect(), UiTokens.NAV_SELECTED, UiTokens.NAV_SELECTED_DEEP,
			UiTokens.RADIUS_CONTROL, lip_now, UiTokens.LIP_REST, UiTokens.DEPTH_RESTING, Color(1, 1, 1, 0.95), 3.0, 0.5)
	elif _pressed_visual:
		# Basılı (seçili değil) öğe: aynı candy karonun yarı saydam, dudağı çökmüş önizlemesi.
		var tile: Rect2 = highlight_rect()
		tile.position.y += TILE_RISE * 0.5
		tile.size.y -= TILE_RISE * 0.5
		UiKit.draw_candy(self, tile, Color(UiTokens.NAV_SELECTED, 0.42), Color(UiTokens.NAV_SELECTED_DEEP, 0.42),
			UiTokens.RADIUS_CONTROL, UiTokens.LIP_PRESSED, UiTokens.LIP_REST, {}, Color(1, 1, 1, 0.5), 2.0, 0.2)


func _set_pressed_visual(value: bool) -> void:
	_pressed_visual = value and not disabled
	_place()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and _pressed_visual:
		_set_pressed_visual(false)
