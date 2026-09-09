extends Node2D
## Oyun tahtası: kap, drop kontrolü, merge çözümü, hedef/süre takibi ve
## taşma (fail) kontrolü. Geometri ve hedefler LevelData'dan gelir.

signal round_finished(won: bool)

const DUMPLING_SCENE: PackedScene = preload("res://scenes/game/dumpling.tscn")
const POP_EFFECT_SCENE: PackedScene = preload("res://scenes/game/pop_effect.tscn")
const BOKEH_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_dot.png")
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
const DANGER_STRIPE_ALPHA_IDLE: float = 0.55
const DANGER_STRIPE_ALPHA_MAX: float = 1.0

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

## Sürükle-bırak ipucunun gösterildiği level. Yalnızca ilk level'da, ilk
## bırakışa kadar. Bkz. _setup_tutorial().
const TUTORIAL_LEVEL: int = 1
const TUTORIAL_SIZE: Vector2 = Vector2(360.0, 220.0)
## İpucu kabın ağzı ile taşma çizgisi arasında, bu oranda aşağıda duruyor.
const TUTORIAL_Y_RATIO: float = 0.42

## Ekran sarsıntısı (M8 juice): merge'in tier'ına göre ölçekleniyor.
## Küçük merge'de neredeyse hissedilmiyor, tier 8'de belirgin.
const SHAKE_MIN: float = 1.5
const SHAKE_MAX: float = 16.0
## Sarsıntı saniyede bu oranda sönümleniyor (yüksek = daha kısa/keskin).
const SHAKE_DECAY: float = 9.0

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
var _shake_strength: float = 0.0
## Danger highlight'ının nabzı (GAME_DESIGN.md §6) — 0..1 arası salınır.
var _danger_pulse: float = 0.0
## İpucu bir kez kapandıktan sonra tekrar açılmasın (fade tween'i sırasında
## ikinci bir bırakış gelirse iki tween çakışırdı).
var _tutorial_dismissed: bool = false
## Sarsıntı sonrası taşma koruması kalan süre (sn). >0 iken taşma birikmiyor.
var _shake_protection: float = 0.0
## Sarsıntının rastgeleliği; testlerde sabitlenebilsin diye ayrı bir üreteç.
var _shake_rng := RandomNumberGenerator.new()
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


func _draw() -> void:
	if level == null:
		return
	var wall_color := Color("6b5a52")
	var top: float = container_top_y()
	var height: float = FLOOR_Y - top
	draw_rect(Rect2(_left_x() - WALL_THICKNESS, top, WALL_THICKNESS, height), wall_color)
	draw_rect(Rect2(_right_x(), top, WALL_THICKNESS, height), wall_color)
	draw_rect(Rect2(_left_x() - WALL_THICKNESS, FLOOR_Y,
		level.container_width + WALL_THICKNESS * 2.0, WALL_THICKNESS), wall_color)
	_draw_overflow_stripe()
	_draw_danger()


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
	# Şerit çizginin ÜSTÜNE ortalanıyor: fail çizgisi şeridin ortasından
	# geçsin, oyuncu bandın neresinin ölümcül olduğunu görsün.
	draw_texture_rect(DANGER_STRIPE_TEXTURE,
		Rect2(_left_x(), overflow_line_y() - height * 0.5, width, height),
		false, Color(1, 1, 1, alpha))


## Taşma tehlikesindeyken kap kenarında kırmızı titreşen highlight
## (GAME_DESIGN.md §6). Sesi zaten M6'da eklenmişti, görseli M8'e kalmıştı.
## Şeridin kendi parlaması _draw_overflow_stripe'ta; burada duvarlar.
func _draw_danger() -> void:
	if _danger_pulse <= 0.0:
		return
	var alpha: float = 0.25 + 0.45 * _danger_pulse
	var glow := Color(1.0, 0.25, 0.3, alpha)
	var top: float = container_top_y()
	var height: float = FLOOR_Y - top
	# Duvarların kendisi kırmızıya boyanıyor.
	draw_rect(Rect2(_left_x() - WALL_THICKNESS, top, WALL_THICKNESS, height), glow)
	draw_rect(Rect2(_right_x(), top, WALL_THICKNESS, height), glow)


# --- Girdi: parmağı sürükle, bırakınca düşür (GAME_DESIGN.md §1) ---
#
# Bir güç silahlıyken normal drop AKIŞI TAMAMEN DEVRE DIŞI: dokunuş hedef
# seçimi olarak yorumlanıyor, boşluğa dokunmak iptal ediyor.

func _unhandled_input(event: InputEvent) -> void:
	if _is_finished:
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
	if _is_finished:
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


func _on_power_refill_requested(type_index: int) -> void:
	var type: PowerUp.Type = type_index as PowerUp.Type
	# Monetization kancası — bu turda hiçbir şey vermiyoruz (GAME_DESIGN §10).
	_flash_status("%s bitti" % PowerUp.display_name(type))


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
## Patlama KOMŞULARI ETKİLEMEZ, tek hedefliktir.
## ⚠️ Bomba görseli placeholder (fx_dot yeniden kullanılıyor), final art yok.
func _run_bomb(target: Dumpling) -> void:
	var destination: Vector2 = target.global_position
	target.play_lock_on()

	var shell := Sprite2D.new()
	shell.texture = BOKEH_TEXTURE
	shell.modulate = Color(0.15, 0.12, 0.18)
	shell.scale = Vector2.ONE * 0.35
	shell.position = Vector2(destination.x, container_top_y() - 60.0)
	add_child(shell)

	var tween := create_tween()
	tween.tween_property(shell, "position", destination, BOMB_TRAVEL) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		shell.queue_free()
		_detonate_bomb(target, destination))


