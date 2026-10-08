extends Node
## TASK/059 — Harita V3 görsel inceleme çekimleri. Dev aracı — oyun çalışırken kullanılmaz. `--headless` İLE
## ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn`; kayıt durumları BELLEKTE sabit vitrin oyuncuları (aynı içerik taban ve aday çekimlerinde — fark
## yalnız kod; hepsi SENTETİK, gerçek bir oyuncunun kaydı değil). Kayıt yolu `user://qa_map_v3_shots/`'a YÖNLENDİRİLİR
## (Main'in yazmaları sahibin kaydına gitmez); sahibin kayıt ailesi başta / sonda bayt bayt karşılaştırılır. Banner
## kipinde yuva yalnız bu araçta yarı saydam plakayla işaretlenir (masaüstünde gerçek banner çizilmez). Taban (`f6dcf29`,
## kaydırma yok) ve aday AYNI aracı çalıştırır: kaydırma API'si yoksa yalnız odak kareleri çekilir.
##
##   01_fresh_focus · 02_fresh_top · 03_mid_focus · 04_mid_top · 05_mid_bottom · 06_mid_scroll_half ·
##   07_done_focus · 08_done_bottom · 09_challenge_done · 10_challenge_open
##
## Kipler: varsayılan masaüstü (yuva yok) · `banner` (yuva 112) · `a36` (üst pay 61 + yuva 112) · `a36nb` (üst pay 61,
## yuva yok) · `slot=N` (yuvayı N tuval px'e zorlar — uç durum) · `zoom=Z` (yalnız aday: dünya ölçeği fizibilite
## ölçümü; dosya adına `_zZ`).
##
##   godot --path . res://tools/map_v3_shots.tscn -- <çıktı_klasörü> [GxY] [banner|a36|a36nb] [slot=N] [zoom=Z] [only=…]

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SHOT_SIZE := Vector2i(720, 1280)
const A36_SAFE_TOP: float = 61.0
const A36_BANNER_DP: int = 64
const A36_DENSITY: float = 2.625
const REDIRECT_DIR: String = "user://qa_map_v3_shots"

