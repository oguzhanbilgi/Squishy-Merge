extends Node
## TASK/049 — Round bitişi pencere sahipliği: kabul edilen round bitişinden sonra o round'un oyun içi engelleyici
## pencereleri (mola, stok 0 refill penceresi) sonuç / geçiş reklamı akışının üstünde KALMAZ ve girdiyi tutmaz.
## Gerçek Main, gerçek board, sahte reklam arka ucu. Headless.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_round_finish_modal/` altındaki bir yola
## yönlendirilir, sonda geri alınır; gerçek kayıt ailesi (kanonik + .tmp + .bak) başta / sonda bayt bayt karşılaştırılır.
##   godot --headless --audio-driver Dummy --path . res://tools/round_finish_modal_test.tscn
##
## Üretim yolu (PROJECT_STATUS §4.24 / §4.28'de kanıtlanan kök neden): Büyütücü dönüşümü board'a bağlı bir tween'dir
## (0,15 sn anticipation); mola / refill dondurması ağaç duraklatması DEĞİL, özel board dondurmasıdır — tween sürer.
## Dönüşüm başlar, mola açılır (ya da stok 0 bir güce basılır → refill penceresi), dönüşüm hedefe ulaşıp round'u o
## pencerenin ALTINDA bitirir; sonuç (katman 10) RESULT_DELAY (0,8 sn) sonra açık molanın (12) / refill'in (11) altına
## açılırdı. Sözleşme (TASK/049): kabul edilen bitiş anında (round_finished işleyicisinin eşzamanlı kısmında, gecikmeden
## ÖNCE) mola ve refill EYLEMSİZ kapanır — Devam Et / Yeniden Başlat / Ana Menüye Dön, satın alma, ödüllü istek,
## bırakış, board değişimi YOK; board'un menü dondurması bırakılır; sonuç / geçiş reklamı akışı aynen.
##
## Bitiş anı ölçümü: izleyici round_finished'e Main'den SONRA bağlanır → Main'in işleyicisi ilk `await`'e kadar
## çalışmış olur; izleyicinin aldığı görüntü "kabul edilen bitişin eşzamanlı sonucu"dur. "Gecikmeden sonra"
## denetimleri Main'in kendi saatine bağlıdır (aynı süreli SceneTree zamanlayıcısı, Main'inkinden sonra kurulur).
##
## Bölümler:
##   A molasız      pencere yokken kazanma: ilerleme bir kez, gecikme aynen, sonuç bir kez, hiçbir eylem
##   B mola · gerçek GERÇEK Büyütücü düğmesi + hedef + HUD geri (mola) dönüşüm sırasında: bitişte mola kapanır, menü
##                  dondurması bırakılır, eylem / bırakış yok, sonuç gecikmeden sonra açılır; sonuçta GERİ yok sayılır,
##                  gerçek dokunuş SONUCA gider (molaya değil); B2 aynısı mola Android GERİ yoluyla açılınca
##   C mola + reklam geçerli geçiş reklamı: mola reklamdan ÖNCE kapalı, kapanışta sonuç bir kez, mola geri gelmez
##   D tekrar       temizlik iki kez / pencere yokken / yinelenen round_finished: yan etki yok
##   E eylemsiz     bitiş anında molanın Yeniden Başlat / Ana Menüye Dön / Devam Et düğmesinde ya da karartmasında BASILI
##                  parmak — basıştan sonra İŞLENMEMİŞ bir olay da gelir (Godot gizleme anındaki sentetik bırakışı ancak
##                  o zaman düğmeye iletir): kapanış eylem yaymaz, bırakış da yaymaz, bırakış parça düşürmez
##   F girdi        temizlikten sonra mola GERİ'yi / dokunuşu tutmaz; sonuç tutar; gizli katman dokunuş yutmaz
##   G ilerleme     ilk kazanma (level 5) mola açıkken, round'da GERÇEK bir merge ve 75'lik bonus sandık eşiği: XP / tur /
##                  merge / bonus sayaç / yıldız / kilit / görev / sandık (tam 2 kart) / Hamur bir kez, bellek = disk,
##                  gecikme / sonuçtan sonra değişmez; molasız kontrolle aynı fark, aynı anahtarlar
##   H TASK/048     değiştirilen round eski sonuç / reklam açmaz (üretim yeniden başlatma işleyicisi); fırlatma aralığı
##                  ertelemesi aynen; geçerli round geçerli reklam + sonuç
##   I Ayarlar      bitişte açık Ayarlar ve gecikmede açılan Ayarlar KAPANMAZ (genel pencere kuralı DEĞİL)
##   J refill       stok 0 güç → refill penceresi dönüşüm sırasında: bitişte kapanır; satın alma / ödül / reklam isteği /
##                  stok / Hamur / kota değişmez; önceden istenmiş ödüllü talep iptal edilmez / verilmez (kendi yolu:
##                  kazanılırsa verilir, kazanılmazsa hiçbir şey; pencere geri gelmez)
##   K kayıp        normal kayıp aynen
##   L sonsuz       Sonsuz sonucu aynen
##   M meydan       meydan okuma sonucu aynen, geçiş reklamı denemesi yok, işleyicisi temizliğe girmez (TASK/047 donuk)
##   N tutorial     tutorial akışı / sonucu aynen
##   O iptal        ACTION_CANCEL 0 bırakış, sonraki bağımsız dokunuş 1; temizlik sonrası yeni round'a sızıntı yok
##   Q canlı mola   bitmemiş round'da GERÇEK mola düğmeleri aynen: Devam Et / karartma devam ettirir, Yeniden Başlat yeni
##                  board kurar (dokunuş sızmaz, sonraki dokunuş 1), Ana Menüye Dön Harita'ya döner
##   R başka yol    aynı karede merge: mola açıldıktan sonra raporlanan temasın ertelenmiş merge'i round'u molada bitirir
##                  (Dumpling'in gönderdiği aynı sinyal — dar dikiş) → aynı temizlik
##   P kaynak       RESULT_DELAY 0,8 / 300 ms / iptal koruması aynen; temizlik ilerleme yazıldıktan SONRA, gecikmeden ÖNCE,
##                  yalnız normal yolda; Ayarlar'a / gezinmeye / kayda dokunmaz; kapalı mola hiçbir eylem yaymaz

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const ENDLESS: String = "res://resources/levels/endless.tres"
const DIR: String = "user://qa_round_finish_modal"
const PATH: String = DIR + "/save.json"
const SECTIONS: int = 18
const MON: String = "2026-09-28"
const THU: String = "2026-10-01"
const BACK_GAP_MSEC: int = 320
const CLEANUP: String = "_dismiss_terminal_gameplay_overlays"
const ACTION_KEYS: Array[String] = ["resume", "restart", "exit", "refill_ad", "refill_dough", "refill_closed",
	"settings_closed", "result_retry", "result_exit"]

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
## Pencere / sonuç eylem sayaçları (sinyal izleyicileri, Main'in işleyicilerinden SONRA bağlı).
var _actions: Dictionary = {}
## Son izlenen bitişin izleyici zamanlayıcısı (Main'in RESULT_DELAY'iyle aynı saat) ve anlar (ms).
var _last_timer: SceneTreeTimer = null
var _finish_msec: int = -1
var _pause_msec: int = -1
var _result_msec: int = -1
## Kabul edilen bitişin eşzamanlı sonucu (bkz. `_snapshot`).
var _at_finish: Dictionary = {}
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

	await _no_overlay()
	await _pause_real()
	await _pause_interstitial()
	await _idempotent()
	await _held_finger()
	await _input_ownership()
	await _progression()
	await _task048()
	await _settings()
	await _refill()
	await _normal_loss()
	await _endless()
	await _challenge()
	await _tutorial()
	await _cancel_touch()
	await _live_pause()
	await _merge_path()
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


# --- A) Molasız bitiş ---------------------------------------------------------------------------------------

func _no_overlay() -> void:
	print("-- A: pencere yokken kazanma — davranış aynen")
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var rounds: int = _rounds()
	var seq: int = _main._result_seq
	await _finish_now(board)
	var timer: SceneTreeTimer = _last_timer
	_c("ön koşul: kazanma kesinleşti (Büyütücü dönüşümü hedefe ulaştı), bitişte açık pencere yoktu", board.is_finished()
		and timer != null and not _af("pause") and not _af("refill"))
	_c("kesinleşme gecikmeden ÖNCE bir kez yazdı (tur + 1); board donuk değil", _rounds() == rounds + 1
		and not _af("menu_paused") and not _af("board_paused"))
	await _until_left(timer, 0.25)
	_c("gecikme sürerken sonuç yok, mola yok", not _main._result.visible and not _main.is_pause_open()
		and timer.time_left > 0.0)
	await _after(timer)
	_c("gecikmeden sonra kazanma sonucu tam bir kez (WIN, level 3, seq + 2)", _main._result.visible
		and _main._result.mode() == _mode("WIN") and _shown_level() == 3 and _shows == 1 and _main._result_seq == seq + 2)
	_c("  … hiçbir pencere / sonuç eylemi yok, bırakış yok, tur hâlâ + 1", _no_actions() and _drops == 0
		and _rounds() == rounds + 1)
	# Yalnız doğrulama kaydı: SceneTreeTimer kare adımıyla ilerler (bitiş karesinin süresi kadar erken dolabilir);
	# sınırlar yalnız akıl sağlığı (RESULT_DELAY sabitinin kendisi P'de).
	_c("  … gecikme ölçümü (kayıt): bitişten sonuca %d ms (RESULT_DELAY %.1f sn, kare adımı payıyla)" % [
		_result_msec - _finish_msec, _delay()], _result_msec - _finish_msec >= 400 and _result_msec - _finish_msec <= 2000)
	_sections_done += 1


