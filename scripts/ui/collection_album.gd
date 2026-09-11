extends CanvasLayer
## Koleksiyon sekmesi (GAME_DESIGN.md §5.3): grid, kaç skin'den kaçı açıldı,
## açılmamışlar silüet. Skin listesi SkinLibrary'den geliyor — yeni .tres
## eklemek yeterli, bu ekran kod değişmeden büyür.
##
## M8.5: albüm artık pasif değil — sahip olunan bir karta dokunmak o skin'i
## TAKIYOR. İlk kart her zaman "Varsayılan" (orijinal dumpling görünümü) ve o
## da seçilebilir. Kilitli karta dokunmak hiçbir şey yapmaz.

## "Varsayılan" kartındaki önizleme. Orta bir tier seçildi: küçük tier'lar
## kartta kayboluyor, büyükler kırpılıyor.
const DEFAULT_PREVIEW: Texture2D = preload("res://assets/visual/dumpling_tier3.png")

const COLUMNS: int = 4
## Kart genisligi: 4 sutun, kenar paylari (2x32) ve sutun araligi (3x12)
## dusulunce sutun basina ~155 px kaliyor; panel ic paylari da eklenince
## 140 tasip son sutunu kirpiyordu.
##
## Yukseklik M8.5-09'da 176'dan 186'ya cikti: adlar Baloo 2 Bold'a gecince
## satir yuksekligi biraz buyudu.
const CARD_SIZE: Vector2 = Vector2(126.0, 186.0)
## Ad bandinin EN AZ yuksekligi (tek satir). Sabit degil: bugunku 20 adin
## hepsi tek satira siginca kartlar esit yukseklikte kaliyor, ileride daha
## uzun bir ad gelirse kart sessizce kirpmak yerine buyuyor.
const NAME_BAND_HEIGHT: float = 26.0
## Kart adi rolun varsayilan boyutunu (23) EZIYOR: 126 px'lik kartin ic
## genisligi (CardPanel ic payi 14+14 dusunce) 98 px.
##
## Olcum (`tools/type_probe.gd`, en uzun ad "Kirmizi Biber", Baloo 2 Bold):
## 16 px -> 92 px, 17 px -> 98 px, 18 px -> 104 px. 17 tam butceye oturuyor
## ama SIFIR pay birakiyor; 16 secildi.
const NAME_FONT_SIZE: int = 16

## Takılı kartın çerçeve rengi ve etiketi.
const EQUIPPED_COLOR: Color = Color("6ddc8b")
const EQUIPPED_LABEL: String = "TAKILI"
## "Varsayılan" kartının sözde id'si — SaveManager'daki boş string ile aynı
## anlama geliyor, sadece UI tarafında bir kart olarak temsil ediliyor.
const DEFAULT_ID: StringName = &""

## id -> kart düğümü. Seçim değişince tüm grid'i yeniden kurmak yerine
## yalnızca eskiyen ve yenilenen iki kart güncelleniyor.
var _cards: Dictionary = {}

@onready var _grid: GridContainer = $Margin/VBox/Scroll/Grid
@onready var _progress: RichTextLabel = $Margin/VBox/Progress


func _ready() -> void:
	_grid.columns = COLUMNS
	refresh()


func refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cards.clear()

	# Varsayılan görünüm de bir seçenek: koleksiyonun ilk kartı.
	_add_card(_make_default_card())

	var owned_count: int = 0
	for skin in SkinLibrary.all():
		var owned: bool = SaveManager.owns_skin(skin.id)
		if owned:
			owned_count += 1
		_add_card(_make_card(skin, owned))

	_refresh_progress(owned_count)
	_apply_equipped_state()


func _add_card(card: Control) -> void:
	_grid.add_child(card)
	_cards[card.get_meta("skin_id")] = card


func _refresh_progress(owned_count: int) -> void:
	_progress.text = "[center]Koleksiyon: %d/%d   ·   %s[/center]" % [
		owned_count, SkinLibrary.total_count(),
		UiIcons.labelled(UiIcons.DOUGH, "Hamur: %d" % SaveManager.dough())]


# --- Kartlar ---

## Ortak iskelet: çerçeve (PanelContainer) + dikey içerik. Çerçeve hem takılı
## durumunu göstermek hem dokunmayı yakalamak için var.
func _make_shell(skin_id: StringName) -> PanelContainer:
	var shell := PanelContainer.new()
	shell.custom_minimum_size = CARD_SIZE
	# Temanin varsayilan PanelContainer stili DIYALOG paneli — camgobegi baslik
	# cubugu var ve kart olarak kullanilinca her kartin tepesine mavi bir bant
	# koyuyor. CardPanel varyanti sade koyu bir kutu (round_result de bunu
	# kullaniyor).
	shell.theme_type_variation = &"CardPanel"
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.set_meta("skin_id", skin_id)
	shell.gui_input.connect(_on_card_input.bind(skin_id))

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(column)
	shell.set_meta("column", column)
	return shell


