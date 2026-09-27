extends Node
## Oyun boyunca yaşayan koşu-anı (run-time) durumu.
## Kalıcı veri SaveManager'da; burada sadece aktif oturumun durumu tutulur.

signal score_changed(new_score: int)
signal merge_performed(tier: int, position: Vector2)

var current_level: int = 1
var score: int = 0
var merge_count: int = 0
## Bu round'da OLUŞTURULAN en yüksek tier (TASK/044 profil istatistiği): merge
## (`register_merge`) ve Büyütücü (`note_tier_created`). Düşen parça sayılmaz.
## Kalıcı rekor yalnız round KESİN bitince yazılır (Main → SaveManager).
var highest_tier_created: int = 0


func reset_run() -> void:
	score = 0
	merge_count = 0
	highest_tier_created = 0
	score_changed.emit(score)


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func register_merge(tier: int, position: Vector2) -> void:
	merge_count += 1
	note_tier_created(tier)
	merge_performed.emit(tier, position)


## Merge dışında oluşturulan tier (Büyütücü, GAME_DESIGN §10.3 hedef istisnası).
## Yalnız istatistik: skor, merge sayacı ve sandık ilerlemesi DEĞİŞMEZ.
func note_tier_created(tier: int) -> void:
	if tier > highest_tier_created:
		highest_tier_created = tier
