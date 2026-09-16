class_name HomeFeatureButton
extends Button
## Ana Sayfa hub madalyonu (M8.6-03B): yüzen yuvarlak özellik butonu —
## Günlük / Koleksiyon / Mağaza / Bonus sandık. Gameplay HUD'un güç slotuyla
## AYNI malzeme ailesi (candy medallion), farklı rol.
##
## Anatomi (arkadan öne):
##   erik gölge → açık lavanta dış halka → koyu lavanta halka → krem
##   `btn_circle` gövde (ButtonFeature) → cam-mavi iç yuva → alt gölge +
##   üst gloss → OWNER sanatı (picto değil) → sağ üstte altın rozet YA DA
##   pembe bildirim noktası → çevrede ince ilerleme halkası (isteğe bağlı)
##   → altta koyu lavanta etiket plakası (PanelFeaturePlaque).
##
## Buton dikdörtgeni yalnız madalyon (96×100 ≥ 48 dokunma hedefi); etiket
## plakası gövdeden aşağı taşan dekor (dokunma almaz). Basış squash
## `UiMotion.attach_press` (0.94 + yay). Kilitli: pasif gövde, soluk sanat,
## kilit rozeti, `disabled`.
##
## Kural: dört madalyon bu TEK bileşenden; ekran kodu halka/gloss kurmaz.

const SIZE: Vector2 = Vector2(96.0, 100.0)
## Etiket plakasının gövdeden aşağı taşması (gövdenin alt dudağına biner).
const PLAQUE_OVERLAP: float = 10.0
const PLAQUE_HEIGHT: float = 30.0
const ART_SIZE: float = 58.0
## Picto kuyusu (owner sanatı olmayan sistemler).
const WELL_SIZE: float = 56.0
## İlerleme halkası: açık lavanta dış halkanın üstünde (gövde 48 + koyu
## halka 4 + açık halka 8 → 52..60 bandı).
const RING_RADIUS: float = 56.0
const RING_WIDTH: float = 6.0
## Bildirim noktası (krem halka + pembe çekirdek).
const DOT_SIZE: float = 34.0

var _rim_light: NinePatchRect
var _rim_deep: NinePatchRect
var _glass: NinePatchRect
var _gloss: NinePatchRect
var _art: TextureRect
var _badge: PanelContainer
var _badge_label: Label
var _dot: Control
var _lock: PanelContainer
var _plaque: Control
var _plaque_body: PanelContainer
var _plaque_label: Label
var _ring: ProgressRing
var _well: Control
var _well_body: NinePatchRect
var _well_base: NinePatchRect
var _well_icon: TextureRect
var _locked: bool = false
var _notification: bool = false


## Madalyon çevresinde ince ilerleme yayı (üstten saat yönünde). Ray koyu
## lavanta, dolgu `tint` (nane: koleksiyon, altın: sandık ödülü).
class ProgressRing extends Control:
	var ratio: float = 0.0
	var tint: Color = UiTokens.MINT

	func _draw() -> void:
		if ratio < 0.0:
			return
		var center: Vector2 = size * 0.5 - Vector2(0.0, 2.0)
		draw_arc(center, RING_RADIUS, 0.0, TAU, 64, Color(UiTokens.LAVENDER_DEEP, 0.55), RING_WIDTH, true)
		if ratio > 0.0:
			var start: float = -PI * 0.5
			draw_arc(center, RING_RADIUS, start, start + TAU * clampf(ratio, 0.0, 1.0), 64, tint, RING_WIDTH, true)


static func create(art_tex: Texture2D, label_text: String) -> HomeFeatureButton:
	var node := HomeFeatureButton.new()
	node.set_art(art_tex)
	node.set_label(label_text)
	return node


