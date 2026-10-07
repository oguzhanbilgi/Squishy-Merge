extends Node
## Profil (TASK/044) regresyon testi. Headless; kayıt dosyasını byte-identical
## geri koyar.
##
##   godot --headless --audio-driver Dummy --path . res://tools/profile_test.tscn
##
## Kontroller:
##   yapı      Main'de 5. ekran; reklam yüzeyi DEĞİL (Surface.NONE); üst satır
##             "PROFİL" · dişli çark (Hamur pill'i yok; TASK/057 Tur 2: geri oku yok); tek SettingsPanel;
##             Profil ekranı / modeli kayda YAZMAZ, satın almaz (TASK/045: tek yazma
##             yolu unvan seçici — progression_ui_test); TASK/045 bölümleri gerçek
##             (LV rozeti + XP rayı, unvan, BAŞARIMLAR); kamera / galeri yok; güçler
##             salt okunur (buton yok).
##   veri      yeni / orta / geç / eski (partial) kayıt: ad "Oyuncu", avatar (vitrin
##             başı ya da kanonik), 3 vitrin yuvası (0 / 1 / 3 dolu), altı
##             istatistik kanonik alanlardan (PlayerProfile ile aynı, uydurma
##             yok — boş değer "—"), güç stokları, koleksiyon N/20 + rarity.
##   rotalar   Ana Sayfa avatarı → Profil; kabuk ANA SAYFA / Android geri → Ana Sayfa; dişli
##             → Ayarlar (Profil'de kalınır; geri önce Ayarlar'ı kapatır); dolu
##             yuva → Koleksiyon'da o parçanın detayı; boş yuva / KOLEKSİYONA GİT
##             → Koleksiyon; Koleksiyon'daki vitrin değişikliği Profil'e yansır;
##             oyun içi HUD ayarları + mola AYNEN çalışır.
##   yatışma   hızlı çift dokunuş (A36 kapısı): ekran / detay / Ayarlar açılışından
##             sonra 300 ms PARMAK basışı yutulur — avatar → Profil (aynı nokta), kabuk ANA SAYFA → avatar, KOLEKSİYONA
##             GİT → albüm kartı, karartmaya düşen ikinci dokunuş; kod yolu
##             (`pressed.emit()`) ve masaüstü fare etkilenmez.
##   sayaçlar  gerçek round bitişi: tur +1 ve oluşturulan en yüksek tier (tek
##             sefer, ikinci _finish sayılmaz); terk edilen / yeniden başlatılan
##             round SAYILMAZ; Büyütücü tier'ı sayılır, merge sayacı değişmez.
##   reklam    sahte arka uçla: Ana Sayfa'da banner görünür, Profil'de gizlenir
##             (yeni reklam yüzeyi yok), Ana Sayfa'ya dönünce geri gelir.
##   yerleşim  7 pencere (320 / 360 / 390 / 540 / 720 / 1080 genişlik) + A36 payı:
##             kırpma / taşma / çakışma yok, dokunma ≥ 48, üst satır sabit, en alt
##             erişilebilir.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const VIEWS: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(720, 1560),
	Vector2i(540, 960), Vector2i(1080, 2340), Vector2i(320, 568), Vector2i(390, 844),
	Vector2i(360, 800)]
const A36_SAFE_TOP: float = 61.0
## `card_bevel_soft` dudağının üst kenarı: kart alt kenarından 22 px (sprite: yüz
## 0–36, dudak 37–47, kontur 48–49, gölge 50–58; alt dilim 30 px).
const CARD_LIP_TOP: float = 22.0
## Profil salt okunur: kayıt / ekonomi yazma yolu yok (TASK/045: unvan seçimi ayrı
## bileşende, `TitleSelector` → `SaveManager.select_title` — progression_ui_test).
const FORBIDDEN_CALLS: Array[String] = ["save_game(", "showcase_add(", "showcase_remove(", "showcase_replace(",
	"showcase_make_first(", "data[", "spend_dough", "add_dough", "purchase", "grant_", "record_", "select_title("]
## TASK/044'te "sahte XP / seviye / başarım yok" kontrolüydü; TASK/045 bu sistemleri
## GERÇEK olarak getirdi — artık ekranda bulunmaları beklenir.
const PROGRESSION_COPY: Array[String] = ["BAŞARIMLAR", "TÜM BAŞARIMLAR"]
## Kamera / galeri / dosya seçici / izin API'si yok (kodda, kelime sınırıyla).
const FORBIDDEN_API: Array[String] = ["Camera", "camera", "gallery", "Gallery", "FileDialog", "request_permission"]

var _fails: int = 0
var _checks: int = 0
var _saved: Dictionary = {}
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _main: Node2D
var _finished: bool = false
var _main_script: GDScript = load("res://scripts/main.gd")


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_saved = SaveManager.data.duplicate(true)
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.data["onboarding_completed"] = true
	_apply_fresh()
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 240 s'de bitmedi — kayıt geri kondu")
			SaveManager.data = _saved
			_restore_save_file()
			get_tree().quit(2))
	get_window().size = Vector2i(720, 1000)
	await get_tree().process_frame
	await _resize(VIEWS[0])
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _settle(2)
	var home: CanvasLayer = _main._screens[0]
	var profile: CanvasLayer = _main._screens[4]

	await _structure(profile)
	await _data_states(profile)
	await _routes(home, profile)
	await _touch_settle(home, profile)
	await _counters()
	await _layout_all(profile)
	await _ads_surface()

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
	print("  [FAIL] test SONUC'tan önce ağaçtan çıktı — kayıt geri kondu")
	SaveManager.data = _saved
	_restore_save_file()


# --- Yapı -------------------------------------------------------------------------

