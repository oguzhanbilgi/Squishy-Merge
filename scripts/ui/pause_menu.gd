extends CanvasLayer
## Mola / çıkış penceresi (M8.6-02 HUD v2). Oyun içi Geri ve Çıkış
## butonları ile Android geri tuşu bunu açar; uygulama DOĞRUDAN
## KAPANMAZ. Pencere açıkken board `set_menu_paused` ile donuk (Main).
##
##   Devam Et          → kapanır, oyun kaldığı yerden sürer
##   Yeniden Başlat    → aynı level baştan (Main._start_level)
##   Ana Menüye Dön    → round terk edilir: sonuç/ödül YOK, haritaya dönülür
##
## Production iskelet: `UiKit.modal_frame` (pembe kurdele "Mola" + krem
## gövde + kapat) — kapat ve karartmaya dokunuş = Devam Et.

signal resume_pressed
signal restart_pressed
signal exit_pressed

var _frame: Control
var _resume: Button
var _restart: Button
var _exit: Button

@onready var _dim: ColorRect = $Center/Dim
@onready var _anchor: CenterContainer = $Center/Anchor


func _ready() -> void:
	visible = false
	_frame = UiKit.modal_frame("Mola", 560.0)
	_anchor.add_child(_frame)
	var body: VBoxContainer = _frame.get_meta(&"body")
	body.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	var note := UiKit.label("Oyun duraklatıldı.", &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(note)
	_resume = UiKit.cta("DEVAM ET", "", &"ButtonCTA", "play")
	_resume.pressed.connect(func() -> void: resume_pressed.emit())
	body.add_child(_resume)
	_restart = UiKit.button("Yeniden Başlat", &"ButtonSecondary", "refresh")
	_restart.pressed.connect(func() -> void: restart_pressed.emit())
	body.add_child(_restart)
	_exit = UiKit.button("Ana Menüye Dön", &"ButtonDanger", "home")
	_exit.pressed.connect(func() -> void: exit_pressed.emit())
	body.add_child(_exit)
	(_frame.get_meta(&"close_button") as Button).pressed.connect(func() -> void: resume_pressed.emit())
	_dim.gui_input.connect(_on_dim_input)


func open_menu() -> void:
	if visible:
		return
	visible = true
	UiMotion.modal_open(_frame, _dim)
	AudioManager.play(&"ui_modal_open")


func close_menu() -> void:
	if not visible:
		return
	visible = false
	AudioManager.play(&"ui_modal_close")


func _on_dim_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null and not touch.pressed:
		resume_pressed.emit()
