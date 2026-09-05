class_name SkinLibrary
extends RefCounted
## resources/skins/ klasörünü tarar — LevelLibrary ile aynı mantık: yeni skin
## eklemek için kod değişikliği gerekmiyor, klasöre .tres koymak yeterli.

const SKINS_DIR: String = "res://resources/skins/"

static var _cache: Array[SkinData] = []


static func all() -> Array[SkinData]:
	if not _cache.is_empty():
		return _cache
	var dir := DirAccess.open(SKINS_DIR)
	if dir == null:
		push_error("Skin klasörü açılamadı: %s" % SKINS_DIR)
		return _cache
	for file_name in dir.get_files():
		# Export edilmiş build'de .tres -> .remap olur.
		var clean_name: String = file_name.trim_suffix(".remap")
		if not clean_name.ends_with(".tres"):
			continue
		var skin := load(SKINS_DIR + clean_name) as SkinData
		if skin != null:
			_cache.append(skin)
	_cache.sort_custom(func(a: SkinData, b: SkinData) -> bool:
		if a.rarity != b.rarity:
			return a.rarity < b.rarity
		return String(a.id) < String(b.id))
	return _cache


static func by_rarity(rarity: SkinData.Rarity) -> Array[SkinData]:
	var result: Array[SkinData] = []
	for skin in all():
		if skin.rarity == rarity:
			result.append(skin)
	return result


static func find(id: StringName) -> SkinData:
	for skin in all():
		if skin.id == id:
			return skin
	return null


static func total_count() -> int:
	return all().size()
