extends Node
## Gameplay shell / responsive regresyon testi (M8.6-02). Headless, kayda
## YAZMAZ (SaveManager.data yalnızca bellekte; sonunda geri konur).
##
##   godot --headless --audio-driver Dummy --path . res://tools/gameplay_shell_test.tscn
##
## Kontroller: production HUD bileşenleri var ve doğru variation'da;
## Sıradaki / Hedef production plaka; güç slotları UiKit.power_slot; evrim
## şeridi tam 8 giriş ve gerçek tier dokuları; hedef kompozisyonlarda
## (720x1280 / 720x1560 / 720x1440 / 720x1600 + banner 0 ve 100) hiçbir
## kontrol ölçülebilir şekilde çakışmıyor, board etkileşim alanı HUD
## kontrolleriyle çakışmıyor, dokunma hedefleri >= 48, banner seam var ve
## hiçbir kontrol içine girmiyor; kamera dönüşümü tersinir; ayarlar
## duraklatması board'u donduruyor; runtime'da _visual_source / spike
## referansı yok.

const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const DUMPLING_VISUAL: GDScript = preload("res://scripts/game/dumpling_visual.gd")
## Mantıksal tuval kompozisyonları. 540x960 → 720x1280, 1080x2340 → 720x1560
## (canvas_items + expand: genişlik 720'ye sabit, yükseklik oranla).
const VIEWS: Array[Vector2] = [Vector2(720, 1280), Vector2(720, 1560), Vector2(720, 1440), Vector2(720, 1600)]
const BANNERS: Array[float] = [0.0, 100.0]
const RUNTIME_FILES: Array[String] = [
	"res://scripts/game/game_board.gd", "res://scripts/ui/gameplay_hud.gd",
	"res://scripts/ui/power_bar.gd", "res://scripts/ui/evolution_strip.gd",
	"res://scripts/ui/gameplay_layout.gd", "res://scripts/ui/ui_kit.gd",
	"res://scenes/game/game_board.tscn", "res://scenes/ui/power_bar.tscn",
	"res://assets/visual/ui_theme.tres",
]
const FORBIDDEN: Array[String] = ["_visual_source", "layerlab_spike", "layerlab_casual_game", "unitypackage"]

