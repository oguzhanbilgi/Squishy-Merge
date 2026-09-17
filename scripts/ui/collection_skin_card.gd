class_name CollectionSkinCard
extends Button
## Koleksiyon galeri kartı (M8.6-06). Yirmi skin + "Varsayılan" bu TEK
## bileşenden; Mağaza kartıyla aynı malzeme ailesi (krem `card_bevel_soft`
## gövde, açık halka, erik gölge, kart yüzü), 3 sütun galeriye göre daha
## küçük ölçü (216×220). Kart bir `Button` ama `MOUSE_FILTER_PASS`: basış
## karta işlenir VE olay ScrollContainer'a da ulaşır (STOP olsa parmak kartın
## üstündeyken kaydırma hiç başlamazdı — galerinin tamamı kart). Kaydırma
## başlayınca BaseButton basışı iptal eder (NOTIFICATION_SCROLL_BEGIN) ve
## kart basış ölçeğini bırakır — kaydırırken yanlışlıkla seçilmez.
##
## Anatomi (arkadan öne):
##   seçim halesi (cyan, yalnız seçili) → erik gölge → rarity halkası (Common
##   açık lavanta / Rare mavi / Epic mor / Legendary altın + altın hale) →
##   seçim halkası (cyan, +7 px, yalnız seçili) → 2 px erik kontur → gövde
##   (PanelCollectionCard krem; kilitli PanelCollectionCardLocked buzlu
##   lavanta-krem) → kart yüzü (`UiKit.card_face`) → sahne: rarity renginde
##   düşük alfa hale → krem kuyu → GERÇEK önizleme `SkinSwatch` 124 px
##   (kilitli: final sanat soluk + owner kilit rozeti — silüet YOK) → Baloo
##   19 ad → durum satırı: TAKILI (nane tik plakası) / boş. Fiyat kartta YOK
##   (gardırop fiyat listesi değil; seçilince vitrin fiyatı + MAĞAZAYA GİT).
##
## Kart kayda YAZMAZ ve takmaz: yalnız `selected(id)` yayar; takma vitrinin
## TAK butonundan (ekran → SaveManager.equip_skin). Durum `SkinEntry` tek
## kaynak (`refresh()` kanonik modelden yeniden okur).
##
## GENİŞ mod (M8.6-06.1, `create(entry, true)`): "Varsayılan" (id "") koleksiyon
## skini DEĞİL, ücretsiz TABAN görünüm (GAME_DESIGN §5.3) — 20 katalog kartından
## farklı BİÇİMDE: galerinin en üstünde, YAYGIN plakasının ÜSTÜNDE, 672×116
## yatay şerit (sol: kuyu + 92 px orijinal dumpling · orta: ad + lavanta
## "ORİJİNAL" rozeti · sağ: TAKILI plakası). Aynı gövde/halka/seçim/dokunma
## reçetesi; rarity etiketi YOK (YAYGIN/Common denmez), fiyat YOK.

signal selected(skin_id: StringName)

enum State { LOCKED, OWNED, EQUIPPED }

