extends CanvasLayer
## Harita — production yolculuk ekranı (M8.6-04; GAME_DESIGN §5.5).
##
## Home'daki büyük OYNA'nın ilk durağı: owner'ın candy dünyası KAHRAMAN,
## üstünde aşağıdan yukarı on level düğümü + kaledeki Sonsuz Mod madalyonu,
## aralarında candy patika (MapTrail). Dashboard/kart/grid DEĞİL.
##
##   ÜST     `ScreenTopBar`: geri (→ Ana Sayfa) · pembe "HARİTA" kurdelesi ·
##           Hamur pill'i + nane "+" (→ Mağaza). Home ile aynı satır geometrisi.
##   DÜNYA   `map_background.png` KEEP_ASPECT_COVERED — cihaz üst güvenli payı
##           (punch-hole) kadar aşağıdan başlar, üstteki bant gök rengi + haze;
##           kenarlarda yumuşak erik vignette; eski tam ekran karartma YOK.
##   DÜĞÜM   `MapLevelNode` (tek bileşen, beş durum). Perspektif: altta 84 px,
##           kalede 72 px; sıradaki ×1.14 + altın halka + nefes alan hale +
##           "OYNA" plakası. Kilitli dokunuş: kilit sallanır, level başlamaz.
##   SONSUZ  kalede 116 px altın madalyon (taç + SONSUZ); kilitliyse lavanta +
##           "Level 10'u bitir". Her şey bitmişse odak (hale) Sonsuz'dadır.
##   ALT     sekme çubuğu YOK (main.gd Harita'da gizler) — dünya tabana kadar;
##           banner yuvası varsa (M8.9-02, owner kararı) dünya yuvanın
##           ÜSTÜNDE biter: level 1 düğümü / OYNA plakası / patika başı
##           banner'a girmez (bkz. `_fit_world`).
##
## Koordinatlar DOKU uzayında (720×1280 harita zemini). Zemin cover ile
## ölçeklenip kırpıldığı için düğümler aynı dönüşümle taşınır
## (`_map_to_screen`); patika hizası her oranda korunur.
##
## Banner yuvalı yerleşim (M8.9-02): dünya dikdörtgeni yuva kadar kısalır.
## Cover ölçeğiyle Sonsuz kalesi üst satırın altında VE level 1 plakası
## yuvanın üstünde kalıyorsa (uzun ekranlar, A36) her şey aynen. 16:9'da
## iki uç birlikte sığmıyor (gerekli 1106 px doku, mevcut ~1087 px); yeni
## kompozisyon icat etmek yerine zemin DİKEYDE en fazla %6 sıkıştırılır
## (720×1280: %2,8 — dokuda gözle seçilmez), düğümler aynı dönüşümle taşınır,
## kırpma iki ucu da kurtaracak şekilde dağıtılır. Yuva 0 iken eski cover
## yerleşimi birebir.
##
## Level verisi, unlock kuralı (`SaveManager.highest_level_unlocked`), yıldız
## verisi, Sonsuz şartı (`is_endless_unlocked`) ve level başlatma yolu
## (`level_chosen` → main._start_level) DEĞİŞMEDİ. Kayıt yalnızca OKUNUR.

signal level_chosen(level: LevelData)
signal home_requested
signal shop_requested

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
## Perspektif: düğüm çapı en alttaki düğümde 1.0, en üsttekinde DEPTH_MIN.
const DEPTH_MIN: float = 0.86
## Sonsuz şartı — kanonik metin (M8.5-12).
const ENDLESS_REQUIREMENT: String = "Level %d'u bitir"
## Punch-hole bandı: zeminin en üst satırları (gök + bulut tepeleri) dikeyde
## gerilerek bandı doldurur; sahnede `flip_v` — bandın ALT kenarı doku satırı
## 0 olur ve zeminin ilk satırıyla birleşir (A36 cihaz kapısı: mirror'suz
## şeritte bulut kenarlarında ince yatay dikiş görünüyordu). Üstüne haze biner.
const SKY_STRIP_ROWS: int = 6
const HAZE_HEIGHT: float = 150.0
## Uzun ekranda (dünya ölçeği > 1) düğümler de yarı oranda büyür: 720×1560'ta
## dünya 1.22×, düğüm 1.11× — oran 16:9 ile aynı okunur; dokunma yalnız büyür.
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
## Harita zemini (sahnedeki MapBackground dokusu; sıkıştırma modunda atlas
## bunun üstüne kurulur, cover modunda doğrudan bu).
const MAP_TEXTURE: Texture2D = preload("res://assets/visual/ui/map_background.png")

