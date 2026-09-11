extends CanvasLayer
## Alt sekme çubuğu: Ana Sayfa / Harita / Koleksiyon / Mağaza.
## Oyun sırasında ve round sonucu ekranında gizleniyor (main.gd yönetiyor).
##
## M8.5-10: generic buton sırası yerine gerçek mobil sekme çubuğu — her
## sekme ikon + etiket, seçili sekme altın ve arkasında yumuşak bir pill.
## Dört sekme aynı yükseklik, aynı baseline, aynı ikon ölçüsü; dokunma
## alanı sekmenin tamamı (≥ 96 px yüksek).
##
## İkonlar Free Casual GUI paketinden türetilen beyaz maskeler
## (tools/make_pack_icons.gd), rengi `self_modulate` veriyor.

signal tab_selected(tab: int)

enum Tab { HOME, MAP, COLLECTION, SHOP }

const LABELS: Array[String] = ["Ana Sayfa", "Harita", "Koleksiyon", "Mağaza"]
const ICONS: Array[Texture2D] = [
	UiPalette.ICON_HOME, UiPalette.ICON_PLAY, UiPalette.ICON_BADGE, UiPalette.ICON_CART]

## Çubuğun yüksekliği. Ekranlar alt payını buna göre bırakıyor
## (`BAR_HEIGHT` + nefes payı).
const BAR_HEIGHT: float = 112.0
## İleride AdMob banner'ı çubuğun ALTINA girecek: çubuk bu kadar yukarı
## kayar, ekran payları da `bottom_inset()` üzerinden aynı miktarda büyür.
## Şimdilik 0 — banner yok (GAME_DESIGN §5.7.3, AdMob SDK kurulmadı).
const AD_SAFE_INSET: float = 0.0

const ICON_BOX: float = 36.0
const PILL_SIZE: Vector2 = Vector2(64.0, 44.0)

var _buttons: Array[Button] = []
var _icons: Array[TextureRect] = []
var _labels: Array[Label] = []
var _pills: Array[PanelContainer] = []
var _active: int = -1

@onready var _anchor: Control = $Anchor
@onready var _row: HBoxContainer = $Anchor/Bar/Row


static func bottom_inset() -> float:
	return BAR_HEIGHT + AD_SAFE_INSET


func _ready() -> void:
	_anchor.offset_top = -bottom_inset()
	_anchor.offset_bottom = -AD_SAFE_INSET
	var group := ButtonGroup.new()
	for i in LABELS.size():
		var button := Button.new()
		UiType.apply(button, UiType.TAB_BUTTON)
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, BAR_HEIGHT - 16.0)
		button.pressed.connect(_on_tab_pressed.bind(i))
		UiMotion.attach_press(button)
		_row.add_child(button)
		_buttons.append(button)

		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.set_anchors_preset(Control.PRESET_FULL_RECT)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 2)
		button.add_child(column)

		# Seçili sekmenin arkasındaki yumuşak pill. Yer her sekmede ayrılıyor
		# (görünmezken de boyut tutuyor) ki seçim değişince satır zıplamasın.
		var pill := PanelContainer.new()
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.custom_minimum_size = PILL_SIZE
		pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pill.add_theme_stylebox_override("panel", _pill_style())
		column.add_child(pill)
		_pills.append(pill)

		var icon := UiPalette.icon_rect(ICONS[i], ICON_BOX, UiPalette.TAB_IDLE)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pill.add_child(icon)
		_icons.append(icon)

		var label := Label.new()
		UiType.apply(label, UiType.TAB_BUTTON)
		label.text = LABELS[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", button.get_theme_font("font"))
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", UiPalette.TAB_IDLE)
		column.add_child(label)
		_labels.append(label)
	set_active(Tab.HOME)


func _on_tab_pressed(index: int) -> void:
	tab_selected.emit(index)


## Dışarıdan sekme değiştirmek için (örn. Ana Sayfa'daki "Oyna" butonu
## haritaya götürüyor). Sinyal YAYMAZ — sonsuz döngü olmasın.
##
## Diğer butonlar AÇIKÇA kapatılıyor: set_pressed_no_signal() ButtonGroup'un
## dışlama mantığını tetiklemiyor, sadece o butonun durumunu değiştiriyor.
func set_active(tab: int) -> void:
	if tab < 0 or tab >= _buttons.size():
		return
	var changed: bool = tab != _active
	_active = tab
	for i in _buttons.size():
		var on: bool = i == tab
		_buttons[i].set_pressed_no_signal(on)
		_icons[i].self_modulate = UiPalette.TAB_ACTIVE if on else UiPalette.TAB_IDLE
		_labels[i].add_theme_color_override("font_color",
			UiPalette.TAB_ACTIVE if on else UiPalette.TAB_IDLE)
		_pills[i].self_modulate.a = 1.0 if on else 0.0
	if changed:
		# İkon pop + pill'in belirmesi: seçim geçişi hissedilsin.
		UiMotion.pop(_icons[tab], 1.18)


static func _pill_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiPalette.TAB_ACTIVE.r, UiPalette.TAB_ACTIVE.g,
		UiPalette.TAB_ACTIVE.b, 0.16)
	box.set_corner_radius_all(22)
	box.content_margin_left = 4.0
	box.content_margin_right = 4.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	return box
