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
##   set_age_band(band)                      (TASK/043 — yaş bandı yönlendirmesi)
##   privacy_options_required() / show_privacy_options()
## SDK tarafı `AdBackend` arayüzü (gerçek: AdmobBackend; testler tools/
## altındaki sahte arka uçla aynı arayüzü sürer).
##
## KİLİTLİ ÜRÜN KURALLARI (GAME_DESIGN §5.7.3 / §11 / docs/monetization/
## DAILY_REWARDS.md) burada DEĞİŞMEZ:
##   - devam hakkı yalnız `Main.grant_revive()` ile (round başına 2, board sayar)
##   - ödüllü refill yalnız `Main.grant_rewarded_power(type, token)` ile
##     (TASK/060: güç başına günde 2, dört bağımsız sayaç; kotayı RewardedPolicy tüketir)
##   - günlük reklamlı sandık / Hamur yalnız `Main.grant_daily_chest(day_key,
##     token)` / `Main.grant_daily_dough(day_key, token)` ile (günde 2 / 1;
##     kotayı DailyRewards tüketir)
##   - hepsi YALNIZ SDK'nın "ödül kazanıldı" callback'iyle ve yalnız açık
##     talebin ad_id'siyle bir kez; kapanma / yüklenememe / gösterilememe /
##     çevrimdışı HİÇBİR ŞEY vermez ve kota tüketmez.
##
## Rıza (UMP) — SDK durumu tek gerçek, kendi GDPR önbelleğimiz yok:
##   her açılışta update → gerekiyorsa form → UMP `canRequestAds()` →
##   ADS_ALLOWED / ADS_NOT_ALLOWED; update hata verirse yine `canRequestAds()`
##   (SDK önceki oturumun rızasını taşır → ERROR_WITH_PREVIOUS_STATE). M9-01:
##   kapı resmî `canRequestAds()` (yamalı eklenti); SDK başlatma ve HER reklam
##   yüklemesinden hemen önce yeniden sorulur. Eklenti sunmuyorsa M8.9'un
##   türetilmiş eşdeğerine düşülür (uyarıyla). Gizlilik seçenekleri satırı
##   `getPrivacyOptionsRequirementStatus() == REQUIRED`, formu
##   `showPrivacyOptionsForm()`. Sonsuz bekleme yok:
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
## Geçiş reklamı (M8.9-02; TASK/052 sıklık politikası `AdPolicy`): önceki gerçek
## gösterimden bu yana en az 2 KESİNLEŞEN NORMAL round (`note_normal_round_finalized`,
## Main) VE 300 sn AKTİF ön plan süresi sonra "uygun" olur ama HİÇBİR ZAMAN oyun
## ortasında açılmaz — yalnız Main'in doğal molasında (round kesin bitti, devam
## kararları tamamlandı, sonuç ekranı henüz açılmadı) `try_show_interstitial` ile;
## hazır değilse sonuç HEMEN açılır, uygunluk kalır. Sayaç + saat gerçek gösterimde
## (SDK "gösterildi") ya da "gösterildi"si kaybolmuş bir reklamın kapanışında (gösterim
## sayılmadan) sıfırlanır. Herhangi bir tam ekran reklam kapanışından sonra 60 sn
## aktif süre boyunca geçiş reklamı bastırılır (art arda iki tam ekran reklam yok).
##
## Tam ekran KİRASI (TASK/052): gösterim çağrısı SDK'ya gittiği an (geri alınamaz)
## uygulamanın kendi engelleyici durumu — geçiş molası / ödüllü talep — bir kiraya
## bağlanır. SDK'nın kapanış / gösterim hatası geri çağrıları belirleyicidir; gelmezse
## uygulama kendi durumunu YALNIZ örtülmediğine dair kanıtla bırakır (bkz. "Tam ekran
## kirası" bölümü) — duraklatılmışken (reklam üstte / arka plan) ve ödüllüde SDK
## "gösterildi" dedikten sonra süreye bağlı bırakma yok. SDK'nın reklamı kapatılmaz / taklit
## edilmez, ödül verilmez, gösterim sayılmaz. Yüklenmiş reklamlar (geçiş + ödüllü) bir saat
## dolmadan tazelenir (motor saati + duvar saati — cihaz uykusunda motor saati durur).
##
## Banner: Ana Sayfa / Harita / Mağaza / Koleksiyon / oyun ekranı
## (docs/monetization/ADS_SYSTEM.md §6); sonuç ekranında gizli. Yuva açılışta
## bir kez hesaplanır ve sabit kalır; onboarding tamamlanmamışsa yuva 0 ve
## hiçbir reklam yüklenmez (tutorial M8.10). Kayda hiçbir şey yazmaz.
##
## İstek yapılandırması (TASK/042, GMA 25.3.0): SDK başlatma arka ucun işi — derece,
## TFCD / TFUA ve yaş işlemi (TFAT) MobileAds.initialize() ÖNCESİ bir kez uygulanır,
## geri okunup doğrulanır; doğrulanamazsa SDK başlamaz (reklam yok).
##
## YAŞ BANDI YÖNLENDİRMESİ (TASK/043, owner kararı — docs/monetization/AGE_BAND_ROUTING.md):
## tek girdi `set_age_band()` (Main, nötr yaş ekranından türetilmiş bant; doğum tarihi
## buraya HİÇ gelmez). Rota `AgeGate.ad_route()`:
##   UNKNOWN / UNDER_13 -> kapı KAPALI: eklenti düğümü kurulmaz (attach yok), UMP
##                         sorulmaz, SDK başlamaz, hiçbir reklam yüklenmez / gösterilmez,
##                         yuva 0, aktif süre saymaz (fail-closed, ASLA yetişkin yolu).
##   TEEN               -> TFAT TEEN + en yüksek derece "T"
##   ADULT              -> TFAT UNSPECIFIED + en yüksek derece "MA"
## Sıra: bant -> rota arka uca (attach'ten ÖNCE) -> attach -> UMP / canRequestAds ->
## initialize() (yapılandırma + geri okuma doğrulaması, SONRA MobileAds.initialize) ->
## SDK hazır -> yüklemeler (+ onboarding). SDK yapılandırıldıktan sonra rota KİLİTLİ: bant
## bu süreçte değişirse işlem değiştirilmez — reklam oturumun geri kalanında kapanır
## (banner gizlenir, ödüllü / geçiş yok) ve yeni bant bir sonraki soğuk açılışta SDK'dan
## önce uygulanır (`AgeBandChange.NEXT_LAUNCH`). Play Age Signals reklama ASLA bağlanmaz.

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
## `set_age_band()` sonucu (TASK/043): UNCHANGED aynı bant; APPLIED uygulandı (ya da SDK
## henüz yapılandırılmadığı için bekleyen rota güncellendi); NEXT_LAUNCH SDK bu süreçte
## eski bantla yapılandırıldı — reklam bu oturumda kapandı, yeni bant bir sonraki soğuk
## açılışta; ADS_STOPPED reklamsız banda (UNKNOWN / UNDER_13) geçildi, reklam durdu.
enum AgeBandChange { UNCHANGED, APPLIED, NEXT_LAUNCH, ADS_STOPPED }
## Tam ekran kirasının biçimi (TASK/052): hangi uygulama durumu bekliyor — geçiş molası ya da ödüllü talep.
enum LeaseKind { NONE, INTERSTITIAL, REWARDED }

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
## Uygulama öne dönünce (APPLICATION_RESUMED) tam ekran kirası hâlâ açıksa SDK'nın
## kapanış geri çağrısı için tanınan pay; sonra kira kurtarılır (ödüllüde ödülsüz kapanış).
const SHOW_RESUME_GRACE: float = 3.0
## Tam ekran kirası (TASK/052): uygulama ÖRTÜLMEMİŞ ön plandayken (gösterim isteğinden /
## SDK "gösterildi"den beri hiç APPLICATION_PAUSED yok, ya da girdi kanıtından beri) SDK
## susarsa kira bu kadar sn sonra kurtarılır. Değer TASK/048'in kabul ettiği gösterim onay
## sınırı; A36: istekten reklamın Godot'yu örtmesine (PAUSED) 55–65 ms, SDK "gösterildi"ye
## 91–149 ms. Ekranda gerçekten açılan tam ekran reklam (GMA AdActivity) uygulamayı duraklatır ve
## örtülüyken bu süre işlemez — reklam ne kadar uzun sürerse sürsün meşru reklam kesilmez (A36 + GMA 25.3'te
## doğrulandı; SDK / eklenti değişirse ya da üçüncü taraf reklam ağı eklenirse yeniden doğrulanmalı — ADS_SYSTEM
## §18.5). Ödüllüde SDK "gösterildi" dedikten SONRA bu süre hiç işlemez: ödül sözü süreye bağlı kesilmesin diye
## yalnız girdi kanıtı ya da duraklatma + öne dönüş payı (`_lease_on_showed`).
const FULLSCREEN_UNCOVERED_LEASE_SEC: float = 5.0
## Tek karede aktif saate eklenebilecek en uzun süre (sn): arka plandan / uykudan dönüşte ilk karenin dev delta'sı
## (durdurulan süre) aktif süreye ve beklemeye sızmasın; gerçek takılmaları ancak eksik sayar (muhafazakâr).
const ACTIVE_TICK_MAX_SEC: float = 1.0
## Kira kurtarma sebebi (olay bağlamı `recovered`).
const RECOVERY_RESUME_GRACE: String = "resume_grace"
const RECOVERY_UNCOVERED_LEASE: String = "uncovered_lease"
const RECOVERY_INPUT_EVIDENCE: String = "input_evidence"
## Kurtarılan / kapanan reklam kimliklerinden en son kaç tanesi "emekli" tutulur: geç ya da
## sahipsiz geri çağrılar bunlara karşı elenir (eklentinin Java tarafı kapanan geçiş reklamını
## kendiliğinden yeniden yükler ama cephe onu önbellekten düşürür — o sahipsiz yüklemenin
## hatası eski kimlikle gelir ve o an süren önyüklemeye ait DEĞİLDİR).
const RETIRED_ID_MEMORY: int = 4

