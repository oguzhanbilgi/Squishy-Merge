class_name MonetizationManager
extends Node
## Tek üretim reklam soyutlaması (M8.9-01/02): rıza (UMP) yaşam döngüsü, SDK
## başlatma, ödüllü reklam durum makinesi (devam + refill + günlük sandık +
## günlük Hamur), geçiş (interstitial) reklamı durum makinesi + aktif süre
## saati + doğal-mola politikası, banner yaşam döngüsü, hazırlık/önbellek
## stratejisi ve analitik olay dikişi.
##
## Oyun/UI eklenti içlerini BİLMEZ: Main bu düğümü mevcut sağlayıcı dikişine
## (`Main.set_rewarded_provider`) takar ve yalnız şu yüzeyi kullanır:
##   show_rewarded_revive(main) / show_rewarded_power(main, type, token)
##   show_rewarded_daily_chest(main, day_key, token) /
##   show_rewarded_daily_dough(main, day_key, token)
##   is_rewarded_ready() / rewarded_note() / ensure_rewarded()
##   cancel_rewarded_request() / set_surface(surface)
##   try_show_interstitial(break_name, continue_callback)
##   set_onboarding_completed(done)
##   privacy_options_required() / show_privacy_options()
## SDK tarafı `AdBackend` arayüzü (gerçek: AdmobBackend; testler tools/
## altındaki sahte arka uçla aynı arayüzü sürer).
##
## KİLİTLİ ÜRÜN KURALLARI (GAME_DESIGN §5.7.3 / §11 / docs/monetization/
## DAILY_REWARDS.md) burada DEĞİŞMEZ:
##   - devam hakkı yalnız `Main.grant_revive()` ile (round başına 2, board sayar)
##   - ödüllü refill yalnız `Main.grant_rewarded_power(type, token)` ile
##     (günde 1, dört gücün toplamı; kotayı RewardedPolicy tüketir)
##   - günlük reklamlı sandık / Hamur yalnız `Main.grant_daily_chest(day_key,
##     token)` / `Main.grant_daily_dough(day_key, token)` ile (günde 2 / 1;
##     kotayı DailyRewards tüketir)
##   - hepsi YALNIZ SDK'nın "ödül kazanıldı" callback'iyle ve yalnız açık
##     talebin ad_id'siyle bir kez; kapanma / yüklenememe / gösterilememe /
##     çevrimdışı HİÇBİR ŞEY vermez ve kota tüketmez.
##
## Rıza (UMP) — SDK durumu tek gerçek, kendi GDPR önbelleğimiz yok:
##   her açılışta update → gerekiyorsa form → durum → ADS_ALLOWED /
##   ADS_NOT_ALLOWED; update hata verirse SDK'nın önceki oturumdan taşıdığı
##   durum kullanılır (ERROR_WITH_PREVIOUS_STATE). Reklam yalnız izin
##   verildikten VE SDK başlatıldıktan sonra istenir. Sonsuz bekleme yok:
##   rıza/yükleme beklerken CTA pasif + "Reklam hazırlanıyor…", hata/kota/
##   çevrimdışıysa "Reklam şu anda kullanılamıyor." — sahte "hazır" yok.
##
## Ödüllü: tek tam ekran reklam aynı anda (geçiş reklamıyla da paylaşılan
## kural); talep bağlamı (tür, güç / gün anahtarı, token, ad_id, sıra no) ile
## stale/duplicate/yanlış-istek callback'leri elenir. Önyükleme: izin + SDK
## + onboarding sonrası; tüketilince/kapanınca bir sonraki; hata → sınırlı
## geri çekilme (5/15/45/120/300 sn, en çok 8 deneme; pencere açılınca talep
## üzerine bir deneme daha).
##
## Geçiş reklamı (M8.9-02, owner kararı): 900 sn AKTİF ön plan süresi sonra
## "uygun" olur ama HİÇBİR ZAMAN oyun ortasında açılmaz — yalnız Main'in
## doğal molasında (round kesin bitti, devam kararları tamamlandı, sonuç
## ekranı henüz açılmadı) `try_show_interstitial` ile; hazır değilse sonuç
## HEMEN açılır, uygunluk kalır. Saat yalnız gerçek gösterimde sıfırlanır.
## Herhangi bir tam ekran reklam kapanışından sonra 60 sn aktif süre boyunca
## geçiş reklamı bastırılır (art arda iki tam ekran reklam yok).
##
## Banner: Ana Sayfa / Harita / Mağaza / Koleksiyon / oyun ekranı
## (docs/monetization/ADS_SYSTEM.md §6); sonuç ekranında gizli. Yuva açılışta
## bir kez hesaplanır ve sabit kalır; onboarding tamamlanmamışsa yuva 0 ve
## hiçbir reklam yüklenmez (tutorial M8.10). Kayda hiçbir şey yazmaz.

signal ads_state_changed(state: int)
## Ödüllü reklamın "hazır" durumu ya da notu değişti — açık pencere tazelenir.
signal rewarded_availability_changed
signal banner_state_changed(state: int)
signal interstitial_state_changed(state: int)
signal privacy_options_changed(required: bool)
## Banner yuvası değişti (onboarding tamamlanınca 0 → yuva); ekranlar yeniden
## yerleşir.
signal banner_slot_changed(px: float)

enum AdsState { UNAVAILABLE, CONSENT_CHECKING, CONSENT_FORM, ADS_ALLOWED, ADS_NOT_ALLOWED, ERROR_WITH_PREVIOUS_STATE }
enum RewardedState { IDLE, LOADING, READY, SHOWING, REWARD_EARNED, DISMISSED, FAILED }
enum RewardedKind { NONE, REVIVE, REFILL, DAILY_CHEST, DAILY_DOUGH }
enum InterstitialState { IDLE, LOADING, READY, SHOWING, DISMISSED, FAILED }
enum BannerState { IDLE, LOADING, LOADED, SHOWN, FAILED }
enum Surface { NONE, HOME, MAP, SHOP, COLLECTION, GAMEPLAY, RESULT }
enum FormPurpose { NONE, STARTUP, PRIVACY_OPTIONS }

## Banner yüzeyleri (M8.9-02 owner kararı): Harita ve oyun ekranı da dahil;
## sonuç ekranı ve pencereli tam ekran anlar dışarıda.
const BANNER_SURFACES: Array[int] = [Surface.HOME, Surface.MAP, Surface.SHOP, Surface.COLLECTION,
	Surface.GAMEPLAY]
## Ödüllü yükleme geri çekilmesi (sn); son değer tekrarlanır.
const REWARDED_RETRY_DELAYS: Array[float] = [5.0, 15.0, 45.0, 120.0, 300.0]
## Bir döngüde en fazla deneme; sonra yalnız talep (pencere açılışı) yeniler.
const REWARDED_MAX_ATTEMPTS: int = 8
## SDK cevabı gelmezse yüklemeyi başarısız say (SDK kendi zaman aşımını da
## uygular; bu, üstteki güvenlik ağı).
const REWARDED_LOAD_TIMEOUT: float = 60.0
const BANNER_RETRY_DELAYS: Array[float] = [15.0, 60.0, 180.0, 600.0]
const BANNER_MAX_ATTEMPTS: int = 6
const CONSENT_RETRY_DELAYS: Array[float] = [30.0, 120.0]
## Talep üzerine (pencere açılınca) iki deneme arası en az süre.
const ON_DEMAND_MIN_INTERVAL: float = 3.0
## Uygulama öne dönünce reklam hâlâ "gösteriliyor" görünüyorsa callback için
## tanınan pay; sonra ödülsüz kapanmış sayılır.
const SHOW_RESUME_GRACE: float = 3.0

