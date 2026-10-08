extends CanvasLayer
## Harita V3 — kaydırılabilir candy yolculuk + MEYDAN portalı (TASK/059; M8.6-04 production haritasının EVRİMİ,
## GAME_DESIGN §5.5). İkinci bir harita sistemi DEĞİL: aynı owner zemini (`map_background.png`), aynı on düğüm yeri,
## aynı Catmull-Rom `MapTrail`, aynı `MapLevelNode` durumları, aynı açılış / giriş animasyonları ve aynı level başlatma
## yolu — değişen yalnız dünyanın ölçeği ve kamerası.
##
##   DÜNYA   zemin TEK TİP (yatay = dikey) ölçekle büyütülür: `WORLD_ZOOM` (1.3) ya da ekranı kaplayan cover ölçeği
##           (hangisi büyükse). Eski sığdırma yolundaki DİKEY SIKIŞTIRMA (sy/sx 0.82…0.94) YOK — yolculuk ekrana
##           sıkıştırılmaz, sabit kabuğun (üst satır + gezinme kabuğu + banner yuvası) ARKASINDA dikeyde kayar.
##           Zeminin üstünde cihaz üst güvenli payı kadar gök bandı (zeminin ilk 6 satırı, `flip_v`, A36 dikiş dersi);
##           kale gerekirse üst satırın altına inecek kadar bant uzar. Zemin ekranı her kaydırma konumunda kaplar
##           (boş bant / alttaki zemin rengi görünmez). Zeminin altında kabuğun arkasına bir "toprak bandı" (zeminin
##           son satırları, aynalı) — kabuk bir pencereyle gizlendiğinde (MEYDAN OKUMA açıkken) alt kenarda koyu şerit
##           kalmaz; banner yuvasına çizilmez.
##   KAMERA  `_scroll` ∈ [0, `_scroll_max`] — 0'da gök bandı ekranın tepesinde (kale + son level'lar), en altta zeminin alt
##           kenarı tepsinin üst kenarında (level 1 + OYNA plakası tepsi / merkez dairenin üstünde). Her GİRİŞTE (sekme
##           geçişi, oyundan dönüş) odak düğümüne (sıradaki level; her şey bitmişse Sonsuz) döner — ziyaret içinde
##           kaydırma korunur. Yeni açılan level'da kamera bir önceki düğümden yenisine kısa süzülür.
##   GİRDİ   kendi küçük jest sahibi (`World`, MOUSE_FILTER_STOP; düğümler / portal PASS): dikey 14 px eşik geçilince
##           sürükleme başlar → `NOTIFICATION_SCROLL_BEGIN` yayılır → BaseButton basışı iptal eder (sürükleme level
##           BAŞLATMAZ); bırakışta savurma (sönümlü, sınırda durur, taşma yok). İptal edilen bırakış (ACTION_CANCEL)
##           savurmaz. Savurma / kamera süzülmesi sürerken gelen dokunuş yalnız kamerayı DURDURUR (altındaki düğüm / portal
##           başlamaz — "yakalama"). Ekran gizlenince / pencere açılınca / sekme değişince / oyun başlayınca / GERİ'de /
##           odak kaybında jest iptal (`cancel_gesture`; Main `_sync_nav`'dan da çağırır). Düğüm basışlarının sahibi
##           TASK/055 GestureGuard (değişmedi). Üst satırın pill'leri dokunuşu TUTAR (altlarına kayan düğüme dokunuş geçmez).
##           Dinlenme konumunda (giriş odağı) kamera gerekirse birkaç piksel kayar ki hiçbir düğüm / plaka / portal üst
##           satırın pill'lerinin altında yarım kalmasın (`_focus_target`).
##   DÜĞÜM   `MapLevelNode` (tek bileşen, beş durum); perspektif çap 84 → 72 × düğüm ölçeği; en küçük düğüm ≥ 84
##           (TOUCH_TARGET). Dokunma alanı gövde + plaka ("OYNA" kelimesi de düğümündür).
##   SONSUZ  kalede; kilitliyken kilit + "BÖLÜM 10" (kural aynı: Level 10 tamamlanınca), açıkken taç + SONSUZ (+ rekor).
##   MEYDAN  sol pembe köprünün ucunda `MapChallengePortal` + pembe yan yol (`MapTrail` yan yol paleti) → `challenge_
##           requested` → Main'in MEVCUT MEYDAN OKUMA penceresi. Durum yalnız gerçek veri (`DailyChallenge.current_view`):
##           hedef dumpling + hazır "!" / tamam ✓. Gün gerçeği yoksa portal ve yan yol gizli (Ana Sayfa ile aynı).
##   ÜST     `ScreenTopBar` (Hamur pill'i + "+" → Mağaza) + solda yalnız-gösterim ⭐ toplam yıldız pill'i. TEXT-LIGHT
##           (UI_VISUAL_SYSTEM §29): "HARİTA" kurdelesi gizli — ekran kimliği kabuğun seçili HARİTA'sında. Geri oku YOK.
##
## Koordinatlar DOKU uzayında (720×1280 harita zemini); `_map_to_world` dünya-yerel koordinata (dünya = kayan `World`
## kontrolü) taşır. Level verisi, unlock kuralı (`SaveManager.highest_level_unlocked`), yıldızlar, Sonsuz şartı
## (`is_endless_unlocked`), level başlatma yolu (`level_chosen` → main._start_level) ve kayıt DEĞİŞMEDİ — Harita
## ilerleme / ekonomi kaydına YAZMAZ, kaydırma / gezinme hiçbir şey yazmaz. Tek olası yazma, portalın meydan okuma gün
## okumasının (`DailyChallenge.current_view` → TASK/047 monoton gün gözlemi, `last_seen_day_key`) yeni bir günü İLK kez
## görmesidir — Ana Sayfa MEYDAN karosunun okumasıyla birebir aynı (açılış zaten gözlediği için pratikte yazmaz).

signal level_chosen(level: LevelData)
signal shop_requested
## TASK/059: MEYDAN portalı → Main'in mevcut MEYDAN OKUMA penceresi (`Main.open_daily_challenge`).
signal challenge_requested

