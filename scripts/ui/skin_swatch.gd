class_name SkinSwatch
extends Control
## Koleksiyon/mağaza kartındaki skin görseli + rarity renginde çerçeve.
##
## Açılmamış skin owner'ın silüet görselini kullanıyor ("?" işareti görselin
## içinde çizili, GAME_DESIGN.md §5.3).
##
## ⚠️ Açılmış skin'in renkli daire önizlemesi PLACEHOLDER, final asset DEĞİL
## (owner kararı, M8.5-02 — "functional equip complete / final skin art
## pending", bkz. SKIN_ART_AUDIT.md). Skin başına gerçek görseller owner'dan
## gelmedi; daire yalnızca hangi skin olduğunu ayırt etmek için.

## Kilitli skin silueti — owner asset'i (M8 art turu).
const LOCKED_TEXTURE: Texture2D = preload("res://assets/visual/ui/skin_locked_silhouette.png")
## Siluetin üstündeki küçük kilit rozeti (icon_sheet.png'den).
## Kutunun bu oranında ve sağ-alt köşede: silüetin yüzünü kapatmıyor,
## "kilitli" bilgisi bir bakışta okunuyor.
const LOCK_BADGE_RATIO: float = 0.36
const LOCK_BADGE_INSET: float = 0.02

var fill_color: Color = Color.WHITE
var ring_color: Color = Color.WHITE
var unlocked: bool = false


func setup(new_fill: Color, new_ring: Color, is_unlocked: bool) -> void:
	fill_color = new_fill
	ring_color = new_ring
	unlocked = is_unlocked
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.42
	if unlocked:
		draw_circle(center, radius, fill_color)
		draw_arc(center, radius, 0.0, TAU, 48, ring_color, 4.0, true)
		# Küçük bir parlama — açık skin'i bir bakışta ayırt etmek için.
		draw_circle(center - Vector2(radius * 0.3, radius * 0.35), radius * 0.18,
			Color(1, 1, 1, 0.45))
		return

	# Kilitli: silüet görseli, en/boy korunarak kutuya sığdırılır. Rarity
	# halkası kalıyor — hangi rarity'nin kilitli olduğu görünsün.
	var tex_size: Vector2 = LOCKED_TEXTURE.get_size()
	var scale_factor: float = minf(size.x / tex_size.x, size.y / tex_size.y)
	var drawn: Vector2 = tex_size * scale_factor
	draw_texture_rect(LOCKED_TEXTURE, Rect2(center - drawn * 0.5, drawn), false)
	var ring := ring_color
	ring.a = 0.35
	draw_arc(center, radius, 0.0, TAU, 48, ring, 4.0, true)
	_draw_lock_badge()


## Sağ-alt köşede küçük kilit ikonu. Silüet zaten "açılmamış" diyor; kilit
## bunu ikonografiyle pekiştiriyor (koleksiyon ve mağazada aynı dil).
func _draw_lock_badge() -> void:
	var badge_h: float = minf(size.x, size.y) * LOCK_BADGE_RATIO
	var tex_size: Vector2 = UiIcons.LOCK.get_size()
	var badge: Vector2 = Vector2(badge_h * tex_size.x / tex_size.y, badge_h)
	var inset: float = minf(size.x, size.y) * LOCK_BADGE_INSET
	var at := Vector2(size.x - badge.x - inset, size.y - badge.y - inset)
	draw_texture_rect(UiIcons.LOCK, Rect2(at, badge), false)
