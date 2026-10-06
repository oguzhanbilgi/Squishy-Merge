extends Node
## TASK/045.2 — Ayarlar kapanışı sonrası girdi odağı testi. Headless.
## Hata (A36, 3/3): oyun içi dişli → Ayarlar → Android GERİ ile kapat → 300 ms yatışmadan
## sonra İLK tahta dokunuşunun bırakışı kayboluyordu (parça düşmüyor, ikinci dokunuş
## normal); KAPAT / karartma ile kapatınca yoktu. Kök neden: dişlinin öykünen fare bırakışı
## Ayarlar'ı açıp yatışmayı başlatıyor, AYNI dokunuşun ScreenTouch bırakışı yutuluyordu —
## Viewport'un parmak odağı (`touch_focus[0]`) dişlide kalıyor, dokunuşsuz geri kapanışından
## sonra ilk tahta dokunuşunun sürüklemesi + bırakışı dişliye gidiyordu. KAPAT / karartma
## dokunuşu odağı yeni bir basışla eziyordu. Sözleşme: yatışma DİZİ bazında — pencerede
## başlayan dizi (basış + sürükleme + bırakış) tamamen yutulur, pencereden önce başlamış
## dizi bölünmez; 300 ms aynen.
## SAHİBİN KAYDINA DOKUNMAZ: SaveManager `user://qa_settings_input/` altına yönlendirilir.
##
##   godot --headless --audio-driver Dummy --path . res://tools/settings_input_test.tscn
##
## Olay sırası cihazdaki gibi: parmak = ScreenTouch / ScreenDrag (device 0)
## `Input.parse_input_event` ile; Godot fareyi dokunuştan öykünür (device -1) ve öykünen
## fare olayını ScreenTouch'tan ÖNCE dağıtır (dişlinin `pressed`'i öykünen bırakışta).
## Android geri = pencerenin bildirim yayılımı (NOTIFICATION_WM_GO_BACK_REQUEST).
##
## Bölümler:
##   oyun içi Ayarlar   dişli → GERİ / KAPAT / karartma: tek kapanış, dişli kendi bırakışını
##                      alır, yatışma biter, İLK bağımsız dokunuş: bas (nişan) → sürükle
##                      (nişan izler) → bırak (tam bir drop); hızlı ikinci dokunuş cooldown'a
##                      takılır, sonra düşer; güç yok, bastırma takılı değil
##   girdi çeşitleri    başka parmak (indeks 1), indeks yeniden kullanımı, masaüstü fare,
##                      yatışma içinde GERİ + pencerede başlayan tahta dizisi (tamamı yutulur,
##                      pencere bittikten sonraki bırakışı da), çift dokunuş koruması
##   hedefli güçler     Bomba / Büyütücü silahlıyken Ayarlar → GERİ: ilk dokunuş hedef, bırakış
##                      tüketilir (drop yok), sonraki bağımsız dokunuş düşürür
##   Profil Ayarlar     Profil dişlisi → GERİ / KAPAT / karartma → ilk dokunuş (kabuk ANA SAYFA; TASK/057
##                      Tur 2: üst çubukta geri oku yok) çalışır;
##                      çift dokunuş koruması
##   pencereler         Mola / Refill / Devam (oyun), Koleksiyon detayı / Başarımlar / Unvanlar
##                      / Günlük / Sandık (kabuk): aç → GERİ (ya da buton) → ilk dokunuş çalışır
##   kaynak             300 ms aynen, dizi tabanlı (yeni zamanlayıcı yok)

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const LEVEL_PATH: String = "res://resources/levels/level_08.tres"
const DIR: String = "user://qa_settings_input"
const PATH: String = DIR + "/save.json"
const SECTIONS: int = 7
## Bomba mermisi 0.28 s uçar; kaldırma + kare payı (power_input_test ile aynı).
const BOMB_SETTLE: float = 0.45
## Main'in geri tuşu debounce'u (250 ms) — art arda iki geri arasında bekle.
const BACK_GAP_MSEC: int = 280

var _main: Node2D
var _board: Node2D
var _drops: int = 0
var _drop_aims: Array[float] = []
var _drop_tiers: Array[int] = []
var _closes: int = 0
## İzlenen kontrolün (dişli) gui_input'una ulaşan PARMAK olayları (device ≠ -1).
var _watched: Array[String] = []
var _watching: Dictionary = {}
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
	SaveManager.data = _fixture()
	SaveManager.save_game()
	get_tree().create_timer(300.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 300 s'de bitmedi")
			# Main hâlâ çalışıyor: kayıt yolu gerçek dosyaya DÖNDÜRÜLMEZ (yol, Main ağaçtan
			# çıktıktan sonra _exit_tree'de döner).
			_teardown(false)
			get_tree().quit(2))
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_main._settings.closed.connect(func() -> void: _closes += 1)
	await _frames(3)
	await _wait(0.4)

	await _gameplay_close_paths()
	await _input_variants()
	await _targeted_powers()
	await _profile_settings()
	await _gameplay_modals()
	await _shell_modals()
	_source_contract()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	_main.queue_free()
	_main = null
	await _frames(3)
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


