class_name ScreenTopBar
extends Control
## İkincil ekran üst satırı (M8.6-04, ilk kullanım: Harita). Home'un üst
## satırıyla AYNI geometri ve malzeme (56 px satır, 24 px kenar payı, cihaz
## üst güvenli payı) — ekranlar arasında geçiş "aynı ürün" okunsun:
##
##   SOL    `UiKit.home_icon_button("back")` → `back_pressed` (Ana Sayfa)
##   ORTA   pembe başlık kurdelesi (`HeaderRibbon`, pencere başlıklarıyla
##          aynı kimlik parçası; dashboard başlığı değil) — ekran adı
##   SAĞ    `UiKit.home_pill(Hamur, değer, "+")` → `add_pressed` (Mağaza);
##          Mağaza'nın kendisinde "+" YOK (`with_add = false`, M8.6-05): pill
##          yalnız bakiye gösterir — kendine giden ölü bir rota olmasın.
##
## Sekme çubuğu göçü (UI_VISUAL_SYSTEM §14.4): her ikincil ekran bu satırı
## alınca alt çubuk o ekranda kalkar. Mağaza/Koleksiyon kendi işlerinde.
## Yerleşim `layout(view_width, safe_top)` ile çağırandan; kurdele ekranda
## ortalanır, sağ pill büyürse (99999 Hamur) kurdele sola kayar, çakışmaz.

signal back_pressed
signal add_pressed

const ROW_HEIGHT: float = 56.0
const TOP_MARGIN: float = 14.0
const SIDE_MARGIN: float = 24.0
const GAP: float = 12.0
## Kurdele satırdan 6 px taşar (üst 3 / alt 3): 70 px'lik sprite 62'de
## doğal oranına yakın kalır.
const RIBBON_HEIGHT: float = 62.0
const RIBBON_MIN_WIDTH: float = 200.0
const DOUGH_ART: Texture2D = preload("res://assets/visual/ui/icon_dough.png")

var _back: Button
var _ribbon: PanelContainer
var _pill: Control
var _safe_top: float = 0.0


func _init(title: String = "", with_add: bool = true) -> void:
	name = "TopBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back = UiKit.home_icon_button("back", ROW_HEIGHT)
	_back.name = "Back"
	_back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(_back)
	_pill = UiKit.home_pill(DOUGH_ART, "0", with_add, ROW_HEIGHT)
	_pill.name = "DoughPill"
	if with_add:
		(_pill.get_meta(&"add_button") as Button).pressed.connect(func() -> void: add_pressed.emit())
	_pill.minimum_size_changed.connect(_relayout)
	add_child(_pill)
	_ribbon = UiKit.header_ribbon(title)
	_ribbon.name = "Title"
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text: Label = _ribbon.get_meta(&"title_label")
	text.add_theme_font_size_override("font_size", 26)
	# Kurdele: erik gölge (HUD dili) — düz yapıştırılmış görünmesin.
	UiKit.hud_shadow(_ribbon, 5.0, 0.24, null, 12.0)
	add_child(_ribbon)
	resized.connect(_relayout)


## Satırı `view_width` genişliğinde, `safe_top` (punch-hole) altına kurar.
## Kontrolün kendi dikdörtgeni satırı + gölge payını kaplar.
func layout(view_width: float, safe_top: float) -> void:
	_safe_top = maxf(safe_top, 0.0)
	position = Vector2.ZERO
	size = Vector2(view_width, height())
	_relayout()


## Satırın kapladığı yükseklik (güvenli pay dahil, gölge hariç).
func height() -> float:
	return _safe_top + TOP_MARGIN + ROW_HEIGHT


func _relayout() -> void:
	var w: float = size.x
	if w <= 0.0:
		return
	var top: float = _safe_top + TOP_MARGIN
	_back.position = Vector2(SIDE_MARGIN, top)
	_back.size = Vector2(ROW_HEIGHT, ROW_HEIGHT)
	var pill_size: Vector2 = _pill.custom_minimum_size
	_pill.size = pill_size
	_pill.position = Vector2(w - SIDE_MARGIN - pill_size.x, top + (ROW_HEIGHT - pill_size.y) * 0.5)
	# Kurdele: içerik genişliği (min 200), ekran ortasında; sağ pill ile
	# arasında en az GAP kalmazsa sola kayar (sol butonla arası da GAP).
	var ribbon_w: float = maxf(_ribbon.get_combined_minimum_size().x, RIBBON_MIN_WIDTH)
	var left_limit: float = SIDE_MARGIN + ROW_HEIGHT + GAP
	var right_limit: float = _pill.position.x - GAP
	var x: float = (w - ribbon_w) * 0.5
	x = minf(x, right_limit - ribbon_w)
	x = maxf(x, left_limit)
	_ribbon.position = Vector2(x, top + (ROW_HEIGHT - RIBBON_HEIGHT) * 0.5)
	_ribbon.size = Vector2(ribbon_w, RIBBON_HEIGHT)


## Ekran adı (büyük harf çağırandan: Godot to_upper Türkçe İ'yi bilmez).
func set_title(text: String) -> void:
	(_ribbon.get_meta(&"title_label") as Label).text = text
	_relayout()


func set_value(text: String, pop: bool = false) -> void:
	UiKit.set_pill_value(_pill, text, pop)


func back_button() -> Button:
	return _back


## Nane "+" (Mağaza kısayolu); `with_add = false` kurulduysa null.
func add_button() -> Button:
	return _pill.get_meta(&"add_button") if _pill.has_meta(&"add_button") else null


func pill() -> Control:
	return _pill


func title_plate() -> PanelContainer:
	return _ribbon


func title_text() -> String:
	return (_ribbon.get_meta(&"title_label") as Label).text
