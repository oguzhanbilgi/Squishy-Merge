extends Node
## M9-01 — release yapılandırması, release kapısı ve UMP sarmalayıcı arayüz
## testleri. Deterministik: İNTERNET, CİHAZ VE EKLENTİ YOK.
##
##   - DEBUG build yalnız Google resmî test kimliklerini kabul eder
##   - RELEASE build boş / Google test / biçimsiz / eksik / karışık kimliği REDDEDER,
##     dört gerçek kimlik + is_real=true ister
##   - debug coğrafyası üretimde (RELEASE) imkânsız; DEBUG'da EEA / NOT_EEA kancaları
##   - kitle: ürün kitlesi owner kararı 13+ genel kitle (general_13_plus, 2026-09-25,
##     KAPALI); TFCD / TFUA / içerik derecesi değerleri (karar değiştirmedi) ve SDK
##     eşlemesi — bunlar TEEN işlemi DEĞİL: 13–17 genç reklam işlemi / yargı bölgesi
##     uyumu ayrı, AÇIK bir OWNER ("UYUM:") engeli
##   - ReleaseReadiness kuralları (paket kimliği + QA kimliği ayrımı, sürüm tek
##     kaynağı, AAB, arm64, hedef API, reklam, kitle, gizlilik URL'i, yamalı eklenti,
##     upload anahtarı, NON_PUBLISHABLE) + bu projenin bugünkü durumu (BLOCKED)
##   - şifre / takma ad raporlara sızmaz
##   - UMP sarmalayıcıları arayüz düzeyinde (AdBackend / FakeAdBackend / Admob.gd
##     cephesi / AdmobBackend eşlemeleri) + commit edilmiş AAR'ların bytecode'u
##   - TASK/041: RequestConfiguration düzeltmesi (0002) korunuyor; eski kusurlu M9 AAR'ı
##     ve bilinmeyen AAR CODE; facade değerleri (G / unspecified / unspecified)
##   - TASK/042: onaylı AAR = v6.0 + 0001 + 0002 + 0003 (GMA 25.3.0, UMP 4.0.0 geçişli,
##     TFAT UNSPECIFIED / CHILD / TEEN + SDK geri okuması); TASK/041'in GMA 24.9.0 AAR'ı
##     artık onaylı DEĞİL (CODE); GMA sürümü + facade TFAT API'si kapıda; üretim yaş işlemi
##     UNSPECIFIED; yapılandırma SDK başlamadan ÖNCE bir kez + geri okuma doğrulaması
##     (uyuşmazsa SDK başlamaz); Age Signals reklama bağlı DEĞİL; genç işlemi OWNER engeli AÇIK
##   - Ayarlar'daki "Gizlilik politikası" satırı (URL yokken gizli)
##   - TASK/043: yaş bandı yönlendirmesi (nötr yaş ekranı; 13–17 TEEN + T, 18+ UNSPECIFIED +
##     MA, 13 altı / bilinmeyen reklamsız): TFAT / derece yalnız AgeGate.ad_route'tan ve yalnız
##     yöneticinin rota yolundan, attach'ten ÖNCE; [Audience] max_ad_content_rating kalktı;
##     genç işlemi engeli owner kaydı + kod tablosu ile kalkar (kodda yazılı bayrak YOK);
##     Play "Uygunsuz reklamlar" (uygulama içerik derecesi) ve yargı bölgesi yaş
##     yükümlülükleri ayrı OWNER / UYUM engelleri
##
## Kayda yazmaz (yalnız user:// geçici dosyalar, sonda silinir); yine de kayıt
## dosyası byte-identical kontrol edilir.
##
##   godot --headless --audio-driver Dummy --path . res://tools/release_config_test.tscn

const TMP_CFG: String = "user://_release_cfg_test.cfg"
const TMP_JAR: String = "user://_release_cfg_test_classes.jar"
const TMP_KEYSTORE: String = "user://_release_cfg_test_upload.jks"
const REAL_APP: String = "ca-app-pub-1234567890123456~1234567890"
const REAL_REWARDED: String = "ca-app-pub-1234567890123456/1111111111"
const REAL_BANNER: String = "ca-app-pub-1234567890123456/2222222222"
const REAL_INTER: String = "ca-app-pub-1234567890123456/3333333333"
const SETTINGS_SCENE: String = "res://scenes/ui/settings_panel.tscn"
## M9-01'in onaylı ama kusurlu yamalı AAR'ları (v6.0 + 0001; TASK/040: RequestConfiguration
## hiç uygulanmıyor). TASK/041 bunları v6.0 + 0001 + 0002 derlemesiyle değiştirdi.
const DEFECTIVE_M9_RELEASE_AAR_SHA256: String = "90d359921f10bc6618ed63b9ea97cdba5afcbdfbb8cb72fe264834e5bf478284"
const DEFECTIVE_M9_DEBUG_AAR_SHA256: String = "e3ac9a6b1492468928c037d4d21464310560c7b21c14c597fa4a567c23c6eb2d"
const CONFIG_PATCH: String = "res://tools/admob_plugin/0002-fix-request-configuration-value-types.patch"
## TASK/042 üretim yaması (TASK/040 spike'ının yerine; spike dosyaları kaldırıldı).
const GMA25_PATCH: String = "res://tools/admob_plugin/0003-gma25-age-restricted-treatment.patch"
const RETIRED_SPIKE_FILES: Array[String] = ["res://tools/admob_plugin/0003-spike-gma25-age-restricted-treatment.patch",
	"res://tools/admob_plugin/0002-spike-gma25-age-restricted-treatment.patch",
	"res://tools/admob_plugin/spike_qa_export.sh", "res://tools/admob_plugin/spike_qa_preset.py"]
## TASK/041'in onaylı AAR'ları (v6.0 + 0001 + 0002, GMA 24.9.0) — TASK/042'de yerini
## GMA 25.3.0 derlemesine bıraktı; kusurlu değil ama artık onaylı değil.
const TASK041_RELEASE_AAR_SHA256: String = "14c745e9d00dbcb582b4e890f5c8a95969f1a15f97a4dfb6e0107860624541a4"
const TASK041_DEBUG_AAR_SHA256: String = "40ae0592773a19045c6a97d1d7182347e1c6d026497ee574a58562b450109e2c"
const KEYSTORE_ENV: Array[String] = ["GODOT_ANDROID_KEYSTORE_RELEASE_PATH", "GODOT_ANDROID_KEYSTORE_RELEASE_USER",
	"GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD", "SQUISHY_NON_PUBLISHABLE_RELEASE"]