## Açılış animasyonu (M8.5-12): patika yanar → düğüm pop → parıltı. ~0.7 s.
const UNLOCK_POP_TIME: float = 0.32
const UNLOCK_TRAIL_TIME: float = 0.4
## Ekran girişi: düğüm katmanı 0.18 s'de belirir, odak düğümü küçük pop.
const ENTRY_TIME: float = 0.18

var _levels: Array[LevelData] = []
## Düğüm butonları, level sırasıyla (index 0 = level 1).
var _nodes: Array[MapLevelNode] = []
var _endless: MapLevelNode
var _focus: MapLevelNode
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
## Test kancası: cihaz üst güvenli payı (A36 punch-hole) masaüstünde
## okunamaz; negatif = gerçek değeri kullan.
var _safe_top_override: float = -1.0
## Test kancası: alt pay (banner yuvası + gesture bar); negatif = gerçek
## (`UiKit.bottom_inset`).
var _bottom_inset_override: float = -1.0
## Dünya dikdörtgeni (cover): son yerleşimde hesaplandı.
var _world: Rect2 = Rect2(Vector2.ZERO, MAP_SIZE)
## Yatay ölçek (doku px → ekran px). Dikey ölçek `_world_scale_y` (yuva
## yokken eşit); `_crop_top` dokunun üstten atılan satırı (doku px).
var _world_scale: float = 1.0
var _world_scale_y: float = 1.0
var _crop_top: float = 0.0
## Sonsuz kalesinin üst satırdan, level 1 plakasının yuvadan uzaklığı (px).
const FIT_MARGIN: float = 12.0
## Dikey sıkıştırma tabanı (sy / sx); altına inilmez (bantlı düzen yerine
## küçük bir taşma kabul edilir — hedef oranlarda gerekmiyor).
const MIN_SQUASH: float = 0.94

@onready var _root: Control = $Root
@onready var _art: TextureRect = $Root/MapBackground
@onready var _sky: TextureRect = $Root/Sky
@onready var _haze: TextureRect = $Root/Haze
@onready var _vignette: TextureRect = $Root/Vignette
@onready var _map: Control = $Root/Map
@onready var _trail: MapTrail = $Root/Map/Trail
@onready var _node_layer: Control = $Root/Map/Nodes
@onready var _fx_layer: Control = $Root/Map/Fx
@onready var _bar: ScreenTopBar = $Root/TopBar


func _ready() -> void:
	_levels = LevelLibrary.load_levels()
	var strip := AtlasTexture.new()
	strip.atlas = MAP_TEXTURE
	strip.region = Rect2(0.0, 0.0, MAP_SIZE.x, float(SKY_STRIP_ROWS))
	_sky.texture = strip
	_haze.texture = _vertical_gradient(Color(0.96, 0.97, 1.0, 0.72), Color(0.96, 0.97, 1.0, 0.0))
	_vignette.texture = _radial_vignette()
	_bar.set_title("HARİTA")
	_bar.back_pressed.connect(func() -> void: home_requested.emit())
	_bar.add_pressed.connect(func() -> void: shop_requested.emit())
	for spec in SPARKLES:
		var spark := UiKit.art(STAR_ART, float(spec[1]))
		_fx_layer.add_child(spark)
		_sparkles.append(spark)
	_root.resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		set_process(visible)
		if visible:
			_layout()
			# main._show_tab görünürlükten SONRA refresh() çağırır: giriş
			# animasyonu yeni düğümleri görsün diye ertelenir.
			_play_entry.call_deferred())
	set_process(visible)
	refresh()


