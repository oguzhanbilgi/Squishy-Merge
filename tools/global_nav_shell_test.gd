extends Node
## TASK/057 — küresel gezinme kabuğu (GlobalNav) odak testi. Gerçek Main, gerçek ekranlar, gerçek parmak olayları
## (`Input.parse_input_event`, Android'deki gibi öykünülen fare). Headless.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_global_nav/` altındaki bir yola yönlendirilir, sonda
## geri alınır; gerçek kayıt ailesi (kanonik + .tmp + .bak) başta / sonda bayt bayt karşılaştırılır.
##   godot --headless --audio-driver Dummy --path . res://tools/global_nav_shell_test.tscn
##
## Bölümler:
##   A kurulum        tek kabuk, katman 6, beş GERÇEK hedef (Main ekran indeksleri), sıra, merkez Harita, GestureGuard
##                    sahipliği, dokunma hedefi ≥ TOUCH_TARGET, etiketler sığar, üst satırla çakışmaz
##   B seçili durum   her hub sekmesinde kabuk görünür, tam bir öğe seçili ve o sekmedir; tepsi sekmeler arasında zıplamaz
##   C gezinme        her hedefe taze dokunuş tam BİR gezinme (sayaç + görünen ekran + seçili öğe); tek ekran görünür
##   D yineleme       aynı sekmeye dokunuş 0 gezinme / ikinci giriş yok; hızlı çift dokunuş tek gezinme; yatışma penceresinde
##                    ikinci hedef yutulur, sonra çalışır; hızlı kod tetiklemesi rota yığmaz
##   E iptal          ACTION_CANCEL · basılı + GERİ · basılı + pencere açılışı · basılı + odak kaybı → 0 gezinme; basış biter;
##                    sonraki taze dokunuş tam bir kez
##   F işaretçisiz    kodla `pressed` (erişilebilirlik) görünür kabukta tam bir kez; gizli kabukta 0
##   G GERİ           Mağaza / Harita / Koleksiyon / Profil'den GERİ → Ana Sayfa (seçili Ana Sayfa); detay açıkken GERİ
##                    detayı kapatır, kabuk geri gelir; Ana Sayfa'da GERİ = çıkış isteği (değişmedi)
##   H görünürlük     oyun / mola / sonuç / devam / refill / Ayarlar / günlük / sandık / GÖREVLER / MEYDAN OKUMA / yaş /
##                    Mağaza onayı / Koleksiyon detayı / Profil başarımlar + unvan / tutorial → kabuk GİZLİ; kapanınca geri
##   I paylar         720×1280 · 720×1600 · 16:9 + banner 112 · A36 benzeri (üst 61 + banner 112): görünüm boyu, tepsi
##                    banner aralığıyla yuvanın üstünde, Ana Sayfa OYNA, Harita düğümleri + Sonsuz kalesi, kaydırılan
##                    ekranların alt payı (doğrudan) ve son içerik; geç gelen banner yuvası (onay sonrası) kabuğu ve payları
##                    yeniden kurar
##   K dokunuş        tepsi üstündeki şerit içeriğe kalır (yan öğe yalnız seçili karo payı, merkez yalnız daire); dock
##                    tepsinin altını / yanını tutar; kabuk görünürken Harita düğümü, Mağaza son satır SATIN AL ve
##                    Koleksiyon son kart GERÇEK dokunuşla çalışır (0 gezinme); Harita'dan kabuk ANA SAYFA → Ana Sayfa
##   L Tur 2          (owner incelemesi, TASK/057 Tur 2) hub üst satırlarında GERİ OKU YOK (GERİ zinciri G'de aynen);
##                    seçili durum TEK aile (her öğe aynı malzeme / parıltı; merkez yalnız +1 premium halka); kısıtlı
##                    16:9 + banner yerleşimi: kabuk KOMPAKT (merkez taşması 0), her öğe ≥ TOUCH_TARGET, yuva kabukla
##                    çakışmaz, aralık kaidesi dokunuş almaz, Harita sıkıştırması ≤ %8 (ilk aday ~%18 reddedildi), düğümler
##                    güvenli ve kabuğun üstünde, Sonsuz kalesi üst satırın pill'iyle çakışmaz
##   J kayıt          sahibin kayıt ailesi bayt-aynı

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_global_nav"
const PATH: String = DIR + "/save.json"
const SECTIONS: int = 11
const MON: String = "2026-09-28"
const THU: String = "2026-10-01"
const BACK_GAP_MSEC: int = 320
const LEVEL_PATH: String = "res://resources/levels/level_04.tres"
const SHOWCASE_ID: StringName = &"rare_02"
const TABS: Array[int] = [0, 1, 2, 3, 4]
const A36_SAFE_TOP: float = 61.0
const A36_SLOT: float = 112.0

