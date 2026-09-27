extends CanvasLayer
## Koleksiyon — koleksiyon parçaları (Squishy) ALBÜMÜ (M8.6-06 production
## ekranı; TASK/044 owner kararı: gameplay skinleri EMEKLİ, koleksiyon
## tamamlama / statü hedefi). Envanter tablosu DEĞİL: kartlar albümün kendisi,
## dokunulan parça büyük detay penceresinde incelenir.
##
##   ÜST      `ScreenTopBar` (sabit): oturmuş geri (→ Ana Sayfa) · pembe
##            "KOLEKSİYON" kurdelesi · Hamur pill'i + nane "+" (→ Mağaza:
##            kilitli parçaların satın alma yeri).
##   BAŞLIK   (sabit, satırın altında) albüm plakası: KOLEKSİYON N/20 + nane
##            ilerleme rayı (20/20 altın + yıldız) · altın VİTRİN N/3 çipi ·
##            rarity başına sayaç çipleri (YAYGIN / NADİR / EPİK / EFSANEVİ).
##   ALBÜM    gerçek ScrollContainer (başlığın altından tabana): rarity bölüm
##            plakaları + 3 sütun `CollectionSkinCard` (20 katalog parçası,
##            katalog sırası). "Varsayılan" kart YOK (TASK/044: takılacak bir
##            görünüm kalmadı; kanonik Squishy bir koleksiyon parçası değil).
##   DETAY    karta dokunmak detay penceresini açar (`UiKit.modal_shell`,
##            "SQUISHY" kurdelesi): `CollectibleStage` (rarity halesi + candy
##            kaide + nefes alan GERÇEK sanat) · KOLEKSİYON PARÇASI · ad ·
##            rarity etiketi + durum çipi · kısa açıklama · eylem:
##              sahip, vitrinde değil → VİTRİNE EKLE (vitrin doluysa AÇIK bir
##                                       "hangisinin yerine?" adımı — sessiz /
##                                       rastgele değiştirme YOK)
##              vitrinde              → VİTRİNDEN ÇIKAR (+ ilk yuvada değilse
##                                       AVATAR YAP)
##              kilitli               → MAĞAZAYA GİT (Koleksiyon satın ALMAZ)
##   ZEMİN    candy-night dünya (ShellBackdrop) Home ayarında + erik vignette.
##
## Kayıt: yalnız SaveManager'ın vitrin işlemleri (`showcase_add` / `_remove` /
## `_replace` / `_make_first` — kanonik, tek yazma) ve yalnız detay eylemleriyle.
## Koleksiyon Hamur harcamaz, parça vermez, satın almaz; gameplay'e hiçbir etkisi
## yok. Durum `SkinEntry` tek kaynak; `skin_granted` / `showcase_changed`
## sinyalleriyle senkron (görünmezken keşfedilen yeni parça bir sonraki açılışta
## albümde öne alınır).

## Üst satırdaki geri butonu (→ Ana Sayfa, main._on_home_requested).
signal home_requested
## Hamur "+" (→ Mağaza, main._on_shop_requested).
signal shop_requested
## Kilitli parçanın MAĞAZAYA GİT'i: Mağaza o parçanın kartına kaydırır
## (main → ShopScreen.focus_skin). Koleksiyon satın ALMAZ.
signal shop_skin_requested(skin_id: StringName)

const TITLE: String = "KOLEKSİYON"
const SIDE_MARGIN: float = 24.0
const COLUMNS: int = 3
const COLUMN_GAP: float = 12.0
const ROW_GAP: float = 12.0
const SECTION_GAP: float = 12.0
const GALLERY_TOP_PAD: float = 16.0
## Başlık altı dikişi: başlığın gölgesi albüme düşer (kartlar bir yüzeyin
## ALTINA kayar, düz kesilmez).
const GALLERY_HAZE_ABOVE: float = 14.0
const GALLERY_HAZE_BELOW: float = 36.0
const BOTTOM_PADDING: float = 64.0
## Üst haze: yalnız satır bandında; son HAZE_FADE px sıfıra solar.
const HAZE_FADE: float = 24.0
const HEADER_GAP: float = 10.0
const HEADER_HEIGHT: float = 128.0
const HEADER_AFTER: float = 6.0
const PROGRESS_TEXT: String = "KOLEKSİYON"
const SHOWCASE_CHIP_TEXT: String = "VİTRİN %d/%d"
const STAR_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
const DOUGH_ART: Texture2D = ScreenTopBar.DOUGH_ART
## Bölüm plakası tonu = rarity sözlüğü (etiket / halka ile aynı aile).
const SECTION_TINTS: Dictionary = {
	SkinData.Rarity.COMMON: Color("8a8aa8"),
	SkinData.Rarity.RARE: Color("3f86d0"),
	SkinData.Rarity.EPIC: Color("8e4fc0"),
	SkinData.Rarity.LEGENDARY: Color("d99a2b"),
}
## Bölüm plakası ile ilk kart sırası arası.
const HEADER_SECTION_GAP: float = 6.0
const ENTRY_TIME: float = 0.18

