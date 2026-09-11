extends Node2D
## Oyun tahtası: kap, drop kontrolü, merge çözümü, hedef/süre takibi ve
## taşma (fail) kontrolü. Geometri ve hedefler LevelData'dan gelir.

signal round_finished(won: bool)
## Taşma grace'i doldu ama round HENÜZ BİTMEDİ: oyuncuya devam etme teklifi
## sunulmalı (M8.5-04). `remaining` bu round'da kalan devam hakkı.
## round_finished bu noktada YAYILMAZ.
signal revive_offered(remaining: int)
## Devam hakkı kullanıldı ve board tekrar oynanabilir hâle geldi.
signal revive_granted(used: int, remaining: int)
## Stok 0 bir güç istendi: refill penceresi açılmalı ve oyun DURMALI
## (M8.5-06). `refill_requested` yalnızca olayı haber veriyordu; bu sinyal
## board'un fiilen donduğunu da bildiriyor.
signal power_refill_offered(type: int)

const DUMPLING_SCENE: PackedScene = preload("res://scenes/game/dumpling.tscn")
const POP_EFFECT_SCENE: PackedScene = preload("res://scenes/game/pop_effect.tscn")
const BOKEH_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_dot.png")
## Güç efektlerinin halka/parıltı katmanları (M8.5-07).
const RING_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_ring.png")
const SPARKLE_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_sparkle.png")
## Owner'ın güç efekt asset'leri (M8.5-08). Prosedürel katmanların YERİNE
## GEÇMİYOR, üstüne biniyorlar: halka/toz okunurluğu sağlıyor, bu dokular
## karakteri veriyor.
##
## Uçan bomba ile patlama AYRI dosyalar — uçan bomba görselini "patlama"
## diye kullanmak yanlış olurdu, patlamanın kendi asset'i var.
const BOMB_PROJECTILE_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_bomb_projectile.png")
const BOMB_IMPACT_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_bomb_impact.png")
const UPGRADE_BEAM_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_upgrade_beam.png")
const PUFF_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_puff_cloud.png")
const STAR_SWIRL_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_star_swirl.png")
## Taşma çizgisinin görsel katmanı — owner asset'i (M8 art turu).
const DANGER_STRIPE_TEXTURE: Texture2D = preload("res://assets/visual/ui/danger_stripe.png")
const DROP_BAG := preload("res://scripts/game/drop_bag.gd")

const WALL_THICKNESS: float = 20.0
## Taşma çizgisine bu süre boyunca temas edilirse round biter (GAME_DESIGN.md §1).
const OVERFLOW_GRACE: float = 1.5
const DROP_COOLDOWN: float = 0.4

## Combo: bu süre içinde art arda gelen merge'ler zincir sayılır
## (GAME_DESIGN.md §6). Zincir 2'ye ulaşınca combo sesi ve "xN" yazısı.
const COMBO_WINDOW: float = 1.2
## Taşma tehlikesindeyken gerilim sesinin tekrar aralığı.
const DANGER_TICK_INTERVAL: float = 0.5

## Taşma şeridinin sakin hâldeki opaklığı; tehlikede DANGER_STRIPE_ALPHA_MAX'a
## çıkıyor. Çizgi her zaman görünmeli (fail çizgisi), tehlikede vurgulanmalı.
##
## M8.5-08: idle 0.55 → 0.34. Yeni gece zemininin üstünde eski değer sürekli
## alarm veriyordu ve şerit board'un en parlak öğesiydi; oysa şerit sakin
## hâlde yalnızca "sınır burası" demeli. MEKANİK DEĞİŞMEDİ — grace süresi,
## taşma alanı ve `_danger_pulse`ın hesabı aynı; değişen yalnız çizim.
const DANGER_STRIPE_ALPHA_IDLE: float = 0.34
const DANGER_STRIPE_ALPHA_MAX: float = 1.0
## Sakin hâldeki renk yumuşatması. Opaklığı daha da düşürmek şeridi
## kaybediyordu; bunun yerine renk soğutuluyor, tehlikede tam beyaza
## (yani asset'in kendi kırmızısına) dönüyor.
const DANGER_STRIPE_IDLE_TINT: Color = Color(0.74, 0.68, 0.80)

## --- Güçler (GAME_DESIGN.md §10) ---
##
## Sarsıntı impulse'u. Değerler gerçek Godot koşularıyla kalibre edildi
## (bkz. tools/_shake_probe): kütleyle ÇARPILIYOR, yoksa tier 1 fırlarken
## tier 8 kıpırdamıyordu. Yatay bileşen baskın; yukarı bileşen bilerek küçük
## çünkü yukarı savurmak haksız taşma üretiyor.
const SHAKE_IMPULSE_X: float = 230.0
const SHAKE_IMPULSE_UP_MIN: float = 40.0
const SHAKE_IMPULSE_UP_MAX: float = 150.0
## Sarsıntıdan sonra taşma sayacının dondurulduğu süre. Bitince normal 1.5 sn
## kuralı aynen geri döner. Stack ETMEZ: yeni sarsıntı pencereyi uzatmaz,
## baştan aynı süreye kurar.
const SHAKE_OVERFLOW_GRACE: float = 1.2
## Temizleyicinin parçaları teker teker patlatma aralığı — tek karede 20
## queue_free() sert görünüyor, ama efekt de uzamamalı.
const CLEAR_STAGGER: float = 0.045
## Bombanın hedefe uçma süresi.
const BOMB_TRAVEL: float = 0.28

## --- Devam etme / revive (GAME_DESIGN.md §11) ---
##
## Round başına en fazla iki devam hakkı. Sayaç ROUND-LOCAL: kayda yazılmıyor,
## her yeni round/retry'da 0'dan başlıyor.
const MAX_REVIVES_PER_ROUND: int = 2
## Devam edildikten sonra board'un oturması için taşma sayacının donduğu süre.
## Sarsıntı korumasıyla aynı mantık: STACK ETMEZ, bitince normal
## OVERFLOW_GRACE kuralı aynen döner.
const REVIVE_PROTECTION: float = 1.5
## Kurtarma temizliği taşma çizgisinin bu kadar ALTINA kadar iner. Üst kenarı
## bu derinliğin üstünde kalan yerleşmiş parçalar kaldırılır.
##
## 120 px = oyun alanı yüksekliğinin (`playable_height`, her level'da 400)
## %30'u. Değer TAHMİN DEĞİL, ölçüldü (`tools/_revive_probe`, level 10,
## rastgele oynayan bot, n=10 her derinlik için; referans: devam olmadan bir
## round medyan **34 sn** sürüyor):
##
## | derinlik | kaldırılan | çizgi altı boşluk | devam sonrası oynanan |
## |---|---|---|---|
## | 0   | %8  | 16 px  | 3.1 sn  |
## | 60  | %30 | 67 px  | 7.6 sn  |
## | **120** | **%42** | **126 px** | **12.1 sn** |
## | 180 | %55 | 199 px | 18.0 sn |
## | 260 | %68 | 280 px | 29.7 sn |
##
## 0 elendi: yalnızca çizgiyi fiilen aşanları kaldırmak board'u dolu bırakıyor,
## oyuncu 3 saniyede aynı fail'e düşüyor — reklam izlemenin karşılığı yok.
## 180+ elendi: board'un yarısından fazlası gidiyor, iki devam hakkıyla
## birlikte round'u fiilen ikiye katlıyor. 120 bir round'un üçte biri kadar
## oyun açıyor; devam anlamlı ama round yeniden başlamıyor.
const REVIVE_RESCUE_DEPTH: float = 120.0

## Sürükle-bırak ipucunun gösterildiği level. Yalnızca ilk level'da, ilk
## bırakışa kadar. Bkz. _setup_tutorial().
const TUTORIAL_LEVEL: int = 1
const TUTORIAL_SIZE: Vector2 = Vector2(360.0, 220.0)
## İpucu kabın ağzı ile taşma çizgisi arasında, bu oranda aşağıda duruyor.
const TUTORIAL_Y_RATIO: float = 0.42

## Ekran sarsıntısı (M8 juice): merge'in tier'ına göre ölçekleniyor.
## Küçük merge'de neredeyse hissedilmiyor, tier 8'de belirgin.
## M8.5-11: kucuk merge'lerde (tier <= 3) sarsinti YOK; tier 4-6 hafif,
## tier 7-8 kisa ve belirgin. Eski egri tier 2'de bile 1.5 px titretiyordu.
const SHAKE_MIN_TIER: int = 4
const SHAKE_MIN: float = 2.0
const SHAKE_MAX: float = 14.0
## Sarsıntı saniyede bu oranda sönümleniyor (yüksek = daha kısa/keskin).
const SHAKE_DECAY: float = 9.0
## Sarsıntının kap parlamasının sönümlenme hızı (yalnızca görsel).
const SHAKE_FLASH_DECAY: float = 2.6

## --- Kabın görünür yüzeyi (M8.5-08) ---
##
## Düz pastel renkler GİTTİ: duvar ve taban artık owner'ın bambu asset'leri.
## Kaynak dikey duvar görselinin şeffaflığı SAHTEYDİ (satranç deseni gerçek
## piksel olarak basılmıştı, alfa %100 opak); doku o dosyadan satranç
## desenine ve yaprağa DEĞMEYEN, ölçülmüş temiz bir sütundan kesildi.
## Ayrıntı: PROJECT_STATUS §4.11.
const WALL_TEXTURE: Texture2D = preload("res://assets/visual/ui/board_wall_bamboo.png")
const FLOOR_TEXTURE: Texture2D = preload("res://assets/visual/ui/board_floor_bamboo.png")
## Görünür taban FLOOR_Y'nin bu kadar ALTINA iniyor. Fizik tabanı 20 px'lik
## collider olarak yerinde duruyor; yatay bambu rayı 20 px'e sıkıştırılsa
## boğum ve kalp süsleri okunmazdı. Aşağı doğru büyüyor, oyun alanına
## GİRMİYOR: FLOOR_Y 1180, viewport 1280, altta 100 px boş yer var.
const FLOOR_APRON: float = 54.0
## Kabın iç zemini — arka plan sahnesinin üstünde oyun alanını ayırıyor.
const WELL_COLOR: Color = Color(0.09, 0.07, 0.13, 0.34)

## Duvar/taban da sekmeli olmalı, yoksa yalnızca dumpling-dumpling
## çarpışmaları zıpluyor ve kap ölü hissettiriyor.
const WALL_BOUNCE: float = 0.13
const WALL_FRICTION: float = 0.5

## Kabın tabanı — tüm level'larda sabit, ekranın altına yakın.
const FLOOR_Y: float = 1180.0
## Taşma çizgisinin üstünde kalan görünür duvar payı. M1'de belirlendi: hem
## ekranı dolduruyor hem de grace süresinde yığının çizgiyi aşması görünüyor.
const RIM_ABOVE_LINE: float = 420.0
## Drop çizgisi kabın ağzının bu kadar üstünde.
const DROP_LINE_ABOVE_RIM: float = 90.0