## Geçiş reklamı (M8.9-02): uygunluk için gereken AKTİF ön plan süresi (sn).
const INTERSTITIAL_INTERVAL_SEC: float = 900.0
## Herhangi bir tam ekran reklam kapanışından sonra geçiş reklamı için
## bekleme (aktif sn) — art arda iki tam ekran reklam yok.
const FULLSCREEN_AD_COOLDOWN_SEC: float = 60.0
const INTERSTITIAL_RETRY_DELAYS: Array[float] = [15.0, 60.0, 180.0, 600.0]
const INTERSTITIAL_MAX_ATTEMPTS: int = 6
const INTERSTITIAL_LOAD_TIMEOUT: float = 60.0
## Google: önbelleklenmiş reklam bir saat sonra süresi dolar → daha önce
## tazelenir (yüklenmiş reklamın en fazla yaşı, aktif değil gerçek sn).
const INTERSTITIAL_MAX_AGE_SEC: float = 3300.0
## `show` sonrası SDK "gösterildi" demezse (eklenti yüklenmemiş reklamda
## sinyalsiz uyarı basar) mola bu kadar sn sonra hatasız sürdürülür.
const INTERSTITIAL_SHOW_CONFIRM_TIMEOUT: float = 5.0

## Oyuncuya görünen notlar (pencereler olduğu gibi gösterir).
const NOTE_PREPARING: String = "Reklam hazırlanıyor…"
const NOTE_UNAVAILABLE: String = "Reklam şu anda kullanılamıyor."
const NOTE_SHOWING: String = "Reklam gösteriliyor…"
const NOTE_NOT_EARNED: String = "Ödül için reklamın tamamını izlemen gerekiyor."
const NOTE_SHOW_FAILED: String = "Reklam gösterilemedi, tekrar dene."
const NOTE_NO_BACKEND: String = "Ödüllü reklam bu cihazda kullanılamıyor."

## Talep üzerine rıza güncellemesini yenileme aralığı (sn).
const CONSENT_ON_DEMAND_MIN_INTERVAL: float = 20.0
const EMPTY_REQUEST: Dictionary = {"active": false, "id": 0, "kind": RewardedKind.NONE, "main": null,
	"type": -1, "token": 0, "day_key": "", "ad_id": "", "earned": false, "cancelled": false}

## Testler zamanlayıcıları hızlandırır (1.0 = gerçek süre).
static var time_scale: float = 1.0

var _backend: AdBackend = null
var _config: AdConfig = null

var _state: AdsState = AdsState.UNAVAILABLE
var _consent_checked: bool = false
## Rıza akışının İLK BAŞLATMASI yapıldı mı (M8.10 §18) — bir LATCH, durum
## makinesi DEĞİL. Rızanın kendi durumu zaten `AdsState`'te modelleniyor
## (CONSENT_CHECKING = uçuşta, ADS_ALLOWED / ADS_NOT_ALLOWED /
## ERROR_WITH_PREVIOUS_STATE = çözülmüş) ve yeniden deneme sayacı
## `_consent_attempts`'te; bu bayrak yalnız "kick-off oldu mu" sorusunu
## yanıtlar.
##
## NEDEN: `_consent_attempts` BAŞARIDA sıfırlanıyor (`_resolve_consent`), bu
## yüzden "akış başladı mı" sorusuna cevap veremez. Onboarding tamamlanınca
## `set_onboarding_completed(true)` ikinci bir `request_consent_update`
## gönderiyordu; bu durumu CONSENT_CHECKING'e düşürüp izni GEÇİCİ OLARAK
## kaybettiriyor ve yüklemeleri engelliyordu (M8.10'da yakalandı).
##
## NEYİ BASTIRMAZ (M8.9 davranışı aynen korunuyor): planlı yeniden denemeler
## (`_on_consent_retry`) ve talep üzerine tazeleme (`ensure_rewarded`,
## ADS_NOT_ALLOWED + ON_DEMAND aralığı) `_start_consent()`'i DOĞRUDAN çağırır
## — latch onları görmez. Yeni uygulama açılışı = yeni yönetici örneği =
## latch yeniden false.
var _consent_kickoff_done: bool = false
var _consent_attempts: int = 0
var _consent_last_attempt_msec: int = -1000000
var _consent_retry_timer: SceneTreeTimer = null
var _form_purpose: FormPurpose = FormPurpose.NONE
var _privacy_options_required: bool = false
var _sdk_ready: bool = false
var _sdk_initializing: bool = false
var _app_paused: bool = false
## Onboarding/tutorial tamamlandı mı (Main kayıttan verir). false: yuva 0,
## hiçbir reklam yüklenmez/gösterilmez, aktif süre sayılmaz.
var _onboarding_completed: bool = true

var _rewarded_state: RewardedState = RewardedState.IDLE
var _ready_ad_id: String = ""
var _rewarded_attempts: int = 0
var _rewarded_retry_timer: SceneTreeTimer = null
var _rewarded_timeout_timer: SceneTreeTimer = null
var _rewarded_last_attempt_msec: int = -100000
var _resume_grace_timer: SceneTreeTimer = null
var _request_seq: int = 0
## Açık talep: {active, id, kind, main, type, token, day_key, ad_id, earned, cancelled}
var _request: Dictionary = EMPTY_REQUEST.duplicate()

var _interstitial_state: InterstitialState = InterstitialState.IDLE
var _interstitial_ready_id: String = ""
var _interstitial_showing_id: String = ""
var _interstitial_loaded_msec: int = 0
var _interstitial_attempts: int = 0
var _interstitial_retry_timer: SceneTreeTimer = null
var _interstitial_timeout_timer: SceneTreeTimer = null
var _interstitial_confirm_timer: SceneTreeTimer = null
var _interstitial_resume_timer: SceneTreeTimer = null
var _interstitial_last_attempt_msec: int = -100000
## Aktif ön plan süresi (sn) — yalnız sayılabilir anlarda birikir.
var _active_elapsed: float = 0.0
var _interstitial_eligible: bool = false
## Tam ekran reklam sonrası kalan bekleme (aktif sn).
var _fullscreen_cooldown: float = 0.0
## Doğal mola: sonuç ekranını süren callback (tam bir kez çağrılır).
var _break_callback: Callable = Callable()
var _break_name: String = ""
var _break_seq: int = 0
var _break_done: bool = true
var _interstitial_shows: int = 0

var _banner_state: BannerState = BannerState.IDLE
var _banner_ad_id: String = ""
var _banner_attempts: int = 0
var _banner_retry_timer: SceneTreeTimer = null
var _banner_slot_px: float = 0.0
var _surface: Surface = Surface.NONE


## Fabrika: arka uç verilmezse platformdan seçilir (Android + eklenti →
## AdmobBackend; yoksa null → Main sağlayıcısız kalır, eski davranış).
static func create(backend: AdBackend = null, config: AdConfig = null) -> MonetizationManager:
	if config == null:
		config = AdConfig.load_project()
	if backend == null:
		backend = AdmobBackend.create(config)
	if backend == null:
		return null
	var manager := MonetizationManager.new()
	manager.name = "MonetizationManager"
	manager._backend = backend
	manager._config = config
	return manager


func _ready() -> void:
	# Aktif süre saati oyun içi pencereler ağacı duraklatsa da sayar; arka
	# plan/reklam/rıza formu koşulları _counting_allowed'da.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _backend == null:
		_set_state(AdsState.UNAVAILABLE)
		set_process(false)
		return
	_backend.attach(self)
	_connect_backend()
	_compute_banner_slot()
	print_verbose("MonetizationManager: %s, %s" % [_backend.backend_name(),
		_config.describe() if _config != null else "config yok"])
	# Rıza (UMP) ONBOARDING'DEN SONRA (M8.10 §18): tutorial sırasında ekranı
	# bir gizlilik formu kaplamaz. Rıza şartı KALDIRILMADI, yalnız ertelendi —
	# `_ads_enabled()` hâlâ izin + SDK istiyor, yani ilk reklam talebinden
	# ÖNCE rıza akışı mutlaka çalışır.
	_maybe_start_consent()


func _exit_tree() -> void:
	_cancel_timer(_consent_retry_timer)
	_cancel_timer(_rewarded_retry_timer)
	_cancel_timer(_rewarded_timeout_timer)
	_cancel_timer(_banner_retry_timer)
	_cancel_timer(_resume_grace_timer)
	_cancel_timer(_interstitial_retry_timer)
	_cancel_timer(_interstitial_timeout_timer)
	_cancel_timer(_interstitial_confirm_timer)
	_cancel_timer(_interstitial_resume_timer)
	if _banner_state == BannerState.SHOWN and _backend != null:
		_backend.hide_banner(_banner_ad_id)
	UiKit.set_banner_slot(0.0)