# --- B) Mola açıkken bitiş — gerçek yol ----------------------------------------------------------------------

func _pause_real() -> void:
	print("-- B: GERÇEK yol — Büyütücü düğmesi + hedef + mola (B1 HUD geri dokunuşu, B2 Android geri) dönüşüm sırasında")
	await _pause_path("hud")
	await _pause_path("back")
	_sections_done += 1


func _pause_path(opener: String) -> void:
	var tag: String = "B1 HUD geri" if opener == "hud" else "B2 Android geri"
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
		ok = await _finish_with_pause(board, opener, true)
	var timer: SceneTreeTimer = _last_timer
	_c("[%s] kurulum (gerçek dokunuş, %d deneme): Büyütücü düğmesi + hedefe basış, mola bitişten ÖNCE açıldı " % [tag, attempts]
		+ "(dönüşüm sürüyordu, board menü duraklamasında), dönüşüm round'u bitirdi", ok)
	if not ok:
		return
	var board_id: int = board.get_instance_id()
	var gen: int = _gen()
	var rounds: int = _rounds()
	print("    zaman: mola %d ms → bitiş %d ms (mola açıldıktan %d ms sonra)" % [_pause_msec, _finish_msec,
		_finish_msec - _pause_msec])
	_c("[%s] BİTİŞ ANINDA (eşzamanlı, gecikmeden önce) mola KAPANDI" % tag, not _af("pause"))
	_c("  … board'un menü dondurması bırakıldı (menü duraklaması yok, board donuk değil)",
		not _af("menu_paused") and not _af("board_paused"))
	_c("  … kapanış eylemsiz: Devam Et / Yeniden Başlat / Ana Menüye Dön sayısı 0, board ve nesil aynı",
		_actions_in(_af("actions"), ["resume", "restart", "exit"]) == 0 and _af("board") and _af("gen") == gen)
	await _until_left(timer, 0.3)
	_c("gecikme sürerken (dokunuş / GERİ yok): mola kapalı, sonuç henüz yok, board aynı", not _main.is_pause_open()
		and not _main._result.visible and _owns(board_id, gen))
	await _after(timer)
	print("    zaman: bitiş → sonuç %d ms; sonuç açıldığında: sonuç görünür=%s (katman %d), mola görünür=%s (katman %d), board menü duraklaması=%s"
		% [_result_msec - _finish_msec, str(_main._result.visible), _main._result.layer, str(_main.is_pause_open()),
		_main._pause.layer, str(board.get("_is_menu_paused"))])
	_c("[%s] gecikmeden sonra sonuç tam bir kez (WIN, level 3); mola sonucun üstünde DEĞİL" % tag, _main._result.visible
		and _main._result.mode() == _mode("WIN") and _shown_level() == 3 and _shows == 1 and not _main.is_pause_open())
	_c("  … ilerleme bir kez (tur kesinleşmede + 1, sonra değişmedi), bırakış yok", _rounds() == rounds and _drops == 0)
	await _back()
	print("    Android geri sonrası: sonuç görünür=%s, mola görünür=%s, eylemler=%s" % [str(_main._result.visible),
		str(_main.is_pause_open()), str(_actions)])
	_c("sonuçta Android geri: sonuç ekranının kuralı (yok sayılır) — mola açılmadı, board aynı, sonuç açık",
		_main._result.visible and not _main.is_pause_open() and _owns(board_id, gen) and _no_actions())
	await _finger_tap(_center(_main._result.primary_button()))
	await _settle(2)
	print("    sonucun HARİTA noktasına gerçek dokunuş sonrası: eylemler=%s, board=%s, sekme=%d" % [str(_actions),
		"YOK" if _main._board == null else "VAR", _main._active_tab])
	_c("[%s] sonucun HARİTA düğmesine gerçek dokunuş SONUCA gitti (sonuç çıkışı 1, mola eylemi 0) → Harita" % tag,
		_actions["result_exit"] == 1 and _actions_in(_actions, ["resume", "restart", "exit"]) == 0
		and _main._board == null and _main._active_tab == 1 and _main._screens[1].visible)


# --- C) Mola + geçerli geçiş reklamı -------------------------------------------------------------------------

func _pause_interstitial() -> void:
	print("-- C: mola açıkken bitiş + geçerli geçiş reklamı")
	await _fresh(true)
	var ads: MonetizationManager = _main._ads
	var fake: FakeAdBackend = ads._backend
	_c("ön koşul: geçiş reklamı UYGUN + HAZIR", ads.interstitial_eligible() and ads.is_interstitial_ready())
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var rounds_before: int = _rounds()
	var ok: bool = await _finish_with_pause(board)
	var timer: SceneTreeTimer = _last_timer
	var board_id: int = board.get_instance_id()
	var gen: int = _gen()
	var rounds: int = _rounds()
	var shows: int = fake.interstitial_shows.size()
	_c("kurulum: mola bitişten ÖNCE açıktı; bitiş anında mola KAPANDI, eylem 0", ok and not _af("pause")
		and _actions_in(_af("actions"), ["resume", "restart", "exit"]) == 0)
	await _after(timer, 0)
	var id: String = fake.interstitial_shows[-1] if fake.interstitial_shows.size() == shows + 1 else ""
	_c("gecikmeden sonra geçerli geçiş reklamı istendi (politika aynen); o anda mola KAPALI, sonuç yok",
		id != "" and ads.break_pending() and ads.interstitial_state() == MonetizationManager.InterstitialState.SHOWING
		and not _main.is_pause_open() and not _main._result.visible and _owns(board_id, gen))
	if id == "":
		_sections_done += 1
		return
	fake.emit_interstitial_showed(id)
	await _settle(1)
	_c("  … tam ekran reklam açıkken: mola kapalı, sonuç yok, board aynı", not _main.is_pause_open()
		and not _main._result.visible and _owns(board_id, gen))
	fake.emit_interstitial_dismissed(id)
	await _settle(3)
	print("    reklam kapanışı sonrası: sonuç görünür=%s (gösterim %d), mola görünür=%s" % [str(_main._result.visible), _shows,
		str(_main.is_pause_open())])
	_c("reklam kapandı → sonuç TAM bir kez (WIN), RESULT yüzeyi, 60 sn bekleme başladı; mola GERİ GELMEDİ",
		_main._result.visible and _shows == 1 and _main._result.mode() == _mode("WIN")
		and ads.surface() == MonetizationManager.Surface.RESULT and not _main.is_pause_open()
		and ads.fullscreen_cooldown_sec() > MonetizationManager.FULLSCREEN_AD_COOLDOWN_SEC - 1.0)
	await _wait(0.9)
	_c("  … sonra da: ikinci sonuç yok, mola yok, yönetici temiz", _shows == 1 and not _main.is_pause_open()
		and not ads.break_pending() and ads.interstitial_state() != MonetizationManager.InterstitialState.SHOWING)
	_c("  … ilerleme bir kez: tur kesinleşmede + 1, reklam / sonuç sonrası aynı", rounds == rounds_before + 1
		and _rounds() == rounds)
	await _back()
	_c("sonuçta Android geri yok sayılır, mola açılmaz", _main._result.visible and not _main.is_pause_open())
	await _finger_tap(_center(_main._result.secondary_button()))
	await _settle(3)
	_c("sonucun TEKRAR düğmesine gerçek dokunuş SONUCA gitti → yeni round (nesil + 1), mola eylemi 0",
		_actions["result_retry"] == 1 and _actions_in(_actions, ["resume", "restart", "exit"]) == 0
		and _differs(_main._board, board_id) and _gen() > gen and not _main._result.visible)
	_sections_done += 1


# --- D) Tekrar güvenliği ---------------------------------------------------------------------------------------

