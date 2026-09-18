extends Node
## İkincil pencere iskeleti v2 + Ayarlar + Günlük + Mola/Bonus Sandık cilası
## (M8.6-08) regresyon testi. Headless, kaydı byte olarak geri koyar.
##
##   godot --headless --audio-driver Dummy --path . res://tools/secondary_modal_ui_test.tscn
##
## Kontroller:
##   İSKELET   `UiKit.modal_shell`: kurdele / başlık+tepelik modları, oturmuş X
##             (kurdele kuyruğuyla kesişmez, krem halka), gövde içeriği panelin
##             içinde, altlık çerçevenin içinde, doğal yükseklik / tavan,
##             kısa tavanda gövde KAYDIRILIR (altlık yerinde), karartma arka
##             plana tıklamayı geçirmez, taşınan ekranlarda gerilmiş
##             `panel_candy` / `ModalPanel` / `CandyButton` bağımlılığı yok,
##             `modal_frame` (Mağaza onayı) değişmedi.
##   AYARLAR   tek örnek, X / Kapat / Android geri kapatır, SFX ve Titreşim
##             anahtarları kanonik SaveManager yolundan yazar, açıp kapamak
##             kayda YAZMAZ, ilgisiz alan/ekonomi değişmez; Gizlilik kapalı /
##             açık: metin, sürüm ve Kapat panelin içinde (eski taşma kusuru
##             regresyonu) — 720×1280 / 1560 / 540×960 / 1080×2340 / A36;
##             kısa tavanda (640) gövde kaydırılır, Kapat ve sürüm görünür
##             (canvas_items + expand tuvali hiçbir pencerede 1280'in altına
##             indirmez; gerçek en kısa durum 1280 ve ona sığar).
##   GÜNLÜK    gerçek claim yolu: +15 Hamur ve seri TAM BİR KEZ; AL ikinci
##             mutasyon yapmaz, kutlama sonrası kapanır ve Ana Sayfa yenilenir;
##             ikinci claim engellenir (durum modu, TAMAM); 7 düğüm ve
##             durumları; uzun seri "+N"; kırık seri notu; X / geri / karartma
##             kapatır; otomatik açılış çift pencere üretmez; 540×960'ta 7
##             düğüm görünür.
##   MOLA      oturmuş X, kahraman / ikincil / tehlike hiyerarşisi, kontroller
##             çerçevede, karartma tam ekran STOP, board donuk; Ayarlar üstte
##             (katman 13 > 12), Ayarlar açıkken mola açılmaz.
##   SANDIK    oturmuş X, ilerleme kaynağı, OYNA rotası, ödül/kayıt yazımı yok,
##             gövde çerçevede.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const VIEWS: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(720, 1560), Vector2i(540, 960), Vector2i(1080, 2340)]
const A36_SAFE_TOP: float = 61.0
const RUNTIME_FILES: Array[String] = [
	"res://scripts/ui/ui_kit.gd", "res://scripts/ui/streak_strip.gd",
	"res://scripts/ui/settings_panel.gd", "res://scripts/ui/daily_reward_popup.gd",
	"res://scripts/ui/pause_menu.gd", "res://scripts/ui/bonus_chest_info.gd",
	"res://scenes/ui/settings_panel.tscn", "res://scenes/ui/daily_reward_popup.tscn",
	"res://scenes/ui/pause_menu.tscn", "res://scenes/ui/bonus_chest_info.tscn",
]
const FORBIDDEN: Array[String] = ["_visual_source", "layerlab_spike", "layerlab_casual_game", "unitypackage"]
const LEGACY: Array[String] = ["panel_candy.png", "ModalPanel", "CandyButton", "UiPalette", "cta_button_normal"]
const MIGRATED_SOURCES: Array[String] = [
	"res://scripts/ui/settings_panel.gd", "res://scripts/ui/daily_reward_popup.gd",
	"res://scenes/ui/settings_panel.tscn", "res://scenes/ui/daily_reward_popup.tscn",
	"res://scripts/ui/pause_menu.gd", "res://scripts/ui/bonus_chest_info.gd",
	# M8.6-10: Devam + Refill de tasindi.
	"res://scripts/ui/revive_offer.gd", "res://scenes/ui/revive_offer.tscn",
	"res://scripts/ui/power_refill.gd", "res://scenes/ui/power_refill.tscn",
]

