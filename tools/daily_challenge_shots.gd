extends Node
## MEYDAN OKUMA (TASK/047) QA çekimleri. Dev aracı — oyun çalışırken kullanılmaz.
## `--headless` İLE ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn`, sabit gün (`DailyRewards.clock_override`: 2026-10-01 perşembe T5 · 420 · 15,
## 2026-10-02 cuma T6 · 540 · 36). SAHİBİN KAYDINA DOKUNMAZ: SaveManager çekim boyunca
## `user://qa_daily_challenge_shots/` altındaki bir yola yönlendirilir, çıkışta gerçek yola ve belleğe
## geri döner, test dosyaları silinir.
##
##   H  Ana Sayfa  01 giriş (+20, T5) · 02 tamamlandı (tik) · 03 banner yuvasıyla (sahte arka uç,
##                 yuva magenta plakayla işaretli — gerçek banner masaüstünde çizilemez)
##   S  Pencere    04 T5 · 05 T6 · 06 tamamlandı
##   G  Oyun       07 T5 başlangıç · 08 T6 başlangıç · 09 son hamle (HAMLE 1, SIRADAKİ yok) ·
##                 10 yatışma ("Hamle bitti", HAMLE 0, bırakış çizgisinde parça yok)
##   R  Sonuç      11 ilk başarı (+20) · 12 taşma · 13 hamle bitti (+ "Hedefe çok yaklaştın!") ·
##                 14 gün değişti · 15 ödül zaten alındı
##
## Kullanım:
##   godot --resolution GxY --path . res://tools/daily_challenge_shots.tscn -- <çıktı> [GxY] [safe=61] [only=HSGR]
## Her karenin piksel boyutu DOĞRULANIR; tutmazsa "BOYUT HATASI" ve çıkış kodu 3 (5 PNG
## yazılamadı, 6 hiç kare yok, 4 `--headless`).

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SHOT_SIZE := Vector2i(720, 1280)
const DIR: String = "user://qa_daily_challenge_shots"
const PATH: String = DIR + "/save.json"
const THU: String = "2026-10-01"
const FRI: String = "2026-10-02"
const OVERLAY_COLOR := Color(1.0, 0.0, 0.8, 0.38)

var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _main: Node2D
var _main_script: GDScript = load("res://scripts/main.gd")
var _saved_data: Dictionary = {}
var _safe_top: float = -1.0
var _only: String = ""
var _shots: int = 0
var _size_errors: int = 0
var _png_errors: int = 0
var _finished: bool = false
var _redirected: bool = false
var _overlay: CanvasLayer


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("HATA: --headless ile çalışmaz (ekran görüntüsü). Kayda dokunulmadı.")
		_finished = true
		get_tree().quit(4)
		return
	DailyRewards.auto_popup_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://daily_challenge_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_size = _shot_size(args)
	for arg in args:
		if String(arg).begins_with("safe="):
			_safe_top = float(String(arg).trim_prefix("safe="))
		if String(arg).begins_with("only="):
			_only = String(arg).trim_prefix("only=")
	DisplayServer.window_set_size(_size)
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.window_get_size() != _size:
		push_warning("pencere %s istendi, %s çalışıyor — `--resolution %dx%d` ile başlatın" % [
			str(_size), str(DisplayServer.window_get_size()), _size.x, _size.y])

	_saved_data = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	SaveManager.save_path = PATH
	_redirected = true
	DailyRewards.clock_override = THU
	get_tree().create_timer(840.0).timeout.connect(func() -> void:
		if not _finished:
			print("HATA: bekçi — çekim 840 s'de bitmedi, SaveManager geri alındı")
			_finish(2))
	_write_fixture()
	SaveManager.load_game()
	await _make_main(null)

	if _wants("H"):
		await _home_states()
	if _wants("S"):
		await _sheet_states()
	if _wants("G"):
		await _game_states()
	if _wants("R"):
		await _result_states()

	print("bitti -> %s (%d kare, %d boyut hatası, %d PNG hatası)" % [_out_dir, _shots, _size_errors, _png_errors])
	if _shots == 0:
		print("HATA: hiç kare çekilmedi (only=%s geçersiz mi?)" % _only)
	_finish(3 if _size_errors > 0 else (5 if _png_errors > 0 else (6 if _shots == 0 else 0)))


func _finish(code: int) -> void:
	if _finished:
		return
	_finished = true
	if _main != null and is_instance_valid(_main):
		_main.free()
	_restore()
	get_tree().quit(code)


func _exit_tree() -> void:
	if _finished:
		return
	_finished = true
	print("HATA: çekim bitmeden ağaçtan çıkıldı — SaveManager geri alındı")
	_restore()


func _restore() -> void:
	if not _redirected:
		return
	DailyRewards.clock_override = ""
	_main_script.set("ads_backend_override", null)
	UiKit.set_banner_slot(0.0)
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


func _wants(group: String) -> bool:
	return _only.is_empty() or _only.contains(group)


