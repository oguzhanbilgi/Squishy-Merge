extends CanvasLayer
## Koleksiyon — production skin galerisi / gardırop (M8.6-06; GAME_DESIGN
## §5.3). Envanter tablosu DEĞİL: seçili karakter kahraman, galeri keşif.
##
##   ÜST      `ScreenTopBar` (sabit): oturmuş geri (→ Ana Sayfa) · pembe
##            "KOLEKSİYON" kurdelesi · Hamur pill'i + nane "+" (→ Mağaza:
##            kilitli skinlerin satın alma yeri).
##   VİTRİN   (sabit, satırın altında): rarity halesi + candy kaide üstünde
##            BÜYÜK gerçek skin sanatı (`SkinSwatch`, 296–320 px, nefes alır)
##            · ad · rarity etiketi + durum çipi · bağlama göre TEK eylem
##            (TAK / MAĞAZAYA GİT / TAKILI plakası) · KOLEKSİYON N/20 pill'i.
##   GALERİ   gerçek ScrollContainer (vitrinin altından tabana): en üstte
##            "Varsayılan" TABAN görünüm şeridi (geniş kart + ORİJİNAL rozeti;
##            koleksiyon skini değil, sayılmaz — GAME_DESIGN §5.3), sonra rarity
##            bölüm plakaları (YAYGIN / NADİR / EPİK / EFSANEVİ) + 3 sütun
##            `CollectionSkinCard` (20 katalog skini, katalog sırası).
##            Karta dokunmak yalnız SEÇER (vitrin güncellenir, kayıt
##            DEĞİŞMEZ); takma vitrindeki TAK ile. Alt sekme çubuğu YOK.
##   ZEMİN    candy-night dünya (ShellBackdrop) Home ayarında + erik vignette;
##            vitrin dünyanın üstünde durur, ekranı krem plaka kaplamaz.
##
## Kayıt: yalnız `SaveManager.equip_skin` (kanonik, tek yazma) ve yalnız TAK
## ile. Koleksiyon Hamur harcamaz, skin vermez, satın almaz — kilitli skin
## Mağaza'ya yönlendirilir (`shop_skin_requested` → Mağaza o karta kaydırır).
## Durum `SkinEntry` tek kaynak;
## `skin_granted` / `skin_equipped` sinyalleriyle senkron (görünmezken gelen
## yeni skin bir sonraki açılışta vitrine alınır — oyuncu yeni skinini büyük
## görür ve TAK der).

## Üst satırdaki geri butonu (→ Ana Sayfa, main._on_home_requested).
signal home_requested
## Hamur "+" (→ Mağaza, main._on_shop_requested).
signal shop_requested
## Kilitli skin'in MAĞAZAYA GİT'i: Mağaza o skin'in kartına kaydırır
## (main → ShopScreen.focus_skin). Koleksiyon satın ALMAZ.
signal shop_skin_requested(skin_id: StringName)

const TITLE: String = "KOLEKSİYON"
const SIDE_MARGIN: float = 24.0
const COLUMNS: int = 3
const COLUMN_GAP: float = 12.0
const ROW_GAP: float = 12.0
const SECTION_GAP: float = 12.0
const GALLERY_TOP_PAD: float = 14.0
## Vitrin altı dikişi: vitrinin gölgesi galeriye düşer — üstte 18 px sıfırdan
## kesim çizgisine .82'ye, altta 42 px'te sıfıra (kartlar bir yüzeyin
## ALTINA kayar, düz kesilmez).
const GALLERY_HAZE_ABOVE: float = 18.0
const GALLERY_HAZE_BELOW: float = 42.0
const BOTTOM_PADDING: float = 64.0
## Üst haze: yalnız satır bandında (0..bar.height()) — vitrin halesi satırın
## arkasında sönük kalır; bandın son HAZE_FADE px'i sıfıra solar, vitrin
## sanatına hiç dokunmaz.
const HAZE_FADE: float = 24.0
## Vitrin ölçüleri (720 tuval; sanat uzun ekranda ART_SIZE_TALL'a büyür).
const ART_SIZE: float = 296.0
const ART_SIZE_TALL: float = 320.0
const HALO_SIZE: float = 520.0
const BLOOM_SIZE: float = 640.0
## Candy kaide: krem üst yüzey (yassı elips) + koyu lavanta alt kalınlık
## (PEDESTAL_LIP px aşağı taşar) + rarity renginde halka + erik temas gölgesi.
const PEDESTAL_SIZE: Vector2 = Vector2(324.0, 54.0)
const PEDESTAL_LIP: float = 8.0
const PEDESTAL_SHADOW: Vector2 = Vector2(430.0, 136.0)
## Kaide üst yüzeyi rarity rengine hafif boyanır (Rare/Epic bir bakışta).
const PEDESTAL_TINT: float = 0.16
## Karakterin ayakları sanat kutusunun bu oranında; kaide merkezi ayakların
## biraz üstünde ki karakter kaideye OTURSUN (havada durmasın).
const FEET_RATIO: float = 0.87
const PEDESTAL_SINK: float = 10.0
## Vitrin kilit rozeti: sanat kutusunun %26'sı (~69 px) — gövdeyi kapatmaz.
const SHOWCASE_LOCK_RATIO: float = 0.26
## Ad satırı: Baloo 34'ün satır kutusu ~55 px (ölçüldü) — kutu ona göre.
const NAME_HEIGHT: float = 56.0
## Etiket satırı: rarity trapezi 18 px yazı + durum çipi (frame_round20
## 34 px) — satır çipin minimumu.
const TAG_ROW_HEIGHT: float = 34.0
const CTA_SIZE: Vector2 = Vector2(320.0, 60.0)
const PROGRESS_SIZE: Vector2 = Vector2(264.0, 52.0)
const SHOWCASE_TOP_PAD: float = 2.0
const SHOWCASE_BOTTOM_PAD: float = 12.0
const TRANSITION_TIME: float = 0.2
const ENTRY_TIME: float = 0.18
const BREATH_PERIOD: float = 3.4
const BREATH_SCALE: float = 0.012
const BREATH_RISE: float = 3.0
const TAK_TEXT: String = "TAK"
const SHOP_TEXT: String = "MAĞAZAYA GİT"
const EQUIPPED_TEXT: String = "TAKILI"
const OWNED_TEXT: String = "SAHİPSİN"
const PROGRESS_TEXT: String = "KOLEKSİYON"
const STAR_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
const DOUGH_ART: Texture2D = ScreenTopBar.DOUGH_ART
## Vitrin çevresindeki sabit pırıltılar: sanat kutusuna göre (merkez 0,0;
## birim = sanat yarıçapı), boyut, faz. Sinüs, RNG yok.
const SHOWCASE_STARS: Array = [
	[Vector2(-1.16, -0.62), 22.0, 0.0], [Vector2(1.12, -0.78), 16.0, 1.3],
	[Vector2(-1.30, 0.22), 14.0, 2.6], [Vector2(1.28, 0.30), 20.0, 3.9],
	[Vector2(-0.82, -1.06), 12.0, 5.1], [Vector2(0.96, 0.92), 12.0, 0.7],
]
## Rarity halesi alfa (vitrin) — Legendary'de ek sıcak altın bloom.
const HALO_ALPHA: Dictionary = {
	SkinData.Rarity.COMMON: 0.42, SkinData.Rarity.RARE: 0.58,
	SkinData.Rarity.EPIC: 0.62, SkinData.Rarity.LEGENDARY: 0.62,
}
const DEFAULT_RARITY_UPPER: String = "ORİJİNAL"
const BURST_COUNT: int = 8
const BURST_TIME: float = 0.55
## Bölüm plakası tonu = rarity sözlüğü (etiket / halka ile aynı aile):
## YAYGIN gri-lavanta (Common gri; mor Epic'in), NADİR mavi, EPİK mor,
## EFSANEVİ altın (beyaz yazı için bir kademe koyu).
const SECTION_TINTS: Dictionary = {
	SkinData.Rarity.COMMON: Color("8a8aa8"),
	SkinData.Rarity.RARE: Color("3f86d0"),
	SkinData.Rarity.EPIC: Color("8e4fc0"),
	SkinData.Rarity.LEGENDARY: Color("d99a2b"),
}
## Bölüm plakası ile ilk kart sırası arası (sıra aralığıyla aynı ritim).
const HEADER_GAP: float = 6.0

