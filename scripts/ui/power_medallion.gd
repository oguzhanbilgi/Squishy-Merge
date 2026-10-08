class_name PowerMedallion
extends Button
## TASK/060 Gameplay HUD V3 — oyun içi güç madalyonu (TEXT-LIGHT / ICON-FIRST). Eski M8.6-02 slotu (tepsi + yuva +
## krem/altın halka + cam disk + "×N" rozeti: çerçeve-içinde-çerçeve) yerine tek candy madalyon:
##
##   ╭─────────╮   gücün VURGU renginde candy gövde (V3 `UiKit.draw_candy_circle`: dudak + yüz + gloss + krem halka
##   │  (güç)  │   + erik derinlik), büyük OWNER güç sanatı, sağ altta stok kabarcığı — YALNIZ rakam ("0", "1", "3";
##   ╰──────③──╯   "x1" / "×1" yok — Product Vision V3 §3).
##
## Durumlar: NORMAL · SİLAHLI (Bomba / Büyütücü hedeflemede: kalın CYAN halka + parlak cyan hale — board'daki hedef
## vurgusuyla aynı renk dili) ·
## STOK 0 (gövde lavantaya solar, sanat kimliğini koruyarak soluk, kabarcık gri "0" — basış refill penceresi) ·
## KAPALI (`disabled`, %55 — mola / pencere dondurması / meydan okuma kilidi) · BASILI (yüz dudağa iner + UiMotion
## squash). Dokunma alanı = düğme dikdörtgeni (HUD yerleşiminin slot dikdörtgeni, ≥ UiTokens.TOUCH_TARGET her iki
## boyutta); görsel gövde onun İÇİNDE ortalı — dokunma haritası görselle aynı yerde.
## Davranış (basış, GestureGuard, stok okuma) PowerBar'da; bu bileşen YALNIZ çizer.

const BODY_INSET: float = 4.0
const LIP_REST: float = 6.0
const LIP_PRESSED: float = 2.0
const RIM: float = 3.0
const RIM_ARMED: float = 6.0
const ART_SHARE: float = 0.84
const STOCK_SIZE: float = 36.0
const STOCK_FONT: int = 22

var _type: PowerUp.Type = PowerUp.Type.BOMB
var _count: int = 0
var _armed: bool = false
var _pressed_visual: bool = false
var _glow: NinePatchRect
var _art: TextureRect
var _stock: Control
var _stock_label: Label


func _init(type: int = PowerUp.Type.BOMB, count: int = 0, slot_size: Vector2 = Vector2(86.0, 92.0)) -> void:
	_type = type as PowerUp.Type
	theme_type_variation = &"PowerSlot"
	focus_mode = Control.FOCUS_NONE
	text = ""
	custom_minimum_size = slot_size
	for style_name in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	set_meta(&"power_slot", true)
	# Silahlı hale: gövdenin ARKASINDA yumuşak cyan blob (neon çerçeve değil).
	_glow = UiKit.patch("popup_glow", Color(UiTokens.CYAN, 1.0))
	_glow.name = "Glow"
	_glow.show_behind_parent = true
	_glow.offset_left = -24.0
	_glow.offset_top = -22.0
	_glow.offset_right = 24.0
	_glow.offset_bottom = 18.0
	_glow.visible = false
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)
	_art = TextureRect.new()
	_art.name = "Art"
	_art.texture = PowerUp.icon(_type)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_stock = Control.new()
	_stock.name = "Stock"
	_stock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stock.size = Vector2(STOCK_SIZE, STOCK_SIZE)
	_stock.draw.connect(_draw_stock)
	add_child(_stock)
	_stock_label = UiType.v3_label("0", UiType.V3_BUTTON, true, HORIZONTAL_ALIGNMENT_CENTER, STOCK_FONT)
	_stock_label.name = "Count"
	_stock_label.size = Vector2(STOCK_SIZE, STOCK_SIZE - 2.0)
	_stock_label.position = Vector2(0.0, -3.0)
	_stock.add_child(_stock_label)
	set_meta(&"glow", _glow)
	set_meta(&"art", _art)
	set_meta(&"badge", _stock)
	set_meta(&"badge_label", _stock_label)
	button_down.connect(func() -> void: _set_pressed_visual(true))
	button_up.connect(func() -> void: _set_pressed_visual(false))
	resized.connect(_place)
	UiMotion.attach_press(self)
	set_state(count, false, true)