func _make_main(fake: FakeAdBackend) -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await get_tree().process_frame
		await get_tree().process_frame
	_main_script.set("ads_backend_override", fake)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_main_script.set("ads_backend_override", null)
	if _safe_top >= 0.0:
		_main._screens[0]._layout_with_safe_top(_safe_top)
		_main._challenge_sheet.layout_with_safe_top(_safe_top)


# --- H: Ana Sayfa ----------------------------------------------------------------------------

func _home_states() -> void:
	_completed("")
	await _show_home("01_home_challenge")
	_completed(THU)
	await _show_home("02_home_challenge_done")
	_completed("")
	# Banner yuvası: sahte arka uç (rıza + init) → Ana Sayfa alt payı; yuva magenta plakayla.
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	await _make_main(fake)
	fake.complete_consent_update(true)
	fake.complete_init()
	await get_tree().process_frame
	_build_overlay(_main._ads.banner_slot_px())
	await _show_home("03_home_challenge_banner")
	_overlay.queue_free()
	_overlay = null
	await _make_main(null)
	UiKit.set_banner_slot(0.0)


func _show_home(name: String) -> void:
	_main._show_tab(1)
	await get_tree().process_frame
	_main._show_tab(0)
	await _settle()
	await _capture(name)


# --- S: Pencere ------------------------------------------------------------------------------

func _sheet_states() -> void:
	_completed("")
	await _show_sheet("04_sheet_t5")
	DailyRewards.clock_override = FRI
	await _show_sheet("05_sheet_t6")
	DailyRewards.clock_override = THU
	_completed(THU)
	await _show_sheet("06_sheet_done")
	_completed("")


func _show_sheet(name: String) -> void:
	_main._show_tab(0)
	await get_tree().process_frame
	_main.open_daily_challenge()
	await get_tree().create_timer(UiMotion.MODAL_TIME + 0.4).timeout
	await get_tree().process_frame
	await _capture(name)
	_main._challenge_sheet.close_sheet(false)
	await _settle()


# --- G: Oyun ---------------------------------------------------------------------------------

func _game_states() -> void:
	_completed("")
	await _start("07_game_t5")
	await _leave()
	DailyRewards.clock_override = FRI
	await _start("08_game_t6")
	await _leave()
	DailyRewards.clock_override = THU
	await _start("")
	# Hedef ulaşılmaz kılınır (yalnız çekim): 14 bırakışta tesadüfen kazanılıp ekran sonuca geçmesin.
	_main._board.level.target_tier = 8
	for i in 14:
		await _quick_drop(i)
	# Zincir / combo rozeti sönsün (COMBO_WINDOW 1.2 s + sönüş), tahta otursun.
	await get_tree().create_timer(4.0).timeout
	await _capture("09_game_one_left")
	await _quick_drop(14)
	# Son parça indi (~1.2 s düşüş), yatışma sürüyor (inişten sonraki 1.5 s merge'siz pencere dolmadan).
	await get_tree().create_timer(1.6).timeout
	await _capture("10_game_settle")
	await _leave()


func _start(name: String) -> void:
	_main._show_tab(0)
	await get_tree().process_frame
	_main.start_daily_challenge()
	# A36 punch-hole payı board'a da (HUD üst satırı + kap); sonuç penceresi bu board'un üstünde açılır.
	if _safe_top >= 0.0 and _main._board != null:
		_main._board._apply_layout(get_viewport().get_visible_rect().size, _safe_top)
	await _settle()
	await get_tree().create_timer(0.4).timeout
	if not name.is_empty():
		await _capture(name)


func _leave() -> void:
	if _main._board != null:
		_main._result.hide_result()
		_main._leave_daily_challenge()
	await _settle()


func _quick_drop(i: int) -> void:
	var board: Node2D = _main._board
	board._drop_cooldown = 0.0
	board._set_aim(board._left_x() + 40.0 + float((i * 131) % int(board.level.container_width - 80.0)))
	board._drop()
	await get_tree().create_timer(0.12).timeout


# --- R: Sonuç ----------------------------------------------------------------------------------

func _result_states() -> void:
	_completed("")
	SaveManager.data["dough"] = 335
	# 11 ilk başarı (gerçek akış: iki gerçek bırakış + gerçek merge ile hedef).
	await _start("")
	for i in 2:
		await _quick_drop(i)
	await _win()
	await _wait_result("11_result_first_clear")
	await _leave()
	_completed("")
	# 12 taşma (gerçek akış).
	await _start("")
	for i in 3:
		await _quick_drop(i)
	await _overflow()
	await _wait_result("12_result_overflow")
	await _leave()
	# 13 hamle bitti + "Hedefe çok yaklaştın!" (bir tier kalmış sonuç — sunum).
	await _start("")
	_main._result.show_challenge_result({"won": false, "rewarded": false, "reward": 0,
		"fail_reason": DailyChallenge.FailReason.MOVES_EXHAUSTED, "drops_used": 15, "drop_budget": 15,
		"target_tier": 5, "reached_tier": 4, "day_changed": false})
	await _reveal_capture("13_result_moves_close")
	await _leave()
	# 14 gün değişti (gerçek akış: perşembe başlar, cuma biter).
	await _start("")
	DailyRewards.clock_override = FRI
	await _overflow()
	await _wait_result("14_result_day_changed")
	DailyRewards.clock_override = THU
	await _leave()
	# 15 ödül zaten alındı (savunma kopyası — sunum).
	await _start("")
	_main._result.show_challenge_result({"won": true, "rewarded": false, "reward": 0,
		"fail_reason": DailyChallenge.FailReason.NONE, "drops_used": 9, "drop_budget": 15,
		"target_tier": 5, "reached_tier": 5, "day_changed": false})
	await _reveal_capture("15_result_already_rewarded")
	await _leave()


