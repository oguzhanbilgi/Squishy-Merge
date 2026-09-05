class_name Dumpling
extends RigidBody2D
## Tek bir dumpling parçası. Aynı tier'daki iki dumpling çarpışınca
## merge_requested yayınlanır; birleştirmeyi GameBoard yürütür.

signal merge_requested(a: Dumpling, b: Dumpling, point: Vector2)

var tier: int = 1
## Merge kuyruğa alındıysa true — aynı kare içinde ikinci kez birleşmeyi önler.
var is_merging: bool = false
## İlk çarpışmasını yaşadı mı? Taşma kontrolü sadece yerleşmiş parçaları sayar,
## yoksa drop çizgisinden geçen her parça yanlışlıkla taşma sayılır.
var has_landed: bool = false

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: Node2D = $Visual


func setup(new_tier: int) -> void:
	tier = new_tier


func _ready() -> void:
	var circle := CircleShape2D.new()
	circle.radius = TierConfig.radius(tier)
	_shape.shape = circle

	var material := PhysicsMaterial.new()
	material.friction = 0.55
	material.bounce = 0.05
	physics_material_override = material

	# Yarıçapla orantılı kütle — büyük tier'lar ağır hissetsin.
	mass = TierConfig.radius(tier) * 0.05

	_visual.setup(TierConfig.radius(tier), TierConfig.color(tier))
	body_entered.connect(_on_body_entered)


func play_squash() -> void:
	_visual.play_squash()


func _on_body_entered(body: Node) -> void:
	has_landed = true

	if is_merging or tier >= TierConfig.MAX_TIER:
		return
	var other := body as Dumpling
	if other == null or other.is_merging or other.tier != tier:
		return

	# Her iki taraf da bu callback'i alır; merge'i yalnızca biri yürütsün.
	if get_instance_id() < other.get_instance_id():
		return

	is_merging = true
	other.is_merging = true
	merge_requested.emit(self, other, (global_position + other.global_position) * 0.5)
