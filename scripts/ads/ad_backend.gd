class_name AdBackend
extends RefCounted
## SDK'ya bakan reklam arka ucu — soyut arayüz (M8.9-01).
##
## MonetizationManager YALNIZ bu arayüzü bilir; eklenti/SDK ayrıntıları
## (`Admob` düğümü, AdInfo/AdError modelleri, ad_id önbelleği) `AdmobBackend`
## içinde kalır. Testler `tools/fake_ad_backend.gd` ile aynı arayüzü
## deterministik olarak sürer — internet, cihaz ve eklenti gerekmez.
##
## Sözleşme:
##   - Bütün sinyaller ana (oyun) iş parçacığında, kare sınırında gelir.
##   - `ad_id` bir yükleme isteğinin kimliğidir; sonraki show/earned/dismissed
##     sinyalleri aynı kimliği taşır (stale/yanlış istek ayrımı için).
##   - Rıza durumu SDK'nın kendi durumudur; burada önbellek tutulmaz.

enum ConsentStatus { UNKNOWN, NOT_REQUIRED, REQUIRED, OBTAINED }
## UMP `getPrivacyOptionsRequirementStatus()` (M9-01).
enum PrivacyOptionsStatus { UNKNOWN, NOT_REQUIRED, REQUIRED }
## İstek yapılandırmasının yaş işlemi (TFAT, TASK/042): GMA 25.3.0
## `RequestConfiguration.Builder.setAgeRestrictedTreatment()`. Adlar SDK'nın
## enum adlarıyla aynı (geri okumada "UNSPECIFIED" / "CHILD" / "TEEN").
## UNSPECIFIED = yaş işlemi belirtilmedi (SDK varsayılanı). TEEN / UNSPECIFIED'ı kimin
## alacağı (yaş bandı yönlendirmesi, TASK/043) bu arayüzün işi DEĞİL: MonetizationManager
## AgeGate.ad_route()'a göre SDK yapılandırılmadan ÖNCE bir kez verir. CHILD hiçbir bant
## için kullanılmaz (13 yaş altı = reklam SDK'sı hiç başlamaz).
enum AgeRestrictedTreatment { UNSPECIFIED, CHILD, TEEN }

signal initialization_completed
signal consent_info_updated
signal consent_info_update_failed(code: int, message: String)
signal consent_form_loaded
signal consent_form_failed_to_load(code: int, message: String)
## code 0 = hata yok (form normal kapandı).
signal consent_form_dismissed(code: int, message: String)
## UMP gizlilik seçenekleri formu kapandı (M9-01); code 0 = hata yok.
signal privacy_options_form_dismissed(code: int, message: String)

signal rewarded_loaded(ad_id: String)
signal rewarded_failed_to_load(ad_id: String, code: int, message: String)
signal rewarded_showed(ad_id: String)
signal rewarded_failed_to_show(ad_id: String, code: int, message: String)
signal rewarded_impression(ad_id: String)
signal rewarded_clicked(ad_id: String)
signal rewarded_earned(ad_id: String, reward_type: String, amount: int)
signal rewarded_dismissed(ad_id: String)

## Geçiş (interstitial) reklamı (M8.9-02) — ödüllüyle aynı kimlik sözleşmesi;
## ödül yok.
signal interstitial_loaded(ad_id: String)
signal interstitial_failed_to_load(ad_id: String, code: int, message: String)
signal interstitial_showed(ad_id: String)
signal interstitial_failed_to_show(ad_id: String, code: int, message: String)
signal interstitial_impression(ad_id: String)
signal interstitial_clicked(ad_id: String)
signal interstitial_dismissed(ad_id: String)

signal banner_loaded(ad_id: String, width_dp: int, height_dp: int, refreshed: bool)
signal banner_failed_to_load(ad_id: String, code: int, message: String)
signal banner_impression(ad_id: String)
signal banner_clicked(ad_id: String)


func backend_name() -> String:
	return "abstract"


## Arka uç sahne ağacına bağlanır (`host` = MonetizationManager). Eklenti
## düğümü burada yaratılır; testte no-op. TASK/043: yönetici bunu yalnız yaş bandı
## reklama izin verince (TEEN / ADULT) ve rotayı (yaş işlemi + derece) verdikten SONRA
## çağırır — UNKNOWN / UNDER_13'te eklenti düğümü hiç kurulmaz.
func attach(_host: Node) -> void:
	pass


## Mobile Ads SDK'yı başlatır (tam bir kez, yalnız UMP izin verince çağrılır).
## TASK/042 sözleşmesi (Google'ın sırası): istek yapılandırması (içerik derecesi,
## TFCD / TFUA, yaş işlemi) SDK başlamadan ÖNCE uygulanır ve SDK'dan geri okunarak
## doğrulanır. true = SDK başlatılıyor (`initialization_completed` gelecek); false =
## doğrulanamadı, SDK BAŞLATILMADI (fail-closed: bu oturumda reklam yok, yeniden deneme yok).
func initialize() -> bool:
	return false


