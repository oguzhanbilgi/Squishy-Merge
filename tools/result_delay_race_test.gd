extends Node
## TASK/048 — Normal RESULT_DELAY eski sonuç yarışı: gecikmeli NORMAL sonuç / geçiş reklamı yalnız
## kendisini zamanlayan round'a aittir. Gerçek Main, gerçek board, sahte reklam arka ucu. Headless.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_result_delay_race/` altındaki
## bir yola yönlendirilir, sonda geri alınır; gerçek kayıt ailesi başta / sonda karşılaştırılır.
##
##   godot --headless --audio-driver Dummy --path . res://tools/result_delay_race_test.tscn
##
## Yarışın üretim yolu (PROJECT_STATUS §4.24): Büyütücü dönüşümü board'a bağlı bir tween'dir ve mola
## dondurmasında da tamamlanır — mola açıkken hedefe ulaşan dönüşüm round'u bitirir, sonuç RESULT_DELAY
## (0,8 sn) sonra açılır; bu arada açık molanın "Yeniden Başlat" / "Ana Menüye Dön"ü round'u değiştirir.
## Kayıp / Sonsuz bitişi molada OLUŞAMAZ (taşma sayacı donukken ilerlemez; bitişten sonra mola açılmaz)
## — o yollar aynı üretim işleyicisiyle (mola Yeniden Başlat işleyicisi, QA kancası) sınanır.
##
## Zaman: "gecikmeden sonra" denetimleri Main'in KENDİ saatine bağlıdır — her izlenen bitişte (round_finished
## yayımında, Main'in zamanlayıcısından hemen SONRA) aynı süreli bir SceneTree zamanlayıcısı kurulur; o
## dolduğunda Main'in gecikmeli kodu aynı karede zaten çalışmıştır (duvar saati / kare süresi farkı yok).
##
## Bölümler:
##   A geçerli    değiştirilmeyen kazanma / kayıp: ilerleme bir kez, sonuç gecikmeden sonra TAM bir kez;
##                gecikme içinde arka plan + öne dönüş round'u değiştirmez
##   B yeniden    GERÇEK dokunuş: Büyütücü düğmesi + hedef + HUD geri (mola) + "Yeniden Başlat" gecikme
##                içinde → eski sonuç açılmaz, dokunuş yeni board'a sızmaz, yeni board örtülmez, dokunuş
##                alır, kendi sonucunu sonra açar
##   C Ana Sayfa  gerçek "Ana Menüye Dön" + Android geri → Ana Sayfa'da sonuç / geçiş reklamı yok
##   D level      gecikme içinde Harita'dan başka sabit level → eski sonuç bastırılır
##   E sonsuz     gecikme içinde Sonsuz → eski sonuç bastırılır
##   F meydan     gecikme içinde meydan okuma → eski normal sonuç (reklamsız — üretimin olağan durumu) ve
##                eski geçiş reklamı (reklam uygunken) yok; meydan okuma sonucu aynen
##   G yeni       A (level 5 ilk kazanma) bitti → B (yeniden başlatılan) A'nın gecikmesi bitmeden bitti: A
##                hiç, B tam bir kez — B'nin sonucu (kilit rozeti YOK) A'nınkinden (kilit rozeti) ayrılır
##   H çoklu      iki eski devam aynı anda bekler: ikisi de ölü, yalnız güncel nesil sunar
##   I ilerleme   meşru kesinleşme bir kez (geri alma yok, çift yok), yeni round güncel ilerlemeden
##   J kayıp      kayıp kesinleşti → değiştirildi: eski kayıp sonucu yok, teselli bir kez
##   K sonsuz     geçerli Sonsuz sonucu aynen; değiştirilen Sonsuz'un sonucu bastırılır
##   L tutorial   tutorial adımları / geri onayı / ATLA nesli değiştirmez; tutorial round sonucu açılır
##   M nesil      board değişimi (yeni / yeniden / terk / çıkış) ilerletir; mola / Ayarlar / öne dönüş /
##                sekme / sonuç sunumu ilerletmez; eski nesil reddedilir; yalnız bellekte
##   N reklam     geçerli normal sonuç geçiş reklamı yolu aynen (arka plan / öne dönüş dahil); eski round
##                reklam DENEMEZ; reklam açıkken değiştirilen round'un sonucu kapanışta / gösterim hatasında
##                açılmaz ve yönetici temiz kalır; meydan okuma hiç denemez
##   O kaynak     RESULT_DELAY 0,8 / 300 ms / iptal koruması aynen; nesil tek noktada; kayıt şeması aynı

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const ENDLESS: String = "res://resources/levels/endless.tres"
const DIR: String = "user://qa_result_delay_race"
const PATH: String = DIR + "/save.json"
const SECTIONS: int = 15
const MON: String = "2026-09-28"
const THU: String = "2026-10-01"
const BACK_GAP_MSEC: int = 320

var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _finished: bool = false
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _main: Node2D
var _main_script: GDScript
## Sonuç ekranının görünür olduğu geçişler (boot başına sıfırlanır).
var _shows: int = 0
## İzlenen board'ların bırakışları.
var _drops: int = 0
## Son izlenen bitişin izleyici zamanlayıcısı (Main'in RESULT_DELAY'iyle aynı saat) ve duvar saati anları.
var _last_timer: SceneTreeTimer = null
var _finish_msec: int = -1
var _pause_msec: int = -1
var _replace_msec: int = -1
## Değiştirme anında son bitişin gecikmesinden kalan süre (Main'in saatiyle; > 0 = gecikme içinde).
var _replace_left: float = -1.0
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
	await get_tree().process_frame

	await _valid_results()
	await _restart_real_input()
	await _home()
	await _fixed_to_fixed()
	await _fixed_to_endless()
	await _fixed_to_challenge()
	await _newer_beats_older()
	await _multiple_stale()
	await _progression()
	await _loss_replaced()
	await _endless()
	await _tutorial()
	await _generation()
	await _ads()
	_source_contract()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	print("-- kayıt")
	await _teardown_main()
	_teardown()
	_c("SaveManager gerçek yola döndü, test klasörü silindi, saat kancası boş",
		SaveManager.save_path == SaveManager.SAVE_PATH and not DirAccess.dir_exists_absolute(DIR)
		and DailyRewards.clock_override == "")
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
	DailyRewards.clock_override = ""
	DailyRewards.auto_popup_enabled = false
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	UiKit.set_banner_slot(0.0)
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- A) Geçerli sonuç -------------------------------------------------------------------------------------

func _valid_results() -> void:
	print("-- A: değiştirilmeyen round — sonuç gecikmeden sonra TAM bir kez")
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var rounds: int = _rounds()
	var seq: int = _main._result_seq
	await _finish_now(board)
	var timer: SceneTreeTimer = _last_timer
	_c("ön koşul: kazanma kesinleşti (gerçek Büyütücü dönüşümü hedefe ulaştı)", board.is_finished() and timer != null)
	_c("kesinleşme gecikmeden ÖNCE yazdı: tur + 1", _rounds() == rounds + 1)
	await _until_left(timer, 0.25)
	_c("gecikme sürerken sonuç henüz yok", not _main._result.visible and timer.time_left > 0.0)
	await _after(timer)
	_c("gecikmeden sonra kazanma sonucu açıldı: mod WIN, kendi level'ı (3), tam bir kez (seq + 2)",
		_main._result.visible and _main._result.mode() == _mode("WIN") and _shown_level() == 3
		and _shows == 1 and _main._result_seq == seq + 2)
	_c("  … sonuç ekranı kayda yazmadı (tur hâlâ + 1)", _rounds() == rounds + 1)

	_main._on_retry_pressed()
	await _settle(3)
	board = _main._board
	_track(board)
	_shows = 0
	seq = _main._result_seq
	await _finish_now(board)
	timer = _last_timer
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)
	await _settle(2)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)
	await _settle(2)
	_c("kurulum: kazanma kesinleşti, gecikme İÇİNDE uygulama arka plana gidip döndü (board aynı)",
		board.is_finished() and timer.time_left > 0.0 and _main._board == board)
	await _after(timer)
	_c("arka plan / öne dönüş round'u değiştirmez: sonuç TAM bir kez (seq + 2)", _main._result.visible
		and _shows == 1 and _main._result_seq == seq + 2)

	_main._on_retry_pressed()
	await _settle(3)
	board = _main._board
	_track(board)
	_shows = 0
	seq = _main._result_seq
	rounds = _rounds()
	await _loss(board)
	timer = _last_timer
	_c("kayıp kesinleşti (devam reddi — üretim yolu): tur + 1", board.is_finished() and timer != null
		and _rounds() == rounds + 1)
	_main.open_pause_menu()
	await _settle(1)
	_c("RESULT_DELAY aralığında mola AÇILMAZ (mevcut kilit aynen)", not _main.is_pause_open())
	await _after(timer)
	_c("geçerli kayıp sonucu açıldı: mod FAIL, level 3, tam bir kez", _main._result.visible
		and _main._result.mode() == _mode("FAIL") and _shown_level() == 3 and _shows == 1 and _main._result_seq == seq + 2)
	_sections_done += 1


