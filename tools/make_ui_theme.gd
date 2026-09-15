extends Node
## M8.6-01 — `assets/visual/ui_theme.tres` uretici. Dev araci.
##
##   godot --headless --path . res://tools/make_ui_theme.tscn
##
## (`-s` betik modu autoload'lari yuklemedigi icin sahne olarak kosar.)
##
## Mevcut temayi yukler, bu betigin URETTIGI type'lari (GENERATED) silip
## UiTokens + UiCoreAssets'ten yeniden kurar ve kaydeder. M8.5 kabugunun
## kullandigi eski roller (Button varsayilani, CardPanel, ChipPanel,
## Display, ScreenTitle, SecondaryButton, IconButton, TabButton, ToggleOn/Off
## ...) DOKUNULMADAN kalir: production ekranlar bu turda degismiyor.
##
## Tema dosyasi elle duzenlenmez; renk/olcu degisikligi UiTokens'a yazilir ve
## bu betik yeniden calistirilir. Variation listesi docs/UI_VISUAL_SYSTEM.md
## ve tools/ui_foundation_test.gd ile ayni olmali.

const THEME_PATH: String = "res://assets/visual/ui_theme.tres"

const FONT_DISPLAY: FontFile = preload("res://assets/fonts/Baloo2-ExtraBold.ttf")
const FONT_TITLE: FontFile = preload("res://assets/fonts/Baloo2-Bold.ttf")
const FONT_NUM: FontFile = preload("res://assets/fonts/Nunito-Bold.ttf")
const FONT_BODY: FontFile = preload("res://assets/fonts/Nunito-SemiBold.ttf")

## Bu betigin sahip oldugu type'lar. Eski (M8.5) roller bu listede YOK.
const GENERATED: Array[StringName] = [
	# Paneller
	&"PanelBase", &"PanelCream", &"PanelPurple", &"PanelDark", &"PanelCard",
	&"PanelModal", &"PanelElevated", &"PanelListRow",
	# Butonlar
	&"ButtonPrimary", &"ButtonSecondary", &"ButtonPurchase", &"ButtonDanger",
	&"ButtonIcon", &"ButtonRoundIcon", &"ButtonCTA", &"ButtonResourceAdd",
	# Etiketler (krem yuzey)
	&"LabelDisplay", &"LabelTitle", &"LabelSection", &"LabelBody", &"LabelCaption",
	&"LabelPrice", &"LabelPositive", &"LabelWarning", &"LabelDisabled", &"LabelStat",
	# Etiketler (koyu yuzey / vurgu)
	&"LabelDisplayOnDark", &"LabelTitleOnDark", &"LabelSectionOnDark", &"LabelBodyOnDark",
	&"LabelCaptionOnDark", &"LabelStatOnDark", &"LabelSectionOnAccent",
	&"LabelBadge", &"LabelBadgeOnDark",
	# Gameplay shell (M8.6-02)
	&"LabelHudScore", &"LabelHudCaption", &"PowerSlot", &"PowerSlotArmed", &"PowerSlotEmpty",
	&"PanelStrip", &"PanelHud", &"PanelHudScore", &"PanelTray", &"PanelHudFrame", &"PanelHudCard",
	&"LabelHudCaptionDark", &"ButtonHud", &"ButtonHudExit", &"ProgressBarHud",
	&"PanelHudPercent", &"PanelHudPill", &"PanelHudBadge", &"PanelHudPortrait",
	# Oyun bilesenleri
	&"ResourcePill", &"HeaderRibbon", &"SectionTag", &"ProgressBarMint", &"ProgressBarGold",
	&"Badge", &"LockBadge", &"EquippedBadge", &"NewBadge", &"CountBadge",
	&"SwitchOn", &"SwitchOff",
	# Rarity
	&"RarityCommon", &"RarityRare", &"RarityEpic", &"RarityLegendary",
	&"RarityFrameCommon", &"RarityFrameRare", &"RarityFrameEpic", &"RarityFrameLegendary",
]

