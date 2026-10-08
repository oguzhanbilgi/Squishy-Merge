extends Node
## TASK/059 — Harita V3 (kaydırılabilir yolculuk + MEYDAN portalı) odak testi. Headless; gerçek `main.tscn`, kayıt
## `user://qa_map_v3/`'e YÖNLENDİRİLİR (sahibin kayıt ailesi başta / sonda bayt bayt karşılaştırılır), saat kancası
## sabit gün (2026-10-01, Perşembe → T5 meydan okuması). Girdi GERÇEK parmak olayları (`InputEventScreenTouch` /
## `InputEventScreenDrag` → motorun dokunuştan fare öykünmesi → GUI).
##
##   godot --headless --audio-driver Dummy --path . res://tools/map_v3_test.tscn
##
## Bölümler: A geometri (6 görünüm) · B odak / kırpma / giriş politikası · C girdi (dokunuş, sürükleme, iptal, bayat
## bırakış, GERİ / sekme sırasında jest, savurma, tekerlek) · D MEYDAN portalı + Ana Sayfa MEYDAN + pencere sahipliği ·
## E kayıt yazılmaz · F açılış / giriş animasyonu · G sahiplik ve text-light kaynak sözleşmesi.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DUMPLING_VISUAL: GDScript = preload("res://scripts/game/dumpling_visual.gd")
const DIR: String = "user://qa_map_v3"
const PATH: String = DIR + "/save.json"
const MON: String = "2026-09-28"
const THU: String = "2026-10-01"
const SECTIONS: int = 7
const BACK_GAP_MSEC: int = 320
const A36_SAFE_TOP: float = 61.0
const SLOT: float = 112.0
const TIGHT_SLOT: float = 128.0
## [pencere, üst güvenli pay, banner yuvası, etiket]
const VIEWS: Array = [
	[Vector2i(720, 1280), 0.0, 0.0, "720×1280"],
	[Vector2i(720, 1280), 0.0, SLOT, "720×1280 + banner 112"],
	[Vector2i(720, 1280), 0.0, TIGHT_SLOT, "720×1280 + banner 128 (en dar)"],
	[Vector2i(720, 1600), 0.0, 0.0, "720×1600"],
	[Vector2i(720, 1560), A36_SAFE_TOP, 0.0, "A36 benzeri 720×1560 + üst 61"],
	[Vector2i(720, 1560), A36_SAFE_TOP, SLOT, "A36 benzeri 720×1560 + üst 61 + banner 112"],
]

var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _finished: bool = false
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _main: Node2D
var _last_back_msec: int = -100000
var _chosen: Array[int] = []


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
	get_tree().create_timer(280.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 280 s'de bitmedi — SaveManager geri alındı")
			if _main != null and is_instance_valid(_main):
				_main.free()
			_teardown()
			get_tree().quit(2))
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame

	await _geometry()
	await _focus_policy()
	await _input_safety()
	await _portal()
	await _save_untouched()
	await _animation()
	await _contract()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	print("-- kayıt")
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


# --- A: geometri -----------------------------------------------------------------------------------------------------

func _geometry() -> void:
	print("-- A: geometri — tek tip ölçek, kaydırma, düğüm / portal / kabuk payları (6 görünüm)")
	for spec in VIEWS:
		get_window().size = spec[0]
		UiKit.set_banner_slot(float(spec[2]))
		await _boot()
		await _apply_view(float(spec[1]), float(spec[2]))
		await _tab(1)
		await _check_geometry(_map(), String(spec[3]), float(spec[1]))
	get_window().size = Vector2i(720, 1280)
	UiKit.set_banner_slot(0.0)
	_sections_done += 1


func _apply_view(safe_top: float, slot: float) -> void:
	for screen: CanvasLayer in _main._screens:
		if screen.has_method("_layout_with_safe_top"):
			screen._layout_with_safe_top(safe_top)
	_main._on_banner_slot_changed(slot)
	await _settle(2)


