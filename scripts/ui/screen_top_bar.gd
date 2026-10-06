class_name ScreenTopBar
extends Control
## Hub ekranı üst satırı (M8.6-04, ilk kullanım: Harita; TASK/057 Tur 2'den beri GERİ OKSUZ). Home'un üst
## satırıyla AYNI geometri ve malzeme (56 px satır, 24 px kenar payı, cihaz üst güvenli payı) — ekranlar arasında
## geçiş "aynı ürün" okunsun:
##
##   ORTA   pembe başlık kurdelesi (`HeaderRibbon`, pencere başlıklarıyla aynı kimlik parçası; dashboard başlığı
##          değil) — ekran adı, ekranın tam ortasında
##   SAĞ    `UiKit.home_pill(Hamur, değer, "+")` → `add_pressed` (Mağaza); Mağaza'nın kendisinde "+" YOK
##          (`with_add = false`, M8.6-05): pill yalnız bakiye gösterir — kendine giden ölü bir rota olmasın.
##          `action_icon` verilirse (TASK/044 Profil: "settings") pill YERİNE aynı 56 px
##          `UiKit.home_icon_button` → `action_pressed`.
##
## Sol üst Ana Sayfa'ya dönüş oku YOK (owner kararı, TASK/057 Tur 2): Harita / Mağaza / Koleksiyon / Profil eş
## düzey hub ekranlarıdır, Ana Sayfa'ya dönüş kalıcı küresel gezinme kabuğunda (ANA SAYFA) ve Android sistem
## GERİ'sinde (DEĞİŞMEDİ). Pencere / detay kapatma düğmeleri ve oyun içi geri bu satırla ilgili değildir.
## Yerleşim `layout(view_width, safe_top)` ile çağırandan; kurdele ekranda ortalanır, sağ pill büyürse (99999
## Hamur) kurdele sola kayar, çakışmaz. `set_title_visible(false)`: kısıtlı Harita yerleşimi (TASK/057) kurdeleyi
## gizleyebilir — satırda yalnız sağ pill kalır.

signal add_pressed
## Sağ ikon butonu (yalnız `action_icon` ile kurulduysa; Profil → Ayarlar).
signal action_pressed

const ROW_HEIGHT: float = 56.0
const TOP_MARGIN: float = 14.0
const SIDE_MARGIN: float = 24.0
const GAP: float = 12.0
## Kurdele satırdan 6 px taşar (üst 3 / alt 3): 70 px'lik sprite 62'de
## doğal oranına yakın kalır.
const RIBBON_HEIGHT: float = 62.0
const RIBBON_MIN_WIDTH: float = 220.0
const DOUGH_ART: Texture2D = preload("res://assets/visual/ui/icon_dough.png")

var _ribbon: PanelContainer
var _pill: Control
var _action: Button
var _safe_top: float = 0.0


func _init(title: String = "", with_add: bool = true, action_icon: String = "") -> void:
	name = "TopBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not action_icon.is_empty():
		_action = UiKit.home_icon_button(action_icon, ROW_HEIGHT)
		_action.name = "Action"
		_action.pressed.connect(func() -> void: action_pressed.emit())
		add_child(_action)
		# Sağ uç bir ikon butonu: pill ile aynı yer (ölçü sabit ROW_HEIGHT kare).
		_pill = _action
	else:
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
	text.add_theme_font_size_override("font_size", 27)
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
	var pill_size: Vector2 = _pill.custom_minimum_size
	if _action != null:
		pill_size = Vector2(ROW_HEIGHT, ROW_HEIGHT)
	_pill.size = pill_size
	_pill.position = Vector2(w - SIDE_MARGIN - pill_size.x, top + (ROW_HEIGHT - pill_size.y) * 0.5)
	# Kurdele: içerik genişliği (min 220), ekranın tam ortasında; sağ pill ile arasında en az GAP kalmazsa sola
	# kayar (sol kenar payı SIDE_MARGIN — geri oku yok, sol taraf nefes payıdır).
	var ribbon_w: float = maxf(_ribbon.get_combined_minimum_size().x, RIBBON_MIN_WIDTH)
	var right_limit: float = _pill.position.x - GAP
	var x: float = (w - ribbon_w) * 0.5
	x = minf(x, right_limit - ribbon_w)
	x = maxf(x, SIDE_MARGIN)
	_ribbon.position = Vector2(x, top + (ROW_HEIGHT - RIBBON_HEIGHT) * 0.5)
	_ribbon.size = Vector2(ribbon_w, RIBBON_HEIGHT)


## Ekran adı (büyük harf çağırandan: Godot to_upper Türkçe İ'yi bilmez).
func set_title(text: String) -> void:
	(_ribbon.get_meta(&"title_label") as Label).text = text
	_relayout()


## Başlık kurdelesini gösterir / gizler (kısıtlı Harita yerleşimi — TASK/057).
func set_title_visible(value: bool) -> void:
	_ribbon.visible = value


func is_title_visible() -> bool:
	return _ribbon.visible


func set_value(text: String, pop: bool = false) -> void:
	if _action != null:
		return
	UiKit.set_pill_value(_pill, text, pop)


## Hub üst satırında geri oku YOK (TASK/057 Tur 2) — eski çağıranlar / testler için her zaman null.
func back_button() -> Button:
	return null


## Nane "+" (Mağaza kısayolu); `with_add = false` kurulduysa null.
func add_button() -> Button:
	return _pill.get_meta(&"add_button") if _pill.has_meta(&"add_button") else null


## Sağ ikon butonu (`action_icon` ile kurulduysa), yoksa null.
func action_button() -> Button:
	return _action


func pill() -> Control:
	return _pill


func title_plate() -> PanelContainer:
	return _ribbon


func title_text() -> String:
	return (_ribbon.get_meta(&"title_label") as Label).text
