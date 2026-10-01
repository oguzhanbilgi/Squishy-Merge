extends Node
## TASK/047 — MEYDAN OKUMA arayüzü testi (Ana Sayfa girişi + pencere + oyun HUD'u + sonuç). Headless.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_daily_challenge_ui/` altındaki
## bir yola yönlendirilir, sonda geri alınır; gerçek kayıt ailesi başta / sonda karşılaştırılır.
##
##   godot --headless --audio-driver Dummy --path . res://tools/daily_challenge_ui_test.tscn
##
## Kontroller:
##   giriş       Ana Sayfa'da TEK MEYDAN OKUMA girişi (ButtonHomePill, GÖREVLER'in hemen altında), bugünün
##               hedef portresi, "+20" (tamamlanmadan) / tik (tamamlanınca); GÖREVLER N/6 aynen; Harita'da
##               yok; onboarding bitmeden gizli; tutorial günü (ilk gün kuralı YOK) görünür; gün gerçeği yoksa gizli
##   pencere     kurdele "MEYDAN OKUMA", "Büyük Dumpling yap · 15 hamlede" (T5) / "Dev Dumpling yap · 36
##               hamlede" (T6), "+20 HAMUR · İlk tamamlayışta", ipucu, yalıtım notu, BAŞLA; tamamlandı:
##               TAMAMLANDI çipi + "Yarın yenilenir" + KAPAT (BAŞLA / ödül yok, yalıtım notu durur)
##   girdi       Android geri / X / karartma / KAPAT kapatır; hızlı çift dokunuş sızmaz (300 ms dizi
##               kuralı aynen); BAŞLA → meydan okuma round'u; açmak / kapatmak kayda yazmaz
##   kapılar     sandık / ayarlar / günlük / GÖREVLER / yaş ekranı açıkken açılmaz; açıkken onlar altına
##               açılmaz, otomatik günlük pencere "due" kalır; ekran / round geçişi kapatır
##   gece yarısı açık pencere gün dönünce BAŞLA eski günü BAŞLATMAZ — pencere bugüne tazelenir; öne dönüş
##               de tazeler
##   HUD         BUGÜN / HAMLE / tepsiler gizli; mola / ayarlar dönüşünde de gizli; normal round aynen
##   sonuç       ilk başarı / ödül zaten alındı / taşma / hamle bitti (+ "Hedefe çok yaklaştın!") / gün
##               değişti kopyaları + butonlar; ardından normal sonuç kendi düzenine döner
##   yerleşim    320×568 / 360×640 / 390×844 / 360×800 / 1080×2340 (+ A36 üst payı 61) + banner yuvası:
##               giriş güvenli alanda, ≥ 48, ortalı, hiçbir kontrolle / maskotun opak pikselleriyle /
##               logoyla çakışmıyor, OYNA / level / banner serbest; pencere ekranda, kırpma yok
##   kaynak      giriş / pencere kayda yazmaz, reklam çağırmaz

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_daily_challenge_ui"
const PATH: String = DIR + "/save.json"
const THU: String = "2026-10-01"
const FRI: String = "2026-10-02"
const MON: String = "2026-09-28"
const VIEWS: Array[Vector2i] = [Vector2i(320, 568), Vector2i(360, 640), Vector2i(390, 844), Vector2i(360, 800),
	Vector2i(1080, 2340)]
const A36_SAFE_TOP: float = 61.0
const SECTIONS: int = 10
const DUMPLING_VISUAL: GDScript = preload("res://scripts/game/dumpling_visual.gd")

var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _finished: bool = false
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _main: Node2D
var _main_script: GDScript
var _mascot_img: Image


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_main_script = load("res://scripts/main.gd")
	# Gerçek çıkış asla: geri tuşu kontrolleri yalnız sayar.
	_main_script.set("quit_suppressed", true)
	_owner_state = _owner_snapshot()
	_saved_data = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	SaveManager.save_path = PATH
	DailyRewards.clock_override = THU
	get_tree().create_timer(400.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 400 s'de bitmedi — SaveManager geri alındı")
			if _main != null and is_instance_valid(_main):
				_main.free()
			_teardown()
			get_tree().quit(2))
	_write_fixture()
	SaveManager.load_game()
	await _resize(Vector2i(720, 1280))
	await _boot()
	_mascot_img = (_home().HERO_ART as Texture2D).get_image()

	await _entry()
	await _sheet_content()
	await _input_contract()
	await _gates()
	await _midnight_sheet()
	await _hud_in_round()
	await _result_states()
	await _layout_all()
	await _ads_banner()
	_source_contract()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	print("-- kayıt")
	await _teardown_main()
	_teardown()
	_c("SaveManager gerçek yola döndü, test klasörü silindi, saat kancası / hata enjeksiyonu boş",
		SaveManager.save_path == SaveManager.SAVE_PATH and not DirAccess.dir_exists_absolute(DIR)
		and DailyRewards.clock_override == "" and SaveFile.fault == SaveFile.Fault.NONE)
	_c("sahibin gerçek kayıt ailesi (kanonik + .tmp + .bak) bayt-aynı", _owner_snapshot() == _owner_state)
	_finished = true
	print("\nSONUC: %d kontrol, %d hata" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _exit_tree() -> void:
	if _finished:
		return
	print("  [FAIL] test SONUC'tan önce ağaçtan çıktı — SaveManager geri alındı")
	_teardown()


func _teardown() -> void:
	SaveFile.fault = SaveFile.Fault.NONE
	DailyRewards.clock_override = ""
	DailyRewards.auto_popup_enabled = false
	if _main_script != null:
		_main_script.set("quit_suppressed", false)
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	UiKit.set_banner_slot(0.0)
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- 1) Ana Sayfa girişi ----------------------------------------------------------------------------