## Herhangi bir tam ekran reklam kapanışından sonra geçiş reklamı için bekleme (aktif sn) —
## art arda iki tam ekran reklam yok. Tek kaynak `AdPolicy` (TASK/052).
const FULLSCREEN_AD_COOLDOWN_SEC: float = AdPolicy.FULLSCREEN_AD_COOLDOWN_SEC
const INTERSTITIAL_RETRY_DELAYS: Array[float] = [15.0, 60.0, 180.0, 600.0]
const INTERSTITIAL_MAX_ATTEMPTS: int = 6
const INTERSTITIAL_LOAD_TIMEOUT: float = 60.0
## Google: önbelleklenmiş reklam bir saat sonra süresi dolar → daha önce
## tazelenir (yüklenmiş reklamın en fazla yaşı, aktif değil gerçek sn).
const INTERSTITIAL_MAX_AGE_SEC: float = 3300.0
## Ödüllü reklam da bir saatte sona erer (Google'ın Android ödüllü rehberi) — aynı tazeleme sınırı (TASK/052).
const REWARDED_MAX_AGE_SEC: float = INTERSTITIAL_MAX_AGE_SEC
## `show` sonrası SDK "gösterildi" demezse (eklenti yüklenmemiş reklamda sinyalsiz uyarı
## basar) mola bu kadar sn sonra hatasız sürdürülür — TASK/052'den beri tam ekran kirasının
## örtülmemiş sınırı (TASK/048 adı korunur; uygulama duraklatılmışken işlemez).
const INTERSTITIAL_SHOW_CONFIRM_TIMEOUT: float = FULLSCREEN_UNCOVERED_LEASE_SEC

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
## Arka uç UMP'nin resmî çağrılarını sunuyor mu (M9-01 yamalı eklenti):
## `canRequestAds` / `getPrivacyOptionsRequirementStatus` /
## `showPrivacyOptionsForm`. false → M8.9 türetmesi (uyarı basılır).
var _privacy_api: bool = false
var _sdk_ready: bool = false
var _sdk_initializing: bool = false
## TASK/042: arka uç istek yapılandırmasını doğrulayamadı → SDK başlatılmadı; bu
## oturumda reklam yok, yeniden deneme yok (fail-closed). Notlar "kullanılamıyor" der.
var _sdk_refused: bool = false
var _app_paused: bool = false
## Android: gerçek Activity.onPause'un FOCUS_OUT'u geldi, onResume'un FOCUS_IN'i henüz gelmedi (TASK/052). Bu sürede
## gelen APPLICATION_RESUMED öne dönüş SAYILMAZ (Vulkan: onStart'ta, etkinlik öne gelmeden de gönderilir).
var _app_focus_lost: bool = false
## Son APPLICATION_PAUSED anı — girdi kanıtının dışlama penceresi (TASK/052).
var _paused_msec: int = -1
## RESUMED kaybolmuşken uygulamaya ulaşan dokunuşla öne dönüş sayılan kez (teşhis, TASK/052).
var _input_resumes: int = 0
## Onboarding/tutorial tamamlandı mı (Main kayıttan verir). false: yuva 0,
## hiçbir reklam yüklenmez/gösterilmez, aktif süre sayılmaz.
var _onboarding_completed: bool = true
## TASK/043: yaş bandı (AgeGate.Band). Varsayılan UNKNOWN = kapı kapalı (fail-closed):
## bant verilmeden hiçbir şey başlamaz.
var _age_band: int = AgeGate.Band.UNKNOWN
## Arka uç (eklenti düğümü) bu süreçte kuruldu mu — yalnız TEEN / ADULT rotası verilince.
var _backend_attached: bool = false
## TASK/043: bant, SDK bu süreçte yapılandırıldıktan sonra değişti (ya da rota kabul
## edilmedi) -> oturumun geri kalanında reklam YOK; yeni bant bir sonraki soğuk açılışta.
var _age_session_blocked: bool = false

var _rewarded_state: RewardedState = RewardedState.IDLE
var _ready_ad_id: String = ""
## Hazır ödüllü reklamın yüklenme anı — motor saati + duvar saati (süre dolumu, TASK/052).
var _rewarded_loaded_msec: int = 0
var _rewarded_loaded_unix: float = 0.0
var _rewarded_attempts: int = 0
var _rewarded_retry_timer: SceneTreeTimer = null
var _rewarded_timeout_timer: SceneTreeTimer = null
var _rewarded_last_attempt_msec: int = -100000
var _request_seq: int = 0
## Açık talep: {active, id, kind, main, type, token, day_key, ad_id, earned, cancelled}
var _request: Dictionary = EMPTY_REQUEST.duplicate()

var _interstitial_state: InterstitialState = InterstitialState.IDLE
var _interstitial_ready_id: String = ""
var _interstitial_showing_id: String = ""
var _interstitial_loaded_msec: int = 0
var _interstitial_loaded_unix: float = 0.0
var _interstitial_attempts: int = 0
var _interstitial_retry_timer: SceneTreeTimer = null
var _interstitial_timeout_timer: SceneTreeTimer = null
var _interstitial_last_attempt_msec: int = -100000
## Aktif ön plan süresi (sn) — yalnız sayılabilir anlarda birikir; gerçek gösterimde sıfırlanır.
var _active_elapsed: float = 0.0
## Önceki gerçek geçiş reklamı gösteriminden bu yana kesinleşen NORMAL round sayısı (TASK/052,
## `AdPolicy`); yalnız bellekte — yeni süreç 0'dan başlar (oturumun ilk geçiş reklamı da 2 round ister).
var _interstitial_rounds: int = 0
## İki sayaç (`AdPolicy.forced_interstitial_gates_met`) sağlandı mı — gösterimde düşer.
var _interstitial_eligible: bool = false
## "Gösterildi"si sayılmış son geçiş reklamı kimliği: çift / geç "gösterildi" ikinci kez sayılmaz.
var _interstitial_showed_id: String = ""
## Emekli kimlikler (bkz. RETIRED_ID_MEMORY) — geç / sahipsiz geri çağrılar elenir.
var _retired_interstitial_ids: Array[String] = []
var _retired_rewarded_ids: Array[String] = []
## Tam ekran reklam sonrası kalan bekleme (aktif sn).
var _fullscreen_cooldown: float = 0.0
## Doğal mola: sonuç ekranını süren callback (tam bir kez çağrılır).
var _break_callback: Callable = Callable()
var _break_name: String = ""
var _break_seq: int = 0
var _break_done: bool = true
var _interstitial_shows: int = 0

## --- Tam ekran kirası (TASK/052; bkz. "Tam ekran kirası" bölümü) ---
## Her gösterim çağrısında +1 (geçiş + ödüllü ortak): eski zamanlayıcı yeni kirayı bitiremez.
var _lease_token: int = 0
var _lease_kind: LeaseKind = LeaseKind.NONE
var _lease_ad_id: String = ""
## SDK bu kira için "gösterildi" dedi.
var _lease_showed: bool = false
## Gösterim çağrısından SONRA uygulama duraklatıldı (reklam örtmüş olabilir) → kurtarma sonucu "kapandı". Önceden
## duraklatılmış uygulamada kira bununla başlamaz (o duraklatma reklamımızın kanıtı değil).
var _lease_covered_seen: bool = false
## Kira sürerken APPLICATION_RESUMED geldi (kurtarma sebebi `resume_grace`).
var _lease_resumed_seen: bool = false
## SDK "gösterildi" anı — hiç örtülmemiş ödüllü kirada girdi kanıtının dışlama penceresi.
var _lease_showed_msec: int = -1
## RESUMED gelmemişken uygulamaya yeni bir dokunuş ulaştı: kira örtülmemiş sayılır (bir sonraki PAUSED'a dek).
var _lease_input_uncovered: bool = false
var _lease_timer: SceneTreeTimer = null
var _lease_recoveries: int = 0

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
	_connect_backend()
	print_verbose("MonetizationManager: %s, %s" % [_backend.backend_name(),
		_config.describe() if _config != null else "config yok"])
	# TASK/043: eklenti düğümü, rıza ve SDK YALNIZ yaş bandı reklama izin verince (TEEN /
	# ADULT) açılır; rota (yaş işlemi + derece) attach'ten ve rızadan ÖNCE arka uca gider.
	# UNKNOWN / UNDER_13: hiçbiri — Main yaşı ilk güvenli kabukta sorar (`set_age_band`).
	_open_age_gate()
	_compute_banner_slot()
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
	_cancel_timer(_interstitial_retry_timer)
	_cancel_timer(_interstitial_timeout_timer)
	_cancel_timer(_lease_timer)
	if _banner_state == BannerState.SHOWN and _backend != null:
		_backend.hide_banner(_banner_ad_id)
	UiKit.set_banner_slot(0.0)


