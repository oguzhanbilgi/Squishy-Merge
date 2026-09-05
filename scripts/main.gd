extends Node2D
## Uygulamanın giriş noktası. M1'de doğrudan oyun tahtasını yükler;
## menü/level akışı M2'de buraya bağlanacak.

const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")


func _ready() -> void:
	add_child(GAME_BOARD_SCENE.instantiate())