# --- B) Gerçek dokunuşla yeniden başlatma ------------------------------------------------------------------

func _restart_real_input() -> void:
	print("-- B: GERÇEK dokunuş — Büyütücü düğmesi + hedef + HUD geri (mola) + 'Yeniden Başlat' gecikme içinde")
	await _fresh()
	var board: Node2D = null
	var ok: bool = false
	var attempts: int = 0
	while not ok and attempts < 3:
		attempts += 1
		board = await _start(_level(3))
		await _wait_settled()
		if attempts == 1:
			# Isınma: düğme + dönüşüm efektinin ilk kullanımı (hedefin altında — round bitmez).
			var warm: Dumpling = await _piece(board, 2)
			await _fire_upgrade(board, warm, true)
			await _wait(0.4)
		ok = await _finish_under_pause(board, true)
	var timer: SceneTreeTimer = _last_timer
	_c("kurulum (gerçek dokunuş, %d deneme): Büyütücü düğmesi + hedefe basış, HUD geri molayı bitişten ÖNCE açtı, " % attempts
		+ "dönüşüm round'u molada bitirdi, mola açık", ok)
	if not ok:
		_sections_done += 1
		return
	var seq: int = _main._result_seq
	var rounds: int = _rounds()
	var board_id: int = board.get_instance_id()
	await _wait_until(_pause_msec + 350)
	var replacement: Node2D = await _restart_via_pause(true)
	_c("gerçek 'Yeniden Başlat' dokunuşu gecikme İÇİNDE yeni board kurdu (bitişten %d ms; Main'in gecikmesinden %.2f sn kalmıştı)"
		% [_replace_msec - _finish_msec, _replace_left], _differs(replacement, board_id) and _replace_left > 0.0
		and not _main._result.visible)
	_c("  … yeniden başlatma dokunuşu yeni board'a sızmadı (yeni board boş — bırakış yok)", replacement != null
		and replacement.live_dumplings().is_empty())
	await _after(timer)
	_c("eski round'un gecikmesi doldu: ESKİ sonuç yeni round'un üstüne AÇILMADI", not _main._result.visible
		and _shows == 0)
	if _abort_if_stale("B"):
		return
	_c("  … eski sunum hiç başlamadı (sonuç sırası aynı)", _main._result_seq == seq)
	_c("  … yeni board etkin: aynı board, bitmemiş, mola kapalı, donuk değil, devam / refill yok",
		_main._board == replacement and not replacement.is_finished() and not _main.is_pause_open()
		and not replacement._is_paused() and not _main._revive.visible and not _main._refill.visible)
	_c("  … yeni round'a dokunulmadı (tur aynı, kesinleşme bayrağı kapalı)", _rounds() == rounds and not _main._round_finalized)
	var dropped: bool = await _drop_ok(replacement)
	_c("  … yeni board GERÇEK dokunuşu aldı: tam 1 bırakış (dokunuş tüketilmedi)", dropped)
	await _finish_now(replacement)
	await _after(_last_timer)
	_c("yeni round kendi sonucunu normal açtı: mod WIN, level 3, tam bir kez", _main._result.visible
		and _main._result.mode() == _mode("WIN") and _shown_level() == 3 and _shows == 1
		and _main._result_seq == seq + 2)
	_sections_done += 1


# --- C) Ana Sayfa ----------------------------------------------------------------------------------------

func _home() -> void:
	print("-- C: gerçek 'Ana Menüye Dön' + Android geri gecikme içinde — Ana Sayfa'da sonuç / reklam yok")
	await _fresh(true)
	var ads: MonetizationManager = _main._ads
	var fake: FakeAdBackend = ads._backend
	_c("ön koşul: geçiş reklamı UYGUN + HAZIR (geçerli bir round bitişi gösterirdi)", ads.interstitial_eligible()
		and ads.is_interstitial_ready())
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var ok: bool = await _finish_under_pause(board, false)
	var timer: SceneTreeTimer = _last_timer
	var shows: int = fake.interstitial_shows.size()
	AdEvents.clear_recent()
	await _wait_until(_pause_msec + 350)
	await _finger_tap(_center(_main._pause.buttons()[2]))
	await _settle(2)
	_c("kurulum: kazanma molada kesinleşti; gerçek 'Ana Menüye Dön' gecikme içinde board'u kaldırdı → Harita", ok
		and _main._board == null and _main._active_tab == 1 and timer.time_left > 0.0)
	await _back()
	_c("  … Android geri → Ana Sayfa (gecikme hâlâ sürüyor)", _main._active_tab == 0 and _main._screens[0].visible
		and timer.time_left > 0.0)
	await _after(timer)
	_c("eski round'un gecikmesi doldu: Ana Sayfa'da sonuç AÇILMADI", not _main._result.visible and _shows == 0
		and _main._screens[0].visible and _main._active_tab == 0)
	_c("  … eski round geçiş reklamı DENEMEDİ (gösterim / atlama olayı yok), reklam uygun + hazır kaldı",
		fake.interstitial_shows.size() == shows and AdEvents.count(&"interstitial_skipped_not_ready") == 0
		and ads.interstitial_state() == MonetizationManager.InterstitialState.READY and ads.interstitial_eligible())
	_c("  … reklam yüzeyi HOME kaldı (RESULT'a geçmedi)", ads.surface() == MonetizationManager.Surface.HOME)
	await _wait_settled()
	await _finger_tap(_center(_main._screens[0].missions_button()))
	await _settle(2)
	_c("Ana Sayfa etkileşimli: GÖREVLER girişine gerçek dokunuş pencereyi açtı", _main._missions.visible)
	_sections_done += 1


# --- D) Başka sabit level -------------------------------------------------------------------------------

func _fixed_to_fixed() -> void:
	print("-- D: gecikme içinde Harita'dan başka sabit level")
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var ok: bool = await _finish_under_pause(board, false)
	var timer: SceneTreeTimer = _last_timer
	var board_id: int = board.get_instance_id()
	_main._pause.exit_pressed.emit()
	await _settle(2)
	_main._screens[1].level_chosen.emit(_level(4))
	await _settle(3)
	var next: Node2D = _main._board
	_track(next)
	_c("kurulum: level 3 molada kesinleşti, gecikme içinde Harita kartı (level_chosen) level 4'ü başlattı", ok
		and _differs(next, board_id) and next.level.level_number == 4 and timer.time_left > 0.0)
	await _after(timer)
	_c("eski level 3 sonucu level 4'ün üstüne AÇILMADI", not _main._result.visible and _shows == 0)
	if _abort_if_stale("D"):
		return
	_c("  … level 4 etkin (bitmemiş, mola yok, donuk değil), kendi kesinleşmesi bekliyor", _main._board == next
		and not next.is_finished() and not _main.is_pause_open() and not next._is_paused() and not _main._round_finalized)
	await _wait_settled()
	var dropped: bool = await _drop_ok(next)
	_c("  … level 4 gerçek dokunuşu aldı: tam 1 bırakış", dropped)
	_sections_done += 1