## Harita zemini doku boyutu (map_background.png).
const MAP_SIZE: Vector2 = Vector2(720.0, 1280.0)
## Level 1..10 düğüm merkezleri, doku uzayı: pembe kaldırım taşı yolun
## ÜSTÜNDE (M8.6-04: 2/4/5 kaldırımdan yola alındı, 8/9/10 aralığı ≥ 104 px
## açıldı). Alt geniş bölümde zig-zag, y≈740'ta sola kıvrım, y≈556'da sağa
## dönüş, tepede kapı kemeri (level 10). Dekoratif karakterlere binmiyor.
const NODE_POSITIONS: Array[Vector2] = [
	Vector2(420.0, 1120.0),
	Vector2(322.0, 1030.0),
	Vector2(440.0, 940.0),
	Vector2(332.0, 850.0),
	Vector2(322.0, 742.0),
	Vector2(398.0, 648.0),
	Vector2(468.0, 556.0),
	Vector2(408.0, 470.0),
	Vector2(480.0, 388.0),
	Vector2(440.0, 292.0),
]
## Sonsuz Mod: patikanın sonundaki kale.
const ENDLESS_POSITION: Vector2 = Vector2(445.0, 150.0)
## TASK/059 MEYDAN portalı: sol pembe köprünün sol ucu (doku uzayı) — zeminin kendi yan yolu; WORLD_ZOOM'un yatay
## kırpmasında (görünen doku x ≈ 83..637) ekranda, hiçbir level düğümüne binmez.
const PORTAL_POSITION: Vector2 = Vector2(176.0, 692.0)
## Yan yol: ana patikanın 5→6 kesiminin ORTASINDAN (Catmull-Rom t = 0.5 ≈ (355, 694); level düğümüne değil — portal
## ilerlemeye bağlı değil) köprü boyunca portala; ana patikadan kalın, sıcak pembe boncuklu.
const BRANCH_POINTS: Array[Vector2] = [
	Vector2(355.0, 694.0),
	Vector2(300.0, 701.0),
	Vector2(240.0, 708.0),
]
const BRANCH_LINE: Color = Color(1.0, 0.95, 0.98, 1.0)
const BRANCH_DOT: Color = Color(0.93, 0.30, 0.60, 1.0)
const BRANCH_SCALE: float = 1.35
## Perspektif: düğüm çapı en alttaki düğümde 1.0, en üsttekinde DEPTH_MIN.
const DEPTH_MIN: float = 0.86
## Sonsuz şartı — TASK/059 text-light: kilit ikonu + "BÖLÜM 10" (kural aynı; Ana Sayfa'nın "BÖLÜM" terimi).
const ENDLESS_REQUIREMENT: String = "BÖLÜM %d"
## Punch-hole bandı: zeminin en üst satırları (gök + bulut tepeleri) dikeyde
## gerilerek bandı doldurur; sahnede `flip_v` — bandın ALT kenarı doku satırı
## 0 olur ve zeminin ilk satırıyla birleşir (A36 cihaz kapısı: mirror'suz
## şeritte bulut kenarlarında ince yatay dikiş görünüyordu). Üstüne haze biner.
const SKY_STRIP_ROWS: int = 6
const HAZE_HEIGHT: float = 150.0
## TASK/059: dünyanın en küçük TEK TİP ölçeği (doku px → tuval px). Ölçüm (build/qa_059): 1.3'te yolculuk 16:9'da
## ~480 px, A36 benzeri + banner'da ~400 px, 720×1600'de ~160 px kayar; A36'da zemin fiziksel olarak 1.95× (bugünkü
## onaylı A36 haritası 1.83×) — bulanık mega büyütme değil; MEYDAN portalı her kaydırma konumunda ekranda.
const WORLD_ZOOM: float = 1.3
## Dünya ölçeği büyüdükçe düğümler de yarı oranda büyür; taban: en küçük (perspektifte en uzak) düğüm ≥ TOUCH_TARGET.
const NODE_WORLD_SCALE_SHARE: float = 0.5
## Atmosfer pırıltıları: doku uzayı konum, kutu, faz — odaktaki düğümün
## çevresinde değil, dünyada (şelale/balon çevresi); sessiz.
const SPARKLES: Array = [
	[Vector2(118.0, 470.0), 16.0, 0.0],
	[Vector2(612.0, 596.0), 13.0, 1.7],
	[Vector2(196.0, 258.0), 12.0, 3.1],
	[Vector2(548.0, 214.0), 14.0, 4.4],
	[Vector2(96.0, 1052.0), 12.0, 2.3],
	[Vector2(652.0, 1004.0), 11.0, 5.2],
]
const STAR_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
const SPARKLE_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_sparkle.png")
## Harita zemini (sahnedeki MapBackground dokusu).
const MAP_TEXTURE: Texture2D = preload("res://assets/visual/ui/map_background.png")

## Açılış animasyonu (M8.5-12): patika yanar → düğüm pop → parıltı. ~0.7 s.
const UNLOCK_POP_TIME: float = 0.32
const UNLOCK_TRAIL_TIME: float = 0.4
## TASK/059: açılışta kamera bir önceki düğümden yenisine süzülür.
const UNLOCK_GLIDE_TIME: float = 0.45
## Ekran girişi: düğüm katmanı 0.18 s'de belirir, odak düğümü küçük pop.
const ENTRY_TIME: float = 0.18

## Düğümlerin üst satır / kabukla arası (px).
const FIT_MARGIN: float = 12.0
## Kalenin kilit rozeti madalyonun üstüne çapın bu oranı kadar taşar (MapLevelNode: -0.08 d).
const ENDLESS_LOCK_RISE: float = 0.08
## Odak düğümünün görsel merkezi, düğümlere açık dikey bandın bu oranında (0 = üst satırın altı, 1 = kabuğun üstü):
## merkezin biraz altı — sıradaki birkaç düğüm üstte görünür.
const FOCUS_ANCHOR: float = 0.58
## Sürükleme eşiği (tuval px, dikey) — A36'da ~8 dp; altındaki titreşim dokunuştur (düğüm basışı sürer).
const DRAG_DEADZONE: float = 14.0
## Savurma (px/s): başlatma alt sınırı, tavan, üstel sönüm (1/s) ve durma hızı.
const FLING_MIN_SPEED: float = 80.0
const FLING_MAX_SPEED: float = 3200.0
const FLING_DECAY: float = 4.6
const FLING_STOP_SPEED: float = 16.0
## Bırakış hızı son bu kadar ms'deki harekettan ölçülür; parmak bu süredir duruyorsa savurma yok.
const VELOCITY_WINDOW_MSEC: int = 90
## Masaüstü fare tekerleği adımı.
const WHEEL_STEP: float = 90.0
## Bu hızın (px/s) üstündeki savurmayı durduran dokunuş "yakalama"dır: altındaki düğüm / portal başlamaz.
const FLING_CATCH_SPEED: float = 60.0
## Dinlenme konumu düzeltmesinin en çok kaydırması (px) ve üst satır pill'lerinin çevresindeki pay.
const FOCUS_NUDGE_MAX: float = 160.0
const PILL_CLEARANCE: float = 4.0

