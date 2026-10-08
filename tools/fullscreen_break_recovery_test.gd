extends Node
## TASK/052 — Tam ekran reklam molası kurtarması: uygulamanın KENDİ engelleyici durumu (geçiş molası / ödüllü talep)
## SDK'nın kapanış / hata geri çağrısı kaybolsa da sonsuza dek sürmez; yalnız uygulamanın örtülmediğine dair kanıtla,
## jetona bağlı ve TAM BİR KEZ biter. SDK'nın reklamı uygulama tarafından kapatılmaz, ödül uydurulmaz, gösterim
## sayılmaz. Gerçek Main + gerçek board + sahte SDK arka ucu (FakeAdBackend). Headless.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: SaveManager `user://qa_fullscreen_break/` altına yönlendirilir, sonda geri alınır;
## gerçek kayıt ailesi (kanonik + .tmp + .bak) başta / sonda bayt karşılaştırılır.
##
##   godot --headless --audio-driver Dummy --path . res://tools/fullscreen_break_recovery_test.tscn
##
## Düzeltmesiz kodda (1d2fb28) da betik hatası OLMADAN koşar: yeni tanılama API'lerine yalnız `has_method` / `call`
## ile erişilir — eski kod açık [FAIL] kontrolleriyle düşer (TASK/052 temel kanıtı).
##
## Bölümler:
##   A kapanış     normal geçiş reklamı: gösterildi + kapanış → mola tam bir kez, sonuç bir kez, önyükleme, bekleme
##   B hata        gösterim hatası → mola biter, sonuç bir kez, bekleme yok, uygunluk kalır; geç kapanış zararsız
##   C kayıp       C1 "gösterildi" sonrası kapanış / yaşam döngüsü yok → örtülmemiş kira sınırında kurtarma ("kapandı");
##                 C2 SDK hiç cevap vermedi → "gösterilmedi" (bekleme yok, uygunluk kalır); erken bitiş yok
##   D yaşam       D1 PAUSED (reklam üstte) → bitiş yok; RESUMED → pay → kurtarma; D2 tekrarlanan arka plan; D3 RESUMED
##                 kayıp → dışlama sonrası yeni dokunuş (girdi kanıtı) → kurtarma
##   E geç         kurtarmadan sonra geç kapanış / hata / gösterildi: ikinci sonuç / mola / sayım yok; "gösterilmedi"
##                 sonrası GEÇ gerçek gösterim bir kez sayılır, sıklık sayaçları sıfırlanır
##   F yineleme    kapanış+kapanış / hata+kapanış / kapanış+hata → geri çağrı tam bir kez; gösterildi+gösterildi bir sayım
##   G erteleme    TASK/048: mola sürerken ertelenen yeniden başlatma, kurtarmada eski sonucun YERİNE tam bir kez
##   H ödül+kayıp  ödüllü: ödül kazanıldı, kapanış kayıp → ödül tam bir kez (devam + refill), kurtarma talebi kapatır
##   I ödülsüz     ödüllü: ödül yok → kurtarma ödül VERMEZ (devam 0, günlük Hamur 0), not doğru, kota tüketilmez
##   J arka plan   yalnız arka plan (gösterildi öncesi / sonrası, ödüllü) molayı bitirmez
##   K sonraki     kurtarmadan sonra hemen yeni tam ekran yok; önyükleme toparlanır; sonraki uygun mola çalışır
##   L yaş / rıza  yaş bilinmiyor / rıza yok: yükleme / gösterim / kira / round sayımı yok
##   M meydan      meydan okuma bitişi: reklam uygun + hazırken geçiş reklamı denemesi / kira SIFIR, sayaç değişmez
##   N sahiplik    takılı molada GERİ molayı açmaz; kurtarmadan sonra sonuç bir kez, GERİ yok sayılır, sonuç düğmesi
##                 GERÇEK dokunuşla çalışır
##   T jeton       eski kiranın zamanlayıcısı YENİ (örtülü) ödüllü talebi bitiremez
##   O yetim       eklentinin sahipsiz yeniden yükleme hatası (emekli kimlik) süren önyüklemeyi bozmaz
##   U sertleştir. inceleme bulguları: Vulkan'ın odak kaybındaki sahte RESUMED'ı kirayı bırakmaz; ilk karenin dev
##                 delta'sı saate sızmaz; ödüllüde "gösterildi" sonrası süreye bağlı bırakma yok (girdi kanıtı); kazanılmış
##                 ödül "gösterilemedi" sayılmaz; "gösterildi"siz kapanış sayaçları sıfırlar (tek kural); süresi dolan hazır
##                 reklam (ödüllü dahil, duvar saati) atılır; kurtarılan reklam önbellekten düşer; atlanan uygun mola
##                 yüklemeyi tetikler; yinelenen ödüllü hatası eskidir; kayıp RESUMED'ı dokunuş onarır
##   S kaynak      kurtarma yolunda ödül / gösterim çağrısı yok; tek zamanlayıcı; Main tek noktada round bildirir

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_fullscreen_break"
const PATH: String = DIR + "/save.json"
const SCALE: float = 0.05
const SECTIONS: int = 18
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
var _fake: FakeAdBackend
## Sonuç ekranının görünür olduğu geçişler (boot başına sıfırlanır).
var _shows: int = 0
var _drops: int = 0
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
	MonetizationManager.time_scale = SCALE
	get_tree().create_timer(400.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 400 s'de bitmedi — SaveManager geri alındı")
			if _main != null and is_instance_valid(_main):
				_main.free()
			_teardown()
			get_tree().quit(2))
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame
	print("tam ekran kirası: örtülmemiş sınır %.2f sn, öne dönüş payı %.2f sn (ölçek %.2f)" % [_lease_sec(), _grace_sec(),
		SCALE])

	await _normal_close()
	await _show_failure()
	await _missing_close()
	await _background_resume()
	await _late_callbacks()
	await _duplicates()
	await _deferred_restart()
	await _rewarded_reward_then_lost_close()
	await _rewarded_no_reward()
	await _background_only()
	await _next_ad_after_recovery()
	await _age_and_consent()
	await _challenge()
	await _input_result_ownership()
	await _token_ownership()
	await _orphan_reload()
	await _review_hardening()
	_source_contract()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	print("-- kayıt")
	await _teardown_main()
	_teardown()
	_c("SaveManager gerçek yola döndü, test klasörü silindi, saat kancası boş, zaman ölçeği 1",
		SaveManager.save_path == SaveManager.SAVE_PATH and not DirAccess.dir_exists_absolute(DIR)
		and DailyRewards.clock_override == "" and MonetizationManager.time_scale == 1.0)
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
	MonetizationManager.time_scale = 1.0
	DailyRewards.clock_override = ""
	DailyRewards.auto_popup_enabled = false
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	UiKit.set_banner_slot(0.0)
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- A) Normal kapanış -------------------------------------------------------------------------------------

func _normal_close() -> void:
	print("-- A: normal geçiş reklamı — gösterildi + kapanış (pozitif kontrol)")
	await _boot()
	var m: MonetizationManager = _main._ads
	_gates(m)
	var board: Node2D = await _start(3)
	var seq: int = _main._result_seq
	var loads: int = _fake.interstitial_loads
	await _finish(board)
	var id: String = await _break_request()
	_c("A: geçerli normal bitiş, iki kapı sağlanmış: geçiş reklamı SDK'ya verildi, mola açık, sonuç yok",
		id != "" and m.break_pending() and not _main._result.visible)
	_c("A: [TASK/052 tanılama] tam ekran kirası açık", _lease_active(m))
	_fake.emit_interstitial_showed(id)
	await _settle(1)
	_c("A: SDK 'gösterildi': mola sürüyor, saat sıfırlandı, gösterim 1", m.break_pending()
		and m.active_elapsed_sec() == 0.0 and m.interstitial_shows() == 1)
	_c("A: [TASK/052 tanılama] round sayacı da sıfırlandı", _rounds(m) == 0)
	_fake.emit_interstitial_impression(id)
	_fake.emit_interstitial_dismissed(id)
	await _settle(3)
	_c("A: kapanış → mola TAM bir kez bitti, sonuç TAM bir kez (seq + 2), RESULT yüzeyi, kira kapandı",
		not m.break_pending() and _main._result.visible and _shows == 1 and _main._result_seq == seq + 2
		and m.surface() == MonetizationManager.Surface.RESULT and not _lease_active(m))
	_c("A: 60 sn tam ekran beklemesi, sıradaki reklam önyüklemede (yükleme + 1), kurtarma 0, mola açık değil",
		is_equal_approx(m.fullscreen_cooldown_sec(), MonetizationManager.FULLSCREEN_AD_COOLDOWN_SEC)
		and _fake.interstitial_loads == loads + 1 and _recoveries(m) == 0 and not _main.is_pause_open())
	_fake.emit_interstitial_dismissed(id)
	await _settle(2)
	_c("A: yinelenen kapanış zararsız (sonuç 1, seq aynı)", _shows == 1 and _main._result_seq == seq + 2)
	_sections_done += 1


# --- B) Gösterim hatası --------------------------------------------------------------------------------------

func _show_failure() -> void:
	print("-- B: gösterim hatası tam ekrandan önce (pozitif kontrol)")
	await _boot()
	var m: MonetizationManager = _main._ads
	_gates(m)
	var board: Node2D = await _start(3)
	var seq: int = _main._result_seq
	await _finish(board)
	var id: String = await _break_request()
	_fake.emit_interstitial_show_failed(id)
	await _settle(3)
	_c("B: gösterim hatası → mola bitti, sonuç TAM bir kez, bekleme YOK, uygunluk kaldı, reklam düştü, yeni yükleme",
		id != "" and not m.break_pending() and _main._result.visible and _shows == 1 and _main._result_seq == seq + 2
		and m.fullscreen_cooldown_sec() == 0.0 and m.interstitial_eligible() and _fake.interstitial_removed.has(id)
		and m.interstitial_state() == MonetizationManager.InterstitialState.LOADING and not _lease_active(m))
	_fake.emit_interstitial_dismissed(id)
	_fake.emit_interstitial_show_failed(id)
	await _settle(2)
	_c("B: hatadan sonra geç kapanış / ikinci hata: ikinci sonuç yok, kurtarma 0", _shows == 1
		and _main._result_seq == seq + 2 and _recoveries(m) == 0)
	_sections_done += 1