## "Varsayılan" kartı: orijinal dumpling görünümü. Her zaman seçilebilir.
func _make_default_card() -> PanelContainer:
	var shell := _make_shell(DEFAULT_ID)
	var column: VBoxContainer = shell.get_meta("column")

	var preview := TextureRect.new()
	preview.texture = DEFAULT_PREVIEW
	preview.custom_minimum_size = Vector2(88.0, 88.0)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(preview)

	column.add_child(_make_name_label("Varsayılan", true))
	column.add_child(_make_rarity_label("Orijinal", Color(1, 1, 1, 0.55)))
	column.add_child(_make_state_label())
	return shell


func _make_card(skin: SkinData, owned: bool) -> PanelContainer:
	var shell := _make_shell(skin.id)
	var column: VBoxContainer = shell.get_meta("column")

	# Açık skin: tint'inde bir daire (hâlâ placeholder). Kapalı skin: owner'ın
	# silüet görseli — tint uygulanmıyor, görselin kendi rengi var.
	var swatch := SkinSwatch.new()
	swatch.custom_minimum_size = Vector2(88.0, 88.0)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.setup(skin.tint, SkinData.rarity_color(skin.rarity), owned)
	column.add_child(swatch)

	column.add_child(_make_name_label(
		skin.display_name if owned else "???", owned))

	var rarity_color: Color = SkinData.rarity_color(skin.rarity)
	if not owned:
		rarity_color.a = 0.4
	column.add_child(_make_rarity_label(
		SkinData.rarity_name(skin.rarity), rarity_color))
	column.add_child(_make_state_label())
	return shell


func _make_name_label(text: String, bright: bool) -> Label:
	var label := Label.new()
	UiType.apply(label, UiType.CARD_TITLE)
	label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Uzun adlar kirpilmak yerine sarsin; bant sabit yukseklikte oldugu icin
	# tek satirlik adlar da ayni yeri kapliyor.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0.0, NAME_BAND_HEIGHT)
	label.modulate = Color.WHITE if bright else Color(1, 1, 1, 0.45)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_rarity_label(text: String, color: Color) -> Label:
	var label := Label.new()
	UiType.apply(label, UiType.CAPTION)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## "TAKILI" satırı. Yer her kartta ayrılıyor (boş metinle) ki seçim
## değiştiğinde kartlar zıplamasın.
func _make_state_label() -> Label:
	var label := Label.new()
	UiType.apply(label, UiType.STAT)
	label.name = "State"
	label.text = ""
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Rolun varsayilani 20; "TAKILI" kart genisligine gore kucuk ama Nunito
	# Bold oldugu icin hala en guclu okunan satirlardan biri.
	label.add_theme_font_size_override("font_size", 15)
	label.custom_minimum_size = Vector2(0.0, 20.0)
	label.modulate = EQUIPPED_COLOR
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# --- Seçim ---

func _on_card_input(event: InputEvent, skin_id: StringName) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_try_equip(skin_id)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_try_equip(skin_id)


## Kilitli skin takılmaz — sessizce yok sayılır (SaveManager da ayrıca
## reddediyor, bu yalnızca gereksiz çağrıyı kesiyor).
func _try_equip(skin_id: StringName) -> void:
	if skin_id != DEFAULT_ID and not SaveManager.owns_skin(skin_id):
		return
	if not SaveManager.equip_skin(skin_id):
		return
	AudioManager.play_sfx(&"star_pat", 1.0)
	_apply_equipped_state()


## Tüm kartların takılı/normal görünümünü tazeler. Grid yeniden KURULMUYOR;
## yalnızca çerçeve stili ve durum etiketi değişiyor.
func _apply_equipped_state() -> void:
	var equipped: StringName = SaveManager.equipped_skin_id()
	for id: StringName in _cards:
		var card: PanelContainer = _cards[id]
		if not is_instance_valid(card):
			continue
		_set_card_equipped(card, id == equipped)


func _set_card_equipped(card: PanelContainer, is_equipped: bool) -> void:
	var state := card.find_child("State", true, false) as Label
	if state != null:
		state.text = EQUIPPED_LABEL if is_equipped else ""
	if is_equipped:
		card.add_theme_stylebox_override("panel", _equipped_stylebox())
	else:
		card.remove_theme_stylebox_override("panel")


static func _equipped_stylebox() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(EQUIPPED_COLOR.r, EQUIPPED_COLOR.g, EQUIPPED_COLOR.b, 0.12)
	box.border_color = EQUIPPED_COLOR
	box.set_border_width_all(3)
	box.set_corner_radius_all(12)
	return box
