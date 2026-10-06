extends Node
## Koleksiyon — albüm ekranı + parça detayı (M8.6-06; TASK/044 Collection V1)
## regresyon testi. Headless, kaydı byte-identical geri koyar.
##
##   godot --headless --audio-driver Dummy --path . res://tools/collection_ui_test.tscn
##
## Kontroller: yapı (ScreenTopBar + "KOLEKSİYON", geri oku YOK — TASK/057 Tur 2, Hamur pill'i + "+",
## alt sekme çubuğu YOK, sabit albüm başlığı, gerçek ScrollContainer, dört
## rarity plakası, tam 20 katalog kartı — TASK/044: "Varsayılan" kartı / seçim
## halkası / vitrin paneli / TAK YOK); katalog (sıra, 8/6/4/2, her kart GERÇEK
## final sanat — silüet yok); başlık (N/20 + nane/altın ray + VİTRİN N/3 +
## rarity sayaçları); detay (karta dokunmak açar, KAYIT DEĞİŞMEZ; kilitli →
## KİLİTLİ + fiyat notu + MAĞAZAYA GİT; sahip → SAHİPSİN + VİTRİNE EKLE;
## vitrinde → VİTRİNDE + VİTRİNDEN ÇIKAR (+ AVATAR YAP); X / karartma / Android
## geri kapatır); vitrin eylemleri (kanonik SaveManager işlemi, tam BİR
## showcase_changed + tek yazma, Hamur/sahiplik değişmez; dolu vitrinde AÇIK
## değiştirme adımı — sessiz değiştirme yok, VAZGEÇ / geri hiçbir şey yazmaz,
## seçilen yuva korunur); kilitli MAĞAZAYA GİT → Mağaza (Koleksiyon SATIN ALMAZ
## — kaynak taraması); gizliyken / görünürken kazanılan parça; ilerleme (0/20,
## 4/20, 20/20 altın); rarity işaretleri; rotalar; 7 pencere (320 / 360 / 390 /
## 540 / 720 / 1080 genişlik) + A36 payı: albüm + detay (üç durum + değiştirme
## adımı) kırpılmıyor / çakışmıyor, dokunma ≥ 48; kayıt dosyası değişmez.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const COLLECTION_SCRIPT: GDScript = preload("res://scripts/ui/collection_screen.gd")
## Pencere boyutları: 720 tuvali (1280/1560) + gerçek telefon pencereleri —
## 320×568 (küçük 16:9), 390×844 (19.5:9), 360×800 (20:9, uzun Android),
## 540×960 ve 1080×2340 (A36 fiziksel).
const VIEWS: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(720, 1560),
	Vector2i(540, 960), Vector2i(1080, 2340), Vector2i(320, 568), Vector2i(390, 844),
	Vector2i(360, 800)]
## A36 punch-hole: 92 px fiziksel / 1.5 = 61 tuval px (M8.6-02 cihaz kapısı).
const A36_SAFE_TOP: float = 61.0
const RUNTIME_FILES: Array[String] = [
	"res://scripts/ui/collection_screen.gd", "res://scripts/ui/collection_skin_card.gd",
	"res://scripts/ui/collectible_stage.gd", "res://scenes/ui/collection_screen.tscn",
	"res://scripts/main.gd",
]
const FORBIDDEN: Array[String] = ["_visual_source", "layerlab_spike", "layerlab_casual_game", "unitypackage"]
## Koleksiyon satın ALMAZ, Hamur'a dokunmaz, parça vermez, kaydı elle yazmaz;
## TASK/044: takma yolu / eski gameplay skin katmanı yok.
const FORBIDDEN_CALLS: Array[String] = ["purchase", "spend_dough", "add_dough", "grant_skin",
	"data[", "save_game(", "unlocked_skins", "Shop.", "equip_skin", "equipped_skin", "SkinVisual",
	"\"TAKILI\"", "\"TAK\""]
const LEGACY_PARTS: Array[String] = ["UiPalette", "StyleBoxFlat", "UiType.", "CandyButton", "tab_bar"]
## Kanonik katalog (GAME_DESIGN §5.6): sıra + rarity.
const EXPECTED_NAMES: Array[String] = ["Sade", "Susamlı", "Kepekli", "Havuçlu", "Yeşil Soğan",
	"Mısır", "Peynirli", "Sarımsaklı", "Karabiber", "Kırmızı Biber", "Mantar", "Ispanak",
	"Deniz Tuzu", "Zencefil", "Acı Sos", "Yosun", "Kakao", "Safran", "Altın Hamur", "Gökkuşağı"]
const EXPECTED_RARITY_COUNTS: Dictionary = {
	SkinData.Rarity.COMMON: 8, SkinData.Rarity.RARE: 6,
	SkinData.Rarity.EPIC: 4, SkinData.Rarity.LEGENDARY: 2,
}
## card_bevel_soft'un pişmiş alt dudağı (kart dikdörtgeninin altından).
const CARD_LIP: float = 11.0

