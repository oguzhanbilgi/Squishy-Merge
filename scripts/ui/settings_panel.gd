extends CanvasLayer
## Ayarlar penceresi — production yeniden kurulum (M8.6-08), bilerek küçük:
##
##   Ses Efektleri   gerçek anahtar: SFX bus'ını susturur, kayda yazar
##   Titreşim        gerçek anahtar (M8.5-15): Haptics'i kapatır, kayda yazar
##   Gizlilik        kısa, doğru metin (hesap/sunucu/analitik yok; reklam
##                   için Google AdMob — M8.9-01) — Göster/Gizle ile
##                   pencerenin İÇİNDE açılır
##   Gizlilik seçenekleri  (M8.9-01) YALNIZ UMP gerekli diyorsa görünür (M9-01:
##                   `getPrivacyOptionsRequirementStatus() == REQUIRED`): Aç →
##                   SDK'nın kendi gizlilik seçenekleri formu. SDK gerekli
##                   demiyorsa satır GİZLİ (sahte kontrol yok).
##   Gizlilik politikası   (M9-01) Play'in "uygulama içinde de" şartı için
##                   barındırılan politikaya bağlantı; URL owner'da (project.godot
##                   `squishy/privacy/policy_url`) — boşken satır HİÇ görünmez.
##   Yaş bilgisi     (TASK/043) doğum tarihini yeniden girme — Main nötr yaş ekranını
##                   yeniden giriş kipinde açar. Kayıtlı yaş / tarih GÖSTERİLMEZ (doğum
##                   tarihi saklanmıyor). Yalnız reklam yöneticisi varken ve yaş bandı
##                   biliniyorken (TEEN / ADULT) görünür (`set_age_info_visible`).
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
## TASK/043: "Yaş bilgisi → Güncelle" — Main nötr yaş ekranını yeniden giriş kipinde açar.
signal age_info_requested

const PRIVACY_TEXT: String = "Squishy Merge hesap, sunucu ve analitik kullanmaz; ilerlemen yalnızca bu cihazda saklanır. Ödüllü, banner ve geçiş (tam ekran) reklamları için Google AdMob kullanılır; reklam SDK'sı reklam kimliği gibi cihaz verilerini Google'ın gizlilik politikasına göre işleyebilir. Doğum tarihin saklanmaz; cihazda yalnızca yaş grubun ve bir sonraki gruba geçiş günün (doğum günün) tutulur; reklam isteğine yalnızca yaş grubuna uygun ayar eklenir. Uygulama içi satın alma yok."
const AGE_INFO_TITLE: String = "Yaş bilgisi"
const AGE_INFO_BUTTON: String = "Güncelle"
const PRIVACY_OPTIONS_TITLE: String = "Gizlilik seçenekleri"
const PRIVACY_OPTIONS_BUTTON: String = "Aç"
const PRIVACY_POLICY_TITLE: String = "Gizlilik politikası"
## Owner'ın barındırdığı politika (M9-01); boş = satır yok.
const PRIVACY_POLICY_SETTING: String = "squishy/privacy/policy_url"
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
## Gizlilik politikası bağlantısı (M9-01): satır + ayırıcı, URL yoksa gizli.
var _privacy_policy_row: HBoxContainer
var _privacy_policy_divider: Control
var _privacy_policy_button: Button
## Yaş bilgisi (TASK/043): satır + ayırıcı, varsayılan gizli (Main açar).
var _age_info_row: HBoxContainer
var _age_info_divider: Control
var _age_info_button: Button
var _age_info_visible: bool = false
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

	# Gizlilik politikası (M9-01): yalnız owner bir https URL'i verdiyse.
	_privacy_policy_divider = UiKit.settings_divider()
	_privacy_policy_divider.name = "PrivacyPolicyDivider"
	body.add_child(_privacy_policy_divider)
	_privacy_policy_button = UiKit.button(PRIVACY_OPTIONS_BUTTON, &"ButtonSecondary")
	_privacy_policy_button.custom_minimum_size = Vector2(132, UiTokens.HEIGHT_NORMAL)
	_privacy_policy_button.pressed.connect(_on_privacy_policy_pressed)
	_privacy_policy_row = UiKit.settings_row("help", PRIVACY_POLICY_TITLE, _privacy_policy_button)
	_privacy_policy_row.name = "PrivacyPolicyRow"
	body.add_child(_privacy_policy_row)
	_apply_privacy_policy_visibility()

	# Yaş bilgisi (TASK/043): yalnız Main görünür yapınca (reklam yöneticisi + bilinen bant).
	_age_info_divider = UiKit.settings_divider()
	_age_info_divider.name = "AgeInfoDivider"
	body.add_child(_age_info_divider)
	_age_info_button = UiKit.button(AGE_INFO_BUTTON, &"ButtonSecondary")
	_age_info_button.custom_minimum_size = Vector2(132, UiTokens.HEIGHT_NORMAL)
	_age_info_button.pressed.connect(_on_age_info_pressed)
	_age_info_row = UiKit.settings_row("calendar", AGE_INFO_TITLE, _age_info_button)
	_age_info_row.name = "AgeInfoRow"
	body.add_child(_age_info_row)
	_apply_age_info_visibility()

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
	_apply_privacy_policy_visibility()
	_apply_age_info_visibility()
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