func _check_geometry(map: CanvasLayer, tag: String, safe_top: float) -> void:
	var nav: GlobalNav = _main.global_nav()
	var view: Vector2 = get_viewport().get_visible_rect().size
	var bar: ScreenTopBar = map.top_bar()
	var scale: Vector2 = map.world_scale()
	var limits: Vector2 = map.scroll_limits()
	var footprint: float = nav.footprint().position.y
	print("    %s: ölçek %.3f, kaydırma [0, %.0f], odak %.0f, dünya %.0f px, gök bandı %.0f, tepsi %.0f, kabuk %s" % [tag,
		scale.x, limits.y, map.scroll_offset(), map.world_height(), map.sky_band(), nav.tray_rect().position.y,
		"kompakt" if nav.is_compact() else "normal"])
	_c("%s: TEK TİP ölçek (sx == sy = %.3f ≥ 1.3; eski dikey sıkıştırma yok)" % [tag, scale.x],
		is_equal_approx(scale.x, scale.y) and scale.x >= map.WORLD_ZOOM - 0.001)
	_c("%s: zemin owner map_background'ın kendisi, bütün (atlas / kırpma yok), oran korunmuş" % tag,
		map.map_art().texture == map.MAP_TEXTURE and map.map_art().stretch_mode == TextureRect.STRETCH_SCALE
		and absf(map.map_art().size.x / map.map_art().size.y - 720.0 / 1280.0) < 0.001)
	_c("%s: gerçek kaydırma aralığı var (%.0f px > 100)" % [tag, limits.y], limits.y > 100.0)
	_c("%s: dünya bandı kabuk tepsisinin üst kenarında biter" % tag,
		absf(map.world_rect().end.y - nav.tray_rect().position.y) <= 1.0)
	_c("%s: text-light — HARİTA kurdelesi gizli, ⭐ pill'i '11/30', Hamur pill'i görünür, ikisi çakışmaz" % tag,
		not bar.is_title_visible() and map.stars_text() == "11/30" and bar.pill().is_visible_in_tree()
		and not map.stars_pill().get_global_rect().intersects(bar.pill().get_global_rect())
		and map.stars_pill().get_global_rect().position.y >= safe_top)
	var all: Array[Control] = _all_targets(map)
	var big: bool = true
	for target in all:
		big = big and target.size.x >= UiTokens.TOUCH_TARGET - 0.5 and target.size.y >= UiTokens.TOUCH_TARGET - 0.5
	_c("%s: 11 düğüm + portal dokunma hedefi ≥ %d px (en küçük düğüm %.1f)" % [tag, UiTokens.TOUCH_TARGET,
		_smallest(map)], big)
	var overlap: String = ""
	for i in all.size():
		for j in range(i + 1, all.size()):
			if _hit(all[i]).intersects(_hit(all[j])):
				overlap += " %s×%s" % [all[i].name, all[j].name]
	_c("%s: dokunma alanları (plaka dahil) birbirine binmez%s" % [tag, overlap], overlap.is_empty())
	# Beklenen merkez ÇİZİLEN zeminden türetilir (zeminin ekran dikdörtgeni + doku konumu × ölçek), düğümün ölçeksiz
	# yerleşim merkeziyle karşılaştırılır (nefes / pop ölçeği hariç) — yerleştirme koduyla aynı formülü kullanmaz.
	var art_rect: Rect2 = map.map_art().get_global_rect()
	var tex_scale: float = art_rect.size.x / 720.0
	var path_ok: bool = absf(art_rect.size.y / 1280.0 - tex_scale) < 0.001
	var world_origin: Vector2 = map.world_layer().global_position
	var all_points: Array = []
	all_points.append_array(map.NODE_POSITIONS)
	all_points.append(map.ENDLESS_POSITION)
	var all_nodes: Array[MapLevelNode] = []
	all_nodes.append_array(map.nodes())
	all_nodes.append(map.endless_node())
	for i in all_nodes.size():
		var node: MapLevelNode = all_nodes[i]
		var drawn: Vector2 = art_rect.position + (all_points[i] as Vector2) * tex_scale
		var center: Vector2 = world_origin + node.position + Vector2(node.diameter(), node.diameter()) * 0.5
		path_ok = path_ok and center.distance_to(drawn) < 0.75
	_c("%s: 10 düğüm + Sonsuz ÇİZİLEN zeminin patika noktalarında (zemin dikdörtgeninden türetilmiş)" % tag, path_ok)
	# D3: kilitli kale şartı tek eylem "10'U BİTİR" (kilit ikonuyla); plaka okunur boyda (15 px, küçültülmedi), yazı plakaya
	# sığar (kırpma yok), ekranda ve kale + level 10 ile çakışmaz.
	var castle_node: MapLevelNode = map.endless_node()
	var plaque_label: Label = castle_node._plaque_label
	var label_fits: bool = plaque_label.get_combined_minimum_size().x <= castle_node._plaque_body.size.x + 0.5 \
		and castle_node._plaque_lock.visible and plaque_label.get_theme_font_size("font_size") >= 15
	var plaque_rect: Rect2 = castle_node.plaque_rect()
	_c("%s: kilitli kale plakası kilit + '10'U BİTİR', 15 px, sığıyor, ekranda, level 10 ile çakışmıyor" % tag,
		castle_node.plaque_text() == "10'U BİTİR" and label_fits and plaque_rect.position.x >= 0.0 and plaque_rect.end.x <= 720.0
		and not plaque_rect.intersects(map.nodes()[9].get_global_rect()))
	# Odak: girişte sıradaki level (5) düğüme açık bantta.
	var focus: MapLevelNode = map.focus_node()
	_c("%s: girişte kamera odakta (level 5), odak düğümü + OYNA açık bantta" % tag, focus == map.nodes()[4]
		and _near(map.scroll_offset(), map.focus_scroll()) and _in_band(map, focus.hit_rect()))
	var pills_clear: bool = _pills_clear(map)
	_c("%s: giriş dinlenme konumunda hiçbir düğüm / plaka / kilit / portal üst satır pill'lerinin altında yarım kalmaz" % tag,
		pills_clear and map.rest_clear_at(map.scroll_offset()))
	# Her düğüm kendi kamera konumunda açık bantta (erişilebilir).
	var reach: String = ""
	var targets: Array[Control] = []
	targets.append_array(map.nodes())
	targets.append(map.endless_node())
	for target in targets:
		map.set_scroll(map.scroll_for(target))
		await _settle(1)
		if not _in_band(map, _hit(target)):
			reach += " " + String(target.name)
	_c("%s: 10 level + Sonsuz kaydırmayla açık banda gelir (üst satır ile kabuk arası)%s" % [tag, reach], reach.is_empty())
	# Uçlar.
	map.set_scroll(0.0)
	await _settle(1)
	var castle: Rect2 = map.endless_node().visual_rect()
	castle.position.y -= map.endless_node().diameter() * map.ENDLESS_LOCK_RISE
	_c("%s: en üstte Sonsuz kalesi (kilit rozeti dahil) üst satırın altında, pill'lerle çakışmaz" % tag,
		castle.position.y >= bar.height() and not castle.intersects(bar.pill().get_global_rect())
		and not castle.intersects(map.stars_pill().get_global_rect()))
	var top_cover: bool = _covered(map, view)
	var portal_top: bool = _portal_clear(map)
	map.set_scroll(limits.y)
	await _settle(1)
	var first: Rect2 = map.nodes()[0].visual_rect()
	_c("%s: en altta level 1 (plaka dahil) kabuğun üstünde (%.0f ≤ %.0f)" % [tag, first.end.y, footprint],
		first.end.y <= footprint and first.position.y >= bar.height())
	var bottom_cover: bool = _covered(map, view)
	var portal_bottom: bool = _portal_clear(map)
	map.set_scroll(limits.y * 0.5)
	await _settle(1)
	_c("%s: zemin + gök bandı görünen bandı her kamera konumunda kaplar (boş / alt zemin görünmez)" % tag,
		top_cover and bottom_cover and _covered(map, view))
	map.set_scroll(map.focus_scroll())
	await _settle(1)
	_c("%s: MEYDAN portalı (yıldız halkası + plaka) en üstte, odakta ve en altta tamamen açık bantta ve ekranda" % tag,
		portal_top and portal_bottom and _portal_clear(map))


## Dokunma alanı (global): düğüm gövde + plaka, portal kendi dikdörtgeni.
func _hit(target: Control) -> Rect2:
	if target is MapLevelNode:
		return (target as MapLevelNode).hit_rect()
	return target.get_global_rect()