var _theme: Theme


func _ready() -> void:
	_theme = load(THEME_PATH) as Theme
	if _theme == null:
		printerr("Tema yuklenemedi: ", THEME_PATH)
		get_tree().quit(1)
		return
	var existing: PackedStringArray = _theme.get_type_list()
	for type in GENERATED:
		if existing.has(type):
			_theme.remove_type(type)
	_build_panels()
	_build_buttons()
	_build_labels()
	_build_components()
	_build_rarity()
	var err: int = ResourceSaver.save(_theme, THEME_PATH)
	print("ui_theme.tres -> ", "ok" if err == OK else "HATA %d" % err,
		" (", GENERATED.size(), " uretilmis type)")
	get_tree().quit(0 if err == OK else 1)


# --- Yardimcilar -------------------------------------------------------------

func _panel(type: StringName, sprite: String, tint: Color, content: Vector4) -> void:
	_theme.set_type_variation(type, &"PanelContainer")
	_theme.set_stylebox("panel", type, UiKit.style(sprite, tint, content))


func _label(type: StringName, font: FontFile, size: int, color: Color,
		shadow: bool = false) -> void:
	_theme.set_type_variation(type, &"Label")
	_theme.set_font("font", type, font)
	_theme.set_font_size("font_size", type, size)
	_theme.set_color("font_color", type, color)
	if shadow:
		_theme.set_color("font_shadow_color", type, UiTokens.TEXT_SHADOW)
		_theme.set_constant("shadow_offset_x", type, 0)
		_theme.set_constant("shadow_offset_y", type, 2)
		_theme.set_constant("shadow_outline_size", type, 1)


## Basili durum: ayni govde koyulasir ve icerik alt bevel'e dogru 3 px iner
## (UiMotion.attach_press olcek animasyonunu ustune ekler).
func _pressed(sprite: String, tint: Color, content: Vector4) -> StyleBoxTexture:
	return UiKit.style(sprite, tint.darkened(0.12),
		Vector4(content.x, content.y + 3.0, content.z, maxf(0.0, content.w - 3.0)))


func _button(type: StringName, sprite: String, tint: Color, content: Vector4,
		font: FontFile, font_size: int, text: Color, text_disabled: Color,
		icon_max: int = 28) -> void:
	_theme.set_type_variation(type, &"Button")
	_theme.set_stylebox("normal", type, UiKit.style(sprite, tint, content))
	_theme.set_stylebox("hover", type, UiKit.style(sprite, tint.lightened(0.06), content))
	_theme.set_stylebox("pressed", type, _pressed(sprite, tint, content))
	_theme.set_stylebox("hover_pressed", type, _pressed(sprite, tint, content))
	_theme.set_stylebox("disabled", type, UiKit.style(sprite, UiTokens.DISABLED, content))
	_theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	_theme.set_font("font", type, font)
	_theme.set_font_size("font_size", type, font_size)
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		_theme.set_color(state, type, text)
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		_theme.set_color(state, type, text.darkened(0.1))
	_theme.set_color("font_disabled_color", type, text_disabled)
	for state in ["icon_normal_color", "icon_hover_color", "icon_focus_color"]:
		_theme.set_color(state, type, text)
	for state in ["icon_pressed_color", "icon_hover_pressed_color"]:
		_theme.set_color(state, type, text.darkened(0.1))
	_theme.set_color("icon_disabled_color", type, text_disabled)
	_theme.set_constant("icon_max_width", type, icon_max)
	_theme.set_constant("h_separation", type, UiTokens.SPACE_SM)


# --- Paneller ----------------------------------------------------------------