const CARD_SIZE: Vector2 = Vector2(216.0, 220.0)
## Geniş (taban görünüm) şerit: galeri iç genişliği; bir kart sırasının yarısı.
const WIDE_SIZE: Vector2 = Vector2(672.0, 116.0)
const WIDE_BODY_MARGIN: Vector4 = Vector4(14, 6, 18, 16)
const WIDE_PREVIEW_SIZE: float = 92.0
const WIDE_WELL_SIZE: float = 80.0
const WIDE_GLOW_SIZE: float = 132.0
const WIDE_NAME_FONT_SIZE: int = 22
const ORIGINAL_TEXT: String = "ORİJİNAL"
## Alt iç pay 22: `card_bevel_soft`'un pişmiş alt dudağı (~11 px) + nefes —
## durum satırındaki TAKILI plakası krem yüzün İÇİNDE kalır, dudağa binmez.
const BODY_MARGIN: Vector4 = Vector4(10, 8, 10, 22)
const PREVIEW_SIZE: float = 124.0
const WELL_SIZE: float = 110.0
const STAGE_HEIGHT: float = 130.0
const GLOW_SIZE: float = 176.0
const GLOW_ALPHA: Dictionary = {
	SkinData.Rarity.COMMON: 0.14, SkinData.Rarity.RARE: 0.18,
	SkinData.Rarity.EPIC: 0.20, SkinData.Rarity.LEGENDARY: 0.26,
}
const NAME_FONT_SIZE: int = 19
const STATE_ROW_HEIGHT: float = 26.0
const EQUIPPED_TEXT: String = "TAKILI"
const SELECT_RING: float = 7.0
const SELECT_POP: float = 1.04
const SPARKLE_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
## Legendary pırıltıları: kart uzayı konum, kutu, faz — dört köşe (Mağaza
## kartıyla aynı dil), yalnız sahne alanında (ad satırına değmez), sinüs,
## RNG yok.
const LEGENDARY_SPARKLES: Array = [
	[Vector2(30.0, 34.0), 18.0, 0.0],
	[Vector2(190.0, 30.0), 13.0, 1.6],
	[Vector2(26.0, 118.0), 13.0, 3.1],
	[Vector2(192.0, 124.0), 18.0, 4.7],
]
## Legendary gövde: satılık/kilitli olsa da sıcak altın-krem (Mağaza 05.1
## ile aynı, CREAM→GOLD_BRIGHT %12) — premium her durumda okunur; buz yalnız
## sanatta.
const LEGENDARY_BODY_MIX: float = 0.12
## Kilitli sanat: hafif buz (soğuk, %14 karartma) — sanat görünür, "senin
## değil" bilgisi kilit rozeti + fiyat + buzlu gövdeyle.
const LOCKED_FROST: Color = Color(0.86, 0.86, 0.94, 1.0)

var _id: StringName = SkinEntry.DEFAULT_ID
var _rarity: int = 0
var _is_default: bool = false
var _wide: bool = false
## Yalnız geniş mod: lavanta "ORİJİNAL" trapez rozeti.
var _original_tag: PanelContainer
var _state: State = State.LOCKED
var _selected: bool = false
var _select_halo: NinePatchRect
var _select_ring: PanelContainer
var _halo: NinePatchRect
var _rim: PanelContainer
var _body: PanelContainer
var _glow: NinePatchRect
var _well: NinePatchRect
var _swatch: SkinSwatch
var _name_label: Label
var _state_row: Control
var _equipped_plate: PanelContainer
var _price: int = 0
var _sparkles: Array[TextureRect] = []


static func create(entry: SkinEntry, wide: bool = false) -> CollectionSkinCard:
	var card := CollectionSkinCard.new(wide)
	card.setup(entry)
	return card


func _init(wide: bool = false) -> void:
	_wide = wide
	# Buton gövdesi görünmez: kartın görünümü çocuk katmanlarında. Basış
	# hissi UiMotion (0.94) + seçim pop'u.
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = WIDE_SIZE if wide else CARD_SIZE
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	_select_halo = UiKit.patch("popup_glow", Color(UiTokens.CYAN, 0.55))
	UiKit.inset(_select_halo, -30.0, -26.0, -30.0, -34.0)
	_select_halo.visible = false
	add_child(_select_halo)
	_halo = UiKit.patch("popup_glow", Color(UiTokens.GOLD_BRIGHT, 0.0))
	UiKit.inset(_halo, -26.0, -22.0, -26.0, -30.0)
	_halo.visible = false
	add_child(_halo)
	var shadow := UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.32))
	UiKit.inset(shadow, -12.0, -4.0, -12.0, -20.0)
	add_child(shadow)
	_select_ring = UiKit.flat_plate("frame_round20", UiTokens.CYAN)
	UiKit.inset(_select_ring, -SELECT_RING, -SELECT_RING, -SELECT_RING, -SELECT_RING)
	_select_ring.visible = false
	add_child(_select_ring)
	_rim = UiKit.flat_plate("frame_round20", Color.WHITE)
	UiKit.inset(_rim, -4.0, -4.0, -4.0, -4.0)
	add_child(_rim)
	var contour := UiKit.flat_plate("frame_round20", Color(UiTokens.LAVENDER_DEEP, 0.5))
	UiKit.inset(contour, -2.0, -2.0, -2.0, -2.0)
	add_child(contour)
	_body = UiKit.panel(&"PanelCollectionCard")
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_body)
	UiKit.card_face(_body, WIDE_BODY_MARGIN if wide else BODY_MARGIN)
	if wide:
		_build_wide()
	else:
		_build_grid()
	_build_equipped_plate()
	if not wide:
		for spec in LEGENDARY_SPARKLES:
			var spark := UiKit.art(SPARKLE_ART, float(spec[1]))
			spark.position = (spec[0] as Vector2) - Vector2(float(spec[1]), float(spec[1])) * 0.5
			spark.size = Vector2(float(spec[1]), float(spec[1]))
			spark.pivot_offset = spark.size * 0.5
			spark.visible = false
			add_child(spark)
			_sparkles.append(spark)
	pressed.connect(func() -> void: selected.emit(_id))
	UiMotion.attach_press(self)


