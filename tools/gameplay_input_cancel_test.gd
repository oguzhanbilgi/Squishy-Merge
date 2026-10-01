extends Node
## TASK/046.2 — iptal edilen oyun dokunuşu (Android ACTION_CANCEL) testi. Headless.
## Hata (A36, gerçek ACTION_CANCEL 2/2): Android ACTION_CANCEL Godot'a `pressed == false`,
## `canceled == true` olan bir InputEventScreenTouch olarak gelir (4.6.3
## `AndroidInputHandler::_cancel_all_touch` → `_parse_all_touch(false, true)`); GameBoard'un
## normal dokunuş yolu her `pressed == false` bırakışında `_drop()` çağırıyordu → iptal edilen
## dokunuş bekleyen parçayı GEÇERLİ bir bırakış gibi düşürüyordu.
## Sözleşme: iptal edilen bırakış bırakma DEĞİLDİR — dizi parça düşürmeden biter (drop 0,
## bekleyen / sıradaki tier ve torba aynı, drop sesi / bekleme süresi / merge / skor / kayıt
## etkisi yok); nişan parmağın son konumunda kalabilir; sonraki bağımsız geçerli dokunuş HEMEN
## tam bir parça düşürür. Zamanlayıcı / gecikme / ek yatışma / takılı parmak durumu yok.
## SAHİBİN KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_input_cancel/` altına
## yönlendirilir; gerçek kayıt ailesinin (kanonik + .tmp + .bak) baytları başta / sonda
## karşılaştırılır.
##
##   godot --headless --audio-driver Dummy --path . res://tools/gameplay_input_cancel_test.tscn
##
## Bölümler:
##   doğrudan yol     GameBoard._unhandled_input: bas (+ sürükle) + bırak → 1 drop, önizleme
##                    ilerler; bas + iptal → 0; bas +
##                    sürükle + iptal → 0 (nişan sürüklenen yerde); basışsız iptal → 0; iptal
##                    sonrası dokunuş hemen 1; iptal tier / torba / ses / bekleme / skor / kayıt
##                    değiştirmez; bekleme süresinde iptal hiçbir şey yapmaz (önceki gibi)
##   gerçek dağıtım   Input.parse_input_event → viewport → Main._input → GameBoard: normal düşer,
##                    iptal düşmez, sürükle + iptal düşmez, sonraki dokunuş hemen kendi x'inde
##   Main yatışması   pencerede başlayan dizinin iptal bırakışı diziyi kapatır (drop yok), sonraki
##                    bağımsız dokunuş normal; TOUCH_SETTLE_MSEC 300 aynen
##   hedefli güçler   Bomba / Büyütücü: hedef basışı + iptal bırakışı → güç bir kez, drop 0, stok
##                    en fazla bir kez; boşluğa basış (iptal) + iptal bırakışı → stok aynı; sonraki
##                    bağımsız dokunuş düşürür
##   çoklu parmak     parmak 0 iptal, parmak 1 geçerli → tam bir drop; ikisi birden iptal (Android
##                    hepsini iptal eder) → 0, sonraki dokunuş hemen 1 (genel "iptal" durumu yok)
##   tutorial         FIRST_DROP: iptal düşürmez, adım / kuyruk aynı; geçerli bırakış güvenli
##                    banda kırpılmış tek parça düşürür (yardımlı girdi aynen)
##   masaüstü / kod   fare tıklaması (dokunuştan öykünür) düşürür; doğrudan `_drop()` aynen;
##                    DROP_COOLDOWN 0.4 aynen
##   kaynak           koruma yalnız GameBoard normal dokunuş yolunda; `_drop()` / Main değişmedi

const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const LEVEL_PATH: String = "res://resources/levels/level_08.tres"
const DIR: String = "user://qa_input_cancel"
const PATH: String = DIR + "/save.json"
const SECTIONS: int = 8
## Drop bekleme süresinin (0.4 s) bitmesi + kare payı.
const COOLDOWN_WAIT: float = 0.45
## Bomba mermisi 0.28 s uçar; kaldırma + kare payı (power_input_test ile aynı).
const BOMB_SETTLE: float = 0.45

