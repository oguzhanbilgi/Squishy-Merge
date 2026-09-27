class_name SkinData
extends Resource
## Koleksiyon parçasının (Squishy) KATALOG tanımı (GAME_DESIGN.md §5.2 / §5.3):
## kimlik, ad, rarity ve owner'ın final önizleme sanatı. Oyuncuya özgü durum
## (sahip mi, vitrinde mi, fiyat) burada DEĞİL — o bilgi `SkinEntry` ile
## birleştiriliyor. Sınıf / dosya adı TARİHSEL ("skin"): eski kayıtlar ve
## .tres yolları bozulmasın diye değişmedi.
##
##   preview_texture — owner'ın FİNAL önizleme sanatı
##                     (assets/visual/skins/previews/skin_<rarity>_<ad>.png).
##                     Koleksiyon kartı, detay, profil vitrini ve mağaza bunu çizer.
##
## TASK/044 (owner kararı): gameplay skinleri EMEKLİ — parçalar oyundaki
## dumpling'lerin görünümünü, fiziği ya da skoru HİÇ değiştirmez. Aşağıdaki
## "Gameplay render (EMEKLİ)" alanları M8.5–M9'un gövde shader profiliydi; mevcut
## 20 .tres değişmeden yüklensin diye VERİ olarak duruyor, hiçbir kod okumuyor.
## Tüm 20 parça: tools/make_skin_resources.py tablosundan üretildi.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

## Desen ailesi (EMEKLİ gameplay profili; .tres uyumluluğu için duruyor).
enum Pattern { NONE, SPECKLE, FLECK, RING, MARBLE, SWIRL, CRYSTAL, STREAK, WAVE, IRIDESCENT, METAL }

@export var id: StringName = &""
@export var display_name: String = ""
@export var rarity: Rarity = Rarity.COMMON
## Final koleksiyon/mağaza/profil önizlemesi (20/20 dolu). null olursa çizenler
## kanonik Squishy'yi gösterir (`SkinEntry.art_texture()`; güvenli fallback,
## prod'da olmamalı).
@export var preview_texture: Texture2D = null

@export_group("Gameplay render (EMEKLİ — TASK/044, okunmaz)")
## Hamur gövdesinin ana rengi (orta ton).
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


## Rarity'nin İÇ adı (İngilizce): tema variation adları (`RarityCommon`…),
## skin id önekleri ve test/araç metinleri buna bağlı — DEĞİŞMEZ. Oyuncuya
## gösterilen ad `rarity_display_name` / `rarity_display_upper`.
static func rarity_name(value: Rarity) -> String:
	match value:
		Rarity.COMMON: return "Common"
		Rarity.RARE: return "Rare"
		Rarity.EPIC: return "Epic"
		Rarity.LEGENDARY: return "Legendary"
	return "?"


## Oyuncuya gösterilen Türkçe rarity adı (M8.6-06; Koleksiyon + Mağaza).
## Kimlik/enum/id değişmedi: yalnızca görüntü eşlemesi.
static func rarity_display_name(value: Rarity) -> String:
	match value:
		Rarity.COMMON: return "Yaygın"
		Rarity.RARE: return "Nadir"
		Rarity.EPIC: return "Epik"
		Rarity.LEGENDARY: return "Efsanevi"
	return "?"


## Büyük harf sürümü etiketler için — Godot `to_upper` Türkçe İ'yi bilmez
## ("Nadir" → "NADIR" olurdu), o yüzden elle.
static func rarity_display_upper(value: Rarity) -> String:
	match value:
		Rarity.COMMON: return "YAYGIN"
		Rarity.RARE: return "NADİR"
		Rarity.EPIC: return "EPİK"
		Rarity.LEGENDARY: return "EFSANEVİ"
	return "?"


## Sandık/kart rengi — rarity'yi bir bakışta ayırt etmek için.
static func rarity_color(value: Rarity) -> Color:
	match value:
		Rarity.COMMON: return Color("9aa0a6")
		Rarity.RARE: return Color("4c9be8")
		Rarity.EPIC: return Color("a55cd6")
		Rarity.LEGENDARY: return Color("f0a92e")
	return Color.WHITE
