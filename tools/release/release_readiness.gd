class_name ReleaseReadiness
extends RefCounted
## Android release kapısı — TEK doğrulayıcı (M9-01). Üç yerden çağrılır:
##   - tools/release/release_check.tscn (pipeline'ın export ÖNCESİ kontrolü),
##   - addons/squishy_release (Godot'un release export'u; engel varsa build'i
##     bilerek düşürür — Godot 4.6.3'te export eklentisi export'u veto edemez),
##   - tools/release_config_test (deterministik testler).
## Girdiler düz değerlerdir (`inputs`), böylece testler sahte proje/preset
## kurmadan her kuralı sürer. Kod YALNIZ kodun görebildiğini denetler; Play
## Console ve hesap adımları docs/ANDROID_RELEASE_CHECKLIST.md'de.
##
## Sonuç: UPLOAD_CANDIDATE (hiç engel yok) · BLOCKED · NON_PUBLISHABLE (engeller
## var ama açıkça istenmiş, İMZASIZ, yolu NOT_FOR_UPLOAD içeren release biçimli
## AAB) · DEBUG (debug export'u — kapı uygulanmaz, yalnız bilgi).
##
## GİZLİLİK: anahtar deposu şifresi / takma adı yalnız "dolu mu" diye bakılır,
## hiçbir yere yazılmaz.
##
## Paket kimlikleri (owner kararı, 2026-09-24): üretim / Play = project.godot
## `squishy/release/android_package_id` (com.obappstudio.squishymerge); QA / test
## (debug TEST-reklam APK'sı, cihaz harness'ları) = üretim + QA_PACKAGE_SUFFIX
## (com.obappstudio.squishymerge.qa). QA kimliği asla release olamaz; üretim
## kimliğiyle yapılan debug export'u raporda uyarı verir (cihazda Play sürümüyle çakışır).
##
## Ürün kitlesi (owner kararı, 2026-09-25 — FİNAL, KAPALI): 13+ genel kitle, 13 yaş
## altı için tasarlanmadı → android_export.cfg [Audience] decision = general_13_plus
## (Play hedef yaş grupları 13–15 / 16–17 / 18+). Kapı fail-closed kalır: karar boşsa
## OWNER, kodu olmayan karar (karma / çocuk) CODE engeli; hazır karar rapora bilgi
## notu düşer (docs/monetization/AUDIENCE_DECISION.md §0).
## Ondan AYRI (düzeltme, 2026-09-25): 13–17'yi de hedefleyen kitlede genç reklam
## işlemi / yargı bölgesi uyum stratejisi AÇIK bir owner / uyum kararı → ayrı OWNER
## engeli ("UYUM:"). GMA 24.9.0'ın TFCD/TFUA yolunda TFAT TEEN'in karşılığı yok;
## TFCD/TFUA/derece değerleri bunu ÇÖZMEZ. Strateji seçilip uygulanana kadar engel
## yapılandırmayla kapanmaz (AUDIENCE_DECISION.md §2.2 — seçim + uygulama ayrı görev).

const CATEGORY_OWNER: String = "OWNER"
const CATEGORY_CONFIG: String = "CONFIG"
const CATEGORY_CODE: String = "CODE"

const STATUS_UPLOAD_CANDIDATE: String = "UPLOAD_CANDIDATE"
const STATUS_BLOCKED: String = "BLOCKED"
const STATUS_NON_PUBLISHABLE: String = "NON_PUBLISHABLE"
const STATUS_DEBUG: String = "DEBUG"

## project.godot tek kaynakları.
const SETTING_PACKAGE_ID: String = "squishy/release/android_package_id"
const SETTING_VERSION_CODE: String = "squishy/release/android_version_code"
const SETTING_PRIVACY_URL: String = "squishy/privacy/policy_url"
const SETTING_VERSION_NAME: String = "application/config/version"

