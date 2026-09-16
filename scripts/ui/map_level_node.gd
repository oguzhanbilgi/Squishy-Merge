class_name MapLevelNode
extends Button
## Harita yolculuk düğümü (M8.6-04): on level düğümü ve Sonsuz Mod
## madalyonu TEK bileşenden. Home madalyonu (HomeFeatureButton) ve gameplay
## güç slotuyla AYNI candy malzeme ailesi — farklı rol: ilerleme.
##
## Beş durum:
##   COMPLETED       cyan gövde, koyu cyan halka, lacivert numara, 3 owner yıldızı
##   CURRENT         ×1.14, cyan gövde, ALTIN halka (Home level rozetiyle aynı
##                   altın = "level" kimliği), arkada nefes alan krem hale,
##                   altında krem "OYNA" plakası
##   LOCKED          açık lavanta gövde, pasif halka, soluk cam, erik numara,
##                   owner pembe kilit; tam alfa (gri blob DEĞİL). Dokunuş
##                   = kilit sallanır + `ui_invalid`; ASLA level başlatmaz
##   ENDLESS_OPEN    116 px altın gövde, krem halka, owner tacı + "SONSUZ",
##                   plaka "Rekor N" / "Rekor bekliyor", 3 pırıltı
##   ENDLESS_LOCKED  lavanta gövde, soluk taç, kilit, plaka "Level 10'u bitir"
##
## Anatomi (arkadan öne): erik temas gölgesi (yassı blob — düğüm dünyaya
## OTURUR) → hale (yalnız odak) → krem dış halka → durum halkası → `btn_circle`
## gövde (butonun stylebox'ı) → cam yuva → alt gölge + üst gloss → içerik
## (numara / taç + yazı) → yıldız sırası → kilit rozeti → altta plaka.
##
## Çap dışarıdan (`set_diameter`): harita perspektif verir — altta 84 px,
## kalede 72 px; sıradaki ×1.14. Buton dikdörtgeni = gövde (≥ 48 dokunma);
## plaka gövdeden aşağı taşan dekor, dokunma almaz.
##
## Kural: on bir düğüm bu bileşenden; ekran kodu halka/gloss kurmaz.
## Level verisi, unlock kuralı, yıldız kuralı BURADA DEĞİL — yalnız sunum.

enum State { LOCKED, CURRENT, COMPLETED, ENDLESS_LOCKED, ENDLESS_OPEN }

## `btn_circle`: boyalı gövde 70/74, alt 4 satır pişmiş gölge (dudak).
const LIP: float = 4.0
const LEVEL_DIAMETER: float = 84.0
const ENDLESS_DIAMETER: float = 116.0
const CURRENT_SCALE: float = 1.14
const RIM_WIDTH: float = 6.0
const RING_WIDTH: float = 3.0
## En dışta ince erik kontur: krem halka açık zeminde kaybolmasın.
const OUTLINE_WIDTH: float = 2.0
const PLAQUE_HEIGHT: float = 30.0
const PLAQUE_OVERLAP: float = 8.0
const STAR_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
const STAR_EMPTY_ART: Texture2D = preload("res://assets/visual/ui/icon_star_empty.png")
const LOCK_ART: Texture2D = preload("res://assets/visual/ui/icon_lock.png")
const CROWN_ART: Texture2D = preload("res://assets/visual/ui/icon_crown.png")
## Sonsuz pırıltıları: gövde merkezine göre oran (çap), kutu oranı, faz.
const ENDLESS_SPARKLES: Array = [
	[Vector2(-0.58, -0.36), 0.20, 0.0],
	[Vector2(0.56, -0.48), 0.16, 2.1],
	[Vector2(0.62, 0.30), 0.13, 4.0],
]
const WIGGLE_TIME: float = 0.22

var _state: State = State.LOCKED
var _diameter: float = LEVEL_DIAMETER
var _level_number: int = 0
var _stars: int = 0
var _focused: bool = false
var _time: float = 0.0
## Dış animasyon (açılış pop'u) ölçeği sürerken nefes ölçeğe dokunmaz.
var hold_breath: bool = false