func _detonate_bomb(target: Dumpling, at: Vector2) -> void:
	var tier: int = target.tier if is_instance_valid(target) else 1
	if is_instance_valid(target):
		target.queue_free()
	# Skor ve merge sayacı DEĞİŞMEZ (GAME_DESIGN.md §10).
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
	var new_tier: int = target.tier + 1
	var at: Vector2 = target.global_position
	var velocity: Vector2 = target.linear_velocity
	target.queue_free()

	var upgraded := _spawn_dumpling(new_tier, at)
	upgraded.linear_velocity = velocity
	upgraded.play_squash()

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
	for index in targets.size():
		var dumpling: Dumpling = targets[index]
		# Kademeli pop: tek karede hepsini silmek sert görünüyor.
		var delay: float = float(index) * CLEAR_STAGGER
		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(func() -> void: _pop_and_free(dumpling))
	_flash_status("%d parça temizlendi" % targets.size())


func _pop_and_free(dumpling: Dumpling) -> void:
	if not is_instance_valid(dumpling) or dumpling.is_queued_for_deletion():
		return
	var tier: int = dumpling.tier
	var at: Vector2 = dumpling.global_position
	dumpling.queue_free()
	# Skor ve merge sayacı DEĞİŞMEZ.
	_spawn_pop(at, TierConfig.color(tier), TierConfig.radius(tier), 2)


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
	if _drop_cooldown > 0.0:
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
	_dumpling_layer.add_child(dumpling)
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
	a.queue_free()
	b.queue_free()

	var merged := _spawn_dumpling(new_tier, point)
	merged.play_squash()

	var celebratory: bool = new_tier == TierConfig.MAX_TIER
	_spawn_pop(point, TierConfig.color(new_tier), TierConfig.radius(new_tier), new_tier)
	_add_shake(new_tier)

	GameState.add_score(TierConfig.merge_score(new_tier))
	GameState.register_merge(new_tier, point)
	# Tek sample, tier başına artan pitch (GAME_DESIGN.md §6).
	AudioManager.play_sfx(&"merge", TierConfig.merge_pitch(new_tier))
	_register_combo()

	if celebratory:
		_flash_status("%s!" % TierConfig.tier_name(new_tier))

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


## Combo yazisi ve arkasindaki rozet birlikte acilip kapaniyor — metin bosken
## ekranda oylece duran bir rozet kalmasin.
func _set_combo_text(text: String) -> void:
	_combo_label.text = text
	_combo_badge.visible = not text.is_empty()


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
	var t: float = clampf(float(tier - 2) / float(TierConfig.MAX_TIER - 2), 0.0, 1.0)
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
		_camera.offset = Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength))
		if _shake_strength == 0.0:
			_camera.offset = Vector2.ZERO

	if _overflow_elapsed > 0.0 and not _is_finished:
		_danger_pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		queue_redraw()
	elif _danger_pulse != 0.0:
		_danger_pulse = 0.0
		queue_redraw()


func _physics_process(delta: float) -> void:
	if _drop_cooldown > 0.0:
		_drop_cooldown = maxf(0.0, _drop_cooldown - delta)
		if _drop_cooldown == 0.0:
			_refresh_preview()

	_tick_combo(delta)

	if _is_finished:
		return

	var overflowing: bool = false
	for body in _overflow_area.get_overlapping_bodies():
		var dumpling := body as Dumpling
		if dumpling != null and dumpling.has_landed and not dumpling.is_merging:
			overflowing = true
			break

	# Sarsıntı koruması: pencere boyunca taşma birikmiyor. Bitince normal
	# OVERFLOW_GRACE kuralı aynen geri dönüyor (GAME_DESIGN.md §10).
	if _shake_protection > 0.0:
		_shake_protection = maxf(0.0, _shake_protection - delta)
		_overflow_elapsed = 0.0
		_danger_tick = 0.0
		return

	if overflowing:
		_overflow_elapsed += delta
		# Gerilim sesi (GAME_DESIGN.md §6): tehlike sürdükçe tekrar eder.
		_danger_tick -= delta
		if _danger_tick <= 0.0:
			AudioManager.play_sfx(&"danger", 1.0)
			_danger_tick = DANGER_TICK_INTERVAL
		if _overflow_elapsed >= OVERFLOW_GRACE:
			_finish(false)
	else:
		_overflow_elapsed = 0.0
		_danger_tick = 0.0


func _finish(won: bool) -> void:
	if _is_finished:
		return
	_is_finished = true
	_preview.visible = false
	# Round bitti: hiçbir güç silahlanamaz, silahlı olan iptal olur.
	_powerups.set_round_active(false)
	_clear_target_highlights()
	_set_combo_text("")
	_status_label.text = "Hedef tamam!" if won else "Bitti"
	AudioManager.play_sfx(&"level_win" if won else &"level_lose")
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

