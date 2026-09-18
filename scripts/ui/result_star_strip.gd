class_name ResultStarStrip
extends Control
## Round sonu yıldız şeridi (M8.6-09). Sonucun ana görsel çapası: üç owner
## yıldızı yay üzerinde (ortadaki büyük ve yukarıda). Kazanılan yıldız dolu
## altın; kazanılmayan, owner'ın kontur yıldızından türetilmiş yumuşak
## lavanta çizgi (`tools/make_result_art.py`) — "üç kez kaybettin" gibi
## okunan soluk altın konturlar kalktı.
##
## Reveal: `set_stars(earned, hidden)` kazanılanları 0 ölçekte bekletir,
## `reveal(index)` tek yıldızı yayla açar (küçük pop + 5 mini yıldız
## pırıltısı, ~0.4 s, deterministik açılar, parçacık düğümü yok). Ses ve
## zamanlama sahibinde (`RoundResult`): şerit yalnız çizer.
##
## Sonsuz modda yıldız yok (GAME_DESIGN §5.1) — sahibi şeridi gizler.

const STAR_FILLED: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
const STAR_EMPTY_SOFT: Texture2D = preload("res://assets/visual/ui/icon_star_empty_soft.png")
## Yan yıldız / orta yıldız kutusu (owner sanatı 130×126, oran korunur),
## ortadaki `MIDDLE_RAISE` px yukarıda: klasik casual yay.
const SIDE_SIZE: float = 86.0
const MIDDLE_SIZE: float = 104.0
const MIDDLE_RAISE: float = 16.0
const GAP: float = 10.0
const HEIGHT: float = 126.0
## Kazanılmayan yıldızın boyası (krem gövde üstünde yumuşak lavanta).
const EMPTY_TINT: Color = Color("c9b3e6")
## Pop: 0 → 1.28 → 1.0 (yay), toplam ~0.34 s.
const POP_OVERSHOOT: float = 1.28
const POP_IN: float = 0.16
const POP_SETTLE: float = 0.14
const SPARK_COUNT: int = 5
const SPARK_TIME: float = 0.42
const SPARK_RADIUS: float = 58.0
const SPARK_SIZE: float = 16.0

var _stars: Array[TextureRect] = []
var _earned: int = 0
var _tweens: Array[Tween] = []


func _init() -> void:
	name = "StarStrip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SIDE_SIZE * 2.0 + MIDDLE_SIZE + GAP * 2.0, HEIGHT)
	for i in 3:
		var star := UiKit.art(STAR_FILLED, MIDDLE_SIZE if i == 1 else SIDE_SIZE)
		star.name = "Star%d" % (i + 1)
		star.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(star)
		_stars.append(star)
	resized.connect(_layout)
	_layout()


## `earned` 0–3. `hidden` true ise kazanılan yıldızlar 0 ölçekte bekler
## (reveal ile açılır); false ise hepsi hemen görünür (test / durum).
func set_stars(earned: int, hidden: bool) -> void:
	_kill_tweens()
	_earned = clampi(earned, 0, 3)
	for i in 3:
		var star: TextureRect = _stars[i]
		var is_earned: bool = i < _earned
		star.texture = STAR_FILLED if is_earned else STAR_EMPTY_SOFT
		star.self_modulate = Color.WHITE if is_earned else EMPTY_TINT
		star.modulate = Color.WHITE
		star.scale = Vector2.ZERO if (is_earned and hidden) else Vector2.ONE
	_layout()


## `index`. yıldızı açar (kazanılmış olmalı). Pop + pırıltı; sahibi sesi çalar.
func reveal(index: int) -> void:
	if index < 0 or index >= _earned:
		return
	var star: TextureRect = _stars[index]
	star.scale = Vector2.ZERO
	var tween: Tween = star.create_tween()
	tween.tween_property(star, "scale", Vector2.ONE * POP_OVERSHOOT, POP_IN) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(star, "scale", Vector2.ONE, POP_SETTLE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tweens.append(tween)
	_sparkle(star)


## Kazanılan yıldız sayısı (test).
func earned() -> int:
	return _earned


## Yıldız düğümleri (test: doku / ölçek / renk).
func stars() -> Array[TextureRect]:
	return _stars


## Bütün kazanılan yıldızlar tam ölçekte mi (reveal bitti mi)?
func all_revealed() -> bool:
	for i in _earned:
		if not _stars[i].scale.is_equal_approx(Vector2.ONE):
			return false
	return true


func _layout() -> void:
	var total: float = SIDE_SIZE * 2.0 + MIDDLE_SIZE + GAP * 2.0
	var x: float = (size.x - total) * 0.5
	var center_y: float = size.y * 0.5 + MIDDLE_RAISE * 0.5
	for i in 3:
		var star: TextureRect = _stars[i]
		var box: float = MIDDLE_SIZE if i == 1 else SIDE_SIZE
		var raise: float = MIDDLE_RAISE if i == 1 else 0.0
		star.size = Vector2(box, box)
		star.position = Vector2(x, center_y - box * 0.5 - raise)
		star.pivot_offset = star.size * 0.5
		x += box + GAP


## Beş mini altın yıldız yıldızın merkezinden dışarı süzülür ve söner.
## Deterministik açılar; RNG yok; biten düğümler silinir.
func _sparkle(star: TextureRect) -> void:
	var center: Vector2 = star.position + star.size * 0.5
	for i in SPARK_COUNT:
		var angle: float = TAU * float(i) / float(SPARK_COUNT) - PI * 0.5 + 0.35
		var box: float = SPARK_SIZE if i % 2 == 0 else SPARK_SIZE * 0.72
		var spark := UiKit.art(STAR_FILLED, box)
		spark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		spark.position = center - Vector2(box, box) * 0.5
		spark.size = Vector2(box, box)
		spark.pivot_offset = spark.size * 0.5
		add_child(spark)
		var target: Vector2 = spark.position + Vector2.from_angle(angle) * SPARK_RADIUS * (1.0 if i % 2 == 0 else 0.8)
		var tween: Tween = spark.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", target, SPARK_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "scale", Vector2.ONE * 0.3, SPARK_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(spark, "modulate:a", 0.0, SPARK_TIME * 0.55).set_delay(SPARK_TIME * 0.45)
		tween.chain().tween_callback(spark.queue_free)


func _kill_tweens() -> void:
	for tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