# --- Detay penceresi ---
const DETAIL_TITLE: String = "SQUISHY"
const DETAIL_WIDTH: float = 600.0
const DETAIL_STAGE: Vector2 = Vector2(300.0, 282.0)
const DETAIL_KICKER: String = "KOLEKSİYON PARÇASI"
const ADD_TEXT: String = "VİTRİNE EKLE"
const REMOVE_TEXT: String = "VİTRİNDEN ÇIKAR"
const AVATAR_TEXT: String = "AVATAR YAP"
const SHOP_TEXT: String = "MAĞAZAYA GİT"
const CANCEL_TEXT: String = "VAZGEÇ"
const OWNED_TEXT: String = "SAHİPSİN"
const SHOWCASED_TEXT: String = "VİTRİNDE"
const LOCKED_TEXT: String = "KİLİTLİ"
const NOTE_OWNED: String = "Profil vitrinine ekle — en fazla %d Squishy sergileyebilirsin. Oyundaki parçaların görünümü değişmez."
const NOTE_OWNED_FULL: String = "Vitrinin dolu (%d/%d). Eklemek için vitrindeki bir Squishy'nin yerine koyabilirsin."
const NOTE_AVATAR: String = "Profil avatarın ve vitrininin ilk Squishy'si."
const NOTE_SLOT: String = "Profil vitrininde · %d. yuva."
const NOTE_LOCKED: String = "Henüz keşfedilmedi. Sandıklardan çıkabilir ya da Mağaza'da %d Hamur."
const REPLACE_KICKER: String = "VİTRİN DOLU · %d/%d"
const REPLACE_NOTE: String = "Hangisinin yerine koyalım? Seçtiğin yuvaya girer, diğerleri yerinde kalır."
const SLOT_AVATAR_TEXT: String = "AVATAR"
const SLOT_TEXT: String = "%d. YUVA"
const REPLACE_TILE: Vector2 = Vector2(164.0, 200.0)
const BURST_COUNT: int = 8
const BURST_TIME: float = 0.55
## Detay eylemlerinden sonra kısa kilit: birincil buton her yazmadan sonra anlam
## değiştirir (VİTRİNE EKLE → AVATAR YAP / VİTRİNDEN ÇIKAR) ve pencere yeniden
## ortalanır — hızlı çift dokunuşun ikinci yarısı istenmeyen bir eyleme düşmesin.
const ACTION_LOCK_MSEC: int = 350

var _bar: ScreenTopBar
var _cards: Array[CollectionSkinCard] = []
## id (String) -> kart.
var _card_by_id: Dictionary = {}
var _headers: Array[Control] = []
var _pending_focus: StringName = &""
var _has_pending_focus: bool = false
# Başlık
var _header: Control
var _header_count: Label
var _header_star: TextureRect
var _header_bar: ProgressBar
var _showcase_chip: PanelContainer
var _showcase_chip_label: Label
var _rarity_chips: Dictionary = {}
# Detay
var _detail: Control
var _detail_dim: ColorRect
var _detail_frame: Control
var _detail_stage: CollectibleStage
var _detail_kicker: Label
var _detail_name: Label
var _detail_tag_slot: Control
var _detail_tag: PanelContainer
var _detail_chip: PanelContainer
var _detail_chip_icon: TextureRect
var _detail_chip_label: Label
var _detail_note: Label
var _detail_primary: Button
var _detail_secondary: Button
var _replace_box: VBoxContainer
var _replace_row: HBoxContainer
var _replace_tiles: Array[Button] = []
var _detail_id: StringName = &""
var _replacing: bool = false
var _action_lock_until: int = 0
var _burst: Array[TextureRect] = []
var _burst_tween: Tween
var _entry_tween: Tween
var _time: float = 0.0
## Test kancası: cihaz üst güvenli payı (A36 punch-hole) masaüstünde
## okunamaz; negatif = gerçek değeri kullan.
var _safe_top_override: float = -1.0

@onready var _root: Control = $Root
@onready var _backdrop: Control = $Root/Backdrop
@onready var _vignette: TextureRect = $Root/Vignette
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
	_build_header()
	_build_gallery()
	_build_detail()
	_build_burst()
	_root.resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		set_process(visible)
		if visible:
			_layout()
			_play_entry.call_deferred()
		else:
			# Sekmeden çıkınca açık detay kapanır; aynı sekmede tazeleme
			# (günlük pencere kapanışı, Hamur yenilemesi) detayı KORUR.
			close_detail(false))
	set_process(visible)
	SaveManager.skin_granted.connect(_on_skin_granted)
	SaveManager.showcase_changed.connect(_on_showcase_changed)
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


