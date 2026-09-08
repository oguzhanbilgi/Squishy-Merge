class_name Shop
extends RefCounted
## Mağaza: sahip olunmayan skin'ler Hamur ile satın alınır
## (GAME_DESIGN.md §5.6). Gerçek para / IAP YOK — PROJECT_CONTEXT non-goal'u
## aynen geçerli, buradaki tek para birimi oyun içi Hamur.

## Rarity başına fiyat. Index = SkinData.Rarity sırası
## (COMMON / RARE / EPIC / LEGENDARY). Denge için tek dokunulacak yer burası.
const PRICES: Array[int] = [50, 150, 400, 900]


static func price(rarity: SkinData.Rarity) -> int:
	return PRICES[int(rarity)]


static func price_of(skin: SkinData) -> int:
	return price(skin.rarity)


## Satın alınabilir skin'ler: sahip OLUNMAYANLAR, rarity'e göre sıralı
## (SkinLibrary.all() zaten rarity + id sırasında döndürüyor).
static func available() -> Array[SkinData]:
	var result: Array[SkinData] = []
	for skin in SkinLibrary.all():
		if not SaveManager.owns_skin(skin.id):
			result.append(skin)
	return result


static func can_afford(skin: SkinData) -> bool:
	return SaveManager.dough() >= price_of(skin)


## Satın alma. Başarılıysa Hamur düşer, skin koleksiyona eklenir ve true döner.
## Sahip olunan veya parası yetmeyen bir skin için hiçbir şey yapmaz.
static func purchase(skin: SkinData) -> bool:
	if skin == null or SaveManager.owns_skin(skin.id):
		return false
	if not SaveManager.spend_dough(price_of(skin)):
		return false
	SaveManager.grant_skin(skin.id)
	return true
