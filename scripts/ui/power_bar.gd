extends Control
## Oyun içi güç çubuğu (GAME_DESIGN.md §10): dört güç, stok sayısı, seçili
## durumu.
##
## M8.5-08: geçici metin işaretleri (`PowerUp.GLYPHS`) ve düz çeviri
## kutucukları KALDIRILDI. Butonlar owner'ın candy pill asset'lerini,
## ikonlar `PowerUp.ICON_PATHS`taki gerçek Texture2D'leri kullanıyor.
##
## Buton içeriği neden `Button.icon` değil de elle kurulmuş bir VBox:
## Godot'un Button'ı ikonu yazının SOLUNA koyuyor; 172 px genişlikte
## "ikon + Temizleyici ×9" tek satıra sığmıyordu. İkon üstte, isim + stok
## altta olunca üçü de okunuyor. VBox `MOUSE_FILTER_IGNORE` — dokunuş
## butona geçsin.
##
## KONUM NOTU: bu çubuk bilerek ekranın en altına sabitlenmedi. Alt safe-area
## ileride AdMob banner'ına ayrılacak (PROJECT_CONTEXT non-goal'ları: reklam
## v1'de YOK ama yer şimdiden bloke edilmemeli). Çubuk kabın ağzının üstünde,
## HUD yazılarının altında duruyor; oyun alanını kapatmıyor.

signal power_pressed(type: int)

## Buton ölçüsü candy pill'in DOĞAL oranına yakın seçildi (172/86 = 2.0;
## kaynak pill'ler 2.30-3.01). Kareye yakın bir buton pill'i ezip köşe
## yarıçaplarını bozuyordu. Dörtlü sıra + 3x8 boşluk = 712 px, 720 px'lik
## viewport'a sığıyor.
const BUTTON_SIZE: Vector2 = Vector2(172.0, 86.0)
## İkon kutusu. Pill'in düz orta alanına sığacak kadar büyük, altındaki
## yazıya yer bırakacak kadar küçük.
const ICON_SIZE: Vector2 = Vector2(40.0, 40.0)
## İçeriğin pill'in uçlarındaki yıldız süslerinden uzak durması için yatay
## pay. Yıldızlar butonun dış %16'sını kaplıyor (ölçüldü); 30 px onların
## dışında kalıyor ve ortada 112 px bırakıyor.
const CONTENT_INSET: float = 30.0
## İsim + stok satırı. Rol: `UiType.STAT` (Nunito Bold).
##
## Boyut rolün varsayılanını (20) EZİYOR: bu satır bir liste öğesi değil,
## 172x86'lık pill'in içinde ikonun altındaki dar şerit ve iki yanda 30'ar
## px yıldız payı düşünce 112 px kalıyor. Ölçüm (`tools/type_probe.gd`, en
## uzun kombinasyon "Temizleyici ×99"): 15 px'te 107 px ile sığıyor,
## 16 px'te 114 px ile taşıyor. Yani 15 sığan en büyük değer.
##
## NOT — Baloo burada GENİŞLİK yüzünden elenmedi: aynı metin Baloo 2 Bold'da
## biraz daha DAR çıkıyor (15 px'te 103 px). Eleme gerekçesi tipografi
## sistemi: bu satır bir başlık değil, stok VERİSİ; sayı ve kısa etiket
## Nunito'nun işi (bkz. scripts/ui/ui_type.gd).
const LABEL_FONT_SIZE: int = 15

## Stok 0'da ikonun opaklığı. Butonun TAMAMI soldurulmuyor — yazı da
## solunca "Bomba ×0" okunmaz oluyordu. Pill'i `CandyButton.EMPTY_TINT`
## soluklaştırıyor, ikon burada, yazı ise TAM OPAK kalıyor.
## Buton stok 0'da da TIKLANABİLİR: basınca refill akışı açılıyor.
const EMPTY_ICON_ALPHA: float = 0.55
## Stok 0 sayısının rengi. Soluk pill üstünde okunan koyu bir kırmızı —
## "bu güç bitti" mesajını solukluktan bağımsız olarak da veriyor.
const EMPTY_TEXT_COLOR: Color = Color(0.56, 0.11, 0.20)

