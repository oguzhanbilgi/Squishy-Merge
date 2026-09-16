extends CanvasLayer
## Ana Sayfa — oyun hub'ı (M8.6-03B). Casual mobil oyun lobisi: kart/sekme
## yığını DEĞİL, bölgeler (zone) ve yüzen özellik madalyonları.
##
##   ÜST      "oturmuş" ayarlar (UiKit.home_icon_button) + seri pill'i (sol) ·
##            Hamur pill'i + nane "+" → Mağaza (sağ) — HUD v5 dili lavanta
##            glossy pill'ler (UiKit.home_pill), 56 px tek satır; cihaz üst
##            güvenli payı satırı aşağı iter
##   LOGO     SQUISHY MERGE lockup, üst satırın altında ortada
##   YAN      sol sütun: Günlük (bildirim noktası) · Koleksiyon (takılı skin,
##            N/20 rozeti + nane halka); sağ sütun: Mağaza · Bonus sandık
##            (owner sandığı, N/75 rozeti + altın halka) — HomeFeatureButton
##   HERO     owner maskotu (yeni yüksek çözünürlüklü türev) + lavanta hale +
##            yer gölgesi + tier 3 / tier 6 dumpling + pırıltılar; nefes
##   OYNA     tek kahraman CTA ALTTA ORTADA, büyük (480×96, cyan candy);
##            hemen üstünde ortalanmış kompakt level pill'i (altın taç
##            madalyonu + "SIRADAKİ / Level 4 ★ 8/30"; sonsuzda "SONSUZ MOD /
##            Rekor 12 480 ★ 30/30") → ikisi de Harita (03B.2)
##
## Harita/harita düğümü Ana Sayfa'da YOK. Alt sekme çubuğu Ana Sayfa'da
## gizli (main.gd). Kayıt YALNIZCA okunur. Zemin candy-night (ShellBackdrop).
##
## Yerleşim `_layout()` ile elle: tuval 720 px genişlik, yükseklik serbest;
## fazla yükseklik hero'ya (maskot büyür, üst/alt nefes payı artar), yan
## madalyonlar ve OYNA ölçeklenmez. Madalyonlar ile maskot/OYNA çakışmaz
## (testle kilitli).

signal play_pressed
signal settings_pressed
signal shop_requested
signal collection_requested
signal map_requested
signal daily_requested
signal chest_requested

const LOGO_ART: Texture2D = preload("res://assets/visual/ui/logo_lockup.png")
const HERO_ART: Texture2D = preload("res://assets/visual/ui/hero_mascot.png")
const CHEST_ART: Texture2D = preload("res://assets/visual/ui/chest_closed.png")
const CROWN_ART: Texture2D = preload("res://assets/visual/ui/icon_crown.png")
const STAR_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
const DUMPLING_VISUAL: GDScript = preload("res://scripts/game/dumpling_visual.gd")

## Yan dumpling'ler: (tier, maskot merkezine göre oran (x: maskot genişliği,
## y: maskot yüksekliği), kutu (maskot 540 iken), açı).
const SIDE_DUMPLINGS: Array = [
	[3, Vector2(-0.42, 0.40), 112.0, -8.0],
	[6, Vector2(0.42, 0.30), 140.0, 7.0],
]
## Pırıltılar: maskot merkezine göre oran, kutu, faz.
const SPARKLES: Array = [
	[Vector2(-0.34, -0.44), 22.0, 0.0],
	[Vector2(0.38, -0.34), 18.0, 1.9],
	[Vector2(0.12, 0.56), 14.0, 3.7],
	[Vector2(-0.46, 0.06), 12.0, 5.1],
	[Vector2(0.50, 0.58), 16.0, 2.6],
	[Vector2(-0.20, 0.66), 12.0, 4.4],
]
## Alt bant pırıltıları (uzun ekranda maskot ile OYNA arasındaki dünya
## bandı): x tuval oranı, y = maskot altı ile OYNA üstü arasındaki oran, kutu, faz.
const BAND_SPARKLES: Array = [
	[0.22, 0.30, 16.0, 0.8],
	[0.66, 0.42, 12.0, 2.9],
	[0.82, 0.18, 18.0, 4.6],
	[0.40, 0.72, 10.0, 1.4],
]

## Ölçüler (tuval px).
const TOP_MARGIN: float = 14.0
const SIDE_MARGIN: float = 24.0
const BAR_HEIGHT: float = 56.0
const LOGO_WIDTH: float = 560.0
const LOGO_GAP: float = 12.0
const FEATURE_MARGIN: float = 28.0
const FEATURE_GAP: float = 14.0
const FEATURE_STEP: float = HomeFeatureButton.SIZE.y + HomeFeatureButton.PLAQUE_HEIGHT \
	- HomeFeatureButton.PLAQUE_OVERLAP + 26.0
