extends Node
## TASK/058 — Ana Sayfa V3 görsel inceleme çekimleri. Dev aracı — oyun çalışırken kullanılmaz. `--headless` İLE
## ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn`; kayıt durumu BELLEKTE sabit bir orta-oyuncu vitrini (aynı içerik taban ve aday çekimlerinde —
## fark yalnız kod). Kayıt yolu `user://qa_home_v3_shots/`'a YÖNLENDİRİLİR (Main'in yazmaları sahibin kaydına gitmez);
## sahibin kayıt ailesi başta / sonda bayt bayt karşılaştırılır. Banner kipinde yuva yalnız bu araçta yarı saydam
## plakayla işaretlenir (masaüstünde gerçek banner çizilmez). Taban (`28a5bf1`) ve aday AYNI aracı çalıştırır: yalnız iki
## sürümde de var olan Main API'leri kullanılır (`open_daily_rewards` / `open_daily_challenge` / `open_missions`).
##
##   01_home (ücretsiz sandık hazır) · 02_daily_open · 03_challenge_open · 04_missions_open ·
##   05_home_first_day (tutorial bugün bitti — günlük sistem kilitli) · 06_home_all_done (günlük + meydan okuma bitti) ·
##   07_home_new_player (yeni oyuncu, ertesi gün) · 08_home_endless (sonsuz mod, dolu koleksiyon)
##
## Kipler: varsayılan masaüstü (yuva yok) · `banner` (yuva 112) · `a36` (üst pay 61 + yuva 112) · `a36nb` (üst pay 61,
## yuva yok) · `slot=N` (yuvayı N tuval px'e zorlar — uç durum).
##
##   godot --path . res://tools/home_v3_shots.tscn -- <çıktı_klasörü> [GxY] [banner|a36|a36nb] [slot=N] [only=01_home,…]

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SHOT_SIZE := Vector2i(720, 1280)
const A36_SAFE_TOP: float = 61.0
const A36_BANNER_DP: int = 64
const A36_DENSITY: float = 2.625
const REDIRECT_DIR: String = "user://qa_home_v3_shots"

var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _safe_top: float = 0.0
var _banner: bool = false
var _slot_override: float = -1.0
var _mode: String = ""
var _owner_family: Dictionary = {}
var _only: PackedStringArray = PackedStringArray()
var _main: Node2D
var _main_script: GDScript = load("res://scripts/main.gd")
var _saved_data: Dictionary = {}
var _shots: int = 0
var _slot_rect: ColorRect
var _slot_label: Label


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://home_v3_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_size = _shot_size(args)
	for arg in args:
		var a: String = String(arg)
		if a == "a36":
			_safe_top = A36_SAFE_TOP
			_banner = true
			_mode = "_a36"
		elif a == "a36nb":
			_safe_top = A36_SAFE_TOP
			_mode = "_a36nb"
		elif a == "banner":
			_banner = true
			_mode = "_banner"
		elif a.begins_with("slot="):
			_slot_override = float(a.trim_prefix("slot="))
			_banner = true
			_mode = "_slot%d" % int(_slot_override)
		elif a.begins_with("only="):
			_only = a.trim_prefix("only=").split(",", false)
	DisplayServer.window_set_size(_size)
	await get_tree().process_frame
	await get_tree().process_frame

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
	if _slot_override > 0.0:
		fake.density_value = _slot_override / float(A36_BANNER_DP) * float(_size.x) / 720.0
	await _make_main(fake)
	if _banner:
		fake.complete_consent_update(true)
		fake.complete_init()
		await _settle()
		_apply_safe_top()
	_build_banner_overlay()
	print("SHOT-INFO size=%s mode=%s safe_top=%d banner_slot=%d nav=%s" % [str(_size), _mode, int(_safe_top),
		int(UiKit.banner_slot()), str(_main.has_method("global_nav"))])

	var home: CanvasLayer = _main._screens[0]
	await _show_home()
	await _capture("01_home")
	_main.open_daily_rewards()
	await _settle()
	await _capture("02_daily_open")
	_main._daily_rewards.close_popup()
	await _settle()
	_main.open_daily_challenge()
	await _settle()
	await _capture("03_challenge_open")
	_main._challenge_sheet.close_sheet()
	await _settle()
	_main.open_missions()
	await _settle()
	await _capture("04_missions_open")
	_main._missions.close_missions()
	await _settle()

	SaveManager.data["onboarding_completed_day"] = DailyRewards.day_key()
	await _show_home()
	await _capture("05_home_first_day")
	SaveManager.data["onboarding_completed_day"] = ""

	var day: String = DailyRewards.day_key()
	SaveManager.data["daily_rewards"] = {"day_key": day, "free_chest_claimed": true, "ad_chests_claimed": 2,
		"dough_ad_claimed": true, "popup_seen_day": day, "last_seen_day_key": day}
	SaveManager.data["daily_challenge"] = {"version": 1, "completed_day_key": DailyChallenge.current_day()}
	await _show_home()
	await _capture("06_home_all_done")

	_apply_new_player()
	await _show_home()
	await _capture("07_home_new_player")

	_apply_endless()
	await _show_home()
	await _capture("08_home_endless")

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


