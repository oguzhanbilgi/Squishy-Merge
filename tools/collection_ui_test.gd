extends Node
## Koleksiyon — production galeri ekranı (M8.6-06) regresyon testi. Headless,
## kaydı byte-identical geri koyar.
##
##   godot --headless --audio-driver Dummy --path . res://tools/collection_ui_test.tscn
##
## Kontroller: yapı (ScreenTopBar + "KOLEKSİYON", geri, Hamur pill'i + "+",
## alt sekme çubuğu YOK — main'de TabBar düğümü yok, gerçek ScrollContainer,
## dört rarity plakası, tam 21 seçenek = Varsayılan taban şeridi + 20 katalog
## skini, eski UiPalette/StyleBoxFlat parçası yok); taban görünüm (M8.6-06.1:
## geniş ORİJİNAL şeridi YAYGIN plakasının üstünde, hiçbir bölümde değil,
## fiyatsız, sayaca girmez, seçilir/takılır); katalog (20 skin, sıra, 8/6/4/2,
## her kart GERÇEK final önizleme — silüet yok, 20 farklı doku); ilk durum
## (takılı skin seçili, bozuk id → Varsayılan, gizliyken kazanılan skin →
## açılışta vitrinde); seçim (vitrin sanat/ad/rarity/durum/CTA değişir, KAYIT
## DEĞİŞMEZ); sahip/TAK (kanonik equip: tam BİR skin_equipped, tam BİR kayıt
## yazması, Hamur/sahiplik/sayaç değişmez, kopya yok); takılı (TAK gizli,
## dokunuş mutasyon yok); kilitli (final sanat + fiyat + MAĞAZAYA GİT →
## Mağaza; Koleksiyon SATIN ALMAZ — kaynak taraması); ilerleme (0/20, 4/20,
## 20/20 altın); rarity işaretleri (halka/hale/pırıltı/kaide, Legendary özel);
## dört pencere + A36 payı (sabit üst satır + sabit vitrin, üç vitrin
## durumunda kırpma/çakışma yok, dokunma ≥ 48, TAKILI plakası kart yüzünde,
## adlar kırpılmıyor, son sıra erişilebilir); rotalar; kayıt dosyası değişmez.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const VIEWS: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(720, 1560),
	Vector2i(540, 960), Vector2i(1080, 2340)]
## A36 punch-hole: 92 px fiziksel / 1.5 = 61 tuval px (M8.6-02 cihaz kapısı).
const A36_SAFE_TOP: float = 61.0
const EXPECTED_CANVAS: Dictionary = {
	Vector2i(720, 1280): Vector2(720, 1280), Vector2i(720, 1560): Vector2(720, 1560),
	Vector2i(540, 960): Vector2(720, 1280), Vector2i(1080, 2340): Vector2(720, 1560),
}
const RUNTIME_FILES: Array[String] = [
	"res://scripts/ui/collection_screen.gd", "res://scripts/ui/collection_skin_card.gd",
	"res://scenes/ui/collection_screen.tscn", "res://scripts/main.gd",
]
const FORBIDDEN: Array[String] = ["_visual_source", "layerlab_spike", "layerlab_casual_game", "unitypackage"]
## Koleksiyon satın ALMAZ, Hamur'a dokunmaz, skin vermez, kaydı elle yazmaz.
const FORBIDDEN_CALLS: Array[String] = ["purchase", "spend_dough", "add_dough", "grant_skin",
	"data[\"dough\"]", "save_game(", "unlocked_skins", "Shop."]
