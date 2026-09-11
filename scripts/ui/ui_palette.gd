class_name UiPalette
extends RefCounted
## Production UI sisteminin renk ve katman tanimlari (M8.5-10).
##
## Katman hiyerarsisi — her ekran ayni bes katmani kullanir, kendi stilini
## icat etmez:
##
##   BACKGROUND  candy-night zemin, koyu ve dusuk kontrast (ShellBackdrop)
##   SURFACE     yari saydam erik/lacivert panel     -> tema `PanelContainer`
##   CARD        biraz daha acik, ince pastel kenar  -> tema `CardPanel`
##   PRIMARY CTA parlak candy cyan (owner pill dokusu ya da tema `Button`)
##   SECONDARY   sakin, cizgili pill                 -> tema `SecondaryButton`
##   SELECTED    nane / altin vurgu
##   DISABLED    doygunlugu alinmis ama okunur
##
## Dekorasyon butcesi: ~%10 kahraman/CTA yogun, %30 orta, %60 sakin yuzey.
## Renkler owner asset'lerinden OLCULDU (cta_button_normal, logo_lockup,
## board_background_night, icon_*): paletteki hicbir ton uydurma degil.

## --- Zemin ve yuzeyler ---
const NIGHT_DEEP: Color = Color("0d153f")
const NIGHT_MID: Color = Color("2d2a6c")
## Kabuk ekranlarinin zemin karartmasi: gece zemini karakterlerin
## arkasinda parlak, UI'in arkasinda sakin olmali.
const BACKDROP_TINT: Color = Color(0.62, 0.6, 0.78, 1.0)
const BACKDROP_SCRIM: Color = Color(0.07, 0.05, 0.18, 0.5)

## --- Candy vurgular (owner asset'lerinden) ---
const CYAN: Color = Color("5eddf9")
const CYAN_DEEP: Color = Color("2f8fd0")
const PINK: Color = Color("f06aa8")
const GOLD: Color = Color("ffd166")
const GOLD_BRIGHT: Color = Color("fee85f")
const LAVENDER: Color = Color("c694fa")
const MINT: Color = Color("6ddc8b")
const CREAM: Color = Color("fcf7ec")

## --- Metin ---
const TEXT: Color = Color(0.99, 0.97, 1.0)
const TEXT_MUTED: Color = Color(1, 1, 1, 0.62)
const TEXT_FAINT: Color = Color(1, 1, 1, 0.42)
## Krem candy panel (modal) ustundeki koyu erik yazi.
const TEXT_ON_CREAM: Color = Color(0.36, 0.16, 0.32)
const TEXT_ON_CREAM_SOFT: Color = Color(0.48, 0.29, 0.41)
## Cyan candy buton ustundeki lacivert.
const TEXT_ON_CYAN: Color = Color(0.06, 0.18, 0.3)

## --- Durumlar ---
const SELECTED: Color = MINT
const SELECTED_SOFT: Color = Color(0.43, 0.86, 0.55, 0.16)
const DISABLED_FACE: Color = Color(0.5, 0.52, 0.66)
const DISABLED_TEXT: Color = Color(1, 1, 1, 0.45)

## Alt sekme cubugu: secili altin, pasif soluk beyaz.
const TAB_ACTIVE: Color = Color("ffd66b")
const TAB_IDLE: Color = Color(1, 1, 1, 0.55)

## Paketten turetilen tek renkli ikon maskeleri (tools/make_pack_icons.gd).
## Hepsi BEYAZ; rengi `modulate`/`self_modulate` verir.
const ICON_HOME: Texture2D = preload("res://assets/visual/ui/icons/home.png")
const ICON_PLAY: Texture2D = preload("res://assets/visual/ui/icons/play.png")
const ICON_BADGE: Texture2D = preload("res://assets/visual/ui/icons/badge.png")
const ICON_CART: Texture2D = preload("res://assets/visual/ui/icons/cart.png")
const ICON_SETTINGS: Texture2D = preload("res://assets/visual/ui/icons/settings.png")
const ICON_VOLUME: Texture2D = preload("res://assets/visual/ui/icons/volume.png")
const ICON_VOLUME_MUTE: Texture2D = preload("res://assets/visual/ui/icons/volume_mute.png")
const ICON_CLOSE: Texture2D = preload("res://assets/visual/ui/icons/close.png")
const ICON_BACK: Texture2D = preload("res://assets/visual/ui/icons/back.png")
const ICON_INFO: Texture2D = preload("res://assets/visual/ui/icons/info.png")
const ICON_CHECK: Texture2D = preload("res://assets/visual/ui/icons/check.png")
const ICON_TROPHY: Texture2D = preload("res://assets/visual/ui/icons/trophy.png")
const ICON_SPARKLE: Texture2D = preload("res://assets/visual/ui/icons/sparkle.png")
const ICON_GIFT: Texture2D = preload("res://assets/visual/ui/icons/gift.png")


