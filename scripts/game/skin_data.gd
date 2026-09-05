class_name SkinData
extends Resource
## Kozmetik dumpling skin'i (GAME_DESIGN.md §5.2). Placeholder görsel: dumpling
## rengini `tint`e kaydırır. Gerçek skin görselleri M7'de owner'dan gelecek.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

@export var id: StringName = &""
@export var display_name: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var tint: Color = Color.WHITE


static func rarity_name(value: Rarity) -> String:
	match value:
		Rarity.COMMON: return "Common"
		Rarity.RARE: return "Rare"
		Rarity.EPIC: return "Epic"
		Rarity.LEGENDARY: return "Legendary"
	return "?"


## Sandık/kart rengi — rarity'yi bir bakışta ayırt etmek için.
static func rarity_color(value: Rarity) -> Color:
	match value:
		Rarity.COMMON: return Color("9aa0a6")
		Rarity.RARE: return Color("4c9be8")
		Rarity.EPIC: return Color("a55cd6")
		Rarity.LEGENDARY: return Color("f0a92e")
	return Color.WHITE
