extends Node
## Production UI temeli testi (M8.6-01). Headless, kayda YAZMAZ.
##
##   godot --headless --audio-driver Dummy --path . res://tools/ui_foundation_test.tscn
##
## Kontroller: tema yukleniyor, gerekli variation'lar var ve dogru base
## type'ta, M8.5 rolleri korunmus, tipografi degismemis, core sprite/ikon
## yollari cozuluyor, 9-slice kenarlari gecerli, buton durumlari (normal /
## basili / pasif) ayri, rarity stilleri oyun verisiyle ayni tonda, kaynak
## pill'i kuruluyor, galeri sahnesi kuruluyor ve production agacinda
## `_visual_source` / ham LayerLab / spike referansi YOK.

const THEME_PATH: String = "res://assets/visual/ui_theme.tres"
const GALLERY_SCENE: PackedScene = preload("res://tools/ui_system_gallery.tscn")

const PANELS: Array[StringName] = [&"PanelBase", &"PanelCream", &"PanelPurple", &"PanelDark",
	&"PanelCard", &"PanelModal", &"PanelElevated", &"PanelListRow"]
const BUTTONS: Array[StringName] = [&"ButtonPrimary", &"ButtonSecondary", &"ButtonPurchase",
	&"ButtonDanger", &"ButtonIcon", &"ButtonRoundIcon", &"ButtonCTA", &"ButtonResourceAdd"]
const LABELS: Array[StringName] = [&"LabelDisplay", &"LabelTitle", &"LabelSection", &"LabelBody",
	&"LabelCaption", &"LabelPrice", &"LabelPositive", &"LabelWarning", &"LabelDisabled", &"LabelStat",
	&"LabelDisplayOnDark", &"LabelTitleOnDark", &"LabelSectionOnDark", &"LabelBodyOnDark",
	&"LabelCaptionOnDark", &"LabelStatOnDark", &"LabelSectionOnAccent", &"LabelBadge", &"LabelBadgeOnDark"]
const COMPONENTS: Array[StringName] = [&"ResourcePill", &"HeaderRibbon", &"SectionTag",
	&"Badge", &"LockBadge", &"EquippedBadge", &"NewBadge", &"CountBadge", &"SwitchOn", &"SwitchOff",
	&"RarityCommon", &"RarityRare", &"RarityEpic", &"RarityLegendary",
	&"RarityFrameCommon", &"RarityFrameRare", &"RarityFrameEpic", &"RarityFrameLegendary"]
const PROGRESS: Array[StringName] = [&"ProgressBarMint", &"ProgressBarGold"]
## M8.5 kabugunun rolleri — bu turda DEGISMEMELI.
const LEGACY: Array[StringName] = [&"CardPanel", &"QuietCardPanel", &"ChipPanel", &"TabBarPanel",
	&"ModalPanel", &"ToggleOn", &"ToggleOff", &"Display", &"ScreenTitle", &"SectionTitle",
	&"CardTitle", &"Stat", &"Caption", &"HudPrimary", &"HudSecondary", &"HudObjective",
	&"SecondaryButton", &"IconButton", &"TabButton"]
const ICON_ROLES: Array[String] = ["back", "close", "settings", "sound_on", "vibration", "info",
	"home", "shop", "collection", "map", "check", "lock", "plus", "arrow_next", "gift", "trophy"]
## Production agaci: burada ham kaynak / spike referansi olamaz.
const PRODUCTION_ROOTS: Array[String] = ["res://scripts", "res://scenes", "res://assets", "res://resources"]
const FORBIDDEN: Array[String] = ["_visual_source", "layerlab_casual_game", "unitypackage", "layerlab_spike"]
const SCAN_EXTENSIONS: Array[String] = ["gd", "tscn", "tres", "gdshader", "godot"]

