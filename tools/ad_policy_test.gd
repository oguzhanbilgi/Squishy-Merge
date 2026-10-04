extends Node
## TASK/052 — gelir odaklı zorunlu geçiş reklamı politikası (`AdPolicy`): önceki gerçek gösterimden bu yana en az 2
## KESİNLEŞEN NORMAL round VE 300 AKTİF sn; 60 sn tam ekran beklemesi; yalnız doğal mola (normal round bitişi →
## sonuçtan önce); tutorial ve meydan okuma dışarıda; hazır değilse sonuç beklemez. Gerçek Main + gerçek board + sahte
## SDK; yönetici düzeyi kontroller ayrıca. Headless.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: SaveManager `user://qa_ad_policy/` altına yönlendirilir, sonda geri alınır; sahibin
## kayıt ailesi başta / sonda bayt karşılaştırılır.
##
##   godot --headless --audio-driver Dummy --path . res://tools/ad_policy_test.tscn
##
## Bölümler:
##   P1  round kapısı      1. kesinleşen normal round → 0; 2. → yalnız süre kapısı da sağlanmışsa uygun
##   P2  süre kapısı       < 300 sn → yok; >= 300 sn + round kapısı → uygun
##   P3  gösterim sonrası  sayaç + saat sıfırlanır; tek round yetmez; iki kapı birlikte yeniden gerekir
##   P4  bekleme           ödüllü kapanışı geçişi bastırır (60 sn); geçiş açıkken başka tam ekran yok
##   P5  tutorial          tutorial + tutorial'dan doğan round reklamsız ve SAYILMAZ; sonra yetişme (catch-up) yok
##   P6  meydan okuma      uygun + hazırken bile round bitişi geçiş reklamı SIFIR (başarı ve kayıp)
##   P7  hazır değil       round normal biter, sonuç RESULT_DELAY dışında beklemez, uygunluk sonraki molaya kalır
##   P8  app-open          UYGULANMADI (N/A) — kaynakta app-open yolu yok
##   P9  ödüllü kotalar    değişmedi: devam 2/round · refill 1/gün · reklamlı sandık 2/gün · +150 Hamur 1/gün
##   P10 banner            tek AdView; izinli / yasak yüzeyler; arka plan duraklatır, öne dönüş tek gösterim
##   P11 tek kaynak        sayılar yalnız AdPolicy'de; yöneticide 900 sn / sabit sayı yok
##   P12 envanter          8 × 150 sn oturum: gösterimler 2., 4., 6., 8. round; aralar >= 2 round ve >= 300 sn

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_ad_policy"
const PATH: String = DIR + "/save.json"
const SECTIONS: int = 12
const MON: String = "2026-09-28"
const THU: String = "2026-10-01"
const SCALE: float = 0.05

var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _finished: bool = false
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _main: Node2D
var _main_script: GDScript
var _fake: FakeAdBackend
var _shows: int = 0


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

	await _rounds_gate()
	await _time_gate()
	await _after_show()
	await _cooldown()
	await _tutorial()
	await _challenge()
	await _no_ready()
	_app_open()
	_rewarded_caps()
	await _banner()
	_single_source()
	await _inventory()
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


# --- P1) Round kapısı -----------------------------------------------------------------------------------------

