class_name TutorialOverlay
extends CanvasLayer
## İlk açılış tutorial'ının coach-mark yüzeyi (M8.10 —
## docs/TUTORIAL_SYSTEM.md). Adım mantığı YOK: `TutorialController` bir
## "adım tarifi" verir, burası onu çizer ve iki sinyal yayar (CTA / ATLA).
##
## TASARIM (UI_VISUAL_SYSTEM candy-night): karartma + spot, kompakt candy
## konuşma kartı (Baloo 2 başlık + Nunito gövde), `tutorial_pose` maskotu,
## nabız atan altın halka ve sürükleme ipucu. Jenerik gri overlay / web
## tooltip / dev-debug görünüm YOK.
##
## KURAL (§9): kart AÇIKLADIĞI hedefin üstünü ASLA kapatmaz. Hedef dikdörtgeni
## verildiğinde kart hangi tarafta daha çok yer varsa oraya oturur, güvenli
## alanlara ve banner yuvasına (onboarding bitene kadar 0) kırpılır.
##
## GİRDİ: kart gövdesi ve spot MOUSE_FILTER_IGNORE — sürükle/bırak adımlarında
## parmak board'a ulaşır. Yalnız CTA ve ATLA dokunuş alır.

## Oyuncu kartın ana butonuna bastı (BAŞLA / DEVAM / DEVAM ET).
signal cta_pressed
## Küçük ATLA kontrolü (guided tutorial boyunca) ya da geri onayındaki ATLA.
signal skip_pressed

const MASCOT: Texture2D = preload("res://assets/visual/ui/tutorial_pose.png")
## Yumuşak DOLU parıltı (M8.7-02 ROL notu: `fx_ring.png` dolu, `fx_dot.png`
## içi boş halka — dosya adları içerikle ters, sabit ROLÜ adlandırıyor).
const GLOW: Texture2D = preload("res://assets/visual/fx/fx_ring.png")

## Kart genişliği (720 px tuval: iki yanda 80 px pay).
const CARD_WIDTH: float = 560.0
## Kart ile hedef arasındaki nefes payı.
const TARGET_GAP: float = 22.0
## Ekran kenarı payı.
const EDGE: float = 20.0
const MASCOT_HEIGHT: float = 230.0
## Spot halkasının hedefin dışına taşan payı.
const RING_PAD: float = 14.0
## Güvenli bandın (HUD ↔ şerit) iç payı.
const BAND_PAD: float = 10.0

var _root: Control
var _spot: Control
var _card: PanelContainer
var _card_host: Control
var _title: Label
var _body: Label
var _cta: Button
var _cta_alt: Button
var _buttons: HBoxContainer
var _mascot: TextureRect
var _skip: Button
var _pointer: Control

## Aktif spot (ekran px); boş = spot yok.
var _target: Rect2 = Rect2()
var _dim: bool = true
## SNAP kılavuz çizgisinin ekran x'i (< 0 = yok).
var _guide_x: float = -1.0
## Nabız fazı (halka + kılavuz + sürükleme ipucu ortak saati).
var _pulse: float = 0.0
## Son yerleşimde ölçülen kart yüksekliği (kendini düzeltme, bkz. _process).
var _measured_card_h: float = -1.0
## Kartın girebileceği güvenli bant (boş = ekranın güvenli alanı).
var _bounds: Rect2 = Rect2()


func _ready() -> void:
	layer = 8
	_root = Control.new()
	_root.name = "Root"
	_root.theme = UiKit.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_spot = Control.new()
	_spot.name = "Spot"
	_spot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spot.draw.connect(_draw_spot)
	_root.add_child(_spot)

	_pointer = Control.new()
	_pointer.name = "DragCue"
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.visible = false
	_pointer.draw.connect(_draw_pointer)
	_root.add_child(_pointer)

	_card_host = Control.new()
	_card_host.name = "CardHost"
	_card_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_card_host)

	_mascot = TextureRect.new()
	_mascot.name = "Mascot"
	_mascot.texture = MASCOT
	_mascot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mascot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mascot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mascot.visible = false
	_card_host.add_child(_mascot)

	_build_card()
	_build_skip()
	visible = false
	set_process(false)
	get_viewport().size_changed.connect(_relayout)


