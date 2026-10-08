extends Node
## TASK/047 — Günlük meydan okuma GameBoard dikişi testi (gerçek board, gerçek fizik). Headless.
## SAHİBİN KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_daily_challenge_board/` altına
## yönlendirilir; gerçek kayıt ailesinin (kanonik + .tmp + .bak) baytları başta / sonda
## karşılaştırılır.
##
##   godot --headless --audio-driver Dummy --path . res://tools/daily_challenge_board_test.tscn
##
## Bölümler:
##   kurulum     başlangıç bütçesi / BUGÜN / HAMLE / tepsiler gizli / devam 0 / ilk iki parça diziden;
##               normal board aynen (bütçe yok, SKOR, level rozeti, güç + 2 devam)
##   dizi        18 gerçek bırakış = 2026-10-01 kilitli vektörü; önizleme SIRADAKİ son parçada gizli
##   bütçe       gerçek bırakış tam −1 (sinyal bir kez); bekleme süresinde reddedilen bırakış 0;
##               ACTION_CANCEL 0; sürükle + iptal 0; sonraki dokunuş hemen −1; son bırakış kabul,
##               fazlası (kod / dokunuş) red; "Hamle bitti"; mola / ayarlar dönüşünde sahte parça yok
##   yatışma     son parça İNDİKTEN sonra merge'siz 1.5 s → hamle bitti kaybı; zincir yatışmayı uzatır;
##               yatışmada / inişten sonra geç merge'le hedef → kazanma; son bırakışta / önce hedef →
##               kazanma; eşik karesindeki merge isteği (ertelenmiş karar + yeniden kontrol); 5.0 s
##               mutlak tavan son bırakıştan (parça hiç inmese de); mola süresi sayılmaz
##   taşma       meydan okumada taşma = kesin kayıp (devam teklifi / fail-pending YOK, round_finished
##               bir kez, sebep OVERFLOW); yatışmada taşma; normal board aynı taşmada devam teklifi
##   güç         tepsi / madalyon / yuva gizli; dört güç basışı ve stok 0 refill isteği hiçbir şey
##               yapmaz; stok aynen; mola / ayarlar / refill / devam geçişleri çubuğu AÇAMAZ
##   normal      meydan okumadan sonra normal board: taze production DropBag, güç açık, 2 devam,
##               sınırsız bırakış, HUD aynen
##   kaynak      DROP_COOLDOWN / OVERFLOW_GRACE / MAX_REVIVES / TierConfig aynen; TASK/046.2 iptal
##               koruması aynen; dikiş varsayılan KAPALI

const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const DIR: String = "user://qa_daily_challenge_board"
const PATH: String = DIR + "/save.json"
const SECTIONS: int = 8
const THU: String = "2026-10-01"
const GOLDEN: Array[int] = [1, 3, 1, 1, 3, 2, 2, 3, 2, 1, 3, 3, 1, 2, 1, 2, 3, 2]
## 1.5 s / 5.0 s fizik karesi (60 Hz) ve ölçüm payı.
const QUIET_FRAMES: int = 90
const CAP_FRAMES: int = 300

var _board: Node2D
var _drops: int = 0
var _dropped_tiers: Array[int] = []
var _finished_events: Array[bool] = []
var _finish_frame: int = -1
var _revive_offers: int = 0
var _refill_offers: int = 0
var _moves_events: Array[int] = []
var _merge_frames: Array[int] = []
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
	SaveManager.data = _fixture()
	SaveManager.save_game()
	GameState.merge_performed.connect(_on_merge)
	get_tree().create_timer(300.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 300 s'de bitmedi")
			_teardown()
			get_tree().quit(2))
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame

	await _setup_and_hud()
	await _sequence_and_previews()
	await _budget()
	await _settle()
	await _overflow()
	await _powers()
	await _normal_after_challenge()
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
	DailyRewards.auto_popup_enabled = _popup_flag_before
	if GameState.merge_performed.is_connected(_on_merge):
		GameState.merge_performed.disconnect(_on_merge)
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	for path in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- 1) Kurulum + HUD -------------------------------------------------------------------------

