extends Node
## M8.9-02 düzen çekimleri: Harita + banner yuvası, oyun + banner yuvası,
## Mağaza günlük ödüller bölümü + yuva, GÜNLÜK ÖDÜLLER penceresi (durumlar)
## ve günlük sandık reveal'i (yalnız Hamur / Hamur + Common skin / Hamur +
## Legendary skin). Dev aracı — oyun çalışırken kullanılmaz. `--headless`
## İLE ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn`, sahte reklam arka ucuyla (`FakeAdBackend`, eklenti
## yok): MonetizationManager yuvayı hesaplar. Masaüstünde gerçek banner
## çizilemediği için banner'ın kaplayacağı bölge YARI SAYDAM MAGENTA plaka
## ile işaretlenir (yalnız bu araçta). Karşılaştırma için Harita ve oyun
## yuvasız (eski düzen) da çekilir.
##
##   01_map_slot            Harita + yuva (orta oyuncu: level 4 sıradaki)
##   01b_map_slot_fresh     Harita + yuva, yeni oyuncu (level 1 SIRADAKİ: OYNA plakası + hale yuvanın üstünde)
##   02_gameplay_slot       L4 oyun + yuva (kompakt mod 16:9'da)
##   03_shop_daily_slot     Mağaza üstü: GÜNLÜK ÖDÜLLER kartı + yuva
##   04_daily_modal_ready   pencere: hepsi HAZIR (sağlayıcı hazır)
##   05_daily_modal_mixed   pencere: ücretsiz ALINDI, sandık 1 / 2, Hamur reklam hazırlanıyor
##   06_reveal_dough        reveal: yalnız +15 Hamur
##   07_reveal_common       reveal: +15 Hamur + Common skin
##   08_reveal_legendary    reveal: +15 Hamur + Legendary skin
##   09_map_noslot / 10_gameplay_noslot   referans (eski düzen)
##
## Reveal'ler SUNUM: `DailyChestReward` elle kurulur ve `show_reveal` ile
## gösterilir — kayda yazılmaz (pencere kayda yazmaz). Yuva ölçüsü: dp ×
## yoğunluk × (720 / pencere genişliği); `dp=` / `density=` / `safe=N`.
##
## KAYIT: araç kayıt dosyasını başta byte olarak okur, çıkışta AYNEN geri
## yazar (ücretsiz sandık claim'i bir kez GERÇEK transaction'la yapılır —
## dosya sonda geri konur).
##
## Kullanım:
##   godot --path . res://tools/daily_ads_shots.tscn -- <çıktı_klasörü> [GxY] [safe=61] [dp=64] [density=2.625]

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const LEVEL_04: String = "res://resources/levels/level_04.tres"
const SHOT_SIZE := Vector2i(720, 1280)
const OVERLAY_COLOR := Color(1.0, 0.0, 0.8, 0.38)

