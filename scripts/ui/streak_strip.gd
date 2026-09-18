class_name StreakStrip
extends Control
## Günlük seri şeridi (M8.6-08): yedi gün düğümü, aralarında bağlantı
## çizgisi, altında gün numaraları. Eskiden "•" metniydi (32 px punto,
## 540×960'ta boş noktalar ~4 px'e iniyordu); artık gerçek bileşen.
##
## Düğüm durumları (`set_streak`):
##   CLAIMED  önceki günler — nane disk + beyaz tik
##   TODAY    bugünkü gün — altın odak halkası, %14 büyük; ödül henüz
##            "alınmadan" krem disk + soluk yıldız, `mark_today()` ile altın
##            disk + parlak yıldız (pop)
##   FUTURE   sessiz lavanta-krem disk
## Seri 7'den uzunsa son düğümde altın "+N" rozeti (eski "+N" metniyle aynı
## bilgi). Bugünkü gün = min(seri, 7). Ödül miktarı burada DEĞİL: runtime
## her gün aynı ödülü verir (DailyReward.DAILY_DOUGH), gün başına farklı
## ödül İCAT EDİLMEZ.
##
## Girdi almaz; kayda dokunmaz; her kare işlemi yok (yalnız state
## değişince / yeniden boyutlanınca yerleşim).

const DAYS: int = 7
const NODE: float = 44.0
const TODAY_SCALE: float = 1.14
const RING: float = 4.0
const CONNECTOR: float = 6.0
const NUMBER_GAP: float = 4.0
const NUMBER_HEIGHT: float = 20.0
## Şeridin iki yanındaki iç pay: "+N" rozeti son düğümün sağ üst omzuna
## taşar, gövde kırpmasının içinde kalsın.
const PAD: float = 14.0
const STAR_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")

enum State { FUTURE, CLAIMED, TODAY }

var _streak: int = 0
var _today_marked: bool = false
var _nodes: Array[Control] = []
var _numbers: Array[Label] = []
var _states: Array[int] = []
var _plus_badge: PanelContainer = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(2.0 * PAD + DAYS * NODE + (DAYS - 1) * 12.0,
		NODE * TODAY_SCALE + NUMBER_GAP + NUMBER_HEIGHT)
	for i in DAYS:
		var node := Control.new()
		node.name = "Day%d" % (i + 1)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(node)
		_nodes.append(node)
		var number := UiKit.label(str(i + 1), &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
		number.name = "Number%d" % (i + 1)
		add_child(number)
		_numbers.append(number)
		_states.append(State.FUTURE)
	resized.connect(_layout)


## `streak` bugünkü günü de sayar (1 = ilk gün). `today_marked`: bugünkü ödül
## görsel olarak alınmış (durum penceresi) ya da henüz kutlanmamış (ödül
## penceresi, AL'a basılınca `mark_today`).
func set_streak(streak: int, today_marked: bool) -> void:
	_streak = maxi(streak, 0)
	_today_marked = today_marked
	var today: int = clampi(_streak, 1, DAYS) - 1
	for i in DAYS:
		var state: int = State.FUTURE
		if _streak > 0:
			if i < today:
				state = State.CLAIMED
			elif i == today:
				state = State.TODAY
		_states[i] = state
		_build_node(i, state)
	_update_plus_badge()
	_layout()
	queue_redraw()


## Bugünkü düğüm kutlanır: altın disk + yıldız + kısa pop. Kayda dokunmaz.
func mark_today() -> void:
	if _streak <= 0 or _today_marked:
		return
	_today_marked = true
	var today: int = clampi(_streak, 1, DAYS) - 1
	_build_node(today, State.TODAY)
	_layout()
	UiMotion.pop(_nodes[today], 1.22)


func streak() -> int:
	return _streak


func is_today_marked() -> bool:
	return _today_marked


## Test/araç: i. düğümün durumu (State).
func node_state(index: int) -> int:
	return _states[index]


func node(index: int) -> Control:
	return _nodes[index]


func node_count() -> int:
	return DAYS


func plus_badge_text() -> String:
	if _plus_badge == null or not _plus_badge.visible:
		return ""
	return (_plus_badge.get_meta(&"text_label") as Label).text


# --- Düğüm görselleri --------------------------------------------------------

func _build_node(index: int, state: int) -> void:
	var node: Control = _nodes[index]
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
	var is_today: bool = state == State.TODAY
	var size: float = NODE * (TODAY_SCALE if is_today else 1.0)
	node.custom_minimum_size = Vector2(size, size)
	node.size = Vector2(size, size)
	node.pivot_offset = node.size * 0.5
	# Erik temas gölgesi: düğüm krem gövdeye oturur.
	var shadow := UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.20 if is_today else 0.14))
	UiKit.inset(shadow, -size * 0.22, -size * 0.10, -size * 0.22, -size * 0.30)
	node.add_child(shadow)
	if is_today:
		# Altın odak halkası (ödül anı) — disk arkasında, RING px dışarı.
		var ring := UiKit.flat_plate("btn_circle_flat", UiTokens.GOLD_BRIGHT if _today_marked else UiTokens.GOLD)
		UiKit.inset(ring, -RING, -RING, -RING, -RING)
		node.add_child(ring)
	var tint: Color
	match state:
		State.CLAIMED:
			tint = UiTokens.MINT
		State.TODAY:
			tint = UiTokens.GOLD if _today_marked else UiTokens.CREAM
		_:
			tint = UiTokens.LAVENDER_SURFACE
	node.add_child(UiKit.flat_plate("btn_circle_flat", tint))
	var light := UiKit.patch("item_circle_inner", Color(1, 1, 1, 0.40))
	UiKit.inset(light, size * 0.14, size * 0.06, size * 0.14, size * 0.44)
	node.add_child(light)
	var mark: Control = null
	match state:
		State.CLAIMED:
			mark = UiKit.icon("check", size * 0.52, UiTokens.TEXT_ON_DARK)
		State.TODAY:
			mark = UiKit.art(STAR_ART, size * 0.60)
			mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			if not _today_marked:
				# Henüz kutlanmadı: soluk yıldız "bugün burası" der, ödülü
				# alınmış göstermez.
				mark.self_modulate = Color(1, 1, 1, 0.42)
	if mark != null:
		mark.name = "Mark"
		mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		var half: float = mark.custom_minimum_size.x * 0.5
		mark.offset_left = -half
		mark.offset_right = half
		mark.offset_top = -half - 1.0
		mark.offset_bottom = half - 1.0
		node.add_child(mark)
	var number: Label = _numbers[index]
	number.add_theme_color_override("font_color",
		UiTokens.TEXT_PRIMARY if is_today else UiTokens.TEXT_TERTIARY)


