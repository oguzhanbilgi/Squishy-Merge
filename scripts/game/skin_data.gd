class_name SkinData
extends Resource
## Kozmetik dumpling skin'inin KATALOG tanımı (GAME_DESIGN.md §5.2):
## kimlik, ad, rarity ve görsel referansları. Oyuncuya özgü durum (sahip mi,
## takılı mı, fiyat) burada DEĞİL — o bilgi `SkinEntry` ile birleştiriliyor.
##
## Görsel alanlar:
##   tint             — placeholder renk kaydırması (SkinVisual, hue shift).
##                      Sanat gelene kadar hem oyunda hem önizlemede bu kullanılır.
##   preview_texture  — koleksiyon/mağaza önizlemesi için hazır görsel.
##                      BOŞSA önizleme orijinal dumpling + SkinVisual ile
##                      türetilir (yani oyunda ne görünüyorsa o). Owner'ın
##                      skin başına önizleme görseli geldiğinde yalnızca bu
##                      alan doldurulur; kod değişmez.
##
## ⚠️ STATUS: functional equip complete / final skin art pending.
## 20 skin'in `tint` değerleri prosedürel placeholder (bkz. SKIN_ART_AUDIT.md).

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

@export var id: StringName = &""
@export var display_name: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var tint: Color = Color.WHITE
## Opsiyonel hazır önizleme görseli. null = orijinal dumpling + tint.
@export var preview_texture: Texture2D = null


static func rarity_name(value: Rarity) -> String:
	match value:
		Rarity.COMMON: return "Common"
		Rarity.RARE: return "Rare"
		Rarity.EPIC: return "Epic"
		Rarity.LEGENDARY: return "Legendary"
	return "?"


## Sandık/kart rengi — rarity'yi bir bakışta ayırt etmek için.
static func rarity_color(value: Rarity) -> Color:
	match value:
		Rarity.COMMON: return Color("9aa0a6")
		Rarity.RARE: return Color("4c9be8")
		Rarity.EPIC: return Color("a55cd6")
		Rarity.LEGENDARY: return Color("f0a92e")
	return Color.WHITE
