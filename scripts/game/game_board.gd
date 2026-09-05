extends Node2D
## Oyun tahtası: kap, drop kontrolü, merge çözümü ve taşma (fail) kontrolü.
## GAME_DESIGN.md §1-2. Level/süre/hedef mantığı M2'de eklenecek.

signal game_over

const DUMPLING_SCENE: PackedScene = preload("res://scenes/game/dumpling.tscn")
const POP_EFFECT_SCENE: PackedScene = preload("res://scenes/game/pop_effect.tscn")

const WALL_THICKNESS: float = 20.0
## Taşma çizgisine bu süre boyunca temas edilirse round biter (GAME_DESIGN.md §1).
const OVERFLOW_GRACE: float = 1.5
const DROP_COOLDOWN: float = 0.4

## Kabın iç genişliği. M2'de level verisinden gelecek; şimdilik sabit.
@export var container_width: float = 600.0
@export var container_top_y: float = 240.0
@export var floor_y: float = 1180.0
@export var overflow_line_y: float = 300.0
@export var drop_line_y: float = 170.0

var _aim_x: float = 360.0
var _pending_tier: int = 1
var _next_tier: int = 1
var _drop_cooldown: float = 0.0
var _overflow_elapsed: float = 0.0
var _is_game_over: bool = false

@onready var _walls: StaticBody2D = $Walls
@onready var _dumpling_layer: Node2D = $DumplingLayer
@onready var _overflow_area: Area2D = $OverflowArea
@onready var _overflow_shape: CollisionShape2D = $OverflowArea/OverflowShape
@onready var _preview: Node2D = $Preview
@onready var _score_label: Label = $HUD/ScoreLabel
@onready var _next_label: Label = $HUD/NextLabel
@onready var _status_label: Label = $HUD/StatusLabel


func _ready() -> void:
	GameState.reset_run()
	GameState.score_changed.connect(_on_score_changed)

	_build_walls()
	_setup_overflow_area()

	_aim_x = _center_x()
	_pending_tier = TierConfig.random_drop_tier()
	_next_tier = TierConfig.random_drop_tier()
	_refresh_preview()
	_on_score_changed(GameState.score)
	_status_label.text = ""


func _left_x() -> float:
	return _center_x() - container_width * 0.5


func _right_x() -> float:
	return _center_x() + container_width * 0.5


func _center_x() -> float:
	return get_viewport_rect().size.x * 0.5


## Kap duvarları koddan kuruluyor — M2'de level başına genişlik değişebilsin diye.
func _build_walls() -> void:
	for child in _walls.get_children():
		child.queue_free()

	var height: float = floor_y - container_top_y
	_add_wall(Vector2(_left_x() - WALL_THICKNESS * 0.5, container_top_y + height * 0.5),
		Vector2(WALL_THICKNESS, height))
	_add_wall(Vector2(_right_x() + WALL_THICKNESS * 0.5, container_top_y + height * 0.5),
		Vector2(WALL_THICKNESS, height))
	_add_wall(Vector2(_center_x(), floor_y + WALL_THICKNESS * 0.5),
		Vector2(container_width + WALL_THICKNESS * 2.0, WALL_THICKNESS))
	queue_redraw()


