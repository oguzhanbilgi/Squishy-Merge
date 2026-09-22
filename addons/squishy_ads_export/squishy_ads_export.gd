@tool
extends EditorPlugin
## Proje export eklentisi (M8.9-01): `addons/AdmobPlugin/android_export.cfg`
## Godot'un "all_resources" export'unda paketlenmez (.cfg bir Resource
## değil) — manifest'e yazılan uygulama kimliği ile çalışma zamanındaki
## reklam birimi kimlikleri ayrı kaynaklardan gelirdi. Bu eklenti dosyayı
## PCK'ye `add_file` ile ekler (tek kaynak korunur) ve export anında
## yapılandırmayı doğrulayıp loglar. Üçüncü taraf AdmobPlugin'e dokunmaz.

var _export_plugin: AdsConfigExportPlugin


func _enter_tree() -> void:
	_export_plugin = AdsConfigExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null


class AdsConfigExportPlugin extends EditorExportPlugin:
	const CONFIG_PATH: String = AdConfig.CONFIG_PATH

	func _get_name() -> String:
		return "SquishyAdsConfig"

	func _export_begin(_features: PackedStringArray, is_debug: bool, _path: String, _flags: int) -> void:
		if not FileAccess.file_exists(CONFIG_PATH):
			push_error("SquishyAdsExport: %s yok — reklam yapılandırması paketlenemedi." % CONFIG_PATH)
			return
		add_file(CONFIG_PATH, FileAccess.get_file_as_bytes(CONFIG_PATH), false)
		# M9-01: build türü kimlikleri seçer — export'un türüyle doğrula (editör
		# kendisi hep debug'dır; `load_project()` burada yanlış türü okurdu).
		var type: AdConfig.BuildType = AdConfig.BuildType.DEBUG if is_debug else AdConfig.BuildType.RELEASE
		var config: AdConfig = AdConfig.load_file(CONFIG_PATH, type)
		print("SquishyAdsExport: paketlendi -> %s" % config.describe())
		if not config.is_valid():
			push_error("SquishyAdsExport: %s reklam yapılandırması GEÇERSİZ (%s) — bu build'de reklam başlatılmaz." % [
				"debug" if is_debug else "RELEASE", "; ".join(config.problems())])
