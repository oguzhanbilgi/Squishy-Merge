extends CanvasLayer
## Mağaza (GAME_DESIGN.md §5.6 skinler, §5.7 güçler). İki bölüm:
##
##   GÜÇLER  — tüketilebilir, tekrar tekrar alınır (Hamur sink'i)
##   SKINLER — kalıcı koleksiyon
##
## Tek para birimi Hamur. Gerçek para Power Pack'ler PLANLANDI ama HENÜZ
## YOK (billing kurulmadı, bkz. GAME_DESIGN §5.7.4).
##
## Fiyatlar burada hardcode DEĞİL: güçler `PowerUpEconomy.DOUGH_PRICES`,
## skinler `Shop.PRICES` üzerinden geliyor.
##
## M8.5-10 görsel pası: liste/veritabanı görünümünden kart tabanlı casual
## mağazaya. Kartta bilgi önceliği: ikon (renkli kuyu) → ad → fiyat
## (Hamur ikonu, altın) → stok (sakin) → CTA (candy pill). Onay diyaloğu
## ve toast candy penceresi/cipi; satın alma başarısında kart pop + bakiye
## cipi pop. Ekonomi/transaction kodu DEĞİŞMEDİ (Shop / PowerUpEconomy).

const SWATCH_SIZE: Vector2 = Vector2(64.0, 64.0)
## Güç kartındaki ikon kuyusu (yuvarlak, gücün vurgu renginde) ve içindeki
## ikon. M8.5-09'a kadar burada `PowerUp.GLYPHS` metin işareti duruyordu;
## gerçek ikonlar `PowerUp.ICON_PATHS`.
const ICON_WELL: float = 84.0
const POWER_ICON_SIZE: float = 68.0
const BUY_SIZE: Vector2 = Vector2(150.0, 62.0)
const BUY_FONT_SIZE: int = 22

var _pending_skin: SkinData = null
## Onay bekleyen güç tipi, ya da -1.
var _pending_power: int = -1
var _dough_chip: PanelContainer
## Son satın alınan öğenin kartı (pop için): kart kimliği -> kart.
var _cards: Dictionary = {}

@onready var _chip_slot: HBoxContainer = $Margin/VBox/Header/ChipSlot
@onready var _list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var _toast: PanelContainer = $Toast
@onready var _toast_label: Label = $Toast/Label
@onready var _confirm: Control = $Confirm
@onready var _confirm_dim: ColorRect = $Confirm/Dim
@onready var _confirm_modal: Control = $Confirm/Modal
@onready var _confirm_title: Label = $Confirm/Modal/Panel/VBox/Title
@onready var _confirm_detail: Label = $Confirm/Modal/Panel/VBox/Detail
@onready var _confirm_price: RichTextLabel = $Confirm/Modal/Panel/VBox/Price
@onready var _confirm_yes: Button = $Confirm/Modal/Panel/VBox/Yes
@onready var _confirm_no: Button = $Confirm/Modal/Panel/VBox/No


func _ready() -> void:
	_dough_chip = UiPalette.chip(UiIcons.DOUGH, "")
	_chip_slot.add_child(_dough_chip)

	CandyButton.style_cta(_confirm_yes)
	UiMotion.attach_press(_confirm_yes)
	UiMotion.attach_press(_confirm_no)
	UiPalette.style_ghost_on_cream(_confirm_no)
	_confirm_no.custom_minimum_size.y = 60.0
	_confirm_yes.pressed.connect(_on_confirm_yes)
	_confirm_no.pressed.connect(_close_confirm)
	_confirm_dim.gui_input.connect(_on_dim_input)
	_confirm.visible = false
	_toast.modulate.a = 0.0
	refresh()


func refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	_cards.clear()

	# Güçler önce: tekrar alınabilen bölüm üstte olsun, skin listesi uzun.
	_list.add_child(_make_section_header(UiPalette.ICON_SPARKLE, "GÜÇLER",
		"Tüketilir · her round'da kullanabilirsin", UiPalette.CYAN))
	for type in PowerUp.all():
		_list.add_child(_make_power_row(type))

	_list.add_child(_make_spacer(10))
	_list.add_child(_make_section_header(UiPalette.ICON_GIFT, "SKİNLER",
		"Kalıcı · bir kez alınır", UiPalette.PINK))
	var shown_rarity: int = -1
	for skin in SkinLibrary.all():
		if int(skin.rarity) != shown_rarity:
			shown_rarity = int(skin.rarity)
			_list.add_child(_make_rarity_header(skin.rarity))
		_list.add_child(_make_row(skin))
	_list.add_child(_make_spacer(8))

	_refresh_dough(false)