func _setup_and_hud() -> void:
	print("-- kurulum + HUD")
	await _make_challenge(DailyChallenge.make_level(THU), 15)
	var hud: GameplayHud = _board._hud
	_c("meydan okuma kipi: bütçe 15 (perşembe), kullanılan 0, kalan 15", _board.is_daily_challenge()
		and _board.drop_budget() == 15 and _board.drops_used() == 0 and _board.drops_remaining() == 15)
	_c("ilk iki parça diziden: bekleyen = 1, SIRADAKİ = 3 (kilitli vektörün başı)", _board._pending_tier == GOLDEN[0]
		and _board._next_tier == GOLDEN[1])
	_c("HUD: level rozeti 'BUGÜN', skor plakası 'HAMLE' + '15'", hud.level_label.text == "BUGÜN"
		and hud.score_caption.text == "HAMLE" and hud.score_label.text == "15")
	_c("hedef kartı aynen: 'HEDEF' + Büyük Dumpling + portre", hud.goal_caption.text == "HEDEF"
		and hud.goal_label.text == "Büyük Dumpling" and hud.goal_portrait.visible)
	_c("güç tepsileri + madalyonlar gizli, çubuk kilitli ve kapalı", not hud.tray_left.visible
		and not hud.tray_right.visible and not hud.power_bar.visible and _all_slots_hidden()
		and hud.power_bar.is_locked() and not hud.power_bar.is_enabled())
	_c("  … orta dekor katmanında görünür güç dekoru yok (TASK/060: tepsi / yuva dekoru kalktı, madalyonlar kendini çizer)",
		_deco_mid_hidden())
	_c("devam hakkı 0 (teklif hiç açılmaz), güç kapalı", _board.max_revives() == 0 and _board.revives_remaining() == 0
		and not _board.powers_enabled())
	_c("önizleme + SIRADAKİ görünür (kalan > 1), sonuç sebebi yok, yatışma yok", _board._preview.visible
		and hud.next_plate.visible and _board.fail_reason() == DailyChallenge.FailReason.NONE
		and not _board.is_settling())
	_c("skor değişince plaka HAMLE kalır (skor metni / pop yok)", await _score_keeps_moves())
	await _make_normal(8)
	hud = _board._hud
	_c("normal board: bütçe yok (-1), devam 2, güç açık, SKOR + '8' rozeti, tepsiler görünür",
		not _board.is_daily_challenge() and _board.drops_remaining() == -1 and _board.max_revives() == 2
		and _board.powers_enabled() and hud.score_caption.text == "SKOR" and hud.level_label.text == "8"
		and hud.tray_left.visible and hud.power_bar.visible and not hud.power_bar.is_locked()
		and hud.power_bar.is_enabled() and hud.next_plate.visible)
	_c("normal board production DropBag kullanır", (_board._drop_bag.get_script() as Script).resource_path
		== "res://scripts/game/drop_bag.gd")
	_sections_done += 1


func _score_keeps_moves() -> bool:
	GameState.add_score(110)
	await get_tree().process_frame
	return _board._hud.score_label.text == "15" and _board._hud.score_pop.modulate.a == 0.0


# --- 2) Dizi + önizlemeler ----------------------------------------------------------------------

func _sequence_and_previews() -> void:
	print("-- gerçek bırakışlar = deterministik dizi; önizlemeler")
	# Hedef T8: 18 bırakışta ulaşılamaz → round kazanmayla bitmez, dizi tam okunur.
	await _make_challenge(_level(8, 600.0), 18)
	var hud: GameplayHud = _board._hud
	var next_hidden_at_one: bool = false
	var preview_at_one: bool = false
	for i in 18:
		if _board.drops_remaining() == 1:
			next_hidden_at_one = not hud.next_plate.visible
			preview_at_one = _board._preview.visible and _board._pending_tier == GOLDEN[17]
		await _quick_drop(i)
	_c("18 gerçek bırakış (dumpling_dropped) kilitli vektör: 1,3,1,1,3,2,2,3,2 | 1,3,3,1,2,1,2,3,2",
		_same(_dropped_tiers, GOLDEN))
	_c("kalan 1 iken: SIRADAKİ gizli (sonraki gerçek bırakış yok), bekleyen son parça görünür",
		next_hidden_at_one and preview_at_one)
	_c("kalan 0: bırakış çizgisinde parça YOK, SIRADAKİ gizli, HAMLE 0", not _board._preview.visible
		and not hud.next_plate.visible and hud.score_label.text == "0" and _board.drops_remaining() == 0)
	_c("drops_changed her bırakışta bir kez, 17 … 0", _same(_moves_events, range(17, -1, -1)))
	_sections_done += 1


# --- 3) Bütçe -----------------------------------------------------------------------------------

