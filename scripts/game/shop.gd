class_name Shop
extends RefCounted
## Mağaza — SKİN tarafı: sahip olunmayan skin'ler Hamur ile satın alınır
## (GAME_DESIGN.md §5.6). Güç tarafı ayrı dosyada: `power_up_economy.gd`.
##
## Buradaki tek para birimi oyun içi Hamur. Gerçek para Power Pack'ler
## PLANLANDI ama HENÜZ KURULMADI (billing yok, bkz. GAME_DESIGN §5.7.4);
## skinler için gerçek para satışı hiç planlanmadı.

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
##
## M8.5-05: eskiden `spend_dough()` + `grant_skin()` şeklinde İKİ AYRI kayıt
## yazması yapılıyordu; aradaki bir çökme Hamur'u yakıp skin'i vermeyebilirdi.
## Artık tek transaction (SaveManager.purchase_skin_with_dough).
static func purchase(skin: SkinData) -> bool:
	if skin == null:
		return false
	return SaveManager.purchase_skin_with_dough(skin.id, price_of(skin))