# --- C) Kapanış kayıp ----------------------------------------------------------------------------------------

func _missing_close() -> void:
	print("-- C: SDK geri çağrısı kayıp — uygulamanın kendi molası örtülmemiş kira sınırında kurtarılır")
	# C1: "gösterildi" geldi, kapanış / hata / yaşam döngüsü hiç gelmiyor.
	await _boot()
	var m: MonetizationManager = _main._ads
	_gates(m)
	var board: Node2D = await _start(3)
	var seq: int = _main._result_seq
	await _finish(board)
	var id: String = await _break_request()
	_fake.emit_interstitial_showed(id)
	await _wait(_lease_sec() * 0.5)
	_c("C1: 'gösterildi' + kapanış / hata / PAUSED / RESUMED YOK: kira sınırının yarısında mola SÜRÜYOR (erken bitiş yok)",
		id != "" and m.break_pending() and not _main._result.visible)
	await _wait(_lease_sec() + 0.1)
	await _settle(2)
	_c("C1: örtülmemiş kira sınırından sonra uygulama molası TAM bir kez kurtarıldı: sonuç TAM bir kez, RESULT yüzeyi",
		not m.break_pending() and _main._result.visible and _shows == 1 and _main._result_seq == seq + 2
		and m.surface() == MonetizationManager.Surface.RESULT)
	var closed: Dictionary = AdEvents.last(&"interstitial_dismissed")
	_c("C1: 'kapandı' sonucu: 60 sn bekleme, round 0 (gösterimde sıfırlandı), gösterim 1 (iki kez sayılmadı), kurtarma 1, "
		+ "olay recovered=uncovered_lease", is_equal_approx(m.fullscreen_cooldown_sec(),
		MonetizationManager.FULLSCREEN_AD_COOLDOWN_SEC) and _rounds(m) == 0 and m.interstitial_shows() == 1
		and _recoveries(m) == 1 and str(closed.get("recovered", "")) == "uncovered_lease" and closed.get("ad_id", "") == id)
	_c("C1: tam ekran artık aktif değil, kira kapandı, ödüllü yeniden hazır, aktif saat yeniden sayar",
		not m.fullscreen_ad_active() and not _lease_active(m) and m.is_rewarded_ready() and _clock_counts(m))
	# C2: SDK gösterim çağrısına hiç cevap vermedi (eklenti sessizce düşürdü), uygulama hiç örtülmedi.
	await _boot()
	m = _main._ads
	_gates(m)
	board = await _start(3)
	seq = _main._result_seq
	await _finish(board)
	id = await _break_request()
	await _wait(_lease_sec() * 0.5)
	_c("C2: SDK hiç cevap vermedi: sınırın yarısında mola sürüyor", id != "" and m.break_pending())
	await _wait(_lease_sec() + 0.1)
	await _settle(2)
	var failed: Dictionary = AdEvents.last(&"interstitial_show_failed")
	_c("C2: 'gösterilmedi' sonucu: sonuç TAM bir kez, bekleme YOK, uygunluk korundu, gösterim 0, olay show_failed "
		+ "'show confirm timeout'", not m.break_pending() and _main._result.visible and _shows == 1
		and _main._result_seq == seq + 2 and m.fullscreen_cooldown_sec() == 0.0 and m.interstitial_eligible()
		and m.interstitial_shows() == 0 and failed.get("message", "") == "show confirm timeout")
	_c("C2: [TASK/052 tanılama] round sayacı korundu, olay recovered=uncovered_lease",
		_rounds(m) >= AdPolicy.FORCED_INTERSTITIAL_MIN_ROUNDS and str(failed.get("recovered", "")) == "uncovered_lease")
	_sections_done += 1


# --- D) Arka plan / öne dönüş --------------------------------------------------------------------------------

func _background_resume() -> void:
	print("-- D: arka plan / öne dönüş — örtülüyken bitiş yok, öne dönüş payı, tekrarlanan duraklatma, kayıp RESUMED")
	# D1
	var m: MonetizationManager = await _stuck_break()
	var id: String = m.interstitial_showing_id()
	# `_stuck_break` mola başladıktan SONRA döner: Main sonucu zamanlarken `_result_seq`'i zaten 1 artırdı — sunum + 1.
	var seq: int = _main._result_seq
	_pause()
	await _wait(_lease_sec() * 4.0)
	_c("D1: 'gösterildi' + uygulama duraklatıldı (reklam üstte): kira sınırının 4 katı boyunca mola SÜRÜYOR "
		+ "(arka plan tamamlanma sayılmaz)", id != "" and m.break_pending() and not _main._result.visible)
	_resume()
	await _wait(_grace_sec() * 0.5)
	_c("D1: öne dönüş: payın yarısında hâlâ SDK'nın kapanışı bekleniyor", m.break_pending())
	await _wait(_grace_sec() + 0.1)
	await _settle(2)
	_c("D1: öne dönüş payı sonunda mola TAM bir kez bitti, sonuç bir kez, 60 sn bekleme",
		not m.break_pending() and _main._result.visible and _shows == 1 and _main._result_seq == seq + 1
		and is_equal_approx(m.fullscreen_cooldown_sec(), MonetizationManager.FULLSCREEN_AD_COOLDOWN_SEC))
	_c("D1: [TASK/052 tanılama] kurtarma 1, olay recovered=resume_grace", _recoveries(m) == 1
		and str(AdEvents.last(&"interstitial_dismissed").get("recovered", "")) == "resume_grace")
	# D2: tekrarlanan arka plan / öne dönüş.
	m = await _stuck_break()
	seq = _main._result_seq
	_pause()
	_resume()
	await _wait(_grace_sec() * 0.5)
	_pause()
	await _wait(_grace_sec() * 3.0)
	_c("D2: öne dönüş payı sürerken yeniden duraklatıldı: duraklatılmışken bitiş YOK (eski pay iptal)", m.break_pending()
		and not _main._result.visible)
	_resume()
	await _wait(_grace_sec() + 0.1)
	await _settle(2)
	_c("D2: son öne dönüşten sonra TAM bir kez kurtarma, sonuç bir kez", not m.break_pending() and _shows == 1
		and _main._result_seq == seq + 1 and _recoveries(m) == 1)
	# D3: RESUMED hiç gelmiyor (yaşam döngüsü kaybı) — girdi kanıtı.
	m = await _stuck_break()
	seq = _main._result_seq
	_pause()
	await _press()
	await _wait(_lease_sec() * 2.0)
	_c("D3: RESUMED kayıp; duraklatmadan hemen sonraki dokunuş (geçiş penceresi) kanıt SAYILMAZ: mola sürüyor",
		m.break_pending() and not _main._result.visible)
	await _press()
	await _wait(_lease_sec() * 0.5)
	_c("D3: dışlama penceresinden sonra uygulamaya ulaşan YENİ dokunuş: sınırın yarısında hâlâ sürüyor", m.break_pending())
	await _wait(_lease_sec() + 0.1)
	await _settle(2)
	_c("D3: girdi kanıtından sonra mola TAM bir kez kurtarıldı (input_evidence), sonuç bir kez; RESUMED hâlâ gelmedi ama "
		+ "dokunuş öne dönüş sayıldı (duraklatma düştü — banner / saat / doğal mola takılı kalmaz)",
		not m.break_pending() and _main._result.visible and _shows == 1 and _main._result_seq == seq + 1
		and _recoveries(m) == 1 and str(AdEvents.last(&"interstitial_dismissed").get("recovered", "")) == "input_evidence"
		and not bool(m.get("_app_paused")))
	_resume()
	await _settle(2)
	_sections_done += 1


# --- E) Kurtarmadan sonra geç geri çağrılar ------------------------------------------------------------------

func _late_callbacks() -> void:
	print("-- E: kurtarmadan sonra geç geri çağrılar sahiplik için eskidir")
	var m: MonetizationManager = await _stuck_break()
	var id: String = m.interstitial_showing_id()
	var seq: int = _main._result_seq
	await _wait(_lease_sec() + 0.1)
	await _settle(2)
	var shows: int = m.interstitial_shows()
	var loads: int = _fake.interstitial_loads
	_c("E1 ön koşul: 'kapandı' kurtarması oldu, sonuç bir kez", id != "" and not m.break_pending() and _shows == 1)
	_fake.emit_interstitial_dismissed(id)
	_fake.emit_interstitial_show_failed(id)
	_fake.emit_interstitial_showed(id)
	await _settle(3)
	_c("E1: geç kapanış + hata + 'gösterildi': ikinci sonuç / ikinci mola bitişi / ikinci gösterim sayımı / yeni "
		+ "yükleme YOK", _shows == 1 and _main._result_seq == seq + 1 and not m.break_pending()
		and m.interstitial_shows() == shows and _recoveries(m) == 1 and _fake.interstitial_loads == loads)
	# E2: "gösterilmedi" kurtarmasından SONRA reklam gerçekten açıldı (SDK sözleşme dışı gecikme).
	await _boot()
	m = _main._ads
	_gates(m)
	var board: Node2D = await _start(3)
	await _finish(board)
	id = await _break_request()
	await _wait(_lease_sec() + 0.1)
	await _settle(2)
	var shows0: int = m.interstitial_shows()
	_c("E2 ön koşul: 'gösterilmedi' kurtarması, sonuç bir kez, uygunluk sürüyor", id != "" and not m.break_pending()
		and _shows == 1 and m.interstitial_eligible() and shows0 == 0)
	_fake.emit_interstitial_showed(id)
	await _settle(1)
	_c("E2: geç GERÇEK gösterim BİR kez sayıldı, sıklık sayaçları sıfırlandı (saat 0, round 0, uygun değil) — art arda "
		+ "zorunlu reklam yok; ikinci sonuç yok", m.interstitial_shows() == shows0 + 1 and m.active_elapsed_sec() == 0.0
		and _rounds(m) == 0 and not m.interstitial_eligible() and _shows == 1)
	_fake.emit_interstitial_showed(id)
	await _settle(1)
	_c("E2: yinelenen geç 'gösterildi' ikinci kez sayılmadı", m.interstitial_shows() == shows0 + 1)
	_fake.emit_interstitial_dismissed(id)
	await _settle(1)
	_c("E2: geç kapanış yalnız 60 sn beklemeyi başlattı; sonuç yine 1, mola yok",
		is_equal_approx(m.fullscreen_cooldown_sec(), MonetizationManager.FULLSCREEN_AD_COOLDOWN_SEC) and _shows == 1
		and not m.break_pending())
	_sections_done += 1


