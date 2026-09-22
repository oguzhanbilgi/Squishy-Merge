extends CanvasLayer
## Mağaza — production casual-game dükkânı (M8.6-05; GAME_DESIGN §5.6 skinler,
## §5.7 güçler). Dikey bir oyun mağazası, ayar listesi DEĞİL:
##
##   ÜST     `ScreenTopBar` (sabit): oturmuş geri (→ Ana Sayfa) · pembe
##           "MAĞAZA" kurdelesi · Hamur pill'i — "+" YOK (Mağaza zaten "+"in
##           hedefi; kendine giden ölü rota olmasın), yalnız bakiye.
##   İÇERİK  gerçek ScrollContainer (üst satırın ALTINDAN kayar, üstte koyu
##           haze ile solar): GÜNLÜK ÖDÜLLER bölüm plakası + tek geniş kart
##           (M8.9-02: durum rozeti HAZIR / "N ödül kaldı" / BUGÜNLÜK
##           TAMAMLANDI + AÇ → `daily_rewards_requested` → Main aynı
##           GÜNLÜK ÖDÜLLER penceresini açar; onboarding bitmeden gizli) ·
##           GÜÇLER bölüm plakası + 2×2 `ShopPowerCard` · SKİNLER bölüm
##           plakası + 2×10 `ShopSkinCard`; altta rahat pay (+ cihaz alt
##           güvenli alanı + banner yuvası). Alt sekme çubuğu YOK.
##   ZEMİN   candy-night dünya (ShellBackdrop) Home ayarında + kenar vignette;
##           kartlar dünyanın üstünde oturan krem candy nesneler.
##
## Tek para birimi Hamur. Gerçek para Güç Paketi / reklam ürünü YOK
## (billing/AdMob kurulmadı — GAME_DESIGN §5.7.4). Fiyatlar burada hardcode
## DEĞİL: güçler `PowerUpEconomy.DOUGH_PRICES`, skinler `Shop.PRICES`.
##
## Satın alma: kart → onay penceresi (`UiKit.modal_frame`, ürün sunumu +
## fiyat + SATIN AL / Vazgeç) → KANONİK tek transaction
## (`PowerUpEconomy.purchase` / `Shop.purchase` → SaveManager). Bu dosya
## Hamur'a doğrudan DOKUNMAZ; skin TAKMAZ (Koleksiyon takar). Hamur
## yetmiyorsa onay açılmaz: kart sallanır + pembe geri bildirim plakası
## (sessiz başarısızlık yok, bedava para yok). Başarıda kart pop + stok /
## bakiye anında kanonik modelden.

## Üst satırdaki geri butonu (→ Ana Sayfa, main._on_home_requested).
signal home_requested
## GÜNLÜK ÖDÜLLER kartının AÇ butonu (M8.9-02) → Main pencereyi açar. Kart
## ödül VERMEZ, kayda yazmaz; durumu yalnız `DailyRewards.state()`'ten okur.
signal daily_rewards_requested

const TITLE: String = "MAĞAZA"
const SIDE_MARGIN: float = 24.0
const COLUMN_GAP: float = 16.0
const ROW_GAP: float = 20.0
## Üst haze: satır boyunca düz koyu bant (kartlar satırın altında OKUNMAZ),
## sonra bu kadar px'te sıfıra solar.
const HAZE_FADE: float = 36.0
## Üst satır ile ilk bölüm plakası arası = solma boyu: ilk plaka dinlenme
## konumunda haze'in dışında (boyanmaz).
const CONTENT_TOP_GAP: float = HAZE_FADE
const SECTION_GAP: float = 12.0
const SECTION_SPACER: float = 22.0
const BOTTOM_PADDING: float = 64.0
const ENTRY_TIME: float = 0.18
## Geri bildirim plakası: kartı varsa kartın hemen altında (12 px), yoksa alt
## kenardan bu kadar yukarıda belirir.
const TOAST_BOTTOM: float = 150.0
const TOAST_CARD_GAP: float = 12.0
## Onay penceresi ürün sunumu (05.1: %12 büyüdü — 172/148·106/152·164'ten):
## sunum alanı, güç kuyusu çapı / sanatı, skin kuyusu / önizlemesi.
const CONFIRM_ART_HEIGHT: float = 190.0
const CONFIRM_POWER_WELL: float = 164.0
const CONFIRM_POWER_ART: float = 118.0
const CONFIRM_SKIN_WELL: float = 168.0
const CONFIRM_SKIN_PREVIEW: float = 184.0
## Günlük ödüller kartı (M8.9-02).
const DAILY_TITLE: String = "GÜNLÜK ÖDÜLLER"
const DAILY_SUB: String = "Ücretsiz sandık · reklamla Hamur ve sandık"
const DAILY_BUTTON: String = "AÇ"
const DAILY_STATUS_READY: String = "HAZIR"
const DAILY_STATUS_LEFT: String = "%d ödül kaldı"
const DAILY_STATUS_DONE: String = "BUGÜNLÜK TAMAMLANDI"
const DAILY_WELL: float = 72.0
const DAILY_ART: float = 50.0
const DAILY_BUTTON_HEIGHT: float = 58.0
const CHEST_ART: Texture2D = preload("res://assets/visual/ui/chest_closed.png")