var _fails: int = 0
var _checks: int = 0
var _saved: Dictionary = {}
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _main: Node2D
var _finished: bool = false
var _showcase_signals: int = 0
var _granted_signals: int = 0
var _shop_requests: int = 0


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	# Otomatik GÜNLÜK ÖDÜLLER penceresi (M8.9-02) bu harness'in konusu değil.
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_saved = SaveManager.data.duplicate(true)
	var save_path: String = SaveManager.SAVE_PATH
	_had_save = FileAccess.file_exists(save_path)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(save_path)
	# Günlük ödül bugün alınmış gibi: main._ready kayda yazmasın.
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	# M8.10: bu harness KABUGU olcuyor — onboarding tamamlanmis olmali.
	SaveManager.data["onboarding_completed"] = true
	_apply_mid()
	get_tree().create_timer(180.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 180 s'de bitmedi — kayıt geri kondu")
			SaveManager.data = _saved
			_restore_save_file()
			get_tree().quit(2))
	SaveManager.showcase_changed.connect(func(_ids: Array) -> void: _showcase_signals += 1)
	SaveManager.skin_granted.connect(func(_id: StringName) -> void: _granted_signals += 1)

	get_window().size = Vector2i(720, 1000)
	await get_tree().process_frame
	await _resize(VIEWS[0])
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	var screen: CanvasLayer = _main._screens[2]
	var shop: CanvasLayer = _main._screens[3]
	var home: CanvasLayer = _main._screens[0]
	var theme: Theme = ThemeDB.get_project_theme()
	screen.shop_requested.connect(func() -> void: _shop_requests += 1)
	screen.shop_skin_requested.connect(func(_id: StringName) -> void: _shop_requests += 1)

	print("-- tema / kaynak hijyeni")
	_c("PanelCollectionCard / PanelCollectionCardLocked variation'ları var (card_bevel_soft krem / buzlu)",
		theme.get_type_list().has(&"PanelCollectionCard") and theme.get_type_list().has(&"PanelCollectionCardLocked")
		and (theme.get_stylebox("panel", &"PanelCollectionCard") as StyleBoxTexture).modulate_color.is_equal_approx(UiTokens.CREAM)
		and (theme.get_stylebox("panel", &"PanelCollectionCard") as StyleBoxTexture).texture.resource_path.contains("card_bevel_soft"))
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/collection_screen.gd")
	var card_src: String = FileAccess.get_file_as_string("res://scripts/ui/collection_skin_card.gd")
	var stage_src: String = FileAccess.get_file_as_string("res://scripts/ui/collectible_stage.gd")
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var clean: bool = true
	for path in RUNTIME_FILES:
		var text: String = FileAccess.get_file_as_string(path)
		for word in FORBIDDEN:
			if text.contains(word):
				clean = false
	_c("çalışma zamanı dosyalarında ham kaynak / spike referansı yok", clean)
	var no_purchase: bool = true
	for word in FORBIDDEN_CALLS:
		if src.contains(word) or card_src.contains(word) or stage_src.contains(word):
			no_purchase = false
			print("    yasak çağrı: ", word)
	_c("Koleksiyon satın ALMAZ / Hamur'a dokunmaz / parça vermez / kaydı elle yazmaz / takma yolu yok (kaynak taraması)", no_purchase)
	var no_legacy: bool = true
	for word in LEGACY_PARTS:
		if src.contains(word) or card_src.contains(word):
			no_legacy = false
			print("    eski parça: ", word)
	_c("eski M8.5 parçası yok (UiPalette / StyleBoxFlat / UiType / CandyButton / tab_bar)", no_legacy)
	_c("vitrin yazmaları yalnız kanonik SaveManager işlemleriyle, yalnız detay eylemlerinden (kart / sahne yazmaz)",
		src.count("SaveManager.showcase_add(") == 1 and src.count("SaveManager.showcase_remove(") == 1
		and src.count("SaveManager.showcase_replace(") == 1 and src.count("SaveManager.showcase_make_first(") == 1
		and not card_src.contains("showcase_add") and not card_src.contains("SaveManager.")
		and not stage_src.contains("SaveManager."))
	_c("alt sekme çubuğu main'den tamamen kalktı (_tabs / tab_bar.tscn yok; TabBar düğümü yok)",
		not main_src.contains("_tabs") and not main_src.contains("tab_bar.tscn")
		and _main.get_node_or_null("TabBar") == null and not ("_tabs" in _main))
	_c("rarity iç adı İngilizce kaldı (variation kimliği), görüntü adı Türkçe",
		SkinData.rarity_name(SkinData.Rarity.LEGENDARY) == "Legendary"
		and SkinData.rarity_display_upper(SkinData.Rarity.LEGENDARY) == "EFSANEVİ"
		and SkinData.rarity_display_name(SkinData.Rarity.RARE) == "Nadir"
		and SkinData.rarity_display_upper(SkinData.Rarity.RARE) == "NADİR"
		and SkinData.rarity_display_upper(SkinData.Rarity.EPIC) == "EPİK"
		and SkinData.rarity_display_upper(SkinData.Rarity.COMMON) == "YAYGIN")
	var tag_probe: PanelContainer = UiKit.rarity_tag(SkinData.Rarity.RARE)
	_c("UiKit.rarity_tag yazısı Türkçe (NADİR), variation RarityRare (Mağaza ile ortak)",
		(tag_probe.get_meta(&"title_label") as Label).text == "NADİR" and tag_probe.theme_type_variation == &"RarityRare")
	tag_probe.free()

	print("-- yapı")
	_main._show_tab(2)
	await get_tree().process_frame
	await get_tree().process_frame
	var bar: ScreenTopBar = screen.top_bar()
	_c("TASK/057 Tur 2: üst satır ScreenTopBar, sol üstte geri oku yok (back_button() null), Hamur PanelHomePill", bar != null
		and bar.back_button() == null
		and (bar.pill().get_meta(&"pill") as PanelContainer).theme_type_variation == &"PanelHomePill")
	_c("TASK/057 Tur 2: Koleksiyon kaynağında geri oku yok (home_requested / back_button() yok), ScreenTopBar'da back_pressed yok",
		not FileAccess.get_file_as_string("res://scripts/ui/collection_screen.gd").contains("home_requested")
		and not FileAccess.get_file_as_string("res://scripts/ui/collection_screen.gd").contains("back_button()")
		and not FileAccess.get_file_as_string("res://scripts/ui/screen_top_bar.gd").contains("back_pressed"))
	_c("başlık 'KOLEKSİYON' (noktalı İ) pembe HeaderRibbon", bar.title_text() == "KOLEKSİYON"
		and bar.title_plate().theme_type_variation == &"HeaderRibbon")
	_c("Hamur pill'inde nane '+' VAR (→ Mağaza; kilitli parçaların alınacağı yer)", bar.add_button() != null
		and bar.add_button().theme_type_variation == &"ButtonHomeAdd" and _count_variation(screen, &"ButtonHomeAdd") == 1)
	_c("Hamur pill'i bakiyeyi gösteriyor (335)", _pill_text(bar) == "335")
	_c("Koleksiyon'da sekme çubuğu YOK, eski tab_bar sahnesi yok", screen.get_node_or_null("TabBar") == null
		and not ResourceLoader.exists("res://scenes/ui/tab_bar.tscn"))
	_c("gerçek ScrollContainer albüm (yatay kapalı, dikey açık, çubuk gizli, kırpma açık)", screen.scroll() != null
		and screen.scroll().horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
		and screen.scroll().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER
		and screen.scroll().clip_contents)
	_c("sabit albüm başlığı (AlbumHeader) albümün DIŞINDA, detay kapalı", screen.header() != null and screen.header().visible
		and not screen.scroll().is_ancestor_of(screen.header()) and not screen.is_detail_open())
	var headers: Array[Control] = screen.section_headers()
	var header_ok: bool = headers.size() == 4
	var expected_headers: Array[String] = ["YAYGIN", "NADİR", "EPİK", "EFSANEVİ"]
	for i in mini(headers.size(), 4):
		if (headers[i].get_meta(&"title_label") as Label).text != expected_headers[i]:
			header_ok = false
	_c("dört rarity bölüm plakası sırayla YAYGIN / NADİR / EPİK / EFSANEVİ (PanelShopSection ailesi)", header_ok
		and (headers[0].get_meta(&"plate") as PanelContainer).theme_type_variation == &"PanelShopSection")
	_c("eski parça yok: CandyButton 0, koyu CardPanel 0", _count_class(screen, "CandyButton") == 0
		and _count_variation(screen, &"CardPanel") == 0 and _count_variation(screen, &"QuietCardPanel") == 0)
	_c("tam 20 albüm kartı (CollectionSkinCard) — TASK/044: 'Varsayılan' kartı YOK", screen.cards().size() == 20
		and _count_class(screen, "CollectionSkinCard") == 20 and screen.card(&"") == null)
	_c("eski seçim / vitrin paneli API'si yok (select / selected_id / cta / showcase_name_text)",
		not screen.has_method("select") and not screen.has_method("selected_id") and not screen.has_method("cta")
		and not screen.has_method("showcase_name_text") and screen.get_node_or_null("Root/Showcase") == null)
	var no_card_process: bool = true
	var cards_pass: bool = true
	for card in screen.cards():
		if card.is_processing() or card.is_physics_processing():
			no_card_process = false
		if card.mouse_filter != Control.MOUSE_FILTER_PASS:
			cards_pass = false
	_c("kartlarda _process yok; yalnız ekran işler (görünürken)", no_card_process and screen.is_processing())
	_c("kartlar MOUSE_FILTER_PASS (basış karta işlenir VE ScrollContainer sürüklemeyi başlatabilir)", cards_pass)
	_main._show_tab(0)
	_c("ekran gizliyken işlem durur", not screen.is_processing())
	_main._show_tab(2)
	await get_tree().process_frame
	print("    düğüm sayısı (Koleksiyon ekranı): ", _count_nodes(screen))

	print("-- katalog")
	_c("SkinLibrary tam 20 parça", SkinLibrary.total_count() == 20 and SkinLibrary.all().size() == 20)
	var counts: Dictionary = {}
	for skin in SkinLibrary.all():
		counts[skin.rarity] = int(counts.get(skin.rarity, 0)) + 1
	_c("rarity sayıları 8 / 6 / 4 / 2", counts.get(SkinData.Rarity.COMMON, 0) == 8 and counts.get(SkinData.Rarity.RARE, 0) == 6
		and counts.get(SkinData.Rarity.EPIC, 0) == 4 and counts.get(SkinData.Rarity.LEGENDARY, 0) == 2)
	var cards: Array[CollectionSkinCard] = screen.cards()
	var entries: Array[SkinEntry] = SkinEntry.all(false)
	var order_ok: bool = cards.size() == entries.size()
	for i in mini(cards.size(), entries.size()):
		if cards[i].skin_id() != entries[i].id:
			order_ok = false
	var names_ok: bool = true
	for i in EXPECTED_NAMES.size():
		if cards[i].name_text() != EXPECTED_NAMES[i]:
			names_ok = false
			print("    ad uyumsuz: ", cards[i].name_text(), " / ", EXPECTED_NAMES[i])
	_c("kart sırası katalog sırası (rarity + id); 20 ad kanonik sırada, Sade ilk", order_ok and names_ok
		and cards[0].skin_id() == &"common_01")
	var grid_ok: bool = true
	var in_sections: int = 0
	for rarity in EXPECTED_RARITY_COUNTS:
		var section: VBoxContainer = screen._content.get_node_or_null("Grid_%s" % SkinData.rarity_name(rarity))
		var expect: int = int(EXPECTED_RARITY_COUNTS[rarity])
		var n: int = 0
		if section != null:
			for row in section.get_children():
				if row.get_child_count() > 3 or (row as HBoxContainer).alignment != BoxContainer.ALIGNMENT_CENTER:
					grid_ok = false
				n += row.get_child_count()
		if section == null or n != expect or section.get_child_count() != ceili(float(expect) / 3.0):
			grid_ok = false
		in_sections += n
	_c("bölüm sıraları 3 sütun, ortalı (YAYGIN 3+3+2 / EPİK 3+1 / EFSANEVİ 2 ortada); tam 8 / 6 / 4 / 2 kart",
		grid_ok and in_sections == 20)
	var art_ok: bool = true
	var seen: Dictionary = {}
	for card in cards:
		var tex: Texture2D = card.swatch()._image.texture
		var entry: SkinEntry = SkinEntry.find(card.skin_id())
		if tex == null or tex != entry.preview_texture() or tex == SkinSwatch.LOCKED_TEXTURE:
			art_ok = false
			print("    sanat yanlış: ", card.skin_id())
		var path: String = tex.resource_path if tex != null else ""
		if path.is_empty() or not path.contains("assets/visual/skins/previews/") or seen.has(path):
			art_ok = false
		seen[path] = true
	_c("20 kartın hepsi GERÇEK final sanat: 20 farklı önizleme dokusu, silüet yok, kilitli dahil", art_ok and seen.size() == 20)

	print("-- başlık (orta oyuncu: 4/20, vitrin rare_02)")
	_c("KOLEKSİYON 4/20 (SkinEntry.owned_count ile aynı), nane ray, yıldız gizli", screen.header_count_text() == "4/20"
		and SkinEntry.owned_count() == 4 and is_equal_approx(screen.header_bar().value, 0.2)
		and screen.header_bar().theme_type_variation == &"ProgressBarMint" and not screen._header_star.visible)
	_c("altın VİTRİN çipi 1/3", screen.showcase_chip_text() == "VİTRİN 1/3")
	_c("rarity sayaçları YAYGIN 2/8 · NADİR 1/6 · EPİK 1/4 · EFSANEVİ 0/2",
		screen.rarity_chip_text(SkinData.Rarity.COMMON) == "YAYGIN 2/8"
		and screen.rarity_chip_text(SkinData.Rarity.RARE) == "NADİR 1/6"
		and screen.rarity_chip_text(SkinData.Rarity.EPIC) == "EPİK 1/4"
		and screen.rarity_chip_text(SkinData.Rarity.LEGENDARY) == "EFSANEVİ 0/2")
	_c("kart durumları: rare_02 VİTRİNDE (altın plaka), common_01 SAHİP (plaka yok), common_03 KİLİTLİ",
		screen.card(&"rare_02").is_showcased() and screen.card(&"rare_02").showcase_plate().visible
		and screen.card(&"common_01").is_owned() and not screen.card(&"common_01").is_showcased()
		and not screen.card(&"common_01").showcase_plate().visible
		and not screen.card(&"common_03").is_owned() and screen.card(&"common_03").swatch()._lock.visible)
	var plate_text: String = _collect_text(screen.card(&"rare_02"))
	_c("VİTRİNDE plakası metni; hiçbir kartta TAKILI yok", plate_text.contains("VİTRİNDE")
		and not _collect_text(screen).contains("TAKILI"))

	print("-- detay: aç / kapat (kayıt değişmez)")
	var file_before: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	var signals_before: int = _showcase_signals
	screen.card(&"common_03").pressed.emit()
	await get_tree().process_frame
	_c("karta dokunmak detayı açar (Kepekli)", screen.is_detail_open() and screen.detail_id() == &"common_03"
		and screen.detail_name_text() == "Kepekli")
	_c("kilitli detay: KOLEKSİYON PARÇASI · YAYGIN · KİLİTLİ · '50 Hamur' notu · MAĞAZAYA GİT (tek eylem)",
		(screen._detail_kicker as Label).text == "KOLEKSİYON PARÇASI" and screen.detail_rarity_text() == "YAYGIN"
		and screen.detail_state_text() == "KİLİTLİ" and screen.detail_note_text().contains("50 Hamur")
		and screen.detail_primary_text() == "MAĞAZAYA GİT" and screen.detail_secondary_text() == ""
		and screen.detail_primary().theme_type_variation == &"ButtonPrimary")
	_c("kilitli detay sahnesi: FINAL sanat + kilit (silüet yok), büyük sanat ≥ 200 px",
		screen.detail_stage().swatch()._image.texture == SkinLibrary.find(&"common_03").preview_texture
		and screen.detail_stage().swatch()._lock.visible and screen.detail_stage().art_box().size.x >= 200.0)
	_c("detay açmak kayda YAZMADI, vitrin sinyali yok", FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == file_before
		and _showcase_signals == signals_before)
	_c("detayda equip / TAK dili yok", not _collect_text(screen.detail_frame()).contains("TAK")
		and not _collect_text(screen.detail_frame()).to_lower().contains("takıl"))
	(screen.detail_frame().get_meta(&"close_button") as Button).pressed.emit()
	await get_tree().process_frame
	_c("X detayı kapatır", not screen.is_detail_open() and screen.detail_id() == &"")
	screen.card(&"rare_01").pressed.emit()
	await get_tree().create_timer(0.3).timeout
	_c("kilitli Rare sahnesi: NADİR, mavi hale (RARITY_RARE), mavi kaide halkası + mavimsi kaide, bloom yok, 150 Hamur",
		screen.detail_rarity_text() == "NADİR"
		and screen.detail_stage().halo().self_modulate.is_equal_approx(Color(UiTokens.RARITY_RARE, CollectibleStage.HALO_ALPHA[SkinData.Rarity.RARE]))
		and _stage_rim(screen).is_equal_approx(UiTokens.RARITY_RARE.lerp(Color.WHITE, 0.3))
		and screen.detail_stage().pedestal().self_modulate.is_equal_approx(UiTokens.TRAY_CREAM.lerp(UiTokens.RARITY_RARE, CollectibleStage.PEDESTAL_TINT))
		and not screen.detail_stage().bloom().visible and screen.detail_note_text().contains("150 Hamur"))
	screen._detail_dim.gui_input.emit(_release_event())
	await get_tree().process_frame
	_c("karartmaya dokunmak detayı kapatır", not screen.is_detail_open())
	screen.card(&"legendary_01").pressed.emit()
	await get_tree().create_timer(0.3).timeout
	_c("kilitli Legendary (Altın Hamur): EFSANEVİ, altın hale + bloom + altın kaide halkası, 900 Hamur, MAĞAZAYA GİT",
		screen.detail_rarity_text() == "EFSANEVİ" and screen.detail_stage().bloom().visible
		and screen.detail_stage().halo().self_modulate.is_equal_approx(Color(UiTokens.GOLD, CollectibleStage.HALO_ALPHA[SkinData.Rarity.LEGENDARY]))
		and _stage_rim(screen) == UiTokens.GOLD and screen.detail_note_text().contains("900 Hamur")
		and screen.detail_primary_text() == "MAĞAZAYA GİT")
	_main._last_back_msec = -1000
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("Android geri: önce detay kapanır, Koleksiyon'da kalınır", not screen.is_detail_open() and _main._active_tab == 2
		and screen.visible)
	screen.card(&"epic_01").pressed.emit()
	await get_tree().create_timer(0.3).timeout
	_c("sahip Epic (Acı Sos): EPİK · SAHİPSİN · VİTRİNE EKLE (cyan) · not '3 Squishy', mor hale + mor kaide halkası",
		screen.detail_name_text() == "Acı Sos" and screen.detail_rarity_text() == "EPİK"
		and screen.detail_state_text() == "SAHİPSİN" and screen.detail_primary_text() == "VİTRİNE EKLE"
		and screen.detail_primary().theme_type_variation == &"ButtonPrimary" and screen.detail_secondary_text() == ""
		and screen.detail_note_text().contains("en fazla 3 Squishy")
		and screen.detail_stage().halo().self_modulate.is_equal_approx(Color(UiTokens.RARITY_EPIC, CollectibleStage.HALO_ALPHA[SkinData.Rarity.EPIC]))
		and _stage_rim(screen).is_equal_approx(UiTokens.RARITY_EPIC.lerp(Color.WHITE, 0.3))
		and not screen.detail_stage().swatch()._lock.visible)
	screen.card(&"rare_02").pressed.emit()
	await get_tree().process_frame
	_c("vitrin başı (rare_02, avatar): VİTRİNDE · avatar notu · tek eylem VİTRİNDEN ÇIKAR (lavanta ikincil)",
		screen.detail_id() == &"rare_02" and screen.detail_state_text() == "VİTRİNDE"
		and screen.detail_note_text() == screen.NOTE_AVATAR and screen.detail_primary_text() == "VİTRİNDEN ÇIKAR"
		and screen.detail_primary().theme_type_variation == &"ButtonSecondary" and screen.detail_secondary_text() == "")
	_c("detay açıkken başka karta geçiş de kayda yazmadı", FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == file_before
		and _showcase_signals == signals_before)
	screen.close_detail(false)

	print("-- vitrin eylemleri (kanonik SaveManager işlemleri)")
	var dough_before: int = SaveManager.dough()
	var owned_before: Array = (SaveManager.data["unlocked_skins"] as Array).duplicate()
	var granted_before: int = _granted_signals
	screen.card(&"epic_01").pressed.emit()
	await get_tree().process_frame
	signals_before = _showcase_signals
	screen.detail_primary().pressed.emit()
	await get_tree().process_frame
	var save_now: Dictionary = _read_save_file()
	_c("VİTRİNE EKLE → vitrin [rare_02, epic_01] (sona eklendi), tam BİR showcase_changed, kayıtta aynı",
		_showcase_is([&"rare_02", &"epic_01"]) and _showcase_signals == signals_before + 1
		and save_now.get("profile_showcase", []) == ["rare_02", "epic_01"])
	_c("VİTRİNE EKLE → Hamur, sahiplik, sayaç değişmedi; grant yok; eski equipped_skin anahtarı yazılmadı",
		SaveManager.dough() == dough_before and SaveManager.data["unlocked_skins"] == owned_before
		and _granted_signals == granted_before and int(save_now.get("dough", -1)) == dough_before
		and not save_now.has("equipped_skin"))
	_c("detay güncellendi: VİTRİNDE · '2. yuva' · AVATAR YAP (cyan) + VİTRİNDEN ÇIKAR (lavanta)",
		screen.detail_state_text() == "VİTRİNDE" and screen.detail_note_text().contains("2. yuva")
		and screen.detail_primary_text() == "AVATAR YAP" and screen.detail_primary().theme_type_variation == &"ButtonPrimary"
		and screen.detail_secondary_text() == "VİTRİNDEN ÇIKAR" and screen.detail_secondary().theme_type_variation == &"ButtonSecondary")
	_c("kart + başlık güncellendi: epic_01 VİTRİNDE plakası, VİTRİN 2/3", screen.card(&"epic_01").is_showcased()
		and screen.card(&"epic_01").showcase_plate().visible and screen.showcase_chip_text() == "VİTRİN 2/3")
	await _wait_action_lock()
	signals_before = _showcase_signals
	screen.detail_primary().pressed.emit()
	await get_tree().process_frame
	_c("AVATAR YAP → epic_01 ilk yuvada [epic_01, rare_02], diğerinin sırası korunur, BİR sinyal",
		_showcase_is([&"epic_01", &"rare_02"]) and _showcase_signals == signals_before + 1
		and _read_save_file().get("profile_showcase", []) == ["epic_01", "rare_02"])
	_c("avatar olunca detay: avatar notu, tek eylem VİTRİNDEN ÇIKAR", screen.detail_note_text() == screen.NOTE_AVATAR
		and screen.detail_primary_text() == "VİTRİNDEN ÇIKAR" and screen.detail_secondary_text() == "")
	await _wait_action_lock()
	signals_before = _showcase_signals
	screen.detail_primary().pressed.emit()
	await get_tree().process_frame
	_c("VİTRİNDEN ÇIKAR → [rare_02] (sonraki öne kayar, rare_02 avatar), BİR sinyal; parça hâlâ sahip",
		_showcase_is([&"rare_02"]) and _showcase_signals == signals_before + 1 and SaveManager.owns_skin(&"epic_01"))
	_c("çıkınca detay SAHİPSİN + VİTRİNE EKLE; kart plakası gizlendi", screen.detail_state_text() == "SAHİPSİN"
		and screen.detail_primary_text() == "VİTRİNE EKLE" and not screen.card(&"epic_01").showcase_plate().visible)
	# İnceleme (TASK/044 merceği 5): birincil buton her yazmadan sonra anlam
	# değiştirir — hızlı çift dokunuşun ikinci yarısı kilitte kalmalı.
	await _wait_action_lock()
	signals_before = _showcase_signals
	screen.detail_primary().pressed.emit()
	screen.detail_primary().pressed.emit()
	screen.detail_secondary().pressed.emit()
	await get_tree().process_frame
	_c("çift dokunuş: yalnız İLK eylem (VİTRİNE EKLE) yazıldı; ikinci dokunuş AVATAR YAP / VİTRİNDEN ÇIKAR tetiklemedi",
		_showcase_is([&"rare_02", &"epic_01"]) and _showcase_signals == signals_before + 1
		and screen.detail_primary_text() == "AVATAR YAP")
	await _wait_action_lock()
	# Dolu vitrin: rare_02, epic_01, common_01 → common_02 eklenmek istenir.
	SaveManager.showcase_add(&"epic_01")
	SaveManager.showcase_add(&"common_01")
	screen.close_detail(false)
	screen.card(&"common_02").pressed.emit()
	await get_tree().process_frame
	_c("vitrin dolu (3/3): sahip Susamlı detayı 'Vitrinin dolu (3/3)' notu + VİTRİNE EKLE, başlık VİTRİN 3/3",
		screen.detail_note_text().begins_with("Vitrinin dolu (3/3)") and screen.detail_primary_text() == "VİTRİNE EKLE"
		and screen.showcase_chip_text() == "VİTRİN 3/3")
	file_before = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	signals_before = _showcase_signals
	screen.detail_primary().pressed.emit()
	await get_tree().process_frame
	var tiles: Array[Button] = screen.replace_tiles()
	_c("dolu vitrinde VİTRİNE EKLE → AÇIK değiştirme adımı (sessiz / rastgele değiştirme YOK): kayıt ve vitrin aynı",
		screen.is_replacing() and _showcase_is([&"rare_02", &"epic_01", &"common_01"])
		and _showcase_signals == signals_before and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == file_before)
	_c("değiştirme adımı: 'VİTRİN DOLU · 3/3' + soru notu, 3 yuva kutusu yuva sırasıyla (AVATAR / 2. YUVA / 3. YUVA)",
		(screen._detail_kicker as Label).text == "VİTRİN DOLU · 3/3" and screen.detail_note_text() == screen.REPLACE_NOTE
		and tiles.size() == 3 and tiles[0].visible and tiles[1].visible and tiles[2].visible
		and (tiles[0].get_meta(&"name_label") as Label).text == "Kırmızı Biber"
		and (tiles[1].get_meta(&"name_label") as Label).text == "Acı Sos"
		and (tiles[2].get_meta(&"name_label") as Label).text == "Sade"
		and _collect_text(tiles[0]).contains("AVATAR") and _collect_text(tiles[1]).contains("2. YUVA")
		and _collect_text(tiles[2]).contains("3. YUVA"))
	_c("değiştirme adımında tek eylem VAZGEÇ; yuva kutuları ≥ 48 px dokunma", not screen.detail_primary().visible
		and screen.detail_secondary_text() == "VAZGEÇ" and tiles[0].size.y >= 48.0 and tiles[0].size.x >= 48.0)
	tiles[0].pressed.emit()
	await get_tree().process_frame
	_c("adım açılır açılmaz gelen dokunuş (çift dokunuşun ikinci yarısı) yuva kutusunu SEÇMEDİ — kayıt aynı",
		screen.is_replacing() and _showcase_is([&"rare_02", &"epic_01", &"common_01"]) and _showcase_signals == signals_before
		and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == file_before)
	await _wait_action_lock()
	screen.detail_secondary().pressed.emit()
	await get_tree().process_frame
	_c("VAZGEÇ → değiştirme adımı kapanır, detay açık kalır; hiçbir şey yazılmadı", not screen.is_replacing()
		and screen.is_detail_open() and screen.detail_primary_text() == "VİTRİNE EKLE"
		and _showcase_is([&"rare_02", &"epic_01", &"common_01"]) and _showcase_signals == signals_before
		and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == file_before)
	await _wait_action_lock()
	screen.detail_primary().pressed.emit()
	await get_tree().process_frame
	_main._last_back_msec = -1000
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("değiştirme adımında Android geri → yalnız adım kapanır (detay açık), hiçbir şey yazılmadı",
		not screen.is_replacing() and screen.is_detail_open() and _main._active_tab == 2
		and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == file_before and _showcase_signals == signals_before)
	await _wait_action_lock()
	screen.detail_primary().pressed.emit()
	await get_tree().process_frame
	await _wait_action_lock()
	tiles[1].pressed.emit()
	await get_tree().process_frame
	_c("yuva seçildi (2. YUVA: Acı Sos) → Susamlı O yuvaya girer [rare_02, common_02, common_01], BİR sinyal, kayıtta aynı",
		_showcase_is([&"rare_02", &"common_02", &"common_01"]) and _showcase_signals == signals_before + 1
		and _read_save_file().get("profile_showcase", []) == ["rare_02", "common_02", "common_01"])
	_c("değiştirme sonrası detay VİTRİNDE '2. yuva'; Acı Sos kartında plaka yok, Susamlı kartında var",
		not screen.is_replacing() and screen.detail_state_text() == "VİTRİNDE"
		and screen.detail_note_text().contains("2. yuva")
		and not screen.card(&"epic_01").showcase_plate().visible and screen.card(&"common_02").showcase_plate().visible)
	_c("değiştirme de Hamur / sahiplik değiştirmedi", SaveManager.dough() == dough_before
		and SaveManager.data["unlocked_skins"] == owned_before)
	screen.close_detail(false)

	print("-- kilitli: MAĞAZAYA GİT, satın alma yok")
	_apply_mid()
	screen.refresh()
	await get_tree().process_frame
	screen.card(&"legendary_02").pressed.emit()
	await get_tree().process_frame
	file_before = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	var requests_before: int = _shop_requests
	screen.detail_primary().pressed.emit()
	await get_tree().process_frame
	_c("kilitli Gökkuşağı MAĞAZAYA GİT → shop_skin_requested → Mağaza (tek örnek), detay kapandı, Koleksiyon gizli",
		_shop_requests == requests_before + 1 and _main._active_tab == 3 and shop.visible and not screen.visible
		and not screen.is_detail_open() and _count_class(_main, "ShopPowerCard") == 4
		and _count_class(_main, "CollectionSkinCard") == 20)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var landed: Rect2 = shop.skin_card(&"legendary_02").get_global_rect()
	var max_scroll: float = shop.scroll().get_v_scroll_bar().max_value - shop.scroll().size.y
	_c("Mağaza hedef parça kartına kaydırdı (Gökkuşağı ekranda, kaydırma sonunda; GÜÇLER'de değil)",
		shop.scroll().scroll_vertical >= int(max_scroll) - 1 and landed.position.y >= shop.top_bar().height()
		and landed.end.y <= 1280.0 and shop.power_cards()[0].get_global_rect().end.y < 0.0)
	_c("kilitli CTA hiçbir şey almadı / yazmadı; vitrin aynı", not SaveManager.owns_skin(&"legendary_02")
		and SaveManager.dough() == 335 and _showcase_is([&"rare_02"])
		and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == file_before)
	# Mağazadan satın alma Koleksiyon GİZLİYKEN → açılışta yeni parça albümde öne alınır.
	SaveManager.data["dough"] = 2000
	shop.refresh()
	shop._open_confirm(SkinLibrary.find(&"legendary_02"))
	await get_tree().process_frame
	shop._confirm_yes.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_c("Mağaza satın aldı (tek transaction): sahip, 1100 Hamur, vitrine OTOMATİK eklenmedi", SaveManager.owns_skin(&"legendary_02")
		and SaveManager.dough() == 1100 and _showcase_is([&"rare_02"]))
	_main._show_tab(2)
	await get_tree().process_frame
	await get_tree().process_frame
	var legend_rect: Rect2 = screen.card(&"legendary_02").get_global_rect()
	_c("Koleksiyon'a dönünce yeni parça albümde öne alındı (kart ekranda, sahip), 5/20, detay kapalı",
		screen.card(&"legendary_02").is_owned() and screen.header_count_text() == "5/20" and not screen.is_detail_open()
		and screen.scroll().scroll_vertical > 0 and legend_rect.position.y >= screen.scroll().global_position.y - 1.0
		and legend_rect.end.y <= get_viewport().get_visible_rect().size.y)
	# Ekran görünürken grant (sandık) → anında kart + başlık; açık detay güncellenir.
	screen.card(&"rare_05").pressed.emit()
	await get_tree().process_frame
	_c("ön koşul: rare_05 detayı KİLİTLİ", screen.detail_state_text() == "KİLİTLİ")
	SaveManager.grant_skin(&"rare_05")
	await get_tree().process_frame
	_c("görünürken kazanılan parça (rare_05): kart sahip, 6/20, açık detay SAHİPSİN + VİTRİNE EKLE",
		screen.card(&"rare_05").is_owned() and screen.header_count_text() == "6/20" and screen.is_detail_open()
		and screen.detail_state_text() == "SAHİPSİN" and screen.detail_primary_text() == "VİTRİNE EKLE")
	screen.close_detail(false)

	print("-- ilerleme")
	_apply_fresh()
	screen.refresh()
	await get_tree().process_frame
	var no_plate: bool = true
	for card in cards:
		if card.is_owned() or card.showcase_plate().visible or not card.swatch()._lock.visible:
			no_plate = false
	_c("yeni oyuncu: 0/20, VİTRİN 0/3, sayaçlar 0/N, hiçbir kart sahip / vitrinde değil, 0 Hamur", screen.header_count_text() == "0/20"
		and screen.showcase_chip_text() == "VİTRİN 0/3" and SkinEntry.owned_count() == 0
		and is_zero_approx(screen.header_bar().value) and screen.rarity_chip_text(SkinData.Rarity.COMMON) == "YAYGIN 0/8"
		and no_plate and _pill_text(bar) == "0")
	screen.card(&"common_01").pressed.emit()
	await get_tree().process_frame
	_c("yeni oyuncuda Sade de kilitli parça (50 Hamur, MAĞAZAYA GİT)", screen.detail_state_text() == "KİLİTLİ"
		and screen.detail_note_text().contains("50 Hamur") and screen.detail_primary_text() == "MAĞAZAYA GİT")
	screen.close_detail(false)
	_apply_full()
	screen.refresh()
	await get_tree().process_frame
	_c("20/20: altın ray + yıldız + altın sayı, tam dolu; sayaçlar tam; ödül verilmedi (Hamur aynı)",
		screen.header_count_text() == "20/20" and is_equal_approx(screen.header_bar().value, 1.0)
		and screen.header_bar().theme_type_variation == &"ProgressBarGold" and screen._header_star.visible
		and screen.rarity_chip_text(SkinData.Rarity.LEGENDARY) == "EFSANEVİ 2/2" and SaveManager.dough() == 1240
		and screen.showcase_chip_text() == "VİTRİN 3/3")
	var all_owned: bool = true
	for card in cards:
		if not card.is_owned() or card.swatch()._lock.visible:
			all_owned = false
	_c("20/20: hiçbir kartta kilit yok; vitrindeki 3 kartta VİTRİNDE", all_owned and _plates(screen) == 3)

	print("-- rarity işaretleri")
	_apply_mid()
	screen.refresh()
	await get_tree().process_frame
	_c("Common kart halkası açık lavanta, hale yok", screen.card(&"common_02").rim().self_modulate.is_equal_approx(UiTokens.LAVENDER_LIGHT)
		and not screen.card(&"common_02").halo().visible)
	_c("Rare kart halkası mavi (RARITY_RARE→beyaz %25)", screen.card(&"rare_01").rim().self_modulate.is_equal_approx(UiTokens.RARITY_RARE.lerp(Color.WHITE, 0.25)))
	_c("Epic kart halkası mor + hafif hale", screen.card(&"epic_02").rim().self_modulate.is_equal_approx(UiTokens.RARITY_EPIC.lerp(Color.WHITE, 0.22))
		and screen.card(&"epic_02").halo().visible)
	_c("Legendary kart: altın halka + altın hale + 4 pırıltı (yalnız Legendary'de) + altın-krem gövde", screen.card(&"legendary_01").rim().self_modulate == UiTokens.GOLD
		and screen.card(&"legendary_01").halo().visible and _sparkle_cards(screen) == 2
		and screen.card(&"legendary_01").sparkles().size() == 4 and screen.card(&"legendary_01").sparkles()[0].visible
		and not screen.card(&"epic_01").sparkles()[0].visible
		and screen.card(&"legendary_01").body().has_theme_stylebox_override("panel")
		and not screen.card(&"epic_01").body().has_theme_stylebox_override("panel"))
	_c("bölüm plakaları rarity tonlu (hepsi override; EFSANEVİ sıcak)",
		(headers[3].get_meta(&"plate") as PanelContainer).has_theme_stylebox_override("panel")
		and (headers[0].get_meta(&"plate") as PanelContainer).has_theme_stylebox_override("panel")
		and ((headers[3].get_meta(&"plate") as PanelContainer).get_theme_stylebox("panel") as StyleBoxTexture).modulate_color.r > 0.8)
	_c("kilitli kart gövdesi buzlu (PanelCollectionCardLocked), sahip olunan krem", screen.card(&"common_03").body().theme_type_variation == &"PanelCollectionCardLocked"
		and screen.card(&"common_01").body().theme_type_variation == &"PanelCollectionCard")
	_c("kilitli kartta kilit rozeti görünür, sahip olunanda yok; kartta fiyat metni YOK (detayda)", screen.card(&"common_03").swatch()._lock.visible
		and not screen.card(&"common_01").swatch()._lock.visible
		and not _collect_text(screen.card(&"common_03")).contains("Hamur"))

	print("-- rotalar")
	_main._show_tab(2)
	await get_tree().process_frame
	# TASK/057 Tur 2: üst çubukta geri oku yok — Ana Sayfa'ya dönüş küresel kabuğun ANA SAYFA öğesi.
	var nav_before: int = _main.nav_navigations
	_main.global_nav().item_button(0).pressed.emit()
	_c("kabuk ANA SAYFA → Ana Sayfa (tam 1 gezinme)", _main._active_tab == 0 and home.visible and not screen.visible
		and _main.nav_navigations == nav_before + 1)
	home.feature_button(&"collection").pressed.emit()
	_c("Home KOLEKSİYON madalyonu → Koleksiyon (tek örnek)", _main._active_tab == 2 and screen.visible
		and _count_class(_main, "CollectionSkinCard") == 20)
	_main._last_back_msec = -1000
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("Android geri (detay kapalı) → Ana Sayfa (çıkış yok: _exit_tree bekçisi SONUC'tan önce gelirse FAIL basar)", _main._active_tab == 0 and home.visible)
	_main._show_tab(2)
	bar.add_button().pressed.emit()
	_c("Hamur '+' → Mağaza", _main._active_tab == 3 and shop.visible and not screen.visible)
	_main._show_tab(2)
	await get_tree().process_frame
	screen.card(&"epic_01").pressed.emit()
	screen.scroll().scroll_vertical = 600
	await get_tree().process_frame
	_main._show_tab(0)
	_main._show_tab(2)
	await get_tree().process_frame
	_c("Koleksiyon'a her girişte kaydırma en üstte (600'den), açık detay kapanmış", screen.scroll().scroll_vertical == 0
		and not screen.is_detail_open())
	screen.card(&"epic_01").pressed.emit()
	await get_tree().process_frame
	_main._show_tab(2)
	await get_tree().process_frame
	_c("aynı sekmede tazeleme (günlük pencere kapanışı / Hamur yenilemesi) açık detayı KORUR (Profil → detay rotası)",
		screen.is_detail_open() and screen.detail_id() == &"epic_01")
	_main._show_tab(0)
	await get_tree().process_frame
	_c("sekmeden çıkınca detay kapanır", not screen.is_detail_open())
	_main._show_tab(2)
	await get_tree().process_frame
	_c("Home Koleksiyon madalyonu aynı sayıyı gösteriyor (4/20)", home.feature_button(&"collection").badge_text() == "4/20")
	# A36 cihaz kapısı (06.2): basış + bırakış AYNI karede (çok kısa dokunuş /
	# adb tap) → üst çubuk butonu ekran gizlenirken 0.94'te asılı kalıyordu. TASK/057 Tur 2: geri oku
	# yok — aynı sınama üst çubuğun kalan butonu "+" (→ Mağaza, Koleksiyon gizlenir) ile.
	var add: Button = bar.add_button()
	var add_center: Vector2 = add.get_global_rect().get_center()
	_send_click(add_center, true)
	_send_click(add_center, false)
	await get_tree().process_frame
	var went_shop: bool = _main._active_tab == 3 and not screen.visible
	await get_tree().create_timer(0.4).timeout
	_main._show_tab(2)
	await get_tree().create_timer(0.3).timeout
	await get_tree().process_frame
	_c("aynı karede basıp bırakılan '+' → Mağaza; Koleksiyon yeniden açılınca buton ölçeği 1.0 (0.94'te asılı değil)",
		went_shop and add.scale.is_equal_approx(Vector2.ONE))
	var first_card: CollectionSkinCard = screen.card(&"common_01")
	var card_center: Vector2 = first_card.get_global_rect().get_center()
	_send_click(card_center, true)
	_send_click(card_center, false)
	await get_tree().create_timer(0.4).timeout
	await get_tree().process_frame
	_c("aynı karede basıp bırakılan kart: detay açıldı, kart ölçeği 1.0", screen.is_detail_open()
		and screen.detail_id() == &"common_01" and first_card.scale.is_equal_approx(Vector2.ONE))
	screen.close_detail(false)

	print("-- yerleşim")
	_apply_mid()
	screen.refresh()
	for view in VIEWS:
		await _resize(view)
		_main._show_tab(0)
		_main._show_tab(2)
		await get_tree().process_frame
		await get_tree().process_frame
		await _check_layout(screen, 0.0, "%dx%d" % [view.x, view.y])
	await _resize(VIEWS[3])
	screen._layout_with_safe_top(A36_SAFE_TOP)
	await get_tree().process_frame
	await get_tree().process_frame
	await _check_layout(screen, A36_SAFE_TOP, "1080x2340")
	screen._layout_with_safe_top(-1.0)
	await _resize(VIEWS[0])

	print("-- kayıt")
	SaveManager.data = _saved
	_restore_save_file()
	var restored: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) if _had_save else PackedByteArray()
	_c("kayıt dosyası byte-identical geri kondu (%d bayt)" % _save_bytes.size(), restored == _save_bytes
		and FileAccess.file_exists(SaveManager.SAVE_PATH) == _had_save)

	_finished = true
	print("\nSONUC: %d kontrol, %d hata" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _exit_tree() -> void:
	if _finished:
		return
	print("  [FAIL] test SONUC'tan önce ağaçtan çıktı (uygulama kapandı / betik hatası) — kayıt geri kondu")
	SaveManager.data = _saved
	_restore_save_file()


# --- Yardımcılar --------------------------------------------------------------

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


## Detay eylem kilidi (CollectionScreen.ACTION_LOCK_MSEC) dolsun: art arda
## bilinçli eylemler gerçek oyuncu hızında.
func _wait_action_lock() -> void:
	await get_tree().create_timer(float(COLLECTION_SCRIPT.ACTION_LOCK_MSEC) / 1000.0 + 0.05).timeout


func _resize(view: Vector2i) -> void:
	get_window().size = view
	await get_tree().process_frame
	await get_tree().process_frame


## Kanonik vitrin (SaveManager.profile_showcase) beklenen id sırası mı.
func _showcase_is(ids: Array) -> bool:
	var got: Array[StringName] = SaveManager.profile_showcase()
	if got.size() != ids.size():
		return false
	for i in ids.size():
		if got[i] != StringName(ids[i]):
			return false
	return true


func _apply_mid() -> void:
	SaveManager.data["highest_level_unlocked"] = 4
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3}
	SaveManager.data["dough"] = 335
	SaveManager.data["unlocked_skins"] = ["common_01", "common_02", "rare_02", "epic_01"]
	SaveManager.data["profile_showcase"] = ["rare_02"]
	SaveManager.data["powerups"] = {"bomb": 3, "upgrade": 1, "shake": 0, "clear_small": 2}
	SaveManager.data["endless_high_score"] = 0
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()


