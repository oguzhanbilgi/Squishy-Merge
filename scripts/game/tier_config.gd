class_name TierConfig
extends RefCounted
## 8 tier'ın veri tablosu (GAME_DESIGN.md §2).
##
## RENKLER artık gövde tint'i DEĞİL. M8'de owner'ın kendi karakter
## sprite'larına geçildi; sprite'lar kendi rengiyle geliyor ve üzerlerine
## modulate uygulanmıyor (bkz. scripts/game/dumpling_visual.gd).
## Buradaki değerler yalnızca merge parçacıklarının ve efektlerin rengi.
## Sprite'lardan örneklendiler (tools/make_character_sprites.gd baskın tonu
## raporluyor) — aksi hâlde mavi tier 8'in üstünde kırmızı parçacık patlardı.
## Sprite değişirse bu diziyi de yeniden örnekle.
##
const MAX_TIER: int = 8

## Drop pool: sadece tier 1-3 rastgele düşer (GAME_DESIGN.md §2).
const DROP_POOL_MAX_TIER: int = 3

const TIERS: Array[Dictionary] = [
	{"name": "Mini Dumpling",   "radius": 22.0,  "color": Color("fbde8d"), "score": 0},
	{"name": "Küçük Dumpling",  "radius": 27.0,  "color": Color("fca7c7"), "score": 50},
	{"name": "Dumpling",        "radius": 34.0,  "color": Color("9bebac"), "score": 70},
	{"name": "Şişkin Dumpling", "radius": 42.0,  "color": Color("95cdf9"), "score": 90},
	{"name": "Büyük Dumpling",  "radius": 52.0,  "color": Color("d3a3f1"), "score": 110},
	{"name": "Dev Dumpling",    "radius": 65.0,  "color": Color("fddf76"), "score": 130},
	{"name": "Jumbo Dumpling",  "radius": 81.0, "color": Color("fca4cc"), "score": 150},
	{"name": "Dumpling Kralı",  "radius": 100.0, "color": Color("a3c4e0"), "score": 200},
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


## Yıldız eşikleri (GAME_DESIGN.md §5.1). Bir tier'a ULAŞAN oyuncuların o
## andaki skor dağılımının p50 ve p85'i; tools/star_thresholds.py ile Monte
## Carlo simülasyonundan (40.000 örnek) üretildi. Index = tier.
##
## DİKKAT: merge puan tablosu değişirse bu diziler ESKİR — script'i tekrar
## çalıştırıp buraya yazmak gerekir. (Eskiden koddan hesaplanıyordu; percentile
## eşikleri kapalı formülle çıkmadığı için artık sabit.)
const SCORE_P50: Array[int] = [0, 0, 0, 0, 160, 430, 1040, 2260, 4730]
const SCORE_P85: Array[int] = [0, 0, 0, 0, 210, 530, 1190, 2430, 4990]


static func score_p50(tier: int) -> int:
	return SCORE_P50[tier]


static func score_p85(tier: int) -> int:
	return SCORE_P85[tier]
