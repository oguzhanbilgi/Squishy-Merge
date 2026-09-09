extends Control
## Oyun içi güç çubuğu (GAME_DESIGN.md §10): dört güç, stok sayısı, seçili
## durumu.
##
## ⚠️ İKONLAR PLACEHOLDER. Final power-up art'ı yok (M8.5-03); butonlar
## geçici metin işaretleri kullanıyor. Mevcut UI temasının buton stilini
## kullanıyorlar ama final asset olarak işaretlenmemeliler.
##
## KONUM NOTU: bu çubuk bilerek ekranın en altına sabitlenmedi. Alt safe-area
## ileride AdMob banner'ına ayrılacak (PROJECT_CONTEXT non-goal'ları: reklam
## v1'de YOK ama yer şimdiden bloke edilmemeli). Çubuk kabın ağzının üstünde,
## HUD yazılarının altında duruyor; oyun alanını kapatmıyor.

signal power_pressed(type: int)

const BUTTON_SIZE: Vector2 = Vector2(96.0, 64.0)
## Seçili gücün çerçeve rengi — koleksiyondaki "TAKILI" ile aynı dil.
const ARMED_COLOR: Color = Color("6ddc8b")
## Stok 0'da buton soluklaşıyor ama TIKLANABİLİR kalıyor: basınca
## refill_requested yayılsın (ileride reklam/Hamur akışı buraya bağlanacak).
const EMPTY_ALPHA: float = 0.45

var _buttons: Dictionary = {}
var _armed: int = PowerUpController.ARMED_NONE

@onready var _row: HBoxContainer = $Row


func _ready() -> void:
	for type in PowerUp.all():
		var button := _make_button(type)
		_row.add_child(button)
		_buttons[int(type)] = button
	refresh()


func _make_button(type: PowerUp.Type) -> Button:
	var button := Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = false
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.add_theme_font_size_override("font_size", 15)
	button.tooltip_text = PowerUp.display_name(type)
	button.pressed.connect(func() -> void: power_pressed.emit(int(type)))
	return button


## Stok ve seçili durumunu tazeler. Her round başında ve her kullanımda
## çağrılıyor — sayılar anında güncellensin.
func refresh() -> void:
	for type in PowerUp.all():
		var button: Button = _buttons[int(type)]
		var count: int = SaveManager.powerup_count(type)
		button.text = "%s\n%s ×%d" % [
			PowerUp.glyph(type), PowerUp.display_name(type), count]
		button.modulate.a = 1.0 if count > 0 else EMPTY_ALPHA
		_style_armed(button, _armed == int(type))


func set_armed(type: int) -> void:
	_armed = type
	for key: int in _buttons:
		_style_armed(_buttons[key], key == type)


func _style_armed(button: Button, armed: bool) -> void:
	if armed:
		button.add_theme_stylebox_override("normal", _armed_stylebox())
		button.add_theme_stylebox_override("hover", _armed_stylebox())
	else:
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_stylebox_override("hover")


static func _armed_stylebox() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(ARMED_COLOR.r, ARMED_COLOR.g, ARMED_COLOR.b, 0.22)
	box.border_color = ARMED_COLOR
	box.set_border_width_all(3)
	box.set_corner_radius_all(10)
	return box
