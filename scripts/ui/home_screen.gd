extends CanvasLayer
## Ana Sayfa V3 (TASK/058) — premium casual oyun hub'ı. Okuma sırası: kimlik / maskot → OYNA → GÜNLÜK | MEYDAN →
## küresel gezinme (TASK/057 kabuğu). Eşdeğer ağırlıkta küçük düğmeler YOK: tek baskın CTA, iki kompakt özellik karosu,
## iki ikincil madalyon. K10 (owner): TEXT-LIGHT / ICON-FIRST — ikon + tek kelime + sayı / rozet / durum; açıklayıcı alt
## yazı yok (UI_VISUAL_SYSTEM §29).
##
##   ÜST      oyuncu durumu (sol: "SV. N" seviye rozeti + seçili unvan + XP rayı) · Hamur bakiyesi (sağ). İkisi de DURUM —
##            dokunma almaz (Profil / Mağaza rotaları kabukta; ikinci bir gezinme sistemi yok). Cihaz üst güvenli payı
##            satırı aşağı iter
##   LOGO     SQUISHY MERGE lockup, üst satırın altında ortada
##   HERO     owner maskotu + lavanta hale + yer gölgesi + tier 3 / tier 6 dumpling + pırıltılar; nefes. Hero'nun üst
##            köşelerinde iki İKİNCİL madalyon (`HomeFeatureButton`, kabuk madalyonlarıyla aynı aile): sol GÖREVLER
##            (N/6 — TASK/046 penceresi), sağ SANDIK (N/75 + altın halka — bonus sandık penceresi). Maskotun dar tepesi
##            madalyonların arasına sokulur, geniş gövdesi altlarında kalır (çakışma testle kilitli)
##   OYNA     V3 birincil CTA (`SquishyButton` PRIMARY HERO, ▶ OYNA) + cyan hale + %1.5 nefes; hemen üstünde DOKUNMA
##            ALMAYAN ilerleme bilgisi ("SIRADAKİ BÖLÜM 5 ★ 11/30"; sonsuzda "SONSUZ MOD Rekor …") → Harita. K9 (owner):
##            oyuncu seviyesi "SV.", harita ilerlemesi "BÖLÜM" — Ana Sayfa'da İngilizce "LV." / "Level" yok
##   KAROLAR  iki kompakt V3 `FeatureTile`, OYNA'nın altında YAN YANA: GÜNLÜK (hediye kuyusu; seri 🔥N, "HAZIR" + "!"
##            rozeti + hale yalnız alınacak varsa, "TAMAM"; tutorial gününde PASİF + kilit + "YARIN") → GÜNLÜK ÖDÜLLER
##            penceresi · MEYDAN (bugünün hedef portresi, "38 HAMLE" — oyun HUD'unun kelimesi —, Hamur ikonu + "+20";
##            tamamlanınca nane "TAMAM") → MEYDAN OKUMA penceresi. Pencerelerin içi DEĞİŞMEDİ
##   TEKLİF   gizli `OfferSlot` (TASK/062 Başlangıç Paketi sözleşmesi — bugün BOŞ, yer kaplamaz; sahte teklif yok)
##   KABUK    TASK/057 GlobalNav (Main'e ait) — karolar kabuğun payının üstünde biter; OYNA ile merkez HARİTA arasında
##            karo sırası: aynı hedefe giden iki düğme üst üste okunmaz
##
## TASK/057 kabuğuyla yinelenen eski girişler KALDIRILDI: MAĞAZA / KOLEKSİYON madalyonları, Hamur "+" kısayolu, Profil
## avatarı, Harita'ya giden level düğmesi (rotalar kabukta + diğer ekranlarda aynen). Ana Sayfa kayda YAZMAZ (tek dolaylı
## yazma TASK/047'nin mevcut ileri-yalnız gün gözlemi: `DailyChallenge.current_view` → `observe_day`). Zemin
## candy-night (ShellBackdrop). Yerleşim `_layout()` ile elle: tuval ≥ 720 px genişlik (içerik ortalı 720 sütun),
## yükseklik serbest; karolar / OYNA alttan sabit, fazla yükseklik hero'ya (maskot büyür).

signal play_pressed
signal daily_requested
signal chest_requested
## GÖREVLER girişi (TASK/046) → Main'in GÖREVLER penceresi.
signal missions_requested
## MEYDAN OKUMA girişi (TASK/047) → Main'in MEYDAN OKUMA penceresi.
signal challenge_requested

const LOGO_ART: Texture2D = preload("res://assets/visual/ui/logo_lockup.png")
const HERO_ART: Texture2D = preload("res://assets/visual/ui/hero_mascot.png")
const CHEST_ART: Texture2D = preload("res://assets/visual/ui/chest_closed.png")
const CROWN_ART: Texture2D = preload("res://assets/visual/ui/icon_crown.png")
const STAR_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
const DUMPLING_VISUAL: GDScript = preload("res://scripts/game/dumpling_visual.gd")

