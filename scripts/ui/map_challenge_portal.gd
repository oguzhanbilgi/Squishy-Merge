class_name MapChallengePortal
extends Button
## Harita V3 MEYDAN portalı (TASK/059). Normal level düğümüyle KARIŞMAYAN, haritanın yan yolunun (sol pembe köprü)
## ucunda duran özel giriş: dokunuş Main'in MEVCUT MEYDAN OKUMA penceresini açar (`Main.open_daily_challenge`;
## yeni Meydan Okuma merkezi YOK — TASK/063). Text-light (UI_VISUAL_SYSTEM §29): sanat + tek kelime + rozet.
##
## Anatomi (arkadan öne): erik temas gölgesi → pembe hale (nefes) → owner `badge_starburst` yıldız halkası (yavaş döner —
## level dairelerinden ve altın Sonsuz madalyonundan ayrı ŞEKİL) → pembe candy kuyu (`UiKit.candy_well`) içinde bugünün
## GERÇEK hedef dumpling'i (T5 / T6, `DailyChallenge.current_view`) → 2 pırıltı → altta pembe "MEYDAN" plakası → sağ üstte
## durum rozeti: hazır "!" (`AttentionBadge` CLAIM) · bugün tamamlandı nane ✓.
##
## Veri YAZMAZ; durum çağırandan (`setup`). Sahte süre / ödül / deneme sayısı GÖSTERMEZ. Dokunma alanı madalyon +
## plaka (kelimeye dokunuş da çalışır — TASK/058 Günlük plakası dersi); `MOUSE_FILTER_PASS`: harita kaydırması portalın
## üstünden de başlar, kaydırma başlayınca basış iptal olur (NOTIFICATION_SCROLL_BEGIN).

const LABEL: String = "MEYDAN"
## Kuyu çapı (doku ölçeği 1'de); harita düğüm ölçeğiyle büyür.
const WELL_DIAMETER: float = 104.0
## Yıldız halkası / kuyu oranı.
const BURST_SCALE: float = 1.56
## Hedef dumpling / kuyu oranı.
const ART_SCALE: float = 0.74
const PLAQUE_HEIGHT: float = 34.0
## Plaka kuyunun altına bu kadar biner.
const PLAQUE_OVERLAP: float = 10.0
const PLAQUE_FONT: int = 19
## Yıldız halkasının bir tam turu (sn) — sakin, dikkat dağıtmaz.
const SPIN_PERIOD: float = 14.0
const BREATH_PERIOD: float = 2.2
const BURST_ART: Texture2D = preload("res://assets/visual/ui/badge_starburst.png")
const STAR_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
const DUMPLING_VISUAL: GDScript = preload("res://scripts/game/dumpling_visual.gd")

var _well_d: float = WELL_DIAMETER
var _target_tier: int = 5
var _completed: bool = false
var _time: float = 0.0

var _shadow: NinePatchRect
var _glow: NinePatchRect
var _burst: TextureRect
var _well: Control
var _plaque: Control
var _plaque_label: Label
var _claim: AttentionBadge
var _done: Control
var _sparkles: Array[TextureRect] = []


func _init() -> void:
	name = "ChallengePortal"
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_shadow = UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.28))
	_shadow.show_behind_parent = true
	add_child(_shadow)
	_glow = UiKit.patch("popup_glow", Color(UiTokens.PINK, 0.55))
	_glow.show_behind_parent = true
	add_child(_glow)
	_burst = UiKit.art(BURST_ART, 120)
	_burst.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_burst)
	_well = UiKit.candy_well(DUMPLING_VISUAL.TEXTURES[_target_tier - 1], UiTokens.PINK, WELL_DIAMETER,
		WELL_DIAMETER * ART_SCALE)
	add_child(_well)
	for i in 2:
		var spark := UiKit.art(STAR_ART, 18)
		spark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(spark)
		_sparkles.append(spark)
	_build_plaque()
	_claim = AttentionBadge.new()
	add_child(_claim)
	_done = _build_done_badge()
	add_child(_done)
	UiMotion.attach_press(self)
	_apply_state()
	_apply_size()


