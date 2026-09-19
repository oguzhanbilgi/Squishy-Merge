extends Node
## M8.7-02 — merge / güç efekt dili davranış testi. Headless. Güç tüketimi
## SaveManager.save_game çağırdığı için kayıt dosyasının BAŞLANGIÇ BYTE'LARI
## çıkışta geri yazılır (harness ile aynı sözleşme); bellek verisi de geri konur.
##
##   godot --headless --audio-driver Dummy --path . res://tools/gameplay_feedback_test.tscn
##
## Ekran görüntüsü değil DAVRANIŞ doğrular:
##   MERGE      skor tablosu ve merge skoru kanonik, tek doğan parça, doğru tier,
##              "+N" etiketi DOĞAN tier'ın yarıçapına göre yüzün üstünde
##   ZİNCİR     zincir skorları aynı, etiketler deterministik ve çakışmasız
##              (dikey kat / yana kayma), etiketler kendini temizler
##   FX ROLÜ    gameplay parıltı/halka/nokta rolleri doğru dokuya bağlı,
##              ışık dokuları toplamsal materyalde, RewardGem DEĞİŞMEDİ
##   BÜYÜTÜCÜ   stok bir kez düşer, hedef bir kez yükselir, skor yok,
##              anticipation penceresinde hedef kilitli / ikinci işlem yok,
##              T7→T8 kral parıltısı + SPECIAL titreşim, hedef takibi çalışır
##   KAZANMA    round_finished tam bir kez, kutlama çapası kazandıran olayda,
##              çapa yoksa yığın tepesi; tekrar tetik kopya üretmez
##   TİTREŞİM   mevcut eşleme aynen (LIGHT/MEDIUM/SPECIAL/STRONG)
##   TEMİZLİK   T8 merge + zincir + Büyütücü sonrası geçici düğüm kalmaz

const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const GAME_BOARD_SCRIPT: GDScript = preload("res://scripts/game/game_board.gd")
const POP_EFFECT: GDScript = preload("res://scripts/game/pop_effect.gd")
const REWARD_GEM: GDScript = preload("res://scripts/ui/reward_gem.gd")
const LIGHT_MATERIAL: CanvasItemMaterial = preload("res://assets/visual/fx/fx_light_additive.tres")
const CANONICAL_SCORES: Array[int] = [0, 50, 70, 90, 110, 130, 150, 200]

var _board: Node2D
var _saved: Dictionary = {}
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _passed: int = 0
var _failed: int = 0
var _finished: Array[bool] = []
var _haptics: Array[Dictionary] = []


func _ready() -> void:
	await get_tree().process_frame
	_saved = SaveManager.data.duplicate(true)
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	Haptics.set_sink(_on_haptic, true)
	Haptics.reset_counters()

	await _test_fx_roles()
	await _test_merge()
	await _test_chain_labels()
	await _test_shake_ring()
	await _test_upgrade()
	await _test_upgrade_t8_parity()
	await _test_upgrade_objective()
	await _test_win_anchor()
	await _test_cleanup()

	await _teardown()
	SaveManager.data = _saved
	_restore_save()
	Haptics.set_sink(Callable(), false)
	print("")
	print("=== SONUC: %d gecti / %d kaldi ===" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- yardımcılar ---------------------------------------------------------------

## Kayıt dosyasını başlangıçtaki byte'larıyla geri yazar.
func _restore_save() -> void:
	if _had_save:
		var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_save_bytes)
			file.close()
	elif FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	var same: bool = not _had_save or FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == _save_bytes
	print("kayıt geri kondu: %s" % ("byte-identical" if same else "FARKLI"))


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("  [OK]   ", label)
	else:
		_failed += 1
		printerr("  [FAIL] ", label)


func _check_eq(label: String, actual: Variant, expected: Variant) -> void:
	_check("%s (beklenen %s, gelen %s)" % [label, expected, actual], actual == expected)


func _section(title: String) -> void:
	print("")
	print("--- ", title, " ---")


func _on_haptic(duration_ms: int, amplitude: float) -> void:
	_haptics.append({"ms": duration_ms, "amp": amplitude, "t": Time.get_ticks_msec()})


func _make_board(level: int, stock: int = 3) -> void:
	await _teardown()
	GameState.reset_run()
	var data: Dictionary = {}
	for type in PowerUp.all():
		data[PowerUp.save_key(type)] = stock
	SaveManager.data["powerups"] = data
	SaveManager.data["equipped_skin"] = ""
	_finished.clear()
	_haptics.clear()
	Haptics.reset_counters()
	var path: String = "res://resources/levels/endless.tres" if level == 0 \
		else "res://resources/levels/level_%02d.tres" % level
	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(load(path))
	_board.round_finished.connect(func(won: bool) -> void: _finished.append(won))
	add_child(_board)
	await get_tree().process_frame
	_board._dismiss_tutorial()
	await get_tree().process_frame


