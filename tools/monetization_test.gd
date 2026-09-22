extends Node
## Monetizasyon temelinin deterministik testi (M8.9-01/02, M9-01) — İNTERNET,
## CİHAZ VE EKLENTİ YOK. M9-01: izin kapısı UMP `canRequestAds()` (istek
## öncesi yeniden sorulur), gizlilik seçenekleri UMP'nin resmî durum/formu,
## eski eklenti için türetme geri düşüşü; yapılandırma kuralları ayrıntısı
## `release_config_test`'te. `FakeAdBackend` SDK'yı taklit eder; MonetizationManager'ın
## rıza yaşam döngüsü, ödüllü durum makinesi (devam + refill), banner yaşam
## döngüsü (Ana Sayfa / Harita / Mağaza / Koleksiyon / oyun; sonuç gizli),
## geri çekilme/önyükleme, analitik olay dikişi ve Main/UI entegrasyonu
## (gerçek pencereler, gerçek board, gerçek kota) doğrulanır. Geçiş reklamı
## ve günlük ödüller kendi suite'lerinde (`interstitial_test`,
## `daily_rewards_test`).
##
## KAYIT DOSYASINA YAZAR (kota/stok senaryoları). Test başında yedekler,
## sonunda byte-identical geri koyar ve bunu kontrol eder.
##
## Kullanım:
##   godot --headless --audio-driver Dummy --path . res://tools/monetization_test.tscn

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const LEVEL_10: String = "res://resources/levels/level_10.tres"


## Main'in ödüllü dikişini taklit eden hedef: yalnız sayar, hiçbir kural
## uygulamaz (kurallar Main + board + kota testlerinde gerçek nesnelerle).
class _MainStub extends Node:
	var revives: int = 0
	var revive_result: bool = true
	var power_grants: Array = []
	var power_result: bool = true
	var unavailable_revive: Array[String] = []
	var unavailable_power: Array[String] = []

	func grant_revive() -> bool:
		revives += 1
		return revive_result

	func grant_rewarded_power(type: int, token: int) -> bool:
		power_grants.append([type, token])
		return power_result

	func notify_rewarded_unavailable(message: String) -> void:
		unavailable_revive.append(message)

	func notify_power_rewarded_unavailable(message: String) -> void:
		unavailable_power.append(message)


var _fails: int = 0
var _checks: int = 0
var _saved: Dictionary = {}
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _main: Node2D
var _events: Array[Dictionary] = []
## Main betiği (statik test dikişi `ads_backend_override` için; const olamaz).
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
	# Onboarding tamam (M8.9-02): reklam ve yuva ancak o zaman; otomatik günlük
	# pencere bu suite'in konusu değil (daily_rewards_test).
	SaveManager.data["onboarding_completed"] = true
	DailyRewards.auto_popup_enabled = false
	# Geri çekilme / zaman aşımı sürelerini testte kısalt (5 s -> 10 ms).
	MonetizationManager.time_scale = 0.002
	AdEvents.subscribe(_on_event)

	_test_config()
	_test_events()
	_test_sources()
	await _test_consent_flow()
	await _test_consent_errors()
	await _test_privacy_options()
	await _test_can_request_ads_gate()
	await _test_rewarded_preload_and_success()
	await _test_rewarded_callback_safety()
	await _test_rewarded_failures()
	await _test_rewarded_lifecycle_edges()
	await _test_banner()
	await _test_onboarding_consent_defer()
	await _test_consent_kickoff_latch()
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


## Zamanlayıcılar için gerçek süre (time_scale sonrası) + birkaç kare.
func _wait(seconds_scaled: float) -> void:
	await get_tree().create_timer(seconds_scaled * MonetizationManager.time_scale + 0.05).timeout
	await _settle(2)


func _make_manager(fake: FakeAdBackend) -> MonetizationManager:
	var manager: MonetizationManager = MonetizationManager.create(fake, AdConfig.test_defaults())
	add_child(manager)
	return manager


func _free_manager(manager: MonetizationManager) -> void:
	if manager != null and is_instance_valid(manager):
		manager.queue_free()
	await _settle(2)


## Rıza gerekmiyor -> izin -> SDK hazır -> ilk ödüllü yükleme bekliyor.
func _boot(fake: FakeAdBackend) -> MonetizationManager:
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	fake.form_available = false
	var manager: MonetizationManager = _make_manager(fake)
	fake.complete_consent_update(true)
	fake.complete_init()
	return manager


# --- Yapılandırma / olaylar / kaynak ---------------------------------------------

func _test_config() -> void:
	print("-- yapılandırma (android_export.cfg; M9-01 build türü seçer — ayrıntı release_config_test)")
	var config: AdConfig = AdConfig.load_project()
	_c("android_export.cfg okundu", config.source == AdConfig.CONFIG_PATH)
	_c("editör/headless = DEBUG build → TEST modu (is_real=false)", not config.is_real
		and config.build_type == AdConfig.BuildType.DEBUG and AdConfig.current_build_type() == AdConfig.BuildType.DEBUG)
	_c("uygulama kimliği Google örnek app id", config.app_id == AdConfig.TEST_APP_ID)
	_c("ödüllü kimlik Google örnek rewarded id", config.rewarded_id == AdConfig.TEST_REWARDED_ID)
	_c("banner kimliği Google örnek ADAPTIVE banner id (katlanabilir değil)",
		config.banner_id == AdConfig.TEST_BANNER_ID and config.banner_id.ends_with("/9214589741"))
	_c("interstitial kimliği Google örnek interstitial id (M8.9-02)", config.interstitial_id == AdConfig.TEST_INTERSTITIAL_ID
		and config.interstitial_id.ends_with("/1033173712"))
	_c("yapılandırma geçerli", config.is_valid() and config.error == "")
	_c("debug coğrafyası ayarlanmadı", config.effective_debug_geography() == "")

	# Release kuralları (M9-01: RELEASE build türü) — geçici dosya ile.
	var tmp: String = "user://_ads_cfg_test.cfg"
	var file := ConfigFile.new()
	file.set_value("General", "is_real", true)
	file.set_value("Release", "app_id", "")
	file.set_value("Release", "rewarded_id", "")
	file.set_value("Release", "banner_id", "")
	file.set_value("Release", "interstitial_id", "")
	file.save(tmp)
	var real_missing := AdConfig.load_file(tmp, AdConfig.BuildType.RELEASE)
	_c("release + boş [Release] -> GEÇERSİZ (reklam başlatılmaz)", real_missing.is_real and not real_missing.is_valid())
	file.set_value("Release", "app_id", AdConfig.TEST_APP_ID)
	file.set_value("Release", "rewarded_id", AdConfig.TEST_REWARDED_ID)
	file.set_value("Release", "banner_id", AdConfig.TEST_BANNER_ID)
	file.set_value("Release", "interstitial_id", AdConfig.TEST_INTERSTITIAL_ID)
	file.save(tmp)
	_c("release + Google örnek kimliği -> GEÇERSİZ", not AdConfig.load_file(tmp, AdConfig.BuildType.RELEASE).is_valid())
	file.set_value("Release", "app_id", "ca-app-pub-1111111111111111~2222222222")
	file.set_value("Release", "rewarded_id", "ca-app-pub-1111111111111111/3333333333")
	file.set_value("Release", "banner_id", "ca-app-pub-1111111111111111/4444444444")
	file.set_value("Debug", "debug_geography", "EEA")
	file.save(tmp)
	_c("release + interstitial kimliği örnek -> GEÇERSİZ (fail-closed, M8.9-02)",
		not AdConfig.load_file(tmp, AdConfig.BuildType.RELEASE).is_valid())
	file.set_value("Release", "interstitial_id", "ca-app-pub-1111111111111111/5555555555")
	file.save(tmp)
	var real_ok := AdConfig.load_file(tmp, AdConfig.BuildType.RELEASE)
	_c("release + dolu [Release] (4 kimlik) -> geçerli, üretim kimlikleri seçildi",
		real_ok.is_valid() and real_ok.rewarded_id.ends_with("/3333333333") and real_ok.banner_id.ends_with("/4444444444")
		and real_ok.interstitial_id.ends_with("/5555555555"))
	_c("release'te debug coğrafyası HİÇ uygulanmaz (dosyada EEA olsa da)", real_ok.effective_debug_geography() == "")
	var same_file_debug := AdConfig.load_file(tmp, AdConfig.BuildType.DEBUG)
	_c("aynı dosya DEBUG build'de: yine Google örnekleri + coğrafya küçük harfe normalize (eea)", same_file_debug.is_valid()
		and not same_file_debug.is_real and same_file_debug.rewarded_id == AdConfig.TEST_REWARDED_ID
		and same_file_debug.effective_debug_geography() == "eea")
	file.set_value("General", "is_real", false)
	file.set_value("Debug", "debug_geography", "mars")
	file.save(tmp)
	var bad_geo := AdConfig.load_file(tmp, AdConfig.BuildType.DEBUG)
	_c("geçersiz debug_geography -> hata, reklam başlamaz", not bad_geo.is_valid() and bad_geo.debug_geography == "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	_c("eklentisiz platformda AdmobBackend.create null (masaüstü)", AdmobBackend.create(config) == null
		and not AdmobBackend.is_available())
	_c("eklentisiz platformda MonetizationManager.create null (Main sağlayıcısız kalır)", MonetizationManager.create() == null)


func _test_events() -> void:
	print("-- analitik olay dikişi (AdEvents)")
	AdEvents.clear_recent()
	var got: Array = []
	var listener := func(name: StringName, event: Dictionary) -> void: got.append([name, event])
	AdEvents.subscribe(listener)
	AdEvents.emit(&"rewarded_requested", {"placement": "revive"})
	AdEvents.emit(&"banner_loaded", {"ad_id": "b1"})
	_c("abone iki olayı aldı (ad + bağlam + zaman)", got.size() == 2 and got[0][0] == &"rewarded_requested"
		and got[0][1]["placement"] == "revive" and got[1][1].has("t_msec"))
	_c("recent/count/last", AdEvents.count(&"rewarded_requested") == 1 and AdEvents.last(&"banner_loaded")["ad_id"] == "b1"
		and AdEvents.recent().size() == 2)
	AdEvents.unsubscribe(listener)
	AdEvents.emit(&"banner_clicked", {})
	_c("abonelik kalkınca olay gitmez", got.size() == 2)
	for i in AdEvents.RECENT_LIMIT + 20:
		AdEvents.emit(&"banner_impression", {"i": i})
	_c("son olay tamponu sınırlı (RECENT_LIMIT)", AdEvents.recent().size() == AdEvents.RECENT_LIMIT)
	_c("olay adları listesi görev tanımıyla aynı (12 + 8 interstitial + 8 günlük = 28)", AdEvents.NAMES.size() == 28
		and AdEvents.NAMES.has(&"rewarded_earned") and AdEvents.NAMES.has(&"banner_clicked")
		and AdEvents.NAMES.has(&"interstitial_skipped_not_ready") and AdEvents.NAMES.has(&"daily_chest_result"))
	AdEvents.clear_recent()