var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _main: Node2D
var _main_script: GDScript = load("res://scripts/main.gd")
var _saved_data: Dictionary = {}
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _safe_top: float = -1.0
var _dp: int = 64
var _density: float = 2.625
var _overlay: CanvasLayer
var _fake: FakeAdBackend


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://daily_ads_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_size = _shot_size(args)
	for arg in args:
		var a: String = String(arg)
		if a.begins_with("safe="):
			_safe_top = float(a.trim_prefix("safe="))
		elif a.begins_with("dp="):
			_dp = int(a.trim_prefix("dp="))
		elif a.begins_with("density="):
			_density = float(a.trim_prefix("density="))
	DisplayServer.window_set_size(_size)
	await get_tree().process_frame
	await get_tree().process_frame

	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_saved_data = SaveManager.data.duplicate(true)
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	_apply_showcase()
	DailyRewards.clock_override = "2026-09-22"

	# 1) Yuvalı: sahte arka uç, SDK hazır, ödüllü reklam yüklü.
	_fake = FakeAdBackend.new()
	_fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	_fake.adaptive_height_dp = _dp
	_fake.density_value = _density
	await _make_main(_fake)
	_fake.complete_consent_update(true)
	_fake.complete_init()
	_fake.complete_rewarded_load(true)
	_fake.complete_interstitial_load(true)
	var slot: float = _main._ads.banner_slot_px()
	print("banner yuvası: %d dp × %.3f → %d tuval px (pencere %s)" % [_dp, _density, int(slot), str(_size)])
	_build_overlay(slot)
	await _show_tab(1)
	_report_map()
	await _capture("01_map_slot")
	# Yeni oyuncu: level 1 SIRADAKİ (OYNA plakası + hale) — en kötü durum.
	SaveManager.data["highest_level_unlocked"] = 1
	SaveManager.data["level_stars"] = {}
	await _show_tab(0)
	await _show_tab(1)
	_report_map()
	await _capture("01b_map_slot_fresh")
	SaveManager.data["highest_level_unlocked"] = 4
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3}
	await _show_tab(0)
	_main._start_level(load(LEVEL_04))
	await _settle()
	if _main._board != null:
		_main._board._dismiss_tutorial()
	await _settle()
	_report_gameplay()
	await _capture("02_gameplay_slot")
	_main.abandon_run()
	await _settle()
	await _show_tab(3)
	await _capture("03_shop_daily_slot")
	# Pencere: hepsi hazır.
	var popup: CanvasLayer = _main._daily_rewards
	_main.open_daily_rewards()
	await _settle()
	await _capture("04_daily_modal_ready")
	# Karışık durum: ücretsiz alındı (gerçek transaction, sonda geri konur),
	# sandık 1 / 2, Hamur reklamı hazır değil.
	popup.close_popup()
	await _settle()
	DailyRewards.claim_free_chest()
	DailyRewards.grant_ad_chest(DailyRewards.day_key())
	_main._ads._rewarded_state = MonetizationManager.RewardedState.LOADING
	_main._ads._ready_ad_id = ""
	_main.open_daily_rewards()
	await _settle()
	await _capture("05_daily_modal_mixed")
	_main._ads._rewarded_state = MonetizationManager.RewardedState.READY
	popup.close_popup()
	await _settle()
	# Reveal'ler (sunum).
	_main.open_daily_rewards()
	await _settle()
	popup.show_reveal(_reward(15, null, -1))
	await _reveal_settle(popup)
	await _capture("06_reveal_dough")
	popup.show_reveal(_reward(15, SkinLibrary.find(&"common_03"), int(SkinData.Rarity.COMMON)))
	await _reveal_settle(popup)
	await _capture("07_reveal_common")
	popup.show_reveal(_reward(15, SkinLibrary.find(&"legendary_01"), int(SkinData.Rarity.LEGENDARY)))
	await _reveal_settle(popup)
	await _capture("08_reveal_legendary")
	popup.close_popup()
	await _settle()
	await _free_main()

	# 2) Yuvasız referans.
	await _make_main(null)
	await _show_tab(1)
	await _capture("09_map_noslot")
	_main._start_level(load(LEVEL_04))
	await _settle()
	if _main._board != null:
		_main._board._dismiss_tutorial()
	await _settle()
	await _capture("10_gameplay_noslot")
	_main.abandon_run()
	await _settle()
	await _free_main()

	DailyRewards.clock_override = ""
	SaveManager.data = _saved_data
	_restore_save_file()
	SaveManager.load_game()
	print("bitti -> ", _out_dir)
	get_tree().quit()


func _reward(dough: int, skin: SkinData, rarity: int) -> DailyChestReward:
	var reward := DailyChestReward.new()
	reward.source = "free"
	reward.day_key = DailyRewards.day_key()
	reward.base_dough = dough
	reward.skin = skin
	reward.rarity = rarity
	reward.skin_rolled = skin != null
	return reward


func _reveal_settle(popup: CanvasLayer) -> void:
	await get_tree().create_timer(popup.REVEAL_CONTINUE_DELAY + 0.5).timeout
	await get_tree().process_frame


func _make_main(fake: FakeAdBackend) -> void:
	_main_script.ads_backend_override = fake
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_main_script.ads_backend_override = null
	if _main._daily != null:
		_main._daily.visible = false
	if _safe_top >= 0.0:
		for screen in _main._screens:
			if screen.has_method("_layout_with_safe_top"):
				screen._layout_with_safe_top(_safe_top)


func _free_main() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	_main.queue_free()
	_main = null
	await get_tree().process_frame
	await get_tree().process_frame


