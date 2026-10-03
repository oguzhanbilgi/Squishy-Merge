extends Node
## TASK/051 — Round başlangıcında dokunuş sahipliği: bir board değişimini BAŞLATAN ya da değişim boyunca basılı kalıp
## onu ATLATAN parmak dizisi yeni board'da parça düşüremez; değişimden sonraki ilk gerçekten bağımsız dokunuş tam bir
## parça düşürür. Gerçek Main, gerçek board / HUD / mola / sonuç / Harita / meydan okuma / tutorial yolları, gerçek parmak
## olayları (`Input.parse_input_event` + boşaltma: cihazdaki sıra — öykünen fare (device -1) ÖNCE, sonra ScreenTouch
## (device 0)). Headless.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_start_level_settle/` altındaki bir yola
## yönlendirilir, sonda geri alınır; gerçek kayıt ailesi (kanonik + .tmp + .bak) başta / sonda bayt bayt karşılaştırılır.
##   godot --headless --audio-driver Dummy --path . res://tools/start_level_touch_settle_test.tscn
##
## Kök neden (build/qa_051/trace/trace.md — düzeltmesiz 1293eb2'de sondayla üretildi):
##   1. `_start_level` mevcut 300 ms parmak yatışmasını KURMUYORDU (meydan okuma başlangıcı kuruyor). Düğmenin öykünen fare
##      bırakışı yeni board'u eşzamanlı kurar; hızlı ikinci dokunuş (basılı tutulsa da) yeni board'a basış + bırakış olarak
##      düşer → 1 parça (Yeniden Başlat / sonuç TEKRAR / Harita düğümü / Sonsuz); HUD düğmesine düşerse onun eylemi.
##   2. GameBoard bırakışın basışının BU board'a ulaşıp ulaşmadığına bakmıyordu: değişimden önce basılmış ve canlı bir
##      kontrolün tutmadığı parmak (eski board'da, kabuk arka planında, serbest bırakılan HUD kontrolünde) yeni board'da
##      kalkınca 1 parça (iki parmaklı mola → Yeniden Başlat, Harita; TASK/048 ertelenen yeniden başlatma).
##   Değişimi başlatan parmağın KENDİ ScreenTouch bırakışı yeni board kurulduktan sonra gelir ama gizli düğmenin parmak
##   odağına gider: sızıntı değil — Main onu bölmemeli (bölerse TASK/045.2 hatası: sonraki tahta bırakışı kaybolur).
## Düzeltme: `_start_level` mevcut `settle_touch_input()`'u board girdiye hazır olduğu an bir kez kurar (300 ms aynen);
## GameBoard sürüklemeyi / bırakışı yalnız basışı kendisine ulaşmış dizide işler.
##
## Bölümler:
##   A normal girdi    bağımsız dokunuş tam bir parça, beklenen tier, çift bırakış yok (kontrol)
##   B basılı parmak   Yeniden Başlat: başlatan parmağın bırakışı; ikinci basış basılı; değişimi atlatan ikinci parmak
##                     (tahtada / mola karartmasında); TASK/048 ertelemesi; ilk parmak tahtadayken düğme basılamaz
##   C çift dokunuş    Yeniden Başlat'a +0 / +100 / +200 ms ikinci dokunuş; ikinci dokunuş yeni board'un HUD geri'sine
##   D sentetik        işlenmemiş olayla gizleme tıklaması tek yeniden başlatma; serbest bırakılan HUD kontrolünün parmağı
##   E sonuç TEKRAR    kayıp / kazanma TEKRAR çift ve basılı ikinci dokunuş; ilerleme / kayıt yinelenmez
##   F Harita          Ana Sayfa OYNA çift dokunuşu level başlatmaz (mevcut); düğüm çift dokunuş; iki parmak arka plan
##   G süre            300 ms; pencere board hazır olunca; içi yutulur, dışı kabul (600 ms değil)
##   H tek kurma       her yol bir kez; sonraki karelerde yeniden kurulmaz; çift çağrı uzatmaz
##   I iptal           pencerede / sonra / atlatan parmakta ACTION_CANCEL 0, sonraki bağımsız 1
##   J Devam           DEVAM ET aynı board, yatışma kurmaz, hemen sonraki dokunuş 1
##   K TASK/049        molada kesinleşme molayı kapatır; sonuç düğmeleri hemen çalışır (sonuç yatışma kurmaz)
##   L meydan okuma    BAŞLA / mola Yeniden Başlat kendi yatışması aynen; atlatan parmak hamle harcamaz
##   M Sonsuz          Sonsuz düğümü + Sonsuz'da Yeniden Başlat
##   N tutorial        açılışta `_start_level`; BAŞLA + ilk bırakış; kilitliyken basılıp açılınca kalkan parmak düşürür
##   O takılı yok      yatışmadan sonra art arda dokunuşlar kurala göre
##   P gezinme         değişimler Ana Sayfa / Ayarlar / mola / sonuç eylemi üretmez
##   Q kayıt           değişim + yutulan / sahipsiz dokunuşlar kayda yazma GİRİŞİMİ üretmez; ekonomi aynen
##   S kaynak          tek kurma noktası, 300 ms, `_input` aynen, sahiplik kapıdan önce, TASK/046.2 aynen

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_start_level_settle"
const PATH: String = DIR + "/save.json"
const SECTIONS: int = 18
const MON: String = "2026-09-28"
const THU: String = "2026-10-01"
const BACK_GAP_MSEC: int = 320
## İkinci dokunuşun başlatan dokunuşun ScreenTouch bırakışından sonraki gerçek süre aralıkları (ms): sonraki kare, tipik
## parmak çift dokunuşu, pencerenin sonuna yakın.
const SECOND_TAP_GAPS: Array[int] = [0, 100, 200]
const ACTION_KEYS: Array[String] = ["resume", "restart", "exit", "result_retry", "result_exit", "settings_closed",
	"level_chosen", "challenge_start"]

var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _finished: bool = false
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _main: Node2D
var _main_script: GDScript
var _settle_msec: int = -1
var _actions: Dictionary = {}
## Board örnek kimliği → {"enter": ms, "ready": ms, "gen": nesil, "drops": bırakış}
var _boards: Dictionary = {}
## Bırakışlar: {"board": kimlik, "msec": ms, "tier": tier, "aim": x}
var _drop_log: Array[Dictionary] = []
## Pencereye gelen parmak olayları — `window_input` Main._input'tan ÖNCE çalışır, yutulanlar da görünür.
var _inputs: Array[Dictionary] = []
var _last_back_msec: int = -100000


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_main_script = load("res://scripts/main.gd")
	_settle_msec = int(_main_script.get_script_constant_map().get("TOUCH_SETTLE_MSEC", -1))
	_owner_state = _owner_snapshot()
	_saved_data = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	SaveManager.save_path = PATH
	get_tree().create_timer(400.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 400 s'de bitmedi — SaveManager geri alındı")
			if _main != null and is_instance_valid(_main):
				_main.free()
			_teardown()
			get_tree().quit(2))
	get_window().size = Vector2i(720, 1280)
	get_tree().root.window_input.connect(_on_window_input)
	await get_tree().process_frame

	await _a_normal_input()
	await _b_restart_held()
	await _c_double_tap()
	await _d_synthetic_release()
	await _e_result_retry()
	await _f_map_home()
	await _g_settle_duration()
	await _h_single_arm()
	await _i_cancel()
	await _j_continue()
	await _k_finish_result()
	await _l_challenge()
	await _m_endless()
	await _n_tutorial()
	await _o_no_stuck()
	await _p_navigation()
	await _q_persistence()
	_s_source_contract()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	print("-- kayıt")
	await _teardown_main()
	_teardown()
	_c("SaveManager gerçek yola döndü, test klasörü silindi, saat kancası / yazma hata enjeksiyonu boş",
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
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	UiKit.set_banner_slot(0.0)
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- A) Normal tahta girdisi -----------------------------------------------------------------------------------

func _a_normal_input() -> void:
	print("-- A: normal tahta girdisi — bağımsız dokunuş tam bir parça (kontrol)")
	await _fresh()
	var board: Node2D = await _new_round(3)
	var gen: int = _gen()
	var pending: int = board._pending_tier
	var p: Vector2 = _board_point(board, -90.0)
	_inputs.clear()
	await _tap(p)
	await _physics(3)
	await _settle(2)
	_c("A bağımsız dokunuş (öykünen fare + ScreenTouch, cihaz sırası) TAM bir parça düşürdü — çift bırakış yok",
		_drops_on(board) == 1 and _count_inputs("mouse", -1) == 2 and _count_inputs("touch", 0) == 2)
	var last: Dictionary = _drop_log[-1] if not _drop_log.is_empty() else {}
	_c("  … beklenen tier (basıştaki bekleyen T%d), dokunuş noktasında" % pending, int(last.get("tier", -1)) == pending
		and _near(float(last.get("aim", -1.0)), _world_x(board, p)))
	_c("  … aynı board, nesil değişmedi, yutulan dizi yok, sahiplik kaydı kapandı", _main._board == board
		and _gen() == gen and _main._settled_sequences.is_empty() and _owned_empty(board))
	_sections_done += 1


# --- B) Yeniden Başlat: basılı parmak / değişimi atlatan parmak ----------------------------------------------------

