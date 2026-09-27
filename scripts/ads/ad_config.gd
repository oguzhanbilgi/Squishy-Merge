class_name AdConfig
extends RefCounted
## AdMob yapılandırması (M8.9-01 → M9-01). TEK kaynak:
## `res://addons/AdmobPlugin/android_export.cfg` — aynı dosyayı eklentinin
## export kancası da okur (uygulama kimliğini AndroidManifest'e yazar).
## Birimler: rewarded, banner ve interstitial (M8.9-02).
##
## M9-01 — KİMLİKLERİ BUILD TÜRÜ SEÇER, elle çevrilen bayrak değil:
##   DEBUG build (`OS.is_debug_build()`: editör, headless testler, debug APK):
##     YALNIZ [Debug] altındaki Google resmî örnek kimlikleri. Orada gerçek bir
##     kimlik görülürse yapılandırma GEÇERSİZ → reklam hiç başlamaz. Debug/QA
##     build'i böylece hiçbir koşulda canlı reklam birimi isteyemez.
##   RELEASE build: YALNIZ [Release] altındaki dört gerçek kimlik ve
##     `[General] is_real=true` (owner'ın "üretim kimlikleri dolu ve onaylı"
##     beyanı). Biri boş, biçimsiz, Google örneği, farklı yayıncıdan ya da
##     tekrar ediyorsa GEÇERSİZ → reklam hiç başlamaz (sessiz test kimliğine
##     düşüş yok). Debug coğrafyası release'te HER ZAMAN kapalı.
## Aynı kurallar export anında (addons/squishy_release) ve testlerde
## (tools/release_config_test) çalışır — tek doğrulayıcı `problems()`.
##
## [Audience] (M9-01): ürün kitlesi kararı + eski TFCD / TFUA etiketleri (unspecified —
## gönderilmez). TASK/043: en yüksek reklam derecesi ARTIK BURADA DEĞİL — yaş bandından
## gelir (AgeGate.ad_route: TEEN "T", ADULT "MA"); dosyada eski `max_ad_content_rating`
## anahtarı kalırsa yapılandırma GEÇERSİZ olur (sessizce yok sayılan, yanıltıcı bir ayar
## olmasın). Owner kayıtları (üçünü de YALNIZ release kapısı okur; çalışma zamanı davranışını
## DEĞİŞTİRMEZLER — docs/monetization/AUDIENCE_DECISION.md, AGE_BAND_ROUTING.md):
##   `teen_ad_treatment`       13–17 genç reklam işlemi stratejisi ("" / "age_band_routing")
##   `app_content_rating`      uygulamanın Play içerik derecesi ("" / 3+ / 7+ / 12+ / 16+ / 18+)
##   `jurisdiction_age_review` yargı bölgesi yaş yükümlülükleri değerlendirmesi ("" / "recorded")

const CONFIG_PATH: String = "res://addons/AdmobPlugin/android_export.cfg"

## Google'ın resmî örnek yayıncısı (developers.google.com/admob/android/test-ads).
const TEST_PUBLISHER: String = "ca-app-pub-3940256099942544"
## Google'ın resmi örnek kimlikleri (developers.google.com/admob/android/
## test-ads, 2026-09-21). Dosya okunamazsa DEBUG build'in varsayılanı bunlardır.
const TEST_APP_ID: String = "ca-app-pub-3940256099942544~3347511713"
const TEST_REWARDED_ID: String = "ca-app-pub-3940256099942544/5224354917"
const TEST_BANNER_ID: String = "ca-app-pub-3940256099942544/9214589741"
## Google'ın resmi Android geçiş (interstitial) reklamı test birimi
## (developers.google.com/admob/android/interstitial, 2026-09-22) — M8.9-02.
const TEST_INTERSTITIAL_ID: String = "ca-app-pub-3940256099942544/1033173712"

## UMP debug coğrafyası (yalnız DEBUG build + test modu). "not_eea", UMP
## 3.1'de kullanımdan kalkan NOT_EEA yerine önerilen OTHER'a eşlenir.
const DEBUG_GEOGRAPHY_VALUES: Array[String] = ["", "disabled", "eea", "not_eea", "regulated_us_state", "other"]