# --- E) Sonsuz ---------------------------------------------------------------------------------------------

func _fixed_to_endless() -> void:
	print("-- E: gecikme içinde Sonsuz")
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var ok: bool = await _finish_under_pause(board, false)
	var timer: SceneTreeTimer = _last_timer
	var board_id: int = board.get_instance_id()
	_main._pause.exit_pressed.emit()
	await _settle(2)
	_main._screens[1].level_chosen.emit(load(ENDLESS))
	await _settle(3)
	var next: Node2D = _main._board
	_track(next)
	_c("kurulum: level 3 molada kesinleşti, gecikme içinde Sonsuz başladı", ok and _differs(next, board_id)
		and next.level.is_endless and timer.time_left > 0.0)
	await _after(timer)
	_c("eski level 3 sonucu Sonsuz'un üstüne AÇILMADI", not _main._result.visible and _shows == 0)
	if _abort_if_stale("E"):
		return
	_c("  … Sonsuz etkin (bitmemiş, mola yok, donuk değil)", _main._board == next and not next.is_finished()
		and not _main.is_pause_open() and not next._is_paused())
	await _wait_settled()
	var dropped: bool = await _drop_ok(next)
	_c("  … Sonsuz gerçek dokunuşu aldı: tam 1 bırakış", dropped)
	_sections_done += 1


# --- F) Meydan okuma ---------------------------------------------------------------------------------------

func _fixed_to_challenge() -> void:
	print("-- F: gecikme içinde Ana Sayfa → meydan okuma (çapraz kip)")
	# F1 — reklamsız (üretimde geçiş reklamı çoğu bitişte uygun değil: eski sonuç doğrudan sunulurdu).
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var ok: bool = await _cross_to_challenge(board)
	var timer: SceneTreeTimer = _last_timer
	var challenge: Node2D = _main._board
	_track(challenge)
	_c("F1 kurulum (reklamsız): normal kazanma molada kesinleşti, gecikme içinde Ana Sayfa → BAŞLA meydan okumayı başlattı",
		ok and challenge != null and challenge.is_daily_challenge() and timer.time_left > 0.0)
	await _after(timer)
	_c("F1: eski NORMAL sonuç meydan okumanın üstüne AÇILMADI", not _main._result.visible and _shows == 0)
	if not _main._result.visible:
		_c("  … F1: meydan okuma etkin (bitmemiş, mola yok), round türü DAILY_CHALLENGE", _main._board == challenge
			and not challenge.is_finished() and not _main.is_pause_open() and _main.is_daily_challenge_round())
	# F2 — reklam uygun + hazır: eski round geçiş reklamı da denemez; meydan okuma sonucu aynen.
	await _fresh(true)
	var ads: MonetizationManager = _main._ads
	var fake: FakeAdBackend = ads._backend
	board = await _start(_level(3))
	await _wait_settled()
	var shows: int = fake.interstitial_shows.size()
	AdEvents.clear_recent()
	ok = await _cross_to_challenge(board)
	timer = _last_timer
	challenge = _main._board
	_track(challenge)
	_c("F2 kurulum (reklam uygun): gecikme içinde meydan okuma başladı", ok and challenge != null
		and challenge.is_daily_challenge() and timer.time_left > 0.0)
	await _after(timer)
	_c("F2: eski NORMAL sonuç meydan okumanın üstüne AÇILMADI", not _main._result.visible and _shows == 0)
	_c("  … F2: eski normal round geçiş reklamı DENEMEDİ, yüzey GAMEPLAY kaldı", fake.interstitial_shows.size() == shows
		and AdEvents.count(&"interstitial_skipped_not_ready") == 0
		and ads.interstitial_state() == MonetizationManager.InterstitialState.READY
		and ads.surface() == MonetizationManager.Surface.GAMEPLAY)
	if _abort_if_stale("F"):
		return
	_c("  … meydan okuma etkin (bitmemiş, mola yok), round türü DAILY_CHALLENGE", _main._board == challenge
		and not challenge.is_finished() and not _main.is_pause_open() and _main.is_daily_challenge_round())
	await _wait_settled()
	var dropped: bool = await _drop_ok(challenge)
	_c("  … meydan okuma gerçek dokunuşu aldı: tam 1 bırakış, bütçeden 1", dropped and challenge.drops_used() == 1)
	var dough: int = SaveManager.dough()
	_shows = 0
	var challenge_shows: int = fake.interstitial_shows.size()
	AdEvents.clear_recent()
	await _win_merge(challenge)
	await _after(_last_timer)
	_c("meydan okuma sonucu aynen: CHALLENGE_WIN, tam bir kez, +20 Hamur bir kez", _main._result.visible
		and _main._result.mode() == _mode("CHALLENGE_WIN") and _shows == 1 and SaveManager.dough() == dough + 20
		and SaveManager.daily_challenge_completed_day() == THU)
	_c("  … meydan okuma bitişi geçiş reklamı DENEMEDİ (TASK/047 aynen)", fake.interstitial_shows.size() == challenge_shows
		and AdEvents.count(&"interstitial_skipped_not_ready") == 0)
	_sections_done += 1


## Mola açıkken kazanma → Ana Menüye Dön → Ana Sayfa → BAŞLA (sayfanın gösterdiği gün) — hepsi üretim işleyicisi.
func _cross_to_challenge(board: Node2D) -> bool:
	var ok: bool = await _finish_under_pause(board, false)
	_main._pause.exit_pressed.emit()
	await _settle(2)
	_main._show_tab(0)
	await _settle(2)
	_main._on_challenge_start_requested(THU)
	await _settle(3)
	return ok and _main.is_daily_challenge_round()


# --- G) Yeni sonuç eskisini yener ----------------------------------------------------------------------

func _newer_beats_older() -> void:
	print("-- G: A kesinleşti → B değiştirdi ve A'nın gecikmesi bitmeden kesinleşti")
	await _fresh()
	var a: Node2D = await _start(_level(5))
	await _wait_settled()
	var ok: bool = await _finish_under_pause(a, false)
	var ta: SceneTreeTimer = _last_timer
	var seq: int = _main._result_seq
	var a_id: int = a.get_instance_id()
	var b: Node2D = await _restart_via_pause(false)
	var b_new: bool = _differs(b, a_id)
	await _finish_now(b, 4)
	var tb: SceneTreeTimer = _last_timer
	_c("kurulum: A (level 5 ilk kazanma — level 6 açıldı) molada, B (yeniden başlatılan) A'nın gecikmesi içinde kesinleşti",
		ok and b_new and b.is_finished() and tb != ta and ta.time_left > 0.0 and SaveManager.highest_level_unlocked() == 6)
	await _after(ta)
	_c("A'nın gecikmesi doldu (B'ninki sürüyor): A'nın sonucu AÇILMADI", not _main._result.visible and _shows == 0
		and tb.time_left > 0.0)
	if _abort_if_stale("G"):
		return
	await _after(tb)
	_c("B'nin gecikmesi doldu: B'nin sonucu TAM bir kez (mod WIN, level 5)", _main._result.visible and _shows == 1
		and _main._result.mode() == _mode("WIN") and _shown_level() == 5 and _main._result_seq == seq + 2)
	_c("  … açılan sonuç B'nin: kilit rozeti YOK (A'nın sonucu 'LEVEL 6 AÇILDI' rozeti taşırdı)",
		_main._result.unlock_badge() == null and _main._result.unlock_text() == "")
	await _wait(0.9)
	_c("  … sonra da ikinci (A) sunumu yok", _shows == 1 and _main._result_seq == seq + 2 and _main._result.visible)
	_sections_done += 1