func _process(delta: float) -> void:
	_tick_active(minf(delta, ACTIVE_TICK_MAX_SEC))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_app_paused = true
		_paused_msec = Time.get_ticks_msec()
		# TASK/052: banner etkinlik yaşam döngüsüne uyar (Google AdView: pause() onPause'da) — eklentinin gizlemesi
		# GONE + adView.pause(), öne dönüşte gösterme VISIBLE + resume(); aynı AdView, yeni yükleme yok.
		_sync_banner()
		# TASK/052: tam ekran reklam (ya da arka plan) uygulamayı örttü — kira süreye bağlı bırakılmaz.
		_lease_on_paused()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Android: yalnız gerçek Activity.onPause'da gelir (GodotLib.focusout) — etkinlik artık en üstte değil.
		_app_focus_lost = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		if _app_focus_lost:
			# Godot 4.6 Vulkan: oluşturucu iş parçacığı Activity.onStart'ta yeniden başlarken de RESUMED gelir — etkinlik
			# henüz öne gelmedi (ör. HOME / kilit / arama sonrası dönüşte üstte hâlâ tam ekran reklam). Bu RESUMED kirayı
			# ve duraklatmayı bırakmaz; gerçek öne dönüş onResume'un FOCUS_IN'i (ya da girdi kanıtı).
			return
		_on_app_front()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if not _app_focus_lost:
			return
		_app_focus_lost = false
		_on_app_front()


## Uygulama gerçekten önde: APPLICATION_RESUMED (odak kaybı yokken) ya da Activity.onResume'un FOCUS_IN'i. Öne dönüş
## payı yalnız bir duraklatmadan SONRA kurulur (masaüstünde pencere odağı FOCUS_OUT / IN — duraklatma yok — kirayı
## bırakmaz; Android'de öne dönüş her zaman bir duraklatmayı izler).
func _on_app_front() -> void:
	var was_paused: bool = _app_paused
	_app_paused = false
	_sync_banner()
	# Reklam etkinliği kapanmış olmalı; kapanış sinyali kuyrukta. Gelmezse (eklenti / SDK
	# boşluğu) sınırlı payın sonunda kira kurtarılır — kimse sonsuza dek "gösteriliyor"da kalmaz.
	if was_paused:
		_lease_on_resumed()
	# Uykudan dönüş: motor saati uykuda durur, süresi dolmuş hazır reklam duvar saatiyle yakalanır.
	_refresh_stale_ads()


## TASK/052 girdi kanıtı: uygulama penceresine ulaşan YENİ bir dokunuş, üstte tam ekran reklam etkinliği OLMADIĞININ
## kanıtıdır (Android yeni dokunuşu en üstteki pencereye verir; reklam üstteyse dokunuş ona gider). İki kullanım:
##   1. PAUSED geldi, RESUMED gelmedi (yaşam döngüsü kaybı): son PAUSED'dan >= FULLSCREEN_UNCOVERED_LEASE_SEC sonraki
##      basış uygulama düzeyinde öne dönüş sayılır — `_app_paused` düşer (banner, aktif saat ve doğal mola geri gelir;
##      kira olsun olmasın) ve açık kira örtülmemiş sayılır (kurtarma sebebi `input_evidence`).
##   2. Ödüllü kirada SDK "gösterildi" dedi ama uygulama hiç örtülmedi: "gösterildi"den >= aynı süre sonraki basış
##      kiranın örtülmemiş sınırını başlatır (ödüllüde "gösterildi" sonrası süreye bağlı bırakma yok).
## Dışlama pencereleri, reklam etkinliği açılırken eski pencereye düşebilen geçiş dokunuşunu eler. Olay tüketilmez.
func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventMouseButton) or not event.is_pressed():
		return
	var settle: int = int(FULLSCREEN_UNCOVERED_LEASE_SEC * time_scale * 1000.0)
	var now: int = Time.get_ticks_msec()
	if _app_paused:
		if now - _paused_msec < settle:
			return
		_app_paused = false
		_app_focus_lost = false
		_input_resumes += 1
		_sync_banner()
		if _lease_kind != LeaseKind.NONE:
			_lease_input_uncovered = true
			_lease_arm(FULLSCREEN_UNCOVERED_LEASE_SEC)
		_refresh_stale_ads()
		return
	if _lease_kind == LeaseKind.REWARDED and _lease_showed and not _lease_covered_seen and not _lease_input_uncovered \
			and now - _lease_showed_msec >= settle:
		_lease_input_uncovered = true
		_lease_arm(FULLSCREEN_UNCOVERED_LEASE_SEC)


func _connect_backend() -> void:
	_backend.initialization_completed.connect(_on_initialization_completed)
	_backend.consent_info_updated.connect(_on_consent_info_updated)
	_backend.consent_info_update_failed.connect(_on_consent_info_update_failed)
	_backend.consent_form_loaded.connect(_on_consent_form_loaded)
	_backend.consent_form_failed_to_load.connect(_on_consent_form_failed_to_load)
	_backend.consent_form_dismissed.connect(_on_consent_form_dismissed)
	_backend.privacy_options_form_dismissed.connect(_on_privacy_options_form_dismissed)
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


## TASK/042: SDK istek yapılandırması doğrulanamadığı için başlatılmadı (oturum reklamsız).
func sdk_refused() -> bool:
	return _sdk_refused


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


## Arka uca verilmiş yaş işlemi (TASK/042 / TASK/043; arka uç yoksa UNSPECIFIED). Kapı
## kapalıyken (UNKNOWN / UNDER_13) hiçbir şey gönderilmez — bu değer SDK'ya gitmez.
func age_restricted_treatment() -> AdBackend.AgeRestrictedTreatment:
	return _backend.age_restricted_treatment() if _backend != null else AdBackend.AgeRestrictedTreatment.UNSPECIFIED


## Arka uca verilmiş en yüksek reklam derecesi (TASK/043); arka uç yoksa "".
func max_ad_content_rating() -> String:
	return _backend.max_ad_content_rating() if _backend != null else ""


func has_backend() -> bool:
	return _backend != null


## TASK/043: yöneticinin yaş bandı (AgeGate.Band).
func age_band() -> int:
	return _age_band


## TASK/043: eklenti düğümü bu süreçte kuruldu mu (yalnız TEEN / ADULT rotasıyla).
func backend_attached() -> bool:
	return _backend_attached


## TASK/043: bant SDK yapılandırıldıktan sonra değişti -> bu oturumda reklam yok.
func age_session_blocked() -> bool:
	return _age_session_blocked


## Yaş kapısı reklama izin veriyor mu (bant TEEN / ADULT ve oturum kapatılmadı).
func age_ads_allowed() -> bool:
	return _age_ads_allowed()


func _age_ads_allowed() -> bool:
	return not _age_session_blocked and bool(AgeGate.ad_route(_age_band)["ads"])


# --- Yaş bandı yönlendirmesi (TASK/043) ----------------------------------------------

## Main'in TEK girişi: nötr yaş ekranından (ya da kayıttan, soğuk açılışta) türetilmiş
## bant. Ağaca girmeden önce verilirse yalnız saklanır; `_ready` kapıyı açar (ya da
## açmaz). Sonra verilirse:
##   reklamsız banda (UNKNOWN / UNDER_13) geçiş -> kapı hiç açılmadıysa kapalı kalır;
##       açıldıysa reklam oturum boyunca DURUR (ADS_STOPPED)
##   TEEN / ADULT, SDK henüz yapılandırılmadı -> bekleyen rota güncellenir, kapı açılır
##       (attach + yuva + rıza; APPLIED) — SDK başlarken yeni değerler uygulanır
##   TEEN / ADULT, SDK bu süreçte başka rotayla yapılandırıldı -> işlem DEĞİŞTİRİLMEZ
##       (kilit): reklam oturumun geri kalanında kapanır, yeni bant bir sonraki soğuk
##       açılışta SDK'dan önce (NEXT_LAUNCH). Çağıran oyuncuya kısa not gösterir.
func set_age_band(band: int) -> AgeBandChange:
	if band == _age_band:
		return AgeBandChange.UNCHANGED
	_age_band = band
	if _backend == null or not is_node_ready():
		return AgeBandChange.APPLIED
	var route: Dictionary = AgeGate.ad_route(band)
	if not bool(route["ads"]):
		if _backend_attached:
			_block_age_session()
			return AgeBandChange.ADS_STOPPED
		rewarded_availability_changed.emit()
		return AgeBandChange.APPLIED
	if _age_session_blocked:
		return AgeBandChange.NEXT_LAUNCH
	if _backend.request_configured():
		# Yalnız birebir aynı rota sürebilir; değilse arka uca reddettirmeden (hata logu
		# üretmeden) oturumu kapat.
		if route["treatment"] == _backend.age_restricted_treatment() \
				and route["max_ad_content_rating"] == _backend.max_ad_content_rating():
			return AgeBandChange.APPLIED
		_block_age_session()
		return AgeBandChange.NEXT_LAUNCH
	if not _open_age_gate():
		return AgeBandChange.NEXT_LAUNCH
	_compute_banner_slot()
	_maybe_start_consent()
	_preload_rewarded()
	_preload_interstitial()
	rewarded_availability_changed.emit()
	_sync_banner()
	return AgeBandChange.APPLIED


