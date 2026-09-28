extends Node
## TASK/045.1 — otomatik GÜNLÜK ÖDÜLLER penceresi Koleksiyon parça detayının ÜSTÜNE açılmaz
## (TASK/044 artığı; TASK/045 Başarımlar / Unvanlar kapısıyla aynı kural). Headless.
## SAHİBİN KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_daily_gate/` altındaki bir
## yola yönlendirilir.
##
##   godot --headless --audio-driver Dummy --path . res://tools/daily_popup_gate_test.tscn
##
## Kontroller:
##   kontrol        detay KAPALIYKEN aynı çağrı pencereyi açar (kapı yalnız detay varken)
##   kapı           detay açık + pencere due: sekme tazeleme (_show_tab aynı sekme), kabuk
##                  tazeleme, öne dönüş (APPLICATION_RESUMED), gün dönümü + öne dönüş, değiştirme
##                  adımı açıkken, Profil vitrini → detay geçişi → pencere AÇILMAZ, "due" kalır,
##                  bugün görüldü işaretlenmez (kayıt yazılmaz), detay açık kalır
##   sonraki fırsat detay kapanınca: öne dönüş / Ana Sayfa'ya dönüş pencereyi normal açar (tek
##                  sefer, sonra due değil); bilinmeyen parça id'si → sıradan geçiş, pencere açılır
##   kadans         otomatik pencere günde bir (gösterilince due değil), ödül / kota değişmez
##   TASK/045       Profil Başarımlar penceresi kapısı aynen

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_daily_gate"
const PATH: String = DIR + "/save.json"
const DETAIL_ID: StringName = &"common_03"
const SECTIONS: int = 5

var _main: Node2D
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _finished: bool = false


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_owner_state = _owner_snapshot()
	_saved_data = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)
	SaveManager.save_path = PATH
	var d: Dictionary = SaveManager.DEFAULT_DATA.duplicate(true)
	d["onboarding_completed"] = true
	d["age_ad_band"] = "ADULT"
	d["powerup_starter_granted"] = true
	d["last_login_date"] = Time.get_date_string_from_system()
	d["unlocked_skins"] = ["common_01", "common_03"]
	SaveManager.data = d
	SaveManager.save_game()
	get_tree().create_timer(180.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 180 s'de bitmedi")
			_teardown()
			get_tree().quit(2))
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _settle(3)
	_main._age_band = AgeGate.Band.ADULT
	var album: CanvasLayer = _main._screens[2]

	await _control(album)
	await _gate(album)
	await _next_opportunity(album)
	await _cadence_and_profile()
	_source()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	_main.queue_free()
	await _settle(2)
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


func _teardown() -> void:
	DailyRewards.auto_popup_enabled = true
	DailyRewards.clock_override = ""
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	for path in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- 1) Kontrol: kapı yalnız detay varken ------------------------------------------------------

func _control(album: CanvasLayer) -> void:
	print("-- kontrol: detay kapalıyken otomatik pencere açılır")
	_main._show_tab(2)
	await _settle(2)
	_make_due()
	_c("ön koşul: Koleksiyon'da, detay kapalı, pencere due, yaş kapısı açık", _main._active_tab == 2
		and not album.is_detail_open() and DailyRewards.popup_due() and not _main._age_blocks_monetizable_surfaces())
	_main._show_tab(2)
	await _settle(2)
	_c("detay KAPALIYKEN aynı sekme tazelemesi pencereyi açtı (bugün görüldü)", _popup().visible
		and not DailyRewards.popup_due())
	_close_popup()
	await _settle(2)
	_sections_done += 1


# --- 2) Kapı ---------------------------------------------------------------------------------------