func _budget() -> void:
	print("-- bütçe: gerçek bırakış = tam bir hamle")
	await _make_challenge(_level(8, 600.0), 5)
	var p: Vector2 = _point(-120.0)
	await _direct(p, true)
	await _direct(p, false)
	_c("gerçek dokunuş bırakışı: tam −1 (kalan 4), sinyal bir kez, parça doğdu", _drops == 1
		and _board.drops_remaining() == 4 and _same(_moves_events, [4]) and _board._hud.score_label.text == "4")
	_c("DROP_COOLDOWN aynen başladı (0 < kalan ≤ 0.4)", _board._drop_cooldown > 0.0 and _board._drop_cooldown <= _board_const("DROP_COOLDOWN"))
	await _direct(_point(60.0), true)
	await _direct(_point(60.0), false)
	_board._drop()
	_c("bekleme süresinde dokunuş + kod bırakışı: reddedildi, hamle düşmedi", _drops == 1 and _board.drops_used() == 1)
	await _wait(0.45)
	# Bekleme süresi KESİN bitmiş: iptal bir parça düşürseydi bekleme süresi onu engelleyemezdi.
	_board._drop_cooldown = 0.0
	var before: Dictionary = _state()
	await _direct(_point(90.0), true)
	await _direct(_point(90.0), false, true)
	_c("ACTION_CANCEL bırakışı: hamle 0, parça / tier / sinyal yok", _board.drops_used() == 1 and _drops == 1
		and _state() == before)
	await _direct(_point(100.0), true)
	await _direct_drag(_point(-100.0))
	await _direct(_point(-100.0), false, true)
	_c("sürükle + İPTAL: hamle 0, nişan sürüklenen yerde", _board.drops_used() == 1 and _drops == 1
		and absf(_board._aim_x - _point(-100.0).x) <= 2.0)
	await _direct(_point(30.0), true)
	await _direct(_point(30.0), false)
	_c("iptalden HEMEN sonra bağımsız dokunuş: tam −1 (kalan 3)", _drops == 2 and _board.drops_remaining() == 3)
	for i in 3:
		await _wait(0.45)
		await _direct(_point(-150.0 + 100.0 * i), true)
		await _direct(_point(-150.0 + 100.0 * i), false)
	_c("son izinli bırakış KABUL (5/5), kalan 0, 'Hamle bitti', yatışma başladı", _drops == 5
		and _board.drops_remaining() == 0 and _board.is_settling()
		and _board._hud.status_label.text == "Hamle bitti" and _board._hud.status_plate.visible)
	var pieces: int = _pieces().size()
	await _wait(0.45)
	await _direct(_point(0.0), true)
	await _direct(_point(0.0), false)
	_board._drop_cooldown = 0.0
	_board._drop()
	_c("6. bırakış (dokunuş + kod) REDDEDİLDİ: parça / hamle / sinyal yok", _drops == 5 and _board.drops_used() == 5
		and _pieces().size() <= pieces)
	_board.set_menu_paused(true)
	await _frames(2)
	_board.set_menu_paused(false)
	await _frames(2)
	_c("mola / ayarlar dönüşü (yatışma sürerken): bırakış çizgisinde sahte parça YOK, SIRADAKİ gizli",
		not _board._preview.visible and not _board._hud.next_plate.visible and _board.is_settling()
		and not _board.is_finished())
	_board.set_tutorial_input_locked(false)
	_c("önizleme açan öteki yollar da sahte parça göstermez", not _board._preview.visible)
	_sections_done += 1


func _board_const(name: String) -> float:
	return float(_board.get_script().get_script_constant_map()[name])


# --- 4) Yatışma ---------------------------------------------------------------------------------