## OYNA (03B.2): altta ortada, ekranın en büyük kontrolü — btn_cta 88 px
## gövdesi 96'ya gerilir (orta bant düz), 480 geniş (tuvalin 2/3'ü).
const PLAY_WIDTH: float = 480.0
const PLAY_HEIGHT: float = 96.0
const PLAY_GAP: float = 14.0
## Level pill'i: OYNA'nın ÜSTÜNDE ortalanmış, ikincil (236×60 + sola taşan
## 56 px altın rozet); OYNA ile arası LEVEL_PLAY_GAP.
const LEVEL_WIDTH: float = 236.0
const LEVEL_WIDTH_MAX: float = 284.0
const LEVEL_HEIGHT: float = 60.0
const LEVEL_BADGE: float = 56.0
const LEVEL_BADGE_OVERHANG: float = 10.0
const LEVEL_PLAY_GAP: float = 12.0
const BOTTOM_MARGIN: float = 28.0
const MASCOT_MIN: float = 320.0
const MASCOT_MAX: float = 600.0
const MASCOT_REF: float = 600.0
const MASCOT_SIDE_MARGIN: float = 44.0
## Maskotun üst %22'si dar (tepe): yan sütunların altına bu kadar sokulabilir.
const MASCOT_NARROW_TOP: float = 0.22
## Maskotun altında yer gölgesi + yan dumpling payı.
const GROUND_ROOM: float = 64.0
## Uzun ekranda (tuval > 1280) fazla yükseklik: gök payı (logo ile sütunlar
## arası), sütun aralığı, alt nefes payı (OYNA altı) ve yan dumpling'lerin
## aşağı inişi paylaşır; kalan alt "sahne" bandında dünya görünür.
## 03B.1: sütunlar hero'nun yanında daha aşağı yayılır (maskot onlarla
## birlikte iner), OYNA satırı ölçülü yukarı çıkar, alt bantta pırıltılar.
const EXTRA_SKY_SHARE: float = 0.22
const EXTRA_STEP_SHARE: float = 0.36
const EXTRA_BOTTOM_SHARE: float = 0.14
const EXTRA_SIDE_DROP: float = 0.26
const EXTRA_MASCOT_GROWTH: float = 0.12
## Hareket.
const BOB_PERIOD: float = 2.6
const BOB_AMPLITUDE: float = 5.0
const BREATH_SCALE: float = 0.015
const CTA_PULSE: float = 0.015
const CTA_PERIOD: float = 1.9
const CHEST_FLOAT: float = 3.0

var _settings_button: Button
var _streak_pill: Control
var _dough_pill: Control
var _logo: TextureRect
var _hero: Control
var _glow: NinePatchRect
var _stage: NinePatchRect
var _ground: NinePatchRect
var _mascot: TextureRect
var _sides: Array[TextureRect] = []
var _sparkles: Array[TextureRect] = []
var _band_sparkles: Array[TextureRect] = []
var _features: Dictionary = {}
var _feature_homes: Dictionary = {}
var _play_pulse: Control
var _play: Button
var _level: Button
var _level_column: VBoxContainer
var _level_badge: Control
var _level_crown: TextureRect
var _level_badge_label: Label
var _level_caption: Label
var _level_title: Label
var _level_stars: Label
## ui_smoke_test uyumluluğu: "nereye gidiyorum" ipucu = level plakası başlığı.
var _play_hint: Label
var _mascot_home: Rect2 = Rect2()
var _ground_home: Rect2 = Rect2()
var _side_homes: Array[Vector2] = []
var _time: float = 0.0
var _daily_claimable: bool = false
## Test kancası: cihaz üst güvenli payı (A36 punch-hole) masaüstünde
## okunamaz; negatif = gerçek değeri kullan.
var _safe_top_override: float = -1.0

@onready var _root: Control = $Root
@onready var _backdrop: Control = $Backdrop


func _ready() -> void:
	_tune_backdrop()
	_build_top()
	_build_hero()
	_build_features()
	_build_play_row()
	_root.resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		set_process(visible)
		if visible:
			_layout())
	set_process(visible)
	refresh()
	_layout()


# --- Kurulum ------------------------------------------------------------------

