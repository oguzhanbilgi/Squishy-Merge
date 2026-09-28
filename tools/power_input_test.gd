extends Node
## TASK/045.1 — hedefli güç (Bomba / Büyütücü) dokunuş tüketimi testi. Headless.
## Hata (A36): hedef seçen dokunuşun BIRAKIŞI normal drop'a düşüp bekleyen parçayı da
## düşürüyordu. Sözleşme: hedefleme modunda basılan dokunuşun tamamı (basış + sürükleme +
## bırakış) hedeflemenindir; güç tam bir kez uygulanır; sonraki bağımsız dokunuş hemen
## normal düşürür. SAHİBİN KAYDINA DOKUNMAZ: SaveManager test boyunca
## `user://qa_power_input/` altındaki bir yola yönlendirilir.
##
##   godot --headless --audio-driver Dummy --path . res://tools/power_input_test.tscn
##
## Kontroller:
##   Bomba / Büyütücü   parmak (ScreenTouch device 0): bas → güç bir kez, stok bir kez;
##                      bırak → parça DÜŞMEZ; etki (Bomba kaldırma / Büyütücü +1 tier,
##                      T7→T8 kutlaması) aynen; sonraki bağımsız dokunuş düşürür
##   kenar durumları    geçersiz hedef (T8'e Büyütücü: hedefleme açık kalır), boşluğa dokunup
##                      iptal, butonla iptal, sürükle-bırak, hızlı dokunuşlar, iki parmak,
##                      kaybolan bırakış (takılı bastırma yok), duraklamada bırakış, stok 0
##   masaüstü / kod     fareden öykünen dokunuş (device -1), doğrudan `_unhandled_input`,
##                      mevcut `_use_targeted_power` kod yolu
##   anında güçler      Sarsıntı / Temizleyici aynen; sonraki dokunuş normal
##   Main               gerçek sahnede aynı sözleşme + 300 ms parmak yatışması aynen
##   kaynak             tüketim durum tabanlı (zamanlayıcı yok), yatışma sabiti 300

const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_power_input"
const PATH: String = DIR + "/save.json"
const SECTIONS: int = 7

var _board: Node2D
var _main: Node2D
var _drops: int = 0
var _refills: Array[int] = []
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
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 240 s'de bitmedi")
			_teardown()
			get_tree().quit(2))

	await _bomb_finger()
	await _upgrade_finger()
	await _edge_cases()
	await _mouse_and_code_paths()
	await _instant_powers()
	await _main_integration()
	_source_contract()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

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


func _teardown() -> void:
	DailyRewards.auto_popup_enabled = true
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	for path in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- 1) Bomba, parmak ----------------------------------------------------------------------

func _bomb_finger() -> void:
	print("-- Bomba: parmak dokunuşu (ScreenTouch device 0)")
	await _make_board(8, 2)
	var cx: float = _board._center_x()
	var target: Dumpling = _spawn(3, Vector2(cx, _board.FLOOR_Y - 38.0))
	var other: Dumpling = _spawn(4, Vector2(cx + 150.0, _board.FLOOR_Y - 45.0))
	await _frames(50)
	var aim_before: float = _board._aim_x
	var pending_before: int = _board._pending_tier
	_arm(PowerUp.Type.BOMB)
	_c("Bomba silahlandı (güç butonu sinyali)", _board._powerups.armed_type() == int(PowerUp.Type.BOMB))
	var at: Vector2 = _win(target.global_position)
	await _touch(at, true)
	_c("basış: güç çözüldü, silah indi, stok 2 → 1", not _board._powerups.is_armed()
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == 1)
	await _touch(at, false)
	_c("BIRAKIŞ bekleyen parçayı DÜŞÜRMEDİ (drop 0, bekleyen tier aynı, nişan aynı)", _drops == 0
		and _board._pending_tier == pending_before and is_equal_approx(_board._aim_x, aim_before))
	await _wait(BombTiming.SETTLE)
	_c("hedef kaldırıldı, diğer parça duruyor (etki aynen)", not is_instance_valid(target)
		and is_instance_valid(other) and _tiers() == [4])
	_c("stok bir kez düştü (1), skor 0, merge 0", SaveManager.powerup_count(PowerUp.Type.BOMB) == 1
		and GameState.score == 0 and GameState.merge_count == 0)
	await _tap(_empty_point())
	_c("sonraki bağımsız dokunuş normal düşürdü (drop 1)", _drops == 1)
	_sections_done += 1


