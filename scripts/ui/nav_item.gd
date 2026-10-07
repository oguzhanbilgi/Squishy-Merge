class_name NavItem
extends Button
## Squishy UI System V3 (TASK/057) — küresel gezinme öğesi (GlobalNav'ın tek düğme bileşeni).
##
## TEK SİMGE AİLESİ (TASK/057 son cila): her hedef aynı candy MADALYONU taşır — beyaz kenar + hedefin vurgu rengi yüz +
## koyu dudak + yumuşak gölge + lacivert picto (her vurgu yüzünde ≥ 4.5:1). Kimlik = picto + vurgu (Ana Sayfa pembe,
## Mağaza altın, Harita cyan, Koleksiyon nane). Profil'de madalyonun yüzü oyuncunun avatarıdır (aynı kenar / dudak /
## gölge). Merkez HARİTA aynı madalyonun büyük hâli: normal kipte tepsinin üstüne taşar; KOMPAKT kipte (kısa
## kullanılabilir yükseklik, ör. 16:9 + banner — GlobalNav karar verir) 62 px, tepsi kenarına oturur (birkaç px
## dekoratif taşma dokunuş almaz).
##
## SEÇİLİ DURUM — TEK AİLE (`selected_family()`): madalyon büyür ve tepsiden yükselir + etrafında krem kaide halkası +
## sıcak altın hale + etiket krem hapta koyu. Dev krem karo YOK (uygulama sekmesi gibi okunmasın). Merkeze özgü TEK ek
## premium katman: kaidenin dışında ince altın halka. Hiçbir öğe başka bir seçili malzeme kullanmaz (`applied_selection()`
## testle kilitli; `_draw` seçili malzemeyi yalnız `_applied`'dan okur).
##
## Dokunma alanı (`_has_point`): yan öğe tepsi dilimi (seçiliyse + yükselen madalyon payı, normal kipte); merkez daire +
## tepsi. Basış: madalyon dudağa iner + yüz hafif aydınlanır + `UiMotion` squash + `ui_tap`. Pasif: %45 soluk,
## `disabled`. Rozet: `badge()` (AttentionBadge) madalyonun sağ üst köşesine oturur. Eylem bağlama GlobalNav'da
## (`GestureGuard.on_pressed` — TASK/055). Odak yok.

## Yan madalyon çapı: seçili değil / seçili (büyür).
const MEDALLION: float = 52.0
const MEDALLION_SELECTED: float = 62.0
## Madalyonun tepsi üstüne göre üst kenarı: seçili değil (tepsinin içinde) / seçili (tepsiden yükselir).
const MEDALLION_TOP: float = 5.0
const MEDALLION_TOP_SELECTED: float = -12.0
## Yan picto: seçili değil / seçili. Avatar madalyon çapında (ölçekle).
const ICON: float = 32.0
const ICON_SELECTED: float = 40.0
const AVATAR: float = 62.0
const CENTER_DIAMETER: float = 92.0
const CENTER_DIAMETER_COMPACT: float = 62.0
const CENTER_ICON: float = 58.0
const CENTER_ICON_COMPACT: float = 44.0
## Kompakt merkez dairenin tepsi üst kenarına göre konumu (negatif = dekoratif taşma; pay / dokunma alanına girmez).
const COMPACT_CIRCLE_TOP: float = -3.0
## Yan öğe etiketinin tepsi üstünden y'si (seçili hap 2 px yukarıda; merkez kompakt etiketi buna yakın hizalanır).
const SIDE_LABEL_Y: float = 60.0
## Seçili yan madalyonun tepsi üstündeki dokunma payı (normal kip; kompaktta yalnız görsel).
const TILE_RISE: float = 14.0
## Merkez dairenin tepsi üstüne taşması (normal kip; kompaktta 0).
const CENTER_RISE: float = 40.0
const LABEL_HEIGHT: float = 26.0
## Madalyon kenarı ve dudağı.
const MEDALLION_RIM: float = 3.0
const MEDALLION_LIP: float = 5.0
## Seçili kaide halkası (krem — her öğede aynı malzeme): yan / merkez / kompakt merkez; merkeze özgü altın halka.
const PLINTH_RING_SIDE: float = 5.0
const PLINTH_RING: float = 10.0
const PLINTH_RING_COMPACT: float = 7.0
const PREMIUM_RING: float = 3.0
## Basılı madalyonun yüzü bu oranda aydınlanır; seçili ailenin krem kaidesi kalın, neredeyse opak önizleme olarak
## görünür (telefonda parmağın altında da seçilsin — A36'da ince önizleme zor okunuyordu).
const PRESS_BRIGHTEN: float = 0.24
const PRESS_PREVIEW_ALPHA: float = 0.95
const PRESS_RING: float = 7.0