# --- F) Yinelenen geri çağrılar ------------------------------------------------------------------------------

class _Counter:
	var calls: int = 0
	func hit() -> void:
		calls += 1


func _duplicates() -> void:
	print("-- F: yinelenen geri çağrılar — mola geri çağrısı tam bir kez")
	for combo: Array in [["dismissed", "dismissed"], ["failed", "dismissed"], ["dismissed", "failed"]]:
		var fake := FakeAdBackend.new()
		var m: MonetizationManager = _manager(fake)
		_gates(m)
		var counter := _Counter.new()
		var shown: bool = m.try_show_interstitial("round_finish", counter.hit)
		var id: String = fake.interstitial_shows[-1] if not fake.interstitial_shows.is_empty() else ""
		if combo[0] == "dismissed":
			fake.emit_interstitial_showed(id)
		for event: String in combo:
			if event == "dismissed":
				fake.emit_interstitial_dismissed(id)
			else:
				fake.emit_interstitial_show_failed(id)
		await _settle(2)
		_c("F: %s → mola geri çağrısı TAM bir kez, mola / kira kapalı" % "+".join(combo), shown and counter.calls == 1
			and not m.break_pending() and not _lease_active(m))
		await _free(m)
	var fake2 := FakeAdBackend.new()
	var m2: MonetizationManager = _manager(fake2)
	_gates(m2)
	var counter2 := _Counter.new()
	m2.try_show_interstitial("round_finish", counter2.hit)
	var id2: String = fake2.interstitial_shows[-1] if not fake2.interstitial_shows.is_empty() else ""
	fake2.emit_interstitial_showed(id2)
	fake2.emit_interstitial_showed(id2)
	fake2.emit_interstitial_dismissed(id2)
	await _settle(2)
	_c("F: gösterildi + gösterildi + kapanış → gösterim BİR kez sayıldı, geri çağrı bir kez", m2.interstitial_shows() == 1
		and counter2.calls == 1)
	await _free(m2)
	# Kurtarma yolu da tam bir kez (Main'in sonuç / nesil korumalarından bağımsız — yöneticinin kendi geri çağrısı).
	var fake3 := FakeAdBackend.new()
	var m3: MonetizationManager = _manager(fake3)
	_gates(m3)
	var counter3 := _Counter.new()
	m3.try_show_interstitial("round_finish", counter3.hit)
	var id3: String = fake3.interstitial_shows[-1] if not fake3.interstitial_shows.is_empty() else ""
	fake3.emit_interstitial_showed(id3)
	await _wait(_lease_sec() + 0.1)
	_c("F: kapanış kayıp → kurtarma: mola geri çağrısı TAM bir kez", id3 != "" and counter3.calls == 1
		and not m3.break_pending())
	fake3.emit_interstitial_dismissed(id3)
	fake3.emit_interstitial_show_failed(id3)
	await _settle(1)
	_c("F: kurtarmadan sonra geç kapanış + hata: geri çağrı hâlâ 1", counter3.calls == 1)
	await _free(m3)
	_sections_done += 1


# --- G) TASK/048 ertelenen yeniden başlatma -------------------------------------------------------------------

func _deferred_restart() -> void:
	print("-- G: TASK/048 — mola sürerken ertelenen yeniden başlatma kurtarmada tam bir kez")
	await _boot()
	var m: MonetizationManager = _main._ads
	_gates(m)
	var board: Node2D = await _start(3)
	var gen: int = int(_main.get("_round_generation"))
	await _finish(board)
	var id: String = await _break_request()
	_fake.emit_interstitial_showed(id)
	await _settle(1)
	# Molanın "Yeniden Başlat" üretim işleyicisi (TASK/049'dan beri mola bitişte kapalı — işleyiciyi doğrudan çağıran
	# yollar, ör. QA kancaları; TASK/048 savunması).
	_main._on_pause_restart()
	await _settle(2)
	_c("G: mola sürerken 'Yeniden Başlat' işleyicisi ERTELENDİ (board aynı, nesil aynı, erteleme bekliyor)", id != ""
		and _main._board == board and int(_main.get("_round_generation")) == gen
		and (_main.get("_deferred_round_change") as Callable).is_valid())
	await _wait(_lease_sec() + 0.15)
	await _settle(3)
	var next: Node2D = _main._board
	_track(next)
	_c("G: kurtarma molayı bitirdi → ertelenen yeniden başlatma eski sonucun YERİNE TAM bir kez çalıştı (yeni board, "
		+ "nesil + 1, sonuç yok, erteleme boş)", next != null and next != board and int(_main.get("_round_generation")) == gen + 1
		and not _main._result.visible and _shows == 0 and not (_main.get("_deferred_round_change") as Callable).is_valid()
		and not next.is_finished() and not m.break_pending())
	_fake.emit_interstitial_dismissed(id)
	await _settle(3)
	_c("G: geç kapanış ertelenen değişimi ikinci kez çalıştırmadı (board aynı, nesil aynı, sonuç yok)", _main._board == next
		and int(_main.get("_round_generation")) == gen + 1 and not _main._result.visible)
	await _wait_settled()
	var dropped: bool = await _drop_ok(next)
	_c("G: yeni board GERÇEK dokunuşla tam 1 bırakış aldı", dropped)
	_sections_done += 1


# --- H) Ödüllü: ödül kazanıldı, kapanış kayıp -----------------------------------------------------------------

func _rewarded_reward_then_lost_close() -> void:
	print("-- H: ödüllü — ödül kazanıldı, kapanış kayıp: ödül tam bir kez, kurtarma talebi kapatır")
	# H1: devam.
	await _boot()
	var m: MonetizationManager = _main._ads
	var board: Node2D = await _start(3)
	board._enter_fail_pending()
	await _settle(2)
	_c("H1 ön koşul: devam teklifi açık, ödüllü hazır", _main._revive.visible and m.is_rewarded_ready())
	_main._revive.continue_button().pressed.emit()
	await _settle(1)
	var rid: String = m.request_info()["ad_id"]
	_fake.emit_rewarded_showed(rid)
	_fake.emit_rewarded_earned(rid)
	await _settle(2)
	_c("H1: 'ödül kazanıldı' → devam TAM bir kez (1/2), teklif kapandı", rid != "" and board.revives_used() == 1
		and not _main._revive.visible)
	await _wait(_lease_sec() * 4.0)
	_c("H1: kapanış gelmedi, uygulama hiç duraklatılmadı: ödüllüde 'gösterildi'den sonra süreye bağlı bırakma YOK — "
		+ "sınırın 4 katında talep hâlâ açık", m.has_active_request() and _recoveries(m) == 0)
	_evidence(m)
	await _wait(_lease_sec() + 0.1)
	await _settle(2)
	_c("H1: uygulamaya ulaşan yeni basış (girdi kanıtı) → kurtarma talebi kapattı: ödül YİNE 1 (çift yok), 60 sn bekleme, "
		+ "kurtarma 1, olay recovered=input_evidence, tam ekran yok",
		not m.has_active_request() and board.revives_used() == 1 and is_equal_approx(m.fullscreen_cooldown_sec(),
		MonetizationManager.FULLSCREEN_AD_COOLDOWN_SEC) and _recoveries(m) == 1
		and str(AdEvents.last(&"rewarded_dismissed").get("recovered", "")) == "input_evidence"
		and not m.fullscreen_ad_active())
	_fake.emit_rewarded_dismissed(rid)
	_fake.emit_rewarded_earned(rid)
	await _settle(2)
	_c("H1: geç kapanış + geç 'ödül' eski: devam hâlâ 1, talep yok", board.revives_used() == 1
		and not m.has_active_request())
	# H2: güç refill'i (kotalı, kayıtlı).
	await _boot({"powerups": {"bomb": 2, "upgrade": 9, "shake": 0, "clear_small": 1}})
	m = _main._ads
	board = await _start(3)
	var stock: int = SaveManager.powerup_count(PowerUp.Type.SHAKE)
	var quota: int = RewardedPolicy.grants_today(PowerUp.Type.SHAKE)
	board._power_bar.power_pressed.emit(int(PowerUp.Type.SHAKE))
	await _settle(2)
	_c("H2 ön koşul: stok 0 Sarsıntı → refill penceresi, kota boş", _main._refill.visible and stock == 0 and quota == 0)
	_main._refill.rewarded_refill_requested.emit(int(PowerUp.Type.SHAKE))
	await _settle(1)
	rid = m.request_info()["ad_id"]
	_fake.emit_rewarded_showed(rid)
	_fake.emit_rewarded_earned(rid)
	_fake.emit_rewarded_earned(rid)
	await _settle(2)
	_c("H2: 'ödül kazanıldı' (+ yinelenen) → stok TAM +1, kota TAM 1", rid != ""
		and SaveManager.powerup_count(PowerUp.Type.SHAKE) == 1 and RewardedPolicy.grants_today(PowerUp.Type.SHAKE) == 1)
	await _wait(_lease_sec() + 0.05)
	_evidence(m)
	await _wait(_lease_sec() + 0.1)
	await _settle(2)
	_fake.emit_rewarded_dismissed(rid)
	await _settle(1)
	_c("H2: kapanış kayıp → kurtarma; geç kapanış: stok hâlâ 1, kota hâlâ 1, talep yok",
		SaveManager.powerup_count(PowerUp.Type.SHAKE) == 1 and RewardedPolicy.grants_today(PowerUp.Type.SHAKE) == 1
		and not m.has_active_request() and _recoveries(m) == 1)
	# H3: yöneticinin KENDİ tek-ödül kapısı (Main'in jetonundan bağımsız): ödülü sayan saplama Main.
	var fake := FakeAdBackend.new()
	var mm: MonetizationManager = _manager(fake)
	var stub := _StubMain.new()
	add_child(stub)
	fake.complete_rewarded_load(true)
	mm.show_rewarded_daily_dough(stub, THU, 3)
	var did: String = mm.request_info()["ad_id"]
	fake.emit_rewarded_showed(did)
	fake.emit_rewarded_earned(did)
	fake.emit_rewarded_earned(did)
	_c("H3: yinelenen 'ödül kazanıldı' → yönetici Main'e TAM bir ödül iletti", did != "" and stub.dough_grants == 1)
	await _wait(_lease_sec() + 0.05)
	_evidence(mm)
	await _wait(_lease_sec() + 0.1)
	await _settle(1)
	fake.emit_rewarded_earned(did)
	fake.emit_rewarded_dismissed(did)
	await _settle(1)
	_c("H3: kapanış kayıp → kurtarma; geç 'ödül' / kapanış: ödül hâlâ 1, 'tamamını izle' notu YOK (ödül kazanılmıştı)",
		stub.dough_grants == 1 and not mm.has_active_request() and stub.unavailable_daily.is_empty())
	stub.queue_free()
	await _free(mm)
	_sections_done += 1


