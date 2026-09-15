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
		add.custom_minimum_size = Vector2(40, 42)
		add.icon = texture("resource_add")
		add.expand_icon = true
		add.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiMotion.attach_press(add)
		row.add_child(add)
		pill.set_meta(&"add_button", add)
	return pill


static func set_pill_value(pill: PanelContainer, text: String, pop: bool = true) -> void:
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


## Rarity etiketi ("LEGENDARY"): trapez govde rarity renginde.
static func rarity_tag(rarity: int) -> PanelContainer:
	var tag := panel(_rarity_variation("Rarity", rarity))
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tag.add_child(label(SkinData.rarity_name(rarity).to_upper(), &"LabelBadgeOnDark"))
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
	var glow := patch("btn_circle_flat", Color(UiTokens.CREAM, 0.55))
	glow.show_behind_parent = true
	glow.offset_left = -10.0
	glow.offset_top = -10.0
	glow.offset_right = 10.0
	glow.offset_bottom = -2.0
	glow.visible = false
	node.add_child(glow)
	# Cerceve halkasi: govdenin arkasinda 3 px tasan koyu erik daire —
	# madalyon kenari zeminden ayrilir (candy coin). Silahli: cyan-derin,
	# stok 0: pasif koyu.
	var rim := patch("btn_circle_flat", UiTokens.NAVY_PURPLE)
	rim.show_behind_parent = true
	rim.offset_left = -3.0
	rim.offset_top = -3.0
	rim.offset_right = 3.0
	rim.offset_bottom = -9.0
	node.add_child(rim)
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
		else (UiTokens.DISABLED_DEEP if empty else UiTokens.NAVY_PURPLE)
	# Stok 0: sanat kimligini korur (renk kalir), yalnizca soluk ve hafif
	# gri-mavi ortu — tamamen gri generic buton olmaz.
	(slot.get_meta(&"art") as Control).self_modulate = \
		Color(0.82, 0.80, 0.90, 0.66) if empty else Color.WHITE
	var count_badge: PanelContainer = slot.get_meta(&"badge")
	var count_label: Label = slot.get_meta(&"badge_label")
	var plus: Control = slot.get_meta(&"badge_plus")
	count_label.text = "" if empty else "×%d" % count
	count_label.visible = not empty
	plus.visible = empty
	if empty:
		count_badge.add_theme_stylebox_override("panel",
			style("badge_round", UiTokens.MINT, Vector4(9, 3, 9, 6)))
	else:
		count_badge.remove_theme_stylebox_override("panel")


## Slotun gosterdigi stok (testler icin; rozet metninden degil meta'dan).
static func power_slot_count(slot: Button) -> int:
	return int(slot.get_meta(&"count", 0)) if slot != null else 0


## Gameplay HUD kose butonu: ButtonIcon + ust gloss (candy) + arkada 3 px
## koyu erik halka — kalin, basilabilir, madalyonlarla ayni aile.
static func hud_icon_button(role: String, size: float) -> Button:
	var node := icon_button(role, &"ButtonIcon", size)
	var rim := patch("frame_round20", UiTokens.NAVY_PURPLE)
	rim.show_behind_parent = true
	rim.offset_left = -3.0
	rim.offset_top = -3.0
	rim.offset_right = 3.0
	rim.offset_bottom = -6.0
	node.add_child(rim)
	var light := patch("btn_bevel_light", Color(1, 1, 1, 0.40))
	light.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	light.offset_left = 4.0
	light.offset_right = -4.0
	light.offset_top = 3.0
	light.offset_bottom = size * 0.45
	node.add_child(light)
	return node


## Lavanta cerceve + krem kart (hedef karti, Siradaki plakasi). Icerik
## meta "card" PanelContainer'ina eklenir.
static func hud_card() -> PanelContainer:
	var frame := panel(&"PanelHudFrame")
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var light := patch("panel_bevel_light", Color(1, 1, 1, 0.30))
	light.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	light.offset_bottom = 22.0
	frame.add_child(light)
	var card := panel(&"PanelHudCard")
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(card)
	frame.set_meta(&"card", card)
	return frame


## HUD plakasi icin kucuk buyuk-harf baslik + deger sutunu (SKOR / 1 240).
static func hud_caption(text: String) -> Label:
	return label(text.to_upper(), &"LabelHudCaption", HORIZONTAL_ALIGNMENT_CENTER)