func _idempotent() -> void:
	print("-- D: temizlik tekrar güvenli — yinelenen çağrı / pencere yok / yinelenen round_finished")
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var has_cleanup: bool = _main.has_method(CLEANUP)
	_c("Main'de terminal pencere temizliği var (%s)" % CLEANUP, has_cleanup)
	if has_cleanup:
		_reset_actions()
		var gen0: int = _gen()
		_main.call(CLEANUP)
		_main.call(CLEANUP)
		await _settle(1)
		_c("canlı round'da, pencere yokken iki çağrı: hiçbir şey olmaz (board canlı, donuk değil, eylem 0, nesil aynı)",
			_main._board == board and not board.is_finished() and not board._is_paused() and _no_actions()
			and _gen() == gen0 and not _main.is_pause_open() and not _main._refill.visible)
	var ok: bool = await _finish_with_pause(board)
	var timer: SceneTreeTimer = _last_timer
	var bytes: PackedByteArray = _bytes()
	var rounds: int = _rounds()
	var gen: int = _gen()
	_c("kurulum: mola açıkken kesinleşti, bitişte kapandı", ok and not _af("pause"))
	if has_cleanup:
		_main.call(CLEANUP)
		_main.call(CLEANUP)
		await _settle(1)
		_c("bitmiş round'da temizliği iki kez daha çağırmak: eylem 0, board / nesil aynı, kayıt aynı, mola / refill kapalı",
			_actions_in(_actions, ["resume", "restart", "exit", "refill_ad", "refill_dough", "refill_closed"]) == 0
			and _main._board == board and _gen() == gen and _bytes() == bytes and not _main.is_pause_open()
			and not _main._refill.visible)
	var finalized: bool = _main._round_finalized
	board.round_finished.emit(true)
	await _settle(2)
	_c("yinelenen round_finished(true) (aynı board): ikinci kesinleşme yok — kayıt / tur aynı, eylem 0", finalized
		and _bytes() == bytes and _rounds() == rounds and _main._board == board
		and _actions_in(_actions, ["resume", "restart", "exit"]) == 0)
	await _after(timer)
	await _wait(0.3)
	_c("  … sonuç TAM bir kez (yinelenen sinyal ikinci sonuç / ikinci gecikme üretmedi), mola yok", _main._result.visible
		and _shows == 1 and not _main.is_pause_open())
	_sections_done += 1


# --- E) Eylemsiz kapanış: basılı parmak -------------------------------------------------------------------

func _held_finger() -> void:
	print("-- E: bitiş anında molada BASILI parmak — kapanış ve bırakış eylem yaymaz, parça düşürmez")
	# "+ olay": basıştan sonra işlenmemiş bir olay (eşlenmemiş tuş) gelir — Godot gizleme anında odaklı düğmeye sentetik
	# bırakış yollar ve girdi "işlendi" işaretli DEĞİLSE BaseButton onu tıklama sayar (A36: basılı Koleksiyon kartı +
	# GERİ). Bu durum yalnız düğmelerin kapalı-pencere koşulunu sınar; düz değişkeler parmak odağı yolunu.
	for variant: Array in [["yeniden başlat", false], ["yeniden başlat", true], ["ana menüye dön", false],
			["ana menüye dön", true], ["devam et", false], ["devam et", true], ["karartma", false], ["karartma", true]]:
		await _held_variant(String(variant[0]), bool(variant[1]))
	_sections_done += 1


func _held_variant(button: String, unhandled: bool) -> void:
	var target: String = button + (" + olay" if unhandled else "")
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var piece: Dumpling = await _piece(board)
	_reset_marks()
	await _fire_upgrade(board, piece)
	_main.open_pause_menu()
	await _settle(1)
	var pos: Vector2 = _pause_point(button)
	await _finger(pos, true)
	if unhandled:
		await _unhandled_key()
	var held: bool = _main.is_pause_open() and not board.is_finished() and is_instance_valid(piece) and piece.is_merging \
		and (not unhandled or not get_viewport().is_input_handled())
	var board_id: int = board.get_instance_id()
	var gen: int = _gen()
	await _until_finished(board)
	var timer: SceneTreeTimer = _last_timer
	_c("[%s] kurulum: mola açık, parmak düğmede / karartmada BASILI%s, dönüşüm sürüyordu → round bitti" % [target,
		", son olay işlenmemiş" if unhandled else ""], held and board.is_finished() and not _at_finish.is_empty())
	_c("[%s] bitişte mola kapandı; kapanış eylem yaymadı (Devam / Yeniden / Ana Menü 0), board + nesil aynı" % target,
		not _af("pause") and _actions_in(_af("actions"), ["resume", "restart", "exit"]) == 0
		and _owns(board_id, gen))
	await _finger(pos, false)
	await _physics(3)
	await _settle(2)
	_c("[%s] parmak kalkınca da eylem YOK (gizli molanın düğmesi / karartması bırakışı almadı), bırakış 0, board aynı" % target,
		_actions_in(_actions, ["resume", "restart", "exit"]) == 0 and _drops == 0 and _owns(board_id, gen)
		and board.is_finished() and not _main.is_pause_open())
	await _after(timer)
	_c("[%s] sonuç gecikmeden sonra tam bir kez, mola yok" % target, _main._result.visible and _shows == 1
		and not _main.is_pause_open() and _owns(board_id, gen))


## Molanın hedef noktası (pencere pikseli): üç düğme ya da karartmanın çerçeve dışındaki köşesi.
func _pause_point(target: String) -> Vector2:
	var buttons: Array[Button] = _main._pause.buttons()
	match target:
		"devam et":
			return _center(buttons[0])
		"yeniden başlat":
			return _center(buttons[1])
		"ana menüye dön":
			return _center(buttons[2])
	return _screen(Vector2(40.0, 60.0))


# --- F) Girdi sahipliği --------------------------------------------------------------------------------------

func _input_ownership() -> void:
	print("-- F: temizlikten sonra girdi — mola GERİ'yi / dokunuşu tutmaz, sonuç tutar")
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var ok: bool = await _finish_with_pause(board)
	var timer: SceneTreeTimer = _last_timer
	var board_id: int = board.get_instance_id()
	var gen: int = _gen()
	_c("kurulum: mola açıkken kesinleşti", ok)
	await _finger_tap(_screen(Vector2(360.0, 640.0)))
	await _finger_tap(_center(_main._pause.buttons()[1]))
	await _physics(3)
	_c("gecikmede molanın eski düğme / karartma noktalarına gerçek dokunuş: mola eylemi 0, bırakış 0, board aynı",
		_actions_in(_actions, ["resume", "restart", "exit"]) == 0 and _drops == 0 and _owns(board_id, gen)
		and not _main.is_pause_open())
	await _back()
	_c("  … gecikmede Android geri: mola yeniden AÇILMAZ (bitişten sonra mola kilidi aynen), board aynı",
		not _main.is_pause_open() and _owns(board_id, gen) and not _main._result.visible and timer.time_left > 0.0)
	await _after(timer)
	_c("sonuç açıldı; gizli pencere yok (mola / refill görünmez)", _main._result.visible and not _main.is_pause_open()
		and not _main._refill.visible)
	await _back()
	await _back()
	_c("iki Android geri: ikisi de sonuç ekranının kuralıyla yok sayıldı (mola açılmadı / kapanmadı, sonuç açık)",
		_main._result.visible and not _main.is_pause_open() and _no_actions())
	await _finger_tap(_center(_main._result.secondary_button()))
	await _settle(3)
	var next: Node2D = _main._board
	_track(next)
	_c("sonucun TEKRAR düğmesi gerçek dokunuşu aldı → yeni round (nesil + 1)", _actions["result_retry"] == 1
		and _differs(next, board_id) and _gen() > gen and not _main._result.visible)
	await _wait_settled()
	var dropped: bool = await _drop_ok(next)
	_c("  … yeni round gerçek dokunuşta tam 1 bırakış (gizli katman dokunuş yutmadı)", dropped)
	_sections_done += 1


# --- G) İlerleme ----------------------------------------------------------------------------------------------