func _structure(profile: CanvasLayer) -> void:
	print("-- yapı / kaynak")
	_c("Main'de 5 ekran: Profil 4. indeks (ProfileScreen, katman 5)", _main._screens.size() == 5
		and profile.get_script().resource_path == "res://scripts/ui/profile_screen.gd" and profile.layer == 5)
	_c("Profil reklam yüzeyi DEĞİL: TAB_SURFACES[4] = NONE, BANNER_SURFACES'ta yok",
		_main.TAB_SURFACES[4] == MonetizationManager.Surface.NONE
		and not MonetizationManager.BANNER_SURFACES.has(MonetizationManager.Surface.NONE))
	var bar: ScreenTopBar = profile.top_bar()
	_c("üst satır: 'PROFİL' kurdelesi + dişli çark (ButtonHomeIcon, 56 px); Hamur pill'i YOK; TASK/057 Tur 2: geri oku YOK",
		bar.title_text() == "PROFİL" and bar.back_button() == null and profile.settings_button() != null
		and profile.settings_button().theme_type_variation == &"ButtonHomeIcon"
		and profile.settings_button().custom_minimum_size.x >= 48.0 and bar.add_button() == null
		and _count_variation(profile, &"PanelHomePill") == 0)
	_c("tek SettingsPanel (Profil kendi ayar penceresini KURMAZ)", _count_script(_main, "res://scripts/ui/settings_panel.gd") == 1
		and _count_script(profile, "res://scripts/ui/settings_panel.gd") == 0)
	var src: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/profile_screen.gd"))
	var slot_src: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/profile_showcase_slot.gd"))
	var tile_src: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/profile_stat_tile.gd"))
	var model_src: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/game/player_profile.gd"))
	var avatar_src: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/avatar_button.gd"))
	var writes: Array[String] = []
	for word in FORBIDDEN_CALLS:
		for text in [src, slot_src, tile_src, model_src, avatar_src]:
			if text.contains(word):
				writes.append(word)
	_c("Profil / model / yuva / avatar kayda YAZMAZ, satın almaz, ödül vermez (kaynak taraması) %s" % str(writes), writes.is_empty())
	_c("TASK/057 Tur 2: Profil kaynağında geri oku yok (home_requested / back_button() yok), ScreenTopBar'da back_pressed yok",
		not src.contains("home_requested") and not src.contains("back_button()")
		and not FileAccess.get_file_as_string("res://scripts/ui/screen_top_bar.gd").contains("back_pressed"))
	var fakes: Array[String] = []
	var word_re := RegEx.new()
	for text in [src, slot_src, tile_src, model_src, avatar_src]:
		for word in FORBIDDEN_API:
			word_re.compile("\\b%s\\b" % word)
			if word_re.search(text) != null:
				fakes.append(word)
	_c("kamera / galeri / dosya seçici / izin API'si yok %s" % str(fakes), fakes.is_empty())
	var literals: Array[String] = _string_literals(src)
	var missing: Array[String] = []
	for word in PROGRESSION_COPY:
		if not literals.has(word):
			missing.append(word)
	_c("TASK/045 gerçek: BAŞARIMLAR bölümü + TÜM BAŞARIMLAR, LV rozeti + XP rayı, unvan eylemi %s" % str(missing),
		missing.is_empty() and profile.level_bar() != null and profile.title_button() != null
		and profile.section(&"achievements") != null and profile.achievements_cta() != null)
	var power_buttons: int = 0
	for node in _all_nodes(profile.content().get_node("PowerRow")):
		if node is Button:
			power_buttons += 1
	_c("GÜÇLER salt okunur: 4 kutucuk, hiç buton yok (satın alma Mağaza'da)", profile.content().get_node("PowerRow").get_child_count() == 4
		and power_buttons == 0 and _count_variation(profile, &"ButtonBuyLocked") == 0)
	_c("bölüm başlıkları VİTRİN / BAŞARIMLAR / İSTATİSTİKLER / GÜÇLER / KOLEKSİYON", _section_text(profile, &"showcase") == "VİTRİN"
		and _section_text(profile, &"achievements") == "BAŞARIMLAR"
		and _section_text(profile, &"stats") == "İSTATİSTİKLER" and _section_text(profile, &"powers") == "GÜÇLER"
		and _section_text(profile, &"collection") == "KOLEKSİYON")
	_c("kimlik avatarı dokunma ALMAZ (dekor), yuvalar ve CTA alır (PASS: kaydırma yuvanın üstünden de başlar)",
		profile.avatar().mouse_filter == Control.MOUSE_FILTER_IGNORE
		and profile.showcase_slots()[0].mouse_filter == Control.MOUSE_FILTER_PASS)


# --- Veri durumları ----------------------------------------------------------------