var _levels: Array[LevelData] = []
## Düğüm butonları, level sırasıyla (index 0 = level 1).
var _nodes: Array[MapLevelNode] = []
var _endless: MapLevelNode
var _focus: MapLevelNode
var _portal: MapChallengePortal
var _stars_pill: Control
var _sparkles: Array[TextureRect] = []
## Son tazelemede görülen en yüksek açık level. -1 = henüz görülmedi
## (ilk tazeleme animasyon oynatmaz). Kayda YAZILMIYOR — bellek içi.
var _last_unlocked: int = -1
var _time: float = 0.0
## Açılış animasyonu oynuyor: giriş pop'u ve nefes ölçeğe dokunmaz.
var _unlock_playing: bool = false
## Canlı tween'ler: tazeleme düğümleri yeniden kurduğunda öldürülür (serbest
## bırakılmış düğüme bağlı callback kalmasın).
var _entry_tween: Tween
var _unlock_tweens: Array[Tween] = []
var _scroll_tween: Tween
## Test kancası: cihaz üst güvenli payı (A36 punch-hole) masaüstünde
## okunamaz; negatif = gerçek değeri kullan.
var _safe_top_override: float = -1.0
## Test kancası: alt pay (banner yuvası + gesture bar); negatif = gerçek
## (`UiKit.bottom_inset`).
var _bottom_inset_override: float = -1.0
## Test / fizibilite kancası: dünya ölçeği tabanı; negatif = WORLD_ZOOM.
var _zoom_override: float = -1.0
## TASK/057: küresel gezinme kabuğunun alt payı (Main `set_nav_inset`; kabuksuz 0) ve bu payın dünyanın ALTINA
## girebilen kısmı (merkez dairenin tepsi üstüne taşması): zemin tepsinin üst kenarına kadar uzanır, düğümler payın
## TAMAMININ üstünde durabilir.
var _nav_inset: float = 0.0
var _nav_overlap: float = 0.0
## Dünya geometrisi (son yerleşim): tek tip ölçek, zeminin dünya içindeki sol kenarı, gök bandı yüksekliği, dünya
## yüksekliği, dünyanın göründüğü ekran altı (tepsi üstü), düğümlere açık bant [tavan, taban].
var _world_scale: float = 1.0
var _art_left: float = 0.0
var _sky_band: float = 0.0
var _world_height: float = MAP_SIZE.y
var _view_bottom: float = MAP_SIZE.y
var _node_ceiling: float = 0.0
var _node_floor: float = MAP_SIZE.y
## Kamera: dünyanın ekran üstüne göre kayması (px) ve sınırı.
var _scroll: float = 0.0
var _scroll_max: float = 0.0
## Jest durumu (yalnız sol işaretçi / öykünülen ilk parmak).
var _press_active: bool = false
var _dragging: bool = false
var _press_y: float = 0.0
var _press_scroll: float = 0.0
var _velocity: float = 0.0
var _samples: Array[Vector2] = []
## Girişten beri oyuncu kamerayı oynattı mı (oynatmadıysa yerleşim değişiminde — geç gelen banner yuvası — odak korunur).
var _user_moved: bool = false
## Ekran yeni görünür oldu: sıradaki `refresh` kamerayı odağa alır.
var _entry_pending: bool = false
## Test / inceleme sayaçları: başlayan sürükleme sayısı, savurma / süzülme yakalaması sayısı.
var drag_count: int = 0
var catch_count: int = 0

@onready var _root: Control = $Root
@onready var _clip: Control = $Root/WorldClip
@onready var _world: Control = $Root/WorldClip/World
@onready var _art: TextureRect = $Root/WorldClip/World/MapBackground
@onready var _sky: TextureRect = $Root/WorldClip/World/Sky
@onready var _ground: TextureRect = $Root/WorldClip/World/Ground
@onready var _haze: TextureRect = $Root/Haze
@onready var _vignette: TextureRect = $Root/Vignette
@onready var _map: Control = $Root/WorldClip/World/Map
@onready var _branch: MapTrail = $Root/WorldClip/World/Map/Branch
@onready var _trail: MapTrail = $Root/WorldClip/World/Map/Trail
@onready var _node_layer: Control = $Root/WorldClip/World/Map/Nodes
@onready var _portal_layer: Control = $Root/WorldClip/World/Map/Portal
@onready var _fx_layer: Control = $Root/WorldClip/World/Map/Fx
@onready var _bar: ScreenTopBar = $Root/TopBar


func _ready() -> void:
	_levels = LevelLibrary.load_levels()
	var strip := AtlasTexture.new()
	strip.atlas = MAP_TEXTURE
	strip.region = Rect2(0.0, 0.0, MAP_SIZE.x, float(SKY_STRIP_ROWS))
	_sky.texture = strip
	var ground := AtlasTexture.new()
	ground.atlas = MAP_TEXTURE
	ground.region = Rect2(0.0, MAP_SIZE.y - 1.0, MAP_SIZE.x, 1.0)
	_ground.texture = ground
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_haze.texture = _vertical_gradient(Color(0.96, 0.97, 1.0, 0.72), Color(0.96, 0.97, 1.0, 0.0))
	_vignette.texture = _radial_vignette()
	_bar.set_title("HARİTA")
	# TASK/059 text-light: kurdele gizli (ekran kimliği kabuğun seçili HARİTA'sında); satırda Hamur pill'i + ⭐ pill'i.
	_bar.set_title_visible(false)
	# TASK/055: üst çubuk (paylaşılan ScreenTopBar) Harita tarafında sahiplenilir — gezinme yalnız geçerli dokunuşla.
	# TASK/057 Tur 2: geri oku yok (Ana Sayfa'ya dönüş küresel gezinme kabuğunda + Android GERİ).
	GestureGuard.own(_bar.add_button())
	_bar.add_pressed.connect(func() -> void:
		if GestureGuard.allows(_bar.add_button()):
			shop_requested.emit())
	# Toplam yıldız (yalnız gösterim, dokunma almaz — kaydırma üstünden de başlar): ⭐ + "N/30".
	_stars_pill = UiKit.home_pill(STAR_ART, "0/0", false, ScreenTopBar.ROW_HEIGHT)
	_stars_pill.name = "StarsPill"
	# Sabit üst satır: pill'ler dokunuşu tutar — altlarına kayan düğüme / portala dokunuş geçmez (Hamur "+" kendi butonu).
	_stars_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar.pill().mouse_filter = Control.MOUSE_FILTER_STOP
	# ...ama pill'in üstünden başlayan sürükleme dünyayı yine kaydırır (aynı jest sahibi; dokunuş düğüme geçmez).
	_stars_pill.gui_input.connect(_on_world_input)
	_bar.pill().gui_input.connect(_on_world_input)
	_root.add_child(_stars_pill)
	_stars_pill.minimum_size_changed.connect(_place_stars_pill)
	_branch.set_branch_palette(BRANCH_LINE, BRANCH_DOT, BRANCH_SCALE)
	_portal = MapChallengePortal.new()
	GestureGuard.on_pressed(_portal, _on_portal_pressed)
	_portal_layer.add_child(_portal)
	for spec in SPARKLES:
		var spark := UiKit.art(STAR_ART, float(spec[1]))
		_fx_layer.add_child(spark)
		_sparkles.append(spark)
	_world.gui_input.connect(_on_world_input)
	_root.resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		set_process(visible)
		cancel_gesture()
		if not visible:
			# Gizlenen haritanın açılış animasyonu (ses dahil) oyunun / pencerenin üstünde sürmez.
			_kill_animations()
		if visible:
			_entry_pending = true
			_user_moved = false
			_layout()
			_focus_camera()
			# main._show_tab görünürlükten SONRA refresh() çağırır: giriş
			# animasyonu yeni düğümleri görsün diye ertelenir.
			_play_entry.call_deferred())
	set_process(visible)
	refresh()


