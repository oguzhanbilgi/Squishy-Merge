class_name UiMotion
extends RefCounted
## Mikro-etkilesimler (M8.5-10): buton basisi, pop, pencere acilisi,
## sekme/ekran gecisi. Hepsi kisa (<= 0.25 sn), kesilebilir ve gameplay'e
## dokunmuyor — yalnizca Control'lerin scale/modulate/position'i.
##
## Kural: 1 saniyelik yavas animasyon YOK. Hedef "snappy": oyuncu ikinci
## kez bastiginda ilk animasyonun bitmesini beklemiyor, tween oldurulup
## yeniden baslatiliyor (bkz. _restart).

## Basili butonun kucultme orani ve sureleri.
const PRESS_SCALE: float = 0.94
const PRESS_IN: float = 0.06
const PRESS_OUT: float = 0.18

const POP_SCALE: float = 1.12
const POP_TIME: float = 0.22

const MODAL_TIME: float = 0.2
const MODAL_FROM_SCALE: float = 0.92

const SCREEN_TIME: float = 0.16
const SCREEN_SLIDE: float = 14.0

const _META_TWEEN: StringName = &"ui_motion_tween"


## Butona basinca 0.94'e cekilir, birakinca yayla (TRANS_BACK) geri gelir.
## Bir kez baglanir; ayni butona ikinci cagri yok sayilir.
static func attach_press(button: BaseButton) -> void:
	if button.has_meta(&"ui_motion_press"):
		return
	button.set_meta(&"ui_motion_press", true)
	button.button_down.connect(func() -> void: _press_in(button))
	button.button_up.connect(func() -> void: _press_out(button))
	# Basili tutup disari surukleyince button_up gelmeyebilir; mouse_exited
	# ile de geri donuyor.
	button.mouse_exited.connect(func() -> void:
		if not button.button_pressed or not button.toggle_mode:
			_press_out(button))


static func _press_in(control: Control) -> void:
	_center_pivot(control)
	var tween: Tween = _restart(control)
	tween.tween_property(control, "scale", Vector2.ONE * PRESS_SCALE, PRESS_IN) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _press_out(control: Control) -> void:
	if control.scale.is_equal_approx(Vector2.ONE):
		return
	_center_pivot(control)
	var tween: Tween = _restart(control)
	tween.tween_property(control, "scale", Vector2.ONE, PRESS_OUT) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Kisa "pop": secim, satin alma basarisi, bakiye guncellemesi.
static func pop(control: Control, amount: float = POP_SCALE) -> void:
	if control == null or not is_instance_valid(control):
		return
	_center_pivot(control)
	var tween: Tween = _restart(control)
	control.scale = Vector2.ONE
	tween.tween_property(control, "scale", Vector2.ONE * amount, POP_TIME * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, POP_TIME * 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Pencere acilisi: karartma solar, panel 0.92'den yayla buyuyup gorunur.
## `dim` null olabilir (karartmasiz pencereler).
static func modal_open(panel: Control, dim: CanvasItem = null) -> void:
	if panel == null:
		return
	_center_pivot(panel)
	if dim != null:
		dim.modulate.a = 0.0
		var dim_tween: Tween = dim.create_tween()
		dim_tween.tween_property(dim, "modulate:a", 1.0, MODAL_TIME * 0.75)
	panel.scale = Vector2.ONE * MODAL_FROM_SCALE
	panel.modulate.a = 0.0
	var tween: Tween = _restart(panel)
	tween.set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, MODAL_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, MODAL_TIME * 0.6)


## Sekme ekrani gecisi: ekranin Control cocuklari hafif asagidan solarak
## gelir. CanvasLayer'in kendisi modulate tasimadigi icin cocuklara
## uygulaniyor. Cok kisa (0.16 sn) — sekmeler arasinda hizla gezerken
## bekleme hissi vermemeli.
static func screen_in(layer: CanvasLayer) -> void:
	for child in layer.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		# Yalnizca icerik container'lari kayar. Zemin (ShellBackdrop, harita)
		# kaymaz — ust kenarda bir an bosluk gorunurdu; zaten gorunmez olan
		# (toast, alfa 0) da ellenmez — yoksa gecis onu gorunur yapardi.
		if not (control is Container) or control.modulate.a < 0.99:
			continue
		var home_y: float = control.position.y
		control.modulate.a = 0.0
		control.position.y = home_y + SCREEN_SLIDE
		var tween: Tween = _restart(control)
		tween.set_parallel(true)
		tween.tween_property(control, "modulate:a", 1.0, SCREEN_TIME)
		tween.tween_property(control, "position:y", home_y, SCREEN_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Ustteki yazi/rozet: kisa yukari suzulme + sonme (toast).
static func toast(control: Control, rise: float = 34.0, time: float = 1.0) -> void:
	if not control.has_meta(&"toast_home"):
		control.set_meta(&"toast_home", control.position)
	var home: Vector2 = control.get_meta(&"toast_home")
	control.position = home + Vector2(0, 10)
	control.modulate.a = 0.0
	var tween: Tween = _restart(control)
	tween.set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, 0.12)
	tween.tween_property(control, "position", home - Vector2(0, rise), time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 0.0, time * 0.5).set_delay(time * 0.5)
	tween.chain().tween_callback(func() -> void: control.position = home)


static func _center_pivot(control: Control) -> void:
	control.pivot_offset = control.size * 0.5


## Kontrolun onceki tween'ini oldurup yenisini baslatir — animasyonlar
## kesilebilir olsun, ust uste binmesin.
static func _restart(control: Control) -> Tween:
	if control.has_meta(_META_TWEEN):
		var old: Tween = control.get_meta(_META_TWEEN)
		if old != null and old.is_valid():
			old.kill()
	var tween: Tween = control.create_tween()
	control.set_meta(_META_TWEEN, tween)
	return tween
