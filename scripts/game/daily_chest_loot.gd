class_name DailyChestLoot
extends RefCounted
## GÜNLÜK sandık loot reçetesi (M8.9-02, owner kararı — docs/monetization/
## DAILY_REWARDS.md §4). Level sonu / bonus sandık reçetesi (`ChestSystem`)
## DEĞİŞMEDİ; bu ayrı bir profil (DAILY):
##
##   garanti      +15 Hamur (GUARANTEED_DOUGH)
##   bağımsız     %30 skin kurası (SKIN_CHANCE_PERCENT)
##     tuttuysa   rarity kurası Common %60 / Rare %25 / Epic %12 / Legendary %3
##                (ChestSystem.RARITY_THRESHOLDS ile aynı kilitli oranlar)
##                → o rarity'de sahip OLUNMAYAN koleksiyon skinlerinden biri
##     tükendiyse (o rarity'nin tamamı sende) skin yerine +15 BONUS Hamur
##
##   sonuç:  skin yok            +15 Hamur
##           yeni skin           +15 Hamur + skin
##           kura tuttu/tükendi  +30 Hamur
##
## "Varsayılan" (orijinal görünüm) koleksiyon skini DEĞİL: `SkinLibrary`
## yalnız 20 koleksiyon .tres'ini tarar, havuza hiç girmez.
##
## Kura tek yerde ve verilen RNG ile çekilir (deterministik test); kayda
## DOKUNMAZ — sonucu `DailyRewards` transaction'ı işler.

const GUARANTEED_DOUGH: int = 15
const SKIN_CHANCE_PERCENT: int = 30
const EXHAUSTED_BONUS_DOUGH: int = 15


## Kura. `owned_ids`: oyuncunun sahip olduğu skin id'leri (String); kayıt
## okunmaz, çağıran verir (test edilebilirlik).
static func roll(rng: RandomNumberGenerator, owned_ids: Array) -> DailyChestReward:
	var reward := DailyChestReward.new()
	reward.base_dough = GUARANTEED_DOUGH
	if rng.randi_range(1, 100) > SKIN_CHANCE_PERCENT:
		return reward
	reward.skin_rolled = true
	reward.rarity = int(roll_rarity(rng))
	var pool: Array[SkinData] = unowned_by_rarity(reward.rarity as SkinData.Rarity, owned_ids)
	if pool.is_empty():
		reward.skin_exhausted = true
		reward.bonus_dough = EXHAUSTED_BONUS_DOUGH
		return reward
	reward.skin = pool[rng.randi_range(0, pool.size() - 1)]
	return reward


## Rarity kurası — kilitli eşikler ChestSystem'den (60 / 85 / 97 / 100).
static func roll_rarity(rng: RandomNumberGenerator) -> SkinData.Rarity:
	var thresholds: Array[int] = ChestSystem.RARITY_THRESHOLDS
	var roll: int = rng.randi_range(1, thresholds[thresholds.size() - 1])
	for index in thresholds.size():
		if roll <= thresholds[index]:
			return index as SkinData.Rarity
	return SkinData.Rarity.COMMON


## O rarity'de sahip olunmayan koleksiyon skinleri (katalog sırasıyla —
## RNG indeksi deterministik).
static func unowned_by_rarity(rarity: SkinData.Rarity, owned_ids: Array) -> Array[SkinData]:
	var pool: Array[SkinData] = []
	for skin in SkinLibrary.by_rarity(rarity):
		if not owned_ids.has(String(skin.id)):
			pool.append(skin)
	return pool
