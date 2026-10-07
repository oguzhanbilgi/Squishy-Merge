extends Node
## TASK/046 — GÖREVLER arayüzü testi (Ana Sayfa girişi + pencere). Headless.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_missions_ui/` altındaki
## bir yola yönlendirilir, sonda geri alınır; gerçek kayıt ailesi başta / sonda karşılaştırılır.
##
##   godot --headless --audio-driver Dummy --path . res://tools/missions_ui_test.tscn
##
## Kontroller:
##   giriş       Ana Sayfa'da TEK GÖREVLER girişi (TASK/058: hero'nun sol üstünde ikincil HomeFeatureButton madalyonu;
##               alt sekme / yeni ekran yok),
##               N/6: 0 · kısmi · bir görev · günlükler tamam · altısı (nane rozet)
##   pencere     kurdele "GÖREVLER", GÜNLÜK / HAFTALIK başlıkları + sabit yenilenme ipuçları,
##               bölüm başına tam 3 kart (katalog sırası), metin / "x / y" / ray / "+10" / "+40",
##               TAMAMLANDI yalnız tamamlananlarda, "N / 6" + not; talep butonu YOK (tek buton X)
##   girdi       Android geri / X / karartma kapatır; girişe hızlı çift dokunuşun ikincisi
##               pencereyi kapatmaz, X'e hızlı çift dokunuşun ikincisi Ana Sayfa'ya düşmez;
##               yatışmadan sonra ilk dokunuş çalışır; kod yolu etkilenmez; yeniden açılış
##               güncel durum + baştan kaydırma
##   kapılar     sandık / ayarlar / günlük / yaş / kısıt ekranı açıkken açılmaz; açıkken sandık /
##               günlük kod yolu altına açmaz; Mağaza'ya geçiş / pencereleri kapat / round kapatır
##   yerleşim    320×568 / 360×640 / 390×844 / 360×800 / 1080×2340 (+ A36 üst payı 61): giriş
##               güvenli alanda, ≥ 84, sol üst köşe, hiçbir Ana Sayfa kontrolüyle / maskotun opak
##               pikselleriyle / logoyla çakışmıyor; pencere ekranda, üst pay altında, kartlar
##               erişilebilir, kırpma / çakışma yok; uzun metin kartı taşırmaz
##   dil         tek üretim dili Türkçe, çeviri / RTL katmanı yok (RTL uygulanamaz), "x / y" LTR
##   reklam      sahte arka uç: pencere yüzeyi değiştirmez, yeni banner / reklam çağrısı yok,
##               pencere banner yuvasının ÜSTÜNE oturur
##   kayıt       açmak / kapatmak / kaydırmak kayda yazmaz (bayt + yazma girişimi dedektörü); açık
##               pencere otomatik günlük pencereyi bastırır ("due" kalır); öne dönüşte gün dönümü
##               pencereyi ve Ana Sayfa rozetini aynı yeni döneme tazeler

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_missions_ui"
const PATH: String = DIR + "/save.json"
const DAY: String = "2026-09-29"
## Aynı haftanın ertesi günü (Salı → Çarşamba; hafta 2026-09-28 Pazartesi).
const NEXT_DAY: String = "2026-09-30"
## Pencere boyutları (dp oranı): 320×568, 360×640, 390×844, 360×800 ve A36 1080×2340.
const VIEWS: Array[Vector2i] = [Vector2i(320, 568), Vector2i(360, 640), Vector2i(390, 844), Vector2i(360, 800),
	Vector2i(1080, 2340)]
const A36_SAFE_TOP: float = 61.0
const SECTIONS: int = 9

var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _finished: bool = false
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _main: Node2D
var _main_script: GDScript
var _mascot_img: Image


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_main_script = load("res://scripts/main.gd")
	_owner_state = _owner_snapshot()
	_saved_data = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	SaveManager.save_path = PATH
	DailyRewards.clock_override = DAY
	get_tree().create_timer(360.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 360 s'de bitmedi — SaveManager geri alındı")
			# Main ÖNCE gider: yol gerçek kayda döndükten sonra yarım kalmış bir akış oraya yazamaz.
			if _main != null and is_instance_valid(_main):
				_main.free()
			_teardown()
			get_tree().quit(2))
	_write_fixture()
	SaveManager.load_game()
	await _resize(Vector2i(720, 1280))
	await _boot()
	_mascot_img = (_home().HERO_ART as Texture2D).get_image()

	await _entry_states()
	await _overlay_content()
	await _input_contract()
	await _gates_and_auto_close()
	await _layout_all()
	await _long_text()
	_locale()
	await _ads_banner()
	await _save_and_daily_gate()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	print("-- kayıt")
	await _teardown_main()
	_teardown()
	_c("SaveManager gerçek yola döndü, test klasörü silindi, saat kancası / hata enjeksiyonu boş",
		SaveManager.save_path == SaveManager.SAVE_PATH and not DirAccess.dir_exists_absolute(DIR)
		and DailyRewards.clock_override == "" and SaveFile.fault == SaveFile.Fault.NONE)
	_c("sahibin gerçek kayıt ailesi (kanonik + .tmp + .bak) bayt-aynı", _owner_snapshot() == _owner_state)
	_finished = true
	print("\nSONUC: %d kontrol, %d hata" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _exit_tree() -> void:
	if _finished:
		return
	print("  [FAIL] test SONUC'tan önce ağaçtan çıktı — SaveManager geri alındı")
	_teardown()


func _teardown() -> void:
	SaveFile.fault = SaveFile.Fault.NONE
	DailyRewards.clock_override = ""
	DailyRewards.auto_popup_enabled = false
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	UiKit.set_banner_slot(0.0)
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- 1) Giriş + N/6 ------------------------------------------------------------------------