var level: LevelData

var _aim_x: float = 360.0
var _pending_tier: int = 1
var _next_tier: int = 1
var _drop_cooldown: float = 0.0
var _overflow_elapsed: float = 0.0
var _combo_count: int = 0
var _combo_timer: float = 0.0
var _danger_tick: float = 0.0
var _reached_target_tier: bool = false
var _is_finished: bool = false
## Taşma doldu, round DURDURULDU, devam teklifi bekleniyor. `_is_finished`
## ile aynı anda true olamaz: teklif ya revive ile kapanır ya `_finish(false)`
## ile.
var _is_fail_pending: bool = false
## Bu round'da GERÇEKTEN kullanılmış devam hakkı. Yalnızca grant_revive()
## başarılı olunca artar — teklifin açılması, CTA'ya basılması, reklamın
## yüklenememesi ve "Bitir" hak TÜKETMEZ.
var _revives_used: int = 0
## Devam sonrası taşma koruması kalan süre (sn). >0 iken taşma birikmiyor.
var _revive_protection: float = 0.0
## Stok 0 refill penceresi açık: oyun DURDU (M8.5-06). Fail-pending ile aynı
## dondurma makinesini kullanıyor ama round bitmiyor — pencere kapanınca
## oyun kaldığı yerden devam ediyor.
var _is_refill_pending: bool = false
## Refill penceresinin hangi güç için açıldığı — niyet geri dönüşü için.
var _refill_type: PowerUp.Type = PowerUp.Type.BOMB
var _shake_strength: float = 0.0
## Danger highlight'ının nabzı (GAME_DESIGN.md §6) — 0..1 arası salınır.
var _danger_pulse: float = 0.0
## Tehlike nabzinin fazi ve aciliyeti (0..1, tasma sayaci / grace) — sunum.
var _danger_phase: float = 0.0
var _danger_urgency: float = 0.0
## İpucu bir kez kapandıktan sonra tekrar açılmasın (fade tween'i sırasında
## ikinci bir bırakış gelirse iki tween çakışırdı).
var _tutorial_dismissed: bool = false
## Sarsıntı sonrası taşma koruması kalan süre (sn). >0 iken taşma birikmiyor.
var _shake_protection: float = 0.0
## Sarsıntının kap kenarındaki parlaması (1 → 0). Yalnızca GÖRSEL; fizik
## ve taşma mantığıyla hiçbir ilgisi yok.
var _shake_flash: float = 0.0
## Sarsıntının rastgeleliği; testlerde sabitlenebilsin diye ayrı bir üreteç.
var _shake_rng := RandomNumberGenerator.new()
## YALNIZCA görsel efektler için. Gameplay RNG akışından (drop_bag, kamera
## sarsıntısı) ayrı tutuluyor: yeni bir efekt eklemek bırakma sırasını
## değiştirmesin. Mevcut RNG coupling teknik borcuna DOKUNULMADI.
var _fx_rng := RandomNumberGenerator.new()
## Güç seçimi/hedefleme durum makinesi (scripts/game/power_up_controller.gd).
var _powerups: PowerUpController
## Skor pop'u için: değişimin miktarını göstermek gerekiyor, sadece yeni
## toplamı değil.
var _prev_score: int = 0
## Skor pop'unun sahnede tanımlı yuvası — animasyon her seferinde buradan
## başlar. Skor metninden türetilmiyor çünkü metnin genişliği değişiyor.
var _score_pop_home: Vector2 = Vector2.ZERO
## Drop sırası: bağımsız rastgele değil, karılmış torbadan (bkz. drop_bag.gd).
## Round başına yeni torba — önceki round'un kalanı sızmasın.
var _drop_bag: RefCounted = DROP_BAG.new()

@onready var _walls: StaticBody2D = $Walls
@onready var _dumpling_layer: Node2D = $DumplingLayer
@onready var _overflow_area: Area2D = $OverflowArea
@onready var _overflow_shape: CollisionShape2D = $OverflowArea/OverflowShape
@onready var _preview: Node2D = $Preview
@onready var _score_label: Label = $HUD/ScoreLabel
@onready var _next_label: Label = $HUD/NextLabel
@onready var _objective_label: RichTextLabel = $HUD/ObjectiveLabel
@onready var _status_label: Label = $HUD/StatusLabel
@onready var _combo_label: Label = $HUD/ComboLabel
@onready var _score_pop: Label = $HUD/ScorePop
@onready var _tutorial: VBoxContainer = $HUD/Tutorial
@onready var _combo_badge: TextureRect = $HUD/ComboLabel/Badge
@onready var _power_bar: Control = $HUD/PowerBar
@onready var _camera: Camera2D = $Camera2D
@onready var _bokeh: CPUParticles2D = $Bokeh


## add_child'dan ÖNCE çağrılmalı — geometri _ready'de bundan kuruluyor.
func setup(level_data: LevelData) -> void:
	level = level_data


func _ready() -> void:
	if level == null:
		push_error("GameBoard level'sız başlatıldı.")
		return

	GameState.reset_run()
	GameState.current_level = level.level_number
	GameState.score_changed.connect(_on_score_changed)

	# Sarsıntı kamerayı kaydırarak yapılıyor; gövdeleri/duvarları oynatmak
	# fizikle çakışırdı. Kamera varsayılan görüntünün tam merkezine oturuyor.
	_camera.position = get_viewport_rect().size * 0.5
	_setup_bokeh()
	_build_walls()
	_setup_overflow_area()

	_aim_x = _center_x()
	_pending_tier = _drop_bag.next_tier()
	_next_tier = _drop_bag.next_tier()
	_refresh_preview()
	_on_score_changed(GameState.score)
	# Taç level göstergesinde, bayrak hedefte (owner ikon seti). Sonsuz modda
	# "Level N" yok — objective_text() zaten "Hedef yok ..." diyor, oraya
	# bayrak koymak yanlış olurdu.
	if level.is_endless:
		_objective_label.text = "%s — %s" % [
			UiIcons.labelled(UiIcons.CROWN, level.display_name()),
			level.objective_text()]
	else:
		_objective_label.text = "%s — %s" % [
			UiIcons.labelled(UiIcons.CROWN, level.display_name()),
			UiIcons.labelled(UiIcons.FLAG, level.objective_text())]
	_status_label.text = ""
	_set_combo_text("")
	_score_pop.text = ""
	_score_pop.modulate.a = 0.0
	_score_pop_home = _score_pop.position
	_prev_score = GameState.score
	_score_label.pivot_offset = Vector2(0.0, _score_label.size.y * 0.5)
	_setup_tutorial()
	_setup_powerups()


## Sürükle-bırak ipucu: yalnızca level 1'de, ilk bırakışa kadar
## (GAME_DESIGN.md §1.1).
func _setup_tutorial() -> void:
	if level.is_endless or level.level_number != TUTORIAL_LEVEL:
		_tutorial.visible = false
		return
	# Kabın ağzı ile taşma çizgisi arasına: round başında burası boş, ve ilk
	# parça düşmeden ipucu zaten kayboluyor.
	var span: float = overflow_line_y() - container_top_y()
	var mid_y: float = container_top_y() + span * TUTORIAL_Y_RATIO
	_tutorial.size = TUTORIAL_SIZE
	_tutorial.position = Vector2(_center_x() - TUTORIAL_SIZE.x * 0.5,
		mid_y - TUTORIAL_SIZE.y * 0.5)
	_tutorial.visible = true

	# Hafif bir salınım — hareketsiz bir ipucu gözden kaçıyor.
	var bob := create_tween().set_loops().bind_node(_tutorial)
	var home: Vector2 = _tutorial.position
	bob.tween_property(_tutorial, "position", home + Vector2(0.0, 10.0), 0.9) \
		.set_trans(Tween.TRANS_SINE)
	bob.tween_property(_tutorial, "position", home, 0.9).set_trans(Tween.TRANS_SINE)


## İlk bırakışta sönerek kaybolur — oyuncu mekaniği anladı.
func _dismiss_tutorial() -> void:
	if _tutorial_dismissed or not _tutorial.visible:
		return
	_tutorial_dismissed = true
	var fade := create_tween().bind_node(_tutorial)
	fade.tween_property(_tutorial, "modulate:a", 0.0, 0.35)
	fade.tween_callback(func() -> void: _tutorial.visible = false)


# --- Geometri ---

func _center_x() -> float:
	return get_viewport_rect().size.x * 0.5


func _left_x() -> float:
	return _center_x() - level.container_width * 0.5


func _right_x() -> float:
	return _center_x() + level.container_width * 0.5


func overflow_line_y() -> float:
	return FLOOR_Y - level.playable_height


func container_top_y() -> float:
	return overflow_line_y() - RIM_ABOVE_LINE


func drop_line_y() -> float:
	return container_top_y() - DROP_LINE_ABOVE_RIM


## Kap duvarları koddan kuruluyor — level başına genişlik değişebilsin diye.
func _build_walls() -> void:
	for child in _walls.get_children():
		child.queue_free()

	var wall_material := PhysicsMaterial.new()
	wall_material.friction = WALL_FRICTION
	wall_material.bounce = WALL_BOUNCE
	_walls.physics_material_override = wall_material

	var top: float = container_top_y()
	var height: float = FLOOR_Y - top
	_add_wall(Vector2(_left_x() - WALL_THICKNESS * 0.5, top + height * 0.5),
		Vector2(WALL_THICKNESS, height))
	_add_wall(Vector2(_right_x() + WALL_THICKNESS * 0.5, top + height * 0.5),
		Vector2(WALL_THICKNESS, height))
	_add_wall(Vector2(_center_x(), FLOOR_Y + WALL_THICKNESS * 0.5),
		Vector2(level.container_width + WALL_THICKNESS * 2.0, WALL_THICKNESS))
	queue_redraw()


