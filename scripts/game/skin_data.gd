class_name SkinData
extends Resource
## Kozmetik dumpling skin'inin KATALOG tanımı (GAME_DESIGN.md §5.2):
## kimlik, ad, rarity, koleksiyon/mağaza önizleme görseli ve gameplay render
## profili. Oyuncuya özgü durum (sahip mi, takılı mı, fiyat) burada DEĞİL —
## o bilgi `SkinEntry` ile birleştiriliyor.
##
## İki görsel katman (M8.5-14):
##   preview_texture — owner'ın FİNAL önizleme sanatı
##                     (assets/visual/skins/previews/skin_<rarity>_<ad>.png).
##                     Koleksiyon kartı, vitrin ve mağaza satırı bunu çizer.
##   gameplay profili — 8 tier sprite'ının GÖVDESİNİ yeniden boyayan/desenleyen
##                     shader parametreleri (assets/visual/skins/skin_body.gdshader,
##                     uygulayan: scripts/game/skin_visual.gd). Tier siluetleri,
##                     yüzler ve aksesuarlar korunur; skin yalnızca hamurun
##                     rengi + malzemesi + deseni. 20×8 sprite ÜRETİLMİYOR.
##
## Profil alanlarının hepsi veri: yeni skin = yeni .tres, kod değişmez.
## Tüm 20 skin: tools/make_skin_resources.py tablosundan üretildi.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

## Desen ailesi — skin_body.gdshader `pattern_type` ile aynı sıra.
enum Pattern { NONE, SPECKLE, FLECK, RING, MARBLE, SWIRL, CRYSTAL, STREAK, WAVE, IRIDESCENT, METAL }

@export var id: StringName = &""
@export var display_name: String = ""
@export var rarity: Rarity = Rarity.COMMON
## Final koleksiyon/mağaza önizlemesi. null olursa SkinSwatch orijinal
## dumpling + gameplay profiliyle türetir (güvenli fallback, prod'da olmamalı).
@export var preview_texture: Texture2D = null

@export_group("Gameplay render")
## Hamur gövdesinin ana rengi (orta ton). Kart/renk özeti de bunu kullanır.
@export var body_color: Color = Color(0.96, 0.92, 0.84)
## Gölge tonu (sprite'ın koyu bölgeleri buna gider).
@export var shade_color: Color = Color(0.72, 0.62, 0.50)
## Spekuler parlama tonu.
@export var highlight_color: Color = Color.WHITE
## Skin renginin tier'ın kendi gövde rengine karışma oranı (M8.5-17).
## 0 = tier olduğu gibi (Sade), 1 = eski tam recolor. Tier rengi her zaman
## birincil çapa; rarity varsayılanları Common 0.30 / Rare 0.35 / Epic 0.40 /
## Legendary 0.50 (tools/make_skin_resources.py). Sekiz tier her skinde
## ayırt edilebilir kalmalı.
@export_range(0.0, 1.0) var tint_strength: float = 0.35
@export var pattern: Pattern = Pattern.NONE
@export var pattern_color: Color = Color(0.3, 0.2, 0.1)
@export var pattern_color2: Color = Color.WHITE
## 0..1: hücrelerin dolu olma olasılığı.
@export_range(0.0, 1.0) var pattern_density: float = 0.5
## Hücre sayısı çarpanı (1 = 9 hücre / doku genişliği).
@export_range(0.2, 4.0) var pattern_scale: float = 1.0
@export_range(0.0, 1.0) var pattern_strength: float = 0.8
## Rarity malzemesi: gloss (parlama), pearl (sedef), sparkle (animasyonlu glint).
@export_range(0.0, 1.0) var gloss: float = 0.0
@export_range(0.0, 1.0) var pearl: float = 0.0
@export_range(0.0, 1.0) var sparkle: float = 0.0
## Legendary aura rengi; alfa 0 = aura yok.
@export var aura_color: Color = Color(1, 1, 1, 0)
@export_range(0.0, 3.0) var anim_speed: float = 1.0


## Gameplay'de hiçbir şey değiştirmeyen profil (Sade): tint 0, desen yok,
## malzeme yok. SkinVisual bu durumda materyal takmaz — tier sprite'ı
## orijinal renkleriyle çizilir, "varsayılan" ile birebir aynı görünür.
func is_baseline() -> bool:
	return tint_strength <= 0.0 and pattern == Pattern.NONE 		and gloss <= 0.0 and pearl <= 0.0 and sparkle <= 0.0


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