## Albüm başlığı: Home üst satır pill'i dili (koyu lavanta gövde + açık halka +
## erik gölge + gloss) — içinde KOLEKSİYON N/20 + altın VİTRİN çipi, nane ray,
## rarity sayaç çipleri. Dashboard değil: tek candy plaka.
func _build_header() -> void:
	_header = Control.new()
	_header.name = "AlbumHeader"
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow := UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.26))
	UiKit.inset(shadow, -14.0, -9.0, -14.0, -19.0)
	_header.add_child(shadow)
	var rim := UiKit.flat_plate("frame_round20", UiTokens.LAVENDER_LIGHT)
	UiKit.inset(rim, -3.0, -3.0, -3.0, -3.0)
	_header.add_child(rim)
	var plate := UiKit.panel(&"PanelHomePill")
	plate.name = "Plate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.add_theme_stylebox_override("panel",
		UiKit.style("frame_round20", UiTokens.LAVENDER_DEEP, Vector4(18, 12, 18, 14)))
	_header.add_child(plate)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	# Sabit 128 px plakada içerik dikeyde ortalı (altta boş bant kalmasın).
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.add_child(column)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var caption := UiKit.label(PROGRESS_TEXT, &"LabelBadgeOnDark")
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", UiTokens.TEXT_ON_DARK)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	_header_star = UiKit.art(STAR_ART, 22)
	_header_star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header_star.visible = false
	row.add_child(_header_star)
	_header_count = UiKit.label("0/20", &"LabelStatOnDark")
	_header_count.name = "Count"
	_header_count.add_theme_font_size_override("font_size", 22)
	_header_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_header_count)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	# VİTRİN N/3: altın çip (vitrin = sergi dili; kartlardaki VİTRİNDE ile aynı).
	_showcase_chip = PanelContainer.new()
	_showcase_chip.name = "ShowcaseChip"
	_showcase_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_showcase_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_showcase_chip.add_theme_stylebox_override("panel",
		UiKit.style("frame_round20", UiTokens.GOLD, Vector4(12, 3, 14, 5)))
	var chip_row := HBoxContainer.new()
	chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_row.add_theme_constant_override("separation", 5)
	_showcase_chip.add_child(chip_row)
	var chip_star := UiKit.art(STAR_ART, 18)
	chip_star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip_row.add_child(chip_star)
	_showcase_chip_label = UiKit.label("", &"LabelBadge")
	_showcase_chip_label.add_theme_font_size_override("font_size", 15)
	_showcase_chip_label.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	chip_row.add_child(_showcase_chip_label)
	row.add_child(_showcase_chip)
	_header_bar = UiKit.progress_bar(0.0, &"ProgressBarMint", 12.0)
	_header_bar.name = "ProgressBar"
	column.add_child(_header_bar)
	var chips := HBoxContainer.new()
	chips.name = "RarityChips"
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_theme_constant_override("separation", 8)
	column.add_child(chips)
	for rarity in [SkinData.Rarity.COMMON, SkinData.Rarity.RARE,
			SkinData.Rarity.EPIC, SkinData.Rarity.LEGENDARY]:
		var chip := PanelContainer.new()
		chip.name = "Chip_%s" % SkinData.rarity_name(rarity)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# `badge_round` (dikey 9-dilim payı 33) ≥ 34 px çipte düzgün hap; `label_round`'un
		# 66 px payı 28 px'te sekme gibi çiziliyordu (TASK/044 incelemesi).
		chip.add_theme_stylebox_override("panel",
			UiKit.style("badge_round", (SECTION_TINTS[rarity] as Color).darkened(0.12), Vector4(8, 6, 8, 8)))
		chip.custom_minimum_size = Vector2(0, 34.0)
		var chip_label := UiKit.label("", &"LabelBadgeOnDark", HORIZONTAL_ALIGNMENT_CENTER)
		chip_label.add_theme_font_size_override("font_size", 14)
		chip_label.clip_text = true
		chip_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		chip.add_child(chip_label)
		chip.set_meta(&"title_label", chip_label)
		chips.add_child(chip)
		_rarity_chips[rarity] = chip
	var gloss := UiKit.patch("btn_bevel_light", Color(1, 1, 1, 0.24))
	gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_left = 10.0
	gloss.offset_right = -10.0
	gloss.offset_top = 3.0
	gloss.offset_bottom = 26.0
	_header.add_child(gloss)
	_root.add_child(_header)
	# Başlık haze'lerin ÖNÜNDE, detayın ARKASINDA (detay en son eklenir).
	_root.move_child(_header, _haze.get_index() + 1)