func _all_targets(map: CanvasLayer) -> Array[Control]:
	var out: Array[Control] = []
	out.append_array(map.nodes())
	out.append(map.endless_node())
	out.append(map.challenge_portal())
	return out


func _smallest(map: CanvasLayer) -> float:
	var out: float = 9999.0
	for node: MapLevelNode in map.nodes():
		out = minf(out, node.diameter())
	return out


## Açık bant: üst satırın altından kabuğun ayak izinin üstüne; yatayda ekranın içi.
func _in_band(map: CanvasLayer, rect: Rect2) -> bool:
	var nav: GlobalNav = _main.global_nav()
	return rect.position.y >= map.top_bar().height() - 0.5 and rect.end.y <= nav.footprint().position.y + 0.5 \
		and rect.position.x >= 0.0 and rect.end.x <= 720.0


func _portal_clear(map: CanvasLayer) -> bool:
	var portal: MapChallengePortal = map.challenge_portal()
	return portal.is_visible_in_tree() and _in_band(map, portal.visual_rect())


## Zemin + gök bandı görünen dünya bandını [0, tepsi üstü] boşluksuz kaplıyor mu (şu anki kamera).
func _covered(map: CanvasLayer, view: Vector2) -> bool:
	var art: Rect2 = map.map_art().get_global_rect()
	var band_bottom: float = map.world_rect().end.y
	var sky: Rect2 = map._sky.get_global_rect()
	var top_ok: bool = art.position.y <= 0.0 or (sky.position.y <= 0.0 and sky.end.y >= art.position.y
		and sky.position.x <= 0.0 and sky.end.x >= view.x)
	return art.position.x <= 0.0 and art.end.x >= view.x and art.end.y >= band_bottom - 0.5 and top_ok


# --- B: odak / kırpma / giriş politikası -----------------------------------------------------------------------------

func _focus_policy() -> void:
	print("-- B: odak düğümü ve kamera kırpması (L1, L5, L10, Sonsuz), giriş politikası")
	for spec in [[1, {}, 0, "L1 (yeni oyuncu)"], [5, {"1": 3, "2": 3, "3": 2, "4": 2}, 4, "L5"],
			[10, _stars(9), 9, "L10"], [11, _stars(10), -1, "Sonsuz açık"]]:
		await _boot({"highest_level_unlocked": spec[0], "level_stars": spec[1]})
		await _tab(1)
		var map: CanvasLayer = _map()
		var index: int = int(spec[2])
		var expected: MapLevelNode = map.endless_node() if index < 0 else map.nodes()[index]
		var limits: Vector2 = map.scroll_limits()
		_c("%s: odak doğru düğüm, kamera odak konumunda ve sınır içinde (%.0f ∈ [0, %.0f])" % [spec[3],
			map.scroll_offset(), limits.y], map.focus_node() == expected and expected.is_focused()
			and _near(map.scroll_offset(), map.focus_scroll()) and map.scroll_offset() >= 0.0
			and map.scroll_offset() <= limits.y)
		_c("%s: odak düğümü (plaka dahil) açık bantta; MEYDAN portalı da ekranda" % spec[3],
			_in_band(map, _hit(expected)) and _portal_clear(map))
	# L1 en alt kırpmada, Sonsuz en üstte (uçlar kırpılır, taşma yok).
	await _boot({"highest_level_unlocked": 1, "level_stars": {}})
	await _tab(1)
	_c("L1 odak: kamera en alt sınırda kırpılı (%.0f = %.0f)" % [_map().scroll_offset(), _map().scroll_limits().y],
		is_equal_approx(_map().scroll_offset(), _map().scroll_limits().y))
	await _boot({"highest_level_unlocked": 11, "level_stars": _stars(10)})
	await _tab(1)
	_c("Sonsuz odak: kamera en üstte (0)", is_zero_approx(_map().scroll_offset()))
	# Giriş politikası: ziyaret içinde kaydırma korunur; yeni giriş odağa döner.
	await _boot()
	await _tab(1)
	var map: CanvasLayer = _map()
	var focus: float = map.scroll_offset()
	await _drag(Vector2(560.0, 700.0), Vector2(0.0, 220.0), 8)
	await _settle(30)
	var moved: float = map.scroll_offset()
	_main._show_tab(1)
	await _wait_settled()
	_c("aynı sekme yeniden istenince (pencere kapanışı gibi) oyuncunun kaydırması korunur (%.0f → %.0f, odak %.0f)" % [
		moved, map.scroll_offset(), focus], absf(moved - focus) > 50.0 and is_equal_approx(map.scroll_offset(), moved))
	await _tab(0)
	await _tab(1)
	_c("yeni giriş (sekme geçişi) kamerayı odağa döndürür (%.0f)" % map.scroll_offset(),
		_near(map.scroll_offset(), map.focus_scroll()) and _near(map.scroll_offset(), focus))
	# Geç gelen banner yuvası (girişten sonra): oyuncu kaydırmadıysa odak korunur, düğüm kabuğun üstünde kalır.
	UiKit.set_banner_slot(SLOT)
	_main._on_banner_slot_changed(SLOT)
	await _settle(3)
	_c("geç banner yuvası: kamera yeni sınırla yeniden odakta, odak düğümü kabuğun üstünde",
		_near(map.scroll_offset(), map.focus_scroll()) and _in_band(map, _hit(map.focus_node())))
	UiKit.set_banner_slot(0.0)
	_main._on_banner_slot_changed(0.0)
	_sections_done += 1


# --- C: girdi --------------------------------------------------------------------------------------------------------