## İnceleme oyuncusu (yalnız bellekte): orta ilerleme, birkaç parça, dolu vitrin, 13+ yetişkin bandı (yaş ekranı
## açılmaz), günlük giriş bugün alınmış (açılış talebi yazmaz), bugünün ücretsiz sandığı hazır.
func _apply_review_player() -> void:
	var today: String = Time.get_date_string_from_system()
	SaveManager.data["last_login_date"] = today
	SaveManager.data["onboarding_completed"] = true
	SaveManager.data["onboarding_completed_day"] = ""
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
	SaveManager.data["daily_challenge"] = {"version": 1, "completed_day_key": ""}
	var day: String = DailyRewards.day_key()
	SaveManager.data["daily_rewards"] = {"day_key": day, "free_chest_claimed": false, "ad_chests_claimed": 0,
		"dough_ad_claimed": false, "popup_seen_day": day, "last_seen_day_key": day}


func _apply_new_player() -> void:
	_apply_review_player()
	SaveManager.data["highest_level_unlocked"] = 1
	SaveManager.data["level_stars"] = {}
	SaveManager.data["dough"] = 0
	SaveManager.data["daily_streak"] = 1
	SaveManager.data["unlocked_skins"] = []
	SaveManager.data["profile_showcase"] = []
	SaveManager.data["merges_since_bonus_chest"] = 3
	SaveManager.data["player_xp"] = 12


func _apply_endless() -> void:
	_apply_review_player()
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
	SaveManager.data["unlocked_skins"] = all_ids
	SaveManager.data["profile_showcase"] = ["legendary_02", "epic_01", "rare_02"]
	SaveManager.data["merges_since_bonus_chest"] = 74
	SaveManager.data["endless_high_score"] = 12480
	SaveManager.data["player_xp"] = 9800


## Banner yuvası (yalnız bu araçta): yarı saydam plaka + etiket — içeriğin yuvaya göre konumu görünsün.
func _build_banner_overlay() -> void:
	var slot: float = UiKit.banner_slot()
	if slot <= 0.0:
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var view: Vector2 = get_viewport().get_visible_rect().size
	_slot_rect = ColorRect.new()
	_slot_rect.color = Color(1.0, 1.0, 1.0, 0.16)
	_slot_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_rect.position = Vector2(0.0, view.y - UiKit.safe_bottom(view) - slot)
	_slot_rect.size = Vector2(view.x, slot)
	layer.add_child(_slot_rect)
	_slot_label = Label.new()
	_slot_label.text = "BANNER YUVASI %d px (yalnız çekim işareti)" % int(slot)
	_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_slot_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_slot_label.add_theme_font_size_override("font_size", 20)
	_slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_label.position = _slot_rect.position
	_slot_label.size = _slot_rect.size
	layer.add_child(_slot_label)


func _family_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for p: String in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null
	return out


func _settle() -> void:
	await get_tree().create_timer(0.45).timeout
	await get_tree().process_frame


## Ana Sayfa'yı (yeniden) gösterir: Main'in her sekme girişindeki `refresh()` yolu.
func _show_home() -> void:
	_main._show_tab(1)
	await get_tree().process_frame
	_main._show_tab(0)
	_apply_safe_top()
	await _settle()


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
