class_name CollectibleStage
extends Control
## Koleksiyon parçası "sahnesi" (TASK/044): rarity halesi + candy kaide üstünde
## nefes alan GERÇEK final sanat. M8.6-06 Koleksiyon vitrininin görsel reçetesi
## (hale → Legendary altın bloom → erik temas gölgesi → rarity halkalı krem kaide →
## kaide parlaması → pırıltılar → sanat) tek bileşende: Koleksiyon detay penceresi
## ve Profil vitrini / avatarı aynı sahneyi kullanır.
##
## Ölçü kontrolün kendisinden: sanat kutusu kare, genişliğin ve yüksekliğin
## küçüğünden türetilir; kaide sanatın ayak hizasında. Hale/bloom kutunun dışına
## taşar (yumuşak ışık — kırpılmasın diye çağıran kırpmayan bir ebeveyne koyar).
## Gameplay'le bağı YOK (materyal / shader takmaz).

## Karakterin ayakları sanat kutusunun bu oranında; kaide merkezi ayakların biraz
## üstünde ki karakter kaideye OTURSUN (havada durmasın).
const FEET_RATIO: float = 0.87
const PEDESTAL_SINK_RATIO: float = 0.034
## Kaide / gölge / hale ölçüleri sanat kutusuna oranla (M8.6-06: sanat 296 →
## kaide 324×54, gölge 430×136, hale 520, bloom 640).
const PEDESTAL_RATIO: Vector2 = Vector2(1.095, 0.182)
const PEDESTAL_LIP_RATIO: float = 0.027
const SHADOW_RATIO: Vector2 = Vector2(1.45, 0.46)
const HALO_RATIO: float = 1.55
const BLOOM_RATIO: float = 1.9
const PEDESTAL_TINT: float = 0.16
const HALO_ALPHA: Dictionary = {
	SkinData.Rarity.COMMON: 0.42, SkinData.Rarity.RARE: 0.58,
	SkinData.Rarity.EPIC: 0.62, SkinData.Rarity.LEGENDARY: 0.62,
}
## Pırıltılar: sanat merkezine göre (birim = sanat yarıçapı), kutu oranı, faz.
const STARS: Array = [
	[Vector2(-1.10, -0.60), 0.074, 0.0], [Vector2(1.08, -0.74), 0.054, 1.3],
	[Vector2(-1.22, 0.20), 0.047, 2.6], [Vector2(1.20, 0.28), 0.068, 3.9],
	[Vector2(-0.80, -1.02), 0.041, 5.1], [Vector2(0.92, 0.88), 0.041, 0.7],
]
const STAR_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
const BREATH_PERIOD: float = 3.4
const BREATH_SCALE: float = 0.012
const BREATH_RISE_RATIO: float = 0.01
## Kilit rozeti sanatın %26'sı (M8.6-06 vitrin oranı — gövdeyi kapatmaz).
const LOCK_RATIO: float = 0.26

var _bloom: NinePatchRect
var _halo: NinePatchRect
var _shadow: NinePatchRect
var _rim: NinePatchRect
var _lip: NinePatchRect
var _pedestal: NinePatchRect
var _gloss: NinePatchRect
var _stars: Array[TextureRect] = []
var _art_wrap: Control
var _breath: Control
var _swatch: SkinSwatch
var _entry: SkinEntry = null
var _animate: bool = true
var _with_stars: bool = true
var _time: float = 0.0


## `with_stars`: çevre pırıltıları (büyük sahne); `animate`: nefes + pırıltı
## sönümü (_process yalnız görünürken).
func _init(with_stars: bool = true, animate: bool = true) -> void:
	_with_stars = with_stars
	_animate = animate
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloom = _glow_patch(Color(UiTokens.GOLD_BRIGHT, 0.26))
	_bloom.name = "Bloom"
	_bloom.visible = false
	add_child(_bloom)
	_halo = _glow_patch(Color(UiTokens.LAVENDER, 0.3))
	_halo.name = "Halo"
	add_child(_halo)
	_shadow = _glow_patch(Color(0.22, 0.09, 0.36, 0.42))
	_shadow.name = "PedestalShadow"
	add_child(_shadow)
	_rim = _circle(UiTokens.LAVENDER_LIGHT, "PedestalRim")
	_lip = _circle(UiTokens.LAVENDER_DEEP, "PedestalLip")
	_pedestal = _circle(UiTokens.TRAY_CREAM, "Pedestal")
	_gloss = _circle(Color(1, 1, 1, 0.55), "PedestalGloss")
	if with_stars:
		for spec in STARS:
			var star := UiKit.art(STAR_ART, 16.0)
			star.set_anchors_preset(Control.PRESET_TOP_LEFT)
			star.modulate.a = 0.55
			add_child(star)
			_stars.append(star)
	_art_wrap = Control.new()
	_art_wrap.name = "Art"
	_art_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art_wrap)
	_breath = Control.new()
	_breath.name = "Breath"
	_breath.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_breath.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art_wrap.add_child(_breath)
	_swatch = SkinSwatch.new()
	_swatch.name = "Preview"
	_swatch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_swatch.lock_badge_ratio = LOCK_RATIO
	_breath.add_child(_swatch)
	resized.connect(_layout)
	visibility_changed.connect(func() -> void: set_process(_animate and is_visible_in_tree()))


func _ready() -> void:
	set_process(_animate and is_visible_in_tree())
	_layout()


