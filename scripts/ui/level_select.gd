extends CanvasLayer
## Harita sekmesi: level seçim ekranı. Kilitli level'lar devre dışı görünür.
## Koleksiyon butonu M8'de alt sekme çubuğuna taşındı.
## GAME_DESIGN.md §5.5'teki yol/düğüm görselleştirmesi ve unlock animasyonu
## henüz yok — bu ekran şimdilik işlevsel, görsel hâli owner asset'leriyle gelecek.

signal level_chosen(level: LevelData)

## Kilitli level düğümündeki kilit rozeti. 96x96'lık butonda köşeye sığacak
## kadar küçük, yazının üstüne binmeyecek kadar kenarda.
const LOCK_BADGE_SIZE: Vector2 = Vector2(30.0, 37.0)
const LOCK_BADGE_INSET: float = 5.0

## Düğümdeki yıldız sırası. M8.5-09'a kadar Unicode "★☆" yazısıydı; ne
## Baloo 2'de ne Nunito'da bu iki kod noktası var (U+2605 / U+2606; dört
## font dosyasının cmap'i de tek tek okundu). Sistem font fallback'i açık
## olduğu için masaüstünde yine bir şey çiziliyordu — ama bambaşka bir
## yazı tipinden, yani tam olarak bu turun kaldırmaya çalıştığı "her ekran
## başka bir UI ailesi" sorunu. Yıldızlar zaten asset olarak var
## (round_result.gd aynılarını kullanıyor), o yüzden yazı yerine görsel.
const NODE_STAR_SIZE: Vector2 = Vector2(20.0, 19.0)
const NODE_STAR_SEPARATION: int = 2
## Level numarası — Baloo 2 Bold (CARD_TITLE rolü, boyutu ezilerek).
## Düğüm bir rozet, numara onun kahramanı: tek başına duran 1-2 haneli bir
## sayıda Baloo'nun tombulluğu okunabilirliği düşürmüyor, karakter katıyor.
## 96 px'lik düğümde numara + yıldız sırası için kalan yer 64 px (aşağıya
## bakın); 28 px Baloo satırı ~38 px, yıldızlarla birlikte 59 px ediyor.
const NODE_NUMBER_FONT_SIZE: int = 28
## İçeriğin düğümün DİKEY olarak neresine oturduğu.
##
## Değerler UYDURULMADI: temanın kendi `Button/styles/normal` stylebox'ının
## content margin'leri (üst 12, alt 20). Asimetri tesadüf değil — buton
## dokusunun alt kısmı düşen gölge, tema bunu zaten böyle tarif ediyor.
## Kutu tam dikdörtgene yayılınca yıldız sırası pill'in alt kenarından
## taşıyordu (çekimle yakalandı).
const NODE_TOP_INSET: float = 12.0
const NODE_BOTTOM_INSET: float = 20.0
## Kazanılmamış yıldızın opaklığı. Açık mavi pill üstünde 0.35 neredeyse
## görünmüyordu (level 10 düğümü ölçüldü); 0.5 hâlâ belirgin şekilde soluk
## ama "üç yıldızdan kaçı" sayılabiliyor.
const NODE_STAR_EMPTY_ALPHA: float = 0.5

var _levels: Array[LevelData] = []

@onready var _grid: GridContainer = $Margin/VBox/Grid
@onready var _endless_button: Button = $Margin/VBox/Endless
@onready var _record_label: RichTextLabel = $Margin/VBox/Record


func _ready() -> void:
	_levels = LevelLibrary.load_levels()
	_endless_button.pressed.connect(_on_endless_pressed)
	refresh()


func refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()

	for level in _levels:
		var button := Button.new()
		button.custom_minimum_size = Vector2(96.0, 96.0)
		button.disabled = not SaveManager.is_level_unlocked(level.level_number)
		button.pressed.connect(_on_level_pressed.bind(level))
		# Kazanılmış yıldızlar burada görünsün, yoksa kayıtta duran veri
		# oyuncuya hiç yansımıyor.
		_add_node_content(button, level.level_number,
			SaveManager.stars_for_level(level.level_number))
		if button.disabled:
			_add_lock_badge(button)
		_grid.add_child(button)

	var endless_unlocked: bool = SaveManager.is_endless_unlocked(_levels.size())
	_endless_button.disabled = not endless_unlocked
	_endless_button.text = "Sonsuz Mod" if endless_unlocked else "Sonsuz Mod (Level %d'i bitir)" % _levels.size()
	_record_label.text = "[center]Sonsuz mod rekoru: %d   ·   %s   ·   Koleksiyon: %d/%d\n%s[/center]" % [
		SaveManager.endless_high_score(),
		UiIcons.labelled(UiIcons.DOUGH, "Hamur: %d" % SaveManager.dough()),
		SaveManager.owned_skins().size(), SkinLibrary.total_count(),
		UiIcons.labelled(UiIcons.FLAME,
			"Günlük seri: %d gün" % SaveManager.daily_streak())]


## Düğümün içeriği: numara üstte, yıldız sırası altta.
##
## `button.text` KULLANILMIYOR (güç çubuğuyla aynı gerekçe): yıldızlar artık
## Texture2D ve Button ikonu yazının SOLUNA koyuyor. İçerik, butonun üstüne
## serilen bir VBox; dokunuş butona geçsin diye MOUSE_FILTER_IGNORE.
func _add_node_content(button: Button, level_number: int, earned: int) -> void:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_top = NODE_TOP_INSET
	box.offset_bottom = -NODE_BOTTOM_INSET
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	button.add_child(box)

	var number := Label.new()
	UiType.apply(number, UiType.CARD_TITLE)
	number.add_theme_font_size_override("font_size", NODE_NUMBER_FONT_SIZE)
	number.text = str(level_number)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(number)

	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.add_theme_constant_override("separation", NODE_STAR_SEPARATION)
	box.add_child(stars)

	for i in 3:
		var star := TextureRect.new()
		star.texture = UiIcons.STAR_FILLED if i < earned else UiIcons.STAR_EMPTY
		star.custom_minimum_size = NODE_STAR_SIZE
		# EXPAND_IGNORE_SIZE olmadan TextureRect'in en küçük ölçüsü texture'ın
		# kendi boyutu (130x126) olur ve düğümü patlatır — round_result.gd'de
		# aynı tuzağa bir kez düşülmüştü.
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.modulate = Color(1, 1, 1, 1) if i < earned 			else Color(1, 1, 1, NODE_STAR_EMPTY_ALPHA)
		stars.add_child(star)


## Kilitli level düğümünün sağ-üst köşesine küçük kilit rozeti.
##
## Butonun kendi `icon` özelliği kullanılmadı: ikon yazıyla aynı akışa girip
## numara/yıldız düzenini bozuyordu. Köşeye oturan ayrı bir katman hem
## içeriğe dokunmuyor hem koleksiyon kartlarındaki kilit rozetiyle aynı dili
## konuşuyor.
func _add_lock_badge(button: Button) -> void:
	var badge := TextureRect.new()
	badge.texture = UiIcons.LOCK
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -LOCK_BADGE_SIZE.x - LOCK_BADGE_INSET
	badge.offset_top = LOCK_BADGE_INSET
	badge.offset_right = -LOCK_BADGE_INSET
	badge.offset_bottom = LOCK_BADGE_SIZE.y + LOCK_BADGE_INSET
	button.add_child(badge)


func _on_level_pressed(level: LevelData) -> void:
	level_chosen.emit(level)


func _on_endless_pressed() -> void:
	var endless := LevelLibrary.load_endless()
	if endless != null:
		level_chosen.emit(endless)
