extends Node
## Oyun boyunca yaşayan koşu-anı (run-time) durumu.
## Kalıcı veri SaveManager'da; burada sadece aktif oturumun durumu tutulur.

signal score_changed(new_score: int)
signal merge_performed(tier: int, position: Vector2)

var current_level: int = 1
var score: int = 0
var merge_count: int = 0


func reset_run() -> void:
	score = 0
	merge_count = 0
	score_changed.emit(score)


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func register_merge(tier: int, position: Vector2) -> void:
	merge_count += 1
	merge_performed.emit(tier, position)
