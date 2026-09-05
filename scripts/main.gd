extends Node2D
## Akış kontrolü: level seçim -> oyun -> sonuç -> level seçim.
## Oyun kuralları GameBoard'da, ilerleme SaveManager'da; burada sadece
## hangi ekranın açık olduğu tutuluyor.

const LEVEL_SELECT_SCENE: PackedScene = preload("res://scenes/ui/level_select.tscn")
const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const ROUND_RESULT_SCENE: PackedScene = preload("res://scenes/ui/round_result.tscn")

## Round bitip sonuç ekranı açılmadan önceki kısa nefes payı — son merge'in
## efekti ekranda kalsın diye.
const RESULT_DELAY: float = 0.8

var _select: CanvasLayer
var _board: Node2D
var _result: CanvasLayer
var _current_level: LevelData


func _ready() -> void:
	_result = ROUND_RESULT_SCENE.instantiate()
	_result.retry_pressed.connect(_on_retry_pressed)
	_result.exit_pressed.connect(_on_exit_pressed)
	add_child(_result)

	_select = LEVEL_SELECT_SCENE.instantiate()
	_select.level_chosen.connect(_start_level)
	add_child(_select)


func _start_level(level: LevelData) -> void:
	_current_level = level
	_select.visible = false
	_result.hide_result()
	_clear_board()

	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(level)
	_board.round_finished.connect(_on_round_finished)
	add_child(_board)


func _clear_board() -> void:
	if _board != null:
		_board.queue_free()
		_board = null


func _on_round_finished(won: bool) -> void:
	var score: int = GameState.score
	var new_record: bool = false

	if _current_level.is_endless:
		new_record = SaveManager.record_endless_score(score)
	elif won:
		SaveManager.complete_level(_current_level.level_number)

	await get_tree().create_timer(RESULT_DELAY).timeout
	_result.show_result(_current_level, won, score, new_record)


func _on_retry_pressed() -> void:
	_start_level(_current_level)


func _on_exit_pressed() -> void:
	_result.hide_result()
	_clear_board()
	_select.refresh()
	_select.visible = true
