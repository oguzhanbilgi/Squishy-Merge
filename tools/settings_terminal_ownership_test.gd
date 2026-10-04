extends Node
## TASK/053 — Ayarlar / terminal sonuç sahipliği: kabul edilen round bitişinden sonra ön planın sahibi SONUÇTUR. Bitişten
## ÖNCE açılmış Ayarlar sonucun üstünde kalmaz; bekleme (RESULT_DELAY / geçiş reklamı molası) İÇİNDE ya da sonuç açıkken
## açılmaya çalışılan Ayarlar açılmaz; kapanmış Ayarlar'ın bayat geri çağrısı tercih yazmaz, pencere açmaz. Bitiş dışında
## Ayarlar (HUD dişlisi, Profil dişlisi, anahtarlar, KAPAT / X / karartma / Android GERİ) AYNEN.
## Gerçek Main, gerçek board, gerektiğinde sahte reklam arka ucu. Headless.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_settings_terminal/` altındaki bir yola
## yönlendirilir, sonda geri alınır; gerçek kayıt ailesi (kanonik + .tmp + .bak) başta / sonda bayt bayt karşılaştırılır.
##   godot --headless --audio-driver Dummy --path . res://tools/settings_terminal_ownership_test.tscn
##
## Kök neden (taban 5b7a727): Ayarlar katman 13, sonuç katman 10 — ikisi birden görünürse Ayarlar her zaman üstte, karartması
## sonucun girdisini tutar.
##   (1) TASK/049'un terminal temizliği (`_dismiss_terminal_gameplay_overlays`, normal + TASK/050 meydan okuma bitişi)
##       Ayarlar'ı bilerek dışarıda bırakıyordu: bitişte açık Ayarlar (Büyütücü dönüşümü / aynı karede merge menü
##       dondurmasında da tamamlanır) sonuç açıldığında hâlâ üstündeydi.
##   (2) HUD dişlisinin yolu (`_on_board_settings_requested` → `open_settings`) round'un kesinleştiğine bakmıyordu (mola
##       — `open_pause_menu` — bakıyor): gecikme / reklam molası içinde dişli Ayarlar'ı açıyor, sonuç onun altına açılıyordu;
##       ertelenen yeniden başlatma (TASK/048) yeni round'u da Ayarlar'ın altında başlatıyordu.
##
## Bitiş anı ölçümü (TASK/049 / 050 suite'leriyle aynı): izleyici round_finished'e Main'den SONRA bağlanır → Main'in
## işleyicisi ilk `await`'e kadar çalışmış olur; "bitiş anı" görüntüsü kabul edilen bitişin eşzamanlı sonucudur. Olay
## kaydı (`_events`) pencerelerin `visibility_changed`'ini ve izleyicinin "finish" anını sırayla tutar (+ms).
##
## Bölümler:
##   A bitişte açık  GERÇEK yol — Büyütücü dönüşümü sırasında HUD dişlisine gerçek dokunuş: bitişte Ayarlar kapanır (kapanış
##                   1), menü dondurması bırakılır, sonuç gecikmeden sonra tek başına bir kez; sonuçta GERİ yok sayılır
##   B beklemede     gecikme içinde gerçek dişli / HUD işleyicisi / doğrudan `open_settings` (false döner), sonuç açıkken,
##                   geçiş reklamı molasında: Ayarlar açılmaz, board donmaz, sonuç tek başına bir kez. Gerçek dişli
##                   denetimlerinde pozitif kontrol: dokunuş dişliye ULAŞTI (board.settings_requested + 1)
##   C normal        canlı round + kabuk: dişli açar + board donar, Ayarlar açıkken mola açılmaz, anahtar tercihi yazar,
##                   KAPAT / X / karartma kapatır, round sürer; Profil dişlisi; terminal round'dan çıktıktan sonra da açılır
##   D GERİ          Ayarlar'dan GERİ (bitiş dışında) aynen; bitişte kapanan Ayarlar'dan sonra gecikmede / sonuçta GERİ
##                   hiçbir şey açmaz
##   E mola/refill   (gerçek girdiyle aynı anda AÇILAMAZ — kod yolu) mola + Ayarlar, refill + Ayarlar → bitişte hepsi kapanır,
##                   eylem yok, sıra kaydı
##   F dondurma      menü dondurması sızmaz: bitişte, reddedilen dişliden sonra, sonraki round'da; reddedilen açılış board'a
##                   HİÇ dokunmaz (F4: canlı board + kapalı kapı, dar dikiş — GameBoard'un bitmiş-board korumasından bağımsız)
##   G meydan        meydan okuma: aynı karede merge Ayarlar AÇIKKEN (gerçek dişli) bitirir → bitişte kapanır, +20 bir kez,
##                   sonuç tek başına; gecikmede dişli reddedilir; çıkıştan sonra Profil dişlisi açar
##   H TASK/048      gecikmede üretim yeniden başlatma; reklam molasında ertelenen yeniden başlatma — yeni round Ayarlar'sız
##   I tekrar        TEKRAR / çıkış / yeni round Ayarlar'ı diriltmez; yeni round'da dişli normal
##   J yinelenen     ikinci round_finished / ikinci temizlik: ikinci kapanış / ikinci sonuç yok
##   K tercih        temizlik tercih yazmaz (ses / titreşim bellek + disk + uygulanan durum aynı); kapanış anında anahtarda /
##                   KAPAT'ta / Yaş bilgisi'nde BASILI parmak (+ işlenmemiş olay) — bırakış tercih yazmaz, pencere açmaz;
##                   "+ olay" varyantlarında pozitif kontrol (gizlenen kontrol sentetik bırakışı tam 1 TIKLAMA saydı) ve
##                   anahtarda sonuçtan çıkıp Profil'den yeniden açılan Ayarlar'ın anahtarları kayıtla aynı
##   P kaynak        RESULT_DELAY 0,8 / 300 ms / iptal koruması aynen; temizlik Ayarlar'ı da kapatır (iki bitiş işleyicisi,
##                   gecikmeden ÖNCE); `open_settings` terminal sahiplikte açmaz ve açılışı raporlar (bool); HUD dişlisi
##                   yalnız açılışta dondurur; kapanış yolu (close_settings → close_panel → _on_settings_closed) sabit

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_settings_terminal"
const PATH: String = DIR + "/save.json"
const SECTIONS: int = 11
const MON: String = "2026-09-28"
const THU: String = "2026-10-01"
const BACK_GAP_MSEC: int = 320
const CLEANUP: String = "_dismiss_terminal_gameplay_overlays"
const ACTION_KEYS: Array[String] = ["resume", "restart", "exit", "refill_ad", "refill_dough", "refill_closed",
	"settings_closed", "age_info", "result_retry", "result_exit"]
const PAUSE_KEYS: Array[String] = ["resume", "restart", "exit"]

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
## Anahtar `toggled` yayımları (K'da "+ olay" pozitif kontrolü; sözleşme tercih değeri üzerinden denetlenir).
var _toggles: int = 0
## HUD dişlisi istekleri (`board.settings_requested`, Main'in işleyicisinden SONRA bağlı) — reddedilen gerçek dokunuşun
## dişliye gerçekten ULAŞTIĞININ pozitif kontrolü.
var _gear: int = 0
## Son izlenen bitişin izleyici zamanlayıcısı (Main'in RESULT_DELAY'iyle aynı saat).
var _last_timer: SceneTreeTimer = null
## Kabul edilen bitişin eşzamanlı sonucu (bkz. `_snapshot`).
var _at_finish: Dictionary = {}
## Sıralı olay kaydı ("ad@+ms") — `_reset_marks` sıfırlar.
var _events: Array[String] = []
var _t0: int = 0
var _last_back_msec: int = -100000
var _attempts: int = 0
var _pre_dough: int = 0


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

	await _open_at_finish()
	await _open_in_wait()
	await _normal_use()
	await _android_back()
	await _pause_refill()
	await _menu_pause()
	await _challenge()
	await _task048()
	await _replay()
	await _duplicate()
	await _persistence()
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
	AudioManager.set_sfx_enabled(SaveManager.sfx_enabled())
	Haptics.set_enabled(SaveManager.haptics_enabled())
	UiKit.set_banner_slot(0.0)
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- A) Bitiş anında açık Ayarlar — gerçek yol --------------------------------------------------------------