## Albüm: rarity başına bölüm plakası + 3 sütunlu kart sıraları (katalog
## sırası: SkinLibrary rarity + id). Sıralar `HBoxContainer` (ortalı): eksik
## son sıra (YAYGIN 3+3+2, EPİK 3+1, EFSANEVİ 2) ortada durur.
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
		spacer.custom_minimum_size = Vector2(0, HEADER_SECTION_GAP)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(spacer)
		var section := VBoxContainer.new()
		section.name = "Grid_%s" % SkinData.rarity_name(rarity)
		section.mouse_filter = Control.MOUSE_FILTER_IGNORE
		section.add_theme_constant_override("separation", int(ROW_GAP))
		_content.add_child(section)
		sections[rarity] = section
	for entry in SkinEntry.all(false):
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


## Detay penceresi: tam ekran karartma + ortalayıcı + `UiKit.modal_shell`
## (Mağaza onay penceresiyle aynı ekran-içi desen). Sabit üst bölge (hero):
## `CollectibleStage`; kaydırılan gövde: künye / ad / etiketler / açıklama /
## (vitrin doluyken) değiştirme adımı; sabit altlık: eylem butonları.
func _build_detail() -> void:
	_detail = Control.new()
	_detail.name = "Detail"
	_detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.visible = false
	_root.add_child(_detail)
	_detail_dim = ColorRect.new()
	_detail_dim.name = "Dim"
	_detail_dim.color = Color(0.05, 0.0, 0.06, 0.62)
	_detail_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail.add_child(_detail_dim)
	var anchor := CenterContainer.new()
	anchor.name = "Anchor"
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(anchor)
	_detail_frame = UiKit.modal_shell(DETAIL_TITLE, DETAIL_WIDTH, &"ribbon", false, true)
	anchor.add_child(_detail_frame)
	var hero: VBoxContainer = _detail_frame.get_meta(&"hero")
	var stage_host := Control.new()
	stage_host.name = "StageHost"
	stage_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_host.custom_minimum_size = Vector2(0, DETAIL_STAGE.y + 12.0)
	hero.add_child(stage_host)
	_detail_stage = CollectibleStage.new(true, true)
	_detail_stage.name = "Stage"
	_detail_stage.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_detail_stage.offset_left = -DETAIL_STAGE.x * 0.5
	_detail_stage.offset_right = DETAIL_STAGE.x * 0.5
	_detail_stage.offset_top = 14.0
	_detail_stage.offset_bottom = 14.0 + DETAIL_STAGE.y
	stage_host.add_child(_detail_stage)
	var body: VBoxContainer = _detail_frame.get_meta(&"body")
	body.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_detail_kicker = UiKit.label(DETAIL_KICKER, &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
	_detail_kicker.name = "Kicker"
	_detail_kicker.add_theme_font_size_override("font_size", 15)
	_detail_kicker.add_theme_color_override("font_color", UiTokens.TEXT_TERTIARY)
	body.add_child(_detail_kicker)
	_detail_name = UiKit.label("", &"LabelTitle", HORIZONTAL_ALIGNMENT_CENTER)
	_detail_name.name = "Name"
	_detail_name.add_theme_font_size_override("font_size", 34)
	_detail_name.clip_text = true
	_detail_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(_detail_name)
	var tag_row := HBoxContainer.new()
	tag_row.name = "TagRow"
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tag_row.add_theme_constant_override("separation", 10)
	body.add_child(tag_row)
	_detail_tag_slot = Control.new()
	_detail_tag_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_tag_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag_row.add_child(_detail_tag_slot)
	_detail_chip = PanelContainer.new()
	_detail_chip.name = "StateChip"
	_detail_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chip_row := HBoxContainer.new()
	chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chip_row.add_theme_constant_override("separation", 5)
	chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_chip.add_child(chip_row)
	_detail_chip_icon = UiKit.art(STAR_ART, 20)
	_detail_chip_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip_row.add_child(_detail_chip_icon)
	_detail_chip_label = UiKit.label("", &"LabelBadge", HORIZONTAL_ALIGNMENT_CENTER)
	_detail_chip_label.add_theme_font_size_override("font_size", 17)
	chip_row.add_child(_detail_chip_label)
	tag_row.add_child(_detail_chip)
	_detail_note = UiKit.label("", &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	_detail_note.name = "Note"
	_detail_note.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_detail_note.add_theme_font_size_override("font_size", 18)
	_detail_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_detail_note)
	_build_replace(body)
	var footer: VBoxContainer = _detail_frame.get_meta(&"footer")
	footer.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_detail_primary = UiKit.candy_button(ADD_TEXT, &"ButtonPrimary", 64.0)
	_detail_primary.name = "Primary"
	_detail_primary.pressed.connect(_on_detail_primary)
	footer.add_child(_detail_primary)
	_detail_secondary = UiKit.candy_button(REMOVE_TEXT, &"ButtonSecondary", 58.0)
	_detail_secondary.name = "Secondary"
	_detail_secondary.pressed.connect(_on_detail_secondary)
	footer.add_child(_detail_secondary)
	(_detail_frame.get_meta(&"close_button") as Button).pressed.connect(close_detail)
	UiKit.attach_dim_close(_detail_dim, close_detail)


## Vitrin doluyken AÇIK değiştirme adımı: vitrindeki üç parça (yuva sırası;
## ilki AVATAR) seçilebilir kutucuk. Oyuncu seçmeden hiçbir şey değişmez.
func _build_replace(body: VBoxContainer) -> void:
	_replace_box = VBoxContainer.new()
	_replace_box.name = "Replace"
	_replace_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_replace_box.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_replace_box.visible = false
	body.add_child(_replace_box)
	_replace_row = HBoxContainer.new()
	_replace_row.name = "Slots"
	_replace_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_replace_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_replace_row.add_theme_constant_override("separation", 12)
	_replace_box.add_child(_replace_row)
	for i in SaveManager.SHOWCASE_MAX:
		var tile := _make_replace_tile(i)
		_replace_row.add_child(tile)
		_replace_tiles.append(tile)


func _make_replace_tile(slot: int) -> Button:
	var tile := Button.new()
	tile.name = "Slot%d" % (slot + 1)
	tile.focus_mode = Control.FOCUS_NONE
	tile.custom_minimum_size = REPLACE_TILE
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		tile.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	var rim := UiKit.flat_plate("frame_round20", UiTokens.LAVENDER_LIGHT)
	UiKit.inset(rim, -3.0, -3.0, -3.0, -3.0)
	tile.add_child(rim)
	var body := UiKit.panel(&"PanelCollectionCard")
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	tile.add_child(body)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	body.add_child(column)
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", UiKit.style("frame_round20",
		UiTokens.GOLD if slot == 0 else UiTokens.LAVENDER_SURFACE, Vector4(10, 1, 10, 3)))
	var badge_label := UiKit.label(SLOT_AVATAR_TEXT if slot == 0 else SLOT_TEXT % (slot + 1),
		&"LabelBadge", HORIZONTAL_ALIGNMENT_CENTER)
	badge_label.add_theme_font_size_override("font_size", 13)
	badge_label.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	badge.add_child(badge_label)
	column.add_child(badge)
	var swatch := SkinSwatch.new()
	swatch.name = "Preview"
	swatch.custom_minimum_size = Vector2(104, 104)
	swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(swatch)
	var name_label := UiKit.label("", &"LabelSection", HORIZONTAL_ALIGNMENT_CENTER)
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(name_label)
	tile.set_meta(&"swatch", swatch)
	tile.set_meta(&"name_label", name_label)
	tile.set_meta(&"slot", slot)
	tile.pressed.connect(func() -> void: _on_replace_slot(slot))
	UiMotion.attach_press(tile)
	return tile