var _board: Node2D
var _main: Node2D
var _drops: int = 0
var _drop_aims: Array[float] = []
var _popup_flag_before: bool = true
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
	_popup_flag_before = DailyRewards.auto_popup_enabled
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_owner_state = _owner_snapshot()
	_saved_data = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)
	SaveManager.save_path = PATH
	SaveManager.data = _fixture(true)
	SaveManager.save_game()
	get_tree().create_timer(300.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 300 s'de bitmedi")
			# Main hâlâ çalışıyor olabilir: kayıt yolu gerçek dosyaya DÖNDÜRÜLMEZ.
			_teardown(false)
			get_tree().quit(2))
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame

	await _direct_board_path()
	await _real_dispatch_path()
	await _main_settle_cancel()
	await _targeted_powers()
	await _multiple_fingers()
	await _tutorial_assist()
	await _desktop_and_code_paths()
	_source_contract()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	await _free_main()
	await _free_board()
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
	if restore_path:
		SaveManager.save_path = SaveManager.SAVE_PATH
		SaveManager.data = _saved_data.duplicate(true)
	for path in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- 1) Doğrudan GameBoard yolu ---------------------------------------------------------------

func _direct_board_path() -> void:
	print("-- doğrudan yol: GameBoard._unhandled_input")
	await _make_board(8, 2)
	var p: Vector2 = _point(-90.0)
	var sound0: int = _drop_sounds()
	var next0: int = _board._next_tier
	await _direct(p, true)
	await _direct(p, false)
	_c("A1 bas + geçerli bırakış: tam bir drop, nişanın x'inde, drop sesi bir kez, bekleme süresi başladı",
		_drops == 1 and _near(_drop_aims[0], p.x) and _drop_sounds() - sound0 == 1
		and _board._drop_cooldown > 0.0)
	_c("A1 önizleme ilerledi: eski 'sıradaki' artık bekleyen parça", _board._pending_tier == next0)

	await _make_board(8, 2)
	var d0: Vector2 = _point(110.0)
	var d1: Vector2 = _point(-70.0)
	await _direct(d0, true)
	await _direct_drag(d1)
	await _direct(d1, false)
	_c("A1b bas + sürükle + geçerli bırakış: tam bir drop, sürüklenen x'te", _drops == 1 and _near(_drop_aims[0], d1.x))

	await _make_board(8, 2)
	var before: Dictionary = _state()
	var q: Vector2 = _point(70.0)
	await _direct(q, true)
	await _direct(q, false, true)
	var after: Dictionary = _state()
	_c("A2 bas + İPTAL bırakışı: drop 0, dumpling_dropped yayılmadı, yeni parça yok", _drops == 0
		and after["pieces"] == before["pieces"])
	_c("A6 iptal bekleyen / sıradaki tier'ı ve torbayı ilerletmedi", after["pending"] == before["pending"]
		and after["next"] == before["next"] and after["bag"] == before["bag"])
	_c("A7 iptal: drop sesi yok, bekleme süresi başlamadı, merge / skor / kayıt aynı",
		after["drop_sound"] == before["drop_sound"] and _board._drop_cooldown == 0.0
		and after["merges"] == before["merges"] and after["score"] == before["score"]
		and after["save"] == before["save"])
	_c("A7 nişan iptal edilen basışın x'inde kalabilir (geri alma yok)", _near(_board._aim_x, q.x))
	var r: Vector2 = _point(-120.0)
	await _direct(r, true)
	await _direct(r, false)
	_c("A5 iptalden HEMEN sonra bağımsız geçerli dokunuş: tam bir drop, kendi x'inde (bekleme yok)",
		_drops == 1 and _near(_drop_aims[0], r.x))

	await _make_board(8, 2)
	before = _state()
	var a: Vector2 = _point(120.0)
	var b: Vector2 = _point(-110.0)
	await _direct(a, true)
	await _direct_drag(b)
	await _direct(b, false, true)
	after = _state()
	_c("A3 bas + sürükle + İPTAL: drop 0, nişan sürüklenen x'te, tier / torba aynı", _drops == 0
		and _near(_board._aim_x, b.x) and after["pending"] == before["pending"]
		and after["next"] == before["next"] and after["bag"] == before["bag"])

	await _make_board(8, 2)
	before = _state()
	await _direct(_point(40.0), false, true)
	after = _state()
	_c("A4 basışı olmayan (anlamlı oyun basışı yokken) İPTAL bırakışı: drop 0, durum aynı", _drops == 0
		and after["pending"] == before["pending"] and after["bag"] == before["bag"]
		and after["drop_sound"] == before["drop_sound"])
	var cool4: float = _board._drop_cooldown
	_drops = 0
	_drop_aims.clear()
	await _direct(_point(-40.0), true)
	await _direct(_point(-40.0), false)
	_c("A4 ardından (bekleme 0) geçerli dokunuş hemen kendi x'inde tam bir drop", is_zero_approx(cool4)
		and _drops == 1 and _near(_drop_aims[0], _point(-40.0).x))

	print("-- doğrudan yol: bekleme süresinde iptal (önceki gibi hiçbir şey)")
	await _make_board(8, 2)
	await _direct(_point(0.0), true)
	await _direct(_point(0.0), false)
	var cooldown_before: float = _board._drop_cooldown
	before = _state()
	await _direct(_point(60.0), true)
	await _direct(_point(60.0), false, true)
	after = _state()
	_c("A8 bekleme süresinde bas + İPTAL: ek drop yok, tier / torba aynı, bekleme sıfırlanmadı",
		cooldown_before > 0.0 and _drops == 1 and after["pending"] == before["pending"]
		and after["bag"] == before["bag"] and _board._drop_cooldown <= cooldown_before)
	await _direct(_point(60.0), true)
	await _direct(_point(60.0), false)
	_c("A8 bekleme süresinde geçerli bırakış da düşürmez (önceki kural aynen)", _drops == 1)
	await _wait(COOLDOWN_WAIT)
	await _direct(_point(-60.0), true)
	await _direct(_point(-60.0), false)
	_c("A8 bekleme bitince geçerli dokunuş düşürdü", _drops == 2)
	_sections_done += 1