func _input_safety() -> void:
	print("-- C: girdi — dokunuş tam bir level, sürükleme level başlatmaz, iptal / bayat bırakış / GERİ / sekme")
	await _boot()
	await _tab(1)
	var map: CanvasLayer = _map()
	_chosen.clear()
	map.level_chosen.connect(func(l: LevelData) -> void: _chosen.append(l.level_number))
	var l5: MapLevelNode = map.nodes()[4]
	# 1) taze dokunuş → tam bir round.
	await _tap_at(_center_of(l5))
	_c("açık level 5'e gerçek dokunuş → tam bir level_chosen(5), gerçek board", _chosen == [5]
		and _main._board != null and _main._current_level.level_number == 5 and not map.visible)
	var board: Variant = _main._board
	await _tap_at(_center_of(l5))
	_c("hızlı ikinci dokunuş ikinci board başlatmaz (300 ms yatışma + gizli Harita; aynı board, tek level_chosen)",
		_chosen == [5] and _main._board == board)
	await _abandon()
	_c("round terk → Harita (board yok)", _main._board == null and _main._active_tab == 1 and map.visible)
	# 2) "OYNA" plakasına (gövdenin altı) dokunuş da düğümündür.
	l5 = map.nodes()[4]
	await _tap_at(_screen(l5.plaque_rect().get_center()))
	_c("OYNA kelimesine dokunuş (gövde dışı plaka) level 5'i başlatır — ölü dokunuş yok", _chosen == [5, 5]
		and _main._board != null)
	await _abandon()
	# 3) düğümden başlayan sürükleme level başlatmaz.
	l5 = map.nodes()[4]
	var before: float = map.scroll_offset()
	var drags: int = map.drag_count
	await _drag(_center_of_canvas(l5), Vector2(0.0, -150.0), 10)
	await _settle(2)
	_c("düğümden başlayan sürükleme: level YOK, kamera kaydı (%.0f → %.0f), sürükleme sayıldı" % [before,
		map.scroll_offset()], _chosen == [5, 5] and _main._board == null and map.visible
		and absf(map.scroll_offset() - before) > 80.0 and map.drag_count == drags + 1)
	await _settle(40)
	_c("sürüklemeden sonra düğümün basış ölçeği bırakıldı (≈1)", absf(l5.scale.x - 1.0) <= 0.02)
	# 4) boş dünyadan sürükleme.
	before = map.scroll_offset()
	await _drag(Vector2(620.0, 520.0), Vector2(0.0, 160.0), 8)
	await _settle(40)
	_c("boş dünyadan sürükleme: kamera kayar, level yok", absf(map.scroll_offset() - before) > 80.0
		and _main._board == null)
	# 5) eşik altı titreşim dokunuştur (tamamlanmış level 4 tekrar oynanır).
	await _refocus(map)
	var l4: MapLevelNode = map.nodes()[3]
	var p: Vector2 = _center_of_canvas(l4)
	await _finger(_screen(p), true)
	await _move(p, p + Vector2(4.0, 7.0))
	await _finger(_screen(p + Vector2(4.0, 7.0)), false)
	await _settle(3)
	_c("eşik altı (8 px) titreşim dokunuş sayılır: tamamlanmış level 4 tekrar oynanır (tek level)",
		_chosen == [5, 5, 4] and _main._board != null and _main._current_level.level_number == 4)
	await _abandon()
	# 6) ACTION_CANCEL.
	l5 = map.nodes()[4]
	before = map.scroll_offset()
	await _finger(_center_of(l5), true)
	var held: bool = l5.is_pressed()
	await _cancel_finger(_center_of(l5))
	_c("ACTION_CANCEL (basış ulaştı → iptal edilen bırakış): level yok, kamera aynı", held and _chosen == [5, 5, 4]
		and _main._board == null and is_equal_approx(map.scroll_offset(), before))
	# 7) sürükle → iptal: savurma yok.
	await _finger(_center_of(l5), true)
	var at: Vector2 = _center_of_canvas(l5)
	for i in 6:
		await _move(at, at + Vector2(0.0, -24.0))
		at += Vector2(0.0, -24.0)
	var dragged: bool = map.is_dragging() and absf(map.scroll_offset() - before) > 60.0
	await _cancel_finger(_screen(at))
	var after_cancel: float = map.scroll_offset()
	await _settle(20)
	_c("hızlı sürükleme (ulaştı, kamera kaydı) iptal edilince savurma yok, level yok (kamera %.0f'da kaldı)" % after_cancel,
		dragged and not map.is_flinging() and is_equal_approx(map.scroll_offset(), after_cancel) and _main._board == null)
	# 8) bayat bırakış: basılıyken ekran gizlenir (kod yolu sekme geçişi), sonra bırakılır.
	await _refocus(map)
	l5 = map.nodes()[4]
	await _finger(_center_of(l5), true)
	var pressed_before_hide: bool = l5.is_pressed()
	_main._show_tab(0)
	await _settle(2)
	await _finger(_center_of(l5), false)
	await _settle(3)
	_c("basılıyken (ulaştı) Harita gizlendi → bırakış level BAŞLATMAZ (Ana Sayfa'da kalınır)", pressed_before_hide
		and _chosen == [5, 5, 4] and _main._board == null and _main._active_tab == 0 and not map.visible)
	await _tab(1)
	# 9) sürükleme sürerken Android GERİ.
	await _finger(_screen(Vector2(600.0, 600.0)), true)
	await _move(Vector2(600.0, 600.0), Vector2(600.0, 540.0))
	_c("ön koşul: sürükleme sürüyor", map.is_dragging())
	await _back()
	_c("sürükleme sırasında GERİ → Ana Sayfa; harita jesti eylemsiz bitti", _main._active_tab == 0
		and not map.is_gesture_active() and not map.is_dragging())
	await _finger(_screen(Vector2(600.0, 540.0)), false)
	await _settle(3)
	_c("GERİ sonrası bırakış: level yok, gizli gezinme yok (Ana Sayfa'da)", _main._board == null and _main._active_tab == 0
		and _chosen == [5, 5, 4])
	await _tab(1)
	# 10) sürükleme sürerken sekme değişimi (kod yolu) ve savurma sürerken gizlenme.
	await _finger(_screen(Vector2(600.0, 600.0)), true)
	await _move(Vector2(600.0, 600.0), Vector2(600.0, 520.0))
	var dragging_before_tab: bool = map.is_dragging()
	_main._show_tab(2)
	await _settle(2)
	await _move(Vector2(600.0, 520.0), Vector2(600.0, 420.0))
	await _finger(_screen(Vector2(600.0, 420.0)), false)
	await _settle(3)
	_c("sürükleme (ulaştı) sırasında sekme değişimi: Koleksiyon önde, harita jesti bitti, level yok",
		dragging_before_tab and _main._active_tab == 2 and not map.is_gesture_active() and not map.is_flinging()
		and _main._board == null)
	await _tab(1)
	# 11) savurma: hızlı sürükle-bırak → kamera bırakıştan sonra da kayar ve sınırda durur (taşma yok).
	map.set_scroll(map.scroll_limits().y * 0.5)
	await _settle(2)
	var start: float = map.scroll_offset()
	await _flick(Vector2(560.0, 560.0), 40.0, 5)
	var released: float = map.scroll_offset()
	var flinging: bool = map.is_flinging()
	await get_tree().create_timer(1.2).timeout
	_c("savurma: bırakıştan sonra da kayar (%.0f → %.0f → %.0f), durur, sınırda kalır" % [start, released,
		map.scroll_offset()], flinging and absf(map.scroll_offset() - released) > 20.0 and not map.is_flinging()
		and map.scroll_offset() >= 0.0 and map.scroll_offset() <= map.scroll_limits().y)
	await _flick(Vector2(560.0, 900.0), -80.0, 6)
	await get_tree().create_timer(1.5).timeout
	_c("parmak yukarı güçlü savurma alt sınıra çarpar: tam sınırda durur (taşma / boşluk yok)", is_equal_approx(
		map.scroll_offset(), map.scroll_limits().y) and not map.is_flinging())
	await _flick(Vector2(560.0, 300.0), 80.0, 6)
	await get_tree().create_timer(1.5).timeout
	_c("parmak aşağı güçlü savurma: tam 0'da durur", is_zero_approx(map.scroll_offset()) and not map.is_flinging())
	# 12) bekleyip bırakma savurmaz.
	map.set_scroll(map.scroll_limits().y * 0.5)
	await _settle(2)
	await _finger(_screen(Vector2(600.0, 600.0)), true)
	await _move(Vector2(600.0, 600.0), Vector2(600.0, 520.0))
	var hold_dragging: bool = map.is_dragging()
	await get_tree().create_timer(0.2).timeout
	await _finger(_screen(Vector2(600.0, 520.0)), false)
	await _settle(2)
	_c("sürükleyip parmak durduktan sonra bırakış savurmaz", hold_dragging and not map.is_flinging())
	# Savurmayı yakalama: savurma sürerken bir düğüme dokunuş yalnız kamerayı durdurur, düğüm başlamaz.
	map.set_scroll(map.scroll_limits().y * 0.5)
	await _settle(2)
	await _flick(Vector2(560.0, 700.0), -30.0, 4)
	var was_flinging: bool = map.is_flinging()
	var catches: int = map.catch_count
	var target: MapLevelNode = map.nodes()[3]
	await _tap_at(_center_of(target))
	await _settle(3)
	_c("savurma sürerken düğüme dokunuş (yakalama): kamera durur, level BAŞLAMAZ", was_flinging and not map.is_flinging()
		and map.catch_count == catches + 1 and _main._board == null and _chosen == [5, 5, 4])
	await _tap_at(_center_of(target))
	_c("yakalamadan sonra taze dokunuş düğümü normal başlatır (tam bir level)", _chosen == [5, 5, 4, 4]
		and _main._board != null)
	await _abandon()
	# 13) kilitli düğüm: yalnız geri bildirim.
	await _refocus(map)
	var locked: MapLevelNode = map.nodes()[6]
	await _tap_at(_center_of(locked))
	_c("kilitli level 7'ye dokunuş: level yok, kilit sallanır (reject çalıştı)", _main._board == null
		and _chosen == [5, 5, 4, 4] and locked._wiggle != null and locked._wiggle.is_valid())
	# Sabit üst satır: ⭐ pill'i dokunuşu tutar (altına kayan düğüme geçmez), kamera kaymaz.
	before = map.scroll_offset()
	await _tap_at(_screen(map.stars_pill().get_global_rect().get_center()))
	_c("⭐ / Hamur pill'leri dokunuşu tutar (MOUSE_FILTER_STOP): dokunuş level başlatmaz, kamera kaymaz",
		map.stars_pill().mouse_filter == Control.MOUSE_FILTER_STOP
		and map.top_bar().pill().mouse_filter == Control.MOUSE_FILTER_STOP and _main._board == null
		and is_equal_approx(map.scroll_offset(), before))
	await _drag(map.stars_pill().get_global_rect().get_center(), Vector2(0.0, 120.0), 6)
	await _settle(30)
	_c("⭐ pill'inin üstünden başlayan sürükleme dünyayı yine kaydırır (%.0f → %.0f), level yok" % [before,
		map.scroll_offset()], absf(map.scroll_offset() - before) > 50.0 and _main._board == null)
	# Sınırın ötesine sürükleyip geri dönen parmak: kamera hemen izler (ölü parmak yolu yok).
	map.set_scroll(20.0)
	await _settle(2)
	await _finger(_screen(Vector2(600.0, 500.0)), true)
	await _move(Vector2(600.0, 500.0), Vector2(600.0, 520.0))
	await _move(Vector2(600.0, 520.0), Vector2(600.0, 720.0))
	var clamped: float = map.scroll_offset()
	await _move(Vector2(600.0, 720.0), Vector2(600.0, 660.0))
	var back: float = map.scroll_offset()
	await get_tree().create_timer(0.15).timeout
	await _finger(_screen(Vector2(600.0, 660.0)), false)
	await _settle(2)
	_c("sınırın ötesine sürüklenip geri dönülünce kamera hemen izler (0 → %.0f, 60 px parmak)" % back,
		is_zero_approx(clamped) and absf(back - 60.0) <= 1.0)
	await _refocus(map)
	# 14) masaüstü fare tekerleği.
	before = map.scroll_offset()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = _screen(Vector2(600.0, 600.0))
	wheel.global_position = wheel.position
	Input.parse_input_event(wheel)
	Input.flush_buffered_events()
	await _settle(2)
	_c("fare tekerleği kamerayı kaydırır (masaüstü), level yok", map.scroll_offset() > before and _main._board == null)
	_sections_done += 1


