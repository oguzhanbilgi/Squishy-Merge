extends CanvasLayer
## Ayarlar penceresi — production yeniden kurulum (M8.6-08), bilerek küçük:
##
##   Ses Efektleri   gerçek anahtar: SFX bus'ını susturur, kayda yazar
##   Titreşim        gerçek anahtar (M8.5-15): Haptics'i kapatır, kayda yazar
##   Gizlilik        kısa, doğru metin (hesap/sunucu/analitik yok; reklam
##                   için Google AdMob — M8.9-01) — Göster/Gizle ile
##                   pencerenin İÇİNDE açılır
##   Gizlilik seçenekleri  (M8.9-01) YALNIZ reklam SDK'sı (UMP) bir rıza
##                   formu sunuyorsa görünür: Aç → SDK'nın kendi formu.
##                   SDK gerekli demiyorsa satır GİZLİ (sahte kontrol yok).
##   Sürüm           uygulama adı + sürüm (project.godot → config/version)
##   Kapat           altlıkta ikincil buton; X ve karartma da kapatır
##
## MÜZİK ANAHTARI BİLEREK YOK: arka plan müziği v1 non-goal (GAME_DESIGN §6),
## Music bus'ı boş. Hiçbir şey çalmayan bir "Müzik" anahtarı sahte bir
## kontrol olurdu. Müzik gelirse `UiKit.settings_row` ile tek satır eklenir.
##
## Görsel: `UiKit.modal_shell` (shell v2, tepelik + gövde içi AYARLAR
## başlığı + oturmuş X), `UiKit.settings_row` (picto kuyucuk + Baloo başlık +
## `UiKit.switch_toggle`), altlıkta sürüm + Kapat. M8.6-07 denetiminin
## onayladığı taşma kusuru (Gizlilik → Göster metni sabit 600×560
## çerçeveden dışarı itiyordu) burada YAPISAL olarak kapandı: pencere
## içeriği kadar büyür, güvenli yüksekliği aşınca gövde kaydırılır, sürüm
## ve Kapat altlıkta cercevenin içinde kalır.
##
## Kayıt sözleşmesi DEĞİŞMEDİ: yalnız `SaveManager.set_sfx_enabled` /
## `set_haptics_enabled` yazar (anahtar dokunuşunda); açılış/kapanış yazmaz.
## Katman 13: Mola (12) üstünde — ikisi de açıksa Ayarlar önde ve Mola'nın
## girdisi karartmanın arkasında kalır (M8.6-07 z-order bulgusu).

signal closed

const PRIVACY_TEXT: String = "Squishy Merge hesap, sunucu ve analitik kullanmaz; ilerlemen yalnızca bu cihazda saklanır. Ödüllü, banner ve geçiş (tam ekran) reklamları için Google AdMob kullanılır; reklam SDK'sı reklam kimliği gibi cihaz verilerini Google'ın gizlilik politikasına göre işleyebilir. Uygulama içi satın alma yok."
const PRIVACY_OPTIONS_TITLE: String = "Gizlilik seçenekleri"
const PRIVACY_OPTIONS_BUTTON: String = "Aç"
const MODAL_WIDTH: float = 560.0

var _frame: Control
var _sfx_toggle: UiToggle
var _haptics_toggle: UiToggle
var _privacy_button: Button
## Genişleyen gizlilik bloğu (metin plakası). Adı ui_smoke_test ile aynı.
var _privacy: PanelContainer
var _privacy_text: Label
## Reklam rızası giriş noktası (M8.9-01): satır + ayırıcı, varsayılan gizli.
var _privacy_options_row: HBoxContainer
var _privacy_options_divider: Control
var _privacy_options_button: Button
## `privacy_options_required()` / `show_privacy_options()` + sinyal
## `privacy_options_changed(required)` sunan nesne (MonetizationManager);
## null = reklam yöneticisi yok → satır hiç görünmez.
var _privacy_options_source: Object = null
var _about: Label
var _close: Button

@onready var _dim: ColorRect = $Center/Dim
@onready var _anchor: CenterContainer = $Center/Anchor