func _test_sources() -> void:
	print("-- kaynak taraması")
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var manager_src: String = FileAccess.get_file_as_string("res://scripts/ads/monetization_manager.gd")
	var backend_src: String = FileAccess.get_file_as_string("res://scripts/ads/admob_backend.gd")
	var ads_src: String = manager_src + backend_src + FileAccess.get_file_as_string("res://scripts/ads/ad_config.gd")
	_c("Main sağlayıcıyı fabrikadan alır (MonetizationManager.create)", main_src.contains("MonetizationManager.create("))
	_c("Main eklenti sınıflarına (Admob / AdInfo) doğrudan dokunmaz",
		not main_src.contains("Admob.") and not main_src.contains("AdInfo") and not main_src.contains("load_rewarded_ad"))
	_c("pencereler (revive/refill) reklam yöneticisini bilmez",
		not FileAccess.get_file_as_string("res://scripts/ui/revive_offer.gd").contains("MonetizationManager")
		and not FileAccess.get_file_as_string("res://scripts/ui/power_refill.gd").contains("MonetizationManager"))
	_c("yönetici eklenti sınıflarını bilmez (yalnız AdBackend)", not manager_src.contains("Admob.")
		and not manager_src.contains("load_rewarded_ad") and not manager_src.contains("_plugin_singleton"))
	_c("app-open / rewarded-interstitial / native / mediation API'si üretim kodunda YOK (interstitial M8.9-02'de var)",
		not ads_src.contains("app_open") and not ads_src.contains("show_native") and not ads_src.contains("rewarded_interstitial")
		and not ads_src.contains("mediation") and ads_src.contains("load_interstitial"))
	_c("üretim kodunda IAP / Billing / analitik sağlayıcı yok", not ads_src.contains("Billing") and not ads_src.contains("Firebase")
		and not main_src.contains("Billing"))
	# Somut kimlikler (M9-01: AdConfig biçim desenleri kimlik değil — regex'le say).
	var concrete_ids: int = 0
	var foreign_ids: int = 0
	for found in RegEx.create_from_string("ca-app-pub-(\\d{16})[~/]\\d{10}").search_all(ads_src):
		concrete_ids += 1
		if found.get_string(1) != "3940256099942544":
			foreign_ids += 1
	_c("üretim kodunda Google örnek yayıncı dışında sabit reklam kimliği yok", concrete_ids >= 4 and foreign_ids == 0)
	_c("üretim kodu FakeAdBackend'i bilmez", not main_src.contains("FakeAdBackend") and not manager_src.contains("FakeAdBackend"))
	var cfg: String = FileAccess.get_file_as_string("res://addons/AdmobPlugin/android_export.cfg")
	_c("android_export.cfg: is_real=false, [Release] boş (üretim kimliği commit edilmedi)",
		cfg.contains("is_real=false") and cfg.count("=\"\"") >= 3)
	_c("ödül kilitli yollardan (Main.grant_revive / grant_rewarded_power / grant_daily_*) geçer, başka yol yok",
		manager_src.contains("main.grant_revive()") and manager_src.contains("main.grant_rewarded_power(")
		and manager_src.contains("main.grant_daily_chest(") and manager_src.contains("main.grant_daily_dough(")
		and not manager_src.contains("SaveManager.") and not manager_src.contains("RewardedPolicy.grant")
		and not manager_src.contains("DailyRewards."))
	_c("yönetici kayda yazmaz (save_game yok)", not manager_src.contains("save_game"))


# --- Rıza --------------------------------------------------------------------------

func _test_consent_flow() -> void:
	print("-- rıza (UMP) akışı")
	# 1. Rıza gerekmiyor.
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	var m: MonetizationManager = _make_manager(fake)
	_c("açılış: CONSENT_CHECKING, update istendi, SDK BAŞLATILMADI", m.ads_state() == MonetizationManager.AdsState.CONSENT_CHECKING
		and fake.consent_update_calls == 1 and fake.init_calls == 0 and fake.rewarded_loads == 0)
	_c("rıza beklerken ödüllü hazır değil + 'hazırlanıyor' notu", not m.is_rewarded_ready()
		and m.rewarded_note() == MonetizationManager.NOTE_PREPARING)
	fake.complete_consent_update(true)
	_c("NOT_REQUIRED -> ADS_ALLOWED, SDK başlatıldı (bir kez), form yok", m.ads_state() == MonetizationManager.AdsState.ADS_ALLOWED
		and m.ads_allowed() and fake.init_calls == 1 and fake.consent_form_loads == 0)
	_c("SDK hazır olmadan reklam yüklenmez", fake.rewarded_loads == 0 and not m.sdk_ready())
	fake.complete_init()
	_c("SDK hazır -> ödüllü önyükleme başladı (1 yükleme)", m.sdk_ready() and fake.rewarded_loads == 1
		and m.rewarded_state() == MonetizationManager.RewardedState.LOADING)
	_c("gizlilik seçenekleri gerekli değil (form yok)", not m.privacy_options_required())
	await _free_manager(m)

	# 2. Rıza gerekli + form var -> form -> OBTAINED (EEA: UMP gizlilik
	# seçeneklerini de REQUIRED döner — M9-01 resmî değer).
	fake = FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.REQUIRED
	fake.form_available = true
	fake.privacy_status = AdBackend.PrivacyOptionsStatus.REQUIRED
	m = _make_manager(fake)
	fake.complete_consent_update(true)
	_c("REQUIRED + form -> CONSENT_FORM, form yükleniyor, SDK yok", m.ads_state() == MonetizationManager.AdsState.CONSENT_FORM
		and fake.consent_form_loads == 1 and fake.init_calls == 0)
	fake.complete_form_load(true)
	_c("form yüklendi -> gösterildi", fake.consent_form_shows == 1)
	_c("form açıkken 'hazırlanıyor' (sonsuz bekleme yok, sahte hazır yok)", m.rewarded_note() == MonetizationManager.NOTE_PREPARING
		and not m.is_rewarded_ready())
	fake.dismiss_form(AdBackend.ConsentStatus.OBTAINED)
	_c("form kapandı, OBTAINED -> ADS_ALLOWED, SDK başlatıldı", m.ads_state() == MonetizationManager.AdsState.ADS_ALLOWED
		and fake.init_calls == 1)
	_c("form sunan bölgede gizlilik seçenekleri gerekli + sinyal", m.privacy_options_required())
	await _free_manager(m)

	# 3. Form reddi/hata: durum REQUIRED kalır -> reklam yok.
	fake = FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.REQUIRED
	fake.form_available = true
	m = _make_manager(fake)
	fake.complete_consent_update(true)
	fake.complete_form_load(true)
	fake.dismiss_form(-1, 4, "form error")
	_c("form hatayla kapandı, hâlâ REQUIRED -> ADS_NOT_ALLOWED, SDK yok, yeniden deneme planlı",
		m.ads_state() == MonetizationManager.AdsState.ADS_NOT_ALLOWED and fake.init_calls == 0 and m.has_pending_consent_retry())
	_c("izin yokken not 'şu anda kullanılamıyor'", m.rewarded_note() == MonetizationManager.NOTE_UNAVAILABLE and not m.is_rewarded_ready())
	await _wait(MonetizationManager.CONSENT_RETRY_DELAYS[0])
	_c("planlı rıza yeniden denemesi çalıştı (2. update)", fake.consent_update_calls == 2
		and m.ads_state() == MonetizationManager.AdsState.CONSENT_CHECKING)
	await _free_manager(m)

	# 4. REQUIRED ama form yok.
	fake = FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.REQUIRED
	fake.form_available = false
	m = _make_manager(fake)
	fake.complete_consent_update(true)
	_c("REQUIRED + form yok -> ADS_NOT_ALLOWED (reklam istenmez)", m.ads_state() == MonetizationManager.AdsState.ADS_NOT_ALLOWED
		and fake.init_calls == 0 and fake.rewarded_loads == 0)
	await _free_manager(m)


func _test_consent_errors() -> void:
	print("-- rıza hataları / önceki durum")
	# Güncelleme hatası, önceki oturum OBTAINED -> ERROR_WITH_PREVIOUS_STATE (izinli).
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.OBTAINED
	var m: MonetizationManager = _make_manager(fake)
	fake.complete_consent_update(false)
	_c("update hatası + önceki OBTAINED -> ERROR_WITH_PREVIOUS_STATE, reklam izinli, SDK başlatıldı",
		m.ads_state() == MonetizationManager.AdsState.ERROR_WITH_PREVIOUS_STATE and m.ads_allowed() and fake.init_calls == 1)
	_c("hata durumunda form açılmadı", fake.consent_form_loads == 0)
	await _free_manager(m)

	# Güncelleme hatası, önceki durum yok -> ADS_NOT_ALLOWED + sınırlı deneme.
	fake = FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.UNKNOWN
	m = _make_manager(fake)
	fake.complete_consent_update(false)
	_c("update hatası + önceki durum yok -> ADS_NOT_ALLOWED, SDK yok", m.ads_state() == MonetizationManager.AdsState.ADS_NOT_ALLOWED
		and fake.init_calls == 0 and m.has_pending_consent_retry())
	var calls_before: int = fake.consent_update_calls
	m.ensure_rewarded()
	_c("pencere açılışı hemen ardından ikinci update SPAM'lemez (min aralık)", fake.consent_update_calls == calls_before)
	await _wait(MonetizationManager.CONSENT_RETRY_DELAYS[0])
	_c("1. planlı deneme", fake.consent_update_calls == 2)
	fake.complete_consent_update(false)
	await _wait(MonetizationManager.CONSENT_RETRY_DELAYS[1])
	_c("2. planlı deneme", fake.consent_update_calls == 3)
	fake.complete_consent_update(false)
	await _wait(MonetizationManager.CONSENT_RETRY_DELAYS[1])
	_c("planlı denemeler SINIRLI (3 update'ten sonra dur)", fake.consent_update_calls == 3
		and not m.has_pending_consent_retry())
	await _wait(MonetizationManager.CONSENT_ON_DEMAND_MIN_INTERVAL)
	m.ensure_rewarded()
	_c("aralık geçince pencere açılışı bir update daha ister (ağ dönmüş olabilir)", fake.consent_update_calls == 4)
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	fake.complete_consent_update(true)
	_c("ağ dönünce izin -> SDK başlatıldı", m.ads_allowed() and fake.init_calls == 1)
	await _free_manager(m)

	# Hata + REQUIRED (önceki oturum rıza istemişti ama alınmamış) -> izin yok.
	fake = FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.REQUIRED
	fake.form_available = true
	m = _make_manager(fake)
	fake.complete_consent_update(false)
	_c("update hatası + önceki REQUIRED -> ADS_NOT_ALLOWED, form denenmez", m.ads_state() == MonetizationManager.AdsState.ADS_NOT_ALLOWED
		and fake.consent_form_loads == 0)
	await _free_manager(m)


