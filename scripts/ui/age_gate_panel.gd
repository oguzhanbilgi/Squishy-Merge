extends CanvasLayer
## Nötr yaş ekranı (TASK/043 — docs/monetization/AGE_BAND_ROUTING.md §3). Oyuncu doğum
## tarihini GÜN / AY / YIL olarak kendisi girer (oyun içi rakam tuş takımı; hazır seçili
## tarih, varsayılan yaş, yaş aralığı düğmesi YOK). Google Play'in nötr yaş ekranı
## örneği: ay / gün / yılın serbestçe girilmesi.
##
## NÖTRLÜK (bilerek): ekran hangi cevabın neyi değiştirdiğini SÖYLEMEZ — eşik yaş, "18+",
## reklam, ödül, kilit açma, oyun parası, sandık, yıldız, konfeti, yönlendiren ok yok;
## hatalı ve gelecekteki tarihler AYNI nötr mesajı alır; her tarih aynı onay adımından
## geçer (yalnız belli yaşlara gösterilen bir onay eşiği ele verirdi); yeniden girişin
## "kaydedildi" adımı da her cevapta AYNI metni gösterir (hangi cevabın bir şeyi
## değiştirdiğini ele vermez).
##
## GİZLİLİK: girilen rakamlar yalnız bu düğümün belleğinde yaşar; onay / vazgeç / kapanışta
## silinir. Burada log (print / push_*), analitik olayı, ağ çağrısı YOK. Dışarı yalnız
## türetilmiş sonuç çıkar: `resolved(band, transition)` (AgeGate.classify_birth_date).
##
## İki kip:
##   REQUIRED — ilk güvenli kabukta, yaş bilinmiyorsa (Main). Kapatma YOK (X yok,
##              karartma kapatmaz); Android geri tuşunu Main yönetir.
##   REENTRY  — Ayarlar → "Yaş bilgisi". X / Vazgeç / karartma kapatır (hiçbir şey
##              değişmez); onaydan sonra kısa "kaydedildi" adımı (Main `show_done`).
##
## Düzeltme: dolu bir alana dokunmak onu baştan yazdırır; DÜZELT girişi boşaltır.
## Taşan rakam yalnız dolu OLMAYAN bir sonraki alana gider (alanlar asla uzamaz).
## Katman 14: Ayarlar (13) ve günlük pencere (12) üstünde; UNDER_13 kısıt ekranı (30) altında.

signal resolved(band: int, transition: String)
## REENTRY: pencere değişiklik olmadan kapandı ya da "güncellendi" adımı onaylandı.
signal closed

enum Mode { REQUIRED, REENTRY }
enum Stage { ENTRY, CONFIRM, DONE }

const TITLE: String = "Doğum tarihin"
const PROMPT: String = "Lütfen doğum tarihini gir."
const NOTE: String = "Doğum tarihin bu cihazdan çıkmaz; yalnızca sana uygun ayarları seçmek için kullanılır."
const ERROR_TEXT: String = "Bu tarih geçerli değil. Lütfen kontrol et."
const CONFIRM_LEAD: String = "Girdiğin tarih"
const CONFIRM_QUESTION: String = "Doğru mu?"
const DONE_TEXT: String = "Yaş bilgin kaydedildi."
## Her yeniden girişte AYNI (nötr): bir sonraki açılışta uygulanan değişikliği de kapsar.
const DONE_NOTE: String = "Bazı ayarlar uygulama yeniden açıldığında güncellenebilir."
const MONTHS: Array[String] = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz",
	"Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
const FIELD_CAPTIONS: Array[String] = ["Gün", "Ay", "Yıl"]
const FIELD_PLACEHOLDERS: Array[String] = ["GG", "AA", "YYYY"]
const FIELD_LENGTHS: Array[int] = [2, 2, 4]
const FIELD_WIDTHS: Array[float] = [132.0, 132.0, 196.0]
const MODAL_WIDTH: float = 600.0
const KEY_HEIGHT: float = 74.0
const KEY_FONT_SIZE: int = 34
const FIELD_FONT_SIZE: int = 34
## Hata satırı: gövde metninden küçük değil, krem zeminde >= 4.5:1 kontrast (koyu turuncu).
const ERROR_FONT_SIZE: int = 20
const ERROR_COLOR: Color = Color("9a4a12")

