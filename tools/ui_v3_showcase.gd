extends Control
## TASK/057 — Squishy UI System V3 bileşen vitrini. DEV ARACI, production navigasyonuna BAĞLI DEĞİL.
##
## Sayfalar ÜRETİM bileşen sınıflarının kendisini (SquishyButton, FeatureCard, OfferCard, PowerCard,
## AttentionBadge, NavItem / GlobalNav, UiKit.section_header_v3 / confirm_shell) üretim tokenlarıyla
## kurar — ayrı bir mockup değildir. Basılı görseller çekim için bileşenin kendi basış görseli
## yoluyla (yalnız bu araçta) açılır. Hiçbir oyun kuralı, ekonomi, kayıt değeri buradan değişmez.
##
##   01_controls   CTA ailesi: birincil / ikincil / ödül / ödüllü reklam / para birimi × durumlar
##   02_cards      özellik kartı, bölüm başlığı, güç kartı, teklif kartı
##   03_badges_nav dikkat rozetleri + gezinme öğesi durumları (gerçek GlobalNav)
##   04_tokens     tipografi ölçeği, renk rolleri, yarıçap / derinlik / boşluk
##   05_modal      V3 onay penceresi (modal_shell v2 + SquishyButton)
##
## Kullanım:
##   godot --path . res://tools/ui_v3_showcase.tscn -- <çıktı_klasörü> [GxY]

const BACKDROP_SCENE: PackedScene = preload("res://scenes/ui/shell_backdrop.tscn")
const ART_TIER5: Texture2D = preload("res://assets/visual/dumpling_tier5.png")
const ART_CHEST: Texture2D = preload("res://assets/visual/ui/chest_closed.png")
const ART_DOUGH: Texture2D = preload("res://assets/visual/ui/icon_dough.png")
const SHOT_SIZE := Vector2i(720, 1280)
const MARGIN: float = 28.0

var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _page: Control
var _shots: int = 0


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://ui_v3_showcase")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	if args.size() >= 2:
		var parts: PackedStringArray = args[1].split("x")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			_size = Vector2i(int(parts[0]), int(parts[1]))
	DisplayServer.window_set_size(_size)
	add_child(BACKDROP_SCENE.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame
	await _shoot("01_controls", _page_controls)
	await _shoot("02_cards", _page_cards)
	await _shoot("03_badges_nav", _page_badges_nav)
	await _shoot("04_tokens", _page_tokens)
	await _shoot("05_modal", _page_modal)
	print("SHOT-DONE %d -> %s" % [_shots, _out_dir])
	get_tree().quit()


func _shoot(name: String, builder: Callable) -> void:
	if _page != null:
		_page.queue_free()
		await get_tree().process_frame
	_page = Control.new()
	_page.name = name
	_page.set_anchors_preset(PRESET_FULL_RECT)
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)
	await builder.call(_page)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var file: String = "%s_%dx%d.png" % [name, _size.x, _size.y]
	var err: int = img.save_png(_out_dir.path_join(file))
	_shots += 1
	print("SHOT %s %s %dx%d" % ["OK" if err == OK else "ERR", file, img.get_width(), img.get_height()])


# --- Yardımcılar -------------------------------------------------------------------

func _column(page: Control, top: float = 36.0) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.position = Vector2(MARGIN, top)
	column.size = Vector2(get_viewport_rect().size.x - MARGIN * 2.0, 0.0)
	column.add_theme_constant_override("separation", UiTokens.SPACE_LG)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(column)
	return column


func _caption(text: String) -> Label:
	var label := UiType.v3_label(text, UiType.V3_META, true)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.80))
	return label


func _heading(text: String) -> Control:
	return UiKit.section_header_v3(text)


func _row(gap: int = UiTokens.SPACE_MD) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


func _cell(control: Control, caption: String) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 6)
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.add_child(control)
	var label := _caption(caption)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(label)
	return cell


func _press(control: Control) -> void:
	# Yalnız vitrin: bileşenin KENDİ basış görseli (girdi olmadan aynı anda birden çok basılı örnek).
	control.call(&"_set_pressed_visual", true)


