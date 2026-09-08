extends Node2D
## Oyun tahtası: kap, drop kontrolü, merge çözümü, hedef/süre takibi ve
## taşma (fail) kontrolü. Geometri ve hedefler LevelData'dan gelir.

signal round_finished(won: bool)

const DUMPLING_SCENE: PackedScene = preload("res://scenes/game/dumpling.tscn")
const POP_EFFECT_SCENE: PackedScene = preload("res://scenes/game/pop_effect.tscn")
const BOKEH_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_dot.png")

const WALL_THICKNESS: float = 20.0
## Taşma çizgisine bu süre boyunca temas edilirse round biter (GAME_DESIGN.md §1).
const OVERFLOW_GRACE: float = 1.5
const DROP_COOLDOWN: float = 0.4

## Combo: bu süre içinde art arda gelen merge'ler zincir sayılır
## (GAME_DESIGN.md §6). Zincir 2'ye ulaşınca combo sesi ve "xN" yazısı.
const COMBO_WINDOW: float = 1.2
## Taşma tehlikesindeyken gerilim sesinin tekrar aralığı.
const DANGER_TICK_INTERVAL: float = 0.5

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
## Skor pop'u için: değişimin miktarını göstermek gerekiyor, sadece yeni
## toplamı değil.
var _prev_score: int = 0
## Skor pop'unun sahnede tanımlı yuvası — animasyon her seferinde buradan
## başlar. Skor metninden türetilmiyor çünkü metnin genişliği değişiyor.
var _score_pop_home: Vector2 = Vector2.ZERO

@onready var _walls: StaticBody2D = $Walls
@onready var _dumpling_layer: Node2D = $DumplingLayer
@onready var _overflow_area: Area2D = $OverflowArea
@onready var _overflow_shape: CollisionShape2D = $OverflowArea/OverflowShape
@onready var _preview: Node2D = $Preview
@onready var _score_label: Label = $HUD/ScoreLabel
@onready var _next_label: Label = $HUD/NextLabel
@onready var _objective_label: Label = $HUD/ObjectiveLabel
@onready var _status_label: Label = $HUD/StatusLabel
@onready var _combo_label: Label = $HUD/ComboLabel
@onready var _score_pop: Label = $HUD/ScorePop
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
	_pending_tier = TierConfig.random_drop_tier()
	_next_tier = TierConfig.random_drop_tier()
	_refresh_preview()
	_on_score_changed(GameState.score)
	_objective_label.text = "%s — %s" % [level.display_name(), level.objective_text()]
	_status_label.text = ""
	_combo_label.text = ""
	_score_pop.text = ""
	_score_pop.modulate.a = 0.0
	_score_pop_home = _score_pop.position
	_prev_score = GameState.score
	_score_label.pivot_offset = Vector2(0.0, _score_label.size.y * 0.5)


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
	draw_dashed_line(Vector2(_left_x(), overflow_line_y()),
		Vector2(_right_x(), overflow_line_y()), Color(1.0, 0.35, 0.35, 0.55), 2.0, 12.0)
	_draw_danger()


## Taşma tehlikesindeyken kap kenarında kırmızı titreşen highlight
## (GAME_DESIGN.md §6). Sesi zaten M6'da eklenmişti, görseli M8'e kalmıştı.
func _draw_danger() -> void:
	if _danger_pulse <= 0.0:
		return
	var alpha: float = 0.25 + 0.45 * _danger_pulse
	var glow := Color(1.0, 0.25, 0.3, alpha)
	var top: float = container_top_y()
	var height: float = FLOOR_Y - top
	# Duvarların kendisi kırmızıya boyanıyor + çizginin altına bir bant.
	draw_rect(Rect2(_left_x() - WALL_THICKNESS, top, WALL_THICKNESS, height), glow)
	draw_rect(Rect2(_right_x(), top, WALL_THICKNESS, height), glow)
	var band: float = 70.0
	draw_rect(Rect2(_left_x(), overflow_line_y(), level.container_width, band),
		Color(1.0, 0.25, 0.3, alpha * 0.22))
	draw_line(Vector2(_left_x(), overflow_line_y()),
		Vector2(_right_x(), overflow_line_y()), Color(1.0, 0.3, 0.35, alpha), 4.0)


# --- Girdi: parmağı sürükle, bırakınca düşür (GAME_DESIGN.md §1) ---

func _unhandled_input(event: InputEvent) -> void:
	if _is_finished:
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
	_spawn_dumpling(_pending_tier, Vector2(_aim_x, drop_line_y()))
	_pending_tier = _next_tier
	_next_tier = TierConfig.random_drop_tier()
	_drop_cooldown = DROP_COOLDOWN
	_set_aim(_aim_x)


func _spawn_dumpling(tier: int, at: Vector2) -> Dumpling:
	var dumpling: Dumpling = DUMPLING_SCENE.instantiate()
	dumpling.setup(tier)
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


## Art arda gelen merge'leri zincirler. Tek merge combo sayılmaz.
func _register_combo() -> void:
	_combo_count += 1
	_combo_timer = COMBO_WINDOW
	if _combo_count < 2:
		return
	AudioManager.play_sfx(&"combo", 1.0 + 0.06 * float(mini(_combo_count, 8)))
	_combo_label.text = "x%d" % _combo_count
	# Zincir uzadıkça yazı büyüsün (GAME_DESIGN.md §6).
	var peak: float = minf(1.3 + 0.12 * float(_combo_count), 2.2)
	var tween := create_tween()
	tween.tween_property(_combo_label, "scale", Vector2(peak, peak), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.15)


func _tick_combo(delta: float) -> void:
	if _combo_timer <= 0.0:
		return
	_combo_timer -= delta
	if _combo_timer <= 0.0:
		_combo_count = 0
		_combo_label.text = ""


func _spawn_pop(at: Vector2, pop_color: Color, radius: float, tier: int) -> void:
	var effect: Node2D = POP_EFFECT_SCENE.instantiate()
	effect.position = at
	add_child(effect)
	effect.burst(pop_color, radius, tier)


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
	_combo_label.text = ""
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