# --- I) Ödüllü: ödül yok -------------------------------------------------------------------------------------

class _StubMain extends Node:
	var revives: int = 0
	var dough_grants: int = 0
	var unavailable_daily: Array[String] = []
	var unavailable_revive: Array[String] = []
	func grant_revive() -> bool:
		revives += 1
		return true
	func grant_daily_dough(_day_key: String, _token: int) -> bool:
		dough_grants += 1
		return true
	func notify_daily_rewarded_unavailable(_kind: String, message: String) -> void:
		unavailable_daily.append(message)
	func notify_rewarded_unavailable(message: String) -> void:
		unavailable_revive.append(message)


func _rewarded_no_reward() -> void:
	print("-- I: ödüllü — ödül geri çağrısı yok: kurtarma ödül VERMEZ")
	# I1: devam, gösterildi, ödül yok, kapanış kayıp.
	await _boot()
	var m: MonetizationManager = _main._ads
	var board: Node2D = await _start(3)
	board._enter_fail_pending()
	await _settle(2)
	_main._revive.continue_button().pressed.emit()
	await _settle(1)
	var rid: String = m.request_info()["ad_id"]
	_fake.emit_rewarded_showed(rid)
	await _wait(_lease_sec() * 4.0)
	_c("I1: gösterildi, duraklatma / kapanış yok: talep süreyle kesilmedi (sınırın 4 katı)", rid != ""
		and m.has_active_request() and board.revives_used() == 0)
	_evidence(m)
	await _wait(_lease_sec() + 0.1)
	await _settle(2)
	_c("I1: gösterildi, ödül yok, kapanış kayıp → girdi kanıtıyla kurtarma: devam 0 (sahte ödül yok), teklif AÇIK, not "
		+ "'tamamını izle'",
		rid != "" and not m.has_active_request() and board.revives_used() == 0 and _main._revive.visible
		and board.is_fail_pending() and _main._revive.note_text() == MonetizationManager.NOTE_NOT_EARNED)
	# I2: SDK gösterim çağrısına hiç cevap vermedi (uygulama örtülmedi) — "gösterilmedi".
	await _boot()
	m = _main._ads
	board = await _start(3)
	board._enter_fail_pending()
	await _settle(2)
	_main._revive.continue_button().pressed.emit()
	await _settle(1)
	rid = m.request_info()["ad_id"]
	await _wait(_lease_sec() * 0.5)
	_c("I2: SDK sessiz: sınırın yarısında talep hâlâ açık", rid != "" and m.has_active_request())
	await _wait(_lease_sec() + 0.1)
	await _settle(2)
	_c("I2: 'gösterilmedi' kurtarması: devam 0, teklif açık, not 'gösterilemedi', reklam önbellekten düştü, bekleme YOK",
		not m.has_active_request() and board.revives_used() == 0 and _main._revive.visible
		and _main._revive.note_text() == MonetizationManager.NOTE_SHOW_FAILED and _fake.rewarded_removed.has(rid)
		and m.fullscreen_cooldown_sec() == 0.0)
	# I3: günlük +150 Hamur (yönetici düzeyi, saplama Main): ödül yok → 0 Hamur.
	var fake := FakeAdBackend.new()
	var mm: MonetizationManager = _manager(fake)
	var stub := _StubMain.new()
	add_child(stub)
	fake.complete_rewarded_load(true)
	mm.show_rewarded_daily_dough(stub, THU, 7)
	var did: String = mm.request_info()["ad_id"]
	fake.emit_rewarded_showed(did)
	await _wait(_lease_sec() + 0.05)
	_evidence(mm)
	await _wait(_lease_sec() + 0.1)
	await _settle(1)
	_c("I3: günlük +Hamur: gösterildi, ödül yok, kapanış kayıp → girdi kanıtıyla kurtarma: Hamur ödülü 0, not 'tamamını "
		+ "izle'", did != ""
		and stub.dough_grants == 0 and not mm.has_active_request()
		and stub.unavailable_daily == [MonetizationManager.NOTE_NOT_EARNED])
	fake.emit_rewarded_earned(did)
	await _settle(1)
	_c("I3: kurtarmadan SONRA gelen geç 'ödül' yetkili değil: Hamur ödülü yine 0", stub.dough_grants == 0)
	stub.queue_free()
	await _free(mm)
	_sections_done += 1


# --- J) Yalnız arka plan -------------------------------------------------------------------------------------

func _background_only() -> void:
	print("-- J: yalnız arka plan molayı bitirmez")
	# J1: "gösterildi" ÖNCESİ duraklatıldı (reklam açılıyor / uygulama örtüldü).
	await _boot()
	var m: MonetizationManager = _main._ads
	_gates(m)
	var board: Node2D = await _start(3)
	var seq: int = _main._result_seq
	await _finish(board)
	var id: String = await _break_request()
	_pause()
	await _wait(_lease_sec() * 4.0)
	_c("J1: gösterim isteğinden sonra uygulama duraklatıldı ('gösterildi' yok): kira sınırının 4 katı boyunca mola SÜRÜYOR",
		id != "" and m.break_pending() and not _main._result.visible)
	_resume()
	await _wait(_grace_sec() + 0.1)
	await _settle(2)
	_c("J1: öne dönüş payından sonra tam bir kez kurtarma, sonuç bir kez; uygulama örtüldüğü için 'kapandı' (60 sn "
		+ "bekleme, sayaçlar sıfırlandı, gösterim SAYILMADI)", not m.break_pending() and _shows == 1
		and _main._result_seq == seq + 2 and is_equal_approx(m.fullscreen_cooldown_sec(),
		MonetizationManager.FULLSCREEN_AD_COOLDOWN_SEC) and _rounds(m) == 0 and m.interstitial_shows() == 0)
	# J2: ödüllü, gösterildi, arka plan.
	await _boot()
	m = _main._ads
	board = await _start(3)
	board._enter_fail_pending()
	await _settle(2)
	_main._revive.continue_button().pressed.emit()
	await _settle(1)
	var rid: String = m.request_info()["ad_id"]
	_fake.emit_rewarded_showed(rid)
	_pause()
	await _wait(_lease_sec() * 4.0)
	_c("J2: ödüllü gösterilirken arka plan: talep açık kaldı (ödülsüz kapanış varsayılmadı)", rid != ""
		and m.has_active_request())
	_resume()
	await _wait(_grace_sec() + 0.1)
	await _settle(2)
	_c("J2: öne dönüş payından sonra talep kapandı, devam 0", not m.has_active_request() and board.revives_used() == 0)
	# J3: ödüllü talep uygulama ZATEN duraklatılmışken başladı (çoklu pencere / etkinlik geçişi anı): kira örtülü
	# başlar — süre işlemez; öne dönüş payıyla biter, ödül yok. Önceki duraklatma reklamın örtmesi sayılmaz ve
	# "gösterildi" de gelmedi → "gösterilmedi".
	var fake := FakeAdBackend.new()
	var mm: MonetizationManager = _manager(fake)
	var stub := _StubMain.new()
	add_child(stub)
	fake.complete_rewarded_load(true)
	mm.notification(NOTIFICATION_APPLICATION_PAUSED)
	mm.show_rewarded_daily_dough(stub, THU, 9)
	var did: String = mm.request_info()["ad_id"]
	await _wait(_lease_sec() * 4.0)
	_c("J3: talep uygulama duraklatılmışken başladı: kira sınırının 4 katı boyunca talep SÜRÜYOR", did != ""
		and mm.has_active_request())
	mm.notification(NOTIFICATION_APPLICATION_RESUMED)
	await _wait(_grace_sec() + 0.1)
	_c("J3: öne dönüş payından sonra talep kapandı — 'gösterilmedi' (önceki duraklatma reklamın kanıtı değil): Hamur "
		+ "ödülü 0, not 'gösterilemedi', bekleme YOK, reklam önbellekten düştü", not mm.has_active_request()
		and stub.dough_grants == 0 and stub.unavailable_daily == [MonetizationManager.NOTE_SHOW_FAILED]
		and mm.fullscreen_cooldown_sec() == 0.0 and fake.rewarded_removed.has(did))
	stub.queue_free()
	await _free(mm)
	_sections_done += 1


# --- K) Kurtarmadan sonraki reklam ---------------------------------------------------------------------------

func _next_ad_after_recovery() -> void:
	print("-- K: kurtarmadan sonra yığılma yok, önyükleme toparlanır, sonraki uygun mola çalışır")
	var m: MonetizationManager = await _stuck_break()
	var id: String = m.interstitial_showing_id()
	await _wait(_lease_sec() + 0.1)
	await _settle(2)
	var counter := _Counter.new()
	var again: bool = m.try_show_interstitial("round_finish", counter.hit)
	var reason: String = str(AdEvents.last(&"interstitial_skipped_not_ready").get("reason", ""))
	_c("K: kurtarmadan hemen sonra yeni tam ekran YOK (sayaçlar sıfır / bekleme)", id != "" and not again
		and (reason == "not_eligible" or reason == "cooldown") and _fake.interstitial_shows.size() == 1)
	while not _fake.pending_interstitial.is_empty():
		_fake.complete_interstitial_load(true)
	await _settle(1)
	_c("K: önyükleme toparlandı: yeni reklam READY (eskisinden farklı kimlik)", m.is_interstitial_ready()
		and m.interstitial_ready_id() != id)
	_gates(m)
	_main._result.hide_result()
	_main._on_retry_pressed()
	await _settle(3)
	var board: Node2D = _main._board
	_track(board)
	var seq: int = _main._result_seq
	await _finish(board)
	var id2: String = await _break_request()
	_c("K: sonraki uygun doğal molada yeni reklam istendi", id2 != "" and id2 != id and m.break_pending())
	_fake.emit_interstitial_showed(id2)
	_fake.emit_interstitial_dismissed(id2)
	await _settle(3)
	_c("K: kapanınca sonuç tam bir kez, kurtarma sayısı değişmedi (1)", not m.break_pending() and _main._result.visible
		and _main._result_seq == seq + 2 and _recoveries(m) == 1)
	_sections_done += 1