var _fails: int = 0
var _checks: int = 0
var _saved: Dictionary = {}


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	await get_tree().process_frame
	_saved = SaveManager.data.duplicate(true)
	SaveManager.data["powerups"] = {"bomb": 2, "upgrade": 0, "shake": 1, "clear_small": 3}

	print("-- bileşenler")
	var board: Node2D = await _make_board("res://resources/levels/level_04.tres")
	var hud: GameplayHud = board.get_node("HUD")
	_c("HUD katmanı GameplayHud", hud != null)
	_c("skor plakası PanelHud", hud.score_plate != null and hud.score_plate.theme_type_variation == &"PanelHud")
	_c("skor etiketi LabelHudScore", hud.score_label.theme_type_variation == &"LabelHudScore")
	_c("Sıradaki production plaka (PanelElevated)", hud.next_plate.theme_type_variation == &"PanelElevated")
	_c("Sıradaki gerçek tier dokusu", hud.next_art.texture == DUMPLING_VISUAL.TEXTURES[board._next_tier - 1])
	_c("Hedef production plaka (PanelHud)", hud.goal_plate.theme_type_variation == &"PanelHud")
	_c("level rozeti Badge", hud.level_badge.theme_type_variation == &"Badge" and hud.level_label.text == "4")
	_c("hedef tier dokusu gerçek", hud.goal_art.texture == DUMPLING_VISUAL.TEXTURES[5])
	_c("hedef adı", hud.goal_label.text == TierConfig.tier_name(6) and hud.goal_caption.text == "HEDEF")
	_c("taban dokusu görünür bölgeden çiziliyor (saydam üst pay yok)",
		board.FLOOR_TEXTURE_REGION.position.y >= 108.0 and board.FLOOR_TEXTURE_REGION.end.y <= 235.0)
	_c("ilerleme ProgressBarMint", hud.goal_bar.theme_type_variation == &"ProgressBarMint")
	_c("ayarlar ButtonIcon", hud.settings_button.theme_type_variation == &"ButtonIcon")
	_c("eski serbest metin yok (ScoreLabel/NextLabel/ObjectiveLabel)",
		hud.get_node_or_null("ScoreLabel") == null and hud.get_node_or_null("NextLabel") == null
		and hud.get_node_or_null("ObjectiveLabel") == null and hud.get_node_or_null("TopPlate") == null)

	print("-- güç slotları")
	var bar: PowerBar = hud.power_bar
	var slot_ok: bool = true
	for type in PowerUp.all():
		var slot: Button = bar.slot(int(type))
		slot_ok = slot_ok and slot != null and slot.has_meta(&"power_slot") \
			and String(slot.theme_type_variation).begins_with("PowerSlot")
	_c("dört slot UiKit.power_slot", slot_ok)
	_c("slot owner güç sanatı", (bar.slot(int(PowerUp.Type.BOMB)).get_meta(&"art") as TextureRect).texture == PowerUp.icon(PowerUp.Type.BOMB))
	_c("stok rozeti ×2", bar.displayed_count(int(PowerUp.Type.BOMB)) == 2)
	_c("slot madalyon govdesi btn_circle",
		(UiKit.theme().get_stylebox("normal", &"PowerSlot") as StyleBoxTexture).texture
			== UiKit.texture("btn_circle"))
	_c("stok 0 sanat rengini koruyor (tam gri degil)",
		(bar.slot(int(PowerUp.Type.UPGRADE)).get_meta(&"art") as TextureRect).self_modulate.a > 0.5)
	_c("stok 0 slotu PowerSlotEmpty + refill '+' rozeti",
		bar.slot(int(PowerUp.Type.UPGRADE)).theme_type_variation == &"PowerSlotEmpty"
		and (bar.slot(int(PowerUp.Type.UPGRADE)).get_meta(&"badge_plus") as Control).visible)
	bar.set_armed(int(PowerUp.Type.BOMB))
	_c("silahlı slot PowerSlotArmed + parıltı", bar.slot(int(PowerUp.Type.BOMB)).theme_type_variation == &"PowerSlotArmed"
		and (bar.slot(int(PowerUp.Type.BOMB)).get_meta(&"glow") as Control).visible)
	bar.set_armed(PowerUpController.ARMED_NONE)
	_c("silah indi", bar.slot(int(PowerUp.Type.BOMB)).theme_type_variation == &"PowerSlot")
	bar.set_enabled(false)
	_c("kapalıyken disabled", bar.slot(int(PowerUp.Type.SHAKE)).disabled)
	bar.set_enabled(true)
	_c("açılınca disabled değil", not bar.slot(int(PowerUp.Type.SHAKE)).disabled)

	print("-- evrim şeridi")
	var strip: EvolutionStrip = hud.strip
	_c("tam 8 giriş", strip.entry_count() == TierConfig.MAX_TIER)
	var tex_ok: bool = true
	for i in TierConfig.MAX_TIER:
		tex_ok = tex_ok and strip.entry_texture(i) == DUMPLING_VISUAL.TEXTURES[i]
	_c("8 giriş gerçek tier dokuları, sırayla", tex_ok)
	_c("şerit PanelStrip", strip.theme_type_variation == &"PanelStrip")
	_c("şeritte metin yok", strip.find_children("*", "Label", true, false).is_empty())
	board._spawn_dumpling(3, Vector2(board._center_x(), board.FLOOR_Y - 100.0))
	_c("ulaşılan tier 3", strip.reached() == 3)
	_c("hedef işareti tier 6", strip._targets[5].visible and not strip._targets[3].visible)

	print("-- yerleşim / çakışma")
	for view in VIEWS:
		for banner in BANNERS:
			GameplayLayout.set_banner_height(banner)
			board._apply_layout(view)
			await get_tree().process_frame
			await get_tree().process_frame
			await _check_composition(board, hud, view, banner)
	GameplayLayout.set_banner_height(0.0)
	# Punch-hole / centik: A36 ust guvenli pay 92 px fiziksel = 61 tuval px.
	board._apply_layout(Vector2(720, 1560), 61.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await _check_composition(board, hud, Vector2(720, 1560), 0.0)
	_c("safe_top 61: HUD satir 1 payin altinda", hud.settings_button.get_global_rect().position.y >= 65.0
		and hud.score_plate.get_global_rect().position.y >= 65.0)
	board._apply_layout(Vector2(720, 1280), 0.0)
	await get_tree().process_frame

	print("-- kamera / girdi")
	var p := Vector2(board._center_x() + 123.0, board.FLOOR_Y - 77.0)
	_c("screen_to_world(world_to_screen(p)) == p",
		board.screen_to_world(board.world_to_screen(p)).distance_to(p) < 0.01)
	var frame: Rect2 = board.reference_frame()
	var region: Rect2 = board.layout()["board"]
	var shown: Rect2 = board.board_screen_rect()
	_c("referans pencere BOARD bölgesinde", region.grow(1.0).encloses(shown))
	_c("fizik ölçüleri değişmedi (FLOOR_Y 1180 / RIM 420 / duvar 20)",
		board.FLOOR_Y == 1180.0 and board.RIM_ABOVE_LINE == 420.0 and board.WALL_THICKNESS == 20.0
		and frame.size.x > 0.0)

	print("-- ayarlar duraklatması")
	board.set_menu_paused(true)
	_c("menü duraklatması _is_paused", board._is_paused() and not bar._enabled)
	board.set_menu_paused(false)
	_c("menü çözüldü", not board._is_paused() and bar._enabled)
	var got_signal: Array = []
	board.settings_requested.connect(func() -> void: got_signal.append(true))
	hud.settings_button.pressed.emit()
	_c("ayarlar butonu settings_requested yayıyor", got_signal.size() == 1)

	print("-- skor / Sıradaki / durum")
	GameState.add_score(1234)
	_c("skor 1 234 formatı", hud.score_label.text == "1 234")
	_c("skor pop'u plakanın sağ kenarında", absf(hud.score_pop_home().x - hud.score_plate.get_global_rect().end.x - 4.0) < 0.5)
	hud.set_status("Taştı!")
	await get_tree().process_frame
	_c("durum plakası görünür ve board ortasında", hud.status_plate.visible
		and hud.status_label.text == "Taştı!"
		and absf(hud.status_plate.get_global_rect().get_center().x - 360.0) < 2.0)
	hud.set_status("")
	_c("durum plakası boş metinde gizli", not hud.status_plate.visible)
	board._next_tier = 2
	board._refresh_preview()
	_c("Sıradaki tier 2 dokusu", hud.next_art.texture == DUMPLING_VISUAL.TEXTURES[1])

	print("-- sonsuz mod HUD")
	board.queue_free()
	await get_tree().process_frame
	var endless: Node2D = await _make_board("res://resources/levels/endless.tres")
	var ehud: GameplayHud = endless.get_node("HUD")
	_c("sonsuz: rozet SONSUZ, başlık REKOR", ehud.level_label.text == "SONSUZ" and ehud.goal_caption.text == "REKOR")
	_c("sonsuz: hedef işareti yok", not ehud.strip._targets.any(func(m: Control) -> bool: return m.visible))
	endless._apply_layout(Vector2(720, 1280))
	await get_tree().process_frame
	await get_tree().process_frame
	await _check_composition(endless, ehud, Vector2(720, 1280), 0.0)
	endless.queue_free()
	await get_tree().process_frame

	print("-- runtime referans taraması")
	var hits: Array[String] = []
	for path in RUNTIME_FILES:
		var text: String = FileAccess.get_file_as_string(path)
		for word in FORBIDDEN:
			if text.contains(word):
				hits.append("%s: %s" % [path, word])
	_c("runtime'da _visual_source / layerlab_spike referansı yok", hits.is_empty())
	for hit in hits:
		print("      ", hit)
	_c("eski spike klasörü yok", not DirAccess.dir_exists_absolute("res://assets/visual/ui/layerlab_spike"))

	SaveManager.data = _saved
	print("\n=== gameplay_shell_test: %d kontrol, %d hata ===" % [_checks, _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _make_board(level: String) -> Node2D:
	var board: Node2D = GAME_BOARD_SCENE.instantiate()
	board.setup(load(level))
	add_child(board)
	await get_tree().process_frame
	await get_tree().process_frame
	return board


func _rect(control: Control) -> Rect2:
	return control.get_global_rect()


func _check_composition(board: Node2D, hud: GameplayHud, view: Vector2, banner: float) -> void:
	var tag: String = "%dx%d banner %d" % [int(view.x), int(view.y), int(banner)]
	var controls: Dictionary = {
		"ayarlar": _rect(hud.settings_button), "skor": _rect(hud.score_plate),
		"siradaki": _rect(hud.next_plate), "hedef": _rect(hud.goal_plate),
		"serit": _rect(hud.strip),
	}
	for type in PowerUp.all():
		controls["slot_" + PowerUp.SAVE_KEYS[type]] = _rect(hud.power_bar.slot(int(type)))
	var names: Array = controls.keys()
	var overlap: Array[String] = []
	for i in names.size():
		for j in range(i + 1, names.size()):
			if GameplayLayout.overlaps(controls[names[i]], controls[names[j]]):
				overlap.append("%s x %s" % [names[i], names[j]])
	_c("%s: kontroller çakışmıyor" % tag, overlap.is_empty())
	for o in overlap:
		print("      ", o)
	var board_rect: Rect2 = board.board_screen_rect()
	var board_hit: Array[String] = []
	for name in names:
		if name != "serit" and GameplayLayout.overlaps(board_rect, controls[name]):
			board_hit.append(name)
	_c("%s: board alanı HUD kontrolleriyle çakışmıyor" % tag, board_hit.is_empty())
	for b in board_hit:
		print("      ", b)
	_c("%s: şerit board'un altında" % tag, controls["serit"].position.y >= board_rect.end.y - 0.5)
	var view_rect := Rect2(Vector2.ZERO, view)
	var inside: bool = true
	for name in names:
		inside = inside and view_rect.grow(0.5).encloses(controls[name])
	_c("%s: her kontrol ekran içinde" % tag, inside)
	var touch_ok: bool = true
	for type in PowerUp.all():
		var r: Rect2 = controls["slot_" + PowerUp.SAVE_KEYS[type]]
		touch_ok = touch_ok and r.size.x >= UiTokens.TOUCH_MIN and r.size.y >= UiTokens.TOUCH_MIN
	touch_ok = touch_ok and controls["ayarlar"].size.x >= UiTokens.TOUCH_MIN
	_c("%s: dokunma hedefleri >= 48" % tag, touch_ok)
	var seam: Rect2 = _rect(hud.banner_seam)
	_c("%s: banner seam var (y %d, h %d)" % [tag, int(seam.position.y), int(seam.size.y)],
		absf(seam.size.y - banner) < 0.5 and absf(seam.end.y - view.y) < 0.5)
	var seam_hit: bool = false
	for name in names:
		seam_hit = seam_hit or (banner > 0.0 and GameplayLayout.overlaps(seam, controls[name]))
	seam_hit = seam_hit or (banner > 0.0 and GameplayLayout.overlaps(seam, board_rect))
	_c("%s: banner seam'e kontrol/board girmiyor" % tag, not seam_hit)
	var region: Rect2 = board.layout()["board"]
	_c("%s: board bölgesi kullanışlı (>= 700 px)" % tag, region.size.y >= 700.0)