## Geçici / yasaklı uygulama kimliği önekleri (Play com.example'ı kabul etmez;
## com.godot.game Godot'un varsayılanı).
const TEMPORARY_PACKAGE_PREFIXES: Array[String] = ["com.example.", "com.godot.", "org.godotengine."]
const PACKAGE_PATTERN: String = "^[a-zA-Z][a-zA-Z0-9_]*(\\.[a-zA-Z][a-zA-Z0-9_]*)+$"
## QA / test paketi = kalıcı kimlik + bu sonek; üretimle ÇAKIŞMAZ, release olamaz.
const QA_PACKAGE_SUFFIX: String = ".qa"
## Play hedef API şartı (yeni uygulama + güncelleme, 2026-08-31'den beri).
const MIN_TARGET_SDK: int = 36
## Godot 4.6.3 Gradle şablonunun varsayılanı (android/build/config.gradle).
const TEMPLATE_TARGET_SDK: int = 36
const FORMAT_AAB: int = 1
const NON_PUBLISHABLE_ENV: String = "SQUISHY_NON_PUBLISHABLE_RELEASE"
const NON_PUBLISHABLE_MARKER: String = "NOT_FOR_UPLOAD"
## Yamalı eklenti (tools/admob_plugin, addons/AdmobPlugin/VERSION.md).
const PATCHED_RELEASE_AAR: String = "res://addons/AdmobPlugin/bin/release/AdmobPlugin-release.aar"
const PATCHED_RELEASE_AAR_SHA256: String = "90d359921f10bc6618ed63b9ea97cdba5afcbdfbb8cb72fe264834e5bf478284"
const PATCHED_FACADE: String = "res://addons/AdmobPlugin/Admob.gd"
## Kitle kararlarından bu sürümde kodu HAZIR olan (AUDIENCE_DECISION.md).
const IMPLEMENTED_AUDIENCE_DECISIONS: Array[String] = ["general_13_plus"]
## 13–17 yaş kullanıcıları da hedefleyen kitle kararları: bunlarda genç reklam
## işlemi / yargı bölgesi uyum stratejisi ayrıca çözülmeli (AUDIENCE_DECISION.md §2.2).
const TEEN_AUDIENCE_DECISIONS: Array[String] = ["general_13_plus", "mixed_audience"]
const TEEN_TREATMENT_BLOCKER: String = "UYUM: 13–17 genç reklam işlemi / yargı bölgesi uyum stratejisi çözülmedi (TFAT TEEN'in GMA 24.9.0 TFCD/TFUA yolunda karşılığı yok; unspecified ≠ TEEN) — AUDIENCE_DECISION.md §2.2"