# --- 2) Gerçek Input dağıtımı: viewport → Main → GameBoard -------------------------------------

func _real_dispatch_path() -> void:
	print("-- gerçek dağıtım: Input.parse_input_event → Main._input → GameBoard")
	await _boot_main(true)
	await _start_round()
	var p: Vector2 = _point(-90.0)
	await _finger(p, true)
	await _finger(p, false)
	_c("B normal parmak dokunuşu Main üzerinden tam bir drop (nişan x'inde)", _drops == 1
		and _near(_drop_aims[0], p.x))

	await _start_round()
	var before: Dictionary = _state()
	var q: Vector2 = _point(80.0)
	await _finger(q, true)
	await _finger(q, false, true)
	var after: Dictionary = _state()
	_c("B Main üzerinden bas + İPTAL: drop 0, tier / torba / ses / skor / kayıt aynı", _drops == 0
		and after["pending"] == before["pending"] and after["next"] == before["next"]
		and after["bag"] == before["bag"] and after["drop_sound"] == before["drop_sound"]
		and after["score"] == before["score"] and after["save"] == before["save"])
	_c("B iptal sonrası Main'de takılı dizi yok (yatışma kaydı boş)", _main._settled_sequences.is_empty())
	var r: Vector2 = _point(-130.0)
	await _finger(r, true)
	await _finger(r, false)
	_c("B iptalden hemen sonra bağımsız dokunuş: tam bir drop, kendi x'inde", _drops == 1
		and _near(_drop_aims[0], r.x))

	print("-- gerçek dağıtım: sürükle, sonra iptal (nişan kalabilir, parça düşmez)")
	await _start_round()
	before = _state()
	var a: Vector2 = _point(130.0)
	var b: Vector2 = _point(-120.0)
	await _finger(a, true)
	await _finger_drag(b)
	await _finger(b, false, true)
	after = _state()
	_c("C bas + sürükle + İPTAL: drop 0, nişan son sürüklenen x'te, tier / torba aynı", _drops == 0
		and _near(_board._aim_x, b.x) and after["pending"] == before["pending"]
		and after["bag"] == before["bag"])
	var c: Vector2 = _point(60.0)
	await _finger(c, true)
	await _finger(c, false)
	_c("C sonraki geçerli dokunuş kendi x'inde nişan aldı ve tam bir parça düşürdü", _drops == 1
		and _near(_drop_aims[0], c.x))
	_sections_done += 1


# --- 3) Main 300 ms yatışması (TASK/045.2) aynen ---------------------------------------------