# --- Sayfalar ----------------------------------------------------------------------

func _page_controls(page: Control) -> void:
	var column := _column(page, 28.0)
	column.add_theme_constant_override("separation", 14)
	column.add_child(_heading("CTA AİLESİ"))
	var hero := SquishyButton.new("OYNA", SquishyButton.Kind.PRIMARY, SquishyButton.SizeClass.HERO, "play")
	hero.custom_minimum_size.x = 480.0
	column.add_child(_cell(hero, "Birincil · HERO 108 px · normal"))
	var row1 := _row()
	var primary_pressed := SquishyButton.new("BAŞLA", SquishyButton.Kind.PRIMARY)
	row1.add_child(_cell(primary_pressed, "Birincil · basılı (yüz dudağa iner)"))
	var primary_off := SquishyButton.new("BAŞLA", SquishyButton.Kind.PRIMARY)
	primary_off.set_state(SquishyButton.State.DISABLED)
	row1.add_child(_cell(primary_off, "Birincil · pasif"))
	column.add_child(row1)
	var row2 := _row()
	row2.add_child(_cell(SquishyButton.new("MEYDAN OKUMA", SquishyButton.Kind.SECONDARY), "İkincil · normal"))
	var secondary_pressed := SquishyButton.new("MEYDAN OKUMA", SquishyButton.Kind.SECONDARY)
	row2.add_child(_cell(secondary_pressed, "İkincil · basılı"))
	column.add_child(row2)
	var row3 := _row()
	row3.add_child(_cell(SquishyButton.new("ÖDÜLÜ AL", SquishyButton.Kind.REWARD, SquishyButton.SizeClass.COMPACT, "gift"),
		"Ödül · alınabilir"))
	var claimed := SquishyButton.new("ÖDÜLÜ AL", SquishyButton.Kind.REWARD, SquishyButton.SizeClass.COMPACT, "gift")
	claimed.set_state(SquishyButton.State.CLAIMED)
	row3.add_child(_cell(claimed, "Ödül · alındı"))
	var reward_off := SquishyButton.new("ÖDÜLÜ AL", SquishyButton.Kind.REWARD, SquishyButton.SizeClass.COMPACT, "gift")
	reward_off.set_state(SquishyButton.State.DISABLED)
	row3.add_child(_cell(reward_off, "Ödül · pasif"))
	column.add_child(row3)
	var row4 := _row(UiTokens.SPACE_MD)
	for done in [0, 1]:
		var ad := SquishyButton.new("REKLAM İZLE", SquishyButton.Kind.REWARDED_AD, SquishyButton.SizeClass.COMPACT)
		ad.set_ad_progress(done, 2)
		row4.add_child(_cell(ad, "Reklam · %d/2" % done))
	column.add_child(row4)
	var row5 := _row(UiTokens.SPACE_MD)
	var exhausted := SquishyButton.new("REKLAM İZLE", SquishyButton.Kind.REWARDED_AD, SquishyButton.SizeClass.COMPACT)
	exhausted.set_ad_progress(2, 2)
	row5.add_child(_cell(exhausted, "Reklam · 2/2 tükendi"))
	var unavailable := SquishyButton.new("REKLAM YOK", SquishyButton.Kind.REWARDED_AD, SquishyButton.SizeClass.COMPACT)
	unavailable.set_state(SquishyButton.State.UNAVAILABLE)
	row5.add_child(_cell(unavailable, "Reklam · yaş / rıza / dolgu yok"))
	column.add_child(row5)
	var row6 := _row()
	var price := SquishyButton.new("", SquishyButton.Kind.CURRENCY, SquishyButton.SizeClass.COMPACT)
	price.set_price(120)
	row6.add_child(_cell(price, "Fiyat · yeterli"))
	var poor := SquishyButton.new("", SquishyButton.Kind.CURRENCY, SquishyButton.SizeClass.COMPACT)
	poor.set_price(900)
	poor.set_state(SquishyButton.State.INSUFFICIENT)
	row6.add_child(_cell(poor, "Fiyat · Hamur yetmiyor"))
	var price_off := SquishyButton.new("", SquishyButton.Kind.CURRENCY, SquishyButton.SizeClass.COMPACT)
	price_off.set_price(180)
	price_off.set_state(SquishyButton.State.DISABLED)
	row6.add_child(_cell(price_off, "Fiyat · pasif"))
	column.add_child(row6)
	await get_tree().process_frame
	_press(primary_pressed)
	_press(secondary_pressed)


