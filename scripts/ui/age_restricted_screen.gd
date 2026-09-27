extends CanvasLayer
## 13 yaş altı kısıt ekranı (TASK/043 — docs/monetization/AGE_BAND_ROUTING.md §5).
## Squishy Merge 13 yaş altı için tasarlanmadı ve onlara pazarlanmaz (owner, 2026-09-27):
## nötr yaş ekranı UNDER_13 verince oyun bu ekranda durur. Reklam SDK'sı hiç başlamaz,
## UMP sorulmaz (MonetizationManager kapısı kapalı).
##
## Bilerek:
##   - Eşik yaş SÖYLENMEZ, "tekrar dene" / "tarihi değiştir" düğmesi YOK (yaşı yeniden
##     girmeye teşvik etmez — nötr yaş ekranı ilkesi). Kaydedilen 13. yaş günü gelince
##     soğuk açılışta kendiliğinden kalkar (SaveManager.resolve_age_band_at_launch).
##   - İlerleme SİLİNMEZ (kayıt cihazda durur); ebeveyn izni / ebeveyn kapısı YOK ve
##     iddia edilmez.
##   - Oyun parası, sandık, yıldız, konfeti yok — bir ödül ekranı değil.
## Katman 30: her şeyin (tutorial, sonuç, pencereler, yaş ekranı) üstünde; tam ekran zemin
## dokunuşları durdurur. Android geri tuşu Main'de: uygulamadan çıkar.

signal exit_requested

const TITLE: String = "Üzgünüz"
const BODY: String = "Squishy Merge senin yaş grubun için tasarlanmadı, bu yüzden şu anda oynanamıyor."
const PROGRESS_NOTE: String = "İlerlemen bu cihazda saklı kalır."
const EXIT_TEXT: String = "ÇIKIŞ"

var _frame: Control
var _exit: Button

@onready var _anchor: CenterContainer = $Center/Anchor


func _ready() -> void:
	visible = false
	_frame = UiKit.modal_shell(TITLE, 560.0, &"heading", false, false)
	_frame.name = "AgeRestrictedShell"
	_anchor.add_child(_frame)
	var body: VBoxContainer = _frame.get_meta(&"body")
	body.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	var text := UiKit.label(BODY, &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	text.name = "Body"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(text)
	var note := UiKit.label(PROGRESS_NOTE, &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	note.name = "ProgressNote"
	note.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	var footer: VBoxContainer = _frame.get_meta(&"footer")
	_exit = UiKit.button(EXIT_TEXT, &"ButtonSecondary")
	_exit.name = "Exit"
	_exit.custom_minimum_size = Vector2(0, UiTokens.HEIGHT_LARGE)
	_exit.pressed.connect(func() -> void: exit_requested.emit())
	footer.add_child(_exit)
	UiKit.modal_relayout(_frame)


func open_screen() -> void:
	if visible:
		return
	visible = true
	UiKit.modal_relayout(_frame)
	UiMotion.modal_open(_frame)


func is_open() -> bool:
	return visible


# --- Testler / QA sürücüsü --------------------------------------------------------------

func frame() -> Control:
	return _frame


func exit_button() -> Button:
	return _exit


func visible_texts() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	_collect(_frame, out)
	return out


func _collect(node: Node, out: PackedStringArray) -> void:
	var control := node as Control
	if control != null and not control.is_visible_in_tree():
		return
	if node is Label and not (node as Label).text.is_empty():
		out.append((node as Label).text)
	elif node is Button and not (node as Button).text.is_empty():
		out.append((node as Button).text)
	for child in node.get_children():
		_collect(child, out)
