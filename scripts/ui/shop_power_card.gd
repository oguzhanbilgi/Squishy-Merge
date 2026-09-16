class_name ShopPowerCard
extends Control
## Mağaza güç ürün kartı (M8.6-05). Dört tüketilebilir güç (Bomba / Büyütücü /
## Sarsıntı / Temizleyici) bu TEK bileşenden; ekran kodu halka/gloss kurmaz.
##
## Anatomi (arkadan öne):
##   erik gölge → açık lavanta halka → krem `card_bevel_soft` gövde
##   (PanelShopCard) → içerik sütunu: candy kuyu içinde OWNER güç sanatı
##   (odak noktası) · Baloo ad · kısa amaç (gerçek mekanik) · Hamur fiyatı ·
##   SATIN AL candy butonu → üst gloss → sağ üstte altın stok rozeti
##   ("Stok ×N", gameplay madalyonunun ×N rozetiyle aynı dil).
##
## Durumlar: NORMAL (cyan SATIN AL) · BASILI (buton squash + koyu gövde) ·
## HAMUR YETMİYOR (soluk cyan ButtonBuyLocked / CYAN_MUTED, fiyat koyu pembe;
## dokununca kart sallanır + ekran geri bildirim verir — sessiz başarısızlık
## yok) ·
## SATIN ALMA BAŞARILI (`celebrate`: pop + pırıltı, stok rozeti güncellenir).
## Stok 0 bir mağaza durumu DEĞİL: ürün Hamur yettiği sürece alınabilir.
##
## Ekonomi burada YOK: fiyat `PowerUpEconomy.price`, stok `SaveManager.
## powerup_count`, karar `PowerUpEconomy.can_afford`; satın alma ekranın
## kanonik yolundan (`PowerUpEconomy.purchase`). Kart yalnız `buy_requested`
## yayar. Kayda YAZMAZ.

signal buy_requested(type: PowerUp.Type)

## 372: gövde içeriğinin ÖLÇÜLEN minimumu (kuyu 128 + Baloo 24 ad 39 + iki
## satır Nunito 17 amaç 51 + fiyat 32 + 2 + SATIN AL 64 + 5×4 ayrım + 34 iç
## pay = 370) + 2 px pay; içerik kart dikdörtgenini aşmaz (testle).
const CARD_SIZE: Vector2 = Vector2(328.0, 372.0)
const BUY_HEIGHT: float = 64.0
const WELL_SIZE: float = 122.0
const WELL_ART_SIZE: float = 88.0
const BUY_TEXT: String = "SATIN AL"
const DOUGH_ART: Texture2D = preload("res://assets/visual/ui/icon_dough.png")
const SPARKLE_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
## Gücün ne yaptığı — GERÇEK mekanik (PowerUpController / GameBoard):
## Bomba seçilen tek dumpling'i yok eder; Büyütücü seçileni bir üst tier'a
## çıkarır (tier 8 hariç); Sarsıntı bütün canlı parçalara impulse uygular;
## Temizleyici tier 1–2 parçaları kaldırır (CLEAR_SMALL_MAX_TIER).
const PURPOSES: Dictionary = {
	PowerUp.Type.BOMB: "Seçtiğin dumpling'i\nyok eder",
	PowerUp.Type.UPGRADE: "Seçtiğin dumpling'i\nbir üst seviyeye çıkarır",
	PowerUp.Type.SHAKE: "Tahtayı sarsar,\nparçalar karışır",
	PowerUp.Type.CLEAR_SMALL: "Küçük dumpling'leri\n(1–2. boy) temizler",
}
const WIGGLE_TIME: float = 0.22

var _type: PowerUp.Type = PowerUp.Type.BOMB
var _affordable: bool = true
var _body: PanelContainer
var _well: Control
var _name_label: Label
var _purpose_label: Label
var _price_label: Label
var _price_row: HBoxContainer
var _buy: Button
var _stock_wrap: Control
var _stock_badge: PanelContainer
var _stock_label: Label
var _wiggle: Tween