func _init() -> void:
	theme_type_variation = &"ButtonFeature"
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = SIZE
	# Gölge: erik, yumuşak, 6 px aşağı (HUD v5 hud_shadow reçetesi).
	UiKit.hud_shadow(self, 6.0, 0.28, null, 16.0)
	# Dış halka: açık lavanta (en dışta) + koyu lavanta (gövdeye bitişik).
	_rim_light = _ring_patch(UiTokens.LAVENDER_LIGHT, 8.0)
	_rim_deep = _ring_patch(UiTokens.LAVENDER_DEEP, 4.0)
	# İlerleme halkası gövdenin arkasında, halkaların üstünde: dış halkanın
	# üstüne oturan ince yay.
	_ring = ProgressRing.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring.show_behind_parent = true
	_ring.ratio = -1.0
	add_child(_ring)
	# Cam iç yuva (güç slotuyla aynı ton), altında yumuşak derinlik.
	_glass = UiKit.patch("item_circle_inner", UiTokens.GLASS_BLUE)
	_glass.offset_left = SIZE.x * 0.12
	_glass.offset_right = -SIZE.x * 0.12
	_glass.offset_top = SIZE.y * 0.10
	_glass.offset_bottom = -SIZE.y * 0.22
	add_child(_glass)
	var shade := UiKit.patch("item_circle_inner", Color(0.35, 0.25, 0.5, 0.14))
	shade.offset_left = SIZE.x * 0.11
	shade.offset_right = -SIZE.x * 0.11
	shade.offset_top = SIZE.y * 0.30
	shade.offset_bottom = -SIZE.y * 0.12
	add_child(shade)
	_gloss = UiKit.patch("item_circle_inner", Color(1, 1, 1, 0.40))
	_gloss.offset_left = SIZE.x * 0.15
	_gloss.offset_right = -SIZE.x * 0.15
	_gloss.offset_top = SIZE.y * 0.06
	_gloss.offset_bottom = -SIZE.y * 0.44
	add_child(_gloss)
	# Owner sanatı: görsel merkez alt dudağın üstünde (hafif yukarı).
	_art = UiKit.art(null, ART_SIZE)
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_art.offset_left = -ART_SIZE * 0.5
	_art.offset_right = ART_SIZE * 0.5
	_art.offset_top = -ART_SIZE * 0.5 - 6.0
	_art.offset_bottom = ART_SIZE * 0.5 - 6.0
	add_child(_art)
	# Altın rozet (sağ üst): "6/20", "49/75".
	_badge = UiKit.panel(&"Badge")
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.custom_minimum_size = Vector2(36.0, 26.0)
	_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_badge.grow_vertical = Control.GROW_DIRECTION_END
	_badge.offset_left = 12.0
	_badge.offset_right = 12.0
	_badge.offset_top = -8.0
	_badge.offset_bottom = -8.0
	_badge_label = UiKit.label("", &"LabelBadge", HORIZONTAL_ALIGNMENT_CENTER)
	_badge_label.add_theme_font_size_override("font_size", 15)
	_badge.add_child(_badge_label)
	_badge.visible = false
	add_child(_badge)
	# Bildirim noktası (sağ üst): krem halka + pembe nokta — "alınacak var".
	_dot = Control.new()
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
	var dot_ring := UiKit.art(UiKit.texture("alert_dot_ring"), DOT_SIZE, UiTokens.CREAM)
	dot_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dot.add_child(dot_ring)
	var dot_core := UiKit.art(UiKit.texture("alert_dot"), DOT_SIZE * 0.56, UiTokens.PINK)
	dot_core.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dot_core.offset_left = -DOT_SIZE * 0.28
	dot_core.offset_right = DOT_SIZE * 0.28
	dot_core.offset_top = -DOT_SIZE * 0.28
	dot_core.offset_bottom = DOT_SIZE * 0.28
	_dot.add_child(dot_core)
	_dot.pivot_offset = Vector2(DOT_SIZE, DOT_SIZE) * 0.5
	_place_dot()
	_dot.visible = false
	add_child(_dot)
	# Kilit rozeti (kilitli durumda, sağ alt).
	_lock = UiKit.badge("", &"LockBadge", "lock")
	_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_lock.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_lock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_lock.offset_left = 8.0
	_lock.offset_right = 8.0
	_lock.offset_top = -10.0
	_lock.offset_bottom = -10.0
	_lock.visible = false
	add_child(_lock)
	# Etiket plakası: gövdenin altına biner, gövdeden geniş olabilir
	# (KOLEKSİYON), yatayda ortalanır. Sarmalayıcı düz Control: açık kenar
	# halkası (NinePatchRect) bir PanelContainer'ın İÇİNDE olsaydı patch
	# kenarları (56×53) plakanın minimumunu şişirirdi.
	_plaque = Control.new()
	_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque.anchor_left = 0.5
	_plaque.anchor_right = 0.5
	_plaque.anchor_top = 1.0
	_plaque.anchor_bottom = 1.0
	_plaque.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_plaque.grow_vertical = Control.GROW_DIRECTION_END
	_plaque.offset_top = -PLAQUE_OVERLAP
	_plaque.offset_bottom = -PLAQUE_OVERLAP + PLAQUE_HEIGHT
	# Açık kenar (HUD plakası dili), gövdenin arkasında. NinePatchRect DEĞİL:
	# `title_oval` patch kenarları (56×53) 30 px plakadan büyük olduğu için
	# NinePatchRect kendini küçültemez; StyleBoxTexture'lı boş PanelContainer
	# istenen ölçüde çizer.
	var plaque_rim := UiKit.flat_plate("badge_round", UiTokens.LAVENDER_LIGHT)
	plaque_rim.offset_left = -2.0
	plaque_rim.offset_top = -2.0
	plaque_rim.offset_right = 2.0
	plaque_rim.offset_bottom = 2.0
	_plaque.add_child(plaque_rim)
	_plaque_body = UiKit.panel(&"PanelFeaturePlaque")
	_plaque_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plaque.add_child(_plaque_body)
	_plaque_label = UiKit.label("", &"LabelBadgeOnDark", HORIZONTAL_ALIGNMENT_CENTER)
	_plaque_label.add_theme_font_size_override("font_size", 14)
	_plaque_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plaque_body.add_child(_plaque_label)
	add_child(_plaque)
	_plaque_body.minimum_size_changed.connect(_layout_plaque)
	UiMotion.attach_press(self)