func _open_at_finish() -> void:
	print("-- A: bitiş ANINDA açık Ayarlar (GERÇEK dişli dokunuşu Büyütücü dönüşümü sırasında) → bitişte kapanır, sonuç tek başına")
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var rounds: int = _rounds()
	var seq: int = _seq()
	var ok: bool = await _finish_with_settings(board, "gear")
	var timer: SceneTreeTimer = _last_timer
	var board_id: int = board.get_instance_id()
	var gen: int = _gen()
	_record("A bitiş anı")
	_c("A kurulum: dönüşüm sırasında gerçek dişli dokunuşu Ayarlar'ı açtı (board donuk), round Ayarlar açıkken bitti", ok)
	_c("A: bitiş ANINDA (işleyicinin eşzamanlı kısmı, gecikmeden ÖNCE) Ayarlar KAPANDI — kapanış sinyali tam 1, sonuç henüz yok",
		not _af("settings") and _actions_in(_af("actions"), ["settings_closed"]) == 1 and not _af("result"))
	_c("  … A: menü dondurması bırakıldı (donuk parça 0), mola / refill yok, board + nesil aynı, tur + 1",
		not _af("menu_paused") and not _af("board_paused") and int(_af("frozen")) == 0 and not _af("pause")
		and not _af("refill") and _owns(board_id, gen) and _rounds() == rounds + 1)
	_c("  … A: sıra — Ayarlar kapanışı bitiş işleyicisinin içinde (izleyicinin 'finish' kaydından ÖNCE)",
		_before("settings:off", "finish"))
	await _until_left(timer, 0.3)
	_c("A: gecikme sürerken Ayarlar kapalı kaldı (yeniden açılmadı), sonuç yok", not _main._settings.visible
		and not _main._result.visible and timer.time_left > 0.0 and _count("settings:on") == 1)
	await _after(timer)
	_record("A sonuç")
	_c("A: gecikmeden sonra sonuç tam bir kez (WIN), ön planda TEK BAŞINA (üstünde görünür pencere yok)%s" % _above_note(),
		_result_alone() and _shows == 1 and _main._result.mode() == _mode("WIN") and _seq() == seq + 2)
	_c("  … A: sıra — Ayarlar kapanışı < bitiş < sonuç; sonuçtan sonra Ayarlar açılmadı; kapanış hâlâ 1",
		_before("settings:off", "result:on") and _before("finish", "result:on") and _count("settings:on") == 1
		and _actions["settings_closed"] == 1)
	await _back()
	await _back()
	_c("A: sonuçta iki Android geri yok sayıldı — sonuç tek başına, Ayarlar YENİDEN AÇILMADI, mola eylemi yok",
		_result_alone() and _count("settings:on") == 1 and _actions["settings_closed"] == 1
		and _actions_in(_actions, PAUSE_KEYS) == 0)
	_sections_done += 1


# --- B) Bekleme içinde açma girişimi ---------------------------------------------------------------------------

func _open_in_wait() -> void:
	print("-- B: bekleme İÇİNDE / sonuçta Ayarlar açma girişimi (gerçek dişli, işleyici, doğrudan, reklam molası) → açılmaz")
	# B1 — RESULT_DELAY içinde HUD dişlisine GERÇEK dokunuş (dişli bu aralıkta ekranda ve dokunulabilir: HUD katman 1,
	# üstünde pencere yok).
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	await _finish_now(board)
	var timer: SceneTreeTimer = _last_timer
	await _until_left(timer, 0.5)
	var left: float = timer.time_left
	var gear: int = _gear
	await _finger_tap(_center(board._hud.settings_button))
	await _settle(1)
	_record("B1 dişli")
	_c("B1: gecikme içinde (%.2f sn kala) gerçek dişli dokunuşu dişliye ulaştı (istek +%d) ama Ayarlar'ı AÇMADI; board menü dondurmasına girmedi"
		% [left, _gear - gear], left > 0.0 and _gear == gear + 1 and not _main._settings.visible
		and _count("settings:on") == 0 and not bool(board.get("_is_menu_paused")) and not board._is_paused()
		and not _main._result.visible)
	await _after(timer)
	_record("B1 sonuç")
	_c("  … B1: sonuç tam bir kez, tek başına; Ayarlar hiç açılmadı%s" % _above_note(), _result_alone() and _shows == 1
		and _count("settings:on") == 0)
	# B2 / B3 — aynı aralıkta HUD işleyicisi (dişlinin vardığı yer) ve doğrudan `open_settings` (Profil / QA kod yolu);
	# B4 — sonuç AÇIKKEN (board hâlâ ekranda, round kesin) aynı girişimler.
	for path: String in ["handler", "direct"]:
		await _fresh()
		board = await _start(_level(3))
		await _wait_settled()
		await _finish_now(board)
		timer = _last_timer
		await _until_left(timer, 0.5)
		var opened: bool = _open_by(path)
		await _settle(1)
		_c("B %s: gecikme içinde Ayarlar açılmadı (açılış raporu false), board donmadı" % path, not opened
			and not _main._settings.visible and not bool(board.get("_is_menu_paused")) and timer.time_left > 0.0)
		await _after(timer)
		_c("  … B %s: sonuç tek başına, bir kez" % path, _result_alone() and _shows == 1)
		opened = _open_by(path)
		await _settle(1)
		_c("  … B4 %s: sonuç açıkken açma girişimi de reddedildi (false) — sonuç tek başına, Ayarlar hiç açılmadı" % path,
			not opened and _result_alone() and _count("settings:on") == 0)
	# B5 — geçiş reklamı molası (TASK/048 fırlatma aralığı): reklam SDK'ya verildi, tam ekran henüz açılmadı → gerçek dişli.
	await _fresh(true)
	var ads: MonetizationManager = _main._ads
	var fake: FakeAdBackend = ads._backend
	board = await _start(_level(3))
	await _wait_settled()
	await _finish_now(board)
	timer = _last_timer
	var shows: int = fake.interstitial_shows.size()
	await _after(timer, 0)
	var id: String = fake.interstitial_shows[-1] if fake.interstitial_shows.size() == shows + 1 else ""
	_c("B5 kurulum: gecikme doldu → geçiş reklamı SDK'ya verildi (mola sürüyor), sonuç yok", id != "" and ads.break_pending()
		and not _main._result.visible)
	gear = _gear
	await _finger_tap(_center(board._hud.settings_button))
	await _settle(1)
	_record("B5 molada dişli")
	_c("B5: reklam molasında gerçek dişli dokunuşu dişliye ulaştı (istek +%d) ama Ayarlar'ı AÇMADI, board donmadı" % (_gear - gear),
		_gear == gear + 1 and not _main._settings.visible and _count("settings:on") == 0
		and not bool(board.get("_is_menu_paused")))
	if id != "":
		fake.emit_interstitial_showed(id)
		await _settle(1)
		fake.emit_interstitial_dismissed(id)
		await _settle(3)
	_record("B5 kapanış")
	_c("  … B5: reklam kapanınca sonuç tam bir kez, tek başına%s" % _above_note(), _result_alone() and _shows == 1)
	_sections_done += 1


## Dönüş: doğrudan yolda `open_settings()`'in açılış raporu; HUD işleyicisinin raporu yok → false.
func _open_by(path: String) -> bool:
	if path == "handler":
		_main._on_board_settings_requested()
		return false
	return _main.open_settings()


# --- C) Bitiş dışında Ayarlar aynen ------------------------------------------------------------------------------