func _page_cards(page: Control) -> void:
	var column := _column(page, 28.0)
	column.add_theme_constant_override("separation", 18)
	column.add_child(_heading("ÖZELLİK KARTI"))
	var daily := FeatureCard.new("GÜNLÜK ÖDÜLLER", "Bugünün sandığı hazır", UiTokens.PINK, ART_CHEST)
	daily.badge().show_claim()
	column.add_child(daily)
	var challenge := FeatureCard.new("MEYDAN OKUMA", "Büyük Dumpling yap · 16 hamle", UiTokens.ROLE_SECONDARY, ART_TIER5)
	challenge.set_progress(0.6, "3/5")
	challenge.badge().show_new()
	column.add_child(challenge)
	var light := FeatureCard.new("KOLEKSİYON", "7/20 Squishy keşfedildi", UiTokens.MINT, null, "collection", true)
	light.set_cta("AÇ", SquishyButton.Kind.PRIMARY)
	column.add_child(light)
	var badge := AttentionBadge.new()
	badge.show_count(2)
	column.add_child(UiKit.section_header_v3("GÜÇLER", badge))
	var powers := _row(UiTokens.SPACE_MD)
	var bomb := PowerCard.new(PowerUp.Type.BOMB, 3)
	bomb.ad_button().set_ad_progress(0, 2)
	powers.add_child(bomb)
	var shake := PowerCard.new(PowerUp.Type.SHAKE, 0)
	shake.ad_button().set_ad_progress(2, 2)
	shake.set_selected(true)
	powers.add_child(shake)
	column.add_child(powers)
	var offer := OfferCard.new("BAŞLANGIÇ PAKETİ", "FİYAT — TASK/062")
	offer.add_reward(PowerUp.icon(PowerUp.Type.BOMB), "3")
	offer.add_reward(PowerUp.icon(PowerUp.Type.UPGRADE), "3")
	offer.add_reward(PowerUp.icon(PowerUp.Type.SHAKE), "3")
	offer.add_reward(PowerUp.icon(PowerUp.Type.CLEAR_SMALL), "3")
	offer.add_reward(ART_DOUGH, "500")
	offer.set_timer_text("2g 23sa KALDI")
	offer.set_value_tag("ÖRNEK")
	column.add_child(offer)