func _ready() -> void:
	_layout_plaque()


func _ring_patch(tint: Color, width: float) -> NinePatchRect:
	var rim := UiKit.patch("btn_circle_flat", tint)
	rim.show_behind_parent = true
	rim.offset_left = -width
	rim.offset_top = -width
	rim.offset_right = width
	# btn_circle'ın alt dudağı: halka altta daha az taşar.
	rim.offset_bottom = width - 4.0
	add_child(rim)
	return rim


## Plaka yatayda ortalanır; genişliği içeriğe göre (min gövde + 8).
func _layout_plaque() -> void:
	var w: float = maxf(_plaque_body.get_combined_minimum_size().x + 6.0, SIZE.x + 8.0)
	_plaque.offset_left = -w * 0.5
	_plaque.offset_right = w * 0.5


# --- Durum -------------------------------------------------------------------

func set_art(tex: Texture2D) -> void:
	_art.texture = tex
	_art.self_modulate = Color.WHITE if not _locked else Color(0.86, 0.84, 0.94, 0.62)
	if _well != null:
		_well.visible = false


## Owner sanatı olmayan sistemler (Günlük, Mağaza): renkli candy kuyu +
## beyaz generic picto. Kuyu rengi sistemin rengi (Günlük pembe, Mağaza
## cyan) — madalyon glass yuvasının içinde küçük bir "buton" gibi durur.
func set_icon(role: String, tint: Color) -> void:
	if _well == null:
		_well = Control.new()
		_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_well.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_well.offset_left = -WELL_SIZE * 0.5
		_well.offset_right = WELL_SIZE * 0.5
		_well.offset_top = -WELL_SIZE * 0.5 - 6.0
		_well.offset_bottom = WELL_SIZE * 0.5 - 6.0
		# Candy kubbe: koyu taban (3 px aşağı, derinlik) + renkli gövde + ince
		# krem kenar + üst gloss — cam yuvanın içinde "oturmuş" küçük buton.
		_well_base = UiKit.patch("btn_circle_flat", tint.darkened(0.30))
		_well_base.offset_top = 3.0
		_well_base.offset_bottom = 3.0
		_well.add_child(_well_base)
		var edge := UiKit.patch("btn_circle_flat", Color(1, 1, 1, 0.55))
		edge.offset_left = -2.0
		edge.offset_top = -2.0
		edge.offset_right = 2.0
		edge.offset_bottom = 1.0
		_well.add_child(edge)
		_well_body = UiKit.patch("btn_circle_flat", tint)
		_well.add_child(_well_body)
		var light := UiKit.patch("item_circle_inner", Color(1, 1, 1, 0.36))
		light.offset_left = WELL_SIZE * 0.14
		light.offset_right = -WELL_SIZE * 0.14
		light.offset_top = WELL_SIZE * 0.07
		light.offset_bottom = -WELL_SIZE * 0.50
		_well.add_child(light)
		_well_icon = UiKit.icon(role, WELL_SIZE * 0.62, UiTokens.TEXT_ON_DARK)
		_well_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_well_icon.offset_left = -WELL_SIZE * 0.31
		_well_icon.offset_right = WELL_SIZE * 0.31
		_well_icon.offset_top = -WELL_SIZE * 0.31
		_well_icon.offset_bottom = WELL_SIZE * 0.31
		_well.add_child(_well_icon)
		add_child(_well)
		move_child(_well, _art.get_index() + 1)
	_well_body.self_modulate = tint
	_well_base.self_modulate = tint.darkened(0.30)
	_well_icon.texture = UiKit.icon_texture(role)
	_well.visible = true
	_art.texture = null