func _b_restart_held() -> void:
	print("-- B: mola → Yeniden Başlat — başlatan parmak, basılı ikinci basış, değişimi atlatan parmak")
	await _fresh()
	# B1: başlatan parmağın KENDİ ScreenTouch bırakışı yeni board hazır olduktan SONRA gelir.
	var board: Node2D = await _new_round(3)
	var paused: bool = await _pause_hud(board)
	var tl: Dictionary = await _restart_tap()
	var nb: Node2D = _main._board
	await _physics(3)
	_c("B1 GERÇEK mola (HUD geri dokunuşu) → GERÇEK Yeniden Başlat dokunuşu: tam BİR yeniden başlatma, tam BİR yeni board (nesil +1)",
		paused and _actions["restart"] == 1 and _gen() == int(tl["gen0"]) + 1 and _differs(nb, int(tl["board0"]))
		and _boards_since(tl) == 1)
	_c("  … düğme öykünen fare bırakışında tetiklendi (board o olayda kuruldu); AYNI parmağın ScreenTouch bırakışı yeni board HAZIR olduktan sonra geldi",
		int(tl["mouse_up"]) >= 0 and int(tl["mouse_up"]) <= int(tl["enter"]) and int(tl["ready"]) >= 0
		and int(tl["touch_up"]) >= int(tl["ready"]))
	_c("  … o bırakış gizli Yeniden Başlat düğmesinin parmak odağına gitti: yeni board'da 0 bırakış, nişan merkezde; Main diziyi bölmedi",
		_drops_on(nb) == 0 and _near(nb._aim_x, nb._center_x()) and not _main._settled_sequences.has(0)
		and _owned_empty(nb))
	_c("  … mola kapalı, board donuk değil, Ana Sayfa / Ayarlar / sonuç yok", _quiet_round(nb))
	await _first_valid(nb, "B1", tl)
	_timeline("B1", tl)

	# B2: hızlı ikinci basış BASILI tutulur, pencere bittikten SONRA kalkar.
	board = await _new_round(3)
	await _pause_hud(board)
	tl = await _restart_tap()
	nb = _main._board
	var swallowed: bool = await _second_tap(tl, 45, 160)
	_c("B2 Yeniden Başlat'tan sonra yeniden basılan parmak (basış +%d ms, pencere içinde) pencere bittikten SONRA kalktı (+%d ms): yeni board'da 0 bırakış, nişan oynamadı"
		% [int(tl["down2"]) - int(tl["touch_up"]), int(tl["up2"]) - int(tl["until"])], swallowed
		and int(tl["up2"]) > int(tl["until"]) and _drops_on(nb) == 0 and _near(nb._aim_x, nb._center_x()))
	_c("  … dizi Main'de bütünüyle yutuldu ve bırakışla kapandı; mola / Ayarlar / güç yok", _main._settled_sequences.is_empty()
		and _quiet_round(nb) and not nb._powerups.is_armed())
	await _first_valid(nb, "B2", tl)
	_timeline("B2", tl)

	# B3: parmak 1 TAHTADA basılıyken mola açılır, parmak 0 Yeniden Başlat'a dokunur; parmak 1 yeni board'da kalkar.
	board = await _new_round(3)
	var back: Vector2 = _center(board._hud.back_button)
	var held: Vector2 = _board_point(board, 110.0)
	await _finger(back, true, 0)
	await _finger(held, true, 1)
	var aimed: bool = _near(board._aim_x, _world_x(board, held))
	await _finger(back, false, 0)
	paused = _main.is_pause_open() and board._is_menu_paused
	await _wait(0.4)
	tl = await _restart_tap()
	nb = _main._board
	await _wait_until(int(tl["until"]) + 120)
	var aim_before: float = nb._aim_x
	var dragged_to: Vector2 = _board_point(nb, -130.0)
	await _drag(dragged_to, held, 1)
	var aim_after_drag: float = nb._aim_x
	await _finger(dragged_to, false, 1)
	await _physics(3)
	_c("B3 kurulum: parmak 0 HUD geri'ye basılıyken parmak 1 tahtaya bastı (nişan), parmak 0 kalkınca mola açıldı; GERÇEK Yeniden Başlat tek yeni board",
		aimed and paused and _actions["restart"] == 1 and _differs(nb, int(tl["board0"])))
	_c("B3 değişimi ATLATAN parmak 1'in yeni board'daki sürüklemesi nişanı OYNATMADI (pencere bittikten sonra)",
		_near(aim_after_drag, aim_before) and not _near(aim_before, _world_x(nb, dragged_to)))
	_c("B3 değişimi ATLATAN parmak 1 yeni board'da (pencere bittikten sonra) kalktı: 0 bırakış, nişan aynı (basışı bu board'a ulaşmamış dizi)",
		_drops_on(nb) == 0 and _near(nb._aim_x, aim_before) and _owned_empty(nb))
	await _first_valid(nb, "B3")

	# B4 (çoklu dokunuş, §22): parmak 0 Yeniden Başlat'a basılıyken parmak 1 mola karartmasına basar; parmak 0 kalkınca yeniden
	# başlatma; parmak 1 yeni board kurulduktan sonra kalkar; ardından pencere içinde parmak 1 yeni board'a dokunur.
	board = await _new_round(3)
	await _pause_hud(board)
	var board4: int = board.get_instance_id()
	var restart_point: Vector2 = _center(_main._pause.buttons()[1])
	var dim_point: Vector2 = _screen(Vector2(40.0, 60.0))
	_reset_actions()
	await _finger(restart_point, true, 0)
	await _finger(dim_point, true, 1)
	await _finger(restart_point, false, 0)
	nb = _main._board
	await _finger(dim_point, false, 1)
	await _physics(2)
	var dim_ok: bool = _actions["restart"] == 1 and _actions["resume"] == 0 and _differs(nb, board4)
	await _tap(_board_point(nb, -100.0), 1)
	await _physics(3)
	_c("B4 parmak 0 Yeniden Başlat'ı tutarken parmak 1 mola karartmasında: tek yeniden başlatma, karartma bırakışı DEVAM yaymadı (kapalı pencere), 0 bırakış",
		dim_ok and _drops_on(nb) == 0 and not _main.is_pause_open())
	_c("  … pencere içinde parmak 1'in yeni board dokunuşu yutuldu (0 bırakış), takılı dizi yok", _drops_on(nb) == 0
		and _main._settled_sequences.is_empty())
	await _first_valid(nb, "B4")

	# B5: TASK/048 ertelemesi — tahtada basılı parmak, ertelenen yeniden başlatma reklam kapanınca çalışır.
	var fake: FakeAdBackend = await _fresh_ads()
	board = await _new_round(3)
	var held5: Vector2 = _board_point(board, 80.0)
	var shows0: int = fake.interstitial_shows.size()
	board._finish(true)
	var guard: int = 0
	while fake.interstitial_shows.size() == shows0 and guard < 600:
		await get_tree().process_frame
		guard += 1
	var requested: bool = fake.interstitial_shows.size() == shows0 + 1 and _main._ads.break_pending()
	var id: String = fake.interstitial_shows[-1] if requested else ""
	await _finger(held5, true, 0)
	var gen0: int = _gen()
	var board0: int = board.get_instance_id()
	_reset_actions()
	# TASK/049'dan beri mola bitişte kapanır ve bitmiş board'da açılmaz: bu aralığa UI girişi yok — üretim işleyicisi
	# doğrudan çağrılır (TASK/048 suite'iyle aynı yol).
	_main._on_pause_restart()
	var deferred: bool = _main._deferred_round_change.is_valid() and _main._board == board
	if requested:
		fake.emit_interstitial_showed(id)
		await _settle(1)
		fake.emit_interstitial_dismissed(id)
	await _settle(3)
	nb = _main._board
	await _wait_settled()
	await _finger(held5, false, 0)
	await _physics(3)
	_c("B5 kurulum (TASK/048 fırlatma aralığı): kazanma kesinleşti, geçiş reklamı SDK'ya verildi, bitmiş board'da basılı parmak; Yeniden Başlat işleyicisi ERTELENDİ",
		requested and deferred)
	_c("B5 reklam kapanınca ertelenen yeniden başlatma TAM bir kez (yeni board, nesil +1, eski sonuç yok)",
		_differs(nb, board0) and _gen() == gen0 + 1 and not _main._result.visible)
	_c("B5 bitmiş board'da basılı kalıp yeni board'da kalkan parmak (açık maddenin ertelenen yeniden başlatma hâli): 0 bırakış",
		nb != null and _drops_on(nb) == 0)
	if nb != null:
		await _first_valid(nb, "B5")

	# B6: motor sınırı (kayıt): parmak 0 tahtada basılıyken (öykünen farenin sahibi) ikinci parmak düğmeye basamaz.
	await _fresh()
	board = await _new_round(3)
	var held6: Vector2 = _board_point(board, -100.0)
	await _finger(held6, true, 0)
	await _back()
	var opened: bool = _main.is_pause_open()
	await _wait(0.4)
	_reset_actions()
	await _tap(_center(_main._pause.buttons()[1]), 1)
	await _physics(2)
	var same: bool = _main._board == board and _actions["restart"] == 0
	await _finger(held6, false, 0)
	await _physics(3)
	_c("B6 parmak 0 tahtada basılıyken Android geri molayı açtı; parmak 1'in Yeniden Başlat dokunuşu düğmeyi TETİKLEMEDİ (Godot öykünen fareyi yalnız ilk parmağa verir) — board aynı",
		opened and same)
	_c("  … parmak 0 açık molanın altında (donuk board) kalktı: 0 bırakış", _drops_on(board) == 0 and _main.is_pause_open())
	_main.resume_game()
	await _settle(2)
	_sections_done += 1


# --- C) Yeniden Başlat: hızlı çift dokunuş ------------------------------------------------------------------------

func _c_double_tap() -> void:
	print("-- C: mola → Yeniden Başlat — hızlı ikinci dokunuş yeni board kurulduktan sonra")
	await _fresh()
	for gap: int in SECOND_TAP_GAPS:
		var board: Node2D = await _new_round(3)
		await _pause_hud(board)
		_reset_actions()
		var tl: Dictionary = await _restart_tap()
		var nb: Node2D = _main._board
		var aim0: float = nb._aim_x if nb != null else -1.0
		var swallowed: bool = await _second_tap(tl, gap)
		_c("C [+%d ms] tam BİR yeniden başlatma, tam BİR yeni board (nesil +1); ikinci dokunuş ikinci yeniden başlatma üretmedi" % gap,
			_actions["restart"] == 1 and _gen() == int(tl["gen0"]) + 1 and _differs(nb, int(tl["board0"]))
			and _boards_since(tl) == 1)
		_c("  … ikinci dokunuş (basış +%d ms, pencere sonu +%d ms) Main'de yutuldu: yeni board'da 0 bırakış, nişan oynamadı, HUD / güç / Ayarlar yok"
			% [int(tl["down2"]) - int(tl["down"]), int(tl["until"]) - int(tl["down"])], swallowed and _drops_on(nb) == 0
			and _near(nb._aim_x, aim0) and _quiet_round(nb) and not nb._powerups.is_armed()
			and _main._settled_sequences.is_empty())
		await _first_valid(nb, "C [+%d ms]" % gap, tl)
		_timeline("C +%d" % gap, tl)

	# C2: ikinci dokunuş yeni board'un HUD geri düğmesine (başka nokta): yeni board'da mola AÇILMAZ.
	var board2: Node2D = await _new_round(3)
	await _pause_hud(board2)
	_reset_actions()
	var tl2: Dictionary = await _restart_tap()
	var nb2: Node2D = _main._board
	var hud_back: Vector2 = _center(nb2._hud.back_button)
	await _wait_until(int(tl2["touch_up"]) + 90)
	await _tap(hud_back)
	await _settle(2)
	_c("C2 Yeniden Başlat'tan ~90 ms sonra yeni board'un HUD geri düğmesine dokunuş yutuldu: mola AÇILMADI, board donuk değil, 0 bırakış",
		not _main.is_pause_open() and not nb2._is_menu_paused and _drops_on(nb2) == 0 and _actions["restart"] == 1)
	await _wait_settled()
	await _tap(hud_back)
	await _settle(2)
	_c("C2 yatışmadan sonra HUD geri dokunuşu normal: mola açıldı (engel takılı değil)", _main.is_pause_open()
		and nb2._is_menu_paused)
	_main.resume_game()
	await _settle(2)
	_sections_done += 1