# --- 2) Büyütücü, parmak ----------------------------------------------------------------------

func _upgrade_finger() -> void:
	print("-- Büyütücü: parmak dokunuşu")
	await _make_board(8, 2)
	var cx: float = _board._center_x()
	var target: Dumpling = _spawn(3, Vector2(cx, _board.FLOOR_Y - 38.0))
	await _frames(50)
	var pos: Vector2 = target.global_position
	var pending_before: int = _board._pending_tier
	_arm(PowerUp.Type.UPGRADE)
	var at: Vector2 = _win(pos)
	await _touch(at, true)
	_c("basış: stok 2 → 1, hedef kilitli (anticipation)", SaveManager.powerup_count(PowerUp.Type.UPGRADE) == 1
		and is_instance_valid(target) and target.is_merging)
	await _touch(at, false)
	_c("BIRAKIŞ parçayı düşürmedi (anticipation penceresinde)", _drops == 0 and _board._pending_tier == pending_before)
	await _wait(0.3)
	await _frames(2)
	_c("tek T4 doğdu, hedefin yerinde (etki aynen)", _tiers() == [4] and _pieces()[0].global_position.distance_to(pos) <= 30.0)
	_c("stok bir kez düştü, skor 0", SaveManager.powerup_count(PowerUp.Type.UPGRADE) == 1 and GameState.score == 0)
	await _tap(_empty_point())
	_c("sonraki bağımsız dokunuş düşürdü", _drops == 1)

	print("-- Büyütücü T7 → T8 (sonsuz mod): kutlama aynen, bırakış düşürmez")
	await _make_board(0, 1)
	var t7: Dumpling = _spawn(7, Vector2(_board._center_x(), _board.FLOOR_Y - 85.0))
	await _frames(60)
	var tier_max_before: int = int(AudioManager.play_count.get(&"tier_max", 0))
	_arm(PowerUp.Type.UPGRADE)
	await _tap(_win(t7.global_position))
	_c("T7 hedefine tam dokunuş: drop 0", _drops == 0)
	await _wait(0.3)
	await _frames(2)
	_c("T8 doğdu, tier_max sesi bir kez, kral parıltısı var", _tiers() == [8]
		and int(AudioManager.play_count.get(&"tier_max", 0)) - tier_max_before == 1
		and _sprites_with(_board.SPARKLE_TEXTURE) >= 1)
	_c("stok 0, skor 0 (güç puan vermez)", SaveManager.powerup_count(PowerUp.Type.UPGRADE) == 0 and GameState.score == 0)
	_sections_done += 1


# --- 3) Kenar durumları ------------------------------------------------------------------------