static func create(type: PowerUp.Type) -> ShopPowerCard:
	var card := ShopPowerCard.new()
	card.setup(type)
	return card


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = CARD_SIZE
	# Gölge + halka: HUD v5 kart reçetesi (erik blob, açık lavanta düz plaka)
	# + halka ile gövde arasında 2 px erik kontur (harita düğümündeki gibi:
	# krem gövde açık halkanın içinde yüzmesin, candy kenar okunsun).
	var shadow := UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.34))
	UiKit.inset(shadow, -16.0, -6.0, -16.0, -26.0)
	add_child(shadow)
	var rim := UiKit.flat_plate("frame_round20", UiTokens.LAVENDER_LIGHT)
	UiKit.inset(rim, -5.0, -5.0, -5.0, -5.0)
	add_child(rim)
	var contour := UiKit.flat_plate("frame_round20", Color(UiTokens.LAVENDER_DEEP, 0.5))
	UiKit.inset(contour, -2.0, -2.0, -2.0, -2.0)
	add_child(contour)
	_body = UiKit.panel(&"PanelShopCardPower")
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_body)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.add_theme_constant_override("separation", 4)
	_body.add_child(column)
	# Kuyu: ortada, gövdeden 6 px oturak payıyla.
	_well = UiKit.candy_well(null, UiTokens.CYAN, WELL_SIZE, WELL_ART_SIZE)
	_well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_well)
	_name_label = UiKit.label("", &"LabelSection", HORIZONTAL_ALIGNMENT_CENTER)
	_name_label.custom_minimum_size = Vector2(0, 32.0)
	column.add_child(_name_label)
	_purpose_label = UiKit.label("", &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
	# 17 px: 540×960 telefonda ~13 px fiziksel — gücün ne yaptığı yalnız burada.
	_purpose_label.add_theme_font_size_override("font_size", 17)
	_purpose_label.custom_minimum_size = Vector2(0, 46.0)
	_purpose_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	column.add_child(_purpose_label)
	_price_row = UiKit.price_row(DOUGH_ART, 0)
	_price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_price_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_price_row.custom_minimum_size = Vector2(0, 32.0)
	(_price_row.get_child(0) as TextureRect).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_price_label = _price_row.get_child(1) as Label
	column.add_child(_price_row)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size = Vector2(0, 2.0)
	column.add_child(gap)
	_buy = UiKit.candy_button(BUY_TEXT, &"ButtonPrimary", BUY_HEIGHT)
	_buy.name = "Buy"
	_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy.pressed.connect(func() -> void: buy_requested.emit(_type))
	column.add_child(_buy)
	# Üst gloss: kartın üst şeridi (kuyunun tepesine hafif biner — candy plaka).
	var gloss := UiKit.patch("btn_bevel_light", Color(1, 1, 1, 0.30))
	gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_left = 10.0
	gloss.offset_right = -10.0
	gloss.offset_top = 3.0
	gloss.offset_bottom = 22.0
	add_child(gloss)
	# Stok rozeti: sağ üst köşe, altın (HUD madalyonunun ×N rozeti). Krem
	# halka rozetin İÇİNE konmaz (PanelContainer çocuklarını içerik
	# dikdörtgenine yerleştirir, halka görünmezdi): sarmalayıcı düz Control
	# içinde halka + rozet kardeş; sarmalayıcı rozetin minimumuna göre sola
	# büyür ("Stok ×12" sığar).
	_stock_wrap = Control.new()
	_stock_wrap.name = "Stock"
	_stock_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stock_wrap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_stock_wrap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_stock_wrap.grow_vertical = Control.GROW_DIRECTION_END
	var badge_rim := UiKit.flat_plate("badge_round", UiTokens.CREAM)
	UiKit.inset(badge_rim, -2.0, -2.0, -2.0, -2.0)
	_stock_wrap.add_child(badge_rim)
	_stock_badge = UiKit.panel(&"Badge")
	_stock_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stock_badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stock_wrap.add_child(_stock_badge)
	_stock_label = UiKit.label("", &"LabelBadge", HORIZONTAL_ALIGNMENT_CENTER)
	_stock_label.add_theme_font_size_override("font_size", 16)
	_stock_badge.add_child(_stock_label)
	add_child(_stock_wrap)
	_stock_badge.minimum_size_changed.connect(_layout_stock_badge)
	_layout_stock_badge()


## Rozet sarmalayıcısı: sağ üst köşeden 6/8 px taşar, genişlik içeriğe göre
## (min 72×30), sola doğru büyür.
func _layout_stock_badge() -> void:
	var min: Vector2 = _stock_badge.get_combined_minimum_size()
	var w: float = maxf(min.x, 72.0)
	var h: float = maxf(min.y, 30.0)
	_stock_wrap.offset_right = 6.0
	_stock_wrap.offset_left = 6.0 - w
	_stock_wrap.offset_top = -8.0
	_stock_wrap.offset_bottom = -8.0 + h


func setup(type: PowerUp.Type) -> void:
	_type = type
	name = "PowerCard_%s" % PowerUp.save_key(type)
	var accent: Color = PowerUp.accent(type)
	(_well.get_meta(&"art") as TextureRect).texture = PowerUp.icon(type)
	UiKit.set_candy_well_accent(_well, accent)
	_name_label.text = PowerUp.display_name(type)
	_purpose_label.text = String(PURPOSES.get(type, ""))
	_price_label.text = "%d Hamur" % PowerUpEconomy.price(type)
	refresh()


## Stok ve Hamur durumunu kanonik modelden yeniden okur (kayda yazmaz).
func refresh() -> void:
	_stock_label.text = "Stok ×%d" % SaveManager.powerup_count(_type)
	set_affordable(PowerUpEconomy.can_afford(_type))


## Hamur yetiyor mu: cyan SATIN AL / soluk cyan "yetmiyor" (dokununca geri
## bildirim) + fiyat koyu pembe, Hamur ikonu soluk. Buton hiçbir zaman
## `disabled` değil.
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


## Hamur yetmedi: kart kısa sallanır (kilitli harita düğümüyle aynı dil).
func reject() -> void:
	if _wiggle != null and _wiggle.is_valid():
		_wiggle.kill()
	pivot_offset = size * 0.5
	rotation = 0.0
	_wiggle = create_tween()
	_wiggle.tween_property(self, "rotation", deg_to_rad(-2.2), WIGGLE_TIME * 0.25)
	_wiggle.tween_property(self, "rotation", deg_to_rad(2.2), WIGGLE_TIME * 0.5)
	_wiggle.tween_property(self, "rotation", 0.0, WIGGLE_TIME * 0.25)


## Satın alma başarılı: küçük pop + stok rozeti pop + birkaç yıldız
## parıltısı (UI-yerel, RNG yok — sabit açılar).
func celebrate() -> void:
	refresh()
	UiMotion.pop(self, 1.04)
	UiMotion.pop(_stock_wrap, 1.25)
	for i in 5:
		var angle: float = -PI * 0.5 + (float(i) - 2.0) * 0.55
		var spark := UiKit.art(SPARKLE_ART, 22.0)
		spark.modulate = Color(1.0, 0.92, 0.6, 1.0)
		var origin: Vector2 = Vector2(size.x * 0.5, WELL_SIZE * 0.5 + 14.0)
		spark.position = origin - Vector2(11.0, 11.0)
		spark.pivot_offset = Vector2(11.0, 11.0)
		spark.scale = Vector2(0.4, 0.4)
		add_child(spark)
		var tween := spark.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", spark.position + Vector2(cos(angle), sin(angle)) * 74.0, 0.42) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "scale", Vector2(1.0, 1.0), 0.2)
		tween.tween_property(spark, "modulate:a", 0.0, 0.3).set_delay(0.16)
		tween.chain().tween_callback(spark.queue_free)


# --- Okuma (test / ekran) ----------------------------------------------------

func type() -> PowerUp.Type:
	return _type


func is_affordable() -> bool:
	return _affordable


func buy_button() -> Button:
	return _buy


func stock_text() -> String:
	return _stock_label.text


func price_text() -> String:
	return _price_label.text


func purpose_text() -> String:
	return _purpose_label.text


func name_text() -> String:
	return _name_label.text


func well() -> Control:
	return _well


func price_row() -> HBoxContainer:
	return _price_row