const LEGACY_PARTS: Array[String] = ["UiPalette", "StyleBoxFlat", "UiType.", "CandyButton", "tab_bar"]
## Kanonik katalog (GAME_DESIGN §5.6 / M8.6-06 brief): sıra + rarity.
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
var _equipped_signals: int = 0
var _granted_signals: int = 0
var _shop_requests: int = 0


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
	get_tree().create_timer(120.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 120 s'de bitmedi — kayıt geri kondu")
			SaveManager.data = _saved
			_restore_save_file()
			get_tree().quit(2))
	SaveManager.skin_equipped.connect(func(_id: StringName) -> void: _equipped_signals += 1)
	SaveManager.skin_granted.connect(func(_id: StringName) -> void: _granted_signals += 1)

	get_window().size = Vector2i(720, 1000)
	await get_tree().process_frame
	await _resize(VIEWS[0])
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_main._daily.visible = false
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
		if src.contains(word) or card_src.contains(word):
			no_purchase = false
			print("    yasak çağrı: ", word)
	_c("Koleksiyon satın ALMAZ / Hamur'a dokunmaz / skin vermez / kaydı elle yazmaz (kaynak taraması)", no_purchase)
	var no_legacy: bool = true
	for word in LEGACY_PARTS:
		if src.contains(word) or card_src.contains(word):
			no_legacy = false
			print("    eski parça: ", word)
	_c("eski M8.5 parçası yok (UiPalette / StyleBoxFlat / UiType / CandyButton / tab_bar)", no_legacy)
	_c("tek kanonik equip yolu: SaveManager.equip_skin, yalnız CTA'dan", src.count("SaveManager.equip_skin(") == 1
		and card_src.count("equip_skin(") == 0)
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
	_c("üst satır ScreenTopBar: geri ButtonHomeIcon (oturmuş), Hamur PanelHomePill", bar != null
		and bar.back_button().theme_type_variation == &"ButtonHomeIcon" and bar.back_button().has_meta(&"face")
		and (bar.pill().get_meta(&"pill") as PanelContainer).theme_type_variation == &"PanelHomePill")
	_c("başlık 'KOLEKSİYON' (noktalı İ) pembe HeaderRibbon", bar.title_text() == "KOLEKSİYON"
		and bar.title_plate().theme_type_variation == &"HeaderRibbon")
	_c("Hamur pill'inde nane '+' VAR (→ Mağaza; kilitli skinlerin alınacağı yer)", bar.add_button() != null
		and bar.add_button().theme_type_variation == &"ButtonHomeAdd" and _count_variation(screen, &"ButtonHomeAdd") == 1)
	_c("Hamur pill'i bakiyeyi gösteriyor (335)", _pill_text(bar) == "335")
	_c("Koleksiyon'da sekme çubuğu YOK, eski tab_bar sahnesi yok", screen.get_node_or_null("TabBar") == null
		and not ResourceLoader.exists("res://scenes/ui/tab_bar.tscn"))
	_c("gerçek ScrollContainer galeri (yatay kapalı, dikey açık, çubuk gizli, kırpma açık)", screen.scroll() != null
		and screen.scroll().horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
		and screen.scroll().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER
		and screen.scroll().clip_contents)
	var headers: Array[Control] = screen.section_headers()
	var header_ok: bool = headers.size() == 4
	var expected_headers: Array[String] = ["YAYGIN", "NADİR", "EPİK", "EFSANEVİ"]
	for i in mini(headers.size(), 4):
		if (headers[i].get_meta(&"title_label") as Label).text != expected_headers[i]:
			header_ok = false
	_c("dört rarity bölüm plakası sırayla YAYGIN / NADİR / EPİK / EFSANEVİ (PanelShopSection ailesi)", header_ok
		and (headers[0].get_meta(&"plate") as PanelContainer).theme_type_variation == &"PanelShopSection")
	_c("eski parça yok: CandyButton 0, StyleBoxFlat panel 0, koyu CardPanel 0", _count_class(screen, "CandyButton") == 0
		and _count_variation(screen, &"CardPanel") == 0 and _count_variation(screen, &"QuietCardPanel") == 0)
	_c("21 seçilebilir görünüm = Varsayılan taban şeridi + 20 katalog skini (CollectionSkinCard)", screen.cards().size() == 21
		and _count_class(screen, "CollectionSkinCard") == 21 and screen.card(&"") != null
		and screen.card(&"").is_default_entry() and screen.card(&"").is_wide())
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
	_c("SkinLibrary tam 20 skin", SkinLibrary.total_count() == 20 and SkinLibrary.all().size() == 20)
	var counts: Dictionary = {}
	for skin in SkinLibrary.all():
		counts[skin.rarity] = int(counts.get(skin.rarity, 0)) + 1
	_c("rarity sayıları 8 / 6 / 4 / 2", counts.get(SkinData.Rarity.COMMON, 0) == 8 and counts.get(SkinData.Rarity.RARE, 0) == 6
		and counts.get(SkinData.Rarity.EPIC, 0) == 4 and counts.get(SkinData.Rarity.LEGENDARY, 0) == 2)
	var order_ok: bool = true
	var cards: Array[CollectionSkinCard] = screen.cards()
	var entries: Array[SkinEntry] = SkinEntry.all(true)
	for i in cards.size():
		if cards[i].skin_id() != entries[i].id:
			order_ok = false
	var names_ok: bool = true
	for i in EXPECTED_NAMES.size():
		if cards[i + 1].name_text() != EXPECTED_NAMES[i]:
			names_ok = false
			print("    ad uyumsuz: ", cards[i + 1].name_text(), " / ", EXPECTED_NAMES[i])
	_c("kart sırası katalog sırası (rarity + id), Varsayılan ilk; 20 ad kanonik sırada", order_ok and names_ok
		and cards[0].name_text() == SkinEntry.DEFAULT_NAME)
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
				for child in row.get_children():
					if (child as CollectionSkinCard).is_default_entry():
						grid_ok = false
				n += row.get_child_count()
		if section == null or n != expect or section.get_child_count() != ceili(float(expect) / 3.0):
			grid_ok = false
		in_sections += n
	_c("bölüm sıraları 3 sütun, ortalı (YAYGIN 3+3+2 / EPİK 3+1 / EFSANEVİ 2 ortada); tam 8 / 6 / 4 / 2 katalog kartı, Varsayılan hiçbirinde değil",
		grid_ok and in_sections == 20)
	_c("YAYGIN bölümü Sade ile başlar (Varsayılan bölümün dışında)",
		((screen._content.get_node("Grid_Common") as VBoxContainer).get_child(0).get_child(0) as CollectionSkinCard).skin_id() == &"common_01")

	print("-- taban görünüm (Varsayılan, M8.6-06.1)")
	var base: CollectionSkinCard = screen.card(&"")
	var base_index: int = base.get_index()
	var header_index: int = screen.section_headers()[0].get_index()
	_c("Varsayılan geniş ORİJİNAL şeridi: galeri içeriğinin İLK çocuğu, YAYGIN plakasının üstünde, 672 px geniş",
		base.is_wide() and base.get_parent() == screen._content and base_index == 0 and base_index < header_index
		and is_equal_approx(base.custom_minimum_size.x, 672.0) and base.custom_minimum_size.y <= 120.0)
	_c("ORİJİNAL rozeti (lavanta trapez, YAYGIN/Common değil); rarity etiketi yok", base.original_tag() != null
		and (base.original_tag().get_meta(&"title_label") as Label).text == "ORİJİNAL"
		and not _collect_text(base).contains("YAYGIN") and not _collect_text(base).contains("Common")
		and base.name_text() == SkinEntry.DEFAULT_NAME)
	_c("Varsayılan fiyatsız, kilitsiz, satın alınamaz; kanonik id boş string", base.price() == 0
		and not base.swatch()._lock.visible and SkinEntry.find(&"").price == 0
		and not SkinEntry.find(&"").is_purchasable() and SkinEntry.DEFAULT_ID == &"")
	_c("Varsayılan sayaca girmez: owned_count kataloğu sayar (mid 4/20; Varsayılan takılıyken de 4)", SkinEntry.owned_count() == 4
		and SkinLibrary.find(&"") == null and not SkinLibrary.all().any(func(s: SkinData) -> bool: return s.id == &""))
	var catalogue_cards: int = 0
	for card in screen.cards():
		if not card.is_default_entry():
			catalogue_cards += 1
	_c("tam 20 koleksiyon kartı + 1 taban şeridi; katalog 20 skin", catalogue_cards == 20 and SkinLibrary.total_count() == 20)
	var art_ok: bool = true
	var seen: Dictionary = {}
	for card in cards:
		var tex: Texture2D = card.swatch()._image.texture
		if card.is_default_entry():
			if tex != SkinEntry.PREVIEW_BASE_TEXTURE:
				art_ok = false
			continue
		var entry: SkinEntry = SkinEntry.find(card.skin_id())
		if tex == null or tex != entry.preview_texture() or tex == SkinSwatch.LOCKED_TEXTURE:
			art_ok = false
			print("    sanat yanlış: ", card.skin_id())
		var path: String = tex.resource_path if tex != null else ""
		if path.is_empty() or not path.contains("assets/visual/skins/previews/") or seen.has(path):
			art_ok = false
		seen[path] = true
	_c("21 kartın hepsi GERÇEK final sanat: 20 farklı önizleme dokusu, silüet yok, kilitli dahil; Varsayılan orijinal dumpling",
		art_ok and seen.size() == 20)
	var preview_ok: bool = true
	for skin in SkinLibrary.all():
		if skin.preview_texture == null or not skin.preview_texture.resource_path.begins_with("res://assets/visual/skins/previews/"):
			preview_ok = false
	_c("20 SkinData.preview_texture dolu ve previews/ altında", preview_ok)

	print("-- ilk durum (orta oyuncu: rare_02 takılı)")
	_c("takılı skin seçili (rare_02), vitrin 'Kırmızı Biber' / NADİR / TAKILI, TAK gizli", screen.selected_id() == &"rare_02"
		and screen.showcase_name_text() == "Kırmızı Biber" and screen.showcase_rarity_text() == "NADİR"
		and screen.showcase_state_text() == "TAKILI" and not screen.cta().visible and screen.equipped_plate().visible)
	_c("vitrin sanatı rare_02 final önizlemesi, kilit yok", screen.showcase_swatch()._image.texture == SkinLibrary.find(&"rare_02").preview_texture
		and not screen.showcase_swatch()._lock.visible)
	_c("rare_02 kartı seçili halka + TAKILI plakası; diğer kartlar seçili değil", screen.card(&"rare_02").is_selected()
		and screen.card(&"rare_02").select_ring().visible and screen.card(&"rare_02").equipped_plate().visible
		and not screen.card(&"common_01").is_selected() and not screen.card(&"common_01").equipped_plate().visible)
	_c("ilerleme 4/20 (SkinEntry.owned_count ile aynı), nane ray", screen.progress_text() == "4/20"
		and SkinEntry.owned_count() == 4 and is_equal_approx(screen.progress_bar().value, 0.2)
		and screen.progress_bar().theme_type_variation == &"ProgressBarMint")
	SaveManager.data["equipped_skin"] = "epic_03"  # sahip olunmayan id → güvenli fallback
	screen.refresh()
	await get_tree().process_frame
	_c("bozuk takılı id → Varsayılan seçili (kayda yazılmadan)", SaveManager.equipped_skin_id() == &""
		and screen.selected_id() == &"" and screen.showcase_name_text() == SkinEntry.DEFAULT_NAME
		and screen.showcase_rarity_text() == "ORİJİNAL" and screen.showcase_state_text() == "TAKILI"
		and SaveManager.data["equipped_skin"] == "epic_03")
	_apply_mid()
	screen.refresh()
	await get_tree().process_frame

	print("-- seçim (kayıt değişmez)")
	var file_before: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	var equipped_before: int = _equipped_signals
	screen.select(&"common_03")
	await get_tree().process_frame
	_c("kilitli Common seçildi: vitrin Kepekli / YAYGIN / '50 Hamur' / MAĞAZAYA GİT, final sanat + kilit",
		screen.selected_id() == &"common_03" and screen.showcase_name_text() == "Kepekli"
		and screen.showcase_rarity_text() == "YAYGIN" and screen.showcase_state_text() == "50 Hamur"
		and screen.cta().visible and screen.cta_text() == "MAĞAZAYA GİT" and not screen.equipped_plate().visible
		and screen.showcase_swatch()._image.texture == SkinLibrary.find(&"common_03").preview_texture
		and screen.showcase_swatch()._lock.visible)
	_c("seçim halkası taşındı; takılı rare_02 TAKILI plakası duruyor", screen.card(&"common_03").is_selected()
		and not screen.card(&"rare_02").is_selected() and screen.card(&"rare_02").equipped_plate().visible
		and screen.card(&"rare_02").is_equipped())
	_c("seçim kayda YAZMADI (dosya aynı, takılı aynı, sinyal yok)", FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == file_before
		and SaveManager.equipped_skin_id() == &"rare_02" and _equipped_signals == equipped_before)
	await get_tree().create_timer(0.3).timeout
	_c("kilitli Common: lavanta hale (LAVENDER α .42), kaide halkası açık lavanta, kaide krem",
		screen.halo().self_modulate.is_equal_approx(Color(UiTokens.LAVENDER, screen.HALO_ALPHA[SkinData.Rarity.COMMON]))
		and _pedestal_rim(screen).is_equal_approx(UiTokens.LAVENDER_LIGHT)
		and screen.pedestal().self_modulate.is_equal_approx(UiTokens.TRAY_CREAM))
	screen.select(&"rare_01")
	await get_tree().create_timer(0.3).timeout
	_c("kilitli Rare: NADİR, mavi hale (RARITY_RARE α .58), mavi kaide halkası + mavimsi kaide, bloom yok, 150 Hamur",
		screen.showcase_rarity_text() == "NADİR"
		and screen.halo().self_modulate.is_equal_approx(Color(UiTokens.RARITY_RARE, screen.HALO_ALPHA[SkinData.Rarity.RARE]))
		and _pedestal_rim(screen).is_equal_approx(UiTokens.RARITY_RARE.lerp(Color.WHITE, 0.3))
		and screen.pedestal().self_modulate.is_equal_approx(UiTokens.TRAY_CREAM.lerp(UiTokens.RARITY_RARE, screen.PEDESTAL_TINT))
		and not screen.bloom().visible and screen.showcase_state_text() == "150 Hamur")
	screen.select(&"epic_01")
	await get_tree().create_timer(0.3).timeout
	_c("sahip Epic (Acı Sos): EPİK, SAHİPSİN çipi, TAK, mor hale + mor kaide halkası", screen.showcase_name_text() == "Acı Sos"
		and screen.showcase_rarity_text() == "EPİK" and screen.showcase_state_text() == "SAHİPSİN"
		and screen.cta_text() == "TAK" and screen.halo().self_modulate.is_equal_approx(Color(UiTokens.RARITY_EPIC, screen.HALO_ALPHA[SkinData.Rarity.EPIC]))
		and _pedestal_rim(screen).is_equal_approx(UiTokens.RARITY_EPIC.lerp(Color.WHITE, 0.3)))
	screen.select(&"legendary_01")
	await get_tree().create_timer(0.3).timeout
	_c("kilitli Legendary (Altın Hamur): EFSANEVİ, altın hale + bloom, 900 Hamur, MAĞAZAYA GİT",
		screen.showcase_rarity_text() == "EFSANEVİ" and screen.bloom().visible
		and screen.halo().self_modulate.is_equal_approx(Color(UiTokens.GOLD, screen.HALO_ALPHA[SkinData.Rarity.LEGENDARY]))
		and screen.showcase_state_text() == "900 Hamur" and screen.cta_text() == "MAĞAZAYA GİT")
	_c("Legendary kaide halkası altın", _pedestal_rim(screen) == UiTokens.GOLD)
	screen.card(&"common_02").pressed.emit()
	await get_tree().process_frame
	_c("karta dokunmak (pressed) seçer: Susamlı, kayıt yine değişmedi", screen.selected_id() == &"common_02"
		and screen.showcase_name_text() == "Susamlı" and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == file_before
		and _equipped_signals == equipped_before)
	_c("aynı karta ikinci dokunuş seçimi bozmaz", _tap_same(screen, &"common_02"))

	print("-- sahip olunan: TAK")
	screen.select(&"common_01")
	await get_tree().process_frame
	var dough_before: int = SaveManager.dough()
	var owned_before: Array = (SaveManager.data["unlocked_skins"] as Array).duplicate()
	var count_before: int = SkinEntry.owned_count()
	equipped_before = _equipped_signals
	var granted_before: int = _granted_signals
	_c("sahip olunan Sade seçili: SAHİPSİN + TAK (cyan candy buton ≥ 48 px)", screen.showcase_state_text() == "SAHİPSİN"
		and screen.cta().visible and screen.cta_text() == "TAK" and screen.cta().size.y >= 48.0
		and screen.cta().theme_type_variation == &"ButtonPrimary" and SaveManager.equipped_skin_id() == &"rare_02")
	screen.cta().pressed.emit()
	await get_tree().process_frame
	var save_now: Dictionary = _read_save_file()
	_c("TAK → kanonik equip: takılı common_01 (kayıtta), tam BİR skin_equipped sinyali", SaveManager.equipped_skin_id() == &"common_01"
		and save_now.get("equipped_skin", "") == "common_01" and _equipped_signals == equipped_before + 1)
	_c("TAK → Hamur, sahiplik listesi, sayaç değişmedi; kopya/grant yok", SaveManager.dough() == dough_before
		and SaveManager.data["unlocked_skins"] == owned_before and SkinEntry.owned_count() == count_before
		and _granted_signals == granted_before and int(save_now.get("dough", -1)) == dough_before
		and (save_now.get("unlocked_skins", []) as Array).size() == owned_before.size())
	_c("TAK → vitrin TAKILI, TAK gizli; common_01 kartı TAKILI, rare_02 kartı SAHİP (plaka gizli)",
		screen.showcase_state_text() == "TAKILI" and not screen.cta().visible and screen.equipped_plate().visible
		and screen.card(&"common_01").is_equipped() and screen.card(&"common_01").equipped_plate().visible
		and not screen.card(&"rare_02").is_equipped() and not screen.card(&"rare_02").equipped_plate().visible
		and screen.card(&"rare_02").is_owned() and screen.selected_id() == &"common_01")
	_c("eski takılı skin (rare_02) hâlâ sahip", SaveManager.owns_skin(&"rare_02") and SkinEntry.find(&"rare_02").owned)
	_c("takılı durumda CTA dokunuşu mutasyon yapmaz", _press_equipped_no_mutation(screen))
	# Varsayılana dönüş: Varsayılan kartı seçilebilir ve takılabilir (GAME_DESIGN §5.3).
	screen.select(&"")
	await get_tree().process_frame
	_c("Varsayılan seçili: ORİJİNAL, SAHİPSİN, TAK", screen.showcase_rarity_text() == "ORİJİNAL"
		and screen.showcase_state_text() == "SAHİPSİN" and screen.cta_text() == "TAK")
	screen.cta().pressed.emit()
	await get_tree().process_frame
	_c("Varsayılan TAK → equipped_skin '' (orijinal görünüm), vitrin TAKILI", SaveManager.equipped_skin_id() == &""
		and _read_save_file().get("equipped_skin", "x") == "" and screen.showcase_state_text() == "TAKILI"
		and screen.card(&"").is_equipped())

	print("-- kilitli: MAĞAZAYA GİT, satın alma yok")
	_apply_mid()
	screen.refresh()
	await get_tree().process_frame
	screen.select(&"legendary_02")
	await get_tree().process_frame
	file_before = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	var requests_before: int = _shop_requests
	screen.cta().pressed.emit()
	await get_tree().process_frame
	_c("kilitli Gökkuşağı MAĞAZAYA GİT → shop_skin_requested → Mağaza (tek örnek), Koleksiyon gizli", _shop_requests == requests_before + 1
		and _main._active_tab == 3 and shop.visible and not screen.visible
		and _count_class(_main, "ShopPowerCard") == 4 and _count_class(_main, "CollectionSkinCard") == 21)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	# Gökkuşağı son kart: içerik sonuna kadar kaydırılır (kart ekranda, GÜÇLER'de
	# değil); orta kart (rare_01) tam üst satırın altına oturur.
	var landed: Rect2 = shop.skin_card(&"legendary_02").get_global_rect()
	var max_scroll: float = shop.scroll().get_v_scroll_bar().max_value - shop.scroll().size.y
	_c("Mağaza hedef skin kartına kaydırdı (Gökkuşağı ekranda, kaydırma sonunda; GÜÇLER'de değil)",
		shop.scroll().scroll_vertical >= int(max_scroll) - 1 and landed.position.y >= shop.top_bar().height()
		and landed.end.y <= 1280.0 and shop.power_cards()[0].get_global_rect().end.y < 0.0)
	shop.focus_skin(&"rare_01")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var expected_top: float = shop.top_bar().height() + shop.CONTENT_TOP_GAP
	_c("focus_skin(orta kart) kartı üst satırın hemen altına getirir (±3 px, pop payı)",
		absf(shop.skin_card(&"rare_01").get_global_rect().position.y - expected_top) <= 3.0)
	_c("kilitli CTA hiçbir şey almadı / takmadı / yazmadı", not SaveManager.owns_skin(&"legendary_02")
		and SaveManager.equipped_skin_id() == &"rare_02" and SaveManager.dough() == 335
		and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == file_before)
	_c("Mağaza kilitli Legendary kartında SATIN AL var (satın alma Mağaza'da)", shop.skin_card(&"legendary_02").buy_button().visible)
	# Mağazadan satın alma Koleksiyon GİZLİYKEN → açılışta yeni skin vitrinde + TAK.
	SaveManager.data["dough"] = 2000
	shop.refresh()
	shop._open_confirm(SkinLibrary.find(&"legendary_02"))
	await get_tree().process_frame
	shop._confirm_yes.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_c("Mağaza satın aldı (tek transaction): sahip, 1100 Hamur, takılı DEĞİL", SaveManager.owns_skin(&"legendary_02")
		and SaveManager.dough() == 1100 and SaveManager.equipped_skin_id() == &"rare_02")
	_main._show_tab(2)
	await get_tree().process_frame
	_c("Koleksiyon'a dönünce yeni skin vitrinde (Gökkuşağı) SAHİPSİN + TAK, 5/20", screen.selected_id() == &"legendary_02"
		and screen.showcase_state_text() == "SAHİPSİN" and screen.cta_text() == "TAK" and screen.progress_text() == "5/20"
		and screen.card(&"legendary_02").is_owned() and not screen.card(&"legendary_02").equipped_plate().visible)
	screen.cta().pressed.emit()
	await get_tree().process_frame
	_c("Legendary TAK → takılı, EFSANEVİ + TAKILI + bloom", SaveManager.equipped_skin_id() == &"legendary_02"
		and screen.showcase_state_text() == "TAKILI" and screen.bloom().visible)
	# Ekran görünürken grant (sandık) → anında vitrine.
	SaveManager.grant_skin(&"rare_05")
	await get_tree().process_frame
	_c("görünürken kazanılan skin (rare_05) anında seçili + SAHİPSİN + TAK, 6/20", screen.selected_id() == &"rare_05"
		and screen.showcase_state_text() == "SAHİPSİN" and screen.cta_text() == "TAK" and screen.progress_text() == "6/20")

	print("-- ilerleme")
	_apply_fresh()
	screen.refresh()
	await get_tree().process_frame
	_c("yeni oyuncu: 0/20 (Sade varsayılan DEĞİL, satılık), Varsayılan takılı + TAKILI şeridi, 0 Hamur", screen.progress_text() == "0/20"
		and SkinEntry.owned_count() == 0 and is_zero_approx(screen.progress_bar().value)
		and screen.selected_id() == &"" and screen.showcase_state_text() == "TAKILI" and _pill_text(bar) == "0"
		and screen.card(&"").is_equipped() and screen.card(&"").equipped_plate().visible and screen.card(&"").is_selected()
		and not screen.card(&"common_01").is_owned() and screen.card(&"common_01").price() == 50)
	_apply_full()
	screen.refresh()
	await get_tree().process_frame
	_c("20/20: altın ray + yıldız, tam dolu; Gökkuşağı takılı; ödül verilmedi (Hamur aynı)", screen.progress_text() == "20/20"
		and is_equal_approx(screen.progress_bar().value, 1.0) and screen.progress_bar().theme_type_variation == &"ProgressBarGold"
		and screen._progress_star.visible and SaveManager.dough() == 1240 and screen.selected_id() == &"legendary_02")
	var all_owned: bool = true
	for card in cards:
		if not card.is_owned() or card.price() != 0 or card.swatch()._lock.visible:
			all_owned = false
	_c("20/20: hiçbir kartta kilit yok", all_owned)
	SaveManager.data["equipped_skin"] = ""
	screen.refresh()
	await get_tree().process_frame
	_c("20/20 Varsayılan'dan bağımsız: Varsayılan takılıyken de 20/20, Varsayılan seçili + TAKILI", screen.progress_text() == "20/20"
		and SkinEntry.owned_count() == 20 and screen.selected_id() == &"" and screen.showcase_state_text() == "TAKILI"
		and screen.card(&"").is_equipped() and screen.card(&"").equipped_plate().visible)

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
	_c("bölüm plakaları rarity tonlu: EFSANEVİ altın, NADİR mavi, EPİK mor, YAYGIN gri-lavanta (hepsi override)",
		(headers[3].get_meta(&"plate") as PanelContainer).has_theme_stylebox_override("panel")
		and (headers[0].get_meta(&"plate") as PanelContainer).has_theme_stylebox_override("panel")
		and ((headers[3].get_meta(&"plate") as PanelContainer).get_theme_stylebox("panel") as StyleBoxTexture).modulate_color.r > 0.8)
	_c("kilitli kart gövdesi buzlu (PanelCollectionCardLocked), sahip olunan krem", screen.card(&"common_03").body().theme_type_variation == &"PanelCollectionCardLocked"
		and screen.card(&"common_01").body().theme_type_variation == &"PanelCollectionCard")
	_c("kilitli kartta kilit rozeti görünür, sahip olunanda yok; kartta fiyat metni YOK (vitrinde)", screen.card(&"common_03").swatch()._lock.visible
		and not screen.card(&"common_01").swatch()._lock.visible
		and not _collect_text(screen.card(&"common_03")).contains("Hamur"))

	print("-- rotalar")
	_main._show_tab(2)
	await get_tree().process_frame
	bar.back_button().pressed.emit()
	_c("geri → Ana Sayfa", _main._active_tab == 0 and home.visible and not screen.visible)
	home.feature_button(&"collection").pressed.emit()
	_c("Home KOLEKSİYON madalyonu → Koleksiyon (tek örnek)", _main._active_tab == 2 and screen.visible
		and _count_class(_main, "CollectionSkinCard") == 21)
	_main._last_back_msec = -1000
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("Android geri → Ana Sayfa (çıkış yok: _exit_tree bekçisi SONUC'tan önce gelirse FAIL basar)", _main._active_tab == 0 and home.visible)
	_main._show_tab(2)
	bar.add_button().pressed.emit()
	_c("Hamur '+' → Mağaza", _main._active_tab == 3 and shop.visible and not screen.visible)
	_main._show_tab(2)
	await get_tree().process_frame
	screen.select(&"legendary_02")
	screen.scroll().scroll_vertical = 600
	await get_tree().process_frame
	_main._show_tab(0)
	_main._show_tab(2)
	await get_tree().process_frame
	_c("Koleksiyon'a her girişte kaydırma en üstte (600'den), seçim takılıya döner", screen.scroll().scroll_vertical == 0
		and screen.selected_id() == &"rare_02")
	_c("Home Koleksiyon madalyonu aynı sayıyı gösteriyor (4/20)", home.feature_button(&"collection").badge_text() == "4/20")

	print("-- yerleşim")
	_apply_mid()
	screen.refresh()
	for view in VIEWS:
		await _resize(view)
		_main._show_tab(0)
		_main._show_tab(2)
		await get_tree().process_frame
		await get_tree().process_frame
		await _check_layout(screen, EXPECTED_CANVAS[view], 0.0, "%dx%d" % [view.x, view.y])
	await _resize(VIEWS[1])
	screen._layout_with_safe_top(A36_SAFE_TOP)
	await get_tree().process_frame
	await get_tree().process_frame
	await _check_layout(screen, EXPECTED_CANVAS[VIEWS[1]], A36_SAFE_TOP, "720x1560")
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


