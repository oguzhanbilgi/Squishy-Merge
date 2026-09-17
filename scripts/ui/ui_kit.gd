class_name UiKit
extends RefCounted
## Production UI bilesen fabrikasi (M8.6-01).
##
## Uc katman:
##   UiTokens        sayilar ve renkler
##   UiCoreAssets    LayerLab'dan turetilmis beyaz 9-slice govdeler + picto ikonlar
##   ui_theme.tres   token + govdeden uretilmis Theme variation'lari
##
## Bu dosya ucunu bir araya getirip EKRANLARIN kullandigi hazir parcalari
## verir: kaynak pill'i, baslik kurdelesi, bolum etiketi, rozetler, ilerleme
## cubugu, ikon/CTA butonlari, ikon kuyusu, bevel plaka. Ekran kodu bir
## StyleBox'i elle kurmaz; burada yoksa buraya eklenir.
##
## Kural: LayerLab govdesi YAPI, Squishy Merge sanati KIMLIK. Generic picto
## (geri/kapat/ayarlar/ses...) `icon()`; Hamur/guc/skin/tac/yildiz gibi
## oyun sanati her zaman owner asset'i (`art()` ile kutuya alinir).

const FONT_DISPLAY: FontFile = preload("res://assets/fonts/Baloo2-ExtraBold.ttf")
const FONT_TITLE: FontFile = preload("res://assets/fonts/Baloo2-Bold.ttf")
const FONT_NUM: FontFile = preload("res://assets/fonts/Nunito-Bold.ttf")
const FONT_BODY: FontFile = preload("res://assets/fonts/Nunito-SemiBold.ttf")

## Sinyal verilmemis content margin: "sprite'in kendi kenarlarini kullan".
const NO_MARGIN: Vector4 = Vector4(-1, -1, -1, -1)


# --- Asset erisimi -----------------------------------------------------------

## Proje temasi. Bilesenler agaca girmeden once kuruldugu icin Control'un
## kendi tema aramasi (agac gerektirir) yerine dogrudan buradan okunur.
static func theme() -> Theme:
	return ThemeDB.get_project_theme()


static func texture(name: String) -> Texture2D:
	assert(UiCoreAssets.SPRITES.has(name), "UiCoreAssets'te yok: " + name)
	return load(UiCoreAssets.ROOT + UiCoreAssets.SPRITES[name][0]) as Texture2D


static func icon_texture(role: String) -> Texture2D:
	assert(UiCoreAssets.ICONS.has(role), "Picto ikon yok: " + role)
	return load(UiCoreAssets.ROOT + UiCoreAssets.ICONS[role]) as Texture2D


## 9-slice StyleBox: `tint` beyaz govdeyi boyar. `content` (sol, ust, sag,
## alt) verilmezse texture margin'leri icerik kenari olur.
static func style(name: String, tint: Color = Color.WHITE,
		content: Vector4 = NO_MARGIN) -> StyleBoxTexture:
	var info: Array = UiCoreAssets.SPRITES[name]
	var box := StyleBoxTexture.new()
	box.texture = texture(name)
	box.texture_margin_left = float(info[3])
	box.texture_margin_top = float(info[4])
	box.texture_margin_right = float(info[5])
	box.texture_margin_bottom = float(info[6])
	box.modulate_color = tint
	if content.x >= 0.0:
		box.content_margin_left = content.x
		box.content_margin_top = content.y
		box.content_margin_right = content.z
		box.content_margin_bottom = content.w
	return box


## 9-slice NinePatchRect: paneli dolduran arka plan/isik katmani.
static func patch(name: String, tint: Color = Color.WHITE) -> NinePatchRect:
	var info: Array = UiCoreAssets.SPRITES[name]
	var rect := NinePatchRect.new()
	rect.texture = texture(name)
	rect.patch_margin_left = info[3]
	rect.patch_margin_top = info[4]
	rect.patch_margin_right = info[5]
	rect.patch_margin_bottom = info[6]
	rect.self_modulate = tint
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Herhangi bir dokuyu sabit kare kutuda, oranini koruyarak gosterir.
static func art(tex: Texture2D, box: float, tint: Color = Color.WHITE) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(box, box)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.self_modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Generic beyaz picto ikon (geri, kapat, ayarlar...). Rengi `tint` verir.
static func icon(role: String, box: float = UiTokens.ICON_MEDIUM,
		tint: Color = UiTokens.TEXT_ON_DARK) -> TextureRect:
	return art(icon_texture(role), box, tint)


# --- Metin -------------------------------------------------------------------