# --- D: MEYDAN portalı ----------------------------------------------------------------------------------------------

func _portal() -> void:
	print("-- D: MEYDAN portalı → mevcut MEYDAN OKUMA penceresi; Ana Sayfa MEYDAN; kapanış / GERİ / sahiplik")
	await _boot()
	await _tab(1)
	var map: CanvasLayer = _map()
	var portal: MapChallengePortal = map.challenge_portal()
	var sheet: CanvasLayer = _main._challenge_sheet
	_chosen.clear()
	map.level_chosen.connect(func(l: LevelData) -> void: _chosen.append(l.level_number))
	var opened: Array[int] = [0]
	sheet.opened.connect(func() -> void: opened[0] += 1)
	_c("portal görünür: 'MEYDAN', bugünün gerçek hedefi (T5), gerçek ilk başarı ödülü '+20' (sahte süre / deneme yok)",
		portal.is_visible_in_tree() and portal.label_text() == "MEYDAN" and portal.target_tier() == 5
		and portal.status_text() == "+%d" % DailyChallenge.REWARD_DOUGH
		and portal.art_texture() == DUMPLING_VISUAL.TEXTURES[4]
		and map.branch_trail().visible and map.branch_trail().is_branch())
	var portal_control: Control = portal
	_c("portal normal level değil: MapLevelNode değil, numara yok, ayrı yan yol", not (portal_control is MapLevelNode)
		and not map.nodes().any(func(n: MapLevelNode) -> bool: return n == portal_control)
		and map.branch_trail() != map.trail())
	await _tap_at(_screen(portal.global_position + portal.well_center()))
	_c("portala gerçek dokunuş → TEK mevcut MEYDAN OKUMA penceresi (level / board yok), Harita altında, kabuk gizli",
		sheet.visible and opened[0] == 1 and _chosen.is_empty() and _main._board == null and _main._active_tab == 1
		and map.visible and not _main.global_nav().visible and int(_main._challenge_origin_tab) == 1)
	await _tap_at(_screen(portal.global_position + portal.well_center()))
	_c("açıkken aynı noktaya hızlı ikinci dokunuş ikinci pencere / level açmaz (300 ms yatışma + karartma)",
		opened[0] == 1 and _chosen.is_empty() and _main._board == null)
	await _back()
	await _wait_settled()
	_c("GERİ → pencere kapanır, Harita'da kalınır (Ana Sayfa'ya kayma yok), kabuk görünür", not sheet.visible
		and _main._active_tab == 1 and map.visible and _main.global_nav().visible)
	await _tap_at(_screen(portal.plaque_rect().get_center()))
	_c("'MEYDAN' kelimesine dokunuş da portalı açar", sheet.visible and opened[0] == 2)
	sheet.close_sheet()
	await _wait_settled()
	_c("pencere kapanışı (X yolu) → Harita, kabuk görünür, level yok", not sheet.visible and _main._active_tab == 1
		and map.visible and _main.global_nav().visible and _chosen.is_empty())
	_main.open_daily_challenge()
	await _settle(2)
	_main._show_tab(0)
	await _wait_settled()
	_c("Harita'dan açılan pencere başka ekrana geçişte kapanır", not sheet.visible and _main._active_tab == 0)
	await _tab(1)
	# Portal üstünden başlayan sürükleme pencere açmaz.
	var drags: int = map.drag_count
	await _drag(_center_of_canvas(portal), Vector2(0.0, -120.0), 8)
	await _settle(3)
	_c("portalın üstünden başlayan sürükleme pencere açmaz, kamera kayar", not sheet.visible
		and map.drag_count == drags + 1)
	# BAŞLA → mevcut meydan okuma round'u; çıkış mevcut kuralla Ana Sayfa'ya (TASK/063 merkezi değişmedi).
	await _refocus(map)
	await _tap_at(_screen(portal.global_position + portal.well_center()))
	_c("ön koşul: pencere açık", sheet.visible)
	sheet.start_requested.emit(DailyChallenge.current_day())
	await _wait_settled()
	_c("BAŞLA → mevcut meydan okuma round'u (normal level değil)", _main._board != null
		and _main.is_daily_challenge_round() and _chosen.is_empty())
	_main.abandon_run()
	await _wait_settled()
	_c("meydan okumadan çıkış mevcut kuralla Ana Sayfa'ya (değişmedi)", _main._board == null and _main._active_tab == 0)
	# Tamamlanmış gün: ✓ ve pencere tamamlandı görünümüyle açılır (BAŞLA yok).
	await _boot({"daily_challenge": {"version": 1, "completed_day_key": THU}})
	await _tab(1)
	map = _map()
	portal = map.challenge_portal()
	sheet = _main._challenge_sheet
	_c("bugün tamamlandı: portal ✓ (nane), '+20' yok", portal.status_text() == "✓" and portal.is_completed())
	await _tap_at(_screen(portal.global_position + portal.well_center()))
	_c("tamamlanmış günde portal pencereyi tamamlandı görünümüyle açar, round yok", sheet.visible
		and bool(sheet.view()["completed"]) and _main._board == null)
	await _back()
	await _wait_settled()
	# Ana Sayfa MEYDAN girişi geçerli kalır.
	await _boot()
	await _tab(0)
	var home: CanvasLayer = _main._screens[0]
	sheet = _main._challenge_sheet
	await _tap_at(_center_of(home.challenge_button()))
	_c("Ana Sayfa MEYDAN karosu aynı pencereyi açar (sahibi Ana Sayfa)", sheet.visible and _main._active_tab == 0
		and int(_main._challenge_origin_tab) == 0)
	await _back()
	await _wait_settled()
	_c("Ana Sayfa'dan açılan pencere GERİ ile kapanır, Ana Sayfa'da kalınır", not sheet.visible and _main._active_tab == 0
		and _main.global_nav().visible)
	# Harita öndeyken gün döner (öne dönüş): portal yalnız okuyarak yeni günün gerçek hedefine geçer (Cuma → T6).
	await _tab(1)
	map = _map()
	DailyRewards.clock_override = "2026-10-02"
	_main._notification(NOTIFICATION_APPLICATION_RESUMED)
	await _settle(2)
	_c("Harita öndeyken gün dönümü (öne dönüş): portal yeni günün gerçek hedefi T6 + '+20'",
		map.challenge_portal().target_tier() == 6 and map.challenge_portal().status_text() == "+20")
	DailyRewards.clock_override = THU
	# Gün gerçeği / onboarding yokken portal gizli (Ana Sayfa karosuyla aynı kural).
	SaveManager.data["onboarding_completed"] = false
	map.refresh_challenge()
	_c("onboarding bitmemişse portal ve yan yol gizli", not map.challenge_portal().visible
		and not map.branch_trail().visible)
	SaveManager.data["onboarding_completed"] = true
	map.refresh_challenge()
	_c("onboarding geri → portal yeniden görünür", map.challenge_portal().visible and map.branch_trail().visible)
	_sections_done += 1