func _add_wall(at: Vector2, size: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = at
	_walls.add_child(collision)


func _setup_overflow_area() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(level.container_width, 8.0)
	_overflow_shape.shape = shape
	_overflow_shape.position = Vector2(_center_x(), overflow_line_y())


## Kabın görünür katmanı. FİZİĞE DOKUNMAZ: collider'lar `_build_walls()`
## içinde ayrı kuruluyor ve buradaki hiçbir sayı onları etkilemiyor.
## Görsel duvar ile fizik duvarı bilerek ayrı — biri değişirken diğeri
## kazara kaymasın.
##
## Çizim sırası: kabın iç zemini → duvarlar → taşma şeridi → tehlike parlaması.
func _draw() -> void:
	if level == null:
		return
	_draw_container_well()
	_draw_walls()
	_draw_overflow_stripe()
	_draw_danger()


## Kabın içi. Arka plan sahnesi (Backdrop katmanı) tüm ekranı kapladığı için
## kabın içi ile dışı aynı parlaklıkta kalıyordu ve "kap" okunmuyordu; bu
## hafif koyu dolgu oyun alanını ayırıyor ve karakterlerin siluetini
## okunur tutuyor. Düz renk — sahte doku DEĞİL.
func _draw_container_well() -> void:
	var top: float = container_top_y()
	draw_rect(Rect2(_left_x(), top, level.container_width, FLOOR_Y - top),
		WELL_COLOR)


## Görsel duvarlar ve taban — owner'ın bambu asset'leri (M8.5-08).
##
## FİZİĞE DOKUNMAZ. `WALL_THICKNESS`, `FLOOR_Y`, `RIM_ABOVE_LINE` ve kap
## genişlikleri DEĞİŞMEDİ; collider'lar hâlâ `_build_walls()` içinde ayrı
## kuruluyor. Buradaki tek fark `draw_rect` yerine `draw_texture_rect`.
##
## Dokular hedef dikdörtgene GERİLİYOR, tile edilmiyor: dikey duvar 20 px
## genişliğinde, tile edilse boğum aralığı ekran yüksekliğine göre değişir
## ve level'dan level'a tutarsız olurdu. Germe anizotropik (dikey bambu
## yatayda ~2.4x sıkışıyor) ama bambu zaten dikey çizgiler + yatay boğum
## bantlarından oluştuğu için 20 px'lik şeritte bu okunmuyor — hedef ölçüde
## kontrol edildi.
func _draw_walls() -> void:
	var top: float = container_top_y()
	var height: float = FLOOR_Y - top
	# Sarsıntı parlaması: duvarlar kısa süre gücün vurgu rengine kayıyor.
	var tint: Color = Color.WHITE
	if _shake_flash > 0.0:
		tint = Color.WHITE.lerp(PowerUp.accent(PowerUp.Type.SHAKE),
			_shake_flash * 0.55)
	draw_texture_rect(WALL_TEXTURE,
		Rect2(_left_x() - WALL_THICKNESS, top, WALL_THICKNESS, height),
		false, tint)
	draw_texture_rect(WALL_TEXTURE,
		Rect2(_right_x(), top, WALL_THICKNESS, height), false, tint)
	# Yatay bambu ray: fizik tabanının hizasından başlayıp aşağı iniyor.
	draw_texture_rect(FLOOR_TEXTURE,
		Rect2(_left_x() - WALL_THICKNESS, FLOOR_Y,
			level.container_width + WALL_THICKNESS * 2.0, FLOOR_APRON),
		false, tint)


## Taşma çizgisinin görsel katmanı (owner asset'i). Eskiden kesikli kırmızı
## bir çizgiydi.
##
## TILE EDİLMİYOR, tek parça geriliyor: kaynak dosya piksel-mükemmel seamless
## değil (sol/sag kenar farkı ort. 0.16, en kötü 1.20 — ölçüldü), tile modunda
## her tekrarda görünür bir dikiş olurdu. Kap genişliği zaten level'a göre
## değiştiği (600 / 720) ve şerit ona göre uzatıldığı için tek parça germe
## hem gerekli hem yeterli.
##
## Yükseklik genişlikten türetiliyor: kaynağın en/boy oranı korunuyor, yoksa
## şeritteki yıldızlar ovale dönerdi.
func _draw_overflow_stripe() -> void:
	var tex_size: Vector2 = DANGER_STRIPE_TEXTURE.get_size()
	var width: float = level.container_width
	var height: float = width * (tex_size.y / tex_size.x)
	var alpha: float = lerpf(DANGER_STRIPE_ALPHA_IDLE, DANGER_STRIPE_ALPHA_MAX,
		_danger_pulse)
	var tint: Color = DANGER_STRIPE_IDLE_TINT.lerp(Color.WHITE, _danger_pulse)
	# Şerit çizginin ÜSTÜNE ortalanıyor: fail çizgisi şeridin ortasından
	# geçsin, oyuncu bandın neresinin ölümcül olduğunu görsün.
	draw_texture_rect(DANGER_STRIPE_TEXTURE,
		Rect2(_left_x(), overflow_line_y() - height * 0.5, width, height),
		false, Color(tint.r, tint.g, tint.b, alpha))


## Taşma tehlikesindeyken kap kenarında kırmızı titreşen highlight
## (GAME_DESIGN.md §6). Sesi zaten M6'da eklenmişti, görseli M8'e kalmıştı.
## Şeridin kendi parlaması _draw_overflow_stripe'ta; burada duvarlar.
func _draw_danger() -> void:
	if _danger_pulse <= 0.0:
		return
	# M8.5-11: duz kirmizi duvar dikdortgeni yerine tasma cizgisinden asagi
	# ve yukari solan pembe-kirmizi bir "rim glow" + duvarlarin ust
	# bolumunde ayni tonda hafif parlama. Surekli flash degil: nabiz
	# alfayi 0.16-0.48 arasinda gezdiriyor, aciliyet arttikca ust sinir
	# hafif yukseliyor (ilk deneme 0.10-0.38 cekimde neredeyse okunmadi).
	var peak: float = lerpf(0.16, 0.48 + 0.14 * _danger_urgency, _danger_pulse)
	var glow := Color(1.0, 0.30, 0.42, peak)
	var clear := Color(1.0, 0.30, 0.42, 0.0)
	var line_y: float = overflow_line_y()
	var left: float = _left_x()
	var right: float = _right_x()
	var band: float = 150.0
	# Cizginin ustu: cizgide en parlak, kap agzina dogru solar.
	draw_polygon(PackedVector2Array([
		Vector2(left, line_y - band), Vector2(right, line_y - band),
		Vector2(right, line_y), Vector2(left, line_y)]),
		PackedColorArray([clear, clear, glow, glow]))
	# Cizginin alti: daha kisa, daha soluk — tehlike bolgesi asagi sarkmasin.
	var under := Color(1.0, 0.30, 0.42, peak * 0.6)
	draw_polygon(PackedVector2Array([
		Vector2(left, line_y), Vector2(right, line_y),
		Vector2(right, line_y + band * 0.5), Vector2(left, line_y + band * 0.5)]),
		PackedColorArray([under, under, clear, clear]))
	# Duvarlarin ust yarisi ayni tonla parlar (alt yari sakin kalir).
	var top: float = container_top_y()
	var wall_h: float = (line_y + band * 0.5) - top
	var wall_glow := Color(1.0, 0.30, 0.42, peak * 0.8)
	draw_polygon(PackedVector2Array([
		Vector2(left - WALL_THICKNESS, top), Vector2(left, top),
		Vector2(left, top + wall_h), Vector2(left - WALL_THICKNESS, top + wall_h)]),
		PackedColorArray([wall_glow, wall_glow, clear, clear]))
	draw_polygon(PackedVector2Array([
		Vector2(right, top), Vector2(right + WALL_THICKNESS, top),
		Vector2(right + WALL_THICKNESS, top + wall_h), Vector2(right, top + wall_h)]),
		PackedColorArray([wall_glow, wall_glow, clear, clear]))


# --- Girdi: parmağı sürükle, bırakınca düşür (GAME_DESIGN.md §1) ---
#
# Bir güç silahlıyken normal drop AKIŞI TAMAMEN DEVRE DIŞI: dokunuş hedef
# seçimi olarak yorumlanıyor, boşluğa dokunmak iptal ediyor.

func _unhandled_input(event: InputEvent) -> void:
	# Bir overlay açıkken oyun girdisi tamamen kapalı: ne nişan, ne bırakma,
	# ne hedefleme. Tek etkileşim overlay'in kendi butonları.
	if _is_finished or _is_paused():
		return

	if _powerups.is_armed():
		_handle_targeting_input(event)
		return

	var drag := event as InputEventScreenDrag
	if drag != null:
		_set_aim(drag.position.x)
		return

	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	if touch.pressed:
		_set_aim(touch.position.x)
	else:
		_drop()


## Hedefleme modundaki dokunuş: geçerli bir dumpling'e denk gelirse güç
## uygulanır, gelmezse iptal edilir. İkisi de stok açısından güvenli —
## iptal hiçbir şey tüketmez.
func _handle_targeting_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	var target: Dumpling = _dumpling_at(touch.position)
	if target == null:
		_powerups.cancel()
		return
	_use_targeted_power(target)


## Ekran noktasının altındaki dumpling. Yarıçap testi kullanılıyor: fizik
## sorgusu yerine basit mesafe, çünkü parçalar daire ve sayıları az.
## En ÜSTTEKİ (sona eklenen) parça önce kontrol ediliyor.
func _dumpling_at(screen_point: Vector2) -> Dumpling:
	var children: Array = _dumpling_layer.get_children()
	for i in range(children.size() - 1, -1, -1):
		var dumpling := children[i] as Dumpling
		if dumpling == null or not is_instance_valid(dumpling):
			continue
		if screen_point.distance_to(dumpling.global_position) <= TierConfig.radius(dumpling.tier):
			return dumpling
	return null


# --- Güçler (GAME_DESIGN.md §10) ---

func _setup_powerups() -> void:
	_powerups = PowerUpController.new()
	_powerups.name = "PowerUps"
	add_child(_powerups)
	_powerups.armed_changed.connect(_on_power_armed_changed)
	_powerups.stock_changed.connect(_refresh_power_bar)
	# Stok 0 iken basılınca yayılıyor. İLERİDE rewarded ad / Hamur / Power
	# Pack akışı buraya bağlanacak; şu an yalnızca kaydediliyor.
	_powerups.refill_requested.connect(_on_power_refill_requested)
	_power_bar.power_pressed.connect(_on_power_pressed)
	_shake_rng.randomize()
	_fx_rng.randomize()
	_refresh_power_bar()


func _refresh_power_bar() -> void:
	_power_bar.refresh()


func _on_power_armed_changed(type: int) -> void:
	_power_bar.set_armed(type)
	if type == PowerUpController.ARMED_NONE:
		_clear_target_highlights()
	else:
		_highlight_valid_targets()
	# Silahlıyken önizleme gizleniyor: drop yapılamıyor, sahte umut vermesin.
	_preview.visible = not _powerups.is_armed()


## Güç butonu. Hedefli güçler hedefleme moduna girer; anında çalışanlar
## burada yürütülür. HİÇBİRİ butona basıldığı için stok tüketmez.
func _on_power_pressed(type_index: int) -> void:
	if _is_finished or _is_paused():
		return
	var type: PowerUp.Type = type_index as PowerUp.Type
	if PowerUp.is_targeted(type):
		_powerups.request(type)
		return
	# Anında çalışan güçler (Sarsıntı / Temizleyici).
	#
	# request() bunlar için hedefleme AÇMAZ ve HER ZAMAN false döner — işi
	# yalnızca (a) stok yoksa refill sinyalini yaymak, (b) açık bir
	# hedeflemeyi temizlemek (iki güç aynı anda aktif olamaz). Dönüşü her
	# zaman false olduğu için karar aslında stoğa bakıyor: stok varsa
	# devam, yoksa çık.
	if not _powerups.request(type) and not SaveManager.has_powerup(type):
		return
	match type:
		PowerUp.Type.SHAKE:
			_use_shake()
		PowerUp.Type.CLEAR_SMALL:
			_use_clear_small()


## Stok 0 iken güç butonuna basıldı.
##
## Bu, güç edinmenin ÜÇ yolunun buluşacağı tek nokta (GAME_DESIGN.md §5.7):
##
##   1. Ödüllü reklam → +1   — HENÜZ YOK (SDK kurulmadı)
##   2. Hamurla al           — VAR, mağazada (PowerUpEconomy.purchase)
##   3. Güç Paketi (IAP)     — HENÜZ YOK (billing kurulmadı)
##
## Sinyal hangi gücün istendiğini eksiksiz taşıyor (`type_index`), böylece
## ileride buraya bir refill modalı takıldığında doğru güç önceden seçili
## gelebilir. BU TURDA MODAL YOK ve hiçbir şey verilmiyor: oyuncuya yalnızca
## Hamur karşılığı söyleniyor, satın alma mağazadan yapılıyor. Round'un
## ortasında mağaza açmak oyunu böler — bilinçli olarak yapılmadı.
func _on_power_refill_requested(type_index: int) -> void:
	if not PowerUp.is_valid_type(type_index):
		return
	if _is_finished or _is_paused():
		return
	_refill_type = type_index as PowerUp.Type
	_enter_refill_pending(_refill_type)


# --- Hedef vurgusu ---

func _highlight_valid_targets() -> void:
	for node in _dumpling_layer.get_children():
		var dumpling := node as Dumpling
		if dumpling == null:
			continue
		dumpling.set_targetable(_powerups.is_valid_target(dumpling))


func _clear_target_highlights() -> void:
	for node in _dumpling_layer.get_children():
		var dumpling := node as Dumpling
		if dumpling != null and is_instance_valid(dumpling):
			dumpling.set_targetable(false)


# --- Güç efektleri: ortak yardımcılar (M8.5-07) ---
#
# M8.5-08: owner'ın güç efekt asset'leri BAĞLANDI. Prosedürel katmanlar
# (fx_ring / fx_dot / fx_sparkle) KALDIRILMADI — okunurluğu onlar taşıyor,
# owner asset'leri karakteri veriyor, ikisi birlikte çalışıyor.
#
# PERFORMANS KURALI: her efekt TEK atışlık, ömrü < 1 sn ve parçacık sayısı
# sabit bir tavanla sınırlı. Tier 8 merge'i + güç efekti aynı anda oynasa
# bile toplam parçacık birkaç yüzü geçmiyor.
#
# RNG: görsel rastgelelik `_fx_rng` üzerinden — gameplay RNG akışına
# (drop_bag / kamera sarsıntısı) DOKUNMUYOR.

## Halka efektinin en fazla yaşayacağı süre.
const FX_RING_TIME: float = 0.34
## Toz/parıltı bulutlarının parçacık tavanı.
const FX_DUST_MAX: int = 20
const FX_SPARKLE_MAX: int = 16
## Temizleyicinin süpürme halkası bu kadar parça kaldırıldıysa oynuyor —
## tek parça için ekranın ortasında halka açmak abartı olurdu.
const FX_SWEEP_MIN_TARGETS: int = 3


## Genişleyen ya da daralan halka. `from_scale` > `to_scale` ise kilitlenme
## (içeri doğru), tersi ise patlama (dışarı doğru) okunur.
func _spawn_ring(at: Vector2, ring_color: Color, from_scale: float,
		to_scale: float, duration: float = FX_RING_TIME) -> void:
	_spawn_fx_sprite(at, RING_TEXTURE,
		Color(ring_color.r, ring_color.g, ring_color.b, 0.9),
		from_scale, to_scale, duration)


## Tek atışlık, ölçeklenip sönen sprite. Halkalar da, owner'ın patlama /
## yükselme / duman asset'leri de bunu kullanıyor — hepsinin ömrü ve
## temizliği tek yerde.
##
## `alpha_hold`: sönmenin ne kadar geç başladığı (0 = baştan sönmeye başlar).
## Patlamada asset bir an tam opak durmalı, yoksa hiç okunmadan kayboluyor.
func _spawn_fx_sprite(at: Vector2, texture: Texture2D, tint: Color,
		from_scale: float, to_scale: float, duration: float,
		spin: float = 0.0, alpha_hold: float = 0.0) -> Sprite2D:
	var fx := Sprite2D.new()
	fx.texture = texture
	fx.position = at
	fx.rotation = spin
	fx.z_index = 5
	fx.modulate = tint
	fx.scale = Vector2.ONE * from_scale
	add_child(fx)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fx, "scale", Vector2.ONE * to_scale, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(fx, "modulate:a", 0.0, duration * (1.0 - alpha_hold)) \
		.set_delay(duration * alpha_hold)
	tween.chain().tween_callback(fx.queue_free)
	return fx


## Bir asset'in hedef PİKSEL çapı için gereken sprite ölçeği. Dokuları elle
## "0.42" gibi sihirli sayılarla ölçeklemek, dosya boyutu değişince sessizce
## bozulurdu.
static func _scale_for(texture: Texture2D, target_px: float) -> float:
	return target_px / maxf(1.0, texture.get_size().x)


## Tek atışlık parçacık bulutu. `up_bias` 1.0 = tamamen yukarı, 0.0 = her yöne.
func _spawn_burst(at: Vector2, texture: Texture2D, burst_color: Color,
		count: int, speed: float, up_bias: float, life: float) -> void:
	var fx := CPUParticles2D.new()
	fx.texture = texture
	fx.position = at
	fx.z_index = 5
	fx.emitting = false
	fx.one_shot = true
	fx.explosiveness = 1.0
	fx.lifetime = life
	fx.amount = maxi(1, count)
	fx.direction = Vector2.UP
	fx.spread = lerpf(180.0, 25.0, clampf(up_bias, 0.0, 1.0))
	fx.gravity = Vector2(0.0, lerpf(700.0, 180.0, up_bias))
	fx.initial_velocity_min = speed * 0.45
	fx.initial_velocity_max = speed
	fx.scale_amount_min = 0.10
	fx.scale_amount_max = 0.26
	fx.color = burst_color
	add_child(fx)
	fx.emitting = true
	get_tree().create_timer(life + 0.25).timeout.connect(fx.queue_free)


# --- Bomba ve Büyütücü ---

func _use_targeted_power(target: Dumpling) -> void:
	if not _powerups.is_valid_target(target):
		# Geçersiz hedef: stok DEĞİŞMEZ, hedefleme açık kalır.
		return
	var type: PowerUp.Type = _powerups.armed_type() as PowerUp.Type
	# Silahı hemen indir: aynı karede gelen ikinci dokunuş bu yola giremesin.
	_powerups.cancel()
	if not _powerups.consume(type):
		return
	match type:
		PowerUp.Type.BOMB:
			_run_bomb(target)
		PowerUp.Type.UPGRADE:
			_run_upgrade(target)


## Bomba: kilitlenme → hedefe uçan mermi → patlama → parça kaldırılır.
## Patlama KOMŞULARI ETKİLEMEZ, tek hedefliktir. MEKANİK DEĞİŞMEDİ —
## M8.5-07 sunumu kurdu, M8.5-08 placeholder dokuları owner asset'leriyle
## değiştirdi. `BOMB_TRAVEL`, hedef kuralları ve stok tüketimi aynı.
##
## Okunurluk zinciri — oyuncu "hangi parçayı bombaladım?" sorusunu anında
## cevaplayabilmeli:
##   1. hedef nabzı durur, kısa beyaz kilitlenme flaşı (play_lock_on)
##   2. hedefin üstüne DARALAN halka — nişan alınan parça bu      (yeni)
##   3. mermi büyüyerek fırlar, yay çizerek ve dönerek iner       (yeni)
##   4. çarpma: genişleyen şok halkası + duman + normal pop       (yeni)
func _run_bomb(target: Dumpling) -> void:
	var destination: Vector2 = target.global_position
	var tier: int = target.tier
	target.play_lock_on()
	# Kilitlenme halkası hedefin üstüne kapanıyor: mermi daha yola çıkmadan
	# hangi parçanın seçildiği belli oluyor.
	_spawn_ring(destination, PowerUp.accent(PowerUp.Type.BOMB),
		2.4, 0.85, BOMB_TRAVEL)

	# Mermi hedefi KAPATMAMALI: çapı hedefin çapının %85'i, ve hiçbir zaman
	# tier 3'ün çapından büyük değil. Tier 8'e atılan bomba ekranı yutmasın.
	var shell_px: float = minf(TierConfig.radius(tier) * 1.7,
		TierConfig.radius(3) * 2.0)
	var shell_scale: float = _scale_for(BOMB_PROJECTILE_TEXTURE, shell_px)

	var shell := Sprite2D.new()
	shell.texture = BOMB_PROJECTILE_TEXTURE
	shell.z_index = 6
	shell.scale = Vector2.ONE * shell_scale * 0.35
	shell.position = Vector2(destination.x, container_top_y() - 60.0)
	add_child(shell)

	# Anticipation: mermi önce yerinde büyüyor, sonra iniyor.
	create_tween().tween_property(shell, "scale", Vector2.ONE * shell_scale, 0.09) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Yay: x yumuşak, y hızlanarak. Düz çizgi yerine "düşüyor" hissi veriyor.
	var arc_x: float = destination.x + _fx_rng.randf_range(-26.0, 26.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(shell, "position:x", destination.x, BOMB_TRAVEL) \
		.set_trans(Tween.TRANS_SINE).from(arc_x)
	tween.tween_property(shell, "position:y", destination.y, BOMB_TRAVEL) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Asset'in kendi hareket izi var (sol-alta uzanıyor), o yüzden eskisi gibi
	# tam tur döndürülmüyor: iz yön değiştirip ters yöne akıyormuş gibi
	# görünürdü. Bunun yerine küçük bir salınım — düşerken canlı duruyor.
	tween.tween_property(shell, "rotation", 0.35, BOMB_TRAVEL) \
		.from(-0.30)
	tween.chain().tween_callback(func() -> void:
		shell.queue_free()
		_detonate_bomb(target, destination, tier))


func _detonate_bomb(target: Dumpling, at: Vector2, tier: int) -> void:
	if is_instance_valid(target):
		target.queue_free()
	# Skor ve merge sayacı DEĞİŞMEZ (GAME_DESIGN.md §10).
	var accent: Color = PowerUp.accent(PowerUp.Type.BOMB)
	# Genişleyen şok halkası + kısa duman: patlamanın merkezi net okunsun.
	_spawn_ring(at, accent, 0.5, 2.6, 0.3)
	# Owner'ın patlama asset'i (uçan bombadan AYRI dosya). Kısa: 0.34 sn.
	# `alpha_hold` ile ilk üçte biri tam opak duruyor, sonra sönüyor —
	# baştan sönseydi patlama hiç okunmadan kaybolurdu.
	_spawn_fx_sprite(at, BOMB_IMPACT_TEXTURE, Color(1, 1, 1, 1),
		_scale_for(BOMB_IMPACT_TEXTURE, TierConfig.radius(tier) * 2.2),
		_scale_for(BOMB_IMPACT_TEXTURE, TierConfig.radius(tier) * 4.4),
		0.34, 0.0, 0.34)
	_spawn_burst(at, BOKEH_TEXTURE, Color(0.72, 0.66, 0.78, 0.85),
		FX_DUST_MAX, TierConfig.radius(tier) * 5.0, 0.15, 0.42)
	_spawn_pop(at, TierConfig.color(tier), TierConfig.radius(tier), maxi(tier, 2))
	_add_shake(tier)
	AudioManager.play_sfx(&"merge", 0.75)


## Büyütücü: parçayı mutate etmek yerine kaldırıp bir üst tier'ı aynı yerde
## doğuruyor. Neden: tier hem collider yarıçapına hem kütleye hem görsele
## bağlı; yerinde `tier += 1` bunları tutarsız bırakırdı.
##
## Momentum korunuyor ki parça havada donmasın. Skor/merge sayacı ARTMAZ ama
## level hedefi yeni tier'ı görür.
func _run_upgrade(target: Dumpling) -> void:
	var old_tier: int = target.tier
	var new_tier: int = target.tier + 1
	var at: Vector2 = target.global_position
	var velocity: Vector2 = target.linear_velocity
	target.queue_free()

	var upgraded := _spawn_dumpling(new_tier, at)
	upgraded.linear_velocity = velocity
	# Normal merge'den daha güçlü squash: dönüşüm "büyüdü" diye okunmalı.
	upgraded.play_squash(0.34, 0.26)

	# --- Reveal (M8.5-07). Dönüşüm ANI değişmedi; efekt onun etrafında. ---
	#
	# Normal merge ile karışmasın diye Büyütücü'nün kendi imzası var:
	# merge'de halka YOK, burada eski tier'ın çapından yeni tier'ın çapına
	# AÇILAN bir halka + yukarı fırlayan parıltı sütunu var.
	var accent: Color = PowerUp.accent(PowerUp.Type.UPGRADE)
	var from_r: float = TierConfig.radius(old_tier)
	var to_r: float = TierConfig.radius(new_tier)
	_spawn_ring(at, accent, from_r / 64.0, (to_r * 1.5) / 64.0, 0.32)
	# Owner'ın yükselme sütunu (ok + halkalar). Yeni parçanın ARKASINDA
	# kalıyor (z_index düşürülüyor) — dönüşen dumpling'in kendisi görünmeli,
	# efekt onu kapatmamalı.
	var beam: Sprite2D = _spawn_fx_sprite(at, UPGRADE_BEAM_TEXTURE,
		Color(1, 1, 1, 0.95),
		_scale_for(UPGRADE_BEAM_TEXTURE, to_r * 2.6),
		_scale_for(UPGRADE_BEAM_TEXTURE, to_r * 3.6),
		0.46, 0.0, 0.30)
	beam.z_index = -1
	# Yukarı doğru parıltı: "yükseldi" hissi. up_bias yüksek = dar koni.
	_spawn_burst(at, SPARKLE_TEXTURE, accent.lerp(Color.WHITE, 0.35),
		FX_SPARKLE_MAX, to_r * 4.5, 0.85, 0.55)

	_spawn_pop(at, TierConfig.color(new_tier), TierConfig.radius(new_tier), new_tier)
	_add_shake(new_tier)
	AudioManager.play_sfx(&"merge", TierConfig.merge_pitch(new_tier))

	# Tier 8'in normal kutlaması güçle elde edilse de çalışır.
	if new_tier == TierConfig.MAX_TIER:
		_flash_status("%s!" % TierConfig.tier_name(new_tier))

	# Hedef takibi: "Tier X'e ulaş" güçle de karşılanabilir.
	if not level.is_endless and new_tier >= level.target_tier:
		_reached_target_tier = true
	_check_objective()


# --- Sarsıntı ---

## Kaba DOKUNMAZ: duvarlar yeniden kurulmuyor, hiçbir şey teleport edilmiyor.
## Yalnızca canlı gövdelere impulse uygulanıyor; parçalar birbirine yaklaşınca
## merge NORMAL çarpışma yolundan oluyor (burada eşleştirme kodu YOK).
func _use_shake() -> void:
	var bodies: Array[Dumpling] = PowerUpController.shakeable(_dumpling_layer.get_children())
	if bodies.is_empty():
		# Board boşken sarsıntının etkisi olmaz — stok harcanmasın.
		_flash_status("Sarsılacak parça yok")
		return
	if not _powerups.consume(PowerUp.Type.SHAKE):
		return

	for dumpling in bodies:
		var sideways: float = _shake_rng.randf_range(-1.0, 1.0)
		var lift: float = _shake_rng.randf_range(SHAKE_IMPULSE_UP_MIN, SHAKE_IMPULSE_UP_MAX)
		# Kütleyle çarpım: her tier benzer hız değişimi alsın.
		dumpling.apply_central_impulse(
			Vector2(sideways * SHAKE_IMPULSE_X, -lift) * dumpling.mass)

	# Taşma koruması: sarsıntı oyuncunun kendi hatası olmayan bir taşma
	# yaratmasın. Sayaç sıfırlanıyor ve kısa süre dondurulup normale dönüyor.
	_overflow_elapsed = 0.0
	_shake_protection = SHAKE_OVERFLOW_GRACE
	_shake_strength = maxf(_shake_strength, SHAKE_MAX * 0.8)
	AudioManager.play_sfx(&"danger", 0.8)
	_flash_status("Sarsıntı!")

	# --- Sunum (M8.5-07). IMPULSE DEĞERLERİ DEĞİŞMEDİ. ---
	#
	# Kamera sarsıntısı tek başına "bir şey oldu" diyor ama "ne oldu"
	# demiyordu. Kabın tabanından kalkan toz + kap kenarının kısa parlaması
	# gücün board'a uygulandığını gösteriyor.
	_play_shake_feedback()


# --- Temizleyici ---

## Tüm canlı tier 1-2 parçaları kaldırır. Merge işlemindekilere DOKUNMUYOR
## (PowerUpController.clearable onları eliyor) — yarıştaki bir merge'in
## ortasına girip yarım durum bırakmasın.
func _use_clear_small() -> void:
	var targets: Array[Dumpling] = PowerUpController.clearable(_dumpling_layer.get_children())
	if targets.is_empty():
		# Küçük parça yoksa güç TÜKETİLMEZ (GAME_DESIGN.md §10).
		_flash_status("Küçük parça yok")
		return
	if not _powerups.consume(PowerUp.Type.CLEAR_SMALL):
		return

	AudioManager.play_sfx(&"merge", 1.15)
	# Süpürme halkası: tek tek pop'lar "dağınık" okunuyordu; ortak bir
	# halka hepsinin AYNI güçle kaldırıldığını anlatıyor. Tek parça için
	# gereksiz olurdu, o yüzden eşik var.
	if targets.size() >= FX_SWEEP_MIN_TARGETS:
		var center := Vector2(_center_x(), (overflow_line_y() + FLOOR_Y) * 0.5)
		_spawn_ring(center, PowerUp.accent(PowerUp.Type.CLEAR_SMALL),
			0.4, level.container_width / 52.0, 0.42)
		# Owner'ın yıldız girdabı: süpürmenin "sihirli süpürge" kimliğini
		# veriyor. Halka okunurluğu, girdap karakteri sağlıyor.
		_spawn_fx_sprite(center, STAR_SWIRL_TEXTURE, Color(1, 1, 1, 0.9),
			_scale_for(STAR_SWIRL_TEXTURE, level.container_width * 0.45),
			_scale_for(STAR_SWIRL_TEXTURE, level.container_width * 0.78),
			0.5, 0.0, 0.24)
	for index in targets.size():
		var dumpling: Dumpling = targets[index]
		# Kademeli pop: tek karede hepsini silmek sert görünüyor.
		var delay: float = float(index) * CLEAR_STAGGER
		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(func() -> void: _pop_and_free(dumpling))
	_flash_status("%d parça temizlendi" % targets.size())


## Tek bir parçayı patlatıp kaldırır. Hem Temizleyici hem devam (revive)
## kurtarma temizliği bunu kullanıyor.
func _pop_and_free(dumpling: Dumpling) -> void:
	if not is_instance_valid(dumpling) or dumpling.is_queued_for_deletion():
		return
	var tier: int = dumpling.tier
	var at: Vector2 = dumpling.global_position
	dumpling.queue_free()
	# Skor ve merge sayacı DEĞİŞMEZ.
	_spawn_pop(at, TierConfig.color(tier), TierConfig.radius(tier), 2)
	# Kısa yukarı iz: parça "silinmiyor", kaldırılıyor gibi okunsun.
	# Parçacık sayısı bilerek küçük — 20 parça birden temizlenebiliyor.
	_spawn_burst(at, SPARKLE_TEXTURE, Color(1.0, 0.95, 0.85, 0.9),
		4, TierConfig.radius(tier) * 3.0, 0.8, 0.34)


## Sarsıntının görsel geri bildirimi. Fizik YOK: yalnızca toz ve kap parlaması.
func _play_shake_feedback() -> void:
	var accent: Color = PowerUp.accent(PowerUp.Type.SHAKE)
	# Taban boyunca birkaç noktadan toz — tek merkezden çıksa "patlama"
	# gibi okunurdu, sarsıntı ise kabın tamamına yayılıyor.
	var puffs: int = 3
	for i in puffs:
		var t: float = (float(i) + 0.5) / float(puffs)
		var at := Vector2(lerpf(_left_x(), _right_x(), t), FLOOR_Y - 12.0)
		# Owner'ın yumuşak duman bulutu — tabandan kalkıp açılıyor.
		# Yön hep yukarı (bulut asset'i ağırlıklı olarak üste doğru açık).
		_spawn_fx_sprite(at + Vector2(0.0, -14.0), PUFF_TEXTURE,
			Color(1, 1, 1, 0.85),
			_scale_for(PUFF_TEXTURE, level.container_width * 0.20),
			_scale_for(PUFF_TEXTURE, level.container_width * 0.34),
			0.52, 0.0, 0.22)
		_spawn_burst(at, BOKEH_TEXTURE, Color(0.85, 0.80, 0.90, 0.55),
			FX_DUST_MAX / puffs, 210.0, 0.7, 0.5)
	# Kap kenarının kısa parlaması.
	_shake_flash = 1.0
	_spawn_ring(Vector2(_center_x(), (overflow_line_y() + FLOOR_Y) * 0.5),
		accent, level.container_width / 90.0, level.container_width / 60.0, 0.36)


func _set_aim(x: float) -> void:
	var margin: float = TierConfig.radius(_pending_tier)
	_aim_x = clampf(x, _left_x() + margin, _right_x() - margin)
	_refresh_preview()


func _refresh_preview() -> void:
	_preview.position = Vector2(_aim_x, drop_line_y())
	_preview.setup(_pending_tier)
	_preview.modulate.a = 1.0 if _drop_cooldown <= 0.0 else 0.4
	_next_label.text = "Sıradaki: %s" % TierConfig.tier_name(_next_tier)


func _drop() -> void:
	# Fail-pending kontrolü BURADA da lazım: _unhandled_input zaten eliyor ama
	# drop cooldown teklif sırasında ilerlemediği için tek başına ona
	# güvenilemez, ve _drop() dışarıdan da (test/bot) çağrılabiliyor.
	if _is_finished or _is_paused() or _drop_cooldown > 0.0:
		return
	_dismiss_tutorial()
	_spawn_dumpling(_pending_tier, Vector2(_aim_x, drop_line_y()))
	_pending_tier = _next_tier
	_next_tier = _drop_bag.next_tier()
	_drop_cooldown = DROP_COOLDOWN
	_set_aim(_aim_x)


func _spawn_dumpling(tier: int, at: Vector2) -> Dumpling:
	var dumpling: Dumpling = DUMPLING_SCENE.instantiate()
	dumpling.setup(tier)
	# Tier 8 annihilation yalnızca sonsuz modda (GAME_DESIGN.md §4).
	dumpling.annihilates_at_max = level.is_endless
	dumpling.position = at
	dumpling.merge_requested.connect(_on_merge_requested)
	dumpling.impact_landed.connect(_on_impact_landed)
	_dumpling_layer.add_child(dumpling)
	# Fail teklifi açıldığı KARE'de uçuşta olan bir merge hâlâ çözülebilir
	# (_resolve_merge deferred çağrılıyor). Doğan parça da donmuş board'a
	# katılmalı, yoksa reklam beklerken tek başına düşerdi.
	if _is_paused():
		dumpling.set_simulation_frozen(true)
	return dumpling


# --- Merge ---

func _on_merge_requested(a: Dumpling, b: Dumpling, point: Vector2) -> void:
	# Fizik callback'i icindeyiz; node ekleme/silme bir sonraki kareye ertelenmeli.
	_resolve_merge.call_deferred(a, b, point)


func _resolve_merge(a: Dumpling, b: Dumpling, point: Vector2) -> void:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return

	if a.tier >= TierConfig.MAX_TIER:
		_resolve_annihilation(a, b, point)
		return

	var new_tier: int = a.tier + 1
	# Sunum (M8.5-11): iki kaynak parcanin hayaleti birlesme noktasina
	# cekilir — fizik merge'i BU KAREDE cozuluyor, hicbir sey ertelenmiyor.
	_play_merge_pull(a, b, point)
	a.queue_free()
	b.queue_free()

	var merged := _spawn_dumpling(new_tier, point)
	var celebratory: bool = new_tier == TierConfig.MAX_TIER
	# Yeni tier: 0.7 -> 1.12 -> 1.0 acilis. Ust tier'larda biraz daha genis.
	merged.play_reveal(1.0 + 0.5 * _tier_t(new_tier))
	_play_merge_flash(point, TierConfig.color(new_tier), TierConfig.radius(new_tier), new_tier)
	_spawn_pop(point, TierConfig.color(new_tier), TierConfig.radius(new_tier), new_tier)
	_add_shake(new_tier)
	if celebratory:
		_play_king_shine(point)

	GameState.add_score(TierConfig.merge_score(new_tier))
	GameState.register_merge(new_tier, point)
	# Tek sample, tier başına artan pitch (GAME_DESIGN.md §6).
	AudioManager.play_sfx(&"merge", TierConfig.merge_pitch(new_tier))
	_register_combo()

	if celebratory:
		_flash_status("%s!" % TierConfig.tier_name(new_tier))
	if new_tier >= FLOAT_SCORE_MIN_TIER:
		_spawn_float_score(point, TierConfig.merge_score(new_tier), TierConfig.color(new_tier))

	if not level.is_endless and new_tier >= level.target_tier:
		_reached_target_tier = true
	_check_objective()


## Sonsuz mod: iki tier 8 çarpışınca ikisi de yok olur (GAME_DESIGN.md §4).
## Level modunda bu yola hiç girilmez — Dumpling.annihilates_at_max false
## olduğu için tier 8'ler merge_requested yaymaz.
##
## Amaç yer açmak: tier 8'ler birikince kap tıkanıyor ve oturum erken
## bitiyordu. Normal merge'den ayrılan yanları: yeni parça DOĞMAZ, patlama
## belirgin daha büyük, sarsıntı daha güçlü, puan tek seferlik bonus.
func _resolve_annihilation(a: Dumpling, b: Dumpling, point: Vector2) -> void:
	a.queue_free()
	b.queue_free()

	var tier: int = TierConfig.MAX_TIER
	_spawn_pop(point, TierConfig.color(tier), TierConfig.radius(tier), tier, true)
	# Tier 8 merge'inin sarsıntısının üstüne çıkıyor (SHAKE_MAX zaten tavan).
	_shake_strength = maxf(_shake_strength, SHAKE_MAX * 1.6)

	GameState.add_score(TierConfig.ANNIHILATION_BONUS)
	# Sandık ilerlemesi açısından normal bir merge sayılıyor.
	GameState.register_merge(tier, point)
	# Merge sesinin en pesi — ağırlık hissi için.
	AudioManager.play_sfx(&"merge", 0.7)
	_register_combo()
	_flash_status("%s x2  +%d!" % [TierConfig.tier_name(tier), TierConfig.ANNIHILATION_BONUS])


## Art arda gelen merge'leri zincirler. Tek merge combo sayılmaz.
func _register_combo() -> void:
	_combo_count += 1
	_combo_timer = COMBO_WINDOW
	if _combo_count < 2:
		return
	AudioManager.play_sfx(&"combo", 1.0 + 0.06 * float(mini(_combo_count, 8)))
	_set_combo_text("x%d" % _combo_count)
	# Zincir uzadıkça yazı büyüsün (GAME_DESIGN.md §6).
	var peak: float = minf(1.3 + 0.12 * float(_combo_count), 2.2)
	var tween := create_tween()
	tween.tween_property(_combo_label, "scale", Vector2(peak, peak), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.15)
	# M8.5-11: zincir uzadikca rozet altina, sonra beyaza dogru parlar ve
	# x3'ten itibaren cok hafif kamera darbesi — ekrani kaplayan yazi degil,
	# "zincir buyuyor" hissi.
	var heat: float = clampf(float(_combo_count - 2) / 4.0, 0.0, 1.0)
	_combo_badge.modulate = Color.WHITE.lerp(COMBO_HOT_TINT, heat)
	_combo_label.add_theme_color_override("font_color",
		Color.WHITE.lerp(COMBO_HOT_TEXT, heat))
	if _combo_count >= 3:
		_shake_strength = maxf(_shake_strength, lerpf(1.5, 4.0, heat))


## Combo yazisi ve arkasindaki rozet birlikte acilip kapaniyor — metin bosken
## ekranda oylece duran bir rozet kalmasin.
func _set_combo_text(text: String) -> void:
	_combo_label.text = text
	_combo_badge.visible = not text.is_empty()
	if text.is_empty():
		_combo_badge.modulate = Color.WHITE
		_combo_label.remove_theme_color_override("font_color")


func _tick_combo(delta: float) -> void:
	if _combo_timer <= 0.0:
		return
	_combo_timer -= delta
	if _combo_timer <= 0.0:
		_combo_count = 0
		_set_combo_text("")


func _spawn_pop(at: Vector2, pop_color: Color, radius: float, tier: int,
		annihilation: bool = false) -> void:
	var effect: Node2D = POP_EFFECT_SCENE.instantiate()
	effect.position = at
	add_child(effect)
	effect.burst(pop_color, radius, tier, annihilation)


## Ekran sarsıntısı, merge'in tier'ına göre. Kamera offset'i kullanılıyor:
## gövdeleri veya tahtayı oynatmak fizik çözümüne karışırdı.
func _add_shake(tier: int) -> void:
	if tier < SHAKE_MIN_TIER:
		return
	var t: float = clampf(float(tier - SHAKE_MIN_TIER) / float(TierConfig.MAX_TIER - SHAKE_MIN_TIER), 0.0, 1.0)
	# Kuvvetli sarsıntı zayıfını ezmesin: üst üste binerse büyük olan kalır.
	_shake_strength = maxf(_shake_strength, lerpf(SHAKE_MIN, SHAKE_MAX, t * t))


## Arka planda yavaş süzülen düşük opaklıklı parıltı noktaları — referans
## moodboard'daki bokeh hissinin ucuz versiyonu (GAME_DESIGN.md §7).
## z_index negatif: kabın ve parçaların ARKASINDA kalmalı.
func _setup_bokeh() -> void:
	var view: Vector2 = get_viewport_rect().size
	_bokeh.texture = BOKEH_TEXTURE
	_bokeh.z_index = -10
	_bokeh.position = view * 0.5
	_bokeh.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	# Yükseklik payı: parçacıklar ekranın altından girip üstünden çıksın.
	_bokeh.emission_rect_extents = Vector2(view.x * 0.5, view.y * 0.6)
	_bokeh.amount = 26
	_bokeh.lifetime = 9.0
	_bokeh.explosiveness = 0.0
	# preprocess: sahne açılır açılmaz ekran zaten dolu olsun, bokeh'in
	# birikmesini beklemeyelim.
	_bokeh.preprocess = 9.0
	_bokeh.direction = Vector2.UP
	_bokeh.spread = 25.0
	_bokeh.gravity = Vector2.ZERO
	_bokeh.initial_velocity_min = 8.0
	_bokeh.initial_velocity_max = 26.0
	_bokeh.scale_amount_min = 0.15
	_bokeh.scale_amount_max = 0.55
	_bokeh.color = Color(1.0, 0.95, 0.85, 0.13)
	_bokeh.emitting = true


func _flash_status(text: String) -> void:
	_status_label.text = text
	await get_tree().create_timer(2.0).timeout
	if not _is_finished and _status_label.text == text:
		_status_label.text = ""


# --- Merge / inis / hedef sunumu (M8.5-11) ---
#
# Hepsi YALNIZCA sunum: fizik merge'i, skor zamanlamasi, taşma ve hedef
# mantigi ayni karede, ayni sirayla cozuluyor. Efektlerin omru < 0.6 sn,
# parcacik sayilari sabit tavanli; rastgelelik `_fx_rng`.
#
# Guc efektleriyle karismamasi icin: normal merge'de HALKA yok (halka
# guclerin imzasi, M8.5-07), onun yerine yumusak parlama + hayalet cekimi.

const COMBO_HOT_TINT: Color = Color(1.0, 0.86, 0.45)
const COMBO_HOT_TEXT: Color = Color(1.0, 0.95, 0.75)
## Birlesme noktasinda ucan "+N" bu tier'dan itibaren (kucuk merge'ler hizli
## ve hafif kalsin; HUD'daki skor pop'u her merge'de zaten var).
const FLOAT_SCORE_MIN_TIER: int = 4
const MERGE_PULL_TIME: float = 0.08
const MERGE_FLASH_TIME: float = 0.18
const PUFF_MAX: int = 6


static func _tier_t(tier: int) -> float:
	return clampf(float(tier - 2) / float(TierConfig.MAX_TIER - 2), 0.0, 1.0)


## Iki kaynak parcanin hayaleti 80 ms'de birlesme noktasina cekilip kucularak
## soner: "temas -> iceri cekilme -> pop" okumasi. Kaynaklar bu karede
## siliniyor; hayalet ayri bir Sprite2D, fizikle ilgisi yok.
func _play_merge_pull(a: Dumpling, b: Dumpling, point: Vector2) -> void:
	for source in [a, b]:
		var ghost: Sprite2D = source.make_ghost()
		if ghost.texture == null:
			ghost.queue_free()
			continue
		ghost.z_index = 4
		add_child(ghost)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(ghost, "global_position", point, MERGE_PULL_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(ghost, "scale", ghost.scale * 0.55, MERGE_PULL_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(ghost, "modulate:a", 0.0, MERGE_PULL_TIME) \
			.set_delay(MERGE_PULL_TIME * 0.4)
		tween.chain().tween_callback(ghost.queue_free)


## Yumusak parlama: beyaza kirilmis tier renginde bir nokta, yaricapin
## 0.6'sindan 1.9'una acilip soner. Guc halkalarindan farkli (dolu, yumusak).
func _play_merge_flash(at: Vector2, flash_color: Color, radius: float, tier: int) -> void:
	var size_scale: float = _scale_for(BOKEH_TEXTURE, radius * 2.0)
	var tint: Color = flash_color.lerp(Color.WHITE, 0.55)
	tint.a = lerpf(0.55, 0.85, _tier_t(tier))
	_spawn_fx_sprite(at, BOKEH_TEXTURE, tint, size_scale * 0.6,
		size_scale * lerpf(1.6, 2.1, _tier_t(tier)), MERGE_FLASH_TIME)


## Tier 8: altin parilti yildizi donerek acilir — premium kutlama, guc
## efektlerinden ayri (sparkle dokusu, halka yok).
func _play_king_shine(at: Vector2) -> void:
	var gold := Color(1.0, 0.9, 0.55, 0.95)
	var base: float = _scale_for(SPARKLE_TEXTURE, TierConfig.radius(TierConfig.MAX_TIER) * 3.2)
	var shine: Sprite2D = _spawn_fx_sprite(at, SPARKLE_TEXTURE, gold, base * 0.3, base, 0.55,
		0.0, 0.35)
	var spin := create_tween()
	spin.tween_property(shine, "rotation", 0.9, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Ikinci, gecikmeli ve capraz: tek yildiz duz durunca "ikon" gibi kaliyordu.
	get_tree().create_timer(0.08).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var second: Sprite2D = _spawn_fx_sprite(at, SPARKLE_TEXTURE,
			Color(1.0, 1.0, 1.0, 0.8), base * 0.2, base * 0.8, 0.45, 0.78, 0.3)
		var spin2 := create_tween()
		spin2.tween_property(second, "rotation", 0.78 - 0.7, 0.45))


## Birlesme noktasinda ucan "+N" (dunya uzayinda, HUD pop'undan ayri).
func _spawn_float_score(at: Vector2, amount: int, tint: Color) -> void:
	var label := Label.new()
	UiType.apply(label, UiType.CARD_TITLE)
	label.text = "+%d" % amount
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", tint.lerp(Color.WHITE, 0.7))
	label.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.1, 0.8))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 2)
	label.z_index = 6
	label.position = at + Vector2(-40.0, -TierConfig.radius(2) - 30.0)
	label.size = Vector2(80.0, 32.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.6, 0.6)
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 46.0, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)


