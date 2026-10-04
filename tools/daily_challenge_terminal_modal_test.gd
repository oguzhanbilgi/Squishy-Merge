extends Node
## TASK/050 — Günlük meydan okuma bitişi pencere sahipliği: o anki denemenin kabul edilen bitişinden sonra denemenin
## oyun içi engelleyici penceresi (mola) meydan okuma sonucunun üstünde KALMAZ ve girdiyi tutmaz.
## Gerçek Main, gerçek meydan okuma board'u, gerçek fizik, sahte reklam arka ucu. Headless.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_dc_terminal_modal/` altındaki bir yola
## yönlendirilir, sonda geri alınır; gerçek kayıt ailesi (kanonik + .tmp + .bak) başta / sonda bayt bayt karşılaştırılır.
##   godot --headless --audio-driver Dummy --path . res://tools/daily_challenge_terminal_modal_test.tscn
##
## Üretim yolu (build/qa_050/baseline/trace.md): mola / ayarlar dondurması ağaç duraklatması DEĞİL, özel board
## dondurmasıdır. Fizik adımı iki aynı tier parçanın temasını kaydeder; rapor (body_entered) bir sonraki adımın başında
## gelir. Arada girdi molayı açarsa (board donar) rapor yine DONMUŞ parçalara ulaşır → Dumpling.merge_requested →
## GameBoard'un ertelenmiş _resolve_merge'i (molayı denetlemez) → hedef tier → _finish(true) → meydan okumanın KENDİ
## bitiş işleyicisi. TASK/049'un terminal temizliği yalnız normal `_on_round_finished`'daydı: meydan okumada mola
## sonucun (katman 10) üstünde (12) kalıyordu. Kayıp yolları (taşma, hamle bitti) açık molada kesinleşemez.
## Sözleşme (TASK/050): kabul edilen meydan okuma bitişinde (işleyicinin eşzamanlı kısmında, ödül / tamamlanma
## işleminden SONRA, gecikmeden ÖNCE) mola EYLEMSİZ kapanır — Devam / Yeniden / Ana Menü, bırakış, ödül, kayıt YOK;
## sonuç akışı (0,8 sn, deneme kimliği) ve TASK/047 kuralları aynen.
##
## Aynı kare penceresi GERÇEK fizikle kurulur (dikiş yok): iki (hedef − 1) parça bir fizik karesinin İÇİNDE yan yana
## 2 px üst üste tabanda doğar (aynı karenin adımı teması kaydeder); aynı karenin boşta evresinde, temas raporlanmadan
## mola gerçek yoldan açılır (HUD geri dokunuşu / Android geri / mola işleyicisi); sonraki karede gerçek temas raporu →
## gerçek merge → gerçek bitiş. Bitiş anı ölçümü: izleyici round_finished'e Main'den SONRA bağlanır.
##
## Bölümler:
##   A molasız      pencere yokken kazanma (gerçek merge): +20 bir kez, gecikme aynen, CHALLENGE_WIN bir kez, reklam yok
##   B mola · HUD   GERÇEK HUD geri dokunuşu kritik pencerede: bitişte mola kapanır, menü dondurması bırakılır, eylem /
##                  bırakış yok, sonuç gecikmeden sonra açılır; sonuçta GERİ yok sayılır, gerçek dokunuş SONUCA gider
##   C mola · geri  aynısı Android geri yönlendirmesiyle (Main._notification → open_pause_menu)
##   D basılı       bitişte molanın Yeniden / Ana Menü / Devam / X düğmesinde ya da karartmasında BASILI parmak (+ işlenmemiş
##                  olay): gizleme ve bırakış eylem yaymaz, board değişmez, Ana Sayfa'ya gidilmez; parmak gecikme boyunca
##                  basılı kalıp sonucun düğmesi üstünde kalkar / iptal edilir; molayı GERİ açmadan önce tahtada basılı parmak
##   E ödül         ilk başarı molada: +20 ve tamamlanma günü TAM bir kez, aynı anda; bellek = disk; yinelenen sinyal /
##                  gecikme / sonuç ikinci yazma üretmez
##   F yalıtım      kayıtta değişen yalnız daily_challenge + dough (XP / görev / başarım / yıldız / tur / sandık / sonsuz)
##   G reklam yok   normal geçiş reklamı hazır + uygunken meydan okuma bitişi reklam denemez
##   H deneme       gecikmede üretim işleyicisiyle bırakılan / yenilenen denemenin eski sonucu açılmaz (TASK/047)
##   I tekrar       ilk başarıdan önce kayıp → TEKRAR DENE: dizi baştan aynı, ödül yok, mola aynen
##   J tekrar yok   başarıdan sonra yeniden oynama reddedilir (temizlik baypas eklemez)
##   K taşma        açık molada taşma kesinleşmez; kapanınca OVERFLOW kaybı, +20 yok, reklam yok
##   L hamle        son izinli bırakış kabul, sonra sahte parça yok / bırakış reddi; açık molada yatışma işlemez;
##                  MOVES_EXHAUSTED kaybı, +20 yok, reklam yok
##   M gün          D → D+1 kabul, geri D'de D+1 kalır; D+1 molada kazanılır; temizlik gün yazmaz; bozuk saat yazılmaz
##   N TASK/049     normal round: Büyütücü + mola ve aynı karede merge + mola → bitişte kapanır, sonuç tek başına
##   O TASK/048     normal round: gecikmede değiştirilen round'un eski sonucu / reklamı yok; fırlatma aralığı ertelemesi
##   P iptal        meydan okumada ACTION_CANCEL 0 bırakış / 0 hamle, sonraki bağımsız dokunuş 1
##   Q gizli katman temizlikten sonra eski mola noktaları / GERİ hiçbir şey yakalamaz (dokunuş HUD'a ulaşır); öne dönüş
##                  gecikmede sonucu bozmaz; sonuç düğmesi dokunuşu alır
##   T Ayarlar      kapsam dışı ama korunur: kritik pencerede gerçek dişliyle açılan / gecikmede açılan Ayarlar KAPANMAZ,
##                  sonuç altına açılır (mevcut davranış), GERİ / X kendi kuralıyla kapatır, sonuç düğmesi çalışır
##   S kaynak       temizlik meydan okuma işleyicisinde ödülden SONRA, gecikmeden ÖNCE, işleyici düzeyinde tek kez; temizlik
##                  gövdesi TAM iki korumalı satır; normal yol aynen; deneme kimliği / reklamsızlık / TASK/047 kilitleri /
##                  PauseMenu kapısı aynen

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_dc_terminal_modal"
const PATH: String = DIR + "/save.json"
const SECTIONS: int = 19
const MON: String = "2026-09-28"
const THU: String = "2026-10-01"
const FRI: String = "2026-10-02"
const SAT: String = "2026-10-03"
const GOLDEN: Array[int] = [1, 3, 1, 1, 3, 2, 2, 3, 2, 1, 3, 3, 1, 2, 1, 2, 3, 2]
const BACK_GAP_MSEC: int = 320
const CLEANUP: String = "_dismiss_terminal_gameplay_overlays"
const ACTION_KEYS: Array[String] = ["resume", "restart", "exit", "settings_closed", "result_retry", "result_exit"]
const PAUSE_KEYS: Array[String] = ["resume", "restart", "exit"]
const PRESETS: Array = [
	{"target_tier": 5, "container_width": 600.0, "drop_budget": 18},
	{"target_tier": 5, "container_width": 480.0, "drop_budget": 16},
	{"target_tier": 6, "container_width": 600.0, "drop_budget": 38},
	{"target_tier": 5, "container_width": 420.0, "drop_budget": 15},
	{"target_tier": 6, "container_width": 540.0, "drop_budget": 36},
	{"target_tier": 6, "container_width": 480.0, "drop_budget": 32},
	{"target_tier": 6, "container_width": 420.0, "drop_budget": 30},
]

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
## `_win_under_pause`'ın son denemesinin başlangıç durumu (temiz kayıttan hemen sonra) ve deneme sayısı.
var _pre_save: Dictionary = {}
var _pre_dough: int = 0
var _pre_shows: int = 0
var _pre_ready: bool = false
var _attempts: int = 0


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

	await _win_no_pause()
	await _pause_hud()
	await _pause_back()
	await _held_pause_button()
	await _reward_once()
	await _isolation()
	await _no_interstitial()
	await _attempt_token()
	await _retry_before_clear()
	await _no_replay()
	await _overflow_loss()
	await _moves_exhausted()
	await _day_monotonic()
	await _normal_task049()
	await _normal_task048()
	await _cancel_touch()
	await _no_input_catcher()
	await _settings_terminal()
	_source_contract()
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
	DailyRewards.auto_popup_enabled = false
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	UiKit.set_banner_slot(0.0)
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- A) Molasız meydan okuma kazanması ------------------------------------------------------------------------

func _win_no_pause() -> void:
	print("-- A: pencere yokken meydan okuma kazanması — davranış aynen")
	await _fresh(true)
	var ads: MonetizationManager = _main._ads
	var fake: FakeAdBackend = ads._backend
	var shows0: int = fake.interstitial_shows.size()
	AdEvents.clear_recent()
	var dough0: int = SaveManager.dough()
	var board: Node2D = await _start_challenge()
	_c("ön koşul: gerçek meydan okuma denemesi — gün %s (perşembe), kilitli preset T5 · 420 · 15, güç kapalı, tamamlanmamış"
		% THU, board != null and board.is_daily_challenge() and _main._challenge_day == THU
		and board.level.target_tier == 5 and is_equal_approx(board.level.container_width, 420.0)
		and board.drop_budget() == 15 and board.drops_used() == 0 and not board.powers_enabled()
		and SaveManager.daily_challenge_completed_day() == "")
	if board == null:
		_sections_done += 1
		return
	await _win_merge(board)
	var timer: SceneTreeTimer = _last_timer
	_c("kazanma kesinleşti (gerçek merge: tabandaki T4'ün üstüne T4 düştü), bitişte mola / Ayarlar yoktu",
		is_instance_valid(board) and board.is_finished() and timer != null and not _af("pause") and not _af("settings"))
	_c("  … ilk başarı ödülü kesinleşmede bir kez: +20 Hamur, tamamlanma günü %s" % THU,
		_af("dough") == dough0 + 20 and _af("completed") == THU)
	await _until_left(timer, 0.25)
	_c("gecikme sürerken sonuç yok, mola yok", not _main._result.visible and not _main.is_pause_open()
		and timer != null and timer.time_left > 0.0)
	await _after(timer)
	_c("gecikmeden sonra meydan okuma sonucu tam bir kez (CHALLENGE_WIN, ödüllü)", _main._result.visible
		and _main._result.mode() == _mode("CHALLENGE_WIN") and _shows == 1
		and bool(_main._result.challenge_outcome().get("rewarded", false)))
	_c("  … geçiş reklamı denemesi YOK (reklam uygun + hazırken), reklam olayı yok, eylem yok",
		fake.interstitial_shows.size() == shows0 and not ads.break_pending() and _interstitial_events() == 0
		and _no_actions())
	# Yalnız doğrulama kaydı: SceneTreeTimer kare adımıyla ilerler; sınırlar yalnız akıl sağlığı (sabit S'de).
	_c("  … gecikme ölçümü (kayıt): bitişten sonuca %d ms (RESULT_DELAY %.1f sn, kare adımı payıyla)" % [
		_result_msec - _finish_msec, _delay()], _result_msec - _finish_msec >= 400 and _result_msec - _finish_msec <= 2000)
	_sections_done += 1


