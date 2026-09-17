class_name ShopSkinCard
extends Control
## Mağaza skin ürün kartı (M8.6-05). Yirmi skin bu TEK bileşenden; güç
## kartıyla aynı gövde/halka/gölge reçetesi, aynı ölçü (`ShopPowerCard.
## CARD_SIZE`, 328×384 — grid ritmi).
##
## Anatomi (arkadan öne):
##   rarity halesi (yalnız Epic lavanta / Legendary altın) → erik gölge →
##   rarity renginde halka → 2 px erik kontur → krem gövde (PanelShopCard;
##   sahip olunan CREAM_DEEP PanelShopCardOwned) → kart yüzü (`UiKit.
##   card_face`: yumuşak radyal ışık + kavisli üst gloss bandı — 05.1) → içerik: sahne
##   (rarity renginde çok düşük alfa radyal candy hale → lavanta-krem
##   yuvarlak kuyu → GERÇEK önizleme `SkinSwatch` 164 px — kartın üst
##   yarısını karakter doldurur; kilitlide final sanat + kilit rozeti, canlı
##   önizleme yolu, yeni sanat YOK; sol üstte rarity etiketi) · Baloo 26 ad ·
##   fiyat satırı YA DA ipucu · SATIN AL ya da durum plakası → Legendary'de
##   4 sessiz pırıltı (sinüs, RNG yok).
##
## Hiyerarşi (05.1): rarity etiketi → büyük karakter → ad → fiyat/durum →
## CTA. Rarity bir bakışta: Common lavanta-nötr halka (sessiz), Rare okunur
## soğuk mavi halka, Epic zengin lavanta-mor halka + hafif aura, Legendary
## altın halka + geniş hale + pırıltı + sıcak altın-krem gövde.
##
## Durumlar (`SkinEntry` tek kaynak): LOCKED (fiyat + cyan SATIN AL;
## Hamur yetmiyorsa soluk cyan `ButtonBuyLocked` (CYAN_MUTED) + koyu pembe
## fiyat, dokununca sallanır) ·
## OWNED ("SAHİPSİN" lavanta plakası, buton YOK) · EQUIPPED ("TAKILI" nane
## plakası + tik). Mağaza skin TAKMAZ (Koleksiyon takar); kart yalnız
## `buy_requested` yayar. Kayda YAZMAZ.

signal buy_requested(skin: SkinData)

enum State { LOCKED, OWNED, EQUIPPED }

const CARD_SIZE: Vector2 = ShopPowerCard.CARD_SIZE
const BUY_HEIGHT: float = ShopPowerCard.BUY_HEIGHT
## 164 (05.1, 140'tan +%17): karakter kartın üst yarısına hâkim; sanat
## kırpılmaz (SkinSwatch %6 iç pay, saç/fiyonk/yıldız/taç kutunun içinde).
const PREVIEW_SIZE: float = 164.0
const WELL_SIZE: float = 152.0
## Sahne yüksekliği: önizleme + rarity etiketi / ad için nefes payı.
const STAGE_HEIGHT: float = PREVIEW_SIZE + 20.0
## Karakterin arkasındaki radyal candy hale (kart düz krem okunmasın):
## rarity renginden, çok düşük alfa; Common nötr lavanta.
const GLOW_SIZE: float = 236.0
const GLOW_ALPHA: Dictionary = {
	SkinData.Rarity.COMMON: 0.14, SkinData.Rarity.RARE: 0.17,
	SkinData.Rarity.EPIC: 0.18, SkinData.Rarity.LEGENDARY: 0.24,
}
## Ad: sanatın altında ama diğer metinlerden güçlü (LabelSection 24 → 26).
const NAME_FONT_SIZE: int = 26
const BUY_TEXT: String = "SATIN AL"
const OWNED_TEXT: String = "SAHİPSİN"
const EQUIPPED_TEXT: String = "TAKILI"
## Sahip olunan kartta fiyat yuvasına giren ipucu: takma Koleksiyon'da.
const OWNED_HINT: String = "Koleksiyon'da tak"
const EQUIPPED_HINT: String = "Şu an takılı"
const DOUGH_ART: Texture2D = preload("res://assets/visual/ui/icon_dough.png")
const SPARKLE_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
const WIGGLE_TIME: float = 0.22
## Legendary pırıltıları: kart uzayı konum, kutu, faz — deterministik, dört
## köşe simetrik, yalnız önizleme alanında (ad satırına değmez).
const LEGENDARY_SPARKLES: Array = [
	[Vector2(52.0, 64.0), 18.0, 0.0],
	[Vector2(278.0, 58.0), 13.0, 1.6],
	[Vector2(46.0, 150.0), 13.0, 3.1],
	[Vector2(282.0, 152.0), 18.0, 4.7],
]

