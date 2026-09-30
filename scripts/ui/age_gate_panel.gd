extends CanvasLayer
## Yaş ekranı (TASK/043 → TASK/046.1 yeniden tasarım — docs/monetization/AGE_BAND_ROUTING.md §3).
## Candy pencere: üstte küçük nötr Squishy + "YAŞINI DOĞRULA" + "Devam etmek için doğum tarihini
## seç."; üç büyük seçici GÜN / AY / YIL (dokun → pencere içinde kompakt seçim ızgarası); DEVAM ET;
## gizlilik notu. Rakam tuş takımı EMEKLİ.
##
## 13+ (owner kararı 2026-09-30): seçici 13 yaşından genç bir tarihi HİÇ sunmaz — yıl / ay / gün
## ızgaraları `AgeGate.selectable_*` aralığından kurulur, bir alan değişince diğerleri
## `AgeGate.clamp_selection` ile uyarlanır: takvim kırpılır (29 Şubat → artık olmayan yılda 28
## Şubat), aralıkla çelişen alan "Seç"e döner (en genç izinli güne KAYDIRILMAZ).
## Eşik bir hata olarak SÖYLENMEZ; "13+", "18+", yaş grubu, reklam, ödül, kilit sözü yok. Aralık
## dışı bir tarih yine de doğrulamaya ulaşırsa (bozuk saat) TEK nötr mesaj: "Tarihi kontrol edip
## tekrar dene." — çıkış / kısıt ekranı YOK.
##
## GİZLİLİK: seçilen gün / ay / yıl yalnız bu düğümün belleğinde yaşar; onay / vazgeç / kapanışta
## silinir. Burada log (print / push_*), analitik olayı, ağ çağrısı YOK. Dışarı yalnız türetilmiş
## sonuç çıkar: `resolved(band, transition)` — band yalnız TEEN / ADULT
## (AgeGate.classify_selected_birth_date).
##
## İki kip:
##   REQUIRED — ilk güvenli kabukta, yaş bilinmiyorken (ya da eski UNDER_13 kaydında) Main açar.
##              Kapatma YOK (X yok, karartma kapatmaz); Android geri UYGULAMADAN ÇIKMAZ (seçim
##              ızgarası / onay açıksa bir adım geri, yoksa yok sayılır).
##   REENTRY  — Ayarlar → "Yaş bilgisi". X / Vazgeç / karartma / geri kapatır (hiçbir şey
##              değişmez); onaydan sonra kısa "kaydedildi" adımı (Main `show_done`).
## Seçiciler her açılışta BOŞ (kayıtlı hiçbir değer gösterilmez — ham doğum tarihi saklanmaz).
## Dokunma güvenliği: açılış / kapanış ve her adım değişimi (ızgara aç / seç, onay, kaydedildi)
## `settle_requested` yayar — Main bunu TASK/045.2 dizi bazlı 300 ms parmak yatışmasına bağlar
## (seçicideki çift dokunuşun ikincisi ızgaradan değer SEÇEMEZ). Onay çift gönderilemez.
## Katman 14: Ayarlar (13) ve günlük pencere (12) üstünde. Zemin: karartmanın içinde opak kabuk
## zemini (gece kasabası, `shell_backdrop`) — arkadaki Ana Sayfa / Ayarlar kontrolleri GÖRÜNMEZ;
## karartmayla birlikte solarak gelir, dokunuşu karartma alır.

signal resolved(band: int, transition: String)
## REENTRY: pencere değişiklik olmadan kapandı ya da "kaydedildi" adımı onaylandı.
signal closed
signal opened
## Adım değişti — Main parmak yatışmasını başlatır.
signal settle_requested

enum Mode { REQUIRED, REENTRY }
enum Stage { ENTRY, PICK, CONFIRM, DONE }
enum Field { DAY, MONTH, YEAR }

