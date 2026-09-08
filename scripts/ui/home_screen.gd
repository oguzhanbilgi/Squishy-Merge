extends CanvasLayer
## Ana Sayfa: minimal karşılama ekranı — hoşgeldin, günlük seri, Hamur ve
## "Oyna" butonu. Oyna haritaya götürüyor (main.gd bağlıyor).
##
## Bilerek sade: asıl içerik Harita/Koleksiyon/Mağaza sekmelerinde.

signal play_pressed

@onready var _streak: Label = $Margin/VBox/Streak
@onready var _dough: Label = $Margin/VBox/Dough
@onready var _play: Button = $Margin/VBox/Play


func _ready() -> void:
	_play.pressed.connect(func() -> void: play_pressed.emit())
	refresh()


func refresh() -> void:
	var streak: int = SaveManager.daily_streak()
	_streak.text = "Günlük seri: %d gün" % streak if streak > 0 else "Günlük seri henüz başlamadı"
	_dough.text = "Hamur: %d   ·   Koleksiyon: %d/%d" % [
		SaveManager.dough(), SaveManager.owned_skins().size(),
		SkinLibrary.total_count()]