func _test_privacy_options() -> void:
	print("-- gizlilik seçenekleri giriş noktası (M9-01: UMP getPrivacyOptionsRequirementStatus / showPrivacyOptionsForm)")
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.OBTAINED
	fake.form_available = true
	fake.privacy_status = AdBackend.PrivacyOptionsStatus.REQUIRED
	var m: MonetizationManager = _make_manager(fake)
	var changes: Array[bool] = []
	m.privacy_options_changed.connect(func(required: bool) -> void: changes.append(required))
	_c("yamalı arka uç: yönetici UMP'nin resmî çağrılarını kullanıyor", m.uses_privacy_api())
	_c("update öncesi gerekli değil (SDK sorulmadı)", not m.privacy_options_required())
	fake.complete_consent_update(true)
	fake.complete_init()
	_c("privacy status REQUIRED -> gerekli (sinyal true)", m.privacy_options_required() and changes == [true])
	m.set_surface(MonetizationManager.Surface.HOME)
	var banner_id: String = fake.complete_banner_load(true)
	_c("banner gösterildi (ön koşul)", m.banner_state() == MonetizationManager.BannerState.SHOWN and banner_id != "")
	_c("show_privacy_options -> SDK'nın showPrivacyOptionsForm'u (rıza formu yüklenmez)", m.show_privacy_options()
		and fake.privacy_form_shows == 1 and fake.consent_form_loads == 0)
	_c("form açıkken ikinci çağrı reddedilir; form kaplarken aktif süre sayılmaz", not m.show_privacy_options()
		and fake.privacy_form_shows == 1 and m.consent_form_covering())
	fake.dismiss_privacy_form(AdBackend.ConsentStatus.OBTAINED)
	_c("seçim sonrası izin sürer (canRequestAds), banner açık, SDK yeniden başlatılmadı",
		m.ads_allowed() and m.banner_state() == MonetizationManager.BannerState.SHOWN and fake.init_calls == 1
		and not m.consent_form_covering())
	# Rıza geri çekildi (SDK REQUIRED diyor → canRequestAds false): reklam durur.
	_c("show_privacy_options (2)", m.show_privacy_options() and fake.privacy_form_shows == 2)
	fake.dismiss_privacy_form(AdBackend.ConsentStatus.REQUIRED)
	_c("form sonrası canRequestAds false -> ADS_NOT_ALLOWED, banner GİZLENDİ, ödüllü hazır değil",
		m.ads_state() == MonetizationManager.AdsState.ADS_NOT_ALLOWED and fake.banner_hides.size() == 1
		and not m.is_rewarded_ready() and m.rewarded_note() == MonetizationManager.NOTE_UNAVAILABLE)
	_c("kullanıcı seçimi sonrası planlı rıza yeniden denemesi YOK (form ısrarı yok)", not m.has_pending_consent_retry())
	_c("REQUIRED iken giriş noktası görünür kalır (kullanıcı fikrini değiştirebilir)", m.privacy_options_required())
	# Fikrini değiştirdi: yeniden izin → reklam geri gelir, SDK yeniden başlatılmaz.
	_c("show_privacy_options (3)", m.show_privacy_options() and fake.privacy_form_shows == 3)
	fake.dismiss_privacy_form(AdBackend.ConsentStatus.OBTAINED)
	_c("yeniden izin -> ADS_ALLOWED, banner yeniden görünür, init tek", m.ads_allowed()
		and m.banner_state() == MonetizationManager.BannerState.SHOWN and fake.init_calls == 1)
	# Form hatası (ör. ağ): SDK durumu değişmedi → izin olduğu gibi kalır.
	_c("show_privacy_options (4)", m.show_privacy_options())
	fake.dismiss_privacy_form(-1, 2, "network")
	_c("form hatayla kapandı, izin değişmedi -> hâlâ ADS_ALLOWED, satır görünür", m.ads_allowed()
		and m.privacy_options_required())
	# Geç/yersiz kapanış sinyali (form açık değilken): yok sayılır.
	fake.dismiss_privacy_form(AdBackend.ConsentStatus.REQUIRED)
	_c("form açık değilken gelen kapanış sinyali yok sayılır (durum değişmez)", m.ads_allowed())
	fake.status = AdBackend.ConsentStatus.OBTAINED
	await _free_manager(m)

	fake = FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	fake.form_available = false
	fake.privacy_status = AdBackend.PrivacyOptionsStatus.NOT_REQUIRED
	m = _make_manager(fake)
	fake.complete_consent_update(true)
	_c("privacy status NOT_REQUIRED -> gerekli DEĞİL, show reddedilir, form açılmaz",
		not m.privacy_options_required() and not m.show_privacy_options() and fake.privacy_form_shows == 0
		and fake.consent_form_loads == 0)
	await _free_manager(m)

	# Form sunulan bölge ama UMP gizlilik seçeneklerini GEREKMEZ diyor (ör. ABD
	# dışı mesaj yok): M8.9 türetmesi burada "gerekli" derdi — artık SDK'nın dediği.
	fake = FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.OBTAINED
	fake.form_available = true
	fake.privacy_status = AdBackend.PrivacyOptionsStatus.NOT_REQUIRED
	m = _make_manager(fake)
	fake.complete_consent_update(true)
	_c("resmî değer türetmeyi ezer: form var ama status NOT_REQUIRED -> satır GİZLİ", not m.privacy_options_required())
	await _free_manager(m)

	# ABD eyalet mesajı: rıza NOT_REQUIRED, gizlilik seçenekleri REQUIRED (M8.9'un
	# açık noktası — türetme bunu göremiyordu).
	fake = FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	fake.form_available = false
	fake.privacy_status = AdBackend.PrivacyOptionsStatus.REQUIRED
	m = _make_manager(fake)
	fake.complete_consent_update(true)
	_c("NOT_REQUIRED + privacy REQUIRED (ABD eyalet mesajı) -> reklam izinli VE satır görünür", m.ads_allowed()
		and m.privacy_options_required())
	await _free_manager(m)

	# Eski (yamasız) eklenti: M8.9 türetmesi aynen çalışır (geri düşüş, uyarıyla).
	fake = FakeAdBackend.new()
	fake.privacy_api = false
	fake.status = AdBackend.ConsentStatus.OBTAINED
	fake.form_available = true
	m = _make_manager(fake)
	fake.complete_consent_update(true)
	fake.complete_init()
	_c("yamasız arka uç: türetme yolu (uses_privacy_api false), form var -> gerekli", not m.uses_privacy_api()
		and m.privacy_options_required() and m.ads_allowed())
	_c("yamasız: show_privacy_options -> rıza formu yüklenir (showPrivacyOptionsForm yok)", m.show_privacy_options()
		and fake.consent_form_loads == 1 and fake.privacy_form_shows == 0)
	fake.complete_form_load(true)
	fake.dismiss_form(AdBackend.ConsentStatus.REQUIRED)
	_c("yamasız: form sonrası REQUIRED -> ADS_NOT_ALLOWED", m.ads_state() == MonetizationManager.AdsState.ADS_NOT_ALLOWED)
	_c("yamasız: canRequestAds hiç çağrılmadı (türetme)", fake.can_request_calls == 0)
	await _free_manager(m)


## M9-01: izin kapısı UMP'nin resmî `canRequestAds()`'i — rıza durumundan
## türetilmez; SDK başlatma ve HER reklam yüklemesinden hemen önce yeniden sorulur.
func _test_can_request_ads_gate() -> void:
	print("-- UMP canRequestAds kapısı (M9-01)")
	# A. Durum OBTAINED ama SDK "istek yok" diyor → kapı SDK'nın dediği.
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.OBTAINED
	fake.can_request_override = 0
	var m: MonetizationManager = _make_manager(fake)
	fake.complete_consent_update(true)
	_c("OBTAINED ama canRequestAds false -> ADS_NOT_ALLOWED, SDK BAŞLATILMADI, yükleme yok",
		m.ads_state() == MonetizationManager.AdsState.ADS_NOT_ALLOWED and fake.init_calls == 0
		and fake.rewarded_loads == 0 and fake.interstitial_loads == 0 and fake.can_request_calls >= 1)
	_c("izinsizlikte sınırlı yeniden deneme planlandı (M8.9 aynen)", m.has_pending_consent_retry())
	await _free_manager(m)

	# B. Rıza durumu UNKNOWN ama SDK izin veriyor (UMP 3: mesaj yapılandırılmamış).
	fake = FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.UNKNOWN
	fake.can_request_override = 1
	m = _make_manager(fake)
	fake.complete_consent_update(true)
	_c("UNKNOWN ama canRequestAds true -> ADS_ALLOWED + SDK başlatıldı (SDK tek gerçek)", m.ads_allowed()
		and fake.init_calls == 1)
	await _free_manager(m)

	# C. Güncelleme HATASI + önceki oturumun geçerli rızası → reklam sürer.
	fake = FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.OBTAINED
	m = _make_manager(fake)
	fake.complete_consent_update(false)
	_c("update HATASI + önceki geçerli rıza (canRequestAds true) -> ERROR_WITH_PREVIOUS_STATE, SDK başlatıldı",
		m.ads_state() == MonetizationManager.AdsState.ERROR_WITH_PREVIOUS_STATE and m.ads_allowed() and fake.init_calls == 1)
	_c("geçici hata geçerli rızayı SİLMEDİ: yeniden deneme yok, form denenmedi", not m.has_pending_consent_retry()
		and fake.consent_form_loads == 0)
	fake.complete_init()
	_c("hata sonrası önyüklemeler açıldı (ödüllü + geçiş)", fake.rewarded_loads == 1 and fake.interstitial_loads == 1)
	await _free_manager(m)

	# D. Güncelleme HATASI + önceki rıza yok → reklam yok, sınırlı deneme.
	fake = FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.UNKNOWN
	m = _make_manager(fake)
	fake.complete_consent_update(false)
	_c("update HATASI + önceki rıza yok (canRequestAds false) -> ADS_NOT_ALLOWED + planlı deneme, SDK yok",
		m.ads_state() == MonetizationManager.AdsState.ADS_NOT_ALLOWED and m.has_pending_consent_retry() and fake.init_calls == 0)
	await _free_manager(m)

	# E. Rıza formu sonrası da karar canRequestAds'in.
	fake = FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.REQUIRED
	fake.form_available = true
	m = _make_manager(fake)
	fake.complete_consent_update(true)
	fake.complete_form_load(true)
	fake.can_request_override = 0
	fake.dismiss_form(AdBackend.ConsentStatus.OBTAINED)
	_c("form sonrası OBTAINED ama canRequestAds false -> ADS_NOT_ALLOWED + deneme, SDK yok",
		m.ads_state() == MonetizationManager.AdsState.ADS_NOT_ALLOWED and m.has_pending_consent_retry() and fake.init_calls == 0)
	await _free_manager(m)

	# F. HER yüklemeden hemen önce yeniden sorulur: izin sonradan kalkarsa
	# planlı yükleme gitmez, kayma yakalanır.
	fake = FakeAdBackend.new()
	m = _boot(fake)
	m.set_surface(MonetizationManager.Surface.HOME)
	fake.complete_banner_load(true)
	_c("ön koşul: izinli, SDK hazır, banner açık, ödüllü yükleniyor", m.ads_allowed()
		and m.banner_state() == MonetizationManager.BannerState.SHOWN and fake.rewarded_loads == 1)
	var calls_before: int = fake.can_request_calls
	for _i in 30:
		m._tick_active(1.0)
	await _settle(3)
	_c("canRequestAds her karede SORULMAZ (yalnız istek anlarında)", fake.can_request_calls == calls_before)
	fake.complete_rewarded_load(false)
	fake.can_request_override = 0
	await _wait(MonetizationManager.REWARDED_RETRY_DELAYS[0])
	_c("izin kalkınca planlı ödüllü yükleme GİTMEDİ (istek öncesi canRequestAds)", fake.rewarded_loads == 1)
	_c("kayma yakalandı -> ADS_NOT_ALLOWED, banner gizlendi, ödüllü hazır değil",
		m.ads_state() == MonetizationManager.AdsState.ADS_NOT_ALLOWED and fake.banner_hides.size() == 1
		and not m.is_rewarded_ready())
	fake.can_request_override = -1
	await _free_manager(m)


