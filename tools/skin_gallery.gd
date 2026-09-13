extends Node2D
## Skin gorsel QA galerisi (M8.5-14). Dev araci — oyun akisinda yok.
##
## 20 skin x tier 1 / 4 / 8 gameplay render'i (DumplingVisual + SkinVisual,
## yani oyundaki materyalin AYNISI) + ad / rarity etiketi, gameplay'e yakin
## koyu candy zeminde. Satin alma / equip gerekmez: override_skin() kullanir,
## kayda dokunmaz. Yakalamak istedigi: yuz boyanmasi, okunmayan desen,
## birbirine benzeyen skinler, asiri VFX, maske hatasi, tier 1 okunurlugu.
##
## Kullanim (pencereli; --headless ile CALISMAZ):
##   godot --path . res://tools/skin_gallery.tscn -- <cikti_klasoru>
## Cikti: skin_gallery_<rarity>.png (4 kare) + skin_gallery_tier1.png
## (tier 1 x3 — kucuk parca okunurlugu) + skin_gallery_tier8.png (tier 8
## detay — yuz/maske/desen).
## Arguman verilmezse ekranda kalir (canli inceleme, animasyonlu efektler).

const VISUAL: GDScript = preload("res://scripts/game/dumpling_visual.gd")
const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const BOT_BRAIN: GDScript = preload("res://tools/bot_brain.gd")
## Gercek gameplay karesi (sonsuz mod, bot birakir, tier >= 4 merge aninda
## yakalanir) alinan skinler: her rarity'den temsilci + tum Epic/Legendary.
const PLAY_SKINS: Array[StringName] = [&"common_02", &"rare_05", &"epic_01", &"epic_02",
	&"epic_03", &"epic_04", &"legendary_01", &"legendary_02"]
const PLAY_SPEEDUP: int = 4
const TIERS: Array[int] = [1, 4, 8]
## Pencere 1080x1500; proje canvas_items stretch (720 taban) oldugu icin
## yerlesim 720x1000 TABAN koordinatinda yapilir (1.5x buyur).
const SHOT_SIZE := Vector2i(1080, 1500)
const BASE_W: float = 720.0
const CELL_W: float = BASE_W / 4.0
const ROW_H: float = 112.0
const TOP: float = 46.0
## Hucredeki cizim yaricapi (taban px): tier'a gore, satira sigacak kadar.
const DRAW_RADIUS: Dictionary = {1: 18.0, 4: 28.0, 8: 33.0}
const PREVIEW_BOX: float = 92.0
const RARITY_LABELS: Array[String] = ["COMMON", "RARE", "EPIC", "LEGENDARY"]

var _out_dir: String = ""
var _root: Node2D


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ""
	DisplayServer.window_set_size(SHOT_SIZE)
	RenderingServer.set_default_clear_color(Color("1a1440"))
	if _out_dir.is_empty():
		_build_page(SkinData.Rarity.COMMON)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	for rarity in 4:
		_build_page(rarity as SkinData.Rarity)
		await _capture("skin_gallery_%s.png" % RARITY_LABELS[rarity].to_lower())
	_build_tier_page(1, 3.0)
	await _capture("skin_gallery_tier1.png")
	_build_tier_page(8, 0.48)
	await _capture("skin_gallery_tier8.png")
	_clear()
	await _shot_gameplay()
	print("bitti -> ", _out_dir)
	get_tree().quit()


func _clear() -> void:
	if _root != null:
		_root.queue_free()
	_root = Node2D.new()
	add_child(_root)


## Bir rarity'nin skinleri: her satir bir skin (ad + rarity), hucrelerde
## tier 1 / 4 / 8 ve son hucrede final onizleme (karsilastirma icin).
func _build_page(rarity: SkinData.Rarity) -> void:
	_clear()
	_label(Vector2(16, 10), "SKIN QA — %s  (tier 1 / 4 / 8 gameplay · sag: final onizleme)"
		% RARITY_LABELS[rarity], 17, UiPalette.GOLD)
	var skins: Array[SkinData] = SkinLibrary.by_rarity(rarity)
	var y: float = TOP + 22.0
	for skin in skins:
		_label(Vector2(16, y - 20.0), "%s  ·  %s" % [skin.display_name, SkinData.rarity_name(skin.rarity)], 14, Color.WHITE)
		for i in TIERS.size():
			var tier: int = TIERS[i]
			var cell_x: float = CELL_W * i + CELL_W * 0.5
			_place_visual(skin, tier, Vector2(cell_x, y + ROW_H * 0.5), DRAW_RADIUS[tier])
			_label(Vector2(cell_x + 40.0, y + ROW_H * 0.72), "T%d" % tier, 11, UiPalette.TEXT_MUTED)
		_place_preview(skin, Vector2(CELL_W * 3.5, y + ROW_H * 0.5), PREVIEW_BOX)
		y += ROW_H
	# Referans: varsayilan gorunum (skin yok) ust sagda kucuk.
	_label(Vector2(CELL_W * 3.0 + 4.0, 12.0), "varsayilan T4:", 11, UiPalette.TEXT_MUTED)
	_place_visual(null, 4, Vector2(CELL_W * 3.0 + 120.0, 24.0), 18.0)