## Yan dumpling'ler: (tier, maskot merkezine göre oran (x: maskot genişliği, y: maskot yüksekliği), kutu (maskot 600
## iken — maskotla ölçeklenir), açı). T6 maskotun kalkık elinin altından uzak (iki sarı tek leke okunmasın).
const SIDE_DUMPLINGS: Array = [
	[3, Vector2(-0.42, 0.40), 112.0, -8.0],
	[6, Vector2(0.47, 0.37), 140.0, 7.0],
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

## Ölçüler (tuval px). İçerik sütunu 720 px (geniş tuvalde ortalı).
const COLUMN_WIDTH: float = 720.0
const TOP_MARGIN: float = 14.0
const SIDE_MARGIN: float = 24.0
const BAR_HEIGHT: float = 56.0
## Logo: geniş ekranda 540, kısa ekranda hero'ya yer açmak için 420'ye kadar küçülür.
const LOGO_WIDTH: float = 540.0
const LOGO_WIDTH_MIN: float = 420.0
const LOGO_GAP: float = 12.0
## İkincil madalyonlar (GÖREVLER / SANDIK): hero'nun üst köşeleri.
const MEDALLION_GAP: float = 6.0
const MEDALLION_HEIGHT: float = HomeFeatureButton.SIZE.y + HomeFeatureButton.PLAQUE_HEIGHT \
	- HomeFeatureButton.PLAQUE_OVERLAP
## OYNA: V3 kahraman CTA (108 px), tuvalin ~3/4'ü.
const PLAY_WIDTH: float = 520.0
const PLAY_HEIGHT: float = float(UiTokens.BUTTON_HEIGHT_HERO)
## Level bilgisi (dokunma ALMAZ): OYNA'nın üstünde, ortalı.
const LEVEL_HEIGHT: float = 44.0
const LEVEL_PLAY_GAP: float = 10.0
## OYNA ile karo sırası arası (birincil CTA nefes alsın; karolar ayrı bir bölge okunsun).
const PLAY_CARDS_GAP: float = 26.0
## Kompakt kabukta (16:9 + banner) daha sıkı: karoların ek tepsi payı maskottan yemesin.
const PLAY_CARDS_GAP_COMPACT: float = 16.0
## İki karo arası (yan yana).
const TILE_GAP: float = 16.0
## Kartların alt kenarı ile kabuk payının üstü (kabuk yokken ekran altı) arası. Kompakt kabukta (merkez taşması yok —
## 16:9 + banner) pay tepsinin tam üstünde biter: seçili yan madalyon 14 px yükselir ve dock'un solması tepsinin 30 px
## üstünde başlar → kart en az NAV_CARD_CLEARANCE_COMPACT uzakta.
const NAV_CARD_CLEARANCE: float = 14.0
const NAV_CARD_CLEARANCE_COMPACT: float = 32.0
## Merkez taşması bundan küçükse kabuk kompakt sayılır.
const NAV_RISE_COMPACT: float = 30.0
const BOTTOM_MARGIN: float = 24.0
const OFFER_GAP: float = 14.0
## Yan dumpling'lerin alt kenarı ile level bilgisi (hero bölgesinin altı) arası en az boşluk (±4 px salınım dahil).
const SIDE_PILL_CLEARANCE: float = 8.0
const MASCOT_MIN: float = 300.0
## Yer yoksa (ör. ileride teklif kartı + en dar ekran) maskot MASCOT_MIN'in altına inebilir, bundan aşağı değil — level
## bilgisiyle / OYNA ile çakışmaktansa küçülür.
const MASCOT_HARD_MIN: float = 200.0
const MASCOT_MAX: float = 600.0
const MASCOT_REF: float = 600.0
const MASCOT_SIDE_MARGIN: float = 44.0
## Maskotun üst %22'si dar (tepe): madalyonların arasına bu kadar sokulabilir.
const MASCOT_NARROW_TOP: float = 0.22
## Maskot madalyonların YANINDA da durabilir (kısa ekran): iki madalyon sütunu arasındaki boşluk payı.
const MASCOT_MEDALLION_GAP: float = 8.0
## Oyuncu durum rozeti çapı: üst yazı çapın %19'u — 74 px'te 14 px (V3 en küçük yazı).
const STATUS_BADGE: float = 74.0
## K9 (owner, TASK/058): Ana Sayfa terimleri — oyuncu seviyesi "SV. N", sıradaki harita bölümü "BÖLÜM N".
const STATUS_LEVEL_CAPTION: String = "SV."
const NEXT_LEVEL_FORMAT: String = "BÖLÜM %d"
## Maskotun altında yer gölgesi + yan dumpling payı.
const GROUND_ROOM: float = 56.0
## Uzun ekranda (hero gerekenden yüksek): fazlanın bu payı logonun üstüne / madalyonların üstüne gök olur, maskot
## kalan bölgede dikeyde ortalanır.
const EXTRA_SKY_SHARE: float = 0.16
const EXTRA_SKY_MAX: float = 56.0
## Hareket.
const BOB_PERIOD: float = 2.6
const BOB_AMPLITUDE: float = 5.0
const BREATH_SCALE: float = 0.015
const CTA_PULSE: float = 0.015
const CTA_PERIOD: float = 1.9
const CHEST_FLOAT: float = 3.0
## K10 (owner, TASK/058): TEXT-LIGHT / ICON-FIRST — Ana Sayfa'da tek kelime + sayı / rozet. Cümleler YOK (pencerelerin
## içi değişmedi; ayrıntı orada).
const DAILY_TITLE: String = "GÜNLÜK"
## İlk gün kuralı (GAME_DESIGN §12.3): kilit kuyusu + tek kelime.
const DAILY_LOCKED: String = "YARIN"
## Alınacak bir şey var (giriş ödülü / ücretsiz sandık): GÜNLÜK penceresindeki "HAZIR" ciplerinin kelimesi.
const DAILY_READY: String = "HAZIR"
const DONE_TAG: String = "TAMAM"
const CHALLENGE_TITLE: String = "MEYDAN"
## Bırakış bütçesi: meydan okuma HUD'unun "HAMLE" plakasıyla aynı kelime.
const CHALLENGE_MOVES: String = "%d HAMLE"
const CHALLENGE_REWARD: String = "+%d"
const CHEST_LABEL: String = "SANDIK"

var _status: Control
var _status_badge: PlayerLevelBadge
var _status_title: Label
var _status_rail: Control
var _status_ratio: float = 0.0
var _dough_pill: Control
var _logo: TextureRect
var _hero: Control
var _glow: NinePatchRect
var _stage: NinePatchRect
var _ground: NinePatchRect
var _mascot: TextureRect
var _sides: Array[TextureRect] = []
var _sparkles: Array[TextureRect] = []
var _missions: HomeFeatureButton
var _chest: HomeFeatureButton
var _play_pulse: Control
var _play_halo: NinePatchRect
var _play: SquishyButton
var _level: PanelContainer
var _level_crown: TextureRect
var _level_caption: Label
var _level_title: Label
var _level_stars: Label
var _daily: FeatureTile
var _challenge: FeatureTile
var _offer_slot: Control
## ui_smoke_test uyumluluğu: "nereye gidiyorum" ipucu = level bilgisinin başlığı.
var _play_hint: Label
var _mascot_home: Rect2 = Rect2()
var _ground_home: Rect2 = Rect2()
var _side_homes: Array[Vector2] = []
var _chest_home: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _daily_claimable: bool = false
## Günlük kartının durumu (test / inceleme): locked · login · free_chest · free_taken · all_done.
var _daily_state: StringName = &""
## Kabuğun merkez taşması (Main `set_nav_inset`); < 0 bilinmiyor (kabuksuz test).
var _nav_rise: float = -1.0
## Test kancası: cihaz üst güvenli payı (A36 punch-hole) masaüstünde okunamaz; negatif = gerçek değeri kullan.
var _safe_top_override: float = -1.0
## TASK/057: küresel gezinme kabuğunun alt payı (Main `set_nav_inset`); kabuksuz (tek başına test) 0.
var _nav_inset: float = 0.0

@onready var _root: Control = $Root
@onready var _backdrop: Control = $Backdrop


func _ready() -> void:
	_tune_backdrop()
	_build_top()
	_build_hero()
	_build_medallions()
	_build_play()
	_build_tiles()
	_root.resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		set_process(visible)
		if visible:
			_layout())
	set_process(visible)
	refresh()
	_layout()