# --- E: kayıt -------------------------------------------------------------------------------------------------------

func _save_untouched() -> void:
	print("-- E: Harita'da gezinme / kaydırma / portal kayda yazmaz")
	await _boot()
	await _tab(1)
	var map: CanvasLayer = _map()
	var before: Dictionary = _test_family()
	await _drag(Vector2(600.0, 500.0), Vector2(0.0, 200.0), 8)
	await _flick(Vector2(600.0, 700.0), -50.0, 5)
	await get_tree().create_timer(0.8).timeout
	map.set_scroll(0.0)
	map.refresh()
	await _tab(0)
	await _tab(1)
	await _tap_at(_center_of(map.nodes()[7]))
	await _tap_at(_screen(map.challenge_portal().global_position + map.challenge_portal().well_center()))
	var sheet_opened: bool = _main._challenge_sheet.visible
	await _back()
	await _wait_settled()
	_c("test kaydı bayt-aynı (sürükleme, savurma, tazeleme, sekme girişi, kilitli dokunuş, portal aç / kapat)",
		sheet_opened and not _main._challenge_sheet.visible and _test_family() == before)
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/level_select.gd") \
		+ FileAccess.get_file_as_string("res://scripts/ui/map_challenge_portal.gd")
	_c("level_select / portal kayda yazmaz (save_game / complete_ / record_ / add_dough / set_ yok)",
		not src.contains("save_game(") and not src.contains("complete_daily_challenge(")
		and not src.contains("record_stars(") and not src.contains("add_dough(") and not src.contains("SaveManager.data["))
	_sections_done += 1


