extends CanvasLayer
## Harita sekmesi: level seçim ekranı (GAME_DESIGN.md §5.5).
##
## M8.5-12: düz 5×2 grid KALKTI. On level düğümü owner'ın harita art'ındaki
## pembe patikayı takip ediyor (aşağıdan yukarı, hafif zig-zag), aralarında
## programatik candy patika (MapTrail), sonda Sonsuz Mod "kapısı" (kale).
## Unlock kuralları, level verisi, yıldızlar DEĞİŞMEDİ — yalnızca yerleşim
## ve sunum.
##
## Düğüm durumları:
##   LOCKED     kilitli — lavanta, soluk, kilit rozeti
##   AVAILABLE  açık ama henüz oynanmamış ve sıradaki değil (teorik; unlock
##              sıralı olduğu için pratikte yalnızca sıradaki olur)
##   NEXT       sıradaki — altın halka + arkasında nabız atan altın hale
##   COMPLETED  yıldızlı candy düğüm
##
## Koordinatlar DOKU uzayında (720×1280 harita zemini). Zemin
## KEEP_ASPECT_COVERED ile çizildiği için uzun ekranda büyüyüp kırpılıyor;
## düğümler aynı dönüşümle taşınıyor (_map_to_screen), böylece patika ile
## hizaları her oranda korunuyor.

signal level_chosen(level: LevelData)

enum NodeState { LOCKED, AVAILABLE, NEXT, COMPLETED }

## Harita zemini doku boyutu (map_background.png).
const MAP_SIZE: Vector2 = Vector2(720.0, 1280.0)
## Level 1..10 düğüm merkezleri, doku uzayı. Pembe kaldırım taşı yolun
## orta hattı üstünde: alt geniş bölümde zig-zag, y≈750'de yolun sola
## kıvrımı, y≈560'ta sağa dönüş, tepede kapı kemeri (level 10). Dekoratif
## karakterlerin (sol alt sarı, sağ alt pembe) ve köprülerin üstüne
## binmiyor; kenara 48 px'ten fazla yaklaşmıyor.
const NODE_POSITIONS: Array[Vector2] = [
	Vector2(420.0, 1120.0),
	Vector2(300.0, 1030.0),
	Vector2(440.0, 940.0),
	Vector2(310.0, 850.0),
	Vector2(300.0, 740.0),
	Vector2(395.0, 645.0),
	Vector2(470.0, 555.0),
	Vector2(410.0, 465.0),
	Vector2(475.0, 385.0),
	Vector2(440.0, 296.0),
]
## Sonsuz Mod kapısı: patikanın sonundaki kale (yolun devamı). Başlık
## satırı (y 30-110) sol ve sağda; kapı ortada (x 387-503) olduğu için
## çakışmıyor.
const ENDLESS_POSITION: Vector2 = Vector2(445.0, 150.0)

## Düğüm 88 px: 96'da on düğüm + kapı 1000 px'lik yola sığmıyor, patika
## görünmüyordu. 88 hâlâ 48 px dokunma hedefinin çok üstünde.
const NODE_SIZE: Vector2 = Vector2(88.0, 88.0)
const PORTAL_SIZE: Vector2 = Vector2(116.0, 116.0)

## Kilitli level düğümündeki kilit rozeti.
const LOCK_BADGE_SIZE: Vector2 = Vector2(30.0, 37.0)
const LOCK_BADGE_INSET: float = 5.0

## Düğümdeki yıldız sırası (asset, Unicode değil — M8.5-09).
const NODE_STAR_SIZE: Vector2 = Vector2(20.0, 19.0)
const NODE_STAR_SEPARATION: int = 2
## Level numarası — Baloo 2 Bold (CARD_TITLE rolü, boyutu ezilerek).
const NODE_NUMBER_FONT_SIZE: int = 26
## İçeriğin düğümün dikey olarak neresine oturduğu (tema content margin'leri).
const NODE_TOP_INSET: float = 10.0
const NODE_BOTTOM_INSET: float = 16.0
const NODE_STAR_EMPTY_ALPHA: float = 0.5