func _entry() -> void:
	print("-- Ana Sayfa MEYDAN OKUMA girişi")
	var home: CanvasLayer = _home()
	await _show_home()
	var entry: Button = home.challenge_button()
	_c("tek MEYDAN OKUMA girişi: ButtonHomePill (GÖREVLER ile aynı aile), dokunma alır, görünür", entry != null
		and entry.theme_type_variation == &"ButtonHomePill" and entry.mouse_filter == Control.MOUSE_FILTER_STOP
		and entry.is_visible_in_tree() and _count_named(home, "Challenge") == 1)
	_c("etiket 'MEYDAN OKUMA'", home.challenge_title_text() == "MEYDAN OKUMA")
	_c("bugünün hedef portresi (perşembe T5 sanatı), '+20' rozeti (tamamlanmadı)",
		home.challenge_portrait_texture() == DUMPLING_VISUAL.TEXTURES[4] and home.challenge_badge_text() == "+20"
		and not home.is_challenge_done_shown())
	_c("GÖREVLER girişi ve N/6 anlamı aynen (tek giriş, '0/6'), madalyonlar 4, beş ekran",
		_count_named(home, "Missions") == 1 and home.missions_count_text() == "0/6"
		and _count_class(home, "HomeFeatureButton") == 4 and _main._screens.size() == 5)
	var missions: Rect2 = home.missions_button().get_global_rect()
	var rect: Rect2 = entry.get_global_rect()
	_c("giriş GÖREVLER'in HEMEN altında (4–16 px), ortalı", rect.position.y >= missions.end.y + 4.0
		and rect.position.y <= missions.end.y + 16.0 and absf(rect.get_center().x - missions.get_center().x) <= 2.0)
	_c("Harita'da meydan okuma yok (giriş yalnız Ana Sayfa'da)", _count_named(_main._screens[1], "Challenge") == 0)
	SaveManager.data["daily_challenge"] = {"version": 1, "completed_day_key": THU}
	await _show_home()
	_c("tamamlanınca: tik rozeti (+20 yok)", home.is_challenge_done_shown() and home.challenge_badge_text() == "")
	SaveManager.data["daily_challenge"] = DailyChallenge.default_block()
	DailyRewards.clock_override = FRI
	await _show_home()
	_c("cuma: T6 hedef portresi, '+20'", home.challenge_portrait_texture() == DUMPLING_VISUAL.TEXTURES[5]
		and home.challenge_badge_text() == "+20")
	DailyRewards.clock_override = THU
	SaveManager.data["onboarding_completed_day"] = THU
	await _show_home()
	_c("tutorial'ın bitirildiği gün (günlük ödüller kilitli) giriş GÖRÜNÜR — ilk gün kuralı uygulanmaz",
		not Onboarding.daily_rewards_unlocked() and entry.is_visible_in_tree())
	SaveManager.data["onboarding_completed_day"] = ""
	SaveManager.data["onboarding_completed"] = false
	home.refresh_daily_challenge()
	_c("onboarding bitmeden giriş gizli, kod yolu pencere açmaz", not entry.visible and not _open_now())
	SaveManager.data["onboarding_completed"] = true
	DailyRewards.clock_override = "bozuk-saat"
	SaveManager.data["daily_rewards"]["last_seen_day_key"] = ""
	home.refresh_daily_challenge()
	_c("gün gerçeği yok: giriş gizli, pencere açılmaz", not entry.visible and not _open_now())
	DailyRewards.clock_override = THU
	SaveManager.data["daily_rewards"]["last_seen_day_key"] = THU
	await _show_home()
	_c("gün geri gelince giriş görünür", entry.is_visible_in_tree())
	_sections_done += 1


## Kod yolundan açmayı dener; açıldıysa kapatıp true döner.
func _open_now() -> bool:
	_main.open_daily_challenge()
	var opened: bool = _sheet().visible
	if opened:
		_sheet().close_sheet(false)
	return opened


# --- 2) Pencere içeriği ----------------------------------------------------------------------------

func _sheet_content() -> void:
	print("-- MEYDAN OKUMA penceresi içeriği")
	var sheet: DailyChallengeOverlay = _sheet()
	await _show_home()
	await _wait_settled()
	await _open()
	var ribbon: PanelContainer = sheet.frame().get_meta(&"ribbon")
	_c("kurdele 'MEYDAN OKUMA'", (ribbon.get_meta(&"title_label") as Label).text == "MEYDAN OKUMA")
	_c("ana satır (perşembe): 'Büyük Dumpling yap · 15 hamlede'", sheet.goal_text() == "Büyük Dumpling yap · 15 hamlede")
	_c("ödül: '+20 HAMUR · İlk tamamlayışta'", sheet.reward_text() == "+20 HAMUR · İlk tamamlayışta")
	_c("ipucu: 'Her gün yeni meydan okuma. Parça sırası gün boyu aynı; istediğin kadar dene.'",
		sheet.hint_text() == "Her gün yeni meydan okuma. Parça sırası gün boyu aynı; istediğin kadar dene.")
	_c("yalıtım notu: 'Görev, XP ve sandık ilerlemesine sayılmaz.'",
		sheet.isolation_text() == "Görev, XP ve sandık ilerlemesine sayılmaz.")
	_c("BAŞLA görünür, KAPAT CTA / TAMAMLANDI yok", sheet.start_button().is_visible_in_tree()
		and _cta_text(sheet.start_button()) == "BAŞLA" and not sheet.close_cta().visible and not sheet.is_done_shown())
	_c("portre: hedef tier sanatı (T5)", _portrait_texture(sheet) == DUMPLING_VISUAL.TEXTURES[4])
	sheet.close_sheet(false)
	await _wait_settled()
	DailyRewards.clock_override = FRI
	await _open()
	_c("cuma (T6): 'Dev Dumpling yap · 36 hamlede' + T6 portresi (Büyük Dumpling yazmaz)",
		sheet.goal_text() == "Dev Dumpling yap · 36 hamlede" and _portrait_texture(sheet) == DUMPLING_VISUAL.TEXTURES[5])
	sheet.close_sheet(false)
	await _wait_settled()
	DailyRewards.clock_override = THU
	SaveManager.data["daily_challenge"] = {"version": 1, "completed_day_key": THU}
	await _open()
	_c("tamamlandı: TAMAMLANDI çipi + 'Yarın yenilenir' + KAPAT; BAŞLA / ödül / ipucu yok, yalıtım notu durur",
		sheet.is_done_shown() and sheet.tomorrow_text() == "Yarın yenilenir" and sheet.close_cta().is_visible_in_tree()
		and _cta_text(sheet.close_cta()) == "KAPAT" and not sheet.start_button().visible and sheet.reward_text() == ""
		and sheet.hint_text() == "" and sheet.isolation_text() == "Görev, XP ve sandık ilerlemesine sayılmaz.")
	sheet.close_cta().pressed.emit()
	await _settle(2)
	_c("KAPAT pencereyi kapatır, Ana Sayfa'da kalınır, round başlamaz", not sheet.visible and _main._board == null
		and _main._active_tab == 0)
	SaveManager.data["daily_challenge"] = DailyChallenge.default_block()
	await _wait_settled()
	_sections_done += 1


