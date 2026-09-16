extends Node
## Harita — production yolculuk ekranı (M8.6-04) regresyon testi. Headless,
## kaydı byte-identical geri koyar.
##
##   godot --headless --audio-driver Dummy --path . res://tools/map_ui_test.tscn
##
## Kontroller: veri/ilerleme (10 level + Sonsuz; üç kayıt durumunda düğüm
## durumları kanonik SaveManager verisinden; Sonsuz kuralı; yıldızlar);
## rotalar (geri → Ana Sayfa, Android geri → Ana Sayfa, Hamur "+" → Mağaza,
## sıradaki düğüm → kanonik level başlangıcı, kilitli başlamaz, Sonsuz
## yalnız açıkken); görsel yapı (tek dünya zemini, dashboard kartı / sekme
## çubuğu yok, sıradaki düğüm daha güçlü, dokunma ≥ 48, üst satırla ve
## birbirleriyle çakışma yok, güvenli alanda); dört pencere + A36 payı;
## açılış animasyonu; kayıt dosyası değişmez; kaynak hijyeni.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const VIEWS: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(720, 1560),
	Vector2i(540, 960), Vector2i(1080, 2340)]
## A36 punch-hole: 92 px fiziksel / 1.5 = 61 tuval px (M8.6-02 cihaz kapısı).
const A36_SAFE_TOP: float = 61.0
const RUNTIME_FILES: Array[String] = [
	"res://scripts/ui/level_select.gd", "res://scripts/ui/map_level_node.gd",
	"res://scripts/ui/map_trail.gd", "res://scripts/ui/screen_top_bar.gd",
	"res://scenes/ui/level_select.tscn", "res://assets/visual/ui_theme.tres",
]
const FORBIDDEN: Array[String] = ["_visual_source", "layerlab_spike", "layerlab_casual_game", "unitypackage"]
const MAP_VARIATIONS: Array[StringName] = [&"ButtonMapNode", &"ButtonMapNodeLocked", &"ButtonMapEndless", &"PanelMapPlaque"]

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
	var save_path: String = SaveManager.SAVE_PATH
	_had_save = FileAccess.file_exists(save_path)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(save_path)
	# Günlük ödül bugün alınmış gibi: main._ready kayda yazmasın.
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	_apply_mid()

	get_window().size = Vector2i(720, 1000)
	await get_tree().process_frame
	await _resize(VIEWS[0])
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_main._daily.visible = false
	var map: CanvasLayer = _main._screens[1]
	var tabs: CanvasLayer = _main._tabs
	var theme: Theme = ThemeDB.get_project_theme()

	print("-- tema")
	for type in MAP_VARIATIONS:
		_c("%s variation'ı var" % type, theme.get_type_list().has(type))

	print("-- yapı")
	_main._show_tab(1)
	await get_tree().process_frame
	await get_tree().process_frame
	var levels: Array[LevelData] = LevelLibrary.load_levels()
	_c("tam 10 normal level, 10 düğüm", levels.size() == 10 and map.nodes().size() == 10)
	_c("Sonsuz düğümü var ve Sonsuz türünde", map.endless_node() != null and map.endless_node().is_endless())
	_c("11 düğüm de MapLevelNode (tek bileşen)", _count_class(map, "MapLevelNode") == 11)
	_c("düğümler grid değil (x farklı, y aşağıdan yukarı azalır)", map.nodes()[0].position.x != map.nodes()[1].position.x
		and map.nodes()[0].position.y > map.nodes()[9].position.y and map.nodes()[9].position.y > map.endless_node().position.y)
	_c("tek dünya zemini (map_background) — KEEP_ASPECT_COVERED", _count_texture(map, "map_background") == 1
		and map.map_art().stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	_c("MapTrail var ve 11 nokta bağlıyor", _count_class(map, "MapTrail") == 1 and map.trail().point_count() == 11)
	_c("Home dashboard parçası yok (kart / HomeFeatureButton / ButtonCard / PanelCard)", _count_class(map, "HomeFeatureButton") == 0
		and _count_variation(map, &"ButtonCard") == 0 and _count_variation(map, &"PanelCard") == 0
		and _count_variation(map, &"PanelModuleCard") == 0)
	_c("eski düz çip / başlık yok (ChipPanel, ResourcePill, ScreenTitle, IconButton)", _count_variation(map, &"ChipPanel") == 0
		and _count_variation(map, &"ResourcePill") == 0 and _count_variation(map, &"ScreenTitle") == 0
		and _count_variation(map, &"IconButton") == 0)
	_c("eski tam ekran karartma (Scrim) yok", map.get_node_or_null("Scrim") == null and map.get_node_or_null("Root/Scrim") == null)
	var bar: ScreenTopBar = map.top_bar()
	_c("üst satır ScreenTopBar: geri ButtonHomeIcon (oturmuş), Hamur PanelHomePill + ButtonHomeAdd", bar != null
		and bar.back_button().theme_type_variation == &"ButtonHomeIcon" and bar.back_button().has_meta(&"face")
		and (bar.pill().get_meta(&"pill") as PanelContainer).theme_type_variation == &"PanelHomePill"
		and bar.add_button().theme_type_variation == &"ButtonHomeAdd")
	_c("başlık 'HARİTA' (noktalı İ) pembe HeaderRibbon", bar.title_text() == "HARİTA"
		and bar.title_plate().theme_type_variation == &"HeaderRibbon")
	_c("Harita'da sekme çubuğu GİZLİ", not tabs.visible)
	_main._show_tab(2)
	_c("Koleksiyon'da çubuk hâlâ görünür (kendi işine kadar)", tabs.visible)
	_main._show_tab(1)
	await get_tree().process_frame

	print("-- veri (orta oyuncu: 1-3 tamam, 4 sıradaki)")
	_refresh(map)
	await get_tree().process_frame
	_check_states(map, 4, {"1": 2, "2": 3, "3": 3})
	_c("Sonsuz kilitli, plaka 'Level 10'u bitir' (kanonik)", map.endless_node().is_locked()
		and map.endless_node().state() == MapLevelNode.State.ENDLESS_LOCKED
		and map.endless_node().plaque_text() == "Level 10'u bitir")
	_c("odak = level 4, hale görünür, plaka 'OYNA'", map.focus_node() == map.nodes()[3]
		and map.nodes()[3].is_focused() and map.nodes()[3]._halo.visible and map.nodes()[3].plaque_text() == "OYNA")
	_c("yıldızlar kayıttan: 2/3/3", map.nodes()[0].stars() == 2 and map.nodes()[1].stars() == 3 and map.nodes()[2].stars() == 3)
	_c("sıradaki düğüm ×1.14 daha büyük; kilitli/tamamlanmış aynı taban", map.nodes()[3].diameter() > map.nodes()[2].diameter() * 1.1
		and map.nodes()[4].diameter() <= map.nodes()[2].diameter())
	_c("düğüm numaraları 1..10", _numbers_ok(map))
	_c("Hamur pill'i kayıttaki değeri gösteriyor (335)", (bar.pill().get_meta(&"value_label") as Label).text == "335")
	_c("patika: 3 segment sıcak (highest 4 → 3)", map.trail().done_segments() == 3)

	print("-- veri (yeni oyuncu)")
	_apply_fresh()
	_refresh(map)
	await get_tree().process_frame
	_check_states(map, 1, {})
	_c("odak level 1 (OYNA), Sonsuz kilitli, 0 sıcak segment", map.focus_node() == map.nodes()[0]
		and map.endless_node().is_locked() and map.trail().done_segments() == 0)

	print("-- veri (her şey bitmiş, Sonsuz açık)")
	_apply_endless(12480)
	_refresh(map)
	await get_tree().process_frame
	_check_states(map, 11, _all_stars())
	_c("Sonsuz açık (is_endless_unlocked), altın ButtonMapEndless, plaka 'Rekor 12 480'", not map.endless_node().is_locked()
		and map.endless_node().theme_type_variation == &"ButtonMapEndless"
		and map.endless_node().plaque_text() == "Rekor 12 480")
	_c("odak Sonsuz'da (hale)", map.focus_node() == map.endless_node() and map.endless_node().is_focused())
	_c("patika: 10 segment sıcak", map.trail().done_segments() == 10)
	_apply_endless(0)
	_refresh(map)
	await get_tree().process_frame
	_c("rekor yokken plaka 'Rekor bekliyor'", map.endless_node().plaque_text() == "Rekor bekliyor")

	print("-- Sonsuz kuralı kayıttan (highest 10 → kilitli, 11 → açık)")
	SaveManager.data["highest_level_unlocked"] = 10
	var nine_stars: Dictionary = _all_stars()
	nine_stars.erase("10")
	SaveManager.data["level_stars"] = nine_stars
	_refresh(map)
	await get_tree().process_frame
	_c("highest 10: level 10 sıradaki, Sonsuz kilitli", map.nodes()[9].state() == MapLevelNode.State.CURRENT
		and map.endless_node().is_locked() and not SaveManager.is_endless_unlocked(10))
	SaveManager.data["highest_level_unlocked"] = 11
	_refresh(map)
	await get_tree().process_frame
	_c("highest 11: Sonsuz açık", not map.endless_node().is_locked() and SaveManager.is_endless_unlocked(10))

	print("-- düğüm bileşeni")
	var probe := MapLevelNode.new()
	add_child(probe)
	probe.setup_level(7, MapLevelNode.State.LOCKED, 0)
	_c("kilitli: ButtonMapNodeLocked, kilit görünür, plaka yok, yıldız yok", probe.is_locked()
		and probe.theme_type_variation == &"ButtonMapNodeLocked" and probe._lock.visible
		and probe.plaque_text().is_empty() and not probe._stars_row.visible)
	probe.setup_level(7, MapLevelNode.State.COMPLETED, 2)
	_c("tamamlanmış: ButtonMapNode, 2 dolu yıldız, kilit yok", not probe.is_locked()
		and probe.theme_type_variation == &"ButtonMapNode" and probe._stars_row.visible and probe.stars() == 2
		and probe._star_rects[1].texture == probe.STAR_ART and probe._star_rects[2].texture == probe.STAR_EMPTY_ART
		and not probe._lock.visible)
	probe.setup_level(7, MapLevelNode.State.CURRENT, 0)
	_c("sıradaki: plaka OYNA, altın halka", probe.plaque_text() == "OYNA" and probe._ring.self_modulate == UiTokens.GOLD)
	probe.set_diameter(72.0)
	_c("çap 72 → buton 72×76 (≥ 48), pivot merkezde", probe.size == Vector2(72.0, 76.0) and probe.pivot_offset == Vector2(36.0, 36.0))
	probe.set_diameter(20.0)
	_c("çap dokunma altına inemez (≥ 48)", probe.size.x >= 48.0)
	probe.setup_endless(false, 0, "Level 10'u bitir")
	_c("Sonsuz kilitli: 116 px, kilit + plaka şartı", probe.diameter() == 116.0 and probe.is_locked()
		and probe._plaque_lock.visible and probe.plaque_text() == "Level 10'u bitir")
	probe.setup_endless(true, 980, "Level 10'u bitir")
	_c("Sonsuz açık: taç görünür, 'SONSUZ' yazısı, 'Rekor 980', pırıltılar", probe._crown.visible
		and probe._caption.visible and probe._caption.text == "SONSUZ" and probe.plaque_text() == "Rekor 980"
		and probe._sparkles[0].visible)
	_c("basış animasyonu bağlı (UiMotion), sesi kendisi yönetir", probe.has_meta(&"ui_motion_press")
		and not probe.has_meta(&"ui_motion_tap"))
	probe.queue_free()

	print("-- rotalar")
	_apply_mid()
	_main._show_tab(1)
	_refresh(map)
	await get_tree().process_frame
	bar.back_button().pressed.emit()
	_c("geri → Ana Sayfa (sekme çubuğu gizli)", _main._active_tab == 0 and _main._screens[0].visible and not tabs.visible)
	_main._show_tab(1)
	bar.add_button().pressed.emit()
	_c("Hamur '+' → Mağaza", _main._active_tab == 3 and _main._screens[3].visible)
	_main._show_tab(1)
	await get_tree().process_frame
	var chosen: Array = []
	map.level_chosen.connect(func(l: LevelData) -> void: chosen.append(l.level_number))
	map.nodes()[6].pressed.emit()
	await get_tree().process_frame
	_c("kilitli level 7'ye dokunuş: level_chosen YOK, board YOK, harita açık", chosen.is_empty()
		and _main._board == null and _main._active_tab == 1 and map.visible)
	map.endless_node().pressed.emit()
	await get_tree().process_frame
	_c("kilitli Sonsuz'a dokunuş: başlamaz", chosen.is_empty() and _main._board == null)
	map.nodes()[3].pressed.emit()
	await get_tree().process_frame
	_c("sıradaki level 4 → level_chosen(4) → kanonik başlangıç (board kuruldu, kabuk gizli)", chosen == [4]
		and _main._board != null and is_instance_valid(_main._board) and _main._current_level.level_number == 4
		and not map.visible and not tabs.visible)
	_main.abandon_run()
	await get_tree().process_frame
	_c("round terk → Harita'ya dönüş, board yok", _main._board == null and _main._active_tab == 1 and map.visible)
	map.nodes()[1].pressed.emit()
	await get_tree().process_frame
	_c("tamamlanmış level 2 tekrar oynanabilir (mevcut kural)", chosen == [4, 2] and _main._board != null)
	_main.abandon_run()
	await get_tree().process_frame
	_apply_endless(0)
	_refresh(map)
	await get_tree().process_frame
	map.endless_node().pressed.emit()
	await get_tree().process_frame
	_c("açık Sonsuz → level_chosen(endless) → kanonik Sonsuz başlangıcı", _main._board != null
		and _main._current_level != null and _main._current_level.is_endless)
	_main.abandon_run()
	await get_tree().process_frame
	_apply_mid()
	_refresh(map)
	await get_tree().process_frame

	print("-- Android geri")
	_main._show_tab(1)
	_main._last_back_msec = -1000
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("Harita'da geri → Ana Sayfa (uygulama kapanmaz)", _main._active_tab == 0 and _main._screens[0].visible)
	_main._show_tab(1)
	_main._last_back_msec = -1000
	_main.open_settings()
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("Harita'da ayarlar açıkken geri → ayarlar kapanır, Harita kalır", not _main._settings.visible and _main._active_tab == 1)
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_c("gameplay geri tuşu politikası aynen (debounce + quit_on_go_back=false)", main_src.contains("quit_on_go_back = false")
		and main_src.contains("BACK_DEBOUNCE_MSEC"))

	print("-- açılış animasyonu")
	_apply_mid()
	_main._show_tab(1)
	_refresh(map)
	await get_tree().process_frame
	SaveManager.data["highest_level_unlocked"] = 5
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3, "4": 3}
	map.refresh()
	await get_tree().process_frame
	_c("tazeleme: highest 4→5 açılış animasyonu başladı, odak level 5", map._unlock_playing
		and map.focus_node() == map.nodes()[4] and map.nodes()[3].state() == MapLevelNode.State.COMPLETED)
	await get_tree().create_timer(1.0).timeout
	_c("~0.7 s sonra bitti, düğüm ölçeği ~1 (nefes ≤ %1.5), patika 4 sıcak segment", not map._unlock_playing
		and map.nodes()[4].scale.x >= 0.99 and map.nodes()[4].scale.x <= 1.02 and map.trail().done_segments() == 4)

	print("-- yerleşim")
	_apply_mid()
	for view in VIEWS:
		await _resize(view)
		_main._show_tab(1)
		_refresh(map)
		await get_tree().process_frame
		await get_tree().process_frame
		_check_layout(map, get_viewport().get_visible_rect().size, 0.0, "%dx%d" % [view.x, view.y])
	await _resize(VIEWS[1])
	map._layout_with_safe_top(A36_SAFE_TOP)
	await get_tree().process_frame
	await get_tree().process_frame
	_check_layout(map, Vector2(VIEWS[1]), A36_SAFE_TOP, "720x1560")
	_c("A36: dünya punch-hole altından başlar (world.y = 61)", is_equal_approx(map.world_rect().position.y, A36_SAFE_TOP))
	map._layout_with_safe_top(-1.0)
	await _resize(VIEWS[0])
	_apply_endless(12480)
	_refresh(map)
	await get_tree().process_frame
	await get_tree().process_frame
	_check_layout(map, Vector2(VIEWS[0]), 0.0, "720x1280 sonsuz açık")

	print("-- kayıt")
	_restore_save_file()
	var file_before: PackedByteArray = FileAccess.get_file_as_bytes(save_path) \
		if FileAccess.file_exists(save_path) else PackedByteArray()
	_apply_mid()
	for i in 3:
		_main._show_tab(1)
		_refresh(map)
		await get_tree().process_frame
	map.nodes()[6].pressed.emit()
	map.endless_node().pressed.emit()
	await get_tree().process_frame
	var file_after: PackedByteArray = FileAccess.get_file_as_bytes(save_path) \
		if FileAccess.file_exists(save_path) else PackedByteArray()
	_c("Harita çizimi/yenilemesi/kilitli dokunuş kayıt dosyasını değiştirmedi", file_before == file_after)
	var select_src: String = FileAccess.get_file_as_string("res://scripts/ui/level_select.gd")
	var node_src: String = FileAccess.get_file_as_string("res://scripts/ui/map_level_node.gd")
	_c("level_select / map_level_node kayda yazmıyor (save_game / complete_level / record_stars / add_dough)",
		not select_src.contains("save_game(") and not select_src.contains("complete_level(")
		and not select_src.contains("record_stars(") and not select_src.contains("add_dough(")
		and not node_src.contains("SaveManager"))
	_c("unlock kuralı kanonik: highest_level_unlocked + is_endless_unlocked (özel kural yok)",
		select_src.contains("SaveManager.highest_level_unlocked()") and select_src.contains("SaveManager.is_endless_unlocked(")
		and select_src.contains("SaveManager.stars_for_level("))

	print("-- kaynak hijyeni")
	var clean: bool = true
	for path in RUNTIME_FILES:
		var text: String = FileAccess.get_file_as_string(path)
		for word in FORBIDDEN:
			if text.contains(word):
				clean = false
				print("    yasak referans: ", path, " -> ", word)
	_c("runtime dosyalarında _visual_source / spike referansı yok", clean)
	_c("sahte sistem yok (IAP / reklam / etkinlik / lider tablosu metni)", not select_src.to_lower().contains("starter")
		and not select_src.contains("Reklamsız") and not select_src.to_lower().contains("leaderboard")
		and not node_src.to_lower().contains("iap"))

	_main.queue_free()
	await get_tree().process_frame
	SaveManager.data = _saved
	_restore_save_file()
	print("=== SONUC: %d/%d kontrol, %d kaldi ===" % [_checks - _fails, _checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


# --- Yardımcılar ---

## Tazeleme — açılış animasyonu OLMADAN (test kayıt durumunu keyfî sırayla
## değiştirir; animasyon yalnız kendi bölümünde ölçülür).
func _refresh(map: CanvasLayer) -> void:
	map._last_unlocked = -1
	map.refresh()


func _restore_save_file() -> void:
	if not _had_save:
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()


func _resize(view: Vector2i) -> void:
	get_window().size = view
	await get_tree().process_frame
	await get_tree().process_frame


func _apply_mid() -> void:
	SaveManager.data["highest_level_unlocked"] = 4
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3}
	SaveManager.data["dough"] = 335
	SaveManager.data["endless_high_score"] = 0
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()


func _apply_fresh() -> void:
	SaveManager.data["highest_level_unlocked"] = 1
	SaveManager.data["level_stars"] = {}
	SaveManager.data["dough"] = 0
	SaveManager.data["endless_high_score"] = 0


func _apply_endless(record: int) -> void:
	SaveManager.data["highest_level_unlocked"] = LevelLibrary.load_levels().size() + 1
	SaveManager.data["level_stars"] = _all_stars()
	SaveManager.data["dough"] = 99999
	SaveManager.data["endless_high_score"] = record


func _all_stars() -> Dictionary:
	var stars: Dictionary = {}
	for i in LevelLibrary.load_levels().size():
		stars[str(i + 1)] = 3
	return stars


## Her düğümün durumu kanonik kayıttan türetilen beklentiyle aynı mı.
func _check_states(map: CanvasLayer, highest: int, stars: Dictionary) -> void:
	var ok: bool = true
	for i in map.nodes().size():
		var n: int = i + 1
		var node: MapLevelNode = map.nodes()[i]
		var expected: MapLevelNode.State
		if n > highest:
			expected = MapLevelNode.State.LOCKED
		elif int(stars.get(str(n), 0)) > 0:
			expected = MapLevelNode.State.COMPLETED
		else:
			expected = MapLevelNode.State.CURRENT
		if node.state() != expected or node.stars() != int(stars.get(str(n), 0)) or node.level_number() != n:
			ok = false
			print("    düğüm %d: durum %d beklenen %d, yıldız %d" % [n, node.state(), expected, node.stars()])
		if node.is_locked() != (n > highest):
			ok = false
	_c("highest %d: 11 düğümün durumu/yıldızı kayıtla birebir" % highest, ok)


func _numbers_ok(map: CanvasLayer) -> bool:
	for i in map.nodes().size():
		if map.nodes()[i].number_text() != str(i + 1):
			return false
	return map.endless_node().number_text().is_empty()


func _count_variation(root: Node, variation: StringName) -> int:
	var count: int = 0
	for node in _all_controls(root):
		if node.theme_type_variation == variation:
			count += 1
	return count


func _count_class(root: Node, klass: String) -> int:
	return root.find_children("*", klass, true, false).size()


func _count_texture(root: Node, name_part: String) -> int:
	var count: int = 0
	for node in _all_controls(root):
		var rect := node as TextureRect
		if rect != null and rect.texture != null and rect.texture.resource_path.contains(name_part):
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


## Yerleşim: bütün düğümler güvenli alanda ve ekranda, dokunma ≥ 48, düğüm
## gövdeleri birbiriyle kesişmiyor, plaka dahil görsel dikdörtgenler
## okunurluğu bozacak kadar (> 6 px) binmiyor, üst satır kontrolleri hiçbir
## düğümle kesişmiyor, sıradaki düğüm en güçlü (çap), Sonsuz görünür.
func _check_layout(map: CanvasLayer, view: Vector2, safe_top: float, window_tag: String) -> void:
	var tag: String = "%s (tuval %dx%d)%s" % [window_tag, int(view.x), int(view.y), " +A36" if safe_top > 0.0 else ""]
	var visible: Rect2 = get_viewport().get_visible_rect()
	_c("%s tuval genişliği 720" % tag, is_equal_approx(visible.size.x, 720.0) and is_equal_approx(visible.size.y, view.y))
	var all_nodes: Array[MapLevelNode] = []
	all_nodes.append_array(map.nodes())
	all_nodes.append(map.endless_node())
	var screen: Rect2 = Rect2(Vector2(0, safe_top), Vector2(720.0, view.y - safe_top))
	var bar: ScreenTopBar = map.top_bar()
	var bar_bottom: float = bar.height()
	var inside: bool = true
	var touch: bool = true
	var below_bar: bool = true
	for node in all_nodes:
		var rect: Rect2 = node.visual_rect()
		if not screen.encloses(rect):
			inside = false
			print("    ekran dışı: ", node.name, " ", rect)
		if node.size.x < 48.0 or node.size.y < 48.0:
			touch = false
		if rect.position.y < bar_bottom:
			below_bar = false
			print("    üst satıra giriyor: ", node.name, " ", rect, " bar ", bar_bottom)
	_c("%s 11 düğüm (plaka dahil) güvenli alanda" % tag, inside)
	_c("%s dokunma hedefleri ≥ 48×48" % tag, touch)
	_c("%s hiçbir düğüm üst satırın altına girmiyor" % tag, below_bar)
	var bar_controls: Array[Control] = [bar.back_button(), bar.pill(), bar.title_plate()]
	var bar_clear: bool = true
	for control in bar_controls:
		var rect: Rect2 = control.get_global_rect()
		if not screen.encloses(rect):
			bar_clear = false
			print("    üst satır ekran dışı: ", control.name, " ", rect)
		for node in all_nodes:
			if rect.intersects(node.visual_rect()):
				bar_clear = false
				print("    üst satır düğümle kesişiyor: ", control.name, " ", node.name)
	_c("%s üst satır güvenli payın altında, düğümlerle kesişmiyor" % tag, bar_clear)
	_c("%s geri butonu ve '+' ≥ 48 px" % tag, bar.back_button().size.x >= 48.0 and bar.add_button().size.x >= 48.0)
	var overlap: bool = false
	var visual_overlap: bool = false
	for i in all_nodes.size():
		for j in range(i + 1, all_nodes.size()):
			if all_nodes[i].get_global_rect().intersects(all_nodes[j].get_global_rect()):
				overlap = true
				print("    gövde çakışması: ", all_nodes[i].name, " x ", all_nodes[j].name)
			var inter: Rect2 = all_nodes[i].visual_rect().intersection(all_nodes[j].visual_rect())
			if inter.size.x > 6.0 and inter.size.y > 6.0:
				visual_overlap = true
				print("    görsel çakışma: ", all_nodes[i].name, " x ", all_nodes[j].name, " ", inter.size)
	_c("%s düğüm gövdeleri birbiriyle kesişmiyor" % tag, not overlap)
	_c("%s plaka dahil görsel çakışma yok (> 6 px)" % tag, not visual_overlap)
	var focus: MapLevelNode = map.focus_node()
	var strongest: bool = focus != null and focus.is_focused()
	if focus != null and not focus.is_endless():
		for node in map.nodes():
			if node != focus and node.diameter() >= focus.diameter():
				strongest = false
	_c("%s odak düğümü var, hale açık ve en büyük level düğümü" % tag, strongest)
	_c("%s Sonsuz görünür ve erişilebilir" % tag, map.endless_node().is_visible_in_tree()
		and screen.encloses(map.endless_node().get_global_rect()))
	_c("%s dünya zemini ekranı kaplıyor" % tag, map.map_art().get_global_rect().encloses(
		Rect2(Vector2(0, safe_top), Vector2(720.0, view.y - safe_top))))
