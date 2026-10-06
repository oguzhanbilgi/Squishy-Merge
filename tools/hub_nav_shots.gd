extends Node
## TASK/057 — hub ekranları görsel inceleme çekimleri (Ana Sayfa / Harita / Mağaza / Koleksiyon / Profil
## + oyun). Dev aracı — oyun çalışırken kullanılmaz. `--headless` İLE ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn`; kayıt durumu BELLEKTE sabit bir orta-oyuncu vitrini (aynı içerik taban ve aday
## çekimlerinde — fark yalnız kod). Kayıt yolu `user://qa_hub_nav_shots/`'a YÖNLENDİRİLİR (Main'in yazmaları
## sahibin kaydına gitmez); sahibin kayıt ailesi başta / sonda bayt bayt karşılaştırılır ve geri yazılır
## (koşucu ayrıca aileyi yedekleyip geri koyar). Banner kipinde yuva yalnız bu araçta yarı saydam plakayla
## işaretlenir (masaüstünde gerçek banner çizilmez).
##
## Taban (TASK/057 öncesi kod) ile aday aynı aracı çalıştırır: küresel gezinme kabuğu yoksa (taban) yalnız
## ortak kareler çekilir; varsa (`Main.global_nav()`) kabuğun ek durumları da çekilir.
##
##   01_home · 02_map · 03_shop · 04_shop_bottom · 05_collection · 06_collection_bottom · 07_profile ·
##   08_profile_bottom · 09_gameplay · 10_daily_modal (Main penceresi kabuğun üstünde) ·
##   11_collection_detail (ekran içi pencere) · [aday] 12_nav_pressed
##
## Kipler: `a36` = A36 benzeri (cihaz üst payı safe=61 + uyarlanabilir banner yuvası 64 dp × 2.625,
## sahte reklam arka ucu); varsayılan = masaüstü (yuva yok, reklam yöneticisi sahte arka uçla ama
## banner yuvası 0).
##
## Kullanım:
##   godot --path . res://tools/hub_nav_shots.tscn -- <çıktı_klasörü> [GxY] [a36|banner] [only=01_home,02_map]

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const LEVEL_04: String = "res://resources/levels/level_04.tres"
const SHOT_SIZE := Vector2i(720, 1280)
const A36_SAFE_TOP: float = 61.0
const A36_BANNER_DP: int = 64
const A36_DENSITY: float = 2.625