## Kuralları uygular. `inputs` anahtarları: build ("release"|"debug"),
## preset_name, package_id, canonical_package_id, version_code,
## canonical_version_code, version_name_preset, project_version, export_format,
## arm64, target_sdk (String; "" = şablon varsayılanı), signed,
## keystore_path_set, keystore_exists, keystore_is_debug, keystore_user_set,
## keystore_password_set, ad_config (AdConfig, RELEASE türünde yüklenmiş),
## privacy_policy_url, plugin_release_aar_sha256, plugin_facade_patched,
## teen_ad_treatment_resolved (yoksa false = engel), non_publishable_requested,
## export_path.
static func evaluate(inputs: Dictionary) -> Dictionary:
	var blockers: Array[Dictionary] = []
	var notes: PackedStringArray = PackedStringArray()
	var build: String = String(inputs.get("build", "release"))
	var canonical: String = String(inputs.get("canonical_package_id", "")).strip_edges()
	var package_id: String = String(inputs.get("package_id", "")).strip_edges()
	if build != "release":
		notes.append("debug export'u: release kapısı uygulanmaz (yalnız Google test kimlikleri, AdConfig DEBUG kuralları)")
		if not canonical.is_empty() and package_id == canonical:
			notes.append("UYARI: debug/test export'u ÜRETİM kimliğiyle ('%s') — cihazda Play sürümüyle çakışır; QA/test kimliği '%s'"
				% [canonical, qa_package_id(canonical)])
		return {"status": STATUS_DEBUG, "blockers": blockers, "notes": notes}

	# 1) Uygulama kimliği (Play'de KALICI — owner kararı). QA / test kimliği
	#    release olamaz: QA paketleri üretimle çakışmamalı.
	if canonical.is_empty():
		_add(blockers, CATEGORY_OWNER, "kalıcı uygulama kimliği (package id) seçilmedi — project.godot %s boş" % SETTING_PACKAGE_ID)
	elif not _valid_package(canonical):
		_add(blockers, CATEGORY_OWNER, "project.godot %s geçersiz ya da geçici: '%s'" % [SETTING_PACKAGE_ID, canonical])
	elif _is_qa_package(canonical):
		_add(blockers, CATEGORY_OWNER, "project.godot %s bir QA kimliği ('%s') — üretim kimliği '%s' ile bitemez"
			% [SETTING_PACKAGE_ID, canonical, QA_PACKAGE_SUFFIX])
	if not _valid_package(package_id):
		_add(blockers, CATEGORY_CONFIG, "preset package/unique_name geçersiz ya da geçici: '%s'" % package_id)
	elif _is_qa_package(package_id):
		_add(blockers, CATEGORY_CONFIG, "preset package/unique_name QA / test kimliği: '%s' — QA paketi release olamaz" % package_id)
	elif not canonical.is_empty() and package_id != canonical:
		_add(blockers, CATEGORY_CONFIG, "preset package/unique_name '%s' ≠ project.godot '%s'" % [package_id, canonical])

	# 2) Sürüm: tek kaynak project.godot.
	var code: int = int(inputs.get("version_code", 0))
	var canonical_code: int = int(inputs.get("canonical_version_code", 0))
	if canonical_code < 1:
		_add(blockers, CATEGORY_CONFIG, "project.godot %s < 1" % SETTING_VERSION_CODE)
	elif code != canonical_code:
		_add(blockers, CATEGORY_CONFIG, "preset version/code %d ≠ project.godot %s %d" % [code, SETTING_VERSION_CODE, canonical_code])
	var name_preset: String = String(inputs.get("version_name_preset", ""))
	var project_version: String = String(inputs.get("project_version", ""))
	if project_version.strip_edges().is_empty():
		_add(blockers, CATEGORY_CONFIG, "project.godot %s boş" % SETTING_VERSION_NAME)
	if not name_preset.is_empty() and name_preset != project_version:
		_add(blockers, CATEGORY_CONFIG, "preset version/name '%s' ≠ project.godot %s '%s' (boş bırak)" % [name_preset, SETTING_VERSION_NAME, project_version])

	# 3) Biçim / mimari / hedef API.
	if int(inputs.get("export_format", 0)) != FORMAT_AAB:
		_add(blockers, CATEGORY_CONFIG, "release çıktısı AAB olmalı (gradle_build/export_format=1) — release APK üretilmez")
	if not bool(inputs.get("arm64", false)):
		_add(blockers, CATEGORY_CONFIG, "arm64-v8a kapalı (Play 64-bit şartı)")
	var target: String = String(inputs.get("target_sdk", "")).strip_edges()
	var target_level: int = TEMPLATE_TARGET_SDK if target.is_empty() else int(target)
	if target_level < MIN_TARGET_SDK:
		_add(blockers, CATEGORY_CONFIG, "targetSdk %d < %d (Play hedef API şartı)" % [target_level, MIN_TARGET_SDK])

	# 4) Reklam yapılandırması (RELEASE kuralları — AdConfig tek doğrulayıcı).
	var ads: AdConfig = inputs.get("ad_config") as AdConfig
	if ads == null:
		_add(blockers, CATEGORY_CONFIG, "reklam yapılandırması okunamadı")
	else:
		for problem in ads.problems():
			_add(blockers, CATEGORY_OWNER, "AdMob: %s" % problem)
		if ads.audience_decision.is_empty():
			_add(blockers, CATEGORY_OWNER, "kitle kararı yok (android_export.cfg [Audience] decision — AUDIENCE_DECISION.md)")
		elif not IMPLEMENTED_AUDIENCE_DECISIONS.has(ads.audience_decision):
			_add(blockers, CATEGORY_CODE, "kitle kararı '%s' ek uygulama istiyor (Families: yaş ekranı / AD_ID / TFCD) — henüz kodda yok" % ads.audience_decision)
		else:
			notes.append("ürün kitlesi kararı: %s (TFCD=%s, TFUA=%s, en yüksek reklam derecesi %s — bunlar TEEN işlemi DEĞİL) — AUDIENCE_DECISION.md §0"
				% [ads.audience_decision, ads.tag_for_child_directed_treatment, ads.tag_for_under_age_of_consent,
					ads.max_ad_content_rating])
		# Ürün kitlesinden AYRI uyum kararı: etiket değerleri (hangisi olursa olsun)
		# genç işlemi yerine geçmez; engeli yalnız çözülmüş bir strateji kaldırır.
		if TEEN_AUDIENCE_DECISIONS.has(ads.audience_decision) and not bool(inputs.get("teen_ad_treatment_resolved", false)):
			_add(blockers, CATEGORY_OWNER, TEEN_TREATMENT_BLOCKER)

	# 5) Gizlilik politikası (Play: konsolda VE uygulama içinde).
	var url: String = String(inputs.get("privacy_policy_url", "")).strip_edges()
	if url.is_empty():
		_add(blockers, CATEGORY_OWNER, "gizlilik politikası URL'i yok (project.godot %s)" % SETTING_PRIVACY_URL)
	elif not url.begins_with("https://"):
		_add(blockers, CATEGORY_OWNER, "gizlilik politikası URL'i https değil")

	# 6) Yamalı AdMob eklentisi (UMP canRequestAds / gizlilik seçenekleri).
	if String(inputs.get("plugin_release_aar_sha256", "")) != PATCHED_RELEASE_AAR_SHA256:
		_add(blockers, CATEGORY_CODE, "addons/AdmobPlugin release AAR yamalı derleme değil (tools/admob_plugin)")
	if not bool(inputs.get("plugin_facade_patched", false)):
		_add(blockers, CATEGORY_CODE, "addons/AdmobPlugin/Admob.gd yamalı cephe değil")

	# 7) İmza: upload anahtarı (Play App Signing) — yalnız varlık, sır okunmaz.
	var signed: bool = bool(inputs.get("signed", true))
	if signed:
		if not bool(inputs.get("keystore_path_set", false)):
			_add(blockers, CATEGORY_OWNER, "upload anahtar deposu verilmedi (GODOT_ANDROID_KEYSTORE_RELEASE_PATH ya da preset keystore/release)")
		elif not bool(inputs.get("keystore_exists", false)):
			_add(blockers, CATEGORY_OWNER, "upload anahtar deposu dosyası bulunamadı")
		elif bool(inputs.get("keystore_is_debug", false)):
			_add(blockers, CATEGORY_OWNER, "release imzası DEBUG anahtarıyla — upload anahtarı gerekli")
		if not bool(inputs.get("keystore_user_set", false)) or not bool(inputs.get("keystore_password_set", false)):
			_add(blockers, CATEGORY_OWNER, "upload anahtarı takma adı / şifresi verilmedi (ortam değişkeni; dosyaya YAZILMAZ)")
	else:
		_add(blockers, CATEGORY_CONFIG, "preset imzasız (package/signed=false) — Play'e yüklenemez")

	notes.append("Play Console / hesap adımları kodla denetlenemez: docs/ANDROID_RELEASE_CHECKLIST.md")
	var status: String = STATUS_UPLOAD_CANDIDATE if blockers.is_empty() else STATUS_BLOCKED
	if status == STATUS_BLOCKED and bool(inputs.get("non_publishable_requested", false)):
		var path: String = String(inputs.get("export_path", ""))
		if not signed and path.contains(NON_PUBLISHABLE_MARKER):
			status = STATUS_NON_PUBLISHABLE
			notes.append("NON-PUBLISHABLE release biçimli AAB: imzasız, yolunda %s — Play'e YÜKLENEMEZ" % NON_PUBLISHABLE_MARKER)
		else:
			notes.append("NON-PUBLISHABLE istendi ama preset imzasız değil ya da yol %s içermiyor → BLOCKED" % NON_PUBLISHABLE_MARKER)
	return {"status": status, "blockers": blockers, "notes": notes}