# --- L) Yaş / rıza -------------------------------------------------------------------------------------------

func _age_and_consent() -> void:
	print("-- L: yaş bilinmiyor / rıza yok: yükleme, gösterim, kira, round sayımı yok")
	await _boot({"age_ad_band": "", "next_age_transition_date": ""}, false)
	var m: MonetizationManager = _main._ads
	var panel: CanvasLayer = _main.age_panel()
	if panel.visible:
		panel.close_panel()
	await _settle(2)
	_gates(m)
	var board: Node2D = await _start(3)
	await _finish(board)
	await _wait(_delay() + 0.1)
	await _settle(2)
	_c("L1: yaş UNKNOWN: round bitişinde geçiş reklamı denenmez (age_gate), kira yok, yükleme yok, round sayılmaz, sonuç hemen",
		_fake.interstitial_shows.is_empty() and _fake.interstitial_loads == 0 and not _lease_active(m)
		and (_rounds(m) <= 0) and _main._result.visible and not m.break_pending())
	await _boot({}, false, AdBackend.ConsentStatus.REQUIRED)
	m = _main._ads
	# Rıza gerekli, form yok → UMP canRequestAds() false → ADS_NOT_ALLOWED (SDK başlamaz).
	_fake.complete_consent_update(true)
	await _settle(1)
	_gates(m)
	board = await _start(3)
	await _finish(board)
	await _wait(_delay() + 0.1)
	await _settle(2)
	_c("L2: rıza alınmadı (ADS_NOT_ALLOWED): geçiş reklamı yok, kira yok, sonuç hemen", _fake.interstitial_shows.is_empty()
		and not _lease_active(m) and _main._result.visible and not m.ads_allowed())
	_sections_done += 1


# --- M) Meydan okuma ------------------------------------------------------------------------------------------

func _challenge() -> void:
	print("-- M: meydan okuma bitişi — geçiş reklamı denemesi / kira / sayaç YOK")
	await _boot()
	var m: MonetizationManager = _main._ads
	_gates(m)
	var rounds: int = _rounds(m)
	var shows: int = _fake.interstitial_shows.size()
	AdEvents.clear_recent()
	var started: bool = _main.start_daily_challenge()
	await _settle(3)
	var board: Node2D = _main._board
	_track(board)
	await _win_merge(board)
	await _wait(_delay() + 0.1)
	await _settle(2)
	_c("M: reklam UYGUN + HAZIRken meydan okuma bitişi: geçiş reklamı denemesi SIFIR, kira yok, round sayacı değişmedi, "
		+ "meydan okuma sonucu açıldı", started and m.interstitial_eligible() and _fake.interstitial_shows.size() == shows
		and AdEvents.count(&"interstitial_skipped_not_ready") == 0 and not _lease_active(m) and _rounds(m) == rounds
		and _main._result.visible)
	_sections_done += 1


# --- N) Girdi / sonuç sahipliği ------------------------------------------------------------------------------

func _input_result_ownership() -> void:
	print("-- N: takılı mola ve kurtarma sırasında girdi / sonuç sahipliği")
	var m: MonetizationManager = await _stuck_break()
	var board: Node2D = _main._board
	await _back()
	_c("N: mola sürerken Android GERİ: mola açılmadı, board silinmedi", not _main.is_pause_open() and _main._board == board)
	await _wait(_lease_sec() + 0.1)
	await _settle(3)
	_c("N: kurtarma → sonuç tam bir kez", not m.break_pending() and _main._result.visible and _shows == 1)
	await _back()
	_c("N: sonuç ekranında GERİ yok sayıldı (mola açılmadı, sonuç açık)", _main._result.visible and not _main.is_pause_open())
	var guard: int = 0
	while not _main._result.is_reveal_done() and guard < 600:
		await get_tree().process_frame
		guard += 1
	await _wait(0.4)
	var action: String = _main._result.primary_action()
	await _finger_tap(_center(_main._result.primary_button()))
	await _settle(3)
	var ok: bool = not _main._result.visible
	if action == "retry":
		ok = ok and _main._board != null and _main._board != board and not _main._board.is_finished()
	else:
		ok = ok and _main._board == null
	_c("N: sonuç düğmesine ('%s') GERÇEK dokunuş çalıştı — girdi bloklu değil" % action, ok)
	_sections_done += 1


# --- T) Jeton sahipliği --------------------------------------------------------------------------------------

func _token_ownership() -> void:
	print("-- T: eski kiranın zamanlayıcısı yeni talebi bitiremez")
	var fake := FakeAdBackend.new()
	var m: MonetizationManager = _manager(fake)
	var stub := _StubMain.new()
	add_child(stub)
	var r1: String = fake.complete_rewarded_load(true)
	m.show_rewarded_revive(stub)
	fake.emit_rewarded_showed(r1)
	m.notification(NOTIFICATION_APPLICATION_PAUSED)
	m.notification(NOTIFICATION_APPLICATION_RESUMED)
	await _wait(_grace_sec() * 0.5)
	m.notification(NOTIFICATION_APPLICATION_PAUSED)
	m.notification(NOTIFICATION_APPLICATION_RESUMED)
	fake.emit_rewarded_dismissed(r1)
	await _settle(1)
	var r2: String = fake.complete_rewarded_load(true)
	m.show_rewarded_revive(stub)
	fake.emit_rewarded_showed(r2)
	m.notification(NOTIFICATION_APPLICATION_PAUSED)
	await _wait(_grace_sec() * 0.5 + 0.05)
	_c("T: önceki talebin öne dönüş zamanlayıcıları YENİ talebi (gösterilen, örtülü) bitirmedi", r2 != ""
		and m.has_active_request() and m.request_info()["ad_id"] == r2 and stub.unavailable_revive.size() == 1)
	m.notification(NOTIFICATION_APPLICATION_RESUMED)
	await _wait(_grace_sec() + 0.1)
	_c("T: yeni talep kendi öne dönüş payında kapandı (ödülsüz), devam 0", not m.has_active_request()
		and stub.revives == 0 and stub.unavailable_revive.size() == 2)
	stub.queue_free()
	await _free(m)
	_sections_done += 1


# --- O) Eklentinin sahipsiz yeniden yüklemesi ------------------------------------------------------------------

func _orphan_reload() -> void:
	print("-- O: kapanan geçiş reklamının sahipsiz yeniden yükleme hatası (emekli kimlik)")
	var fake := FakeAdBackend.new()
	var m: MonetizationManager = _manager(fake)
	_gates(m)
	var counter := _Counter.new()
	m.try_show_interstitial("round_finish", counter.hit)
	var id: String = fake.interstitial_shows[-1] if not fake.interstitial_shows.is_empty() else ""
	fake.emit_interstitial_showed(id)
	fake.emit_interstitial_dismissed(id)
	await _settle(1)
	_c("O ön koşul: kapanış → yeni önyükleme sürüyor (LOADING, deneme 0)", id != "" and counter.calls == 1
		and m.interstitial_state() == MonetizationManager.InterstitialState.LOADING and m.interstitial_attempts() == 0)
	fake.interstitial_failed_to_load.emit(id, 3, "No fill (orphan auto-reload)")
	await _settle(1)
	_c("O: kapanan reklamın (emekli kimlik) yükleme hatası süren önyüklemeyi BOZMADI: LOADING, deneme 0, yeniden deneme "
		+ "yok, olay stale", m.interstitial_state() == MonetizationManager.InterstitialState.LOADING
		and m.interstitial_attempts() == 0 and not m.has_pending_interstitial_retry()
		and AdEvents.last(&"interstitial_load_failed").get("stale", false) == true)
	fake.complete_interstitial_load(false)
	await _settle(1)
	_c("O: süren yüklemenin GERÇEK hatası yine işlendi: FAILED, deneme 1, planlı yeniden deneme",
		m.interstitial_state() == MonetizationManager.InterstitialState.FAILED and m.interstitial_attempts() == 1
		and m.has_pending_interstitial_retry())
	await _free(m)
	_sections_done += 1


# --- U) İnceleme sertleştirmesi -------------------------------------------------------------------------------

## Android onPause'un sırası (GodotVulkanRenderView): FOCUS_OUT, sonra PAUSED.
func _focus_out_pause() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)


## Android onResume'un sırası: RESUMED, sonra FOCUS_IN (etkinlik gerçekten en üstte).
func _real_resume() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)


## Yöneticiye doğrudan yeni bir basış (girdi kanıtının birim yolu; gerçek görünüm yolu D3 / U11'de).
func _evidence(m: MonetizationManager) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(360, 700)
	touch.pressed = true
	m._input(touch)


func _field(m: Object, name: String, fallback: Variant) -> Variant:
	var value: Variant = m.get(name)
	return fallback if value == null else value


## Yönetici betiğinin sabiti (düzeltmesiz kodda yoksa `fallback`).
func _const(m: Object, name: String, fallback: Variant) -> Variant:
	return (m.get_script() as GDScript).get_script_constant_map().get(name, fallback)


