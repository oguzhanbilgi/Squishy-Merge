extends CanvasLayer
## Mağaza (GAME_DESIGN.md §5.6): skin'ler Hamur ile satın alınır.
## Rarity'e göre gruplanmış liste; sahip olunanlar "✓ Sahipsin" ile
## işaretli ve soluk kalıyor — listeden çıkarmak yerine işaretlemek
## koleksiyonun ne kadarının tamamlandığını da gösteriyor.
##
## Gerçek para / IAP YOK. Tek para birimi Hamur.

## Açılmamış skin'in silüet rengi — koleksiyon albümüyle aynı dil.
const LOCKED_COLOR: Color = Color(0.28, 0.28, 0.32)
const SWATCH_SIZE: Vector2 = Vector2(72.0, 72.0)

var _pending: SkinData = null

@onready var _dough: Label = $Margin/VBox/Dough
@onready var _list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var _toast: Label = $Toast
@onready var _confirm: Control = $Confirm
@onready var _confirm_text: Label = $Confirm/Panel/VBox/Text
@onready var _confirm_yes: Button = $Confirm/Panel/VBox/Buttons/Yes
@onready var _confirm_no: Button = $Confirm/Panel/VBox/Buttons/No


func _ready() -> void:
	_confirm_yes.pressed.connect(_on_confirm_yes)
	_confirm_no.pressed.connect(_close_confirm)
	_confirm.visible = false
	_toast.modulate.a = 0.0
	refresh()


func refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	var shown_rarity: int = -1
	for skin in SkinLibrary.all():
		if int(skin.rarity) != shown_rarity:
			shown_rarity = int(skin.rarity)
			_list.add_child(_make_rarity_header(skin.rarity))
		_list.add_child(_make_row(skin))

	_dough.text = "Hamur: %d" % SaveManager.dough()


func _make_rarity_header(rarity: SkinData.Rarity) -> Control:
	var label := Label.new()
	label.text = "%s  ·  %d Hamur" % [SkinData.rarity_name(rarity), Shop.price(rarity)]
	label.modulate = SkinData.rarity_color(rarity)
	label.add_theme_font_size_override("font_size", 22)
	return label


func _make_row(skin: SkinData) -> Control:
	var owned: bool = SaveManager.owns_skin(skin.id)

	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	card.custom_minimum_size = Vector2(0, 92)
	if owned:
		card.modulate = Color(1, 1, 1, 0.55)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var swatch := SkinSwatch.new()
	swatch.custom_minimum_size = SWATCH_SIZE
	swatch.setup(skin.tint if owned else LOCKED_COLOR,
		SkinData.rarity_color(skin.rarity), owned)
	row.add_child(swatch)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)

	var name_label := Label.new()
	name_label.text = skin.display_name
	text.add_child(name_label)

	var detail := Label.new()
	detail.add_theme_font_size_override("font_size", 15)
	if owned:
		detail.text = "✓ Sahipsin"
		detail.modulate = Color(0.6, 0.85, 0.6)
	else:
		detail.text = "%d Hamur" % Shop.price_of(skin)
		detail.modulate = SkinData.rarity_color(skin.rarity)
	text.add_child(detail)

	if not owned:
		var buy := Button.new()
		buy.text = "Satın Al"
		buy.custom_minimum_size = Vector2(150, 68)
		# Parası yetmiyorsa pasif — basılabilir görünüp reddetmek kötü his.
		buy.disabled = not Shop.can_afford(skin)
		buy.pressed.connect(_open_confirm.bind(skin))
		row.add_child(buy)

	return card


# --- Onay diyaloğu ---

func _open_confirm(skin: SkinData) -> void:
	_pending = skin
	_confirm_text.text = "%s\n%s  ·  %d Hamur\n\nSatın alınsın mı?" % [
		skin.display_name, SkinData.rarity_name(skin.rarity), Shop.price_of(skin)]
	_confirm.visible = true


func _close_confirm() -> void:
	_pending = null
	_confirm.visible = false


func _on_confirm_yes() -> void:
	var skin: SkinData = _pending
	_close_confirm()
	if skin == null:
		return
	if Shop.purchase(skin):
		AudioManager.play_sfx(&"chest_open", 1.0)
		_show_toast("%s alındı!" % skin.display_name)
	else:
		# Araya başka bir harcama girdiyse (teorik) sessizce düşmesin.
		_show_toast("Hamur yetmedi.")
	refresh()


## Basit başarı geri bildirimi: yukarı doğru süzülüp sönen bir yazı.
func _show_toast(message: String) -> void:
	_toast.text = message
	_toast.modulate.a = 1.0
	var home: Vector2 = _toast.position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_toast, "position", home - Vector2(0, 40), 1.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(_toast, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tween.chain().tween_callback(func() -> void: _toast.position = home)