func _edge_cases() -> void:
	print("-- geçersiz hedef: T8'e Büyütücü")
	await _make_board(0, 2)
	var t8: Dumpling = _spawn(8, Vector2(_board._center_x(), _board.FLOOR_Y - 95.0))
	await _frames(60)
	_arm(PowerUp.Type.UPGRADE)
	await _tap(_win(t8.global_position))
	_c("geçersiz hedef: stok aynı (2), hedefleme AÇIK kaldı, drop 0", SaveManager.powerup_count(PowerUp.Type.UPGRADE) == 2
		and _board._powerups.is_armed() and _drops == 0)
	_board._powerups.cancel()

	print("-- boşluğa dokunarak iptal")
	await _make_board(8, 2)
	_spawn(3, Vector2(_board._center_x(), _board.FLOOR_Y - 38.0))
	await _frames(40)
	_arm(PowerUp.Type.BOMB)
	await _tap(_empty_point())
	_c("boşluğa dokunuş iptal etti: silah indi, stok aynı (2), bırakış DÜŞÜRMEDİ", not _board._powerups.is_armed()
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == 2 and _drops == 0)
	await _tap(_empty_point())
	_c("iptalden sonraki dokunuş normal düşürdü", _drops == 1)

	print("-- güç butonuyla iptal (toggle)")
	await _make_board(8, 2)
	await _frames(5)
	_arm(PowerUp.Type.BOMB)
	_arm(PowerUp.Type.BOMB)
	_c("aynı butona ikinci basış iptal etti, stok aynı", not _board._powerups.is_armed()
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == 2)
	await _tap(_empty_point())
	_c("butonla iptal sonrası dokunuş normal düşürdü (tüketilmiş dizi yok)", _drops == 1)

	print("-- sürükle, sonra bırak")
	await _make_board(8, 2)
	var target: Dumpling = _spawn(3, Vector2(_board._center_x(), _board.FLOOR_Y - 38.0))
	await _frames(40)
	var aim_before: float = _board._aim_x
	_arm(PowerUp.Type.BOMB)
	var at: Vector2 = _win(target.global_position)
	await _touch(at, true)
	await _drag(at + Vector2(-160.0, -40.0))
	await _drag(at + Vector2(-240.0, -90.0))
	await _touch(at + Vector2(-240.0, -90.0), false)
	_c("sürükleme nişanı KAYDIRMADI, bırakış düşürmedi, güç bir kez", is_equal_approx(_board._aim_x, aim_before)
		and _drops == 0 and SaveManager.powerup_count(PowerUp.Type.BOMB) == 1)
	await _tap(_empty_point(-1))
	_c("sonraki dokunuş normal", _drops == 1)

	print("-- hızlı dokunuşlar: hedef + hemen ikinci dokunuş")
	await _make_board(8, 2)
	target = _spawn(3, Vector2(_board._center_x(), _board.FLOOR_Y - 38.0))
	await _frames(40)
	_arm(PowerUp.Type.BOMB)
	at = _win(target.global_position)
	await _touch(at, true)
	await _touch(at, false)
	await _touch(at, true)
	await _touch(at, false)
	_c("ikinci hızlı dokunuş bağımsız: tam bir drop, İKİNCİ güç işlemi YOK (stok 1)", _drops == 1
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == 1 and not _board._powerups.is_armed())
	await _wait(BombTiming.SETTLE)
	_c("hedef bir kez kaldırıldı", not is_instance_valid(target))

	print("-- aynı karede basış + bırakış (tek dağıtım, hızlı parmak)")
	await _make_board(8, 2)
	target = _spawn(3, Vector2(_board._center_x(), _board.FLOOR_Y - 38.0))
	await _frames(40)
	_arm(PowerUp.Type.UPGRADE)
	at = _win(target.global_position)
	Input.parse_input_event(_touch_event(at, true, 0))
	Input.parse_input_event(_touch_event(at, false, 0))
	Input.flush_buffered_events()
	await get_tree().process_frame
	_c("tek dağıtımda basış + bırakış: güç bir kez (stok 1), drop 0", SaveManager.powerup_count(PowerUp.Type.UPGRADE) == 1
		and _drops == 0 and _board._targeting_touches.is_empty())
	await _wait(0.3)
	await _tap(_empty_point())
	_c("ardından dokunuş normal düşürdü", _drops == 1)

	print("-- iki parmak: hedefleme parmağı tüketilir, diğer parmak bağımsız")
	await _make_board(8, 2)
	target = _spawn(3, Vector2(_board._center_x(), _board.FLOOR_Y - 38.0))
	await _frames(40)
	_arm(PowerUp.Type.BOMB)
	at = _win(target.global_position)
	await _touch(at, true, 0)
	await _touch(_empty_point(), true, 1)
	await _touch(_empty_point(), false, 1)
	_c("ikinci parmak normal düşürdü (1)", _drops == 1)
	await _touch(at, false, 0)
	_c("hedefleme parmağının bırakışı yine düşürmedi (hâlâ 1), güç bir kez", _drops == 1
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == 1)

	print("-- kaybolan bırakış: bastırma takılı kalmaz")
	await _make_board(8, 2)
	target = _spawn(3, Vector2(_board._center_x(), _board.FLOOR_Y - 38.0))
	await _frames(40)
	_arm(PowerUp.Type.BOMB)
	await _touch(_win(target.global_position), true)
	await _tap(_empty_point())
	_c("aynı parmağın YENİ basışı diziyi kapattı: normal düşürdü (1)", _drops == 1
		and _board._targeting_touches.is_empty())

	print("-- duraklamada gelen bırakış")
	await _make_board(8, 2)
	target = _spawn(3, Vector2(_board._center_x(), _board.FLOOR_Y - 38.0))
	await _frames(40)
	_arm(PowerUp.Type.BOMB)
	at = _win(target.global_position)
	await _touch(at, true)
	_board.set_menu_paused(true)
	await _touch(at, false)
	_c("duraklamadaki bırakış diziyi kapattı, düşürmedi", _drops == 0 and _board._targeting_touches.is_empty())
	_board.set_menu_paused(false)
	await _frames(2)
	await _tap(_empty_point())
	_c("devam edince ilk dokunuş normal düşürdü", _drops == 1)

	print("-- stok 0: hedefleme açılmaz, refill istenir, dokunuş normal")
	await _make_board(8, 0)
	_refills.clear()
	_arm(PowerUp.Type.BOMB)
	_c("stok 0: silahlanmadı, refill teklifi (Bomba) yayıldı", not _board._powerups.is_armed()
		and _refills == [int(PowerUp.Type.BOMB)] and _board.is_refill_pending())
	_board.exit_refill_pending(false)
	await _frames(2)
	await _tap(_empty_point())
	_c("refill kapandıktan sonra dokunuş normal düşürdü", _drops == 1)
	_sections_done += 1