var _tab: int = 0
var _center: bool = false
var _compact: bool = false
var _selected: bool = false
var _pressed_visual: bool = false
var _accent: Color = UiTokens.NAV_ACCENT_MAP
var _accent_deep: Color = UiTokens.NAV_ACCENT_MAP_DEEP
var _icon: TextureRect
var _avatar: AvatarButton
var _label: Label
var _badge: AttentionBadge
## Öğenin dikdörtgeninde tepsi üst kenarının y'si (GlobalNav verir).
var _tray_top: float = 0.0
## Şu an çizilen seçili malzeme (seçili değilse boş) — `_draw` YALNIZ bunu kullanır.
var _applied: Dictionary = {}


## Seçili durum ailesi: bütün öğeler AYNI kaide / ışıma / etiket hapı / ikon / etiket rengini kullanır.
static func selected_family() -> Dictionary:
	return {
		"fill": UiTokens.NAV_SELECTED,
		"deep": UiTokens.NAV_SELECTED_DEEP,
		"glow": UiTokens.NAV_SELECTED_GLOW,
		"icon": UiTokens.NAV_MEDALLION_ICON,
		"label": UiTokens.TEXT_PRIMARY,
	}


func _init(tab: int, label_text: String, icon_role: String = "", center: bool = false,
		avatar: bool = false, accent: Color = UiTokens.NAV_ACCENT_MAP,
		accent_deep: Color = UiTokens.NAV_ACCENT_MAP_DEEP) -> void:
	_tab = tab
	_center = center
	_accent = accent
	_accent_deep = accent_deep
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


## Hedefin kimlik vurgusu (madalyon yüzü; Profil'de avatarın arkası).
func accent() -> Color:
	return _accent


func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	_apply()
	if value:
		UiMotion.pop(_label, 1.08)


func is_selected() -> bool:
	return _selected


## Kompakt kip (GlobalNav): merkez taşmaz, daire tepsinin kenarında.
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


## Testler: basılıyken madalyon yüzünün çökme miktarı (px).
func face_offset() -> float:
	return (_lip_rest() - UiTokens.LIP_PRESSED) if _pressed_visual else 0.0


## Şu an çizilen seçili malzeme (seçili değilse boş sözlük) — tek aile sözleşmesi için.
func applied_selection() -> Dictionary:
	return _applied


func center_diameter() -> float:
	return CENTER_DIAMETER_COMPACT if _compact else CENTER_DIAMETER


## Madalyon çapı (merkez: büyük daire; yan: seçiliyse büyük).
func medallion_diameter() -> float:
	if _center:
		return center_diameter()
	return MEDALLION_SELECTED if _selected else MEDALLION


## Madalyon dikdörtgeni (yüz + dudak, öğe koordinatı) — testler ve çizim.
func highlight_rect() -> Rect2:
	var d: float = medallion_diameter()
	var top: float
	if _center:
		top = (_tray_top - CENTER_RISE) if not _compact else (_tray_top + COMPACT_CIRCLE_TOP)
	else:
		top = _tray_top + (MEDALLION_TOP_SELECTED if _selected else MEDALLION_TOP)
	return Rect2(Vector2((size.x - d) * 0.5, top), Vector2(d, d + _lip_rest()))


## Dokunma alanı: tepsi üstündeki şeritte yalnız görünen kontrol (merkez daire / seçili madalyon payı) dokunuş alır;
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
	# Kompakt kipte kabuğun payı taşmayı içermez: seçili madalyonun yükselen payı yalnız görseldir.
	return point.y >= _tray_top - (TILE_RISE if _selected and not _compact else 0.0)


func _lip_rest() -> float:
	return UiTokens.LIP_REST if _center else MEDALLION_LIP


func _apply() -> void:
	_applied = selected_family() if _selected else {}
	if _icon != null:
		_icon.self_modulate = UiTokens.NAV_MEDALLION_ICON
	var label_color: Color = _applied["label"] if _selected else UiTokens.NAV_LABEL_IDLE
	_label.add_theme_color_override("font_color", label_color)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0) if _selected else UiTokens.TEXT_SHADOW)
	modulate.a = 0.45 if disabled else 1.0
	_place()
	queue_redraw()