func _entry_states() -> void:
	print("-- Ana Sayfa GÖREVLER girişi")
	var home: CanvasLayer = _home()
	var entry: Button = home.missions_button()
	_c("tek GÖREVLER girişi: HomeFeatureButton madalyonu (TASK/058 ikincil giriş, kabuk madalyon ailesi), dokunma alır",
		entry != null and entry is HomeFeatureButton and entry.theme_type_variation == &"ButtonFeature"
		and entry.mouse_filter == Control.MOUSE_FILTER_STOP and _count_named(home, "Missions") == 1)
	_c("etiket 'GÖREVLER' (Türkçe büyük harf, noktalı Ö)", (entry as HomeFeatureButton).label_text() == "GÖREVLER")
	_c("alt gezinme / yeni ekran yok: beş ekran aynen, sekme çubuğu yok", _main._screens.size() == 5
		and _main.get_node_or_null("TabBar") == null)
	_c("Ana Sayfa madalyonları iki (TASK/058: GÖREVLER + SANDIK; Mağaza / Koleksiyon kabukta)",
		_count_class(home, "HomeFeatureButton") == 2)
	var states: Array = [
		["0 ilerleme", _raw({}, [], {}, []), "0/6"],
		["kısmi (tamam yok)", _raw({"daily_merges": 7, "daily_rounds": 1}, [], {"weekly_merges": 46}, []), "0/6"],
		["bir görev tamam", _raw({"daily_clear": 1}, ["daily_clear"], {}, []), "1/6"],
		["günlükler tamam", _raw({}, ["daily_merges", "daily_rounds", "daily_clear"], {"weekly_rounds": 5}, []), "3/6"],
		["altısı tamam", _all_done(), "6/6"],
	]
	for state: Array in states:
		_set_missions(state[1])
		await _show_home()
		_c("N/6 — %s → '%s'" % [state[0], state[2]], home.missions_count_text() == state[2])
	var badge: PanelContainer = home.missions_badge()
	_c("6/6'da rozet nane (başarı), diğerlerinde tema altın rozeti", badge.has_theme_stylebox_override("panel")
		and (badge.get_theme_stylebox("panel") as StyleBoxTexture).modulate_color.is_equal_approx(UiTokens.MINT))
	_set_missions(_raw({}, [], {}, []))
	await _show_home()
	_c("  … 0/6'da rozet tema altını (geçersiz kılma yok)", not home.missions_badge().has_theme_stylebox_override("panel"))
	var bytes: PackedByteArray = _bytes()
	# Yazma girişimi dedektörü: tek atımlık hata kurulu kalırsa hiçbir write_save çağrılmadı
	# (dosya baytı aynı kalsa bile gereksiz bir yazmayı da yakalar).
	SaveFile.fault = SaveFile.Fault.TEMP_OPEN
	entry.pressed.emit()
	await _settle(2)
	_c("giriş → GÖREVLER penceresi (Main'in, Ana Sayfa'da kalınır)", _main._missions.visible and _main._active_tab == 0
		and home.visible)
	_main._missions.close_missions(false)
	await _wait_settled()
	_c("açmak / kapatmak kayda yazmadı (bayt-aynı, yazma girişimi yok)", _bytes() == bytes
		and SaveFile.fault == SaveFile.Fault.TEMP_OPEN)
	SaveFile.fault = SaveFile.Fault.NONE
	_sections_done += 1


# --- 2) Pencere içeriği ------------------------------------------------------------------------

