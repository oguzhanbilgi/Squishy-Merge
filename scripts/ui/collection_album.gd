extends CanvasLayer
## Koleksiyon sekmesi (GAME_DESIGN.md §5.3): vitrin + albüm ilerlemesi +
## rarity kartlı grid. Skin listesi SkinEntry/SkinLibrary'den geliyor — yeni
## .tres eklemek yeterli, bu ekran kod değişmeden büyür.
##
## Etkileşim (spec değişmedi): sahip olunan bir karta dokunmak o skin'i
## TAKIYOR ve kayda yazıyor; ilk kart "Varsayılan" ve o da takılabilir.
## Kilitli karta dokunmak takmıyor ama vitrinde GÖSTERİYOR: adı, rarity'si,
## fiyatı ve mağazaya giden kısayol (M8.5-13).
##
## Vitrin (Showcase): üstte büyük önizleme + ad + rarity/durum etiketleri +
## bağlama göre tek aksiyon (Tak / Mağazaya Git). Vitrin her zaman ya takılı
## skin'i ya da son dokunulan kilitli kartı gösteriyor.
##
## Durum senkronu: SaveManager.skin_granted / skin_equipped sinyalleri.
## Ekran görünürken gelen değişiklik anında işleniyor; görünmezken gelen
## (mağazadan satın alma) `_pending_focus` olarak bekletilip bir sonraki
## refresh()'te (sekme açılışı, main.gd) vitrine taşınıyor — oyuncu
## Koleksiyon'a geçince yeni skin'ini büyük görüyor ve "Tak" diyor.
##
## Skin önizlemesi: SkinSwatch artık gameplay'deki materyalin aynısıyla
## orijinal dumpling'i çiziyor (renkli daire placeholder'ı kalktı). Sanat
## gelince SkinData.preview_texture doldurulur, burası değişmez.

## Mağazaya git kısayolu — main.gd Mağaza sekmesini açar.
signal shop_requested

const COLUMNS: int = 4
## Kart genişliği: 4 sütun, kenar payları (2x30) ve sütun aralığı (3x12)
## düşülünce 126 ScrollContainer içinde tam oturuyor (M8.5-10 ölçümü).
const CARD_SIZE: Vector2 = Vector2(126.0, 200.0)
const CARD_PREVIEW: float = 92.0
## Ad bandının EN AZ yüksekliği (tek satır). Uzun ad gelirse kart büyür.
const NAME_BAND_HEIGHT: float = 26.0
## Kart adı rolün varsayılan boyutunu (23) eziyor: 110 px iç genişlik
## (`tools/type_probe.gd` ölçümü, M8.5-10).
const NAME_FONT_SIZE: int = 16

const EQUIPPED_COLOR: Color = UiPalette.SELECTED
const EQUIPPED_LABEL: String = "TAKILI"
const LOCKED_LABEL: String = "KİLİTLİ"
const NEW_LABEL: String = "YENİ"
## Rozet yüksekliği: her kartta yer ayrılıyor (boşken görünmez) ki seçim
## değişince grid zıplamasın. Kilitli kartta aynı bant fiyatı taşıyor.
const STATE_BADGE_HEIGHT: float = 24.0
const DEFAULT_ID: StringName = SkinEntry.DEFAULT_ID

## id -> kart düğümü. Seçim değişince tüm grid'i yeniden kurmak yerine
## yalnızca çerçeve stili ve durum etiketi güncelleniyor.
var _cards: Dictionary = {}
## id -> SkinEntry (son refresh anındaki durum).
var _entries: Dictionary = {}
## Vitrindeki giriş: takılı skin ya da dokunulan kilitli kart.
var _focused_id: StringName = DEFAULT_ID
## Görünmezken gelen skin_granted: bir sonraki refresh'te vitrine alınır.
var _pending_focus: StringName = DEFAULT_ID
var _has_pending_focus: bool = false
## Vitrinde "YENİ" rozeti gösterilecek id (son satın alınan / kazanılan).
## Varsayılanın id'si de boş string olduğundan ayrı bir bayrak gerekiyor.
var _new_id: StringName = DEFAULT_ID
var _has_new: bool = false

var _dough_chip: PanelContainer
var _showcase_swatch: SkinSwatch
var _showcase_action: Button

