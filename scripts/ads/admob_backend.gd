class_name AdmobBackend
extends AdBackend
## Gerçek AdMob arka ucu (M8.9-01): `addons/AdmobPlugin` v6.0'ın `Admob`
## düğümünü sarar ve eklenti sinyallerini AdBackend'in düz tipli
## sinyallerine çevirir. Yalnız Android'de, eklenti singleton'ı varsa
## yaratılır (`is_available()`); masaüstünde/headless'ta hiç kurulmaz —
## MonetizationManager o zaman arka uçsuz (UNAVAILABLE) kalır.
##
## Eklentinin RIZA API'si (v6.0): update_consent_info → consent_info_updated /
## consent_info_update_failed; get_consent_status; is_consent_form_available;
## load_consent_form → consent_form_loaded / consent_form_failed_to_load;
## show_consent_form → consent_form_dismissed. `canRequestAds()` ve
## `getPrivacyOptionsRequirementStatus()` sarmalayıcıda YOK — bkz.
## docs/monetization/PRIVACY_CONSENT.md §4 (eşdeğer türetme ve açık nokta).
##
## Kimlikler AdConfig'ten (android_export.cfg): test modunda Google örnek
## kimlikleri (rewarded, adaptive banner, interstitial — M8.9-02). Eklentinin
## kendi varsayılan "debug" kimlikleri KULLANILMAZ — banner için eklenti
## varsayılanı (…/2014213617) Google'ın katlanabilir banner örneği, bizim
## banner uyarlanabilir sabit (…/9214589741).

const SINGLETON_NAME: String = "AdmobPlugin"

var _admob: Admob
var _config: AdConfig


static func is_available() -> bool:
	return Engine.has_singleton(SINGLETON_NAME)


## Eklenti yoksa ya da yapılandırma geçersizse null (hata `config.error`).
static func create(config: AdConfig) -> AdmobBackend:
	if not is_available():
		return null
	if config == null or not config.is_valid():
		push_error("AdmobBackend: geçersiz reklam yapılandırması — %s" % (config.describe() if config != null else "null"))
		return null
	var backend := AdmobBackend.new()
	backend._config = config
	return backend


func backend_name() -> String:
	return "admob-plugin-6.0"


func attach(host: Node) -> void:
	if _admob != null:
		return
	_admob = Admob.new()
	_admob.name = "Admob"
	_admob.is_real = _config.is_real
	# Kimlikler: is_real'e göre ilgili takım okunur (Admob._ready seçer).
	_admob.android_debug_application_id = _config.app_id if not _config.is_real else ""
	_admob.android_real_application_id = _config.app_id if _config.is_real else ""
	_admob.android_debug_rewarded_id = _config.rewarded_id if not _config.is_real else Admob.ANDROID_REWARDED_DEMO_AD_UNIT_ID
	_admob.android_real_rewarded_id = _config.rewarded_id if _config.is_real else ""
	_admob.android_debug_banner_id = _config.banner_id if not _config.is_real else AdConfig.TEST_BANNER_ID
	_admob.android_real_banner_id = _config.banner_id if _config.is_real else ""
	_admob.android_debug_interstitial_id = _config.interstitial_id if not _config.is_real else AdConfig.TEST_INTERSTITIAL_ID
	_admob.android_real_interstitial_id = _config.interstitial_id if _config.is_real else ""
	# Banner: alt kenara sabit, uyarlanabilir, güvenli alanın (nav bar /
	# cutout) içinde — ekranlar UiKit.bottom_inset ile aynı payı ayırıyor.
	_admob.banner_position = LoadAdRequest.AdPosition.BOTTOM
	_admob.banner_size = LoadAdRequest.RequestedAdSize.ADAPTIVE
	_admob.banner_collapsible_position = LoadAdRequest.CollapsiblePosition.DISABLED
	_admob.banner_anchor_to_safe_area = true
	# Kitle/içerik: en muhafazakâr içerik derecesi (G); COPPA/TFUA etiketi
	# BİLEREK UNSPECIFIED — owner kararı bekleyen politika seçimi
	# (docs/monetization/PRIVACY_CONSENT.md §6). Tahmin edilmedi.
	_admob.max_ad_content_rating = AdmobConfig.ContentRating.G
	_admob.child_directed = AdmobConfig.TagForChildDirectedTreatment.UNSPECIFIED
	_admob.under_age_of_consent = AdmobConfig.TagForUnderAgeOfConsent.UNSPECIFIED
	_admob.auto_configure_on_initialize = true
	# Tek seferlik ödüllü reklam: gösterildikten sonra önbellekten düşer;
	# sonraki reklam MonetizationManager tarafından yeniden yüklenir.
	_admob.remove_rewarded_ads_after_displayed = true
	_admob.remove_rewarded_ads_after_scene = true
	_admob.remove_banner_ads_after_scene = true
	# Geçiş reklamı da tek kullanımlık (M8.9-02): gösterildikten sonra düşer,
	# yöneticisi sıradakini yükler; tek önbellekli reklam yeter.
	_admob.remove_interstitial_ads_after_displayed = true
	_admob.remove_interstitial_ads_after_scene = true
	_admob.max_rewarded_ad_cache = 3
	_admob.max_banner_ad_cache = 2
	_admob.max_interstitial_ad_cache = 2
	match _config.debug_geography:
		"disabled":
			_admob.debug_geography = ConsentRequestParameters.DebugGeography.DISABLED
		"eea":
			_admob.debug_geography = ConsentRequestParameters.DebugGeography.EEA
		"regulated_us_state":
			_admob.debug_geography = ConsentRequestParameters.DebugGeography.REGULATED_US_STATE
		"other":
			_admob.debug_geography = ConsentRequestParameters.DebugGeography.OTHER
		_:
			_admob.debug_geography = ConsentRequestParameters.DebugGeography.NOT_SET
	host.add_child(_admob)
	_connect()


