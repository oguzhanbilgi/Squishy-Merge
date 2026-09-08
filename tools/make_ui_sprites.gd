extends SceneTree
## Wenrexa "UI Mobile" (CC0) paketinden UI tema sprite'larini uretir.
## Tek seferlik/tekrar calistirilabilir bir arac — oyun calisirken kullanilmaz.
##
## Neden kirpiliyor: kaynak PNG'lerde gorunur grafigin etrafinda genis seffaf
## dolgu var (orn. Button11 308x87 tuvalde buton sadece y=18..70 arasinda).
## 9-patch paylari bu dolguyu da esnetirdi ve butonun gorunur yuksekligi
## Control dikdortgeninden kucuk kalirdi. Opak siniri bulup kirpmak bunu
## ortadan kaldiriyor; yumusak golge alpha>0 oldugu icin korunuyor.
##
## Calistirma:
##   godot --headless --path . --script res://tools/make_ui_sprites.gd
##
## Kaynak paketin `_visual_source/` altinda acilmis olmasi gerekir (gitignore'lu).

const SRC := "res://_visual_source/wenrexa_uimobile/PNG/"
const OUT := "res://assets/visual/ui/"

## Alpha bu esigin altindaki pikseller "bos" sayilir (yumusak golgeyi korur).
const ALPHA_CUTOFF: float = 0.03

## Secim gerekcesi assets/visual/CREDITS.md'de.
const ITEMS: Array[Dictionary] = [
	{"src": "Button11.png", "out": "wenrexa_button.png"},
	{"src": "Msg17.png",    "out": "wenrexa_panel.png"},
]


func _initialize() -> void:
	var ok := true
	for entry in ITEMS:
		ok = _crop(entry["src"], entry["out"]) and ok
	print("SONUC: ", "OK" if ok else "HATA")
	quit(0 if ok else 1)


func _crop(src_name: String, out_name: String) -> bool:
	var path := ProjectSettings.globalize_path(SRC + src_name)
	var img := Image.load_from_file(path)
	if img == null:
		printerr("Kaynak okunamadi: ", path)
		return false
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()

	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a <= ALPHA_CUTOFF:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < 0:
		printerr("Tamamen seffaf: ", src_name)
		return false

	var region := Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	var out := img.get_region(region)
	var dst := ProjectSettings.globalize_path(OUT + out_name)
	if out.save_png(dst) != OK:
		printerr("Yazilamadi: ", dst)
		return false
	print("%-20s <- %-14s %dx%d -> %dx%d  (kirpma %s)" % [
		out_name, src_name, w, h, region.size.x, region.size.y, region])
	return true