## Anlamli inis: parcanin alt kenarinda kucuk toz pufu. Yerlesmis yigin
## bunu tetiklemez (Dumpling.LAND_PUFF_SPEED esigi + debounce).
func _on_impact_landed(dumpling: Dumpling, speed: float) -> void:
	if _is_finished or not is_instance_valid(dumpling):
		return
	var r: float = TierConfig.radius(dumpling.tier)
	var t: float = clampf((speed - Dumpling.LAND_PUFF_SPEED) / 500.0, 0.0, 1.0)
	var count: int = mini(PUFF_MAX, 3 + int(round(3.0 * t)))
	_spawn_burst(dumpling.global_position + Vector2(0.0, r * 0.8), PUFF_TEXTURE,
		Color(1.0, 0.95, 0.9, lerpf(0.35, 0.6, t)), count,
		lerpf(70.0, 140.0, t) * clampf(r / 40.0, 0.7, 1.6), 0.15, 0.28)


## Hedef tamam: durum yazisi pop + kabin agzindan yukari parilti yagmuru
## (tek atis, 22 parcacik) + kisa hafif sarsinti. Sonuc ekrani main.gd'de
## RESULT_DELAY (0.8 sn) sonra aciliyor; bu pencere okunabilir bir basari ani.
## Durum degismiyor: _is_finished zaten set, girdi zaten kapali.
func _play_goal_celebration() -> void:
	_status_label.pivot_offset = _status_label.size * 0.5
	_status_label.scale = Vector2(0.6, 0.6)
	var tween := create_tween()
	tween.tween_property(_status_label, "scale", Vector2(1.15, 1.15), 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_status_label, "scale", Vector2.ONE, 0.14)
	var at := Vector2(_center_x(), container_top_y() + 40.0)
	_spawn_burst(at, SPARKLE_TEXTURE, Color(1.0, 0.92, 0.6, 0.95), 22, 420.0, 0.85, 0.9)
	_spawn_burst(at, BOKEH_TEXTURE, Color(1.0, 0.75, 0.9, 0.7), 14, 300.0, 0.7, 0.7)
	_shake_strength = maxf(_shake_strength, 5.0)