func _rounds_gate() -> void:
	print("-- P1: round kapısı (en az 2 kesinleşen normal round)")
	var fake := FakeAdBackend.new()
	var m: MonetizationManager = _manager(fake)
	m._tick_active(AdPolicy.FORCED_INTERSTITIAL_MIN_INTERVAL_SEC + 100.0)
	_c("P1: 400 sn aktif ama 0 round: uygun DEĞİL, mola gösterimi yok (not_eligible)", not m.interstitial_eligible()
		and not m.try_show_interstitial("round_finish", func() -> void: pass)
		and AdEvents.last(&"interstitial_skipped_not_ready").get("reason", "") == "not_eligible")
	m.note_normal_round_finalized()
	_c("P1: 1 round + 400 sn: uygun DEĞİL", not m.interstitial_eligible() and m.interstitial_rounds() == 1)
	m.note_normal_round_finalized()
	_c("P1: 2 round + 400 sn: uygun, olay interstitial_eligible {rounds 2}", m.interstitial_eligible()
		and int(AdEvents.last(&"interstitial_eligible").get("rounds", -1)) == 2)
	await _free(m)
	# Main: gerçek round kesinleşmeleri sayılır.
	await _boot()
	var ads: MonetizationManager = _main._ads
	ads._tick_active(AdPolicy.FORCED_INTERSTITIAL_MIN_INTERVAL_SEC)
	var outcome: Dictionary = await _play_round()
	_c("P1/Main: süre kapısı sağlanmış, İLK kesinleşen normal round: geçiş reklamı YOK, sonuç hemen, round sayacı 1",
		not outcome["shown"] and outcome["result"] and ads.interstitial_rounds() == 1
		and outcome["reason"] == "not_eligible")
	outcome = await _play_round()
	_c("P1/Main: İKİNCİ kesinleşen normal round (300 sn sağlanmış): geçiş reklamı istendi, kapanınca sonuç tam bir kez",
		outcome["shown"] and outcome["result"] and _shows == 2)
	_sections_done += 1


# --- P2) Süre kapısı ------------------------------------------------------------------------------------------

func _time_gate() -> void:
	print("-- P2: süre kapısı (en az 300 aktif sn)")
	var fake := FakeAdBackend.new()
	var m: MonetizationManager = _manager(fake)
	_note_rounds(m)
	m._tick_active(AdPolicy.FORCED_INTERSTITIAL_MIN_INTERVAL_SEC - 1.0)
	_c("P2: 2 round + 299 sn: uygun DEĞİL", not m.interstitial_eligible())
	m._tick_active(1.0)
	_c("P2: 2 round + 300 sn: uygun", m.interstitial_eligible())
	await _free(m)
	await _boot()
	var ads: MonetizationManager = _main._ads
	ads._tick_active(AdPolicy.FORCED_INTERSTITIAL_MIN_INTERVAL_SEC - 1.0)
	await _play_round()
	var outcome: Dictionary = await _play_round()
	_c("P2/Main: 2 kesinleşen round ama 299 sn: geçiş reklamı YOK (not_eligible), sonuç hemen", not outcome["shown"]
		and outcome["result"] and outcome["reason"] == "not_eligible" and ads.interstitial_rounds() == 2)
	ads._tick_active(1.0)
	_c("P2/Main: +1 sn → iki kapı sağlandı (uygun), oyun ortasında kendiliğinden gösterim YOK", ads.interstitial_eligible()
		and _fake.interstitial_shows.is_empty())
	outcome = await _play_round()
	_c("P2/Main: sonraki doğal molada geçiş reklamı istendi", outcome["shown"])
	_sections_done += 1


# --- P3) Gösterimden sonra -------------------------------------------------------------------------------------

func _after_show() -> void:
	print("-- P3: gerçek gösterimden sonra sayaçlar sıfırlanır, iki kapı birlikte yeniden gerekir")
	var fake := FakeAdBackend.new()
	var m: MonetizationManager = _manager(fake)
	_note_rounds(m, 3)
	m._tick_active(AdPolicy.FORCED_INTERSTITIAL_MIN_INTERVAL_SEC + 50.0)
	var id: String = fake.interstitial_shows[-1] if m.try_show_interstitial("round_finish", func() -> void: pass) \
		and not fake.interstitial_shows.is_empty() else ""
	fake.emit_interstitial_showed(id)
	_c("P3: SDK 'gösterildi' → round 0, saat 0, uygun değil", id != "" and m.interstitial_rounds() == 0
		and m.active_elapsed_sec() == 0.0 and not m.interstitial_eligible())
	fake.emit_interstitial_dismissed(id)
	fake.complete_interstitial_load(true)
	m._tick_active(AdPolicy.FORCED_INTERSTITIAL_MIN_INTERVAL_SEC + 60.0)
	m.note_normal_round_finalized()
	_c("P3: sonraki TEK round (+360 sn, bekleme bitti): uygun DEĞİL — tek round yetmez", not m.interstitial_eligible()
		and not m.try_show_interstitial("round_finish", func() -> void: pass)
		and AdEvents.last(&"interstitial_skipped_not_ready").get("reason", "") == "not_eligible")
	m.note_normal_round_finalized()
	_c("P3: ikinci round → iki kapı birlikte sağlandı: uygun", m.interstitial_eligible())
	await _free(m)
	# Round'lar tamam ama süre yok.
	fake = FakeAdBackend.new()
	m = _manager(fake)
	_note_rounds(m)
	m._tick_active(AdPolicy.FORCED_INTERSTITIAL_MIN_INTERVAL_SEC)
	m.try_show_interstitial("round_finish", func() -> void: pass)
	id = fake.interstitial_shows[-1]
	fake.emit_interstitial_showed(id)
	fake.emit_interstitial_dismissed(id)
	fake.complete_interstitial_load(true)
	_note_rounds(m, 4)
	m._tick_active(AdPolicy.FORCED_INTERSTITIAL_MIN_INTERVAL_SEC - 1.0)
	_c("P3: gösterimden sonra 4 round ama 299 sn: uygun DEĞİL", not m.interstitial_eligible()
		and m.interstitial_rounds() == 4)
	await _free(m)
	_sections_done += 1