## Vitrin kutlaması: sahne merkezinden dışarı uçan 8 owner yıldızı (havuz).
func _build_burst() -> void:
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Kutlama detay penceresinin ÖNÜNDE.
	_root.move_child(_fx, _root.get_child_count() - 1)
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
	var header_y: float = _bar.height() + HEADER_GAP
	_header.position = Vector2(SIDE_MARGIN, header_y)
	_header.size = Vector2(view.x - SIDE_MARGIN * 2.0, HEADER_HEIGHT)
	var gallery_y: float = header_y + HEADER_HEIGHT + HEADER_AFTER
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
	if _detail.visible:
		UiKit.modal_relayout(_detail_frame)


# --- Tazeleme -----------------------------------------------------------------

## Sekmeye her girişte (main._show_tab): kartlar, başlık ve bakiye kanonik
## modelden. Kartlar yeniden KURULMAZ. Açık detay yalnız tazelenir (sekmeden
## çıkınca zaten kapanır — `visibility_changed`); böylece Profil'den açılan
## detay, üstünde açılıp kapanan günlük pencere yüzünden kaybolmaz. Görünmezken
## keşfedilen yeni parça varsa albüm ona kaydırır ve kart pop'lar.
func refresh() -> void:
	_refresh_detail()
	for card in _cards:
		card.refresh()
	_refresh_header()
	_bar.set_value(str(SaveManager.dough()), false)
	_scroll.scroll_vertical = 0
	if _has_pending_focus:
		_has_pending_focus = false
		focus_card(_pending_focus)


