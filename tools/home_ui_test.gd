extends Node
## Ana Sayfa hub (M8.6-03B) regresyon testi. Headless, kaydı geri koyar.
##
##   godot --headless --audio-driver Dummy --path . res://tools/home_ui_test.tscn
##
## Kontroller: production bileşenler doğru variation'da (ButtonHomeIcon
## "oturmuş" ayarlar, PanelHomePill seri/Hamur + ButtonHomeAdd, tek ButtonCTA
## OYNA, ButtonHomePill level pill'i + altın rozet, dört
## HomeFeatureButton/ButtonFeature); üst satır hizası (ayarlar / seri / Hamur
## ortak optik merkez, ±3 px); yeni oyuncuda seri asla "0" değil; SIRADAKİ
## yazımı (Home + gameplay HUD kaynağı); sandık bilgisi ödül durumunu
## değiştirmez; Ana
## Sayfa'da sekme çubuğu GİZLİ, harita içeriği YOK; rotalar (OYNA/plaka →
## Harita, Koleksiyon → Koleksiyon, Mağaza ve Hamur "+" → Mağaza, Günlük →
## günlük penceresi, Sandık → sandık bilgisi → OYNA → Harita, ayarlar);
## veri gösterimleri üç kayıt durumunda (orta / yeni / sonsuz) + günlük
## alınabilir/alınmış; 720x1280, 1560, 1440, 1600 (+ A36 payı) tuvalinde
## hiçbir kontrol çakışmıyor, madalyonlar maskotun OPAK pikselleriyle ve
## OYNA ile kesişmiyor, hepsi görünür alanda, dokunma hedefleri ≥ 48;
## Ana Sayfa'yı çizmek/yenilemek kayıt dosyasını DEĞİŞTİRMİYOR; Android geri;
## runtime'da _visual_source / spike referansı yok.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
## Pencere boyutları: 720 tuvali (1280/1560/1440/1600) + gerçek cihaz
## pencereleri 540×960 (tuval 720×1280) ve 1080×2340 (tuval 720×1560).
const VIEWS: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(720, 1560), Vector2i(720, 1440), Vector2i(720, 1600),
	Vector2i(540, 960), Vector2i(1080, 2340)]
