class_name DailyChestReward
extends RefCounted
## Bir GÜNLÜK sandığın sonucu (M8.9-02, docs/monetization/DAILY_REWARDS.md §4).
## Level sonu sandığından (`ChestReward`: ya skin YA Hamur) farklı bir
## profil: günlük sandık HER ZAMAN Hamur verir, üstüne bağımsız bir skin
## şansı vardır — ikisi birden olabilir.
##
## DEĞİŞMEZ SONUÇ: `DailyRewards` transaction anında üretip kayda işler;
## pencere bunu yalnız GÖSTERİR. Animasyon tekrarı / pencere yeniden açılışı
## / ikinci sinyal yeniden kura çekmez — nesne salt okunur tutulur.

## Kaynak: "free" (ücretsiz sandık) ya da "ad" (reklamlı sandık).
var source: String = "free"
## Ödülün ait olduğu yerel gün anahtarı (YYYY-MM-DD).
var day_key: String = ""
## Garanti Hamur (15) + geri düşüş Hamur'u (skin kurası tutup rarity
## tükendiyse +15) = toplam.
var base_dough: int = 0
var bonus_dough: int = 0
## Skin kurası tuttu mu (%30)?
var skin_rolled: bool = false
## Kura tuttuysa çekilen rarity; tutmadıysa -1.
var rarity: int = -1
## Verilen skin (null = skin yok).
var skin: SkinData = null
## Kura tuttu ama o rarity'de sahip olunmayan skin kalmamıştı (→ bonus Hamur).
var skin_exhausted: bool = false


func dough() -> int:
	return base_dough + bonus_dough


func has_skin() -> bool:
	return skin != null


## Sandık görselinin (RewardGem) efekt kademesi: skin varsa onun rarity'si,
## yoksa en sade kademe.
func fx_rarity() -> int:
	return rarity if has_skin() else int(SkinData.Rarity.COMMON)


## Pencere/skin kartı için ChestReward görünümü (yalnız sunum; kayda dokunmaz).
func as_skin_chest_reward() -> ChestReward:
	var view := ChestReward.new()
	view.rarity = (rarity as SkinData.Rarity) if rarity >= 0 else SkinData.Rarity.COMMON
	view.skin = skin
	return view


func describe() -> String:
	return "DailyChestReward(%s %s dough=%d skin=%s rarity=%d rolled=%s exhausted=%s)" % [
		source, day_key, dough(), String(skin.id) if skin != null else "-", rarity,
		str(skin_rolled), str(skin_exhausted)]