func _main_settle_cancel() -> void:
	print("-- Main yatışması: pencerede başlayan dizinin İPTAL bırakışı diziyi kapatır")
	await _start_round()
	_main.settle_touch_input()
	var p: Vector2 = _point(90.0)
	await _finger(p, true)
	_c("D ön koşul: pencerede başlayan basış yutuldu (dizi kayıtlı)", _main._settled_sequences.has(0))
	await _finger(p, false, true)
	_c("D İPTAL bırakışı da yutuldu ve diziyi kapattı: drop yok, yatışma kaydı boş", _drops == 0
		and _main._settled_sequences.is_empty())
	await _wait(0.32)
	var r: Vector2 = _point(-90.0)
	await _finger(r, true)
	await _finger(r, false)
	_c("D pencereden sonra bağımsız dokunuş normal düşürdü", _drops == 1 and _near(_drop_aims[0], r.x))
	_c("D Main yatışma süresi aynen 300 ms", _main.TOUCH_SETTLE_MSEC == 300)
	await _free_main()
	_sections_done += 1


# --- 4) Hedefli güçler (TASK/045.1) aynen -------------------------------------------------------

func _targeted_powers() -> void:
	print("-- Bomba: hedef basışı + İPTAL bırakışı")
	await _make_board(8, 2)
	var target: Dumpling = _spawn(3, Vector2(_board._center_x(), _board.FLOOR_Y - 38.0))
	var other: Dumpling = _spawn(4, Vector2(_board._center_x() + 150.0, _board.FLOOR_Y - 45.0))
	await _frames(50)
	var pending_before: int = _board._pending_tier
	_arm(PowerUp.Type.BOMB)
	var at: Vector2 = target.global_position
	await _finger(at, true)
	_c("E Bomba basışı gücü çözdü: silah indi, stok 2 → 1", not _board._powerups.is_armed()
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == 1)
	await _finger(at, false, true)
	_c("E Bomba dizisinin İPTAL bırakışı tüketildi: drop 0, bekleyen tier aynı", _drops == 0
		and _board._pending_tier == pending_before and _board._targeting_touches.is_empty())
	await _wait(BOMB_SETTLE)
	_c("E Bomba etkisi aynen (hedef kaldırıldı, diğeri duruyor), stok tam bir kez düştü (1)",
		not is_instance_valid(target) and is_instance_valid(other)
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == 1)
	await _finger(_empty(), true)
	await _finger(_empty(), false)
	_c("E Bomba sonrası bağımsız geçerli dokunuş düşürdü", _drops == 1)

	print("-- Büyütücü: hedef basışı + İPTAL bırakışı")
	await _make_board(8, 2)
	target = _spawn(3, Vector2(_board._center_x(), _board.FLOOR_Y - 38.0))
	await _frames(50)
	var pos: Vector2 = target.global_position
	pending_before = _board._pending_tier
	_arm(PowerUp.Type.UPGRADE)
	await _finger(pos, true)
	_c("E Büyütücü basışı: stok 2 → 1, hedef kilitli", SaveManager.powerup_count(PowerUp.Type.UPGRADE) == 1
		and is_instance_valid(target) and target.is_merging)
	await _finger(pos, false, true)
	_c("E Büyütücü dizisinin İPTAL bırakışı: drop 0, bekleyen tier aynı", _drops == 0
		and _board._pending_tier == pending_before)
	await _wait(0.3)
	await _frames(2)
	_c("E Büyütücü etkisi aynen (tek T4 hedefin yerinde), stok tam bir kez düştü (1)", _tiers() == [4]
		and _pieces()[0].global_position.distance_to(pos) <= 30.0
		and SaveManager.powerup_count(PowerUp.Type.UPGRADE) == 1)
	await _finger(_empty(), true)
	await _finger(_empty(), false)
	_c("E Büyütücü sonrası bağımsız geçerli dokunuş düşürdü", _drops == 1)

	print("-- hedefleme: boşluğa basış (iptal) + İPTAL bırakışı; silahlıyken basışsız iptal")
	await _make_board(8, 2)
	_spawn(3, Vector2(_board._center_x(), _board.FLOOR_Y - 38.0))
	await _frames(40)
	_arm(PowerUp.Type.BOMB)
	await _finger(_empty(), true)
	await _finger(_empty(), false, true)
	_c("E boşluğa basış hedeflemeyi iptal etti (stok aynı 2), İPTAL bırakışı düşürmedi", not _board._powerups.is_armed()
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == 2 and _drops == 0)
	_arm(PowerUp.Type.BOMB)
	await _finger(_empty(), false, true)
	_c("E silahlıyken basışsız İPTAL bırakışı: hedefleme açık kaldı, stok aynı, drop 0", _board._powerups.is_armed()
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == 2 and _drops == 0)
	_board._powerups.cancel()
	await _finger(_empty(), true)
	await _finger(_empty(), false)
	_c("E ardından bağımsız geçerli dokunuş düşürdü", _drops == 1)
	_sections_done += 1


