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
##   - Ayarlar'daki "Gizlilik politikası" satırı (URL yokken gizli)
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
	_c("reklam etiketleri korunuyor: TFCD unspecified, TFUA unspecified, derece G (M8.9 değerleri)",
		project.tag_for_child_directed_treatment == "unspecified"
		and project.tag_for_under_age_of_consent == "unspecified" and project.max_ad_content_rating == "G")
	_c("projenin değerleri SDK'ya aynen: TFCD/TFUA UNSPECIFIED (gönderilmez — TEEN DEĞİL), derece G",
		AdmobBackend._tfcd(project.tag_for_child_directed_treatment) == AdmobConfig.TagForChildDirectedTreatment.UNSPECIFIED
		and AdmobBackend._tfua(project.tag_for_under_age_of_consent) == AdmobConfig.TagForUnderAgeOfConsent.UNSPECIFIED
		and AdmobBackend._content_rating(project.max_ad_content_rating) == AdmobConfig.ContentRating.G)
	var plugin_api: String = FileAccess.get_file_as_string("res://addons/AdmobPlugin/Admob.gd") \
		+ FileAccess.get_file_as_string("res://addons/AdmobPlugin/model/AdmobConfig.gd")
	_c("GMA 24.9.0 yolu TEEN ifade edemez: TFCD/TFUA enumlarında TEEN yok, eklentide AgeRestrictedTreatment API'si yok, bağımlılık 24.9.0 (TFAT 25.3.0+)",
		not AdmobConfig.TagForChildDirectedTreatment.has("TEEN") and not AdmobConfig.TagForUnderAgeOfConsent.has("TEEN")
		and not plugin_api.contains("AgeRestrictedTreatment") and not plugin_api.to_lower().contains("age_restricted_treatment")
		and FileAccess.get_file_as_string("res://addons/AdmobPlugin/AdmobPlugin.gd").contains("com.google.android.gms:play-services-ads:24.9.0"))
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
	_c("geçersiz TFCD / derece / karar -> yapılandırma GEÇERSİZ",
		not _cfg({"Audience": {"tag_for_child_directed_treatment": "maybe"}}, AdConfig.BuildType.DEBUG).is_valid()
		and not _cfg({"Audience": {"max_ad_content_rating": "X"}}, AdConfig.BuildType.DEBUG).is_valid()
		and not _cfg({"Audience": {"decision": "kids"}}, AdConfig.BuildType.DEBUG).is_valid())
	var decided := _cfg(_real_release({"Audience": {"tag_for_child_directed_treatment": "false",
		"tag_for_under_age_of_consent": "false", "max_ad_content_rating": "pg"}}), AdConfig.BuildType.RELEASE)
	_c("owner kararı kayda geçince değerler okunur (derece büyük harfe)", decided.is_valid()
		and decided.audience_decision == "general_13_plus" and decided.tag_for_child_directed_treatment == "false"
		and decided.max_ad_content_rating == "PG")


# --- ReleaseReadiness kuralları ------------------------------------------------------

