extends Node
## Ana Sayfa hub regresyon testi — TASK/058 Ana Sayfa V3 (önce M8.6-03B). Headless, kaydı geri koyar.
##
##   godot --headless --audio-driver Dummy --path . res://tools/home_ui_test.tscn
##
## Kontroller: V3 bileşenleri (tek kahraman OYNA = SquishyButton PRIMARY HERO; GÜNLÜK ÖDÜLLER + MEYDAN OKUMA =
## FeatureCard; GÖREVLER + SANDIK = HomeFeatureButton; üst satır ve level bilgisi DURUM — buton değil); kabukla
## yinelenen eski girişler YOK (avatar, Hamur "+", Mağaza / Koleksiyon madalyonu, Harita'ya giden level düğmesi);
## veri gösterimleri üç kayıt durumunda (orta / yeni / sonsuz) + günlük alınabilir / alınmış; SIRADAKİ yazımı (Home +
## gameplay HUD); sandık bilgisi ödül durumunu değiştirmez; rotalar (OYNA → Harita, GÜNLÜK → günlük penceresi (gerçek
## claim yolu), SANDIK → sandık bilgisi → OYNA → Harita, kabuk PROFİL → Profil → dişli → Ayarlar); Android geri;
## 720×1280 / 1560 / 1440 / 1600 (+ A36 payı) tuvalinde hiçbir kontrol çakışmıyor, madalyonlar maskotun OPAK
## pikselleriyle ve OYNA / kartlarla kesişmiyor, hepsi görünür alanda, dokunma hedefleri ≥ 84; Ana Sayfa'yı çizmek /
## yenilemek kayıt dosyasını DEĞİŞTİRMİYOR; runtime'da _visual_source / spike referansı yok. Dokunuş, iptal, ilk gün,
## banner ve teklif yuvası odak testi: tools/home_v3_test.tscn.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
## Pencere boyutları: 720 tuvali (1280/1560/1440/1600) + gerçek cihaz pencereleri 540×960 (tuval 720×1280) ve
## 1080×2340 (tuval 720×1560).
const VIEWS: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(720, 1560), Vector2i(720, 1440), Vector2i(720, 1600),
	Vector2i(540, 960), Vector2i(1080, 2340)]
## A36 punch-hole: 92 px fiziksel / 1.5 = 61 tuval px (M8.6-02 cihaz kapısı).
const A36_SAFE_TOP: float = 61.0
const RUNTIME_FILES: Array[String] = [
	"res://scripts/ui/home_screen.gd", "res://scripts/ui/home_feature_button.gd", "res://scripts/ui/feature_card.gd",
	"res://scripts/ui/bonus_chest_info.gd", "res://scripts/ui/ui_kit.gd",
	"res://scenes/ui/home_screen.tscn", "res://scenes/ui/bonus_chest_info.tscn",
	"res://assets/visual/ui_theme.tres",
]
const FORBIDDEN: Array[String] = ["_visual_source", "layerlab_spike", "layerlab_casual_game", "unitypackage"]