# --- 5) Çoklu parmak: bağımsızlık aynen, genel "iptal" durumu yok ------------------------------

func _multiple_fingers() -> void:
	print("-- çoklu parmak: parmak 0 iptal, parmak 1 geçerli")
	await _make_board(8, 2)
	var p0: Vector2 = _point(120.0)
	var p1: Vector2 = _point(-100.0)
	await _finger(p0, true, false, 0)
	await _finger(p1, true, false, 1)
	await _finger(p0, false, true, 0)
	_c("F parmak 0'ın İPTAL bırakışı düşürmedi", _drops == 0)
	var cool_f: float = _board._drop_cooldown
	_drops = 0
	_drop_aims.clear()
	await _finger(p1, false, false, 1)
	_c("F parmak 1'in geçerli bırakışı (bekleme 0) tam bir drop, parmak 1'in nişanında", is_zero_approx(cool_f)
		and _drops == 1 and _near(_drop_aims[0], p1.x))

	print("-- çoklu parmak: Android hepsini iptal eder (iki parmak birden)")
	await _make_board(8, 2)
	var before: Dictionary = _state()
	await _finger(p0, true, false, 0)
	await _finger(p1, true, false, 1)
	await _finger(p0, false, true, 0)
	await _finger(p1, false, true, 1)
	var after: Dictionary = _state()
	_c("F iki parmağın İPTAL bırakışı: drop 0, tier / torba aynı", _drops == 0
		and after["pending"] == before["pending"] and after["bag"] == before["bag"])
	var cool_all: float = _board._drop_cooldown
	_drops = 0
	_drop_aims.clear()
	var p2: Vector2 = _point(10.0)
	await _finger(p2, true, false, 0)
	await _finger(p2, false, false, 0)
	_c("F ardından (bekleme 0) bağımsız dokunuş HEMEN kendi x'inde tam bir drop (takılı / genel iptal durumu yok)",
		is_zero_approx(cool_all) and _drops == 1 and _near(_drop_aims[0], p2.x))
	_sections_done += 1


# --- 6) Tutorial yardımlı girdisi aynen --------------------------------------------------------

func _tutorial_assist() -> void:
	print("-- tutorial FIRST_DROP: iptal düşürmez, geçerli bırakış güvenli banda kırpılır")
	await _boot_main(false)
	var tutorial: TutorialController = _main._tutorial as TutorialController
	_c("ön koşul: yeni oyuncu tutorial'a girdi (WELCOME)", tutorial != null
		and tutorial.current_step() == TutorialController.Step.WELCOME)
	tutorial.advance()
	await get_tree().process_frame
	_board = _main._board
	_board.dumpling_dropped.connect(_on_dropped)
	_drops = 0
	_drop_aims.clear()
	_c("ön koşul: FIRST_DROP, board girdisi açık", tutorial.current_step() == TutorialController.Step.FIRST_DROP
		and not _board.is_tutorial_input_locked())
	var pending_before: int = _board._pending_tier
	var next_before: int = _board._next_tier
	var queue_before: int = _board.tutorial_queue_size()
	var center: float = _board.get_viewport_rect().size.x * 0.5
	var half: float = _board.level.container_width * TutorialController.FIRST_DROP_CLAMP_RATIO
	var far := Vector2(center - 500.0, _board.overflow_line_y() + 60.0)
	await _direct(far, true)
	await _direct(far, false, true)
	_c("tutorial: İPTAL bırakışı düşürmedi, adım FIRST_DROP, bekleyen / sıradaki / kuyruk aynı", _drops == 0
		and _pieces().is_empty() and tutorial.current_step() == TutorialController.Step.FIRST_DROP
		and _board._pending_tier == pending_before and _board._next_tier == next_before
		and _board.tutorial_queue_size() == queue_before)
	var locked_after_cancel: bool = _board.is_tutorial_input_locked()
	_drops = 0
	_drop_aims.clear()
	await _direct(far, true)
	await _direct(far, false)
	_c("tutorial: iptalden sonra girdi açık; geçerli bırakış tek T1 düşürdü, güvenli bandın içinde (yardım aynen)",
		not locked_after_cancel and _drops == 1 and _pieces().size() == 1 and _pieces()[0].tier == 1
		and absf(_pieces()[0].position.x - center) <= half + 1.0)
	await _free_main()
	_sections_done += 1