func _progression() -> void:
	print("-- G: ilk kazanma mola açıkken (round'da gerçek merge + bonus sandık eşiği) — ilerleme TAM bir kez, bellek = disk")
	var bonus_due: Dictionary = {"merges_since_bonus_chest": 74}
	await _fresh(false, true, bonus_due)
	var control: Dictionary = await _first_clear(false)
	await _fresh(false, true, bonus_due)
	var run: Dictionary = await _first_clear(true)
	var s0: Dictionary = run["s0"]
	var s1: Dictionary = run["s1"]
	var stars: int = _level(5).stars_earned(true, TierConfig.merge_score(3))
	var award: int = PlayerProgression.round_xp_award(1, true, 0, stars)
	_c("kontrol (mola yok) ve deney (mola açıkken; bitişte kapandı) kesinleşti; ikisinde de round'da TAM 1 gerçek merge",
		control["ok"] and run["ok"] and control["merged"] and run["merged"] and run["pause_at_finish"] == false)
	_c("kesinleşme gecikmeden ÖNCE: tur + 1, XP + %d (merge + level + yıldız), level 6 açıldı, level 5'e %d yıldız" % [
		award, stars], int(s1["total_rounds_played"]) == int(s0["total_rounds_played"]) + 1
		and int(s1["player_xp"]) == int(s0["player_xp"]) + award and int(s1["highest_level_unlocked"]) == 6
		and int(s0["highest_level_unlocked"]) == 5 and int((s1["level_stars"] as Dictionary).get("5", 0)) == stars)
	_c("  … merge sayaçları bir kez: toplam merge + 1, 75'lik bonus sayaç 74 → 0 (eşik aşıldı)",
		int(s1["total_merges"]) == int(s0["total_merges"]) + 1 and int(s0["merges_since_bonus_chest"]) == 74
		and int(s1["merges_since_bonus_chest"]) == 0)
	_c("  … görev ilerlemesi bir kez: günlük tur + 1, günlük merge + 1, günlük level 1/1 (ödül verildi)",
		_mission(s1, "daily_rounds") == _mission(s0, "daily_rounds") + 1
		and _mission(s1, "daily_merges") == _mission(s0, "daily_merges") + 1 and _mission(s1, "daily_clear") == 1
		and _rewarded(s1).has("daily_clear") and not _rewarded(s0).has("daily_clear"))
	_c("  … sandıklar kesinleşmede TAM bir kez: sonuçta tam 2 kart (level sandığı + 75'lik bonus sandık) — deney %d, kontrol %d"
		% [int(run["cards"]), int(control["cards"])], int(run["cards"]) == 2 and int(control["cards"]) == 2)
	_c("  … Hamur yalnız kesinleşmenin ödülleriyle değişti: başlangıç + görev + sandık = kesinleşme sonrası (deney %s, kontrol %s)"
		% [run["dough_note"], control["dough_note"]], run["dough_ok"] and control["dough_ok"])
	# Sandık içerikleri rastgele (Hamur / skin) — karşılaştırma yalnız belirlenimci alanlarda; Hamur yukarıda tam uzlaşır.
	var keys: Array[String] = ["player_xp", "total_rounds_played", "highest_level_unlocked", "level_stars", "missions",
		"total_merges", "merges_since_bonus_chest", "highest_tier_created", "endless_high_score", "unlocked_achievements"]
	var same_delta: bool = true
	for key in keys:
		if JSON.stringify(_norm(_delta(run["s0"], run["s1"], key))) != JSON.stringify(_norm(_delta(control["s0"], control["s1"], key))):
			same_delta = false
			print("    fark: %s" % key)
	_c("  … deneyin kesinleşmesi molasız kontrolünkiyle AYNI (XP, tur, kilit, yıldız, görev, merge, bonus sayaç, başarım)",
		same_delta)
	_c("  … kayıt şeması aynı: deneyin ve kontrolün kayıt anahtarları birebir (yeni alan yok)",
		_keys(run["s1"]) == _keys(control["s1"]) and _keys(run["s1"]) == _keys(run["s0"]))
	_c("bellek = disk (kesinleşmeden hemen sonra)", run["disk_equal_1"])
	_c("gecikme + sonuç sonrası ilerleme GERİ ALINMADI, İKİLENMEDİ (bellek + disk kesinleşmedeki gibi), bellek = disk",
		_same(run["s3"], s1) and run["d3"] == run["d1"] and run["disk_equal_3"] and run["result"])
	_sections_done += 1


## Level 5 ilk kazanma (round'da önce 1 gerçek merge); `pause` ise mola açıkken (bitişte kapanır).
func _first_clear(pause: bool) -> Dictionary:
	var board: Node2D = await _start(_level(5))
	await _wait_settled()
	var merged: bool = await _merge_once(board)
	var s0: Dictionary = SaveManager.data.duplicate(true)
	var ok: bool = false
	if pause:
		ok = await _finish_with_pause(board)
	else:
		await _finish_now(board)
		ok = board.is_finished()
	var timer: SceneTreeTimer = _last_timer
	var out: Dictionary = {"ok": ok, "merged": merged, "s0": s0, "s1": SaveManager.data.duplicate(true), "d1": _bytes(),
		"pause_at_finish": bool(_at_finish.get("pause", true)), "disk_equal_1": _disk_equals_memory()}
	await _after(timer)
	await _wait(0.3)
	out["s3"] = SaveManager.data.duplicate(true)
	out["d3"] = _bytes()
	out["disk_equal_3"] = _disk_equals_memory()
	out["result"] = _main._result.visible and _shows == 1
	out["cards"] = _main._result.cards().size()
	var mission_dough: int = int((_main._result.progress_summary().get("missions", {}) as Dictionary).get("dough", 0))
	var chest_dough: int = _shown_chest_dough()
	out["dough_ok"] = int(out["s1"]["dough"]) == int(s0["dough"]) + mission_dough + chest_dough
	out["dough_note"] = "%d + %d + %d → %d" % [int(s0["dough"]), mission_dough, chest_dough, int(out["s1"]["dough"])]
	return out


## Gerçek bir merge (fizik): sol kenarda tabanda T2, üstüne bir T2 düşer → T3 (hedefin altında). Dönüş: round'un merge
## sayacı tam + 1 oldu mu.
func _merge_once(board: Node2D) -> bool:
	var before: int = GameState.merge_count
	var r: float = TierConfig.radius(2)
	var x: float = board._left_x() + r + 12.0
	board._spawn_dumpling(2, Vector2(x, _floor_y(board) - r - 1.0))
	board._spawn_dumpling(2, Vector2(x, _floor_y(board) - 3.0 * r - 30.0))
	var guard: int = 0
	while GameState.merge_count == before and guard < 600:
		await get_tree().physics_frame
		guard += 1
	await _physics(30)
	return GameState.merge_count == before + 1


## Açık sonucun sandık kartlarının Hamur'u (kesinleşmede yazılan).
func _shown_chest_dough() -> int:
	var total: int = 0
	var shown: Variant = _main._result.get("_rewards")
	if shown is Array:
		for reward: Variant in shown:
			if reward is ChestReward:
				total += (reward as ChestReward).dough
	return total


# --- H) TASK/048 savunması aynen ----------------------------------------------------------------------------

func _task048() -> void:
	print("-- H: TASK/048 sahipliği aynen — değiştirilen round eski sonuç / reklam açmaz, fırlatma ertelemesi")
	# H1 — kesinleşen round gecikme içinde ÜRETİM yeniden başlatma işleyicisiyle değiştirilir (mola artık bitişte kapalı:
	# işleyici, molanın kendi sinyaliyle — dar test dikişi). Eski sonuç / geçiş reklamı yok.
	await _fresh(true)
	var ads: MonetizationManager = _main._ads
	var fake: FakeAdBackend = ads._backend
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var ok: bool = await _finish_with_pause(board)
	var timer: SceneTreeTimer = _last_timer
	var shows: int = fake.interstitial_shows.size()
	var board_id: int = board.get_instance_id()
	await _until_left(timer, 0.4)
	_main._pause.restart_pressed.emit()
	var left: float = timer.time_left
	await _settle(2)
	var next: Node2D = _main._board
	_track(next)
	_c("H1 kurulum: bitişte mola kapandı; gecikme İÇİNDE (%.2f sn kala) üretim yeniden başlatma işleyicisi yeni board kurdu" % left,
		ok and not _af("pause") and _differs(next, board_id) and left > 0.0)
	await _after(timer)
	_c("H1: eski sonuç AÇILMADI, eski round geçiş reklamı DENEMEDİ (reklam uygun + hazır kaldı)", not _main._result.visible
		and _shows == 0 and fake.interstitial_shows.size() == shows
		and ads.interstitial_state() == MonetizationManager.InterstitialState.READY)
	await _wait_settled()
	var dropped: bool = await _drop_ok(next)
	_c("  … H1: yeni round etkin, gerçek dokunuşta tam 1 bırakış", dropped and _main._board == next and not next.is_finished())

	# H2 — fırlatma aralığı: reklam SDK'ya verildi, tam ekran henüz açılmadı → üretim yeniden başlatma işleyicisi
	# ERTELENİR, kapanışta eski sonucun YERİNE çalışır.
	await _fresh(true)
	ads = _main._ads
	fake = ads._backend
	board = await _start(_level(3))
	await _wait_settled()
	ok = await _finish_with_pause(board)
	timer = _last_timer
	board_id = board.get_instance_id()
	var gen: int = _gen()
	shows = fake.interstitial_shows.size()
	await _after(timer, 0)
	var id: String = fake.interstitial_shows[-1] if fake.interstitial_shows.size() == shows + 1 else ""
	_c("H2 kurulum: gecikme doldu, sahiplik doğrulandı → reklam SDK'ya VERİLDİ; mola kapalı, sonuç yok",
		ok and id != "" and ads.break_pending() and not _main.is_pause_open() and not _main._result.visible)
	if id != "":
		_main._pause.restart_pressed.emit()
		await _settle(2)
		_c("  … H2: fırlatma aralığında üretim yeniden başlatma işleyicisi ERTELENDİ (board + nesil aynı)",
			_owns(board_id, gen) and not _main._result.visible)
		fake.emit_interstitial_showed(id)
		await _settle(1)
		_c("  … H2: tam ekran reklam açıldığında ekranın sahibi hâlâ onu isteyen round", _owns(board_id, gen))
		fake.emit_interstitial_dismissed(id)
		await _settle(3)
		next = _main._board
		_c("  … H2: kapanışta ertelenen yeniden başlatma eski sonucun YERİNE çalıştı (yeni board, sonuç yok, mola yok)",
			_differs(next, board_id) and _gen() > gen and not _main._result.visible and _shows == 0
			and not _main.is_pause_open() and not ads.break_pending())
		_track(next)
		await _wait_settled()
		dropped = await _drop_ok(next)
		_c("  … H2: yeni board gerçek dokunuşta tam 1 bırakış", dropped)

	# H3 — geçerli round geçerli reklam + sonuç (aynı politika).
	await _fresh(true)
	ads = _main._ads
	fake = ads._backend
	board = await _start(_level(3))
	await _wait_settled()
	await _finish_now(board)
	shows = fake.interstitial_shows.size()
	await _after(_last_timer, 0)
	id = fake.interstitial_shows[-1] if fake.interstitial_shows.size() >= 1 else ""
	_c("H3: geçerli normal bitiş geçiş reklamını istedi", id != "" and ads.break_pending())
	if id != "":
		fake.emit_interstitial_showed(id)
		fake.emit_interstitial_dismissed(id)
		await _settle(3)
		_c("  … H3: kapanınca sonuç tam bir kez (WIN)", _main._result.visible and _shows == 1
			and _main._result.mode() == _mode("WIN"))
	_sections_done += 1