var _fails: int = 0
var _checks: int = 0
var _saved: Dictionary = {}
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _main: Node2D
var _mascot_img: Image


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
	# Günlük ödül bugün alınmış gibi: main._ready kayda yazmasın (bu test "Ana Sayfa'yı çizmek kaydı değiştirmez"
	# sözünü ölçüyor).
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	# M8.10: bu harness KABUGU olcuyor — onboarding tamamlanmis olmali, yoksa Main dogrudan ilk acilis tutorial'ina
	# girer. Kayit dosyasini geri koymayan baska bir suite diske `false` birakmis olabilir.
	SaveManager.data["onboarding_completed"] = true
	SaveManager.data["onboarding_completed_day"] = ""
	_apply_showcase()

	get_window().size = Vector2i(720, 1000)
	await get_tree().process_frame
	await _resize(VIEWS[0])
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	var home: CanvasLayer = _main._screens[0]
	_mascot_img = (home.HERO_ART as Texture2D).get_image()

	print("-- bileşenler (V3)")
	_c("OYNA: V3 SquishyButton PRIMARY HERO, 'OYNA' + oynat pictosu", home.play_button() is SquishyButton
		and home.play_button().kind() == SquishyButton.Kind.PRIMARY
		and home.play_button().size_class() == SquishyButton.SizeClass.HERO and home.play_button().title() == "OYNA")
	var heroes: int = 0
	for node in _all_controls(home):
		if node is SquishyButton and (node as SquishyButton).size_class() == SquishyButton.SizeClass.HERO:
			heroes += 1
	_c("ekranda tam bir kahraman CTA; eski ButtonCTA yok", heroes == 1 and _count_variation(home, &"ButtonCTA") == 0)
	_c("GÜNLÜK ÖDÜLLER + MEYDAN OKUMA: V3 FeatureCard (tam genişlik, tek dokunma hedefi)",
		home.daily_card() is FeatureCard and home.challenge_card() is FeatureCard
		and home.daily_card().title_text() == "GÜNLÜK ÖDÜLLER" and home.challenge_card().title_text() == "MEYDAN OKUMA"
		and _count_class(home, "FeatureCard") == 2)
	_c("GÖREVLER + SANDIK: HomeFeatureButton (ButtonFeature), etiketli; ekranda tam 2 madalyon",
		home.missions_button().label_text() == "GÖREVLER" and home.chest_button().label_text() == "BONUS SANDIK"
		and home.missions_button().theme_type_variation == &"ButtonFeature"
		and _count_class(home, "HomeFeatureButton") == 2)
	_c("feature_button anahtarları: daily / missions / chest; shop / collection → null",
		home.feature_keys() == [&"daily", &"missions", &"chest"] and home.feature_button(&"daily") == home.daily_card()
		and home.feature_button(&"shop") == null and home.feature_button(&"collection") == null)
	_c("kabukla yinelenen girişler YOK: avatar, Hamur '+', Mağaza / Koleksiyon madalyonu, level düğmesi",
		_count_class(home, "AvatarButton") == 0 and not home.dough_pill().has_meta(&"add_button")
		and home.find_child("Shop", true, false) == null and home.find_child("Collection", true, false) == null
		and _count_variation(home, &"ButtonHomePill") == 0 and _count_variation(home, &"ButtonHomeAdd") == 0)
	_c("Ana Sayfa'da ayarlar butonu YOK (TASK/044: Ayarlar Profil'in dişli çarkında)",
		home.find_child("Settings", true, false) == null and not home.has_method("settings_button")
		and _count_variation(home, &"ButtonHomeIcon") == 0)
	_c("üst satır DURUM: oyuncu seviyesi + unvan + XP rayı (PlayerLevelBadge) ve Hamur pill'i (PanelHomePill), fare almaz",
		_count_class(home.player_status(), "PlayerLevelBadge") == 1
		and (home.dough_pill().get_meta(&"pill") as PanelContainer).theme_type_variation == &"PanelHomePill"
		and home.player_status().mouse_filter == Control.MOUSE_FILTER_IGNORE
		and _count_class(home.player_status(), "BaseButton") == 0)
	_c("level bilgisi DURUM (PanelContainer, fare almaz, buton yok)", home.level_info().mouse_filter == Control.MOUSE_FILTER_IGNORE
		and home.level_info().find_children("*", "BaseButton", true, false).is_empty())
	_c("eski UiPalette çipi / IconButton / dashboard kartı / sekme çubuğu yok", _count_variation(home, &"ChipPanel") == 0
		and _count_variation(home, &"IconButton") == 0 and _count_variation(home, &"PanelModuleCard") == 0
		and _count_variation(home, &"ButtonTab") == 0 and _count_variation(home, &"PanelNav") == 0)
	_c("Ana Sayfa'da harita içeriği yok (MapTrail / harita zemini / düğüm)", _count_class(home, "MapTrail") == 0
		and not _uses_texture(home, "map_background") and home.find_child("Portal", true, false) == null)
	_c("hero maskotu yüksek çözünürlüklü türev (hero_mascot, ≥ 700 px)", (home.HERO_ART as Texture2D).resource_path.ends_with("hero_mascot.png")
		and _mascot_img != null and _mascot_img.get_width() >= 700)
	_c("teklif yuvası (TASK/062) boş + gizli; OfferCard yok", not home.offer_slot().visible
		and home.offer_slot().get_child_count() == 0 and _count_class(home, "OfferCard") == 0)

	print("-- sekme çubuğu")
	_c("Ana Sayfa'da eski sekme çubuğu YOK (main'de TabBar düğümü yok)", not ("_tabs" in _main) and _main.get_node_or_null("TabBar") == null)
	_main._show_tab(1)
	_c("Harita'da eski sekme çubuğu YOK", _main.get_node_or_null("TabBar") == null and _main._screens[1].visible)
	_main._show_tab(0)
	_c("Ana Sayfa'ya dönünce yalnız Home görünür", home.visible and not _main._screens[1].visible)

	print("-- veri (orta oyuncu)")
	home.refresh()
	_c("Hamur 335", _pill_text(home.dough_pill()) == "335")
	_c("oyuncu durumu: seviye = PlayerProfile seviyesi, unvan = seçili unvan, XP oranı 0..1",
		home.status_level() == PlayerProfile.player_level() and home.status_title_text() == PlayerProfile.selected_title_name()
		and home.status_ratio() >= 0.0 and home.status_ratio() <= 1.0)
	_c("level bilgisi: SIRADAKİ (noktalı İ), 'Level 4', 8/30", home.level_caption_text() == "SIRADAKİ"
		and home.level_title_text() == "Level 4" and home.level_stars_text() == "8/30")
	var chest: HomeFeatureButton = home.chest_button()
	_c("sandık rozeti 49/75, altın halka 49/75", chest.badge_text() == "49/75" and absf(chest.progress() - 49.0 / 75.0) < 0.011
		and chest._ring.tint == UiTokens.GOLD)
	_c("sandık sanatı owner sandığı", chest._art.texture == home.CHEST_ART)
	_c("günlük alınmış (giriş): '!' yok değil — ücretsiz sandık hazır (gerçek durum)", not home.is_daily_claimable()
		and home.daily_state() == &"free_chest" and home.daily_card().badge().text() == "!")
	_c("ui_smoke uyumluluğu: _play_hint dolu", not home._play_hint.text.is_empty())

	print("-- veri (yeni oyuncu)")
	_apply_fresh()
	home.refresh()
	_c("Hamur 0; level 1, 0/30", _pill_text(home.dough_pill()) == "0" and home.level_title_text() == "Level 1"
		and home.level_stars_text() == "0/30")
	_c("seri 0 iken Günlük kartı çıplak '0' göstermez", not home.daily_card().subtitle_text().begins_with("0"))
	_c("sandık 0/75", chest.badge_text() == "0/75" and chest.progress() == 0.0)

	print("-- veri (sonsuz açık)")
	_apply_endless()
	home.refresh()
	_c("sonsuz: 'SONSUZ MOD' / 'Rekor 12 480' / 30/30", home.level_caption_text() == "SONSUZ MOD"
		and home.level_title_text() == "Rekor 12 480" and home.level_stars_text() == "30/30")
	_c("Hamur 99999; Günlük kartında '365 günlük seri'", _pill_text(home.dough_pill()) == "99999"
		and home.daily_card().subtitle_text().begins_with("365 günlük seri"))

	print("-- günlük ödül durumu")
	_apply_showcase()
	SaveManager.data["last_login_date"] = _yesterday()
	home.refresh()
	var daily: FeatureCard = home.daily_card()
	_c("dün giriş → alınabilir: kart 'Giriş ödülü hazır' + '!' rozeti", home.is_daily_claimable()
		and home.daily_state() == &"login" and daily.badge().visible and daily.subtitle_text() == "Giriş ödülü hazır")
	var dough_before: int = SaveManager.dough()
	var unified: CanvasLayer = _main._daily_rewards
	daily.pressed.emit()
	await get_tree().process_frame
	_c("Günlük kartı → GÜNLÜK ÖDÜLLER penceresi açıldı (tek pencere, gerçek claim yolu)", unified.visible
		and not unified.is_auto_opened())
	_c("claim DailyReward üzerinden: +%d Hamur, seri 3; pencere '3. GÜN', '+15 HAMUR', ALINDI" % DailyReward.DAILY_DOUGH,
		SaveManager.dough() == dough_before + DailyReward.DAILY_DOUGH and SaveManager.daily_streak() == 3
		and unified.login_day_text() == "3. GÜN" and unified.login_reward_text() == "+%d HAMUR" % DailyReward.DAILY_DOUGH
		and unified.login_chip_text() == unified.LOGIN_CLAIMED)
	unified.close_popup()
	await get_tree().process_frame
	_c("kapanınca Ana Sayfa yenilendi: giriş bekliyor değil, '3 günlük seri', Hamur pill'i güncel",
		not home.is_daily_claimable() and daily.subtitle_text().begins_with("3 günlük seri")
		and _pill_text(home.dough_pill()) == str(dough_before + DailyReward.DAILY_DOUGH))
	daily.pressed.emit()
	await get_tree().process_frame
	_c("alınmışken Günlük → aynı pencere ALINDI durumu, ödül tekrar VERİLMEDİ", unified.visible
		and unified.login_chip_text() == unified.LOGIN_CLAIMED and unified.strip().is_today_marked()
		and SaveManager.dough() == dough_before + DailyReward.DAILY_DOUGH)
	unified.close_popup()
	await get_tree().process_frame
	_c("eski DailyRewardPopup ağaçta YOK (tek günlük akış)", _main.get_node_or_null("DailyRewardPopup") == null)
	_apply_showcase()
	home.refresh()

	print("-- madalyon bileşeni")
	var probe := HomeFeatureButton.new()
	probe.set_art(home.CHEST_ART)
	probe.set_label("Deneme")
	probe.set_badge("3/4")
	probe.set_notification(true)
	probe.set_progress(0.5, UiTokens.MINT)
	_c("rozet + bildirim + halka birlikte", probe.badge_text() == "3/4" and probe.has_notification() and probe.progress() == 0.5)
	probe.set_locked(true)
	_c("kilitli: disabled, ButtonFeatureLocked, rozet/nokta gizli, kilit görünür", probe.disabled and probe.is_locked()
		and probe.theme_type_variation == &"ButtonFeatureLocked" and not probe._badge.visible and not probe._dot.visible and probe._lock.visible)
	probe.set_locked(false)
	_c("kilit açılınca eski durum geri", not probe.disabled and probe.theme_type_variation == &"ButtonFeature"
		and probe._badge.visible and probe._dot.visible and not probe._lock.visible)
	probe.size = HomeFeatureButton.SIZE
	_c("TASK/058 isabet testi: etiket plakası dokunma alanına dahil, dışı değil", probe._has_point(Vector2(48, 110))
		and probe._has_point(Vector2(48, 50)) and not probe._has_point(Vector2(48, 140)))
	probe.set_badge("")
	_c("boş rozet gizlenir", not probe._badge.visible and probe.badge_text().is_empty())
	_c("basış animasyonu bağlı (UiMotion)", probe.has_meta(&"ui_motion_press"))
	probe.free()

	print("-- rotalar")
	_main._show_tab(0)
	home.play_button().pressed.emit()
	_c("OYNA → Harita (M8.6-04)", _main._active_tab == 1 and _main._screens[1].visible)
	_main._show_tab(0)
	var reward_state: Array = [SaveManager.dough(), int(SaveManager.data.get("merges_since_bonus_chest", 0)),
		SaveManager.owned_skins().size()]
	chest.pressed.emit()
	await get_tree().process_frame
	_c("SANDIK madalyonu → bonus sandık bilgisi (49/75, kural metni)", _main._chest_info.visible
		and _main._chest_info.count_text() == "49/75" and _main._active_tab == 0)
	_c("sandık bilgisi ödül durumunu DEĞİŞTİRMEDİ (Hamur / merge sayacı / skin)", reward_state == [SaveManager.dough(),
		int(SaveManager.data.get("merges_since_bonus_chest", 0)), SaveManager.owned_skins().size()])
	_main._chest_info.play_button().pressed.emit()
	_c("sandık penceresi OYNA → kapanır, Harita", not _main._chest_info.visible and _main._active_tab == 1)
	_main._show_tab(0)
	home.missions_button().pressed.emit()
	await get_tree().process_frame
	_c("GÖREVLER madalyonu → GÖREVLER penceresi", _main._missions.visible)
	_main._missions.close_missions(false)
	home.challenge_card().pressed.emit()
	await get_tree().process_frame
	_c("MEYDAN OKUMA kartı → MEYDAN OKUMA penceresi", _main._challenge_sheet.visible)
	_main._challenge_sheet.close_sheet(false)
	var profile: CanvasLayer = _main._screens[4]
	var nav_before: int = _main.nav_navigations
	_main.global_nav().item_button(4).pressed.emit()
	_c("kabuk PROFİL → Profil (TASK/058: Ana Sayfa avatarı yok)", _main._active_tab == 4 and profile.visible and not home.visible
		and _main.nav_navigations == nav_before + 1)
	profile.settings_button().pressed.emit()
	_c("Profil dişli çarkı → Ayarlar (Main'in tek SettingsPanel'i)", _main._settings.visible and _main._active_tab == 4)
	_main.close_settings()
	_c("ayarlar kapandı, Profil'de kalındı", not _main._settings.visible and _main._active_tab == 4 and profile.visible)
	nav_before = _main.nav_navigations
	_main.global_nav().item_button(0).pressed.emit()
	_c("Profil'de kabuk ANA SAYFA → Ana Sayfa (tam 1 gezinme)", _main._active_tab == 0 and home.visible
		and not profile.visible and _main.nav_navigations == nav_before + 1)
	_c("Ana Sayfa ekranı hareket ediyor (process açık)", home.is_processing())
	_main._show_tab(1)
	_c("gizliyken hareket durur", not home.is_processing())
	_main._show_tab(0)

	print("-- Android geri")
	_main._show_tab(2)
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("Koleksiyon'da geri → Ana Sayfa", _main._active_tab == 0 and home.visible and not _main._screens[2].visible)
	_main._last_back_msec = -1000
	_main.open_settings()
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("Ana Sayfa'da ayarlar açıkken geri → ayarlar kapanır, sekme aynı", not _main._settings.visible and _main._active_tab == 0)
	_main._last_back_msec = -1000
	chest.pressed.emit()
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("sandık penceresi açıkken geri → pencere kapanır", not _main._chest_info.visible and _main._active_tab == 0)
	_main._last_back_msec = -1000
	daily.pressed.emit()
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("günlük penceresi açıkken geri → pencere kapanır", not _main._daily_rewards.visible and _main._active_tab == 0)
	_main._last_back_msec = -1000
	_main._show_tab(4)
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("Profil'de geri → Ana Sayfa", _main._active_tab == 0 and home.visible and not _main._screens[4].visible)
	_main._show_tab(0)
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_c("Ana Sayfa'da pencere yokken geri → quit (politika korunuyor)", main_src.contains("get_tree().quit()"))

	print("-- yerleşim")
	for view in VIEWS:
		await _resize(view)
		_main._show_tab(0)
		await get_tree().process_frame
		await get_tree().process_frame
		_check_layout(home, get_viewport().get_visible_rect().size, 0.0, "%dx%d" % [view.x, view.y])
	# A36 punch-hole: üst pay satırı aşağı iter.
	await _resize(VIEWS[1])
	await _check_layout_with_safe(home, Vector2(VIEWS[1]), A36_SAFE_TOP)

	print("-- kayıt")
	# Günlük claim yolu kaydı yazdı (bilerek, gerçek yol). Dosyayı baştaki byte'lara geri koy, sonra "Ana Sayfa'yı
	# çizmek/yenilemek yazmaz" ölç.
	_restore_save_file()
	var file_before: PackedByteArray = FileAccess.get_file_as_bytes(save_path) \
		if FileAccess.file_exists(save_path) else PackedByteArray()
	_apply_showcase()
	for i in 3:
		_main._show_tab(0)
		home.refresh()
		await get_tree().process_frame
	var file_after: PackedByteArray = FileAccess.get_file_as_bytes(save_path) \
		if FileAccess.file_exists(save_path) else PackedByteArray()
	_c("Ana Sayfa çizimi/yenilemesi kayıt dosyasını değiştirmedi", file_before == file_after)
	var home_src: String = FileAccess.get_file_as_string("res://scripts/ui/home_screen.gd")
	var chest_src: String = FileAccess.get_file_as_string("res://scripts/ui/bonus_chest_info.gd")
	_c("home_screen / bonus_chest_info save_game / add_dough / grant çağırmıyor", not home_src.contains("save_game(")
		and not home_src.contains("add_dough(") and not home_src.contains("grant_")
		and not chest_src.contains("save_game(") and not chest_src.contains("add_dough(") and not chest_src.contains("grant_"))

	print("-- kaynak hijyeni")
	var clean: bool = true
	for path in RUNTIME_FILES:
		var text: String = FileAccess.get_file_as_string(path)
		for word in FORBIDDEN:
			if text.contains(word):
				clean = false
				print("    yasak referans: ", path, " -> ", word)
	_c("runtime dosyalarında _visual_source / spike referansı yok", clean)
	var hud_src: String = FileAccess.get_file_as_string("res://scripts/ui/gameplay_hud.gd")
	_c("kullanıcıya görünen 'SIRADAKI' (noktasız) yok: Home + gameplay HUD 'SIRADAKİ'",
		not home_src.contains("\"SIRADAKI\"") and not hud_src.contains("\"SIRADAKI\"")
		and hud_src.contains("\"SIRADAKİ\"") and home_src.contains("\"SIRADAKİ\""))

	_main.queue_free()
	await get_tree().process_frame
	SaveManager.data = _saved
	_restore_save_file()
	print("=== SONUC: %d/%d kontrol, %d kaldi ===" % [_checks - _fails, _checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


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


## Yerel takvimde "dün": DailyReward günü `Time.get_date_string_from_system()` (YEREL) ile okur; UTC unix zamanından
## türetmek yerel 00:00–03:00 arasında (UTC+3) iki gün geriye kayıyordu → seri kopuk, kontrol yanlış FAIL.
func _yesterday() -> String:
	var local_unix: int = Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system())
	return Time.get_date_string_from_unix_time(local_unix - 86400)


func _resize(view: Vector2i) -> void:
	get_window().size = view
	await get_tree().process_frame
	await get_tree().process_frame


func _pill_text(pill: Control) -> String:
	return (pill.get_meta(&"value_label") as Label).text


func _count_variation(root: Node, variation: StringName) -> int:
	var count: int = 0
	for node in _all_controls(root):
		if node.theme_type_variation == variation:
			count += 1
	return count


func _count_class(root: Node, klass: String) -> int:
	return root.find_children("*", klass, true, false).size()


func _uses_texture(root: Node, name_part: String) -> bool:
	for node in _all_controls(root):
		var rect := node as TextureRect
		if rect != null and rect.texture != null and rect.texture.resource_path.contains(name_part):
			return true
	return false


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


func _check_layout_with_safe(home: CanvasLayer, view: Vector2, safe_top: float) -> void:
	# UiKit.safe_top pencereden okur (masaüstünde 0); A36 payı yerleşime test kancasıyla enjekte edilir.
	home._layout_with_safe_top(safe_top)
	await get_tree().process_frame
	await get_tree().process_frame
	_check_layout(home, view, safe_top, "%dx%d" % [int(view.x), int(view.y)])
	home._layout_with_safe_top(-1.0)


## Etkileşimli kontroller: hepsi görünür alanda, birbiriyle çakışmıyor, ≥ 84 px; madalyonlar (etiket plakası dahil)
## maskotun opak pikselleriyle, OYNA / kartlarla ve birbirleriyle kesişmiyor; logo üstte; okuma sırası.
func _check_layout(home: CanvasLayer, view: Vector2, safe_top: float, window_tag: String) -> void:
	var tag: String = "%s (tuval %dx%d)%s" % [window_tag, int(view.x), int(view.y), " +A36" if safe_top > 0.0 else ""]
	var visible: Rect2 = get_viewport().get_visible_rect()
	_c("%s tuval genişliği 720" % tag, is_equal_approx(visible.size.x, 720.0) and is_equal_approx(visible.size.y, view.y))
	var buttons: Array[BaseButton] = []
	for node in _all_controls(home):
		if node is BaseButton and node.is_visible_in_tree():
			buttons.append(node)
	var screen: Rect2 = Rect2(Vector2(0, safe_top), Vector2(720.0, view.y - safe_top))
	var inside: bool = true
	var touch: bool = true
	for button in buttons:
		var rect: Rect2 = _button_rect(button)
		if not screen.encloses(rect):
			inside = false
			print("    ekran dışı: ", button.name, " ", rect)
		if button.get_global_rect().size.x < UiTokens.TOUCH_TARGET or button.get_global_rect().size.y < UiTokens.TOUCH_TARGET:
			touch = false
			print("    dokunma hedefi küçük: ", button.name, " ", button.get_global_rect().size)
	_c("%s bütün butonlar (%d = OYNA + 2 kart + 2 madalyon) görünür alanda, güvenli payın altında" % [tag, buttons.size()],
		inside and buttons.size() == 5)
	_c("%s dokunma hedefleri ≥ %d×%d" % [tag, UiTokens.TOUCH_TARGET, UiTokens.TOUCH_TARGET], touch)
	var overlap: bool = false
	for i in buttons.size():
		for j in range(i + 1, buttons.size()):
			if buttons[i].is_ancestor_of(buttons[j]) or buttons[j].is_ancestor_of(buttons[i]):
				continue
			var inter: Rect2 = _button_rect(buttons[i]).intersection(_button_rect(buttons[j]))
			if inter.size.x > 1.0 and inter.size.y > 1.0:
				overlap = true
				print("    çakışma: ", buttons[i].name, " x ", buttons[j].name)
	_c("%s butonlar (madalyon plakaları dahil) çakışmıyor" % tag, not overlap)
	var mascot_rect: Rect2 = home.mascot_rect()
	var hits: bool = false
	for medallion: HomeFeatureButton in [home.missions_button(), home.chest_button()]:
		if _mascot_hits(mascot_rect, medallion.visual_rect()):
			hits = true
			print("    maskot madalyona giriyor: ", medallion.name)
	_c("%s madalyonlar maskotun opak pikselleriyle kesişmiyor" % tag, not hits)
	var play_rect: Rect2 = home.play_button().get_global_rect()
	var level_rect: Rect2 = home.level_info().get_global_rect()
	var daily_rect: Rect2 = home.daily_card().get_global_rect()
	var challenge_rect: Rect2 = home.challenge_card().get_global_rect()
	_c("%s okuma sırası: maskot → level bilgisi → OYNA → GÜNLÜK → MEYDAN OKUMA" % tag,
		mascot_rect.end.y <= level_rect.position.y + 1.0 and level_rect.end.y <= play_rect.position.y
		and play_rect.end.y < daily_rect.position.y and daily_rect.end.y < challenge_rect.position.y)
	_c("%s OYNA yatayda ORTALI (|merkez − 360| ≤ 2 px), ≥ 420 × %d" % [tag, UiTokens.BUTTON_HEIGHT_HERO],
		absf(play_rect.get_center().x - 360.0) <= 2.0 and play_rect.size.x >= 420.0
		and play_rect.size.y >= float(UiTokens.BUTTON_HEIGHT_HERO) - 2.0)
	_c("%s level bilgisi OYNA'nın hemen üstünde (≤ 16 px), ortalı (±3 px), OYNA'dan dar" % tag,
		play_rect.position.y - level_rect.end.y <= 16.0 and absf(level_rect.get_center().x - 360.0) <= 3.0
		and level_rect.size.x < play_rect.size.x)
	_c("%s maskot baskın (≥ 340 px yüksek; V3'te kartlar hero'dan yer alır — 16:9 + banner ~368)" % tag,
		mascot_rect.size.y >= 340.0)
	# Uzun ekranda alt boşluk: maskot ile level bilgisi arası ölü bant olmasın (≤ 420 px).
	_c("%s maskot ile level bilgisi arası ≤ 420 px" % tag, level_rect.position.y - mascot_rect.end.y <= 420.0)
	var logo_rect: Rect2 = home.logo().get_global_rect()
	var status_rect: Rect2 = home.player_status().get_global_rect()
	var dough_rect: Rect2 = home.dough_pill().get_global_rect()
	_c("%s logo üst satırın altında, madalyonların ve maskotun üstünde" % tag, logo_rect.position.y >= status_rect.end.y - 1.0
		and logo_rect.end.y <= home.missions_button().get_global_rect().position.y + 1.0
		and logo_rect.end.y <= mascot_rect.position.y + 1.0)
	_c("%s üst satır güvenli payın altında, oyuncu durumu / Hamur ortak optik merkez (±3 px)" % tag,
		status_rect.position.y >= safe_top + home.TOP_MARGIN - 1.0
		and absf(status_rect.get_center().y - dough_rect.get_center().y) <= 3.0)
	_c("%s sol/sağ iç pay: seviye rozeti sol kenarı = Hamur sağ payı (±2)" % tag,
		absf(home.player_status().get_node("LevelBadge").get_global_rect().position.x - (720.0 - dough_rect.end.x)) <= 2.0)


func _button_rect(button: BaseButton) -> Rect2:
	if button is HomeFeatureButton:
		return (button as HomeFeatureButton).visual_rect()
	return button.get_global_rect()


## Madalyon dikdörtgeni ile maskot art'ının opak pikselleri kesişiyor mu?
func _mascot_hits(mascot_rect: Rect2, rect: Rect2) -> bool:
	var inter: Rect2 = mascot_rect.intersection(rect)
	if inter.size.x <= 0.0 or inter.size.y <= 0.0 or _mascot_img == null:
		return false
	var kx: float = float(_mascot_img.get_width()) / mascot_rect.size.x
	var ky: float = float(_mascot_img.get_height()) / mascot_rect.size.y
	var y: float = inter.position.y
	while y < inter.end.y:
		var x: float = inter.position.x
		while x < inter.end.x:
			var px: int = clampi(int((x - mascot_rect.position.x) * kx), 0, _mascot_img.get_width() - 1)
			var py: int = clampi(int((y - mascot_rect.position.y) * ky), 0, _mascot_img.get_height() - 1)
			if _mascot_img.get_pixel(px, py).a > 0.15:
				return true
			x += 3.0
		y += 3.0
	return false


func _apply_showcase() -> void:
	SaveManager.data["highest_level_unlocked"] = 4
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3}
	SaveManager.data["dough"] = 335
	SaveManager.data["daily_streak"] = 2
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.data["unlocked_skins"] = ["common_01", "common_02", "rare_02", "common_04", "rare_05", "epic_01"]
	SaveManager.data["profile_showcase"] = ["rare_02"]
	SaveManager.data["merges_since_bonus_chest"] = 49
	SaveManager.data["endless_high_score"] = 0


func _apply_fresh() -> void:
	SaveManager.data["highest_level_unlocked"] = 1
	SaveManager.data["level_stars"] = {}
	SaveManager.data["dough"] = 0
	SaveManager.data["daily_streak"] = 0
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.data["unlocked_skins"] = []
	SaveManager.data["profile_showcase"] = []
	SaveManager.data["merges_since_bonus_chest"] = 0
	SaveManager.data["endless_high_score"] = 0


func _apply_endless() -> void:
	var all_ids: Array = []
	for skin in SkinLibrary.all():
		all_ids.append(String(skin.id))
	var stars: Dictionary = {}
	var total: int = LevelLibrary.load_levels().size()
	for i in total:
		stars[str(i + 1)] = 3
	SaveManager.data["highest_level_unlocked"] = total + 1
	SaveManager.data["level_stars"] = stars
	SaveManager.data["dough"] = 99999
	SaveManager.data["daily_streak"] = 365
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.data["unlocked_skins"] = all_ids
	SaveManager.data["profile_showcase"] = ["legendary_02", "epic_01", "rare_02"]
	SaveManager.data["merges_since_bonus_chest"] = 74
	SaveManager.data["endless_high_score"] = 12480
