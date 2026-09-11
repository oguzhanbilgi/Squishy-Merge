extends Node
## Tipografi tasma olcumu (M8.5-09). Dev araci — oyun calisirken kullanilmaz.
##
## Neden bir arac: font degisince metin GENISLIGI degisiyor ve bu ekran
## goruntusunden guvenilir okunamaz. "Temizleyici ×99" 112 px'lik pill
## bosluguna siginca mi kirpilmiyor, yoksa 2 px payla mi kurtuluyor —
## goz bunu ayirt edemez, `get_string_size()` eder.
##
## Ayrica GLYPH KAPSAMINI dogruluyor: iki font ailesinde de bulunmayan bir
## kod noktasi (Unicode yildiz, tik, dolu daire) sessizce sistem font
## fallback'ine dusuyor ve masaustunde "calisiyor gibi" gorunuyor. Burada
## kapsam dogrudan `font.has_char()` ile sorgulaniyor.
##
## Kullanim:
##   godot --headless --audio-driver Dummy --path . res://tools/type_probe.tscn

const BALOO_BOLD: FontFile = preload("res://assets/fonts/Baloo2-Bold.ttf")
const BALOO_EXTRABOLD: FontFile = preload("res://assets/fonts/Baloo2-ExtraBold.ttf")
const NUNITO_BOLD: FontFile = preload("res://assets/fonts/Nunito-Bold.ttf")
const NUNITO_SEMIBOLD: FontFile = preload("res://assets/fonts/Nunito-SemiBold.ttf")

## Turkce Latin Extended kontrolu — eksik glyph varsa font production'a
## alinmaz (gorev sarti).
const TURKISH_GLYPHS: String = "İıŞşĞğÇçÖöÜü"
## UI'da gecen ASCII disi isaretler.
const UI_SYMBOLS: String = "×·•…—"
## M8.5-09'da metinden CIKARILAN isaretler. Burada listeleniyorlar ki biri
## geri gelirse bu arac hemen "yok" desin.
const REMOVED_SYMBOLS: String = "★☆✓●○✸▲⌫"

var _failed: int = 0


func _ready() -> void:
	_section("1) Glyph kapsami")
	_probe_coverage()
	_section("2) Dar kutularda tasma")
	_probe_fits()
	_section("3) En kotu durum metinleri")
	_probe_worst_case()
	print("")
	print("=== SONUC: %d uyari ===" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)


func _section(title: String) -> void:
	print("")
	print("--- %s ---" % title)


func _fonts() -> Dictionary:
	return {
		"Baloo2-Bold": BALOO_BOLD,
		"Baloo2-ExtraBold": BALOO_EXTRABOLD,
		"Nunito-Bold": NUNITO_BOLD,
		"Nunito-SemiBold": NUNITO_SEMIBOLD,
	}


# --- 1) Kapsam ---

func _probe_coverage() -> void:
	for name: String in _fonts():
		var font: FontFile = _fonts()[name]
		var missing_tr: String = _missing(font, TURKISH_GLYPHS)
		var missing_ui: String = _missing(font, UI_SYMBOLS)
		var missing_removed: String = _missing(font, REMOVED_SYMBOLS)
		if not missing_tr.is_empty():
			_fail("%s: TURKCE GLYPH EKSIK -> %s" % [name, missing_tr])
		elif not missing_ui.is_empty():
			_fail("%s: UI isareti eksik -> %s" % [name, missing_ui])
		else:
			print("  [OK]   %-18s Turkce + UI isaretleri tam" % name)
		# Bunlarin EKSIK olmasi beklenen durum; teyit icin yaziliyor.
		print("         cikarilan isaretlerden eksik: %s" % (
			missing_removed if not missing_removed.is_empty() else "(yok!)"))


func _missing(font: FontFile, sample: String) -> String:
	var out: String = ""
	for i in sample.length():
		if not font.has_char(sample.unicode_at(i)):
			out += sample[i]
	return out


# --- 2) Dar kutular ---

