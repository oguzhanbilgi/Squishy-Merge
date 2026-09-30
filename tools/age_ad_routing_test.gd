extends Node
## TASK/043 — yaş bandı reklam yönlendirmesi deterministik testi (İNTERNET, CİHAZ, EKLENTİ
## YOK; `FakeAdBackend` SDK'yı taklit eder, saat `AgeGate.clock_override` /
## `DailyRewards.clock_override` ile enjekte). docs/monetization/AGE_BAND_ROUTING.md.
##
##   YÖNETİCİ   UNKNOWN / UNDER_13: eklenti (attach), UMP, SDK, yükleme, yuva, saat YOK;
##              TEEN -> TEEN + T, ADULT -> UNSPECIFIED + MA: rota attach'ten ve rızadan ÖNCE,
##              yapılandırma + geri okuma initialize'dan ÖNCE; UMP matrisi (TEEN / ADULT ×
##              EEA / NOT_EEA); canRequestAds kapısı korunuyor; bant değişimi (SDK öncesi ->
##              uygulanır; SDK sonrası -> oturum reklamsız, işlem DEĞİŞMEZ, sonraki soğuk açılış);
##              geri okuma uyuşmazlığında fail-closed
##   MAIN       eski kayıt UNKNOWN: Ana Sayfa'da zorunlu yaş ekranı, günlük pencere ve rıza
##              bekler, Android geri UYGULAMADAN ÇIKMAZ (TASK/046.1); ilk açılış: tutorial +
##              tutorial round'u reklamsız, İLK güvenli kabukta yaş ekranı; ESKİ UNDER_13 kaydı
##              (TASK/046.1): kısıt ekranı YOK, yaş yeniden sorulur, SDK / UMP yok, TEEN / ADULT'a
##              çevrilmez (13. yaş gününde bile), kayıt UNKNOWN + tarih boş, ilerleme duruyor;
##              soğuk açılış geçişleri (tam
##              18. yaş günü -> ADULT, bir gün önce TEEN); Ayarlar → Yaş bilgisi (yeniden giriş:
##              aynı bant / farklı bant SDK öncesi / sonrası; panel açıkken banner YOK, kapanınca
##              geri; 13 altı yıl ızgarada YOK); günlük pencere sırası; geçiş reklamı yaş
##              bilinmeden yok; kayıtta ham doğum tarihi YOK
##
## Kayda yazar — başta yedekler, sonda byte-identical geri koyar.
##
##   godot --headless --audio-driver Dummy --path . res://tools/age_ad_routing_test.tscn

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const LEVEL_10: String = "res://resources/levels/level_10.tres"
const TODAY: String = "2026-10-01"