var _bar: ScreenTopBar
var _cards: Array[CollectionSkinCard] = []
## id (String) -> kart; varsayılan "" anahtarında.
var _card_by_id: Dictionary = {}
var _headers: Array[Control] = []
var _selected_id: StringName = SkinEntry.DEFAULT_ID
var _pending_focus: StringName = SkinEntry.DEFAULT_ID
var _has_pending_focus: bool = false
# Vitrin parçaları
var _halo: NinePatchRect
var _bloom: NinePatchRect
var _pedestal_shadow: NinePatchRect
var _pedestal_rim: NinePatchRect
var _pedestal_lip: NinePatchRect
var _pedestal: NinePatchRect
var _pedestal_gloss: NinePatchRect
var _stars: Array[TextureRect] = []
var _art_wrap: Control
var _breath: Control
var _swatch: SkinSwatch
var _name_label: Label
var _tag_row: HBoxContainer
var _tag_slot: Control
var _tag: PanelContainer
var _state_chip: PanelContainer
var _state_icon: TextureRect
var _state_label: Label
var _cta: Button
## TAKILI plakası: sarmalayıcı Control (gölge + halka + gloss burada — bir
## PanelContainer çocuklarını içerik dikdörtgenine oturtur, dekor kaybolurdu)
## + içinde nane `title_oval` PanelContainer (yalnız satır).
var _equipped_wrap: Control
var _equipped_plate: PanelContainer
var _progress_wrap: Control
var _progress_caption: Label
var _progress_count: Label
var _progress_star: TextureRect
var _progress_bar: ProgressBar
var _burst: Array[TextureRect] = []
var _burst_tween: Tween
var _transition: Tween
var _entry_tween: Tween
var _time: float = 0.0
var _art_home_y: float = 0.0
## Test kancası: cihaz üst güvenli payı (A36 punch-hole) masaüstünde
## okunamaz; negatif = gerçek değeri kullan.
var _safe_top_override: float = -1.0

@onready var _root: Control = $Root
@onready var _backdrop: Control = $Root/Backdrop
@onready var _vignette: TextureRect = $Root/Vignette
@onready var _showcase: Control = $Root/Showcase
@onready var _scroll: ScrollContainer = $Root/Gallery
@onready var _margin: MarginContainer = $Root/Gallery/Margin
@onready var _content: VBoxContainer = $Root/Gallery/Margin/Content
@onready var _gallery_haze: TextureRect = $Root/GalleryHaze
@onready var _haze: TextureRect = $Root/Haze
@onready var _fx: Control = $Root/Fx


func _ready() -> void:
	_tune_backdrop()
	_vignette.texture = _radial_vignette()
	_haze.texture = _band_gradient(Color(UiTokens.WORLD_INDIGO, 0.72), Color(UiTokens.WORLD_INDIGO, 0.0))
	_gallery_haze.texture = _seam_gradient(Color(UiTokens.WORLD_INDIGO, 0.82),
		GALLERY_HAZE_ABOVE / (GALLERY_HAZE_ABOVE + GALLERY_HAZE_BELOW))
	_bar = ScreenTopBar.new(TITLE, true)
	_bar.back_pressed.connect(func() -> void: home_requested.emit())
	_bar.add_pressed.connect(func() -> void: shop_requested.emit())
	_root.add_child(_bar)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_build_showcase()
	_build_gallery()
	_build_burst()
	_root.resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		set_process(visible)
		if visible:
			_layout()
			_play_entry.call_deferred())
	set_process(visible)
	SaveManager.skin_granted.connect(_on_skin_granted)
	SaveManager.skin_equipped.connect(_on_skin_equipped)
	_layout()
	refresh()