func _refresh_header() -> void:
	var total: int = SkinLibrary.total_count()
	var owned: int = SkinEntry.owned_count()
	_header_count.text = "%d/%d" % [owned, total]
	_header_bar.value = float(owned) / float(maxi(total, 1))
	var complete: bool = total > 0 and owned >= total
	_header_bar.theme_type_variation = &"ProgressBarGold" if complete else &"ProgressBarMint"
	_header_star.visible = complete
	_header_count.add_theme_color_override("font_color", UiTokens.GOLD_BRIGHT if complete else UiTokens.TEXT_ON_DARK)
	_showcase_chip_label.text = SHOWCASE_CHIP_TEXT % [SaveManager.profile_showcase().size(), SaveManager.SHOWCASE_MAX]
	for rarity in _rarity_chips:
		var chip: PanelContainer = _rarity_chips[rarity]
		var label: Label = chip.get_meta(&"title_label")
		label.text = "%s %d/%d" % [SkinData.rarity_display_upper(rarity),
			SkinEntry.owned_count_by_rarity(rarity), SkinLibrary.by_rarity(rarity).size()]


## Albümü bir kartın üstüne kaydırır ve kartı pop'lar (yeni keşif / Profil'den
## gelen istek). Yerleşim oturduktan SONRA (bir kare).
func focus_card(skin_id: StringName) -> void:
	var card: CollectionSkinCard = _card_by_id.get(String(skin_id))
	if card == null:
		return
	await get_tree().process_frame
	if not is_inside_tree() or not visible or not is_instance_valid(card):
		return
	var target: float = card.global_position.y + float(_scroll.scroll_vertical) \
		- _scroll.global_position.y - GALLERY_TOP_PAD
	_scroll.scroll_vertical = int(maxf(target, 0.0))
	UiMotion.pop(card, 1.05)


func _on_card_selected(skin_id: StringName) -> void:
	AudioManager.play(&"ui_select")
	open_detail(skin_id)


func _play_entry() -> void:
	if not is_inside_tree() or not visible:
		return
	if _entry_tween != null and _entry_tween.is_valid():
		_entry_tween.kill()
	# Ekran girişi (0.18 s): başlık + albüm solarak gelir (main'in
	# `UiMotion.screen_in`'i yalnız Container çocuklarını kaydırır).
	_scroll.modulate.a = 0.0
	_header.modulate.a = 0.0
	_entry_tween = create_tween()
	_entry_tween.set_parallel(true)
	_entry_tween.tween_property(_scroll, "modulate:a", 1.0, ENTRY_TIME)
	_entry_tween.tween_property(_header, "modulate:a", 1.0, ENTRY_TIME)


## Boşta: Legendary kartların pırıltıları (kartlar kendi _process'ini
## çalıştırmaz; gizliyken işlem yok).
func _process(delta: float) -> void:
	_time += delta
	for card in _cards:
		card.tick_sparkles(_time)


# --- Detay --------------------------------------------------------------------

## Parçanın detay penceresi (albüm kartı, Profil vitrini). Bilinmeyen id →
## hiçbir şey olmaz.
func open_detail(skin_id: StringName) -> void:
	var entry: SkinEntry = SkinEntry.find(skin_id)
	if entry == null or entry.is_default():
		return
	var was_open: bool = _detail.visible
	_detail_id = skin_id
	_replacing = false
	_action_lock_until = 0
	_detail.visible = true
	_apply_detail(entry)
	(_detail_frame.get_meta(&"scroll") as ScrollContainer).scroll_vertical = 0
	if not was_open:
		UiMotion.modal_open(_detail_frame, _detail_dim)
		AudioManager.play(&"ui_modal_open")


func close_detail(with_sound: bool = true) -> void:
	if not _detail.visible:
		return
	_detail.visible = false
	_replacing = false
	_detail_id = &""
	if with_sound:
		AudioManager.play(&"ui_modal_close")


func _refresh_detail() -> void:
	if not _detail.visible:
		return
	var entry: SkinEntry = SkinEntry.find(_detail_id)
	if entry == null:
		close_detail(false)
		return
	_apply_detail(entry)