# --- Doku uzayı -> dünya ---

## Doku noktası → dünya-yerel nokta (`World` kontrolünün uzayı; ekran y = dünya y − `_scroll`).
func _map_to_world(map_point: Vector2) -> Vector2:
	return Vector2(_art_left + map_point.x * _world_scale, _sky_band + map_point.y * _world_scale)


## Doku noktası → ekran noktası (şu anki kamerayla) — testler / inceleme.
func _map_to_screen(map_point: Vector2) -> Vector2:
	return _map_to_world(map_point) - Vector2(0.0, _scroll)


func _safe_top() -> float:
	if _safe_top_override >= 0.0:
		return _safe_top_override
	return UiKit.safe_top(_root.size)


func _bottom_inset() -> float:
	if _bottom_inset_override >= 0.0:
		return _bottom_inset_override
	return UiKit.bottom_inset(_root.size)


func _zoom_floor() -> float:
	return _zoom_override if _zoom_override > 0.0 else WORLD_ZOOM


func _layout() -> void:
	if _root == null or _bar == null:
		return
	var view: Vector2 = _root.size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var safe_top: float = _safe_top()
	_bar.layout(view.x, safe_top)
	_bar.set_title_visible(false)
	_place_stars_pill()
	# Dünyanın göründüğü bant: ekran üstünden kabuk tepsisinin üst kenarına (kabuksuz: banner yuvasının üstüne).
	_view_bottom = maxf(view.y - _bottom_inset() - maxf(_nav_inset - _nav_overlap, 0.0), 1.0)
	_node_floor = _view_bottom - minf(_nav_overlap, _nav_inset) - FIT_MARGIN
	_node_ceiling = _bar.height() + FIT_MARGIN
	_fit_world(view, safe_top)
	# Kırpma: banner yuvasının üstüne kadar (kabuk tepsisi ve dock dünyanın üstüne çizilir).
	var clip_bottom: float = maxf(view.y - _bottom_inset(), _view_bottom)
	_clip.position = Vector2.ZERO
	_clip.size = Vector2(view.x, clip_bottom)
	_world.size = Vector2(view.x, _world_height)
	_art.texture = MAP_TEXTURE
	_art.position = Vector2(_art_left, _sky_band)
	_art.size = MAP_SIZE * _world_scale
	# Gök bandı: zeminin GÖRÜNEN yatay aralığının en üst satırları (bulutlar dikişte hizalı kalsın).
	_sky.position = Vector2.ZERO
	_sky.size = Vector2(view.x, _sky_band + 2.0)
	var strip: AtlasTexture = _sky.texture as AtlasTexture
	if strip != null:
		strip.region = Rect2(-_art_left / _world_scale, 0.0, view.x / _world_scale, float(SKY_STRIP_ROWS))
	# Toprak bandı: en alt kamera konumunda zeminin altı ile kırpmanın altı arası (kabuğun arkası); zeminin son satırları
	# aynalı — dikiş zeminin son satırında birleşir.
	var ground_h: float = clip_bottom - _view_bottom + 2.0
	var ground_rows: float = clampf(ground_h / _world_scale, 1.0, MAP_SIZE.y * 0.25)
	_ground.position = Vector2(_art_left, _world_height - 1.0)
	_ground.size = Vector2(MAP_SIZE.x * _world_scale, ground_h)
	var ground_tex: AtlasTexture = _ground.texture as AtlasTexture
	if ground_tex != null:
		ground_tex.region = Rect2(0.0, MAP_SIZE.y - ground_rows, MAP_SIZE.x, ground_rows)
	_haze.position = Vector2.ZERO
	_haze.size = Vector2(view.x, safe_top + HAZE_HEIGHT)
	_vignette.position = Vector2.ZERO
	_vignette.size = view

	var trail_points := PackedVector2Array()
	var radii := PackedFloat32Array()
	for i in _nodes.size():
		var node: MapLevelNode = _nodes[i]
		var center: Vector2 = _map_to_world(NODE_POSITIONS[i])
		var d: float = _node_diameter(i, node.state() == MapLevelNode.State.CURRENT)
		node.set_diameter(d)
		node.position = center - Vector2(d, d) * 0.5
		trail_points.append(center)
		radii.append(d * 0.5)
	if _endless != null:
		var center: Vector2 = _map_to_world(ENDLESS_POSITION)
		_endless.set_diameter(MapLevelNode.ENDLESS_DIAMETER * _node_world_scale())
		var d: float = _endless.diameter()
		_endless.position = center - Vector2(d, d) * 0.5
		trail_points.append(center)
		radii.append(d * 0.5)
	_trail.set_trail(trail_points, _done_segments(), _trail.lit, radii)
	_layout_portal()
	for i in _sparkles.size():
		var spec: Array = SPARKLES[i]
		var box: float = float(spec[1])
		var at: Vector2 = _map_to_world(spec[0] as Vector2)
		_sparkles[i].position = at - Vector2(box, box) * 0.5
		_sparkles[i].size = Vector2(box, box)
		_sparkles[i].pivot_offset = Vector2(box, box) * 0.5
	# Oyuncu bu girişte kamerayı oynatmadıysa (ör. banner yuvası girişten sonra geldi) odak korunur; oynattıysa konum
	# yalnız yeni sınırlara kırpılır.
	if not _user_moved and not _scroll_running():
		_focus_camera()
	else:
		_set_scroll(_scroll)


