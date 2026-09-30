extends Node
## Yaş ekranı QA çekimleri (TASK/046.1 — 13+ GÜN / AY / YIL seçicileri). Dev aracı — oyun
## çalışırken kullanılmaz. `--headless` İLE ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn` + `FakeAdBackend` (eklentisiz masaüstünde reklam yöneticisi olmadan yaş
## ekranı hiç açılmaz; sahte arka uç internete / SDK'ya gitmez, rıza hiç tamamlanmaz). Sabit
## "bugün" 2026-09-30 (`AgeGate.clock_override`). Tarihler sentetiktir.
## SAHİBİN KAYDINA DOKUNMAZ: SaveManager çekim boyunca `user://qa_age_gate_shots/` altındaki
## bir yola yönlendirilir, çıkışta gerçek yola ve belleğe döner, test dosyaları silinir.
##
##   01 zorunlu, boş seçiciler (Ana Sayfa üstünde)   02 kısmi seçim (yıl + ay)
##   03 YIL ızgarası (en genç yıl ilk)               04 GÜN ızgarası (en genç ay: 1..30)
##   05 en genç izinli tarih (30 Eylül 2013, tam 13)  06 genç seçimi (15 Haziran 2010)
##   07 yetişkin seçimi (30 Eylül 2008, 18. yaş günü) 08 onay adımı (30 Eylül 2008 / Doğru mu?)
##   09 nötr hata (bozuk saat: "Tarihi kontrol edip tekrar dene.")
##   10 Ayarlar → Yaş bilgisi yeniden giriş (boş)    11 yeniden giriş "kaydedildi"
##
## Kullanım:
##   godot --resolution GxY --path . res://tools/age_gate_shots.tscn -- <çıktı> [GxY] [safe=61]
## Her karenin piksel boyutu DOĞRULANIR; tutmazsa "BOYUT HATASI" ve çıkış kodu 3 (5 PNG
## yazılamadı, 6 hiç kare yok, 4 `--headless`).

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SHOT_SIZE := Vector2i(720, 1280)
const DIR: String = "user://qa_age_gate_shots"
const PATH: String = DIR + "/save.json"
const TODAY: String = "2026-09-30"

var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _main: Node2D
var _saved_data: Dictionary = {}
var _safe_top: float = -1.0
var _shots: int = 0
var _size_errors: int = 0
var _png_errors: int = 0
var _finished: bool = false
var _redirected: bool = false
var _main_script: GDScript = load("res://scripts/main.gd")


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("HATA: --headless ile çalışmaz (ekran görüntüsü). Kayda dokunulmadı.")
		_finished = true
		get_tree().quit(4)
		return
	DailyRewards.auto_popup_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://age_gate_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_size = _shot_size(args)
	for arg in args:
		if String(arg).begins_with("safe="):
			_safe_top = float(String(arg).trim_prefix("safe="))
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
	AgeGate.clock_override = TODAY
	get_tree().create_timer(600.0).timeout.connect(func() -> void:
		if not _finished:
			print("HATA: bekçi — çekim 600 s'de bitmedi, SaveManager geri alındı")
			_finish(2))
	_write_fixture()
	SaveManager.load_game()

	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.REQUIRED
	_main_script.set("ads_backend_override", fake)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_main_script.set("ads_backend_override", null)
	await get_tree().process_frame
	await get_tree().process_frame
	if _safe_top >= 0.0:
		for screen in _main._screens:
			if screen.has_method("_layout_with_safe_top"):
				screen._layout_with_safe_top(_safe_top)
		_panel().layout_with_safe_top(_safe_top)

	await _required_states()
	await _reentry_states()

	print("bitti -> %s (%d kare, %d boyut hatası, %d PNG hatası)" % [_out_dir, _shots, _size_errors, _png_errors])
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
	AgeGate.clock_override = ""
	_main_script.set("ads_backend_override", null)
	UiKit.set_banner_slot(0.0)
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


func _clean() -> void:
	for path in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _panel() -> CanvasLayer:
	return _main.age_panel()


# --- Zorunlu kip -----------------------------------------------------------------------------