# --- Kurulum ------------------------------------------------------------------

## Hub'da dünya nefes alsın: kabuk zemini (ShellBackdrop) sekmelerde koyu karartılıyor (liste/kart okunurluğu); Ana
## Sayfa'da gece kasabası daha görünür — karartma azalır, alt solma kartlar için kalır. Yalnız bu sahnenin örneği değişir.
func _tune_backdrop() -> void:
	var night: CanvasItem = _backdrop.get_node_or_null("Night")
	if night != null:
		night.modulate = Color(0.82, 0.80, 0.94, 1.0)
	var scrim: ColorRect = _backdrop.get_node_or_null("Scrim")
	if scrim != null:
		scrim.color = Color(0.07, 0.05, 0.18, 0.22)
	var fade: CanvasItem = _backdrop.get_node_or_null("BottomFade")
	if fade != null:
		fade.modulate = Color(1, 1, 1, 0.85)


## Üst satır: iki DURUM pill'i (HUD v5 lavanta glossy pill ailesi, `UiKit.home_pill` reçetesi). Dokunma almaz.
func _build_top() -> void:
	_status = Control.new()
	_status.name = "PlayerStatus"
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_status)
	var shadow := UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.26))
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = -14.0
	shadow.offset_top = -9.0
	shadow.offset_right = 14.0
	shadow.offset_bottom = 19.0
	_status.add_child(shadow)
	var rim := UiKit.flat_plate("label_round", UiTokens.LAVENDER_LIGHT)
	rim.offset_left = -3.0
	rim.offset_top = -3.0
	rim.offset_right = 3.0
	rim.offset_bottom = 3.0
	_status.add_child(rim)
	var pill := UiKit.panel(&"PanelHomePill")
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_status.add_child(pill)
	var gloss := UiKit.patch("btn_bevel_light", Color(1, 1, 1, 0.30))
	gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_left = 8.0
	gloss.offset_right = -8.0
	gloss.offset_top = 3.0
	gloss.offset_bottom = BAR_HEIGHT * 0.40
	_status.add_child(gloss)
	# Seviye rozeti pill'in sol ucundan taşar (level rozeti dili); metin + XP rayı pill içinde.
	_status_badge = PlayerLevelBadge.new(STATUS_BADGE)
	_status_badge.name = "LevelBadge"
	_status_badge.set_caption(STATUS_LEVEL_CAPTION)
	_status.add_child(_status_badge)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 3)
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = STATUS_BADGE - 22.0 + 8.0
	column.offset_right = -14.0
	column.offset_top = 4.0
	column.offset_bottom = -8.0
	_status.add_child(column)
	_status_title = UiKit.label("", &"LabelSectionOnDark")
	_status_title.name = "Title"
	_status_title.add_theme_font_size_override("font_size", 18)
	_status_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_status_title)
	_status_rail = Control.new()
	_status_rail.name = "XpRail"
	_status_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_rail.custom_minimum_size = Vector2(0.0, 10.0)
	_status_rail.draw.connect(_draw_status_rail)
	column.add_child(_status_rail)
	_dough_pill = UiKit.home_pill(UiIcons.DOUGH, "", false, BAR_HEIGHT)
	_dough_pill.name = "DoughPill"
	_dough_pill.minimum_size_changed.connect(_layout)
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
	# Sıcak sahne ışığı: maskotun ayaklarının altında geniş, çok düşük alfa krem havuz.
	_stage = UiKit.patch("popup_glow", Color(1.0, 0.92, 0.72, 0.16))
	_stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hero.add_child(_stage)
	# Erik yer gölgesi: karakter havada asılı durmasın; nefesle daralır.
	_ground = UiKit.patch("popup_glow", Color(0.16, 0.07, 0.30, 0.78))
	_ground.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hero.add_child(_ground)
	for spec in SIDE_DUMPLINGS:
		var side := UiKit.art(DUMPLING_VISUAL.TEXTURES[int(spec[0]) - 1], float(spec[2]))
		# Boy maskotla ölçeklenir (_layout): en küçük boy tam kutu kalsaydı kısa ekranda ~1.6 kat büyük çizilirdi.
		side.custom_minimum_size = Vector2.ZERO
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
		spark.custom_minimum_size = Vector2.ZERO
		spark.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_hero.add_child(spark)
		_sparkles.append(spark)
	# Logo maskotun üstünde (hero'nun önünde) — üst satırın altında ortada.
	_logo = UiKit.art(LOGO_ART, 0)
	_logo.name = "Logo"
	_logo.custom_minimum_size = Vector2.ZERO
	_logo.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.add_child(_logo)