func _normal_use() -> void:
	print("-- C: bitiş dışında Ayarlar AYNEN — dişli açar + board donar, anahtar tercih yazar, KAPAT / X / karartma kapatır")
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	_reset_marks()
	await _finger_tap(_center(board._hud.settings_button))
	_c("C1: canlı round'da gerçek dişli dokunuşu Ayarlar'ı açtı, board menü dondurmasında", _main._settings.visible
		and bool(board.get("_is_menu_paused")) and board._is_paused())
	_main.open_pause_menu()
	await _settle(1)
	_c("  … C1: Ayarlar açıkken mola açılmaz (tek odak kuralı aynen)", _main._settings.visible and not _main.is_pause_open())
	await _wait_settled()
	var sfx: bool = SaveManager.sfx_enabled()
	await _finger_tap(_center(_main._settings._sfx_toggle))
	await _settle(2)
	_c("C2: Ses Efektleri anahtarına gerçek dokunuş tercihi çevirdi, uyguladı ve kayda yazdı (bellek = disk)",
		SaveManager.sfx_enabled() != sfx and AudioManager.is_sfx_enabled() == SaveManager.sfx_enabled()
		and _disk_value("sfx_enabled") == SaveManager.sfx_enabled())
	await _finger_tap(_center(_main._settings._sfx_toggle))
	await _settle(2)
	_c("  … C2: ikinci dokunuş geri çevirdi (bellek = disk)", SaveManager.sfx_enabled() == sfx
		and _disk_value("sfx_enabled") == sfx)
	await _finger_tap(_center(_main._settings._close))
	await _settle(2)
	_c("C3: KAPAT gerçek dokunuşla kapattı (kapanış 1), board çözüldü, round sürüyor", not _main._settings.visible
		and _actions["settings_closed"] == 1 and not bool(board.get("_is_menu_paused")) and not board.is_finished())
	for which: String in ["x", "dim"]:
		await _wait_settled()
		await _finger_tap(_center(board._hud.settings_button))
		await _wait_settled()
		var before: int = _actions["settings_closed"]
		if which == "x":
			await _finger_tap(_center(_main._settings.frame().get_meta(&"close_button")))
		else:
			await _finger_tap(_screen(Vector2(40.0, 60.0)))
		await _settle(2)
		_c("C4 %s: dişli Ayarlar'ı açtı, gerçek dokunuş kapattı (kapanış + 1), board çözüldü" % which,
			not _main._settings.visible and _actions["settings_closed"] == before + 1
			and not bool(board.get("_is_menu_paused")))
	await _wait_settled()
	var dropped: bool = await _drop_ok(board)
	_c("  … C4: Ayarlar sonrası round gerçek dokunuşta tam 1 bırakış", dropped)
	await _wait_settled()
	await _finger_tap(_center(board._hud.back_button))
	await _settle(1)
	_c("C5: Ayarlar kapandıktan sonra HUD geri molayı normal açar", _main.is_pause_open())
	_main.resume_game()
	await _settle(1)
	# C6 — kabuk: Profil dişlisi (Main'in tek paneli), Android geri kapatır; doğrudan açılış true raporlar.
	await _fresh()
	await _profile_settings("C6 Profil")
	var opened: bool = _main.open_settings()
	_c("  … C6: kabukta doğrudan open_settings açar ve true döndürür (açılış raporu)", opened and _main._settings.visible)
	_main.close_settings()
	await _settle(1)
	# C7 — terminal round'dan çıktıktan SONRA (round kesin kalır, board yok) Profil dişlisi yine açar.
	board = await _start(_level(3))
	await _wait_settled()
	await _finish_now(board)
	await _after(_last_timer)
	await _wait_settled()
	await _finger_tap(_center(_main._result.primary_button()))
	await _settle(3)
	_c("C7 kurulum: kazanma sonucu → gerçek dokunuşla Harita (board yok, round kesin kaldı)", _main._board == null
		and _main._active_tab == 1 and bool(_main.get("_round_finalized")))
	await _profile_settings("C7 bitişten sonra Profil")
	_sections_done += 1


func _profile_settings(tag: String) -> void:
	_main._on_profile_requested()
	await _wait_settled()
	var profile: CanvasLayer = _main._screens[4]
	await _finger_tap(_center(profile.settings_button()))
	_c("%s: Profil dişlisi (gerçek dokunuş) Ayarlar'ı açtı" % tag, _main._settings.visible and _main._active_tab == 4)
	await _back()
	_c("  … %s: Android geri Ayarlar'ı kapattı, Profil'de kalındı" % tag, not _main._settings.visible
		and _main._active_tab == 4)


# --- D) Android GERİ ---------------------------------------------------------------------------------------------

func _android_back() -> void:
	print("-- D: Android GERİ — Ayarlar'dan geri (bitiş dışında) aynen; bitişte kapanan Ayarlar'dan sonra geri hiçbir şey açmaz")
	# D1 — canlı round: dişli → Ayarlar → GERİ → kapanır, board çözülür, round sürer.
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	await _finger_tap(_center(board._hud.settings_button))
	await _back()
	_c("D1: canlı round'da Ayarlar'dan Android geri — Ayarlar kapandı (kapanış 1), mola açılmadı, board çözüldü",
		not _main._settings.visible and _actions["settings_closed"] == 1 and not _main.is_pause_open()
		and not bool(board.get("_is_menu_paused")) and not board.is_finished())
	await _wait_settled()
	var dropped: bool = await _drop_ok(board)
	_c("  … D1: round sürüyor, gerçek dokunuşta tam 1 bırakış", dropped)
	# D2 / D3 — bitişte açık Ayarlar → bitişte kapandı → gecikmede GERİ, sonuçta iki GERİ.
	await _fresh()
	board = await _start(_level(3))
	await _wait_settled()
	var ok: bool = await _finish_with_settings(board, "gear")
	var timer: SceneTreeTimer = _last_timer
	await _until_left(timer, 0.4)
	await _back()
	_record("D2 gecikmede geri")
	_c("D2: bitişte açık Ayarlar BİTİŞTE kapandı; gecikmede Android geri — mola / Ayarlar açılmadı, sonuç henüz yok, kapanış 1",
		ok and _before("settings:off", "finish") and not _main._settings.visible and not _main.is_pause_open()
		and not _main._result.visible and _actions["settings_closed"] == 1 and _count("settings:on") == 1
		and timer.time_left > 0.0)
	await _after(timer)
	await _back()
	await _back()
	_c("D3: sonuçta iki Android geri — sonuç tek başına, Ayarlar açılmadı, sonuç tek kez", _result_alone() and _shows == 1
		and _count("settings:on") == 1 and _actions_in(_actions, PAUSE_KEYS) == 0)
	# D4 — Ayarlar hiç açılmadan gecikmede GERİ (mevcut davranış): yok sayılır.
	await _fresh()
	board = await _start(_level(3))
	await _wait_settled()
	await _finish_now(board)
	timer = _last_timer
	await _until_left(timer, 0.4)
	await _back()
	_c("D4: gecikmede Android geri yok sayıldı (mola / Ayarlar yok)", not _main.is_pause_open()
		and not _main._settings.visible and not _main._result.visible)
	await _after(timer)
	_c("  … D4: sonuç tek başına, bir kez", _result_alone() and _shows == 1)
	_sections_done += 1


# --- E) Mola / refill + Ayarlar -------------------------------------------------------------------------------

func _pause_refill() -> void:
	print("-- E: mola / refill + Ayarlar (kod yolu — gerçek girdiyle aynı anda açılamaz) → bitişte hepsi eylemsiz kapanır")
	print("   not: HUD (katman 1) molanın (12) / refill'in (11) karartması altında; Ayarlar (13) açıkken dişli, HUD geri ve güç")
	print("   düğmeleri karartma altında, open_pause_menu Ayarlar açıkken açmaz — iki pencere birlikte yalnız kod yoluyla")
	# E1 — mola açık, üstüne Ayarlar (HUD işleyicisi), dönüşüm biter.
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var piece: Dumpling = await _piece(board)
	_reset_marks()
	await _fire_upgrade(board, piece)
	_main.open_pause_menu()
	_main._on_board_settings_requested()
	var both: bool = _main.is_pause_open() and _main._settings.visible and not board.is_finished() \
		and is_instance_valid(piece) and piece.is_merging
	await _until_finished(board)
	var timer: SceneTreeTimer = _last_timer
	_record("E1 bitiş")
	_c("E1 kurulum: mola + Ayarlar dönüşüm sırasında açıktı, round bitti", both and board.is_finished() and not _at_finish.is_empty())
	_c("E1: bitişte mola VE Ayarlar kapandı — mola eylemi 0, Ayarlar kapanışı 1, menü dondurması bırakıldı",
		not _af("pause") and not _af("settings") and _actions_in(_af("actions"), PAUSE_KEYS) == 0
		and _actions_in(_af("actions"), ["settings_closed"]) == 1 and not _af("menu_paused") and not _af("board_paused"))
	_c("  … E1: sıra — mola ve Ayarlar kapanışı bitiş işleyicisinin içinde (finish'ten önce)",
		_before("pause:off", "finish") and _before("settings:off", "finish"))
	await _after(timer)
	_c("  … E1: sonuç tek başına, bir kez; mola / Ayarlar geri gelmedi%s" % _above_note(), _result_alone() and _shows == 1
		and _count("settings:on") == 1 and _count("pause:on") == 1)
	# E2 — stok 0 güç → refill penceresi (gerçek dokunuş) dönüşüm sırasında, üstüne Ayarlar (işleyici).
	await _fresh()
	board = await _start(_level(3))
	await _wait_settled()
	piece = await _piece(board)
	_reset_marks()
	await _fire_upgrade(board, piece)
	await _finger_tap(_center(board._power_bar.slot(int(PowerUp.Type.BOMB))))
	_main._on_board_settings_requested()
	both = _main._refill.visible and _main._settings.visible and not board.is_finished()
	var bombs: int = SaveManager.powerup_count(PowerUp.Type.BOMB)
	await _until_finished(board)
	timer = _last_timer
	_record("E2 bitiş")
	_c("E2 kurulum: refill (gerçek stok 0 Bomba dokunuşu) + Ayarlar dönüşüm sırasında açıktı, round bitti", both
		and board.is_finished() and not _at_finish.is_empty())
	_c("E2: bitişte refill VE Ayarlar kapandı — satın alma / ödüllü istek 0, Bomba stoğu aynı, Ayarlar kapanışı 1",
		not _af("refill") and not _af("settings") and _actions_in(_af("actions"), ["refill_ad", "refill_dough"]) == 0
		and _actions_in(_af("actions"), ["settings_closed"]) == 1 and SaveManager.powerup_count(PowerUp.Type.BOMB) == bombs
		and not _af("menu_paused") and not _af("board_paused"))
	await _after(timer)
	_c("  … E2: sonuç tek başına, bir kez; bitişten sonra Hamur / stok değişmedi (kesinleşmenin görev ödülü bitiş anında)%s"
		% _above_note(), _result_alone() and _shows == 1 and SaveManager.dough() == int(_af("dough"))
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == bombs and _actions_in(_actions, ["refill_ad", "refill_dough"]) == 0)
	_sections_done += 1