# --- 3) Girdi -----------------------------------------------------------------------------------------

func _input_contract() -> void:
	print("-- girdi: geri / X / karartma / hızlı çift dokunuş / BAŞLA")
	var sheet: DailyChallengeOverlay = _sheet()
	var home: CanvasLayer = _home()
	await _show_home()
	await _wait_settled()
	await _open()
	_main._last_back_msec = -1000
	_main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(2)
	_c("Android geri: pencere kapandı, Ana Sayfa'da kalındı (uygulama kapanmadı)", not sheet.visible
		and _main._active_tab == 0 and home.visible and _main.quit_requests == 0)
	await _wait_settled()
	await _open()
	sheet.close_button().pressed.emit()
	await _settle(2)
	_c("X: pencere kapandı", not sheet.visible)
	await _wait_settled()
	var entry_pos: Vector2 = _screen_center(home.challenge_button())
	await _finger_tap(entry_pos)
	_c("parmak: giriş → pencere açık", sheet.visible)
	var dim_pos: Vector2 = _dim_point(sheet.frame())
	await _finger_tap(dim_pos)
	_c("açılışın hemen ardından karartmaya dokunuş yutuldu (sızma yok)", sheet.visible)
	await _wait_settled()
	await _finger_tap(dim_pos)
	_c("yatışmadan sonra karartma dokunuşu kapatır", not sheet.visible)
	await _finger_tap(entry_pos)
	_c("kapanışın hemen ardından girişe dokunuş yutuldu: yeniden açılmadı", not sheet.visible)
	await _wait_settled()
	await _finger_tap(entry_pos)
	_c("yatışmadan sonra giriş yine açar", sheet.visible)
	await _wait_settled()
	var bytes: PackedByteArray = _bytes()
	SaveFile.fault = SaveFile.Fault.TEMP_OPEN
	sheet.close_button().pressed.emit()
	await _wait_settled()
	await _open()
	sheet.close_sheet(false)
	await _wait_settled()
	_c("açmak / kapatmak kayda yazmadı (bayt-aynı, yazma girişimi yok)", _bytes() == bytes
		and SaveFile.fault == SaveFile.Fault.TEMP_OPEN)
	SaveFile.fault = SaveFile.Fault.NONE
	await _open()
	await _wait_settled()
	var start_pos: Vector2 = _screen_center(sheet.start_button())
	await _finger_tap(start_pos)
	await _physics(4)
	_c("parmak: BAŞLA → pencere kapandı, MEYDAN OKUMA round'u başladı (bugünün günü); BAŞLA'nın bırakışı parça düşürmedi",
		not sheet.visible and _main._board != null and _main._board.is_daily_challenge() and _main._challenge_day == THU
		and _main._board.drops_used() == 0)
	await _finger_tap(start_pos)
	await _physics(4)
	_c("BAŞLA'ya hızlı ikinci dokunuş yeni board'a bırakış olarak DÜŞMEDİ (300 ms yatışma)",
		_main._board.drops_used() == 0)
	await _wait_settled()
	var board: Node2D = _main._board
	var world := Vector2(board._center_x() - 60.0, board.overflow_line_y() + 60.0)
	await _finger_tap(get_viewport().get_screen_transform() * board.world_to_screen(world))
	await _physics(4)
	_c("yatışmadan sonra ilk tahta dokunuşu tam bir bırakış (hamle 15 → 14)", _main._board.drops_used() == 1
		and _main._board._hud.score_label.text == "14")
	await _wait_settled()
	await _leave_round()
	_sections_done += 1


# --- 4) Kapılar ----------------------------------------------------------------------------------------