func _apply_fresh() -> void:
	SaveManager.data["highest_level_unlocked"] = 1
	SaveManager.data["level_stars"] = {}
	SaveManager.data["dough"] = 0
	SaveManager.data["unlocked_skins"] = []
	SaveManager.data["profile_showcase"] = []
	SaveManager.data["powerups"] = {"bomb": 1, "upgrade": 1, "shake": 1, "clear_small": 1}
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()


func _apply_full() -> void:
	_apply_mid()
	var all: Array = []
	for skin in SkinLibrary.all():
		all.append(String(skin.id))
	SaveManager.data["unlocked_skins"] = all
	SaveManager.data["profile_showcase"] = ["legendary_02", "epic_03", "rare_02"]
	SaveManager.data["dough"] = 1240


func _pill_text(bar: ScreenTopBar) -> String:
	return (bar.pill().get_meta(&"value_label") as Label).text


func _stage_rim(screen: CanvasLayer) -> Color:
	return (screen.detail_stage().get_node("PedestalRim") as NinePatchRect).self_modulate


func _collect_text(node: Node) -> String:
	var out: String = ""
	for n in _all_nodes(node):
		if n is Label and (n as Label).is_visible_in_tree():
			out += (n as Label).text + "|"
	return out


func _plates(screen: CanvasLayer) -> int:
	var n: int = 0
	for card in screen.cards():
		if card.showcase_plate().visible:
			n += 1
	return n