## Kapıyı açar: rota arka uca (SDK yapılandırılmadan ÖNCE), sonra (ilk kez) attach +
## gizlilik API algısı. Bant reklama izin vermiyorsa ya da oturum kapatıldıysa HİÇBİR
## ŞEY yapmaz (false). Rota reddedilirse (SDK başka rotayla yapılandırılmış) oturum kapanır.
func _open_age_gate() -> bool:
	if not _age_ads_allowed():
		return false
	var route: Dictionary = AgeGate.ad_route(_age_band)
	if not _push_age_route(route) or not _backend_matches_route(route):
		_block_age_session()
		return false
	if not _backend_attached:
		_backend.attach(self)
		_backend_attached = true
		_privacy_api = _backend.has_privacy_api()
		if not _privacy_api:
			push_warning("MonetizationManager: arka uç UMP canRequestAds / gizlilik seçenekleri API'sini sunmuyor — M8.9 türetmesi kullanılıyor (tools/admob_plugin)")
	return true


## Rotanın iki değeri (yaş işlemi + en yüksek derece) arka uca. İkisi de kabul edilmezse
## false (SDK başka değerlerle yapılandırılmış — kilit).
func _push_age_route(route: Dictionary) -> bool:
	var treatment_ok: bool = _backend.set_age_restricted_treatment(route["treatment"])
	var rating_ok: bool = _backend.set_max_ad_content_rating(route["max_ad_content_rating"])
	return treatment_ok and rating_ok


## Arka ucun tuttuğu (SDK'ya gidecek) yaş işlemi + derece, rotayla BİREBİR mi. UMP'den ÖNCE
## (kapı açılırken) ve `MobileAds.initialize` ÖNCESİ (`_ensure_sdk`) sorulur; SDK'nın
## uygulanan yapılandırmayı geri okuması (TASK/042) bunun üstüne ayrıca doğrular.
func _backend_matches_route(route: Dictionary) -> bool:
	return bool(route["ads"]) and _backend.age_restricted_treatment() == route["treatment"] \
		and _backend.max_ad_content_rating() == route["max_ad_content_rating"]


## Oturumun geri kalanında reklam YOK (TASK/043): hazır / yüklenen reklamlar gösterilmez
## (`_ads_enabled` false), banner gizlenir, yeniden denemeler durur, açık pencereler
## "kullanılamıyor" der. Gizlilik seçenekleri formu (oyuncunun hakkı) açık kalır; yuva
## sabit kalır (düzen zıplamaz). Geri alınmaz — yeni süreç yeni bantla başlar.
func _block_age_session() -> void:
	if _age_session_blocked:
		return
	_age_session_blocked = true
	_cancel_timer(_consent_retry_timer)
	_consent_retry_timer = null
	_cancel_timer(_rewarded_retry_timer)
	_rewarded_retry_timer = null
	_cancel_timer(_banner_retry_timer)
	_banner_retry_timer = null
	_cancel_timer(_interstitial_retry_timer)
	_interstitial_retry_timer = null
	# Yoldaki (yüklenen) açılış rıza formu artık gösterilmez (`_on_consent_form_loaded`).
	if _form_purpose == FormPurpose.STARTUP:
		_form_purpose = FormPurpose.NONE
	_sync_banner()
	rewarded_availability_changed.emit()


## Onboarding tamamlanmış mı (Main kayıttan verir; M8.10 tutorial bitince
## true yapar). false → reklam yok, yuva yok, saat durur.
func onboarding_completed() -> bool:
	return _onboarding_completed


## Reklam istenebilir mi: izin + SDK + onboarding + yaş kapısı (hepsi birlikte).
func _ads_enabled() -> bool:
	return _backend != null and ads_allowed() and _sdk_ready and _onboarding_completed and _age_ads_allowed()


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


## TASK/043: UMP yalnız kapı açıkken (eklenti kurulu + bant TEEN / ADULT + oturum açık).
## Yeniden denemeler ve talep üzerine tazeleme de bu kapıdan geçer (`_start_consent`).
func _consent_gate_open() -> bool:
	return _backend_attached and _age_ads_allowed()


## Rıza akışı bu yönetici örneğinde hiç başlatıldı mı (testler + teşhis).
func consent_started() -> bool:
	return _consent_kickoff_done


func _start_consent() -> void:
	if not _consent_gate_open():
		return
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
	if not _backend_attached:
		return   # TASK/043: kapı kapalıyken UMP sorulmadı — başıboş sinyal yok sayılır.
	_consent_checked = true
	_resolve_consent(false)


## Güncelleme başarısız: SDK `getConsentStatus()` önceki oturumun değerini
## taşır (UMP belgesi) — o değer izin veriyorsa reklam istenebilir
## (ERROR_WITH_PREVIOUS_STATE), vermiyorsa sınırlı yeniden deneme.
func _on_consent_info_update_failed(_code: int, _message: String) -> void:
	if not _backend_attached:
		return
	_consent_checked = true
	_resolve_consent(true)


## Güncelleme sonucu (başarı ya da hata) → form gerekiyorsa form, yoksa izin
## kararını UMP `canRequestAds()` verir. Hata yolunda form DENENMEZ; SDK'nın
## önceki oturumdan taşıdığı rıza hâlâ izin veriyorsa reklam sürer
## (ERROR_WITH_PREVIOUS_STATE) — geçici bir ağ hatası geçerli rızayı SİLMEZ.
func _resolve_consent(after_error: bool) -> void:
	var status: AdBackend.ConsentStatus = _backend.consent_status()
	_update_privacy_options()
	if not _consent_gate_open():
		# TASK/043: güncelleme yoldayken oturum kapandı (ör. Ayarlar'dan 13 altı) — rıza formu,
		# SDK ve yeniden deneme YOK. Gizlilik seçenekleri satırı yukarıda güncellendi.
		return
	if not after_error and status == AdBackend.ConsentStatus.REQUIRED and _backend.is_consent_form_available():
		# loadAndShowConsentFormIfRequired'ın açık hâli (aynı SDK çağrıları).
		_set_state(AdsState.CONSENT_FORM)
		_form_purpose = FormPurpose.STARTUP
		_backend.load_consent_form()
		return
	if _sdk_can_request_ads():
		_consent_attempts = 0
		_set_state(AdsState.ERROR_WITH_PREVIOUS_STATE if after_error else AdsState.ADS_ALLOWED)
		_ensure_sdk()
	else:
		# Rıza gerekli ama alınmadı / form yok / önceki durum yok: reklam
		# istenmez, sınırlı yeniden deneme.
		_set_state(AdsState.ADS_NOT_ALLOWED)
		_schedule_consent_retry()


## UMP "reklam istenebilir mi": resmî `canRequestAds()` (M9-01). Eklenti
## sunmuyorsa M8.9 eşdeğeri — Google'ın tanımının kendisi: güncelleme
## çağrıldıktan sonra durum NOT_REQUIRED ya da OBTAINED.
func _sdk_can_request_ads() -> bool:
	if _privacy_api:
		return _backend.can_request_ads()
	var status: AdBackend.ConsentStatus = _backend.consent_status()
	return _consent_checked and (status == AdBackend.ConsentStatus.NOT_REQUIRED
		or status == AdBackend.ConsentStatus.OBTAINED)


## Her reklam isteğinden (SDK başlatma / yükleme) HEMEN ÖNCE: UMP hâlâ izin
## veriyor mu? Vermiyorsa istek gitmez; durum bizde "izinli" kalmışsa (kayma)
## izin kalkar — banner gizlenir, ödüllü/geçiş hazır sayılmaz.
func _request_permitted() -> bool:
	if _sdk_can_request_ads():
		return true
	if ads_allowed():
		push_warning("MonetizationManager: UMP canRequestAds() false — reklam isteği durduruldu")
		_set_state(AdsState.ADS_NOT_ALLOWED)
	return false


func _schedule_consent_retry() -> void:
	if _consent_attempts > CONSENT_RETRY_DELAYS.size():
		return
	var delay: float = CONSENT_RETRY_DELAYS[mini(_consent_attempts - 1, CONSENT_RETRY_DELAYS.size() - 1)]
	_cancel_timer(_consent_retry_timer)
	_consent_retry_timer = _start_timer(delay, _on_consent_retry)


func _on_consent_form_loaded() -> void:
	if _form_purpose == FormPurpose.NONE:
		return
	if _form_purpose == FormPurpose.STARTUP and not _consent_gate_open():
		_form_purpose = FormPurpose.NONE   # TASK/043: yükleme sürerken oturum kapandı
		return
	_backend.show_consent_form()


func _on_consent_form_failed_to_load(_code: int, _message: String) -> void:
	var purpose: FormPurpose = _form_purpose
	_form_purpose = FormPurpose.NONE
	if purpose == FormPurpose.STARTUP:
		_set_state(AdsState.ADS_NOT_ALLOWED)
		_schedule_consent_retry()


## Form kapandı (rıza verildi / reddedildi / hata): izni SDK'dan yeniden oku.
func _on_consent_form_dismissed(_code: int, _message: String) -> void:
	_after_form(_form_purpose)


