extends SceneTree
## Owner'in ChatGPT ile urettigi sprite'lari oyuna hazirlar (8 tier karakteri
## + sandik gorselleri).
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
##   godot --headless --path . --script res://tools/make_owner_sprites.gd
##
## Kaynaklarin `_visual_source/chatgpt_characters/` altinda olmasi gerekir
## (gitignore'lu — owner'in urettigi dosyalar repoda tutulmuyor, sadece
## kucultulmus ciktilar assets/visual/ altinda).

const SRC := "res://_visual_source/chatgpt_characters/"
const OUT := "res://assets/visual/"

## UI gorselleri: karakterlerden farkli klasor ve sabit hedef boyut (tier
## yariçapina bagli degiller, ekranda sabit olculerde duruyorlar).
##
## Her kayit su anahtarlari kullanabilir:
##   size  : hedef GEOMETRIK ORTALAMA (kare-ish gorseller icin)
##   width : hedef GENISLIK, en/boy korunur (uzun/yatay gorseller icin)
##   exact : hedef tam olcu, en/boy zorlanir (tam ekran zeminler icin)
##   crop  : icerik sinirlarina kirpilsin mi (varsayilan true)
const UI_SRC := "res://_visual_source/chatgpt_ui/"
const UI_OUT := "res://assets/visual/ui/"
const UI_ITEMS: Array[Dictionary] = [
	{"src": "chest_closed.png", "out": "chest_closed.png", "size": 256},
	{"src": "chest_open.png",   "out": "chest_open.png",   "size": 256},

	# Harita zemini: viewport 720x1280 ile ayni oranda (kaynak 941x1672,
	# 0.5628 vs 0.5625 — %0.05 fark, gorunmez). Kirpma YOK: gorsel tamamen
	# opak ve tuvalin tamami icerik.
	{"src": "map_background.png", "out": "map_background.png",
		"exact": Vector2i(720, 1280), "crop": false},

	# Logo: ana sayfada ~560 px genislikte duruyor, 2x pay ile 1024.
	{"src": "logo_lockup.png", "out": "logo_lockup.png", "width": 1024},

	# Kilitli skin silueti: koleksiyonda 88, magazada 72 px kutuda.
	{"src": "skin_locked_silhouette.png", "out": "skin_locked_silhouette.png",
		"size": 192},

	# Tehlike seridi: en genis kap 720 px (sonsuz mod), 2x pay ile 1440.
	# DIKKAT: bu dosya seamless DEGIL (sol/sag kenar farki ort. 0.16, en kotu
	# 1.20). Tile edilmemeli — kap genisligine tek parca gerilir.
	{"src": "danger_stripe.png", "out": "danger_stripe.png", "width": 1440},

	# Skor/combo rozeti: metnin arkasinda ~220 px'e kadar buyuyor.
	{"src": "badge_starburst.png", "out": "badge_starburst.png", "size": 256},

	# "Yeni!" banner: odul kartindaki detay satirinin arkasinda ~360 px.
	{"src": "banner_new.png", "out": "banner_new.png", "width": 720},

	# Tutorial pozu: level 1 ipucunun yaninda ~180 px.
	{"src": "tutorial_pose.png", "out": "tutorial_pose.png", "size": 320},
]

## --- Android adaptive icon katmanlari ---
##
## Godot'un Android export preset'i 432x432 bekliyor
## (launcher_icons/adaptive_background_432x432 ve _foreground_432x432).
const ICON_OUT := "res://assets/visual/icon/"
const ICON_SIZE: int = 432
## Android adaptive icon'da tuvalin YALNIZCA ortadaki %66'lik dairesi her
## launcher maskesinde gorunur; disi kirpilabilir. Onplan icerigi bu alana
## sigdiriliyor, yoksa yuvarlak/squircle maskede kenarlardan kesiliyor.
const ICON_SAFE: float = 0.66
## Tek kare launcher ikonu (launcher_icons/main_192x192) — iki katmanin
## duz kompoziti.
const ICON_MAIN_SIZE: int = 192

