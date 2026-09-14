extends Control
## M8.6-01 — Production UI sistemi galerisi. DEV ARACI, production
## navigasyonuna BAGLI DEGIL.
##
## Tema variation'larini, UiKit bilesenlerini ve bes gercek urun modulunu
## (guc satiri, skin karti, odul blogu, HUD plakasi, pencere govdesi) tek
## ekranda gosterir; amaç "hepsi TEK oyundan cikmis mi?" sorusuna gozle
## cevap vermek. Ekran DEGIL, bilesen ornekleri.
##
## Kullanim (masaustu):
##   godot --path . res://tools/ui_system_gallery.tscn                 etkilesimli
##   godot --path . res://tools/ui_system_gallery.tscn -- shots <dir>  cekimler
## Cihazda: sag alttaki ok butonu sayfalari sirayla gezer; sayfalar dikeyde
## kaydirilabilir.
##
## Hicbir oyun kurali, ekonomi, kayit degeri BURADAN degismez.

const BACKDROP_SCENE: PackedScene = preload("res://scenes/ui/shell_backdrop.tscn")

## Squishy Merge sanati (kimlik katmani) — galeride LayerLab iskeletinin icinde.
const ART_DOUGH: Texture2D = preload("res://assets/visual/ui/icon_dough.png")
const ART_BOMB: Texture2D = preload("res://assets/visual/ui/power_bomb.png")
const ART_UPGRADE: Texture2D = preload("res://assets/visual/ui/power_upgrade.png")
const ART_TIER2: Texture2D = preload("res://assets/visual/dumpling_tier2.png")
const ART_TIER6: Texture2D = preload("res://assets/visual/dumpling_tier6.png")
const ART_SKIN_LEGENDARY: Texture2D = preload("res://assets/visual/skins/previews/skin_legendary_altin_hamur.png")
const ART_SKIN_RAINBOW: Texture2D = preload("res://assets/visual/skins/previews/skin_legendary_gokkusagi.png")
const ART_SKIN_EPIC: Texture2D = preload("res://assets/visual/skins/previews/skin_epic_safran.png")
const ART_SKIN_RARE: Texture2D = preload("res://assets/visual/skins/previews/skin_rare_ispanak.png")
const ART_SKIN_SADE: Texture2D = preload("res://assets/visual/skins/previews/skin_common_sade.png")
const ART_STAR: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
const ART_CROWN: Texture2D = preload("res://assets/visual/ui/icon_crown.png")
const ART_FLAG: Texture2D = preload("res://assets/visual/ui/icon_flag.png")
const ART_CHEST: Texture2D = preload("res://assets/visual/ui/chest_open.png")

const SHOT_SIZES: Array[Vector2i] = [
	Vector2i(720, 1280), Vector2i(720, 1560), Vector2i(540, 960), Vector2i(1080, 2340)]
const PAGE_NAMES: Array[String] = ["palette_type", "panels", "buttons", "components", "modules"]
const PAGE_TITLES: Array[String] = ["Palet · Tipografi", "Paneller", "Butonlar", "Bileşenler", "Modüller"]

var _pages: Array[Control] = []
var _nav: Control
var _title: PanelContainer
var _shot_dir: String = ""
var _active: int = 0


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "shots":
		_shot_dir = args[1]
	add_child(BACKDROP_SCENE.instantiate())
	# _page() sayfayi agaca kendisi ekler (ScrollContainer koku).
	_pages = [_page_palette(), _page_panels(), _page_buttons(), _page_components(), _page_modules()]
	for page in _pages:
		page.visible = false
	_title = _build_title_bar()
	add_child(_title)
	_nav = _build_nav()
	add_child(_nav)
	_show(0)
	if _shot_dir != "":
		await _capture_all()
		get_tree().quit()


func _show(index: int) -> void:
	_active = index
	for i in _pages.size():
		_pages[i].visible = i == index
	var text: Label = _title.get_meta(&"title_label")
	text.text = "%s  %d/%d" % [PAGE_TITLES[index], index + 1, _pages.size()]


# --- Iskelet -----------------------------------------------------------------