## Rarity kenar rengi: kartin ince pastel cizgisi. SkinData'nin doygun
## rarity rengi koyu kart ustunde bagiriyordu; burada yumusatiliyor.
static func rarity_border(color: Color) -> Color:
	return color.lerp(Color.WHITE, 0.25) * Color(1, 1, 1, 0.75)


## Ikon kutusu: tek renkli maske ikon, sabit kare icinde oranini koruyarak.
static func icon_rect(texture: Texture2D, box: float, tint: Color = TEXT) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(box, box)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.self_modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Durum cipi: kucuk pill icinde ikon + deger ("Hamur 315", "12/20").
## Dort sekmede de ayni cip kullanilir; "Hamur: 315 · Koleksiyon: 18/20"
## gibi birlesik satirlar bu turda kalkti.
static func chip(icon: Texture2D, text: String, icon_height: int = 26,
		tint: Color = Color.WHITE) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ChipPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	if icon != null:
		var size: Vector2 = icon.get_size()
		var rect := TextureRect.new()
		rect.texture = icon
		rect.custom_minimum_size = Vector2(
			roundf(float(icon_height) * size.x / size.y), float(icon_height))
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.self_modulate = tint
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rect)
	var label := Label.new()
	label.name = "Value"
	UiType.apply(label, UiType.STAT)
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	panel.set_meta(&"value_label", label)
	return panel


## Cipin degerini gunceller; deger degistiyse kucuk bir pop oynatir
## (satin alma sonrasi bakiye geri bildirimi).
static func set_chip_value(panel: PanelContainer, text: String, pop: bool = true) -> void:
	if panel == null or not panel.has_meta(&"value_label"):
		return
	var label: Label = panel.get_meta(&"value_label")
	if label.text == text:
		return
	label.text = text
	if pop:
		UiMotion.pop(panel)


## Ikonlu yuvarlak buton (ayarlar disli, kapat, geri).
static func icon_button(texture: Texture2D, size: float = 64.0,
		tint: Color = TEXT) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"IconButton"
	button.custom_minimum_size = Vector2(size, size)
	button.focus_mode = Control.FOCUS_NONE
	var icon := icon_rect(texture, size * 0.5, tint)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.custom_minimum_size = Vector2.ZERO
	button.add_child(icon)
	UiMotion.attach_press(button)
	return button


## Krem candy panel (modal) üstündeki "hayalet" buton: temanın beyaz
## SecondaryButton'ı krem zeminde görünmez, erik tonlu yarı saydam dolgu
## kullanılıyor. Ayarlar, mağaza onayı ve kapatma ikonu aynı stili paylaşır.
static func plum_ghost_box(alpha: float, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var plum: Color = TEXT_ON_CREAM
	box.bg_color = Color(plum.r, plum.g, plum.b, alpha)
	box.set_border_width_all(2)
	box.border_color = Color(plum.r, plum.g, plum.b, alpha + 0.12)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 20.0
	box.content_margin_right = 20.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 12.0
	return box


static func style_ghost_on_cream(button: Button, radius: int = 24) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, TEXT_ON_CREAM)
	button.add_theme_stylebox_override("normal", plum_ghost_box(0.10, radius))
	button.add_theme_stylebox_override("hover", plum_ghost_box(0.16, radius))
	button.add_theme_stylebox_override("pressed", plum_ghost_box(0.06, radius))
	button.add_theme_stylebox_override("hover_pressed", plum_ghost_box(0.06, radius))
	button.focus_mode = Control.FOCUS_NONE