func _settle() -> void:
	print("-- son bırakıştan sonra yatışma (1.5 s merge'siz / 5.0 s tavan)")
	# a) Merge'siz: son bırakış boş kaba → parça İNDİKTEN 1.5 s sonra hamle bitti kaybı (düşüş süresi
	#    sessiz pencereden yemez).
	await _make_challenge(_level(8, 600.0), 1)
	_board._set_aim(_board._center_x())
	var drop_frame: int = await _drop_now()
	var land_frame: int = await _until_landed(_board._settle_piece, 200)
	await _until_finished(400)
	var waited: int = _finish_frame - land_frame
	_c("merge'siz yatışma: son parça İNDİKTEN ~1.5 s (%d fizik karesi; düşüş %d kare) sonra KAYIP, sebep MOVES_EXHAUSTED, sinyal bir kez"
		% [waited, land_frame - drop_frame], _same(_finished_events, [false])
		and _board.fail_reason() == DailyChallenge.FailReason.MOVES_EXHAUSTED and land_frame - drop_frame >= 30
		and waited >= QUIET_FRAMES - 1 and waited <= QUIET_FRAMES + 6)
	_c("  … devam teklifi yok, sonuç plakası 'Bitti'", _revive_offers == 0 and _board._hud.status_label.text == "Bitti")

	# b) Zincir: son parça bekleyen T1'e düşüp merge eder → sessiz pencere merge'den itibaren.
	await _make_challenge(_level(8, 600.0), 1)
	var x: float = _board._center_x()
	_spawn(1, Vector2(x, _board_const("FLOOR_Y") - 22.0))
	await _frames(20)
	_merge_frames.clear()
	_board._set_aim(x)
	drop_frame = await _drop_now()
	await _until_finished(500)
	var merge_ok: bool = not _merge_frames.is_empty()
	var last_merge: int = _merge_frames.back() if merge_ok else -1
	_c("zincir: son bırakış merge etti (%d. karede); kayıp merge'den ≥ 1.5 s sonra (%d kare)"
		% [last_merge - drop_frame, _finish_frame - last_merge], merge_ok and _same(_finished_events, [false])
		and _finish_frame - last_merge >= QUIET_FRAMES - 2 and _finish_frame - drop_frame > QUIET_FRAMES + 2)

	# c) Yatışmada hedef: son bırakış T1 + bekleyen T1 → T2 = hedef → KAZANMA (hamle 0 iken).
	await _make_challenge(_level(2, 600.0), 1)
	x = _board._center_x() - 80.0
	_spawn(1, Vector2(x, _board_const("FLOOR_Y") - 22.0))
	await _frames(20)
	_board._set_aim(x)
	await _drop_now()
	var settling: bool = _board.is_settling() and _board.drops_remaining() == 0
	await _until_finished(400)
	_c("yatışmada hedef oluştu → KAZANMA (son bırakıştan sonra, hamle 0), sebep yok", settling
		and _same(_finished_events, [true]) and _board.fail_reason() == DailyChallenge.FailReason.NONE)

	# d) Hedef son bırakıştan ÖNCE: kazanma, kalan hamle korunur.
	await _make_challenge(_level(2, 600.0), 4)
	x = _board._center_x() + 60.0
	_spawn(1, Vector2(x, _board_const("FLOOR_Y") - 22.0))
	await _frames(20)
	_board._set_aim(x)
	await _drop_now()
	await _until_finished(400)
	_c("hedef son bırakıştan önce → KAZANMA, kullanılan 1 / 4", _same(_finished_events, [true]) and _board.drops_used() == 1
		and not _board.is_settling())

	# e) 5.0 s mutlak tavan: merge'ler hiç durmasa (her karede merge isteği) bile kayıp.
	await _make_challenge(_level(8, 600.0), 1)
	_board._set_aim(_board._center_x())
	drop_frame = await _drop_now()
	var guard: int = 0
	while _finish_frame < 0 and guard < 450:
		_board._note_challenge_merge()
		await get_tree().physics_frame
		guard += 1
	waited = _finish_frame - drop_frame
	_c("mutlak tavan: kesintisiz merge'de bile 5.0 s (%d kare) sonra KAYIP (MOVES_EXHAUSTED)" % waited,
		_same(_finished_events, [false]) and _board.fail_reason() == DailyChallenge.FailReason.MOVES_EXHAUSTED
		and waited >= CAP_FRAMES - 1 and waited <= CAP_FRAMES + 6)

	# f) Mola süresi sayılmaz (parça indikten 30 kare sonra 150 kare mola).
	await _make_challenge(_level(8, 600.0), 1)
	_board._set_aim(_board._center_x())
	drop_frame = await _drop_now()
	land_frame = await _until_landed(_board._settle_piece, 200)
	await _frames(30)
	_board.set_menu_paused(true)
	await _frames(150)
	var paused_ok: bool = _finish_frame < 0 and _board.is_settling()
	_board.set_menu_paused(false)
	await _until_finished(400)
	waited = _finish_frame - land_frame
	_c("mola açıkken (150 kare) yatışma işlemez; kapanınca kalan süre işler (inişten %d kare)" % waited,
		paused_ok and _same(_finished_events, [false]) and waited >= QUIET_FRAMES + 150 - 2
		and waited <= QUIET_FRAMES + 150 + 8)

	# g) İnişten SONRA gelen geç merge (sekme / yuvarlanma): son parça yere iner, 30 kare sonra eşi
	#    üstüne düşüp hedefi kurar → KAZANMA. (Pencere bırakıştan sayılsaydı ~90. karede kayıptı.)
	await _make_challenge(_level(2, 600.0), 1)
	_board._set_aim(_board._center_x())
	drop_frame = await _drop_now()
	var final_piece: Dumpling = _board._settle_piece
	land_frame = await _until_landed(final_piece, 200)
	await _frames(30)
	var partner_frame: int = Engine.get_physics_frames()
	if is_instance_valid(final_piece):
		_spawn(1, final_piece.position + Vector2(0.0, -60.0))
	await _until_finished(400)
	_c("geç merge (eş inişten %d, bırakıştan %d kare sonra): hedef → KAZANMA, sebep yok"
		% [partner_frame - land_frame, partner_frame - drop_frame], _same(_finished_events, [true])
		and _board.fail_reason() == DailyChallenge.FailReason.NONE and partner_frame - drop_frame > QUIET_FRAMES)

	# h) Eşik karesinde merge isteği (yarış): karar ertelenir + yeniden kontrol → hedef kazanır.
	var pair: Array[Dumpling] = await _race_setup(_level(2, 600.0))
	_board._tick_challenge_settle(1.6)
	_board._on_merge_requested(pair[0], pair[1], (pair[0].position + pair[1].position) * 0.5)
	await _frames(3)
	_c("eşik karesinde gelen merge isteği hedefi kurar → KAZANMA (ertelenmiş karar + yeniden kontrol)",
		_same(_finished_events, [true]) and _board.fail_reason() == DailyChallenge.FailReason.NONE)

	# i) Aynı yarış, hedefe ulaşmayan merge: zincir sürer; kayıp ~1.5 s SONRA yine gelir.
	pair = await _race_setup(_level(8, 600.0))
	_board._tick_challenge_settle(1.6)
	_board._on_merge_requested(pair[0], pair[1], (pair[0].position + pair[1].position) * 0.5)
	var race_frame: int = Engine.get_physics_frames()
	await _until_finished(300)
	waited = _finish_frame - race_frame
	_c("eşik karesinde hedefe ulaşmayan merge: kayıp ertelendi, ~1.5 s sonra MOVES_EXHAUSTED (%d kare)" % waited,
		_same(_finished_events, [false]) and _board.fail_reason() == DailyChallenge.FailReason.MOVES_EXHAUSTED
		and waited >= QUIET_FRAMES - 2 and waited <= QUIET_FRAMES + 8)

	# j) Son parça hiç inmezse (yerçekimsiz — beyaz kutu) sessiz pencere başlamaz; tavan bırakıştan 5.0 s.
	await _make_challenge(_level(8, 600.0), 1)
	_board._set_aim(_board._center_x())
	drop_frame = await _drop_now()
	var hover: Dumpling = _board._settle_piece
	hover.gravity_scale = 0.0
	hover.linear_velocity = Vector2.ZERO
	await _until_finished(400)
	waited = _finish_frame - drop_frame
	_c("son parça inmezse: mutlak tavan son bırakıştan 5.0 s (%d kare) → MOVES_EXHAUSTED" % waited,
		is_instance_valid(hover) and not hover.has_landed and _same(_finished_events, [false])
		and _board.fail_reason() == DailyChallenge.FailReason.MOVES_EXHAUSTED
		and waited >= CAP_FRAMES - 1 and waited <= CAP_FRAMES + 6)
	_sections_done += 1


