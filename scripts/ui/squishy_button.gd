class_name SquishyButton
extends Button
## Squishy UI System V3 (TASK/057) — CTA ailesi: tek bileşen, beş tür, açık durum makinesi.
##
##   PRIMARY      OYNA / BAŞLA — cyan candy, ekranın baskın eylemi (HERO boyu)
##   SECONDARY    MEYDAN OKUMA / ikincil gezinme — koyu lavanta, beyaz yazı
##   REWARD       ÖDÜLÜ AL — nane; ALINDI (CLAIMED) düz krem + nane tik
##   REWARDED_AD  REKLAM İZLE n/2 — pembe + film pictosu + sayaç cipi; 2/2 = EXHAUSTED,
##                yaş / rıza / reklam yok = UNAVAILABLE (gri, sebep yazısı)
##   CURRENCY     fiyat dugmesi — Hamur ikonu + fiyat (nane); Hamur yetmiyor = INSUFFICIENT
##                (dokunulabilir, soluk — geri bildirim verir; gerçek pasiften ayrık)
##
## Görsel `UiKit.draw_candy` (dudak + yüz + gloss + dış halka + gölge); BASINCA yüz dudağa
## iner (LIP_REST → LIP_PRESSED, içerik de iner) + `UiMotion` %94 squash ve `ui_tap` — yalnız
## opaklık değil. Pasif / alınmış / tükenmiş: düz (LIP_FLAT), `disabled`. Odak: oyun dokunmatik,
## FOCUS_NONE (klavye odağı uygulamada yok); kodla `pressed` / erişilebilirlik tıklaması çalışır.
## Eylem bağlamak: `GestureGuard.on_pressed(button, action)` (TASK/055) — bu bileşen basış
## sahipliğine dokunmaz, yalnız görseli çizer. Kaydırılan içerikte `set_scrollable(true)`
## (PASS + kaydırma başlayınca basış görseli bırakılır — M8.6-06.3 kuralı).
## Ekonomi / reklam mantığı YOK: durum ve sayaç ÇAĞIRANDAN gelir.

enum Kind { PRIMARY, SECONDARY, REWARD, REWARDED_AD, CURRENCY }
enum SizeClass { HERO, NORMAL, COMPACT }
enum State { NORMAL, DISABLED, CLAIMED, EXHAUSTED, UNAVAILABLE, INSUFFICIENT }

## Boy sınıfı yükseklikleri (dudak dahil): HERO kahraman CTA, NORMAL ≥ TOUCH_TARGET (A36'da
## 48 dp), COMPACT kart içi (TOUCH_COMPACT).
const HEIGHTS: Dictionary = {SizeClass.HERO: float(UiTokens.BUTTON_HEIGHT_HERO),
	SizeClass.NORMAL: float(UiTokens.BUTTON_HEIGHT), SizeClass.COMPACT: float(UiTokens.BUTTON_HEIGHT_COMPACT)}
const TEXT_SIZES: Dictionary = {
	SizeClass.HERO: UiTokens.TYPE_BUTTON_HERO,
	SizeClass.NORMAL: UiTokens.TYPE_BUTTON,
	SizeClass.COMPACT: UiTokens.TYPE_BUTTON_COMPACT,
}
const RADII: Dictionary = {
	SizeClass.HERO: UiTokens.RADIUS_FEATURE,
	SizeClass.NORMAL: UiTokens.RADIUS_CONTROL,
	SizeClass.COMPACT: UiTokens.RADIUS_CONTROL,
}
const ICON_SIZES: Dictionary = {SizeClass.HERO: 44.0, SizeClass.NORMAL: 36.0, SizeClass.COMPACT: 24.0}
const SIDE_PAD: Dictionary = {SizeClass.HERO: 36.0, SizeClass.NORMAL: 24.0, SizeClass.COMPACT: 12.0}
## TASK/057 Tur 2: kahraman CTA daha boyutlu — kalın dudak + yükseltilmiş gölge (basışta yine LIP_PRESSED'e iner).
const LIP_HERO: float = 10.0
const MIN_WIDTHS: Dictionary = {SizeClass.HERO: 320.0, SizeClass.NORMAL: 200.0, SizeClass.COMPACT: 132.0}
const RIM_WIDTH: float = 3.0
const DOUGH_ART: Texture2D = preload("res://assets/visual/ui/icon_dough.png")
const CLAIMED_TEXT: String = "ALINDI"