func _review_hardening() -> void:
	print("-- U: inceleme sertleştirmesi — Vulkan sahte RESUMED, saat sınırı, ödüllü 'gösterildi' sonrası, tek sıfırlama "
		+ "kuralı, süre dolumu, önbellek, yükleme tetiği, yinelenen hata, kayıp RESUMED onarımı")
	# U1: Godot 4.6 Vulkan — HOME / kilit / arama sırasında reklam üstte; dönüşte etkinlik onStart'ta yeniden başlar ve
	# RESUMED gelir ama etkinlik ÖNE GELMEDİ (FOCUS_IN yok, reklam hâlâ üstte).
	var m: MonetizationManager = await _stuck_break()
	var seq: int = _main._result_seq
	_focus_out_pause()
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)
	await _wait(_grace_sec() * 4.0)
	await _settle(2)
	_c("U1: odak kaybındayken gelen RESUMED (Vulkan onStart, reklam üstte): pay sınırının 4 katı boyunca mola SÜRÜYOR, "
		+ "uygulama duraklatılmış sayılıyor, kurtarma 0", m.break_pending() and not _main._result.visible
		and bool(m.get("_app_paused")) and _recoveries(m) == 0)
	_real_resume()
	await _wait(_grace_sec() + 0.1)
	await _settle(2)
	_c("U1: gerçek öne dönüş (RESUMED + FOCUS_IN): pay sonunda TAM bir kez kurtarma (resume_grace), sonuç bir kez",
		not m.break_pending() and _main._result.visible and _shows == 1 and _main._result_seq == seq + 1
		and _recoveries(m) == 1 and str(AdEvents.last(&"interstitial_dismissed").get("recovered", "")) == "resume_grace"
		and not bool(m.get("_app_paused")))
	# U2: aynı sahte RESUMED ödüllü talepte — oyuncu reklamı bitirir, ödül GERÇEK geri çağrıyla gelir ve verilir.
	await _boot()
	m = _main._ads
	var board: Node2D = await _start(3)
	board._enter_fail_pending()
	await _settle(2)
	_main._revive.continue_button().pressed.emit()
	await _settle(1)
	var rid: String = m.request_info()["ad_id"]
	_focus_out_pause()
	_fake.emit_rewarded_showed(rid)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)
	await _wait(_grace_sec() * 4.0)
	_c("U2: ödüllü + sahte RESUMED: talep AÇIK kaldı (ödülsüz kapanış varsayılmadı)", rid != "" and m.has_active_request()
		and board.revives_used() == 0)
	_fake.emit_rewarded_earned(rid)
	await _settle(2)
	_c("U2: reklam bitince gelen 'ödül kazanıldı' YETKİLİ: devam TAM bir kez", board.revives_used() == 1)
	_real_resume()
	await _wait(_grace_sec() + 0.1)
	await _settle(2)
	_c("U2: gerçek öne dönüşte talep kapandı ('kapandı': resume_grace, 60 sn bekleme), devam yine 1, 'tamamını izle' "
		+ "notu YOK", not m.has_active_request() and board.revives_used() == 1
		and _main._revive.note_text() != MonetizationManager.NOTE_NOT_EARNED
		and str(AdEvents.last(&"rewarded_dismissed").get("recovered", "")) == "resume_grace"
		and is_equal_approx(m.fullscreen_cooldown_sec(), MonetizationManager.FULLSCREEN_AD_COOLDOWN_SEC))
	# U3: arka plandan dönüşte ilk karenin dev delta'sı aktif saate sızmaz.
	await _boot()
	m = _main._ads
	var before: float = m.active_elapsed_sec()
	_pause()
	_resume()
	m._process(360.0)
	var cap: float = float(_const(m, "ACTIVE_TICK_MAX_SEC", -1.0))
	_c("U3: dönüşteki ilk kare 360 sn delta: aktif saat en çok kare sınırı kadar (≤ 1 sn) arttı (sızıntı yok)", cap > 0.0
		and cap <= 1.0
		and m.active_elapsed_sec() - before <= cap + 0.001 and m.active_elapsed_sec() > before)
	# U4: ödüllü, SDK "gösterildi" dedi ama uygulama hiç duraklatılmadı (etkinliği duraklatmayan gösterim yolu): süreye
	# bağlı bırakma YOK; yalnız "gösterildi"den sonra uygulamaya ulaşan yeni dokunuş.
	var fake := FakeAdBackend.new()
	var mm: MonetizationManager = _manager(fake)
	var stub := _StubMain.new()
	add_child(stub)
	fake.complete_rewarded_load(true)
	mm.show_rewarded_daily_dough(stub, THU, 11)
	var did: String = mm.request_info()["ad_id"]
	fake.emit_rewarded_showed(did)
	_evidence(mm)
	await _wait(_lease_sec() * 4.0)
	_c("U4: 'gösterildi', duraklatma yok: kira sınırının 4 katı boyunca talep AÇIK (ödül sözü süreyle kesilmez); "
		+ "'gösterildi'den hemen sonraki basış kanıt sayılmadı", did != "" and mm.has_active_request()
		and stub.unavailable_daily.is_empty() and _recoveries(mm) == 0)
	fake.emit_rewarded_earned(did)
	_c("U4: reklam sürerken gelen 'ödül kazanıldı' verildi (talep hâlâ açık)", stub.dough_grants == 1
		and mm.has_active_request())
	_evidence(mm)
	await _wait(_lease_sec() * 0.5)
	_c("U4: 'gösterildi'den sonra uygulamaya ulaşan yeni basış: sınırın yarısında talep hâlâ açık", mm.has_active_request())
	# Aynı gösterimin yinelenen "gösterildi"si kabul edilmiş kanıtı / zamanlayıcıyı bozmaz.
	fake.emit_rewarded_showed(did)
	await _wait(_lease_sec() * 0.5 + 0.1)
	_c("U4: girdi kanıtıyla TAM bir kez kapandı (input_evidence): ödül 1, not yok, 60 sn bekleme, eklenti nesnesi "
		+ "önbellekten düştü", not mm.has_active_request() and stub.dough_grants == 1 and stub.unavailable_daily.is_empty()
		and str(AdEvents.last(&"rewarded_dismissed").get("recovered", "")) == "input_evidence"
		and is_equal_approx(mm.fullscreen_cooldown_sec(), MonetizationManager.FULLSCREEN_AD_COOLDOWN_SEC)
		and fake.rewarded_removed.has(did))
	# U5: "ödül kazanıldı" geldi ama "gösterildi" ve PAUSED kayboldu: "gösterilemedi" sayılmaz.
	fake.complete_rewarded_load(true)
	mm._fullscreen_cooldown = 0.0
	stub.unavailable_daily.clear()
	mm.show_rewarded_daily_dough(stub, THU, 12)
	var eid: String = mm.request_info()["ad_id"]
	fake.emit_rewarded_earned(eid)
	await _wait(_lease_sec() + 0.1)
	_c("U5: 'ödül kazanıldı' + 'gösterildi' / PAUSED kayıp → 'kapandı': ödül 2 (bir kez daha), 'gösterilemedi' notu YOK, "
		+ "60 sn bekleme", eid != "" and eid != did and not mm.has_active_request() and stub.dough_grants == 2
		and stub.unavailable_daily.is_empty()
		and is_equal_approx(mm.fullscreen_cooldown_sec(), MonetizationManager.FULLSCREEN_AD_COOLDOWN_SEC))
	# U10: yinelenen SDK "gösterilemedi" süren önyüklemeyi bozmaz (kapanan kimlik emekli).
	mm._fullscreen_cooldown = 0.0
	while not fake.pending_rewarded.is_empty():
		fake.complete_rewarded_load(true)
	mm.show_rewarded_daily_dough(stub, THU, 13)
	var fid: String = mm.request_info()["ad_id"]
	fake.emit_rewarded_show_failed(fid)
	await _settle(1)
	var loads: int = fake.rewarded_loads
	var state: int = mm.rewarded_state()
	fake.emit_rewarded_show_failed(fid)
	await _settle(1)
	_c("U10: yinelenen 'gösterilemedi' ESKİ: önyükleme durumu ve yükleme sayısı değişmedi", fid != ""
		and state == MonetizationManager.RewardedState.LOADING and mm.rewarded_state() == state
		and fake.rewarded_loads == loads)
	stub.queue_free()
	await _free(mm)
	# U6: geçiş — SDK kapanışı geldi ama "gösterildi" kayboldu: kapanış gösterimin kanıtı, sayaçlar sıfırlanır,
	# gösterim SAYILMAZ (kurtarmanın örtülme kuralıyla aynı tek kural).
	fake = FakeAdBackend.new()
	mm = _manager(fake)
	_gates(mm)
	var counter := _Counter.new()
	mm.try_show_interstitial("round_finish", counter.hit)
	var iid: String = fake.interstitial_shows[-1] if not fake.interstitial_shows.is_empty() else ""
	fake.emit_interstitial_dismissed(iid)
	await _settle(1)
	_c("U6: 'gösterildi' kayıp + SDK kapanışı: mola bir kez, sayaçlar sıfırlandı (saat 0, round 0, uygun değil), gösterim "
		+ "SAYILMADI, 60 sn bekleme", iid != "" and counter.calls == 1 and mm.active_elapsed_sec() == 0.0
		and _rounds(mm) == 0 and not mm.interstitial_eligible() and mm.interstitial_shows() == 0
		and is_equal_approx(mm.fullscreen_cooldown_sec(), MonetizationManager.FULLSCREEN_AD_COOLDOWN_SEC))
	# U6b: "gösterilmedi" kurtarmasından SONRA kendi reklamımızın geç kapanışı ("gösterildi" yine yok) → sıfırlama.
	while not fake.pending_interstitial.is_empty():
		fake.complete_interstitial_load(true)
	mm._fullscreen_cooldown = 0.0
	_gates(mm)
	counter = _Counter.new()
	mm.try_show_interstitial("round_finish", counter.hit)
	var lid: String = fake.interstitial_shows[-1]
	await _wait(_lease_sec() + 0.1)
	_c("U6b ön koşul: 'gösterilmedi' kurtarması — sayaçlar korundu", counter.calls == 1 and lid != iid
		and _rounds(mm) >= AdPolicy.FORCED_INTERSTITIAL_MIN_ROUNDS and mm.interstitial_eligible())
	fake.emit_interstitial_dismissed(lid)
	await _settle(1)
	_c("U6b: geç kapanış (gösterildi yok): sayaçlar sıfırlandı, gösterim SAYILMADI, 60 sn bekleme, ikinci mola yok",
		counter.calls == 1 and _rounds(mm) == 0 and not mm.interstitial_eligible() and mm.interstitial_shows() == 0
		and is_equal_approx(mm.fullscreen_cooldown_sec(), MonetizationManager.FULLSCREEN_AD_COOLDOWN_SEC))
	# U9: uygun mola başka sebeple atlansa da (bekleme) tükenmiş yükleme döngüsü yeniden tetiklenir. Kapılar ÖNCE
	# sağlanır (uygunluk anının kendi tetiği geçsin), sonra döngü tükenmiş + bekleme sürüyor kurulur.
	_gates(mm)
	mm._cancel_timer(mm._interstitial_retry_timer)
	mm._interstitial_retry_timer = null
	mm._discard_ready_interstitial()
	mm._set_interstitial_state(MonetizationManager.InterstitialState.FAILED)
	while not fake.pending_interstitial.is_empty():
		fake.complete_interstitial_load(false)
	mm._interstitial_attempts = MonetizationManager.INTERSTITIAL_MAX_ATTEMPTS
	mm._interstitial_last_attempt_msec = -100000
	mm._fullscreen_cooldown = MonetizationManager.FULLSCREEN_AD_COOLDOWN_SEC
	var iloads: int = fake.interstitial_loads
	counter = _Counter.new()
	var shown: bool = mm.try_show_interstitial("round_finish", counter.hit)
	_c("U9: uygun mola 'cooldown' ile atlandı, yükleme döngüsü tükenmişti: bir sonraki mola için yükleme tetiklendi",
		not shown and AdEvents.last(&"interstitial_skipped_not_ready").get("reason", "") == "cooldown"
		and fake.interstitial_loads == iloads + 1)
	await _free(mm)
	# U7: hazır reklamın süresi dolar (Google: bir saat) — ödüllü de; motor saati uykuda durur, duvar saati yakalar.
	await _boot()
	m = _main._ads
	var old: String = str(_field(m, "_ready_ad_id", ""))
	var limit_ms: int = int(float(_const(m, "REWARDED_MAX_AGE_SEC", 0.0)) * 1000.0)
	m.set("_rewarded_loaded_msec", Time.get_ticks_msec() - limit_ms - 100)
	_c("U7: ödüllü reklam motor saatine göre bir saati aştı: hazır DEĞİL (gösterilmez)", limit_ms > 0 and old != ""
		and not m.is_rewarded_ready())
	var rloads: int = _fake.rewarded_loads
	m._tick_active(0.1)
	_c("U7: aktif saat adımında süresi dolan ödüllü atıldı + tazeleniyor (eklentiden düştü, yeni yükleme)",
		_fake.rewarded_removed.has(old) and _fake.rewarded_loads == rloads + 1
		and m.rewarded_state() == MonetizationManager.RewardedState.LOADING)
	var fresh: String = _fake.complete_rewarded_load(true)
	await _settle(1)
	m.set("_rewarded_loaded_unix", Time.get_unix_time_from_system() - float(limit_ms) / 1000.0 - 100.0)
	_c("U7: duvar saatine göre (cihaz uykusu — motor saati durdu) süresi dolan ödüllü de hazır DEĞİL", fresh != ""
		and not m.is_rewarded_ready() and m.rewarded_note() == MonetizationManager.NOTE_PREPARING)
	board = await _start(3)
	rloads = _fake.rewarded_loads
	board._enter_fail_pending()
	await _settle(2)
	_main._revive.continue_button().pressed.emit()
	await _settle(1)
	_c("U7: devam CTA'sı süresi dolmuş reklamı GÖSTERMEDİ: talep yok, reklam atıldı, yeni yükleme, devam 0",
		not m.has_active_request() and _fake.rewarded_removed.has(fresh) and _fake.rewarded_loads == rloads + 1
		and board.revives_used() == 0 and _fake.rewarded_shows.size() == 0)
	_main.decline_revive()
	await _wait(_delay() + 0.1)
	await _settle(2)
	var inter: String = str(_field(m, "_interstitial_ready_id", ""))
	m.set("_interstitial_loaded_unix", Time.get_unix_time_from_system()
		- MonetizationManager.INTERSTITIAL_MAX_AGE_SEC * MonetizationManager.time_scale - 100.0)
	var iloads2: int = _fake.interstitial_loads
	_pause()
	_resume()
	await _settle(1)
	_c("U7: geçiş reklamı duvar saatine göre doldu: öne dönüşte atıldı + tazeleniyor", inter != ""
		and _fake.interstitial_removed.has(inter) and _fake.interstitial_loads == iloads2 + 1
		and m.interstitial_state() == MonetizationManager.InterstitialState.LOADING)
	# U8: kurtarılan "kapandı" eklenti nesnesini önbellekten düşürür (geçiş).
	m = await _stuck_break()
	var sid: String = m.interstitial_showing_id()
	await _wait(_lease_sec() + 0.1)
	await _settle(2)
	_c("U8: geçiş 'kapandı' kurtarması reklam nesnesini eklenti önbelleğinden düşürdü", sid != "" and not m.break_pending()
		and _fake.interstitial_removed.has(sid))
	# U11: kira YOKKEN RESUMED kayboldu: uygulamaya ulaşan yeni dokunuş öne dönüştür — banner, saat, doğal mola geri.
	# (Dokunuşlar board'a düşer: Ana Sayfa düğmelerine basıp yüzey değiştirmesin.)
	await _boot()
	m = _main._ads
	await _start(3)
	_c("U11 ön koşul: oyun yüzeyinde banner görünür", m.banner_state() == MonetizationManager.BannerState.SHOWN)
	_pause()
	await _press()
	_c("U11: duraklatıldı (RESUMED gelmeyecek), dışlama penceresindeki dokunuş: hâlâ duraklatılmış, banner gizli",
		bool(m.get("_app_paused")) and m.banner_state() == MonetizationManager.BannerState.LOADED)
	await _wait(_lease_sec() + 0.05)
	await _press()
	await _settle(1)
	_c("U11: dışlamadan sonra uygulamaya ulaşan yeni dokunuş: öne dönüş sayıldı — duraklatma düştü, banner yeniden "
		+ "görünür, aktif saat sayıyor, doğal mola 'app_paused' ile atlanmaz", not bool(m.get("_app_paused"))
		and m.banner_state() == MonetizationManager.BannerState.SHOWN and _clock_counts(m)
		and (int(m.call("input_resumes")) == 1 if m.has_method("input_resumes") else false))
	# U12: GL sırası (Compatibility oluşturucu): onPause → FOCUS_OUT + PAUSED; onResume → FOCUS_IN, RESUMED bir kare
	# sonra. Öne dönüş FOCUS_IN'de; ikinci RESUMED payı yeniden kurmaz — tek kurtarma, tek sonuç.
	m = await _stuck_break()
	seq = _main._result_seq
	_focus_out_pause()
	await _wait(_grace_sec() * 2.0)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await _settle(2)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)
	await _wait(_grace_sec() + 0.1)
	await _settle(2)
	_c("U12: GL sırası (FOCUS_IN, sonra RESUMED): TAM bir kurtarma (resume_grace), sonuç bir kez", not m.break_pending()
		and _main._result.visible and _shows == 1 and _main._result_seq == seq + 1 and _recoveries(m) == 1
		and str(AdEvents.last(&"interstitial_dismissed").get("recovered", "")) == "resume_grace")
	# U12b: masaüstü pencere odağı (FOCUS_OUT / FOCUS_IN, duraklatma YOK) hiç örtülmemiş ödüllü kirayı süreyle bırakmaz.
	fake = FakeAdBackend.new()
	mm = _manager(fake)
	stub = _StubMain.new()
	add_child(stub)
	fake.complete_rewarded_load(true)
	mm.show_rewarded_daily_dough(stub, THU, 21)
	var wid: String = mm.request_info()["ad_id"]
	fake.emit_rewarded_showed(wid)
	mm.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	mm.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await _wait(_grace_sec() * 3.0)
	_c("U12b: duraklatma olmadan odak çıkışı / girişi: 'gösterildi' demiş ödüllü talep süreyle bırakılmadı", wid != ""
		and mm.has_active_request() and _recoveries(mm) == 0 and stub.unavailable_daily.is_empty())
	stub.queue_free()
	await _free(mm)
	# U13: girdi kanıtıyla öne dönüş odak kaybını da kapatır (sonraki odaksız RESUMED / PAUSED doğru işlenir) ve süresi
	# dolmuş hazır reklamları tazeler.
	await _boot()
	m = _main._ads
	await _start(3)
	var stale: String = str(_field(m, "_ready_ad_id", ""))
	_focus_out_pause()
	m.set("_rewarded_loaded_unix", Time.get_unix_time_from_system() - float(_const(m, "REWARDED_MAX_AGE_SEC", 0.0))
		- 100.0)
	await _wait(_lease_sec() + 0.05)
	await _press()
	await _settle(1)
	_c("U13: RESUMED / FOCUS_IN kayıp, dokunuşla öne dönüş: duraklatma VE odak kaybı düştü, süresi dolan hazır ödüllü "
		+ "reklam atılıp tazeleniyor", not bool(m.get("_app_paused")) and not bool(_field(m, "_app_focus_lost", true))
		and stale != "" and _fake.rewarded_removed.has(stale)
		and m.rewarded_state() == MonetizationManager.RewardedState.LOADING)
	_pause()
	_resume()
	await _settle(1)
	_c("U13: sonraki odaksız PAUSED + RESUMED (Vulkan yüzey döngüsü) yine öne dönüş sayıldı: duraklatma düştü",
		not bool(m.get("_app_paused")) and m.banner_state() == MonetizationManager.BannerState.SHOWN)
	_sections_done += 1


