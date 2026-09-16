extends Node
## Mağaza — production dükkân ekranı (M8.6-05) regresyon testi. Headless,
## kaydı byte-identical geri koyar.
##
##   godot --headless --audio-driver Dummy --path . res://tools/shop_ui_test.tscn
##
## Kontroller: yapı (ScreenTopBar + "MAĞAZA", "+" yok, sekme çubuğu yok,
## gerçek ScrollContainer, iki bölüm plakası, tam 4 güç kartı / 20 skin
## kartı, eski liste/çip/neon parçası yok); güç verisi (kanonik fiyatlar
## 120/180/100/160, stok, amaç metni gerçek mekanik); satın alma (yeter →
## onay → tek transaction: Hamur −fiyat, stok +1, tek save; yetmez → hiçbir
## şey değişmez + geri bildirim; onay kapatmak harcamaz); skinler (50/150/
## 400/900, sahip ≠ satılık, takılı ayrık, kanonik satın alma, auto-equip
## YOK); rotalar (geri → Ana Sayfa, Android geri → önce onay kapanır sonra
## Ana Sayfa, çıkış yok); dört pencere + A36 payı (kırpma/çakışma yok,
## dokunma ≥ 48, sabit üst satır, ilk kart satırın altında, en alt
## erişilebilir); kayıt dosyası değişmez; kaynak hijyeni + sahte ürün yok.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const VIEWS: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(720, 1560),
	Vector2i(540, 960), Vector2i(1080, 2340)]
## A36 punch-hole: 92 px fiziksel / 1.5 = 61 tuval px (M8.6-02 cihaz kapısı).
const A36_SAFE_TOP: float = 61.0
const RUNTIME_FILES: Array[String] = [
	"res://scripts/ui/shop_screen.gd", "res://scripts/ui/shop_power_card.gd",
	"res://scripts/ui/shop_skin_card.gd", "res://scripts/ui/screen_top_bar.gd",
	"res://scenes/ui/shop_screen.tscn", "res://assets/visual/ui_theme.tres",
]
const FORBIDDEN: Array[String] = ["_visual_source", "layerlab_spike", "layerlab_casual_game", "unitypackage"]
## Sahte monetizasyon: gerçek para, indirim, gem, reklamsız, paket, abonelik.
const FAKE_MONETIZATION: Array[String] = ["TRY", "₺", "USD", "$", "indirim", "İndirim", "%",
	"gem", "Gem", "Reklamsız", "reklamsız", "Starter", "starter", "Paket", "paket", "abonelik",
	"Best", "Popular", "Popüler", "No Ads"]
const SHOP_VARIATIONS: Array[StringName] = [&"PanelShopCard", &"PanelShopCardPower", &"PanelShopCardOwned",
	&"PanelShopSection", &"PanelShopToast", &"OwnedBadge", &"ButtonBuyLocked"]
const EXPECTED_POWER_PRICES: Dictionary = {
	PowerUp.Type.BOMB: 120, PowerUp.Type.UPGRADE: 180,
	PowerUp.Type.SHAKE: 100, PowerUp.Type.CLEAR_SMALL: 160,
}
const EXPECTED_SKIN_PRICES: Dictionary = {
	SkinData.Rarity.COMMON: 50, SkinData.Rarity.RARE: 150,
	SkinData.Rarity.EPIC: 400, SkinData.Rarity.LEGENDARY: 900,
}