func _refresh_dough(pop: bool) -> void:
	UiPalette.set_chip_value(_dough_chip, "%d Hamur" % SaveManager.dough(), pop)


# --- Bölüm başlıkları ---

## İkon + başlık + kısa not, tek satırda. Başlık Baloo, not Nunito.
func _make_section_header(icon: Texture2D, title: String, note: String,
		accent: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 46)
	var rect := UiPalette.icon_rect(icon, 28.0, accent)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rect)
	var label := Label.new()
	UiType.apply(label, UiType.SECTION_TITLE)
	label.text = title
	label.add_theme_color_override("font_color", accent)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var caption := Label.new()
	UiType.apply(caption, UiType.CAPTION)
	caption.text = note
	caption.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.clip_text = true
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(caption)
	return row


func _make_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


# --- Güç satırı ---

func _make_power_row(type: PowerUp.Type) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	card.custom_minimum_size = Vector2(0, 108)
	_cards["power_%d" % int(type)] = card

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	row.add_child(_make_icon_well(PowerUp.accent(type), PowerUp.icon(type)))

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)

	var name_label := Label.new()
	UiType.apply(name_label, UiType.CARD_TITLE)
	name_label.text = PowerUp.display_name(type)
	text.add_child(name_label)

	text.add_child(_make_price_line(PowerUpEconomy.price(type)))

	# Stok sakin (Caption): karar bilgisi fiyat, stok bağlam.
	var stock_label := Label.new()
	UiType.apply(stock_label, UiType.CAPTION)
	stock_label.text = "Stok ×%d" % SaveManager.powerup_count(type)
	stock_label.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	text.add_child(stock_label)

	var buy := _make_buy_button(PowerUpEconomy.can_afford(type))
	buy.pressed.connect(_open_power_confirm.bind(type))
	row.add_child(buy)

	return card


## Gücün vurgu renginde yuvarlak kuyu; ikon değerli görünsün, düz listede
## kaybolmasın.
func _make_icon_well(accent: Color, icon: Texture2D) -> Control:
	var well := PanelContainer.new()
	well.custom_minimum_size = Vector2(ICON_WELL, ICON_WELL)
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.22)
	box.set_border_width_all(2)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	box.set_corner_radius_all(int(ICON_WELL * 0.5))
	well.add_theme_stylebox_override("panel", box)
	var rect := TextureRect.new()
	rect.texture = icon
	rect.custom_minimum_size = Vector2(POWER_ICON_SIZE, POWER_ICON_SIZE)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(rect)
	return well


## "120 Hamur" — Hamur ikonu + altın rakam. Kartın en güçlü veri satırı.
func _make_price_line(price: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(0, 30)
	label.add_theme_color_override("default_color", UiPalette.GOLD)
	label.text = UiIcons.labelled(UiIcons.DOUGH, "%d Hamur" % price, 24)
	return label


func _make_buy_button(affordable: bool) -> Button:
	var buy := Button.new()
	buy.text = "Satın Al"
	buy.custom_minimum_size = BUY_SIZE
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.focus_mode = Control.FOCUS_NONE
	buy.add_theme_font_size_override("font_size", BUY_FONT_SIZE)
	# Parası yetmiyorsa pasif — basılabilir görünüp reddetmek kötü his.
	buy.disabled = not affordable
	UiMotion.attach_press(buy)
	return buy


# --- Skin satırı ---

func _make_rarity_header(rarity: SkinData.Rarity) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 34)
	var dot := PanelContainer.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = SkinData.rarity_color(rarity)
	box.set_corner_radius_all(6)
	dot.add_theme_stylebox_override("panel", box)
	row.add_child(dot)
	var label := Label.new()
	UiType.apply(label, UiType.STAT)
	label.text = SkinData.rarity_name(rarity)
	label.add_theme_color_override("font_color", SkinData.rarity_color(rarity))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var price := Label.new()
	UiType.apply(price, UiType.CAPTION)
	price.text = "%d Hamur" % Shop.price(rarity)
	price.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(price)
	return row