## A36 punch-hole: 92 px fiziksel / 1.5 = 61 tuval px (M8.6-02 cihaz kapısı).
const A36_SAFE_TOP: float = 61.0
const RUNTIME_FILES: Array[String] = [
	"res://scripts/ui/home_screen.gd", "res://scripts/ui/home_feature_button.gd",
	"res://scripts/ui/bonus_chest_info.gd", "res://scripts/ui/ui_kit.gd",
	"res://scenes/ui/home_screen.tscn", "res://scenes/ui/bonus_chest_info.tscn",
	"res://assets/visual/ui_theme.tres",
]
const FORBIDDEN: Array[String] = ["_visual_source", "layerlab_spike", "layerlab_casual_game", "unitypackage"]
const FEATURES: Array[StringName] = [&"daily", &"collection", &"shop", &"chest"]

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
	# Günlük ödül bugün alınmış gibi: main._ready kayda yazmasın (bu test
	# "Ana Sayfa'yı çizmek kaydı değiştirmez" sözünü ölçüyor).
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
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

	print("-- bileşenler")
	_c("ayarlar butonu ButtonHomeIcon (oturmuş Home varyantı, yüz + dudak)", home.settings_button().theme_type_variation == &"ButtonHomeIcon"
		and home.settings_button().has_meta(&"face"))
	_c("seri pill'i PanelHomePill (HUD v5 lavanta, koyu cip değil) + owner alev", (home.streak_pill().get_meta(&"pill") as PanelContainer).theme_type_variation == &"PanelHomePill")
	var add: Button = home.dough_pill().get_meta(&"add_button")
	_c("Hamur pill'i PanelHomePill + nane yuvarlak '+' (ButtonHomeAdd, 48)", (home.dough_pill().get_meta(&"pill") as PanelContainer).theme_type_variation == &"PanelHomePill"
		and add.theme_type_variation == &"ButtonHomeAdd" and add.custom_minimum_size.x >= 48.0)
	_c("Ana Sayfa'da koyu ResourcePill / ButtonHud yok", _count_variation(home, &"ResourcePill") == 0
		and _count_variation(home, &"ButtonHud") == 0)
	_c("OYNA ButtonCTA (tek kahraman CTA)", home.play_button().theme_type_variation == &"ButtonCTA")
	_c("OYNA yazısı", (home.play_button().get_meta(&"title_label") as Label).text == "OYNA")
	var ctas: int = 0
	for node in _all_controls(home):
		if node is Button and (node as Button).theme_type_variation == &"ButtonCTA":
			ctas += 1
	_c("ekranda tam bir ButtonCTA var", ctas == 1)
	_c("level pill'i ButtonHomePill + altın taç rozeti (dashboard kartı değil)", home.level_button().theme_type_variation == &"ButtonHomePill"
		and home.level_badge() != null and home.level_badge().get_parent() == home.level_button()
		and _count_variation(home, &"ButtonCard") == 0 and _count_variation(home, &"PanelHudCard") == 0)
	var features_ok: bool = home.feature_keys().size() == 4
	for key in FEATURES:
		var button: HomeFeatureButton = home.feature_button(key)
		features_ok = features_ok and button != null and button.theme_type_variation == &"ButtonFeature" \
			and not button.label_text().is_empty() and button.custom_minimum_size.x >= 48.0
	_c("dört madalyon HomeFeatureButton / ButtonFeature, etiketli", features_ok)
	_c("madalyon etiketleri GÜNLÜK / KOLEKSİYON / MAĞAZA / SANDIK",
		home.feature_button(&"daily").label_text() == "GÜNLÜK"
		and home.feature_button(&"collection").label_text() == "KOLEKSİYON"
		and home.feature_button(&"shop").label_text() == "MAĞAZA"
		and home.feature_button(&"chest").label_text() == "SANDIK")
	_c("madalyon sınıfı tek: HomeFeatureButton (ekranda 4 örnek)", _count_class(home, "HomeFeatureButton") == 4)
	_c("eski UiPalette çipi / IconButton / TextureButton CTA yok", _count_variation(home, &"ChipPanel") == 0
		and _count_variation(home, &"IconButton") == 0 and home.find_child("Play", true, false) is Button)
	_c("Ana Sayfa'da dashboard kartı yok (PanelModuleCard / ButtonTab / PanelNav)", _count_variation(home, &"PanelModuleCard") == 0
		and _count_variation(home, &"ButtonTab") == 0 and _count_variation(home, &"PanelNav") == 0)
	_c("Ana Sayfa'da ProgressBar yok (ilerleme halka/rozetle)", _count_class(home, "ProgressBar") == 0)
	_c("Ana Sayfa'da harita içeriği yok (MapTrail / harita zemini / düğüm)", _count_class(home, "MapTrail") == 0
		and not _uses_texture(home, "map_background") and home.find_child("Portal", true, false) == null)
	_c("hero maskotu yüksek çözünürlüklü türev (hero_mascot, ≥ 700 px)", (home.HERO_ART as Texture2D).resource_path.ends_with("hero_mascot.png")
		and _mascot_img != null and _mascot_img.get_width() >= 700)

	print("-- sekme çubuğu")
	# M8.6-06: eski alt sekme çubuğu tamamen kalktı — main'de TabBar düğümü yok,
	# hiçbir ekranda gizli bir çubuk dokunma almaz.
	_c("Ana Sayfa'da sekme çubuğu YOK (main'de TabBar düğümü yok)", not ("_tabs" in _main) and _main.get_node_or_null("TabBar") == null)
	_main._show_tab(1)
	_c("Harita'da sekme çubuğu YOK (M8.6-04: kendi üst satırı, geri → Ana Sayfa)", _main.get_node_or_null("TabBar") == null and _main._screens[1].visible)
	_main._show_tab(2)
	_c("Koleksiyon'da sekme çubuğu YOK (M8.6-06: kendi ScreenTopBar'ı)", _main.get_node_or_null("TabBar") == null and _main._screens[2].visible)
	_main._show_tab(0)
	_c("Ana Sayfa'ya dönünce yalnız Home görünür", home.visible and not _main._screens[2].visible)

	print("-- veri (orta oyuncu)")
	home.refresh()
	_c("Hamur 335, seri '2 günlük seri'", _pill_text(home.dough_pill()) == "335" and _pill_text(home.streak_pill()) == "2 günlük seri")
	_c("level pill'i: rozet 4 (görünür), 'Level 4', SIRADAKİ (noktalı İ), 8/30", home._level_badge_label.text == "4"
		and home._level_badge_label.visible and home._level_title.text == "Level 4"
		and home._level_caption.text == "SIRADAKİ" and home._level_stars.text == "8/30")
	var collection: HomeFeatureButton = home.feature_button(&"collection")
	_c("koleksiyon rozeti 6/20, halka 0.30", collection.badge_text() == "6/20" and absf(collection.progress() - 0.3) < 0.011)
	_c("koleksiyon sanatı takılı skin'in önizlemesi", collection._art.texture == SkinEntry.find(&"rare_02").preview_texture())
	var chest: HomeFeatureButton = home.feature_button(&"chest")
	_c("sandık rozeti 49/75, altın halka 49/75", chest.badge_text() == "49/75" and absf(chest.progress() - 49.0 / 75.0) < 0.011
		and chest._ring.tint == UiTokens.GOLD)
	_c("sandık sanatı owner sandığı", chest._art.texture == home.CHEST_ART)
	_c("günlük alınmış: bildirim noktası yok", not home.feature_button(&"daily").has_notification() and not home.is_daily_claimable())
	_c("ui_smoke uyumluluğu: _play_hint dolu", not home._play_hint.text.is_empty())

	print("-- veri (yeni oyuncu)")
	_apply_fresh()
	home.refresh()
	_c("Hamur 0; seri ASLA çıplak '0' değil → 'Seri başlasın'", _pill_text(home.dough_pill()) == "0"
		and _pill_text(home.streak_pill()) == "Seri başlasın" and not _pill_text(home.streak_pill()).begins_with("0"))
	_c("Level 1, 0/30", home._level_title.text == "Level 1" and home._level_stars.text == "0/30" and home._level_badge_label.text == "1")
	_c("koleksiyon 0/20, halka 0, varsayılan dumpling", collection.badge_text() == "0/20" and collection.progress() == 0.0
		and collection._art.texture == home.DUMPLING_VISUAL.TEXTURES[0])
	_c("sandık 0/75", chest.badge_text() == "0/75" and chest.progress() == 0.0)

	print("-- veri (sonsuz açık)")
	_apply_endless()
	home.refresh()
	_c("sonsuz: rozette yalnız büyük taç (yazı gizli), 'Rekor 12 480', SONSUZ MOD, 30/30", home._level_badge_label.text == "SONSUZ"
		and not home._level_badge_label.visible and home._level_crown.custom_minimum_size.x >= 30.0
		and home._level_title.text == "Rekor 12 480" and home._level_caption.text == "SONSUZ MOD" and home._level_stars.text == "30/30")
	_c("koleksiyon 20/20 dolu", collection.badge_text() == "20/20" and is_equal_approx(collection.progress(), 1.0))
	_c("Hamur 99999, seri '365 günlük seri'", _pill_text(home.dough_pill()) == "99999" and _pill_text(home.streak_pill()) == "365 günlük seri")

	print("-- günlük ödül durumu")
	_apply_showcase()
	SaveManager.data["last_login_date"] = _yesterday()
	home.refresh()
	var daily: HomeFeatureButton = home.feature_button(&"daily")
	_c("dün giriş → alınabilir: bildirim noktası görünür", home.is_daily_claimable() and daily.has_notification()
		and daily.notification_dot().visible)
	_c("bildirim noktası pembe (ödül vurgusu), rozet yok", daily.badge_text().is_empty())
	var dough_before: int = SaveManager.dough()
	var unified: CanvasLayer = _main._daily_rewards
	daily.pressed.emit()
	await get_tree().process_frame
	_c("Günlük madalyonu → GÜNLÜK ÖDÜLLER penceresi açıldı (tek pencere, gerçek claim yolu)", unified.visible
		and not unified.is_auto_opened())
	_c("claim DailyReward üzerinden: +%d Hamur, seri 3; pencere '3. GÜN', '+15 HAMUR', ALINDI" % DailyReward.DAILY_DOUGH,
		SaveManager.dough() == dough_before + DailyReward.DAILY_DOUGH and SaveManager.daily_streak() == 3
		and unified.login_day_text() == "3. GÜN" and unified.login_reward_text() == "+%d HAMUR" % DailyReward.DAILY_DOUGH
		and unified.login_chip_text() == unified.LOGIN_CLAIMED)
	unified.close_popup()
	await get_tree().process_frame
	_c("kapanınca Ana Sayfa yenilendi: nokta yok, Hamur pill'i güncel", not daily.has_notification()
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
	probe.set_badge("")
	_c("boş rozet gizlenir", not probe._badge.visible and probe.badge_text().is_empty())
	_c("basış animasyonu bağlı (UiMotion)", probe.has_meta(&"ui_motion_press"))
	probe.free()

	print("-- rotalar")
	_main._show_tab(0)
	home.play_button().pressed.emit()
	_c("OYNA → Harita (M8.6-04)", _main._active_tab == 1 and _main._screens[1].visible)
	_main._show_tab(0)
	home.level_button().pressed.emit()
	_c("level plakası → Harita", _main._active_tab == 1)
	_main._show_tab(0)
	collection.pressed.emit()
	_c("Koleksiyon madalyonu → Koleksiyon", _main._active_tab == 2 and _main._screens[2].visible)
	_main._show_tab(0)
	home.feature_button(&"shop").pressed.emit()
	_c("Mağaza madalyonu → Mağaza", _main._active_tab == 3 and _main._screens[3].visible)
	_main._show_tab(0)
	add.pressed.emit()
	_c("Hamur '+' → Mağaza", _main._active_tab == 3)
	_main._show_tab(0)
	var reward_state: Array = [SaveManager.dough(), int(SaveManager.data.get("merges_since_bonus_chest", 0)),
		SaveManager.owned_skins().size()]
	chest.pressed.emit()
	await get_tree().process_frame
	_c("Sandık madalyonu → bonus sandık bilgisi (49/75, kural metni)", _main._chest_info.visible
		and _main._chest_info.count_text() == "49/75" and _main._active_tab == 0)
	_c("sandık bilgisi ödül durumunu DEĞİŞTİRMEDİ (Hamur / merge sayacı / skin)", reward_state == [SaveManager.dough(),
		int(SaveManager.data.get("merges_since_bonus_chest", 0)), SaveManager.owned_skins().size()])
	_main._chest_info.play_button().pressed.emit()
	_c("sandık penceresi OYNA → kapanır, Harita", not _main._chest_info.visible and _main._active_tab == 1)
	_main._show_tab(0)
	home.settings_button().pressed.emit()
	_c("ayarlar butonu pencereyi açıyor", _main._settings.visible)
	_main.close_settings()
	_c("ayarlar kapandı", not _main._settings.visible)
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
	_check_layout_with_safe(home, Vector2(VIEWS[1]), A36_SAFE_TOP)

	print("-- kayıt")
	# Günlük claim yolu kaydı yazdı (bilerek, gerçek yol). Dosyayı baştaki
	# byte'lara geri koy, sonra "Ana Sayfa'yı çizmek/yenilemek yazmaz" ölç.
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
		and hud_src.contains("\"SIRADAKİ\""))

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


