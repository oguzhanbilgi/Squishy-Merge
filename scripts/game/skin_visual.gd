class_name SkinVisual
extends RefCounted
## Skin'in dumpling sprite'ına NASIL uygulandığı — tek ve DEĞİŞTİRİLEBİLİR
## katman.
##
## Bu dosya bilinçli olarak yalıtılmış: save/equip sistemi, koleksiyon UI'ı ve
## gameplay hiçbir yerde "skin nasıl görünür" bilgisine sahip değil, hepsi
## buraya `apply()` diyor. Sonraki sanat turunda skin başına ayrı sprite,
## desen atlası ya da başka bir teknik gelirse **yalnızca bu dosya** değişir;
## kayıt formatı, equip akışı ve oyun kodu aynen kalır.
##
## ⚠️ ŞU ANKİ HÂL BİR ÖNİZLEME, FİNAL SANAT DEĞİL.
## `resources/skins/*.tres` içindeki `tint` değerleri prosedürel üretilmiş
## placeholder'lar (20 skin boyunca sabit 49.3° hue spirali) ve yiyecek
## isimleriyle hiç örtüşmüyorlar — "Kırmızı Biber" sarı-yeşil, "Havuçlu"
## nane yeşili. Bkz. SKIN_ART_AUDIT.md. O yüzden burada renk körlemesine
## uygulanmıyor, kontrollü bir kaydırma yapılıyor.

const SHADER: Shader = preload("res://assets/visual/skin_tint.gdshader")

## Renk kaydırmasının gücü. 1.0 sprite'ı tamamen skin rengine boyardı ve
## tier'lar yalnızca boyutla ayırt edilir hâle gelirdi; 0.45 skin'i belirgin
## kılarken tier paletini de okunur bırakıyor (ekran görüntüsüyle seçildi).
const STRENGTH: float = 0.45

## Shader materyali sprite başına yeniden yaratılmıyor: aynı skin'i kullanan
## bütün parçalar aynı materyali paylaşabilir. Anahtar = skin id.
static var _materials: Dictionary = {}


## Sprite'a skin görünümünü uygular. `skin` null ise varsayılan/orijinal
## görünüme döner (materyal tamamen kaldırılır — shader hiç çalışmaz).
static func apply(sprite: Sprite2D, skin: SkinData) -> void:
	if sprite == null:
		return
	if skin == null:
		clear(sprite)
		return
	sprite.material = _material_for(skin)


## Varsayılan görünüm: materyal yok, sprite kendi renkleriyle çizilir.
static func clear(sprite: Sprite2D) -> void:
	if sprite == null:
		return
	sprite.material = null


static func _material_for(skin: SkinData) -> ShaderMaterial:
	var key: String = String(skin.id)
	var cached: Variant = _materials.get(key)
	if cached is ShaderMaterial:
		return cached
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("skin_tint", skin.tint)
	material.set_shader_parameter("strength", STRENGTH)
	_materials[key] = material
	return material


## Skin verisi çalışma anında değişirse (dev aracı / editör) önbelleği boşalt.
static func invalidate_cache() -> void:
	_materials.clear()
