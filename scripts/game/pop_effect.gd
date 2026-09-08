extends Node2D
## Merge anindaki parcacik patlamasi (GAME_DESIGN.md §1, M8 juice pasi).
##
## Tier'a gore olcekleniyor: kucuk tier'da birkac soluk nokta, tier 8'de
## genis + parlak nokta patlamasi ustune bir parilti katmani. Amac, her
## merge'in "boyutu kadar" hissettirmesi.

const DOT_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_dot.png")
const SPARKLE_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_sparkle.png")

## Parilti katmani bu tier'dan itibaren devreye giriyor — her merge'de
## parilti olsa etki degersizlesirdi.
const SPARKLE_MIN_TIER: int = 5

@onready var _dots: CPUParticles2D = $Dots
@onready var _sparkles: CPUParticles2D = $Sparkles


## `tier` yeni olusan dumpling'in tier'i (2..8).
func burst(burst_color: Color, burst_radius: float, tier: int) -> void:
	var celebratory: bool = tier >= TierConfig.MAX_TIER
	# 0 (tier 2) -> 1 (tier 8): tum olcekleme bu tek orandan turuyor.
	var t: float = clampf(float(tier - 2) / float(TierConfig.MAX_TIER - 2), 0.0, 1.0)

	_dots.texture = DOT_TEXTURE
	_dots.emitting = false
	_dots.one_shot = true
	_dots.explosiveness = 1.0
	_dots.lifetime = lerpf(0.35, 0.75, t)
	_dots.amount = int(lerpf(10.0, 40.0, t)) * (2 if celebratory else 1)
	_dots.direction = Vector2.UP
	_dots.spread = 180.0
	_dots.gravity = Vector2(0.0, 900.0)
	_dots.initial_velocity_min = burst_radius * lerpf(2.5, 5.0, t)
	_dots.initial_velocity_max = burst_radius * lerpf(5.0, 10.0, t)
	# Parçacık boyutu tier'la büyüsün ama parçanın kendisiyle yarışmasın:
	# kaynak texture 128 px, yani ölçek = (istenen çap / 128). Katsayılar
	# parçacık çapını yarıçapın ~%20-50'sinde tutuyor. Daha büyük değerler
	# (ilk deneme 0.004-0.014) 100 px yarıçapta 180 px'lik halkalar üretip
	# patlamayı "kabarcık duvarı" gibi gösteriyordu.
	_dots.scale_amount_min = burst_radius * 0.0015
	_dots.scale_amount_max = burst_radius * lerpf(0.0028, 0.004, t)
	_dots.color = burst_color
	_dots.emitting = true

	if tier >= SPARKLE_MIN_TIER:
		_sparkles.texture = SPARKLE_TEXTURE
		_sparkles.emitting = false
		_sparkles.one_shot = true
		_sparkles.explosiveness = 1.0
		_sparkles.lifetime = lerpf(0.5, 0.9, t)
		_sparkles.amount = int(lerpf(5.0, 18.0, t))
		_sparkles.direction = Vector2.UP
		_sparkles.spread = 180.0
		_sparkles.gravity = Vector2(0.0, 260.0)
		_sparkles.initial_velocity_min = burst_radius * 1.5
		_sparkles.initial_velocity_max = burst_radius * 4.0
		_sparkles.scale_amount_min = burst_radius * 0.002
		_sparkles.scale_amount_max = burst_radius * 0.006
		# Parilti beyaza dogru kirilsin ki tier renginin ustunde okunsun.
		_sparkles.color = burst_color.lerp(Color.WHITE, 0.6)
		_sparkles.emitting = true

	var longest: float = maxf(_dots.lifetime, _sparkles.lifetime if _sparkles.emitting else 0.0)
	await get_tree().create_timer(longest + 0.2).timeout
	queue_free()
