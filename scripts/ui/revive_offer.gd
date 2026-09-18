extends CanvasLayer
## Devam etme (revive) teklifi penceresi — GAME_DESIGN.md §11, production
## yeniden kurulum (M8.6-10). Eski M8.5-08 candy panel + mavi yıldızlı
## candy pill CTA'ları (birincil ile "Bitir" aynı buton) kalktı.
##
## ⚠️ BU PENCERE REKLAM OYNATMAZ ve DEVAM HAKKI VERMEZ. "DEVAM ET"e basmak
## yalnızca `rewarded_revive_requested` sinyalini yayar; devam hakkını YALNIZCA
## sağlayıcının "ödül kazanıldı" callback'i (`Main.grant_revive` →
## `GameBoard.grant_revive`) verir. Sayaç board'un `revives_remaining()`'i,
## burada ayrı bir kopya tutulmaz/mutasyona uğramaz. Sahte reklam, sahte
## geri sayım ve otomatik bedava devam YOKTUR.
##
## Acil ikinci şans anı, ama Kazanma sonucundan daha güçlü DEĞİL:
##   tepelik (owner kanatlı kalp) + "DEVAM ETMEK İSTER MİSİN?" başlığı
##   açıklama satırı
##   DEVAM HAKKI plakası: iki kalp (owner tepeliğinden türetilen
##     `icon_heart_revive`; kalan = renkli, kullanılmış = soluk lavanta) +
##     "2 / 2" — sahte üçüncü yuva yok, board ne derse o
##   DEVAM ET kahraman CTA (cyan, film pictosu, "Reklam izle" alt satırı)
##   durum notu (sağlayıcı yok / reklam isteniyor / hak bitti / sağlayıcı
##     mesajı)
##   BİTİR ikincil (lavanta) — devam varken hiyerarşide alt, ama hep erişilir
##
## Sağlayıcı bağlı değilse (bugünkü production) DEVAM ET PASİF ve sebebi
## yazılı: reklamın çalışacağını iddia eden aktif bir buton gösterilmez.
## Talep gönderilince buton cevap gelene kadar kilitli (çift dokunuş / çift
## talep yok); sağlayıcı "olmadı" derse buton yalnız sağlayıcı bağlıysa
## yeniden açılır (tekrar dene), teklif açık kalır, hak tüketilmez.
##
## X yok, karartma dokunuşu kapatmaz, Android geri yok sayılır (Main): karar
## penceresi — çıkış yalnız iki CTA'dan. Kayıt/ekonomi yazımı YOK.
##
## Sözleşme (Main / revive_test / result_ui_test / secondary_ui_shots):
## `show_offer(remaining, max_revives, provider_ready)`, `hide_offer()`,
## `show_unavailable(message)`, `rewarded_revive_requested`, `decline_pressed`.

## Oyuncu ödüllü reklam CTA'sına bastı. Bu bir TALEP'tir, devam hakkı DEĞİL.
signal rewarded_revive_requested
## Oyuncu "Bitir" dedi: round kesin bitsin. Devam hakkı tüketilmez.
signal decline_pressed

const HEART_ART: Texture2D = preload("res://assets/visual/ui/icon_heart_revive.png")
const MODAL_WIDTH: float = 560.0
const HEART_SIZE: float = 84.0
const HEART_GAP: int = 18
## Plakanın arkasındaki yumuşak pembe hale (kalpler pencerenin odağı).
const COUNTER_HALO: Color = Color(UiTokens.PINK, 0.16)
## Kullanılmış hak: aynı kalp, soluk lavanta-gri (renk değil "boş yuva" okunur).
const HEART_USED_TINT: Color = Color(0.62, 0.58, 0.72, 0.42)
const HEART_POP: float = 1.14
## Kopyalar (oyuncu dili Türkçe; kanonik metinler korunur).
const TITLE: String = "DEVAM ETMEK İSTER MİSİN?"
const DETAIL: String = "Taşan parçaları temizle, kaldığın yerden devam et."
const COUNTER_CAPTION: String = "DEVAM HAKKI"
const PRIMARY: String = "DEVAM ET"
const PRIMARY_SUB: String = "Reklam izle"
const SECONDARY: String = "BİTİR"
const NOTE_REQUESTING: String = "Reklam isteniyor…"
const NOTE_NO_PROVIDER: String = "Ödüllü reklam henüz bağlı değil."
const NOTE_EXHAUSTED: String = "Bu turdaki devam hakkın bitti."