func _teardown() -> void:
	if _board != null and is_instance_valid(_board):
		_board.queue_free()
		_board = null
		await get_tree().process_frame
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _spawn(tier: int, at: Vector2) -> Dumpling:
	return _board._spawn_dumpling(tier, at)


func _pieces() -> Array[Dumpling]:
	var out: Array[Dumpling] = []
	for child in _board._dumpling_layer.get_children():
		var d := child as Dumpling
		if d != null and is_instance_valid(d) and not d.is_queued_for_deletion():
			out.append(d)
	return out


func _tiers() -> Array[int]:
	var out: Array[int] = []
	for d in _pieces():
		out.append(d.tier)
	out.sort()
	return out


## Board'un çocuğu geçici efekt düğümleri (bokeh hariç).
func _fx(kind: String) -> Array:
	var out: Array = []
	for child in _board.get_children():
		if child == _board._bokeh:
			continue
		match kind:
			"sprite":
				if child is Sprite2D:
					out.append(child)
			"label":
				if child is Label:
					out.append(child)
			"particles":
				if child is CPUParticles2D:
					out.append(child)
			"pop":
				if child.get_script() == POP_EFFECT:
					out.append(child)
	return out


func _sprites_with(texture: Texture2D) -> Array:
	var out: Array = []
	for s in _fx("sprite"):
		if (s as Sprite2D).texture == texture:
			out.append(s)
	return out


static func _label_rect(l: Label) -> Rect2:
	var size: Vector2 = l.size * l.scale
	var center: Vector2 = l.position + l.size * 0.5
	return Rect2(center - size * 0.5, size)


## İki yerleşik parça: `rest` tabanda, `falling` üstüne düşer; merge karesini bekler.
func _merge_pair(tier: int, x: float) -> Dictionary:
	var r: float = TierConfig.radius(tier)
	_spawn(tier, Vector2(x - r * 0.5, _board.FLOOR_Y - r - 6.0))
	await _frames(40)
	var score_before: int = GameState.score
	var merges_before: int = GameState.merge_count
	_spawn(tier, Vector2(x - r * 0.5 + r * 0.55, _board.FLOOR_Y - r - 220.0))
	var point: Array = [Vector2.INF]
	var cb := func(_t: int, p: Vector2) -> void: point[0] = p
	GameState.merge_performed.connect(cb)
	for i in 240:
		await get_tree().physics_frame
		if point[0] != Vector2.INF:
			break
	GameState.merge_performed.disconnect(cb)
	return {"point": point[0], "score_delta": GameState.score - score_before,
		"merges_delta": GameState.merge_count - merges_before}


func _last_piece() -> Dumpling:
	var list: Array[Dumpling] = _pieces()
	return list[list.size() - 1] if not list.is_empty() else null


# --- 1) FX rolleri -----------------------------------------------------------------