# --- Ödüllü -----------------------------------------------------------------------

func _test_rewarded_preload_and_success() -> void:
	print("-- ödüllü: önyükleme + başarı (devam / refill)")
	_events.clear()
	var fake := FakeAdBackend.new()
	var m: MonetizationManager = _boot(fake)
	var stub := _MainStub.new()
	add_child(stub)
	var avail: Array[int] = [0]
	m.rewarded_availability_changed.connect(func() -> void: avail[0] += 1)
	_c("SDK hazır -> LOADING, not 'hazırlanıyor', hazır değil", m.rewarded_state() == MonetizationManager.RewardedState.LOADING
		and m.rewarded_note() == MonetizationManager.NOTE_PREPARING and not m.is_rewarded_ready())
	var ad1: String = fake.complete_rewarded_load(true)
	_c("yüklendi -> READY, hazır, not boş, sinyal", m.rewarded_state() == MonetizationManager.RewardedState.READY
		and m.is_rewarded_ready() and m.rewarded_note() == "" and avail[0] >= 1)
	_c("olay: rewarded_loaded (preload)", _events_named(&"rewarded_loaded").size() == 1
		and _events_named(&"rewarded_loaded")[0]["placement"] == "preload")

	# Devam: talep -> gösterim -> ödül -> kapanış -> sonraki önyükleme.
	m.show_rewarded_revive(stub)
	_c("talep: SHOWING, backend show(ad1) tam bir kez, hazır değil, not 'gösteriliyor'",
		m.rewarded_state() == MonetizationManager.RewardedState.SHOWING and fake.rewarded_shows == [ad1]
		and not m.is_rewarded_ready() and m.rewarded_note() == MonetizationManager.NOTE_SHOWING and m.has_active_request())
	_c("olay: rewarded_requested placement=revive", _events_named(&"rewarded_requested").size() == 1
		and _events_named(&"rewarded_requested")[0]["placement"] == "revive")
	fake.emit_rewarded_showed(ad1)
	fake.emit_rewarded_impression(ad1)
	_c("olaylar: showed + impression (revive bağlamı)", _events_named(&"rewarded_showed").size() == 1
		and _events_named(&"rewarded_impression")[0]["placement"] == "revive")
	_c("gösterim sırasında ödül YOK", stub.revives == 0)
	fake.emit_rewarded_earned(ad1)
	_c("ödül callback'i -> Main.grant_revive tam bir kez, REWARD_EARNED", stub.revives == 1
		and m.rewarded_state() == MonetizationManager.RewardedState.REWARD_EARNED)
	_c("olay: rewarded_earned revive", _events_named(&"rewarded_earned").size() == 1
		and _events_named(&"rewarded_earned")[0]["placement"] == "revive" and not _events_named(&"rewarded_earned")[0].has("stale"))
	fake.emit_rewarded_dismissed(ad1)
	_c("kapanış: talep kapandı, sonraki reklam yükleniyor (2. yükleme), 'olmadı' bildirimi YOK",
		not m.has_active_request() and fake.rewarded_loads == 2 and m.rewarded_state() == MonetizationManager.RewardedState.LOADING
		and stub.unavailable_revive.is_empty())
	_c("olay: rewarded_dismissed earned=true", _events_named(&"rewarded_dismissed").size() == 1
		and _events_named(&"rewarded_dismissed")[0]["earned"] == true)

	# Refill: doğru güç + token.
	var ad2: String = fake.complete_rewarded_load(true)
	m.show_rewarded_power(stub, int(PowerUp.Type.BOMB), 7)
	_c("refill talebi: show(ad2), olay placement=refill power=bomb", fake.rewarded_shows == [ad1, ad2]
		and _events_named(&"rewarded_requested")[1]["placement"] == "refill"
		and _events_named(&"rewarded_requested")[1]["power"] == "bomb")
	fake.emit_rewarded_earned(ad2)
	_c("ödül -> Main.grant_rewarded_power(BOMB, 7) tam bir kez", stub.power_grants == [[int(PowerUp.Type.BOMB), 7]])
	fake.emit_rewarded_dismissed(ad2)
	_c("kapanış -> 3. yükleme (önyükleme sürüyor)", fake.rewarded_loads == 3)
	stub.queue_free()
	await _free_manager(m)


func _test_rewarded_callback_safety() -> void:
	print("-- ödüllü: callback güvenliği (çift / geç / eski / iptal / yanlış)")
	var fake := FakeAdBackend.new()
	var m: MonetizationManager = _boot(fake)
	var stub := _MainStub.new()
	add_child(stub)
	var ad1: String = fake.complete_rewarded_load(true)

	# Çift ödül callback'i.
	m.show_rewarded_revive(stub)
	fake.emit_rewarded_earned(ad1)
	fake.emit_rewarded_earned(ad1)
	_c("aynı reklam iki 'ödül' -> tek grant", stub.revives == 1)
	_c("ikinci ödül olayı stale işaretli", _events_named(&"rewarded_earned").size() >= 2
		and _events_named(&"rewarded_earned")[-1].get("stale", false) == true)
	fake.emit_rewarded_dismissed(ad1)

	# Kapanış sonrası ödül (yarış): talep kapandı, ödül yok.
	var ad2: String = fake.complete_rewarded_load(true)
	m.show_rewarded_power(stub, int(PowerUp.Type.SHAKE), 11)
	fake.emit_rewarded_dismissed(ad2)
	_c("ödülsüz kapanış -> Main'e 'olmadı' (tamamını izle), stok yok", stub.power_grants.is_empty()
		and stub.unavailable_power == [MonetizationManager.NOTE_NOT_EARNED])
	fake.emit_rewarded_earned(ad2)
	_c("kapanıştan SONRA gelen ödül HİÇBİR ŞEY vermez", stub.power_grants.is_empty())

	# Eski talebin callback'i yeni talebi etkilemez.
	var ad3: String = fake.complete_rewarded_load(true)
	m.show_rewarded_revive(stub)
	fake.emit_rewarded_earned(ad2)
	_c("eski reklamın (ad2) ödülü açık talebe (ad3) ödül vermez", stub.revives == 1)
	fake.emit_rewarded_dismissed(ad2)
	_c("eski reklamın kapanışı açık talebi kapatmaz (hâlâ SHOWING)", m.has_active_request()
		and m.rewarded_state() == MonetizationManager.RewardedState.SHOWING)
	fake.emit_rewarded_earned(ad3)
	_c("doğru reklamın ödülü verir", stub.revives == 2)
	fake.emit_rewarded_dismissed(ad3)

	# İptal: pencere kapandı / round bitti -> ödül yok, akış sürer.
	var ad4: String = fake.complete_rewarded_load(true)
	m.show_rewarded_power(stub, int(PowerUp.Type.BOMB), 12)
	m.cancel_rewarded_request()
	fake.emit_rewarded_earned(ad4)
	_c("iptal edilmiş talebin ödülü stok VERMEZ", stub.power_grants.is_empty())
	fake.emit_rewarded_dismissed(ad4)
	_c("iptal sonrası kapanış: 'olmadı' bildirimi yok, talep kapalı, önyükleme sürüyor",
		stub.unavailable_power.size() == 1 and not m.has_active_request() and m.rewarded_state() == MonetizationManager.RewardedState.LOADING)

	# Ekran değişti / Main yok oldu: çökme yok, ödül yok.
	var ad5: String = fake.complete_rewarded_load(true)
	var stub2 := _MainStub.new()
	add_child(stub2)
	m.show_rewarded_revive(stub2)
	stub2.free()
	fake.emit_rewarded_earned(ad5)
	fake.emit_rewarded_dismissed(ad5)
	_c("hedef Main silinmişken callback'ler çökmedi, akış sürdü", not m.has_active_request()
		and fake.rewarded_loads == 6)

	# Aynı anda ikinci tam ekran reklam yok.
	var ad6: String = fake.complete_rewarded_load(true)
	m.show_rewarded_revive(stub)
	m.show_rewarded_power(stub, int(PowerUp.Type.UPGRADE), 13)
	_c("gösterim sırasında ikinci talep reddedilir ('gösteriliyor'), backend show 1 kez",
		stub.unavailable_power[-1] == MonetizationManager.NOTE_SHOWING and fake.rewarded_shows.count(ad6) == 1)
	m.show_rewarded_revive(stub)
	_c("çift dokunuş: ikinci devam talebi de reddedilir", stub.unavailable_revive[-1] == MonetizationManager.NOTE_SHOWING
		and fake.rewarded_shows.size() == 6)
	fake.emit_rewarded_dismissed(ad6)

	# Hazır değilken talep: 'olmadı' + not, gösterim yok.
	_c("kapanış sonrası yeni yükleme bekliyor (LOADING)", m.rewarded_state() == MonetizationManager.RewardedState.LOADING)
	m.show_rewarded_revive(stub)
	_c("yüklenmemişken talep -> backend show YOK, Main'e 'hazırlanıyor'", fake.rewarded_shows.size() == 6
		and stub.unavailable_revive[-1] == MonetizationManager.NOTE_PREPARING and not m.has_active_request())
	stub.queue_free()
	await _free_manager(m)


