class_name DailyChallengeOverlay
extends CanvasLayer
## MEYDAN OKUMA penceresi (TASK/047 — GAME_DESIGN §5.11, UI_VISUAL_SYSTEM §26) — Ana Sayfa'nın
## MEYDAN OKUMA girişi açar. GÖREVLER penceresiyle AYNI aile: Main'e ait ikincil pencere (katman 12),
## `UiKit.modal_shell` + kurdele + oturmuş X + karartma; yeni ekran / alt gezinme yok, reklam yüzeyi
## DEĞİL (Ana Sayfa'nın banner'ı aynen, pencere yuvanın üstüne oturur).
##
##   ÜST (sabit)   bugünün hedef portresi (candy kuyu) + ana satır "Büyük Dumpling yap · 18 hamlede"
##   GÖVDE         "+20 HAMUR · İlk tamamlayışta" · ipucu · "Görev, XP ve sandık ilerlemesine sayılmaz."
##   ALTLIK        BAŞLA  |  tamamlandı: "✓ TAMAMLANDI" · "Yarın yenilenir" · KAPAT
##
## Açmak / kapatmak / BAŞLA kayda YAZMAZ: BAŞLA yalnız gösterilen günle `start_requested` yayar —
## Main günü YENİDEN okur, gün değiştiyse pencereyi bugüne tazeler (eski günün meydan okuması
## başlamaz). X / karartma / Android geri (Main) kapatır; açılış ve kapanış Main'in 300 ms parmak
## yatışmasını başlatır (Main bağlar).

signal opened
signal closed
signal start_requested(day_key: String)

const TITLE: String = DailyChallenge.TITLE
const WIDTH: float = 600.0
const REWARD_FORMAT: String = "+%d HAMUR · İlk tamamlayışta"
const HINT_TEXT: String = "Her gün yeni meydan okuma. Parça sırası gün boyu aynı; istediğin kadar dene."
const ISOLATION_TEXT: String = "Görev, XP ve sandık ilerlemesine sayılmaz."
const START_TEXT: String = "BAŞLA"
const DONE_TEXT: String = "TAMAMLANDI"
const TOMORROW_TEXT: String = "Yarın yenilenir"
const CLOSE_TEXT: String = "KAPAT"
const WELL_SIZE: float = 132.0
const WELL_ART: float = 104.0
## Hedef portresi kuyusu: T5 lavanta, T6 altın (tier rengi değil — kuyu Home kartlarıyla aynı aile).
const DUMPLING_VISUAL: GDScript = preload("res://scripts/game/dumpling_visual.gd")
const DOUGH_ART: Texture2D = preload("res://assets/visual/ui/icon_dough.png")

var _frame: Control
var _well_host: Control
var _well: Control
var _goal: Label
var _reward_row: HBoxContainer
var _reward: Label
var _hint: Label
var _isolation: Label
var _done_row: HBoxContainer
var _done_chip: PanelContainer
var _tomorrow: Label
var _start: Button
var _close_cta: Button
var _view: Dictionary = {}
var _safe_top_override: float = -1.0

@onready var _dim: ColorRect = $Center/Dim
@onready var _anchor: CenterContainer = $Center/Anchor


func _ready() -> void:
	visible = false
	_frame = UiKit.modal_shell(TITLE, WIDTH, &"ribbon", false, true)
	_frame.name = "DailyChallengeShell"
	_anchor.add_child(_frame)
	_build_hero(_frame.get_meta(&"hero"))
	_build_body(_frame.get_meta(&"body"))
	_build_footer(_frame.get_meta(&"footer"))
	GestureGuard.on_pressed(_frame.get_meta(&"close_button") as Button, close_sheet)
	UiKit.attach_dim_close(_dim, close_sheet)
	$Center.resized.connect(func() -> void:
		if visible:
			UiKit.seat_modal_below_safe_top(_anchor, _frame, _safe_top_override))
	UiKit.modal_relayout(_frame)


func _build_hero(hero: VBoxContainer) -> void:
	hero.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_well_host = Control.new()
	_well_host.name = "PortraitHost"
	_well_host.custom_minimum_size = Vector2(0, WELL_SIZE + 18.0)
	_well_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(_well_host)
	_goal = UiKit.label("", &"LabelTitle", HORIZONTAL_ALIGNMENT_CENTER)
	_goal.name = "Goal"
	_goal.add_theme_font_size_override("font_size", 26)
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero.add_child(_goal)


