extends Node
## TASK/046.1 — yaş ekranı GERÇEK PARMAK girdisi testi (Main + FakeAdBackend; headless). Parmak
## olayları `Input.parse_input_event` ile (ScreenTouch, device 0; Godot fareyi dokunuştan öykünür),
## Android geri = kök bildirim yayılımı. TASK/045.2 dizi bazlı 300 ms yatışma AYNEN.
## SAHİBİN KAYDINA DOKUNMAZ: SaveManager `user://qa_age_gate_ui/` altına yönlendirilir.
##
##   godot --headless --audio-driver Dummy --path . res://tools/age_gate_ui_test.tscn
##
## Bölümler:
##   zorunlu     eski kayıt (yaş yok): açılışta panel; arkadaki Ana Sayfa'ya dokunuş SIZMAZ (OYNA
##               tetiklenmez); geri uygulamadan ÇIKMAZ; seçiciye çift dokunuşun ikincisi ızgaradan
##               değer SEÇEMEZ; seçimden sonraki hızlı dokunuş ızgarayı yeniden açmaz; DEVAM ET'e
##               çift dokunuş onayı atlamaz; ONAYLA'ya çift dokunuş TEK sonuç + TEK rota, ikincisi
##               arkadaki Ana Sayfa'ya düşmez; kapandıktan sonra İLK dokunuş çalışır; seçimden önce
##               arka uca (UMP / init / banner / ödüllü / geçiş) HİÇ çağrı yok
##   yeniden     Ayarlar → Güncelle (parmakla): panel açık, banner gizli; X / Vazgeç / karartma /
##   giriş       geri kapatır (kayıt aynen); her kapanıştan sonra hızlı ikinci dokunuş yutulur,
##               yatışmadan sonraki İLK dokunuş çalışır; kapanınca banner geri gelir
##   eski        UNDER_13 kaydı: kısıt ekranı YOK, zorunlu panel, geri çıkmaz, arka uç çağrısı yok
##   kaynak      yatışma 300 ms, panel sinyalleri Main'in yatışmasına bağlı

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_age_gate_ui"
const PATH: String = DIR + "/save.json"
const TODAY: String = "2026-09-30"
const SECTIONS: int = 4
const BACK_GAP_MSEC: int = 280