func _build_panels() -> void:
	var navy := Color(UiTokens.NAVY_PURPLE, 0.94)
	_panel(&"PanelBase", "panel_round", navy, Vector4(20, 16, 20, 18))
	_panel(&"PanelCream", "popup_body", UiTokens.CREAM, Vector4(24, 22, 24, 26))
	_panel(&"PanelPurple", "panel_bevel", Color(UiTokens.PLUM, 0.96), Vector4(16, 10, 18, 14))
	_panel(&"PanelDark", "panel_bevel", Color(UiTokens.NAVY_PURPLE_DEEP, 0.96), Vector4(16, 10, 18, 14))
	_panel(&"PanelCard", "card_large", UiTokens.CREAM, Vector4(16, 14, 16, 22))
	# Modal: ust kenar kurdele icin bos birakilir (kurdele -34 px tasar).
	_panel(&"PanelModal", "popup_body", UiTokens.CREAM, Vector4(36, 56, 36, 36))
	_panel(&"PanelElevated", "card_bevel", UiTokens.CREAM, Vector4(14, 10, 14, 16))
	# Liste satiri: ayni vanilya ailesinden bir ton koyu krem, TAM opak
	# (0.94 alfa koyu zemin ustunde griye kayiyordu); kartlardan bir kademe
	# geri, ama ayni paket.
	_panel(&"PanelListRow", "list_row", UiTokens.CREAM_DEEP, Vector4(14, 8, 16, 14))
	# HUD skor/hedef plakasi (M8.6-02): PanelPurple govdesi, dar dikey pay —
	# 64-92 px satirlara sigsin.
	_panel(&"PanelHud", "panel_bevel", Color(UiTokens.PLUM, 0.96), Vector4(14, 5, 16, 11))
	# Gameplay ust HUD (M8.6-02 HUD v2): glossy lavanta skor plakasi, erik guc
	# tepsisi (2 madalyon), lavanta cerceve + krem kart (hedef / Siradaki).
	# HUD v3 (hud_target.png): mor kapsul skor, acik lavanta-krem tepsi, kalin
	# koyu-lavanta cerceve + krem kart (label_round: yumusak kose, cizgi yok).
	# HUD v4: govdeler pismis bevel/dudakli sprite'lardan (btn_bevel: cizgi +
	# bevel; card_bevel: yumusak alt dudak) — duz label_round kutu hissi
	# veriyordu. Dis halka/golge/gloss UiKit.hud_* dekor katmaninda.
	# HUD v5 (yumusatma): govdeler `*_soft` surumlerinden — siyah cizgi
	# tint'in koyu tonuna (erik/koyu lavanta) kaldirildi, dis golge yari
	# alfa; tepsi `title_oval` pill (kose yok, organik candy taban).
	_panel(&"PanelHudScore", "btn_bevel_soft", UiTokens.LAVENDER_DEEP, Vector4(20, 4, 20, 12))
	_panel(&"PanelTray", "title_oval", UiTokens.TRAY_CREAM, Vector4(6, 6, 6, 12))
	_panel(&"PanelHudFrame", "btn_bevel_soft", UiTokens.LAVENDER_DEEP.lerp(UiTokens.LAVENDER_LIGHT, 0.14), Vector4(7, 5, 7, 10))
	_panel(&"PanelHudCard", "card_bevel_soft", UiTokens.CREAM, Vector4(12, 2, 12, 6))
	_panel(&"PanelHudPill", "title_oval", UiTokens.CREAM, Vector4(14, 2, 14, 6))
	_panel(&"PanelHudPercent", "label_trapezoid", UiTokens.NAVY_PURPLE_DEEP, Vector4(12, 1, 14, 3))
	_panel(&"PanelHudBadge", "btn_bevel_soft", UiTokens.GOLD, Vector4(8, 2, 8, 8))
	_panel(&"PanelHudPortrait", "frame_round12", UiTokens.CREAM_DEEP, Vector4(5, 1, 5, 3))
	# Evrim seridi tepsisi (M8.6-02): koyu yuvarlak plaka, dar iceri pay.
	_panel(&"PanelStrip", "panel_bevel", Color(UiTokens.PLUM, 0.94), Vector4(14, 4, 14, 8))


