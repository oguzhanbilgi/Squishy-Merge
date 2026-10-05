class_name TitleSelector
extends Control
## UNVANLAR penceresi (TASK/045) — Profil'e ait modal (yeni sekme / reklam yüzeyi
## YOK): `UiKit.modal_shell` ("UNVANLAR" kurdelesi, oturmuş X), sabit üstte kısa not,
## kaydırılan gövdede 9 `TitleRow` (katalog sırası).
##
##   - Açık unvana dokunmak TEK kayıt yazması: `SaveManager.select_title` (bu pencerenin
##     tek kayıt çağrısı); satırlar ve Profil HEMEN güncellenir, pencere açık kalır.
##   - Zaten seçili unvan: yazma yok. Kilitli unvan: satır pasif (dokunulamaz).
##   - Seçimden sonra kısa eylem kilidi: hızlı çift dokunuş ikinci bir yazma üretmez.
##   - X / karartma / Android geri: DEĞİŞİKLİK YAPMADAN kapanır.

signal opened
signal closed
## Seçim kayda yazıldı (Profil kimliği tazelenir).
signal title_selected(id: StringName)

const TITLE: String = "UNVANLAR"
const WIDTH: float = 600.0
const NOTE: String = "Unvanın profilinde adının altında görünür. Yeni unvanlar başarımlarla açılır."
## Koleksiyon detayındaki eylem kilidiyle aynı (hızlı çift dokunuş).
const ACTION_LOCK_MSEC: int = 350

var _dim: ColorRect
var _frame: Control
var _anchor: CenterContainer
var _rows: Array[TitleRow] = []
var _action_lock_until: int = 0
var _safe_top_override: float = -1.0


func _init() -> void:
	name = "TitleSelector"
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
	_frame.name = "TitleShell"
	_anchor.add_child(_frame)
	var hero: VBoxContainer = _frame.get_meta(&"hero")
	var note := UiKit.label(NOTE, &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
	note.name = "Note"
	note.add_theme_font_size_override("font_size", 16)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero.add_child(note)
	var body: VBoxContainer = _frame.get_meta(&"body")
	body.add_theme_constant_override("separation", 12)
	for id in AchievementCatalog.title_ids():
		var row := TitleRow.new()
		GestureGuard.on_pressed(row, _on_row_pressed.bind(id))
		body.add_child(row)
		_rows.append(row)
	# Son satırın gölgesi / dudağı kaydırma kırpmasına takılmasın.
	var tail := Control.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.custom_minimum_size = Vector2(0, 6)
	body.add_child(tail)
	GestureGuard.on_pressed(_frame.get_meta(&"close_button") as Button, close)
	UiKit.attach_dim_close(_dim, close)
	resized.connect(func() -> void:
		if visible:
			UiKit.seat_modal_below_safe_top(_anchor, _frame, _safe_top_override))


func open() -> void:
	var was_open: bool = visible
	refresh()
	visible = true
	UiKit.seat_modal_below_safe_top(_anchor, _frame, _safe_top_override)
	(_frame.get_meta(&"scroll") as ScrollContainer).scroll_vertical = 0
	if not was_open:
		_action_lock_until = 0
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
	var rows: Array[Dictionary] = PlayerProfile.title_rows()
	for i in _rows.size():
		if i < rows.size():
			_rows[i].setup(rows[i])


## Android geri: açıksa kapanır (seçim yapılmaz) → true.
func handle_back() -> bool:
	if not visible:
		return false
	close()
	return true


func _on_row_pressed(id: StringName) -> void:
	if Time.get_ticks_msec() < _action_lock_until or not visible:
		return
	match SaveManager.select_title(id):
		SaveManager.TitleResult.SELECTED:
			_action_lock_until = Time.get_ticks_msec() + ACTION_LOCK_MSEC
			AudioManager.play(&"ui_equip")
			Haptics.light()
			refresh()
			var row: TitleRow = _row_for(id)
			if row != null:
				# Ertelenir: `pressed` bırakışta gelir ve aynı olayın `button_up`'ı basış
				# animasyonunu geri alırken pop'u öldürüyordu (lens 5).
				(func() -> void: UiMotion.pop(row, 1.04)).call_deferred()
			title_selected.emit(id)
		SaveManager.TitleResult.LOCKED, SaveManager.TitleResult.UNKNOWN:
			# Kilitli satır pasif (dokunma almaz) — bu dal yalnız kod yolundan gelen savunma.
			AudioManager.play(&"ui_invalid")


func _row_for(id: StringName) -> TitleRow:
	for row in _rows:
		if row.title_id() == id:
			return row
	return null


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


func rows() -> Array[TitleRow]:
	return _rows


func row(id: StringName) -> TitleRow:
	return _row_for(id)


func scroll() -> ScrollContainer:
	return _frame.get_meta(&"scroll")
