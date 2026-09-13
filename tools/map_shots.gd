extends Node
## Harita ekrani QA cekimleri (M8.5-12). Dev araci — oyun calisirken
## kullanilmaz. `--headless` ILE CALISTIRILAMAZ.
##
## Uc kayit durumu BELLEKTE kuruluyor (save_game CAGRILMAZ, cekim sonunda
## eski degerler geri konuyor):
##   owner   : kayit oldugu gibi (owner'da 10/10 tamam, sonsuz acik)
##   mid     : level 1-3 tamam (2/3/3 yildiz), sıradaki 4, 5-10 kilitli
##   fresh   : hicbir sey oynanmamis, sıradaki 1
## Ayrica `unlock`: mid durumundan level 4 bitmis gibi tazeleme — acilis
## animasyonunun ortasi (BEFORE agacinda animasyon yok, ayni kare cekilir).
##
## Kullanim:
##   godot --path . res://tools/map_shots.tscn -- <cikti_klasoru> [GxY]

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SHOT_SIZE := Vector2i(540, 960)

var _out_dir: String = ""
var _main: Node2D


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(_shot_size(args))
	await get_tree().process_frame

	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	if _main._daily != null:
		_main._daily.visible = false

	var before: Dictionary = {
		"highest_level_unlocked": SaveManager.data.get("highest_level_unlocked", 1),
		"level_stars": (SaveManager.data.get("level_stars", {}) as Dictionary).duplicate(),
	}

	await _show_map()
	await _capture("m01_owner.png")

	_set_progress(4, {"1": 2, "2": 3, "3": 3})
	await _show_map()
	await _capture("m02_mid_current4.png")

	_set_progress(1, {})
	await _show_map()
	await _capture("m03_fresh.png")

	# Acilis animasyonu: mid durumunu goster, sonra level 4 tamamlanmis gibi
	# tazele ve animasyonun ortasinda cek.
	_set_progress(4, {"1": 2, "2": 3, "3": 3})
	await _show_map()
	_set_progress(5, {"1": 2, "2": 3, "3": 3, "4": 3})
	_main._screens[1].refresh()
	await get_tree().create_timer(0.18).timeout
	await _capture("m04_unlock_mid.png")
	await get_tree().create_timer(0.6).timeout
	await _capture("m05_unlock_done.png")

	SaveManager.data["highest_level_unlocked"] = before["highest_level_unlocked"]
	SaveManager.data["level_stars"] = before["level_stars"]
	print("bitti -> ", _out_dir)
	get_tree().quit()


func _set_progress(highest: int, stars: Dictionary) -> void:
	SaveManager.data["highest_level_unlocked"] = highest
	SaveManager.data["level_stars"] = stars


func _show_map() -> void:
	_main._show_tab(0)
	await get_tree().process_frame
	_main._show_tab(1)
	_main._tabs.set_active(1)
	await get_tree().create_timer(0.9).timeout
	await get_tree().process_frame


func _shot_size(args: PackedStringArray) -> Vector2i:
	if args.size() < 2:
		return SHOT_SIZE
	var parts: PackedStringArray = args[1].split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return SHOT_SIZE
	return Vector2i(int(parts[0]), int(parts[1]))


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(_out_dir.path_join(file_name))
	print(("kaydedildi : " if err == OK else "HATA       : "), file_name)