func _win() -> void:
	var board: Node2D = _main._board
	var tier: int = board.level.target_tier - 1
	var r: float = TierConfig.radius(tier)
	var floor_y: float = float(board.get_script().get_script_constant_map()["FLOOR_Y"])
	var x: float = board._right_x() - r - 12.0
	board._spawn_dumpling(tier, Vector2(x, floor_y - r - 1.0))
	board._spawn_dumpling(tier, Vector2(x, floor_y - 3.0 * r - 30.0))
	var guard: int = 0
	while not board.is_finished() and guard < 400:
		await get_tree().physics_frame
		guard += 1


func _overflow() -> void:
	var board: Node2D = _main._board
	var left: float = board._left_x()
	var width: float = board.level.container_width
	var floor_y: float = float(board.get_script().get_script_constant_map()["FLOOR_Y"])
	for row in 3:
		for column in 2:
			board._spawn_dumpling(8, Vector2(left + width * (0.25 if column == 0 else 0.75),
				floor_y - 101.0 - 205.0 * float(row)))
	var guard: int = 0
	while not board.is_finished() and guard < 900:
		await get_tree().physics_frame
		guard += 1


func _wait_result(name: String) -> void:
	await get_tree().create_timer(_main.RESULT_DELAY + 0.2).timeout
	await _reveal_capture(name)


func _reveal_capture(name: String) -> void:
	var result: CanvasLayer = _main._result
	var waited: int = 0
	while not result.is_reveal_done() and waited < 60 * 6:
		await get_tree().process_frame
		waited += 1
	await get_tree().create_timer(0.8).timeout
	await _capture(name)


# --- Kayıt durumları -----------------------------------------------------------------------------

func _write_fixture() -> void:
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 2},
		"endless_high_score": 0, "dough": 335, "total_merges": 40, "merges_since_bonus_chest": 10,
		"unlocked_skins": ["common_01", "rare_02"], "profile_showcase": ["rare_02"],
		"powerups": {"bomb": 2, "upgrade": 1, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "", "daily_streak": 3,
		"last_login_date": Time.get_date_string_from_system(), "age_ad_band": "ADULT", "next_age_transition_date": "",
		"player_meta_version": 1, "player_xp": 400, "total_rounds_played": 12, "highest_tier_created": 5,
		"daily_rewards": {"day_key": THU, "free_chest_claimed": false, "ad_chests_claimed": 0,
			"dough_ad_claimed": false, "popup_seen_day": THU, "last_seen_day_key": THU}}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(content, "\t"))
	file.close()


func _completed(day: String) -> void:
	SaveManager.data["daily_challenge"] = {"version": 1, "completed_day_key": day}


## Banner'ın kaplayacağı bölge (banner_slot_shots ile aynı işaret; production'da çizim yok).
func _build_overlay(slot: float) -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 100
	add_child(_overlay)
	var view: Vector2 = get_viewport().get_visible_rect().size
	var rect := ColorRect.new()
	rect.color = OVERLAY_COLOR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = Vector2(0.0, view.y - UiKit.safe_bottom(view) - slot)
	rect.size = Vector2(view.x, slot)
	_overlay.add_child(rect)


# --- Çekim ---------------------------------------------------------------------------------------

func _settle() -> void:
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame


func _tag() -> String:
	return "%dx%d%s" % [_size.x, _size.y, "_a36" if _safe_top >= 0.0 else ""]


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var file: String = "%s_%s.png" % [name, _tag()]
	var err: int = img.save_png(_out_dir.path_join(file))
	_shots += 1
	if err != OK:
		_png_errors += 1
	if img.get_size() != _size:
		_size_errors += 1
		print("BOYUT HATASI: %s = %s, beklenen %s" % [file, str(img.get_size()), str(_size)])
	print(("kaydedildi : " if err == OK else "HATA       : "), file, " ", img.get_size())


func _shot_size(args: PackedStringArray) -> Vector2i:
	if args.size() < 2:
		return SHOT_SIZE
	var parts: PackedStringArray = args[1].split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return SHOT_SIZE
	return Vector2i(int(parts[0]), int(parts[1]))


func _clean() -> void:
	for path in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