var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _a36: bool = false
var _banner: bool = false
const REDIRECT_DIR: String = "user://qa_hub_nav_shots"
var _owner_family: Dictionary = {}
var _only: PackedStringArray = PackedStringArray()
var _main: Node2D
var _main_script: GDScript = load("res://scripts/main.gd")
var _saved_data: Dictionary = {}
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _shots: int = 0


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://hub_nav_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_size = _shot_size(args)
	for arg in args:
		var a: String = String(arg)
		if a == "a36":
			_a36 = true
			_banner = true
		elif a == "banner":
			_banner = true
		elif a.begins_with("only="):
			_only = a.trim_prefix("only=").split(",", false)
	DisplayServer.window_set_size(_size)
	await get_tree().process_frame
	await get_tree().process_frame

	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_saved_data = SaveManager.data.duplicate(true)
	_owner_family = _family_snapshot()
	DirAccess.make_dir_recursive_absolute(REDIRECT_DIR)
	SaveManager.save_path = REDIRECT_DIR + "/save.json"
	_apply_review_player()

	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	fake.adaptive_height_dp = A36_BANNER_DP if _banner else 0
	# Yuva tuval px'te A36 ile aynı (112): 720 pencerede A36 yoğunluğu gerçek dışı 168 px üretirdi.
	fake.density_value = A36_DENSITY * float(_size.x) / 1080.0
	await _make_main(fake)
	if _banner:
		fake.complete_consent_update(true)
		fake.complete_init()
		await _settle()
		_apply_safe_top()
		_build_banner_overlay()
	print("SHOT-INFO size=%s a36=%s banner_slot=%d nav=%s" % [str(_size), str(_a36),
		int(UiKit.banner_slot()), str(_main.has_method("global_nav"))])

	await _show_tab(0)
	await _capture("01_home")
	await _show_tab(1)
	await _capture("02_map")
	await _show_tab(3)
	await _capture("03_shop")
	await _scroll_end(_main._screens[3])
	await _capture("04_shop_bottom")
	await _show_tab(2)
	await _capture("05_collection")
	await _scroll_end(_main._screens[2])
	await _capture("06_collection_bottom")
	await _show_tab(4)
	await _capture("07_profile")
	await _scroll_end(_main._screens[4])
	await _capture("08_profile_bottom")

	_main._start_level(load(LEVEL_04))
	await _settle()
	await _settle()
	await _capture("09_gameplay")
	_main.abandon_run()
	await _settle()

	await _show_tab(0)
	_main.open_daily_rewards()
	await _settle()
	await _capture("10_daily_modal")
	_main._daily_rewards.close_popup()
	await _settle()

	await _show_tab(2)
	_main._screens[2].open_detail(&"rare_02")
	await _settle()
	await _capture("11_collection_detail")
	_main._screens[2].handle_back()
	await _settle()

	if _main.has_method("global_nav"):
		await _show_tab(3)
		await _capture_nav_pressed()

	await _free_main()
	SaveManager.save_path = SaveManager.SAVE_PATH
	for p: String in [REDIRECT_DIR + "/save.json", REDIRECT_DIR + "/save.json" + SaveFile.TEMP_SUFFIX,
			REDIRECT_DIR + "/save.json" + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	DirAccess.remove_absolute(REDIRECT_DIR)
	SaveManager.data = _saved_data
	_restore_save_file()
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
	if not _a36:
		return
	for screen in _main._screens:
		if screen.has_method("_layout_with_safe_top"):
			screen._layout_with_safe_top(A36_SAFE_TOP)
	if _main.has_method("global_nav"):
		_main.global_nav().relayout()


func _free_main() -> void:
	_main.queue_free()
	_main = null
	await get_tree().process_frame
	await get_tree().process_frame


## Aday: Mağaza sekmesine basılı tutulan parmak (basış görseli) — bırakılmadan çekilir, sonra iptal.
func _capture_nav_pressed() -> void:
	var nav: Node = _main.global_nav()
	var item: Control = nav.item_button(2)
	var at: Vector2 = get_viewport().get_screen_transform() * (item.get_global_rect().get_center() + Vector2(0.0, 20.0))
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await get_tree().create_timer(0.12).timeout
	await _capture("12_nav_pressed")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.canceled = true
	up.position = at
	up.global_position = at
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await _settle()


## Ekranın kaydırma kabını en alta indirir (son içerik + alt pay görünür).
func _scroll_end(screen: Node) -> void:
	if not screen.has_method("scroll"):
		return
	var scroll: ScrollContainer = screen.scroll()
	await get_tree().process_frame
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	scroll.scroll_vertical = int(bar.max_value)
	await _settle()


## İnceleme oyuncusu (yalnız bellekte): orta ilerleme, birkaç parça, dolu vitrin, 13+ yetişkin bandı
## (yaş ekranı açılmaz), günlük giriş bugün alınmış (açılış talebi yazmaz).
func _apply_review_player() -> void:
	var today: String = Time.get_date_string_from_system()
	SaveManager.data["last_login_date"] = today
	SaveManager.data["onboarding_completed"] = true
	SaveManager.data["highest_level_unlocked"] = 5
	SaveManager.data["level_stars"] = {"1": 3, "2": 3, "3": 2, "4": 3}
	SaveManager.data["dough"] = 1240
	SaveManager.data["daily_streak"] = 3
	SaveManager.data["unlocked_skins"] = ["common_01", "common_02", "rare_02", "common_05", "epic_01", "rare_04",
		"common_03"]
	SaveManager.data["profile_showcase"] = ["epic_01", "rare_02", "common_05"]
	SaveManager.data["merges_since_bonus_chest"] = 49
	SaveManager.data["total_merges"] = 412
	SaveManager.data["total_rounds_played"] = 23
	SaveManager.data["highest_tier_created"] = 6
	SaveManager.data["player_xp"] = 640
	SaveManager.data["powerups"] = {"bomb": 2, "upgrade": 1, "shake": 0, "clear_small": 1}
	SaveManager.data["powerup_starter_granted"] = true
	SaveManager.data["age_ad_band"] = "ADULT"
	SaveManager.data["next_age_transition_date"] = ""


## Banner yuvası (yalnız bu araçta): yarı saydam plaka + etiket — kabuğun yuvaya göre konumu görünsün.
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
	await get_tree().create_timer(0.45).timeout
	await get_tree().process_frame


func _show_tab(tab: int) -> void:
	_main._show_tab(tab)
	await _settle()


func _restore_save_file() -> void:
	if _had_save and FileAccess.file_exists(SaveManager.SAVE_PATH) 			and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == _save_bytes:
		return
	if not _had_save:
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()


func _shot_size(args: PackedStringArray) -> Vector2i:
	if args.size() < 2:
		return SHOT_SIZE
	var parts: PackedStringArray = args[1].split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return SHOT_SIZE
	return Vector2i(int(parts[0]), int(parts[1]))


func _tag() -> String:
	return "%dx%d%s" % [_size.x, _size.y, "_a36" if _a36 else ("_banner" if _banner else "")]


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