# --- 1) Oyun içi Ayarlar: GERİ / KAPAT / karartma ---------------------------------------------

func _gameplay_close_paths() -> void:
	for mode: StringName in [&"back", &"kapat", &"dim"]:
		print("-- oyun içi dişli → Ayarlar → %s → ilk tahta dokunuşu" % _mode_name(mode))
		await _start_round()
		var closes_before: int = _closes
		await _gear_tap()
		_c("%s: dişli (parmak) → Ayarlar açık, board donuk" % _mode_name(mode), _main._settings.visible
			and _board._is_menu_paused)
		_c("%s: dişli kendi ScreenTouch bırakışını aldı (Viewport parmak odağı kapandı)" % _mode_name(mode),
			_watched.count("release 0") == 1)
		await _wait_settled()
		await _close_settings(mode)
		_c("%s: Ayarlar TAM BİR kez kapandı, board çözüldü" % _mode_name(mode), not _main._settings.visible
			and _closes == closes_before + 1 and not _board._is_menu_paused)
		await _wait_settled()
		_c("%s: ön koşul — yatışma bitti, bastırılan dizi yok" % _mode_name(mode),
			Time.get_ticks_msec() >= _main._touch_settle_until and _no_settled())
		await _first_touch_drops(_mode_name(mode))
		await _rapid_second_touch(_mode_name(mode))
	_sections_done += 1


## Kapanıştan sonraki İLK bağımsız parmak dizisi (indeks 0 — dişlinin indeksi): bas → kısa
## sürükle → bırak. Nişan basışta ve sürüklemede izler, bırakış TAM BİR parça düşürür.
func _first_touch_drops(label: String, index: int = 0) -> void:
	var p: Vector2 = _board_point(120.0)
	var q: Vector2 = _board_point(-120.0)
	var pending: int = _board._pending_tier
	var stocks: Dictionary = _stocks()
	var watched_before: int = _watched.size()
	_drops = 0
	_drop_aims.clear()
	_drop_tiers.clear()
	_c("%s: ön koşul — drop cooldown bitti (düşmeme hatası cooldown'dan olamaz)" % label,
		_board._drop_cooldown == 0.0 and not _board._is_paused())
	await _finger(p, true, index)
	var aim_press: float = _board._aim_x
	await _finger_drag(q, p, index)
	var aim_drag: float = _board._aim_x
	await _finger(q, false, index)
	_c("%s: ilk dokunuşun basışı nişanı taşıdı" % label, _near(aim_press, _world_x(p)))
	_c("%s: sürükleme tahtaya ulaştı, nişan izledi" % label, _near(aim_drag, _world_x(q)))
	_c("%s: İLK bırakış tam bir parça düşürdü (ikinci dokunuş gerekmedi), sürüklenen noktada, bekleyen tier" % label,
		_drops == 1 and _near(_drop_aims[0], _world_x(q)) and _drop_tiers[0] == pending)
	_c("%s: dişli ilk dokunuşun hiçbir olayını ALMADI" % label, _watched.size() == watched_before)
	_c("%s: güç kullanılmadı / silahlanmadı, bastırılan dizi yok" % label, _stocks() == stocks
		and not _board._powerups.is_armed() and _no_settled())


## Hızlı ikinci bağımsız dokunuş: drop cooldown'u (0.4 s, oyun kuralı — DEĞİŞMEDİ) içinde
## ikinci parça yok (çift drop yok); cooldown biter bitmez sonraki dokunuş düşürür.
func _rapid_second_touch(label: String) -> void:
	var rapid: Vector2 = _board_point(40.0)
	await _finger_tap(rapid)
	_c("%s: hızlı ikinci dokunuş tahtaya ulaştı (nişan taşındı) ama cooldown içinde çift drop üretmedi" % label,
		_drops == 1 and _near(_board._aim_x, _world_x(rapid)) and _board._drop_cooldown > 0.0)
	await _wait(_board.DROP_COOLDOWN + 0.12)
	await _finger_tap(_board_point(40.0))
	_c("%s: cooldown'dan sonra bağımsız dokunuş hemen düşürdü" % label, _drops == 2
		and _no_settled())


# --- 2) Girdi çeşitleri ---------------------------------------------------------------------