var _main: Node2D
var _fake: FakeAdBackend
var _resolved: int = 0
var _play_presses: int = 0
var _last_back_msec: int = -100000
var _popup_flag_before: bool = true
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _finished: bool = false
var _main_script: GDScript = load("res://scripts/main.gd")


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	_popup_flag_before = DailyRewards.auto_popup_enabled
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_owner_state = _owner_snapshot()
	_saved_data = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)
	SaveManager.save_path = PATH
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 240 s'de bitmedi")
			_teardown(false)
			get_tree().quit(2))
	get_window().size = Vector2i(720, 1280)
	AgeGate.clock_override = TODAY
	MonetizationManager.time_scale = 0.05
	_main_script.set("quit_suppressed", true)
	await get_tree().process_frame

	await _required_mode()
	await _reentry_mode()
	await _legacy_under_13()
	_source_contract()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	await _free_main()
	_teardown()
	_c("sahibin gerçek kaydı ve kardeş .tmp / .bak adları DEĞİŞMEDİ", _owner_snapshot() == _owner_state)
	_c("SaveManager gerçek yola döndü, test klasörü silindi", SaveManager.save_path == SaveManager.SAVE_PATH
		and not DirAccess.dir_exists_absolute(DIR))
	_finished = true
	print("\nSONUC: %d kontrol, %d hata" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _exit_tree() -> void:
	if not _finished:
		_teardown()


func _teardown(restore_path: bool = true) -> void:
	DailyRewards.auto_popup_enabled = _popup_flag_before
	AgeGate.clock_override = ""
	MonetizationManager.time_scale = 1.0
	_main_script.set("quit_suppressed", false)
	_main_script.set("ads_backend_override", null)
	UiKit.set_banner_slot(0.0)
	if restore_path:
		SaveManager.save_path = SaveManager.SAVE_PATH
		SaveManager.data = _saved_data.duplicate(true)
	for path in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- Kurulum ------------------------------------------------------------------------------------

func _fixture(band: String, transition: String = "") -> Dictionary:
	var d: Dictionary = SaveManager.DEFAULT_DATA.duplicate(true)
	d["onboarding_completed"] = true
	d["powerup_starter_granted"] = true
	d["last_login_date"] = Time.get_date_string_from_system()
	d["highest_level_unlocked"] = 6
	d["dough"] = 420
	if band.is_empty():
		d.erase("age_ad_band")
		d.erase("next_age_transition_date")
	else:
		d["age_ad_band"] = band
		d["next_age_transition_date"] = transition
	return d


func _boot(band: String, transition: String = "") -> void:
	await _free_main()
	SaveManager.data = _fixture(band, transition)
	SaveManager.save_game()
	_fake = FakeAdBackend.new()
	_fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	_main_script.set("ads_backend_override", _fake)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_main_script.set("ads_backend_override", null)
	_resolved = 0
	_play_presses = 0
	_main.age_panel().resolved.connect(func(_band: int, _transition: String) -> void: _resolved += 1)
	_main._screens[0].play_pressed.connect(func() -> void: _play_presses += 1)
	await _frames(3)
	await _wait_settled()


func _free_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _frames(3)
	UiKit.set_banner_slot(0.0)


func _panel() -> CanvasLayer:
	return _main.age_panel()


# --- 1) Zorunlu kip ---------------------------------------------------------------------------------

func _required_mode() -> void:
	print("-- zorunlu: arkaya sızma yok, geri çıkmaz, çift dokunuş / çift gönderim yok, kapanış sonrası ilk dokunuş")
	await _boot("")
	var panel: CanvasLayer = _panel()
	_c("eski kayıt (yaş yok): ZORUNLU panel Ana Sayfa üstünde; arka uca HİÇ çağrı yok", panel.visible and not panel.is_reentry()
		and _main._active_tab == 0 and _fake.calls.is_empty())
	var play: Button = _main._screens[0].play_button()
	await _finger_tap(_center(play))
	await _wait_settled()
	await _finger_tap(_center(play))
	await _mouse_click(_center(play))
	await _wait_settled()
	_c("arkadaki OYNA'ya parmak + fare dokunuşu SIZMAZ (karartma yutar): OYNA 0, round yok, panel açık",
		_play_presses == 0 and (_main._board == null or not is_instance_valid(_main._board)) and panel.visible
		and _main._active_tab == 0)
	await _back()
	await _back()
	_c("zorunlu kipte Android geri (2×) uygulamadan ÇIKMAZ, panel açık", _main.quit_requests == 0 and panel.visible
		and panel.stage() == panel.Stage.ENTRY)
	await _wait_settled()
	# Seçiciye çift dokunuş: ilki ızgarayı açar, ikincisi (yatışma içinde) ızgaradan değer SEÇEMEZ.
	var year_pos: Vector2 = _center(panel.selector_button(2))
	await _finger_tap(year_pos)
	await _finger_tap(year_pos)
	_c("YIL seçicisine çift dokunuş: ızgara açık, ikinci dokunuş değer SEÇMEDİ", panel.picker_field() == 2
		and panel.selection()["year"] == 0)
	await _wait_settled()
	var picked_year: bool = await _tap_option(2010)
	_c("yatışmadan sonra ızgarada 2010'a dokunuş seçti, ızgara kapandı", picked_year and panel.selection()["year"] == 2010
		and panel.picker_field() == -1)
	await _finger_tap(_last_tap)
	_c("seçimden hemen sonraki hızlı dokunuş (yatışma içinde) ızgarayı yeniden AÇMADI / değeri değiştirmedi",
		panel.picker_field() == -1 and panel.selection()["year"] == 2010)
	await _wait_settled()
	await _finger_tap(_center(panel.selector_button(1)))
	await _wait_settled()
	var picked_month: bool = await _tap_option(9)
	await _wait_settled()
	await _finger_tap(_center(panel.selector_button(0)))
	await _wait_settled()
	var picked_day: bool = await _tap_option(15)
	await _wait_settled()
	_c("parmakla 15 Eylül 2010 seçildi (GÜN / AY / YIL)", picked_month and picked_day
		and panel.selection() == {"day": 15, "month": 9, "year": 2010} and not panel.continue_button().disabled)
	var cont: Vector2 = _center(panel.continue_button())
	await _finger_tap(cont)
	await _finger_tap(cont)
	_c("DEVAM ET'e çift dokunuş: onay adımı, ikinci dokunuş ONAYI ATLAMADI (sonuç yok)", panel.stage() == panel.Stage.CONFIRM
		and _resolved == 0 and panel.confirm_text() == "15 Eylül 2010")
	await _wait_settled()
	var confirm: Vector2 = _center(panel.confirm_button())
	await _finger_tap(confirm)
	await _finger_tap(confirm)
	await _frames(2)
	_c("ONAYLA'ya çift dokunuş: TEK sonuç, TEK rota (TEEN + T), kayıt TEEN (geçiş 18. yaş günü)", _resolved == 1
		and _fake.calls.count("set_age_restricted_treatment:TEEN") == 1 and SaveManager.age_ad_band_raw() == "TEEN"
		and SaveManager.next_age_transition_raw() == "2028-09-15")
	_c("ikinci dokunuş arkaya düşmedi: panel kapandı, Ana Sayfa'da, OYNA 0, Ayarlar / görevler kapalı",
		not panel.visible and _main._active_tab == 0 and _play_presses == 0 and not _main._settings.visible
		and not _main._missions.visible)
	await _wait_settled()
	await _finger_tap(_center(play))
	await _frames(3)
	_c("kapanış + yatışmadan sonra İLK dokunuş çalışır: OYNA tetiklendi", _play_presses == 1)
	_sections_done += 1


## Açık ızgarada değere parmakla dokunur (seçenek kaydırma alanında görünür olmalı).
var _last_tap: Vector2 = Vector2.ZERO


func _tap_option(value: int) -> bool:
	var panel: CanvasLayer = _panel()
	var option: Button = panel.option_button(value)
	if option == null:
		return false
	var view: Rect2 = (panel.frame().get_meta(&"scroll") as Control).get_global_rect()
	if not view.encloses(option.get_global_rect()):
		print("    seçenek kaydırma alanında görünmüyor: ", value)
		return false
	_last_tap = _center(option)
	await _finger_tap(_last_tap)
	return panel.picker_field() == -1


# --- 2) Yeniden giriş -------------------------------------------------------------------------------

func _reentry_mode() -> void:
	print("-- yeniden giriş: parmakla Güncelle, X / Vazgeç / karartma / geri, kapanış sonrası ilk dokunuş, banner")
	await _boot("ADULT")
	_fake.complete_consent_update(true)
	_fake.complete_init()
	await _frames(2)
	var banner: String = _fake.complete_banner_load(true)
	await _frames(2)
	var m: MonetizationManager = _main._ads
	_c("ADULT açılış: SDK hazır, banner Ana Sayfa'da", _fake.banner_shows == [banner])
	_main.open_settings()
	await _wait_settled()
	var settings: CanvasLayer = _main._settings
	var update: Vector2 = _center(settings.age_info_button())
	var panel: CanvasLayer = _panel()
	var closes: Array[String] = []
	for how: String in ["x", "vazgec", "dim", "back"]:
		await _finger_tap(update)
		await _frames(2)
		var opened: bool = panel.visible and panel.is_reentry()
		var hidden: bool = m.surface() == MonetizationManager.Surface.NONE and _fake.banner_hides.size() == closes.size() + 1
		await _finger_tap(update)
		var still_entry: bool = panel.visible and panel.stage() == panel.Stage.ENTRY and panel.picker_field() == -1
		await _wait_settled()
		var target: Vector2 = Vector2.ZERO
		match how:
			"x":
				target = _center(panel.close_x())
				await _finger_tap(target)
			"vazgec":
				target = _center(panel.cancel_button())
				await _finger_tap(target)
			"dim":
				var frame_rect: Rect2 = panel.frame().get_global_rect()
				target = _screen(Vector2(maxf(frame_rect.position.x * 0.5, 4.0), frame_rect.get_center().y))
				await _finger_tap(target)
			"back":
				await _back()
		await _frames(2)
		var closed_ok: bool = not panel.visible and settings.visible and SaveManager.age_ad_band_raw() == "ADULT"
		var restored: bool = m.surface() == MonetizationManager.Surface.HOME and _fake.banner_shows.size() == closes.size() + 2
		if how != "back":
			await _finger_tap(target)
		var swallowed: bool = settings.visible and not panel.visible
		_c("%s: Güncelle parmakla açtı (banner gizli), hızlı ikinci dokunuş yutuldu, kapandı (kayıt aynen, banner geri), kapanış sonrası hızlı dokunuş Ayarlar'ı KAPATMADI"
			% how, opened and hidden and still_entry and closed_ok and restored and swallowed)
		closes.append(how)
		await _wait_settled()
	_c("yeniden giriş boyunca çıkış isteği yok, arka uç işlemi aynen (UNSPECIFIED / MA)", _main.quit_requests == 0
		and _fake.treatment == AdBackend.AgeRestrictedTreatment.UNSPECIFIED and _fake.rating == "MA")
	var close_button: Button = settings.frame().get_meta(&"close_button")
	await _finger_tap(_center(close_button))
	await _frames(2)
	_c("son kapanış + yatışmadan sonra İLK dokunuş çalışır: Ayarlar'ın X'i Ayarlar'ı kapattı", not settings.visible)
	_sections_done += 1


# --- 3) Eski UNDER_13 -------------------------------------------------------------------------------

func _legacy_under_13() -> void:
	print("-- eski UNDER_13 kaydı: kısıt ekranı YOK, zorunlu panel, geri çıkmaz, SDK yok")
	await _boot("UNDER_13", "2029-06-01")
	var panel: CanvasLayer = _panel()
	_c("eski UNDER_13: bant UNKNOWN, ZORUNLU panel, arka uca çağrı YOK, ilerleme duruyor", _main.age_band() == AgeGate.Band.UNKNOWN
		and panel.visible and not panel.is_reentry() and _fake.calls.is_empty() and SaveManager.highest_level_unlocked() == 6
		and SaveManager.dough() == 420)
	var restricted: PackedStringArray = PackedStringArray()
	for node in _main.find_children("*", "Control", true, false):
		var control := node as Control
		if control.is_visible_in_tree():
			var text: String = (control as Label).text if control is Label else ((control as Button).text if control is Button else "")
			if text.contains("Üzgünüz") or text.contains("yaş grubun") or text == "ÇIKIŞ":
				restricted.append(text)
	_c("ekranda kısıt / çıkış metni YOK %s" % str(restricted), restricted.is_empty())
	await _back()
	_c("geri uygulamadan ÇIKMAZ", _main.quit_requests == 0 and panel.visible)
	_sections_done += 1


# --- 4) Kaynak ------------------------------------------------------------------------------------

func _source_contract() -> void:
	print("-- kaynak")
	var settle_msec: int = int(_main_script.get_script_constant_map().get("TOUCH_SETTLE_MSEC", -1))
	_c("yatışma süresi aynen 300 ms", settle_msec == 300)
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_c("panelin açılış + adım sinyalleri Main'in yatışmasına bağlı; görünürlük reklam yüzeyini yönetir",
		main_src.contains("_age_panel.opened.connect(settle_touch_input)")
		and main_src.contains("_age_panel.settle_requested.connect(settle_touch_input)")
		and main_src.contains("_age_panel.visibility_changed.connect(_on_age_panel_visibility_changed)"))
	_sections_done += 1


# --- Yardımcılar ------------------------------------------------------------------------------------

func _touch_event(pos: Vector2, pressed: bool, index: int) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = pos
	touch.pressed = pressed
	return touch


## Parmak olayı Input'a verilir ve HEMEN dağıtılır (öykünen fare önce, sonra ScreenTouch).
func _finger(pos: Vector2, pressed: bool, index: int = 0) -> void:
	Input.parse_input_event(_touch_event(pos, pressed, index))
	Input.flush_buffered_events()
	await get_tree().process_frame


func _finger_tap(pos: Vector2, index: int = 0) -> void:
	await _finger(pos, true, index)
	await _finger(pos, false, index)


## Masaüstü fare tıklaması (device 0).
func _mouse_click(pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = pos
		click.global_position = pos
		if pressed:
			click.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(click)
		Input.flush_buffered_events()
		await get_tree().process_frame


func _back() -> void:
	var gap: int = _last_back_msec + BACK_GAP_MSEC - Time.get_ticks_msec()
	if gap > 0:
		await _wait(float(gap) / 1000.0)
	_last_back_msec = Time.get_ticks_msec()
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame


## Main'in yatışması geçene kadar GERÇEK süre bekler.
func _wait_settled() -> void:
	var settle_msec: int = int(_main_script.get_script_constant_map().get("TOUCH_SETTLE_MSEC", 300))
	await _wait(float(settle_msec) / 1000.0 + 0.12)
	await get_tree().process_frame


## Tuval noktası → Input.parse_input_event'in beklediği PENCERE pikseli.
func _screen(canvas: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * canvas


func _center(control: Control) -> Vector2:
	return _screen(control.get_global_rect().get_center())


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for path in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out
