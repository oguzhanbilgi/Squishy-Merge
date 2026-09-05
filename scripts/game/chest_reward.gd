class_name ChestReward
extends RefCounted
## Bir sandıktan çıkan şey: ya yeni bir skin ya da Hamur (GAME_DESIGN.md §5.2).

var rarity: SkinData.Rarity = SkinData.Rarity.COMMON
## null ise ödül Hamur.
var skin: SkinData = null
var dough: int = 0
## Zaten sahip olunan bir skin çıktığı için Hamur'a çevrildiyse true.
var is_duplicate: bool = false
## Kaybedilen round'un teselli ödülü mü (GAME_DESIGN.md §5.1 madde 4).
var is_consolation: bool = false


func is_skin_reward() -> bool:
	return skin != null


func title() -> String:
	if is_consolation:
		return "Teselli ödülü"
	return SkinData.rarity_name(rarity)


func description() -> String:
	if is_skin_reward():
		return "Yeni skin: %s" % skin.display_name
	if is_duplicate:
		return "Zaten vardı → %d Hamur" % dough
	return "%d Hamur" % dough


func color() -> Color:
	if is_consolation:
		return Color("7a7a7a")
	return SkinData.rarity_color(rarity)