# --- P4) Tam ekran beklemesi ----------------------------------------------------------------------------------

class _StubMain extends Node:
	var unavailable: Array[String] = []
	func notify_rewarded_unavailable(message: String) -> void:
		unavailable.append(message)
	func grant_revive() -> bool:
		return true


func _cooldown() -> void:
	print("-- P4: tam ekran beklemesi — ödüllü ↔ geçiş yığılmaz")
	var fake := FakeAdBackend.new()
	var m: MonetizationManager = _manager(fake)
	var stub := _StubMain.new()
	add_child(stub)
	_gates(m)
	var r1: String = fake.complete_rewarded_load(true)
	m.show_rewarded_revive(stub)
	_c("P4: ödüllü talep açıkken doğal mola: geçiş YOK (rewarded_active)", not m.try_show_interstitial("round_finish",
		func() -> void: pass) and AdEvents.last(&"interstitial_skipped_not_ready").get("reason", "") == "rewarded_active")
	fake.emit_rewarded_showed(r1)
	fake.emit_rewarded_earned(r1)
	fake.emit_rewarded_dismissed(r1)
	_c("P4: ödüllü kapandı → 60 sn bekleme: iki kapı sağlı olsa da geçiş YOK (cooldown)", m.interstitial_eligible()
		and not m.try_show_interstitial("round_finish", func() -> void: pass)
		and AdEvents.last(&"interstitial_skipped_not_ready").get("reason", "") == "cooldown")
	m._tick_active(AdPolicy.FULLSCREEN_AD_COOLDOWN_SEC - 1.0)
	_c("P4: 59 sn sonra hâlâ bekleme", not m.try_show_interstitial("round_finish", func() -> void: pass))
	m._tick_active(1.0)
	_c("P4: 60 sn sonra geçiş gösterildi", m.try_show_interstitial("round_finish", func() -> void: pass)
		and fake.interstitial_shows.size() == 1)
	var r2: String = fake.complete_rewarded_load(true)
	m.show_rewarded_revive(stub)
	_c("P4: geçiş molası sürerken ödüllü gösterim gönderilmez ('Reklam gösteriliyor…'), tam ekran aktif", r2 != ""
		and fake.rewarded_shows == [r1] and stub.unavailable[-1] == MonetizationManager.NOTE_SHOWING
		and m.fullscreen_ad_active())
	var id: String = fake.interstitial_shows[-1]
	fake.emit_interstitial_showed(id)
	fake.emit_interstitial_dismissed(id)
	fake.complete_interstitial_load(true)
	_note_rounds(m, 4)
	m._tick_active(AdPolicy.FULLSCREEN_AD_COOLDOWN_SEC - 1.0)
	_c("P4: geçiş kapandı → 60 sn bekleme + sıfırlanmış kapılar: 59 sn sonra (4 round olsa da) art arda geçiş YOK",
		m.fullscreen_cooldown_sec() > 0.0 and not m.interstitial_eligible()
		and not m.try_show_interstitial("round_finish", func() -> void: pass))
	stub.queue_free()
	await _free(m)
	# Ödüllü kapanışının hemen ardından round bitişi (Main).
	await _boot()
	var ads: MonetizationManager = _main._ads
	_gates(ads)
	_main._start_level(_level(3))
	await _settle(3)
	var board: Node2D = _main._board
	board._enter_fail_pending()
	await _settle(2)
	_main._revive.continue_button().pressed.emit()
	await _settle(1)
	var rid: String = ads.request_info()["ad_id"]
	_fake.emit_rewarded_showed(rid)
	_fake.emit_rewarded_earned(rid)
	_fake.emit_rewarded_dismissed(rid)
	await _settle(2)
	var outcome: Dictionary = await _finish_round(board)
	_c("P4/Main: ödüllü devamın hemen ardından round bitti → geçiş ATLANDI (cooldown), sonuç hemen, uygunluk kaldı",
		not outcome["shown"] and outcome["result"] and outcome["reason"] == "cooldown" and ads.interstitial_eligible())
	_sections_done += 1