# --- D) Sentetik bırakış -----------------------------------------------------------------------------------------

func _d_synthetic_release() -> void:
	print("-- D: sentetik bırakış — gizlenen düğmenin tıklaması / serbest bırakılan kontrolün parmağı yeni board'a girdi olmaz")
	await _fresh()
	# D1: Yeniden Başlat basılıyken işlenmemiş bir olay (gizlemede Godot odaklı düğmeye sentetik bırakış yollar; son olay
	# "işlendi" değilse BaseButton onu tıklama sayar — TASK/049 sondası): yine TAM bir yeniden başlatma.
	var board: Node2D = await _new_round(3)
	await _pause_hud(board)
	_reset_actions()
	var tl: Dictionary = await _restart_tap(true)
	var nb: Node2D = _main._board
	await _physics(3)
	await _settle(2)
	_c("D1 Yeniden Başlat basışı + işlenmemiş olay + bırakış: tam BİR yeniden başlatma, tam BİR yeni board (nesil +1) — gizleme ikinci `_start_level` üretmedi",
		_actions["restart"] == 1 and _gen() == int(tl["gen0"]) + 1 and _boards_since(tl) == 1)
	_c("  … yeni board'da 0 bırakış, mola kapalı", _drops_on(nb) == 0 and _quiet_round(nb))
	await _first_valid(nb, "D1")

	# D2: parmak 1 ESKİ board'un Sarsıntı düğmesinde basılı (parmak odağı o düğmede); mola → Yeniden Başlat eski board'u (HUD
	# dahil) serbest bırakır; parmak 1 yeni board'da kalkar — odak kontrolü yok, olay işlenmeden tahtaya iner.
	board = await _new_round(3)
	var slot: Button = board._power_bar.slot(PowerUp.Type.SHAKE)
	var slot_point: Vector2 = _center(slot)
	var back: Vector2 = _center(board._hud.back_button)
	var stocks: Dictionary = _stocks()
	await _finger(back, true, 0)
	await _finger(slot_point, true, 1)
	await _finger(back, false, 0)
	var paused: bool = _main.is_pause_open()
	await _wait(0.4)
	_reset_actions()
	var tl2: Dictionary = await _restart_tap()
	nb = _main._board
	await _settle(2)
	var freed: bool = not is_instance_valid(slot)
	await _wait_until(int(tl2["until"]) + 120)
	var aim_before: float = nb._aim_x
	await _finger(slot_point, false, 1)
	await _physics(3)
	_c("D2 kurulum: parmak 1 eski board'un Sarsıntı düğmesinde basılı, mola açıldı, Yeniden Başlat eski board'u (HUD dahil) serbest bıraktı",
		paused and freed and _actions["restart"] == 1)
	_c("D2 serbest bırakılan kontrolün parmağı yeni board'da kalktı: 0 bırakış, nişan aynı, güç kullanılmadı (stok aynı), silah yok",
		_drops_on(nb) == 0 and _near(nb._aim_x, aim_before) and _stocks() == stocks and not nb._powerups.is_armed())
	await _first_valid(nb, "D2")
	_sections_done += 1


# --- E) Sonuç TEKRAR ---------------------------------------------------------------------------------------------

func _e_result_retry() -> void:
	print("-- E: sonuç TEKRAR — aynı kök neden (sonuç → `_start_level`)")
	await _fresh()
	for variant: String in ["kayıp · TEKRAR çift dokunuş", "kazanma · TEKRAR çift dokunuş", "kayıp · TEKRAR basılı ikinci basış"]:
		var won: bool = variant.begins_with("kazanma")
		var board: Node2D = await _new_round(3)
		var before_finish: Dictionary = _progress_state()
		var shown: bool = await _finish_to_result(board, won)
		var button: Button = _main._result.secondary_button() if won else _main._result.primary_button()
		var bytes: PackedByteArray = _bytes()
		var state: Dictionary = _progress_state()
		SaveFile.fault = SaveFile.Fault.TEMP_OPEN
		_reset_actions()
		var tl: Dictionary = await _button_tap(button)
		var nb: Node2D = _main._board
		var swallowed: bool = await _second_tap(tl, 100, 140 if variant.contains("basılı") else 0)
		var no_write: bool = SaveFile.fault == SaveFile.Fault.TEMP_OPEN and _bytes() == bytes
		SaveFile.fault = SaveFile.Fault.NONE
		_c("E [%s] kurulum: round kesinleşti (kesinleşme ilerlemeyi bir kez yazdı: tur +1), sonuç görünür; GERÇEK TEKRAR dokunuşu tam BİR tekrar, tam BİR yeni board (nesil +1), sonuç gizli"
			% variant, shown and int(state["rounds"]) == int(before_finish["rounds"]) + 1
			and _actions["result_retry"] == 1 and _actions["result_exit"] == 0
			and _gen() == int(tl["gen0"]) + 1 and _differs(nb, int(tl["board0"])) and _boards_since(tl) == 1
			and not _main._result.visible)
		_c("  … ikinci dokunuş (+%d ms) yutuldu: yeni board'da 0 bırakış, nişan merkezde" % (int(tl["down2"]) - int(tl["down"])),
			swallowed and _drops_on(nb) == 0 and _near(nb._aim_x, nb._center_x()) and _quiet_round(nb))
		_c("  … geçiş yolu (koruma): TEKRAR + yutulan dokunuşlar kayda yazma GİRİŞİMİ üretmedi; tur / XP / görev / Hamur kesinleşmedeki gibi",
			no_write and _same(_progress_state(), state))
		_timeline("E " + variant, tl)
		await _first_valid(nb, "E [%s]" % variant)

	# E4: geçiş reklamı yöneticisiyle (sahte arka uç, geçiş reklamı uygun + hazır): kesinleşmenin reklamı kapanınca sonuç;
	# TEKRAR + yutulan ikinci dokunuş geçiş reklamı DENEMEZ; yeni round'un kesinleşmesi ilerlemeyi TAM bir kez yazar.
	var fake: FakeAdBackend = await _fresh_ads()
	var board4: Node2D = await _new_round(3)
	var shows0: int = fake.interstitial_shows.size()
	board4._finish(false)
	var guard: int = 0
	while fake.interstitial_shows.size() == shows0 and not _main._result.visible and guard < 600:
		await get_tree().process_frame
		guard += 1
	var ad_id: String = fake.interstitial_shows[-1] if fake.interstitial_shows.size() == shows0 + 1 else ""
	if ad_id != "":
		fake.emit_interstitial_showed(ad_id)
		await _settle(1)
		fake.emit_interstitial_dismissed(ad_id)
	var shown4: bool = await _until_result(1.5)
	await _wait(0.3)
	var shows1: int = fake.interstitial_shows.size()
	var state4: Dictionary = _progress_state()
	_reset_actions()
	var tl4: Dictionary = await _button_tap(_main._result.primary_button())
	var nb4: Node2D = _main._board
	var swallowed4: bool = await _second_tap(tl4, 100)
	_c("E4 kurulum (sahte reklam arka ucu): kayıp kesinleşti, geçiş reklamı istendi + kapandı, sonuç görünür; GERÇEK TEKRAR tek yeni board",
		ad_id != "" and shown4 and _actions["result_retry"] == 1 and _differs(nb4, int(tl4["board0"])))
	_c("  … TEKRAR + yutulan ikinci dokunuş geçiş reklamı DENEMEDİ (istek sayısı aynı, bekleyen mola yok), 0 bırakış",
		swallowed4 and fake.interstitial_shows.size() == shows1 and not _main._ads.break_pending() and _drops_on(nb4) == 0)
	var merges4: int = GameState.merge_count
	if nb4 != null and is_instance_valid(nb4):
		nb4._finish(false)
	var shown5: bool = await _until_result(2.5)
	var after4: Dictionary = _progress_state()
	_c("E4 TEKRAR'ın yeni round'u kesinleşince ilerleme TAM bir kez: tur +1, toplam merge + yeni round'un merge sayısı (%d), sonuç bir kez"
		% merges4, shown5 and int(after4["rounds"]) == int(state4["rounds"]) + 1
		and int(after4["merges"]) == int(state4["merges"]) + merges4)
	_sections_done += 1


# --- F) Harita / Ana Sayfa ---------------------------------------------------------------------------------------