func _data_states(profile: CanvasLayer) -> void:
	print("-- yeni oyuncu (0 vitrin)")
	_apply_fresh()
	_main._show_tab(4)
	await _settle(1)
	var file_before: PackedByteArray = _bytes()
	_c("ad 'Oyuncu' (nötr, yerel); 'Bu cihazdaki profilin'", profile.player_name_text() == "Oyuncu"
		and PlayerProfile.display_name() == "Oyuncu" and _collect_text(profile.content().get_node("Identity")).contains("Bu cihazdaki profilin"))
	_c("avatar kanonik Squishy (lavanta halka), kural ipucu görünür, avatar satırı gizli", profile.avatar().entry().is_default()
		and profile.avatar().art_texture() == SkinEntry.PREVIEW_BASE_TEXTURE and profile.avatar().ring_color() == UiTokens.LAVENDER_DEEP
		and profile.avatar_hint_visible() and profile.avatar_line_text() == "")
	var slots: Array = profile.showcase_slots()
	_c("3 vitrin yuvası, hepsi BOŞ YUVA (+ 'Koleksiyondan ekle'), rozet gizli", slots.size() == 3
		and not slots[0].is_filled() and not slots[1].is_filled() and not slots[2].is_filled()
		and _collect_text(slots[0]).contains("BOŞ YUVA") and _collect_text(slots[2]).contains("Koleksiyondan ekle"))
	_c("SONSUZ REKOR '—' + 'Sonsuz mod kilitli' (0 uydurulmaz)", _tile(profile, &"endless").value_text() == "—"
		and _tile(profile, &"endless").note_text() == "Sonsuz mod kilitli")
	_c("BİRLEŞTİRME 0 · YILDIZ 0/30 · TAMAMLANAN LEVEL 0/10 · OYNANAN TUR 0 (not yok) · EN YÜKSEK TIER '—'",
		_tile(profile, &"merges").value_text() == "0" and _tile(profile, &"stars").value_text() == "0/%d" % PlayerProfile.max_stars()
		and _tile(profile, &"levels").value_text() == "0/%d" % PlayerProfile.level_count()
		and _tile(profile, &"rounds").value_text() == "0" and _tile(profile, &"rounds").note_text() == ""
		and _tile(profile, &"tier").value_text() == "—")
	_c("yıldız tavanı level sayısı × 3 (30), level sayısı 10", PlayerProfile.max_stars() == 30 and PlayerProfile.level_count() == 10)
	_c("güç stokları canlı (yeni: ×1 ×1 ×1 ×1)", _powers_match(profile))
	_c("koleksiyon 0/20, YAYGIN 0/8 … EFSANEVİ 0/2, KOLEKSİYONA GİT", profile.collection_count_text() == "0/20"
		and profile.collection_chip_text(SkinData.Rarity.COMMON) == "YAYGIN 0/8"
		and profile.collection_chip_text(SkinData.Rarity.LEGENDARY) == "EFSANEVİ 0/2"
		and (profile.collection_cta().get_meta(&"title_label") as Label).text == "KOLEKSİYONA GİT")
	_c("Profil'i açmak / tazelemek kayıt dosyasını değiştirmedi", _bytes() == file_before)

	print("-- orta oyuncu (1 vitrin)")
	_apply_mid()
	profile.refresh()
	await _settle(1)
	_c("avatar = vitrin başı rare_02 (Rare mavi halka), satır 'Kırmızı Biber' + NADİR, ipucu gizli",
		profile.avatar().entry().id == &"rare_02" and profile.avatar().ring_color() == UiTokens.RARITY_RARE
		and profile.avatar_line_text() == "Kırmızı Biber" and not profile.avatar_hint_visible()
		and _collect_text(profile.content().get_node("Identity")).contains("NADİR"))
	slots = profile.showcase_slots()
	_c("yuva 1 dolu (Kırmızı Biber, altın AVATAR rozeti, NADİR); yuva 2–3 boş", slots[0].is_filled()
		and slots[0].name_text() == "Kırmızı Biber" and slots[0].badge_text() == "AVATAR"
		and _collect_text(slots[0]).contains("NADİR") and not slots[1].is_filled() and not slots[2].is_filled())
	_c("dolu yuva sahnesi final sanat (kilit yok)", slots[0].stage().swatch()._image.texture == SkinLibrary.find(&"rare_02").preview_texture
		and not slots[0].stage().swatch()._lock.visible)
	var expected_tier: int = _expected_tier(5)
	_c("istatistikler kanonik: BİRLEŞTİRME '%s', YILDIZ 11/30 (bozuk değerler kırpıldı / yok sayıldı), LEVEL 4/10, TUR 17"
		% GameplayHud._thousands(1234), _tile(profile, &"merges").value_text() == GameplayHud._thousands(1234)
		and _tile(profile, &"stars").value_text() == "11/30" and PlayerProfile.total_stars() == 11
		and _tile(profile, &"levels").value_text() == "4/10" and _tile(profile, &"rounds").value_text() == "17")
	_c("EN YÜKSEK TIER = max(kayıt 5, tamamlanan level hedefleri) = %d (%s); level'lardan türediği için 'en az' notu"
		% [expected_tier, TierConfig.tier_name(expected_tier)],
		expected_tier > 5 and PlayerProfile.highest_tier() == expected_tier and PlayerProfile.highest_tier_is_lower_bound()
		and _tile(profile, &"tier").value_text() == TierConfig.tier_name(expected_tier)
		and _tile(profile, &"tier").note_text() == "Tier %d · en az" % expected_tier
		and _tile(profile, &"tier").art_texture() == preload("res://scripts/game/dumpling_visual.gd").TEXTURES[expected_tier - 1])
	_c("güç stokları ×3 ×1 ×0 ×2 (0 soluk)", _powers_match(profile) and profile.power_count_text(PowerUp.Type.SHAKE) == "×0")
	_c("koleksiyon 6/20, YAYGIN 3/8, NADİR 2/6, EPİK 1/4", profile.collection_count_text() == "6/20"
		and profile.collection_chip_text(SkinData.Rarity.COMMON) == "YAYGIN 3/8"
		and profile.collection_chip_text(SkinData.Rarity.RARE) == "NADİR 2/6"
		and profile.collection_chip_text(SkinData.Rarity.EPIC) == "EPİK 1/4")

	print("-- geç oyuncu (3 vitrin, sonsuz açık, 20/20)")
	_apply_late()
	profile.refresh()
	await _settle(1)
	slots = profile.showcase_slots()
	_c("3 yuva dolu, yuva sırasıyla: Gökkuşağı (AVATAR) · Kakao (2. YUVA) · Kırmızı Biber (3. YUVA)",
		slots[0].name_text() == "Gökkuşağı" and slots[0].badge_text() == "AVATAR"
		and slots[1].name_text() == "Kakao" and slots[1].badge_text() == "2. YUVA"
		and slots[2].name_text() == "Kırmızı Biber" and slots[2].badge_text() == "3. YUVA")
	_c("avatar Legendary (altın halka)", profile.avatar().entry().id == &"legendary_02" and profile.avatar().ring_color() == UiTokens.GOLD)
	_c("SONSUZ REKOR '%s' (not yok) · LEVEL 10/10 + 'Sonsuz mod açık' · YILDIZ 30/30 · TUR '%s' · TIER 8"
		% [GameplayHud._thousands(12480), GameplayHud._thousands(1250)],
		_tile(profile, &"endless").value_text() == GameplayHud._thousands(12480) and _tile(profile, &"endless").note_text() == ""
		and _tile(profile, &"levels").value_text() == "10/10" and _tile(profile, &"levels").note_text() == "Sonsuz mod açık"
		and _tile(profile, &"stars").value_text() == "30/30" and _tile(profile, &"rounds").value_text() == GameplayHud._thousands(1250)
		and _tile(profile, &"tier").value_text() == TierConfig.tier_name(8) and _tile(profile, &"tier").note_text() == "Tier 8"
		and not PlayerProfile.highest_tier_is_lower_bound())
	_c("koleksiyon 20/20: altın ray + yıldız, EFSANEVİ 2/2", profile.collection_count_text() == "20/20"
		and profile._collection_bar.theme_type_variation == &"ProgressBarGold" and profile._collection_star.visible
		and profile.collection_chip_text(SkinData.Rarity.LEGENDARY) == "EFSANEVİ 2/2")
	_c("güç stokları ×99 ×12 ×0 ×7", _powers_match(profile) and profile.power_count_text(PowerUp.Type.BOMB) == "×99")

	print("-- eski kayıt (sayaçlar güncellemeden beri)")
	SaveManager.data["profile_counters_partial"] = true
	SaveManager.data["total_rounds_played"] = 3
	profile.refresh()
	_c("partial kayıt: TUR '3' + 'güncellemeden beri' notu (geçmiş uydurulmaz)", _tile(profile, &"rounds").value_text() == "3"
		and _tile(profile, &"rounds").note_text() == "güncellemeden beri")
	_c("PlayerProfile.snapshot tutarlı (ekranla aynı kaynak)", PlayerProfile.snapshot()["rounds_played"] == 3
		and PlayerProfile.snapshot()["counters_partial"] == true and PlayerProfile.snapshot()["collection_count"] == 20)


# --- Rotalar -----------------------------------------------------------------------