## Karartmaya dokunuşun bırakılışı (UiKit.attach_dim_close bırakışta kapatır).
func _release_event() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	return ev


## Gerçek giriş olayı (BaseButton sırası: pressed → button_up), emit değil.
func _send_click(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)


func _sparkle_cards(screen: CanvasLayer) -> int:
	var n: int = 0
	for card in screen.cards():
		var any: bool = false
		for spark in card.sparkles():
			if spark.visible:
				any = true
		if any:
			n += 1
	return n


func _count_variation(root: Node, variation: StringName) -> int:
	var n: int = 0
	for control in _all_controls(root):
		if control.theme_type_variation == variation:
			n += 1
	return n


func _count_class(root: Node, klass: String) -> int:
	return _all_nodes(root).filter(func(node: Node) -> bool:
		var script: Script = node.get_script()
		return script != null and script.get_global_name() == klass).size()


func _count_nodes(root: Node) -> int:
	return _all_nodes(root).size()


func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	for child in root.get_children():
		out.append_array(_all_nodes(child))
	return out


func _all_controls(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	for node in _all_nodes(root):
		if node is Control:
			out.append(node)
	return out


func _text_width(label: Label, text: String) -> float:
	return label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		label.get_theme_font_size("font_size")).x


func _check_layout(screen: CanvasLayer, safe_top: float, window_tag: String) -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var tag: String = "%s (tuval %dx%d)%s" % [window_tag, roundi(view.x), roundi(view.y), " +A36" if safe_top > 0.0 else ""]
	_c("%s tuval genişliği ~720, yükseklik ≥ 1278" % tag, absf(view.x - 720.0) <= 2.0 and view.y >= 1278.0)
	var bar: ScreenTopBar = screen.top_bar()
	var scroll: ScrollContainer = screen.scroll()
	scroll.scroll_vertical = 0
	# Geçiş / pop tween'leri (≤ 0.25 s) bitsin: ölçülen dikdörtgenler dinlenmede.
	await get_tree().create_timer(0.35).timeout
	await get_tree().process_frame
	var bar_bottom: float = bar.height()
	var screen_rect: Rect2 = Rect2(Vector2(0, safe_top), Vector2(view.x, view.y - safe_top))
	var bar_ok: bool = true
	# TASK/057 Tur 2: üst satırda geri oku yok — satır = başlık kurdelesi + Hamur pill'i ("+").
	for control in [bar.pill(), bar.title_plate()]:
		if not screen_rect.encloses(control.get_global_rect()):
			bar_ok = false
			print("    üst satır ekran dışı: ", control.name, " ", control.get_global_rect())
	_c("%s üst satır güvenli payın altında, ekranda; satır yüksekliği %d" % [tag, int(bar_bottom)], bar_ok
		and is_equal_approx(bar_bottom, safe_top + ScreenTopBar.TOP_MARGIN + ScreenTopBar.ROW_HEIGHT))
	_c("%s geri oku yok (TASK/057 Tur 2), '+' ≥ 48" % tag, bar.back_button() == null
		and bar.add_button().size.x >= 48.0 and bar.add_button().size.y >= 48.0)
	var header: Rect2 = screen.header().get_global_rect()
	var bar_rect: Rect2 = Rect2(Vector2(0, safe_top), Vector2(view.x, bar_bottom - safe_top))
	_c("%s albüm başlığı satırın altında (kesişme yok), 24..W-24, ekranda" % tag, header.position.y >= bar_bottom
		and not header.intersects(bar_rect) and absf(header.position.x - 24.0) <= 1.0
		and absf(header.end.x - (view.x - 24.0)) <= 1.0 and screen_rect.encloses(header))
	var header_labels_ok: bool = true
	for label in _all_nodes(screen.header()):
		if label is Label and (label as Label).is_visible_in_tree():
			var l: Label = label
			if not header.grow(1.0).encloses(l.get_global_rect()) or _text_width(l, l.text) > l.size.x + 0.5:
				header_labels_ok = false
				print("    başlık yazısı taşıyor/kırpılıyor: '", l.text, "' ", l.get_global_rect())
	_c("%s başlık yazıları (sayı, VİTRİN çipi, 4 rarity sayacı) kırpılmadan plakanın içinde" % tag, header_labels_ok)
	var gallery_y: float = scroll.global_position.y
	_c("%s albüm başlığın altından tabana (ScrollContainer y > başlık altı, yükseklik = kalan ≥ 300)" % tag,
		gallery_y >= header.end.y and is_equal_approx(scroll.size.y, view.y - gallery_y) and scroll.size.y >= 300.0)
	var haze: TextureRect = screen.haze()
	_c("%s üst haze yalnız satır bandında (başlığa dokunmaz)" % tag, is_equal_approx(haze.size.y, bar_bottom)
		and haze.get_global_rect().end.y <= header.position.y + 0.5)
	var cards: Array[CollectionSkinCard] = screen.cards()
	var inside_x: bool = true
	var touch: bool = true
	var overlap: bool = false
	var columns: Dictionary = {}
	var x0: float = (view.x - 3.0 * 216.0 - 2.0 * 12.0) * 0.5
	for card in cards:
		var rect: Rect2 = card.get_global_rect()
		if rect.position.x < 24.0 - 0.5 or rect.end.x > view.x - 24.0 + 0.5:
			inside_x = false
			print("    yatay taşma: ", card.name, " ", rect)
		if rect.size.x < 48.0 or rect.size.y < 48.0:
			touch = false
		# Konteynerler konumu tam piksele yuvarlar (721 px tuval: x0 = 24.5 → 24).
		var step: float = (rect.position.x - x0) / 114.0
		if absf(step - roundf(step)) * 114.0 > 1.0:
			inside_x = false
			print("    ızgara dışı konum: ", card.name, " ", rect.position.x)
		columns[roundi(step)] = true
	for i in cards.size():
		for j in range(i + 1, cards.size()):
			if cards[i].get_global_rect().intersects(cards[j].get_global_rect()):
				overlap = true
				print("    kart çakışması: ", cards[i].name, " x ", cards[j].name)
	if not (columns.has(0) and columns.has(2) and columns.has(4)):
		print("    sütunlar (x0 = %.2f, 114 px adım): " % x0, columns.keys())
	_c("%s kartlar yatayda 24..W-24 içinde, 216 px, kesişme yok, ≥ 48 dokunma; tam sıra 3 sütun, eksik sıra ortalı" % tag,
		inside_x and touch and not overlap and is_equal_approx(cards[0].get_global_rect().size.x, 216.0)
		and columns.has(0) and columns.has(2) and columns.has(4)
		and absf(screen.card(&"common_07").get_global_rect().position.x - (x0 + 114.0)) <= 1.0
		and absf(screen.card(&"epic_04").get_global_rect().position.x - (x0 + 228.0)) <= 1.0
		and absf(screen.card(&"legendary_02").get_global_rect().position.x - (x0 + 342.0)) <= 1.0)
	var first: Rect2 = cards[0].get_global_rect()
	var first_header: Rect2 = screen.section_headers()[0].get_global_rect()
	_c("%s YAYGIN plakası albümün en üstünde, ilk sıra (Sade) plakanın altında ve tamamen görünür" % tag,
		first_header.position.y >= gallery_y and first.position.y > first_header.end.y
		and first.end.y <= view.y and cards[2].get_global_rect().end.y <= view.y)
	var fits: bool = true
	for card in cards:
		var lbl: Label = card._name_label
		if _text_width(lbl, lbl.text) > lbl.size.x:
			fits = false
			print("    ad sığmıyor: ", lbl.text)
	_c("%s 20 kart adı kırpılmadan sığıyor (üç nokta yok)" % tag, fits)
	var legendary: CollectionSkinCard = screen.card(&"legendary_01")
	var card_rect: Rect2 = legendary.get_global_rect()
	var badge_ok: bool = card_rect.grow(8.0).encloses(legendary.swatch()._lock.get_global_rect())
	badge_ok = badge_ok and legendary.swatch().get_global_rect().encloses(legendary.swatch()._lock.get_global_rect())
	for spark in legendary.sparkles():
		if not card_rect.encloses(spark.get_global_rect()):
			badge_ok = false
	var showcased: CollectionSkinCard = screen.card(&"rare_02")
	var face_bottom: float = showcased.get_global_rect().end.y - CARD_LIP
	var plate: Rect2 = showcased.showcase_plate().get_global_rect()
	_c("%s kilit rozeti sanat kutusunda, Legendary pırıltıları kartın içinde, VİTRİNDE plakası krem yüzün içinde (dudağa binmez)" % tag,
		badge_ok and showcased.get_global_rect().encloses(plate) and plate.end.y <= face_bottom - 2.0
		and showcased.get_global_rect().encloses(showcased._name_label.get_global_rect()))
	# Kaydırma: sonuna git, son kart tamamen görünür + alt pay; satır ve başlık oynamaz.
	var bar_pos_before: Vector2 = bar.pill().global_position
	var header_before: Vector2 = screen.header().global_position
	var max_scroll: float = scroll.get_v_scroll_bar().max_value - scroll.size.y
	scroll.scroll_vertical = int(max_scroll) + 10
	await get_tree().process_frame
	await get_tree().process_frame
	var last: Rect2 = cards[cards.size() - 1].get_global_rect()
	_c("%s albüm kaydırılabilir (max > 0), sonunda son kart tamamen ekranda, alt pay ≥ 40" % tag,
		max_scroll > 0.0 and last.end.y <= view.y - 40.0 and last.position.y >= gallery_y)
	_c("%s kaydırma üst satırı ve başlığı OYNATMADI (sabit)" % tag,
		bar.pill().global_position == bar_pos_before and screen.header().global_position == header_before)
	scroll.scroll_vertical = 0
	await get_tree().process_frame
	# Detay penceresi: kilitli / sahip / vitrinde (iki eylem) / değiştirme adımı.
	SaveManager.data["profile_showcase"] = ["rare_02", "epic_01", "common_02"]
	var detail_ok: bool = true
	for step in [[&"legendary_01", false], [&"common_01", false], [&"epic_01", false], [&"common_01", true]]:
		screen.open_detail(step[0])
		if step[1]:
			screen.detail_primary().pressed.emit()
		await get_tree().create_timer(0.3).timeout
		await get_tree().process_frame
		if not _detail_fits(screen, screen_rect, "%s %s%s" % [tag, step[0], " (değiştirme)" if step[1] else ""]):
			detail_ok = false
		screen.close_detail(false)
	SaveManager.data["profile_showcase"] = ["rare_02"]
	screen.refresh()
	_c("%s detay penceresi (kilitli / sahip / vitrinde iki eylem / değiştirme adımı): ekranda, butonlar ≥ 48, sahne + ad + etiket + not kırpılmadan çerçevede, çakışma yok" % tag,
		detail_ok)