func _gates() -> void:
	print("-- kapılar: başka pencere açıkken açılmaz; açıkken altına pencere açılmaz; geçişler kapatır")
	var sheet: DailyChallengeOverlay = _sheet()
	await _show_home()
	await _wait_settled()
	var refused: Array[String] = []
	var opened: Array[String] = []
	_main._on_chest_requested()
	await _settle(2)
	if _main._chest_info.visible:
		opened.append("sandık")
	if _open_now():
		refused.append("sandık")
	_main._chest_info.close_info()
	await _wait_settled()
	_main.open_settings()
	await _settle(2)
	if _main._settings.visible:
		opened.append("ayarlar")
	if _open_now():
		refused.append("ayarlar")
	_main.close_settings()
	await _wait_settled()
	_main.open_daily_rewards()
	await _settle(2)
	if _main._daily_rewards.visible:
		opened.append("günlük")
	if _open_now():
		refused.append("günlük")
	_main._daily_rewards.close_popup()
	await _wait_settled()
	_main.open_missions()
	await _settle(2)
	if _main._missions.visible:
		opened.append("görevler")
	if _open_now():
		refused.append("görevler")
	_main._missions.close_missions(false)
	await _wait_settled()
	_main._age_panel.visible = true
	if _open_now():
		refused.append("yaş ekranı")
	_main._age_panel.visible = false
	await _wait_settled()
	_c("ön koşul: sandık / ayarlar / günlük / GÖREVLER gerçekten açıldı %s" % str(opened), opened.size() == 4)
	_c("sandık / ayarlar / günlük / GÖREVLER / yaş ekranı açıkken MEYDAN OKUMA açılmaz %s" % str(refused), refused.is_empty())
	await _open()
	_main._on_chest_requested()
	_main.open_daily_rewards()
	_main.open_missions()
	await _settle(2)
	_c("pencere açıkken sandık / günlük / GÖREVLER altına açılmaz (aynı katman 12)", sheet.visible
		and not _main._chest_info.visible and not _main._daily_rewards.visible and not _main._missions.visible)
	DailyRewards.auto_popup_enabled = true
	SaveManager.data["daily_rewards"]["popup_seen_day"] = ""
	_main._maybe_auto_open_daily_rewards()
	await _settle(2)
	_c("otomatik günlük pencere pencerenin üstüne açılmaz, 'due' kalır", sheet.visible and not _main._daily_rewards.visible
		and DailyRewards.popup_due())
	DailyRewards.auto_popup_enabled = false
	SaveManager.data["daily_rewards"]["popup_seen_day"] = THU
	_main._show_tab(3)
	await _settle(2)
	var on_tab: bool = not sheet.visible and _main._active_tab == 3
	_main._show_tab(0)
	await _wait_settled()
	await _open()
	_main._close_secondary_windows()
	await _settle(2)
	var on_close_all: bool = not sheet.visible
	await _wait_settled()
	await _open()
	_main._start_level(_level(2))
	await _settle(2)
	var on_round: bool = not sheet.visible and _main._board != null
	_main.open_daily_challenge()
	var in_round: bool = not sheet.visible
	_main.abandon_run()
	await _settle(2)
	_main._show_tab(0)
	await _wait_settled()
	_c("Mağaza'ya geçiş / pencereleri kapatma / round başlangıcı pencereyi kapatır; round sırasında açılmaz (%s · %s · %s · %s)"
		% [str(on_tab), str(on_close_all), str(on_round), str(in_round)], on_tab and on_close_all and on_round and in_round)
	_main._show_tab(4)
	await _settle(2)
	_main.open_daily_challenge()
	_c("Ana Sayfa dışında (Profil) açılmaz", not sheet.visible)
	_main._show_tab(0)
	await _wait_settled()
	_sections_done += 1


# --- 5) Gece yarısı: açık pencere -------------------------------------------------------------------

func _midnight_sheet() -> void:
	print("-- gece yarısı: açık pencerenin BAŞLA'sı eski günü başlatmaz")
	var sheet: DailyChallengeOverlay = _sheet()
	await _show_home()
	await _wait_settled()
	await _open()
	await _wait_settled()
	_c("ön koşul: pencere perşembeyi gösteriyor", sheet.shown_day() == THU)
	DailyRewards.clock_override = FRI
	var start_pos: Vector2 = _screen_center(sheet.start_button())
	await _finger_tap(start_pos)
	await _settle(2)
	_c("gün döndü: parmakla BAŞLA round BAŞLATMADI, pencere bugüne (cuma T6·540·36) tazelendi", _main._board == null
		and sheet.visible and sheet.shown_day() == FRI and sheet.goal_text() == "Dev Dumpling yap · 36 hamlede")
	_c("  … Ana Sayfa girişi de cumaya tazelendi (T6 portresi)", _home().challenge_portrait_texture() == DUMPLING_VISUAL.TEXTURES[5])
	await _finger_tap(start_pos)
	await _settle(2)
	_c("tazelemenin hemen ardından hızlı ikinci parmak dokunuşu YUTULDU (300 ms yatışma): yeni gün görülmeden başlamadı",
		_main._board == null and sheet.visible and sheet.shown_day() == FRI)
	await _wait_settled()
	await _finger_tap(_screen_center(sheet.start_button()))
	await _settle(3)
	_c("yatışmadan sonra BAŞLA: cumanın meydan okuması başlar (bütçe 36)", _main._board != null and _main._challenge_day == FRI
		and _main._board.drop_budget() == 36)
	await _leave_round()
	DailyRewards.clock_override = THU
	SaveManager.record_daily_last_seen_day(THU)
	SaveManager.data["daily_rewards"]["last_seen_day_key"] = THU
	await _show_home()
	await _wait_settled()
	await _open()
	DailyRewards.clock_override = FRI
	_main._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _settle(2)
	_c("öne dönüş: açık pencere ve giriş yeni güne tazelendi (yalnız okuyarak)", sheet.visible and sheet.shown_day() == FRI
		and _home().challenge_portrait_texture() == DUMPLING_VISUAL.TEXTURES[5])
	sheet.close_sheet(false)
	DailyRewards.clock_override = THU
	SaveManager.data["daily_rewards"]["last_seen_day_key"] = THU
	await _wait_settled()
	_sections_done += 1


# --- 6) Oyun HUD'u ---------------------------------------------------------------------------------------

func _hud_in_round() -> void:
	print("-- oyun HUD'u: BUGÜN / HAMLE / güç tepsileri gizli")
	_c("ön koşul: meydan okuma başladı", _main.start_daily_challenge())
	await _settle(3)
	var hud: GameplayHud = _main._board._hud
	_c("rozet BUGÜN, plaka HAMLE 15, tepsiler + madalyonlar gizli, hedef kartı Büyük Dumpling",
		hud.level_label.text == "BUGÜN" and hud.score_caption.text == "HAMLE" and hud.score_label.text == "15"
		and not hud.tray_left.visible and not hud.tray_right.visible and not hud.power_bar.visible
		and hud.goal_label.text == "Büyük Dumpling")
	_main.open_pause_menu()
	await _settle(2)
	_main.resume_game()
	await _settle(2)
	_main._on_board_settings_requested()
	await _settle(2)
	_main.close_settings()
	await _settle(2)
	_c("mola + ayarlar dönüşü: tepsiler gizli, çubuk kapalı kalır", not hud.tray_left.visible and not hud.power_bar.visible
		and not hud.power_bar.is_enabled())
	_c("geri tuşu round'da mola açar (uygulama kapanmaz)", await _back_opens_pause())
	await _leave_round()
	_main._start_level(_level(2))
	await _settle(3)
	hud = _main._board._hud
	_c("normal round HUD aynen: '2' rozeti, SKOR, tepsiler görünür", hud.level_label.text == "2"
		and hud.score_caption.text == "SKOR" and hud.tray_left.visible and hud.power_bar.visible)
	_main.open_pause_menu()
	_main.abandon_run()
	await _settle(2)
	_main._show_tab(0)
	await _wait_settled()
	_sections_done += 1