func _add_wall(at: Vector2, size: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = at
	_walls.add_child(collision)


func _setup_overflow_area() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(container_width, 8.0)
	_overflow_shape.shape = shape
	_overflow_shape.position = Vector2(_center_x(), overflow_line_y)


func _draw() -> void:
	var wall_color := Color("6b5a52")
	var height: float = floor_y - container_top_y
	draw_rect(Rect2(_left_x() - WALL_THICKNESS, container_top_y, WALL_THICKNESS, height), wall_color)
	draw_rect(Rect2(_right_x(), container_top_y, WALL_THICKNESS, height), wall_color)
	draw_rect(Rect2(_left_x() - WALL_THICKNESS, floor_y,
		container_width + WALL_THICKNESS * 2.0, WALL_THICKNESS), wall_color)

	# Taşma çizgisi
	draw_dashed_line(Vector2(_left_x(), overflow_line_y), Vector2(_right_x(), overflow_line_y),
		Color(1.0, 0.35, 0.35, 0.55), 2.0, 12.0)


# --- Girdi: parmağı sürükle, bırakınca düşür (GAME_DESIGN.md §1) ---

func _unhandled_input(event: InputEvent) -> void:
	if _is_game_over:
		return

	var drag := event as InputEventScreenDrag
	if drag != null:
		_set_aim(drag.position.x)
		return

	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	if touch.pressed:
		_set_aim(touch.position.x)
	else:
		_drop()


func _set_aim(x: float) -> void:
	var margin: float = TierConfig.radius(_pending_tier)
	_aim_x = clampf(x, _left_x() + margin, _right_x() - margin)
	_refresh_preview()


func _refresh_preview() -> void:
	_preview.position = Vector2(_aim_x, drop_line_y)
	_preview.setup(TierConfig.radius(_pending_tier), TierConfig.color(_pending_tier))
	_preview.modulate.a = 1.0 if _drop_cooldown <= 0.0 else 0.4
	_next_label.text = "Sıradaki: %s" % TierConfig.tier_name(_next_tier)


func _drop() -> void:
	if _drop_cooldown > 0.0:
		return
	_spawn_dumpling(_pending_tier, Vector2(_aim_x, drop_line_y))
	_pending_tier = _next_tier
	_next_tier = TierConfig.random_drop_tier()
	_drop_cooldown = DROP_COOLDOWN
	_set_aim(_aim_x)


func _spawn_dumpling(tier: int, at: Vector2) -> Dumpling:
	var dumpling: Dumpling = DUMPLING_SCENE.instantiate()
	dumpling.setup(tier)
	dumpling.position = at
	dumpling.merge_requested.connect(_on_merge_requested)
	_dumpling_layer.add_child(dumpling)
	return dumpling


# --- Merge ---

func _on_merge_requested(a: Dumpling, b: Dumpling, point: Vector2) -> void:
	# Fizik callback'i içindeyiz; node ekleme/silme bir sonraki kareye ertelenmeli.
	_resolve_merge.call_deferred(a, b, point)


func _resolve_merge(a: Dumpling, b: Dumpling, point: Vector2) -> void:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return

	var new_tier: int = a.tier + 1
	a.queue_free()
	b.queue_free()

	var merged := _spawn_dumpling(new_tier, point)
	merged.play_squash()

	var celebratory: bool = new_tier == TierConfig.MAX_TIER
	_spawn_pop(point, TierConfig.color(new_tier), TierConfig.radius(new_tier), celebratory)

	GameState.add_score(TierConfig.merge_score(new_tier))
	GameState.register_merge(new_tier, point)
	# Ses dosyaları M6'da gelecek; pitch escalation mantığı şimdiden yerinde.
	AudioManager.play_sfx(null, TierConfig.merge_pitch(new_tier))

	if celebratory:
		_status_label.text = "%s!" % TierConfig.tier_name(new_tier)
		await get_tree().create_timer(2.0).timeout
		if not _is_game_over:
			_status_label.text = ""


func _spawn_pop(at: Vector2, pop_color: Color, radius: float, celebratory: bool) -> void:
	var effect: CPUParticles2D = POP_EFFECT_SCENE.instantiate()
	effect.position = at
	add_child(effect)
	effect.burst(pop_color, radius, celebratory)


# --- Taşma kontrolü ---

func _physics_process(delta: float) -> void:
	if _drop_cooldown > 0.0:
		_drop_cooldown = maxf(0.0, _drop_cooldown - delta)
		if _drop_cooldown == 0.0:
			_refresh_preview()

	if _is_game_over:
		return

	var overflowing: bool = false
	for body in _overflow_area.get_overlapping_bodies():
		var dumpling := body as Dumpling
		if dumpling != null and dumpling.has_landed and not dumpling.is_merging:
			overflowing = true
			break

	if overflowing:
		_overflow_elapsed += delta
		if _overflow_elapsed >= OVERFLOW_GRACE:
			_end_round()
	else:
		_overflow_elapsed = 0.0


func _end_round() -> void:
	_is_game_over = true
	_preview.visible = false
	_status_label.text = "Taştı! Skor: %d" % GameState.score
	game_over.emit()


func _on_score_changed(new_score: int) -> void:
	_score_label.text = "Skor: %d" % new_score
