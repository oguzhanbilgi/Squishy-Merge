class_name SkinSwatch
extends Control
## Koleksiyon kartındaki placeholder skin görseli: dolu bir daire + rarity
## renginde çerçeve. Açılmamış skin'de daire düz silüet rengine düşer
## (GAME_DESIGN.md §5.3). Gerçek skin görselleri M7'de owner'dan gelecek.

var fill_color: Color = Color.WHITE
var ring_color: Color = Color.WHITE
var unlocked: bool = false


func setup(new_fill: Color, new_ring: Color, is_unlocked: bool) -> void:
	fill_color = new_fill
	ring_color = new_ring
	unlocked = is_unlocked
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.42
	draw_circle(center, radius, fill_color)
	var ring := ring_color
	if not unlocked:
		ring.a = 0.35
	draw_arc(center, radius, 0.0, TAU, 48, ring, 4.0, true)
	if unlocked:
		# Küçük bir parlama — açık skin'i bir bakışta ayırt etmek için.
		draw_circle(center - Vector2(radius * 0.3, radius * 0.35), radius * 0.18,
			Color(1, 1, 1, 0.45))