# --- Kurulum ------------------------------------------------------------------

## Kabuk zemini Home/Mağaza ayarında: gece kasabası görünür, karartma azalır.
func _tune_backdrop() -> void:
	var night: CanvasItem = _backdrop.get_node_or_null("Night")
	if night != null:
		night.modulate = Color(0.80, 0.78, 0.94, 1.0)
	var scrim: ColorRect = _backdrop.get_node_or_null("Scrim")
	if scrim != null:
		scrim.color = Color(0.07, 0.05, 0.18, 0.30)
	var fade: CanvasItem = _backdrop.get_node_or_null("BottomFade")
	if fade != null:
		fade.modulate = Color(1, 1, 1, 0.70)


## Vitrin: "candy kaide üstünde karakter" — profil kartı değil. Arkadan öne:
## rarity halesi (+ Legendary altın bloom) → erik temas gölgesi → rarity
## halkalı krem kaide (yassı elips) → kaide üst parlaması → pırıltılar →
## nefes alan sanat → ad → rarity etiketi + durum çipi → eylem yuvası
## (TAK / MAĞAZAYA GİT candy buton | TAKILI nane plakası) → ilerleme pill'i.
func _build_showcase() -> void:
	_showcase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloom = UiKit.patch("popup_glow", Color(UiTokens.GOLD_BRIGHT, 0.26))
	_bloom.name = "Bloom"
	_bloom.visible = false
	_showcase.add_child(_bloom)
	_halo = UiKit.patch("popup_glow", Color(UiTokens.LAVENDER, 0.3))
	_halo.name = "Halo"
	_showcase.add_child(_halo)
	_pedestal_shadow = UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.42))
	_pedestal_shadow.name = "PedestalShadow"
	_showcase.add_child(_pedestal_shadow)
	_pedestal_rim = UiKit.patch("item_circle_inner", UiTokens.LAVENDER_LIGHT)
	_pedestal_rim.name = "PedestalRim"
	_showcase.add_child(_pedestal_rim)
	_pedestal_lip = UiKit.patch("item_circle_inner", UiTokens.LAVENDER_DEEP)
	_pedestal_lip.name = "PedestalLip"
	_showcase.add_child(_pedestal_lip)
	_pedestal = UiKit.patch("item_circle_inner", UiTokens.TRAY_CREAM)
	_pedestal.name = "Pedestal"
	_showcase.add_child(_pedestal)
	_pedestal_gloss = UiKit.patch("item_circle_inner", Color(1, 1, 1, 0.55))
	_pedestal_gloss.name = "PedestalGloss"
	_showcase.add_child(_pedestal_gloss)
	for spec in SHOWCASE_STARS:
		var star := UiKit.art(STAR_ART, float(spec[1]))
		star.size = Vector2(float(spec[1]), float(spec[1]))
		star.pivot_offset = star.size * 0.5
		star.modulate.a = 0.55
		_showcase.add_child(star)
		_stars.append(star)
	_art_wrap = Control.new()
	_art_wrap.name = "Art"
	_art_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_showcase.add_child(_art_wrap)
	_breath = Control.new()
	_breath.name = "Breath"
	_breath.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_breath.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art_wrap.add_child(_breath)
	_swatch = SkinSwatch.new()
	_swatch.name = "Preview"
	_swatch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_swatch.lock_badge_ratio = SHOWCASE_LOCK_RATIO
	_breath.add_child(_swatch)
	_name_label = UiKit.label("", &"LabelTitleOnDark", HORIZONTAL_ALIGNMENT_CENTER)
	_name_label.name = "Name"
	_name_label.add_theme_font_size_override("font_size", 34)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_showcase.add_child(_name_label)
	_tag_row = HBoxContainer.new()
	_tag_row.name = "TagRow"
	_tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tag_row.add_theme_constant_override("separation", 10)
	_showcase.add_child(_tag_row)
	_tag_slot = Control.new()
	_tag_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tag_row.add_child(_tag_slot)
	# Durum çipi: SAHİPSİN (açık nane) ya da kilit + fiyat (koyu erik).
	_state_chip = UiKit.panel(&"OwnedBadge")
	_state_chip.name = "StateChip"
	_state_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chip_row := HBoxContainer.new()
	chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chip_row.add_theme_constant_override("separation", 5)
	chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state_chip.add_child(chip_row)
	# Fiyat çipinde Hamur ikonu (kilit zaten sanatın üstünde — çift kilit yok).
	_state_icon = UiKit.art(DOUGH_ART, 22)
	_state_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_state_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip_row.add_child(_state_icon)
	_state_label = UiKit.label("", &"LabelBadge", HORIZONTAL_ALIGNMENT_CENTER)
	_state_label.add_theme_font_size_override("font_size", 17)
	chip_row.add_child(_state_label)
	_tag_row.add_child(_state_chip)
	# Eylem yuvası: candy buton (TAK cyan / MAĞAZAYA GİT cyan) YA DA takılı
	# nane plakası — aynı yuva, aynı ölçü; iki hâkim buton yan yana olmaz.
	_cta = UiKit.candy_button(TAK_TEXT, &"ButtonPrimary", CTA_SIZE.y)
	_cta.name = "Cta"
	_cta.pressed.connect(_on_cta_pressed)
	_showcase.add_child(_cta)
	_equipped_wrap = Control.new()
	_equipped_wrap.name = "EquippedPlate"
	_equipped_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate_shadow := UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.22))
	UiKit.inset(plate_shadow, -12.0, -8.0, -12.0, -16.0)
	_equipped_wrap.add_child(plate_shadow)
	var plate_rim := UiKit.flat_plate("title_oval", UiTokens.LAVENDER_LIGHT)
	UiKit.inset(plate_rim, -3.0, -3.0, -3.0, -1.0)
	_equipped_wrap.add_child(plate_rim)
	_equipped_plate = UiKit.panel(&"EquippedBadge")
	_equipped_plate.name = "Plate"
	_equipped_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipped_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_equipped_plate.add_theme_stylebox_override("panel",
		UiKit.style("title_oval", UiTokens.MINT, Vector4(24, 6, 24, 12)))
	_equipped_wrap.add_child(_equipped_plate)
	var plate_row := HBoxContainer.new()
	plate_row.alignment = BoxContainer.ALIGNMENT_CENTER
	plate_row.add_theme_constant_override("separation", 8)
	plate_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipped_plate.add_child(plate_row)
	var check := UiKit.icon("check", 26, UiTokens.TEXT_ON_ACCENT)
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate_row.add_child(check)
	var equipped_label := UiKit.label(EQUIPPED_TEXT, &"LabelBadge", HORIZONTAL_ALIGNMENT_CENTER)
	equipped_label.add_theme_font_size_override("font_size", 24)
	plate_row.add_child(equipped_label)
	var plate_gloss := UiKit.patch("btn_bevel_light", Color(1, 1, 1, 0.30))
	plate_gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	plate_gloss.offset_left = 12.0
	plate_gloss.offset_right = -12.0
	plate_gloss.offset_top = 3.0
	plate_gloss.offset_bottom = 24.0
	_equipped_wrap.add_child(plate_gloss)
	_showcase.add_child(_equipped_wrap)
	_build_progress()