var _bar: ScreenTopBar
var _daily_header: Control
var _daily_card: PanelContainer
var _daily_spacer: Control
var _daily_status: PanelContainer
var _daily_status_label: Label
var _daily_button: Button
var _power_cards: Array[ShopPowerCard] = []
var _skin_cards: Array[ShopSkinCard] = []
## Kart kimliği -> kart: "power_<tip>" ve skin id (String). Testler ve
## satın alma sonrası pop için.
var _cards: Dictionary = {}
var _pending_skin: SkinData = null
## Onay bekleyen güç tipi, ya da -1.
var _pending_power: int = -1
var _frame: Control
var _confirm_art: Control
var _confirm_title: Label
var _confirm_detail: Label
var _confirm_price: Label
var _confirm_balance: Label
var _confirm_yes: Button
var _confirm_no: Button
var _toast: Control
var _toast_plate: PanelContainer
var _toast_rim: PanelContainer
var _toast_label: Label
var _time: float = 0.0
var _entry_tween: Tween
## Test kancası: cihaz üst güvenli payı (A36 punch-hole) masaüstünde
## okunamaz; negatif = gerçek değeri kullan.
var _safe_top_override: float = -1.0

@onready var _root: Control = $Root
@onready var _backdrop: Control = $Root/Backdrop
@onready var _vignette: TextureRect = $Root/Vignette
@onready var _scroll: ScrollContainer = $Root/Scroll
@onready var _margin: MarginContainer = $Root/Scroll/Margin
@onready var _content: VBoxContainer = $Root/Scroll/Margin/Content
@onready var _haze: TextureRect = $Root/Haze
@onready var _confirm: Control = $Confirm
@onready var _confirm_dim: ColorRect = $Confirm/Dim
@onready var _confirm_anchor: CenterContainer = $Confirm/Anchor


func _ready() -> void:
	_tune_backdrop()
	_vignette.texture = _radial_vignette()
	_haze.texture = _band_gradient(Color(UiTokens.WORLD_INDIGO, 0.94), Color(UiTokens.WORLD_INDIGO, 0.0))
	_bar = ScreenTopBar.new(TITLE, false)
	_bar.back_pressed.connect(func() -> void: home_requested.emit())
	_root.add_child(_bar)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_build_content()
	_build_confirm()
	_build_toast()
	_root.resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		set_process(visible)
		if visible:
			_layout()
			_play_entry.call_deferred())
	set_process(visible)
	_layout()
	refresh()


# --- Kurulum ------------------------------------------------------------------

## Kabuk zemini Mağaza'da Home ayarında: gece kasabası görünür, karartma
## azalır (krem kartlar zaten okunur), alt solma kalır.
func _tune_backdrop() -> void:
	var night: CanvasItem = _backdrop.get_node_or_null("Night")
	if night != null:
		night.modulate = Color(0.80, 0.78, 0.94, 1.0)
	var scrim: ColorRect = _backdrop.get_node_or_null("Scrim")
	if scrim != null:
		scrim.color = Color(0.07, 0.05, 0.18, 0.30)
	var fade: CanvasItem = _backdrop.get_node_or_null("BottomFade")
	if fade != null:
		fade.modulate = Color(1, 1, 1, 0.70)


