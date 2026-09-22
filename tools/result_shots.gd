extends Node
## Round sonu çekimleri (M8.6-09). Dev aracı — oyun çalışırken kullanılmaz.
## `--headless` İLE ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn` üstünde, gameplay board'u gerçekten kurulup (yığın +
## bitmiş durum) sonuç ekranı deterministik `ChestReward` nesneleriyle
## doğrudan `show_result` ile açılır. Board'un `round_finished`'ı main'e
## GİTMEZ: sandık RNG'si, kayıt yazımı, ödül verme YOK — çekimler sunumu
## gösterir. Yalnız `20_retry_pressed` / `21_map_pressed` gerçek buton
## yolunu (retry → level yeniden başlar, Harita → harita + açılış
## animasyonu) koşar; ikisi de kayda yazmaz (harita bellekteki kaydı okur).
##
## Harness-only durumlar açıkça işaretli: `17_overflow_stress_6` (6 ödül —
## runtime'da bir tavan yok ama tipik en fazla ~5, bkz. QA_NOTES) ve
## `16_max_legit_rewards` (Sonsuz, 5 bonus sandık: ~350 merge'lik uzun tur).
##
## Kullanım:
##   godot --path . res://tools/result_shots.tscn -- <çıktı_klasörü> [GxY] [safe=61] [only=01,05]
## `safe=N`: A36 punch-hole payı simülasyonu (kabuk + board; dosya adı `_a36`).

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SHOT_SIZE := Vector2i(720, 1280)
const LEVEL_04: String = "res://resources/levels/level_04.tres"
const LEVEL_08: String = "res://resources/levels/level_08.tres"
const LEVEL_10: String = "res://resources/levels/level_10.tres"
const ENDLESS: String = "res://resources/levels/endless.tres"
## Birleşmeyen yığınlar (komşu tier'lar farklı): board kendi kendine merge
## yapıp skoru/hedefi değiştirmesin.
const PILE_MEDIUM: Array = [[5, 3, 4, 2, 1], [2, 4, 1, 3], [3, 1, 2]]
const PILE_DANGER: Array = [[7, 5, 6], [4, 6, 3, 5], [5, 2, 4, 1, 3], [1, 4, 2, 5, 2], [3, 1, 4, 1, 3, 2], [2, 3, 1, 2, 1]]
## Reveal bekleme: yıldızlar 0.3 + 3×0.2, kart başına 0.45 + 0.35, açılış
## efektleri ~0.5.
const REVEAL_BASE: float = 1.3
const REVEAL_PER_CARD: float = 0.85

var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _main: Node2D
var _saved_data: Dictionary = {}
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _safe_top: float = -1.0
var _shots: int = 0
var _only: PackedStringArray = PackedStringArray()


func _wants(id: String) -> bool:
	return _only.is_empty() or _only.has(id)


func _ready() -> void:
	# Otomatik GÜNLÜK ÖDÜLLER penceresi (M8.9-02) bu harness'in konusu değil.
	DailyRewards.auto_popup_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://result_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_size = _shot_size(args)
	for arg in args:
		if String(arg).begins_with("safe="):
			_safe_top = float(String(arg).trim_prefix("safe="))
		elif String(arg).begins_with("only="):
			_only = String(arg).trim_prefix("only=").split(",", false)
	DisplayServer.window_set_size(_size)
	await get_tree().process_frame
	await get_tree().process_frame

	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_saved_data = SaveManager.data.duplicate(true)
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	# M8.10: bu harness KABUGU olcuyor — onboarding tamamlanmis olmali,
	# yoksa Main dogrudan ilk acilis tutorial'ina girer. Kayit dosyasini
	# geri koymayan baska bir suite diske `false` birakmis olabilir.
	SaveManager.data["onboarding_completed"] = true

	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_showcase()
	_apply_safe_top_to_shell()

	await _group_states()

	SaveManager.data = _saved_data
	_restore_save_file()
	print("bitti -> ", _out_dir, " (", _shots, " çekim)")
	get_tree().quit()