## "Her şey tamam" girdileri. `teen_ad_treatment_resolved = true` ve
## `plugin_known_defects = []` GELECEĞİ modeller (13–17 genç reklam işlemi stratejisi
## seçilmiş + uygulanmış; RequestConfiguration kusuru düzeltilmiş eklenti derlemesi);
## bugünkü projede ikisi de açık.
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
		"teen_ad_treatment_resolved": true, "plugin_known_defects": [],
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
	_c("general_13_plus -> ürün kitlesi engeli yok; rapor notu kararı, etiketleri ve TEEN olmadıklarını gösterir",
		_notes_have(good, "ürün kitlesi kararı: general_13_plus (TFCD=unspecified, TFUA=unspecified, en yüksek reklam derecesi G — bunlar TEEN işlemi DEĞİL)"))
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
			{"tag_for_child_directed_treatment": "unspecified", "tag_for_under_age_of_consent": "unspecified", "max_ad_content_rating": "G"},
			{"tag_for_child_directed_treatment": "false", "tag_for_under_age_of_consent": "false", "max_ad_content_rating": "G"},
			{"tag_for_child_directed_treatment": "true", "tag_for_under_age_of_consent": "true", "max_ad_content_rating": "G"},
			{"tag_for_child_directed_treatment": "unspecified", "tag_for_under_age_of_consent": "unspecified", "max_ad_content_rating": "T"}]:
		var tagged: Dictionary = _gate({"ad_config": _cfg(_real_release({"Audience": tags}), AdConfig.BuildType.RELEASE),
			"teen_ad_treatment_resolved": false})
		tags_not_teen = tags_not_teen and _blocked_by(tagged, "OWNER", "UYUM:")
	_c("etiketler TEEN yerine geçmez: TFCD/TFUA unspecified, false, true ya da derece T (Teen İÇERİK derecesi) -> UYUM engeli kalır",
		tags_not_teen)
	_c("gizlilik politikası URL'i yok -> OWNER; http -> OWNER", _blocked_by(_gate({"privacy_policy_url": ""}), "OWNER", "gizlilik")
		and _blocked_by(_gate({"privacy_policy_url": "http://squishy.invalid"}), "OWNER", "https"))
	_c("yamasız eklenti AAR'ı -> CODE; yamasız cephe -> CODE",
		_blocked_by(_gate({"plugin_release_aar_sha256": "526516f93b1e29a6749b0293d86649bb7a6971603258a62e109dfd65afb36789"}),
			"CODE", "AAR") and _blocked_by(_gate({"plugin_facade_patched": false}), "CODE", "Admob.gd"))
	_c("bilinen eklenti kusuru -> CODE (tek engel; TASK/040)", _blocked_by(_gate({"plugin_known_defects": ["kusur-X"]}), "CODE", "kusur-X")
		and _gate({"plugin_known_defects": ["kusur-X"]})["blockers"].size() == 1)
	var defect_inputs: Dictionary = _good_inputs()
	defect_inputs.erase("plugin_known_defects")
	_c("kusur girdisi yoksa AAR SHA'sından türetilir (fail-closed): onaylı M9 AAR -> CODE RequestConfiguration",
		_blocked_by(ReleaseReadiness.evaluate(defect_inputs), "CODE", "RequestConfiguration")
		and ReleaseReadiness.known_plugin_defects("0000").is_empty())
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
	_c("ayrı OWNER UYUM engeli VAR: 13–17 genç reklam işlemi / yargı bölgesi stratejisi AÇIK (project_inputs: çözülmedi)",
		not bool(inputs["teen_ad_treatment_resolved"]) and _blocked_by(result, "OWNER", ReleaseReadiness.TEEN_TREATMENT_BLOCKER))
	var owner_blockers: int = 0
	for blocker: Dictionary in result["blockers"]:
		if blocker["category"] == "OWNER":
			owner_blockers += 1
	var code_blockers: int = 0
	for blocker: Dictionary in result["blockers"]:
		if blocker["category"] == "CODE":
			code_blockers += 1
	_c("bugün tam 10 engel: OWNER 9 (AdMob 5 + gizlilik URL'i 1 + upload anahtarı 2 + 13–17 uyum 1) + CODE 1",
		owner_blockers == 9 and code_blockers == 1 and result["blockers"].size() == 10)
	_c("tek CODE engeli bilinen RequestConfiguration kusuru (TASK/040 A36); yamalı AAR + cephe yerinde",
		inputs["plugin_release_aar_sha256"] == ReleaseReadiness.PATCHED_RELEASE_AAR_SHA256
		and bool(inputs["plugin_facade_patched"]) and inputs["plugin_known_defects"].size() == 1
		and _blocked_by(result, "CODE", "RequestConfiguration"))
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
		inner.close()
		_c("%s AdmobConfiguration.class Number / Object[] güvenli dönüşüm İÇERMİYOR — TASK/040 bilinen kusuru bu AAR'da (kapı CODE)" % kind,
			not config_class.is_empty() and not _class_has(config_class, "java/lang/Number")
			and _class_has(config_class, "java/lang/Integer"))
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
	var script: String = FileAccess.get_file_as_string("res://tools/admob_plugin/build_patched_plugin.sh")
	_c("yama SHA-256'sı VERSION.md ve yeniden derleme betiğiyle aynı", version.contains(patch_sha)
		and script.contains("PATCH_SHA256=\"%s\"" % patch_sha))
	_c("GMA / UMP sürümleri değişmedi (24.9.0 / eklentinin bağımlılık listesi)",
		FileAccess.get_file_as_string("res://addons/AdmobPlugin/AdmobPlugin.gd").contains("com.google.android.gms:play-services-ads:24.9.0"))