func _build_content() -> void:
	_content.add_theme_constant_override("separation", SECTION_GAP)
	_build_daily_section()
	var powers_header := UiKit.section_header("GÜÇLER")
	powers_header.name = "PowersHeader"
	_content.add_child(powers_header)
	var power_grid := _make_grid("PowerGrid")
	_content.add_child(power_grid)
	for type in PowerUp.all():
		var card := ShopPowerCard.create(type)
		card.buy_requested.connect(_on_power_buy_requested)
		power_grid.add_child(card)
		_power_cards.append(card)
		_cards["power_%d" % int(type)] = card
	_content.add_child(_make_spacer(SECTION_SPACER))
	var skins_header := UiKit.section_header("SKİNLER")
	skins_header.name = "SkinsHeader"
	_content.add_child(skins_header)
	var skin_grid := _make_grid("SkinGrid")
	_content.add_child(skin_grid)
	for entry in SkinEntry.all(false):
		var card := ShopSkinCard.create(entry)
		card.buy_requested.connect(_on_skin_buy_requested)
		skin_grid.add_child(card)
		_skin_cards.append(card)
		_cards[String(entry.id)] = card


## GÜNLÜK ÖDÜLLER bölümü (M8.9-02): bölüm plakası + tek geniş kart (güç
## kartlarıyla aynı krem gövde dili: candy kuyuda owner sandığı, Baloo
## başlık + alt satır, sağda durum rozeti, altta cyan AÇ). Ödül burada
## verilmez; AÇ pencereyi açar. Onboarding bitmeden bölüm gizli (tutorial
## öncesi günlük/reklam sunumu yok — `_refresh_daily`).
func _build_daily_section() -> void:
	_daily_header = UiKit.section_header(DAILY_TITLE)
	_daily_header.name = "DailyHeader"
	_content.add_child(_daily_header)
	_daily_card = PanelContainer.new()
	_daily_card.name = "DailyCard"
	_daily_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_daily_card.add_theme_stylebox_override("panel",
		UiKit.style("card_bevel_soft", UiTokens.TRAY_CREAM, Vector4(16, 14, 16, 18)))
	var ring := UiKit.flat_plate("frame_round20", Color(UiTokens.LAVENDER_SURFACE, 0.95))
	ring.show_behind_parent = true
	UiKit.inset(ring, -2.0, -2.0, -2.0, -2.0)
	_daily_card.add_child(ring)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_daily_card.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	var well_host := Control.new()
	well_host.custom_minimum_size = Vector2(DAILY_WELL + 10.0, DAILY_WELL + 12.0)
	well_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(well_host)
	var well := UiKit.candy_well(CHEST_ART, UiTokens.PINK, DAILY_WELL, DAILY_ART)
	well.name = "Well"
	well.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	well.offset_left = -DAILY_WELL * 0.5
	well.offset_right = DAILY_WELL * 0.5
	well.offset_top = -(DAILY_WELL + 6.0) * 0.5
	well.offset_bottom = (DAILY_WELL + 6.0) * 0.5
	well_host.add_child(well)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", -2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(text)
	var title := UiKit.label(DAILY_TITLE, &"LabelSection")
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 22)
	text.add_child(title)
	var sub := UiKit.label(DAILY_SUB, &"LabelBody")
	sub.name = "Sub"
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(sub)
	var status_host := CenterContainer.new()
	status_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(status_host)
	_daily_status = UiKit.badge(DAILY_STATUS_READY)
	_daily_status.name = "DailyStatus"
	_daily_status_label = _daily_status.get_child(0).get_child(0)
	_daily_status_label.add_theme_font_size_override("font_size", 14)
	status_host.add_child(_daily_status)
	_daily_button = UiKit.button(DAILY_BUTTON, &"ButtonPrimary")
	_daily_button.name = "DailyOpen"
	_daily_button.custom_minimum_size = Vector2(0, DAILY_BUTTON_HEIGHT)
	# ScrollContainer içinde buton (06.3 kuralı): basış kaydırmayı engellemez,
	# kaydırma başlayınca basış görseli bırakılır (BaseButton basışı iptal eder).
	_daily_button.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.scroll_started.connect(func() -> void: UiMotion.release(_daily_button))
	_daily_button.pressed.connect(func() -> void: daily_rewards_requested.emit())
	column.add_child(_daily_button)
	_content.add_child(_daily_card)
	_daily_spacer = _make_spacer(SECTION_SPACER)
	_daily_spacer.name = "DailySpacer"
	_content.add_child(_daily_spacer)