# --- I) Ayarlar ---------------------------------------------------------------------------------------------

func _settings() -> void:
	print("-- I: Ayarlar TASK/049 temizliğine girmez (genel pencere kuralı değil)")
	# I1 — Ayarlar bitiş ANINDA açık (HUD dişlisine dönüşüm sırasında gerçek dokunuş): kapanmaz.
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var piece: Dumpling = await _piece(board)
	_reset_marks()
	await _fire_upgrade(board, piece)
	await _finger_tap(_center(board._hud.settings_button))
	var open_first: bool = _main._settings.visible and not board.is_finished() and board._is_menu_paused
	await _until_finished(board)
	var timer: SceneTreeTimer = _last_timer
	_c("I1 kurulum: dönüşüm sırasında gerçek dişli dokunuşu Ayarlar'ı açtı (board donuk), round bitti", open_first
		and board.is_finished() and not _at_finish.is_empty())
	_c("I1: bitiş anında Ayarlar AÇIK KALDI (temizlik Ayarlar'ı kapatmaz), kapanış sinyali yok", _af("settings")
		and _actions_in(_af("actions"), ["settings_closed"]) == 0 and _main._settings.visible)
	await _after(timer)
	_c("  … I1: gecikmeden sonra sonuç açıldı, Ayarlar hâlâ üstünde (mevcut davranış — kayda geçen açık madde)",
		_main._result.visible and _shows == 1 and _main._settings.visible and _actions["settings_closed"] == 0)
	await _back()
	_c("  … I1: Android geri Ayarlar'ı kapattı (kendi kuralı), sonuç açık kaldı", not _main._settings.visible
		and _actions["settings_closed"] == 1 and _main._result.visible and not _main.is_pause_open())
	# I2 — Ayarlar gecikme İÇİNDE açılır: kapanmaz, sonuç altına açılır, KAPAT çalışır.
	await _fresh()
	board = await _start(_level(3))
	await _wait_settled()
	await _finish_now(board)
	timer = _last_timer
	await _until_left(timer, 0.5)
	await _finger_tap(_center(board._hud.settings_button))
	_c("I2: gecikme içinde gerçek dişli dokunuşu Ayarlar'ı açtı (mevcut davranış)", _main._settings.visible
		and timer.time_left > 0.0 and not _main._result.visible)
	await _after(timer)
	_c("  … I2: sonuç açıldı, Ayarlar kapanmadı (üstünde)", _main._result.visible and _main._settings.visible
		and _actions["settings_closed"] == 0)
	await _finger_tap(_center(_main._settings.frame().get_meta(&"close_button")))
	await _settle(2)
	_c("  … I2: Ayarlar'ın X'i gerçek dokunuşla kapattı, sonuç açık", not _main._settings.visible
		and _actions["settings_closed"] == 1 and _main._result.visible)
	_sections_done += 1


# --- J) Stok 0 refill penceresi -----------------------------------------------------------------------------

func _refill() -> void:
	print("-- J: stok 0 güç → refill penceresi Büyütücü dönüşümü sırasında — bitişte eylemsiz kapanır")
	# J1 — gerçek yol: Büyütücü düğmesi + hedef + stok 0 Bomba düğmesine gerçek dokunuş (refill açılır), dönüşüm biter.
	await _fresh(true, false)
	var ads: MonetizationManager = _main._ads
	var fake: FakeAdBackend = ads._backend
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var piece: Dumpling = await _piece(board)
	var dough: int = SaveManager.dough()
	var bomb: int = SaveManager.powerup_count(PowerUp.Type.BOMB)
	var quota: int = RewardedPolicy.remaining_today()
	var rewarded_shows: int = fake.rewarded_shows.size()
	_reset_marks()
	await _fire_upgrade(board, piece, true)
	var upgrade_after_use: int = SaveManager.powerup_count(PowerUp.Type.UPGRADE)
	await _finger_tap(_center(board._power_bar.slot(int(PowerUp.Type.BOMB))))
	var refill_first: bool = _main._refill.visible and board.is_refill_pending() and not board.is_finished() \
		and is_instance_valid(piece) and piece.is_merging
	await _until_finished(board)
	var timer: SceneTreeTimer = _last_timer
	_c("J1 kurulum (gerçek dokunuş): stok 0 Bomba → refill penceresi dönüşüm sürerken açıldı (board donuk), round bitti",
		refill_first and bomb == 0 and board.is_finished() and not _at_finish.is_empty())
	_c("J1: BİTİŞ ANINDA refill penceresi KAPANDI, board refill beklemesinde değil, donuk değil",
		not _af("refill") and not _af("refill_pending") and not _af("board_paused"))
	_c("  … eylemsiz: ödüllü istek / Hamurla alma / kapat sinyali 0, ödüllü reklam gösterilmedi",
		_actions_in(_actions, ["refill_ad", "refill_dough", "refill_closed"]) == 0
		and fake.rewarded_shows.size() == rewarded_shows)
	_c("  … stok / günlük ödüllü kota DEĞİŞMEDİ (Bomba %d → %d, Büyütücü kullanımda düşen %d, kota %d → %d)" % [bomb,
		int(_af("bomb")), upgrade_after_use, quota, int(_af("quota"))], int(_af("bomb")) == bomb
		and int(_af("quota")) == quota and int(_af("upgrade")) == upgrade_after_use)
	await _after(timer)
	var mission_dough: int = int((_main._result.progress_summary().get("missions", {}) as Dictionary).get("dough", 0))
	var chest_dough: int = _shown_chest_dough()
	_c("  … Hamur yalnız kesinleşmenin ödülleriyle değişti (%d + görev %d + sandık %d = %d), satın alma düşümü yok; sonra sabit"
		% [dough, mission_dough, chest_dough, int(_af("dough"))],
		int(_af("dough")) == dough + mission_dough + chest_dough and SaveManager.dough() == int(_af("dough"))
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == bomb and RewardedPolicy.remaining_today() == quota)
	_c("J1: gecikmeden sonra sonuç tam bir kez; refill penceresi sonucun üstünde DEĞİL", _main._result.visible
		and _shows == 1 and not _main._refill.visible and not _main.is_pause_open())
	await _back()
	_c("  … sonuçta Android geri yok sayılır; refill / mola açılmaz", _main._result.visible and not _main._refill.visible
		and not _main.is_pause_open() and _actions["refill_closed"] == 0)
	await _finger_tap(_center(_main._result.primary_button()))
	await _settle(2)
	_c("  … sonucun HARİTA düğmesine gerçek dokunuş SONUCA gitti (refill eylemi 0) → Harita", _actions["result_exit"] == 1
		and _actions_in(_actions, ["refill_ad", "refill_dough", "refill_closed"]) == 0 and _main._active_tab == 1
		and _main._board == null)

	# J2 / J3 — QA düzeyi (insan 0,15 sn'de yetişemez): refill'de REKLAM İZLE basılmış, ödüllü reklam açık, round biter.
	# Temizlik pencereyi kapatır ama açık talebe DOKUNMAZ: iptal etmez, ödül vermez; oyuncu ödülü kazanırsa kendi token
	# yolu verir (önceden de böyleydi — J2), kazanmazsa hiçbir şey verilmez, pencere geri gelmez (J3).
	await _refill_pending(true)
	await _refill_pending(false)
	_sections_done += 1


