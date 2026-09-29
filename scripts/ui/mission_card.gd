class_name MissionCard
extends PanelContainer
## Görev kartı (TASK/046) — GÜNLÜK ÖDÜLLER seçenek kartının malzemesi (bir ton geri krem
## `card_bevel_soft` gövde + ince lavanta halka). Solda metrik kuyusu (`candy_well`: merge →
## owner dumpling'i · tur → oyna pictosu · level → owner bayrağı), ortada görev metni (Baloo) +
## durum çipi, altında ilerleme rayı + "7 / 15"; sağda Hamur ödül rozeti (owner Hamur sanatı +
## "+10").
##
##   DEVAM       krem gövde, lavanta halka, nane ray kısmi, çip yok.
##   TAMAMLANDI  açık nane gövde + nane halka, nane ray tam dolu, nane "✓ TAMAMLANDI" çipi,
##               sayaç nane — ödül otomatik eklendi (talep butonu YOK).
## Sayaç sabit genişlikte sağa yaslı: altı kartın rayları aynı boyda hizalanır.
##
## Veri yalnız `Missions.rows()` satırından; kayda YAZMAZ, dokunma ALMAZ (kaydırma kartın
## üstünden de başlar).

const BODY_MARGIN: Vector4 = Vector4(16, 12, 16, 16)
const WELL_SIZE: float = 56.0
const WELL_ART: float = 38.0
const MIN_HEIGHT: float = 96.0
## "120 / 120" sığar; bütün kartlarda aynı → raylar hizalı.
const PROGRESS_WIDTH: float = 84.0
const RING_WIDTH: float = 3.0
## Tamamlanan kartın gövdesi: krem → hafif nane (başarı, göz yormadan listede seçilir).
const BODY_DONE: Color = Color("e3f5e6")
const DONE_TEXT: String = "TAMAMLANDI"
const PROGRESS_FORMAT: String = "%d / %d"
const REWARD_FORMAT: String = "+%d"
const DOUGH_ART: Texture2D = preload("res://assets/visual/ui/icon_dough.png")
const MERGE_ART: Texture2D = preload("res://assets/visual/dumpling_tier3.png")
const CLEAR_ART: Texture2D = preload("res://assets/visual/ui/icon_flag.png")

var _ring: PanelContainer
var _body_open: StyleBoxTexture
var _body_done: StyleBoxTexture
var _well_host: Control
var _well: Control
var _title: Label
var _chip: PanelContainer
var _rail: ProgressBar
var _progress: Label
var _reward: Label
var _row: Dictionary = {}


func _init() -> void:
	name = "MissionCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, MIN_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_open = UiKit.style("card_bevel_soft", UiTokens.CREAM_DEEP, BODY_MARGIN)
	_body_done = UiKit.style("card_bevel_soft", BODY_DONE, BODY_MARGIN)
	add_theme_stylebox_override("panel", _body_open)
	_ring = UiKit.flat_plate("frame_round20", Color.WHITE)
	_ring.name = "Ring"
	_ring.self_modulate = Color(UiTokens.LAVENDER_SURFACE, 0.95)
	_ring.show_behind_parent = true
	UiKit.inset(_ring, -RING_WIDTH, -RING_WIDTH, -RING_WIDTH, -RING_WIDTH)
	add_child(_ring)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	add_child(row)
	_well_host = Control.new()
	_well_host.name = "WellHost"
	_well_host.custom_minimum_size = Vector2(WELL_SIZE + 8.0, WELL_SIZE + 10.0)
	_well_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_well_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_well_host)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var head := HBoxContainer.new()
	head.name = "Head"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	column.add_child(head)
	_title = UiKit.label("", &"LabelSection")
	_title.name = "Title"
	_title.add_theme_font_size_override("font_size", 20)
	# Uzun metin kartı taşırmaz (tek satır, üç nokta); katalog metinleri sığar.
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_chip = PanelContainer.new()
	_chip.name = "DoneChip"
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
	var chip_label := UiKit.label(DONE_TEXT, &"LabelBadge")
	chip_label.name = "DoneLabel"
	chip_label.add_theme_font_size_override("font_size", 14)
	chip_row.add_child(chip_label)
	_chip.visible = false
	head.add_child(_chip)
	var bar_row := HBoxContainer.new()
	bar_row.name = "ProgressRow"
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_theme_constant_override("separation", 10)
	column.add_child(bar_row)
	_rail = UiKit.progress_bar(0.0, &"ProgressBarMint", 14.0)
	_rail.name = "Rail"
	_rail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(_rail)
	_progress = UiKit.label("", &"LabelStat", HORIZONTAL_ALIGNMENT_RIGHT)
	_progress.name = "Progress"
	_progress.add_theme_font_size_override("font_size", 16)
	_progress.custom_minimum_size = Vector2(PROGRESS_WIDTH, 0)
	bar_row.add_child(_progress)
	# Ödül rozeti: owner Hamur sanatı + "+10" (altın fiyat dili) — kartın sağında, dikeyde ortalı.
	var reward := HBoxContainer.new()
	reward.name = "Reward"
	reward.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward.add_theme_constant_override("separation", 2)
	reward.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(reward)
	var coin := UiKit.art(DOUGH_ART, 34.0)
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reward.add_child(coin)
	_reward = UiKit.label("", &"LabelPrice")
	_reward.name = "RewardLabel"
	_reward.add_theme_font_size_override("font_size", 22)
	reward.add_child(_reward)


