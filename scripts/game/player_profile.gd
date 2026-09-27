class_name PlayerProfile
extends RefCounted
## Profil (TASK/044) — oyuncu kimliği, vitrin ve istatistiklerin TEK okuma API'si.
##
## Hiçbir şey YAZMAZ ve kanonik değerleri KOPYALAMAZ:
##   yıldız          level_stars toplamı (LevelLibrary'deki level'lar üzerinden)
##   harita          highest_level_unlocked (sonsuz: tüm level'lar tamam)
##   sonsuz rekor    endless_high_score
##   birleştirme     total_merges
##   koleksiyon      sahiplik (SkinEntry.owned_count — katalogdaki parçalar)
##   güç stoğu       SaveManager.powerup_count (canlı; salt okunur)
## Yalnız geri üretilemeyen iki sayaç SaveManager'da (bkz. DEFAULT_DATA notu):
## oynanan tur ve oluşturulan en yüksek tier.
##
## Gameplay'e HİÇBİR etkisi yok: profil, vitrin ve avatar yalnız görüntü.

## Görünen ad (TASK/044): nötr ve yerel. Düzenlenebilir takma ad, seviye, unvan
## ve başarımlar TASK/045'in işi — burada sahte bir sistem gösterilmez. Hesap /
## sunucu / kimlik iddiası YOK.
const DEFAULT_NAME: String = "Oyuncu"


static func display_name() -> String:
	return DEFAULT_NAME


## Avatar: vitrinin ilk parçası, vitrin boşsa kanonik Squishy (hiç null değil).
static func avatar_entry() -> SkinEntry:
	return SkinEntry.avatar_entry()


static func showcase_entries() -> Array[SkinEntry]:
	return SkinEntry.showcase_entries()


# --- İlerleme -------------------------------------------------------------------

static func level_count() -> int:
	return LevelLibrary.load_levels().size()


static func total_stars() -> int:
	var stars: int = 0
	for level in LevelLibrary.load_levels():
		stars += clampi(SaveManager.stars_for_level(level.level_number), 0, 3)
	return stars


static func max_stars() -> int:
	return level_count() * 3


static func highest_level_unlocked() -> int:
	return SaveManager.highest_level_unlocked()


static func is_endless_unlocked() -> bool:
	return SaveManager.is_endless_unlocked(level_count())


## Tamamlanan level sayısı (kilidi açılan en yüksek level'ın öncekiler).
static func completed_levels() -> int:
	return clampi(highest_level_unlocked() - 1, 0, level_count())


static func endless_high_score() -> int:
	return SaveManager.endless_high_score()


static func total_merges() -> int:
	return SaveManager.total_merges()


# --- Sayaçlar (TASK/044) ----------------------------------------------------------

## Bitmiş round sayısı (SaveManager.record_round_finished). Eski kayıtta
## `counters_partial()` true: sayı güncellemeden beri.
static func rounds_played() -> int:
	return SaveManager.total_rounds_played()


static func counters_partial() -> bool:
	return SaveManager.profile_counters_partial()


## Oluşturulan en yüksek tier (0 = henüz yok). Kayıtlı rekor ile TAMAMLANAN
## level'ların hedef tier'ı arasından büyüğü: bir level'ı bitirmek o tier'ı merge ya
## da Büyütücü ile oluşturmayı ŞART koşar (GAME_DESIGN §3 / §10.3; düşen parçalar en
## fazla tier 3, hedefler ≥ 4) — eski kayıtta da uydurma değil, kanıtlanmış alt sınır.
static func highest_tier() -> int:
	return maxi(clampi(SaveManager.highest_tier_created(), 0, TierConfig.MAX_TIER), _completed_target_tier())


## Gösterilen tier yalnız tamamlanan level'lardan türetilmiş ALT SINIR mı (kayıtlı
## rekordan büyük — sayaçlardan önceki ilerleme). Profil bunu "en az" diye yazar.
static func highest_tier_is_lower_bound() -> bool:
	return _completed_target_tier() > SaveManager.highest_tier_created()


static func _completed_target_tier() -> int:
	var best: int = 0
	var unlocked: int = highest_level_unlocked()
	for level in LevelLibrary.load_levels():
		if level.level_number < unlocked:
			best = maxi(best, level.target_tier)
	return clampi(best, 0, TierConfig.MAX_TIER)


# --- Koleksiyon -------------------------------------------------------------------

static func collection_count() -> int:
	return SkinEntry.owned_count()


static func collection_total() -> int:
	return SkinLibrary.total_count()


## Rarity sırasıyla [{rarity, owned, total}] (albüm başlığı + profil).
static func collection_by_rarity() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for rarity: SkinData.Rarity in [SkinData.Rarity.COMMON, SkinData.Rarity.RARE,
			SkinData.Rarity.EPIC, SkinData.Rarity.LEGENDARY]:
		rows.append({"rarity": rarity, "owned": SkinEntry.owned_count_by_rarity(rarity),
			"total": SkinLibrary.by_rarity(rarity).size()})
	return rows


# --- Güç envanteri ----------------------------------------------------------------

## Canlı stok, PowerUp.all() sırasıyla (Bomba / Büyütücü / Sarsıntı / Temizleyici).
static func power_counts() -> Dictionary:
	var counts: Dictionary = {}
	for type in PowerUp.all():
		counts[type] = SaveManager.powerup_count(type)
	return counts


## Testler / çekim aracı için tek anlık görüntü.
static func snapshot() -> Dictionary:
	return {
		"name": display_name(),
		"avatar": String(avatar_entry().id),
		"showcase": SaveManager.profile_showcase(),
		"endless_high_score": endless_high_score(),
		"total_merges": total_merges(),
		"total_stars": total_stars(),
		"max_stars": max_stars(),
		"highest_level_unlocked": highest_level_unlocked(),
		"endless_unlocked": is_endless_unlocked(),
		"rounds_played": rounds_played(),
		"counters_partial": counters_partial(),
		"highest_tier": highest_tier(),
		"collection_count": collection_count(),
		"collection_total": collection_total(),
		"powers": power_counts(),
	}
