class_name NavItem
extends Button
## Squishy UI System V3 (TASK/057) — küresel gezinme öğesi (GlobalNav'ın tek düğme bileşeni).
##
##   yan öğe   ikon (beyaz picto + yumuşak gölge ya da oyuncu avatarı) baskın tanıma işareti + kısa etiket (beyaz,
##             tepside ≥ 4.5:1).
##   merkez    büyük yuvarlak cyan candy düğme (Harita = oyunun ana yolu); ikon lacivert (cyan üstünde ≥ 4.5:1).
##             Normal kipte tepsinin üstüne taşar; KOMPAKT kipte (kısa kullanılabilir yükseklik, ör. 16:9 + banner —
##             GlobalNav karar verir) 62 px daire tepsi kenarına oturur (yalnız birkaç px dekoratif taşma, dokunuş
##             almaz), etiketi yan etiketlerle neredeyse aynı çizgide — dokunma alanı tam tepsi dilimi (≥ TOUCH_TARGET).
##
## SEÇİLİ DURUM — TEK AİLE (`selected_family()`): krem candy malzeme + sıcak altın ışıma + yükselme. Yan öğe: krem
## karo tepsiden yükselir, ikon mor, etiket koyu. Merkez: AYNI krem malzeme dairenin etrafında kalın kaide halkası +
## aynı ışıma + etiketi aynı krem hapta koyu — ve merkeze özgü TEK ek premium katman: ince altın dış halka. Hiçbir
## öğe başka bir seçili malzeme kullanmaz (`applied_selection()` testle kilitli).
##
## Dokunma alanı (`_has_point`): yan öğe yalnız GÖRÜNEN gövdesi — tepsi (seçiliyse + karo payı); merkez yalnız
## daire + tepsi. Basış: yüz dudağa iner (karo / daire; seçili olmayan öğede yarı saydam krem karo önizlemesi, etiket
## koyu) + `UiMotion` squash + `ui_tap`. Pasif: %45 soluk, `disabled`. Rozet: `badge()` (AttentionBadge) ikonun sağ
## üst köşesine oturur. Eylem bağlama GlobalNav'da (`GestureGuard.on_pressed` — TASK/055). Odak yok.

const ICON: float = 58.0
const AVATAR: float = 58.0
const CENTER_DIAMETER: float = 92.0
const CENTER_DIAMETER_COMPACT: float = 62.0
const CENTER_ICON: float = 58.0
const CENTER_ICON_COMPACT: float = 44.0
## Kompakt merkez dairenin tepsi üst kenarına göre konumu (negatif = dekoratif taşma; pay / dokunma alanına girmez).
const COMPACT_CIRCLE_TOP: float = -3.0
## Yan öğe etiketinin tepsi üstünden y'si (merkez kompakt etiketi buna yakın hizalanır).
const SIDE_LABEL_Y: float = 56.0
## Seçili karonun tepsi üstüne taşması.
const TILE_RISE: float = 14.0
## Merkez dairenin tepsi üstüne taşması (normal kip; kompaktta 0).
const CENTER_RISE: float = 40.0
const TILE_INSET_X: float = 6.0
const LABEL_HEIGHT: float = 26.0
## Merkez seçili kaide halkası (krem — yan öğenin seçili karosuyla aynı malzeme; kompaktta ince) ve merkeze özgü tek
## ek katman: premium altın dış halka.
const PLINTH_RING: float = 10.0
const PLINTH_RING_COMPACT: float = 7.0
const PREMIUM_RING: float = 3.0
## Basılı (seçili olmayan) öğenin önizleme karosu opaklığı (soluk "pasif" gibi görünmesin).
const PRESS_PREVIEW_ALPHA: float = 0.68
## Beyaz pictonun yumuşak gölgesi (düz "uygulama sekmesi" görünmesin — candy derinlik).
const ICON_SHADOW: Color = Color(0.10, 0.04, 0.22, 0.42)
const ICON_SHADOW_OFFSET: Vector2 = Vector2(0.0, 3.0)

var _tab: int = 0
var _center: bool = false
var _compact: bool = false
var _selected: bool = false
var _pressed_visual: bool = false
var _icon: TextureRect
var _icon_shadow: TextureRect
var _avatar: AvatarButton
var _label: Label
var _badge: AttentionBadge
## Öğenin dikdörtgeninde tepsi üst kenarının y'si (GlobalNav verir).
var _tray_top: float = 0.0
## Şu an çizilen seçili malzeme (seçili değilse boş) — `_draw` YALNIZ bunu kullanır.
var _applied: Dictionary = {}