## Kitle kararı anahtarları (owner, AUDIENCE_DECISION.md). "" = karar yok.
const AUDIENCE_DECISIONS: Array[String] = ["general_13_plus", "mixed_audience", "child_directed"]
const TAG_VALUES: Array[String] = ["unspecified", "true", "false"]
## SDK'nın kabul ettiği en yüksek reklam derecesi değerleri (arka uç doğrulaması).
const CONTENT_RATINGS: Array[String] = ["G", "PG", "T", "MA"]
## 13–17 genç reklam işlemi stratejisi kaydı (owner). "" = kayıt yok.
const TEEN_AD_TREATMENTS: Array[String] = ["age_band_routing"]
## Yargı bölgesi yaş yükümlülükleri değerlendirmesi kaydı (owner / hukuk). "" = kayıt yok.
const JURISDICTION_AGE_REVIEWS: Array[String] = ["recorded"]
## Uygulamanın Google Play içerik derecesi (IARC genel yaş etiketi) — owner Play Console
## içerik derecelendirme anketinden sonra kaydeder; "" = kayıt yok. Release kapısı bununla
## yönlendirmenin reklam derecelerini karşılaştırır (Play "Uygunsuz reklamlar" politikası).
const APP_CONTENT_RATINGS: Array[String] = ["3+", "7+", "12+", "16+", "18+"]

## AdMob kimlik biçimleri (16 haneli yayıncı; ~ uygulama, / reklam birimi).
const APP_ID_PATTERN: String = "^ca-app-pub-\\d{16}~\\d{10}$"
const UNIT_ID_PATTERN: String = "^ca-app-pub-\\d{16}/\\d{10}$"

enum BuildType { DEBUG, RELEASE }

var build_type: BuildType = BuildType.DEBUG
## Dosyadaki `[General] is_real` — owner'ın "release kimlikleri dolu" beyanı.
var file_is_real: bool = false
## ETKİN üretim modu: yalnız RELEASE build'de true (Admob düğümüne verilir;
## false → UMP test cihazı + debug coğrafyası izinli).
var is_real: bool = false
var app_id: String = TEST_APP_ID
var rewarded_id: String = TEST_REWARDED_ID
var banner_id: String = TEST_BANNER_ID
var interstitial_id: String = TEST_INTERSTITIAL_ID
## Dosyada istenen debug coğrafyası (ham). Uygulanan değer için
## `effective_debug_geography()` — release'te daima "".
var debug_geography: String = ""
var audience_decision: String = ""
var tag_for_child_directed_treatment: String = "unspecified"
var tag_for_under_age_of_consent: String = "unspecified"
## `[Audience] teen_ad_treatment` (owner stratejisi kaydı, TASK/043); "" = yok.
var teen_ad_treatment: String = ""
## `[Audience] app_content_rating` (uygulamanın Play içerik derecesi, owner); "" = yok.
var app_content_rating: String = ""
## `[Audience] jurisdiction_age_review` (owner / hukuk değerlendirmesi kaydı); "" = yok.
var jurisdiction_age_review: String = ""
var source: String = "defaults"
## İlk sorun (geriye uyumlu tek satır); tamamı `problems()`.
var error: String = ""
var _problems: PackedStringArray = PackedStringArray()


## Çalışan build'in türü: export edilmiş release şablonu → RELEASE.
static func current_build_type() -> BuildType:
	return BuildType.DEBUG if OS.is_debug_build() else BuildType.RELEASE


static func load_project() -> AdConfig:
	return load_file(CONFIG_PATH, current_build_type())


static func load_file(path: String, type: BuildType) -> AdConfig:
	var config := AdConfig.new()
	config.build_type = type
	config._load(path)
	return config


## Test varsayılanları (masaüstü/headless testler için): DEBUG, Google örnekleri.
static func test_defaults() -> AdConfig:
	var config := AdConfig.new()
	config._validate()
	return config