func _back_opens_pause() -> bool:
	_main._last_back_msec = -1000
	_main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(2)
	var ok: bool = _main.is_pause_open() and _main.quit_requests == 0
	_main.resume_game()
	await _settle(2)
	return ok


# --- 7) Sonuç durumları -------------------------------------------------------------------------------

func _result_states() -> void:
	print("-- sonuç: meydan okuma kopyaları")
	var result: CanvasLayer = _main._result
	var base: Dictionary = {"won": true, "rewarded": true, "reward": 20, "fail_reason": DailyChallenge.FailReason.NONE,
		"drops_used": 17, "drop_budget": 18, "target_tier": 5, "reached_tier": 5, "day_changed": false}
	result.show_challenge_result(base)
	await _settle(3)
	_c("ilk başarı: 'MEYDAN OKUMA TAMAM!' · '+20 HAMUR' · HAMLE '17 / 18' · 'Yarın yenilenir' · yalnız ANA SAYFA",
		result.title_text() == "MEYDAN OKUMA TAMAM!" and result.challenge_body_text() == "+20 HAMUR"
		and result.challenge_moves_text() == "17 / 18" and result.challenge_footer_text() == "Yarın yenilenir"
		and result.primary_text() == "ANA SAYFA" and not result.secondary_button().visible and result.topper().visible
		and result.cards().is_empty() and not result.progress_strip().visible)
	var already: Dictionary = base.duplicate()
	already["rewarded"] = false
	already["reward"] = 0
	result.show_challenge_result(already)
	await _settle(2)
	_c("ödül zaten alındı: 'Bugünün ödülü zaten alındı.' (ek ödül yok)", result.title_text() == "MEYDAN OKUMA TAMAM!"
		and result.challenge_body_text() == "Bugünün ödülü zaten alındı.")
	var overflow: Dictionary = base.duplicate()
	overflow["won"] = false
	overflow["rewarded"] = false
	overflow["fail_reason"] = DailyChallenge.FailReason.OVERFLOW
	overflow["reached_tier"] = 4
	result.show_challenge_result(overflow)
	await _settle(2)
	_c("taşma: 'OLMADI' · 'Kap taştı. Sıra aynı, tekrar dene!' · TEKRAR DENE + ANA SAYFA (yaklaştın notu YOK)",
		result.title_text() == "OLMADI" and result.challenge_body_text() == "Kap taştı. Sıra aynı, tekrar dene!"
		and result.primary_text() == "TEKRAR DENE" and result.secondary_text() == "ANA SAYFA"
		and result.secondary_button().visible and result.encourage_text() == "" and result.primary_action() == "retry")
	var moves: Dictionary = overflow.duplicate()
	moves["fail_reason"] = DailyChallenge.FailReason.MOVES_EXHAUSTED
	moves["drops_used"] = 18
	result.show_challenge_result(moves)
	await _settle(2)
	_c("hamle bitti (bir tier kaldı): 'Hamlen bitti. Sıra aynı, tekrar dene!' + 'Hedefe çok yaklaştın!' + HEDEF + HAMLE 18 / 18",
		result.title_text() == "OLMADI" and result.challenge_body_text() == "Hamlen bitti. Sıra aynı, tekrar dene!"
		and result.encourage_text() == "Hedefe çok yaklaştın!" and result.target_text() == "Büyük Dumpling"
		and result.challenge_moves_text() == "18 / 18")
	moves["reached_tier"] = 3
	result.show_challenge_result(moves)
	await _settle(2)
	_c("hamle bitti (iki tier kaldı): yaklaştın notu yok", result.encourage_text() == "")
	var changed: Dictionary = overflow.duplicate()
	changed["day_changed"] = true
	result.show_challenge_result(changed)
	await _settle(2)
	_c("gün değişti: 'Gün değişti · yeni meydan okuma hazır.' · YENİ MEYDAN OKUMA + ANA SAYFA",
		result.title_text() == "OLMADI" and result.challenge_body_text() == "Gün değişti · yeni meydan okuma hazır."
		and result.primary_text() == "YENİ MEYDAN OKUMA" and result.secondary_text() == "ANA SAYFA")
	var retry_hits: Array[int] = [0]
	var exit_hits: Array[int] = [0]
	var on_retry := func() -> void: retry_hits[0] += 1
	var on_exit := func() -> void: exit_hits[0] += 1
	result.retry_pressed.connect(on_retry)
	result.exit_pressed.connect(on_exit)
	result.retry_pressed.disconnect(_main._on_retry_pressed)
	result.exit_pressed.disconnect(_main._on_exit_pressed)
	result.primary_button().pressed.emit()
	result.secondary_button().pressed.emit()
	result.show_challenge_result(base)
	await _settle(2)
	result.primary_button().pressed.emit()
	result.secondary_button().pressed.emit()
	_c("butonlar: kayıpta birincil = tekrar, ikincil = çıkış; başarıda birincil = çıkış, ikincil YOK",
		retry_hits[0] == 1 and exit_hits[0] == 2)
	result.retry_pressed.disconnect(on_retry)
	result.exit_pressed.disconnect(on_exit)
	result.retry_pressed.connect(_main._on_retry_pressed)
	result.exit_pressed.connect(_main._on_exit_pressed)
	var empty: Array[ChestReward] = []
	result.show_result(_level(3), false, 120, 0, empty, false, false, 4)
	await _settle(2)
	_c("ardından normal sonuç kendi düzeninde: meydan okuma parçaları gizli, ikincil + HAMUR çipi geri",
		result.challenge_body_text() == "" and result.challenge_moves_text() == "" and result.challenge_footer_text() == ""
		and result.secondary_button().visible and result.title_text() == "OLMADI" and result.primary_text() == "TEKRAR DENE"
		and result.secondary_text() == "HARİTA" and result.dough_text() != "")
	result.hide_result()
	await _settle(2)
	# Gerçek akış (Main): sonuç açılırken mevcut 300 ms yatışma kurulur — açılışın hemen ardından başlayan
	# dokunuş düğmeye basmaz; yatışmadan sonra parmakla TEKRAR DENE, hızlı ikinci dokunuş yeni board'a düşmez.
	await _show_home()
	await _wait_settled()
	_main.start_daily_challenge()
	await _settle(3)
	var failed: Node2D = _main._board
	var attempt: int = _main._challenge_attempt
	failed._finish(false)
	var guard: int = 0
	while not result.visible and guard < 240:
		await get_tree().process_frame
		guard += 1
	await _finger_tap(_screen_center(result.primary_button()))
	await _settle(2)
	_c("sonuç açılır açılmaz parmak dokunuşu TEKRAR DENE'ye BASMADI (300 ms yatışma): aynı deneme, sonuç açık",
		result.visible and _main._challenge_attempt == attempt and _main._board == failed)
	await _wait_settled()
	var primary_pos: Vector2 = _screen_center(result.primary_button())
	await _finger_tap(primary_pos)
	await _physics(2)
	await _finger_tap(primary_pos)
	await _physics(4)
	_c("yatışmadan sonra parmakla TEKRAR DENE: yeni deneme baştan; hızlı ikinci dokunuş yeni board'a bırakış OLMADI",
		not result.visible and _main._challenge_attempt == attempt + 1 and _main._board != null
		and _main._board.is_daily_challenge() and _main._board.drops_used() == 0)
	await _leave_round()
	# Açık kayıp sonucu gece yarısını geçer: TEKRAR DENE'ye hızlı çift parmak — ilki sonucu "Gün değişti"ye
	# yeniler (+300 ms yatışma), ikincisi YUTULUR; yeni günün meydan okuması ancak yatışmadan sonra başlar.
	_main.start_daily_challenge()
	await _settle(3)
	failed = _main._board
	attempt = _main._challenge_attempt
	failed._finish(false)
	guard = 0
	while not result.visible and guard < 240:
		await get_tree().process_frame
		guard += 1
	await _wait_settled()
	DailyRewards.clock_override = FRI
	primary_pos = _screen_center(result.primary_button())
	await _finger_tap(primary_pos)
	await _finger_tap(primary_pos)
	await _settle(2)
	_c("gece yarısını açık geçen kayıp sonucu: TEKRAR DENE'ye çift parmak — sonuç 'Gün değişti'ye yenilendi, ikinci dokunuş yeni günü BAŞLATMADI",
		result.visible and result.challenge_body_text() == "Gün değişti · yeni meydan okuma hazır."
		and result.primary_text() == "YENİ MEYDAN OKUMA" and _main._challenge_attempt == attempt
		and _main._board == failed)
	await _wait_settled()
	await _finger_tap(_screen_center(result.primary_button()))
	await _settle(3)
	_c("  … yatışmadan sonra YENİ MEYDAN OKUMA: cumanın meydan okuması (bütçe 36)", not result.visible
		and _main._challenge_day == FRI and _main._board != null and _main._board.drop_budget() == 36)
	await _leave_round()
	DailyRewards.clock_override = THU
	SaveManager.data["daily_rewards"]["last_seen_day_key"] = THU
	_sections_done += 1