func _overlay_content() -> void:
	print("-- GÖREVLER penceresi içeriği")
	var overlay: MissionsOverlay = _main._missions
	_set_missions(_raw({"daily_merges": 7, "daily_rounds": 1}, [], {"weekly_merges": 46, "weekly_rounds": 5,
		"weekly_clears": 2}, []))
	await _open()
	var ribbon: PanelContainer = overlay.frame().get_meta(&"ribbon")
	_c("kurdele başlığı 'GÖREVLER'", (ribbon.get_meta(&"title_label") as Label).text == "GÖREVLER")
	var daily_header: Control = overlay.section_header(Missions.PERIOD_DAILY)
	var weekly_header: Control = overlay.section_header(Missions.PERIOD_WEEKLY)
	_c("bölüm başlıkları GÜNLÜK / HAFTALIK + sabit ipuçları 'Yarın yenilenir' / 'Pazartesi yenilenir' (canlı sayaç yok)",
		(daily_header.get_meta(&"title_label") as Label).text == "GÜNLÜK"
		and (daily_header.get_meta(&"hint_label") as Label).text == "Yarın yenilenir"
		and (weekly_header.get_meta(&"title_label") as Label).text == "HAFTALIK"
		and (weekly_header.get_meta(&"hint_label") as Label).text == "Pazartesi yenilenir")
	var body: VBoxContainer = overlay.frame().get_meta(&"body")
	var order: Array[String] = []
	for child in body.get_children():
		if child == daily_header:
			order.append("GÜNLÜK")
		elif child == weekly_header:
			order.append("HAFTALIK")
		elif child is MissionCard:
			order.append(String((child as MissionCard).mission_id()))
	_c("sıra: GÜNLÜK + 3 günlük kart, HAFTALIK + 3 haftalık kart (tam üçer, katalog sırası)", order == ["GÜNLÜK",
		"daily_merges", "daily_rounds", "daily_clear", "HAFTALIK", "weekly_merges", "weekly_rounds", "weekly_clears"])
	var expect: Dictionary = {
		&"daily_merges": ["15 birleşme yap", "7 / 15", "+10", 7.0 / 15.0],
		&"daily_rounds": ["2 tur tamamla", "1 / 2", "+10", 0.5],
		&"daily_clear": ["1 level tamamla", "0 / 1", "+10", 0.0],
		&"weekly_merges": ["120 birleşme yap", "46 / 120", "+40", 46.0 / 120.0],
		&"weekly_rounds": ["12 tur tamamla", "5 / 12", "+40", 5.0 / 12.0],
		&"weekly_clears": ["5 level tamamla", "2 / 5", "+40", 0.4],
	}
	var cards_ok: bool = true
	for id: StringName in expect:
		var card: MissionCard = overlay.card(id)
		var want: Array = expect[id]
		# Ray değeri ProgressBar'ın varsayılan 0.01 adımına oturur (7/15 → 0.47): yarım adım tolerans.
		if card == null or card.title_text() != want[0] or card.progress_text() != want[1] or card.reward_text() != want[2] \
				or absf(card.rail().value - float(want[3])) > card.rail().step * 0.5 + 0.0001 or card.is_done_shown():
			cards_ok = false
			print("    kart %s: '%s' '%s' '%s' %.3f %s" % [id, card.title_text(), card.progress_text(), card.reward_text(),
				card.rail().value, str(card.is_done_shown())])
	_c("her kart: metin, 'x / y', ilerleme rayı, Hamur ödülü (+10 / +40); kısmi durumda TAMAMLANDI yok", cards_ok)
	_c("üst sayaç '0 / 6' + otomatik ödül notu (talep yok)", overlay.count_text() == "0 / 6"
		and overlay.note_text() == "Ödüller görev tamamlanınca otomatik eklenir.")
	var buttons: Array[BaseButton] = []
	for node in _all_nodes(overlay.frame()):
		if node is BaseButton and (node as BaseButton).is_visible_in_tree():
			buttons.append(node)
	_c("talep butonu YOK: pencerede tek buton kapat (X)", buttons.size() == 1 and buttons[0] == overlay.close_button())
	var words: Array[String] = []
	for node in _all_nodes(overlay.frame()):
		if node is Label and (node as Label).is_visible_in_tree():
			words.append((node as Label).text)
	var joined: String = " ".join(words)
	_c("oyuncu dili: 'AL' / 'TOPLA' / 'CLAIM' / geliştirici metni yok", not joined.contains("TOPLA") and not joined.contains("CLAIM")
		and not words.has("AL") and not joined.contains("daily_") and not joined.contains("weekly_") and not joined.contains("TODO"))
	overlay.close_missions(false)
	await _wait_settled()

	var one: Dictionary = _raw({"daily_merges": 9, "daily_rounds": 1, "daily_clear": 1}, ["daily_clear"], {"weekly_merges": 52}, [])
	_set_missions(one)
	await _open()
	var clear_card: MissionCard = overlay.card(&"daily_clear")
	_c("bir görev tamam: '1 / 6', yalnız o kartta TAMAMLANDI + dolu ray + '1 / 1'", overlay.count_text() == "1 / 6"
		and clear_card.is_done_shown() and is_equal_approx(clear_card.rail().value, 1.0)
		and clear_card.progress_text() == "1 / 1" and _done_count(overlay) == 1)
	var open_card: MissionCard = overlay.card(&"daily_merges")
	_c("çip metni 'TAMAMLANDI' (yalnız tamamlanan kartta)", clear_card.done_text() == "TAMAMLANDI"
		and open_card.done_text() == "")
	_c("durum halkası görünür: kök Control'ün tam dikdörtgeni, gövde her yandan 3 px içeride ve üstte; tamamlananda nane, açıkta lavanta",
		_ring_ok(clear_card, UiTokens.MINT) and _ring_ok(open_card, MissionCard.RING_OPEN))
	overlay.close_missions(false)
	await _wait_settled()
	_set_missions(_raw({}, ["daily_merges", "daily_rounds", "daily_clear"], {"weekly_merges": 88}, []))
	await _open()
	_c("günlükler tamam: '3 / 6', üç günlük kart TAMAMLANDI (15 / 15 · 2 / 2 · 1 / 1), haftalıklar devam",
		overlay.count_text() == "3 / 6" and _done_count(overlay) == 3 and overlay.card(&"daily_merges").progress_text() == "15 / 15"
		and overlay.card(&"daily_rounds").progress_text() == "2 / 2" and not overlay.card(&"weekly_merges").is_done_shown())
	overlay.close_missions(false)
	await _wait_settled()
	_set_missions(_all_done())
	await _open()
	_c("altısı tamam: '6 / 6' altın + 'Hepsi tamam!', altı kart TAMAMLANDI", overlay.count_text() == "6 / 6"
		and overlay.note_text() == "Hepsi tamam!" and _done_count(overlay) == 6)
	overlay.close_missions(false)
	await _wait_settled()
	_set_missions(_raw({}, [], {}, []))
	await _open()
	_c("0 ilerleme: '0 / 6', bütün raylar boş, TAMAMLANDI yok", overlay.count_text() == "0 / 6" and _done_count(overlay) == 0
		and _rails_all(overlay, 0.0))
	overlay.close_missions(false)
	await _wait_settled()
	_sections_done += 1


# --- 3) Girdi sözleşmesi -----------------------------------------------------------------------