## TASK/053: KAPALI pencere eylem üretmez. Pencere bir kontrol BASILIYKEN gizlenirse (round bitişi Ayarlar'ı kapatır; ya
## da Android geri) Godot gizleme anında o düğmeye sentetik bırakış yollar ve son girdi işlenmemişse BaseButton onu
## tıklama sayar (TASK/049'un Mola dersi) — tercih yazılmaz, yaş / gizlilik penceresi açılmaz, tarayıcı açılmaz.
## Anahtarın görünümü bir sonraki `open_panel()`'da kayıttan yeniden kurulur. Gizlilik metni (yalnız pencere içi,
## açılışta kapanır) ve kapanış (`close_panel` zaten görünürlükle korunur) bu kapsamda değil.
func _on_sfx_toggled(on: bool) -> void:
	if not visible:
		return
	SaveManager.set_sfx_enabled(on)
	# Açınca duyulur bir onay; kapatınca zaten sessiz.
	if on:
		AudioManager.play(&"ui_toggle_on")


func _on_haptics_toggled(on: bool) -> void:
	if not visible:
		return
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
	if not visible or not _privacy_options_required() or not _privacy_options_source.has_method("show_privacy_options"):
		return
	AudioManager.play(&"ui_tap")
	_privacy_options_source.show_privacy_options()


# --- Gizlilik politikası (M9-01) --------------------------------------------------

## Owner'ın verdiği politika URL'i; yalnız https kabul (boş/başka → "").
static func privacy_policy_url() -> String:
	var url: String = String(ProjectSettings.get_setting(PRIVACY_POLICY_SETTING, "")).strip_edges()
	return url if url.begins_with("https://") else ""


func _apply_privacy_policy_visibility() -> void:
	if _privacy_policy_row == null:
		return
	var shown: bool = not privacy_policy_url().is_empty()
	_privacy_policy_row.visible = shown
	_privacy_policy_divider.visible = shown
	if visible and _frame != null:
		UiKit.modal_relayout(_frame)


func _on_privacy_policy_pressed() -> void:
	var url: String = privacy_policy_url()
	if not visible or url.is_empty():
		return
	AudioManager.play(&"ui_tap")
	OS.shell_open(url)


# --- Yaş bilgisi (TASK/043) --------------------------------------------------------------

## Main: reklam yöneticisi varken ve yaş bandı TEEN / ADULT iken true. Bilinmeyen yaş
## zorunlu yaş ekranıyla (kabukta) çözülür; 13 altı Ayarlar'a hiç ulaşamaz (kısıt ekranı).
func set_age_info_visible(shown: bool) -> void:
	_age_info_visible = shown
	_apply_age_info_visibility()


func _apply_age_info_visibility() -> void:
	if _age_info_row == null:
		return
	_age_info_row.visible = _age_info_visible
	_age_info_divider.visible = _age_info_visible
	if visible and _frame != null:
		UiKit.modal_relayout(_frame)


func _on_age_info_pressed() -> void:
	if not visible or not _age_info_visible:
		return
	AudioManager.play(&"ui_tap")
	age_info_requested.emit()


func age_info_row() -> HBoxContainer:
	return _age_info_row


func age_info_button() -> Button:
	return _age_info_button


## Testler / araçlar için.
func frame() -> Control:
	return _frame


func privacy_policy_row() -> HBoxContainer:
	return _privacy_policy_row


func privacy_options_row() -> HBoxContainer:
	return _privacy_options_row


func privacy_options_button() -> Button:
	return _privacy_options_button


func is_privacy_open() -> bool:
	return _privacy.visible