# --- P5) Tutorial -----------------------------------------------------------------------------------------------

func _tutorial() -> void:
	print("-- P5: ilk tutorial akışı reklamsız; ardından yetişme (catch-up) yok")
	await _boot({"onboarding_completed": false}, true)
	var ads: MonetizationManager = _main._ads
	var tutorial: TutorialController = _main._tutorial
	_c("P5 ön koşul: taze kurulum — tutorial gerçek Level 1'de açık, yönetici onboarding false", tutorial.is_active()
		and not ads.onboarding_completed())
	ads._tick_active(2000.0)
	ads.note_normal_round_finalized()
	_c("P5: tutorial sürerken süre ve round SAYILMAZ", ads.active_elapsed_sec() == 0.0 and ads.interstitial_rounds() == 0)
	tutorial.skip()
	await _settle(2)
	_c("P5: tutorial atlandı (kayıt tamam) ama round sürüyor: monetizasyon ERTELENDİ (yönetici false)",
		SaveManager.onboarding_completed() and not ads.onboarding_completed())
	var outcome: Dictionary = await _finish_round(_main._board)
	_c("P5: tutorial'dan doğan Level 1 bitti: geçiş reklamı YOK, round SAYILMADI, sonuç açıldı", not outcome["shown"]
		and outcome["result"] and ads.interstitial_rounds() == 0)
	_main._start_level(_level(3))
	await _settle(3)
	await _ready_ads()
	_c("P5: güvenli round sınırında monetizasyon açıldı", ads.onboarding_completed() and ads.sdk_ready())
	ads._tick_active(2000.0)
	outcome = await _finish_round(_main._board)
	_c("P5: açılıştan sonraki İLK normal round (+2000 sn): geçiş reklamı YOK — tutorial'dan yetişme yok (not_eligible)",
		not outcome["shown"] and outcome["reason"] == "not_eligible" and ads.interstitial_rounds() == 1)
	_main._start_level(_level(3))
	await _settle(3)
	outcome = await _finish_round(_main._board)
	_c("P5: ikinci normal round → ilk zorunlu geçiş reklamı", outcome["shown"])
	_sections_done += 1


# --- P6) Meydan okuma -----------------------------------------------------------------------------------------

func _challenge() -> void:
	print("-- P6: meydan okuma — uygun + hazırken bile round bitişi geçiş reklamı SIFIR")
	await _boot()
	var ads: MonetizationManager = _main._ads
	_gates(ads)
	var rounds: int = ads.interstitial_rounds()
	for won: bool in [false, true]:
		AdEvents.clear_recent()
		var shows: int = _fake.interstitial_shows.size()
		if not _main.start_daily_challenge():
			_c("P6 ön koşul: meydan okuma başladı (%s)" % ("başarı" if won else "kayıp"), false)
			continue
		await _settle(3)
		var board: Node2D = _main._board
		if won:
			await _win_merge(board)
		else:
			board._enter_fail_pending()
			await _settle(2)
		await _wait(_delay() + 0.15)
		await _settle(2)
		_c("P6: meydan okuma %s (reklam UYGUN + HAZIR): geçiş denemesi / olayı SIFIR, round sayacı değişmedi, sonucu açıldı"
			% ("başarısı" if won else "kaybı"), ads.interstitial_eligible() and ads.is_interstitial_ready()
			and _fake.interstitial_shows.size() == shows and AdEvents.count(&"interstitial_skipped_not_ready") == 0
			and ads.interstitial_rounds() == rounds and _main._result.visible)
	_sections_done += 1