var _id: StringName = &""
var _skin: SkinData = null
var _state: State = State.LOCKED
var _affordable: bool = true
var _rarity: int = 0
var _halo: NinePatchRect
var _glow: NinePatchRect
var _rim: PanelContainer
var _body: PanelContainer
var _tag_slot: Control
var _tag: PanelContainer
var _well: NinePatchRect
var _swatch: SkinSwatch
var _name_label: Label
var _price_row: HBoxContainer
var _price_label: Label
var _hint_label: Label
var _owned_plate: PanelContainer
var _owned_label: Label
var _owned_icon: TextureRect
var _buy: Button
var _sparkles: Array[TextureRect] = []
var _wiggle: Tween


static func create(entry: SkinEntry) -> ShopSkinCard:
	var card := ShopSkinCard.new()
	card.setup(entry)
	return card


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = CARD_SIZE
	_halo = UiKit.patch("popup_glow", Color(UiTokens.GOLD, 0.0))
	UiKit.inset(_halo, -40.0, -36.0, -40.0, -44.0)
	_halo.visible = false
	add_child(_halo)
	var shadow := UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.34))
	UiKit.inset(shadow, -16.0, -6.0, -16.0, -26.0)
	add_child(shadow)
	# Halka beyaz tabanlı: rengi yalnız `setup()` `self_modulate` ile verir
	# (stylebox tint × self_modulate çift boyama olmasın).
	_rim = UiKit.flat_plate("frame_round20", Color.WHITE)
	UiKit.inset(_rim, -5.0, -5.0, -5.0, -5.0)
	add_child(_rim)
	var contour := UiKit.flat_plate("frame_round20", Color(UiTokens.LAVENDER_DEEP, 0.5))
	UiKit.inset(contour, -2.0, -2.0, -2.0, -2.0)
	add_child(contour)
	_body = UiKit.panel(&"PanelShopCard")
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_body)
	# Kart yüzü (yumuşak radyal ışık + üst gloss bandı) içeriğin ALTINDA.
	UiKit.card_face(_body)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	# Skin içeriği (338: sahne 184 + ad 42 + fiyat 32 + 4 + eylem 60 + 4×4)
	# güç kartından kısa: dikeyde ortalanır, boşluk alta yığılmaz.
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(column)
	# Önizleme sahnesi: sabit yükseklik; hale + kuyu + swatch ortada (8 px
	# aşağı: rarity etiketi sanatın %6 iç paylı kutusuna değmez — testle),
	# rarity etiketi sol üstte (sabit konumlar, container değil).
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.custom_minimum_size = Vector2(0, STAGE_HEIGHT)
	column.add_child(stage)
	# Radyal candy hale: kuyunun merkezinde, rarity renginde, çok düşük alfa
	# (`setup()` boyar). Kartın içinde kalır (236 < 296 iç genişlik).
	_glow = UiKit.patch("popup_glow", Color(UiTokens.LAVENDER, 0.0))
	_glow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_glow.offset_left = -GLOW_SIZE * 0.5
	_glow.offset_right = GLOW_SIZE * 0.5
	_glow.offset_top = -GLOW_SIZE * 0.5 + 10.0
	_glow.offset_bottom = GLOW_SIZE * 0.5 + 10.0
	stage.add_child(_glow)
	_well = UiKit.patch("item_circle_inner", UiTokens.TRAY_CREAM)
	_well.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_well.offset_left = -WELL_SIZE * 0.5
	_well.offset_right = WELL_SIZE * 0.5
	_well.offset_top = -WELL_SIZE * 0.5 + 10.0
	_well.offset_bottom = WELL_SIZE * 0.5 + 10.0
	stage.add_child(_well)
	var well_shade := UiKit.patch("item_circle_inner", Color(0.35, 0.25, 0.5, 0.10))
	well_shade.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	well_shade.offset_left = -WELL_SIZE * 0.5 + 4.0
	well_shade.offset_right = WELL_SIZE * 0.5 - 4.0
	well_shade.offset_top = -WELL_SIZE * 0.5 + 18.0
	well_shade.offset_bottom = WELL_SIZE * 0.5 + 14.0
	stage.add_child(well_shade)
	_swatch = SkinSwatch.new()
	_swatch.name = "Preview"
	_swatch.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_swatch.offset_left = -PREVIEW_SIZE * 0.5
	_swatch.offset_right = PREVIEW_SIZE * 0.5
	_swatch.offset_top = -PREVIEW_SIZE * 0.5 + 8.0
	_swatch.offset_bottom = PREVIEW_SIZE * 0.5 + 8.0
	stage.add_child(_swatch)
	_tag_slot = Control.new()
	_tag_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag_slot.position = Vector2(-4.0, -2.0)
	stage.add_child(_tag_slot)
	_name_label = UiKit.label("", &"LabelSection", HORIZONTAL_ALIGNMENT_CENTER)
	_name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	_name_label.custom_minimum_size = Vector2(0, 36.0)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_name_label)
	# Fiyat yuvası: kilitli kartta Hamur fiyatı; sahip olunan kartta BOŞ ama
	# yüksekliği kalır — durum plakası komşu kartların SATIN AL hizasına oturur
	# (grid ritmi bozulmaz).
	var price_slot := Control.new()
	price_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_slot.custom_minimum_size = Vector2(0, 32.0)
	column.add_child(price_slot)
	_price_row = UiKit.price_row(DOUGH_ART, 0)
	_price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_price_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	(_price_row.get_child(0) as TextureRect).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_price_label = _price_row.get_child(1) as Label
	price_slot.add_child(_price_row)
	# Sahip olunan kartta fiyat yerine ipucu ("Koleksiyon'da tak"): kart çıkmaz
	# sokak olmasın, yuva boş kalmasın.
	_hint_label = UiKit.label("", &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint_label.visible = false
	price_slot.add_child(_hint_label)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size = Vector2(0, 4.0)
	column.add_child(gap)
	# Eylem alanı: SATIN AL butonu ya da durum plakası (aynı 64 px yuva).
	var action := Control.new()
	action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action.custom_minimum_size = Vector2(0, BUY_HEIGHT)
	column.add_child(action)
	_buy = UiKit.candy_button(BUY_TEXT, &"ButtonPrimary", BUY_HEIGHT)
	_buy.name = "Buy"
	_buy.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Butondan baslayan dikey surukleme Magaza'yi kaydirsin (06.3, A36: STOP
	# ile 0 px); dokunus yine tek `pressed` -> buy_requested.
	UiKit.make_candy_button_scrollable(_buy)
	_buy.pressed.connect(func() -> void:
		if _skin != null:
			buy_requested.emit(_skin))
	action.add_child(_buy)
	_owned_plate = UiKit.panel(&"OwnedBadge")
	_owned_plate.name = "StatePlate"
	_owned_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_owned_plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var owned_row := HBoxContainer.new()
	owned_row.alignment = BoxContainer.ALIGNMENT_CENTER
	owned_row.add_theme_constant_override("separation", 6)
	owned_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_owned_plate.add_child(owned_row)
	_owned_icon = UiKit.icon("check", 24, UiTokens.TEXT_ON_ACCENT)
	_owned_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	owned_row.add_child(_owned_icon)
	_owned_label = UiKit.label("", &"LabelBadge", HORIZONTAL_ALIGNMENT_CENTER)
	_owned_label.add_theme_font_size_override("font_size", 20)
	owned_row.add_child(_owned_label)
	_owned_plate.visible = false
	action.add_child(_owned_plate)
	_owned_plate.minimum_size_changed.connect(_layout_state_plate)
	for spec in LEGENDARY_SPARKLES:
		var spark := UiKit.art(SPARKLE_ART, float(spec[1]))
		spark.position = (spec[0] as Vector2) - Vector2(float(spec[1]), float(spec[1])) * 0.5
		spark.size = Vector2(float(spec[1]), float(spec[1]))
		spark.pivot_offset = spark.size * 0.5
		spark.visible = false
		add_child(spark)
		_sparkles.append(spark)


## Sahip/takılı plakasını eylem yuvasında ortalar (içerik genişliğine göre).
func _layout_state_plate() -> void:
	var min: Vector2 = _owned_plate.get_combined_minimum_size()
	var w: float = maxf(min.x, 184.0)
	var h: float = maxf(min.y, 50.0)
	_owned_plate.offset_left = -w * 0.5
	_owned_plate.offset_right = w * 0.5
	_owned_plate.offset_top = -h * 0.5
	_owned_plate.offset_bottom = h * 0.5


func setup(entry: SkinEntry) -> void:
	_id = entry.id
	_skin = entry.skin
	_rarity = int(entry.rarity)
	name = "SkinCard_%s" % String(_id)
	_name_label.text = entry.display_name
	if _tag != null:
		_tag.queue_free()
	_tag = UiKit.rarity_tag(_rarity)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.position = Vector2.ZERO
	_tag_slot.add_child(_tag)
	# Rarity dili (05.1 kalibrasyonu): Common nötr açık lavanta halka (sessiz),
	# Rare okunur soğuk mavi halka (beyaza %25 — eskiden %42, soluk kalıyordu),
	# Epic zengin lavanta-mor halka (%22) + hafif hale, Legendary altın halka +
	# geniş altın hale + pırıltı + hafif sıcak (altın-krem) gövde. Karakterin
	# arkasındaki radyal hale de rarity renginde (Common lavanta), düşük alfa.
	# Hale/halka/parıltı dışında gövde aynı: kart bütünüyle doygunlaşmaz.
	var rarity_color: Color = UiTokens.rarity_color(_rarity)
	var glow_color: Color = rarity_color
	match _rarity:
		SkinData.Rarity.RARE:
			_rim.self_modulate = rarity_color.lerp(Color.WHITE, 0.25)
			_halo.visible = false
		SkinData.Rarity.EPIC:
			_rim.self_modulate = rarity_color.lerp(Color.WHITE, 0.22)
			_halo.self_modulate = Color(rarity_color, 0.34)
			_halo.visible = true
		SkinData.Rarity.LEGENDARY:
			_rim.self_modulate = UiTokens.GOLD
			_halo.self_modulate = Color(UiTokens.GOLD_BRIGHT, 0.65)
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
	# Kilitli skin de gerçek sanatıyla (owner kararı, M8.5-14): oyuncu ne
	# aldığını görsün; kilit rozeti + fiyat "senin değil" bilgisini taşır.
	_swatch.setup(entry, true)
	_price_label.text = "%d Hamur" % entry.price
	_price_row.visible = _state == State.LOCKED
	_hint_label.visible = _state != State.LOCKED
	_hint_label.text = EQUIPPED_HINT if _state == State.EQUIPPED else OWNED_HINT
	_buy.visible = _state == State.LOCKED
	_owned_plate.visible = _state != State.LOCKED
	_body.theme_type_variation = &"PanelShopCard" if _state == State.LOCKED else &"PanelShopCardOwned"
	# Legendary: satılık gövde hafif altın-krem (premium); sahip olunan
	# gövde yine bir ton geri vanilya.
	if _rarity == SkinData.Rarity.LEGENDARY and _state == State.LOCKED:
		_body.add_theme_stylebox_override("panel", UiKit.style("card_bevel_soft",
			UiTokens.CREAM.lerp(UiTokens.GOLD_BRIGHT, 0.12), Vector4(16, 14, 16, 20)))
	else:
		_body.remove_theme_stylebox_override("panel")
	if _state == State.EQUIPPED:
		_owned_plate.theme_type_variation = &"EquippedBadge"
		_owned_label.text = EQUIPPED_TEXT
		_owned_label.add_theme_color_override("font_color", UiTokens.TEXT_ON_ACCENT)
		_owned_icon.visible = true
		_owned_icon.self_modulate = UiTokens.TEXT_ON_ACCENT
	elif _state == State.OWNED:
		_owned_plate.theme_type_variation = &"OwnedBadge"
		_owned_label.text = OWNED_TEXT
		_owned_label.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
		_owned_icon.visible = true
		_owned_icon.self_modulate = UiTokens.MINT_DEEP
	_layout_state_plate()
	set_affordable(entry.can_afford() if _state == State.LOCKED else true)


func set_affordable(affordable: bool) -> void:
	_affordable = affordable
	UiKit.set_candy_button_variation(_buy, &"ButtonPrimary" if affordable else &"ButtonBuyLocked")
	var dough_icon: TextureRect = _price_row.get_child(0)
	if affordable:
		_price_label.remove_theme_color_override("font_color")
		dough_icon.self_modulate = Color.WHITE
	else:
		_price_label.add_theme_color_override("font_color", UiTokens.PINK_DEEP)
		dough_icon.self_modulate = Color(1, 1, 1, 0.6)


## Hamur yetmedi: kısa sallanma.
func reject() -> void:
	if _wiggle != null and _wiggle.is_valid():
		_wiggle.kill()
	pivot_offset = size * 0.5
	rotation = 0.0
	_wiggle = create_tween()
	_wiggle.tween_property(self, "rotation", deg_to_rad(-2.2), WIGGLE_TIME * 0.25)
	_wiggle.tween_property(self, "rotation", deg_to_rad(2.2), WIGGLE_TIME * 0.5)
	_wiggle.tween_property(self, "rotation", 0.0, WIGGLE_TIME * 0.25)


## Satın alma başarılı: durum plakası gelir, kart pop, önizleme pop.
func celebrate() -> void:
	refresh()
	UiMotion.pop(self, 1.04)
	UiMotion.pop(_swatch, 1.12)


## Legendary pırıltıları (ekran `_process`'inden; sinüs, RNG yok).
func tick_sparkles(time: float) -> void:
	if _rarity != SkinData.Rarity.LEGENDARY:
		return
	for i in _sparkles.size():
		var phase: float = float(LEGENDARY_SPARKLES[i][2])
		var twinkle: float = 0.35 + 0.55 * (0.5 + 0.5 * sin(TAU * time / 2.6 + phase))
		_sparkles[i].modulate.a = twinkle
		_sparkles[i].scale = Vector2.ONE * (0.75 + 0.35 * twinkle)


# --- Okuma (test / ekran) ----------------------------------------------------

func skin_id() -> StringName:
	return _id


func skin() -> SkinData:
	return _skin


func state() -> State:
	return _state


func is_owned() -> bool:
	return _state != State.LOCKED


func is_equipped() -> bool:
	return _state == State.EQUIPPED


func is_affordable() -> bool:
	return _affordable


func rarity() -> int:
	return _rarity


## ScrollContainer kaydirmaya baslayinca (parmak SATIN AL ustunde basladi ve
## surukledi) BaseButton basisi iptal eder ama button_up yaymaz: yazi dudagi
## ve 0.94 olcek burada geri alinir, buton basili kalmaz (06.3).
func _notification(what: int) -> void:
	if what == NOTIFICATION_SCROLL_BEGIN and _buy != null:
		UiKit.release_candy_button(_buy)


func buy_button() -> Button:
	return _buy


func state_plate() -> PanelContainer:
	return _owned_plate


func state_text() -> String:
	return _owned_label.text if _owned_plate.visible else ""


func price_text() -> String:
	return _price_label.text


func name_text() -> String:
	return _name_label.text


func swatch() -> SkinSwatch:
	return _swatch


func rarity_tag() -> PanelContainer:
	return _tag


func halo() -> Control:
	return _halo


func glow() -> Control:
	return _glow


func hint_text() -> String:
	return _hint_label.text if _hint_label.visible else ""


func price_row() -> HBoxContainer:
	return _price_row