var _shadow: NinePatchRect
var _halo: NinePatchRect
var _outline: NinePatchRect
var _rim: NinePatchRect
var _ring: NinePatchRect
var _glass: NinePatchRect
var _shade: NinePatchRect
var _gloss: NinePatchRect
var _number: Label
var _crown: TextureRect
var _caption: Label
var _stars_row: HBoxContainer
var _star_rects: Array[TextureRect] = []
var _lock: TextureRect
var _plaque: Control
var _plaque_rim: PanelContainer
var _plaque_body: PanelContainer
var _plaque_row: HBoxContainer
var _plaque_lock: TextureRect
var _plaque_label: Label
var _sparkles: Array[TextureRect] = []
var _wiggle: Tween


func _init() -> void:
	theme_type_variation = &"ButtonMapNode"
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Temas gölgesi: yassı erik blob, gövdenin altına doğru (dünyaya oturma).
	_shadow = UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.26))
	_shadow.show_behind_parent = true
	add_child(_shadow)
	# Hale: yalnız odaktaki düğüm (sıradaki level / açık Sonsuz hedefi).
	_halo = UiKit.patch("popup_glow", Color(1.0, 0.97, 0.88, 0.0))
	_halo.show_behind_parent = true
	_halo.visible = false
	add_child(_halo)
	_outline = UiKit.patch("btn_circle_flat", Color(UiTokens.LAVENDER_DEEP, 0.55))
	_outline.show_behind_parent = true
	add_child(_outline)
	_rim = UiKit.patch("btn_circle_flat", UiTokens.CREAM)
	_rim.show_behind_parent = true
	add_child(_rim)
	_ring = UiKit.patch("btn_circle_flat", UiTokens.CYAN_DEEP)
	_ring.show_behind_parent = true
	add_child(_ring)
	_glass = UiKit.patch("item_circle_inner", UiTokens.GLASS_BLUE)
	add_child(_glass)
	_shade = UiKit.patch("item_circle_inner", Color(0.35, 0.25, 0.5, 0.14))
	add_child(_shade)
	_gloss = UiKit.patch("item_circle_inner", Color(1, 1, 1, 0.40))
	add_child(_gloss)
	_crown = UiKit.art(CROWN_ART, 44)
	_crown.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_crown.visible = false
	add_child(_crown)
	_number = UiKit.label("", &"LabelSectionOnAccent", HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_number)
	_caption = UiKit.label("SONSUZ", &"LabelSectionOnAccent", HORIZONTAL_ALIGNMENT_CENTER)
	_caption.add_theme_font_size_override("font_size", 15)
	_caption.visible = false
	add_child(_caption)
	_stars_row = HBoxContainer.new()
	_stars_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_stars_row.add_theme_constant_override("separation", -1)
	_stars_row.visible = false
	add_child(_stars_row)
	for i in 3:
		var star := UiKit.art(STAR_ART, 17)
		star.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_stars_row.add_child(star)
		_star_rects.append(star)
	_lock = UiKit.art(LOCK_ART, 28)
	_lock.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_lock.visible = false
	add_child(_lock)
	_build_plaque()
	for spec in ENDLESS_SPARKLES:
		var spark := UiKit.art(STAR_ART, 20)
		spark.visible = false
		add_child(spark)
		_sparkles.append(spark)
	# Basış: 0.94 squash; ses yalnız açık düğümde (kilitli: `ui_invalid`).
	UiMotion.attach_press(self, false)
	button_down.connect(func() -> void:
		if not is_locked():
			AudioManager.play(&"ui_tap"))
	_apply_size()


## Plaka: gövdenin altına biner (Home madalyon plakası dili) — krem plaka +
## koyu lavanta kenar; içinde isteğe bağlı kilit + Baloo yazı (OYNA / Rekor /
## şart). Düz plakalar: NinePatchRect 30 px'te patch kenarının altına inemez.
func _build_plaque() -> void:
	_plaque = Control.new()
	_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque.visible = false
	add_child(_plaque)
	_plaque_rim = UiKit.flat_plate("badge_round", UiTokens.LAVENDER_DEEP)
	_plaque_rim.offset_left = -2.0
	_plaque_rim.offset_top = -2.0
	_plaque_rim.offset_right = 2.0
	_plaque_rim.offset_bottom = 2.0
	_plaque.add_child(_plaque_rim)
	_plaque_body = UiKit.panel(&"PanelMapPlaque")
	_plaque_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plaque.add_child(_plaque_body)
	_plaque_row = HBoxContainer.new()
	_plaque_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_plaque_row.add_theme_constant_override("separation", 4)
	_plaque_body.add_child(_plaque_row)
	_plaque_lock = UiKit.art(LOCK_ART, 18)
	_plaque_lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_plaque_lock.visible = false
	_plaque_row.add_child(_plaque_lock)
	_plaque_label = UiKit.label("", &"LabelBadge", HORIZONTAL_ALIGNMENT_CENTER)
	_plaque_label.add_theme_font_size_override("font_size", 15)
	_plaque_row.add_child(_plaque_label)
	_plaque_body.minimum_size_changed.connect(_layout_plaque)