## Dünya ölçeği + gök bandı + kaydırma sınırı. Ölçek TEK TİP: max(WORLD_ZOOM, ekran genişliği / 720, görünen bant /
## 1280); level 1'in OYNA plakası en alt konumda kabuğun üstüne çıkamıyorsa (yalnız aşırı oranlarda) ölçek biraz büyür.
## Gök bandı = üst güvenli pay; kale en üst konumda üst satırın altında kalacak kadar uzar.
func _fit_world(view: Vector2, safe_top: float) -> void:
	var s: float = maxf(maxf(_zoom_floor(), view.x / MAP_SIZE.x), (_view_bottom - safe_top) / MAP_SIZE.y)
	_world_scale = s
	var bottom_extent: float = MapLevelNode.LEVEL_DIAMETER * MapLevelNode.CURRENT_SCALE * _node_world_scale() * 0.5 \
		+ MapLevelNode.LIP - MapLevelNode.PLAQUE_OVERLAP + MapLevelNode.PLAQUE_HEIGHT + 2.0
	var bottom_need: float = bottom_extent + (_view_bottom - _node_floor)
	var below_first: float = MAP_SIZE.y - NODE_POSITIONS[0].y
	if below_first * s < bottom_need:
		s = bottom_need / below_first
		_world_scale = s
	_art_left = (view.x - MAP_SIZE.x * s) * 0.5
	var ns: float = _node_world_scale()
	var castle_rise: float = MapLevelNode.ENDLESS_DIAMETER * ns * (0.5 + ENDLESS_LOCK_RISE)
	var castle_top: float = ENDLESS_POSITION.y * s - castle_rise
	_sky_band = maxf(safe_top, _node_ceiling - castle_top)
	_world_height = _sky_band + MAP_SIZE.y * s
	_scroll_max = maxf(_world_height - _view_bottom, 0.0)


## Perspektif çapı: doku y'sine göre 84 → 72 (× düğüm ölçeği); sıradaki ×1.14.
func _node_diameter(index: int, current: bool) -> float:
	var y: float = NODE_POSITIONS[index].y
	var t: float = clampf((y - NODE_POSITIONS[NODE_POSITIONS.size() - 1].y)
		/ maxf(NODE_POSITIONS[0].y - NODE_POSITIONS[NODE_POSITIONS.size() - 1].y, 1.0), 0.0, 1.0)
	var d: float = MapLevelNode.LEVEL_DIAMETER * lerpf(DEPTH_MIN, 1.0, t) * _node_world_scale()
	if current:
		d *= MapLevelNode.CURRENT_SCALE
	return d


## Düğüm ölçeği: dünya ölçeğinin yarısı kadar büyür; en uzak (en küçük) düğüm TOUCH_TARGET'in altına inmez.
func _node_world_scale() -> float:
	var grow: float = 1.0 + maxf(_world_scale - 1.0, 0.0) * NODE_WORLD_SCALE_SHARE
	return maxf(grow, float(UiTokens.TOUCH_TARGET) / (MapLevelNode.LEVEL_DIAMETER * DEPTH_MIN))


## Tamamlanmış segment sayısı: level k tamamlandıysa k→k+1 segmenti sıcak.
## highest_level_unlocked = H demek 1..H-1 tamamlandı → H-1 segment.
func _done_segments() -> int:
	return clampi(SaveManager.highest_level_unlocked() - 1, 0, NODE_POSITIONS.size())


## MEYDAN portalı + yan yol (dünya-yerel). Portal gizliyse yan yol da gizli.
func _layout_portal() -> void:
	_branch.visible = _portal.visible
	if not _portal.visible:
		return
	_portal.set_well_diameter(MapChallengePortal.WELL_DIAMETER * _node_world_scale())
	var center: Vector2 = _map_to_world(PORTAL_POSITION)
	_portal.position = center - _portal.well_center()
	var points := PackedVector2Array()
	var radii := PackedFloat32Array()
	for p in BRANCH_POINTS:
		points.append(_map_to_world(p))
		radii.append(-10.0)
	points.append(center)
	radii.append(_portal.well_diameter() * 0.5)
	_branch.set_trail(points, points.size() - 1, 0.0, radii)


func _place_stars_pill() -> void:
	if _stars_pill == null or _bar == null:
		return
	_stars_pill.position = Vector2(ScreenTopBar.SIDE_MARGIN,
		_bar.height() - ScreenTopBar.ROW_HEIGHT + (ScreenTopBar.ROW_HEIGHT - _stars_pill.size.y) * 0.5)


# --- Tazeleme ---

func refresh() -> void:
	cancel_gesture()
	_kill_animations()
	for child in _node_layer.get_children():
		child.queue_free()
	_nodes.clear()
	_endless = null
	_focus = null

	var highest: int = SaveManager.highest_level_unlocked()
	var newly_unlocked: int = -1
	if _last_unlocked > 0 and highest > _last_unlocked:
		newly_unlocked = highest
	_last_unlocked = highest

	for level in _levels:
		var state: MapLevelNode.State = _state_for(level.level_number, highest)
		var node := MapLevelNode.new()
		node.setup_level(level.level_number, state, SaveManager.stars_for_level(level.level_number))
		GestureGuard.on_pressed(node, _on_node_pressed.bind(node, level))
		_node_layer.add_child(node)
		_nodes.append(node)
		if state == MapLevelNode.State.CURRENT and level.level_number == highest:
			_focus = node

	var endless_open: bool = SaveManager.is_endless_unlocked(_levels.size())
	_endless = MapLevelNode.new()
	_endless.setup_endless(endless_open, SaveManager.endless_high_score(),
		ENDLESS_REQUIREMENT % _levels.size())
	GestureGuard.on_pressed(_endless, _on_endless_pressed)
	_node_layer.add_child(_endless)
	# Her şey bitmişse yolculuğun hedefi Sonsuz: hale oraya.
	if _focus == null and endless_open:
		_focus = _endless
	if _focus != null:
		_focus.set_focused(true)

	_bar.set_value(str(SaveManager.dough()), false)
	_refresh_stars()
	refresh_challenge(false)
	_trail.lit = 0.0
	var entry: bool = _entry_pending
	_entry_pending = false
	if entry or newly_unlocked > 0:
		_user_moved = false
	_layout()
	if entry or newly_unlocked > 0:
		_focus_camera()

	if newly_unlocked > 0:
		_play_unlock(newly_unlocked)


