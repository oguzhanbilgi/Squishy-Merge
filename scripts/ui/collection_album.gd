extends CanvasLayer
## Koleksiyon sekmesi (GAME_DESIGN.md §5.3): grid, kaç skin'den kaçı açıldı,
## açılmamışlar silüet. Skin listesi SkinLibrary'den geliyor — yeni .tres
## eklemek yeterli, bu ekran kod değişmeden büyür.
##
## M8.5: albüm artık pasif değil — sahip olunan bir karta dokunmak o skin'i
## TAKIYOR. İlk kart her zaman "Varsayılan" (orijinal dumpling görünümü) ve o
## da seçilebilir. Kilitli karta dokunmak hiçbir şey yapmaz.
##
## M8.5-10 görsel pası: gerçek albüm kabuğu — başlık + Hamur cipi, altın
## ilerleme çubuğu, rarity kenarlı kartlar, sakin/karanlık kilitli kartlar,
## nane "TAKILI" rozeti. Skin önizlemesi HÂLÂ placeholder (SkinSwatch),
## bu tur ona dokunmadı.

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
const CARD_SIZE: Vector2 = Vector2(126.0, 196.0)
## Ad bandinin EN AZ yuksekligi (tek satir). Sabit degil: bugunku 20 adin
## hepsi tek satira siginca kartlar esit yukseklikte kaliyor, ileride daha
## uzun bir ad gelirse kart sessizce kirpmak yerine buyuyor.
const NAME_BAND_HEIGHT: float = 26.0
## Kart adi rolun varsayilan boyutunu (23) EZIYOR: 126 px'lik kartin ic
## genisligi (kart ic payi 8+8 dusunce, M8.5-10) 110 px.
##
## Olcum (`tools/type_probe.gd`, en uzun ad "Kirmizi Biber", Baloo 2 Bold):
## 16 px -> 92 px, 17 px -> 98 px, 18 px -> 104 px. 17 tam butceye oturuyor
## ama SIFIR pay birakiyor; 16 secildi.
const NAME_FONT_SIZE: int = 16

## Takılı kartın çerçeve rengi ve etiketi (palette SELECTED = nane).
const EQUIPPED_COLOR: Color = UiPalette.SELECTED
const EQUIPPED_LABEL: String = "TAKILI"
## Rozet yüksekliği: her kartta yer ayrılıyor (boşken görünmez) ki seçim
## değişince grid zıplamasın.
const STATE_BADGE_HEIGHT: float = 24.0
## "Varsayılan" kartının sözde id'si — SaveManager'daki boş string ile aynı
## anlama geliyor, sadece UI tarafında bir kart olarak temsil ediliyor.
const DEFAULT_ID: StringName = &""

## id -> kart düğümü. Seçim değişince tüm grid'i yeniden kurmak yerine
## yalnızca eskiyen ve yenilenen iki kart güncelleniyor.
var _cards: Dictionary = {}

var _dough_chip: PanelContainer

@onready var _grid: GridContainer = $Margin/VBox/Scroll/Grid
@onready var _chip_slot: HBoxContainer = $Margin/VBox/Header/ChipSlot
@onready var _icon_slot: HBoxContainer = $Margin/VBox/ProgressCard/Row/IconSlot
@onready var _count: Label = $Margin/VBox/ProgressCard/Row/Column/Labels/Count
@onready var _bar: ProgressBar = $Margin/VBox/ProgressCard/Row/Column/Bar


func _ready() -> void:
	_grid.columns = COLUMNS
	_dough_chip = UiPalette.chip(UiIcons.DOUGH, "")
	_chip_slot.add_child(_dough_chip)
	var badge := UiPalette.icon_rect(UiPalette.ICON_BADGE, 40.0, UiPalette.GOLD)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_slot.add_child(badge)
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
	var total: int = SkinLibrary.total_count()
	_count.text = "%d/%d" % [owned_count, total]
	_bar.max_value = float(maxi(total, 1))
	_bar.value = float(owned_count)
	UiPalette.set_chip_value(_dough_chip, "%d Hamur" % SaveManager.dough(), false)


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
	column.add_child(_make_rarity_label("Orijinal", UiPalette.TEXT_MUTED))
	column.add_child(_make_state_badge())
	shell.set_meta("base_style", _card_style(Color(1, 1, 1, 0.35), true))
	shell.add_theme_stylebox_override("panel", shell.get_meta("base_style"))
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
		rarity_color.a = 0.45
	column.add_child(_make_rarity_label(
		SkinData.rarity_name(skin.rarity), rarity_color))
	column.add_child(_make_state_badge())
	# Açık kart: rarity renginde ince kenar. Kilitli kart: sakin, koyu,
	# kenarı silik — keşfedilmemiş ama okunabilir.
	shell.set_meta("base_style", _card_style(rarity_color, owned))
	shell.add_theme_stylebox_override("panel", shell.get_meta("base_style"))
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
	label.modulate = Color.WHITE if bright else Color(1, 1, 1, 0.5)
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


## "TAKILI" rozeti: nane pill, koyu yazı. Yer her kartta ayrılıyor (boşken
## görünmez) ki seçim değiştiğinde kartlar zıplamasın.
func _make_state_badge() -> PanelContainer:
	var badge := PanelContainer.new()
	badge.name = "State"
	badge.custom_minimum_size = Vector2(0.0, STATE_BADGE_HEIGHT)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = EQUIPPED_COLOR
	box.set_corner_radius_all(12)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 1.0
	box.content_margin_bottom = 2.0
	badge.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	UiType.apply(label, UiType.STAT)
	label.text = EQUIPPED_LABEL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.05, 0.22, 0.12))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	badge.modulate.a = 0.0
	return badge


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
	var state := card.find_child("State", true, false) as PanelContainer
	var was_equipped: bool = card.get_meta("equipped", false)
	card.set_meta("equipped", is_equipped)
	if state != null:
		state.modulate.a = 1.0 if is_equipped else 0.0
	if is_equipped:
		card.add_theme_stylebox_override("panel", _equipped_stylebox())
		if not was_equipped:
			UiMotion.pop(card, 1.06)
	else:
		card.add_theme_stylebox_override("panel", card.get_meta("base_style"))


## Kartın sakin hâli: tema CardPanel kalıbı, kenar rengi rarity'den.
static func _card_style(border: Color, owned: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	if owned:
		box.bg_color = Color(0.2, 0.17, 0.42, 0.92)
		box.border_color = UiPalette.rarity_border(border)
	else:
		box.bg_color = Color(0.1, 0.08, 0.24, 0.8)
		box.border_color = Color(1, 1, 1, 0.07)
	box.set_border_width_all(2)
	box.set_corner_radius_all(20)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	return box


static func _equipped_stylebox() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.SELECTED_SOFT
	box.border_color = EQUIPPED_COLOR
	box.set_border_width_all(3)
	box.set_corner_radius_all(20)
	box.content_margin_left = 7.0
	box.content_margin_right = 7.0
	box.content_margin_top = 9.0
	box.content_margin_bottom = 9.0
	return box