## --- HUD ikon sheet'i ---
##
## icon_sheet.png tek dosyada 7 ikon tasiyor, duzenli bir grid DEGIL: ikonlar
## farkli boyutlarda ve dagilimlari duzensiz. O yuzden sabit hucre olculeri
## yerine bagli bilesen (connected component) analizi yapiliyor.
const SHEET_SRC := "res://_visual_source/chatgpt_ui/icon_sheet.png"
const SHEET_OUT := "res://assets/visual/ui/"
## Ekranda en buyuk kullanim 64 px (round sonucu yildizlari); 2x pay ile 128.
const SHEET_ICON_SIZE: int = 128
## Bu alandan kucuk bilesenler kenar yumusatma artigi sayilir. Olculdu: gercek
## ikonlar 47.000-92.000 px, kopuk alev kivilcimi 3.536 px, artiklar <= 22 px.
## 500 esigi kivilcimi tutar, artiklarin 195'ini birden atar.
const SHEET_MIN_AREA: int = 500
## Okuma sirasi (soldan saga, ustten alta). Sheet'in duzeni degisirse burasi
## da degismeli — arac bulunan ikon sayisini bu listeyle karsilastirip
## uyusmazlikta hata veriyor.
const SHEET_NAMES: Array[String] = [
	"icon_star_filled.png", "icon_star_empty.png", "icon_dough.png",
	"icon_lock.png", "icon_crown.png", "icon_flame.png", "icon_flag.png",
]

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
	for item in UI_ITEMS:
		ok = _process_ui(item) and ok
	ok = _process_icons() and ok
	ok = _process_icon_sheet() and ok
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


## UI gorselleri: (istege bagli) kirp + hedefe kucult. Karakterlerdeki gibi
## yariçapa bagli bir olcek yok, ekranda sabit olculerde duruyorlar.
func _process_ui(item: Dictionary) -> bool:
	var img := Image.load_from_file(ProjectSettings.globalize_path(UI_SRC + item["src"]))
	if img == null:
		printerr("Kaynak okunamadi: ", item["src"])
		return false
	img.convert(Image.FORMAT_RGBA8)

	var region := Rect2i(0, 0, img.get_width(), img.get_height())
	if item.get("crop", true):
		region = _content_bounds(img)
		if region.size.x <= 0:
			printerr("Tamamen seffaf: ", item["src"])
			return false
	var cropped := img.get_region(region)

	var out_w: int = region.size.x
	var out_h: int = region.size.y
	if item.has("exact"):
		var exact: Vector2i = item["exact"]
		out_w = exact.x
		out_h = exact.y
	else:
		var factor: float = 1.0
		if item.has("width"):
			factor = float(item["width"]) / float(region.size.x)
		else:
			# Geometrik ortalama: kare olmayan gorsellerde tek bir kenara
			# gore olceklemek diger kenari asiri buyutuyor/kucultuyor.
			factor = float(item["size"]) / sqrt(float(region.size.x) * float(region.size.y))
		out_w = maxi(1, int(round(float(region.size.x) * factor)))
		out_h = maxi(1, int(round(float(region.size.y) * factor)))

	if out_w > region.size.x or out_h > region.size.y:
		printerr("UYARI: %s buyutuluyor (%dx%d -> %dx%d) — kaynak yetersiz." % [
			item["src"], region.size.x, region.size.y, out_w, out_h])
	cropped.resize(out_w, out_h, Image.INTERPOLATE_LANCZOS)

	var dst := ProjectSettings.globalize_path(UI_OUT + item["out"])
	if cropped.save_png(dst) != OK:
		printerr("Yazilamadi: ", dst)
		return false
	print("%-28s <- %-28s %dx%d -> %dx%d" % [
		item["out"], item["src"], region.size.x, region.size.y, out_w, out_h])
	return true