## Tek tier, 20 skin buyutulmus (yaninda gercek gameplay boyutu): tier 1
## okunurluk, tier 8 yuz/desen/maske detay kontrolu.
func _build_tier_page(tier: int, zoom: float) -> void:
	_clear()
	_label(Vector2(16, 10), "SKIN QA — TIER %d (x%.2f buyutme, gercek boyut sagda)" % [tier, zoom], 17, UiPalette.GOLD)
	var i: int = 0
	var r: float = TierConfig.radius(tier)
	for skin in SkinLibrary.all():
		var col: int = i % 4
		var row: int = i / 4
		var x: float = CELL_W * col + CELL_W * 0.5
		var y: float = TOP + 70.0 + row * 182.0
		_place_visual(skin, tier, Vector2(x - 24.0, y), r * zoom)
		_place_visual(skin, tier, Vector2(x + 66.0, y + 20.0), r * minf(zoom, 1.0) * 0.5)
		_label(Vector2(x - 80.0, y + r * zoom + 6.0), skin.display_name, 13, Color.WHITE)
		i += 1


# --- Gercek gameplay: takili skin + merge ani ---
#
# Takili skin YALNIZCA bellekte degistirilir (save_game cagrilmaz), cekim
# bitince geri konur. Board sonsuz modda, bot birakiyor, tier >= 4 merge'den
# 2 kare sonra yakalaniyor (screenshot_runner._shot_merge ile ayni yontem):
# squash/stretch, merge cekimi, aura ve parcacik uyumu gercek kosulda gorunur.

var _board: Node2D
var _drive: bool = false
var _capture_countdown: int = -1


func _shot_gameplay() -> void:
	var saved_skins: Variant = (SaveManager.data.get("unlocked_skins", []) as Array).duplicate()
	var saved_equipped: Variant = SaveManager.data.get("equipped_skin", "")
	Engine.physics_ticks_per_second = 60 * PLAY_SPEEDUP
	Engine.time_scale = float(PLAY_SPEEDUP)
	Engine.max_physics_steps_per_frame = 16 * PLAY_SPEEDUP
	for id in PLAY_SKINS:
		SaveManager.data["unlocked_skins"] = [String(id)]
		SaveManager.data["equipped_skin"] = String(id)
		_board = GAME_BOARD_SCENE.instantiate()
		_board.setup(load("res://resources/levels/endless.tres"))
		add_child(_board)
		_capture_countdown = -1
		_drive = true
		GameState.merge_performed.connect(_on_merge)
		var frames: int = 0
		while _capture_countdown != 0 and frames < 60 * 40:
			await get_tree().process_frame
			frames += 1
			if _capture_countdown > 0:
				_capture_countdown -= 1
		GameState.merge_performed.disconnect(_on_merge)
		_drive = false
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = _out_dir.path_join("skin_play_%s.png" % id)
		print(("kaydedildi : " if img.save_png(path) == OK else "HATA       : "), path)
		_board.queue_free()
		_board = null
		await get_tree().process_frame
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 16
	SaveManager.data["unlocked_skins"] = saved_skins
	SaveManager.data["equipped_skin"] = saved_equipped


func _physics_process(_delta: float) -> void:
	if not _drive or _board == null or not is_instance_valid(_board):
		return
	if _board._is_finished or _board.is_fail_pending() or _board._drop_cooldown > 0.0:
		return
	_board._set_aim(BOT_BRAIN.pick_x(_board, _board._pending_tier))
	_board._drop()


func _on_merge(tier: int, _position: Vector2) -> void:
	if tier >= 4 and _capture_countdown < 0:
		_capture_countdown = 2


## DumplingVisual'i verilen dis yaricapa olcekler; CONTACT_FIT dokunulmaz.
## Olcek bir SARMALAYICI dugumde: DumplingVisual kendi scale'ini squash icin
## her kare yeniden yaziyor (_apply_scale).
func _place_visual(skin: SkinData, tier: int, at: Vector2, draw_radius: float) -> void:
	var holder := Node2D.new()
	holder.position = at
	holder.scale = Vector2.ONE * (draw_radius / TierConfig.radius(tier))
	_root.add_child(holder)
	var visual: Node2D = VISUAL.new()
	holder.add_child(visual)
	visual.setup(tier)
	visual.override_skin(skin)


func _place_preview(skin: SkinData, at: Vector2, box: float) -> void:
	if skin.preview_texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = skin.preview_texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var size: Vector2 = skin.preview_texture.get_size()
	sprite.scale = Vector2.ONE * (box / maxf(size.x, size.y))
	sprite.position = at
	_root.add_child(sprite)


func _label(at: Vector2, text: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.position = at
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	_root.add_child(label)


func _capture(file_name: String) -> void:
	# Shader TIME'a bagli efektler bir kare sonra otursun.
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out_dir.path_join(file_name)
	var err: int = img.save_png(path)
	print(("kaydedildi : " if err == OK else "HATA       : "), path)