@onready var _grid: GridContainer = $Margin/VBox/Scroll/Grid
@onready var _chip_slot: HBoxContainer = $Margin/VBox/Header/ChipSlot
@onready var _showcase: PanelContainer = $Margin/VBox/Showcase
@onready var _showcase_preview_slot: Control = $Margin/VBox/Showcase/Row/PreviewSlot
@onready var _showcase_name: Label = $Margin/VBox/Showcase/Row/Column/Name
@onready var _showcase_tags: HBoxContainer = $Margin/VBox/Showcase/Row/Column/Tags
@onready var _showcase_detail: Label = $Margin/VBox/Showcase/Row/Column/Detail
@onready var _showcase_action_slot: HBoxContainer = $Margin/VBox/Showcase/Row/Column/ActionSlot
@onready var _icon_slot: HBoxContainer = $Margin/VBox/ProgressCard/Row/IconSlot
@onready var _count: Label = $Margin/VBox/ProgressCard/Row/Column/Labels/Count
@onready var _bar: ProgressBar = $Margin/VBox/ProgressCard/Row/Column/Bar


func _ready() -> void:
	_grid.columns = COLUMNS
	_dough_chip = UiPalette.chip(UiIcons.DOUGH, "")
	_chip_slot.add_child(_dough_chip)
	var badge := UiPalette.icon_rect(UiPalette.ICON_BADGE, 34.0, UiPalette.GOLD)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_slot.add_child(badge)

	_showcase_swatch = SkinSwatch.new()
	_showcase_swatch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_showcase_preview_slot.add_child(_showcase_swatch)
	_showcase_action = Button.new()
	_showcase_action.custom_minimum_size = Vector2(150.0, 54.0)
	_showcase_action.focus_mode = Control.FOCUS_NONE
	_showcase_action.add_theme_font_size_override("font_size", 20)
	_showcase_action.pressed.connect(_on_showcase_action)
	UiMotion.attach_press(_showcase_action)
	_showcase_action_slot.add_child(_showcase_action)

	SaveManager.skin_granted.connect(_on_skin_granted)
	SaveManager.skin_equipped.connect(_on_skin_equipped)
	refresh()


func refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cards.clear()
	_entries.clear()

	for entry in SkinEntry.all(true):
		_entries[entry.id] = entry
		_add_card(_make_card(entry))

	_refresh_progress()
	if _has_pending_focus:
		_has_pending_focus = false
		_focused_id = _pending_focus
	elif not _entries.has(_focused_id):
		_focused_id = SaveManager.equipped_skin_id()
	elif (_entries[_focused_id] as SkinEntry).owned and not _is_new(_focused_id):
		# Sahip olunan bir kart vitrindeyse o ya takılı olandır (dokunmak =
		# takmak) ya da az önce kazanılan "YENİ"; kilitli odak korunur.
		_focused_id = SaveManager.equipped_skin_id()
	_apply_equipped_state()
	_refresh_showcase()


func _add_card(card: Control) -> void:
	_grid.add_child(card)
	_cards[card.get_meta("skin_id")] = card


func _refresh_progress() -> void:
	var total: int = SkinLibrary.total_count()
	var owned_count: int = SkinEntry.owned_count()
	_count.text = "%d/%d" % [owned_count, total]
	_bar.max_value = float(maxi(total, 1))
	_bar.value = float(owned_count)
	UiPalette.set_chip_value(_dough_chip, "%d Hamur" % SaveManager.dough(), false)


# --- Vitrin ---

func _refresh_showcase() -> void:
	var entry: SkinEntry = _entries.get(_focused_id)
	if entry == null:
		entry = SkinEntry.equipped_entry()
		_focused_id = entry.id
	_showcase_swatch.setup(entry)
	_showcase_name.text = entry.display_name
	_showcase_name.modulate = Color.WHITE if entry.owned else Color(1, 1, 1, 0.7)

	for child in _showcase_tags.get_children():
		_showcase_tags.remove_child(child)
		child.queue_free()
	_showcase_tags.add_child(_make_pill(entry.rarity_label(), entry.rarity_color(), true))
	if entry.equipped:
		_showcase_tags.add_child(_make_pill(EQUIPPED_LABEL, EQUIPPED_COLOR, false))
	elif entry.is_locked():
		_showcase_tags.add_child(_make_pill(LOCKED_LABEL, Color(1, 1, 1, 0.35), true))
	elif _is_new(entry.id):
		_showcase_tags.add_child(_make_pill(NEW_LABEL, UiPalette.GOLD, false))

	if entry.is_locked():
		_showcase_detail.text = "Sandıktan çıkabilir · Mağazada %d Hamur" % entry.price
		_showcase_action.text = "Mağazaya Git"
		_showcase_action.theme_type_variation = UiType.SECONDARY_BUTTON
		_showcase_action.visible = true
	elif entry.equipped:
		_showcase_detail.text = ("Orijinal dumpling görünümü · oyunda takılı"
			if entry.is_default() else "Oyunda bu görünümle oynuyorsun")
		_showcase_action.visible = false
	else:
		_showcase_detail.text = "Koleksiyonunda · oyunda kullanmak için tak"
		_showcase_action.text = "Tak"
		_showcase_action.theme_type_variation = &""
		_showcase_action.visible = true
	_showcase.add_theme_stylebox_override("panel",
		_showcase_style(entry.rarity_color(), entry.equipped))