func _place() -> void:
	if _label == null:
		return
	var circle: Rect2 = highlight_rect()
	var d: float = medallion_diameter()
	var drop: float = face_offset()
	var icon_center := Vector2(size.x * 0.5, circle.position.y + d * 0.5 + drop)
	if _center:
		_label.position = Vector2(0.0, circle.end.y - 2.0) if not _compact \
			else Vector2(0.0, maxf(circle.end.y - 6.0, _tray_top + SIDE_LABEL_Y))
	else:
		_label.position = Vector2(0.0, _tray_top + SIDE_LABEL_Y - (2.0 if _selected else 0.0))
	_label.size = Vector2(size.x, LABEL_HEIGHT)
	if _avatar != null:
		# Avatar madalyonun yüzü: aynı çapta (ölçekle), aynı kenar / dudak / gölge NavItem'dan.
		var k: float = d / AVATAR
		_avatar.size = Vector2(AVATAR, AVATAR)
		_avatar.pivot_offset = Vector2.ZERO
		_avatar.scale = Vector2(k, k)
		_avatar.position = icon_center - Vector2(d, d) * 0.5
	else:
		var icon_box: float
		if _center:
			icon_box = CENTER_ICON_COMPACT if _compact else CENTER_ICON
		else:
			icon_box = ICON_SELECTED if _selected else ICON
		_icon.size = Vector2(icon_box, icon_box)
		_icon.position = icon_center - Vector2(icon_box, icon_box) * 0.5
	_badge.place_at(icon_center + Vector2(d * 0.42, -d * 0.40))


func _draw() -> void:
	var circle: Rect2 = highlight_rect()
	var d: float = medallion_diameter()
	var rest: float = _lip_rest()
	var lip_now: float = UiTokens.LIP_PRESSED if _pressed_visual else rest
	var c := Vector2(size.x * 0.5, circle.position.y + (d + rest) * 0.5)
	if not _applied.is_empty():
		# Seçili aile: aynı sıcak hale + aynı krem kaide halkası; merkeze özgü tek ek katman ince altın halka.
		var plinth: float = PLINTH_RING_SIDE
		if _center:
			plinth = PLINTH_RING_COMPACT if _compact else PLINTH_RING
		_draw_glow(circle.grow(plinth), d)
		if _center:
			UiKit.draw_candy_circle(self, c, d + (plinth + PREMIUM_RING) * 2.0, UiTokens.GOLD_BRIGHT,
				UiTokens.GOLD_DEEP, lip_now, rest, UiTokens.DEPTH_RESTING, Color(0, 0, 0, 0), 0.0, 0.0)
		UiKit.draw_candy_circle(self, c, d + plinth * 2.0, _applied["fill"], _applied["deep"], lip_now, rest,
			{} if _center else UiTokens.DEPTH_RESTING, Color(0, 0, 0, 0), 0.0, 0.45)
	elif _pressed_visual and not _center:
		# Basılı (seçili değil): seçili ailenin krem kaidesinin yarı saydam önizlemesi (dudağı çökmüş).
		var fam: Dictionary = selected_family()
		UiKit.draw_candy_circle(self, c, d + PRESS_RING * 2.0, Color(fam["fill"], PRESS_PREVIEW_ALPHA),
			Color(fam["deep"], PRESS_PREVIEW_ALPHA), lip_now, rest, {}, Color(0, 0, 0, 0), 0.0, 0.0)
	# Madalyon: vurgu yüz + koyu dudak + beyaz kenar (seçiliyken / basılıyken kenarı kaide üstlenir).
	var face: Color = _accent.lerp(Color.WHITE, PRESS_BRIGHTEN) if _pressed_visual else _accent
	var rim_w: float = 0.0 if _selected or (_pressed_visual and not _center) else MEDALLION_RIM
	var depth: Dictionary = {} if _selected else UiTokens.DEPTH_RESTING
	if _center and not _selected:
		depth = UiTokens.DEPTH_ELEVATED
	UiKit.draw_candy_circle(self, c, d, face, _accent_deep, lip_now, rest, depth, UiTokens.NAV_MEDALLION_RIM, rim_w,
		0.0 if _avatar != null else 0.32)
	if not _applied.is_empty():
		# Etiket aynı krem malzemede (seçili ailesi) — tepsinin içinde küçük hap.
		var w: float = minf(_label.get_minimum_size().x + 20.0, size.x - 4.0)
		var pill := Rect2(Vector2((size.x - w) * 0.5, _label.position.y + 1.0), Vector2(w, LABEL_HEIGHT - 1.0))
		UiKit.draw_candy(self, pill, _applied["fill"], _applied["deep"], LABEL_HEIGHT * 0.5, 3.0, 3.0, {},
			Color(0, 0, 0, 0), 0.0, 0.0)


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
