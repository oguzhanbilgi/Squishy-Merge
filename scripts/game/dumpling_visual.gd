extends Node2D
## Dumpling görseli: nötr gri gövde sprite'ı + tier rengiyle tint, üstüne
## tint'lenmeyen bir yüz. Sprite'lar Kenney "Shape Characters" (CC0)
## PLACEHOLDER — owner kendi asset'iyle aynı dosya adlarını koruyarak
## değiştirecek (bkz. assets/visual/CREDITS.md).

## Gövde nötr gri; renk TierConfig paletinden modulate ile geliyor, burada
## yeni renk tanımlanmıyor.
const BODY_TEXTURE: Texture2D = preload("res://assets/visual/dumpling_body.png")
const FACE_TEXTURE: Texture2D = preload("res://assets/visual/dumpling_face.png")
## Parlama overlay'i (M8): sol-üstte yarı saydam beyaz highlight. Tint
## uygulanmaz — ışık yansıması tier renginden bağımsız. Gövdeyle aynı
## ölçüde üretiliyor (tools/make_fx_sprites.gd), o yüzden aynı ölçek geçerli.
const GLOSS_TEXTURE: Texture2D = preload("res://assets/visual/fx/dumpling_gloss.png")
## Highlight'ın gücü. 1.0 plastik/ıslak görünüyor, 0.45 "cilalı" sınırında.
const GLOSS_ALPHA: float = 0.45

## Gövde texture'u 160x160, yani yarıçapı 80 px. Ölçek bundan çıkıyor.
const BODY_TEXTURE_RADIUS: float = 80.0
## Yüz genişliği / gövde çapı. Kenney'nin kendi örnek oranı.
const FACE_WIDTH_RATIO: float = 0.66
## Yüz merkezi gövde merkezinin bu kadar üstünde (yarıçap katı).
const FACE_OFFSET_RATIO: float = -0.16

var radius: float = 20.0
var fill_color: Color = Color.WHITE

var _tween: Tween
var _body: Sprite2D
var _gloss: Sprite2D
var _face: Sprite2D
## Yüzün gövde merkezine göre konumu — her karede dönüş geri alınarak
## uygulanıyor, yoksa yüz gövdeyle birlikte merkezin etrafında dönerdi.
var _face_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_ensure_sprites()


## setup() _ready'den önce de çağrılabildiği için sprite'lar tembel kuruluyor.
func _ensure_sprites() -> void:
	if _body != null:
		return
	_body = Sprite2D.new()
	_body.texture = BODY_TEXTURE
	add_child(_body)
	_gloss = Sprite2D.new()
	_gloss.texture = GLOSS_TEXTURE
	_gloss.modulate = Color(1.0, 1.0, 1.0, GLOSS_ALPHA)
	add_child(_gloss)
	_face = Sprite2D.new()
	_face.texture = FACE_TEXTURE
	add_child(_face)


func setup(new_radius: float, new_color: Color) -> void:
	radius = new_radius
	fill_color = new_color
	_ensure_sprites()
	_body.scale = Vector2.ONE * (radius / BODY_TEXTURE_RADIUS)
	_body.modulate = fill_color
	_gloss.scale = _body.scale
	var face_width: float = radius * 2.0 * FACE_WIDTH_RATIO
	_face.scale = Vector2.ONE * (face_width / float(FACE_TEXTURE.get_width()))
	_face_offset = Vector2(0.0, radius * FACE_OFFSET_RATIO)
	_face.position = _face_offset


## Gövde serbest dönüyor (M1 kilitli karar) ama yüz her zaman yukarı bakmalı;
## yan yatmış yüz büyük tier'larda karalama gibi okunuyordu.
##
## `top_level = true` yerine yüz normal çocuk olarak bırakıldı: top_level olsaydı
## ebeveynin ölçeğini de miras almazdı ve squash-stretch sırasında yüz gövdeyle
## birlikte ezilmez, üstünde sabit dururdu. Bunun yerine hem dönüş hem de konum
## offset'i ters çevriliyor — sonuç aynı (yüz dik), squash bağlantısı korunuyor.
func _process(_delta: float) -> void:
	if _face == null or _gloss == null:
		return
	var body_rotation: float = global_rotation
	_face.rotation = -body_rotation
	_face.position = _face_offset.rotated(-body_rotation)
	# Işık kaynağı sabit: gövde dönerken highlight ekranda sol-üstte kalmalı.
	# Merkezde durduğu için konum düzeltmesi gerekmiyor, sadece dönüş.
	_gloss.rotation = -body_rotation


## Squash-stretch. Merge'de tam genlik (GAME_DESIGN.md §1: 1.0 -> 1.2/0.8 -> 1.0,
## ~150 ms); çarpmada aynı tween'in hıza orantılı hafif versiyonu.
func play_squash(amount: float = 0.2, duration: float = 0.15) -> void:
	# Önceki squash hâlâ oynuyorsa kes — üst üste binince titreşim oluyor.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	scale = Vector2.ONE
	var half: float = duration * 0.5
	_tween = create_tween()
	var squashed := Vector2(1.0 + amount, 1.0 - amount)
	_tween.tween_property(self, "scale", squashed, half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, half).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
