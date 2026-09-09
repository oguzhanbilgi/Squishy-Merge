extends Node
## M8 juice pasinin ekran goruntulerini uretir: merge ani, tasma (danger)
## durumu ve sandik acilisi. Dev araci — oyun calisirken kullanilmaz.
##
## `--headless` ILE CALISTIRILAMAZ: headless dummy rasterizer kullanir,
## ekran goruntusu bos cikar. Pencereli calismali.
##
## Kullanim:
##   godot --path . res://tools/screenshot_test.tscn -- <cikti_klasoru> [GxY]
##
## Ikinci arguman opsiyonel pencere olcusu ("540x1170" gibi): UI'in dar/uzun
## modern telefon oraninda (9:19.5) tasip tasmadigini kontrol etmek icin.
## Proje 9:16 tasarlandi, stretch "expand" oldugu icin uzun ekranda viewport
## yukseliyor — kontrol edilmesi gereken sey bu.

const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const ROUND_RESULT_SCENE: PackedScene = preload("res://scenes/ui/round_result.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const LEVEL_SELECT_SCENE: PackedScene = preload("res://scenes/ui/level_select.tscn")
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
	DisplayServer.window_set_size(_shot_size(args))
	_set_speed(SPEEDUP)

	await get_tree().process_frame
	await _shot_merge()
	await _shot_combo()
	await _shot_score_pop()
	await _shot_tutorial()
	await _shot_danger()
	await _shot_chest()
	await _shot_shell()
	await _shot_locked_levels()
	await _shot_skins()
	print("bitti -> ", _out_dir)
	get_tree().quit()


# --- Ortak ---

## Ikinci arguman "GENISLIKxYUKSEKLIK" ise onu, degilse varsayilani dondurur.
func _shot_size(args: PackedStringArray) -> Vector2i:
	if args.size() < 2:
		return SHOT_SIZE
	var parts: PackedStringArray = args[1].split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		printerr("Olcu okunamadi (\"540x1170\" bekleniyor): ", args[1])
		return SHOT_SIZE
	return Vector2i(int(parts[0]), int(parts[1]))


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


# --- 1b) Combo rozeti: "xN" ve "+N" yazılarının arkasındaki starburst ---

## Combo zinciri 2'ye ulaştığı anda yakalıyor: hem ComboLabel hem ScorePop o
## anda görünür, ikisinin de arkasında rozet var.
func _shot_combo() -> void:
	_make_board(0)
	_drive = true
	GameState.merge_performed.connect(_on_merge_for_combo)
	await _wait_for_capture(60 * 120)
	GameState.merge_performed.disconnect(_on_merge_for_combo)
	await _capture("04_combo.png")
	await _teardown()


func _on_merge_for_combo(_tier: int, _position: Vector2) -> void:
	if _board == null or not is_instance_valid(_board):
		return
	# 2 kare pay: rozetin scale pop'u tepeye yaklaşsın.
	if _board._combo_count >= 2 and _capture_countdown < 0:
		_capture_countdown = 2


# --- 1d) Skor pop rozeti: "+N" yazisinin arkasindaki starburst ---

## Merge beklemek yerine skor dogrudan artiriliyor: pop tween'i 0.55 sn ve
## normal hizda calisiyor, boylece rozetin yerini kare kare kovalamak
## gerekmiyor.
func _shot_score_pop() -> void:
	_set_speed(1)
	_make_board(1)
	await get_tree().process_frame
	GameState.add_score(150)
	# Tween'in scale pop'unun tepesi ~0.14 sn; 0.1 sn'de rozet tam acilmis.
	await get_tree().create_timer(0.1).timeout
	await _capture("04b_skor_pop.png")
	await _teardown()
	_set_speed(SPEEDUP)


# --- 1c) Level 1 tutorial ipucu: poz + "sürükle • bırak" ---

## Hiç bırakma yapılmadan yakalanıyor — ipucu ilk bırakışta sönüyor.
## Aynı karede taşma şeridinin sakin (idle) hâli de görünüyor.
func _shot_tutorial() -> void:
	_make_board(1)
	# Bob tween'i biraz ilerlesin ki poz layout'a oturmuş olsun.
	for i in 8:
		await get_tree().process_frame
	await _capture("05_tutorial.png")
	await _teardown()


# --- 1e) Kilitli level rozeti ---

## Gercek kayitta tum level'lar acik oldugu icin kilit rozeti hic gorunmuyor.
## Ilerleme SADECE BELLEKTE gerileltiliyor (SaveManager.save cagrilmiyor),
## cekim alinip hemen geri konuyor — owner'in kaydi bozulmaz.
func _shot_locked_levels() -> void:
	var key := "highest_level_unlocked"
	var original: Variant = SaveManager.data.get(key, 1)
	SaveManager.data[key] = 4

	var select: CanvasLayer = LEVEL_SELECT_SCENE.instantiate()
	add_child(select)
	await get_tree().process_frame
	select.refresh()
	await get_tree().process_frame
	await _capture("08b_harita_kilitli.png")

	select.queue_free()
	SaveManager.data[key] = original
	await get_tree().process_frame


# --- 1f) Skin onizlemesi: 8 tier x (varsayilan + 4 rarity) ---

## Skin gorsel katmaninin (scripts/game/skin_visual.gd) QA cikti.
##
## Tier'lar ESIT BOYUTTA ciziliyor. Gercekte caplari 44-200 px arasi degisiyor
## ama burada olculmek istenen sey boyut degil RENK: skin uygulandiginda
## tier'lar birbirinden hala ayirt edilebiliyor mu, yuz/kontur okunuyor mu,
## parlamalar sonuyor mu.
const SKIN_SHOT_TIERS: int = 8
const SKIN_SHOT_CELL: float = 78.0
const SKIN_SHOT_ROW_HEIGHT: float = 116.0
## Rarity basina temsilci skin. Ikisi bilerek en kotu eslesmeler
## (SKIN_ART_AUDIT.md): "Kirmizi Biber" sari-yesil, "Altin Hamur" turkuaz.
const SKIN_SHOT_IDS: Array[StringName] = [
	&"common_01", &"rare_02", &"epic_01", &"legendary_01",
]


func _shot_skins() -> void:
	var root := Node2D.new()
	add_child(root)

	var rows: Array[Dictionary] = [{"skin": null, "label": "VARSAYILAN (skin yok)"}]
	for id in SKIN_SHOT_IDS:
		var skin: SkinData = SkinLibrary.find(id)
		if skin == null:
			continue
		rows.append({"skin": skin, "label": "%s — %s (%s)" % [
			SkinData.rarity_name(skin.rarity), skin.display_name,
			skin.tint.to_html(false)]})

	var top: float = 70.0
	for row in rows:
		var label := Label.new()
		label.position = Vector2(24.0, top - 34.0)
		label.add_theme_font_size_override("font_size", 19)
		label.text = row["label"]
		root.add_child(label)

		for tier in range(1, SKIN_SHOT_TIERS + 1):
			var visual: Node2D = preload("res://scripts/game/dumpling_visual.gd").new()
			root.add_child(visual)
			visual.setup(tier)
			visual.override_skin(row["skin"])
			# Tum tier'lari ayni ekran boyutuna normalize et.
			visual.scale = Vector2.ONE * (SKIN_SHOT_CELL / (TierConfig.radius(tier) * 2.0))
			visual.position = Vector2(
				60.0 + float(tier - 1) * (SKIN_SHOT_CELL + 9.0),
				top + SKIN_SHOT_CELL * 0.5)
		top += SKIN_SHOT_ROW_HEIGHT

	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("11_skin_karsilastirma.png")
	root.queue_free()
	await get_tree().process_frame


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

	# Yıldız reveal'i 3 x 0.4 sn = 1.2 sn. Sonra her sandık için 0.5 sn
	# bekleme + kart belirme, ardından 0.35 sn sonra açılış: kart n
	# 1.7 + n*1.2 sn'de beliriyor, 0.35 sn sonra açılıyor.
	# 1.95 sn = ilk sandık belirdi ama daha AÇILMADI (kapalı hâli).
	await get_tree().create_timer(1.95).timeout
	await _capture("06_chest_closed.png")
	# 5.80 sn = dördü de açıldı, sonuncusunun patlaması hâlâ havada.
	await get_tree().create_timer(5.80 - 1.95).timeout
	await _capture("03_chest.png")
	result.queue_free()
	await get_tree().process_frame


## Gerçek kura yerine sabit ödüller: ekran görüntüsü tekrarlanabilir olsun ve
## dört rarity'nin görsel farkı tek karede görünsün (M8 ödül reveal pası).
func _fake_rewards() -> Array[ChestReward]:
	var rewards: Array[ChestReward] = []
	for rarity in [SkinData.Rarity.COMMON, SkinData.Rarity.RARE,
			SkinData.Rarity.EPIC, SkinData.Rarity.LEGENDARY]:
		var reward := ChestReward.new()
		reward.rarity = rarity
		var candidates: Array[SkinData] = SkinLibrary.by_rarity(rarity)
		if candidates.is_empty():
			reward.is_duplicate = true
			reward.dough = 25
		else:
			reward.skin = candidates[0]
		rewards.append(reward)
	return rewards


# --- 4) Sekme kabuğu: dört sekme de gerçek main.tscn üzerinden ---

## Ekranları tek tek instantiate etmek yerine gerçek akış kullanılıyor:
## sekme çubuğu ancak main.gd bağladığında görünüyor ve asıl doğrulanmak
## istenen şey de o.
func _shot_shell() -> void:
	var main: Node2D = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	# Günlük ödül popup'ı açıldıysa kapat — sekmeleri örtmesin.
	if main._daily != null:
		main._daily.visible = false

	var names: Array[String] = ["07_ana_sayfa", "08_harita", "09_koleksiyon", "10_magaza"]
	for tab in names.size():
		main._show_tab(tab)
		main._tabs.set_active(tab)
		await get_tree().process_frame
		await get_tree().process_frame
		await _capture(names[tab] + ".png")

	main.queue_free()
	await get_tree().process_frame
