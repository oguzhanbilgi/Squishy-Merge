class_name SkinSwatch
extends Control
## Koleksiyon / mağaza / vitrin skin önizlemesi (M8.5-13).
##
## Üç durum, tek bileşen:
##   varsayılan  — orijinal dumpling (tier 3), materyal yok, nötr hale
##   sahip       — SkinData.preview_texture (owner'ın FİNAL önizleme sanatı,
##                 M8.5-14; 20 skin'in hepsinde dolu). Yoksa fallback: orijinal
##                 dumpling + gameplay SkinVisual materyali. Arkada rarity
##                 renginde yumuşak radyal parıltı: kart "collectible" okunsun,
##                 rarity bir bakışta ayırt edilsin.
##   kilitli     — owner'ın silüet görseli (GAME_DESIGN.md §5.3) + sağ-altta
##                 kilit rozeti; parıltı soluk ama rarity rengi okunuyor.
##
## Sanat turu: skin başına gerçek görsel gelince `SkinData.preview_texture`
## doldurulur, bu dosya değişmez. Render tekniği değişirse SkinVisual değişir,
## bu dosya yine değişmez.

const LOCKED_TEXTURE: Texture2D = preload("res://assets/visual/ui/skin_locked_silhouette.png")
## Kilit rozeti: kutunun bu oranında, sağ-alt köşede — silüetin yüzünü
## kapatmıyor, "kilitli" bilgisi bir bakışta okunuyor.
const LOCK_BADGE_RATIO: float = 0.34
const LOCK_BADGE_INSET: float = 0.02
## Görselin kutuya göre iç payı: parıltı kenarlarda nefes alsın.
const IMAGE_INSET: float = 0.06
const GLOW_ALPHA_OWNED: float = 0.8
const GLOW_ALPHA_LOCKED: float = 0.2
const GLOW_ALPHA_DEFAULT: float = 0.28
## Kilitli ama açığa çıkarılmış önizleme hafif soluk: "henüz senin değil"
## okunsun ama sanat görünsün. 0.86/0.90 açık pastel Legendary'leri
## (Gökkuşağı) fazla söndürüyordu; %7 karartma + hafif soğuk ton yeterli,
## kilitli bilgisini zaten kilit rozeti + KİLİTLİ pill taşıyor.
const LOCKED_REVEAL_TINT: Color = Color(0.93, 0.93, 0.96, 1.0)

## Rarity rengi -> radyal parıltı dokusu. Her kart için yeniden üretilmiyor.
static var _glow_cache: Dictionary = {}

var _glow: TextureRect
var _image: TextureRect
var _lock: TextureRect
var _entry: SkinEntry = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow = _make_rect()
	_image = _make_rect()
	_lock = _make_rect()
	_lock.visible = false
	add_child(_glow)
	add_child(_image)
	add_child(_lock)
	resized.connect(_layout)


## `reveal_locked` (M8.5-14 polish): kilitli skin'de silüet yerine FİNAL
## önizlemeyi göster, kilit rozeti kalsın. Mağaza (satın alınan şey
## görünmeli — 900 Hamur'luk Legendary "?" olarak satılmaz) ve koleksiyon
## VİTRİNİ (kilitli karta dokununca inceleme) bunu kullanır; koleksiyon
## GRID'i kullanmaz — keşif hissi orada korunur.
func setup(entry: SkinEntry, reveal_locked: bool = false) -> void:
	_entry = entry
	if entry == null:
		visible = false
		return
	visible = true
	var color: Color = entry.rarity_color()
	if entry.is_locked():
		var ready_made: Texture2D = entry.preview_texture()
		if reveal_locked and ready_made != null:
			_image.texture = ready_made
			_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			_image.modulate = LOCKED_REVEAL_TINT
		else:
			_image.texture = LOCKED_TEXTURE
			_image.modulate = Color.WHITE
		SkinVisual.clear(_image)
		_glow.texture = _glow_for(color, GLOW_ALPHA_LOCKED)
		_lock.visible = true
		_lock.texture = UiIcons.LOCK
	else:
		_image.modulate = Color.WHITE
		var ready_made: Texture2D = entry.preview_texture()
		if ready_made != null:
			# Final önizleme sanatı (M8.5-14): 512 px import, kartta 64-150 px
			# — mipmap'li filtre yoksa küçültme kırpışır.
			_image.texture = ready_made
			_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			SkinVisual.clear(_image)
		else:
			_image.texture = SkinEntry.PREVIEW_BASE_TEXTURE
			# Varsayılanda skin null -> materyal kalkar; sahip olunanda
			# gameplay'deki materyalin AYNISI (SkinVisual önbelleği).
			SkinVisual.apply(_image, entry.skin)
		_glow.texture = _glow_for(color,
			GLOW_ALPHA_DEFAULT if entry.is_default() else GLOW_ALPHA_OWNED)
		_lock.visible = false
	_layout()


func _layout() -> void:
	_glow.position = Vector2.ZERO
	_glow.size = size
	var inset: Vector2 = size * IMAGE_INSET
	_image.position = inset
	_image.size = size - inset * 2.0
	if _lock.visible and _lock.texture != null:
		var badge_h: float = minf(size.x, size.y) * LOCK_BADGE_RATIO
		var tex_size: Vector2 = _lock.texture.get_size()
		var badge := Vector2(badge_h * tex_size.x / tex_size.y, badge_h)
		var pad: float = minf(size.x, size.y) * LOCK_BADGE_INSET
		_lock.position = Vector2(size.x - badge.x - pad, size.y - badge.y - pad)
		_lock.size = badge


static func _make_rect() -> TextureRect:
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Merkezde rarity renginde, kenara doğru saydamlaşan yumuşak daire.
static func _glow_for(color: Color, alpha: float) -> Texture2D:
	var key: String = "%s@%.2f" % [color.to_html(), alpha]
	var cached: Variant = _glow_cache.get(key)
	if cached is Texture2D:
		return cached
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(color.r, color.g, color.b, alpha),
		Color(color.r, color.g, color.b, alpha * 0.35),
		Color(color.r, color.g, color.b, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 1.0)
	_glow_cache[key] = texture
	return texture