# --- Butonlar ----------------------------------------------------------------

func _build_buttons() -> void:
	# Yazi butonlarinda dikey hizalama (M8.6-01 polish) EKRAN GORUNTUSUNDEN
	# OLCULDU (tools/ui_system_gallery.tscn -- shots, piksel sayimi):
	#   - btn_normal (58): pill govdesi 1..52 (53..57 golge) -> gorsel merkez
	#     rect ustunden 26. Baloo 2 Bold 22 buyuk harf murekkebi Button
	#     icinde icerik merkezinin ~2.5 px ustune duser (ascent 24 / descent
	#     12, diyakritik payi buyuk). Eski 6/14 murekkebi 3.5 px yukarida
	#     birakiyordu; 10/10 ile murekkep merkezi 26.5 (pill 26).
	#   - btn_cta (88): pill 0..83 -> merkez 41.5; UiKit.cta govdesi (EB 28)
	#     icerik merkezinin ~1 px ustunde -> 14/16 ile murekkep 42.
	#   Toplam ust+alt (20 / 30) korunur; basili durum +3 px ekler. Pasif
	#   yazi her butonda koyu (govde her zaman lavanta-gri): ~4.8:1.
	var normal := Vector4(24, 10, 24, 10)
	_button(&"ButtonPrimary", "btn_normal", UiTokens.CYAN, normal,
		FONT_TITLE, 22, UiTokens.TEXT_ON_ACCENT, UiTokens.TEXT_DISABLED)
	_button(&"ButtonSecondary", "btn_normal", UiTokens.LAVENDER_SURFACE, normal,
		FONT_TITLE, 22, UiTokens.TEXT_PRIMARY, UiTokens.TEXT_DISABLED)
	_button(&"ButtonPurchase", "btn_normal", UiTokens.MINT, normal,
		FONT_TITLE, 22, UiTokens.TEXT_ON_ACCENT, UiTokens.TEXT_DISABLED)
	_button(&"ButtonDanger", "btn_normal", UiTokens.PINK, normal,
		FONT_TITLE, 22, UiTokens.TEXT_ON_DARK, UiTokens.TEXT_DISABLED)
	# Ikon butonlari: kare (ayarlar/geri) lavanta, daire (kapat) pembe.
	_button(&"ButtonIcon", "btn_square", UiTokens.LAVENDER, Vector4(12, 10, 12, 16),
		FONT_TITLE, 22, UiTokens.TEXT_ON_DARK, UiTokens.TEXT_DISABLED, 30)
	_button(&"ButtonRoundIcon", "btn_circle", UiTokens.PINK, Vector4(14, 12, 14, 20),
		FONT_TITLE, 22, UiTokens.TEXT_ON_DARK, UiTokens.TEXT_DISABLED, 28)
	# Kahraman CTA (88): pencere/ana sayfa birincil eylemi. Pill 0..83.
	_button(&"ButtonCTA", "btn_cta", UiTokens.CYAN, Vector4(28, 14, 28, 16),
		FONT_DISPLAY, 28, UiTokens.TEXT_ON_ACCENT, UiTokens.TEXT_DISABLED, 34)
	# Guc slotu (M8.6-02 polish): madalyon — `btn_circle` (3B basilabilir
	# daire), uc durum ayri variation: normal krem, silahli cyan, stok 0
	# pasif lavanta-gri. Ikon/rozet/parilti UiKit.power_slot cocuklari.
	var slot := Vector4(6, 6, 6, 12)
	_button(&"PowerSlot", "btn_circle", UiTokens.CREAM, slot,
		FONT_TITLE, 16, UiTokens.TEXT_PRIMARY, UiTokens.TEXT_DISABLED)
	_button(&"PowerSlotArmed", "btn_circle", UiTokens.CYAN, slot,
		FONT_TITLE, 16, UiTokens.TEXT_ON_ACCENT, UiTokens.TEXT_DISABLED)
	# Stok 0: ayni candy ailesi — acik lavanta govde (gri placeholder degil).
	_button(&"PowerSlotEmpty", "btn_circle", UiTokens.LAVENDER_SURFACE, slot,
		FONT_TITLE, 16, UiTokens.TEXT_DISABLED, UiTokens.TEXT_DISABLED)
	# Gameplay HUD kose butonlari (HUD v3): koyu lavanta-mor kare, buyuk beyaz
	# picto; cikis pembe. Halka/gloss/golge UiKit.hud_icon_button ekler.
	_button(&"ButtonHud", "btn_bevel_soft", UiTokens.LAVENDER_DEEP, Vector4(8, 6, 8, 14),
		FONT_TITLE, 22, UiTokens.TEXT_ON_DARK, UiTokens.TEXT_DISABLED, 34)
	_button(&"ButtonHudExit", "btn_bevel_soft", UiTokens.PINK, Vector4(8, 6, 8, 14),
		FONT_TITLE, 22, UiTokens.TEXT_ON_DARK, UiTokens.TEXT_DISABLED, 34)
	# Kaynak pill'inin nane "+" butonu.
	_button(&"ButtonResourceAdd", "resource_btn", UiTokens.MINT, Vector4(8, 6, 8, 10),
		FONT_TITLE, 18, UiTokens.TEXT_ON_ACCENT, UiTokens.TEXT_DISABLED, 20)


