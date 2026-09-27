extends Node
## Koleksiyon QA çekimleri (M8.6-06; TASK/044 albüm + parça detayı). Dev aracı —
## oyun çalışırken kullanılmaz. `--headless` İLE ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn` deterministik kayıt durumlarıyla çekiliyor. KAYIT: 13
## (VİTRİNE EKLE) ve 12 (değiştirme adımı) gerçek vitrin yolunu KOŞAR (kayda
## yazar). Araç kayıt dosyasını başta byte olarak okur, çıkışta AYNEN geri yazar;
## durum değerleri bellekte ve çıkışta geri konur.
##
##   01_fresh                 yeni oyuncu: 0 Hamur, parça yok, 0/20, VİTRİN 0/3
##   02_partial               orta oyuncu: 335 Hamur, 4 parça, 4/20, vitrinde rare_02
##   03_complete              20/20 (altın ray + yıldız), vitrin 3/3
##   04_scroll_mid            albüm kaydırma %45 (orta oyuncu)
##   05_scroll_bottom         albüm kaydırma sonu
##   06_detail_locked         kilitli Common detayı (KİLİTLİ, fiyat notu, MAĞAZAYA GİT)
##   07_detail_locked_legend  kilitli Legendary detayı (altın hale + bloom)
##   08_detail_owned          sahip Epic detayı (SAHİPSİN, VİTRİNE EKLE)
##   09_detail_avatar         vitrin başı (VİTRİNDE, avatar notu, VİTRİNDEN ÇIKAR)
##   10_detail_slot2          vitrinin 2. yuvası (AVATAR YAP + VİTRİNDEN ÇIKAR)
##   11_detail_full           vitrin dolu: sahip parça ("Vitrinin dolu (3/3)")
##   12_detail_replace        dolu vitrinde VİTRİNE EKLE → AÇIK değiştirme adımı
##   13_showcase_added        VİTRİNE EKLE → kutlama (pop + yıldız patlaması)
##   14_card_pressed          albüm kartı basılı (gerçek fare olayı)
##   15_shop_route            MAĞAZAYA GİT → Mağaza (rota hedefi)
##
## Kullanım:
##   godot --resolution GxY --path . res://tools/collection_shots.tscn -- <çıktı_klasörü> [GxY] [safe=61]
## `safe=N`: A36 punch-hole payı simülasyonu (tuval px; dosya adına `_a36`).
## `--resolution` ŞART (TASK/044): pencere yöneticisiz X (xvfb) çalışma anındaki
## `window_set_size`'ı yok sayar — yalnız argüman verilirse kare istenen boyutta
## çıkar; araç boyut tutmazsa uyarı basar.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SHOT_SIZE := Vector2i(720, 1280)

var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _main: Node2D
var _saved_data: Dictionary = {}
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _safe_top: float = -1.0