## Bu projenin gerçek girdileri: project.godot, reklam yapılandırması (RELEASE),
## eklenti dosyaları, ortam değişkenleri + verilen preset seçenekleri
## (`preset` = {"name", "options": Dictionary, "export_path"}).
static func project_inputs(preset: Dictionary, build: String) -> Dictionary:
	var options: Dictionary = preset.get("options", {})
	var keystore: String = OS.get_environment("GODOT_ANDROID_KEYSTORE_RELEASE_PATH")
	if keystore.is_empty():
		keystore = String(options.get("keystore/release", ""))
	var user: String = OS.get_environment("GODOT_ANDROID_KEYSTORE_RELEASE_USER")
	if user.is_empty():
		user = String(options.get("keystore/release_user", ""))
	var password_set: bool = not OS.get_environment("GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD").is_empty() \
		or not String(options.get("keystore/release_password", "")).is_empty()
	var keystore_abs: String = ProjectSettings.globalize_path(keystore) if not keystore.is_empty() else ""
	var facade: String = FileAccess.get_file_as_string(PATCHED_FACADE) if FileAccess.file_exists(PATCHED_FACADE) else ""
	return {
		"build": build,
		"preset_name": String(preset.get("name", "")),
		"package_id": String(options.get("package/unique_name", "")),
		"canonical_package_id": String(ProjectSettings.get_setting(SETTING_PACKAGE_ID, "")),
		"version_code": int(options.get("version/code", 1)),
		"canonical_version_code": int(ProjectSettings.get_setting(SETTING_VERSION_CODE, 0)),
		"version_name_preset": String(options.get("version/name", "")),
		"project_version": String(ProjectSettings.get_setting(SETTING_VERSION_NAME, "")),
		"export_format": int(options.get("gradle_build/export_format", 0)),
		"arm64": bool(options.get("architectures/arm64-v8a", false)),
		"target_sdk": String(options.get("gradle_build/target_sdk", "")),
		"signed": bool(options.get("package/signed", true)),
		"keystore_path_set": not keystore.is_empty(),
		"keystore_exists": not keystore_abs.is_empty() and FileAccess.file_exists(keystore_abs),
		"keystore_is_debug": not keystore_abs.is_empty() and (keystore_abs.get_file().to_lower() == "debug.keystore"
			or keystore_abs.simplify_path() == String(_editor_debug_keystore()).simplify_path()),
		"keystore_user_set": not user.is_empty(),
		"keystore_password_set": password_set,
		"ad_config": AdConfig.load_file(AdConfig.CONFIG_PATH, AdConfig.BuildType.RELEASE),
		"privacy_policy_url": String(ProjectSettings.get_setting(SETTING_PRIVACY_URL, "")),
		"plugin_release_aar_sha256": FileAccess.get_sha256(PATCHED_RELEASE_AAR) if FileAccess.file_exists(PATCHED_RELEASE_AAR) else "",
		"plugin_facade_patched": facade.contains("func has_privacy_options_api()") and facade.contains("func show_privacy_options_form()"),
		# 13–17 genç reklam işlemi stratejisi bugün SEÇİLMEDİ (AUDIENCE_DECISION §2.2):
		# kayıt / uygulama yok → daima false. Strateji seçilince ayrı görevde bağlanır.
		"teen_ad_treatment_resolved": false,
		"non_publishable_requested": OS.get_environment(NON_PUBLISHABLE_ENV) == "1",
		"export_path": String(preset.get("export_path", "")),
	}