# --- 8) Yerleşim -------------------------------------------------------------------------------------------

func _layout_all() -> void:
	print("-- yerleşim: 320 / 360 / 390 dp + 1080×2340 + A36 üst payı")
	for view in VIEWS:
		await _resize(view)
		await _layout_view(view, -1.0)
	await _resize(VIEWS[4])
	await _layout_view(VIEWS[4], A36_SAFE_TOP)
	await _resize(VIEWS[0])
	SaveManager.data["daily_challenge"] = {"version": 1, "completed_day_key": THU}
	await _layout_view(VIEWS[0], -1.0, "tamamlandı")
	SaveManager.data["daily_challenge"] = DailyChallenge.default_block()
	DailyRewards.clock_override = FRI
	await _layout_view(VIEWS[0], -1.0, "T6")
	DailyRewards.clock_override = THU
	await _resize(Vector2i(720, 1280))
	_home()._layout_with_safe_top(-1.0)
	_sheet().layout_with_safe_top(-1.0)
	await _show_home()
	_sections_done += 1


func _layout_view(view_size: Vector2i, safe_top: float, variant: String = "") -> void:
	var home: CanvasLayer = _home()
	var view: Vector2 = get_viewport().get_visible_rect().size
	var tag: String = "%dx%d (tuval %dx%d)%s%s" % [view_size.x, view_size.y, roundi(view.x), roundi(view.y),
		" +A36" if safe_top > 0.0 else "", (" " + variant) if variant != "" else ""]
	var top: float = maxf(safe_top, 0.0)
	home._layout_with_safe_top(safe_top)
	_sheet().layout_with_safe_top(safe_top)
	await _show_home()
	var entry: Button = home.challenge_button()
	var rect: Rect2 = entry.get_global_rect()
	var screen := Rect2(Vector2(0, top), Vector2(view.x, view.y - top))
	_c("%s giriş ekranda, üst payın altında, ≥ 48, ortalı (±2)" % tag, entry.is_visible_in_tree()
		and screen.encloses(rect) and rect.size.x >= 48.0 and rect.size.y >= 48.0
		and absf(rect.get_center().x - view.x * 0.5) <= 2.0)
	var overlap: Array[String] = []
	for node in _all_nodes(home):
		if node == entry or not (node is BaseButton) or not (node as BaseButton).is_visible_in_tree():
			continue
		if entry.is_ancestor_of(node) or node.is_ancestor_of(entry):
			continue
		var other: Rect2 = (node as HomeFeatureButton).visual_rect() if node is HomeFeatureButton else (node as Control).get_global_rect()
		var inter: Rect2 = rect.intersection(other)
		if inter.size.x > 1.0 and inter.size.y > 1.0:
			overlap.append(String(node.name))
	_c("%s giriş hiçbir kontrolle çakışmıyor (GÖREVLER, madalyon plakaları, avatar, pill'ler, level, OYNA) %s"
		% [tag, str(overlap)], overlap.is_empty())
	var missions: Rect2 = home.missions_button().get_global_rect()
	_c("%s GÖREVLER'in hemen altında (4–16 px)" % tag, rect.position.y >= missions.end.y + 4.0
		and rect.position.y <= missions.end.y + 16.0)
	var logo: Rect2 = home.logo().get_global_rect()
	_c("%s logonun altında, maskotun opak piksellerine değmiyor" % tag, rect.position.y >= logo.end.y
		and not _mascot_hits(home.mascot_rect(), rect))
	_c("%s OYNA / level pill / banner bölgesi serbest" % tag, rect.end.y < home.level_button().get_global_rect().position.y
		and rect.end.y < view.y * 0.5)
	var clip: Array[String] = []
	for node in _all_nodes(entry):
		if node is Label and (node as Label).is_visible_in_tree():
			var label: Label = node
			if _text_width(label, label.text) > label.size.x + 0.5 or not rect.grow(0.5).encloses(label.get_global_rect()):
				clip.append(label.text)
	_c("%s giriş yazıları kırpılmıyor, pill içinde %s" % [tag, str(clip)], clip.is_empty())
	var sheet: DailyChallengeOverlay = _sheet()
	await _open()
	var frame: Rect2 = sheet.frame().get_global_rect()
	var ribbon: Rect2 = (sheet.frame().get_meta(&"ribbon") as Control).get_global_rect()
	var close: Rect2 = sheet.close_button().get_global_rect()
	_c("%s pencere ekranda: kurdele / X üst payın altında, gövde ekran içinde, banner yuvasının üstünde" % tag,
		ribbon.position.y >= top - 0.5 and close.position.y >= top - 0.5 and frame.position.x >= 0.0
		and frame.end.x <= view.x + 0.5 and frame.end.y <= view.y - UiKit.bottom_inset(view) + 0.5)
	_c("%s X ≥ 48, ekranda" % tag, close.size.x >= 48.0 and close.size.y >= 48.0 and Rect2(Vector2.ZERO, view).encloses(close))
	var cta: Button = sheet.close_cta() if sheet.close_cta().visible else sheet.start_button()
	var cta_rect: Rect2 = cta.get_global_rect()
	_c("%s CTA (%s) pencere içinde, ≥ 48" % [tag, _cta_text(cta)], frame.grow(0.5).encloses(cta_rect)
		and cta_rect.size.y >= 48.0)
	var host: Control = sheet.frame().get_meta(&"body_host")
	var scroll: ScrollContainer = sheet.frame().get_meta(&"scroll")
	var texts: Array[String] = []
	for node in _all_nodes(sheet.frame()):
		if not (node is Label) or not (node as Label).is_visible_in_tree():
			continue
		var label: Label = node
		if host.is_ancestor_of(label):
			scroll.ensure_control_visible(label)
			await _settle(1)
		var fits: bool = label.get_visible_line_count() >= label.get_line_count() \
			if label.autowrap_mode != TextServer.AUTOWRAP_OFF \
			else _text_width(label, label.text) <= label.size.x + 0.5
		var lr: Rect2 = label.get_global_rect()
		var inside: bool = lr.position.x >= frame.position.x - 0.5 and lr.end.x <= frame.end.x + 0.5
		if host.is_ancestor_of(label):
			inside = inside and host.get_global_rect().grow(1.0).encloses(lr)
		if not fits or not inside:
			texts.append(label.text)
	scroll.scroll_vertical = 0
	_c("%s pencere metinleri kırpılmıyor, erişilebilir %s" % [tag, str(texts)], texts.is_empty())
	sheet.close_sheet(false)
	await _wait_settled()