var _kind: Kind = Kind.PRIMARY
var _size_class: SizeClass = SizeClass.NORMAL
var _state: State = State.NORMAL
var _title_text: String = ""
var _lip: float = UiTokens.LIP_REST
var _pressed_visual: bool = false
var _row: HBoxContainer
var _icon: TextureRect
var _title: Label
var _chip: PanelContainer
var _chip_label: Label
var _price: Label
var _icon_role: String = ""
var _icon_art: Texture2D = null
var _counter: String = ""
var _price_set: bool = false
## Ödüllü reklam ilerlemesi (set_ad_progress); _ad_total 0 = verilmedi.
var _ad_done: int = 0
var _ad_total: int = 0
## Geçici sebep başlığı (UNAVAILABLE / DISABLED: "REKLAM YOK"…); NORMAL'e dönünce asıl başlık.
var _reason: String = ""


func _init(title: String = "", kind: int = Kind.PRIMARY, size_class: int = SizeClass.NORMAL,
		icon_role: String = "", icon_art: Texture2D = null) -> void:
	_kind = kind as Kind
	_size_class = size_class as SizeClass
	_title_text = title
	_icon_role = icon_role
	_icon_art = icon_art
	focus_mode = Control.FOCUS_NONE
	text = ""
	clip_contents = false
	for style_name in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	_build()
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	mouse_exited.connect(func() -> void:
		if _pressed_visual and not button_pressed:
			_set_pressed_visual(false))
	resized.connect(_place_row)
	UiMotion.attach_press(self)
	_apply()


func _build() -> void:
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", UiTokens.SPACE_SM + 2)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	var icon_size: float = ICON_SIZES[_size_class]
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_icon)
	_title = UiType.v3_label(_title_text, UiType.V3_BUTTON, false, HORIZONTAL_ALIGNMENT_CENTER,
		TEXT_SIZES[_size_class])
	_title.name = "Title"
	_row.add_child(_title)
	_price = UiType.v3_label("", UiType.V3_BUTTON, false, HORIZONTAL_ALIGNMENT_CENTER, TEXT_SIZES[_size_class])
	_price.name = "Price"
	_price.visible = false
	_row.add_child(_price)
	_chip = PanelContainer.new()
	_chip.name = "Chip"
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chip.visible = false
	_row.add_child(_chip)
	_chip_label = UiType.v3_label("", UiType.V3_BADGE, true, HORIZONTAL_ALIGNMENT_CENTER)
	_chip_label.name = "ChipText"
	_chip.add_child(_chip_label)
	# Yazı ölçüsü (tema fontu) ağaçta kesinleşir: satır büyüdükçe düğme de büyür, içerik taşmaz.
	_row.minimum_size_changed.connect(_update_min)


# --- Genel API ------------------------------------------------------------------

func kind() -> Kind:
	return _kind


func size_class() -> SizeClass:
	return _size_class


func state() -> State:
	return _state


func set_kind(value: int) -> void:
	_kind = value as Kind
	_apply()


func set_title(value: String) -> void:
	_title_text = value
	_apply()


func title() -> String:
	return _title.text


func title_label() -> Label:
	return _title


## Durum geçişi (çağıran karar verir) — `disabled`'ın TEK kaynağı. DISABLED / CLAIMED / EXHAUSTED /
## UNAVAILABLE → `disabled`; INSUFFICIENT dokunulabilir kalır (geri bildirim çağıranın). `reason` yalnız
## UNAVAILABLE / DISABLED'da geçici başlıktır ("REKLAM YOK"); NORMAL'e dönünce asıl başlık geri gelir. Tükenmiş
## reklam ilerlemesi (done ≥ total) NORMAL istense de EXHAUSTED kalır (yaş / rıza dönünce "2/2" etkin görünmez).
func set_state(value: int, reason: String = "") -> void:
	_state = value as State
	_reason = reason if (_state == State.UNAVAILABLE or _state == State.DISABLED) else ""
	if _state == State.NORMAL and _ad_total > 0 and _ad_done >= _ad_total:
		_state = State.EXHAUSTED
	_apply()


## Kısayol: etkin ↔ DISABLED (aynı durum makinesi; `disabled`'ı doğrudan YAZMAYIN — `_apply` durumdan kurar).
func set_enabled(value: bool) -> void:
	set_state(State.NORMAL if value else State.DISABLED)


func is_enabled() -> bool:
	return not _is_flat()


## Sayaç cipi ("0/2", "YENİ"…); boş metin gizler. ALINDI durumunda gizli.
func set_counter(value: String) -> void:
	_counter = value
	_apply()


func counter_text() -> String:
	return _chip_label.text if _chip.visible else ""


