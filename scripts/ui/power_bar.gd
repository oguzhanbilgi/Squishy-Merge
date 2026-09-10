extends Control
## Oyun içi güç çubuğu (GAME_DESIGN.md §10): dört güç, stok sayısı, seçili
## durumu.
##
## ⚠️ İKONLAR PLACEHOLDER. Final power-up art'ı YOK; butonlar geçici metin
## işaretleri (`PowerUp.GLYPHS`) kullanıyor.
##
## MİMARİ HAZIR (M8.5-07): `PowerUp.ICON_PATHS` doldurulduğu anda butonlar
## gerçek `Texture2D` ikona geçer, burada kod değişikliği GEREKMEZ. Dört
## gücün ayırt edilmesi şimdilik isim + `PowerUp.ACCENTS` vurgu rengiyle
## sağlanıyor.
##
## KONUM NOTU: bu çubuk bilerek ekranın en altına sabitlenmedi. Alt safe-area
## ileride AdMob banner'ına ayrılacak (PROJECT_CONTEXT non-goal'ları: reklam
## v1'de YOK ama yer şimdiden bloke edilmemeli). Çubuk kabın ağzının üstünde,
## HUD yazılarının altında duruyor; oyun alanını kapatmıyor.

signal power_pressed(type: int)

const BUTTON_SIZE: Vector2 = Vector2(96.0, 68.0)
## Gerçek ikon geldiğinde buton içindeki ikon kutusunun genişliği.
const ICON_MAX_WIDTH: int = 34
## Seçili gücün çerçeve rengi — koleksiyondaki "TAKILI" ile aynı dil.
const ARMED_COLOR: Color = Color("6ddc8b")
## Stok 0'da buton soluklaşıyor ama TIKLANABİLİR kalıyor: basınca
## refill_requested yayılsın (ileride reklam/Hamur akışı buraya bağlanacak).
const EMPTY_ALPHA: float = 0.45

## Çubuk tümden kapalıyken (round bitti, ya da devam teklifi açık) butonlar
## `disabled` ve bu opaklıkta. Stok-0 solukluğundan AYRI bir durum: orada
## buton hâlâ basılabilir (refill sinyali için), burada hiç basılamaz.
const DISABLED_ALPHA: float = 0.3

var _buttons: Dictionary = {}
var _armed: int = PowerUpController.ARMED_NONE
var _enabled: bool = true

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
	# Gerçek ikon varsa Button'ın kendi `icon` yuvasına giriyor; yoksa
	# `refresh()` metin işaretine düşüyor. İkon dosyaları eklendiğinde
	# burada başka değişiklik gerekmiyor.
	var texture: Texture2D = PowerUp.icon(type)
	if texture != null:
		button.icon = texture
		button.expand_icon = true
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.add_theme_constant_override("icon_max_width", ICON_MAX_WIDTH)
	button.pressed.connect(func() -> void: power_pressed.emit(int(type)))
	return button


## Stok ve seçili durumunu tazeler. Her round başında ve her kullanımda
## çağrılıyor — sayılar anında güncellensin.
func refresh() -> void:
	for type in PowerUp.all():
		var button: Button = _buttons[int(type)]
		var count: int = SaveManager.powerup_count(type)
		# Gerçek ikon varsa metin işareti satırı hiç yazılmıyor.
		if button.icon != null:
			button.text = "%s ×%d" % [PowerUp.display_name(type), count]
		else:
			button.text = "%s\n%s ×%d" % [
				PowerUp.glyph(type), PowerUp.display_name(type), count]
		button.disabled = not _enabled
		if not _enabled:
			button.modulate.a = DISABLED_ALPHA
		else:
			button.modulate.a = 1.0 if count > 0 else EMPTY_ALPHA
		_style_armed(button, _armed == int(type), type)


## Çubuğu tümden açar/kapatır (M8.5-04). Kapalıyken hiçbir güç kullanılamaz
## ve stok tüketilemez; stoklar olduğu gibi durur, tekrar açılınca kaldığı
## yerden devam eder.
func set_enabled(enabled: bool) -> void:
	if enabled == _enabled:
		return
	_enabled = enabled
	refresh()


func set_armed(type: int) -> void:
	_armed = type
	for key: int in _buttons:
		_style_armed(_buttons[key], key == type, key as PowerUp.Type)


func _style_armed(button: Button, armed: bool, type: PowerUp.Type) -> void:
	if armed:
		button.add_theme_stylebox_override("normal", _armed_stylebox(type))
		button.add_theme_stylebox_override("hover", _armed_stylebox(type))
	else:
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_stylebox_override("hover")


## Seçili çerçeve: ortak yeşil ile gücün kendi vurgu rengi karıştırılıyor.
## Ortak renk "bu seçili" der, vurgu rengi "hangisi seçili" der.
static func _armed_stylebox(type: PowerUp.Type) -> StyleBoxFlat:
	var tint: Color = ARMED_COLOR.lerp(PowerUp.accent(type), 0.55)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(tint.r, tint.g, tint.b, 0.26)
	box.border_color = tint
	box.set_border_width_all(3)
	box.set_corner_radius_all(12)
	return box