func _apply_fresh() -> void:
	SaveManager.data["highest_level_unlocked"] = 1
	SaveManager.data["level_stars"] = {}
	SaveManager.data["dough"] = 0
	SaveManager.data["unlocked_skins"] = []
	SaveManager.data["equipped_skin"] = ""
	SaveManager.data["powerups"] = {"bomb": 1, "upgrade": 1, "shake": 1, "clear_small": 1}
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()


func _apply_full() -> void:
	_apply_mid()
	var all: Array = []
	for skin in SkinLibrary.all():
		all.append(String(skin.id))
	SaveManager.data["unlocked_skins"] = all
	SaveManager.data["equipped_skin"] = "legendary_02"
	SaveManager.data["dough"] = 1240


func _pill_text(bar: ScreenTopBar) -> String:
	return (bar.pill().get_meta(&"value_label") as Label).text


func _pedestal_rim(screen: CanvasLayer) -> Color:
	return (screen.pedestal().get_parent().get_node("PedestalRim") as NinePatchRect).self_modulate


func _collect_text(node: Node) -> String:
	var out: String = ""
	for n in _all_nodes(node):
		if n is Label and (n as Label).visible:
			out += (n as Label).text + "|"
	return out


func _tap_same(screen: CanvasLayer, id: StringName) -> bool:
	var before: int = _equipped_signals
	screen.card(id).pressed.emit()
	return screen.selected_id() == id and _equipped_signals == before