# --- Etiketler ---------------------------------------------------------------

func _build_labels() -> void:
	# Krem yuzey (kart, modal, satir): koyu erik.
	_label(&"LabelDisplay", FONT_DISPLAY, 42, UiTokens.TEXT_PRIMARY)
	_label(&"LabelTitle", FONT_DISPLAY, 32, UiTokens.TEXT_PRIMARY)
	_label(&"LabelSection", FONT_TITLE, 24, UiTokens.TEXT_PRIMARY)
	_label(&"LabelBody", FONT_BODY, 19, UiTokens.TEXT_PRIMARY)
	_label(&"LabelCaption", FONT_BODY, 15, UiTokens.TEXT_SECONDARY)
	_label(&"LabelPrice", FONT_NUM, 21, UiTokens.TEXT_PRICE)
	_label(&"LabelPositive", FONT_NUM, 18, UiTokens.TEXT_POSITIVE)
	_label(&"LabelWarning", FONT_NUM, 18, UiTokens.TEXT_WARNING)
	_label(&"LabelDisabled", FONT_BODY, 18, UiTokens.DISABLED_DEEP)
	_label(&"LabelStat", FONT_NUM, 20, UiTokens.TEXT_PRIMARY)
	# Koyu yuzey (dunya, plaka, kurdele): beyaz, golgeli.
	_label(&"LabelDisplayOnDark", FONT_DISPLAY, 42, UiTokens.TEXT_ON_DARK, true)
	_label(&"LabelTitleOnDark", FONT_DISPLAY, 32, UiTokens.TEXT_ON_DARK, true)
	_label(&"LabelSectionOnDark", FONT_TITLE, 24, UiTokens.TEXT_ON_DARK, true)
	_label(&"LabelBodyOnDark", FONT_BODY, 19, UiTokens.TEXT_ON_DARK)
	_label(&"LabelCaptionOnDark", FONT_BODY, 15, UiTokens.TEXT_ON_DARK_MUTED)
	_label(&"LabelStatOnDark", FONT_NUM, 22, UiTokens.TEXT_ON_DARK, true)
	# Vurgu yuzeyi (cyan/nane/altin etiket): lacivert.
	_label(&"LabelSectionOnAccent", FONT_TITLE, 20, UiTokens.TEXT_ON_ACCENT)
	_label(&"LabelBadge", FONT_TITLE, 16, UiTokens.TEXT_ON_ACCENT)
	_label(&"LabelBadgeOnDark", FONT_TITLE, 14, UiTokens.TEXT_ON_DARK)
	# Gameplay HUD (M8.6-02): skor rakami buyuk Nunito (veri), plaka
	# basligi kucuk buyuk-harf Nunito (SKOR / SIRADAKI).
	_label(&"LabelHudScore", FONT_NUM, 30, UiTokens.TEXT_ON_DARK, true)
	_label(&"LabelHudCaption", FONT_NUM, 13, UiTokens.TEXT_ON_DARK_MUTED)
	# Krem/lavanta ustunde kucuk buyuk-harf baslik (HEDEF / SKOR / SIRADAKI).
	_label(&"LabelHudCaptionDark", FONT_NUM, 13, UiTokens.TEXT_SECONDARY)