## Günlük kartın durumu kanonik modelden; onboarding bitmeden bölüm gizli.
func _refresh_daily() -> void:
	if _daily_card == null:
		return
	var shown: bool = SaveManager.onboarding_completed()
	_daily_header.visible = shown
	_daily_card.visible = shown
	_daily_spacer.visible = shown
	if not shown:
		return
	var state: Dictionary = DailyRewards.state()
	var left: int = int(state["remaining_total"])
	var max_total: int = DailyRewards.FREE_CHESTS_PER_DAY + DailyRewards.AD_CHESTS_PER_DAY + DailyRewards.AD_DOUGH_PER_DAY
	var text: String = DAILY_STATUS_DONE
	if left >= max_total:
		text = DAILY_STATUS_READY
	elif left > 0:
		text = DAILY_STATUS_LEFT % left
	_daily_status_label.text = text
	var ready: bool = left > 0
	_daily_status.theme_type_variation = &"Badge" if ready else &"LockBadge"
	_daily_status_label.theme_type_variation = &"LabelBadge" if ready else &"LabelBadgeOnDark"
	_daily_status_label.add_theme_font_size_override("font_size", 14)


func _make_grid(grid_name: String) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = grid_name
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", int(COLUMN_GAP))
	grid.add_theme_constant_override("v_separation", int(ROW_GAP))
	return grid


func _make_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## Onay penceresi: production iskelet (`UiKit.modal_frame`: pembe kurdele +
## krem gövde + kapat) — ürün sunumu (candy kuyu / skin önizlemesi), ad,
## açıklama, fiyat, SATIN AL (kahraman CTA) ve Vazgeç. 05.1: kurdele iki
## yandan içeri çekilir ve kapat X'i krem halkayla köşeye oturur
## (`UiKit.seat_modal_close` — X kurdelenin sağ kuyruğuna binmez; paylaşılan
## modal_frame reçetesi değişmez), ürün sunumu %12 büyür (CONFIRM_ART_HEIGHT).
func _build_confirm() -> void:
	_frame = UiKit.modal_frame("Satın Al", 560.0)
	UiKit.seat_modal_close(_frame)
	_confirm_anchor.add_child(_frame)
	var body: VBoxContainer = _frame.get_meta(&"body")
	body.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_confirm_art = Control.new()
	_confirm_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_art.custom_minimum_size = Vector2(0, CONFIRM_ART_HEIGHT)
	body.add_child(_confirm_art)
	_confirm_title = UiKit.label("-", &"LabelTitle", HORIZONTAL_ALIGNMENT_CENTER)
	_confirm_title.add_theme_font_size_override("font_size", 30)
	body.add_child(_confirm_title)
	_confirm_detail = UiKit.label("-", &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	_confirm_detail.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_confirm_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_confirm_detail)
	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(price_row)
	var dough := UiKit.art(ScreenTopBar.DOUGH_ART, 36)
	dough.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	dough.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price_row.add_child(dough)
	_confirm_price = UiKit.label("", &"LabelPrice")
	_confirm_price.add_theme_font_size_override("font_size", 28)
	price_row.add_child(_confirm_price)
	# İşlem şeffaf: bakiye önce → sonra (kanonik modelden; onay yalnız Hamur
	# yetiyorken açılır).
	_confirm_balance = UiKit.label("", &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
	_confirm_balance.add_theme_font_size_override("font_size", 17)
	body.add_child(_confirm_balance)
	body.add_child(_make_spacer(2.0))
	_confirm_yes = UiKit.cta("SATIN AL", "", &"ButtonCTA")
	_confirm_yes.name = "Yes"
	_confirm_yes.pressed.connect(_on_confirm_yes)
	body.add_child(_confirm_yes)
	_confirm_no = UiKit.button("Vazgeç", &"ButtonSecondary")
	_confirm_no.name = "No"
	_confirm_no.pressed.connect(_close_confirm)
	body.add_child(_confirm_no)
	(_frame.get_meta(&"close_button") as Button).pressed.connect(_close_confirm)
	_confirm_dim.gui_input.connect(_on_dim_input)
	_confirm.visible = false


## Geri bildirim plakası: pembe `title_oval` candy plaka (gameplay "Taştı!"
## durum plakasıyla aynı dil) + açık halka + erik gölge; başarıda nane.
func _build_toast() -> void:
	_toast = Control.new()
	_toast.name = "Toast"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	var shadow := UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.30))
	UiKit.inset(shadow, -14.0, -8.0, -14.0, -18.0)
	_toast.add_child(shadow)
	_toast_rim = UiKit.flat_plate("title_oval", UiTokens.LAVENDER_LIGHT)
	UiKit.inset(_toast_rim, -3.0, -3.0, -3.0, -3.0)
	_toast.add_child(_toast_rim)
	_toast_plate = UiKit.panel(&"PanelShopToast")
	_toast_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast.add_child(_toast_plate)
	_toast_label = UiKit.label("", &"LabelSectionOnDark", HORIZONTAL_ALIGNMENT_CENTER)
	_toast_label.add_theme_font_size_override("font_size", 21)
	_toast_plate.add_child(_toast_label)
	var gloss := UiKit.patch("btn_bevel_light", Color(1, 1, 1, 0.30))
	gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_left = 10.0
	gloss.offset_right = -10.0
	gloss.offset_top = 3.0
	gloss.offset_bottom = 20.0
	_toast.add_child(gloss)
	add_child(_toast)


