class_name ChestSystem
extends RefCounted
## Sandık açma (GAME_DESIGN.md §5.2).
##
## Sandık açılışı İKİ AŞAMALI ve bu iki aşama birbirinden bağımsız:
##
##   1) RARITY rulesi  — Common %60 / Rare %25 / Epic %12 / Legendary %3
##   2) ÖDÜL TİPİ rulesi — %30 skin / %70 Hamur
##
## Bu iki kavram karıştırılmamalı: rarity sandığın "kalitesini" seçer,
## ödül tipi o kalitede skin mi Hamur mu çıkacağını seçer. Legendary bir
## sandık da %70 olasılıkla Hamur verir (ama Legendary miktarında).
##
## Her ikisi de KİLİTLİ, owner onaylı. Değiştirmeden önce owner'a sor ve
## `tools/shop_economy.py` simülasyonunu yeniden çalıştır.
##
## open() ödülü SaveManager'a da işler; dönen ChestReward sadece gösterim
## içindir.

# --- Kilitli oranlar ---

## Rarity kümülatif eşikleri (1-100). Sıra SkinData.Rarity enum sırasıyla aynı:
## COMMON 1-60, RARE 61-85, EPIC 86-97, LEGENDARY 98-100.
const RARITY_THRESHOLDS: Array[int] = [60, 85, 97, 100]

## Ödül tipi: sandığın skin verme olasılığı (yüzde). Kalanı Hamur.
## KİLİTLİ (owner, M8.5): %30 skin / %70 Hamur.
const SKIN_REWARD_PERCENT: int = 30

## Hamur ödülünün rarity başına miktarı. Skin ödülü Hamur'a düştüğünde de
## (koleksiyon dolu / duplicate) aynı tablo kullanılıyor — oyuncu açısından
## ikisi de "bu rarity'nin Hamur karşılığı".
const RARITY_DOUGH: Array[int] = [10, 25, 60, 150]

## Kaybedilen round'un teselli ödülü (GAME_DESIGN.md §5.1 madde 4).
const CONSOLATION_DOUGH: int = 5

## Kaç merge'de bir bonus sandık (GAME_DESIGN.md §5.2).
const MERGES_PER_BONUS_CHEST: int = 75


# --- Aşama 1: rarity ---

static func roll_rarity() -> SkinData.Rarity:
	var roll: int = randi_range(1, RARITY_THRESHOLDS[RARITY_THRESHOLDS.size() - 1])
	for index in RARITY_THRESHOLDS.size():
		if roll <= RARITY_THRESHOLDS[index]:
			return index as SkinData.Rarity
	return SkinData.Rarity.COMMON


# --- Aşama 2: ödül tipi ---

## true = skin denenecek, false = doğrudan Hamur.
## "Denenecek", çünkü skin verilemeyebilir (bkz. _grant_skin_or_dough).
static func roll_wants_skin() -> bool:
	return randi_range(1, 100) <= SKIN_REWARD_PERCENT


# --- Sandık açma ---

## Bir sandık açar ve sonucu kalıcı kayda işler.
##
## Bir sandık HER ZAMAN tek bir şey verir: ya skin ya Hamur, ikisi birden
## asla değil. `ChestReward.is_skin_reward()` bu ayrımın tek göstergesi.
static func open() -> ChestReward:
	var reward := ChestReward.new()
	reward.rarity = roll_rarity()

	if roll_wants_skin():
		_grant_skin_or_dough(reward)
	else:
		_grant_dough(reward)
	return reward


## Skin ödülü. Deterministik kural:
##
##   - O rarity'de oyuncunun sahip OLMADIĞI skin varsa, onlardan biri
##     rastgele seçilip verilir. Yani skin ödülü çıktıysa gerçekten yeni bir
##     skin açılır — sahip olunanlar havuzdan baştan eleniyor.
##   - Hiç açılmamış skin kalmadıysa (o rarity tamamlanmış ya da hiç skin
##     tanımlı değil) aynı rarity'nin Hamur karşılığına düşülür ve ödül
##     `is_duplicate` olarak işaretlenir.
##
## Neden sahip olunanlar önceden eleniyor: eski davranış tüm havuzdan
## rastgele seçip sahip olunanı Hamur'a çeviriyordu. Bu, koleksiyon
## doldukça skin ödülünün sessizce Hamur'a dönüşmesi demekti — %30'luk
## skin oranı kâğıt üzerinde duruyor ama pratikte çok daha düşük
## gerçekleşiyordu. Şimdi %30, açılmamış skin bulunduğu sürece gerçekten
## %30.
static func _grant_skin_or_dough(reward: ChestReward) -> void:
	var pool: Array[SkinData] = _unowned_by_rarity(reward.rarity)
	if pool.is_empty():
		reward.is_duplicate = true
		_grant_dough(reward)
		return
	var picked: SkinData = pool[randi() % pool.size()]
	reward.skin = picked
	SaveManager.grant_skin(picked.id)


static func _grant_dough(reward: ChestReward) -> void:
	reward.dough = RARITY_DOUGH[int(reward.rarity)]
	SaveManager.add_dough(reward.dough)


static func _unowned_by_rarity(rarity: SkinData.Rarity) -> Array[SkinData]:
	var pool: Array[SkinData] = []
	for skin in SkinLibrary.by_rarity(rarity):
		if not SaveManager.owns_skin(skin.id):
			pool.append(skin)
	return pool


static func consolation() -> ChestReward:
	var reward := ChestReward.new()
	reward.is_consolation = true
	reward.dough = CONSOLATION_DOUGH
	SaveManager.add_dough(reward.dough)
	return reward