func _routes(home: CanvasLayer, profile: CanvasLayer) -> void:
	print("-- rotalar")
	_apply_mid()
	_main._show_tab(0)
	await _settle(1)
	# TASK/058: Ana Sayfa avatarı kaldırıldı — Profil girişi kabuğun PROFİL öğesi (niyet aynı).
	_main.global_nav().item_button(4).pressed.emit()
	await _settle(1)
	_c("kabuk PROFİL → Profil (yalnız Profil görünür)", _main._active_tab == 4 and profile.visible and not home.visible)
	profile.settings_button().pressed.emit()
	await _settle(1)
	_c("dişli çark → Ayarlar (Main'in tek paneli), Profil altta açık", _main._settings.visible and _main._active_tab == 4
		and profile.visible)
	_main._last_back_msec = -1000
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("Ayarlar açıkken Android geri → yalnız Ayarlar kapanır, Profil'de kalınır", not _main._settings.visible
		and _main._active_tab == 4)
	profile.settings_button().pressed.emit()
	_main.close_settings()
	_c("Ayarlar KAPAT → Profil'de kalınır", not _main._settings.visible and _main._active_tab == 4)
	# TASK/057 Tur 2: Profil üst çubuğunda geri oku yok — Ana Sayfa'ya dönüş küresel kabuğun ANA SAYFA öğesi.
	var nav_before: int = _main.nav_navigations
	_main.global_nav().item_button(0).pressed.emit()
	_c("Profil'de kabuk ANA SAYFA → Ana Sayfa (tam 1 gezinme)", _main._active_tab == 0 and home.visible
		and not profile.visible and _main.nav_navigations == nav_before + 1)
	_main._show_tab(4)
	_main._last_back_msec = -1000
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("Profil'de Android geri → Ana Sayfa (uygulama kapanmaz)", _main._active_tab == 0 and home.visible)
	_main._show_tab(4)
	await _settle(1)
	var album: CanvasLayer = _main._screens[2]
	profile.showcase_slots()[0].pressed.emit()
	await _settle(1)
	_c("dolu yuva (Kırmızı Biber) → Koleksiyon, o parçanın detayı açık", _main._active_tab == 2 and album.visible
		and album.is_detail_open() and album.detail_id() == &"rare_02" and album.detail_state_text() == "VİTRİNDE")
	album.close_detail(false)
	_main._show_tab(4)
	await _settle(1)
	profile.showcase_slots()[2].pressed.emit()
	await _settle(1)
	_c("boş yuva → Koleksiyon (detay kapalı)", _main._active_tab == 2 and album.visible and not album.is_detail_open())
	album.card(&"epic_01").pressed.emit()
	album.detail_primary().pressed.emit()
	await _settle(1)
	_c("ön koşul: Koleksiyon'da epic_01 vitrine eklendi", _showcase_is(["rare_02", "epic_01"]))
	album.close_detail(false)
	_main._show_tab(4)
	await _settle(1)
	_c("Profil'e dönünce 2. yuva Acı Sos (vitrin değişikliği yansıdı)", profile.showcase_slots()[1].is_filled()
		and profile.showcase_slots()[1].name_text() == "Acı Sos")
	_c("kabuk PROFİL avatarı da güncel (vitrin başı rare_02)",
		_main.global_nav().item_button(4).avatar().entry().id == &"rare_02")
	profile.collection_cta().pressed.emit()
	await _settle(1)
	_c("KOLEKSİYONA GİT → Koleksiyon", _main._active_tab == 2 and album.visible)
	print("-- oyun içi ayarlar / mola korunuyor")
	_main._start_level(_level(2))
	await _settle(2)
	_main._board.settings_requested.emit()
	await _settle(1)
	_c("oyun içi HUD ayarları → aynı Ayarlar paneli, board menü duraklatmasında", _main._settings.visible
		and _main._board._is_paused())
	_main.close_settings()
	await _settle(1)
	_c("Ayarlar kapanınca board çözüldü", not _main._settings.visible and not _main._board._is_paused())
	_main.open_pause_menu()
	_c("mola penceresi açılıyor", _main.is_pause_open())
	_main.resume_game()
	_c("mola kapanıyor, board çözüldü", not _main.is_pause_open() and not _main._board._is_paused())
	_main.abandon_run()
	await _settle(1)


## TASK/057: Profil'i, KOLEKSİYONA GİT'in ortası albümün (açılışta kaydırma 0) bir kartının içine düşecek kadar
## yukarıdan geri kaydırır; CTA kabuğun ayak izinin üstünde kalır. Uygun konum yoksa dokunmaz (ön koşul FAIL eder).
func _align_cta_over_album_card(profile: CanvasLayer, album: CanvasLayer) -> void:
	var scroll: ScrollContainer = profile.scroll()
	var cta: Control = profile.collection_cta()
	var rect: Rect2 = cta.get_global_rect()
	var floor_y: float = get_viewport().get_visible_rect().size.y
	if _main.has_method("global_nav"):
		floor_y = (_main.call("global_nav") as Object).call("footprint").position.y
	var offset: float = float(album.scroll().scroll_vertical)
	for card: CollectionSkinCard in album.cards():
		var card_rect: Rect2 = card.get_global_rect()
		card_rect.position.y += offset
		if card_rect.position.x > rect.get_center().x or card_rect.end.x < rect.get_center().x:
			continue
		var target: float = maxf(card_rect.position.y + 10.0, rect.get_center().y)
		if target > card_rect.end.y - 10.0 or target + rect.size.y * 0.5 > floor_y - 2.0:
			continue
		var delta: float = target - rect.get_center().y
		if delta > float(scroll.scroll_vertical):
			continue
		scroll.scroll_vertical = int(float(scroll.scroll_vertical) - ceilf(delta))
		await _settle(2)
		await _wait_settled()
		return


# --- Geçiş sonrası parmak yatışması (TASK/044 A36 kapısı) ----------------------------