# --- Yerleşim -----------------------------------------------------------------

func _safe_top() -> float:
	if _safe_top_override >= 0.0:
		return _safe_top_override
	return UiKit.safe_top(_root.size)


func _layout() -> void:
	if _root == null or _bar == null:
		return
	var view: Vector2 = _root.size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var safe_top: float = _safe_top()
	_bar.layout(view.x, safe_top)
	_vignette.position = Vector2.ZERO
	_vignette.size = view
	_haze.position = Vector2.ZERO
	_haze.size = Vector2(view.x, _bar.height() + HAZE_FADE)
	var band: GradientTexture2D = _haze.texture as GradientTexture2D
	if band != null and band.gradient != null:
		# Düz bant satırın altına kadar; solma HAZE_FADE boyunca.
		band.gradient.offsets = PackedFloat32Array([0.0, _bar.height() / _haze.size.y, 1.0])
	# İçerik tam ekran kayar; üst pay = sabit satır + boşluk. Kartlar satırın
	# altına girince haze ile solar.
	_scroll.position = Vector2.ZERO
	_scroll.size = view
	_margin.add_theme_constant_override("margin_left", int(SIDE_MARGIN))
	_margin.add_theme_constant_override("margin_right", int(SIDE_MARGIN))
	_margin.add_theme_constant_override("margin_top", int(_bar.height() + CONTENT_TOP_GAP))
	_margin.add_theme_constant_override("margin_bottom", int(BOTTOM_PADDING + UiKit.bottom_inset(view)))


# --- Tazeleme -----------------------------------------------------------------

## Sekmeye her girişte (main._show_tab) ve satın almada: kartlar ve bakiye
## kanonik modelden. Kartlar yeniden KURULMAZ (durum güncellenir); giriş
## kaydırmayı en üste alır.
func refresh() -> void:
	_refresh_states(false)
	_scroll.scroll_vertical = 0


## Koleksiyon'dan MAĞAZAYA GİT (M8.6-06): oyuncunun baktığı skin kartı üst
## satırın hemen altına getirilir ve bir kez pop'lar (rota gözle tamamlanır;
## GÜÇLER'in tepesine düşmez). Sekme girişinin `refresh()`'i kaydırmayı
## sıfırladıktan ve container yerleşimi oturduktan SONRA çalışır (bir kare
## bekler). Bilinmeyen id → hiçbir şey olmaz (Mağaza en üstte).
func focus_skin(id: StringName) -> void:
	var card: Control = _cards.get(String(id))
	if card == null:
		return
	_focus_card(card)