## Etiket metni olduğu gibi (büyük harf çağıran verir: Godot'un to_upper'ı
## Türkçe noktalı İ'yi bilmez — "Koleksiyon" → "KOLEKSIYON" olurdu).
func set_label(text: String) -> void:
	_plaque_label.text = text
	_layout_plaque()


## Altın rozet ("6/20"); boş metin gizler. Bildirim noktasıyla aynı köşe:
## rozet varsa nokta rozetin soluna kayar.
func set_badge(text: String) -> void:
	_badge_label.text = text
	_badge.visible = not text.is_empty()
	_place_dot()


## Pembe bildirim noktası: "alınacak/yeni var".
func set_notification(on: bool) -> void:
	_notification = on
	_dot.visible = on
	_place_dot()


func _place_dot() -> void:
	# Rozet görünürken nokta sol üst köşeye geçer (ikisi de okunur kalsın).
	if _badge.visible:
		_dot.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_dot.offset_left = -10.0
		_dot.offset_right = -10.0 + DOT_SIZE
	else:
		_dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_dot.offset_left = -DOT_SIZE + 10.0
		_dot.offset_right = 10.0
	_dot.offset_top = -8.0
	_dot.offset_bottom = -8.0 + DOT_SIZE


## İlerleme halkası: 0..1 dolu yay; negatif = halka yok.
func set_progress(ratio: float, tint: Color = UiTokens.MINT) -> void:
	_ring.ratio = ratio
	_ring.tint = tint
	_ring.queue_redraw()


## Kilitli/pasif: açık lavanta gövde, cam yuva soluk, sanat soluk, kilit
## rozeti; buton `disabled` (basış/ses yok). Rozet ve bildirim gizlenir.
func set_locked(on: bool) -> void:
	_locked = on
	disabled = on
	theme_type_variation = &"ButtonFeatureLocked" if on else &"ButtonFeature"
	_glass.self_modulate = UiTokens.GLASS_MUTED if on else UiTokens.GLASS_BLUE
	_rim_deep.self_modulate = UiTokens.DISABLED if on else UiTokens.LAVENDER_DEEP
	_art.self_modulate = Color(0.86, 0.84, 0.94, 0.62) if on else Color.WHITE
	if _well != null:
		_well.modulate = Color(0.86, 0.84, 0.94, 0.62) if on else Color.WHITE
	_lock.visible = on
	if on:
		_badge.visible = false
		_dot.visible = false
	else:
		_badge.visible = not _badge_label.text.is_empty()
		_dot.visible = _notification
	_plaque.modulate.a = 0.75 if on else 1.0


func is_locked() -> bool:
	return _locked


func has_notification() -> bool:
	return _notification


func badge_text() -> String:
	return _badge_label.text if _badge.visible else ""


func label_text() -> String:
	return _plaque_label.text


func progress() -> float:
	return _ring.ratio


## Bildirim noktası (nabız için).
func notification_dot() -> Control:
	return _dot


## Etiket plakası dahil görsel dikdörtgen (tuval koordinatı) — çakışma testi.
func visual_rect() -> Rect2:
	var rect: Rect2 = get_global_rect()
	return rect.merge(_plaque.get_global_rect())
