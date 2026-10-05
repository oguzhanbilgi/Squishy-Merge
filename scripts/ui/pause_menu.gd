extends CanvasLayer
## Mola / çıkış penceresi (M8.6-02 HUD v2). Oyun içi Geri ve Çıkış
## butonları ile Android geri tuşu bunu açar; uygulama DOĞRUDAN
## KAPANMAZ. Pencere açıkken board `set_menu_paused` ile donuk (Main).
##
##   Devam Et          → kapanır, oyun kaldığı yerden sürer
##   Yeniden Başlat    → aynı level baştan (Main._start_level)
##   Ana Menüye Dön    → round terk edilir: sonuç/ödül YOK, haritaya dönülür
##
## M8.6-08 dar cila: production iskelet v2 (`UiKit.modal_shell`, pembe
## kurdele "Mola", OTURMUŞ X — kurdele kuyruğuna binmez), üç eylem altlıkta
## (asla kaydırılmaz): DEVAM ET kahraman cyan / Yeniden Başlat lavanta /
## ince ayraç / Ana Menüye Dön pembe (çıkış vurgusu, kahramandan zayıf).
## Eylemler, terk davranışı, geri tuşu = devam, karartma dokunuşu = devam
## DEĞİŞMEDİ; onay penceresi eklenmedi (owner kararı).
## TASK/049: round açık molanın altında kesinleşirse Main pencereyi EYLEMSİZ
## kapatır (`close_menu` — hiçbir eylem sinyali yayılmaz); kapalı pencerenin
## düğmeleri / karartması da eylem yaymaz (`_emit_if_open`).

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
	_frame = UiKit.modal_shell("Mola", 560.0, &"ribbon", false, true)
	_anchor.add_child(_frame)
	var footer: VBoxContainer = _frame.get_meta(&"footer")
	footer.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	var top_gap := Control.new()
	top_gap.custom_minimum_size = Vector2(0, UiTokens.SPACE_SM)
	top_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(top_gap)
	_resume = UiKit.cta("DEVAM ET", "", &"ButtonCTA", "play")
	_resume.name = "Resume"
	GestureGuard.on_pressed(_resume, _emit_if_open.bind(resume_pressed))
	footer.add_child(_resume)
	_restart = UiKit.button("Yeniden Başlat", &"ButtonSecondary", "refresh")
	_restart.name = "Restart"
	GestureGuard.on_pressed(_restart, _emit_if_open.bind(restart_pressed))
	footer.add_child(_restart)
	footer.add_child(UiKit.settings_divider())
	_exit = UiKit.button("Ana Menüye Dön", &"ButtonDanger", "home")
	_exit.name = "Exit"
	GestureGuard.on_pressed(_exit, _emit_if_open.bind(exit_pressed))
	footer.add_child(_exit)
	GestureGuard.on_pressed(_frame.get_meta(&"close_button") as Button, _emit_if_open.bind(resume_pressed))
	UiKit.attach_dim_close(_dim, _emit_if_open.bind(resume_pressed))
	UiKit.modal_relayout(_frame)


## TASK/049: KAPALI pencere hiçbir eylem YAYMAZ — üç düğme, X ve karartma bu kapıdan geçer. Round açık molanın
## altında kesinleşince Main molayı eylemsiz kapatır (`close_menu`); gizleme anında Godot odaklı düğmeye sentetik
## bırakış yollar ve son girdi olayı "işlendi" değilse (ör. GERİ tuşu, başka bir parmak / aygıt) BaseButton onu
## tıklama sayar — masaüstü 4.6.3 sondasında üç düğme de gizlemede tetiklendi (A36'daki basılı Koleksiyon kartı +
## GERİ ile aynı motor yolu); gizlenen karartma ise parmak odağını düşürmez, basılı parmağın bırakışı sonradan ona
## gelir. Gizleme yayılırken `visible` zaten false.
func _emit_if_open(action: Signal) -> void:
	if visible:
		action.emit()


func open_menu() -> void:
	if visible:
		return
	visible = true
	UiKit.modal_relayout(_frame)
	UiMotion.modal_open(_frame, _dim)
	AudioManager.play(&"ui_modal_open")


func close_menu() -> void:
	if not visible:
		return
	visible = false
	AudioManager.play(&"ui_modal_close")


## Testler için.
func frame() -> Control:
	return _frame


func buttons() -> Array[Button]:
	return [_resume, _restart, _exit]
