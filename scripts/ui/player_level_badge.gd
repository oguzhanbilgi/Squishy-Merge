class_name PlayerLevelBadge
extends Control
## Oyuncu Seviyesi rozeti (TASK/045) — candy disk: Mağaza / Profil kuyularıyla aynı
## malzeme (`UiKit.candy_well`: vurgu halesi, erik temas gölgesi, koyu oturak, açık
## lavanta halka, koyu lavanta gövde, gloss), üstünde küçük "LV." ve büyük Baloo
## seviye sayısı. Rakam arttıkça punto küçülür: LV. 7'den bozukluk sınırındaki
## LV. 2 500 018'e kadar kırpılmadan sığar (seviyenin tasarım tavanı yok).
## Dokunma almaz (dekor). `celebrate()` seviye atlamada altın parıltı + pop.

const LV_TEXT: String = "LV."
const BODY: Color = UiTokens.LAVENDER_DEEP
## Rakam sayısı → 76 px diskte punto (çap oranıyla ölçeklenir).
const NUMBER_SIZES: Array[int] = [36, 36, 30, 25, 21, 18, 16, 14]

var _diameter: float = 76.0
var _well: Control
var _caption: Label
var _number: Label
var _level: int = 1
var _tween: Tween


func _init(diameter: float = 76.0) -> void:
	_diameter = diameter
	name = "LevelBadge"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(diameter, diameter + 6.0)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pivot_offset = custom_minimum_size * 0.5
	_well = UiKit.candy_well(null, BODY, diameter, 0.0)
	_well.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_well)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(-diameter * 0.16))
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Gövde dairesi dikdörtgenin üst `diameter` px'i (alt 6 px oturak): yazı gövdede ortalanır.
	column.offset_top = diameter * 0.04
	column.offset_bottom = -6.0 - diameter * 0.04
	add_child(column)
	_caption = UiKit.label(LV_TEXT, &"LabelBadgeOnDark", HORIZONTAL_ALIGNMENT_CENTER)
	_caption.name = "Caption"
	_caption.add_theme_font_size_override("font_size", int(round(diameter * 0.19)))
	_caption.add_theme_color_override("font_color", UiTokens.LAVENDER_LIGHT)
	column.add_child(_caption)
	_number = UiKit.label("1", &"LabelTitleOnDark", HORIZONTAL_ALIGNMENT_CENTER)
	_number.name = "Number"
	_number.add_theme_color_override("font_outline_color", UiTokens.TEXT_PRIMARY)
	_number.add_theme_constant_override("outline_size", maxi(2, int(diameter * 0.06)))
	column.add_child(_number)
	set_level(1)


func set_level(level: int) -> void:
	_level = maxi(level, 1)
	_number.text = str(_level)
	var digits: int = _number.text.length()
	var base: int = NUMBER_SIZES[mini(digits, NUMBER_SIZES.size()) - 1]
	_number.add_theme_font_size_override("font_size", maxi(10, int(round(base * _diameter / 76.0))))


func level() -> int:
	return _level


## Üst yazı (varsayılan "LV." — Profil / sonuç). TASK/058 K9: Ana Sayfa Türkçe "SV." kullanır (harita "BÖLÜM"üyle
## karışmasın); punto aynı (çapın %19'u).
func set_caption(text: String) -> void:
	_caption.text = text


## Seviye atlama: disk kısa bir altın parıltıyla pop eder (kutlama, bloklamaz).
func celebrate() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	UiKit.set_candy_well_accent(_well, UiTokens.GOLD_DEEP.lerp(UiTokens.GOLD, 0.35))
	pivot_offset = size * 0.5
	scale = Vector2.ONE * 1.18
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(0.35)
	_tween.chain().tween_callback(func() -> void: UiKit.set_candy_well_accent(_well, BODY))


## Kutlamayı anında bitirir (sonuç ekranı gizlenince / yeniden açılınca).
func settle() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	scale = Vector2.ONE
	UiKit.set_candy_well_accent(_well, BODY)


# --- Testler / çekim aracı ----------------------------------------------------

func number_text() -> String:
	return _number.text


func number_label() -> Label:
	return _number


func caption_text() -> String:
	return _caption.text