## Hub'da dünya nefes alsın: kabuk zemini (ShellBackdrop) sekmelerde koyu
## karartılıyor (liste/kart okunurluğu); Ana Sayfa'da gece kasabası daha
## görünür — karartma azalır, alt solma OYNA satırı için kalır. Yalnız bu
## sahnenin örneği değişir, diğer ekranlar aynı kalır.
func _tune_backdrop() -> void:
	var night: CanvasItem = _backdrop.get_node_or_null("Night")
	if night != null:
		night.modulate = Color(0.82, 0.80, 0.94, 1.0)
	var scrim: ColorRect = _backdrop.get_node_or_null("Scrim")
	if scrim != null:
		scrim.color = Color(0.07, 0.05, 0.18, 0.22)
	var fade: CanvasItem = _backdrop.get_node_or_null("BottomFade")
	if fade != null:
		fade.modulate = Color(1, 1, 1, 0.75)


func _build_top() -> void:
	# Ayarlar: boyalı sınırı dikdörtgene oturan Home varyantı (HUD v5 köşe
	# butonu btn_bevel_soft'un pişmiş gölgesi yüzünden halkanın içinde
	# "yüzüyordu" — bkz. UiKit.home_icon_button).
	_settings_button = UiKit.home_icon_button("settings", BAR_HEIGHT)
	_settings_button.name = "Settings"
	_settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	_root.add_child(_settings_button)
	_streak_pill = UiKit.home_pill(UiIcons.FLAME, "", false, BAR_HEIGHT)
	_streak_pill.name = "StreakPill"
	_streak_pill.minimum_size_changed.connect(_layout)
	_root.add_child(_streak_pill)
	_dough_pill = UiKit.home_pill(UiIcons.DOUGH, "", true, BAR_HEIGHT)
	_dough_pill.name = "DoughPill"
	_dough_pill.minimum_size_changed.connect(_layout)
	(_dough_pill.get_meta(&"add_button") as Button).pressed.connect(
		func() -> void: shop_requested.emit())
	_root.add_child(_dough_pill)


func _build_hero() -> void:
	_hero = Control.new()
	_hero.name = "Hero"
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hero)
	# Yumuşak lavanta hale: maskot gece dünyasında "yüzmesin".
	_glow = UiKit.patch("popup_glow", Color(UiTokens.LAVENDER_DEEP, 0.70))
	_glow.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hero.add_child(_glow)
	# Sıcak sahne ışığı: maskotun ayaklarının altında geniş, çok düşük alfa
	# krem havuz — karakter dünyanın "sahnesinde" durur, alt bant boş okunmaz.
	_stage = UiKit.patch("popup_glow", Color(1.0, 0.92, 0.72, 0.16))
	_stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hero.add_child(_stage)
	# Erik yer gölgesi: karakter havada asılı durmasın; nefesle daralır.
	_ground = UiKit.patch("popup_glow", Color(0.16, 0.07, 0.30, 0.78))
	_ground.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hero.add_child(_ground)
	for spec in SIDE_DUMPLINGS:
		var side := UiKit.art(DUMPLING_VISUAL.TEXTURES[int(spec[0]) - 1], float(spec[2]))
		side.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		side.set_anchors_preset(Control.PRESET_TOP_LEFT)
		side.rotation_degrees = float(spec[3])
		_hero.add_child(side)
		_sides.append(side)
		_side_homes.append(Vector2.ZERO)
	_mascot = UiKit.art(HERO_ART, 0)
	_mascot.name = "Mascot"
	_mascot.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mascot.custom_minimum_size = Vector2.ZERO
	_mascot.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hero.add_child(_mascot)
	for spec in SPARKLES:
		var spark := UiKit.art(STAR_ART, float(spec[1]))
		spark.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_hero.add_child(spark)
		_sparkles.append(spark)
	for spec in BAND_SPARKLES:
		var spark := UiKit.art(STAR_ART, float(spec[2]))
		spark.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_hero.add_child(spark)
		_band_sparkles.append(spark)
	# Logo maskotun üstünde (hero'nun önünde) — üst satırın altında ortada.
	_logo = UiKit.art(LOGO_ART, 0)
	_logo.name = "Logo"
	_logo.custom_minimum_size = Vector2.ZERO
	_logo.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.add_child(_logo)


