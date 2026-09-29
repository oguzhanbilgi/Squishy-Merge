class_name MissionsOverlay
extends CanvasLayer
## GÖREVLER penceresi (TASK/046 — GAME_DESIGN §5.10) — Ana Sayfa'nın GÖREVLER girişi açar;
## Main'e ait ikincil pencere (GÜNLÜK ÖDÜLLER / Bonus Sandık ile aynı katman ve iskelet: yeni
## alt sekme / ekran YOK, reklam yüzeyi DEĞİL — Ana Sayfa'nın mevcut banner'ı aynen, pencere
## yuvanın üstüne oturur).
##
##   ÜST (sabit)   hedef picto + "2 / 6 GÖREV" + ray (6/6'da altın + yıldız) + ödül notu
##                 ("Ödüller görev tamamlanınca otomatik eklenir.") — talep butonu YOK.
##   GÖVDE         GÜNLÜK başlığı + "Yarın yenilenir" · 3 kart; HAFTALIK başlığı +
##                 "Pazartesi yenilenir" · 3 kart (sabit ipucu, canlı sayaç YOK).
##
## Açmak / kapatmak / kaydırmak kayda YAZMAZ. X / karartma / Android geri (Main) → kapanır.
## Açılış ve kapanış Main'in 300 ms parmak yatışmasını başlatır (Main bağlar).

signal opened
signal closed

const TITLE: String = "GÖREVLER"
const WIDTH: float = 600.0
const COUNT_FORMAT: String = "%d / %d"
const COUNT_UNIT: String = "GÖREV"
const NOTE_TEXT: String = "Ödüller görev tamamlanınca otomatik eklenir."
const COMPLETE_TEXT: String = "Hepsi tamam!"
const DAILY_TITLE: String = "GÜNLÜK"
const WEEKLY_TITLE: String = "HAFTALIK"
const DAILY_HINT: String = "Yarın yenilenir"
const WEEKLY_HINT: String = "Pazartesi yenilenir"
const STAR_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")

var _frame: Control
var _count: Label
var _star: TextureRect
var _bar: ProgressBar
var _note: Label
var _cards: Array[MissionCard] = []
var _headers: Dictionary = {}
var _safe_top_override: float = -1.0

@onready var _dim: ColorRect = $Center/Dim
@onready var _anchor: CenterContainer = $Center/Anchor


func _ready() -> void:
	visible = false
	_frame = UiKit.modal_shell(TITLE, WIDTH, &"ribbon", false, true)
	_frame.name = "MissionsShell"
	_anchor.add_child(_frame)
	_build_hero(_frame.get_meta(&"hero"))
	var body: VBoxContainer = _frame.get_meta(&"body")
	body.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	for period: StringName in [Missions.PERIOD_DAILY, Missions.PERIOD_WEEKLY]:
		var daily: bool = period == Missions.PERIOD_DAILY
		var header := _section_header(DAILY_TITLE if daily else WEEKLY_TITLE, DAILY_HINT if daily else WEEKLY_HINT)
		body.add_child(header)
		_headers[period] = header
		for id in Missions.ids_for(period):
			var card := MissionCard.new()
			body.add_child(card)
			_cards.append(card)
	var tail := Control.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.custom_minimum_size = Vector2(0, 4)
	body.add_child(tail)
	(_frame.get_meta(&"close_button") as Button).pressed.connect(close_missions)
	UiKit.attach_dim_close(_dim, close_missions)
	# Ekran boyutu değişince (döndürme / pencere) pencere yeniden oturur. Tam ekran kök
	# dinlenir — `_anchor`'ın kendi payı oturtmayla değişir, onu dinlemek döngü kurardı.
	$Center.resized.connect(func() -> void:
		if visible:
			UiKit.seat_modal_below_safe_top(_anchor, _frame, _safe_top_override))
	UiKit.modal_relayout(_frame)