# --- 7) Masaüstü fare ve kod yolları aynen -----------------------------------------------------

func _desktop_and_code_paths() -> void:
	print("-- masaüstü fare (dokunuş fareden öykünür) ve doğrudan `_drop()` aynen")
	await _make_board(8, 2)
	var p: Vector2 = _point(-70.0)
	await _mouse(p, true)
	await _mouse(p, false)
	_c("masaüstü fare tıklaması tam bir drop (fare yolu değişmedi)", _drops == 1 and _near(_drop_aims[0], p.x))
	await _make_board(8, 2)
	_board._set_aim(_point(50.0).x)
	_board._drop()
	_c("geçerli çağıran (araç / bot) doğrudan `_drop()`: tam bir drop, bekleme 0.4", _drops == 1
		and is_equal_approx(_board._drop_cooldown, _board.DROP_COOLDOWN))
	_c("DROP_COOLDOWN aynen 0.4", is_equal_approx(_board.DROP_COOLDOWN, 0.4))
	_sections_done += 1


# --- 8) Kaynak sözleşmesi --------------------------------------------------------------------------

func _source_contract() -> void:
	print("-- kaynak")
	var board: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/game/game_board.gd"))
	var input_fn: String = _function(board, "func _unhandled_input(")
	_c("normal dokunuş yolu: iptal edilen bırakış `_drop()`'a ulaşmaz", input_fn.contains("elif not touch.canceled:")
		and input_fn.find("elif not touch.canceled:") < input_fn.find("_drop()"))
	_c("koruma zamanlayıcısız / durumsuz (süre, tick, yeni parmak durumu yok)", not input_fn.contains("msec")
		and not input_fn.contains("timer") and not input_fn.contains("delta"))
	var drop_fn: String = _function(board, "func _drop(")
	_c("`_drop()` geçerli çağıranlar için aynen (iptal bilgisi taşımaz)", not drop_fn.is_empty()
		and not drop_fn.contains("cancel"))
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var main_input: String = _function(_strip_comments(main_src), "func _input(")
	_c("Main yatışması aynen: TOUCH_SETTLE_MSEC 300, `_input` iptali özel ele almıyor (bırakış dizisi kapatır)",
		main_src.contains("const TOUCH_SETTLE_MSEC: int = 300") and not main_input.is_empty()
		and not main_input.contains("cancel"))
	_sections_done += 1


# --- Yardımcılar ------------------------------------------------------------------------------------

func _fixture(onboarded: bool) -> Dictionary:
	var d: Dictionary = SaveManager.DEFAULT_DATA.duplicate(true)
	d["onboarding_completed"] = onboarded
	d["age_ad_band"] = "ADULT" if onboarded else d["age_ad_band"]
	d["powerup_starter_granted"] = true
	d["last_login_date"] = Time.get_date_string_from_system()
	d["highest_level_unlocked"] = 9 if onboarded else 1
	d["powerups"] = {"bomb": 3, "upgrade": 3, "shake": 2, "clear_small": 2}
	return d


func _make_board(level: int, stock: int) -> void:
	await _free_main()
	await _free_board()
	GameState.reset_run()
	var stocks: Dictionary = {}
	for type in PowerUp.all():
		stocks[PowerUp.save_key(type)] = stock
	SaveManager.data["powerups"] = stocks
	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(load("res://resources/levels/level_%02d.tres" % level))
	_board.dumpling_dropped.connect(_on_dropped)
	add_child(_board)
	_drops = 0
	_drop_aims.clear()
	await get_tree().process_frame
	await get_tree().process_frame


func _free_board() -> void:
	if _board != null and is_instance_valid(_board) and _main == null:
		_board.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_board = null


func _boot_main(onboarded: bool) -> void:
	await _free_main()
	await _free_board()
	SaveManager.data = _fixture(onboarded)
	SaveManager.save_game()
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _frames(3)
	await _wait(0.4)


func _free_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		_board = null
		await get_tree().process_frame
		await get_tree().process_frame


func _start_round() -> void:
	_main._start_level(load(LEVEL_PATH))
	await _frames(3)
	_board = _main._board
	_board.dumpling_dropped.connect(_on_dropped)
	_drops = 0
	_drop_aims.clear()
	await _wait(COOLDOWN_WAIT)