## KOLEKSİYON N/20 pill'i: Home üst satır pill'i dili (koyu lavanta
## `label_round` + açık halka + erik gölge + gloss); içinde başlık + sayı ve
## nane ilerleme rayı. 20/20: altın ray + yıldız.
func _build_progress() -> void:
	_progress_wrap = Control.new()
	_progress_wrap.name = "Progress"
	_progress_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow := UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.26))
	UiKit.inset(shadow, -14.0, -9.0, -14.0, -19.0)
	_progress_wrap.add_child(shadow)
	var rim := UiKit.flat_plate("label_round", UiTokens.LAVENDER_LIGHT)
	UiKit.inset(rim, -3.0, -3.0, -3.0, -3.0)
	_progress_wrap.add_child(rim)
	var pill := UiKit.panel(&"PanelHomePill")
	pill.name = "Pill"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.set_anchors_preset(Control.PRESET_FULL_RECT)
	pill.add_theme_stylebox_override("panel",
		UiKit.style("label_round", UiTokens.LAVENDER_DEEP, Vector4(16, 5, 16, 7)))
	_progress_wrap.add_child(pill)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(column)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	_progress_caption = UiKit.label(PROGRESS_TEXT, &"LabelBadgeOnDark")
	_progress_caption.add_theme_font_size_override("font_size", 15)
	_progress_caption.add_theme_color_override("font_color", UiTokens.TEXT_ON_DARK)
	_progress_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_progress_caption)
	_progress_star = UiKit.art(STAR_ART, 20)
	_progress_star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_star.visible = false
	row.add_child(_progress_star)
	_progress_count = UiKit.label("0/20", &"LabelStatOnDark")
	_progress_count.add_theme_font_size_override("font_size", 19)
	row.add_child(_progress_count)
	_progress_bar = UiKit.progress_bar(0.0, &"ProgressBarMint", 11.0)
	column.add_child(_progress_bar)
	var gloss := UiKit.patch("btn_bevel_light", Color(1, 1, 1, 0.26))
	gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_left = 8.0
	gloss.offset_right = -8.0
	gloss.offset_top = 3.0
	gloss.offset_bottom = 22.0
	_progress_wrap.add_child(gloss)
	_showcase.add_child(_progress_wrap)


## Galeri: en üstte "Varsayılan" taban görünüm şeridi (geniş kart, ORİJİNAL
## rozeti; GAME_DESIGN §5.3: ilk seçenek her zaman Varsayılan, seçilebilir —
## ama 20 koleksiyon skininden biri DEĞİL: YAYGIN plakasının ÜSTÜNDE, sayaca
## girmez), sonra rarity başına bölüm plakası + 3 sütunlu kart sıraları
## (katalog sırası: SkinLibrary rarity + id; YAYGIN Sade ile başlar). Sıralar
## `HBoxContainer` (ortalı): eksik son sıra (YAYGIN 3+3+2, EPİK 3+1, EFSANEVİ 2)
## ortada durur, sağda boş yuva kalmaz (GridContainer bunu yapamaz).
func _build_gallery() -> void:
	_content.add_theme_constant_override("separation", SECTION_GAP)
	var sections: Dictionary = {}
	for rarity in [SkinData.Rarity.COMMON, SkinData.Rarity.RARE,
			SkinData.Rarity.EPIC, SkinData.Rarity.LEGENDARY]:
		var header := UiKit.section_header(SkinData.rarity_display_upper(rarity),
			SECTION_TINTS[rarity])
		header.name = "Header_%s" % SkinData.rarity_name(rarity)
		_content.add_child(header)
		_headers.append(header)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, HEADER_GAP)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(spacer)
		var section := VBoxContainer.new()
		section.name = "Grid_%s" % SkinData.rarity_name(rarity)
		section.mouse_filter = Control.MOUSE_FILTER_IGNORE
		section.add_theme_constant_override("separation", int(ROW_GAP))
		_content.add_child(section)
		sections[rarity] = section
	for entry in SkinEntry.all(true):
		if entry.is_default():
			var base := CollectionSkinCard.create(entry, true)
			base.selected.connect(_on_card_selected)
			_content.add_child(base)
			_content.move_child(base, 0)
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, HEADER_GAP)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_content.add_child(gap)
			_content.move_child(gap, 1)
			_cards.append(base)
			_card_by_id[String(entry.id)] = base
			continue
		var card := CollectionSkinCard.create(entry)
		card.selected.connect(_on_card_selected)
		var section: VBoxContainer = sections[entry.rarity]
		var row: HBoxContainer = section.get_child(section.get_child_count() - 1) if section.get_child_count() > 0 else null
		if row == null or row.get_child_count() >= COLUMNS:
			row = HBoxContainer.new()
			row.name = "Row%d" % (section.get_child_count() + 1)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", int(COLUMN_GAP))
			section.add_child(row)
		row.add_child(card)
		_cards.append(card)
		_card_by_id[String(entry.id)] = card