# --- Hedef, süre, taşma ---

## Hedef tier'a ulaşmak yetmez; level 10'da ayrıca skor hedefi var, o yüzden
## her merge'den sonra iki koşul birlikte kontrol ediliyor.
func _check_objective() -> void:
	if _is_finished or level.is_endless:
		return
	if not _reached_target_tier:
		return
	if level.has_score_target() and GameState.score < level.target_score:
		return
	_finish(true)


## Sarsıntı ve danger nabzı görsel; fizik adımına değil kareye bağlılar.
func _process(delta: float) -> void:
	if _shake_strength > 0.0:
		_shake_strength = maxf(0.0, _shake_strength - SHAKE_DECAY * delta)
		# M8.5-11: kamera sarsintisi artik GLOBAL RNG'yi tuketmiyor. Eskiden
		# randf_range drop_bag'in shuffle'iyla ayni akisi paylasiyordu ve
		# bot_runner'i tekrarlanamaz kiliyordu (PROJECT_STATUS §7 #14).
		# Gorsel rastgelelik `_fx_rng`den — gameplay RNG'ye dokunulmuyor.
		_camera.offset = Vector2(
			_fx_rng.randf_range(-_shake_strength, _shake_strength),
			_fx_rng.randf_range(-_shake_strength, _shake_strength))
		if _shake_strength == 0.0:
			_camera.offset = Vector2.ZERO

	if _shake_flash > 0.0:
		_shake_flash = maxf(0.0, _shake_flash - SHAKE_FLASH_DECAY * delta)
		queue_redraw()

	if _overflow_elapsed > 0.0 and not _is_finished:
		# Nabiz hizi tasma sayaci doldukca artar (~1.9 Hz -> ~4.5 Hz): ses
		# kapaliyken de "sure bitiyor" okunur. Mekanik (OVERFLOW_GRACE) ayni.
		var urgency: float = clampf(_overflow_elapsed / OVERFLOW_GRACE, 0.0, 1.0)
		_danger_phase += delta * TAU * lerpf(1.9, 4.5, urgency)
		_danger_pulse = 0.5 + 0.5 * sin(_danger_phase)
		_danger_urgency = urgency
		queue_redraw()
	elif _danger_pulse != 0.0:
		_danger_pulse = 0.0
		_danger_urgency = 0.0
		_danger_phase = 0.0
		queue_redraw()