func _refill_pending(earned: bool) -> void:
	var tag: String = "J2 ödül kazanıldı" if earned else "J3 ödül kazanılmadı"
	await _fresh(true, false)
	var ads: MonetizationManager = _main._ads
	var fake: FakeAdBackend = ads._backend
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var piece: Dumpling = await _piece(board)
	var bomb: int = SaveManager.powerup_count(PowerUp.Type.BOMB)
	var quota: int = RewardedPolicy.remaining_today()
	var rewarded_shows: int = fake.rewarded_shows.size()
	_reset_marks()
	await _fire_upgrade(board, piece)
	board._power_bar.power_pressed.emit(int(PowerUp.Type.BOMB))
	await _settle(1)
	var ad_button: Button = _main._refill.get("_ad")
	if ad_button != null:
		ad_button.pressed.emit()
	await _settle(1)
	var requested: bool = fake.rewarded_shows.size() == rewarded_shows + 1 and int(_main._refill_pending_token) != 0
	await _until_finished(board)
	var timer: SceneTreeTimer = _last_timer
	_c("%s kurulum (QA): refill açık, REKLAM İZLE → ödüllü reklam istendi (talep token'ı açık), round bitti" % tag,
		requested and board.is_finished() and not _at_finish.is_empty())
	_c("  … bitişte refill penceresi kapandı; açık ödüllü talep İPTAL EDİLMEDİ ve ödül VERİLMEDİ (stok / kota aynı)",
		not _af("refill") and int(_main._refill_pending_token) != 0 and not bool(ads._request.get("cancelled", true))
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == bomb and RewardedPolicy.remaining_today() == quota)
	var shown: String = fake.rewarded_shows[-1] if fake.rewarded_shows.size() > rewarded_shows else ""
	if shown != "":
		fake.emit_rewarded_showed(shown)
		if earned:
			fake.emit_rewarded_earned(shown, "coins", 1)
		fake.emit_rewarded_dismissed(shown)
	await _settle(3)
	if earned:
		_c("  … oyuncu ödülü kazandı → kendi token yolu stoğu verdi (+1 Bomba, kota - 1), token kapandı; pencere yeniden "
			+ "AÇILMADI; bellek = disk", SaveManager.powerup_count(PowerUp.Type.BOMB) == bomb + 1
			and RewardedPolicy.remaining_today() == quota - 1 and int(_main._refill_pending_token) == 0
			and not _main._refill.visible and _disk_equals_memory())
	else:
		_c("  … ödülsüz kapanış → hiçbir şey verilmedi (stok / kota aynı), token kapandı, pencere yeniden AÇILMADI; bellek = disk",
			shown != "" and SaveManager.powerup_count(PowerUp.Type.BOMB) == bomb and RewardedPolicy.remaining_today() == quota
			and int(_main._refill_pending_token) == 0 and not _main._refill.visible and _disk_equals_memory())
	await _after(timer)
	await _settle(2)
	_c("  … sonuç tam bir kez, refill / mola üstünde değil", _main._result.visible and _shows == 1
		and not _main._refill.visible and not _main.is_pause_open())


# --- K) Normal kayıp ----------------------------------------------------------------------------------------

func _normal_loss() -> void:
	print("-- K: normal kayıp aynen (kayıp molada oluşamaz — mola yolu uydurulmaz)")
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var s0: Dictionary = SaveManager.data.duplicate(true)
	await _loss(board)
	var timer: SceneTreeTimer = _last_timer
	var s1: Dictionary = SaveManager.data.duplicate(true)
	_c("kayıp kesinleşti (devam reddi — üretim yolu): tur + 1, teselli yazıldı; bitişte pencere yoktu", board.is_finished()
		and int(s1["total_rounds_played"]) == int(s0["total_rounds_played"]) + 1 and not _same(s1, s0)
		and not _af("pause") and not _af("refill"))
	_main.open_pause_menu()
	await _settle(1)
	_c("RESULT_DELAY aralığında mola AÇILMAZ (mevcut kilit aynen)", not _main.is_pause_open())
	await _after(timer)
	_c("geçerli kayıp sonucu: FAIL, level 3, tam bir kez; ilerleme sonradan değişmedi", _main._result.visible
		and _main._result.mode() == _mode("FAIL") and _shown_level() == 3 and _shows == 1 and _same(SaveManager.data, s1))
	_c("  … eylem yok", _no_actions())
	_sections_done += 1


# --- L) Sonsuz ------------------------------------------------------------------------------------------------

func _endless() -> void:
	print("-- L: Sonsuz aynen")
	await _fresh()
	var board: Node2D = await _start(load(ENDLESS))
	await _wait_settled()
	await _loss(board)
	await _after(_last_timer)
	_c("Sonsuz sonucu: ENDLESS, tam bir kez, eylem yok", _main._result.visible and _main._result.mode() == _mode("ENDLESS")
		and _shows == 1 and _no_actions() and not _main.is_pause_open())
	_main.open_pause_menu()
	await _settle(1)
	_c("  … sonuç açıkken mola açılmaz", not _main.is_pause_open())
	_sections_done += 1


# --- M) Meydan okuma ------------------------------------------------------------------------------------------

func _challenge() -> void:
	print("-- M: meydan okuma aynen — kendi işleyicisi, geçiş reklamı denemesi yok")
	await _fresh(true)
	var ads: MonetizationManager = _main._ads
	var fake: FakeAdBackend = ads._backend
	var shows: int = fake.interstitial_shows.size()
	var dough: int = SaveManager.dough()
	AdEvents.clear_recent()
	var started: bool = _main.start_daily_challenge()
	await _settle(3)
	var challenge: Node2D = _main._board
	_track(challenge)
	_c("ön koşul: meydan okuma başladı, güçler KAPALI (Büyütücü dönüşüm yolu yok), kendi bitiş işleyicisi", started
		and challenge != null and challenge.is_daily_challenge() and not challenge.powers_enabled()
		and not challenge.round_finished.is_connected(_main._on_round_finished))
	_main.open_pause_menu()
	await _settle(1)
	var paused: bool = _main.is_pause_open() and challenge._is_menu_paused
	_main.resume_game()
	await _settle(1)
	_c("  … meydan okumada mola açılır / DEVAM ET kapatır (aynı pencere)", paused and not _main.is_pause_open()
		and not challenge._is_paused())
	await _win_merge(challenge)
	await _after(_last_timer)
	_c("meydan okuma sonucu aynen: CHALLENGE_WIN, tam bir kez, +20 Hamur bir kez", _main._result.visible
		and _main._result.mode() == _mode("CHALLENGE_WIN") and _shows == 1 and SaveManager.dough() == dough + 20)
	_c("  … geçiş reklamı denemesi YOK (reklam uygun + hazırken), eylem yok", fake.interstitial_shows.size() == shows
		and AdEvents.count(&"interstitial_skipped_not_ready") == 0 and _no_actions())
	_sections_done += 1


# --- N) Tutorial ----------------------------------------------------------------------------------------------

func _tutorial() -> void:
	print("-- N: tutorial aynen")
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
	await _back()
	_c("tutorial'da Android geri: tutorial onayı, mola AÇILMAZ", _main._tutorial.is_back_prompt_open()
		and not _main.is_pause_open())
	await _back()
	tutorial.skip()
	await _settle(2)
	_c("ATLA: onboarding tamamlandı, round sürüyor", SaveManager.onboarding_completed() and not _main.is_tutorial_active()
		and _main._board == board and not board.is_finished())
	await _win_merge(board)
	await _after(_last_timer)
	_c("tutorial round'unun kazanma sonucu: WIN, level 1, tam bir kez, eylem yok", _main._result.visible
		and _main._result.mode() == _mode("WIN") and _shown_level() == 1 and _shows == 1 and _no_actions())
	_sections_done += 1


# --- O) ACTION_CANCEL / dokunuş -------------------------------------------------------------------------------

func _cancel_touch() -> void:
	print("-- O: ACTION_CANCEL 0 bırakış, sonraki bağımsız dokunuş 1; temizlik yeni round'a sızmaz")
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var at: Vector2 = _board_point(board, -90.0)
	await _finger(at, true)
	await _cancel(at)
	await _physics(3)
	_c("iptal edilen dokunuş (ACTION_CANCEL): 0 bırakış", _drops == 0)
	var dropped: bool = await _drop_ok(board)
	_c("  … sonraki bağımsız dokunuş: tam 1 bırakış", dropped)
	var ok: bool = await _finish_with_pause(board)
	var timer: SceneTreeTimer = _last_timer
	var drops: int = _drops
	await _finger_tap(_board_point(board, 40.0))
	await _physics(3)
	_c("mola bitişte kapandı; gecikmede bitmiş board'a dokunuş bırakış ÜRETMEZ", ok and not _af("pause")
		and _drops == drops)
	await _after(timer)
	await _finger_tap(_center(_main._result.secondary_button()))
	await _settle(3)
	var next: Node2D = _main._board
	_track(next)
	await _physics(3)
	_c("TEKRAR → yeni round: temizlikten kalan bırakış yok (yeni board boş)", next != null and next != board
		and next.live_dumplings().is_empty() and _drops == drops)
	await _wait_settled()
	dropped = await _drop_ok(next)
	_c("  … yeni round'da ilk bağımsız dokunuş tam 1 bırakış", dropped)
	_sections_done += 1


# --- Q) Bitmemiş round'da gerçek mola düğmeleri ---------------------------------------------------------------

