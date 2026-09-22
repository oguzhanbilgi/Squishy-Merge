class_name AdConfig
extends RefCounted
## AdMob kimlik yapılandırması (M8.9-01). TEK kaynak:
## `res://addons/AdmobPlugin/android_export.cfg` — aynı dosyayı export
## eklentisi de okur (uygulama kimliğini AndroidManifest'e yazar), böylece
## manifest'teki app id ile çalışma zamanındaki reklam birimi kimlikleri
## aynı anahtardan (is_real) seçilir. Birimler: rewarded, banner ve
## interstitial (M8.9-02).
##
## TEST YAPILANDIRMASI (bu milestone): is_real=false, Google'ın resmi
## örnek kimlikleri. Canlı reklam istenmez.
##
## ÜRETİM (sonraki release/config adımı, owner): dosyada is_real=true +
## [Release] anahtarları. is_real=true iken bir kimlik boşsa `is_valid()`
## false döner ve MonetizationManager reklamı HİÇ başlatmaz — gerçek
## build'de sessizce test kimliğine düşülmez.

const CONFIG_PATH: String = "res://addons/AdmobPlugin/android_export.cfg"

## Google'ın resmi örnek kimlikleri (developers.google.com/admob/android/
## test-ads, 2026-09-21). Dosya okunamazsa güvenli varsayılan bunlardır.
const TEST_APP_ID: String = "ca-app-pub-3940256099942544~3347511713"
const TEST_REWARDED_ID: String = "ca-app-pub-3940256099942544/5224354917"
const TEST_BANNER_ID: String = "ca-app-pub-3940256099942544/9214589741"
## Google'ın resmi Android geçiş (interstitial) reklamı test birimi
## (developers.google.com/admob/android/interstitial, 2026-09-22) — M8.9-02.
const TEST_INTERSTITIAL_ID: String = "ca-app-pub-3940256099942544/1033173712"

## UMP debug coğrafyası (yalnız is_real=false iken uygulanır):
## "" / "disabled" / "eea" / "regulated_us_state" / "other".
const DEBUG_GEOGRAPHY_VALUES: Array[String] = ["", "disabled", "eea", "regulated_us_state", "other"]

var is_real: bool = false
var app_id: String = TEST_APP_ID
var rewarded_id: String = TEST_REWARDED_ID
var banner_id: String = TEST_BANNER_ID
var interstitial_id: String = TEST_INTERSTITIAL_ID
var debug_geography: String = ""
var source: String = "defaults"
var error: String = ""


static func load_project() -> AdConfig:
	var config := AdConfig.new()
	config._load(CONFIG_PATH)
	return config


## Test varsayılanları (masaüstü/headless testler için).
static func test_defaults() -> AdConfig:
	return AdConfig.new()


func _load(path: String) -> void:
	if not FileAccess.file_exists(path):
		source = "defaults (dosya yok)"
		# Export edilmiş build'de dosya paketlenmemişse (addons/squishy_ads_export
		# eklentisi devre dışı?) KAPALI kal: manifest'teki uygulama kimliği ile
		# çalışma zamanı kimlikleri ayrışabilir; test varsayılanına düşülmez.
		if OS.has_feature("template"):
			error = "android_export.cfg export paketinde yok"
		return
	var file := ConfigFile.new()
	var err: Error = file.load(path)
	if err != OK:
		error = "android_export.cfg okunamadı (%d)" % err
		source = "defaults (okuma hatası)"
		return
	source = path
	is_real = bool(file.get_value("General", "is_real", false))
	var section: String = "Release" if is_real else "Debug"
	app_id = String(file.get_value(section, "app_id", "" if is_real else TEST_APP_ID))
	rewarded_id = String(file.get_value(section, "rewarded_id", "" if is_real else TEST_REWARDED_ID))
	banner_id = String(file.get_value(section, "banner_id", "" if is_real else TEST_BANNER_ID))
	interstitial_id = String(file.get_value(section, "interstitial_id", "" if is_real else TEST_INTERSTITIAL_ID))
	debug_geography = String(file.get_value("Debug", "debug_geography", "")).to_lower()
	if not DEBUG_GEOGRAPHY_VALUES.has(debug_geography):
		error = "geçersiz debug_geography '%s'" % debug_geography
		debug_geography = ""
	if is_real:
		if app_id.is_empty() or rewarded_id.is_empty() or banner_id.is_empty() \
				or interstitial_id.is_empty():
			error = "is_real=true ama [Release] kimlikleri eksik"
		elif app_id.begins_with("ca-app-pub-3940256099942544") \
				or rewarded_id.begins_with("ca-app-pub-3940256099942544") \
				or banner_id.begins_with("ca-app-pub-3940256099942544") \
				or interstitial_id.begins_with("ca-app-pub-3940256099942544"):
			error = "is_real=true ama [Release] altında Google örnek kimliği var"


## Reklam başlatılabilir mi? Test modunda her zaman; gerçek modda yalnız
## bütün üretim kimlikleri doluysa.
func is_valid() -> bool:
	return error.is_empty()


func describe() -> String:
	return "AdConfig(is_real=%s, app_id=%s, rewarded=%s, banner=%s, interstitial=%s, geo=%s, source=%s%s)" % [
		str(is_real), app_id, rewarded_id, banner_id, interstitial_id,
		debug_geography if not debug_geography.is_empty() else "-", source,
		"" if error.is_empty() else ", HATA: " + error]