func _required_states() -> void:
	var panel: CanvasLayer = _panel()
	await _settle(0.8)
	if not panel.visible:
		print("HATA: zorunlu yaş ekranı açılmadı")
		return
	await _capture("01_required_empty")
	_pick(2, 2010)
	_pick(1, 6)
	await _settle()
	await _capture("02_partial_year_month")
	_reset()
	panel.selector_button(2).pressed.emit()
	await _settle()
	await _capture("03_picker_year_youngest_first")
	panel.close_picker()
	_pick(2, 2013)
	_pick(1, 9)
	panel.selector_button(0).pressed.emit()
	await _settle()
	await _capture("04_picker_day_youngest_month")
	panel.option_button(30).pressed.emit()
	await _settle()
	await _capture("05_youngest_valid_13")
	_select(15, 6, 2010)
	await _settle()
	await _capture("06_teen_selection")
	_select(30, 9, 2008)
	await _settle()
	await _capture("07_adult_selection")
	panel.continue_button().pressed.emit()
	await _settle()
	await _capture("08_confirmation")
	panel.fix_button().pressed.emit()
	AgeGate.clock_override = "2026-09-26"
	panel.continue_button().pressed.emit()
	AgeGate.clock_override = TODAY
	await _settle()
	await _capture("09_neutral_error")
	_select(30, 9, 2008)
	panel.continue_button().pressed.emit()
	panel.confirm_button().pressed.emit()
	await _settle(0.6)


## Seçimi siler (panel aynı kipte yeniden açılır; seçiciler boş).
func _reset() -> void:
	var panel: CanvasLayer = _panel()
	if panel.is_reentry():
		panel.open_reentry()
	else:
		panel.open_required()


func _pick(field: int, value: int) -> void:
	var panel: CanvasLayer = _panel()
	panel.selector_button(field).pressed.emit()
	var option: Button = panel.option_button(value)
	if option == null:
		print("HATA: ızgarada yok: ", value)
		panel.close_picker()
		return
	option.pressed.emit()


func _select(day: int, month: int, year: int) -> void:
	_reset()
	_pick(2, year)
	_pick(1, month)
	_pick(0, day)


# --- Yeniden giriş -------------------------------------------------------------------------------

func _reentry_states() -> void:
	if _main.age_band() != AgeGate.Band.ADULT:
		print("HATA: zorunlu giriş ADULT ile çözülmedi")
		return
	_main.open_settings()
	await _settle()
	_main._settings.age_info_button().pressed.emit()
	await _settle(0.8)
	await _capture("10_settings_reentry_empty")
	_select(1, 1, 1990)
	var panel: CanvasLayer = _panel()
	panel.continue_button().pressed.emit()
	panel.confirm_button().pressed.emit()
	await _settle()
	await _capture("11_settings_reentry_done")
	panel.done_button().pressed.emit()
	_main.close_settings()
	await _settle()


# --- Kayıt ------------------------------------------------------------------------------------------

## Eski oyuncu, yaş bilgisi YOK (TASK/043 öncesi kayıt) — açılışta zorunlu yaş ekranı.
func _write_fixture() -> void:
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 2},
		"endless_high_score": 0, "dough": 335, "total_merges": 40, "merges_since_bonus_chest": 0,
		"unlocked_skins": ["common_01", "rare_02"], "profile_showcase": ["rare_02"],
		"powerups": {"bomb": 2, "upgrade": 1, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "", "daily_streak": 3,
		"last_login_date": Time.get_date_string_from_system(),
		"player_meta_version": 1, "player_xp": 400, "total_rounds_played": 12, "highest_tier_created": 5}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(content, "\t"))
	file.close()


# --- Çekim ---------------------------------------------------------------------------------------

func _settle(seconds: float = 0.5) -> void:
	await get_tree().create_timer(seconds).timeout
	await get_tree().process_frame


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
	await _drawn_frame()
	await _drawn_frame()
	var img: Image = get_viewport().get_texture().get_image()
	var file: String = "%s_%s.png" % [name, _tag()]
	if img.get_size() != _size:
		_size_errors += 1
		print("BOYUT HATASI: %s %s != %s" % [file, str(img.get_size()), str(_size)])
	var err: int = img.save_png(_out_dir.path_join(file))
	if err == OK:
		_shots += 1
	else:
		_png_errors += 1
	print(("kaydedildi : " if err == OK else "HATA       : "), file)


## Bir çizilmiş kare bekler; 30 karede çizim gelmezse (pencere görünmez) kareyi zorla çizdirir.
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