## A36'da gerçek hızlı çift dokunuş (ikinci basış ilk bırakıştan ~130–150 ms sonra):
## Ana Sayfa avatarı → Profil açıldı, ikinci dokunuş AYNI dikdörtgendeki Profil geri'sine
## düşüp Ana Sayfa'ya döndü; KOLEKSİYONA GİT → altındaki albüm kartının detayı açıldı;
## parça detayı / Profil dişlisi → pencere ikinci dokunuşta karartmadan kapandı. Main
## geçişten sonra TOUCH_SETTLE_MSEC boyunca PARMAK basışlarını yutar. Burada gerçek
## parmak olayı enjekte edilir (ScreenTouch, device 0 — Godot fareyi dokunuştan
## öykünür, cihazdaki sıra); kod yolu ve masaüstü fare ayrıca sınanır.
func _touch_settle(home: CanvasLayer, profile: CanvasLayer) -> void:
	print("-- geçiş sonrası parmak yatışması (hızlı çift dokunuş, A36)")
	_apply_mid()
	var album: CanvasLayer = _main._screens[2]
	var settle_msec: int = int(_main_script.get_script_constant_map().get("TOUCH_SETTLE_MSEC", -1))
	_c("yatışma süresi 300 ms (Android çift dokunuş penceresi)", settle_msec == 300)
	_main._show_tab(0)
	await _wait_settled()
	# TASK/058: Ana Sayfa avatarı kaldırıldı — aynı senaryo kabuğun PROFİL öğesiyle (Ana Sayfa → Profil girişi).
	var avatar_pos: Vector2 = _screen_center(_main.global_nav().item_button(4))
	# TASK/057 Tur 2: Profil üst çubuğunda geri oku yok — avatarın noktasında artık Profil geri'si yok; Ana Sayfa'ya
	# dönüş kabuğun ANA SAYFA öğesi (parmakla).
	_c("ön koşul (TASK/057 Tur 2): Profil üst çubuğunda geri oku yok (back_button() null)",
		profile.top_bar().back_button() == null)
	var home_item: Button = _main.global_nav().item_button(0)
	await _finger_tap(avatar_pos)
	_c("parmak dokunuşu: kabuk PROFİL → Profil", _main._active_tab == 4 and profile.visible)
	# TASK/058: aynı noktaya ikinci dokunuş (zaten seçili PROFİL) her durumda 0 gezinmedir — yatışma, FARKLI bir hedefe
	# (kabuk ANA SAYFA) hemen ikinci dokunuşla sınanır.
	await _finger_tap(_screen_center(home_item))
	_c("hemen ikinci dokunuş (kabuk ANA SAYFA) yutuldu: Profil'de kalındı", _main._active_tab == 4
		and profile.visible)
	await _wait_settled()
	var nav_before: int = _main.nav_navigations
	await _finger_tap(_screen_center(home_item))
	_c("yatışmadan sonra kabuk ANA SAYFA parmakla çalışır → Ana Sayfa (tam 1 gezinme)", _main._active_tab == 0
		and home.visible and _main.nav_navigations == nav_before + 1)
	await _finger_tap(avatar_pos)
	_c("geri dönüşün hemen ardından PROFİL dokunuşu yutuldu (Profil açılmadı)", _main._active_tab == 0)
	await _wait_settled()
	await _finger_tap(avatar_pos)
	_c("yatışmadan sonra PROFİL yine Profil'i açar", _main._active_tab == 4)

	var scroll: ScrollContainer = profile.scroll()
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _settle(2)
	await _wait_settled()
	# TASK/057: küresel gezinme kabuğu Profil'in alt payını büyüttü — en alta kaydırılmış KOLEKSİYONA GİT artık
	# albümün bir kartına değil bölüm başlığına denk geliyor. Senaryo aynen (geçişte çift dokunuşun ikincisi
	# albüm kartına SIZMAZ): Profil, CTA'nın ortası (kabuğun üstünde kalarak) açılıştaki albümün bir kartının
	# üstüne gelecek kadar geri kaydırılır.
	await _align_cta_over_album_card(profile, album)
	var cta_pos: Vector2 = _screen_center(profile.collection_cta())
	await _finger_tap(cta_pos)
	_c("KOLEKSİYONA GİT (parmak) → Koleksiyon", _main._active_tab == 2 and album.visible)
	var card_under: CollectionSkinCard = null
	for card: CollectionSkinCard in album.cards():
		if card.get_global_rect().has_point(get_viewport().get_screen_transform().affine_inverse() * cta_pos) \
				and album.scroll().get_global_rect().has_point(card.get_global_rect().get_center()):
			card_under = card
	_c("ön koşul: aynı noktada bir albüm kartı var", card_under != null)
	await _finger_tap(cta_pos)
	_c("hemen ikinci dokunuş altındaki albüm kartını AÇMADI", not album.is_detail_open())
	await _wait_settled()
	await _finger_tap(cta_pos)
	_c("yatışmadan sonra aynı kart parmakla detayı açar", album.is_detail_open()
		and card_under != null and album.detail_id() == card_under.skin_id())
	var frame: Rect2 = album.detail_frame().get_global_rect()
	var dim_canvas := Vector2(frame.get_center().x, frame.end.y + 40.0)
	if dim_canvas.y >= get_viewport().get_visible_rect().size.y - 8.0:
		dim_canvas.y = frame.position.y - 40.0
	var dim_pos: Vector2 = get_viewport().get_screen_transform() * dim_canvas
	await _finger_tap(dim_pos)
	_c("detay açılışının hemen ardından karartmaya dokunuş yutuldu: detay açık kaldı", album.is_detail_open())
	await _wait_settled()
	await _finger_tap(dim_pos)
	_c("yatışmadan sonra karartmaya dokunuş detayı kapatır (UiKit sözleşmesi aynen)", not album.is_detail_open())

	_main._show_tab(4)
	await _wait_settled()
	var gear_pos: Vector2 = _screen_center(profile.settings_button())
	await _finger_tap(gear_pos)
	_c("Profil dişlisi (parmak) → Ayarlar", _main._settings.visible)
	await _finger_tap(gear_pos)
	_c("hemen ikinci dokunuş Ayarlar'ın karartmasına düştü ama pencere açık kaldı", _main._settings.visible)
	await _wait_settled()
	_main.close_settings()

	print("-- yatışma kod yolunu / masaüstü fareyi etkilemez")
	_main._show_tab(0)
	_main.global_nav().item_button(4).pressed.emit()
	_c("kod yolu: geçişin hemen ardından pressed.emit() → Profil", _main._active_tab == 4)
	home_item.pressed.emit()
	_c("kod yolu: geçişin hemen ardından kabuk ANA SAYFA → Ana Sayfa", _main._active_tab == 0)
	_main._show_tab(4)
	await _mouse_click(_screen_center(home_item))
	_c("masaüstü fare tıklaması (device 0) geçişin hemen ardından kabuk ANA SAYFA'da çalışır → Ana Sayfa", _main._active_tab == 0)
	await _wait_settled()


# --- Sayaçlar ----------------------------------------------------------------------

func _counters() -> void:
	print("-- profil sayaçları (gerçek round)")
	_apply_mid()
	SaveManager.data["total_rounds_played"] = 17
	SaveManager.data["highest_tier_created"] = 3
	SaveManager.data["profile_counters_partial"] = false
	var merges_before: int = SaveManager.total_merges()
	_main._start_level(_level(2))
	await _settle(2)
	_c("round başında GameState.highest_tier_created 0", GameState.highest_tier_created == 0)
	GameState.register_merge(5, Vector2(360, 700))
	GameState.note_tier_created(4)
	var merge_count: int = GameState.merge_count
	_c("merge tier 5 kaydı; Büyütücü notu (4) rekoru düşürmez, merge sayacını ARTIRMAZ", GameState.highest_tier_created == 5
		and merge_count == 1)
	_main._board._finish(false)
	_main._board._finish(false)
	await get_tree().create_timer(_main.RESULT_DELAY + 0.3).timeout
	await _settle(2)
	_c("bitmiş round: tur 17 → 18 (çift _finish tek sayım), rekor tier 3 → 5, kayıtta aynı", SaveManager.total_rounds_played() == 18
		and SaveManager.highest_tier_created() == 5 and int(_read_save_file().get("total_rounds_played", -1)) == 18
		and int(_read_save_file().get("highest_tier_created", -1)) == 5)
	_c("toplam merge kanonik yoldan (round'un 1 merge'ü) — profil sayaçları merge'e dokunmadı",
		SaveManager.total_merges() == merges_before + 1)
	_main.abandon_run()
	await _settle(1)
	_main._start_level(_level(2))
	await _settle(2)
	GameState.register_merge(7, Vector2(360, 700))
	_main.abandon_run()
	await _settle(1)
	_c("terk edilen round SAYILMAZ (tur 18, rekor 5 — tier 7 yazılmadı)", SaveManager.total_rounds_played() == 18
		and SaveManager.highest_tier_created() == 5)
	_main._start_level(_level(2))
	await _settle(2)
	GameState.register_merge(6, Vector2(360, 700))
	_main._on_pause_restart()
	await _settle(2)
	_c("yeniden başlatılan round SAYILMAZ, yeni round'un rekoru sıfırdan", SaveManager.total_rounds_played() == 18
		and SaveManager.highest_tier_created() == 5 and GameState.highest_tier_created == 0)
	_main.abandon_run()
	await _settle(1)