## Yarış kurulumu: bütçe 1, son parça sola iner; sağda birbirine değmeyen iki T1 (merge isteği elle).
func _race_setup(level: LevelData) -> Array[Dumpling]:
	await _make_challenge(level, 1)
	_board._set_aim(_board._left_x() + 60.0)
	await _drop_now()
	await _until_landed(_board._settle_piece, 200)
	var floor_y: float = _board_const("FLOOR_Y")
	var a: Dumpling = _spawn(1, Vector2(_board._right_x() - 150.0, floor_y - 22.0))
	var b: Dumpling = _spawn(1, Vector2(_board._right_x() - 40.0, floor_y - 22.0))
	await _frames(2)
	# Dumpling._on_body_entered'ın yaptığı gibi iki taraf da kilitlenir.
	a.is_merging = true
	b.is_merging = true
	return [a, b]


## Parçanın ilk temasının (has_landed) fizik karesi; parça merge'de yok olduysa o kare; yoksa -1.
func _until_landed(piece: Dumpling, max_frames: int) -> int:
	var guard: int = 0
	while guard < max_frames:
		if piece == null or not is_instance_valid(piece) or piece.has_landed:
			return Engine.get_physics_frames()
		await get_tree().physics_frame
		guard += 1
	return -1


# --- 5) Taşma ------------------------------------------------------------------------------------