# --- S) Kaynak sözleşmesi -------------------------------------------------------------------------------------

func _source_contract() -> void:
	print("-- S: kaynak sözleşmesi")
	var manager: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ads/monetization_manager.gd"))
	var main: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/main.gd"))
	var recover_fn: String = _function(manager, "func _recover_lease(")
	_c("kurtarma işlevinde ödül / gösterim / SDK çağrısı YOK (uygulama durumu bırakılır; eklenti önbelleğinden düşürme "
		+ "ortak kapanış yolunda)", recover_fn != ""
		and not recover_fn.contains("grant_") and not recover_fn.contains("_backend."))
	_c("kira zamanlayıcısı tek yerde kurulur (`_lease_arm`), jetona bağlı", manager.count("_on_lease_timeout.bind(") == 1
		and _function(manager, "func _lease_arm(").contains("_on_lease_timeout.bind(_lease_token)")
		and _function(manager, "func _on_lease_timeout(").contains("token != _lease_token"))
	_c("eski üç zamanlayıcı (onay / iki öne dönüş payı) kalktı; 900 sn sabiti yok", not manager.contains("_resume_grace_timer")
		and not manager.contains("_interstitial_confirm_timer") and not manager.contains("_interstitial_resume_timer")
		and not manager.contains("INTERSTITIAL_INTERVAL_SEC"))
	_c("girdi kanıtı olayı TÜKETMEZ", not _function(manager, "func _input(").contains("set_input_as_handled"))
	var finish_fn: String = _function(main, "func _on_round_finished(")
	var noted: int = finish_fn.find("_ads.note_normal_round_finalized()")
	_c("Main round'u TEK noktada bildirir: normal bitiş, `_round_finalized` korumasından sonra, gecikmeden ÖNCE; meydan "
		+ "okuma bitişi bildirmez", main.count("note_normal_round_finalized()") == 1 and noted > finish_fn.find("_round_finalized = true")
		and noted < finish_fn.find("await get_tree().create_timer(RESULT_DELAY).timeout")
		and not _function(main, "func _on_challenge_round_finished(").contains("_ads"))
	_c("geçiş reklamı tek çağrı noktası (Main round bitişi)", main.count("_ads.try_show_interstitial(") == 1)
	_sections_done += 1