# --- Doku uzayı -> ekran ---

## Dünya: zemin `Rect2(0, safe_top, vw, vh − safe_top)` alanını KEEP_ASPECT_
## COVERED doldurur (ölçek = max(w/720, h/1280), merkezlenir). Aynı dönüşüm
## düğümlere uygulanır. Punch-hole yokken eski (tam ekran) dönüşümle birebir.
func _map_to_screen(map_point: Vector2) -> Vector2:
	return Vector2((map_point.x - MAP_SIZE.x * 0.5) * _world_scale + _world.get_center().x,
		_world.position.y + (map_point.y - _crop_top) * _world_scale_y)


func _safe_top() -> float:
	if _safe_top_override >= 0.0:
		return _safe_top_override
	return UiKit.safe_top(_root.size)


func _bottom_inset() -> float:
	if _bottom_inset_override >= 0.0:
		return _bottom_inset_override
	return UiKit.bottom_inset(_root.size)


## Dünya ölçeği + kırpma (bkz. üst not). Cover ölçeği `sx`; dikey `sy` ≤ sx.
## Sınırlar: Sonsuz kalesinin üstü üst satırın altında (FIT_MARGIN), level 1
## OYNA plakasının altı dünyanın (= yuvanın) üstünde (FIT_MARGIN). Sığıyorsa
## kırpma ortalanır (eski davranış); sığmıyorsa önce kırpma iki uca göre
## seçilir, o da yetmezse sy düşürülür.
func _fit_world(view: Vector2, safe_top: float, bottom_inset: float) -> void:
	_world = Rect2(0.0, safe_top, view.x, maxf(view.y - safe_top - bottom_inset, 1.0))
	var sx: float = maxf(_world.size.x / MAP_SIZE.x, _world.size.y / MAP_SIZE.y)
	_world_scale = sx
	_world_scale_y = sx
	_crop_top = (MAP_SIZE.y - _world.size.y / sx) * 0.5
	if bottom_inset <= 0.0:
		return
	var ns: float = _node_world_scale()
	var bar_bottom: float = _bar.height() + 3.0 - _world.position.y
	# Doku uzayında iki uç: kale madalyonunun üstü, level 1 plakasının altı.
	var top_anchor: float = ENDLESS_POSITION.y
	var top_extent: float = MapLevelNode.ENDLESS_DIAMETER * ns * 0.5
	var bottom_anchor: float = NODE_POSITIONS[0].y
	var bottom_extent: float = MapLevelNode.LEVEL_DIAMETER * MapLevelNode.CURRENT_SCALE * ns * 0.5 \
		+ MapLevelNode.LIP - MapLevelNode.PLAQUE_OVERLAP + MapLevelNode.PLAQUE_HEIGHT + 2.0
	var span_budget: float = _world.size.y - 2.0 * FIT_MARGIN - bar_bottom - top_extent - bottom_extent
	var sy: float = minf(sx, span_budget / maxf(bottom_anchor - top_anchor, 1.0))
	# Dikey cover'ı kaybetmemek için taban: dünya yüksekliği / doku yüksekliği.
	sy = maxf(sy, maxf(_world.size.y / MAP_SIZE.y, sx * MIN_SQUASH))
	_world_scale_y = sy
	var total_crop: float = maxf(MAP_SIZE.y - _world.size.y / sy, 0.0)
	var crop_max: float = top_anchor - (bar_bottom + FIT_MARGIN + top_extent) / sy
	var crop_min: float = bottom_anchor - (_world.size.y - FIT_MARGIN - bottom_extent) / sy
	var crop: float = total_crop * 0.5
	crop = clampf(crop, crop_min, crop_max) if crop_min <= crop_max else crop_min
	_crop_top = clampf(crop, 0.0, total_crop)