## `row`: Missions.rows() satırı.
func setup(row: Dictionary) -> void:
	_row = row
	if row.is_empty():
		visible = false
		return
	visible = true
	name = "Mission_%s" % String(row["id"])
	var done: bool = bool(row["completed"])
	var goal: int = maxi(int(row["target"]), 1)
	var value: int = clampi(int(row["progress"]), 0, goal)
	_set_well(row.get("metric", &""))
	_title.text = String(row["title"])
	_chip.visible = done
	add_theme_stylebox_override("panel", _body_done if done else _body_open)
	_ring.self_modulate = UiTokens.MINT if done else Color(UiTokens.LAVENDER_SURFACE, 0.95)
	_rail.value = float(value) / float(goal)
	_progress.text = PROGRESS_FORMAT % [value, goal]
	_progress.add_theme_color_override("font_color", UiTokens.MINT_DEEP if done else UiTokens.TEXT_PRIMARY)
	_reward.text = REWARD_FORMAT % int(row["reward"])


## Metrik kuyusu (kart yeniden kurulmaz; metrik değişirse kuyu yenilenir).
func _set_well(metric: StringName) -> void:
	if _well != null and _well.get_meta(&"metric", &"") == metric:
		return
	if _well != null:
		_well.queue_free()
	var art: Texture2D = MERGE_ART
	var accent: Color = UiTokens.PINK
	match metric:
		Missions.METRIC_ROUNDS:
			art = UiKit.icon_texture("play")
			accent = UiTokens.CYAN
		Missions.METRIC_CLEARS:
			art = CLEAR_ART
			accent = UiTokens.GOLD
	_well = UiKit.candy_well(art, accent, WELL_SIZE, WELL_ART)
	_well.name = "Well"
	_well.set_meta(&"metric", metric)
	_well.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_well.offset_left = -WELL_SIZE * 0.5
	_well.offset_right = WELL_SIZE * 0.5
	_well.offset_top = -(WELL_SIZE + 6.0) * 0.5
	_well.offset_bottom = (WELL_SIZE + 6.0) * 0.5
	_well_host.add_child(_well)


# --- Testler / çekim aracı ----------------------------------------------------

func row() -> Dictionary:
	return _row


func mission_id() -> StringName:
	return _row.get("id", &"")


func title_text() -> String:
	return _title.text


func progress_text() -> String:
	return _progress.text


func reward_text() -> String:
	return _reward.text


func is_done_shown() -> bool:
	return _chip.visible


func rail() -> ProgressBar:
	return _rail


func title_label() -> Label:
	return _title


func done_chip() -> PanelContainer:
	return _chip
