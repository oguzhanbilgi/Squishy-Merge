extends Node
## TASK/056 — HUD hedef kartı ad sığdırma çekimleri. Dev aracı; `--headless` İLE ÇALIŞTIRILAMAZ
## (ekran görüntüsü). Gerçek GameBoard + production GameplayHud; her durum için tam kare + hedef
## kartı kırpması (kart dikdörtgeni + 24 px pay, pencere ölçeğinde).
##
## Durumlar: L01–L10 + Sonsuz (gerçek level kaynakları) · DC_T5 / DC_T6 (günlük meydan okuma HUD'u,
## BUGÜN rozeti) · T1–T8 (level_03 kopyası, hedef tier değiştirilmiş — üretimde hedef olmayan
## tier'lar dahil) · STRESS_* (yalnız test metni, sevkiyat metni DEĞİL: T5'ten biraz uzun Türkçe,
## Latin harfli, aşırı uzun → taban puntoda sınırlı kesme) · RTL_* (yalnız test: kart
## `layout_direction = RTL`; ürün tek dilli Türkçe, RTL yerelleştirmesi yok — yönlendirme
## sağlamlığı vekili).
##
## KAYIT: SaveManager test yoluna yönlendirilir (sahte kayıt, `user://qa_target_card_shots/`);
## sahibin kayıt ailesi (kanonik + .tmp + .bak) baştan / sondan bayt olarak karşılaştırılır.
##
## Kullanım:
##   godot --path . res://tools/target_card_shots.tscn -- <çıktı_klasörü> [GxY] [ETİKET,ETİKET...]
## (Düzeltmesiz tabanda — `set_goal_name` yokken — STRESS_* metni doğrudan etikete yazılır:
## aynı araç önce / sonra karşılaştırmasını çeker.)

const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const SHOT_SIZE := Vector2i(720, 1280)
const DIR: String = "user://qa_target_card_shots"
const PATH: String = DIR + "/save.json"
const THU: String = "2026-10-01"
const CROP_PAD: float = 24.0
## [etiket, tür, değer]
const CASES: Array = [
	["L01", "level", 1], ["L02", "level", 2], ["L03", "level", 3], ["L04", "level", 4],
	["L05", "level", 5], ["L06", "level", 6], ["L07", "level", 7], ["L08", "level", 8],
	["L09", "level", 9], ["L10", "level", 10], ["ENDLESS", "endless", 0],
	["DC_T5", "challenge", 5], ["DC_T6", "challenge", 6],
	["T1", "tier", 1], ["T2", "tier", 2], ["T3", "tier", 3], ["T4", "tier", 4],
	["T5", "tier", 5], ["T6", "tier", 6], ["T7", "tier", 7], ["T8", "tier", 8],
	["STRESS_T5PLUS", "name", "Büyük Dumplingler"],
	["STRESS_LATIN", "name", "Gigantic Dumpling"],
	["STRESS_EXTREME", "name", "Büyük Dumpling Kralının Tacı"],
	["RTL_T5", "rtl", 3], ["RTL_L08", "rtl", 8],
]

var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _filter: PackedStringArray = PackedStringArray()
var _owner: Dictionary = {}
var _saved: Dictionary = {}
var _shots: int = 0


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		# Varsayılan klasör YOK: çıktı asla sahibin `user://` klasörüne düşmez.
		print("kullanım: godot --path . res://tools/target_card_shots.tscn -- <çıktı_klasörü> [GxY] [ETİKET,...]")
		get_tree().quit(2)
		return
	_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	if args.size() >= 2:
		var parts: PackedStringArray = args[1].split("x")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			_size = Vector2i(int(parts[0]), int(parts[1]))
	if args.size() >= 3:
		_filter = args[2].split(",", false)
	DisplayServer.window_set_size(_size)
	_owner = _owner_snapshot()
	_saved = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)
	SaveManager.save_path = PATH
	SaveManager.data = {"highest_level_unlocked": 10, "dough": 335, "powerup_starter_granted": true,
		"onboarding_completed": true, "age_ad_band": "ADULT",
		"powerups": {"bomb": 2, "upgrade": 1, "shake": 1, "clear_small": 3}}
	await get_tree().process_frame
	await get_tree().process_frame

	var index: int = 0
	for spec in CASES:
		index += 1
		if not _filter.is_empty() and not _filter.has(String(spec[0])):
			continue
		await _shoot(index, spec)

	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved
	_remove_dir()
	var window: Vector2i = DisplayServer.window_get_size()
	var canvas: Vector2 = get_viewport().get_visible_rect().size
	print("SHOTS %d -> %s | window requested %dx%d actual %dx%d | canvas %dx%d%s | owner save family unchanged=%s"
		% [_shots, _out_dir, _size.x, _size.y, window.x, window.y, int(canvas.x), int(canvas.y),
		"" if int(canvas.x) == 720 else " !! CANVAS WIDTH IS NOT 720 (window clamped / not a phone aspect)",
		str(_owner_snapshot() == _owner)])
	get_tree().quit()


func _shoot(index: int, spec: Array) -> void:
	var tag: String = spec[0]
	var kind: String = spec[1]
	var board: Node2D = GAME_BOARD_SCENE.instantiate()
	match kind:
		"level", "rtl":
			board.setup(load("res://resources/levels/level_%02d.tres" % int(spec[2])))
		"endless":
			board.setup(load("res://resources/levels/endless.tres"))
		"challenge":
			var level: LevelData = DailyChallenge.make_level(THU)
			level.target_tier = int(spec[2])
			board.setup(level)
			board.setup_challenge(DailyChallenge.Sequence.new(THU), 18)
		"tier":
			var level: LevelData = (load("res://resources/levels/level_03.tres") as LevelData).duplicate()
			level.target_tier = int(spec[2])
			board.setup(level)
		"name":
			board.setup(load("res://resources/levels/level_03.tres"))
	add_child(board)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud: GameplayHud = board.get_node("HUD")
	if kind == "name":
		if hud.has_method("set_goal_name"):
			hud.call("set_goal_name", String(spec[2]))
		else:
			hud.goal_label.text = String(spec[2])
	if kind == "rtl":
		hud.goal_plate.layout_direction = Control.LAYOUT_DIRECTION_RTL
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var base: String = "%02d_%s" % [index, tag]
	img.save_png(_out_dir.path_join(base + "_full.png"))
	var scale: float = float(img.get_width()) / get_viewport().get_visible_rect().size.x
	var card: Rect2 = hud.goal_plate.get_global_rect().grow(CROP_PAD)
	var crop := Rect2i(Vector2i((card.position * scale).floor()), Vector2i((card.size * scale).ceil()))
	crop = crop.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(crop).save_png(_out_dir.path_join(base + "_card.png"))
	var label: Label = hud.goal_label
	print("SHOT %s | text='%s' font=%d label_w=%.0f extra='%s' dir=%s canvas_w=%.0f"
		% [base, label.text, label.get_theme_font_size("font_size"), label.size.x, hud.goal_extra.text,
		"RTL" if hud.goal_plate.is_layout_rtl() else "LTR", get_viewport().get_visible_rect().size.x])
	_shots += 1
	board.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for path in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out


func _remove_dir() -> void:
	var dir: DirAccess = DirAccess.open(DIR)
	if dir != null:
		for f in dir.get_files():
			dir.remove(f)
	DirAccess.remove_absolute(DIR)
