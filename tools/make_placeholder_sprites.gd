extends SceneTree
## Kenney "Shape Characters" (CC0) paketinden placeholder dumpling sprite'larini
## uretir. Tek seferlik/tekrar calistirilabilir bir arac — oyun calisirken
## kullanilmaz.
##
## Neden gerekli: Kenney govdeleri sabit renkli (mavi/sari/pembe...). Bizim
## per-tier paletimiz (TierConfig.TIERS) modulate ile uygulanacagi icin govdenin
## NOTR (gri) olmasi gerekiyor; renkli bir govdeyi tint'lemek rengi kirletirdi.
## Burada govde luminansa cevrilip baskin dolgu tonu 1.0'a normalize ediliyor —
## boylece modulate = palet rengi, parlaklik/golge gradyani korunuyor.
##
## Calistirma:
##   godot --headless --path . --script res://tools/make_placeholder_sprites.gd
##
## Kaynak paketin `_visual_source/` altinda acilmis olmasi gerekir (gitignore'lu).

const SRC := "res://_visual_source/kenney_shape-characters/PNG/Double/"
const OUT := "res://assets/visual/"

## Govde kaynagi: sari en genis luminans araligina sahip, normalize edince
## gradyan en az bilgi kaybiyla kaliyor.
const BODY_SRC := "yellow_body_circle.png"
## Yuz: kapali mutlu gozler + gulumseme. Kucuk boyutta da okunan tek stil
## (GAME_DESIGN §1 kawaii/cozy yonu). 8 ayri ifade v1 icin gereksiz.
const FACE_SRC := "face_l.png"


func _initialize() -> void:
	var ok := true
	ok = _make_body() and ok
	ok = _copy_face() and ok
	print("SONUC: ", "OK" if ok else "HATA")
	quit(0 if ok else 1)


func _luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func _make_body() -> bool:
	var path := ProjectSettings.globalize_path(SRC + BODY_SRC)
	var img := Image.load_from_file(path)
	if img == null:
		printerr("Govde kaynagi okunamadi: ", path)
		return false
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()

	# Baskin dolgu tonunu bul (256 kovali histogram, sadece opak pikseller).
	var hist := PackedInt32Array()
	hist.resize(256)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < 0.99:
				continue
			var b := clampi(int(_luminance(c) * 255.0), 0, 255)
			hist[b] += 1
	var fill := 0
	var best := 0
	for i in 256:
		if hist[i] > best:
			best = hist[i]
			fill = i
	if fill <= 0:
		printerr("Baskin dolgu tonu bulunamadi.")
		return false
	var scale := 255.0 / float(fill)

	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var v := clampf(_luminance(c) * scale, 0.0, 1.0)
			out.set_pixel(x, y, Color(v, v, v, c.a))
	var dst := ProjectSettings.globalize_path(OUT + "dumpling_body.png")
	var err := out.save_png(dst)
	if err != OK:
		printerr("Govde yazilamadi: ", dst)
		return false
	print("govde  : %s  %dx%d  (baskin ton %d -> 255, olcek %.3f)" % [dst.get_file(), w, h, fill, scale])
	return true


func _copy_face() -> bool:
	var path := ProjectSettings.globalize_path(SRC + FACE_SRC)
	var img := Image.load_from_file(path)
	if img == null:
		printerr("Yuz kaynagi okunamadi: ", path)
		return false
	img.convert(Image.FORMAT_RGBA8)
	var dst := ProjectSettings.globalize_path(OUT + "dumpling_face.png")
	if img.save_png(dst) != OK:
		printerr("Yuz yazilamadi: ", dst)
		return false
	print("yuz    : %s  %dx%d  (kaynak %s, tint uygulanmaz)" % [dst.get_file(), img.get_width(), img.get_height(), FACE_SRC])
	return true
