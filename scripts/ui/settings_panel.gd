extends CanvasLayer
## Ayarlar penceresi (M8.5-10) — production temeli, bilerek küçük:
##
##   Ses Efektleri   gerçek anahtar: SFX bus'ını susturur, kayda yazar
##   Gizlilik        kısa, doğru metin (veri toplanmıyor, backend yok)
##   Hakkında        uygulama adı + sürüm (project.godot → config/version)
##   Kapat           candy CTA + sağ üst kapatma ikonu + karartmaya dokunma
##
## MÜZİK ANAHTARI BİLEREK YOK: arka plan müziği v1 non-goal (GAME_DESIGN §6),
## Music bus'ı boş. Hiçbir şey çalmayan bir "Müzik" anahtarı sahte bir
## kontrol olurdu. Müzik gelirse `_add_toggle_row` ile tek satır eklenir.
##
## Görsel: devam/refill pencereleriyle AYNI candy panel + tepelik + CTA.

signal closed

const PRIVACY_TEXT: String = "Squishy Merge kişisel veri toplamaz. İlerlemen yalnızca bu cihazda saklanır; hesap, sunucu ve analitik yoktur. Şu an reklam ve uygulama içi satın alma da yok."

var _sfx_toggle: UiToggle
var _privacy_button: Button
var _close_icon: Button

@onready var _dim: ColorRect = $Center/Dim
@onready var _modal: Control = $Center/Modal
@onready var _rows: VBoxContainer = $Center/Modal/Panel/VBox/Rows
@onready var _privacy: VBoxContainer = $Center/Modal/Panel/VBox/Privacy
@onready var _privacy_text: Label = $Center/Modal/Panel/VBox/Privacy/PrivacyText
@onready var _about: Label = $Center/Modal/Panel/VBox/About
@onready var _close: Button = $Center/Modal/Panel/VBox/Close


func _ready() -> void:
	visible = false
	CandyButton.style_cta(_close)
	_close.pressed.connect(close_panel)
	UiMotion.attach_press(_close)
	_dim.gui_input.connect(_on_dim_input)

	_sfx_toggle = _add_toggle_row(UiPalette.ICON_VOLUME, "Ses Efektleri")
	_sfx_toggle.toggled.connect(_on_sfx_toggled)
	_privacy_button = _add_link_row(UiPalette.ICON_INFO, "Gizlilik", "Göster")
	_privacy_button.pressed.connect(_toggle_privacy)
	_privacy_text.text = PRIVACY_TEXT

	var version: String = String(ProjectSettings.get_setting("application/config/version", "dev"))
	_about.text = "Squishy Merge · Sürüm %s" % version

	# Sağ üst kapatma ikonu — modal kapatma yolu her zaman görünür olsun.
	_close_icon = UiPalette.icon_button(UiPalette.ICON_CLOSE, 56.0, UiPalette.TEXT_ON_CREAM)
	UiPalette.style_ghost_on_cream(_close_icon, 28)
	_close_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_close_icon.offset_left = -56.0 - 30.0
	_close_icon.offset_right = -30.0
	_close_icon.offset_top = 30.0
	_close_icon.offset_bottom = 30.0 + 56.0
	_close_icon.pressed.connect(close_panel)
	_modal.add_child(_close_icon)


func open_panel() -> void:
	_sfx_toggle.set_on(SaveManager.sfx_enabled())
	_privacy.visible = false
	_privacy_button.text = "Göster"
	visible = true
	UiMotion.modal_open(_modal, _dim)


func close_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _on_sfx_toggled(on: bool) -> void:
	SaveManager.set_sfx_enabled(on)
	# Açınca duyulur bir onay; kapatınca zaten sessiz.
	if on:
		AudioManager.play_sfx(&"star_pat", 1.2)


func _toggle_privacy() -> void:
	_privacy.visible = not _privacy.visible
	_privacy_button.text = "Gizle" if _privacy.visible else "Göster"


## Karartmaya dokunmak da kapatır — "nereye basacağım?" sorusu olmasın.
func _on_dim_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed:
		close_panel()
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		close_panel()


# --- Satırlar ---

## Krem panel üstünde koyu erik yazı; ikon aynı tonda. Satır sakin bir
## yüzey (%60 kotasından), yalnızca anahtar renkli.
func _make_row(icon: Texture2D, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size = Vector2(0, 60)
	var rect := UiPalette.icon_rect(icon, 34.0, UiPalette.TEXT_ON_CREAM)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rect)
	var label := Label.new()
	UiType.apply(label, UiType.CARD_TITLE)
	label.text = title
	label.add_theme_color_override("font_color", UiPalette.TEXT_ON_CREAM)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_rows.add_child(row)
	return row


func _add_toggle_row(icon: Texture2D, title: String) -> UiToggle:
	var row := _make_row(icon, title)
	var toggle := UiToggle.new()
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(toggle)
	return toggle


func _add_link_row(icon: Texture2D, title: String, action: String) -> Button:
	var row := _make_row(icon, title)
	var button := Button.new()
	UiType.apply(button, UiType.SECONDARY_BUTTON)
	button.text = action
	button.custom_minimum_size = Vector2(120, 48)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiPalette.style_ghost_on_cream(button, 20)
	UiMotion.attach_press(button)
	row.add_child(button)
	return button