## Durum: stok (yalnız rakam), silahlı, etkin. Stok 0'da da basılabilir (refill akışı).
func set_state(count: int, armed: bool, enabled: bool) -> void:
	_count = maxi(count, 0)
	_armed = armed and _count > 0
	set_meta(&"count", _count)
	theme_type_variation = &"PowerSlotArmed" if _armed else (&"PowerSlotEmpty" if _count <= 0 else &"PowerSlot")
	disabled = not enabled
	modulate.a = 1.0 if enabled else 0.55
	_glow.visible = _armed and enabled
	_stock_label.text = str(_count)
	_stock_label.add_theme_color_override("font_color", UiTokens.TEXT_ON_DARK)
	_art.self_modulate = Color(0.86, 0.84, 0.94, 0.72) if _count <= 0 else Color.WHITE
	if disabled and _pressed_visual:
		_set_pressed_visual(false)
	_place()
	queue_redraw()
	_stock.queue_redraw()


func power_type() -> PowerUp.Type:
	return _type


func count() -> int:
	return _count


## Kabarcıkta gösterilen metin (testler: YALNIZ rakam).
func count_text() -> String:
	return _stock_label.text


func is_armed() -> bool:
	return _armed


func is_pressed_visual() -> bool:
	return _pressed_visual


## Görsel gövde dairesi (kontrol koordinatı; dudak hariç yüz).
func body_rect() -> Rect2:
	var d: float = _diameter()
	var lip_drop: float = (LIP_REST - (LIP_PRESSED if _pressed_visual else LIP_REST))
	return Rect2(Vector2((size.x - d) * 0.5, BODY_INSET + lip_drop), Vector2(d, d))


## Stok kabarcığının dikdörtgeni (kontrol koordinatı).
func stock_rect() -> Rect2:
	return Rect2(_stock.position, _stock.size)


func _diameter() -> float:
	return maxf(minf(size.x - BODY_INSET * 2.0, size.y - BODY_INSET * 2.0 - LIP_REST), 8.0)


func _place() -> void:
	if _art == null:
		return
	var body: Rect2 = body_rect()
	var art_size: float = body.size.x * ART_SHARE
	_art.size = Vector2(art_size, art_size)
	_art.position = body.get_center() - Vector2(art_size, art_size) * 0.5 - Vector2(0.0, 2.0)
	_stock.position = Vector2(size.x - STOCK_SIZE + 2.0, size.y - STOCK_SIZE - 1.0)
	pivot_offset = size * 0.5


func _palette() -> Array:
	var accent: Color = PowerUp.accent(_type)
	if _count <= 0:
		var face: Color = accent.lerp(UiTokens.LAVENDER_SURFACE, 0.62)
		return [face, face.darkened(0.30), UiTokens.LAVENDER_LIGHT, RIM]
	if _armed:
		return [accent.lightened(0.12), accent.darkened(0.32), UiTokens.CYAN, RIM_ARMED]
	return [accent, accent.darkened(0.32), UiTokens.CREAM, RIM]


func _draw() -> void:
	var pal: Array = _palette()
	var d: float = _diameter()
	var lip: float = LIP_PRESSED if _pressed_visual else LIP_REST
	var center := Vector2(size.x * 0.5, BODY_INSET + (d + LIP_REST) * 0.5)
	UiKit.draw_candy_circle(self, center, d, pal[0], pal[1], lip, LIP_REST, UiTokens.DEPTH_RESTING, pal[2],
		float(pal[3]), UiTokens.GLOSS_ALPHA * 1.15)


func _draw_stock() -> void:
	var color: Color = UiTokens.NAVY_PURPLE if _count > 0 else UiTokens.ROLE_DISABLED
	UiKit.draw_candy_circle(_stock, Vector2(STOCK_SIZE, STOCK_SIZE) * 0.5 - Vector2(0.0, 1.0), STOCK_SIZE - 4.0,
		color, color.darkened(0.35), 3.0, 3.0, {}, Color.WHITE, 2.5, 0.22)


func _set_pressed_visual(value: bool) -> void:
	_pressed_visual = value and not disabled
	_place()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and _pressed_visual:
		_set_pressed_visual(false)
	elif what == NOTIFICATION_SCROLL_BEGIN and _pressed_visual:
		_set_pressed_visual(false)