# --- H) Çoklu eski devam --------------------------------------------------------------------------------

func _multiple_stale() -> void:
	print("-- H: iki eski devam (A, B) aynı anda bekler, C güncel")
	await _fresh()
	var a: Node2D = await _start(_level(3))
	await _wait_settled()
	var ok_a: bool = await _finish_under_pause(a, false)
	var ta: SceneTreeTimer = _last_timer
	var seq: int = _main._result_seq
	var a_id: int = a.get_instance_id()
	var b: Node2D = await _restart_via_pause(false)
	var b_new: bool = _differs(b, a_id)
	var ok_b: bool = false
	if b_new:
		ok_b = await _finish_under_pause(b, false, 4)
	var tb: SceneTreeTimer = _last_timer
	var b_id: int = b.get_instance_id() if b_new else 0
	var c: Node2D = await _restart_via_pause(false)
	var c_new: bool = _differs(c, b_id)
	_c("kurulum: A ve B molada kesinleşti, C ikisinin de gecikmesi içinde başladı (A'dan %.2f sn, B'den %.2f sn kalmıştı)"
		% [ta.time_left, tb.time_left], ok_a and ok_b and b_new and c_new and tb != ta and ta.time_left > 0.0
		and tb.time_left > 0.0)
	await _after(tb)
	_c("A ve B'nin gecikmeleri doldu: ikisinin de sonucu AÇILMADI, sunum hiç başlamadı", not _main._result.visible
		and _shows == 0 and _main._result_seq == seq and ta.time_left <= 0.0)
	if _abort_if_stale("H"):
		return
	_c("  … C etkin (bitmemiş, mola yok)", _main._board == c and not c.is_finished() and not _main.is_pause_open())
	var dropped: bool = await _drop_ok(c)
	_c("  … C gerçek dokunuşu aldı: tam 1 bırakış", dropped)
	await _finish_now(c)
	await _after(_last_timer)
	_c("yalnız güncel nesil (C) sundu: tam bir kez", _main._result.visible and _shows == 1 and _main._result_seq == seq + 2)
	_sections_done += 1


# --- I) İlerleme ------------------------------------------------------------------------------------------

func _progression() -> void:
	print("-- I: meşru kesinleşme bir kez — bastırılan sonuç ilerlemeyi geri almaz / ikilemez")
	await _fresh()
	var control: Dictionary = await _first_clear(false)
	_c("kontrol (değiştirilmedi): level 5 ilk kazanma sonucu açıldı, sonuç kayda yazmadı", control["ok"]
		and control["result"] and _same(control["s3"], control["s1"]) and control["d3"] == control["d1"])
	await _fresh()
	var run: Dictionary = await _first_clear(true)
	var s0: Dictionary = run["s0"]
	var s1: Dictionary = run["s1"]
	var stars: int = _level(5).stars_earned(true, 0)
	var award: int = PlayerProgression.round_xp_award(0, true, 0, stars)
	_c("deney: level 5 molada kesinleşti, gecikme içinde yeniden başlatıldı", run["ok"] and run["replaced"])
	_c("kesinleşme gecikmeden ÖNCE: tur + 1, XP + %d, level 6 açıldı, level 5'e %d yıldız" % [award, stars],
		int(s1["total_rounds_played"]) == int(s0["total_rounds_played"]) + 1
		and int(s1["player_xp"]) == int(s0["player_xp"]) + award and int(s1["highest_level_unlocked"]) == 6
		and int(s0["highest_level_unlocked"]) == 5 and int((s1["level_stars"] as Dictionary).get("5", 0)) == stars)
	_c("  … görev ilerlemesi bir kez: günlük tur + 1, günlük level 1/1 (ödül verildi)",
		_mission(s1, "daily_rounds") == _mission(s0, "daily_rounds") + 1 and _mission(s1, "daily_clear") == 1
		and _rewarded(s1).has("daily_clear") and not _rewarded(s0).has("daily_clear"))
	var keys: Array[String] = ["player_xp", "total_rounds_played", "highest_level_unlocked", "level_stars", "missions",
		"total_merges", "merges_since_bonus_chest", "highest_tier_created", "endless_high_score"]
	var same_delta: bool = true
	for key in keys:
		if JSON.stringify(_norm(_delta(run["s0"], run["s1"], key))) != JSON.stringify(_norm(_delta(control["s0"], control["s1"], key))):
			same_delta = false
			print("    fark: %s" % key)
	_c("  … deneyin kesinleşmesi kontrolünkiyle AYNI (XP, tur, kilit, yıldız, görev, merge)", same_delta)
	_c("yeniden başlatma hiçbir şey yazmadı (bellek + disk aynı)", _same(run["s2"], s1) and run["d2"] == run["d1"])
	_c("eski round'un gecikmesi doldu: sonuç AÇILMADI", not run["result"])
	_c("  … ilerleme GERİ ALINMADI, İKİLENMEDİ (bellek + disk kesinleşmedeki gibi)", _same(run["s3"], s1)
		and run["d3"] == run["d1"])
	var next: Node2D = run["next"]
	_c("yeni round güncel ilerlemeden başladı (level 6 açık, level 5 yıldızı korunuyor)", _main._board == next
		and SaveManager.highest_level_unlocked() == 6 and SaveManager.stars_for_level(5) == stars)
	if _abort_if_stale("I"):
		return
	# Değiştirilen board'un GEÇ round_finished'ı (aynı kare — board henüz serbest değil): ikinci kesinleşme yok.
	var bytes_late: PackedByteArray = _bytes()
	var rounds_late: int = _rounds()
	var old: Node2D = _main._board
	_main._on_pause_restart()
	old.round_finished.emit(true)
	await _after(_last_timer)
	_c("değiştirilen board'un geç round_finished(true)'u: kesinleşme / kayıt / sonuç YOK", _bytes() == bytes_late
		and _rounds() == rounds_late and not _main._round_finalized and not _main._result.visible
		and _main._board != null and not _main._board.is_finished())
	var board: Node2D = _main._board
	_track(board)
	_shows = 0
	await _finish_now(board)
	await _after(_last_timer)
	_c("yeni round kendi ilerlemesini bir kez yazdı (tur + 1) ve sonucunu bir kez açtı", _rounds() == rounds_late + 1
		and _main._result.visible and _shows == 1)
	_sections_done += 1


## Level 5 ilk kazanma (mola açıkken); `replace` ise gecikme içinde mola Yeniden Başlat.
func _first_clear(replace: bool) -> Dictionary:
	var board: Node2D = await _start(_level(5))
	await _wait_settled()
	var s0: Dictionary = SaveManager.data.duplicate(true)
	var ok: bool = await _finish_under_pause(board, false)
	var timer: SceneTreeTimer = _last_timer
	var out: Dictionary = {"ok": ok, "s0": s0, "s1": SaveManager.data.duplicate(true), "d1": _bytes(), "replaced": false}
	if replace:
		var board_id: int = board.get_instance_id()
		var next: Node2D = await _restart_via_pause(false)
		out["replaced"] = _differs(next, board_id) and _replace_left > 0.0
		out["next"] = next
		out["s2"] = SaveManager.data.duplicate(true)
		out["d2"] = _bytes()
	await _after(timer)
	out["s3"] = SaveManager.data.duplicate(true)
	out["d3"] = _bytes()
	out["result"] = _main._result.visible
	return out


# --- J) Kayıp ----------------------------------------------------------------------------------------------

