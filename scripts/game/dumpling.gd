class_name Dumpling
extends RigidBody2D
## Tek bir dumpling parçası. Aynı tier'daki iki dumpling çarpışınca
## merge_requested yayınlanır; birleştirmeyi GameBoard yürütür.
## Her çarpmada hıza orantılı bir squash-stretch oynar — "yapışma" hissini
## kıran asıl şey bu (merge anındaki squash tek başına yetmiyor).
## Squash cisim türüne bakmaz: duvar, taban ve diğer dumpling'ler aynı
## mantıktan geçer.

signal merge_requested(a: Dumpling, b: Dumpling, point: Vector2)

## Bu hızın altındaki temaslar squash tetiklemez (yerleşmiş yığındaki
## sürekli mikro temaslar titreşim yaratmasın diye).
const IMPACT_SPEED_MIN: float = 60.0
## Bu hızda squash genliği tavana vurur.
const IMPACT_SPEED_MAX: float = 900.0
const IMPACT_SQUASH_MIN: float = 0.08
const IMPACT_SQUASH_MAX: float = 0.25
const IMPACT_SQUASH_DURATION: float = 0.12
## Aynı parça bu süre içinde ikinci kez squash tetikleyemez.
const IMPACT_DEBOUNCE: float = 0.13

var tier: int = 1
## Sonsuz modda iki tier 8 birbirini yok eder (GAME_DESIGN.md §4). Level
## modunda tier 8 hiçbir şeyle birleşmez, normal bir parça gibi kalır —
## §1'deki karar. Bayrağı GameBoard spawn sırasında set ediyor.
var annihilates_at_max: bool = false
## Merge kuyruğa alındıysa true — aynı kare içinde ikinci kez birleşmeyi önler.
var is_merging: bool = false
## İlk çarpışmasını yaşadı mı? Taşma kontrolü sadece yerleşmiş parçaları sayar,
## yoksa drop çizgisinden geçen her parça yanlışlıkla taşma sayılır.
var has_landed: bool = false

## Çarpışma çözülmeden önceki hız. body_entered tetiklendiğinde linear_velocity
## çoktan sönümlenmiş olabiliyor, o yüzden yaklaşma hızını ayrıca tutuyoruz.
var _approach_speed: float = 0.0
var _squash_cooldown: float = 0.0

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
	# Owner kararı: parçalar top gibi hafifçe seksin (birbirine ve duvara).
	# Duvarda da aynı değer var; Godot ikisini birleştirdiği için efektif
	# sekme ~0.24 oluyor. Ölçüm: 0.13 -> ~47 px sekme, yığın ~2.8 sn'de
	# duruluyor. 0.18+ denendi, yığın 6 sn oynamaya devam ediyor.
	material.bounce = 0.13
	physics_material_override = material

	# Düşük damping: yüksek değer "yüzüyor" hissi veriyor.
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.15

	# Serbest dönüş açık kalmalı — parçaların yuvarlanıp boşluklara oturması
	# "canlı" hissin büyük parçası.
	lock_rotation = false

	# Yarıçapla orantılı kütle — büyük tier'lar ağır hissetsin.
	mass = TierConfig.radius(tier) * 0.05

	_visual.setup(tier)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	# Fizik adımı çözülmeden önceki hız: çarpma anındaki yaklaşma hızı bu.
	_approach_speed = linear_velocity.length()
	if _squash_cooldown > 0.0:
		_squash_cooldown = maxf(0.0, _squash_cooldown - delta)


func play_squash() -> void:
	_visual.play_squash()


# --- Güç hedefleme (M8.5-03) ---
#
# Görsel iş DumplingVisual'da; buradaki tek sorumluluk onu iletmek.

## Bu parça şu an geçerli bir güç hedefi mi? Vurgu/nabız buna göre açılır.
func set_targetable(targetable: bool) -> void:
	_visual.set_targetable(targetable)


## Bomba kilitlendiğinde oynayan kısa vurgu.
func play_lock_on() -> void:
	_visual.play_lock_on()


func _on_body_entered(body: Node) -> void:
	has_landed = true
	_try_impact_squash()

	if is_merging or (tier >= TierConfig.MAX_TIER and not annihilates_at_max):
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


func _try_impact_squash() -> void:
	if _squash_cooldown > 0.0:
		return
	var speed: float = maxf(_approach_speed, linear_velocity.length())
	if speed < IMPACT_SPEED_MIN:
		return
	var t: float = clampf((speed - IMPACT_SPEED_MIN) / (IMPACT_SPEED_MAX - IMPACT_SPEED_MIN), 0.0, 1.0)
	_squash_cooldown = IMPACT_DEBOUNCE
	_visual.play_squash(lerpf(IMPACT_SQUASH_MIN, IMPACT_SQUASH_MAX, t), IMPACT_SQUASH_DURATION)