## Galeri kartı: dikey sütun — sahne (hale + kuyu + sanat) → ad → durum satırı.
func _build_grid() -> void:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(column)
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.custom_minimum_size = Vector2(0, STAGE_HEIGHT)
	column.add_child(stage)
	_glow = UiKit.patch("popup_glow", Color(UiTokens.LAVENDER, 0.0))
	_center(_glow, GLOW_SIZE, 6.0)
	stage.add_child(_glow)
	_well = UiKit.patch("item_circle_inner", UiTokens.TRAY_CREAM)
	_center(_well, WELL_SIZE, 6.0)
	stage.add_child(_well)
	var well_shade := UiKit.patch("item_circle_inner", Color(0.35, 0.25, 0.5, 0.10))
	_center(well_shade, WELL_SIZE - 8.0, 12.0)
	stage.add_child(well_shade)
	_swatch = SkinSwatch.new()
	_swatch.name = "Preview"
	_center(_swatch, PREVIEW_SIZE, 4.0)
	stage.add_child(_swatch)
	_name_label = UiKit.label("", &"LabelSection", HORIZONTAL_ALIGNMENT_CENTER)
	_name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	_name_label.custom_minimum_size = Vector2(0, 28.0)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_name_label)
	_state_row = Control.new()
	_state_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state_row.custom_minimum_size = Vector2(0, STATE_ROW_HEIGHT)
	column.add_child(_state_row)


## Taban görünüm şeridi (Varsayılan): yatay satır — sahne (kuyu + 92 px
## orijinal dumpling) → ad + ORİJİNAL rozeti (sola yaslı, dikey ortalı) →
## sağda TAKILI yuvası. Rarity etiketi yok: bu bir koleksiyon skini değil.
func _build_wide() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	_body.add_child(row)
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.custom_minimum_size = Vector2(WIDE_PREVIEW_SIZE + 6.0, 0)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(stage)
	_glow = UiKit.patch("popup_glow", Color(UiTokens.LAVENDER, 0.0))
	_center(_glow, WIDE_GLOW_SIZE, 0.0)
	stage.add_child(_glow)
	_well = UiKit.patch("item_circle_inner", UiTokens.TRAY_CREAM)
	_center(_well, WIDE_WELL_SIZE, 2.0)
	stage.add_child(_well)
	var well_shade := UiKit.patch("item_circle_inner", Color(0.35, 0.25, 0.5, 0.10))
	_center(well_shade, WIDE_WELL_SIZE - 6.0, 6.0)
	stage.add_child(well_shade)
	_swatch = SkinSwatch.new()
	_swatch.name = "Preview"
	_center(_swatch, WIDE_PREVIEW_SIZE, 0.0)
	stage.add_child(_swatch)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_name_label = UiKit.label("", &"LabelSection", HORIZONTAL_ALIGNMENT_LEFT)
	_name_label.add_theme_font_size_override("font_size", WIDE_NAME_FONT_SIZE)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_name_label)
	var tag_row := HBoxContainer.new()
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(tag_row)
	# Lavanta trapez (rarity etiketleriyle aynı biçim, rarity rengi DEĞİL):
	# "ücretsiz taban görünüm" — YAYGIN/Common değil.
	_original_tag = PanelContainer.new()
	_original_tag.name = "OriginalTag"
	_original_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_original_tag.add_theme_stylebox_override("panel",
		UiKit.style("label_trapezoid", UiTokens.LAVENDER_DEEP, Vector4(14, 0, 18, 4)))
	var tag_text := UiKit.label(ORIGINAL_TEXT, &"LabelBadgeOnDark", HORIZONTAL_ALIGNMENT_CENTER)
	tag_text.add_theme_font_size_override("font_size", 15)
	_original_tag.add_child(tag_text)
	_original_tag.set_meta(&"title_label", tag_text)
	tag_row.add_child(_original_tag)
	_state_row = Control.new()
	_state_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state_row.custom_minimum_size = Vector2(112.0, 0)
	_state_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_state_row)


