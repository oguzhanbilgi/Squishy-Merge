extends CanvasLayer
## Günlük giriş ödülü penceresi (GAME_DESIGN.md §5.4).
## Sadece gösterge: ödül zaten SaveManager'a işlenmiş olarak buraya geliyor.

signal closed

## Seri sayacının noktaları. M8.5-09'a kadar "●" / "○" (U+25CF / U+25CB)
## idi; ikisi de ne Baloo 2'de ne Nunito'da var (dört font dosyasının cmap'i
## tek tek okundu), yani sistem fallback'inden bambaşka bir yazı tipiyle
## çizilirlerdi. İkisi de artık AYNI karakter (U+2022 "•", her iki ailede de
## var); dolu/boş ayrımını şekil değil RENK yapıyor.
##
## Bu yüzden etiket `Label` değil `RichTextLabel`: tek satırda iki farklı
## renk gerekiyor.
const STREAK_DOT: String = "•"
const STREAK_DOT_FILLED_COLOR: String = "ffd166"
const STREAK_DOT_EMPTY_COLOR: String = "ffffff55"
const STREAK_DOT_FONT_SIZE: int = 32
## Sayaçta gösterilen gün sayısı — seri bundan uzunsa "+N" olarak yazılır.
const STREAK_DOTS: int = 7

@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _reward: Label = $Center/Panel/VBox/Reward
@onready var _streak: RichTextLabel = $Center/Panel/VBox/Streak
@onready var _note: Label = $Center/Panel/VBox/Note
@onready var _close: Button = $Center/Panel/VBox/Close


func _ready() -> void:
	visible = false
	_close.pressed.connect(func() -> void:
		visible = false
		closed.emit())


func show_reward(result: Dictionary) -> void:
	var streak: int = result["streak"]
	_title.text = "Günlük ödül"
	_reward.text = "+%d Hamur" % result["reward"]
	_streak.text = "[center]%d günlük seri\n%s[/center]" % [
		streak, _streak_dots(streak)]
	# Seri kırıldıysa oyuncuya sebebini söyle, sessizce sıfırlama.
	_note.text = "Serin kırılmıştı, sayaç sıfırlandı." if result["streak_broken"] else ""
	visible = true


## Noktalar BBCode döner — `_streak` bir RichTextLabel.
func _streak_dots(streak: int) -> String:
	var filled: int = mini(streak, STREAK_DOTS)
	var dots: String = "[color=%s]%s[/color]" % [STREAK_DOT_FILLED_COLOR,
		_dot_run(filled)]
	if filled < STREAK_DOTS:
		dots += " [color=%s]%s[/color]" % [STREAK_DOT_EMPTY_COLOR,
			_dot_run(STREAK_DOTS - filled)]
	if streak > STREAK_DOTS:
		dots += "  +%d" % (streak - STREAK_DOTS)
	# "•" metin boyunda kucuk bir nokta; sayac olarak okunmasi icin buyutuluyor
	# (cekimde 21 px'te toplu igne basi gibi kaliyordu).
	return "[font_size=%d]%s[/font_size]" % [STREAK_DOT_FONT_SIZE, dots]


## Aralarında boşluk olan N nokta. Boşluksuz dizildiklerinde "•••••••"
## tek bir çizgi gibi okunuyor, sayılamıyor.
func _dot_run(count: int) -> String:
	var parts: PackedStringArray = []
	for i in count:
		parts.append(STREAK_DOT)
	return " ".join(parts)
