class_name PowerBar
extends Control
## Oyun içi güç kontrolleri (GAME_DESIGN.md §10): dört güç, stok, seçili
## durumu. M8.6-02: eski dört dev yatay pill KALKTI; her güç artık
## `UiKit.power_slot` — bevel gövde + owner güç sanatı + stok rozeti +
## silahlı parıltı. Slotlar HUD'da iki sol + iki sağ (üst oyun alanının
## çevresinde) durur; konumlar `GameplayLayout.compute()["slots"]` ile
## `apply_layout` üzerinden verilir, burada sabit koordinat yok.
##
## DAVRANIŞ DEĞİŞMEDİ: buton stok 0'da da basılabilir (refill akışı),
## `set_enabled(false)` tümünü `disabled` yapar, `set_armed` seçili slotu
## işaretler. Stok verisi SaveManager'dan okunur; burada stok DEĞİŞMEZ.

signal power_pressed(type: int)

## Slot sırası: tip -> slot indeksi. Sol ikili hedefli güçler (Bomba,
## Büyütücü), sağ ikili anında güçler (Sarsıntı, Temizleyici).
const SLOT_ORDER: Array[PowerUp.Type] = [
	PowerUp.Type.BOMB, PowerUp.Type.UPGRADE,
	PowerUp.Type.SHAKE, PowerUp.Type.CLEAR_SMALL,
]

var _slots: Dictionary = {}
var _armed: int = PowerUpController.ARMED_NONE
var _enabled: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for type in SLOT_ORDER:
		var slot: Button = UiKit.power_slot(PowerUp.icon(type),
			SaveManager.powerup_count(type), GameplayLayout.SLOT_SIZE)
		slot.name = "Slot_%s" % PowerUp.SAVE_KEYS[type]
		slot.tooltip_text = PowerUp.display_name(type)
		slot.pressed.connect(func() -> void: power_pressed.emit(int(type)))
		add_child(slot)
		_slots[int(type)] = slot
	refresh()


## Slot dikdörtgenleri (ekran koordinatı, HUD katmanı). Sıra SLOT_ORDER.
func apply_layout(rects: Array[Rect2]) -> void:
	for i in SLOT_ORDER.size():
		if i >= rects.size():
			break
		var slot: Button = _slots[int(SLOT_ORDER[i])]
		slot.position = rects[i].position
		slot.size = rects[i].size
		slot.pivot_offset = rects[i].size * 0.5


## Stok ve seçili durumunu tazeler. Her round başında ve her kullanımda
## çağrılıyor — sayılar anında güncellensin.
func refresh() -> void:
	for type in SLOT_ORDER:
		UiKit.set_power_slot_state(_slots[int(type)], SaveManager.powerup_count(type),
			_armed == int(type), _enabled)


## Çubuğu tümden açar/kapatır (M8.5-04). Kapalıyken hiçbir güç kullanılamaz
## ve stok tüketilemez; stoklar olduğu gibi durur, tekrar açılınca kaldığı
## yerden devam eder.
func set_enabled(enabled: bool) -> void:
	if enabled == _enabled:
		return
	_enabled = enabled
	refresh()


func set_armed(type: int) -> void:
	_armed = type
	refresh()


func slot(type: int) -> Button:
	return _slots.get(type)


## Slotun ekranda gösterdiği stok (testler için).
func displayed_count(type: int) -> int:
	return UiKit.power_slot_count(_slots.get(type))


func slot_rect(type: int) -> Rect2:
	var s: Button = _slots.get(type)
	return Rect2(s.position, s.size) if s != null else Rect2()