func _physics_process(delta: float) -> void:
	# Devam teklifi açıkken oyun ZAMANI durur: drop cooldown, combo penceresi
	# ve taşma sayacı hiç ilerlemez. Reklam 40 sn açık kalsa bile board
	# oyuncunun bıraktığı yerde bulunur.
	if _is_paused():
		return

	if _drop_cooldown > 0.0:
		_drop_cooldown = maxf(0.0, _drop_cooldown - delta)
		if _drop_cooldown == 0.0:
			_refresh_preview()

	_tick_combo(delta)

	if _is_finished:
		return

	# Koruma pencereleri: sarsıntı (GAME_DESIGN.md §10.5) ve devam sonrası
	# (§11). İkisi de taşma sayacını dondurur, ikisi de STACK ETMEZ; aynı anda
	# açık olabilirler, o yüzden ikisi de ayrı ayrı eritiliyor.
	if _shake_protection > 0.0 or _revive_protection > 0.0:
		_shake_protection = maxf(0.0, _shake_protection - delta)
		_revive_protection = maxf(0.0, _revive_protection - delta)
		_overflow_elapsed = 0.0
		_danger_tick = 0.0
		return

	if _is_overflowing():
		_overflow_elapsed += delta
		# Gerilim sesi (GAME_DESIGN.md §6): tehlike sürdükçe tekrar eder.
		_danger_tick -= delta
		if _danger_tick <= 0.0:
			AudioManager.play_sfx(&"danger", 1.0)
			_danger_tick = DANGER_TICK_INTERVAL
		if _overflow_elapsed >= OVERFLOW_GRACE:
			_trigger_overflow_fail()
	else:
		_overflow_elapsed = 0.0
		_danger_tick = 0.0