# --- B / C) Kritik pencerede mola — gerçek yol ------------------------------------------------------------------

func _pause_hud() -> void:
	print("-- B: GERÇEK yol — aynı karede merge + mola GERÇEK HUD geri dokunuşuyla")
	await _critical_path("hud")
	_sections_done += 1


func _pause_back() -> void:
	print("-- C: GERÇEK yol — aynı karede merge + mola Android geri yönlendirmesiyle")
	await _critical_path("back")
	_sections_done += 1


func _critical_path(opener: String) -> void:
	var tag: String = "B HUD geri" if opener == "hud" else "C Android geri"
	var board: Node2D = await _win_under_pause(opener)
	var ok: bool = board != null
	var dough0: int = _pre_dough
	var timer: SceneTreeTimer = _last_timer
	_c("[%s] kurulum (%d deneme): iki T4 temasta, temas raporlanmadan ÖNCE mola gerçek yoldan açıldı (board donuk), " % [
		tag, _attempts] + "raporlanan temasın gerçek merge'i meydan okumayı molada kazandı", ok)
	if not ok:
		return
	var attempt: int = int(_main.get("_challenge_attempt"))
	if is_instance_valid(board):
		print("    gün %s · hedef T%d · bütçe %d · kullanılan %d · zaman: mola %d ms → bitiş %d ms (mola açıldıktan %d ms sonra)"
			% [_main._challenge_day, board.level.target_tier, board.drop_budget(), board.drops_used(), _pause_msec,
			_finish_msec, _finish_msec - _pause_msec])
	_c("[%s] BİTİŞ ANINDA (eşzamanlı, gecikmeden önce) mola KAPANDI" % tag, not _af("pause"))
	_c("  … board'un menü dondurması bırakıldı (menü duraklaması yok, board donuk değil, donmuş parça yok)",
		not _af("menu_paused") and not _af("board_paused") and _af("frozen") == 0)
	_c("  … kapanış eylemsiz: Devam / Yeniden / Ana Menü 0, bırakış 0, board ve deneme aynı",
		_actions_in(_af("actions"), PAUSE_KEYS) == 0 and _drops == 0 and _af("board") and _af("attempt") == attempt)
	_c("  … ödül kesinleşmede yazıldı (+20, gün %s) — temizlik ödülü değiştirmedi" % THU,
		_af("dough") == dough0 + 20 and _af("completed") == THU)
	await _until_left(timer, 0.3)
	_c("gecikme sürerken (dokunuş / GERİ yok): mola kapalı, sonuç henüz yok, board aynı", not _main.is_pause_open()
		and not _main._result.visible and _main._board == board)
	await _after(timer)
	print("    zaman: bitiş → sonuç %d ms; sonuç açıldığında: sonuç görünür=%s (katman %d), mola görünür=%s (katman %d)"
		% [_result_msec - _finish_msec, str(_main._result.visible), _main._result.layer, str(_main.is_pause_open()),
		_main._pause.layer])
	_c("[%s] gecikmeden sonra CHALLENGE_WIN tam bir kez; mola sonucun üstünde DEĞİL" % tag, _main._result.visible
		and _main._result.mode() == _mode("CHALLENGE_WIN") and _shows == 1 and not _main.is_pause_open())
	await _back()
	print("    Android geri sonrası: sonuç görünür=%s, mola görünür=%s, eylemler=%s" % [str(_main._result.visible),
		str(_main.is_pause_open()), str(_actions)])
	_c("sonuçta Android geri: sonuç ekranının kuralı (yok sayılır) — mola açılmadı, sonuç açık, eylem yok",
		_main._result.visible and not _main.is_pause_open() and _no_actions())
	await _wait_settled()
	await _finger_tap(_center(_main._result.primary_button()))
	await _settle(2)
	print("    sonucun ANA SAYFA noktasına gerçek dokunuş sonrası: eylemler=%s, board=%s, sekme=%d" % [str(_actions),
		"YOK" if _main._board == null else "VAR", _main._active_tab])
	_c("[%s] sonucun ANA SAYFA düğmesine gerçek dokunuş SONUCA gitti (sonuç çıkışı 1, mola eylemi 0) → Ana Sayfa" % tag,
		_actions["result_exit"] == 1 and _actions_in(_actions, PAUSE_KEYS) == 0 and _main._board == null
		and _main._active_tab == 0 and _main._screens[0].visible)
	var diff: Array[String] = _diff_keys(_pre_save, SaveManager.data)
	_c("  … Ana Sayfa'ya dönüşten sonra da kayıtta değişen YALNIZ daily_challenge + dough (değişen: %s)" % str(diff),
		_same(diff, ["daily_challenge", "dough"]))


# --- D) Basılı mola düğmesi -------------------------------------------------------------------------------

func _held_pause_button() -> void:
	print("-- D: bitiş anında molada BASILI parmak — gizleme ve bırakış eylem yaymaz, board / ekran değişmez")
	# "+ olay": basıştan sonra işlenmemiş bir olay gelir — Godot gizleme anında odaklı düğmeye sentetik bırakış yollar ve
	# girdi "işlendi" işaretli DEĞİLSE BaseButton onu tıklama sayar (TASK/049 sondası). Bu değişke düğmelerin
	# kapalı-pencere kapısını sınar; düz değişkeler parmak odağı yolunu.
	for variant: Array in [["yeniden başlat", false], ["yeniden başlat", true], ["ana menüye dön", false],
			["ana menüye dön", true], ["devam et", false], ["devam et", true], ["x", false], ["x", true],
			["karartma", false], ["karartma", true]]:
		await _held_variant(String(variant[0]), bool(variant[1]))
	await _held_through_variant("ana menüye dön", false)
	await _held_through_variant("karartma", true)
	await _held_board_variant()
	_sections_done += 1


func _held_variant(button: String, unhandled: bool) -> void:
	var target: String = button + (" + olay" if unhandled else "")
	var board: Node2D = await _win_under_pause("call", button, unhandled)
	var ok: bool = board != null
	var timer: SceneTreeTimer = _last_timer
	_c("[%s] kurulum: mola açıldı, parmak düğmede / karartmada BASILI%s, raporlanan temasın merge'i meydan okumayı bitirdi" % [
		target, ", son olay işlenmemiş" if unhandled else ""], ok)
	if not ok:
		return
	var tab: int = _main._active_tab
	_c("[%s] bitişte mola kapandı; kapanış eylem yaymadı (Devam / Yeniden / Ana Menü 0), board aynı" % target,
		not _af("pause") and _actions_in(_af("actions"), PAUSE_KEYS) == 0 and _af("board"))
	await _finger(_pause_point(button), false)
	await _physics(3)
	await _settle(2)
	_c("[%s] parmak kalkınca da eylem YOK (gizli molanın düğmesi / karartması bırakışı almadı): bırakış 0, board değişmedi, Ana Sayfa'ya gidilmedi"
		% target, _actions_in(_actions, PAUSE_KEYS) == 0 and _drops == 0 and _main._board == board
		and is_instance_valid(board) and board.is_finished() and not _main.is_pause_open() and _main._active_tab == tab)
	await _after(timer)
	_c("[%s] sonuç gecikmeden sonra tam bir kez (CHALLENGE_WIN), mola yok" % target, _main._result.visible
		and _main._result.mode() == _mode("CHALLENGE_WIN") and _shows == 1 and not _main.is_pause_open()
		and _main._board == board)


## Parmak gecikme BOYUNCA basılı kalır, sonuç açıldıktan sonra sonucun ANA SAYFA düğmesi üstüne sürüklenip orada kalkar
## (`cancel`: kalkmak yerine ACTION_CANCEL): sonuç düğmesine tıklama SAYILMAZ, mola eylemi yok; sonra bağımsız bir
## dokunuş sonucu çalıştırır.
func _held_through_variant(button: String, cancel: bool) -> void:
	var target: String = "%s · gecikme boyunca basılı → %s" % [button, "iptal" if cancel else "sonuç düğmesinde kalkar"]
	var board: Node2D = await _win_under_pause("call", button, false)
	var ok: bool = board != null
	var timer: SceneTreeTimer = _last_timer
	_c("[%s] kurulum: parmak molada basılıyken meydan okuma molada kazanıldı, mola bitişte kapandı" % target, ok
		and not _af("pause"))
	if not ok:
		return
	await _after(timer)
	var shown: bool = _main._result.visible and _shows == 1
	var to: Vector2 = _center(_main._result.primary_button())
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = to
	drag.relative = to - _pause_point(button)
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	await get_tree().process_frame
	if cancel:
		await _cancel(to)
	else:
		await _finger(to, false)
	await _settle(2)
	_c("[%s] sonuç açıktı; basılı parmağın bırakışı / iptali sonuca TIKLAMADI (sonuç çıkışı 0), mola eylemi 0, sonuç açık" % target,
		shown and _actions["result_exit"] == 0 and _actions_in(_actions, PAUSE_KEYS) == 0 and _main._result.visible
		and not _main.is_pause_open())
	await _wait_settled()
	await _finger_tap(_center(_main._result.primary_button()))
	await _settle(2)
	_c("[%s] sonra bağımsız dokunuş sonucun ANA SAYFA'sını çalıştırdı (sonuç çıkışı 1) → Ana Sayfa" % target,
		_actions["result_exit"] == 1 and _main._board == null and _main._active_tab == 0)


