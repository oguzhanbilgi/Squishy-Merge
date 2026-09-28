class_name AchievementBadge
extends Control
## Başarım rozeti (TASK/045): owner'ın candy yıldız patlaması halkası
## (`badge_starburst.png` — HUD combo rozetiyle aynı sanat) + ortada kategori
## sanatı (owner varlıkları: merge merdiveninde tier dumpling'leri 2 / 4 / 6 / 8,
## yıldız, taç, bayrak, kanonik Squishy, maskot, buharlı sepet) + altta hedef çipi
## ("100", "30") — 12 rozetin her biri ayırt edilir.
##
##   AÇIK     tam renk halka + sıcak altın parıltı, altın çip.
##   KİLİTLİ  buzlu lavanta halka + soluk sanat + kilit rozeti, lavanta çip
##            (Koleksiyon'un kilitli kart dili: sanat görünür, "keşfedilecek").
##
## Dokunma almaz (dekor). Varsayılan unvan için `setup(&"", true)`: hedef çipi yok.

const STARBURST: Texture2D = preload("res://assets/visual/ui/badge_starburst.png")
const TIER_ART: Array[Texture2D] = [
	preload("res://assets/visual/dumpling_tier1.png"), preload("res://assets/visual/dumpling_tier2.png"),
	preload("res://assets/visual/dumpling_tier3.png"), preload("res://assets/visual/dumpling_tier4.png"),
	preload("res://assets/visual/dumpling_tier5.png"), preload("res://assets/visual/dumpling_tier6.png"),
	preload("res://assets/visual/dumpling_tier7.png"), preload("res://assets/visual/dumpling_tier8.png"),
]
const MASCOT_ART: Texture2D = preload("res://assets/visual/ui/tutorial_pose.png")
const BASKET_ART: Texture2D = preload("res://assets/visual/ui/chest_open.png")
## Başarım → sanat (katalog id'si). Bilinmeyen / varsayılan unvan: tier 1 Squishy.
const ART_BY_ID: Dictionary = {
	&"first_merge": 1, &"merge_100": 3, &"merge_500": 5, &"merge_1000": 7,
	&"stars_5": "star", &"stars_15": "star", &"stars_30": "crown",
	&"levels_3": "flag", &"levels_10": "flag",
	&"collection_5": 2, &"collection_10": "mascot", &"collection_20": "basket",
}
## Kilitli: buzlu lavanta — halka ve sanat yarı saydam, soğuk tonlu (altın-pembe
## halka çarpımla kahverengiye dönmesin; krem kartta "henüz değil" okunur).
const LOCKED_RING: Color = Color(0.80, 0.76, 0.96, 0.50)
const LOCKED_ART: Color = Color(0.86, 0.84, 0.98, 0.62)
const GLOW_OPEN: Color = Color(1.0, 0.82, 0.40, 0.42)
## Oranlar (çapa göre).
const ART_RATIO: float = 0.50
const PIP_HEIGHT_RATIO: float = 0.27
## Hedef çipinin halka karesinin altına sarkan kısmı (çip yüksekliğine oranla). Bu pay
## rozetin KUTUSUNA dahildir: kartlar kutuya göre yerleşir, çip kartın pişmiş alt
## dudağına binmez (lens 5 bulgusu — çip eskiden kutunun 8–10 px altına taşıyordu).
const PIP_OVERHANG_RATIO: float = 0.38

var _diameter: float = 84.0
var _id: StringName = &""
var _unlocked: bool = false
var _glow: NinePatchRect
var _ring: TextureRect
var _art: TextureRect
var _lock: TextureRect
var _pip: PanelContainer
var _pip_label: Label


func _init(diameter: float = 84.0) -> void:
	_diameter = diameter
	name = "AchievementBadge"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pip_h: float = maxf(20.0, diameter * PIP_HEIGHT_RATIO)
	# Kutu = üstte halka karesi + altta çipin sarkan payı.
	custom_minimum_size = Vector2(diameter, diameter + ceilf(pip_h * PIP_OVERHANG_RATIO))
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_glow = UiKit.patch("popup_glow", GLOW_OPEN)
	_square(_glow, diameter * 0.22)
	add_child(_glow)
	_ring = UiKit.art(STARBURST, diameter)
	_ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_square(_ring, 0.0)
	add_child(_ring)
	var art_size: float = diameter * ART_RATIO
	_art = UiKit.art(TIER_ART[0], art_size)
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_square(_art, -(diameter - art_size) * 0.5)
	add_child(_art)
	var lock_size: float = diameter * 0.30
	_lock = UiKit.art(UiIcons.LOCK, lock_size)
	_lock.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_lock.offset_left = -lock_size - diameter * 0.02
	_lock.offset_right = -diameter * 0.02
	_lock.offset_top = diameter * 0.02
	_lock.offset_bottom = lock_size + diameter * 0.02
	add_child(_lock)
	_pip = PanelContainer.new()
	_pip.name = "Pip"
	_pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Çipin altı kutunun altı; yazı çipten uzunsa YUKARI (halkaya doğru) büyür.
	_pip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_pip.offset_top = -pip_h
	_pip.offset_bottom = 0.0
	_pip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_pip)
	_pip_label = UiKit.label("", &"LabelBadge", HORIZONTAL_ALIGNMENT_CENTER)
	_pip_label.add_theme_font_size_override("font_size", maxi(11, int(round(diameter * 0.16))))
	_pip.add_child(_pip_label)
	setup(&"", true)


## `id`: katalog başarımı (boş = varsayılan unvan rozeti). `unlocked`: renk / kilit.
func setup(id: StringName, unlocked: bool) -> void:
	_id = id
	_unlocked = unlocked
	_art.texture = art_for(id)
	var goal: int = AchievementCatalog.target(id)
	_pip.visible = goal > 0
	_pip_label.text = str(goal)
	_pip.add_theme_stylebox_override("panel", UiKit.style("badge_round",
		UiTokens.GOLD if unlocked else UiTokens.LAVENDER_SURFACE, Vector4(8, 0, 8, 3)))
	_pip_label.add_theme_color_override("font_color", UiTokens.TEXT_ON_ACCENT if unlocked else UiTokens.TEXT_SECONDARY)
	_ring.self_modulate = Color.WHITE if unlocked else LOCKED_RING
	_art.self_modulate = Color.WHITE if unlocked else LOCKED_ART
	_glow.visible = unlocked
	_lock.visible = not unlocked


## `control`'ü kutunun üstündeki halka karesine yerleştirir; `pad` > 0 dışa taşar
## (parıltı), < 0 içe çeker (ortadaki sanat).
func _square(control: Control, pad: float) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = -pad
	control.offset_top = -pad
	control.offset_right = _diameter + pad
	control.offset_bottom = _diameter + pad


static func art_for(id: StringName) -> Texture2D:
	var key: Variant = ART_BY_ID.get(id, 0)
	if typeof(key) == TYPE_INT:
		return TIER_ART[clampi(int(key), 0, TIER_ART.size() - 1)]
	match String(key):
		"star": return UiIcons.STAR_FILLED
		"crown": return UiIcons.CROWN
		"flag": return UiIcons.FLAG
		"mascot": return MASCOT_ART
		"basket": return BASKET_ART
	return TIER_ART[0]


# --- Testler / çekim aracı ----------------------------------------------------

func achievement_id() -> StringName:
	return _id


func is_unlocked() -> bool:
	return _unlocked


func art_texture() -> Texture2D:
	return _art.texture


func pip_text() -> String:
	return _pip_label.text if _pip.visible else ""


func lock_visible() -> bool:
	return _lock.visible
