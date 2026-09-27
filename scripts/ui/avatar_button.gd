class_name AvatarButton
extends Button
## Profil avatarı (TASK/044): yuvarlak candy madalyon — Ana Sayfa üst satırının
## PROFİL girişi (56 px; eski ayarlar butonunun yeri) ve Profil ekranının büyük
## kimlik avatarı (dokunma almaz). Görsel TEK kaynaktan: `SkinEntry.avatar_entry()`
## (vitrinin ilk parçası; vitrin boşsa kanonik Squishy).
##
## Anatomi (arkadan öne): erik gölge → açık lavanta dış halka → rarity halkası
## (Common / varsayılan koyu lavanta, Rare mavi, Epic mor, Legendary altın) →
## krem iç yuva → alt gölge → owner'ın final sanatı → üst gloss. Kamera / galeri /
## yükleme YOK (owner kararı): avatar yalnız koleksiyon parçasıdır.

## Sanatın iç yuvaya oranı (karakter yuvadan hafif taşarak "oturur").
const ART_RATIO: float = 0.96

var _ring: NinePatchRect
var _well: NinePatchRect
var _art: TextureRect
var _entry: SkinEntry = null


func _init(diameter: float = 56.0, interactive: bool = true) -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(diameter, diameter)
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	UiKit.hud_shadow(self, diameter * 0.09, 0.28, null, diameter * 0.26)
	var rim := UiKit.patch("btn_circle_flat", UiTokens.LAVENDER_LIGHT)
	UiKit.inset(rim, -diameter * 0.07, -diameter * 0.07, -diameter * 0.07, -diameter * 0.07)
	add_child(rim)
	_ring = UiKit.patch("btn_circle_flat", UiTokens.LAVENDER_DEEP)
	UiKit.inset(_ring, 0.0, 0.0, 0.0, 0.0)
	add_child(_ring)
	_well = UiKit.patch("item_circle_inner", UiTokens.TRAY_CREAM)
	var ring_w: float = maxf(diameter * 0.075, 3.0)
	UiKit.inset(_well, ring_w, ring_w, ring_w, ring_w)
	add_child(_well)
	var shade := UiKit.patch("item_circle_inner", Color(0.35, 0.25, 0.5, 0.14))
	UiKit.inset(shade, ring_w + 1.0, diameter * 0.40, ring_w + 1.0, ring_w)
	add_child(shade)
	_art = UiKit.art(null, 0.0)
	_art.name = "Art"
	_art.custom_minimum_size = Vector2.ZERO
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var art_box: float = (diameter - ring_w * 2.0) * ART_RATIO
	_art.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_art.offset_left = -art_box * 0.5
	_art.offset_right = art_box * 0.5
	_art.offset_top = -art_box * 0.5 + diameter * 0.02
	_art.offset_bottom = art_box * 0.5 + diameter * 0.02
	add_child(_art)
	var gloss := UiKit.patch("item_circle_inner", Color(1, 1, 1, 0.30))
	UiKit.inset(gloss, diameter * 0.2, ring_w + 1.0, diameter * 0.2, diameter * 0.58)
	add_child(gloss)
	if interactive:
		UiMotion.attach_press(self)


## Avatarı kanonik modelden tazeler (vitrin değişti / ekran açıldı).
func refresh() -> void:
	set_entry(SkinEntry.avatar_entry())


func set_entry(entry: SkinEntry) -> void:
	_entry = entry
	_art.texture = entry.art_texture() if entry != null else SkinEntry.PREVIEW_BASE_TEXTURE
	var ring: Color = UiTokens.LAVENDER_DEEP
	if entry != null and not entry.is_default():
		match int(entry.rarity):
			SkinData.Rarity.RARE: ring = UiTokens.RARITY_RARE
			SkinData.Rarity.EPIC: ring = UiTokens.RARITY_EPIC
			SkinData.Rarity.LEGENDARY: ring = UiTokens.GOLD
	_ring.self_modulate = ring


# --- Testler / çekim aracı ----------------------------------------------------

func entry() -> SkinEntry:
	return _entry


func art_texture() -> Texture2D:
	return _art.texture


func ring_color() -> Color:
	return _ring.self_modulate