# --- 4) Masaüstü fare + kod yolları -------------------------------------------------------------

func _mouse_and_code_paths() -> void:
	print("-- masaüstü fare (dokunuş fareden öykünür, device -1)")
	await _make_board(8, 2)
	var target: Dumpling = _spawn(3, Vector2(_board._center_x(), _board.FLOOR_Y - 38.0))
	await _frames(40)
	_arm(PowerUp.Type.BOMB)
	var at: Vector2 = _win(target.global_position)
	await _mouse(at, true)
	_c("fare basışı gücü çözdü (stok 1)", SaveManager.powerup_count(PowerUp.Type.BOMB) == 1
		and not _board._powerups.is_armed())
	await _mouse(at, false)
	_c("fare bırakışı düşürmedi", _drops == 0)
	await _mouse(_empty_point(), true)
	await _mouse(_empty_point(), false)
	_c("sonraki fare tıklaması normal düşürdü", _drops == 1)

	print("-- kod yolu: doğrudan _unhandled_input (viewport koordinatı)")
	await _make_board(8, 2)
	target = _spawn(3, Vector2(_board._center_x(), _board.FLOOR_Y - 38.0))
	await _frames(40)
	_arm(PowerUp.Type.UPGRADE)
	var vp: Vector2 = _board.world_to_screen(target.global_position)
	_board._unhandled_input(_touch_event(vp, true, 0))
	_board._unhandled_input(_touch_event(vp, false, 0))
	_c("kod yolu: güç bir kez, bırakış düşürmedi", SaveManager.powerup_count(PowerUp.Type.UPGRADE) == 1 and _drops == 0)
	var empty_vp: Vector2 = _board.world_to_screen(Vector2(_board._center_x() - 200.0, _board.overflow_line_y() + 40.0))
	_board._unhandled_input(_touch_event(empty_vp, true, 0))
	_board._unhandled_input(_touch_event(empty_vp, false, 0))
	_c("kod yolu: sonraki dokunuş düşürdü", _drops == 1)

	print("-- mevcut `_use_targeted_power` kod yolu (araçlar / testler) aynen")
	await _make_board(8, 2)
	target = _spawn(3, Vector2(_board._center_x(), _board.FLOOR_Y - 38.0))
	await _frames(40)
	_arm(PowerUp.Type.BOMB)
	_board._use_targeted_power(target)
	_c("doğrudan çağrı: stok 1, silah indi, tüketilmiş dokunuş kaydı YOK", SaveManager.powerup_count(PowerUp.Type.BOMB) == 1
		and not _board._powerups.is_armed() and _board._targeting_touches.is_empty())
	await _tap(_empty_point())
	_c("ardından ilk dokunuş normal düşürdü", _drops == 1)
	_sections_done += 1


# --- 5) Anında güçler ---------------------------------------------------------------------------

