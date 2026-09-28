class_name PlayerLevelBar
extends HBoxContainer
## Oyuncu Seviyesi satırı (TASK/045): `PlayerLevelBadge` + candy XP rayı + "84 / 180 XP".
## Profil kimlik kartında ve sonuç ekranının kompakt ilerleme şeridinde AYNI bileşen.
##
## Ray yalnız bir SONRAKİ seviyeye ilerlemeyi gösterir (seviye içi XP / gereksinim);
## kümülatif XP asla birincil değer değil. Tam sınırda "0 / gereksinim". Seviye içi
## değerler 400'ü geçemediği için yazı her seviyede aynı genişlikte kalır.
## Ray: temanın candy kaydırıcı dokuları (koyu lacivert oluk + parlak dolgu) — düz
## "bootstrap" çubuğu değil; dolgu candy CYAN, kutlamada altın.
##
## `animate_xp(önce, sonra)` sonuç ekranı içindir: XP sayarak akar, her seviye
## sınırında ray sıfırlanır ve rozet pop eder (çok seviye atlama doğru gösterilir).
## Bloklamaz; `settle()` anında son duruma getirir.

signal level_crossed(level: int)

const XP_FORMAT: String = "%d / %d XP"
const NEXT_FORMAT: String = "SONRAKİ: LV. %d"
const FILL: Color = UiTokens.CYAN
const FILL_CELEBRATE: Color = UiTokens.GOLD
## Akış süresi: taban + geçilen seviye başına (üst sınırlı) — bloklamaz.
const FLOW_BASE: float = 0.75
const FLOW_PER_LEVEL: float = 0.28
const FLOW_MAX: float = 1.9

var _badge: PlayerLevelBadge
var _rail: ProgressBar
var _fill_box: StyleBoxTexture
var _gloss: NinePatchRect
var _xp_label: Label
var _next_label: Label
var _shown_level: int = 1
var _tween: Tween
var _target_xp: int = 0


## `compact`: sonuç ekranı (ince ray, "SONRAKİ" yazısı yok).
func _init(badge_size: float = 76.0, rail_height: float = 22.0, compact: bool = false) -> void:
	name = "LevelBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 14 if not compact else 12)
	_badge = PlayerLevelBadge.new(badge_size)
	add_child(_badge)
	var column := VBoxContainer.new()
	column.name = "Progress"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(column)
	_rail = UiKit.progress_bar(0.0, &"ProgressBarMint", rail_height)
	_rail.name = "XpRail"
	# Adım yok: ray tam oranı gösterir (Range varsayılanı 0.01'e yuvarlardı) ve akış
	# tween'i pürüzsüz dolar.
	_rail.step = 0.0
	_fill_box = UiKit.style("slider_fill_sm", FILL)
	_rail.add_theme_stylebox_override("fill", _fill_box)
	column.add_child(_rail)
	# Candy parıltısı: rayın üst yarısında ince beyaz ışık (dolgu plastik okunsun).
	_gloss = UiKit.patch("btn_bevel_light", Color(1, 1, 1, 0.30))
	_gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_gloss.offset_left = 6.0
	_gloss.offset_right = -6.0
	_gloss.offset_top = 2.0
	_gloss.offset_bottom = maxf(6.0, rail_height * 0.45)
	_rail.add_child(_gloss)
	var row := HBoxContainer.new()
	row.name = "Texts"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	_xp_label = UiKit.label("0 / 60 XP", &"LabelStat")
	_xp_label.name = "XpText"
	_xp_label.add_theme_font_size_override("font_size", 18 if not compact else 17)
	row.add_child(_xp_label)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_next_label = UiKit.label("", &"LabelBadge")
	_next_label.name = "NextText"
	_next_label.add_theme_font_size_override("font_size", 14)
	_next_label.add_theme_color_override("font_color", UiTokens.TEXT_TERTIARY)
	_next_label.visible = not compact
	row.add_child(_next_label)
	show_xp(0)


## Kümülatif XP'yi anında gösterir (seviye, ray, yazılar).
func show_xp(xp: int) -> void:
	_kill_tween()
	_badge.settle()
	_fill_box.modulate_color = FILL
	_target_xp = PlayerProgression.clamp_xp(xp)
	_apply(_target_xp)


## Sonuç ekranı akışı: `from_xp`'den `to_xp`'ye sayarak; geçilen her seviyede ray
## sıfırlanır, rozet kutlar ve `level_crossed` yayılır. Aynı değerse anında gösterir.
func animate_xp(from_xp: int, to_xp: int, delay: float = 0.0) -> void:
	var start: int = PlayerProgression.clamp_xp(from_xp)
	_target_xp = maxi(PlayerProgression.clamp_xp(to_xp), start)
	_kill_tween()
	_apply(start)
	if _target_xp == start:
		return
	var crossed: int = PlayerProgression.level_for_xp(_target_xp) - PlayerProgression.level_for_xp(start)
	var duration: float = minf(FLOW_BASE + FLOW_PER_LEVEL * float(mini(crossed, 4)), FLOW_MAX)
	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)
	_tween.tween_method(_flow, float(start), float(_target_xp), duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_apply.bind(_target_xp))


## Akışı anında bitirir: son durum gösterilir (gizleme / yeniden açma / test).
func settle() -> void:
	_kill_tween()
	_badge.settle()
	_fill_box.modulate_color = FILL
	_apply(_target_xp)


func _flow(value: float) -> void:
	_apply(int(round(value)))


func _apply(xp: int) -> void:
	var level: int = PlayerProgression.level_for_xp(xp)
	var into: int = PlayerProgression.xp_into_level(xp)
	var required: int = PlayerProgression.xp_required_for_next(xp)
	if level > _shown_level and _tween != null and _tween.is_valid():
		_badge.celebrate()
		_fill_box.modulate_color = FILL_CELEBRATE
		level_crossed.emit(level)
	_shown_level = level
	_badge.set_level(level)
	_rail.value = float(into) / float(maxi(required, 1))
	_xp_label.text = XP_FORMAT % [into, required]
	_next_label.text = NEXT_FORMAT % (level + 1)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


# --- Testler / çekim aracı ----------------------------------------------------

func badge() -> PlayerLevelBadge:
	return _badge


func rail() -> ProgressBar:
	return _rail


func xp_text() -> String:
	return _xp_label.text


func next_text() -> String:
	return _next_label.text if _next_label.visible else ""


func level_text() -> String:
	return "LV. %s" % _badge.number_text()


func is_animating() -> bool:
	return _tween != null and _tween.is_valid()
