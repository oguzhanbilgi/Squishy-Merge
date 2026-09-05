class_name LevelData
extends Resource
## Tek bir level'ın verisi. Yeni level eklemek için kod değiştirmeye gerek yok:
## resources/levels/ altına yeni bir .tres koymak yeterli (LevelLibrary klasörü
## tarayıp level_number'a göre sıralıyor).

## Level sırası. Sonsuz modda kullanılmaz.
@export var level_number: int = 1

## Hedef: bu tier'a ulaş. Sonsuz modda 0 (hedef yok).
@export var target_tier: int = 4

## Ek hedef: bu skora da ulaş. 0 = skor hedefi yok.
@export var target_score: int = 0

## Kabın iç genişliği (px). GAME_DESIGN.md §3'teki geniş/orta/dar etiketlerinin
## ölçümle belirlenmiş karşılığı.
@export var container_width: float = 600.0

## Taban ile taşma çizgisi arası (px). M1'de ölçülerek 400'de kilitlendi.
@export var playable_height: float = 400.0

## Saniye. 0 = süre limiti yok.
@export var time_limit: float = 0.0

## Sonsuz mod: hedef ve süre yok, sadece skor ve kişisel rekor.
@export var is_endless: bool = false


func has_time_limit() -> bool:
	return time_limit > 0.0


func has_score_target() -> bool:
	return target_score > 0


func display_name() -> String:
	return "Sonsuz Mod" if is_endless else "Level %d" % level_number


## Hedef metni — HUD ve level seçim ekranı aynı ifadeyi kullansın diye burada.
func objective_text() -> String:
	if is_endless:
		return "Hedef yok — skorunu yükselt"
	var text: String = "Hedef: %s" % TierConfig.tier_name(target_tier)
	if has_score_target():
		text += " + %d skor" % target_score
	return text
