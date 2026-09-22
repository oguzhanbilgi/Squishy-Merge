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

signal initialization_completed
signal consent_info_updated
signal consent_info_update_failed(code: int, message: String)
signal consent_form_loaded
signal consent_form_failed_to_load(code: int, message: String)
## code 0 = hata yok (form normal kapandı).
signal consent_form_dismissed(code: int, message: String)

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
## düğümü burada yaratılır; testte no-op.
func attach(_host: Node) -> void:
	pass


func initialize() -> void:
	pass


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