## Detay içeriği tek kaynaktan (SkinEntry): sahne, künye, ad, rarity etiketi,
## durum çipi, açıklama ve TEK hâkim eylem (+ gerekirse ikincil).
func _apply_detail(entry: SkinEntry) -> void:
	_detail_stage.setup(entry, true)
	_detail_name.text = entry.display_name
	if _detail_tag != null:
		_detail_tag_slot.remove_child(_detail_tag)
		_detail_tag.queue_free()
		_detail_tag = null
	_detail_tag = UiKit.rarity_tag(int(entry.rarity))
	(_detail_tag.get_meta(&"title_label") as Label).add_theme_font_size_override("font_size", 18)
	_detail_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_tag_slot.add_child(_detail_tag)
	_detail_tag_slot.custom_minimum_size = _detail_tag.get_combined_minimum_size()
	_detail_tag.size = _detail_tag_slot.custom_minimum_size
	var showcase_size: int = SaveManager.profile_showcase().size()
	var full: bool = showcase_size >= SaveManager.SHOWCASE_MAX
	_detail_kicker.text = DETAIL_KICKER
	_replace_box.visible = false
	if entry.is_locked():
		_set_chip(LOCKED_TEXT, UiKit.icon_texture("lock"), UiTokens.NAVY_PURPLE, UiTokens.GOLD)
		_detail_note.text = NOTE_LOCKED % entry.price
		_set_button(_detail_primary, SHOP_TEXT, &"ButtonPrimary", true)
		_detail_secondary.visible = false
	elif entry.showcased:
		_set_chip(SHOWCASED_TEXT, STAR_ART, UiTokens.GOLD, UiTokens.TEXT_PRIMARY)
		_detail_note.text = NOTE_AVATAR if entry.showcase_slot == 0 else NOTE_SLOT % (entry.showcase_slot + 1)
		if entry.showcase_slot > 0:
			_set_button(_detail_primary, AVATAR_TEXT, &"ButtonPrimary", true)
			_set_button(_detail_secondary, REMOVE_TEXT, &"ButtonSecondary", true)
		else:
			_set_button(_detail_primary, REMOVE_TEXT, &"ButtonSecondary", true)
			_detail_secondary.visible = false
	else:
		_set_chip(OWNED_TEXT, UiKit.icon_texture("check"), UiTokens.MINT, UiTokens.TEXT_ON_ACCENT)
		_detail_note.text = NOTE_OWNED_FULL % [showcase_size, SaveManager.SHOWCASE_MAX] if full \
			else NOTE_OWNED % SaveManager.SHOWCASE_MAX
		_set_button(_detail_primary, ADD_TEXT, &"ButtonPrimary", true)
		_detail_secondary.visible = false
	if _replacing and not entry.is_locked() and not entry.showcased and full:
		_show_replace_step()
	else:
		# Değiştirme artık geçerli değil (vitrin boşaldı / parça vitrine girdi).
		_replacing = false
	UiKit.modal_relayout(_detail_frame)


## Değiştirme adımı: vitrindeki parçalar yuva sırasıyla; altlıkta yalnız VAZGEÇ.
func _show_replace_step() -> void:
	var showcase: Array[SkinEntry] = SkinEntry.showcase_entries()
	_detail_kicker.text = REPLACE_KICKER % [showcase.size(), SaveManager.SHOWCASE_MAX]
	_detail_note.text = REPLACE_NOTE
	for i in _replace_tiles.size():
		var tile: Button = _replace_tiles[i]
		if i < showcase.size():
			tile.visible = true
			(tile.get_meta(&"swatch") as SkinSwatch).setup(showcase[i])
			(tile.get_meta(&"name_label") as Label).text = showcase[i].display_name
			tile.set_meta(&"skin_id", showcase[i].id)
		else:
			tile.visible = false
	_replace_box.visible = true
	_detail_primary.visible = false
	_set_button(_detail_secondary, CANCEL_TEXT, &"ButtonSecondary", true)


func _set_chip(text: String, icon: Texture2D, fill: Color, text_color: Color) -> void:
	_detail_chip.add_theme_stylebox_override("panel",
		UiKit.style("frame_round20", fill, Vector4(12, 3, 14, 5)))
	_detail_chip_icon.texture = icon
	_detail_chip_icon.self_modulate = text_color if icon != STAR_ART else Color.WHITE
	_detail_chip_label.text = text
	_detail_chip_label.add_theme_color_override("font_color", text_color)


func _set_button(button: Button, text: String, variation: StringName, shown: bool) -> void:
	button.visible = shown
	(button.get_meta(&"title_label") as Label).text = text
	UiKit.set_candy_button_variation(button, variation)


func _actions_locked() -> bool:
	return Time.get_ticks_msec() < _action_lock_until


func _lock_actions() -> void:
	_action_lock_until = Time.get_ticks_msec() + ACTION_LOCK_MSEC


func _on_detail_primary() -> void:
	if _actions_locked():
		return
	var entry: SkinEntry = SkinEntry.find(_detail_id)
	if entry == null:
		return
	_lock_actions()
	if entry.is_locked():
		var target: StringName = entry.id
		close_detail(false)
		shop_skin_requested.emit(target)
		return
	if entry.showcased:
		if entry.showcase_slot > 0:
			if SaveManager.showcase_make_first(entry.id):
				_celebrate()
		else:
			_remove_from_showcase(entry.id)
		return
	match SaveManager.showcase_add(entry.id):
		SaveManager.ShowcaseResult.ADDED:
			_celebrate()
		SaveManager.ShowcaseResult.FULL:
			# Sessiz değiştirme YOK: oyuncu hangi yuvanın değişeceğini seçer.
			_replacing = true
			AudioManager.play(&"ui_select")
			_apply_detail(entry)