## Dört madalyon TEK bileşenden. Sol: Günlük, Koleksiyon; sağ: Mağaza, Bonus
## sandık. Her biri gerçek bir rotaya bağlı — sahte buton yok.
func _build_features() -> void:
	var daily := HomeFeatureButton.new()
	daily.name = "Daily"
	daily.set_icon("gift", UiTokens.PINK)
	daily.set_label("GÜNLÜK")
	daily.pressed.connect(func() -> void: daily_requested.emit())
	_add_feature(&"daily", daily)

	var collection := HomeFeatureButton.new()
	collection.name = "Collection"
	collection.set_art(DUMPLING_VISUAL.TEXTURES[0])
	collection.set_label("KOLEKSİYON")
	collection.pressed.connect(func() -> void: collection_requested.emit())
	_add_feature(&"collection", collection)

	var shop := HomeFeatureButton.new()
	shop.name = "Shop"
	shop.set_icon("shop", UiTokens.CYAN)
	shop.set_label("MAĞAZA")
	shop.pressed.connect(func() -> void: shop_requested.emit())
	_add_feature(&"shop", shop)

	var chest := HomeFeatureButton.new()
	chest.name = "Chest"
	chest.set_art(CHEST_ART)
	chest.set_label("SANDIK")
	chest.pressed.connect(func() -> void: chest_requested.emit())
	_add_feature(&"chest", chest)


func _add_feature(key: StringName, button: HomeFeatureButton) -> void:
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.add_child(button)
	_features[key] = button
	_feature_homes[key] = Vector2.ZERO


func _build_play_row() -> void:
	_build_level_pill()
	# OYNA: nefes wrapper'ı (butonun kendi scale'i basışa kalır).
	_play_pulse = Control.new()
	_play_pulse.name = "CtaPulse"
	_play_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_play_pulse)
	_play = UiKit.hero_cta("OYNA")
	_play.name = "Play"
	_play.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play.pressed.connect(func() -> void: play_pressed.emit())
	_play_pulse.add_child(_play)


## Level pill'i (03B.1): OYNA bölgesine bağlı ikincil candy ilerleme nesnesi —
## dashboard kartı değil. Basılabilir koyu lavanta pill (ButtonHomePill) +
## erik gölge + açık halka + gloss; sol ucundan taşan altın taç madalyonu
## (btn_circle altın gövde + krem halka + taç + level numarası); pill içinde
## "SIRADAKİ" (küçük, beyaz %62) / "Level 4" (Baloo 22 beyaz) / "★ 8/30"
## (altın). Sonsuz: rozet "SONSUZ", "SONSUZ MOD" / "Rekor 12 480" / "★ 30/30".
## Rota: Harita (değişmedi).
func _build_level_pill() -> void:
	_level = Button.new()
	_level.name = "Level"
	_level.theme_type_variation = &"ButtonHomePill"
	_level.focus_mode = Control.FOCUS_NONE
	_level.pressed.connect(func() -> void: map_requested.emit())
	UiKit.hud_shadow(_level, 6.0, 0.28, null, 16.0)
	var rim := UiKit.flat_plate("label_round", UiTokens.LAVENDER_LIGHT)
	rim.show_behind_parent = true
	rim.offset_left = -3.0
	rim.offset_top = -3.0
	rim.offset_right = 3.0
	rim.offset_bottom = 3.0
	_level.add_child(rim)
	_root.add_child(_level)
	# İki satır: "SIRADAKİ" başlığı · "Level 4" + sağında altın "★ 8/30".
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", -4)
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = LEVEL_BADGE - LEVEL_BADGE_OVERHANG + 10.0
	column.offset_right = -10.0
	column.offset_top = 1.0
	column.offset_bottom = -6.0
	_level.add_child(column)
	_level_column = column
	column.minimum_size_changed.connect(_layout)
	_level_caption = UiKit.label("SIRADAKİ", &"LabelHudCaption")
	_level_caption.add_theme_font_size_override("font_size", 12)
	column.add_child(_level_caption)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_row)
	_level_title = UiKit.label("Level 1", &"LabelSectionOnDark")
	_level_title.add_theme_font_size_override("font_size", 21)
	title_row.add_child(_level_title)
	_play_hint = _level_title
	var star_row := HBoxContainer.new()
	star_row.add_theme_constant_override("separation", 3)
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	star_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(star_row)
	var star := UiKit.art(STAR_ART, 14)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	star_row.add_child(star)
	_level_stars = UiKit.label("0/30", &"LabelBadgeOnDark")
	_level_stars.add_theme_font_size_override("font_size", 14)
	_level_stars.add_theme_color_override("font_color", UiTokens.GOLD)
	star_row.add_child(_level_stars)
	var gloss := UiKit.patch("btn_bevel_light", Color(1, 1, 1, 0.28))
	gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_left = LEVEL_BADGE - LEVEL_BADGE_OVERHANG + 6.0
	gloss.offset_right = -8.0
	gloss.offset_top = 3.0
	gloss.offset_bottom = LEVEL_HEIGHT * 0.40
	_level.add_child(gloss)
	# Altın taç madalyonu: sol uçtan taşar, pill'in önünde.
	_level_badge = Control.new()
	_level_badge.name = "LevelBadge"
	_level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_badge.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_level_badge.offset_left = -LEVEL_BADGE_OVERHANG
	_level_badge.offset_right = -LEVEL_BADGE_OVERHANG + LEVEL_BADGE
	_level_badge.offset_top = -LEVEL_BADGE * 0.5 - 2.0
	_level_badge.offset_bottom = LEVEL_BADGE * 0.5 - 2.0
	_level.add_child(_level_badge)
	var badge_shadow := UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.30))
	badge_shadow.offset_left = -12.0
	badge_shadow.offset_top = -8.0
	badge_shadow.offset_right = 12.0
	badge_shadow.offset_bottom = 16.0
	_level_badge.add_child(badge_shadow)
	# btn_circle'in boyali govdesi 70/74 (alt 4 satir golge): halkalar govdeye
	# oturur, altta tasmaz.
	var badge_rim := UiKit.patch("btn_circle_flat", UiTokens.CREAM)
	badge_rim.offset_left = -4.0
	badge_rim.offset_top = -4.0
	badge_rim.offset_right = 4.0
	badge_rim.offset_bottom = 0.0
	_level_badge.add_child(badge_rim)
	var badge_ring := UiKit.patch("btn_circle_flat", UiTokens.GOLD_DEEP)
	badge_ring.offset_left = -1.0
	badge_ring.offset_top = -1.0
	badge_ring.offset_right = 1.0
	badge_ring.offset_bottom = -3.0
	_level_badge.add_child(badge_ring)
	var badge_body := UiKit.patch("btn_circle", UiTokens.GOLD)
	badge_body.offset_bottom = 4.0
	_level_badge.add_child(badge_body)
	var badge_gloss := UiKit.patch("item_circle_inner", Color(1, 1, 1, 0.34))
	badge_gloss.offset_left = 8.0
	badge_gloss.offset_top = 3.0
	badge_gloss.offset_right = -8.0
	badge_gloss.offset_bottom = -29.0
	_level_badge.add_child(badge_gloss)
	var badge_col := VBoxContainer.new()
	badge_col.add_theme_constant_override("separation", -8)
	badge_col.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_col.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_col.offset_top = -2.0
	badge_col.offset_bottom = -6.0
	_level_badge.add_child(badge_col)
	_level_crown = UiKit.art(CROWN_ART, 20)
	_level_crown.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge_col.add_child(_level_crown)
	_level_badge_label = UiKit.label("1", &"LabelSectionOnAccent", HORIZONTAL_ALIGNMENT_CENTER)
	_level_badge_label.add_theme_font_size_override("font_size", 20)
	badge_col.add_child(_level_badge_label)
	UiMotion.attach_press(_level)