## Pembe plaka: koyu pembe kenar + pembe gövde + beyaz Baloo "MEYDAN" (krem "OYNA" plakalarından ayrı renk ailesi).
func _build_plaque() -> void:
	_plaque = Control.new()
	_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plaque)
	var shadow := UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.26))
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = -10.0
	shadow.offset_top = -6.0
	shadow.offset_right = 10.0
	shadow.offset_bottom = 12.0
	_plaque.add_child(shadow)
	var rim := UiKit.flat_plate("badge_round", UiTokens.PINK_DEEP)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rim.offset_left = -3.0
	rim.offset_top = -3.0
	rim.offset_right = 3.0
	rim.offset_bottom = 5.0
	_plaque.add_child(rim)
	var body := UiKit.flat_plate("badge_round", UiTokens.PINK)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plaque.add_child(body)
	var gloss := UiKit.patch("btn_bevel_light", Color(1, 1, 1, 0.30))
	gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_left = 6.0
	gloss.offset_right = -6.0
	gloss.offset_top = 2.0
	gloss.offset_bottom = PLAQUE_HEIGHT * 0.42
	_plaque.add_child(gloss)
	_plaque_label = UiKit.label(LABEL, &"LabelTitleOnDark", HORIZONTAL_ALIGNMENT_CENTER)
	_plaque_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plaque_label.add_theme_font_size_override("font_size", PLAQUE_FONT)
	_plaque_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plaque.add_child(_plaque_label)


## Tamamlandı rozeti: nane daire + beyaz tik ikonu (glif değil — §12 font kapsamı).
func _build_done_badge() -> Control:
	var badge := Control.new()
	badge.name = "DoneBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := UiKit.patch("btn_circle_flat", Color.WHITE)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.offset_left = -3.0
	ring.offset_top = -3.0
	ring.offset_right = 3.0
	ring.offset_bottom = 3.0
	badge.add_child(ring)
	var disc := UiKit.patch("btn_circle_flat", UiTokens.MINT_DEEP)
	disc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(disc)
	var check := UiKit.icon("check", 22, UiTokens.TEXT_ON_DARK)
	check.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	badge.add_child(check)
	badge.set_meta(&"check", check)
	return badge


# --- Kurulum ----------------------------------------------------------------

## Bugünün gerçek durumu: hedef tier (5 / 6) ve bugün tamamlandı mı.
func setup(target_tier: int, completed: bool) -> void:
	_target_tier = clampi(target_tier, 1, DUMPLING_VISUAL.TEXTURES.size())
	_completed = completed
	_apply_state()


## Kuyu çapı (harita düğüm ölçeği uygulanmış).
func set_well_diameter(d: float) -> void:
	_well_d = maxf(d, float(UiTokens.TOUCH_TARGET))
	_apply_size()


func well_diameter() -> float:
	return _well_d


func target_tier() -> int:
	return _target_tier


func is_completed() -> bool:
	return _completed


func label_text() -> String:
	return _plaque_label.text


## "!" (hazır) ya da "✓" (tamam) — test / inceleme.
func status_text() -> String:
	if _done.visible:
		return "✓"
	return _claim.text()


func art_texture() -> Texture2D:
	return (_well.get_meta(&"art") as TextureRect).texture


## Kuyunun merkezi (bu kontrolün yerel uzayında).
func well_center() -> Vector2:
	var burst: float = _well_d * BURST_SCALE
	return Vector2(size.x * 0.5, burst * 0.5)


## Görsel dikdörtgen (global, yıldız halkası + plaka) — çakışma testleri.
func visual_rect() -> Rect2:
	return get_global_rect().merge(_plaque.get_global_rect()).merge(_burst.get_global_rect())


func plaque_rect() -> Rect2:
	return _plaque.get_global_rect()


func _apply_state() -> void:
	var picture: TextureRect = _well.get_meta(&"art")
	picture.texture = DUMPLING_VISUAL.TEXTURES[_target_tier - 1]
	if _completed:
		_claim.clear()
	else:
		_claim.show_claim()
	_done.visible = _completed
	_place_badges()


# --- Ölçü -------------------------------------------------------------------