## Tahtada BASILI parmak (bırakış henüz yok) → kritik pencerede mola Android GERİ ile açılır → meydan okuma molada biter →
## parmak bitmiş board'da kalkar: bırakış yok, hamle yok, sonuca tıklama yok.
func _held_board_variant() -> void:
	var target: String = "tahtada basılı parmak + GERİ"
	var board: Node2D = await _win_under_pause("back", "board", false)
	var ok: bool = board != null
	var timer: SceneTreeTimer = _last_timer
	_c("[%s] kurulum: parmak tahtada basılıyken mola Android geri ile açıldı, meydan okuma molada kazanıldı" % target, ok
		and not _af("pause"))
	if not ok:
		return
	var at: Vector2 = _board_point(board, -90.0)
	await _finger(at, false)
	await _physics(3)
	await _settle(2)
	_c("[%s] parmak bitmiş board'da kalktı: bırakış 0, hamle 0, mola eylemi 0" % target, _drops == 0
		and board.drops_used() == 0 and _actions_in(_actions, PAUSE_KEYS) == 0)
	await _after(timer)
	_c("[%s] sonuç gecikmeden sonra tam bir kez; parmağın bırakışı sonuca dokunmadı (sonuç çıkışı 0)" % target,
		_main._result.visible and _shows == 1 and _actions["result_exit"] == 0 and _main._board == board)


# --- E) Ödül tam bir kez ----------------------------------------------------------------------------------------

func _reward_once() -> void:
	print("-- E: ilk başarı molada — +20 ve tamamlanma günü TAM bir kez, aynı işlemde; sonrasında yazma girişimi YOK")
	var board: Node2D = await _win_under_pause("call")
	var ok: bool = board != null
	var dough0: int = _pre_dough
	var timer: SceneTreeTimer = _last_timer
	var bytes: PackedByteArray = _bytes()
	_c("kurulum: ilk başarı mola açıkken (aynı karede merge) kesinleşti", ok)
	_c("+20 Hamur TAM bir kez ve tamamlanma günü %s — ikisi aynı kesinleşme anında (eşzamanlı, gecikmeden önce)" % THU,
		_af("dough") == dough0 + 20 and _af("completed") == THU and SaveManager.dough() == dough0 + 20
		and SaveManager.daily_challenge_completed_day() == THU)
	_c("  … bellek = disk (tek işlem kayda yazıldı)", _disk_equals_memory())
	# Bundan sonra HİÇBİR yazma girişimi olmamalı: bir sonraki SaveFile.write_save enjeksiyonu tüketir (aynı içerikle
	# yeniden yazma da yakalanır — her yazma ana dosyayı .bak'a döndürür).
	SaveFile.fault = SaveFile.Fault.TEMP_OPEN
	var finalized: bool = bool(_main.get("_round_finalized"))
	if board != null and is_instance_valid(board):
		board.round_finished.emit(true)
		board.round_finished.emit(true)
	await _settle(2)
	_c("yinelenen round_finished(true) ×2 (aynı board): ikinci kesinleşme yok — Hamur, gün ve kayıt baytları aynı",
		finalized and SaveManager.dough() == dough0 + 20 and _bytes() == bytes)
	await _after(timer)
	await _wait(0.3)
	_c("gecikme + sonuç sonrası: ikinci ödül yok, sonuç tam bir kez ve hâlâ ilk başarının ('+20 HAMUR', ödüllü)",
		SaveManager.dough() == dough0 + 20 and _shows == 1 and _main._result.mode() == _mode("CHALLENGE_WIN")
		and _main._result.challenge_body_text() == String(_result_const("CHALLENGE_REWARD")) % 20
		and bool(_main._result.challenge_outcome().get("rewarded", false)))
	_c("  … kesinleşmeden sonra YAZMA GİRİŞİMİ YOK (enjekte edilen hata tüketilmedi), kayıt baytları aynı",
		SaveFile.fault == SaveFile.Fault.TEMP_OPEN and _bytes() == bytes)
	_c("  … aynı gün ikinci tamamlama +0 (SaveManager reddeder, yazmaz)", not SaveManager.complete_daily_challenge(THU)
		and SaveManager.dough() == dough0 + 20 and _bytes() == bytes and SaveFile.fault == SaveFile.Fault.TEMP_OPEN)
	SaveFile.fault = SaveFile.Fault.NONE
	_sections_done += 1


# --- F) İlerleme yalıtımı ---------------------------------------------------------------------------------------

func _isolation() -> void:
	print("-- F: meydan okuma molada kazanıldı — kayıtta yalnız Hamur + tamamlanma günü değişir")
	var board: Node2D = await _win_under_pause("hud")
	var ok: bool = board != null
	var before: Dictionary = _pre_save
	await _after(_last_timer)
	var after: Dictionary = SaveManager.data.duplicate(true)
	var diff: Array[String] = _diff_keys(before, after)
	_c("kurulum: mola açıkken kazanıldı, bitişte kapandı, sonuç açıldı", ok and not _af("pause") and _main._result.visible)
	_c("kayıtta değişen YALNIZ daily_challenge + dough (değişen: %s)" % str(diff), _same(diff, ["daily_challenge", "dough"]))
	var same: Array[String] = []
	for key: String in ["player_xp", "missions", "unlocked_achievements", "level_stars", "total_rounds_played",
			"total_merges", "merges_since_bonus_chest", "highest_tier_created", "highest_level_unlocked",
			"endless_high_score", "powerups", "unlocked_skins"]:
		if JSON.stringify(_norm(before.get(key))) == JSON.stringify(_norm(after.get(key))):
			same.append(key)
	_c("  … XP / görev / başarım / yıldız / tur / toplam merge / bonus sandık sayacı / en yüksek tier / level / sonsuz rekoru / güç / koleksiyon aynen (%d/12)"
		% same.size(), same.size() == 12)
	var block: Dictionary = after.get("daily_challenge", {})
	var names: Array = block.keys()
	names.sort()
	_c("  … daily_challenge bloğu yalnız sürüm 1 + tamamlanma günü (yeni alan yok): %s" % JSON.stringify(_norm(block)),
		_same(names, ["completed_day_key", "version"]) and int(block.get("version", 0)) == 1
		and String(block.get("completed_day_key", "")) == THU)
	_sections_done += 1


# --- G) Geçiş reklamı yok ---------------------------------------------------------------------------------------

func _no_interstitial() -> void:
	print("-- G: normal geçiş reklamı hazır + uygunken meydan okuma bitişi reklam denemez (ödüllü de yok)")
	var board: Node2D = await _win_under_pause("call", "", false, true)
	var ok: bool = board != null
	var ads: MonetizationManager = _main._ads
	var fake: FakeAdBackend = ads._backend
	_c("ön koşul: normal geçiş reklamı UYGUN + HAZIR (başlatmadan önce)", _pre_ready)
	var shows0: int = _pre_shows
	await _after(_last_timer)
	await _wait(0.5)
	_c("kurulum: mola açıkken kazanıldı", ok)
	_c("meydan okuma bitişi geçiş reklamı DENEMEZ: gösterim yok, reklam molası yok, reklam olayı yok, reklam nesli yok",
		fake.interstitial_shows.size() == shows0 and not ads.break_pending() and _interstitial_events() == 0
		and int(_main.get("_round_break_generation")) == -1)
	_c("  … ödüllü reklam da yok: gösterim / istek / gösterildi olayı 0; tam ekran bekleme süresi başlamadı",
		fake.rewarded_shows.is_empty() and AdEvents.count(&"rewarded_requested") == 0
		and AdEvents.count(&"rewarded_showed") == 0 and ads.fullscreen_cooldown_sec() <= 0.0)
	_c("  … temizlik meydan okumayı normal reklam yoluna sokmadı: sonuç açıldı (CHALLENGE_WIN, RESULT yüzeyi), reklam hâlâ uygun + hazır",
		_main._result.visible and _main._result.mode() == _mode("CHALLENGE_WIN") and _shows == 1
		and ads.surface() == MonetizationManager.Surface.RESULT and ads.interstitial_eligible()
		and ads.is_interstitial_ready())
	var diff: Array[String] = _diff_keys(_pre_save, SaveManager.data)
	_c("  … reklam arka ucu açıkken de kayıtta değişen YALNIZ daily_challenge + dough (değişen: %s)" % str(diff),
		_same(diff, ["daily_challenge", "dough"]))
	_sections_done += 1


# --- H) Deneme kimliği ------------------------------------------------------------------------------------------

func _attempt_token() -> void:
	print("-- H: deneme kimliği — gecikmede bırakılan / yenilenen denemenin eski sonucu açılmaz (TASK/047)")
	# H1 — molada kazanılan deneme, gecikme İÇİNDE üretim "Ana Menüye Dön" işleyicisiyle bırakılır (mola bitişte kapandığı
	# için işleyici doğrudan çağrılır — dar dikiş, üretim kodu aynen).
	var board: Node2D = await _win_under_pause("call")
	var ok: bool = board != null
	var dough0: int = _pre_dough
	var timer: SceneTreeTimer = _last_timer
	await _until_left(timer, 0.4)
	_main.abandon_run()
	await _settle(2)
	_c("H1 kurulum: mola açıkken kazanıldı; gecikme İÇİNDE üretim çıkış işleyicisi denemeyi bıraktı → Ana Sayfa", ok
		and _main._board == null and _main._active_tab == 0 and not _main.is_daily_challenge_round())
	await _after(timer)
	await _wait(0.3)
	_c("H1: eski denemenin gecikmeli sonucu AÇILMADI (deneme / board doğrulaması), mola yok, ödül yine tam bir kez",
		_shows == 0 and not _main._result.visible and not _main.is_pause_open() and SaveManager.dough() == dough0 + 20
		and SaveManager.daily_challenge_completed_day() == THU)
	# H2 — kayıp kesinleşir; gecikme İÇİNDE üretim "Yeniden Başlat" işleyicisi yeni deneme kurar.
	await _fresh()
	board = await _start_challenge()
	var attempt0: int = int(_main.get("_challenge_attempt"))
	if board != null:
		await _pile_kings(board)
		await _until_finished(board, 4000)
	timer = _last_timer
	_c("H2 kurulum: taşma kaybı (OVERFLOW) kesinleşti, bitişte mola yoktu", is_instance_valid(board) and board.is_finished()
		and board.fail_reason() == DailyChallenge.FailReason.OVERFLOW and not _af("pause"))
	await _until_left(timer, 0.4)
	_main._on_pause_restart()
	await _settle(3)
	var next: Node2D = _main._board
	_track(next)
	_c("H2: gecikme içinde üretim yeniden başlatma işleyicisi YENİ deneme kurdu (deneme + 1, yeni board, aynı gün)",
		next != null and next != board and int(_main.get("_challenge_attempt")) == attempt0 + 1
		and next.is_daily_challenge() and _main._challenge_day == THU)
	await _after(timer)
	await _wait(0.3)
	_c("H2: eski denemenin gecikmeli kayıp sonucu AÇILMADI; yeni deneme canlı (bitmemiş, hamle 0)", _shows == 0
		and not _main._result.visible and _main._board == next and next != null and not next.is_finished()
		and next.drops_used() == 0)
	_sections_done += 1