## Detay çerçevesi güvenli alanda; kurdele + X ekranda; hero sahnesi, ad,
## etiket satırı, not ve görünür butonlar çerçevede, birbirine binmez; ad ve
## eylem yazıları sığar; değiştirme kutuları gövdede.
func _detail_fits(screen: CanvasLayer, screen_rect: Rect2, tag: String) -> bool:
	var frame: Control = screen.detail_frame()
	var frame_rect: Rect2 = frame.get_global_rect()
	var ok: bool = true
	var why: Array[String] = []
	if not screen_rect.encloses(frame_rect):
		ok = false
		why.append("çerçeve ekran dışı %s" % frame_rect)
	var close: Button = frame.get_meta(&"close_button")
	var ribbon: Control = frame.get_meta(&"ribbon")
	if not screen_rect.encloses(close.get_global_rect()) or close.size.x < 48.0:
		ok = false
		why.append("X ekran dışı / küçük")
	if not screen_rect.encloses(ribbon.get_global_rect()):
		ok = false
		why.append("kurdele ekran dışı")
	var stage: Rect2 = screen.detail_stage().get_global_rect()
	var name_rect: Rect2 = screen._detail_name.get_global_rect()
	var chip: Rect2 = screen._detail_chip.get_global_rect()
	var note: Rect2 = screen._detail_note.get_global_rect()
	var scroll: ScrollContainer = frame.get_meta(&"scroll")
	var body_clip: Rect2 = scroll.get_global_rect()
	if not frame_rect.encloses(stage):
		ok = false
		why.append("sahne çerçeve dışı")
	if screen._detail_name.is_visible_in_tree() and (not body_clip.grow(1.0).encloses(name_rect) or stage.end.y > name_rect.position.y + 1.0) \
			and not bool(frame.get_meta(&"body_scrolls", false)):
		ok = false
		why.append("ad gövde dışı / sahneye biniyor")
	if _text_width(screen._detail_name, screen._detail_name.text) > screen._detail_name.size.x:
		ok = false
		why.append("ad sığmıyor")
	if chip.intersects(screen._detail_tag.get_global_rect()) and screen._detail_chip.visible:
		ok = false
		why.append("durum çipi rarity etiketine biniyor")
	if not bool(frame.get_meta(&"body_scrolls", false)) and not body_clip.grow(1.0).encloses(note):
		ok = false
		why.append("not gövde dışı")
	var buttons: Array[Button] = []
	for b in [screen.detail_primary(), screen.detail_secondary()]:
		if b.is_visible_in_tree():
			buttons.append(b)
	for b in buttons:
		var r: Rect2 = b.get_global_rect()
		if r.size.y < 48.0 or not frame_rect.encloses(r) or r.intersects(body_clip) or r.intersects(stage):
			ok = false
			why.append("buton %s küçük / dışarıda / gövdeye biniyor %s" % [b.name, r])
		var title: Label = b.get_meta(&"title_label")
		if _text_width(title, title.text) > r.size.x - 24.0:
			ok = false
			why.append("buton yazısı sığmıyor: %s" % title.text)
	if buttons.size() == 2 and buttons[0].get_global_rect().intersects(buttons[1].get_global_rect()):
		ok = false
		why.append("iki buton çakışıyor")
	if screen.is_replacing():
		for tile in screen.replace_tiles():
			if tile.visible and not frame_rect.encloses(tile.get_global_rect()):
				ok = false
				why.append("yuva kutusu çerçeve dışı")
	if not ok:
		print("    detay sorunu ", tag, ": ", ", ".join(why))
	return ok
