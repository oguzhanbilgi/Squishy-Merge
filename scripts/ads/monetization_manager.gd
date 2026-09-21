class_name MonetizationManager
extends Node
## Tek üretim reklam soyutlaması (M8.9-01): rıza (UMP) yaşam döngüsü, SDK
## başlatma, ödüllü reklam durum makinesi (devam + refill), banner yaşam
## döngüsü, hazırlık/önbellek stratejisi ve analitik olay dikişi.
##
## Oyun/UI eklenti içlerini BİLMEZ: Main bu düğümü mevcut sağlayıcı dikişine
## (`Main.set_rewarded_provider`) takar ve yalnız şu yüzeyi kullanır:
##   show_rewarded_revive(main) / show_rewarded_power(main, type, token)
##   is_rewarded_ready() / rewarded_note() / ensure_rewarded()
##   cancel_rewarded_request() / set_surface(surface)
##   privacy_options_required() / show_privacy_options()
## SDK tarafı `AdBackend` arayüzü (gerçek: AdmobBackend; testler tools/
## altındaki sahte arka uçla aynı arayüzü sürer).
##
## KİLİTLİ ÜRÜN KURALLARI (GAME_DESIGN §5.7.3 / §11) burada DEĞİŞMEZ:
##   - devam hakkı yalnız `Main.grant_revive()` ile (round başına 2, board sayar)
##   - ödüllü refill yalnız `Main.grant_rewarded_power(type, token)` ile
##     (günde 1, dört gücün toplamı; kotayı RewardedPolicy tüketir)
##   - ikisi de YALNIZ SDK'nın "ödül kazanıldı" callback'iyle ve yalnız açık
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
## Ödüllü: tek tam ekran reklam aynı anda; talep bağlamı (tür, güç, token,
## ad_id, sıra no) ile stale/duplicate/yanlış-istek callback'leri elenir.
## Önyükleme: izin + SDK sonrası; tüketilince/kapanınca bir sonraki; hata →
## sınırlı geri çekilme (5/15/45/120/300 sn, en çok 8 deneme; pencere
## açılınca talep üzerine bir deneme daha). Banner yalnız Ana Sayfa / Mağaza /
## Koleksiyon'da (docs/monetization/ADS_SYSTEM.md §6); oyun ekranı ve
## Harita v1'de banner DIŞI (gerekçe orada). Kayda hiçbir şey yazmaz.

signal ads_state_changed(state: int)
## Ödüllü reklamın "hazır" durumu ya da notu değişti — açık pencere tazelenir.
signal rewarded_availability_changed
signal banner_state_changed(state: int)
signal privacy_options_changed(required: bool)

enum AdsState { UNAVAILABLE, CONSENT_CHECKING, CONSENT_FORM, ADS_ALLOWED, ADS_NOT_ALLOWED, ERROR_WITH_PREVIOUS_STATE }
enum RewardedState { IDLE, LOADING, READY, SHOWING, REWARD_EARNED, DISMISSED, FAILED }
enum RewardedKind { NONE, REVIVE, REFILL }
enum BannerState { IDLE, LOADING, LOADED, SHOWN, FAILED }
enum Surface { NONE, HOME, MAP, SHOP, COLLECTION, GAMEPLAY, RESULT }
enum FormPurpose { NONE, STARTUP, PRIVACY_OPTIONS }

## v1 banner yüzeyleri: yalnız düzeni alt payı ayıran menü ekranları.
const BANNER_SURFACES: Array[int] = [Surface.HOME, Surface.SHOP, Surface.COLLECTION]
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
	"type": -1, "token": 0, "ad_id": "", "earned": false, "cancelled": false}

## Testler zamanlayıcıları hızlandırır (1.0 = gerçek süre).
static var time_scale: float = 1.0

var _backend: AdBackend = null
var _config: AdConfig = null

var _state: AdsState = AdsState.UNAVAILABLE
var _consent_checked: bool = false
var _consent_attempts: int = 0
var _consent_last_attempt_msec: int = -1000000
var _consent_retry_timer: SceneTreeTimer = null
var _form_purpose: FormPurpose = FormPurpose.NONE
var _privacy_options_required: bool = false
var _sdk_ready: bool = false
var _sdk_initializing: bool = false
var _app_paused: bool = false