func _test_rewarded_failures() -> void:
	print("-- ödüllü: yükleme / gösterim hataları, geri çekilme, zaman aşımı")
	var fake := FakeAdBackend.new()
	var m: MonetizationManager = _boot(fake)
	var stub := _MainStub.new()
	add_child(stub)
	_events.clear()

	# Yükleme hatası -> FAILED + geri çekilme (sınırlı).
	fake.complete_rewarded_load(false)
	_c("no-fill -> FAILED, deneme 1, yeniden deneme planlı, not 'şu anda kullanılamıyor'",
		m.rewarded_state() == MonetizationManager.RewardedState.FAILED and m.rewarded_attempts() == 1
		and m.has_pending_rewarded_retry() and m.rewarded_note() == MonetizationManager.NOTE_UNAVAILABLE and not m.is_rewarded_ready())
	_c("olay: rewarded_load_failed (code 3)", _events_named(&"rewarded_load_failed").size() == 1
		and _events_named(&"rewarded_load_failed")[0]["code"] == 3)
	_c("hata anında spam yok (hemen ikinci yükleme yok)", fake.rewarded_loads == 1)
	await _wait(MonetizationManager.REWARDED_RETRY_DELAYS[0])
	_c("geri çekilme sonrası 2. yükleme", fake.rewarded_loads == 2 and m.rewarded_state() == MonetizationManager.RewardedState.LOADING)
	for i in MonetizationManager.REWARDED_MAX_ATTEMPTS - 1:
		fake.complete_rewarded_load(false)
		if m.has_pending_rewarded_retry():
			await _wait(MonetizationManager.REWARDED_RETRY_DELAYS[mini(m.rewarded_attempts() - 1, MonetizationManager.REWARDED_RETRY_DELAYS.size() - 1)])
	_c("en fazla %d deneme, sonra durur (planlı deneme yok)" % MonetizationManager.REWARDED_MAX_ATTEMPTS,
		fake.rewarded_loads == MonetizationManager.REWARDED_MAX_ATTEMPTS and not m.has_pending_rewarded_retry()
		and m.rewarded_state() == MonetizationManager.RewardedState.FAILED)
	await _wait(MonetizationManager.ON_DEMAND_MIN_INTERVAL)
	m.ensure_rewarded()
	_c("pencere açılışı (talep) döngüyü sıfırlar: bir deneme daha", fake.rewarded_loads == MonetizationManager.REWARDED_MAX_ATTEMPTS + 1
		and m.rewarded_attempts() == 0)
	var loads_now: int = fake.rewarded_loads
	m.ensure_rewarded()
	_c("yükleme sürerken ensure ikinci yükleme açmaz", fake.rewarded_loads == loads_now)
	var ad_ok: String = fake.complete_rewarded_load(true)
	_c("başarı -> READY, deneme sayacı 0", m.is_rewarded_ready() and m.rewarded_attempts() == 0)

	# Gösterim hatası.
	m.show_rewarded_revive(stub)
	fake.emit_rewarded_show_failed(ad_ok)
	_c("show hatası -> Main'e 'gösterilemedi', ödül yok, reklam önbellekten düştü, yeni yükleme",
		stub.unavailable_revive == [MonetizationManager.NOTE_SHOW_FAILED] and stub.revives == 0
		and fake.rewarded_removed == [ad_ok] and not m.has_active_request()
		and m.rewarded_state() == MonetizationManager.RewardedState.LOADING)
	_c("olay: rewarded_show_failed revive", _events_named(&"rewarded_show_failed").size() == 1
		and _events_named(&"rewarded_show_failed")[0]["placement"] == "revive")

	# Zaman aşımı: SDK cevap vermiyor.
	var loads_before: int = fake.rewarded_loads
	await _wait(MonetizationManager.REWARDED_LOAD_TIMEOUT)
	_c("yükleme zaman aşımı -> FAILED + geri çekilme (sonsuz LOADING yok)",
		m.rewarded_state() == MonetizationManager.RewardedState.FAILED or fake.rewarded_loads > loads_before)
	# Geç gelen yükleme yine de kabul edilir (reklam gerçekten hazır).
	var late: String = fake.complete_rewarded_load(true)
	_c("zaman aşımından sonra gelen yükleme kabul: READY", late != "" and m.is_rewarded_ready())
	stub.queue_free()
	await _free_manager(m)


func _test_rewarded_lifecycle_edges() -> void:
	print("-- ödüllü: gösterim sırasında yükleme, arka plan, rıza kaybı")
	var fake := FakeAdBackend.new()
	var m: MonetizationManager = _boot(fake)
	var stub := _MainStub.new()
	add_child(stub)
	var ad1: String = fake.complete_rewarded_load(true)
	m.show_rewarded_revive(stub)
	# Gösterim sırasında (eski/paralel) bir yükleme tamamlanırsa: hazırda tut.
	fake.load_rewarded()
	var ad_extra: String = fake.complete_rewarded_load(true)
	_c("gösterim sırasında biten yükleme durumu bozmaz (hâlâ SHOWING)", m.rewarded_state() == MonetizationManager.RewardedState.SHOWING
		and ad_extra != "")
	fake.emit_rewarded_earned(ad1)
	fake.emit_rewarded_dismissed(ad1)
	_c("kapanışta hazırdaki reklam kullanılır: READY, ekstra yükleme yok", m.rewarded_state() == MonetizationManager.RewardedState.READY
		and m.is_rewarded_ready() and fake.rewarded_loads == 2)

	# Arka plan: reklam sırasında uygulama duraklar, geri gelince kapanış gelmezse.
	m.show_rewarded_revive(stub)
	m.notification(NOTIFICATION_APPLICATION_PAUSED)
	m.notification(NOTIFICATION_APPLICATION_RESUMED)
	_c("öne dönüşte hemen karar yok (kapanış sinyali bekleniyor)", m.rewarded_state() == MonetizationManager.RewardedState.SHOWING)
	await _wait(MonetizationManager.SHOW_RESUME_GRACE)
	_c("pay dolunca ödülsüz kapanış varsayıldı: talep kapandı, 'olmadı', yeni yükleme",
		not m.has_active_request() and stub.unavailable_revive[-1] == MonetizationManager.NOTE_NOT_EARNED
		and fake.rewarded_loads == 3 and stub.revives == 1)
	# Öne dönüşte kapanış zamanında gelirse pay iptal.
	var ad3: String = fake.complete_rewarded_load(true)
	m.show_rewarded_revive(stub)
	m.notification(NOTIFICATION_APPLICATION_PAUSED)
	m.notification(NOTIFICATION_APPLICATION_RESUMED)
	fake.emit_rewarded_earned(ad3)
	fake.emit_rewarded_dismissed(ad3)
	var revives_after: int = stub.revives
	var notes_after: int = stub.unavailable_revive.size()
	await _wait(MonetizationManager.SHOW_RESUME_GRACE)
	_c("zamanında gelen kapanış: pay tetiklenmedi, çift işlem yok", stub.revives == revives_after
		and stub.unavailable_revive.size() == notes_after and revives_after == 2)

	# Rıza kaybı: READY olsa da hazır sayılmaz.
	fake.complete_rewarded_load(true)
	_c("ön koşul: READY", m.is_rewarded_ready())
	fake.form_available = true
	fake.privacy_status = AdBackend.PrivacyOptionsStatus.REQUIRED
	fake.status = AdBackend.ConsentStatus.OBTAINED
	fake.complete_consent_update(true)
	_c("show_privacy_options", m.show_privacy_options())
	fake.dismiss_privacy_form(AdBackend.ConsentStatus.REQUIRED)
	_c("izin kalkınca yüklü reklam bile 'hazır' değil, not 'kullanılamıyor'", not m.is_rewarded_ready()
		and m.rewarded_note() == MonetizationManager.NOTE_UNAVAILABLE)
	m.show_rewarded_revive(stub)
	_c("izinsiz talep -> gösterim YOK", fake.rewarded_shows.size() == 3 and not m.has_active_request())
	stub.queue_free()
	await _free_manager(m)


# --- Banner ---------------------------------------------------------------------

