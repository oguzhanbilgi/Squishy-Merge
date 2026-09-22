extends Node
## Banner yuvası düzen çekimleri (M8.9-01). Dev aracı — oyun çalışırken
## kullanılmaz. `--headless` İLE ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn`, sahte reklam arka ucuyla (`FakeAdBackend`, eklenti yok)
## kurulur: MonetizationManager banner yuvasını hesaplar, Ana Sayfa / Mağaza /
## Koleksiyon alt payı ayırır. Masaüstünde gerçek banner çizilemediği için
## banner'ın kaplayacağı bölge YARI SAYDAM MAGENTA plaka ile işaretlenir
## (yalnız bu araçta; production'da böyle bir çizim yok). Karşılaştırma için
## aynı ekranlar yuvasız (eski düzen) da çekilir.
##
##   01_home / 02_map / 03_shop / 04_collection      yuva + plaka
##   05_home_noslot / 06_shop_noslot / 07_coll_noslot  eski düzen (referans)
##   08_gameplay                                    oyun (banner dışı; plaka yok)
##
## Yuva ölçüsü: uyarlanabilir banner yüksekliği dp × yoğunluk × (720 /
## pencere genişliği). Varsayılan 64 dp × 2.625 (A36); `dp=` / `density=`
## argümanlarıyla değiştirilebilir. `safe=N` A36 punch-hole simülasyonu.
##
## KAYIT: kayda yazan yol yok; araç kayıt dosyasını başta byte olarak okur,
## çıkışta AYNEN geri yazar (güvenlik).
##
## Kullanım:
##   godot --path . res://tools/banner_slot_shots.tscn -- <çıktı_klasörü> [GxY] [safe=61] [dp=64] [density=2.625]

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


func _ready() -> void:
	# Otomatik GÜNLÜK ÖDÜLLER penceresi (M8.9-02) bu harness'in konusu değil.
	DailyRewards.auto_popup_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://banner_slot_shots")
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
	# M8.10: bu harness KABUGU olcuyor — onboarding tamamlanmis olmali,
	# yoksa Main dogrudan ilk acilis tutorial'ina girer. Kayit dosyasini
	# geri koymayan baska bir suite diske `false` birakmis olabilir.
	SaveManager.data["onboarding_completed"] = true
	_apply_showcase()

	# 1) Yuvalı: sahte arka uç.
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	fake.adaptive_height_dp = _dp
	fake.density_value = _density
	await _make_main(fake)
	fake.complete_consent_update(true)
	fake.complete_init()
	var slot: float = _main._ads.banner_slot_px()
	print("banner yuvası: %d dp × %.3f → %d tuval px (pencere %s)" % [_dp, _density, int(slot), str(_size)])
	_build_overlay(slot)
	await _show_tab(0)
	await _capture("01_home")
	await _show_tab(1)
	_overlay.visible = false
	await _capture("02_map")
	_overlay.visible = true
	await _show_tab(3)
	await _capture("03_shop")
	await _show_tab(2)
	await _capture("04_collection")
	_overlay.visible = false
	_main._start_level(load(LEVEL_04))
	await _settle()
	await _settle()
	await _capture("08_gameplay")
	_main.abandon_run()
	await _settle()
	await _free_main()

	# 2) Yuvasız referans (eski düzen).
	await _make_main(null)
	await _show_tab(0)
	await _capture("05_home_noslot")
	await _show_tab(3)
	await _capture("06_shop_noslot")
	await _show_tab(2)
	await _capture("07_coll_noslot")
	await _free_main()

	SaveManager.data = _saved_data
	_restore_save_file()
	print("bitti -> ", _out_dir)
	get_tree().quit()


func _make_main(fake: FakeAdBackend) -> void:
	_main_script.ads_backend_override = fake
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_main_script.ads_backend_override = null
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


## Banner'ın kaplayacağı bölge: alt kenardan safe_bottom (masaüstünde 0) kadar
## yukarıda, yuva yüksekliğinde plaka + etiket.
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


## Vitrin kayıt durumu (yalnızca bellekte): orta oyuncu.
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