const TITLE: String = "YAŞINI DOĞRULA"
const SUBTITLE: String = "Devam etmek için doğum tarihini seç."
const NOTE: String = "Doğum tarihin cihazından çıkmaz."
const ERROR_TEXT: String = "Tarihi kontrol edip tekrar dene."
const CONFIRM_LEAD: String = "Seçtiğin tarih"
const CONFIRM_QUESTION: String = "Doğru mu?"
const DONE_TEXT: String = "Yaş bilgin kaydedildi."
## Her yeniden girişte AYNI (nötr): bir sonraki açılışta uygulanan değişikliği de kapsar.
const DONE_NOTE: String = "Bazı ayarlar uygulama yeniden açıldığında güncellenebilir."
const PLACEHOLDER: String = "Seç"
const CAPTIONS: Array[String] = ["GÜN", "AY", "YIL"]
const PICK_TITLES: Array[String] = ["Gün seç", "Ay seç", "Yıl seç"]
const BACK_TEXT: String = "Geri"
const MONTHS: Array[String] = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz",
	"Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
const MODAL_WIDTH: float = 600.0
## Toplam + 2 ara (12) = 524 ≤ pencere içerik genişliği 528 (600 − 2 × 36): gövde ortada kalır.
const SELECTOR_WIDTHS: Array[float] = [136.0, 200.0, 164.0]
const SELECTOR_HEIGHT: float = 92.0
const SELECTOR_FONT_SIZE: int = 30
const GRID_COLUMNS: Array[int] = [6, 3, 4]
const OPTION_HEIGHT: float = 70.0
const OPTION_FONT_SIZE: int = 26
const ART_SIZE: float = 92.0
const SQUISHY_ART: Texture2D = preload("res://assets/visual/dumpling_tier2.png")
## Hata satırı: gövde metninden küçük değil, krem zeminde >= 4.5:1 kontrast (koyu turuncu).
const ERROR_FONT_SIZE: int = 20
const ERROR_COLOR: Color = Color("9a4a12")

var _mode: Mode = Mode.REQUIRED
var _stage: Stage = Stage.ENTRY
var _picker: int = Field.DAY
## Seçim (0 = seçilmedi) — yalnız bellekte; `_reset_entry` siler.
var _day: int = 0
var _month: int = 0
var _year: int = 0
## Onay gönderildi (çift ONAYLA koruması) — yeni açılışta sıfırlanır.
var _submitted: bool = false

var _frame: Control
var _subtitle: Label
var _close_x: Button
var _entry_box: VBoxContainer
var _selectors: Array[Button] = []
var _selector_values: Array[Label] = []
var _error: Label
var _note: Label
var _pick_box: VBoxContainer
var _pick_title: Label
var _pick_back: Button
var _grid: GridContainer
var _options: Dictionary = {}   # değer -> Button (açık ızgara)
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
## Test / çekim: cihaz güvenli alanı yerine sabit üst pay (tuval px); < 0 = cihazınki.
var _safe_top_override: float = -1.0

@onready var _dim: ColorRect = $Center/Dim
@onready var _anchor: CenterContainer = $Center/Anchor


func _ready() -> void:
	visible = false
	# Opak zemin karartmayı TAM kaplar. A36 kapısı (TASK/046.1): dışa aktarılmış derlemede alt sahne
	# kökünün (shell_backdrop) tam ekran çapaları kayboluyordu (çapa 0, boyut 0 — arkadaki Ana Sayfa
	# görünüyordu); editörde görülmüyor. Çapalar burada açıkça kurulur.
	backdrop().set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Tepelik YOK (taç + yıldız sanatı sonuç / ödül ekranlarının dili — yaş ekranında olmaz).
	_frame = UiKit.modal_shell(TITLE, MODAL_WIDTH, &"heading", false, true)
	_frame.name = "AgeGateShell"
	_anchor.add_child(_frame)
	_close_x = _frame.get_meta(&"close_button")
	_close_x.pressed.connect(_on_cancel)
	UiKit.attach_dim_close(_dim, _on_dim_released)
	_build_hero(_frame.get_meta(&"hero"))
	var body: VBoxContainer = _frame.get_meta(&"body")
	body.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	_build_entry(body)
	_build_picker(body)
	_build_confirm(body)
	_build_done(body)
	_build_footer(_frame.get_meta(&"footer"))
	(_frame.get_meta(&"scroll") as ScrollContainer).scroll_started.connect(_release_options)
	# Ekran boyutu değişince (döndürme / pencere) pencere güvenli üst payın altına yeniden oturur.
	$Center.resized.connect(func() -> void:
		if visible:
			UiKit.seat_modal_below_safe_top(_anchor, _frame, _safe_top_override))
	_apply_stage()
	UiKit.modal_relayout(_frame)