func _on_showcase_action() -> void:
	var entry: SkinEntry = _entries.get(_focused_id)
	if entry == null:
		return
	if entry.is_locked():
		shop_requested.emit()
		return
	_try_equip(entry.id)


## Vitrin kenarı: takılıysa nane, değilse skin'in rarity rengi — vitrin
## grid'deki kartla aynı dili konuşsun.
static func _showcase_style(accent: Color, is_equipped: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.2, 0.17, 0.42, 0.92)
	box.border_color = EQUIPPED_COLOR if is_equipped else UiPalette.rarity_border(accent)
	box.set_border_width_all(2)
	box.set_corner_radius_all(22)
	box.content_margin_left = 14.0
	box.content_margin_right = 16.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	return box


## Küçük pill etiketi: rarity (çizgili, renkli yazı) ya da durum (dolu).
static func _make_pill(text: String, color: Color, outlined: bool) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	if outlined:
		box.bg_color = Color(color.r, color.g, color.b, 0.16)
		box.border_color = Color(color.r, color.g, color.b, 0.7)
		box.set_border_width_all(1)
	else:
		box.bg_color = color
	box.set_corner_radius_all(12)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 1.0
	box.content_margin_bottom = 2.0
	pill.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	UiType.apply(label, UiType.STAT)
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color",
		color.lerp(Color.WHITE, 0.35) if outlined else Color(0.05, 0.18, 0.12))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(label)
	return pill


# --- Kartlar ---

func _make_card(entry: SkinEntry) -> PanelContainer:
	var shell := PanelContainer.new()
	shell.custom_minimum_size = CARD_SIZE
	# Temanın varsayılan PanelContainer stili DİYALOG paneli; CardPanel
	# varyantı sade koyu kutu. Stil aşağıda rarity'ye göre eziliyor.
	shell.theme_type_variation = &"CardPanel"
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.set_meta("skin_id", entry.id)
	shell.gui_input.connect(_on_card_input.bind(entry.id))

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(column)

	var swatch := SkinSwatch.new()
	swatch.custom_minimum_size = Vector2(CARD_PREVIEW, CARD_PREVIEW)
	swatch.setup(entry)
	column.add_child(swatch)

	column.add_child(_make_name_label(entry.display_name, entry.owned))
	var rarity_color: Color = entry.rarity_color()
	if entry.is_locked():
		rarity_color.a = 0.5
	column.add_child(_make_rarity_label(entry.rarity_label(), rarity_color))
	column.add_child(_make_state_band(entry))

	shell.set_meta("base_style", _card_style(entry))
	shell.add_theme_stylebox_override("panel", shell.get_meta("base_style"))
	return shell


func _make_name_label(text: String, bright: bool) -> Label:
	var label := Label.new()
	UiType.apply(label, UiType.CARD_TITLE)
	label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0.0, NAME_BAND_HEIGHT)
	label.modulate = Color.WHITE if bright else Color(1, 1, 1, 0.55)
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


## Kartın alt bandı, sabit yükseklik. Sahip olunan: "TAKILI" rozeti (boşken
## görünmez). Kilitli: fiyat — oyuncu neye ne kadar uzak olduğunu görsün.
func _make_state_band(entry: SkinEntry) -> Control:
	if entry.is_locked():
		var price := Label.new()
		price.name = "Price"
		UiType.apply(price, UiType.STAT)
		price.text = "%d Hamur" % entry.price
		price.add_theme_font_size_override("font_size", 13)
		price.add_theme_color_override("font_color", UiPalette.GOLD)
		price.modulate = Color(1, 1, 1, 0.75)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price.custom_minimum_size = Vector2(0.0, STATE_BADGE_HEIGHT)
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return price
	var badge := _make_pill(EQUIPPED_LABEL, EQUIPPED_COLOR, false)
	badge.name = "State"
	badge.custom_minimum_size = Vector2(0.0, STATE_BADGE_HEIGHT)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.modulate.a = 0.0
	return badge


# --- Seçim ---

func _on_card_input(event: InputEvent, skin_id: StringName) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_on_card_tapped(skin_id)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_on_card_tapped(skin_id)


## Sahip olunan kart: tak. Kilitli kart: vitrine al (takma).
func _on_card_tapped(skin_id: StringName) -> void:
	var entry: SkinEntry = _entries.get(skin_id)
	if entry == null:
		return
	if entry.is_locked():
		_focus(skin_id)
		AudioManager.play_sfx(&"star_pat", 0.8)
		return
	_try_equip(skin_id)