## Seçili durum ailesi: bütün öğeler AYNI dolgu / dudak / ışıma / ikon / etiket rengini kullanır.
static func selected_family() -> Dictionary:
	return {
		"fill": UiTokens.NAV_SELECTED,
		"deep": UiTokens.NAV_SELECTED_DEEP,
		"glow": UiTokens.NAV_SELECTED_GLOW,
		"icon": UiTokens.NAV_ICON_SELECTED,
		"label": UiTokens.TEXT_PRIMARY,
	}


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


## Kompakt kip (GlobalNav): merkez taşmaz, daire tepsinin içinde.
func set_compact(value: bool) -> void:
	if _compact == value:
		return
	_compact = value
	_apply()


func is_compact() -> bool:
	return _compact


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


## Şu an çizilen seçili malzeme (seçili değilse boş sözlük) — tek aile sözleşmesi için.
func applied_selection() -> Dictionary:
	return _applied


func center_diameter() -> float:
	return CENTER_DIAMETER_COMPACT if _compact else CENTER_DIAMETER


## Seçili karo / merkez daire dikdörtgeni (öğe koordinatı) — testler ve çizim.
func highlight_rect() -> Rect2:
	if _center:
		var d: float = center_diameter()
		var top: float = (_tray_top - CENTER_RISE) if not _compact else (_tray_top + COMPACT_CIRCLE_TOP)
		return Rect2(Vector2((size.x - d) * 0.5, top), Vector2(d, d + UiTokens.LIP_REST))
	return Rect2(Vector2(TILE_INSET_X, _tray_top - TILE_RISE),
		Vector2(size.x - TILE_INSET_X * 2.0, size.y - _tray_top + TILE_RISE - 6.0))


## Dokunma alanı: tepsi üstündeki şeritte yalnız görünen kontrol (merkez daire / seçili karo payı) dokunuş alır;
## şeridin geri kalanı alttaki içeriğe (kaydırılan kartlar) kalır.
func _has_point(point: Vector2) -> bool:
	if point.x < 0.0 or point.x > size.x or point.y > size.y:
		return false
	if _center:
		if _compact:
			# Kompakt: dokunma alanı tam tepsi dilimi; dairenin birkaç px dekoratif taşması içeriğe kalır.
			return point.y >= _tray_top
		var circle: Rect2 = highlight_rect()
		var c := Vector2(size.x * 0.5, circle.position.y + center_diameter() * 0.5)
		return point.y >= _tray_top or point.distance_to(c) <= center_diameter() * 0.5 + 4.0
	# Kompakt kipte kabuğun payı taşmayı içermez: seçili karonun yükselen payı yalnız görseldir.
	return point.y >= _tray_top - (TILE_RISE if _selected and not _compact else 0.0)


func _apply() -> void:
	_applied = selected_family() if _selected else {}
	var label_color: Color = UiTokens.NAV_LABEL_IDLE
	if _center:
		if _icon != null:
			_icon.self_modulate = UiTokens.TEXT_ON_ACCENT
		if _selected:
			label_color = _applied["label"]
	elif _selected:
		label_color = _applied["label"]
		if _icon != null:
			_icon.self_modulate = _applied["icon"]
	elif _pressed_visual:
		# Basılı önizleme karosu açık: etiket koyu (beyaz yarı saydam kremde ~2.4:1 kalırdı).
		label_color = UiTokens.TEXT_PRIMARY
		if _icon != null:
			_icon.self_modulate = UiTokens.NAV_ICON_SELECTED
	elif _icon != null:
		_icon.self_modulate = UiTokens.NAV_ICON_IDLE
	if _icon_shadow != null:
		_icon_shadow.visible = not _center and not _selected and not _pressed_visual
	_label.add_theme_color_override("font_color", label_color)
	var dark_label: bool = _selected or (_pressed_visual and not _center)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0) if dark_label else UiTokens.TEXT_SHADOW)
	modulate.a = 0.45 if disabled else 1.0
	_place()
	queue_redraw()


func _place() -> void:
	if _label == null:
		return
	var drop: float = face_offset()
	var icon_box: float = (CENTER_ICON_COMPACT if _compact else CENTER_ICON) if _center \
		else (AVATAR if _avatar != null else ICON)
	var icon_center: Vector2
	if _center:
		var circle: Rect2 = highlight_rect()
		icon_center = Vector2(size.x * 0.5, circle.position.y + center_diameter() * 0.5 + drop)
		_label.position = Vector2(0.0, circle.end.y - 2.0) if not _compact \
			else Vector2(0.0, maxf(circle.end.y - 6.0, _tray_top + SIDE_LABEL_Y))
	else:
		var lift: float = TILE_RISE * 0.6 if _selected else 0.0
		icon_center = Vector2(size.x * 0.5, _tray_top + 31.0 - lift + drop)
		_label.position = Vector2(0.0, _tray_top + SIDE_LABEL_Y - lift * 0.5 + drop)
	_label.size = Vector2(size.x, LABEL_HEIGHT)
	var icon_node_c: Control = icon_node()
	icon_node_c.size = Vector2(icon_box, icon_box)
	icon_node_c.position = icon_center - Vector2(icon_box, icon_box) * 0.5
	if _icon_shadow != null:
		_icon_shadow.size = icon_node_c.size
		_icon_shadow.position = icon_node_c.position + ICON_SHADOW_OFFSET
	_badge.place_at(icon_center + Vector2(icon_box * 0.42, -icon_box * 0.40))