## Parçayı sahneye koyar. `reveal_locked`: kilitli parçada final sanat soluk +
## kilit (owner kararı M8.5-14 / M8.6-06); false → silüet.
func setup(entry: SkinEntry, reveal_locked: bool = true) -> void:
	_entry = entry
	_swatch.setup(entry, reveal_locked)
	var rarity: int = int(entry.rarity) if entry != null else 0
	var is_default: bool = entry == null or entry.is_default()
	var halo_color: Color = UiTokens.rarity_color(rarity)
	if is_default or rarity == SkinData.Rarity.COMMON:
		halo_color = UiTokens.LAVENDER
	elif rarity == SkinData.Rarity.LEGENDARY:
		halo_color = UiTokens.GOLD
	_halo.self_modulate = Color(halo_color, float(HALO_ALPHA.get(rarity, 0.3)) * (0.6 if is_default else 1.0))
	var rim_color: Color = UiTokens.LAVENDER_LIGHT
	if not is_default:
		match rarity:
			SkinData.Rarity.RARE: rim_color = UiTokens.RARITY_RARE.lerp(Color.WHITE, 0.3)
			SkinData.Rarity.EPIC: rim_color = UiTokens.RARITY_EPIC.lerp(Color.WHITE, 0.3)
			SkinData.Rarity.LEGENDARY: rim_color = UiTokens.GOLD
	_rim.self_modulate = rim_color
	var surface: Color = UiTokens.TRAY_CREAM
	if not is_default and rarity != SkinData.Rarity.COMMON:
		surface = UiTokens.TRAY_CREAM.lerp(halo_color, PEDESTAL_TINT)
	_pedestal.self_modulate = surface
	_bloom.visible = not is_default and rarity == SkinData.Rarity.LEGENDARY
	_layout()


## Sanat kutusu kenarı (kare): genişlik ve yüksekliğin sığan en büyüğü (kaide
## sanatın altından bir miktar taşar).
func art_size() -> float:
	return maxf(minf(size.x / PEDESTAL_RATIO.x, size.y / (FEET_RATIO + PEDESTAL_RATIO.y * 0.6)), 1.0)


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var art: float = art_size()
	var cx: float = size.x * 0.5
	var art_top: float = 0.0
	var center := Vector2(cx, art_top + art * 0.5)
	_art_wrap.position = Vector2(cx - art * 0.5, art_top)
	_art_wrap.size = Vector2(art, art)
	_art_wrap.pivot_offset = _art_wrap.size * 0.5
	_breath.pivot_offset = Vector2(art * 0.5, art * 0.86)
	_place(_halo, center, Vector2.ONE * art * HALO_RATIO)
	_place(_bloom, center + Vector2(0.0, art * 0.03), Vector2.ONE * art * BLOOM_RATIO)
	var seat_y: float = art_top + art * FEET_RATIO - art * PEDESTAL_SINK_RATIO
	var ped: Vector2 = art * PEDESTAL_RATIO
	var lip: float = art * PEDESTAL_LIP_RATIO
	_place(_shadow, Vector2(cx, seat_y + art * 0.074), art * SHADOW_RATIO)
	_place(_rim, Vector2(cx, seat_y + lip * 0.5), ped + Vector2(10.0, 10.0 + lip))
	_place(_lip, Vector2(cx, seat_y + lip), ped)
	_place(_pedestal, Vector2(cx, seat_y), ped)
	_place(_gloss, Vector2(cx, seat_y - ped.y * 0.19), Vector2(ped.x * 0.58, maxf(ped.y * 0.26, 4.0)))
	for i in _stars.size():
		var spec: Array = STARS[i]
		var box: float = art * float(spec[1])
		var at: Vector2 = center + (spec[0] as Vector2) * art * 0.5
		_stars[i].position = at - Vector2(box, box) * 0.5
		_stars[i].size = Vector2(box, box)
		_stars[i].pivot_offset = Vector2(box, box) * 0.5


func _process(delta: float) -> void:
	_time += delta
	var phase: float = TAU * _time / BREATH_PERIOD
	var art: float = _art_wrap.size.x
	_breath.scale = Vector2.ONE * (1.0 + BREATH_SCALE * sin(phase))
	_breath.position.y = -art * BREATH_RISE_RATIO * (0.5 + 0.5 * sin(phase))
	for i in _stars.size():
		var spec: Array = STARS[i]
		var twinkle: float = 0.35 + 0.5 * (0.5 + 0.5 * sin(TAU * _time / 2.6 + float(spec[2])))
		_stars[i].modulate.a = twinkle
		_stars[i].scale = Vector2.ONE * (0.8 + 0.3 * twinkle)


## Kutlama: sanat pop'u (vitrine eklendi / avatar oldu).
func celebrate() -> void:
	UiMotion.pop(_art_wrap, 1.08)


static func _place(node: Control, center: Vector2, box: Vector2) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = center - box * 0.5
	node.size = box
	node.pivot_offset = box * 0.5


func _glow_patch(tint: Color) -> NinePatchRect:
	var patch := UiKit.patch("popup_glow", tint)
	patch.set_anchors_preset(Control.PRESET_TOP_LEFT)
	return patch


func _circle(tint: Color, node_name: String) -> NinePatchRect:
	var patch := UiKit.patch("item_circle_inner", tint)
	patch.name = node_name
	patch.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(patch)
	return patch


# --- Testler / çekim aracı ----------------------------------------------------

func entry() -> SkinEntry:
	return _entry


func swatch() -> SkinSwatch:
	return _swatch


func art_box() -> Control:
	return _art_wrap


func halo() -> NinePatchRect:
	return _halo


func bloom() -> NinePatchRect:
	return _bloom


func pedestal() -> NinePatchRect:
	return _pedestal