func _loss_replaced() -> void:
	print("-- J: kayıp kesinleşti → değiştirildi (kayıp molada oluşamaz: mola Yeniden Başlat işleyicisi, QA kancası)")
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var s0: Dictionary = SaveManager.data.duplicate(true)
	await _loss(board)
	var timer: SceneTreeTimer = _last_timer
	var s1: Dictionary = SaveManager.data.duplicate(true)
	var d1: PackedByteArray = _bytes()
	_c("kayıp kesinleşti: tur + 1, teselli kesinleşmede (Hamur / sandık değişti), kayıt yazıldı", board.is_finished()
		and int(s1["total_rounds_played"]) == int(s0["total_rounds_played"]) + 1 and not _same(s1, s0) and d1.size() > 0)
	var board_id: int = board.get_instance_id()
	_main._on_pause_restart()
	var left: float = timer.time_left
	await _settle(2)
	var next: Node2D = _main._board
	_track(next)
	_c("kurulum: kayıp gecikmesi içinde aynı level yeniden başladı", _differs(next, board_id) and left > 0.0)
	await _after(timer)
	_c("eski KAYIP sonucu yeniden başlatılan round'un üstüne AÇILMADI", not _main._result.visible and _shows == 0)
	_c("  … teselli / tur yalnız kesinleşmede: ikinci teselli yok, geri alma yok (bellek + disk aynı)",
		_same(SaveManager.data, s1) and _bytes() == d1)
	if _abort_if_stale("J"):
		return
	_c("  … yeni round etkin (bitmemiş, mola yok)", _main._board == next and not next.is_finished() and not _main.is_pause_open())
	var dropped: bool = await _drop_ok(next)
	_c("  … yeni round gerçek dokunuşu aldı: tam 1 bırakış", dropped)
	_sections_done += 1


# --- K) Sonsuz -----------------------------------------------------------------------------------------------

func _endless() -> void:
	print("-- K: Sonsuz aynı gecikmeli yolu kullanır")
	await _fresh()
	var board: Node2D = await _start(load(ENDLESS))
	await _wait_settled()
	await _loss(board)
	await _after(_last_timer)
	_c("geçerli Sonsuz sonucu: mod ENDLESS, tam bir kez", _main._result.visible and _main._result.mode() == _mode("ENDLESS")
		and _shows == 1)
	_main._on_retry_pressed()
	await _settle(3)
	board = _main._board
	_track(board)
	_shows = 0
	await _loss(board)
	var timer: SceneTreeTimer = _last_timer
	var finished: bool = board.is_finished()
	var board_id: int = board.get_instance_id()
	var s1: Dictionary = SaveManager.data.duplicate(true)
	_main._on_pause_restart()
	var left: float = timer.time_left
	await _settle(2)
	var next: Node2D = _main._board
	_track(next)
	_c("kurulum: Sonsuz kesinleşti, gecikme içinde yeni Sonsuz başladı", finished and _differs(next, board_id)
		and next.level.is_endless and left > 0.0)
	await _after(timer)
	_c("değiştirilen Sonsuz round'unun sonucu AÇILMADI", not _main._result.visible and _shows == 0)
	_c("  … rekor / tur yalnız kesinleşmede (sonra değişmedi)", _same(SaveManager.data, s1))
	if _abort_if_stale("K"):
		return
	_c("  … yeni Sonsuz etkin", _main._board == next and not next.is_finished())
	_sections_done += 1


# --- L) Tutorial ---------------------------------------------------------------------------------------------

func _tutorial() -> void:
	print("-- L: tutorial adımları / geri onayı / ATLA round neslini değiştirmez")
	await _teardown_main()
	_clean()
	DailyRewards.clock_override = THU
	SaveManager.load_game()
	await _boot()
	var tutorial: TutorialController = _main._tutorial
	var board: Node2D = _main._board
	_track(board)
	_c("ön koşul: yeni oyuncu → gerçek Level 1 tutorial round'u", board != null and _main.is_tutorial_active()
		and board.level.level_number == 1)
	var g: int = _gen()
	tutorial.advance()
	await _settle(2)
	await _back()
	await _back()
	await _settle(2)
	_c("tutorial ileri + Android geri onayı (aç / kapat): nesil ve board aynı", _gen() == g and _main._board == board
		and _main.is_tutorial_active())
	tutorial.skip()
	await _settle(2)
	_c("ATLA: onboarding tamamlandı, round sürüyor, nesil ve board aynı", SaveManager.onboarding_completed()
		and not _main.is_tutorial_active() and _main._board == board and _gen() == g and not board.is_finished())
	await _win_merge(board)
	await _after(_last_timer)
	_c("tutorial round'unun kazanma sonucu açıldı (bastırılmadı): WIN, level 1, tam bir kez", _main._result.visible
		and _main._result.mode() == _mode("WIN") and _shown_level() == 1 and _shows == 1)
	_sections_done += 1


# --- M) Round nesli ---------------------------------------------------------------------------------------

func _generation() -> void:
	print("-- M: round nesli — board değişimi ilerletir, diğer eylemler ilerletmez; yalnız bellekte")
	await _fresh()
	var value: Variant = _main.get("_round_generation")
	_c("Main'de bellek içi round nesli var (int)", value != null and typeof(value) == TYPE_INT)
	var g0: int = _gen()
	_main._show_tab(1)
	await _settle(2)
	_main._show_tab(0)
	await _settle(2)
	_c("board yokken sekme geçişleri nesli değiştirmez", _gen() == g0)
	var board: Node2D = await _start(_level(3))
	var g1: int = _gen()
	_c("yeni round (sabit level) nesli ilerletir", g1 > g0)
	_main.open_pause_menu()
	await _settle(1)
	_main.resume_game()
	await _settle(1)
	_c("mola aç / DEVAM ET nesli değiştirmez", _gen() == g1 and _main._board == board)
	_main._on_board_settings_requested()
	await _settle(1)
	_main.close_settings()
	await _settle(1)
	_c("oyun içi Ayarlar aç / kapat nesli değiştirmez", _gen() == g1)
	_main._notification(NOTIFICATION_APPLICATION_RESUMED)
	await _settle(1)
	_c("öne dönüş (gün tazeleme) nesli değiştirmez", _gen() == g1)
	var board_id: int = board.get_instance_id()
	_main.open_pause_menu()
	await _settle(1)
	_main._pause.restart_pressed.emit()
	await _settle(2)
	var g2: int = _gen()
	_c("mola Yeniden Başlat nesli ilerletir", g2 > g1 and _differs(_main._board, board_id))
	_main.open_pause_menu()
	await _settle(1)
	_main._pause.exit_pressed.emit()
	await _settle(2)
	var g3: int = _gen()
	_c("Ana Menüye Dön (terk) nesli ilerletir", g3 > g2 and _main._board == null)
	_main._show_tab(0)
	await _settle(2)
	_c("  … sonra sekme geçişi değiştirmez", _gen() == g3)
	var started: bool = _main.start_daily_challenge()
	await _settle(2)
	var g4: int = _gen()
	_c("meydan okuma başlatması nesli ilerletir", started and g4 > g3)
	_main.open_pause_menu()
	await _settle(1)
	_main.abandon_run()
	await _settle(2)
	_c("meydan okumadan çıkış nesli ilerletir", _gen() > g4)
	board = await _start(_level(3))
	await _wait_settled()
	await _finish_now(board)
	var g5: int = _gen()
	await _after(_last_timer)
	_c("geçerli sonuç açıldı; kesinleşme ve sunum nesli değiştirmedi", _main._result.visible and _gen() == g5)
	var owned: bool = _main.has_method("_round_still_owned") and bool(_main.call("_round_still_owned", g5))
	var stale: bool = _main.has_method("_round_still_owned") and not bool(_main.call("_round_still_owned", g5 - 1))
	_c("doğrulayıcı: güncel nesil kabul, eski nesil RED", owned and stale)
	_main._on_retry_pressed()
	await _settle(2)
	var g6: int = _gen()
	_c("sonuç TEKRAR (yeni round) nesli ilerletir; eski nesil artık RED", g6 > g5
		and _main.has_method("_round_still_owned") and not bool(_main.call("_round_still_owned", g5)))
	_track(_main._board)
	await _finish_now(_main._board)
	await _after(_last_timer)
	var g7: int = _gen()
	_main._on_exit_pressed()
	await _settle(2)
	_c("sonuç ANA SAYFA / çıkış nesli ilerletir", _gen() > g7 and _main._board == null)
	SaveManager.save_game()
	_c("nesil kayda yazılmaz: bellekte / diskte 'generation' yok", not JSON.stringify(SaveManager.data).contains("generation")
		and not FileAccess.get_file_as_string(PATH).contains("generation"))
	_sections_done += 1


