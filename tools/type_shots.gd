extends Node
## Tipografi gorsel QA cekimleri (M8.5-09). Dev araci — oyun calisirken
## kullanilmaz.
##
## `--headless` ILE CALISTIRILAMAZ (screenshot_runner.gd ile ayni sebep):
## headless dummy rasterizer kullanir, cekimler bos cikar.
##
## Uc sey uretiyor, ucu de mevcut araclarin kapsamadigi:
##
##   1. Turkce glyph tablosu — İ ı Ş ş Ğ ğ Ç ç Ö ö Ü ü dort agirlikta yan yana.
##      `type_probe.gd` glyph'in font dosyasinda VAR oldugunu soyluyor;
##      burada dogru CIZILDIGI de goruluyor (nokta, cengel, kesme).
##   2. En kotu durum degerleri — Hamur 99999, guc stogu ×99. Owner'in
##      kaydinda bu degerler yok ve olusmasi icin haftalarca oynamak gerekir;
##      bunlar BELLEKTE uretiliyor, kayda YAZILMIYOR.
##   3. Gunluk odul penceresi — hicbir mevcut arac bunu cekmiyordu.
##
## KAYIT DOSYASI: bu arac SaveManager.save_game() CAGIRMAZ. Yalnizca
## `SaveManager.data` sozlugunu bellekte gecici olarak degistirip cekim
## sonunda geri koyuyor (screenshot_runner.gd'nin kilitli level cekimiyle
## ayni yontem). Yine de owner kaydi yedeklenmis olmali: oyunun baska
## kodlari (gunluk giris) kendiliginden yazabilir.
##
## Kullanim:
##   godot --path . res://tools/type_shots.tscn -- <cikti_klasoru> [GxY]

const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const DAILY_SCENE: PackedScene = preload("res://scenes/ui/daily_reward_popup.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const POWER_REFILL_SCENE: PackedScene = preload("res://scenes/ui/power_refill.tscn")

const BALOO_BOLD: FontFile = preload("res://assets/fonts/Baloo2-Bold.ttf")
const BALOO_EXTRABOLD: FontFile = preload("res://assets/fonts/Baloo2-ExtraBold.ttf")
const NUNITO_BOLD: FontFile = preload("res://assets/fonts/Nunito-Bold.ttf")
const NUNITO_SEMIBOLD: FontFile = preload("res://assets/fonts/Nunito-SemiBold.ttf")

const SHOT_SIZE := Vector2i(540, 960)

## En kotu durum degerleri. Hamur bes haneli, stoklar iki haneli — layout
## bozulacaksa burada bozulur.
const WORST_DOUGH: int = 99999
const WORST_STOCK: int = 99

var _out_dir: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(_shot_size(args))

	await get_tree().process_frame
	await _shot_glyphs()
	await _shot_daily()
	await _shot_worst_case_board()
	await _shot_worst_case_tabs()
	await _shot_worst_case_refill()
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


# --- 1) Turkce glyph tablosu ---

## Dort agirlik, uc satir: buyuk harfler, kucuk harfler ve UI isaretleri.
## "İ" ile "I", "ı" ile "i" YAN YANA yaziliyor — noktali/noktasiz ayrimi
## ancak boyle dogrulanabiliyor.
const GLYPH_ROWS: Array[String] = [
	"İ I Ş Ğ Ç Ö Ü",
	"ı i ş ğ ç ö ü",
	"Şişli Ğ ğ · × • … —",
	"Büyütücü Temizleyici Sarsıntı",
]


func _shot_glyphs() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.13, 0.12, 0.16)
	root.add_child(bg)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 20.0
	column.offset_top = 20.0
	column.offset_right = -20.0
	column.add_theme_constant_override("separation", 6)
	root.add_child(column)

	var fonts: Array = [
		["Baloo 2 ExtraBold", BALOO_EXTRABOLD, 30],
		["Baloo 2 Bold", BALOO_BOLD, 30],
		["Nunito Bold", NUNITO_BOLD, 26],
		["Nunito SemiBold", NUNITO_SEMIBOLD, 26],
	]
	for entry: Array in fonts:
		var head := Label.new()
		head.text = "— %s —" % entry[0]
		head.add_theme_font_override("font", NUNITO_BOLD)
		head.add_theme_font_size_override("font_size", 15)
		head.modulate = Color(1, 0.85, 0.55)
		column.add_child(head)
		for row: String in GLYPH_ROWS:
			var label := Label.new()
			label.text = row
			label.add_theme_font_override("font", entry[1])
			label.add_theme_font_size_override("font_size", entry[2])
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			column.add_child(label)

	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("t01_turkce_glyph.png")
	root.queue_free()
	await get_tree().process_frame