func _load(path: String) -> void:
	is_real = build_type == BuildType.RELEASE
	if is_real:
		# Release'te hiçbir test varsayılanı yok: dosya ne derse o.
		app_id = ""
		rewarded_id = ""
		banner_id = ""
		interstitial_id = ""
	if not FileAccess.file_exists(path):
		source = "defaults (dosya yok)"
		# Export edilmiş build'de dosya paketlenmemişse KAPALI kal: manifest'teki
		# uygulama kimliği ile çalışma zamanı kimlikleri ayrışabilir.
		if OS.has_feature("template") or is_real:
			_problems.append("android_export.cfg export paketinde yok")
		_validate()
		return
	var file := ConfigFile.new()
	var err: Error = file.load(path)
	if err != OK:
		source = "defaults (okuma hatası)"
		_problems.append("android_export.cfg okunamadı (%d)" % err)
		_validate()
		return
	source = path
	file_is_real = bool(file.get_value("General", "is_real", false))
	var section: String = "Release" if is_real else "Debug"
	app_id = String(file.get_value(section, "app_id", "" if is_real else TEST_APP_ID)).strip_edges()
	rewarded_id = String(file.get_value(section, "rewarded_id", "" if is_real else TEST_REWARDED_ID)).strip_edges()
	banner_id = String(file.get_value(section, "banner_id", "" if is_real else TEST_BANNER_ID)).strip_edges()
	interstitial_id = String(file.get_value(section, "interstitial_id", "" if is_real else TEST_INTERSTITIAL_ID)).strip_edges()
	debug_geography = String(file.get_value("Debug", "debug_geography", "")).strip_edges().to_lower()
	audience_decision = String(file.get_value("Audience", "decision", "")).strip_edges().to_lower()
	tag_for_child_directed_treatment = String(file.get_value("Audience", "tag_for_child_directed_treatment",
		"unspecified")).strip_edges().to_lower()
	tag_for_under_age_of_consent = String(file.get_value("Audience", "tag_for_under_age_of_consent",
		"unspecified")).strip_edges().to_lower()
	teen_ad_treatment = String(file.get_value("Audience", "teen_ad_treatment", "")).strip_edges().to_lower()
	app_content_rating = String(file.get_value("Audience", "app_content_rating", "")).strip_edges()
	jurisdiction_age_review = String(file.get_value("Audience", "jurisdiction_age_review", "")).strip_edges().to_lower()
	if file.has_section_key("Audience", "max_ad_content_rating"):
		_problems.append("[Audience] max_ad_content_rating artık kullanılmıyor (TASK/043: derece yaş bandından — TEEN T, ADULT MA); anahtarı kaldır")
	_validate()


func _validate() -> void:
	if not DEBUG_GEOGRAPHY_VALUES.has(debug_geography):
		_problems.append("geçersiz debug_geography '%s'" % debug_geography)
		debug_geography = ""
	if not TAG_VALUES.has(tag_for_child_directed_treatment):
		_problems.append("geçersiz tag_for_child_directed_treatment '%s'" % tag_for_child_directed_treatment)
	if not TAG_VALUES.has(tag_for_under_age_of_consent):
		_problems.append("geçersiz tag_for_under_age_of_consent '%s'" % tag_for_under_age_of_consent)
	if not teen_ad_treatment.is_empty() and not TEEN_AD_TREATMENTS.has(teen_ad_treatment):
		_problems.append("geçersiz [Audience] teen_ad_treatment '%s'" % teen_ad_treatment)
	if not app_content_rating.is_empty() and not APP_CONTENT_RATINGS.has(app_content_rating):
		_problems.append("geçersiz [Audience] app_content_rating '%s' (3+ / 7+ / 12+ / 16+ / 18+)" % app_content_rating)
	if not jurisdiction_age_review.is_empty() and not JURISDICTION_AGE_REVIEWS.has(jurisdiction_age_review):
		_problems.append("geçersiz [Audience] jurisdiction_age_review '%s'" % jurisdiction_age_review)
	if not audience_decision.is_empty() and not AUDIENCE_DECISIONS.has(audience_decision):
		_problems.append("geçersiz [Audience] decision '%s'" % audience_decision)
	var ids: Dictionary = {"app_id": app_id, "rewarded_id": rewarded_id, "banner_id": banner_id,
		"interstitial_id": interstitial_id}
	if is_real:
		_validate_release_ids(ids)
	else:
		_validate_debug_ids(ids)
	error = _problems[0] if not _problems.is_empty() else ""