func _focus_card(card: Control) -> void:
	await get_tree().process_frame
	if not is_inside_tree() or not visible or not is_instance_valid(card):
		return
	var target: float = card.global_position.y + float(_scroll.scroll_vertical) \
		- (_bar.height() + CONTENT_TOP_GAP)
	_scroll.scroll_vertical = int(maxf(target, 0.0))
	UiMotion.pop(card, 1.03)


func _refresh_states(pop_balance: bool) -> void:
	_refresh_daily()
	for card in _power_cards:
		card.refresh()
	for card in _skin_cards:
		card.refresh()
	_bar.set_value(str(SaveManager.dough()), pop_balance)


func _play_entry() -> void:
	if not is_inside_tree() or not visible:
		return
	if _entry_tween != null and _entry_tween.is_valid():
		_entry_tween.kill()
	_scroll.modulate.a = 0.0
	_entry_tween = create_tween()
	_entry_tween.tween_property(_scroll, "modulate:a", 1.0, ENTRY_TIME)


func _process(delta: float) -> void:
	_time += delta
	for card in _skin_cards:
		card.tick_sparkles(_time)


# --- Satın alma akışı ---------------------------------------------------------

func _on_power_buy_requested(type: PowerUp.Type) -> void:
	if not PowerUpEconomy.can_afford(type):
		_reject(_cards.get("power_%d" % int(type)))
		return
	_open_power_confirm(type)


func _on_skin_buy_requested(skin: SkinData) -> void:
	var entry: SkinEntry = SkinEntry.for_skin(skin)
	if not entry.is_purchasable():
		return
	if not entry.can_afford():
		_reject(_cards.get(String(skin.id)))
		return
	_open_confirm(skin)


## Hamur yetmedi: kart sallanır, `ui_invalid`, pembe plaka. Hiçbir state
## değişmez; bedava Hamur / reklam rotası YOK.
func _reject(card: Control) -> void:
	if card != null and is_instance_valid(card) and card.has_method("reject"):
		card.reject()
	AudioManager.play(&"ui_invalid")
	Haptics.light()
	_show_toast("Hamur yetmiyor · %d Hamur'un var" % SaveManager.dough(), UiTokens.PINK,
		UiTokens.TEXT_ON_DARK, card)


func _open_confirm(skin: SkinData) -> void:
	_pending_skin = skin
	_pending_power = -1
	_set_confirm_art_skin(skin)
	_confirm_title.text = skin.display_name
	_confirm_detail.text = "%s skin · kalıcı, bir kez alınır" % SkinData.rarity_display_name(skin.rarity)
	_show_confirm(Shop.price_of(skin))


func _open_power_confirm(type: PowerUp.Type) -> void:
	_pending_skin = null
	_pending_power = int(type)
	_set_confirm_art_power(type)
	_confirm_title.text = "%s ×1" % PowerUp.display_name(type)
	_confirm_detail.text = "Stok ×%d → ×%d" % [
		SaveManager.powerup_count(type), SaveManager.powerup_count(type) + 1]
	_show_confirm(PowerUpEconomy.price(type))


func _set_confirm_art_power(type: PowerUp.Type) -> void:
	_clear_confirm_art()
	var well := UiKit.candy_well(PowerUp.icon(type), PowerUp.accent(type),
		CONFIRM_POWER_WELL, CONFIRM_POWER_ART)
	well.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	well.offset_left = -CONFIRM_POWER_WELL * 0.5
	well.offset_right = CONFIRM_POWER_WELL * 0.5
	well.offset_top = -(CONFIRM_POWER_WELL + 6.0) * 0.5
	well.offset_bottom = (CONFIRM_POWER_WELL + 6.0) * 0.5
	_confirm_art.add_child(well)


