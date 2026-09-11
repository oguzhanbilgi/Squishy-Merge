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


## --- İki satırlı pencere CTA'sı (M8.5-09) ---
##
## Üst satır eylem ("HAMURLA AL"), alt satır bedel/ödül ("120 Hamur").
## GAME_DESIGN §5.7.3'ün istediği hiyerarşi bu: oyuncu önce ne yapacağını,
## sonra ne ödeyeceğini okusun.
##
## Neden `button.text` DEĞİL: Godot'un Button'ı tek font kullanıyor. İki
## satır aynı ağırlıkta çıkıyor ve "HAMURLA AL" ile "120 Hamur" görsel
## olarak eşitleniyordu. İçerik, butonun üstüne serilen bir VBox — güç
## çubuğundaki desenin aynısı, dokunuş `MOUSE_FILTER_IGNORE` ile butona
## geçiyor.
##
## DİKKAT: Godot'un `font_disabled_color`u yalnızca `button.text`e uygulanır,
## çocuk Label'lara DEĞİL. Butonun `disabled` durumu değiştiğinde
## `refresh_cta()` çağrılmalı — yoksa pasif CTA'nın yazısı tam kontrastta
## kalır ve buton basılabilir görünür.
const CTA_TITLE_FONT_SIZE: int = 26
const CTA_SUBTITLE_FONT_SIZE: int = 17
## Alt satırın normal durumdaki tonu: başlıkla aynı koyu lacivertin biraz
## açığı. Ayrı bir renk değil, aynı rengin zayıflatılmışı — iki satır tek
## bir blok gibi okunsun.
const CTA_SUBTITLE_ALPHA: float = 0.78

const _META_TITLE: StringName = &"cta_title"
const _META_SUBTITLE: StringName = &"cta_subtitle"


## CTA'nın iki satırını kurar/günceller. `subtitle` boşsa alt satır gizlenir
## ve başlık tek başına dikey ortalanır.
static func set_cta_text(button: Button, title: String, subtitle: String = "") -> void:
	# Yazı `button.text`ten TAMAMEN alınıyor: ikisi birden dolu olursa
	# tema yazısı overlay'in altında ikinci kez çizilir.
	button.text = ""
	var box: VBoxContainer = button.get_node_or_null("CtaText") as VBoxContainer
	if box == null:
		box = VBoxContainer.new()
		box.name = "CtaText"
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 0)
		button.add_child(box)

		var title_label := Label.new()
		UiType.apply(title_label, UiType.CARD_TITLE)
		title_label.add_theme_font_size_override("font_size", CTA_TITLE_FONT_SIZE)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(title_label)
		button.set_meta(_META_TITLE, title_label)

		var subtitle_label := Label.new()
		UiType.apply(subtitle_label, UiType.STAT)
		subtitle_label.add_theme_font_size_override("font_size", CTA_SUBTITLE_FONT_SIZE)
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(subtitle_label)
		button.set_meta(_META_SUBTITLE, subtitle_label)

	(button.get_meta(_META_TITLE) as Label).text = title
	var sub_label: Label = button.get_meta(_META_SUBTITLE)
	sub_label.text = subtitle
	sub_label.visible = not subtitle.is_empty()
	refresh_cta(button)


## Pasif/aktif kontrastını tazeler. `button.disabled` değiştikten SONRA
## çağrılmalı.
static func refresh_cta(button: Button) -> void:
	if not button.has_meta(_META_TITLE):
		return
	var base: Color = FONT_DISABLED_COLOR if button.disabled else FONT_COLOR
	var title_label: Label = button.get_meta(_META_TITLE)
	title_label.add_theme_color_override("font_color", base)
	var sub_label: Label = button.get_meta(_META_SUBTITLE)
	sub_label.add_theme_color_override("font_color",
		Color(base.r, base.g, base.b, CTA_SUBTITLE_ALPHA))


## CTA'nın oyuncuya görünen yazısı, tek string olarak. Test/QA için:
## `button.text` artık boş, doğrulama bu iki satırı okumalı.
static func cta_text(button: Button) -> String:
	if not button.has_meta(_META_TITLE):
		return button.text
	var sub_label: Label = button.get_meta(_META_SUBTITLE)
	var title: String = (button.get_meta(_META_TITLE) as Label).text
	return title if sub_label.text.is_empty() else "%s
%s" % [title, sub_label.text]


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
