class_name AchievementsOverlay
extends Control
## TÜM BAŞARIMLAR penceresi (TASK/045) — Profil'e ait modal (yeni alt sekme YOK,
## reklam yüzeyi DEĞİL, banner YOK): `UiKit.modal_shell` ("BAŞARIMLAR" kurdelesi,
## oturmuş X). Sabit üst bölgede "7 / 12" + ray (12/12'de altın + yıldız); kaydırılan
## gövdede kategori başlıklarıyla 12 `AchievementCard` (V1'de gizli başarım yok —
## kilitliler de görünür, ilerlemesiyle).
##
## Açmak / kapatmak / kaydırmak kayda YAZMAZ (Profil açılışındaki uzlaştırma zaten
## bellekte yapıldı). X / karartma / Android geri → kapanır, Profil'e dönülür.

signal opened
signal closed

const TITLE: String = "BAŞARIMLAR"
const WIDTH: float = 600.0
const COUNT_UNIT: String = "BAŞARIM"
const COMPLETE_TEXT: String = "Hepsi tamam!"
const STAR_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
const GROUP_TITLES: Dictionary = {
	AchievementCatalog.METRIC_MERGES: "BİRLEŞTİRME",
	AchievementCatalog.METRIC_STARS: "YILDIZ",
	AchievementCatalog.METRIC_LEVELS: "BÖLÜM",
	AchievementCatalog.METRIC_COLLECTION: "KOLEKSİYON",
}

var _dim: ColorRect
var _frame: Control
var _count: Label
var _complete: Label
var _star: TextureRect
var _bar: ProgressBar
var _cards: Array[AchievementCard] = []
var _group_headers: Array[Control] = []
var _anchor: CenterContainer
var _safe_top_override: float = -1.0


func _init() -> void:
	name = "AchievementsOverlay"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.05, 0.0, 0.06, 0.62)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_anchor = CenterContainer.new()
	_anchor.name = "Anchor"
	_anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_anchor)
	_frame = UiKit.modal_shell(TITLE, WIDTH, &"ribbon", false, true)
	_frame.name = "AchievementsShell"
	_anchor.add_child(_frame)
	_build_hero(_frame.get_meta(&"hero"))
	var body: VBoxContainer = _frame.get_meta(&"body")
	body.add_theme_constant_override("separation", 12)
	var last_metric: StringName = &""
	for entry in AchievementCatalog.ACHIEVEMENTS:
		if entry["metric"] != last_metric:
			last_metric = entry["metric"]
			var header := _group_header(String(GROUP_TITLES.get(last_metric, "")))
			body.add_child(header)
			_group_headers.append(header)
		var card := AchievementCard.new(false)
		body.add_child(card)
		_cards.append(card)
	var tail := Control.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.custom_minimum_size = Vector2(0, 6)
	body.add_child(tail)
	GestureGuard.on_pressed(_frame.get_meta(&"close_button") as Button, close)
	UiKit.attach_dim_close(_dim, close)
	resized.connect(func() -> void:
		if visible:
			UiKit.seat_modal_below_safe_top(_anchor, _frame, _safe_top_override))


func _build_hero(hero: VBoxContainer) -> void:
	hero.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.name = "CountRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	hero.add_child(row)
	var trophy := UiKit.icon("trophy", 34, UiTokens.GOLD_DEEP)
	trophy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(trophy)
	_count = UiKit.label("0 / 12", &"LabelTitle")
	_count.name = "Count"
	_count.add_theme_font_size_override("font_size", 34)
	row.add_child(_count)
	var unit := UiKit.label(COUNT_UNIT, &"LabelBadge")
	unit.add_theme_font_size_override("font_size", 16)
	unit.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	unit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(unit)
	_star = UiKit.art(STAR_ART, 30)
	_star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_star.visible = false
	row.add_child(_star)
	_bar = UiKit.progress_bar(0.0, &"ProgressBarMint", 16.0)
	_bar.name = "CountRail"
	hero.add_child(_bar)
	_complete = UiKit.label(COMPLETE_TEXT, &"LabelBadge", HORIZONTAL_ALIGNMENT_CENTER)
	_complete.name = "Complete"
	_complete.add_theme_font_size_override("font_size", 16)
	_complete.add_theme_color_override("font_color", UiTokens.GOLD_DEEP)
	_complete.visible = false
	hero.add_child(_complete)


## Kategori başlığı: küçük erik yazı + ince lavanta çizgi (krem pencere içinde sakin).
func _group_header(title: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "Group_%s" % title
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	var label := UiKit.label(title, &"LabelBadge")
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	row.add_child(label)
	var line := UiKit.settings_divider()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	return row


func open() -> void:
	var was_open: bool = visible
	refresh()
	visible = true
	UiKit.seat_modal_below_safe_top(_anchor, _frame, _safe_top_override)
	(_frame.get_meta(&"scroll") as ScrollContainer).scroll_vertical = 0
	if not was_open:
		UiMotion.modal_open(_frame, _dim)
		AudioManager.play(&"ui_modal_open")
		opened.emit()


func close(with_sound: bool = true) -> void:
	if not visible:
		return
	visible = false
	if with_sound:
		AudioManager.play(&"ui_modal_close")
	closed.emit()


func refresh() -> void:
	var rows: Array[Dictionary] = PlayerProfile.achievement_rows()
	var open_count: int = 0
	for i in _cards.size():
		if i < rows.size():
			_cards[i].setup(rows[i])
			if bool(rows[i]["unlocked"]):
				open_count += 1
	var total: int = _cards.size()
	var complete: bool = total > 0 and open_count >= total
	_count.text = "%d / %d" % [open_count, total]
	_count.add_theme_color_override("font_color", UiTokens.GOLD_DEEP if complete else UiTokens.TEXT_PRIMARY)
	_bar.value = float(open_count) / float(maxi(total, 1))
	_bar.theme_type_variation = &"ProgressBarGold" if complete else &"ProgressBarMint"
	_star.visible = complete
	_complete.visible = complete


## Android geri: açıksa kapanır → true.
func handle_back() -> bool:
	if not visible:
		return false
	close()
	return true


# --- Testler / çekim aracı ----------------------------------------------------

## Cihaz güvenli alanı yerine sabit üst pay (tuval px) — Profil'in `_layout_with_safe_top`'u iletir.
func layout_with_safe_top(safe_top: float) -> void:
	_safe_top_override = safe_top
	if visible:
		UiKit.seat_modal_below_safe_top(_anchor, _frame, _safe_top_override)


func frame() -> Control:
	return _frame


func dim() -> ColorRect:
	return _dim


func cards() -> Array[AchievementCard]:
	return _cards


func card(id: StringName) -> AchievementCard:
	for c in _cards:
		if c.achievement_id() == id:
			return c
	return null


func count_text() -> String:
	return _count.text


func group_headers() -> Array[Control]:
	return _group_headers


func scroll() -> ScrollContainer:
	return _frame.get_meta(&"scroll")
