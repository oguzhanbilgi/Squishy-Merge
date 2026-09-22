extends Node
## Mağaza QA çekimleri (M8.6-05). Dev aracı — oyun çalışırken kullanılmaz.
## `--headless` İLE ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn` deterministik vitrin kayıt durumlarıyla çekiliyor.
## KAYIT: 05 (güç) ve 08/09 hazırlığı (skin) için gerçek satın alma yolu
## KOŞAR (kayda yazar). Araç kayıt dosyasını başta byte olarak okur, çıkışta
## AYNEN geri yazar; vitrin değerleri bellekte ve çıkışta geri konur.
##
##   01_shop_top_mid_player     orta oyuncu: 335 Hamur, 4 skin (rare_02 takılı), stok 3/1/0/2
##   02_shop_top_fresh_player   yeni oyuncu: 0 Hamur, skin yok, stok 1/1/1/1 (hepsi "yetmiyor")
##   03_shop_power_zero_stock   dört gücün stoğu 0, 500 Hamur (ürün yine alınabilir)
##   04_shop_power_pressed      Bomba SATIN AL basılı (gerçek fare olayı)
##   05_shop_power_after_purchase  Bomba onay → SATIN AL → pop + pırıltı + plaka
##   06_shop_insufficient_dough 80 Hamur ile Bomba'ya dokunuş: sallanma + pembe plaka
##   07_shop_skin_common_locked kilitli Common kartlar (yeni oyuncu, 120 Hamur)
##   08_shop_skin_owned         sahip olunan Common kartlar (SAHİPSİN)
##   09_shop_skin_equipped      takılı skin kartı (TAKILI, rare_02)
##   10_shop_skin_rare          Rare bölümü
##   11_shop_skin_epic          Epic bölümü
##   12_shop_skin_legendary     Legendary bölümü
##   13_shop_scrolled_mid       kaydırma %45
##   14_shop_scrolled_bottom    kaydırma sonu (alt pay)
##   15_shop_confirm_power      güç onay penceresi
##   16_shop_confirm_skin       skin onay penceresi
##   17_back_home               geri → Ana Sayfa (rota hedefi)
##
## Kullanım:
##   godot --path . res://tools/shop_shots.tscn -- <çıktı_klasörü> [GxY] [safe=61]
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
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://shop_shots")
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
		_shop()._layout_with_safe_top(_safe_top)
		_main._screens[0]._layout_with_safe_top(_safe_top)

	_apply_mid()
	await _show_shop()
	await _capture("01_shop_top_mid_player")
	_apply_fresh()
	await _show_shop()
	await _capture("02_shop_top_fresh_player")
	_apply_mid()
	SaveManager.data["dough"] = 500
	SaveManager.data["powerups"] = {"bomb": 0, "upgrade": 0, "shake": 0, "clear_small": 0}
	await _show_shop()
	await _capture("03_shop_power_zero_stock")

	_apply_mid()
	await _show_shop()
	await _shot_pressed(_shop().power_card(PowerUp.Type.BOMB).buy_button(), "04_shop_power_pressed")
	# Gerçek satın alma yolu (kayda yazar, sonda geri konur).
	await _show_shop()
	_shop()._open_power_confirm(PowerUp.Type.BOMB)
	await _settle()
	await _capture("15_shop_confirm_power")
	_shop()._confirm_yes.pressed.emit()
	await get_tree().create_timer(0.16).timeout
	await _capture("05_shop_power_after_purchase")
	await _settle()

	_apply_mid()
	SaveManager.data["dough"] = 80
	await _show_shop()
	_shop().power_card(PowerUp.Type.BOMB).buy_button().pressed.emit()
	await get_tree().create_timer(0.2).timeout
	await _capture("06_shop_insufficient_dough")
	await _settle()

	_apply_fresh()
	SaveManager.data["dough"] = 120
	await _show_shop()
	await _scroll_to(_shop().skin_card(&"common_01"))
	await _capture("07_shop_skin_common_locked")
	_apply_mid()
	await _show_shop()
	await _scroll_to(_shop().skin_card(&"common_01"))
	await _capture("08_shop_skin_owned")
	await _scroll_to(_shop().skin_card(&"rare_01"))
	await _capture("09_shop_skin_equipped")
	await _scroll_to(_shop().skin_card(&"rare_03"))
	await _capture("10_shop_skin_rare")
	await _scroll_to(_shop().skin_card(&"epic_01"))
	await _capture("11_shop_skin_epic")
	await _scroll_to(_shop().skin_card(&"legendary_01"))
	await _capture("12_shop_skin_legendary")
	# Onay yalnız Hamur yetiyorken açılır: pencere kendi içinde tutarlı olsun.
	SaveManager.data["dough"] = 1200
	_shop().refresh()
	await _scroll_to(_shop().skin_card(&"legendary_01"))
	_shop()._open_confirm(SkinLibrary.find(&"legendary_01"))
	await _settle()
	await _capture("16_shop_confirm_skin")
	_shop()._close_confirm()
	await _settle()

	_apply_mid()
	await _show_shop()
	var scroll: ScrollContainer = _shop().scroll()
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value * 0.45)
	await _settle()
	await _capture("13_shop_scrolled_mid")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _settle()
	await _capture("14_shop_scrolled_bottom")

	await _show_shop()
	_shop().top_bar().back_button().pressed.emit()
	await _settle()
	await _capture("17_back_home")

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


func _show_shop() -> void:
	_main._show_tab(0)
	await get_tree().process_frame
	_main._show_tab(3)
	await _settle()


func _shop() -> CanvasLayer:
	return _main._screens[3]


## Kartı üst satırın 24 px altına getirecek şekilde kaydırır.
func _scroll_to(card: Control) -> void:
	if card == null:
		return
	var scroll: ScrollContainer = _shop().scroll()
	var target: float = card.global_position.y - (_shop().top_bar().height() + 24.0)
	scroll.scroll_vertical = int(scroll.scroll_vertical + target)
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
	# Basış bırakılınca onay açılmış olabilir (fare dışarıda bırakıldı: açılmaz).
	if _shop().is_confirm_open():
		_shop()._close_confirm()
		await _settle()


func _mouse(at: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)