func _live_pause() -> void:
	print("-- Q: bitmemiş round'da GERÇEK mola düğmeleri aynen (Devam Et / karartma / Yeniden Başlat / Ana Menüye Dön)")
	for action: String in ["devam et", "karartma", "yeniden başlat", "ana menüye dön"]:
		await _fresh()
		var board: Node2D = await _start(_level(3))
		await _wait_settled()
		var board_id: int = board.get_instance_id()
		var gen: int = _gen()
		await _finger_tap(_center(board._hud.back_button))
		await _settle(2)
		var opened: bool = _main.is_pause_open() and board._is_menu_paused and not board.is_finished()
		await _wait_settled()
		await _finger_tap(_pause_point(action))
		await _settle(2)
		await _physics(3)
		match action:
			"devam et", "karartma":
				_c("[%s] gerçek HUD geri molayı açtı (board donuk); gerçek dokunuş devam ettirdi: mola kapalı, board aynı, donuk değil, Devam 1, bırakış 0"
					% action, opened and not _main.is_pause_open() and _owns(board_id, gen) and not board._is_paused()
					and _actions["resume"] == 1 and _actions_in(_actions, ["restart", "exit"]) == 0 and _drops == 0)
				await _wait_settled()
				var dropped: bool = await _drop_ok(board)
				_c("  … [%s] round sürüyor: gerçek dokunuşta tam 1 bırakış" % action, dropped)
			"yeniden başlat":
				var next: Node2D = _main._board
				_track(next)
				_c("[%s] gerçek dokunuş yeni board kurdu (nesil + 1, Yeniden 1), dokunuş yeni board'a SIZMADI (parça yok, bırakış 0)"
					% action, opened and _differs(next, board_id) and _gen() > gen and _actions["restart"] == 1
					and not _main.is_pause_open() and next.live_dumplings().is_empty() and _drops == 0)
				await _wait_settled()
				var dropped_next: bool = await _drop_ok(next)
				_c("  … [%s] yeni round gerçek dokunuşta tam 1 bırakış" % action, dropped_next)
			_:
				_c("[%s] gerçek dokunuş round'u terk etti → Harita (Ana Menü 1, board yok, sonuç yok, ilerleme yazılmadı)" % action,
					opened and _actions["exit"] == 1 and _main._board == null and _main._active_tab == 1
					and not _main._result.visible and _rounds() == 12)
	_sections_done += 1


# --- R) Başka bitiş yolu: aynı karede merge ----------------------------------------------------------------

func _merge_path() -> void:
	print("-- R: aynı karede merge — mola açıldıktan sonra raporlanan temas round'u molada bitirir → aynı temizlik")
	# Fizik adımı teması kaydeder, raporu (body_entered) bir sonraki adımın başında gelir: o arada girdi molayı açmış
	# olabilir. Dumpling._on_body_entered'ın yaptığı (iki parçayı kilitle + merge_requested) burada aynen yapılır (dar
	# dikiş); board'un ertelenmiş _resolve_merge'i molayı denetlemez → hedef merge round'u molada bitirir.
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var tier: int = board.level.target_tier - 1
	var r: float = TierConfig.radius(tier)
	var a: Dumpling = board._spawn_dumpling(tier, Vector2(board._left_x() + r + 8.0, _floor_y(board) - r - 1.0))
	var b: Dumpling = board._spawn_dumpling(tier, Vector2(board._right_x() - r - 8.0, _floor_y(board) - r - 1.0))
	await _physics(20)
	_reset_marks()
	var board_id: int = board.get_instance_id()
	var gen: int = _gen()
	_main.open_pause_menu()
	var paused: bool = _main.is_pause_open() and board._is_menu_paused and not board.is_finished()
	a.is_merging = true
	b.is_merging = true
	a.merge_requested.emit(a, b, (a.global_position + b.global_position) * 0.5)
	await _until_finished(board)
	var timer: SceneTreeTimer = _last_timer
	_c("kurulum: mola açıktı (board donuk), ertelenmiş hedef merge round'u molada bitirdi", paused and board.is_finished()
		and not _at_finish.is_empty())
	_c("BİTİŞ ANINDA mola kapandı, menü dondurması bırakıldı, eylem 0, board + nesil aynı", not _af("pause")
		and not _af("menu_paused") and _actions_in(_af("actions"), ["resume", "restart", "exit"]) == 0 and _af("board")
		and _af("gen") == gen)
	await _after(timer)
	_c("gecikmeden sonra sonuç tam bir kez (WIN), mola sonucun üstünde değil, board aynı", _main._result.visible
		and _main._result.mode() == _mode("WIN") and _shows == 1 and not _main.is_pause_open() and _owns(board_id, gen))
	_sections_done += 1


# --- P) Kaynak sözleşmesi -----------------------------------------------------------------------------------

func _source_contract() -> void:
	print("-- P: kaynak sözleşmesi")
	var src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var code: String = _strip_comments(src)
	var board_code: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/game/game_board.gd"))
	var pause_code: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/pause_menu.gd"))
	var constants: Dictionary = _main_script.get_script_constant_map()
	_c("RESULT_DELAY aynen 0,8 sn", is_equal_approx(float(constants["RESULT_DELAY"]), 0.8))
	_c("TOUCH_SETTLE_MSEC aynen 300 (TASK/045.2)", int(constants["TOUCH_SETTLE_MSEC"]) == 300)
	_c("TASK/046.2 iptal koruması aynen", FileAccess.get_file_as_string("res://scripts/game/game_board.gd")
		.contains("\telif not touch.canceled:"))
	_c("geçiş reklamı tek çağrı noktası (Main round bitişi)", code.count("_ads.try_show_interstitial(") == 1)
	var helper: String = _function(code, "func %s(" % CLEANUP)
	_c("terminal pencere temizliği tek fonksiyonda: molayı close_menu ile, refill'i hide_refill ile kapatır",
		helper != "" and helper.contains("_pause.close_menu()") and helper.contains("_refill.hide_refill()"))
	var forbidden: Array[String] = ["_settings", "close_settings", "_daily_rewards", "_chest_info", "_missions",
		"_challenge_sheet", "_age_panel", "resume_game(", "_on_pause_restart(", "abandon_run(", "_start_level(",
		"_clear_board(", "_finish_refill(", "_on_refill_closed(", "grant_", "save_game", "SaveManager",
		"_cancel_rewarded_request(", "_clear_refill_request(", "_show_tab(", "_result.", "emit("]
	var leaks: Array[String] = []
	for token in forbidden:
		if helper.contains(token):
			leaks.append(token)
	_c("  … temizlik Ayarlar'a / ikincil pencerelere / gezinmeye / round değişimine / kayda / ödüllü talebe dokunmaz%s"
		% ("" if leaks.is_empty() else " (sızan: %s)" % ", ".join(leaks)), helper != "" and leaks.is_empty())
	var finish_fn: String = _function(code, "func _on_round_finished(")
	var guard: int = finish_fn.find("_round_finalized = true")
	var call_at: int = finish_fn.find("%s()" % CLEANUP)
	var waited: int = finish_fn.find("await get_tree().create_timer(RESULT_DELAY).timeout")
	var written: int = maxi(finish_fn.find("SaveManager.record_round_finished("), finish_fn.find("progress[\"missions\"] = missions"))
	_c("normal bitiş: temizlik kesinleştirme korumasından SONRA, round'un ilerlemesi yazıldıktan SONRA, gecikmeden ÖNCE ve tek kez",
		guard >= 0 and written > guard and call_at > written and waited > call_at
		and finish_fn.count("%s()" % CLEANUP) == 1)
	var call_sites: int = code.count("%s()" % CLEANUP) - code.count("func %s()" % CLEANUP)
	_c("  … temizlik yalnız normal bitişte: meydan okuma işleyicisi çağırmaz (TASK/047 aynen), başka çağıran yok (%d)"
		% call_sites, not _function(code, "func _on_challenge_round_finished(").contains(CLEANUP) and call_sites == 1)
	var board_finish: String = _function(board_code, "func _finish(")
	_c("GameBoard._finish menü dondurmasını da bırakır (refill / devam / tutorial dondurmalarıyla birlikte, sinyalden ÖNCE)",
		board_finish.contains("_is_menu_paused = false") and board_finish.find("_is_menu_paused = false")
		< board_finish.find("round_finished.emit("))
	var gate: String = _function(pause_code, "func _emit_if_open(")
	var direct: int = pause_code.count("resume_pressed.emit()") + pause_code.count("restart_pressed.emit()") \
		+ pause_code.count("exit_pressed.emit()")
	_c("PauseMenu: kapalı pencere eylem yaymaz — üç düğme + X + karartma (5 kanca) tek görünürlük kapısından, doğrudan yayım yok",
		gate.contains("if visible:") and gate.contains("action.emit()") and gate.find("if visible:") < gate.find("action.emit()")
		and pause_code.count("_emit_if_open.bind(") == 5 and direct == 0
		and pause_code.contains("UiKit.attach_dim_close(_dim, _emit_if_open.bind(resume_pressed))"))
	_c("TASK/048 sahipliği aynen: nesil kontrolleri + fırlatma ertelemesi yerinde",
		finish_fn.contains("_round_still_owned(") and _function(code, "func _present_result(").contains("_round_still_owned(")
		and _function(code, "func _on_pause_restart(").contains("_defer_round_change(")
		and _function(code, "func abandon_run(").contains("_defer_round_change("))
	_sections_done += 1


# --- Yardımcılar ------------------------------------------------------------------------------------------

