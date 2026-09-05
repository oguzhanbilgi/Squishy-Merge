class_name TierConfig
extends RefCounted
## 8 tier'ın veri tablosu (GAME_DESIGN.md §2). Renk/yarıçap değerleri
## PLACEHOLDER — final asset'ler M7'de owner tarafından verilecek.

const MAX_TIER: int = 8

## Drop pool: sadece tier 1-3 rastgele düşer (GAME_DESIGN.md §2).
const DROP_POOL_MAX_TIER: int = 3

const TIERS: Array[Dictionary] = [
	{"name": "Mini Dumpling",   "radius": 22.0,  "color": Color("ffd9a0"), "score": 0},
	{"name": "Küçük Dumpling",  "radius": 30.0,  "color": Color("ffb3ba"), "score": 50},
	{"name": "Dumpling",        "radius": 40.0,  "color": Color("baffc9"), "score": 70},
	{"name": "Şişkin Dumpling", "radius": 52.0,  "color": Color("bae1ff"), "score": 90},
	{"name": "Büyük Dumpling",  "radius": 66.0,  "color": Color("e3baff"), "score": 110},
	{"name": "Dev Dumpling",    "radius": 84.0,  "color": Color("fff5ba"), "score": 130},
	{"name": "Jumbo Dumpling",  "radius": 106.0, "color": Color("ffab76"), "score": 150},
	{"name": "Dumpling Kralı",  "radius": 132.0, "color": Color("ff6b8a"), "score": 200},
]


static func radius(tier: int) -> float:
	return TIERS[tier - 1]["radius"]


static func color(tier: int) -> Color:
	return TIERS[tier - 1]["color"]


## Bu tier'a birleşildiğinde kazanılan puan. Tier 1'inki hiç kullanılmaz
## (tier 1'e birleşilmez), o yüzden 0.
## M2'de KİLİTLENDİ: bu tabloyla tier 8'e ulaşan oyuncunun skoru medyan
## ~4740 oluyor, level 10'un 5000 hedefine 2-3 merge kalıyor.
static func merge_score(tier: int) -> int:
	return TIERS[tier - 1]["score"]


static func tier_name(tier: int) -> String:
	return TIERS[tier - 1]["name"]


## Merge sesinin pitch'i her tier'da biraz daha yüksek (GAME_DESIGN.md §6).
static func merge_pitch(tier: int) -> float:
	return 0.85 + 0.09 * float(tier - 1)


static func random_drop_tier() -> int:
	return randi_range(1, DROP_POOL_MAX_TIER)