static func label(text: String, variation: StringName = &"LabelBody",
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := Label.new()
	node.text = text
	node.theme_type_variation = variation
	node.horizontal_alignment = align
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


# --- Butonlar ----------------------------------------------------------------

## Tek satirlik yazi butonu (ButtonPrimary / Secondary / Purchase / Danger).
## `icon_role` verilirse yazinin soluna beyaz picto girer.
static func button(text: String, variation: StringName = &"ButtonPrimary",
		icon_role: String = "") -> Button:
	var node := Button.new()
	node.text = text
	node.theme_type_variation = variation
	node.focus_mode = Control.FOCUS_NONE
	if icon_role != "":
		node.icon = icon_texture(icon_role)
		node.expand_icon = true
	UiMotion.attach_press(node)
	return node


## Kare/daire ikon butonu (ayarlar, geri, kapat). Ikon Button.icon olarak
## girer; rengi/boyutu variation'daki icon_* token'lari verir.
static func icon_button(role: String, variation: StringName = &"ButtonIcon",
		size: float = UiTokens.HEIGHT_NORMAL) -> Button:
	var node := Button.new()
	node.theme_type_variation = variation
	node.focus_mode = Control.FOCUS_NONE
	node.icon = icon_texture(role)
	node.expand_icon = true
	node.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.custom_minimum_size = Vector2(size, size)
	UiMotion.attach_press(node)
	return node


## Kahraman CTA: Baloo baslik + istege bagli Nunito alt satir + picto.
## Button.text bos; icerik cocuk container'da (iki satir gerekiyor).
static func cta(title: String, subtitle: String = "",
		variation: StringName = &"ButtonCTA", icon_role: String = "") -> Button:
	var node := Button.new()
	node.theme_type_variation = variation
	node.focus_mode = Control.FOCUS_NONE
	node.custom_minimum_size = Vector2(0, UiTokens.HEIGHT_HERO)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(row)
	# Icerik butonun content margin'ine gore konumlanir (alt bevel payi).
	var box: StyleBox = theme().get_stylebox("normal", variation)
	if box != null:
		row.offset_top = box.content_margin_top
		row.offset_bottom = -box.content_margin_bottom
	var text_color: Color = theme().get_color("font_color", variation)
	if icon_role != "":
		var picto := icon(icon_role, UiTokens.ICON_MEDIUM, text_color)
		picto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(picto)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", -6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_override("font", theme().get_font("font", variation))
	title_label.add_theme_font_size_override("font_size", theme().get_font_size("font_size", variation))
	title_label.add_theme_color_override("font_color", text_color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_label)
	node.set_meta(&"title_label", title_label)
	if subtitle != "":
		var sub := label(subtitle, &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
		sub.add_theme_color_override("font_color", Color(text_color, 0.8))
		column.add_child(sub)
	UiMotion.attach_press(node)
	return node


# --- Paneller ----------------------------------------------------------------

static func panel(variation: StringName = &"PanelCard") -> PanelContainer:
	var node := PanelContainer.new()
	node.theme_type_variation = variation
	return node


## Bevel plaka (PanelPurple / PanelDark): govde + ust isik katmani. Isik ayri
## NinePatch olarak govdenin ustunde, iceriklerin altinda durur.
static func plate(variation: StringName = &"PanelPurple") -> PanelContainer:
	var node := panel(variation)
	var light := patch("panel_bevel_light", Color(1, 1, 1, 0.14))
	light.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	light.offset_bottom = 32.0
	node.add_child(light)
	return node


## Pencere cercevesi: pembe parilti + krem govde (PanelModal) + ust kenardan
## tasan baslik kurdelesi + sag ustte pembe daire kapat. Icerik `body`
## VBox'una eklenir (meta "body"); kapat butonu meta "close_button".
## Owner'in kanatli-kalp tepeligi gibi kimlik parcalari bu iskeletin
## USTUNE ekran tarafinda eklenir; iskelet yapiyi verir, kimligi degil.
static func modal_frame(title: String, width: float = 600.0,
		glow: Color = UiTokens.GLOW_SUBTLE) -> Control:
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(width, 0)
	var glow_patch := patch("popup_glow", glow)
	glow_patch.offset_left = -70.0
	glow_patch.offset_top = -70.0
	glow_patch.offset_right = 70.0
	glow_patch.offset_bottom = 70.0
	frame.add_child(glow_patch)
	var body_panel := panel(&"PanelModal")
	body_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(body_panel)
	var light := patch("popup_light", Color(1, 1, 1, 0.5))
	light.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	light.offset_bottom = 33.0
	frame.add_child(light)
	var body := VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	body_panel.add_child(body)
	var ribbon := header_ribbon(title)
	ribbon.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	ribbon.offset_left = 24.0
	ribbon.offset_right = -24.0
	ribbon.offset_top = -34.0
	ribbon.offset_bottom = 46.0
	frame.add_child(ribbon)
	var close := icon_button("close", &"ButtonRoundIcon", 64.0)
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left = -40.0
	close.offset_right = 24.0
	close.offset_top = -26.0
	close.offset_bottom = 38.0
	frame.add_child(close)
	# Govde yuksekligi icerige gore: PanelContainer minimumunu cerceveye tasi.
	body_panel.minimum_size_changed.connect(func() -> void:
		frame.custom_minimum_size.y = body_panel.get_combined_minimum_size().y)
	frame.set_meta(&"body", body)
	frame.set_meta(&"close_button", close)
	frame.set_meta(&"ribbon", ribbon)
	return frame


## Ikon kuyusu: bevel daire (tint) + ic parlama + ortada oyun sanati.
static func icon_well(tex: Texture2D, tint: Color, size: float,
		art_size: float) -> Control:
	var well := Control.new()
	well.custom_minimum_size = Vector2(size, size * 1.07)
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(patch("item_circle", tint))
	var inner := patch("item_circle_inner", Color(1, 1, 1, 0.35))
	inner.offset_left = size * 0.07
	inner.offset_right = -size * 0.07
	inner.offset_top = size * 0.07
	inner.offset_bottom = -size * 0.14
	well.add_child(inner)
	var picture := art(tex, art_size)
	picture.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	picture.offset_left = -art_size * 0.5
	picture.offset_right = art_size * 0.5
	picture.offset_top = -art_size * 0.5 - size * 0.035
	picture.offset_bottom = art_size * 0.5 - size * 0.035
	well.add_child(picture)
	return well


## Rarity cerceveli onizleme (skin karti): item cercevesi rarity renginde.
static func rarity_frame(tex: Texture2D, rarity: int, art_size: float) -> PanelContainer:
	var frame := panel(_rarity_variation("RarityFrame", rarity))
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_child(art(tex, art_size))
	return frame


# --- Oyun bilesenleri --------------------------------------------------------

## Kaynak pill'i: koyu govde, oyun ikonu (Hamur), Nunito deger, istege bagli
## nane "+" (magaza kisayolu). Deger `set_pill_value` ile guncellenir.
static func resource_pill(icon_tex: Texture2D, value: String,
		with_add: bool = false) -> PanelContainer:
	var pill := panel(&"ResourcePill")
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	row.add_child(art(icon_tex, 40))
	var value_label := label(value, &"LabelStatOnDark")
	row.add_child(value_label)
	pill.set_meta(&"value_label", value_label)
	if with_add:
		var add := Button.new()
		add.theme_type_variation = &"ButtonResourceAdd"
		add.focus_mode = Control.FOCUS_NONE
		# Dokunma hedefi >= 48 (M8.6-03B): pill'in "+"si tek basina da vurulabilsin.
		add.custom_minimum_size = Vector2(48, 48)
		add.icon = texture("resource_add")
		add.expand_icon = true
		add.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiMotion.attach_press(add)
		row.add_child(add)
		pill.set_meta(&"add_button", add)
	return pill


## `pill`: resource_pill (PanelContainer) ya da home_pill sarmalayicisi —
## ikisi de meta "value_label" tasir.
static func set_pill_value(pill: Control, text: String, pop: bool = true) -> void:
	if pill == null or not pill.has_meta(&"value_label"):
		return
	var value_label: Label = pill.get_meta(&"value_label")
	if value_label.text == text:
		return
	value_label.text = text
	if pop:
		UiMotion.pop(pill)


## Baslik kurdelesi: ekran/pencere basligi. Kurdele varsayilan pembe;
## `tint` ile lavanta/altin (altin YALNIZ premium anlar).
static func header_ribbon(title: String, tint: Color = UiTokens.PINK) -> PanelContainer:
	var ribbon := panel(&"HeaderRibbon")
	if tint != UiTokens.PINK:
		var box: StyleBoxTexture = theme().get_stylebox("panel", &"HeaderRibbon").duplicate()
		box.modulate_color = tint
		ribbon.add_theme_stylebox_override("panel", box)
	var text := label(title, &"LabelTitleOnDark", HORIZONTAL_ALIGNMENT_CENTER)
	ribbon.add_child(text)
	ribbon.set_meta(&"title_label", text)
	return ribbon


## Bolum etiketi: "GÜÇLER", "SKİNLER". Trapez govde, koyu yazi.
static func section_tag(title: String, tint: Color = UiTokens.CYAN) -> PanelContainer:
	var tag := panel(&"SectionTag")
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if tint != UiTokens.CYAN:
		var box: StyleBoxTexture = theme().get_stylebox("panel", &"SectionTag").duplicate()
		box.modulate_color = tint
		tag.add_theme_stylebox_override("panel", box)
	tag.add_child(label(title, &"LabelSectionOnAccent"))
	return tag


## Rozet: Badge / LockBadge / EquippedBadge / NewBadge / CountBadge.
## `icon_role` verilirse yazinin soluna kucuk picto (kilit, tik).
static func badge(text: String, variation: StringName = &"Badge",
		icon_role: String = "") -> PanelContainer:
	var node := panel(variation)
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(row)
	var text_variation: StringName = &"LabelBadgeOnDark" \
		if variation in [&"LockBadge", &"NewBadge"] else &"LabelBadge"
	var text_color: Color = UiTokens.TEXT_ON_DARK \
		if text_variation == &"LabelBadgeOnDark" else UiTokens.TEXT_ON_ACCENT
	if icon_role != "":
		row.add_child(icon(icon_role, 18, text_color))
	if text != "":
		row.add_child(label(text, text_variation))
	return node


## Rarity etiketi ("EFSANEVİ"): trapez govde rarity renginde. Yazi oyuncu
## dili (M8.6-06 `SkinData.rarity_display_upper`); variation adi ic ad.
static func rarity_tag(rarity: int) -> PanelContainer:
	var tag := panel(_rarity_variation("Rarity", rarity))
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var text := label(SkinData.rarity_display_upper(rarity), &"LabelBadgeOnDark")
	tag.add_child(text)
	tag.set_meta(&"title_label", text)
	return tag


## Ilerleme cubugu (hedef, koleksiyon). `ProgressBarMint` / `ProgressBarGold`.
static func progress_bar(ratio: float, variation: StringName = &"ProgressBarMint",
		height: float = 24.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.theme_type_variation = variation
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf(ratio, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


## Anahtar (ayarlar): LayerLab beyaz ray + topuz, nane = acik.
static func switch_toggle(on: bool) -> UiToggle:
	var toggle := UiToggle.new()
	toggle.on_variation = &"SwitchOn"
	toggle.off_variation = &"SwitchOff"
	toggle.knob_texture = texture("switch_knob")
	toggle.set_on(on)
	return toggle


## Yazi + ince bosluk + ikon satiri (fiyat: Hamur ikonu + "120 Hamur").
static func price_row(icon_tex: Texture2D, price: int,
		variation: StringName = &"LabelPrice") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.SPACE_XS + 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art(icon_tex, UiTokens.ICON_SMALL + 2))
	row.add_child(label("%d Hamur" % price, variation))
	return row


static func _rarity_variation(prefix: String, rarity: int) -> StringName:
	return StringName(prefix + SkinData.rarity_name(rarity))


# --- Gameplay shell (M8.6-02) ------------------------------------------------

## Guc slotu (madalyon): `btn_circle` govde (PowerSlot krem / PowerSlotArmed
## cyan / PowerSlotEmpty pasif) + ic parlama + OWNER guc sanati (asla picto
## degil) + sag ustte stok rozeti + silahliyken arkada yumusak krem halka
## (neon degil). Durum `set_power_slot_state` ile guncellenir; buton stok
## 0'da da basilabilir (refill akisi), o zaman rozet nane "+" olur ve sanat
## rengini kaybetmeden solar.
static func power_slot(art_tex: Texture2D, count: int,
		size: Vector2 = Vector2(84.0, 88.0)) -> Button:
	var node := Button.new()
	node.theme_type_variation = &"PowerSlot"
	node.focus_mode = Control.FOCUS_NONE
	node.custom_minimum_size = size
	node.set_meta(&"power_slot", true)
	# Silahli halka: govdenin ARKASINDA (show_behind_parent), yumusak krem
	# daire, slot kenarindan 9 px tasar — neon cerceve degil, "kaldirilmis
	# madalyon" hissi.
	var glow := patch("popup_glow", Color(UiTokens.CYAN, 0.75))
	glow.show_behind_parent = true
	glow.offset_left = -22.0
	glow.offset_top = -22.0
	glow.offset_right = 22.0
	glow.offset_bottom = 14.0
	glow.visible = false
	node.add_child(glow)
	# Cerceve halkasi: govdenin arkasinda 3 px tasan koyu erik daire —
	# madalyon kenari zeminden ayrilir (candy coin). Silahli: cyan-derin,
	# stok 0: pasif koyu.
	# Kalin krem/altin halka: en diste krem (7 px), icinde altin (4 px).
	var outer_ring := patch("btn_circle_flat", UiTokens.CREAM)
	outer_ring.show_behind_parent = true
	outer_ring.offset_left = -7.0
	outer_ring.offset_top = -7.0
	outer_ring.offset_right = 7.0
	outer_ring.offset_bottom = -5.0
	node.add_child(outer_ring)
	var rim := patch("btn_circle_flat", UiTokens.GOLD)
	rim.show_behind_parent = true
	rim.offset_left = -4.0
	rim.offset_top = -4.0
	rim.offset_right = 4.0
	rim.offset_bottom = -8.0
	node.add_child(rim)
	node.set_meta(&"outer_ring", outer_ring)
	# Cam ic disk (hud_target: acik gok mavisi), sanatin arkasinda.
	var glass := patch("item_circle_inner", UiTokens.GLASS_BLUE)
	glass.offset_left = size.x * 0.11
	glass.offset_right = -size.x * 0.11
	glass.offset_top = size.y * 0.09
	glass.offset_bottom = -size.y * 0.21
	node.add_child(glass)
	# Ic parlama: ust yarida beyaz ic daire (candy gloss), altta hafif
	# golge dairesi (yumusak derinlik).
	var shade := patch("item_circle_inner", Color(0.35, 0.25, 0.5, 0.16))
	shade.offset_left = size.x * 0.10
	shade.offset_right = -size.x * 0.10
	shade.offset_top = size.y * 0.30
	shade.offset_bottom = -size.y * 0.10
	node.add_child(shade)
	var light := patch("item_circle_inner", Color(1, 1, 1, 0.42))
	light.offset_left = size.x * 0.14
	light.offset_right = -size.x * 0.14
	light.offset_top = size.y * 0.05
	light.offset_bottom = -size.y * 0.42
	node.add_child(light)
	var art_size: float = size.x * 0.72
	var picture := art(art_tex, art_size)
	picture.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	picture.offset_left = -art_size * 0.5
	picture.offset_right = art_size * 0.5
	# Alt bevel golgesi ~10 px: sanat gorsel merkeze (hafif yukari) oturur.
	picture.offset_top = -art_size * 0.5 - 6.0
	picture.offset_bottom = art_size * 0.5 - 6.0
	node.add_child(picture)
	# Stok rozeti: sag ust kose, altin; sola dogru buyur.
	var count_badge := panel(&"Badge")
	count_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_badge.custom_minimum_size = Vector2(34.0, 26.0)
	count_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	count_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count_badge.grow_vertical = Control.GROW_DIRECTION_END
	count_badge.offset_right = 6.0
	count_badge.offset_top = -6.0
	count_badge.offset_left = 6.0
	count_badge.offset_bottom = -6.0
	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.add_theme_constant_override("separation", 0)
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_badge.add_child(badge_row)
	var plus := icon("plus", 16, UiTokens.TEXT_ON_ACCENT)
	plus.visible = false
	badge_row.add_child(plus)
	var count_label := label("×%d" % count, &"LabelBadge")
	badge_row.add_child(count_label)
	node.add_child(count_badge)
	node.set_meta(&"glow", glow)
	node.set_meta(&"rim", rim)
	node.set_meta(&"glass", glass)
	node.set_meta(&"art", picture)
	node.set_meta(&"badge", count_badge)
	node.set_meta(&"badge_label", count_label)
	node.set_meta(&"badge_plus", plus)
	node.set_meta(&"count", count)
	UiMotion.attach_press(node)
	set_power_slot_state(node, count, false, true)
	return node


## Slot durumu: stok, silahli, etkin. Stok 0 -> pasif govde + soluk sanat +
## nane "+" rozeti (dokununca refill). Etkin degil -> `disabled` + %55.
static func set_power_slot_state(slot: Button, count: int, armed: bool,
		enabled: bool) -> void:
	if slot == null or not slot.has_meta(&"power_slot"):
		return
	var empty: bool = count <= 0
	slot.set_meta(&"count", count)
	slot.theme_type_variation = &"PowerSlotArmed" if armed 		else (&"PowerSlotEmpty" if empty else &"PowerSlot")
	slot.disabled = not enabled
	slot.modulate.a = 1.0 if enabled else 0.55
	(slot.get_meta(&"glow") as Control).visible = armed and enabled
	(slot.get_meta(&"rim") as Control).self_modulate = UiTokens.CYAN_DEEP if armed \
		else (UiTokens.LAVENDER if empty else UiTokens.GOLD)
	(slot.get_meta(&"outer_ring") as Control).self_modulate = Color(UiTokens.CYAN, 0.9) if armed \
		else (UiTokens.LAVENDER_SURFACE if empty else UiTokens.CREAM)
	(slot.get_meta(&"glass") as Control).self_modulate = UiTokens.CYAN if armed \
		else (UiTokens.GLASS_MUTED if empty else UiTokens.GLASS_BLUE)
	# Stok 0: sanat kimligini korur (renk kalir), yalnizca soluk ve hafif
	# gri-mavi ortu — tamamen gri generic buton olmaz.
	(slot.get_meta(&"art") as Control).self_modulate = \
		Color(0.86, 0.84, 0.94, 0.72) if empty else Color.WHITE
	var count_badge: PanelContainer = slot.get_meta(&"badge")
	var count_label: Label = slot.get_meta(&"badge_label")
	var plus: Control = slot.get_meta(&"badge_plus")
	count_label.text = "" if empty else "×%d" % count
	count_label.visible = not empty
	plus.visible = empty
	if empty:
		# Nane "+" rozeti sag ALT kosede (hud_target), stok rozeti sag ustte.
		count_badge.add_theme_stylebox_override("panel",
			style("badge_round", UiTokens.MINT, Vector4(9, 3, 9, 6)))
		count_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count_badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
		count_badge.offset_top = -4.0
		count_badge.offset_bottom = -4.0
	else:
		count_badge.remove_theme_stylebox_override("panel")
		count_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		count_badge.grow_vertical = Control.GROW_DIRECTION_END
		count_badge.offset_top = -6.0
		count_badge.offset_bottom = -6.0
	count_badge.offset_right = 6.0
	count_badge.offset_left = 6.0


## Slotun gosterdigi stok (testler icin; rozet metninden degil meta'dan).
static func power_slot_count(slot: Button) -> int:
	return int(slot.get_meta(&"count", 0)) if slot != null else 0


## Dekor katmani baglama (HUD v3). PanelContainer cocuklarini icerik
## dikdortgenine yerlestirir ve minimum boyuta katar; bu yuzden golge /
## halka / gloss gibi dis dekorlar plakanin ICINE degil, HUD'un ayri dekor
## kontrolune (`host`) eklenir ve plakanin dikdortgenini `item_rect_changed`
## ile izler. `margins` = (sol, ust, sag, alt) tasma; negatif = iceri.
static func hud_attach(target: Control, deco: Control, host: Control,
		margins: Vector4) -> Control:
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.set_anchors_preset(Control.PRESET_TOP_LEFT)
	host.add_child(deco)
	var sync := func() -> void:
		if not is_instance_valid(deco) or not is_instance_valid(target):
			return
		deco.global_position = target.global_position - Vector2(margins.x, margins.y)
		deco.size = target.size + Vector2(margins.x + margins.z, margins.y + margins.w)
		deco.visible = target.is_visible_in_tree()
	target.item_rect_changed.connect(sync)
	target.visibility_changed.connect(sync)
	if target.is_inside_tree():
		sync.call()
	else:
		target.tree_entered.connect(sync, CONNECT_ONE_SHOT)
	return deco


## Yumusak dis golge: plakanin arkasina `drop` px asagi kaymis koyu
## yuvarlak plaka. Buton (Control) icin dogrudan cocuk; PanelContainer
## icin `host` ver.
static func hud_shadow(target: Control, drop: float = 5.0, alpha: float = 0.30,
		host: Control = null, spread: float = 14.0) -> NinePatchRect:
	# popup_glow: yumusak kenarli radyal blob -> bulanik, dogal golge.
	# HUD v5: siyah degil erik (candy zeminle karisir), genis yayilim.
	var shadow := patch("popup_glow", Color(0.22, 0.09, 0.36, alpha))
	if host != null:
		hud_attach(target, shadow, host, Vector4(spread, spread - drop, spread, spread + drop))
		return shadow
	shadow.show_behind_parent = true
	shadow.offset_left = -spread
	shadow.offset_right = spread
	shadow.offset_top = -spread + drop
	shadow.offset_bottom = spread + drop
	target.add_child(shadow)
	return shadow


## Acik kenar halkasi: govdeden `width` px tasan yuvarlak plaka
## (hud_target: mor govdelerin acik dis kenari).
static func hud_rim(target: Control, tint: Color = UiTokens.LAVENDER_LIGHT,
		width: float = 3.0, host: Control = null, sprite: String = "frame_round20") -> NinePatchRect:
	# HUD v5: varsayilan halka `frame_round20` — duz beyaz yuvarlak plaka
	# (pismis cizgi yok), tint ile temiz acik lavanta kenar.
	var rim := patch(sprite, tint)
	if host != null:
		hud_attach(target, rim, host, Vector4(width, width, width, width))
		return rim
	rim.show_behind_parent = true
	rim.offset_left = -width
	rim.offset_top = -width
	rim.offset_right = width
	rim.offset_bottom = width
	target.add_child(rim)
	return rim


## Ust ic parlama seridi (gloss). `host` verilirse plakanin ustune, on
## dekor katmanina biner (yalniz ust `height` px). (`gloss_inset`: yan/ust
## pay — `UiKit.inset` fonksiyonuyla ad cakismasin.)
static func hud_gloss(target: Control, height: float, alpha: float = 0.34,
		gloss_inset: float = 5.0, host: Control = null) -> NinePatchRect:
	var light := patch("btn_bevel_light", Color(1, 1, 1, alpha))
	if host != null:
		var strip := Control.new()
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		light.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		light.offset_left = gloss_inset
		light.offset_right = -gloss_inset
		light.offset_top = gloss_inset * 0.6
		light.offset_bottom = height
		strip.add_child(light)
		hud_attach(target, strip, host, Vector4.ZERO)
		return light
	light.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	light.offset_left = gloss_inset
	light.offset_right = -gloss_inset
	light.offset_top = gloss_inset * 0.6
	light.offset_bottom = height
	target.add_child(light)
	return light


## Gameplay HUD kose butonu (v3): koyu lavanta-mor kare govde (ButtonHud /
## ButtonHudExit pembe), acik lavanta dis halka, ust gloss, dis golge,
## buyuk beyaz picto — hud_target'taki kalin candy kontrol.
static func hud_icon_button(role: String, size: float,
		variation: StringName = &"ButtonHud") -> Button:
	var node := icon_button(role, variation, size)
	hud_shadow(node, 4.0, 0.20)
	hud_rim(node, UiTokens.LAVENDER_LIGHT if variation == &"ButtonHud" else Color("fbd6e6"), 4.0)
	hud_gloss(node, size * 0.40, 0.40, 7.0)
	# Ic parlama: hafif acik ic kenar (toy buton).
	var inner := patch("border_round_thin", Color(1, 1, 1, 0.16))
	inner.offset_left = 3.0
	inner.offset_top = 3.0
	inner.offset_right = -3.0
	inner.offset_bottom = -10.0
	node.add_child(inner)
	return node


## Tepsi yuvasi: madalyonun oturdugu koyu-krem cukur (tepsi ile madalyon
## arasindaki `mid` dekor katmanina; madalyon dikdortgenini izler).
static func hud_socket(slot: Control, mid: Control) -> Control:
	var socket := patch("item_circle", Color(0.62, 0.52, 0.80, 0.55))
	hud_attach(slot, socket, mid, Vector4(9.0, 9.0, 9.0, 3.0))
	return socket


## Kalin koyu-lavanta cerceve + krem kart + dis golge + acik halka (hedef
## karti, Siradaki plakasi). Dekorlar `back`/`front` dekor katmanlarina
## baglanir. Icerik meta "card" PanelContainer'ina eklenir.
static func hud_card(back: Control, front: Control, with_stars: bool = false,
		inner: StringName = &"PanelHudCard") -> PanelContainer:
	var frame := panel(&"PanelHudFrame")
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_shadow(frame, 6.0, 0.26, back)
	hud_rim(frame, UiTokens.LAVENDER_LIGHT, 4.0, back)
	var card := panel(inner)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(card)
	hud_gloss(frame, 24.0, 0.34, 16.0, front)
	if with_stars:
		# Cerceve kenarlarinda altin yildiz aksani (sol/sag orta), on katman.
		var stars := Control.new()
		stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in [0.0, 1.0]:
			var star := art(preload("res://assets/visual/ui/icon_star_filled.png"), 26)
			star.anchor_left = side
			star.anchor_right = side
			star.anchor_top = 0.5
			star.anchor_bottom = 0.5
			star.offset_left = -13.0
			star.offset_right = 13.0
			star.offset_top = -13.0
			star.offset_bottom = 13.0
			stars.add_child(star)
		hud_attach(frame, stars, front, Vector4.ZERO)
	frame.set_meta(&"card", card)
	return frame


## HUD plakasi icin kucuk buyuk-harf baslik + deger sutunu (SKOR / 1 240).
static func hud_caption(text: String) -> Label:
	return label(text.to_upper(), &"LabelHudCaption", HORIZONTAL_ALIGNMENT_CENTER)


# --- Home hub (M8.6-03B) -----------------------------------------------------

## Cihazin ust guvenli alan payi (centik / punch-hole), tuval piksel
## cinsinden. Pencere yoksa (headless) ya da pay yoksa 0. GameBoard'daki
## `_detect_safe_top` ile ayni hesap — kabuk ekranlari (home) ust satiri bu
## kadar asagi iter.
static func safe_top(view: Vector2) -> float:
	var window: Vector2 = Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or window.y <= 0.0 or view.x <= 0.0:
		return 0.0
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var inset_px: float = maxf(0.0, float(safe.position.y))
	return inset_px * (view.x / window.x)


## Cihazin alt guvenli alan payi (gesture bar) — tuval piksel. Yalniz
## mobilde: masaustunde get_display_safe_area EKRANIN (gorev cubugu haric)
## dikdortgenini verir, pencereyle ilgisi yoktur (1280 px pencerede 240 px
## sahte pay cikiyordu).
static func safe_bottom(view: Vector2) -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var window: Vector2 = Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or window.y <= 0.0 or view.x <= 0.0:
		return 0.0
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var inset_px: float = maxf(0.0, window.y - float(safe.end.y))
	return inset_px * (view.x / window.x)


## Duz yuvarlak plaka (03B.1): `frame_round20` / `label_round` gibi PISMIS
## cizgisi ve golgesi olmayan beyaz plakalari istenen boyutta cizer. NinePatchRect
## DEGIL — patch kenarlari (51x50) kucuk plakadan buyuk olunca NinePatchRect
## kendini kucultemez; StyleBoxTexture'li bos PanelContainer her olcude cizer.
## Boyali alan = dikdortgen (dekor hizalamasi icin onemli).
static func flat_plate(sprite: String, tint: Color) -> PanelContainer:
	var node := PanelContainer.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", style(sprite, tint, Vector4.ZERO))
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	return node


## Plakayi `target`'in dikdortgenine gore (sol, ust, sag, alt) tasmayla yerlestirir.
static func _inset(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = left
	node.offset_top = top
	node.offset_right = -right
	node.offset_bottom = -bottom


## `_inset`'in bilesen dosyalarindan (ShopPowerCard / ShopSkinCard) kullanilan
## acik adi: negatif deger disari tasma.
static func inset(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	_inset(node, left, top, right, bottom)


## Home "oturmus" ikon butonu (03B.1): HUD v5 kose butonuyla ayni malzeme
## (koyu lavanta govde, acik lavanta halka, erik golge, ust gloss, beyaz
## picto) ama boyali sinirlari dikdortgene birebir oturan duz plakalardan:
##   erik golge (arkada, 5 px asagi) -> acik lavanta halka (+4) ->
##   koyu taban plakasi (butonun kendi stylebox'i; alt LIP px dudak olarak
##   gorunur) -> yuz plakasi (LAVENDER_DEEP, alt LIP px haric) -> gloss
##   (yuzun ust %44'u) -> ince ic isik -> beyaz picto (yuz merkezinde).
## Basinca yuz + gloss + ikon dudaga oturur (LIP-2 px) ve UiMotion 0.94 squash.
## HUD v5'in `hud_icon_button`'i DEGISMEDI (cihazda onayli); bu Home varyanti.
const HOME_ICON_LIP: float = 6.0

static func home_icon_button(role: String, size: float) -> Button:
	var node := Button.new()
	node.theme_type_variation = &"ButtonHomeIcon"
	node.focus_mode = Control.FOCUS_NONE
	node.custom_minimum_size = Vector2(size, size)
	hud_shadow(node, 5.0, 0.26, null, 14.0)
	var rim := flat_plate("frame_round20", UiTokens.LAVENDER_LIGHT)
	rim.show_behind_parent = true
	_inset(rim, -4.0, -4.0, -4.0, -4.0)
	node.add_child(rim)
	# Yuz: butonun uzerinde, alt dudak kadar kisa. Basista asagi kayar.
	var face := Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inset(face, 0.0, 0.0, 0.0, HOME_ICON_LIP)
	node.add_child(face)
	var body := flat_plate("frame_round20", UiTokens.LAVENDER_DEEP)
	face.add_child(body)
	# Gloss: HUD v5 ile ayni yumusak uclu isik seridi (btn_bevel_light).
	var gloss := patch("btn_bevel_light", Color(1, 1, 1, 0.38))
	gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_left = 6.0
	gloss.offset_right = -6.0
	gloss.offset_top = 3.0
	gloss.offset_bottom = size * 0.40
	face.add_child(gloss)
	var picto := icon(role, size * 0.60, UiTokens.TEXT_ON_DARK)
	picto.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	picto.offset_left = -size * 0.30
	picto.offset_right = size * 0.30
	picto.offset_top = -size * 0.30
	picto.offset_bottom = size * 0.30
	face.add_child(picto)
	node.set_meta(&"face", face)
	node.set_meta(&"icon", picto)
	node.button_down.connect(func() -> void:
		face.offset_top = HOME_ICON_LIP - 2.0
		face.offset_bottom = -2.0
		body.self_modulate = Color(0.9, 0.9, 0.9))
	var release := func() -> void:
		face.offset_top = 0.0
		face.offset_bottom = -HOME_ICON_LIP
		body.self_modulate = Color.WHITE
	node.button_up.connect(release)
	node.mouse_exited.connect(release)
	UiMotion.attach_press(node)
	return node


## Home ust satir kaynak pill'i (03B.1, HUD v5 dili — duz koyu cip DEGIL):
## erik golge -> acik lavanta halka (+3) -> koyu lavanta `label_round` pill
## (PanelHomePill) -> ust gloss; icinde owner ikonu 40 + beyaz Nunito deger +
## istege bagli nane yuvarlak "+" (48, ButtonHomeAdd: koyu nane taban + gloss +
## beyaz picto). Deger `set_pill_value` ile (meta "value_label"). Donen dugum
## bir sarmalayici Control: boyutu pill icerigine gore (meta "pill").
static func home_pill(icon_tex: Texture2D, value: String,
		with_add: bool = false, min_height: float = 56.0) -> Control:
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow := patch("popup_glow", Color(0.22, 0.09, 0.36, 0.26))
	_inset(shadow, -14.0, -9.0, -14.0, -19.0)
	wrap.add_child(shadow)
	var rim := flat_plate("label_round", UiTokens.LAVENDER_LIGHT)
	_inset(rim, -3.0, -3.0, -3.0, -3.0)
	wrap.add_child(rim)
	var pill := panel(&"PanelHomePill")
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	var picture := art(icon_tex, 40)
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(picture)
	var value_label := label(value, &"LabelStatOnDark")
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value_label)
	if with_add:
		var add := Button.new()
		add.theme_type_variation = &"ButtonHomeAdd"
		add.focus_mode = Control.FOCUS_NONE
		add.custom_minimum_size = Vector2(48, 48)
		add.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Koyu nane taban (3 px asagi tasar: dudak) + ust gloss + beyaz "+".
		var base := patch("btn_circle_flat", UiTokens.MINT_DEEP)
		base.show_behind_parent = true
		_inset(base, 0.0, 3.0, 0.0, -3.0)
		add.add_child(base)
		var add_gloss := patch("item_circle_inner", Color(1, 1, 1, 0.34))
		_inset(add_gloss, 7.0, 4.0, 7.0, 24.0)
		add.add_child(add_gloss)
		var plus := icon("plus", 28, UiTokens.TEXT_ON_DARK)
		plus.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		plus.offset_left = -14.0
		plus.offset_right = 14.0
		plus.offset_top = -14.0 - 1.0
		plus.offset_bottom = 14.0 - 1.0
		add.add_child(plus)
		UiMotion.attach_press(add)
		row.add_child(add)
		wrap.set_meta(&"add_button", add)
	else:
		# Tek basina pill: sag pay simetrik.
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(4, 0)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spacer)
	var gloss := patch("btn_bevel_light", Color(1, 1, 1, 0.30))
	gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_left = 8.0
	gloss.offset_right = -8.0
	gloss.offset_top = 3.0
	gloss.offset_bottom = min_height * 0.40
	wrap.add_child(gloss)
	wrap.set_meta(&"value_label", value_label)
	wrap.set_meta(&"pill", pill)
	var sync := func() -> void:
		var min: Vector2 = pill.get_combined_minimum_size()
		wrap.custom_minimum_size = Vector2(min.x, maxf(min.y, min_height))
		wrap.size = wrap.custom_minimum_size
	pill.minimum_size_changed.connect(sync)
	wrap.ready.connect(func() -> void: sync.call_deferred())
	sync.call()
	return wrap


## Kahraman OYNA (home): `cta` + cyan hale + erik golge + acik halka + kalin
## gloss + ince ic kenar + iki ucta owner yildizi. Basis `cta` icinde; bosta
## nefes ekranin kendi wrapper'inda (buton scale'i basisa kalir).
static func hero_cta(title: String, subtitle: String = "") -> Button:
	var node := cta(title, subtitle)
	(node.get_meta(&"title_label") as Label).add_theme_font_size_override("font_size", 40)
	var halo := patch("popup_glow", Color(UiTokens.CYAN, 0.42))
	halo.show_behind_parent = true
	halo.offset_left = -34.0
	halo.offset_right = 34.0
	halo.offset_top = -26.0
	halo.offset_bottom = 34.0
	node.add_child(halo)
	node.set_meta(&"halo", halo)
	hud_shadow(node, 8.0, 0.34, null, 18.0)
	# btn_cta'nin son 4 satiri pismis golge (boyali govde 84/88): halka altta
	# govdeye oturur, ustte/yanlarda 4 px gorunur (03B.1 kayit duzeltmesi).
	var rim := hud_rim(node, Color("f4f0ff"), 4.0)
	rim.offset_bottom = 0.0
	hud_gloss(node, 36.0, 0.42, 10.0)
	var inner := patch("border_round_thin", Color(1, 1, 1, 0.22))
	inner.offset_left = 4.0
	inner.offset_top = 4.0
	inner.offset_right = -4.0
	inner.offset_bottom = -12.0
	node.add_child(inner)
	var star_tex: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
	for side in [0.0, 1.0]:
		var star := art(star_tex, 34)
		star.anchor_left = side
		star.anchor_right = side
		star.anchor_top = 0.5
		star.anchor_bottom = 0.5
		star.offset_left = -17.0 + (6.0 if side == 0.0 else -6.0)
		star.offset_right = 17.0 + (6.0 if side == 0.0 else -6.0)
		star.offset_top = -17.0 - 2.0
		star.offset_bottom = 17.0 - 2.0
		node.add_child(star)
	# Yazi satiri en uste: gloss/ic kenar yaziyi soldurmasin.
	var row: Control = (node.get_meta(&"title_label") as Label).get_parent().get_parent()
	node.move_child(row, node.get_child_count() - 1)
	return node


# --- Magaza (M8.6-05) --------------------------------------------------------

## Candy yazi butonu (magaza SATIN AL): `btn_normal` govdesi (ButtonPrimary
## cyan / ButtonBuyLocked lavanta-gri) + erik golge + acik pill halkasi + ust
## gloss. Yazi cocuk Label olarak EN USTTE: Button kendi yazisini cocuklardan
## once cizer, gloss onu soldururdu (hero_cta ile ayni cozum). Basinca yazi
## 3 px dudaga iner (temanin pressed content margin'i cocuklara islemez) ve
## UiMotion squash. Variation `set_candy_button_variation` ile degisir.
static func candy_button(text: String, variation: StringName = &"ButtonPrimary",
		height: float = 58.0) -> Button:
	var node := Button.new()
	node.theme_type_variation = variation
	node.focus_mode = Control.FOCUS_NONE
	# btn_normal 58 px sabit govde; daha yuksek istenirse orta satir gerilir
	# (duz pill, gloss/halka ayri) — magaza SATIN AL 64 (rahat dokunma).
	node.custom_minimum_size = Vector2(0, maxf(height, 58.0))
	hud_shadow(node, 4.0, 0.22, null, 12.0)
	# Halka: pill (title_oval) — frame_round20'nin koseleri yuvarlak uclardan
	# disari tasardi. btn_normal'in son 5 satiri pismis golge: halka altta
	# govdeye oturur (+3 - 5 = -2).
	var rim := flat_plate("title_oval", UiTokens.LAVENDER_LIGHT)
	rim.show_behind_parent = true
	_inset(rim, -3.0, -3.0, -3.0, 2.0)
	node.add_child(rim)
	var gloss := patch("btn_bevel_light", Color(1, 1, 1, 0.34))
	gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_left = 10.0
	gloss.offset_right = -10.0
	gloss.offset_top = 3.0
	gloss.offset_bottom = 24.0
	node.add_child(gloss)
	var title_label := Label.new()
	title_label.text = text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.add_child(title_label)
	node.set_meta(&"title_label", title_label)
	node.set_meta(&"rim", rim)
	node.set_meta(&"gloss", gloss)
	set_candy_button_variation(node, variation)
	node.button_down.connect(func() -> void:
		title_label.offset_top = 3.0
		title_label.offset_bottom = 3.0 - 5.0)
	var release := func() -> void:
		title_label.offset_top = 0.0
		title_label.offset_bottom = -5.0
	release.call()
	node.button_up.connect(release)
	node.mouse_exited.connect(release)
	node.set_meta(&"release", release)
	UiMotion.attach_press(node)
	return node


## Kaydirilabilir icerikteki candy buton (Magaza SATIN AL, M8.6-06.3): Button'in
## varsayilani MOUSE_FILTER_STOP — Viewport basis olayini butonda durdurur,
## ScrollContainer basisi hic gormez ve parmak butonun ustundeyken kaydirma
## baslamaz (A36'da olculdu: 0 px). PASS ile olay ust ScrollContainer'a da
## ulasir (Koleksiyon karti ile ayni desen); dokunus yine tek `pressed`
## uretir (BaseButton, kaydirma basladiginda NOTIFICATION_SCROLL_BEGIN ile
## basisi iptal eder — birakista `pressed` YAYILMAZ). Basis gorseli icin
## release_candy_button'i kart NOTIFICATION_SCROLL_BEGIN'de cagirir.
static func make_candy_button_scrollable(button: Button) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_PASS


## Candy butonun basis gorselini disaridan birakir (yazi dudagi + 0.94 olcek):
## kaydirma basladiginda BaseButton basisi iptal eder ama button_up yaymaz.
static func release_candy_button(button: Button) -> void:
	(button.get_meta(&"release") as Callable).call()
	UiMotion.release(button)


## Candy butonun govde/yazi rolunu degistirir (SATIN AL: cyan <-> Hamur
## yetmiyor lavanta-gri). Yazi rengi/fontu temadaki variation'dan.
static func set_candy_button_variation(button: Button, variation: StringName) -> void:
	button.theme_type_variation = variation
	var title_label: Label = button.get_meta(&"title_label")
	title_label.add_theme_font_override("font", theme().get_font("font", variation))
	title_label.add_theme_font_size_override("font_size", theme().get_font_size("font_size", variation))
	title_label.add_theme_color_override("font_color", theme().get_color("font_color", variation))
	var gloss: Control = button.get_meta(&"gloss")
	gloss.self_modulate = Color(1, 1, 1, 0.34 if variation == &"ButtonPrimary" else 0.22)


## Kuyu oturaginin koyulastirma orani (candy_well / set_candy_well_accent).
const WELL_SEAT_DARKEN: float = 0.46
const WELL_GLOW_ALPHA: float = 0.30

## Candy kuyu (magaza guc karti / onay penceresi): owner sanatini tasiyan
## yuvarlak premium sunum — erik temas golgesi -> koyu alt oturak (gucun
## vurgu renginin koyusu, 6 px asagi tasar) -> acik lavanta halka -> renkli
## ic yuzey -> alt golge + ust gloss -> owner sanati. Gameplay madalyonu / Home kuyusuyla ayni aile.
## `size` govde capi; kontrolun dikdortgeni `size x (size + 6)`.
static func candy_well(art_tex: Texture2D, accent: Color, size: float,
		art_size: float) -> Control:
	var well := Control.new()
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.custom_minimum_size = Vector2(size, size + 6.0)
	# Vurgu halesi: kuyunun arkasinda genis, dusuk alfa renk (urun sanati
	# kartin odak noktasi; kart tek duz krem slab okunmasin).
	var glow := patch("popup_glow", Color(accent, WELL_GLOW_ALPHA))
	_inset(glow, -size * 0.34, -size * 0.30, -size * 0.34, -size * 0.36)
	well.add_child(glow)
	# Erik temas golgesi: kuyu karta OTURUR (harita dugumuyle ayni dil).
	var shadow := patch("popup_glow", Color(0.22, 0.09, 0.36, 0.22))
	_inset(shadow, -size * 0.18, -size * 0.06, -size * 0.18, -size * 0.22)
	well.add_child(shadow)
	var seat := patch("btn_circle_flat", accent.darkened(WELL_SEAT_DARKEN))
	_inset(seat, -6.0, 6.0, -6.0, -1.0)
	well.add_child(seat)
	# Halka acik lavanta: kuyu krem kartin ustunde oturur, krem halka kremde
	# kaybolurdu (kart halkasiyla ayni ton).
	var rim := patch("btn_circle_flat", UiTokens.LAVENDER_LIGHT)
	_inset(rim, -6.0, -6.0, -6.0, 6.0 + 2.0)
	well.add_child(rim)
	var body := patch("btn_circle_flat", accent)
	_inset(body, 0.0, 0.0, 0.0, 6.0)
	well.add_child(body)
	var shade := patch("item_circle_inner", Color(0.35, 0.25, 0.5, 0.18))
	_inset(shade, size * 0.10, size * 0.32, size * 0.10, 6.0 + size * 0.06)
	well.add_child(shade)
	var light := patch("item_circle_inner", Color(1, 1, 1, 0.42))
	_inset(light, size * 0.14, size * 0.06, size * 0.14, 6.0 + size * 0.44)
	well.add_child(light)
	var picture := art(art_tex, art_size)
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	picture.offset_left = -art_size * 0.5
	picture.offset_right = art_size * 0.5
	picture.offset_top = -art_size * 0.5 - 3.0
	picture.offset_bottom = art_size * 0.5 - 3.0
	well.add_child(picture)
	well.set_meta(&"art", picture)
	well.set_meta(&"body", body)
	well.set_meta(&"seat", seat)
	well.set_meta(&"glow", glow)
	return well


## Kuyunun vurgu rengini degistirir: hale + oturak + yuzey birlikte
## (`setup()` sonradan cagirdiginda uc katman da yeni renge gecer).
static func set_candy_well_accent(well: Control, accent: Color) -> void:
	(well.get_meta(&"body") as CanvasItem).self_modulate = accent
	(well.get_meta(&"seat") as CanvasItem).self_modulate = accent.darkened(WELL_SEAT_DARKEN)
	(well.get_meta(&"glow") as CanvasItem).self_modulate = Color(accent, WELL_GLOW_ALPHA)


## Bolum basligi (magaza GUCLER / SKINLER): iki yanda ince acik lavanta
## cizgi, ortada koyu lavanta `title_oval` plakasi (PanelShopSection) + acik
## halka + erik golge + gloss + beyaz Baloo baslik. MAGAZA kurdelesinin
## altinda ikincil: 44 px plaka, dikey alan yemez. 05.1 candy puff: plakanin
## altinda SECTION_LIP px koyu lavanta dudak (home_icon_button dili — plaka
## kabarik, yapistirilmis degil), acik halka dudagi da sarar, gloss biraz
## daha belirgin + sol ustte kucuk beyaz parlama noktasi. Buyuk harf
## CAGIRANDAN gelir (Godot to_upper Turkce I'yi bilmez). Meta: "title_label",
## "plate", "lip".
const SECTION_LIP: float = 4.0

static func section_header(title: String, tint: Color = UiTokens.LAVENDER_DEEP) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	# 44 px plaka + dudak payi: dudak ve halka satirin altina tasmaz.
	row.custom_minimum_size = Vector2(0, 44.0 + SECTION_LIP)
	for side in 2:
		var line := flat_plate("badge_round", Color(UiTokens.LAVENDER_LIGHT, 0.78))
		line.set_anchors_preset(Control.PRESET_TOP_LEFT)
		line.custom_minimum_size = Vector2(24.0, 4.0)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(line)
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Plaka sarmalayicinin ust 44 px'i; dudak altta SECTION_LIP px.
	var shadow := patch("popup_glow", Color(0.22, 0.09, 0.36, 0.26))
	_inset(shadow, -12.0, -8.0, -12.0, -18.0)
	wrap.add_child(shadow)
	var rim := flat_plate("title_oval", UiTokens.LAVENDER_LIGHT)
	_inset(rim, -3.0, -3.0, -3.0, -3.0)
	wrap.add_child(rim)
	# Dudak: plakanin koyusu, plakanin altindan SECTION_LIP px gorunur.
	var lip := flat_plate("title_oval", tint.darkened(0.32))
	_inset(lip, 0.0, SECTION_LIP, 0.0, 0.0)
	wrap.add_child(lip)
	var plate := panel(&"PanelShopSection")
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inset(plate, 0.0, 0.0, 0.0, SECTION_LIP)
	if tint != UiTokens.LAVENDER_DEEP:
		plate.add_theme_stylebox_override("panel",
			style("title_oval", tint, Vector4(22, 2, 22, 8)))
	wrap.add_child(plate)
	var text := label(title, &"LabelSectionOnDark", HORIZONTAL_ALIGNMENT_CENTER)
	text.add_theme_font_size_override("font_size", 22)
	plate.add_child(text)
	var gloss := patch("btn_bevel_light", Color(1, 1, 1, 0.38))
	gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_left = 8.0
	gloss.offset_right = -8.0
	gloss.offset_top = 2.0
	gloss.offset_bottom = 18.0
	wrap.add_child(gloss)
	# Kucuk parlama noktasi (sol ust): candy plastigin tek noktasal isigi.
	var spot := TextureRect.new()
	spot.texture = texture("item_circle_inner")
	spot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spot.stretch_mode = TextureRect.STRETCH_SCALE
	spot.self_modulate = Color(1, 1, 1, 0.55)
	spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spot.set_anchors_preset(Control.PRESET_TOP_LEFT)
	spot.offset_left = 16.0
	spot.offset_top = 6.0
	spot.offset_right = 16.0 + 14.0
	spot.offset_bottom = 6.0 + 7.0
	wrap.add_child(spot)
	var sync := func() -> void:
		var min: Vector2 = plate.get_combined_minimum_size()
		wrap.custom_minimum_size = Vector2(maxf(min.x, 180.0), maxf(min.y, 44.0) + SECTION_LIP)
	plate.minimum_size_changed.connect(sync)
	sync.call()
	row.add_child(wrap)
	# Plaka ikinci cocuk: sol cizgi, plaka, sag cizgi.
	row.move_child(wrap, 1)
	row.set_meta(&"title_label", text)
	row.set_meta(&"plate", plate)
	row.set_meta(&"lip", lip)
	return row


## Magaza kart yuzu (05.1): buyuk krem yuzeyin duz okunmamasi icin govdenin
## ICINE (icerik sutununun altina) giren dekor katmani — `body`
## PanelContainer'inin ilk cocugu olur, PanelContainer onu icerik
## dikdortgenine oturtur; icindeki `Clip` kontrolu disari tasarak govde
## dikdortgenini alir (icerik payi 16/14/16/20 geri acilir) ve
## `clip_contents` ile katmanlari govdenin icinde tutar:
##   yumusak beyaz radyal isik (`popup_glow`, kartin ust-ortasinda: urun
##   sanatinin arkasi hafif aydinlik, alt yari sakin krem — sert kenar yok,
##   kose disina sizmaz) → ust gloss bandi (`popup_light`: kavisli sise
##   parlamasi, govde ust kenarini takip eder). Hepsi beyaz alfa: govde tonu
##   (krem / TRAY_CREAM / CREAM_DEEP / altin-krem) korunur. Golge/halka/
##   kontur kartin kendi dekoru; bu yalniz yuz. Meta: "sheen", "gloss".
const CARD_SHEEN_ALPHA: float = 0.34
const CARD_GLOSS_ALPHA: float = 0.58

static func card_face(body: PanelContainer, body_margin: Vector4 = Vector4(16, 14, 16, 20)) -> Control:
	var host := Control.new()
	host.name = "Face"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var clip := Control.new()
	clip.name = "Clip"
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.clip_contents = true
	_inset(clip, -body_margin.x, -body_margin.y, -body_margin.z, -body_margin.w)
	host.add_child(clip)
	# Radyal isik (328x384 magaza kartina gore ayarli px): merkez govde
	# ust-ortasinda (y 90 ≈ %23 — urun sanatinin arkasi), genislik govde +
	# 2x24 (kenarda alfa ~%2), yukseklik 312 (~%80). Clip disariya sizdirmaz.
	var sheen := patch("popup_glow", Color(1, 1, 1, CARD_SHEEN_ALPHA))
	sheen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	sheen.anchor_right = 1.0
	sheen.anchor_bottom = 0.0
	sheen.offset_left = -24.0
	sheen.offset_right = 24.0
	sheen.offset_top = -66.0
	sheen.offset_bottom = 246.0
	clip.add_child(sheen)
	var gloss := patch("popup_light", Color(1, 1, 1, CARD_GLOSS_ALPHA))
	gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_left = 7.0
	gloss.offset_right = -7.0
	gloss.offset_top = 5.0
	gloss.offset_bottom = 5.0 + 28.0
	clip.add_child(gloss)
	body.add_child(host)
	body.move_child(host, 0)
	host.set_meta(&"sheen", sheen)
	host.set_meta(&"gloss", gloss)
	return host


## Onay penceresinin kapat butonunu oturtur (05.1): `modal_frame` kurdelesi
## varsayilan olarak govde kenarina 24 px kalir ve sag kuyruk kapat
## dairesinin altina girer. Kurdele `ribbon_margin` px iceri cekilir (kuyruk
## kapatin solunda biter), kapatin arkasina krem halka (+ring px) ve erik
## temas golgesi gelir: X govdenin kosesine oturmus candy buton okunur.
## PAYLASILAN modal_frame recetesi DEGISMEZ (Mola / Bonus Sandik ayni).
static func seat_modal_close(frame: Control, ribbon_margin: float = 60.0,
		ring: float = 4.0) -> void:
	var ribbon: Control = frame.get_meta(&"ribbon")
	ribbon.offset_left = ribbon_margin
	ribbon.offset_right = -ribbon_margin
	var close: Button = frame.get_meta(&"close_button")
	var shadow := patch("popup_glow", Color(0.22, 0.09, 0.36, 0.30))
	shadow.show_behind_parent = true
	_inset(shadow, -10.0, -4.0, -10.0, -16.0)
	close.add_child(shadow)
	var halo := flat_plate("btn_circle_flat", UiTokens.CREAM)
	halo.show_behind_parent = true
	# btn_circle'in son ~8 satiri pismis golge: halka govde dairesine oturur.
	_inset(halo, -ring, -ring, -ring, 8.0 - ring)
	close.add_child(halo)
	close.set_meta(&"seat_ring", halo)