# --- Yerleşim ----------------------------------------------------------------------

func _layout_all(profile: CanvasLayer) -> void:
	print("-- yerleşim")
	_apply_late()
	for view in VIEWS:
		await _resize(view)
		_main._show_tab(0)
		_main._show_tab(4)
		await _settle(2)
		await _check_layout(profile, 0.0, "%dx%d" % [view.x, view.y])
	await _resize(VIEWS[3])
	profile._layout_with_safe_top(A36_SAFE_TOP)
	await _settle(2)
	await _check_layout(profile, A36_SAFE_TOP, "1080x2340")
	profile._layout_with_safe_top(-1.0)
	_apply_fresh()
	profile.refresh()
	await _resize(VIEWS[4])
	_main._show_tab(0)
	_main._show_tab(4)
	await _settle(2)
	await _check_layout(profile, 0.0, "320x568 yeni oyuncu")
	await _resize(VIEWS[0])


func _check_layout(profile: CanvasLayer, safe_top: float, window_tag: String) -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var tag: String = "%s (tuval %dx%d)%s" % [window_tag, roundi(view.x), roundi(view.y), " +A36" if safe_top > 0.0 else ""]
	var scroll: ScrollContainer = profile.scroll()
	scroll.scroll_vertical = 0
	await get_tree().create_timer(0.3).timeout
	await get_tree().process_frame
	var bar: ScreenTopBar = profile.top_bar()
	var screen_rect: Rect2 = Rect2(Vector2(0, safe_top), Vector2(view.x, view.y - safe_top))
	# TASK/057 Tur 2: üst satırda geri oku yok — satır = kurdele + dişli.
	var gear: Rect2 = profile.settings_button().get_global_rect()
	var ribbon: Rect2 = bar.title_plate().get_global_rect()
	_c("%s üst satır güvenli payın altında: dişli ≥ 48, ekranda; kurdele dişliye binmez; geri oku yok" % tag,
		bar.back_button() == null and screen_rect.encloses(gear) and gear.size.x >= 48.0 and gear.size.y >= 48.0
		and gear.position.y >= safe_top + ScreenTopBar.TOP_MARGIN - 0.5
		and not ribbon.intersects(gear) and gear.end.x <= view.x - 24.0 + 0.5)
	var content: VBoxContainer = profile.content()
	var inside: bool = true
	var prev_bottom: float = -INF
	var order_ok: bool = true
	for child in content.get_children():
		var c: Control = child
		if not c.visible:
			continue
		var r: Rect2 = c.get_global_rect()
		if r.position.x < 24.0 - 0.5 or r.end.x > view.x - 24.0 + 0.5:
			inside = false
			print("    yatay taşma: ", c.name, " ", r)
		if r.position.y < prev_bottom - 0.5:
			order_ok = false
			print("    bölüm çakışması: ", c.name, " ", r)
		prev_bottom = r.end.y
	_c("%s bölümler 24..W-24 içinde, üst üste binmeden sırayla" % tag, inside and order_ok)
	var first: Rect2 = content.get_child(0).get_global_rect()
	_c("%s kimlik kartı üst satırın altında başlar" % tag, first.position.y >= bar.height() + 4.0)
	var clipped: Array[String] = []
	for node in _all_nodes(content):
		if node is Label and (node as Label).is_visible_in_tree() and not (node as Label).autowrap_mode:
			var l: Label = node
			if _text_width(l, l.text) > l.size.x + 0.5:
				clipped.append(l.text)
	_c("%s tek satırlık yazılar kırpılmadan sığıyor (ad, istatistik değer/etiketleri, güç adları, yuva adları, çipler) %s"
		% [tag, str(clipped)], clipped.is_empty())
	var slots_ok: bool = true
	var slots: Array = profile.showcase_slots()
	for i in slots.size():
		var r: Rect2 = slots[i].get_global_rect()
		if r.size.x < 48.0 or r.size.y < 48.0:
			slots_ok = false
		for j in range(i + 1, slots.size()):
			if r.intersects(slots[j].get_global_rect()):
				slots_ok = false
		var badge: Rect2 = slots[i]._badge.get_global_rect()
		if slots[i].is_filled() and (not r.grow(2.0).encloses(Rect2(badge.position.x, r.position.y, badge.size.x, 1.0))
				or badge.end.y > r.position.y + badge.size.y):
			slots_ok = false
	_c("%s 3 yuva çakışmıyor, ≥ 48 dokunma, rozet kartın üst kenarına oturuyor" % tag, slots_ok)
	var tiles_ok: bool = true
	for key in [&"endless", &"merges", &"stars", &"levels", &"rounds", &"tier"]:
		var t: ProfileStatTile = profile.stat_tile(key)
		var tr: Rect2 = t.get_global_rect()
		for node in _all_nodes(t):
			if node is Label and (node as Label).is_visible_in_tree():
				if not tr.encloses((node as Label).get_global_rect()):
					tiles_ok = false
					print("    istatistik yazısı kutucuk dışı: ", key, " ", (node as Label).text)
	_c("%s istatistik yazıları (değer / etiket / not) kutucuğun içinde" % tag, tiles_ok)
	# `card_bevel_soft`'un pişmiş alt dudağı kartın alt kenarından 11–22 px yukarıda
	# (sprite ölçümü): yazı / buton / avatar krem yüzde kalmalı (TASK/044 merceği 6).
	var lip_ok: bool = true
	var cards: Array[Control] = [content.get_node("Identity"), content.get_node("CollectionCard"),
		content.get_node("AchievementsCard")]
	for key in [&"endless", &"merges", &"stars", &"levels", &"rounds", &"tier"]:
		cards.append(profile.stat_tile(key))
	for tile in content.get_node("PowerRow").get_children():
		cards.append(tile)
	for slot_node in profile.showcase_slots():
		cards.append(slot_node)
	for card in cards:
		var cr: Rect2 = card.get_global_rect()
		for node in _all_nodes(card):
			if node == card or not (node is Label or node is Button) or not (node as Control).is_visible_in_tree():
				continue
			var nr: Rect2 = (node as Control).get_global_rect()
			if nr.end.y > cr.end.y - CARD_LIP_TOP + 0.5:
				lip_ok = false
				print("    alt dudağa biniyor: ", card.name, " / ", node.name, " ", nr, " kart ", cr)
	_c("%s kart içerikleri (yazı / buton / avatar) krem yüzde — pişmiş alt dudağa binmiyor" % tag, lip_ok)
	var max_scroll: float = maxf(scroll.get_v_scroll_bar().max_value - scroll.size.y, 0.0)
	var bar_before: Vector2 = profile.settings_button().global_position
	scroll.scroll_vertical = int(max_scroll) + 10
	await get_tree().process_frame
	await get_tree().process_frame
	var cta: Rect2 = profile.collection_cta().get_global_rect()
	_c("%s kaydırma sonunda KOLEKSİYONA GİT tamamen ekranda, alt pay ≥ 40, ≥ 48 yükseklik; üst satır sabit" % tag,
		cta.end.y <= view.y - 40.0 - UiKit.bottom_inset(view) + 0.5 and cta.position.y >= bar.height()
		and cta.size.y >= 48.0 and profile.settings_button().global_position == bar_before)
	scroll.scroll_vertical = 0
	await get_tree().process_frame