## Sıradaki level: altın halka + arkasında nabız atan hale.
const NEXT_RING_COLOR: Color = UiPalette.GOLD
const NEXT_PULSE_SCALE: float = 1.05
const NEXT_PULSE_TIME: float = 0.9
const HALO_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_dot.png")
const SPARKLE_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_sparkle.png")
const HALO_SIZE: float = 210.0

## Kilitli düğümün soluklaştırılması (pasif tema stili zaten lavanta).
const LOCKED_ALPHA: float = 0.78

## Açılış animasyonu (M8.5-12): düğüm pop + parıltı + patika yanması.
const UNLOCK_POP_TIME: float = 0.32
const UNLOCK_TRAIL_TIME: float = 0.4

var _levels: Array[LevelData] = []
var _dough_chip: PanelContainer
var _streak_chip: PanelContainer
var _record_chip: PanelContainer
var _pulse: Tween
var _halo: TextureRect
var _portal: Button
var _portal_caption: Label
## Düğüm butonları, level sırasıyla (index 0 = level 1).
var _nodes: Array[Button] = []
## Son tazelemede görülen en yüksek açık level. -1 = henüz görülmedi
## (ilk tazeleme animasyon oynatmaz). Kayda YAZILMIYOR — bellek içi.
var _last_unlocked: int = -1

@onready var _map: Control = $Map
@onready var _trail: MapTrail = $Map/Trail
@onready var _node_layer: Control = $Map/Nodes
@onready var _chip_slot: HBoxContainer = $Header/Row/ChipSlot


func _ready() -> void:
	_levels = LevelLibrary.load_levels()
	_dough_chip = UiPalette.chip(UiIcons.DOUGH, "")
	_streak_chip = UiPalette.chip(UiIcons.FLAME, "")
	_chip_slot.add_child(_streak_chip)
	_chip_slot.add_child(_dough_chip)
	_map.resized.connect(_layout)
	refresh()


# --- Doku uzayı -> ekran ---

## MapBackground KEEP_ASPECT_COVERED: ölçek = max(vw/720, vh/1280),
## çizim merkezlenir. Aynı dönüşüm düğümlere uygulanıyor.
func _map_to_screen(map_point: Vector2) -> Vector2:
	var view: Vector2 = _map.size
	if view.x <= 0.0 or view.y <= 0.0:
		view = MAP_SIZE
	var s: float = maxf(view.x / MAP_SIZE.x, view.y / MAP_SIZE.y)
	return (map_point - MAP_SIZE * 0.5) * s + view * 0.5


func _layout() -> void:
	var trail_points := PackedVector2Array()
	for i in _nodes.size():
		var center: Vector2 = _map_to_screen(NODE_POSITIONS[i])
		_nodes[i].position = center - NODE_SIZE * 0.5
		trail_points.append(center)
	if _portal != null:
		var center: Vector2 = _map_to_screen(ENDLESS_POSITION)
		_portal.position = center - PORTAL_SIZE * 0.5
		_record_chip.reset_size()
		_record_chip.position = center + Vector2(-_record_chip.get_combined_minimum_size().x * 0.5,
			PORTAL_SIZE.y * 0.5 + 6.0)
		trail_points.append(center)
	if _halo != null and _halo.has_meta("node"):
		var node: Button = _halo.get_meta("node")
		_halo.position = node.position + NODE_SIZE * 0.5 - Vector2.ONE * HALO_SIZE * 0.5
	var done: int = _done_segments()
	_trail.set_trail(trail_points, done, _trail.lit)


## Tamamlanmış segment sayısı: level k tamamlandıysa k→k+1 segmenti sıcak.
## highest_level_unlocked = H demek 1..H-1 tamamlandı → H-1 segment.
func _done_segments() -> int:
	return clampi(SaveManager.highest_level_unlocked() - 1, 0, NODE_POSITIONS.size())


# --- Tazeleme ---