func _layout() -> void:
	if _root == null or _bar == null:
		return
	var view: Vector2 = _root.size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var safe_top: float = _safe_top()
	_bar.layout(view.x, safe_top)
	_fit_world(view, safe_top, _bottom_inset())
	_art.position = _world.position
	_art.size = _world.size
	if is_equal_approx(_world_scale_y, _world_scale):
		# Cover: dokuyu Godot kırpar (eski yol, yuva yokken birebir).
		_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_art.texture = MAP_TEXTURE
	else:
		# Dikey sıkıştırma: görünen doku bölgesi atlas ile kesilir ve dünya
		# dikdörtgenine gerilir (yuvanın altına hiçbir şey çizilmez).
		var visible_w: float = _world.size.x / _world_scale
		var visible_h: float = _world.size.y / _world_scale_y
		var atlas := AtlasTexture.new()
		atlas.atlas = MAP_TEXTURE
		atlas.region = Rect2((MAP_SIZE.x - visible_w) * 0.5, _crop_top, visible_w, visible_h)
		_art.stretch_mode = TextureRect.STRETCH_SCALE
		_art.texture = atlas
	_sky.position = Vector2.ZERO
	_sky.size = Vector2(view.x, safe_top + 2.0)
	# Bant, zeminin GÖRÜNEN yatay aralığının en üst satırlarını gerer (uzun
	# ekranda zemin yanlardan kırpılır; bulutlar dikişte hizalı kalsın).
	var art_left: float = _world.position.x + (_world.size.x - MAP_SIZE.x * _world_scale) * 0.5
	var strip: AtlasTexture = _sky.texture as AtlasTexture
	if strip != null:
		strip.region = Rect2((0.0 - art_left) / _world_scale, _crop_top, view.x / _world_scale, float(SKY_STRIP_ROWS))
	_haze.position = Vector2.ZERO
	_haze.size = Vector2(view.x, safe_top + HAZE_HEIGHT)
	_vignette.position = Vector2.ZERO
	_vignette.size = view

	var trail_points := PackedVector2Array()
	var radii := PackedFloat32Array()
	for i in _nodes.size():
		var node: MapLevelNode = _nodes[i]
		var center: Vector2 = _map_to_screen(NODE_POSITIONS[i])
		var d: float = _node_diameter(i, node.state() == MapLevelNode.State.CURRENT)
		node.set_diameter(d)
		node.position = center - Vector2(d, d) * 0.5
		trail_points.append(center)
		radii.append(d * 0.5)
	if _endless != null:
		var center: Vector2 = _map_to_screen(ENDLESS_POSITION)
		_endless.set_diameter(MapLevelNode.ENDLESS_DIAMETER * _node_world_scale())
		var d: float = _endless.diameter()
		_endless.position = center - Vector2(d, d) * 0.5
		trail_points.append(center)
		radii.append(d * 0.5)
	_trail.set_trail(trail_points, _done_segments(), _trail.lit, radii)
	for i in _sparkles.size():
		var spec: Array = SPARKLES[i]
		var box: float = float(spec[1])
		var at: Vector2 = _map_to_screen(spec[0] as Vector2)
		_sparkles[i].position = at - Vector2(box, box) * 0.5
		_sparkles[i].size = Vector2(box, box)
		_sparkles[i].pivot_offset = Vector2(box, box) * 0.5


## Perspektif çapı: doku y'sine göre 84 → 72; sıradaki ×1.14.
func _node_diameter(index: int, current: bool) -> float:
	var y: float = NODE_POSITIONS[index].y
	var t: float = clampf((y - NODE_POSITIONS[NODE_POSITIONS.size() - 1].y)
		/ maxf(NODE_POSITIONS[0].y - NODE_POSITIONS[NODE_POSITIONS.size() - 1].y, 1.0), 0.0, 1.0)
	var d: float = MapLevelNode.LEVEL_DIAMETER * lerpf(DEPTH_MIN, 1.0, t) * _node_world_scale()
	if current:
		d *= MapLevelNode.CURRENT_SCALE
	return d


