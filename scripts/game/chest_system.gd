class_name ChestSystem
extends RefCounted
## Sandık açma ve rarity kurası (GAME_DESIGN.md §5.2).
## Oranlar KİLİTLİ, owner onaylı: Common %60 / Rare %25 / Epic %12 / Legendary %3.
## open() ödülü SaveManager'a da işler; dönen ChestReward sadece gösterim içindir.

## Kümülatif eşikler (1-100). Sıra rarity enum sırasıyla aynı.
const RARITY_THRESHOLDS: Array[int] = [60, 85, 97, 100]

## Duplicate skin Hamur'a çevrilirken rarity başına verilen miktar.
## GAME_DESIGN'da tanımlı değil — M3'te belirlendi, v1.1 shop'u gelince
## gerçek bir ekonomiye göre yeniden bakılacak.
const DUPLICATE_DOUGH: Array[int] = [10, 25, 60, 150]

## Kaybedilen round'un teselli ödülü (GAME_DESIGN.md §5.1 madde 4).
const CONSOLATION_DOUGH: int = 5

## Kaç merge'de bir bonus sandık (GAME_DESIGN.md §5.2).
const MERGES_PER_BONUS_CHEST: int = 75


static func roll_rarity() -> SkinData.Rarity:
	var roll: int = randi_range(1, RARITY_THRESHOLDS[RARITY_THRESHOLDS.size() - 1])
	for index in RARITY_THRESHOLDS.size():
		if roll <= RARITY_THRESHOLDS[index]:
			return index as SkinData.Rarity
	return SkinData.Rarity.COMMON


## Bir sandık açar ve sonucu kalıcı kayda işler.
static func open() -> ChestReward:
	var reward := ChestReward.new()
	reward.rarity = roll_rarity()

	var candidates: Array[SkinData] = SkinLibrary.by_rarity(reward.rarity)
	if candidates.is_empty():
		# O rarity'de hiç skin tanımlı değilse Hamur'a düş.
		reward.dough = DUPLICATE_DOUGH[reward.rarity]
		SaveManager.add_dough(reward.dough)
		return reward

	var picked: SkinData = candidates[randi() % candidates.size()]
	if SaveManager.owns_skin(picked.id):
		# Dedupe: zaten sahip olunan skin Hamur'a çevrilir.
		reward.is_duplicate = true
		reward.dough = DUPLICATE_DOUGH[reward.rarity]
		SaveManager.add_dough(reward.dough)
	else:
		reward.skin = picked
		SaveManager.grant_skin(picked.id)
	return reward


static func consolation() -> ChestReward:
	var reward := ChestReward.new()
	reward.is_consolation = true
	reward.dough = CONSOLATION_DOUGH
	SaveManager.add_dough(reward.dough)
	return reward