# --- I) İlk başarıdan önce tekrar ------------------------------------------------------------------------------

func _retry_before_clear() -> void:
	print("-- I: kayıp → TEKRAR DENE: dizi baştan aynı (yeni dizi kaynağı), ödül yok, mola aynen")
	await _fresh()
	var dough0: int = SaveManager.dough()
	var board: Node2D = await _start_challenge()
	_c("ön koşul: deneme dizisi pinlenmiş vektörden (bekleyen %s, sıradaki %s)" % [
		str(board._pending_tier) if board != null else "-", str(board._next_tier) if board != null else "-"],
		board != null and board._pending_tier == GOLDEN[0] and board._next_tier == GOLDEN[1])
	if board == null:
		_sections_done += 1
		return
	var old_bag: int = (board._drop_bag as Object).get_instance_id()
	for i in 3:
		await _quick_drop(board, i)
	var advanced: bool = board.drops_used() == 3 and board._pending_tier == GOLDEN[3] and board._next_tier == GOLDEN[4]
	await _pile_kings(board)
	await _until_finished(board, 4000)
	await _after(_last_timer)
	_c("üç bırakış (dizi vektör[3..4]'te) sonra taşma kaybı: CHALLENGE_FAIL tam bir kez, +20 yok, gün yazılmadı", advanced
		and _main._result.visible and _main._result.mode() == _mode("CHALLENGE_FAIL") and _shows == 1
		and SaveManager.dough() == dough0 and SaveManager.daily_challenge_completed_day() == "")
	await _wait_settled()
	await _finger_tap(_center(_main._result.primary_button()))
	await _settle(3)
	var next: Node2D = _main._board
	_track(next)
	var bag: Variant = next._drop_bag if next != null else null
	_c("TEKRAR DENE (gerçek dokunuş) → yeni deneme: dizi baştan AYNI (bekleyen / sıradaki = vektör[0..1]), hamle 0, ödül yok",
		next != null and next != board and next.is_daily_challenge() and next._pending_tier == GOLDEN[0]
		and next._next_tier == GOLDEN[1] and next.drops_used() == 0 and SaveManager.dough() == dough0
		and _actions["result_retry"] == 1)
	_c("  … yeni deneme YENİ bir dizi kaynağı aldı (aynı günün DailyChallenge.Sequence'ı, eski kaynağın devamı değil)",
		bag is DailyChallenge.Sequence and (bag as Object).get_instance_id() != old_bag
		and String((bag as DailyChallenge.Sequence).day_key) == THU)
	if next == null:
		_sections_done += 1
		return
	await _wait_settled()
	await _finger_tap(_center(next._hud.back_button))
	await _settle(2)
	var opened: bool = _main.is_pause_open() and next._is_menu_paused
	await _wait_settled()
	await _finger_tap(_pause_point("devam et"))
	await _settle(2)
	_c("yeni denemede mola aynen: gerçek HUD geri açtı (board donuk), gerçek DEVAM ET kapattı (board çözüldü, Devam 1)",
		opened and not _main.is_pause_open() and not next._is_paused() and _actions["resume"] == 1)
	await _wait_settled()
	var dropped: bool = await _drop_ok(next)
	_c("  … deneme sürüyor: gerçek dokunuşta tam 1 bırakış, hamle 1", dropped and next.drops_used() == 1)
	_sections_done += 1


# --- J) Başarıdan sonra yeniden oynama yok ------------------------------------------------------------------

func _no_replay() -> void:
	print("-- J: başarıdan sonra yeniden oynama reddedilir — temizlik baypas eklemez, reddedilen yollar yazmaz")
	# J1 — molada kazanılan deneme; gecikme İÇİNDE (meydan okuma türü hâlâ açık) molanın üretim Yeniden Başlat işleyicisi —
	# mola bitişte kapandığı için doğrudan çağrılır (dar dikiş).
	var board: Node2D = await _win_under_pause("call")
	var ok: bool = board != null
	var timer: SceneTreeTimer = _last_timer
	var attempt: int = int(_main.get("_challenge_attempt"))
	SaveFile.fault = SaveFile.Fault.TEMP_OPEN
	await _until_left(timer, 0.4)
	_main._on_pause_restart()
	await _settle(3)
	_c("J1: molada kazanıldı; gecikme içinde molanın üretim Yeniden Başlat işleyicisi yeni deneme KURMADI → Ana Sayfa (deneme aynı)",
		ok and _main._board == null and _main._active_tab == 0 and int(_main.get("_challenge_attempt")) == attempt)
	await _after(timer)
	await _wait(0.3)
	_c("  … J1: eski deneme sonucu açılmadı; yazma girişimi YOK (enjekte edilen hata tüketilmedi), Hamur +20 bir kez",
		_shows == 0 and SaveFile.fault == SaveFile.Fault.TEMP_OPEN and SaveManager.dough() == _pre_dough + 20)
	SaveFile.fault = SaveFile.Fault.NONE
	# J2 — sonuç açıkken: başlatma / sonucun tekrar işleyicisi / Ana Sayfa penceresinin BAŞLA'sı reddedilir.
	board = await _win_under_pause("call")
	ok = board != null
	timer = _last_timer
	attempt = int(_main.get("_challenge_attempt"))
	SaveFile.fault = SaveFile.Fault.TEMP_OPEN
	await _after(timer)
	var dough1: int = SaveManager.dough()
	_c("J2 kurulum: mola açıkken kazanıldı, sonuç açık (CHALLENGE_WIN)", ok and _main._result.visible
		and _main._result.mode() == _mode("CHALLENGE_WIN"))
	_c("kazanma sonucunda TEKRAR yok (yalnız ANA SAYFA): ikincil düğme görünmez", not _main._result.secondary_button().visible)
	var view: Dictionary = DailyChallenge.current_view()
	_c("gün tamamlandı: görünüm completed, start_daily_challenge REDDEDİLDİ (board aynı, yeni deneme yok)",
		bool(view.get("completed", false)) and not _main.start_daily_challenge() and _main._board == board
		and int(_main.get("_challenge_attempt")) == attempt)
	_main._on_retry_pressed()
	await _settle(3)
	_c("  … sonuç açıkken üretim tekrar işleyicisi de yeni deneme KURMAZ → Ana Sayfa (Hamur aynı, deneme aynı)",
		_main._board == null and _main._active_tab == 0 and SaveManager.dough() == dough1
		and int(_main.get("_challenge_attempt")) == attempt)
	_main.open_daily_challenge()
	await _settle(2)
	var sheet: bool = _main._challenge_sheet.visible
	_main._on_challenge_start_requested(THU)
	await _settle(3)
	_c("  … Ana Sayfa penceresinin BAŞLA'sı da başlatmaz (board yok, Hamur aynı, deneme aynı)", sheet and _main._board == null
		and SaveManager.dough() == dough1 and int(_main.get("_challenge_attempt")) == attempt)
	_c("  … sonuç + reddedilen yeniden oynama yolları boyunca YAZMA GİRİŞİMİ YOK (enjekte edilen hata tüketilmedi)",
		SaveFile.fault == SaveFile.Fault.TEMP_OPEN)
	SaveFile.fault = SaveFile.Fault.NONE
	_sections_done += 1


# --- K) Taşma kaybı -----------------------------------------------------------------------------------------

func _overflow_loss() -> void:
	print("-- K: taşma — açık molada kesinleşmez; kapanınca OVERFLOW kaybı aynen")
	await _fresh(true)
	var ads: MonetizationManager = _main._ads
	var fake: FakeAdBackend = ads._backend
	var shows0: int = fake.interstitial_shows.size()
	AdEvents.clear_recent()
	var dough0: int = SaveManager.dough()
	var before: Dictionary = SaveManager.data.duplicate(true)
	var board: Node2D = await _start_challenge()
	if board == null:
		_c("kurulum: meydan okuma başladı", false)
		_sections_done += 1
		return
	await _pile_kings(board)
	var guard: int = 0
	while float(board.get("_overflow_elapsed")) < 0.1 and not board.is_finished() and guard < 300:
		await get_tree().physics_frame
		guard += 1
	_main.open_pause_menu()
	await _settle(1)
	var paused: bool = _main.is_pause_open() and board._is_menu_paused and not board.is_finished()
	var elapsed: float = float(board.get("_overflow_elapsed"))
	await _wait(2.0)
	_c("taşma sayacı açık molada İLERLEMEZ: 2,0 sn (> OVERFLOW_GRACE 1,5) sonra round bitmedi, sayaç aynı (%.2f sn)" % elapsed,
		paused and elapsed > 0.0 and not board.is_finished() and is_equal_approx(float(board.get("_overflow_elapsed")), elapsed))
	_main.resume_game()
	await _until_finished(board, 4000)
	var timer: SceneTreeTimer = _last_timer
	_c("mola kapanınca kalan süre işledi → kesin kayıp, sebep OVERFLOW (devam yok), bitişte mola yok",
		is_instance_valid(board) and board.is_finished() and board.fail_reason() == DailyChallenge.FailReason.OVERFLOW
		and not _af("pause") and not _main._revive.visible)
	await _after(timer)
	_c("kayıp sonucu tam bir kez (CHALLENGE_FAIL, taşma metni), +20 yok, gün yazılmadı", _main._result.visible
		and _main._result.mode() == _mode("CHALLENGE_FAIL") and _shows == 1
		and _main._result.challenge_body_text() == String(_result_const("CHALLENGE_OVERFLOW"))
		and SaveManager.dough() == dough0 and SaveManager.daily_challenge_completed_day() == "")
	_c("  … geçiş reklamı denemesi yok (reklam uygun + hazır), eylem yok", fake.interstitial_shows.size() == shows0
		and not ads.break_pending() and _interstitial_events() == 0 and _actions_in(_actions, PAUSE_KEYS) == 0)
	var diff: Array[String] = _diff_keys(before, SaveManager.data)
	_c("  … taşma kaybı kayda HİÇBİR ŞEY yazmadı (değişen: %s)" % str(diff), diff.is_empty())
	_sections_done += 1


# --- L) Hamle bitti -----------------------------------------------------------------------------------------