## Harita ölçümleri: level 1 plakası / kale / yuva mesafeleri (stdout).
func _report_map() -> void:
	var map: CanvasLayer = _main._screens[1]
	var view: Vector2 = get_viewport().get_visible_rect().size
	var slot_top: float = view.y - UiKit.bottom_inset(view)
	var node1: Control = map.nodes()[0]
	var plaque: Control = node1._plaque
	var plaque_bottom: float = plaque.get_global_rect().end.y if plaque.visible else node1.get_global_rect().end.y
	var endless: Control = map.endless_node()
	var bar_bottom: float = map.top_bar().get_global_rect().end.y
	print("harita: ölçek %s, kırpma üst %.1f doku px, dünya %s" % [str(map.world_scale()), map.crop_top(), str(map.world_rect())])
	print("harita: level 1 plaka altı %.1f / yuva üstü %.1f (boşluk %.1f px); kale üstü %.1f / üst satır altı %.1f (boşluk %.1f px)" % [
		plaque_bottom, slot_top, slot_top - plaque_bottom, endless.get_global_rect().position.y, bar_bottom,
		endless.get_global_rect().position.y - bar_bottom])


## Oyun ölçümleri: kamera zoom, board bölgesi, kompakt mod, T1 çapı (stdout).
func _report_gameplay() -> void:
	var board: Node2D = _main._board
	var rects: Dictionary = board.layout()
	var view: Vector2 = get_viewport().get_visible_rect().size
	var zoom: float = board._camera_zoom
	print("oyun: view %s, kompakt %s, board bölgesi %s, kamera zoom %.3f, T1 çapı %.1f px, T8 çapı %.1f px, seam %s" % [
		str(view), str(rects.get("compact", false)), str(rects["board"]), zoom,
		TierConfig.radius(1) * 2.0 * zoom, TierConfig.radius(8) * 2.0 * zoom, str(rects["banner"])])
	var screen_rect: Rect2 = board.board_screen_rect()
	print("oyun: kap ekran dikdörtgeni %s (altı %.1f, seam üstü %.1f), taşma çizgisi y %.1f" % [str(screen_rect),
		screen_rect.end.y, (rects["banner"] as Rect2).position.y, board.world_to_screen(Vector2(0, board.overflow_line_y())).y])


func _build_overlay(slot: float) -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 100
	add_child(_overlay)
	var view: Vector2 = get_viewport().get_visible_rect().size
	var rect := ColorRect.new()
	rect.color = OVERLAY_COLOR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = Vector2(0.0, view.y - UiKit.safe_bottom(view) - slot)
	rect.size = Vector2(view.x, slot)
	_overlay.add_child(rect)
	var label := Label.new()
	label.text = "BANNER YUVASI %d px (uyarlanabilir, alt, güvenli alan içinde)" % int(slot)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 22)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = rect.position
	label.size = rect.size
	_overlay.add_child(label)


func _restore_save_file() -> void:
	if not _had_save:
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()


func _shot_size(args: PackedStringArray) -> Vector2i:
	if args.size() < 2:
		return SHOT_SIZE
	var parts: PackedStringArray = args[1].split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return SHOT_SIZE
	return Vector2i(int(parts[0]), int(parts[1]))


func _tag() -> String:
	return "%dx%d%s" % [_size.x, _size.y, "_a36" if _safe_top >= 0.0 else ""]


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var file: String = "%s_%s.png" % [name, _tag()]
	var err: int = img.save_png(_out_dir.path_join(file))
	print(("kaydedildi : " if err == OK else "HATA       : "), file)


func _settle() -> void:
	await get_tree().create_timer(0.45).timeout
	await get_tree().process_frame


func _show_tab(tab: int) -> void:
	_main._show_tab(tab)
	await _settle()


## Vitrin kayıt durumu (yalnızca bellekte): orta oyuncu, onboarding tamam.
func _apply_showcase() -> void:
	SaveManager.data["highest_level_unlocked"] = 4
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3}
	SaveManager.data["dough"] = 335
	SaveManager.data["daily_streak"] = 2
	SaveManager.data["unlocked_skins"] = ["common_01", "common_02", "rare_02", "common_05", "epic_01", "rare_04"]
	SaveManager.data["equipped_skin"] = "rare_02"
	SaveManager.data["merges_since_bonus_chest"] = 49
	SaveManager.data["powerups"] = {"bomb": 2, "upgrade": 1, "shake": 0, "clear_small": 1}
	SaveManager.data["powerup_starter_granted"] = true
	SaveManager.data["onboarding_completed"] = true
	SaveManager.data["daily_rewards"] = {"day_key": "", "free_chest_claimed": false, "ad_chests_claimed": 0,
		"dough_ad_claimed": false, "popup_seen_day": "", "last_seen_day_key": ""}