# --- F: animasyon ---------------------------------------------------------------------------------------------------

func _animation() -> void:
	print("-- F: giriş / açılış animasyonu ve kamera süzülmesi")
	await _boot({"highest_level_unlocked": 4, "level_stars": {"1": 3, "2": 3, "3": 2}})
	await _tab(1)
	var map: CanvasLayer = _map()
	_main._show_tab(0)
	await _wait_settled()
	_main._show_tab(1)
	await _settle(2)
	var mid_node: float = map._node_layer.modulate.a
	var mid_portal: float = map._portal_layer.modulate.a
	await _wait_settled()
	_c("giriş: düğüm ve portal katmanı solarak gelir (bir kare sonra alfa %.2f / %.2f < 1, sonra 1)" % [mid_node,
		mid_portal], mid_node < 0.99 and mid_portal < 0.99 and is_equal_approx(map._node_layer.modulate.a, 1.0)
		and is_equal_approx(map._portal_layer.modulate.a, 1.0))
	SaveManager.data["highest_level_unlocked"] = 5
	SaveManager.data["level_stars"] = {"1": 3, "2": 3, "3": 2, "4": 2}
	map.refresh()
	await _settle(2)
	var gliding: bool = map._scroll_running()
	_c("yeni açılan level 5: açılış animasyonu + kamera süzülmesi başladı, odak level 5", map._unlock_playing
		and gliding and map.focus_node() == map.nodes()[4])
	await get_tree().create_timer(1.0).timeout
	_c("~0.7 s sonra: animasyon bitti, kamera level 5'in odak konumunda, düğüm açık bantta, patika 4 sıcak segment",
		not map._unlock_playing and not map._scroll_running()
		and _near(map.scroll_offset(), map.focus_scroll()) and _in_band(map, _hit(map.nodes()[4]))
		and map.trail().done_segments() == 4)
	# Süzülme sırasında dokunuş süzülmeyi durdurur (kamera oyuncunun).
	SaveManager.data["highest_level_unlocked"] = 6
	SaveManager.data["level_stars"] = {"1": 3, "2": 3, "3": 2, "4": 2, "5": 1}
	map.refresh()
	await _settle(2)
	await _finger(_screen(Vector2(620.0, 600.0)), true)
	var held: float = map.scroll_offset()
	await _settle(4)
	_c("süzülme sırasında basış süzülmeyi durdurur", not map._scroll_running() and is_equal_approx(map.scroll_offset(),
		held))
	await _finger(_screen(Vector2(620.0, 600.0)), false)
	await _settle(2)
	_c("tazeleme canlı tween'leri öldürür (serbest düğüme bağlı callback yok)", map._unlock_tweens.size() <= 2)
	# Açılış animasyonu sürerken harita gizlenirse (OYNA'ya hızlı dokunuş / sekme) animasyon ve sesi sürmez.
	SaveManager.data["highest_level_unlocked"] = 7
	SaveManager.data["level_stars"] = {"1": 3, "2": 3, "3": 2, "4": 2, "5": 1, "6": 2}
	map.refresh()
	await _settle(2)
	var playing: bool = map._unlock_playing
	_main._show_tab(0)
	await _settle(2)
	_c("açılış animasyonu sürerken gizlenen harita animasyonu durdurur (canlı açılış tween'i kalmaz)", playing
		and not map._unlock_playing and map._unlock_tweens.is_empty())
	_sections_done += 1


# --- G: sözleşme ----------------------------------------------------------------------------------------------------