# --- Yardımcılar ----------------------------------------------------------------------------------------------

func _lease_sec() -> float:
	return MonetizationManager.INTERSTITIAL_SHOW_CONFIRM_TIMEOUT * SCALE


func _grace_sec() -> float:
	return MonetizationManager.SHOW_RESUME_GRACE * SCALE


func _delay() -> float:
	return float(_main_script.get_script_constant_map()["RESULT_DELAY"])


## Yeni tanılama API'leri düzeltmesiz kodda yok: -1 / 0 / false (açık [FAIL], betik hatası değil).
func _rounds(m: MonetizationManager) -> int:
	return int(m.call("interstitial_rounds")) if m.has_method("interstitial_rounds") else -1


func _recoveries(m: MonetizationManager) -> int:
	return int(m.call("fullscreen_recoveries")) if m.has_method("fullscreen_recoveries") else 0


func _lease_active(m: MonetizationManager) -> bool:
	return bool(m.call("lease_active")) if m.has_method("lease_active") else false


## Zorunlu geçiş reklamının iki kapısı sağlanır (TASK/052 AdPolicy: aktif süre + kesinleşen normal round). Düzeltmesiz
## kodda eski tek kapı (900 sn) — temel karşılaştırma aynı senaryoyla koşsun.
func _gates(m: MonetizationManager) -> void:
	var consts: Dictionary = (m.get_script() as GDScript).get_script_constant_map()
	if consts.has("INTERSTITIAL_INTERVAL_SEC"):
		m._tick_active(float(consts["INTERSTITIAL_INTERVAL_SEC"]))
		return
	m._tick_active(AdPolicy.FORCED_INTERSTITIAL_MIN_INTERVAL_SEC)
	for i in AdPolicy.FORCED_INTERSTITIAL_MIN_ROUNDS:
		m.call("note_normal_round_finalized")


## Aktif süre saati şu an sayıyor mu (tam ekran / arka plan dışlaması bitti mi).
func _clock_counts(m: MonetizationManager) -> bool:
	var before: float = m.active_elapsed_sec()
	m._tick_active(1.0)
	return m.active_elapsed_sec() > before


## Takılı mola kurulumu: iki kapı, Level 3 kaybı, gecikme sonrası geçiş reklamı SDK'ya verildi + "gösterildi".
func _stuck_break() -> MonetizationManager:
	await _boot()
	var m: MonetizationManager = _main._ads
	_gates(m)
	var board: Node2D = await _start(3)
	await _finish(board)
	var id: String = await _break_request()
	if id != "":
		_fake.emit_interstitial_showed(id)
		await _settle(1)
	return m


## Bağımsız yönetici (Main'siz): rıza + SDK hazır, geçiş reklamı yüklü.
func _manager(fake: FakeAdBackend) -> MonetizationManager:
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	var m: MonetizationManager = MonetizationManager.create(fake, AdConfig.test_defaults())
	m.set_age_band(AgeGate.Band.ADULT)
	add_child(m)
	m.set_process(false)
	fake.complete_consent_update(true)
	fake.complete_init()
	fake.complete_interstitial_load(true)
	return m


func _free(m: MonetizationManager) -> void:
	if m != null and is_instance_valid(m):
		m.queue_free()
	await _settle(2)


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


## Temiz kayıt + Main + sahte SDK (rıza `consent`, init, banner / ödüllü / geçiş yüklü). `ready_ads` false: yalnız rıza
## güncellemesi tamamlanır (yaş / rıza bölümü).
func _boot(extra: Dictionary = {}, ready_ads: bool = true,
		consent: AdBackend.ConsentStatus = AdBackend.ConsentStatus.NOT_REQUIRED) -> void:
	await _teardown_main()
	_clean()
	DailyRewards.clock_override = THU
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(_fixture(extra), "\t"))
	file.close()
	SaveManager.load_game()
	_fake = FakeAdBackend.new()
	_fake.status = consent
	_main_script.set("ads_backend_override", _fake)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _settle(3)
	_main_script.set("ads_backend_override", null)
	_main._ads.set_process(false)
	_shows = 0
	_drops = 0
	_main._result.visibility_changed.connect(func() -> void:
		if _main != null and is_instance_valid(_main) and _main._result.visible:
			_shows += 1)
	AdEvents.clear_recent()
	if not ready_ads:
		return
	_fake.complete_consent_update(true)
	_fake.complete_init()
	await _settle(2)
	# Sınırlı döngüler: hatalı yönetici (ör. her eşitlemede yeniden yükleme) testi kilitlemesin, açık FAIL üretsin.
	for i in 4:
		if _fake.pending_banner.is_empty():
			break
		_fake.complete_banner_load(true)
	while not _fake.pending_interstitial.is_empty():
		_fake.complete_interstitial_load(true)
	while not _fake.pending_rewarded.is_empty():
		_fake.complete_rewarded_load(true)
	await _settle(2)


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _settle(3)


func _start(number: int) -> Node2D:
	var level: LevelData = null
	for candidate in LevelLibrary.load_levels():
		if candidate.level_number == number:
			level = candidate
	_main._start_level(level)
	await _settle(3)
	var board: Node2D = _main._board
	_track(board)
	return board


## (`board` Variant: serbest bırakılmış düğüm tipli parametreye verilemez — düzeltmesiz kodda eski board düşebilir.)
func _track(board: Variant) -> void:
	if board == null or not is_instance_valid(board) or board.has_meta(&"qa_tracked"):
		return
	board.set_meta(&"qa_tracked", true)
	board.dumpling_dropped.connect(func(_tier: int) -> void: _drops += 1)


## Kayıp (üretim yolu): devam teklifi → reddet → kesin kayıp.
func _finish(board: Node2D) -> void:
	board._enter_fail_pending()
	await _settle(2)
	_main.decline_revive()
	await _settle(1)


## Gecikme sonrası doğal molada geçiş reklamı SDK'ya verildiyse kimliği ("" = verilmedi).
func _break_request() -> String:
	var shows: int = _fake.interstitial_shows.size()
	await _wait(_delay() + 0.1)
	await _settle(1)
	return _fake.interstitial_shows[-1] if _fake.interstitial_shows.size() == shows + 1 else ""


## Gerçek merge ile hedef: sağ kenarda tabandaki (hedef − 1) tier parçasının üstüne aynısı düşer.
func _win_merge(board: Node2D) -> void:
	var tier: int = board.level.target_tier - 1
	var r: float = TierConfig.radius(tier)
	var x: float = board._right_x() - r - 12.0
	var floor_y: float = float(board.get_script().get_script_constant_map()["FLOOR_Y"])
	board._spawn_dumpling(tier, Vector2(x, floor_y - r - 1.0))
	board._spawn_dumpling(tier, Vector2(x, floor_y - 3.0 * r - 30.0))
	var guard: int = 0
	while not board.is_finished() and guard < 600:
		await get_tree().physics_frame
		guard += 1


func _pause() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)


func _resume() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)


## Uygulama penceresine yeni bir dokunuş (basış + bırakış) — board'un boş bir noktası.
func _press() -> void:
	var at: Vector2 = _screen(Vector2(360, 700))
	await _finger(at, true)
	await _finger(at, false)


func _back() -> void:
	var gap: int = _last_back_msec + BACK_GAP_MSEC - Time.get_ticks_msec()
	if gap > 0:
		await _wait(float(gap) / 1000.0)
	_last_back_msec = Time.get_ticks_msec()
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(1)


func _wait_settled() -> void:
	while Time.get_ticks_msec() < int(_main.get("_touch_settle_until")):
		await get_tree().process_frame
	await _settle(1)


func _drop_ok(board: Variant) -> bool:
	if board == null or not is_instance_valid(board):
		return false
	var before: int = _drops
	var at: Vector2 = _screen(board.world_to_screen(Vector2(board._center_x() - 90.0, board.overflow_line_y() + 60.0)))
	await _finger_tap(at)
	for i in 3:
		await get_tree().physics_frame
	return _drops == before + 1


func _finger(pos: Vector2, pressed: bool, index: int = 0) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = pos
	touch.pressed = pressed
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _finger_tap(pos: Vector2, index: int = 0) -> void:
	await _finger(pos, true, index)
	await _finger(pos, false, index)


func _screen(canvas: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * canvas


func _center(control: Control) -> Vector2:
	return _screen(control.get_global_rect().get_center())


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _strip_comments(src: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	for line in src.split("\n"):
		var at: int = line.find("#")
		out.append(line.substr(0, at) if at >= 0 else line)
	return "\n".join(out)


func _function(code: String, header: String) -> String:
	var start: int = code.find(header)
	if start < 0:
		return ""
	var end: int = code.find("\nfunc ", start + header.length())
	return code.substr(start, (end - start) if end >= 0 else -1)


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