func _draw() -> void:
	var lip_now: float = UiTokens.LIP_PRESSED if _pressed_visual else UiTokens.LIP_REST
	if _center:
		var circle: Rect2 = highlight_rect()
		var d: float = center_diameter()
		var c := Vector2(size.x * 0.5, circle.position.y + (d + UiTokens.LIP_REST) * 0.5)
		var rim: Color = Color(1, 1, 1, 0.92)
		var rim_w: float = 4.0
		if not _applied.is_empty():
			# Seçili aile: aynı sıcak ışıma + aynı krem malzeme (kaide halkası) + merkeze özgü ince altın dış halka.
			var plinth: float = PLINTH_RING_COMPACT if _compact else PLINTH_RING
			_draw_glow(circle.grow(plinth), d)
			UiKit.draw_candy_circle(self, c, d + (plinth + PREMIUM_RING) * 2.0, UiTokens.GOLD_BRIGHT,
				UiTokens.GOLD_DEEP, lip_now, UiTokens.LIP_REST, UiTokens.DEPTH_RESTING, Color(0, 0, 0, 0), 0.0, 0.0)
			UiKit.draw_candy_circle(self, c, d + plinth * 2.0, _applied["fill"], _applied["deep"], lip_now,
				UiTokens.LIP_REST, {}, Color(0, 0, 0, 0), 0.0, 0.45)
			rim = Color(1, 1, 1, 0.0)
			rim_w = 0.0
		UiKit.draw_candy_circle(self, c, d, UiTokens.ROLE_PRIMARY, UiTokens.ROLE_PRIMARY_DEEP, lip_now,
			UiTokens.LIP_REST, {} if not _applied.is_empty() else UiTokens.DEPTH_ELEVATED, rim, rim_w)
		if not _applied.is_empty():
			# Etiket aynı krem malzemede (seçili ailesi) — tepsinin içinde küçük hap.
			var w: float = minf(_label.get_minimum_size().x + 20.0, size.x - 4.0)
			var pill := Rect2(Vector2((size.x - w) * 0.5, _label.position.y + 1.0), Vector2(w, LABEL_HEIGHT - 1.0))
			UiKit.draw_candy(self, pill, _applied["fill"], _applied["deep"], LABEL_HEIGHT * 0.5, 3.0, 3.0, {},
				Color(0, 0, 0, 0), 0.0, 0.0)
		return
	if not _applied.is_empty():
		var tile: Rect2 = highlight_rect()
		_draw_glow(tile, UiTokens.RADIUS_CONTROL)
		UiKit.draw_candy(self, tile, _applied["fill"], _applied["deep"], UiTokens.RADIUS_CONTROL, lip_now,
			UiTokens.LIP_REST, UiTokens.DEPTH_RESTING, Color(1, 1, 1, 0.95), 3.0, 0.5)
	elif _pressed_visual:
		# Basılı (seçili değil) öğe: aynı candy karonun yarı saydam, dudağı çökmüş önizlemesi.
		var tile: Rect2 = highlight_rect()
		tile.position.y += TILE_RISE * 0.5
		tile.size.y -= TILE_RISE * 0.5
		var fam: Dictionary = selected_family()
		UiKit.draw_candy(self, tile, Color(fam["fill"], PRESS_PREVIEW_ALPHA), Color(fam["deep"], PRESS_PREVIEW_ALPHA),
			UiTokens.RADIUS_CONTROL, UiTokens.LIP_PRESSED, UiTokens.LIP_REST, {}, Color(1, 1, 1, 0.5), 2.0, 0.2)


## Seçili ailenin sıcak ışıması (aynı renk / boy her öğede).
func _draw_glow(rect: Rect2, radius: float) -> void:
	var glow := UiKit.v3_box(Color(0, 0, 0, 0), radius)
	glow.shadow_color = _applied["glow"]
	glow.shadow_size = 16
	draw_style_box(glow, rect)


func _set_pressed_visual(value: bool) -> void:
	_pressed_visual = value and not disabled
	_apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and _pressed_visual:
		_set_pressed_visual(false)