## Gizlilik seçenekleri formu kapandı (M9-01, `showPrivacyOptionsForm`).
func _on_privacy_options_form_dismissed(_code: int, _message: String) -> void:
	if _form_purpose != FormPurpose.PRIVACY_OPTIONS:
		return
	_after_form(FormPurpose.PRIVACY_OPTIONS)


func _after_form(purpose: FormPurpose) -> void:
	_form_purpose = FormPurpose.NONE
	if purpose == FormPurpose.NONE:
		return
	_update_privacy_options()
	if _sdk_can_request_ads():
		_consent_attempts = 0
		_set_state(AdsState.ADS_ALLOWED)
		_ensure_sdk()
	else:
		_set_state(AdsState.ADS_NOT_ALLOWED)
		if purpose == FormPurpose.STARTUP:
			_schedule_consent_retry()


## Gizlilik seçenekleri giriş noktası gerekli mi? M9-01: UMP
## `getPrivacyOptionsRequirementStatus() == REQUIRED` (Google: REQUIRED iken
## görünür bir giriş noktası ZORUNLU, değilse gizli). Eklenti sunmuyorsa M8.9
## eşdeğeri: güncelleme yapıldı VE SDK bir rıza formu sunuyor. Ayrıntı:
## docs/monetization/PRIVACY_CONSENT.md §4.
func _update_privacy_options() -> void:
	var required: bool
	if _privacy_api:
		required = _consent_checked and _backend.privacy_options_status() == AdBackend.PrivacyOptionsStatus.REQUIRED
	else:
		required = _consent_checked and _backend.is_consent_form_available()
	if required != _privacy_options_required:
		_privacy_options_required = required
		privacy_options_changed.emit(required)


func privacy_options_required() -> bool:
	return _privacy_options_required


## Arka uç UMP'nin resmî çağrılarını mı kullanıyor (true) yoksa M8.9
## türetmesine mi düştü (false)? Testler + teşhis + QA sürücüsü.
func uses_privacy_api() -> bool:
	return _privacy_api


## Ayarlar → "Gizlilik seçenekleri": SDK'nın gizlilik seçenekleri formunu
## (`showPrivacyOptionsForm`) açar; kapanınca izin durumu yeniden
## değerlendirilir (reklam durabilir ya da başlayabilir).
func show_privacy_options() -> bool:
	if _backend == null or not _privacy_options_required or _form_purpose != FormPurpose.NONE:
		return false
	_form_purpose = FormPurpose.PRIVACY_OPTIONS
	if _privacy_api:
		_backend.show_privacy_options_form()
	else:
		_backend.load_consent_form()
	return true


## UMP / gizlilik formu uygulamayı kaplıyor mu (aktif süre sayılmaz).
func consent_form_covering() -> bool:
	return _state == AdsState.CONSENT_FORM or _form_purpose != FormPurpose.NONE


# --- SDK ------------------------------------------------------------------------

func _ensure_sdk() -> void:
	if not _consent_gate_open():
		return   # TASK/043: bilinmeyen / 13 altı / oturumu kapatılmış bant -> SDK yok.
	if _sdk_ready or _sdk_initializing:
		_preload_rewarded()
		_preload_interstitial()
		_sync_banner()
		return
	if _sdk_refused:
		return
	# Google: Mobile Ads SDK yalnız canRequestAds() true iken başlatılır.
	if not _request_permitted():
		return
	# TASK/043: SDK'ya gidecek yaş işlemi + derece hâlâ bu bandın rotası mı (fail-closed).
	if not _backend_matches_route(AgeGate.ad_route(_age_band)):
		_block_age_session()
		return
	_sdk_initializing = true
	if not _backend.initialize():
		# TASK/042: istek yapılandırması doğrulanamadı → SDK başlamadı (fail-closed).
		_sdk_initializing = false
		_sdk_refused = true
		push_warning("MonetizationManager: istek yapılandırması doğrulanamadı — bu oturumda reklam yok")
		rewarded_availability_changed.emit()


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
		and _ads_enabled() and _interstitial_state != InterstitialState.SHOWING and not _rewarded_expired())


## CTA pasifken pencerede yazan sebep; hazırken boş.
func rewarded_note() -> String:
	if _backend == null:
		return NOTE_NO_BACKEND
	if not _age_ads_allowed():
		# TASK/043: yaş kapısı kapalı — nötr not (yaşı / sebebi söylemez).
		return NOTE_UNAVAILABLE
	if _state == AdsState.UNAVAILABLE:
		return NOTE_NO_BACKEND
	if not _onboarding_completed or _sdk_refused:
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
			# Süresi dolmuş hazır reklam gösterilmez; tazelenene dek "hazırlanıyor" (TASK/052).
			return NOTE_PREPARING if _rewarded_expired() else ""
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
	if _backend == null or not _onboarding_completed or not _age_ads_allowed():
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
	if _rewarded_state == RewardedState.READY and _rewarded_expired():
		# TASK/052: süresi dolmuş hazır reklam — at, tazele (pencere "hazırlanıyor" der).
		_discard_ready_rewarded()
		_preload_rewarded()
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
	if _rewarded_state == RewardedState.READY and _rewarded_expired():
		# TASK/052: süresi dolmuş reklam gösterilmez (Google: reklamlar bir saatte sona erer) — at, tazele.
		_discard_ready_rewarded()
		_preload_rewarded()
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
	# TASK/052: geri alınamaz gösterim çağrısından HEMEN önce kira (SDK susarsa talep sonsuza dek açık kalmaz).
	_lease_begin(LeaseKind.REWARDED, _request["ad_id"])
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
	if not _request_permitted():
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
	_rewarded_loaded_msec = Time.get_ticks_msec()
	_rewarded_loaded_unix = Time.get_unix_time_from_system()
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


## Hazır ödüllü reklamı at (süresi doldu): eklenti önbelleğinden düşer, kimlik emekli (geç sinyali eskidir).
func _discard_ready_rewarded() -> void:
	if not _ready_ad_id.is_empty():
		_backend.remove_rewarded(_ready_ad_id)
		_retire(_retired_rewarded_ids, _ready_ad_id)
		_ready_ad_id = ""
	if _rewarded_state == RewardedState.READY:
		_rewarded_state = RewardedState.IDLE
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
		_lease_on_showed(LeaseKind.REWARDED, ad_id)
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
	_rewarded_closed(ad_id, "")


## Ödüllü reklamın kapanışı — SDK geri çağrısı (`recovered` boş) ya da tam ekran kirasının "kapandı"
## kurtarması (`recovered` = sebep, TASK/052). Ödül YALNIZ "ödül kazanıldı" geri çağrısında verildi; burada
## ASLA verilmez — kurtarma, kazanılmamış ödülü kazanılmış saymaz.
func _rewarded_closed(ad_id: String, recovered: String) -> void:
	if _request["active"] and _request["ad_id"] != ad_id:
		# Başka bir (eski) reklamın kapanışı; açık talebe dokunulmaz.
		AdEvents.emit(&"rewarded_dismissed", {"placement": "preload", "ad_id": ad_id, "stale": true})
		return
	if not _request["active"] and _retired_rewarded_ids.has(ad_id):
		# TASK/052: kirası kurtarılmış reklamın geç kapanışı — sahiplik için eski, ikinci işlem yok.
		AdEvents.emit(&"rewarded_dismissed", {"placement": "preload", "ad_id": ad_id, "stale": true})
		return
	if _lease_kind == LeaseKind.REWARDED and _lease_ad_id == ad_id:
		_lease_end()
	var ctx: Dictionary = {"placement": "preload", "ad_id": ad_id}
	var was_showing: bool = (_rewarded_state == RewardedState.SHOWING
		or _rewarded_state == RewardedState.REWARD_EARNED)
	if _request["active"]:
		ctx = _request_context()
		ctx["earned"] = _request["earned"]
		if not _request["earned"] and not _request["cancelled"]:
			_notify_unavailable(_request["main"], _request["kind"], NOTE_NOT_EARNED)
		_clear_request()
	# Kapanan reklamın kimliği emekli (SDK ya da kurtarma): yinelenen / geç geri çağrıları eskidir.
	_retire(_retired_rewarded_ids, ad_id)
	if not recovered.is_empty():
		ctx["recovered"] = recovered
		# Kurtarılan kapanışta SDK kapanışı gelmedi: eklenti nesnesi önbellekte kalmasın.
		_backend.remove_rewarded(ad_id)
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
	_rewarded_show_failed(ad_id, code, message, "")


