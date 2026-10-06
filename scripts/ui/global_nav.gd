class_name GlobalNav
extends CanvasLayer
## Squishy UI System V3 (TASK/057) — küresel gezinme kabuğu (hub ekranları arası kalıcı alt gezinme).
##
## Oyuncu Mağaza / Koleksiyon / Profil / Harita arasında Ana Sayfa'ya dönmeden geçer (Product Vision V3
## §8). Beş hedef = Main'in GERÇEK beş ekranı (`_screens` indeksleri; yeni rota icat edilmedi):
##
##   ANA SAYFA (0) · MAĞAZA (3) · [ HARİTA (1) ] · KOLEKSİYON (2) · PROFİL (4)
##
## Merkez HARİTA büyük cyan daire (oyunun ana yolu; Ana Sayfa'nın OYNA'sıyla aynı hedef), yan öğeler
## kalıcı lavanta candy tepside; seçili yan öğe tepsiden yükselen krem karo. Profil öğesi oyuncunun
## avatarı (vitrinin ilk parçası).
##
## SAHİPLİK: görünürlük ve seçili hedef Main'indir (`Main._sync_nav`): yalnız bir hub ekranı açıkken ve
## hiçbir engelleyici pencere (Main pencereleri, ekran içi pencere, yaş ekranı, oyun / sonuç / mola /
## tutorial) yokken görünür. Bu düğüm yalnız `destination_requested(tab)` yayar; aynı hedefe ikinci
## gezinme, yinelenen rota ve bayat dokunuş Main'de / GestureGuard'da kesilir.
##
## Katman 6: hub ekranlarının (5) üstünde, tutorial (8), sonuç (10) ve tüm pencerelerin (11–14) altında.
## Yerleşim: tepsi alt kenarı = ekran altı − `UiKit.bottom_inset` (gesture bar + banner yuvası) − `bottom_gap()`
## (banner yuvası varsa BANNER_GAP: tepsinin dokunulan öğeleri reklamın hemen üstüne oturmaz — kazara reklam
## tıklaması riski; uyum değerlendirmesi owner'da AÇIK). Konum SEKMELER ARASINDA SABİT (banner'sız sekmede de
## zıplamaz). Tepsinin arkasında opak DOCK: tepsi üst kenarının biraz üstünden ekran altına (banner yuvası
## dahil) solan koyu taban — kaydırılan içerik tepsinin altında / yanında görünmez, dokunuş almaz (STOP); gerçek
## banner (native görünüm) yuvada dock'un üstüne çizilir. Hub ekranları içeriği `reserve()` kadar yukarıda
## bitirir (Main `set_nav_inset` ile verir).

signal destination_requested(tab: int)

const LAYER: int = 6
## Görünen sıra: [ekran indeksi, etiket, picto rolü, merkez mi, avatar mı].
const DESTINATIONS: Array = [
	[0, "ANA SAYFA", "home", false, false],
	[3, "MAĞAZA", "shop", false, false],
	[1, "HARİTA", "map", true, false],
	[2, "KOLEKSİYON", "collection", false, false],
	[4, "PROFİL", "", false, true],
]
const TRAY_HEIGHT: float = 92.0
const SIDE_MARGIN: float = 12.0
## Tepsi ile ekran altı (gesture bar) arası.
const BOTTOM_GAP: float = 8.0
## Banner yuvası varken tepsi ile banner arası (dokunulmayan dock şeridi).
const BANNER_GAP: float = 28.0
const TRAY_PAD_X: float = 6.0
## Tepsi en fazla bu kadar geniş (geniş tuvalde ortalanır).
const TRAY_MAX_WIDTH: float = 696.0
## Dock'un tepsi üst kenarının üstüne solma payı ve tam opaklığa ulaştığı derinlik.
const DOCK_FADE_ABOVE: float = 30.0
const DOCK_SOLID_BELOW: float = 26.0
## Hub içeriğinin bırakması gereken alt pay — banner YOKKEN (banner / gesture bar payının ÜSTÜNE): alt boşluk +
## tepsi + merkez taşması. Banner varken `reserve()` BANNER_GAP ile hesaplar.
const RESERVE: float = BOTTOM_GAP + TRAY_HEIGHT + NavItem.CENTER_RISE

var _root: Control
var _dock: TextureRect
var _dock_block: Control
var _tray: Control
var _items: Dictionary = {}
var _order: Array[NavItem] = []
var _current: int = -1
var _bottom_inset_override: float = -1.0
var _banner_override: float = -1.0


func _init() -> void:
	name = "GlobalNav"
	layer = LAYER
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_dock = TextureRect.new()
	_dock.name = "Dock"
	_dock.texture = _dock_texture()
	_dock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dock.stretch_mode = TextureRect.STRETCH_SCALE
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dock)
	# Tepsi üst kenarından ekran altına: alttaki kaydırılan içeriğe dokunuş sızdırmaz (yan paylar, alt boşluk,
	# banner yuvası). Tepsi üstündeki solma bandı içeriğe açık kalır.
	_dock_block = Control.new()
	_dock_block.name = "DockBlock"
	_dock_block.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dock_block)
	_tray = Control.new()
	_tray.name = "Tray"
	_tray.mouse_filter = Control.MOUSE_FILTER_STOP
	_tray.draw.connect(_draw_tray)
	_root.add_child(_tray)
	for spec in DESTINATIONS:
		var item := NavItem.new(int(spec[0]), String(spec[1]), String(spec[2]), bool(spec[3]), bool(spec[4]))
		var tab: int = int(spec[0])
		GestureGuard.on_pressed(item, func() -> void: destination_requested.emit(tab))
		_root.add_child(item)
		_items[tab] = item
		_order.append(item)
	# Merkez en üstte çizilsin (yan karoların halesi üstüne binmesin).
	_root.move_child(_items[1], _root.get_child_count() - 1)
	_root.resized.connect(relayout)