## Her satir: etiket, font, olculecek metin, kullanilabilir genislik,
## denenecek boyutlar. En buyuk SIGAN boyut basiliyor.
func _probe_fits() -> void:
	# Guc cubugu pill'i: 172 px genislik, iki yanda 30 px yildiz payi.
	_fit("guc cubugu etiketi", NUNITO_BOLD, "Temizleyici ×99", 112.0,
		[13, 14, 15, 16, 17])
	_fit("guc cubugu (Baloo denendi)", BALOO_BOLD, "Temizleyici ×99", 112.0,
		[13, 14, 15, 16, 17])
	# Koleksiyon karti: 126 px kart, CardPanel ic payi 14+14.
	_fit("koleksiyon kart adi", BALOO_BOLD, "Kirmizi Biber", 98.0,
		[15, 16, 17, 18, 19, 20])
	# Alt sekme cubugu: 720 - 24 kenar - 3x8 aralik = 4 x 168; buton
	# stylebox'i iki yanda 30 px ic pay birakiyor.
	_fit("sekme yazisi", NUNITO_BOLD, "Koleksiyon", 108.0, [19, 20, 21, 22, 23])
	# Oyun HUD'u hedef satiri: 24..700, iki satir ici ikon ~30 px.
	_fit("HUD hedef satiri", NUNITO_BOLD,
		"Level 10 — Hedef: Dumpling Kralı + 5000 skor", 616.0, [23, 24, 25, 26, 27])
	# Pencere CTA'si: 496 px pill, iki yanda 58 px yildiz payi.
	_fit("CTA ust satiri", BALOO_BOLD, "REKLAM İZLE", 380.0, [24, 25, 26, 27, 28])
	_fit("CTA alt satiri", NUNITO_BOLD, "+1 Temizleyici", 380.0, [16, 17, 18, 19])


func _fit(label: String, font: FontFile, text: String, budget: float,
		sizes: Array) -> void:
	var best: int = -1
	var widths: PackedStringArray = []
	for size: int in sizes:
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, size).x
		widths.append("%d:%.0f" % [size, w])
		if w <= budget:
			best = size
	var verdict: String = ("en buyuk sigan: %d px" % best) if best > 0 \
		else "HICBIRI SIGMIYOR"
	if best < 0:
		_fail("%s -> %s (butce %.0f px)" % [label, verdict, budget])
	else:
		print("  [OK]   %-26s butce %.0f px | %s | %s" % [
			label, budget, verdict, " ".join(widths)])


# --- 3) En kotu durum ---

## Oyunun uretebilecegi EN UZUN gercek metinler. Bunlar UI'da gercekten
## olusabilen kombinasyonlar; uydurma degil.
func _probe_worst_case() -> void:
	var rows: Array = [
		["guc cubugu", NUNITO_BOLD, 14, "Temizleyici ×99", 112.0],
		["magaza fiyat", NUNITO_BOLD, 20, "99999 Hamur", 300.0],
		["HUD skor", NUNITO_BOLD, 22, "Skor: 999999", 376.0],
		["Hamur satiri", NUNITO_BOLD, 21, "Hamur: 99999   ·   Koleksiyon: 20/20", 640.0],
		["refill basligi", BALOO_EXTRABOLD, 42, "Temizleyici bitti", 496.0],
		["kota satiri", NUNITO_SEMIBOLD, 16, "Bugünkü reklam hakkı: 1/1", 496.0],
	]
	for row: Array in rows:
		var font: FontFile = row[1]
		var w: float = font.get_string_size(row[3], HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, row[2]).x
		var budget: float = row[4]
		if w > budget:
			_fail("%s @%d px: %.0f px > butce %.0f px -> \"%s\"" % [
				row[0], row[2], w, budget, row[3]])
		else:
			print("  [OK]   %-16s @%2d px: %5.0f / %5.0f px  \"%s\"" % [
				row[0], row[2], w, budget, row[3]])


func _fail(message: String) -> void:
	_failed += 1
	print("  [UYARI] %s" % message)
