extends Node
## Geçiş (interstitial) reklamı deterministik testi (M8.9-02) — İNTERNET,
## CİHAZ, EKLENTİ YOK. `FakeAdBackend` SDK'yı taklit eder; yöneticinin aktif
## süre saati (900 sn), dışlanan anlar, doğal mola politikası (yalnız round
## bitişi → sonuçtan önce), tam ekran bekleme (60 sn), ödüllü ↔ geçiş
## dışlaması, yükleme/gösterim hataları, çift/geç callback'ler ve Main
## entegrasyonu (gerçek board: sonuç tam bir kez, kayıp yok, çift yok).
##
## KAYIT DOSYASINA YAZAR (round bitişi). Test başında yedekler, sonunda
## byte-identical geri koyar ve bunu kontrol eder.
##
## Kullanım:
##   godot --headless --audio-driver Dummy --path . res://tools/interstitial_test.tscn

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const LEVEL_10: String = "res://resources/levels/level_10.tres"

var _fails: int = 0
var _checks: int = 0
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _saved: Dictionary = {}
var _events: Array[Dictionary] = []
var _main_script: GDScript = load("res://scripts/main.gd")


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	await get_tree().process_frame
	_saved = SaveManager.data.duplicate(true)
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.data["onboarding_completed"] = true
	DailyRewards.auto_popup_enabled = false
	MonetizationManager.time_scale = 0.01
	AdEvents.subscribe(_on_event)

	await _test_preload_and_clock()
	await _test_natural_break()
	await _test_failures_and_races()
	await _test_main_integration()

	AdEvents.unsubscribe(_on_event)
	DailyRewards.auto_popup_enabled = true
	MonetizationManager.time_scale = 1.0
	SaveManager.data = _saved
	_restore_save_file()
	var restored: bool = not _had_save or FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == _save_bytes
	_c("kayıt dosyası test sonunda byte-identical geri kondu", restored)
	print("=== SONUC: %d/%d kontrol, %d kaldi ===" % [_checks - _fails, _checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _on_event(_name: StringName, event: Dictionary) -> void:
	_events.append(event)


func _events_named(name: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in _events:
		if e["name"] == name:
			out.append(e)
	return out


func _settle(frames: int = 2) -> void:
	for i in maxi(frames, 1):
		await get_tree().process_frame


func _wait(seconds_scaled: float) -> void:
	await get_tree().create_timer(seconds_scaled * MonetizationManager.time_scale + 0.05).timeout
	await _settle(2)


## Rıza yok -> izin -> SDK hazır; saat testten sürülür (process kapalı).
func _boot(fake: FakeAdBackend) -> MonetizationManager:
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	var m: MonetizationManager = MonetizationManager.create(fake, AdConfig.test_defaults())
	add_child(m)
	m.set_process(false)
	fake.complete_consent_update(true)
	fake.complete_init()
	return m


func _free(m: MonetizationManager) -> void:
	if m != null and is_instance_valid(m):
		m.queue_free()
	await _settle(2)


class _Counter:
	var calls: int = 0
	func hit() -> void:
		calls += 1


# --- Önyükleme + aktif süre saati --------------------------------------------------------

func _test_preload_and_clock() -> void:
	print("-- önyükleme, aktif süre saati, dışlanan anlar")
	_events.clear()
	var fake := FakeAdBackend.new()
	var m: MonetizationManager = _boot(fake)
	_c("SDK hazır -> tek geçiş reklamı önyüklemesi (rewarded ile birlikte)", fake.interstitial_loads == 1
		and m.interstitial_state() == MonetizationManager.InterstitialState.LOADING and fake.rewarded_loads == 1)
	var i1: String = fake.complete_interstitial_load(true)
	_c("yüklendi -> READY, olay interstitial_loaded", m.interstitial_state() == MonetizationManager.InterstitialState.READY
		and m.is_interstitial_ready() and m.interstitial_ready_id() == i1 and _events_named(&"interstitial_loaded").size() == 1)
	_c("yapılandırma: interstitial test kimliği (…/1033173712)", AdConfig.TEST_INTERSTITIAL_ID.ends_with("/1033173712")
		and AdConfig.load_project().interstitial_id == AdConfig.TEST_INTERSTITIAL_ID)
	_c("sabitler: 900 sn aralık, 60 sn tam ekran bekleme", MonetizationManager.INTERSTITIAL_INTERVAL_SEC == 900.0
		and MonetizationManager.FULLSCREEN_AD_COOLDOWN_SEC == 60.0)
	m._tick_active(899.0)
	_c("899 sn -> uygun DEĞİL", not m.interstitial_eligible() and is_equal_approx(m.active_elapsed_sec(), 899.0)
		and _events_named(&"interstitial_eligible").is_empty())
	m._tick_active(1.0)
	_c("900 sn -> uygun, olay interstitial_eligible (active_elapsed_sec), gösterim YOK", m.interstitial_eligible()
		and _events_named(&"interstitial_eligible").size() == 1 and fake.interstitial_shows.is_empty()
		and _events_named(&"interstitial_eligible")[0]["active_elapsed_sec"] >= 900.0)
	await _free(m)

	# Dışlanan anlar.
	fake = FakeAdBackend.new()
	m = _boot(fake)
	fake.complete_interstitial_load(true)
	m.notification(NOTIFICATION_APPLICATION_PAUSED)
	m._tick_active(500.0)
	_c("arka planda süre SAYILMAZ", m.active_elapsed_sec() == 0.0)
	m.notification(NOTIFICATION_APPLICATION_RESUMED)
	m._tick_active(100.0)
	_c("öne dönünce sayılır", is_equal_approx(m.active_elapsed_sec(), 100.0))
	var r1: String = fake.complete_rewarded_load(true)
	var stub := Node.new()
	add_child(stub)
	m.show_rewarded_revive(stub)
	m._tick_active(300.0)
	_c("ödüllü reklam gösterilirken süre SAYILMAZ", is_equal_approx(m.active_elapsed_sec(), 100.0)
		and m.rewarded_state() == MonetizationManager.RewardedState.SHOWING)
	fake.emit_rewarded_showed(r1)
	fake.emit_rewarded_earned(r1)
	m._tick_active(300.0)
	_c("ödül kazanıldı ama reklam hâlâ üstte: yine sayılmaz", is_equal_approx(m.active_elapsed_sec(), 100.0))
	fake.emit_rewarded_dismissed(r1)
	_c("ödüllü kapanış -> 60 sn tam ekran beklemesi başladı", is_equal_approx(m.fullscreen_cooldown_sec(), 60.0))
	m._tick_active(50.0)
	_c("bekleme aktif süreyle azalır (10 kaldı), saat 150", is_equal_approx(m.fullscreen_cooldown_sec(), 10.0)
		and is_equal_approx(m.active_elapsed_sec(), 150.0))
	await _free(m)
	stub.queue_free()

	# UMP formu kaplarken ve rıza yokken.
	fake = FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.REQUIRED
	fake.form_available = true
	m = MonetizationManager.create(fake, AdConfig.test_defaults())
	add_child(m)
	m.set_process(false)
	fake.complete_consent_update(true)
	fake.complete_form_load(true)
	m._tick_active(400.0)
	_c("rıza formu kaplarken süre SAYILMAZ, geçiş reklamı yüklenmez", m.active_elapsed_sec() == 0.0
		and fake.interstitial_loads == 0 and m.consent_form_covering())
	fake.dismiss_form(AdBackend.ConsentStatus.OBTAINED)
	fake.complete_init()
	m._tick_active(400.0)
	_c("form kapanıp SDK hazır olunca sayılır ve yüklenir", is_equal_approx(m.active_elapsed_sec(), 400.0)
		and fake.interstitial_loads == 1)
	m.set_onboarding_completed(false)
	m._tick_active(400.0)
	_c("onboarding false -> sayılmaz", is_equal_approx(m.active_elapsed_sec(), 400.0))
	m.set_onboarding_completed(true)
	m._tick_active(600.0)
	_c("onboarding true -> sayılır, 1000 >= 900 uygun", m.interstitial_eligible())
	await _free(m)


# --- Doğal mola ------------------------------------------------------------------------------

func _test_natural_break() -> void:
	print("-- doğal mola: yalnız try_show_interstitial, hazır değilse sonuç hemen, saat yalnız gösterimde sıfırlanır")
	_events.clear()
	var fake := FakeAdBackend.new()
	var m: MonetizationManager = _boot(fake)
	var i1: String = fake.complete_interstitial_load(true)
	var counter := _Counter.new()
	_c("uygun değilken doğal mola: gösterim YOK, false, olay skipped reason not_eligible",
		not m.try_show_interstitial("round_finish", counter.hit) and fake.interstitial_shows.is_empty()
		and _events_named(&"interstitial_skipped_not_ready")[-1]["reason"] == "not_eligible" and counter.calls == 0)
	m._tick_active(900.0)
	_c("900 sn aktif oyun ortasında: KENDİLİĞİNDEN GÖSTERMEZ (yalnız molada)", m.interstitial_eligible()
		and fake.interstitial_shows.is_empty())
	var shown: bool = m.try_show_interstitial("round_finish", counter.hit)
	_c("uygun + READY -> gösterim gönderildi (true), SHOWING, callback henüz yok", shown
		and fake.interstitial_shows == [i1] and m.interstitial_state() == MonetizationManager.InterstitialState.SHOWING
		and counter.calls == 0 and m.break_pending())
	_c("gösterim sürerken ödüllü hazır DEĞİL (tek tam ekran)", not m.is_rewarded_ready()
		and m.rewarded_note() == MonetizationManager.NOTE_SHOWING)
	m._tick_active(30.0)
	_c("gösterim sürerken saat sayılmaz, henüz sıfırlanmadı", is_equal_approx(m.active_elapsed_sec(), 900.0))
	fake.emit_interstitial_showed(i1)
	_c("SDK 'gösterildi' -> saat 0, uygunluk düştü, olay showed (natural_break=round_finish)",
		m.active_elapsed_sec() == 0.0 and not m.interstitial_eligible()
		and _events_named(&"interstitial_showed")[-1]["natural_break"] == "round_finish"
		and m.interstitial_shows() == 1)
	fake.emit_interstitial_impression(i1)
	fake.emit_interstitial_dismissed(i1)
	await _settle(1)
	_c("kapanış -> callback TAM BİR KEZ, bekleme 60, sonraki reklam yükleniyor, olaylar impression+dismissed",
		counter.calls == 1 and is_equal_approx(m.fullscreen_cooldown_sec(), 60.0) and fake.interstitial_loads == 2
		and _events_named(&"interstitial_impression").size() == 1 and _events_named(&"interstitial_dismissed").size() == 1
		and not m.break_pending())
	fake.emit_interstitial_dismissed(i1)
	fake.emit_interstitial_showed(i1)
	_c("çift/geç kapanış + gösterildi callback'leri zararsız (callback 1, saat 0)", counter.calls == 1
		and m.active_elapsed_sec() == 0.0 and _events_named(&"interstitial_dismissed")[-1].get("stale", false) == true)
	# Bekleme: uygun olsa da gösterim yok.
	m._tick_active(900.0)
	_c("bekleme bitti (900 > 60) ve yeniden uygun", m.interstitial_eligible() and m.fullscreen_cooldown_sec() == 0.0)
	# Hazır değil (yükleme sürüyor): sonuç hemen, uygunluk kalır.
	var counter2 := _Counter.new()
	_c("READY değil (yükleme sürüyor) -> false, reason not_ready, uygunluk KALIR, callback yok",
		not m.try_show_interstitial("round_finish", counter2.hit) and m.interstitial_eligible()
		and _events_named(&"interstitial_skipped_not_ready")[-1]["reason"] == "not_ready" and counter2.calls == 0)
	var i2: String = fake.complete_interstitial_load(true)
	_c("sonraki molada hazır -> gösterilir", m.try_show_interstitial("round_finish", counter2.hit)
		and fake.interstitial_shows == [i1, i2])
	fake.emit_interstitial_showed(i2)
	fake.emit_interstitial_dismissed(i2)
	_c("ikinci döngü: callback 1, saat 0", counter2.calls == 1 and m.active_elapsed_sec() == 0.0)
	await _free(m)


# --- Hatalar ve yarışlar -----------------------------------------------------------------------

func _test_failures_and_races() -> void:
	print("-- yükleme/gösterim hataları, onay zaman aşımı, bekleme, dışlama, süresi dolma")
	_events.clear()
	# Yükleme hatası + sınırlı geri çekilme.
	var fake := FakeAdBackend.new()
	var m: MonetizationManager = _boot(fake)
	fake.complete_interstitial_load(false)
	_c("no-fill -> FAILED, deneme 1, planlı yeniden deneme, olay load_failed", m.interstitial_state() == MonetizationManager.InterstitialState.FAILED
		and m.interstitial_attempts() == 1 and m.has_pending_interstitial_retry() and _events_named(&"interstitial_load_failed").size() == 1)
	await _wait(MonetizationManager.INTERSTITIAL_RETRY_DELAYS[0])
	_c("geri çekilme sonrası 2. yükleme", fake.interstitial_loads == 2)
	for i in MonetizationManager.INTERSTITIAL_MAX_ATTEMPTS - 1:
		fake.complete_interstitial_load(false)
		if m.has_pending_interstitial_retry():
			await _wait(MonetizationManager.INTERSTITIAL_RETRY_DELAYS[mini(m.interstitial_attempts() - 1, MonetizationManager.INTERSTITIAL_RETRY_DELAYS.size() - 1)])
	_c("deneme sınırı (%d), sonra durur" % MonetizationManager.INTERSTITIAL_MAX_ATTEMPTS, fake.interstitial_loads == MonetizationManager.INTERSTITIAL_MAX_ATTEMPTS
		and not m.has_pending_interstitial_retry())
	var counter := _Counter.new()
	m._tick_active(900.0)
	await _wait(MonetizationManager.ON_DEMAND_MIN_INTERVAL)
	_c("uygun olunca talep üzerine bir deneme daha (döngü sıfır)", fake.interstitial_loads == MonetizationManager.INTERSTITIAL_MAX_ATTEMPTS + 1
		or m.interstitial_state() == MonetizationManager.InterstitialState.LOADING)
	fake.complete_interstitial_load(false)
	_c("FAILED iken mola: false, reason failed, sonuç hemen (callback yok), uygunluk kalır",
		not m.try_show_interstitial("round_finish", counter.hit) and counter.calls == 0 and m.interstitial_eligible()
		and _events_named(&"interstitial_skipped_not_ready")[-1]["reason"] == "failed")
	await _free(m)

	# Gösterim hatası: sonuç sürer, saat sıfırlanmaz.
	fake = FakeAdBackend.new()
	m = _boot(fake)
	var i1: String = fake.complete_interstitial_load(true)
	m._tick_active(900.0)
	counter = _Counter.new()
	m.try_show_interstitial("round_finish", counter.hit)
	fake.emit_interstitial_show_failed(i1)
	await _settle(1)
	_c("gösterim hatası -> callback TAM BİR KEZ, saat 900 (sıfırlanmadı), uygunluk kalır, reklam düştü, yeni yükleme",
		counter.calls == 1 and is_equal_approx(m.active_elapsed_sec(), 900.0) and m.interstitial_eligible()
		and fake.interstitial_removed == [i1] and fake.interstitial_loads == 2 and m.fullscreen_cooldown_sec() == 0.0
		and _events_named(&"interstitial_show_failed").size() == 1)
	fake.emit_interstitial_dismissed(i1)
	_c("hatadan sonra geç kapanış zararsız", counter.calls == 1)
	# Onay zaman aşımı: SDK 'gösterildi' demedi.
	var i2: String = fake.complete_interstitial_load(true)
	counter = _Counter.new()
	m.try_show_interstitial("round_finish", counter.hit)
	await _wait(MonetizationManager.INTERSTITIAL_SHOW_CONFIRM_TIMEOUT)
	_c("onay zaman aşımı -> callback TAM BİR KEZ (sonuç bekletilmez), saat sıfırlanmadı, olay show_failed (confirm timeout)",
		counter.calls == 1 and is_equal_approx(m.active_elapsed_sec(), 900.0)
		and _events_named(&"interstitial_show_failed")[-1]["message"] == "show confirm timeout")
	fake.emit_interstitial_showed(i2)
	fake.emit_interstitial_dismissed(i2)
	await _settle(1)
	_c("geç gösterim + kapanış: callback yine 1 (çift sonuç yok), yalnız bekleme başladı", counter.calls == 1
		and is_equal_approx(m.fullscreen_cooldown_sec(), 60.0))
	await _free(m)

	# Bekleme: ödüllü yeni kapandı -> geçiş reklamı bastırılır.
	fake = FakeAdBackend.new()
	m = _boot(fake)
	fake.complete_interstitial_load(true)
	var r1: String = fake.complete_rewarded_load(true)
	m._tick_active(900.0)
	var stub := Node.new()
	add_child(stub)
	counter = _Counter.new()
	m.show_rewarded_revive(stub)
	_c("ödüllü talep açıkken mola: false, reason rewarded_active", not m.try_show_interstitial("round_finish", counter.hit)
		and _events_named(&"interstitial_skipped_not_ready")[-1]["reason"] == "rewarded_active" and counter.calls == 0)
	fake.emit_rewarded_showed(r1)
	fake.emit_rewarded_dismissed(r1)
	_c("ödüllü kapandı -> bekleme 60: mola ATLANIR (reason cooldown), uygunluk kalır, sonuç hemen",
		not m.try_show_interstitial("round_finish", counter.hit) and m.interstitial_eligible()
		and _events_named(&"interstitial_skipped_not_ready")[-1]["reason"] == "cooldown" and fake.interstitial_shows.is_empty())
	m._tick_active(59.0)
	_c("59 sn sonra hâlâ bekleme", not m.try_show_interstitial("round_finish", counter.hit))
	m._tick_active(1.0)
	_c("60 sn sonra gösterilir", m.try_show_interstitial("round_finish", counter.hit) and fake.interstitial_shows.size() == 1)
	var stub2 := _StubMain.new()
	add_child(stub2)
	var r2: String = fake.complete_rewarded_load(true)
	m.show_rewarded_revive(stub2)
	_c("geçiş reklamı SHOWING iken ödüllü gösterim gönderilmez, Main'e 'gösteriliyor' notu", fake.rewarded_shows == [r1]
		and stub2.unavailable == [MonetizationManager.NOTE_SHOWING] and r2 != "")
	fake.emit_interstitial_showed(m.interstitial_showing_id())
	fake.emit_interstitial_dismissed(m.interstitial_showing_id())
	await _settle(1)
	_c("geçiş kapandı -> ödüllü yeniden hazır", m.is_rewarded_ready())
	await _free(m)
	stub.queue_free()
	stub2.queue_free()

	# Süresi dolma (Google: 1 saat) ve yükleme zaman aşımı.
	fake = FakeAdBackend.new()
	m = _boot(fake)
	var i3: String = fake.complete_interstitial_load(true)
	m._interstitial_loaded_msec = Time.get_ticks_msec() - int(MonetizationManager.INTERSTITIAL_MAX_AGE_SEC * MonetizationManager.time_scale * 1000.0) - 100
	m._tick_active(1.0)
	_c("süresi dolan hazır reklam atılır ve yenisi yüklenir", fake.interstitial_removed == [i3] and fake.interstitial_loads == 2
		and m.interstitial_state() == MonetizationManager.InterstitialState.LOADING)
	await _wait(MonetizationManager.INTERSTITIAL_LOAD_TIMEOUT)
	_c("yükleme zaman aşımı -> FAILED + geri çekilme", m.interstitial_state() == MonetizationManager.InterstitialState.FAILED
		and m.has_pending_interstitial_retry())
	# Öne dönüş payı: SHOWING takılı kalmaz.
	await _wait(MonetizationManager.INTERSTITIAL_RETRY_DELAYS[0])
	var i4: String = fake.complete_interstitial_load(true)
	m._tick_active(900.0)
	counter = _Counter.new()
	m.try_show_interstitial("round_finish", counter.hit)
	fake.emit_interstitial_showed(i4)
	m.notification(NOTIFICATION_APPLICATION_PAUSED)
	m.notification(NOTIFICATION_APPLICATION_RESUMED)
	await _wait(MonetizationManager.SHOW_RESUME_GRACE)
	_c("öne dönüşte kapanış gelmezse pay sonunda kapanmış sayılır: callback 1, SHOWING değil", counter.calls == 1
		and m.interstitial_state() != MonetizationManager.InterstitialState.SHOWING)
	await _free(m)


class _StubMain extends Node:
	var unavailable: Array[String] = []
	func notify_rewarded_unavailable(message: String) -> void:
		unavailable.append(message)
	func grant_revive() -> bool:
		return true


# --- Main entegrasyonu ---------------------------------------------------------------------------

func _test_main_integration() -> void:
	print("-- Main: round bitişi -> geçiş reklamı -> sonuç TAM BİR KEZ (gerçek board)")
	MonetizationManager.time_scale = 0.05
	_events.clear()
	get_window().size = Vector2i(720, 1280)
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	_main_script.ads_backend_override = fake
	var main: Node2D = MAIN_SCENE.instantiate()
	add_child(main)
	await _settle(3)
	_main_script.ads_backend_override = null
	main._daily.visible = false
	var m: MonetizationManager = main._ads
	m.set_process(false)
	fake.complete_consent_update(true)
	fake.complete_init()
	var i1: String = fake.complete_interstitial_load(true)
	fake.complete_rewarded_load(true)
	_c("Main + sahte SDK: geçiş reklamı hazır", m.is_interstitial_ready() and i1 != "")

	# 1) Uygun değil: sonuç hemen.
	main._start_level(load(LEVEL_10))
	await _settle(2)
	var board: Node2D = main._board
	board._dismiss_tutorial()
	board._enter_fail_pending()
	await _settle(2)
	main.decline_revive()
	await get_tree().create_timer(main.RESULT_DELAY + 0.3).timeout
	await _settle(2)
	_c("uygun değilken round bitti -> sonuç HEMEN, gösterim yok, sonuç bir kez", main._result.visible
		and fake.interstitial_shows.is_empty() and m.surface() == MonetizationManager.Surface.RESULT and main._result_seq == 2)
	main._result.hide_result()
	main.abandon_run()
	await _settle(2)

	# 2) Aktif oyun içinde 900 sn: gösterim YOK; round bitince gösterim; kapanınca sonuç bir kez.
	main._start_level(load(LEVEL_10))
	await _settle(2)
	board = main._board
	board._dismiss_tutorial()
	m._tick_active(900.0)
	await _settle(2)
	_c("oyun ortasında 900 sn: uygun ama gösterim YOK, board sürüyor", m.interstitial_eligible()
		and fake.interstitial_shows.is_empty() and not board.is_finished())
	board._enter_fail_pending()
	await _settle(2)
	_c("devam teklifi açık: hâlâ gösterim yok (karar bekleniyor)", main._revive.visible and fake.interstitial_shows.is_empty())
	var seq_before: int = main._result_seq
	main.decline_revive()
	await get_tree().create_timer(main.RESULT_DELAY + 0.05).timeout
	await _settle(1)
	_c("BİTİR -> round kesin bitti -> geçiş reklamı gösteriliyor, sonuç HENÜZ açılmadı", fake.interstitial_shows == [i1]
		and m.interstitial_state() == MonetizationManager.InterstitialState.SHOWING and not main._result.visible)
	fake.emit_interstitial_showed(i1)
	main._last_back_msec = -100000
	main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(1)
	_c("reklam üstteyken geri: mola açılmadı, board silinmedi", not main.is_pause_open() and main._board != null)
	fake.emit_interstitial_dismissed(i1)
	await _settle(2)
	_c("kapanış -> sonuç açıldı (tam bir kez), RESULT yüzeyi, saat 0", main._result.visible
		and main._result_seq == seq_before + 2 and m.surface() == MonetizationManager.Surface.RESULT
		and m.active_elapsed_sec() == 0.0)
	fake.emit_interstitial_dismissed(i1)
	await _settle(1)
	_c("çift kapanış: sonuç ikilenmedi (seq aynı)", main._result_seq == seq_before + 2 and main._result.visible)
	main._result.hide_result()
	main.abandon_run()
	await _settle(2)

	# 3) Ödüllü devam yeni kapandı -> bekleme -> sonraki mola atlanır, sonuç hemen.
	var i2: String = fake.complete_interstitial_load(true)
	m._tick_active(900.0)
	main._start_level(load(LEVEL_10))
	await _settle(2)
	board = main._board
	board._dismiss_tutorial()
	board._enter_fail_pending()
	await _settle(2)
	var offer: CanvasLayer = main._revive
	offer.continue_button().pressed.emit()
	await _settle(1)
	var r: String = m.request_info()["ad_id"]
	fake.emit_rewarded_showed(r)
	fake.emit_rewarded_earned(r)
	fake.emit_rewarded_dismissed(r)
	await _settle(2)
	_c("ödüllü devam alındı (1/2), bekleme 60 başladı", board.revives_used() == 1 and is_equal_approx(m.fullscreen_cooldown_sec(), 60.0))
	board._enter_fail_pending()
	await _settle(2)
	seq_before = main._result_seq
	main.decline_revive()
	await get_tree().create_timer(main.RESULT_DELAY + 0.3).timeout
	await _settle(2)
	_c("ödüllü kapanıştan hemen sonra round bitti -> geçiş reklamı ATLANDI (bekleme), sonuç hemen, uygunluk kalır",
		main._result.visible and fake.interstitial_shows == [i1] and m.interstitial_eligible()
		and main._result_seq == seq_before + 2 and _events_named(&"interstitial_skipped_not_ready")[-1]["reason"] == "cooldown")
	main._result.hide_result()
	main.abandon_run()
	await _settle(2)

	# 4) Gösterim hatası doğal molada: sonuç sürer.
	m._tick_active(60.0)
	main._start_level(load(LEVEL_10))
	await _settle(2)
	board = main._board
	board._dismiss_tutorial()
	board._enter_fail_pending()
	await _settle(2)
	seq_before = main._result_seq
	main.decline_revive()
	await get_tree().create_timer(main.RESULT_DELAY + 0.05).timeout
	await _settle(1)
	_c("bekleme bitti -> gösterim gönderildi", fake.interstitial_shows == [i1, i2] and not main._result.visible)
	fake.emit_interstitial_show_failed(i2)
	await _settle(2)
	_c("gösterim hatası -> sonuç açıldı, saat sıfırlanmadı, uygunluk kalır, deadlock yok", main._result.visible
		and main._result_seq == seq_before + 2 and m.interstitial_eligible() and m.active_elapsed_sec() > 0.0)
	main._result.hide_result()
	main.abandon_run()
	await _settle(2)
	_c("kaynak: geçiş reklamı yalnız Main'in round bitişinde çağrılır (başka yerde try_show yok)",
		FileAccess.get_file_as_string("res://scripts/main.gd").count("_ads.try_show_interstitial(") == 1
		and not FileAccess.get_file_as_string("res://scripts/game/game_board.gd").contains("interstitial"))
	main.queue_free()
	await _settle(2)


func _restore_save_file() -> void:
	if not _had_save:
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()