func _build_body(body: VBoxContainer) -> void:
	body.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	_reward_row = HBoxContainer.new()
	_reward_row.name = "RewardRow"
	_reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_reward_row.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_reward_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_reward_row)
	var dough := UiKit.art(DOUGH_ART, 34)
	dough.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	dough.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_reward_row.add_child(dough)
	_reward = UiKit.label(REWARD_FORMAT % DailyChallenge.REWARD_DOUGH, &"LabelSection")
	_reward.name = "Reward"
	_reward.add_theme_font_size_override("font_size", 20)
	_reward.add_theme_color_override("font_color", UiTokens.GOLD_DEEP)
	_reward.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_reward_row.add_child(_reward)
	# Tamamlandı: nane "✓ TAMAMLANDI" çipi (GÖREVLER kartının çipi; tik ikon, glif değil).
	_done_row = HBoxContainer.new()
	_done_row.name = "DoneRow"
	_done_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_done_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_done_row.visible = false
	body.add_child(_done_row)
	_done_chip = PanelContainer.new()
	_done_chip.name = "DoneChip"
	_done_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_done_chip.add_theme_stylebox_override("panel", UiKit.style("frame_round20", UiTokens.MINT, Vector4(16, 4, 18, 6)))
	_done_row.add_child(_done_chip)
	var chip_row := HBoxContainer.new()
	chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_row.add_theme_constant_override("separation", 6)
	_done_chip.add_child(chip_row)
	var check := UiKit.icon("check", 22, UiTokens.TEXT_ON_ACCENT)
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip_row.add_child(check)
	var done_label := UiKit.label(DONE_TEXT, &"LabelBadge")
	done_label.name = "DoneLabel"
	done_label.add_theme_font_size_override("font_size", 19)
	chip_row.add_child(done_label)
	_tomorrow = UiKit.label(TOMORROW_TEXT, &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	_tomorrow.name = "Tomorrow"
	_tomorrow.add_theme_font_size_override("font_size", 18)
	_tomorrow.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_tomorrow.visible = false
	body.add_child(_tomorrow)
	_hint = UiKit.label(HINT_TEXT, &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	_hint.name = "Hint"
	_hint.add_theme_font_size_override("font_size", 17)
	_hint.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_hint)
	# Yalıtım notu (owner kilidi — kaldırılmaz): her iki durumda da görünür; 320 dp'de de okunur
	# gövde yazısı (küçük başlık stili orada fazla soluk kalıyordu).
	_isolation = UiKit.label(ISOLATION_TEXT, &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	_isolation.name = "Isolation"
	_isolation.add_theme_font_size_override("font_size", 16)
	_isolation.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_isolation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_isolation)


func _build_footer(footer: VBoxContainer) -> void:
	_start = UiKit.cta(START_TEXT, "", &"ButtonCTA", "play")
	_start.name = "Start"
	GestureGuard.on_pressed(_start, _on_start_pressed)
	footer.add_child(_start)
	_close_cta = UiKit.cta(CLOSE_TEXT, "", &"ButtonCTA", "close")
	_close_cta.name = "Close"
	GestureGuard.on_pressed(_close_cta, close_sheet)
	_close_cta.visible = false
	footer.add_child(_close_cta)


## `view`: `DailyChallenge.current_view()` (Main okur — pencere kayda / saate bakmaz).
func open_sheet(view: Dictionary) -> void:
	var was_open: bool = visible
	show_view(view)
	visible = true
	UiKit.seat_modal_below_safe_top(_anchor, _frame, _safe_top_override)
	(_frame.get_meta(&"scroll") as ScrollContainer).scroll_vertical = 0
	if not was_open:
		UiMotion.modal_open(_frame, _dim)
		AudioManager.play(&"ui_modal_open")
		opened.emit()


## İçeriği verilen güne göre kurar (açıkken de — gün değişince Main tazeler).
func show_view(view: Dictionary) -> void:
	_view = view.duplicate()
	var completed: bool = bool(view.get("completed", false))
	var target: int = clampi(int(view.get("target_tier", 1)), 1, TierConfig.MAX_TIER)
	if _well != null:
		_well.queue_free()
	_well = UiKit.candy_well(DUMPLING_VISUAL.TEXTURES[target - 1],
		UiTokens.GOLD if target >= 6 else UiTokens.LAVENDER_LIGHT, WELL_SIZE, WELL_ART)
	_well.name = "Portrait"
	_well.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_well.offset_left = -WELL_SIZE * 0.5
	_well.offset_right = WELL_SIZE * 0.5
	_well.offset_top = -(WELL_SIZE + 6.0) * 0.5
	_well.offset_bottom = (WELL_SIZE + 6.0) * 0.5
	_well_host.add_child(_well)
	_goal.text = DailyChallenge.goal_text(view)
	_reward_row.visible = not completed
	_hint.visible = not completed
	_done_row.visible = completed
	_tomorrow.visible = completed
	_start.visible = not completed
	_close_cta.visible = completed
	UiKit.modal_relayout(_frame)


func close_sheet(with_sound: bool = true) -> void:
	if not visible:
		return
	visible = false
	if with_sound:
		AudioManager.play(&"ui_modal_close")
	closed.emit()


func _on_start_pressed() -> void:
	if not visible or bool(_view.get("completed", false)):
		return
	start_requested.emit(String(_view.get("day_key", "")))


## Android geri (Main): açıksa kapanır → true.
func handle_back() -> bool:
	if not visible:
		return false
	close_sheet()
	return true


# --- Testler / çekim aracı ----------------------------------------------------

func layout_with_safe_top(safe_top: float) -> void:
	_safe_top_override = safe_top
	if visible:
		UiKit.seat_modal_below_safe_top(_anchor, _frame, _safe_top_override)


func frame() -> Control:
	return _frame


func dim() -> ColorRect:
	return _dim


func view() -> Dictionary:
	return _view.duplicate()


func shown_day() -> String:
	return String(_view.get("day_key", ""))


func goal_text() -> String:
	return _goal.text


func reward_text() -> String:
	return _reward.text if _reward_row.visible else ""


func hint_text() -> String:
	return _hint.text if _hint.visible else ""


func isolation_text() -> String:
	return _isolation.text if _isolation.visible else ""


func is_done_shown() -> bool:
	return _done_row.visible


func tomorrow_text() -> String:
	return _tomorrow.text if _tomorrow.visible else ""


func start_button() -> Button:
	return _start


func close_cta() -> Button:
	return _close_cta


func close_button() -> Button:
	return _frame.get_meta(&"close_button")


func portrait() -> Control:
	return _well