# --- Yerleşim -----------------------------------------------------------------

func _layout() -> void:
	if _root == null or _play == null:
		return
	var view: Vector2 = _root.size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var safe_top: float = _safe_top_override if _safe_top_override >= 0.0 else UiKit.safe_top(view)
	var safe_bottom: float = UiKit.safe_bottom(view)
	var extra: float = maxf(view.y - 1280.0, 0.0)

	# ÜST satır.
	var top_y: float = safe_top + TOP_MARGIN
	_settings_button.position = Vector2(SIDE_MARGIN, top_y)
	_settings_button.size = Vector2(BAR_HEIGHT, BAR_HEIGHT)
	# Pill'ler ayarlarla aynı yükseklikte (56) tek satır: optik merkezler aynı.
	var streak_size: Vector2 = _streak_pill.custom_minimum_size
	_streak_pill.size = streak_size
	_streak_pill.position = Vector2(SIDE_MARGIN + BAR_HEIGHT + 12.0, top_y + (BAR_HEIGHT - streak_size.y) * 0.5)
	var dough_size: Vector2 = _dough_pill.custom_minimum_size
	_dough_pill.size = dough_size
	_dough_pill.position = Vector2(view.x - SIDE_MARGIN - dough_size.x, top_y + (BAR_HEIGHT - dough_size.y) * 0.5)

	# LOGO.
	var logo_h: float = LOGO_WIDTH * float(LOGO_ART.get_height()) / float(LOGO_ART.get_width())
	var logo_top: float = top_y + BAR_HEIGHT + LOGO_GAP
	_logo.position = Vector2((view.x - LOGO_WIDTH) * 0.5, logo_top)
	_logo.size = Vector2(LOGO_WIDTH, logo_h)
	var logo_bottom: float = logo_top + logo_h

	# OYNA grubu (alt, 03B.2): büyük OYNA ortada, hemen üstünde ortalanmış
	# kompakt level pill'i (rozet dahil optik merkez tuval ortasında).
	var play_top: float = view.y - safe_bottom - BOTTOM_MARGIN - extra * EXTRA_BOTTOM_SHARE - PLAY_HEIGHT
	_play_pulse.position = Vector2((view.x - PLAY_WIDTH) * 0.5, play_top)
	_play_pulse.size = Vector2(PLAY_WIDTH, PLAY_HEIGHT)
	_play_pulse.pivot_offset = _play_pulse.size * 0.5
	var level_top: float = play_top - LEVEL_PLAY_GAP - LEVEL_HEIGHT
	# Pill genişliği içeriğe göre (sonsuzda "Rekor 12 480 ★ 30/30" daha
	# uzun), 236..284 arasında; görsel genişlik = pill + sola taşan rozet,
	# bu bütün ortalanır.
	var text_w: float = _level_column.get_combined_minimum_size().x + _level_column.offset_left - _level_column.offset_right + 4.0
	var level_w: float = clampf(text_w, LEVEL_WIDTH, LEVEL_WIDTH_MAX)
	var level_visual_w: float = level_w + LEVEL_BADGE_OVERHANG
	_level.position = Vector2((view.x - level_visual_w) * 0.5 + LEVEL_BADGE_OVERHANG, level_top)
	_level.size = Vector2(level_w, LEVEL_HEIGHT)

	# YAN sütunlar: logonun altından başlar; uzun ekranda gök payı ve sütun
	# aralığı büyür.
	var col_top: float = logo_bottom + FEATURE_GAP + extra * EXTRA_SKY_SHARE
	var step: float = FEATURE_STEP + extra * EXTRA_STEP_SHARE
	var col_x_left: float = FEATURE_MARGIN
	var col_x_right: float = view.x - FEATURE_MARGIN - HomeFeatureButton.SIZE.x
	var order: Array = [[&"daily", col_x_left, 0], [&"collection", col_x_left, 1],
		[&"shop", col_x_right, 0], [&"chest", col_x_right, 1]]
	for entry in order:
		var at := Vector2(float(entry[1]), col_top + float(entry[2]) * step)
		_feature_homes[entry[0]] = at
		var button: HomeFeatureButton = _features[entry[0]]
		button.position = at
		button.size = HomeFeatureButton.SIZE
	var col_bottom: float = col_top + step + HomeFeatureButton.SIZE.y \
		+ HomeFeatureButton.PLAQUE_HEIGHT - HomeFeatureButton.PLAQUE_OVERLAP

	# HERO: hero bölgesi logo altı → OYNA üstü; maskot sütunların arasına
	# yalnız dar tepesiyle sokulur, genişliği tuvale sığar.
	var hero_top: float = logo_bottom + 4.0
	var hero_bottom: float = play_top - LEVEL_PLAY_GAP - LEVEL_HEIGHT - PLAY_GAP
	_hero.position = Vector2(0.0, hero_top)
	_hero.size = Vector2(view.x, maxf(hero_bottom - hero_top, 1.0))
	var art_aspect: float = float(HERO_ART.get_width()) / float(HERO_ART.get_height())
	var h_by_width: float = (view.x - 2.0 * MASCOT_SIDE_MARGIN) / art_aspect
	var h_by_height: float = (hero_bottom - GROUND_ROOM - col_bottom) / (1.0 - MASCOT_NARROW_TOP)
	# Uzun ekranda maskot biraz daha büyür (tuval genişliği yine sınır).
	var mascot_cap: float = MASCOT_MAX + minf(extra, 320.0) * EXTRA_MASCOT_GROWTH
	var mascot_h: float = clampf(minf(minf(h_by_width, h_by_height), mascot_cap), MASCOT_MIN, mascot_cap)
	var mascot_w: float = mascot_h * art_aspect
	var mascot_top: float = maxf(col_bottom - mascot_h * MASCOT_NARROW_TOP, hero_top + 8.0)
	# Kısa ekranda maskot OYNA'ya değmesin: yer payını koruyarak yukarı çek.
	mascot_top = minf(mascot_top, hero_bottom - GROUND_ROOM - mascot_h)
	mascot_top = maxf(mascot_top, hero_top)
	var center := Vector2(view.x * 0.5, mascot_top + mascot_h * 0.5) - Vector2(0.0, hero_top)
	_mascot_home = Rect2(center - Vector2(mascot_w, mascot_h) * 0.5, Vector2(mascot_w, mascot_h))
	_mascot.position = _mascot_home.position
	_mascot.size = _mascot_home.size
	_mascot.pivot_offset = _mascot_home.size * Vector2(0.5, 0.92)
	var glow_size: float = mascot_h * 2.0
	_glow.position = center - Vector2(glow_size, glow_size * 0.9) * 0.5
	_glow.size = Vector2(glow_size, glow_size * 0.9)
	_ground_home = Rect2(center.x - mascot_w * 0.40, center.y + mascot_h * 0.32,
		mascot_w * 0.80, mascot_h * 0.34)
	_ground.position = _ground_home.position
	_ground.size = _ground_home.size
	var stage_w: float = view.x * 1.3
	var stage_h: float = (hero_bottom - hero_top) - (center.y + mascot_h * 0.30) + 120.0
	_stage.position = Vector2(center.x - stage_w * 0.5, center.y + mascot_h * 0.30 - 40.0)
	_stage.size = Vector2(stage_w, maxf(stage_h, 120.0))
	var scale_k: float = mascot_h / MASCOT_REF
	# Yan dumpling'ler maskotun ayak hizasında; uzun ekranda alt sahneye iner.
	var side_drop: float = extra * EXTRA_SIDE_DROP
	for i in _sides.size():
		var spec: Array = SIDE_DUMPLINGS[i]
		var box: float = float(spec[2]) * scale_k
		var at: Vector2 = center + (spec[1] as Vector2) * Vector2(mascot_w, mascot_h) + Vector2(0.0, side_drop)
		_side_homes[i] = at - Vector2(box, box) * 0.5
		_sides[i].position = _side_homes[i]
		_sides[i].size = Vector2(box, box)
		_sides[i].pivot_offset = Vector2(box, box) * 0.5
	for i in _sparkles.size():
		var spec: Array = SPARKLES[i]
		var box: float = float(spec[1]) * scale_k
		var at: Vector2 = center + (spec[0] as Vector2) * Vector2(mascot_w * 1.15, mascot_h)
		_sparkles[i].position = at - Vector2(box, box) * 0.5
		_sparkles[i].size = Vector2(box, box)
	# Alt bant: maskot altı → hero altı arasında (hero koordinatı).
	var band_top: float = center.y + mascot_h * 0.5
	var band_h: float = maxf((hero_bottom - hero_top) - band_top, 40.0)
	for i in _band_sparkles.size():
		var spec: Array = BAND_SPARKLES[i]
		var box: float = float(spec[2])
		var at := Vector2(view.x * float(spec[0]), band_top + band_h * float(spec[1]))
		_band_sparkles[i].position = at - Vector2(box, box) * 0.5
		_band_sparkles[i].size = Vector2(box, box)
		# Kısa ekranda bant dar: pırıltılar maskotun ayaklarına girmesin.
		_band_sparkles[i].visible = band_h >= 120.0