# --- 9) Reklam / banner ----------------------------------------------------------------------------------

func _ads_banner() -> void:
	print("-- reklam: pencere yeni yüzey değil, banner yuvasının üstüne oturur")
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	await _boot(fake)
	fake.complete_consent_update(true)
	fake.complete_init()
	await _settle(2)
	var ads: MonetizationManager = _main._ads
	if fake.banner_loads > 0:
		fake.complete_banner_load(true)
	await _settle(2)
	await _show_home()
	await _wait_settled()
	_c("ön koşul: Ana Sayfa'da banner gösterimde", ads != null and ads.banner_state() == MonetizationManager.BannerState.SHOWN)
	var calls: int = fake.calls.size()
	var shows: int = fake.banner_shows.size()
	_home().challenge_button().pressed.emit()
	await _settle(2)
	_c("pencere açıldı: yüzey HOME aynen, arka uca çağrı yok, yeni banner gösterimi yok", _sheet().visible
		and ads.surface() == MonetizationManager.Surface.HOME and fake.calls.size() == calls
		and fake.banner_shows.size() == shows)
	var view: Vector2 = get_viewport().get_visible_rect().size
	_c("pencere banner yuvasının ÜSTÜNDE (yuva %.0f px)" % UiKit.banner_slot(), UiKit.banner_slot() > 0.0
		and _sheet().frame().get_global_rect().end.y <= view.y - UiKit.bottom_inset(view) + 0.5)
	var rect: Rect2 = _home().challenge_button().get_global_rect()
	_c("banner'lı düzende giriş OYNA / level pill'in üstünde", rect.end.y < _home().level_button().get_global_rect().position.y)
	_sheet().close_sheet()
	await _settle(2)
	_c("pencere kapandı: arka uca çağrı yok", fake.calls.size() == calls)
	await _teardown_main()
	UiKit.set_banner_slot(0.0)
	await _boot()
	_sections_done += 1


# --- 10) Kaynak sözleşmesi -------------------------------------------------------------------------------

func _source_contract() -> void:
	print("-- kaynak sözleşmesi")
	var files: Array[String] = ["res://scripts/ui/daily_challenge_overlay.gd"]
	var tokens: Array[String] = ["save_game", "SaveManager.data", "complete_daily_challenge", "add_dough",
		"MonetizationManager", "AdEvents", "show_rewarded", "try_show_interstitial", "set_surface"]
	var hits: Array[String] = []
	for path in files:
		var code: String = _strip_comments(FileAccess.get_file_as_string(path))
		for token in tokens:
			if code.contains(token):
				hits.append("%s: %s" % [path.get_file(), token])
	var home_code: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/home_screen.gd"))
	var home_fn: String = _function(home_code, "func refresh_daily_challenge(")
	for token in tokens:
		if home_fn.contains(token):
			hits.append("home_screen.refresh_daily_challenge: %s" % token)
	_c("pencere ve giriş kayda yazmaz, reklam çağırmaz (bulunan: %s)" % str(hits), hits.is_empty() and home_fn.length() > 0)
	_sections_done += 1