# --- F) Menü dondurması sızmaz ---------------------------------------------------------------------------------

func _menu_pause() -> void:
	print("-- F: menü dondurması sızmaz — bitişte, reddedilen dişliden sonra, sonraki round'da")
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var ok: bool = await _finish_with_settings(board, "handler")
	var timer: SceneTreeTimer = _last_timer
	_c("F1 kurulum: Ayarlar (HUD işleyicisi) dönüşüm sırasında açıktı, round bitti", ok)
	_c("F1: bitişte board'un menü dondurması bırakıldı, donuk parça 0, board duraklamış değil", not _af("menu_paused")
		and not _af("board_paused") and int(_af("frozen")) == 0)
	await _after(timer)
	_c("  … F1: sonuçta da board dondurmasız, Ayarlar kapalı", not bool(board.get("_is_menu_paused"))
		and _frozen(board) == 0 and _result_alone())
	# F2 — Ayarlar'sız bitiş (açık Ayarlar'ın karartması dişliyi örtmesin): gecikmede gerçek dişli → reddedilir, dondurma yok.
	await _fresh()
	board = await _start(_level(3))
	await _wait_settled()
	await _finish_now(board)
	timer = _last_timer
	await _until_left(timer, 0.4)
	var gear: int = _gear
	await _finger_tap(_center(board._hud.settings_button))
	await _settle(1)
	_c("F2: gecikmede reddedilen dişliden (istek +%d) sonra board menü dondurmasına GİRMEDİ, parçalar donmadı, Ayarlar kapalı"
		% (_gear - gear), _gear == gear + 1 and not _main._settings.visible and not bool(board.get("_is_menu_paused"))
		and not board._is_paused() and _frozen(board) == 0)
	await _after(timer)
	await _wait_settled()
	await _finger_tap(_center(_main._result.secondary_button()))
	await _settle(3)
	var next: Node2D = _main._board
	_track(next)
	_c("F3: sonuç TEKRAR (gerçek dokunuş) → yeni round, menü dondurması yok, Ayarlar kapalı", _actions["result_retry"] == 1
		and next != null and is_instance_valid(next) and next != board and not bool(next.get("_is_menu_paused"))
		and not next._is_paused() and not _main._settings.visible)
	await _wait_settled()
	var dropped: bool = await _drop_ok(next)
	_c("  … F3: yeni round gerçek dokunuşta tam 1 bırakış", dropped)
	await _wait_settled()
	await _finger_tap(_center(next._hud.settings_button))
	_c("  … F3: yeni round'da dişli Ayarlar'ı normal açar (board donar)", _main._settings.visible
		and bool(next.get("_is_menu_paused")))
	await _wait_settled()
	await _finger_tap(_center(_main._settings._close))
	await _settle(2)
	_c("  … F3: KAPAT → board çözüldü", not _main._settings.visible and not bool(next.get("_is_menu_paused")))
	# F4 — reddedilen açılış board'a HİÇ dokunmaz (GameBoard'un bitmiş-board korumasına dayanmadan): CANLI board'da kapı
	# dar dikişle kapalı (`_round_finalized` — kapının girdisi — true); gerçek dişli dokunuşu dişliye ulaşır, Ayarlar
	# açılmaz, canlı board donmaz. Bayrak hemen geri alınır, round sürer.
	await _fresh()
	board = await _start(_level(3))
	await _wait_settled()
	_main.set("_round_finalized", true)
	gear = _gear
	await _finger_tap(_center(board._hud.settings_button))
	await _settle(1)
	var refused: bool = _gear == gear + 1 and not _main._settings.visible and not bool(board.get("_is_menu_paused")) \
		and not board._is_paused() and _frozen(board) == 0 and not board.is_finished()
	_main.set("_round_finalized", false)
	_c("F4: kapı kapalıyken CANLI board'da gerçek dişli dokunuşu (istek +%d) — Ayarlar açılmadı, board DONMADI (reddedilen açılış board'a dokunmaz)"
		% (_gear - gear), refused)
	await _wait_settled()
	dropped = await _drop_ok(board)
	_c("  … F4: kapı açılınca round sürüyor — gerçek dokunuşta tam 1 bırakış, menü dondurması yok", dropped
		and not bool(board.get("_is_menu_paused")))
	_sections_done += 1


# --- G) Meydan okuma -----------------------------------------------------------------------------------------

func _challenge() -> void:
	print("-- G: meydan okuma — aynı karede merge Ayarlar AÇIKKEN (gerçek dişli) bitirir; gecikmede dişli; çıkıştan sonra Profil")
	var board: Node2D = await _challenge_with_gear()
	var ok: bool = board != null
	var timer: SceneTreeTimer = _last_timer
	_record("G1 bitiş (%d deneme)" % _attempts)
	_c("G1 kurulum (%d deneme): Ayarlar gerçek dişliyle temas raporlanmadan ÖNCE açıldı (board donuk), meydan okuma Ayarlar açıkken kazanıldı"
		% _attempts, ok)
	if ok:
		_c("G1: bitiş ANINDA Ayarlar kapandı (kapanış 1), mola yok, menü dondurması bırakıldı, +20 Hamur yazıldı",
			not _af("settings") and _actions_in(_af("actions"), ["settings_closed"]) == 1 and not _af("pause")
			and not _af("menu_paused") and int(_af("dough")) == _pre_dough + 20 and _before("settings:off", "finish"))
		await _after(timer)
		_record("G1 sonuç")
		_c("  … G1: gecikmeden sonra meydan okuma sonucu (CHALLENGE_WIN) tek başına, bir kez; +20 tam bir kez%s" % _above_note(),
			_result_alone() and _shows == 1 and _main._result.mode() == _mode("CHALLENGE_WIN")
			and SaveManager.dough() == _pre_dough + 20 and _count("settings:on") == 1)
		await _back()
		_c("  … G1: sonuçta Android geri yok sayıldı, Ayarlar açılmadı", _result_alone() and _count("settings:on") == 1)
		await _wait_settled()
		await _finger_tap(_center(_main._result.primary_button()))
		await _settle(3)
		_c("  … G1: sonuç düğmesi gerçek dokunuşu aldı → Ana Sayfa, Ayarlar kapalı", _actions["result_exit"] == 1
			and _main._board == null and _main._active_tab == 0 and not _main._settings.visible)
		await _profile_settings("G1 meydan okumadan sonra Profil")
	# G2 — meydan okuma penceresiz biter; gecikme içinde gerçek dişli reddedilir.
	await _fresh()
	board = await _start_challenge()
	var pre: int = SaveManager.dough()
	if board != null:
		await _win_merge(board)
	timer = _last_timer
	await _until_left(timer, 0.5)
	var gear: int = _gear
	if board != null and is_instance_valid(board):
		await _finger_tap(_center(board._hud.settings_button))
	await _settle(1)
	_record("G2 dişli")
	_c("G2: meydan okuma gecikmesinde gerçek dişli dokunuşu dişliye ulaştı (istek +%d) ama Ayarlar'ı AÇMADI, board donmadı"
		% (_gear - gear), board != null and is_instance_valid(board) and board.is_finished() and _gear == gear + 1
		and not _main._settings.visible and not bool(board.get("_is_menu_paused")) and timer != null
		and timer.time_left > 0.0)
	await _after(timer)
	_c("  … G2: meydan okuma sonucu tek başına, bir kez; +20 bir kez", _result_alone() and _shows == 1
		and SaveManager.dough() == pre + 20)
	_sections_done += 1