func _ready() -> void:
	# Otomatik GÜNLÜK ÖDÜLLER penceresi (M8.9-02) bu harness'in konusu değil.
	DailyRewards.auto_popup_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://collection_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_size = _shot_size(args)
	for arg in args:
		if String(arg).begins_with("safe="):
			_safe_top = float(String(arg).trim_prefix("safe="))
	DisplayServer.window_set_size(_size)
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.window_get_size() != _size:
		push_warning("pencere %s istendi, %s çalışıyor — `--resolution %dx%d` ile başlatın" % [
			str(_size), str(DisplayServer.window_get_size()), _size.x, _size.y])

	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_saved_data = SaveManager.data.duplicate(true)
	# main._ready günlük ödülü bugün alınmış saysın (kayda yazmasın).
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	# M8.10: bu harness KABUGU ölçüyor — onboarding tamamlanmış olmalı.
	SaveManager.data["onboarding_completed"] = true

	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	if _safe_top >= 0.0:
		_screen()._layout_with_safe_top(_safe_top)
		_main._screens[0]._layout_with_safe_top(_safe_top)
		_main._screens[3]._layout_with_safe_top(_safe_top)

	_apply_fresh()
	await _show()
	await _capture("01_fresh")
	_apply_mid()
	await _show()
	await _capture("02_partial")
	_apply_full()
	await _show()
	await _capture("03_complete")

	_apply_mid()
	await _show()
	var scroll: ScrollContainer = _screen().scroll()
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value * 0.45)
	await _settle()
	await _capture("04_scroll_mid")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _settle()
	await _capture("05_scroll_bottom")

	await _show()
	await _detail(&"common_03")
	await _capture("06_detail_locked")
	await _detail(&"legendary_02")
	await _capture("07_detail_locked_legend")
	await _detail(&"epic_01")
	await _capture("08_detail_owned")
	await _detail(&"rare_02")
	await _capture("09_detail_avatar")

	_apply_mid()
	SaveManager.data["profile_showcase"] = ["rare_02", "epic_01"]
	await _show()
	await _detail(&"epic_01")
	await _capture("10_detail_slot2")

	_apply_mid()
	SaveManager.data["profile_showcase"] = ["rare_02", "epic_01", "common_01"]
	await _show()
	await _detail(&"common_02")
	await _capture("11_detail_full")
	_screen().detail_primary().pressed.emit()
	await _settle()
	await _capture("12_detail_replace")

	_apply_mid()
	await _show()
	await _detail(&"epic_01")
	_screen().detail_primary().pressed.emit()
	await get_tree().create_timer(0.16).timeout
	await _capture("13_showcase_added")
	await _settle()

	_apply_mid()
	await _show()
	await _shot_pressed(_screen().card(&"common_01"), "14_card_pressed")
	_screen().close_detail(false)

	await _show()
	await _detail(&"legendary_02")
	_screen().detail_primary().pressed.emit()
	await _settle()
	await _capture("15_shop_route")

	SaveManager.data = _saved_data
	_restore_save_file()
	print("bitti -> ", _out_dir)
	get_tree().quit()


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
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame


func _show() -> void:
	_main._show_tab(0)
	await get_tree().process_frame
	_main._show_tab(2)
	await _settle()


func _screen() -> CanvasLayer:
	return _main._screens[2]


## Karta dokunuş yolu (albüm kartı → detay penceresi).
func _detail(id: StringName) -> void:
	_screen().close_detail(false)
	_screen().card(id).pressed.emit()
	await _settle()


# --- Kayıt durumları (yalnızca bellekte) ---

func _apply_mid() -> void:
	SaveManager.data["highest_level_unlocked"] = 4
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3}
	SaveManager.data["dough"] = 335
	SaveManager.data["unlocked_skins"] = ["common_01", "common_02", "rare_02", "epic_01"]
	SaveManager.data["profile_showcase"] = ["rare_02"]
	SaveManager.data["powerups"] = {"bomb": 3, "upgrade": 1, "shake": 0, "clear_small": 2}
	SaveManager.data["daily_streak"] = 2
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()


func _apply_fresh() -> void:
	SaveManager.data["highest_level_unlocked"] = 1
	SaveManager.data["level_stars"] = {}
	SaveManager.data["dough"] = 0
	SaveManager.data["unlocked_skins"] = []
	SaveManager.data["profile_showcase"] = []
	SaveManager.data["powerups"] = {"bomb": 1, "upgrade": 1, "shake": 1, "clear_small": 1}
	SaveManager.data["daily_streak"] = 0
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()


func _apply_full() -> void:
	_apply_mid()
	var all: Array = []
	for skin in SkinLibrary.all():
		all.append(String(skin.id))
	SaveManager.data["unlocked_skins"] = all
	SaveManager.data["profile_showcase"] = ["legendary_02", "epic_03", "rare_02"]
	SaveManager.data["dough"] = 1240


# --- Durumlar ---

## Gerçek basış: fare olayı butonun merkezine (pressed gövde + basış ölçeği).
## Tuval -> pencere pikseli (1080x2340'ta tuval 1.5x küçük).
func _shot_pressed(button: BaseButton, name: String) -> void:
	if button == null:
		print(name, ": buton bulunamadı — atlandı")
		return
	var k: float = float(DisplayServer.window_get_size().x) / get_viewport().get_visible_rect().size.x
	var at: Vector2 = button.get_global_rect().get_center() * k
	_mouse(at, true)
	for i in 8:
		await get_tree().process_frame
	await _capture(name)
	_mouse(Vector2(-10, -10), false)
	await _settle()


func _mouse(at: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)