func _ready() -> void:
	relayout()
	refresh()


# --- API ------------------------------------------------------------------------

## Seçili hedef (Main `_show_tab`'tan). Bilinmeyen indeks hiçbir öğeyi seçmez.
func set_current(tab: int) -> void:
	_current = tab
	for item in _order:
		item.set_selected(item.tab() == tab)


func current() -> int:
	return _current


func item_button(tab: int) -> NavItem:
	return _items.get(tab, null)


func items() -> Array[NavItem]:
	return _order


## Hedefin rozeti (dikkat sistemi; içerik TASK/058/061'de bağlanır).
func badge(tab: int) -> AttentionBadge:
	var item: NavItem = item_button(tab)
	return item.badge() if item != null else null


func set_item_enabled(tab: int, value: bool) -> void:
	var item: NavItem = item_button(tab)
	if item != null:
		item.set_item_enabled(value)


## Tepsi ile alt kenar (banner yuvası / gesture bar) arası: yuva varsa BANNER_GAP.
func bottom_gap() -> float:
	return BANNER_GAP if _banner_slot() > 0.0 else BOTTOM_GAP


## Hub içeriğinin bırakacağı alt pay (`UiKit.bottom_inset`'in ÜSTÜNE).
func reserve() -> float:
	return bottom_gap() + TRAY_HEIGHT + NavItem.CENTER_RISE


## Tepsinin ekran dikdörtgeni (merkez taşması HARİÇ).
func tray_rect() -> Rect2:
	return Rect2(_tray.global_position, _tray.size)


## Kabuğun kapladığı tüm DOKUNMA / içerik alanı (merkez taşması dahil) — içerik bunun üstünde bitmeli. Seçili
## merkezin altın halesi bunun ~20 px üstüne yalnız IŞIK olarak taşar (dokunma almaz, içeriği örtmez).
func footprint() -> Rect2:
	var rect: Rect2 = tray_rect()
	rect.position.y -= NavItem.CENTER_RISE
	rect.size.y += NavItem.CENTER_RISE
	return rect


## Dock'un dokunuş tutan (STOP) bölgesi: tepsi üst kenarından ekran altına.
func dock_block_rect() -> Rect2:
	return Rect2(_dock_block.global_position, _dock_block.size)


## Avatar (Profil öğesi) tazelemesi — vitrin değişince Main çağırır.
func refresh() -> void:
	var profile: NavItem = item_button(4)
	if profile != null and profile.avatar() != null:
		profile.avatar().refresh()


## Test kancası: alt pay (gesture bar + banner yuvası); negatif = gerçek (`UiKit.bottom_inset`).
func set_bottom_inset_override(px: float, banner_px: float = -1.0) -> void:
	_bottom_inset_override = px
	_banner_override = banner_px
	relayout()


func relayout() -> void:
	var view: Vector2 = _root.size
	if view.x <= 0.0 or view.y <= 0.0:
		view = _root.get_viewport_rect().size if _root.is_inside_tree() else Vector2(720.0, 1280.0)
	var inset: float = _bottom_inset_override if _bottom_inset_override >= 0.0 else UiKit.bottom_inset(view)
	var width: float = minf(view.x - SIDE_MARGIN * 2.0, TRAY_MAX_WIDTH)
	var left: float = (view.x - width) * 0.5
	var bottom: float = view.y - inset - bottom_gap()
	var tray_top: float = bottom - TRAY_HEIGHT
	_tray.position = Vector2(left, tray_top)
	_tray.size = Vector2(width, TRAY_HEIGHT)
	_dock.position = Vector2(0.0, tray_top - DOCK_FADE_ABOVE)
	_dock.size = Vector2(view.x, view.y - tray_top + DOCK_FADE_ABOVE)
	var gradient: Gradient = (_dock.texture as GradientTexture2D).gradient
	gradient.offsets = PackedFloat32Array([0.0, clampf((DOCK_FADE_ABOVE + DOCK_SOLID_BELOW) / maxf(_dock.size.y, 1.0),
		0.05, 0.95), 1.0])
	_dock_block.position = Vector2(0.0, tray_top)
	_dock_block.size = Vector2(view.x, view.y - tray_top)
	var slot: float = (width - TRAY_PAD_X * 2.0) / float(_order.size())
	for i in _order.size():
		var item: NavItem = _order[i]
		item.position = Vector2(left + TRAY_PAD_X + slot * float(i), tray_top - NavItem.CENTER_RISE)
		item.size = Vector2(slot, TRAY_HEIGHT + NavItem.CENTER_RISE)
		item.set_tray_top(NavItem.CENTER_RISE)
	_tray.queue_redraw()


func _banner_slot() -> float:
	return _banner_override if _banner_override >= 0.0 else UiKit.banner_slot()


func _draw_tray() -> void:
	UiKit.draw_candy(_tray, Rect2(Vector2.ZERO, _tray.size), UiTokens.NAV_TRAY, UiTokens.NAV_TRAY_DEEP,
		UiTokens.RADIUS_MODAL, UiTokens.LIP_REST, UiTokens.LIP_REST, UiTokens.DEPTH_FLOATING,
		UiTokens.LAVENDER_LIGHT, float(UiTokens.BORDER_STANDARD), 0.07, 0.26)


## Dock dokusu: üstte saydam → tepsi gövdesi hizasında koyu dünya rengi (solma oranı yerleşimde ayarlanır).
static func _dock_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	gradient.colors = PackedColorArray([Color(UiTokens.NAV_DOCK, 0.0), UiTokens.NAV_DOCK, UiTokens.NAV_DOCK])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 8
	tex.height = 256
	return tex