# --- Altyapı -----------------------------------------------------------------

func _restore_save_file() -> void:
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
	return "%dx%d%s" % [_size.x, _size.y, "_a36" if _safe_top >= 0.0 else ""]


func _capture(name: String) -> void:
	# Pencere çizmiyorsa (küçültülmüş / kilit ekranı) `frame_post_draw` hiç
	# gelmez ve araç sonsuza dek beklerdi (final koşusunda yaşandı): en çok 30
	# kare bekle, çizim gelmezse kareyi zorla üret.
	await _drawn_frame()
	await _drawn_frame()
	var img: Image = get_viewport().get_texture().get_image()
	var file: String = "%s_%s.png" % [name, _tag()]
	var err: int = img.save_png(_out_dir.path_join(file))
	if err == OK:
		_shots += 1
	print(("kaydedildi : " if err == OK else "HATA       : "), file)


## Bir çizilmiş kare bekler; 30 karede çizim gelmezse (pencere görünmez)
## RenderingServer'a kareyi zorla çizdirir.
func _drawn_frame() -> void:
	var drawn: Array[bool] = [false]
	var mark := func() -> void: drawn[0] = true
	RenderingServer.frame_post_draw.connect(mark, CONNECT_ONE_SHOT)
	var frames: int = 0
	while not drawn[0] and frames < 30:
		await get_tree().process_frame
		frames += 1
	if not drawn[0]:
		if RenderingServer.frame_post_draw.is_connected(mark):
			RenderingServer.frame_post_draw.disconnect(mark)
		RenderingServer.force_draw(false)


func _settle(seconds: float = 0.45) -> void:
	await get_tree().create_timer(seconds).timeout
	await get_tree().process_frame


func _pointer(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	if pressed:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(ev)


func _apply_safe_top_to_shell() -> void:
	if _safe_top < 0.0:
		return
	for screen in _main._screens:
		if screen.has_method("_layout_with_safe_top"):
			screen._layout_with_safe_top(_safe_top)


func _apply_safe_top_to_board() -> void:
	if _safe_top < 0.0 or _main._board == null:
		return
	_main._board._apply_layout(get_viewport().get_visible_rect().size, _safe_top)


func _apply_showcase() -> void:
	SaveManager.data["highest_level_unlocked"] = 4
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3}
	SaveManager.data["dough"] = 335
	SaveManager.data["daily_streak"] = 2
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.data["unlocked_skins"] = ["common_01", "common_02", "rare_02", "common_04", "rare_05", "epic_01"]
	SaveManager.data["equipped_skin"] = "rare_02"
	SaveManager.data["merges_since_bonus_chest"] = 49
	SaveManager.data["endless_high_score"] = 0
	SaveManager.data["powerups"] = {"bomb": 4, "upgrade": 1, "shake": 0, "clear_small": 0}
	SaveManager.data["rewarded_power_date"] = ""
	SaveManager.data["rewarded_power_grants"] = 0
	SaveManager.data["sfx_enabled"] = true
	SaveManager.data["haptics_enabled"] = true


func _start_board(level_path: String) -> void:
	_main._start_level(load(level_path))
	await get_tree().process_frame
	await get_tree().process_frame
	# round_finished main'e GİTMEZ: gerçek ödül / kayıt / RNG yolu çalışmaz.
	_main._board.round_finished.disconnect(_main._on_round_finished)
	_apply_safe_top_to_board()
	await get_tree().process_frame


func _leave_board() -> void:
	_main._result.hide_result()
	_main.abandon_run()
	await get_tree().process_frame
	_main._show_tab(0)
	await _settle(0.3)


func _spawn(tier: int, at: Vector2) -> Dumpling:
	return _main._board._spawn_dumpling(tier, at)