func _build_card() -> void:
	_card = UiKit.panel(&"PanelCard")
	_card.name = "CoachCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Kartın altındaki lavanta halka + gölge: candy kart reçetesi.
	var ring := UiKit.flat_plate("frame_round20", Color(UiTokens.LAVENDER_SURFACE, 0.95))
	ring.show_behind_parent = true
	UiKit.inset(ring, -3.0, -3.0, -3.0, -3.0)
	_card.add_child(ring)
	UiKit.hud_shadow(_card, 7.0, 0.34, null, 18.0)
	_card_host.add_child(_card)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_card.add_child(column)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(pad)

	var inner := VBoxContainer.new()
	inner.name = "Inner"
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	pad.add_child(inner)
	for side: String in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side,
			UiTokens.SPACE_LG if side != "bottom" else UiTokens.SPACE_LG)

	_title = UiKit.label("", &"LabelSection", HORIZONTAL_ALIGNMENT_CENTER)
	_title.name = "Title"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_title)

	_body = UiKit.label("", &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	_body.name = "Body"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_body)

	_buttons = HBoxContainer.new()
	_buttons.name = "Buttons"
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	inner.add_child(_buttons)

	_cta_alt = UiKit.candy_button("", &"ButtonSecondary", 58.0)
	_cta_alt.name = "CtaAlt"
	_cta_alt.custom_minimum_size.x = 190.0
	_cta_alt.visible = false
	_cta_alt.pressed.connect(func() -> void: skip_pressed.emit())
	_buttons.add_child(_cta_alt)

	_cta = UiKit.candy_button("", &"ButtonPrimary", 58.0)
	_cta.name = "Cta"
	_cta.custom_minimum_size.x = 210.0
	_cta.pressed.connect(func() -> void: cta_pressed.emit())
	_buttons.add_child(_cta)


## ATLA: küçük, gösterişsiz, ana CTA DEĞİL (§11) — üst sağ köşede düz yazı.
## Candy buton REÇETESİ KULLANILMIYOR: bilinçli olarak sessiz bir kontrol,
## yalnız okunurluk için ince bir koyu pill arkalığı var.
func _build_skip() -> void:
	_skip = Button.new()
	_skip.name = "Skip"
	_skip.text = "ATLA"
	_skip.flat = true
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.custom_minimum_size = Vector2(100.0, UiTokens.TOUCH_MIN)
	_skip.add_theme_color_override("font_color", UiTokens.TEXT_ON_DARK_MUTED)
	_skip.add_theme_color_override("font_hover_color", UiTokens.TEXT_ON_DARK)
	_skip.add_theme_color_override("font_pressed_color", UiTokens.TEXT_ON_DARK)
	var backing := UiKit.flat_plate("title_oval", Color(UiTokens.NAVY_PURPLE_DEEP, 0.46))
	backing.show_behind_parent = true
	UiKit.inset(backing, 0.0, 4.0, 0.0, 4.0)
	_skip.add_child(backing)
	UiMotion.attach_press(_skip)
	_skip.pressed.connect(func() -> void: skip_pressed.emit())
	_root.add_child(_skip)


# --- Sunum ---------------------------------------------------------------------

