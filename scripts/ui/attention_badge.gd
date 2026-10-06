class_name AttentionBadge
extends Control
## Squishy UI System V3 (TASK/057) — dikkat rozeti (kırmızı nokta karşılığı). Tek bileşen, dört görünüm:
##
##   DOT     yalnız nokta (bir şey var) — 20 px
##   COUNT   sayı (1..99, üstü "99+"); 0 → NONE
##   NEW     "YENİ" hapı
##   CLAIM   alınmaya hazır — "!" (ödülü bekleyen giriş)
##
## Mercan-kırmızı gövde + beyaz halka + alt dudak (V3 derinlik ailesi, küçük ölçek). Rozet
## yerleşimi değiştirmez: ebeveyn onu `place_at(nokta)` ile köşeye OTURTUR (merkez noktada),
## kendi boyutu içeriğe göre büyür ama ebeveynin boyutuna / minimumuna katılmaz (top_level
## değil; ebeveyn PanelContainer DEĞİL, düz Control olmalı). Fare almaz. Durum ÇAĞIRANDAN gelir
## (görev / günlük sayısı TASK/058/061'de bağlanır).

enum Mode { NONE, DOT, COUNT, NEW, CLAIM }

const DOT_SIZE: float = 20.0
const PILL_HEIGHT: float = 30.0
const RING: float = 3.0
const LIP: float = 2.0
const NEW_TEXT: String = "YENİ"
const CLAIM_TEXT: String = "!"
const COUNT_CAP: int = 99

var _mode: Mode = Mode.NONE
var _count: int = 0
var _label: Label
var _anchor_point: Vector2 = Vector2.ZERO
var _anchored: bool = false


func _init() -> void:
	name = "AttentionBadge"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = UiType.v3_label("", UiType.V3_BADGE, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label.name = "Text"
	_label.add_theme_color_override("font_color", UiTokens.TEXT_ON_DARK)
	add_child(_label)
	# Etiket temalanınca (ağaca girince) ölçüsü değişir: rozet boyu her çağrı sırasında doğru kalsın.
	_label.minimum_size_changed.connect(_resize)
	_apply()


func set_mode(mode: int, count: int = 0) -> void:
	_mode = mode as Mode
	_count = maxi(count, 0)
	if _mode == Mode.COUNT and _count == 0:
		_mode = Mode.NONE
	_apply()


func show_dot() -> void:
	set_mode(Mode.DOT)


func show_count(count: int) -> void:
	set_mode(Mode.COUNT, count)


func show_new() -> void:
	set_mode(Mode.NEW)


func show_claim() -> void:
	set_mode(Mode.CLAIM)


func clear() -> void:
	set_mode(Mode.NONE)


func mode() -> Mode:
	return _mode


func text() -> String:
	return _label.text if _label.visible else ""


func count() -> int:
	return _count if _mode == Mode.COUNT else 0


## Rozetin MERKEZİNİ ebeveyn koordinatında `point`e oturtur (köşe noktası). Boyut değişince korunur.
func place_at(point: Vector2) -> void:
	_anchor_point = point
	_anchored = true
	custom_minimum_size = Vector2.ZERO
	_reposition()


func _apply() -> void:
	visible = _mode != Mode.NONE
	match _mode:
		Mode.COUNT:
			_label.text = str(_count) if _count <= COUNT_CAP else "%d+" % COUNT_CAP
		Mode.NEW:
			_label.text = NEW_TEXT
		Mode.CLAIM:
			_label.text = CLAIM_TEXT
		_:
			_label.text = ""
	_label.visible = not _label.text.is_empty()
	_resize()


## Boy: nokta sabit; metinli hap etiketin gerçek ölçüsüne göre (+ iki yan pay).
func _resize() -> void:
	var w: float = DOT_SIZE
	var h: float = DOT_SIZE
	if _label.visible:
		var text_w: float = _label.get_combined_minimum_size().x
		h = PILL_HEIGHT
		w = maxf(PILL_HEIGHT, text_w + 18.0)
	size = Vector2(w, h)
	# Köşeye oturtulan rozet ebeveynin minimumuna katılmaz; konteyner içinde (bölüm başlığı) kendi boyunu ister.
	custom_minimum_size = Vector2.ZERO if _anchored else Vector2(w, h)
	_label.position = Vector2(0.0, -LIP * 0.5 - 1.0)
	_label.size = Vector2(w, h)
	_reposition()
	queue_redraw()


func _reposition() -> void:
	if _anchored:
		position = _anchor_point - size * 0.5


func _draw() -> void:
	if _mode == Mode.NONE:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var r: float = size.y * 0.5
	# Beyaz halka (kontrolün dışına RING px) + yumuşak gölge → koyu dudak → mercan yüz → gloss.
	var ring := UiKit.v3_box(Color.WHITE, r + RING)
	UiTokens.shadow_apply(ring, {"color": Color(0.10, 0.04, 0.22, 0.30), "size": 3, "offset": Vector2(0, 2)})
	draw_style_box(ring, rect.grow(RING))
	draw_style_box(UiKit.v3_box(UiTokens.ATTENTION_DEEP, r), rect)
	var face := Rect2(rect.position, Vector2(rect.size.x, rect.size.y - LIP))
	draw_style_box(UiKit.v3_box(UiTokens.ATTENTION, r), face)
	var gloss := UiKit.v3_box(Color(1, 1, 1, 0.32), maxf(r - 3.0, 3.0))
	draw_style_box(gloss, Rect2(face.position + Vector2(r * 0.45, 2.0), Vector2(face.size.x - r * 0.9, face.size.y * 0.42)))


func _notification(what: int) -> void:
	# Etiket ölçüsü ağaçta (tema fontuyla) kesinleşir; çocuk etiket ebeveynden SONRA temalanır → READY.
	if what == NOTIFICATION_READY or what == NOTIFICATION_THEME_CHANGED:
		_resize()