func _make_row(skin: SkinData) -> Control:
	var owned: bool = SaveManager.owns_skin(skin.id)
	var rarity_color: Color = SkinData.rarity_color(skin.rarity)

	var card := PanelContainer.new()
	card.theme_type_variation = &"QuietCardPanel" if owned else &"CardPanel"
	card.custom_minimum_size = Vector2(0, 92)
	if not owned:
		# Rarity kartın kenar rengi — her kart aynı kalıp, tek fark ince çizgi.
		var box := (card.get_theme_stylebox("panel", &"CardPanel") as StyleBoxFlat).duplicate()
		box.border_color = UiPalette.rarity_border(rarity_color)
		card.add_theme_stylebox_override("panel", box)
	_cards[String(skin.id)] = card

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	var swatch := SkinSwatch.new()
	swatch.custom_minimum_size = SWATCH_SIZE
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.setup(skin.tint, rarity_color, owned)
	if owned:
		swatch.modulate = Color(1, 1, 1, 0.7)
	row.add_child(swatch)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)

	var name_label := Label.new()
	UiType.apply(name_label, UiType.CARD_TITLE)
	name_label.text = skin.display_name
	if owned:
		name_label.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	text.add_child(name_label)

	if owned:
		# Sahip olunan: tik + "Sahipsin", nane. Kart sakin yüzeyde, CTA yok.
		var state := HBoxContainer.new()
		state.add_theme_constant_override("separation", 6)
		var check := UiPalette.icon_rect(UiPalette.ICON_CHECK, 18.0, UiPalette.MINT)
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		state.add_child(check)
		var detail := Label.new()
		UiType.apply(detail, UiType.STAT)
		detail.text = "Sahipsin"
		detail.add_theme_color_override("font_color", UiPalette.MINT)
		state.add_child(detail)
		text.add_child(state)
	else:
		text.add_child(_make_price_line(Shop.price_of(skin)))
		var buy := _make_buy_button(Shop.can_afford(skin))
		buy.pressed.connect(_open_confirm.bind(skin))
		row.add_child(buy)

	return card


# --- Onay diyaloğu (iki bölüm de aynı diyaloğu kullanıyor) ---

func _open_confirm(skin: SkinData) -> void:
	_pending_skin = skin
	_pending_power = -1
	_confirm_title.text = skin.display_name
	_confirm_detail.text = "%s skin · kalıcı" % SkinData.rarity_name(skin.rarity)
	_show_confirm(Shop.price_of(skin))


func _open_power_confirm(type: PowerUp.Type) -> void:
	_pending_skin = null
	_pending_power = int(type)
	_confirm_title.text = "%s ×1" % PowerUp.display_name(type)
	_confirm_detail.text = "Stok ×%d → ×%d" % [
		SaveManager.powerup_count(type), SaveManager.powerup_count(type) + 1]
	_show_confirm(PowerUpEconomy.price(type))


func _show_confirm(price: int) -> void:
	_confirm_price.text = "[center]%s[/center]" % UiIcons.labelled(
		UiIcons.DOUGH, "%d Hamur" % price, 30)
	_confirm.visible = true
	UiMotion.modal_open(_confirm_modal, _confirm_dim)


func _close_confirm() -> void:
	_pending_skin = null
	_pending_power = -1
	_confirm.visible = false


## Geri tuşu: onay diyaloğu açıksa onu kapatır (true), değilse main.gd
## sekmeye döner (false).
func handle_back() -> bool:
	if _confirm.visible:
		_close_confirm()
		return true
	return false


## Karartmaya dokunmak "Vazgeç" ile aynı.
func _on_dim_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed:
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
	# Başarılı da olsa başarısız da olsa listeyi tazele: stok, Hamur ve
	# "parası yetmiyor" pasiflikleri anında doğru görünsün.
	refresh()
	_refresh_dough(true)
	if not bought_key.is_empty():
		# refresh() kartları yeniden kurdu; yeni kart bir kare sonra yerleşir.
		await get_tree().process_frame
		var card: Control = _cards.get(bought_key)
		if card != null and is_instance_valid(card):
			UiMotion.pop(card, 1.04)


func _buy_power(type: PowerUp.Type) -> bool:
	if PowerUpEconomy.purchase(type):
		AudioManager.play_sfx(&"chest_open", 1.1)
		_show_toast("%s ×1 alındı · Stok ×%d" % [
			PowerUp.display_name(type), SaveManager.powerup_count(type)])
		return true
	# Araya başka bir harcama girdiyse (teorik) sessizce düşmesin.
	_show_toast("Hamur yetmedi.")
	return false


func _buy_skin(skin: SkinData) -> bool:
	if Shop.purchase(skin):
		AudioManager.play_sfx(&"chest_open", 1.0)
		_show_toast("%s alındı!" % skin.display_name)
		return true
	_show_toast("Hamur yetmedi.")
	return false


## Başarı geri bildirimi: alt kenardan yükselip sönen cip.
func _show_toast(message: String) -> void:
	_toast_label.text = message
	UiMotion.toast(_toast)