func _build_title_bar() -> PanelContainer:
	var ribbon := UiKit.header_ribbon("", UiTokens.LAVENDER)
	ribbon.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	ribbon.offset_left = 120.0
	ribbon.offset_right = -120.0
	ribbon.offset_top = 8.0
	ribbon.offset_bottom = 78.0
	ribbon.mouse_filter = MOUSE_FILTER_IGNORE
	var text: Label = ribbon.get_meta(&"title_label")
	text.theme_type_variation = &"LabelSectionOnDark"
	return ribbon


func _build_nav() -> Control:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	row.offset_left = -140.0
	row.offset_right = -10.0
	row.offset_top = -74.0
	row.offset_bottom = -10.0
	row.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	var prev := UiKit.icon_button("arrow_prev", &"ButtonIcon", 60.0)
	prev.pressed.connect(func() -> void: _show((_active - 1 + _pages.size()) % _pages.size()))
	row.add_child(prev)
	var next := UiKit.icon_button("arrow_next", &"ButtonIcon", 60.0)
	next.pressed.connect(func() -> void: _show((_active + 1) % _pages.size()))
	row.add_child(next)
	return row


## Sayfa: kaydirilabilir dikey sutun, baslik cubugunun altindan baslar.
func _page(name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.offset_top = 92.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", UiTokens.SPACE_LG)
	margin.add_theme_constant_override("margin_right", UiTokens.SPACE_LG)
	margin.add_theme_constant_override("margin_bottom", 90)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	margin.add_child(column)
	column.set_meta(&"scroll", scroll)
	return column


func _page_root(column: VBoxContainer) -> Control:
	return column.get_meta(&"scroll")


func _heading(column: VBoxContainer, text: String) -> void:
	var tag := UiKit.section_tag(text.to_upper(), UiTokens.PINK)
	column.add_child(tag)


func _note(column: VBoxContainer, text: String) -> void:
	var note := UiKit.label(text, &"LabelCaptionOnDark")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)


func _row(separation: int = UiTokens.SPACE_MD) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	return row


func _flow(separation: int = UiTokens.SPACE_SM) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", separation)
	flow.add_theme_constant_override("v_separation", separation)
	return flow