# --- TASK/040: 13–17 genç reklam işlemi sınırları -------------------------------------

## Kodla denetlenebilen TASK/040 kuralları (docs/monetization/GLOBAL_TEEN_AD_TREATMENT.md):
## Play Age Signals hiçbir reklam / runtime koduna bağlı değil; GMA 25.3.0 TEEN spike'ı
## üretim eklentisine GİRMEDİ; genç işlemi engeli yapılandırmayla kapanmıyor; spike
## yalnız yama + QA araçları olarak duruyor.
func _test_teen_treatment_boundaries() -> void:
	print("-- TASK/040: genç reklam işlemi sınırları (Age Signals YOK, spike üretime girmedi)")
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
	var facade: String = FileAccess.get_file_as_string("res://addons/AdmobPlugin/Admob.gd")
	var model: String = FileAccess.get_file_as_string("res://addons/AdmobPlugin/model/AdmobConfig.gd")
	var ads_src: String = ""
	for path in _files_under("res://scripts/ads", ["gd"]):
		ads_src += FileAccess.get_file_as_string(path)
	_c("üretim eklentisi GMA 24.9.0 kaldı: facade / model / scripts/ads içinde age_restricted_treatment YOK (spike üretime girmedi)",
		not facade.contains("age_restricted_treatment") and not model.contains("AgeRestrictedTreatment")
		and not ads_src.contains("age_restricted_treatment")
		and FileAccess.get_file_as_string("res://addons/AdmobPlugin/AdmobPlugin.gd").contains("play-services-ads:24.9.0"))
	var gate_src: String = FileAccess.get_file_as_string("res://tools/release/release_readiness.gd")
	_c("kapı genç işlemi engelini kapatmıyor: project_inputs teen_ad_treatment_resolved = false, true yazılı değil",
		gate_src.contains("\"teen_ad_treatment_resolved\": false,") and not gate_src.contains("\"teen_ad_treatment_resolved\": true"))
	var spike_patch: String = "res://tools/admob_plugin/0002-spike-gma25-age-restricted-treatment.patch"
	var build_script: String = FileAccess.get_file_as_string("res://tools/admob_plugin/build_patched_plugin.sh")
	var patch_text: String = FileAccess.get_file_as_string(spike_patch)
	_c("spike yaması (GMA 25.3.0 + setAgeRestrictedTreatment + TFAT_DIAG) yalnız `spike` modunda, SHA-256 betikte sabit",
		patch_text.contains("+playads = \"25.3.0\"") and patch_text.contains("builder.setAgeRestrictedTreatment(ageTreatment)")
		and patch_text.contains("TFAT_DIAG")
		and build_script.contains("SPIKE_PATCH_SHA256=\"%s\"" % FileAccess.get_sha256(spike_patch))
		and build_script.contains("NOT installed; addons/AdmobPlugin stays GMA 24.9.0"))
	var harness: Script = load("res://tools/ads_device.gd")
	_c("QA sürücüsü (tools/ads_device.gd) üretim facade'ıyla derlenir; TEEN kancaları dinamik (yalnız spike eklentisinde çalışır)",
		harness != null and FileAccess.get_file_as_string("res://tools/ads_device.gd").contains("\"age_restricted_treatment\" in facade"))


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


static func _find_bytes(haystack: PackedByteArray, needle: PackedByteArray) -> bool:
	var n: int = needle.size()
	for i in haystack.size() - n + 1:
		if haystack[i] == needle[0] and haystack.slice(i, i + n) == needle:
			return true
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