# --- P7) Reklam hazır değil -------------------------------------------------------------------------------------

func _no_ready() -> void:
	print("-- P7: reklam hazır değil — sonuç beklemez, uygunluk sonraki molaya kalır")
	await _boot({}, false)
	var ads: MonetizationManager = _main._ads
	_fake.complete_consent_update(true)
	_fake.complete_init()
	await _settle(2)
	_gates(ads)
	_c("P7 ön koşul: iki kapı sağlı, geçiş reklamı YÜKLENİYOR (hazır değil)", ads.interstitial_eligible()
		and ads.interstitial_state() == MonetizationManager.InterstitialState.LOADING)
	_main._start_level(_level(3))
	await _settle(3)
	var board: Node2D = _main._board
	board._enter_fail_pending()
	await _settle(2)
	var t0: int = Time.get_ticks_msec()
	_main.decline_revive()
	while not _main._result.visible and Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
	var took: int = Time.get_ticks_msec() - t0
	_c("P7: round normal bitti, sonuç RESULT_DELAY sonrası HEMEN (%d ms ≈ %d ms) — reklam beklenmedi, gösterim yok, "
		% [took, int(_delay() * 1000.0)] + "sebep not_ready, uygunluk kaldı", _main._result.visible
		and took < int(_delay() * 1000.0) + 400 and _fake.interstitial_shows.is_empty()
		and AdEvents.last(&"interstitial_skipped_not_ready").get("reason", "") == "not_ready" and ads.interstitial_eligible())
	_fake.complete_interstitial_load(true)
	# Uygulama ön planda değilken (başka bir etkinlik örtüyor: arama ekranı vb.) doğal mola gelirse geçiş denenmez.
	_main._start_level(_level(3))
	await _settle(3)
	board = _main._board
	board._enter_fail_pending()
	await _settle(2)
	_main.decline_revive()
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)
	await _wait(_delay() + 0.12)
	await _settle(2)
	_c("P7: doğal mola uygulama DURAKLATILMIŞKEN geldi: geçiş denenmedi (app_paused), sonuç açıldı, uygunluk + reklam kaldı",
		_fake.interstitial_shows.is_empty() and _main._result.visible and ads.interstitial_eligible()
		and ads.interstitial_state() == MonetizationManager.InterstitialState.READY
		and AdEvents.last(&"interstitial_skipped_not_ready").get("reason", "") == "app_paused")
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)
	await _settle(2)
	var outcome: Dictionary = await _play_round()
	_c("P7: öne dönüşten sonra sonraki doğal molada gösterildi", outcome["shown"])
	# UMP gizlilik seçenekleri formu (Ayarlar'dan) açıkken doğal mola gelirse geçiş formun üstüne açılmaz (TASK/052
	# inceleme L4-03): sonuç hemen, uygunluk + reklam kalır; form kapanınca sonraki molada gösterilir.
	_gates(ads)
	ads.set("_privacy_options_required", true)
	var opened: bool = ads.show_privacy_options()
	outcome = await _play_round()
	_c("P7: gizlilik formu açıkken doğal mola: geçiş denenmedi (consent_form), sonuç açıldı, uygunluk + reklam kaldı",
		opened and ads.consent_form_covering() and not outcome["shown"] and outcome["result"]
		and outcome["reason"] == "consent_form" and ads.interstitial_eligible()
		and ads.interstitial_state() == MonetizationManager.InterstitialState.READY)
	_fake.dismiss_privacy_form()
	await _settle(2)
	outcome = await _play_round()
	_c("P7: form kapandıktan sonra sonraki doğal molada gösterildi", not ads.consent_form_covering() and outcome["shown"])
	_sections_done += 1


# --- P8) App-open -----------------------------------------------------------------------------------------------