## Çubuk tümden kapalıyken (round bitti, ya da devam teklifi açık) butonlar
## `disabled` ve bu opaklıkta. Stok-0 solukluğundan AYRI bir durum: orada
## buton hâlâ basılabilir (refill sinyali için), burada hiç basılamaz.
const DISABLED_ALPHA: float = 0.55

## Koyu yazının açık camgöbeği pill üstünde kenarını netleştiren ince
## açık hâle. Pill'in kendi gölgeleri yazıyı yer yer yutuyordu.
const LABEL_SHADOW: Color = Color(1, 1, 1, 0.7)
## Hâlenin kalınlığı. 3'ten 2'ye indi (M8.5-09): Nunito'nun ince ve düzgün
## konturunda 3 px hâle harfleri şişirip bulanıklaştırıyordu.
const LABEL_OUTLINE_SIZE: int = 2

## İçeriğin pill'in DİKEY olarak neresine oturduğu. Buton dokusunun alt
## kısmı düşen gölge; kutu tam dikdörtgene yayılınca yazı pill'in alt
## kenarına yapışıyordu (çekimle yakalandı). Üstten biraz, alttan daha çok
## içeri alınıyor.
const CONTENT_TOP_INSET: float = 2.0
const CONTENT_BOTTOM_INSET: float = 14.0

var _buttons: Dictionary = {}
var _labels: Dictionary = {}
var _icons: Dictionary = {}
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
	button.tooltip_text = PowerUp.display_name(type)
	CandyButton.style_power(button, false)

	# İçerik butonun ÜSTÜNE seriliyor; dokunuşu yutmasın diye IGNORE.
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = CONTENT_INSET
	box.offset_right = -CONTENT_INSET
	box.offset_top = CONTENT_TOP_INSET
	box.offset_bottom = -CONTENT_BOTTOM_INSET
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	button.add_child(box)

	var icon := TextureRect.new()
	icon.texture = PowerUp.icon(type)
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var label := Label.new()
	UiType.apply(label, UiType.STAT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	label.add_theme_color_override("font_color", CandyButton.FONT_COLOR)
	label.add_theme_color_override("font_outline_color", LABEL_SHADOW)
	label.add_theme_constant_override("outline_size", LABEL_OUTLINE_SIZE)
	box.add_child(label)

	_icons[int(type)] = icon
	_labels[int(type)] = label
	button.pressed.connect(func() -> void: power_pressed.emit(int(type)))
	return button


## Stok ve seçili durumunu tazeler. Her round başında ve her kullanımda
## çağrılıyor — sayılar anında güncellensin.
func refresh() -> void:
	for type in PowerUp.all():
		var button: Button = _buttons[int(type)]
		var label: Label = _labels[int(type)]
		var icon: TextureRect = _icons[int(type)]
		var count: int = SaveManager.powerup_count(type)
		var empty: bool = count <= 0
		label.text = "%s ×%d" % [PowerUp.display_name(type), count]
		button.disabled = not _enabled
		# Çubuk tümden kapalıyken buton `disabled` stylebox'ına (gri pill)
		# geçiyor ve tamamı soluyor. Stok 0 bundan AYRI: orada yalnızca pill
		# ve ikon soluyor, yazı okunur kalıyor.
		button.modulate.a = DISABLED_ALPHA if not _enabled else 1.0
		icon.modulate.a = EMPTY_ICON_ALPHA if empty else 1.0
		label.add_theme_color_override("font_color",
			EMPTY_TEXT_COLOR if empty else CandyButton.FONT_COLOR)
		_style_armed(button, _armed == int(type))


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
		_style_armed(_buttons[key], key == type)


## Seçili vurgu artık ayrı bir asset (parlayan yeşil kenar + kıvılcım).
## Eski `StyleBoxFlat` çerçevesinin yerini aldı; ikisi üst üste binmiyor.
func _style_armed(button: Button, armed: bool) -> void:
	var type: int = _buttons.find_key(button)
	var empty: bool = SaveManager.powerup_count(type as PowerUp.Type) <= 0
	CandyButton.style_power(button, armed, empty)