func _input_variants() -> void:
	print("-- başka parmak / indeks yeniden kullanımı / masaüstü fare")
	await _start_round()
	await _gear_tap()
	await _wait_settled()
	await _back()
	await _wait_settled()
	await _first_touch_drops("GERİ sonrası parmak 1", 1)
	await _wait(_board.DROP_COOLDOWN + 0.12)
	await _first_touch_drops("ardından parmak 0 (indeks yeniden kullanımı)", 0)

	await _start_round()
	var gear: Button = _board._hud.settings_button
	await _mouse_click(_center(gear))
	_c("masaüstü fare: dişli → Ayarlar", _main._settings.visible)
	await _wait_settled()
	await _back()
	await _wait_settled()
	_drops = 0
	var p: Vector2 = _board_point(-90.0)
	await _mouse_click(p)
	_c("masaüstü fare: GERİ sonrası ilk tıklama düşürdü (fareden öykünen dokunuş)", _drops == 1
		and _near(_drop_aims[0], _world_x(p)))

	print("-- yatışma içinde GERİ: pencerede başlayan tahta dizisi tamamen yutulur")
	await _start_round()
	await _gear_tap()
	await _back()
	_c("ön koşul: hızlı GERİ Ayarlar'ı kapattı, yatışma penceresi hâlâ açık", not _main._settings.visible
		and not _board._is_menu_paused and Time.get_ticks_msec() + 120 < _main._touch_settle_until)
	var aim: float = _board._aim_x
	# Dişli kendi dokunuşunu (basış + bırakış) aldı; bundan sonra ona hiçbir şey gitmemeli —
	# yutan Main olmalı, asılı bir GUI odağı değil.
	var gear_seen: int = _watched.size()
	_drops = 0
	var a: Vector2 = _board_point(130.0)
	var b: Vector2 = _board_point(-130.0)
	await _finger(a, true)
	_c("pencerede başlayan basış yutuldu (nişan aynı)", _near(_board._aim_x, aim) and _settled_has(0))
	await _finger_drag(b, a)
	_c("aynı dizinin sürüklemesi Main'de yutuldu (nişan aynı, dişliye de gitmedi)", _near(_board._aim_x, aim)
		and _watched.size() == gear_seen)
	await _wait_until_msec(_main._touch_settle_until + 80)
	await _finger_drag(a, b)
	await _finger(a, false)
	_c("pencere BİTTİKTEN sonra gelen sürükleme / bırakış da Main'de yutuldu: drop yok, nişan aynı, dişliye gitmedi",
		_drops == 0 and _near(_board._aim_x, aim) and _watched.size() == gear_seen)
	_c("dizi bırakışla kapandı (takılı bastırma yok)", _no_settled())
	await _finger_tap(a)
	_c("sonraki bağımsız dokunuş hemen düşürdü", _drops == 1)

	print("-- kaybolan bırakış: aynı parmağın yeni basışı yutulan diziyi kapatır")
	await _start_round()
	await _gear_tap()
	await _back()
	_drops = 0
	await _finger(_board_point(100.0), true)
	_c("ön koşul: pencerede basış yutuldu", _settled_has(0))
	await _wait_settled()
	await _finger_tap(_board_point(-100.0))
	_c("bırakışı hiç gelmeyen dizi yeni basışla kapandı, yeni dokunuş düşürdü", _drops == 1
		and _no_settled())

	print("-- iptal edilen bırakış (Android ACTION_CANCEL) yutulan diziyi kapatır")
	await _start_round()
	await _gear_tap()
	await _back()
	_drops = 0
	var cancel_at: Vector2 = _board_point(90.0)
	await _finger(cancel_at, true)
	_c("ön koşul: pencerede basış yutuldu", _settled_has(0))
	var canceled := _touch_event(cancel_at, false, 0)
	canceled.canceled = true
	Input.parse_input_event(canceled)
	Input.flush_buffered_events()
	await get_tree().process_frame
	_c("iptal edilen bırakış da yutuldu ve diziyi kapattı: drop yok, bastırma yok", _drops == 0 and _no_settled())
	await _wait_settled()
	await _finger_tap(_board_point(-90.0))
	_c("iptalden sonra bağımsız dokunuş hemen düşürdü", _drops == 1)

	print("-- iki parmak: pencereden önce basan parmak 0 bölünmez, pencerede basan parmak 1 tamamen yutulur")
	await _start_round()
	_drops = 0
	var p0: Vector2 = _board_point(120.0)
	var p1: Vector2 = _board_point(-60.0)
	var p1_end: Vector2 = _board_point(-140.0)
	await _finger(p0, true, 0)
	_main.settle_touch_input()
	await _finger(p1, true, 1)
	_c("pencerede basan parmak 1 yutuldu (nişan parmak 0'da), yalnız onun dizisi kayıtlı",
		_near(_board._aim_x, _world_x(p0)) and _settled_has(1) and not _settled_has(0))
	await _finger(p0, false, 0)
	_c("pencereden önce başlamış parmak 0 dizisi bölünmedi: bırakışı pencere içinde hemen düşürdü", _drops == 1
		and _near(_drop_aims[0], _world_x(p0)))
	await _wait_settled()
	await _finger_drag(p1_end, p1, 1)
	await _finger(p1_end, false, 1)
	_c("parmak 1'in pencere sonrası sürüklemesi / bırakışı da yutuldu (drop yok, nişan aynı), kayıt kapandı",
		_drops == 1 and _near(_board._aim_x, _world_x(p0)) and _no_settled())

	print("-- pencereden ÖNCE başlamış tahta dizisi bölünmez (ikinci parmak)")
	await _start_round()
	var gear_at: Vector2 = _center(_board._hud.settings_button)
	var c: Vector2 = _board_point(-110.0)
	_drops = 0
	await _finger(gear_at, true, 0)
	await _finger(c, true, 1)
	_c("ön koşul: parmak 1 pencereden önce tahtaya bastı (nişan)", _near(_board._aim_x, _world_x(c)))
	await _finger(gear_at, false, 0)
	_c("parmak 0 dişliden kalktı → Ayarlar, board donuk", _main._settings.visible and _board._is_menu_paused)
	await _back()
	_c("ön koşul: hızlı GERİ kapattı, pencere hâlâ açık", not _main._settings.visible
		and Time.get_ticks_msec() + 80 < _main._touch_settle_until)
	await _finger(c, false, 1)
	_c("parmak 1'in pencere içindeki bırakışı KENDİ dizisini tamamladı: tam bir drop, nişanda", _drops == 1
		and _near(_drop_aims[0], _world_x(c)) and _no_settled())

	print("-- TASK/044 çift dokunuş koruması: dişli → hemen ikinci dokunuş karartmaya")
	await _start_round()
	var gear_pos: Vector2 = _center(_board._hud.settings_button)
	var closes_before: int = _closes
	await _gear_tap()
	_c("ön koşul: dişli noktası Ayarlar çerçevesinin DIŞINDA (ikinci dokunuş karartmaya düşer)",
		not _main._settings.frame().get_global_rect().has_point(_canvas(gear_pos)))
	await _finger_tap(gear_pos)
	_c("hemen ikinci dokunuş yutuldu: Ayarlar açık, kapanış yok", _main._settings.visible
		and _closes == closes_before and _no_settled())
	await _wait_settled()
	await _finger_tap(gear_pos)
	_c("yatışmadan sonra karartma dokunuşu kapatır (UiKit sözleşmesi aynen)", not _main._settings.visible
		and _closes == closes_before + 1)
	await _wait_settled()
	await _first_touch_drops("çift dokunuş sonrası")
	_sections_done += 1