# --- N) Reklam --------------------------------------------------------------------------------------------

func _ads() -> void:
	print("-- N: geçiş reklamı — geçerli normal sonuç aynen; eski round denemez; meydan okuma hiç")
	# N1 — geçerli normal sonuç: politika aynen.
	await _fresh(true)
	var ads: MonetizationManager = _main._ads
	var fake: FakeAdBackend = ads._backend
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var seq: int = _main._result_seq
	await _finish_now(board)
	await _after(_last_timer)
	_c("geçerli normal sonuç: gecikmeden sonra geçiş reklamı gösteriliyor (aynı politika), sonuç HENÜZ yok",
		fake.interstitial_shows.size() == 1 and ads.interstitial_state() == MonetizationManager.InterstitialState.SHOWING
		and not _main._result.visible)
	var shown: String = fake.interstitial_shows[0] if not fake.interstitial_shows.is_empty() else ""
	fake.emit_interstitial_showed(shown)
	fake.emit_interstitial_dismissed(shown)
	await _settle(3)
	_c("  … reklam kapandı → sonuç tam bir kez, RESULT yüzeyi", _main._result.visible and _shows == 1
		and _main._result_seq == seq + 2 and ads.surface() == MonetizationManager.Surface.RESULT)

	# N2 — gecikme içinde arka plan + öne dönüş: round değişmedi → reklam bir kez denenir, sonuç bir kez.
	await _fresh(true)
	ads = _main._ads
	fake = ads._backend
	board = await _start(_level(3))
	await _wait_settled()
	seq = _main._result_seq
	await _finish_now(board)
	var timer: SceneTreeTimer = _last_timer
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)
	await _settle(2)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)
	await _settle(2)
	var left: float = timer.time_left
	await _after(timer)
	_c("gecikme içinde arka plan / öne dönüş (%.2f sn kalmıştı): geçiş reklamı TAM bir kez denendi" % left, left > 0.0
		and fake.interstitial_shows.size() == 1 and ads.interstitial_state() == MonetizationManager.InterstitialState.SHOWING)
	shown = fake.interstitial_shows[0] if not fake.interstitial_shows.is_empty() else ""
	fake.emit_interstitial_showed(shown)
	fake.emit_interstitial_dismissed(shown)
	await _settle(3)
	_c("  … kapanınca sonuç tam bir kez", _main._result.visible and _shows == 1 and _main._result_seq == seq + 2)

	# N3 — eski round reklam denemez; sonraki geçerli bitiş aynı politikayla gösterir.
	await _fresh(true)
	ads = _main._ads
	fake = ads._backend
	board = await _start(_level(3))
	await _wait_settled()
	var ok: bool = await _finish_under_pause(board, false)
	timer = _last_timer
	var shows: int = fake.interstitial_shows.size()
	AdEvents.clear_recent()
	var board_id: int = board.get_instance_id()
	var next: Node2D = await _restart_via_pause(false)
	var replaced: bool = _differs(next, board_id)
	await _after(timer)
	_c("eski round (gecikmede yeniden başlatıldı): geçiş reklamı DENEMEDİ, reklam uygun + hazır kaldı", ok
		and replaced and fake.interstitial_shows.size() == shows and AdEvents.count(&"interstitial_skipped_not_ready") == 0
		and ads.interstitial_state() == MonetizationManager.InterstitialState.READY and ads.interstitial_eligible())
	_c("  … yüzey GAMEPLAY (yeni board), sonuç yok", ads.surface() == MonetizationManager.Surface.GAMEPLAY
		and not _main._result.visible)
	if not _main._result.visible and ads.interstitial_state() == MonetizationManager.InterstitialState.READY:
		seq = _main._result_seq
		await _finish_now(next)
		await _after(_last_timer)
		_c("yeni round'un geçerli bitişi geçiş reklamını gösterdi (politika aynen)", fake.interstitial_shows.size() == shows + 1
			and ads.interstitial_state() == MonetizationManager.InterstitialState.SHOWING)
		var second: String = fake.interstitial_shows[-1]
		fake.emit_interstitial_showed(second)
		fake.emit_interstitial_dismissed(second)
		await _settle(3)
		_c("  … kapanınca yeni round'un sonucu tam bir kez", _main._result.visible and _shows == 1 and _main._result_seq == seq + 2)
	else:
		_c("yeni round'un geçerli bitişi geçiş reklamını gösterdi (politika aynen)", false)

	# N4 / N5 — reklam açıkken round değişir (üretimde reklam oyunu örter — savunma; QA kancası: mola Yeniden
	# Başlat işleyicisi): kapanışta da, gösterim hatasında da eski sonuç açılmaz, yönetici temiz kalır.
	for mode: String in ["kapanış", "gösterim hatası"]:
		await _fresh(true)
		ads = _main._ads
		fake = ads._backend
		board = await _start(_level(3))
		await _wait_settled()
		await _finish_now(board)
		await _after(_last_timer)
		var id: String = fake.interstitial_shows[0] if not fake.interstitial_shows.is_empty() else ""
		_c("ön koşul (%s): geçerli bitiş geçiş reklamını açtı" % mode, id != ""
			and ads.interstitial_state() == MonetizationManager.InterstitialState.SHOWING)
		if mode == "kapanış":
			fake.emit_interstitial_showed(id)
		_main._on_pause_restart()
		await _settle(2)
		next = _main._board
		_track(next)
		if mode == "kapanış":
			fake.emit_interstitial_dismissed(id)
		else:
			fake.emit_interstitial_show_failed(id)
		await _settle(3)
		_c("reklam açıkken değiştirilen round (%s): ESKİ sonuç yeni board'un üstüne AÇILMADI" % mode,
			not _main._result.visible and _shows == 0 and _main._board == next and not next.is_finished())
		_c("  … yüzey GAMEPLAY (RESULT'a geçmedi)", ads.surface() == MonetizationManager.Surface.GAMEPLAY)
		_c("  … yönetici temiz: bekleyen mola yok, reklam artık GÖSTERİLMİYOR%s" % (", 60 sn bekleme başladı"
			if mode == "kapanış" else ""), not ads.break_pending()
			and ads.interstitial_state() != MonetizationManager.InterstitialState.SHOWING
			and (mode != "kapanış" or ads.fullscreen_cooldown_sec() > MonetizationManager.FULLSCREEN_AD_COOLDOWN_SEC - 1.0))

	# N6 — meydan okuma hiç denemez.
	await _fresh(true)
	ads = _main._ads
	fake = ads._backend
	shows = fake.interstitial_shows.size()
	AdEvents.clear_recent()
	_main.start_daily_challenge()
	await _settle(3)
	var challenge: Node2D = _main._board
	_track(challenge)
	await _win_merge(challenge)
	await _after(_last_timer)
	_c("meydan okuma bitişi: geçiş reklamı denemesi YOK (TASK/047 aynen), meydan okuma sonucu açıldı",
		fake.interstitial_shows.size() == shows and AdEvents.count(&"interstitial_skipped_not_ready") == 0
		and _main._result.visible and _main._result.mode() == _mode("CHALLENGE_WIN"))
	_sections_done += 1


# --- O) Kaynak sözleşmesi --------------------------------------------------------------------------------