## İki ikincil madalyon — TEK bileşen (`HomeFeatureButton`); her biri gerçek bir pencereye bağlı.
func _build_medallions() -> void:
	_missions = HomeFeatureButton.new()
	_missions.name = "Missions"
	_missions.set_icon("goal", UiTokens.MINT)
	_missions.set_label("GÖREVLER")
	_missions.set_anchors_preset(Control.PRESET_TOP_LEFT)
	GestureGuard.on_pressed(_missions, func() -> void: missions_requested.emit())
	_root.add_child(_missions)
	_chest = HomeFeatureButton.new()
	_chest.name = "Chest"
	_chest.set_art(CHEST_ART)
	# K10: tek kelime (sandık sanatı + N/75 halkası anlamı taşır; Ana Sayfa'da başka "sandık" yazısı yok — GÜNLÜK karosu
	# cümle göstermez). Pencere başlığı (BONUS SANDIK) aynen.
	_chest.set_label(CHEST_LABEL)
	_chest.set_anchors_preset(Control.PRESET_TOP_LEFT)
	GestureGuard.on_pressed(_chest, func() -> void: chest_requested.emit())
	_root.add_child(_chest)


func _build_play() -> void:
	_build_level_info()
	# OYNA: nefes wrapper'ı (butonun kendi ölçeği basışa kalır) + arkasında cyan hale.
	_play_pulse = Control.new()
	_play_pulse.name = "CtaPulse"
	_play_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_play_pulse)
	_play_halo = UiKit.patch("popup_glow", Color(UiTokens.CYAN, 0.40))
	_play_halo.name = "Halo"
	_play_halo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_halo.offset_left = -40.0
	_play_halo.offset_right = 40.0
	_play_halo.offset_top = -30.0
	_play_halo.offset_bottom = 34.0
	_play_pulse.add_child(_play_halo)
	_play = SquishyButton.new("OYNA", SquishyButton.Kind.PRIMARY, SquishyButton.SizeClass.HERO, "play")
	_play.name = "Play"
	_play.set_anchors_preset(Control.PRESET_FULL_RECT)
	GestureGuard.on_pressed(_play, func() -> void: play_pressed.emit())
	_play_pulse.add_child(_play)


## Level bilgisi: OYNA'nın hedefini söyleyen DURUM satırı — düğme değil (çerçeve / dudak / basış yok, fare almaz).
## Koyu yarı saydam hap + altın taç + "SIRADAKİ" + "BÖLÜM 5" + ★ "11/30". Sonsuz: "SONSUZ MOD" / "Rekor 12 480".
func _build_level_info() -> void:
	_level = PanelContainer.new()
	_level.name = "LevelInfo"
	_level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiKit.v3_box(Color(UiTokens.NAVY_PURPLE_DEEP, 0.62), LEVEL_HEIGHT * 0.5)
	box.content_margin_left = 16.0
	box.content_margin_right = 18.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 4.0
	_level.add_theme_stylebox_override("panel", box)
	_root.add_child(_level)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_level.add_child(row)
	_level_crown = UiKit.art(CROWN_ART, 26)
	_level_crown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_level_crown)
	_level_caption = UiKit.label("SIRADAKİ", &"LabelHudCaption")
	_level_caption.add_theme_font_size_override("font_size", UiTokens.TYPE_SECONDARY)
	_level_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_level_caption)
	_level_title = UiKit.label(NEXT_LEVEL_FORMAT % 1, &"LabelSectionOnDark")
	_level_title.add_theme_font_size_override("font_size", 22)
	_level_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_level_title)
	_play_hint = _level_title
	var star := UiKit.art(STAR_ART, 18)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(star)
	_level_stars = UiKit.label("0/30", &"LabelBadgeOnDark")
	_level_stars.add_theme_font_size_override("font_size", UiTokens.TYPE_SECONDARY)
	_level_stars.add_theme_color_override("font_color", UiTokens.GOLD)
	_level_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_level_stars)
	_level.minimum_size_changed.connect(_layout)


## İki kompakt V3 özellik karosu (karonun TAMAMI tek dokunma hedefi; GestureGuard) + gizli teklif yuvası.
func _build_tiles() -> void:
	_daily = FeatureTile.new(DAILY_TITLE, UiTokens.PINK, null, "gift")
	_daily.name = "Daily"
	_daily.set_anchors_preset(Control.PRESET_TOP_LEFT)
	GestureGuard.on_pressed(_daily, func() -> void: daily_requested.emit())
	_root.add_child(_daily)
	_challenge = FeatureTile.new(CHALLENGE_TITLE, UiTokens.LAVENDER, DUMPLING_VISUAL.TEXTURES[4])
	_challenge.name = "Challenge"
	_challenge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	GestureGuard.on_pressed(_challenge, func() -> void: challenge_requested.emit())
	_root.add_child(_challenge)
	# TASK/062 sözleşmesi: Başlangıç Paketi kartı (OfferCard) bu yuvaya çocuk olarak eklenir ve yuva görünür yapılır;
	# `_layout` onu karolarla kabuk arasına yerleştirir, hero küçülür. Bugün yuva BOŞ ve gizli — yer kaplamaz, sahte
	# teklif / süre / fiyat YOK.
	_offer_slot = Control.new()
	_offer_slot.name = "OfferSlot"
	_offer_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer_slot.visible = false
	_root.add_child(_offer_slot)
	# Yuva kendini korur: görünürlük / içerik değişince yerleşim yeniden kurulur (TASK/062 ayrıca refresh çağırmak zorunda değil).
	_offer_slot.visibility_changed.connect(_layout.call_deferred)
	_offer_slot.child_entered_tree.connect(func(_child: Node) -> void: _layout.call_deferred())
	_offer_slot.child_exiting_tree.connect(func(_child: Node) -> void: _layout.call_deferred())