## Buton dikdörtgeni = yıldız halkası genişliği × (halka üstü .. plaka altı): dokunma alanı madalyon + plaka.
func _apply_size() -> void:
	var d: float = _well_d
	var burst: float = d * BURST_SCALE
	var plaque_top: float = burst * 0.5 + d * 0.5 - PLAQUE_OVERLAP
	custom_minimum_size = Vector2(burst, plaque_top + PLAQUE_HEIGHT + 4.0)
	size = custom_minimum_size
	pivot_offset = Vector2(burst * 0.5, burst * 0.5)
	var center := Vector2(burst * 0.5, burst * 0.5)
	_place(_shadow, center.x - d * 0.80, center.y + d * 0.22, center.x + d * 0.80, center.y + d * 0.78)
	_place(_glow, center.x - burst * 0.78, center.y - burst * 0.78, center.x + burst * 0.78, center.y + burst * 0.78)
	_burst.custom_minimum_size = Vector2(burst, burst)
	_place(_burst, 0.0, 0.0, burst, burst)
	_burst.pivot_offset = Vector2(burst, burst) * 0.5
	# candy_well: kontrol (d, d + 6) — gövde üstte d × d.
	_well.custom_minimum_size = Vector2(d, d + 6.0)
	_place(_well, center.x - d * 0.5, center.y - d * 0.5, center.x + d * 0.5, center.y + d * 0.5 + 6.0)
	var picture: TextureRect = _well.get_meta(&"art")
	var art_size: float = d * ART_SCALE
	picture.custom_minimum_size = Vector2(art_size, art_size)
	picture.offset_left = -art_size * 0.5
	picture.offset_right = art_size * 0.5
	picture.offset_top = -art_size * 0.5 - 3.0
	picture.offset_bottom = art_size * 0.5 - 3.0
	var spark_specs: Array = [[Vector2(-0.62, -0.30), 0.20], [Vector2(0.58, 0.34), 0.16]]
	for i in _sparkles.size():
		var spec: Array = spark_specs[i]
		var box: float = float(spec[1]) * d
		var at: Vector2 = center + (spec[0] as Vector2) * d
		_sparkles[i].custom_minimum_size = Vector2(box, box)
		_place(_sparkles[i], at.x - box * 0.5, at.y - box * 0.5, at.x + box * 0.5, at.y + box * 0.5)
		_sparkles[i].pivot_offset = Vector2(box, box) * 0.5
	var text_w: float = _plaque_label.get_combined_minimum_size().x
	var plaque_w: float = clampf(text_w + 30.0, d * 0.9, burst)
	_place(_plaque, center.x - plaque_w * 0.5, plaque_top, center.x + plaque_w * 0.5, plaque_top + PLAQUE_HEIGHT)
	_place_badges()


func _place_badges() -> void:
	var d: float = _well_d
	var burst: float = d * BURST_SCALE
	var corner := Vector2(burst * 0.5 + d * 0.38, burst * 0.5 - d * 0.38)
	_claim.place_at(corner)
	var box: float = 34.0
	_place(_done, corner.x - box * 0.5, corner.y - box * 0.5, corner.x + box * 0.5, corner.y + box * 0.5)
	var check: Control = _done.get_meta(&"check")
	check.offset_left = -11.0
	check.offset_right = 11.0
	check.offset_top = -11.0
	check.offset_bottom = 11.0


static func _place(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = Vector2(left, top)
	node.size = Vector2(right - left, bottom - top)


# --- Hareket ----------------------------------------------------------------

## Kaydırma başladı: BaseButton basışı iptal etti (eylem yok) — basış ölçeği de bırakılır.
func _notification(what: int) -> void:
	if what == NOTIFICATION_SCROLL_BEGIN:
		UiMotion.release(self)
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(is_visible_in_tree())


## Yıldız halkası yavaş döner, hale nefes alır, pırıltılar sönümlenir (sinüs; RNG yok).
func _process(delta: float) -> void:
	_time += delta
	_burst.rotation = TAU * fmod(_time, SPIN_PERIOD) / SPIN_PERIOD
	var breath: float = 0.5 + 0.5 * sin(TAU * _time / BREATH_PERIOD)
	_glow.self_modulate.a = 0.40 + 0.30 * breath
	_glow.pivot_offset = _glow.size * 0.5
	_glow.scale = Vector2.ONE * (1.0 + 0.05 * breath)
	for i in _sparkles.size():
		var twinkle: float = 0.45 + 0.55 * (0.5 + 0.5 * sin(TAU * _time / 1.7 + float(i) * 2.4))
		_sparkles[i].self_modulate.a = twinkle
		_sparkles[i].scale = Vector2.ONE * (0.75 + 0.3 * twinkle)