## --- Android adaptive icon ---
##
## Iki duzeltme yapiliyor, ikisi de kaynak dosyalardaki gercek sorunlara
## karsi (olculdu, bkz. CREDITS):
##
## 1) ARKA PLAN KATMANI TAM KARE OLMALI. Kaynak dairesel: pikselin %25'i
##    tamamen seffaf, kosaler bos. Android arka plan katmanini KIRPAR, kendi
##    maskesini uygular — seffaf kose birakirsan kare/squircle maskeli
##    launcher'da ikonun kosaleri delik gorunur. Daire, kendi kenar renginden
##    ornekle doldurulmus opak bir karenin uzerine biniyor.
##
## 2) ONPLAN GUVENLI ALANA SIGMALI. Kaynakta icerik tuvalin %92'sini
##    kapliyor, oysa her maskede gorunmesi garanti alan ortadaki %66.
##    Icerik bu orana kuculterek ortalaniyor.
func _process_icons() -> bool:
	var bg := Image.load_from_file(ProjectSettings.globalize_path(UI_SRC + "icon_bg_layer.png"))
	var fg := Image.load_from_file(ProjectSettings.globalize_path(UI_SRC + "icon_fg_layer.png"))
	if bg == null or fg == null:
		printerr("Ikon katmanlari okunamadi.")
		return false
	bg.convert(Image.FORMAT_RGBA8)
	fg.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ICON_OUT))

	var bg_out := _icon_background(bg)
	var fg_out := _icon_foreground(fg)

	var ok := true
	ok = _save_icon(bg_out, "adaptive_background_432.png") and ok
	ok = _save_icon(fg_out, "adaptive_foreground_432.png") and ok

	# Tek kare launcher ikonu: iki katmanin duz kompoziti. Proje hala
	# Godot'un varsayilan robot ikonuyla geliyor; M9'da bu kullanilabilir.
	var main := bg_out.duplicate()
	main.blend_rect(fg_out, Rect2i(0, 0, ICON_SIZE, ICON_SIZE), Vector2i.ZERO)
	main.resize(ICON_MAIN_SIZE, ICON_MAIN_SIZE, Image.INTERPOLATE_LANCZOS)
	ok = _save_icon(main, "launcher_main_192.png") and ok
	return ok