func _update_plus_badge() -> void:
	var extra: int = _streak - DAYS
	if extra <= 0:
		if _plus_badge != null:
			_plus_badge.visible = false
		return
	if _plus_badge == null:
		_plus_badge = UiKit.badge("+0", &"CountBadge")
		_plus_badge.name = "PlusBadge"
		# badge(): PanelContainer > HBox > Label.
		var text: Label = _plus_badge.get_child(0).get_child(0)
		_plus_badge.set_meta(&"text_label", text)
		add_child(_plus_badge)
	(_plus_badge.get_meta(&"text_label") as Label).text = "+%d" % extra
	_plus_badge.visible = true


# --- Yerleşim ----------------------------------------------------------------

func _layout() -> void:
	var width: float = size.x - 2.0 * PAD
	var gap: float = (width - DAYS * NODE) / float(DAYS - 1)
	var row_h: float = NODE * TODAY_SCALE
	for i in DAYS:
		var node: Control = _nodes[i]
		var s: float = node.custom_minimum_size.x
		var cx: float = PAD + i * (NODE + gap) + NODE * 0.5
		var cy: float = row_h * 0.5
		node.position = Vector2(cx - s * 0.5, cy - s * 0.5)
		node.size = Vector2(s, s)
		node.pivot_offset = node.size * 0.5
		var number: Label = _numbers[i]
		number.size = Vector2(NODE + gap, NUMBER_HEIGHT)
		number.position = Vector2(cx - number.size.x * 0.5, row_h + NUMBER_GAP)
	if _plus_badge != null and _plus_badge.visible:
		# Son düğümün sağ üst omzu; sağa en fazla 8 px taşar (PAD içinde).
		var last: Control = _nodes[DAYS - 1]
		var badge_w: float = _plus_badge.get_combined_minimum_size().x
		_plus_badge.position = Vector2(last.position.x + last.size.x - badge_w + 8.0, last.position.y - 10.0)
	queue_redraw()


## Bağlantı çizgileri düğümlerin ARKASINDA (Control kendini çocuklarından
## önce çizer): tamamlanan segment nane, bugüne gelen segment altın, gelecek
## lavanta.
func _draw() -> void:
	if _nodes.is_empty() or size.x <= 0.0:
		return
	var y: float = NODE * TODAY_SCALE * 0.5
	for i in DAYS - 1:
		var a: Control = _nodes[i]
		var b: Control = _nodes[i + 1]
		var from_x: float = a.position.x + a.size.x * 0.5
		var to_x: float = b.position.x + b.size.x * 0.5
		var color: Color = Color(UiTokens.LAVENDER_SURFACE, 0.9)
		if _states[i] == State.CLAIMED:
			color = UiTokens.MINT if _states[i + 1] == State.CLAIMED else UiTokens.GOLD
		draw_line(Vector2(from_x, y), Vector2(to_x, y), color, CONNECTOR, true)