var _fails: int = 0
var _checks: int = 0
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _saved: Dictionary = {}
var _main_script: GDScript = load("res://scripts/main.gd")
var _main: Node2D = null


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	await get_tree().process_frame
	# Önceki koşu yarıda kesildiyse (zaman aşımı / kill) yedeği ÖNCE geri koy.
	_recover_sidecar()
	_saved = SaveManager.data.duplicate(true)
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
		_write_sidecar(_save_bytes)
	get_window().size = Vector2i(720, 1280)
	MonetizationManager.time_scale = 0.05
	TutorialController.time_scale = 0.05
	AgeGate.clock_override = TODAY
	DailyRewards.clock_override = TODAY
	DailyRewards.auto_popup_enabled = false
	_main_script.set("quit_suppressed", true)

	await _test_manager_closed_bands()
	await _test_manager_routes_and_order()
	await _test_ump_matrix()
	await _test_band_changes()
	await _test_read_back_fail_closed()
	await _test_consent_in_flight_block()
	await _test_main_legacy_unknown()
	await _test_main_first_run()
	await _test_main_legacy_under_13()
	await _test_main_launch_transitions()
	await _test_main_broken_clock()
	await _test_main_settings_reentry()
	await _test_main_interstitial_and_desktop()

	await _teardown_main()
	_main_script.set("quit_suppressed", false)
	_main_script.set("ads_backend_override", null)
	AgeGate.clock_override = ""
	DailyRewards.clock_override = ""
	DailyRewards.auto_popup_enabled = true
	MonetizationManager.time_scale = 1.0
	TutorialController.time_scale = 1.0
	UiKit.set_banner_slot(0.0)
	SaveManager.data = _saved
	_restore_save_file()
	var restored: bool = not _had_save or FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == _save_bytes
	_c("kayıt dosyası test sonunda byte-identical geri kondu", restored)
	if restored:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SIDECAR_PATH))
	print("=== SONUC: %d/%d kontrol, %d kaldi ===" % [_checks - _fails, _checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


## Yarıda kesilen koşuya karşı yan yedek (kayıt dosyasının ham baytları).
const SIDECAR_PATH: String = "user://squishy_merge_save.json.age_routing_testbak"


func _write_sidecar(bytes: PackedByteArray) -> void:
	var file := FileAccess.open(SIDECAR_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()


func _recover_sidecar() -> void:
	if not FileAccess.file_exists(SIDECAR_PATH):
		return
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(SIDECAR_PATH)
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()
		SaveManager.load_game()
	print("  (önceki yarıda kalan koşunun kayıt yedeği geri kondu)")


func _restore_save_file() -> void:
	if _had_save:
		var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(_save_bytes)
		file.close()
	elif FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))


func _settle(frames: int = 2) -> void:
	for i in maxi(frames, 1):
		await get_tree().process_frame


static func _idx(fake: FakeAdBackend, call: String) -> int:
	return fake.calls.find(call)


## Sıra kanıtı: verilen çağrılar fake.calls'ta bu sırada (hepsi var).
static func _ordered(fake: FakeAdBackend, calls: Array) -> bool:
	var last: int = -1
	for call in calls:
		var at: int = fake.calls.find(call, last + 1)
		if at == -1:
			return false
		last = at
	return true


func _manager(fake: FakeAdBackend, band: int, onboarding: bool = true) -> MonetizationManager:
	var m: MonetizationManager = MonetizationManager.create(fake, AdConfig.test_defaults())
	m.set_onboarding_completed(onboarding)
	if band != AgeGate.Band.UNKNOWN:
		m.set_age_band(band)
	add_child(m)
	m.set_process(false)
	await _settle(1)
	return m


func _free(m: MonetizationManager) -> void:
	if m != null and is_instance_valid(m):
		m.queue_free()
	await _settle(2)
	UiKit.set_banner_slot(0.0)


## Rıza gerekmiyor -> izin -> yapılandırma + init -> hazır.
func _ready_sdk(fake: FakeAdBackend) -> void:
	fake.complete_consent_update(true)
	fake.complete_init()
	await _settle(1)


# --- Yönetici: kapalı bantlar ------------------------------------------------------

func _test_manager_closed_bands() -> void:
	print("-- yönetici: UNKNOWN / UNDER_13 -> eklenti, UMP, SDK, reklam YOK (fail-closed)")
	for band in [AgeGate.Band.UNKNOWN, AgeGate.Band.UNDER_13]:
		var name: String = AgeGate.band_name(band)
		var fake := FakeAdBackend.new()
		fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
		var m: MonetizationManager = await _manager(fake, band)
		_c("%s: arka uca HİÇ çağrı yok (attach / yaş işlemi / UMP / init / yükleme yok) %s" % [name, str(fake.calls)],
			fake.calls.is_empty() and not m.backend_attached() and not m.consent_started()
			and fake.consent_update_calls == 0 and fake.init_calls == 0)
		_c("%s: SDK'ya bakan getter'lar da (rıza durumu, canRequestAds, banner boyu) attach'siz HİÇ çağrılmadı %s"
			% [name, str(fake.pre_attach_getters)], fake.pre_attach_getters.is_empty())
		_c("%s: yuva 0, ödüllü hazır değil, not nötr 'kullanılamıyor'" % name, m.banner_slot_px() == 0.0
			and not m.is_rewarded_ready() and m.rewarded_note() == MonetizationManager.NOTE_UNAVAILABLE)
		m.set_surface(MonetizationManager.Surface.HOME)
		m.ensure_rewarded()
		m._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		m._tick_active(2000.0)
		_c("%s: yüzey / talep / öne dönüş hiçbir şey başlatmaz; aktif süre saymaz" % name, fake.calls.is_empty()
			and m.active_elapsed_sec() == 0.0 and not m.interstitial_eligible())
		var shown: bool = m.try_show_interstitial("round_finish", func() -> void: pass)
		_c("%s: geçiş reklamı sebebi age_gate, gösterim yok" % name, not shown and m._interstitial_block_reason() == "age_gate")
		# Başıboş SDK sinyali (UMP hiç sorulmadı) yok sayılır: SDK başlamaz.
		fake.complete_consent_update(true)
		await _settle(1)
		_c("%s: başıboş rıza sinyali yok sayılır (SDK başlamaz, durum değişmez, getter çağrısı yok)" % name, fake.init_calls == 0
			and fake.request_configuration_applies == 0 and not m.ads_allowed() and fake.pre_attach_getters.is_empty())
		_c("%s: yönetici bandı taşıyor, oturum kapalı değil (sadece kapı kapalı)" % name, m.age_band() == band
			and not m.age_session_blocked() and not m.age_ads_allowed())
		await _free(m)


# --- Yönetici: rota ve sıra --------------------------------------------------------

func _test_manager_routes_and_order() -> void:
	print("-- yönetici: TEEN -> TEEN + T, ADULT -> UNSPECIFIED + MA; rota -> attach -> UMP -> yapılandırma -> init -> yükleme")
	for spec in [[AgeGate.Band.TEEN, "TEEN", "T"], [AgeGate.Band.ADULT, "UNSPECIFIED", "MA"]]:
		var band: int = spec[0]
		var treatment: String = spec[1]
		var rating: String = spec[2]
		var fake := FakeAdBackend.new()
		fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
		var m: MonetizationManager = await _manager(fake, band)
		_c("%s: rota attach'ten ve rızadan ÖNCE arka uca (%s, %s)" % [AgeGate.band_name(band), treatment, rating],
			_ordered(fake, ["set_age_restricted_treatment:" + treatment, "set_max_ad_content_rating:" + rating, "attach",
				"request_consent_update"]) and m.backend_attached() and m.consent_started())
		_c("%s: rıza sonuçlanmadan yapılandırma / SDK yok" % AgeGate.band_name(band), fake.request_configuration_applies == 0
			and fake.init_calls == 0)
		fake.complete_consent_update(true)
		await _settle(1)
		var config_call: String = "request_configuration:%s:%s" % [treatment, rating]
		_c("%s: izin -> yapılandırma (%s) initialize'dan ÖNCE, bir kez; geri okuma %s / %s" % [AgeGate.band_name(band), config_call, treatment, rating],
			_ordered(fake, ["request_consent_update", config_call, "initialize"]) and fake.request_configuration_applies == 1
			and fake.init_calls == 1 and fake.applied_request_configuration()["age_restricted_treatment"] == treatment
			and fake.applied_request_configuration()["max_ad_content_rating"] == rating)
		_c("%s: SDK hazır olmadan reklam yüklenmez" % AgeGate.band_name(band), fake.rewarded_loads == 0
			and fake.interstitial_loads == 0 and fake.banner_loads == 0)
		fake.complete_init()
		m.set_surface(MonetizationManager.Surface.HOME)
		await _settle(1)
		_c("%s: SDK hazır -> ödüllü + geçiş + banner yükleniyor; yuva hesaplandı" % AgeGate.band_name(band),
			fake.rewarded_loads == 1 and fake.interstitial_loads == 1 and fake.banner_loads == 1 and m.banner_slot_px() > 0.0)
		_c("%s: yönetici değerleri = arka uç (%s / %s); TFCD / TFUA -1 (eski yol nötr)" % [AgeGate.band_name(band), treatment, rating],
			AdBackend.AgeRestrictedTreatment.keys()[m.age_restricted_treatment()] == treatment
			and m.max_ad_content_rating() == rating
			and fake.applied_request_configuration()["tag_for_child_directed_treatment"] == -1
			and fake.applied_request_configuration()["tag_for_under_age_of_consent"] == -1)
		_c("%s: CHILD hiçbir zaman gönderilmedi" % AgeGate.band_name(band), _idx(fake, "set_age_restricted_treatment:CHILD") == -1)
		await _free(m)


# --- UMP matrisi -----------------------------------------------------------------------

func _test_ump_matrix() -> void:
	print("-- UMP matrisi: TEEN / ADULT × EEA / NOT_EEA; canRequestAds kapısı korunuyor")
	for band in [AgeGate.Band.TEEN, AgeGate.Band.ADULT]:
		var route: Dictionary = AgeGate.ad_route(band)
		var treatment: String = AdBackend.AgeRestrictedTreatment.keys()[route["treatment"]]
		var rating: String = route["max_ad_content_rating"]
		# EEA: rıza formu -> OBTAINED -> SDK.
		var eea := FakeAdBackend.new()
		eea.status = AdBackend.ConsentStatus.REQUIRED
		eea.form_available = true
		eea.privacy_status = AdBackend.PrivacyOptionsStatus.REQUIRED
		var m: MonetizationManager = await _manager(eea, band)
		eea.complete_consent_update(true)
		await _settle(1)
		_c("%s + EEA: UMP güncellemesi -> form yüklendi (TEEN UMP'yi ATLAMAZ), SDK yok" % AgeGate.band_name(band),
			eea.consent_update_calls == 1 and eea.consent_form_loads == 1 and eea.init_calls == 0
			and m.ads_state() == MonetizationManager.AdsState.CONSENT_FORM)
		eea.complete_form_load(true)
		eea.dismiss_form(AdBackend.ConsentStatus.OBTAINED)
		await _settle(1)
		_c("%s + EEA: rıza -> canRequestAds sorgulandı -> yapılandırma %s / %s -> init; gizlilik seçenekleri gerekli" % [
				AgeGate.band_name(band), treatment, rating],
			eea.can_request_calls > 0 and eea.init_calls == 1 and m.privacy_options_required()
			and _ordered(eea, ["show_consent_form", "request_configuration:%s:%s" % [treatment, rating], "initialize"]))
		await _free(m)
		# EEA, reddedildi / form hatası: SDK YOK.
		var denied := FakeAdBackend.new()
		denied.status = AdBackend.ConsentStatus.REQUIRED
		denied.form_available = true
		m = await _manager(denied, band)
		denied.complete_consent_update(true)
		denied.complete_form_load(true)
		denied.dismiss_form(-1, 4, "form error")
		await _settle(1)
		_c("%s + EEA, rıza yok: canRequestAds false -> SDK / yapılandırma YOK" % AgeGate.band_name(band),
			denied.init_calls == 0 and denied.request_configuration_applies == 0 and not m.ads_allowed())
		await _free(m)
		# NOT_EEA: form yok -> SDK.
		var other := FakeAdBackend.new()
		other.status = AdBackend.ConsentStatus.NOT_REQUIRED
		m = await _manager(other, band)
		other.complete_consent_update(true)
		await _settle(1)
		_c("%s + NOT_EEA: UMP güncellemesi yine yapıldı, form yok, yapılandırma %s / %s -> init" % [AgeGate.band_name(band), treatment, rating],
			other.consent_update_calls == 1 and other.consent_form_loads == 0 and other.init_calls == 1
			and _ordered(other, ["request_consent_update", "request_configuration:%s:%s" % [treatment, rating], "initialize"])
			and not m.privacy_options_required())
		await _free(m)


# --- Bant değişimi (Ayarlar → Yaş bilgisi) ------------------------------------------

func _test_band_changes() -> void:
	print("-- bant değişimi: SDK öncesi uygulanır; SDK sonrası oturum reklamsız, işlem DEĞİŞMEZ")
	# UNKNOWN -> TEEN (yaş ekranı, kabukta).
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	var m: MonetizationManager = await _manager(fake, AgeGate.Band.UNKNOWN)
	var slots: Array = []
	m.banner_slot_changed.connect(func(px: float) -> void: slots.append(px))
	var change: int = m.set_age_band(AgeGate.Band.TEEN)
	await _settle(1)
	_c("UNKNOWN -> TEEN: APPLIED; rota -> attach -> UMP; yuva açıldı (banner_slot_changed)",
		change == MonetizationManager.AgeBandChange.APPLIED and _ordered(fake, ["set_age_restricted_treatment:TEEN",
			"set_max_ad_content_rating:T", "attach", "request_consent_update"]) and slots.size() == 1 and m.banner_slot_px() > 0.0)
	_c("aynı bant yeniden -> UNCHANGED", m.set_age_band(AgeGate.Band.TEEN) == MonetizationManager.AgeBandChange.UNCHANGED)
	# TEEN -> ADULT, rıza sürüyor (SDK yapılandırılmadı): bekleyen rota güncellenir.
	change = m.set_age_band(AgeGate.Band.ADULT)
	_c("TEEN -> ADULT SDK öncesi: APPLIED, arka uç UNSPECIFIED / MA, oturum açık, rıza yeniden istenmedi",
		change == MonetizationManager.AgeBandChange.APPLIED and fake.treatment == AdBackend.AgeRestrictedTreatment.UNSPECIFIED
		and fake.rating == "MA" and not m.age_session_blocked() and fake.consent_update_calls == 1)
	fake.complete_consent_update(true)
	fake.complete_init()
	m.set_surface(MonetizationManager.Surface.HOME)
	await _settle(1)
	_c("... SDK yeni bantla yapılandırıldı (ADULT: UNSPECIFIED / MA)", _idx(fake, "request_configuration:UNSPECIFIED:MA") != -1
		and _idx(fake, "request_configuration:TEEN:T") == -1)
	var banner: String = fake.complete_banner_load(true)
	var rewarded: String = fake.complete_rewarded_load(true)
	fake.complete_interstitial_load(true)
	m._tick_active(MonetizationManager.INTERSTITIAL_INTERVAL_SEC + 1.0)
	await _settle(1)
	_c("hazırlık: banner gösteriliyor, ödüllü hazır, geçiş uygun + hazır", fake.banner_shows == [banner]
		and m.is_rewarded_ready() and m.is_interstitial_ready() and m.interstitial_eligible())
	var availability: Array = [0]
	m.rewarded_availability_changed.connect(func() -> void: availability[0] += 1)
	# ADULT -> TEEN, SDK yapılandırıldıktan SONRA: kilit.
	change = m.set_age_band(AgeGate.Band.TEEN)
	await _settle(1)
	_c("SDK SONRASI ADULT -> TEEN: NEXT_LAUNCH, oturum reklamsız", change == MonetizationManager.AgeBandChange.NEXT_LAUNCH
		and m.age_session_blocked() and not m.age_ads_allowed())
	_c("... işlem DEĞİŞMEDİ (arka uç hâlâ UNSPECIFIED / MA), reddetme logu üretilmedi (yeniden uygulama yok)",
		fake.treatment == AdBackend.AgeRestrictedTreatment.UNSPECIFIED and fake.rating == "MA"
		and fake.treatment_refusals == 0 and fake.rating_refusals == 0 and fake.request_configuration_applies == 1)
	_c("... banner GİZLENDİ, ödüllü / geçiş hazır sayılmaz, not 'kullanılamıyor', pencereler tazelendi",
		fake.banner_hides == [banner] and not m.is_rewarded_ready() and not m.is_interstitial_ready()
		and m.rewarded_note() == MonetizationManager.NOTE_UNAVAILABLE and availability[0] >= 1)
	var main_stub := Node.new()
	add_child(main_stub)
	m.show_rewarded_revive(main_stub)
	var shown: bool = m.try_show_interstitial("round_finish", func() -> void: pass)
	_c("... ödüllü gösterilmez, geçiş gösterilmez (sebep age_gate)", fake.rewarded_shows.is_empty()
		and fake.interstitial_shows.is_empty() and not shown and m._interstitial_block_reason() == "age_gate")
	var loads_before: int = fake.rewarded_loads + fake.interstitial_loads + fake.banner_loads
	m.ensure_rewarded()
	m.set_surface(MonetizationManager.Surface.MAP)
	m.set_surface(MonetizationManager.Surface.HOME)
	m._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _settle(1)
	_c("... yeni yükleme / banner gösterimi YOK (talep, yüzey, öne dönüş)", fake.rewarded_loads + fake.interstitial_loads
		+ fake.banner_loads == loads_before and fake.banner_shows == [banner])
	_c("... bant yeniden ADULT'a dönse de bu süreçte açılmaz (NEXT_LAUNCH)", m.set_age_band(AgeGate.Band.ADULT)
		== MonetizationManager.AgeBandChange.NEXT_LAUNCH and m.age_session_blocked())
	_c("... yuva SABİT (düzen zıplamaz)", m.banner_slot_px() > 0.0)
	main_stub.queue_free()
	await _free(m)
	# Yeni soğuk açılış = yeni yönetici: yeni bant SDK'dan önce.
	var fresh := FakeAdBackend.new()
	fresh.status = AdBackend.ConsentStatus.NOT_REQUIRED
	var m2: MonetizationManager = await _manager(fresh, AgeGate.Band.TEEN)
	await _ready_sdk(fresh)
	_c("sonraki soğuk açılış: TEEN + T yapılandırmadan / init'ten ÖNCE", _ordered(fresh, ["set_age_restricted_treatment:TEEN",
		"set_max_ad_content_rating:T", "attach", "request_configuration:TEEN:T", "initialize"]) and not m2.age_session_blocked())
	# 13 altına geçiş (kapı açıkken).
	change = m2.set_age_band(AgeGate.Band.UNDER_13)
	_c("TEEN -> UNDER_13: ADS_STOPPED, oturum reklamsız", change == MonetizationManager.AgeBandChange.ADS_STOPPED
		and m2.age_session_blocked() and not m2.is_rewarded_ready())
	await _free(m2)
	# Kapı hiç açılmadan UNKNOWN -> UNDER_13: hiçbir şey başlamaz.
	var closed := FakeAdBackend.new()
	var m3: MonetizationManager = await _manager(closed, AgeGate.Band.UNKNOWN)
	change = m3.set_age_band(AgeGate.Band.UNDER_13)
	_c("UNKNOWN -> UNDER_13: APPLIED, arka uca hâlâ HİÇ çağrı yok", change == MonetizationManager.AgeBandChange.APPLIED
		and closed.calls.is_empty())
	await _free(m3)


func _test_read_back_fail_closed() -> void:
	print("-- geri okuma uyuşmazlığı: SDK başlamaz (TEEN uygulanmadıysa fail-closed)")
	# UMP'den ÖNCE: arka uç rotayı kabul edip TUTMADIYSA kapı açılmaz (attach / UMP yok).
	var lost := FakeAdBackend.new()
	lost.status = AdBackend.ConsentStatus.NOT_REQUIRED
	lost.route_store_fault = true
	var ml: MonetizationManager = await _manager(lost, AgeGate.Band.TEEN)
	_c("rota arka uçta tutulmadı (TEEN / T değil) -> attach / UMP / SDK YOK, oturum reklamsız (UMP öncesi doğrulama)",
		_idx(lost, "attach") == -1 and lost.consent_update_calls == 0 and lost.init_calls == 0 and ml.age_session_blocked())
	await _free(ml)
	# init'ten HEMEN ÖNCE: arka ucun tuttuğu değer rotadan saptıysa SDK başlamaz.
	var drift := FakeAdBackend.new()
	drift.status = AdBackend.ConsentStatus.NOT_REQUIRED
	var md: MonetizationManager = await _manager(drift, AgeGate.Band.TEEN)
	drift.treatment = AdBackend.AgeRestrictedTreatment.UNSPECIFIED
	drift.complete_consent_update(true)
	await _settle(1)
	_c("rıza sonrası arka uç değeri rotadan saptı (TEEN -> UNSPECIFIED) -> yapılandırma / initialize YOK, oturum reklamsız",
		drift.request_configuration_applies == 0 and drift.init_calls == 0 and md.age_session_blocked()
		and drift.rewarded_loads == 0)
	await _free(md)
	var bad := FakeAdBackend.new()
	bad.status = AdBackend.ConsentStatus.NOT_REQUIRED
	bad.request_configuration_fault = true
	var m: MonetizationManager = await _manager(bad, AgeGate.Band.TEEN)
	bad.complete_consent_update(true)
	await _settle(1)
	_c("SDK TEEN'i uygulamadı (geri okuma UNSPECIFIED) -> initialize YOK, sdk_refused, reklam yok",
		bad.init_refusals == 1 and bad.init_calls == 0 and m.sdk_refused() and bad.rewarded_loads == 0
		and m.rewarded_note() == MonetizationManager.NOTE_UNAVAILABLE)
	await _free(m)


func _test_consent_in_flight_block() -> void:
	print("-- rıza yoldayken oturum kapandı (Ayarlar'dan 13 altı): rıza formu yüklenmez / gösterilmez, SDK yok")
	# (a) Güncelleme yolda -> 13 altı -> güncelleme EEA REQUIRED + form var dönüyor.
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.REQUIRED
	fake.form_available = true
	var m: MonetizationManager = await _manager(fake, AgeGate.Band.TEEN)
	_c("TEEN: rıza güncellemesi istendi (yolda)", fake.consent_update_calls == 1 and m.consent_started())
	var change: int = m.set_age_band(AgeGate.Band.UNDER_13)
	fake.complete_consent_update(true)
	await _settle(1)
	_c("13 altına geçildi (ADS_STOPPED), geç gelen güncelleme -> form YÜKLENMEDİ / GÖSTERİLMEDİ, yapılandırma / init YOK",
		change == MonetizationManager.AgeBandChange.ADS_STOPPED and fake.consent_form_loads == 0
		and fake.consent_form_shows == 0 and fake.request_configuration_applies == 0 and fake.init_calls == 0)
	await _free(m)
	# (b) Form yükleniyor -> 13 altı -> form yüklendi sinyali.
	var loading := FakeAdBackend.new()
	loading.status = AdBackend.ConsentStatus.REQUIRED
	loading.form_available = true
	var m2: MonetizationManager = await _manager(loading, AgeGate.Band.ADULT)
	loading.complete_consent_update(true)
	await _settle(1)
	_c("ADULT (EEA): açılış rıza formu yükleniyor", loading.consent_form_loads == 1 and loading.consent_form_shows == 0)
	m2.set_age_band(AgeGate.Band.UNDER_13)
	loading.complete_form_load(true)
	await _settle(1)
	_c("13 altına geçildi -> yüklenen form GÖSTERİLMEDİ, SDK yok", loading.consent_form_shows == 0
		and loading.init_calls == 0 and m2.age_session_blocked())
	await _free(m2)
	# (c) TEEN <-> ADULT (SDK sonrası değil, rıza yolda): oturum açık kalır, form normal akar.
	var normal := FakeAdBackend.new()
	normal.status = AdBackend.ConsentStatus.REQUIRED
	normal.form_available = true
	var m3: MonetizationManager = await _manager(normal, AgeGate.Band.TEEN)
	_c("rıza yoldayken TEEN -> ADULT (SDK yapılandırılmadı): APPLIED, oturum açık",
		m3.set_age_band(AgeGate.Band.ADULT) == MonetizationManager.AgeBandChange.APPLIED and not m3.age_session_blocked())
	normal.complete_consent_update(true)
	normal.complete_form_load(true)
	await _settle(1)
	_c("... açılış rıza formu gösterildi (engellenmemiş oturumda davranış aynı)", normal.consent_form_shows == 1)
	await _free(m3)


# --- Main entegrasyonu -------------------------------------------------------------

## Kayıt kur (bellek + disk). `onboarded` false = yeni oyuncu.
func _seed(onboarded: bool, band: String = "", transition: String = "", login_today: bool = true) -> void:
	SaveManager.data = SaveManager.DEFAULT_DATA.duplicate(true)
	SaveManager.data["powerup_starter_granted"] = true
	SaveManager.data["powerups"] = {"bomb": 1, "upgrade": 1, "shake": 1, "clear_small": 1}
	SaveManager.data["onboarding_completed"] = onboarded
	SaveManager.data["highest_level_unlocked"] = 5 if onboarded else 1
	SaveManager.data["dough"] = 300
	# Giriş ödülü GERÇEK yerel günü okur (DailyReward); saat kancası yalnız günlük kotalarda.
	SaveManager.data["last_login_date"] = _real_days_ago(0 if login_today else 1)
	SaveManager.data["daily_streak"] = 2
	if band.is_empty():
		SaveManager.data.erase("age_ad_band")
		SaveManager.data.erase("next_age_transition_date")
	else:
		SaveManager.data["age_ad_band"] = band
		SaveManager.data["next_age_transition_date"] = transition
	SaveManager.save_game()


static func _real_days_ago(days: int) -> String:
	var unix: int = Time.get_unix_time_from_datetime_string(Time.get_date_string_from_system() + "T12:00:00") - days * 86400
	return Time.get_date_string_from_unix_time(unix).substr(0, 10)


func _boot(fake: FakeAdBackend) -> void:
	await _teardown_main()
	_main_script.set("ads_backend_override", fake)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _settle(3)
	_main_script.set("ads_backend_override", null)


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _settle(2)
	UiKit.set_banner_slot(0.0)


func _panel() -> CanvasLayer:
	return _main.age_panel()


## TASK/046.1: GÜN / AY / YIL seçicileri — yıl, ay, gün ızgaradan seçilir (kod yolu
## `pressed.emit()`; parmak yatışması etkilemez), sonra DEVAM ET + ONAYLA.
func _enter_dob(ddmmyyyy: String) -> void:
	var panel: CanvasLayer = _panel()
	var values: Array[int] = [int(ddmmyyyy.substr(4, 4)), int(ddmmyyyy.substr(2, 2)), int(ddmmyyyy.substr(0, 2))]
	var fields: Array[int] = [2, 1, 0]
	for i in 3:
		panel.selector_button(fields[i]).pressed.emit()
		var option: Button = panel.option_button(values[i])
		if option == null:
			print("    ızgarada yok: ", values[i])
			panel.close_picker()
			continue
		option.pressed.emit()
	panel.continue_button().pressed.emit()
	await _settle(1)
	panel.confirm_button().pressed.emit()
	await _settle(2)


func _test_main_legacy_unknown() -> void:
	print("-- Main: eski kayıt (onboarding tamam, yaş YOK) -> Ana Sayfa'da zorunlu yaş ekranı; günlük pencere ve rıza bekler")
	_seed(true, "", "", false)
	DailyRewards.auto_popup_enabled = true
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	await _boot(fake)
	var m: MonetizationManager = _main._ads
	_c("açılış: yaş ekranı (ZORUNLU) Ana Sayfa üstünde; günlük pencere AÇILMADI (giriş ödülü yine de alındı)",
		_panel().visible and not _panel().is_reentry() and _main._active_tab == 0 and not _main._daily_rewards.visible
		and SaveManager.last_login_date() == Time.get_date_string_from_system())
	_c("yaş çözülmeden: eklenti / UMP / SDK YOK (getter dahil), yuva 0, Ayarlar'da Yaş bilgisi satırı gizli", fake.calls.is_empty()
		and fake.pre_attach_getters.is_empty() and m.banner_slot_px() == 0.0 and not _main._settings.age_info_row().visible)
	_main.open_daily_rewards()
	await _settle(1)
	_c("Ana Sayfa madalyonu / Mağaza kartı yolu da günlük pencereyi AÇMAZ (reklamlı girişler var)", not _main._daily_rewards.visible)
	var quits: int = _main.quit_requests
	await get_tree().create_timer(0.3).timeout
	_main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(1)
	_c("zorunlu yaş ekranında Android geri UYGULAMADAN ÇIKMAZ (TASK/046.1): panel açık, çıkış isteği yok",
		_main.quit_requests == quits and _panel().visible and not _panel().is_reentry())
	_panel().selector_button(2).pressed.emit()
	await get_tree().create_timer(0.3).timeout
	_main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(1)
	_c("ızgara açıkken geri: yalnız ızgara kapandı, panel açık, çıkış yok", _panel().visible and _panel().picker_field() == -1
		and _main.quit_requests == quits)
	_c("geçerli seçimden önce: UMP 0 · init 0 · banner 0 · ödüllü 0 · geçiş 0 (arka uca HİÇ çağrı yok)", fake.calls.is_empty()
		and fake.consent_update_calls == 0 and fake.init_calls == 0 and fake.banner_loads == 0 and fake.rewarded_loads == 0
		and fake.interstitial_loads == 0 and fake.interstitial_shows.is_empty())
	var home: CanvasLayer = _main._screens[0]
	var play_bottom_before: float = home._play_pulse.position.y + home._play_pulse.size.y
	await _enter_dob("01011990")
	var slot: float = m.banner_slot_px()
	var play_bottom_after: float = home._play_pulse.position.y + home._play_pulse.size.y
	var view_h: float = home._root.size.y
	_c("yaş girilince yuva açıldı ve görünür Ana Sayfa HEMEN yeniden yerleşti: OYNA yuva kadar yukarı, banner'ın üstünde (%.0f px)" % slot,
		slot > 0.0 and is_equal_approx(play_bottom_before - play_bottom_after, slot)
		and play_bottom_after <= view_h - UiKit.bottom_inset(home._root.size) + 0.5)
	_c("yetişkin tarihi -> panel kapandı, kayıt ADULT (tarih YOK), yönetici ADULT", not _panel().visible
		and SaveManager.age_ad_band_raw() == "ADULT" and SaveManager.next_age_transition_raw() == ""
		and _main.age_band() == AgeGate.Band.ADULT and m.age_band() == AgeGate.Band.ADULT)
	_c("yaş çözüldü -> rota (UNSPECIFIED / MA) -> attach -> UMP ŞİMDİ", _ordered(fake, ["set_age_restricted_treatment:UNSPECIFIED",
		"set_max_ad_content_rating:MA", "attach", "request_consent_update"]))
	_c("günlük pencere yaştan SONRA açıldı (bugün ilk kez)", _main._daily_rewards.visible and _main._daily_rewards.is_auto_opened())
	await _ready_sdk(fake)
	_c("rıza -> yapılandırma UNSPECIFIED / MA -> init; Ana Sayfa banner'ı yükleniyor", _ordered(fake, ["request_consent_update",
		"request_configuration:UNSPECIFIED:MA", "initialize"]) and fake.banner_loads == 1)
	_c("Ayarlar'da Yaş bilgisi satırı artık görünür", _main._settings.age_info_row().visible)
	var text: String = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	_c("kayıtta ham doğum tarihi YOK (1990 / 01.01.1990 / 1990-01-01)", not text.contains("1990"))
	_main._daily_rewards.close_popup()
	DailyRewards.auto_popup_enabled = false
	await _teardown_main()


func _test_main_first_run() -> void:
	print("-- Main: ilk açılış — tutorial + tutorial round'u reklamsız, yaş İLK güvenli kabukta, sonra UMP")
	_seed(false)
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.REQUIRED
	fake.form_available = true
	await _boot(fake)
	var m: MonetizationManager = _main._ads
	_c("tutorial açık, yaş ekranı YOK (tutorial kesilmez), arka uca çağrı yok", _main.is_tutorial_active()
		and not _panel().visible and fake.calls.is_empty())
	_main._tutorial.advance()
	await _settle(1)
	_main._tutorial.skip()
	await _settle(1)
	_c("tutorial bitti ama round sürüyor: yaş ekranı YOK (round ortası), monetizasyon ertelendi", SaveManager.onboarding_completed()
		and not _panel().visible and _main._monetization_deferred and fake.calls.is_empty())
	_main.abandon_run()
	await _settle(2)
	_c("ilk güvenli kabuk (Harita): ZORUNLU yaş ekranı; UMP HENÜZ yok", _panel().visible and _main._active_tab == 1
		and not m.consent_started() and fake.calls.is_empty())
	_c("tutorial günü: günlük sistem kilitli (ilk gün kuralı değişmedi)", not Onboarding.daily_rewards_unlocked()
		and not _main._daily_rewards.visible)
	var map: CanvasLayer = _main._screens[1]
	var world_before: Rect2 = map.world_rect()
	await _enter_dob("15062011")
	var world_after: Rect2 = map.world_rect()
	var map_view: Vector2 = get_viewport().get_visible_rect().size
	_c("yaş girilince yuva açıldı; görünür HARİTA hemen yeniden yerleşti: dünya yuvanın üstünde biter (%.0f px)" % m.banner_slot_px(),
		m.banner_slot_px() > 0.0 and world_after.end.y < world_before.end.y
		and world_after.end.y <= map_view.y - UiKit.bottom_inset(map_view) + 0.5)
	_c("15 yaş -> TEEN (geçiş 18. yaş günü), rota TEEN + T -> attach -> UMP; form yükleniyor", SaveManager.age_ad_band_raw() == "TEEN"
		and SaveManager.next_age_transition_raw() == "2029-06-15" and _ordered(fake, ["set_age_restricted_treatment:TEEN",
			"set_max_ad_content_rating:T", "attach", "request_consent_update"]))
	fake.complete_consent_update(true)
	fake.complete_form_load(true)
	fake.dismiss_form(AdBackend.ConsentStatus.OBTAINED)
	fake.complete_init()
	await _settle(1)
	_c("EEA rıza -> yapılandırma TEEN / T -> init; geri okuma TEEN", _ordered(fake, ["show_consent_form",
		"request_configuration:TEEN:T", "initialize"]) and fake.applied_request_configuration()["age_restricted_treatment"] == "TEEN")
	_c("kayıtta ham doğum tarihi YOK (2011 / 15.06.2011)", not FileAccess.get_file_as_string(SaveManager.SAVE_PATH).contains("2011"))
	await _teardown_main()
	# Tutorial round'undan "tekrar" döngüsü: kabuk görülmeden yaş sorulmaz, reklam yok.
	_seed(false)
	var loop := FakeAdBackend.new()
	loop.status = AdBackend.ConsentStatus.NOT_REQUIRED
	await _boot(loop)
	_main._tutorial.advance()
	await _settle(1)
	_main._tutorial.skip()
	await _settle(1)
	_main._start_level(load(LEVEL_10))
	await _settle(2)
	_c("yeni round (kabuk yok): yaş ekranı YOK, monetizasyon açıldı ama yaş kapısı kapalı -> çağrı yok", not _panel().visible
		and not _main._monetization_deferred and _main._ads.onboarding_completed() and loop.calls.is_empty())
	_main._board._enter_fail_pending()
	await _settle(3)
	_c("devam penceresi: DEVAM ET pasif + nötr 'kullanılamıyor' (yaş bilinmeden ödüllü yok)", _main._revive.visible
		and _main._revive.continue_button().disabled and _main._revive.note_text() == MonetizationManager.NOTE_UNAVAILABLE)
	_main.decline_revive()
	await _settle(2)
	_main._result.hide_result()
	_main.abandon_run()
	await _settle(2)
	_c("kabuğa dönünce yaş ekranı", _panel().visible)
	await _teardown_main()


## Açık ağaçta kısıt / çıkış ekranı metni görünüyor mu (TASK/046.1: hiçbir yolda olmamalı).
func _restricted_text_visible() -> bool:
	for node in _main.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		var text: String = ""
		if control is Label:
			text = (control as Label).text
		elif control is Button:
			text = (control as Button).text
		if text.contains("Üzgünüz") or text.contains("yaş grubun") or text == "ÇIKIŞ":
			return true
	return false


func _test_main_legacy_under_13() -> void:
	print("-- Main: ESKİ UNDER_13 kaydı (TASK/043 dönemi) -> kısıt ekranı YOK, yaş yeniden sorulur, SDK / UMP YOK")
	_seed(true, "UNDER_13", "2029-04-02", false)
	DailyRewards.auto_popup_enabled = true
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	await _boot(fake)
	_c("açılış: bant UNKNOWN (yaş tahmin edilmez), ZORUNLU yaş ekranı Ana Sayfa üstünde, kısıt / çıkış ekranı YOK",
		_main.age_band() == AgeGate.Band.UNKNOWN and _panel().visible and not _panel().is_reentry() and _main._active_tab == 0
		and not _restricted_text_visible() and not _main.has_method("age_restricted_screen"))
	_c("arka uca HİÇ çağrı yok (attach / UMP / SDK / yükleme), yuva 0, günlük pencere yok, tutorial yok", fake.calls.is_empty()
		and _main._ads.banner_slot_px() == 0.0 and not _main._daily_rewards.visible and not _main.is_tutorial_active())
	_c("kayıt TEEN / ADULT'a çevrilmedi: UNKNOWN + tarih boş (eski 13. yaş günü silindi), ilerleme duruyor (level 5, Hamur korunmuş)",
		SaveManager.age_ad_band_raw() == "UNKNOWN" and SaveManager.next_age_transition_raw() == ""
		and not FileAccess.get_file_as_string(SaveManager.SAVE_PATH).contains("2029-04-02")
		and SaveManager.highest_level_unlocked() == 5 and SaveManager.dough() >= 300)
	var quits: int = _main.quit_requests
	await get_tree().create_timer(0.3).timeout
	_main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(1)
	_c("Android geri UYGULAMADAN ÇIKMAZ, panel açık", _main.quit_requests == quits and _panel().visible)
	_main.open_daily_rewards()
	await _settle(1)
	_c("günlük pencere (reklamlı girişler) yaş çözülmeden açılmaz", not _main._daily_rewards.visible)
	await _enter_dob("15062011")
	_c("yeni 13+ giriş (15 yaş) -> TEEN (geçiş 18. yaş günü), eski 13. yaş günü kayıtta YOK, rota TEEN + T attach / UMP'den ÖNCE",
		SaveManager.age_ad_band_raw() == "TEEN" and SaveManager.next_age_transition_raw() == "2029-06-15"
		and not FileAccess.get_file_as_string(SaveManager.SAVE_PATH).contains("2029-04-02")
		and _ordered(fake, ["set_age_restricted_treatment:TEEN", "set_max_ad_content_rating:T", "attach", "request_consent_update"]))
	_c("panel kapandı, günlük pencere yaştan SONRA", not _panel().visible and _main._daily_rewards.visible)
	_main._daily_rewards.close_popup()
	await _teardown_main()
	# Eski UNDER_13, saklı 13. yaş günü GELMİŞ: yine TEEN'e çevrilmez — yeniden sorulur.
	_seed(true, "UNDER_13", "2029-04-02", false)
	AgeGate.clock_override = "2029-04-02"
	DailyRewards.clock_override = "2029-04-02"
	var birthday := FakeAdBackend.new()
	await _boot(birthday)
	_c("saklı 13. yaş günü bugün: bant UNKNOWN, yaş ekranı, arka uç çağrısı YOK (eski tarih yaş kanıtı sayılmaz)",
		_main.age_band() == AgeGate.Band.UNKNOWN and _panel().visible and birthday.calls.is_empty()
		and SaveManager.age_ad_band_raw() == "UNKNOWN" and not _restricted_text_visible())
	await _teardown_main()
	AgeGate.clock_override = TODAY
	DailyRewards.clock_override = TODAY
	DailyRewards.auto_popup_enabled = false


func _test_main_launch_transitions() -> void:
	print("-- Main: soğuk açılış geçişi — 18. yaş gününden bir gün önce TEEN, tam 18. yaş günü ADULT (SDK'dan önce)")
	_seed(true, "TEEN", "2026-10-02")
	var before := FakeAdBackend.new()
	before.status = AdBackend.ConsentStatus.NOT_REQUIRED
	await _boot(before)
	_c("18. yaş gününden BİR GÜN önce: TEEN kalır, rota TEEN + T", _main.age_band() == AgeGate.Band.TEEN
		and SaveManager.age_ad_band_raw() == "TEEN" and _idx(before, "set_age_restricted_treatment:TEEN") != -1
		and not _panel().visible)
	await _teardown_main()
	AgeGate.clock_override = "2026-10-02"
	DailyRewards.clock_override = "2026-10-02"
	var turned := FakeAdBackend.new()
	turned.status = AdBackend.ConsentStatus.NOT_REQUIRED
	await _boot(turned)
	await _ready_sdk(turned)
	_c("tam 18. yaş günü: kayıt ADULT (geçiş temizlendi), rota UNSPECIFIED + MA attach / UMP / init'ten ÖNCE, TEEN hiç verilmedi",
		_main.age_band() == AgeGate.Band.ADULT and SaveManager.age_ad_band_raw() == "ADULT"
		and SaveManager.next_age_transition_raw() == "" and _idx(turned, "set_age_restricted_treatment:TEEN") == -1
		and _ordered(turned, ["set_age_restricted_treatment:UNSPECIFIED", "set_max_ad_content_rating:MA", "attach",
			"request_consent_update", "request_configuration:UNSPECIFIED:MA", "initialize"]))
	await _teardown_main()
	AgeGate.clock_override = TODAY
	DailyRewards.clock_override = TODAY
	# Bozuk kayıt -> UNKNOWN -> yaş yeniden sorulur, reklam yok.
	_seed(true, "ADULT", "2027-01-01")
	var corrupt := FakeAdBackend.new()
	await _boot(corrupt)
	_c("bozuk kayıt (ADULT + tarih) -> UNKNOWN: yaş ekranı, arka uca çağrı YOK (ASLA yetişkin yolu)", _main.age_band() == AgeGate.Band.UNKNOWN
		and _panel().visible and corrupt.calls.is_empty())
	await _teardown_main()


func _test_main_broken_clock() -> void:
	print("-- Main: cihaz saati modelden önce (bozuk) — yaş sorulmaz, bant UNKNOWN (reklam yok), oyun açık")
	_seed(true, "", "", false)
	DailyRewards.auto_popup_enabled = true
	AgeGate.clock_override = "2026-09-26"
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	await _boot(fake)
	_c("bozuk saat: yaş ekranı AÇILMADI, bant UNKNOWN, arka uca çağrı yok, günlük pencere yok (reklamlı girişler)",
		not _panel().visible and _main.age_band() == AgeGate.Band.UNKNOWN and fake.calls.is_empty()
		and not _main._daily_rewards.visible and _main._active_tab == 0)
	_c("... kayda hiçbir yaş değeri yazılmadı", SaveManager.age_ad_band_raw() == "UNKNOWN" and SaveManager.next_age_transition_raw() == "")
	await _teardown_main()
	# Eski UNDER_13 kaydı bozuk saatte: UNKNOWN, reklam yok, kısıt ekranı YOK (TASK/046.1).
	_seed(true, "UNDER_13", "2030-05-10")
	var under := FakeAdBackend.new()
	await _boot(under)
	_c("bozuk saat + eski UNDER_13: bant UNKNOWN, arka uca çağrı yok, kısıt / çıkış ekranı YOK, kayıt UNKNOWN + tarih boş (yaş sorulmasa da)",
		_main.age_band() == AgeGate.Band.UNKNOWN and under.calls.is_empty() and not _restricted_text_visible()
		and SaveManager.age_ad_band_raw() == "UNKNOWN" and SaveManager.next_age_transition_raw() == "")
	await _teardown_main()
	AgeGate.clock_override = TODAY
	DailyRewards.auto_popup_enabled = false


func _test_main_settings_reentry() -> void:
	print("-- Main: Ayarlar → Yaş bilgisi (yeniden giriş) — SDK sonrası değişim oturumu kapatır, sonraki açılış yeni bant")
	_seed(true, "ADULT", "")
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	await _boot(fake)
	await _ready_sdk(fake)
	var m: MonetizationManager = _main._ads
	var banner: String = fake.complete_banner_load(true)
	fake.complete_rewarded_load(true)
	await _settle(1)
	_c("ADULT açılış: SDK UNSPECIFIED / MA ile hazır, banner Ana Sayfa'da", fake.banner_shows == [banner] and m.is_rewarded_ready())
	_main.open_settings()
	await _settle(2)
	_c("Ayarlar: 'Yaş bilgisi' satırı görünür (kayıtlı yaş / tarih YOK, yalnız Güncelle)", _main._settings.age_info_row().visible
		and _main._settings.age_info_button().text == "Güncelle")
	var sframe: Control = _main._settings.frame()
	var canvas := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var spanel: Control = sframe.get_meta(&"panel")
	_c("Ayarlar (banner yuvasıyla, 720×1280): pencere ekranda, Yaş bilgisi satırı + Güncelle panelin içinde",
		canvas.encloses(sframe.get_global_rect()) and spanel.get_global_rect().encloses(_main._settings.age_info_button().get_global_rect()))
	_main._settings.age_info_button().pressed.emit()
	await _settle(2)
	var sel: Array[bool] = _panel().selected_fields()
	_c("yeniden giriş paneli Ayarlar'ın ÜSTÜNDE, seçiciler boş", _panel().visible and _panel().is_reentry()
		and _panel().layer > _main._settings.layer and not sel[0] and not sel[1] and not sel[2])
	_c("TASK/046.1: yaş paneli açıkken banner YOK (yüzey NONE, gizlendi), yuva sabit", m.surface() == MonetizationManager.Surface.NONE
		and fake.banner_hides == [banner] and m.banner_slot_px() > 0.0)
	# Aynı bant (başka yetişkin tarihi): reklam sürer, not yok.
	await _enter_dob("10101985")
	var done_same: PackedStringArray = _panel().visible_texts()
	_c("aynı bant (ADULT): TAMAM adımı (nötr not), NEXT_LAUNCH değil, reklam sürüyor", _panel().stage() == _panel().Stage.DONE
		and _panel().done_note_visible() and not _panel().done_next_launch() and not m.age_session_blocked() and m.is_rewarded_ready())
	_panel().done_button().pressed.emit()
	await _settle(1)
	_c("TAMAM -> panel kapandı, Ayarlar açık; banner Ana Sayfa yüzeyine GERİ geldi", not _panel().visible
		and _main._settings.visible and m.surface() == MonetizationManager.Surface.HOME and fake.banner_shows == [banner, banner])
	# Farklı bant, SDK sonrası: oturum reklamsız.
	_main._settings.age_info_button().pressed.emit()
	await _enter_dob("15062011")
	_c("ADULT -> TEEN (SDK yapılandırılmış): kayıt TEEN, NEXT_LAUNCH; ekrandaki metin aynı bantla BİREBİR aynı (cevap ele verilmez)",
		SaveManager.age_ad_band_raw() == "TEEN" and _panel().stage() == _panel().Stage.DONE and _panel().done_next_launch()
		and _panel().visible_texts() == done_same)
	_c("... bu oturumda reklam YOK: banner gizli, ödüllü hazır değil, işlem değişmedi (UNSPECIFIED / MA)",
		m.age_session_blocked() and fake.banner_hides == [banner, banner] and not m.is_rewarded_ready()
		and fake.treatment == AdBackend.AgeRestrictedTreatment.UNSPECIFIED and fake.rating == "MA" and fake.treatment_refusals == 0)
	_panel().done_button().pressed.emit()
	_main.close_settings()
	await _settle(1)
	_c("... panel kapanınca da banner GERİ GELMEDİ (oturum reklamsız)", fake.banner_shows == [banner, banner]
		and m.banner_state() != MonetizationManager.BannerState.SHOWN)
	DailyRewards.auto_popup_enabled = false
	_main.open_daily_rewards()
	await _settle(2)
	var popup: CanvasLayer = _main._daily_rewards
	_c("günlük pencere: ücretsiz sandık açık kalır, reklamlı girişler pasif + nötr not", popup.visible
		and not popup.free_button().disabled and popup.dough_button().disabled and popup.chest_button().disabled)
	popup.close_popup()
	await _teardown_main()
	# Sonraki soğuk açılış: TEEN + T SDK'dan önce.
	var next := FakeAdBackend.new()
	next.status = AdBackend.ConsentStatus.NOT_REQUIRED
	await _boot(next)
	await _ready_sdk(next)
	_c("sonraki soğuk açılış: TEEN + T yapılandırmadan / init'ten ÖNCE, oturum açık", _ordered(next, [
		"set_age_restricted_treatment:TEEN", "set_max_ad_content_rating:T", "attach", "request_consent_update",
		"request_configuration:TEEN:T", "initialize"]) and not _main._ads.age_session_blocked())
	# Tersi: TEEN -> ADULT SDK sonrası.
	_main.open_settings()
	_main._settings.age_info_button().pressed.emit()
	await _enter_dob("01011990")
	_c("TEEN -> ADULT (SDK sonrası): NEXT_LAUNCH, oturum reklamsız, işlem TEEN kaldı", _panel().done_next_launch()
		and _main._ads.age_session_blocked() and next.treatment == AdBackend.AgeRestrictedTreatment.TEEN and next.rating == "T")
	_panel().done_button().pressed.emit()
	_main.close_settings()
	await _teardown_main()
	var after := FakeAdBackend.new()
	after.status = AdBackend.ConsentStatus.NOT_REQUIRED
	await _boot(after)
	await _ready_sdk(after)
	_c("... sonraki açılış ADULT: UNSPECIFIED + MA SDK'dan önce", _ordered(after, ["set_age_restricted_treatment:UNSPECIFIED",
		"set_max_ad_content_rating:MA", "attach", "request_configuration:UNSPECIFIED:MA", "initialize"]))
	# SDK ÖNCESİ yeniden giriş (EEA rızası bekliyor): uygulanır, not yok.
	await _teardown_main()
	_seed(true, "ADULT", "")
	var pending := FakeAdBackend.new()
	pending.status = AdBackend.ConsentStatus.REQUIRED
	pending.form_available = true
	await _boot(pending)
	_main.open_settings()
	_main._settings.age_info_button().pressed.emit()
	await _enter_dob("15062011")
	_c("SDK ÖNCESİ ADULT -> TEEN: NEXT_LAUNCH değil, oturum açık, bekleyen rota TEEN / T", not _panel().done_next_launch()
		and not _main._ads.age_session_blocked() and pending.treatment == AdBackend.AgeRestrictedTreatment.TEEN and pending.rating == "T")
	_panel().done_button().pressed.emit()
	_main.close_settings()
	pending.complete_consent_update(true)
	pending.complete_form_load(true)
	pending.dismiss_form(AdBackend.ConsentStatus.OBTAINED)
	await _settle(1)
	_c("... rıza sonrası SDK TEEN / T ile yapılandırıldı", _idx(pending, "request_configuration:TEEN:T") != -1
		and _idx(pending, "request_configuration:UNSPECIFIED:MA") == -1 and pending.init_calls == 1)
	# TASK/046.1: yeniden girişte 13 altı yıl ızgarada YOK; vazgeçince hiçbir şey değişmez.
	_main.open_settings()
	_main._settings.age_info_button().pressed.emit()
	await _settle(1)
	_panel().selector_button(2).pressed.emit()
	var years: Array[int] = _panel().option_values()
	_c("yeniden giriş yıl ızgarası en genç 2013 (bugün 2026-10-01), 2014+ YOK", not years.is_empty() and years[0] == 2013
		and _panel().option_button(2014) == null and _panel().option_button(2016) == null)
	var quits: int = _main.quit_requests
	await get_tree().create_timer(0.3).timeout
	_main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(1)
	_c("yeniden girişte geri: önce ızgara kapanır (panel açık)", _panel().visible and _panel().picker_field() == -1)
	await get_tree().create_timer(0.3).timeout
	_main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(1)
	_c("ikinci geri: yeniden giriş VAZGEÇ — panel kapandı, Ayarlar açık, kayıt TEEN aynen, çıkış yok", not _panel().visible
		and _main._settings.visible and SaveManager.age_ad_band_raw() == "TEEN" and _main.quit_requests == quits)
	# Panel açıkken gelen reklam yüzeyi değişimi (NONE dahil) yalnız hatırlanır, kapanınca uygulanır.
	var pm: MonetizationManager = _main._ads
	_main._settings.age_info_button().pressed.emit()
	await _settle(1)
	var none_while_open: bool = pm.surface() == MonetizationManager.Surface.NONE
	_main._set_ad_surface(MonetizationManager.Surface.MAP)
	var held: bool = pm.surface() == MonetizationManager.Surface.NONE
	_panel().close_x().pressed.emit()
	await _settle(1)
	_c("panel açıkken yüzey NONE; o sırada gelen değişim (MAP) yalnız hatırlandı, kapanınca uygulandı", none_while_open
		and held and pm.surface() == MonetizationManager.Surface.MAP)
	_main._settings.age_info_button().pressed.emit()
	await _settle(1)
	_main._set_ad_surface(MonetizationManager.Surface.NONE)
	_panel().close_x().pressed.emit()
	await _settle(1)
	_c("... panel açıkken gelen NONE da hatırlandı: kapanınca banner yüzeyine DÖNÜLMEDİ", pm.surface() == MonetizationManager.Surface.NONE)
	await _teardown_main()


func _test_main_interstitial_and_desktop() -> void:
	print("-- Main: yaş bilinmeden round bitişinde geçiş reklamı YOK; eklentisiz masaüstünde yaş ekranı YOK")
	_seed(true, "", "")
	var fake := FakeAdBackend.new()
	await _boot(fake)
	_panel().close_panel()
	_main._start_level(load(LEVEL_10))
	await _settle(2)
	var m: MonetizationManager = _main._ads
	m._tick_active(MonetizationManager.INTERSTITIAL_INTERVAL_SEC + 5.0)
	var shown: bool = m.try_show_interstitial("round_finish", func() -> void: pass)
	_c("UNKNOWN: aktif süre saymaz, geçiş reklamı gösterilmez (age_gate), arka uca çağrı yok", not shown
		and m.active_elapsed_sec() == 0.0 and fake.interstitial_shows.is_empty() and fake.calls.is_empty())
	await _teardown_main()
	_seed(true, "", "")
	await _boot(null)
	_c("eklentisiz masaüstü (reklam yöneticisi yok): yaş ekranı / Yaş bilgisi satırı YOK (eski davranış)",
		_main._ads == null and not _panel().visible and not _main._settings.age_info_row().visible)
	await _teardown_main()