## Adım tarifi. Anahtarlar (hepsi opsiyonel):
##   title, body      : metinler ("" = gizli)
##   cta              : ana buton yazısı ("" = buton yok)
##   cta_alt          : ikincil buton yazısı ("" = yok; geri onayında ATLA)
##   target           : Rect2 ekran px — spot + halka (boş = spot yok)
##   dim              : true ise ekran karartılır (sürükleme adımlarında false)
##   mascot           : tutorial_pose gösterilsin mi
##   pointer          : sürükle-bırak hareket ipucu
##   guide_x          : SNAP kılavuz çizgisinin ekran x'i (< 0 = yok)
##   skip             : küçük ATLA kontrolü görünsün mü
##   bounds           : Rect2 — kartın ve ATLA'nın girebileceği güvenli bant
##                      (HUD'un altı ↔ evrim şeridinin üstü). Verilmezse
##                      ekranın güvenli alanı kullanılır.
func show_step(spec: Dictionary) -> void:
	_target = spec.get("target", Rect2()) as Rect2
	_bounds = spec.get("bounds", Rect2()) as Rect2
	_dim = bool(spec.get("dim", true))
	_guide_x = float(spec.get("guide_x", -1.0))

	var title: String = String(spec.get("title", ""))
	var body: String = String(spec.get("body", ""))
	_title.text = title
	_title.visible = not title.is_empty()
	_body.text = body
	_body.visible = not body.is_empty()

	var cta: String = String(spec.get("cta", ""))
	_cta.visible = not cta.is_empty()
	if _cta.visible:
		(_cta.get_meta(&"title_label") as Label).text = cta
	var cta_alt: String = String(spec.get("cta_alt", ""))
	_cta_alt.visible = not cta_alt.is_empty()
	if _cta_alt.visible:
		(_cta_alt.get_meta(&"title_label") as Label).text = cta_alt
	_buttons.visible = _cta.visible or _cta_alt.visible
	# Tamamen boş bir adım tarifi (ilk parça otururken) kart göstermez —
	# içi boş bir panel ekranda durmasın.
	_card.visible = _title.visible or _body.visible or _buttons.visible

	_mascot.visible = bool(spec.get("mascot", false)) and _card.visible
	_pointer.visible = bool(spec.get("pointer", false))
	_skip.visible = bool(spec.get("skip", true))

	visible = true
	set_process(true)
	_relayout()


func hide_overlay() -> void:
	visible = false
	set_process(false)
	_target = Rect2()
	_guide_x = -1.0


func is_open() -> bool:
	return visible


## Testler/çekimler için: kartın ve spotun ekran dikdörtgenleri.
func card_rect() -> Rect2:
	return _card.get_global_rect()


func target_rect() -> Rect2:
	return _target


func cta_button() -> Button:
	return _cta


func cta_alt_button() -> Button:
	return _cta_alt


func skip_button() -> Button:
	return _skip


func title_text() -> String:
	return _title.text


func body_text() -> String:
	return _body.text


func _process(delta: float) -> void:
	_pulse = fposmod(_pulse + delta, TAU)
	# Kart ölçüsü kendini düzeltir: `show_step` ilk çağrıldığında tema/yazı
	# tipi ölçüleri henüz oturmamış olabiliyor (ilk karede `PanelCard`
	# beklenenden çok yüksek ölçülüyordu — 720×1280'de 1416 px). Minimum
	# boyut değiştiğinde yerleşim yeniden kurulur; sabitlenince durur.
	var wanted: float = _card.get_combined_minimum_size().y if _card.visible else 0.0
	if not is_equal_approx(wanted, _measured_card_h):
		_measured_card_h = wanted
		_relayout()
	_spot.queue_redraw()
	if _pointer.visible:
		_pointer.queue_redraw()


# --- Yerleşim --------------------------------------------------------------------