# --- Yerleşim -----------------------------------------------------------------

func _layout() -> void:
	if _root == null or _play == null or _daily == null:
		return
	var view: Vector2 = _root.size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var safe_top: float = _safe_top_override if _safe_top_override >= 0.0 else UiKit.safe_top(view)
	var column_w: float = minf(view.x, COLUMN_WIDTH)
	var left: float = (view.x - column_w) * 0.5
	var center_x: float = view.x * 0.5
	# Alt bütçe: gesture bar + banner yuvası (M8.9-01; eklentisiz 0) + küresel gezinme kabuğu (TASK/057).
	var compact: bool = _nav_inset > 0.0 and _nav_rise >= 0.0 and _nav_rise < NAV_RISE_COMPACT
	var clearance: float = BOTTOM_MARGIN
	if _nav_inset > 0.0:
		clearance = NAV_CARD_CLEARANCE_COMPACT if compact else NAV_CARD_CLEARANCE
	var bottom: float = view.y - UiKit.bottom_inset(view) - _nav_inset - clearance

	# ÜST satır: oyuncu durumu (sol) · Hamur (sağ), ortak optik merkez.
	var top_y: float = safe_top + TOP_MARGIN
	# Seviye rozeti pill'in sol ucundan 22 px taşar (rozet dahil sol pay = SIDE_MARGIN).
	# Unvanın GERÇEK genişliği (kırpan Label'ın en küçük boyu 1 px'tir — ölçü yazı tipinden).
	var title_w: float = _status_title.get_theme_font("font").get_string_size(_status_title.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, _status_title.get_theme_font_size("font_size")).x
	var status_w: float = clampf(title_w + STATUS_BADGE - 22.0 + 8.0 + 14.0 + 8.0, 210.0, 300.0)
	_status.position = Vector2(left + SIDE_MARGIN + 22.0, top_y)
	_status.size = Vector2(status_w, BAR_HEIGHT)
	_status_badge.position = Vector2(-22.0, (BAR_HEIGHT - _status_badge.custom_minimum_size.y) * 0.5 + 3.0)
	_status_badge.size = _status_badge.custom_minimum_size
	var dough_size: Vector2 = _dough_pill.custom_minimum_size
	_dough_pill.size = dough_size
	_dough_pill.position = Vector2(left + column_w - SIDE_MARGIN - dough_size.x, top_y + (BAR_HEIGHT - dough_size.y) * 0.5)

	# Alttan yukarı: teklif yuvası (boşsa yok) → GÜNLÜK | MEYDAN karo sırası → OYNA → level bilgisi.
	var card_w: float = column_w - SIDE_MARGIN * 2.0
	var card_x: float = left + SIDE_MARGIN
	var cursor: float = bottom
	if _offer_slot.visible and _offer_slot.get_child_count() > 0:
		var offer_h: float = 0.0
		for child in _offer_slot.get_children():
			if child is Control:
				offer_h = maxf(offer_h, (child as Control).get_combined_minimum_size().y)
		_offer_slot.position = Vector2(card_x, cursor - offer_h)
		_offer_slot.size = Vector2(card_w, offer_h)
		for child in _offer_slot.get_children():
			if child is Control:
				(child as Control).position = Vector2.ZERO
				(child as Control).size = _offer_slot.size
		cursor -= offer_h + OFFER_GAP
	# Karolar yan yana (eşit genişlik); MEYDAN gizliyse (gün gerçeği yok) GÜNLÜK tek başına ortada.
	var tile_w: float = (card_w - TILE_GAP) * 0.5
	var tile_top: float = cursor - FeatureTile.HEIGHT
	if _challenge.visible:
		_daily.position = Vector2(card_x, tile_top)
		_challenge.position = Vector2(card_x + tile_w + TILE_GAP, tile_top)
		_challenge.size = Vector2(tile_w, FeatureTile.HEIGHT)
	else:
		_daily.position = Vector2(center_x - tile_w * 0.5, tile_top)
	_daily.size = Vector2(tile_w, FeatureTile.HEIGHT)
	cursor = tile_top - (PLAY_CARDS_GAP_COMPACT if compact else PLAY_CARDS_GAP)
	var play_w: float = minf(PLAY_WIDTH, column_w - 2.0 * 64.0)
	var play_top: float = cursor - PLAY_HEIGHT
	_play_pulse.position = Vector2(center_x - play_w * 0.5, play_top)
	_play_pulse.size = Vector2(play_w, PLAY_HEIGHT)
	_play_pulse.pivot_offset = _play_pulse.size * 0.5
	var level_size: Vector2 = Vector2(maxf(_level.get_combined_minimum_size().x, 200.0), LEVEL_HEIGHT)
	var level_top: float = play_top - LEVEL_PLAY_GAP - LEVEL_HEIGHT
	_level.position = Vector2(center_x - level_size.x * 0.5, level_top)
	_level.size = level_size

	# LOGO: kısa ekranda küçülür (hero'ya yer).
	var logo_aspect: float = float(LOGO_ART.get_height()) / float(LOGO_ART.get_width())
	var hero_room: float = level_top - (top_y + BAR_HEIGHT)
	var logo_w: float = clampf(LOGO_WIDTH - maxf(640.0 - hero_room, 0.0) * 0.8, LOGO_WIDTH_MIN, LOGO_WIDTH)
	var logo_h: float = logo_w * logo_aspect
	# Uzun ekranda fazla yükseklik: payın bir kısmı logonun üstüne gök olur.
	var needed: float = LOGO_GAP + logo_h + MEDALLION_GAP + MEDALLION_HEIGHT + MASCOT_MAX * (1.0 - MASCOT_NARROW_TOP) \
		+ GROUND_ROOM
	var sky: float = clampf((hero_room - needed) * EXTRA_SKY_SHARE, 0.0, EXTRA_SKY_MAX)
	var logo_top: float = top_y + BAR_HEIGHT + LOGO_GAP + sky
	_logo.position = Vector2(center_x - logo_w * 0.5, logo_top)
	_logo.size = Vector2(logo_w, logo_h)
	var logo_bottom: float = logo_top + logo_h

	# İkincil madalyonlar: hero'nun üst köşeleri.
	var medal_top: float = logo_bottom + MEDALLION_GAP + sky
	_missions.position = Vector2(left + SIDE_MARGIN, medal_top)
	_missions.size = HomeFeatureButton.SIZE
	_chest_home = Vector2(left + column_w - SIDE_MARGIN - HomeFeatureButton.SIZE.x, medal_top)
	_chest.position = _chest_home
	_chest.size = HomeFeatureButton.SIZE
	var medal_bottom: float = medal_top + MEDALLION_HEIGHT

	# HERO: logo altı → level bilgisi üstü. İki yerleşimden büyüğü: (a) maskot madalyon sütunlarının ARASINA sığar
	# (genişliği sütunlar arası boşluk kadar — kısa ekran), (b) yalnız dar tepesi madalyonların arasına sokulur, geniş
	# gövdesi madalyon satırının ALTINDA kalır (uzun ekran — maskot daha büyük).
	var hero_top: float = logo_bottom + 2.0
	var hero_bottom: float = level_top - 6.0
	_hero.position = Vector2(0.0, hero_top)
	_hero.size = Vector2(view.x, maxf(hero_bottom - hero_top, 1.0))
	var art_aspect: float = float(HERO_ART.get_width()) / float(HERO_ART.get_height())
	var h_by_width: float = (column_w - 2.0 * MASCOT_SIDE_MARGIN) / art_aspect
	var between_w: float = column_w - 2.0 * (SIDE_MARGIN + HomeFeatureButton.SIZE.x + MASCOT_MEDALLION_GAP)
	var h_beside: float = minf(hero_bottom - GROUND_ROOM - (hero_top + 4.0), between_w / art_aspect)
	var h_below: float = minf((hero_bottom - GROUND_ROOM - medal_bottom) / (1.0 - MASCOT_NARROW_TOP), h_by_width)
	var beside: bool = h_beside >= h_below
	# En küçük boy yer varsa MASCOT_MIN; yer yoksa MASCOT_HARD_MIN'e kadar iner (level bilgisi / OYNA ile çakışmaz).
	var room: float = hero_bottom - GROUND_ROOM - (hero_top + 4.0)
	var floor_h: float = clampf(room, MASCOT_HARD_MIN, MASCOT_MIN)
	var mascot_h: float = clampf(minf(maxf(h_beside, h_below), MASCOT_MAX), floor_h, MASCOT_MAX)
	var mascot_w: float = mascot_h * art_aspect
	# (b)'de en yukarı: dar tepe madalyon satırının altına sokulur. Fazla yer varsa maskot kalan bölgede dikeyde ortalanır.
	var top_min: float = hero_top + 4.0 if beside else maxf(medal_bottom - mascot_h * MASCOT_NARROW_TOP, hero_top + 4.0)
	var top_max: float = hero_bottom - GROUND_ROOM - mascot_h
	var mascot_top: float = top_min + maxf(top_max - top_min, 0.0) * 0.5
	mascot_top = maxf(minf(mascot_top, top_max), hero_top)
	var center := Vector2(center_x, mascot_top + mascot_h * 0.5) - Vector2(0.0, hero_top)
	_mascot_home = Rect2(center - Vector2(mascot_w, mascot_h) * 0.5, Vector2(mascot_w, mascot_h))
	_mascot.position = _mascot_home.position
	_mascot.size = _mascot_home.size
	_mascot.pivot_offset = _mascot_home.size * Vector2(0.5, 0.92)
	var glow_size: float = mascot_h * 2.0
	_glow.position = center - Vector2(glow_size, glow_size * 0.9) * 0.5
	_glow.size = Vector2(glow_size, glow_size * 0.9)
	_ground_home = Rect2(center.x - mascot_w * 0.40, center.y + mascot_h * 0.32, mascot_w * 0.80, mascot_h * 0.34)
	_ground.position = _ground_home.position
	_ground.size = _ground_home.size
	var stage_w: float = view.x * 1.3
	var stage_h: float = (hero_bottom - hero_top) - (center.y + mascot_h * 0.30) + 120.0
	_stage.position = Vector2(center.x - stage_w * 0.5, center.y + mascot_h * 0.30 - 40.0)
	_stage.size = Vector2(stage_w, maxf(stage_h, 120.0))
	var scale_k: float = mascot_h / MASCOT_REF
	# Yan dumpling'ler maskotun ayak hizasında; level bilgisinin arkasına inmez (sınır gerçek çizim boyuyla).
	for i in _sides.size():
		var spec: Array = SIDE_DUMPLINGS[i]
		var box: float = float(spec[2]) * scale_k
		var at: Vector2 = center + (spec[1] as Vector2) * Vector2(mascot_w, mascot_h)
		var home_at: Vector2 = at - Vector2(box, box) * 0.5
		var drawn: float = maxf(box, _sides[i].get_combined_minimum_size().y)
		home_at.y = minf(home_at.y, hero_bottom - hero_top - drawn - SIDE_PILL_CLEARANCE)
		_side_homes[i] = home_at
		_sides[i].position = _side_homes[i]
		_sides[i].size = Vector2(box, box)
		_sides[i].pivot_offset = Vector2(box, box) * 0.5
	for i in _sparkles.size():
		var spec: Array = SPARKLES[i]
		var box: float = float(spec[1]) * scale_k
		var at: Vector2 = center + (spec[0] as Vector2) * Vector2(mascot_w * 1.15, mascot_h)
		_sparkles[i].position = at - Vector2(box, box) * 0.5
		_sparkles[i].size = Vector2(box, box)