## Ödüllü reklam gösterilemedi — SDK geri çağrısı ya da tam ekran kirasının "gösterilmedi" kurtarması
## (`recovered` = sebep, TASK/052: SDK susarken uygulama hiç örtülmedi). Ödül yok, kota tüketilmez.
func _rewarded_show_failed(ad_id: String, code: int, message: String, recovered: String) -> void:
	if _request["active"] and _request["ad_id"] != ad_id:
		AdEvents.emit(&"rewarded_show_failed", {"placement": "preload", "ad_id": ad_id,
			"code": code, "message": message, "stale": true})
		_backend.remove_rewarded(ad_id)
		return
	if not _request["active"] and _retired_rewarded_ids.has(ad_id):
		# TASK/052: kirası kurtarılmış reklamın geç hatası — önyükleme durumuna dokunulmaz.
		AdEvents.emit(&"rewarded_show_failed", {"placement": "preload", "ad_id": ad_id,
			"code": code, "message": message, "stale": true})
		return
	if _lease_kind == LeaseKind.REWARDED and _lease_ad_id == ad_id:
		_lease_end()
	var ctx: Dictionary = {"placement": "preload", "ad_id": ad_id, "code": code, "message": message}
	if _request["active"]:
		ctx = _request_context()
		ctx["code"] = code
		ctx["message"] = message
		if not _request["cancelled"]:
			_notify_unavailable(_request["main"], _request["kind"], NOTE_SHOW_FAILED)
		_clear_request()
	# Gösterilemeyen reklamın kimliği emekli (SDK ya da kurtarma): yinelenen hata süren önyüklemeyi bozamaz.
	_retire(_retired_rewarded_ids, ad_id)
	if not recovered.is_empty():
		ctx["recovered"] = recovered
	AdEvents.emit(&"rewarded_show_failed", ctx)
	# Gösterilemeyen reklam tüketilmiş sayılır: önbellekten düş, yenisini yükle.
	_backend.remove_rewarded(ad_id)
	if _ready_ad_id == ad_id:
		_ready_ad_id = ""
	_rewarded_state = RewardedState.READY if not _ready_ad_id.is_empty() else RewardedState.FAILED
	rewarded_availability_changed.emit()
	_preload_rewarded()


# --- Geçiş reklamı (interstitial, M8.9-02; sıklık TASK/052 `AdPolicy`) -----------------------
#
# Uygunluk (iki sayaç birlikte): önceki gerçek gösterimden bu yana AdPolicy.FORCED_INTERSTITIAL_
# MIN_ROUNDS kesinleşen NORMAL round (Main bildirir) VE AdPolicy.FORCED_INTERSTITIAL_MIN_INTERVAL_SEC
# aktif ön plan saniyesi. Sayılmayan anlar: arka plan (ekran kapalı dahil — Android uygulamayı
# duraklatır), UMP/gizlilik formu, ödüllü ya da geçiş reklamı ekranda, onboarding tamamlanmamış,
# yaş bandı reklamsız. Oyun içi normal pencereler (mola, ayarlar, devam, refill) SAYILIR.
#
# Gösterim YALNIZ Main'in doğal molasında (`try_show_interstitial`): uygun + READY + bekleme yok +
# başka tam ekran reklam yok + uygulama ön planda. Değilse hiç gösterilmez (sonuç hemen açılır),
# uygunluk korunur, sonraki molada denenir. Sayaç + saat iki yerde sıfırlanır: SDK "gösterildi" (geç gelse de,
# kendi reklamımız için bir kez; gösterim sayılır) ve "gösterildi"si gelmemiş reklamın kapanışı — SDK kapanışı ya da
# örtülme kanıtlı kira kurtarması (gösterim SAYILMAZ; art arda zorunlu geçiş olmasın). Yükleme / gösterim hatası,
# "gösterilmedi" kurtarması sıfırlamaz.

func interstitial_eligible() -> bool:
	return _interstitial_eligible


## Önceki gerçek geçiş reklamından bu yana sayılan kesinleşen normal round (TASK/052).
func interstitial_rounds() -> int:
	return _interstitial_rounds


## Main: normal round KESİN bitti (`_on_round_finished`, round başına tam bir kez). Meydan okuma bu yolu hiç
## çağırmaz — yalıtım Main'in ayrı bitiş işleyicisindedir (suite'ler kaynakla denetler); `false` argümanı kuralı
## yazılı tutar. Sayaç yalnız monetizasyon bu süreçte açıkken artar (`AdPolicy.round_counts`): onboarding tamam
## (tutorial ve tutorial'dan doğan round reklamsız) + yaş bandı reklamlı. Gecikmede round değiştirilse de kesinleşen
## round sayılmış kalır.
func note_normal_round_finalized() -> void:
	if not AdPolicy.round_counts(false, _monetization_active()):
		return
	_interstitial_rounds += 1
	_update_interstitial_eligibility()


## Monetizasyon bu süreçte açık mı (sayaçlar için): arka uç + onboarding + yaş bandı. Rıza / SDK ayrıca
## gösterim anında denetlenir (aktif süre saatiyle aynı kapsam): rıza reddi / SDK beklemesi sayımı DURDURMAZ —
## sonradan reklama izin verilirse ilk doğal mola gösterebilir (2 round + 300 sn bu süreçte yine sağlanmıştır).
func _monetization_active() -> bool:
	return _backend != null and _onboarding_completed and _age_ads_allowed()


## İki sayaç ilk kez sağlandı: "uygun" (olay) + reklam yoksa (hata döngüsü bitmiş) bir yükleme daha.
func _update_interstitial_eligibility() -> void:
	if _interstitial_eligible or not AdPolicy.forced_interstitial_gates_met(_active_elapsed, _interstitial_rounds):
		return
	_interstitial_eligible = true
	AdEvents.emit(&"interstitial_eligible", {"active_elapsed_sec": _active_elapsed, "rounds": _interstitial_rounds})
	_kick_interstitial_load()


## Sıklık sayaçlarını sıfırlar. Çağıranlar: SDK "gösterildi" (geç gelen dahil, kendi reklamımız için bir kez) ve
## "gösterildi"si gelmemiş reklamın kapanışı (`_interstitial_closed` + eski kapanış dalı; gösterim sayılmaz).
func _reset_interstitial_gates() -> void:
	_active_elapsed = 0.0
	_interstitial_rounds = 0
	_interstitial_eligible = false


func active_elapsed_sec() -> float:
	return _active_elapsed


func fullscreen_cooldown_sec() -> float:
	return _fullscreen_cooldown


func is_interstitial_ready() -> bool:
	return (_interstitial_state == InterstitialState.READY and not _interstitial_ready_id.is_empty()
		and _ads_enabled() and not _interstitial_expired())


func _interstitial_expired() -> bool:
	return _ad_expired(_interstitial_loaded_msec, _interstitial_loaded_unix, INTERSTITIAL_MAX_AGE_SEC * time_scale)


## Ödüllü yaş sınırı ölçek DIŞI gerçek saniyedir (testlerin sıkıştırılmış zamanı mevcut ödüllü akışları bozmasın;
## üretimde time_scale 1 — geçişle aynı sınır).
func _rewarded_expired() -> bool:
	return _ad_expired(_rewarded_loaded_msec, _rewarded_loaded_unix, REWARDED_MAX_AGE_SEC)


## Yüklenmiş reklamın yaşı `limit_sec`'i aştı mı (TASK/052). İki saat, hangisi önce aşarsa: motor saati (cihaz derin
## uykudayken DURUR) ve duvar saati (uykuda da ilerler; geri alınmış saat — negatif fark — ve bilinmeyen yükleme anı
## yok sayılır).
func _ad_expired(loaded_msec: int, loaded_unix: float, limit_sec: float) -> bool:
	var limit_msec: int = int(limit_sec * 1000.0)
	if Time.get_ticks_msec() - loaded_msec > limit_msec:
		return true
	if loaded_unix <= 0.0:
		return false
	return (Time.get_unix_time_from_system() - loaded_unix) * 1000.0 > float(limit_msec)


## Aktif süre sayılabilir mi (bkz. üst not).
func _counting_allowed() -> bool:
	return (_backend != null and _onboarding_completed and _age_ads_allowed() and not _app_paused
		and not consent_form_covering() and not fullscreen_ad_active())


## Saat adımı (`_process`; testler doğrudan çağırır). Gerçek saniye — time_scale
## uygulanmaz (aktif süre ölçek dışı; testler saniyeyi kendisi verir).
func _tick_active(delta: float) -> void:
	if delta <= 0.0 or not _counting_allowed():
		return
	_active_elapsed += delta
	if _fullscreen_cooldown > 0.0:
		_fullscreen_cooldown = maxf(0.0, _fullscreen_cooldown - delta)
	_update_interstitial_eligibility()
	_refresh_stale_ads()


## Süresi dolmuş HAZIR reklamları at ve tazele (geçiş + ödüllü; Google: reklamlar bir saatte sona erer) — aktif saat
## adımında, öne dönüşte (uyku sonrası duvar saati), ödüllü pencere / CTA anında.
func _refresh_stale_ads() -> void:
	if _interstitial_state == InterstitialState.READY and _interstitial_expired():
		_discard_ready_interstitial()
		_preload_interstitial()
	if _rewarded_state == RewardedState.READY and _rewarded_expired():
		_discard_ready_rewarded()
		_preload_rewarded()


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
		if _interstitial_eligible:
			# Uygun ama bu mola atlandı (hangi sebeple olursa olsun): reklam yoksa / süresi dolduysa bir sonraki mola
			# için sınırlı yükleme (`_kick_interstitial_load` yalnız boş / hatalı durumda, aralıklı) — TASK/052.
			if reason == "expired":
				_discard_ready_interstitial()
			_kick_interstitial_load()
		return false
	_break_seq += 1
	_break_callback = continue_callback
	_break_name = break_name
	_break_done = false
	_interstitial_showing_id = _interstitial_ready_id
	_interstitial_ready_id = ""
	_set_interstitial_state(InterstitialState.SHOWING)
	rewarded_availability_changed.emit()
	# TASK/052: geri alınamaz gösterim çağrısından HEMEN önce kira (TASK/048 onay zaman aşımının yerini alır:
	# örtülmemiş ön planda FULLSCREEN_UNCOVERED_LEASE_SEC; uygulama duraklatılmışken süre işlemez).
	_lease_begin(LeaseKind.INTERSTITIAL, _interstitial_showing_id)
	_backend.show_interstitial(_interstitial_showing_id)
	return true