func _node_world_scale() -> float:
	return 1.0 + maxf(_world_scale - 1.0, 0.0) * NODE_WORLD_SCALE_SHARE


## Tamamlanmış segment sayısı: level k tamamlandıysa k→k+1 segmenti sıcak.
## highest_level_unlocked = H demek 1..H-1 tamamlandı → H-1 segment.
func _done_segments() -> int:
	return clampi(SaveManager.highest_level_unlocked() - 1, 0, NODE_POSITIONS.size())


# --- Tazeleme ---

func refresh() -> void:
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
		node.pressed.connect(_on_node_pressed.bind(node, level))
		_node_layer.add_child(node)
		_nodes.append(node)
		if state == MapLevelNode.State.CURRENT and level.level_number == highest:
			_focus = node

	var endless_open: bool = SaveManager.is_endless_unlocked(_levels.size())
	_endless = MapLevelNode.new()
	_endless.setup_endless(endless_open, SaveManager.endless_high_score(),
		ENDLESS_REQUIREMENT % _levels.size())
	_endless.pressed.connect(_on_endless_pressed)
	_node_layer.add_child(_endless)
	# Her şey bitmişse yolculuğun hedefi Sonsuz: hale oraya.
	if _focus == null and endless_open:
		_focus = _endless
	if _focus != null:
		_focus.set_focused(true)

	_bar.set_value(str(SaveManager.dough()), false)
	_trail.lit = 0.0
	_layout()

	if newly_unlocked > 0:
		_play_unlock(newly_unlocked)


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

## Ekran girişi (sekme geçişinin üstüne): düğüm katmanı kısa solmayla
## gelir, odak düğümü küçük pop. Düğüm konumları oynamaz.
func _play_entry() -> void:
	if not is_inside_tree():
		return
	if _entry_tween != null and _entry_tween.is_valid():
		_entry_tween.kill()
	_node_layer.modulate.a = 0.0
	_entry_tween = create_tween()
	_entry_tween.tween_property(_node_layer, "modulate:a", 1.0, ENTRY_TIME)
	if _focus != null and not _unlock_playing:
		_entry_tween.tween_callback(UiMotion.pop.bind(_focus, 1.06))


## Atmosfer pırıltıları sönümlenir (sinüs, RNG yok). Düğümlerin kendi
## nefesi MapLevelNode içinde.
func _process(delta: float) -> void:
	_time += delta
	for i in _sparkles.size():
		var spec: Array = SPARKLES[i]
		var twinkle: float = 0.35 + 0.5 * (0.5 + 0.5 * sin(TAU * _time / 2.3 + float(spec[2])))
		_sparkles[i].modulate.a = twinkle
		_sparkles[i].scale = Vector2.ONE * (0.8 + 0.3 * twinkle)


## Level `level_number` ilk kez açıldı: patikanın son segmenti yanar,
## düğüm pop'lar, birkaç parıltı, `level_unlock`. ~0.7 s, kesilebilir;
## kayıt değişmez.
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


## Test/çekim kancası: alt pay (banner yuvası) da verilir.
func _layout_with_insets(safe_top: float, bottom_inset: float) -> void:
	_safe_top_override = safe_top
	_bottom_inset_override = bottom_inset
	_layout()


func world_scale() -> Vector2:
	return Vector2(_world_scale, _world_scale_y)


func crop_top() -> float:
	return _crop_top


func nodes() -> Array[MapLevelNode]:
	return _nodes


func endless_node() -> MapLevelNode:
	return _endless


func focus_node() -> MapLevelNode:
	return _focus


func top_bar() -> ScreenTopBar:
	return _bar


func trail() -> MapTrail:
	return _trail


func world_rect() -> Rect2:
	return _world


func map_art() -> TextureRect:
	return _art
