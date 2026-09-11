extends CanvasLayer
## Alt sekme çubuğu: Ana Sayfa / Harita / Koleksiyon / Mağaza.
## Oyun sırasında ve round sonucu ekranında gizleniyor (main.gd yönetiyor).

signal tab_selected(tab: int)

enum Tab { HOME, MAP, COLLECTION, SHOP }

const LABELS: Array[String] = ["Ana Sayfa", "Harita", "Koleksiyon", "Mağaza"]

var _buttons: Array[Button] = []

@onready var _row: HBoxContainer = $Anchor/Row


func _ready() -> void:
	var group := ButtonGroup.new()
	for i in LABELS.size():
		var button := Button.new()
		# Sekme yazisi Nunito Bold: dort sekme adi ("Koleksiyon" 10 karakter)
		# 720 px'i dortte bolen bir seride Baloo ile tasiyor.
		UiType.apply(button, UiType.TAB_BUTTON)
		button.text = LABELS[i]
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 76)
		# Aktif sekme "basılı" görünür — tema zaten pressed stilini tanımlıyor.
		button.pressed.connect(_on_tab_pressed.bind(i))
		_row.add_child(button)
		_buttons.append(button)
	set_active(Tab.HOME)


func _on_tab_pressed(index: int) -> void:
	tab_selected.emit(index)


## Dışarıdan sekme değiştirmek için (örn. Ana Sayfa'daki "Oyna" butonu
## haritaya götürüyor). Sinyal YAYMAZ — sonsuz döngü olmasın.
##
## Diğer butonlar AÇIKÇA kapatılıyor: set_pressed_no_signal() ButtonGroup'un
## dışlama mantığını tetiklemiyor, sadece o butonun durumunu değiştiriyor.
## Yalnızca hedefi basılı yapmak vurguların birikmesine yol açıyordu.
func set_active(tab: int) -> void:
	if tab < 0 or tab >= _buttons.size():
		return
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(i == tab)
