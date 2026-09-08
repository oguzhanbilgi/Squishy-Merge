extends Node
## M8 juice pasinin ekran goruntulerini uretir: merge ani, tasma (danger)
## durumu ve sandik acilisi. Dev araci — oyun calisirken kullanilmaz.
##
## `--headless` ILE CALISTIRILAMAZ: headless dummy rasterizer kullanir,
## ekran goruntusu bos cikar. Pencereli calismali.
##
## Kullanim:
##   godot --path . res://tools/screenshot_test.tscn -- <cikti_klasoru>

const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const ROUND_RESULT_SCENE: PackedScene = preload("res://scenes/ui/round_result.tscn")
const BOT_BRAIN = preload("res://tools/bot_brain.gd")

## Proje viewport'u 720x1280; ekrana sigmasi icin ayni oranda kucultuluyor.
const SHOT_SIZE := Vector2i(540, 960)

## Fizikle dolan sahneleri (merge, danger) gercek zamanda beklemek gereksiz.
## bot_runner.gd ile ayni yontem: fizik adimi 1/60 sn kalir, saniyede N kat
## adim atilir. Sandik cekiminde 1.0'a donuluyor — orada tween zamanlamasi
## hassas ve hizlandirmanin bir faydasi yok.
const SPEEDUP: int = 4

var _out_dir: String = ""
var _board: Node2D
var _drive: bool = false
## true ise botun sezgisi yerine tamamen rastgele x'e birakilir. Kotu oyun =
## yigin merge olmadan yukselir; danger durumunu guvenilir sekilde tetikler.
## (Sabit x denendi, ise yaramadi: parcalar ust uste dusunce surekli merge
## oluyor ve bot L10'u kazanip cikiyordu.)
var _drive_random: bool = false
## -1 = tetiklenmedi, >0 = bu kadar kare sonra yakala, 0 = yakala.
var _capture_countdown: int = -1


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(SHOT_SIZE)
	_set_speed(SPEEDUP)

	await get_tree().process_frame
	await _shot_merge()
	await _shot_danger()
	await _shot_chest()
	print("bitti -> ", _out_dir)
	get_tree().quit()


# --- Ortak ---

func _set_speed(factor: int) -> void:
	Engine.physics_ticks_per_second = 60 * factor
	Engine.time_scale = float(factor)
	Engine.max_physics_steps_per_frame = 16 * factor

func _make_board(level_number: int) -> void:
	var path: String = "res://resources/levels/endless.tres"
	if level_number > 0:
		path = "res://resources/levels/level_%02d.tres" % level_number
	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(load(path))
	add_child(_board)


func _teardown() -> void:
	_drive = false
	_drive_random = false
	_capture_countdown = -1
	if _board != null and is_instance_valid(_board):
		_board.queue_free()
	_board = null
	await get_tree().process_frame


func _physics_process(_delta: float) -> void:
	if not _drive or _board == null or not is_instance_valid(_board):
		return
	if _board._is_finished or _board._drop_cooldown > 0.0:
		return
	var x: float = BOT_BRAIN.pick_x(_board, _board._pending_tier)
	if _drive_random:
		x = randf_range(_board._left_x(), _board._right_x())
	_board._set_aim(x)
	_board._drop()


## Sayaç 0'a inene ya da süre dolana kadar kare kare bekler.
func _wait_for_capture(max_frames: int) -> void:
	var frames: int = 0
	while _capture_countdown != 0 and frames < max_frames:
		await get_tree().process_frame
		frames += 1
		if _capture_countdown > 0:
			_capture_countdown -= 1


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out_dir.path_join(file_name)
	var err: int = img.save_png(path)
	print(("kaydedildi : " if err == OK else "HATA       : "), path)


# --- 1) Merge anı: yüksek tier bir birleşmenin parçacık patlaması ---

func _shot_merge() -> void:
	# Sonsuz mod: hedef yok, geniş kap — bot tier 7-8'e kadar çıkabilsin.
	_make_board(0)
	_drive = true
	GameState.merge_performed.connect(_on_merge_for_shot)
	await _wait_for_capture(60 * 120)
	GameState.merge_performed.disconnect(_on_merge_for_shot)
	await _capture("01_merge.png")
	await _teardown()


func _on_merge_for_shot(tier: int, _position: Vector2) -> void:
	# Patlamanın açılmasına 2 kare pay bırak; ilk karede parçacıklar hâlâ
	# merkezde üst üste duruyor.
	if tier >= 7 and _capture_countdown < 0:
		_capture_countdown = 2


# --- 2) Danger: taşma çizgisi aşılmış, kırmızı highlight nabzı ---

## Taşma anını yakalamak için KÖTÜ oyun gerekiyor: rastgele bırakma yığını
## merge etmeden yükseltiyor. Round taşmadan biterse (bot kazanabilir) baştan
## denenir.
func _shot_danger() -> void:
	for attempt in 6:
		_make_board(10)
		await get_tree().process_frame
		_drive = true
		_drive_random = true
		var caught: bool = false
		var frames: int = 0
		while frames < 60 * 150:
			await get_tree().process_frame
			frames += 1
			if _board == null or not is_instance_valid(_board) or _board._is_finished:
				break
			# Grace 1.5 sn; 0.7'de yakalamak hem highlight'ın açılmasını
			# bekler hem game-over'dan önce kalır.
			if _board._overflow_elapsed > 0.7:
				caught = true
				break
		if caught:
			await _capture("02_danger.png")
			await _teardown()
			return
		print("  danger denemesi %d: taşma yakalanamadı, tekrar" % (attempt + 1))
		await _teardown()
	printerr("danger durumu yakalanamadı")


# --- 3) Sandık açılışı: ışık patlaması + parıltı ---

func _shot_chest() -> void:
	_set_speed(1)
	var result: CanvasLayer = ROUND_RESULT_SCENE.instantiate()
	add_child(result)
	await get_tree().process_frame

	var level: LevelData = load("res://resources/levels/level_03.tres")
	result.show_result(level, true, 640, 3, _fake_rewards(), false)

	# Yıldız reveal'i 3 x 0.4 sn, ardından ilk sandık 0.5 sn sonra açılıyor.
	# 1.85 sn = patlamanın ~0.15 sn içi, en parlak an.
	await get_tree().create_timer(1.85).timeout
	await _capture("03_chest.png")
	result.queue_free()
	await get_tree().process_frame


## Gerçek kura yerine sabit ödüller — ekran görüntüsü tekrarlanabilir olsun
## ve legendary'nin parlak hâli garanti görünsün.
func _fake_rewards() -> Array[ChestReward]:
	var legendary := ChestReward.new()
	legendary.rarity = SkinData.Rarity.LEGENDARY
	legendary.skin = SkinLibrary.by_rarity(SkinData.Rarity.LEGENDARY)[0]

	var dough := ChestReward.new()
	dough.rarity = SkinData.Rarity.RARE
	dough.is_duplicate = true
	dough.dough = 25

	var rewards: Array[ChestReward] = [legendary, dough]
	return rewards