func refresh() -> void:
	for child in _node_layer.get_children():
		child.queue_free()
	_nodes.clear()
	_halo = null
	_portal = null
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()

	var highest: int = SaveManager.highest_level_unlocked()
	var newly_unlocked: int = -1
	if _last_unlocked > 0 and highest > _last_unlocked:
		newly_unlocked = highest
	_last_unlocked = highest

	# Hale düğümlerin ARKASINDA: önce ekleniyor.
	_halo = TextureRect.new()
	_halo.texture = HALO_TEXTURE
	_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_halo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_halo.size = Vector2.ONE * HALO_SIZE
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo.modulate = Color(UiPalette.GOLD.r, UiPalette.GOLD.g, UiPalette.GOLD.b, 0.0)
	_node_layer.add_child(_halo)

	for level in _levels:
		var state: NodeState = _state_for(level.level_number, highest)
		var button: Button = _make_node(level, state)
		_node_layer.add_child(button)
		_nodes.append(button)
		if state == NodeState.NEXT:
			_mark_next(button)

	_make_portal(SaveManager.is_endless_unlocked(_levels.size()))

	UiPalette.set_chip_value(_dough_chip, "%d Hamur" % SaveManager.dough(), false)
	var streak: int = SaveManager.daily_streak()
	UiPalette.set_chip_value(_streak_chip,
		"%d günlük seri" % streak if streak > 0 else "Seri başlasın", false)
	if SaveManager.is_endless_unlocked(_levels.size()):
		UiPalette.set_chip_value(_record_chip, "Rekor %d" % SaveManager.endless_high_score(), false)
	_trail.lit = 0.0
	_layout()

	if newly_unlocked > 0:
		_play_unlock(newly_unlocked)


func _state_for(level_number: int, highest: int) -> NodeState:
	if level_number > highest:
		return NodeState.LOCKED
	if SaveManager.stars_for_level(level_number) > 0:
		return NodeState.COMPLETED
	if level_number == highest:
		return NodeState.NEXT
	return NodeState.AVAILABLE


# --- Düğümler ---

func _make_node(level: LevelData, state: NodeState) -> Button:
	var button := Button.new()
	button.size = NODE_SIZE
	button.custom_minimum_size = NODE_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = state == NodeState.LOCKED
	button.pivot_offset = NODE_SIZE * 0.5
	button.pressed.connect(_on_level_pressed.bind(level))
	UiMotion.attach_press(button)
	# Kilitli düğümde yıldız sırası YOK: numara + kilit yeter, boş yıldızlar
	# on düğümde tekrarlanınca gürültü oluyordu.
	_add_node_content(button, level.level_number,
		SaveManager.stars_for_level(level.level_number), state != NodeState.LOCKED)
	if state == NodeState.LOCKED:
		_add_lock_badge(button)
		button.modulate.a = LOCKED_ALPHA
	elif state == NodeState.AVAILABLE:
		# CTA gibi okunur ama sıradaki kadar parlamaz: ince krem kenar.
		for style_name in ["normal", "hover"]:
			var box := (button.get_theme_stylebox(style_name) as StyleBoxFlat).duplicate()
			box.set_border_width_all(2)
			box.border_width_bottom = 6
			box.border_color = UiPalette.CREAM
			button.add_theme_stylebox_override(style_name, box)
	return button


