class_name GestureGuard
extends Node
## TASK/055 — GUI düğmesinin işaretçi dokunuşu sahipliği (TASK/054 Koleksiyon modelinin paylaşılan, açık API'li biçimi).
##
## Godot 4.6.3 BaseButton (Faz A sondasıyla doğrulandı): Android ACTION_CANCEL bırakışını tıklama sayar (`canceled`a
## bakmaz); basılı bir düğme gizlenince ya da pencere odağı gidince Viewport ona iç aygıtlı bir bırakış yollar — son girdi
## işlenmemişse (cihazda GERİ tuşunun kendi olayı, bir ses tuşu) bu da tıklama olur, işlenmişse basış asılı kalır.
## Sahiplenilen düğmede bu bileşen:
##   (1) iptal edilen sol bırakışta basışı `gui_input` SİNYALİNDE bitirir — motor sinyali BaseButton'ın kendi işleyişinden
##       ÖNCE yayar → BaseButton aynı bırakışı basışsız görür: `pressed` / `toggled` hiç doğmaz; olay yine üst kontrollere
##       (kaydırma) yayılır, `accept_event` yok;
##   (2) basış sürerken yüzey geçersizleşirse basışı genel API'yle bitirir (`disabled` true → false: basış durumu sıfırlanır,
##       eylem yok): düğme gizlenince (`visibility_changed` CanvasItem bildiriminde, Control'ün gizleme işinden — iç
##       bırakıştan — ÖNCE yayılır), pencere odağı gidince ve Android GERİ isteğinde (gizlemeyen GERİ yolları: oyunda mola);
##   (3) eylemi yalnız `allows` doğruysa çalıştırır: düğme ekranda VE (işaretçi basışı yok — klavye / erişilebilirlik /
##       kısayol / kodla `pressed` — YA DA basışın gerçek, iptal edilmemiş bırakışı görüldü). İç aygıtlı bırakış `gui_input`
##       yaymaz → odak kaybındaki bayat tıklama (kök Viewport odağı bu bileşenin bildiriminden önce düşürür) eylemsiz kalır.
## Global girdi yutma, zaman aşımı, Input değişikliği yok; yalnız açıkça sahiplenilen düğmeler. Önkoşullar: düğme bırakışta
## eylem kipinde ve yalnız sol düğme maskeli (uygulamanın tüm düğmeleri); Android uzun basış = sağ tık ve pan / ölçek
## jestleri KAPALI kalmalı (açılırsa motor bu jestlerde ACTION_CANCEL üretir). `own` + `allows` kullanan röle (ör. paylaşılan
## ScreenTopBar'ın tüketicileri) `allows`'u `pressed` yayımı İÇİNDE okumalı (CONNECT_DEFERRED değil). Motor sınırı: Android
## 13+'ta birden çok parmaklı bir jestte tek işaretçinin iptali (POINTER_UP + FLAG_CANCELED — ör. avuç / kavrama reddi)
## Godot'ya düz bırakış olarak gelir; o işaretçi fare öykünen ilk parmaksa ayırt edilemez. Tek parmak ACTION_CANCEL'ı
## (kenar geri kaydırması, sistem jesti) her zaman `canceled` taşır.
## API:
##   GestureGuard.on_pressed(button, action)  sahiplen + `action`ı yalnız geçerli etkinleştirmede çalıştır
##   GestureGuard.own(button)                  yalnız sahiplen (eylemi çağıran `GestureGuard.allows` ile denetler)
##   GestureGuard.allows(button) -> bool       bu `pressed` / `toggled` eylem üretebilir mi
##   GestureGuard.invalidate(button)           yüzey geçersizleşti: basılı işaretçi basışını şimdi eylemsiz bitir

const META: StringName = &"gesture_guard"

var _button: BaseButton
## Basılı tutulan bir İŞARETÇİ basışı var (button_down'u sol fare / öykünülen dokunuş basışı tetikledi).
var _held: bool = false
## Bu basışın gerçek, iptal edilmemiş sol bırakışı görüldü.
var _released: bool = false
## O an işlenen olay sol işaretçi basışı mı (`gui_input` sinyali BaseButton'dan önce gelir; button_down aynı olayda yayılır).
var _pointer_press: bool = false


## `button`ı sahiplenir (zaten sahipliyse aynı bileşeni döndürür).
static func own(button: BaseButton) -> GestureGuard:
	var existing: Variant = button.get_meta(META) if button.has_meta(META) else null
	if is_instance_valid(existing) and (existing as GestureGuard)._button == button:
		return existing as GestureGuard
	var guard := GestureGuard.new()
	guard.name = "GestureGuard"
	guard._button = button
	button.set_meta(META, guard)
	button.add_child(guard, false, Node.INTERNAL_MODE_BACK)
	button.gui_input.connect(guard._on_gui_input)
	button.button_down.connect(guard._on_button_down)
	button.button_up.connect(guard._on_button_up)
	button.visibility_changed.connect(guard._on_visibility_changed)
	return guard


## Sahiplenir ve `action`ı `pressed`'e bağlar: yalnız `allows` doğruysa çalışır.
static func on_pressed(button: BaseButton, action: Callable) -> GestureGuard:
	var guard: GestureGuard = own(button)
	button.pressed.connect(guard._run.bind(action))
	return guard


## Bu düğmenin şu anki `pressed` / `toggled`'ı eylem üretebilir mi (sahipsiz düğme: yalnız görünürlük).
static func allows(button: BaseButton) -> bool:
	var guard: GestureGuard = _guard_of(button)
	return guard.allows_activation() if guard != null else button.is_visible_in_tree()


## Açık geçersizleştirme: basılı işaretçi basışı eylemsiz biter.
static func invalidate(button: BaseButton) -> void:
	var guard: GestureGuard = _guard_of(button)
	if guard != null:
		guard.end_press()


## Düğmenin GEÇERLİ sahibi (meta başka bir düğmeye ait / serbest bırakılmış bir bileşeni gösteriyorsa null).
static func _guard_of(button: BaseButton) -> GestureGuard:
	var guard: Variant = button.get_meta(META) if button.has_meta(META) else null
	if is_instance_valid(guard) and (guard as GestureGuard)._button == button:
		return guard as GestureGuard
	return null


func allows_activation() -> bool:
	return _button.is_visible_in_tree() and (not _held or _released)


## Basılı işaretçi basışını eylemsiz bitirir; sahiplik her durumda temizlenir (devre dışı düğmede motor basışı zaten
## sıfırlamıştır — yalnız `disabled` turu atlanır).
func end_press() -> void:
	_released = false
	if not _held:
		return
	_held = false
	if _button.disabled:
		return
	_button.disabled = true
	_button.disabled = false


func _run(action: Callable) -> void:
	if allows_activation():
		action.call()


func _on_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	_pointer_press = click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if click.pressed:
		_released = false
	elif click.canceled:
		end_press()
	else:
		_released = true


func _on_button_down() -> void:
	_held = _pointer_press
	_pointer_press = false


func _on_button_up() -> void:
	_held = false


func _on_visibility_changed() -> void:
	if _held and not _button.is_visible_in_tree():
		end_press()


## Pencere odağı kaybı / Android GERİ isteği: basılı işaretçi basışı eylemsiz biter. (Ağaçtan çıkan basılı düğme ayrıca
## ele alınmaz: motor (4.6.3) o anda button_up yayar → `_on_button_up` sahipliği temizler.)
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		end_press()