func _f_map_home() -> void:
	print("-- F: Harita / Ana Sayfa → level başlangıcı")
	await _fresh()
	# F0: Ana Sayfa OYNA → Harita (Ana Sayfa doğrudan level başlatmaz); OYNA'ya hızlı ikinci dokunuş Harita'nın `_show_tab`
	# yatışmasında (TASK/044) yutulur — level başlamaz. Korunan davranış.
	_main._show_tab(0)
	await _wait_settled()
	var play: Vector2 = _center(_main._screens[0].play_button())
	_reset_actions()
	await _tap(play)
	var on_map: bool = _main._active_tab == 1 and _main._screens[1].visible
	await _wait(0.1)
	await _tap(play)
	await _settle(2)
	_c("F0 Ana Sayfa OYNA → Harita; OYNA noktasına hızlı ikinci dokunuş yutuldu (mevcut yatışma): level başlamadı, board yok",
		on_map and _main._board == null and _actions["level_chosen"] == 0 and _main._active_tab == 1)

	# F1: Harita düğümü (level 3) — çift dokunuş.
	for gap: int in SECOND_TAP_GAPS:
		await _to_map()
		var node: MapLevelNode = _main._screens[1].nodes()[2]
		_reset_actions()
		var tl: Dictionary = await _button_tap(node)
		var nb: Node2D = _main._board
		var swallowed: bool = await _second_tap(tl, gap)
		_c("F1 [+%d ms] GERÇEK Harita düğümü dokunuşu: tam BİR level_chosen, tam BİR yeni board (level 3, nesil +1), kabuk gizli"
			% gap, _actions["level_chosen"] == 1 and _boards_since(tl) == 1 and nb != null
			and nb.level.level_number == 3 and _gen() == int(tl["gen0"]) + 1 and not _main._screens[1].visible)
		_c("  … düğüme hızlı ikinci dokunuş yutuldu: yeni board'da 0 bırakış, nişan merkezde", swallowed and nb != null
			and _drops_on(nb) == 0 and _near(nb._aim_x, nb._center_x()) and _quiet_round(nb))
		_timeline("F1 +%d" % gap, tl)
		if nb != null:
			await _first_valid(nb, "F1 [+%d ms]" % gap)

	# F2: iki parmak — parmak 0 düğümde, parmak 1 Harita arka planında (kontrol yakalamaz) basılı; level başlar; parmak 1
	# pencere bittikten sonra yeni board'da kalkar.
	await _to_map()
	var node2: MapLevelNode = _main._screens[1].nodes()[2]
	var np: Vector2 = _center(node2)
	var background: Vector2 = _screen(Vector2(40.0, 700.0))
	_reset_actions()
	await _finger(np, true, 0)
	await _finger(background, true, 1)
	await _finger(np, false, 0)
	var nb2: Node2D = _main._board
	await _wait_settled()
	await _finger(background, false, 1)
	await _physics(3)
	_c("F2 parmak 1 Harita arka planında basılıyken parmak 0'ın düğüm dokunuşu level'ı başlattı; parmak 1 yeni board'da kalktı: 0 bırakış",
		_actions["level_chosen"] == 1 and nb2 != null and _drops_on(nb2) == 0 and _owned_empty(nb2))
	if nb2 != null:
		await _first_valid(nb2, "F2")
	_sections_done += 1


# --- G) Yatışma süresi ---------------------------------------------------------------------------------------------

func _g_settle_duration() -> void:
	print("-- G: yatışma süresi — 300 ms aynen, board hazır olunca başlar, iki katına çıkmaz")
	_c("G TOUCH_SETTLE_MSEC == 300", _settle_msec == 300)
	await _fresh()
	var board: Node2D = await _new_round(3)
	await _pause_hud(board)
	var tl: Dictionary = await _restart_tap()
	var nb: Node2D = _main._board
	# Referans: board'un `ready` anı (izleyiciyle bağımsız ölçülür — pencere sonundan türetilmez).
	var ready_at: int = int(tl["ready"])
	_c("G pencere board girdiye HAZIR olduktan sonra (aynı işleyicide) kuruldu ve 300 ms sürüyor: pencere sonu = hazır +%d ms"
		% (int(tl["until"]) - ready_at), ready_at >= 0 and int(tl["arm"]) >= ready_at and int(tl["arm"]) <= int(tl["touch_up"])
		and int(tl["until"]) - ready_at >= 300 and int(tl["until"]) - ready_at <= 320)
	# Basış anları board hazır anına göre (+150 / +420 ms): pencere sonu (+300) iki yönde de ≥ 120 ms pay; dağıtım anları
	# kontrolün içinde — makine yükü bir basışı sınırın öbür yanına iterse kontrol sessizce geçmez, görünür düşer.
	await _wait_until(ready_at + 150)
	var t_in: int = Time.get_ticks_msec()
	await _tap(_board_point(nb, -80.0))
	await _physics(3)
	var inside: bool = _drops_on(nb) == 0
	await _wait_until(ready_at + 420)
	var t_out: int = Time.get_ticks_msec()
	await _tap(_board_point(nb, 80.0))
	await _physics(3)
	_c("G board hazır +%d ms'de (pencere içinde) başlayan dokunuş yutuldu; +%d ms'de (pencere sonu +%d'den sonra) başlayan İLK dokunuş TAM bir parça — etkin engel ~300 ms (kısalmadı, 600 ms'ye uzamadı)"
		% [t_in - ready_at, t_out - ready_at, int(tl["until"]) - ready_at], t_in < int(tl["until"])
		and t_out >= int(tl["until"]) and inside and _drops_on(nb) == 1)
	var until_now: int = _main._touch_settle_until
	_c("G kurulumdan sonra pencere yeniden kurulmadı (pencere sonu aynı)", until_now == int(tl["until"]))
	_sections_done += 1


# --- H) Tek kurma ------------------------------------------------------------------------------------------------

func _h_single_arm() -> void:
	print("-- H: tek kurma — her başlatma yolunda bir kez; sonraki karelerde yeniden kurulmaz; çift çağrı uzatmaz")
	await _fresh()
	for path: String in ["mola Yeniden Başlat", "sonuç TEKRAR", "Harita düğümü", "Sonsuz düğümü"]:
		var tl: Dictionary = {}
		match path:
			"mola Yeniden Başlat":
				var b: Node2D = await _new_round(3)
				await _pause_hud(b)
				tl = await _restart_tap()
			"sonuç TEKRAR":
				var b2: Node2D = await _new_round(3)
				await _finish_to_result(b2, false)
				tl = await _button_tap(_main._result.primary_button())
			"Harita düğümü":
				await _to_map()
				tl = await _button_tap(_main._screens[1].nodes()[2])
			_:
				await _to_map()
				tl = await _button_tap(_main._screens[1].endless_node())
		var until: int = int(tl["until"])
		await _settle(8)
		await _wait_until(int(tl["ready"]) + 400)
		_c("H [%s] tek pencere: board hazır olduktan sonra (aynı işleyici) kuruldu, pencere sonu = hazır +%d ms; hazır +400 ms'ye dek yeniden kurulmadı"
			% [path, until - int(tl["ready"])], int(tl["ready"]) >= 0 and int(tl["arm"]) >= int(tl["ready"])
			and until - int(tl["ready"]) >= 300 and until - int(tl["ready"]) <= 320
			and _main._touch_settle_until == until)
		await _wait_settled()
	var t: int = Time.get_ticks_msec()
	_main.settle_touch_input()
	_main.settle_touch_input()
	var end: int = Time.get_ticks_msec()
	_c("H `settle_touch_input` atama (toplama değil): art arda iki çağrı pencereyi yalnız son çağrı + 300'e kurar — 600 ms'ye UZAMAZ",
		_main._touch_settle_until >= t + 300 and _main._touch_settle_until <= end + 300)
	await _wait_settled()
	_sections_done += 1


# --- I) ACTION_CANCEL --------------------------------------------------------------------------------------------

func _i_cancel() -> void:
	print("-- I: ACTION_CANCEL (TASK/046.2) — 0 bırakış, sonraki bağımsız dokunuş 1")
	await _fresh()
	var board: Node2D = await _new_round(3)
	await _pause_hud(board)
	var tl: Dictionary = await _restart_tap()
	var nb: Node2D = _main._board
	var p: Vector2 = _board_point(nb, -60.0)
	await _finger(p, true)
	var swallowed: bool = _main._settled_sequences.has(0)
	await _cancel(p)
	await _physics(2)
	_c("I1 yatışma penceresinde başlayan dizinin ACTION_CANCEL'ı: 0 bırakış, dizi kapandı (takılı bastırma yok)", swallowed
		and _drops_on(nb) == 0 and _main._settled_sequences.is_empty() and int(tl["until"]) > 0)
	await _wait_settled()
	var q: Vector2 = _board_point(nb, 60.0)
	await _finger(q, true)
	await _cancel(q)
	await _physics(2)
	_c("I2 yatışmadan sonra tahtada ACTION_CANCEL: 0 bırakış (TASK/046.2 aynen), sahiplik kaydı kapandı", _drops_on(nb) == 0
		and _owned_empty(nb))
	await _tap(_board_point(nb, 100.0))
	await _physics(3)
	_c("I2 iptalden sonra sonraki bağımsız dokunuş TAM bir parça", _drops_on(nb) == 1)

	# I3: değişimi atlatan parmağın (B3 kurulumu) bırakış yerine iptali.
	board = await _new_round(3)
	var back: Vector2 = _center(board._hud.back_button)
	var held: Vector2 = _board_point(board, -110.0)
	await _finger(back, true, 0)
	await _finger(held, true, 1)
	await _finger(back, false, 0)
	await _wait(0.4)
	tl = await _restart_tap()
	nb = _main._board
	await _wait_until(int(tl["until"]) + 100)
	await _cancel(held, 1)
	await _physics(2)
	_c("I3 değişimi atlatan parmağın yeni board'daki ACTION_CANCEL'ı: 0 bırakış", _drops_on(nb) == 0
		and _owned_empty(nb))
	await _first_valid(nb, "I3")
	_sections_done += 1


# --- J) Mola DEVAM ET -----------------------------------------------------------------------------------------------

func _j_continue() -> void:
	print("-- J: mola DEVAM ET — aynı board, yatışma KURULMAZ, sonraki dokunuş hemen normal")
	await _fresh()
	var board: Node2D = await _new_round(3)
	var paused: bool = await _pause_hud(board)
	var until0: int = _main._touch_settle_until
	var gen0: int = _gen()
	_reset_actions()
	await _tap(_center(_main._pause.buttons()[0]))
	await _physics(2)
	_c("J GERÇEK DEVAM ET: mola kapandı, aynı board (nesil aynı), board çözüldü; devam 1, yeniden başlatma 0", paused
		and not _main.is_pause_open() and _main._board == board and _gen() == gen0 and not board._is_menu_paused
		and _actions["resume"] == 1 and _actions["restart"] == 0)
	_c("  … DEVAM ET dokunuşu 0 bırakış; DEVAM yatışma KURMADI (pencere sonu değişmedi)", _drops_on(board) == 0
		and _main._touch_settle_until == until0)
	await _wait(0.12)
	await _tap(_board_point(board, 90.0))
	await _physics(3)
	_c("J DEVAM'dan ~120 ms sonra bağımsız tahta dokunuşu HEMEN TAM bir parça (Devam'da başlangıç engeli yok)",
		_drops_on(board) == 1)
	_sections_done += 1