## Gösterimi engelleyen sebep; boş = gösterilebilir.
func _interstitial_block_reason() -> String:
	if _backend == null or not _onboarding_completed:
		return "disabled"
	if not _age_ads_allowed():
		return "age_gate"
	if not _interstitial_eligible:
		return "not_eligible"
	if _sdk_refused:
		return "sdk_refused"
	if not ads_allowed() or not _sdk_ready:
		return "consent"
	if consent_form_covering():
		# TASK/052: UMP gizlilik seçenekleri formu açık (Ayarlar'dan) — geçiş reklamı formun üstüne açılmaz.
		return "consent_form"
	if _app_paused:
		# TASK/052: uygulama ön planda değil (başka bir etkinlik örtüyor / arka plan) — oyuncu molada değil.
		return "app_paused"
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
	if not _request_permitted():
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
		_retire(_retired_interstitial_ids, _interstitial_ready_id)
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
		_interstitial_loaded_unix = Time.get_unix_time_from_system()
		return
	if not _interstitial_ready_id.is_empty() and _interstitial_ready_id != ad_id:
		_backend.remove_interstitial(_interstitial_ready_id)
	_interstitial_ready_id = ad_id
	_interstitial_loaded_msec = Time.get_ticks_msec()
	_interstitial_loaded_unix = Time.get_unix_time_from_system()
	_set_interstitial_state(InterstitialState.READY)


func _on_interstitial_failed_to_load(ad_id: String, code: int, message: String) -> void:
	if _retired_interstitial_ids.has(ad_id):
		# TASK/052: emekli kimliğin (gösterilmiş / düşürülmüş reklam) yükleme hatası — eklentinin Java tarafının
		# kapanışta başlattığı sahipsiz yeniden yükleme. Süren önyüklemeye ait DEĞİL: durum / deneme değişmez.
		AdEvents.emit(&"interstitial_load_failed", {"ad_id": ad_id, "code": code, "message": message,
			"stale": true, "active_elapsed_sec": _active_elapsed})
		return
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
		# Kendi reklamımız, mola "gösterilmedi" kurtarmasıyla bittikten SONRA gerçekten açıldıysa (SDK sözleşme
		# dışı gecikme) bu da gerçek gösterim: sayaçlar sıfırlanır, gösterim BİR kez sayılır (TASK/052).
		var late: bool = not ad_id.is_empty() and ad_id == _interstitial_showing_id and ad_id != _interstitial_showed_id
		AdEvents.emit(&"interstitial_showed", {"ad_id": ad_id, "stale": true, "late": late,
			"active_elapsed_sec": _active_elapsed})
		if late:
			_interstitial_shows += 1
			_interstitial_showed_id = ad_id
			_reset_interstitial_gates()
		return
	if ad_id == _interstitial_showed_id:
		# Aynı gösterimin yinelenen "gösterildi"si: ikinci sayım / sıfırlama yok.
		AdEvents.emit(&"interstitial_showed", {"ad_id": ad_id, "stale": true, "active_elapsed_sec": _active_elapsed})
		return
	_interstitial_shows += 1
	_interstitial_showed_id = ad_id
	AdEvents.emit(&"interstitial_showed", {"ad_id": ad_id, "natural_break": _break_name,
		"active_elapsed_sec": _active_elapsed, "rounds": _interstitial_rounds})
	# Gerçek tam ekran gösterim başladı: sayaç + saat şimdi sıfırlanır (gösterim sayıldı).
	_reset_interstitial_gates()
	_lease_on_showed(LeaseKind.INTERSTITIAL, ad_id)


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
			# Mola "gösterilmedi" kurtarmasıyla (eski adıyla onay zaman aşımı) bittikten SONRA kapanan gerçek
			# gösterim: yalnız bekleme; kimlik emekli (eklentinin sahipsiz yeniden yüklemesi elenir).
			_interstitial_showing_id = ""
			_retire(_retired_interstitial_ids, ad_id)
			if ad_id != _interstitial_showed_id:
				# "gösterildi" de kaybolduysa kapanış gösterimin kanıtı: sayaçlar sıfırlanır, gösterim sayılmaz.
				_reset_interstitial_gates()
			_start_fullscreen_cooldown()
		return
	_interstitial_closed(ad_id, "")


## Geçiş reklamının kapanışı — SDK geri çağrısı (`recovered` boş) ya da tam ekran kirasının "kapandı"
## kurtarması (`recovered` = sebep, TASK/052). Mola tam bir kez biter (`_finish_break`), 60 sn bekleme başlar,
## sıradaki reklam yüklenir. Kurtarmadan sonra gelen geç kapanış eski sayılır (kimlik emekli, ikinci işlem yok).
## "gösterildi"si gelmemiş reklamın kapanışı da gösterimin kanıtıdır: sıklık sayaçları sıfırlanır (gösterim
## SAYILMAZ) — SDK kapanışı ile örtülme kanıtlı kurtarma için TEK kural.
func _interstitial_closed(ad_id: String, recovered: String) -> void:
	_lease_end()
	if ad_id != _interstitial_showed_id:
		_reset_interstitial_gates()
	var ctx: Dictionary = {"ad_id": ad_id, "natural_break": _break_name, "active_elapsed_sec": _active_elapsed}
	if not recovered.is_empty():
		ctx["recovered"] = recovered
	AdEvents.emit(&"interstitial_dismissed", ctx)
	_interstitial_showing_id = ""
	_retire(_retired_interstitial_ids, ad_id)
	if not recovered.is_empty():
		# Kurtarılan kapanışta SDK kapanışı gelmedi: eklenti nesnesi önbellekte kalmasın.
		_backend.remove_interstitial(ad_id)
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
	_lease_end()
	_interstitial_showing_id = ""
	_retire(_retired_interstitial_ids, ad_id)
	# Saat sıfırlanmaz, uygunluk kalır (gerçek gösterim olmadı).
	_set_interstitial_state(InterstitialState.READY if not _interstitial_ready_id.is_empty()
		else InterstitialState.FAILED)
	rewarded_availability_changed.emit()
	_finish_break()
	_preload_interstitial()


## Tam ekran kirasının "gösterilmedi" kurtarması (TASK/052; TASK/048'in onay zaman aşımı): gösterim çağrısından
## sonra SDK ne "gösterildi" ne hata dedi ve uygulama hiç örtülmedi — reklam açılmadı sayılır. Mola beklemez (sonuç
## açılır), bekleme yok, sayaç / saat sıfırlanmaz (gerçek gösterim olmadı). Reklam eklenti önbelleğinde kalır: geç de
## olsa gösterilirse geç "gösterildi" sayaçları sıfırlar, kapanışı yalnız beklemeyi başlatır; gösterilmezse önbellek
## tavanı eskiyi atar.
func _interstitial_not_shown(ad_id: String, recovered: String) -> void:
	_lease_end()
	AdEvents.emit(&"interstitial_show_failed", {"ad_id": ad_id, "code": -1, "message": "show confirm timeout",
		"natural_break": _break_name, "recovered": recovered, "active_elapsed_sec": _active_elapsed})
	_set_interstitial_state(InterstitialState.READY if not _interstitial_ready_id.is_empty()
		else InterstitialState.FAILED)
	rewarded_availability_changed.emit()
	_finish_break()
	_preload_interstitial()


func _set_interstitial_state(state: InterstitialState) -> void:
	if state == _interstitial_state:
		return
	_interstitial_state = state
	interstitial_state_changed.emit(state)