func _connect() -> void:
	_admob.initialization_completed.connect(func(_status: InitializationStatus) -> void:
		initialization_completed.emit())
	_admob.consent_info_updated.connect(func() -> void: consent_info_updated.emit())
	_admob.consent_info_update_failed.connect(func(error: FormError) -> void:
		consent_info_update_failed.emit(error.get_code(), error.get_message()))
	_admob.consent_form_loaded.connect(func() -> void: consent_form_loaded.emit())
	_admob.consent_form_failed_to_load.connect(func(error: FormError) -> void:
		consent_form_failed_to_load.emit(error.get_code(), error.get_message()))
	_admob.consent_form_dismissed.connect(func(error: FormError) -> void:
		consent_form_dismissed.emit(error.get_code(), error.get_message()))

	_admob.rewarded_ad_loaded.connect(func(info: AdInfo, _response: ResponseInfo) -> void:
		rewarded_loaded.emit(info.get_ad_id()))
	_admob.rewarded_ad_failed_to_load.connect(func(info: AdInfo, error: LoadAdError) -> void:
		rewarded_failed_to_load.emit(info.get_ad_id(), error.get_code(), error.get_message()))
	_admob.rewarded_ad_showed_full_screen_content.connect(func(info: AdInfo) -> void:
		rewarded_showed.emit(info.get_ad_id()))
	_admob.rewarded_ad_failed_to_show_full_screen_content.connect(func(info: AdInfo, error: AdError) -> void:
		rewarded_failed_to_show.emit(info.get_ad_id(), error.get_code(), error.get_message()))
	_admob.rewarded_ad_impression.connect(func(info: AdInfo) -> void:
		rewarded_impression.emit(info.get_ad_id()))
	_admob.rewarded_ad_clicked.connect(func(info: AdInfo) -> void:
		rewarded_clicked.emit(info.get_ad_id()))
	_admob.rewarded_ad_user_earned_reward.connect(func(info: AdInfo, reward: RewardItem) -> void:
		rewarded_earned.emit(info.get_ad_id(), reward.get_type(), reward.get_amount()))
	_admob.rewarded_ad_dismissed_full_screen_content.connect(func(info: AdInfo) -> void:
		rewarded_dismissed.emit(info.get_ad_id()))

	_admob.interstitial_ad_loaded.connect(func(info: AdInfo, _response: ResponseInfo) -> void:
		interstitial_loaded.emit(info.get_ad_id()))
	_admob.interstitial_ad_failed_to_load.connect(func(info: AdInfo, error: LoadAdError) -> void:
		interstitial_failed_to_load.emit(info.get_ad_id(), error.get_code(), error.get_message()))
	_admob.interstitial_ad_showed_full_screen_content.connect(func(info: AdInfo) -> void:
		interstitial_showed.emit(info.get_ad_id()))
	_admob.interstitial_ad_failed_to_show_full_screen_content.connect(func(info: AdInfo, error: AdError) -> void:
		interstitial_failed_to_show.emit(info.get_ad_id(), error.get_code(), error.get_message()))
	_admob.interstitial_ad_impression.connect(func(info: AdInfo) -> void:
		interstitial_impression.emit(info.get_ad_id()))
	_admob.interstitial_ad_clicked.connect(func(info: AdInfo) -> void:
		interstitial_clicked.emit(info.get_ad_id()))
	_admob.interstitial_ad_dismissed_full_screen_content.connect(func(info: AdInfo) -> void:
		interstitial_dismissed.emit(info.get_ad_id()))

	_admob.banner_ad_loaded.connect(func(info: AdInfo, _response: ResponseInfo) -> void:
		banner_loaded.emit(info.get_ad_id(), info.get_measured_width(), info.get_measured_height(), false))
	_admob.banner_ad_refreshed.connect(func(info: AdInfo, _response: ResponseInfo) -> void:
		banner_loaded.emit(info.get_ad_id(), info.get_measured_width(), info.get_measured_height(), true))
	_admob.banner_ad_failed_to_load.connect(func(info: AdInfo, error: LoadAdError) -> void:
		banner_failed_to_load.emit(info.get_ad_id(), error.get_code(), error.get_message()))
	_admob.banner_ad_impression.connect(func(info: AdInfo) -> void:
		banner_impression.emit(info.get_ad_id()))
	_admob.banner_ad_clicked.connect(func(info: AdInfo) -> void:
		banner_clicked.emit(info.get_ad_id()))