# --- K) TASK/049 normal bitiş + sonuç düğmeleri ------------------------------------------------------------------

func _k_finish_result() -> void:
	print("-- K: TASK/049 normal bitiş — mola bitişte kapanır; sonuç düğmeleri hemen çalışır (sonuç yatışma kurmaz)")
	await _fresh()
	var board: Node2D = await _new_round(3)
	var paused: bool = await _pause_hud(board)
	var until0: int = _main._touch_settle_until
	_reset_actions()
	# Mola açıkken round meşru biçimde biter (Büyütücü dönüşümünün molada tamamlanması gibi) → TASK/049 temizliği.
	board._finish(true)
	var closed: bool = not _main.is_pause_open() and not board._is_menu_paused
	var shown: bool = await _until_result(2.0)
	_c("K mola açıkken kesinleşen bitiş: mola bitişte kapandı (TASK/049), eylem yok; sonuç gecikmeden sonra (WIN) tek başına",
		paused and closed and shown and _main._result.mode() == _result_mode("WIN") and not _main.is_pause_open()
		and _actions["resume"] == 0 and _actions["restart"] == 0 and _actions["exit"] == 0)
	_c("  … sonuç gösterimi yatışma KURMADI (pencere sonu değişmedi)", _main._touch_settle_until == until0)
	await _wait(0.1)
	await _tap(_center(_main._result.primary_button()))
	await _settle(2)
	_c("K sonuç açıldıktan ~100 ms sonra GERÇEK HARİTA dokunuşu çalıştı (sonuç çıkışı 1) → Harita, board yok",
		_actions["result_exit"] == 1 and _main._board == null and _main._active_tab == 1 and _main._screens[1].visible)
	# Kayıp sonucu: TEKRAR hemen çalışır (yeni board E'de ayrıntılı).
	await _wait_settled()
	var board2: Node2D = await _new_round(3)
	var board2_id: int = board2.get_instance_id()
	await _finish_to_result(board2, false)
	_reset_actions()
	await _tap(_center(_main._result.primary_button()))
	await _settle(2)
	_c("K kayıp sonucunda GERÇEK TEKRAR dokunuşu çalıştı: tekrar 1, yeni board, sonuç gizli", _actions["result_retry"] == 1
		and _differs(_main._board, board2_id) and not _main._result.visible)
	_sections_done += 1


# --- L) Meydan okuma ---------------------------------------------------------------------------------------------

func _l_challenge() -> void:
	print("-- L: meydan okuma — kendi başlangıç yatışması aynen; sızıntı yok, hamle harcanmaz")
	await _fresh()
	_main._show_tab(0)
	await _wait_settled()
	await _tap(_center(_main._screens[0].challenge_button()))
	await _settle(2)
	var sheet: bool = _main._challenge_sheet.visible
	await _wait_settled()
	_reset_actions()
	var tl: Dictionary = await _button_tap(_main._challenge_sheet.start_button())
	var nb: Node2D = _main._board
	var swallowed: bool = await _second_tap(tl, 100)
	_c("L GERÇEK MEYDAN OKUMA → BAŞLA: tam BİR meydan okuma board'u (gün %s, bütçe tam), meydan okumanın KENDİ 300 ms kurulumu" % THU,
		sheet and _actions["challenge_start"] == 1 and nb != null and nb.is_daily_challenge() and _main._challenge_day == THU
		and _boards_since(tl) == 1 and int(tl["until"]) - int(tl["arm"]) == 300)
	_c("  … BAŞLA'ya hızlı ikinci dokunuş yutuldu: 0 bırakış, 0 hamle", swallowed and nb != null and _drops_on(nb) == 0
		and nb.drops_used() == 0)
	if nb != null:
		await _first_valid(nb, "L")
		_c("  … ilk bağımsız dokunuş meydan okumada tam bir hamle (1)", nb.drops_used() == 1)

	# L2: meydan okumada mola → Yeniden Başlat (kendi yolu: `_retry_daily_challenge`) + çift dokunuş.
	await _pause_hud(nb)
	_reset_actions()
	var tl2: Dictionary = await _restart_tap()
	var nb2: Node2D = _main._board
	var swallowed2: bool = await _second_tap(tl2, 100)
	_c("L2 meydan okuma mola → Yeniden Başlat: tam BİR yeni meydan okuma denemesi (normal `_start_level` değil), çift dokunuş 0 bırakış / 0 hamle",
		_actions["restart"] == 1 and nb2 != null and nb2.is_daily_challenge() and _differs(nb2, int(tl2["board0"]))
		and swallowed2 and _drops_on(nb2) == 0 and nb2.drops_used() == 0)

	# L3: değişimi atlatan parmak (HUD geri + tahta, iki parmak) meydan okumada hamle harcamaz.
	await _wait_settled()
	var back: Vector2 = _center(nb2._hud.back_button)
	var held: Vector2 = _board_point(nb2, 100.0)
	await _finger(back, true, 0)
	await _finger(held, true, 1)
	await _finger(back, false, 0)
	await _wait(0.4)
	var tl3: Dictionary = await _restart_tap()
	var nb3: Node2D = _main._board
	await _wait_until(int(tl3["until"]) + 120)
	await _finger(held, false, 1)
	await _physics(3)
	_c("L3 meydan okumada değişimi atlatan parmak yeni denemede kalktı: 0 bırakış, 0 hamle (bütçe tam)", nb3 != null
		and nb3.is_daily_challenge() and _drops_on(nb3) == 0 and nb3.drops_used() == 0)
	if nb3 != null:
		await _first_valid(nb3, "L3")
	_sections_done += 1


# --- M) Sonsuz ---------------------------------------------------------------------------------------------------

func _m_endless() -> void:
	print("-- M: Sonsuz — Harita Sonsuz düğümü ve Sonsuz'da Yeniden Başlat `_start_level`'dan geçer")
	await _fresh()
	await _to_map()
	_reset_actions()
	var tl: Dictionary = await _button_tap(_main._screens[1].endless_node())
	var nb: Node2D = _main._board
	var swallowed: bool = await _second_tap(tl, 100)
	_c("M GERÇEK Sonsuz düğümü dokunuşu: tam BİR sonsuz round (level_chosen 1), ikinci dokunuş yutuldu: 0 bırakış",
		_actions["level_chosen"] == 1 and nb != null and nb.level.is_endless and _boards_since(tl) == 1 and swallowed
		and _drops_on(nb) == 0)
	if nb != null:
		await _first_valid(nb, "M")
	await _pause_hud(nb)
	_reset_actions()
	var tl2: Dictionary = await _restart_tap()
	var nb2: Node2D = _main._board
	var swallowed2: bool = await _second_tap(tl2, 100)
	_c("M2 Sonsuz'da mola → Yeniden Başlat: tek yeni sonsuz board, çift dokunuş 0 bırakış", _actions["restart"] == 1
		and nb2 != null and nb2.level.is_endless and _differs(nb2, int(tl2["board0"])) and swallowed2 and _drops_on(nb2) == 0)
	if nb2 != null:
		await _first_valid(nb2, "M2")
	_sections_done += 1


# --- N) Tutorial ---------------------------------------------------------------------------------------------------

func _n_tutorial() -> void:
	print("-- N: ilk açılış tutorial'ı — açılışta `_start_level`; tutorial tepkisiz olmaz")
	var boot_msec: int = Time.get_ticks_msec()
	await _fresh_tutorial()
	var boot_end: int = Time.get_ticks_msec()
	var board: Node2D = _main._board
	var tut: TutorialController = _main._tutorial
	_c("N kurulum: yeni kayıt → açılışta GERÇEK Level 1 tutorial board'u, adım WELCOME (girdi kilitli)", board != null
		and tut.is_active() and tut.step_name() == "welcome" and board._tutorial_input_locked)
	var arm: int = _main._touch_settle_until - _settle_msec
	_c("N açılış yatışması tutorial board'u kurulurken kuruldu (açılış işlemi içinde, +%d ms), 300 ms sonra biter" % (
		arm - boot_msec), arm >= boot_msec and arm <= boot_end)
	await _wait_settled()
	await _tap(_center(_main._tutorial_overlay.cta_button()))
	await _settle(2)
	_c("N yatışmadan sonra GERÇEK BAŞLA dokunuşu tutorial'ı ilerletti (first_drop, girdi açık)",
		tut.step_name() == "first_drop" and not board._tutorial_input_locked)
	await _tap(_board_point(board, 0.0))
	await _physics(3)
	_c("N ilk tutorial dokunuşu TAM bir parça (tutorial kuyruğu T1)", _drops_on(board) == 1
		and int((_drop_log[-1] if not _drop_log.is_empty() else {}).get("tier", -1)) == 1)
	# N2: aynı board'da girdi kilitliyken basılan, kilit açılınca kalkan parmak — sahiplik kapıdan ÖNCE kaydedilir,
	# davranış eskisi gibi: bırakış düşürür (tutorial'ın ikinci bırakışı).
	var locked: bool = board._tutorial_input_locked
	var p: Vector2 = _board_point(board, 0.0)
	await _finger(p, true)
	var guard: int = 0
	while tut.step_name() != "match_drop" and guard < 900:
		await get_tree().process_frame
		guard += 1
	var unlocked: bool = tut.step_name() == "match_drop" and not board._tutorial_input_locked
	await _finger(p, false)
	await _physics(3)
	_c("N2 kilitliyken (ilk parça oturuyor) basılan parmak kilit açılınca (match_drop) kalktı: tutorial'ın ikinci bırakışı düştü — aynı board'da başlamış dizi bölünmez",
		locked and unlocked and _drops_on(board) == 2)
	_sections_done += 1