## Meydan okuma Ayarlar AÇIKKEN kazanılır (gerçek aynı kare penceresi, TASK/050 deseni): iki (hedef − 1) parça bir fizik
## karesinin İÇİNDE yan yana tabanda doğar — o karenin adımı teması kaydeder; aynı karenin boşta evresinde HUD dişlisine
## GERÇEK dokunuş Ayarlar'ı açar (menü dondurması); sonraki karede temas donmuş parçalara raporlanır → gerçek merge → bitiş.
## Motor bir kareye iki fizik adımı sığdırırsa temas Ayarlar açılmadan raporlanabilir — o deneme sayılmaz, en fazla 3.
func _challenge_with_gear() -> Node2D:
	_attempts = 0
	while _attempts < 3:
		_attempts += 1
		await _fresh()
		_pre_dough = SaveManager.dough()
		var board: Node2D = await _start_challenge()
		if board == null:
			return null
		var tier: int = board.level.target_tier - 1
		var r: float = TierConfig.radius(tier)
		var y: float = _floor_y(board) - r - 1.0
		var cx: float = board._center_x()
		_reset_marks()
		await get_tree().physics_frame
		var a: Dumpling = board._spawn_dumpling(tier, Vector2(cx - r + 1.0, y))
		var b: Dumpling = board._spawn_dumpling(tier, Vector2(cx + r - 1.0, y))
		await get_tree().process_frame
		var untouched: bool = is_instance_valid(a) and is_instance_valid(b) and not a.is_merging and not b.is_merging \
			and not board.is_finished()
		_tap_now(_center(board._hud.settings_button))
		var open_first: bool = _main._settings.visible and bool(board.get("_is_menu_paused")) and not board.is_finished()
		await _until_finished(board)
		if untouched and open_first and is_instance_valid(board) and board.is_finished() and not _at_finish.is_empty():
			return board
	return null


# --- H) TASK/048 ---------------------------------------------------------------------------------------------------

func _task048() -> void:
	print("-- H: TASK/048 aynen — gecikmede yeniden başlatma; reklam molasında ertelenen yeniden başlatma yeni round'u Ayarlar'sız kurar")
	# H1 — bitişte açık Ayarlar kapandı; gecikme İÇİNDE üretim yeniden başlatma işleyicisi (molanın kendi sinyali — mola
	# bitişte kapalı: dar test dikişi) → yeni round, eski sonuç / eski geçiş reklamı yok (reklam uygun + hazır), Ayarlar yok.
	await _fresh(true)
	var ads: MonetizationManager = _main._ads
	var fake: FakeAdBackend = ads._backend
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var ok: bool = await _finish_with_settings(board, "gear")
	var timer: SceneTreeTimer = _last_timer
	var board_id: int = board.get_instance_id()
	var shows: int = fake.interstitial_shows.size()
	await _until_left(timer, 0.4)
	_main._pause.restart_pressed.emit()
	await _settle(2)
	var next: Node2D = _main._board
	_track(next)
	_c("H1: bitişte Ayarlar kapandı; gecikme içinde yeniden başlatma yeni board kurdu, Ayarlar kapalı", ok
		and not _af("settings") and _differs(next, board_id) and not _main._settings.visible)
	await _after(timer)
	_record("H1 gecikme sonu")
	_c("  … H1: eski sonuç AÇILMADI, eski round geçiş reklamı DENEMEDİ (uygun + hazır kaldı); yeni round Ayarlar'sız, dondurmasız",
		not _main._result.visible and _shows == 0 and fake.interstitial_shows.size() == shows
		and ads.interstitial_state() == MonetizationManager.InterstitialState.READY and not _main._settings.visible
		and next != null and is_instance_valid(next) and not bool(next.get("_is_menu_paused")))
	await _wait_settled()
	var dropped: bool = await _drop_ok(next)
	_c("  … H1: yeni round gerçek dokunuşta tam 1 bırakış", dropped)
	# H2 — fırlatma aralığı: reklam SDK'ya verildi → gerçek dişli (reddedilir) → üretim yeniden başlatma ERTELENİR →
	# kapanışta eski sonucun YERİNE çalışır: yeni round Ayarlar'ın altında BAŞLAMAZ.
	await _fresh(true)
	ads = _main._ads
	fake = ads._backend
	board = await _start(_level(3))
	await _wait_settled()
	await _finish_now(board)
	timer = _last_timer
	board_id = board.get_instance_id()
	var gen: int = _gen()
	shows = fake.interstitial_shows.size()
	await _after(timer, 0)
	var id: String = fake.interstitial_shows[-1] if fake.interstitial_shows.size() == shows + 1 else ""
	_c("H2 kurulum: reklam SDK'ya verildi (mola sürüyor), sonuç yok", id != "" and ads.break_pending()
		and not _main._result.visible)
	var gear: int = _gear
	await _finger_tap(_center(board._hud.settings_button))
	await _settle(1)
	_main._pause.restart_pressed.emit()
	await _settle(2)
	_record("H2 molada dişli + yeniden başlat")
	_c("  … H2: molada dişli (istek +%d) Ayarlar'ı açmadı; yeniden başlatma ERTELENDİ (board + nesil aynı)" % (_gear - gear),
		_gear == gear + 1 and not _main._settings.visible and _owns(board_id, gen))
	if id != "":
		fake.emit_interstitial_showed(id)
		await _settle(1)
		fake.emit_interstitial_dismissed(id)
		await _settle(3)
	next = _main._board
	_track(next)
	_record("H2 kapanış")
	_c("  … H2: kapanışta ertelenen yeniden başlatma sonucun YERİNE çalıştı — yeni round Ayarlar'ın ALTINDA değil, sonuç yok",
		_differs(next, board_id) and _gen() > gen and not _main._result.visible and _shows == 0
		and not _main._settings.visible and not ads.break_pending())
	await _wait_settled()
	dropped = await _drop_ok(next)
	_c("  … H2: yeni round gerçek dokunuşta tam 1 bırakış", dropped and next != null and not bool(next.get("_is_menu_paused")))
	_sections_done += 1


# --- I) Tekrar / çıkış Ayarlar'ı diriltmez -------------------------------------------------------------------------

func _replay() -> void:
	print("-- I: TEKRAR / çıkış / yeni round kapanmış Ayarlar'ı diriltmez")
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var ok: bool = await _finish_with_settings(board, "gear")
	await _after(_last_timer)
	await _wait_settled()
	await _finger_tap(_center(_main._result.secondary_button()))
	await _settle(3)
	var next: Node2D = _main._board
	_track(next)
	await _settle(6)
	_c("I1: bitişte kapanan Ayarlar → sonuç TEKRAR (gerçek dokunuş) → yeni round: Ayarlar kapalı, kapanış hâlâ 1, yeniden açılış yok",
		ok and _actions["result_retry"] == 1 and _differs(next, board.get_instance_id() if is_instance_valid(board) else -1)
		and not _main._settings.visible and _actions["settings_closed"] == 1 and _count("settings:on") == 1)
	await _wait_settled()
	ok = await _finish_with_settings(next, "gear")
	await _after(_last_timer)
	await _wait_settled()
	await _finger_tap(_center(_main._result.primary_button()))
	await _settle(6)
	_c("I2: ikinci round da Ayarlar açıkken bitti → sonuçtan çıkış (gerçek dokunuş) → Harita, Ayarlar kapalı",
		ok and _actions["result_exit"] == 1 and _main._board == null and _main._active_tab == 1
		and not _main._settings.visible and _actions["settings_closed"] == 2)
	board = await _start(_level(3))
	await _wait_settled()
	_c("I3: Harita'dan yeni round: Ayarlar kapalı, board donuk değil", not _main._settings.visible
		and not bool(board.get("_is_menu_paused")))
	await _finger_tap(_center(board._hud.settings_button))
	_c("  … I3: yeni round'da dişli Ayarlar'ı normal açar", _main._settings.visible and bool(board.get("_is_menu_paused")))
	await _back()
	_c("  … I3: Android geri kapatır, board çözülür", not _main._settings.visible and not bool(board.get("_is_menu_paused")))
	_sections_done += 1


# --- J) Yinelenen bitiş ------------------------------------------------------------------------------------------