func _instant_powers() -> void:
	print("-- Sarsıntı / Temizleyici: davranış aynen, sonraki dokunuş normal")
	await _make_board(8, 2)
	var cx: float = _board._center_x()
	_spawn(1, Vector2(cx - 120.0, _board.FLOOR_Y - 20.0))
	_spawn(2, Vector2(cx + 120.0, _board.FLOOR_Y - 26.0))
	_spawn(5, Vector2(cx, _board.FLOOR_Y - 55.0))
	await _frames(50)
	_c("ön koşul: board T1, T2, T5", _tiers() == [1, 2, 5])
	_arm(PowerUp.Type.CLEAR_SMALL)
	# Kaldırma kademeli (CLEAR_STAGGER / parça) — tüm pop'lar bitsin.
	await _wait(0.35)
	_c("Temizleyici: silahlanmaz, stok 2 → 1, T1/T2 kaldırıldı, T5 kaldı", not _board._powerups.is_armed()
		and SaveManager.powerup_count(PowerUp.Type.CLEAR_SMALL) == 1 and _tiers() == [5])
	await _tap(_empty_point())
	_c("Temizleyici sonrası dokunuş normal düşürdü", _drops == 1)
	await _make_board(8, 2)
	_spawn(5, Vector2(_board._center_x(), _board.FLOOR_Y - 55.0))
	await _frames(40)
	_arm(PowerUp.Type.SHAKE)
	_c("Sarsıntı: silahlanmaz, anında çalıştı, stok 2 → 1, koruma 1.2 s", not _board._powerups.is_armed()
		and SaveManager.powerup_count(PowerUp.Type.SHAKE) == 1 and _board._shake_protection > 0.6)
	await _tap(_empty_point())
	_c("Sarsıntı sonrası dokunuş normal düşürdü", _drops == 1)
	await _make_board(8, 2)
	_spawn(5, Vector2(_board._center_x(), _board.FLOOR_Y - 55.0))
	await _frames(40)
	_arm(PowerUp.Type.CLEAR_SMALL)
	_c("Temizleyici T1/T2 yokken tüketilmez (stok 2)", SaveManager.powerup_count(PowerUp.Type.CLEAR_SMALL) == 2)
	await _make_board(8, 2)
	_arm(PowerUp.Type.SHAKE)
	_c("Sarsıntı boş board'da tüketilmez (stok 2)", SaveManager.powerup_count(PowerUp.Type.SHAKE) == 2)
	_sections_done += 1


# --- 6) Main: gerçek sahne + 300 ms parmak yatışması ------------------------------------------------

func _main_integration() -> void:
	print("-- Main: gerçek sahne, hedef dokunuşu + parmak yatışması aynen")
	await _free_board()
	SaveManager.data = DailyRewardsFixture.data()
	SaveManager.data["powerups"] = {"bomb": 3, "upgrade": 3, "shake": 1, "clear_small": 1}
	SaveManager.save_game()
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _frames(3)
	await _wait(0.4)
	_main._start_level(load("res://resources/levels/level_08.tres"))
	await _frames(3)
	_board = _main._board
	_board.dumpling_dropped.connect(func(_tier: int) -> void: _drops += 1)
	_drops = 0
	await _wait(0.4)
	var target: Dumpling = _spawn(3, Vector2(_board._center_x(), _board.FLOOR_Y - 38.0))
	await _frames(40)
	_arm(PowerUp.Type.BOMB)
	var at: Vector2 = _win(target.global_position)
	await _touch(at, true)
	await _touch(at, false)
	_c("Main içinde: parmakla Bomba bir kez (stok 3 → 2), bırakış düşürmedi", SaveManager.powerup_count(PowerUp.Type.BOMB) == 2
		and _drops == 0)
	await _wait(BombTiming.SETTLE)
	await _tap(_empty_point())
	_c("Main içinde: sonraki dokunuş normal düşürdü", _drops == 1)

	_arm(PowerUp.Type.BOMB)
	var second: Dumpling = _spawn(2, Vector2(_board._center_x() + 140.0, _board.FLOOR_Y - 30.0))
	await _frames(40)
	_main.settle_touch_input()
	await _tap(_win(second.global_position))
	_c("yatışma penceresinde parmak dokunuşu Main'de yutuldu: güç YOK, drop YOK, hedefleme açık", _drops == 1
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == 2 and _board._powerups.is_armed())
	await _wait(0.42)
	await _tap(_win(second.global_position))
	_c("yatışmadan sonra aynı dokunuş gücü uyguladı, bırakış düşürmedi", SaveManager.powerup_count(PowerUp.Type.BOMB) == 1
		and _drops == 1)
	_main.queue_free()
	_main = null
	_board = null
	await _frames(3)
	_sections_done += 1


# --- 7) Kaynak sözleşmesi ------------------------------------------------------------------------