var _fails: int = 0
var _checks: int = 0
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _env_backup: Dictionary = {}


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	await get_tree().process_frame
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	for key in KEYSTORE_ENV:
		_env_backup[key] = OS.get_environment(key)
		OS.unset_environment(key)

	_test_debug_ids()
	_test_release_ids()
	_test_debug_geography()
	_test_audience()
	_test_release_gate_rules()
	_test_current_project_state()
	_test_secret_hygiene()
	_test_wrapper_interface()
	_test_patched_binaries()
	_test_teen_treatment_boundaries()
	_test_request_configuration_path()
	_test_tfat_api()
	_test_age_band_routing_gate()
	await _test_privacy_policy_row()

	for key in KEYSTORE_ENV:
		if String(_env_backup[key]).is_empty():
			OS.unset_environment(key)
		else:
			OS.set_environment(key, _env_backup[key])
	for path in [TMP_CFG, TMP_JAR, TMP_KEYSTORE]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var restored: bool = not _had_save or FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == _save_bytes
	_c("kayıt dosyası dokunulmadı (byte-identical)", restored)
	print("=== SONUC: %d/%d kontrol, %d kaldi ===" % [_checks - _fails, _checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


## Geçici android_export.cfg yazar ve verilen build türüyle yükler.
func _cfg(sections: Dictionary, type: AdConfig.BuildType) -> AdConfig:
	var file := ConfigFile.new()
	for section: String in sections:
		for key: String in sections[section]:
			file.set_value(section, key, sections[section][key])
	file.save(TMP_CFG)
	return AdConfig.load_file(TMP_CFG, type)


func _real_release(extra: Dictionary = {}) -> Dictionary:
	var sections: Dictionary = {
		"General": {"is_real": true},
		"Release": {"app_id": REAL_APP, "rewarded_id": REAL_REWARDED, "banner_id": REAL_BANNER,
			"interstitial_id": REAL_INTER},
		"Audience": {"decision": "general_13_plus"},
	}
	for section: String in extra:
		if not sections.has(section):
			sections[section] = {}
		for key: String in extra[section]:
			sections[section][key] = extra[section][key]
	return sections


## android_export.cfg [Audience]: hiçbir anahtar yaş işlemi değil ve hiçbir değer TEEN / CHILD
## seçmiyor (yorumlar sayılmaz — ConfigFile ile okunur).
static func _audience_selects_teen() -> bool:
	var file := ConfigFile.new()
	if file.load(AdConfig.CONFIG_PATH) != OK:
		return true
	for key in file.get_section_keys("Audience"):
		var value: String = str(file.get_value("Audience", key)).to_lower()
		if key.to_lower().contains("age_restricted") or value == "teen" or value == "child":
			return true
	return false


static func _problem_count(config: AdConfig, needle: String) -> int:
	var n: int = 0
	for problem in config.problems():
		if problem.contains(needle):
			n += 1
	return n


# --- DEBUG: yalnız Google test kimlikleri ------------------------------------------

func _test_debug_ids() -> void:
	print("-- DEBUG build: yalnız Google resmî test kimlikleri")
	var project := AdConfig.load_project()
	_c("proje yapılandırması (editör = DEBUG) geçerli, dört kimlik Google örneği", project.is_valid()
		and project.build_type == AdConfig.BuildType.DEBUG and not project.is_real
		and project.app_id == AdConfig.TEST_APP_ID and project.rewarded_id == AdConfig.TEST_REWARDED_ID
		and project.banner_id == AdConfig.TEST_BANNER_ID and project.interstitial_id == AdConfig.TEST_INTERSTITIAL_ID)
	_c("test_defaults(): DEBUG + Google örnekleri + geçerli", AdConfig.test_defaults().is_valid()
		and AdConfig.test_defaults().build_type == AdConfig.BuildType.DEBUG)
	var sample := _cfg({"General": {"is_real": false}, "Debug": {"app_id": AdConfig.TEST_APP_ID,
		"rewarded_id": AdConfig.TEST_REWARDED_ID, "banner_id": AdConfig.TEST_BANNER_ID,
		"interstitial_id": AdConfig.TEST_INTERSTITIAL_ID}}, AdConfig.BuildType.DEBUG)
	_c("DEBUG + açık Google örnek kimlikleri -> kabul", sample.is_valid())
	var live := _cfg({"Debug": {"rewarded_id": REAL_REWARDED}}, AdConfig.BuildType.DEBUG)
	_c("DEBUG + [Debug]'da gerçek (Google dışı) birim -> GEÇERSİZ (canlı reklam imkânsız)", not live.is_valid()
		and _problem_count(live, "Google örnek kimliği değil") == 1)
	var malformed := _cfg({"Debug": {"banner_id": "banner"}}, AdConfig.BuildType.DEBUG)
	_c("DEBUG + biçimsiz kimlik -> GEÇERSİZ", not malformed.is_valid())
	var real_file := _cfg(_real_release(), AdConfig.BuildType.DEBUG)
	_c("dosya is_real=true + gerçek [Release] olsa da DEBUG build Google örneklerini kullanır",
		real_file.is_valid() and not real_file.is_real and real_file.file_is_real
		and real_file.app_id == AdConfig.TEST_APP_ID and real_file.interstitial_id == AdConfig.TEST_INTERSTITIAL_ID)


# --- RELEASE: dört gerçek kimlik ----------------------------------------------------

func _test_release_ids() -> void:
	print("-- RELEASE build: dört gerçek kimlik, fail-closed")
	var project := AdConfig.load_file(AdConfig.CONFIG_PATH, AdConfig.BuildType.RELEASE)
	_c("bugünkü proje yapılandırması RELEASE'te GEÇERSİZ (is_real=false + 4 boş kimlik)", not project.is_valid()
		and project.is_real and _problem_count(project, "is_real=false") == 1 and _problem_count(project, "boş") == 4)
	var empty := _cfg({"General": {"is_real": true}, "Release": {"app_id": "", "rewarded_id": "", "banner_id": "",
		"interstitial_id": ""}}, AdConfig.BuildType.RELEASE)
	_c("release reddeder: boş kimlikler (4 sorun)", not empty.is_valid() and _problem_count(empty, "boş") == 4)
	var tests := _cfg({"General": {"is_real": true}, "Release": {"app_id": AdConfig.TEST_APP_ID,
		"rewarded_id": AdConfig.TEST_REWARDED_ID, "banner_id": AdConfig.TEST_BANNER_ID,
		"interstitial_id": AdConfig.TEST_INTERSTITIAL_ID}}, AdConfig.BuildType.RELEASE)
	_c("release reddeder: Google test kimlikleri (4 sorun)", not tests.is_valid()
		and _problem_count(tests, "Google örnek (test)") == 4)
	var ok := _cfg(_real_release(), AdConfig.BuildType.RELEASE)
	_c("release kabul: dört gerçek kimlik + is_real=true, üretim kimlikleri seçildi", ok.is_valid() and ok.is_real
		and ok.app_id == REAL_APP and ok.rewarded_id == REAL_REWARDED and ok.banner_id == REAL_BANNER
		and ok.interstitial_id == REAL_INTER)
	for key in ["app_id", "rewarded_id", "banner_id", "interstitial_id"]:
		var missing := _cfg(_real_release({"Release": {key: ""}}), AdConfig.BuildType.RELEASE)
		_c("release dört kimliği de ister: %s boş -> GEÇERSİZ (tek sorun)" % key, not missing.is_valid()
			and missing.problems().size() == 1)
		var sample := _cfg(_real_release({"Release": {key: AdConfig.TEST_APP_ID if key == "app_id" else AdConfig.TEST_BANNER_ID}}),
			AdConfig.BuildType.RELEASE)
		_c("release: yalnız %s Google örneği -> GEÇERSİZ" % key, not sample.is_valid())
	var not_real := _cfg(_real_release({"General": {"is_real": false}}), AdConfig.BuildType.RELEASE)
	_c("release: kimlikler dolu ama is_real=false (onay yok) -> GEÇERSİZ", not not_real.is_valid()
		and _problem_count(not_real, "is_real=false") == 1)
	var mixed := _cfg(_real_release({"Release": {"banner_id": "ca-app-pub-9999999999999999/2222222222"}}),
		AdConfig.BuildType.RELEASE)
	_c("release: farklı yayıncıdan kimlik -> GEÇERSİZ", not mixed.is_valid() and _problem_count(mixed, "yayıncı") == 1)
	var duplicate := _cfg(_real_release({"Release": {"interstitial_id": REAL_REWARDED}}), AdConfig.BuildType.RELEASE)
	_c("release: iki reklam türü aynı birim -> GEÇERSİZ", not duplicate.is_valid()
		and _problem_count(duplicate, "aynı birim") == 1)
	var short := _cfg(_real_release({"Release": {"app_id": "ca-app-pub-123456789012345~1234567890"}}),
		AdConfig.BuildType.RELEASE)
	_c("release: biçimsiz uygulama kimliği (15 haneli yayıncı) -> GEÇERSİZ", not short.is_valid()
		and _problem_count(short, "biçimsiz") == 1)
	var unit_as_app := _cfg(_real_release({"Release": {"app_id": REAL_BANNER}}), AdConfig.BuildType.RELEASE)
	_c("release: app_id yerine birim kimliği -> GEÇERSİZ", not unit_as_app.is_valid())
	var spaced := _cfg(_real_release({"Release": {"rewarded_id": "  " + REAL_REWARDED + " "}}), AdConfig.BuildType.RELEASE)
	_c("release: kenar boşlukları kırpılır", spaced.is_valid() and spaced.rewarded_id == REAL_REWARDED)
	var absent := AdConfig.load_file("user://_release_cfg_yok.cfg", AdConfig.BuildType.RELEASE)
	_c("release: yapılandırma dosyası yok -> GEÇERSİZ (test varsayılanına düşüş yok)", not absent.is_valid()
		and absent.app_id.is_empty() and absent.rewarded_id.is_empty())
	var backend_src: String = FileAccess.get_file_as_string("res://scripts/ads/admob_backend.gd")
	_c("AdmobBackend geçersiz yapılandırmada arka uç KURMAZ (fail-closed; kaynak)",
		backend_src.contains("if config == null or not config.is_valid():") and backend_src.contains("return null"))


# --- Debug coğrafyası --------------------------------------------------------------

func _test_debug_geography() -> void:
	print("-- UMP debug coğrafyası: yalnız DEBUG; EEA / NOT_EEA kancaları")
	var eea := _cfg({"Debug": {"debug_geography": "EEA"}}, AdConfig.BuildType.DEBUG)
	_c("DEBUG + EEA -> uygulanır (küçük harfe normalize)", eea.is_valid() and eea.effective_debug_geography() == "eea"
		and AdmobBackend.debug_geography_value(eea.effective_debug_geography()) == ConsentRequestParameters.DebugGeography.EEA)
	var not_eea := _cfg({"Debug": {"debug_geography": "not_eea"}}, AdConfig.BuildType.DEBUG)
	_c("DEBUG + NOT_EEA -> UMP OTHER'a eşlenir (NOT_EEA 3.1'de kullanımdan kalktı)", not_eea.is_valid()
		and AdmobBackend.debug_geography_value(not_eea.effective_debug_geography()) == ConsentRequestParameters.DebugGeography.OTHER)
	_c("eşlemeler: other / regulated_us_state / disabled / boş",
		AdmobBackend.debug_geography_value("other") == ConsentRequestParameters.DebugGeography.OTHER
		and AdmobBackend.debug_geography_value("regulated_us_state") == ConsentRequestParameters.DebugGeography.REGULATED_US_STATE
		and AdmobBackend.debug_geography_value("disabled") == ConsentRequestParameters.DebugGeography.DISABLED
		and AdmobBackend.debug_geography_value("") == ConsentRequestParameters.DebugGeography.NOT_SET)
	_c("eklentiye giden değerler UMP sabitleriyle aynı (EEA=1, OTHER=4, NOT_SET gönderilmez)",
		int(ConsentRequestParameters.DebugGeography.EEA) == 1 and int(ConsentRequestParameters.DebugGeography.OTHER) == 4
		and int(ConsentRequestParameters.DebugGeography.NOT_SET) == -1)
	var bad := _cfg({"Debug": {"debug_geography": "mars"}}, AdConfig.BuildType.DEBUG)
	_c("geçersiz coğrafya -> yapılandırma GEÇERSİZ", not bad.is_valid() and bad.effective_debug_geography() == "")
	var release_geo := _cfg(_real_release({"Debug": {"debug_geography": "eea"}}), AdConfig.BuildType.RELEASE)
	_c("RELEASE: dosyada EEA olsa da etkin coğrafya YOK (üretimde zorlanamaz)", release_geo.is_valid()
		and release_geo.debug_geography == "eea" and release_geo.effective_debug_geography() == ""
		and AdmobBackend.debug_geography_value(release_geo.effective_debug_geography()) == ConsentRequestParameters.DebugGeography.NOT_SET)
	_c("RELEASE: QA kancası set_debug_geography REDDEDİLİR", not release_geo.set_debug_geography("eea")
		and release_geo.effective_debug_geography() == "")
	var qa := AdConfig.test_defaults()
	_c("DEBUG: QA kancası EEA / NOT_EEA kabul, geçersizi reddeder", qa.set_debug_geography("eea")
		and qa.effective_debug_geography() == "eea" and qa.set_debug_geography("NOT_EEA")
		and qa.effective_debug_geography() == "not_eea" and not qa.set_debug_geography("mars")
		and qa.effective_debug_geography() == "not_eea")
	var facade: String = FileAccess.get_file_as_string("res://addons/AdmobPlugin/Admob.gd")
	_c("kilit 2: eklenti cephesi coğrafyayı yalnız is_real=false iken gönderir",
		facade.contains("\t\t\tif not is_real:\n\t\t\t\tif debug_geography != ConsentRequestParameters.DebugGeography.NOT_SET:"))
	var patch: String = FileAccess.get_file_as_string("res://tools/admob_plugin/0001-ump-privacy-options-and-debug-geography.patch")
	_c("kilit 3 + #120: Java yalnız gerçek-dışı modda debug ayarı kurar; Long kabul (instanceof Number)",
		patch.contains("+\t\t\t\tif (debugGeographyObj instanceof Number) {")
		and patch.contains("-\t\t\t\tif (debugGeographyObj instanceof Integer) {"))
	var device_src: String = FileAccess.get_file_as_string("res://tools/ads_device.gd")
	_c("QA sürücüsü coğrafyayı yalnız set_debug_geography ile değiştirir (release'te reddedilir)",
		device_src.contains("config.set_debug_geography(") and not device_src.contains("config.debug_geography ="))


# --- Kitle ---------------------------------------------------------------------------

func _test_audience() -> void:
	print("-- kitle: ürün kitlesi 13+ (general_13_plus, KAPALI) + TFCD / TFUA / içerik derecesi (TEEN işlemi DEĞİL)")
	var project := AdConfig.load_project()
	_c("ürün kitlesi seçili: decision general_13_plus (13+ genel kitle; Play 13–15 / 16–17 / 18+), yapılandırma geçerli",
		project.audience_decision == "general_13_plus" and project.is_valid())
	var audience_file := ConfigFile.new()
	audience_file.load(AdConfig.CONFIG_PATH)
	_c("eski yaş etiketleri korunuyor: TFCD unspecified, TFUA unspecified; derece anahtarı YOK (TASK/043: yaş bandından)",
		project.tag_for_child_directed_treatment == "unspecified"
		and project.tag_for_under_age_of_consent == "unspecified"
		and not audience_file.has_section_key("Audience", "max_ad_content_rating")
		and not ("max_ad_content_rating" in project))
	_c("projenin eski etiketleri SDK'ya aynen: TFCD/TFUA UNSPECIFIED (gönderilmez — TEEN DEĞİL)",
		AdmobBackend._tfcd(project.tag_for_child_directed_treatment) == AdmobConfig.TagForChildDirectedTreatment.UNSPECIFIED
		and AdmobBackend._tfua(project.tag_for_under_age_of_consent) == AdmobConfig.TagForUnderAgeOfConsent.UNSPECIFIED)
	var plugin_api: String = FileAccess.get_file_as_string("res://addons/AdmobPlugin/Admob.gd") \
		+ FileAccess.get_file_as_string("res://addons/AdmobPlugin/model/AdmobConfig.gd")
	_c("TFCD/TFUA TEEN ifade edemez (enumlarında TEEN yok); TEEN yalnız ayrı TFAT enumunda (GMA 25.3.0, TASK/042) ve projenin [Audience] etiketleri onu seçmez",
		not AdmobConfig.TagForChildDirectedTreatment.has("TEEN") and not AdmobConfig.TagForUnderAgeOfConsent.has("TEEN")
		and AdmobConfig.AgeRestrictedTreatment.has("TEEN") and plugin_api.contains("enum AgeRestrictedTreatment")
		and FileAccess.get_file_as_string("res://addons/AdmobPlugin/AdmobPlugin.gd").contains("com.google.android.gms:play-services-ads:25.3.0")
		and not _audience_selects_teen())
	var release_project := AdConfig.load_file(AdConfig.CONFIG_PATH, AdConfig.BuildType.RELEASE)
	_c("RELEASE yüklemesinde de general_13_plus; ürün kitlesinin kodu hazır (CODE engeli yok), [Audience] sorunu yok",
		release_project.audience_decision == "general_13_plus"
		and ReleaseReadiness.IMPLEMENTED_AUDIENCE_DECISIONS.has(release_project.audience_decision)
		and _problem_count(release_project, "Audience") == 0 and _problem_count(release_project, "tag_for") == 0
		and _problem_count(release_project, "max_ad_content_rating") == 0)
	_c("unspecified -> SDK'ya gönderilmez (UNSPECIFIED)",
		AdmobBackend._tfcd("unspecified") == AdmobConfig.TagForChildDirectedTreatment.UNSPECIFIED
		and AdmobBackend._tfua("unspecified") == AdmobConfig.TagForUnderAgeOfConsent.UNSPECIFIED)
	_c("true/false eşlemesi", AdmobBackend._tfcd("true") == AdmobConfig.TagForChildDirectedTreatment.TRUE
		and AdmobBackend._tfcd("false") == AdmobConfig.TagForChildDirectedTreatment.FALSE
		and AdmobBackend._tfua("true") == AdmobConfig.TagForUnderAgeOfConsent.TRUE
		and AdmobBackend._tfua("false") == AdmobConfig.TagForUnderAgeOfConsent.FALSE)
	_c("içerik derecesi eşlemesi G / PG / T / MA", AdmobBackend._content_rating("G") == AdmobConfig.ContentRating.G
		and AdmobBackend._content_rating("PG") == AdmobConfig.ContentRating.PG
		and AdmobBackend._content_rating("T") == AdmobConfig.ContentRating.T
		and AdmobBackend._content_rating("MA") == AdmobConfig.ContentRating.MA)
	_c("geçersiz TFCD / karar / teen_ad_treatment / app_content_rating / jurisdiction_age_review -> yapılandırma GEÇERSİZ",
		not _cfg({"Audience": {"tag_for_child_directed_treatment": "maybe"}}, AdConfig.BuildType.DEBUG).is_valid()
		and not _cfg({"Audience": {"decision": "kids"}}, AdConfig.BuildType.DEBUG).is_valid()
		and not _cfg({"Audience": {"teen_ad_treatment": "teen"}}, AdConfig.BuildType.DEBUG).is_valid()
		and not _cfg({"Audience": {"app_content_rating": "PEGI 3"}}, AdConfig.BuildType.DEBUG).is_valid()
		and not _cfg({"Audience": {"jurisdiction_age_review": "yes"}}, AdConfig.BuildType.DEBUG).is_valid())
	var stale := _cfg({"Audience": {"max_ad_content_rating": "G"}}, AdConfig.BuildType.DEBUG)
	_c("TASK/043: eski [Audience] max_ad_content_rating anahtarı (geçerli değerle bile) -> GEÇERSİZ (yanıltıcı, kullanılmayan ayar kalmaz)",
		not stale.is_valid() and _problem_count(stale, "artık kullanılmıyor") == 1)
	var decided := _cfg(_real_release({"Audience": {"tag_for_child_directed_treatment": "false",
		"tag_for_under_age_of_consent": "false", "teen_ad_treatment": "Age_Band_Routing", "app_content_rating": "12+",
		"jurisdiction_age_review": "recorded"}}), AdConfig.BuildType.RELEASE)
	_c("owner kayıtları okunur (strateji küçük harfe, derece aynen)", decided.is_valid()
		and decided.audience_decision == "general_13_plus" and decided.tag_for_child_directed_treatment == "false"
		and decided.teen_ad_treatment == "age_band_routing" and decided.app_content_rating == "12+"
		and decided.jurisdiction_age_review == "recorded")
	_c("bugünkü proje: üç owner kaydı da boş (strateji / içerik derecesi / yargı bölgesi değerlendirmesi)",
		project.teen_ad_treatment == "" and project.app_content_rating == "" and project.jurisdiction_age_review == "")


# --- ReleaseReadiness kuralları ------------------------------------------------------

## "Her şey tamam" girdileri: GELECEĞİ modeller — 13–17 stratejisi kayıtta, yargı bölgesi
## değerlendirmesi kayıtta, uygulamanın Play içerik derecesi yönlendirmenin T / MA
## reklamlarına izin veriyor (16+), kod tablosu temiz, bilinen eklenti kusuru yok.
func _good_inputs() -> Dictionary:
	return {
		"build": "release", "preset_name": "Android Release AAB",
		"package_id": "com.squishy.merge", "canonical_package_id": "com.squishy.merge",
		"version_code": 3, "canonical_version_code": 3, "version_name_preset": "", "project_version": "0.8.5",
		"export_format": ReleaseReadiness.FORMAT_AAB, "arm64": true, "target_sdk": "", "signed": true,
		"keystore_path_set": true, "keystore_exists": true, "keystore_is_debug": false, "keystore_user_set": true,
		"keystore_password_set": true, "ad_config": _cfg(_real_release(), AdConfig.BuildType.RELEASE),
		"privacy_policy_url": "https://squishy.invalid/privacy",
		"plugin_release_aar_sha256": ReleaseReadiness.PATCHED_RELEASE_AAR_SHA256, "plugin_facade_patched": true,
		"plugin_facade_tfat": true, "plugin_gma_version": ReleaseReadiness.REQUIRED_GMA_VERSION,
		"teen_ad_treatment_resolved": true, "jurisdiction_age_review_recorded": true, "age_routing_problems": [],
		"app_content_rating": "16+", "routed_ad_content_ratings": ["T", "MA"], "plugin_known_defects": [],
		"non_publishable_requested": false, "export_path": "build/release/squishy_merge.aab",
	}


func _gate(overrides: Dictionary) -> Dictionary:
	var inputs: Dictionary = _good_inputs()
	for key: String in overrides:
		inputs[key] = overrides[key]
	return ReleaseReadiness.evaluate(inputs)


static func _blocked_by(result: Dictionary, category: String, needle: String) -> bool:
	if result["status"] != ReleaseReadiness.STATUS_BLOCKED:
		return false
	for blocker: Dictionary in result["blockers"]:
		if blocker["category"] == category and String(blocker["message"]).contains(needle):
			return true
	return false


static func _notes_have(result: Dictionary, needle: String) -> bool:
	for note in result["notes"]:
		if String(note).contains(needle):
			return true
	return false


func _test_release_gate_rules() -> void:
	print("-- ReleaseReadiness: kurallar tek tek")
	var good: Dictionary = _gate({})
	_c("her şey tamam -> UPLOAD_CANDIDATE, engel yok", good["status"] == ReleaseReadiness.STATUS_UPLOAD_CANDIDATE
		and good["blockers"].is_empty())
	_c("paket kimliği seçilmedi -> OWNER", _blocked_by(_gate({"canonical_package_id": ""}), "OWNER", "seçilmedi"))
	_c("kanonik com.example.* -> OWNER (geçici)", _blocked_by(_gate({"canonical_package_id": "com.example.squishymerge",
		"package_id": "com.example.squishymerge"}), "OWNER", "geçici"))
	_c("preset com.example.* -> CONFIG", _blocked_by(_gate({"package_id": "com.example.squishymerge"}), "CONFIG", "package/unique_name"))
	_c("com.godot.game (Godot varsayılanı) -> engel", _gate({"package_id": "com.godot.game",
		"canonical_package_id": "com.godot.game"})["status"] == ReleaseReadiness.STATUS_BLOCKED)
	_c("preset paket ≠ project.godot -> CONFIG", _blocked_by(_gate({"package_id": "com.squishy.other"}), "CONFIG", "≠"))
	_c("TASK/043: preset user_data_backup/allow=true (kayıt otomatik yedeğe) -> CONFIG; varsayılan / false engel değil",
		_blocked_by(_gate({"user_data_backup_allowed": true}), "CONFIG", "user_data_backup/allow")
		and _gate({"user_data_backup_allowed": false})["status"] == ReleaseReadiness.STATUS_UPLOAD_CANDIDATE)
	_c("geçersiz paket biçimi -> engel", _gate({"package_id": "squishy", "canonical_package_id": "squishy"})["status"]
		== ReleaseReadiness.STATUS_BLOCKED)
	var qa: String = ReleaseReadiness.qa_package_id("com.squishy.merge")
	_c("QA / test kimliği = kalıcı kimlik + .qa", qa == "com.squishy.merge.qa")
	_c("preset QA kimliğiyle release -> CONFIG (QA paketi release olamaz)", _blocked_by(_gate({"package_id": qa}),
		"CONFIG", "QA / test kimliği"))
	_c("kanonik QA kimliği -> OWNER (üretim kimliği .qa ile bitemez)", _blocked_by(_gate({"canonical_package_id": qa,
		"package_id": qa}), "OWNER", "QA kimliği"))
	_c("versionCode ≠ tek kaynak -> CONFIG", _blocked_by(_gate({"version_code": 2}), "CONFIG", "version/code"))
	_c("tek kaynak versionCode < 1 -> CONFIG", _blocked_by(_gate({"canonical_version_code": 0, "version_code": 0}),
		"CONFIG", "< 1"))
	_c("preset versionName ≠ project.godot -> CONFIG", _blocked_by(_gate({"version_name_preset": "1.0"}), "CONFIG", "version/name"))
	_c("preset versionName boş (project'ten gelir) -> sorun yok; eşit -> sorun yok",
		_gate({"version_name_preset": ""})["status"] == ReleaseReadiness.STATUS_UPLOAD_CANDIDATE
		and _gate({"version_name_preset": "0.8.5"})["status"] == ReleaseReadiness.STATUS_UPLOAD_CANDIDATE)
	_c("release APK -> CONFIG (yalnız AAB)", _blocked_by(_gate({"export_format": 0}), "CONFIG", "AAB"))
	_c("arm64 kapalı -> CONFIG", _blocked_by(_gate({"arm64": false}), "CONFIG", "arm64"))
	_c("targetSdk 35 -> CONFIG; 36 ve boş (şablon 36) kabul", _blocked_by(_gate({"target_sdk": "35"}), "CONFIG", "targetSdk")
		and _gate({"target_sdk": "36"})["status"] == ReleaseReadiness.STATUS_UPLOAD_CANDIDATE)
	_c("reklam yapılandırması geçersiz (test kimlikleri) -> OWNER AdMob engelleri",
		_blocked_by(_gate({"ad_config": AdConfig.load_file(AdConfig.CONFIG_PATH, AdConfig.BuildType.RELEASE)}), "OWNER", "AdMob"))
	var no_decision: Dictionary = _gate({"ad_config": _cfg(_real_release({"Audience": {"decision": ""}}),
		AdConfig.BuildType.RELEASE), "teen_ad_treatment_resolved": false})
	_c("kitle kararı yok -> OWNER (UYUM satırı eklenmez: kitle bilinmiyor)",
		_blocked_by(no_decision, "OWNER", "kitle kararı yok") and not _blocked_by(no_decision, "OWNER", "UYUM:"))
	var mixed: Dictionary = _gate({"ad_config": _cfg(_real_release({"Audience": {"decision": "mixed_audience"}}),
		AdConfig.BuildType.RELEASE), "teen_ad_treatment_resolved": false})
	var child: Dictionary = _gate({"ad_config": _cfg(_real_release({"Audience": {"decision": "child_directed"}}),
		AdConfig.BuildType.RELEASE), "teen_ad_treatment_resolved": false})
	_c("fail-closed: mixed_audience -> CODE + ayrı UYUM (13–17 de hedefte); child_directed -> CODE, UYUM yok (yalnız 13 altı)",
		_blocked_by(mixed, "CODE", "mixed_audience") and _blocked_by(mixed, "OWNER", "UYUM:")
		and _blocked_by(child, "CODE", "child_directed") and not _blocked_by(child, "OWNER", "UYUM:"))
	_c("general_13_plus -> ürün kitlesi engeli yok; rapor notu kararı, eski etiketleri ve TEEN olmadıklarını gösterir; strateji notu",
		_notes_have(good, "ürün kitlesi kararı: general_13_plus (TFCD=unspecified, TFUA=unspecified — eski etiketler TEEN işlemi DEĞİL")
		and _notes_have(good, "13–17 genç reklam işlemi stratejisi: age_band_routing")
		and _notes_have(good, "hukuki garanti DEĞİL"))
	var teen: Dictionary = _gate({"teen_ad_treatment_resolved": false})
	_c("general_13_plus + genç reklam işlemi çözülmedi -> TEK engel: ayrı OWNER UYUM (13–17); 'kitle kararı yok' yok, CODE yok",
		_blocked_by(teen, "OWNER", ReleaseReadiness.TEEN_TREATMENT_BLOCKER) and teen["blockers"].size() == 1
		and not _blocked_by(teen, "OWNER", "kitle kararı yok") and not _has_category(teen, "CODE"))
	var legacy_inputs: Dictionary = _good_inputs()
	legacy_inputs.erase("teen_ad_treatment_resolved")
	_c("teen_ad_treatment_resolved girdisi yoksa -> fail-closed: UYUM engeli",
		_blocked_by(ReleaseReadiness.evaluate(legacy_inputs), "OWNER", "UYUM:"))
	var tags_not_teen: bool = true
	for tags: Dictionary in [
			{"tag_for_child_directed_treatment": "unspecified", "tag_for_under_age_of_consent": "unspecified"},
			{"tag_for_child_directed_treatment": "false", "tag_for_under_age_of_consent": "false"},
			{"tag_for_child_directed_treatment": "true", "tag_for_under_age_of_consent": "true"}]:
		var tagged: Dictionary = _gate({"ad_config": _cfg(_real_release({"Audience": tags}), AdConfig.BuildType.RELEASE),
			"teen_ad_treatment_resolved": false})
		tags_not_teen = tags_not_teen and _blocked_by(tagged, "OWNER", ReleaseReadiness.TEEN_TREATMENT_BLOCKER)
	_c("etiketler TEEN stratejisi yerine geçmez: TFCD/TFUA unspecified, false, true -> genç işlemi engeli kalır",
		tags_not_teen)
	_c("gizlilik politikası URL'i yok -> OWNER; http -> OWNER", _blocked_by(_gate({"privacy_policy_url": ""}), "OWNER", "gizlilik")
		and _blocked_by(_gate({"privacy_policy_url": "http://squishy.invalid"}), "OWNER", "https"))
	_c("yamasız eklenti AAR'ı -> CODE; yamasız cephe -> CODE",
		_blocked_by(_gate({"plugin_release_aar_sha256": "526516f93b1e29a6749b0293d86649bb7a6971603258a62e109dfd65afb36789"}),
			"CODE", "AAR") and _blocked_by(_gate({"plugin_facade_patched": false}), "CODE", "Admob.gd"))
	_c("bilinen eklenti kusuru -> CODE (tek engel; TASK/040)", _blocked_by(_gate({"plugin_known_defects": ["kusur-X"]}), "CODE", "kusur-X")
		and _gate({"plugin_known_defects": ["kusur-X"]})["blockers"].size() == 1)
	# TASK/041: kusur girdisi yoksa AAR SHA'sından türetilir (fail-closed).
	var fixed_inputs: Dictionary = _good_inputs()
	fixed_inputs.erase("plugin_known_defects")
	var fixed: Dictionary = ReleaseReadiness.evaluate(fixed_inputs)
	_c("onaylı TASK/042 AAR'ı (GMA 25.3.0 derlemesi) -> bilinen kusur YOK, CODE yok, UPLOAD_CANDIDATE (kusur SHA'dan türetildi)",
		ReleaseReadiness.known_plugin_defects(ReleaseReadiness.PATCHED_RELEASE_AAR_SHA256).is_empty()
		and fixed["status"] == ReleaseReadiness.STATUS_UPLOAD_CANDIDATE and not _has_category(fixed, "CODE"))
	var t041_inputs: Dictionary = _good_inputs()
	t041_inputs.erase("plugin_known_defects")
	t041_inputs["plugin_release_aar_sha256"] = TASK041_RELEASE_AAR_SHA256
	var t041: Dictionary = ReleaseReadiness.evaluate(t041_inputs)
	_c("TASK/041 AAR'ı (14c745e9…, GMA 24.9.0) sessizce geri gelemez -> CODE 'artık onaylı değil' (tek engel); kusur kaydı değil",
		_blocked_by(t041, "CODE", "artık onaylı değil") and _blocked_by(t041, "CODE", "GMA 25.3.0")
		and t041["blockers"].size() == 1 and ReleaseReadiness.known_plugin_defects(TASK041_RELEASE_AAR_SHA256).is_empty()
		and ReleaseReadiness.SUPERSEDED_RELEASE_AARS.has(TASK041_RELEASE_AAR_SHA256)
		and not ReleaseReadiness.SUPERSEDED_RELEASE_AARS.has(ReleaseReadiness.PATCHED_RELEASE_AAR_SHA256))
	_c("GMA sürüm şartı: 25.3.0 kabul; 24.9.0 / 25.4.0 / boş -> CODE (tam sürüm, fail-closed)",
		ReleaseReadiness.REQUIRED_GMA_VERSION == "25.3.0"
		and _blocked_by(_gate({"plugin_gma_version": "24.9.0"}), "CODE", "Google Mobile Ads SDK")
		and _blocked_by(_gate({"plugin_gma_version": "25.4.0"}), "CODE", "Google Mobile Ads SDK")
		and _blocked_by(_gate({"plugin_gma_version": ""}), "CODE", "Google Mobile Ads SDK"))
	var no_gma_inputs: Dictionary = _good_inputs()
	no_gma_inputs.erase("plugin_gma_version")
	var no_tfat_inputs: Dictionary = _good_inputs()
	no_tfat_inputs.erase("plugin_facade_tfat")
	_c("GMA sürümü / facade TFAT girdisi yoksa -> CODE (fail-closed); TFAT'sız cephe -> CODE",
		_blocked_by(ReleaseReadiness.evaluate(no_gma_inputs), "CODE", "Google Mobile Ads SDK")
		and _blocked_by(ReleaseReadiness.evaluate(no_tfat_inputs), "CODE", "TFAT")
		and _blocked_by(_gate({"plugin_facade_tfat": false}), "CODE", "TFAT"))
	_c("GMA sürümü üretilmiş AdmobPlugin.gd metninden: tek bağımlılık -> sürüm; yok / iki tane -> '' (fail-closed)",
		ReleaseReadiness.plugin_gma_version("[ \"a:b:1\", \"com.google.android.gms:play-services-ads:25.3.0\" ]") == "25.3.0"
		and ReleaseReadiness.plugin_gma_version("[ \"a:b:1\" ]") == ""
		and ReleaseReadiness.plugin_gma_version("\"com.google.android.gms:play-services-ads:25.3.0\", \"com.google.android.gms:play-services-ads:24.9.0\"") == "")
	var old_inputs: Dictionary = _good_inputs()
	old_inputs.erase("plugin_known_defects")
	old_inputs["plugin_release_aar_sha256"] = DEFECTIVE_M9_RELEASE_AAR_SHA256
	var old: Dictionary = ReleaseReadiness.evaluate(old_inputs)
	_c("eski kusurlu M9 AAR'ı (90d35992…) -> REDDEDİLİR: CODE RequestConfiguration kusuru + CODE onaylı derleme değil",
		_blocked_by(old, "CODE", "RequestConfiguration") and _blocked_by(old, "CODE", "AAR yamalı derleme değil")
		and ReleaseReadiness.known_plugin_defects(DEFECTIVE_M9_RELEASE_AAR_SHA256).size() == 1)
	var unknown: Dictionary = _gate({"plugin_release_aar_sha256": "0".repeat(64), "plugin_known_defects":
		ReleaseReadiness.known_plugin_defects("0".repeat(64))})
	_c("bilinmeyen / doğrulanmamış AAR (SHA eşleşmiyor) -> CODE (fail-closed); kusur kaydı olmasa da geçemez",
		_blocked_by(unknown, "CODE", "AAR yamalı derleme değil") and ReleaseReadiness.known_plugin_defects("0000").is_empty()
		and _gate({"plugin_release_aar_sha256": ""})["status"] == ReleaseReadiness.STATUS_BLOCKED)
	_c("kusur kuralı SİLİNMEDİ: eski SHA'nın RequestConfiguration kaydı duruyor; onaylı (GMA 25.3.0) SHA kayıtta DEĞİL",
		ReleaseReadiness.KNOWN_PLUGIN_DEFECTS.has(DEFECTIVE_M9_RELEASE_AAR_SHA256)
		and String(ReleaseReadiness.KNOWN_PLUGIN_DEFECTS[DEFECTIVE_M9_RELEASE_AAR_SHA256]).contains("RequestConfiguration")
		and not ReleaseReadiness.KNOWN_PLUGIN_DEFECTS.has(ReleaseReadiness.PATCHED_RELEASE_AAR_SHA256)
		and ReleaseReadiness.PATCHED_RELEASE_AAR_SHA256 != DEFECTIVE_M9_RELEASE_AAR_SHA256)
	_c("imzasız preset -> CONFIG (Play'e yüklenemez)", _blocked_by(_gate({"signed": false}), "CONFIG", "imzasız"))
	_c("upload anahtarı yok / dosya yok / debug anahtarı / takma ad-şifre yok -> OWNER",
		_blocked_by(_gate({"keystore_path_set": false}), "OWNER", "verilmedi")
		and _blocked_by(_gate({"keystore_exists": false}), "OWNER", "bulunamadı")
		and _blocked_by(_gate({"keystore_is_debug": true}), "OWNER", "DEBUG")
		and _blocked_by(_gate({"keystore_password_set": false}), "OWNER", "şifresi"))
	var np: Dictionary = _gate({"non_publishable_requested": true, "signed": false, "canonical_package_id": "",
		"export_path": "build/release/NOT_FOR_UPLOAD_squishy_merge_unsigned.aab"})
	_c("NON_PUBLISHABLE: istek + imzasız + yol NOT_FOR_UPLOAD -> NON_PUBLISHABLE (engeller raporda kalır)",
		np["status"] == ReleaseReadiness.STATUS_NON_PUBLISHABLE and not np["blockers"].is_empty())
	_c("NON_PUBLISHABLE isteği imzalı presette -> BLOCKED", _gate({"non_publishable_requested": true, "canonical_package_id": "",
		"export_path": "build/release/NOT_FOR_UPLOAD_x.aab"})["status"] == ReleaseReadiness.STATUS_BLOCKED)
	_c("NON_PUBLISHABLE isteği işaretsiz yolda -> BLOCKED", _gate({"non_publishable_requested": true, "signed": false,
		"export_path": "build/release/squishy_merge.aab"})["status"] == ReleaseReadiness.STATUS_BLOCKED)
	_c("istek yokken imzasız + işaretli yol yine BLOCKED (sessiz geçiş yok)", _gate({"signed": false,
		"export_path": "build/release/NOT_FOR_UPLOAD_x.aab"})["status"] == ReleaseReadiness.STATUS_BLOCKED)
	var debug: Dictionary = _gate({"build": "debug", "package_id": qa})
	_c("debug export'u (QA kimliği): kapı uygulanmaz (DEBUG, engel yok, uyarı yok — QA paketleri serbest)",
		debug["status"] == ReleaseReadiness.STATUS_DEBUG and debug["blockers"].is_empty() and not _notes_have(debug, "UYARI"))
	var debug_prod: Dictionary = _gate({"build": "debug"})
	_c("debug export'u ÜRETİM kimliğiyle: DEBUG kalır (build düşmez) ama rapor UYARI verir (Play sürümüyle çakışır)",
		debug_prod["status"] == ReleaseReadiness.STATUS_DEBUG and debug_prod["blockers"].is_empty()
		and _notes_have(debug_prod, "ÜRETİM kimliğiyle"))
	var text: String = ReleaseReadiness.report(_gate({"canonical_package_id": ""}), "t")
	_c("rapor: durum + kategori etiketleri + checklist notu", text.contains("BLOCKED") and text.contains("[OWNER]")
		and text.contains("ANDROID_RELEASE_CHECKLIST"))


# --- Bu projenin bugünkü durumu -----------------------------------------------------

func _test_current_project_state() -> void:
	print("-- bu proje bugün: tek kaynaklar + BLOCKED (upload-ready DEĞİL)")
	var canonical: String = String(ProjectSettings.get_setting(ReleaseReadiness.SETTING_PACKAGE_ID, ""))
	_c("project.godot: paket kimliği com.obappstudio.squishymerge (owner kararı, kalıcı), versionCode 1, versionName 0.8.5, gizlilik URL'i yok",
		canonical == "com.obappstudio.squishymerge"
		and int(ProjectSettings.get_setting(ReleaseReadiness.SETTING_VERSION_CODE, 0)) == 1
		and String(ProjectSettings.get_setting(ReleaseReadiness.SETTING_VERSION_NAME, "")) == "0.8.5"
		and String(ProjectSettings.get_setting(ReleaseReadiness.SETTING_PRIVACY_URL, "x")) == "")
	_c("QA / test kimliği com.obappstudio.squishymerge.qa — üretimden ayrı",
		ReleaseReadiness.qa_package_id(canonical) == "com.obappstudio.squishymerge.qa"
		and ReleaseReadiness.qa_package_id(canonical) != canonical)
	var preset: Dictionary = {"name": "Android Release AAB", "export_path": "build/release/squishy_merge.aab",
		"options": {"package/unique_name": "com.obappstudio.squishymerge", "version/code": 1, "version/name": "",
			"gradle_build/export_format": 1, "architectures/arm64-v8a": true, "gradle_build/target_sdk": "",
			"package/signed": true}}
	var inputs: Dictionary = ReleaseReadiness.project_inputs(preset, "release")
	var result: Dictionary = ReleaseReadiness.evaluate(inputs)
	print(ReleaseReadiness.report(result, "bugünkü proje"))
	_c("bugünkü proje BLOCKED", result["status"] == ReleaseReadiness.STATUS_BLOCKED)
	_c("paket kimliği engeli YOK: kanonik geçerli + release preset'i eşit; CONFIG engeli yok",
		not _blocked_by(result, "OWNER", "package id") and not _blocked_by(result, "OWNER", ReleaseReadiness.SETTING_PACKAGE_ID)
		and not _has_category(result, "CONFIG"))
	_c("kalan engeller: AdMob + gizlilik URL'i + upload anahtarı (hepsi OWNER)",
		_blocked_by(result, "OWNER", "AdMob") and _blocked_by(result, "OWNER", "gizlilik")
		and _blocked_by(result, "OWNER", "upload"))
	_c("ürün kitlesi engeli YOK (general_13_plus: ne 'kitle kararı yok' OWNER ne CODE); rapor kararı gösteriyor",
		not _blocked_by(result, "OWNER", "kitle kararı yok") and not _blocked_by(result, "CODE", "kitle kararı")
		and _notes_have(result, "ürün kitlesi kararı: general_13_plus"))
	_c("TASK/043: 13–17 genç reklam işlemi stratejisi kayda geçmedi (A36 kapısı öncesi) -> OWNER UYUM engeli; kod tablosu temiz",
		not bool(inputs["teen_ad_treatment_resolved"]) and _blocked_by(result, "OWNER", ReleaseReadiness.TEEN_TREATMENT_BLOCKER)
		and (inputs["age_routing_problems"] as PackedStringArray).is_empty())
	_c("TASK/043: yargı bölgesi yaş yükümlülükleri değerlendirmesi kayıtta değil -> ayrı OWNER UYUM engeli",
		not bool(inputs["jurisdiction_age_review_recorded"]) and _blocked_by(result, "OWNER", ReleaseReadiness.JURISDICTION_REVIEW_BLOCKER))
	_c("TASK/043: Play Uygunsuz Reklamlar — uygulamanın içerik derecesi kayıtta değil, yönlendirme T + MA -> ayrı OWNER UYUM engeli",
		inputs["app_content_rating"] == "" and inputs["routed_ad_content_ratings"] == ["T", "MA"]
		and _blocked_by(result, "OWNER", "UYUM (Play Uygunsuz Reklamlar)"))
	var owner_blockers: int = 0
	for blocker: Dictionary in result["blockers"]:
		if blocker["category"] == "OWNER":
			owner_blockers += 1
	var code_blockers: int = 0
	for blocker: Dictionary in result["blockers"]:
		if blocker["category"] == "CODE":
			code_blockers += 1
	_c("bugün tam 11 engel: OWNER 11 (AdMob 5 + gizlilik URL'i 1 + upload anahtarı 2 + 13–17 stratejisi 1 + yargı bölgesi 1 + uygulama içerik derecesi 1) + CODE 0 + CONFIG 0",
		owner_blockers == 11 and code_blockers == 0 and result["blockers"].size() == 11)
	_c("CODE engeli YOK (TASK/042): release AAR = onaylı GMA 25.3.0 derlemesi, bilinen kusur 0, eski kusurlu / TASK/041 SHA değil, cephe yamalı + TFAT, GMA 25.3.0",
		inputs["plugin_release_aar_sha256"] == ReleaseReadiness.PATCHED_RELEASE_AAR_SHA256
		and inputs["plugin_release_aar_sha256"] != DEFECTIVE_M9_RELEASE_AAR_SHA256
		and inputs["plugin_release_aar_sha256"] != TASK041_RELEASE_AAR_SHA256
		and bool(inputs["plugin_facade_patched"]) and bool(inputs["plugin_facade_tfat"])
		and inputs["plugin_gma_version"] == "25.3.0" and inputs["plugin_known_defects"].is_empty()
		and not _blocked_by(result, "CODE", "RequestConfiguration"))
	_c("sürüm tek kaynağı: preset versionCode 1 = project.godot 1, versionName boş → 0.8.5",
		int(inputs["version_code"]) == int(inputs["canonical_version_code"]) and inputs["version_name_preset"] == "")


static func _has_category(result: Dictionary, category: String) -> bool:
	for blocker: Dictionary in result["blockers"]:
		if blocker["category"] == category:
			return true
	return false


# --- Sır hijyeni --------------------------------------------------------------------

func _test_secret_hygiene() -> void:
	print("-- upload anahtarı sırları raporlara sızmaz")
	var keystore := FileAccess.open(TMP_KEYSTORE, FileAccess.WRITE)
	keystore.store_string("not-a-real-keystore")
	keystore.close()
	OS.set_environment("GODOT_ANDROID_KEYSTORE_RELEASE_PATH", ProjectSettings.globalize_path(TMP_KEYSTORE))
	OS.set_environment("GODOT_ANDROID_KEYSTORE_RELEASE_USER", "squishy-test-alias-77")
	OS.set_environment("GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD", "squishy-test-secret-9f3")
	var preset: Dictionary = {"name": "t", "export_path": "x.aab", "options": {"package/signed": true,
		"gradle_build/export_format": 1, "architectures/arm64-v8a": true}}
	var inputs: Dictionary = ReleaseReadiness.project_inputs(preset, "release")
	_c("ortam değişkenleri okunur: yol + varlık + takma ad/şifre 'dolu'", inputs["keystore_path_set"]
		and inputs["keystore_exists"] and inputs["keystore_user_set"] and inputs["keystore_password_set"]
		and not inputs["keystore_is_debug"])
	var text: String = ReleaseReadiness.report(ReleaseReadiness.evaluate(inputs), "sır")
	_c("rapor şifreyi ve takma adı İÇERMEZ", not text.contains("squishy-test-secret-9f3")
		and not text.contains("squishy-test-alias-77"))
	_c("girdiler şifreyi saklamaz (yalnız bool)", not var_to_str(inputs).contains("squishy-test-secret-9f3"))
	for key in KEYSTORE_ENV:
		OS.unset_environment(key)
	var ignore: String = FileAccess.get_file_as_string("res://.gitignore")
	_c(".gitignore: *.keystore / *.jks / keystore.properties / export_presets.cfg takip dışı",
		ignore.contains("*.keystore") and ignore.contains("*.jks") and ignore.contains("keystore.properties")
		and ignore.contains("export_presets.cfg"))


# --- UMP sarmalayıcıları: arayüz düzeyi ---------------------------------------------

func _test_wrapper_interface() -> void:
	print("-- UMP sarmalayıcıları (arayüz düzeyi)")
	var base := AdBackend.new()
	_c("AdBackend taban: API yok, canRequestAds false, durum UNKNOWN, sinyal tanımlı", not base.has_privacy_api()
		and not base.can_request_ads() and base.privacy_options_status() == AdBackend.PrivacyOptionsStatus.UNKNOWN
		and base.has_signal("privacy_options_form_dismissed"))
	var fake := FakeAdBackend.new()
	_c("FakeAdBackend (yamalı eklenti gibi): API var; update öncesi canRequestAds false (UMP)", fake.has_privacy_api()
		and not fake.can_request_ads())
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	fake.request_consent_update()
	_c("update sonrası NOT_REQUIRED -> canRequestAds true", fake.can_request_ads())
	fake.status = AdBackend.ConsentStatus.REQUIRED
	_c("REQUIRED -> canRequestAds false", not fake.can_request_ads())
	var got: Array = []
	fake.privacy_options_form_dismissed.connect(func(code: int, message: String) -> void: got.append([code, message]))
	fake.show_privacy_options_form()
	fake.dismiss_privacy_form(AdBackend.ConsentStatus.OBTAINED, 0, "")
	_c("showPrivacyOptionsForm -> kapanış sinyali (code, message) + yeni durum", fake.privacy_form_shows == 1
		and got == [[0, ""]] and fake.can_request_ads())
	var admob := Admob.new()
	_c("Admob.gd cephesi (yamalı): üç metot + has_privacy_options_api + sinyal",
		admob.has_method("can_request_ads") and admob.has_method("get_privacy_options_requirement_status")
		and admob.has_method("show_privacy_options_form") and admob.has_method("has_privacy_options_api")
		and admob.has_signal("privacy_options_form_dismissed"))
	_c("eklenti singleton'ı yokken (masaüstü) API 'yok' der — çağrı yapılmaz", not admob.has_privacy_options_api())
	_c("Admob.gd cephesi (TASK/042): age_restricted_treatment özelliği (varsayılan UNSPECIFIED) + get_applied_request_configuration()",
		"age_restricted_treatment" in admob and admob.has_method("get_applied_request_configuration")
		and admob.age_restricted_treatment == AdmobConfig.AgeRestrictedTreatment.UNSPECIFIED)
	admob.free()
	var backend_src: String = FileAccess.get_file_as_string("res://scripts/ads/admob_backend.gd")
	_c("AdmobBackend: API algısı sinyal kaydından, durum dizgesi eşlemesi, kapanış sinyali bağlı",
		backend_src.contains("_admob.has_privacy_options_api()") and backend_src.contains("\"REQUIRED\":")
		and backend_src.contains("\"NOT_REQUIRED\":")
		and backend_src.contains("_admob.privacy_options_form_dismissed.connect("))
	var manager_src: String = FileAccess.get_file_as_string("res://scripts/ads/monetization_manager.gd")
	_c("yönetici: izin kararı _sdk_can_request_ads, istek öncesi _request_permitted (SDK init + 3 yükleme)",
		manager_src.count("if not _request_permitted():") == 4 and manager_src.contains("_backend.can_request_ads()")
		and manager_src.contains("_backend.show_privacy_options_form()"))


# --- Commit edilmiş eklenti ikilileri ------------------------------------------------

func _test_patched_binaries() -> void:
	print("-- yamalı AAR'lar (commit edilmiş ikililer)")
	var version: String = FileAccess.get_file_as_string("res://addons/AdmobPlugin/VERSION.md")
	for kind in ["debug", "release"]:
		var path: String = "res://addons/AdmobPlugin/bin/%s/AdmobPlugin-%s.aar" % [kind, kind]
		var sha: String = FileAccess.get_sha256(path)
		_c("%s AAR SHA-256 VERSION.md'deki yamalı değer (%s…)" % [kind, sha.substr(0, 8)], version.contains(sha))
		var reader := ZIPReader.new()
		_c("%s AAR açıldı" % kind, reader.open(path) == OK)
		var jar: PackedByteArray = reader.read_file("classes.jar")
		reader.close()
		var out := FileAccess.open(TMP_JAR, FileAccess.WRITE)
		out.store_buffer(jar)
		out.close()
		var inner := ZIPReader.new()
		inner.open(TMP_JAR)
		var plugin_class: PackedByteArray = inner.read_file("org/godotengine/plugin/admob/AdmobPlugin.class")
		var consent_class: PackedByteArray = inner.read_file("org/godotengine/plugin/admob/model/ConsentConfiguration.class")
		var config_class: PackedByteArray = inner.read_file("org/godotengine/plugin/admob/model/AdmobConfiguration.class")
		var spike_hits: PackedStringArray = PackedStringArray()
		for entry in inner.get_files():
			if entry.ends_with(".class"):
				var bytes: PackedByteArray = inner.read_file(entry)
				for needle in ["TFAT_DIAG", "get_request_configuration_diagnostics", "configure_before_initialize"]:
					if _class_has(bytes, needle):
						spike_hits.append("%s (%s)" % [entry.get_file(), needle])
		inner.close()
		_c("%s AAR eski kusurlu M9 derlemesi DEĞİL, TASK/041 derlemesi DEĞİL (%s… ≠ %s… / %s… / %s… / %s…)" % [kind, sha.substr(0, 8),
				DEFECTIVE_M9_DEBUG_AAR_SHA256.substr(0, 8), DEFECTIVE_M9_RELEASE_AAR_SHA256.substr(0, 8),
				TASK041_DEBUG_AAR_SHA256.substr(0, 8), TASK041_RELEASE_AAR_SHA256.substr(0, 8)],
			sha != DEFECTIVE_M9_DEBUG_AAR_SHA256 and sha != DEFECTIVE_M9_RELEASE_AAR_SHA256
			and sha != TASK041_DEBUG_AAR_SHA256 and sha != TASK041_RELEASE_AAR_SHA256)
		_c("%s AdmobConfiguration.class Godot 4.6 Long / Object[] güvenli okuma İÇERİYOR (TASK/041 0002: instanceof Number + intValue + geçersiz değer logu)" % kind,
			not config_class.is_empty() and _class_has(config_class, "java/lang/Number")
			and _class_has(config_class, "intValue") and _class_has(config_class, "Invalid request configuration value '")
			and _class_has(config_class, "Skipping invalid test device id of type "))
		_c("%s AdmobPlugin.class set_request_configuration: istisna yutulmaz (NOT applied logu) + SDK geri okuması (applied satırı, yaş işlemi dahil)" % kind,
			_class_has(plugin_class, "set_request_configuration(): request configuration NOT applied")
			and _class_has(plugin_class, "set_request_configuration(): applied ")
			and _class_has(plugin_class, "max_ad_content_rating=") and _class_has(plugin_class, " age_restricted_treatment=")
			and _class_has(plugin_class, "getRequestConfiguration") and _class_has(plugin_class, "getAgeRestrictedTreatment"))
		_c("%s AdmobPlugin.class (TASK/042): get_applied_request_configuration() + MobileAds.initialize ÖNCESİ geri okuma logu + SDK sürümü" % kind,
			_class_has(plugin_class, "get_applied_request_configuration")
			and _class_has(plugin_class, "initialize(): request configuration before MobileAds.initialize ")
			and _class_has(plugin_class, "getVersion"))
		_c("%s AdmobConfiguration.class (TASK/042): setAgeRestrictedTreatment + UNSPECIFIED / CHILD / TEEN + age_restricted_treatment anahtarı" % kind,
			_class_has(config_class, "setAgeRestrictedTreatment")
			and _class_has(config_class, "com/google/android/gms/ads/AgeRestrictedTreatment")
			and _class_has_utf8(config_class, "UNSPECIFIED") and _class_has_utf8(config_class, "CHILD")
			and _class_has_utf8(config_class, "TEEN")
			and _class_has(config_class, "age_restricted_treatment"))
		_c("%s reklam kimliği (AAID) loglanmıyor: eski 'Added Advertising ID as test device: ' + değer satırı yok, yerine '(value not logged)'" % kind,
			not _class_has(config_class, "Added Advertising ID as test device: ")
			and _class_has(config_class, "Added Advertising ID as test device (value not logged)")
			and _class_has(config_class, " (values not logged)"))
		_c("%s spike tanısı üretime girmedi: TFAT_DIAG / get_request_configuration_diagnostics / configure_before_initialize YOK %s" % [kind, str(spike_hits)],
			spike_hits.is_empty())
		_c("%s AdmobPlugin.class: can_request_ads / get_privacy_options_requirement_status / show_privacy_options_form / sinyal" % kind,
			not jar.is_empty() and _class_has(plugin_class, "can_request_ads")
			and _class_has(plugin_class, "get_privacy_options_requirement_status")
			and _class_has(plugin_class, "show_privacy_options_form")
			and _class_has(plugin_class, "privacy_options_form_dismissed"))
		_c("%s AdmobPlugin.class UMP'nin gerçek çağrılarını içerir (canRequestAds / getPrivacyOptionsRequirementStatus / showPrivacyOptionsForm)" % kind,
			_class_has(plugin_class, "canRequestAds") and _class_has(plugin_class, "getPrivacyOptionsRequirementStatus")
			and _class_has(plugin_class, "showPrivacyOptionsForm"))
		_c("%s ConsentConfiguration.class: java/lang/Number (#120 düzeltmesi)" % kind,
			_class_has(consent_class, "java/lang/Number"))
	var patch_sha: String = FileAccess.get_sha256("res://tools/admob_plugin/0001-ump-privacy-options-and-debug-geography.patch")
	var config_patch_sha: String = FileAccess.get_sha256(CONFIG_PATCH)
	var gma25_patch_sha: String = FileAccess.get_sha256(GMA25_PATCH)
	var script: String = FileAccess.get_file_as_string("res://tools/admob_plugin/build_patched_plugin.sh")
	_c("yama SHA-256'ları (0001 + 0002 + 0003) VERSION.md ve yeniden derleme betiğiyle aynı", version.contains(patch_sha)
		and script.contains("PATCH_SHA256=\"%s\"" % patch_sha) and version.contains(config_patch_sha)
		and script.contains("CONFIG_PATCH_SHA256=\"%s\"" % config_patch_sha) and not gma25_patch_sha.is_empty()
		and version.contains(gma25_patch_sha) and script.contains("GMA25_PATCH_SHA256=\"%s\"" % gma25_patch_sha))
	var config_patch: String = FileAccess.get_file_as_string(CONFIG_PATCH)
	_c("0002 (üretim, TASK/041): yalnız AdmobPlugin.java + AdmobConfiguration.java; (int) / (String[]) dönüşümleri kalkıyor, Number / Object[] okuma geliyor",
		config_patch.count("diff --git ") == 2
		and config_patch.contains("-\t\treturn (int) _data.get(CHILD_DIRECTED_TREATMENT_PROPERTY);")
		and config_patch.contains("-\t\treturn (int) _data.get(UNDER_AGE_OF_CONSENT_PROPERTY);")
		and config_patch.contains("-\t\treturn (int) _data.get(PERSONALIZATION_STATE_PROPERTY);")
		and config_patch.contains("-\t\treturn (String[]) _data.get(TEST_DEVICE_IDS_PROPERTY);")
		and config_patch.contains("+\t\tif (value instanceof Number) {")
		and config_patch.contains("+\t\tif (!(value instanceof Object[])) {"))
	_c("0002 GMA 25 / UMP 4 / TFAT / TEEN İÇERMİYOR (sürüm satırı, AgeRestrictedTreatment, TFAT_DIAG, TEEN yok); GDScript'e dokunmuyor",
		not config_patch.contains("playads") and not config_patch.contains("AgeRestrictedTreatment")
		and not config_patch.contains("TFAT") and not config_patch.contains("TEEN") and not config_patch.contains(".gd b/"))
	var gma25_patch: String = FileAccess.get_file_as_string(GMA25_PATCH)
	_c("0003 (üretim, TASK/042): playads 24.9.0 -> 25.3.0, setAgeRestrictedTreatment, geri okuma API'si, AAID loglanmıyor; 5 dosya",
		gma25_patch.count("diff --git ") == 5
		and gma25_patch.contains("-playads = \"24.9.0\"") and gma25_patch.contains("+playads = \"25.3.0\"")
		and gma25_patch.contains("builder.setAgeRestrictedTreatment(ageTreatment == AgeRestrictedTreatment.UNSPECIFIED ? null : ageTreatment);")
		and gma25_patch.contains("+\tpublic Dictionary get_applied_request_configuration() {")
		and gma25_patch.contains("+func get_applied_request_configuration() -> Dictionary:")
		and gma25_patch.contains("-\t\t\t\t\tLog.d(LOG_TAG, \"Added Advertising ID as test device: \" + adInfo.getId());"))
	_c("0003 TFAT eşlemesi tam: 0 UNSPECIFIED (SDK'ya null = ayarlanmamış varsayılan), 1 CHILD, 2 TEEN; bilinmeyen değer loglanır, uygulanmaz",
		gma25_patch.contains("+\t\t\tcase 0: return AgeRestrictedTreatment.UNSPECIFIED;")
		and gma25_patch.contains("+\t\t\tcase 1: return AgeRestrictedTreatment.CHILD;")
		and gma25_patch.contains("+\t\t\tcase 2: return AgeRestrictedTreatment.TEEN;")
		and gma25_patch.contains("builder.setAgeRestrictedTreatment(ageTreatment == AgeRestrictedTreatment.UNSPECIFIED ? null : ageTreatment);")
		and gma25_patch.contains("': unknown treatment \" + value + \" (not applied)\");"))
	_c("0003 0002'nin dönüşüm düzeltmesini geri ALMIYOR / tekrarlamıyor (getInt yeniden kullanılır; (int) / (String[]) dönüşümü yok); spike tanısı yok",
		not gma25_patch.contains("(int) _data.get(") and not gma25_patch.contains("(String[]) _data.get(")
		and not gma25_patch.contains("-\t\tif (value instanceof Number) {")
		and gma25_patch.contains("Integer value = getInt(AGE_RESTRICTED_TREATMENT_PROPERTY);")
		and not gma25_patch.contains("TFAT_DIAG") and not gma25_patch.contains("get_request_configuration_diagnostics")
		and not gma25_patch.contains("configure_before_initialize"))
	var retired: PackedStringArray = PackedStringArray()
	for path in RETIRED_SPIKE_FILES:
		if FileAccess.file_exists(path):
			retired.append(path)
	_c("derleme betiği: modlar verify / build / install / baseline, v6.0 + 0001 + 0002 + 0003, spike modu YOK; beklenen GMA 25.3.0 / UMP 4.0.0; AAR hash'leri betik = VERSION.md = kapı = diskteki AAR; eski spike dosyaları yok %s" % str(retired),
		script.contains("git -C \"$SRC\" apply \"$1\"")
		and script.contains("apply_patch \"$CONFIG_PATCH\" \"$CONFIG_PATCH_SHA256\" \"0002\"")
		and script.contains("apply_patch \"$GMA25_PATCH\" \"$GMA25_PATCH_SHA256\" \"0003\"")
		and script.contains("EXPECTED_GMA=\"25.3.0\"") and script.contains("EXPECTED_UMP=\"4.0.0\"")
		and script.contains("case \"$MODE\" in verify|build|install|baseline) ;;")
		and not script.contains("SPIKE_PATCH") and retired.is_empty()
		and script.contains("PATCHED_RELEASE_SHA256_WINDOWS=\"%s\"" % ReleaseReadiness.PATCHED_RELEASE_AAR_SHA256)
		and script.contains("PATCHED_DEBUG_SHA256_WINDOWS=\"%s\"" % FileAccess.get_sha256("res://addons/AdmobPlugin/bin/debug/AdmobPlugin-debug.aar"))
		and version.contains(ReleaseReadiness.PATCHED_RELEASE_AAR_SHA256)
		and FileAccess.get_sha256(ReleaseReadiness.PATCHED_RELEASE_AAR) == ReleaseReadiness.PATCHED_RELEASE_AAR_SHA256)
	var deps: String = FileAccess.get_file_as_string("res://addons/AdmobPlugin/AdmobPlugin.gd")
	_c("GMA 25.3.0 / UMP 4.0.0: tek reklam bağımlılığı play-services-ads:25.3.0 (UMP 4.0.0 play-services-ads-api:25.3.0'ın geçişlisi); 24.9.0 / UMP geçersiz kılma YOK; VERSION.md çözülmüş sürümleri yazıyor",
		deps.contains("\"com.google.android.gms:play-services-ads:25.3.0\"") and not deps.contains("play-services-ads:24")
		and ReleaseReadiness.plugin_gma_version(deps) == "25.3.0"
		and not deps.contains("user-messaging-platform") and version.contains("user-messaging-platform:4.0.0")
		and version.contains("play-services-ads-api:25.3.0")
		and script.contains("for artifact in play-services-ads play-services-ads-api user-messaging-platform; do")
		and script.contains("[ \"$got\" = \"$want \" ] || die"))


# --- TASK/040 + TASK/042: 13–17 genç reklam işlemi sınırları ---------------------------

## Kodla denetlenebilen kurallar (docs/monetization/GLOBAL_TEEN_AD_TREATMENT.md,
## AGE_BAND_ROUTING.md): Play Age Signals hiçbir reklam / runtime koduna bağlı değil; TASK/043
## ile yaş işlemi (TEEN / UNSPECIFIED) ve derece YALNIZ AgeGate.ad_route'tan, YALNIZ
## yöneticinin rota yolundan gelir; CHILD hiçbir banda verilmez; genç işlemi engeli owner
## kaydı + kod tablosu olmadan kapanmaz.
func _test_teen_treatment_boundaries() -> void:
	print("-- TASK/040 + TASK/042 + TASK/043: genç reklam işlemi sınırları (Age Signals YOK, TFAT yalnız yaş bandı rotasından, CHILD yok)")
	var hits: PackedStringArray = PackedStringArray()
	for root in ["res://scripts", "res://addons"]:
		for path in _files_under(root, ["gd", "cfg", "tscn", "tres"]):
			var lower: String = FileAccess.get_file_as_string(path).to_lower()
			for needle in ["agesignals", "age_signals", "age-signals", "agesignalsmanager"]:
				if lower.contains(needle):
					hits.append("%s (%s)" % [path, needle])
	var project_text: String = FileAccess.get_file_as_string("res://project.godot").to_lower()
	_c("Play Age Signals reklam / runtime koduna BAĞLI DEĞİL: scripts/ + addons/ + project.godot içinde yok %s" % str(hits),
		hits.is_empty() and not project_text.contains("age-signals") and not project_text.contains("agesignals"))
	var deps: String = FileAccess.get_file_as_string("res://addons/AdmobPlugin/AdmobPlugin.gd").to_lower()
	_c("Age Signals bağımlılığı YOK: eklentinin Android bağımlılıklarında com.google.android.play:age-signals yok",
		not deps.contains("age-signals") and not deps.contains("agesignals"))
	_c("rota verilmeden arka uç değerleri en muhafazakâr: UNSPECIFIED + G (AdBackend tabanı, FakeAdBackend, AdmobBackend, Admob.gd cephesi)",
		AdBackend.new().age_restricted_treatment() == AdBackend.AgeRestrictedTreatment.UNSPECIFIED
		and AdBackend.new().max_ad_content_rating() == "G" and FakeAdBackend.new().max_ad_content_rating() == "G"
		and AdmobBackend.new().max_ad_content_rating() == "G"
		and FakeAdBackend.new().age_restricted_treatment() == AdBackend.AgeRestrictedTreatment.UNSPECIFIED
		and AdmobBackend.new().age_restricted_treatment() == AdBackend.AgeRestrictedTreatment.UNSPECIFIED
		and _facade_default_treatment() == AdmobConfig.AgeRestrictedTreatment.UNSPECIFIED)
	# TASK/043: scripts/ içindeki set_age_restricted_treatment / set_max_ad_content_rating ÇAĞRISI
	# yalnız yöneticinin rota yolunda (AgeGate.ad_route değeri); TEEN sabiti yalnız arka ucun
	# eşlemesinde (_tfat) ve AgeGate'in tablosunda; CHILD yalnız _tfat eşlemesinde.
	var calls: PackedStringArray = PackedStringArray()
	var bad_calls: PackedStringArray = PackedStringArray()
	var teen_refs: PackedStringArray = PackedStringArray()
	for path in _files_under("res://scripts", ["gd"]):
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line: String = lines[i].strip_edges()
			if line.begins_with("#") or line.begins_with("##"):
				continue
			if line.contains("set_age_restricted_treatment(") and not line.begins_with("func ") \
					and not line.begins_with("static func "):
				calls.append("%s:%d" % [path.get_file(), i + 1])
				if not (path.ends_with("monetization_manager.gd") and line.contains("(route[\"treatment\"])")):
					bad_calls.append("%s:%d %s" % [path.get_file(), i + 1, line])
			if line.contains("set_max_ad_content_rating(") and not line.begins_with("func ") \
					and not line.begins_with("static func "):
				calls.append("%s:%d" % [path.get_file(), i + 1])
				if not (path.ends_with("monetization_manager.gd") and line.contains("(route[\"max_ad_content_rating\"])")):
					bad_calls.append("%s:%d %s" % [path.get_file(), i + 1, line])
			if line.contains("AgeRestrictedTreatment.TEEN") or line.contains("AgeRestrictedTreatment.CHILD"):
				teen_refs.append("%s:%d" % [path.get_file(), i + 1])
	_c("yaş işlemi + derece yalnız yöneticinin rota yolundan (_push_age_route: AgeGate.ad_route değeri) — başka çağrı YOK (%s) %s" % [str(calls), str(bad_calls)],
		calls.size() == 2 and bad_calls.is_empty())
	var admob_refs: int = 0
	var gate_refs: int = 0
	for ref in teen_refs:
		if ref.begins_with("admob_backend.gd:"):
			admob_refs += 1
		elif ref.begins_with("age_gate.gd:"):
			gate_refs += 1
	var gate_code: String = "\n".join(Array(FileAccess.get_file_as_string("res://scripts/game/age_gate.gd").split("\n")).filter(
		func(line: String) -> bool: return not line.strip_edges().begins_with("#")))
	_c("scripts/ içinde TEEN / CHILD sabiti yalnız AdmobBackend._tfat (4) + AgeGate tablosu (TEEN, 2); AgeGate'te CHILD YOK %s" % str(teen_refs),
		teen_refs.size() == 6 and admob_refs == 4 and gate_refs == 2 and not gate_code.contains("AgeRestrictedTreatment.CHILD"))
	var ad_config_src: String = FileAccess.get_file_as_string("res://scripts/ads/ad_config.gd").to_lower()
	var export_cfg: String = FileAccess.get_file_as_string("res://addons/AdmobPlugin/android_export.cfg").to_lower()
	_c("yaş işlemi yapılandırmadan gelmiyor (yaş bandından): android_export.cfg ve AdConfig'te age_restricted_treatment anahtarı yok",
		not ad_config_src.contains("age_restricted_treatment") and not export_cfg.contains("age_restricted_treatment"))
	var gate_src: String = FileAccess.get_file_as_string("res://tools/release/release_readiness.gd")
	_c("kapı genç işlemi engelini bayrakla kapatmıyor: project_inputs teen_treatment_resolved(ad_config) (owner kaydı + kod tablosu), 'teen_ad_treatment_resolved': true / false yazılı DEĞİL",
		gate_src.contains("\"teen_ad_treatment_resolved\": teen_treatment_resolved(ad_config),")
		and not gate_src.contains("\"teen_ad_treatment_resolved\": true") and not gate_src.contains("\"teen_ad_treatment_resolved\": false")
		and ReleaseReadiness.TEEN_TREATMENT_BLOCKER.contains("age_band_routing"))
	var harness_src: String = FileAccess.get_file_as_string("res://tools/ads_device.gd")
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd") + FileAccess.get_file_as_string("res://scenes/main.tscn")
	var harness: Script = load("res://tools/ads_device.gd")
	_c("QA sürücüsü yaş işlemini arka uca DOĞRUDAN vermez (TASK/042 `teen` / `tfat` kaldırıldı); yaş yalnız üretim yolundan (kayıt + panel); üretim sahnesi sürücüyü yüklemiyor",
		harness != null and harness.can_instantiate() and not harness_src.contains("set_age_restricted_treatment(") and not harness_src.contains("set_max_ad_content_rating(")
		and harness_src.contains("SaveManager.store_age_band(") and not main_src.contains("ads_device"))


func _facade_default_treatment() -> int:
	var admob := Admob.new()
	var value: int = admob.age_restricted_treatment
	admob.free()
	return value


# --- TASK/041 + TASK/042: üretim RequestConfiguration yolu -----------------------------

## Kodla denetlenebilen kısım: facade'ın Java'ya gönderdiği değerler (ve Godot tipleri —
## v6.0'ı bozan tam da bunlardı) + yapılandırmanın MobileAds.initialize() ÖNCESİ bir kez
## uygulanma sırası. Native geri okuma cihazda: "set_request_configuration(): applied …"
## ve "initialize(): request configuration before MobileAds.initialize …" logları.
func _test_request_configuration_path() -> void:
	print("-- TASK/041 + TASK/042: RequestConfiguration yolu (değerler aynı + TFAT UNSPECIFIED, SDK başlamadan ÖNCE bir kez)")
	var project := AdConfig.load_project()
	var admob := Admob.new()
	var adult: Dictionary = AgeGate.ad_route(AgeGate.Band.ADULT)
	var teen: Dictionary = AgeGate.ad_route(AgeGate.Band.TEEN)
	admob.is_real = project.is_real
	admob.child_directed = AdmobBackend._tfcd(project.tag_for_child_directed_treatment)
	admob.under_age_of_consent = AdmobBackend._tfua(project.tag_for_under_age_of_consent)
	admob.max_ad_content_rating = AdmobBackend._content_rating(adult["max_ad_content_rating"])
	admob.age_restricted_treatment = AdmobBackend._tfat(adult["treatment"])
	var raw: Dictionary = admob.create_request_configuration().get_raw_data()
	admob.max_ad_content_rating = AdmobBackend._content_rating(teen["max_ad_content_rating"])
	admob.age_restricted_treatment = AdmobBackend._tfat(teen["treatment"])
	var raw_teen: Dictionary = admob.create_request_configuration().get_raw_data()
	admob.age_restricted_treatment = AdmobBackend._tfat(AdBackend.AgeRestrictedTreatment.CHILD)
	var raw_child: Dictionary = admob.create_request_configuration().get_raw_data()
	admob.free()
	_c("ADULT rotası cepheden aynen: derece \"MA\", yaş işlemi 0 (UNSPECIFIED), TFCD -1 / TFUA -1, kişiselleştirme 0 (DEFAULT), is_real false (DEBUG), test_device_ids []",
		raw.get("max_ad_content_rating") == "MA" and raw.get("age_restricted_treatment") == 0
		and raw.get("tag_for_child_directed_treatment") == -1
		and raw.get("tag_for_under_age_of_consent") == -1 and raw.get("personalization_state") == 0
		and raw.get("is_real") == false and raw.get("test_device_ids") == [])
	_c("TEEN rotası cepheden aynen: yaş işlemi 2 (TEEN), derece \"T\"; CHILD eşlemesi 1 (Java ile aynı, hiçbir banda verilmez)",
		raw_teen.get("age_restricted_treatment") == 2 and raw_teen.get("max_ad_content_rating") == "T"
		and raw_child.get("age_restricted_treatment") == 1)
	_c("Godot tipleri (Java'da Long / Boolean / String / Object[]): TFCD, TFUA, kişiselleştirme, yaş işlemi int; is_real bool; derece String; test_device_ids Array",
		typeof(raw["tag_for_child_directed_treatment"]) == TYPE_INT and typeof(raw["tag_for_under_age_of_consent"]) == TYPE_INT
		and typeof(raw["personalization_state"]) == TYPE_INT and typeof(raw["age_restricted_treatment"]) == TYPE_INT
		and typeof(raw["is_real"]) == TYPE_BOOL
		and typeof(raw["max_ad_content_rating"]) == TYPE_STRING and typeof(raw["test_device_ids"]) == TYPE_ARRAY)
	var facade_src: String = FileAccess.get_file_as_string("res://addons/AdmobPlugin/Admob.gd")
	var backend_src: String = FileAccess.get_file_as_string("res://scripts/ads/admob_backend.gd")
	var manager_src: String = FileAccess.get_file_as_string("res://scripts/ads/monetization_manager.gd")
	_c("facade: set_request_configuration() create_request_configuration() ile AYNI yapıcıyı kullanır (gönderilen = test edilen)",
		facade_src.contains("\t\t\ta_config = create_request_configuration()\n\n\t\t_plugin_singleton.set_request_configuration(a_config.get_raw_data())"))
	_c("sıra (TASK/042): AdmobBackend.initialize() ÖNCE yapılandırır + geri okur, SONRA _admob.initialize(); doğrulanamazsa başlatmaz",
		backend_src.contains("func initialize() -> bool:\n\tif not _apply_request_configuration():\n")
		and backend_src.contains("\t\treturn false\n\t_admob.initialize()\n")
		and backend_src.count("_admob.initialize()") == 1
		and backend_src.contains("func _apply_request_configuration() -> bool:\n\t_admob.set_request_configuration()\n"))
	_c("tek yapılandırma yolu: facade SDK hazır sinyalinde YENİDEN uygulamaz (auto_configure_on_initialize = false); set_request_configuration yalnız _apply_request_configuration'da",
		backend_src.contains("_admob.auto_configure_on_initialize = false")
		and not backend_src.contains("_admob.auto_configure_on_initialize = true")
		and backend_src.count("_admob.set_request_configuration()") == 1)
	_c("sıra: yönetici SDK hazır sinyalinden önce hiçbir reklam yüklemez (_ads_enabled → _sdk_ready; _sdk_ready yalnız _on_initialization_completed'de true)",
		manager_src.contains("return _backend != null and ads_allowed() and _sdk_ready and _onboarding_completed")
		and manager_src.count("_sdk_ready = true") == 1
		and manager_src.contains("func _on_initialization_completed() -> void:\n\t_sdk_initializing = false\n\t_sdk_ready = true"))
	_c("SDK tek kez: _ensure_sdk ÖNCE yaş kapısı (TASK/043), sonra _sdk_ready / _sdk_initializing, yalnız _request_permitted() (UMP canRequestAds) iken, init'ten HEMEN önce rota doğrulaması (sapma -> oturum kapanır); tek initialize çağrısı",
		manager_src.contains("func _ensure_sdk() -> void:\n\tif not _consent_gate_open():\n\t\treturn")
		and manager_src.contains("\tif _sdk_ready or _sdk_initializing:\n\t\t_preload_rewarded()")
		and manager_src.contains("\tif not _request_permitted():\n\t\treturn\n")
		and manager_src.contains("\tif not _backend_matches_route(AgeGate.ad_route(_age_band)):\n\t\t_block_age_session()\n\t\treturn\n\t_sdk_initializing = true\n\tif not _backend.initialize():")
		and manager_src.find("\tif not _request_permitted():\n\t\treturn\n", manager_src.find("func _ensure_sdk()"))
			< manager_src.find("\tif not _backend_matches_route(AgeGate.ad_route(_age_band)):", manager_src.find("func _ensure_sdk()"))
		and manager_src.count("_backend.initialize()") == 1)
	_c("fail-closed yönetici: initialize() false -> _sdk_refused, başlatma bayrağı temizlenir, yeniden deneme yok, not 'kullanılamıyor'",
		manager_src.contains("\t\t_sdk_initializing = false\n\t\t_sdk_refused = true\n")
		and manager_src.contains("\tif _sdk_refused:\n\t\treturn\n\t# Google: Mobile Ads SDK yalnız canRequestAds() true iken başlatılır.")
		and manager_src.contains("if not _onboarding_completed or _sdk_refused:\n\t\treturn NOTE_UNAVAILABLE"))
	var gate_at: int = manager_src.find("func _open_age_gate() -> bool:")
	var push_at: int = manager_src.find("\tvar route: Dictionary = AgeGate.ad_route(_age_band)\n\tif not _push_age_route(route) or not _backend_matches_route(route):\n\t\t_block_age_session()\n\t\treturn false", gate_at)
	var attach_at: int = manager_src.find("_backend.attach(self)", gate_at)
	_c("TASK/043: rota (yaş işlemi + derece) attach'ten ÖNCE gönderilip arka uçtan geri doğrulanır (UMP öncesi), attach tek yerde (_open_age_gate), rıza _open_age_gate'ten SONRA",
		gate_at != -1 and push_at > gate_at and attach_at > push_at and manager_src.count("_backend.attach(self)") == 1
		and manager_src.contains("\t_open_age_gate()\n\t_compute_banner_slot()"))
	_c("TASK/043: yoldaki rıza sonucu / formu kapalı oturumda işlenmez (_resolve_consent kapı denetimi, STARTUP formu düşer)",
		manager_src.contains("\t_update_privacy_options()\n\tif not _consent_gate_open():\n")
		and manager_src.contains("\tif _form_purpose == FormPurpose.STARTUP and not _consent_gate_open():\n\t\t_form_purpose = FormPurpose.NONE")
		and manager_src.contains("\tif _form_purpose == FormPurpose.STARTUP:\n\t\t_form_purpose = FormPurpose.NONE"))


# --- TASK/042: TFAT arayüzü + geri okuma doğrulaması (sahte SDK) ------------------------

func _test_tfat_api() -> void:
	print("-- TASK/042: TFAT arayüzü (UNSPECIFIED / CHILD / TEEN) + geri okuma doğrulaması, fail-closed")
	_c("AdBackend.AgeRestrictedTreatment: UNSPECIFIED 0, CHILD 1, TEEN 2 (adlar SDK enum adları)",
		AdBackend.AgeRestrictedTreatment.keys() == ["UNSPECIFIED", "CHILD", "TEEN"]
		and AdBackend.AgeRestrictedTreatment.UNSPECIFIED == 0 and AdBackend.AgeRestrictedTreatment.TEEN == 2)
	_c("AdmobConfig.AgeRestrictedTreatment (cephe modeli): UNSPECIFIED 0, CHILD 1, TEEN 2; AdmobBackend._tfat birebir eşler",
		AdmobConfig.AgeRestrictedTreatment.UNSPECIFIED == 0 and AdmobConfig.AgeRestrictedTreatment.CHILD == 1
		and AdmobConfig.AgeRestrictedTreatment.TEEN == 2
		and AdmobBackend._tfat(AdBackend.AgeRestrictedTreatment.UNSPECIFIED) == AdmobConfig.AgeRestrictedTreatment.UNSPECIFIED
		and AdmobBackend._tfat(AdBackend.AgeRestrictedTreatment.CHILD) == AdmobConfig.AgeRestrictedTreatment.CHILD
		and AdmobBackend._tfat(AdBackend.AgeRestrictedTreatment.TEEN) == AdmobConfig.AgeRestrictedTreatment.TEEN)
	var expected: Dictionary = AdBackend.expected_request_configuration(AdBackend.AgeRestrictedTreatment.UNSPECIFIED, "G", -1, -1)
	_c("beklenen geri okuma: {UNSPECIFIED, G, -1, -1}", expected == {"age_restricted_treatment": "UNSPECIFIED",
		"max_ad_content_rating": "G", "tag_for_child_directed_treatment": -1, "tag_for_under_age_of_consent": -1})
	# Cihazdaki native geri okuma biçimi (Java Dictionary → Godot: String / int / bool).
	var native: Dictionary = {"age_restricted_treatment": "UNSPECIFIED", "max_ad_content_rating": "G",
		"tag_for_child_directed_treatment": -1, "tag_for_under_age_of_consent": -1, "personalization_state": "DEFAULT",
		"test_device_ids": 3, "sdk_version": "25.3.0", "initialized": false}
	var teen_native: Dictionary = native.duplicate()
	teen_native["age_restricted_treatment"] = "TEEN"
	var no_rating: Dictionary = native.duplicate()
	no_rating["max_ad_content_rating"] = ""
	_c("doğrulama: aynı -> ''; yaş işlemi farklı / derece uygulanmamış / geri okuma yok (eski eklenti) -> uyuşmazlık",
		AdBackend.request_configuration_problem(native, expected) == ""
		and AdBackend.request_configuration_problem(teen_native, expected).contains("age_restricted_treatment=TEEN")
		and AdBackend.request_configuration_problem(no_rating, expected).contains("max_ad_content_rating")
		and not AdBackend.request_configuration_problem({}, expected).is_empty()
		and AdBackend.request_configuration_problem(teen_native,
			AdBackend.expected_request_configuration(AdBackend.AgeRestrictedTreatment.TEEN, "G", -1, -1)) == "")
	var fake := FakeAdBackend.new()
	fake.initialize()
	var cfg_at: int = fake.calls.find("request_configuration:UNSPECIFIED:G")
	_c("sahte SDK: initialize = yapılandırma (rota yoksa UNSPECIFIED / G) + geri okuma, SONRA başlatma; geri okuma UNSPECIFIED / G",
		cfg_at != -1 and fake.calls.find("initialize") > cfg_at and fake.init_calls == 1
		and fake.applied_request_configuration()["age_restricted_treatment"] == "UNSPECIFIED"
		and fake.applied_request_configuration()["max_ad_content_rating"] == "G")
	var late_ok: bool = fake.set_age_restricted_treatment(AdBackend.AgeRestrictedTreatment.TEEN)
	var same_ok: bool = fake.set_age_restricted_treatment(AdBackend.AgeRestrictedTreatment.UNSPECIFIED)
	_c("SDK yapılandırıldıktan SONRA farklı yaş işlemi REDDEDİLİR (false), doğrulanmış yapılandırma kalır; aynı değer kabul",
		not late_ok and same_ok and fake.treatment_refusals == 1 and fake.request_configuration_applies == 1
		and fake.applied_request_configuration()["age_restricted_treatment"] == "UNSPECIFIED"
		and fake.age_restricted_treatment() == AdBackend.AgeRestrictedTreatment.UNSPECIFIED)
	var early := FakeAdBackend.new()
	var early_ok: bool = early.set_age_restricted_treatment(AdBackend.AgeRestrictedTreatment.TEEN)
	_c("SDK başlamadan verilen TEEN kabul edilir (true), henüz uygulanmaz; initialize onu başlatma ÖNCESİ uygular",
		early_ok and early.request_configuration_applies == 0)
	var early_started: bool = early.initialize()
	_c("... geri okuma TEEN, sonra başlatma (initialize true)", early_started
		and early.calls.find("request_configuration:TEEN:G") < early.calls.find("initialize")
		and early.calls.find("request_configuration:TEEN:G") != -1 and early.init_calls == 1
		and early.applied_request_configuration()["age_restricted_treatment"] == "TEEN")
	var bad := FakeAdBackend.new()
	bad.request_configuration_fault = true
	bad.set_age_restricted_treatment(AdBackend.AgeRestrictedTreatment.TEEN)
	var bad_started: bool = bad.initialize()
	_c("fail-closed: SDK TEEN'i uygulamazsa (geri okuma UNSPECIFIED) SDK BAŞLATILMAZ (initialize false)", not bad_started
		and bad.init_refusals == 1
		and bad.init_calls == 0 and bad.calls.has("initialize_refused") and not bad.calls.has("initialize"))
	var backend_src: String = FileAccess.get_file_as_string("res://scripts/ads/admob_backend.gd")
	_c("AdmobBackend: beklenen = cephenin gönderdiği derece / TFCD / TFUA + yaş işlemi; uyuşmazlık push_error ile görünür, initialize false",
		backend_src.contains("expected_request_configuration(_age_restricted_treatment,")
		and backend_src.contains("request_configuration_problem(_admob.get_applied_request_configuration(), expected)")
		and backend_src.contains("push_error(\"AdmobBackend: istek yapılandırması doğrulanamadı")
		and backend_src.contains("\t\treturn false\n\t_admob.initialize()\n\treturn true\n"))
	_c("AdmobBackend: SDK yapılandırıldıktan sonra yaş işlemi değişikliği reddedilir (yeniden uygulama yolu YOK)",
		backend_src.contains("\tif _request_configured:\n\t\tif value == _age_restricted_treatment:\n\t\t\treturn true\n")
		and backend_src.count("_apply_request_configuration()") == 2)
	# TASK/043: en yüksek derece aynı kilitle.
	var rated := FakeAdBackend.new()
	var rate_early: bool = rated.set_max_ad_content_rating("T")
	var rate_bad: bool = rated.set_max_ad_content_rating("X")
	rated.initialize()
	var rate_late: bool = rated.set_max_ad_content_rating("MA")
	var rate_same: bool = rated.set_max_ad_content_rating("T")
	_c("TASK/043 derece kilidi (sahte SDK): SDK öncesi T kabul, geçersiz X ret; yapılandırma T; sonra MA ret, aynı T kabul",
		rate_early and not rate_bad and not rate_late and rate_same and rated.rating == "T"
		and rated.applied_request_configuration()["max_ad_content_rating"] == "T" and rated.request_configured())
	_c("AdmobBackend: derece yalnız G / PG / T / MA; SDK yapılandırıldıktan sonra farklı derece reddedilir; request_configured() bayrağı",
		backend_src.contains("func set_max_ad_content_rating(value: String) -> bool:\n\tif not AdConfig.CONTENT_RATINGS.has(value):")
		and backend_src.contains("\tif _request_configured:\n\t\tif value == _max_ad_content_rating:\n\t\t\treturn true\n")
		and backend_src.contains("func request_configured() -> bool:\n\treturn _request_configured")
		and backend_src.contains("_admob.max_ad_content_rating = _content_rating(_max_ad_content_rating)")
		and not backend_src.contains("_config.max_ad_content_rating"))


# --- TASK/043: yaş bandı yönlendirmesi + kapı kuralları ---------------------------------

func _test_age_band_routing_gate() -> void:
	print("-- TASK/043: yaş bandı yönlendirme tablosu + kapı (strateji kaydı, yargı bölgesi, Play Uygunsuz Reklamlar)")
	_c("kod tablosu owner tablosuyla birebir (AgeGate.routing_contract_problems boş)",
		AgeGate.routing_contract_problems().is_empty())
	_c("yönlendirmenin reklam dereceleri: TEEN T + ADULT MA", ReleaseReadiness.routed_ad_content_ratings() == ["T", "MA"])
	_c("teen_treatment_resolved: kayıt yok -> false; 'age_band_routing' -> true (kod tablosu temizken); config yok -> false",
		not ReleaseReadiness.teen_treatment_resolved(_cfg(_real_release(), AdConfig.BuildType.RELEASE))
		and ReleaseReadiness.teen_treatment_resolved(_cfg(_real_release({"Audience": {"teen_ad_treatment": "age_band_routing"}}),
			AdConfig.BuildType.RELEASE))
		and not ReleaseReadiness.teen_treatment_resolved(null))
	var no_review: Dictionary = _gate({"jurisdiction_age_review_recorded": false})
	var review_missing: Dictionary = _good_inputs()
	review_missing.erase("jurisdiction_age_review_recorded")
	_c("yargı bölgesi değerlendirmesi kayıtta değil / girdi yok -> TEK engel OWNER UYUM (Brezilya Digital ECA, ABD eyalet, AB rıza yaşı, Families)",
		_blocked_by(no_review, "OWNER", ReleaseReadiness.JURISDICTION_REVIEW_BLOCKER) and no_review["blockers"].size() == 1
		and _blocked_by(ReleaseReadiness.evaluate(review_missing), "OWNER", ReleaseReadiness.JURISDICTION_REVIEW_BLOCKER)
		and ReleaseReadiness.JURISDICTION_REVIEW_BLOCKER.contains("Digital ECA")
		and ReleaseReadiness.JURISDICTION_REVIEW_BLOCKER.contains("Age Signals reklamda ASLA"))
	var routing_bad: Dictionary = _gate({"age_routing_problems": ["TEEN -> TFAT TEEN + derece T olmalı"]})
	var routing_missing: Dictionary = _good_inputs()
	routing_missing.erase("age_routing_problems")
	_c("kod tablosu sapması -> CODE; girdi yoksa CODE (fail-closed)", _blocked_by(routing_bad, "CODE", "owner tablosundan sapıyor")
		and _blocked_by(ReleaseReadiness.evaluate(routing_missing), "CODE", "denetlenemedi"))
	_c("Play Uygunsuz Reklamlar: içerik derecesi kayıtta yok -> OWNER; 3+ / 7+ / 12+ (MA 16+ ister) -> OWNER; 16+ / 18+ -> engel yok",
		_blocked_by(_gate({"app_content_rating": ""}), "OWNER", "kayda geçmedi")
		and _blocked_by(_gate({"app_content_rating": "3+"}), "OWNER", "UYUM (Play Uygunsuz Reklamlar): uygulamanın Play içerik derecesi 3+")
		and _blocked_by(_gate({"app_content_rating": "7+"}), "OWNER", "Uygunsuz Reklamlar")
		and _blocked_by(_gate({"app_content_rating": "12+"}), "OWNER", "en az 16+")
		and _gate({"app_content_rating": "16+"})["status"] == ReleaseReadiness.STATUS_UPLOAD_CANDIDATE
		and _gate({"app_content_rating": "18+"})["status"] == ReleaseReadiness.STATUS_UPLOAD_CANDIDATE)
	_c("derece tablosu (AdMob dijital içerik etiketi ↔ Play): G 3+, PG 7+, T 12+, MA 16+; yalnız T -> 12+ yeter; G -> her derece",
		ReleaseReadiness.AD_RATING_MIN_APP_RATING == {"G": "3+", "PG": "7+", "T": "12+", "MA": "16+"}
		and ReleaseReadiness.ad_content_rating_problem("12+", ["T"]) == ""
		and ReleaseReadiness.ad_content_rating_problem("3+", ["G"]) == ""
		and not ReleaseReadiness.ad_content_rating_problem("7+", ["T"]).is_empty()
		and not ReleaseReadiness.ad_content_rating_problem("", ["G", "PG"]).is_empty())
	var rated_missing: Dictionary = _good_inputs()
	rated_missing.erase("routed_ad_content_ratings")
	rated_missing["app_content_rating"] = "12+"
	_c("fail-closed: yönlendirme dereceleri girdisi yoksa MA sayılır; tanınmayan reklam derecesi MA; tanınmayan uygulama derecesi engel",
		_blocked_by(ReleaseReadiness.evaluate(rated_missing), "OWNER", "Uygunsuz Reklamlar")
		and not ReleaseReadiness.ad_content_rating_problem("12+", ["Z"]).is_empty()
		and not ReleaseReadiness.ad_content_rating_problem("PEGI 3", ["T"]).is_empty())
	var all_open: Dictionary = _gate({"teen_ad_treatment_resolved": false, "jurisdiction_age_review_recorded": false,
		"app_content_rating": ""})
	_c("üç UYUM engeli birbirinden bağımsız ve hepsi OWNER (strateji + yargı bölgesi + içerik derecesi)",
		all_open["blockers"].size() == 3 and not _has_category(all_open, "CODE") and not _has_category(all_open, "CONFIG"))
	var export_cfg := ConfigFile.new()
	export_cfg.load(AdConfig.CONFIG_PATH)
	_c("android_export.cfg: teen_ad_treatment / app_content_rating / jurisdiction_age_review anahtarları var (owner kayıtları), max_ad_content_rating YOK",
		export_cfg.has_section_key("Audience", "teen_ad_treatment") and export_cfg.has_section_key("Audience", "app_content_rating")
		and export_cfg.has_section_key("Audience", "jurisdiction_age_review")
		and not export_cfg.has_section_key("Audience", "max_ad_content_rating"))
	var gate_src: String = FileAccess.get_file_as_string("res://tools/release/release_readiness.gd")
	_c("kapı yaş kodunu yalnız saf tablolardan okur (AgeGate autoload'a dokunmaz — export eklentisinde de derlenir)",
		gate_src.contains("AgeGate.routing_contract_problems()") and gate_src.contains("AgeGate.ad_route(band)")
		and not FileAccess.get_file_as_string("res://scripts/game/age_gate.gd").contains("SaveManager."))


static func _files_under(root: String, extensions: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for file in dir.get_files():
		if extensions.has(file.get_extension()):
			out.append(root.path_join(file))
	for sub in dir.get_directories():
		out.append_array(_files_under(root.path_join(sub), extensions))
	return out


## Sınıf dosyası sabit havuzundaki UTF-8 adlar (NUL içerdiği için bayt araması).
static func _class_has(bytes: PackedByteArray, needle: String) -> bool:
	return _find_bytes(bytes, needle.to_utf8_buffer())


## Sabit havuzunda TAM olarak bu dizge olan bir CONSTANT_Utf8 girdisi (etiket 0x01 + u2 uzunluk):
## "CHILD" araması "CHILD_DIRECTED_TREATMENT_PROPERTY" ile eşleşemez.
static func _class_has_utf8(bytes: PackedByteArray, value: String) -> bool:
	var body: PackedByteArray = value.to_utf8_buffer()
	var entry := PackedByteArray([1, (body.size() >> 8) & 0xff, body.size() & 0xff])
	entry.append_array(body)
	return _find_bytes(bytes, entry)


static func _find_bytes(haystack: PackedByteArray, needle: PackedByteArray) -> bool:
	var n: int = needle.size()
	var i: int = haystack.find(needle[0])
	while i != -1 and i + n <= haystack.size():
		if haystack.slice(i, i + n) == needle:
			return true
		i = haystack.find(needle[0], i + 1)
	return false


# --- Ayarlar: gizlilik politikası satırı ---------------------------------------------

func _test_privacy_policy_row() -> void:
	print("-- Ayarlar: 'Gizlilik politikası' satırı (URL owner'da)")
	var original: Variant = ProjectSettings.get_setting(ReleaseReadiness.SETTING_PRIVACY_URL, "")
	var settings: CanvasLayer = (load(SETTINGS_SCENE) as PackedScene).instantiate()
	add_child(settings)
	await get_tree().process_frame
	settings.open_panel()
	await get_tree().process_frame
	await get_tree().process_frame
	_c("URL yok -> satır GİZLİ (sahte bağlantı yok)", not settings.privacy_policy_row().visible)
	ProjectSettings.set_setting(ReleaseReadiness.SETTING_PRIVACY_URL, "https://squishy.invalid/privacy")
	settings.close_panel()
	settings.open_panel()
	await get_tree().process_frame
	await get_tree().process_frame
	var frame: Control = settings.frame()
	var row: HBoxContainer = settings.privacy_policy_row()
	_c("https URL -> satır GÖRÜNÜR, 'Aç' butonu", row.visible and settings.privacy_policy_url() == "https://squishy.invalid/privacy")
	var scroll: ScrollContainer = frame.get_meta(&"scroll")
	_c("satır pencere gövdesinin içinde (taşma yok)", scroll.get_global_rect().grow(1.0).encloses(row.get_global_rect())
		or scroll.get_v_scroll_bar().visible)
	ProjectSettings.set_setting(ReleaseReadiness.SETTING_PRIVACY_URL, "http://squishy.invalid/privacy")
	settings.close_panel()
	settings.open_panel()
	await get_tree().process_frame
	_c("https olmayan URL -> satır GİZLİ", not settings.privacy_policy_row().visible and settings.privacy_policy_url() == "")
	settings.close_panel()
	ProjectSettings.set_setting(ReleaseReadiness.SETTING_PRIVACY_URL, original)
	settings.queue_free()
	await get_tree().process_frame
	_c("proje ayarı geri kondu (diske yazılmadı)", String(ProjectSettings.get_setting(ReleaseReadiness.SETTING_PRIVACY_URL, "x")) == "")