## Yerel takvimde "dün": DailyReward günü `Time.get_date_string_from_system()`
## (YEREL) ile okur; UTC unix zamanından türetmek yerel 00:00–03:00 arasında
## (UTC+3) iki gün geriye kayıyordu → seri kopuk, kontrol yanlış FAIL.
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
	# UiKit.safe_top pencereden okur (masaüstünde 0); A36 payı yerleşime
	# test kancasıyla enjekte edilir.
	home._layout_with_safe_top(safe_top)
	await get_tree().process_frame
	await get_tree().process_frame
	_check_layout(home, view, safe_top, "%dx%d" % [int(view.x), int(view.y)])
	home._layout_with_safe_top(-1.0)


## Etkileşimli kontroller: hepsi görünür alanda, birbiriyle çakışmıyor,
## ≥ 48 px; madalyonlar (etiket plakası dahil) maskotun opak pikselleriyle,
## OYNA/plaka ile ve birbirleriyle kesişmiyor; logo üstte; OYNA altta.
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
		var rect: Rect2 = button.get_global_rect()
		if not screen.encloses(rect):
			inside = false
			print("    ekran dışı: ", button.name, " ", rect)
		if rect.size.x < 48.0 or rect.size.y < 48.0:
			touch = false
			print("    dokunma hedefi küçük: ", button.name, " ", rect.size)
	_c("%s bütün butonlar (%d) görünür alanda, güvenli payın altında" % [tag, buttons.size()], inside and buttons.size() >= 8)
	_c("%s dokunma hedefleri ≥ 48×48" % tag, touch)
	var overlap: bool = false
	for i in buttons.size():
		for j in range(i + 1, buttons.size()):
			if buttons[i].is_ancestor_of(buttons[j]) or buttons[j].is_ancestor_of(buttons[i]):
				continue
			var a: Rect2 = _button_rect(buttons[i])
			var b: Rect2 = _button_rect(buttons[j])
			var inter: Rect2 = a.intersection(b)
			if inter.size.x > 1.0 and inter.size.y > 1.0:
				overlap = true
				print("    çakışma: ", buttons[i].name, " ", a, " x ", buttons[j].name, " ", b)
	_c("%s butonlar (madalyon plakaları dahil) çakışmıyor" % tag, not overlap)
	# Madalyonlar maskotun opak pikselleriyle kesişmiyor (alfa duyarlı).
	var mascot_rect: Rect2 = home.mascot_rect()
	var hits: bool = false
	for key in FEATURES:
		var button: HomeFeatureButton = home.feature_button(key)
		if _mascot_hits(mascot_rect, button.visual_rect()):
			hits = true
			print("    maskot madalyona giriyor: ", button.name)
	_c("%s madalyonlar maskotun opak pikselleriyle kesişmiyor" % tag, not hits)
	var play_rect: Rect2 = home.play_button().get_global_rect()
	var level_rect: Rect2 = home.level_button().get_global_rect()
	var clear_play: bool = true
	for key in FEATURES:
		var vr: Rect2 = home.feature_button(key).visual_rect()
		if vr.intersects(play_rect) or vr.intersects(level_rect):
			clear_play = false
	_c("%s madalyonlar OYNA/plaka satırına girmiyor" % tag, clear_play)
	_c("%s maskot level pill'inin üstünde, tuval içinde" % tag, mascot_rect.end.y <= level_rect.position.y + 1.0
		and mascot_rect.position.x >= 0.0 and mascot_rect.end.x <= 720.0)
	_c("%s maskot baskın (≥ 480 px yüksek)" % tag, mascot_rect.size.y >= 480.0)
	var logo_rect: Rect2 = home.logo().get_global_rect()
	var settings_rect: Rect2 = home.settings_button().get_global_rect()
	_c("%s logo üst satırın altında, madalyonların ve maskotun üstünde" % tag, logo_rect.position.y >= settings_rect.end.y - 1.0
		and logo_rect.end.y <= home.feature_button(&"daily").get_global_rect().position.y + 1.0
		and logo_rect.end.y <= mascot_rect.position.y + 1.0)
	_c("%s üst satır güvenli payın altında" % tag, settings_rect.position.y >= safe_top + home.TOP_MARGIN - 1.0)
	var streak_rect: Rect2 = home.streak_pill().get_global_rect()
	var dough_rect: Rect2 = home.dough_pill().get_global_rect()
	_c("%s ayarlar / seri / Hamur ortak optik merkez (±3 px), aynı satır" % tag,
		absf(settings_rect.get_center().y - streak_rect.get_center().y) <= 3.0
		and absf(settings_rect.get_center().y - dough_rect.get_center().y) <= 3.0
		and absf(settings_rect.size.y - streak_rect.size.y) <= 2.0 and absf(settings_rect.size.y - dough_rect.size.y) <= 2.0)
	_c("%s sol/sağ iç pay simetrik (ayarlar sol = Hamur sağ), seri ayarların sağında" % tag,
		absf(settings_rect.position.x - (720.0 - dough_rect.end.x)) <= 1.0
		and streak_rect.position.x >= settings_rect.end.x + 8.0 and streak_rect.end.x < dough_rect.position.x - 8.0)
	_c("%s ayarlar butonu 56 px, boyalı yüz + dudak dikdörtgenin içinde" % tag, settings_rect.size == Vector2(56.0, 56.0)
		and (home.settings_button().get_meta(&"face") as Control).get_global_rect().end.y <= settings_rect.end.y)
	var medallions_safe: bool = true
	for key in FEATURES:
		if not screen.encloses(home.feature_button(key).visual_rect()):
			medallions_safe = false
	_c("%s madalyonlar (plaka dahil) güvenli alanda" % tag, medallions_safe)
	_c("%s OYNA alt kenara yakın (≤ 60 px pay), 480×96, ≥ 48 dokunma" % tag, view.y - play_rect.end.y <= 60.0 + (view.y - 1280.0) * home.EXTRA_BOTTOM_SHARE + 1.0
		and absf(play_rect.size.x - home.PLAY_WIDTH) <= home.PLAY_WIDTH * 0.02
		and absf(play_rect.size.y - home.PLAY_HEIGHT) <= home.PLAY_HEIGHT * 0.02
		and play_rect.size.x >= 420.0 and play_rect.size.y >= 82.0)
	_c("%s OYNA yatayda ORTALI (|merkez − 360| ≤ 2 px)" % tag, absf(play_rect.get_center().x - 360.0) <= 2.0)
	# Level pill'i: OYNA'nın ÜSTÜNDE, rozet dahil görsel bütün ortalı, çakışmıyor.
	var badge_rect: Rect2 = home.level_badge().get_global_rect()
	var level_visual: Rect2 = level_rect.merge(badge_rect)
	_c("%s level pill'i OYNA'nın hemen üstünde (8–16 px), ortalı (±3 px), çakışmıyor" % tag,
		level_rect.end.y <= play_rect.position.y and play_rect.position.y - level_rect.end.y >= 8.0
		and play_rect.position.y - level_rect.end.y <= 16.0
		and absf(level_visual.get_center().x - 360.0) <= 3.0
		and not level_visual.intersects(play_rect) and badge_rect.position.x >= 0.0)
	_c("%s level pill'i OYNA'dan belirgin küçük (genişlik ≤ 284 < 480, yükseklik 60)" % tag,
		level_rect.size.x < play_rect.size.x - 100.0 and level_rect.size.x <= home.LEVEL_WIDTH_MAX + 0.5
		and level_rect.size.x >= home.LEVEL_WIDTH - 0.5 and is_equal_approx(level_rect.size.y, home.LEVEL_HEIGHT))
	_c("%s level pill'i madalyonlarla / maskotla çakışmıyor" % tag, not _mascot_hits(mascot_rect, level_visual)
		and _clear_of_features(home, level_visual))
	# Uzun ekranda alt boşluk: maskot/dumpling ile OYNA arası 1280'e göre
	# orantılı büyür ama 500 px'i geçmez (dünya bandı, ölü boşluk değil).
	var band: float = level_rect.position.y - mascot_rect.end.y
	_c("%s maskot ile level pill'i arası ≤ 420 px" % tag, band <= 420.0)


func _clear_of_features(home: CanvasLayer, rect: Rect2) -> bool:
	for key in FEATURES:
		if home.feature_button(key).visual_rect().intersects(rect):
			return false
	return true


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
	SaveManager.data["equipped_skin"] = "rare_02"
	SaveManager.data["merges_since_bonus_chest"] = 49
	SaveManager.data["endless_high_score"] = 0


func _apply_fresh() -> void:
	SaveManager.data["highest_level_unlocked"] = 1
	SaveManager.data["level_stars"] = {}
	SaveManager.data["dough"] = 0
	SaveManager.data["daily_streak"] = 0
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.data["unlocked_skins"] = []
	SaveManager.data["equipped_skin"] = ""
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
	SaveManager.data["equipped_skin"] = "legendary_02"
	SaveManager.data["merges_since_bonus_chest"] = 74
	SaveManager.data["endless_high_score"] = 12480