# --- Reklam yüzeyi -----------------------------------------------------------------

func _ads_surface() -> void:
	print("-- reklam: Profil banner yüzeyi DEĞİL (sahte arka uç)")
	_main.queue_free()
	_main = null
	await _settle(2)
	_apply_mid()
	SaveManager.data["age_ad_band"] = "ADULT"
	SaveManager.data["next_age_transition_date"] = ""
	SaveManager.data["onboarding_completed"] = true
	SaveManager.data["onboarding_completed_day"] = ""
	SaveManager.save_game()
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	_main_script.set("ads_backend_override", fake)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _settle(3)
	_main_script.set("ads_backend_override", null)
	fake.complete_consent_update(true)
	fake.complete_init()
	await _settle(2)
	var ads: MonetizationManager = _main._ads
	if fake.banner_loads > 0:
		fake.complete_banner_load(true)
	await _settle(2)
	_c("ön koşul: Ana Sayfa'da banner gösterildi (yüzey HOME)", ads != null and ads.surface() == MonetizationManager.Surface.HOME
		and ads.banner_state() == MonetizationManager.BannerState.SHOWN)
	var hides_before: int = fake.banner_hides.size()
	_main.global_nav().item_button(4).pressed.emit()
	await _settle(2)
	_c("Profil açılınca yüzey NONE, banner GİZLENDİ (yeni reklam yüzeyi yok)", _main._active_tab == 4
		and ads.surface() == MonetizationManager.Surface.NONE and ads.banner_state() != MonetizationManager.BannerState.SHOWN
		and fake.banner_hides.size() == hides_before + 1)
	var interstitial_before: int = fake.interstitial_shows.size()
	var rewarded_before: int = fake.rewarded_shows.size()
	_main._screens[4].settings_button().pressed.emit()
	await _settle(1)
	_main.close_settings()
	_c("Profil / Ayarlar geçişi geçiş reklamı ya da ödüllü reklam açmadı", fake.interstitial_shows.size() == interstitial_before
		and fake.rewarded_shows.size() == rewarded_before)
	# TASK/057 Tur 2: Profil üst çubuğunda geri oku yok — Ana Sayfa'ya dönüş kabuğun ANA SAYFA öğesi.
	_main.global_nav().item_button(0).pressed.emit()
	await _settle(2)
	_c("Ana Sayfa'ya dönünce banner geri geldi", _main._active_tab == 0 and ads.surface() == MonetizationManager.Surface.HOME
		and ads.banner_state() == MonetizationManager.BannerState.SHOWN)
	# TASK/043 yolu artık Profil'den (inceleme merceği 7): dişli → Yaş bilgisi →
	# SDK sonrası farklı bant → oturum reklamsız; Ana Sayfa'da banner geri GELMEZ.
	_main.global_nav().item_button(4).pressed.emit()
	await _settle(2)
	_main._screens[4].settings_button().pressed.emit()
	await _settle(2)
	_c("Profil dişlisinden açılan Ayarlar'da 'Yaş bilgisi → Güncelle' satırı görünür (TASK/043 aynen)",
		_main._settings.visible and _main._settings.age_info_row().visible
		and _main._settings.age_info_button().text == "Güncelle")
	var shows_before: int = fake.banner_shows.size()
	_main._settings.age_info_button().pressed.emit()
	await _settle(2)
	var panel: CanvasLayer = _main.age_panel()
	_c("yeniden giriş paneli Ayarlar'ın üstünde, Profil altta", panel.visible and panel.is_reentry()
		and panel.layer > _main._settings.layer and _main._active_tab == 4)
	await _enter_dob(panel, "15062011")
	_c("ADULT → TEEN (SDK yapılandırılmış): kayıt TEEN, oturum reklamsız (TASK/043 kilidi)",
		SaveManager.age_ad_band_raw() == "TEEN" and ads.age_session_blocked())
	panel.done_button().pressed.emit()
	_main.close_settings()
	await _settle(1)
	_main.global_nav().item_button(0).pressed.emit()
	await _settle(2)
	_c("Ana Sayfa'ya dönünce banner GERİ GELMEDİ (oturum kilidi Profil yolundan da geçerli)", _main._active_tab == 0
		and ads.banner_state() != MonetizationManager.BannerState.SHOWN and fake.banner_shows.size() == shows_before)
	_main.queue_free()
	_main = null
	await _settle(2)
	UiKit.set_banner_slot(0.0)


# --- Yardımcılar -------------------------------------------------------------------

## Yaş ekranında tarih seçimi (TASK/046.1 GÜN / AY / YIL seçicileri; age_ad_routing_test ile
## aynı yol): yıl, ay, gün ızgaradan; DEVAM ET; ONAYLA.
func _enter_dob(panel: CanvasLayer, ddmmyyyy: String) -> void:
	var values: Array[int] = [int(ddmmyyyy.substr(4, 4)), int(ddmmyyyy.substr(2, 2)), int(ddmmyyyy.substr(0, 2))]
	var fields: Array[int] = [2, 1, 0]
	for i in 3:
		panel.selector_button(fields[i]).pressed.emit()
		if panel.option_button(values[i]) == null:
			panel.close_picker()
			continue
		panel.option_button(values[i]).pressed.emit()
	panel.continue_button().pressed.emit()
	await _settle(1)
	panel.confirm_button().pressed.emit()
	await _settle(2)

func _apply_fresh() -> void:
	SaveManager.data["highest_level_unlocked"] = 1
	SaveManager.data["level_stars"] = {}
	SaveManager.data["dough"] = 0
	SaveManager.data["unlocked_skins"] = []
	SaveManager.data["profile_showcase"] = []
	SaveManager.data["powerups"] = {"bomb": 1, "upgrade": 1, "shake": 1, "clear_small": 1}
	SaveManager.data["endless_high_score"] = 0
	SaveManager.data["total_merges"] = 0
	SaveManager.data["total_rounds_played"] = 0
	SaveManager.data["highest_tier_created"] = 0
	SaveManager.data["profile_counters_partial"] = false
	# TASK/045: başarım listesi monoton — önceki fikstürden taşmasın; Profil açılışı
	# gerçeklerden uzlaştırır.
	SaveManager.data["player_xp"] = 0
	SaveManager.data["unlocked_achievements"] = []
	SaveManager.data["selected_title_id"] = "birlestirici"
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()