var _rewarded_state: RewardedState = RewardedState.IDLE
var _ready_ad_id: String = ""
var _rewarded_attempts: int = 0
var _rewarded_retry_timer: SceneTreeTimer = null
var _rewarded_timeout_timer: SceneTreeTimer = null
var _rewarded_last_attempt_msec: int = -100000
var _resume_grace_timer: SceneTreeTimer = null
var _request_seq: int = 0
## Açık talep: {active, id, kind, main, type, token, ad_id, earned, cancelled}
var _request: Dictionary = EMPTY_REQUEST.duplicate()

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
	if _backend == null:
		_set_state(AdsState.UNAVAILABLE)
		return
	_backend.attach(self)
	_connect_backend()
	_compute_banner_slot()
	print_verbose("MonetizationManager: %s, %s" % [_backend.backend_name(),
		_config.describe() if _config != null else "config yok"])
	_start_consent()


func _exit_tree() -> void:
	_cancel_timer(_consent_retry_timer)
	_cancel_timer(_rewarded_retry_timer)
	_cancel_timer(_rewarded_timeout_timer)
	_cancel_timer(_banner_retry_timer)
	_cancel_timer(_resume_grace_timer)
	if _banner_state == BannerState.SHOWN and _backend != null:
		_backend.hide_banner(_banner_ad_id)
	UiKit.set_banner_slot(0.0)


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


func banner_state() -> BannerState:
	return _banner_state


func surface() -> Surface:
	return _surface


func backend() -> AdBackend:
	return _backend


func has_backend() -> bool:
	return _backend != null


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

func _start_consent() -> void:
	_cancel_timer(_consent_retry_timer)
	_consent_retry_timer = null
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


# --- SDK ------------------------------------------------------------------------

func _ensure_sdk() -> void:
	if _sdk_ready or _sdk_initializing:
		_preload_rewarded()
		_sync_banner()
		return
	_sdk_initializing = true
	_backend.initialize()


func _on_initialization_completed() -> void:
	_sdk_initializing = false
	_sdk_ready = true
	rewarded_availability_changed.emit()
	_preload_rewarded()
	_sync_banner()


# --- Ödüllü — Main sağlayıcı dikişi ---------------------------------------------

## Yüklenmiş bir ödüllü reklam ŞİMDİ gösterilebilir mi? Pencerelerin CTA'sı
## yalnız bu true iken aktif (M8.6-10 sözleşmesi: çalışmayacak buton yok).
func is_rewarded_ready() -> bool:
	return (_rewarded_state == RewardedState.READY and not _ready_ad_id.is_empty()
		and ads_allowed() and _sdk_ready and _backend != null)


## CTA pasifken pencerede yazan sebep; hazırken boş.
func rewarded_note() -> String:
	if _backend == null or _state == AdsState.UNAVAILABLE:
		return NOTE_NO_BACKEND
	match _state:
		AdsState.CONSENT_CHECKING, AdsState.CONSENT_FORM:
			return NOTE_PREPARING
		AdsState.ADS_NOT_ALLOWED:
			return NOTE_UNAVAILABLE
	if not _sdk_ready:
		return NOTE_PREPARING
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
	if _backend == null:
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
	_show_rewarded(main, RewardedKind.REVIVE, -1, 0)


func show_rewarded_power(main: Node, type: int, token: int) -> void:
	_show_rewarded(main, RewardedKind.REFILL, type, token)