func _settle_physics(max_frames: int = 240) -> void:
	for i in max_frames:
		await get_tree().physics_frame
		var moving: bool = false
		for child in _main._board._dumpling_layer.get_children():
			var d := child as Dumpling
			if d != null and d.linear_velocity.length() > 4.0:
				moving = true
				break
		if not moving and i > 30:
			return


func _pile(rows: Array) -> void:
	var board: Node2D = _main._board
	var left: float = board._left_x()
	var right: float = board._right_x()
	var y: float = board.FLOOR_Y - 40.0
	for row in rows:
		var tiers: Array = row
		var total_w: float = 0.0
		for t in tiers:
			total_w += TierConfig.radius(t) * 2.0 + 6.0
		var x: float = (left + right) * 0.5 - total_w * 0.5
		var row_h: float = 0.0
		for t in tiers:
			var r: float = TierConfig.radius(t)
			x += r + 3.0
			_spawn(t, Vector2(clampf(x, left + r, right - r), y - r))
			x += r + 3.0
			row_h = maxf(row_h, r * 2.0)
		y -= row_h + 4.0
		for i in 12:
			await get_tree().physics_frame
	await _settle_physics()


# --- Ödül fabrikaları ----------------------------------------------------------

func _dough(rarity: SkinData.Rarity, duplicate: bool = false) -> ChestReward:
	var r := ChestReward.new()
	r.rarity = rarity
	r.dough = ChestSystem.RARITY_DOUGH[int(rarity)]
	r.is_duplicate = duplicate
	return r


func _skin(rarity: SkinData.Rarity, index: int = 0) -> ChestReward:
	var r := ChestReward.new()
	r.rarity = rarity
	var pool: Array[SkinData] = SkinLibrary.by_rarity(rarity)
	r.skin = pool[mini(index, pool.size() - 1)]
	return r


func _consolation() -> ChestReward:
	var r := ChestReward.new()
	r.is_consolation = true
	r.dough = ChestSystem.CONSOLATION_DOUGH
	return r


## Board'u bitmiş göster ve sonuç ekranını hazır ödüllerle aç; reveal'i
## bekle (`wait` < 0 → ödül sayısına göre hesaplanır).
func _open(level_path: String, won: bool, score: int, rewards: Array[ChestReward],
		new_record: bool, pile: Array = PILE_MEDIUM, newly_unlocked: bool = false,
		reached_tier: int = 0, wait: float = -1.0) -> void:
	await _start_board(level_path)
	await _pile(pile)
	GameState.reset_run()
	GameState.add_score(score)
	var board: Node2D = _main._board
	var level: LevelData = _main._current_level
	board._is_finished = false
	board._finish(won)
	# Dar kapta (L8/L10) tehlike yığını yerleşirken taşma teklifi açılmış
	# olabilir; gerçek akışta Main round bitince teklifi kapatır — aynısı.
	_main._revive.hide_offer()
	_main._result.show_result(level, won, score, level.stars_earned(won, score), rewards,
		new_record, newly_unlocked, reached_tier)
	if wait < 0.0:
		wait = REVEAL_BASE + REVEAL_PER_CARD * float(rewards.size()) + 0.5
	await _settle(wait)


func _shot(id: String, name: String, level_path: String, won: bool, score: int,
		rewards: Array[ChestReward], new_record: bool = false, pile: Array = PILE_MEDIUM,
		newly_unlocked: bool = false, reached_tier: int = 0, wait: float = -1.0) -> void:
	if not _wants(id):
		return
	await _open(level_path, won, score, rewards, new_record, pile, newly_unlocked, reached_tier, wait)
	await _capture("%s_%s" % [id, name])
	await _leave_board()


# --- Durumlar --------------------------------------------------------------------