# --- Oyun bilesenleri --------------------------------------------------------

func _build_components() -> void:
	_panel(&"ResourcePill", "resource_bar", Color(UiTokens.NAVY_PURPLE_DEEP, 0.96), Vector4(8, 4, 14, 4))
	_panel(&"HeaderRibbon", "header_ribbon", UiTokens.PINK, Vector4(40, 4, 40, 16))
	_panel(&"SectionTag", "label_trapezoid", UiTokens.CYAN, Vector4(20, 2, 24, 6))
	_panel(&"Badge", "badge_round", UiTokens.GOLD, Vector4(10, 2, 10, 5))
	_panel(&"LockBadge", "badge_round", UiTokens.DISABLED_DEEP, Vector4(10, 2, 10, 5))
	_panel(&"EquippedBadge", "frame_round20", UiTokens.MINT, Vector4(16, 4, 16, 6))
	_panel(&"NewBadge", "badge_round", UiTokens.PINK, Vector4(10, 2, 10, 5))
	_panel(&"CountBadge", "badge_round", UiTokens.GOLD, Vector4(8, 1, 8, 4))
	# Ilerleme: koyu ray + nane dolgu; altin dolgu yalniz premium (Legendary,
	# odul sandigi).
	for entry in [[&"ProgressBarMint", UiTokens.MINT], [&"ProgressBarGold", UiTokens.GOLD]]:
		var type: StringName = entry[0]
		_theme.set_type_variation(type, &"ProgressBar")
		_theme.set_stylebox("background", type,
			UiKit.style("slider_thin_bg", Color(UiTokens.NAVY_PURPLE_DEEP, 0.9), Vector4(2, 2, 2, 3)))
		_theme.set_stylebox("fill", type, UiKit.style("slider_fill_sm", entry[1]))
	# HUD hedef cubugu (v3): koyu mor cizgili ray + parlak nane dolgu.
	_theme.set_type_variation(&"ProgressBarHud", &"ProgressBar")
	_theme.set_stylebox("background", &"ProgressBarHud",
		UiKit.style("slider_thin_bg", UiTokens.NAVY_PURPLE, Vector4(3, 2, 3, 3)))
	_theme.set_stylebox("fill", &"ProgressBarHud", UiKit.style("slider_fill_sm", UiTokens.MINT))
	# Anahtar rayi: acik nane, kapali lavanta-gri.
	_panel(&"SwitchOn", "switch_track", UiTokens.MINT, Vector4(0, 0, 0, 0))
	_panel(&"SwitchOff", "switch_track", Color("b9b0c9"), Vector4(0, 0, 0, 0))


# --- Rarity ------------------------------------------------------------------

func _build_rarity() -> void:
	for rarity in [SkinData.Rarity.COMMON, SkinData.Rarity.RARE,
			SkinData.Rarity.EPIC, SkinData.Rarity.LEGENDARY]:
		var name: String = SkinData.rarity_name(rarity)
		_panel(StringName("Rarity" + name), "label_trapezoid",
			UiTokens.rarity_tint(rarity), Vector4(14, 0, 18, 4))
		_panel(StringName("RarityFrame" + name), "item_frame",
			UiTokens.rarity_color(rarity), Vector4(6, 6, 6, 8))
