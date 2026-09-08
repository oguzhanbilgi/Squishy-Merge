extends SceneTree
## Kenney "Particle Pack" (CC0) paketinden juice/polish (M8) icin gereken
## parcacik sprite'larini uretir, ayrica dumpling parlama overlay'ini cizer.
## Tek seferlik/tekrar calistirilabilir bir arac — oyun calisirken kullanilmaz.
##
## Calistirma:
##   godot --headless --path . --script res://tools/make_fx_sprites.gd
##
## Kaynak paketin `_visual_source/` altinda acilmis olmasi gerekir (gitignore'lu).

const SRC := "res://_visual_source/kenney_particle-pack/PNG (Transparent)/"
const OUT := "res://assets/visual/fx/"

## Kaynaklar 512x512 — parcacik olarak bu cok buyuk (hem APK hem overdraw).
## Ekranda hicbiri ~140 px'i gecmiyor, bu yuzden kucultuluyor.
const RESIZES: Array[Dictionary] = [
	{"src": "circle_01.png", "out": "fx_dot.png",     "size": 128},
	{"src": "star_04.png",   "out": "fx_sparkle.png", "size": 128},
	{"src": "star_08.png",   "out": "fx_burst.png",   "size": 256},
]

## Parlama overlay'i govde texture'uyla ayni olcude uretiliyor ki
## dumpling_visual.gd ikisine de ayni olcegi uygulayabilsin.
const GLOSS_SIZE: int = 160
const GLOSS_OUT := "dumpling_gloss.png"


func _initialize() -> void:
	var ok := true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for entry in RESIZES:
		ok = _resize(entry["src"], entry["out"], entry["size"]) and ok
	ok = _make_gloss() and ok
	print("SONUC: ", "OK" if ok else "HATA")
	quit(0 if ok else 1)


func _resize(src_name: String, out_name: String, size: int) -> bool:
	var path := ProjectSettings.globalize_path(SRC + src_name)
	var img := Image.load_from_file(path)
	if img == null:
		printerr("Kaynak okunamadi: ", path)
		return false
	img.convert(Image.FORMAT_RGBA8)
	var was := img.get_width()
	img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	var dst := ProjectSettings.globalize_path(OUT + out_name)
	if img.save_png(dst) != OK:
		printerr("Yazilamadi: ", dst)
		return false
	print("%-16s <- %-16s %dx%d -> %dx%d" % [out_name, src_name, was, was, size, size])
	return true


## Dumpling parlama overlay'i: sol-ustte, hafif egik, yumusak kenarli beyaz
## bir elips. Yeni asset gerektirmeden duz vektor gorunumunu kirip "cilali"
## his veriyor (GAME_DESIGN.md §7 yonu).
##
## Neden koda cizdiriliyor: Kenney paketinde govde egrisine oturan bir
## highlight yok; elips parametrik oldugu icin owner kendi govdesini
## koyarsa buradan tek satirla ayarlanabiliyor.
func _make_gloss() -> bool:
	var n := GLOSS_SIZE
	var center := float(n) * 0.5
	var body_radius := center  # govde texture'unun yaricapi = yarim kenar

	# Elipsin merkezi (govde yaricapi cinsinden, sol-ust yon) ve yaricaplari.
	var gloss_center := Vector2(center - body_radius * 0.34, center - body_radius * 0.40)
	var gloss_radii := Vector2(body_radius * 0.40, body_radius * 0.26)
	var tilt := deg_to_rad(-28.0)
	# Highlight govdenin kenarindan tasmasin diye ic tarafa maskeleniyor.
	var mask_radius := body_radius * 0.92

	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var d := (p - gloss_center).rotated(-tilt)
			# Elips ici = 0, kenari = 1
			var t: float = sqrt(pow(d.x / gloss_radii.x, 2.0) + pow(d.y / gloss_radii.y, 2.0))
			# Yumusak dususu: merkezde tam opak, kenara dogru kareli sonumleme.
			var a: float = clampf(1.0 - t, 0.0, 1.0)
			a = a * a
			# Govde disina tasan kismi kirp (kenarda da yumusak).
			var edge: float = clampf((mask_radius - p.distance_to(Vector2(center, center))) / 6.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * edge))

	var dst := ProjectSettings.globalize_path(OUT + GLOSS_OUT)
	if img.save_png(dst) != OK:
		printerr("Parlama yazilamadi: ", dst)
		return false
	print("%-16s <- kodda cizildi   %dx%d" % [GLOSS_OUT, n, n])
	return true