func _overflow() -> void:
	print("-- taşma: meydan okumada devam YOK")
	await _make_challenge(DailyChallenge.make_level(THU), 15)
	await _pile_kings()
	await _until_finished(900)
	_c("meydan okuma taşması: KESİN kayıp, sebep OVERFLOW, round_finished bir kez",
		_same(_finished_events, [false]) and _board.fail_reason() == DailyChallenge.FailReason.OVERFLOW)
	_c("  … devam teklifi / fail-pending / refill YOK, grant_revive reddedilir", _revive_offers == 0
		and not _board.is_fail_pending() and _refill_offers == 0 and not _board.grant_revive()
		and _board.revives_used() == 0)

	# Yatışma sırasında taşma: merge'ler yatışmayı canlı tutarken taşma kesinleşir → OVERFLOW.
	await _make_challenge(_level(8, 420.0), 1)
	_board._set_aim(_board._center_x())
	await _drop_now()
	await _pile_kings(true)
	await _until_finished(900, true)
	_c("yatışma sırasında taşma kesinleşti → kayıp, sebep OVERFLOW (devam yok)", _same(_finished_events, [false])
		and _board.fail_reason() == DailyChallenge.FailReason.OVERFLOW and _revive_offers == 0)

	await _make_normal(8)
	await _pile_kings()
	var guard: int = 0
	while _revive_offers == 0 and _finish_frame < 0 and guard < 900:
		await get_tree().physics_frame
		guard += 1
	_c("normal board aynı taşmada devam teklifi açar (2 hak), round bitmez", _revive_offers == 1
		and _board.is_fail_pending() and _finished_events.is_empty() and _board.revives_remaining() == 2)
	_board.decline_revive()
	_sections_done += 1


## Kaba tier 8'ler (level modunda birleşmez), ÇAKIŞMAYAN ızgarada: iki sütun × üç sıra. Dar kapta
## sırada en fazla iki kral sığar; altı kral en az 540 px yükseklik ister → 400'lük alan taşar.
func _pile_kings(keep_merging: bool = false) -> void:
	var left: float = _board._left_x()
	var width: float = _board.level.container_width
	var floor_y: float = _board_const("FLOOR_Y")
	for row in 3:
		for column in 2:
			var x: float = left + width * (0.25 if column == 0 else 0.75)
			_spawn(8, Vector2(x, floor_y - 101.0 - 205.0 * float(row)))
	for f in 12:
		if keep_merging:
			_board._note_challenge_merge()
		await get_tree().physics_frame


# --- 6) Güçler ----------------------------------------------------------------------------------

func _powers() -> void:
	print("-- güçler tamamen kapalı")
	await _make_challenge(DailyChallenge.make_level(THU), 15, 2)
	var stock: Dictionary = (SaveManager.data["powerups"] as Dictionary).duplicate()
	for type in PowerUp.all():
		_board._power_bar.power_pressed.emit(int(type))
		await _frames(2)
	_c("dört güç basışı: hiçbiri silahlanmadı / çalışmadı, stok aynen, refill yok",
		not _board._powerups.is_armed() and SaveManager.data["powerups"] == stock and _refill_offers == 0
		and _board._hud.status_label.text == "")
	_c("denetleyici kapalı: güç isteği reddedilir, refill sinyali yayılmaz", not _board._powerups.request(PowerUp.Type.BOMB)
		and _refill_offers == 0)
	await _make_challenge(DailyChallenge.make_level(THU), 15, 0)
	for type in PowerUp.all():
		_board._power_bar.power_pressed.emit(int(type))
		_board._powerups.refill_requested.emit(int(type))
		await _frames(1)
	_c("stok 0: refill penceresi / ödüllü refill isteği YOK, board donmadı", _refill_offers == 0
		and not _board.is_refill_pending() and not _board._is_paused())
	_board.set_menu_paused(true)
	_board.set_menu_paused(false)
	_board._power_bar.set_enabled(true)
	_board._is_refill_pending = true
	_board.exit_refill_pending(true)
	await _frames(2)
	_c("mola / ayarlar / refill / devam dönüşü çubuğu AÇAMAZ (kilitli, kapalı, gizli)",
		not _board._power_bar.is_enabled() and _board._power_bar.is_locked() and not _board._hud.power_bar.visible
		and not _board._hud.tray_left.visible and _all_slots_hidden() and not _board._powerups.is_armed())
	_c("güç envanteri dokunulmadı (kayıt aynen)", _same((SaveManager.data["powerups"] as Dictionary).values(), [0, 0, 0, 0]))
	_sections_done += 1


