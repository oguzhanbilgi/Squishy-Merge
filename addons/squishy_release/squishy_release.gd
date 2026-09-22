@tool
extends EditorPlugin
## Android release kapısı (M9-01) — editör/export eklentisi, oyuna girmez
## (preset exclude_filter'da; oyun çalışırken hiç yüklenmez).
##
## Her Android export'unun başında `ReleaseReadiness` raporunu log'a basar.
## RELEASE export'unda engel varsa build'i BİLEREK düşürür: Godot 4.6.3'te bir
## export eklentisi export'u veto edemez (`_get_export_option_warning` yalnız
## mesaj ekler, geçerliliği değiştirmez), bu yüzden Gradle'a kendini anlatan,
## çözülemeyen bir bağımlılık verilir →
##   "Could not find squishymerge.release-blocked:see-docs-ANDROID_RELEASE_CHECKLIST:m9"
## ve Godot "Building of Android project failed" ile durur. Debug export'ları
## (test reklamlı APK, QA paketleri) hiç etkilenmez.
##
## Tek istisna: `SQUISHY_NON_PUBLISHABLE_RELEASE=1` + İMZASIZ preset + yolunda
## NOT_FOR_UPLOAD → Play'e yüklenemeyen release biçimli AAB (pipeline doğrulaması).
## Doğrulayıcı: tools/release/release_readiness.gd; akış:
## tools/release/release_android.sh; liste: docs/ANDROID_RELEASE_CHECKLIST.md.

const BLOCKED_DEPENDENCY: String = "squishymerge.release-blocked:see-docs-ANDROID_RELEASE_CHECKLIST:m9"
const READINESS_PATH: String = "res://tools/release/release_readiness.gd"

var _export_plugin: ReleaseGateExportPlugin


func _enter_tree() -> void:
	_export_plugin = ReleaseGateExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null


class ReleaseGateExportPlugin extends EditorExportPlugin:
	var _result: Dictionary = {}
	var _export_path: String = ""

	func _get_name() -> String:
		return "SquishyReleaseGate"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _export_begin(_features: PackedStringArray, is_debug: bool, path: String, _flags: int) -> void:
		_export_path = path
		_result = _evaluate(is_debug)
		var text: String = String(_readiness().report(_result, "SquishyReleaseGate (%s)" % path.get_file()))
		print(text)
		if String(_result.get("status", "")) == "BLOCKED":
			push_error("SquishyReleaseGate: RELEASE EXPORT REDDEDİLDİ — engeller yukarıda; build bilerek düşürülüyor (%s)." % BLOCKED_DEPENDENCY)

	func _get_android_dependencies(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray()
		if _result.is_empty():
			_result = _evaluate(false)
		if String(_result.get("status", "")) == "BLOCKED":
			return PackedStringArray([BLOCKED_DEPENDENCY])
		return PackedStringArray()

	func _export_end() -> void:
		_result = {}
		_export_path = ""

	func _evaluate(is_debug: bool) -> Dictionary:
		var options: Dictionary = {}
		for key in ["package/unique_name", "version/code", "version/name", "gradle_build/export_format",
				"architectures/arm64-v8a", "gradle_build/target_sdk", "package/signed", "keystore/release",
				"keystore/release_user", "keystore/release_password"]:
			var value: Variant = get_option(key)
			if value != null:
				options[key] = value
		var preset: Dictionary = {"name": "", "options": options, "export_path": _export_path}
		var readiness: GDScript = _readiness()
		return readiness.evaluate(readiness.project_inputs(preset, "debug" if is_debug else "release"))

	func _readiness() -> GDScript:
		# Doğrulayıcı tools/ altında (export dışı): bilerek `load`, preload değil.
		return load(READINESS_PATH) as GDScript