# --- Kurulum ----------------------------------------------------------------

## Level düğümü. `stars` yalnız COMPLETED'da gösterilir.
func setup_level(level_number: int, state: State, stars: int) -> void:
	_level_number = level_number
	_stars = clampi(stars, 0, 3)
	_state = state
	name = "Level%d" % level_number
	_apply_state()


## Sonsuz Mod madalyonu. `record` 0 = henüz rekor yok. Şart metni
## çağırandan gelir (kanonik: "Level 10'u bitir").
func setup_endless(open: bool, record: int, requirement: String) -> void:
	_level_number = 0
	_state = State.ENDLESS_OPEN if open else State.ENDLESS_LOCKED
	name = "Endless"
	_diameter = ENDLESS_DIAMETER
	_apply_state()
	if open:
		_set_plaque(("Rekor %s" % GameplayHud._thousands(record)) if record > 0 else "Rekor bekliyor", false)
	else:
		_set_plaque(requirement, true)


## Gövde çapı (buton = çap × (çap + dudak)). Sıradaki ×1.14 çağıranda.
func set_diameter(d: float) -> void:
	_diameter = maxf(d, float(UiTokens.TOUCH_MIN))
	_apply_size()


## Odak: hale görünür ve nefes alır (sıradaki level; her şey bitmişse açık
## Sonsuz). Nefes `_process`'te — basış tween'i çalışırken ölçek ellenmez.
func set_focused(on: bool) -> void:
	_focused = on
	_halo.visible = on
	if on:
		_halo.self_modulate.a = 0.70
	set_process(on or _state == State.ENDLESS_OPEN)


func state() -> State:
	return _state


func is_locked() -> bool:
	return _state == State.LOCKED or _state == State.ENDLESS_LOCKED


func is_endless() -> bool:
	return _state == State.ENDLESS_LOCKED or _state == State.ENDLESS_OPEN


func is_focused() -> bool:
	return _focused


func level_number() -> int:
	return _level_number


func stars() -> int:
	return _stars


func number_text() -> String:
	return _number.text


func plaque_text() -> String:
	return _plaque_label.text if _plaque.visible else ""


func diameter() -> float:
	return _diameter


## Gövde merkezi (global).
func body_center() -> Vector2:
	return global_position + Vector2(_diameter, _diameter) * 0.5


## Plaka dahil görsel dikdörtgen (global) — çakışma testleri.
func visual_rect() -> Rect2:
	var rect: Rect2 = get_global_rect()
	if _plaque.visible:
		rect = rect.merge(_plaque.get_global_rect())
	return rect