func _test_banner() -> void:
	print("-- banner: yuva, yüzeyler, gezinme, hata, olaylar")
	_events.clear()
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	var m: MonetizationManager = _make_manager(fake)
	var window: Vector2 = Vector2(DisplayServer.window_get_size())
	var scale: float = 720.0 / window.x if window.x > 0.0 else 1.0
	var expected_slot: float = ceilf(64.0 * 2.625 * scale)
	_c("banner yuvası açılışta hesaplandı (64 dp × 2.625 → %d tuval px) ve UiKit'e yazıldı" % int(expected_slot),
		m.banner_slot_px() == expected_slot and UiKit.banner_slot() == expected_slot
		and UiKit.bottom_inset(Vector2(720, 1280)) == expected_slot)
	m.set_surface(MonetizationManager.Surface.HOME)
	_c("izin/SDK yokken Ana Sayfa'da banner istenmez", fake.banner_loads == 0)
	fake.complete_consent_update(true)
	fake.complete_init()
	_c("SDK hazır + Ana Sayfa -> banner yükleniyor (1)", fake.banner_loads == 1 and m.banner_state() == MonetizationManager.BannerState.LOADING)
	m.set_surface(MonetizationManager.Surface.RESULT)
	var b1: String = fake.complete_banner_load(true)
	_c("sonuç ekranındayken yüklenen banner GÖSTERİLMEZ (LOADED, gizli)", m.banner_state() == MonetizationManager.BannerState.LOADED
		and fake.banner_shows.is_empty())
	_c("olay: banner_loaded", _events_named(&"banner_loaded").size() == 1)
	m.set_surface(MonetizationManager.Surface.HOME)
	_c("Ana Sayfa -> gösterildi (aynı reklam, yeni yükleme yok)", m.banner_state() == MonetizationManager.BannerState.SHOWN
		and fake.banner_shows == [b1] and fake.banner_loads == 1)
	m.set_surface(MonetizationManager.Surface.MAP)
	_c("Harita -> gösterili kalır (M8.9-02 owner kararı: Harita banner yüzeyi)", m.banner_state() == MonetizationManager.BannerState.SHOWN
		and fake.banner_hides.is_empty())
	m.set_surface(MonetizationManager.Surface.GAMEPLAY)
	_c("oyun ekranı -> gösterili kalır (M8.9-02: oyun banner yüzeyi, ayrılmış yuva)", m.banner_state() == MonetizationManager.BannerState.SHOWN
		and fake.banner_hides.is_empty() and fake.banner_shows.size() == 1)
	m.set_surface(MonetizationManager.Surface.RESULT)
	_c("sonuç ekranı -> GİZLENDİ (tek hide)", m.banner_state() == MonetizationManager.BannerState.LOADED and fake.banner_hides == [b1])
	m.set_surface(MonetizationManager.Surface.NONE)
	_c("NONE -> gizli kalır, ikinci hide yok", fake.banner_hides.size() == 1)
	m.set_surface(MonetizationManager.Surface.SHOP)
	_c("Mağaza -> gösterildi", m.banner_state() == MonetizationManager.BannerState.SHOWN and fake.banner_shows.size() == 2)
	m.set_surface(MonetizationManager.Surface.COLLECTION)
	_c("Mağaza -> Koleksiyon: gösterili kalır, ekstra show/hide yok", m.banner_state() == MonetizationManager.BannerState.SHOWN
		and fake.banner_shows.size() == 2 and fake.banner_hides.size() == 1)
	m.set_surface(MonetizationManager.Surface.COLLECTION)
	_c("aynı yüzey tekrar: hiçbir çağrı yok", fake.banner_shows.size() == 2 and fake.banner_hides.size() == 1)
	_c("banner yüzeyleri: Ana Sayfa / Harita / Mağaza / Koleksiyon / oyun; sonuç dışarıda",
		MonetizationManager.BANNER_SURFACES.size() == 5 and MonetizationManager.BANNER_SURFACES.has(MonetizationManager.Surface.MAP)
		and MonetizationManager.BANNER_SURFACES.has(MonetizationManager.Surface.GAMEPLAY)
		and not MonetizationManager.BANNER_SURFACES.has(MonetizationManager.Surface.RESULT))
	fake.emit_banner_refreshed(b1)
	fake.emit_banner_impression(b1)
	fake.emit_banner_clicked(b1)
	_c("yenileme/gösterim/tıklama olayları, durum SHOWN", _events_named(&"banner_loaded").size() == 2
		and _events_named(&"banner_loaded")[1]["refreshed"] == true and _events_named(&"banner_impression").size() == 1
		and _events_named(&"banner_clicked").size() == 1 and m.banner_state() == MonetizationManager.BannerState.SHOWN)
	# Arka plan / öne dönüş: çift gösterim yok.
	m.notification(NOTIFICATION_APPLICATION_PAUSED)
	m.notification(NOTIFICATION_APPLICATION_RESUMED)
	_c("arka plan/öne dönüş: gösterili banner çift show almaz", fake.banner_shows.size() == 2)
	# Yönetici giderken banner gizlenir, yuva sıfırlanır.
	await _free_manager(m)
	_c("yönetici silinince banner gizlendi, yuva 0", fake.banner_hides.size() == 2 and UiKit.banner_slot() == 0.0)

	# Hata + geri çekilme.
	_events.clear()
	fake = FakeAdBackend.new()
	m = _boot(fake)
	m.set_surface(MonetizationManager.Surface.SHOP)
	fake.complete_banner_load(false)
	_c("banner no-fill -> FAILED, deneme 1, planlı yeniden deneme, yuva sabit (düzen zıplamaz)",
		m.banner_state() == MonetizationManager.BannerState.FAILED and m.banner_attempts() == 1 and m.has_pending_banner_retry()
		and UiKit.banner_slot() > 0.0)
	_c("olay: banner_load_failed", _events_named(&"banner_load_failed").size() == 1)
	m.set_surface(MonetizationManager.Surface.HOME)
	_c("yeniden deneme beklerken yüzey değişimi ek yükleme açmaz", fake.banner_loads == 1)
	await _wait(MonetizationManager.BANNER_RETRY_DELAYS[0])
	_c("geri çekilme sonrası 2. yükleme", fake.banner_loads == 2)
	for i in MonetizationManager.BANNER_MAX_ATTEMPTS - 1:
		fake.complete_banner_load(false)
		if m.has_pending_banner_retry():
			await _wait(MonetizationManager.BANNER_RETRY_DELAYS[mini(m.banner_attempts() - 1, MonetizationManager.BANNER_RETRY_DELAYS.size() - 1)])
	_c("banner denemesi sınırlı (%d), sonra durur" % MonetizationManager.BANNER_MAX_ATTEMPTS, fake.banner_loads == MonetizationManager.BANNER_MAX_ATTEMPTS
		and not m.has_pending_banner_retry())
	m.set_surface(MonetizationManager.Surface.RESULT)
	m.set_surface(MonetizationManager.Surface.HOME)
	_c("sınır dolunca gezinme yeni yükleme açmaz (spam yok)", fake.banner_loads == MonetizationManager.BANNER_MAX_ATTEMPTS)
	await _free_manager(m)

	# Yükleme sürerken yüzey değişimi.
	fake = FakeAdBackend.new()
	m = _boot(fake)
	m.set_surface(MonetizationManager.Surface.HOME)
	m.set_surface(MonetizationManager.Surface.RESULT)
	var b2: String = fake.complete_banner_load(true)
	_c("yükleme sürerken sonuca geçildi: yüklenen banner gösterilmedi", m.banner_state() == MonetizationManager.BannerState.LOADED
		and fake.banner_shows.is_empty() and b2 != "")
	m.set_surface(MonetizationManager.Surface.HOME)
	_c("Ana Sayfa'ya dönünce gösterildi", fake.banner_shows == [b2])
	await _free_manager(m)

	# Onboarding tamamlanmamış: yuva 0, hiçbir yüzeyde banner yok; tamamlanınca yuva + banner.
	fake = FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	m = _make_manager(fake)
	m.set_onboarding_completed(false)
	await _settle(1)
	fake.complete_consent_update(true)
	fake.complete_init()
	m.set_surface(MonetizationManager.Surface.HOME)
	m.set_surface(MonetizationManager.Surface.GAMEPLAY)
	_c("onboarding false: yuva 0, banner hiçbir yüzeyde yüklenmez, ödüllü yüklenmez", m.banner_slot_px() == 0.0
		and UiKit.banner_slot() == 0.0 and fake.banner_loads == 0 and fake.rewarded_loads == 0 and fake.interstitial_loads == 0)
	m.set_onboarding_completed(true)
	_c("onboarding true: yuva hesaplandı, banner + ödüllü + geçiş yüklemeleri başladı", m.banner_slot_px() == expected_slot
		and fake.banner_loads == 1 and fake.rewarded_loads == 1 and fake.interstitial_loads == 1)
	await _free_manager(m)


# --- Onboarding: rıza (UMP) ve reklam açılışı ertelemesi (M8.10 §18) --------------
#
# Tutorial sırasında ekranı bir gizlilik formu KAPLAMAMALI. Rıza şartı
# kaldırılmıyor, yalnız erteleniyor: ilk reklam talebinden ÖNCE mutlaka
# çalışıyor.

func _test_onboarding_consent_defer() -> void:
	print("-- onboarding: rıza + reklam açılışı ertelemesi (M8.10)")
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.REQUIRED
	fake.form_available = true
	var m: MonetizationManager = MonetizationManager.create(fake, AdConfig.test_defaults())
	# Main açılışta bunu AĞACA GİRMEDEN önce veriyor (yuva ekranlardan önce).
	m.set_onboarding_completed(false)
	add_child(m)
	await _settle(2)
	_c("onboarding false: UMP güncellemesi HİÇ istenmedi", not m.consent_started()
		and fake.consent_update_calls == 0)
	_c("onboarding false: rıza formu yüklenmedi/gösterilmedi",
		fake.consent_form_loads == 0 and fake.consent_form_shows == 0)
	_c("onboarding false: SDK başlatılmadı", fake.init_calls == 0 and not m.sdk_ready())
	_c("onboarding false: hiçbir reklam yüklenmedi", fake.rewarded_loads == 0
		and fake.interstitial_loads == 0 and fake.banner_loads == 0)
	_c("onboarding false: yuva 0", m.banner_slot_px() == 0.0)
	m._tick_active(1000.0)
	_c("onboarding false: aktif süre saati durdu",
		m.active_elapsed_sec() == 0.0 and not m.interstitial_eligible())
	_c("onboarding false: reklam gösterilemez (izin + SDK yok)", not m.is_rewarded_ready())

	# Tutorial bitti: rıza akışı ŞİMDİ başlar ve reklamdan ÖNCE tamamlanır.
	m.set_onboarding_completed(true)
	await _settle(1)
	_c("onboarding true: UMP güncellemesi tam bir kez istendi",
		m.consent_started() and fake.consent_update_calls == 1)
	_c("rıza gelmeden hâlâ reklam yüklenmiyor", fake.rewarded_loads == 0
		and fake.banner_loads == 0 and fake.interstitial_loads == 0)
	fake.complete_consent_update(true)
	await _settle(1)
	_c("rıza gerekli -> form yüklendi", fake.consent_form_loads == 1)
	fake.complete_form_load(true)
	await _settle(1)
	_c("form gösterildi", fake.consent_form_shows == 1)
	_c("form ekrandayken reklam yok ve saat saymıyor", m.consent_form_covering()
		and fake.rewarded_loads == 0)
	fake.dismiss_form(AdBackend.ConsentStatus.OBTAINED)
	await _settle(2)
	_c("rıza alındı -> SDK başlatıldı", fake.init_calls == 1)
	fake.complete_init()
	m.set_surface(MonetizationManager.Surface.HOME)
	await _settle(1)
	_c("rıza + SDK + onboarding: yüklemeler başladı", fake.rewarded_loads == 1
		and fake.interstitial_loads == 1 and fake.banner_loads == 1)
	_c("yuva artık hesaplandı", m.banner_slot_px() > 0.0)

	# İkinci kez true: rıza akışı YENİDEN başlatılmaz.
	m.set_onboarding_completed(true)
	await _settle(1)
	_c("aynı değer yeniden verilince rıza tekrar istenmez", fake.consent_update_calls == 1)
	await _free_manager(m)
	UiKit.set_banner_slot(0.0)


# --- Rıza kick-off latch'i: M8.9 yeniden deneme davranışı BOZULMADI (M8.10) -------
#
# M8.10, rıza akışının onboarding'e kadar başlamamasını istiyor. Bunun için
# eklenen `_consent_kickoff_done` LATCH'i YALNIZ kick-off noktalarını
# (`_ready`, `set_onboarding_completed(true)`) kapatır. Aşağıdaki kontroller
# M8.9'un yeniden deneme / geri çekilme / talep üzerine tazeleme yollarının
# latch tarafından BASTIRILMADIĞINI deterministik olarak kanıtlıyor.