func _duplicate() -> void:
	print("-- J: yinelenen round_finished / ikinci temizlik — ikinci kapanış, ikinci sonuç, ikinci tur yok")
	await _fresh()
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var rounds: int = _rounds()
	var ok: bool = await _finish_with_settings(board, "gear")
	var timer: SceneTreeTimer = _last_timer
	board.round_finished.emit(true)
	board.round_finished.emit(false)
	_main.call(CLEANUP)
	_main.call(CLEANUP)
	await _settle(2)
	_c("J1: iki yinelenen round_finished + iki temizlik çağrısı: Ayarlar kapanışı hâlâ 1, Ayarlar kapalı, tur + 1 (bir kez)",
		ok and _actions["settings_closed"] == 1 and not _main._settings.visible and _rounds() == rounds + 1)
	await _after(timer)
	await _wait(0.9)
	_c("  … J1: sonuç tam bir kez, tek başına (yinelenen sinyal ikinci sonuç zamanlamadı)", _result_alone() and _shows == 1)
	_sections_done += 1


# --- K) Tercih kalıcılığı --------------------------------------------------------------------------------------

func _persistence() -> void:
	print("-- K: tercih — temizlik yazmaz; kapanış anında anahtarda / KAPAT'ta / Yaş bilgisi'nde BASILI parmak bırakışı yazmaz, açmaz")
	# K1 — kayıtta ses + titreşim KAPALI; Ayarlar bitişte açık → temizlik kapatır → tercih (bellek, disk, uygulanan) aynı.
	await _fresh(false, {"sfx_enabled": false, "haptics_enabled": false})
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	var ok: bool = await _finish_with_settings(board, "gear")
	await _after(_last_timer)
	_c("K1: bitişte açık Ayarlar kapandı; ses / titreşim tercihi KAPALI kaldı (bellek, disk, uygulanan durum)", ok
		and not _main._settings.visible and not SaveManager.sfx_enabled() and not SaveManager.haptics_enabled()
		and _disk_value("sfx_enabled") == false and _disk_value("haptics_enabled") == false
		and not AudioManager.is_sfx_enabled() and not Haptics.is_enabled() and _result_alone())
	# K2 — kapanış anında Ayarlar'ın bir kontrolünde BASILI parmak (+ ardından işlenmemiş bir olay: Godot gizleme anında
	# odaklı düğmeye sentetik bırakış yollar ve girdi "işlendi" DEĞİLSE BaseButton onu tıklama sayar — TASK/049 dersi).
	# Ayarlar 300 ms açılış yatışmasından SONRA basılır; dönüşüm (0,15 sn) bu süreye sığmadığından bitiş dar dikişle:
	# `GameBoard._finish` (dönüşümün / merge'in vardığı aynı fonksiyon).
	for variant: Array in [["ses", false], ["ses", true], ["titreşim", true], ["kapat", true], ["x", true]]:
		await _held_variant(String(variant[0]), bool(variant[1]), false)
	# K3 — "Yaş bilgisi → Güncelle" (reklam yöneticisi + bilinen yaş bandında görünür): bırakış yaş penceresini sonucun
	# üstüne AÇMAZ.
	for unhandled: bool in [false, true]:
		await _held_variant("yaş", unhandled, true)
	_sections_done += 1


func _held_variant(control: String, unhandled: bool, with_ads: bool) -> void:
	var tag: String = control + (" + olay" if unhandled else "")
	await _fresh(with_ads, {"sfx_enabled": true, "haptics_enabled": true}, false)
	var board: Node2D = await _start(_level(3))
	await _wait_settled()
	await _finger_tap(_center(board._hud.settings_button))
	await _wait_settled()
	var target: Control = _settings_control(control)
	var visible_target: bool = target != null and target.is_visible_in_tree()
	var pos: Vector2 = _center(target) if target != null else Vector2.ZERO
	var clicks: Array[int] = [0]
	if target is BaseButton:
		(target as BaseButton).pressed.connect(func() -> void: clicks[0] += 1)
	var toggle: bool = control == "ses" or control == "titreşim"
	_reset_marks()
	_toggles = 0
	await _finger(pos, true)
	if unhandled:
		await _unhandled_key()
	var held: bool = visible_target and _main._settings.visible and not board.is_finished() \
		and (not unhandled or not get_viewport().is_input_handled())
	board._finish(true)
	await _settle(1)
	var timer: SceneTreeTimer = _last_timer
	var closed_at_finish: bool = not _af("settings")
	await _finger(pos, false)
	await _settle(3)
	_record("K [%s] bırakış" % tag)
	_c("K [%s] kurulum: Ayarlar açık, parmak kontrolde BASILI%s → round bitti" % [tag,
		", son olay işlenmemiş" if unhandled else ""], held and board.is_finished() and not _at_finish.is_empty())
	_c("K [%s] bitişte Ayarlar kapandı; parmak kalkınca tercih YAZILMADI (ses / titreşim bellek + uygulanan aynı), Ayarlar / yaş penceresi açılmadı (gizli tıklama: %d, anahtar toggled: %d)"
		% [tag, clicks[0], _toggles], closed_at_finish and SaveManager.sfx_enabled() and SaveManager.haptics_enabled()
		and AudioManager.is_sfx_enabled() and Haptics.is_enabled() and not _main._settings.visible
		and not _main._age_panel.visible and _actions["age_info"] == 0 and _actions["settings_closed"] == 1)
	if unhandled:
		# Pozitif kontrol: koruma gerçekten sınandı — gizlenen pencerenin kontrolü sentetik bırakışı TIKLAMA saydı.
		_c("  … K [%s] pozitif kontrol: gizlenen kontrol sentetik bırakışı tam 1 tıklama saydı (anahtarda toggled %d)"
			% [tag, 1 if toggle else 0], clicks[0] == 1 and _toggles == (1 if toggle else 0))
	await _after(timer)
	_c("  … K [%s] sonuç tek başına, bir kez; diskte tercih aynı%s" % [tag, _above_note()], _result_alone() and _shows == 1
		and _disk_value("sfx_enabled") == true and _disk_value("haptics_enabled") == true)
	if unhandled and toggle:
		await _reopen_matches_save(tag)


## Sonuçtan çıkış (gerçek dokunuş) → Harita → Profil dişlisi → Ayarlar: anahtarlar kayıtla AYNI — gizli tıklamanın
## çevirdiği görünüm `open_panel`'de kayıttan yeniden kuruldu (tercih yazılmadığı için kayıt hâlâ AÇIK).
func _reopen_matches_save(tag: String) -> void:
	await _wait_settled()
	await _finger_tap(_center(_main._result.primary_button()))
	await _settle(3)
	_main._on_profile_requested()
	await _wait_settled()
	var profile: CanvasLayer = _main._screens[4]
	await _finger_tap(_center(profile.settings_button()))
	var s: CanvasLayer = _main._settings
	_c("  … K [%s] sonuçtan çıkıp Profil dişlisiyle yeniden açılan Ayarlar'da anahtarlar kayıtla AYNI (ses %s, titreşim %s)"
		% [tag, str(s._sfx_toggle.button_pressed), str(s._haptics_toggle.button_pressed)], s.visible
		and _main._board == null and _main._active_tab == 4 and SaveManager.sfx_enabled() and SaveManager.haptics_enabled()
		and s._sfx_toggle.button_pressed == SaveManager.sfx_enabled()
		and s._haptics_toggle.button_pressed == SaveManager.haptics_enabled())
	await _back()


func _settings_control(control: String) -> Control:
	var s: CanvasLayer = _main._settings
	match control:
		"ses":
			return s._sfx_toggle
		"titreşim":
			return s._haptics_toggle
		"kapat":
			return s._close
		"x":
			return s.frame().get_meta(&"close_button") as Control
		"yaş":
			return s.age_info_button()
	return null


# --- P) Kaynak sözleşmesi --------------------------------------------------------------------------------------