# --- O) Takılı engel yok ---------------------------------------------------------------------------------------------

func _o_no_stuck() -> void:
	print("-- O: takılı engel yok — yatışmadan sonra art arda bağımsız dokunuşlar kurala göre")
	await _fresh()
	var board: Node2D = await _new_round(3)
	await _pause_hud(board)
	var tl: Dictionary = await _restart_tap()
	var nb: Node2D = _main._board
	await _second_tap(tl, 60)
	await _wait_settled()
	for i in 3:
		await _tap(_board_point(nb, -120.0 + 120.0 * float(i)))
		await _physics(2)
		await _wait(float(nb.DROP_COOLDOWN) + 0.08)
	_c("O yatışmadan sonra 3 bağımsız dokunuş → 3 parça (bekleme kuralıyla); yutulan / sahipli dizi kalmadı", _drops_on(nb) == 3
		and _main._settled_sequences.is_empty() and _owned_empty(nb))
	await _tap(_board_point(nb, 30.0))
	await _tap(_board_point(nb, -30.0))
	await _physics(2)
	_c("O hızlı ikinci dokunuş oyun kuralına (DROP_COOLDOWN, değişmedi) takılır: çift parça yok", _drops_on(nb) == 4
		and nb._drop_cooldown > 0.0)
	_sections_done += 1


# --- P) Gezinme yan etkisi yok ----------------------------------------------------------------------------------------

func _p_navigation() -> void:
	print("-- P: yatışma kurulumu gezinme / pencere / sonuç eylemi üretmez")
	await _fresh()
	var board: Node2D = await _new_round(3)
	await _pause_hud(board)
	_reset_actions()
	var tl: Dictionary = await _restart_tap()
	await _second_tap(tl, 80)
	_c("P mola Yeniden Başlat (+ yutulan ikinci dokunuş): yalnız yeniden başlatma; Ana Sayfa / Harita gizli, Ayarlar / mola / sonuç / pencereler kapalı",
		_actions["restart"] == 1 and _actions_except(["restart"]) == 0 and _quiet_round(_main._board))
	var board2: Node2D = await _new_round(3)
	await _finish_to_result(board2, false)
	_reset_actions()
	tl = await _button_tap(_main._result.primary_button())
	await _second_tap(tl, 80)
	_c("P sonuç TEKRAR (+ yutulan ikinci dokunuş): yalnız tekrar; gezinme / pencere / sonuç çıkışı yok", _actions["result_retry"] == 1
		and _actions_except(["result_retry"]) == 0 and _quiet_round(_main._board))
	await _to_map()
	_reset_actions()
	tl = await _button_tap(_main._screens[1].nodes()[2])
	await _second_tap(tl, 80)
	_c("P Harita düğümü (+ yutulan ikinci dokunuş): yalnız level_chosen; Ana Sayfa'ya dönülmedi, pencere yok", _actions["level_chosen"] == 1
		and _actions_except(["level_chosen"]) == 0 and _quiet_round(_main._board))
	_sections_done += 1


# --- Q) Kayıt / ekonomi ------------------------------------------------------------------------------------------------

func _q_persistence() -> void:
	print("-- Q: kayıt / ekonomi yalıtımı — değişim + yutulan / sahipsiz dokunuşlar kayda yazmaz")
	await _fresh()
	var board: Node2D = await _new_round(3)
	var bytes: PackedByteArray = _bytes()
	var state: Dictionary = _progress_state()
	var stocks: Dictionary = _stocks()
	SaveFile.fault = SaveFile.Fault.TEMP_OPEN
	# İki parmaklı atlatan dizi + Sarsıntı düğmesinde basılı üçüncü parmak yok; tek akış: HUD geri (parmak 0) + tahta (1) →
	# mola → Yeniden Başlat → hızlı ikinci dokunuş → atlatan parmak kalkar → pencereden sonra bağımsız dokunuş YOK (bırakış
	# kayda yazmaz ama burada yalnız değişim ölçülür).
	var back: Vector2 = _center(board._hud.back_button)
	var held: Vector2 = _board_point(board, 90.0)
	await _finger(back, true, 0)
	await _finger(held, true, 1)
	await _finger(back, false, 0)
	await _wait(0.4)
	var tl: Dictionary = await _restart_tap()
	await _second_tap(tl, 100)
	await _wait_until(int(tl["until"]) + 100)
	await _finger(held, false, 1)
	await _physics(3)
	var nb: Node2D = _main._board
	var no_write: bool = SaveFile.fault == SaveFile.Fault.TEMP_OPEN
	SaveFile.fault = SaveFile.Fault.NONE
	_c("Q mola Yeniden Başlat + yutulan ikinci dokunuş + atlatan parmak: kayda yazma GİRİŞİMİ yok, kayıt baytları aynı, 0 bırakış",
		no_write and _bytes() == bytes and _drops_on(nb) == 0)
	_c("  … Hamur / XP / tur / görev / başarım / yıldız / meydan okuma / sonsuz rekoru / güç stokları aynı (terk edilen round sayılmaz)",
		_same(_progress_state(), state) and _stocks() == stocks)
	_sections_done += 1


# --- S) Kaynak sözleşmesi --------------------------------------------------------------------------------------------

func _s_source_contract() -> void:
	print("-- S: kaynak sözleşmesi")
	var raw: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var code: String = _strip_comments(raw)
	_c("S TOUCH_SETTLE_MSEC aynen 300; pencere yalnız `settle_touch_input`'ta, atamayla yazılır",
		raw.contains("const TOUCH_SETTLE_MSEC: int = 300") and code.count("_touch_settle_until =") == 1
		and _function(code, "func settle_touch_input(").contains("_touch_settle_until = Time.get_ticks_msec() + TOUCH_SETTLE_MSEC"))
	var start_fn: String = _function(code, "func _start_level(")
	_c("S `_start_level` mevcut yatışmayı TAM bir kez, board ağaca eklendikten SONRA kurar",
		start_fn.count("settle_touch_input()") == 1 and start_fn.find("add_child(_board)") >= 0
		and start_fn.find("add_child(_board)") < start_fn.find("settle_touch_input()"))
	var leaks: Array[String] = []
	for header: String in ["func _begin_round(", "func _on_pause_restart(", "func resume_game(", "func _present_result(",
			"func _begin_first_run_tutorial(", "func _clear_board(", "func _defer_round_change(", "func _on_round_finished(",
			"func _dismiss_terminal_gameplay_overlays(", "func open_pause_menu("]:
		if _function(code, header).contains("settle_touch_input"):
			leaks.append(header)
	_c("S çağıranlar / ortak sınır ayrıca kurmaz (tek kurma noktası `_start_level`)%s" % (
		"" if leaks.is_empty() else " — kuran: %s" % ", ".join(leaks)), leaks.is_empty())
	var retry_fn: String = _function(code, "func _on_retry_pressed(")
	_c("S sonuç TEKRAR yolu aynen: yalnız meydan okuma gün tazelemesinde mevcut tek kurulum; normal dal `_start_level`",
		retry_fn.count("settle_touch_input()") == 1 and retry_fn.find("settle_touch_input()") < retry_fn.find("_retry_daily_challenge()")
		and retry_fn.contains("_start_level(_current_level)"))
	var dc_fn: String = _function(code, "func start_daily_challenge(")
	_c("S meydan okuma başlangıcı aynen: kendi yatışması TAM bir kez, add_child'dan sonra; `_start_level` kullanmaz",
		dc_fn.count("settle_touch_input()") == 1 and dc_fn.find("add_child(_board)") < dc_fn.find("settle_touch_input()")
		and not dc_fn.contains("_start_level("))
	var input_fn: String = _function(code, "func _input(")
	_c("S Main._input aynen: dizi tabanlı, tek saat okuması, zamanlayıcı / bekleme yok",
		input_fn.contains("_settled_sequences") and input_fn.contains("_touch_settle_until") and input_fn.count("msec") == 1
		and not input_fn.contains("timer") and not input_fn.contains("await"))
	var board_code: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/game/game_board.gd"))
	var unh: String = _function(board_code, "func _unhandled_input(")
	var own_at: int = unh.find("_note_owned_touch(event)")
	var consume_at: int = unh.find("_consume_targeting_touch(event)")
	var gate_at: int = unh.find("_is_finished or _is_paused()")
	var owned_at: int = unh.find("if not owned:")
	_c("S GameBoard sahiplik kaydı her kapıdan ÖNCE (hedefleme tüketimi ve duraklatma kapısından önce)", own_at >= 0
		and own_at < consume_at and consume_at < gate_at)
	_c("S sahipsiz dizi duraklatma kapısından SONRA, hedefleme / nişan / bırakıştan ÖNCE düşer", owned_at > gate_at
		and owned_at < unh.find("_powerups.is_armed()") and owned_at < unh.find("_set_aim(") and owned_at < unh.find("_drop()"))
	_c("S TASK/046.2 iptal koruması aynen (`elif not touch.canceled:` `_drop()`'tan önce)", unh.contains("elif not touch.canceled:")
		and unh.find("elif not touch.canceled:") < unh.find("_drop()"))
	var own_fn: String = _function(board_code, "func _note_owned_touch(")
	_c("S sahiplik zamanlayıcısız (süre / tick / timer / delta yok): basış açar, bırakış (iptal dahil) kapatır",
		not own_fn.is_empty() and not own_fn.contains("msec") and not own_fn.contains("timer") and not own_fn.contains("delta")
		and own_fn.contains("_owned_touches[touch.index] = true") and own_fn.contains("_owned_touches.erase(touch.index)"))
	var drop_fn: String = _function(board_code, "func _drop(")
	_c("S DROP_COOLDOWN aynen 0.4; `_drop()` sahiplik / iptal bilgisi taşımaz", board_code.contains("const DROP_COOLDOWN: float = 0.4")
		and not drop_fn.is_empty() and not drop_fn.contains("owned") and not drop_fn.contains("cancel"))
	_sections_done += 1


# --- Kurulum yardımcıları ----------------------------------------------------------------------------------------------

