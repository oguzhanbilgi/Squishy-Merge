class_name SkinVisual
extends RefCounted
## Skin'in dumpling sprite'ına NASIL uygulandığı — tek ve DEĞİŞTİRİLEBİLİR
## katman. Save/equip sistemi, koleksiyon UI'ı ve gameplay "skin nasıl
## görünür" bilgisine sahip değil; hepsi buraya `apply()` / `clear()` diyor.
##
## M8.5-14 production pipeline:
##   - Tier sprite'ı temel (siluet, yüz, yanak, aksesuar korunur).
##   - `assets/visual/skins/skin_body.gdshader` yalnızca gövde maskesinin
##     (`generated/body_mask_tier*.png`, tools/make_skin_masks.py) içini
##     boyar: SkinData profilinden renk (shade/body/highlight, sprite'ın
##     kendi shading'i luminanstan okunur), deterministik desen ailesi,
##     gloss/pearl/sparkle rarity malzemesi. Global RNG yok, TIME dışında
##     rastgelelik yok.
##   - Legendary: sprite'ın ARKASINA kompakt bir aura sprite'ı eklenir
##     (`attach_fx`), TIME ile nefes alır; parçacık yok, script yok.
##
## Materyaller (skin, tier) çifti başına bir kez kurulup paylaşılıyor: bir
## round'da tek skin aktif olduğundan pratikte en fazla 8 materyal yaşar.
## Aynı skin'i kullanan bütün parçalar aynı materyali paylaşır.
##
## Fizik, collider, CONTACT_FIT, merge/skor: bu dosyanın konusu DEĞİL.

const SHADER: Shader = preload("res://assets/visual/skins/skin_body.gdshader")
const AURA_SHADER: Shader = preload("res://assets/visual/skins/skin_aura.gdshader")
const BODY_MASKS: Array[Texture2D] = [
	preload("res://assets/visual/skins/generated/body_mask_tier1.png"),
	preload("res://assets/visual/skins/generated/body_mask_tier2.png"),
	preload("res://assets/visual/skins/generated/body_mask_tier3.png"),
	preload("res://assets/visual/skins/generated/body_mask_tier4.png"),
	preload("res://assets/visual/skins/generated/body_mask_tier5.png"),
	preload("res://assets/visual/skins/generated/body_mask_tier6.png"),
	preload("res://assets/visual/skins/generated/body_mask_tier7.png"),
	preload("res://assets/visual/skins/generated/body_mask_tier8.png"),
]
## Tier dokusunun en/boy oranı (x/y) — desen hücreleri ekranda kare kalsın.
const TEXTURE_ASPECT: Array[float] = [
	143.0 / 115.0, 145.0 / 113.0, 268.0 / 245.0, 287.0 / 229.0,
	291.0 / 225.0, 572.0 / 459.0, 575.0 / 456.0, 532.0 / 492.0,
]
## Tier'a göre desen detay ölçeği: küçük parçada daha az ama daha büyük
## hücre (tier 1 ~40 px; 9 hücre 4 px'lik benek demek, okunmaz).
const DETAIL_SCALE: Array[float] = [0.55, 0.6, 0.8, 0.85, 0.9, 1.0, 1.0, 1.0]
## UI fallback'inde (preview_texture yoksa) kullanılan tier — SkinEntry'nin
## PREVIEW_BASE_TEXTURE'ı tier 3.
const DEFAULT_TIER: int = 3

const AURA_NAME: StringName = &"SkinAura"
## Aura dokusu 256 px; sprite dokusunun uzun kenarının bu katı kadar açılır.
const AURA_SIZE: int = 256
const AURA_SPREAD: float = 1.45
const AURA_ALPHA: float = 0.5

## "skin_id/tier" -> ShaderMaterial
static var _materials: Dictionary = {}
static var _aura_texture: GradientTexture2D = null
static var _aura_material: ShaderMaterial = null


## Sprite'a skin görünümünü uygular. `skin` null ise varsayılan/orijinal
## görünüme döner (materyal tamamen kaldırılır — shader hiç çalışmaz).
##
## `item` Sprite2D (gameplay) ya da TextureRect (UI fallback) olabilir.
## `tier` gövde maskesini seçer (1..8); UI çağrıları vermezse tier 3.
static func apply(item: CanvasItem, skin: SkinData, tier: int = DEFAULT_TIER) -> void:
	if item == null:
		return
	if skin == null:
		clear(item)
		return
	item.material = _material_for(skin, clampi(tier, 1, 8))