# --- 3) Hedefli güçler (TASK/045.1 aynen) -----------------------------------------------------

func _targeted_powers() -> void:
	for type: PowerUp.Type in [PowerUp.Type.BOMB, PowerUp.Type.UPGRADE]:
		var label: String = PowerUp.display_name(type)
		print("-- %s silahlı → Ayarlar → GERİ → ilk dokunuş hedef" % label)
		await _start_round()
		var target: Dumpling = _board._spawn_dumpling(3, Vector2(_board._center_x(), _board.FLOOR_Y - 38.0))
		await _frames(50)
		var target_pos: Vector2 = target.global_position
		var stock_before: int = SaveManager.powerup_count(type)
		await _finger_tap(_center(_board._power_bar.slot(int(type))))
		_c("%s: güç yuvasına parmak → silahlandı, stok aynı (%d)" % [label, stock_before],
			_board._powerups.armed_type() == int(type) and SaveManager.powerup_count(type) == stock_before)
		await _gear_tap()
		await _wait_settled()
		await _back()
		await _wait_settled()
		_c("%s: GERİ kapanışından sonra hâlâ silahlı" % label, _board._powerups.armed_type() == int(type))
		_drops = 0
		var pending: int = _board._pending_tier
		var aim: float = _board._aim_x
		var at: Vector2 = _win_world(target.global_position)
		await _finger(at, true)
		_c("%s: ilk dokunuş hedefe → güç bir kez, silah indi, stok %d → %d" % [label, stock_before, stock_before - 1],
			not _board._powerups.is_armed() and SaveManager.powerup_count(type) == stock_before - 1)
		await _finger(at, false)
		_c("%s: bırakış tahtaya ulaştı ve TÜKETİLDİ (drop yok, bekleyen tier / nişan aynı, dizi kapandı)" % label,
			_drops == 0 and _board._pending_tier == pending and _near(_board._aim_x, aim)
			and _board._targeting_touches.is_empty())
		if type == PowerUp.Type.BOMB:
			await _wait(BOMB_SETTLE)
			_c("Bomba: hedef kaldırıldı (etki aynen)", not is_instance_valid(target) and _tiers().is_empty())
		else:
			# Anticipation (0.15 s) + dönüşüm: hedefin yerinde tek T4 doğar (power_input_test ile aynı).
			await _wait(0.3)
			await _frames(2)
			var pieces: Array[Dumpling] = _pieces()
			_c("Büyütücü: hedefin yerinde tek T4 doğdu (etki aynen)", _tiers() == [4]
				and pieces[0].global_position.distance_to(target_pos) <= 30.0)
		await _finger_tap(_board_point(150.0))
		_c("%s: sonraki bağımsız dokunuş hemen düşürdü, güç stoğu tekrar düşmedi" % label, _drops == 1
			and SaveManager.powerup_count(type) == stock_before - 1)
	_sections_done += 1