func _input_contract() -> void:
	print("-- girdi: geri / X / karartma / hızlı çift dokunuş / yeniden açılış")
	var overlay: MissionsOverlay = _main._missions
	var home: CanvasLayer = _home()
	await _show_home()
	await _wait_settled()
	await _open()
	_main._last_back_msec = -1000
	_main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(2)
	_c("Android geri: pencere kapandı, Ana Sayfa'da kalındı (uygulama kapanmadı)", not overlay.visible
		and _main._active_tab == 0 and home.visible and not get_tree().paused)
	await _wait_settled()
	await _open()
	overlay.close_button().pressed.emit()
	await _settle(2)
	_c("X: pencere kapandı", not overlay.visible and _main._active_tab == 0)
	await _wait_settled()

	# Girişe gerçek parmak dokunuşu → açılır; hemen ardından KARARTMAYA (kapatacak nokta) düşen
	# ikinci dokunuş yutulmalı.
	var entry_pos: Vector2 = _screen_center(home.missions_button())
	await _finger_tap(entry_pos)
	_c("parmak: GÖREVLER girişi → pencere açık", overlay.visible)
	var dim_pos: Vector2 = _dim_point(overlay.frame())
	await _finger_tap(dim_pos)
	_c("açılışın hemen ardından karartmaya dokunuş yutuldu: pencere açık (sızma yok)", overlay.visible)
	await _wait_settled()
	await _finger_tap(dim_pos)
	_c("yatışmadan sonra ilk karartma dokunuşu kapatır (UiKit sözleşmesi)", not overlay.visible)
	await _finger_tap(entry_pos)
	_c("kapanışın hemen ardından girişe dokunuş yutuldu: yeniden açılmadı", not overlay.visible)
	await _wait_settled()
	await _finger_tap(entry_pos)
	_c("yatışmadan sonra giriş yine açar", overlay.visible)
	await _wait_settled()
	# X → hemen ardından Ana Sayfa'da eylem yapan bir kontrole (TASK/058: Hamur '+' kaldırıldı — kabuğun MAĞAZA öğesi)
	# dokunuş.
	var close_pos: Vector2 = _screen_center(overlay.close_button())
	await _finger_tap(close_pos)
	_c("parmak: X → kapandı", not overlay.visible)
	var add: Button = _main.global_nav().item_button(3)
	await _finger_tap(_screen_center(add))
	_c("X'in hemen ardından kabuk MAĞAZA dokunuşu yutuldu: Mağaza açılmadı", _main._active_tab == 0 and home.visible)
	await _wait_settled()
	await _finger_tap(_screen_center(add))
	_c("yatışmadan sonra kabuk MAĞAZA Mağaza'yı açar (kontrol gerçekten eylemli)", _main._active_tab == 3)
	_main._show_tab(0)
	await _wait_settled()
	# Kod yolu yatışmadan etkilenmez.
	_main.open_missions()
	overlay.close_button().pressed.emit()
	home.missions_button().pressed.emit()
	_c("kod yolu: kapanışın hemen ardından pressed.emit() → yeniden açıldı", overlay.visible)
	overlay.close_missions(false)
	await _wait_settled()
	# Yeniden açılış: güncel durum + baştan kaydırma.
	_set_missions(_raw({"daily_merges": 3}, [], {}, []))
	await _open()
	overlay.scroll().scroll_vertical = 400
	overlay.close_missions(false)
	_set_missions(_raw({"daily_merges": 11}, ["daily_clear"], {}, []))
	await _wait_settled()
	await _open()
	_c("yeniden açılış: güncel durum (11 / 15, 1 / 6) ve kaydırma başta", overlay.card(&"daily_merges").progress_text() == "11 / 15"
		and overlay.count_text() == "1 / 6" and overlay.scroll().scroll_vertical == 0)
	overlay.close_missions(false)
	await _wait_settled()
	# Tutorial koçluğu sırasında açılmaz (Main kapısı).
	_c("round sırasında / Ana Sayfa dışında açılmaz", await _refused_elsewhere())
	_sections_done += 1


func _refused_elsewhere() -> bool:
	_main._show_tab(4)
	await _settle(2)
	_main.open_missions()
	var on_profile: bool = not _main._missions.visible
	_main._show_tab(0)
	await _settle(2)
	_main._start_level(_level(2))
	await _settle(2)
	_main.open_missions()
	var in_round: bool = not _main._missions.visible
	_main.abandon_run()
	await _settle(2)
	_main._show_tab(0)
	await _wait_settled()
	return on_profile and in_round


# --- 3b) Kapılar + kendiliğinden kapanış ---------------------------------------------------------

func _gates_and_auto_close() -> void:
	print("-- kapılar: başka pencere açıkken açılmaz; ekran / round / pencere kapanışında kapanır")
	var overlay: MissionsOverlay = _main._missions
	await _show_home()
	await _wait_settled()
	var opened: Array[String] = []
	var refused: Array[String] = []
	_main._on_chest_requested()
	await _settle(2)
	if _main._chest_info.visible:
		opened.append("sandık")
	_open_over("sandık", refused)
	_main._chest_info.close_info()
	await _wait_settled()
	_main.open_settings()
	await _settle(2)
	if _main._settings.visible:
		opened.append("ayarlar")
	_open_over("ayarlar", refused)
	_main.close_settings()
	await _wait_settled()
	_main.open_daily_rewards()
	await _settle(2)
	if _main._daily_rewards.visible:
		opened.append("günlük")
	_open_over("günlük", refused)
	_main._daily_rewards.close_popup()
	await _wait_settled()
	# Yaş ekranı: yalnız görünürlük (kapı bunu okur; yaş akışı çalıştırılmaz). TASK/046.1: 13 altı
	# kısıt ekranı emekli.
	_main._age_panel.visible = true
	_open_over("yaş ekranı", refused)
	_main._age_panel.visible = false
	await _wait_settled()
	_c("ön koşul: sandık / ayarlar / günlük pencereleri gerçekten açıldı %s" % str(opened), opened.size() == 3)
	_c("sandık / ayarlar / günlük / yaş ekranı açıkken GÖREVLER açılmaz %s" % str(refused), refused.is_empty())
	# Ters yön: GÖREVLER açıkken aynı katmandaki pencereler kod yolundan da altına açılmaz.
	await _open()
	_main._on_chest_requested()
	_main.open_daily_rewards()
	await _settle(2)
	_c("GÖREVLER açıkken sandık bilgisi / günlük pencere açılmaz (aynı katman 12)", overlay.visible
		and not _main._chest_info.visible and not _main._daily_rewards.visible)
	# Kendiliğinden kapanış: başka ekrana geçiş, ikincil pencereleri kapatma, round başlangıcı.
	_main._show_tab(3)
	await _settle(2)
	var on_tab: bool = not overlay.visible and _main._active_tab == 3
	_main._show_tab(0)
	await _wait_settled()
	await _open()
	_main._close_secondary_windows()
	await _settle(2)
	var on_close_all: bool = not overlay.visible
	await _wait_settled()
	await _open()
	_main._start_level(_level(2))
	await _settle(2)
	var on_round: bool = not overlay.visible and _main._board != null
	_main.abandon_run()
	await _settle(2)
	_main._show_tab(0)
	await _wait_settled()
	_c("Mağaza'ya geçiş / ikincil pencereleri kapatma / round başlangıcı GÖREVLER'i kapatır (tab %s · pencereler %s · round %s)"
		% [str(on_tab), str(on_close_all), str(on_round)], on_tab and on_close_all and on_round)
	_sections_done += 1