## Boşta hareket: maskot nefes (ölçek %1.5 + ±5 px), yer gölgesi ters fazda,
## yan dumpling'ler farklı fazda salınım, pırıltı sönümü, OYNA %1.5 nefes,
## sandık madalyonu ±3 px, Günlük alınabilirse yalnız nokta nabız. Sinüs —
## RNG yok, gameplay'e dokunmuyor.
func _process(delta: float) -> void:
	_time += delta
	var phase: float = TAU * _time / BOB_PERIOD
	var bob: float = sin(phase)
	_mascot.position = _mascot_home.position + Vector2(0.0, bob * BOB_AMPLITUDE)
	_mascot.scale = Vector2.ONE * (1.0 + BREATH_SCALE * (0.5 + 0.5 * bob))
	var spread: float = 1.0 + bob * 0.06
	_ground.size = _ground_home.size * Vector2(spread, 1.0)
	_ground.position = _ground_home.position + Vector2(_ground_home.size.x * (1.0 - spread) * 0.5, 0.0)
	_ground.modulate.a = 0.85 + bob * 0.15
	for i in _sides.size():
		var spec: Array = SIDE_DUMPLINGS[i]
		_sides[i].position = _side_homes[i] + Vector2(0.0, sin(phase * 0.8 + float(i) * 2.1) * 4.0)
		_sides[i].rotation_degrees = float(spec[3]) + sin(phase * 0.5 + float(i)) * 2.0
	for i in _sparkles.size():
		var spec: Array = SPARKLES[i]
		var twinkle: float = 0.55 + 0.45 * sin(phase * 1.6 + float(spec[2]))
		_sparkles[i].modulate.a = twinkle
		_sparkles[i].scale = Vector2.ONE * (0.8 + 0.3 * twinkle)
		_sparkles[i].pivot_offset = _sparkles[i].size * 0.5
	for i in _band_sparkles.size():
		var spec: Array = BAND_SPARKLES[i]
		var twinkle: float = 0.45 + 0.45 * sin(phase * 1.3 + float(spec[3]))
		_band_sparkles[i].modulate.a = twinkle
		_band_sparkles[i].scale = Vector2.ONE * (0.8 + 0.3 * twinkle)
		_band_sparkles[i].pivot_offset = _band_sparkles[i].size * 0.5
	var pulse: float = 1.0 + CTA_PULSE * (0.5 + 0.5 * sin(TAU * _time / CTA_PERIOD))
	_play_pulse.scale = Vector2.ONE * pulse
	var chest: HomeFeatureButton = _features[&"chest"]
	chest.position = (_feature_homes[&"chest"] as Vector2) + Vector2(0.0, sin(phase * 0.7 + 1.3) * CHEST_FLOAT)
	if _daily_claimable:
		var dot: Control = (_features[&"daily"] as HomeFeatureButton).notification_dot()
		dot.scale = Vector2.ONE * (1.0 + 0.16 * (0.5 + 0.5 * sin(TAU * _time / 1.4)))