# --- 4) Profil Ayarlar ------------------------------------------------------------------------

func _profile_settings() -> void:
	_leave_round()
	var profile: CanvasLayer = _main._screens[4]
	var home: CanvasLayer = _main._screens[0]
	for mode: StringName in [&"back", &"kapat", &"dim"]:
		print("-- Profil dişlisi → Ayarlar → %s → ilk dokunuş" % _mode_name(mode))
		_main._show_tab(4)
		await _wait_settled()
		_watch(profile.settings_button())
		var closes_before: int = _closes
		await _finger_tap(_center(profile.settings_button()))
		_c("Profil %s: dişli (parmak) → Ayarlar, Profil'de kalındı" % _mode_name(mode), _main._settings.visible
			and _main._active_tab == 4)
		_c("Profil %s: dişli kendi ScreenTouch bırakışını aldı" % _mode_name(mode), _watched.count("release 0") == 1)
		await _wait_settled()
		await _close_settings(mode)
		_c("Profil %s: Ayarlar tam bir kez kapandı, Profil görünür" % _mode_name(mode), not _main._settings.visible
			and _closes == closes_before + 1 and _main._active_tab == 4 and profile.visible)
		await _wait_settled()
		# TASK/057 Tur 2: Profil üst çubuğunda geri oku yok — ilk dokunuş kabuğun ANA SAYFA öğesine.
		var nav_before: int = _main.nav_navigations
		await _finger_tap(_center(_main.global_nav().item_button(0)))
		_c("Profil %s: ilk dokunuş (kabuk ANA SAYFA) çalıştı → Ana Sayfa (tam 1 gezinme), bastırılan dizi yok" % _mode_name(mode),
			_main._active_tab == 0 and home.visible and _main.nav_navigations == nav_before + 1 and _no_settled())
	print("-- Profil dişlisi çift dokunuş koruması (TASK/044)")
	_main._show_tab(4)
	await _wait_settled()
	var gear_pos: Vector2 = _center(profile.settings_button())
	await _finger_tap(gear_pos)
	_c("ön koşul: Profil dişlisi noktası Ayarlar çerçevesinin DIŞINDA (ikinci dokunuş karartmaya)",
		_main._settings.visible and not _main._settings.frame().get_global_rect().has_point(_canvas(gear_pos)))
	await _finger_tap(gear_pos)
	_c("Profil dişlisine hızlı ikinci dokunuş karartmaya düştü ama Ayarlar açık kaldı", _main._settings.visible
		and _no_settled())
	await _wait_settled()
	await _back()
	_c("GERİ Ayarlar'ı kapattı, Profil'de kalındı", not _main._settings.visible and _main._active_tab == 4)
	_sections_done += 1


# --- 5) Oyun içi pencereler: Mola / Refill / Devam -------------------------------------------------

func _gameplay_modals() -> void:
	print("-- Mola: HUD geri (parmak) → Android GERİ → ilk tahta dokunuşu")
	await _start_round()
	await _finger_tap(_center(_board._hud.back_button))
	_c("Mola açık, board donuk", _main.is_pause_open() and _board._is_paused())
	await _wait(0.35)
	await _back()
	_c("GERİ molayı kapattı, board çözüldü", not _main.is_pause_open() and not _board._is_paused())
	await _wait_settled()
	await _first_touch_drops("Mola GERİ")

	print("-- Mola: DEVAM ET (parmak) → ilk tahta dokunuşu")
	await _start_round()
	await _finger_tap(_center(_board._hud.back_button))
	await _wait(0.35)
	await _finger_tap(_center(_main._pause.buttons()[0]))
	_c("DEVAM ET molayı kapattı", not _main.is_pause_open() and not _board._is_paused())
	await _wait_settled()
	await _first_touch_drops("Mola DEVAM ET")

	print("-- Refill: stok 0 güç (parmak) → Android GERİ → ilk tahta dokunuşu")
	await _start_round()
	var stocks: Dictionary = (SaveManager.data["powerups"] as Dictionary).duplicate()
	stocks[PowerUp.save_key(PowerUp.Type.SHAKE)] = 0
	SaveManager.data["powerups"] = stocks
	_board._refresh_power_bar()
	await _finger_tap(_center(_board._power_bar.slot(int(PowerUp.Type.SHAKE))))
	_c("Refill açık, board donuk", _main._refill.visible and _board.is_refill_pending())
	await _wait(0.35)
	await _back()
	_c("GERİ refill'i kapattı (hiçbir şey alınmadı), board çözüldü", not _main._refill.visible
		and not _board.is_refill_pending() and SaveManager.powerup_count(PowerUp.Type.SHAKE) == 0)
	await _wait_settled()
	await _first_touch_drops("Refill GERİ")

	print("-- Devam: teklif → DEVAM ET (parmak, sahte sağlayıcı) → ilk tahta dokunuşu")
	var provider := ReviveStub.new()
	_main.set_rewarded_provider(provider)
	await _start_round()
	_board._trigger_overflow_fail()
	await _frames(2)
	_c("Devam teklifi açık, board donuk", _main._revive.visible and _board.is_fail_pending())
	await _wait(0.35)
	await _back()
	_c("GERİ devam teklifinde yok sayılır (karar bekler)", _main._revive.visible and _board.is_fail_pending())
	await _finger_tap(_center(_main._revive.continue_button()))
	_c("DEVAM ET → devam verildi, board çözüldü", not _main._revive.visible and not _board.is_fail_pending()
		and provider.requests == 1)
	await _wait_settled()
	await _first_touch_drops("Devam")
	_main.set_rewarded_provider(null)
	_sections_done += 1


