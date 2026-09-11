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

const SWATCH_SIZE: Vector2 = Vector2(72.0, 72.0)
## Güç kartındaki ikon kutusu. M8.5-09'a kadar burada hâlâ `PowerUp.GLYPHS`
## metin işareti duruyordu (✸ ▲ ≈ ⌫) — M8.5-08 bunları güç çubuğundan
## kaldırmış ama mağazayı atlamıştı. Yeni tipografi bunu zorunlu kıldı:
## dört işaretin hiçbiri Baloo 2 / Nunito cmap'inde YOK, yani ya tofu ya da
## sistem fallback'inden bambaşka bir yazı tipi çizilirdi. Gerçek ikonlar
## zaten var (`PowerUp.ICON_PATHS`), güç çubuğu da onları kullanıyor.
const POWER_ICON_SIZE: Vector2 = Vector2(72.0, 72.0)
## Bölüm başlıklarının rengi — rarity renkleriyle çakışmayan nötr bir ton.
const SECTION_COLOR: Color = Color("ffd9a0")

var _pending_skin: SkinData = null
## Onay bekleyen güç tipi, ya da -1.
var _pending_power: int = -1

@onready var _dough: RichTextLabel = $Margin/VBox/Dough
@onready var _list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var _toast: Label = $Toast
@onready var _confirm: Control = $Confirm
@onready var _confirm_text: Label = $Confirm/Panel/VBox/Text
@onready var _confirm_yes: Button = $Confirm/Panel/VBox/Buttons/Yes
@onready var _confirm_no: Button = $Confirm/Panel/VBox/Buttons/No


func _ready() -> void:
	_confirm_yes.pressed.connect(_on_confirm_yes)
	_confirm_no.pressed.connect(_close_confirm)
	_confirm.visible = false
	_toast.modulate.a = 0.0
	refresh()


func refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	# Güçler önce: tekrar alınabilen bölüm üstte olsun, skin listesi uzun.
	_list.add_child(_make_section_header("GÜÇLER"))
	_list.add_child(_make_section_note(
		"Tüketilir. Her round'da kullanabilirsin."))
	for type in PowerUp.all():
		_list.add_child(_make_power_row(type))

	_list.add_child(_make_section_header("SKİNLER"))
	_list.add_child(_make_section_note("Kalıcı. Bir kez alınır."))
	var shown_rarity: int = -1
	for skin in SkinLibrary.all():
		if int(skin.rarity) != shown_rarity:
			shown_rarity = int(skin.rarity)
			_list.add_child(_make_rarity_header(skin.rarity))
		_list.add_child(_make_row(skin))

	_refresh_dough()


func _refresh_dough() -> void:
	_dough.text = "[center]%s[/center]" % UiIcons.labelled(
		UiIcons.DOUGH, "Hamur: %d" % SaveManager.dough())


# --- Bölüm başlıkları ---

func _make_section_header(text: String) -> Control:
	var label := Label.new()
	UiType.apply(label, UiType.SECTION_TITLE)
	label.text = text
	label.modulate = SECTION_COLOR
	return label


func _make_section_note(text: String) -> Control:
	var label := Label.new()
	UiType.apply(label, UiType.CAPTION)
	label.text = text
	label.modulate = Color(1, 1, 1, 0.55)
	return label


# --- Güç satırı ---

func _make_power_row(type: PowerUp.Type) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	card.custom_minimum_size = Vector2(0, 92)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var icon := TextureRect.new()
	icon.texture = PowerUp.icon(type)
	icon.custom_minimum_size = POWER_ICON_SIZE
	# EXPAND_IGNORE_SIZE olmadan ikonun kendi 256x256'sı satırı patlatır.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)

	var name_label := Label.new()
	UiType.apply(name_label, UiType.CARD_TITLE)
	name_label.text = PowerUp.display_name(type)
	text.add_child(name_label)

	# Stok sakin (Caption), fiyat guclu (Stat): ikisi ayni boyda olunca
	# satirda hangisinin karar bilgisi oldugu okunmuyordu.
	var stock_label := Label.new()
	UiType.apply(stock_label, UiType.CAPTION)
	stock_label.text = "Stok: ×%d" % SaveManager.powerup_count(type)
	stock_label.modulate = Color(1, 1, 1, 0.7)
	text.add_child(stock_label)

	var price_label := Label.new()
	UiType.apply(price_label, UiType.STAT)
	price_label.text = "%d Hamur" % PowerUpEconomy.price(type)
	price_label.modulate = SECTION_COLOR
	text.add_child(price_label)

	var buy := Button.new()
	UiType.apply(buy, UiType.SECONDARY_BUTTON)
	buy.text = "Satın Al"
	buy.custom_minimum_size = Vector2(158, 68)
	# Parası yetmiyorsa pasif — basılabilir görünüp reddetmek kötü his.
	buy.disabled = not PowerUpEconomy.can_afford(type)
	buy.pressed.connect(_open_power_confirm.bind(type))
	row.add_child(buy)

	return card