## Takma kutlaması: sanat merkezinden dışarı uçan 8 owner yıldızı (havuz,
## bir kez kurulur).
func _build_burst() -> void:
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in BURST_COUNT:
		var star := UiKit.art(STAR_ART, 22.0)
		star.size = Vector2(22, 22)
		star.pivot_offset = star.size * 0.5
		star.visible = false
		_fx.add_child(star)
		_burst.append(star)


# --- Yerleşim -----------------------------------------------------------------

func _safe_top() -> float:
	if _safe_top_override >= 0.0:
		return _safe_top_override
	return UiKit.safe_top(_root.size)


## Uzun ekranda (tuval > 1280) vitrin sanatı büyür; fazla dikey alanın kalanı
## galeriye gider.
func _art_size() -> float:
	var extra: float = clampf((_root.size.y - 1280.0) / 280.0, 0.0, 1.0)
	return lerpf(ART_SIZE, ART_SIZE_TALL, extra)


func showcase_height() -> float:
	var art: float = _art_size()
	return SHOWCASE_TOP_PAD + art + 12.0 + NAME_HEIGHT + TAG_ROW_HEIGHT + 12.0 \
		+ CTA_SIZE.y + 12.0 + PROGRESS_SIZE.y + SHOWCASE_BOTTOM_PAD


func _layout() -> void:
	if _root == null or _bar == null:
		return
	var view: Vector2 = _root.size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var safe_top: float = _safe_top()
	_bar.layout(view.x, safe_top)
	_vignette.position = Vector2.ZERO
	_vignette.size = view
	_haze.position = Vector2.ZERO
	_haze.size = Vector2(view.x, _bar.height())
	var band: GradientTexture2D = _haze.texture as GradientTexture2D
	if band != null and band.gradient != null:
		band.gradient.offsets = PackedFloat32Array([0.0, maxf(_bar.height() - HAZE_FADE, 0.0) / _haze.size.y, 1.0])
	# Vitrin: satırın hemen altında, sabit.
	var show_h: float = showcase_height()
	_showcase.position = Vector2(0.0, _bar.height())
	_showcase.size = Vector2(view.x, show_h)
	_layout_showcase(view.x)
	# Galeri: vitrinin altından tabana; içerik kenar payı 24, altta rahat pay.
	var gallery_y: float = _showcase.position.y + show_h
	_scroll.position = Vector2(0.0, gallery_y)
	_scroll.size = Vector2(view.x, maxf(view.y - gallery_y, 0.0))
	_margin.add_theme_constant_override("margin_left", int(SIDE_MARGIN))
	_margin.add_theme_constant_override("margin_right", int(SIDE_MARGIN))
	_margin.add_theme_constant_override("margin_top", int(GALLERY_TOP_PAD))
	_margin.add_theme_constant_override("margin_bottom", int(BOTTOM_PADDING + UiKit.bottom_inset(view)))
	_gallery_haze.position = Vector2(0.0, gallery_y - GALLERY_HAZE_ABOVE)
	_gallery_haze.size = Vector2(view.x, GALLERY_HAZE_ABOVE + GALLERY_HAZE_BELOW)
	_fx.position = Vector2.ZERO
	_fx.size = view