func _press_equipped_no_mutation(screen: CanvasLayer) -> bool:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	var before: int = _equipped_signals
	# CTA gizli; yine de sinyal yolu çağrılırsa hiçbir şey olmamalı.
	screen.cta().pressed.emit()
	var unchanged: bool = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == bytes
	return unchanged and _equipped_signals == before and not screen.cta().visible


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


func _check_layout(screen: CanvasLayer, view: Vector2, safe_top: float, window_tag: String) -> void:
	var tag: String = "%s (tuval %dx%d)%s" % [window_tag, int(view.x), int(view.y), " +A36" if safe_top > 0.0 else ""]
	var visible: Rect2 = get_viewport().get_visible_rect()
	_c("%s tuval genişliği 720" % tag, is_equal_approx(visible.size.x, 720.0) and is_equal_approx(visible.size.y, view.y))
	var bar: ScreenTopBar = screen.top_bar()
	var scroll: ScrollContainer = screen.scroll()
	scroll.scroll_vertical = 0
	# Seçim pop'u / geçiş tween'leri (≤ 0.25 s) bitsin: ölçülen dikdörtgenler
	# dinlenme konumu olsun.
	await get_tree().create_timer(0.35).timeout
	await get_tree().process_frame
	var bar_bottom: float = bar.height()
	var screen_rect: Rect2 = Rect2(Vector2(0, safe_top), Vector2(720.0, view.y - safe_top))
	var bar_ok: bool = true
	for control in [bar.back_button(), bar.pill(), bar.title_plate()]:
		if not screen_rect.encloses(control.get_global_rect()):
			bar_ok = false
			print("    üst satır ekran dışı: ", control.name, " ", control.get_global_rect())
	_c("%s üst satır güvenli payın altında, ekranda; satır yüksekliği %d" % [tag, int(bar_bottom)], bar_ok
		and is_equal_approx(bar_bottom, safe_top + ScreenTopBar.TOP_MARGIN + ScreenTopBar.ROW_HEIGHT))
	_c("%s geri ≥ 48, '+' ≥ 48" % tag, bar.back_button().size.x >= 48.0 and bar.back_button().size.y >= 48.0
		and bar.add_button().size.x >= 48.0 and bar.add_button().size.y >= 48.0)
	var showcase: Control = screen.showcase()
	var show_rect: Rect2 = showcase.get_global_rect()
	var art: Rect2 = screen.art_box().get_global_rect()
	_c("%s vitrin satırın hemen altında, sabit; sanat kutusu satırla kesişmiyor, ekranda, ≥ 296 px" % tag,
		is_equal_approx(show_rect.position.y, bar_bottom) and art.position.y >= bar_bottom
		and screen_rect.encloses(art) and art.size.x >= 296.0)
	var bar_rect: Rect2 = Rect2(Vector2(0, safe_top), Vector2(720.0, bar_bottom - safe_top))
	var haze: TextureRect = screen.haze()
	_c("%s üst haze yalnız satır bandında (vitrin sanatına dokunmaz); sanat/ad satıra girmez" % tag,
		not art.intersects(bar_rect) and not screen._name_label.get_global_rect().intersects(bar_rect)
		and is_equal_approx(haze.size.y, bar_bottom) and not haze.get_global_rect().intersects(art))
	# Üç vitrin durumu (takılı / sahip TAK / kilitli MAĞAZAYA GİT): sıra, kesişme,
	# kapsama ve çip + etiketin satır içinde kalması her durumda ölçülür.
	var order_ok: bool = true
	var cta_rect: Rect2
	var plate_rect: Rect2
	var progress_rect: Rect2
	var name_rect: Rect2
	var tag_rect: Rect2
	for id in [&"rare_02", &"common_01", &"legendary_01"]:
		screen.select(id, false)
		await get_tree().process_frame
		cta_rect = screen.cta().get_global_rect()
		plate_rect = screen.equipped_plate().get_global_rect()
		progress_rect = screen.progress_plate().get_global_rect()
		name_rect = screen._name_label.get_global_rect()
		tag_rect = screen._tag_row.get_global_rect()
		var chip_ok: bool = true
		if screen.state_chip().visible:
			var chip_rect: Rect2 = screen.state_chip().get_global_rect()
			var rtag_rect: Rect2 = screen._tag.get_global_rect()
			chip_ok = tag_rect.encloses(chip_rect) and tag_rect.encloses(rtag_rect) and not chip_rect.intersects(rtag_rect)
		var state_ok: bool = name_rect.end.y <= tag_rect.position.y and tag_rect.end.y <= cta_rect.position.y
		state_ok = state_ok and cta_rect.end.y <= progress_rect.position.y and show_rect.encloses(cta_rect)
		state_ok = state_ok and show_rect.encloses(progress_rect) and show_rect.encloses(name_rect)
		state_ok = state_ok and is_equal_approx(cta_rect.position.y, plate_rect.position.y) and chip_ok
		if not state_ok:
			order_ok = false
			print("    durum ", id, " vitrin ", show_rect, " ad ", name_rect, " etiket ", tag_rect, " cta ", cta_rect, " plaka ", plate_rect, " ilerleme ", progress_rect)
	_c("%s vitrin içi (takılı / sahip / kilitli): ad → etiket+çip → eylem → ilerleme sırayla, kesişme yok, hepsi vitrin içinde" % tag, order_ok)
	screen.select(&"rare_02", false)
	# Seçim pop'ları (1.04, 0.22 s) bitsin: kart dikdörtgenleri dinlenmede ölçülür.
	await get_tree().create_timer(0.3).timeout
	await get_tree().process_frame
	cta_rect = screen.cta().get_global_rect()
	plate_rect = screen.equipped_plate().get_global_rect()
	_c("%s CTA 320×60 (≥ 48), tuval ortasında; TAKILI plakası aynı yuvada, aynı ayak izi, ≥ 48" % tag,
		cta_rect.size.y >= 48.0 and is_equal_approx(cta_rect.size.x, 320.0) and is_equal_approx(cta_rect.get_center().x, 360.0)
		and plate_rect.size.y >= 48.0 and absf(plate_rect.get_center().x - 360.0) < 1.0
		and is_equal_approx(plate_rect.size.x, cta_rect.size.x))
	_c("%s vitrin okunur: ad ≥ 30 px, rarity etiketi ≥ 18 px" % tag,
		screen._name_label.get_theme_font_size("font_size") >= 30
		and (screen._tag.get_meta(&"title_label") as Label).get_theme_font_size("font_size") >= 18)
	var fits: bool = true
	for card in screen.cards():
		var lbl: Label = card._name_label
		if _text_width(lbl, lbl.text) > lbl.size.x:
			fits = false
			print("    ad sığmıyor: ", lbl.text)
	var show_name: Label = screen._name_label
	_c("%s 21 kart adı ve vitrin adı kırpılmadan sığıyor (üç nokta yok)" % tag, fits
		and _text_width(show_name, "Kırmızı Biber") < show_name.size.x)
	var gallery_y: float = show_rect.end.y
	_c("%s galeri vitrinin altından tabana (ScrollContainer y = vitrin altı, yükseklik = kalan)" % tag,
		is_equal_approx(scroll.global_position.y, gallery_y) and is_equal_approx(scroll.size.y, view.y - gallery_y)
		and scroll.size.y >= 300.0)
	var cards: Array[CollectionSkinCard] = screen.cards()
	var inside_x: bool = true
	var touch: bool = true
	var overlap: bool = false
	var columns: Dictionary = {}
	for card in cards:
		var rect: Rect2 = card.get_global_rect()
		if rect.position.x < 24.0 - 0.5 or rect.end.x > 696.0 + 0.5:
			inside_x = false
			print("    yatay taşma: ", card.name, " ", rect)
		if rect.size.x < 48.0 or rect.size.y < 48.0:
			touch = false
		columns[roundi(rect.position.x)] = true
	for i in cards.size():
		for j in range(i + 1, cards.size()):
			if cards[i].get_global_rect().intersects(cards[j].get_global_rect()):
				overlap = true
				print("    kart çakışması: ", cards[i].name, " x ", cards[j].name)
	# Tam sıralar 3 sütun (x 24 / 252 / 480); eksik sıralar ortada (Safran tek: x 252; iki Legendary: x 138 / 366).
	_c("%s kartlar yatayda 24..696 içinde, 216 px, kesişme yok, ≥ 48 dokunma; tam sıra 3 sütun, eksik sıra ortalı (YAYGIN son 2 / Safran / Legendary 2)" % tag,
		inside_x and touch and not overlap and is_equal_approx(cards[1].get_global_rect().size.x, 216.0)
		and columns.has(24) and columns.has(252) and columns.has(480)
		and is_equal_approx(screen.card(&"common_07").get_global_rect().position.x, 138.0)
		and is_equal_approx(screen.card(&"common_08").get_global_rect().position.x, 366.0)
		and is_equal_approx(screen.card(&"epic_04").get_global_rect().position.x, 252.0)
		and is_equal_approx(screen.card(&"legendary_01").get_global_rect().position.x, 138.0)
		and is_equal_approx(screen.card(&"legendary_02").get_global_rect().position.x, 366.0))
	var base_rect: Rect2 = cards[0].get_global_rect()
	var first: Rect2 = cards[1].get_global_rect()
	var header: Rect2 = screen.section_headers()[0].get_global_rect()
	_c("%s Varsayılan şeridi galerinin en üstünde (24..696, ≤ 120 px), YAYGIN plakası altında, Sade plakanın altında, ilk sıra tamamen görünür" % tag,
		base_rect.position.y >= gallery_y and is_equal_approx(base_rect.position.x, 24.0)
		and is_equal_approx(base_rect.size.x, 672.0) and base_rect.size.y <= 120.0
		and base_rect.end.y < header.position.y and first.position.y > header.end.y
		and first.end.y <= view.y and cards[3].get_global_rect().end.y <= view.y)
	var legendary: CollectionSkinCard = screen.card(&"legendary_01")
	var card_rect: Rect2 = legendary.get_global_rect()
	var badge_ok: bool = card_rect.grow(8.0).encloses(legendary.swatch()._lock.get_global_rect())
	badge_ok = badge_ok and legendary.swatch().get_global_rect().encloses(legendary.swatch()._lock.get_global_rect())
	for spark in legendary.sparkles():
		if not card_rect.encloses(spark.get_global_rect()):
			badge_ok = false
	var equipped_card: CollectionSkinCard = screen.card(&"rare_02")
	var face_bottom: float = equipped_card.get_global_rect().end.y - CARD_LIP
	var eq_plate: Rect2 = equipped_card.equipped_plate().get_global_rect()
	_c("%s kilit rozeti sanat kutusunda, Legendary pırıltıları kartın içinde, TAKILI plakası krem yüzün içinde (dudağa binmez)" % tag,
		badge_ok and equipped_card.get_global_rect().encloses(eq_plate) and eq_plate.end.y <= face_bottom - 4.0
		and equipped_card.get_global_rect().encloses(equipped_card._name_label.get_global_rect()))
	# Kaydırma: sonuna git, son kart tamamen görünür + alt pay; satır ve vitrin oynamaz.
	var bar_pos_before: Vector2 = bar.back_button().global_position
	var show_pos_before: Vector2 = showcase.global_position
	var max_scroll: float = scroll.get_v_scroll_bar().max_value - scroll.size.y
	scroll.scroll_vertical = int(max_scroll) + 10
	await get_tree().process_frame
	await get_tree().process_frame
	var last: Rect2 = cards[cards.size() - 1].get_global_rect()
	_c("%s galeri kaydırılabilir (max > 0), sonunda son kart tamamen ekranda, alt pay ≥ 40" % tag,
		max_scroll > 0.0 and last.end.y <= view.y - 40.0 and last.position.y >= gallery_y)
	_c("%s kaydırma üst satırı ve vitrini OYNATMADI (sabit)" % tag,
		bar.back_button().global_position == bar_pos_before and showcase.global_position == show_pos_before)
	_c("%s kaydırma sonunda ilk kart galerinin üstünden çıktı (vitrinin altında kırpılır)" % tag,
		cards[0].get_global_rect().end.y < gallery_y)
	scroll.scroll_vertical = 0
	await get_tree().process_frame