func initialize() -> void:
	_admob.initialize()


func request_consent_update() -> void:
	# Parametreler düğümden: is_real, TFUA (UNSPECIFIED → gönderilmez),
	# test modunda debug coğrafyası + cihazın kendi hash'i (eklenti ekler).
	_admob.update_consent_info()


func consent_status() -> ConsentStatus:
	var status: UserConsent = _admob.get_consent_status()
	if status == null:
		return ConsentStatus.UNKNOWN
	match status.status:
		UserConsent.Status.NOT_REQUIRED:
			return ConsentStatus.NOT_REQUIRED
		UserConsent.Status.REQUIRED:
			return ConsentStatus.REQUIRED
		UserConsent.Status.OBTAINED:
			return ConsentStatus.OBTAINED
	return ConsentStatus.UNKNOWN


func is_consent_form_available() -> bool:
	return _admob.is_consent_form_available()


func load_consent_form() -> void:
	_admob.load_consent_form()


func show_consent_form() -> void:
	_admob.show_consent_form()


func load_rewarded() -> void:
	_admob.load_rewarded_ad()


func show_rewarded(ad_id: String) -> void:
	_admob.show_rewarded_ad(ad_id)


func remove_rewarded(ad_id: String) -> void:
	if _admob._active_rewarded_ads.has_key(ad_id):
		_admob.remove_rewarded_ad(ad_id)


func load_interstitial() -> void:
	_admob.load_interstitial_ad()


## Yalnız eklenti önbelleğinde olan (yüklü) kimlik gösterilir: eklentinin
## Java tarafı yüklenmemiş reklamda sessizce `Log.w` basıp HİÇBİR sinyal
## vermez — yönetici zaten yalnız READY iken çağırır ve gösterim onay zaman
## aşımı tutar (MonetizationManager.INTERSTITIAL_SHOW_CONFIRM_TIMEOUT).
func show_interstitial(ad_id: String) -> void:
	if _admob._active_interstitial_ads.has_key(ad_id):
		_admob.show_interstitial_ad(ad_id)


func remove_interstitial(ad_id: String) -> void:
	if _admob._active_interstitial_ads.has_key(ad_id):
		_admob.remove_interstitial_ad(ad_id)


func load_banner() -> void:
	_admob.load_banner_ad()


## Eklentinin `Admob` düğümü sahne ağacından çıkarken (uygulama kapanışı,
## test harness'inde yeniden kurulum) önbelleğindeki reklamları KENDİSİ
## kaldırır ve bu, yöneticinin `_exit_tree`'sinden ÖNCE olur (çocuk düğüm
## önce çıkar). Kaldırılmış bir kimlikle show/hide istemek eklentide
## `push_error` üretiyordu (A36 kapısı, logcat) — kimlik önbellekte yoksa
## sessizce atlanır; davranış değişmez.
func show_banner(ad_id: String) -> void:
	if _admob._active_banner_ads.has_key(ad_id):
		_admob.show_banner_ad(ad_id)


func hide_banner(ad_id: String) -> void:
	if _admob._active_banner_ads.has_key(ad_id):
		_admob.hide_banner_ad(ad_id)


func remove_banner(ad_id: String) -> void:
	if _admob._active_banner_ads.has_key(ad_id):
		_admob.remove_banner_ad(ad_id)


## SDK'nın portre sabit uyarlanabilir yüksekliği (tam ekran genişliği için).
func adaptive_banner_height_dp() -> int:
	var size: AdSize = _admob.get_portrait_adaptive_banner_size(-1)
	return size.get_height() if size != null else 0


func density() -> float:
	var dpi: int = DisplayServer.screen_get_dpi()
	return maxf(1.0, float(dpi) / 160.0) if dpi > 0 else 1.0