## TAKILI: küçük nane tik plakası (EquippedBadge dili, kompakt) — durum
## satırında ortalı; iki modda da aynı.
func _build_equipped_plate() -> void:
	_equipped_plate = UiKit.panel(&"EquippedBadge")
	_equipped_plate.name = "EquippedPlate"
	_equipped_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipped_plate.add_theme_stylebox_override("panel",
		UiKit.style("frame_round20", UiTokens.MINT, Vector4(10, 1, 10, 3)))
	var plate_row := HBoxContainer.new()
	plate_row.alignment = BoxContainer.ALIGNMENT_CENTER
	plate_row.add_theme_constant_override("separation", 4)
	plate_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipped_plate.add_child(plate_row)
	var check := UiKit.icon("check", 16, UiTokens.TEXT_ON_ACCENT)
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate_row.add_child(check)
	var equipped_label := UiKit.label(EQUIPPED_TEXT, &"LabelBadge", HORIZONTAL_ALIGNMENT_CENTER)
	equipped_label.add_theme_font_size_override("font_size", 14)
	plate_row.add_child(equipped_label)
	_equipped_plate.visible = false
	_state_row.add_child(_equipped_plate)
	_equipped_plate.minimum_size_changed.connect(_layout_plate)


## ScrollContainer sürüklemeye başladı: BaseButton basışı iptal etti (sinyal
## yok) — basış ölçeği (0.94) de bırakılır.
func _notification(what: int) -> void:
	if what == NOTIFICATION_SCROLL_BEGIN:
		UiMotion.release(self)


static func _center(node: Control, box: float, down: float) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	node.offset_left = -box * 0.5
	node.offset_right = box * 0.5
	node.offset_top = -box * 0.5 + down
	node.offset_bottom = box * 0.5 + down


func _layout_plate() -> void:
	var min: Vector2 = _equipped_plate.get_combined_minimum_size()
	var w: float = maxf(min.x, 96.0)
	var h: float = maxf(min.y, 26.0)
	_equipped_plate.set_anchors_preset(Control.PRESET_CENTER)
	_equipped_plate.offset_left = -w * 0.5
	_equipped_plate.offset_right = w * 0.5
	_equipped_plate.offset_top = -h * 0.5
	_equipped_plate.offset_bottom = h * 0.5


func setup(entry: SkinEntry) -> void:
	_id = entry.id
	_rarity = int(entry.rarity)
	_is_default = entry.is_default()
	name = "Card_%s" % (String(_id) if not _is_default else "default")
	_name_label.text = entry.display_name
	# Rarity dili (Mağaza 05.1 kalibrasyonuyla aynı): Common açık lavanta
	# halka, Rare mavi (beyaza %25), Epic mor (%22) + hafif hale, Legendary
	# altın halka + altın hale + 2 pırıltı. Karakter arkasındaki hale rarity
	# renginde, düşük alfa.
	var rarity_color: Color = UiTokens.rarity_color(_rarity)
	var glow_color: Color = rarity_color
	if _is_default:
		# Taban görünüm: lavanta halka (Common'ın açık lavantasından bir ton
		# doygun) — koleksiyon rarity ailesinin dışında okunur.
		_rim.self_modulate = UiTokens.LAVENDER.lerp(Color.WHITE, 0.35)
		_halo.visible = false
		_glow.self_modulate = Color(UiTokens.LAVENDER, 0.16)
		_apply_entry(entry)
		return
	match _rarity:
		SkinData.Rarity.RARE:
			_rim.self_modulate = rarity_color.lerp(Color.WHITE, 0.25)
			_halo.visible = false
		SkinData.Rarity.EPIC:
			_rim.self_modulate = rarity_color.lerp(Color.WHITE, 0.22)
			_halo.self_modulate = Color(rarity_color, 0.30)
			_halo.visible = true
		SkinData.Rarity.LEGENDARY:
			_rim.self_modulate = UiTokens.GOLD
			_halo.self_modulate = Color(UiTokens.GOLD_BRIGHT, 0.55)
			_halo.visible = true
			glow_color = UiTokens.GOLD
		_:
			_rim.self_modulate = UiTokens.LAVENDER_LIGHT
			_halo.visible = false
			glow_color = UiTokens.LAVENDER
	_glow.self_modulate = Color(glow_color, float(GLOW_ALPHA.get(_rarity, 0.14)))
	for spark in _sparkles:
		spark.visible = _rarity == SkinData.Rarity.LEGENDARY
	_apply_entry(entry)