func _show_rewarded(main: Node, kind: RewardedKind, type: int, token: int) -> void:
	var ctx: Dictionary = _context(kind, type)
	AdEvents.emit(&"rewarded_requested", ctx)
	if _request["active"]:
		# Aynı anda ikinci tam ekran reklam yok (devam + refill birlikte olamaz).
		_notify_unavailable(main, kind, NOTE_SHOWING)
		return
	if not is_rewarded_ready():
		_notify_unavailable(main, kind, rewarded_note())
		ensure_rewarded()
		return
	_request_seq += 1
	_request = {
		"active": true, "id": _request_seq, "kind": kind, "main": main,
		"type": type, "token": token, "ad_id": _ready_ad_id,
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


func _context(kind: RewardedKind, type: int) -> Dictionary:
	var ctx: Dictionary = {"placement": _placement_name(kind)}
	if kind == RewardedKind.REFILL and PowerUp.is_valid_type(type):
		ctx["power"] = PowerUp.save_key(type as PowerUp.Type)
	return ctx


func _placement_name(kind: RewardedKind) -> String:
	match kind:
		RewardedKind.REVIVE:
			return "revive"
		RewardedKind.REFILL:
			return "refill"
	return "preload"


func _request_context() -> Dictionary:
	if not _request["active"]:
		return {"placement": "preload"}
	var ctx: Dictionary = _context(_request["kind"], _request["type"])
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


func _clear_request() -> void:
	_request = EMPTY_REQUEST.duplicate()


# --- Ödüllü — yükleme / önbellek ---------------------------------------------

func _preload_rewarded() -> void:
	if _backend == null or not ads_allowed() or not _sdk_ready:
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
## geçer (board / kota / token kendi kontrollerini yapar).
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


func _on_rewarded_dismissed(ad_id: String) -> void:
	if _request["active"] and _request["ad_id"] != ad_id:
		# Başka bir (eski) reklamın kapanışı; açık talebe dokunulmaz.
		AdEvents.emit(&"rewarded_dismissed", {"placement": "preload", "ad_id": ad_id, "stale": true})
		return
	_cancel_timer(_resume_grace_timer)
	_resume_grace_timer = null
	var ctx: Dictionary = {"placement": "preload", "ad_id": ad_id}
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
		rewarded_availability_changed.emit()
		_preload_rewarded()


# --- Banner ----------------------------------------------------------------------

## Main ekran değiştirdikçe çağırır. Banner yalnız BANNER_SURFACES'ta görünür;
## oyun / sonuç / harita / pencereli tam ekranlarda gizlenir (arkada sızan
## banner yok).
func set_surface(surface: Surface) -> void:
	if surface == _surface:
		return
	_surface = surface
	_sync_banner()


## Ekranların altta ayırdığı pay (tuval px). Eklenti varsa açılışta
## hesaplanır ve oturum boyunca SABİT kalır: dolu/boş fark etmez, düzen
## zıplamaz (boşken zemin görünür). Eklenti yoksa 0.
func banner_slot_px() -> float:
	return _banner_slot_px


func _compute_banner_slot() -> void:
	var height_dp: int = _backend.adaptive_banner_height_dp()
	if height_dp <= 0:
		_banner_slot_px = 0.0
		UiKit.set_banner_slot(0.0)
		return
	var window: Vector2 = Vector2(DisplayServer.window_get_size())
	var canvas_width: float = float(ProjectSettings.get_setting("display/window/size/viewport_width", 720))
	var scale: float = canvas_width / window.x if window.x > 0.0 else 1.0
	_banner_slot_px = ceilf(float(height_dp) * _backend.density() * scale)
	UiKit.set_banner_slot(_banner_slot_px)


func _banner_wanted() -> bool:
	return (_backend != null and ads_allowed() and _sdk_ready
		and BANNER_SURFACES.has(_surface) and not _app_paused)


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
	return "ads=%s sdk=%s rewarded=%s ready=%s banner=%s surface=%s slot=%d req=%s" % [
		AdsState.keys()[_state], str(_sdk_ready), RewardedState.keys()[_rewarded_state],
		str(is_rewarded_ready()), BannerState.keys()[_banner_state], Surface.keys()[_surface],
		int(_banner_slot_px), str(_request["active"])]


func rewarded_attempts() -> int:
	return _rewarded_attempts


func banner_attempts() -> int:
	return _banner_attempts


func consent_attempts() -> int:
	return _consent_attempts


func has_pending_rewarded_retry() -> bool:
	return _rewarded_retry_timer != null


func has_pending_banner_retry() -> bool:
	return _banner_retry_timer != null


func has_pending_consent_retry() -> bool:
	return _consent_retry_timer != null


func banner_ad_id() -> String:
	return _banner_ad_id


func request_info() -> Dictionary:
	return _request.duplicate()