func _gap(column: VBoxContainer, height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	column.add_child(gap)


# --- 1. Palet + tipografi ----------------------------------------------------

func _page_palette() -> Control:
	var column := _page("PalettePage")
	_heading(column, "Palet")
	var swatches := GridContainer.new()
	swatches.columns = 4
	swatches.add_theme_constant_override("h_separation", UiTokens.SPACE_SM)
	swatches.add_theme_constant_override("v_separation", UiTokens.SPACE_SM)
	column.add_child(swatches)
	for entry in [
			["Dünya", UiTokens.WORLD_INDIGO], ["Lacivert", UiTokens.NAVY_PURPLE],
			["Erik", UiTokens.PLUM], ["Krem", UiTokens.CREAM],
			["Lavanta", UiTokens.LAVENDER], ["Lav. yüzey", UiTokens.LAVENDER_SURFACE],
			["Cyan", UiTokens.CYAN], ["Pembe", UiTokens.PINK],
			["Nane", UiTokens.MINT], ["Altın", UiTokens.GOLD],
			["Pasif", UiTokens.DISABLED], ["Metin", UiTokens.TEXT_PRIMARY],
			["Common", UiTokens.RARITY_COMMON], ["Rare", UiTokens.RARITY_RARE],
			["Epic", UiTokens.RARITY_EPIC], ["Legendary", UiTokens.RARITY_LEGENDARY]]:
		swatches.add_child(_swatch(entry[0], entry[1]))

	_heading(column, "Tipografi · koyu yüzey")
	for entry in [[&"LabelDisplayOnDark", "Display 42 · Baloo EB"],
			[&"LabelTitleOnDark", "Title 32 · Baloo EB"],
			[&"LabelSectionOnDark", "Section 24 · Baloo B"],
			[&"LabelStatOnDark", "Stat 22 · Nunito B"],
			[&"LabelBodyOnDark", "Body 19 · Nunito SB"],
			[&"LabelCaptionOnDark", "Caption 15 · Nunito SB"]]:
		column.add_child(UiKit.label(entry[1], entry[0]))

	_heading(column, "Tipografi · krem yüzey")
	var card := UiKit.panel(&"PanelCard")
	column.add_child(card)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	card.add_child(list)
	for entry in [[&"LabelDisplay", "Display 42"], [&"LabelTitle", "Title 32"],
			[&"LabelSection", "Section 24"], [&"LabelStat", "Stat 20 · 1 240"],
			[&"LabelBody", "Body 19 · Taşan parçalar temizlenir."],
			[&"LabelCaption", "Caption 15 · Kalıcı · bir kez alınır"],
			[&"LabelPrice", "Price 21 · 120 Hamur"],
			[&"LabelPositive", "Positive 18 · Sahipsin · Takılı"],
			[&"LabelWarning", "Warning 18 · Stok bitti"],
			[&"LabelDisabled", "Disabled 18 · Yakında"]]:
		list.add_child(UiKit.label(entry[1], entry[0]))
	return _page_root(column)


func _swatch(name: String, color: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(0, 46)
	chip.size_flags_horizontal = SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(UiTokens.RADIUS_SMALL)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.18)
	chip.add_theme_stylebox_override("panel", style)
	box.add_child(chip)
	box.add_child(UiKit.label("%s  #%s" % [name, color.to_html(false)], &"LabelCaptionOnDark"))
	return box


# --- 2. Paneller -------------------------------------------------------------

func _page_panels() -> Control:
	var column := _page("PanelsPage")
	_heading(column, "Paneller")
	_note(column, "Koyu dünya üstünde: PanelBase / PanelPurple / PanelDark. Krem içerik: PanelCard / PanelElevated / PanelListRow / PanelCream / PanelModal.")
	var row1 := _row()
	column.add_child(row1)
	row1.add_child(_panel_sample(UiKit.panel(&"PanelBase"), "PanelBase", &"LabelBodyOnDark"))
	row1.add_child(_panel_sample(UiKit.plate(&"PanelPurple"), "PanelPurple", &"LabelBodyOnDark"))
	row1.add_child(_panel_sample(UiKit.plate(&"PanelDark"), "PanelDark", &"LabelBodyOnDark"))
	var row2 := _row()
	column.add_child(row2)
	row2.add_child(_panel_sample(UiKit.panel(&"PanelCard"), "PanelCard", &"LabelBody"))
	row2.add_child(_panel_sample(UiKit.panel(&"PanelElevated"), "PanelElevated", &"LabelBody"))
	var list_row := _panel_sample(UiKit.panel(&"PanelListRow"), "PanelListRow", &"LabelBody")
	column.add_child(list_row)
	var cream := _panel_sample(UiKit.panel(&"PanelCream"), "PanelCream · içerik yüzeyi", &"LabelBody")
	cream.custom_minimum_size.y = 120.0
	column.add_child(cream)
	_gap(column, 30)
	var modal := UiKit.modal_frame("PanelModal", 560.0)
	modal.size_flags_horizontal = SIZE_SHRINK_CENTER
	var body: VBoxContainer = modal.get_meta(&"body")
	var text := UiKit.label("Kurdele üstten taşar, pembe daire kapat sağ üstte. Owner tepeliği bu iskeletin üstüne gelir.", &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(text)
	body.add_child(UiKit.button("Tamam", &"ButtonSecondary"))
	column.add_child(modal)
	return _page_root(column)


func _panel_sample(panel: PanelContainer, caption: String, variation: StringName) -> PanelContainer:
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 96.0
	var text := UiKit.label(caption, variation, HORIZONTAL_ALIGNMENT_CENTER)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(text)
	return panel


# --- 3. Butonlar -------------------------------------------------------------

func _page_buttons() -> Control:
	var column := _page("ButtonsPage")
	_heading(column, "Butonlar")
	_note(column, "Her satır: normal · basılı · pasif. Aynı gövde, dört yükseklik (44/58/72/88); bevel ve köşe gövdeyle ölçeklenir.")
	for entry in [[&"ButtonPrimary", "OYNA"], [&"ButtonSecondary", "Kapat"],
			[&"ButtonPurchase", "SATIN AL"], [&"ButtonDanger", "Sil"]]:
		column.add_child(_button_states(entry[0], entry[1]))
	_heading(column, "İkon butonları")
	var icons := _row(UiTokens.SPACE_LG)
	column.add_child(icons)
	for role in ["settings", "back", "sound_on"]:
		icons.add_child(UiKit.icon_button(role, &"ButtonIcon", 62.0))
	icons.add_child(_pressed(UiKit.icon_button("settings", &"ButtonIcon", 62.0)))
	icons.add_child(_disabled(UiKit.icon_button("settings", &"ButtonIcon", 62.0)))
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 8.0
	icons.add_child(spacer)
	icons.add_child(UiKit.icon_button("close", &"ButtonRoundIcon", 64.0))
	icons.add_child(_pressed(UiKit.icon_button("close", &"ButtonRoundIcon", 64.0)))
	icons.add_child(_disabled(UiKit.icon_button("close", &"ButtonRoundIcon", 64.0)))
	_heading(column, "Kahraman CTA")
	column.add_child(UiKit.cta("DEVAM ET", "Reklam izle", &"ButtonCTA", "movie"))
	column.add_child(UiKit.cta("OYNA"))
	column.add_child(_pressed(UiKit.cta("BASILI")))
	column.add_child(_disabled(UiKit.cta("Stok yok", "Reklam kotası doldu", &"ButtonCTA", "movie")))
	_heading(column, "İkonlu yazı butonu")
	var with_icons := _row()
	column.add_child(with_icons)
	var a := UiKit.button("Ödülü Al", &"ButtonPurchase", "gift")
	a.size_flags_horizontal = SIZE_EXPAND_FILL
	with_icons.add_child(a)
	var b := UiKit.button("Haritaya Git", &"ButtonPrimary", "map")
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	with_icons.add_child(b)
	return _page_root(column)


func _button_states(variation: StringName, text: String) -> Control:
	var row := _row()
	for i in 3:
		var button := UiKit.button(text, variation)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		if i == 1:
			_pressed(button)
		elif i == 2:
			_disabled(button)
		row.add_child(button)
	return row


func _pressed(button: Button) -> Button:
	button.toggle_mode = true
	button.button_pressed = true
	return button


func _disabled(button: Button) -> Button:
	button.disabled = true
	if button.has_meta(&"title_label"):
		var muted: Color = UiKit.theme().get_color("font_disabled_color", button.theme_type_variation)
		var title: Label = button.get_meta(&"title_label")
		title.add_theme_color_override("font_color", muted)
		for child in title.get_parent().get_children():
			if child != title:
				(child as Label).add_theme_color_override("font_color", Color(muted, 0.8))
		for child in title.get_parent().get_parent().get_children():
			if child is TextureRect:
				(child as TextureRect).self_modulate = muted
	return button


# --- 4. Bilesenler -----------------------------------------------------------

func _page_components() -> Control:
	var column := _page("ComponentsPage")
	_heading(column, "Kaynak pill'i")
	var pills := _row(UiTokens.SPACE_LG)
	column.add_child(pills)
	pills.add_child(UiKit.resource_pill(ART_DOUGH, "335", true))
	pills.add_child(UiKit.resource_pill(ART_DOUGH, "12 480"))
	pills.add_child(UiKit.resource_pill(ART_STAR, "1 240"))

	_heading(column, "Başlık kurdelesi · bölüm etiketi")
	var ribbons := _row()
	column.add_child(ribbons)
	for entry in [["Mağaza", UiTokens.PINK], ["Ayarlar", UiTokens.LAVENDER], ["Ödül!", UiTokens.GOLD]]:
		var ribbon := UiKit.header_ribbon(entry[0], entry[1])
		ribbon.size_flags_horizontal = SIZE_EXPAND_FILL
		ribbons.add_child(ribbon)
	var tags := _flow()
	column.add_child(tags)
	tags.add_child(UiKit.section_tag("GÜÇLER"))
	tags.add_child(UiKit.section_tag("SKİNLER", UiTokens.PINK))
	tags.add_child(UiKit.section_tag("GÜNLÜK", UiTokens.MINT))
	tags.add_child(UiKit.section_tag("PREMIUM", UiTokens.GOLD))

	_heading(column, "İlerleme · anahtar")
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	column.add_child(bars)
	for ratio in [0.25, 0.6, 1.0]:
		bars.add_child(UiKit.progress_bar(ratio))
	bars.add_child(UiKit.progress_bar(0.7, &"ProgressBarGold"))
	var switches := _row(UiTokens.SPACE_LG)
	column.add_child(switches)
	switches.add_child(UiKit.switch_toggle(true))
	switches.add_child(UiKit.switch_toggle(false))
	var off := UiKit.switch_toggle(true)
	off.disabled = true
	switches.add_child(off)
	switches.add_child(UiKit.label("Ses  ·  Titreşim  ·  pasif", &"LabelBodyOnDark"))

	_heading(column, "Rozetler")
	var badges := _flow(UiTokens.SPACE_MD)
	column.add_child(badges)
	badges.add_child(UiKit.badge("×4", &"Badge"))
	badges.add_child(UiKit.badge("4", &"Badge", ""))
	badges.add_child(UiKit.badge("Kilitli", &"LockBadge", "lock"))
	badges.add_child(UiKit.badge("TAKILI", &"EquippedBadge", "check"))
	badges.add_child(UiKit.badge("YENİ", &"NewBadge"))
	badges.add_child(UiKit.badge("12/20", &"CountBadge"))
	badges.add_child(UiKit.badge("", &"LockBadge", "lock"))

	_heading(column, "Rarity")
	var rarities := _flow(UiTokens.SPACE_MD)
	column.add_child(rarities)
	for rarity in [SkinData.Rarity.COMMON, SkinData.Rarity.RARE, SkinData.Rarity.EPIC, SkinData.Rarity.LEGENDARY]:
		rarities.add_child(UiKit.rarity_tag(rarity))
	var frames := _row(UiTokens.SPACE_LG)
	column.add_child(frames)
	frames.add_child(UiKit.rarity_frame(ART_SKIN_SADE, SkinData.Rarity.COMMON, 84))
	frames.add_child(UiKit.rarity_frame(ART_SKIN_RARE, SkinData.Rarity.RARE, 84))
	frames.add_child(UiKit.rarity_frame(ART_SKIN_EPIC, SkinData.Rarity.EPIC, 84))
	frames.add_child(UiKit.rarity_frame(ART_SKIN_LEGENDARY, SkinData.Rarity.LEGENDARY, 84))

	_heading(column, "Picto ikonlar · 24 / 32 / 48 / 72")
	var sizes := _row(UiTokens.SPACE_LG)
	sizes.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(sizes)
	for size in [UiTokens.ICON_SMALL, UiTokens.ICON_MEDIUM, UiTokens.ICON_LARGE, UiTokens.ICON_HERO]:
		var picto := UiKit.icon("settings", size)
		picto.size_flags_vertical = SIZE_SHRINK_CENTER
		sizes.add_child(picto)
	var all := _flow(UiTokens.SPACE_SM)
	column.add_child(all)
	for role in UiCoreAssets.ICONS.keys():
		var well := UiKit.panel(&"PanelBase")
		well.add_theme_stylebox_override("panel", UiKit.style("frame_round12", Color(UiTokens.NAVY_PURPLE, 0.9), Vector4(8, 8, 8, 8)))
		well.add_child(UiKit.icon(role, UiTokens.ICON_MEDIUM))
		all.add_child(well)
	return _page_root(column)


# --- 5. Moduller -------------------------------------------------------------

func _page_modules() -> Control:
	var column := _page("ModulesPage")
	_heading(column, "1 · Güç satırı")
	column.add_child(_module_power_row())
	_heading(column, "2 · Skin kartı")
	column.add_child(_module_skin_card())
	column.add_child(_module_owned_row())
	_heading(column, "4 · HUD plakası")
	column.add_child(_module_hud())
	_heading(column, "3 · Ödül bloğu")
	column.add_child(_module_reward())
	_heading(column, "5 · Pencere gövdesi")
	_gap(column, 24)
	column.add_child(_module_modal())
	return _page_root(column)


func _module_power_row() -> Control:
	var card := UiKit.panel(&"PanelCard")
	var row := _row(UiTokens.SPACE_LG)
	card.add_child(row)
	row.add_child(UiKit.icon_well(ART_BOMB, UiTokens.LAVENDER, 96, 72))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	info.size_flags_vertical = SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	info.add_child(UiKit.label("Bomba", &"LabelSection"))
	info.add_child(UiKit.price_row(ART_DOUGH, 120))
	info.add_child(UiKit.label("Stok ×4 · Tüketilir", &"LabelCaption"))
	var buy := UiKit.button("SATIN AL", &"ButtonPurchase")
	buy.size_flags_vertical = SIZE_SHRINK_CENTER
	buy.custom_minimum_size.x = 168.0
	row.add_child(buy)
	return card


func _module_skin_card() -> Control:
	var card := UiKit.panel(&"PanelCard")
	var row := _row(UiTokens.SPACE_LG)
	card.add_child(row)
	row.add_child(UiKit.rarity_frame(ART_SKIN_LEGENDARY, SkinData.Rarity.LEGENDARY, 104))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	info.size_flags_vertical = SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	row.add_child(info)
	info.add_child(UiKit.rarity_tag(SkinData.Rarity.LEGENDARY))
	info.add_child(UiKit.label("Altın Hamur", &"LabelSection"))
	info.add_child(UiKit.price_row(ART_DOUGH, 900))
	var buy := UiKit.button("SATIN AL", &"ButtonPrimary")
	buy.size_flags_vertical = SIZE_SHRINK_CENTER
	buy.custom_minimum_size.x = 168.0
	row.add_child(buy)
	return card


func _module_owned_row() -> Control:
	var card := UiKit.panel(&"PanelListRow")
	var row := _row(UiTokens.SPACE_MD)
	card.add_child(row)
	row.add_child(UiKit.art(ART_SKIN_SADE, 56))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	info.size_flags_vertical = SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	info.add_child(UiKit.label("Sade", &"LabelSection"))
	var owned := _row(UiTokens.SPACE_XS)
	info.add_child(owned)
	owned.add_child(UiKit.icon("check", 20, UiTokens.TEXT_POSITIVE))
	owned.add_child(UiKit.label("Sahipsin · Takılı", &"LabelPositive"))
	row.add_child(UiKit.badge("TAKILI", &"EquippedBadge"))
	return card


func _module_reward() -> Control:
	var block := UiKit.panel(&"PanelCream")
	var body := VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	block.add_child(body)
	var ribbon := UiKit.header_ribbon("Sandık Ödülü", UiTokens.GOLD)
	ribbon.size_flags_horizontal = SIZE_SHRINK_CENTER
	ribbon.custom_minimum_size.x = 340.0
	body.add_child(ribbon)
	var art_row := _row(UiTokens.SPACE_LG)
	art_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(art_row)
	art_row.add_child(UiKit.art(ART_CHEST, 132))
	var glow := Control.new()
	glow.custom_minimum_size = Vector2(150, 150)
	var focus := UiKit.patch("item_focus", UiTokens.GLOW_PREMIUM)
	glow.add_child(focus)
	var frame := UiKit.rarity_frame(ART_SKIN_RAINBOW, SkinData.Rarity.LEGENDARY, 100)
	frame.set_anchors_and_offsets_preset(PRESET_CENTER)
	frame.offset_left = -58.0
	frame.offset_right = 58.0
	frame.offset_top = -60.0
	frame.offset_bottom = 60.0
	glow.add_child(frame)
	art_row.add_child(glow)
	var tag := UiKit.rarity_tag(SkinData.Rarity.LEGENDARY)
	tag.size_flags_horizontal = SIZE_SHRINK_CENTER
	body.add_child(tag)
	body.add_child(UiKit.label("Gökkuşağı", &"LabelTitle", HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(UiKit.label("Koleksiyona eklendi · Legendary skin", &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER))
	var dough := _row(UiTokens.SPACE_XS)
	dough.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(dough)
	dough.add_child(UiKit.art(ART_DOUGH, 26))
	dough.add_child(UiKit.label("+50 Hamur", &"LabelPrice"))
	body.add_child(UiKit.cta("HARİKA!", "", &"ButtonCTA", "gift"))
	return block


func _module_hud() -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	var row1 := _row(UiTokens.SPACE_SM)
	wrap.add_child(row1)
	var score := UiKit.plate(&"PanelPurple")
	var score_row := _row(UiTokens.SPACE_SM)
	score.add_child(score_row)
	score_row.add_child(UiKit.art(ART_STAR, 40))
	var score_col := VBoxContainer.new()
	score_col.add_theme_constant_override("separation", -4)
	score_row.add_child(score_col)
	score_col.add_child(UiKit.label("SKOR", &"LabelCaptionOnDark"))
	score_col.add_child(UiKit.label("1 240", &"LabelStatOnDark"))
	row1.add_child(score)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	row1.add_child(spacer)
	row1.add_child(UiKit.resource_pill(ART_DOUGH, "335", true))
	row1.add_child(UiKit.icon_button("settings", &"ButtonIcon", 62.0))
	var row2 := _row(UiTokens.SPACE_SM)
	wrap.add_child(row2)
	var goal := UiKit.plate(&"PanelPurple")
	goal.size_flags_horizontal = SIZE_EXPAND_FILL
	row2.add_child(goal)
	var goal_row := _row(UiTokens.SPACE_MD)
	goal.add_child(goal_row)
	var level := UiKit.badge("4", &"Badge")
	var level_row: HBoxContainer = level.get_child(0)
	level_row.add_child(UiKit.art(ART_CROWN, 24))
	level_row.move_child(level_row.get_child(-1), 0)
	goal_row.add_child(level)
	var goal_col := VBoxContainer.new()
	goal_col.size_flags_horizontal = SIZE_EXPAND_FILL
	goal_col.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	goal_row.add_child(goal_col)
	var objective := _row(UiTokens.SPACE_XS + 2)
	goal_col.add_child(objective)
	objective.add_child(UiKit.art(ART_FLAG, 22))
	objective.add_child(UiKit.label("Hedef: Dev Dumpling", &"LabelStatOnDark"))
	goal_col.add_child(UiKit.progress_bar(0.6, &"ProgressBarMint", 22))
	var next := UiKit.panel(&"PanelElevated")
	var next_col := VBoxContainer.new()
	next_col.alignment = BoxContainer.ALIGNMENT_CENTER
	next_col.add_theme_constant_override("separation", 0)
	next.add_child(next_col)
	next_col.add_child(UiKit.label("Sıradaki", &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER))
	var tier := UiKit.art(ART_TIER2, 56)
	tier.size_flags_horizontal = SIZE_SHRINK_CENTER
	next_col.add_child(tier)
	row2.add_child(next)
	return wrap


func _module_modal() -> Control:
	var modal := UiKit.modal_frame("Devam etmek ister misin?", 600.0)
	modal.size_flags_horizontal = SIZE_SHRINK_CENTER
	var body: VBoxContainer = modal.get_meta(&"body")
	var art := UiKit.icon_well(ART_TIER6, UiTokens.LAVENDER, 200, 156)
	art.size_flags_horizontal = SIZE_SHRINK_CENTER
	body.add_child(art)
	var detail := UiKit.label("Taşan parçalar temizlenir, kaldığın yerden devam edersin.", &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(detail)
	var remaining := _row(UiTokens.SPACE_XS + 2)
	remaining.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(remaining)
	remaining.add_child(UiKit.label("Devam hakkı", &"LabelStat"))
	remaining.add_child(UiKit.art(ART_STAR, 26))
	remaining.add_child(UiKit.art(ART_STAR, 26))
	remaining.add_child(UiKit.label("2/2", &"LabelStat"))
	_gap(body, 4)
	body.add_child(UiKit.cta("DEVAM ET", "Reklam izle", &"ButtonCTA", "movie"))
	body.add_child(UiKit.button("Bitir", &"ButtonSecondary"))
	return modal


# --- Cekim modu --------------------------------------------------------------

func _capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	_nav.visible = false
	for size in SHOT_SIZES:
		DisplayServer.window_set_size(size)
		await get_tree().process_frame
		await get_tree().process_frame
		var actual: Vector2i = DisplayServer.window_get_size()
		for i in _pages.size():
			_show(i)
			var scroll := _pages[i] as ScrollContainer
			scroll.scroll_vertical = 0
			await _save_shot("gallery_%s_%dx%d.png" % [PAGE_NAMES[i], size.x, size.y], actual)
			# Sayfa ekrandan uzunsa sonunu da cek (kaydirma icerigin tamamina ulasiyor mu?).
			await get_tree().process_frame
			var overflow: int = int(scroll.get_v_scroll_bar().max_value - scroll.size.y)
			if overflow > 40:
				scroll.scroll_vertical = overflow
				await _save_shot("gallery_%s_%dx%d_end.png" % [PAGE_NAMES[i], size.x, size.y], actual)
	print("bitti -> ", _shot_dir)


func _save_shot(file_name: String, actual: Vector2i) -> void:
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(_shot_dir.path_join(file_name))
	print(file_name, " (pencere %dx%d) -> " % [actual.x, actual.y], "ok" if err == OK else "HATA %d" % err)
