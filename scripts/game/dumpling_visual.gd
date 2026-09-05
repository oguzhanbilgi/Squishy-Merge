extends Node2D
## Placeholder görsel: düz renkli daire. M7'de owner'ın asset'iyle değişecek.

var radius: float = 20.0
var fill_color: Color = Color.WHITE

var _tween: Tween


func setup(new_radius: float, new_color: Color) -> void:
	radius = new_radius
	fill_color = new_color
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, fill_color.darkened(0.25), 3.0, true)


## Squash-stretch. Merge'de tam genlik (GAME_DESIGN.md §1: 1.0 -> 1.2/0.8 -> 1.0,
## ~150 ms); çarpmada aynı tween'in hıza orantılı hafif versiyonu.
func play_squash(amount: float = 0.2, duration: float = 0.15) -> void:
	# Önceki squash hâlâ oynuyorsa kes — üst üste binince titreşim oluyor.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	scale = Vector2.ONE
	var half: float = duration * 0.5
	_tween = create_tween()
	var squashed := Vector2(1.0 + amount, 1.0 - amount)
	_tween.tween_property(self, "scale", squashed, half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, half).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