## Okunabilir rapor (şifre / takma ad içermez).
static func report(result: Dictionary, title: String) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("== %s: %s ==" % [title, result["status"]])
	for blocker: Dictionary in result["blockers"]:
		lines.append("  [%s] %s" % [blocker["category"], blocker["message"]])
	for note in result["notes"]:
		lines.append("  not: %s" % note)
	return "\n".join(lines)


## QA / test kimliği: kalıcı kimlik + QA_PACKAGE_SUFFIX (com.obappstudio.squishymerge.qa).
static func qa_package_id(canonical: String) -> String:
	return canonical.strip_edges() + QA_PACKAGE_SUFFIX


static func _add(blockers: Array[Dictionary], category: String, message: String) -> void:
	blockers.append({"category": category, "message": message})


static func _is_qa_package(value: String) -> bool:
	return value.ends_with(QA_PACKAGE_SUFFIX)


static func _valid_package(value: String) -> bool:
	if value.is_empty() or RegEx.create_from_string(PACKAGE_PATTERN).search(value) == null:
		return false
	for prefix in TEMPORARY_PACKAGE_PREFIXES:
		if value.begins_with(prefix):
			return false
	return true


static func _editor_debug_keystore() -> String:
	if Engine.is_editor_hint() and EditorInterface.get_editor_settings() != null:
		return String(EditorInterface.get_editor_settings().get_setting("export/android/debug_keystore"))
	return ""
