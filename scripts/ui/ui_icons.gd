class_name UiIcons
extends RefCounted
## icon_sheet.png'den kesilen HUD ikonlarının tek tanımı (owner asset'i,
## bkz. assets/visual/CREDITS.md).
##
## Bu ikonlar yazının İÇİNE giriyor ("... · Hamur: 315 · ..." gibi birleşik
## satırlarda kelimenin soluna), o yüzden ayrı TextureRect düğümleri yerine
## BBCode `[img]` etiketiyle satır içine gömülüyorlar. Ayrı düğüm olsalardı
## birleşik satırların her birini parçalara bölmek gerekirdi.
##
## Bunu kullanan etiketler `Label` değil `RichTextLabel` olmalı
## (`bbcode_enabled = true`).

const DOUGH: Texture2D = preload("res://assets/visual/ui/icon_dough.png")
const FLAME: Texture2D = preload("res://assets/visual/ui/icon_flame.png")
const FLAG: Texture2D = preload("res://assets/visual/ui/icon_flag.png")
const CROWN: Texture2D = preload("res://assets/visual/ui/icon_crown.png")
const LOCK: Texture2D = preload("res://assets/visual/ui/icon_lock.png")
const STAR_FILLED: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
const STAR_EMPTY: Texture2D = preload("res://assets/visual/ui/icon_star_empty.png")

## Satır içi ikon yüksekliği. Gövde metni 16-22 px; ikon biraz daha büyük
## olunca satırda "rozet" gibi okunuyor, çok büyük olunca satır aralığını
## açıyor. 26 ikisinin arası.
const INLINE_HEIGHT: int = 26


## Satır içine gömülecek ikonun BBCode'u. Genişlik ikonun kendi en/boy
## oranından hesaplanıyor: ikonlar kare değil (bayrak dar, taç geniş) ve
## sadece genişlik verilseydi satırdaki yükseklikleri tutmazdı.
static func inline(texture: Texture2D, height: int = INLINE_HEIGHT) -> String:
	var size: Vector2 = texture.get_size()
	var width: int = maxi(1, int(round(float(height) * size.x / size.y)))
	return "[img=%dx%d]%s[/img]" % [width, height, texture.resource_path]


## İkon + ince boşluk + yazı. Boşluk normal bir space değil: BBCode'da
## `[img]`'den hemen sonra gelen space bazen satır sonunda kırpılıyor.
static func labelled(texture: Texture2D, text: String,
		height: int = INLINE_HEIGHT) -> String:
	return "%s %s" % [inline(texture, height), text]