# --- Skin satırı ---

func _make_rarity_header(rarity: SkinData.Rarity) -> Control:
	var label := Label.new()
	UiType.apply(label, UiType.SECTION_TITLE)
	# Bolum basligindan (GUCLER / SKINLER) bir kademe zayif: ayni rolu
	# kullaniyor ama boyutu eziliyor, boylece iki seviye ayirt ediliyor.
	label.add_theme_font_size_override("font_size", 21)
	label.text = "%s  ·  %d Hamur" % [SkinData.rarity_name(rarity), Shop.price(rarity)]
	label.modulate = SkinData.rarity_color(rarity)
	return label


func _make_row(skin: SkinData) -> Control:
	var owned: bool = SaveManager.owns_skin(skin.id)

	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	card.custom_minimum_size = Vector2(0, 92)
	if owned:
		card.modulate = Color(1, 1, 1, 0.55)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var swatch := SkinSwatch.new()
	swatch.custom_minimum_size = SWATCH_SIZE
	swatch.setup(skin.tint, SkinData.rarity_color(skin.rarity), owned)
	row.add_child(swatch)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)

	var name_label := Label.new()
	UiType.apply(name_label, UiType.CARD_TITLE)
	name_label.text = skin.display_name
	text.add_child(name_label)

	var detail := Label.new()
	UiType.apply(detail, UiType.STAT)
	if owned:
		# ✓ (U+2713) kaldirildi: iki font ailesinde de yok, sistem
		# fallback'inden bambaska bir yazi tipiyle cizilirdi. Yesil renk
		# ve soluk kart zaten "sahipsin" mesajini veriyor.
		detail.text = "Sahipsin"
		detail.modulate = Color(0.6, 0.85, 0.6)
	else:
		detail.text = "%d Hamur" % Shop.price_of(skin)
		detail.modulate = SkinData.rarity_color(skin.rarity)
	text.add_child(detail)

	if not owned:
		var buy := Button.new()
		UiType.apply(buy, UiType.SECONDARY_BUTTON)
		buy.text = "Satın Al"
		buy.custom_minimum_size = Vector2(158, 68)
		buy.disabled = not Shop.can_afford(skin)
		buy.pressed.connect(_open_confirm.bind(skin))
		row.add_child(buy)

	return card


# --- Onay diyaloğu (iki bölüm de aynı diyaloğu kullanıyor) ---

func _open_confirm(skin: SkinData) -> void:
	_pending_skin = skin
	_pending_power = -1
	_confirm_text.text = "%s\n%s  ·  %d Hamur\n\nSatın alınsın mı?" % [
		skin.display_name, SkinData.rarity_name(skin.rarity), Shop.price_of(skin)]
	_confirm.visible = true


func _open_power_confirm(type: PowerUp.Type) -> void:
	_pending_skin = null
	_pending_power = int(type)
	_confirm_text.text = "%s  ×1\n%d Hamur\n\nSatın alınsın mı?" % [
		PowerUp.display_name(type), PowerUpEconomy.price(type)]
	_confirm.visible = true


func _close_confirm() -> void:
	_pending_skin = null
	_pending_power = -1
	_confirm.visible = false


func _on_confirm_yes() -> void:
	var skin: SkinData = _pending_skin
	var power: int = _pending_power
	_close_confirm()

	if power >= 0:
		_buy_power(power as PowerUp.Type)
	elif skin != null:
		_buy_skin(skin)
	# Başarılı da olsa başarısız da olsa listeyi tazele: stok, Hamur ve
	# "parası yetmiyor" pasiflikleri anında doğru görünsün.
	refresh()


func _buy_power(type: PowerUp.Type) -> void:
	if PowerUpEconomy.purchase(type):
		AudioManager.play_sfx(&"chest_open", 1.1)
		_show_toast("%s ×1 alındı!  (Stok: ×%d)" % [
			PowerUp.display_name(type), SaveManager.powerup_count(type)])
	else:
		# Araya başka bir harcama girdiyse (teorik) sessizce düşmesin.
		_show_toast("Hamur yetmedi.")


func _buy_skin(skin: SkinData) -> void:
	if Shop.purchase(skin):
		AudioManager.play_sfx(&"chest_open", 1.0)
		_show_toast("%s alındı!" % skin.display_name)
	else:
		_show_toast("Hamur yetmedi.")


## Basit başarı geri bildirimi: yukarı doğru süzülüp sönen bir yazı.
func _show_toast(message: String) -> void:
	_toast.text = message
	_toast.modulate.a = 1.0
	var home: Vector2 = _toast.position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_toast, "position", home - Vector2(0, 40), 1.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(_toast, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tween.chain().tween_callback(func() -> void: _toast.position = home)