var _frame: Control
var _heading: Label
var _detail: Label
var _counter: PanelContainer
var _hearts_row: HBoxContainer
var _hearts: Array[TextureRect] = []
var _remaining: Label
var _continue: Button
var _note: Label
var _decline: Button
var _remaining_count: int = 0
var _max_revives: int = 0
var _provider_ready: bool = false
var _request_pending: bool = false
var _message: String = ""

@onready var _dim: ColorRect = $Center/Dim
@onready var _anchor: CenterContainer = $Center/Anchor


func _ready() -> void:
	visible = false
	# Karartma: dokunuş arkadaki board'a sızmaz, ama KAPATMAZ (karar penceresi).
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame = UiKit.modal_shell(TITLE, MODAL_WIDTH, &"heading", true, false)
	_frame.name = "ReviveShell"
	_anchor.add_child(_frame)
	_heading = _frame.get_meta(&"heading")
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_heading.add_theme_font_size_override("font_size", 30)

	var hero: VBoxContainer = _frame.get_meta(&"hero")
	hero.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	_detail = UiKit.label(DETAIL, &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	_detail.name = "Detail"
	_detail.add_theme_font_size_override("font_size", 19)
	_detail.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero.add_child(_detail)
	var counter_host := CenterContainer.new()
	counter_host.name = "CounterHost"
	counter_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(counter_host)
	_counter = _build_counter()
	counter_host.add_child(_counter)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, UiTokens.SPACE_XS)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(gap)

	var footer: VBoxContainer = _frame.get_meta(&"footer")
	footer.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_continue = UiKit.cta(PRIMARY, PRIMARY_SUB, &"ButtonCTA", "movie")
	_continue.name = "Continue"
	_continue.pressed.connect(_on_continue_pressed)
	footer.add_child(_continue)
	_note = UiKit.label("", &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
	_note.name = "Note"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.visible = false
	footer.add_child(_note)
	_decline = UiKit.button(SECONDARY, &"ButtonSecondary")
	_decline.name = "Decline"
	_decline.pressed.connect(func() -> void: decline_pressed.emit())
	footer.add_child(_decline)
	UiKit.modal_relayout(_frame)


## DEVAM HAKKI plakası: bir ton geri krem plaka + ince lavanta kontur (Round
## sonu özet çipiyle aynı aile), içinde başlık / kalp sırası / "2 / 2".
func _build_counter() -> PanelContainer:
	var plate := PanelContainer.new()
	plate.name = "Counter"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel",
		UiKit.style("label_round", UiTokens.CREAM_DEEP, Vector4(34, 12, 34, 14)))
	var halo := UiKit.patch("popup_glow", COUNTER_HALO)
	halo.show_behind_parent = true
	UiKit.inset(halo, -36.0, -30.0, -36.0, -34.0)
	plate.add_child(halo)
	var outline := UiKit.flat_plate("label_round", Color(UiTokens.LAVENDER_SURFACE, 0.9))
	outline.show_behind_parent = true
	UiKit.inset(outline, -2.0, -2.0, -2.0, -2.0)
	plate.add_child(outline)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(column)
	var caption := UiKit.label(COUNTER_CAPTION, &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
	caption.name = "Caption"
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", UiTokens.TEXT_TERTIARY)
	column.add_child(caption)
	_hearts_row = HBoxContainer.new()
	_hearts_row.name = "Hearts"
	_hearts_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hearts_row.add_theme_constant_override("separation", HEART_GAP)
	_hearts_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_hearts_row)
	_remaining = UiKit.label("", &"LabelStat", HORIZONTAL_ALIGNMENT_CENTER)
	_remaining.name = "Remaining"
	_remaining.add_theme_font_size_override("font_size", 22)
	column.add_child(_remaining)
	return plate