## Boşta hareket: maskot nefes (ölçek %1.5 + ±5 px), yer gölgesi ters fazda, yan dumpling'ler farklı fazda salınım,
## pırıltı sönümü, OYNA %1.5 nefes, sandık madalyonu ±3 px. Sinüs — RNG yok, gameplay'e dokunmuyor.
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
	var pulse: float = 1.0 + CTA_PULSE * (0.5 + 0.5 * sin(TAU * _time / CTA_PERIOD))
	_play_pulse.scale = Vector2.ONE * pulse
	_chest.position = _chest_home + Vector2(0.0, sin(phase * 0.7 + 1.3) * CHEST_FLOAT)


func _draw_status_rail() -> void:
	var rect := Rect2(Vector2.ZERO, _status_rail.size)
	_status_rail.draw_style_box(UiKit.v3_box(Color(UiTokens.NAVY_PURPLE_DEEP, 0.60), rect.size.y * 0.5), rect)
	if _status_ratio > 0.0:
		var fill := Rect2(rect.position, Vector2(maxf(rect.size.x * _status_ratio, rect.size.y), rect.size.y))
		_status_rail.draw_style_box(UiKit.v3_box(UiTokens.CYAN, rect.size.y * 0.5), fill)


# --- Veri ---------------------------------------------------------------------