func _on_dropped(_tier: int) -> void:
	_drops += 1
	_drop_aims.append(_board._aim_x)


## Bekleyen / sıradaki tier, torba / tutorial kuyruğu, parça, ses, skor ve kayıt görüntüsü.
func _state() -> Dictionary:
	var bag: Array = []
	var source: Variant = _board._drop_bag.get("_bag")
	if source is Array:
		bag = (source as Array).duplicate()
	return {
		"pending": _board._pending_tier,
		"next": _board._next_tier,
		"bag": bag,
		"queue": _board._tutorial_queue.duplicate(),
		"pieces": _pieces().size(),
		"drop_sound": _drop_sounds(),
		"merges": GameState.merge_count,
		"score": GameState.score,
		"save": JSON.stringify(SaveManager.data),
	}


## Drop sesi DENEMELERİ: çalınan + bekleme / kanal yüzünden atılan (ikisi de `play_drop` çağrısı).
func _drop_sounds() -> int:
	return int(AudioManager.play_count.get(&"drop", 0)) + int(AudioManager.drop_count.get(&"drop", 0))


## Kabın içinde, parçalardan uzak boş bir dünya noktası (taşma çizgisinin altında).
func _point(dx: float) -> Vector2:
	return Vector2(_board._center_x() + dx, _board.overflow_line_y() + 60.0)


func _empty() -> Vector2:
	return _point(-150.0)


## Doğrudan yol: olay GameBoard'un girdi işleyicisine verilir (viewport koordinatı).
func _direct(world: Vector2, pressed: bool, canceled: bool = false, index: int = 0) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = _board.world_to_screen(world)
	touch.pressed = pressed
	touch.canceled = canceled
	_board._unhandled_input(touch)
	await get_tree().process_frame


func _direct_drag(world: Vector2, index: int = 0) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.position = _board.world_to_screen(world)
	_board._unhandled_input(drag)
	await get_tree().process_frame


## Gerçek dağıtım: Input'a verilir ve HEMEN dağıtılır (öykünen fare önce, sonra ScreenTouch —
## cihazdaki sıra); tampon boşaltılır ki sıra deterministik olsun.
func _finger(world: Vector2, pressed: bool, canceled: bool = false, index: int = 0) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = _win(world)
	touch.pressed = pressed
	touch.canceled = canceled
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _finger_drag(world: Vector2, index: int = 0) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.position = _win(world)
	drag.relative = Vector2(-80.0, 0.0)
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	await get_tree().process_frame


## Masaüstü fare tıklaması (device 0; proje ayarı dokunuşu fareden öykünür, device -1).
func _mouse(world: Vector2, pressed: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	click.position = _win(world)
	click.global_position = click.position
	if pressed:
		click.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await get_tree().process_frame


## Dünya noktası → Input.parse_input_event'in beklediği PENCERE pikseli.
func _win(world: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * _board.world_to_screen(world)


## Güç butonu (PowerBar sinyali — GameBoard'un gerçek bağlantısı).
func _arm(type: PowerUp.Type) -> void:
	_board._power_bar.power_pressed.emit(int(type))


func _spawn(tier: int, at: Vector2) -> Dumpling:
	return _board._spawn_dumpling(tier, at)


func _pieces() -> Array[Dumpling]:
	var out: Array[Dumpling] = []
	for child in _board._dumpling_layer.get_children():
		var d := child as Dumpling
		if d != null and is_instance_valid(d) and not d.is_queued_for_deletion():
			out.append(d)
	return out


func _tiers() -> Array[int]:
	var out: Array[int] = []
	for d in _pieces():
		out.append(d.tier)
	out.sort()
	return out


## Nişan / düşüş x'i dokunulan noktaya yakın mı (kenar kırpması için 2 px pay).
func _near(a: float, b: float) -> bool:
	return absf(a - b) <= 2.0


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _strip_comments(code: String) -> String:
	var lines: PackedStringArray = []
	for line in code.split("\n"):
		var at: int = line.find("#")
		lines.append(line if at == -1 else line.substr(0, at))
	return "\n".join(lines)


func _function(code: String, header: String) -> String:
	var start: int = code.find(header)
	if start == -1:
		return ""
	var end: int = code.find("\nfunc ", start + header.length())
	return code.substr(start, (end - start) if end != -1 else -1)


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for path in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out
