class_name CandyButton
extends RefCounted
## Owner'ın candy buton asset'lerinin TEK bağlanma noktası (M8.5-08).
##
## Neden global tema değil: `assets/visual/ui_theme.tres` bütün ekranlarda
## (ana sayfa, harita, koleksiyon, mağaza) ortak. Bu turun kapsamı yalnız
## OYUN EKRANI ve onun iki penceresi; temayı değiştirmek kapsam dışı üç
## ekranı da sessizce yeniden tasarlardı. O yüzden candy butonlar buradan
## TEK TEK uygulanıyor.
##
## Doku türetme kuralı (bkz. PROJECT_STATUS §4.11): kaynak pill gövdelerinin
## oranı birbirinden farklıydı (normal 2.45 / seçili 2.30 / pasif 3.01).
## Aynı dikdörtgene gerilselerdi uçlardaki yıldızlar durum değiştikçe şekil
## değiştirirdi. Türetmede sürekli bir sütun haritası kullanıldı: ölçek
## yıldız kapaklarında tam 1:1, farkın tamamı pill'in düz orta şeridinde
## soğuruluyor, ikisi arasında yumuşak geçiyor (sert kesim görünür bir dikey
## Mach bandı bırakıyordu). Üç durum aynı orana getirildiği için runtime'da
## 9-patch'e gerek YOK, düz germe doğru sonucu veriyor.

## Güç çubuğu butonu — 172x86 (oran 2.0), dokular buna göre türetildi.
const POWER_NORMAL: Texture2D = preload("res://assets/visual/ui/power_button_normal.png")
const POWER_SELECTED: Texture2D = preload("res://assets/visual/ui/power_button_selected.png")
const POWER_DISABLED: Texture2D = preload("res://assets/visual/ui/power_button_disabled.png")

## Pencere CTA'sı — geniş pill, 496x96 (oran 5.17).
const CTA_NORMAL: Texture2D = preload("res://assets/visual/ui/cta_button_normal.png")
const CTA_DISABLED: Texture2D = preload("res://assets/visual/ui/cta_button_disabled.png")

## Pencere CTA'larının ortak yüksekliği. Tek bir geniş doku yetsin diye
## bütün CTA'lar aynı ölçüde: ayrı ayrı yükseklikleri olsaydı her biri için
## ayrı oranda doku türetmek ya da yıldızları ezmek gerekirdi.
const CTA_HEIGHT: float = 96.0

## Basılı durumun karartması. Ayrı bir "pressed" asset'i YOK; aynı doku
## hafifçe karartılıyor.
const PRESSED_TINT: Color = Color(0.82, 0.86, 0.90)
## Stok 0 gücün pill rengi. Solukluk YALNIZCA dokuya uygulanıyor — butonun
## tamamı `modulate` ile soldurulduğunda yazı da soluyordu ve "Bomba ×0"
## okunmaz hâle geliyordu (ölçüldü, ilk denemede böyle oldu).
const EMPTY_TINT: Color = Color(0.74, 0.78, 0.86, 0.62)

## Candy pill açık camgöbeği; üstünde koyu lacivert yazı okunuyor.
const FONT_COLOR: Color = Color(0.07, 0.20, 0.30)
## Pasif buton yazısı. Tema varsayılanı (açık gri) gri pill'in üstünde
## KAYBOLUYORDU; GAME_DESIGN §5.7.3 pasif CTA'nın sebebiyle birlikte
## okunur kalmasını istiyor. Koyu arduvaz: belirgin şekilde soluk ama
## hâlâ okunabilir.
const FONT_DISABLED_COLOR: Color = Color(0.28, 0.32, 0.40)


## Dokuyu kontrolün dikdörtgenine geren stylebox. `texture_margin` bilerek
## SIFIR: dokular zaten hedef orana türetildi (bkz. dosya başlığı), 9-patch
## eklenirse kapaklar doku pikseli olarak sabit kalır ve küçük butonda
## ortayı bastırırdı.
static func _box(texture: Texture2D, left: float, right: float,
		top: float, bottom: float, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.content_margin_left = left
	box.content_margin_right = right
	box.content_margin_top = top
	box.content_margin_bottom = bottom
	box.modulate_color = tint
	return box


## Pencere CTA'sı (Devam Et / Reklam İzle / Hamurla Al / Kapat / Bitir).
## Yatay içerik payı yıldız süslerini boşta bırakacak kadar geniş: yazı
## yıldızların üstüne binmesin.
static func style_cta(button: Button) -> void:
	button.custom_minimum_size.y = CTA_HEIGHT
	button.add_theme_stylebox_override("normal", _box(CTA_NORMAL, 58, 58, 8, 12))
	button.add_theme_stylebox_override("hover", _box(CTA_NORMAL, 58, 58, 8, 12,
		Color(1.10, 1.10, 1.10)))
	button.add_theme_stylebox_override("pressed", _box(CTA_NORMAL, 58, 58, 12, 8,
		PRESSED_TINT))
	button.add_theme_stylebox_override("disabled", _box(CTA_DISABLED, 58, 58, 8, 12))
	button.add_theme_color_override("font_color", FONT_COLOR)
	button.add_theme_color_override("font_hover_color", FONT_COLOR)
	button.add_theme_color_override("font_pressed_color", FONT_COLOR)
	button.add_theme_color_override("font_disabled_color", FONT_DISABLED_COLOR)


## Güç çubuğu butonu.
##
## `armed` = bu güç seçili (hedefleme açık). Seçili durum ayrı bir asset:
## parlayan yeşil kenar + kıvılcımlar. Eski yeşil çerçeve `StyleBoxFlat`'ı
## yerine geçiyor — iki vurgu üst üste binmesin diye.
##
## `empty` = stok 0. Buton hâlâ BASILABİLİR (refill akışı buna bağlı), o
## yüzden `disabled` durumu DEĞİL: yalnızca pill soluklaşıyor, yazı tam
## opak kalıyor.
static func style_power(button: Button, armed: bool, empty: bool = false) -> void:
	var face: Texture2D = POWER_SELECTED if armed else POWER_NORMAL
	var tint: Color = EMPTY_TINT if empty else Color.WHITE
	button.add_theme_stylebox_override("normal", _box(face, 30, 30, 6, 8, tint))
	button.add_theme_stylebox_override("hover", _box(face, 30, 30, 6, 8,
		tint * Color(1.08, 1.08, 1.08, 1.0)))
	button.add_theme_stylebox_override("pressed", _box(face, 30, 30, 8, 6,
		tint * PRESSED_TINT))
	button.add_theme_stylebox_override("disabled", _box(POWER_DISABLED, 30, 30, 6, 8))