func _ready() -> void:
	visible = false
	_frame = UiKit.modal_shell("AYARLAR", MODAL_WIDTH, &"heading", true, true)
	_anchor.add_child(_frame)
	var body: VBoxContainer = _frame.get_meta(&"body")
	body.add_theme_constant_override("separation", UiTokens.SPACE_XS)

	_sfx_toggle = _make_toggle()
	_sfx_toggle.toggled.connect(_on_sfx_toggled)
	body.add_child(UiKit.settings_row("sound_on", "Ses Efektleri", _sfx_toggle))
	body.add_child(UiKit.settings_divider())
	_haptics_toggle = _make_toggle()
	_haptics_toggle.toggled.connect(_on_haptics_toggled)
	body.add_child(UiKit.settings_row("vibration", "Titreşim", _haptics_toggle))
	body.add_child(UiKit.settings_divider())
	_privacy_button = UiKit.button("Göster", &"ButtonSecondary")
	_privacy_button.custom_minimum_size = Vector2(132, UiTokens.HEIGHT_NORMAL)
	_privacy_button.pressed.connect(_toggle_privacy)
	body.add_child(UiKit.settings_row("info", "Gizlilik", _privacy_button))

	# Gizlilik metni: bir ton geri krem plaka, gövde yazısı; yalnız açıkken.
	_privacy = UiKit.flat_plate("frame_round20", UiTokens.CREAM_DEEP)
	_privacy.name = "Privacy"
	_privacy.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_privacy.add_theme_stylebox_override("panel",
		UiKit.style("frame_round20", UiTokens.CREAM_DEEP, Vector4(18, 14, 18, 16)))
	_privacy.visible = false
	var privacy_column := VBoxContainer.new()
	privacy_column.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	privacy_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_privacy.add_child(privacy_column)
	_privacy_text = UiKit.label(PRIVACY_TEXT, &"LabelBody")
	_privacy_text.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_privacy_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_privacy_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	privacy_column.add_child(_privacy_text)
	var privacy_gap := Control.new()
	privacy_gap.name = "PrivacyGap"
	privacy_gap.custom_minimum_size = Vector2(0, UiTokens.SPACE_SM)
	privacy_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	privacy_gap.visible = false
	body.add_child(privacy_gap)
	body.add_child(_privacy)
	_privacy.set_meta(&"gap", privacy_gap)

	# Gizlilik seçenekleri (UMP): yalnız SDK "gerekli" derken görünür.
	_privacy_options_divider = UiKit.settings_divider()
	_privacy_options_divider.name = "PrivacyOptionsDivider"
	_privacy_options_divider.visible = false
	body.add_child(_privacy_options_divider)
	_privacy_options_button = UiKit.button(PRIVACY_OPTIONS_BUTTON, &"ButtonSecondary")
	_privacy_options_button.custom_minimum_size = Vector2(132, UiTokens.HEIGHT_NORMAL)
	_privacy_options_button.pressed.connect(_on_privacy_options_pressed)
	_privacy_options_row = UiKit.settings_row("lock", PRIVACY_OPTIONS_TITLE, _privacy_options_button)
	_privacy_options_row.name = "PrivacyOptionsRow"
	_privacy_options_row.visible = false
	body.add_child(_privacy_options_row)
	_apply_privacy_options_visibility()

	# Altlık: sürüm (düşük vurgu) + Kapat. Hiç kaydırılmaz.
	var footer: VBoxContainer = _frame.get_meta(&"footer")
	var footer_gap := Control.new()
	footer_gap.custom_minimum_size = Vector2(0, UiTokens.SPACE_SM)
	footer_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(footer_gap)
	var version: String = String(ProjectSettings.get_setting("application/config/version", "dev"))
	_about = UiKit.label("Squishy Merge · Sürüm %s" % version, &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
	_about.add_theme_color_override("font_color", UiTokens.TEXT_TERTIARY)
	footer.add_child(_about)
	_close = UiKit.button("Kapat", &"ButtonSecondary")
	_close.name = "Close"
	_close.pressed.connect(close_panel)
	footer.add_child(_close)

	(_frame.get_meta(&"close_button") as Button).pressed.connect(close_panel)
	UiKit.attach_dim_close(_dim, close_panel)
	UiKit.modal_relayout(_frame)


## Anahtar: `UiKit.switch_toggle` (nane ray + LayerLab topuz). MOUSE_FILTER_PASS:
## gövde kısa ekranda kaydırılabildiğinde anahtardan başlayan sürükleme de
## kaydırır (Mağaza SATIN AL dersi, M8.6-06.3); BaseButton kaydırma başlayınca
## basışı iptal eder, anahtar yanlışlıkla dönmez.
func _make_toggle() -> UiToggle:
	var toggle := UiKit.switch_toggle(true)
	toggle.custom_minimum_size = Vector2(96, 52)
	toggle.mouse_filter = Control.MOUSE_FILTER_PASS
	return toggle


func open_panel() -> void:
	_sfx_toggle.set_on(SaveManager.sfx_enabled())
	_haptics_toggle.set_on(SaveManager.haptics_enabled())
	_set_privacy_open(false)
	_apply_privacy_options_visibility()
	visible = true
	UiKit.modal_relayout(_frame)
	(_frame.get_meta(&"scroll") as ScrollContainer).scroll_vertical = 0
	UiMotion.modal_open(_frame, _dim)
	AudioManager.play(&"ui_modal_open")


func close_panel() -> void:
	if not visible:
		return
	visible = false
	AudioManager.play(&"ui_modal_close")
	closed.emit()


func _on_sfx_toggled(on: bool) -> void:
	SaveManager.set_sfx_enabled(on)
	# Açınca duyulur bir onay; kapatınca zaten sessiz.
	if on:
		AudioManager.play(&"ui_toggle_on")


func _on_haptics_toggled(on: bool) -> void:
	SaveManager.set_haptics_enabled(on)
	# Açınca hissedilir bir onay (destekleyen cihazda); kapatınca zaten yok.
	if on:
		Haptics.medium()


func _toggle_privacy() -> void:
	_set_privacy_open(not _privacy.visible)


func _set_privacy_open(open: bool) -> void:
	_privacy.visible = open
	(_privacy.get_meta(&"gap") as Control).visible = open
	_privacy_button.text = "Gizle" if open else "Göster"


# --- Gizlilik seçenekleri (M8.9-01) ---------------------------------------------

## Main bağlar (yönetici yoksa null). SDK durumu değişince satır güncellenir.
func set_privacy_options_source(source: Object) -> void:
	if _privacy_options_source != null and _privacy_options_source.has_signal("privacy_options_changed"):
		_privacy_options_source.privacy_options_changed.disconnect(_on_privacy_options_changed)
	_privacy_options_source = source
	if source != null and source.has_signal("privacy_options_changed"):
		source.privacy_options_changed.connect(_on_privacy_options_changed)
	_apply_privacy_options_visibility()


func _on_privacy_options_changed(_required: bool) -> void:
	_apply_privacy_options_visibility()


func _privacy_options_required() -> bool:
	return (_privacy_options_source != null and is_instance_valid(_privacy_options_source)
		and _privacy_options_source.has_method("privacy_options_required")
		and _privacy_options_source.privacy_options_required())


func _apply_privacy_options_visibility() -> void:
	if _privacy_options_row == null:
		return
	var required: bool = _privacy_options_required()
	_privacy_options_row.visible = required
	_privacy_options_divider.visible = required
	if visible and _frame != null:
		UiKit.modal_relayout(_frame)


func _on_privacy_options_pressed() -> void:
	if not _privacy_options_required() or not _privacy_options_source.has_method("show_privacy_options"):
		return
	AudioManager.play(&"ui_tap")
	_privacy_options_source.show_privacy_options()


## Testler / araçlar için.
func frame() -> Control:
	return _frame


func privacy_options_row() -> HBoxContainer:
	return _privacy_options_row


func privacy_options_button() -> Button:
	return _privacy_options_button


func is_privacy_open() -> bool:
	return _privacy.visible