func _source_contract() -> void:
	print("-- P: kaynak sözleşmesi")
	var src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var code: String = _strip_comments(src)
	var board_code: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/game/game_board.gd"))
	var constants: Dictionary = _main_script.get_script_constant_map()
	_c("RESULT_DELAY aynen 0,8 sn", is_equal_approx(float(constants["RESULT_DELAY"]), 0.8))
	_c("TOUCH_SETTLE_MSEC aynen 300 (TASK/045.2)", int(constants["TOUCH_SETTLE_MSEC"]) == 300)
	_c("TASK/046.2 iptal koruması aynen", FileAccess.get_file_as_string("res://scripts/game/game_board.gd")
		.contains("\telif not touch.canceled:"))
	var helper: String = _function(code, "func %s(" % CLEANUP)
	_c("terminal temizliği mola + refill + AYARLAR'ı kapatır (Ayarlar kendi kapanış yoluyla: close_settings)",
		helper.contains("_pause.close_menu()") and helper.contains("_refill.hide_refill()")
		and helper.contains("close_settings()"))
	var forbidden: Array[String] = ["_daily_rewards", "_chest_info", "_missions", "_challenge_sheet", "_age_panel",
		"resume_game(", "_on_pause_restart(", "abandon_run(", "_start_level(", "_clear_board(", "_finish_refill(",
		"_on_refill_closed(", "grant_", "save_game", "SaveManager", "set_sfx_enabled", "set_haptics_enabled",
		"_cancel_rewarded_request(", "_clear_refill_request(", "_show_tab(", "_result.", "open_settings("]
	var leaks: Array[String] = []
	for token in forbidden:
		if helper.contains(token):
			leaks.append(token)
	_c("  … temizlik ikincil pencerelere / gezinmeye / round değişimine / kayda / tercihe / ödüllü talebe dokunmaz%s"
		% ("" if leaks.is_empty() else " (sızan: %s)" % ", ".join(leaks)), helper != "" and leaks.is_empty())
	for header: String in ["func _on_round_finished(", "func _on_challenge_round_finished("]:
		var fn: String = _function(code, header)
		var guard: int = fn.find("_round_finalized = true")
		var call_at: int = fn.find("%s()" % CLEANUP)
		var waited: int = fn.find("await get_tree().create_timer(RESULT_DELAY).timeout")
		_c("%s: temizlik kesinleştirme korumasından SONRA, gecikmeden ÖNCE, tek kez" % header.trim_prefix("func ").trim_suffix("("),
			guard >= 0 and call_at > guard and waited > call_at and fn.count("%s()" % CLEANUP) == 1)
	var open_fn: String = _function(code, "func open_settings(")
	var gate_at: int = open_fn.find("_terminal_round_owns_screen()")
	var open_at: int = open_fn.find("_settings.open_panel()")
	_c("open_settings: terminal sahiplik kapısı panel açılışından ÖNCE (tek açma noktası — HUD dişlisi, Profil, QA)",
		gate_at >= 0 and open_at > gate_at)
	var refuse_at: int = open_fn.find("return false")
	_c("  … open_settings açılışı raporlar: `-> bool`, kapıda `return false` (panel açılışından önce), açılışta `return true`",
		open_fn.begins_with("func open_settings() -> bool:") and refuse_at > gate_at and refuse_at < open_at
		and open_fn.count("return false") == 1 and open_fn.rfind("return true") > open_at)
	var handler: String = _function(code, "func _on_board_settings_requested(")
	_c("HUD dişlisi board'u YALNIZ açılış başarılıysa dondurur (reddedilen açılış board'a dokunmaz — GameBoard korumasına dayanmaz)",
		handler.contains("if open_settings() and _board != null and is_instance_valid(_board):")
		and handler.count("open_settings()") == 1 and handler.count("set_menu_paused(") == 1
		and handler.find("open_settings()") < handler.find("set_menu_paused(true)"))
	var owns: String = _function(code, "func _terminal_round_owns_screen(")
	_c("  … kapı = kesinleşen round (`_round_finalized`) + ekranda board (Profil / kabuk yolu board yokken etkilenmez)",
		owns.contains("_round_finalized") and owns.contains("_board != null") and owns.contains("is_instance_valid(_board)"))
	_c("  … HUD dişlisi yalnız open_settings'ten geçer (panel doğrudan açılmaz)", code.count("_settings.open_panel()") == 1)
	var panel_code: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/settings_panel.gd"))
	var unguarded: Array[String] = []
	for pair: Array in [["func _on_sfx_toggled(", "SaveManager.set_sfx_enabled("],
			["func _on_haptics_toggled(", "SaveManager.set_haptics_enabled("],
			["func _on_age_info_pressed(", "age_info_requested.emit()"],
			["func _on_privacy_options_pressed(", "show_privacy_options()"],
			["func _on_privacy_policy_pressed(", "OS.shell_open("]]:
		var fn: String = _function(panel_code, String(pair[0]))
		var gate: int = fn.find("not visible")
		var act: int = fn.find(String(pair[1]))
		if gate < 0 or act < 0 or gate > act:
			unguarded.append(String(pair[0]).trim_prefix("func ").trim_suffix("("))
	_c("SettingsPanel: KAPALI pencere eylem üretmez — tercih / yaş / gizlilik seçenekleri / politika işleyicileri görünürlükten geçer%s"
		% ("" if unguarded.is_empty() else " (korumasız: %s)" % ", ".join(unguarded)), unguarded.is_empty())
	_c("  … kapanış zaten görünürlükle korunur (close_panel), açılış kayıttan yeniden kurar (set_on)",
		_function(panel_code, "func close_panel(").contains("if not visible:")
		and _function(panel_code, "func open_panel(").contains("_sfx_toggle.set_on(SaveManager.sfx_enabled())")
		and _function(panel_code, "func open_panel(").contains("_haptics_toggle.set_on(SaveManager.haptics_enabled())"))
	# Temizliğin geçişli yolu (close_settings → close_panel → closed → _on_settings_closed) sabit: buraya eklenecek bir yan
	# etki TASK/049 / 050 / 053 terminal temizliğine sessizce katılırdı.
	var close_path: bool = _lines(_function(code, "func close_settings(")) == ["func close_settings() -> void:",
		"_settings.close_panel()"] \
		and _lines(_function(code, "func _on_settings_closed(")) == ["func _on_settings_closed() -> void:",
		"if _board != null and is_instance_valid(_board) and not _pause.visible:", "_board.set_menu_paused(false)"] \
		and _lines(_function(panel_code, "func close_panel(")) == ["func close_panel() -> void:", "if not visible:",
		"return", "visible = false", "AudioManager.play(&\"ui_modal_close\")", "closed.emit()"]
	_c("  … kapanış yolu sabit: close_settings → close_panel (ses + closed) → _on_settings_closed (yalnız mola kapalıyken board'u çözer; başka yan etki yok)",
		close_path)
	var board_finish: String = _function(board_code, "func _finish(")
	_c("GameBoard._finish menü dondurmasını bırakır (TASK/049, sinyalden ÖNCE)", board_finish.contains("_is_menu_paused = false")
		and board_finish.find("_is_menu_paused = false") < board_finish.find("round_finished.emit("))
	var menu_fn: String = _function(board_code, "func set_menu_paused(")
	_c("GameBoard.set_menu_paused bitmiş board'da çalışmaz (reddedilen dişli dondurma sızdırmaz)",
		menu_fn.contains("or _is_finished"))


# --- Ortak ---------------------------------------------------------------------------------------------------------

func _fixture(extra: Dictionary = {}) -> Dictionary:
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 2},
		"endless_high_score": 640, "dough": 335, "total_merges": 40, "merges_since_bonus_chest": 10,
		"unlocked_skins": ["common_01", "rare_02"], "profile_showcase": ["rare_02"],
		"powerups": {"bomb": 0, "upgrade": 9, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
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


func _write_fixture(extra: Dictionary = {}) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(_fixture(extra), "\t"))
	file.close()


## Temiz kayıt + Main. `with_ads`: sahte reklam arka ucu (rıza + init + ödüllü hazır); `interstitial`: normal geçiş
## reklamı da hazır + uygun (TASK/052 AdPolicy'nin iki kapısı dolmuş).
func _fresh(with_ads: bool = false, extra: Dictionary = {}, interstitial: bool = true) -> void:
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
		_main._ads._tick_active(AdPolicy.FORCED_INTERSTITIAL_MIN_INTERVAL_SEC)
		for i in AdPolicy.FORCED_INTERSTITIAL_MIN_ROUNDS:
			_main._ads.note_normal_round_finalized()
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
	_gear = 0
	_last_timer = null
	_reset_actions()
	_reset_marks()
	_main._result.visibility_changed.connect(func() -> void:
		if _main != null and is_instance_valid(_main) and _main._result.visible:
			_shows += 1)
	for pair: Array in [[_main._settings, "settings"], [_main._pause, "pause"], [_main._refill, "refill"],
			[_main._result, "result"], [_main._age_panel, "age"]]:
		var layer: CanvasLayer = pair[0]
		var label: String = pair[1]
		layer.visibility_changed.connect(func() -> void:
			if _main != null and is_instance_valid(_main):
				_ev("%s:%s" % [label, "on" if layer.visible else "off"]))
	_main._pause.resume_pressed.connect(func() -> void: _actions["resume"] += 1)
	_main._pause.restart_pressed.connect(func() -> void: _actions["restart"] += 1)
	_main._pause.exit_pressed.connect(func() -> void: _actions["exit"] += 1)
	_main._refill.rewarded_refill_requested.connect(func(_type: int) -> void: _actions["refill_ad"] += 1)
	_main._refill.dough_refill_requested.connect(func(_type: int) -> void: _actions["refill_dough"] += 1)
	_main._refill.closed.connect(func() -> void: _actions["refill_closed"] += 1)
	_main._settings.closed.connect(func() -> void: _actions["settings_closed"] += 1)
	_main._settings.age_info_requested.connect(func() -> void: _actions["age_info"] += 1)
	_main._settings._sfx_toggle.toggled.connect(func(_on: bool) -> void: _toggles += 1)
	_main._settings._haptics_toggle.toggled.connect(func(_on: bool) -> void: _toggles += 1)
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
	_at_finish = {}
	_events = []
	_t0 = Time.get_ticks_msec()