func _gate(album: CanvasLayer) -> void:
	print("-- detay açıkken otomatik pencere açılmaz, due kalır")
	_main._show_tab(2)
	await _settle(2)
	album.open_detail(DETAIL_ID)
	await _settle(2)
	_make_due()
	var seen_before: String = SaveManager.daily_popup_seen_day()
	var bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	_c("ön koşul: detay açık (%s), pencere due" % DETAIL_ID, album.is_detail_open() and DailyRewards.popup_due())

	_main._show_tab(2)
	await _settle(2)
	_c("sekme tazeleme (_show_tab aynı sekme): pencere AÇILMADI, due, detay açık", _blocked(album))
	_main._refresh_shell_dough()
	await _settle(2)
	_c("kabuk tazeleme (_refresh_shell_dough): pencere yok, due", _blocked(album))
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)
	await _settle(2)
	_c("öne dönüş (APPLICATION_RESUMED): pencere AÇILMADI, due, detay açık", _blocked(album))
	_main._maybe_auto_open_daily_rewards()
	await _settle(2)
	_c("doğrudan otomatik açılış çağrısı: kapı tuttu", _blocked(album))
	_c("bugün görüldü işaretlenmedi, kayıt dosyası YAZILMADI", SaveManager.daily_popup_seen_day() == seen_before
		and FileAccess.get_file_as_bytes(PATH) == bytes_before)

	print("-- gün dönümü + öne dönüş, detay açık")
	DailyRewards.clock_override = _tomorrow()
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)
	await _settle(2)
	_c("yeni gün görüldü (kayda işlendi) ama pencere AÇILMADI; yeni gün için due",
		SaveManager.daily_last_seen_day_key() == _tomorrow() and _blocked(album))

	print("-- değiştirme adımı açıkken (vitrin dolu)")
	SaveManager.data["unlocked_skins"] = ["common_01", "common_03", "common_04", "common_05"]
	SaveManager.data["profile_showcase"] = ["common_01", "common_04", "common_05"]
	album.close_detail(false)
	album.open_detail(DETAIL_ID)
	album.detail_primary().pressed.emit()
	await _settle(2)
	_main._show_tab(2)
	await _settle(2)
	_c("değiştirme adımı açık + sekme tazeleme: pencere yok, due", album.is_replacing() and _blocked(album))
	album.handle_back()
	album.close_detail(false)
	await _settle(2)

	print("-- Profil vitrini → parça detayı geçişi")
	DailyRewards.auto_popup_enabled = false
	_main._show_tab(4)
	await _settle(2)
	DailyRewards.auto_popup_enabled = true
	_c("ön koşul: Profil'de, pencere due", _main._active_tab == 4 and DailyRewards.popup_due() and not _popup().visible)
	_main._on_collectible_requested(&"common_04")
	await _settle(2)
	_c("vitrin → Koleksiyon + detay: pencere detayın üstüne AÇILMADI, due", _main._active_tab == 2
		and album.detail_id() == &"common_04" and _blocked(album))
	_sections_done += 1


# --- 3) Sonraki güvenli fırsat -------------------------------------------------------------------

func _next_opportunity(album: CanvasLayer) -> void:
	print("-- detay kapanınca pencere bir sonraki güvenli fırsatta normal açılır")
	var album_ok: bool = album.is_detail_open()
	album.close_detail()
	await _settle(2)
	_c("detay kapandı; pencere kendiliğinden açılmadı (kapanış bir tetik değil), hâlâ due", album_ok
		and not album.is_detail_open() and not _popup().visible and DailyRewards.popup_due())
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)
	await _settle(2)
	_c("öne dönüş: pencere AÇILDI, bugün görüldü", _popup().visible and not DailyRewards.popup_due())
	_close_popup()
	await _settle(2)

	_make_due()
	album.open_detail(DETAIL_ID)
	await _settle(2)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)
	await _settle(2)
	_c("tekrar: detay açıkken öne dönüş engellendi", _blocked(album))
	album.close_detail()
	_main._on_home_requested()
	await _settle(2)
	_c("detay kapat → Ana Sayfa'ya dönüş: pencere Ana Sayfa'da açıldı", _main._active_tab == 0 and _popup().visible
		and not DailyRewards.popup_due())
	_close_popup()
	await _settle(2)

	print("-- bilinmeyen parça id'si: detay açılmaz → sıradan geçiş")
	DailyRewards.auto_popup_enabled = false
	_main._show_tab(4)
	await _settle(2)
	DailyRewards.auto_popup_enabled = true
	_make_due()
	_main._on_collectible_requested(&"yok_boyle_parca")
	await _settle(2)
	_c("detay açılmadı, pencere Koleksiyon'da normal açıldı", _main._active_tab == 2 and not album.is_detail_open()
		and _popup().visible)
	_close_popup()
	await _settle(2)
	_sections_done += 1