func _source_contract() -> void:
	print("-- O: kaynak sözleşmesi")
	var src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var code: String = _strip_comments(src)
	var constants: Dictionary = _main_script.get_script_constant_map()
	_c("RESULT_DELAY aynen 0,8 sn (süre değişmedi)", is_equal_approx(float(constants["RESULT_DELAY"]), 0.8))
	_c("TOUCH_SETTLE_MSEC aynen 300 (TASK/045.2)", int(constants["TOUCH_SETTLE_MSEC"]) == 300)
	_c("geçiş reklamı tek çağrı noktası (Main round bitişi)", code.count("_ads.try_show_interstitial(") == 1)
	_c("TASK/046.2 iptal koruması aynen", FileAccess.get_file_as_string("res://scripts/game/game_board.gd")
		.contains("\telif not touch.canceled:"))
	var clear_fn: String = _function(code, "func _clear_board(")
	var bump_at: int = clear_fn.find("_round_generation += 1")
	_c("nesil TEK noktada ilerler: _clear_board (her board değişiminin geçtiği yer), board bağları koptuktan SONRA",
		code.count("_round_generation += 1") == 1 and bump_at >= 0
		and bump_at > clear_fn.find("round_finished.disconnect(_on_round_finished)"))
	var re := RegEx.new()
	re.compile("(?m)^\\s*_board\\s*=[^=]")
	var begin_fn: String = _function(code, "func _begin_round(")
	_c("_board yalnız _begin_round'da (önce _clear_board) ve _clear_board'da atanır", re.search_all(code).size() == 2
		and re.search_all(begin_fn).size() == 1 and re.search_all(clear_fn).size() == 1
		and begin_fn.find("_clear_board()") >= 0 and begin_fn.find("_clear_board()") < begin_fn.find("_board = "))
	var finish_fn: String = _function(code, "func _on_round_finished(")
	var captured: int = finish_fn.find("_round_generation")
	var waited: int = finish_fn.find("await get_tree().create_timer(RESULT_DELAY).timeout")
	var checked: int = finish_fn.find("_round_still_owned(", maxi(waited, 0))
	var advert: int = finish_fn.find("_ads.try_show_interstitial(")
	_c("normal sonuç: nesil gecikmeden ÖNCE yakalanır, gecikmeden sonra ve geçiş reklamından ÖNCE doğrulanır",
		captured >= 0 and waited > captured and checked > waited and advert > checked)
	_c("sonuç ekranı aşaması da sahipliği doğrular", _function(code, "func _present_result(").contains("_round_still_owned("))
	_c("normal işleyici meydan okumayı bilmez (TASK/047 sözleşmesi)", not finish_fn.contains("challenge")
		and not finish_fn.contains("_round_kind"))
	_c("meydan okuma kendi deneme kimliğini korur (TASK/047 aynen)", code.contains("func _challenge_result_current(")
		and code.contains("_challenge_attempt += 1"))
	var save_src: String = FileAccess.get_file_as_string("res://scripts/autoload/save_manager.gd") \
		+ FileAccess.get_file_as_string("res://scripts/autoload/save_file.gd")
	_c("nesil kayda girmez (SaveManager / SaveFile bilmiyor)", not save_src.contains("round_generation"))
	_sections_done += 1


# --- Yardımcılar ------------------------------------------------------------------------------------------

func _fixture(extra: Dictionary = {}) -> Dictionary:
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 2},
		"endless_high_score": 0, "dough": 335, "total_merges": 40, "merges_since_bonus_chest": 10,
		"unlocked_skins": ["common_01", "rare_02"], "profile_showcase": ["rare_02"],
		"powerups": {"bomb": 2, "upgrade": 9, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "", "daily_streak": 3,
		"last_login_date": Time.get_date_string_from_system(), "age_ad_band": "ADULT", "next_age_transition_date": "",
		"player_meta_version": 1, "player_xp": 400, "total_rounds_played": 12, "highest_tier_created": 4,
		"unlocked_achievements": ["merge_10"],
		"daily_rewards": {"day_key": THU, "free_chest_claimed": true, "ad_chests_claimed": 2,
			"dough_ad_claimed": true, "popup_seen_day": THU, "last_seen_day_key": THU},
		"missions": {"version": 1, "day_key": THU, "week_start_day_key": MON,
			"daily_progress": {"daily_merges": 5, "daily_rounds": 0, "daily_clear": 0}, "daily_rewarded": [],
			"weekly_progress": {"weekly_merges": 30, "weekly_rounds": 4, "weekly_clears": 2}, "weekly_rewarded": []}}
	for key: String in extra:
		content[key] = extra[key]
	return content


func _write_fixture(extra: Dictionary = {}) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(_fixture(extra), "\t"))
	file.close()


## Temiz kayıt + Main (isteğe bağlı sahte reklam arka ucu: rıza + init + geçiş reklamı hazır + uygun).
func _fresh(with_ads: bool = false) -> void:
	await _teardown_main()
	_clean()
	DailyRewards.clock_override = THU
	_write_fixture()
	SaveManager.load_game()
	if not with_ads:
		await _boot()
		return
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


func _boot(fake: FakeAdBackend = null) -> void:
	await _teardown_main()
	_main_script.set("ads_backend_override", fake)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _settle(3)
	_main_script.set("ads_backend_override", null)
	_shows = 0
	_drops = 0
	_last_timer = null
	_main._result.visibility_changed.connect(func() -> void:
		if _main != null and is_instance_valid(_main) and _main._result.visible:
			_shows += 1)


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _settle(2)


## Normal round başlatma (Main'in Harita / sonuç / mola yolunun ortak girişi).
func _start(level: LevelData) -> Node2D:
	_main._start_level(level)
	await _settle(3)
	var board: Node2D = _main._board
	_track(board)
	return board


## Bırakış sayacı + bitiş izleyicisi: round_finished yayımında (Main'in işleyicisinden SONRA bağlı) Main'in
## RESULT_DELAY zamanlayıcısıyla aynı süreli bir SceneTree zamanlayıcısı — aynı karede Main'inkinden sonra döner.
func _track(board: Node2D) -> void:
	if board == null or board.has_meta(&"qa_tracked"):
		return
	board.set_meta(&"qa_tracked", true)
	board.dumpling_dropped.connect(func(_tier: int) -> void: _drops += 1)
	board.round_finished.connect(func(_won: bool) -> void:
		_finish_msec = Time.get_ticks_msec()
		_last_timer = get_tree().create_timer(_delay()))


## Bu bitişin gecikmesi doldu (Main'in gecikmeli kodu bu karede çalıştı) + birkaç kare.
func _after(timer: SceneTreeTimer, frames: int = 3) -> void:
	if timer != null and timer.time_left > 0.0:
		await timer.timeout
	await _settle(frames)


## Gecikmeden `seconds` kalana kadar bekle (gecikme SÜRERKEN denetim için).
func _until_left(timer: SceneTreeTimer, seconds: float) -> void:
	while timer != null and timer.time_left > seconds:
		await get_tree().process_frame


## Tabanda bir parça (varsayılan: hedefin bir altı) — Büyütücü hedefi.
func _piece(board: Node2D, tier: int = -1, frames: int = 8) -> Dumpling:
	if tier < 0:
		tier = board.level.target_tier - 1
	var r: float = TierConfig.radius(tier)
	var piece: Dumpling = board._spawn_dumpling(tier, Vector2(board._center_x() + 60.0, _floor_y(board) - r - 1.0))
	await _physics(frames)
	return piece


## Büyütücü: güç düğmesi (`real_button`: GERÇEK dokunuş, yoksa PowerBar sinyali — GameBoard'un gerçek bağlantısı)
## + hedefe GERÇEK parmak basışı (dönüşüm basışta başlar, 0,15 sn anticipation sonra tamamlanır).
func _fire_upgrade(board: Node2D, piece: Dumpling, real_button: bool = false) -> void:
	if real_button:
		await _finger_tap(_center(board._power_bar.slot(int(PowerUp.Type.UPGRADE))))
	else:
		board._power_bar.power_pressed.emit(int(PowerUp.Type.UPGRADE))
		await _settle(1)
	var at: Vector2 = _win(board, piece.global_position)
	await _finger(at, true)
	await _finger(at, false)