func _is_overflowing() -> bool:
	for body in _overflow_area.get_overlapping_bodies():
		var dumpling := body as Dumpling
		if dumpling != null and dumpling.has_landed and not dumpling.is_merging:
			return true
	return false


# --- Stok 0 refill duraklaması (GAME_DESIGN.md §5.7.3) ---
#
# Refill penceresi açıkken oyun DURUR. Bu kozmetik bir tercih değil:
# ödüllü reklam 20-40 sn açık kalabiliyor ve board arka planda oynamaya
# devam etseydi oyuncu reklam izlerken taşıp round'u kaybederdi.
#
# Fail-pending ile AYNI dondurma makinesini kullanıyor ama farkı önemli:
# round BİTMİYOR, hiçbir sinyal round'u finalize etmiyor. Pencere kapanınca
# oyun tam kaldığı yerden devam ediyor.

## Oyun herhangi bir overlay yüzünden durmuş mu?
func _is_paused() -> bool:
	return _is_fail_pending or _is_refill_pending


func is_refill_pending() -> bool:
	return _is_refill_pending


## Stok 0 iken güç butonuna basıldı: oyunu dondur ve pencereyi iste.
func _enter_refill_pending(type: PowerUp.Type) -> void:
	if _is_refill_pending or _is_fail_pending or _is_finished:
		return
	_is_refill_pending = true
	_preview.visible = false
	_powerups.set_round_active(false)
	_clear_target_highlights()
	_power_bar.set_enabled(false)
	_set_board_frozen(true)
	power_refill_offered.emit(int(type))