func _group_states() -> void:
	var l4: LevelData = load(LEVEL_04)
	var s1: int = maxi(50, l4.star_2_threshold() - 60)
	var s2: int = l4.star_2_threshold() + 10
	var s3: int = l4.star_3_threshold() + 40

	# 00 reveal başlamadan: pencere açılış hareketi bitti (0.2 s), yıldızlar
	# henüz gizli, kartlar görünmez.
	await _shot("00", "reveal_pending", LEVEL_04, true, s3, [_dough(SkinData.Rarity.RARE)],
		false, PILE_MEDIUM, false, 0, 0.24)
	# 01 / 02 kayıp: düşük skor (uzak) ve hedefe yakın (tier 5 / hedef 6).
	await _shot("01", "fail_low_score", LEVEL_04, false, 120, [_consolation()], false, PILE_DANGER, false, 3)
	await _shot("02", "fail_near_target", LEVEL_04, false, 640, [_consolation()], false, PILE_DANGER, false, 5)
	# 03–05 kazanma yıldızları.
	await _shot("03", "win_1star", LEVEL_04, true, s1, [_dough(SkinData.Rarity.COMMON)])
	await _shot("04", "win_2star", LEVEL_04, true, s2, [_dough(SkinData.Rarity.COMMON)])
	await _shot("05", "win_3star", LEVEL_04, true, s3, [_dough(SkinData.Rarity.COMMON)])
	# 06–09 Hamur ödülü, dört rarity.
	await _shot("06", "dough_common", LEVEL_04, true, s3, [_dough(SkinData.Rarity.COMMON)])
	await _shot("07", "dough_rare", LEVEL_04, true, s3, [_dough(SkinData.Rarity.RARE)])
	await _shot("08", "dough_epic", LEVEL_04, true, s3, [_dough(SkinData.Rarity.EPIC)])
	await _shot("09", "dough_legendary", LEVEL_04, true, s3, [_dough(SkinData.Rarity.LEGENDARY)])
	# 10–13 skin ödülü, dört rarity (gerçek final sanat).
	await _shot("10", "skin_common", LEVEL_04, true, s3, [_skin(SkinData.Rarity.COMMON, 2)])
	await _shot("11", "skin_rare", LEVEL_04, true, s3, [_skin(SkinData.Rarity.RARE, 3)])
	await _shot("12", "skin_epic", LEVEL_04, true, s3, [_skin(SkinData.Rarity.EPIC, 2)])
	await _shot("13", "skin_legendary", LEVEL_04, true, s3, [_skin(SkinData.Rarity.LEGENDARY, 1)])
	# 14 geri düşüş: Epik tamam → 60 Hamur (skin verildi denmez).
	await _shot("14", "fallback_dough", LEVEL_04, true, s3, [_dough(SkinData.Rarity.EPIC, true)])
	# 15 çoklu ödül: level sandığı + bonus (skin).
	await _shot("15", "multiple_rewards", LEVEL_04, true, s3,
		[_dough(SkinData.Rarity.RARE), _skin(SkinData.Rarity.EPIC, 1), _dough(SkinData.Rarity.COMMON)])
	# 16 en fazla meşru ödül: Sonsuz uzun tur, 5 bonus sandık (yeni rekor).
	SaveManager.data["endless_high_score"] = 12480
	await _shot("16", "max_legit_rewards_endless5", ENDLESS, false, 12480,
		[_dough(SkinData.Rarity.COMMON), _skin(SkinData.Rarity.RARE, 4), _dough(SkinData.Rarity.RARE),
			_dough(SkinData.Rarity.EPIC), _dough(SkinData.Rarity.LEGENDARY)], true, PILE_DANGER)
	SaveManager.data["endless_high_score"] = 0
	# 17 HARNESS-ONLY stres: 6 ödül, kaydırma (reveal sonunda gövde son karta kaymış).
	if _wants("17"):
		await _open(LEVEL_04, true, s3,
			[_dough(SkinData.Rarity.COMMON), _skin(SkinData.Rarity.COMMON, 4), _dough(SkinData.Rarity.RARE),
				_dough(SkinData.Rarity.EPIC), _skin(SkinData.Rarity.RARE, 5), _dough(SkinData.Rarity.LEGENDARY)],
			false, PILE_MEDIUM, false, 0, 0.9)
		await _capture("17_overflow_stress_6_reveal_top")
		await _settle(REVEAL_BASE + REVEAL_PER_CARD * 6.0)
		await _capture("17_overflow_stress_6_scrolled_end")
		# Başa kaydır: kartlar erişilebilir, altlık yerinde.
		var scroll: ScrollContainer = _main._result.frame().get_meta(&"scroll")
		scroll.scroll_vertical = 0
		await _settle(0.3)
		await _capture("17_overflow_stress_6_scrolled_top")
		await _leave_board()
	# 18 Level 10 tamam → Sonsuz Mod açıldı rozeti (yalnız bu round açtıysa).
	await _shot("18", "level10_complete_endless_unlocked", LEVEL_10, true, 5210,
		[_dough(SkinData.Rarity.RARE), _dough(SkinData.Rarity.COMMON)], false, PILE_MEDIUM, true, 8)
	# 19 Sonsuz: yeni rekor (tepelikli) / rekorsuz (lavanta), ödülsüz ve bonuslu.
	SaveManager.data["endless_high_score"] = 9860
	await _shot("19", "endless_new_record", ENDLESS, false, 9860, [], true, PILE_DANGER)
	SaveManager.data["endless_high_score"] = 12480
	await _shot("19b", "endless_no_record_bonus", ENDLESS, false, 7410,
		[_dough(SkinData.Rarity.COMMON)], false, PILE_DANGER)
	SaveManager.data["endless_high_score"] = 0
	# 22 yeni level açıldı (L4 → LEVEL 5 AÇILDI) — kazanma + yeni kilit.
	await _shot("22", "new_level_unlock", LEVEL_04, true, s3, [_dough(SkinData.Rarity.RARE)],
		false, PILE_MEDIUM, true, 6)
	# 11b uzun hedef metni (L8: tier + skor).
	await _shot("23", "win_l8_score_objective", LEVEL_08, true, 6980, [_dough(SkinData.Rarity.COMMON)])
	# 02b kayıp: hedef tier tamam ama skor yetmedi (L8).
	await _shot("24", "fail_l8_score_short", LEVEL_08, false, 4120, [_consolation()], false, PILE_MEDIUM, false, 7)

	# 20 / 21 gerçek buton yolu: basılı görünüm → bırakış → rota.
	if _wants("20"):
		await _open(LEVEL_04, false, 640, [_consolation()], false, PILE_DANGER, false, 5)
		var retry: Button = _main._result.primary_button()
		var pos: Vector2 = retry.get_global_rect().get_center()
		_pointer(pos, true)
		await get_tree().process_frame
		await get_tree().process_frame
		await _capture("20_retry_pressed_down")
		_pointer(pos, false)
		await _settle(0.6)
		await _capture("20_retry_released_board_restarted")
		await _leave_board()
	if _wants("21"):
		await _open(LEVEL_04, true, s3, [_dough(SkinData.Rarity.RARE)], false, PILE_MEDIUM, true, 6)
		# Harita bu round'un açtığı düğümü okusun (bellekte; dosya yazılmaz).
		SaveManager.data["highest_level_unlocked"] = 5
		SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3, "4": 3}
		var map_button: Button = _main._result.primary_button()
		var pos2: Vector2 = map_button.get_global_rect().get_center()
		_pointer(pos2, true)
		await get_tree().process_frame
		await get_tree().process_frame
		await _capture("21_map_pressed_down")
		_pointer(pos2, false)
		await _settle(0.75)
		await _capture("21_map_released_unlock_animation")
		await _settle(1.2)
		await _capture("21_map_released_settled")
		_apply_showcase()
		await _leave_board()
	_apply_showcase()