func _on_detail_secondary() -> void:
	if _actions_locked():
		return
	_lock_actions()
	if _replacing:
		_replacing = false
		_refresh_detail()
		return
	var entry: SkinEntry = SkinEntry.find(_detail_id)
	if entry != null and entry.showcased:
		_remove_from_showcase(entry.id)


## Dokunuş sesi basışta (candy buton `UiMotion.attach_press`) — ikinci kez çalınmaz.
func _remove_from_showcase(skin_id: StringName) -> void:
	SaveManager.showcase_remove(skin_id)


func _on_replace_slot(slot: int) -> void:
	if _actions_locked() or not _replacing or slot >= _replace_tiles.size():
		return
	var tile: Button = _replace_tiles[slot]
	if not tile.has_meta(&"skin_id"):
		return
	var old_id: StringName = tile.get_meta(&"skin_id")
	_replacing = false
	_lock_actions()
	if SaveManager.showcase_replace(old_id, _detail_id):
		_celebrate()
	else:
		_refresh_detail()


## Vitrin değişti (bu ekran ya da başka bir yer): kartlar, başlık, açık detay.
func _on_showcase_changed(_ids: Array) -> void:
	for card in _cards:
		card.refresh()
	_refresh_header()
	_refresh_detail()


## Vitrine eklendi / avatar oldu: sanat pop + yıldız patlaması + onay sesi.
func _celebrate() -> void:
	if not visible or not _detail.visible:
		return
	AudioManager.play(&"ui_equip")
	Haptics.light()
	_detail_stage.celebrate()
	var card: CollectionSkinCard = _card_by_id.get(String(_detail_id))
	if card != null:
		UiMotion.pop(card.showcase_plate(), 1.2)
	if _burst_tween != null and _burst_tween.is_valid():
		_burst_tween.kill()
	var art: Control = _detail_stage.art_box()
	var center: Vector2 = art.global_position + art.size * 0.5 - _fx.global_position
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
		# Sekme açılınca refresh() geliyor (main.gd); o anda albümde öne alınır.
		_pending_focus = skin_id
		_has_pending_focus = true
		return
	for card in _cards:
		card.refresh()
	_refresh_header()
	_refresh_detail()
	focus_card(skin_id)


## Android geri: açık değiştirme adımı → detaya; açık detay → kapat (true);
## değilse main.gd Ana Sayfa'ya döner (false). Geri tuşu eylem kilidine
## takılmaz (yazma yapmaz).
func handle_back() -> bool:
	if _detail.visible:
		if _replacing:
			_replacing = false
			AudioManager.play(&"ui_tap")
			_refresh_detail()
		else:
			close_detail()
		return true
	return false


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


## Albüm dikişi: başlığın altında kartların kırpıldığı çizgi — ortası koyu,
## iki yana sıfıra solan yumuşak bant.
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


func header() -> Control:
	return _header


func header_count_text() -> String:
	return _header_count.text


func header_bar() -> ProgressBar:
	return _header_bar


func showcase_chip_text() -> String:
	return _showcase_chip_label.text


func rarity_chip_text(rarity: SkinData.Rarity) -> String:
	return ((_rarity_chips[rarity] as PanelContainer).get_meta(&"title_label") as Label).text


func cards() -> Array[CollectionSkinCard]:
	return _cards


func card(skin_id: StringName) -> CollectionSkinCard:
	return _card_by_id.get(String(skin_id))


func section_headers() -> Array[Control]:
	return _headers


func is_detail_open() -> bool:
	return _detail.visible


func is_replacing() -> bool:
	return _detail.visible and _replacing


func detail_id() -> StringName:
	return _detail_id


func detail_frame() -> Control:
	return _detail_frame


func detail_stage() -> CollectibleStage:
	return _detail_stage


func detail_name_text() -> String:
	return _detail_name.text


func detail_rarity_text() -> String:
	return (_detail_tag.get_meta(&"title_label") as Label).text if _detail_tag != null else ""


func detail_state_text() -> String:
	return _detail_chip_label.text


func detail_note_text() -> String:
	return _detail_note.text


func detail_primary() -> Button:
	return _detail_primary


func detail_secondary() -> Button:
	return _detail_secondary


func detail_primary_text() -> String:
	return (_detail_primary.get_meta(&"title_label") as Label).text if _detail_primary.visible else ""


func detail_secondary_text() -> String:
	return (_detail_secondary.get_meta(&"title_label") as Label).text if _detail_secondary.visible else ""


func replace_tiles() -> Array[Button]:
	return _replace_tiles


func haze() -> TextureRect:
	return _haze
