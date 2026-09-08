extends SceneTree
## Owner'in ChatGPT ile urettigi 8 tier karakterini oyuna hazirlar.
## Tek seferlik/tekrar calistirilabilir arac — oyun calisirken kullanilmaz.
##
## Yaptiklari:
##  1) Icerik sinirlarina kirpar (kaynaklarda genis seffaf dolgu var).
##  2) Ekranda gorunecek boyuta gore kucultur — kaynaklar 1254x1254 ve
##     ~900 KB; en buyuk tier bile ekranda 200 px. Kucultmezsek APK'ya
##     bosuna ~7 MB girer.
##  3) Parcacik/onizleme rengi icin her sprite'in baskin tonunu raporlar.
##
## Calistirma:
##   godot --headless --path . --script res://tools/make_character_sprites.gd
##
## Kaynaklarin `_visual_source/chatgpt_characters/` altinda olmasi gerekir
## (gitignore'lu — owner'in urettigi dosyalar repoda tutulmuyor, sadece
## kucultulmus ciktilar assets/visual/ altinda).

const SRC := "res://_visual_source/chatgpt_characters/"
const OUT := "res://assets/visual/"

const FILES: Array[String] = ["tier1_mini.png", "tier2_kucuk.png", "tier3_dumpling.png",
	"tier4_siskin.png", "tier5_buyuk.png", "tier6_dev.png", "tier7_jumbo.png", "tier8_kral.png"]

## Alpha bu esigin altindaki pikseller "bos" sayilir.
const ALPHA_CUTOFF: float = 0.02

## Ekran boyutunun kac kati cozunurlukte tutuluyor (yuksek DPI telefonlarda
## viewport 2x'e kadar olceklenebiliyor).
const SUPERSAMPLE: float = 2.0
const MIN_SIZE: int = 128
const MAX_SIZE: int = 512


func _initialize() -> void:
	var ok := true
	var palette: PackedStringArray = []
	for tier in range(1, FILES.size() + 1):
		var result := _process_one(tier, FILES[tier - 1])
		if result.is_empty():
			ok = false
			continue
		palette.append(result["hex"])
	print("")
	print("TierConfig icin baskin renkler: ", " ".join(palette))
	print("SONUC: ", "OK" if ok else "HATA")
	quit(0 if ok else 1)


func _process_one(tier: int, file_name: String) -> Dictionary:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + file_name))
	if img == null:
		printerr("Kaynak okunamadi: ", file_name)
		return {}
	img.convert(Image.FORMAT_RGBA8)

	var region := _content_bounds(img)
	if region.size.x <= 0:
		printerr("Tamamen seffaf: ", file_name)
		return {}
	var cropped := img.get_region(region)

	# Hedef: gorsel alanin GEOMETRIK ORTALAMASI ekran capinin SUPERSAMPLE kati.
	# Neden geometrik ortalama: bu sprite'lar dairesel degil (en/boy ~1.25),
	# collider ise CircleShape2D. Sadece genislige gore olceklesek dikey
	# bosluk, sadece yukseklige gore olceklesek yatay tasma olurdu; geometrik
	# ortalama ikisinin hatasini dengeliyor. dumpling_visual.gd ayni formulu
	# kullanarak calisma aninda olcegi hesapliyor.
	var diameter: float = TierConfig.radius(tier) * 2.0
	var target: int = clampi(
		nearest_po2(int(diameter * SUPERSAMPLE)), MIN_SIZE, MAX_SIZE)
	var mean: float = sqrt(float(region.size.x) * float(region.size.y))
	var factor: float = float(target) / mean
	var out_w: int = maxi(1, int(round(float(region.size.x) * factor)))
	var out_h: int = maxi(1, int(round(float(region.size.y) * factor)))
	cropped.resize(out_w, out_h, Image.INTERPOLATE_LANCZOS)

	var out_name := "dumpling_tier%d.png" % tier
	var dst := ProjectSettings.globalize_path(OUT + out_name)
	if cropped.save_png(dst) != OK:
		printerr("Yazilamadi: ", dst)
		return {}

	var dominant := _dominant_color(cropped)
	print("%-20s <- %-20s %dx%d -> %dx%d  baskin #%s" % [
		out_name, file_name, region.size.x, region.size.y, out_w, out_h,
		dominant.to_html(false)])
	return {"hex": dominant.to_html(false)}


func _content_bounds(img: Image) -> Rect2i:
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
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## Parcacik ve onizleme rengi icin: opak piksellerin ortalamasi, ama cok koyu
## (yuz/kontur) ve cok acik (spekuler parlama) uclar disarida — ikisi de
## govdenin "temsili" rengi degil.
func _dominant_color(img: Image) -> Color:
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.95:
				continue
			var lum := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			if lum < 0.25 or lum > 0.95:
				continue
			r += c.r
			g += c.g
			b += c.b
			n += 1
	if n == 0:
		return Color.WHITE
	return Color(r / n, g / n, b / n)