# --- 4) Kadans + TASK/045 kapısı -------------------------------------------------------------------

func _cadence_and_profile() -> void:
	print("-- kadans: günde bir, ödül / kota dokunulmadı")
	var state_before: Dictionary = DailyRewards.state()
	_main._show_tab(0)
	await _settle(2)
	_main._show_tab(2)
	await _settle(2)
	_c("aynı gün ikinci kez otomatik açılmaz (görüldü)", not _popup().visible and not DailyRewards.popup_due())
	var state_after: Dictionary = DailyRewards.state()
	_c("kotalar değişmedi (ücretsiz sandık / reklamlı sandık / Hamur reklamı)", state_after["free_chest_claimed"]
		== state_before["free_chest_claimed"] and state_after["ad_chests_claimed"] == state_before["ad_chests_claimed"]
		and state_after["dough_ad_claimed"] == state_before["dough_ad_claimed"])

	print("-- TASK/045: Profil Başarımlar penceresi kapısı aynen")
	var profile: CanvasLayer = _main._screens[4]
	DailyRewards.auto_popup_enabled = false
	_main._show_tab(4)
	await _settle(2)
	DailyRewards.auto_popup_enabled = true
	_make_due()
	profile.open_achievements()
	await _settle(2)
	_main._maybe_auto_open_daily_rewards()
	await _settle(2)
	_c("Başarımlar açıkken pencere açılmadı, due", not _popup().visible and DailyRewards.popup_due())
	profile.handle_back()
	await _settle(2)
	_main._maybe_auto_open_daily_rewards()
	await _settle(2)
	_c("kapanınca aynı çağrı açtı", _popup().visible)
	_close_popup()
	await _settle(2)
	_sections_done += 1


func _source() -> void:
	print("-- kaynak")
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var fn: String = main_src.substr(main_src.find("func _maybe_auto_open_daily_rewards()"))
	fn = fn.substr(0, fn.find("\nfunc "))
	var gate: int = fn.find("_screens[2].is_detail_open()")
	var mark: int = fn.find("DailyRewards.mark_popup_seen()")
	_c("kapı otomatik açılışta ve 'görüldü' işaretinden ÖNCE", gate != -1 and mark != -1 and gate < mark)
	_c("Profil vitrini geçişi otomatik açılışı detaydan SONRA dener",
		main_src.contains("_show_tab(2, false)\n\t_screens[2].open_detail(skin_id)"))
	_sections_done += 1


# --- Yardımcılar ------------------------------------------------------------------------------------

func _make_due() -> void:
	var raw: Dictionary = (SaveManager.data.get("daily_rewards", {}) as Dictionary).duplicate()
	raw["popup_seen_day"] = ""
	SaveManager.data["daily_rewards"] = raw
	DailyRewards.auto_popup_enabled = true


func _blocked(album: CanvasLayer) -> bool:
	return not _popup().visible and DailyRewards.popup_due() and album.is_detail_open()


func _popup() -> CanvasLayer:
	return _main._daily_rewards


func _close_popup() -> void:
	if _popup().visible:
		_popup().close_popup()


func _tomorrow() -> String:
	var unix: int = int(Time.get_unix_time_from_datetime_string(Time.get_date_string_from_system())) + 86400
	return Time.get_date_string_from_unix_time(unix)


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for path in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out