func _layout_showcase(width: float) -> void:
	var art: float = _art_size()
	var cx: float = width * 0.5
	var art_top: float = SHOWCASE_TOP_PAD
	var art_center := Vector2(cx, art_top + art * 0.5)
	_art_wrap.position = Vector2(cx - art * 0.5, art_top)
	_art_wrap.size = Vector2(art, art)
	_art_wrap.pivot_offset = _art_wrap.size * 0.5
	_breath.pivot_offset = Vector2(art * 0.5, art * 0.86)
	_art_home_y = art_top
	_place_center(_halo, art_center, Vector2(HALO_SIZE, HALO_SIZE) * (art / ART_SIZE))
	_place_center(_bloom, art_center + Vector2(0, 10), Vector2(BLOOM_SIZE, BLOOM_SIZE) * (art / ART_SIZE))
	# Kaide: karakterin ayak hizasının biraz üstünde — karakter kaidenin üst
	# yarısına OTURUR; arkasından halka + krem yüzey, altından koyu kalınlık.
	var seat_y: float = art_top + art * FEET_RATIO - PEDESTAL_SINK
	_place_center(_pedestal_shadow, Vector2(cx, seat_y + 22.0), PEDESTAL_SHADOW)
	_place_center(_pedestal_rim, Vector2(cx, seat_y + PEDESTAL_LIP * 0.5), PEDESTAL_SIZE + Vector2(10, 10 + PEDESTAL_LIP))
	_place_center(_pedestal_lip, Vector2(cx, seat_y + PEDESTAL_LIP), PEDESTAL_SIZE)
	_place_center(_pedestal, Vector2(cx, seat_y), PEDESTAL_SIZE)
	_place_center(_pedestal_gloss, Vector2(cx, seat_y - 10.0), Vector2(PEDESTAL_SIZE.x * 0.58, 14.0))
	for i in _stars.size():
		var spec: Array = SHOWCASE_STARS[i]
		var star: TextureRect = _stars[i]
		var at: Vector2 = art_center + (spec[0] as Vector2) * art * 0.5
		star.position = at - star.size * 0.5
	var y: float = art_top + art + 12.0
	_name_label.position = Vector2(SIDE_MARGIN, y)
	_name_label.size = Vector2(width - SIDE_MARGIN * 2.0, NAME_HEIGHT)
	y += NAME_HEIGHT
	_tag_row.position = Vector2(SIDE_MARGIN, y)
	_tag_row.size = Vector2(width - SIDE_MARGIN * 2.0, TAG_ROW_HEIGHT)
	y += TAG_ROW_HEIGHT + 12.0
	_cta.position = Vector2(cx - CTA_SIZE.x * 0.5, y)
	_cta.size = CTA_SIZE
	_cta.pivot_offset = CTA_SIZE * 0.5
	_layout_equipped_plate(cx, y)
	y += CTA_SIZE.y + 12.0
	_progress_wrap.position = Vector2(cx - PROGRESS_SIZE.x * 0.5, y)
	_progress_wrap.size = PROGRESS_SIZE
	_progress_wrap.pivot_offset = PROGRESS_SIZE * 0.5


## TAKILI plakası CTA ile aynı ayak izi (320×60): takınca geometri değil
## yalnız malzeme değişir (yuva daralıp genişlemez).
func _layout_equipped_plate(cx: float, y: float) -> void:
	var min: Vector2 = _equipped_plate.get_combined_minimum_size()
	var w: float = maxf(min.x, CTA_SIZE.x)
	_equipped_wrap.position = Vector2(cx - w * 0.5, y)
	_equipped_wrap.size = Vector2(w, CTA_SIZE.y)
	_equipped_wrap.pivot_offset = _equipped_wrap.size * 0.5


static func _place_center(node: Control, center: Vector2, box: Vector2) -> void:
	# `UiKit.patch` tam dikdörtgen anchor'la gelir; serbest konum için sıfırla.
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = center - box * 0.5
	node.size = box
	node.pivot_offset = box * 0.5


# --- Tazeleme -----------------------------------------------------------------

## Sekmeye her girişte (main._show_tab): kartlar, vitrin, bakiye ve ilerleme
## kanonik modelden. Kartlar yeniden KURULMAZ. Seçim: görünmezken kazanılan
## yeni skin varsa o; yoksa takılı skin (varsayılan dahil). Kaydırma en üste.
func refresh() -> void:
	for card in _cards:
		card.refresh()
	_refresh_progress()
	_bar.set_value(str(SaveManager.dough()), false)
	var focus: StringName = SaveManager.equipped_skin_id()
	if _has_pending_focus:
		_has_pending_focus = false
		if _card_by_id.has(String(_pending_focus)):
			focus = _pending_focus
	select(focus, false)
	_scroll.scroll_vertical = 0


func _refresh_progress() -> void:
	var total: int = SkinLibrary.total_count()
	var owned: int = SkinEntry.owned_count()
	_progress_count.text = "%d/%d" % [owned, total]
	_progress_bar.value = float(owned) / float(maxi(total, 1))
	var complete: bool = total > 0 and owned >= total
	_progress_bar.theme_type_variation = &"ProgressBarGold" if complete else &"ProgressBarMint"
	_progress_star.visible = complete
	_progress_count.add_theme_color_override("font_color", UiTokens.GOLD_BRIGHT if complete else UiTokens.TEXT_ON_DARK)


## Seçim: vitrin bu girişi gösterir, kart halkası taşınır. Kayıt DEĞİŞMEZ.
func select(skin_id: StringName, animate: bool = true) -> void:
	if not _card_by_id.has(String(skin_id)):
		skin_id = SaveManager.equipped_skin_id()
	var changed: bool = skin_id != _selected_id
	_selected_id = skin_id
	for card in _cards:
		card.set_selected(card.skin_id() == skin_id)
	_refresh_showcase(animate and changed)


func _on_card_selected(skin_id: StringName) -> void:
	if skin_id == _selected_id:
		UiMotion.pop(_art_wrap, 1.04)
		return
	AudioManager.play(&"ui_select")
	select(skin_id, true)