func refresh() -> void:
	# Üst satır: oyuncu seviyesi + seçili unvan + seviye içi XP oranı; Hamur bakiyesi.
	var progress: Dictionary = PlayerProfile.level_progress()
	_status_badge.set_level(int(progress["level"]))
	_status_title.text = PlayerProfile.selected_title_name()
	_status_ratio = float(progress["ratio"])
	_status_rail.queue_redraw()
	UiKit.set_pill_value(_dough_pill, str(SaveManager.dough()), false)

	var levels: Array[LevelData] = LevelLibrary.load_levels()
	var total: int = levels.size()
	var next_level: int = SaveManager.highest_level_unlocked()
	var stars: int = 0
	for i in total:
		stars += SaveManager.stars_for_level(i + 1)
	_level_stars.text = "%d/%d" % [stars, maxi(total * 3, 1)]
	if next_level > total:
		_level_caption.text = "SONSUZ MOD"
		var record: int = SaveManager.endless_high_score()
		_level_title.text = "Rekor %s" % GameplayHud._thousands(record) if record > 0 else "Rekor bekliyor"
	else:
		_level_caption.text = "SIRADAKİ"
		_level_title.text = NEXT_LEVEL_FORMAT % next_level

	var merges: int = int(SaveManager.data.get("merges_since_bonus_chest", 0))
	var per_chest: int = ChestSystem.MERGES_PER_BONUS_CHEST
	_chest.set_badge("%d/%d" % [merges, per_chest])
	_chest.set_progress(float(merges) / float(per_chest), UiTokens.GOLD)

	refresh_daily()
	refresh_missions()
	refresh_daily_challenge()
	_layout()


## GÜNLÜK karosu — yalnız gerçek durum (YAZMAZ), K10 görsel dil: ilk gün kuralında PASİF + kilit + "YARIN" (pencere
## açılmaz, GAME_DESIGN §12.3); giriş ödülü / ücretsiz sandık hazırsa "HAZIR" cipi + "!" rozeti + hale; bugünlük her şey
## alındıysa nane "TAMAM"; seri (bugünün giriş ödülü alındıysa) alev ikonu + sayı.
func refresh_daily() -> void:
	var chips: Array = []
	_daily_claimable = DailyReward.is_claimable()
	var state: Dictionary = DailyRewards.state()
	if not Onboarding.daily_rewards_unlocked():
		_daily_state = &"locked"
		# "YARIN" YALNIZ ilk gün kuralında doğru; onboarding bitmemişse (Ana Sayfa o durumda görünmez) cip yok.
		if Onboarding.is_first_day_suppressed():
			chips.append({"text": DAILY_LOCKED, "kind": FeatureTile.KIND_MUTED})
	else:
		if _daily_claimable:
			_daily_state = &"login"
		elif bool(state["free_chest_available"]):
			_daily_state = &"free_chest"
		elif bool(state["all_done"]):
			_daily_state = &"all_done"
		else:
			_daily_state = &"free_taken"
		var streak: int = SaveManager.daily_streak()
		if streak > 0 and DailyReward.claimed_today():
			chips.append({"text": str(streak), "icon": UiIcons.FLAME, "kind": FeatureTile.KIND_INFO})
		if _daily_state == &"login" or _daily_state == &"free_chest":
			chips.append({"text": DAILY_READY, "kind": FeatureTile.KIND_GOLD})
		elif _daily_state == &"all_done":
			chips.append({"text": DONE_TAG, "kind": FeatureTile.KIND_MINT})
	_daily.set_chips(chips)
	# Kilitli: kilit pictosu + pasif karo — sessiz ölü giriş değil, durumu söyleyen karo.
	_daily.set_art(null, "lock" if _daily_state == &"locked" else "gift")
	_daily.set_enabled(_daily_state != &"locked")
	var ready: bool = _daily_state == &"login" or _daily_state == &"free_chest"
	_daily.set_glow(ready)
	if ready:
		_daily.badge().show_claim()
	else:
		_daily.badge().clear()


## GÖREVLER rozeti: içinde bulunulan dönemlerde tamamlanan görev "N/6" (kabul edilen günün dönemi — Missions.current,
## YAZMAZ). 6/6'da rozet nane. Main öne dönüşte de çağırır (gün değişmiş olabilir).
func refresh_missions() -> void:
	var total: int = Missions.CATALOG.size()
	var done: int = Missions.completed_count(Missions.current())
	_missions.set_badge("%d/%d" % [done, total])
	var panel: PanelContainer = _missions.badge_panel()
	if done >= total:
		panel.add_theme_stylebox_override("panel", UiKit.style("badge_round", UiTokens.MINT, _badge_margin()))
	else:
		panel.remove_theme_stylebox_override("panel")