func _app_open() -> void:
	print("-- P8: app-open reklamı UYGULANMADI (N/A — ADS_SYSTEM §18.4)")
	var found: Array[String] = []
	var scripts: Array[String] = _scripts_under("res://scripts")
	_c("P8 ön koşul: üretim betiklerinin hepsi tarandı (%d dosya, yönetici + Main dahil)" % scripts.size(),
		scripts.size() > 20 and scripts.has("res://scripts/ads/monetization_manager.gd")
		and scripts.has("res://scripts/main.gd"))
	for path: String in scripts:
		var code: String = _strip_comments(FileAccess.get_file_as_string(path))
		for token: String in ["app_open", "load_app_open_ad", "show_app_open_ad", "auto_show_on_resume"]:
			if code.contains(token):
				found.append("%s:%s" % [path.get_file(), token])
	_c("P8: üretim kodunda app-open yolu YOK (yükleme / gösterim / öne dönüşte otomatik gösterim) %s" % str(found),
		found.is_empty())
	_sections_done += 1


## `root` altındaki her .gd (özyinelemeli) — P8 app-open taraması tek bir dosya listesine bağlı kalmasın.
func _scripts_under(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			out.append(root.path_join(file))
	for sub: String in dir.get_directories():
		out.append_array(_scripts_under(root.path_join(sub)))
	return out


# --- P9) Ödüllü kotalar -----------------------------------------------------------------------------------------

func _rewarded_caps() -> void:
	print("-- P9: ödüllü kotalar TASK/052'de DEĞİŞMEDİ (tek kaynaklarından okunur)")
	var caps: Dictionary = AdPolicy.rewarded_caps()
	_c("P9: devam 2 / round, güç refill'i 1 / gün (dört gücün toplamı), reklamlı sandık 2 / gün, reklamlı +150 Hamur 1 / gün",
		caps == {"revive_per_round": 2, "power_refill_per_day": 1, "ad_chest_per_day": 2, "ad_dough_per_day": 1,
		"ad_dough_amount": 150})
	_c("P9: kotalar tek kaynaklarıyla aynı (kopya sayı yok)", caps["power_refill_per_day"] == RewardedPolicy.DAILY_POWER_REFILLS
		and caps["ad_chest_per_day"] == DailyRewards.AD_CHESTS_PER_DAY and caps["ad_dough_per_day"] == DailyRewards.AD_DOUGH_PER_DAY
		and not FileAccess.get_file_as_string("res://scripts/ads/ad_policy.gd").contains("revive_per_round\": 2"))
	_sections_done += 1


# --- P10) Banner -------------------------------------------------------------------------------------------------

func _banner() -> void:
	print("-- P10: banner — tek AdView, izinli / yasak yüzeyler, yaşam döngüsü")
	await _boot()
	var ads: MonetizationManager = _main._ads
	var loads: int = _fake.banner_loads
	var hides: int = _fake.banner_hides.size()
	for tab in [1, 2, 3, 0]:
		_main._show_tab(tab)
		await _settle(1)
	_c("P10: Ana Sayfa / Harita / Koleksiyon / Mağaza gezinmesi: banner gösteriliyor, yeni yükleme / gizleme yok (tek AdView)",
		ads.banner_state() == MonetizationManager.BannerState.SHOWN and _fake.banner_loads == loads
		and _fake.banner_hides.size() == hides)
	_main._show_tab(4)
	await _settle(1)
	_c("P10: Profil banner yüzeyi DEĞİL → gizlendi (yuva korunur)", ads.surface() == MonetizationManager.Surface.NONE
		and ads.banner_state() == MonetizationManager.BannerState.LOADED and UiKit.banner_slot() > 0.0)
	_main._show_tab(0)
	await _settle(1)
	_main._start_level(_level(3))
	await _settle(3)
	_c("P10: oyun ekranı banner yüzeyi", ads.surface() == MonetizationManager.Surface.GAMEPLAY
		and ads.banner_state() == MonetizationManager.BannerState.SHOWN)
	await _finish_round(_main._board)
	_c("P10: sonuç ekranında banner GİZLİ", ads.surface() == MonetizationManager.Surface.RESULT
		and ads.banner_state() == MonetizationManager.BannerState.LOADED)
	_main._result.hide_result()
	_main._show_tab(0)
	await _settle(1)
	var shows: int = _fake.banner_shows.size()
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)
	await _settle(1)
	_c("P10: arka plan → banner gizlendi (eklenti: GONE + adView.pause)", ads.banner_state() == MonetizationManager.BannerState.LOADED)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)
	await _settle(1)
	_c("P10: öne dönüş → aynı banner TEK kez yeniden gösterildi; tüm akış boyunca tek yükleme",
		ads.banner_state() == MonetizationManager.BannerState.SHOWN and _fake.banner_shows.size() == shows + 1
		and _fake.banner_loads == loads)
	_c("P10: yüzey listesi: Ana Sayfa / Harita / Mağaza / Koleksiyon / oyun; sonuç ve Profil dışarıda",
		MonetizationManager.BANNER_SURFACES.size() == 5 and not MonetizationManager.BANNER_SURFACES.has(
		MonetizationManager.Surface.RESULT) and not MonetizationManager.BANNER_SURFACES.has(MonetizationManager.Surface.NONE))
	_sections_done += 1