## Kalp sırası board'un verdiği tavana göre kurulur (2); fazladan yuva icat
## edilmez, eksik de gösterilmez.
func _ensure_hearts(count: int) -> void:
	if _hearts.size() == count:
		return
	for heart in _hearts:
		heart.queue_free()
	_hearts.clear()
	for i in count:
		var heart := UiKit.art(HEART_ART, HEART_SIZE)
		heart.name = "Heart%d" % (i + 1)
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		heart.pivot_offset = Vector2(HEART_SIZE, HEART_SIZE) * 0.5
		_hearts_row.add_child(heart)
		_hearts.append(heart)


# --- Sözleşme ------------------------------------------------------------------

## `remaining`: bu round'da KALAN devam hakkı (board söyler). `provider_ready`:
## ödüllü sağlayıcı bağlı mı (Main söyler) — değilse DEVAM ET pasif ve sebebi
## yazılı; teklif yine açık, BİTİR erişilir.
func show_offer(remaining: int, max_revives: int, provider_ready: bool) -> void:
	_remaining_count = maxi(0, remaining)
	_max_revives = maxi(0, max_revives)
	_provider_ready = provider_ready
	_request_pending = false
	_message = ""
	_ensure_hearts(_max_revives)
	_refresh()
	visible = true
	UiKit.modal_relayout(_frame)
	UiMotion.modal_open(_frame, _dim)
	# Kalan kalpler kısa bir nabız: "hâlâ hakkın var" (kullanılmış olan durur).
	for i in _hearts.size():
		if i < _remaining_count:
			UiMotion.pop(_hearts[i], HEART_POP)


func hide_offer() -> void:
	visible = false
	_request_pending = false
	_message = ""


## Sağlayıcı talebi reddetti / reklam hazır değil / ödül kazanılmadı. Teklif
## AÇIK KALIR, devam hakkı tüketilmez. Sağlayıcı bağlıysa oyuncu tekrar
## deneyebilir (buton açılır); bağlı değilse buton pasif kalır — "tekrar
## dene" diyen ama çalışmayacak bir buton gösterilmez.
func show_unavailable(message: String) -> void:
	_request_pending = false
	_message = message
	_refresh()


func _on_continue_pressed() -> void:
	# Çift dokunuş / çift talep koruması: cevap gelene kadar ikinci talep
	# gitmez; sağlayıcı yokken ve hak bitmişken talep hiç üretilmez.
	if not _can_request():
		return
	_request_pending = true
	_message = ""
	_refresh()
	rewarded_revive_requested.emit()


func _can_request() -> bool:
	return _remaining_count > 0 and _provider_ready and not _request_pending


## Kalpler, sayaç, CTA durumu ve not — tek yerden.
func _refresh() -> void:
	for i in _hearts.size():
		var available: bool = i < _remaining_count
		_hearts[i].self_modulate = Color.WHITE if available else HEART_USED_TINT
	_remaining.text = "%d / %d" % [_remaining_count, _max_revives]
	UiKit.set_cta_enabled(_continue, _can_request())
	var text: String = ""
	var warning: bool = false
	if _request_pending:
		text = NOTE_REQUESTING
	elif _remaining_count <= 0:
		text = NOTE_EXHAUSTED
		warning = true
	elif _message != "":
		text = _message
		warning = true
	elif not _provider_ready:
		text = NOTE_NO_PROVIDER
		warning = true
	_note.text = text
	_note.visible = text != ""
	_note.theme_type_variation = &"LabelWarning" if warning else &"LabelCaption"
	_note.add_theme_color_override("font_color",
		UiTokens.TEXT_WARNING if warning else UiTokens.TEXT_SECONDARY)


# --- Testler / araçlar ----------------------------------------------------------

func frame() -> Control:
	return _frame


func dim() -> ColorRect:
	return _dim


func hearts() -> Array[TextureRect]:
	return _hearts


## Renkli (kalan) kalp sayısı.
func hearts_available() -> int:
	var count: int = 0
	for heart in _hearts:
		if heart.self_modulate == Color.WHITE:
			count += 1
	return count


func remaining_text() -> String:
	return _remaining.text


func note_text() -> String:
	return _note.text if _note.visible else ""


func continue_button() -> Button:
	return _continue


func decline_button() -> Button:
	return _decline


func is_request_pending() -> bool:
	return _request_pending


func provider_ready() -> bool:
	return _provider_ready