## MEYDAN karosu: bugünün meydan okuması (DailyChallenge.current_view — YAZMAZ). Onboarding bitmeden / gün gerçeği
## yokken gizli (GÜNLÜK ortaya geçer); hedef portresi + "38 HAMLE" + Hamur ikonu "+20" (gerçek bütçe ve ödül); tamamlanınca
## nane "TAMAM" (pencere yine açılır, tamamlandı durumunu gösterir). Main öne dönüşte ve pencerenin gün tazelemesinde de
## çağırır.
func refresh_daily_challenge() -> void:
	var view: Dictionary = DailyChallenge.current_view() if Onboarding.is_completed() else {}
	var was_visible: bool = _challenge.visible
	_challenge.visible = not view.is_empty()
	if was_visible != _challenge.visible:
		_layout()
	if view.is_empty():
		return
	var target: int = clampi(int(view["target_tier"]), 1, TierConfig.MAX_TIER)
	_challenge.set_art(DUMPLING_VISUAL.TEXTURES[target - 1])
	if bool(view["completed"]):
		_challenge.set_chips([{"text": DONE_TAG, "kind": FeatureTile.KIND_MINT}])
	else:
		_challenge.set_chips([
			{"text": CHALLENGE_MOVES % int(view["drop_budget"]), "kind": FeatureTile.KIND_INFO},
			{"text": CHALLENGE_REWARD % DailyChallenge.REWARD_DOUGH, "icon": UiIcons.DOUGH, "kind": FeatureTile.KIND_GOLD},
		])


## Rozet içerik payı (tema Badge'inin kendi payı; nane boyamada aynı ölçü kalsın).
func _badge_margin() -> Vector4:
	var box: StyleBox = UiKit.theme().get_stylebox("panel", &"Badge")
	return Vector4(box.content_margin_left, box.content_margin_top, box.content_margin_right,
		box.content_margin_bottom)


# --- Testler / çekim aracı ---------------------------------------------------

func _layout_with_safe_top(safe_top: float) -> void:
	_safe_top_override = safe_top
	_layout()


## TASK/057: küresel gezinme kabuğunun alt payı (tuval px). Main kabuğu kurunca verir; `rise` = merkez taşması (TASK/058:
## kompakt kabukta kartlar tepsiden daha uzak).
func set_nav_inset(px: float, rise: float = -1.0) -> void:
	_nav_inset = maxf(px, 0.0)
	_nav_rise = rise
	_layout()


func nav_inset() -> float:
	return _nav_inset


func play_button() -> SquishyButton:
	return _play


## Level bilgisi (dokunma almaz — durum).
func level_info() -> PanelContainer:
	return _level


func level_title_text() -> String:
	return _level_title.text


func level_caption_text() -> String:
	return _level_caption.text


func level_stars_text() -> String:
	return _level_stars.text


## GÜNLÜK karosu (K10; eski ad korunur).
func daily_card() -> FeatureTile:
	return _daily


## locked · login · free_chest · free_taken · all_done
func daily_state() -> StringName:
	return _daily_state


## MEYDAN karosu (K10; eski ad korunur).
func challenge_card() -> FeatureTile:
	return _challenge


## MEYDAN OKUMA girişi (TASK/047; K10'dan beri kompakt karo).
func challenge_button() -> Button:
	return _challenge


func challenge_title_text() -> String:
	return _challenge.title_text()


## Ödül cipi "+20" (tamamlanmadan) ya da boş (tamamlandı cipi gösteriliyor).
func challenge_badge_text() -> String:
	var kinds: Array = _challenge.chip_kinds()
	var texts: PackedStringArray = _challenge.chip_texts()
	for i in kinds.size():
		if kinds[i] == FeatureTile.KIND_GOLD:
			return texts[i]
	return ""


## Bırakış bütçesi cipi "38 HAMLE" (tamamlanmadan) ya da boş.
func challenge_moves_text() -> String:
	var kinds: Array = _challenge.chip_kinds()
	var texts: PackedStringArray = _challenge.chip_texts()
	for i in kinds.size():
		if kinds[i] == FeatureTile.KIND_INFO:
			return texts[i]
	return ""


func is_challenge_done_shown() -> bool:
	return _challenge.chip_kinds().has(FeatureTile.KIND_MINT)


func challenge_portrait_texture() -> Texture2D:
	return _challenge.art_texture()


## GÖREVLER girişi (TASK/046; V3'te ikincil madalyon).
func missions_button() -> HomeFeatureButton:
	return _missions


func missions_count_text() -> String:
	return _missions.badge_text()


func missions_badge() -> PanelContainer:
	return _missions.badge_panel()


func chest_button() -> HomeFeatureButton:
	return _chest


## Ana Sayfa girişleri anahtarla (eski API): daily → GÜNLÜK karosu, missions / chest → madalyonlar. TASK/058'de
## KALDIRILAN `shop` / `collection` → null (kabuk sahibi).
func feature_button(key: StringName) -> Control:
	match key:
		&"daily":
			return _daily
		&"missions":
			return _missions
		&"chest":
			return _chest
	return null


func feature_keys() -> Array:
	return [&"daily", &"missions", &"chest"]


## TASK/062 Başlangıç Paketi yuvası (bugün boş + gizli).
func offer_slot() -> Control:
	return _offer_slot


func player_status() -> Control:
	return _status


func status_title_text() -> String:
	return _status_title.text


func status_level() -> int:
	return _status_badge.level()


## K9: oyuncu seviyesi rozetinin üst yazısı ("SV.").
func status_caption_text() -> String:
	return _status_badge.caption_text()


## Seviye içi XP oranı (0..1) — XP rayının dolgusu.
func status_ratio() -> float:
	return _status_ratio


func dough_pill() -> Control:
	return _dough_pill


func hero() -> Control:
	return _hero


func mascot_rect() -> Rect2:
	return Rect2(_hero.global_position + _mascot_home.position, _mascot_home.size)


func logo() -> TextureRect:
	return _logo


func is_daily_claimable() -> bool:
	return _daily_claimable