func _refresh_showcase(animate: bool) -> void:
	var entry: SkinEntry = SkinEntry.find(_selected_id)
	if entry == null:
		entry = SkinEntry.equipped_entry()
		_selected_id = entry.id
	# Vitrin kilitli skin'i de gerçek sanatıyla gösterir (kilit rozetiyle).
	_swatch.setup(entry, true)
	_name_label.text = entry.display_name
	if _tag != null:
		# Aynı karede iki etiket üst üste çizilmesin: önce ağaçtan çıkar.
		_tag_slot.remove_child(_tag)
		_tag.queue_free()
		_tag = null
	if entry.is_default():
		_tag = UiKit.panel(&"RarityCommon")
		var text := UiKit.label(DEFAULT_RARITY_UPPER, &"LabelBadgeOnDark")
		_tag.add_child(text)
		_tag.set_meta(&"title_label", text)
	else:
		_tag = UiKit.rarity_tag(int(entry.rarity))
	(_tag.get_meta(&"title_label") as Label).add_theme_font_size_override("font_size", 18)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag_slot.add_child(_tag)
	_tag_slot.custom_minimum_size = _tag.get_combined_minimum_size()
	_tag.size = _tag_slot.custom_minimum_size
	# Durum çipi + eylem: tek hâkim eylem, aynı durum üç rozetle tekrarlanmaz.
	if entry.is_locked():
		_state_chip.visible = true
		_state_chip.add_theme_stylebox_override("panel",
			UiKit.style("frame_round20", UiTokens.NAVY_PURPLE, Vector4(12, 3, 14, 5)))
		_state_icon.texture = DOUGH_ART
		_state_icon.visible = true
		_state_label.text = "%d Hamur" % entry.price
		_state_label.add_theme_color_override("font_color", UiTokens.GOLD)
		_cta.visible = true
		(_cta.get_meta(&"title_label") as Label).text = SHOP_TEXT
		_equipped_wrap.visible = false
	elif entry.equipped:
		_state_chip.visible = false
		_cta.visible = false
		_equipped_wrap.visible = true
	else:
		_state_chip.visible = true
		_state_chip.remove_theme_stylebox_override("panel")
		_state_icon.visible = false
		_state_label.text = OWNED_TEXT
		_state_label.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
		_cta.visible = true
		(_cta.get_meta(&"title_label") as Label).text = TAK_TEXT
		_equipped_wrap.visible = false
	_layout_equipped_plate(_root.size.x * 0.5, _cta.position.y)
	# Rarity malzemesi: hale rengi/alfası, kaide halkası, Legendary bloom.
	var rarity: int = int(entry.rarity)
	var halo_color: Color = UiTokens.rarity_color(rarity)
	if entry.is_default() or rarity == SkinData.Rarity.COMMON:
		halo_color = UiTokens.LAVENDER
	elif rarity == SkinData.Rarity.LEGENDARY:
		halo_color = UiTokens.GOLD
	var halo_target := Color(halo_color, float(HALO_ALPHA.get(rarity, 0.3)))
	var rim_color: Color = UiTokens.LAVENDER_LIGHT
	match rarity:
		SkinData.Rarity.RARE: rim_color = UiTokens.RARITY_RARE.lerp(Color.WHITE, 0.3)
		SkinData.Rarity.EPIC: rim_color = UiTokens.RARITY_EPIC.lerp(Color.WHITE, 0.3)
		SkinData.Rarity.LEGENDARY: rim_color = UiTokens.GOLD
	_bloom.visible = rarity == SkinData.Rarity.LEGENDARY and not entry.is_default()
	_pedestal_rim.self_modulate = rim_color
	# Kaide yüzeyi rarity'ye hafif boyanır: Rare/Epic yalnız 3 px halkayla
	# değil, kaideyle de okunur; Common/Varsayılan nötr krem.
	var surface: Color = UiTokens.TRAY_CREAM
	if not entry.is_default() and rarity != SkinData.Rarity.COMMON:
		surface = UiTokens.TRAY_CREAM.lerp(halo_color, PEDESTAL_TINT)
	_pedestal.self_modulate = surface
	if animate:
		_play_transition(halo_target)
	else:
		if _transition != null and _transition.is_valid():
			_transition.kill()
		_halo.self_modulate = halo_target
		_art_wrap.scale = Vector2.ONE
		_art_wrap.modulate.a = 1.0