func _fixture(extra: Dictionary = {}) -> Dictionary:
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 2},
		"endless_high_score": 0, "dough": 335, "total_merges": 40, "merges_since_bonus_chest": 10,
		"unlocked_skins": ["common_01", "rare_02"], "profile_showcase": ["rare_02"],
		"powerups": {"bomb": 0, "upgrade": 9, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
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


## Temiz kayıt + Main. `with_ads`: sahte reklam arka ucu (rıza + init + ödüllü hazır); `interstitial`: geçiş reklamı
## da hazır + uygun (aktif süre eşiği dolmuş).
func _fresh(with_ads: bool = false, interstitial: bool = true, extra: Dictionary = {}) -> void:
	await _teardown_main()
	_clean()
	DailyRewards.clock_override = THU
	_write_fixture(extra)
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
	if interstitial:
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
	_reset_actions()
	_main._result.visibility_changed.connect(func() -> void:
		if _main != null and is_instance_valid(_main) and _main._result.visible:
			_shows += 1
			_result_msec = Time.get_ticks_msec())
	_main._pause.resume_pressed.connect(func() -> void: _actions["resume"] += 1)
	_main._pause.restart_pressed.connect(func() -> void: _actions["restart"] += 1)
	_main._pause.exit_pressed.connect(func() -> void: _actions["exit"] += 1)
	_main._refill.rewarded_refill_requested.connect(func(_type: int) -> void: _actions["refill_ad"] += 1)
	_main._refill.dough_refill_requested.connect(func(_type: int) -> void: _actions["refill_dough"] += 1)
	_main._refill.closed.connect(func() -> void: _actions["refill_closed"] += 1)
	_main._settings.closed.connect(func() -> void: _actions["settings_closed"] += 1)
	_main._result.retry_pressed.connect(func() -> void: _actions["result_retry"] += 1)
	_main._result.exit_pressed.connect(func() -> void: _actions["result_exit"] += 1)


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _settle(2)


func _reset_actions() -> void:
	for key in ACTION_KEYS:
		_actions[key] = 0


func _reset_marks() -> void:
	_finish_msec = -1
	_pause_msec = -1
	_result_msec = -1
	_at_finish = {}


func _no_actions() -> bool:
	return _actions_in(_actions, ACTION_KEYS) == 0


func _actions_in(source: Dictionary, keys: Array) -> int:
	var total: int = 0
	for key: String in keys:
		total += int(source.get(key, 0))
	return total


## Normal round başlatma (Main'in Harita / sonuç / mola yolunun ortak girişi).
func _start(level: LevelData) -> Node2D:
	_main._start_level(level)
	await _settle(3)
	var board: Node2D = _main._board
	_track(board)
	return board


## Bırakış sayacı + bitiş izleyicisi (Main'in işleyicisinden SONRA bağlı): bitişin eşzamanlı sonucu + Main'in
## RESULT_DELAY zamanlayıcısıyla aynı süreli bir SceneTree zamanlayıcısı.
func _track(board: Node2D) -> void:
	if board == null or board.has_meta(&"qa_tracked"):
		return
	board.set_meta(&"qa_tracked", true)
	board.dumpling_dropped.connect(func(_tier: int) -> void: _drops += 1)
	board.round_finished.connect(func(_won: bool) -> void:
		_finish_msec = Time.get_ticks_msec()
		_last_timer = get_tree().create_timer(_delay())
		_at_finish = _snapshot(board))


## Bitiş görüntüsünden bir alan; görüntü yoksa (kurulum başarısız) kontrolü DÜŞÜREN değer — betik hatası değil FAIL.
func _af(key: String) -> Variant:
	if _at_finish.has(key):
		return _at_finish[key]
	match key:
		"settings", "board":
			return false
		"gen", "dough", "bomb", "upgrade", "quota":
			return -999
		"actions":
			var spoiled: Dictionary = {}
			for name in ACTION_KEYS:
				spoiled[name] = 999
			return spoiled
	return true


## Kabul edilen bitişin eşzamanlı sonucu: Main'in round_finished işleyicisi ilk `await`'e kadar çalıştı.
func _snapshot(board: Node2D) -> Dictionary:
	return {"pause": _main.is_pause_open(), "refill": _main._refill.visible, "settings": _main._settings.visible,
		"menu_paused": bool(board.get("_is_menu_paused")), "board_paused": board._is_paused(),
		"refill_pending": board.is_refill_pending(), "result": _main._result.visible, "gen": _gen(),
		"board": _main._board == board, "actions": _actions.duplicate(), "dough": SaveManager.dough(),
		"bomb": SaveManager.powerup_count(PowerUp.Type.BOMB), "upgrade": SaveManager.powerup_count(PowerUp.Type.UPGRADE),
		"quota": RewardedPolicy.remaining_today()}


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


## Mola AÇIKKEN kazanma (üretim yolu): Büyütücü dönüşümü başlar, anticipation içinde mola açılır, dönüşüm hedefe
## ulaşıp round'u bitirir. `opener`: "hud" = HUD geri düğmesine GERÇEK dokunuş, "back" = Android geri (Main'in
## GO_BACK yönlendirmesi), "call" = mola işleyicisi (`open_pause_menu` — ikisinin de vardığı yer). `real_button`:
## Büyütücü düğmesine gerçek dokunuş. Dönüş: kurulum doğru mu (mola bitişten ÖNCE açıktı, dönüşüm sürüyordu, round
## bitti). Bitişin eşzamanlı sonucu `_at_finish`'te.
func _finish_with_pause(board: Node2D, opener: String = "call", real_button: bool = false, frames: int = 8) -> bool:
	var piece: Dumpling = await _piece(board, -1, frames)
	if opener == "back":
		# Main'in 250 ms geri debounce'u dönüşüm SIRASINDA yutmasın: önceki geriden yeterince uzaklaş (önce bekle).
		while Time.get_ticks_msec() - int(_main.get("_last_back_msec")) < BACK_GAP_MSEC:
			await get_tree().process_frame
	_reset_marks()
	await _fire_upgrade(board, piece, real_button)
	match opener:
		"hud":
			await _finger_tap(_center(board._hud.back_button))
		"back":
			_last_back_msec = Time.get_ticks_msec()
			get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
		_:
			_main.open_pause_menu()
	_pause_msec = Time.get_ticks_msec()
	var paused_first: bool = _main.is_pause_open() and not board.is_finished() and is_instance_valid(piece) \
		and piece.is_merging and board._is_menu_paused
	await _until_finished(board)
	return paused_first and board.is_finished() and not _at_finish.is_empty()


## Molasız kazanma: Büyütücü dönüşümü hedefe ulaşır.
func _finish_now(board: Node2D, frames: int = 8) -> void:
	var piece: Dumpling = await _piece(board, -1, frames)
	_reset_marks()
	await _fire_upgrade(board, piece)
	await _until_finished(board)


## Gerçek merge ile hedef: sağ kenarda tabandaki (hedef − 1) tier parçasının üstüne aynısı düşer.
func _win_merge(board: Node2D) -> void:
	_reset_marks()
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
	_reset_marks()
	board._enter_fail_pending()
	await _settle(2)
	_main.decline_revive()
	await _settle(1)


## Round bitene kadar (kare + duvar saati sınırı — dönüşüm 0,15 sn).
func _until_finished(board: Node2D, max_msec: int = 3000) -> void:
	var limit: int = Time.get_ticks_msec() + max_msec
	while is_instance_valid(board) and not board.is_finished() and Time.get_ticks_msec() < limit:
		await get_tree().process_frame


## Yeni board mı: geçerli ve kimliği eskisinden farklı (serbest bırakılmış düğüm null gibi karşılaştırılır).
func _differs(board: Variant, old_id: int) -> bool:
	return board != null and is_instance_valid(board) and (board as Object).get_instance_id() != old_id


## Ekranın sahibi hâlâ verilen round mu: aynı board (kimlik) + aynı nesil.
func _owns(board_id: int, gen: int) -> bool:
	return _main._board != null and is_instance_valid(_main._board) and _main._board.get_instance_id() == board_id \
		and _gen() == gen


## Board'a gerçek parmak dokunuşu → tam 1 bırakış mı.
func _drop_ok(board: Node2D) -> bool:
	var before: int = _drops
	await _finger_tap(_board_point(board, -90.0))
	await _physics(3)
	return _drops == before + 1


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


func _keys(state: Dictionary) -> String:
	var names: Array = state.keys()
	names.sort()
	return JSON.stringify(names)


## Bir anahtarın iki durum arasındaki farkı (karşılaştırma için kaba gösterim).
func _delta(before: Dictionary, after: Dictionary, key: String) -> Variant:
	var a: Variant = _norm(before.get(key))
	var b: Variant = _norm(after.get(key))
	if typeof(a) == TYPE_INT and typeof(b) == TYPE_INT:
		return int(b) - int(a)
	return [a, b]


## Diskteki kayıt bellektekiyle aynı mı (JSON sayı normalizasyonuyla).
func _disk_equals_memory() -> bool:
	if not FileAccess.file_exists(PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed is Dictionary and _same(parsed, SaveManager.data)


func _delay() -> float:
	return float(_main_script.get_script_constant_map()["RESULT_DELAY"])


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


## Hiçbir şeyin işlemediği bir girdi olayı (eşlenmemiş tuş, basış + bırakış): ardından Viewport'un "işlendi" bayrağı
## kapalı kalır — gerçek cihazda ör. GERİ tuşunun KeyEvent'i ya da başka bir girdi aygıtı.
func _unhandled_key() -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_F13
		key.physical_keycode = KEY_F13
		key.pressed = pressed
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		await get_tree().process_frame


## Android ACTION_CANCEL: bırakış `canceled == true` (TASK/046.2).
func _cancel(pos: Vector2, index: int = 0) -> void:
	var touch := _touch_event(pos, false, index)
	touch.canceled = true
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	await get_tree().process_frame


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