var _fails: int = 0
var _checks: int = 0


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	await get_tree().process_frame
	var theme: Theme = load(THEME_PATH) as Theme
	_c("ui_theme.tres yukleniyor", theme != null)
	_c("proje temasi ui_theme.tres", ThemeDB.get_project_theme() != null
		and ThemeDB.get_project_theme().resource_path == THEME_PATH)
	if theme == null:
		_finish()
		return

	print("-- variation'lar")
	var types: PackedStringArray = theme.get_type_list()
	for type in PANELS + COMPONENTS:
		_c("%s var (PanelContainer)" % type, types.has(type)
			and theme.get_type_variation_base(type) == &"PanelContainer"
			and theme.has_stylebox("panel", type))
	for type in PROGRESS:
		_c("%s var (ProgressBar)" % type, types.has(type)
			and theme.get_type_variation_base(type) == &"ProgressBar"
			and theme.has_stylebox("fill", type) and theme.has_stylebox("background", type))
	for type in BUTTONS:
		_c("%s var (Button)" % type, types.has(type)
			and theme.get_type_variation_base(type) == &"Button")
	for type in LABELS:
		_c("%s var (Label)" % type, types.has(type)
			and theme.get_type_variation_base(type) == &"Label"
			and theme.has_font("font", type) and theme.has_font_size("font_size", type)
			and theme.has_color("font_color", type))
	for type in LEGACY:
		_c("M8.5 rolu korunmus: %s" % type, types.has(type))

	print("-- tipografi (degismemeli)")
	_c("Display = Baloo 2 ExtraBold 42", _font_is(theme, &"Display", "Baloo2-ExtraBold")
		and theme.get_font_size("font_size", &"Display") == 42)
	_c("Stat = Nunito Bold 20", _font_is(theme, &"Stat", "Nunito-Bold")
		and theme.get_font_size("font_size", &"Stat") == 20)
	_c("Button varsayilani = Baloo 2 Bold 27", _font_is(theme, &"Button", "Baloo2-Bold")
		and theme.get_font_size("font_size", &"Button") == 27)
	_c("default_font = Nunito SemiBold", theme.default_font != null
		and theme.default_font.resource_path.contains("Nunito-SemiBold"))
	_c("LabelDisplay = Baloo 2 ExtraBold", _font_is(theme, &"LabelDisplay", "Baloo2-ExtraBold"))
	_c("LabelTitle = Baloo 2 ExtraBold", _font_is(theme, &"LabelTitle", "Baloo2-ExtraBold"))
	_c("LabelSection = Baloo 2 Bold", _font_is(theme, &"LabelSection", "Baloo2-Bold"))
	_c("LabelBody = Nunito SemiBold", _font_is(theme, &"LabelBody", "Nunito-SemiBold"))
	_c("LabelCaption = Nunito SemiBold", _font_is(theme, &"LabelCaption", "Nunito-SemiBold"))
	_c("LabelStat/Price = Nunito Bold", _font_is(theme, &"LabelStat", "Nunito-Bold")
		and _font_is(theme, &"LabelPrice", "Nunito-Bold"))
	_c("ButtonPrimary = Baloo 2 Bold", _font_is(theme, &"ButtonPrimary", "Baloo2-Bold"))
	_c("ButtonCTA = Baloo 2 ExtraBold", _font_is(theme, &"ButtonCTA", "Baloo2-ExtraBold"))

	print("-- core asset'ler")
	var sprite_ok: int = 0
	var margin_ok: int = 0
	for name in UiCoreAssets.SPRITES:
		var info: Array = UiCoreAssets.SPRITES[name]
		var path: String = UiCoreAssets.ROOT + info[0]
		var tex: Texture2D = load(path) as Texture2D
		if tex != null and tex.get_width() == info[1] and tex.get_height() == info[2]:
			sprite_ok += 1
		var l: int = info[3]
		var t: int = info[4]
		var r: int = info[5]
		var b: int = info[6]
		if l >= 0 and t >= 0 and r >= 0 and b >= 0 and l + r < info[1] and t + b < info[2]:
			margin_ok += 1
		else:
			print("    kenar hatasi: ", name, " ", info)
	_c("%d/%d core sprite yukleniyor ve boyutu kayitla ayni" % [sprite_ok, UiCoreAssets.SPRITES.size()],
		sprite_ok == UiCoreAssets.SPRITES.size())
	_c("%d/%d 9-slice kenari gecerli (sol+sag < en, ust+alt < boy)" % [margin_ok, UiCoreAssets.SPRITES.size()],
		margin_ok == UiCoreAssets.SPRITES.size())
	_c("core asset yolu assets/visual/ui/core/", UiCoreAssets.ROOT == "res://assets/visual/ui/core/")
	var icon_ok: int = 0
	for role in ICON_ROLES:
		var tex: Texture2D = UiKit.icon_texture(role) if UiCoreAssets.ICONS.has(role) else null
		if tex != null and tex.get_width() == 128:
			icon_ok += 1
		else:
			print("    ikon eksik: ", role)
	_c("%d/%d generic picto ikon var (128 px)" % [icon_ok, ICON_ROLES.size()], icon_ok == ICON_ROLES.size())
	var all_icons_ok: bool = true
	for role in UiCoreAssets.ICONS:
		if load(UiCoreAssets.ROOT + UiCoreAssets.ICONS[role]) == null:
			all_icons_ok = false
	_c("kayitli %d ikonun tamami yukleniyor" % UiCoreAssets.ICONS.size(), all_icons_ok)

	print("-- tema stylebox dokulari")
	var missing_tex: int = 0
	var total_tex: int = 0
	for type in PANELS + COMPONENTS + BUTTONS + PROGRESS:
		for style_name in theme.get_stylebox_list(type):
			var box: StyleBox = theme.get_stylebox(style_name, type)
			if box is StyleBoxTexture:
				total_tex += 1
				var tex_box := box as StyleBoxTexture
				if tex_box.texture == null or not tex_box.texture.resource_path.begins_with(UiCoreAssets.ROOT):
					missing_tex += 1
				elif tex_box.texture_margin_left + tex_box.texture_margin_right >= tex_box.texture.get_width() \
						or tex_box.texture_margin_top + tex_box.texture_margin_bottom >= tex_box.texture.get_height():
					missing_tex += 1
	_c("%d StyleBoxTexture'in tamami core dokuya bagli, kenarlari gecerli" % total_tex,
		total_tex > 0 and missing_tex == 0)

	print("-- buton durumlari")
	for type in BUTTONS:
		var normal := theme.get_stylebox("normal", type) as StyleBoxTexture
		var pressed := theme.get_stylebox("pressed", type) as StyleBoxTexture
		var disabled := theme.get_stylebox("disabled", type) as StyleBoxTexture
		var hover := theme.get_stylebox("hover", type) as StyleBoxTexture
		var ok: bool = normal != null and pressed != null and disabled != null and hover != null
		if ok:
			ok = pressed.modulate_color != normal.modulate_color \
				and pressed.content_margin_top > normal.content_margin_top \
				and disabled.modulate_color.is_equal_approx(UiTokens.DISABLED) \
				and theme.has_color("font_disabled_color", type) \
				and theme.get_color("font_disabled_color", type) != theme.get_color("font_color", type)
		_c("%s: normal / basili (koyu + 3 px) / pasif (lavanta-gri) ayri" % type, ok)
	_c("ButtonCTA govdesi hero yukseklik (88)", (theme.get_stylebox("normal", &"ButtonCTA") as StyleBoxTexture)
		.texture.get_height() == UiTokens.HEIGHT_HERO)
	_c("ButtonPrimary govdesi normal yukseklik (58)", (theme.get_stylebox("normal", &"ButtonPrimary") as StyleBoxTexture)
		.texture.get_height() == 58)

	print("-- token'lar")
	_c("UiTokens rarity = SkinData rarity", UiTokens.RARITY_COMMON == SkinData.rarity_color(SkinData.Rarity.COMMON)
		and UiTokens.RARITY_RARE == SkinData.rarity_color(SkinData.Rarity.RARE)
		and UiTokens.RARITY_EPIC == SkinData.rarity_color(SkinData.Rarity.EPIC)
		and UiTokens.RARITY_LEGENDARY == SkinData.rarity_color(SkinData.Rarity.LEGENDARY))
	_c("UiTokens paleti UiPalette ile ayni (cyan/pembe/nane/altin/krem)",
		UiTokens.CYAN == UiPalette.CYAN and UiTokens.PINK == UiPalette.PINK
		and UiTokens.MINT == UiPalette.MINT and UiTokens.GOLD == UiPalette.GOLD
		and UiTokens.CREAM == UiPalette.CREAM and UiTokens.LAVENDER == UiPalette.LAVENDER)
	_c("dokunma hedefi: compact >= 44, TOUCH_MIN = 48 <= normal",
		UiTokens.HEIGHT_COMPACT >= 44 and UiTokens.TOUCH_MIN == 48
		and UiTokens.HEIGHT_NORMAL >= UiTokens.TOUCH_MIN)
	_c("bosluk olcegi artan (XS<SM<MD<LG<XL)", UiTokens.SPACE_XS < UiTokens.SPACE_SM
		and UiTokens.SPACE_SM < UiTokens.SPACE_MD and UiTokens.SPACE_MD < UiTokens.SPACE_LG
		and UiTokens.SPACE_LG < UiTokens.SPACE_XL)
	_c("ikon olcegi artan (24<32<48<72)", UiTokens.ICON_SMALL < UiTokens.ICON_MEDIUM
		and UiTokens.ICON_MEDIUM < UiTokens.ICON_LARGE and UiTokens.ICON_LARGE < UiTokens.ICON_HERO)
	for rarity in [SkinData.Rarity.COMMON, SkinData.Rarity.RARE, SkinData.Rarity.EPIC, SkinData.Rarity.LEGENDARY]:
		var name: String = SkinData.rarity_name(rarity)
		var tag := theme.get_stylebox("panel", StringName("Rarity" + name)) as StyleBoxTexture
		var frame := theme.get_stylebox("panel", StringName("RarityFrame" + name)) as StyleBoxTexture
		_c("Rarity%s etiketi + cercevesi rarity renginde" % name, tag != null and frame != null
			and tag.modulate_color.is_equal_approx(UiTokens.rarity_tint(rarity))
			and frame.modulate_color.is_equal_approx(UiTokens.rarity_color(rarity)))
	_c("premium altin yalniz Legendary/ProgressBarGold/Badge (ButtonPrimary cyan, Purchase nane)",
		(theme.get_stylebox("normal", &"ButtonPrimary") as StyleBoxTexture).modulate_color.is_equal_approx(UiTokens.CYAN)
		and (theme.get_stylebox("normal", &"ButtonPurchase") as StyleBoxTexture).modulate_color.is_equal_approx(UiTokens.MINT)
		and (theme.get_stylebox("normal", &"ButtonCTA") as StyleBoxTexture).modulate_color.is_equal_approx(UiTokens.CYAN)
		and (theme.get_stylebox("fill", &"ProgressBarGold") as StyleBoxTexture).modulate_color.is_equal_approx(UiTokens.GOLD))

	print("-- bilesenler kuruluyor")
	var host := Control.new()
	host.size = Vector2(720, 1280)
	add_child(host)
	var pill := UiKit.resource_pill(preload("res://assets/visual/ui/icon_dough.png"), "335", true)
	host.add_child(pill)
	await get_tree().process_frame
	_c("ResourcePill kuruluyor (boyut > 0, ResourcePill stili)", pill.size.x > 60.0 and pill.size.y >= 40.0
		and pill.theme_type_variation == &"ResourcePill"
		and pill.get_theme_stylebox("panel") is StyleBoxTexture)
	UiKit.set_pill_value(pill, "1 000", false)
	_c("ResourcePill degeri guncelleniyor", (pill.get_meta(&"value_label") as Label).text == "1 000")
	_c("ResourcePill '+' butonu ButtonResourceAdd", pill.has_meta(&"add_button")
		and (pill.get_meta(&"add_button") as Button).theme_type_variation == &"ButtonResourceAdd")
	var icon_button := UiKit.icon_button("settings")
	host.add_child(icon_button)
	var cta := UiKit.cta("DEVAM ET", "Reklam izle", &"ButtonCTA", "movie")
	host.add_child(cta)
	var modal := UiKit.modal_frame("Baslik")
	host.add_child(modal)
	var toggle := UiKit.switch_toggle(true)
	host.add_child(toggle)
	await get_tree().process_frame
	_c("ikon butonu dokunma hedefi >= 48", icon_button.size.x >= UiTokens.TOUCH_MIN
		and icon_button.size.y >= UiTokens.TOUCH_MIN and icon_button.icon != null)
	_c("CTA hero yukseklik, baslik etiketi Baloo", cta.size.y >= UiTokens.HEIGHT_HERO
		and cta.has_meta(&"title_label"))
	_c("modal_frame: govde + kurdele + kapat", modal.has_meta(&"body") and modal.has_meta(&"ribbon")
		and (modal.get_meta(&"close_button") as Button).theme_type_variation == &"ButtonRoundIcon")
	_c("switch_toggle SwitchOn/SwitchOff + LayerLab topuz", toggle.on_variation == &"SwitchOn"
		and toggle.off_variation == &"SwitchOff" and toggle.knob_texture != null and toggle.button_pressed)
	var legacy_toggle := UiToggle.new()
	_c("UiToggle varsayilani M8.5 (ToggleOn/ToggleOff, daire topuz)", legacy_toggle.on_variation == &"ToggleOn"
		and legacy_toggle.off_variation == &"ToggleOff" and legacy_toggle.knob_texture == null)
	legacy_toggle.free()
	host.queue_free()

	print("-- galeri")
	var gallery: Control = GALLERY_SCENE.instantiate()
	add_child(gallery)
	await get_tree().process_frame
	await get_tree().process_frame
	_c("ui_system_gallery kuruluyor (5 sayfa)", gallery._pages.size() == 5 and gallery._pages[0].visible)
	gallery._show(4)
	await get_tree().process_frame
	_c("galeri sayfa gecisi", gallery._active == 4 and gallery._pages[4].visible and not gallery._pages[0].visible)
	gallery.queue_free()

	print("-- production agacinda yasak referans")
	var hits: Array[String] = []
	for root in PRODUCTION_ROOTS:
		_scan(root, hits)
	_scan_file("res://project.godot", hits)
	for hit in hits:
		print("    ", hit)
	_c("production'da _visual_source / ham LayerLab / spike referansi yok (%d dosya tarandi)" % _scanned, hits.is_empty())
	_c("eski spike klasoru yok (assets/visual/ui/layerlab_spike)",
		not DirAccess.dir_exists_absolute("res://assets/visual/ui/layerlab_spike"))
	_finish()


var _scanned: int = 0


func _scan(dir_path: String, hits: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan(path, hits)
		elif SCAN_EXTENSIONS.has(entry.get_extension()):
			_scan_file(path, hits)
		entry = dir.get_next()
	dir.list_dir_end()


func _scan_file(path: String, hits: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	_scanned += 1
	# Yorum satirlari (## / # / ;) tarama disi: aciklamada "_visual_source"
	# demek serbest, KOD/yol olarak gecmesi yasak.
	for line in file.get_as_text().split("
"):
		var code: String = line.strip_edges()
		if code.begins_with("#") or code.begins_with(";"):
			continue
		for word in FORBIDDEN:
			if code.contains(word):
				hits.append("%s -> %s" % [path, word])
				break


func _font_is(theme: Theme, type: StringName, stem: String) -> bool:
	var font: Font = theme.get_font("font", type)
	return font != null and font.resource_path.get_file().begins_with(stem)


func _finish() -> void:
	print("\nUI FOUNDATION TEST: %d/%d gecti, %d hata" % [_checks - _fails, _checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)