## Kilitli skin takılmaz — sessizce yok sayılır (SaveManager da ayrıca
## reddediyor, bu yalnızca gereksiz çağrıyı kesiyor). Başarılı equip'in
## UI etkisi SaveManager.skin_equipped sinyalinden geliyor
## (_on_skin_equipped); zaten takılıysa sinyal gelmez, yalnızca vitrin
## odağı tazelenir.
func _try_equip(skin_id: StringName) -> void:
	if skin_id != DEFAULT_ID and not SaveManager.owns_skin(skin_id):
		return
	if not SaveManager.equip_skin(skin_id):
		return
	_focus(skin_id)


func _focus(skin_id: StringName) -> void:
	var changed: bool = skin_id != _focused_id
	_focused_id = skin_id
	_apply_equipped_state()
	_refresh_showcase()
	if changed:
		UiMotion.pop(_showcase_preview_slot, 1.08)


# --- SaveManager sinyalleri ---

func _on_skin_equipped(skin_id: StringName) -> void:
	# Girişlerin takılılık bilgisini tazele; grid yeniden KURULMUYOR.
	for id: StringName in _entries:
		(_entries[id] as SkinEntry).equipped = id == skin_id
	if _is_new(skin_id):
		_has_new = false
	AudioManager.play_sfx(&"star_pat", 1.0)
	_focus(skin_id)


func _is_new(skin_id: StringName) -> bool:
	return _has_new and skin_id == _new_id


func _on_skin_granted(skin_id: StringName) -> void:
	_new_id = skin_id
	_has_new = true
	if not visible:
		# Sekme açılınca refresh() zaten geliyor (main.gd); o anda vitrine al.
		_pending_focus = skin_id
		_has_pending_focus = true
		return
	_has_pending_focus = false
	_focused_id = skin_id
	refresh()


## Tüm kartların takılı/normal/odaklı görünümünü tazeler.
func _apply_equipped_state() -> void:
	var equipped: StringName = SaveManager.equipped_skin_id()
	for id: StringName in _cards:
		var card: PanelContainer = _cards[id]
		if not is_instance_valid(card):
			continue
		_set_card_state(card, id == equipped, id == _focused_id and id != equipped)


func _set_card_state(card: PanelContainer, is_equipped: bool, is_focused: bool) -> void:
	var state := card.find_child("State", true, false) as PanelContainer
	var was_equipped: bool = card.get_meta("equipped", false)
	card.set_meta("equipped", is_equipped)
	if state != null:
		state.modulate.a = 1.0 if is_equipped else 0.0
	if is_equipped:
		card.add_theme_stylebox_override("panel", _equipped_stylebox())
		if not was_equipped:
			UiMotion.pop(card, 1.06)
	elif is_focused:
		card.add_theme_stylebox_override("panel", _focused_stylebox(card.get_meta("base_style")))
	else:
		card.add_theme_stylebox_override("panel", card.get_meta("base_style"))


## Kartın sakin hâli. Sahip olunan: plum yüzey, rarity kenar; Legendary
## kenarı altın ve daha kalın (albümdeki "büyük ödül" hissi). Kilitli: koyu,
## kenarı silik — keşfedilmemiş ama okunabilir. Varsayılan: nötr beyaz kenar.
static func _card_style(entry: SkinEntry) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var border: int = 2
	if entry.owned:
		box.bg_color = Color(0.2, 0.17, 0.42, 0.92)
		if entry.is_default():
			box.border_color = Color(1, 1, 1, 0.35)
		elif entry.rarity == SkinData.Rarity.LEGENDARY:
			box.border_color = Color(UiPalette.GOLD.r, UiPalette.GOLD.g, UiPalette.GOLD.b, 0.9)
			border = 3
		else:
			box.border_color = UiPalette.rarity_border(entry.rarity_color())
	else:
		box.bg_color = Color(0.1, 0.08, 0.24, 0.8)
		box.border_color = Color(1, 1, 1, 0.07)
	box.set_border_width_all(border)
	box.set_corner_radius_all(20)
	# Kenar kalınlığı + iç pay her zaman 10/12: kalın kenarlı kart içeriği
	# kaydırmasın.
	box.content_margin_left = 10.0 - border
	box.content_margin_right = 10.0 - border
	box.content_margin_top = 12.0 - border
	box.content_margin_bottom = 12.0 - border
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


## Vitrinde duran kilitli kart: kenarı beyaz — "şu an buna bakıyorsun".
static func _focused_stylebox(base: StyleBoxFlat) -> StyleBoxFlat:
	var box: StyleBoxFlat = base.duplicate()
	box.border_color = Color(1, 1, 1, 0.55)
	return box