func _moves_exhausted() -> void:
	print("-- L: hamle bitti — son izinli bırakış kabul, sahte parça yok, açık molada yatışma işlemez, kayıp aynen")
	await _fresh(true)
	var ads: MonetizationManager = _main._ads
	var fake: FakeAdBackend = ads._backend
	var shows0: int = fake.interstitial_shows.size()
	AdEvents.clear_recent()
	var dough0: int = SaveManager.dough()
	var before: Dictionary = SaveManager.data.duplicate(true)
	var board: Node2D = await _start_challenge()
	if board == null:
		_c("kurulum: meydan okuma başladı", false)
		_sections_done += 1
		return
	var budget: int = board.drop_budget()
	# Hızlandırma (durum dikişi): bütçenin son bırakışına gelinir — HUD / önizleme üretim fonksiyonlarıyla tazelenir.
	board._drops_used = budget - 1
	board._hud.set_moves(1)
	board._refresh_challenge_previews()
	var dropped: bool = await _drop_ok(board)
	_c("son izinli bırakış gerçek dokunuşla KABUL edildi (hamle %d / %d); ardından sahte parça yok (önizleme / SIRADAKİ gizli), yatışma başladı"
		% [board.drops_used(), budget], dropped and board.drops_used() == budget and board.drops_remaining() == 0
		and not board._preview.visible and board.is_settling())
	await _wait(0.45)
	var drops: int = _drops
	await _finger_tap(_board_point(board, 60.0))
	await _physics(3)
	_c("  … bütçe bittikten sonra gerçek dokunuş bırakış ÜRETMEDİ (hamle aynı, yeni parça yok)", _drops == drops
		and board.drops_used() == budget)
	var guard: int = 0
	while not bool(board.get("_settle_landed")) and not board.is_finished() and guard < 300:
		await get_tree().physics_frame
		guard += 1
	_main.open_pause_menu()
	await _settle(1)
	var paused: bool = _main.is_pause_open() and board._is_menu_paused and not board.is_finished()
	await _wait(DailyChallenge.SETTLE_QUIET_SEC + 0.6)
	_c("açık molada yatışma İŞLEMEZ: %.1f sn (> sessiz pencere %.1f) sonra round bitmedi, yatışma sürüyor" % [
		DailyChallenge.SETTLE_QUIET_SEC + 0.6, DailyChallenge.SETTLE_QUIET_SEC], paused and not board.is_finished()
		and board.is_settling())
	_main.resume_game()
	await _until_finished(board, 7000)
	var timer: SceneTreeTimer = _last_timer
	_c("mola kapanınca yatışma tamamlandı → kesin kayıp, sebep MOVES_EXHAUSTED, bitişte mola yok",
		is_instance_valid(board) and board.is_finished()
		and board.fail_reason() == DailyChallenge.FailReason.MOVES_EXHAUSTED and not _af("pause"))
	await _after(timer)
	_c("kayıp sonucu tam bir kez (CHALLENGE_FAIL, hamle metni), +20 yok, gün yazılmadı, geçiş reklamı denemesi yok",
		_main._result.visible and _main._result.mode() == _mode("CHALLENGE_FAIL") and _shows == 1
		and _main._result.challenge_body_text() == String(_result_const("CHALLENGE_MOVES"))
		and SaveManager.dough() == dough0 and SaveManager.daily_challenge_completed_day() == ""
		and fake.interstitial_shows.size() == shows0 and not ads.break_pending() and _interstitial_events() == 0)
	var diff: Array[String] = _diff_keys(before, SaveManager.data)
	_c("  … hamle bitti kaybı kayda HİÇBİR ŞEY yazmadı (değişen: %s)" % str(diff), diff.is_empty())
	_sections_done += 1


# --- M) Monoton gün -----------------------------------------------------------------------------------------

func _day_monotonic() -> void:
	print("-- M: monoton gün — D → D+1, geri D'de D+1 kalır; temizlik gün GÖZLEMLEMEZ, sonuç anı gözlemler; bozuk saat yazılmaz")
	var board: Node2D = null
	var ok: bool = false
	var forward: String = ""
	var back: String = ""
	var seen: String = ""
	var preset_ok: bool = false
	var dough0: int = 0
	var attempts: int = 0
	while not ok and attempts < 3:
		attempts += 1
		await _fresh()
		DailyRewards.clock_override = FRI
		forward = DailyChallenge.current_day()
		DailyRewards.clock_override = THU
		back = DailyChallenge.current_day()
		seen = SaveManager.daily_last_seen_day_key()
		dough0 = SaveManager.dough()
		board = await _start_challenge()
		preset_ok = board != null and _main._challenge_day == FRI and board.level.target_tier == 6 \
			and is_equal_approx(board.level.container_width, 540.0) and board.drop_budget() == 36
		if board == null:
			break
		await _warm_pause(board)
		# Deneme sürerken gece yarısı geçer (D+2): kesinleşmede hiçbir yol günü gözlemlememeli; sonuç anı gözlemler.
		DailyRewards.clock_override = SAT
		ok = await _critical_pause(board, "call")
	_c("gün D (%s) → D+1 (%s) kabul edildi; saat geri D'ye alınınca meydan okuma D+1'de KALIR (last_seen %s)" % [THU,
		forward, seen], forward == FRI and back == FRI and seen == FRI)
	_c("geri alınmış saatte başlayan deneme D+1'in (cuma T6 · 540 · 36)", preset_ok)
	var timer: SceneTreeTimer = _last_timer
	_c("D+1 meydan okuması (saat artık D+2) mola açıkken kazanıldı: bitişte mola kapandı, +20 bir kez, ödül denemenin BAŞLADIĞI güne (D+1)",
		ok and not _af("pause") and _af("dough") == dough0 + 20 and _af("completed") == FRI)
	_c("  … kesinleşmede (temizlik dahil) gün GÖZLEMLENMEDİ: last_seen hâlâ D+1 (%s)" % str(_af("last_seen")),
		_af("last_seen") == FRI)
	await _after(timer)
	_c("sonuç anı günü okur (TASK/047): last_seen D+2, sonuçta 'gün değişti', tamamlanma D+1 ve Hamur +20 aynen",
		SaveManager.daily_last_seen_day_key() == SAT and bool(_main._result.challenge_outcome().get("day_changed", false))
		and SaveManager.daily_challenge_completed_day() == FRI and SaveManager.dough() == dough0 + 20)
	var bytes: PackedByteArray = _bytes()
	DailyRewards.clock_override = THU
	_c("saat geri D'ye: meydan okuma görülen en yeni günde (D+2) kalır; D+1 ödülü tekrar verilmez, kayıt aynı",
		DailyChallenge.current_day() == SAT and SaveManager.daily_challenge_completed_day() == FRI
		and SaveManager.dough() == dough0 + 20 and _bytes() == bytes)
	DailyRewards.clock_override = "bozuk-saat"
	var invalid: String = DailyChallenge.current_day()
	_c("bozuk saat 'bozuk-saat' kaydedilmez (TASK/047 kuralı): gün gerçeği yok ('%s' — başlatma reddedilir), last_seen aynen, kayıt aynı"
		% invalid, invalid == "" and not _main.start_daily_challenge() and SaveManager.daily_last_seen_day_key() == SAT
		and _bytes() == bytes)
	DailyRewards.clock_override = "1970-01-01"
	var ancient: String = DailyChallenge.current_day()
	_c("geçmişte kalan geçersiz saat '1970-01-01' de yazılmaz: meydan okuma görülen en yeni günde ('%s'), kayıt aynı" % ancient,
		ancient == SAT and SaveManager.daily_last_seen_day_key() == SAT and _bytes() == bytes)
	DailyRewards.clock_override = THU
	_sections_done += 1


# --- N) TASK/049 normal round ----------------------------------------------------------------------------

func _normal_task049() -> void:
	print("-- N: TASK/049 normal round aynen — Büyütücü + mola ve aynı karede merge + mola")
	await _fresh()
	var board: Node2D = await _start_normal(3)
	var ok: bool = await _finish_with_upgrade_pause(board)
	var timer: SceneTreeTimer = _last_timer
	_c("N1 kurulum: Büyütücü dönüşümü sürerken mola açıldı, dönüşüm normal round'u molada bitirdi", ok)
	_c("N1: bitişte mola kapandı, menü dondurması bırakıldı, eylem 0", not _af("pause") and not _af("menu_paused")
		and _actions_in(_af("actions"), PAUSE_KEYS) == 0)
	await _after(timer)
	_c("N1: gecikmeden sonra WIN tam bir kez, mola sonucun üstünde değil", _main._result.visible
		and _main._result.mode() == _mode("WIN") and _shows == 1 and not _main.is_pause_open())
	ok = false
	var attempts: int = 0
	while not ok and attempts < 3:
		attempts += 1
		await _fresh()
		board = await _start_normal(3)
		if board == null:
			break
		await _warm_pause(board)
		ok = await _critical_pause(board, "call")
	timer = _last_timer
	_c("N2 kurulum (%d deneme): normal round'da aynı karede merge (gerçek fizik) mola açıkken round'u bitirdi" % attempts, ok)
	_c("N2: bitişte mola kapandı, eylem 0", not _af("pause") and _actions_in(_af("actions"), PAUSE_KEYS) == 0)
	await _after(timer)
	_c("N2: gecikmeden sonra WIN tam bir kez, mola yok", _main._result.visible and _main._result.mode() == _mode("WIN")
		and _shows == 1 and not _main.is_pause_open())
	# N3 — AYNI oturumda meydan okumadan hemen sonra normal round: meydan okuma durumu sızmaz, normal ilerleme bir kez.
	var challenge: Node2D = await _win_under_pause("call")
	var won: bool = challenge != null
	await _after(_last_timer)
	var after_challenge: Dictionary = SaveManager.data.duplicate(true)
	await _wait_settled()
	await _finger_tap(_center(_main._result.primary_button()))
	await _settle(2)
	var home: bool = won and _main._board == null and _main._active_tab == 0
	board = await _start_normal(3)
	var kind_ok: bool = board != null and not _main.is_daily_challenge_round() and String(_main.get("_challenge_day")) == "" \
		and not bool(_main.get("_round_finalized"))
	var shows0: int = _shows
	ok = await _finish_with_upgrade_pause(board)
	timer = _last_timer
	await _after(timer)
	var diff: Array[String] = _diff_keys(after_challenge, SaveManager.data)
	_c("N3 kurulum: meydan okuma molada kazanıldı → ANA SAYFA; aynı oturumda normal Level 3 temiz başladı (tür NORMAL, gün boş, kesinleşme sıfır)",
		home and kind_ok)
	_c("N3: normal round molada bitti; bitişte mola kapandı, WIN tam bir kez (level 3)", ok and not _af("pause")
		and _main._result.visible and _main._result.mode() == _mode("WIN") and _shows == shows0 + 1)
	_c("  … normal ilerleme bir kez yazıldı (tur + 1); meydan okuma alanları değişmedi (daily_challenge / Hamur dışında normal anahtarlar: %s)"
		% str(diff), int(SaveManager.data.get("total_rounds_played", 0)) == int(after_challenge.get("total_rounds_played", 0)) + 1
		and not diff.has("daily_challenge") and JSON.stringify(_norm(SaveManager.data.get("daily_challenge")))
		== JSON.stringify(_norm(after_challenge.get("daily_challenge"))))
	_sections_done += 1