func _page_badges_nav(page: Control) -> void:
	var column := _column(page, 28.0)
	column.add_child(_heading("DİKKAT ROZETİ"))
	var row := _row(UiTokens.SPACE_LG + 8)
	var specs: Array = [[AttentionBadge.Mode.DOT, 0, "nokta"], [AttentionBadge.Mode.COUNT, 3, "sayı 3"],
		[AttentionBadge.Mode.COUNT, 150, "sayı 150"], [AttentionBadge.Mode.NEW, 0, "YENİ"],
		[AttentionBadge.Mode.CLAIM, 0, "al-hazır"]]
	for spec in specs:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(76.0, 76.0)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tile := Panel.new()
		tile.add_theme_stylebox_override("panel", UiKit.v3_box(UiTokens.SURFACE_HUB, 20.0, UiTokens.LAVENDER_LIGHT, 3))
		tile.position = Vector2(4.0, 12.0)
		tile.size = Vector2(60.0, 60.0)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tile)
		var badge := AttentionBadge.new()
		badge.set_mode(int(spec[0]), int(spec[1]))
		holder.add_child(badge)
		badge.place_at(Vector2(60.0, 16.0))
		row.add_child(_cell(holder, String(spec[2])))
	column.add_child(row)
	column.add_child(_heading("GEZİNME ÖĞESİ"))
	var notes := _caption("Seçili: Mağaza (krem karo) · basılı: Koleksiyon · rozet: Ana Sayfa nokta, Profil YENİ, Mağaza 2")
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(notes)
	# Gerçek GlobalNav: sayfanın ortasında (kendi katmanı; alt payı ezilerek ortaya alınır).
	# TASK/057 Tur 2: üç tepsi — seçili yan öğe (normal), seçili merkez (normal) ve seçili merkez (KOMPAKT kip: kısa
	# ekran + banner). Vitrinde tepsi sayfanın ortasına ezilmiş payla alındığı için kip açıkça verilir.
	var h: float = get_viewport_rect().size.y
	var nav := GlobalNav.new()
	page.add_child(nav)
	nav.set_compact_override(0)
	nav.set_bottom_inset_override(h * 0.47)
	nav.set_current(3)
	nav.badge(0).show_dot()
	nav.badge(4).show_new()
	nav.badge(3).show_count(2)
	var nav2 := GlobalNav.new()
	page.add_child(nav2)
	nav2.set_compact_override(0)
	nav2.set_bottom_inset_override(h * 0.245)
	nav2.set_current(1)
	nav2.set_item_enabled(4, false)
	var nav3 := GlobalNav.new()
	page.add_child(nav3)
	nav3.set_compact_override(1)
	nav3.set_bottom_inset_override(h * 0.03)
	nav3.set_current(1)
	# Altyazılar kabukların (katman 6) dock'unun ÜSTÜNDE ayrı katmanda — dock tepsinin altını koyu tutar.
	var notes_layer := CanvasLayer.new()
	notes_layer.layer = 7
	page.add_child(notes_layer)
	var caption1 := _caption("Tek seçili aile: krem candy + altın hale · basılı önizleme: Koleksiyon")
	caption1.position = Vector2(MARGIN, h * 0.53 + 6.0)
	notes_layer.add_child(caption1)
	var caption2 := _caption("Seçili merkez: aynı krem kaide + hale, ek tek katman ince altın halka · pasif: Profil")
	caption2.position = Vector2(MARGIN, h * 0.755 + 6.0)
	notes_layer.add_child(caption2)
	var caption3 := _caption("Kompakt kip (kısa ekran + banner): merkez tepside, dokunma alanı yine tam tepsi")
	caption3.position = Vector2(MARGIN, h * 0.97 - GlobalNav.TRAY_HEIGHT - GlobalNav.BOTTOM_GAP - 44.0)
	notes_layer.add_child(caption3)
	await get_tree().process_frame
	_press(nav.item_button(2))