## MEYDAN portalı: bugünün meydan okuması (DailyChallenge.current_view — Ana Sayfa karosuyla AYNI okuma; YAZMAZ —
## yalnız gün gözlemi, TASK/047 monoton gün). Onboarding bitmeden / gün gerçeği yokken gizli. Main öne dönüşte ve
## pencerenin gün tazelemesinde de çağırır.
func refresh_challenge(relayout: bool = true) -> void:
	if _portal == null:
		return
	var view: Dictionary = DailyChallenge.current_view() if Onboarding.is_completed() else {}
	var was_visible: bool = _portal.visible
	_portal.visible = not view.is_empty()
	if not view.is_empty():
		_portal.setup(int(view["target_tier"]), bool(view["completed"]))
	if relayout and was_visible != _portal.visible:
		_layout()


func _refresh_stars() -> void:
	var total: int = 0
	for level in _levels:
		total += SaveManager.stars_for_level(level.level_number)
	UiKit.set_pill_value(_stars_pill, "%d/%d" % [total, _levels.size() * 3], false)


func _state_for(level_number: int, highest: int) -> MapLevelNode.State:
	if level_number > highest:
		return MapLevelNode.State.LOCKED
	if SaveManager.stars_for_level(level_number) > 0:
		return MapLevelNode.State.COMPLETED
	return MapLevelNode.State.CURRENT


# --- Etkileşim ---

## Açık düğüm → level (kanonik `level_chosen`, main._start_level). Kilitli →
## yalnız geri bildirim; level başlamaz.
func _on_node_pressed(node: MapLevelNode, level: LevelData) -> void:
	if node.is_locked():
		node.reject()
		return
	level_chosen.emit(level)


func _on_endless_pressed() -> void:
	if _endless.is_locked():
		_endless.reject()
		return
	var endless := LevelLibrary.load_endless()
	if endless != null:
		level_chosen.emit(endless)


## MEYDAN portalı (GestureGuard'dan geçmiş geçerli dokunuş) → Main'in mevcut penceresi.
func _on_portal_pressed() -> void:
	if _portal.visible:
		challenge_requested.emit()


# --- Kamera ve jest ---

## Dünyanın sürüklenmesi: sol işaretçi (dokunuştan öykünülen ilk parmak) basışı düğümde / portalda (PASS) ya da boş
## dünyada başlar; olay buraya yayılır. Dikey eşik geçilince sürükleme: NOTIFICATION_SCROLL_BEGIN → BaseButton basışı
## iptal (bırakışta level başlamaz). İptal edilen bırakış savurmaz.
func _on_world_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_begin_press(button.global_position.y)
			else:
				_end_press(button.canceled)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_nudge(-WHEEL_STEP)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_nudge(WHEEL_STEP)
		return
	var motion := event as InputEventMouseMotion
	if motion == null or not _press_active:
		return
	if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		# Bırakışı görülmemiş basış (odak başka yere geçti): jest kapanır, eylem yok.
		_end_press(true)
		return
	_drag_to(motion.global_position.y)


func _begin_press(y: float) -> void:
	# Savurma / kamera süzülmesi sürerken gelen dokunuş kamerayı yakalar: dünya parmağın altında kayarken başlamış bu basış
	# bir düğümü / portalı ETKİNLEŞTİRMEZ (basış hemen iptal; parmak hareket ederse eşiksiz sürükleme sürer).
	var catching: bool = absf(_velocity) > FLING_CATCH_SPEED or _scroll_running()
	_kill_scroll_tween()
	_velocity = 0.0
	_press_active = true
	_dragging = false
	_press_y = y
	_press_scroll = _scroll
	_samples.clear()
	_samples.append(Vector2(_now(), y))
	if catching:
		_dragging = true
		_user_moved = true
		catch_count += 1
		_world.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)


func _drag_to(y: float) -> void:
	if not _dragging:
		if absf(y - _press_y) <= DRAG_DEADZONE:
			return
		_dragging = true
		_user_moved = true
		drag_count += 1
		# Eşik mesafesi atlanır (kamera parmağın ardından zıplamaz); basılı düğüm / portal basışı eylemsiz biter.
		_press_y = y
		_press_scroll = _scroll
		_world.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	var desired: float = _press_scroll - (y - _press_y)
	_set_scroll(desired)
	if not is_equal_approx(desired, _scroll):
		# Sınırda: parmak geri dönünce kamera hemen izlesin (sınırın ötesindeki "ölü" parmak yolu birikmez).
		_press_y = y
		_press_scroll = _scroll
	var now: float = _now()
	_samples.append(Vector2(now, y))
	while _samples.size() > 2 and now - _samples[0].x > float(VELOCITY_WINDOW_MSEC) / 1000.0:
		_samples.remove_at(0)


func _end_press(canceled: bool) -> void:
	var was_dragging: bool = _dragging
	_press_active = false
	_dragging = false
	if not was_dragging or canceled or _samples.size() < 2:
		_samples.clear()
		return
	var first: Vector2 = _samples[0]
	var last: Vector2 = _samples[_samples.size() - 1]
	_samples.clear()
	var dt: float = last.x - first.x
	if dt <= 0.0 or _now() - last.x > float(VELOCITY_WINDOW_MSEC) / 1000.0:
		return
	var speed: float = -(last.y - first.y) / dt
	if absf(speed) >= FLING_MIN_SPEED:
		_velocity = clampf(speed, -FLING_MAX_SPEED, FLING_MAX_SPEED)


func _nudge(amount: float) -> void:
	if _press_active:
		return
	_kill_scroll_tween()
	_velocity = 0.0
	_user_moved = true
	_set_scroll(_scroll + amount)


## Etkin jesti eylemsiz bitirir: sürükleme / savurma / kamera süzülmesi durur, basılı düğüm / portal basışı eylemsiz
## biter (GestureGuard). Ekran gizlenince, tazelemede, GERİ'de, odak kaybında ve Main'in kabuk senkronunda (pencere
## açık / başka sekme / oyun) çağrılır.
func cancel_gesture() -> void:
	_press_active = false
	_dragging = false
	_velocity = 0.0
	_samples.clear()
	_kill_scroll_tween()
	for node in _nodes:
		if is_instance_valid(node):
			GestureGuard.invalidate(node)
	if _endless != null and is_instance_valid(_endless):
		GestureGuard.invalidate(_endless)
	if _portal != null:
		GestureGuard.invalidate(_portal)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		cancel_gesture()


func _set_scroll(value: float) -> void:
	_scroll = clampf(value, 0.0, _scroll_max)
	if _world != null:
		_world.position = Vector2(0.0, -_scroll)


