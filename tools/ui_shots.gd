extends Node
## Production UI kabugu QA cekimleri (M8.5-10). Dev araci — oyun calisirken
## kullanilmaz.
##
## `--headless` ILE CALISTIRILAMAZ (screenshot_runner.gd ile ayni sebep).
##
## Dort sekme, ayarlar penceresi, alt sekme cubugu ve urun akisi
## (Home -> Map -> Collection -> Shop -> Gameplay) ayni kayit durumuyla
## cekiliyor; ayni araci d214f63 (BEFORE) ve guncel agac (AFTER) uzerinde
## calistirip yan yana koymak icin yazildi. BEFORE agacinda olmayan seyler
## (ayarlar) `has_method` ile atlaniyor, arac iki agacta da calisiyor.
##
## KAYIT DOSYASI: `SaveManager.save_game()` CAGRILMAZ. En kotu durum
## degerleri (Hamur 99999, koleksiyon 20/20, stok x99) yalnizca bellekte
## degistirilip cekim sonunda geri konuyor (type_shots.gd ile ayni yontem).
## Yine de owner kaydi yedeklenmis olmali.
##
## Kullanim:
##   godot --path . res://tools/ui_shots.tscn -- <cikti_klasoru> [GxY]

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")

const SHOT_SIZE := Vector2i(540, 960)
const WORST_DOUGH: int = 99999
const WORST_STOCK: int = 99

var _out_dir: String = ""
var _main: Node2D


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(_shot_size(args))

	await get_tree().process_frame
	await _boot_main()
	await _shot_tabs("")
	await _shot_collection_equipped()
	await _shot_shop_scrolled("")
	await _shot_settings()
	await _shot_worst_case()
	await _shot_gameplay()
	print("bitti -> ", _out_dir)
	get_tree().quit()


func _shot_size(args: PackedStringArray) -> Vector2i:
	if args.size() < 2:
		return SHOT_SIZE
	var parts: PackedStringArray = args[1].split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		printerr("Olcu okunamadi (\"540x1170\" bekleniyor): ", args[1])
		return SHOT_SIZE
	return Vector2i(int(parts[0]), int(parts[1]))


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out_dir.path_join(file_name)
	var err: int = img.save_png(path)
	print(("kaydedildi : " if err == OK else "HATA       : "), path)


func _settle() -> void:
	# Gecis animasyonlari (varsa) bitsin; sabit 0.4 sn bekleme cekimi
	# deterministik tutuyor.
	await get_tree().create_timer(0.45).timeout
	await get_tree().process_frame


func _boot_main() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	if _main._daily != null:
		_main._daily.visible = false


func _show_tab(tab: int) -> void:
	_main._show_tab(tab)
	_main._tabs.set_active(tab)
	await _settle()


# --- Dort sekme ---

func _shot_tabs(suffix: String) -> void:
	var names: Array[String] = ["01_home", "02_map", "03_collection", "04_shop"]
	for tab in names.size():
		await _show_tab(tab)
		await _capture(names[tab] + suffix + ".png")


# --- Koleksiyon: takili skin ---

## Sahip olunan ilk skin takili gibi gosterilir; kayda YAZILMAZ.
func _shot_collection_equipped() -> void:
	var before: Variant = SaveManager.data.get("equipped_skin", "")
	var owned: Array = SaveManager.owned_skins()
	if owned.is_empty():
		SaveManager.data["unlocked_skins"] = ["common_01"]
		owned = SaveManager.owned_skins()
	SaveManager.data["equipped_skin"] = String(owned[0])
	await _show_tab(2)
	await _capture("06_collection_equipped.png")
	SaveManager.data["equipped_skin"] = before


# --- Magaza: guc kartlari ustte, skin listesi asagida ---

func _shot_shop_scrolled(suffix: String) -> void:
	await _show_tab(3)
	var shop: CanvasLayer = _main._screens[3]
	var scroll: ScrollContainer = shop.find_child("Scroll", true, false) as ScrollContainer
	await _capture("05_shop_power_cards" + suffix + ".png")
	if scroll != null:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await get_tree().process_frame
		await get_tree().process_frame
		await _capture("10_shop_long" + suffix + ".png")
		scroll.scroll_vertical = 0


# --- Ayarlar (yalnizca AFTER agacinda var) ---

func _shot_settings() -> void:
	await _show_tab(0)
	if not _main.has_method("open_settings"):
		print("ayarlar yok (BEFORE agaci) — atlandi")
		return
	_main.open_settings()
	await _settle()
	await _capture("08_settings.png")
	_main.close_settings()
	await _settle()


# --- En kotu durum: Hamur 99999, koleksiyon 20/20, stok x99 ---

func _shot_worst_case() -> void:
	var before: Dictionary = {
		"dough": SaveManager.data.get("dough", 0),
		"powerups": (SaveManager.data.get("powerups", {}) as Dictionary).duplicate(),
		"unlocked_skins": (SaveManager.data.get("unlocked_skins", []) as Array).duplicate(),
		"daily_streak": SaveManager.data.get("daily_streak", 0),
	}
	var stock: Dictionary = {}
	for type in PowerUp.all():
		stock[PowerUp.save_key(type)] = WORST_STOCK
	var all_ids: Array = []
	for skin in SkinLibrary.all():
		all_ids.append(String(skin.id))
	SaveManager.data["dough"] = WORST_DOUGH
	SaveManager.data["powerups"] = stock
	SaveManager.data["unlocked_skins"] = all_ids
	SaveManager.data["daily_streak"] = 365

	await _show_tab(0)
	await _capture("09_home_long.png")
	await _shot_shop_scrolled("_worst")
	await _show_tab(2)
	await _capture("11_collection_full.png")

	SaveManager.data["dough"] = before["dough"]
	SaveManager.data["powerups"] = before["powerups"]
	SaveManager.data["unlocked_skins"] = before["unlocked_skins"]
	SaveManager.data["daily_streak"] = before["daily_streak"]
	await _show_tab(0)


# --- Oyun ekrani: urun akisinin son karesi ---

func _shot_gameplay() -> void:
	_main.queue_free()
	await get_tree().process_frame
	var board: Node2D = GAME_BOARD_SCENE.instantiate()
	board.setup(load("res://resources/levels/level_03.tres"))
	add_child(board)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("12_gameplay.png")
	board.queue_free()
	await get_tree().process_frame
