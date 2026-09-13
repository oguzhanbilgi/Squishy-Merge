class_name MapTrail
extends Control
## Harita düğümlerini bağlayan candy patika (M8.5-12). Programatik: yeni
## asset yok. Düğüm merkezlerinden geçen yumuşak bir eğri (Catmull-Rom),
## üstünde küçük nokta işaretleri.
##
##   tamamlanmış segment  : sıcak krem-altın, opak
##   sıradaki segment     : aynı renk, `lit` (0..1) kadarı yanmış — açılış
##                          animasyonu bu değeri 0'dan 1'e sürer
##   gelecek segmentler   : soluk beyaz, düşük alfa
##
## Zeminle yarışmasın diye çizgi ince (6 px) ve altında yumuşak koyu bir
## gölge çizgisi var; pembe zemin üstünde krem okunuyor.

const LINE_WIDTH: float = 6.0
const SHADOW_WIDTH: float = 10.0
const DOT_SPACING: float = 26.0
const DOT_RADIUS: float = 3.2
const CURVE_STEPS: int = 12

const DONE_COLOR: Color = Color(1.0, 0.93, 0.72, 0.95)
const DONE_DOT: Color = Color(1.0, 0.82, 0.4, 1.0)
const FUTURE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.32)
const FUTURE_DOT: Color = Color(1.0, 1.0, 1.0, 0.45)
const SHADOW_COLOR: Color = Color(0.25, 0.1, 0.3, 0.28)

## Düğüm merkezleri (bu kontrolün yerel uzayında), sırayla.
var _points: PackedVector2Array = PackedVector2Array()
## Tamamlanmış segment sayısı (0..n-1): i < done ise segment i sıcak.
var _done: int = 0
## `done` indeksli segmentin ne kadarı yanmış (0..1). Açılış animasyonu.
var lit: float = 0.0:
	set(value):
		lit = clampf(value, 0.0, 1.0)
		queue_redraw()


func set_trail(points: PackedVector2Array, done_segments: int, lit_amount: float = 0.0) -> void:
	_points = points
	_done = done_segments
	lit = lit_amount
	queue_redraw()


func set_done(done_segments: int) -> void:
	_done = done_segments
	queue_redraw()


func _draw() -> void:
	if _points.size() < 2:
		return
	for i in _points.size() - 1:
		var poly: PackedVector2Array = _segment(i)
		var done: bool = i < _done
		var partial: float = lit if i == _done else 0.0
		draw_polyline(poly, SHADOW_COLOR, SHADOW_WIDTH, true)
		if done:
			draw_polyline(poly, DONE_COLOR, LINE_WIDTH, true)
		else:
			draw_polyline(poly, FUTURE_COLOR, LINE_WIDTH, true)
			if partial > 0.0:
				var cut: int = int(round(float(poly.size() - 1) * partial))
				if cut >= 1:
					draw_polyline(poly.slice(0, cut + 1), DONE_COLOR, LINE_WIDTH, true)
		_draw_dots(poly, done, partial)


## Segment üstündeki noktalar: eşit aralıklı, uçlardaki düğümlerin altında
## kalanlar atlanıyor (düğüm 96 px, yarıçap 48 + pay).
func _draw_dots(poly: PackedVector2Array, done: bool, partial: float) -> void:
	var lengths: Array[float] = [0.0]
	for i in range(1, poly.size()):
		lengths.append(lengths[i - 1] + poly[i - 1].distance_to(poly[i]))
	var total: float = lengths[poly.size() - 1]
	var lit_len: float = total * partial
	var d: float = 54.0
	while d < total - 54.0:
		var at: Vector2 = _point_at(poly, lengths, d)
		var warm: bool = done or d <= lit_len
		draw_circle(at + Vector2(0, 1.5), DOT_RADIUS + 1.2, SHADOW_COLOR)
		draw_circle(at, DOT_RADIUS, DONE_DOT if warm else FUTURE_DOT)
		d += DOT_SPACING


func _point_at(poly: PackedVector2Array, lengths: Array[float], d: float) -> Vector2:
	for i in range(1, poly.size()):
		if lengths[i] >= d:
			var t: float = (d - lengths[i - 1]) / maxf(0.001, lengths[i] - lengths[i - 1])
			return poly[i - 1].lerp(poly[i], t)
	return poly[poly.size() - 1]


## i. düğümden i+1. düğüme Catmull-Rom eğrisi (uç noktalar tekrarlanarak).
func _segment(i: int) -> PackedVector2Array:
	var p0: Vector2 = _points[maxi(i - 1, 0)]
	var p1: Vector2 = _points[i]
	var p2: Vector2 = _points[i + 1]
	var p3: Vector2 = _points[mini(i + 2, _points.size() - 1)]
	var out := PackedVector2Array()
	for s in CURVE_STEPS + 1:
		var t: float = float(s) / float(CURVE_STEPS)
		out.append(_catmull(p0, p1, p2, p3, t))
	return out


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