func _process(delta: float) -> void:
	_tick_active(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_app_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_app_paused = false
		_sync_banner()
		if _rewarded_state == RewardedState.SHOWING or _rewarded_state == RewardedState.REWARD_EARNED:
			# Reklam etkinliği kapanmış olmalı; kapanış sinyali kuyrukta.
			# Gelmezse (eklenti/SDK boşluğu) sınırlı payın sonunda ödülsüz
			# kapanış varsayılır — kimse sonsuza dek "gösteriliyor"da kalmaz.
			_resume_grace_timer = _start_timer(SHOW_RESUME_GRACE, _on_resume_grace_timeout)
		if _interstitial_state == InterstitialState.SHOWING:
			_cancel_timer(_interstitial_resume_timer)
			_interstitial_resume_timer = _start_timer(SHOW_RESUME_GRACE, _on_interstitial_resume_grace)


func _connect_backend() -> void:
	_backend.initialization_completed.connect(_on_initialization_completed)
	_backend.consent_info_updated.connect(_on_consent_info_updated)
	_backend.consent_info_update_failed.connect(_on_consent_info_update_failed)
	_backend.consent_form_loaded.connect(_on_consent_form_loaded)
	_backend.consent_form_failed_to_load.connect(_on_consent_form_failed_to_load)
	_backend.consent_form_dismissed.connect(_on_consent_form_dismissed)
	_backend.rewarded_loaded.connect(_on_rewarded_loaded)
	_backend.rewarded_failed_to_load.connect(_on_rewarded_failed_to_load)
	_backend.rewarded_showed.connect(_on_rewarded_showed)
	_backend.rewarded_failed_to_show.connect(_on_rewarded_failed_to_show)
	_backend.rewarded_impression.connect(_on_rewarded_impression)
	_backend.rewarded_clicked.connect(_on_rewarded_clicked)
	_backend.rewarded_earned.connect(_on_rewarded_earned)
	_backend.rewarded_dismissed.connect(_on_rewarded_dismissed)
	_backend.interstitial_loaded.connect(_on_interstitial_loaded)
	_backend.interstitial_failed_to_load.connect(_on_interstitial_failed_to_load)
	_backend.interstitial_showed.connect(_on_interstitial_showed)
	_backend.interstitial_failed_to_show.connect(_on_interstitial_failed_to_show)
	_backend.interstitial_impression.connect(_on_interstitial_impression)
	_backend.interstitial_clicked.connect(_on_interstitial_clicked)
	_backend.interstitial_dismissed.connect(_on_interstitial_dismissed)
	_backend.banner_loaded.connect(_on_banner_loaded)
	_backend.banner_failed_to_load.connect(_on_banner_failed_to_load)
	_backend.banner_impression.connect(_on_banner_impression)
	_backend.banner_clicked.connect(_on_banner_clicked)


# --- Durum ----------------------------------------------------------------------

func ads_state() -> AdsState:
	return _state


func ads_allowed() -> bool:
	return _state == AdsState.ADS_ALLOWED or _state == AdsState.ERROR_WITH_PREVIOUS_STATE


func sdk_ready() -> bool:
	return _sdk_ready


func rewarded_state() -> RewardedState:
	return _rewarded_state


func interstitial_state() -> InterstitialState:
	return _interstitial_state


func banner_state() -> BannerState:
	return _banner_state


func surface() -> Surface:
	return _surface


func backend() -> AdBackend:
	return _backend


func has_backend() -> bool:
	return _backend != null


## Onboarding tamamlanmış mı (Main kayıttan verir; M8.10 tutorial bitince
## true yapar). false → reklam yok, yuva yok, saat durur.
func onboarding_completed() -> bool:
	return _onboarding_completed


## Reklam istenebilir mi: izin + SDK + onboarding (hepsi birlikte).
func _ads_enabled() -> bool:
	return _backend != null and ads_allowed() and _sdk_ready and _onboarding_completed


## Main açılışta kayıttan çağırır (ekranlar yerleşmeden ÖNCE — yuva) ve
## M8.10 tutorial bitince bir daha (true). false → yuva 0, gösterili banner
## gizlenir, hiçbir yeni yükleme açılmaz; true → yuva hesaplanır, yüklemeler
## başlar. Aynı değer yeniden verilirse hiçbir şey olmaz.
func set_onboarding_completed(done: bool) -> void:
	if done == _onboarding_completed:
		return
	_onboarding_completed = done
	if _backend == null or not is_node_ready():
		# Ağaca girmeden önce (Main yaratırken): yalnız bayrak; _ready hesaplar.
		return
	_compute_banner_slot()
	if done:
		# Tutorial bitti: rıza akışı ŞİMDİ başlar (açılışta ertelenmişti),
		# ardından yüklemeler.
		_maybe_start_consent()
		_preload_rewarded()
		_preload_interstitial()
	rewarded_availability_changed.emit()
	_sync_banner()


func _set_state(state: AdsState) -> void:
	if state == _state:
		return
	var was_allowed: bool = ads_allowed()
	_state = state
	ads_state_changed.emit(state)
	if was_allowed != ads_allowed():
		rewarded_availability_changed.emit()
		_sync_banner()


# --- Rıza (UMP) -----------------------------------------------------------------

## Rıza akışının TEK kick-off noktası: onboarding tamamlanana kadar başlamaz
## ve bir kez başladıysa yeniden başlatılmaz. Yalnız `_ready()` ve
## `set_onboarding_completed(true)` çağırır; yeniden denemeler ve talep
## üzerine tazeleme bu kapıdan GEÇMEZ (bkz. `_consent_kickoff_done`).
func _maybe_start_consent() -> void:
	if not _onboarding_completed or _consent_kickoff_done:
		return
	_start_consent()


## Rıza akışı bu yönetici örneğinde hiç başlatıldı mı (testler + teşhis).
func consent_started() -> bool:
	return _consent_kickoff_done


func _start_consent() -> void:
	_cancel_timer(_consent_retry_timer)
	_consent_retry_timer = null
	_consent_kickoff_done = true
	_consent_attempts += 1
	_consent_last_attempt_msec = Time.get_ticks_msec()
	_set_state(AdsState.CONSENT_CHECKING)
	_backend.request_consent_update()


func _on_consent_retry() -> void:
	_consent_retry_timer = null
	if _state == AdsState.ADS_NOT_ALLOWED:
		_start_consent()


func _on_consent_info_updated() -> void:
	_consent_checked = true
	_resolve_consent(false)


## Güncelleme başarısız: SDK `getConsentStatus()` önceki oturumun değerini
## taşır (UMP belgesi) — o değer izin veriyorsa reklam istenebilir
## (ERROR_WITH_PREVIOUS_STATE), vermiyorsa sınırlı yeniden deneme.
func _on_consent_info_update_failed(_code: int, _message: String) -> void:
	_consent_checked = true
	_resolve_consent(true)


func _resolve_consent(after_error: bool) -> void:
	var status: AdBackend.ConsentStatus = _backend.consent_status()
	_update_privacy_options()
	match status:
		AdBackend.ConsentStatus.NOT_REQUIRED, AdBackend.ConsentStatus.OBTAINED:
			_consent_attempts = 0
			_set_state(AdsState.ERROR_WITH_PREVIOUS_STATE if after_error else AdsState.ADS_ALLOWED)
			_ensure_sdk()
		AdBackend.ConsentStatus.REQUIRED:
			if after_error:
				_set_state(AdsState.ADS_NOT_ALLOWED)
				_schedule_consent_retry()
			elif _backend.is_consent_form_available():
				_set_state(AdsState.CONSENT_FORM)
				_form_purpose = FormPurpose.STARTUP
				_backend.load_consent_form()
			else:
				# Rıza gerekli ama SDK form sunamıyor: reklam istenmez.
				_set_state(AdsState.ADS_NOT_ALLOWED)
				_schedule_consent_retry()
		_:
			_set_state(AdsState.ADS_NOT_ALLOWED)
			_schedule_consent_retry()


func _schedule_consent_retry() -> void:
	if _consent_attempts > CONSENT_RETRY_DELAYS.size():
		return
	var delay: float = CONSENT_RETRY_DELAYS[mini(_consent_attempts - 1, CONSENT_RETRY_DELAYS.size() - 1)]
	_cancel_timer(_consent_retry_timer)
	_consent_retry_timer = _start_timer(delay, _on_consent_retry)


func _on_consent_form_loaded() -> void:
	if _form_purpose == FormPurpose.NONE:
		return
	_backend.show_consent_form()


func _on_consent_form_failed_to_load(_code: int, _message: String) -> void:
	var purpose: FormPurpose = _form_purpose
	_form_purpose = FormPurpose.NONE
	if purpose == FormPurpose.STARTUP:
		_set_state(AdsState.ADS_NOT_ALLOWED)
		_schedule_consent_retry()


## Form kapandı (rıza verildi / reddedildi / hata): durumu SDK'dan yeniden oku.
func _on_consent_form_dismissed(_code: int, _message: String) -> void:
	var purpose: FormPurpose = _form_purpose
	_form_purpose = FormPurpose.NONE
	if purpose == FormPurpose.NONE:
		return
	var status: AdBackend.ConsentStatus = _backend.consent_status()
	_update_privacy_options()
	if status == AdBackend.ConsentStatus.OBTAINED or status == AdBackend.ConsentStatus.NOT_REQUIRED:
		_consent_attempts = 0
		_set_state(AdsState.ADS_ALLOWED)
		_ensure_sdk()
	else:
		_set_state(AdsState.ADS_NOT_ALLOWED)
		if purpose == FormPurpose.STARTUP:
			_schedule_consent_retry()


## Gizlilik seçenekleri giriş noktası gerekli mi? v6.0 eklentisi UMP'nin
## `getPrivacyOptionsRequirementStatus()`'ünü sarmaz; SDK'dan türeyen
## eşdeğer: rıza güncellemesi yapıldı VE SDK bir rıza formu sunuyor
## (`isConsentFormAvailable`, yalnız düzenlenen bölgelerde true). Ayrıntı ve
## açık nokta: docs/monetization/PRIVACY_CONSENT.md §4.
func _update_privacy_options() -> void:
	var required: bool = _consent_checked and _backend.is_consent_form_available()
	if required != _privacy_options_required:
		_privacy_options_required = required
		privacy_options_changed.emit(required)


func privacy_options_required() -> bool:
	return _privacy_options_required


## Ayarlar → "Gizlilik seçenekleri": SDK'nın formunu yeniden sunar; kapanınca
## izin durumu yeniden değerlendirilir (reklam durabilir ya da başlayabilir).
func show_privacy_options() -> bool:
	if _backend == null or not _privacy_options_required or _form_purpose != FormPurpose.NONE:
		return false
	_form_purpose = FormPurpose.PRIVACY_OPTIONS
	_backend.load_consent_form()
	return true


## UMP / gizlilik formu uygulamayı kaplıyor mu (aktif süre sayılmaz).
func consent_form_covering() -> bool:
	return _state == AdsState.CONSENT_FORM or _form_purpose != FormPurpose.NONE


# --- SDK ------------------------------------------------------------------------

func _ensure_sdk() -> void:
	if _sdk_ready or _sdk_initializing:
		_preload_rewarded()
		_preload_interstitial()
		_sync_banner()
		return
	_sdk_initializing = true
	_backend.initialize()


func _on_initialization_completed() -> void:
	_sdk_initializing = false
	_sdk_ready = true
	rewarded_availability_changed.emit()
	_preload_rewarded()
	_preload_interstitial()
	_sync_banner()


# --- Ödüllü — Main sağlayıcı dikişi ---------------------------------------------

## Yüklenmiş bir ödüllü reklam ŞİMDİ gösterilebilir mi? Pencerelerin CTA'sı
## yalnız bu true iken aktif (M8.6-10 sözleşmesi: çalışmayacak buton yok).
## Geçiş reklamı gösterilirken de hayır (tek tam ekran reklam).
func is_rewarded_ready() -> bool:
	return (_rewarded_state == RewardedState.READY and not _ready_ad_id.is_empty()
		and _ads_enabled() and _interstitial_state != InterstitialState.SHOWING)


## CTA pasifken pencerede yazan sebep; hazırken boş.
func rewarded_note() -> String:
	if _backend == null or _state == AdsState.UNAVAILABLE:
		return NOTE_NO_BACKEND
	if not _onboarding_completed:
		return NOTE_UNAVAILABLE
	match _state:
		AdsState.CONSENT_CHECKING, AdsState.CONSENT_FORM:
			return NOTE_PREPARING
		AdsState.ADS_NOT_ALLOWED:
			return NOTE_UNAVAILABLE
	if not _sdk_ready:
		return NOTE_PREPARING
	if _interstitial_state == InterstitialState.SHOWING:
		return NOTE_SHOWING
	match _rewarded_state:
		RewardedState.READY:
			return ""
		RewardedState.SHOWING, RewardedState.REWARD_EARNED:
			return NOTE_SHOWING
		RewardedState.LOADING:
			return NOTE_PREPARING
		RewardedState.FAILED:
			return NOTE_UNAVAILABLE
	# IDLE / DISMISSED: önyükleme sırada.
	return NOTE_PREPARING if _rewarded_attempts < REWARDED_MAX_ATTEMPTS else NOTE_UNAVAILABLE


## Pencere açıldı: hazır değilse (rıza reddi dışında) bir yükleme daha dene —
## geri çekilme beklemesi kısaltılır, spam yok (ON_DEMAND_MIN_INTERVAL).
func ensure_rewarded() -> void:
	if _backend == null or not _onboarding_completed:
		return
	if _state == AdsState.ADS_NOT_ALLOWED:
		# Rıza reddi/hatası sonrası pencere açıldı: sınırlı aralıkla bir
		# güncelleme daha (ağ geri gelmiş olabilir); SDK yine tek gerçek.
		var since_consent: float = float(Time.get_ticks_msec() - _consent_last_attempt_msec) / 1000.0
		if since_consent >= CONSENT_ON_DEMAND_MIN_INTERVAL * time_scale:
			_start_consent()
		return
	if not ads_allowed() or not _sdk_ready:
		return
	match _rewarded_state:
		RewardedState.IDLE, RewardedState.DISMISSED, RewardedState.FAILED:
			var since: float = float(Time.get_ticks_msec() - _rewarded_last_attempt_msec) / 1000.0
			if since >= ON_DEMAND_MIN_INTERVAL * time_scale:
				_rewarded_attempts = 0
				_preload_rewarded()


func show_rewarded_revive(main: Node) -> void:
	_show_rewarded(main, RewardedKind.REVIVE, -1, 0, "")


func show_rewarded_power(main: Node, type: int, token: int) -> void:
	_show_rewarded(main, RewardedKind.REFILL, type, token, "")


## Günlük reklamlı sandık (M8.9-02): bağlam = gün anahtarı + Main'in talep
## token'ı; ödül `Main.grant_daily_chest(day_key, token)`.
func show_rewarded_daily_chest(main: Node, day_key: String, token: int) -> void:
	_show_rewarded(main, RewardedKind.DAILY_CHEST, -1, token, day_key)


## Günlük reklamlı +150 Hamur (M8.9-02); ödül `Main.grant_daily_dough(day_key, token)`.
func show_rewarded_daily_dough(main: Node, day_key: String, token: int) -> void:
	_show_rewarded(main, RewardedKind.DAILY_DOUGH, -1, token, day_key)


func _show_rewarded(main: Node, kind: RewardedKind, type: int, token: int, day_key: String) -> void:
	var ctx: Dictionary = _context(kind, type, day_key)
	AdEvents.emit(&"rewarded_requested", ctx)
	if _request["active"] or _interstitial_state == InterstitialState.SHOWING:
		# Aynı anda ikinci tam ekran reklam yok (devam + refill + günlük +
		# geçiş reklamı birlikte olamaz).
		_notify_unavailable(main, kind, NOTE_SHOWING)
		return
	if not is_rewarded_ready():
		_notify_unavailable(main, kind, rewarded_note())
		ensure_rewarded()
		return
	_request_seq += 1
	_request = {
		"active": true, "id": _request_seq, "kind": kind, "main": main,
		"type": type, "token": token, "day_key": day_key, "ad_id": _ready_ad_id,
		"earned": false, "cancelled": false,
	}
	_ready_ad_id = ""
	_rewarded_state = RewardedState.SHOWING
	rewarded_availability_changed.emit()
	_backend.show_rewarded(_request["ad_id"])


## Main: pencere kapandı / round terk edildi / board silindi. Açık talep
## iptal edilir: sonradan gelen "ödül" HİÇBİR ŞEY vermez, reklam akışı
## (kapanış → önyükleme) normal sürer.
func cancel_rewarded_request() -> void:
	if _request["active"]:
		_request["cancelled"] = true


func has_active_request() -> bool:
	return bool(_request["active"])


## Herhangi bir tam ekran reklam (ödüllü ya da geçiş) şu an ekranda mı?
func fullscreen_ad_active() -> bool:
	return (_request["active"] or _rewarded_state == RewardedState.SHOWING
		or _rewarded_state == RewardedState.REWARD_EARNED
		or _interstitial_state == InterstitialState.SHOWING)


func _context(kind: RewardedKind, type: int, day_key: String) -> Dictionary:
	var ctx: Dictionary = {"placement": _placement_name(kind)}
	if kind == RewardedKind.REFILL and PowerUp.is_valid_type(type):
		ctx["power"] = PowerUp.save_key(type as PowerUp.Type)
	if not day_key.is_empty():
		ctx["day_key"] = day_key
	return ctx


func _placement_name(kind: RewardedKind) -> String:
	match kind:
		RewardedKind.REVIVE:
			return "revive"
		RewardedKind.REFILL:
			return "refill"
		RewardedKind.DAILY_CHEST:
			return "daily_chest"
		RewardedKind.DAILY_DOUGH:
			return "daily_dough"
	return "preload"


func _request_context() -> Dictionary:
	if not _request["active"]:
		return {"placement": "preload"}
	var ctx: Dictionary = _context(_request["kind"], _request["type"], _request["day_key"])
	ctx["ad_id"] = _request["ad_id"]
	return ctx


func _notify_unavailable(main: Variant, kind: RewardedKind, message: String) -> void:
	if main == null or not is_instance_valid(main):
		return
	match kind:
		RewardedKind.REVIVE:
			if main.has_method("notify_rewarded_unavailable"):
				main.notify_rewarded_unavailable(message)
		RewardedKind.REFILL:
			if main.has_method("notify_power_rewarded_unavailable"):
				main.notify_power_rewarded_unavailable(message)
		RewardedKind.DAILY_CHEST, RewardedKind.DAILY_DOUGH:
			if main.has_method("notify_daily_rewarded_unavailable"):
				main.notify_daily_rewarded_unavailable(_placement_name(kind), message)


func _clear_request() -> void:
	_request = EMPTY_REQUEST.duplicate()


# --- Ödüllü — yükleme / önbellek ---------------------------------------------

func _preload_rewarded() -> void:
	if not _ads_enabled():
		return
	match _rewarded_state:
		RewardedState.LOADING, RewardedState.READY, RewardedState.SHOWING, RewardedState.REWARD_EARNED:
			return
	if _rewarded_attempts >= REWARDED_MAX_ATTEMPTS:
		return
	_cancel_timer(_rewarded_retry_timer)
	_rewarded_retry_timer = null
	_rewarded_state = RewardedState.LOADING
	_rewarded_last_attempt_msec = Time.get_ticks_msec()
	_cancel_timer(_rewarded_timeout_timer)
	_rewarded_timeout_timer = _start_timer(REWARDED_LOAD_TIMEOUT, _on_rewarded_load_timeout)
	rewarded_availability_changed.emit()
	_backend.load_rewarded()


func _on_rewarded_loaded(ad_id: String) -> void:
	_cancel_timer(_rewarded_timeout_timer)
	_rewarded_timeout_timer = null
	_cancel_timer(_rewarded_retry_timer)
	_rewarded_retry_timer = null
	_rewarded_attempts = 0
	_ready_ad_id = ad_id
	if _rewarded_state != RewardedState.SHOWING and _rewarded_state != RewardedState.REWARD_EARNED:
		_rewarded_state = RewardedState.READY
	AdEvents.emit(&"rewarded_loaded", {"placement": "preload", "ad_id": ad_id})
	rewarded_availability_changed.emit()


func _on_rewarded_failed_to_load(ad_id: String, code: int, message: String) -> void:
	AdEvents.emit(&"rewarded_load_failed", {"placement": "preload", "ad_id": ad_id,
		"code": code, "message": message})
	if _rewarded_state != RewardedState.LOADING:
		return
	_cancel_timer(_rewarded_timeout_timer)
	_rewarded_timeout_timer = null
	_rewarded_state = RewardedState.FAILED
	_rewarded_attempts += 1
	_schedule_rewarded_retry()
	rewarded_availability_changed.emit()


func _on_rewarded_load_timeout() -> void:
	_rewarded_timeout_timer = null
	if _rewarded_state != RewardedState.LOADING:
		return
	_on_rewarded_failed_to_load("", -1, "load timeout")


func _schedule_rewarded_retry() -> void:
	if _rewarded_attempts >= REWARDED_MAX_ATTEMPTS:
		return
	var delay: float = REWARDED_RETRY_DELAYS[mini(_rewarded_attempts - 1, REWARDED_RETRY_DELAYS.size() - 1)]
	_cancel_timer(_rewarded_retry_timer)
	_rewarded_retry_timer = _start_timer(delay, _on_rewarded_retry)


func _on_rewarded_retry() -> void:
	_rewarded_retry_timer = null
	_preload_rewarded()


func _on_rewarded_showed(ad_id: String) -> void:
	if _request["active"] and _request["ad_id"] == ad_id:
		AdEvents.emit(&"rewarded_showed", _request_context())
	else:
		AdEvents.emit(&"rewarded_showed", {"placement": "preload", "ad_id": ad_id, "stale": true})


func _on_rewarded_impression(ad_id: String) -> void:
	var ctx: Dictionary = _request_context()
	ctx["ad_id"] = ad_id
	AdEvents.emit(&"rewarded_impression", ctx)


func _on_rewarded_clicked(_ad_id: String) -> void:
	pass


## TEK ödül yolu. Üç kapı: açık talep, aynı ad_id, daha önce ödül verilmemiş.
## İptal edilmiş talep ödül vermez. Ödül Main'in kilitli grant yollarından
## geçer (board / kota / token kendi kontrollerini yapar). Ödül türü talep
## bağlamından gelir — görünen pencereden ASLA çıkarılmaz.
func _on_rewarded_earned(ad_id: String, reward_type: String, amount: int) -> void:
	if not _request["active"] or _request["ad_id"] != ad_id or _request["earned"]:
		AdEvents.emit(&"rewarded_earned", {"placement": "preload", "ad_id": ad_id, "stale": true,
			"reward_type": reward_type, "amount": amount})
		return
	_request["earned"] = true
	_rewarded_state = RewardedState.REWARD_EARNED
	var ctx: Dictionary = _request_context()
	ctx["reward_type"] = reward_type
	ctx["amount"] = amount
	ctx["cancelled"] = _request["cancelled"]
	AdEvents.emit(&"rewarded_earned", ctx)
	if _request["cancelled"]:
		return
	if not is_instance_valid(_request["main"]):
		return
	var main: Node = _request["main"]
	match _request["kind"]:
		RewardedKind.REVIVE:
			if main.has_method("grant_revive"):
				main.grant_revive()
		RewardedKind.REFILL:
			if main.has_method("grant_rewarded_power"):
				main.grant_rewarded_power(_request["type"], _request["token"])
		RewardedKind.DAILY_CHEST:
			if main.has_method("grant_daily_chest"):
				main.grant_daily_chest(_request["day_key"], _request["token"])
		RewardedKind.DAILY_DOUGH:
			if main.has_method("grant_daily_dough"):
				main.grant_daily_dough(_request["day_key"], _request["token"])


func _on_rewarded_dismissed(ad_id: String) -> void:
	if _request["active"] and _request["ad_id"] != ad_id:
		# Başka bir (eski) reklamın kapanışı; açık talebe dokunulmaz.
		AdEvents.emit(&"rewarded_dismissed", {"placement": "preload", "ad_id": ad_id, "stale": true})
		return
	_cancel_timer(_resume_grace_timer)
	_resume_grace_timer = null
	var ctx: Dictionary = {"placement": "preload", "ad_id": ad_id}
	var was_showing: bool = (_rewarded_state == RewardedState.SHOWING
		or _rewarded_state == RewardedState.REWARD_EARNED)
	if _request["active"]:
		ctx = _request_context()
		ctx["earned"] = _request["earned"]
		if not _request["earned"] and not _request["cancelled"]:
			_notify_unavailable(_request["main"], _request["kind"], NOTE_NOT_EARNED)
		_clear_request()
	AdEvents.emit(&"rewarded_dismissed", ctx)
	if _rewarded_state == RewardedState.SHOWING or _rewarded_state == RewardedState.REWARD_EARNED \
			or _rewarded_state == RewardedState.DISMISSED:
		# Gösterim sırasında başka bir yükleme bittiyse o hazır; yoksa sıradaki.
		_rewarded_state = RewardedState.READY if not _ready_ad_id.is_empty() else RewardedState.DISMISSED
	if was_showing:
		_start_fullscreen_cooldown()
	rewarded_availability_changed.emit()
	_preload_rewarded()


func _on_rewarded_failed_to_show(ad_id: String, code: int, message: String) -> void:
	if _request["active"] and _request["ad_id"] != ad_id:
		AdEvents.emit(&"rewarded_show_failed", {"placement": "preload", "ad_id": ad_id,
			"code": code, "message": message, "stale": true})
		_backend.remove_rewarded(ad_id)
		return
	_cancel_timer(_resume_grace_timer)
	_resume_grace_timer = null
	var ctx: Dictionary = {"placement": "preload", "ad_id": ad_id, "code": code, "message": message}
	if _request["active"]:
		ctx = _request_context()
		ctx["code"] = code
		ctx["message"] = message
		if not _request["cancelled"]:
			_notify_unavailable(_request["main"], _request["kind"], NOTE_SHOW_FAILED)
		_clear_request()
	AdEvents.emit(&"rewarded_show_failed", ctx)
	# Gösterilemeyen reklam tüketilmiş sayılır: önbellekten düş, yenisini yükle.
	_backend.remove_rewarded(ad_id)
	if _ready_ad_id == ad_id:
		_ready_ad_id = ""
	_rewarded_state = RewardedState.READY if not _ready_ad_id.is_empty() else RewardedState.FAILED
	rewarded_availability_changed.emit()
	_preload_rewarded()


func _on_resume_grace_timeout() -> void:
	_resume_grace_timer = null
	if _rewarded_state != RewardedState.SHOWING and _rewarded_state != RewardedState.REWARD_EARNED:
		return
	if _request["active"]:
		_on_rewarded_dismissed(_request["ad_id"])
	else:
		_rewarded_state = RewardedState.DISMISSED
		_start_fullscreen_cooldown()
		rewarded_availability_changed.emit()
		_preload_rewarded()


# --- Geçiş reklamı (interstitial, M8.9-02) -------------------------------------------
#
# Uygunluk: INTERSTITIAL_INTERVAL_SEC aktif ön plan saniyesi. Sayılmayan
# anlar: arka plan (ekran kapalı dahil — Android uygulamayı duraklatır),
# UMP/gizlilik formu, ödüllü ya da geçiş reklamı ekranda, onboarding
# tamamlanmamış. Oyun içi normal pencereler (mola, ayarlar, devam, refill)
# SAYILIR.
#
# Gösterim YALNIZ Main'in doğal molasında (`try_show_interstitial`): uygun +
# READY + bekleme yok + başka tam ekran reklam yok. Değilse hiç gösterilmez
# (sonuç hemen açılır), uygunluk korunur, sonraki molada denenir. Saat yalnız
# SDK "gösterildi" deyince sıfırlanır; yükleme/gösterim hatası sıfırlamaz.

func interstitial_eligible() -> bool:
	return _interstitial_eligible


func active_elapsed_sec() -> float:
	return _active_elapsed


func fullscreen_cooldown_sec() -> float:
	return _fullscreen_cooldown


func is_interstitial_ready() -> bool:
	return (_interstitial_state == InterstitialState.READY and not _interstitial_ready_id.is_empty()
		and _ads_enabled() and not _interstitial_expired())


func _interstitial_expired() -> bool:
	return (Time.get_ticks_msec() - _interstitial_loaded_msec) > int(INTERSTITIAL_MAX_AGE_SEC * time_scale * 1000.0)


## Aktif süre sayılabilir mi (bkz. üst not).
func _counting_allowed() -> bool:
	return (_backend != null and _onboarding_completed and not _app_paused
		and not consent_form_covering() and not fullscreen_ad_active())


## Saat adımı (`_process`; testler doğrudan çağırır). Gerçek saniye — time_scale
## uygulanmaz (aktif süre ölçek dışı; testler saniyeyi kendisi verir).
func _tick_active(delta: float) -> void:
	if delta <= 0.0 or not _counting_allowed():
		return
	_active_elapsed += delta
	if _fullscreen_cooldown > 0.0:
		_fullscreen_cooldown = maxf(0.0, _fullscreen_cooldown - delta)
	if not _interstitial_eligible and _active_elapsed >= INTERSTITIAL_INTERVAL_SEC:
		_interstitial_eligible = true
		AdEvents.emit(&"interstitial_eligible", {"active_elapsed_sec": _active_elapsed})
		# Uygun olduk, reklam yoksa (hata döngüsü bitmiş) bir deneme daha.
		_kick_interstitial_load()
	if _interstitial_state == InterstitialState.READY and _interstitial_expired():
		# Google: reklam bir saatte sona erer — süresi dolanı at, tazele.
		_discard_ready_interstitial()
		_preload_interstitial()


## Herhangi bir tam ekran reklam kapandı: geçiş reklamı için bekleme başlar.
func _start_fullscreen_cooldown() -> void:
	_fullscreen_cooldown = FULLSCREEN_AD_COOLDOWN_SEC


## Main'in doğal molası (round kesin bitti → sonuçtan önce). Gösterim
## gerçekten gönderildiyse true döner ve `continue_callback` reklam kapanınca
## (ya da gösterilemezse / onay gelmezse) TAM BİR KEZ çağrılır. false → hiçbir
## şey gösterilmedi, Main sonucu HEMEN açar; uygunluk korunur.
func try_show_interstitial(break_name: String, continue_callback: Callable) -> bool:
	var reason: String = _interstitial_block_reason()
	if reason != "":
		AdEvents.emit(&"interstitial_skipped_not_ready", {"natural_break": break_name,
			"active_elapsed_sec": _active_elapsed, "reason": reason, "eligible": _interstitial_eligible})
		if _interstitial_eligible and (reason == "not_ready" or reason == "failed" or reason == "expired"):
			# Uygun ama reklam yok: bir sonraki mola için yükleme dene.
			_kick_interstitial_load()
		return false
	_break_seq += 1
	_break_callback = continue_callback
	_break_name = break_name
	_break_done = false
	_interstitial_showing_id = _interstitial_ready_id
	_interstitial_ready_id = ""
	_set_interstitial_state(InterstitialState.SHOWING)
	_cancel_timer(_interstitial_confirm_timer)
	_interstitial_confirm_timer = _start_timer(INTERSTITIAL_SHOW_CONFIRM_TIMEOUT, _on_interstitial_confirm_timeout)
	rewarded_availability_changed.emit()
	_backend.show_interstitial(_interstitial_showing_id)
	return true


## Gösterimi engelleyen sebep; boş = gösterilebilir.
func _interstitial_block_reason() -> String:
	if _backend == null or not _onboarding_completed:
		return "disabled"
	if not _interstitial_eligible:
		return "not_eligible"
	if not ads_allowed() or not _sdk_ready:
		return "consent"
	if _fullscreen_cooldown > 0.0:
		return "cooldown"
	if _request["active"] or _rewarded_state == RewardedState.SHOWING \
			or _rewarded_state == RewardedState.REWARD_EARNED:
		return "rewarded_active"
	if _interstitial_state == InterstitialState.SHOWING:
		return "showing"
	if _interstitial_state == InterstitialState.FAILED:
		return "failed"
	if _interstitial_state != InterstitialState.READY or _interstitial_ready_id.is_empty():
		return "not_ready"
	if _interstitial_expired():
		return "expired"
	return ""


## Doğal mola sürsün: callback tam bir kez (geç/çift SDK olayı ikinci kez
## çağıramaz; sonuç ekranı ne kaybolur ne ikilenir).
func _finish_break() -> void:
	if _break_done:
		return
	_break_done = true
	var callback: Callable = _break_callback
	_break_callback = Callable()
	if callback.is_valid():
		callback.call()


func _preload_interstitial() -> void:
	if not _ads_enabled():
		return
	match _interstitial_state:
		InterstitialState.LOADING, InterstitialState.READY, InterstitialState.SHOWING:
			return
	if _interstitial_attempts >= INTERSTITIAL_MAX_ATTEMPTS:
		return
	_cancel_timer(_interstitial_retry_timer)
	_interstitial_retry_timer = null
	_set_interstitial_state(InterstitialState.LOADING)
	_interstitial_last_attempt_msec = Time.get_ticks_msec()
	_cancel_timer(_interstitial_timeout_timer)
	_interstitial_timeout_timer = _start_timer(INTERSTITIAL_LOAD_TIMEOUT, _on_interstitial_load_timeout)
	_backend.load_interstitial()


## Talep üzerine (uygunluk anı / doğal mola) sınırlı aralıkla döngüyü sıfırla.
func _kick_interstitial_load() -> void:
	if not _ads_enabled():
		return
	match _interstitial_state:
		InterstitialState.IDLE, InterstitialState.DISMISSED, InterstitialState.FAILED:
			var since: float = float(Time.get_ticks_msec() - _interstitial_last_attempt_msec) / 1000.0
			if since >= ON_DEMAND_MIN_INTERVAL * time_scale:
				_interstitial_attempts = 0
				_preload_interstitial()


func _discard_ready_interstitial() -> void:
	if not _interstitial_ready_id.is_empty():
		_backend.remove_interstitial(_interstitial_ready_id)
		_interstitial_ready_id = ""
	if _interstitial_state == InterstitialState.READY:
		_set_interstitial_state(InterstitialState.IDLE)


func _on_interstitial_loaded(ad_id: String) -> void:
	_cancel_timer(_interstitial_timeout_timer)
	_interstitial_timeout_timer = null
	_cancel_timer(_interstitial_retry_timer)
	_interstitial_retry_timer = null
	_interstitial_attempts = 0
	AdEvents.emit(&"interstitial_loaded", {"ad_id": ad_id, "active_elapsed_sec": _active_elapsed})
	if _interstitial_state == InterstitialState.SHOWING:
		# Gösterim sürerken gelen ikinci yükleme: kapanınca hazır olacak.
		_interstitial_ready_id = ad_id
		_interstitial_loaded_msec = Time.get_ticks_msec()
		return
	if not _interstitial_ready_id.is_empty() and _interstitial_ready_id != ad_id:
		_backend.remove_interstitial(_interstitial_ready_id)
	_interstitial_ready_id = ad_id
	_interstitial_loaded_msec = Time.get_ticks_msec()
	_set_interstitial_state(InterstitialState.READY)


func _on_interstitial_failed_to_load(ad_id: String, code: int, message: String) -> void:
	AdEvents.emit(&"interstitial_load_failed", {"ad_id": ad_id, "code": code, "message": message,
		"active_elapsed_sec": _active_elapsed})
	if _interstitial_state != InterstitialState.LOADING:
		return
	_cancel_timer(_interstitial_timeout_timer)
	_interstitial_timeout_timer = null
	_set_interstitial_state(InterstitialState.FAILED)
	_interstitial_attempts += 1
	if _interstitial_attempts < INTERSTITIAL_MAX_ATTEMPTS:
		var delay: float = INTERSTITIAL_RETRY_DELAYS[mini(_interstitial_attempts - 1, INTERSTITIAL_RETRY_DELAYS.size() - 1)]
		_cancel_timer(_interstitial_retry_timer)
		_interstitial_retry_timer = _start_timer(delay, _on_interstitial_retry)


func _on_interstitial_load_timeout() -> void:
	_interstitial_timeout_timer = null
	if _interstitial_state != InterstitialState.LOADING:
		return
	_on_interstitial_failed_to_load("", -1, "load timeout")


func _on_interstitial_retry() -> void:
	_interstitial_retry_timer = null
	if _interstitial_state == InterstitialState.FAILED:
		_preload_interstitial()


func _on_interstitial_showed(ad_id: String) -> void:
	if _interstitial_state != InterstitialState.SHOWING or ad_id != _interstitial_showing_id:
		AdEvents.emit(&"interstitial_showed", {"ad_id": ad_id, "stale": true,
			"active_elapsed_sec": _active_elapsed})
		return
	_cancel_timer(_interstitial_confirm_timer)
	_interstitial_confirm_timer = null
	_interstitial_shows += 1
	AdEvents.emit(&"interstitial_showed", {"ad_id": ad_id, "natural_break": _break_name,
		"active_elapsed_sec": _active_elapsed})
	# Gerçek tam ekran gösterim başladı: saat şimdi sıfırlanır (yalnız burada).
	_active_elapsed = 0.0
	_interstitial_eligible = false


func _on_interstitial_impression(ad_id: String) -> void:
	AdEvents.emit(&"interstitial_impression", {"ad_id": ad_id, "natural_break": _break_name,
		"active_elapsed_sec": _active_elapsed})


func _on_interstitial_clicked(_ad_id: String) -> void:
	pass


func _on_interstitial_dismissed(ad_id: String) -> void:
	if _interstitial_state != InterstitialState.SHOWING or ad_id != _interstitial_showing_id:
		AdEvents.emit(&"interstitial_dismissed", {"ad_id": ad_id, "stale": true,
			"active_elapsed_sec": _active_elapsed})
		if ad_id == _interstitial_showing_id and not ad_id.is_empty():
			# Onay zaman aşımından SONRA kapanan gerçek gösterim: yalnız bekleme.
			_interstitial_showing_id = ""
			_start_fullscreen_cooldown()
		return
	_cancel_timer(_interstitial_confirm_timer)
	_interstitial_confirm_timer = null
	_cancel_timer(_interstitial_resume_timer)
	_interstitial_resume_timer = null
	AdEvents.emit(&"interstitial_dismissed", {"ad_id": ad_id, "natural_break": _break_name,
		"active_elapsed_sec": _active_elapsed})
	_interstitial_showing_id = ""
	_set_interstitial_state(InterstitialState.READY if not _interstitial_ready_id.is_empty()
		else InterstitialState.DISMISSED)
	_start_fullscreen_cooldown()
	rewarded_availability_changed.emit()
	_finish_break()
	_preload_interstitial()


func _on_interstitial_failed_to_show(ad_id: String, code: int, message: String) -> void:
	var active: bool = _interstitial_state == InterstitialState.SHOWING and ad_id == _interstitial_showing_id
	AdEvents.emit(&"interstitial_show_failed", {"ad_id": ad_id, "code": code, "message": message,
		"natural_break": _break_name if active else "", "stale": not active,
		"active_elapsed_sec": _active_elapsed})
	_backend.remove_interstitial(ad_id)
	if not active:
		return
	_cancel_timer(_interstitial_confirm_timer)
	_interstitial_confirm_timer = null
	_cancel_timer(_interstitial_resume_timer)
	_interstitial_resume_timer = null
	_interstitial_showing_id = ""
	# Saat sıfırlanmaz, uygunluk kalır (gerçek gösterim olmadı).
	_set_interstitial_state(InterstitialState.READY if not _interstitial_ready_id.is_empty()
		else InterstitialState.FAILED)
	rewarded_availability_changed.emit()
	_finish_break()
	_preload_interstitial()


## `show` sonrası SDK onayı gelmedi: mola beklemez, sonuç açılır; gösterim
## gerçekten sonradan gelirse kapanışı yalnız bekleme başlatır.
func _on_interstitial_confirm_timeout() -> void:
	_interstitial_confirm_timer = null
	if _interstitial_state != InterstitialState.SHOWING or _break_done:
		return
	AdEvents.emit(&"interstitial_show_failed", {"ad_id": _interstitial_showing_id, "code": -1,
		"message": "show confirm timeout", "natural_break": _break_name,
		"active_elapsed_sec": _active_elapsed})
	# Reklam eklenti önbelleğinde kalır: geç de olsa gösterilirse kapanışı
	# eklenti kendisi düşürür; gösterilmezse önbellek tavanı eskiyi atar.
	_set_interstitial_state(InterstitialState.READY if not _interstitial_ready_id.is_empty()
		else InterstitialState.FAILED)
	rewarded_availability_changed.emit()
	_finish_break()
	_preload_interstitial()


func _on_interstitial_resume_grace() -> void:
	_interstitial_resume_timer = null
	if _interstitial_state == InterstitialState.SHOWING:
		_on_interstitial_dismissed(_interstitial_showing_id)


func _set_interstitial_state(state: InterstitialState) -> void:
	if state == _interstitial_state:
		return
	_interstitial_state = state
	interstitial_state_changed.emit(state)


# --- Banner ----------------------------------------------------------------------

## Main ekran değiştirdikçe çağırır. Banner yalnız BANNER_SURFACES'ta görünür;
## sonuç ekranında gizlenir (arkada sızan banner yok).
func set_surface(surface: Surface) -> void:
	if surface == _surface:
		return
	_surface = surface
	_sync_banner()


## Ekranların altta ayırdığı pay (tuval px). Eklenti varsa açılışta
## hesaplanır ve oturum boyunca SABİT kalır: dolu/boş fark etmez, düzen
## zıplamaz (boşken zemin görünür). Eklenti yoksa ya da onboarding
## tamamlanmamışsa 0 (tam düzen).
func banner_slot_px() -> float:
	return _banner_slot_px


func _compute_banner_slot() -> void:
	var height_dp: int = _backend.adaptive_banner_height_dp() if _onboarding_completed else 0
	var previous: float = _banner_slot_px
	if height_dp <= 0:
		_banner_slot_px = 0.0
	else:
		var window: Vector2 = Vector2(DisplayServer.window_get_size())
		var canvas_width: float = float(ProjectSettings.get_setting("display/window/size/viewport_width", 720))
		var scale: float = canvas_width / window.x if window.x > 0.0 else 1.0
		_banner_slot_px = ceilf(float(height_dp) * _backend.density() * scale)
	UiKit.set_banner_slot(_banner_slot_px)
	if not is_equal_approx(previous, _banner_slot_px):
		banner_slot_changed.emit(_banner_slot_px)


func _banner_wanted() -> bool:
	return _ads_enabled() and BANNER_SURFACES.has(_surface) and not _app_paused


func _sync_banner() -> void:
	if _backend == null:
		return
	if _banner_wanted():
		match _banner_state:
			BannerState.IDLE:
				_load_banner()
			BannerState.FAILED:
				if _banner_retry_timer == null and _banner_attempts < BANNER_MAX_ATTEMPTS:
					_load_banner()
			BannerState.LOADED:
				_backend.show_banner(_banner_ad_id)
				_set_banner_state(BannerState.SHOWN)
	else:
		if _banner_state == BannerState.SHOWN:
			_backend.hide_banner(_banner_ad_id)
			_set_banner_state(BannerState.LOADED)


func _load_banner() -> void:
	_cancel_timer(_banner_retry_timer)
	_banner_retry_timer = null
	_set_banner_state(BannerState.LOADING)
	_backend.load_banner()


func _on_banner_loaded(ad_id: String, width_dp: int, height_dp: int, refreshed: bool) -> void:
	AdEvents.emit(&"banner_loaded", {"ad_id": ad_id, "width_dp": width_dp, "height_dp": height_dp,
		"refreshed": refreshed, "surface": _surface})
	if refreshed:
		return
	_banner_ad_id = ad_id
	_banner_attempts = 0
	_set_banner_state(BannerState.LOADED)
	_sync_banner()


func _on_banner_failed_to_load(ad_id: String, code: int, message: String) -> void:
	AdEvents.emit(&"banner_load_failed", {"ad_id": ad_id, "code": code, "message": message,
		"surface": _surface})
	if _banner_state != BannerState.LOADING:
		return
	_set_banner_state(BannerState.FAILED)
	_banner_attempts += 1
	if _banner_attempts < BANNER_MAX_ATTEMPTS:
		var delay: float = BANNER_RETRY_DELAYS[mini(_banner_attempts - 1, BANNER_RETRY_DELAYS.size() - 1)]
		_cancel_timer(_banner_retry_timer)
		_banner_retry_timer = _start_timer(delay, _on_banner_retry)


func _on_banner_retry() -> void:
	_banner_retry_timer = null
	if _banner_state == BannerState.FAILED:
		_sync_banner()


func _on_banner_impression(ad_id: String) -> void:
	AdEvents.emit(&"banner_impression", {"ad_id": ad_id, "surface": _surface})


func _on_banner_clicked(ad_id: String) -> void:
	AdEvents.emit(&"banner_clicked", {"ad_id": ad_id, "surface": _surface})


func _set_banner_state(state: BannerState) -> void:
	if state == _banner_state:
		return
	_banner_state = state
	banner_state_changed.emit(state)


# --- Zamanlayıcılar --------------------------------------------------------------

func _start_timer(seconds: float, callback: Callable) -> SceneTreeTimer:
	if not is_inside_tree():
		return null
	var timer: SceneTreeTimer = get_tree().create_timer(maxf(seconds * time_scale, 0.001), true)
	timer.timeout.connect(callback)
	return timer


## SceneTreeTimer durdurulamaz; bağlantısı koparılır (callback gelmez).
func _cancel_timer(timer: SceneTreeTimer) -> void:
	if timer == null or not is_instance_valid(timer):
		return
	for connection in timer.timeout.get_connections():
		timer.timeout.disconnect(connection["callable"])


# --- Testler / teşhis --------------------------------------------------------------

func describe() -> String:
	return "ads=%s sdk=%s onb=%s rewarded=%s ready=%s inter=%s elig=%s active=%.0f cool=%.0f banner=%s surface=%s slot=%d req=%s" % [
		AdsState.keys()[_state], str(_sdk_ready), str(_onboarding_completed),
		RewardedState.keys()[_rewarded_state], str(is_rewarded_ready()),
		InterstitialState.keys()[_interstitial_state], str(_interstitial_eligible), _active_elapsed,
		_fullscreen_cooldown, BannerState.keys()[_banner_state], Surface.keys()[_surface],
		int(_banner_slot_px), str(_request["active"])]


func rewarded_attempts() -> int:
	return _rewarded_attempts


func banner_attempts() -> int:
	return _banner_attempts


func interstitial_attempts() -> int:
	return _interstitial_attempts


func interstitial_shows() -> int:
	return _interstitial_shows


func consent_attempts() -> int:
	return _consent_attempts


func has_pending_rewarded_retry() -> bool:
	return _rewarded_retry_timer != null


func has_pending_banner_retry() -> bool:
	return _banner_retry_timer != null


func has_pending_interstitial_retry() -> bool:
	return _interstitial_retry_timer != null


func has_pending_consent_retry() -> bool:
	return _consent_retry_timer != null


func banner_ad_id() -> String:
	return _banner_ad_id


func interstitial_ready_id() -> String:
	return _interstitial_ready_id


func interstitial_showing_id() -> String:
	return _interstitial_showing_id


func break_pending() -> bool:
	return not _break_done


func request_info() -> Dictionary:
	return _request.duplicate()