## Ödüllü reklam ilerlemesi: "done/total" cipi. Yalnız NORMAL ↔ EXHAUSTED türetilir (done ≥ total → EXHAUSTED);
## DISABLED / CLAIMED / INSUFFICIENT / UNAVAILABLE çağıranındır, ilerleme onları ezmez. Kota mantığı YOK (TASK/060).
func set_ad_progress(done: int, total: int) -> void:
	_ad_total = maxi(total, 0)
	_ad_done = clampi(done, 0, _ad_total)
	_counter = "%d/%d" % [_ad_done, _ad_total]
	if _state == State.NORMAL or _state == State.EXHAUSTED:
		_state = State.EXHAUSTED if (_ad_total > 0 and _ad_done >= _ad_total) else State.NORMAL
	_apply()


## Fiyat (CURRENCY): Hamur ikonu + rakam. Başlık verilmişse solunda kalır.
func set_price(amount: int) -> void:
	_price.text = GameplayHud._thousands(amount)
	_price_set = true
	_apply()


func price_text() -> String:
	return _price.text if _price.visible else ""


## Kaydırılan içerikte (M8.6-06.3): PASS — basış ScrollContainer'a da ulaşır; kaydırma
## başlayınca basış görseli bırakılır (BaseButton basışı iptal eder, button_up yaymaz).
func set_scrollable(value: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS if value else Control.MOUSE_FILTER_STOP


## Testler / inceleme: yüzün dinlenme konumundan çökmesi (px). Dinlenmede 0.
func face_offset() -> float:
	return _rest_lip() - _lip if not _is_flat() else 0.0


func is_pressed_visual() -> bool:
	return _pressed_visual


## Yüz dikdörtgeni (içerik bunun içinde) — kontrol koordinatı.
func face_rect() -> Rect2:
	var rest: float = _rest_lip()
	return Rect2(Vector2(0.0, rest - _lip), Vector2(size.x, maxf(size.y - rest, 1.0)))


func row() -> HBoxContainer:
	return _row


# --- Durum → görünüm -------------------------------------------------------------

func _is_flat() -> bool:
	return _state == State.DISABLED or _state == State.CLAIMED or _state == State.EXHAUSTED \
		or _state == State.UNAVAILABLE


func _rest_lip() -> float:
	if _is_flat():
		return UiTokens.LIP_FLAT
	return LIP_HERO if _size_class == SizeClass.HERO else UiTokens.LIP_REST


## [yüz, dudak, halka, yazı rengi, yazı koyu yüzeyde mi].
func _palette() -> Array:
	if _state == State.CLAIMED:
		return [UiTokens.SURFACE_NEUTRAL, UiTokens.SURFACE_NEUTRAL_DEEP, UiTokens.ROLE_REWARD,
			UiTokens.TEXT_POSITIVE, false]
	if _is_flat():
		return [UiTokens.ROLE_DISABLED, UiTokens.ROLE_DISABLED_DEEP, UiTokens.BORDER_COLOR_DISABLED,
			UiTokens.TEXT_DISABLED, false]
	match _kind:
		Kind.SECONDARY:
			return [UiTokens.ROLE_SECONDARY, UiTokens.ROLE_SECONDARY_DEEP, UiTokens.LAVENDER_LIGHT,
				UiTokens.TEXT_ON_DARK, true]
		Kind.REWARD:
			return [UiTokens.ROLE_REWARD, UiTokens.ROLE_REWARD_DEEP, UiTokens.BORDER_COLOR_STANDARD,
				UiTokens.TEXT_ON_ACCENT, false]
		Kind.REWARDED_AD:
			return [UiTokens.ROLE_AD, UiTokens.ROLE_AD_DEEP, UiTokens.BORDER_COLOR_STANDARD,
				UiTokens.TEXT_ON_DARK, true]
		Kind.CURRENCY:
			if _state == State.INSUFFICIENT:
				return [UiTokens.ROLE_CURRENCY_MUTED, UiTokens.ROLE_CURRENCY_MUTED_DEEP,
					UiTokens.ROLE_CURRENCY, UiTokens.TEXT_INSUFFICIENT, false]
			return [UiTokens.ROLE_CURRENCY, UiTokens.ROLE_CURRENCY_DEEP, UiTokens.BORDER_COLOR_STANDARD,
				UiTokens.TEXT_ON_ACCENT, false]
	return [UiTokens.ROLE_PRIMARY, UiTokens.ROLE_PRIMARY_DEEP, UiTokens.BORDER_COLOR_STANDARD,
		UiTokens.TEXT_ON_ACCENT, false]


func _apply() -> void:
	if _title == null:
		return
	disabled = _is_flat()
	if _is_flat() and _pressed_visual:
		# Basılıyken pasifleşti (ör. reklam durumu değişti): BaseButton bırakışı yok sayar → görsel + ölçek burada.
		_set_pressed_visual(false)
		UiMotion.release(self)
	var pal: Array = _palette()
	var text_color: Color = pal[3]
	var on_dark: bool = pal[4]
	var title_text: String = _title_text
	if _state == State.CLAIMED:
		title_text = CLAIMED_TEXT
	elif not _reason.is_empty():
		title_text = _reason
	_title.text = title_text
	_title.visible = not title_text.is_empty()
	UiType.v3(_title, UiType.V3_BUTTON, on_dark, TEXT_SIZES[_size_class])
	_title.add_theme_color_override("font_color", text_color)
	UiType.v3(_price, UiType.V3_BUTTON, on_dark, TEXT_SIZES[_size_class])
	_price.add_theme_color_override("font_color", text_color)
	# İkon: tür varsayılanı (film / tik / Hamur) ya da çağıranın pictosu / sanatı.
	var tex: Texture2D = _icon_art
	var tint: Color = Color.WHITE
	var role: String = _icon_role
	if _state == State.CLAIMED:
		role = "check"
		tex = null
	elif tex == null and role.is_empty():
		match _kind:
			Kind.REWARDED_AD:
				role = "movie"
			Kind.CURRENCY:
				tex = DOUGH_ART
	if tex == null and not role.is_empty():
		tex = UiKit.icon_texture(role)
		tint = text_color
	_icon.texture = tex
	_icon.self_modulate = Color(tint, 0.55) if (_is_flat() and _state != State.CLAIMED) else tint
	if _state == State.CLAIMED:
		_icon.self_modulate = UiTokens.TEXT_POSITIVE
	_icon.visible = tex != null
	# Sayaç cipi: koyu yarı saydam (pasifte koyu gri); ALINDI'da sayaç ve fiyat gizli.
	_chip_label.text = _counter
	_chip.visible = not _counter.is_empty() and _state != State.CLAIMED
	_price.visible = _price_set and _state != State.CLAIMED
	var chip_color: Color = Color(UiTokens.NAVY_PURPLE_DEEP, 0.55) if not _is_flat() else Color(UiTokens.DISABLED_DEEP, 0.9)
	_chip.add_theme_stylebox_override("panel", UiKit.v3_chip(chip_color))
	_chip_label.add_theme_color_override("font_color", UiTokens.TEXT_ON_DARK)
	_update_min()
	_lip = UiTokens.LIP_PRESSED if _pressed_visual else _rest_lip()
	_place_row()
	queue_redraw()


## En küçük boy: içerik satırı + yan paylar (boy sınıfının alt sınırı), yükseklik boy sınıfından.
func _update_min() -> void:
	var row_w: float = _row.get_combined_minimum_size().x + float(SIDE_PAD[_size_class]) * 2.0
	custom_minimum_size = Vector2(maxf(MIN_WIDTHS[_size_class], ceilf(row_w)), HEIGHTS[_size_class])


func _place_row() -> void:
	if _row == null:
		return
	var face: Rect2 = face_rect()
	var pad: float = SIDE_PAD[_size_class]
	_row.position = Vector2(pad, face.position.y)
	_row.size = Vector2(maxf(size.x - pad * 2.0, 0.0), face.size.y)


func _draw() -> void:
	var pal: Array = _palette()
	var rim_w: float = RIM_WIDTH if _state != State.CLAIMED else float(UiTokens.BORDER_STANDARD)
	var depth: Dictionary = {} if _is_flat() else (UiTokens.DEPTH_ELEVATED if _size_class == SizeClass.HERO
		else UiTokens.DEPTH_RESTING)
	var gloss: float = UiTokens.GLOSS_ALPHA * (0.4 if _is_flat() else (0.95 if _size_class == SizeClass.HERO else 0.8))
	UiKit.draw_candy(self, Rect2(Vector2.ZERO, size), pal[0], pal[1], float(RADII[_size_class]),
		_lip, _rest_lip(), depth, pal[2], rim_w, gloss)


# --- Basış görseli ----------------------------------------------------------------

func _on_down() -> void:
	_set_pressed_visual(true)


func _on_up() -> void:
	_set_pressed_visual(false)


func _set_pressed_visual(value: bool) -> void:
	_pressed_visual = value and not _is_flat()
	_lip = UiTokens.LIP_PRESSED if _pressed_visual else _rest_lip()
	_place_row()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_THEME_CHANGED:
		_apply()
		return
	# Kaydırma başladı (PASS kipinde): BaseButton basışı iptal eder ama button_up yaymaz.
	if what == NOTIFICATION_SCROLL_BEGIN and _pressed_visual:
		_set_pressed_visual(false)
		UiMotion.release(self)
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and _pressed_visual:
		_set_pressed_visual(false)