var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _safe_top: float = 0.0
var _banner: bool = false
var _slot_override: float = -1.0
var _zoom: float = -1.0
var _mode: String = ""
var _owner_family: Dictionary = {}
var _only: PackedStringArray = PackedStringArray()
var _main: Node2D
var _main_script: GDScript = load("res://scripts/main.gd")
var _saved_data: Dictionary = {}
var _shots: int = 0


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://map_v3_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_size = _shot_size(args)
	for arg in args:
		var a: String = String(arg)
		if a == "a36":
			_safe_top = A36_SAFE_TOP
			_banner = true
			_mode += "_a36"
		elif a == "a36nb":
			_safe_top = A36_SAFE_TOP
			_mode += "_a36nb"
		elif a == "banner":
			_banner = true
			_mode += "_banner"
		elif a.begins_with("slot="):
			_slot_override = float(a.trim_prefix("slot="))
			_banner = true
			_mode += "_slot%d" % int(_slot_override)
		elif a.begins_with("zoom="):
			_zoom = float(a.trim_prefix("zoom="))
			_mode += "_z%d" % int(round(_zoom * 100.0))
		elif a.begins_with("only="):
			_only = a.trim_prefix("only=").split(",", false)
	DisplayServer.window_set_size(_size)
	await get_tree().process_frame
	await get_tree().process_frame

	_saved_data = SaveManager.data.duplicate(true)
	_owner_family = _family_snapshot()
	DirAccess.make_dir_recursive_absolute(REDIRECT_DIR)
	SaveManager.save_path = REDIRECT_DIR + "/save.json"
	_apply_player(5, {"1": 3, "2": 3, "3": 2, "4": 3}, 0, false)

	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	fake.adaptive_height_dp = A36_BANNER_DP if _banner else 0
	# Yuva tuval px'te A36 ile aynı (112): 720 pencerede A36 yoğunluğu gerçek dışı 168 px üretirdi.
	fake.density_value = A36_DENSITY * float(_size.x) / 1080.0
	if _slot_override > 0.0:
		fake.density_value = _slot_override / float(A36_BANNER_DP) * float(_size.x) / 720.0
	await _make_main(fake)
	if _banner:
		fake.complete_consent_update(true)
		fake.complete_init()
		await _settle()
		_apply_safe_top()
	_build_banner_overlay()
	var map: CanvasLayer = _main._screens[1]
	var scrolls: bool = map.has_method("set_scroll")
	if _zoom > 0.0 and map.has_method("set_world_zoom_override"):
		map.set_world_zoom_override(_zoom)
	print("SHOT-INFO size=%s mode=%s safe_top=%d banner_slot=%d scroll_api=%s" % [str(_size), _mode, int(_safe_top),
		int(UiKit.banner_slot()), str(scrolls)])

	# A — yeni oyuncu (onboarding bitmiş): level 1 sıradaki, Sonsuz kilitli.
	_apply_player(1, {}, 0, false)
	await _show_map()
	await _capture("01_fresh_focus")
	if scrolls:
		await _scroll_edge(map, true)
		await _capture("02_fresh_top")

	# B — orta oyuncu: 1–4 tamam (gerçek yıldızlar 3/3/2/3), 5 sıradaki; meydan okuma bugün hazır.
	_apply_player(5, {"1": 3, "2": 3, "3": 2, "4": 3}, 0, false)
	await _show_map()
	await _capture("03_mid_focus")
	if scrolls:
		_print_geometry(map, "mid_focus")
		await _scroll_edge(map, true)
		await _capture("04_mid_top")
		_print_geometry(map, "mid_top")
		await _scroll_edge(map, false)
		await _capture("05_mid_bottom")
		_print_geometry(map, "mid_bottom")
		var limits: Vector2 = map.scroll_limits()
		map.set_scroll((limits.x + limits.y) * 0.5)
		await _settle()
		await _capture("06_mid_scroll_half")

	# C — her şey bitmiş: 10/10 üç yıldız, Sonsuz açık + rekor (odak Sonsuz).
	_apply_player(11, _all_stars(), 12480, false)
	await _show_map()
	await _capture("07_done_focus")
	if scrolls:
		await _scroll_edge(map, false)
		await _capture("08_done_bottom")

	# D — orta oyuncu, bugünün meydan okuması tamamlandı.
	_apply_player(5, {"1": 3, "2": 3, "3": 2, "4": 3}, 0, true)
	await _show_map()
	await _capture("09_challenge_done")

	# E — orta oyuncu: Harita'daki MEYDAN portalından açılan mevcut MEYDAN OKUMA penceresi.
	_apply_player(5, {"1": 3, "2": 3, "3": 2, "4": 3}, 0, false)
	await _show_map()
	if map.has_method("challenge_portal") and map.challenge_portal() != null:
		map.challenge_portal().pressed.emit()
		await _settle()
		await _capture("10_challenge_open")
		_main._challenge_sheet.close_sheet()
		await _settle()

	await _free_main()
	SaveManager.save_path = SaveManager.SAVE_PATH
	for p: String in [REDIRECT_DIR + "/save.json", REDIRECT_DIR + "/save.json" + SaveFile.TEMP_SUFFIX,
			REDIRECT_DIR + "/save.json" + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	DirAccess.remove_absolute(REDIRECT_DIR)
	SaveManager.data = _saved_data
	print("SHOT-OWNER-SAVE %s" % ("byte-identical" if _family_snapshot() == _owner_family else "DIFFERS"))
	print("SHOT-DONE %d -> %s" % [_shots, _out_dir])
	get_tree().quit()


func _make_main(fake: FakeAdBackend) -> void:
	_main_script.ads_backend_override = fake
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_main_script.ads_backend_override = null
	_apply_safe_top()


func _apply_safe_top() -> void:
	if _safe_top <= 0.0:
		return
	for screen in _main._screens:
		if screen.has_method("_layout_with_safe_top"):
			screen._layout_with_safe_top(_safe_top)
	if _main.has_method("global_nav"):
		_main.global_nav().relayout()


func _free_main() -> void:
	_main.queue_free()
	_main = null
	await get_tree().process_frame
	await get_tree().process_frame


## Vitrin oyuncusu (yalnız bellekte; SENTETİK): `highest` açık en yüksek level, gerçek yıldız sözlüğü, Sonsuz rekoru,
## bugünün meydan okuması tamam mı. 13+ yetişkin bandı (yaş ekranı açılmaz), günlük giriş bugün alınmış (açılış talebi
## yazmaz), günlük pencere bugün görülmüş.
func _apply_player(highest: int, stars: Dictionary, record: int, challenge_done: bool) -> void:
	var today: String = Time.get_date_string_from_system()
	SaveManager.data["last_login_date"] = today
	SaveManager.data["onboarding_completed"] = true
	SaveManager.data["onboarding_completed_day"] = ""
	SaveManager.data["highest_level_unlocked"] = highest
	SaveManager.data["level_stars"] = stars.duplicate()
	SaveManager.data["endless_high_score"] = record
	SaveManager.data["dough"] = 1240
	SaveManager.data["daily_streak"] = 3
	SaveManager.data["age_ad_band"] = "ADULT"
	SaveManager.data["next_age_transition_date"] = ""
	var day: String = DailyRewards.day_key()
	SaveManager.data["daily_rewards"] = {"day_key": day, "free_chest_claimed": true, "ad_chests_claimed": 0,
		"dough_ad_claimed": false, "popup_seen_day": day, "last_seen_day_key": day}
	SaveManager.data["daily_challenge"] = {"version": 1, "completed_day_key": ""}
	if challenge_done:
		SaveManager.data["daily_challenge"] = {"version": 1, "completed_day_key": DailyChallenge.current_day()}


func _all_stars() -> Dictionary:
	var stars: Dictionary = {}
	for i in LevelLibrary.load_levels().size():
		stars[str(i + 1)] = 3
	return stars


## Harita'yı (yeniden) GİRİŞ olarak gösterir: Main'in sekme girişi (`_show_tab` → görünür + `refresh()`).
func _show_map() -> void:
	_main._show_tab(0)
	await get_tree().process_frame
	_main._show_tab(1)
	_apply_safe_top()
	await _settle()


func _scroll_edge(map: CanvasLayer, top: bool) -> void:
	var limits: Vector2 = map.scroll_limits()
	map.set_scroll(limits.x if top else limits.y)
	await _settle()


func _print_geometry(map: CanvasLayer, tag: String) -> void:
	var limits: Vector2 = map.scroll_limits()
	print("SHOT-GEOM %s scroll=%.1f limits=[%.1f, %.1f] zoom=%.3f" % [tag, map.scroll_offset(), limits.x, limits.y,
		map.world_scale().x])


## Banner yuvası (yalnız bu araçta): yarı saydam plaka + etiket — içeriğin yuvaya göre konumu görünsün.
func _build_banner_overlay() -> void:
	var slot: float = UiKit.banner_slot()
	if slot <= 0.0:
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var view: Vector2 = get_viewport().get_visible_rect().size
	var rect := ColorRect.new()
	rect.color = Color(1.0, 1.0, 1.0, 0.16)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = Vector2(0.0, view.y - UiKit.safe_bottom(view) - slot)
	rect.size = Vector2(view.x, slot)
	layer.add_child(rect)
	var label := Label.new()
	label.text = "BANNER YUVASI %d px (yalnız çekim işareti)" % int(slot)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	label.add_theme_font_size_override("font_size", 20)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = rect.position
	label.size = rect.size
	layer.add_child(label)


func _family_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for p: String in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null
	return out


func _settle() -> void:
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame


func _shot_size(args: PackedStringArray) -> Vector2i:
	if args.size() < 2:
		return SHOT_SIZE
	var parts: PackedStringArray = args[1].split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return SHOT_SIZE
	return Vector2i(int(parts[0]), int(parts[1]))


func _tag() -> String:
	return "%dx%d%s" % [_size.x, _size.y, _mode]


func _capture(name: String) -> void:
	if not _only.is_empty() and not _only.has(name):
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var file: String = "%s_%s.png" % [name, _tag()]
	var err: int = img.save_png(_out_dir.path_join(file))
	_shots += 1
	print("SHOT %s %s %dx%d" % ["OK" if err == OK else "ERR", file, img.get_width(), img.get_height()])