# --- O) TASK/048 normal round ----------------------------------------------------------------------------

func _normal_task048() -> void:
	print("-- O: TASK/048 aynen — gecikmede değiştirilen round eski sonuç / reklam açmaz; fırlatma aralığı ertelemesi")
	await _fresh(true)
	var ads: MonetizationManager = _main._ads
	var fake: FakeAdBackend = ads._backend
	var board: Node2D = await _start_normal(3)
	await _win_merge(board)
	var timer: SceneTreeTimer = _last_timer
	var shows0: int = fake.interstitial_shows.size()
	await _until_left(timer, 0.3)
	_main._on_pause_restart()
	await _settle(3)
	var next: Node2D = _main._board
	_track(next)
	await _after(timer)
	await _wait(0.3)
	_c("O1: gecikme içinde üretim yeniden başlatma işleyicisiyle değiştirilen round'un eski sonucu / geçiş reklamı AÇILMADI",
		next != null and next != board and _shows == 0 and fake.interstitial_shows.size() == shows0
		and not ads.break_pending() and not _main._result.visible)
	if next == null:
		_sections_done += 1
		return
	await _wait_settled()
	await _win_merge(next)
	var limit: int = Time.get_ticks_msec() + 3000
	while not ads.break_pending() and Time.get_ticks_msec() < limit:
		await get_tree().process_frame
	var board_id: int = next.get_instance_id()
	var gen: int = _gen()
	_main._on_pause_restart()
	await _settle(1)
	var deferred: bool = ads.break_pending() and _owns(board_id, gen)
	_c("O2: reklam SDK'ya verildikten sonra (fırlatma aralığı) üretim yeniden başlatma ERTELENDİ (board + nesil aynı)", deferred)
	if fake.interstitial_shows.size() > shows0:
		var id: String = fake.interstitial_shows[-1]
		fake.emit_interstitial_showed(id)
		await _settle(1)
		fake.emit_interstitial_dismissed(id)
		await _settle(3)
	_c("  … O2: kapanışta ertelenen yeniden başlatma eski sonucun YERİNE çalıştı (yeni board, sonuç yok, mola yok)",
		deferred and _differs(_main._board, board_id) and not _main._result.visible and not _main.is_pause_open())
	_sections_done += 1


# --- P) ACTION_CANCEL -------------------------------------------------------------------------------------

func _cancel_touch() -> void:
	print("-- P: meydan okumada ACTION_CANCEL 0 bırakış / 0 hamle; sonraki bağımsız dokunuş 1; temizlik sonrası sızıntı yok")
	await _fresh()
	var board: Node2D = await _start_challenge()
	if board == null:
		_c("kurulum: meydan okuma başladı", false)
		_sections_done += 1
		return
	var at: Vector2 = _board_point(board, -90.0)
	var used: int = board.drops_used()
	await _finger(at, true)
	await _cancel(at)
	await _physics(3)
	_c("iptal edilen dokunuş (ACTION_CANCEL): 0 bırakış, hamle maliyeti 0", _drops == 0 and board.drops_used() == used)
	var dropped: bool = await _drop_ok(board)
	_c("  … sonraki bağımsız dokunuş: tam 1 bırakış, hamle + 1", dropped and board.drops_used() == used + 1)
	board = await _win_under_pause("call")
	var timer: SceneTreeTimer = _last_timer
	var drops: int = _drops
	if board != null:
		at = _board_point(board, -90.0)
		await _finger(at, true)
		await _cancel(at)
		await _finger_tap(_board_point(board, 40.0))
		await _physics(3)
	_c("molada kazanıldı, bitişte kapandı; gecikmede iptal edilen + düz dokunuş bitmiş board'a bırakış / hamle ÜRETMEZ",
		board != null and is_instance_valid(board) and not _af("pause") and _drops == drops and board.drops_used() == 0)
	await _after(timer)
	_sections_done += 1


# --- Q) Gizli katman / girdi yakalayıcı yok ---------------------------------------------------------------

func _no_input_catcher() -> void:
	print("-- Q: temizlikten sonra gizli mola katmanı girdi yakalamaz (dokunuş HUD'a ulaşır); öne dönüş; sonuç düğmesi")
	var board: Node2D = await _win_under_pause("hud")
	var ok: bool = board != null
	var timer: SceneTreeTimer = _last_timer
	_c("kurulum: mola açıkken kazanıldı, bitişte kapandı", ok and not _af("pause"))
	if not ok:
		_sections_done += 1
		return
	var hud_back: Array[int] = [0]
	board.pause_requested.connect(func() -> void: hud_back[0] += 1)
	# Karartmanın köşesi (40, 60) HUD geri düğmesinin üstüne denk gelir: gizli mola dokunuşu YUTMAZSA HUD alır (Main bitmiş
	# board'da molayı açmayı reddeder).
	await _finger_tap(_pause_point("karartma"))
	await _finger_tap(_pause_point("yeniden başlat"))
	await _finger_tap(_pause_point("ana menüye dön"))
	await _finger_tap(_pause_point("devam et"))
	await _physics(3)
	_c("gecikmede eski mola noktalarına gerçek dokunuş: mola eylemi 0, bırakış 0, board aynı; köşe dokunuşu HUD geri düğmesine ULAŞTI (%d) ve reddedildi"
		% hud_back[0], _actions_in(_actions, PAUSE_KEYS) == 0 and _drops == 0 and _main._board == board
		and not _main.is_pause_open() and hud_back[0] >= 1)
	await _back()
	_c("  … gecikmede Android geri: mola yeniden AÇILMAZ (bitişten sonra mola kilidi aynen), sonuç henüz yok",
		not _main.is_pause_open() and _main._board == board and not _main._result.visible)
	var before: Dictionary = SaveManager.data.duplicate(true)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)
	await _settle(2)
	_c("  … gecikmede öne dönüş (APPLICATION_RESUMED): mola kapalı, günlük pencere yok, sonuç henüz yok",
		not _main.is_pause_open() and not _main._daily_rewards.visible and not _main._result.visible)
	await _after(timer)
	var dim: Variant = _main._pause.get("_dim")
	_c("sonuç tam bir kez açıldı; gizli katman yok (mola penceresi ve karartması ağaçta görünmez); öne dönüş kayda yazmadı",
		_main._result.visible and _shows == 1 and not _main.is_pause_open() and dim is Control
		and not (dim as Control).is_visible_in_tree() and _diff_keys(before, SaveManager.data).is_empty())
	await _back()
	await _back()
	_c("iki Android geri: ikisi de sonuç ekranının kuralıyla yok sayıldı (mola açılmadı, sonuç açık, eylem yok)",
		_main._result.visible and not _main.is_pause_open() and _no_actions())
	await _wait_settled()
	await _finger_tap(_center(_main._result.primary_button()))
	await _settle(2)
	_c("sonucun ANA SAYFA düğmesi gerçek dokunuşu aldı (sonuç çıkışı 1, mola eylemi 0) → Ana Sayfa",
		_actions["result_exit"] == 1 and _actions_in(_actions, PAUSE_KEYS) == 0 and _main._board == null
		and _main._active_tab == 0)
	_sections_done += 1


# --- T) Ayarlar — kapsam dışı, korunur ---------------------------------------------------------------------

func _settings_terminal() -> void:
	print("-- T: Ayarlar kapsam dışı — meydan okuma bitişi Ayarlar'ı KAPATMAZ (mevcut davranış korunur)")
	# T1 — Ayarlar kritik pencerede GERÇEK HUD dişlisiyle açılır (aynı menü dondurması): aynı karede merge meydan okumayı
	# Ayarlar açıkken bitirir.
	var board: Node2D = await _win_under_pause("gear")
	var ok: bool = board != null
	var timer: SceneTreeTimer = _last_timer
	_c("T1 kurulum (%d deneme): Ayarlar gerçek dişliyle temas raporlanmadan ÖNCE açıldı (board donuk), meydan okuma Ayarlar açıkken kazanıldı"
		% _attempts, ok)
	if ok:
		_c("T1: bitiş anında Ayarlar AÇIK KALDI (temizlik Ayarlar'ı kapatmaz), mola yok, kapanış sinyali yok, +20 yazıldı",
			_af("settings") and not _af("pause") and _actions["settings_closed"] == 0 and _af("dough") == _pre_dough + 20)
		await _after(timer)
		_c("  … gecikmeden sonra sonuç açıldı, Ayarlar hâlâ üstünde (mevcut davranış — kayda geçen açık madde)",
			_main._result.visible and _main._settings.visible and _shows == 1)
		await _back()
		_c("  … Android geri Ayarlar'ı kapattı (kendi kuralı), sonuç açık kaldı", not _main._settings.visible
			and _main._result.visible and _actions["settings_closed"] == 1)
		await _wait_settled()
		await _finger_tap(_center(_main._result.primary_button()))
		await _settle(2)
		_c("  … sonuç düğmesi gerçek dokunuşu aldı (sonuç çıkışı 1) → Ana Sayfa", _actions["result_exit"] == 1
			and _main._board == null and _main._active_tab == 0)
	# T2 — Ayarlar gecikme İÇİNDE (molada biten meydan okumadan sonra) gerçek dişliyle açılır: kapanmaz, sonuç altına açılır.
	board = await _win_under_pause("call")
	timer = _last_timer
	var settled: bool = board != null and not _af("pause")
	if board != null:
		await _finger_tap(_center(board._hud.settings_button))
		await _settle(2)
	_c("T2: molada kazanıldı (bitişte kapandı); gecikme içinde gerçek dişli dokunuşu Ayarlar'ı açtı (mevcut davranış)",
		settled and _main._settings.visible)
	await _after(timer)
	_c("  … sonuç açıldı, Ayarlar kapanmadı (üstünde), mola yok", _main._result.visible and _main._settings.visible
		and not _main.is_pause_open() and _shows == 1)
	var close: Variant = _main._settings.frame().get_meta(&"close_button")
	await _wait_settled()
	if close is Control:
		await _finger_tap(_center(close as Control))
	await _settle(2)
	_c("  … Ayarlar'ın X'i gerçek dokunuşla kapattı, sonuç açık", not _main._settings.visible and _main._result.visible)
	_sections_done += 1


# --- S) Kaynak sözleşmesi -----------------------------------------------------------------------------------