func _fixture(extra: Dictionary = {}) -> Dictionary:
	var content: Dictionary = {"highest_level_unlocked": 11,
		"level_stars": {"1": 3, "2": 3, "3": 2, "4": 2, "5": 1, "6": 1, "7": 1, "8": 1, "9": 1, "10": 1},
		"endless_high_score": 640, "dough": 335, "total_merges": 40, "merges_since_bonus_chest": 10,
		"unlocked_skins": ["common_01", "rare_02"], "profile_showcase": ["rare_02"],
		"powerups": {"bomb": 2, "upgrade": 9, "shake": 2, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "", "daily_streak": 3,
		"last_login_date": Time.get_date_string_from_system(), "age_ad_band": "ADULT", "next_age_transition_date": "",
		"player_meta_version": 1, "player_xp": 400, "total_rounds_played": 12, "highest_tier_created": 4,
		"unlocked_achievements": ["merge_10"],
		"daily_challenge": {"version": 1, "completed_day_key": ""},
		"daily_rewards": {"day_key": THU, "free_chest_claimed": true, "ad_chests_claimed": 2,
			"dough_ad_claimed": true, "popup_seen_day": THU, "last_seen_day_key": THU},
		"missions": {"version": 1, "day_key": THU, "week_start_day_key": MON,
			"daily_progress": {"daily_merges": 5, "daily_rounds": 0, "daily_clear": 0}, "daily_rewarded": [],
			"weekly_progress": {"weekly_merges": 30, "weekly_rounds": 4, "weekly_clears": 2}, "weekly_rewarded": []}}
	for key: String in extra:
		content[key] = extra[key]
	return content


func _write(content: Dictionary) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(content, "\t"))
	file.close()


## Temiz kayıt + Main (reklam yöneticisi yok — masaüstü).
func _fresh() -> void:
	await _teardown_main()
	_clean()
	SaveFile.fault = SaveFile.Fault.NONE
	DailyRewards.clock_override = THU
	_write(_fixture())
	SaveManager.load_game()
	await _boot(null)


## Temiz kayıt + Main + sahte reklam arka ucu (rıza + init + yükler hazır; geçiş reklamı uygun + hazır).
func _fresh_ads() -> FakeAdBackend:
	await _teardown_main()
	_clean()
	SaveFile.fault = SaveFile.Fault.NONE
	DailyRewards.clock_override = THU
	_write(_fixture())
	SaveManager.load_game()
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	await _boot(fake)
	fake.complete_consent_update(true)
	fake.complete_init()
	await _settle(2)
	if not fake.pending_banner.is_empty():
		fake.complete_banner_load(true)
	_main._ads._tick_active(MonetizationManager.INTERSTITIAL_INTERVAL_SEC)
	await _settle(2)
	while not fake.pending_interstitial.is_empty():
		fake.complete_interstitial_load(true)
	while not fake.pending_rewarded.is_empty():
		fake.complete_rewarded_load(true)
	await _settle(2)
	return fake


## Yeni oyuncu kaydı (onboarding bitmemiş) + Main: açılışta tutorial `_start_level` ile başlar.
func _fresh_tutorial() -> void:
	await _teardown_main()
	_clean()
	SaveFile.fault = SaveFile.Fault.NONE
	DailyRewards.clock_override = THU
	var content: Dictionary = SaveManager.DEFAULT_DATA.duplicate(true)
	content["onboarding_completed"] = false
	content["powerup_starter_granted"] = true
	content["last_login_date"] = Time.get_date_string_from_system()
	_write(content)
	SaveManager.load_game()
	await _boot(null)


func _boot(fake: FakeAdBackend) -> void:
	await _teardown_main()
	_boards.clear()
	_drop_log.clear()
	_reset_actions()
	_main_script.set("ads_backend_override", fake)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_main_script.set("ads_backend_override", null)
	_main.child_entered_tree.connect(_on_main_child)
	if _main._board != null and is_instance_valid(_main._board):
		_register(_main._board, Time.get_ticks_msec())
	_main._pause.resume_pressed.connect(func() -> void: _actions["resume"] += 1)
	_main._pause.restart_pressed.connect(func() -> void: _actions["restart"] += 1)
	_main._pause.exit_pressed.connect(func() -> void: _actions["exit"] += 1)
	_main._result.retry_pressed.connect(func() -> void: _actions["result_retry"] += 1)
	_main._result.exit_pressed.connect(func() -> void: _actions["result_exit"] += 1)
	_main._settings.closed.connect(func() -> void: _actions["settings_closed"] += 1)
	_main._screens[1].level_chosen.connect(func(_l: LevelData) -> void: _actions["level_chosen"] += 1)
	_main._challenge_sheet.start_requested.connect(func(_d: String) -> void: _actions["challenge_start"] += 1)
	await _settle(3)


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _settle(2)


func _reset_actions() -> void:
	for key in ACTION_KEYS:
		_actions[key] = 0


func _actions_except(keys: Array) -> int:
	var total: int = 0
	for key: String in ACTION_KEYS:
		if not keys.has(key):
			total += int(_actions.get(key, 0))
	return total


func _on_main_child(node: Node) -> void:
	if _main == null or not is_instance_valid(_main) or node != _main._board:
		return
	_register(node as Node2D, Time.get_ticks_msec())


## Board izleyicisi: giriş / hazır anı, nesil, bırakışlar (Main'in bağlantılarından SONRA bağlı).
func _register(board: Node2D, enter_msec: int) -> void:
	var id: int = board.get_instance_id()
	if _boards.has(id):
		return
	_boards[id] = {"enter": enter_msec, "ready": enter_msec if board.is_node_ready() else -1, "gen": _gen(), "drops": 0}
	if not board.is_node_ready():
		board.ready.connect(func() -> void:
			if _boards.has(id):
				_boards[id]["ready"] = Time.get_ticks_msec())
	board.dumpling_dropped.connect(func(tier: int) -> void:
		if _boards.has(id):
			_boards[id]["drops"] = int(_boards[id]["drops"]) + 1
		_drop_log.append({"board": id, "msec": Time.get_ticks_msec(), "tier": tier,
			"aim": board._aim_x if is_instance_valid(board) else -1.0}))


func _on_window_input(event: InputEvent) -> void:
	var entry: Dictionary = {"msec": Time.get_ticks_msec(), "device": event.device}
	var touch := event as InputEventScreenTouch
	var mouse := event as InputEventMouseButton
	if touch != null:
		entry["kind"] = "touch"
		entry["index"] = touch.index
		entry["pressed"] = touch.pressed
	elif mouse != null:
		entry["kind"] = "mouse"
		entry["index"] = -1
		entry["pressed"] = mouse.pressed
	else:
		return
	_inputs.append(entry)


func _count_inputs(kind: String, device: int) -> int:
	var n: int = 0
	for entry: Dictionary in _inputs:
		if entry["kind"] == kind and int(entry["device"]) == device:
			n += 1
	return n


## İlk eşleşen olayın anı (yoksa -1). `kind` "mouse" → öykünen fare (device -1), "touch" → parmak 0 (device 0).
func _input_time(kind: String, pressed: bool) -> int:
	for entry: Dictionary in _inputs:
		if entry["kind"] != kind or bool(entry["pressed"]) != pressed:
			continue
		if kind == "mouse" and int(entry["device"]) == -1:
			return int(entry["msec"])
		if kind == "touch" and int(entry["device"]) != -1 and int(entry["index"]) == 0:
			return int(entry["msec"])
	return -1


## Normal round (kurulum: doğrudan `_start_level` — Harita / sonuç / molanın vardığı yer) + yatışmanın bitmesi.
func _new_round(number: int) -> Node2D:
	if _main._board != null and is_instance_valid(_main._board):
		_main.abandon_run()
		await _settle(2)
	_main._start_level(_level(number))
	await _settle(3)
	await _wait_settled()
	_reset_actions()
	_inputs.clear()
	return _main._board


## Harita (board varsa terk: `abandon_run` → Harita) + yatışmanın bitmesi.
func _to_map() -> void:
	if _main._result.visible or (_main._board != null and is_instance_valid(_main._board)):
		_main.abandon_run()
		await _settle(2)
	else:
		_main._show_tab(1)
		await _settle(2)
	await _wait_settled()


## GERÇEK HUD geri dokunuşu → mola (board donar); pencere açılış hareketi oturur.
func _pause_hud(board: Node2D) -> bool:
	if board == null or not is_instance_valid(board):
		return false
	await _tap(_center(board._hud.back_button))
	await _settle(1)
	var ok: bool = _main.is_pause_open() and board._is_menu_paused
	await _wait(0.4)
	_reset_actions()
	return ok


## Round'u bitirir (kazanma / kayıp) ve sonucun görünmesini bekler (+ 0,3 sn).
func _finish_to_result(board: Node2D, won: bool) -> bool:
	if board == null or not is_instance_valid(board):
		return false
	board._finish(won)
	var shown: bool = await _until_result(2.5)
	await _wait(0.3)
	return shown


func _until_result(seconds: float) -> bool:
	var limit: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not _main._result.visible and Time.get_ticks_msec() < limit:
		await get_tree().process_frame
	await _settle(1)
	return _main._result.visible


## Değişimi başlatan GERÇEK düğme dokunuşu (parmak 0, cihaz sırası) + zaman çizelgesi.
func _button_tap(control: Control, unhandled: bool = false) -> Dictionary:
	var p: Vector2 = _center(control)
	var tl: Dictionary = {"gen0": _gen(), "board0": _board_id(), "until0": _main._touch_settle_until, "point": p,
		"boards0": _boards.size()}
	_inputs.clear()
	tl["down"] = Time.get_ticks_msec()
	await _finger(p, true)
	if unhandled:
		_unhandled_key_now()
	await _finger(p, false)
	_fill_timeline(tl)
	return tl


func _restart_tap(unhandled: bool = false) -> Dictionary:
	return await _button_tap(_main._pause.buttons()[1], unhandled)


## Zaman çizelgesi: öykünen fare bırakışı (düğme bu olayda tetiklenir), board girişi / hazır, yatışma kurulumu ve
## pencere sonu, başlatan parmağın ScreenTouch bırakışı.
func _fill_timeline(tl: Dictionary) -> void:
	tl["mouse_up"] = _input_time("mouse", false)
	tl["touch_up"] = _input_time("touch", false)
	var info: Dictionary = _boards.get(_board_id(), {})
	tl["enter"] = int(info.get("enter", -1))
	tl["ready"] = int(info.get("ready", -1))
	tl["until"] = _main._touch_settle_until
	tl["arm"] = int(tl["until"]) - _settle_msec if int(tl["until"]) != int(tl["until0"]) else -1


