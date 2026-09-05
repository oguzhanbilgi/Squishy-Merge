extends Node2D
## Placeholder görsel: düz renkli daire. M7'de owner'ın asset'iyle değişecek.

var radius: float = 20.0
var fill_color: Color = Color.WHITE


func setup(new_radius: float, new_color: Color) -> void:
	radius = new_radius
	fill_color = new_color
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, fill_color.darkened(0.25), 3.0, true)


## Squash-stretch (GAME_DESIGN.md §1): 1.0 -> 0.8/1.2 -> 1.0, ~150ms.
func play_squash() -> void:
	scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 0.8), 0.075) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.075) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