func _page_tokens(page: Control) -> void:
	var column := _column(page, 28.0)
	column.add_theme_constant_override("separation", 10)
	column.add_child(_heading("TİPOGRAFİ ÖLÇEĞİ"))
	var roles: Array = [[UiType.V3_HERO, "Kahraman 44"], [UiType.V3_SCREEN_TITLE, "Ekran başlığı 30"],
		[UiType.V3_SECTION, "Bölüm başlığı 24"], [UiType.V3_CARD_TITLE, "Kart başlığı 23"],
		[UiType.V3_BUTTON, "BUTON 26"], [UiType.V3_BODY, "Gövde metni 19 · Nunito"],
		[UiType.V3_SECONDARY, "İkincil metin 16"], [UiType.V3_BADGE, "ROZET 16"], [UiType.V3_NAV, "GEZİNME 16"],
		[UiType.V3_META, "Meta / sayaç 14 (en küçük)"]]
	for spec in roles:
		column.add_child(UiType.v3_label(String(spec[1]), spec[0], true))
	column.add_child(_heading("RENK ROLLERİ"))
	var swatches: Array = [
		[UiTokens.ROLE_PRIMARY, "birincil"], [UiTokens.ROLE_SECONDARY, "ikincil"], [UiTokens.ROLE_REWARD, "ödül"],
		[UiTokens.ROLE_AD, "reklam"], [UiTokens.ROLE_CURRENCY, "fiyat"], [UiTokens.ROLE_PREMIUM, "premium"],
		[UiTokens.ROLE_DANGER, "yıkıcı"], [UiTokens.ATTENTION, "dikkat"], [UiTokens.SURFACE_NEUTRAL, "yüzey"],
		[UiTokens.SURFACE_HUB, "hub yüzeyi"], [UiTokens.NAV_TRAY, "gezinme"], [UiTokens.ROLE_DISABLED, "pasif"]]
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	for spec in swatches:
		var chip := Control.new()
		chip.custom_minimum_size = Vector2(98.0, 58.0)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var color: Color = spec[0]
		chip.draw.connect(func() -> void:
			UiKit.draw_candy(chip, Rect2(Vector2(4.0, 4.0), Vector2(90.0, 50.0)), color, color.darkened(0.35),
				UiTokens.RADIUS_COMPACT, UiTokens.LIP_REST, UiTokens.LIP_REST, UiTokens.DEPTH_RESTING,
				Color(1, 1, 1, 0.6), 2.0))
		grid.add_child(_cell(chip, String(spec[1])))
	column.add_child(grid)
	column.add_child(_heading("YARIÇAP · DERİNLİK"))
	var shapes := _row(UiTokens.SPACE_LG)
	var radii: Array = [[UiTokens.RADIUS_COMPACT, "kompakt 14"], [UiTokens.RADIUS_CONTROL, "kontrol 22"],
		[UiTokens.RADIUS_FEATURE, "özellik 30"], [UiTokens.RADIUS_MODAL, "pencere 36"]]
	for spec in radii:
		var box := Control.new()
		box.custom_minimum_size = Vector2(130.0, 96.0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var radius: float = float(spec[0])
		box.draw.connect(func() -> void:
			UiKit.draw_candy(box, Rect2(Vector2(6.0, 6.0), Vector2(118.0, 82.0)), UiTokens.SURFACE_ELEVATED,
				UiTokens.SURFACE_NEUTRAL_DEEP, radius, UiTokens.LIP_CARD, UiTokens.LIP_CARD, UiTokens.DEPTH_ELEVATED,
				UiTokens.LAVENDER_LIGHT, 3.0))
		shapes.add_child(_cell(box, String(spec[1])))
	column.add_child(shapes)
	var touch := _caption("Dokunma: birincil ≥ %d px (A36 ≈ 48 dp) · kompakt ≥ %d px (≈ 37 dp) · 1 px = %.3f dp (A36)" % [
		UiTokens.TOUCH_TARGET, UiTokens.TOUCH_COMPACT, UiTokens.DP_PER_PX_A36])
	touch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(touch)


func _page_modal(page: Control) -> void:
	# Arkada gerçek bir V3 sahnesi: kartlar + gezinme kabuğu (pencere açıkken GİZLİ olması gerektiği
	# hub'da Main sağlar; burada karartmanın altında ne kaldığı görünsün diye yok).
	var column := _column(page, 120.0)
	column.add_child(FeatureCard.new("GÜNLÜK ÖDÜLLER", "Bugünün sandığı hazır", UiTokens.PINK, ART_CHEST))
	column.add_child(FeatureCard.new("MEYDAN OKUMA", "Büyük Dumpling yap", UiTokens.ROLE_SECONDARY, ART_TIER5))
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.0, 0.06, 0.62)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	page.add_child(dim)
	var anchor := CenterContainer.new()
	anchor.set_anchors_preset(PRESET_FULL_RECT)
	page.add_child(anchor)
	var frame: Control = UiKit.confirm_shell("EMİN MİSİN?", "Bu pencere V3 onay iskeletidir: başlık, içerik, birincil ve ikincil eylem. Karartmaya dokunmak birakışta kapatır; iptal edilen dokunuş kapatmaz.",
		"ONAYLA", "VAZGEÇ")
	anchor.add_child(frame)
	UiKit.modal_relayout(frame)