## Varsayılan görünüm: materyal yok, sprite kendi renkleriyle çizilir.
static func clear(item: CanvasItem) -> void:
	if item == null:
		return
	item.material = null


## Rarity efektleri (şimdilik Legendary aura). Sprite'ın çocuğu olarak
## eklenir, sprite'la birlikte ölçeklenir/eğilir. Skin değişince ya da
## null gelince kaldırılır — eski efekt asla asılı kalmaz.
static func attach_fx(sprite: Sprite2D, skin: SkinData) -> void:
	if sprite == null:
		return
	var existing: Node = sprite.get_node_or_null(NodePath(AURA_NAME))
	if existing != null and existing.is_queued_for_deletion():
		existing = null
	var wants_aura: bool = skin != null and skin.aura_color.a > 0.001
	if not wants_aura:
		if existing != null:
			existing.queue_free()
		return
	var aura: Sprite2D = existing as Sprite2D
	if aura == null:
		aura = Sprite2D.new()
		aura.name = AURA_NAME
		aura.show_behind_parent = true
		aura.texture = _aura_tex()
		aura.material = _aura_mat()
		sprite.add_child(aura)
	aura.modulate = Color(skin.aura_color.r, skin.aura_color.g, skin.aura_color.b, AURA_ALPHA)
	if sprite.texture != null:
		var size: Vector2 = sprite.texture.get_size()
		var longest: float = maxf(size.x, size.y)
		aura.scale = Vector2.ONE * (longest * AURA_SPREAD / float(AURA_SIZE))
		# Gövdenin merkezi dokunun biraz altında (tepe püskülü / aksesuar).
		aura.position = Vector2(0.0, size.y * 0.06)


static func clear_fx(sprite: Sprite2D) -> void:
	attach_fx(sprite, null)


static func _material_for(skin: SkinData, tier: int) -> ShaderMaterial:
	var key: String = "%s/%d" % [String(skin.id), tier]
	var cached: Variant = _materials.get(key)
	if cached is ShaderMaterial:
		return cached
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("body_mask", BODY_MASKS[tier - 1])
	material.set_shader_parameter("body_color", skin.body_color)
	material.set_shader_parameter("shade_color", skin.shade_color)
	material.set_shader_parameter("highlight_color", skin.highlight_color)
	material.set_shader_parameter("pattern_type", int(skin.pattern))
	material.set_shader_parameter("pattern_color", skin.pattern_color)
	material.set_shader_parameter("pattern_color2", skin.pattern_color2)
	material.set_shader_parameter("pattern_density", skin.pattern_density)
	material.set_shader_parameter("pattern_scale", skin.pattern_scale)
	material.set_shader_parameter("pattern_strength", skin.pattern_strength)
	material.set_shader_parameter("detail_scale", DETAIL_SCALE[tier - 1])
	material.set_shader_parameter("gloss", skin.gloss)
	material.set_shader_parameter("pearl", skin.pearl)
	material.set_shader_parameter("sparkle", skin.sparkle)
	material.set_shader_parameter("anim_speed", skin.anim_speed)
	material.set_shader_parameter("aspect", TEXTURE_ASPECT[tier - 1])
	_materials[key] = material
	return material


static func _aura_tex() -> GradientTexture2D:
	if _aura_texture != null:
		return _aura_texture
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
	_aura_texture = GradientTexture2D.new()
	_aura_texture.gradient = gradient
	_aura_texture.width = AURA_SIZE
	_aura_texture.height = AURA_SIZE
	_aura_texture.fill = GradientTexture2D.FILL_RADIAL
	_aura_texture.fill_from = Vector2(0.5, 0.5)
	_aura_texture.fill_to = Vector2(0.5, 1.0)
	return _aura_texture


static func _aura_mat() -> ShaderMaterial:
	if _aura_material != null:
		return _aura_material
	_aura_material = ShaderMaterial.new()
	_aura_material.shader = AURA_SHADER
	return _aura_material


## Skin verisi çalışma anında değişirse (dev aracı / editör) önbelleği boşalt.
static func invalidate_cache() -> void:
	_materials.clear()