func _apply_mid() -> void:
	SaveManager.data["highest_level_unlocked"] = 5
	# "4": 9 bozuk (3'e kırpılır), "5": -2 (0), "99": 3 olmayan level (yok sayılır):
	# 3 + 2 + 3 + 3 = 11.
	SaveManager.data["level_stars"] = {"1": 3, "2": 2, "3": 3, "4": 9, "5": -2, "99": 3}
	SaveManager.data["dough"] = 335
	SaveManager.data["unlocked_skins"] = ["common_01", "common_02", "rare_02", "common_04", "rare_05", "epic_01"]
	SaveManager.data["profile_showcase"] = ["rare_02"]
	SaveManager.data["powerups"] = {"bomb": 3, "upgrade": 1, "shake": 0, "clear_small": 2}
	SaveManager.data["endless_high_score"] = 0
	SaveManager.data["total_merges"] = 1234
	SaveManager.data["total_rounds_played"] = 17
	SaveManager.data["highest_tier_created"] = 5
	SaveManager.data["profile_counters_partial"] = false
	# TASK/045: başarım listesi monoton — önceki fikstürden taşmasın; Profil açılışı
	# gerçeklerden uzlaştırır.
	SaveManager.data["player_xp"] = 0
	SaveManager.data["unlocked_achievements"] = []
	SaveManager.data["selected_title_id"] = "birlestirici"
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()


func _apply_late() -> void:
	var all_ids: Array = []
	for skin in SkinLibrary.all():
		all_ids.append(String(skin.id))
	var stars: Dictionary = {}
	for level in LevelLibrary.load_levels():
		stars[str(level.level_number)] = 3
	SaveManager.data["highest_level_unlocked"] = LevelLibrary.load_levels().size() + 1
	SaveManager.data["level_stars"] = stars
	SaveManager.data["dough"] = 99999
	SaveManager.data["unlocked_skins"] = all_ids
	SaveManager.data["profile_showcase"] = ["legendary_02", "epic_03", "rare_02"]
	SaveManager.data["powerups"] = {"bomb": 99, "upgrade": 12, "shake": 0, "clear_small": 7}
	SaveManager.data["endless_high_score"] = 12480
	SaveManager.data["total_merges"] = 98765
	SaveManager.data["total_rounds_played"] = 1250
	SaveManager.data["highest_tier_created"] = 8
	SaveManager.data["profile_counters_partial"] = false
	# TASK/045: başarım listesi monoton — önceki fikstürden taşmasın; Profil açılışı
	# gerçeklerden uzlaştırır.
	SaveManager.data["player_xp"] = 0
	SaveManager.data["unlocked_achievements"] = []
	SaveManager.data["selected_title_id"] = "birlestirici"
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()


func _expected_tier(saved: int) -> int:
	var best: int = saved
	for level in LevelLibrary.load_levels():
		if level.level_number < SaveManager.highest_level_unlocked():
			best = maxi(best, level.target_tier)
	return best


func _level(number: int) -> LevelData:
	for level in LevelLibrary.load_levels():
		if level.level_number == number:
			return level
	return null


func _powers_match(profile: CanvasLayer) -> bool:
	for type in PowerUp.all():
		if profile.power_count_text(type) != "×%d" % SaveManager.powerup_count(type):
			return false
	return true


func _tile(profile: CanvasLayer, key: StringName) -> ProfileStatTile:
	return profile.stat_tile(key)


func _section_text(profile: CanvasLayer, key: StringName) -> String:
	var header: Control = profile.section(key)
	return (header.get_meta(&"title_label") as Label).text if header != null and header.has_meta(&"title_label") else ""


func _showcase_is(ids: Array) -> bool:
	var got: Array[StringName] = SaveManager.profile_showcase()
	if got.size() != ids.size():
		return false
	for i in ids.size():
		if got[i] != StringName(ids[i]):
			return false
	return true


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


## Main'in geçiş sonrası parmak yatışması geçene kadar GERÇEK süre bekler.
func _wait_settled() -> void:
	var settle_msec: int = int(_main_script.get_script_constant_map().get("TOUCH_SETTLE_MSEC", 300))
	await get_tree().create_timer(float(settle_msec) / 1000.0 + 0.12).timeout
	await get_tree().process_frame


## Kontrolün merkezi PENCERE pikselinde (Input.parse_input_event pencere koordinatı ister).
func _screen_center(control: Control) -> Vector2:
	return get_viewport().get_screen_transform() * control.get_global_rect().get_center()


## Gerçek parmak dokunuşu: ScreenTouch (device 0) bas → bir kare → bırak. Godot fareyi
## dokunuştan öykünür (device -1) — A36'daki olay sırasının aynısı.
func _finger_tap(pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = pos
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await get_tree().process_frame


## Masaüstü fare tıklaması (device 0; proje ayarı dokunuşu fareden öykünür).
func _mouse_click(pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = pos
		click.global_position = pos
		if pressed:
			click.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(click)
		await get_tree().process_frame


func _resize(view: Vector2i) -> void:
	get_window().size = view
	await get_tree().process_frame
	await get_tree().process_frame


func _bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) if FileAccess.file_exists(SaveManager.SAVE_PATH) \
		else PackedByteArray()


func _read_save_file() -> Dictionary:
	if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	return parsed if parsed is Dictionary else {}


func _restore_save_file() -> void:
	if not _had_save:
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()


func _strip_comments(code: String) -> String:
	var out: PackedStringArray = []
	for line in code.split("\n"):
		var hash: int = line.find("#")
		out.append(line if hash < 0 else line.substr(0, hash))
	return "\n".join(out)


func _string_literals(code: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.new()
	re.compile("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
	for m in re.search_all(code):
		out.append(m.get_string(1))
	return out


func _collect_text(node: Node) -> String:
	var out: String = ""
	for n in _all_nodes(node):
		if n is Label and (n as Label).is_visible_in_tree():
			out += (n as Label).text + "|"
	return out


func _text_width(label: Label, text: String) -> float:
	return label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		label.get_theme_font_size("font_size")).x


func _count_variation(root: Node, variation: StringName) -> int:
	var n: int = 0
	for node in _all_nodes(root):
		if node is Control and (node as Control).theme_type_variation == variation:
			n += 1
	return n


func _count_script(root: Node, path: String) -> int:
	var n: int = 0
	for node in _all_nodes(root):
		var script: Script = node.get_script()
		if script != null and script.resource_path == path:
			n += 1
	return n


func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	for child in root.get_children():
		out.append_array(_all_nodes(child))
	return out