func _source_contract() -> void:
	print("-- kaynak")
	var board: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/game/game_board.gd"))
	var input_fn: String = _function(board, "func _unhandled_input(")
	_c("_unhandled_input önce tüketilmiş diziyi eler (duraklatma kapısından da önce)",
		input_fn.find("_consume_targeting_touch(event)") != -1
		and input_fn.find("_consume_targeting_touch(event)") < input_fn.find("_is_finished or _is_paused()"))
	var targeting_fn: String = _function(board, "func _handle_targeting_input(")
	_c("hedefleme basışı dokunuşu kaydeder (dizinin sahibi hedefleme)", targeting_fn.contains("_targeting_touches[touch.index] = true"))
	var consume_fn: String = _function(board, "func _consume_targeting_touch(")
	_c("tüketim zamanlayıcısız (durum tabanlı: süre / tick / timer yok)", not consume_fn.is_empty()
		and not consume_fn.contains("msec") and not consume_fn.contains("timer") and not consume_fn.contains("delta"))
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_c("Main parmak yatışması aynen: TOUCH_SETTLE_MSEC 300, yalnız parmak basışı", main_src.contains("const TOUCH_SETTLE_MSEC: int = 300")
		and main_src.contains("event.device != InputEvent.DEVICE_ID_EMULATION"))
	_sections_done += 1


# --- Yardımcılar ----------------------------------------------------------------------------------

class BombTiming:
	## Bomba mermisi 0.28 s uçar; kaldırma + kare payı.
	const SETTLE: float = 0.45


class DailyRewardsFixture:
	static func data() -> Dictionary:
		var d: Dictionary = SaveManager.DEFAULT_DATA.duplicate(true)
		d["onboarding_completed"] = true
		d["age_ad_band"] = "ADULT"
		d["powerup_starter_granted"] = true
		d["last_login_date"] = Time.get_date_string_from_system()
		d["highest_level_unlocked"] = 9
		return d


func _make_board(level: int, stock: int) -> void:
	await _free_board()
	GameState.reset_run()
	var stocks: Dictionary = {}
	for type in PowerUp.all():
		stocks[PowerUp.save_key(type)] = stock
	SaveManager.data["powerups"] = stocks
	var path: String = "res://resources/levels/endless.tres" if level == 0 \
		else "res://resources/levels/level_%02d.tres" % level
	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(load(path))
	_board.dumpling_dropped.connect(func(_tier: int) -> void: _drops += 1)
	_board.power_refill_offered.connect(func(type: int) -> void: _refills.append(type))
	add_child(_board)
	_drops = 0
	await get_tree().process_frame
	await get_tree().process_frame


func _free_board() -> void:
	if _board != null and is_instance_valid(_board) and _main == null:
		_board.queue_free()
		_board = null
		await get_tree().process_frame
		await get_tree().process_frame


## Güç butonu (PowerBar sinyali — GameBoard'un gerçek bağlantısı).
func _arm(type: PowerUp.Type) -> void:
	_board._power_bar.power_pressed.emit(int(type))


func _spawn(tier: int, at: Vector2) -> Dumpling:
	return _board._spawn_dumpling(tier, at)


## Dünya noktası → Input.parse_input_event'in beklediği PENCERE pikseli.
func _win(world: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * _board.world_to_screen(world)


## Kabın içinde, parçalardan uzak boş bir nokta (pencere pikseli).
func _empty_point(side: int = 1) -> Vector2:
	return _win(Vector2(_board._center_x() + side * 200.0, _board.overflow_line_y() + 40.0))


func _touch_event(pos: Vector2, pressed: bool, index: int) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = pos
	touch.pressed = pressed
	return touch


## Olay Input'a verilir ve HEMEN dağıtılır: `parse_input_event` tamponlar; bir fizik
## karesinden sonra gelen `process_frame` aynı turdadır (dağıtım henüz yok) — sıra
## deterministik olsun diye tampon burada boşaltılır.
func _touch(pos: Vector2, pressed: bool, index: int = 0) -> void:
	Input.parse_input_event(_touch_event(pos, pressed, index))
	Input.flush_buffered_events()
	await get_tree().process_frame


func _tap(pos: Vector2) -> void:
	await _touch(pos, true)
	await _touch(pos, false)


func _drag(pos: Vector2, index: int = 0) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.position = pos
	drag.relative = Vector2(-80.0, -20.0)
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _mouse(pos: Vector2, pressed: bool) -> void:
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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


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


func _sprites_with(texture: Texture2D) -> int:
	var count: int = 0
	var stack: Array[Node] = [_board]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Sprite2D and (node as Sprite2D).texture == texture:
			count += 1
		stack.append_array(node.get_children())
	return count


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


func _strip_comments(code: String) -> String:
	var out: PackedStringArray = []
	for line in code.split("\n"):
		var hash: int = line.find("#")
		out.append(line if hash < 0 else line.substr(0, hash))
	return "\n".join(out)