# --- P11) Tek kaynak ---------------------------------------------------------------------------------------------

func _single_source() -> void:
	print("-- P11: politika sayıları tek yerde (AdPolicy)")
	var manager: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ads/monetization_manager.gd"))
	var update_fn: String = _function(manager, "func _update_interstitial_eligibility(")
	_c("P11: AdPolicy: 2 round, 300 sn, 60 sn bekleme", AdPolicy.FORCED_INTERSTITIAL_MIN_ROUNDS == 2
		and AdPolicy.FORCED_INTERSTITIAL_MIN_INTERVAL_SEC == 300.0 and AdPolicy.FULLSCREEN_AD_COOLDOWN_SEC == 60.0)
	_c("P11: yönetici uygunluğu AdPolicy'den alır; 900 sn sabiti yok; bekleme sabiti AdPolicy'ye bağlı",
		update_fn.contains("AdPolicy.forced_interstitial_gates_met(_active_elapsed, _interstitial_rounds)")
		and not manager.contains("INTERSTITIAL_INTERVAL_SEC") and not manager.contains("900.0")
		and manager.contains("FULLSCREEN_AD_COOLDOWN_SEC: float = AdPolicy.FULLSCREEN_AD_COOLDOWN_SEC")
		and MonetizationManager.FULLSCREEN_AD_COOLDOWN_SEC == AdPolicy.FULLSCREEN_AD_COOLDOWN_SEC)
	_c("P11: round sayacı yalnız Main'in normal bitişinden ve yalnız monetizasyon açıkken (AdPolicy.round_counts)",
		_function(manager, "func note_normal_round_finalized(").contains("AdPolicy.round_counts(false, _monetization_active())")
		and AdPolicy.round_counts(false, true) and not AdPolicy.round_counts(true, true) and not AdPolicy.round_counts(false, false))
	_sections_done += 1


# --- P12) Envanter özellikleri -----------------------------------------------------------------------------------

func _inventory() -> void:
	print("-- P12: 20 dk / 8 round (150 sn) oturumu — gösterim aralıkları")
	await _boot()
	var ads: MonetizationManager = _main._ads
	var shown_rounds: Array[int] = []
	var active_at_show: Array[float] = []
	var total: float = 0.0
	for i in 8:
		ads._tick_active(150.0)
		total += 150.0
		var outcome: Dictionary = await _play_round()
		if outcome["shown"]:
			shown_rounds.append(i + 1)
			active_at_show.append(total)
	var spaced: bool = true
	for j in range(1, shown_rounds.size()):
		spaced = spaced and shown_rounds[j] - shown_rounds[j - 1] >= AdPolicy.FORCED_INTERSTITIAL_MIN_ROUNDS \
			and active_at_show[j] - active_at_show[j - 1] >= AdPolicy.FORCED_INTERSTITIAL_MIN_INTERVAL_SEC
	_c("P12: gösterimler 2., 4., 6., 8. round'da (%s); ilk round'da yok; her ara >= 2 round ve >= 300 aktif sn" % str(
		shown_rounds), shown_rounds == [2, 4, 6, 8] and spaced)
	_sections_done += 1


# --- Yardımcılar ----------------------------------------------------------------------------------------------

