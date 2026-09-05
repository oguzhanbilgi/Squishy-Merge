class_name LevelLibrary
extends RefCounted
## resources/levels/ klasörünü tarar. Yeni bir .tres eklendiğinde kod
## değişmeden listeye girer (GAME_DESIGN.md §3 data-driven şartı).

const LEVELS_DIR: String = "res://resources/levels/"


## Sonsuz mod hariç, level_number'a göre sıralı level listesi.
static func load_levels() -> Array[LevelData]:
	var levels: Array[LevelData] = []
	for level in _load_all():
		if not level.is_endless:
			levels.append(level)
	levels.sort_custom(func(a: LevelData, b: LevelData) -> bool:
		return a.level_number < b.level_number)
	return levels


static func load_endless() -> LevelData:
	for level in _load_all():
		if level.is_endless:
			return level
	push_error("Sonsuz mod resource'u bulunamadı: %s" % LEVELS_DIR)
	return null


static func _load_all() -> Array[LevelData]:
	var result: Array[LevelData] = []
	var dir := DirAccess.open(LEVELS_DIR)
	if dir == null:
		push_error("Level klasörü açılamadı: %s" % LEVELS_DIR)
		return result
	for file_name in dir.get_files():
		# Export edilmiş build'de .tres -> .remap olur.
		var clean_name: String = file_name.trim_suffix(".remap")
		if not clean_name.ends_with(".tres"):
			continue
		var resource := load(LEVELS_DIR + clean_name)
		var level := resource as LevelData
		if level != null:
			result.append(level)
	return result