## Başlatan dokunuşun ScreenTouch bırakışından `gap` ms sonra aynı noktaya ikinci dokunuş; `hold` > 0 ise basılı kalır ve
## pencere sonundan `hold` ms sonra kalkar. Dönüş: basış Main'de yutuldu mu (dizi kaydı).
func _second_tap(tl: Dictionary, gap: int, hold: int = 0) -> bool:
	var base: int = int(tl["touch_up"]) if int(tl["touch_up"]) >= 0 else Time.get_ticks_msec()
	await _wait_until(base + gap)
	tl["down2"] = Time.get_ticks_msec()
	await _finger(tl["point"], true)
	var swallowed: bool = _main._settled_sequences.has(0)
	if hold > 0:
		await _wait_until(int(tl["until"]) + hold)
	tl["up2"] = Time.get_ticks_msec()
	await _finger(tl["point"], false)
	await _physics(3)
	await _settle(1)
	return swallowed


## Yatışma bittikten sonra İLK gerçekten bağımsız dokunuş: tam bir parça.
func _first_valid(board: Node2D, tag: String, tl: Dictionary = {}) -> void:
	if board == null or not is_instance_valid(board):
		_c("%s yatışmadan sonra ilk bağımsız dokunuş — board yok" % tag, false)
		return
	await _wait_settled()
	# Oyun kuralı (DROP_COOLDOWN 0,4 sn) de bitmiş olsun: düzeltmesiz kodda sızan bırakışın beklemesi ilk bağımsız
	# dokunuşu yutmasın — kontrol yalnız "pencere sonrası ilk bağımsız dokunuş" sorusunu ölçer.
	var guard: int = 0
	while is_instance_valid(board) and board._drop_cooldown > 0.0 and guard < 120:
		await get_tree().process_frame
		guard += 1
	var before: int = _drops_on(board)
	var at: int = Time.get_ticks_msec()
	await _tap(_board_point(board, 70.0))
	await _physics(3)
	if not tl.is_empty():
		tl["accept"] = at
	_c("%s yatışmadan sonra (pencere sonu +%d ms) ilk bağımsız dokunuş TAM bir parça" % [tag, at - _main._touch_settle_until],
		_drops_on(board) == before + 1 and _main._settled_sequences.is_empty())


func _timeline(tag: String, tl: Dictionary) -> void:
	var t0: int = int(tl.get("down", 0))
	var parts: PackedStringArray = []
	for key: String in ["mouse_up", "enter", "ready", "arm", "touch_up", "down2", "up2", "accept"]:
		if tl.has(key) and int(tl[key]) >= 0:
			parts.append("%s +%d" % [key, int(tl[key]) - t0])
	print("    zaman çizelgesi [%s] (ms, başlatan basıştan): %s · pencere sonu +%d" % [tag, " · ".join(parts),
		int(tl.get("until", t0)) - t0])


## Round sessiz mi: board var ve donuk değil, mola / Ayarlar / sonuç / pencereler kapalı, kabuk ekranları gizli.
func _quiet_round(board: Variant) -> bool:
	if board == null or not is_instance_valid(board):
		return false
	var shell_hidden: bool = true
	for screen: CanvasLayer in _main._screens:
		shell_hidden = shell_hidden and not screen.visible
	return (shell_hidden and not board._is_menu_paused and not _main.is_pause_open() and not _main._settings.visible
		and not _main._result.visible and not _main._missions.visible and not _main._challenge_sheet.visible
		and not _main._daily_rewards.visible)


func _stocks() -> Dictionary:
	return {"bomb": SaveManager.powerup_count(PowerUp.Type.BOMB),
		"upgrade": SaveManager.powerup_count(PowerUp.Type.UPGRADE),
		"shake": SaveManager.powerup_count(PowerUp.Type.SHAKE),
		"clear_small": SaveManager.powerup_count(PowerUp.Type.CLEAR_SMALL)}


func _progress_state() -> Dictionary:
	return {"dough": SaveManager.dough(), "xp": SaveManager.player_xp(), "rounds": SaveManager.total_rounds_played(),
		"achievements": SaveManager.unlocked_achievements(), "stars3": SaveManager.stars_for_level(3),
		"missions": (SaveManager.data.get("missions", {}) as Dictionary).duplicate(true),
		"challenge": SaveManager.daily_challenge_completed_day(), "endless": SaveManager.endless_high_score(),
		"merges": int(SaveManager.data.get("total_merges", 0)), "highest_tier": SaveManager.highest_tier_created()}


## Board'un sahiplik kaydı boş mu (TASK/051 alanı; alan yoksa — düzeltmesiz board — boş sayılır, betik hatası değil).
func _owned_empty(board: Variant) -> bool:
	if board == null or not is_instance_valid(board):
		return false
	var owned: Variant = board.get("_owned_touches")
	return owned == null or (owned as Dictionary).is_empty()


func _drops_on(board: Variant) -> int:
	if board == null or not is_instance_valid(board):
		return -1
	return int((_boards.get(board.get_instance_id(), {}) as Dictionary).get("drops", -1))


func _boards_since(tl: Dictionary) -> int:
	return _boards.size() - int(tl.get("boards0", _boards.size()))


func _board_id() -> int:
	return _main._board.get_instance_id() if _main._board != null and is_instance_valid(_main._board) else 0


func _differs(board: Variant, old_id: int) -> bool:
	return board != null and is_instance_valid(board) and board.get_instance_id() != old_id


func _gen() -> int:
	var value: Variant = _main.get("_round_generation")
	return int(value) if value != null else -1


func _level(number: int) -> LevelData:
	for level in LevelLibrary.load_levels():
		if level.level_number == number:
			return level
	return null


func _result_mode(name: String) -> int:
	var script: GDScript = load("res://scripts/ui/round_result.gd")
	return int((script.get_script_constant_map()["Mode"] as Dictionary)[name])


# --- Girdi / zaman yardımcıları ------------------------------------------------------------------------------------------

func _touch_event(pos: Vector2, pressed: bool, index: int) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = pos
	touch.pressed = pressed
	return touch


## Parmak olayı Input'a verilir ve HEMEN dağıtılır (öykünen fare önce, sonra ScreenTouch — cihazdaki sıra).
func _finger(pos: Vector2, pressed: bool, index: int = 0) -> void:
	Input.parse_input_event(_touch_event(pos, pressed, index))
	Input.flush_buffered_events()
	await get_tree().process_frame


func _tap(pos: Vector2, index: int = 0) -> void:
	await _finger(pos, true, index)
	await _finger(pos, false, index)


## Parmak sürüklemesi (ScreenDrag; öykünen fare hareketi yalnız ilk parmakta).
func _drag(to: Vector2, from: Vector2, index: int = 0) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.position = to
	drag.relative = to - from
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	await get_tree().process_frame


## Android ACTION_CANCEL: bırakış `canceled == true` (TASK/046.2).
func _cancel(pos: Vector2, index: int = 0) -> void:
	var touch := _touch_event(pos, false, index)
	touch.canceled = true
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	await get_tree().process_frame


## Hiçbir şeyin işlemediği bir girdi olayı (eşlenmemiş tuş): ardından Viewport'un "işlendi" bayrağı kapalı kalır.
func _unhandled_key_now() -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_F13
		key.physical_keycode = KEY_F13
		key.pressed = pressed
		Input.parse_input_event(key)
		Input.flush_buffered_events()


## Android geri (Main'in 250 ms debounce'u gerçek saatle — iki basış arasında boşluk).
func _back() -> void:
	var gap: int = _last_back_msec + BACK_GAP_MSEC - Time.get_ticks_msec()
	if gap > 0:
		await _wait(float(gap) / 1000.0)
	_last_back_msec = Time.get_ticks_msec()
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(1)


func _wait_until(target: int) -> void:
	var left: int = target - Time.get_ticks_msec()
	if left > 0:
		await _wait(float(left) / 1000.0)
	await get_tree().process_frame


## Main'in yatışma penceresi bitene kadar (+80 ms) GERÇEK süre.
func _wait_settled() -> void:
	await _wait_until(_main._touch_settle_until + 80)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _screen(canvas: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * canvas


func _center(control: Control) -> Vector2:
	return _screen(control.get_global_rect().get_center())


## Kabın içinde, parçalardan uzak boş bir nokta (pencere pikseli).
func _board_point(board: Node2D, dx: float) -> Vector2:
	return _screen(board.world_to_screen(Vector2(board._center_x() + dx, board.overflow_line_y() + 60.0)))


## Pencere pikseli → board dünyasında x.
func _world_x(board: Node2D, window_point: Vector2) -> float:
	var canvas: Vector2 = get_viewport().get_screen_transform().affine_inverse() * window_point
	return board.screen_to_world(canvas).x


func _near(a: float, b: float, tolerance: float = 2.0) -> bool:
	return absf(a - b) <= tolerance


# --- Kayıt yardımcıları --------------------------------------------------------------------------------------------------

## JSON sayı normalizasyonu: tam değerli float → int.
func _norm(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number: float = value
			return int(number) if is_equal_approx(number, roundf(number)) else number
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key: Variant in value:
				out[str(key)] = _norm(value[key])
			return out
		TYPE_ARRAY:
			var items: Array = []
			for item: Variant in value:
				items.append(_norm(item))
			return items
	return value


func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(_norm(a)) == JSON.stringify(_norm(b))


func _bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(PATH) if FileAccess.file_exists(PATH) else PackedByteArray()


func _strip_comments(code: String) -> String:
	var lines: PackedStringArray = []
	for line in code.split("\n"):
		var at: int = line.find("#")
		lines.append(line if at == -1 else line.substr(0, at))
	return "\n".join(lines)


## Fonksiyon gövdesi: başlıktan bir sonraki üst düzey `func`'a kadar.
func _function(code: String, header: String) -> String:
	var start: int = code.find(header)
	if start < 0:
		return ""
	var end: int = code.find("\nfunc ", start + header.length())
	return code.substr(start, (end if end >= 0 else code.length()) - start)


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