## Daireyi opak bir karenin uzerine bindirir. Dolgu rengi, dairenin dis
## kenarindan ornekleniyor: kosaler sanatin kendi rengiyle devam etsin,
## rastgele bir zemin uzerinde duran daire gibi gorunmesin.
func _icon_background(src: Image) -> Image:
	var scaled := src.duplicate()
	scaled.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	var fill := _edge_color(scaled)
	var out := Image.create_empty(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	out.fill(fill)
	out.blend_rect(scaled, Rect2i(0, 0, ICON_SIZE, ICON_SIZE), Vector2i.ZERO)
	print("adaptive arka plan: kose dolgusu #%s (kaynak dairesel, kosaler bostu)"
		% fill.to_html(false))
	return out


## Onplan icerigini guvenli alana sigdirir, seffaf tuvalde ortalar.
func _icon_foreground(src: Image) -> Image:
	var region := _content_bounds(src)
	if region.size.x <= 0:
		printerr("Onplan katmani tamamen seffaf.")
		return Image.create_empty(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	var cropped := src.get_region(region)
	var safe: float = float(ICON_SIZE) * ICON_SAFE
	# Uzun kenar guvenli alana otursun — kisa kenar zaten sigar.
	var factor: float = safe / float(maxi(region.size.x, region.size.y))
	var w: int = maxi(1, int(round(float(region.size.x) * factor)))
	var h: int = maxi(1, int(round(float(region.size.y) * factor)))
	cropped.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var out := Image.create_empty(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	out.blend_rect(cropped, Rect2i(0, 0, w, h),
		Vector2i((ICON_SIZE - w) / 2, (ICON_SIZE - h) / 2))
	print("adaptive onplan: icerik %dx%d -> %dx%d (tuvalin %%%d'i, guvenli alan %%%d)" % [
		region.size.x, region.size.y, w, h,
		int(round(100.0 * float(maxi(w, h)) / float(ICON_SIZE))),
		int(round(ICON_SAFE * 100.0))])
	return out


## Dairenin dis kenarindaki opak piksellerin ortalamasi. Merkez rengi degil:
## merkez cogu zaman daha acik/koyu bir vurgu, kenar ise kosaye komsu olan.
func _edge_color(img: Image) -> Color:
	var center := Vector2(img.get_width(), img.get_height()) * 0.5
	# Tuvalin yarisinin %80-%95'i arasindaki halka: dairenin dis bandi.
	var half: float = minf(center.x, center.y)
	var inner: float = half * 0.80
	var outer: float = half * 0.95
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.95:
				continue
			var d: float = Vector2(x, y).distance_to(center)
			if d < inner or d > outer:
				continue
			r += c.r
			g += c.g
			b += c.b
			n += 1
	if n == 0:
		return img.get_pixel(img.get_width() / 2, img.get_height() / 2)
	return Color(r / n, g / n, b / n, 1.0)


## --- HUD ikon sheet'ini parcalara ayirir ---
##
## Grid varsaymiyor: alfa uzerinden bagli bilesenler bulunuyor, artiklar
## eleniyor, kesisen kutular birlestiriliyor (alevin kopuk kivilcimi ayri bir
## bilesen ama alevin kutusunun icinde kaliyor), sonra okuma sirasina
## diziliyor. Sheet yeniden uretilirse ikonlar kaysa bile calisir.
func _process_icon_sheet() -> bool:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SHEET_SRC))
	if img == null:
		printerr("Ikon sheet'i okunamadi: ", SHEET_SRC)
		return false
	img.convert(Image.FORMAT_RGBA8)

	var boxes := _merge_overlapping(_components(img))
	if boxes.size() != SHEET_NAMES.size():
		printerr("Ikon sheet'inde %d ikon bekleniyordu, %d bulundu — sheet duzeni degismis olabilir." % [
			SHEET_NAMES.size(), boxes.size()])
		return false
	boxes = _reading_order(boxes)

	var ok := true
	for i in boxes.size():
		var region: Rect2i = boxes[i]
		var cropped := img.get_region(region)
		# Ikonlar kare degil (bayrak genis, kilit uzun); geometrik ortalama
		# hepsini gorsel olarak ayni "agirlikta" tutuyor.
		var mean: float = sqrt(float(region.size.x) * float(region.size.y))
		var factor: float = float(SHEET_ICON_SIZE) / mean
		var w: int = maxi(1, int(round(float(region.size.x) * factor)))
		var h: int = maxi(1, int(round(float(region.size.y) * factor)))
		cropped.resize(w, h, Image.INTERPOLATE_LANCZOS)
		var dst := ProjectSettings.globalize_path(SHEET_OUT + SHEET_NAMES[i])
		if cropped.save_png(dst) != OK:
			printerr("Yazilamadi: ", dst)
			ok = false
			continue
		print("%-28s <- icon_sheet x=%d..%d y=%d..%d  %dx%d -> %dx%d" % [
			SHEET_NAMES[i], region.position.x, region.end.x - 1,
			region.position.y, region.end.y - 1,
			region.size.x, region.size.y, w, h])
	return ok


## Alfasi olan piksellerin bagli bilesenleri; artiklar (SHEET_MIN_AREA alti)
## atiliyor. Flood fill yigin tabanli — 1254x1254'te rekursiyon patlar.
func _components(img: Image) -> Array[Rect2i]:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var out: Array[Rect2i] = []

	for y in h:
		for x in w:
			if seen[y * w + x] == 1:
				continue
			seen[y * w + x] = 1
			if img.get_pixel(x, y).a <= ALPHA_CUTOFF:
				continue
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			var rect := Rect2i(x, y, 1, 1)
			var area := 0
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				area += 1
				rect = rect.expand(p).expand(p + Vector2i.ONE)
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var n := p + Vector2i(dx, dy)
						if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
							continue
						if seen[n.y * w + n.x] == 1:
							continue
						seen[n.y * w + n.x] = 1
						if img.get_pixel(n.x, n.y).a <= ALPHA_CUTOFF:
							continue
						stack.append(n)
			if area >= SHEET_MIN_AREA:
				out.append(rect)
	return out


## Kopuk parcali ikonlari (alev + kivilcimi) tek kutuya toplar.
##
## Sadece "kesisiyorlar mi" YETMEZ: tacin kutusu alevinkiyle 2 px ortusuyor
## (tac x=337..670, alev x=669..972) ve o kadari bile ikisini birlestiriyordu.
## Olcut, kesisimin KUCUK kutuya orani:
##   tac  ∩ alev  =    562 px²  / 93.854 px² = %0.6  -> ayri
##   alev ∩ kivilcim = 5.104 px² /  6.380 px² = %80   -> birlesir
## Aradaki fark iki kat buyuklugunde, %25 esigi guvenli.
const MERGE_OVERLAP_RATIO: float = 0.25


func _merge_overlapping(boxes: Array[Rect2i]) -> Array[Rect2i]:
	var merged := true
	while merged:
		merged = false
		for i in range(boxes.size()):
			for j in range(i + 1, boxes.size()):
				if not _mostly_inside(boxes[i], boxes[j]):
					continue
				boxes[i] = boxes[i].merge(boxes[j])
				boxes.remove_at(j)
				merged = true
				break
			if merged:
				break
	return boxes


func _mostly_inside(a: Rect2i, b: Rect2i) -> bool:
	var overlap: Rect2i = a.intersection(b)
	if overlap.size.x <= 0 or overlap.size.y <= 0:
		return false
	var overlap_area: float = float(overlap.size.x) * float(overlap.size.y)
	var smaller: float = minf(float(a.size.x) * float(a.size.y),
		float(b.size.x) * float(b.size.y))
	return overlap_area / smaller >= MERGE_OVERLAP_RATIO


## Satir satir soldan saga. Satirlar y-merkezlerine gore gruplaniyor: ayni
## satirdaki ikonlar farkli yuksekliklerde olabildigi icin ust kenara gore
## siralamak yanlis sonuc veriyor.
func _reading_order(boxes: Array[Rect2i]) -> Array[Rect2i]:
	var sorted_boxes := boxes.duplicate()
	sorted_boxes.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		return a.get_center().y < b.get_center().y)

	var tolerance: float = 0.0
	for b in sorted_boxes:
		tolerance += float(b.size.y)
	tolerance = (tolerance / float(sorted_boxes.size())) * 0.6

	var out: Array[Rect2i] = []
	var row: Array[Rect2i] = []
	var row_y: float = 0.0
	for b in sorted_boxes:
		if not row.is_empty() and absf(float(b.get_center().y) - row_y) > tolerance:
			out.append_array(_sorted_by_x(row))
			row = []
		row.append(b)
		var sum: float = 0.0
		for r in row:
			sum += float(r.get_center().y)
		row_y = sum / float(row.size())
	out.append_array(_sorted_by_x(row))
	return out


func _sorted_by_x(row: Array[Rect2i]) -> Array[Rect2i]:
	var copy := row.duplicate()
	copy.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		return a.get_center().x < b.get_center().x)
	return copy


func _save_icon(img: Image, file_name: String) -> bool:
	var dst := ProjectSettings.globalize_path(ICON_OUT + file_name)
	if img.save_png(dst) != OK:
		printerr("Yazilamadi: ", dst)
		return false
	print("%-28s %dx%d" % [file_name, img.get_width(), img.get_height()])
	return true


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