func _source_contract() -> void:
	print("-- S: kaynak sözleşmesi")
	var code: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/main.gd"))
	var board_src: String = FileAccess.get_file_as_string("res://scripts/game/game_board.gd")
	var board_code: String = _strip_comments(board_src)
	var pause_code: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/pause_menu.gd"))
	var dc_code: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/game/daily_challenge.gd"))
	var constants: Dictionary = _main_script.get_script_constant_map()
	var handler: String = _function(code, "func _on_challenge_round_finished(")
	var guard: int = handler.find("_round_finalized = true")
	var reward: int = handler.find("SaveManager.complete_daily_challenge(")
	var call_at: int = handler.find("%s()" % CLEANUP)
	var waited: int = handler.find("await get_tree().create_timer(RESULT_DELAY).timeout")
	_c("meydan okuma bitişi: paylaşılan temizlik kesinleştirme korumasından SONRA, ödül / tamamlanma işleminden SONRA, gecikmeden ÖNCE ve tek kez",
		guard >= 0 and reward > guard and call_at > reward and waited > call_at and handler.count(CLEANUP) == 1)
	_c("  … çağrı işleyici düzeyinde (koşulsuz — `if won:` içinde DEĞİL)", handler.contains("\n\t%s()\n" % CLEANUP))
	var normal: String = _function(code, "func _on_round_finished(")
	var normal_call: int = normal.find("%s()" % CLEANUP)
	var written: int = maxi(normal.find("SaveManager.record_round_finished("), normal.find("progress[\"missions\"] = missions"))
	_c("normal bitiş aynen (TASK/049): temizlik ilerleme yazıldıktan SONRA, gecikmeden ÖNCE, tek kez", written >= 0
		and normal_call > written and normal.find("await get_tree().create_timer(RESULT_DELAY).timeout") > normal_call
		and normal.count("%s()" % CLEANUP) == 1)
	var call_sites: int = code.count(CLEANUP) - code.count("func %s(" % CLEANUP)
	_c("temizliğe yalnız iki round bitiş işleyicisi başvurur (normal + meydan okuma; her biçim — call / call_deferred / ad), başka yer yok (%d)"
		% call_sites, call_sites == 2 and normal.count(CLEANUP) == 1 and handler.count(CLEANUP) == 1)
	var helper: String = _function(code, "func %s(" % CLEANUP)
	var body: Array[String] = []
	for raw in helper.split("\n").slice(1):
		var text: String = raw.strip_edges()
		if text != "":
			body.append(text)
	_c("paylaşılan temizlik gövdesi TAM iki korumalı satır (başka hiçbir şey yok): %s" % str(body), _same(body, [
		"if _pause != null and _pause.visible:", "_pause.close_menu()", "if _refill != null and _refill.visible:",
		"_refill.hide_refill()"]))
	var forbidden: Array[String] = ["_settings", "close_settings", "_daily_rewards", "_chest_info", "_missions",
		"_challenge_sheet", "_age_panel", "resume_game(", "_on_pause_restart(", "abandon_run(", "_start_level(",
		"start_daily_challenge(", "_retry_daily_challenge(", "_leave_daily_challenge(", "_clear_board(", "_finish_refill(",
		"_on_refill_closed(", "grant_", "save_game", "SaveManager", "_cancel_rewarded_request(", "_clear_refill_request(",
		"_show_tab(", "_result.", "emit(", "DailyChallenge", "DailyRewards", "_ads.", "_round_", "_deferred_round_change",
		"_board", "_set_ad_surface(", "settle_touch_input(", "_revive", "decline_revive(", "set_menu_paused(", "_refresh_",
		"current_day", "observe_day", "_resolve_daily_login(", "_check_daily_reward("]
	var leaks: Array[String] = []
	for token in forbidden:
		if helper.contains(token):
			leaks.append(token)
	_c("paylaşılan temizlik aynen: yalnız molayı (close_menu) ve refill'i (hide_refill) kapatır; Ayarlar / gezinme / round / kayıt / gün / reklam yok%s"
		% ("" if leaks.is_empty() else " (sızan: %s)" % ", ".join(leaks)), helper != ""
		and helper.contains("_pause.close_menu()") and helper.contains("_refill.hide_refill()") and leaks.is_empty())
	var hits: Array[String] = []
	for token in ["_on_round_finished", "try_show_interstitial", "_round_break_generation", "record_round_finished",
			"add_merges", "record_mission_round", "PlayerProgression", "_collect_rewards", "show_rewarded", "_settings",
			"close_settings", "_close_secondary_windows", "_refresh_", "observe_day", "_resolve_daily_login(",
			"_check_daily_reward(", "_start_level(", "_on_pause_restart(", "abandon_run("]:
		if handler.contains(token):
			hits.append(token)
	_c("meydan okuma işleyicisi normal yola / reklama / ilerlemeye girmez (bulunan: %s)" % str(hits), handler != ""
		and hits.is_empty())
	var token_fn: String = _function(code, "func _challenge_result_current(")
	_c("deneme kimliği aynen: gecikmeden sonra _challenge_result_current(attempt, board) — deneme + tür + aynı board",
		handler.contains("if not _challenge_result_current(attempt, board):") and handler.find("_challenge_result_current(")
		> waited and token_fn.contains("attempt != _challenge_attempt") and token_fn.contains("_round_kind != RoundKind.DAILY_CHALLENGE")
		and token_fn.contains("return _board == board"))
	_c("RESULT_DELAY 0,8 sn, TOUCH_SETTLE_MSEC 300, TASK/046.2 iptal koruması aynen",
		is_equal_approx(float(constants["RESULT_DELAY"]), 0.8) and int(constants["TOUCH_SETTLE_MSEC"]) == 300
		and board_src.contains("\telif not touch.canceled:"))
	var gate: String = _function(pause_code, "func _emit_if_open(")
	var direct: int = pause_code.count("resume_pressed.emit()") + pause_code.count("restart_pressed.emit()") \
		+ pause_code.count("exit_pressed.emit()")
	_c("PauseMenu kapısı aynen (TASK/049): üç düğme + X + karartma tek görünürlük kapısından (önce koşul), doğrudan yayım yok",
		gate.contains("if visible:") and gate.contains("action.emit()") and gate.find("if visible:") < gate.find("action.emit()")
		and pause_code.count("_emit_if_open.bind(") == 5 and direct == 0
		and pause_code.contains("UiKit.attach_dim_close(_dim, _emit_if_open.bind(resume_pressed))"))
	_c("GameBoard aynen: _finish menü dondurmasını bırakır (TASK/049); güç / refill kapısı meydan okumada kapalı",
		_function(board_code, "func _finish(").contains("_is_menu_paused = false")
		and _function(board_code, "func _on_power_pressed(").contains("if not _powers_enabled:")
		and _function(board_code, "func _on_power_refill_requested(").contains("if not _powers_enabled:")
		and _function(board_code, "func setup_challenge(").contains("_powers_enabled = false"))
	_c("TASK/047 kilitleri aynen: haftalık presetler, torba [1,1,1,2,2,2,3,3,3], ödül 20, kayıt bloğu sürüm 1, yükseklik 400",
		JSON.stringify(_norm(DailyChallenge.PRESETS)) == JSON.stringify(_norm(PRESETS))
		and _same(DailyChallenge.BAG_TEMPLATE, [1, 1, 1, 2, 2, 2, 3, 3, 3]) and DailyChallenge.REWARD_DOUGH == 20
		and DailyChallenge.VERSION == 1 and is_equal_approx(DailyChallenge.PLAYABLE_HEIGHT, 400.0)
		and _same(DailyChallenge.default_block().keys(), ["version", "completed_day_key"]))
	_c("pinlenmiş dizi 2026-10-01 aynen (1,3,1,1,3,2,2,3,2 | 1,3,3,1,2,1,2,3,2); global seed() / randomize() yok",
		_same(DailyChallenge.sequence(THU, 18), GOLDEN) and not dc_code.contains("seed(")
		and not dc_code.contains("randomize("))
	_c("ödül işlemi aynen: tamamlanma günü + 20 Hamur tek save_game'de", _function(
		_strip_comments(FileAccess.get_file_as_string("res://scripts/autoload/save_manager.gd")),
		"func complete_daily_challenge(").count("save_game()") == 1)
	_sections_done += 1


# --- Yardımcılar ------------------------------------------------------------------------------------------