## Pencere kapandı (kapatıldı, satın alındı ya da vazgeçildi): oyunu
## kaldığı yerden sürdür.
##
## `resume_intent`: refill başarılıysa oyuncunun ilk niyetine dönülür.
## HEDEFLİ güçlerde hedefleme yeniden açılır — bu tamamen geri
## alınabilir, stok tüketmez. ANINDA çalışan güçlerde (Sarsıntı /
## Temizleyici) bilerek OTOMATİK ÇALIŞTIRILMIYOR: pencereden çıkar
## çıkmaz gücün kendiliğinden harcanması "yanlışlıkla harcama" olurdu.
## Stok geldi, çubuk güncellendi, oyuncu bir kez daha basar.
func exit_refill_pending(resume_intent: bool = false) -> void:
	if not _is_refill_pending:
		return
	_is_refill_pending = false
	_set_board_frozen(false)
	_powerups.set_round_active(true)
	_power_bar.set_enabled(true)
	_refresh_power_bar()
	_preview.visible = true
	_refresh_preview()

	if not resume_intent:
		return
	var type: PowerUp.Type = _refill_type
	if SaveManager.has_powerup(type) and PowerUp.is_targeted(type):
		_powerups.request(type)


# --- Devam etme (revive) akışı — GAME_DESIGN.md §11 ---
#
# Taşma dolduğunda round ARTIK doğrudan bitmiyor. Üç ayrı kavram var:
#
#   1. fail candidate  -> _trigger_overflow_fail()  (hak varsa teklif açılır)
#   2. revive granted  -> grant_revive()            (yalnız reward callback'i)
#   3. final loss      -> _finish(false)            (tek sefer, tek yerden)
#
# round_finished(false) YALNIZCA 3'te yayılır. Teklif açıkken ne teselli
# ödülü, ne merge muhasebesi, ne sonuç ekranı çalışır — bunların hepsi
# main.gd'de round_finished'a bağlı.

func max_revives() -> int:
	return MAX_REVIVES_PER_ROUND


func revives_used() -> int:
	return _revives_used


func revives_remaining() -> int:
	return maxi(0, MAX_REVIVES_PER_ROUND - _revives_used)


func is_fail_pending() -> bool:
	return _is_fail_pending


## Taşma grace'i doldu. Hak varsa teklif, yoksa kesin kayıp.
func _trigger_overflow_fail() -> void:
	if _is_finished or _is_fail_pending:
		return
	if revives_remaining() <= 0:
		# Haklar bitti: normal final loss yolu, mevcut davranışın aynısı.
		_finish(false)
		return
	_enter_fail_pending()


## Board'u tamamen durdurup teklifi yayar. Bu noktadan sonra board'un state'i
## yalnızca grant_revive() veya decline_revive() ile değişir.
func _enter_fail_pending() -> void:
	_is_fail_pending = true
	_preview.visible = false
	# Hedefleme açıksa iptal olur, yeni güç silahlanamaz. Stok TÜKETİLMEZ.
	_powerups.set_round_active(false)
	_clear_target_highlights()
	_power_bar.set_enabled(false)
	# Zincir kesin koptu; donmuş board'un üstünde asılı bir "xN" kalmasın.
	_combo_count = 0
	_combo_timer = 0.0
	_set_combo_text("")
	_set_board_frozen(true)
	AudioManager.play_sfx(&"danger", 0.7)
	_status_label.text = "Taştı!"
	revive_offered.emit(revives_remaining())


## Devam hakkını GERÇEKTEN verir. Yalnızca ödül kazanıldığı doğrulandığında
## çağrılmalı (reklam kapandı callback'i DEĞİL — GAME_DESIGN.md §11).
##
## Dönüş: devam gerçekleştiyse true. Teklif açık değilse ya da hak kalmadıysa
## hiçbir şey yapmaz ve false döner — sayaç da artmaz.
func grant_revive() -> bool:
	if not _is_fail_pending or _is_finished:
		return false
	if revives_remaining() <= 0:
		return false

	_revives_used += 1
	_is_fail_pending = false

	var rescued: int = _rescue_overflow_dumplings()
	_set_board_frozen(false)

	# Taşma durumu tamamen sıfırlanıyor ve kısa koruma açılıyor: cleanup
	# sonrası yığının oturması için. STACK ETMEZ (atama, toplama değil).
	_overflow_elapsed = 0.0
	_danger_tick = 0.0
	_danger_pulse = 0.0
	_revive_protection = REVIVE_PROTECTION
	queue_redraw()

	# Girdi ve güçler geri geliyor; stoklar kaldığı yerden devam ediyor
	# (kurtarma temizliği Bomba/Temizleyici kullanımı SAYILMAZ).
	_powerups.set_round_active(true)
	_power_bar.set_enabled(true)
	_drop_cooldown = 0.0
	_preview.visible = true
	_refresh_preview()

	AudioManager.play_sfx(&"level_win", 1.15)
	_flash_status("Devam! %d parça kurtarıldı" % rescued)
	revive_granted.emit(_revives_used, revives_remaining())
	return true


## Oyuncu teklifi reddetti. Hak TÜKETİLMEZ; round kesin biter.
func decline_revive() -> void:
	if not _is_fail_pending:
		return
	_is_fail_pending = false
	_finish(false)


## Taşmaya sebep olan parçaları kaldırır ve kaldırılan sayısını döner.
##
## Ölçüt geometrik: parçanın ÜST KENARI taşma çizgisine ulaşmışsa (yani
## çizgiyi fiilen aşıyorsa) kaldırılır. OverflowArea 8 px'lik ince bir şerit
## olduğu için onun `get_overlapping_bodies()` listesi çizginin tam üstünde
## duran ama şeride değmeyen parçaları kaçırıyor; bu ölçüt onların üst
## kümesi ve "fail'in sebebi" tanımına birebir oturuyor.
##
## Çizginin GÜVENLİ ALTINDA kalan hiçbir parçaya dokunulmuyor — board
## temizlenmiyor, yalnızca tehlike bandı boşaltılıyor.
##
## Kaldırılan parçalar skor, merge sayacı ve bonus sandık ilerlemesi ÜRETMEZ
## (güçlerdeki kuralın aynısı, GAME_DESIGN.md §10.3).
func _rescue_overflow_dumplings() -> int:
	var line: float = overflow_line_y() + REVIVE_RESCUE_DEPTH
	var removed: int = 0
	for node in _dumpling_layer.get_children():
		var dumpling := node as Dumpling
		if dumpling == null or not is_instance_valid(dumpling):
			continue
		if dumpling.is_queued_for_deletion() or dumpling.is_merging:
			continue
		# Henüz inmemiş parça taşmaya sebep olmuyor (taşma kontrolü de
		# `has_landed` istiyor) — düşmeye devam etsin.
		if not dumpling.has_landed:
			continue
		if dumpling.global_position.y - TierConfig.radius(dumpling.tier) > line:
			continue
		_pop_and_free(dumpling)
		removed += 1
	# Kalanların uyandırılması çözülme adımında: set_simulation_frozen(false)
	# zaten `sleeping = false` yapıyor, donmuş gövdeye burada dokunmak
	# etkisiz olurdu.
	return removed


## Tüm canlı gövdeleri simülasyondan çıkarır/geri alır.
func _set_board_frozen(frozen: bool) -> void:
	for node in _dumpling_layer.get_children():
		var dumpling := node as Dumpling
		if dumpling != null and is_instance_valid(dumpling) \
				and not dumpling.is_queued_for_deletion():
			dumpling.set_simulation_frozen(frozen)


func _finish(won: bool) -> void:
	if _is_finished:
		return
	_is_finished = true
	# Bir overlay açıkken round bitmiş olabilir. Board donmuş kalmasın.
	_is_fail_pending = false
	_is_refill_pending = false
	_set_board_frozen(false)
	_preview.visible = false
	# Round bitti: hiçbir güç silahlanamaz, silahlı olan iptal olur.
	_powerups.set_round_active(false)
	_clear_target_highlights()
	_power_bar.set_enabled(false)
	_set_combo_text("")
	_status_label.text = "Hedef tamam!" if won else "Bitti"
	AudioManager.play_sfx(&"level_win" if won else &"level_lose")
	if won:
		_play_goal_celebration()
	round_finished.emit(won)


## Skor sadece değişmesin, kazanılan miktar "+N" olarak yukarı doğru büyüyüp
## sönerek pop etsin (GAME_DESIGN.md §6'daki combo "xN" deseninin aynısı).
func _on_score_changed(new_score: int) -> void:
	_score_label.text = "Skor: %d" % new_score
	var delta: int = new_score - _prev_score
	_prev_score = new_score
	if delta <= 0:
		return

	_score_pop.text = "+%d" % delta
	_score_pop.pivot_offset = _score_pop.size * 0.5
	_score_pop.position = _score_pop_home
	_score_pop.modulate.a = 1.0
	_score_pop.scale = Vector2(0.6, 0.6)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_score_pop, "scale", Vector2(1.25, 1.25), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_score_pop, "position",
		_score_pop_home - Vector2(0.0, 34.0), 0.55).set_ease(Tween.EASE_OUT)
	tween.tween_property(_score_pop, "modulate:a", 0.0, 0.55).set_delay(0.15)

	# Skorun kendisi de hafifçe zıplasın — sayının değiştiği fark edilsin.
	var bump := create_tween()
	bump.tween_property(_score_label, "scale", Vector2(1.12, 1.12), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bump.tween_property(_score_label, "scale", Vector2.ONE, 0.12)