func _note_rounds(m: MonetizationManager, count: int = AdPolicy.FORCED_INTERSTITIAL_MIN_ROUNDS) -> void:
	for i in count:
		m.note_normal_round_finalized()


func _gates(m: MonetizationManager) -> void:
	_note_rounds(m)
	m._tick_active(AdPolicy.FORCED_INTERSTITIAL_MIN_INTERVAL_SEC)


func _manager(fake: FakeAdBackend) -> MonetizationManager:
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	var m: MonetizationManager = MonetizationManager.create(fake, AdConfig.test_defaults())
	m.set_age_band(AgeGate.Band.ADULT)
	add_child(m)
	m.set_process(false)
	fake.complete_consent_update(true)
	fake.complete_init()
	fake.complete_interstitial_load(true)
	AdEvents.clear_recent()
	return m


func _free(m: MonetizationManager) -> void:
	if m != null and is_instance_valid(m):
		m.queue_free()
	await _settle(2)


## Normal round: Level 3 başlar ve kayıpla kesinleşir; gösterim olursa SDK "gösterildi" + kapanış.
func _play_round() -> Dictionary:
	_main._start_level(_level(3))
	await _settle(3)
	return await _finish_round(_main._board)


func _finish_round(board: Node2D) -> Dictionary:
	var before: int = _fake.interstitial_shows.size()
	var skips: int = AdEvents.count(&"interstitial_skipped_not_ready")
	board._enter_fail_pending()
	await _settle(2)
	_main.decline_revive()
	await _wait(_delay() + 0.12)
	await _settle(2)
	var shown: bool = _fake.interstitial_shows.size() == before + 1
	if shown:
		var id: String = _fake.interstitial_shows[-1]
		_fake.emit_interstitial_showed(id)
		_fake.emit_interstitial_dismissed(id)
		await _settle(3)
		while not _fake.pending_interstitial.is_empty():
			_fake.complete_interstitial_load(true)
		await _settle(1)
	var reason: String = ""
	if AdEvents.count(&"interstitial_skipped_not_ready") > skips:
		reason = str(AdEvents.last(&"interstitial_skipped_not_ready").get("reason", ""))
	return {"shown": shown, "result": _main._result.visible, "reason": reason}


func _ready_ads() -> void:
	var ads: MonetizationManager = _main._ads
	if ads.ads_state() == MonetizationManager.AdsState.CONSENT_CHECKING:
		_fake.complete_consent_update(true)
		await _settle(1)
	if not ads.sdk_ready():
		_fake.complete_init()
		await _settle(1)
	while not _fake.pending_interstitial.is_empty():
		_fake.complete_interstitial_load(true)
	while not _fake.pending_rewarded.is_empty():
		_fake.complete_rewarded_load(true)
	# Sınırlı döngü: hatalı yönetici (ör. her eşitlemede yeniden yükleme) testi kilitlemesin, açık FAIL üretsin (P10).
	for i in 4:
		if _fake.pending_banner.is_empty():
			break
		_fake.complete_banner_load(true)
	await _settle(1)


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


## Temiz kayıt + Main + sahte SDK. `ready_ads` true: rıza + init + yüklemeler tamam (taze kurulumda monetizasyon
## kapalı olduğu için yalnız ne sunulduysa).
func _boot(extra: Dictionary = {}, ready_ads: bool = true) -> void:
	await _teardown_main()
	_clean()
	DailyRewards.clock_override = THU
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(_fixture(extra), "\t"))
	file.close()
	SaveManager.load_game()
	_fake = FakeAdBackend.new()
	_fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	_main_script.set("ads_backend_override", _fake)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _settle(3)
	_main_script.set("ads_backend_override", null)
	_main._ads.set_process(false)
	_shows = 0
	_main._result.visibility_changed.connect(func() -> void:
		if _main != null and is_instance_valid(_main) and _main._result.visible:
			_shows += 1)
	AdEvents.clear_recent()
	if not ready_ads:
		return
	if _main._ads.onboarding_completed():
		await _ready_ads()


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _settle(3)


func _level(number: int) -> LevelData:
	for level in LevelLibrary.load_levels():
		if level.level_number == number:
			return level
	return null


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


func _delay() -> float:
	return float(_main_script.get_script_constant_map()["RESULT_DELAY"])


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