## Kontrolün (düğüm / portal) görsel merkezini düğümlere açık bandın FOCUS_ANCHOR noktasına getiren kamera konumu.
func _scroll_for(target: Control) -> float:
	if target == null or not is_instance_valid(target):
		return _scroll
	# Ölçeksiz yerleşim dikdörtgeni (dünya-yerel): nefes / pop ölçeği kamera konumunu oynatmaz. Portalın buton
	# dikdörtgeni yıldız halkası + plakadır.
	var rect: Rect2 = Rect2(target.position, target.size)
	if target is MapLevelNode:
		rect = (target as MapLevelNode).layout_rect()
	var anchor: float = _node_ceiling + (_node_floor - _node_ceiling) * FOCUS_ANCHOR
	return clampf(rect.get_center().y - anchor, 0.0, _scroll_max)


## Kamera odak düğümüne (sıradaki level; her şey bitmişse Sonsuz) — anında.
func _focus_camera() -> void:
	var target: Control = _focus
	if target == null and not _nodes.is_empty():
		target = _nodes[0]
	if target != null:
		_set_scroll(_focus_target(target))


## Dinlenme konumu: odak düğümü bandın FOCUS_ANCHOR noktasında; bu konumda bir düğüm / plaka / kilit rozeti / portal üst
## satırın pill'leriyle kesişiyorsa kamera en yakın ±FOCUS_NUDGE_MAX içinde kesişmeyen konuma kayar (odak düğümü ve portal
## açık bantta kalır). Mümkün değilse (dünyanın ucu) anchor konumu kalır — kayan içerik zaten pill'lerin arkasındadır.
func _focus_target(target: Control) -> float:
	var base: float = _scroll_for(target)
	if _rest_clear(base, target):
		return base
	var offset: float = 2.0
	while offset <= FOCUS_NUDGE_MAX:
		for c: float in [base - offset, base + offset]:
			if c >= 0.0 and c <= _scroll_max and _rest_clear(c, target):
				return c
		offset += 2.0
	return base


func _rest_clear(c: float, focus: Control) -> bool:
	var focus_rect: Rect2 = _layout_rect(focus)
	focus_rect.position.y -= c
	if focus_rect.position.y < _node_ceiling or focus_rect.end.y > _node_floor:
		return false
	var pills: Array[Rect2] = [_bar.pill().get_global_rect().grow(PILL_CLEARANCE),
		_stars_pill.get_global_rect().grow(PILL_CLEARANCE)]
	var targets: Array[Control] = []
	targets.append_array(_nodes)
	if _endless != null:
		targets.append(_endless)
	if _portal.visible:
		targets.append(_portal)
		var portal_rect: Rect2 = _layout_rect(_portal)
		portal_rect.position.y -= c
		if portal_rect.position.y < _bar.height() or portal_rect.end.y > _node_floor + FIT_MARGIN:
			return false
	for t in targets:
		var rect: Rect2 = _layout_rect(t)
		rect.position.y -= c
		for pill in pills:
			if rect.intersects(pill):
				return false
	return true


## Ölçeksiz yerleşim dikdörtgeni (dünya-yerel): düğümde gövde + plaka + üstte kilit rozeti payı; portalda buton.
func _layout_rect(target: Control) -> Rect2:
	if target is MapLevelNode:
		var node := target as MapLevelNode
		var rect: Rect2 = node.layout_rect()
		var rise: float = node.diameter() * ENDLESS_LOCK_RISE
		rect.position.y -= rise
		rect.size.y += rise
		return rect
	return Rect2(target.position, target.size)


func _scroll_running() -> bool:
	return _scroll_tween != null and _scroll_tween.is_valid() and _scroll_tween.is_running()


func _kill_scroll_tween() -> void:
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	_scroll_tween = null


func _now() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0


# --- Hareket ---

func _kill_animations() -> void:
	if _entry_tween != null and _entry_tween.is_valid():
		_entry_tween.kill()
	for tween in _unlock_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_unlock_tweens.clear()
	_unlock_playing = false
	_node_layer.modulate.a = 1.0
	_portal_layer.modulate.a = 1.0

## Ekran girişi (sekme geçişinin üstüne): düğüm katmanı (+ portal) kısa solmayla
## gelir, odak düğümü küçük pop. Düğüm konumları oynamaz.
func _play_entry() -> void:
	if not is_inside_tree():
		return
	if _entry_tween != null and _entry_tween.is_valid():
		_entry_tween.kill()
	_node_layer.modulate.a = 0.0
	_portal_layer.modulate.a = 0.0
	_entry_tween = create_tween()
	_entry_tween.set_parallel(true)
	_entry_tween.tween_property(_node_layer, "modulate:a", 1.0, ENTRY_TIME)
	_entry_tween.tween_property(_portal_layer, "modulate:a", 1.0, ENTRY_TIME)
	_entry_tween.chain()
	if _focus != null and not _unlock_playing:
		_entry_tween.tween_callback(UiMotion.pop.bind(_focus, 1.06))


## Atmosfer pırıltıları sönümlenir (sinüs, RNG yok) + savurma. Düğümlerin kendi
## nefesi MapLevelNode içinde.
func _process(delta: float) -> void:
	_time += delta
	for i in _sparkles.size():
		var spec: Array = SPARKLES[i]
		var twinkle: float = 0.35 + 0.5 * (0.5 + 0.5 * sin(TAU * _time / 2.3 + float(spec[2])))
		_sparkles[i].modulate.a = twinkle
		_sparkles[i].scale = Vector2.ONE * (0.8 + 0.3 * twinkle)
	if _velocity != 0.0 and not _press_active:
		var before: float = _scroll
		_set_scroll(_scroll + _velocity * delta)
		_velocity *= exp(-FLING_DECAY * delta)
		if absf(_velocity) < FLING_STOP_SPEED or is_equal_approx(before, _scroll):
			_velocity = 0.0


