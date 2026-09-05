extends CanvasLayer
## Round sonu ekranı. GAME_DESIGN.md §5.1'deki yıldız reveal'ı ve sandık
## animasyonu M3'te buraya eklenecek; şu an sadece sonuç + butonlar.

signal retry_pressed
signal exit_pressed

@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _detail: Label = $Center/Panel/VBox/Detail
@onready var _retry: Button = $Center/Panel/VBox/Buttons/Retry
@onready var _exit: Button = $Center/Panel/VBox/Buttons/Exit


func _ready() -> void:
	hide_result()
	_retry.pressed.connect(func() -> void: retry_pressed.emit())
	_exit.pressed.connect(func() -> void: exit_pressed.emit())


func hide_result() -> void:
	visible = false


func show_result(level: LevelData, won: bool, score: int, new_record: bool) -> void:
	if level.is_endless:
		_title.text = "Yeni rekor!" if new_record else "Bitti"
		_detail.text = "Skor: %d\nRekor: %d" % [score, SaveManager.endless_high_score()]
	else:
		# objective_text() zaten "Hedef: ..." ile başlıyor, tekrar ekleme.
		_title.text = ("Level %d tamam!" % level.level_number) if won else "Olmadı"
		_detail.text = "Skor: %d\n%s" % [score, level.objective_text()]
	visible = true
