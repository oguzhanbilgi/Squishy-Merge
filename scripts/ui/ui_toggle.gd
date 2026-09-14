class_name UiToggle
extends Button
## Ayarlar anahtarı (M8.5-10): pill ray + kayan yuvarlak topuz.
##
## Free Casual GUI'nin "Pannel_time" anahtarı biçim referansı; asset
## olarak kullanılmadı (krem/turuncu, paletin dışında). Burada tema
## `ToggleOn` / `ToggleOff` stylebox'larıyla çiziliyor — nane = açık.
##
## `toggle_mode` açık bir Button: dokunma alanı 88x48, durum `button_pressed`.
## Topuz `_knob` (0..1) ile kayıyor, tween ile 0.14 sn.
##
## M8.6-01: ray variation'ları ve topuz dokusu dışarıdan verilebiliyor
## (`UiKit.switch_toggle` → `SwitchOn`/`SwitchOff` + LayerLab topuz);
## varsayılanlar M8.5 ayarlar panelini aynen korur.

const TRACK_SIZE: Vector2 = Vector2(88.0, 48.0)
const KNOB_RADIUS: float = 18.0
const KNOB_INSET: float = 6.0
const SLIDE_TIME: float = 0.14

## Ray stylebox'larının tema variation'ları.
var on_variation: StringName = &"ToggleOn"
var off_variation: StringName = &"ToggleOff"
## Verilirse topuz daire yerine bu dokuyla çizilir (9-slice değil; en/boy
## korunarak KNOB_RADIUS*2 yüksekliğe ölçeklenir).
var knob_texture: Texture2D = null

var _knob: float = 0.0
var _track_on: StyleBox
var _track_off: StyleBox


func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = TRACK_SIZE
	# Kendi çizimimiz var; temanın buton yüzeyi görünmesin.
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())


func _ready() -> void:
	_track_on = get_theme_stylebox("panel", on_variation)
	_track_off = get_theme_stylebox("panel", off_variation)
	_knob = 1.0 if button_pressed else 0.0
	toggled.connect(_on_toggled)
	# Anahtarin kendi sesi var (ayarlar paneli); evrensel tik'i alma.
	UiMotion.attach_press(self, false)
	queue_redraw()


func set_on(on: bool) -> void:
	set_pressed_no_signal(on)
	_knob = 1.0 if on else 0.0
	queue_redraw()


func _on_toggled(on: bool) -> void:
	var tween: Tween = create_tween()
	tween.tween_method(_set_knob, _knob, 1.0 if on else 0.0, SLIDE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_knob(value: float) -> void:
	_knob = value
	queue_redraw()


func _draw() -> void:
	# Pasif anahtar butunuyle soluk (ray + topuz); yalniz farkliysa yaz,
	# modulate degisimi yeniden cizim tetiklemesin.
	var target_alpha: float = 0.55 if disabled else 1.0
	if not is_equal_approx(modulate.a, target_alpha):
		modulate.a = target_alpha
	var rect := Rect2(Vector2.ZERO, size)
	# Kapalıdan açığa geçerken iki ray üst üste soluyor: renk sıçramasın.
	draw_style_box(_track_off, rect)
	if _knob > 0.0:
		var on_box := _track_on as StyleBoxFlat
		if on_box != null:
			var faded := on_box.duplicate() as StyleBoxFlat
			faded.bg_color.a = on_box.bg_color.a * _knob
			faded.border_color.a = on_box.border_color.a * _knob
			draw_style_box(faded, rect)
		var on_tex := _track_on as StyleBoxTexture
		if on_tex != null:
			var faded_tex := on_tex.duplicate() as StyleBoxTexture
			faded_tex.modulate_color.a = on_tex.modulate_color.a * _knob
			draw_style_box(faded_tex, rect)
	var travel: float = size.x - 2.0 * (KNOB_INSET + KNOB_RADIUS)
	var center := Vector2(KNOB_INSET + KNOB_RADIUS + travel * _knob, size.y * 0.5)
	if knob_texture != null:
		# Doku golgesini kendi tasiyor; yukseklik = topuz capi + tasma payi.
		var tex_size: Vector2 = knob_texture.get_size()
		var height: float = KNOB_RADIUS * 2.0 + 8.0
		var width: float = height * tex_size.x / tex_size.y
		var top_left := center - Vector2(width * 0.5, KNOB_RADIUS + 3.0)
		draw_texture_rect(knob_texture, Rect2(top_left, Vector2(width, height)), false,
			Color(1, 1, 1, 0.92 if disabled else 1.0))
		return
	draw_circle(center + Vector2(0, 2), KNOB_RADIUS, Color(0, 0, 0, 0.18))
	draw_circle(center, KNOB_RADIUS, Color(1, 1, 1, 0.92 if disabled else 1.0))