# --- 6) Kabuk pencereleri (Android geri kullananlar) -------------------------------------------

func _shell_modals() -> void:
	_leave_round()
	var home: CanvasLayer = _main._screens[0]
	var album: CanvasLayer = _main._screens[2]
	var profile: CanvasLayer = _main._screens[4]

	print("-- Koleksiyon detayı: kart (parmak) → GERİ → ilk dokunuş başka kart")
	_main._show_tab(2)
	await _wait_settled()
	var cards: Array[CollectionSkinCard] = _visible_cards(album)
	_c("ön koşul: görünür iki varsayılan-dışı kart", cards.size() >= 2)
	if cards.size() >= 2:
		await _finger_tap(_center(cards[0]))
		_c("kart → detay açık", album.is_detail_open() and album.detail_id() == cards[0].skin_id())
		await _wait_settled()
		await _back()
		_c("GERİ detayı kapattı, Koleksiyon'da kalındı", not album.is_detail_open() and _main._active_tab == 2)
		await _wait_settled()
		await _finger_tap(_center(cards[1]))
		_c("ilk dokunuş başka kartın detayını açtı", album.is_detail_open() and album.detail_id() == cards[1].skin_id()
			and _no_settled())
		await _wait_settled()
		await _back()
		await _wait_settled()
		# Pencereden ÖNCE basılı parmak + GERİ'nin başlattığı pencere: bırakış artık yutulmuyor,
		# basıştaki (gizlenmiş) karta yönlenir — yeni ekranın aynı noktadaki kontrolüne DÜŞMEZ ve
		# GERİ'nin kendi sonucuna hiçbir şey EKLEMEZ. (Godot, gizlenen basılı butona gizlenirken
		# sentetik bırakış gönderir — `_drop_mouse_focus`; kart bazen o anda açılır. Bu motor
		# davranışı düzeltmeden bağımsızdır: 25 turluk ölçümde temel 11, düzeltme 10 kez GERİ anında,
		# ikisi de 0 kez bırakışta. Burada yalnız bırakışın etkisi denetlenir.)
		var held: Vector2 = _center(cards[0])
		await _finger(held, true)
		await _back()
		_c("ön koşul: kart basılıyken GERİ → Ana Sayfa, yatışma penceresi açık", _main._active_tab == 0
			and Time.get_ticks_msec() + 80 < _main._touch_settle_until)
		var detail_at_back: bool = album.is_detail_open()
		await _finger(held, false)
		_c("basılı kartın pencere içindeki bırakışı GERİ'nin sonucuna eylem eklemedi (detay / pencere / geçiş yok), dizi kapalı",
			album.is_detail_open() == detail_at_back and _main._active_tab == 0 and not _main._daily_rewards.visible
			and not _main._chest_info.visible and not _main._settings.visible and _no_settled())
		if album.is_detail_open():
			album.close_detail(false)
		await _wait_settled()
		_main._show_tab(2)
		await _wait_settled()

	print("-- Başarımlar: TÜM BAŞARIMLAR (parmak) → GERİ → ilk dokunuş dişli")
	_main._show_tab(4)
	await _wait_settled()
	var scroll: ScrollContainer = profile.scroll()
	var cta: Button = profile.achievements_cta()
	scroll.scroll_vertical = int(cta.global_position.y - scroll.global_position.y + scroll.scroll_vertical - 400.0)
	await _frames(2)
	await _wait_settled()
	await _finger_tap(_center(cta))
	_c("Başarımlar penceresi açık", profile.achievements_overlay().visible)
	await _wait_settled()
	await _back()
	_c("GERİ Başarımlar'ı kapattı, Profil'de kalındı", not profile.achievements_overlay().visible
		and _main._active_tab == 4)
	await _wait_settled()
	scroll.scroll_vertical = 0
	await _frames(2)
	await _finger_tap(_center(profile.settings_button()))
	_c("ilk dokunuş (dişli) Ayarlar'ı açtı", _main._settings.visible and _no_settled())
	await _wait_settled()
	await _back()
	await _wait_settled()

	print("-- Unvanlar: unvan (parmak) → GERİ → ilk dokunuş yeniden açar")
	await _finger_tap(_center(profile.title_button()))
	_c("Unvan seçici açık", profile.title_selector().visible)
	await _wait_settled()
	await _back()
	_c("GERİ seçiciyi kapattı, Profil'de kalındı", not profile.title_selector().visible and _main._active_tab == 4)
	await _wait_settled()
	await _finger_tap(_center(profile.title_button()))
	_c("ilk dokunuş seçiciyi yeniden açtı", profile.title_selector().visible and _no_settled())
	await _wait_settled()
	await _back()
	await _wait_settled()

	print("-- Günlük pencere: madalyon (parmak) → GERİ → ilk dokunuş Sandık")
	_main._show_tab(0)
	await _wait_settled()
	await _finger_tap(_center(home.feature_button(&"daily")))
	_c("Günlük ödüller penceresi açık", _main._daily_rewards.visible)
	await _wait(0.35)
	await _back()
	_c("GERİ günlük pencereyi kapattı, Ana Sayfa'da kalındı", not _main._daily_rewards.visible and _main._active_tab == 0)
	await _wait_settled()
	await _finger_tap(_center(home.feature_button(&"chest")))
	_c("ilk dokunuş Bonus Sandık bilgisini açtı", _main._chest_info.visible and _no_settled())
	await _wait(0.35)
	await _back()
	_c("GERİ Sandık bilgisini kapattı", not _main._chest_info.visible and _main._active_tab == 0)
	await _wait_settled()
	await _finger_tap(_center(home.play_button()))
	_c("ilk dokunuş OYNA → Harita", _main._active_tab == 1 and _no_settled())
	_sections_done += 1