# --- 7) Meydan okumadan sonra normal board -------------------------------------------------------

func _normal_after_challenge() -> void:
	print("-- meydan okumadan sonra normal round")
	await _make_challenge(DailyChallenge.make_level(THU), 15)
	await _quick_drop(0)
	await _make_normal(9, 1)
	var hud: GameplayHud = _board._hud
	_c("taze production DropBag (meydan okuma kaynağı taşınmadı)",
		(_board._drop_bag.get_script() as Script).resource_path == "res://scripts/game/drop_bag.gd")
	_c("güç açık ve görünür, 2 devam, HUD SKOR + level rozeti", _board.powers_enabled() and hud.power_bar.visible
		and hud.tray_left.visible and _all_slots_visible() and hud.power_bar.is_enabled() and not hud.power_bar.is_locked()
		and _board.max_revives() == 2 and hud.score_caption.text == "SKOR" and hud.level_label.text == "9")
	for i in 22:
		await _quick_drop(i)
	_c("sınırsız bırakış: 22 bırakışın hepsi kabul, bütçe / yatışma yok", _drops == 22 and not _board.is_settling()
		and _board.drops_remaining() == -1 and _board._preview.visible)
	_board._power_bar.power_pressed.emit(int(PowerUp.Type.BOMB))
	await _frames(2)
	_c("normal güç basışı silahlanır (güç yolu aynen)", _board._powerups.is_armed())
	_board._powerups.cancel()
	_sections_done += 1


# --- 8) Kaynak sözleşmesi --------------------------------------------------------------------------

func _source_contract() -> void:
	print("-- kaynak sözleşmesi")
	var constants: Dictionary = (load("res://scripts/game/game_board.gd") as GDScript).get_script_constant_map()
	_c("DROP_COOLDOWN 0.4, OVERFLOW_GRACE 1.5, MAX_REVIVES_PER_ROUND 2 aynen",
		is_equal_approx(float(constants["DROP_COOLDOWN"]), 0.4) and is_equal_approx(float(constants["OVERFLOW_GRACE"]), 1.5)
		and int(constants["MAX_REVIVES_PER_ROUND"]) == 2)
	var radii: Array = []
	var scores: Array = []
	for tier in range(1, TierConfig.MAX_TIER + 1):
		radii.append(TierConfig.radius(tier))
		scores.append(TierConfig.merge_score(tier))
	_c("TierConfig yarıçapları / merge puanları aynen", radii == [22.0, 27.0, 34.0, 42.0, 52.0, 65.0, 81.0, 100.0]
		and scores == [0, 50, 70, 90, 110, 130, 150, 200])
	var code: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/game/game_board.gd"))
	_c("TASK/046.2 iptal koruması aynen (`elif not touch.canceled:` → `_drop()`)", code.contains("elif not touch.canceled:"))
	_c("board rastgeleliği meydan okumaya girmedi (game_board.gd'de seed( yok)", not code.contains("seed("))
	var fresh: Node2D = GAME_BOARD_SCENE.instantiate()
	_c("dikiş varsayılan KAPALI: yeni board meydan okuma değil, güç açık, devam = const",
		not fresh.is_daily_challenge() and fresh.powers_enabled() and fresh.max_revives() == 2 and fresh.drops_remaining() == -1)
	fresh.free()
	_sections_done += 1


# --- Yardımcılar ----------------------------------------------------------------------------------

func _fixture(stock: int = 2) -> Dictionary:
	var stocks: Dictionary = {}
	for type in PowerUp.all():
		stocks[PowerUp.save_key(type)] = stock
	return {"highest_level_unlocked": 5, "dough": 335, "powerups": stocks, "powerup_starter_granted": true,
		"onboarding_completed": true, "age_ad_band": "ADULT"}