var _fails: int = 0
var _checks: int = 0
var _saved: Dictionary = {}
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _main: Node2D


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	await get_tree().process_frame
	_saved = SaveManager.data.duplicate(true)
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	# main._ready günlük ödülü bugün alınmış saysın (kayda yazmasın).
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	_apply_showcase()
	get_window().size = Vector2i(720, 1000)
	await get_tree().process_frame
	await _resize(VIEWS[0])

	await _test_shell()

	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_main._daily.visible = false

	await _test_settings()
	await _test_settings_sizes()
	await _test_daily()
	await _test_pause()
	await _test_chest()
	_test_sources()

	_main.queue_free()
	await get_tree().process_frame
	SaveManager.data = _saved
	_restore_save_file()
	var restored: bool = not _had_save or FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == _save_bytes
	_c("kayıt dosyası test sonunda byte-identical geri kondu", restored)
	print("=== SONUC: %d/%d kontrol, %d kaldi ===" % [_checks - _fails, _checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


# --- İskelet -------------------------------------------------------------------

func _test_shell() -> void:
	print("-- iskelet v2 (modal_shell)")
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(center)

	# Kurdele modu (Mola / Bonus Sandık).
	var ribbon_shell: Control = UiKit.modal_shell("Mola", 560.0, &"ribbon", false, true)
	center.add_child(ribbon_shell)
	var body: VBoxContainer = ribbon_shell.get_meta(&"body")
	var footer: VBoxContainer = ribbon_shell.get_meta(&"footer")
	for i in 3:
		body.add_child(UiKit.label("Satır %d" % i, &"LabelBody"))
	var cta := UiKit.cta("DEVAM ET", "", &"ButtonCTA")
	footer.add_child(cta)
	UiKit.modal_relayout(ribbon_shell)
	await _settle(2)
	var close: Button = ribbon_shell.get_meta(&"close_button")
	var ribbon: Control = ribbon_shell.get_meta(&"ribbon")
	_c("kurdele modu: gövde + altlık + kurdele + kapat, başlık/tepelik yok",
		body != null and footer != null and ribbon != null and close != null
		and not ribbon_shell.has_meta(&"heading") and not ribbon_shell.has_meta(&"topper"))
	_c("kapat ButtonRoundIcon + oturak halkası (05.1 reçetesi)", close.theme_type_variation == &"ButtonRoundIcon"
		and close.has_meta(&"seat_ring") and close.get_child_count() >= 2)
	_c("kurdele iki yandan 60 px içeride (varsayılan modal_frame 24)", is_equal_approx(ribbon.offset_left, 60.0)
		and is_equal_approx(ribbon.offset_right, -60.0)
		and is_equal_approx((UiKit.modal_frame("x").get_meta(&"ribbon") as Control).offset_left, 24.0))
	_c("kapat dairesi kurdele kuyruğuyla KESİŞMİYOR", not close.get_global_rect().intersects(ribbon.get_global_rect()))
	_c("kapat dokunma hedefi ≥ 56", close.size.x >= 56.0 and close.size.y >= 56.0)
	var panel: Control = ribbon_shell.get_meta(&"panel")
	_c("gövde içeriği panelin içinde", _children_inside(body, panel.get_global_rect()))
	_c("altlık CTA çerçevenin içinde ve gövdenin altında", panel.get_global_rect().encloses(cta.get_global_rect())
		and cta.get_global_rect().position.y >= (ribbon_shell.get_meta(&"body_host") as Control).get_global_rect().end.y)
	var natural_h: float = ribbon_shell.size.y
	_c("doğal yükseklik: gövde kaydırılmıyor, solma bandı gizli", not bool(ribbon_shell.get_meta(&"body_scrolls"))
		and not (ribbon_shell.get_meta(&"fade") as Control).visible and natural_h > 200.0)

	# Başlık + tepelik modu (Ayarlar / Günlük) + kaydırma tavanı.
	var topper_shell: Control = UiKit.modal_shell("GÜNLÜK ÖDÜL", 560.0, &"heading", true, true)
	center.add_child(topper_shell)
	ribbon_shell.visible = false
	var t_body: VBoxContainer = topper_shell.get_meta(&"body")
	var t_footer: VBoxContainer = topper_shell.get_meta(&"footer")
	var rows: Array[Control] = []
	# 26 × 48 + aralar ≈ 1560 px doğal gövde: 1280 tuvalinde tavanı aşar.
	for i in 26:
		var row := UiKit.label("Uzun içerik satırı %d" % i, &"LabelBody")
		row.custom_minimum_size = Vector2(0, 48)
		t_body.add_child(row)
		rows.append(row)
	var t_cta := UiKit.button("Kapat", &"ButtonSecondary")
	t_footer.add_child(t_cta)
	UiKit.modal_relayout(topper_shell)
	await _settle(2)
	var heading: Label = topper_shell.get_meta(&"heading")
	var topper: TextureRect = topper_shell.get_meta(&"topper")
	_c("başlık modu: gövde içi Baloo başlık (LabelTitle), kurdele yok", heading != null
		and heading.text == "GÜNLÜK ÖDÜL" and heading.theme_type_variation == &"LabelTitle"
		and not topper_shell.has_meta(&"ribbon"))
	_c("tepelik owner kanatlı-kalp, 300×96 kutu, oran korunur (1024×328 → 3.12)",
		topper != null and topper.texture == UiKit.MODAL_TOPPER_ART
		and is_equal_approx(topper.size.x, 300.0) and is_equal_approx(topper.size.y, 96.0)
		and topper.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		and absf(topper.size.x / topper.size.y - 1024.0 / 328.0) < 0.02)
	_c("tepelik gövdenin üstünden 62 px taşar, X kapat tepelikle kesişmez",
		is_equal_approx(topper.offset_top, -UiKit.MODAL_TOPPER_OVERHANG)
		and not (topper_shell.get_meta(&"close_button") as Control).get_global_rect().intersects(topper.get_global_rect()))
	var t_panel: Control = topper_shell.get_meta(&"panel")
	var view_h: float = get_viewport().get_visible_rect().size.y
	_c("uzun içerik: gövde tavanla KAYDIRILIYOR, pencere ekrana sığıyor (%.0f ≤ %.0f)"
		% [topper_shell.size.y, view_h], bool(topper_shell.get_meta(&"body_scrolls"))
		and topper_shell.size.y + UiKit.MODAL_TOPPER_OVERHANG <= view_h - 2.0 * UiKit.MODAL_OUTER_MARGIN + 1.0
		and (topper_shell.get_meta(&"fade") as Control).visible)
	_c("kaydırmalı gövdede altlık çerçevenin içinde ve görünür", t_panel.get_global_rect().encloses(t_cta.get_global_rect())
		and t_cta.is_visible_in_tree())
	var host_rect: Rect2 = (topper_shell.get_meta(&"body_host") as Control).get_global_rect()
	_c("gövde yuvası MODAL_BODY_MIN'in altına inmiyor", host_rect.size.y >= UiKit.MODAL_BODY_MIN - 0.5)
	_c("ilk satır görünür, son satır yuvanın dışında (kaydırılacak)", host_rect.encloses(rows[0].get_global_rect())
		and not host_rect.encloses(rows[25].get_global_rect()))
	# Dışarıdan tavan: min/max sistemi.
	UiKit.set_modal_height_cap(topper_shell, 640.0)
	await _settle(2)
	_c("dış tavan 640: pencere ≤ 640, gövde kaydırılıyor, altlık içeride", topper_shell.size.y <= 640.5
		and bool(topper_shell.get_meta(&"body_scrolls"))
		and t_panel.get_global_rect().encloses(t_cta.get_global_rect()))
	UiKit.set_modal_height_cap(topper_shell, 4000.0)
	await _settle(2)
	_c("tavan kalkınca gövde doğal yüksekliğe büyür, kaydırma kapanır", not bool(topper_shell.get_meta(&"body_scrolls"))
		and (topper_shell.get_meta(&"body_host") as Control).size.y >= 26.0 * 48.0)
	UiKit.set_modal_height_cap(topper_shell, 0.0)
	# Boş gövde: yuva gizlenir, altlık tek başına.
	var empty_shell: Control = UiKit.modal_shell("Boş", 560.0, &"ribbon", false, true)
	center.add_child(empty_shell)
	(empty_shell.get_meta(&"footer") as VBoxContainer).add_child(UiKit.button("Tamam"))
	UiKit.modal_relayout(empty_shell)
	await _settle(2)
	_c("boş gövde: yuva gizli, altlık görünür", not (empty_shell.get_meta(&"body_host") as Control).visible
		and (empty_shell.get_meta(&"footer") as Control).visible)
	# Kapatılamaz pencere.
	var no_close: Control = UiKit.modal_shell("Karar", 560.0, &"ribbon", false, false)
	_c("closable=false: kapat yok", not no_close.has_meta(&"close_button"))
	no_close.free()
	host.queue_free()
	await get_tree().process_frame


# --- Ayarlar -------------------------------------------------------------------

func _test_settings() -> void:
	print("-- Ayarlar")
	_main._show_tab(0)
	await _settle(2)
	var settings: CanvasLayer = _main._settings
	var file_before: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	var data_before: Dictionary = SaveManager.data.duplicate(true)
	var closed_count: Array = []
	settings.closed.connect(func() -> void: closed_count.append(true))

	_main.open_settings()
	_main.open_settings()
	await _settle(2)
	_c("ayarlar açıldı; tek örnek, tek iskelet", settings.visible and _count_class(_main, "CanvasLayer", "SettingsPanel") == 1
		and _count_named(settings, "ModalShell") == 1)
	_c("katman 13 (Mola 12'nin üstünde)", settings.layer == 13 and _main._pause.layer == 12)
	var frame: Control = settings.frame()
	_c("iskelet: başlık AYARLAR + tepelik + oturmuş X", (frame.get_meta(&"heading") as Label).text == "AYARLAR"
		and frame.has_meta(&"topper") and (frame.get_meta(&"close_button") as Button).has_meta(&"seat_ring"))
	_c("anahtarlar UiKit.switch_toggle (SwitchOn/Off + LayerLab topuz), ≥ 48 px, PASS",
		settings._sfx_toggle.on_variation == &"SwitchOn" and settings._sfx_toggle.knob_texture != null
		and settings._sfx_toggle.size.y >= 48.0 and settings._sfx_toggle.size.x >= 48.0
		and settings._sfx_toggle.mouse_filter == Control.MOUSE_FILTER_PASS)
	_c("anahtarlar kayıttaki değerle açılıyor (ikisi de açık)", settings._sfx_toggle.button_pressed
		and settings._haptics_toggle.button_pressed)
	_c("açmak kayda yazmadı", FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == file_before)

	# SFX: kanonik yol.
	settings._sfx_toggle.button_pressed = false
	await get_tree().process_frame
	_c("SFX kapalı → SaveManager.set_sfx_enabled: kayıt false + bus mute",
		SaveManager.data["sfx_enabled"] == false and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")))
	settings._sfx_toggle.button_pressed = true
	await get_tree().process_frame
	_c("SFX açık → kayıt true + bus açık", SaveManager.data["sfx_enabled"] == true
		and not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")))
	settings._haptics_toggle.button_pressed = false
	await get_tree().process_frame
	_c("Titreşim kapalı → set_haptics_enabled: kayıt false + Haptics kapalı",
		SaveManager.data["haptics_enabled"] == false and not Haptics.is_enabled())
	settings._haptics_toggle.button_pressed = true
	await get_tree().process_frame
	_c("Titreşim açık → kayıt true + Haptics açık", SaveManager.data["haptics_enabled"] == true and Haptics.is_enabled())
	# Anahtarlar (tasarım gereği) yazdı; bundan sonraki açma/kapama yazmamalı.
	var file_mid: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	var data_after: Dictionary = SaveManager.data.duplicate(true)
	data_after.erase("sfx_enabled")
	data_after.erase("haptics_enabled")
	data_before.erase("sfx_enabled")
	data_before.erase("haptics_enabled")
	_c("ilgisiz alan / ekonomi değişmedi (Hamur 335, skin, seri)", data_after == data_before and SaveManager.dough() == 335)

	# Gizlilik: kapalı → açık → kapalı, metin/sürüm/Kapat panelin içinde.
	var panel: Control = frame.get_meta(&"panel")
	_c("gizlilik kapalı başlıyor (Göster)", not settings.is_privacy_open() and settings._privacy_button.text == "Göster")
	var collapsed_h: float = frame.size.y
	settings._privacy_button.pressed.emit()
	await _settle(3)
	_c("Göster → metin açık (Gizle), pencere büyüdü", settings.is_privacy_open()
		and settings._privacy_button.text == "Gizle" and frame.size.y > collapsed_h + 60.0)
	_c("gizlilik metni kanonik kopya, panelin içinde", settings._privacy_text.text == settings.PRIVACY_TEXT
		and panel.get_global_rect().encloses(settings._privacy_text.get_global_rect()))
	_c("ESKİ TAŞMA REGRESYONU: sürüm satırı ve Kapat panelin İÇİNDE (720×1280)",
		panel.get_global_rect().encloses(settings._about.get_global_rect())
		and panel.get_global_rect().encloses(settings._close.get_global_rect()))
	_c("sürüm satırı LabelCaption düşük vurgu, metni project.godot sürümü",
		settings._about.theme_type_variation == &"LabelCaption"
		and settings._about.text.contains(String(ProjectSettings.get_setting("application/config/version", "dev"))))
	settings._privacy_button.pressed.emit()
	await _settle(2)
	_c("Gizle → kapandı, pencere eski yüksekliğine döndü", not settings.is_privacy_open()
		and absf(frame.size.y - collapsed_h) < 1.0)

	# Kapanış yolları.
	settings._close.pressed.emit()
	await get_tree().process_frame
	_c("Kapat → kapandı, closed 1 kez", not settings.visible and closed_count.size() == 1)
	_main.open_settings()
	await _settle(2)
	(frame.get_meta(&"close_button") as Button).pressed.emit()
	await get_tree().process_frame
	_c("X → kapandı, closed 2", not settings.visible and closed_count.size() == 2)
	_main.open_settings()
	await _settle(2)
	_main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	_c("Android geri → kapandı, Ana Sayfa aynı (sekme 0), uygulama açık", not settings.visible
		and _main._active_tab == 0 and closed_count.size() == 3)
	# Karartma arka plana tıklamayı geçirmez: Ana Sayfa OYNA'nın üstüne tık.
	await _settle(20)
	_main.open_settings()
	await _settle(4)
	var home: CanvasLayer = _main._screens[0]
	var play: Button = home.play_button()
	var at: Vector2 = play.get_global_rect().get_center()
	_pointer(at, true)
	await get_tree().process_frame
	_pointer(at, false)
	await _settle(3)
	_c("karartma: OYNA'nın üstüne tık Harita'ya GİTMEDİ, karartma dokunuşu pencereyi kapattı",
		_main._active_tab == 0 and not settings.visible)
	_c("açıp kapamak (anahtar dokunuşu yok) kaydı yazmadı", FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == file_mid)


func _test_settings_sizes() -> void:
	print("-- Ayarlar: pencere boyutları (gizlilik açık)")
	var settings: CanvasLayer = _main._settings
	var frame: Control = settings.frame()
	var panel: Control = frame.get_meta(&"panel")
	for view in VIEWS:
		await _resize(view)
		_main.open_settings()
		await _settle(2)
		settings._privacy_button.pressed.emit()
		await _settle(4)
		var canvas: Vector2 = get_viewport().get_visible_rect().size
		var frame_rect: Rect2 = frame.get_global_rect()
		var screen: Rect2 = Rect2(Vector2.ZERO, canvas)
		var inside: bool = panel.get_global_rect().encloses(settings._privacy_text.get_global_rect()) \
			and panel.get_global_rect().encloses(settings._about.get_global_rect()) \
			and panel.get_global_rect().encloses(settings._close.get_global_rect()) \
			and _children_inside(frame.get_meta(&"body"), panel.get_global_rect())
		_c("%dx%d: gizlilik açık — metin, sürüm, Kapat panelde; pencere ekranda; gövde kaydırılmıyor"
			% [view.x, view.y], inside and screen.encloses(frame_rect)
			and frame_rect.position.y - UiKit.MODAL_TOPPER_OVERHANG >= 0.0
			and not bool(frame.get_meta(&"body_scrolls")))
		_c("%dx%d: metin ≥ 19 px gövde yazısı (küçültülmedi), satırlar ≥ 48 px"
			% [view.x, view.y], settings._privacy_text.get_theme_font_size("font_size") >= 19
			and settings._sfx_toggle.size.y >= 48.0)
		_main.close_settings()
		await get_tree().process_frame
	# A36 simülasyonu (720×1560 + 61 px üst pay): pencere payın altında.
	await _resize(Vector2i(720, 1560))
	_main.open_settings()
	await _settle(2)
	settings._privacy_button.pressed.emit()
	await _settle(4)
	_c("A36 (1560 + 61): pencere tepelikle birlikte payın altında, alt gezinme bölgesinden uzak",
		frame.get_global_rect().position.y - UiKit.MODAL_TOPPER_OVERHANG >= A36_SAFE_TOP
		and frame.get_global_rect().end.y <= 1560.0 - 120.0)
	_main.close_settings()
	# Kısa ekran provası: canvas_items + expand tuvali hiçbir pencerede 1280
	# px'in altına indirmez (540×960 = 720×1280'in 0.75'i), gerçek en kısa
	# durum 1280'dir ve gizlilik açık Ayarlar ona sığar (yukarıdaki kontroller).
	# Tavan sistemi daha kısa bir tuvali dışarıdan sınırlayarak kanıtlanır.
	await _resize(VIEWS[0])
	_main.open_settings()
	await _settle(2)
	settings._privacy_button.pressed.emit()
	UiKit.set_modal_height_cap(frame, 640.0)
	await _settle(4)
	var canvas_short: Vector2 = get_viewport().get_visible_rect().size
	_c("kısa tavan (640): gövde KAYDIRILIYOR, Kapat ve sürüm görünür, pencere ≤ 640 ve ekranda, metin küçülmedi",
		bool(frame.get_meta(&"body_scrolls")) and settings._close.is_visible_in_tree()
		and frame.size.y <= 640.5 and Rect2(Vector2.ZERO, canvas_short).encloses(frame.get_global_rect())
		and panel.get_global_rect().encloses(settings._close.get_global_rect())
		and panel.get_global_rect().encloses(settings._about.get_global_rect())
		and settings._privacy_text.get_theme_font_size("font_size") >= 19)
	var host_rect: Rect2 = (frame.get_meta(&"body_host") as Control).get_global_rect()
	var scroll: ScrollContainer = frame.get_meta(&"scroll")
	scroll.scroll_vertical = 10000
	await _settle(2)
	_c("kısa tavanda gövde sonuna kaydırılınca gizlilik metni yuvada tam görünür",
		host_rect.encloses(settings._privacy_text.get_global_rect().grow(-0.5)))
	UiKit.set_modal_height_cap(frame, 0.0)
	await _settle(2)
	_c("tavan kalkınca gövde kaydırılmıyor", not bool(frame.get_meta(&"body_scrolls")))
	_main.close_settings()
	await _resize(VIEWS[0])


# --- Günlük ---------------------------------------------------------------------

func _test_daily() -> void:
	print("-- Günlük ödül")
	await _resize(VIEWS[0])
	_apply_showcase()
	_main._show_tab(0)
	await _settle(2)
	var daily: CanvasLayer = _main._daily
	var home: CanvasLayer = _main._screens[0]
	var closed_count: Array = []
	daily.closed.connect(func() -> void: closed_count.append(true))
	_c("kapalı başlıyor, tek örnek", not daily.visible and _count_class(_main, "CanvasLayer", "DailyRewardPopup") == 1)

	# Gerçek claim yolu: dün giriş yapılmış → Günlük madalyonu.
	SaveManager.data["last_login_date"] = _yesterday()
	SaveManager.data["daily_streak"] = 2
	home.refresh()
	var dough_before: int = SaveManager.dough()
	_main._on_daily_requested()
	await _settle(4)
	_c("claim: +%d Hamur ve seri 3 TAM BİR KEZ (DailyReward.claim_if_new_day)" % DailyReward.DAILY_DOUGH,
		SaveManager.dough() == dough_before + DailyReward.DAILY_DOUGH and SaveManager.daily_streak() == 3
		and SaveManager.last_login_date() == Time.get_date_string_from_system())
	_c("ödül penceresi açık: AL kahraman CTA (ButtonCTA), +15 HAMUR", daily.visible and daily.cta_text() == "AL"
		and daily.cta_button().theme_type_variation == &"ButtonCTA"
		and daily._reward.text == "+%d HAMUR" % DailyReward.DAILY_DOUGH)
	var strip: StreakStrip = daily.strip()
	_c("seri şeridi: 7 düğüm; 1-2 alınmış, 3 bugün (kutlanmamış), 4-7 gelecek", strip.node_count() == 7
		and strip.node_state(0) == StreakStrip.State.CLAIMED and strip.node_state(1) == StreakStrip.State.CLAIMED
		and strip.node_state(2) == StreakStrip.State.TODAY and strip.node_state(3) == StreakStrip.State.FUTURE
		and strip.node_state(6) == StreakStrip.State.FUTURE and not strip.is_today_marked()
		and strip.plus_badge_text() == "")
	_c("gün rozeti '3. GÜN', not yok", daily._day_label.text == "3. GÜN" and not daily._note.visible)
	var frame: Control = daily.frame()
	var panel: Control = frame.get_meta(&"panel")
	_c("gövde (kuyu, ödül, rozet, şerit) panelin içinde; AL çerçevede", _children_inside(frame.get_meta(&"body"), panel.get_global_rect())
		and panel.get_global_rect().encloses(daily.cta_button().get_global_rect()))
	_c("iskelet: tepelik + GÜNLÜK ÖDÜL + oturmuş X", frame.has_meta(&"topper")
		and (frame.get_meta(&"heading") as Label).text == "GÜNLÜK ÖDÜL"
		and (frame.get_meta(&"close_button") as Button).has_meta(&"seat_ring"))
	# AL: kutlama, ikinci mutasyon YOK, sonra kapanır.
	var file_after_claim: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	daily.cta_button().pressed.emit()
	await get_tree().process_frame
	_c("AL → bugünkü düğüm kutlandı (yıldız), pencere hâlâ açık (kısa kutlama)", strip.is_today_marked()
		and daily.visible and daily.is_claim_pending())
	daily.cta_button().pressed.emit()
	await _settle(1)
	_c("AL kayda DOKUNMADI: Hamur, seri, tarih aynı; dosya aynı", SaveManager.dough() == dough_before + DailyReward.DAILY_DOUGH
		and SaveManager.daily_streak() == 3 and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == file_after_claim)
	await get_tree().create_timer(daily.CLAIM_CLOSE_DELAY + 0.25).timeout
	await get_tree().process_frame
	_c("kutlama sonrası pencere kapandı, closed 1 kez (çift basış tek kapanış)", not daily.visible and closed_count.size() == 1)
	_c("kapanınca Ana Sayfa yenilendi: Hamur pill'i güncel, bildirim noktası yok",
		_pill_text(home.dough_pill()) == str(dough_before + DailyReward.DAILY_DOUGH)
		and not home.feature_button(&"daily").has_notification())
	# İkinci claim engellenir: durum modu.
	_main._on_daily_requested()
	await _settle(2)
	_c("ikinci claim YOK: durum penceresi ('aldın', TAMAM ButtonPrimary), Hamur aynı", daily.visible
		and daily.cta_text() == "TAMAM" and daily.cta_button().theme_type_variation == &"ButtonPrimary"
		and daily._reward.text.contains("aldın") and SaveManager.dough() == dough_before + DailyReward.DAILY_DOUGH)
	_c("durum modunda bugünkü düğüm yıldızlı (alınmış), not 'yarın tekrar gel'", strip.is_today_marked()
		and strip.node_state(2) == StreakStrip.State.TODAY and daily._note.visible
		and daily._note.text.begins_with("Yarın"))
	daily.cta_button().pressed.emit()
	await get_tree().process_frame
	_c("TAMAM → hemen kapandı", not daily.visible and closed_count.size() == 2)
	# Otomatik açılış çift pencere üretmez.
	_main._check_daily_reward()
	await get_tree().process_frame
	_c("bugün alınmışken _check_daily_reward pencere AÇMAZ, ödül vermez", not daily.visible
		and SaveManager.dough() == dough_before + DailyReward.DAILY_DOUGH)
	# Vitrin durumları (kayda yazmaz): uzun seri, kırık seri.
	daily.show_reward({"claimed": true, "streak": 12, "reward": DailyReward.DAILY_DOUGH, "streak_broken": false})
	await _settle(2)
	_c("uzun seri 12: 7. düğüm bugün, '+5' rozeti, '12. GÜN'", strip.node_state(6) == StreakStrip.State.TODAY
		and strip.node_state(5) == StreakStrip.State.CLAIMED and strip.plus_badge_text() == "+5"
		and daily._day_label.text == "12. GÜN")
	_c("'+5' rozeti gövdenin içinde (kırpılmıyor)", (frame.get_meta(&"body_host") as Control).get_global_rect().encloses(
		strip.get_node("PlusBadge").get_global_rect()))
	daily.close_popup()
	daily.show_reward({"claimed": true, "streak": 1, "reward": DailyReward.DAILY_DOUGH, "streak_broken": true})
	await _settle(2)
	_c("kırık seri: 1. düğüm bugün, not LabelWarning 'Serin kırılmıştı…'", strip.node_state(0) == StreakStrip.State.TODAY
		and strip.node_state(1) == StreakStrip.State.FUTURE and daily._note.visible
		and daily._note.theme_type_variation == &"LabelWarning" and daily._note.text.begins_with("Serin"))
	# Kapanış yolları: X, geri, karartma.
	(frame.get_meta(&"close_button") as Button).pressed.emit()
	await get_tree().process_frame
	_c("X → kapandı", not daily.visible)
	daily.show_status(4)
	await _settle(2)
	await _settle(18)
	_main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	_c("Android geri → kapandı, Ana Sayfa (sekme 0)", not daily.visible and _main._active_tab == 0)
	daily.show_status(4)
	await _settle(4)
	var dim_at := Vector2(360.0, 60.0)
	_pointer(dim_at, true)
	await get_tree().process_frame
	_pointer(dim_at, false)
	await _settle(2)
	_c("karartma dokunuşu → kapandı; arkadaki üst satır ayarlar butonu AÇILMADI", not daily.visible
		and not _main._settings.visible and _main._active_tab == 0)
	# 540×960: yedi düğüm görünür ve panelde.
	await _resize(Vector2i(540, 960))
	daily.show_reward({"claimed": true, "streak": 4, "reward": DailyReward.DAILY_DOUGH, "streak_broken": false})
	await _settle(4)
	var all_visible: bool = true
	for i in 7:
		var node: Control = strip.node(i)
		if not panel.get_global_rect().encloses(node.get_global_rect()) or node.size.x < 40.0:
			all_visible = false
	_c("540×960: 7 düğüm panelin içinde, her biri ≥ 40 tuval px (≥ 30 px fiziksel)", all_visible)
	_c("540×960: AL çerçevede ve ekranda", panel.get_global_rect().encloses(daily.cta_button().get_global_rect())
		and Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).encloses(frame.get_global_rect()))
	daily.close_popup()
	await _resize(VIEWS[0])
	_apply_showcase()
	home.refresh()


# --- Mola -----------------------------------------------------------------------

func _test_pause() -> void:
	print("-- Mola")
	_main._start_level(load("res://resources/levels/level_04.tres"))
	await get_tree().process_frame
	await get_tree().process_frame
	_main._board._dismiss_tutorial()
	await _settle(2)
	_main.open_pause_menu()
	await _settle(4)
	var pause: CanvasLayer = _main._pause
	var frame: Control = pause.frame()
	var close: Button = frame.get_meta(&"close_button")
	var ribbon: Control = frame.get_meta(&"ribbon")
	_c("mola açık, board donuk", pause.visible and _main._board._is_menu_paused)
	_c("oturmuş X: halka var, kurdele kuyruğuyla kesişmiyor", close.has_meta(&"seat_ring")
		and not close.get_global_rect().intersects(ribbon.get_global_rect()))
	var buttons: Array[Button] = pause.buttons()
	_c("hiyerarşi: DEVAM ET ButtonCTA (88) > Yeniden Başlat ButtonSecondary (58) = Ana Menüye Dön ButtonDanger (58)",
		buttons[0].theme_type_variation == &"ButtonCTA" and buttons[1].theme_type_variation == &"ButtonSecondary"
		and buttons[2].theme_type_variation == &"ButtonDanger" and buttons[0].size.y > buttons[1].size.y
		and buttons[2].size.y <= buttons[1].size.y + 0.5)
	var panel: Control = frame.get_meta(&"panel")
	var inside: bool = true
	for b in buttons:
		if not panel.get_global_rect().encloses(b.get_global_rect()):
			inside = false
	_c("üç eylem çerçevenin içinde, altlıkta (kaydırılmaz)", inside and buttons[0].get_parent() == frame.get_meta(&"footer"))
	var dim: ColorRect = pause.get_node("Center/Dim")
	_c("karartma tam ekran ve STOP (gameplay girdisi sızmaz)", dim.mouse_filter == Control.MOUSE_FILTER_STOP
		and dim.get_global_rect().encloses(Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)))
	# Z-order: Ayarlar Mola'nın üstünde; Ayarlar açıkken mola açılmaz.
	_main.open_settings()
	await _settle(2)
	_c("Ayarlar mola üstünde (katman 13 > 12) ve görünür", _main._settings.visible and _main._settings.layer > pause.layer)
	_main.close_settings()
	await get_tree().process_frame
	_c("Ayarlar kapanınca mola açık kaldı, board hâlâ donuk", pause.visible and _main._board._is_menu_paused)
	_main.resume_game()
	await get_tree().process_frame
	_c("devam: mola kapandı, board çözüldü", not pause.visible and not _main._board._is_menu_paused)
	_main._on_board_settings_requested()
	await _settle(2)
	_main.open_pause_menu()
	await get_tree().process_frame
	_c("Ayarlar açıkken open_pause_menu mola AÇMAZ (tek odak kuralı)", _main._settings.visible and not pause.visible)
	_main.close_settings()
	await get_tree().process_frame
	_c("oyun içi Ayarlar kapanınca board çözüldü", not _main._board._is_menu_paused)
	_main.abandon_run()
	await _settle(2)
	_c("terk: Harita (sekme 1), board yok", _main._active_tab == 1 and _main._board == null)
	_main._show_tab(0)
	await _settle(2)


# --- Bonus Sandık ---------------------------------------------------------------

func _test_chest() -> void:
	print("-- Bonus Sandık bilgisi")
	_apply_showcase()
	var chest: CanvasLayer = _main._chest_info
	var file_before: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	var dough_before: int = SaveManager.dough()
	_main._on_chest_requested()
	await _settle(4)
	var frame: Control = chest.frame()
	var close: Button = frame.get_meta(&"close_button")
	var ribbon: Control = frame.get_meta(&"ribbon")
	_c("açık: 49/75, çubuk 49/75, 'Sandığa 26 merge kaldı'", chest.visible and chest.count_text() == "49/75"
		and absf(chest._bar.value - 49.0 / 75.0) < 0.011 and chest._remaining.text == "Sandığa 26 merge kaldı")
	_c("oturmuş X, kurdele kuyruğuyla kesişmiyor", close.has_meta(&"seat_ring")
		and not close.get_global_rect().intersects(ribbon.get_global_rect()))
	var panel: Control = frame.get_meta(&"panel")
	_c("gövde (kuyu, kural, çubuk, not) panelde; OYNA altlıkta çerçevede",
		_children_inside(frame.get_meta(&"body"), panel.get_global_rect())
		and panel.get_global_rect().encloses(chest.play_button().get_global_rect())
		and chest.play_button().get_parent() == frame.get_meta(&"footer"))
	_c("sandık sanatı altın candy kuyuda (ödül rengi)", chest._well != null and chest._well.has_meta(&"art")
		and (chest._well.get_meta(&"art") as TextureRect).texture == chest.CHEST_ART)
	chest.close_info()
	SaveManager.data["merges_since_bonus_chest"] = 74
	_main._on_chest_requested()
	await _settle(2)
	_c("ilerleme kaynağı merges_since_bonus_chest: 74/75, 1 kaldı", chest.count_text() == "74/75"
		and chest._remaining.text == "Sandığa 1 merge kaldı")
	chest.play_button().pressed.emit()
	await _settle(2)
	_c("OYNA → kapandı, Harita (sekme 1)", not chest.visible and _main._active_tab == 1)
	_c("bilgi penceresi ödül VERMEDİ, kayda YAZMADI", SaveManager.dough() == dough_before
		and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == file_before)
	_main._show_tab(0)
	await _settle(2)
	_main._on_chest_requested()
	await _settle(2)
	await _settle(18)
	_main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	_c("Android geri → sandık kapandı, Ana Sayfa", not chest.visible and _main._active_tab == 0)
	_apply_showcase()


# --- Kaynak hijyeni --------------------------------------------------------------

func _test_sources() -> void:
	print("-- kaynak hijyeni")
	var clean: bool = true
	for path in RUNTIME_FILES:
		var text: String = FileAccess.get_file_as_string(path)
		for word in FORBIDDEN:
			if text.contains(word):
				clean = false
				print("    yasak referans: ", path, " -> ", word)
	_c("runtime dosyalarında _visual_source / spike referansı yok", clean)
	var legacy_free: bool = true
	for path in MIGRATED_SOURCES:
		var text: String = FileAccess.get_file_as_string(path)
		for word in LEGACY:
			if text.contains(word):
				legacy_free = false
				print("    eski bağımlılık: ", path, " -> ", word)
	_c("taşınan ekranlarda panel_candy / ModalPanel / CandyButton / UiPalette yok", legacy_free)
	var shop_src: String = FileAccess.get_file_as_string("res://scripts/ui/shop_screen.gd")
	_c("Mağaza onayı hâlâ modal_frame + seat_modal_close (değişmedi)",
		shop_src.contains("UiKit.modal_frame(\"Satın Al\"") and shop_src.contains("UiKit.seat_modal_close(_frame)"))
	var daily_src: String = FileAccess.get_file_as_string("res://scripts/ui/daily_reward_popup.gd")
	var settings_src: String = FileAccess.get_file_as_string("res://scripts/ui/settings_panel.gd")
	_c("Günlük penceresi kayda yazmıyor (add_dough / record_daily_login / save_game yok)",
		not daily_src.contains("add_dough(") and not daily_src.contains("record_daily_login(")
		and not daily_src.contains("save_game("))
	_c("Ayarlar yalnız set_sfx_enabled / set_haptics_enabled yazıyor", settings_src.contains("SaveManager.set_sfx_enabled(")
		and settings_src.contains("SaveManager.set_haptics_enabled(") and not settings_src.contains("save_game(")
		and not settings_src.contains("add_dough("))
	_c("Günlük / Ayarlar / Mola / Sandık _process kullanmıyor (dinlenmede işlem yok)",
		not daily_src.contains("func _process") and not settings_src.contains("func _process")
		and not FileAccess.get_file_as_string("res://scripts/ui/streak_strip.gd").contains("func _process")
		and not FileAccess.get_file_as_string("res://scripts/ui/pause_menu.gd").contains("func _process")
		and not FileAccess.get_file_as_string("res://scripts/ui/bonus_chest_info.gd").contains("func _process"))


# --- Yardımcılar -----------------------------------------------------------------

func _restore_save_file() -> void:
	if not _had_save:
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()


## Yerel takvimde "dün" (DailyReward yerel günü okur).
func _yesterday() -> String:
	var local_unix: int = Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system())
	return Time.get_date_string_from_unix_time(local_unix - 86400)


func _resize(view: Vector2i) -> void:
	get_window().size = view
	await get_tree().process_frame
	await get_tree().process_frame


## N kare bekler (açılış tween'i 0.2 sn; 12+ kare = yerleşim + tween biter).
func _settle(frames: int) -> void:
	for i in maxi(frames, 1):
		await get_tree().process_frame
	if frames >= 4:
		await get_tree().create_timer(0.25).timeout
		await get_tree().process_frame


func _pointer(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	if pressed:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(ev)


func _pill_text(pill: Control) -> String:
	return (pill.get_meta(&"value_label") as Label).text


## Görünür çocukların (ve alt ağaçtaki etiket/butonların) global dikdörtgeni
## `rect`'in içinde mi.
func _children_inside(container: Control, rect: Rect2) -> bool:
	for child in container.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		if not rect.encloses(control.get_global_rect().grow(-0.5)):
			print("    dışarıda: ", control.name, " ", control.get_global_rect(), " panel ", rect)
			return false
	return true


func _count_class(root: Node, klass: String, name_part: String) -> int:
	var n: int = 0
	for node in root.get_children():
		if node.is_class(klass) and String(node.name).contains(name_part):
			n += 1
	return n


func _count_named(root: Node, name_part: String) -> int:
	var n: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if String(node.name).contains(name_part):
			n += 1
		for child in node.get_children():
			stack.append(child)
	return n


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
	SaveManager.data["powerups"] = {"bomb": 4, "upgrade": 1, "shake": 0, "clear_small": 0}
	SaveManager.data["rewarded_power_date"] = ""
	SaveManager.data["rewarded_power_grants"] = 0
	SaveManager.data["sfx_enabled"] = true
	SaveManager.data["haptics_enabled"] = true