func _build_hero(hero: VBoxContainer) -> void:
	hero.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.name = "CountRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	hero.add_child(row)
	var goal := UiKit.icon("goal", 32, UiTokens.PINK_DEEP)
	goal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(goal)
	_count = UiKit.label(COUNT_FORMAT % [0, Missions.CATALOG.size()], &"LabelTitle")
	_count.name = "Count"
	_count.add_theme_font_size_override("font_size", 32)
	row.add_child(_count)
	var unit := UiKit.label(COUNT_UNIT, &"LabelBadge")
	unit.add_theme_font_size_override("font_size", 16)
	unit.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	unit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(unit)
	_star = UiKit.art(STAR_ART, 28)
	_star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_star.visible = false
	row.add_child(_star)
	_bar = UiKit.progress_bar(0.0, &"ProgressBarMint", 14.0)
	_bar.name = "CountRail"
	hero.add_child(_bar)
	_note = UiKit.label(NOTE_TEXT, &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
	_note.name = "Note"
	_note.add_theme_font_size_override("font_size", 15)
	_note.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero.add_child(_note)


## Bölüm başlığı: erik "GÜNLÜK" + ince lavanta çizgi + takvim picto + sabit yenilenme ipucu.
func _section_header(title: String, hint: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "Section_%s" % title
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	var label := UiKit.label(title, &"LabelBadge")
	label.name = "Title"
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	row.add_child(label)
	var line := UiKit.settings_divider()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	var calendar := UiKit.icon("calendar", 18, UiTokens.TEXT_SECONDARY)
	calendar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(calendar)
	# İkincil erik (kremde okunur kontrast; üçüncül ton 14 px'te soluk kalıyordu).
	var hint_label := UiKit.label(hint, &"LabelCaption")
	hint_label.name = "Hint"
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	row.add_child(hint_label)
	row.set_meta(&"hint_label", hint_label)
	row.set_meta(&"title_label", label)
	return row


## Kayıt yalnız OKUNUR (Missions.current — kabul edilen günün dönemi).
func open_missions() -> void:
	var was_open: bool = visible
	refresh()
	visible = true
	UiKit.seat_modal_below_safe_top(_anchor, _frame, _safe_top_override)
	(_frame.get_meta(&"scroll") as ScrollContainer).scroll_vertical = 0
	if not was_open:
		UiMotion.modal_open(_frame, _dim)
		AudioManager.play(&"ui_modal_open")
		opened.emit()


func close_missions(with_sound: bool = true) -> void:
	if not visible:
		return
	visible = false
	if with_sound:
		AudioManager.play(&"ui_modal_close")
	closed.emit()


func refresh() -> void:
	var state: Dictionary = Missions.current()
	var rows: Array[Dictionary] = Missions.rows(state)
	for i in _cards.size():
		_cards[i].setup(rows[i] if i < rows.size() else {})
	var total: int = rows.size()
	var done: int = Missions.completed_count(state)
	var complete: bool = total > 0 and done >= total
	_count.text = COUNT_FORMAT % [done, total]
	_count.add_theme_color_override("font_color", UiTokens.GOLD_DEEP if complete else UiTokens.TEXT_PRIMARY)
	_bar.value = float(done) / float(maxi(total, 1))
	_bar.theme_type_variation = &"ProgressBarGold" if complete else &"ProgressBarMint"
	_star.visible = complete
	_note.text = COMPLETE_TEXT if complete else NOTE_TEXT
	_note.add_theme_color_override("font_color", UiTokens.GOLD_DEEP if complete else UiTokens.TEXT_SECONDARY)


## Android geri (Main): açıksa kapanır → true.
func handle_back() -> bool:
	if not visible:
		return false
	close_missions()
	return true


# --- Testler / çekim aracı ----------------------------------------------------

## Cihaz güvenli alanı yerine sabit üst pay (tuval px).
func layout_with_safe_top(safe_top: float) -> void:
	_safe_top_override = safe_top
	if visible:
		UiKit.seat_modal_below_safe_top(_anchor, _frame, _safe_top_override)


func frame() -> Control:
	return _frame


func dim() -> ColorRect:
	return _dim


func cards() -> Array[MissionCard]:
	return _cards


func card(id: StringName) -> MissionCard:
	for c in _cards:
		if c.mission_id() == id:
			return c
	return null


func count_text() -> String:
	return _count.text


func note_text() -> String:
	return _note.text


func section_header(period: StringName) -> Control:
	return _headers.get(period, null)


func close_button() -> Button:
	return _frame.get_meta(&"close_button")


func scroll() -> ScrollContainer:
	return _frame.get_meta(&"scroll")
