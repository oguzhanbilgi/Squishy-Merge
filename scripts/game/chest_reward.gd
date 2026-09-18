class_name ChestReward
extends RefCounted
## Bir sandıktan çıkan şey: ya yeni bir skin ya da Hamur (GAME_DESIGN.md §5.2).

var rarity: SkinData.Rarity = SkinData.Rarity.COMMON
## null ise ödül Hamur.
var skin: SkinData = null
var dough: int = 0
## Skin ödülü çıktı ama verilemediği için Hamur'a düştüyse true — yani o
## rarity'de açılmamış skin kalmamış (koleksiyonun o bölümü tamamlanmış).
## Bkz. ChestSystem._grant_skin_or_dough.
var is_duplicate: bool = false
## Kaybedilen round'un teselli ödülü mü (GAME_DESIGN.md §5.1 madde 4).
var is_consolation: bool = false


func is_skin_reward() -> bool:
	return skin != null


## Oyuncuya görünen başlık (M8.6-09: Türkçe, büyük harf — Koleksiyon /
## Mağaza rarity diliyle aynı `SkinData.rarity_display_upper`). İç ad
## `rarity_name` (Common…) değişmedi; id/enum/variation kimliği o.
func title() -> String:
	if is_consolation:
		return "TESELLİ"
	return SkinData.rarity_display_upper(rarity)


## Ana satır: skin adı ya da "+N Hamur".
func description() -> String:
	if is_skin_reward():
		return skin.display_name
	return "+%d Hamur" % dough


## Kısa not (yalnız geri düşüşte): o kalitedeki bütün skinler zaten
## oyuncuda, sandık aynı kalitenin Hamur karşılığını verdi. İç terim
## ("duplicate" / "fallback") oyuncuya gösterilmez; skin verildi de denmez.
func note() -> String:
	if is_duplicate and not is_skin_reward():
		return "%s skinlerin tamamı sende" % SkinData.rarity_display_name(rarity)
	return ""


func color() -> Color:
	if is_consolation:
		return Color("7a7a7a")
	return SkinData.rarity_color(rarity)