## Başka bir ekran / pencere açıkken GÖREVLER'i kod yolundan açmayı dener; açılırsa kaydeder ve kapatır.
func _open_over(what: String, refused: Array[String]) -> void:
	_main.open_missions()
	if _main._missions.visible:
		refused.append(what)
		_main._missions.close_missions(false)


# --- 4) Yerleşim --------------------------------------------------------------------------------

func _layout_all() -> void:
	print("-- yerleşim: 320 / 360 / 390 dp + 1080×2340 + A36 üst payı")
	_set_missions(_raw({"daily_merges": 15, "daily_rounds": 2, "daily_clear": 1}, ["daily_merges", "daily_rounds", "daily_clear"],
		{"weekly_merges": 120, "weekly_rounds": 5}, ["weekly_merges"]))
	for view in VIEWS:
		await _resize(view)
		await _layout_view(view, -1.0)
	await _resize(VIEWS[4])
	await _layout_view(VIEWS[4], A36_SAFE_TOP)
	await _resize(Vector2i(720, 1280))
	_home()._layout_with_safe_top(-1.0)
	_main._missions.layout_with_safe_top(-1.0)
	await _show_home()
	_sections_done += 1


func _layout_view(view_size: Vector2i, safe_top: float) -> void:
	var home: CanvasLayer = _home()
	var view: Vector2 = get_viewport().get_visible_rect().size
	var tag: String = "%dx%d (tuval %dx%d)%s" % [view_size.x, view_size.y, roundi(view.x), roundi(view.y),
		" +A36" if safe_top > 0.0 else ""]
	var top: float = maxf(safe_top, 0.0)
	home._layout_with_safe_top(safe_top)
	_main._missions.layout_with_safe_top(safe_top)
	await _show_home()
	var entry: Button = home.missions_button()
	var rect: Rect2 = entry.get_global_rect()
	var screen := Rect2(Vector2(0, top), Vector2(view.x, view.y - top))
	_c("%s giriş ekranda, üst payın altında, ≥ 84 dokunma (TASK/058: hero'nun sol üst köşesi)" % tag,
		screen.encloses((entry as HomeFeatureButton).visual_rect()) and rect.size.x >= 84.0 and rect.size.y >= 84.0
		and rect.get_center().x < view.x * 0.5)
	var overlap: Array[String] = []
	for node in _all_nodes(home):
		if node == entry or not (node is BaseButton) or not (node as BaseButton).is_visible_in_tree():
			continue
		if entry.is_ancestor_of(node) or node.is_ancestor_of(entry):
			continue
		var other: Rect2 = (node as HomeFeatureButton).visual_rect() if node is HomeFeatureButton else (node as Control).get_global_rect()
		var inter: Rect2 = rect.intersection(other)
		if inter.size.x > 1.0 and inter.size.y > 1.0:
			overlap.append(String(node.name))
	_c("%s giriş hiçbir Ana Sayfa kontrolüyle çakışmıyor (SANDIK + plakası, kartlar, OYNA) %s" % [tag, str(overlap)],
		overlap.is_empty())
	var logo: Rect2 = home.logo().get_global_rect()
	var mascot: Rect2 = home.mascot_rect()
	_c("%s giriş logonun altında, maskotun opak piksellerine değmiyor" % tag, rect.position.y >= logo.end.y
		and not _mascot_hits(mascot, rect))
	var chest: Rect2 = home.chest_button().get_global_rect()
	_c("%s giriş SANDIK ile aynı madalyon satırında, karşı köşede (TASK/058)" % tag, rect.end.x < chest.position.x
		and absf(rect.get_center().y - chest.get_center().y) <= 4.0)
	_c("%s OYNA / level bilgisi / banner bölgesi serbest (giriş üst yarıda)" % tag,
		(entry as HomeFeatureButton).visual_rect().end.y < home.level_info().get_global_rect().position.y
		and rect.end.y < view.y * 0.5)
	# Madalyonun görsel bütünü: gövde + etiket plakası + köşe rozeti (TASK/058).
	var entry_frame: Rect2 = (entry as HomeFeatureButton).visual_rect().merge(
		(entry as HomeFeatureButton).badge_panel().get_global_rect())
	var entry_clip: Array[String] = []
	for node in _all_nodes(entry):
		if node is Label and (node as Label).is_visible_in_tree():
			var entry_label: Label = node
			if _text_width(entry_label, entry_label.text) > entry_label.size.x + 0.5 \
					or not entry_frame.grow(0.5).encloses(entry_label.get_global_rect()):
				entry_clip.append(entry_label.text)
	_c("%s giriş yazıları ('GÖREVLER', 'N/6') kırpılmıyor, madalyon içinde %s" % [tag, str(entry_clip)], entry_clip.is_empty())
	# Pencere.
	var overlay: MissionsOverlay = _main._missions
	await _open()
	var frame: Rect2 = overlay.frame().get_global_rect()
	var ribbon: Rect2 = (overlay.frame().get_meta(&"ribbon") as Control).get_global_rect()
	var close: Rect2 = overlay.close_button().get_global_rect()
	_c("%s pencere ekranda: kurdele / X üst payın altında, gövde ekran içinde" % tag, ribbon.position.y >= top - 0.5
		and close.position.y >= top - 0.5 and frame.position.x >= 0.0 and frame.end.x <= view.x + 0.5
		and frame.end.y <= view.y - UiKit.bottom_inset(view) + 0.5)
	_c("%s X ≥ 48 ve ekranda" % tag, close.size.x >= 48.0 and close.size.y >= 48.0 and Rect2(Vector2.ZERO, view).encloses(close))
	var head_clip: Array[String] = []
	var head_labels: Array[Node] = _all_nodes(overlay.frame().get_meta(&"hero"))
	for period: StringName in [Missions.PERIOD_DAILY, Missions.PERIOD_WEEKLY]:
		head_labels.append_array(_all_nodes(overlay.section_header(period)))
	for node in head_labels:
		if not (node is Label) or not (node as Label).is_visible_in_tree():
			continue
		var head_label: Label = node
		var fits: bool = head_label.get_visible_line_count() >= head_label.get_line_count() \
			if head_label.autowrap_mode != TextServer.AUTOWRAP_OFF \
			else _text_width(head_label, head_label.text) <= head_label.size.x + 0.5
		var label_rect: Rect2 = head_label.get_global_rect()
		if not fits or label_rect.position.x < frame.position.x - 0.5 or label_rect.end.x > frame.end.x + 0.5:
			head_clip.append(head_label.text)
	_c("%s üst sayaç / not / bölüm başlıkları + ipuçları kırpılmıyor, pencere içinde %s" % [tag, str(head_clip)],
		head_clip.is_empty())
	var scroll: ScrollContainer = overlay.scroll()
	var host_node: Control = overlay.frame().get_meta(&"body_host")
	var reach: bool = true
	var ring_clipped: Array[String] = []
	for card in overlay.cards():
		scroll.ensure_control_visible(card)
		await _settle(2)
		if not host_node.get_global_rect().grow(1.0).encloses(card.get_global_rect()):
			reach = false
			print("    erişilemedi: ", card.name, " ", card.get_global_rect(), " gövde ", host_node.get_global_rect())
		# Kaydırma alanı içeriği kırpar: halka (kartın tam dikdörtgeni) yatayda alanın içinde kalmalı.
		var ring_rect: Rect2 = card.ring().get_global_rect()
		var scroll_rect: Rect2 = scroll.get_global_rect()
		if ring_rect.position.x < scroll_rect.position.x - 0.5 or ring_rect.end.x > scroll_rect.end.x + 0.5:
			ring_clipped.append(String(card.name))
	var scrolls: bool = bool(overlay.frame().get_meta(&"body_scrolls", false))
	scroll.scroll_vertical = 0
	await _settle(2)
	_c("%s altı kart erişilebilir (%s)" % [tag, "gövde kaydırılır" if scrolls else "hepsi sığar"], reach)
	_c("%s kart halkaları kaydırma alanında kırpılmıyor %s" % [tag, str(ring_clipped)], ring_clipped.is_empty())
	var clipped: Array[String] = []
	for card in overlay.cards():
		var card_rect: Rect2 = card.get_global_rect()
		if card_rect.position.x < frame.position.x - 0.5 or card_rect.end.x > frame.end.x + 0.5:
			clipped.append("%s taşıyor" % card.name)
		for label: Label in [card.title_label()]:
			if _text_width(label, label.text) > label.size.x + 0.5:
				clipped.append("%s başlık kırpıldı" % card.name)
		for node in _all_nodes(card):
			if node is Label and node != card.title_label() and (node as Label).is_visible_in_tree():
				var l: Label = node
				if _text_width(l, l.text) > l.size.x + 0.5:
					clipped.append("%s '%s'" % [card.name, l.text])
				if not card_rect.grow(0.5).encloses(l.get_global_rect()):
					clipped.append("%s '%s' kart dışında" % [card.name, l.text])
	_c("%s kırpma / taşma yok (katalog metinleri, sayaç, ödül, TAMAMLANDI) %s" % [tag, str(clipped)], clipped.is_empty())
	var cards_overlap: bool = false
	var cards: Array[MissionCard] = overlay.cards()
	for i in cards.size():
		for j in range(i + 1, cards.size()):
			var inter: Rect2 = cards[i].get_global_rect().intersection(cards[j].get_global_rect())
			if inter.size.x > 1.0 and inter.size.y > 1.0:
				cards_overlap = true
	_c("%s kartlar üst üste binmiyor" % tag, not cards_overlap)
	overlay.close_missions(false)
	await _wait_settled()