func _test_fx_roles() -> void:
	_section("FX dokusu rolleri (gameplay) ve RewardGem izolasyonu")
	var board_script: GDScript = GAME_BOARD_SCRIPT
	var consts: Dictionary = board_script.get_script_constant_map()
	_check("GameBoard.GLOW_TEXTURE (dolu parıltı rolü) = fx_ring.png",
		(consts["GLOW_TEXTURE"] as Texture2D).resource_path.ends_with("fx_ring.png"))
	_check("GameBoard.RING_TEXTURE (içi boş halka rolü) = fx_dot.png",
		(consts["RING_TEXTURE"] as Texture2D).resource_path.ends_with("fx_dot.png"))
	_check("GameBoard'da eski BOKEH_TEXTURE sabiti yok", not consts.has("BOKEH_TEXTURE"))
	_check("GameBoard.FX_LIGHT_MATERIAL toplamsal", (consts["FX_LIGHT_MATERIAL"] as CanvasItemMaterial).blend_mode
		== CanvasItemMaterial.BLEND_MODE_ADD)
	var pop_consts: Dictionary = POP_EFFECT.get_script_constant_map()
	_check("PopEffect.DOT_TEXTURE (dolu nokta rolü) = fx_ring.png",
		(pop_consts["DOT_TEXTURE"] as Texture2D).resource_path.ends_with("fx_ring.png"))
	_check("PopEffect.LIGHT_MATERIAL toplamsal",
		(pop_consts["LIGHT_MATERIAL"] as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD)
	# Görünür çap oranları ölçülen alfa profiliyle uyumlu (0.40 / 0.72).
	_check("GLOW_VISIBLE 0.40 / RING_VISIBLE 0.72", is_equal_approx(consts["GLOW_VISIBLE"], 0.40)
		and is_equal_approx(consts["RING_VISIBLE"], 0.72))
	_check("_ring_scale(144 px) → görünür halka 144 px",
		is_equal_approx(board_script._ring_scale(144.0) * 128.0 * 0.72, 144.0))
	_check("_glow_scale(100 px) → görünür parıltı 100 px",
		is_equal_approx(board_script._glow_scale(100.0) * 128.0 * 0.40, 100.0))
	# RewardGem: onaylı sonuç ekranı — sabitler ve kaynak dosya DEĞİŞMEDİ.
	var gem: Dictionary = REWARD_GEM.get_script_constant_map()
	_check("RewardGem.DOT_TEXTURE hâlâ fx_dot.png", (gem["DOT_TEXTURE"] as Texture2D).resource_path.ends_with("fx_dot.png"))
	_check("RewardGem.RING_TEXTURE hâlâ fx_ring.png", (gem["RING_TEXTURE"] as Texture2D).resource_path.ends_with("fx_ring.png"))
	_check("RewardGem.BURST_TEXTURE hâlâ fx_burst.png", (gem["BURST_TEXTURE"] as Texture2D).resource_path.ends_with("fx_burst.png"))
	var gem_src: String = FileAccess.get_file_as_string("res://scripts/ui/reward_gem.gd")
	_check("reward_gem.gd toplamsal materyal / GLOW_TEXTURE / ölçek düzeltmesi içermiyor",
		not gem_src.contains("fx_light_additive") and not gem_src.contains("GLOW_TEXTURE")
		and not gem_src.contains("CanvasItemMaterial") and not gem_src.contains("_VISIBLE"))
	var result_src: String = FileAccess.get_file_as_string("res://scripts/ui/round_result.gd")
	_check("round_result.gd toplamsal materyal içermiyor", not result_src.contains("fx_light_additive"))
	# PNG'ler dokunulmadı: içerik ölçümü (merkez alfa) denetimdeki gibi.
	var ring_img: Image = (consts["GLOW_TEXTURE"] as Texture2D).get_image()
	var dot_img: Image = (consts["RING_TEXTURE"] as Texture2D).get_image()
	_check("fx_ring.png hâlâ dolu (merkez α > 0.9), fx_dot.png hâlâ içi boş (merkez α = 0)",
		ring_img.get_pixel(64, 64).a > 0.9 and dot_img.get_pixel(64, 64).a == 0.0)
	_check("tools/make_fx_sprites.gd eşlemesi değişmedi (circle_01→fx_dot, circle_05→fx_ring)",
		FileAccess.get_file_as_string("res://tools/make_fx_sprites.gd").contains('"circle_01.png", "out": "fx_dot.png"'))


# --- 2) Merge -----------------------------------------------------------------------

func _test_merge() -> void:
	_section("Merge: skor, tier, tek parça, etiket çapası, parlama rolü")
	for tier in range(1, 9):
		_check_eq("merge_score(%d) kanonik" % tier, TierConfig.merge_score(tier), CANONICAL_SCORES[tier - 1])

	await _make_board(8)
	var cx: float = _board._center_x()
	# T3 + T3 → T4 (+90), dünya etiketi VAR (tier ≥ 4).
	var res: Dictionary = await _merge_pair(3, cx)
	_check("T3+T3 merge gerçekleşti", res["point"] != Vector2.INF)
	_check_eq("skor +90", res["score_delta"], 90)
	_check_eq("merge sayacı +1", res["merges_delta"], 1)
	_check_eq("tek doğan parça, tier 4", _tiers(), [4])
	var born: Dumpling = _last_piece()
	var labels: Array = _fx("label")
	_check_eq("tier 4: bir '+N' etiketi", labels.size(), 1)
	if labels.size() == 1:
		var l: Label = labels[0]
		_check_eq("etiket metni +90", l.text, "+90")
		var rect: Rect2 = _label_rect(l)
		var top: float = born.global_position.y - TierConfig.radius(4)
		var gap: float = top - rect.end.y
		_check("etiket alt kenarı doğan parçanın collider tepesinin ≥ 10 px üstünde (gap %.0f)" % gap, gap >= 10.0)
		_check("etiket parçanın üstünden ≤ 90 px yukarıda (gap %.0f)" % gap, gap <= 90.0)
		_check("etiket yatayda merge noktasına ortalı (Δx %.0f)" % absf(rect.get_center().x - res["point"].x),
			absf(rect.get_center().x - res["point"].x) <= 2.0)
		_check("etiket yüksekliği gerçek boyut (≥ 32)", l.size.y >= 32.0)
	# Flash: dolu parıltı dokusu + toplamsal materyal, z 5.
	var flashes: Array = _sprites_with(_board.GLOW_TEXTURE)
	_check("merge parlaması GLOW dokusuyla çizildi", flashes.size() >= 1)
	if flashes.size() >= 1:
		var f: Sprite2D = flashes[0]
		_check("parlama toplamsal materyalde, z 5", f.material == LIGHT_MATERIAL and f.z_index == 5)
		_check("parlama alfa 0.3–0.5 (pastel parçada beyaz patlamasın)", f.modulate.a > 0.25 and f.modulate.a < 0.5)
	_check("merge'de halka YOK (halka güç imzası)", _sprites_with(_board.RING_TEXTURE).is_empty())
	var pops: Array = _fx("pop")
	_check("PopEffect noktaları GLOW dokusu + toplamsal", pops.size() == 1
		and (pops[0].get_node("Dots") as CPUParticles2D).texture == _board.GLOW_TEXTURE
		and (pops[0].get_node("Dots") as CPUParticles2D).material == LIGHT_MATERIAL)
	_check("T4 merge titreşimi LIGHT (18 ms)", _haptics.size() == 1 and _haptics[0]["ms"] == 18)

	# T1 + T1 → T2: dünya etiketi YOK (FLOAT_SCORE_MIN_TIER 4), skor +50.
	await _make_board(8)
	res = await _merge_pair(1, cx)
	_check_eq("T1+T1 skor +50", res["score_delta"], 50)
	_check_eq("tier 2 doğdu", _tiers(), [2])
	_check("tier 2: dünya etiketi yok", _fx("label").is_empty())
	_check("tier 2 parlaması var (düşük tier görünür)", _sprites_with(_board.GLOW_TEXTURE).size() >= 1)

	# T7 + T7 → T8: +200, kral parıltısı, SPECIAL, tier_max sesi.
	await _make_board(8)
	var tier_max_before: int = int(AudioManager.play_count.get(&"tier_max", 0))
	res = await _merge_pair(7, cx)
	_check_eq("T7+T7 skor +200", res["score_delta"], 200)
	_check_eq("tier 8 doğdu", _tiers(), [8])
	_check("kral parıltısı: yıldız + patlama yıldızı sprite'ları", _sprites_with(_board.SPARKLE_TEXTURE).size() >= 1
		and _sprites_with(_board.BURST_TEXTURE).size() == 1)
	_check("kral parıltısı toplamsal", (_sprites_with(_board.SPARKLE_TEXTURE)[0] as Sprite2D).material == LIGHT_MATERIAL)
	_check_eq("tier_max sesi 1 kez", int(AudioManager.play_count.get(&"tier_max", 0)) - tier_max_before, 1)
	await _wait(0.2)
	_check("T8 merge titreşimi SPECIAL (35 + 60 ms)", _haptics.size() == 2 and _haptics[0]["ms"] == 35 and _haptics[1]["ms"] == 60)
	labels = _fx("label")
	if labels.size() == 1:
		var gap8: float = (_last_piece().global_position.y - 100.0) - _label_rect(labels[0]).end.y
		_check("T8: '+200' etiketi tacın üstünde (gap %.0f ≥ 20)" % gap8, gap8 >= 20.0)
	else:
		_check("T8: tek etiket", false)


# --- 3) Zincir etiketleri --------------------------------------------------------------

func _test_chain_labels() -> void:
	_section("Zincir: skor, etiket katları, yana kayma, determinizm, temizlik")
	await _make_board(9)
	var cx: float = _board._center_x()
	var at := Vector2(cx, _board.FLOOR_Y - 60.0)
	# Aynı noktada art arda üç etiket (x3 zincir aynı noktada çözülür).
	var l1: Label = _board._spawn_float_score(at, 90, Color.WHITE, TierConfig.radius(4))
	var l2: Label = _board._spawn_float_score(at, 110, Color.WHITE, TierConfig.radius(5))
	var l3: Label = _board._spawn_float_score(at, 130, Color.WHITE, TierConfig.radius(6))
	var r1: Rect2 = Rect2(l1.position, l1.size)
	var r2: Rect2 = Rect2(l2.position, l2.size)
	var r3: Rect2 = Rect2(l3.position, l3.size)
	_check("ikinci etiket birincinin üstünde, çakışmıyor", r2.end.y <= r1.position.y and not r2.intersects(r1))
	_check("üçüncü etiket ikincinin üstünde, çakışmıyor", r3.end.y <= r2.position.y and not r3.intersects(r2)
		and not r3.intersects(r1))
	_check("katlar kompakt (üçüncü ≤ 120 px yukarıda)", r1.position.y - r3.position.y <= 120.0)
	_check("etiketler yatayda aynı hizada", is_equal_approx(r1.position.x, r2.position.x) and is_equal_approx(r2.position.x, r3.position.x))
	var y_first: float = l2.position.y
	# Determinizm: aynı kurulum aynı konumu verir.
	await _make_board(9)
	_board._spawn_float_score(at, 90, Color.WHITE, TierConfig.radius(4))
	var l2b: Label = _board._spawn_float_score(at, 110, Color.WHITE, TierConfig.radius(5))
	_check("deterministik: ikinci kurulumda aynı konum", is_equal_approx(l2b.position.y, y_first))
	# Yan yana iki merge: küçük yatay bindirme → yana kayma, kat yok.
	await _make_board(9)
	var la: Label = _board._spawn_float_score(Vector2(cx - 38.0, at.y), 110, Color.WHITE, TierConfig.radius(5))
	var lb: Label = _board._spawn_float_score(Vector2(cx + 38.0, at.y), 90, Color.WHITE, TierConfig.radius(5))
	var ra: Rect2 = Rect2(la.position, la.size).grow(_board.FLOAT_SCORE_LANE_GAP)
	var rb: Rect2 = Rect2(lb.position, lb.size)
	_check("yan yana: çakışma yok", not ra.intersects(rb))
	_check("yan yana: ikinci etiket kat değil, yana kaydı (aynı y, sağa)", is_equal_approx(lb.position.y, la.position.y)
		and lb.position.x > cx + 38.0 - lb.size.x * 0.5)
	# Ömür: etiketler ~0.5 s'de kendini siler; sonraki spawn listeyi budar.
	await _wait(0.8)
	_check("etiketler kendini sildi", _fx("label").is_empty())
	_board._spawn_float_score(at, 90, Color.WHITE, TierConfig.radius(4))
	_check_eq("canlı etiket listesi budandı (1)", _board._float_labels.size(), 1)
	_check("etiket yok-ken yeni etiket taban konumda (kat yok)",
		is_equal_approx((_board._float_labels[0] as Label).position.y, r1.position.y))

	# Gerçek zincir skoru: T2+T2→T3 (+70), doğan T3 komşu T3 ile →T4 (+90).
	await _make_board(9)
	var y: float = _board.FLOOR_Y
	_spawn(3, Vector2(cx - 50.0, y - 34.0 - 4.0))
	await _frames(30)
	_spawn(2, Vector2(cx - 50.0 + 34.0 + 27.0 + 2.0, y - 27.0 - 4.0))
	await _frames(40)
	var rest2: Dumpling = null
	for d in _pieces():
		if d.tier == 2:
			rest2 = d
	var score0: int = GameState.score
	var merges: Array = [0]
	var cb := func(_t: int, _p: Vector2) -> void: merges[0] += 1
	GameState.merge_performed.connect(cb)
	_spawn(2, Vector2(rest2.global_position.x - 6.0, rest2.global_position.y - 27.0 - 200.0))
	for i in 300:
		await get_tree().physics_frame
		if merges[0] >= 2:
			break
	GameState.merge_performed.disconnect(cb)
	_check_eq("zincir: 2 merge", merges[0], 2)
	_check_eq("zincir skoru 70 + 90 = 160 (değişmedi)", GameState.score - score0, 160)
	_check_eq("zincir sonunda tek T4", _tiers(), [4])
	_check("zincir combo x2", _board._combo_count == 2)


# --- 4) Sarsıntı halkası ----------------------------------------------------------

func _test_shake_ring() -> void:
	_section("Sarsıntı: içi boş halka, kap genişliğine göre ölçü, tek MEDIUM")
	await _make_board(6)
	var cx: float = _board._center_x()
	for i in 5:
		_spawn(1 + i, Vector2(cx - 120.0 + i * 60.0, _board.FLOOR_Y - 60.0 - i * 10.0))
	await _frames(60)
	var stock: int = SaveManager.powerup_count(PowerUp.Type.SHAKE)
	_board._use_shake()
	await _frames(1)
	_check_eq("stok bir düştü", SaveManager.powerup_count(PowerUp.Type.SHAKE), stock - 1)
	var rings: Array = _sprites_with(_board.RING_TEXTURE)
	_check_eq("bir sarsıntı halkası (RING dokusu)", rings.size(), 1)
	if rings.size() == 1:
		var ring: Sprite2D = rings[0]
		var visible_px: float = ring.scale.x * 128.0 * 0.72
		var w: float = _board.level.container_width
		_check("halka görünür çapı kap genişliğinin %30–%60'ı ile başlıyor (%.0f / %.0f)" % [visible_px, w],
			visible_px >= w * 0.28 and visible_px <= w * 0.6)
		_check("halka toplamsal + ikinci kat çocuk sprite", ring.material == LIGHT_MATERIAL
			and ring.get_child_count() == 1 and (ring.get_child(0) as Sprite2D).texture == _board.RING_TEXTURE)
		_check("halka kabın ortasında", is_equal_approx(ring.position.x, cx))
	_check("sarsıntıda dolu parıltı sprite'ı yok (sis lekesi kalktı)", _sprites_with(_board.GLOW_TEXTURE).is_empty())
	await _wait(0.5)
	_check("halka 0.5 s'de temizlendi", _sprites_with(_board.RING_TEXTURE).is_empty())
	_check("sarsıntı titreşimi tek MEDIUM (32 ms)", _haptics.size() == 1 and _haptics[0]["ms"] == 32)
	_check("koruma penceresi açıldı (1.2 s, değişmedi)", _board._shake_protection > 0.6 and _board.SHAKE_OVERFLOW_GRACE == 1.2)


# --- 5) Büyütücü ----------------------------------------------------------------------

func _test_upgrade() -> void:
	_section("Büyütücü: anticipation penceresi, tek işlem, kilit, skor yok")
	await _make_board(8, 2)
	var cx: float = _board._center_x()
	var target: Dumpling = _spawn(3, Vector2(cx, _board.FLOOR_Y - 34.0 - 4.0))
	var other: Dumpling = _spawn(5, Vector2(cx + 120.0, _board.FLOOR_Y - 52.0 - 4.0))
	await _frames(60)
	var pos: Vector2 = target.global_position
	var upgrade_before: int = int(AudioManager.play_count.get(&"upgrade", 0))
	_check("silahlanma", _board._powerups.request(PowerUp.Type.UPGRADE))
	_board._use_targeted_power(target)
	_check_eq("stok DOKUNUŞTA 2 → 1", SaveManager.powerup_count(PowerUp.Type.UPGRADE), 1)
	_check("silah indi", not _board._powerups.is_armed())
	_check("hedef pencerede canlı ve kilitli (is_merging)", is_instance_valid(target) and target.is_merging)
	_check_eq("henüz dönüşüm yok (tier'lar 3, 5)", _tiers(), [3, 5])
	_check_eq("upgrade sesi dokunuşta", int(AudioManager.play_count.get(&"upgrade", 0)) - upgrade_before, 1)
	# Anticipation görselleri hedefe bağlı: halka + sütun.
	var attached: int = 0
	for child in target.get_children():
		if child is Sprite2D:
			attached += 1
	_check_eq("hedefe bağlı anticipation sprite'ları (halka + sütun)", attached, 2)
	var beam_ok: bool = false
	for child in target.get_children():
		if child is Sprite2D and (child as Sprite2D).texture == _board.UPGRADE_BEAM_TEXTURE:
			beam_ok = (child as Sprite2D).z_index == 5 and (child as Sprite2D).global_position.y < pos.y
	_check("sütun ÖNDE (z 5) ve parçanın üstünde", beam_ok)
	# Pencerede ikinci işlem: tekrar silahlan, aynı hedefe dokun → geçersiz (kilitli), stok aynı.
	_check("pencerede yeniden silahlanılabilir", _board._powerups.request(PowerUp.Type.UPGRADE))
	_check("kilitli hedef geçerli hedef değil", not _board._powerups.is_valid_target(target))
	_board._use_targeted_power(target)
	_check_eq("aynı hedefe ikinci dokunuş stok düşürmez", SaveManager.powerup_count(PowerUp.Type.UPGRADE), 1)
	_board._powerups.cancel()
	# Pencere biter: tek dönüşüm.
	await _wait(0.25)
	await _frames(2)
	_check("hedef kaldırıldı", not is_instance_valid(target))
	_check_eq("tek T4 doğdu, T5 dokunulmadı", _tiers(), [4, 5])
	var born: Dumpling = null
	for d in _pieces():
		if d.tier == 4:
			born = d
	_check("doğan parça hedefin yerinde (Δ ≤ 30 px)", born != null and born.global_position.distance_to(pos) <= 30.0)
	_check_eq("skor 0 (güç puan vermez)", GameState.score, 0)
	_check_eq("merge sayacı 0", GameState.merge_count, 0)
	_check_eq("stok hâlâ 1 (ikinci düşüş yok)", SaveManager.powerup_count(PowerUp.Type.UPGRADE), 1)
	_check("T3→T4 titreşimi MEDIUM, dönüşümde (tek)", _haptics.size() == 1 and _haptics[0]["ms"] == 32)
	_check("dönüşümde açılan halka + sütun board'da", _sprites_with(_board.RING_TEXTURE).size() >= 1
		and _sprites_with(_board.UPGRADE_BEAM_TEXTURE).size() == 1)
	_check("kral parıltısı YOK (T4)", _sprites_with(_board.SPARKLE_TEXTURE).is_empty())
	_check("eski hedefin sprite'ları onunla gitti", is_instance_valid(other) and other.get_child_count() <= 2)

	# Menü duraklatması pencerede: dönüşüm donmuş board'a katılır, kopya yok.
	await _make_board(8, 1)
	target = _spawn(2, Vector2(cx, _board.FLOOR_Y - 27.0 - 4.0))
	await _frames(40)
	_board._powerups.request(PowerUp.Type.UPGRADE)
	_board._use_targeted_power(target)
	_board.set_menu_paused(true)
	await _wait(0.25)
	await _frames(2)
	_check_eq("duraklamada dönüşüm gerçekleşti (T3)", _tiers(), [3])
	_check("doğan parça donmuş", _pieces()[0].is_simulation_frozen())
	_board.set_menu_paused(false)
	await _frames(2)
	_check("çözüldü", not _pieces()[0].is_simulation_frozen())
	_check_eq("stok 0, tek düşüş", SaveManager.powerup_count(PowerUp.Type.UPGRADE), 0)


func _test_upgrade_t8_parity() -> void:
	_section("Büyütücü T7→T8: normal T8 merge ile aynı kutlama sınıfı")
	# Sonsuz mod: hedef yok, durum plakası "Hedef tamam!" ile ezilmez.
	await _make_board(0, 1)
	var cx: float = _board._center_x()
	var target: Dumpling = _spawn(7, Vector2(cx, _board.FLOOR_Y - 81.0 - 4.0))
	await _frames(60)
	var tier_max_before: int = int(AudioManager.play_count.get(&"tier_max", 0))
	_board._powerups.request(PowerUp.Type.UPGRADE)
	_board._use_targeted_power(target)
	await _wait(0.25)
	await _frames(2)
	_check_eq("T8 doğdu", _tiers(), [8])
	_check("kral parıltısı çağrıldı (yıldız + patlama yıldızı)", _sprites_with(_board.SPARKLE_TEXTURE).size() >= 1
		and _sprites_with(_board.BURST_TEXTURE).size() == 1)
	_check_eq("tier_max sesi", int(AudioManager.play_count.get(&"tier_max", 0)) - tier_max_before, 1)
	_check("titreşim SPECIAL (35 + 60 ms), MEDIUM değil", _haptics.size() == 2 and _haptics[0]["ms"] == 35
		and _haptics[1]["ms"] == 60)
	_check_eq("skor 0 / merge 0 (kutlama puan vermez)", [GameState.score, GameState.merge_count], [0, 0])
	_check_eq("en yüksek tier 8 kaydedildi", _board.max_tier_reached(), 8)
	_check("durum plakası kral", _board._status_label.text.contains(TierConfig.tier_name(8)))
	_check("sonsuz mod: round bitmedi", _finished.is_empty())


func _test_upgrade_objective() -> void:
	_section("Büyütücü hedef takibi + bitmiş board'da kopya yok")
	await _make_board(1, 2)
	var cx: float = _board._center_x()
	var target: Dumpling = _spawn(3, Vector2(cx, _board.FLOOR_Y - 34.0 - 4.0))
	await _frames(40)
	_board._powerups.request(PowerUp.Type.UPGRADE)
	_board._use_targeted_power(target)
	await _wait(0.25)
	await _frames(2)
	_check("L1 (hedef 4): T3→T4 yükseltmesi round'u bitirdi, bir kez", _finished.size() == 1 and _finished[0])
	_check_eq("skor yine 0", GameState.score, 0)
	_check("kazanma çapası hedefin konumu (Δ < 40 px)",
		_board._win_anchor.distance_to(Vector2(cx, _board.FLOOR_Y - 38.0)) < 40.0)
	_board._check_objective()
	_board._check_objective(Vector2.ZERO)
	_check_eq("tekrar tetik: round_finished hâlâ 1", _finished.size(), 1)
	_check("bitmiş round: güç silahlanamaz", not _board._powerups.request(PowerUp.Type.UPGRADE))


# --- 6) Kazanma çapası -------------------------------------------------------------

func _test_win_anchor() -> void:
	_section("Kazanma: çapa kazandıran merge'de, tek bitiş, kap ağzı değil")
	await _make_board(1)
	var cx: float = _board._center_x()
	var res: Dictionary = await _merge_pair(3, cx)
	await _frames(1)
	_check("T3+T3 → T4 round'u bitirdi (bir kez, kazanıldı)", _finished.size() == 1 and _finished[0])
	_check("çapa merge noktası", _board._win_anchor.distance_to(res["point"]) < 1.0)
	var bursts: Array = _fx("particles")
	var near: int = 0
	var mouth: int = 0
	for p in bursts:
		var c := p as CPUParticles2D
		if c.position.distance_to(res["point"]) <= 40.0:
			near += 1
		if absf(c.position.y - (_board.container_top_y() + 40.0)) < 2.0:
			mouth += 1
	_check("kutlama patlamaları (≥ 2) merge noktasında, kap ağzında hiçbiri (yakın %d, ağız %d)" % [near, mouth],
		near >= 2 and mouth == 0)
	var win_y: float = res["point"].y
	_check("çapa board içinde (çizgi−40 ≤ y ≤ taban−40)", win_y >= _board.overflow_line_y() - 40.0 and win_y <= _board.FLOOR_Y - 40.0)
	_check("durum 'Hedef tamam!'", _board._status_label.text == "Hedef tamam!")
	_check("kazanma sarsıntısı ≥ 5 px (değişmedi)", _board._shake_strength >= 4.0)
	_board._check_objective(res["point"])
	_check_eq("ikinci tetik kopya bitiş üretmez", _finished.size(), 1)
	# Çapasız yol (test/harici tetik): yığın tepesine düşer.
	await _make_board(1)
	_spawn(2, Vector2(cx - 60.0, _board.FLOOR_Y - 60.0))
	_spawn(3, Vector2(cx + 40.0, _board.FLOOR_Y - 34.0 - 4.0))
	await _frames(40)
	var top: float = _board._pile_top_y()
	_check("_pile_top_y yığının tepesi (< taban − 60)", top < _board.FLOOR_Y - 60.0 and top > _board.overflow_line_y())
	_board._reached_target_tier = true
	_board._check_objective()
	await _frames(1)
	_check("çapasız kazanma bitişi bir kez", _finished.size() == 1)
	var fallback_ok: bool = false
	for p in _fx("particles"):
		if absf((p as CPUParticles2D).position.y - top) < 2.0:
			fallback_ok = true
	_check("çapasız: patlama yığın tepesinde", fallback_ok)
	# Boş board'da çapasız: kabın ortası (kırılmaz).
	await _make_board(1)
	_check("boş board _pile_top_y = kabın ortası",
		is_equal_approx(_board._pile_top_y(), (_board.overflow_line_y() + _board.FLOOR_Y) * 0.5))


# --- 7) Temizlik -----------------------------------------------------------------------

func _test_cleanup() -> void:
	_section("Temizlik: T8 merge + Büyütücü + sarsıntı sonrası geçici düğüm yok")
	await _make_board(8, 2)
	var cx: float = _board._center_x()
	await _merge_pair(7, cx - 100.0)
	var t3: Dumpling = _spawn(3, Vector2(cx + 120.0, _board.FLOOR_Y - 34.0 - 4.0))
	await _frames(30)
	_board._powerups.request(PowerUp.Type.UPGRADE)
	_board._use_targeted_power(t3)
	_board._use_shake()
	await _frames(3)
	var busy: int = _fx("sprite").size() + _fx("label").size() + _fx("particles").size() + _fx("pop").size()
	_check("efektler oynarken geçici düğümler var (%d)" % busy, busy >= 5)
	await _wait(1.6)
	await _frames(2)
	var left: int = _fx("sprite").size() + _fx("label").size() + _fx("particles").size() + _fx("pop").size()
	_check_eq("1.6 s sonra geçici efekt düğümü kalmadı", left, 0)
	_check("bokeh duruyor", is_instance_valid(_board._bokeh) and _board._bokeh.emitting)
	var lingering: int = 0
	for d in _pieces():
		for child in d.get_children():
			if child is Sprite2D:
				lingering += 1
	_check_eq("parçalara bağlı efekt kalmadı", lingering, 0)
	_check("tween kalmadı (hepsi tek atışlık)", get_tree().get_processed_tweens().is_empty())
	_check_eq("parça sayısı: T8 + T4", _tiers(), [4, 8])