var _mode: Mode = Mode.REQUIRED
var _stage: Stage = Stage.ENTRY
## Girilen rakamlar (gün, ay, yıl) — yalnız bellekte; `_reset_entry` siler.
var _digits: Array[String] = ["", "", ""]
var _field: int = 0
## Oyuncu dolu bir alana dokundu: ilk rakam o alanı baştan yazar.
var _overwrite: bool = false

var _frame: Control
var _close_x: Button
var _entry_box: VBoxContainer
var _prompt: Label
var _field_buttons: Array[Button] = []
var _error: Label
var _keys: Dictionary = {}   # "0".."9", "del", "clear" -> Button
var _note: Label
var _confirm_box: VBoxContainer
var _confirm_date: Label
var _done_box: VBoxContainer
var _done_label: Label
var _next_launch_label: Label
var _continue: Button
var _confirm_row: HBoxContainer
var _fix: Button
var _confirm: Button
var _cancel: Button
var _done: Button
## Son `show_done` çağrısı NEXT_LAUNCH mıydı (yalnız teşhis / QA; ekranda fark yok).
var _done_next_launch: bool = false

@onready var _dim: ColorRect = $Center/Dim
@onready var _anchor: CenterContainer = $Center/Anchor


func _ready() -> void:
	visible = false
	# Tepelik YOK (taç + yıldız sanatı sonuç / ödül ekranlarının dili — nötr ekranda olmaz).
	_frame = UiKit.modal_shell(TITLE, MODAL_WIDTH, &"heading", false, true)
	_frame.name = "AgeGateShell"
	_anchor.add_child(_frame)
	_close_x = _frame.get_meta(&"close_button")
	_close_x.pressed.connect(_on_cancel)
	UiKit.attach_dim_close(_dim, _on_dim_released)
	var body: VBoxContainer = _frame.get_meta(&"body")
	body.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	_build_entry(body)
	_build_confirm(body)
	_build_done(body)
	_build_footer(_frame.get_meta(&"footer"))
	_apply_stage()
	UiKit.modal_relayout(_frame)