# --- 5) Uzun metin -------------------------------------------------------------------------------

func _long_text() -> void:
	print("-- uzun metin provası")
	var overlay: MissionsOverlay = _main._missions
	_set_missions(_raw({"daily_merges": 7}, ["daily_clear"], {}, []))
	await _open()
	var card: MissionCard = overlay.card(&"daily_clear")
	var width: float = card.size.x
	var reward: Rect2 = card.find_child("Reward", true, false).get_global_rect()
	card.title_label().text = "Çok uzun bir görev metni: birleşme, tur ve level görevlerini aynı gün içinde tamamla"
	await _settle(3)
	var label: Label = card.title_label()
	_c("uzun başlık tek satırda üç noktayla kırpılır: kart genişliği aynı, ödül / TAMAMLANDI yerinde",
		label.clip_text and label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS
		and is_equal_approx(card.size.x, width) and card.find_child("Reward", true, false).get_global_rect().is_equal_approx(reward)
		and card.done_chip().is_visible_in_tree() and card.get_global_rect().encloses(card.done_chip().get_global_rect()))
	overlay.close_missions(false)
	await _wait_settled()
	_sections_done += 1


# --- 6) Dil ------------------------------------------------------------------------------------------

func _locale() -> void:
	print("-- dil / yön")
	var translations: Variant = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	_c("üretim dili tek (Türkçe): projede çeviri kaynağı yok → RTL yerelleştirme uygulanamaz",
		(translations as PackedStringArray).is_empty() and TranslationServer.get_loaded_locales().is_empty())
	var card: MissionCard = _main._missions.card(&"daily_merges")
	_c("görev id'leri iç kimlik, metin ayrı tabloda (id ≠ metin; 'x / y' soldan sağa)",
		String(Missions.CATALOG[0]["id"]) == "daily_merges" and Missions.title(&"daily_merges") == "15 birleşme yap"
		and not card.is_layout_rtl() and card.progress_text().begins_with(str(Missions.progress_of(Missions.current(), &"daily_merges"))))
	_sections_done += 1