func _relayout() -> void:
	if not visible or _root == null:
		return
	var view: Vector2 = _root.size
	if view.x <= 0.0:
		view = get_viewport().get_visible_rect().size
	var top: float = UiKit.safe_top(view) + EDGE
	var bottom: float = view.y - UiKit.bottom_inset(view) - EDGE
	if _bounds.size.y > 0.0:
		# Oyun ekranında: HUD'un altı ↔ şeridin üstü. Kart ve ATLA buraya
		# sığar; HUD kontrolleri ve evrim şeridi ASLA örtülmez.
		top = maxf(top, _bounds.position.y + BAND_PAD)
		bottom = minf(bottom, _bounds.end.y - BAND_PAD)

	_skip.position = Vector2(view.x - EDGE - _skip.custom_minimum_size.x, top)
	_skip.size = _skip.custom_minimum_size

	if not _card.visible:
		# Kartsız adım (ilk parça otururken): yalnız spot/kılavuz çizilir.
		_measured_card_h = 0.0
		_spot.queue_redraw()
		return

	_card.size = Vector2(CARD_WIDTH, 0.0)
	_card.reset_size()
	_card.size.x = CARD_WIDTH
	var card_h: float = _card.get_combined_minimum_size().y
	_measured_card_h = card_h
	_card.size = Vector2(CARD_WIDTH, card_h)
	var block_h: float = card_h + (MASCOT_HEIGHT if _mascot.visible else 0.0)

	var card_x: float = (view.x - CARD_WIDTH) * 0.5
	var card_y: float = 0.0
	# ATLA'nın altında kalan dikey alan kart için kullanılabilir (ATLA sağ üst
	# köşede küçük bir kontrol; kart tam genişlikte olduğu için onun altından
	# başlar).
	var card_top: float = top + (_skip.size.y + 6.0 if _skip.visible else 0.0)
	if _target.size == Vector2.ZERO:
		# Hedefsiz adım (karşılama / hazırsın): blok dikeyde ortalanır, biraz
		# aşağıda — maskot üstte, kart altta.
		top = card_top
		card_y = clampf((top + bottom - block_h) * 0.5 + 20.0, top, maxf(top, bottom - card_h))
		if _mascot.visible:
			var mascot_floor: float = top + MASCOT_HEIGHT
			card_y = clampf(card_y, mascot_floor, maxf(mascot_floor, bottom - card_h))
	else:
		# Hedefli adım: kart hangi tarafta daha çok yer varsa oraya, hedefe
		# ASLA değmeden (§9).
		# Kart yalnızca TAM SIĞDIĞI tarafa gider; iki taraf da dar kalırsa
		# geniş olanına oturur ve banda kırpılır.
		var above: float = _target.position.y - card_top
		var below: float = bottom - _target.end.y
		var fits_below: bool = below >= card_h + TARGET_GAP
		var fits_above: bool = above >= card_h + TARGET_GAP
		if fits_below and (not fits_above or below >= above):
			card_y = _target.end.y + TARGET_GAP
		elif fits_above:
			card_y = _target.position.y - TARGET_GAP - card_h
		elif below >= above:
			card_y = _target.end.y + TARGET_GAP
		else:
			card_y = _target.position.y - TARGET_GAP - card_h
		card_y = clampf(card_y, card_top, maxf(card_top, bottom - card_h))
		# Kırpma kartı hedefin üstüne itmiş olabilir (hedef bandın kenarına
		# çok yakınsa). "Kart hedefi ÖRTMEZ" kuralı yapısal olsun: hâlâ
		# çakışıyorsa geniş olan tarafa taşınır.
		if card_y < _target.end.y and card_y + card_h > _target.position.y:
			var below_y: float = _target.end.y + TARGET_GAP
			var above_y: float = _target.position.y - TARGET_GAP - card_h
			card_y = below_y if (bottom - below_y) >= (above_y - card_top) else above_y
		# Maskot hedefli adımlarda gizli (yer yok) — güvence.
		_mascot.visible = false
	_card.position = Vector2(card_x, card_y)

	if _mascot.visible:
		_mascot.size = Vector2(CARD_WIDTH, MASCOT_HEIGHT)
		_mascot.position = Vector2(card_x, card_y - MASCOT_HEIGHT + 8.0)

	if _pointer.visible:
		# Sürükleme ipucu kartın üstünde/altında boş kalan tarafta.
		var cue_h: float = 74.0
		var cue_y: float = card_y - TARGET_GAP - cue_h
		if cue_y < top:
			cue_y = minf(card_y + card_h + TARGET_GAP, bottom - cue_h)
		_pointer.position = Vector2(EDGE + 40.0, cue_y)
		_pointer.size = Vector2(view.x - (EDGE + 40.0) * 2.0, cue_h)

	_spot.queue_redraw()