func _set_confirm_art_skin(skin: SkinData) -> void:
	_clear_confirm_art()
	var entry: SkinEntry = SkinEntry.for_skin(skin)
	# Kartla aynı sahne: rarity renginde düşük alfa hale → krem kuyu → swatch.
	var glow := UiKit.patch("popup_glow", Color(UiTokens.rarity_color(int(skin.rarity))
		if skin.rarity != SkinData.Rarity.COMMON else UiTokens.LAVENDER, 0.16))
	glow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	glow.offset_left = -CONFIRM_SKIN_PREVIEW * 0.72
	glow.offset_right = CONFIRM_SKIN_PREVIEW * 0.72
	glow.offset_top = -CONFIRM_SKIN_PREVIEW * 0.72 + 2.0
	glow.offset_bottom = CONFIRM_SKIN_PREVIEW * 0.72 + 2.0
	_confirm_art.add_child(glow)
	var well := UiKit.patch("item_circle_inner", UiTokens.TRAY_CREAM)
	well.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	well.offset_left = -CONFIRM_SKIN_WELL * 0.5
	well.offset_right = CONFIRM_SKIN_WELL * 0.5
	well.offset_top = -CONFIRM_SKIN_WELL * 0.5 + 2.0
	well.offset_bottom = CONFIRM_SKIN_WELL * 0.5 + 2.0
	_confirm_art.add_child(well)
	var swatch := SkinSwatch.new()
	swatch.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	swatch.offset_left = -CONFIRM_SKIN_PREVIEW * 0.5
	swatch.offset_right = CONFIRM_SKIN_PREVIEW * 0.5
	swatch.offset_top = -CONFIRM_SKIN_PREVIEW * 0.5
	swatch.offset_bottom = CONFIRM_SKIN_PREVIEW * 0.5
	swatch.setup(entry, true)
	_confirm_art.add_child(swatch)
	var tag := UiKit.rarity_tag(int(skin.rarity))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tag.position = Vector2(0.0, 4.0)
	_confirm_art.add_child(tag)


func _clear_confirm_art() -> void:
	for child in _confirm_art.get_children():
		child.queue_free()


func _show_confirm(price: int) -> void:
	_confirm_price.text = "%d Hamur" % price
	_confirm_balance.text = "Bakiye %d → %d" % [SaveManager.dough(), SaveManager.dough() - price]
	_confirm.visible = true
	UiMotion.modal_open(_frame, _confirm_dim)
	AudioManager.play(&"ui_modal_open")


func _close_confirm() -> void:
	_pending_skin = null
	_pending_power = -1
	if _confirm.visible:
		AudioManager.play(&"ui_modal_close")
	_confirm.visible = false


## Geri tuşu: onay penceresi açıksa onu kapatır (true), değilse main.gd
## Ana Sayfa'ya döner (false).
func handle_back() -> bool:
	if _confirm.visible:
		_close_confirm()
		return true
	return false


## Karartmaya dokunmak "Vazgeç" ile aynı.
func _on_dim_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null and not touch.pressed:
		_close_confirm()
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_close_confirm()


func _on_confirm_yes() -> void:
	var skin: SkinData = _pending_skin
	var power: int = _pending_power
	_close_confirm()
	var bought_key: String = ""
	if power >= 0:
		if _buy_power(power as PowerUp.Type):
			bought_key = "power_%d" % power
	elif skin != null:
		if _buy_skin(skin):
			bought_key = String(skin.id)
	# Başarılı da olsa başarısız da olsa tazele: stok, bakiye ve "yetmiyor"
	# durumları anında doğru görünsün (bakiye pop'u yalnız değişince).
	_refresh_states(true)
	if not bought_key.is_empty():
		var card: Control = _cards.get(bought_key)
		if card != null and is_instance_valid(card) and card.has_method("celebrate"):
			card.celebrate()


func _buy_power(type: PowerUp.Type) -> bool:
	if PowerUpEconomy.purchase(type):
		AudioManager.play(&"ui_purchase")
		Haptics.medium()
		_show_toast("%s ×1 alındı · Stok ×%d" % [
			PowerUp.display_name(type), SaveManager.powerup_count(type)],
			UiTokens.MINT, UiTokens.TEXT_ON_ACCENT, _cards.get("power_%d" % int(type)))
		return true
	# Araya başka bir harcama girdiyse (teorik) sessizce düşmesin.
	AudioManager.play(&"ui_invalid")
	_show_toast("Hamur yetmedi.", UiTokens.PINK)
	return false