# --- Veri ---------------------------------------------------------------------

func refresh() -> void:
	# Seri: yeni oyuncuda çıplak "0" yok — "Seri başlasın"; sonra "N günlük seri".
	var streak: int = SaveManager.daily_streak()
	UiKit.set_pill_value(_streak_pill, "%d günlük seri" % streak if streak > 0 else "Seri başlasın", false)
	UiKit.set_pill_value(_dough_pill, str(SaveManager.dough()), false)

	var levels: Array[LevelData] = LevelLibrary.load_levels()
	var total: int = levels.size()
	var next_level: int = SaveManager.highest_level_unlocked()
	var stars: int = 0
	for i in total:
		stars += SaveManager.stars_for_level(i + 1)
	var max_stars: int = maxi(total * 3, 1)
	_level_stars.text = "%d/%d" % [stars, max_stars]
	if next_level > total:
		# Sonsuz: rozette yalnız büyük taç (66 px dairede "SONSUZ" yazısı
		# okunmuyordu); metin pill'de.
		_level_badge_label.text = "SONSUZ"
		_level_badge_label.visible = false
		_level_crown.custom_minimum_size = Vector2(32, 32)
		_level_caption.text = "SONSUZ MOD"
		var record: int = SaveManager.endless_high_score()
		_level_title.text = "Rekor %s" % GameplayHud._thousands(record) if record > 0 else "Rekor bekliyor"
	else:
		_level_badge_label.text = str(next_level)
		_level_badge_label.visible = true
		_level_crown.custom_minimum_size = Vector2(20, 20)
		_level_caption.text = "SIRADAKİ"
		_level_title.text = "Level %d" % next_level

	var collection: HomeFeatureButton = _features[&"collection"]
	var owned: int = SkinEntry.owned_count()
	var catalog: int = SkinLibrary.total_count()
	collection.set_badge("%d/%d" % [owned, catalog])
	collection.set_progress(float(owned) / float(maxi(catalog, 1)), UiTokens.MINT)
	var preview: Texture2D = SkinEntry.equipped_entry().preview_texture()
	collection.set_art(preview if preview != null else DUMPLING_VISUAL.TEXTURES[0])

	var chest: HomeFeatureButton = _features[&"chest"]
	var merges: int = int(SaveManager.data.get("merges_since_bonus_chest", 0))
	var per_chest: int = ChestSystem.MERGES_PER_BONUS_CHEST
	chest.set_badge("%d/%d" % [merges, per_chest])
	chest.set_progress(float(merges) / float(per_chest), UiTokens.GOLD)

	var daily: HomeFeatureButton = _features[&"daily"]
	_daily_claimable = DailyReward.is_claimable()
	daily.set_notification(_daily_claimable)
	if not _daily_claimable:
		daily.notification_dot().scale = Vector2.ONE
	_layout()


# --- Testler / çekim aracı ---------------------------------------------------

func _layout_with_safe_top(safe_top: float) -> void:
	_safe_top_override = safe_top
	_layout()


func play_button() -> Button:
	return _play


func settings_button() -> Button:
	return _settings_button


func level_button() -> Button:
	return _level


func feature_button(key: StringName) -> HomeFeatureButton:
	return _features.get(key, null)


func feature_keys() -> Array:
	return _features.keys()


func dough_pill() -> Control:
	return _dough_pill


func streak_pill() -> Control:
	return _streak_pill


func level_badge() -> Control:
	return _level_badge


func hero() -> Control:
	return _hero


func mascot_rect() -> Rect2:
	return Rect2(_hero.global_position + _mascot_home.position, _mascot_home.size)


func logo() -> TextureRect:
	return _logo


func is_daily_claimable() -> bool:
	return _daily_claimable