## Level `level_number` ilk kez açıldı: kamera bir önceki düğümden yenisine süzülür, patikanın son segmenti yanar,
## düğüm pop'lar, birkaç parıltı, `level_unlock`. ~0.7 s, kesilebilir (dokunuş süzülmeyi durdurur); kayıt değişmez.
func _play_unlock(level_number: int) -> void:
	var index: int = level_number - 1
	var done: int = _done_segments()
	_trail.set_done(maxi(done - 1, 0))
	_trail.lit = 0.0
	var trail_tween := create_tween()
	_unlock_tweens.append(trail_tween)
	trail_tween.tween_property(_trail, "lit", 1.0, UNLOCK_TRAIL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	trail_tween.tween_callback(func() -> void:
		_trail.set_done(done)
		_trail.lit = 0.0)
	var target: Control = null
	if index < _nodes.size():
		target = _nodes[index]
	elif _endless != null:
		target = _endless
	if target == null:
		return
	var previous: Control = _nodes[index - 1] if index - 1 >= 0 and index - 1 < _nodes.size() else null
	if previous != null:
		var to: float = _focus_target(target)
		_set_scroll(_scroll_for(previous))
		_kill_scroll_tween()
		_scroll_tween = create_tween()
		_scroll_tween.tween_method(_set_scroll, _scroll, to, UNLOCK_GLIDE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_unlock_playing = true
	if target is MapLevelNode:
		(target as MapLevelNode).hold_breath = true
	target.scale = Vector2(0.4, 0.4)
	var pop := create_tween()
	_unlock_tweens.append(pop)
	pop.tween_interval(UNLOCK_TRAIL_TIME * 0.6)
	pop.tween_property(target, "scale", Vector2(1.15, 1.15), UNLOCK_POP_TIME * 0.55) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(target, "scale", Vector2.ONE, UNLOCK_POP_TIME * 0.45)
	pop.tween_callback(_spawn_unlock_sparkles.bind(target))
	pop.tween_callback(AudioManager.play.bind(&"level_unlock"))
	pop.tween_callback(func() -> void:
		_unlock_playing = false
		if is_instance_valid(target) and target is MapLevelNode:
			(target as MapLevelNode).hold_breath = false)


func _spawn_unlock_sparkles(target: Control) -> void:
	if not is_instance_valid(target):
		return
	var fx := CPUParticles2D.new()
	fx.texture = SPARKLE_TEXTURE
	fx.position = target.position + target.size * 0.5
	fx.one_shot = true
	fx.explosiveness = 1.0
	fx.amount = 12
	fx.lifetime = 0.55
	fx.direction = Vector2.UP
	fx.spread = 180.0
	fx.gravity = Vector2(0.0, 220.0)
	fx.initial_velocity_min = 90.0
	fx.initial_velocity_max = 190.0
	fx.scale_amount_min = 0.14
	fx.scale_amount_max = 0.3
	fx.color = Color(1.0, 0.92, 0.6, 0.95)
	_node_layer.add_child(fx)
	fx.emitting = true
	get_tree().create_timer(fx.lifetime + 0.2).timeout.connect(fx.queue_free)


# --- Dokular (programatik, asset yok) ---

static func _vertical_gradient(top: Color, bottom: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([top, Color(top, top.a * 0.45), bottom])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 8
	tex.height = 128
	return tex


## Yumuşak erik vignette: merkez temiz, kenarlar hafif koyu — dünya
## karartılmaz, yalnız kenar çerçevelenir (eski tam ekran α .40 karartma yok).
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


# --- Testler / çekim aracı ---

func _layout_with_safe_top(safe_top: float) -> void:
	_safe_top_override = safe_top
	_layout()


## TASK/057: küresel gezinme kabuğunun alt payı (tuval px) ve dünyanın altına girebilen kısmı (merkez
## daire taşması). Düğümler en alt kamera konumunda kabuğun üstünde kalır.
func set_nav_inset(px: float, overlap: float = 0.0) -> void:
	_nav_inset = maxf(px, 0.0)
	_nav_overlap = clampf(overlap, 0.0, _nav_inset)
	_layout()


## Düğümlerin durabileceği alt çizgi (ekran y): dünya altı − kabuk taşması − kenar payı.
func node_floor() -> float:
	return _node_floor


## Düğümlerin durabileceği üst çizgi (ekran y): üst satırın altı + kenar payı.
func node_ceiling() -> float:
	return _node_ceiling


## Başlık kurdelesi gizli mi (TASK/059: text-light — her zaman gizli; eski çağıranlar için).
func title_yielded() -> bool:
	return not _bar.is_title_visible()


## Test/çekim kancası: alt pay (banner yuvası) da verilir.
func _layout_with_insets(safe_top: float, bottom_inset: float) -> void:
	_safe_top_override = safe_top
	_bottom_inset_override = bottom_inset
	_layout()


## Test / fizibilite kancası: dünya ölçeği tabanı (negatif = WORLD_ZOOM).
func set_world_zoom_override(zoom: float) -> void:
	_zoom_override = zoom
	_layout()


## Dünya ölçeği (TASK/059: TEK TİP — x == y, dikey sıkıştırma yok).
func world_scale() -> Vector2:
	return Vector2(_world_scale, _world_scale)


## Ekranın tepesindeki doku satırı (şu anki kamerayla; gök bandında negatif).
func crop_top() -> float:
	return (_scroll - _sky_band) / _world_scale


## Dünyanın göründüğü ekran bandı: ekran üstünden kabuk tepsisinin üst kenarına.
func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(_root.size.x, _view_bottom))


## Dünyanın tam yüksekliği (gök bandı + zemin) ve gök bandı.
func world_height() -> float:
	return _world_height


func sky_band() -> float:
	return _sky_band


func scroll_offset() -> float:
	return _scroll


func scroll_limits() -> Vector2:
	return Vector2(0.0, _scroll_max)


## Kamerayı anında konumlar (sınırlara kırpılır) — testler / çekim aracı.
func set_scroll(value: float) -> void:
	_kill_scroll_tween()
	_velocity = 0.0
	_set_scroll(value)


## Odak düğümünün dinlenme kamera konumu (sınırlara kırpılmış, üst satır pill düzeltmesi dahil).
func focus_scroll() -> float:
	var target: Control = _focus if _focus != null else (_nodes[0] if not _nodes.is_empty() else null)
	return _focus_target(target) if target != null else _scroll


## Kameranın `value` konumunda düğüm / portal üst satır pill'leriyle kesişmiyor mu (odak açık bantta) — testler.
func rest_clear_at(value: float) -> bool:
	var target: Control = _focus if _focus != null else (_nodes[0] if not _nodes.is_empty() else null)
	return target != null and _rest_clear(value, target)


## Herhangi bir düğümün / portalın kamera konumu.
func scroll_for(target: Control) -> float:
	return _scroll_for(target)


func is_dragging() -> bool:
	return _dragging


func is_flinging() -> bool:
	return _velocity != 0.0


func is_gesture_active() -> bool:
	return _press_active


func nodes() -> Array[MapLevelNode]:
	return _nodes


func endless_node() -> MapLevelNode:
	return _endless


func focus_node() -> MapLevelNode:
	return _focus


func challenge_portal() -> MapChallengePortal:
	return _portal


func branch_trail() -> MapTrail:
	return _branch


func stars_pill() -> Control:
	return _stars_pill


func stars_text() -> String:
	return (_stars_pill.get_meta(&"value_label") as Label).text


func top_bar() -> ScreenTopBar:
	return _bar


func trail() -> MapTrail:
	return _trail


func world_layer() -> Control:
	return _world


func map_art() -> TextureRect:
	return _art