# --- 2) Gunluk odul penceresi ---

## Seri 4: dort dolu, uc bos nokta. Sayacin iki rengi de tek karede.
func _shot_daily() -> void:
	var popup: CanvasLayer = DAILY_SCENE.instantiate()
	add_child(popup)
	await get_tree().process_frame
	popup.show_reward({"reward": 15, "streak": 4, "streak_broken": false})
	await get_tree().process_frame
	await _capture("t02_gunluk_odul.png")
	popup.queue_free()
	await get_tree().process_frame


# --- 3) En kotu durum: oyun ekrani ---

## Guc stoklari ×99, Hamur 99999. Degerler BELLEKTE degistiriliyor,
## `save_game()` cagrilmiyor; cekim sonunda eski hallerine donuyorlar.
func _shot_worst_case_board() -> void:
	var restore: Dictionary = _push_worst_case()

	var board: Node2D = GAME_BOARD_SCENE.instantiate()
	board.setup(load("res://resources/levels/level_10.tres"))
	add_child(board)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("t03_en_kotu_oyun_hud.png")
	board.queue_free()
	await get_tree().process_frame

	_pop_worst_case(restore)


## Ana kabuk: dort sekmenin de Hamur satiri bes haneli.
func _shot_worst_case_tabs() -> void:
	var restore: Dictionary = _push_worst_case()

	var main: Node2D = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	if main._daily != null:
		main._daily.visible = false

	var names: Array[String] = ["t04_en_kotu_ana_sayfa", "t05_en_kotu_harita",
		"t06_en_kotu_koleksiyon", "t07_en_kotu_magaza"]
	for tab in names.size():
		main._show_tab(tab)
		main._tabs.set_active(tab)
		await get_tree().process_frame
		await get_tree().process_frame
		await _capture(names[tab] + ".png")

	main.queue_free()
	await get_tree().process_frame
	_pop_worst_case(restore)


## Refill penceresi EN UZUN gucle: "Temizleyici bitti" + "+1 Temizleyici".
## Saglayici yok (production durumu) — pasif CTA'nin kontrasti da burada
## goruluyor.
func _shot_worst_case_refill() -> void:
	var restore: Dictionary = _push_worst_case()
	# Stok 0 olmali: pencere zaten bu durumda aciliyor.
	var stock: Dictionary = (SaveManager.data["powerups"] as Dictionary).duplicate()
	stock[PowerUp.save_key(PowerUp.Type.CLEAR_SMALL)] = 0
	SaveManager.data["powerups"] = stock

	var refill: CanvasLayer = POWER_REFILL_SCENE.instantiate()
	add_child(refill)
	await get_tree().process_frame
	refill.show_refill(PowerUp.Type.CLEAR_SMALL, false)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("t08_en_kotu_refill.png")
	refill.queue_free()
	await get_tree().process_frame
	_pop_worst_case(restore)


## Kayit sozlugunu BELLEKTE en kotu duruma alir, eski degerleri dondurur.
func _push_worst_case() -> Dictionary:
	var before: Dictionary = {
		"dough": SaveManager.data.get("dough", 0),
		"powerups": (SaveManager.data.get("powerups", {}) as Dictionary).duplicate(),
	}
	var stock: Dictionary = {}
	for type in PowerUp.all():
		stock[PowerUp.save_key(type)] = WORST_STOCK
	SaveManager.data["dough"] = WORST_DOUGH
	SaveManager.data["powerups"] = stock
	return before


func _pop_worst_case(before: Dictionary) -> void:
	SaveManager.data["dough"] = before["dough"]
	SaveManager.data["powerups"] = before["powerups"]