# --- Tam ekran kirası (TASK/052) -----------------------------------------------------------------------
#
# Uygulamanın KENDİ engelleyici durumu (geçiş molası / ödüllü talep) gösterim çağrısıyla başlar; SDK'nın kapanış /
# gösterim hatası geri çağrısıyla biter (belirleyici). SDK susarsa kira YALNIZ uygulamanın örtülmediğine dair kanıtla
# kurtarılır — kira başına tek zamanlayıcı, kira jetonuna bağlı, tam bir kez:
#   - APPLICATION_RESUMED geldi                              -> SHOW_RESUME_GRACE (3 sn; M8.9-01'den beri aynı pay)
#   - gösterim isteğinden beri hiç PAUSED yok ("gösterildi" öncesi) -> FULLSCREEN_UNCOVERED_LEASE_SEC (5 sn; TASK/048)
#   - geçiş: SDK "gösterildi" dedi, hiç PAUSED yok          -> "gösterildi"den 5 sn (sonuç reklamın altında açılabilir;
#     ödül yok — ucuz yanlış tahmin)
#   - ödüllü: SDK "gösterildi" dedi, hiç PAUSED yok          -> SÜREYE BAĞLI BIRAKMA YOK; yalnız "gösterildi"den >= 5 sn
#     sonra uygulamaya ulaşan YENİ dokunuş (reklam üstteyse dokunuş ona gider) -> 5 sn
#   - PAUSED geldi, RESUMED gelmedi, ama PAUSED'dan >= 5 sn sonra uygulamaya YENİ dokunuş ulaştı -> 5 sn (ve
#     `_app_paused` düşer — uygulama düzeyinde öne dönüş)
#   - Android'de onPause'un FOCUS_OUT'u ile onResume'un FOCUS_IN'i arasındaki RESUMED (Vulkan: onStart'ta, üstte reklam
#     varken de) öne dönüş SAYILMAZ — pay FOCUS_IN'le başlar
#   - uygulama duraklatılmışken (reklam üstte ya da arka plan) SÜREYE BAĞLI BIRAKMA YOK
# Örtülme kanıtı yalnız gösterim çağrısından SONRAKİ PAUSED'dır (önceden duraklatılmış uygulama sayılmaz).
# Sonuç kanıta göre: SDK "gösterildi" dedi, uygulama örtüldü ya da (ödüllü) "ödül kazanıldı" geldi -> "kapandı"
# (kapanış anlamı: 60 sn bekleme; geçişte "gösterildi" yoksa sıklık sayaçları `_interstitial_closed`'da sıfırlanır —
# gösterim SAYILMAZ; ödüllüde ödül YALNIZ zaten kazanıldıysa, o an verilmişti; eklenti nesnesi önbellekten düşer);
# hiçbiri -> "gösterilmedi" (gösterim hatası anlamı: bekleme yok, uygunluk kalır, ödül yok). SDK'nın tam ekran
# reklamı uygulama tarafından KAPATILMAZ; sahte kapatma düğmesi, sahte ödül, sayılmamış gösterim YOK. Kurtarmadan
# sonra gelen geç geri çağrılar sahiplik için eskidir (kimlikler emekli).

func _lease_begin(kind: LeaseKind, ad_id: String) -> void:
	_lease_token += 1
	_lease_kind = kind
	_lease_ad_id = ad_id
	_lease_showed = false
	# Yalnız gösterim çağrısından SONRAKİ PAUSED örtülme kanıtıdır: zaten duraklatılmış uygulamada (etkinlik geçişi /
	# çoklu pencere) önceki duraklatma "reklamımız örttü" sayılmaz. Duraklatılmışken zamanlayıcı kurulmaz.
	_lease_covered_seen = false
	_lease_resumed_seen = false
	_lease_showed_msec = -1
	_lease_input_uncovered = false
	_lease_arm(FULLSCREEN_UNCOVERED_LEASE_SEC)


func _lease_end() -> void:
	_cancel_timer(_lease_timer)
	_lease_timer = null
	_lease_kind = LeaseKind.NONE
	_lease_ad_id = ""
	_lease_input_uncovered = false


## Uygulama örtülmemiş mi: duraklatılmamış ya da (RESUMED kaybolmuşken) girdi kanıtı var.
func _lease_uncovered() -> bool:
	return not _app_paused or _lease_input_uncovered


## Kiranın tek zamanlayıcısını (yeniden) kurar — yalnız uygulama örtülmemişken; önceki zamanlayıcı düşer.
func _lease_arm(seconds: float) -> void:
	_cancel_timer(_lease_timer)
	_lease_timer = null
	if _lease_kind == LeaseKind.NONE or not _lease_uncovered():
		return
	_lease_timer = _start_timer(seconds, _on_lease_timeout.bind(_lease_token))


## SDK "gösterildi". Hiç örtülmemiş GEÇİŞ kirasında örtülmemiş sınır bu andan yeniden sayılır (gerçek reklam şimdi
## uygulamayı duraklatmalı; PAUSED gelince sayım durur). Hiç örtülmemiş ÖDÜLLÜ kirada süreye bağlı bırakma kalkar:
## reklam gerçekten ekrandaysa (etkinliği duraklatmayan bir gösterim yolu dahil) hak edilen ödül kesilmesin — kira
## yalnız "gösterildi"den sonraki girdi kanıtıyla (`_input`) ya da duraklatma + öne dönüş payıyla biter.
func _lease_on_showed(kind: LeaseKind, ad_id: String) -> void:
	if _lease_kind != kind or _lease_ad_id != ad_id or _lease_showed:
		# Başka kiranın ya da aynı gösterimin yinelenen "gösterildi"si: kabul edilmiş girdi kanıtı / zamanlayıcı bozulmaz.
		return
	_lease_showed = true
	_lease_showed_msec = Time.get_ticks_msec()
	if _lease_covered_seen or _app_paused:
		return
	if kind == LeaseKind.REWARDED:
		_lease_input_uncovered = false
		_cancel_timer(_lease_timer)
		_lease_timer = null
		return
	_lease_arm(FULLSCREEN_UNCOVERED_LEASE_SEC)


func _lease_on_paused() -> void:
	if _lease_kind == LeaseKind.NONE:
		return
	_lease_covered_seen = true
	_lease_input_uncovered = false
	_cancel_timer(_lease_timer)
	_lease_timer = null


func _lease_on_resumed() -> void:
	if _lease_kind == LeaseKind.NONE:
		return
	_lease_resumed_seen = true
	_lease_input_uncovered = false
	_lease_arm(SHOW_RESUME_GRACE)


func _on_lease_timeout(token: int) -> void:
	_lease_timer = null
	if token != _lease_token or _lease_kind == LeaseKind.NONE or not _lease_uncovered():
		return
	_recover_lease()


## Kira kurtarması — tam bir kez (jeton + `_lease_end`; SDK geri çağrısı önce geldiyse kira zaten bitmiştir).
func _recover_lease() -> void:
	var kind: LeaseKind = _lease_kind
	var ad_id: String = _lease_ad_id
	# Ödüllüde "ödül kazanıldı" geldiyse reklam gösterilmiştir (ödül o an verildi): "gösterilemedi" sayılmaz.
	var earned: bool = (kind == LeaseKind.REWARDED and _request["active"] and _request["ad_id"] == ad_id
		and bool(_request["earned"]))
	var closed: bool = _lease_showed or _lease_covered_seen or earned
	var reason: String = RECOVERY_UNCOVERED_LEASE
	if _lease_input_uncovered:
		reason = RECOVERY_INPUT_EVIDENCE
	elif _lease_resumed_seen:
		reason = RECOVERY_RESUME_GRACE
	_lease_recoveries += 1
	match kind:
		LeaseKind.INTERSTITIAL:
			if not closed:
				_interstitial_not_shown(ad_id, reason)
				return
			# "gösterildi" kaybolduysa (yalnız örtülme kanıtı) sayaçları `_interstitial_closed` sıfırlar — gösterim
			# SAYILMAZ; art arda zorunlu reklam olmaz (SDK kapanışıyla aynı tek kural).
			_interstitial_closed(ad_id, reason)
		LeaseKind.REWARDED:
			if closed:
				_rewarded_closed(ad_id, reason)
			else:
				_rewarded_show_failed(ad_id, -1, "show confirm timeout", reason)


## Kimliği emekli listeye ekler (en son RETIRED_ID_MEMORY tane).
func _retire(list: Array[String], ad_id: String) -> void:
	if ad_id.is_empty() or list.has(ad_id):
		return
	list.append(ad_id)
	while list.size() > RETIRED_ID_MEMORY:
		list.pop_front()


## Tam ekran kirası açık mı (geçiş molası ya da ödüllü talep SDK'ya verildi, sonuç henüz yok).
func lease_active() -> bool:
	return _lease_kind != LeaseKind.NONE


func lease_kind() -> LeaseKind:
	return _lease_kind


## Bu süreçte kurtarılan kira sayısı (teşhis; SDK kapanışı gelmeden biten tam ekran molaları).
func fullscreen_recoveries() -> int:
	return _lease_recoveries


## RESUMED kaybolmuşken uygulamaya ulaşan dokunuşla öne dönüş sayılan kez (teşhis).
func input_resumes() -> int:
	return _input_resumes


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
	# TASK/043: yuva yalnız eklenti kurulu ve bant reklamlıyken; oturum sonradan kapatılırsa
	# (NEXT_LAUNCH) yuva SABİT kalır — düzen zıplamaz, boş yuvada zemin görünür.
	var slot_open: bool = _onboarding_completed and _backend_attached and bool(AgeGate.ad_route(_age_band)["ads"])
	var height_dp: int = _backend.adaptive_banner_height_dp() if slot_open else 0
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
	if not _request_permitted():
		return
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
	return "age=%s attached=%s age_blocked=%s ads=%s papi=%s priv=%s sdk=%s onb=%s rewarded=%s ready=%s inter=%s elig=%s active=%.0f rounds=%d cool=%.0f banner=%s surface=%s slot=%d req=%s lease=%s recov=%d inres=%d" % [
		AgeGate.band_name(_age_band), str(_backend_attached), str(_age_session_blocked),
		AdsState.keys()[_state], str(_privacy_api), str(_privacy_options_required), str(_sdk_ready), str(_onboarding_completed),
		RewardedState.keys()[_rewarded_state], str(is_rewarded_ready()),
		InterstitialState.keys()[_interstitial_state], str(_interstitial_eligible), _active_elapsed, _interstitial_rounds,
		_fullscreen_cooldown, BannerState.keys()[_banner_state], Surface.keys()[_surface],
		int(_banner_slot_px), str(_request["active"]), LeaseKind.keys()[_lease_kind], _lease_recoveries, _input_resumes]


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