## Mola AÇIKKEN kazanma (üretim yolu): Büyütücü dönüşümü başlar, anticipation içinde mola açılır (gerçek
## HUD geri dokunuşu ya da mola işleyicisi), dönüşüm donmuş board'da tamamlanıp round'u bitirir.
## Dönüş: kurulum doğru mu (mola bitişten ÖNCE açıldı, round bitti, mola hâlâ açık).
func _finish_under_pause(board: Node2D, real: bool, frames: int = 8) -> bool:
	var piece: Dumpling = await _piece(board, -1, frames)
	_finish_msec = -1
	var timer_before: SceneTreeTimer = _last_timer
	await _fire_upgrade(board, piece, real)
	if real:
		await _finger_tap(_center(board._hud.back_button))
	else:
		_main.open_pause_menu()
	_pause_msec = Time.get_ticks_msec()
	var paused_first: bool = _main.is_pause_open() and not board.is_finished() and is_instance_valid(piece) \
		and piece.is_merging
	await _until_finished(board)
	return paused_first and board.is_finished() and _main.is_pause_open() and _last_timer != timer_before


## Molasız kazanma: Büyütücü dönüşümü hedefe ulaşır.
func _finish_now(board: Node2D, frames: int = 8) -> void:
	var piece: Dumpling = await _piece(board, -1, frames)
	_finish_msec = -1
	await _fire_upgrade(board, piece)
	await _until_finished(board)


## Gerçek merge ile hedef: sağ kenarda tabandaki (hedef − 1) tier parçasının üstüne aynısı düşer.
func _win_merge(board: Node2D) -> void:
	_finish_msec = -1
	var tier: int = board.level.target_tier - 1
	var r: float = TierConfig.radius(tier)
	var x: float = board._right_x() - r - 12.0
	board._spawn_dumpling(tier, Vector2(x, _floor_y(board) - r - 1.0))
	board._spawn_dumpling(tier, Vector2(x, _floor_y(board) - 3.0 * r - 30.0))
	var guard: int = 0
	while not board.is_finished() and guard < 600:
		await get_tree().physics_frame
		guard += 1


## Devam teklifi → reddet (Main'in üretim işleyicisi) → kesin kayıp.
func _loss(board: Node2D) -> void:
	_finish_msec = -1
	board._enter_fail_pending()
	await _settle(2)
	_main.decline_revive()
	await _settle(1)


func _restart_via_pause(real: bool) -> Node2D:
	var old_id: int = _main._board.get_instance_id() if _main._board != null else 0
	if real:
		await _finger_tap(_center(_main._pause.buttons()[1]))
	else:
		_main._pause.restart_pressed.emit()
	_replace_msec = Time.get_ticks_msec()
	_replace_left = _last_timer.time_left if _last_timer != null else -1.0
	await _settle(2)
	var board: Node2D = _main._board
	if _differs(board, old_id):
		_track(board)
	return board


## Yeni board mı: geçerli ve kimliği eskisinden farklı (serbest bırakılmış düğüm Godot'ta null gibi karşılaştırılır
## — kimlik eski board yaşarken alınır).
func _differs(board: Variant, old_id: int) -> bool:
	return board != null and is_instance_valid(board) and (board as Object).get_instance_id() != old_id


func _until_finished(board: Node2D, max_frames: int = 900) -> void:
	var guard: int = 0
	while is_instance_valid(board) and not board.is_finished() and guard < max_frames:
		await get_tree().process_frame
		guard += 1


## Yeni board'a gerçek parmak dokunuşu → tam 1 bırakış mı.
func _drop_ok(board: Node2D) -> bool:
	var before: int = _drops
	await _finger_tap(_board_point(board, -90.0))
	await _physics(3)
	return _drops == before + 1


## Eski sonuç açıldıysa (düzeltmesiz kod) bölümün kalanı anlamsız — atlanır.
func _abort_if_stale(label: String) -> bool:
	if _main._result.visible:
		print("    (eski sonuç ekranda — %s bölümünün kalanı atlandı)" % label)
		_sections_done += 1
		return true
	return false


func _gen() -> int:
	var value: Variant = _main.get("_round_generation")
	return int(value) if value != null else -1


func _rounds() -> int:
	return int(SaveManager.data.get("total_rounds_played", 0))


func _shown_level() -> int:
	var level: Variant = _main._result.get("_level")
	return (level as LevelData).level_number if level is LevelData else -1


func _mission(state: Dictionary, key: String) -> int:
	return int(((state.get("missions", {}) as Dictionary).get("daily_progress", {}) as Dictionary).get(key, 0))


func _rewarded(state: Dictionary) -> Array:
	return ((state.get("missions", {}) as Dictionary).get("daily_rewarded", []) as Array)


## Bir anahtarın iki durum arasındaki farkı (karşılaştırma için kaba gösterim).
func _delta(before: Dictionary, after: Dictionary, key: String) -> Variant:
	var a: Variant = _norm(before.get(key))
	var b: Variant = _norm(after.get(key))
	if typeof(a) == TYPE_INT and typeof(b) == TYPE_INT:
		return int(b) - int(a)
	return [a, b]


func _delay() -> float:
	return float(_main_script.get_script_constant_map()["RESULT_DELAY"])


func _wait_until(target_msec: int) -> void:
	var left: int = target_msec - Time.get_ticks_msec()
	if left > 0:
		await get_tree().create_timer(float(left) / 1000.0).timeout
	await _settle(1)


func _wait_settled() -> void:
	var settle_msec: int = int(_main_script.get_script_constant_map().get("TOUCH_SETTLE_MSEC", 300))
	await _wait(float(settle_msec) / 1000.0 + 0.12)
	await _settle(1)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


## Android geri (Main'in 250 ms debounce'u gerçek saatle — iki basış arasında boşluk).
func _back() -> void:
	var gap: int = _last_back_msec + BACK_GAP_MSEC - Time.get_ticks_msec()
	if gap > 0:
		await _wait(float(gap) / 1000.0)
	_last_back_msec = Time.get_ticks_msec()
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(1)


func _touch_event(pos: Vector2, pressed: bool, index: int) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = pos
	touch.pressed = pressed
	return touch


## Parmak olayı Input'a verilir ve HEMEN dağıtılır (tampon boşaltılır — sıra deterministik).
func _finger(pos: Vector2, pressed: bool, index: int = 0) -> void:
	Input.parse_input_event(_touch_event(pos, pressed, index))
	Input.flush_buffered_events()
	await get_tree().process_frame


func _finger_tap(pos: Vector2, index: int = 0) -> void:
	await _finger(pos, true, index)
	await _finger(pos, false, index)


func _screen(canvas: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * canvas


func _center(control: Control) -> Vector2:
	return _screen(control.get_global_rect().get_center())


## Dünya noktası → Input.parse_input_event'in beklediği PENCERE pikseli.
func _win(board: Node2D, world: Vector2) -> Vector2:
	return _screen(board.world_to_screen(world))


## Kabın içinde, parçalardan uzak boş bir nokta (pencere pikseli).
func _board_point(board: Node2D, dx: float) -> Vector2:
	return _win(board, Vector2(board._center_x() + dx, board.overflow_line_y() + 60.0))


func _floor_y(board: Node2D) -> float:
	return float(board.get_script().get_script_constant_map()["FLOOR_Y"])


func _level(number: int) -> LevelData:
	for level in LevelLibrary.load_levels():
		if level.level_number == number:
			return level
	return null


func _mode(name: String) -> int:
	var script: GDScript = load("res://scripts/ui/round_result.gd")
	return int((script.get_script_constant_map()["Mode"] as Dictionary)[name])


## JSON sayı normalizasyonu: tam değerli float → int (bellek int, disk float okunur).
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


func _same(a: Dictionary, b: Dictionary) -> bool:
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