## Seçim geçişi (0.2 s, bloke etmez): sanat 0.94 → 1.0 + solma, hale retint.
func _play_transition(halo_target: Color) -> void:
	if _transition != null and _transition.is_valid():
		_transition.kill()
	_art_wrap.pivot_offset = _art_wrap.size * 0.5
	_art_wrap.scale = Vector2.ONE * 0.94
	_art_wrap.modulate.a = 0.45
	_transition = create_tween()
	_transition.set_parallel(true)
	_transition.tween_property(_art_wrap, "scale", Vector2.ONE, TRANSITION_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_transition.tween_property(_art_wrap, "modulate:a", 1.0, TRANSITION_TIME * 0.7)
	_transition.tween_property(_halo, "self_modulate", halo_target, TRANSITION_TIME)


func _play_entry() -> void:
	if not is_inside_tree() or not visible:
		return
	if _entry_tween != null and _entry_tween.is_valid():
		_entry_tween.kill()
	# Ekran girişi (0.18 s): vitrin + galeri solarak gelir (main'in
	# `UiMotion.screen_in`'i yalnız Container çocuklarını kaydırır; Root bir
	# Control — giriş hissi buradan).
	_scroll.modulate.a = 0.0
	_showcase.modulate.a = 0.0
	_entry_tween = create_tween()
	_entry_tween.set_parallel(true)
	_entry_tween.tween_property(_scroll, "modulate:a", 1.0, ENTRY_TIME)
	_entry_tween.tween_property(_showcase, "modulate:a", 1.0, ENTRY_TIME)


## Boşta: vitrin sanatı nefes alır (±%1.2 ölçek, 3 px süzülme), pırıltılar
## kısık sinüsle yanıp söner; Legendary kartların 2 pırıltısı. 21 kartın
## hiçbiri kendi _process'ini çalıştırmaz; gizliyken işlem yok.
func _process(delta: float) -> void:
	_time += delta
	var phase: float = TAU * _time / BREATH_PERIOD
	_breath.scale = Vector2.ONE * (1.0 + BREATH_SCALE * sin(phase))
	_breath.position.y = -BREATH_RISE * (0.5 + 0.5 * sin(phase))
	for i in _stars.size():
		var spec: Array = SHOWCASE_STARS[i]
		var twinkle: float = 0.35 + 0.5 * (0.5 + 0.5 * sin(TAU * _time / 2.6 + float(spec[2])))
		_stars[i].modulate.a = twinkle
		_stars[i].scale = Vector2.ONE * (0.8 + 0.3 * twinkle)
	for card in _cards:
		card.tick_sparkles(_time)


# --- Eylemler -----------------------------------------------------------------

## Vitrin eylemi: kilitli → Mağaza (Koleksiyon satın ALMAZ); sahip → TAK
## (kanonik equip, tek kayıt yazması, sinyal UI'yi günceller); takılı →
## buton zaten görünmez, hiçbir şey olmaz.
func _on_cta_pressed() -> void:
	var entry: SkinEntry = SkinEntry.find(_selected_id)
	if entry == null:
		return
	if entry.is_locked():
		shop_skin_requested.emit(entry.id)
		return
	if entry.equipped:
		return
	SaveManager.equip_skin(entry.id)


func _on_skin_equipped(skin_id: StringName) -> void:
	for card in _cards:
		card.refresh()
	if _selected_id != skin_id:
		select(skin_id, false)
	else:
		_refresh_showcase(false)
	if not visible:
		return
	AudioManager.play(&"ui_equip")
	Haptics.light()
	_celebrate()


## Takma kutlaması: sanat pop + TAKILI plakası pop + yıldız patlaması.
func _celebrate() -> void:
	UiMotion.pop(_art_wrap, 1.08)
	UiMotion.pop(_equipped_wrap, 1.10)
	var card: CollectionSkinCard = _card_by_id.get(String(_selected_id))
	if card != null:
		UiMotion.pop(card.equipped_plate(), 1.2)
	if _burst_tween != null and _burst_tween.is_valid():
		_burst_tween.kill()
	var center: Vector2 = _showcase.position + _art_wrap.position + _art_wrap.size * 0.5
	_burst_tween = create_tween()
	_burst_tween.set_parallel(true)
	for i in _burst.size():
		var star: TextureRect = _burst[i]
		var angle: float = TAU * float(i) / float(_burst.size()) - PI * 0.5
		var dir := Vector2(cos(angle), sin(angle))
		star.visible = true
		star.modulate = Color(UiTokens.GOLD_BRIGHT, 1.0)
		star.position = center + dir * 50.0 - star.size * 0.5
		star.scale = Vector2.ONE * 0.5
		_burst_tween.tween_property(star, "position", center + dir * 150.0 - star.size * 0.5, BURST_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_burst_tween.tween_property(star, "scale", Vector2.ONE * 1.1, BURST_TIME * 0.4)
		_burst_tween.tween_property(star, "modulate:a", 0.0, BURST_TIME * 0.5).set_delay(BURST_TIME * 0.5)
	_burst_tween.chain().tween_callback(func() -> void:
		for star in _burst:
			star.visible = false)


func _on_skin_granted(skin_id: StringName) -> void:
	if not visible:
		# Sekme açılınca refresh() geliyor (main.gd); o anda vitrine al.
		_pending_focus = skin_id
		_has_pending_focus = true
		return
	for card in _cards:
		card.refresh()
	_refresh_progress()
	select(skin_id, true)


# --- Dokular (programatik, asset yok) ----------------------------------------

static func _band_gradient(top: Color, bottom: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([top, top, bottom])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 8
	tex.height = 128
	return tex


## Galeri dikişi: vitrinin altında kartların kırpıldığı çizgi — ortası koyu,
## iki yana sıfıra solan yumuşak bant (sert kesim okunmaz, bant okunmaz).
static func _seam_gradient(peak: Color, peak_at: float = 0.5) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, peak_at, 1.0])
	gradient.colors = PackedColorArray([Color(peak, 0.0), peak, Color(peak, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 8
	tex.height = 128
	return tex


## Yumuşak erik vignette (Harita/Mağaza ile aynı): merkez temiz, kenarlar koyu.
static func _radial_vignette() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	gradient.colors = PackedColorArray([Color(0.2, 0.08, 0.32, 0.0),
		Color(0.2, 0.08, 0.32, 0.0), Color(0.2, 0.08, 0.32, 0.30)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 128
	tex.height = 128
	return tex


# --- Testler / çekim aracı ----------------------------------------------------

func _layout_with_safe_top(safe_top: float) -> void:
	_safe_top_override = safe_top
	_layout()


func top_bar() -> ScreenTopBar:
	return _bar


func scroll() -> ScrollContainer:
	return _scroll


func showcase() -> Control:
	return _showcase


func cards() -> Array[CollectionSkinCard]:
	return _cards


func card(skin_id: StringName) -> CollectionSkinCard:
	return _card_by_id.get(String(skin_id))


func section_headers() -> Array[Control]:
	return _headers


func selected_id() -> StringName:
	return _selected_id


func showcase_swatch() -> SkinSwatch:
	return _swatch


func showcase_name_text() -> String:
	return _name_label.text


func showcase_rarity_text() -> String:
	return (_tag.get_meta(&"title_label") as Label).text if _tag != null else ""


func showcase_state_text() -> String:
	if _equipped_wrap.visible:
		return EQUIPPED_TEXT
	return _state_label.text if _state_chip.visible else ""


func cta() -> Button:
	return _cta


func cta_text() -> String:
	return (_cta.get_meta(&"title_label") as Label).text if _cta.visible else ""


## TAKILI plakası (sarmalayıcı: görünürlük / dikdörtgen / pop burada).
func equipped_plate() -> Control:
	return _equipped_wrap


func state_chip() -> PanelContainer:
	return _state_chip


func progress_text() -> String:
	return _progress_count.text


func progress_bar() -> ProgressBar:
	return _progress_bar


func progress_plate() -> Control:
	return _progress_wrap


func halo() -> NinePatchRect:
	return _halo


func bloom() -> NinePatchRect:
	return _bloom


func pedestal() -> NinePatchRect:
	return _pedestal


func art_box() -> Control:
	return _art_wrap


func haze() -> TextureRect:
	return _haze