var _fails: int = 0
var _checks: int = 0
var _saved: Dictionary = {}
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _main: Node2D
## Test bitti mi: `_exit_tree` bundan önce gelirse (uygulama kapandı / betik
## hatası) kayıt yine de geri konur ve FAIL basılır.
var _finished: bool = false
## Beklenen tuval: pencere → tuval (720 geniş, yükseklik oranla).
const EXPECTED_CANVAS: Dictionary = {
	Vector2i(720, 1280): Vector2(720, 1280), Vector2i(720, 1560): Vector2(720, 1560),
	Vector2i(540, 960): Vector2(720, 1280), Vector2i(1080, 2340): Vector2(720, 1560),
}


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	await get_tree().process_frame
	_saved = SaveManager.data.duplicate(true)
	var save_path: String = SaveManager.SAVE_PATH
	_had_save = FileAccess.file_exists(save_path)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(save_path)
	# Günlük ödül bugün alınmış gibi: main._ready kayda yazmasın.
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	_apply_mid()
	# Bekçi: test 120 s'de bitmezse (askı) kayıt geri konur, çıkış 2.
	get_tree().create_timer(120.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 120 s'de bitmedi — kayıt geri kondu")
			SaveManager.data = _saved
			_restore_save_file()
			get_tree().quit(2))

	get_window().size = Vector2i(720, 1000)
	await get_tree().process_frame
	await _resize(VIEWS[0])
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_main._daily.visible = false
	var shop: CanvasLayer = _main._screens[3]
	var tabs: CanvasLayer = _main._tabs
	var theme: Theme = ThemeDB.get_project_theme()

	print("-- tema")
	for type in SHOP_VARIATIONS:
		_c("%s variation'ı var" % type, theme.get_type_list().has(type))
	_c("ButtonBuyLocked soluk cyan gövde (CYAN_MUTED, gerçek pasif DISABLED'dan ayrık), lacivert-mor yazı",
		(theme.get_stylebox("normal", &"ButtonBuyLocked") as StyleBoxTexture).modulate_color.is_equal_approx(UiTokens.CYAN_MUTED)
		and not UiTokens.CYAN_MUTED.is_equal_approx(UiTokens.DISABLED)
		and theme.get_color("font_color", &"ButtonBuyLocked") == UiTokens.NAVY_PURPLE)
	_c("güç kartı gövdesi TRAY_CREAM (PanelShopCardPower), skin kartı CREAM, sahip olunan CREAM_DEEP",
		(theme.get_stylebox("panel", &"PanelShopCardPower") as StyleBoxTexture).modulate_color.is_equal_approx(UiTokens.TRAY_CREAM)
		and (theme.get_stylebox("panel", &"PanelShopCardOwned") as StyleBoxTexture).modulate_color.is_equal_approx(UiTokens.CREAM_DEEP))
	_c("PanelShopCard krem card_bevel_soft (HUD v5 kart ailesi)",
		(theme.get_stylebox("panel", &"PanelShopCard") as StyleBoxTexture).modulate_color.is_equal_approx(UiTokens.CREAM)
		and (theme.get_stylebox("panel", &"PanelShopCard") as StyleBoxTexture).texture.resource_path.contains("card_bevel_soft"))

	print("-- yapı")
	_main._show_tab(3)
	await get_tree().process_frame
	await get_tree().process_frame
	var bar: ScreenTopBar = shop.top_bar()
	_c("üst satır ScreenTopBar: geri ButtonHomeIcon (oturmuş), Hamur PanelHomePill", bar != null
		and bar.back_button().theme_type_variation == &"ButtonHomeIcon" and bar.back_button().has_meta(&"face")
		and (bar.pill().get_meta(&"pill") as PanelContainer).theme_type_variation == &"PanelHomePill")
	_c("başlık 'MAĞAZA' (noktalı İ, Ğ) pembe HeaderRibbon", bar.title_text() == "MAĞAZA"
		and bar.title_plate().theme_type_variation == &"HeaderRibbon")
	_c("Mağaza'da Hamur pill'inde '+' YOK (kendine giden rota yok)", bar.add_button() == null
		and _count_variation(shop, &"ButtonHomeAdd") == 0 and _count_variation(shop, &"ButtonResourceAdd") == 0)
	_c("Mağaza'da sekme çubuğu GİZLİ", not tabs.visible)
	_main._show_tab(2)
	_c("Koleksiyon'da çubuk hâlâ görünür (kendi işine kadar)", tabs.visible)
	_main._show_tab(3)
	await get_tree().process_frame
	_c("gerçek ScrollContainer (yatay kapalı, dikey kaydırma açık, çubuk gizli)", shop.scroll() != null
		and shop.scroll().horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
		and shop.scroll().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER)
	var headers: Array[Control] = shop.section_headers()
	_c("iki bölüm plakası: GÜÇLER, SKİNLER (PanelShopSection)", headers.size() == 2
		and (headers[0].get_meta(&"title_label") as Label).text == "GÜÇLER"
		and (headers[1].get_meta(&"title_label") as Label).text == "SKİNLER"
		and (headers[0].get_meta(&"plate") as PanelContainer).theme_type_variation == &"PanelShopSection")
	_c("tam 4 güç ürünü (ShopPowerCard), sırası PowerUp.all()", shop.power_cards().size() == 4
		and _count_class(shop, "ShopPowerCard") == 4 and shop.power_cards()[0].type() == PowerUp.Type.BOMB
		and shop.power_cards()[3].type() == PowerUp.Type.CLEAR_SMALL)
	_c("tam 20 skin kartı (ShopSkinCard), katalog sırası", shop.skin_cards().size() == SkinLibrary.total_count()
		and _count_class(shop, "ShopSkinCard") == 20 and shop.skin_cards()[0].skin_id() == &"common_01"
		and shop.skin_cards()[19].skin_id() == &"legendary_02")
	_c("kartlar 2 sütunlu grid (GridContainer columns=2)", _grid_columns(shop, "PowerGrid") == 2
		and _grid_columns(shop, "SkinGrid") == 2)
	_c("eski liste/çip/başlık parçası yok (CardPanel, QuietCardPanel, ChipPanel, ScreenTitle, RichTextLabel)",
		_count_variation(shop, &"CardPanel") == 0 and _count_variation(shop, &"QuietCardPanel") == 0
		and _count_variation(shop, &"ChipPanel") == 0 and _count_variation(shop, &"ScreenTitle") == 0
		and _count_class(shop, "RichTextLabel") == 0)
	_c("eski neon CandyButton / TabBar yok; alt sekme çubuğu şöyle dursun, Mağaza'da hiç yok",
		_count_class(shop, "CandyButton") == 0 and shop.get_node_or_null("TabBar") == null)
	_c("her güç kartı OWNER güç sanatını taşıyor (picto değil)", _power_art_ok(shop))
	_c("her skin kartı canlı önizleme (SkinSwatch) taşıyor", _count_class(shop, "SkinSwatch") >= 20)
	_c("üst satır Root'un son çocuğu (içeriğin ÜSTÜNDE çizilir, sabit)", bar.get_parent() == shop.get_node("Root")
		and bar.get_index() == shop.get_node("Root").get_child_count() - 1)

	print("-- güç verisi (orta oyuncu: 335 Hamur, stok 3/1/0/2)")
	for card in shop.power_cards():
		var type: PowerUp.Type = card.type()
		var price: int = int(EXPECTED_POWER_PRICES[type])
		_c("%s fiyatı %d Hamur (PowerUpEconomy ile aynı)" % [PowerUp.display_name(type), price],
			card.price_text() == "%d Hamur" % price and PowerUpEconomy.price(type) == price)
		_c("%s adı Baloo LabelSection, amaç metni dolu" % PowerUp.display_name(type),
			card.name_text() == PowerUp.display_name(type) and not card.purpose_text().is_empty())
	_c("stok rozetleri kayıttan: Bomba ×3, Büyütücü ×1, Sarsıntı ×0, Temizleyici ×2",
		shop.power_card(PowerUp.Type.BOMB).stock_text() == "Stok ×3"
		and shop.power_card(PowerUp.Type.UPGRADE).stock_text() == "Stok ×1"
		and shop.power_card(PowerUp.Type.SHAKE).stock_text() == "Stok ×0"
		and shop.power_card(PowerUp.Type.CLEAR_SMALL).stock_text() == "Stok ×2")
	_c("stok 0 kart yine satılık (335 ≥ 100): cyan SATIN AL", shop.power_card(PowerUp.Type.SHAKE).is_affordable()
		and shop.power_card(PowerUp.Type.SHAKE).buy_button().theme_type_variation == &"ButtonPrimary"
		and not shop.power_card(PowerUp.Type.SHAKE).buy_button().disabled)
	_c("amaç metinleri gerçek mekaniği anlatıyor (yok eder / üst seviye / sarsar / küçük)",
		shop.power_card(PowerUp.Type.BOMB).purpose_text().contains("yok eder")
		and shop.power_card(PowerUp.Type.UPGRADE).purpose_text().contains("üst seviye")
		and shop.power_card(PowerUp.Type.SHAKE).purpose_text().contains("sarsar")
		and shop.power_card(PowerUp.Type.CLEAR_SMALL).purpose_text().contains("Küçük"))
	_c("Hamur pill'i kayıttaki değeri gösteriyor (335)", (bar.pill().get_meta(&"value_label") as Label).text == "335")

	print("-- satın alma (kanonik tek transaction)")
	_apply_mid()
	shop.refresh()
	await get_tree().process_frame
	var bomb: ShopPowerCard = shop.power_card(PowerUp.Type.BOMB)
	var dough_before: int = SaveManager.dough()
	var stock_before: int = SaveManager.powerup_count(PowerUp.Type.BOMB)
	bomb.buy_button().pressed.emit()
	await get_tree().process_frame
	_c("SATIN AL → onay penceresi açılır, satın alma HENÜZ yok", shop.is_confirm_open()
		and SaveManager.dough() == dough_before and SaveManager.powerup_count(PowerUp.Type.BOMB) == stock_before)
	_c("onay: başlık 'Bomba ×1', 'Stok ×3 → ×4', fiyat '120 Hamur', bakiye '335 → 215', CTA ButtonCTA", shop._confirm_title.text == "Bomba ×1"
		and shop._confirm_detail.text == "Stok ×3 → ×4" and shop._confirm_price.text == "120 Hamur"
		and shop.confirm_balance_text() == "Bakiye 335 → 215"
		and shop._confirm_yes.theme_type_variation == &"ButtonCTA")
	shop._confirm_no.pressed.emit()
	await get_tree().process_frame
	_c("Vazgeç → pencere kapanır, hiçbir şey harcanmaz", not shop.is_confirm_open()
		and SaveManager.dough() == dough_before and SaveManager.powerup_count(PowerUp.Type.BOMB) == stock_before)
	bomb.buy_button().pressed.emit()
	await get_tree().process_frame
	var file_before: PackedByteArray = FileAccess.get_file_as_bytes(save_path) if FileAccess.file_exists(save_path) else PackedByteArray()
	shop._confirm_yes.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_c("SATIN AL → Hamur tam fiyat düştü (335 → 215)", SaveManager.dough() == dough_before - 120)
	_c("stok +1 (3 → 4), kart rozeti 'Stok ×4'", SaveManager.powerup_count(PowerUp.Type.BOMB) == stock_before + 1
		and bomb.stock_text() == "Stok ×4")
	_c("bakiye pill'i anında kanonik model (215)", (bar.pill().get_meta(&"value_label") as Label).text == "215")
	_c("onay kapandı, başarı plakası görünür ('alındı')", not shop.is_confirm_open()
		and shop.is_toast_visible() and shop.toast_text().contains("alındı"))
	var written: Dictionary = _read_save_file()
	_c("dosyadaki Hamur ve stok tutarlı (215 / bomb 4 — tek transaction sonucu; yol kaynak taramasıyla kilitli)",
		int(written.get("dough", -1)) == 215 and int((written.get("powerups", {}) as Dictionary).get("bomb", -1)) == 4)
	_c("kayıt dosyası yazıldı (SaveManager.save_game)", FileAccess.get_file_as_bytes(save_path) != file_before)
	# Diğer kartların 'yetmiyor' durumu da anında (215: Büyütücü 180 yetiyor, hepsi yetiyor).
	_c("diğer kartlar da tazelendi (215 ≥ 180: hepsi satılık)", shop.power_card(PowerUp.Type.UPGRADE).is_affordable())

	print("-- yetersiz Hamur")
	_apply_mid()
	SaveManager.data["dough"] = 80
	shop.refresh()
	await get_tree().process_frame
	_c("80 Hamur: dört güç kartı 'yetmiyor' (ButtonBuyLocked, disabled DEĞİL, fiyat koyu pembe, Hamur ikonu soluk)",
		_all_power_locked(shop) and not bomb.buy_button().disabled
		and bomb._price_label.get_theme_color("font_color") == UiTokens.PINK_DEEP
		and (bomb.price_row().get_child(0) as CanvasItem).self_modulate.a < 0.9)
	var stock_poor: int = SaveManager.powerup_count(PowerUp.Type.BOMB)
	file_before = FileAccess.get_file_as_bytes(save_path)
	bomb.buy_button().pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_c("yetmezken SATIN AL → onay AÇILMAZ, satın alma YOK", not shop.is_confirm_open()
		and SaveManager.dough() == 80 and SaveManager.powerup_count(PowerUp.Type.BOMB) == stock_poor)
	_c("geri bildirim plakası görünür ('Hamur yetmiyor'), kart sallanıyor", shop.is_toast_visible()
		and shop.toast_text().contains("yetmiyor") and bomb._wiggle != null and bomb._wiggle.is_valid())
	_c("kayıt dosyası DEĞİŞMEDİ (sessiz mutasyon yok)", FileAccess.get_file_as_bytes(save_path) == file_before)
	await get_tree().create_timer(0.3).timeout
	_c("sallanma bitti, kart düz (rotation ≈ 0)", absf(bomb.rotation) < 0.001)
	# Onay açıkken Hamur düşerse (teorik yarış): kanonik yol reddeder, UI toast.
	_apply_mid()
	shop.refresh()
	await get_tree().process_frame
	bomb.buy_button().pressed.emit()
	await get_tree().process_frame
	SaveManager.data["dough"] = 10
	shop._confirm_yes.pressed.emit()
	await get_tree().process_frame
	_c("onay açıkken Hamur yetmez olursa: satın alma yok, 'yetmedi' plakası", SaveManager.dough() == 10
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == 3 and shop.toast_text().contains("yetmedi"))

	print("-- skinler")
	_apply_mid()
	shop.refresh()
	await get_tree().process_frame
	var rarity_ok: bool = true
	for card in shop.skin_cards():
		var expected: int = int(EXPECTED_SKIN_PRICES[card.rarity()])
		if Shop.price(card.rarity()) != expected:
			rarity_ok = false
		if not card.is_owned() and card.price_text() != "%d Hamur" % expected:
			rarity_ok = false
			print("    fiyat uyuşmadı: ", card.skin_id(), " ", card.price_text())
	_c("kilitli kartlarda rarity fiyatı 50/150/400/900 (Shop.PRICES ile aynı)", rarity_ok
		and Shop.PRICES == [50, 150, 400, 900])
	var owned_card: ShopSkinCard = shop.skin_card(&"common_01")
	var equipped_card: ShopSkinCard = shop.skin_card(&"rare_02")
	var locked_card: ShopSkinCard = shop.skin_card(&"rare_03")
	_c("sahip olunan kart: SAHİPSİN plakası (OwnedBadge), SATIN AL yok, fiyat yok, ipucu 'Koleksiyon'da tak'", owned_card.is_owned()
		and not owned_card.is_equipped() and owned_card.state_text() == "SAHİPSİN"
		and owned_card.state_plate().theme_type_variation == &"OwnedBadge"
		and not owned_card.buy_button().visible and not owned_card._price_row.visible
		and owned_card.hint_text() == "Koleksiyon'da tak")
	_c("takılı kart: TAKILI plakası (EquippedBadge nane) — sahipten görünür ayrık, ipucu 'Şu an takılı'", equipped_card.is_equipped()
		and equipped_card.state_text() == "TAKILI" and equipped_card.state_plate().theme_type_variation == &"EquippedBadge"
		and equipped_card.state_plate().theme_type_variation != owned_card.state_plate().theme_type_variation
		and not equipped_card.buy_button().visible and equipped_card.hint_text() == "Şu an takılı")
	_c("sahip olunan kart gövdesi PanelShopCardOwned, kilitli PanelShopCard (sahip ≠ satılık), güç PanelShopCardPower",
		owned_card._body.theme_type_variation == &"PanelShopCardOwned"
		and locked_card._body.theme_type_variation == &"PanelShopCard"
		and bomb._body.theme_type_variation == &"PanelShopCardPower")
	_c("kilitli kart: gerçek FINAL önizleme + kilit rozeti + fiyat + SATIN AL", not locked_card.is_owned()
		and locked_card.swatch()._image.texture == SkinLibrary.find(&"rare_03").preview_texture
		and locked_card.swatch()._lock.visible and locked_card._price_row.visible and locked_card.buy_button().visible)
	_c("rarity dili: Common lavanta halka / Rare mavi / Epic lavanta-mor + hale / Legendary altın + hale + pırıltı",
		shop.skin_card(&"common_03")._rim.self_modulate.is_equal_approx(UiTokens.LAVENDER_LIGHT)
		and not shop.skin_card(&"common_03").halo().visible
		and shop.skin_card(&"rare_03")._rim.self_modulate.b > shop.skin_card(&"rare_03")._rim.self_modulate.r
		and shop.skin_card(&"epic_02").halo().visible
		and shop.skin_card(&"legendary_01")._rim.self_modulate.is_equal_approx(UiTokens.GOLD)
		and shop.skin_card(&"legendary_01").halo().visible and shop.skin_card(&"legendary_01")._sparkles[0].visible
		and not shop.skin_card(&"epic_02")._sparkles[0].visible)
	_c("rarity etiketi her kartta (RarityCommon/…)", shop.skin_card(&"common_03").rarity_tag().theme_type_variation == &"RarityCommon"
		and shop.skin_card(&"legendary_01").rarity_tag().theme_type_variation == &"RarityLegendary")
	# Kanonik satın alma: rare_03 (150), 335 → 185; takılı DEĞİŞMEZ.
	var equipped_before: StringName = SaveManager.equipped_skin_id()
	var granted: Array = []
	SaveManager.skin_granted.connect(func(id: StringName) -> void: granted.append(id))
	locked_card.buy_button().pressed.emit()
	await get_tree().process_frame
	_c("skin SATIN AL → onay (ad, 'Rare skin', 150 Hamur)", shop.is_confirm_open()
		and shop._confirm_title.text == SkinLibrary.find(&"rare_03").display_name
		and shop._confirm_detail.text.begins_with("Rare skin") and shop._confirm_price.text == "150 Hamur")
	shop._confirm_yes.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_c("skin satın alındı (owns_skin), Hamur −150 (335 → 185), skin_granted BİR kez", SaveManager.owns_skin(&"rare_03")
		and SaveManager.dough() == 185 and granted == [&"rare_03"])
	_c("auto-equip YOK: takılı skin aynen (rare_02)", SaveManager.equipped_skin_id() == equipped_before
		and SaveManager.equipped_skin_id() == &"rare_02")
	_c("kart SAHİPSİN'e döndü (buton yok), takılı kart hâlâ TAKILI", locked_card.is_owned()
		and locked_card.state_text() == "SAHİPSİN" and not locked_card.buy_button().visible
		and equipped_card.is_equipped())
	written = _read_save_file()
	_c("dosyada Hamur 185 ve unlocked_skins rare_03 birlikte (tek transaction sonucu)", int(written.get("dough", -1)) == 185
		and (written.get("unlocked_skins", []) as Array).has("rare_03"))
	# Yetmeyen skin: legendary 900 > 185.
	var legendary: ShopSkinCard = shop.skin_card(&"legendary_01")
	_c("185 Hamur: Legendary (900) 'yetmiyor' butonu, Common (50) cyan", not legendary.is_affordable()
		and legendary.buy_button().theme_type_variation == &"ButtonBuyLocked"
		and shop.skin_card(&"common_03").is_affordable())
	legendary.buy_button().pressed.emit()
	await get_tree().process_frame
	_c("yetmeyen skin → onay yok, satın alma yok, geri bildirim", not shop.is_confirm_open()
		and not SaveManager.owns_skin(&"legendary_01") and SaveManager.dough() == 185
		and shop.toast_text().contains("yetmiyor"))
	# Koleksiyon'da takınca Mağaza'ya dönüşte kart TAKILI (refresh kanonik).
	SaveManager.data["equipped_skin"] = "rare_03"
	shop.scroll().scroll_vertical = 600
	await get_tree().process_frame
	_c("ön koşul: kaydırma 600'e alınabildi (içerik uzun)", shop.scroll().scroll_vertical == 600)
	_main._show_tab(2)
	_main._show_tab(3)
	await get_tree().process_frame
	_c("Koleksiyon'da takılan skin Mağaza'ya dönüşte TAKILI, eski takılı SAHİPSİN", locked_card.is_equipped()
		and equipped_card.is_owned() and not equipped_card.is_equipped())
	_c("sekmeye giriş kaydırmayı en üste alır (600 → 0)", shop.scroll().scroll_vertical == 0)

	print("-- rotalar")
	_apply_mid()
	_main._show_tab(3)
	await get_tree().process_frame
	bar.back_button().pressed.emit()
	_c("geri → Ana Sayfa (sekme çubuğu gizli)", _main._active_tab == 0 and _main._screens[0].visible and not tabs.visible)
	_main._screens[0].feature_button(&"shop").pressed.emit()
	_c("Home MAĞAZA madalyonu → Mağaza (tek örnek, çubuk yok)", _main._active_tab == 3 and shop.visible
		and not tabs.visible and _count_class(_main, "ShopPowerCard") == 4)
	_main._show_tab(0)
	(_main._screens[0]._dough_pill.get_meta(&"add_button") as Button).pressed.emit()
	_c("Home Hamur '+' → Mağaza", _main._active_tab == 3 and shop.visible)
	_main._show_tab(1)
	_main._screens[1].top_bar().add_button().pressed.emit()
	_c("Harita Hamur '+' → Mağaza", _main._active_tab == 3 and shop.visible)
	_c("Mağaza CanvasLayer main'de tek kez (çift örnek yok)", _count_children_of_scene(_main, "res://scenes/ui/shop_screen.tscn") == 1)

	print("-- Android geri")
	_main._show_tab(3)
	_main._last_back_msec = -1000
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("Mağaza'da geri → Ana Sayfa (çıkış yok: _exit_tree bekçisi SONUC'tan önce gelirse FAIL basar)", _main._active_tab == 0
		and _main._screens[0].visible)
	_main._show_tab(3)
	bomb.buy_button().pressed.emit()
	await get_tree().process_frame
	_main._last_back_msec = -1000
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("onay açıkken geri → önce onay kapanır, Mağaza kalır", not shop.is_confirm_open() and _main._active_tab == 3)
	_main._last_back_msec = -1000
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("ikinci geri → Ana Sayfa", _main._active_tab == 0)
	_main._show_tab(3)
	_main._last_back_msec = -1000
	_main.open_settings()
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("Mağaza'da ayarlar açıkken geri → ayarlar kapanır, Mağaza kalır", not _main._settings.visible and _main._active_tab == 3)
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_c("gameplay geri tuşu politikası aynen (debounce + quit_on_go_back=false)", main_src.contains("quit_on_go_back = false")
		and main_src.contains("BACK_DEBOUNCE_MSEC"))
	_c("sekme çubuğu yalnız Koleksiyon'da (main._show_tab: tab == 2)", main_src.contains("_tabs.visible = tab == 2"))

	print("-- yerleşim")
	_apply_mid()
	for view in VIEWS:
		await _resize(view)
		_main._show_tab(3)
		await get_tree().process_frame
		await get_tree().process_frame
		await _check_layout(shop, EXPECTED_CANVAS[view], 0.0, "%dx%d" % [view.x, view.y])
	await _resize(VIEWS[1])
	_main._show_tab(3)
	shop._layout_with_safe_top(A36_SAFE_TOP)
	await get_tree().process_frame
	await get_tree().process_frame
	await _check_layout(shop, Vector2(VIEWS[1]), A36_SAFE_TOP, "720x1560")
	_c("A36: üst satır punch-hole altından başlar (geri butonu y ≥ 61)", bar.back_button().global_position.y >= A36_SAFE_TOP)
	shop._layout_with_safe_top(-1.0)
	await _resize(VIEWS[0])

	print("-- kayıt")
	_restore_save_file()
	file_before = FileAccess.get_file_as_bytes(save_path) if FileAccess.file_exists(save_path) else PackedByteArray()
	_apply_mid()
	SaveManager.data["dough"] = 20
	for i in 3:
		_main._show_tab(3)
		await get_tree().process_frame
	bomb.buy_button().pressed.emit()
	shop.skin_card(&"legendary_02").buy_button().pressed.emit()
	await get_tree().process_frame
	var file_after: PackedByteArray = FileAccess.get_file_as_bytes(save_path) if FileAccess.file_exists(save_path) else PackedByteArray()
	_c("Mağaza çizimi/yenilemesi/yetmeyen dokunuş kayıt dosyasını değiştirmedi", file_before == file_after)
	var shop_src: String = FileAccess.get_file_as_string("res://scripts/ui/shop_screen.gd")
	var power_src: String = FileAccess.get_file_as_string("res://scripts/ui/shop_power_card.gd")
	var skin_src: String = FileAccess.get_file_as_string("res://scripts/ui/shop_skin_card.gd")
	_c("Mağaza Hamur'a doğrudan dokunmuyor (add_dough / spend_dough / data[\"dough\"] / grant_ / save_game yok)",
		not shop_src.contains("add_dough(") and not shop_src.contains("spend_dough(")
		and not shop_src.contains("data[\"dough\"]") and not shop_src.contains("grant_")
		and not shop_src.contains("save_game(") and not shop_src.contains("equip_skin(")
		and not power_src.contains("SaveManager.data") and not skin_src.contains("SaveManager.data")
		and not power_src.contains("purchase(") and not skin_src.contains("purchase("))
	_c("satın alma yalnız kanonik yoldan (PowerUpEconomy.purchase / Shop.purchase)",
		shop_src.contains("PowerUpEconomy.purchase(") and shop_src.contains("Shop.purchase(")
		and not shop_src.contains("purchase_powerup_with_dough") and not shop_src.contains("purchase_skin_with_dough"))
	var price_literal := RegEx.new()
	price_literal.compile("\"\\d+ Hamur\"")
	_c("fiyat hardcode yok (\"N Hamur\" literali yok; PowerUpEconomy.price / SkinEntry.price)",
		price_literal.search(shop_src) == null and price_literal.search(power_src) == null
		and price_literal.search(skin_src) == null
		and power_src.contains("PowerUpEconomy.price(") and skin_src.contains("entry.price"))

	print("-- kaynak hijyeni")
	var clean: bool = true
	for path in RUNTIME_FILES:
		var text: String = FileAccess.get_file_as_string(path)
		for word in FORBIDDEN:
			if text.contains(word):
				clean = false
				print("    yasak referans: ", path, " -> ", word)
	_c("runtime dosyalarında _visual_source / spike referansı yok", clean)
	var fake: bool = false
	var visible_text: String = _collect_text(shop)
	for word in FAKE_MONETIZATION:
		if visible_text.contains(word):
			fake = true
			print("    sahte ürün metni: ", word)
	_c("ekranda sahte monetizasyon yok (gerçek para / indirim / gem / reklamsız / paket)", not fake)
	_c("ekranda gerçek para Güç Paketi / reklam ürünü YOK (yalnız 4 güç + 20 skin)", _count_class(shop, "ShopPowerCard") == 4
		and _count_class(shop, "ShopSkinCard") == 20 and not shop_src.contains("Mini") and not shop_src.contains("Mega"))

	_main.queue_free()
	await get_tree().process_frame
	SaveManager.data = _saved
	_restore_save_file()
	_finished = true
	print("=== SONUC: %d/%d kontrol, %d kaldi ===" % [_checks - _fails, _checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


## Kayıt güvenlik ağı: test SONUC'a varmadan ağaçtan çıkarsa (uygulama
## kapandı — örn. Android geri yanlışlıkla quit çağırdı — ya da betik hatası)
## FAIL basılır ve owner kaydı byte'ıyla geri konur.
func _exit_tree() -> void:
	if _finished:
		return
	print("  [FAIL] test SONUC'tan önce ağaçtan çıktı (uygulama kapandı / betik hatası) — kayıt geri kondu")
	SaveManager.data = _saved
	_restore_save_file()


# --- Yardımcılar ---

func _restore_save_file() -> void:
	if not _had_save:
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()


func _read_save_file() -> Dictionary:
	if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	return parsed if parsed is Dictionary else {}


func _resize(view: Vector2i) -> void:
	get_window().size = view
	await get_tree().process_frame
	await get_tree().process_frame


func _apply_mid() -> void:
	SaveManager.data["highest_level_unlocked"] = 4
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3}
	SaveManager.data["dough"] = 335
	SaveManager.data["unlocked_skins"] = ["common_01", "common_02", "rare_02", "epic_01"]
	SaveManager.data["equipped_skin"] = "rare_02"
	SaveManager.data["powerups"] = {"bomb": 3, "upgrade": 1, "shake": 0, "clear_small": 2}
	SaveManager.data["endless_high_score"] = 0
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()


func _all_power_locked(shop: CanvasLayer) -> bool:
	for card in shop.power_cards():
		if card.is_affordable() or card.buy_button().theme_type_variation != &"ButtonBuyLocked":
			return false
	return true


func _power_art_ok(shop: CanvasLayer) -> bool:
	for card in shop.power_cards():
		var art: TextureRect = card.well().get_meta(&"art")
		if art == null or art.texture == null or art.texture != PowerUp.icon(card.type()):
			return false
	return true


func _grid_columns(root: Node, grid_name: String) -> int:
	var grid := root.find_child(grid_name, true, false) as GridContainer
	return grid.columns if grid != null else 0


func _count_variation(root: Node, variation: StringName) -> int:
	var count: int = 0
	for node in _all_controls(root):
		if node.theme_type_variation == variation:
			count += 1
	return count


func _count_class(root: Node, klass: String) -> int:
	return root.find_children("*", klass, true, false).size()


func _count_children_of_scene(root: Node, scene_path: String) -> int:
	var count: int = 0
	for child in root.get_children():
		if child.scene_file_path == scene_path:
			count += 1
	return count


func _all_controls(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Control:
			out.append(node)
		for child in node.get_children():
			stack.append(child)
	return out


func _collect_text(node: Node) -> String:
	var parts: PackedStringArray = []
	for child in node.get_children():
		var label := child as Label
		if label != null:
			parts.append(label.text)
		var button := child as Button
		if button != null:
			parts.append(button.text)
		parts.append(_collect_text(child))
	return "\n".join(parts)


func _all_cards(shop: CanvasLayer) -> Array[Control]:
	var out: Array[Control] = []
	for card in shop.power_cards():
		out.append(card)
	for card in shop.skin_cards():
		out.append(card)
	return out


## Yerleşim: üst satır güvenli payın altında ve sabit; kartlar 2 sütun,
## yatayda ekranda, birbiriyle kesişmiyor, ilk kart satırın altında
## başlıyor; SATIN AL / geri ≥ 48; kaydırma sonunda son kart tamamen
## görünür ve alt paya sığıyor; kaydırma üst satırı oynatmıyor.
func _check_layout(shop: CanvasLayer, view: Vector2, safe_top: float, window_tag: String) -> void:
	var tag: String = "%s (tuval %dx%d)%s" % [window_tag, int(view.x), int(view.y), " +A36" if safe_top > 0.0 else ""]
	var visible: Rect2 = get_viewport().get_visible_rect()
	_c("%s tuval genişliği 720" % tag, is_equal_approx(visible.size.x, 720.0) and is_equal_approx(visible.size.y, view.y))
	var bar: ScreenTopBar = shop.top_bar()
	var scroll: ScrollContainer = shop.scroll()
	scroll.scroll_vertical = 0
	await get_tree().process_frame
	var bar_bottom: float = bar.height()
	var screen: Rect2 = Rect2(Vector2(0, safe_top), Vector2(720.0, view.y - safe_top))
	var bar_controls: Array[Control] = [bar.back_button(), bar.pill(), bar.title_plate()]
	var bar_ok: bool = true
	for control in bar_controls:
		if not screen.encloses(control.get_global_rect()):
			bar_ok = false
			print("    üst satır ekran dışı: ", control.name, " ", control.get_global_rect())
	_c("%s üst satır güvenli payın altında, ekranda" % tag, bar_ok)
	_c("%s geri butonu ≥ 48 px" % tag, bar.back_button().size.x >= 48.0 and bar.back_button().size.y >= 48.0)
	var cards: Array[Control] = _all_cards(shop)
	var inside_x: bool = true
	var touch: bool = true
	var overlap: bool = false
	for card in cards:
		var rect: Rect2 = card.get_global_rect()
		if rect.position.x < 0.0 or rect.end.x > 720.0:
			inside_x = false
			print("    yatay taşma: ", card.name, " ", rect)
		var buy: Button = card.buy_button()
		if buy.visible and (buy.size.x < 48.0 or buy.size.y < 48.0):
			touch = false
	for i in cards.size():
		for j in range(i + 1, cards.size()):
			if cards[i].get_global_rect().intersects(cards[j].get_global_rect()):
				overlap = true
				print("    kart çakışması: ", cards[i].name, " x ", cards[j].name)
	_c("%s 24 kart yatayda ekranda (kırpma yok), 2 sütun" % tag, inside_x
		and is_equal_approx(cards[0].get_global_rect().position.x, 24.0)
		and is_equal_approx(cards[1].get_global_rect().end.x, 696.0))
	_c("%s kartlar birbiriyle kesişmiyor" % tag, not overlap)
	_c("%s SATIN AL butonları ≥ 48 px (aslında 296×58)" % tag, touch
		and shop.power_cards()[0].buy_button().size.x >= 200.0)
	var first: Rect2 = cards[0].get_global_rect()
	var header: Rect2 = shop.section_headers()[0].get_global_rect()
	_c("%s ilk bölüm plakası haze solmasının dışında, ilk kart plakanın altında (plaka y %d ≥ bar %d + %d)" % [tag, int(header.position.y), int(bar_bottom), int(shop.HAZE_FADE)],
		header.position.y >= bar_bottom + shop.HAZE_FADE and first.position.y > header.end.y)
	_c("%s ilk güç satırı ekranda tamamen görünür" % tag, first.end.y <= view.y and cards[1].get_global_rect().end.y <= view.y)
	# Kart içi: buton kartın içinde, fiyat butonla kesişmiyor, kuyu kartın içinde.
	var bomb: ShopPowerCard = shop.power_cards()[0]
	var buy_rect: Rect2 = bomb.buy_button().get_global_rect()
	var price_rect: Rect2 = bomb._price_row.get_global_rect()
	var well_rect: Rect2 = bomb.well().get_global_rect()
	_c("%s kart içi: buton/fiyat/kuyu kartın içinde, fiyat butonla kesişmiyor" % tag,
		first.encloses(buy_rect) and first.encloses(price_rect) and first.encloses(well_rect)
		and not price_rect.intersects(buy_rect) and not well_rect.intersects(price_rect))
	var skin: ShopSkinCard = shop.skin_cards()[0]
	var skin_rect: Rect2 = skin.get_global_rect()
	_c("%s skin kartı: önizleme + ad + plaka kartın içinde" % tag, skin_rect.encloses(skin.swatch().get_global_rect())
		and skin_rect.encloses(skin._name_label.get_global_rect()) and skin_rect.encloses(skin.state_plate().get_global_rect()))
	_c("%s kart gövdesi kart dikdörtgenine sığıyor (içerik minimumu ≤ kart; halka/gölge hizalı)" % tag,
		bomb._body.size.y <= bomb.size.y + 0.5 and bomb._body.get_combined_minimum_size().y <= bomb.size.y + 0.5
		and skin._body.get_combined_minimum_size().y <= skin.size.y + 0.5)
	# Kaydırma: sonuna git, son kart tamamen görünür + alt pay; üst satır oynamaz.
	var bar_pos_before: Vector2 = bar.back_button().global_position
	var max_scroll: float = scroll.get_v_scroll_bar().max_value - scroll.size.y
	scroll.scroll_vertical = int(max_scroll) + 10
	await get_tree().process_frame
	await get_tree().process_frame
	var last: Rect2 = cards[cards.size() - 1].get_global_rect()
	_c("%s içerik kaydırılabilir (max > 0) ve sonunda son kart tamamen ekranda, alt pay ≥ 40" % tag,
		max_scroll > 0.0 and last.end.y <= view.y - 40.0 and last.position.y >= bar_bottom)
	_c("%s kaydırma üst satırı oynatmadı (sabit)" % tag, bar.back_button().global_position == bar_pos_before)
	_c("%s kaydırma sonunda ilk kart satırın altına girip kayboldu" % tag, cards[0].get_global_rect().end.y < bar_bottom)
	_c("%s ScrollContainer tam ekran (y 0, yükseklik = tuval): içerik satırın ALTINDAN kayar, kırpılmaz" % tag,
		scroll.global_position.y == 0.0 and is_equal_approx(scroll.size.y, view.y))
	scroll.scroll_vertical = int(first.position.y)
	await get_tree().process_frame
	await get_tree().process_frame
	var bar_rect: Rect2 = Rect2(Vector2(0, safe_top), Vector2(720.0, bar_bottom - safe_top))
	_c("%s orta kaydırmada bir kart üst satırla kesişiyor (satırın altında, haze örtüyor), satır yerinde" % tag,
		cards[0].get_global_rect().intersects(bar_rect) and bar.back_button().global_position == bar_pos_before)
	var haze: TextureRect = shop.haze()
	var haze_tex: GradientTexture2D = haze.texture as GradientTexture2D
	_c("%s üst haze satır boyunca düz bant (≥ .88 alfa) + %d px solma" % [tag, int(shop.HAZE_FADE)],
		haze.global_position.y == 0.0 and haze.size.y >= bar_bottom + shop.HAZE_FADE - 1.0
		and haze_tex.gradient.colors[0].a >= 0.88 and haze_tex.gradient.colors[1].a >= 0.88
		and haze_tex.gradient.offsets[1] * haze.size.y >= bar_bottom - 1.0)
	scroll.scroll_vertical = 0
	await get_tree().process_frame
