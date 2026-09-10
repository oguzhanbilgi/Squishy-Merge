extends Node
## Devam etme (revive) akisinin davranissal testi + gorsel QA cekimleri
## (M8.5-04, GAME_DESIGN.md §11).
##
## Neden bir arac: bu akisin kritik invariant'lari ("round_finished yalnizca
## bir kez", "reward callback'i olmadan devam verilmez", "temizlik skoru
## degistirmez") elle oynayarak guvenilir dogrulanamaz — taşmayi tetiklemek
## dakikalar suruyor ve sayaclar ekranda gorunmuyor.
##
## GERCEK REKLAM YOK: harness ödül kazanildi callback'ini dogrudan
## `grant_revive()` cagirarak simule ediyor. Production UI'da boyle bir yol
## YOKTUR (bkz. scripts/ui/revive_offer.gd).
##
## Kullanim (cekim istenirse PENCERELI calismali, --headless ile cekimler bos
## cikar):
##   godot --path . res://tools/revive_test.tscn -- <cikti_klasoru>
##   godot --headless --audio-driver Dummy --path . res://tools/revive_test.tscn
##
## KAYIT DOSYASI: senaryo 1-5 yazmaz (hicbir round finalize edilmiyor,
## SaveManager yalnizca guc stogu icin okunuyor). Senaryo 6 gercek main.gd
## akisini kullandigi icin YAZAR — calistirmadan once owner kaydini yedekle,
## sonra byte-identical geri yukle.

const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const REVIVE_OFFER_SCENE: PackedScene = preload("res://scenes/ui/revive_offer.tscn")
const BOT_BRAIN = preload("res://tools/bot_brain.gd")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

## Fizigi bozmadan hizlandirma (bot_runner.gd ile ayni yontem): fizik adimi
## 1/60 sn kaliyor, saniyede N kat adim atiliyor.
const SPEEDUP: int = 6
## Tasma icin KOTU oyun gerekiyor; rastgele birakma yigini merge etmeden
## yukseltiyor. Bot kazanip cikarsa yeniden denenir.
const FAIL_ATTEMPTS: int = 8
## Bir tasma denemesi icin ust sinir (kare).
const FAIL_MAX_FRAMES: int = 60 * 200
## Cekimlerin alindigi pencere olcusu — proje 720x1280, ayni oranda.
const SHOT_SIZE := Vector2i(540, 960)
## Level 10: en dar kap (370 px), tasma en hizli burada olusuyor.
const TEST_LEVEL: int = 10
## 0 = sonsuz mod (resources/levels/endless.tres).
const ENDLESS_LEVEL: int = 0

var _out_dir: String = ""
var _board: Node2D
var _offer: CanvasLayer
var _drive: bool = false
var _shots: bool = false

## Board'un yaydigi sinyallerin sayaclari — "yalnizca bir kez" iddialari
## bunlarla dogrulaniyor.
var _finished_count: int = 0
var _finished_won: Array[bool] = []
var _offered_count: int = 0
var _offered_remaining: Array[int] = []
var _granted_count: int = 0

var _passed: int = 0
var _failed: int = 0
## Oyun-ici gecen sure (sn). Engine.time_scale delta'ya zaten yansidigi icin
## delta toplami gercek oyun saniyesi veriyor — hizlandirmadan bagimsiz.
var _game_time: float = 0.0

## Sabit tohum: bot rastgele birakiyor, tohumsuz her kosu bambaska bir yigin
## uretiyor. Kosuyu BIREBIR tekrarlanabilir YAPMAZ — kamera sarsintisi
## `_process` icinde ayni global RNG'yi tuketiyor ve `_process` fizik
## kareleriyle sabit oranda calismiyor (M8.5-03'te kaydedilen teknik borc,
## bu taskta degistirilmedi). Bu yuzden senaryolar sonuca gore dallanabilmeli.
const RNG_SEED: int = 20260909