# --- 7) Kaynak sözleşmesi ---------------------------------------------------------------------------

func _source_contract() -> void:
	print("-- kaynak")
	var settle_msec: int = int(_main_script.get_script_constant_map().get("TOUCH_SETTLE_MSEC", -1))
	_c("yatışma süresi aynen 300 ms (büyütülmedi)", settle_msec == 300)
	var main_src: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/main.gd"))
	var input_fn: String = _function(main_src, "func _input(")
	_c("_input dizi tabanlı: basış pencereye, sürükleme / bırakış diziye bakar", input_fn.contains("_settled_sequences")
		and input_fn.contains("_touch_settle_until"))
	_c("_input'a yeni zamanlayıcı / bekleme eklenmedi", not input_fn.contains("timer") and not input_fn.contains("await")
		and not input_fn.contains("delta") and input_fn.count("msec") == 1)
	_c("yalnız parmak olayları: masaüstü fare ve ondan öykünen dokunuş ayrı tutulur",
		main_src.contains("event.device != InputEvent.DEVICE_ID_EMULATION"))
	_sections_done += 1


# --- Yardımcılar ------------------------------------------------------------------------------------

## Sahte ödüllü sağlayıcı: DEVAM ET talebi hemen devamı verir (reklam yok).
class ReviveStub:
	extends RefCounted
	var requests: int = 0

	func show_rewarded_revive(main: Node) -> void:
		requests += 1
		main.grant_revive()


func _fixture() -> Dictionary:
	var d: Dictionary = SaveManager.DEFAULT_DATA.duplicate(true)
	d["onboarding_completed"] = true
	d["age_ad_band"] = "ADULT"
	d["powerup_starter_granted"] = true
	d["last_login_date"] = Time.get_date_string_from_system()
	d["highest_level_unlocked"] = 9
	d["powerups"] = {"bomb": 3, "upgrade": 3, "shake": 2, "clear_small": 2}
	return d


func _start_round() -> void:
	_main._start_level(load(LEVEL_PATH))
	await _frames(3)
	_board = _main._board
	_board.dumpling_dropped.connect(func(tier: int) -> void:
		_drops += 1
		_drop_aims.append(_board._aim_x)
		_drop_tiers.append(tier))
	_drops = 0
	_drop_aims.clear()
	_drop_tiers.clear()
	_watch(_board._hud.settings_button)
	await _wait(0.45)


func _leave_round() -> void:
	if _main._board != null and is_instance_valid(_main._board):
		_main.abandon_run()
	_board = null


## İzlenen kontrolün gui_input'una ulaşan PARMAK olayları ("press 0" / "release 0" /
## "drag 0"). Öykünen fare ve masaüstü olayları sayılmaz. Her kontrol bir kez bağlanır.
func _watch(control: Control) -> void:
	_watched.clear()
	if _watching.has(control.get_instance_id()):
		return
	_watching[control.get_instance_id()] = true
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		var touch := event as InputEventScreenTouch
		if touch != null:
			_watched.append(("press %d" if touch.pressed else "release %d") % touch.index)
			return
		var drag := event as InputEventScreenDrag
		if drag != null:
			_watched.append("drag %d" % drag.index))