## SDK'ya gidecek yaş işlemi (TASK/042). Varsayılan UNSPECIFIED. Yalnız SDK
## yapılandırılmadan (`initialize()`) ÖNCE değiştirilebilir: sonra farklı bir değer
## REDDEDİLİR (false, loglanır) — doğrulanmış yapılandırma geçerli kalır, uygulanmamış
## bir işlem sessizce "uygulandı" sayılamaz. true = kabul (aynı değer de true).
func set_age_restricted_treatment(_value: AgeRestrictedTreatment) -> bool:
	return false


func age_restricted_treatment() -> AgeRestrictedTreatment:
	return AgeRestrictedTreatment.UNSPECIFIED


## SDK'ya gidecek en yüksek reklam içeriği derecesi ("G" / "PG" / "T" / "MA"; TASK/043:
## yaş bandından — TEEN "T", ADULT "MA"). Yaş işlemiyle AYNI kilit: yalnız SDK
## yapılandırılmadan ÖNCE değiştirilebilir, sonra farklı değer REDDEDİLİR (false).
func set_max_ad_content_rating(_value: String) -> bool:
	return false


func max_ad_content_rating() -> String:
	return "G"


## İstek yapılandırması bu süreçte SDK'ya en az bir kez uygulandı mı (`initialize()`
## başı). true iken yaş işlemi / derece kilitli (TASK/042 / TASK/043).
func request_configured() -> bool:
	return false


## SDK'nın ŞU ANKİ istek yapılandırması (native geri okuma, TASK/042):
## age_restricted_treatment, max_ad_content_rating, tag_for_child_directed_treatment,
## tag_for_under_age_of_consent, personalization_state, test_device_ids (yalnız
## SAYI), sdk_version, initialized. Boş = bilinmiyor.
func applied_request_configuration() -> Dictionary:
	return {}


## Beklenen geri okuma değerleri (TASK/042 doğrulaması): yaş işlemi adı, derece,
## TFCD / TFUA (SDK tamsayısı: -1 belirtilmedi, 0 false, 1 true).
static func expected_request_configuration(treatment: AgeRestrictedTreatment, max_ad_content_rating: String,
		tag_for_child_directed_treatment: int, tag_for_under_age_of_consent: int) -> Dictionary:
	return {
		"age_restricted_treatment": String(AgeRestrictedTreatment.keys()[treatment]),
		"max_ad_content_rating": max_ad_content_rating,
		"tag_for_child_directed_treatment": tag_for_child_directed_treatment,
		"tag_for_under_age_of_consent": tag_for_under_age_of_consent,
	}


## SDK geri okumasını beklenenle karşılaştırır; "" = uyuşuyor, değilse okunabilir
## fark listesi. Geri okuma yoksa (eski eklenti) de uyuşmazlık sayılır — fail-closed.
static func request_configuration_problem(applied: Dictionary, expected: Dictionary) -> String:
	if applied.is_empty():
		return "SDK geri okuması yok (eklenti get_applied_request_configuration() sunmuyor)"
	var problems: PackedStringArray = PackedStringArray()
	for key: String in expected:
		if not applied.has(key) or str(applied[key]) != str(expected[key]):
			problems.append("%s=%s (beklenen %s)" % [key, str(applied.get(key, "<yok>")), str(expected[key])])
	return ", ".join(problems)


func request_consent_update() -> void:
	pass


func consent_status() -> ConsentStatus:
	return ConsentStatus.UNKNOWN


func is_consent_form_available() -> bool:
	return false


func load_consent_form() -> void:
	pass


func show_consent_form() -> void:
	pass


## UMP'nin resmî üç çağrısı sunuluyor mu (M9-01, yamalı eklenti)? false →
## yönetici M8.9'un SDK'dan türettiği eşdeğerlere düşer ve bunu loglar.
func has_privacy_api() -> bool:
	return false


## UMP `ConsentInformation.canRequestAds()`.
func can_request_ads() -> bool:
	return false


## UMP `ConsentInformation.getPrivacyOptionsRequirementStatus()`.
func privacy_options_status() -> PrivacyOptionsStatus:
	return PrivacyOptionsStatus.UNKNOWN


## UMP `UserMessagingPlatform.showPrivacyOptionsForm()` → kapanınca
## `privacy_options_form_dismissed`.
func show_privacy_options_form() -> void:
	pass


func load_rewarded() -> void:
	pass


func show_rewarded(_ad_id: String) -> void:
	pass


func remove_rewarded(_ad_id: String) -> void:
	pass


func load_interstitial() -> void:
	pass


func show_interstitial(_ad_id: String) -> void:
	pass


func remove_interstitial(_ad_id: String) -> void:
	pass


func load_banner() -> void:
	pass


func show_banner(_ad_id: String) -> void:
	pass


func hide_banner(_ad_id: String) -> void:
	pass


func remove_banner(_ad_id: String) -> void:
	pass


## Portre sabit uyarlanabilir banner yüksekliği (dp). 0 = bilinmiyor.
## Yükleme gerektirmez; SDK genişlikten hesaplar.
func adaptive_banner_height_dp() -> int:
	return 0


## Cihaz piksel / dp.
func density() -> float:
	return 1.0