## Kilitli düğüme dokunuş: kilit sallanır, `ui_invalid`. Level başlatmaz.
func reject() -> void:
	AudioManager.play(&"ui_invalid")
	var target: Control = _lock if _lock.visible else self
	if _wiggle != null and _wiggle.is_valid():
		_wiggle.kill()
	target.pivot_offset = target.size * 0.5
	_wiggle = create_tween()
	for step in [-10.0, 8.0, -5.0, 0.0]:
		_wiggle.tween_property(target, "rotation_degrees", float(step), WIGGLE_TIME / 4.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- Durum ------------------------------------------------------------------

func _apply_state() -> void:
	var endless: bool = is_endless()
	var locked: bool = is_locked()
	match _state:
		State.COMPLETED:
			theme_type_variation = &"ButtonMapNode"
			_ring.self_modulate = UiTokens.CYAN_DEEP
			_rim.self_modulate = UiTokens.CREAM
			_glass.self_modulate = UiTokens.GLASS_BLUE
		State.CURRENT:
			theme_type_variation = &"ButtonMapNode"
			_ring.self_modulate = UiTokens.GOLD
			_rim.self_modulate = UiTokens.CREAM
			_glass.self_modulate = UiTokens.GLASS_BLUE
		State.LOCKED, State.ENDLESS_LOCKED:
			theme_type_variation = &"ButtonMapNodeLocked"
			_ring.self_modulate = UiTokens.DISABLED
			_rim.self_modulate = Color(UiTokens.CREAM, 0.85)
			# Kilitli cam: gövdeden bir ton açık kalsın (yuva okunsun).
			_glass.self_modulate = Color("ebe6f4")
		State.ENDLESS_OPEN:
			theme_type_variation = &"ButtonMapEndless"
			_ring.self_modulate = UiTokens.GOLD_DEEP
			_rim.self_modulate = UiTokens.CREAM
			_glass.self_modulate = UiTokens.CREAM
	_halo.self_modulate = Color(UiTokens.GOLD_BRIGHT, 0.0) if endless else Color(0.88, 0.98, 1.0, 0.0)
	_outline.self_modulate = Color(UiTokens.LAVENDER_DEEP, 0.40 if locked else 0.55)
	_number.visible = not endless
	_number.text = str(_level_number) if not endless else ""
	_number.add_theme_color_override("font_color",
		Color(UiTokens.TEXT_DISABLED, 0.72) if locked else UiTokens.TEXT_ON_ACCENT)
	_crown.visible = endless
	_crown.self_modulate = Color(0.86, 0.84, 0.94, 0.62) if locked else Color.WHITE
	_caption.visible = endless
	_caption.add_theme_color_override("font_color",
		Color(UiTokens.TEXT_DISABLED, 0.72) if locked else UiTokens.TEXT_ON_ACCENT)
	_stars_row.visible = _state == State.COMPLETED
	for i in 3:
		var earned: bool = i < _stars
		_star_rects[i].texture = STAR_ART if earned else STAR_EMPTY_ART
		_star_rects[i].self_modulate = Color.WHITE if earned else Color(1, 1, 1, 0.55)
	_lock.visible = locked
	_lock.rotation_degrees = 0.0
	_gloss.self_modulate = Color(1, 1, 1, 0.26 if locked else 0.40)
	if _state == State.CURRENT:
		_set_plaque("OYNA", false)
	elif not endless:
		_plaque.visible = false
	for spark in _sparkles:
		spark.visible = _state == State.ENDLESS_OPEN
	set_process(_focused or _state == State.ENDLESS_OPEN)
	_apply_size()


func _set_plaque(text: String, with_lock: bool) -> void:
	_plaque_label.text = text
	_plaque_lock.visible = with_lock
	_plaque.visible = not text.is_empty()
	_layout_plaque()


# --- Ölçü -------------------------------------------------------------------

func _apply_size() -> void:
	var d: float = _diameter
	custom_minimum_size = Vector2(d, d + LIP)
	size = custom_minimum_size
	pivot_offset = Vector2(d, d) * 0.5
	# Temas gölgesi: 1.9d × 0.8d yassı elips, merkezi gövdenin %86'sında.
	_place(_shadow, -0.45 * d, 0.46 * d, 1.45 * d, 1.26 * d)
	_place(_halo, -0.72 * d, -0.72 * d, 1.72 * d, 1.72 * d)
	var ring_w: float = RING_WIDTH + (1.0 if _state == State.CURRENT or _state == State.ENDLESS_OPEN else 0.0)
	var rim_w: float = RIM_WIDTH + ring_w
	var outline_w: float = rim_w + OUTLINE_WIDTH
	_place(_outline, -outline_w, -outline_w, d + outline_w, d + outline_w)
	_place(_rim, -rim_w, -rim_w, d + rim_w, d + rim_w)
	_place(_ring, -ring_w, -ring_w, d + ring_w, d + ring_w)
	# Cam yuva: %74 çap, merkez hafif yukarıda (alt dudak payı).
	var well: float = 0.74 * d
	var well_center := Vector2(d * 0.5, d * 0.47)
	_place(_glass, well_center.x - well * 0.5, well_center.y - well * 0.5,
		well_center.x + well * 0.5, well_center.y + well * 0.5)
	_place(_shade, 0.11 * d, 0.30 * d, 0.89 * d, 0.92 * d)
	_place(_gloss, 0.15 * d, 0.06 * d, 0.85 * d, 0.56 * d)
	var endless: bool = is_endless()
	var completed: bool = _state == State.COMPLETED
	# Numara: yıldız varken yukarı; font çapla ölçekli (84 → 26, 96 → 30).
	var number_size: int = int(round(d * (0.29 if is_locked() else 0.31)))
	_number.add_theme_font_size_override("font_size", number_size)
	var number_shift: float = -0.09 * d if completed else -0.03 * d
	_place(_number, 0.0, number_shift, d, d + number_shift)
	var crown: float = 0.38 * d
	_crown.custom_minimum_size = Vector2(crown, crown)
	_place(_crown, d * 0.5 - crown * 0.5, d * 0.40 - crown * 0.5 - 0.04 * d,
		d * 0.5 + crown * 0.5, d * 0.40 + crown * 0.5 - 0.04 * d)
	_caption.add_theme_font_size_override("font_size", int(round(d * 0.13)))
	_place(_caption, 0.0, d * 0.58, d, d * 0.82)
	var star: float = 0.22 * d
	for rect in _star_rects:
		rect.custom_minimum_size = Vector2(star, star)
	_place(_stars_row, 0.06 * d, 0.59 * d, 0.94 * d, 0.59 * d + star)
	var lock: float = 0.34 * d
	_lock.custom_minimum_size = Vector2(lock, lock)
	_place(_lock, 0.66 * d, -0.08 * d, 0.66 * d + lock, -0.08 * d + lock)
	_lock.pivot_offset = Vector2(lock, lock) * 0.5
	for i in _sparkles.size():
		var spec: Array = ENDLESS_SPARKLES[i]
		var box: float = float(spec[1]) * d
		var at: Vector2 = Vector2(d, d) * 0.5 + (spec[0] as Vector2) * d
		_sparkles[i].custom_minimum_size = Vector2(box, box)
		_place(_sparkles[i], at.x - box * 0.5, at.y - box * 0.5, at.x + box * 0.5, at.y + box * 0.5)
		_sparkles[i].pivot_offset = Vector2(box, box) * 0.5
	_layout_plaque()


func _layout_plaque() -> void:
	var d: float = _diameter
	var w: float = maxf(_plaque_body.get_combined_minimum_size().x + 8.0, d * 0.7)
	var top: float = d + LIP - PLAQUE_OVERLAP
	_place(_plaque, d * 0.5 - w * 0.5, top, d * 0.5 + w * 0.5, top + PLAQUE_HEIGHT)


static func _place(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = Vector2(left, top)
	node.size = Vector2(right - left, bottom - top)


# --- Hareket ----------------------------------------------------------------

## Odak halesi nefes alır (alfa + %6 ölçek), gövde en fazla %1.5 — yalnız
## basış tween'i çalışmıyorken (UiMotion ölçeği devralır). Sonsuz
## pırıltıları sönümlenir. Sinüs; RNG yok.
func _process(delta: float) -> void:
	_time += delta
	var phase: float = TAU * _time / 1.9
	var breath: float = 0.5 + 0.5 * sin(phase)
	if _focused:
		_halo.self_modulate.a = 0.58 + 0.30 * breath
		var halo_scale: float = 1.0 + 0.07 * breath
		_halo.pivot_offset = _halo.size * 0.5
		_halo.scale = Vector2.ONE * halo_scale
		if not button_pressed and not hold_breath and not _press_tween_running():
			scale = Vector2.ONE * (1.0 + 0.015 * breath)
	for i in _sparkles.size():
		var spec: Array = ENDLESS_SPARKLES[i]
		var twinkle: float = 0.45 + 0.55 * (0.5 + 0.5 * sin(phase * 1.4 + float(spec[2])))
		_sparkles[i].self_modulate.a = twinkle
		_sparkles[i].scale = Vector2.ONE * (0.75 + 0.3 * twinkle)


func _press_tween_running() -> bool:
	if not has_meta(&"ui_motion_tween"):
		return false
	var tween: Tween = get_meta(&"ui_motion_tween")
	return tween != null and tween.is_valid() and tween.is_running()