## DEBUG: yalnız Google'ın örnek yayıncısı — canlı birim imkânsız.
func _validate_debug_ids(ids: Dictionary) -> void:
	for key: String in ids:
		var value: String = ids[key]
		if not _well_formed(key, value):
			_problems.append("[Debug] %s biçimsiz ya da boş" % key)
		elif not value.begins_with(TEST_PUBLISHER):
			_problems.append("[Debug] %s Google örnek kimliği değil — debug build canlı birim isteyemez" % key)


## RELEASE: dört gerçek kimlik, aynı yayıncı, birbirinden farklı birimler.
func _validate_release_ids(ids: Dictionary) -> void:
	if not file_is_real:
		_problems.append("release build ama [General] is_real=false (üretim kimlikleri onaylanmadı)")
	var publishers: Dictionary = {}
	for key: String in ids:
		var value: String = ids[key]
		if value.is_empty():
			_problems.append("[Release] %s boş" % key)
		elif not _well_formed(key, value):
			_problems.append("[Release] %s biçimsiz ('%s')" % [key, value])
		elif value.begins_with(TEST_PUBLISHER):
			_problems.append("[Release] %s Google örnek (test) kimliği" % key)
		else:
			publishers[value.substr(0, 27)] = true
	if publishers.size() > 1:
		_problems.append("[Release] kimlikleri farklı AdMob yayıncılarından")
	var units: Array[String] = [rewarded_id, banner_id, interstitial_id]
	for i in units.size():
		for j in range(i + 1, units.size()):
			if not units[i].is_empty() and units[i] == units[j]:
				_problems.append("[Release] iki reklam türü aynı birim kimliğini kullanıyor")


static func _well_formed(key: String, value: String) -> bool:
	var regex := RegEx.create_from_string(APP_ID_PATTERN if key == "app_id" else UNIT_ID_PATTERN)
	return regex.search(value) != null


## Reklam başlatılabilir mi? Kurallar yukarıda; tek sorun bile → false.
func is_valid() -> bool:
	return _problems.is_empty()


func problems() -> PackedStringArray:
	return _problems.duplicate()


## Uygulanacak UMP debug coğrafyası: yalnız DEBUG build + test modunda, aksi
## hâlde daima "" (üretimde coğrafya zorlanamaz).
func effective_debug_geography() -> String:
	if build_type != BuildType.DEBUG or is_real:
		return ""
	return debug_geography


## QA/test kancası (tools/ads_device): DEBUG build'de coğrafyayı değiştirir;
## RELEASE'te reddeder (false).
func set_debug_geography(value: String) -> bool:
	var geo: String = value.strip_edges().to_lower()
	if build_type != BuildType.DEBUG or is_real or not DEBUG_GEOGRAPHY_VALUES.has(geo):
		return false
	debug_geography = geo
	return true


func describe() -> String:
	return "AdConfig(build=%s, is_real=%s, file_is_real=%s, app_id=%s, rewarded=%s, banner=%s, interstitial=%s, geo=%s, audience=%s tfcd=%s tfua=%s teen=%s, source=%s%s)" % [
		"release" if build_type == BuildType.RELEASE else "debug", str(is_real), str(file_is_real),
		app_id, rewarded_id, banner_id, interstitial_id,
		effective_debug_geography() if not effective_debug_geography().is_empty() else "-",
		audience_decision if not audience_decision.is_empty() else "-", tag_for_child_directed_treatment,
		tag_for_under_age_of_consent, (teen_ad_treatment if not teen_ad_treatment.is_empty() else "-")
			+ " app_rating=" + (app_content_rating if not app_content_rating.is_empty() else "-"), source,
		"" if error.is_empty() else ", HATA: " + error]
