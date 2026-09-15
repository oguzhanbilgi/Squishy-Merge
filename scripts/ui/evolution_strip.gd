class_name EvolutionStrip
extends PanelContainer
## Evrim şeridi (M8.6-02): 8 gerçek gameplay tier'ı sırayla, küçük bir koyu
## tepside. Envanter DEĞİL — "neyi hedefliyorum?" sorusunu tek bakışta
## cevaplar. Metin yok.
##
## Okuma: erik bevel raf (`PanelStrip` + üst ışık); ulaşılmış tier'lar tam
## opak, ulaşılmamışlar hafif soluk (görünür kalır — motivasyon); bu
## round'da ulaşılan en yüksek tier yumuşak krem hale + %15 büyütme, level
## hedefi altın küçük halka. Tier dokuları `DumplingVisual.TEXTURES`
## (owner sanatı) — başka bir kaynak yok. Neon seçim çerçevesi YOK.

## Tier dokuları: gameplay sprite'larının kendisi (owner sanatı).
const DUMPLING_VISUAL: GDScript = preload("res://scripts/game/dumpling_visual.gd")
## Ulaşılmamış tier'ın opaklığı.
const UNREACHED_ALPHA: float = 0.72
## Kutu ölçüleri: tier 1 küçük, tier 8 büyük — ilerleme hissi.
const ART_MIN: float = 34.0
const ART_MAX: float = 50.0
## Ulaşılan tier'ın büyütmesi ve hale rengi.
const REACHED_SCALE: float = 1.15
const HALO_COLOR: Color = Color(UiTokens.CREAM, 0.42)

var _cells: Array[Control] = []
var _arts: Array[TextureRect] = []
var _glows: Array[Control] = []
var _targets: Array[Control] = []
var _reached: int = 0
var _target: int = 0


func _ready() -> void:
	theme_type_variation = &"PanelStrip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Raf üst ışığı (UiKit.plate ile aynı katman).
	var light := UiKit.patch("panel_bevel_light", Color(1, 1, 1, 0.14))
	light.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	light.offset_bottom = 28.0
	add_child(light)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for i in TierConfig.MAX_TIER:
		var cell := Control.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.custom_minimum_size = Vector2(ART_MAX + 12.0, ART_MAX + 4.0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cell)
		var art_size: float = lerpf(ART_MIN, ART_MAX, float(i) / float(TierConfig.MAX_TIER - 1))
		var glow := UiKit.patch("btn_circle_flat", HALO_COLOR)
		glow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		var g: float = art_size * 0.5 + 6.0
		glow.offset_left = -g
		glow.offset_top = -g
		glow.offset_right = g
		glow.offset_bottom = g
		glow.visible = false
		cell.add_child(glow)
		var art := UiKit.art(DUMPLING_VISUAL.TEXTURES[i], art_size)
		art.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		art.offset_left = -art_size * 0.5
		art.offset_top = -art_size * 0.5
		art.offset_right = art_size * 0.5
		art.offset_bottom = art_size * 0.5
		art.pivot_offset = Vector2(art_size, art_size) * 0.5
		cell.add_child(art)
		# Hedef işareti: altın küçük halka, kutunun sağ üstünde.
		var mark := UiKit.patch("alert_dot_ring", UiTokens.GOLD)
		mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		mark.offset_left = art_size * 0.5 - 8.0
		mark.offset_top = -art_size * 0.5 - 6.0
		mark.offset_right = art_size * 0.5 + 8.0
		mark.offset_bottom = -art_size * 0.5 + 10.0
		mark.visible = false
		cell.add_child(mark)
		_cells.append(cell)
		_arts.append(art)
		_glows.append(glow)
		_targets.append(mark)
	_refresh()


## Bu round'da ulaşılan en yüksek tier (1..8). Yükselince kısa pop.
func set_reached(tier: int) -> void:
	tier = clampi(tier, 0, TierConfig.MAX_TIER)
	if tier == _reached:
		return
	var rose: bool = tier > _reached
	_reached = tier
	_refresh()
	if rose and _reached >= 1:
		UiMotion.pop(_cells[_reached - 1], 1.25)


## Level hedefi (0 = hedef yok, sonsuz mod).
func set_target(tier: int) -> void:
	_target = clampi(tier, 0, TierConfig.MAX_TIER)
	_refresh()


func reached() -> int:
	return _reached


func entry_count() -> int:
	return _arts.size()


func entry_texture(index: int) -> Texture2D:
	return _arts[index].texture


func _refresh() -> void:
	for i in _arts.size():
		var tier: int = i + 1
		_arts[i].self_modulate.a = 1.0 if tier <= _reached else UNREACHED_ALPHA
		var current: bool = tier == _reached and _reached > 0
		_glows[i].visible = current
		_arts[i].scale = Vector2.ONE * (REACHED_SCALE if current else 1.0)
		_targets[i].visible = tier == _target