func _build_entry(body: VBoxContainer) -> void:
	_entry_box = VBoxContainer.new()
	_entry_box.name = "Entry"
	_entry_box.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	_entry_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_entry_box)
	_prompt = UiKit.label(PROMPT, &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_entry_box.add_child(_prompt)

	var fields := HBoxContainer.new()
	fields.name = "Fields"
	fields.alignment = BoxContainer.ALIGNMENT_CENTER
	fields.add_theme_constant_override("separation", UiTokens.SPACE_LG)
	fields.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_box.add_child(fields)
	for i in 3:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", UiTokens.SPACE_XS)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var caption := UiKit.label(FIELD_CAPTIONS[i], &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
		caption.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
		column.add_child(caption)
		var field := UiKit.button("", &"ButtonSecondary")
		field.name = "Field%d" % i
		field.custom_minimum_size = Vector2(FIELD_WIDTHS[i], 76.0)
		field.add_theme_font_size_override("font_size", FIELD_FONT_SIZE)
		field.pressed.connect(select_field.bind(i))
		column.add_child(field)
		fields.add_child(column)
		_field_buttons.append(field)

	_error = UiKit.label(ERROR_TEXT, &"LabelWarning", HORIZONTAL_ALIGNMENT_CENTER)
	_error.name = "Error"
	_error.add_theme_font_size_override("font_size", ERROR_FONT_SIZE)
	_error.add_theme_color_override("font_color", ERROR_COLOR)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.visible = false
	_entry_box.add_child(_error)

	var pad := GridContainer.new()
	pad.name = "Keypad"
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", UiTokens.SPACE_MD)
	pad.add_theme_constant_override("v_separation", UiTokens.SPACE_MD)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_box.add_child(pad)
	for label in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "clear", "0", "del"]:
		var key: Button
		match label:
			"clear":
				key = UiKit.button("Temizle", &"ButtonSecondary")
				key.pressed.connect(press_clear)
			"del":
				key = UiKit.button("Sil", &"ButtonSecondary", "arrow_prev")
				key.pressed.connect(press_backspace)
			_:
				key = UiKit.button(label, &"ButtonSecondary")
				key.add_theme_font_size_override("font_size", KEY_FONT_SIZE)
				key.pressed.connect(press_digit.bind(int(label)))
		key.name = "Key_%s" % label
		key.custom_minimum_size = Vector2(0, KEY_HEIGHT)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pad.add_child(key)
		_keys[label] = key

	_note = UiKit.label(NOTE, &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	_note.name = "Note"
	_note.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_entry_box.add_child(_note)


func _build_confirm(body: VBoxContainer) -> void:
	_confirm_box = VBoxContainer.new()
	_confirm_box.name = "Confirm"
	_confirm_box.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_confirm_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_confirm_box)
	var lead := UiKit.label(CONFIRM_LEAD, &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	lead.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_confirm_box.add_child(lead)
	_confirm_date = UiKit.label("", &"LabelDisplay", HORIZONTAL_ALIGNMENT_CENTER)
	_confirm_date.name = "Date"
	_confirm_box.add_child(_confirm_date)
	var question := UiKit.label(CONFIRM_QUESTION, &"LabelSection", HORIZONTAL_ALIGNMENT_CENTER)
	_confirm_box.add_child(question)


func _build_done(body: VBoxContainer) -> void:
	_done_box = VBoxContainer.new()
	_done_box.name = "Done"
	_done_box.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_done_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_done_box)
	_done_label = UiKit.label(DONE_TEXT, &"LabelSection", HORIZONTAL_ALIGNMENT_CENTER)
	_done_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_done_box.add_child(_done_label)
	_next_launch_label = UiKit.label(DONE_NOTE, &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	_next_launch_label.name = "DoneNote"
	_next_launch_label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_next_launch_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_done_box.add_child(_next_launch_label)


func _build_footer(footer: VBoxContainer) -> void:
	footer.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_continue = UiKit.cta("DEVAM", "", &"ButtonCTA")
	_continue.name = "Continue"
	_continue.pressed.connect(press_continue)
	footer.add_child(_continue)
	_confirm_row = HBoxContainer.new()
	_confirm_row.name = "ConfirmRow"
	_confirm_row.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	_confirm_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(_confirm_row)
	_fix = UiKit.button("DÜZELT", &"ButtonSecondary")
	_fix.name = "Fix"
	_fix.custom_minimum_size = Vector2(0, UiTokens.HEIGHT_HERO)
	_fix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fix.pressed.connect(press_fix)
	_confirm_row.add_child(_fix)
	_confirm = UiKit.cta("ONAYLA", "", &"ButtonCTA")
	_confirm.name = "ConfirmButton"
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.pressed.connect(press_confirm)
	_confirm_row.add_child(_confirm)
	_cancel = UiKit.button("Vazgeç", &"ButtonSecondary")
	_cancel.name = "Cancel"
	_cancel.pressed.connect(_on_cancel)
	footer.add_child(_cancel)
	_done = UiKit.cta("TAMAM", "", &"ButtonCTA")
	_done.name = "DoneButton"
	_done.pressed.connect(press_done)
	footer.add_child(_done)


# --- Açma / kapama -------------------------------------------------------------------

## İlk güvenli kabukta, yaş bilinmiyorken (Main). Kapatılamaz.
func open_required() -> void:
	_open(Mode.REQUIRED)


## Ayarlar → "Yaş bilgisi" (Main). Vazgeçilebilir; hiçbir kayıtlı değer gösterilmez (ham
## doğum tarihi saklanmaz; saklanan geçiş günü de burada gösterilmez) — alanlar HER ZAMAN
## boş açılır.
func open_reentry() -> void:
	_open(Mode.REENTRY)


func _open(mode: Mode) -> void:
	_mode = mode
	_reset_entry()
	_stage = Stage.ENTRY
	_apply_stage()
	visible = true
	UiKit.modal_relayout(_frame)
	(_frame.get_meta(&"scroll") as ScrollContainer).scroll_vertical = 0
	UiMotion.modal_open(_frame, _dim)
	AudioManager.play(&"ui_modal_open")


## Main: yeniden girişte sonuç kaydedildi — kısa onay adımı. Metin ve not HER cevapta
## aynı (nötr): `next_launch` (SDK bu süreçte eski bantla yapılandırılmıştı, yeni bant bir
## sonraki açılışta) ekrana ayrı bir işaret olarak YANSIMAZ; yalnız teşhis için tutulur.
func show_done(next_launch: bool) -> void:
	_stage = Stage.DONE
	_done_next_launch = next_launch
	_next_launch_label.visible = true
	_apply_stage()


func close_panel() -> void:
	_reset_entry()
	if not visible:
		return
	visible = false
	AudioManager.play(&"ui_modal_close")


func _on_cancel() -> void:
	if _mode != Mode.REENTRY or not visible:
		return
	close_panel()
	closed.emit()


func is_reentry() -> bool:
	return _mode == Mode.REENTRY


## Android geri (Main): yeniden girişte vazgeç / tamam = true (tüketildi). Zorunlu
## kipte false — pencere kapatılamaz; Main uygulamadan çıkar.
func handle_back() -> bool:
	if _mode != Mode.REENTRY:
		return false
	if _stage == Stage.DONE:
		press_done()
	else:
		_on_cancel()
	return true


func _on_dim_released() -> void:
	if _mode == Mode.REENTRY and _stage != Stage.DONE:
		_on_cancel()


# --- Giriş ---------------------------------------------------------------------------

func select_field(index: int) -> void:
	if _stage != Stage.ENTRY or index < 0 or index > 2:
		return
	_field = index
	# Dolu alana dokunmak onu düzeltmek içindir: ilk rakam alanı baştan yazar.
	_overwrite = _field_full(index)
	_refresh_entry()


func press_digit(digit: int) -> void:
	if _stage != Stage.ENTRY or digit < 0 or digit > 9:
		return
	var index: int = _field
	if _overwrite:
		_digits[index] = ""
		_overwrite = false
	# Dolu alandan taşan rakam yalnız dolu OLMAYAN bir sonraki alana; hepsi doluysa yok sayılır.
	while _field_full(index):
		if index >= 2:
			return
		index += 1
	_digits[index] += str(digit)
	_field = index
	# Kendiliğinden ilerleme: alan doldu ya da tek hane başka değer alamaz (gün 4–9, ay 2–9).
	if index < 2 and _field_full(index):
		_field = index + 1
	_error.visible = false
	_refresh_entry()


## Alan dolu mu: tam uzunlukta ya da tek hanesi başka rakam alamaz (gün 4–9, ay 2–9) —
## kendiliğinden ilerlemeyle aynı kural. Rakamların ANLAMINA bakmaz (yaş bilgisi yok).
func _field_full(index: int) -> bool:
	var text: String = _digits[index]
	if text.length() >= FIELD_LENGTHS[index]:
		return true
	if text.length() == 1:
		return (index == 0 and int(text) > 3) or (index == 1 and int(text) > 1)
	return false


func press_backspace() -> void:
	if _stage != Stage.ENTRY:
		return
	_overwrite = false
	var index: int = _field
	if _digits[index].is_empty() and index > 0:
		index -= 1
	if not _digits[index].is_empty():
		_digits[index] = _digits[index].substr(0, _digits[index].length() - 1)
	_field = index
	_error.visible = false
	_refresh_entry()


func press_clear() -> void:
	if _stage != Stage.ENTRY:
		return
	_digits = ["", "", ""]
	_field = 0
	_overwrite = false
	_error.visible = false
	_refresh_entry()


func press_continue() -> void:
	if _stage != Stage.ENTRY or not is_complete():
		return
	var result: Dictionary = _classify()
	if not bool(result["ok"]):
		# Geçersiz, gelecek ve çok eski tarih: AYNI nötr mesaj.
		_error.visible = true
		UiKit.modal_relayout(_frame)
		AudioManager.play(&"ui_invalid")
		return
	_confirm_date.text = "%d %s %d" % [int(_digits[0]), MONTHS[int(_digits[1]) - 1], int(_digits[2])]
	_stage = Stage.CONFIRM
	_apply_stage()


## DÜZELT: giriş BOŞALTILIR, oyuncu tarihi baştan girer (dolu alanlarda sessizce yok sayılan
## rakam kalmaz; açılıştaki durumla aynı).
func press_fix() -> void:
	if _stage != Stage.CONFIRM:
		return
	_reset_entry()
	_stage = Stage.ENTRY
	_apply_stage()


## Onay: bugünkü tarihe göre YENİDEN sınıflandırılır, rakamlar SİLİNİR, yalnız türetilmiş
## sonuç yayılır. Doğum tarihi bu düğümden dışarı çıkmaz.
func press_confirm() -> void:
	if _stage != Stage.CONFIRM:
		return
	var result: Dictionary = _classify()
	_reset_entry()
	if not bool(result["ok"]):
		_stage = Stage.ENTRY
		_error.visible = true
		_apply_stage()
		return
	AudioManager.play(&"ui_tap")
	resolved.emit(int(result["band"]), String(result["transition"]))


func press_done() -> void:
	if _stage != Stage.DONE:
		return
	close_panel()
	closed.emit()


## Cihaz saati modelden önceyi gösteriyorsa (bozuk) tarih sınıflandırılmaz: AYNI nötr hata.
func _classify() -> Dictionary:
	var today: Dictionary = AgeGate.today()
	if not AgeGate.clock_plausible(today):
		return {"ok": false, "error": AgeGate.EntryError.INVALID, "band": AgeGate.Band.UNKNOWN, "transition": ""}
	return AgeGate.classify_birth_date(int(_digits[2]), int(_digits[1]), int(_digits[0]), today)


func is_complete() -> bool:
	return not _digits[0].is_empty() and not _digits[1].is_empty() and _digits[2].length() == FIELD_LENGTHS[2]


func _reset_entry() -> void:
	_digits = ["", "", ""]
	_field = 0
	_overwrite = false
	if _confirm_date != null:
		_confirm_date.text = ""
	if _error != null:
		_error.visible = false
	if _field_buttons.size() == 3:
		_refresh_entry()


# --- Görünüm -------------------------------------------------------------------------

func _apply_stage() -> void:
	_entry_box.visible = _stage == Stage.ENTRY
	_confirm_box.visible = _stage == Stage.CONFIRM
	_done_box.visible = _stage == Stage.DONE
	_continue.visible = _stage == Stage.ENTRY
	_confirm_row.visible = _stage == Stage.CONFIRM
	_cancel.visible = _mode == Mode.REENTRY and _stage != Stage.DONE
	_done.visible = _stage == Stage.DONE
	_close_x.visible = _mode == Mode.REENTRY and _stage != Stage.DONE
	_refresh_entry()
	UiKit.modal_relayout(_frame)


func _refresh_entry() -> void:
	for i in 3:
		var field: Button = _field_buttons[i]
		var empty: bool = _digits[i].is_empty()
		field.text = FIELD_PLACEHOLDERS[i] if empty else _digits[i]
		field.theme_type_variation = &"ButtonPrimary" if i == _field else &"ButtonSecondary"
		var color: Color = UiTokens.TEXT_TERTIARY if empty else UiTokens.TEXT_PRIMARY
		if i == _field:
			color = Color(UiTokens.TEXT_ON_ACCENT, 0.55) if empty else UiTokens.TEXT_ON_ACCENT
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			field.add_theme_color_override(state, color)
	if _continue != null:
		UiKit.set_cta_enabled(_continue, is_complete())


# --- Testler / QA sürücüsü (salt okunur) -----------------------------------------------

func mode() -> Mode:
	return _mode


func stage() -> Stage:
	return _stage


func active_field() -> int:
	return _field


## Alanlarda GÖRÜNEN metin (boşken yer tutucu).
func field_text(index: int) -> String:
	return _field_buttons[index].text


## Girilmiş hane sayıları (rakamların kendisi değil).
func field_lengths() -> Array[int]:
	return [_digits[0].length(), _digits[1].length(), _digits[2].length()]


func error_visible() -> bool:
	return _error.visible


func error_text() -> String:
	return _error.text


func confirm_text() -> String:
	return _confirm_date.text


## "Kaydedildi" adımının notu görünüyor mu (her yeniden girişte aynı nötr not).
func done_note_visible() -> bool:
	return _done_box.visible and _next_launch_label.visible


## Son "kaydedildi" adımı NEXT_LAUNCH mıydı (teşhis / QA; ekranda fark YOK).
func done_next_launch() -> bool:
	return _done_next_launch


func frame() -> Control:
	return _frame


func field_button(index: int) -> Button:
	return _field_buttons[index]


func key_button(label: String) -> Button:
	return _keys.get(label)


func continue_button() -> Button:
	return _continue


func confirm_button() -> Button:
	return _confirm


func fix_button() -> Button:
	return _fix


func cancel_button() -> Button:
	return _cancel


func done_button() -> Button:
	return _done


func close_x() -> Button:
	return _close_x


## Pencerede görünen bütün metinler (nötrlük testi: yasaklı sözcük / eşik / yönlendirme).
func visible_texts() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	_collect_texts(_frame, out)
	return out


func _collect_texts(node: Node, out: PackedStringArray) -> void:
	var control := node as Control
	if control != null and not control.is_visible_in_tree():
		return
	if node is Label and not (node as Label).text.is_empty():
		out.append((node as Label).text)
	elif node is Button and not (node as Button).text.is_empty():
		out.append((node as Button).text)
	for child in node.get_children():
		_collect_texts(child, out)
