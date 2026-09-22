extends Node
## Koleksiyon QA çekimleri (M8.6-06). Dev aracı — oyun çalışırken kullanılmaz.
## `--headless` İLE ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn` deterministik vitrin kayıt durumlarıyla çekiliyor.
## KAYIT: 15/16 (TAK) için gerçek equip yolu KOŞAR (kayda yazar). Araç kayıt
## dosyasını başta byte olarak okur, çıkışta AYNEN geri yazar; vitrin
## değerleri bellekte ve çıkışta geri konur.
##
##   01_fresh                 yeni oyuncu: 0 Hamur, skin yok, Varsayılan takılı, 0/20
##   02_mid_player            orta oyuncu: 335 Hamur, 4 skin, rare_02 takılı, 4/20
##   03_common_equipped       Common (Susamlı) takılı
##   04_common_owned          Common sahip, takılı değil (TAK)
##   05_common_locked         Common kilitli seçili (MAĞAZAYA GİT)
##   06_rare_selected         Rare sahip seçili
##   07_rare_locked           Rare kilitli seçili
##   08_epic_selected         Epic sahip seçili
##   09_epic_locked           Epic kilitli seçili
##   10_legendary_locked      Legendary kilitli seçili (Gökkuşağı)
##   11_legendary_owned       Legendary sahip, takılı değil (Altın Hamur)
##   12_legendary_equipped    Legendary takılı
##   13_full_20               20/20 koleksiyon (altın ilerleme)
##   14_card_pressed          kart basılı (gerçek fare olayı)
##   15_tak_pressed           TAK basılı
##   16_equip_success         TAK → takıldı (pop + pırıltı + TAKILI)
##   17_locked_cta            kilitli seçili + MAĞAZAYA GİT (Legendary)
##   18_scroll_mid            galeri kaydırma %45
##   19_scroll_bottom         galeri kaydırma sonu
##   20_shop_route            MAĞAZAYA GİT → Mağaza (rota hedefi)
##
## Kullanım:
##   godot --path . res://tools/collection_shots.tscn -- <çıktı_klasörü> [GxY] [safe=61]
## `safe=N`: A36 punch-hole payı simülasyonu (tuval px; dosya adına `_a36`).

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

	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_saved_data = SaveManager.data.duplicate(true)
	# main._ready günlük ödülü bugün alınmış saysın (kayda yazmasın).
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()

	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	if _main._daily != null:
		_main._daily.visible = false
	if _safe_top >= 0.0:
		_screen()._layout_with_safe_top(_safe_top)
		_main._screens[0]._layout_with_safe_top(_safe_top)
		_main._screens[3]._layout_with_safe_top(_safe_top)

	_apply_fresh()
	await _show()
	await _capture("01_fresh")
	_apply_mid()
	await _show()
	await _capture("02_mid_player")

	_apply_mid()
	SaveManager.data["equipped_skin"] = "common_02"
	await _show()
	await _capture("03_common_equipped")
	await _select(&"common_01")
	await _capture("04_common_owned")
	await _select(&"common_03")
	await _capture("05_common_locked")
	await _select(&"rare_02")
	await _capture("06_rare_selected")
	await _select(&"rare_01")
	await _capture("07_rare_locked")
	await _select(&"epic_01")
	await _capture("08_epic_selected")
	await _select(&"epic_03")
	await _capture("09_epic_locked")
	await _select(&"legendary_02")
	await _capture("10_legendary_locked")
	await _capture("17_locked_cta")

	_apply_mid()
	SaveManager.data["unlocked_skins"].append("legendary_01")
	await _show()
	await _select(&"legendary_01")
	await _capture("11_legendary_owned")
	SaveManager.data["equipped_skin"] = "legendary_01"
	await _show()
	await _capture("12_legendary_equipped")

	_apply_full()
	await _show()
	await _capture("13_full_20")

	_apply_mid()
	await _show()
	await _shot_pressed(_screen().card(&"common_01"), "14_card_pressed")
	await _select(&"common_01")
	await _shot_pressed(_screen().cta(), "15_tak_pressed")
	# Gerçek equip yolu (kayda yazar, sonda geri konur). Basılı çekimin
	# bırakılışı equip'i tetiklemiş olabilir: durum sıfırdan kurulur.
	_apply_mid()
	await _show()
	await _select(&"common_01")
	_screen().cta().pressed.emit()
	await get_tree().create_timer(0.14).timeout
	await _capture("16_equip_success")
	await _settle()

	_apply_mid()
	await _show()
	var scroll: ScrollContainer = _screen().scroll()
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value * 0.45)
	await _settle()
	await _capture("18_scroll_mid")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _settle()
	await _capture("19_scroll_bottom")

	await _show()
	await _select(&"legendary_02")
	_screen().cta().pressed.emit()
	await _settle()
	await _capture("20_shop_route")

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


func _select(id: StringName) -> void:
	_screen().select(id, true)
	await _settle()


# --- Vitrin kayıt durumları (yalnızca bellekte) ---

func _apply_mid() -> void:
	SaveManager.data["highest_level_unlocked"] = 4
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3}
	SaveManager.data["dough"] = 335
	SaveManager.data["unlocked_skins"] = ["common_01", "common_02", "rare_02", "epic_01"]
	SaveManager.data["equipped_skin"] = "rare_02"
	SaveManager.data["powerups"] = {"bomb": 3, "upgrade": 1, "shake": 0, "clear_small": 2}
	SaveManager.data["daily_streak"] = 2
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()


func _apply_fresh() -> void:
	SaveManager.data["highest_level_unlocked"] = 1
	SaveManager.data["level_stars"] = {}
	SaveManager.data["dough"] = 0
	SaveManager.data["unlocked_skins"] = []
	SaveManager.data["equipped_skin"] = ""
	SaveManager.data["powerups"] = {"bomb": 1, "upgrade": 1, "shake": 1, "clear_small": 1}
	SaveManager.data["daily_streak"] = 0
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()


func _apply_full() -> void:
	_apply_mid()
	var all: Array = []
	for skin in SkinLibrary.all():
		all.append(String(skin.id))
	SaveManager.data["unlocked_skins"] = all
	SaveManager.data["equipped_skin"] = "legendary_02"
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