func _buy_skin(skin: SkinData) -> bool:
	if Shop.purchase(skin):
		AudioManager.play(&"ui_purchase")
		Haptics.medium()
		_show_toast("%s alındı · Koleksiyon'da tak" % skin.display_name,
			UiTokens.MINT, UiTokens.TEXT_ON_ACCENT, _cards.get(String(skin.id)))
		return true
	AudioManager.play(&"ui_invalid")
	_show_toast("Hamur yetmedi.", UiTokens.PINK)
	return false


## Geri bildirim: yükselip sönen candy plaka. `card` verilirse plaka o kartın
## hemen altında belirir (göz ve parmak oradadır); ekrana sığmazsa kartın
## üstüne alınır; kart yoksa alt kenara yakın.
func _show_toast(message: String, tint: Color, text_color: Color = UiTokens.TEXT_ON_DARK,
		card: Control = null) -> void:
	_toast_label.text = message
	_toast_label.add_theme_color_override("font_color", text_color)
	_toast_plate.add_theme_stylebox_override("panel",
		UiKit.style("title_oval", tint, Vector4(26, 6, 26, 12)))
	var min: Vector2 = _toast_plate.get_combined_minimum_size()
	var w: float = maxf(min.x, 240.0)
	var h: float = maxf(min.y, 56.0)
	var view: Vector2 = _root.size
	_toast.size = Vector2(w, h)
	var y: float = view.y - TOAST_BOTTOM - UiKit.bottom_inset(view) - h
	if card != null and is_instance_valid(card):
		var rect: Rect2 = card.get_global_rect()
		y = rect.end.y + TOAST_CARD_GAP
		if y + h > view.y - UiKit.bottom_inset(view) - 24.0:
			y = rect.position.y - h - TOAST_CARD_GAP
		y = clampf(y, _bar.height() + 8.0, view.y - h - 24.0)
	_toast.set_meta(&"toast_home", Vector2((view.x - w) * 0.5, y))
	UiMotion.toast(_toast)


# --- Dokular (programatik, asset yok) ----------------------------------------

## Üst haze: düz bant + solma (offset'ler `_layout`'ta satır yüksekliğine
## göre güncellenir).
static func _band_gradient(top: Color, bottom: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.66, 1.0])
	gradient.colors = PackedColorArray([top, top, bottom])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 8
	tex.height = 128
	return tex


## Yumuşak erik vignette (Harita ile aynı): merkez temiz, kenarlar hafif koyu.
static func _radial_vignette() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	gradient.colors = PackedColorArray([Color(0.2, 0.08, 0.32, 0.0),
		Color(0.2, 0.08, 0.32, 0.0), Color(0.2, 0.08, 0.32, 0.30)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 128
	tex.height = 128
	return tex


# --- Testler / çekim aracı ----------------------------------------------------

func _layout_with_safe_top(safe_top: float) -> void:
	_safe_top_override = safe_top
	_layout()


func top_bar() -> ScreenTopBar:
	return _bar


func scroll() -> ScrollContainer:
	return _scroll


func power_cards() -> Array[ShopPowerCard]:
	return _power_cards


func skin_cards() -> Array[ShopSkinCard]:
	return _skin_cards


func power_card(type: PowerUp.Type) -> ShopPowerCard:
	return _cards.get("power_%d" % int(type))


func skin_card(id: StringName) -> ShopSkinCard:
	return _cards.get(String(id))


func daily_card() -> PanelContainer:
	return _daily_card


func daily_button() -> Button:
	return _daily_button


func daily_status_text() -> String:
	return _daily_status_label.text


func section_headers() -> Array[Control]:
	var out: Array[Control] = []
	for child in _content.get_children():
		if child.has_meta(&"title_label"):
			out.append(child)
	return out


func confirm_frame() -> Control:
	return _frame


func is_confirm_open() -> bool:
	return _confirm.visible


func toast_plate() -> Control:
	return _toast


func haze() -> TextureRect:
	return _haze


func confirm_balance_text() -> String:
	return _confirm_balance.text


func toast_text() -> String:
	return _toast_label.text


func is_toast_visible() -> bool:
	return _toast.modulate.a > 0.05