func _test_consent_kickoff_latch() -> void:
	print("-- rıza kick-off latch'i (M8.10) — M8.9 yeniden deneme yolları korunuyor")

	# 1) onboarding false -> SIFIR güncelleme, latch kapalı.
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	var m: MonetizationManager = MonetizationManager.create(fake, AdConfig.test_defaults())
	m.set_onboarding_completed(false)
	add_child(m)
	await _settle(2)
	_c("onboarding false: sıfır consent update, latch kapalı",
		fake.consent_update_calls == 0 and not m.consent_started())
	# Yüzey/öne dönüş/pencere açılışı onboarding false iken de tetiklemez.
	for surface in [MonetizationManager.Surface.HOME, MonetizationManager.Surface.MAP,
			MonetizationManager.Surface.GAMEPLAY, MonetizationManager.Surface.SHOP]:
		m.set_surface(surface as MonetizationManager.Surface)
	m._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	m.ensure_rewarded()
	await _settle(1)
	_c("onboarding false: sekme/öne dönüş/pencere açılışı da tetiklemez",
		fake.consent_update_calls == 0 and fake.consent_form_loads == 0)

	# 2) İlk güvenli aktivasyon -> TAM BİR rıza akışı.
	m.set_onboarding_completed(true)
	await _settle(1)
	_c("ilk aktivasyon: tam bir consent update, latch açıldı",
		fake.consent_update_calls == 1 and m.consent_started())

	# 3) Başarılı güncellemeden SONRA: aynı çalışmada ikinci gereksiz update YOK.
	fake.complete_consent_update(true)
	fake.complete_init()
	await _settle(1)
	_c("başarı -> ADS_ALLOWED", m.ads_allowed() and m.sdk_ready())
	for i in 3:
		for surface in [MonetizationManager.Surface.HOME, MonetizationManager.Surface.MAP,
				MonetizationManager.Surface.COLLECTION, MonetizationManager.Surface.SHOP,
				MonetizationManager.Surface.GAMEPLAY, MonetizationManager.Surface.RESULT]:
			m.set_surface(surface as MonetizationManager.Surface)
		m._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		m._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		m.ensure_rewarded()
	m.set_onboarding_completed(false)
	m.set_onboarding_completed(true)
	await _settle(2)
	_c("başarıdan sonra sekme/öne dönüş/pencere/onboarding tekrarları İKİNCİ update göndermez",
		fake.consent_update_calls == 1)
	_c("izin korundu (ikinci update durumu CONSENT_CHECKING'e düşürmedi)",
		m.ads_allowed() and m.ads_state() == MonetizationManager.AdsState.ADS_ALLOWED)
	await _free_manager(m)

	# 4) Yeni uygulama açılışı = yeni yönetici örneği -> açılış güncellemesi YİNE olur.
	var fake2 := FakeAdBackend.new()
	fake2.status = AdBackend.ConsentStatus.NOT_REQUIRED
	var m2: MonetizationManager = _make_manager(fake2)
	await _settle(1)
	_c("yeni yönetici örneği: açılış rıza güncellemesi yeniden yapılır",
		fake2.consent_update_calls == 1 and m2.consent_started())
	await _free_manager(m2)

	# 5) HATA yolu: latch yeniden denemeleri BASTIRMAZ (M8.9 davranışı).
	var fake3 := FakeAdBackend.new()
	fake3.status = AdBackend.ConsentStatus.UNKNOWN
	var m3: MonetizationManager = _make_manager(fake3)
	_c("hata öncesi latch açık (kick-off yapıldı)", m3.consent_started())
	fake3.complete_consent_update(false)
	_c("update hatası -> ADS_NOT_ALLOWED + planlı yeniden deneme",
		m3.ads_state() == MonetizationManager.AdsState.ADS_NOT_ALLOWED
		and m3.has_pending_consent_retry())
	# 6a) Talep üzerine tazeleme spam yapmaz. Ölçüm HEMEN denemenin ardından:
	# aradaki her bekleme ON_DEMAND aralığını (ölçekte 0,04 sn) zaten doldurur.
	m3.ensure_rewarded()
	_c("aralık dolmadan talep üzerine update SPAM'lemez (latch'ten bağımsız)",
		fake3.consent_update_calls == 1)
	await _wait(MonetizationManager.CONSENT_RETRY_DELAYS[0])
	_c("latch AÇIKKEN 1. planlı yeniden deneme gitti (bastırma YOK)",
		fake3.consent_update_calls == 2 and m3.consent_started())
	fake3.complete_consent_update(false)
	await _wait(MonetizationManager.CONSENT_RETRY_DELAYS[1])
	_c("latch AÇIKKEN 2. planlı yeniden deneme gitti", fake3.consent_update_calls == 3)
	fake3.complete_consent_update(false)
	await _wait(MonetizationManager.CONSENT_RETRY_DELAYS[1])
	_c("yeniden denemeler M8.9'daki gibi SINIRLI (3'te durur)",
		fake3.consent_update_calls == 3 and not m3.has_pending_consent_retry())
	# 6b) Sınır dolduktan SONRA bile talep üzerine tazeleme çalışır (ağ dönüşü).
	m3.ensure_rewarded()
	_c("latch AÇIKKEN aralık geçince talep üzerine update gitti (ağ dönüşü)",
		fake3.consent_update_calls == 4)
	fake3.status = AdBackend.ConsentStatus.NOT_REQUIRED
	fake3.complete_consent_update(true)
	_c("kurtarma tamam: izin + SDK", m3.ads_allowed() and fake3.init_calls == 1)
	await _free_manager(m3)
	UiKit.set_banner_slot(0.0)


# --- Main entegrasyonu -----------------------------------------------------------