# --- 7) Reklam: banner / yüzey ---------------------------------------------------------------------

func _ads_banner() -> void:
	print("-- reklam: pencere banner yüzeyi değil, yuvanın üstüne oturur (sahte arka uç)")
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	await _boot(fake)
	fake.complete_consent_update(true)
	fake.complete_init()
	await _settle(2)
	var ads: MonetizationManager = _main._ads
	if fake.banner_loads > 0:
		fake.complete_banner_load(true)
	await _settle(2)
	_c("ön koşul: Ana Sayfa'da banner, yuva > 0", ads != null and ads.banner_state() == MonetizationManager.BannerState.SHOWN
		and UiKit.banner_slot() > 0.0)
	var calls: int = fake.calls.size()
	var shows: int = fake.banner_shows.size()
	await _show_home()
	await _wait_settled()
	calls = fake.calls.size()
	_home().missions_button().pressed.emit()
	await get_tree().create_timer(UiMotion.MODAL_TIME + 0.2).timeout
	var view: Vector2 = get_viewport().get_visible_rect().size
	var frame: Rect2 = _main._missions.frame().get_global_rect()
	_c("pencere açık: yüzey HOME aynen (yeni yüzey yok), arka uca çağrı yok, banner gösterimi eklenmedi",
		ads.surface() == MonetizationManager.Surface.HOME and fake.calls.size() == calls and fake.banner_shows.size() == shows)
	_c("pencere banner yuvasının ÜSTÜNDE (alt kenar ≤ ekran − yuva)", frame.end.y <= view.y - UiKit.banner_slot() + 0.5)
	_main._missions.close_missions()
	await _settle(2)
	_c("pencere kapandı: arka uca çağrı yok", fake.calls.size() == calls)
	# Sahte yöneticinin yuvası statik: reklamsız Main'den ÖNCE sıfırlanır (sonraki yerleşimler yuvasız).
	UiKit.set_banner_slot(0.0)
	await _boot()
	_sections_done += 1


# --- 8) Kayıt + otomatik günlük pencere kapısı -------------------------------------------------------

func _save_and_daily_gate() -> void:
	print("-- kayıt yazılmaz; açık pencere otomatik günlük pencereyi bastırır; öne dönüşte gün dönümü")
	var overlay: MissionsOverlay = _main._missions
	var home: CanvasLayer = _home()
	SaveManager.save_game()
	var bytes: PackedByteArray = _bytes()
	await _show_home()
	SaveFile.fault = SaveFile.Fault.TEMP_OPEN
	await _open()
	overlay.scroll().scroll_vertical = 300
	await _settle(2)
	overlay.refresh()
	overlay.close_missions()
	await _settle(2)
	_c("aç / kaydır / tazele / kapat: kayıt bayt-aynı, yazma girişimi yok", _bytes() == bytes
		and SaveFile.fault == SaveFile.Fault.TEMP_OPEN)
	SaveFile.fault = SaveFile.Fault.NONE
	var raw: Dictionary = (SaveManager.data.get("daily_rewards", {}) as Dictionary).duplicate()
	raw["popup_seen_day"] = ""
	SaveManager.data["daily_rewards"] = raw
	DailyRewards.auto_popup_enabled = true
	_c("ön koşul: otomatik günlük pencere bugün due", DailyRewards.popup_due())
	await _wait_settled()
	# Bugün (Salı): günlükler tamam + haftalık birleşme 52.
	_set_missions(_raw({}, ["daily_merges", "daily_rounds", "daily_clear"], {"weekly_merges": 52}, []))
	await _open()
	_c("ön koşul: pencere ve Ana Sayfa rozeti bugünü gösteriyor (3 / 6 · 3/6)", overlay.count_text() == "3 / 6"
		and home.missions_count_text() == "3/6")
	_main._maybe_auto_open_daily_rewards()
	await _settle(1)
	_c("GÖREVLER açıkken otomatik günlük pencere açılmadı (hâlâ due)", not _main._daily_rewards.visible
		and overlay.visible and DailyRewards.popup_due())
	# Uygulama arkadayken gün döndü (aynı hafta, Çarşamba): öne dönüş günlükleri sıfırlar, haftalık kalır.
	DailyRewards.clock_override = NEXT_DAY
	_main._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _settle(1)
	var daily_card: MissionCard = overlay.card(&"daily_merges")
	_c("öne dönüş + gün dönümü: pencere yerinde tazelendi (0 / 6 · günlük 0 / 15 · haftalık 52 / 120 korunur)",
		overlay.visible and overlay.count_text() == "0 / 6" and daily_card.progress_text() == "0 / 15"
		and not daily_card.is_done_shown() and overlay.card(&"weekly_merges").progress_text() == "52 / 120")
	_c("  … Ana Sayfa rozeti de yeni dönemde (0/6; eski 3/6 kalmadı)", home.missions_count_text() == "0/6")
	_c("  … günlük pencere yine bastırıldı (yeni gün için due)", not _main._daily_rewards.visible
		and DailyRewards.popup_due())
	overlay.close_missions(false)
	_main._maybe_auto_open_daily_rewards()
	await _settle(1)
	_c("pencere kapanınca aynı çağrı günlük pencereyi açar (kapı yalnız pencere varken)", _main._daily_rewards.visible)
	_main._daily_rewards.close_popup()
	DailyRewards.auto_popup_enabled = false
	await _wait_settled()
	_sections_done += 1