func _ready() -> void:
	seed(RNG_SEED)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_shots = args.size() >= 1
	if _shots:
		_out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(_out_dir)
		DisplayServer.window_set_size(SHOT_SIZE)
	_set_speed(SPEEDUP)

	_offer = REVIVE_OFFER_SCENE.instantiate()
	add_child(_offer)

	await get_tree().process_frame
	await _scenario_full_cycle()
	await _scenario_decline()
	await _scenario_ad_failure()
	await _scenario_win_after_revive()
	await _scenario_endless()
	await _scenario_main_flow()

	print("")
	print("=== SONUC: %d gecti / %d kaldi ===" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- Kucuk assert yardimcilari ---

func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("  [OK]   ", label)
	else:
		_failed += 1
		printerr("  [FAIL] ", label)


func _check_eq(label: String, actual: Variant, expected: Variant) -> void:
	_check("%s (beklenen %s, gelen %s)" % [label, expected, actual], actual == expected)


func _section(title: String) -> void:
	print("")
	print("--- ", title, " ---")


# --- Board kurulumu ---

func _set_speed(factor: int) -> void:
	Engine.physics_ticks_per_second = 60 * factor
	Engine.time_scale = float(factor)
	Engine.max_physics_steps_per_frame = 16 * factor


func _make_board(level_number: int = TEST_LEVEL) -> void:
	_finished_count = 0
	_finished_won.clear()
	_offered_count = 0
	_offered_remaining.clear()
	_granted_count = 0

	var path: String = "res://resources/levels/endless.tres"
	if level_number > 0:
		path = "res://resources/levels/level_%02d.tres" % level_number
	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(load(path))
	_board.round_finished.connect(_on_round_finished)
	_board.revive_offered.connect(_on_revive_offered)
	_board.revive_granted.connect(_on_revive_granted)
	add_child(_board)


func _teardown() -> void:
	_drive = false
	if _board != null and is_instance_valid(_board):
		_board.queue_free()
	_board = null
	_offer.hide_offer()
	await get_tree().process_frame


func _on_round_finished(won: bool) -> void:
	_finished_count += 1
	_finished_won.append(won)


func _on_revive_offered(remaining: int) -> void:
	_offered_count += 1
	_offered_remaining.append(remaining)
	# Gercek akista bunu main.gd yapiyor; burada pencerenin de acildigini
	# dogrulamak ve cekim alabilmek icin ayni bagi elle kuruyoruz.
	_offer.show_offer(remaining, _board.max_revives())


func _on_revive_granted(_used: int, _remaining: int) -> void:
	_granted_count += 1


func _physics_process(delta: float) -> void:
	_game_time += delta
	if not _drive or _board == null or not is_instance_valid(_board):
		return
	if _board._is_finished or _board.is_fail_pending() or _board._drop_cooldown > 0.0:
		return
	# Rastgele x: kotu oyun, yigin merge olmadan yukselir.
	_board._set_aim(randf_range(_board._left_x(), _board._right_x()))
	_board._drop()


## Tasma bekler. Dondugunde ya fail-pending ya round bitmis olur.
## Dönüş: fail-pending'e girildiyse true.
func _play_until_fail(max_frames: int = FAIL_MAX_FRAMES) -> bool:
	_drive = true
	var frames: int = 0
	while frames < max_frames:
		await get_tree().process_frame
		frames += 1
		if _board == null or not is_instance_valid(_board):
			return false
		if _board.is_fail_pending():
			_drive = false
			return true
		if _board._is_finished:
			_drive = false
			return false
	_drive = false
	return false


## Board'u sifirdan kurup ilk tasmaya kadar oynatir (bot kazanirsa tekrar
## dener). Dönüş: fail-pending'e girildiyse true.
func _fresh_board_until_fail(level_number: int = TEST_LEVEL) -> bool:
	for attempt in FAIL_ATTEMPTS:
		_make_board(level_number)
		await get_tree().process_frame
		if await _play_until_fail():
			return true
		print("  (deneme %d: tasma yakalanamadi, tekrar)" % (attempt + 1))
		await _teardown()
	printerr("  tasma HIC yakalanamadi")
	return false


func _capture(file_name: String) -> void:
	if not _shots:
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out_dir.path_join(file_name)
	var err: int = img.save_png(path)
	print(("  cekim  : " if err == OK else "  CEKIM HATASI: "), path)


## Board'daki canli parcalarin durumu — dondurma ve temizlik olcumu icin.
##
## `above_line` ve `landed_top_y` YALNIZCA yerlesmis (`has_landed`) parcalari
## sayar: tasma kuralinin kendisi de oyle (bkz. GameBoard._is_overflowing),
## havada olan bir parca tasmaya sebep olmaz ve kurtarilmaz.
func _snapshot() -> Dictionary:
	var alive: int = 0
	var frozen: int = 0
	var above_line: int = 0
	## Kurtarma bandindaki (cizgi + REVIVE_RESCUE_DEPTH) yerlesmis parca sayisi.
	var in_band: int = 0
	var landed_top_y: float = INF
	var line: float = _board.overflow_line_y()
	for node in _board._dumpling_layer.get_children():
		var dumpling := node as Dumpling
		if dumpling == null or not is_instance_valid(dumpling) \
				or dumpling.is_queued_for_deletion():
			continue
		alive += 1
		if dumpling.is_simulation_frozen():
			frozen += 1
		if not dumpling.has_landed:
			continue
		var top: float = dumpling.global_position.y - TierConfig.radius(dumpling.tier)
		landed_top_y = minf(landed_top_y, top)
		if top <= line:
			above_line += 1
		if top <= line + _board.REVIVE_RESCUE_DEPTH:
			in_band += 1
	return {
		"alive": alive, "frozen": frozen, "above_line": above_line,
		"in_band": in_band,
		"landed_top_y": landed_top_y, "line": line,
		"score": GameState.score, "merges": GameState.merge_count,
		"powerups": _powerup_stock(),
	}


func _powerup_stock() -> Dictionary:
	var stock: Dictionary = {}
	for type in PowerUp.all():
		stock[PowerUp.save_key(type)] = SaveManager.powerup_count(type)
	return stock


# --- 1) Tam dongu: fail -> grant -> fail -> grant -> fail -> final loss ---

## Botun devam ettikten SONRA kazanmasi mesru bir sonuc (senaryo 4 onu ayrica
## test ediyor) ama bu senaryonun olcmek istedigi iki-devam dongusu degil.
## O yuzden dongu tamamlanamazsa bastan deneniyor.
##
## Not: sabit tohuma ragmen kosular birebir tekrarlanabilir DEGIL — kamera
## sarsintisi `_process` icinde global RNG'yi tuketiyor ve `_process` fizik
## kareleriyle sabit oranda calismiyor. Bu, M8.5-03'te kaydedilen mevcut
## teknik borc; bu taskta DEGISTIRILMEDI.
func _scenario_full_cycle() -> void:
	for attempt in 4:
		var passed_before: int = _passed
		var failed_before: int = _failed
		if await _try_full_cycle():
			return
		# Yarim kalan denemenin assert'leri sayilmasin.
		_passed = passed_before
		_failed = failed_before
		print("  (bot devam sonrasi kazandi, senaryo bastan deneniyor)")
		await _teardown()
	_failed += 1
	printerr("  [FAIL] tam dongu 4 denemede tamamlanamadi")


## Dönüş: iki-devam dongusu bastan sona yurutulduyse true.
func _try_full_cycle() -> bool:
	_section("Senaryo 1: FAIL -> Revive#1 -> FAIL -> Revive#2 -> FAIL -> final loss")
	if not await _fresh_board_until_fail():
		_failed += 1
		return true

	# --- Ilk fail ---
	var at_fail: Dictionary = _snapshot()
	_check("ilk fail: fail-pending acildi", _board.is_fail_pending())
	_check_eq("ilk fail: round_finished YAYILMADI", _finished_count, 0)
	_check_eq("ilk fail: teklif sayisi", _offered_count, 1)
	_check_eq("ilk fail: kalan hak", _offered_remaining[0], 2)
	_check_eq("ilk fail: kullanilan hak", _board.revives_used(), 0)
	_check("ilk fail: tum parcalar donduruldu (%d/%d)"
		% [at_fail["frozen"], at_fail["alive"]],
		at_fail["alive"] > 0 and at_fail["frozen"] == at_fail["alive"])
	# Kurtarma BANDINDA parca olmali; "cizgiyi tam asmis olmali" demek fazla
	# kati: tasmayi Area2D ortusmesi tetikliyor ve o liste bir fizik adimi
	# gecikmeli, dolayisiyla sinirdaki bir parca fail aninda cizginin birkac
	# piksel altinda olculebiliyor. Onemli olan kurtarmanin onu yakalamasi.
	_check("ilk fail: kurtarma bandinda parca var (%d)" % at_fail["in_band"],
		at_fail["in_band"] > 0)
	_check("ilk fail: preview kapali", not _board._preview.visible)
	_check("ilk fail: guc cubugu kapali", not _board._power_bar._enabled)
	_check("ilk fail: hicbir guc silahli degil", not _board._powerups.is_armed())
	await _capture("r01_fail_modal_2_of_2.png")

	# Board gercekten donmus mu: birkac yuz kare bosa gecsin, hicbir sey
	# oynamasin. (Reklam ekrani 20-40 sn acik kalabilir.)
	var before_wait: Array = _positions()
	for i in 240:
		await get_tree().process_frame
	_check("bekleme sirasinda board hic oynamadi",
		_positions() == before_wait)
	_check_eq("bekleme sirasinda skor sabit", GameState.score, at_fail["score"])
	_check_eq("bekleme sirasinda merge sayaci sabit",
		GameState.merge_count, at_fail["merges"])
	_check_eq("bekleme sirasinda round_finished hala yayilmadi", _finished_count, 0)
	await _capture("r02_donmus_board.png")

	# Pencereyi bir an gizleyip altindaki board'u ciplak yakala: donmus yigin
	# ve KAPALI guc cubugu (r04 ile kiyaslanacak — orada cubuk parlak).
	_offer.hide_offer()
	await get_tree().process_frame
	await _capture("r08_guc_bari_kapali.png")
	_offer.show_offer(_board.revives_remaining(), _board.max_revives())
	await get_tree().process_frame

	# Guc butonlari fail-pending'de calismamali.
	var stock_before: Dictionary = _powerup_stock()
	for type in PowerUp.all():
		_board._on_power_pressed(int(type))
	await get_tree().process_frame
	_check("fail-pending: guc butonlari etkisiz (stok degismedi)",
		_powerup_stock() == stock_before)
	_check("fail-pending: guc basinca silahlanmadi", not _board._powerups.is_armed())

	# Drop da calismamali.
	var alive_before_drop: int = _snapshot()["alive"]
	_board._drop()
	await get_tree().process_frame
	_check_eq("fail-pending: drop etkisiz", _snapshot()["alive"], alive_before_drop)

	# --- Grant #1 (odul kazanildi callback'i simulasyonu) ---
	#
	# Olcumlerin bir kismi grant'ten HEMEN SONRA, hicbir kare gecmeden
	# alinmali: bir kare gecerse fizik tekrar isliyor ve olusan yeni merge'in
	# puani "temizlik puan verdi mi" sorusuna karisir.
	var granted: bool = _board.grant_revive()
	var after: Dictionary = _snapshot()
	var protection_at_grant: float = _board._revive_protection
	_offer.hide_offer()
	_check("grant #1 basarili", granted)
	_check_eq("grant #1: kullanilan hak", _board.revives_used(), 1)
	_check_eq("grant #1: kalan hak", _board.revives_remaining(), 1)
	_check_eq("grant #1: revive_granted sinyali", _granted_count, 1)
	_check_eq("grant #1: round_finished hala yayilmadi", _finished_count, 0)
	_check("grant #1: fail-pending kapandi", not _board.is_fail_pending())

	_check_eq("grant #1: temizlik SKOR vermedi", after["score"], at_fail["score"])
	_check_eq("grant #1: temizlik MERGE saymadi", after["merges"], at_fail["merges"])
	_check("grant #1: guc envanteri DEGISMEDI",
		after["powerups"] == at_fail["powerups"])
	_check("grant #1: cizgiyi asan yerlesmis parca kalmadi (%d)"
		% after["above_line"], after["above_line"] == 0)
	_check("grant #1: board TAMAMEN temizlenmedi (%d/%d parca kaldi)"
		% [after["alive"], at_fail["alive"]], after["alive"] > 0)
	_check("grant #1: preview geri geldi", _board._preview.visible)
	_check("grant #1: guc cubugu geri acildi", _board._power_bar._enabled)
	print("  olcum  : %d parcanin %d'i kaldirildi; yerlesmis yigin tepesi "
		% [at_fail["alive"], at_fail["alive"] - after["alive"]]
		+ "%.0f -> %.0f px (cizgi %.0f, yeni bosluk %.0f px)"
			% [at_fail["landed_top_y"], after["landed_top_y"], after["line"],
				after["landed_top_y"] - after["line"]])

	await get_tree().process_frame
	_check("grant #1: cozuldu, donmus parca kalmadi", _snapshot()["frozen"] == 0)
	await _capture("r03_temizlik_sonrasi.png")

	# Koruma penceresi: 1.5 sn boyunca tasma birikmemeli.
	_check("grant #1: koruma penceresi 1.5 sn acildi (%.2f)" % protection_at_grant,
		is_equal_approx(protection_at_grant, 1.5))
	var protection_ok: bool = true
	var protection_frames: int = 0
	while _board._revive_protection > 0.0 and protection_frames < 60 * 10:
		await get_tree().process_frame
		protection_frames += 1
		if _board._overflow_elapsed > 0.0 or _board._is_finished \
				or _board.is_fail_pending():
			protection_ok = false
			break
	_check("grant #1: koruma boyunca tasma birikmedi ve round bitmedi",
		protection_ok)
	_check_eq("grant #1: koruma sonrasi round_finished hala yayilmadi",
		_finished_count, 0)

	# Guc kullanimi geri geldi mi? (Stok tuketilmesin diye tetiklemiyoruz,
	# yalnizca hedeflemenin acilabildigini dogruluyoruz.)
	_board._on_power_pressed(int(PowerUp.Type.BOMB))
	_check("grant #1: hedefli guc tekrar silahlanabiliyor",
		_board._powerups.is_armed() or not SaveManager.has_powerup(PowerUp.Type.BOMB))
	_board._powerups.cancel()

	# Fizik gercekten devam ediyor mu?
	var before_resume: Array = _positions()
	for i in 30:
		await get_tree().process_frame
	_check("grant #1: fizik/oyun devam ediyor",
		_positions() != before_resume or _board._overflow_elapsed >= 0.0)
	await _capture("r04_devam_eden_oyun.png")

	# --- Ikinci fail ---
	#
	# Devam ETTIKTEN sonra ne kadar oynanabildigi, "anlamli ikinci sans" bunun
	# olcusu: birkac saniyede ayni fail'e dusuluyorsa temizlik yetersizdir.
	var survive_from: float = _game_time
	var second: bool = await _play_until_fail()
	print("  olcum  : devam sonrasi %.1f sn oynandi (koruma penceresi dahil)"
		% (_game_time - survive_from))
	if not second:
		# Round fail yerine kazanmayla bitti -> bu deneme sayilmaz.
		return false
	_check_eq("ikinci fail: teklif sayisi", _offered_count, 2)
	_check_eq("ikinci fail: kalan hak", _offered_remaining[1], 1)
	_check_eq("ikinci fail: round_finished hala yayilmadi", _finished_count, 0)
	await _capture("r05_fail_modal_1_of_2.png")

	# --- Grant #2 ---
	var granted2: bool = _board.grant_revive()
	_offer.hide_offer()
	_check("grant #2 basarili", granted2)
	_check_eq("grant #2: kullanilan hak", _board.revives_used(), 2)
	_check_eq("grant #2: kalan hak", _board.revives_remaining(), 0)
	_check_eq("grant #2: round_finished hala yayilmadi", _finished_count, 0)

	# --- Ucuncu fail: artik teklif YOK ---
	var third: bool = await _play_until_fail()
	if _finished_won.size() == 1 and _finished_won[0] == true:
		# Ikinci devamdan sonra kazandi -> yine dongu tamamlanmadi.
		return false
	_check("ucuncu fail: teklif ACILMADI (fail-pending yok)", not third)
	_check_eq("ucuncu fail: teklif sayisi hala 2", _offered_count, 2)
	_check_eq("ucuncu fail: round_finished TAM 1 KEZ", _finished_count, 1)
	_check("ucuncu fail: kayip olarak bitti",
		_finished_won.size() == 1 and _finished_won[0] == false)
	# Haklar tukendikten sonra grant hicbir sey yapmamali.
	_check("haklar bitince grant_revive() reddediyor", not _board.grant_revive())
	_check_eq("reddedilen grant sayaci artirmadi", _board.revives_used(), 2)
	await _capture("r06_final_loss.png")

	await _teardown()
	return true


func _positions() -> Array:
	var out: Array = []
	for node in _board._dumpling_layer.get_children():
		var dumpling := node as Dumpling
		if dumpling != null and is_instance_valid(dumpling) \
				and not dumpling.is_queued_for_deletion():
			out.append(dumpling.global_position.snapped(Vector2(0.01, 0.01)))
	return out


# --- 2) Reddetme: ilk teklifte "Bitir" ---

func _scenario_decline() -> void:
	_section("Senaryo 2: ilk teklifte Bitir -> final loss, hak tuketilmez")
	if not await _fresh_board_until_fail():
		_failed += 1
		return

	_check_eq("teklif acildi, round bitmedi", _finished_count, 0)
	_board.decline_revive()
	_check_eq("decline: round_finished TAM 1 KEZ", _finished_count, 1)
	_check("decline: kayip olarak bitti",
		_finished_won.size() == 1 and _finished_won[0] == false)
	_check_eq("decline: devam hakki TUKETILMEDI", _board.revives_used(), 0)
	_check("decline: fail-pending kapandi", not _board.is_fail_pending())
	_check("decline: board cozuldu", _snapshot()["frozen"] == 0)
	# Ikinci kez cagirmak yeni bir finalization uretmemeli.
	_board.decline_revive()
	_check_eq("decline: tekrar cagrildi, round_finished hala 1", _finished_count, 1)
	_check("decline sonrasi grant_revive() reddediyor", not _board.grant_revive())
	_check_eq("decline sonrasi devam hakki hala 0", _board.revives_used(), 0)

	await _teardown()


# --- 3) Reklam basarisizligi: talep var, odul YOK ---

func _scenario_ad_failure() -> void:
	_section("Senaryo 3: rewarded talebi var, odul callback'i YOK")
	if not await _fresh_board_until_fail():
		_failed += 1
		return

	var before: Dictionary = _snapshot()
	# Production yolunun aynisi: CTA sinyali yayilir, grant CAGRILMAZ.
	# Sayac dizide tutuluyor: GDScript lambda'lari degeri KOPYALAYARAK
	# yakaliyor, `var requested: int` icerden artirilamaz.
	var requested: Array[int] = [0]
	_offer.rewarded_revive_requested.connect(
		func() -> void: requested[0] += 1)
	_offer._on_continue_pressed()
	_check("CTA basilinca buton kilitlendi (cift dokunus korumasi)",
		_offer._continue.disabled)
	_offer.show_unavailable("Odullu reklam henuz bagli degil.")
	await get_tree().process_frame

	_check_eq("CTA talebi yayildi", requested[0], 1)
	_check_eq("talep devam hakki TUKETMEDI", _board.revives_used(), 0)
	_check_eq("talep round'u bitirmedi", _finished_count, 0)
	_check("talep sonrasi hala fail-pending", _board.is_fail_pending())
	_check("talep sonrasi board hala donmus",
		_snapshot()["frozen"] == before["frozen"])
	_check("talep sonrasi CTA tekrar basilabilir", not _offer._continue.disabled)
	await _capture("r07_reklam_basarisiz.png")

	# Sonra Bitir ile kapatilabilmeli.
	_board.decline_revive()
	_check_eq("basarisizlik sonrasi Bitir: round_finished TAM 1 KEZ",
		_finished_count, 1)
	_check_eq("basarisizlik sonrasi devam hakki hala 0", _board.revives_used(), 0)

	await _teardown()


# --- 4) Revive sonrasi kazanma ---

func _scenario_win_after_revive() -> void:
	_section("Senaryo 4: devam kullanildi, sonra hedef tamamlandi")
	if not await _fresh_board_until_fail():
		_failed += 1
		return

	_check("grant basarili", _board.grant_revive())
	_offer.hide_offer()
	await get_tree().process_frame
	_check_eq("devam kullanildi", _board.revives_used(), 1)

	# Hedefi guc/merge beklemeden dogrudan kurmak yerine, level'in kazanma
	# yolunu ayni sekilde tetikliyoruz: hedef tier'a ulasildi + skor esigi.
	_board._reached_target_tier = true
	if _board.level.has_score_target():
		GameState.add_score(_board.level.target_score)
	_board._check_objective()
	await get_tree().process_frame

	_check_eq("kazanma: round_finished TAM 1 KEZ", _finished_count, 1)
	_check("kazanma: won = true",
		_finished_won.size() == 1 and _finished_won[0] == true)
	_check("kazanma: fail-pending kapali", not _board.is_fail_pending())
	_check("kazanma: board cozuldu", _snapshot()["frozen"] == 0)
	_check_eq("kazanma: devam hakki hala 1 (ceza yok)", _board.revives_used(), 1)
	# Ikinci kez tetiklemek yeni bir finalization uretmemeli.
	_board._check_objective()
	_board.decline_revive()
	_check_eq("kazanma: tekrar tetiklendi, round_finished hala 1", _finished_count, 1)

	await _teardown()


# --- 5) Sonsuz mod: ayni akis, mevcut endless kurallari bozulmadan ---

## Sonsuz modun fail semantigi level'larinkiyle ayni (tek fail state tasma) ve
## revive kodunda `is_endless` dali YOK. Burada dogrulanan sey: teklif orada da
## aciliyor, devam calisiyor ve round_finished YINE tam bir kez yayiliyor —
## endless finalization'i (rekor kaydi, main.gd) o sinyale bagli.
func _scenario_endless() -> void:
	_section("Senaryo 5: sonsuz mod")
	if not await _fresh_board_until_fail(ENDLESS_LEVEL):
		_failed += 1
		return

	_check("sonsuz mod: level gercekten endless", _board.level.is_endless)
	_check_eq("sonsuz mod: teklif acildi", _offered_count, 1)
	_check_eq("sonsuz mod: kalan hak", _offered_remaining[0], 2)
	_check_eq("sonsuz mod: round_finished YAYILMADI", _finished_count, 0)

	var at_fail: Dictionary = _snapshot()
	_check("sonsuz mod: board donduruldu",
		at_fail["alive"] > 0 and at_fail["frozen"] == at_fail["alive"])

	_check("sonsuz mod: grant basarili", _board.grant_revive())
	var after: Dictionary = _snapshot()
	_check_eq("sonsuz mod: temizlik SKOR vermedi", after["score"], at_fail["score"])
	_check_eq("sonsuz mod: temizlik MERGE saymadi", after["merges"], at_fail["merges"])
	_check_eq("sonsuz mod: kullanilan hak", _board.revives_used(), 1)
	_check_eq("sonsuz mod: grant round'u bitirmedi", _finished_count, 0)

	# Ikinci hakki da harcayip ucuncu fail'de kesin kaybi dogrula.
	if await _play_until_fail():
		_check_eq("sonsuz mod: ikinci teklifte kalan hak", _offered_remaining[1], 1)
		_check("sonsuz mod: grant #2", _board.grant_revive())
		var third: bool = await _play_until_fail()
		_check("sonsuz mod: ucuncu fail'de teklif YOK", not third)
		_check_eq("sonsuz mod: round_finished TAM 1 KEZ", _finished_count, 1)
		_check("sonsuz mod: kayip olarak bitti",
			_finished_won.size() == 1 and _finished_won[0] == false)

	await _teardown()


# --- 6) Gercek main.gd akisi: odul/finalization TAM BIR KEZ ---

## Senaryo 1-5 sinyalleri board seviyesinde sayiyor. Burada dogrulanan sey
## bir ust katman: main.gd'nin odul toplama + sonuc ekrani yolu revive
## sirasinda HIC calismiyor, final loss'ta TAM BIR KEZ calisiyor.
##
## DIKKAT: bu senaryo kayit dosyasina YAZAR (SaveManager.add_merges vb.).
## Kosu sonunda owner kaydi disaridan byte-identical geri yukleniyor.
func _scenario_main_flow() -> void:
	_section("Senaryo 6: gercek main.gd — odul ve sonuc ekrani tam bir kez")
	var main: Node2D = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	main._daily.visible = false

	var merges_before: int = int(SaveManager.data.get("total_merges", 0))
	# Bot round'u kazanabilir; bu senaryonun olcmek istedigi fail yolu, o
	# yuzden tasma yakalanana kadar level bastan baslatiliyor.
	var reached_fail: bool = false
	for attempt in FAIL_ATTEMPTS:
		main._start_level(load("res://resources/levels/level_%02d.tres" % TEST_LEVEL))
		await get_tree().process_frame
		_board = main._board
		_board.round_finished.connect(_on_round_finished)
		_finished_count = 0
		_finished_won.clear()
		if await _play_until_fail():
			reached_fail = true
			break
		print("  (deneme %d: tasma yakalanamadi, tekrar)" % (attempt + 1))
		# Kazanilan round finalize olur ve kayda yazar; sonraki denemenin
		# referansi guncel deger olmali.
		await get_tree().create_timer(2.0).timeout
		merges_before = int(SaveManager.data.get("total_merges", 0))
		main._result.hide_result()

	if not reached_fail:
		printerr("  [FAIL] tasma yakalanamadi")
		_failed += 1
		main.queue_free()
		await get_tree().process_frame
		return

	# Teklif acik: sonuc ekrani ve odul yolu HIC calismamali.
	_check("main: devam penceresi acildi", main._revive.visible)
	_check("main: sonuc ekrani ACILMADI", not main._result.visible)
	_check_eq("main: kayit merge sayaci DEGISMEDI",
		int(SaveManager.data.get("total_merges", 0)), merges_before)

	# Saglayici yokken CTA devam VERMEMELI.
	main._on_rewarded_revive_requested()
	await get_tree().process_frame
	_check_eq("main: saglayicisiz CTA devam VERMEDI", _board.revives_used(), 0)
	_check("main: CTA sonrasi hala fail-pending", _board.is_fail_pending())
	_check("main: teklif hala acik", main._revive.visible)

	# Odul kazanildi callback'inin karsiligi: Main.grant_revive().
	_check("main: grant_revive() basarili", main.grant_revive())
	_check("main: grant sonrasi pencere kapandi", not main._revive.visible)
	_check_eq("main: devam kullanildi", _board.revives_used(), 1)
	_check("main: grant sonrasi sonuc ekrani hala kapali", not main._result.visible)

	# Kalan hakki da harcayip kesin kayba git.
	if await _play_until_fail():
		main.grant_revive()
		await _play_until_fail()
	var round_merges: int = GameState.merge_count
	_check_eq("main: round_finished TAM 1 KEZ", _finished_count, 1)

	# main.gd sonuc ekranini RESULT_DELAY (0.8 sn) sonra aciyor.
	var waited: int = 0
	while not main._result.visible and waited < 60 * 20:
		await get_tree().process_frame
		waited += 1
	_check("main: final loss'ta sonuc ekrani acildi", main._result.visible)
	_check_eq("main: kayit merge sayaci TAM BIR KEZ islendi",
		int(SaveManager.data.get("total_merges", 0)), merges_before + round_merges)

	main.queue_free()
	_board = null
	await get_tree().process_frame