var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _finished: bool = false
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _main: Node2D
var _last_back_msec: int = -100000


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_owner_state = _owner_snapshot()
	_saved_data = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	SaveManager.save_path = PATH
	get_tree().create_timer(400.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 400 s'de bitmedi — SaveManager geri alındı")
			if _main != null and is_instance_valid(_main):
				_main.free()
			_teardown()
			get_tree().quit(2))
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame

	await _setup_contract()
	await _selected_state()
	await _navigation()
	await _repeat()
	await _cancel()
	await _non_pointer()
	await _back_chain()
	await _visibility()
	await _insets()
	await _touch_reach()
	await _round2()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	print("-- J: kayıt")
	await _teardown_main()
	_teardown()
	_c("SaveManager gerçek yola döndü, test klasörü silindi, saat kancası boş, banner yuvası 0",
		SaveManager.save_path == SaveManager.SAVE_PATH and not DirAccess.dir_exists_absolute(DIR)
		and DailyRewards.clock_override == "" and is_zero_approx(UiKit.banner_slot()))
	_c("sahibin gerçek kayıt ailesi (kanonik + .tmp + .bak) bayt-aynı", _owner_snapshot() == _owner_state)
	_finished = true
	print("\nSONUC: %d kontrol, %d hata" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _exit_tree() -> void:
	if not _finished:
		_teardown()


# --- A: kurulum ------------------------------------------------------------------------------------------------------

func _setup_contract() -> void:
	print("-- A: kurulum — tek kabuk, gerçek hedefler, sahiplik, dokunma hedefi")
	await _boot()
	var navs: Array = _find_all(get_tree().root, "GlobalNav")
	var nav: GlobalNav = _nav()
	_c("tek GlobalNav düğümü (ikinci kabuk / yinelenen kurulum yok)", navs.size() == 1 and nav != null)
	_c("katman 6: hub ekranlarının (5) üstünde, tutorial (8) / sonuç (10) / pencerelerin (11-14) altında",
		nav.layer == 6 and nav.layer > (_main._screens[0] as CanvasLayer).layer and nav.layer < 8)
	var order: Array[int] = []
	for item: NavItem in nav.items():
		order.append(item.tab())
	_c("sıra: Ana Sayfa · Mağaza · [Harita] · Koleksiyon · Profil (ekran indeksleri 0 3 1 2 4)", order == [0, 3, 1, 2, 4])
	_c("hedefler Main'in GERÇEK ekranları (her indeks bir `_screens` ekranı; yeni rota yok)",
		order.all(func(t: int) -> bool: return t >= 0 and t < _main._screens.size()))
	_c("merkez öğe Harita ve tek merkez", nav.item_button(1).is_center()
		and nav.items().filter(func(i: NavItem) -> bool: return i.is_center()).size() == 1)
	var labels: Array[String] = []
	for item: NavItem in nav.items():
		labels.append(item.label_text())
	_c("etiketler Türkçe büyük harf: %s" % str(labels), labels == ["ANA SAYFA", "MAĞAZA", "HARİTA", "KOLEKSİYON", "PROFİL"])
	var owned: bool = true
	var targets: bool = true
	var fits: bool = true
	for item: NavItem in nav.items():
		owned = owned and item.has_meta(&"gesture_guard")
		var rect: Rect2 = item.get_global_rect()
		targets = targets and rect.size.x >= UiTokens.TOUCH_TARGET and rect.size.y >= UiTokens.TOUCH_TARGET
		fits = fits and item.label_node().get_minimum_size().x <= rect.size.x - 4.0
	_c("her öğe GestureGuard'a ait (TASK/055 sahipliği)", owned)
	_c("her öğenin dokunma alanı ≥ %d px (A36'da 48 dp)" % UiTokens.TOUCH_TARGET, targets)
	_c("her etiket öğesine sığar (kırpma yok)", fits)
	await _tab(3)
	var bar_bottom: float = (_main._screens[3].top_bar() as ScreenTopBar).height()
	_c("kabuk üst satırla çakışmaz (ayak izi üstü %.0f > üst satır altı %.0f)" % [nav.footprint().position.y, bar_bottom],
		nav.footprint().position.y > bar_bottom + 200.0)
	_c("kabuğun payı = tepsi + merkez taşması + alt boşluk (%.0f px)" % nav.reserve(),
		is_equal_approx(nav.reserve(), GlobalNav.TRAY_HEIGHT + NavItem.CENTER_RISE + GlobalNav.BOTTOM_GAP))
	_c("tepsi boşlukları alttaki içeriğe dokunuş sızdırmaz (STOP)",
		(nav.get_node("Root/Tray") as Control).mouse_filter == Control.MOUSE_FILTER_STOP)
	var band_ok: bool = true
	for item: NavItem in nav.items():
		var t: float = item.tray_top()
		if item.is_center():
			var c := Vector2(item.size.x * 0.5, t - NavItem.CENTER_RISE + NavItem.CENTER_DIAMETER * 0.5)
			band_ok = band_ok and item._has_point(c) and not item._has_point(Vector2(3.0, t - 12.0)) \
				and item._has_point(Vector2(3.0, t + 10.0))
		elif item.is_selected():
			band_ok = band_ok and not item._has_point(Vector2(item.size.x * 0.5, t - 20.0)) \
				and item._has_point(Vector2(item.size.x * 0.5, t - NavItem.TILE_RISE + 2.0)) \
				and item._has_point(Vector2(item.size.x * 0.5, t + 40.0))
		else:
			# Seçili olmayan yan öğe tepsi üstünde hiçbir şey çizmez: dokunma alanı tepsiden başlar.
			band_ok = band_ok and not item._has_point(Vector2(item.size.x * 0.5, t - 7.0)) \
				and item._has_point(Vector2(item.size.x * 0.5, t + 2.0)) \
				and item._has_point(Vector2(item.size.x * 0.5, t + 40.0))
	_c("dokunma alanı: tepsi üstündeki 40 px şeritte seçili yan öğe yalnız karo payı (14 px), seçili olmayan hiç, merkez "
		+ "yalnız daire", band_ok)
	_c("yan öğe dokunma alanı yine ≥ TOUCH_TARGET yükseklik (seçili olmayan = tepsi %.0f px)" % GlobalNav.TRAY_HEIGHT,
		GlobalNav.TRAY_HEIGHT >= UiTokens.TOUCH_TARGET)
	var view_a: Vector2 = nav.get_viewport().get_visible_rect().size
	var dock: Rect2 = nav.dock_block_rect()
	_c("dock: tepsi üst kenarından ekran altına tam genişlik dokunuş tutar (tepsinin altı / yanı içeriğe sızmaz)",
		is_equal_approx(dock.position.y, nav.tray_rect().position.y) and is_equal_approx(dock.end.y, view_a.y)
		and is_equal_approx(dock.size.x, view_a.x)
		and (nav.get_node("Root/DockBlock") as Control).mouse_filter == Control.MOUSE_FILTER_STOP
		and (nav.get_node("Root/Dock") as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_sections_done += 1


# --- B: seçili durum --------------------------------------------------------------------------------------------------

func _selected_state() -> void:
	print("-- B: her hub sekmesinde görünür, tam bir seçili öğe, sabit tepsi")
	var nav: GlobalNav = _nav()
	var tray: Rect2 = Rect2()
	var stable: bool = true
	for tab: int in TABS:
		await _tab(tab)
		var selected: Array = nav.items().filter(func(i: NavItem) -> bool: return i.is_selected())
		_c("sekme %d: kabuk görünür, tam bir öğe seçili ve o sekme" % tab,
			nav.visible and selected.size() == 1 and (selected[0] as NavItem).tab() == tab and nav.current() == tab)
		_c("sekme %d: seçili öğe TEK seçili aile malzemesini uygular, diğerleri hiçbirini (Tur 2)" % tab,
			_family_ok(nav))
		# Son cila: seçili yan öğe hücre boyu krem karo değil — madalyon büyür ve tepsiden yükselir.
		var sel: NavItem = selected[0] if selected.size() == 1 else null
		if sel != null and not sel.is_center():
			var r: Rect2 = sel.highlight_rect()
			_c("sekme %d: seçili yan öğe yükselen madalyon (%.0f px, hücre %.0f px; üstü tepsinin %.0f px üstünde)" % [
				tab, r.size.x, sel.size.x, sel.tray_top() - r.position.y], r.size.x <= NavItem.MEDALLION_SELECTED + 0.5
				and r.size.x < sel.size.x * 0.6 and r.position.y < sel.tray_top())
		if tab == 0:
			tray = nav.tray_rect()
		else:
			stable = stable and nav.tray_rect().is_equal_approx(tray)
	_c("tepsi beş sekmede aynı dikdörtgende (sekme değişiminde zıplamaz)", stable)
	_sections_done += 1


# --- C: gezinme ------------------------------------------------------------------------------------------------------

func _navigation() -> void:
	print("-- C: her hedefe taze dokunuş tam BİR gezinme")
	var nav: GlobalNav = _nav()
	var routes: Array = [[0, 3], [3, 2], [2, 4], [4, 1], [1, 0], [0, 2], [2, 3], [3, 4], [4, 0], [0, 1], [1, 4], [4, 3],
		[3, 1], [1, 2], [2, 0], [0, 4]]
	for route in routes:
		await _tab(int(route[0]))
		var before: int = _main.nav_navigations
		await _tap(nav.item_button(int(route[1])))
		await _wait_settled()
		var target: int = int(route[1])
		_c("%d → %d: sayaç +1, hedef ekran görünür, tek ekran, seçili öğe hedef" % [route[0], target],
			_main.nav_navigations == before + 1 and _main._active_tab == target and _visible_screens() == [target]
			and nav.item_button(target).is_selected() and nav.visible)
	_sections_done += 1


# --- D: yineleme / hızlı dokunuş ---------------------------------------------------------------------------------------

func _repeat() -> void:
	print("-- D: aynı sekme, hızlı çift dokunuş, yatışma, kod yığını")
	var nav: GlobalNav = _nav()
	for tab: int in TABS:
		await _tab(tab)
		var before: int = _main.nav_navigations
		var screen: CanvasLayer = _main._screens[tab]
		var settle_before: int = int(_main.get("_touch_settle_until"))
		await _tap(nav.item_button(tab))
		await _wait_settled()
		_c("sekme %d: aynı öğeye dokunuş 0 gezinme, ekran yerinde, giriş geçişi yeniden oynamaz" % tab,
			_main.nav_navigations == before and _main._active_tab == tab and screen.visible
			and int(_main.get("_touch_settle_until")) == settle_before)
	# Hızlı çift dokunuş (aynı hedef, yatışma penceresi içinde).
	await _tab(0)
	var before2: int = _main.nav_navigations
	await _tap(nav.item_button(3))
	await _tap(nav.item_button(3))
	await _wait_settled()
	_c("hızlı çift dokunuş (Mağaza): tam bir gezinme, tek ekran", _main.nav_navigations == before2 + 1
		and _visible_screens() == [3])
	# Yatışma penceresinde ikinci hedef: TASK/044 300 ms parmak yatışması yutar.
	await _tab(0)
	var before3: int = _main.nav_navigations
	await _tap(nav.item_button(2))
	var second_at: int = Time.get_ticks_msec()
	var window_end: int = int(_main.get("_touch_settle_until"))
	await _tap(nav.item_button(4))
	_c("  … ikinci dokunuş yatışma penceresinin içinde basıldı (ön koşul: %d ms < %d ms)" % [second_at, window_end],
		second_at < window_end)
	_c("yatışma penceresindeki ikinci hedef (Profil) yutulur: tek gezinme, Koleksiyon görünür",
		_main.nav_navigations == before3 + 1 and _visible_screens() == [2])
	await _wait_settled()
	await _tap(nav.item_button(4))
	await _wait_settled()
	_c("yatışmadan sonra ikinci hedef tam bir kez çalışır (Profil)", _main.nav_navigations == before3 + 2
		and _visible_screens() == [4])
	# Kod yolundan hızlı art arda istekler: rota yığılmaz (tek görünen ekran, son hedef).
	var before4: int = _main.nav_navigations
	nav.destination_requested.emit(0)
	nav.destination_requested.emit(0)
	nav.destination_requested.emit(3)
	await _wait_settled()
	_c("art arda kod istekleri (0, 0, 3): 2 gerçek gezinme, tek ekran, son hedef seçili",
		_main.nav_navigations == before4 + 2 and _visible_screens() == [3] and nav.item_button(3).is_selected())
	_sections_done += 1


# --- E: iptal / geçersizleşme ------------------------------------------------------------------------------------------

func _cancel() -> void:
	print("-- E: iptal edilen / geçersizleşen basış 0 gezinme")
	var nav: GlobalNav = _nav()
	await _tab(0)
	var shop_item: NavItem = nav.item_button(3)
	var before: int = _main.nav_navigations
	var pos: Vector2 = _center(shop_item)
	await _finger(pos, true)
	_c("basılıyken öğe basış görselinde (yüz %.0f px çöktü)" % shop_item.face_offset(),
		shop_item.is_pressed_visual() and shop_item.face_offset() > 0.0)
	await _cancel_finger(pos)
	await _finger(pos, false)
	await _wait_settled()
	_c("ACTION_CANCEL: 0 gezinme, Ana Sayfa'da, basış bitti", _main.nav_navigations == before
		and _visible_screens() == [0] and not shop_item.is_pressed_visual())
	# Basılı + GERİ (Mağaza'dayken GERİ Ana Sayfa'ya götürür; basılı Koleksiyon öğesi eylemsiz biter).
	await _tab(3)
	var coll: NavItem = nav.item_button(2)
	before = _main.nav_navigations
	pos = _center(coll)
	await _finger(pos, true)
	_c("  … Koleksiyon öğesi basılı (ön koşul)", coll.is_pressed_visual())
	await _unhandled_key()
	await _back()
	await _finger(pos, false)
	await _wait_settled()
	_c("basılı Koleksiyon + GERİ: GERİ zinciri (Mağaza → Ana Sayfa) çalışır, öğe 0 gezinme",
		_main.nav_navigations == before and _visible_screens() == [0] and nav.item_button(0).is_selected())
	# Basılı + pencere açılışı (günlük ödüller): kabuk gizlenir, bayat bırakış eylemsiz.
	await _tab(0)
	var profile_item: NavItem = nav.item_button(4)
	before = _main.nav_navigations
	pos = _center(profile_item)
	await _finger(pos, true)
	_c("  … Profil öğesi basılı (ön koşul)", profile_item.is_pressed_visual())
	_main.open_daily_rewards()
	await _settle(2)
	_c("pencere açılınca kabuk gizlendi", not nav.visible and _main._daily_rewards.visible)
	await _finger(pos, false)
	await _settle(3)
	_main._daily_rewards.close_popup()
	await _wait_settled()
	_c("basılı Profil + pencere açılışı: 0 gezinme, Ana Sayfa'da, kabuk geri geldi, basış bitti",
		_main.nav_navigations == before and _visible_screens() == [0] and nav.visible and not profile_item.is_pressed_visual())
	# Basılı + pencere odağı kaybı (Android onPause).
	before = _main.nav_navigations
	var map_item: NavItem = nav.item_button(1)
	pos = _center(map_item)
	await _finger(pos, true)
	_c("  … Harita öğesi basılı (ön koşul)", map_item.is_pressed_visual())
	await _unhandled_key()
	_window_notify(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await _settle(2)
	_window_notify(NOTIFICATION_WM_WINDOW_FOCUS_IN)
	await _settle(2)
	await _finger(pos, false)
	await _wait_settled()
	_c("basılı Harita + odak kaybı: 0 gezinme, Ana Sayfa'da", _main.nav_navigations == before and _visible_screens() == [0])
	# Basılı + kabuk gizlenip BIRAKIŞTAN ÖNCE yeniden görünür (pencere açılıp kapandı): bayat bırakış 0.
	var shop_again: NavItem = nav.item_button(3)
	pos = _center(shop_again)
	await _finger(pos, true)
	_c("  … Mağaza öğesi basılı (ön koşul)", shop_again.is_pressed_visual())
	_main.open_daily_rewards()
	await _settle(2)
	_main._daily_rewards.close_popup()
	await _settle(3)
	var shown_again: bool = nav.visible
	await _finger(pos, false)
	await _wait_settled()
	_c("basılı + gizlen + yeniden görün + bırak: 0 gezinme (kabuk bırakıştan önce görünürdü: %s)" % str(shown_again),
		shown_again and _main.nav_navigations == before and _visible_screens() == [0])
	await _tap(map_item)
	await _wait_settled()
	_c("sonraki taze dokunuş tam bir kez (Harita)", _main.nav_navigations == before + 1 and _visible_screens() == [1])
	_sections_done += 1


# --- F: işaretçisiz etkinleştirme --------------------------------------------------------------------------------------

func _non_pointer() -> void:
	print("-- F: kodla pressed (erişilebilirlik yolu)")
	var nav: GlobalNav = _nav()
	await _tab(0)
	var before: int = _main.nav_navigations
	nav.item_button(2).pressed.emit()
	await _wait_settled()
	_c("görünür kabukta kodla pressed: tam bir gezinme (Koleksiyon)", _main.nav_navigations == before + 1
		and _visible_screens() == [2])
	_main._screens[2].open_detail(SHOWCASE_ID)
	await _settle(3)
	before = _main.nav_navigations
	nav.item_button(3).pressed.emit()
	nav.destination_requested.emit(3)
	await _wait_settled()
	_c("gizli kabuk (detay açık): kodla pressed / bayat istek 0 gezinme, detay açık kalır",
		_main.nav_navigations == before and _main._screens[2].has_open_overlay() and _visible_screens() == [2])
	_main._screens[2].close_detail(false)
	await _wait_settled()
	_sections_done += 1


# --- G: Android GERİ ----------------------------------------------------------------------------------------------------

func _back_chain() -> void:
	print("-- G: GERİ zinciri değişmedi")
	var nav: GlobalNav = _nav()
	for tab: int in [3, 1, 2, 4]:
		await _tab(tab)
		await _back()
		await _wait_settled()
		_c("sekme %d → GERİ → Ana Sayfa, seçili Ana Sayfa, kabuk görünür" % tab,
			_visible_screens() == [0] and nav.item_button(0).is_selected() and nav.visible)
	await _tab(2)
	_main._screens[2].open_detail(SHOWCASE_ID)
	await _settle(3)
	_c("Koleksiyon detayı açık: kabuk gizli", not nav.visible)
	await _back()
	await _wait_settled()
	_c("GERİ detayı kapatır, Koleksiyon'da kalınır, kabuk geri gelir", _visible_screens() == [2]
		and not _main._screens[2].has_open_overlay() and nav.visible and nav.item_button(2).is_selected())
	await _tab(0)
	var quits: int = int(_main.get("quit_requests"))
	await _back()
	await _wait_settled()
	_c("Ana Sayfa'da GERİ = çıkış isteği (+1, değişmedi)", int(_main.get("quit_requests")) == quits + 1)
	_sections_done += 1


# --- H: görünürlük matrisi -----------------------------------------------------------------------------------------------

func _visibility() -> void:
	print("-- H: kabuk yalnız hub ekranlarında; engelleyici yüzeylerde gizli")
	var nav: GlobalNav = _nav()
	# Oyun + mola + oyundan çıkış.
	await _tab(1)
	_main._start_level(load(LEVEL_PATH))
	await _settle(3)
	await _wait_settled()
	_c("oyun (board): kabuk gizli", not nav.visible and _main._board != null)
	_main.open_pause_menu()
	await _settle(2)
	_c("mola: kabuk gizli", not nav.visible and _main.is_pause_open())
	_main.resume_game()
	await _settle(2)
	_c("moladan dönüş (oyun sürüyor): kabuk hâlâ gizli", not nav.visible)
	_main.abandon_run()
	await _wait_settled()
	_c("oyundan çıkış → Harita: kabuk görünür, Harita seçili", nav.visible and _visible_screens() == [1]
		and nav.item_button(1).is_selected())
	# Main katmanları (sonuç / devam / refill doğrudan katman görünürlüğüyle — kabuk sözleşmesi katmanı izler).
	for spec in [[_main._result, "sonuç"], [_main._revive, "devam teklifi"], [_main._refill, "refill"]]:
		var layer: CanvasLayer = spec[0]
		layer.visible = true
		await _settle(1)
		var hidden: bool = not nav.visible
		layer.visible = false
		await _settle(1)
		_c("%s katmanı açık: kabuk gizli; kapanınca geri" % spec[1], hidden and nav.visible)
	# Ayarlar (Profil dişlisi yolu).
	await _tab(4)
	_c("Ayarlar açıldı", _main.open_settings())
	await _settle(2)
	_c("Ayarlar: kabuk gizli", not nav.visible)
	_main.close_settings()
	await _wait_settled()
	_c("Ayarlar kapandı: kabuk görünür (Profil seçili)", nav.visible and nav.item_button(4).is_selected())
	# Profil başarımlar / unvan pencereleri.
	_main._screens[4].open_achievements()
	await _settle(2)
	_c("Profil başarımlar penceresi: kabuk gizli", not nav.visible)
	_main._screens[4].handle_back()
	await _wait_settled()
	_c("başarımlar kapandı: kabuk görünür", nav.visible)
	_main._screens[4].open_title_selector()
	await _settle(2)
	_c("Profil unvan seçici: kabuk gizli", not nav.visible)
	_main._screens[4].handle_back()
	await _wait_settled()
	_c("unvan seçici kapandı: kabuk görünür", nav.visible)
	# Ana Sayfa pencereleri.
	await _tab(0)
	for spec in [["open_daily_rewards", "günlük ödüller", "_daily_rewards"], ["open_missions", "GÖREVLER", "_missions"],
			["open_daily_challenge", "MEYDAN OKUMA", "_challenge_sheet"], ["_on_chest_requested", "sandık bilgisi", "_chest_info"]]:
		_main.call(String(spec[0]))
		await _settle(2)
		var layer: CanvasLayer = _main.get(String(spec[2]))
		var hidden: bool = not nav.visible and layer.visible
		await _back()
		await _wait_settled()
		_c("%s: kabuk gizli; GERİ ile kapanınca geri (Ana Sayfa)" % spec[1], hidden and nav.visible
			and not layer.visible and _visible_screens() == [0])
	# Mağaza onayı (ekran içi pencere).
	await _tab(3)
	_main._screens[3]._open_power_confirm(PowerUp.Type.SHAKE)
	await _settle(2)
	_c("Mağaza onayı: kabuk gizli", not nav.visible and _main._screens[3].has_open_overlay())
	await _back()
	await _wait_settled()
	_c("onay GERİ ile kapandı: kabuk görünür, Mağaza'da", nav.visible and _visible_screens() == [3])
	# Yaş ekranı (zorunlu kip).
	await _tab(0)
	_main.age_panel().open_required()
	await _settle(2)
	_c("yaş ekranı: kabuk gizli", not nav.visible)
	_main.age_panel().close_panel()
	await _wait_settled()
	_c("yaş ekranı kapandı: kabuk görünür", nav.visible)
	# Tutorial katmanı TEK BAŞINA (board olmadan) da kabuğu gizler.
	_main._tutorial_overlay.visible = true
	await _settle(1)
	var tut_hidden: bool = not nav.visible
	_main._tutorial_overlay.visible = false
	await _settle(1)
	_c("tutorial katmanı (board yokken): kabuk gizli; kapanınca geri", tut_hidden and nav.visible)
	# İlk açılış tutorial'ı (onboarding bitmemiş kayıt): kabuk hiç görünmez.
	await _boot({"onboarding_completed": false, "highest_level_unlocked": 1, "level_stars": {}})
	_c("ilk açılış tutorial'ı (board + koçluk): kabuk gizli", not _nav().visible and _main._board != null)
	await _boot()
	_c("yeni Main (onboarding bitmiş): Ana Sayfa'da kabuk görünür, Ana Sayfa seçili", _nav().visible
		and _nav().item_button(0).is_selected())
	_sections_done += 1


# --- I: paylar / içerik kabuğun üstünde ----------------------------------------------------------------------------------

func _insets() -> void:
	print("-- I: içerik kabuğun üstünde biter (üç görünüm)")
	for spec in [[Vector2i(720, 1280), 0.0, 0.0, "720×1280"], [Vector2i(720, 1600), 0.0, 0.0, "720×1600 (20:9)"],
			[Vector2i(720, 1280), 0.0, A36_SLOT, "720×1280 + banner 112 (16:9)"],
			[Vector2i(720, 1560), A36_SAFE_TOP, A36_SLOT, "A36 benzeri 720×1560 + üst 61 + banner 112"]]:
		get_window().size = spec[0]
		UiKit.set_banner_slot(float(spec[2]))
		await _boot()
		var got: Vector2 = _nav().get_viewport().get_visible_rect().size
		_c("%s: görünüm gerçekten %s (%s)" % [spec[3], str(Vector2(spec[0])), str(got)], got.is_equal_approx(Vector2(spec[0])))
		var safe_top: float = float(spec[1])
		for screen: CanvasLayer in _main._screens:
			if screen.has_method("_layout_with_safe_top"):
				screen._layout_with_safe_top(safe_top)
		_main._on_banner_slot_changed(float(spec[2]))
		await _check_insets(String(spec[3]), safe_top)
	# Geç gelen yuva (cihazda onay + SDK başlatması SONRA): kabuk ve paylar yeniden kurulur.
	get_window().size = Vector2i(720, 1280)
	UiKit.set_banner_slot(0.0)
	await _boot()
	var nav: GlobalNav = _nav()
	var before_end: float = nav.tray_rect().end.y
	UiKit.set_banner_slot(A36_SLOT)
	_main._on_banner_slot_changed(A36_SLOT)
	await _settle(2)
	_c("geç yuva: tepsi alt kenarı 1280 → 1280 − 112 − 28 = %.0f (önce %.0f)" % [nav.tray_rect().end.y, before_end],
		is_equal_approx(before_end, 1280.0 - GlobalNav.BOTTOM_GAP)
		and is_equal_approx(nav.tray_rect().end.y, 1280.0 - A36_SLOT - GlobalNav.BANNER_GAP))
	_c("geç yuva (16:9 + 112 → kompakt kip, Tur 2): pay %.0f = 28 + 92 + 0; Mağaza alt payı doğrudan 64 + 112 + pay" % nav.reserve(),
		nav.is_compact() and is_zero_approx(nav.center_rise())
		and is_equal_approx(nav.reserve(), GlobalNav.BANNER_GAP + GlobalNav.TRAY_HEIGHT)
		and (_main._screens[3]._margin as MarginContainer).get_theme_constant("margin_bottom")
		== int(_main._screens[3].BOTTOM_PADDING + A36_SLOT + nav.reserve()))
	await _tab(0)
	_c("geç yuva: Ana Sayfa OYNA yeni payın üstünde", (_main._screens[0].play_button() as Control).get_global_rect().end.y
		<= nav.footprint().position.y - 4.0)
	get_window().size = Vector2i(720, 1280)
	UiKit.set_banner_slot(0.0)
	_sections_done += 1


func _check_insets(tag: String, safe_top: float) -> void:
	var nav: GlobalNav = _nav()
	var view: Vector2 = nav.get_viewport().get_visible_rect().size
	var floor_y: float = nav.footprint().position.y
	var gap: float = GlobalNav.BANNER_GAP if UiKit.banner_slot() > 0.0 else GlobalNav.BOTTOM_GAP
	_c("%s: tepsi alt kenarı = ekran − banner/gesture payı − %.0f (yuva varsa dokunulmayan 28 px aralık)" % [tag, gap],
		is_equal_approx(nav.tray_rect().end.y, view.y - UiKit.bottom_inset(view) - gap)
		and is_equal_approx(nav.bottom_gap(), gap))
	# Ana Sayfa.
	await _tab(0)
	var home: CanvasLayer = _main._screens[0]
	var play: Rect2 = home.play_button().get_global_rect()
	# TASK/058: level düğmesi yerine dokunma almayan level bilgisi; OYNA ile kabuk arasında GÜNLÜK / MEYDAN OKUMA kartları.
	var level: Rect2 = home.level_info().get_global_rect()
	_c("%s: Ana Sayfa OYNA (alt %.0f), level bilgisi ve kartlar kabuğun üstünde (%.0f)" % [tag, play.end.y, floor_y],
		play.end.y <= floor_y - 4.0 and level.end.y <= play.position.y
		and home.challenge_card().get_global_rect().end.y <= floor_y + 0.5)
	_c("%s: Ana Sayfa maskotu level pill'ine değmez ve en az %d px (%.0f)" % [tag, int(home.MASCOT_MIN),
		home.mascot_rect().size.y], home.mascot_rect().end.y <= level.position.y + 1.0
		and home.mascot_rect().size.y >= home.MASCOT_MIN - 1.0)
	var sides_clear: bool = true
	for side: Control in home._sides:
		var ok_side: bool = not side.get_global_rect().intersects(level) and not side.get_global_rect().intersects(play)
		if not ok_side:
			print("    yan dumpling %s ∩ level %s / OYNA %s" % [str(side.get_global_rect()), str(level), str(play)])
		sides_clear = sides_clear and ok_side
	_c("%s: Ana Sayfa yan dumpling'leri level pill'inin / OYNA'nın arkasına inmez (Tur 2, A36 bulgusu)" % tag, sides_clear)
	# Harita.
	await _tab(1)
	var map: CanvasLayer = _main._screens[1]
	# TASK/059: Harita kaydırılabilir — düğümler en alt kamera konumunda (en yukarıda oldukları yer) kabuğun üstünde; girişte
	# odak düğümü de kabuğun üstünde. Kabuğun altına kayan düğüm dock'un arkasındadır (dokunuşu dock tutar).
	var focus_scroll: float = map.scroll_offset()
	var focus_bottom: float = _node_bottom(map.focus_node())
	map.set_scroll(map.scroll_limits().y)
	await _settle(1)
	var lowest: float = 0.0
	for node: MapLevelNode in map.nodes():
		lowest = maxf(lowest, _node_bottom(node))
	_c("%s: Harita en alt konumda düğümler + OYNA plakası kabuğun üstünde (en alt %.0f ≤ %.0f); girişte odak %.0f" % [tag,
		lowest, floor_y, focus_bottom], lowest <= floor_y and focus_bottom <= floor_y)
	map.set_scroll(0.0)
	await _settle(1)
	var endless: MapLevelNode = map.endless_node()
	var bar: ScreenTopBar = map.top_bar()
	_c("%s: TASK/059 text-light kurdele gizli; en üstte Sonsuz kalesi üst satırın altında (%.0f ≥ %.0f), Hamur pill'iyle çakışmaz"
		% [tag, endless.get_global_rect().position.y, bar.height()], not bar.is_title_visible()
		and endless.get_global_rect().position.y >= bar.height() - 0.5
		and not endless.get_global_rect().intersects(bar.pill().get_global_rect()))
	map.set_scroll(focus_scroll)
	_c("%s: Harita zemini tepsinin üst kenarına kadar (normal kipte merkez daire dünyaya biner)" % tag,
		absf(map.world_rect().end.y - nav.tray_rect().position.y) <= 1.0)
	var squash: float = map.world_scale().y / map.world_scale().x
	# TASK/059: dikey sıkıştırma YOK (eski Tur 2 tabanı 0.92 / ilk aday 0.819 tarihsel) — dünya tek tip ölçekli kayar.
	var art_ratio: float = map.map_art().size.y / map.map_art().size.x
	_c("%s: Harita dikey sıkıştırma yok (zemin oranı %.4f = 1280/720; TASK/059 kaydırılabilir yolculuk)" % [tag, art_ratio],
		is_equal_approx(squash, 1.0) and absf(art_ratio - 1280.0 / 720.0) < 0.001)
	var focus: MapLevelNode = map.focus_node()
	if focus != null:
		print("    %s: Harita odak düğümü çapı %.1f px, sy/sx %.3f, kurdele %s, kabuk %s" % [tag, focus.diameter(), squash,
			"bıraktı" if map.title_yielded() else "görünür", "kompakt" if nav.is_compact() else "normal"])
	# Kaydırılan ekranlar: son içerik kabuğun üstünde, sona kaydırılabilir.
	for spec in [[3, "Mağaza"], [2, "Koleksiyon"], [4, "Profil"]]:
		await _tab(int(spec[0]))
		var screen: CanvasLayer = _main._screens[int(spec[0])]
		var scroll: ScrollContainer = screen.scroll()
		var margin: int = (screen._margin as MarginContainer).get_theme_constant("margin_bottom")
		_c("%s: %s alt payı doğrudan = %d + yuva/gesture %.0f + kabuk %.0f (%d)" % [tag, spec[1], int(screen.BOTTOM_PADDING),
			UiKit.bottom_inset(view), nav.reserve(), margin], margin == int(screen.BOTTOM_PADDING + UiKit.bottom_inset(view)
			+ nav.reserve()))
		_c("%s: %s gerçekten kayar (ön koşul: kaydırma aralığı > 0)" % [tag, spec[1]],
			scroll.get_v_scroll_bar().max_value - scroll.size.y > 1.0)
		scroll.scroll_vertical = 1000000
		await _settle(3)
		var content: Control = scroll.get_child(0) as Control
		var last: Control = _last_visible_leaf(content)
		var last_bottom: float = last.get_global_rect().end.y if last != null else 0.0
		_c("%s: %s sona kaydırıldı → son içerik (alt %.0f) kabuğun üstünde (%.0f)" % [tag, spec[1], last_bottom, floor_y],
			last != null and last_bottom <= floor_y)


# --- K: dokunuş erişimi ---------------------------------------------------------------------------------------------------

func _touch_reach() -> void:
	print("-- K: kabuk görünürken içerik gerçek dokunuşla çalışır; şerit içeriğe kalır")
	get_window().size = Vector2i(720, 1280)
	UiKit.set_banner_slot(0.0)
	await _boot()
	var nav: GlobalNav = _nav()
	# Tepsi üstündeki şerit: Mağaza'da yan öğenin üstüne 20 px dokunuş gezinmez.
	await _tab(3)
	var before: int = _main.nav_navigations
	for tab: int in [0, 2, 4]:
		for rise: float in [20.0, 6.0]:
			var item: NavItem = nav.item_button(tab)
			var band := Vector2(item.get_global_rect().get_center().x, nav.tray_rect().position.y - rise)
			await _finger(_screen(band), true)
			await _finger(_screen(band), false)
			await _settle(3)
			if _main._screens[3].has_open_overlay():
				_main._screens[3].handle_back()
				await _settle(2)
			await _wait_settled()
	_c("Mağaza: tepsinin 20 px ve 6 px üstündeki dokunuşlar (seçili olmayan yan öğe hizası) 0 gezinme, Mağaza'da",
		_main.nav_navigations == before and _visible_screens() == [3])
	# Harita: kabuk görünürken odak düğümü (Level 5) gerçek dokunuşla round başlatır.
	await _tab(1)
	var map: CanvasLayer = _main._screens[1]
	var focus: MapLevelNode = map.focus_node()
	before = _main.nav_navigations
	_c("  … Harita odak düğümü kabuğun üstünde (ön koşul)", focus != null and focus.get_global_rect().end.y
		<= nav.footprint().position.y)
	await _tap(focus)
	await _wait_settled()
	_c("Harita: odak düğümüne dokunuş round başlatır, 0 gezinme, kabuk gizlenir", _main._board != null
		and _main.nav_navigations == before and not nav.visible)
	_main.abandon_run()
	await _wait_settled()
	before = _main.nav_navigations
	await _tap(nav.item_button(0))
	await _wait_settled()
	_c("Harita → kabuk ANA SAYFA (gerçek dokunuş; üst satırda geri oku yok) → Ana Sayfa, tam 1 gezinme",
		_visible_screens() == [0] and nav.item_button(0).is_selected() and _main.nav_navigations == before + 1)
	# Mağaza: sona kaydır, son satırın SATIN AL'ı gerçek dokunuşla onayı açar.
	await _tab(3)
	var shop: CanvasLayer = _main._screens[3]
	shop.scroll().scroll_vertical = 1000000
	await _settle(3)
	await _wait_settled()
	var last_card: Control = shop.skin_cards()[shop.skin_cards().size() - 1]
	var buy: Button = last_card.buy_button()
	_c("  … son satır SATIN AL kabuğun üstünde (ön koşul: alt %.0f ≤ %.0f)" % [buy.get_global_rect().end.y,
		nav.footprint().position.y], buy.get_global_rect().end.y <= nav.footprint().position.y)
	before = _main.nav_navigations
	await _tap(buy)
	await _settle(3)
	_c("Mağaza son satır SATIN AL: gerçek dokunuş onayı açar, 0 gezinme, kabuk gizlenir", shop.has_open_overlay()
		and _main.nav_navigations == before and not nav.visible)
	shop.handle_back()
	await _wait_settled()
	# Koleksiyon: sona kaydır, son kart gerçek dokunuşla detayı açar.
	await _tab(2)
	var album: CanvasLayer = _main._screens[2]
	album.scroll().scroll_vertical = 1000000
	await _settle(3)
	await _wait_settled()
	var cards: Array = album.cards()
	var last: Control = cards[cards.size() - 1]
	_c("  … son kart kabuğun üstünde (ön koşul: alt %.0f ≤ %.0f)" % [last.get_global_rect().end.y,
		nav.footprint().position.y], last.get_global_rect().end.y <= nav.footprint().position.y)
	before = _main.nav_navigations
	await _tap(last)
	await _settle(3)
	_c("Koleksiyon son kart: gerçek dokunuş detayı açar, 0 gezinme, kabuk gizlenir", album.has_open_overlay()
		and _main.nav_navigations == before and not nav.visible)
	album.close_detail(false)
	await _wait_settled()
	_sections_done += 1


# --- L: Tur 2 (owner incelemesi) --------------------------------------------------------------------------------------

func _round2() -> void:
	print("-- L: Tur 2 — geri oku yok, tek seçili aile, kısıtlı 16:9 + banner yerleşimi")
	get_window().size = Vector2i(720, 1280)
	UiKit.set_banner_slot(0.0)
	await _boot()
	var nav: GlobalNav = _nav()
	# Geri oku yok: dört hub ekranının üst satırı ok içermez (Ana Sayfa'ya dönüş kabukta + Android GERİ).
	var no_arrow: bool = true
	for tab: int in [1, 3, 2, 4]:
		await _tab(tab)
		var bar: ScreenTopBar = _main._screens[tab].top_bar()
		no_arrow = no_arrow and bar.back_button() == null and bar.find_child("Back", true, false) == null
		for child: Node in bar.get_children():
			if child is Button:
				no_arrow = no_arrow and child == bar.action_button()
	_c("Harita / Mağaza / Koleksiyon / Profil üst satırında geri oku yok (yalnız kurdele + Hamur pill / dişli)", no_arrow)
	_c("kaynak sözleşmesi: ScreenTopBar `back_pressed` yaymaz; hub ekranlarında `home_requested` yok",
		not FileAccess.get_file_as_string("res://scripts/ui/screen_top_bar.gd").contains("signal back_pressed")
		and ["level_select", "shop_screen", "collection_screen", "profile_screen"].all(func(f: String) -> bool:
			return not FileAccess.get_file_as_string("res://scripts/ui/%s.gd" % f).contains("home_requested")))
	_c("Profil dişlisi ve Harita / Koleksiyon Hamur \"+\" yerinde; Mağaza'da \"+\" yok (yeni işlev yok)",
		_main._screens[4].top_bar().action_button() != null and _main._screens[1].top_bar().add_button() != null
		and _main._screens[2].top_bar().add_button() != null and _main._screens[3].top_bar().add_button() == null)
	var fam: Dictionary = NavItem.selected_family()
	_c("seçili aile tek tanım: krem dolgu + altın parıltı",
		fam.get("fill") == UiTokens.NAV_SELECTED and fam.get("glow") == UiTokens.NAV_SELECTED_GLOW)
	var same: bool = true
	for tab: int in TABS:
		await _tab(tab)
		same = same and _family_ok(nav)
	_c("beş sekmenin her birinde seçili öğe aynı aileyi uygular (merkez Harita dahil)", same)
	# Kısıtlı yerleşim: 720×1280 + banner 112 (16:9).
	UiKit.set_banner_slot(A36_SLOT)
	await _boot()
	nav = _nav()
	_main._on_banner_slot_changed(A36_SLOT)
	await _settle(2)
	var view: Vector2 = nav.get_viewport().get_visible_rect().size
	_c("16:9 + banner: kabuk KOMPAKT (merkez taşması 0, pay %.0f)" % nav.reserve(), nav.is_compact()
		and is_zero_approx(nav.center_rise()) and is_equal_approx(nav.reserve(), GlobalNav.BANNER_GAP + GlobalNav.TRAY_HEIGHT))
	var min_side: float = 9999.0
	for item: NavItem in nav.items():
		var r: Rect2 = item.get_global_rect()
		min_side = minf(min_side, minf(r.size.x, r.size.y))
	_c("16:9 + banner: her kabuk öğesinin dokunma alanı ≥ %d px (en küçük kenar %.0f)" % [UiTokens.TOUCH_TARGET, min_side],
		min_side >= UiTokens.TOUCH_TARGET)
	var center: NavItem = nav.item_button(1)
	var mid := Vector2(center.size.x * 0.5, center.tray_top() + GlobalNav.TRAY_HEIGHT * 0.5)
	# Karşılaştırma seçili OLMAYAN yan öğeyle (seçili karo etiketi birkaç px yükselir).
	var plain: NavItem = nav.items().filter(func(i: NavItem) -> bool: return not i.is_selected() and not i.is_center())[0]
	var side_label_y: float = plain.label_node().get_global_rect().position.y
	var center_label_y: float = center.label_node().get_global_rect().position.y
	_c("16:9 + banner: kompakt merkez etiketi yan etiketlerle neredeyse aynı çizgide (fark %.0f px ≤ 6), tepsi yüzünde"
		% (center_label_y - side_label_y), absf(center_label_y - side_label_y) <= 6.0
		and center.label_node().get_global_rect().end.y <= nav.tray_rect().end.y)
	_c("16:9 + banner: kompakt merkezin dekoratif taşması dokunuş almaz (tepsi üstü 2 px: hayır, tepsi içi: evet)",
		not center._has_point(Vector2(center.size.x * 0.5, center.tray_top() - 2.0))
		and center._has_point(Vector2(center.size.x * 0.5, center.tray_top() + 2.0)))
	_c("16:9 + banner: kompakt kabuk dokunma alanı tepsiden başlar (seçili yan karonun yükselişi yalnız görsel)",
		nav.items().all(func(i: NavItem) -> bool: return not i._has_point(Vector2(i.size.x * 0.5, i.tray_top() - 6.0))))
	_c("16:9 + banner: kompakt merkez (Harita) tepsi yüksekliğinin tamamında dokunulur (%d px)" % int(GlobalNav.TRAY_HEIGHT),
		center.is_compact() and center._has_point(mid) and center._has_point(Vector2(4.0, center.tray_top() + 4.0))
		and center._has_point(Vector2(center.size.x - 4.0, center.tray_top() + GlobalNav.TRAY_HEIGHT - 4.0)))
	var slot_top: float = view.y - A36_SLOT
	var plinth: Control = nav.get_node("Root/BannerPlinth")
	_c("16:9 + banner: yuva kabukla çakışmaz (tepsi altı %.0f + 28 = yuva üstü %.0f)" % [nav.tray_rect().end.y, slot_top],
		is_equal_approx(nav.tray_rect().end.y + GlobalNav.BANNER_GAP, slot_top))
	_c("16:9 + banner: aralık kaidesi görünür, dokunuş almaz, yuvaya taşmaz (dock'un parçası; ölü gri şerit değil)",
		plinth.visible and plinth.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and plinth.get_global_rect().end.y <= slot_top + 0.5)
	var dock: Rect2 = nav.dock_block_rect()
	_c("16:9 + banner: tepsi üstünden ekran altına dock dokunuş tutar (kabuk altında içerik etkileşimi yok)",
		is_equal_approx(dock.position.y, nav.tray_rect().position.y) and is_equal_approx(dock.end.y, view.y))
	var family_compact: bool = true
	for tab: int in TABS:
		await _tab(tab)
		family_compact = family_compact and _family_ok(nav) and nav.visible
	_c("16:9 + banner: beş sekmede seçili aile aynı (kompakt kipte de)", family_compact)
	await _tab(1)
	var map: CanvasLayer = _main._screens[1]
	var squash: float = map.world_scale().y / map.world_scale().x
	var art_ratio: float = map.map_art().size.y / map.map_art().size.x
	_c("16:9 + banner: Harita sıkıştırması yok (zemin oranı %.4f = 1280/720; Tur 2'nin 0.926'sı ve ilk adayın 0.819'u tarihsel)"
		% art_ratio, is_equal_approx(squash, 1.0) and absf(art_ratio - 1280.0 / 720.0) < 0.001)
	var floor_y: float = nav.footprint().position.y
	var bar2: ScreenTopBar = map.top_bar()
	var inside: bool = true
	var smallest: float = 9999.0
	var targets: Array[MapLevelNode] = []
	targets.append_array(map.nodes())
	targets.append(map.endless_node())
	# TASK/059: her düğüm kendi kamera konumunda ekranda, üst satırın altında, kabuğun üstünde, Hamur pill'iyle çakışmaz.
	for node: MapLevelNode in targets:
		map.set_scroll(map.scroll_for(node))
		await _settle(1)
		var r: Rect2 = node.get_global_rect()
		smallest = minf(smallest, node.diameter())
		inside = inside and r.position.y >= bar2.height() and _node_bottom(node) <= floor_y and r.position.x >= 0.0 \
			and r.end.x <= view.x and not r.intersects(bar2.pill().get_global_rect())
	map.set_scroll(map.focus_scroll())
	await _settle(1)
	_c("16:9 + banner: her düğüm + Sonsuz kalesi kendi kamera konumunda ekranda, kabuğun üstünde, Hamur pill'iyle çakışmaz (en küçük %.0f px ≥ %d)"
		% [smallest, UiTokens.TOUCH_TARGET], inside and smallest >= UiTokens.TOUCH_TARGET - 0.5)
	var focus: MapLevelNode = map.focus_node()
	_c("16:9 + banner: odak (sıradaki) düğüm ≥ TOUCH_TARGET (%.1f px)" % focus.diameter(), focus.diameter()
		>= UiTokens.TOUCH_TARGET - 0.5)
	print("    16:9 + banner: kurdele %s, sy/sx %.3f (eski 0.819), en küçük düğüm %.1f, odak %.1f" % [
		"bıraktı" if map.title_yielded() else "görünür", squash, smallest, focus.diameter()])
	var before: int = _main.nav_navigations
	await _tap(focus)
	await _wait_settled()
	_c("16:9 + banner: odak düğümüne gerçek dokunuş round başlatır (0 gezinme, kabuk gizli)", _main._board != null
		and _main.nav_navigations == before and not nav.visible)
	_main.abandon_run()
	await _wait_settled()
	# Geniş Hamur pill'i (5-6 hane): kurdele / kale kararı pill'in gerçek genişliğiyle verilir.
	for dough: int in [12480, 99999, 999999]:
		await _boot({"dough": dough})
		_main._on_banner_slot_changed(A36_SLOT)
		await _tab(1)
		await _settle(3)
		var m: CanvasLayer = _main._screens[1]
		var b: ScreenTopBar = m.top_bar()
		m.set_scroll(0.0)
		await _settle(1)
		var e: Rect2 = m.endless_node().get_global_rect()
		var p: Rect2 = b.pill().get_global_rect()
		var s: float = m.world_scale().y / m.world_scale().x
		var overlap: bool = e.intersects(p) or e.intersects(m.stars_pill().get_global_rect()) \
			or (b.is_title_visible() and e.intersects(b.title_plate().get_global_rect()))
		print("    Hamur %d: pill x %.0f..%.0f, kale x %.0f..%.0f y %.0f (en üst), kurdele %s, sy/sx %.3f, çakışma %s" % [dough,
			p.position.x, p.end.x, e.position.x, e.end.x, e.position.y, "gizli" if m.title_yielded() else "görünür", s,
			str(overlap)])
		# TASK/059: kurdele her zaman gizli (text-light); geniş Hamur pill'i kaleye binmez — kale en üstte üst satırın altında.
		_c("16:9 + banner, Hamur %d: kurdele gizli, en üstte kale pill'lerle çakışmaz, üst satırın altında, sy/sx %.3f = 1" % [
			dough, s], m.title_yielded() and not overlap and e.position.y >= b.height() - 0.5 and is_equal_approx(s, 1.0))
	# Büyük üst güvenli pay (40) + 16:9 + yuva: kurdele bırakılsa da %8'e sığmaz → son çare taban; kale güvenli alanda.
	await _boot()
	_main._on_banner_slot_changed(A36_SLOT)
	await _tab(1)
	var tall: CanvasLayer = _main._screens[1]
	tall._layout_with_safe_top(40.0)
	await _settle(2)
	var ts: float = tall.world_scale().y / tall.world_scale().x
	tall.set_scroll(0.0)
	await _settle(1)
	var castle_y: float = tall.endless_node().get_global_rect().position.y
	tall.set_scroll(tall.scroll_limits().y)
	await _settle(1)
	var lowest: float = 0.0
	for node: MapLevelNode in tall.nodes():
		lowest = maxf(lowest, _node_bottom(node))
	print("    16:9 + banner + üst 40: sy/sx %.3f, kale y %.0f (en üst), en alt %.0f (en alt), kabuk %.0f" % [ts,
		castle_y, lowest, _nav().footprint().position.y])
	_c("16:9 + banner + üst güvenli pay 40 (uç durum): en üstte kale güvenli alanda ve üst satırın altında, en altta düğümler kabuğun üstünde, sy/sx %.3f = 1"
		% ts, castle_y >= tall.top_bar().height() - 0.5 and castle_y >= 40.0
		and lowest <= _nav().footprint().position.y and is_equal_approx(ts, 1.0))
	tall._layout_with_safe_top(0.0)
	get_window().size = Vector2i(720, 1280)
	UiKit.set_banner_slot(0.0)
	_sections_done += 1


## Seçili öğe NavItem.selected_family()'yi uygular, diğer öğeler boş (seçili aile tek kaynak).
func _family_ok(nav: GlobalNav) -> bool:
	var fam: Dictionary = NavItem.selected_family()
	var ok: bool = true
	for item: NavItem in nav.items():
		if item.is_selected():
			ok = ok and item.applied_selection() == fam
		else:
			ok = ok and item.applied_selection().is_empty()
	return ok


# --- Ortak ---------------------------------------------------------------------------------------------------------------

func _nav() -> GlobalNav:
	return _main.global_nav()


func _visible_screens() -> Array[int]:
	var out: Array[int] = []
	for i in _main._screens.size():
		if (_main._screens[i] as CanvasLayer).visible:
			out.append(i)
	return out


## Harita düğümünün en alt görsel sınırı (OYNA plakası dahil).
func _node_bottom(node: MapLevelNode) -> float:
	var bottom: float = node.get_global_rect().end.y
	for child in node.get_children():
		var control := child as Control
		if control != null and control.visible:
			bottom = maxf(bottom, control.get_global_rect().end.y)
	return bottom


## Kaydırılan içeriğin en alttaki görünür kartı / satırı (kabın son görünür çocuğu).
func _last_visible_leaf(content: Control) -> Control:
	var children: Array = content.get_children()
	for i in range(children.size() - 1, -1, -1):
		var child := children[i] as Control
		if child != null and child.visible and child.size.y > 1.0:
			if child is Container and child.get_child_count() > 0 and not (child is PanelContainer):
				var inner: Control = _last_visible_leaf(child)
				return inner if inner != null else child
			return child
	return null


func _find_all(node: Node, cls: String) -> Array:
	var out: Array = []
	if node.get_script() != null and (node.get_script() as Script).get_global_name() == cls:
		out.append(node)
	for child in node.get_children():
		out.append_array(_find_all(child, cls))
	return out


func _fixture(extra: Dictionary = {}) -> Dictionary:
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 2},
		"endless_high_score": 640, "dough": 900, "total_merges": 40, "merges_since_bonus_chest": 10,
		"unlocked_skins": ["common_01", String(SHOWCASE_ID)], "profile_showcase": [String(SHOWCASE_ID)],
		"powerups": {"bomb": 0, "upgrade": 2, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "", "daily_streak": 3,
		"last_login_date": Time.get_date_string_from_system(), "age_ad_band": "ADULT", "next_age_transition_date": "",
		"player_meta_version": 1, "player_xp": 400, "total_rounds_played": 12, "highest_tier_created": 4,
		"unlocked_achievements": ["merge_10"], "daily_challenge": {"version": 1, "completed_day_key": ""},
		"daily_rewards": {"day_key": THU, "free_chest_claimed": true, "ad_chests_claimed": 2,
			"dough_ad_claimed": true, "popup_seen_day": THU, "last_seen_day_key": THU},
		"missions": {"version": 1, "day_key": THU, "week_start_day_key": MON,
			"daily_progress": {"daily_merges": 5, "daily_rounds": 0, "daily_clear": 0}, "daily_rewarded": [],
			"weekly_progress": {"weekly_merges": 30, "weekly_rounds": 4, "weekly_clears": 2}, "weekly_rewarded": []}}
	for key: String in extra:
		content[key] = extra[key]
	return content


## Temiz kayıt + Main (Ana Sayfa).
func _boot(extra: Dictionary = {}) -> void:
	await _teardown_main()
	_clean()
	DailyRewards.clock_override = THU
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(_fixture(extra), "\t"))
	file.close()
	SaveManager.load_game()
	_main = MAIN_SCENE.instantiate()
	_main.set("quit_suppressed", true)
	add_child(_main)
	await _settle(3)
	_main.set("quit_suppressed", true)
	await _wait_settled()


func _tab(index: int) -> void:
	_main._show_tab(index)
	await _wait_settled()


func _touch_event(pos: Vector2, pressed: bool, index: int) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = pos
	touch.pressed = pressed
	return touch


func _finger(pos: Vector2, pressed: bool, index: int = 0) -> void:
	Input.parse_input_event(_touch_event(pos, pressed, index))
	Input.flush_buffered_events()
	await get_tree().process_frame


func _tap(control: Control) -> void:
	var pos: Vector2 = _center(control)
	await _finger(pos, true)
	await _finger(pos, false)
	await _settle(3)


## Android ACTION_CANCEL: bırakış `canceled == true`.
func _cancel_finger(pos: Vector2, index: int = 0) -> void:
	var cancel := _touch_event(pos, false, index)
	cancel.canceled = true
	Input.parse_input_event(cancel)
	Input.flush_buffered_events()
	await _settle(2)


## Hiçbir şeyin işlemediği girdi (cihazda GERİ tuşunun kendi olayı) — Viewport "işlendi" bayrağı kapalı kalır.
func _unhandled_key() -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_F13
		key.physical_keycode = KEY_F13
		key.pressed = pressed
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		await get_tree().process_frame


func _window_notify(what: int) -> void:
	_notify_tree(get_tree().root, what)


func _notify_tree(node: Node, what: int) -> void:
	node.notification(what)
	var i: int = 0
	while i < node.get_child_count(true):
		var child: Node = node.get_child(i, true)
		if not (child is Window):
			_notify_tree(child, what)
		i += 1


## Android geri (Main'in 250 ms debounce'u gerçek saatle).
func _back() -> void:
	var gap: int = maxi(_last_back_msec + BACK_GAP_MSEC, int(_main.get("_last_back_msec")) + BACK_GAP_MSEC) \
		- Time.get_ticks_msec()
	if gap > 0:
		await get_tree().create_timer(float(gap) / 1000.0).timeout
	_last_back_msec = Time.get_ticks_msec()
	_window_notify(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(1)


func _screen(canvas: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * canvas


func _center(control: Control) -> Vector2:
	return _screen(control.get_global_rect().get_center())


func _wait_settled() -> void:
	await get_tree().create_timer(0.45).timeout
	await _settle(1)


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _settle(2)


func _teardown() -> void:
	DailyRewards.clock_override = ""
	DailyRewards.auto_popup_enabled = false
	UiKit.set_banner_slot(0.0)
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


func _clean() -> void:
	for p: String in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for p: String in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null
	return out
