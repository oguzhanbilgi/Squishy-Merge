extends CPUParticles2D
## Merge anındaki küçük "pop" parçacığı (GAME_DESIGN.md §1).
## Tier 8 oluşunca daha büyük bir konfeti patlaması olarak kullanılır.


func burst(burst_color: Color, burst_radius: float, celebratory: bool = false) -> void:
	emitting = false
	one_shot = true
	explosiveness = 1.0
	lifetime = 0.7 if celebratory else 0.45
	amount = 60 if celebratory else 14
	direction = Vector2.UP
	spread = 180.0
	gravity = Vector2(0.0, 900.0)
	initial_velocity_min = burst_radius * (6.0 if celebratory else 3.0)
	initial_velocity_max = burst_radius * (11.0 if celebratory else 6.0)
	scale_amount_min = 2.0
	scale_amount_max = 5.0 if celebratory else 4.0
	color = burst_color
	emitting = true

	await get_tree().create_timer(lifetime + 0.2).timeout
	queue_free()