## Durumu kanonik modelden yeniden okur (`SkinEntry.find`), kayda yazmaz.
func refresh() -> void:
	var entry: SkinEntry = SkinEntry.find(_id)
	if entry != null:
		_apply_entry(entry)


func _apply_entry(entry: SkinEntry) -> void:
	if entry.equipped:
		_state = State.EQUIPPED
	elif entry.owned:
		_state = State.OWNED
	else:
		_state = State.LOCKED
	# Kilitli kart da GERÇEK final sanatı gösterir (owner kararı, M8.5-14;
	# koleksiyonda M8.6-06'dan itibaren silüet yok): sanat arzu uyandırsın,
	# kilit rozeti + fiyat + buzlu gövde "henüz senin değil" der.
	_swatch.setup(entry, true)
	_swatch.modulate = LOCKED_FROST if _state == State.LOCKED else Color.WHITE
	_body.theme_type_variation = &"PanelCollectionCardLocked" if _state == State.LOCKED else &"PanelCollectionCard"
	if _rarity == SkinData.Rarity.LEGENDARY:
		_body.add_theme_stylebox_override("panel", UiKit.style("card_bevel_soft",
			UiTokens.CREAM.lerp(UiTokens.GOLD_BRIGHT, LEGENDARY_BODY_MIX), BODY_MARGIN))
	else:
		_body.remove_theme_stylebox_override("panel")
	_price = entry.price
	_equipped_plate.visible = _state == State.EQUIPPED
	_layout_plate()


## Seçim: cyan hale + halka, kısa pop (yalnız seçilince).
func set_selected(on: bool) -> void:
	var was: bool = _selected
	_selected = on
	_select_halo.visible = on
	_select_ring.visible = on
	if on and not was:
		UiMotion.pop(self, SELECT_POP)


## Legendary pırıltıları (ekran `_process`'inden; sinüs, RNG yok).
func tick_sparkles(time: float) -> void:
	if _rarity != SkinData.Rarity.LEGENDARY:
		return
	for i in _sparkles.size():
		var phase: float = float(LEGENDARY_SPARKLES[i][2])
		var twinkle: float = 0.30 + 0.60 * (0.5 + 0.5 * sin(TAU * time / 2.8 + phase))
		_sparkles[i].modulate.a = twinkle
		_sparkles[i].scale = Vector2.ONE * (0.75 + 0.35 * twinkle)


# --- Okuma (test / ekran) ----------------------------------------------------

func skin_id() -> StringName:
	return _id


func is_default_entry() -> bool:
	return _is_default


## Geniş taban görünüm şeridi mi (Varsayılan)?
func is_wide() -> bool:
	return _wide


func original_tag() -> PanelContainer:
	return _original_tag


func state() -> State:
	return _state


func is_owned() -> bool:
	return _state != State.LOCKED


func is_equipped() -> bool:
	return _state == State.EQUIPPED


func is_selected() -> bool:
	return _selected


func rarity() -> int:
	return _rarity


func swatch() -> SkinSwatch:
	return _swatch


func name_text() -> String:
	return _name_label.text


## Kartta fiyat GÖSTERİLMEZ (vitrinde); kilitli girişin fiyatı okunabilir.
func price() -> int:
	return _price if _state == State.LOCKED else 0


func equipped_plate() -> PanelContainer:
	return _equipped_plate


func select_ring() -> Control:
	return _select_ring


func rim() -> Control:
	return _rim


func halo() -> Control:
	return _halo


func body() -> PanelContainer:
	return _body


func sparkles() -> Array[TextureRect]:
	return _sparkles