func _ev(tag: String) -> void:
	_events.append("%s@%+d" % [tag, Time.get_ticks_msec() - _t0])


## İlk geçiş indeksi (yoksa -1).
func _index(tag: String) -> int:
	for i in _events.size():
		if _events[i].begins_with(tag + "@"):
			return i
	return -1


func _count(tag: String) -> int:
	var n: int = 0
	for event in _events:
		if event.begins_with(tag + "@"):
			n += 1
	return n


## `first` olayı, `then` olayından ÖNCE kaydedildi (ikisi de var).
func _before(first: String, then: String) -> bool:
	var a: int = _index(first)
	var b: int = _index(then)
	return a >= 0 and b >= 0 and a < b


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


func _start_challenge() -> Node2D:
	var started: bool = _main.start_daily_challenge()
	await _settle(3)
	var board: Node2D = _main._board if started else null
	_track(board)
	await _wait_settled()
	return board


## Bırakış sayacı + bitiş izleyicisi (Main'in işleyicisinden SONRA bağlı): bitişin eşzamanlı sonucu + Main'in
## RESULT_DELAY zamanlayıcısıyla aynı süreli bir SceneTree zamanlayıcısı.
func _track(board: Node2D) -> void:
	if board == null or board.has_meta(&"qa_tracked"):
		return
	board.set_meta(&"qa_tracked", true)
	board.dumpling_dropped.connect(func(_tier: int) -> void: _drops += 1)
	board.settings_requested.connect(func() -> void: _gear += 1)
	board.round_finished.connect(func(_won: bool) -> void:
		if not _at_finish.is_empty():
			return
		_ev("finish")
		_last_timer = get_tree().create_timer(_delay())
		_at_finish = _snapshot(board))


## Bitiş görüntüsünden bir alan; görüntü yoksa (kurulum başarısız) kontrolü DÜŞÜREN değer — betik hatası değil FAIL.
func _af(key: String) -> Variant:
	if _at_finish.has(key):
		return _at_finish[key]
	match key:
		"board":
			return false
		"gen", "dough", "frozen":
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
		"menu_paused": bool(board.get("_is_menu_paused")), "board_paused": board._is_paused(), "frozen": _frozen(board),
		"result": _main._result.visible, "gen": _gen(), "board": _main._board == board, "actions": _actions.duplicate(),
		"dough": SaveManager.dough()}


func _frozen(board: Variant) -> int:
	var n: int = 0
	if board == null or not is_instance_valid(board):
		return -1
	for piece in (board as Node).call("live_dumplings"):
		if piece is Dumpling and (piece as Dumpling).is_simulation_frozen():
			n += 1
	return n


## Kayıt satırı (sayılmaz): nesil, sonuç sırası, kesinleşme, reklam molası nesli, pencere / dondurma durumu, olay sırası.
func _record(tag: String) -> void:
	var board: Variant = _main._board
	var menu: String = str(bool((board as Node).get("_is_menu_paused"))) if board != null and is_instance_valid(board) else "-"
	print("  [KAYIT] %s: nesil=%d sonuç_seq=%d kesin=%s reklam_nesli=%s | ayarlar=%s mola=%s refill=%s menü_dondurma=%s sonuç=%s üstte=%s | %s" % [
		tag, _gen(), _seq(), str(_main.get("_round_finalized")), str(_main.get("_round_break_generation")),
		str(_main._settings.visible), str(_main.is_pause_open()), str(_main._refill.visible), menu,
		str(_main._result.visible), str(_above_result()), " ".join(_events)])


## Sonucun katmanında ya da üstünde görünür olan Main pencereleri (sonuç hariç).
func _above_result() -> Array[String]:
	var out: Array[String] = []
	for child in _main.get_children():
		var layer := child as CanvasLayer
		if layer != null and layer != _main._result and layer.visible and layer.layer >= _main._result.layer:
			out.append(String(layer.name))
	return out


func _result_alone() -> bool:
	return _main._result.visible and _above_result().is_empty()


func _above_note() -> String:
	var above: Array[String] = _above_result()
	return "" if above.is_empty() else " (üstte: %s)" % ", ".join(above)


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


## Büyütücü: güç sinyali (GameBoard'un gerçek PowerBar bağlantısı) + hedefe GERÇEK parmak basışı (dönüşüm basışta başlar,
## 0,15 sn anticipation sonra tamamlanır).
func _fire_upgrade(board: Node2D, piece: Dumpling) -> void:
	board._power_bar.power_pressed.emit(int(PowerUp.Type.UPGRADE))
	await _settle(1)
	var at: Vector2 = _win(board, piece.global_position)
	await _finger(at, true)
	await _finger(at, false)


## Ayarlar AÇIKKEN kazanma (üretim yolu): Büyütücü dönüşümü başlar, anticipation içinde Ayarlar açılır ("gear" = HUD
## dişlisine GERÇEK dokunuş, "handler" = dişlinin vardığı Main işleyicisi), dönüşüm hedefe ulaşıp round'u bitirir. Dönüş:
## kurulum doğru mu (Ayarlar bitişten ÖNCE açıktı, board donuktu, dönüşüm sürüyordu, round bitti).
func _finish_with_settings(board: Node2D, opener: String) -> bool:
	var piece: Dumpling = await _piece(board)
	_reset_marks()
	await _fire_upgrade(board, piece)
	if opener == "gear":
		await _finger_tap(_center(board._hud.settings_button))
	else:
		_main._on_board_settings_requested()
	var open_first: bool = _main._settings.visible and not board.is_finished() and is_instance_valid(piece) \
		and piece.is_merging and bool(board.get("_is_menu_paused"))
	await _until_finished(board)
	return open_first and board.is_finished() and not _at_finish.is_empty()


## Pencere yokken kazanma: Büyütücü dönüşümü hedefe ulaşır.
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
	while is_instance_valid(board) and not board.is_finished() and guard < 600:
		await get_tree().physics_frame
		guard += 1


## Round bitene kadar (kare + duvar saati sınırı — dönüşüm 0,15 sn).
func _until_finished(board: Variant, max_msec: int = 3000) -> void:
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
func _drop_ok(board: Variant) -> bool:
	if board == null or not is_instance_valid(board):
		return false
	var before: int = _drops
	await _finger_tap(_board_point(board, -90.0))
	await _physics(3)
	return _drops == before + 1


func _gen() -> int:
	var value: Variant = _main.get("_round_generation")
	return int(value) if value != null else -1


func _seq() -> int:
	var value: Variant = _main.get("_result_seq")
	return int(value) if value != null else -1


func _rounds() -> int:
	return int(SaveManager.data.get("total_rounds_played", 0))


## Diskteki kayıtta bir anahtar (yoksa null).
func _disk_value(key: String) -> Variant:
	if not FileAccess.file_exists(PATH):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return (parsed as Dictionary).get(key) if parsed is Dictionary else null


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
	var gap: int = maxi(_last_back_msec + BACK_GAP_MSEC, int(_main.get("_last_back_msec")) + BACK_GAP_MSEC) \
		- Time.get_ticks_msec()
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


## Kare beklemeden dokunuş (aynı kare penceresi için).
func _tap_now(pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		Input.parse_input_event(_touch_event(pos, pressed, 0))
		Input.flush_buffered_events()


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


func _screen(canvas: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * canvas


func _center(control: Control) -> Vector2:
	if control == null:
		return Vector2.ZERO
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


func _strip_comments(code: String) -> String:
	var lines: PackedStringArray = []
	for line in code.split("\n"):
		var at: int = line.find("#")
		lines.append(line if at == -1 else line.substr(0, at))
	return "\n".join(lines)


## Fonksiyon metninin boş olmayan satırları (kırpılmış; yorumlar `_strip_comments` ile zaten atılmış).
func _lines(fn: String) -> Array:
	var out: Array = []
	for line in fn.split("\n"):
		var text: String = line.strip_edges()
		if not text.is_empty():
			out.append(text)
	return out


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