## Sıradaki level: altın halka + nabız + arkada yumuşak altın hale.
func _mark_next(button: Button) -> void:
	for style_name in ["normal", "hover"]:
		var box := (button.get_theme_stylebox(style_name) as StyleBoxFlat).duplicate()
		box.set_border_width_all(3)
		box.border_width_bottom = 6
		box.border_color = NEXT_RING_COLOR
		button.add_theme_stylebox_override(style_name, box)
	_halo.set_meta("node", button)
	_halo.modulate.a = 0.7
	# Basınca nabız durur; basma animasyonu (UiMotion) scale'i devralır.
	button.button_down.connect(func() -> void:
		if _pulse != null and _pulse.is_valid():
			_pulse.kill())
	_pulse = button.create_tween().set_loops()
	_pulse.set_parallel(true)
	_pulse.tween_property(button, "scale", Vector2.ONE * NEXT_PULSE_SCALE, NEXT_PULSE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(_halo, "modulate:a", 1.0, NEXT_PULSE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.chain().set_parallel(true)
	_pulse.tween_property(button, "scale", Vector2.ONE, NEXT_PULSE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(_halo, "modulate:a", 0.7, NEXT_PULSE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Düğümün içeriği: numara üstte, yıldız sırası altta. `button.text`
## KULLANILMIYOR: yıldızlar Texture2D, Button ikonu yazının soluna koyar.
func _add_node_content(button: Button, level_number: int, earned: int,
		show_stars: bool = true) -> void:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_top = NODE_TOP_INSET
	box.offset_bottom = -NODE_BOTTOM_INSET
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	button.add_child(box)

	var number := Label.new()
	UiType.apply(number, UiType.CARD_TITLE)
	number.add_theme_font_size_override("font_size", NODE_NUMBER_FONT_SIZE)
	number.text = str(level_number)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(number)

	if not show_stars:
		return
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.add_theme_constant_override("separation", NODE_STAR_SEPARATION)
	box.add_child(stars)

	for i in 3:
		var star := TextureRect.new()
		star.texture = UiIcons.STAR_FILLED if i < earned else UiIcons.STAR_EMPTY
		star.custom_minimum_size = NODE_STAR_SIZE
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.modulate = Color(1, 1, 1, 1) if i < earned \
			else Color(1, 1, 1, NODE_STAR_EMPTY_ALPHA)
		stars.add_child(star)


## Kilitli düğümün sağ-üst köşesine küçük kilit rozeti (koleksiyonla aynı dil).
func _add_lock_badge(button: Button) -> void:
	var badge := TextureRect.new()
	badge.texture = UiIcons.LOCK
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -LOCK_BADGE_SIZE.x - LOCK_BADGE_INSET
	badge.offset_top = LOCK_BADGE_INSET
	badge.offset_right = -LOCK_BADGE_INSET
	badge.offset_bottom = LOCK_BADGE_SIZE.y + LOCK_BADGE_INSET
	button.add_child(badge)


# --- Sonsuz Mod kapısı ---

## Normal düğüm gibi değil: kalenin önünde yuvarlak altın "kapı", kupa
## ikonu, altında etiket ve rekor cipi. Kilitliyse gri + kilit + "Level
## 10'u bitir". Unlock kuralı SaveManager.is_endless_unlocked — değişmedi.
func _make_portal(unlocked: bool) -> void:
	_portal = Button.new()
	_portal.size = PORTAL_SIZE
	_portal.custom_minimum_size = PORTAL_SIZE
	_portal.focus_mode = Control.FOCUS_NONE
	_portal.disabled = not unlocked
	_portal.pivot_offset = PORTAL_SIZE * 0.5
	_portal.pressed.connect(_on_endless_pressed)
	UiMotion.attach_press(_portal)
	_portal.add_theme_stylebox_override("normal", _portal_style(UiPalette.GOLD, Color(1, 1, 1, 0.9)))
	_portal.add_theme_stylebox_override("hover", _portal_style(UiPalette.GOLD_BRIGHT, Color.WHITE))
	_portal.add_theme_stylebox_override("pressed", _portal_style(Color(0.9, 0.7, 0.3), Color(1, 1, 1, 0.8)))
	_portal.add_theme_stylebox_override("hover_pressed", _portal_style(Color(0.9, 0.7, 0.3), Color(1, 1, 1, 0.8)))
	_portal.add_theme_stylebox_override("disabled", _portal_style(UiPalette.DISABLED_FACE, Color(1, 1, 1, 0.3)))
	var ink: Color = Color(0.45, 0.22, 0.32) if unlocked else Color(1, 1, 1, 0.5)
	# Kapının içi: kupa + "Sonsuz" etiketi (dış etiket level 10 düğümüyle
	# çakışıyordu; kapı zaten 116 px, ikisi içeri sığıyor).
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 14.0
	column.offset_bottom = -14.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	_portal.add_child(column)
	var icon := UiPalette.icon_rect(UiPalette.ICON_TROPHY, 44.0, ink)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	_portal_caption = Label.new()
	UiType.apply(_portal_caption, UiType.CARD_TITLE)
	_portal_caption.text = "Sonsuz"
	_portal_caption.add_theme_font_size_override("font_size", 18)
	_portal_caption.add_theme_color_override("font_color", ink)
	_portal_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portal_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_portal_caption)
	if not unlocked:
		_add_lock_badge(_portal)
		_portal.modulate.a = LOCKED_ALPHA
	_node_layer.add_child(_portal)

	# Kapının altındaki tek cip: açıksa rekor, kilitliyse şart.
	if unlocked:
		_record_chip = UiPalette.chip(UiPalette.ICON_TROPHY, "Rekor 0", 20, UiPalette.GOLD)
	else:
		_record_chip = UiPalette.chip(UiIcons.LOCK, "Level %d'u bitir" % _levels.size(), 20)
	_node_layer.add_child(_record_chip)


static func _portal_style(face: Color, ring: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = face
	box.set_border_width_all(4)
	box.border_color = ring
	box.set_corner_radius_all(int(PORTAL_SIZE.x * 0.5))
	box.shadow_color = Color(1.0, 0.85, 0.4, 0.35)
	box.shadow_size = 14
	return box


# --- Açılış animasyonu ---

## Level `level_number` ilk kez açıldı: patikanın son segmenti yanar,
## düğüm pop'lar, birkaç parıltı. ~0.5 sn, kesilebilir; kayıt değişmez.
func _play_unlock(level_number: int) -> void:
	var index: int = level_number - 1
	# Yeni yanan segment: bir onceki dugumden yeni acilan dugume. Once done'i
	# bir geri alip o segmenti 0'dan 1'e yak, bitince gercek done'a don.
	var done: int = _done_segments()
	_trail.set_done(maxi(done - 1, 0))
	_trail.lit = 0.0
	var trail_tween := create_tween()
	trail_tween.tween_property(_trail, "lit", 1.0, UNLOCK_TRAIL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	trail_tween.tween_callback(func() -> void:
		_trail.set_done(done)
		_trail.lit = 0.0)
	var target: Control = null
	if index < _nodes.size():
		target = _nodes[index]
	elif _portal != null:
		target = _portal
	if target == null:
		return
	target.scale = Vector2(0.4, 0.4)
	var pop := create_tween()
	pop.tween_interval(UNLOCK_TRAIL_TIME * 0.6)
	pop.tween_property(target, "scale", Vector2(1.15, 1.15), UNLOCK_POP_TIME * 0.55) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(target, "scale", Vector2.ONE, UNLOCK_POP_TIME * 0.45)
	pop.tween_callback(_spawn_unlock_sparkles.bind(target))
	pop.tween_callback(AudioManager.play.bind(&"level_unlock"))


func _spawn_unlock_sparkles(target: Control) -> void:
	if not is_instance_valid(target):
		return
	var fx := CPUParticles2D.new()
	fx.texture = SPARKLE_TEXTURE
	fx.position = target.position + target.size * 0.5
	fx.one_shot = true
	fx.explosiveness = 1.0
	fx.amount = 12
	fx.lifetime = 0.55
	fx.direction = Vector2.UP
	fx.spread = 180.0
	fx.gravity = Vector2(0.0, 220.0)
	fx.initial_velocity_min = 90.0
	fx.initial_velocity_max = 190.0
	fx.scale_amount_min = 0.14
	fx.scale_amount_max = 0.3
	fx.color = Color(1.0, 0.92, 0.6, 0.95)
	_node_layer.add_child(fx)
	fx.emitting = true
	get_tree().create_timer(fx.lifetime + 0.2).timeout.connect(fx.queue_free)


func _on_level_pressed(level: LevelData) -> void:
	level_chosen.emit(level)


func _on_endless_pressed() -> void:
	var endless := LevelLibrary.load_endless()
	if endless != null:
		level_chosen.emit(endless)
