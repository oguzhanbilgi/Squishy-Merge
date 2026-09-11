extends CanvasLayer
## Ana Sayfa (M8.5-10): commercial-game home ekranı.
##
##   üst çubuk    günlük seri cipi (sol) · ayarlar dişlisi (sağ)
##   hero         SQUISHY MERGE logosu + owner'ın maskot pozu
##   durum        Hamur ve koleksiyon cipleri
##   birincil CTA OYNA — ekrandaki tek büyük candy pill, hiyerarşide 1 numara
##
## Zemin candy-night (ShellBackdrop) — dört sekme ve oyun ekranı aynı dünyada.
## Oyna haritaya götürüyor (main.gd bağlıyor).

signal play_pressed
signal settings_pressed

## OYNA butonunun genişliği: owner'ın 620x120 pill dokusunun doğal oranı
## (5.17). Yükseklik sahnede 118 → genişlik 610; 720 px ekranda iki yanda
## 55 px pay kalıyor.
const PLAY_WIDTH: float = 610.0

var _streak_chip: PanelContainer
var _dough_chip: PanelContainer
var _collection_chip: PanelContainer
var _settings_button: Button

@onready var _play: TextureButton = $Margin/VBox/Play
@onready var _play_hint: Label = $Margin/VBox/PlayHint
@onready var _chips: HBoxContainer = $Margin/VBox/Chips
@onready var _streak_slot: HBoxContainer = $TopBar/Row/StreakSlot
@onready var _settings_slot: HBoxContainer = $TopBar/Row/SettingsSlot
@onready var _mascot: TextureRect = $Margin/VBox/MascotSlot/Mascot


func _ready() -> void:
	_play.custom_minimum_size.x = PLAY_WIDTH
	_play.pressed.connect(func() -> void: play_pressed.emit())
	UiMotion.attach_press(_play)

	_streak_chip = UiPalette.chip(UiIcons.FLAME, "")
	_streak_slot.add_child(_streak_chip)

	_settings_button = UiPalette.icon_button(UiPalette.ICON_SETTINGS, 64.0, UiPalette.CREAM)
	_settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	_settings_slot.add_child(_settings_button)

	_dough_chip = UiPalette.chip(UiIcons.DOUGH, "")
	_collection_chip = UiPalette.chip(UiPalette.ICON_BADGE, "", 22, UiPalette.GOLD)
	_chips.add_child(_dough_chip)
	_chips.add_child(_collection_chip)

	_start_mascot_bob()
	refresh()


func refresh() -> void:
	var streak: int = SaveManager.daily_streak()
	UiPalette.set_chip_value(_streak_chip,
		"%d günlük seri" % streak if streak > 0 else "Seri başlasın", false)
	UiPalette.set_chip_value(_dough_chip, "%d Hamur" % SaveManager.dough(), false)
	UiPalette.set_chip_value(_collection_chip, "%d/%d" % [
		SaveManager.owned_skins().size(), SkinLibrary.total_count()], false)

	# OYNA'nın altındaki tek satır: oyuncu nereye gideceğini bilsin.
	var next_level: int = SaveManager.highest_level_unlocked()
	var total: int = LevelLibrary.load_levels().size()
	if next_level > total:
		_play_hint.text = "Tüm level'lar tamam · Sonsuz Mod açık"
	else:
		_play_hint.text = "Sıradaki: Level %d" % next_level


## Maskot yavaşça nefes alıyor — hero bölgesi ölü durmasın. Sonsuz, hafif
## (±6 px), 2.4 sn periyot. Görsel düz bir Control yuvasının içinde: VBox
## yalnızca yuvayı yerleştiriyor, görselin position'ı tween'e kalıyor
## (doğrudan container çocuğu olsaydı her yeniden yerleşimde zıplardı).
func _start_mascot_bob() -> void:
	var tween: Tween = _mascot.create_tween().set_loops()
	tween.tween_property(_mascot, "position:y", _mascot.position.y - 6.0, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).as_relative()
	tween.tween_property(_mascot, "position:y", 6.0, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).as_relative()
