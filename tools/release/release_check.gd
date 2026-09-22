extends Node
## Release kapısının export ÖNCESİ, headless çalıştırılan hâli (M9-01).
## Yerel `export_presets.cfg`'deki bir preset + project.godot + reklam
## yapılandırması + eklenti + ortam değişkenleri → ReleaseReadiness raporu.
## Hiçbir dosyaya yazmaz (kayıt dahil), yalnız stdout + çıkış kodu.
##
##   godot --headless --path . res://tools/release/release_check.tscn -- --preset="Android Release AAB" [--path=build/x.aab]
##
## Çıkış kodu: 0 UPLOAD_CANDIDATE · 2 BLOCKED · 3 NON_PUBLISHABLE · 4 DEBUG · 1 hata.
## Şifre / takma ad asla yazdırılmaz.

const PRESETS: String = "res://export_presets.cfg"
const CREDENTIALS: String = "res://.godot/export_credentials.cfg"


func _ready() -> void:
	var args: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			args[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1).trim_prefix("\"").trim_suffix("\"")
	var preset_name: String = String(args.get("preset", "Android Release AAB"))
	var preset: Dictionary = _load_preset(preset_name)
	if preset.is_empty():
		print("release_check: preset '%s' export_presets.cfg içinde yok" % preset_name)
		get_tree().quit(1)
		return
	if args.has("path"):
		preset["export_path"] = args["path"]
	var build: String = String(args.get("build", "release"))
	var inputs: Dictionary = ReleaseReadiness.project_inputs(preset, build)
	var result: Dictionary = ReleaseReadiness.evaluate(inputs)
	print(ReleaseReadiness.report(result, "release_check '%s'" % preset_name))
	var ads: AdConfig = inputs["ad_config"]
	print("  bilgi: paket='%s' versionCode=%d versionName='%s' format=%s arm64=%s targetSdk=%s imzalı=%s AdConfig=%s" % [
		inputs["package_id"], inputs["version_code"],
		inputs["version_name_preset"] if not String(inputs["version_name_preset"]).is_empty() else inputs["project_version"],
		"AAB" if int(inputs["export_format"]) == ReleaseReadiness.FORMAT_AAB else "APK", str(inputs["arm64"]),
		inputs["target_sdk"] if not String(inputs["target_sdk"]).is_empty() else "%d (şablon)" % ReleaseReadiness.TEMPLATE_TARGET_SDK,
		str(inputs["signed"]), "geçerli" if ads.is_valid() else "GEÇERSİZ"])
	var codes: Dictionary = {
		ReleaseReadiness.STATUS_UPLOAD_CANDIDATE: 0, ReleaseReadiness.STATUS_BLOCKED: 2,
		ReleaseReadiness.STATUS_NON_PUBLISHABLE: 3, ReleaseReadiness.STATUS_DEBUG: 4,
	}
	get_tree().quit(int(codes.get(result["status"], 1)))


func _load_preset(preset_name: String) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PRESETS) != OK:
		return {}
	var creds := ConfigFile.new()
	var has_creds: bool = cfg != null and creds.load(CREDENTIALS) == OK
	var index: int = 0
	while cfg.has_section("preset.%d" % index):
		var section: String = "preset.%d" % index
		if String(cfg.get_value(section, "name", "")) == preset_name:
			var options: Dictionary = {}
			var options_section: String = section + ".options"
			if cfg.has_section(options_section):
				for key in cfg.get_section_keys(options_section):
					options[key] = cfg.get_value(options_section, key)
			if has_creds and creds.has_section(options_section):
				for key in creds.get_section_keys(options_section):
					options[key] = creds.get_value(options_section, key)
			return {"name": preset_name, "options": options,
				"export_path": String(cfg.get_value(section, "export_path", "")),
				"exclude_filter": String(cfg.get_value(section, "exclude_filter", ""))}
		index += 1
	return {}