func _contract() -> void:
	print("-- G: sahiplik + text-light + kapsam")
	await _boot()
	await _tab(1)
	var map: CanvasLayer = _map()
	var owned: bool = true
	for target in _all_targets(map):
		owned = owned and target.has_meta(&"gesture_guard") and target.mouse_filter == Control.MOUSE_FILTER_PASS
	_c("11 düğüm + portal GestureGuard sahipli (TASK/055) ve PASS (kaydırma üstlerinden başlar)", owned)
	_c("kayan dünya jestin sahibi (World STOP), kırpma tepsinin altına kadar", map.world_layer().mouse_filter
		== Control.MOUSE_FILTER_STOP)
	var texts: PackedStringArray = PackedStringArray()
	var wordy: String = ""
	for label: Label in map.find_children("*", "Label", true, false):
		if not label.is_visible_in_tree() or label.text.is_empty():
			continue
		texts.append(label.text)
		var words: int = 0
		for token in label.text.split(" ", false):
			# Rakamla başlayan belirteç sayıdır ("10'U" — ekli sayı); "!" gibi tek karakter sayılmaz.
			if not token.left(1).is_valid_int() and token.length() > 1:
				words += 1
		if words > 1:
			wordy += " '%s'" % label.text
	_c("text-light: Harita'nın görünen her yazısı ≤ 1 kelime (+ sayı)%s — %s" % [wordy, ", ".join(texts)],
		wordy.is_empty())
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/level_select.gd")
	_c("eski dikey sıkıştırma yolu yok (MIN_SQUASH / atlas kırpması / _fit_pass)", not src.contains("MIN_SQUASH")
		and not src.contains("_fit_pass") and not src.contains("atlas.region = Rect2((MAP_SIZE.x"))
	_c("geri oku / home_requested yok (TASK/057)", not src.contains("home_requested") and not src.contains("back_button()")
		and map.top_bar().back_button() == null)
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_c("Harita portalı Main'in mevcut yolu (open_daily_challenge) — yeni Meydan Okuma merkezi yok",
		main_src.contains("select.challenge_requested.connect(open_daily_challenge)")
		and not FileAccess.file_exists("res://scripts/ui/challenge_hub.gd"))
	_sections_done += 1


# --- Yardımcılar ----------------------------------------------------------------------------------------------------

## Şu anki kamerada hiçbir düğüm (kilit rozeti dahil) / plaka / portal görsel dikdörtgeni üst satır pill'leriyle kesişmiyor.
func _pills_clear(map: CanvasLayer) -> bool:
	var pills: Array[Rect2] = [map.top_bar().pill().get_global_rect(), map.stars_pill().get_global_rect()]
	for target in _all_targets(map):
		var rect: Rect2 = _hit(target)
		if target is MapLevelNode:
			var rise: float = (target as MapLevelNode).diameter() * map.ENDLESS_LOCK_RISE
			rect.position.y -= rise
			rect.size.y += rise
		for pill in pills:
			if rect.intersects(pill):
				print("    pill altında: ", target.name, " ", rect, " ∩ ", pill)
				return false
	return true


func _near(a: float, b: float) -> bool:
	return absf(a - b) <= 0.5


func _map() -> CanvasLayer:
	return _main._screens[1]


func _stars(count: int) -> Dictionary:
	var out: Dictionary = {}
	for i in count:
		out[str(i + 1)] = 3
	return out


func _refocus(map: CanvasLayer) -> void:
	map.set_scroll(map.focus_scroll())
	await _settle(2)


func _abandon() -> void:
	_main.abandon_run()
	await _wait_settled()


func _fixture(extra: Dictionary = {}) -> Dictionary:
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 3},
		"endless_high_score": 0, "dough": 1240, "total_merges": 40, "merges_since_bonus_chest": 10,
		"unlocked_skins": ["common_01"], "profile_showcase": [],
		"powerups": {"bomb": 0, "upgrade": 2, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "", "daily_streak": 3,
		"last_login_date": Time.get_date_string_from_system(), "age_ad_band": "ADULT", "next_age_transition_date": "",
		"player_meta_version": 1, "player_xp": 400, "total_rounds_played": 12, "highest_tier_created": 4,
		"unlocked_achievements": [], "daily_challenge": {"version": 1, "completed_day_key": ""},
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
	await _wait_settled()


func _tab(index: int) -> void:
	_main._show_tab(index)
	await _wait_settled()


func _touch_event(pos: Vector2, pressed: bool, index: int = 0) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = pos
	touch.pressed = pressed
	return touch


func _finger(pos: Vector2, pressed: bool) -> void:
	Input.parse_input_event(_touch_event(pos, pressed))
	Input.flush_buffered_events()
	await get_tree().process_frame


func _cancel_finger(pos: Vector2) -> void:
	var cancel := _touch_event(pos, false)
	cancel.canceled = true
	Input.parse_input_event(cancel)
	Input.flush_buffered_events()
	await _settle(2)


## Parmak sürüklemesi (tuval koordinatı) — tek adım.
func _move(from: Vector2, to: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = _screen(to)
	drag.relative = _screen(to) - _screen(from)
	drag.velocity = Vector2.ZERO
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	await get_tree().process_frame


## Bas → `delta` kadar `steps` adımda sürükle → (bekle) → bırak. Tuval koordinatı.
func _drag(from: Vector2, delta: Vector2, steps: int) -> void:
	await _finger(_screen(from), true)
	var at: Vector2 = from
	for i in steps:
		var next: Vector2 = from + delta * float(i + 1) / float(steps)
		await _move(at, next)
		at = next
	await get_tree().create_timer(0.15).timeout
	await _finger(_screen(at), false)


## Hızlı sürükle-bırak (savurma): her karede `step` px, beklemeden bırak.
func _flick(from: Vector2, step: float, steps: int) -> void:
	await _finger(_screen(from), true)
	var at: Vector2 = from
	for i in steps:
		var next: Vector2 = at + Vector2(0.0, step)
		await _move(at, next)
		at = next
	await _finger(_screen(at), false)


func _tap_at(pos: Vector2) -> void:
	await _finger(pos, true)
	await _finger(pos, false)
	await _settle(3)


## Android geri (Main'in 250 ms debounce'u gerçek saatle).
func _back() -> void:
	var gap: int = maxi(_last_back_msec + BACK_GAP_MSEC, int(_main.get("_last_back_msec")) + BACK_GAP_MSEC) \
		- Time.get_ticks_msec()
	if gap > 0:
		await get_tree().create_timer(float(gap) / 1000.0).timeout
	_last_back_msec = Time.get_ticks_msec()
	_notify_tree(get_tree().root, NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(1)


func _notify_tree(node: Node, what: int) -> void:
	node.notification(what)
	var i: int = 0
	while i < node.get_child_count(true):
		var child: Node = node.get_child(i, true)
		if not (child is Window):
			_notify_tree(child, what)
		i += 1


func _screen(canvas: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * canvas


func _center_of_canvas(control: Control) -> Vector2:
	if control is MapLevelNode:
		return (control as MapLevelNode).body_center()
	return control.get_global_rect().get_center()


func _center_of(control: Control) -> Vector2:
	return _screen(_center_of_canvas(control))


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


func _test_family() -> Dictionary:
	var out: Dictionary = {}
	for p: String in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		out[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null
	return out


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for p: String in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null
	return out