func _test_main_integration() -> void:
	print("-- Main entegrasyonu (gerçek pencereler + board + kota, sahte SDK)")
	# Bu bölüm zamanlayıcı beklemez; level açılışı yavaş karelerde 60 s'lik
	# (ölçekli 0.12 s) yükleme zaman aşımını tetiklemesin diye ölçek gevşetilir.
	MonetizationManager.time_scale = 0.05
	get_window().size = Vector2i(720, 1280)
	await _settle(2)
	# Taban: yöneticisiz Main'de OYNA konumu.
	_main_script.ads_backend_override = null
	var base_main: Node2D = MAIN_SCENE.instantiate()
	add_child(base_main)
	await _settle(3)
	_c("eklentisiz masaüstünde Main sağlayıcısız (eski davranış)", base_main._ads == null
		and base_main._rewarded_provider == null and UiKit.banner_slot() == 0.0)
	var base_play_y: float = base_main._screens[0]._play_pulse.position.y
	base_main.queue_free()
	await _settle(2)

	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	# Gerçekçi en büyük yuva (M8.9-02): 64 dp × 2.0 → 128 tuval px (telefonlarda
	# uyarlanabilir banner 50–64 dp / 320–412 dp genişlik → 87–128 px; 720 px
	# pencerede A36 yoğunluğu 168 px'lik gerçek dışı bir yuva üretirdi).
	fake.adaptive_height_dp = 64
	fake.density_value = 2.0
	_main_script.ads_backend_override = fake
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _settle(3)
	_main_script.ads_backend_override = null
	var m: MonetizationManager = _main._ads
	_c("Main yöneticiyi yarattı ve sağlayıcı olarak taktı", m != null and _main._rewarded_provider == m
		and m.get_parent() == _main)
	var slot: float = m.banner_slot_px()
	var play_y: float = _main._screens[0]._play_pulse.position.y
	_c("banner yuvası ekranlardan önce hesaplandı: Ana Sayfa OYNA yuva kadar yukarıda (%d px)" % int(slot),
		slot > 0.0 and is_equal_approx(base_play_y - play_y, slot))
	_c("Ana Sayfa yüzeyi seçildi", m.surface() == MonetizationManager.Surface.HOME)
	fake.complete_consent_update(true)
	fake.complete_init()
	_c("SDK hazır: Ana Sayfa'da banner yükleniyor, ödüllü önyükleniyor", fake.banner_loads == 1 and fake.rewarded_loads == 1)
	var b1: String = fake.complete_banner_load(true)
	_c("banner Ana Sayfa'da gösterildi", fake.banner_shows == [b1])
	_main._show_tab(1)
	await _settle(2)
	var map_screen: CanvasLayer = _main._screens[1]
	_c("Harita -> banner gösterili kalır (M8.9-02), Harita dünyası yuvanın üstünde biter", fake.banner_hides.is_empty()
		and is_equal_approx(map_screen.world_rect().end.y, 1280.0 - slot))
	var slot_top: float = 1280.0 - slot
	var nodes_clear: bool = true
	for node in map_screen.nodes():
		nodes_clear = nodes_clear and node.get_global_rect().end.y <= slot_top
		if node._plaque.visible:
			nodes_clear = nodes_clear and node._plaque.get_global_rect().end.y <= slot_top
	_c("Harita: 10 düğüm (+ plaka) ve Sonsuz kalesi yuvaya girmiyor, kale üst satırın altında",
		nodes_clear and map_screen.endless_node().get_global_rect().position.y >= map_screen.top_bar().get_global_rect().end.y
		and map_screen.endless_node().get_global_rect().end.y <= slot_top)
	_c("Harita dünya dikey sıkıştırması sınırlı (>= 0.94) ve yatay ölçek cover", map_screen.world_scale().y >= 0.94
		and map_screen.world_scale().y <= map_screen.world_scale().x + 0.001)
	_main._show_tab(3)
	_c("Mağaza -> gösterili kalır", fake.banner_shows.size() == 1 and fake.banner_hides.is_empty())
	_main._show_tab(2)
	_c("Koleksiyon -> gösterili kalır", fake.banner_shows.size() == 1 and fake.banner_hides.is_empty())
	_main._show_tab(0)

	# Devam akışı: pencere açıkken reklam yüklenir, CTA açılır, ödül board'a gider.
	_main._start_level(load(LEVEL_10))
	await _settle(2)
	_c("oyun -> banner gösterili kalır (GAMEPLAY yüzeyi), banner seam = yuva, board seam'in üstünde",
		m.surface() == MonetizationManager.Surface.GAMEPLAY and fake.banner_hides.is_empty()
		and is_equal_approx((_main._board.layout()["banner"] as Rect2).size.y, slot)
		and _main._board.board_screen_rect().end.y <= (_main._board.layout()["banner"] as Rect2).position.y)
	var board: Node2D = _main._board
	var finished: Array[int] = [0]
	board.round_finished.connect(func(_won: bool) -> void: finished[0] += 1)
	var offer: CanvasLayer = _main._revive
	var bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	board._enter_fail_pending()
	await _settle(3)
	_c("devam penceresi açık, reklam henüz yüklenmedi -> CTA PASİF + dürüst not (hazırlanıyor / kullanılamıyor)",
		offer.visible and offer.continue_button().disabled
		and (offer.note_text() == MonetizationManager.NOTE_PREPARING or offer.note_text() == MonetizationManager.NOTE_UNAVAILABLE))
	var ad1: String = fake.complete_rewarded_load(true)
	await _settle(1)
	_c("reklam yüklendi -> pencere tazelendi: CTA AKTİF, not boş", not offer.continue_button().disabled
		and offer.note_text() == "" and offer.provider_ready())
	offer.continue_button().pressed.emit()
	await _settle(2)
	_c("DEVAM ET -> backend show(ad1) tam bir kez, CTA kilitli ('isteniyor')", fake.rewarded_shows == [ad1]
		and offer.is_request_pending() and offer.continue_button().disabled)
	offer.continue_button().pressed.emit()
	await _settle(1)
	_c("çift dokunuş ikinci gösterim üretmez", fake.rewarded_shows.size() == 1)
	_c("gösterim sırasında hak tüketilmedi, round bitmedi, kayıt yazılmadı", board.revives_used() == 0
		and board.is_fail_pending() and finished[0] == 0 and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == bytes_before)
	fake.emit_rewarded_showed(ad1)
	fake.emit_rewarded_earned(ad1)
	await _settle(2)
	_c("ödül -> board devam etti (1/2), pencere kapandı", board.revives_used() == 1 and not board.is_fail_pending()
		and not offer.visible)
	fake.emit_rewarded_dismissed(ad1)
	await _settle(1)
	_c("kapanış -> sonraki reklam yükleniyor", fake.rewarded_loads == 2)
	_c("devam kayda yazmadı", FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == bytes_before)

	# Ödülsüz kapanış: teklif açık kalır, hak aynı, CTA yeni reklam gelince açılır.
	var ad2: String = fake.complete_rewarded_load(true)
	board._enter_fail_pending()
	await _settle(3)
	_c("2. teklif (1/2), CTA aktif", offer.visible and offer.remaining_text() == "1 / 2" and not offer.continue_button().disabled)
	offer.continue_button().pressed.emit()
	await _settle(1)
	fake.emit_rewarded_dismissed(ad2)
	await _settle(2)
	_c("ödülsüz kapanış: teklif açık, hak 1 (tüketilmedi), not 'tamamını izle', CTA yeni reklam gelene kadar pasif",
		offer.visible and board.revives_used() == 1 and board.is_fail_pending()
		and offer.note_text() == MonetizationManager.NOTE_NOT_EARNED and offer.continue_button().disabled)
	var ad3: String = fake.complete_rewarded_load(true)
	await _settle(1)
	_c("yeni reklam -> CTA yeniden aktif (tekrar dene)", not offer.continue_button().disabled)
	offer.continue_button().pressed.emit()
	await _settle(1)
	fake.emit_rewarded_earned(ad3)
	fake.emit_rewarded_dismissed(ad3)
	await _settle(2)
	_c("2. ödül -> 2/2 kullanıldı", board.revives_used() == 2 and board.revives_remaining() == 0)
	fake.complete_rewarded_load(true)
	board._enter_fail_pending()
	await _settle(2)
	_c("3. teklif: hak yok -> CTA pasif, 'hakkın bitti' (reklam hazır olsa da)", offer.visible
		and offer.continue_button().disabled and offer.note_text() == offer.NOTE_EXHAUSTED and m.is_rewarded_ready())
	_c("hak yokken grant_revive() false (round başına 2 KİLİTLİ)", not _main.grant_revive())
	_main.decline_revive()
	await _settle(2)
	_c("BİTİR -> round bitti, reklam talebi yok", finished[0] == 1 and not m.has_active_request())
	await _settle(2)
	_main._result.hide_result()
	_main.abandon_run()
	await _settle(2)

	# Refill akışı: kota + doğru güç + token; KAPAT iptali.
	SaveManager.data["dough"] = 500
	SaveManager.data["powerups"] = {"bomb": 0, "upgrade": 0, "shake": 0, "clear_small": 0}
	SaveManager.data["rewarded_power_date"] = ""
	SaveManager.data["rewarded_power_grants"] = 0
	_main._start_level(load(LEVEL_10))
	await _settle(2)
	board = _main._board
	var refill: CanvasLayer = _main._refill
	_c("ön koşul: ödüllü hazır", m.is_rewarded_ready())
	board._on_power_refill_requested(int(PowerUp.Type.BOMB))
	await _settle(3)
	_c("refill açık: REKLAM İZLE aktif, kota 1/1", refill.visible and not refill._ad.disabled and refill._quota.text.contains("1/1"))
	refill._ad.pressed.emit()
	await _settle(2)
	var req: Dictionary = m.request_info()
	_c("talep: doğru güç (bomb) + Main token'ı, backend show 1", req["active"] and req["type"] == int(PowerUp.Type.BOMB)
		and req["token"] == _main._refill_pending_token and fake.rewarded_shows.size() == 4)
	var ad_r: String = req["ad_id"]
	fake.emit_rewarded_earned(ad_r)
	await _settle(2)
	_c("ödül -> Bomba stoğu 1, kota tüketildi (1 grant), pencere kapandı, oyun sürüyor",
		SaveManager.powerup_count(PowerUp.Type.BOMB) == 1 and RewardedPolicy.remaining_today() == 0
		and not refill.visible and not board.is_refill_pending())
	_c("diğer üç güç stoğu 0 (yanlış güce stok yok)", SaveManager.powerup_count(PowerUp.Type.UPGRADE) == 0
		and SaveManager.powerup_count(PowerUp.Type.SHAKE) == 0 and SaveManager.powerup_count(PowerUp.Type.CLEAR_SMALL) == 0)
	fake.emit_rewarded_earned(ad_r)
	_c("çift ödül callback'i ikinci stok VERMEZ", SaveManager.powerup_count(PowerUp.Type.BOMB) == 1)
	fake.emit_rewarded_dismissed(ad_r)
	await _settle(1)
	fake.complete_rewarded_load(true)
	_c("olay bağlamı: rewarded_earned placement=refill power=bomb", _events_named(&"rewarded_earned").size() > 0
		and _events_named(&"rewarded_earned")[-2 if _events_named(&"rewarded_earned").size() > 1 else -1]["placement"] == "refill")
	# Kota dolu: başka güç için CTA pasif, SDK'ya gösterim gitmez.
	board._on_power_refill_requested(int(PowerUp.Type.SHAKE))
	await _settle(3)
	_c("kota dolu (dört gücün toplamı) -> Sarsıntı'da REKLAM İZLE pasif + kota notu, reklam hazır olsa da",
		refill.visible and refill._ad.disabled and refill.ad_note_text() == refill.NOTE_QUOTA_USED and m.is_rewarded_ready())
	refill._on_ad_pressed()
	await _settle(1)
	_c("kota doluyken talep SDK'ya gitmez", fake.rewarded_shows.size() == 4)
	_main._on_refill_closed()
	await _settle(1)
	# Yarın: kota yenilenir; KAPAT ile iptal -> geç ödül stok vermez.
	SaveManager.data["rewarded_power_date"] = ""
	SaveManager.data["rewarded_power_grants"] = 0
	board._on_power_refill_requested(int(PowerUp.Type.UPGRADE))
	await _settle(3)
	refill._ad.pressed.emit()
	await _settle(1)
	var ad_c: String = m.request_info()["ad_id"]
	_main._on_refill_closed()
	await _settle(1)
	_c("KAPAT: talep iptal (yönetici), Main token'ı sıfır, oyun sürüyor", m.request_info()["cancelled"]
		and _main._refill_pending_token == 0 and not board.is_refill_pending())
	fake.emit_rewarded_earned(ad_c)
	fake.emit_rewarded_dismissed(ad_c)
	await _settle(1)
	_c("iptalden sonra gelen ödül stok VERMEZ, kota tüketmez", SaveManager.powerup_count(PowerUp.Type.UPGRADE) == 0
		and RewardedPolicy.remaining_today() == 1)
	# Round terk edilirken açık talep: board silinir, ödül yok.
	fake.complete_rewarded_load(true)
	board._on_power_refill_requested(int(PowerUp.Type.CLEAR_SMALL))
	await _settle(3)
	refill._ad.pressed.emit()
	await _settle(1)
	var ad_a: String = m.request_info()["ad_id"]
	_main.abandon_run()
	await _settle(2)
	fake.emit_rewarded_earned(ad_a)
	fake.emit_rewarded_dismissed(ad_a)
	await _settle(1)
	_c("round terk edildikten sonra gelen ödül stok VERMEZ, çökme yok", SaveManager.powerup_count(PowerUp.Type.CLEAR_SMALL) == 0
		and _main._board == null and m.surface() == MonetizationManager.Surface.MAP)
	_c("gezinme döngüsü boyunca tek AdView (1 yükleme), sonuç dışında hide yok", fake.banner_loads == 1
		and fake.banner_shows.size() == 1)

	# Ayarlar: gizlilik seçenekleri satırı SDK'ya göre.
	var settings: CanvasLayer = _main._settings
	_main.open_settings()
	await _settle(2)
	_c("form sunulmayan bölgede 'Gizlilik seçenekleri' satırı GİZLİ", not settings.privacy_options_row().visible)
	_c("gizlilik metni reklamı doğru anlatıyor (AdMob, geçiş reklamı dahil, satın alma yok)", settings.PRIVACY_TEXT.contains("AdMob")
		and settings.PRIVACY_TEXT.contains("geçiş") and settings.PRIVACY_TEXT.contains("satın alma yok")
		and not settings.PRIVACY_TEXT.contains("reklam ve uygulama içi satın alma da yok"))
	_main.close_settings()
	fake.form_available = true
	fake.privacy_status = AdBackend.PrivacyOptionsStatus.REQUIRED
	fake.status = AdBackend.ConsentStatus.OBTAINED
	fake.complete_consent_update(true)
	_main.open_settings()
	await _settle(2)
	_c("UMP privacy status REQUIRED -> satır GÖRÜNÜR ('Gizlilik seçenekleri' + Aç)", settings.privacy_options_row().visible
		and settings.privacy_options_button().text == settings.PRIVACY_OPTIONS_BUTTON)
	_c("gizlilik politikası URL'i yok -> 'Gizlilik politikası' satırı GİZLİ (M9-01, sahte bağlantı yok)",
		not settings.privacy_policy_row().visible)
	settings.privacy_options_button().pressed.emit()
	await _settle(1)
	_c("Aç -> SDK'nın gizlilik seçenekleri formu (showPrivacyOptionsForm)", fake.privacy_form_shows == 1
		and fake.consent_form_loads == 0)
	fake.dismiss_privacy_form(AdBackend.ConsentStatus.OBTAINED)
	await _settle(1)
	_c("form kapandı, izin sürüyor, satır hâlâ görünür", m.ads_allowed() and settings.privacy_options_row().visible)
	_main.close_settings()

	_main.queue_free()
	await _settle(2)
	_c("Main silinince banner yuvası sıfırlandı", UiKit.banner_slot() == 0.0)


func _restore_save_file() -> void:
	if not _had_save:
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()