## Sabit üst bölge: küçük nötr Squishy + alt başlık (kaydırılmaz).
func _build_hero(hero: VBoxContainer) -> void:
	hero.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	var art := UiKit.art(SQUISHY_ART, ART_SIZE)
	art.name = "Squishy"
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hero.add_child(art)
	_subtitle = UiKit.label(SUBTITLE, &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle.name = "Subtitle"
	_subtitle.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero.add_child(_subtitle)


func _build_entry(body: VBoxContainer) -> void:
	_entry_box = VBoxContainer.new()
	_entry_box.name = "Entry"
	_entry_box.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	_entry_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_entry_box)
	var row := HBoxContainer.new()
	row.name = "Selectors"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry_box.add_child(row)
	for i in 3:
		var column := VBoxContainer.new()
		column.name = "Column%d" % i
		column.add_theme_constant_override("separation", UiTokens.SPACE_XS)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(column)
		var caption := UiKit.label(CAPTIONS[i], &"LabelBadge", HORIZONTAL_ALIGNMENT_CENTER)
		caption.name = "Caption"
		caption.add_theme_font_size_override("font_size", 17)
		caption.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
		column.add_child(caption)
		var selector := UiKit.button("", &"ButtonSecondary")
		selector.name = "Selector%d" % i
		selector.custom_minimum_size = Vector2(SELECTOR_WIDTHS[i], SELECTOR_HEIGHT)
		selector.pressed.connect(open_picker.bind(i))
		column.add_child(selector)
		# Değer + küçük aşağı ok: butonun içinde ortalı satır (dokunma butona gider).
		var inner := HBoxContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 6)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selector.add_child(inner)
		var value := UiKit.label(PLACEHOLDER, &"LabelSection", HORIZONTAL_ALIGNMENT_CENTER)
		value.name = "Value"
		value.add_theme_font_size_override("font_size", SELECTOR_FONT_SIZE)
		value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inner.add_child(value)
		var chevron := UiKit.icon("arrow_down", 22, UiTokens.TEXT_SECONDARY)
		chevron.name = "Chevron"
		chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inner.add_child(chevron)
		_selectors.append(selector)
		_selector_values.append(value)
	_error = UiKit.label(ERROR_TEXT, &"LabelWarning", HORIZONTAL_ALIGNMENT_CENTER)
	_error.name = "Error"
	_error.add_theme_font_size_override("font_size", ERROR_FONT_SIZE)
	_error.add_theme_color_override("font_color", ERROR_COLOR)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.visible = false
	_entry_box.add_child(_error)
	_note = UiKit.label(NOTE, &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
	_note.name = "Note"
	_note.add_theme_font_size_override("font_size", 17)
	_note.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_entry_box.add_child(_note)


## Pencere içi seçim ızgarası (yeni pencere / açılır liste YOK): başlık satırı (Geri + "Yıl seç")
## + seçenek ızgarası. Seçenekler her açılışta aralıktan yeniden kurulur.
func _build_picker(body: VBoxContainer) -> void:
	_pick_box = VBoxContainer.new()
	_pick_box.name = "Picker"
	_pick_box.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	_pick_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_pick_box)
	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pick_box.add_child(head)
	_pick_back = UiKit.button(BACK_TEXT, &"ButtonSecondary", "arrow_prev")
	_pick_back.name = "PickBack"
	_pick_back.custom_minimum_size = Vector2(150, 60)
	_pick_back.pressed.connect(close_picker)
	head.add_child(_pick_back)
	_pick_title = UiKit.label("", &"LabelSection", HORIZONTAL_ALIGNMENT_CENTER)
	_pick_title.name = "PickTitle"
	_pick_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_pick_title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(150, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(spacer)
	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.add_theme_constant_override("h_separation", UiTokens.SPACE_SM)
	_grid.add_theme_constant_override("v_separation", UiTokens.SPACE_SM)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pick_box.add_child(_grid)


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
	_continue = UiKit.cta("DEVAM ET", "", &"ButtonCTA")
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

## İlk güvenli kabukta, yaş bilinmiyorken (Main). Kapatılamaz; geri tuşu çıkmaz.
func open_required() -> void:
	_open(Mode.REQUIRED)


## Ayarlar → "Yaş bilgisi" (Main). Vazgeçilebilir; seçiciler HER ZAMAN boş açılır.
func open_reentry() -> void:
	_open(Mode.REENTRY)


func _open(mode: Mode) -> void:
	var was_open: bool = visible
	_mode = mode
	_reset_entry()
	_submitted = false
	_stage = Stage.ENTRY
	_apply_stage()
	visible = true
	UiKit.seat_modal_below_safe_top(_anchor, _frame, _safe_top_override)
	UiKit.modal_relayout(_frame)
	(_frame.get_meta(&"scroll") as ScrollContainer).scroll_vertical = 0
	if not was_open:
		UiMotion.modal_open(_frame, _dim)
		AudioManager.play(&"ui_modal_open")
		opened.emit()


## Main: yeniden girişte sonuç kaydedildi — kısa onay adımı. Metin ve not HER cevapta aynı
## (nötr): `next_launch` ekrana ayrı bir işaret olarak YANSIMAZ; yalnız teşhis için tutulur.
func show_done(next_launch: bool) -> void:
	_stage = Stage.DONE
	_done_next_launch = next_launch
	_next_launch_label.visible = true
	_apply_stage()
	settle_requested.emit()


func close_panel() -> void:
	_reset_entry()
	if not visible:
		return
	visible = false
	AudioManager.play(&"ui_modal_close")
	settle_requested.emit()


func _on_cancel() -> void:
	if _mode != Mode.REENTRY or not visible:
		return
	close_panel()
	closed.emit()


func is_reentry() -> bool:
	return _mode == Mode.REENTRY


## Android geri (Main) — HER ZAMAN tüketilir (true): uygulamadan çıkılmaz. Seçim ızgarası açıksa
## ızgara kapanır; onay adımındaysa seçime döner (DÜZELT); yeniden girişte giriş / kaydedildi
## adımında pencere kapanır; zorunlu kipte giriş adımında yok sayılır.
func handle_back() -> bool:
	match _stage:
		Stage.PICK:
			close_picker()
		Stage.CONFIRM:
			press_fix()
		Stage.DONE:
			press_done()
		_:
			_on_cancel()
	return true


func _on_dim_released() -> void:
	if _mode == Mode.REENTRY and (_stage == Stage.ENTRY or _stage == Stage.PICK):
		_on_cancel()


# --- Seçim ---------------------------------------------------------------------------

## Seçim ızgarasını açar: seçenekler bugünkü seçilebilir aralıktan (AgeGate) kurulur.
func open_picker(field: int) -> void:
	if _stage != Stage.ENTRY or field < Field.DAY or field > Field.YEAR:
		return
	_picker = field
	# Saat seçimler arasında kaydıysa (gece yarısı / saat dilimi) önce aralığa uyarla.
	_apply_clamp()
	_build_options()
	_stage = Stage.PICK
	_error.visible = false
	_apply_stage()
	var scroll: ScrollContainer = _frame.get_meta(&"scroll")
	scroll.scroll_vertical = 0
	settle_requested.emit()
	# Seçili değer (varsa) görünür olsun — ızgara bir kare sonra yerleşir.
	var current: int = _value_of(field)
	if _options.has(current):
		await get_tree().process_frame
		if _stage == Stage.PICK and _picker == field and _options.has(current):
			scroll.ensure_control_visible(_options[current])


func close_picker() -> void:
	if _stage != Stage.PICK:
		return
	_clear_options()
	_stage = Stage.ENTRY
	_apply_stage()
	(_frame.get_meta(&"scroll") as ScrollContainer).scroll_vertical = 0
	settle_requested.emit()


## Açık ızgarada bir değer seçer (seçenek butonu da bunu çağırır). Diğer alanlar aralığa
## kırpılır; ızgara kapanır.
func choose(value: int) -> void:
	if _stage != Stage.PICK or not _options.has(value):
		return
	match _picker:
		Field.DAY:
			_day = value
		Field.MONTH:
			_month = value
		Field.YEAR:
			_year = value
	_apply_clamp()
	AudioManager.play(&"ui_tap")
	close_picker()


func _apply_clamp() -> void:
	var clamped: Dictionary = AgeGate.clamp_selection(_day, _month, _year, AgeGate.today())
	_day = int(clamped["day"])
	_month = int(clamped["month"])
	_year = int(clamped["year"])


## Açık alan için seçilebilir değerler (yıl: en genç yıl ilk).
func _option_values(field: int) -> Array[int]:
	var today: Dictionary = AgeGate.today()
	var out: Array[int] = []
	match field:
		Field.DAY:
			var days: Vector2i = AgeGate.selectable_day_range(_year, _month, today)
			for d in range(days.x, days.y + 1):
				out.append(d)
		Field.MONTH:
			var months: Vector2i = AgeGate.selectable_month_range(_year, today) if _year != 0 else Vector2i(1, 12)
			for m in range(months.x, months.y + 1):
				out.append(m)
		Field.YEAR:
			var years: Vector2i = AgeGate.selectable_year_range(today)
			for y in range(years.y, years.x - 1, -1):
				out.append(y)
	return out


## Izgara kapanınca seçenekler de gider (gizli ızgarada seçili değerin izi kalmaz). Basılan
## seçenek kendi `pressed` yayını içinde olabilir — ağaçtan çıkarılmaz, kare sonunda silinir.
func _clear_options() -> void:
	for child in _grid.get_children():
		if not child.is_queued_for_deletion():
			child.queue_free()
	_options.clear()


func _build_options() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_options.clear()
	_grid.columns = GRID_COLUMNS[_picker]
	var selected: int = _value_of(_picker)
	for value in _option_values(_picker):
		var text: String = MONTHS[value - 1] if _picker == Field.MONTH else str(value)
		var option := UiKit.button(text, &"ButtonPrimary" if value == selected else &"ButtonSecondary")
		option.name = "Option_%d" % value
		option.custom_minimum_size = Vector2(0, OPTION_HEIGHT)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.add_theme_font_size_override("font_size", OPTION_FONT_SIZE)
		# Kaydırma seçeneklerin üstünden de başlar; kaydırma başlayınca basış bırakılır
		# (BaseButton SCROLL_BEGIN'de basışı iptal eder — seçim olmaz).
		option.mouse_filter = Control.MOUSE_FILTER_PASS
		option.pressed.connect(choose.bind(value))
		_grid.add_child(option)
		_options[value] = option
	_pick_title.text = PICK_TITLES[_picker]


func _release_options() -> void:
	for option: Button in _options.values():
		UiMotion.release(option)


func _value_of(field: int) -> int:
	match field:
		Field.DAY:
			return _day
		Field.MONTH:
			return _month
	return _year


func press_continue() -> void:
	if _stage != Stage.ENTRY or not is_complete():
		return
	var result: Dictionary = _classify()
	if not bool(result["ok"]):
		# Aralık dışı / geçersiz / bozuk saat: TEK nötr mesaj (eşik söylenmez).
		_error.visible = true
		UiKit.modal_relayout(_frame)
		AudioManager.play(&"ui_invalid")
		return
	_confirm_date.text = "%d %s %d" % [_day, MONTHS[_month - 1], _year]
	_stage = Stage.CONFIRM
	_apply_stage()
	settle_requested.emit()


## DÜZELT: seçime dönülür, seçilen değerler KORUNUR (oyuncu bir alanı değiştirir).
func press_fix() -> void:
	if _stage != Stage.CONFIRM:
		return
	# Gönderim reddedildiyse (Main başka bant almadı) panel kilitli kalmasın.
	_submitted = false
	_stage = Stage.ENTRY
	_apply_stage()
	settle_requested.emit()


## Onay: bugünkü tarihe göre YENİDEN sınıflandırılır, seçim SİLİNİR, yalnız türetilmiş sonuç
## yayılır (tek sefer — hızlı ikinci ONAYLA yok sayılır).
func press_confirm() -> void:
	if _stage != Stage.CONFIRM or _submitted:
		return
	var result: Dictionary = _classify()
	_reset_entry()
	if not bool(result["ok"]):
		_stage = Stage.ENTRY
		_error.visible = true
		_apply_stage()
		AudioManager.play(&"ui_invalid")
		settle_requested.emit()
		return
	_submitted = true
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
	return AgeGate.classify_selected_birth_date(_year, _month, _day, today)


func is_complete() -> bool:
	return _day != 0 and _month != 0 and _year != 0


func _reset_entry() -> void:
	_day = 0
	_month = 0
	_year = 0
	if _grid != null:
		_clear_options()
	if _confirm_date != null:
		_confirm_date.text = ""
	if _error != null:
		_error.visible = false
	if _selectors.size() == 3:
		_refresh_entry()


# --- Görünüm -------------------------------------------------------------------------

func _apply_stage() -> void:
	_entry_box.visible = _stage == Stage.ENTRY
	_pick_box.visible = _stage == Stage.PICK
	_confirm_box.visible = _stage == Stage.CONFIRM
	_done_box.visible = _stage == Stage.DONE
	_continue.visible = _stage == Stage.ENTRY
	_confirm_row.visible = _stage == Stage.CONFIRM
	_cancel.visible = _mode == Mode.REENTRY and (_stage == Stage.ENTRY or _stage == Stage.CONFIRM)
	_done.visible = _stage == Stage.DONE
	# "Kaydedildi" adımında "doğum tarihini seç" istemi anlamsız — yalnız Squishy kalır.
	_subtitle.visible = _stage != Stage.DONE
	_close_x.visible = _mode == Mode.REENTRY and _stage != Stage.DONE
	_refresh_entry()
	UiKit.modal_relayout(_frame)


func _refresh_entry() -> void:
	for i in 3:
		var value: int = _value_of(i)
		var label: Label = _selector_values[i]
		if value == 0:
			label.text = PLACEHOLDER
			label.add_theme_color_override("font_color", UiTokens.TEXT_TERTIARY)
		else:
			label.text = MONTHS[value - 1] if i == Field.MONTH else str(value)
			label.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	if _continue != null:
		UiKit.set_cta_enabled(_continue, is_complete())


# --- Testler / QA sürücüsü (salt okunur) -----------------------------------------------

## Cihaz güvenli alanı yerine sabit üst pay (tuval px) — testler / çekim aracı.
func layout_with_safe_top(safe_top: float) -> void:
	_safe_top_override = safe_top
	if visible:
		UiKit.seat_modal_below_safe_top(_anchor, _frame, _safe_top_override)
		UiKit.modal_relayout(_frame)


func mode() -> Mode:
	return _mode


func stage() -> Stage:
	return _stage


## Açık seçim ızgarasının alanı (Field) — ızgara kapalıysa -1.
func picker_field() -> int:
	return _picker if _stage == Stage.PICK else -1


## Hangi alanlar seçili (değerlerin kendisi değil — QA durum satırı için).
func selected_fields() -> Array[bool]:
	return [_day != 0, _month != 0, _year != 0]


## Seçim (yalnız testler; bellek içi). {"day", "month", "year"} — 0 = seçilmedi.
func selection() -> Dictionary:
	return {"day": _day, "month": _month, "year": _year}


## Açık ızgaradaki değerler (sırasıyla).
func option_values() -> Array[int]:
	var out: Array[int] = []
	for value: int in _options.keys():
		out.append(value)
	return out


func option_button(value: int) -> Button:
	return _options.get(value)


func selector_button(index: int) -> Button:
	return _selectors[index]


## Seçicide GÖRÜNEN metin (boşken "Seç").
func selector_text(index: int) -> String:
	return _selector_values[index].text


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


func dim() -> ColorRect:
	return _dim


## Opak tam ekran zemin (karartmanın çocuğu).
func backdrop() -> Control:
	return _dim.get_node("Backdrop")


func picker_back_button() -> Button:
	return _pick_back


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


## Pencerede görünen bütün metinler.
func visible_texts() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	_collect_texts(_frame, out, false)
	return out


## Görünen AÇIKLAMA metinleri (seçim ızgarasının sayı / ay seçenekleri hariç) — nötrlük testi:
## eşik, yaş grubu, reklam, ödül sözü yok.
func explanatory_texts() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	_collect_texts(_frame, out, true)
	return out


func _collect_texts(node: Node, out: PackedStringArray, skip_values: bool) -> void:
	var control := node as Control
	if control != null and not control.is_visible_in_tree():
		return
	if skip_values and (node == _grid or (node is Button and _selectors.has(node as Button))):
		return
	if node is Label and not (node as Label).text.is_empty():
		out.append((node as Label).text)
	elif node is Button and not (node as Button).text.is_empty():
		out.append((node as Button).text)
	for child in node.get_children():
		_collect_texts(child, out, skip_values)
