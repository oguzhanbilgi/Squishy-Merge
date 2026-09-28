class_name PlayerProfile
extends RefCounted
## Profil (TASK/044) — oyuncu kimliği, vitrin ve istatistiklerin TEK okuma API'si.
## TASK/045: Oyuncu Seviyesi / XP, başarım satırları ve unvanlar da buradan okunur
## (kural katmanı PlayerProgression + AchievementCatalog, kayıt SaveManager).
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

## Görünen ad (TASK/044): nötr ve yerel. Düzenlenebilir takma ad YOK (TASK/045 de
## eklemedi). Hesap / sunucu / kimlik iddiası YOK.
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


# --- Oyuncu Seviyesi / başarımlar / unvanlar (TASK/045) ----------------------------

static func player_xp() -> int:
	return SaveManager.player_xp()


static func player_level() -> int:
	return PlayerProgression.level_for_xp(player_xp())


## Seviye içi ilerleme: {level, xp, into, required, ratio} — ray "into / required XP".
static func level_progress() -> Dictionary:
	var xp: int = player_xp()
	return {
		"level": PlayerProgression.level_for_xp(xp),
		"xp": xp,
		"into": PlayerProgression.xp_into_level(xp),
		"required": PlayerProgression.xp_required_for_next(xp),
		"ratio": PlayerProgression.level_ratio(xp),
	}


static func selected_title_id() -> StringName:
	return SaveManager.selected_title_id()


static func selected_title_name() -> String:
	return AchievementCatalog.title_name(selected_title_id())


static func achievements_unlocked_count() -> int:
	return SaveManager.unlocked_achievements().size()


static func achievements_total() -> int:
	return AchievementCatalog.count()


## Tek başarımın ekran satırı: {id, name, description, metric, target, value (hedefe
## kırpılmış; açıksa hedef), unlocked, title_id, title_name}. Bilinmeyen id boş.
static func achievement_row(id: StringName) -> Dictionary:
	return _achievement_row(id, SaveManager.progression_stats(), SaveManager.unlocked_achievements())


## Katalog sırasıyla bütün başarım satırları (başarımlar penceresi).
static func achievement_rows() -> Array[Dictionary]:
	var stats: Dictionary = SaveManager.progression_stats()
	var unlocked: Array[StringName] = SaveManager.unlocked_achievements()
	var rows: Array[Dictionary] = []
	for id in AchievementCatalog.ids():
		rows.append(_achievement_row(id, stats, unlocked))
	return rows


## Profil özeti: sıradaki hedefler (AchievementCatalog.next_goals — en fazla 3).
static func next_goal_rows(limit: int = 3) -> Array[Dictionary]:
	var stats: Dictionary = SaveManager.progression_stats()
	var unlocked: Array[StringName] = SaveManager.unlocked_achievements()
	var rows: Array[Dictionary] = []
	for id in AchievementCatalog.next_goals(stats, unlocked, limit):
		rows.append(_achievement_row(id, stats, unlocked))
	return rows


static func _achievement_row(id: StringName, stats: Dictionary, unlocked: Array) -> Dictionary:
	var entry: Dictionary = AchievementCatalog.find(id)
	if entry.is_empty():
		return {}
	var goal: int = int(entry["target"])
	var is_open: bool = unlocked.has(id)
	var title_id: StringName = AchievementCatalog.title_for_achievement(id)
	return {
		"id": id,
		"name": String(entry["name"]),
		"description": String(entry["description"]),
		"metric": entry["metric"],
		"target": goal,
		"value": goal if is_open else mini(AchievementCatalog.progress(id, stats), goal),
		"unlocked": is_open,
		"title_id": title_id,
		"title_name": AchievementCatalog.title_name(title_id) if title_id != &"" else "",
	}


## Unvan seçicinin satırları (katalog sırası): {id, name, unlocked, selected,
## source_id, source_name, source_description}.
static func title_rows() -> Array[Dictionary]:
	var unlocked: Array = SaveManager.unlocked_achievements()
	var selected: StringName = selected_title_id()
	var rows: Array[Dictionary] = []
	for id in AchievementCatalog.title_ids():
		var source: StringName = AchievementCatalog.title_source(id)
		var source_entry: Dictionary = AchievementCatalog.find(source)
		rows.append({
			"id": id,
			"name": AchievementCatalog.title_name(id),
			"unlocked": AchievementCatalog.is_title_unlocked(id, unlocked),
			"selected": id == selected,
			"source_id": source,
			"source_name": String(source_entry.get("name", "")),
			"source_description": String(source_entry.get("description", "")),
		})
	return rows


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
		"player_xp": player_xp(),
		"player_level": player_level(),
		"title": String(selected_title_id()),
		"achievements_unlocked": achievements_unlocked_count(),
		"achievements_total": achievements_total(),
	}
