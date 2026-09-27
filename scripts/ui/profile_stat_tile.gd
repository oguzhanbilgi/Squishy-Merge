class_name ProfileStatTile
extends Control
## Profil istatistik kutucuğu (TASK/044): 2 sütunlu ızgaranın tek hücresi —
## kart dili (krem `card_bevel_soft` + açık halka + erik gölge + kart yüzü),
## solda candy kuyuda owner sanatı (taç / yıldız / bayrak / tier dumpling'i),
## sağda büyük değer + küçük büyük harf etiket (+ gerekirse not satırı:
## "güncellemeden beri"). Dashboard hücresi DEĞİL; değer yoksa "—" (uydurma yok).

const SIZE: Vector2 = Vector2(330.0, 112.0)
## Alt pay 24: `card_bevel_soft`'un pişmiş dudağı kartın alt kenarından 11–22 px
## yukarıda — içerik krem yüzde kalır (TASK/044 incelemesi, piksel ölçümü).
const BODY_MARGIN: Vector4 = Vector4(14, 10, 14, 24)
const WELL_SIZE: float = 68.0
const WELL_ART: float = 50.0
const VALUE_FONT_SIZE: int = 30
const VALUE_FONT_SIZE_SMALL: int = 22
const CAPTION_FONT_SIZE: int = 14
const EMPTY_VALUE: String = "—"

var _well: Control
var _value: Label
var _caption: Label
var _note: Label


func _init(caption: String = "", art: Texture2D = null, accent: Color = UiTokens.LAVENDER) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	var shadow := UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.28))
	UiKit.inset(shadow, -12.0, -4.0, -12.0, -18.0)
	add_child(shadow)
	var rim := UiKit.flat_plate("frame_round20", UiTokens.LAVENDER_LIGHT)
	UiKit.inset(rim, -4.0, -4.0, -4.0, -4.0)
	add_child(rim)
	var body := UiKit.panel(&"PanelCollectionCard")
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	# İç pay kart yüzüyle aynı (tema 10/8/10/12 değil): içerik alt dudağa binmez.
	body.add_theme_stylebox_override("panel", UiKit.style("card_bevel_soft", UiTokens.CREAM, BODY_MARGIN))
	add_child(body)
	UiKit.card_face(body, BODY_MARGIN)
	body.minimum_size_changed.connect(func() -> void:
		custom_minimum_size.y = maxf(SIZE.y, body.get_combined_minimum_size().y))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	body.add_child(row)
	_well = UiKit.candy_well(art, accent, WELL_SIZE, WELL_ART)
	_well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_well)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", -2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_value = UiKit.label(EMPTY_VALUE, &"LabelTitle")
	_value.name = "Value"
	_value.add_theme_font_size_override("font_size", VALUE_FONT_SIZE)
	_value.clip_text = true
	_value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_value)
	_caption = UiKit.label(caption, &"LabelBadge")
	_caption.name = "Caption"
	_caption.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	_caption.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_caption.clip_text = true
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_caption)
	_note = UiKit.label("", &"LabelCaption")
	_note.name = "Note"
	_note.add_theme_font_size_override("font_size", 13)
	_note.add_theme_color_override("font_color", UiTokens.TEXT_TERTIARY)
	_note.visible = false
	column.add_child(_note)


## Değer + (isteğe bağlı) not. Boş değer "—". Uzun değer (tier adı) küçük punto.
func set_value(value: String, note: String = "") -> void:
	_value.text = value if not value.is_empty() else EMPTY_VALUE
	_value.add_theme_font_size_override("font_size",
		VALUE_FONT_SIZE if _value.text.length() <= 9 else VALUE_FONT_SIZE_SMALL)
	_note.text = note
	_note.visible = not note.is_empty()


func set_art(art: Texture2D, accent: Color) -> void:
	(_well.get_meta(&"art") as TextureRect).texture = art
	UiKit.set_candy_well_accent(_well, accent)


# --- Testler / çekim aracı ----------------------------------------------------

func value_text() -> String:
	return _value.text


func caption_text() -> String:
	return _caption.text


func note_text() -> String:
	return _note.text if _note.visible else ""


func art_texture() -> Texture2D:
	return (_well.get_meta(&"art") as TextureRect).texture