func _fixture(extra: Dictionary = {}) -> Dictionary:
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 2},
		"endless_high_score": 640, "dough": 335, "total_merges": 40, "merges_since_bonus_chest": 10,
		"unlocked_skins": ["common_01", "rare_02"], "profile_showcase": ["rare_02"],
		"powerups": {"bomb": 2, "upgrade": 9, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
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


## Temiz kayıt + Main. `with_ads`: sahte reklam arka ucu (rıza + init + ödüllü hazır) ve normal geçiş reklamı hazır +
## uygun (aktif süre eşiği dolmuş).
func _fresh(with_ads: bool = false, extra: Dictionary = {}) -> void:
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
	# TASK/052: zorunlu geçiş reklamının iki kapısı (AdPolicy) — reklam gerçekten UYGUN + hazırken meydan okuma denemez.
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
	_last_timer = null
	_reset_actions()
	_reset_marks()
	_main._result.visibility_changed.connect(func() -> void:
		if _main != null and is_instance_valid(_main) and _main._result.visible:
			_shows += 1
			_result_msec = Time.get_ticks_msec())
	_main._pause.resume_pressed.connect(func() -> void: _actions["resume"] += 1)
	_main._pause.restart_pressed.connect(func() -> void: _actions["restart"] += 1)
	_main._pause.exit_pressed.connect(func() -> void: _actions["exit"] += 1)
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


## Gerçek meydan okuma başlatma (Main'in BAŞLA / TEKRAR / mola Yeniden Başlat ortak girişi) + 300 ms geçiş yatışması.
func _start_challenge() -> Node2D:
	var started: bool = _main.start_daily_challenge()
	await _settle(3)
	var board: Node2D = _main._board if started else null
	_track(board)
	await _wait_settled()
	return board


## Normal round başlatma (Main'in Harita / sonuç / mola yolunun ortak girişi).
func _start_normal(number: int) -> Node2D:
	_main._start_level(_level(number))
	await _settle(3)
	var board: Node2D = _main._board
	_track(board)
	await _wait_settled()
	return board


## Isınma: mola üretim işleyicileriyle bir kez açılıp kapanır (oyuncu daha önce mola vermiş gibi; pencere düzeni hazır).
func _warm_pause(_board: Node2D) -> void:
	_main.open_pause_menu()
	await _settle(2)
	_main.resume_game()
	await _settle(2)
	_reset_actions()


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
		"attempt", "dough", "frozen":
			return -999 if key != "frozen" else 999
		"completed", "last_seen":
			return "?"
		"actions":
			var spoiled: Dictionary = {}
			for name in ACTION_KEYS:
				spoiled[name] = 999
			return spoiled
	return true


## Kabul edilen bitişin eşzamanlı sonucu: Main'in round_finished işleyicisi ilk `await`'e kadar çalıştı.
func _snapshot(board: Node2D) -> Dictionary:
	var frozen: int = 0
	for piece in board.live_dumplings():
		if piece is Dumpling and (piece as Dumpling).is_simulation_frozen():
			frozen += 1
	return {"pause": _main.is_pause_open(), "settings": _main._settings.visible,
		"menu_paused": bool(board.get("_is_menu_paused")), "board_paused": board._is_paused(), "frozen": frozen,
		"result": _main._result.visible, "board": _main._board == board, "attempt": int(_main.get("_challenge_attempt")),
		"actions": _actions.duplicate(), "dough": SaveManager.dough(),
		"completed": SaveManager.daily_challenge_completed_day(), "last_seen": SaveManager.daily_last_seen_day_key()}


## Bu bitişin gecikmesi doldu (Main'in gecikmeli kodu bu karede çalıştı) + birkaç kare.
func _after(timer: SceneTreeTimer, frames: int = 3) -> void:
	if timer != null and timer.time_left > 0.0:
		await timer.timeout
	await _settle(frames)


## Gecikmeden `seconds` kalana kadar bekle (gecikme SÜRERKEN denetim için).
func _until_left(timer: SceneTreeTimer, seconds: float) -> void:
	while timer != null and timer.time_left > seconds:
		await get_tree().process_frame


## Molada kazanılan meydan okuma (gerçek aynı kare penceresi): temiz kayıtla en fazla 3 deneme — motor bir kareye iki
## fizik adımı sığdırırsa temas mola açılmadan raporlanabilir; o deneme sayılmaz (meydan okuma molasız kazanılmış olur),
## kayıt baştan kurulur. Başlangıç durumu `_pre_save` / `_pre_dough` / `_pre_shows` / `_pre_ready`'de. Dönüş: board
## (kurulum doğruysa) ya da null.
func _win_under_pause(opener: String, hold: String = "", unhandled: bool = false, with_ads: bool = false) -> Node2D:
	_attempts = 0
	while _attempts < 3:
		_attempts += 1
		await _fresh(with_ads)
		_pre_save = SaveManager.data.duplicate(true)
		_pre_dough = SaveManager.dough()
		_pre_shows = 0
		_pre_ready = false
		if with_ads:
			var fake: FakeAdBackend = _main._ads._backend
			_pre_shows = fake.interstitial_shows.size()
			_pre_ready = _main._ads.interstitial_eligible() and _main._ads.is_interstitial_ready()
		AdEvents.clear_recent()
		var board: Node2D = await _start_challenge()
		if board == null:
			return null
		await _warm_pause(board)
		if await _critical_pause(board, opener, hold, unhandled):
			return board
		if hold == "board" and is_instance_valid(board):
			await _finger(_board_point(board, -90.0), false)
		elif hold != "" and _main != null and is_instance_valid(_main):
			await _finger(_pause_point(hold), false)
	return null


## GERÇEK aynı kare penceresi: iki (hedef − 1) parça bir fizik karesinin İÇİNDE yan yana 2 px üst üste tabanda doğar —
## o karenin adımı teması kaydeder. Aynı karenin boşta evresinde (temas henüz raporlanmadı) mola `opener` yoluyla
## açılır: "hud" = HUD geri düğmesine gerçek dokunuş, "back" = Android geri (Main'in GO_BACK yönlendirmesi), "call" =
## mola işleyicisi (`open_pause_menu`, ikisinin vardığı yer). `hold`: mola açılır açılmaz o noktaya (düğme / karartma)
## parmak basılır ve BASILI kalır; `unhandled`: ardından işlenmemiş bir olay. Sonraki karede temas donmuş parçalara
## raporlanır → gerçek merge → bitiş. Dönüş: kurulum doğru mu (çift mola açılırken birleşmemişti, mola bitişten ÖNCE
## açıktı, round bitti). Bitişin eşzamanlı sonucu `_at_finish`'te.
func _critical_pause(board: Node2D, opener: String, hold: String = "", unhandled: bool = false) -> bool:
	if board == null or not is_instance_valid(board):
		return false
	var tier: int = board.level.target_tier - 1
	var r: float = TierConfig.radius(tier)
	var y: float = _floor_y(board) - r - 1.0
	var cx: float = board._center_x()
	if opener == "back":
		while Time.get_ticks_msec() - int(_main.get("_last_back_msec")) < BACK_GAP_MSEC \
				or Time.get_ticks_msec() - _last_back_msec < BACK_GAP_MSEC:
			await get_tree().process_frame
	_reset_marks()
	await get_tree().physics_frame
	var a: Dumpling = board._spawn_dumpling(tier, Vector2(cx - r + 1.0, y))
	var b: Dumpling = board._spawn_dumpling(tier, Vector2(cx + r - 1.0, y))
	await get_tree().process_frame
	var untouched: bool = is_instance_valid(a) and is_instance_valid(b) and not a.is_merging and not b.is_merging \
		and not board.is_finished()
	if hold == "board":
		# Tahtada basılı parmak (bırakış henüz yok) — mola ondan SONRA açılır.
		_press_now(_board_point(board, -90.0), true)
	match opener:
		"hud":
			_tap_now(_center(board._hud.back_button))
		"gear":
			_tap_now(_center(board._hud.settings_button))
		"back":
			_last_back_msec = Time.get_ticks_msec()
			get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
		_:
			_main.open_pause_menu()
	_pause_msec = Time.get_ticks_msec()
	var window_open: bool = _main._settings.visible if opener == "gear" else _main.is_pause_open()
	var paused_first: bool = window_open and bool(board.get("_is_menu_paused")) and not board.is_finished()
	if hold != "" and hold != "board" and paused_first:
		_press_now(_pause_point(hold), true)
		if unhandled:
			_unhandled_key_now()
			paused_first = paused_first and not get_viewport().is_input_handled()
	await _until_finished(board)
	return untouched and paused_first and is_instance_valid(board) and board.is_finished() and not _at_finish.is_empty()


## Mola AÇIKKEN normal round kazanması (TASK/049 üretim yolu): Büyütücü dönüşümü başlar, anticipation içinde mola açılır.
func _finish_with_upgrade_pause(board: Node2D) -> bool:
	if board == null:
		return false
	var tier: int = board.level.target_tier - 1
	var r: float = TierConfig.radius(tier)
	var piece: Dumpling = board._spawn_dumpling(tier, Vector2(board._center_x() + 60.0, _floor_y(board) - r - 1.0))
	await _physics(8)
	_reset_marks()
	board._power_bar.power_pressed.emit(int(PowerUp.Type.UPGRADE))
	await _settle(1)
	var at: Vector2 = _win(board, piece.global_position)
	await _finger(at, true)
	await _finger(at, false)
	_main.open_pause_menu()
	_pause_msec = Time.get_ticks_msec()
	var paused_first: bool = _main.is_pause_open() and not board.is_finished() and is_instance_valid(piece) \
		and piece.is_merging and bool(board.get("_is_menu_paused"))
	await _until_finished(board)
	return paused_first and is_instance_valid(board) and board.is_finished() and not _at_finish.is_empty()


## Gerçek merge ile hedef (molasız): sağ kenarda tabandaki (hedef − 1) tier parçasının üstüne aynısı düşer.
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


## Kaba tier 8'ler (level modunda birleşmez) çakışmayan ızgarada: 400'lük oyun alanı kesin taşar.
func _pile_kings(board: Node2D) -> void:
	_reset_marks()
	var left: float = board._left_x()
	var width: float = board.level.container_width
	for row in 3:
		for column in 2:
			board._spawn_dumpling(8, Vector2(left + width * (0.25 if column == 0 else 0.75),
				_floor_y(board) - 101.0 - 205.0 * float(row)))
	await _physics(4)


## Üretim bırakışı (bekleme süresi sıfırlanır — hızlandırma).
func _quick_drop(board: Node2D, i: int) -> void:
	board._drop_cooldown = 0.0
	board._set_aim(board._left_x() + 40.0 + float((i * 131) % int(board.level.container_width - 80.0)))
	board._drop()
	await _physics(4)


## Round bitene kadar (kare + duvar saati sınırı).
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
func _drop_ok(board: Node2D) -> bool:
	var before: int = _drops
	await _finger_tap(_board_point(board, -90.0))
	await _physics(3)
	return _drops == before + 1


func _gen() -> int:
	var value: Variant = _main.get("_round_generation")
	return int(value) if value != null else -1


func _interstitial_events() -> int:
	var n: int = 0
	for name: StringName in [&"interstitial_eligible", &"interstitial_showed", &"interstitial_impression",
			&"interstitial_dismissed", &"interstitial_show_failed", &"interstitial_skipped_not_ready"]:
		n += AdEvents.count(name)
	return n


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
		"x":
			return _center((_main._pause.get("_frame") as Control).get_meta(&"close_button") as Control)
	return _screen(Vector2(40.0, 60.0))


func _diff_keys(a: Dictionary, b: Dictionary) -> Array[String]:
	var keys: Dictionary = {}
	for key: String in a:
		keys[key] = true
	for key: String in b:
		keys[key] = true
	var out: Array[String] = []
	for key: String in keys:
		if JSON.stringify(_norm(a.get(key))) != JSON.stringify(_norm(b.get(key))):
			out.append(key)
	out.sort()
	return out


## Diskteki kayıt bellektekiyle aynı mı (JSON sayı normalizasyonuyla).
func _disk_equals_memory() -> bool:
	if not FileAccess.file_exists(PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed is Dictionary and JSON.stringify(_norm(parsed)) == JSON.stringify(_norm(SaveManager.data))


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


## Kare beklemeden basış (+ bırakış): kritik pencere tek bir boşta evresidir.
func _press_now(pos: Vector2, pressed: bool) -> void:
	Input.parse_input_event(_touch_event(pos, pressed, 0))
	Input.flush_buffered_events()


func _tap_now(pos: Vector2) -> void:
	_press_now(pos, true)
	_press_now(pos, false)


## Hiçbir şeyin işlemediği bir girdi olayı (eşlenmemiş tuş, basış + bırakış), kare beklemeden: ardından Viewport'un
## "işlendi" bayrağı kapalı kalır — gerçek cihazda ör. GERİ tuşunun KeyEvent'i ya da başka bir girdi aygıtı.
func _unhandled_key_now() -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_F13
		key.physical_keycode = KEY_F13
		key.pressed = pressed
		Input.parse_input_event(key)
		Input.flush_buffered_events()


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
	return int((_result_const("Mode") as Dictionary)[name])


func _result_const(name: String) -> Variant:
	var script: GDScript = load("res://scripts/ui/round_result.gd")
	return script.get_script_constant_map()[name]


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
