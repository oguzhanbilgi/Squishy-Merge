class_name AchievementCard
extends Control
## Başarım kartı (TASK/045) — Profil kartlarıyla aynı malzeme (erik gölge → açık
## halka → krem `card_bevel_soft` gövde + kart yüzü). Solda `AchievementBadge`,
## sağda ad (Baloo) + durum çipi, açıklama, ilerleme rayı + "73 / 100", ödül
## unvanı satırı ("Unvan: Hamur Ustası").
##
##   AÇIK     kenar altın, rozet tam renk, altın ray tam dolu, nane "AÇILDI" çipi —
##            kutlamalı ama okunur.
##   KİLİTLİ  kenar lavanta, rozet buzlu + kilit, nane ray kısmi; kart YİNE görünür
##            (V1'de gizli başarım yok).
##
## `compact`: Profil'in "sıradaki hedefler" özeti — kart kromu YOK (Profil'in krem
## BAŞARIMLAR kartının içinde düz satır; kart içinde kart olmasın), küçük rozet.
## Veri yalnız `PlayerProfile.achievement_row()` sözlüğünden; kayda YAZMAZ, dokunma
## ALMAZ (kaydırma kartın üstünden de başlar).

## Alt pay 24: `card_bevel_soft`'un pişmiş dudağı kartın alt kenarından 11–22 px
## yukarıda — içerik krem yüzde kalır (TASK/044 ölçümü).
const BODY_MARGIN: Vector4 = Vector4(14, 12, 16, 24)
const BADGE_SIZE: float = 84.0
const BADGE_SIZE_COMPACT: float = 64.0
const MIN_HEIGHT: float = 132.0
const MIN_HEIGHT_COMPACT: float = 76.0
const OPEN_TEXT: String = "AÇILDI"
const TITLE_FORMAT: String = "Unvan: %s"
const PROGRESS_FORMAT: String = "%d / %d"

var _compact: bool = false
var _rim: PanelContainer
var _badge: AchievementBadge
var _name: Label
var _chip: PanelContainer
var _description: Label
var _rail: ProgressBar
var _progress: Label
var _title_row: HBoxContainer
var _title_label: Label
var _row: Dictionary = {}


func _init(compact: bool = false) -> void:
	_compact = compact
	name = "AchievementCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var min_height: float = MIN_HEIGHT_COMPACT if compact else MIN_HEIGHT
	custom_minimum_size = Vector2(0, min_height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body: Container
	if compact:
		body = MarginContainer.new()
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(body)
	else:
		var shadow := UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.26))
		UiKit.inset(shadow, -12.0, -4.0, -12.0, -18.0)
		add_child(shadow)
		_rim = UiKit.flat_plate("frame_round20", Color.WHITE)
		_rim.self_modulate = UiTokens.LAVENDER_LIGHT
		UiKit.inset(_rim, -4.0, -4.0, -4.0, -4.0)
		add_child(_rim)
		var panel := UiKit.panel(&"PanelCollectionCard")
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.add_theme_stylebox_override("panel", UiKit.style("card_bevel_soft", UiTokens.CREAM, BODY_MARGIN))
		add_child(panel)
		UiKit.card_face(panel, BODY_MARGIN)
		body = panel
	body.minimum_size_changed.connect(func() -> void:
		custom_minimum_size.y = maxf(min_height, body.get_combined_minimum_size().y))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	body.add_child(row)
	_badge = AchievementBadge.new(BADGE_SIZE_COMPACT if compact else BADGE_SIZE)
	row.add_child(_badge)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 3)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 8)
	column.add_child(head)
	_name = UiKit.label("", &"LabelSection")
	_name.name = "Name"
	_name.add_theme_font_size_override("font_size", 20 if compact else 22)
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_name)
	_chip = PanelContainer.new()
	_chip.name = "OpenChip"
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chip.add_theme_stylebox_override("panel", UiKit.style("frame_round20", UiTokens.MINT, Vector4(10, 2, 12, 4)))
	var chip_row := HBoxContainer.new()
	chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_row.add_theme_constant_override("separation", 4)
	_chip.add_child(chip_row)
	var check := UiKit.icon("check", 16, UiTokens.TEXT_ON_ACCENT)
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip_row.add_child(check)
	var chip_label := UiKit.label(OPEN_TEXT, &"LabelBadge")
	chip_label.add_theme_font_size_override("font_size", 14)
	chip_row.add_child(chip_label)
	head.add_child(_chip)
	_description = UiKit.label("", &"LabelCaption")
	_description.name = "Description"
	_description.add_theme_font_size_override("font_size", 15 if compact else 16)
	_description.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_description)
	var bar_row := HBoxContainer.new()
	bar_row.name = "ProgressRow"
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_theme_constant_override("separation", 10)
	column.add_child(bar_row)
	_rail = UiKit.progress_bar(0.0, &"ProgressBarMint", 14.0)
	_rail.name = "Rail"
	_rail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(_rail)
	_progress = UiKit.label("", &"LabelStat")
	_progress.name = "Progress"
	_progress.add_theme_font_size_override("font_size", 16)
	bar_row.add_child(_progress)
	_title_row = HBoxContainer.new()
	_title_row.name = "TitleReward"
	_title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_row.add_theme_constant_override("separation", 6)
	column.add_child(_title_row)
	var crown := UiKit.art(UiIcons.CROWN, 20.0)
	crown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title_row.add_child(crown)
	_title_label = UiKit.label("", &"LabelBadge")
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.clip_text = true
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_row.add_child(_title_label)


## `row`: PlayerProfile.achievement_row() sözlüğü.
func setup(row: Dictionary) -> void:
	_row = row
	if row.is_empty():
		visible = false
		return
	visible = true
	name = "Achievement_%s" % String(row["id"])
	var open: bool = bool(row["unlocked"])
	var goal: int = int(row["target"])
	var value: int = clampi(int(row["value"]), 0, goal)
	_badge.setup(row["id"], open)
	_name.text = String(row["name"])
	_description.text = String(row["description"])
	_chip.visible = open
	if _rim != null:
		_rim.self_modulate = UiTokens.GOLD if open else UiTokens.LAVENDER_LIGHT
	_rail.theme_type_variation = &"ProgressBarGold" if open else &"ProgressBarMint"
	_rail.value = float(value) / float(maxi(goal, 1))
	_progress.text = PROGRESS_FORMAT % [value, goal]
	_progress.add_theme_color_override("font_color", UiTokens.GOLD_DEEP if open else UiTokens.TEXT_PRIMARY)
	var title_name: String = String(row.get("title_name", ""))
	_title_row.visible = not title_name.is_empty()
	_title_label.text = TITLE_FORMAT % title_name
	_title_label.add_theme_color_override("font_color", UiTokens.GOLD_DEEP if open else UiTokens.TEXT_TERTIARY)
	(_title_row.get_child(0) as CanvasItem).self_modulate = Color.WHITE if open else Color(1, 1, 1, 0.45)


# --- Testler / çekim aracı ----------------------------------------------------

func row() -> Dictionary:
	return _row


func achievement_id() -> StringName:
	return _row.get("id", &"")


func badge() -> AchievementBadge:
	return _badge


func name_text() -> String:
	return _name.text


func description_text() -> String:
	return _description.text


func progress_text() -> String:
	return _progress.text


func title_text() -> String:
	return _title_label.text if _title_row.visible else ""


func is_open_shown() -> bool:
	return _chip.visible


func rail() -> ProgressBar:
	return _rail