func _level(target: int, width: float) -> LevelData:
	var level: LevelData = DailyChallenge.make_level(THU)
	level.target_tier = target
	level.container_width = width
	return level


func _make_challenge(level: LevelData, budget: int, stock: int = 2) -> void:
	await _free_board()
	_reset_counters(stock)
	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(level)
	_board.setup_challenge(DailyChallenge.Sequence.new(THU), budget)
	_connect_board()
	add_child(_board)
	await _frames(2)


func _make_normal(number: int, stock: int = 2) -> void:
	await _free_board()
	_reset_counters(stock)
	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(load("res://resources/levels/level_%02d.tres" % number))
	_connect_board()
	add_child(_board)
	await _frames(2)


func _reset_counters(stock: int) -> void:
	GameState.reset_run()
	SaveManager.data = _fixture(stock)
	_drops = 0
	_dropped_tiers.clear()
	_finished_events.clear()
	_finish_frame = -1
	_revive_offers = 0
	_refill_offers = 0
	_moves_events.clear()
	_merge_frames.clear()


func _connect_board() -> void:
	_board.dumpling_dropped.connect(func(tier: int) -> void:
		_drops += 1
		_dropped_tiers.append(tier))
	_board.round_finished.connect(func(won: bool) -> void:
		_finished_events.append(won)
		if _finish_frame < 0:
			_finish_frame = Engine.get_physics_frames())
	_board.revive_offered.connect(func(_remaining: int) -> void: _revive_offers += 1)
	_board.power_refill_offered.connect(func(_type: int) -> void: _refill_offers += 1)
	_board.drops_changed.connect(func(remaining: int) -> void: _moves_events.append(remaining))


func _free_board() -> void:
	if _board != null and is_instance_valid(_board):
		_board.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_board = null


func _on_merge(_tier: int, _position: Vector2) -> void:
	_merge_frames.append(Engine.get_physics_frames())


## Hızlı bırakış (bekleme süresi atlanır — yalnız sıra / sayım testleri), x yayılır.
func _quick_drop(i: int) -> void:
	_board._drop_cooldown = 0.0
	_board._set_aim(_board._left_x() + 60.0 + float((i * 97) % int(_board.level.container_width - 120.0)))
	_board._drop()
	await _frames(4)


## Tek bırakış (bekleme yok); bırakış anının fizik karesi.
func _drop_now() -> int:
	_board._drop_cooldown = 0.0
	var frame: int = Engine.get_physics_frames()
	_board._drop()
	return frame


func _until_finished(max_frames: int, keep_merging: bool = false) -> void:
	var guard: int = 0
	while _finish_frame < 0 and guard < max_frames:
		if keep_merging:
			_board._note_challenge_merge()
		await get_tree().physics_frame
		guard += 1


func _state() -> Dictionary:
	return {"pending": _board._pending_tier, "next": _board._next_tier, "pieces": _pieces().size(),
		"used": _board.drops_used(), "cooldown": _board._drop_cooldown}


func _point(dx: float) -> Vector2:
	return Vector2(_board._center_x() + dx, _board.overflow_line_y() + 60.0)


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


func _spawn(tier: int, at: Vector2) -> Dumpling:
	return _board._spawn_dumpling(tier, at)


func _pieces() -> Array[Dumpling]:
	var out: Array[Dumpling] = []
	for child in _board._dumpling_layer.get_children():
		var d := child as Dumpling
		if d != null and is_instance_valid(d) and not d.is_queued_for_deletion():
			out.append(d)
	return out


func _all_slots_hidden() -> bool:
	for type in PowerBar.SLOT_ORDER:
		if _board._hud.power_bar.slot(int(type)).is_visible_in_tree():
			return false
	return true


func _all_slots_visible() -> bool:
	for type in PowerBar.SLOT_ORDER:
		if not _board._hud.power_bar.slot(int(type)).is_visible_in_tree():
			return false
	return true


## Orta dekor katmanında görünür güç dekoru yok mu. TASK/060 HUD V3: tepsi gloss'u / madalyon yuvaları KALDIRILDI
## (katman boş olabilir); kalan her çocuk gizli olmalı.
func _deco_mid_hidden() -> bool:
	var mid: Node = _board._hud.get_node_or_null("DecoMid")
	if mid == null:
		return false
	for child in mid.get_children():
		if (child as CanvasItem).visible:
			return false
	return true


func _same(a: Array, b: Array) -> bool:
	return str(a) == str(b)


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


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for path in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out