# --- Yardımcılar ----------------------------------------------------------------------------------

func _write_fixture() -> void:
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 2},
		"endless_high_score": 0, "dough": 335, "total_merges": 40, "merges_since_bonus_chest": 10,
		"unlocked_skins": ["common_01", "rare_02"], "profile_showcase": ["rare_02"],
		"powerups": {"bomb": 2, "upgrade": 1, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "", "daily_streak": 3,
		"last_login_date": Time.get_date_string_from_system(), "age_ad_band": "ADULT", "next_age_transition_date": "",
		"player_meta_version": 1, "player_xp": 400, "total_rounds_played": 12, "highest_tier_created": 5}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(content, "\t"))
	file.close()


func _raw(daily: Dictionary, daily_rewarded: Array, weekly: Dictionary, weekly_rewarded: Array) -> Dictionary:
	return Missions.sanitize({"version": 1, "day_key": DAY, "week_start_day_key": Missions.week_start(DAY),
		"daily_progress": daily, "daily_rewarded": daily_rewarded, "weekly_progress": weekly,
		"weekly_rewarded": weekly_rewarded})


func _all_done() -> Dictionary:
	return _raw({}, ["daily_merges", "daily_rounds", "daily_clear"], {}, ["weekly_merges", "weekly_rounds", "weekly_clears"])


func _set_missions(state: Dictionary) -> void:
	SaveManager.data["missions"] = state


func _home() -> CanvasLayer:
	return _main._screens[0]


func _show_home() -> void:
	_main._show_tab(1)
	await _settle(1)
	_main._show_tab(0)
	await _settle(2)


func _open() -> void:
	_main.open_missions()
	await get_tree().create_timer(UiMotion.MODAL_TIME + 0.12).timeout
	await _settle(1)


## Halka gövdenin çocuğu değil (PanelContainer onu içerik payına oturtup gövdenin altında
## saklardı), kartın dışına da taşmıyor (kaydırma alanı kırpardı); gövdeden önce çizilir.
func _ring_ok(card: MissionCard, color: Color) -> bool:
	var ring: Control = card.ring()
	var body: Control = card.body()
	var rect: Rect2 = card.get_global_rect()
	return (ring.get_parent() == card and not card.is_class("Container") and ring.is_visible_in_tree()
		and ring.get_index() < body.get_index() and ring.get_global_rect().is_equal_approx(rect)
		and body.get_global_rect().is_equal_approx(rect.grow(-MissionCard.RING_WIDTH))
		and ring.self_modulate.is_equal_approx(color))


func _done_count(overlay: MissionsOverlay) -> int:
	var n: int = 0
	for card in overlay.cards():
		if card.is_done_shown():
			n += 1
	return n


func _rails_all(overlay: MissionsOverlay, value: float) -> bool:
	for card in overlay.cards():
		if not is_equal_approx(card.rail().value, value):
			return false
	return true


func _entry_title(entry: Button) -> String:
	for node in _all_nodes(entry):
		if node is Label and node.name == "Title":
			return (node as Label).text
	return ""


func _boot(fake: FakeAdBackend = null) -> void:
	await _teardown_main()
	_main_script.set("ads_backend_override", fake)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _settle(3)
	_main_script.set("ads_backend_override", null)


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _settle(2)


func _level(number: int) -> LevelData:
	for level in LevelLibrary.load_levels():
		if level.level_number == number:
			return level
	return null


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


## Main'in geçiş sonrası parmak yatışması geçene kadar GERÇEK süre bekler.
func _wait_settled() -> void:
	var settle_msec: int = int(_main_script.get_script_constant_map().get("TOUCH_SETTLE_MSEC", 300))
	await get_tree().create_timer(float(settle_msec) / 1000.0 + 0.12).timeout
	await get_tree().process_frame


func _screen_center(control: Control) -> Vector2:
	return get_viewport().get_screen_transform() * control.get_global_rect().get_center()


## Gerçek parmak dokunuşu: ScreenTouch (device 0) bas → bir kare → bırak.
func _finger_tap(pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = pos
		touch.pressed = pressed
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		await get_tree().process_frame


## Pencerenin altında / üstünde karartmaya düşen bir nokta (pencere piksel). Açılış tween'i
## ölçeği merkez etrafında değiştirir: SON dikdörtgen merkez + ölçeksiz boyuttan.
func _dim_point(frame: Control) -> Vector2:
	var center: Vector2 = frame.get_global_rect().get_center()
	var final_rect := Rect2(center - frame.size * 0.5, frame.size)
	var view_h: float = get_viewport().get_visible_rect().size.y
	var below: float = view_h - final_rect.end.y
	var above: float = final_rect.position.y - UiKit.MODAL_RIBBON_OVERHANG
	var point := Vector2(center.x, final_rect.end.y + below * 0.5) if below >= above \
		else Vector2(center.x, above * 0.5)
	return get_viewport().get_screen_transform() * point


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


func _resize(view: Vector2i) -> void:
	get_window().size = view
	await _settle(2)


func _text_width(label: Label, text: String) -> float:
	return label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		label.get_theme_font_size("font_size")).x


func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	for child in root.get_children():
		out.append_array(_all_nodes(child))
	return out


func _count_named(root: Node, node_name: String) -> int:
	var n: int = 0
	for node in _all_nodes(root):
		if node.name == node_name:
			n += 1
	return n


func _count_class(root: Node, klass: String) -> int:
	var n: int = 0
	for node in _all_nodes(root):
		if node.get_class() == klass or (node.get_script() != null and (node.get_script() as Script).get_global_name() == klass):
			n += 1
	return n


func _bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(PATH) if FileAccess.file_exists(PATH) else PackedByteArray()


func _clean() -> void:
	for path in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for path in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out