# --- Çizim ------------------------------------------------------------------------

## Karartma hedefin ÜSTÜNE gelmez: delik dört dikdörtgenle bırakılır
## (shader yok, ucuz). Halka altın, nabızlı.
func _draw_spot() -> void:
	var view: Vector2 = _spot.size
	var scrim := Color(0.05, 0.02, 0.14, 0.58)
	var hole: Rect2 = _target.grow(RING_PAD)
	if _dim:
		if _target.size == Vector2.ZERO:
			_spot.draw_rect(Rect2(Vector2.ZERO, view), scrim)
		else:
			_spot.draw_rect(Rect2(0.0, 0.0, view.x, maxf(0.0, hole.position.y)), scrim)
			_spot.draw_rect(Rect2(0.0, hole.end.y, view.x, maxf(0.0, view.y - hole.end.y)), scrim)
			_spot.draw_rect(Rect2(0.0, hole.position.y, maxf(0.0, hole.position.x), hole.size.y), scrim)
			_spot.draw_rect(Rect2(hole.end.x, hole.position.y,
				maxf(0.0, view.x - hole.end.x), hole.size.y), scrim)

	if _target.size != Vector2.ZERO:
		var beat: float = 0.5 + 0.5 * sin(_pulse * 2.4)
		var ring := Color(UiTokens.GOLD, 0.55 + 0.35 * beat)
		_spot.draw_rect(hole, ring, false, 3.0)
		_spot.draw_rect(hole.grow(4.0 + 3.0 * beat),
			Color(UiTokens.GOLD_BRIGHT, 0.18 + 0.16 * beat), false, 2.0)

	if _guide_x >= 0.0:
		# SNAP kılavuzu: bırakma çizgisinden tabana inen ince cyan iz.
		var beat2: float = 0.5 + 0.5 * sin(_pulse * 3.0)
		var col := Color(UiTokens.CYAN, 0.30 + 0.28 * beat2)
		var step: float = 22.0
		var y: float = 0.0
		while y < view.y:
			_spot.draw_line(Vector2(_guide_x, y), Vector2(_guide_x, y + step * 0.55), col, 3.0)
			y += step


## Sürükle-bırak ipucu: yumuşak yatay ray + üstünde gidip gelen parmak
## noktası. Yeni bir dış asset gerektirmiyor (§8).
func _draw_pointer() -> void:
	var w: float = _pointer.size.x
	var mid: float = _pointer.size.y * 0.5
	var track := Color(UiTokens.LAVENDER_LIGHT, 0.28)
	_pointer.draw_line(Vector2(10.0, mid), Vector2(w - 10.0, mid), track, 6.0)
	for side: float in [10.0, w - 10.0]:
		_pointer.draw_circle(Vector2(side, mid), 7.0, Color(UiTokens.LAVENDER_LIGHT, 0.40))
	# Parmak: 0..1 arasında yumuşak gidiş-dönüş.
	var t: float = 0.5 + 0.5 * sin(_pulse * 1.5)
	var at := Vector2(lerpf(26.0, w - 26.0, t), mid)
	_pointer.draw_texture_rect(GLOW, Rect2(at - Vector2(30.0, 30.0), Vector2(60.0, 60.0)),
		false, Color(UiTokens.CYAN, 0.35))
	_pointer.draw_circle(at, 15.0, Color(UiTokens.CREAM, 0.92))
	_pointer.draw_circle(at, 15.0, Color(UiTokens.CYAN_DEEP, 0.75), false, 3.0)
	# Aşağı bırakma oku.
	var tip: Vector2 = at + Vector2(0.0, 26.0)
	var arrow := Color(UiTokens.CYAN, 0.85)
	_pointer.draw_line(at + Vector2(0.0, 16.0), tip, arrow, 4.0)
	_pointer.draw_line(tip, tip + Vector2(-7.0, -8.0), arrow, 4.0)
	_pointer.draw_line(tip, tip + Vector2(7.0, -8.0), arrow, 4.0)