# --- Yardımcılar -------------------------------------------------------------------------------------------

func _write_fixture() -> void:
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 2},
		"endless_high_score": 0, "dough": 335, "total_merges": 40, "merges_since_bonus_chest": 10,
		"unlocked_skins": ["common_01", "rare_02"], "profile_showcase": ["rare_02"],
		"powerups": {"bomb": 2, "upgrade": 1, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "", "daily_streak": 3,
		"last_login_date": THU, "age_ad_band": "ADULT", "next_age_transition_date": "",
		"player_meta_version": 1, "player_xp": 400, "total_rounds_played": 12, "highest_tier_created": 5,
		"daily_rewards": {"day_key": THU, "free_chest_claimed": false, "ad_chests_claimed": 0,
			"dough_ad_claimed": false, "popup_seen_day": THU, "last_seen_day_key": THU}}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(content, "\t"))
	file.close()


func _home() -> CanvasLayer:
	return _main._screens[0]


func _sheet() -> DailyChallengeOverlay:
	return _main._challenge_sheet


func _show_home() -> void:
	_main._show_tab(1)
	await _settle(1)
	_main._show_tab(0)
	await _settle(2)


func _open() -> void:
	_main.open_daily_challenge()
	await get_tree().create_timer(UiMotion.MODAL_TIME + 0.12).timeout
	await _settle(1)


func _leave_round() -> void:
	if _main._board != null:
		_main.open_pause_menu()
		await _settle(1)
		_main.abandon_run()
	await _settle(2)
	_main._show_tab(0)
	await _wait_settled()


func _cta_text(button: Button) -> String:
	return (button.get_meta(&"title_label") as Label).text


func _portrait_texture(sheet: DailyChallengeOverlay) -> Texture2D:
	for node in _all_nodes(sheet.portrait()):
		if node is TextureRect and (node as TextureRect).texture != null \
				and (node as TextureRect).texture in DUMPLING_VISUAL.TEXTURES:
			return (node as TextureRect).texture
	return null


func _boot(fake: FakeAdBackend = null) -> void:
	await _teardown_main()
	_main_script.set("ads_backend_override", fake)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _settle(3)
	_main_script.set("ads_backend_override", null)


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _settle(2)


func _level(number: int) -> LevelData:
	for level in LevelLibrary.load_levels():
		if level.level_number == number:
			return level
	return null


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _wait_settled() -> void:
	var settle_msec: int = int(_main_script.get_script_constant_map().get("TOUCH_SETTLE_MSEC", 300))
	await get_tree().create_timer(float(settle_msec) / 1000.0 + 0.12).timeout
	await get_tree().process_frame


func _screen_center(control: Control) -> Vector2:
	return get_viewport().get_screen_transform() * control.get_global_rect().get_center()


func _finger_tap(pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = pos
		touch.pressed = pressed
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		await get_tree().process_frame


func _dim_point(frame: Control) -> Vector2:
	var center: Vector2 = frame.get_global_rect().get_center()
	var final_rect := Rect2(center - frame.size * 0.5, frame.size)
	var view_h: float = get_viewport().get_visible_rect().size.y
	var below: float = view_h - final_rect.end.y
	var above: float = final_rect.position.y - UiKit.MODAL_RIBBON_OVERHANG
	var point := Vector2(center.x, final_rect.end.y + below * 0.5) if below >= above \
		else Vector2(center.x, above * 0.5)
	return get_viewport().get_screen_transform() * point


func _mascot_hits(mascot_rect: Rect2, rect: Rect2) -> bool:
	var inter: Rect2 = mascot_rect.intersection(rect)
	if inter.size.x <= 0.0 or inter.size.y <= 0.0 or _mascot_img == null:
		return false
	var kx: float = float(_mascot_img.get_width()) / mascot_rect.size.x
	var ky: float = float(_mascot_img.get_height()) / mascot_rect.size.y
	var y: float = inter.position.y
	while y < inter.end.y:
		var x: float = inter.position.x
		while x < inter.end.x:
			var px: int = clampi(int((x - mascot_rect.position.x) * kx), 0, _mascot_img.get_width() - 1)
			var py: int = clampi(int((y - mascot_rect.position.y) * ky), 0, _mascot_img.get_height() - 1)
			if _mascot_img.get_pixel(px, py).a > 0.15:
				return true
			x += 3.0
		y += 3.0
	return false


func _resize(view: Vector2i) -> void:
	get_window().size = view
	await _settle(2)


func _text_width(label: Label, text: String) -> float:
	return label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		label.get_theme_font_size("font_size")).x


func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	for child in root.get_children():
		out.append_array(_all_nodes(child))
	return out


func _count_named(root: Node, node_name: String) -> int:
	var n: int = 0
	for node in _all_nodes(root):
		if node.name == node_name:
			n += 1
	return n


func _count_class(root: Node, klass: String) -> int:
	var n: int = 0
	for node in _all_nodes(root):
		if node.get_class() == klass or (node.get_script() != null and (node.get_script() as Script).get_global_name() == klass):
			n += 1
	return n


func _strip_comments(code: String) -> String:
	var lines: PackedStringArray = []
	for line in code.split("\n"):
		var at: int = line.find("#")
		lines.append(line if at == -1 else line.substr(0, at))
	return "\n".join(lines)


func _function(code: String, header: String) -> String:
	var start: int = code.find(header)
	if start < 0:
		return ""
	var end: int = code.find("\nfunc ", start + header.length())
	return code.substr(start, (end if end >= 0 else code.length()) - start)


func _bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(PATH) if FileAccess.file_exists(PATH) else PackedByteArray()


func _clean() -> void:
	for path in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for path in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out