func _gear_tap() -> void:
	_watched.clear()
	await _finger_tap(_center(_board._hud.settings_button))


func _close_settings(mode: StringName) -> void:
	match mode:
		&"back":
			await _back()
		&"kapat":
			await _finger_tap(_center(_main._settings._close))
		&"dim":
			await _finger_tap(_dim_point(_main._settings.frame()))


func _mode_name(mode: StringName) -> String:
	return {&"back": "GERİ", &"kapat": "KAPAT", &"dim": "karartma"}[mode]


## Android geri: pencere GO_BACK bildirimini ağaca yayar (Window → tüm düğümler). Main'in
## 250 ms debounce'u iki geri arasında beklenerek aşılır.
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


func _wait_until_msec(target: int) -> void:
	var left: int = target - Time.get_ticks_msec()
	if left > 0:
		await _wait(float(left) / 1000.0)
	await get_tree().process_frame


func _touch_event(pos: Vector2, pressed: bool, index: int) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = pos
	touch.pressed = pressed
	return touch


## Parmak olayı Input'a verilir ve HEMEN dağıtılır (öykünen fare önce, sonra ScreenTouch —
## cihazdaki sıra); tampon boşaltılır ki sıra deterministik olsun.
func _finger(pos: Vector2, pressed: bool, index: int = 0) -> void:
	Input.parse_input_event(_touch_event(pos, pressed, index))
	Input.flush_buffered_events()
	await get_tree().process_frame


func _finger_tap(pos: Vector2, index: int = 0) -> void:
	await _finger(pos, true, index)
	await _finger(pos, false, index)


func _finger_drag(pos: Vector2, from: Vector2, index: int = 0) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.position = pos
	drag.relative = pos - from
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	await get_tree().process_frame


## Masaüstü fare tıklaması (device 0; proje ayarı dokunuşu fareden öykünür, device -1).
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


## Tuval noktası → Input.parse_input_event'in beklediği PENCERE pikseli.
func _screen(canvas: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * canvas


func _canvas(window: Vector2) -> Vector2:
	return get_viewport().get_screen_transform().affine_inverse() * window


func _center(control: Control) -> Vector2:
	return _screen(control.get_global_rect().get_center())


func _win_world(world: Vector2) -> Vector2:
	return _screen(_board.world_to_screen(world))


## Kabın içinde, parçalardan uzak boş bir nokta (pencere pikseli).
func _board_point(dx: float) -> Vector2:
	return _win_world(Vector2(_board._center_x() + dx, _board.overflow_line_y() + 60.0))


func _world_x(window: Vector2) -> float:
	return _board.screen_to_world(_canvas(window)).x


## Pencere çerçevesinin dışında karartma noktası.
func _dim_point(frame: Control) -> Vector2:
	var rect: Rect2 = frame.get_global_rect()
	var point := Vector2(rect.get_center().x, rect.end.y + 40.0)
	if point.y >= get_viewport().get_visible_rect().size.y - 8.0:
		point.y = rect.position.y - 40.0
	return _screen(point)


func _visible_cards(album: CanvasLayer) -> Array[CollectionSkinCard]:
	var out: Array[CollectionSkinCard] = []
	var view: Rect2 = album.scroll().get_global_rect()
	for card: CollectionSkinCard in album.cards():
		var entry: SkinEntry = SkinEntry.find(card.skin_id())
		if entry == null or entry.is_default():
			continue
		if view.encloses(card.get_global_rect()):
			out.append(card)
	return out


## Main'in yuttuğu parmak dizisi kalmadı mı (takılı bastırma yok). Alan düzeltme öncesi
## Main'de yok: bu hijyen kontrolü orada true döner — negatif kontrolü davranış kontrolleri
## (drop / nişan / dişliye giden olay) belirler, betik hatası değil.
func _no_settled() -> bool:
	var sequences: Variant = _main.get("_settled_sequences")
	return sequences == null or (sequences as Dictionary).is_empty()


func _settled_has(key: int) -> bool:
	var sequences: Variant = _main.get("_settled_sequences")
	return sequences != null and (sequences as Dictionary).has(key)


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


func _stocks() -> Dictionary:
	var out: Dictionary = {}
	for type in PowerUp.all():
		out[type] = SaveManager.powerup_count(type)
	return out


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.5


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _function(code: String, header: String) -> String:
	var start: int = code.find(header)
	if start == -1:
		return ""
	var end: int = code.find("\nfunc ", start + header.length())
	return code.substr(start, (end - start) if end != -1 else -1)


func _strip_comments(code: String) -> String:
	var out: PackedStringArray = []
	for line in code.split("\n"):
		var hash: int = line.find("#")
		out.append(line if hash < 0 else line.substr(0, hash))
	return "\n".join(out)


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for path in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out
