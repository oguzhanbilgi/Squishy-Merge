class_name MissionsOverlay
extends CanvasLayer
## GÖREVLER penceresi (TASK/046 → TASK/061 V3 — GAME_DESIGN §5.10) — Ana Sayfa'nın GÖREVLER girişi açar; Main'e ait
## ikincil pencere (GÜNLÜK ÖDÜLLER / Bonus Sandık ile aynı katman ve iskelet: yeni alt sekme / ekran YOK, reklam yüzeyi
## DEĞİL — Ana Sayfa'nın mevcut banner'ı aynen, pencere yuvanın üstüne oturur).
##
##   ÜST (sabit)   hedef picto + "2 / 6 GÖREV" (tamamlanan) + alınabilir ödül varsa dikkat rozeti (sayı) + ray (6/6
##                 alınmışsa altın + yıldız) + kısa not "Tamamla, ödülünü al!" (hepsi alınınca "Hepsi tamam!").
##   GÖVDE         GÜNLÜK başlığı + "Yarın yenilenir" · 3 kart; HAFTALIK başlığı + "Pazartesi yenilenir" · 3 kart
##                 (sabit ipucu, canlı sayaç YOK). Kart durumları AKTİF / ALINABİLİR (ÖDÜLÜ AL) / ALINDI (MissionCard).
##
## Pencere ödül VERMEZ: kartın ÖDÜLÜ AL'ı `claim_requested(id, period_key)` yayar, Main SaveManager'ın tek yetkili talep
## işlemini çağırır ve sonucu `apply_claim` ile geri verir (kart kanonik veriden tazelenir + kısa candy geri bildirim:
## kart pop'u, CTA'dan yükselen "+10" Hamur, ödül sesi, hafif titreşim — tam ekran kutlama YOK). Açmak / kapatmak /
## kaydırmak kayda YAZMAZ. X / karartma / Android geri (Main) → kapanır. Açılış ve kapanış Main'in 300 ms parmak
## yatışmasını başlatır (Main bağlar).

signal opened
signal closed
## ÖDÜLÜ AL (TASK/061): gösterilen dönemin anahtarıyla — doğrulama ve ödül SaveManager'da (Main).
signal claim_requested(id: StringName, period_key: String)

const TITLE: String = "GÖREVLER"
const WIDTH: float = 600.0
const COUNT_FORMAT: String = "%d / %d"
const COUNT_UNIT: String = "GÖREV"
const NOTE_TEXT: String = "Tamamla, ödülünü al!"
const COMPLETE_TEXT: String = "Hepsi tamam!"
const DAILY_TITLE: String = "GÜNLÜK"
const WEEKLY_TITLE: String = "HAFTALIK"
const DAILY_HINT: String = "Yarın yenilenir"
const WEEKLY_HINT: String = "Pazartesi yenilenir"
## Kayıt güvenliği (TASK/061): talep kalıcı kayıtta doğrulanmadıysa kutlama yerine notta kısa, gerçeği söyleyen durum.
##   KAYIT BEKLİYOR  ödül doğrulanmış kurtarma kopyasında (SaveFile PENDING): kart ALINDI doğru, kanonik ad henüz değil
##   KAYDEDİLEMEDİ   ödül diskte yok, bellek geri alındı (SAVE_FAILED): kart ALINABİLİR kalır
const SAVE_PENDING_TEXT: String = "KAYIT BEKLİYOR"
const SAVE_FAILED_TEXT: String = "KAYDEDİLEMEDİ"
const GAIN_FORMAT: String = "+%d"
## "+10" yükselişi: süre, mesafe (tuval px).
const GAIN_TIME: float = 0.85
const GAIN_RISE: float = 72.0
const STAR_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
const DOUGH_ART: Texture2D = preload("res://assets/visual/ui/icon_dough.png")

var _frame: Control
var _count: Label
var _star: TextureRect
var _attention: AttentionBadge
var _bar: ProgressBar
var _note: Label
var _cards: Array[MissionCard] = []
var _headers: Dictionary = {}
var _safe_top_override: float = -1.0
var _last_gain: Control

@onready var _center: Control = $Center
@onready var _dim: ColorRect = $Center/Dim
@onready var _anchor: CenterContainer = $Center/Anchor


func _ready() -> void:
	visible = false
	_frame = UiKit.modal_shell(TITLE, WIDTH, &"ribbon", false, true)
	_frame.name = "MissionsShell"
	_anchor.add_child(_frame)
	_build_hero(_frame.get_meta(&"hero"))
	var body: VBoxContainer = _frame.get_meta(&"body")
	body.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	for period: StringName in [Missions.PERIOD_DAILY, Missions.PERIOD_WEEKLY]:
		var daily: bool = period == Missions.PERIOD_DAILY
		var header := _section_header(DAILY_TITLE if daily else WEEKLY_TITLE, DAILY_HINT if daily else WEEKLY_HINT)
		body.add_child(header)
		_headers[period] = header
		for id in Missions.ids_for(period):
			var card := MissionCard.new()
			card.claim_pressed.connect(func(mission: StringName, period_key: String) -> void:
				claim_requested.emit(mission, period_key))
			body.add_child(card)
			_cards.append(card)
	var tail := Control.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.custom_minimum_size = Vector2(0, 4)
	body.add_child(tail)
	GestureGuard.on_pressed(_frame.get_meta(&"close_button") as Button, close_missions)
	UiKit.attach_dim_close(_dim, close_missions)
	# Ekran boyutu değişince (döndürme / pencere) pencere yeniden oturur. Tam ekran kök
	# dinlenir — `_anchor`'ın kendi payı oturtmayla değişir, onu dinlemek döngü kurardı.
	$Center.resized.connect(func() -> void:
		if visible:
			UiKit.seat_modal_below_safe_top(_anchor, _frame, _safe_top_override))
	UiKit.modal_relayout(_frame)


func _build_hero(hero: VBoxContainer) -> void:
	hero.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.name = "CountRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	hero.add_child(row)
	var goal := UiKit.icon("goal", 32, UiTokens.PINK_DEEP)
	goal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(goal)
	_count = UiKit.label(COUNT_FORMAT % [0, Missions.CATALOG.size()], &"LabelTitle")
	_count.name = "Count"
	_count.add_theme_font_size_override("font_size", 32)
	row.add_child(_count)
	var unit := UiKit.label(COUNT_UNIT, &"LabelBadge")
	unit.add_theme_font_size_override("font_size", 16)
	unit.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	unit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(unit)
	_star = UiKit.art(STAR_ART, 28)
	_star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_star.visible = false
	row.add_child(_star)
	# Alınabilir ödül sayısı (V3 dikkat rozeti — Ana Sayfa GÖREVLER madalyonuyla aynı dil).
	_attention = AttentionBadge.new()
	_attention.name = "ClaimableBadge"
	_attention.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_attention)
	_bar = UiKit.progress_bar(0.0, &"ProgressBarMint", 14.0)
	_bar.name = "CountRail"
	hero.add_child(_bar)
	_note = UiKit.label(NOTE_TEXT, &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
	_note.name = "Note"
	_note.add_theme_font_size_override("font_size", 15)
	_note.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero.add_child(_note)


## Bölüm başlığı: erik "GÜNLÜK" + ince lavanta çizgi + takvim picto + sabit yenilenme ipucu.
func _section_header(title: String, hint: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "Section_%s" % title
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	var label := UiKit.label(title, &"LabelBadge")
	label.name = "Title"
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	row.add_child(label)
	var line := UiKit.settings_divider()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	var calendar := UiKit.icon("calendar", 18, UiTokens.TEXT_SECONDARY)
	calendar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(calendar)
	# İkincil erik (kremde okunur kontrast; üçüncül ton 14 px'te soluk kalıyordu).
	var hint_label := UiKit.label(hint, &"LabelCaption")
	hint_label.name = "Hint"
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	row.add_child(hint_label)
	row.set_meta(&"hint_label", hint_label)
	row.set_meta(&"title_label", label)
	return row


## Kayıt yalnız OKUNUR (Missions.current — kabul edilen günün dönemi).
func open_missions() -> void:
	var was_open: bool = visible
	refresh()
	visible = true
	UiKit.seat_modal_below_safe_top(_anchor, _frame, _safe_top_override)
	(_frame.get_meta(&"scroll") as ScrollContainer).scroll_vertical = 0
	if not was_open:
		UiMotion.modal_open(_frame, _dim)
		AudioManager.play(&"ui_modal_open")
		opened.emit()


func close_missions(with_sound: bool = true) -> void:
	if not visible:
		return
	visible = false
	_clear_gain()
	if with_sound:
		AudioManager.play(&"ui_modal_close")
	closed.emit()


func refresh() -> void:
	var state: Dictionary = Missions.current()
	var rows: Array[Dictionary] = Missions.rows(state)
	for i in _cards.size():
		_cards[i].setup(rows[i] if i < rows.size() else {})
	var total: int = rows.size()
	var done: int = Missions.completed_count(state)
	var claimable: int = Missions.claimable_count(state)
	var complete: bool = total > 0 and done >= total and claimable == 0
	_count.text = COUNT_FORMAT % [done, total]
	_count.add_theme_color_override("font_color", UiTokens.GOLD_DEEP if complete else UiTokens.TEXT_PRIMARY)
	_bar.value = float(done) / float(maxi(total, 1))
	_bar.theme_type_variation = &"ProgressBarGold" if complete else &"ProgressBarMint"
	_star.visible = complete
	_attention.show_count(claimable)
	_note.text = COMPLETE_TEXT if complete else NOTE_TEXT
	_note.add_theme_color_override("font_color", UiTokens.GOLD_DEEP if complete else UiTokens.TEXT_SECONDARY)


## Main'in talep sonucu (SaveManager.claim_mission_reward): kartlar kanonik veriden tazelenir; bu çağrı Hamur verdiyse
## (ÖDÜLÜ AL, ya da pencere gece yarısını açık geçtiyse kapanan dönemin teslimi — dokunulan ödül dahil) kısa candy geri
## bildirimi ve "+N" = bu çağrının verdiği TOPLAM Hamur (bakiyedeki artışın aynısı). Hiç Hamur verilmediyse yalnız tazeleme
## + `ui_invalid`. Kutlama YALNIZ ödül kanonik kayıtta doğrulanınca: SAVE_FAILED → "KAYDEDİLEMEDİ" + `ui_invalid`;
## kayıt bekliyor (PENDING) → kart ALINDI (doğru) + "KAYIT BEKLİYOR", pop / "+N" / ses / titreşim yok.
func apply_claim(id: StringName, outcome: Dictionary) -> void:
	var source: MissionCard = card(id)
	var origin: Rect2 = source.claim_button().get_global_rect() if source != null else Rect2()
	refresh()
	if int(outcome.get("result", -1)) == Missions.Claim.SAVE_FAILED:
		_show_save_status(SAVE_FAILED_TEXT)
		AudioManager.play(&"ui_invalid")
		return
	var granted: int = int(outcome.get("dough", 0))
	if granted <= 0:
		AudioManager.play(&"ui_invalid")
		return
	if int(outcome.get("persist", SaveFile.Outcome.SAVED)) == SaveFile.Outcome.PENDING:
		_show_save_status(SAVE_PENDING_TEXT)
		return
	if source != null:
		source.play_claimed()
	_show_gain(granted, origin)
	AudioManager.play(&"daily_reward")
	Haptics.light()


## Kayıt durumu notu (bir sonraki `refresh` normal nota döner).
func _show_save_status(text: String) -> void:
	_note.text = text
	_note.add_theme_color_override("font_color", UiTokens.TEXT_WARNING_STRONG)


## CTA'nın üstünden yükselip solan "+10" + Hamur sanatı (yalnız görsel; dokunma almaz, kendini siler).
func _show_gain(amount: int, origin: Rect2) -> void:
	_clear_gain()
	if amount <= 0 or origin.size == Vector2.ZERO:
		return
	var gain := HBoxContainer.new()
	gain.name = "ClaimGain"
	gain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gain.add_theme_constant_override("separation", 4)
	var coin := UiKit.art(DOUGH_ART, 34.0)
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	gain.add_child(coin)
	var label := UiKit.label(GAIN_FORMAT % amount, &"LabelPrice")
	label.name = "GainLabel"
	label.add_theme_font_size_override("font_size", 30)
	gain.add_child(label)
	_center.add_child(gain)
	gain.size = gain.get_combined_minimum_size()
	var local: Vector2 = origin.get_center() - _center.get_global_rect().position
	gain.position = local - Vector2(gain.size.x * 0.5, gain.size.y + 6.0)
	_last_gain = gain
	var tween: Tween = gain.create_tween().set_parallel(true)
	tween.tween_property(gain, "position:y", gain.position.y - GAIN_RISE, GAIN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(gain, "modulate:a", 0.0, GAIN_TIME * 0.45).set_delay(GAIN_TIME * 0.55)
	tween.chain().tween_callback(gain.queue_free)


func _clear_gain() -> void:
	if _last_gain != null and is_instance_valid(_last_gain):
		_last_gain.queue_free()
	_last_gain = null


## Android geri (Main): açıksa kapanır → true.
func handle_back() -> bool:
	if not visible:
		return false
	close_missions()
	return true


# --- Testler / çekim aracı ----------------------------------------------------

## Cihaz güvenli alanı yerine sabit üst pay (tuval px).
func layout_with_safe_top(safe_top: float) -> void:
	_safe_top_override = safe_top
	if visible:
		UiKit.seat_modal_below_safe_top(_anchor, _frame, _safe_top_override)


func frame() -> Control:
	return _frame


func dim() -> ColorRect:
	return _dim


func cards() -> Array[MissionCard]:
	return _cards


func card(id: StringName) -> MissionCard:
	for c in _cards:
		if c.mission_id() == id:
			return c
	return null


func count_text() -> String:
	return _count.text


func note_text() -> String:
	return _note.text


## Başlıktaki alınabilir ödül rozeti (0 → gizli).
func claimable_badge() -> AttentionBadge:
	return _attention


## Son talebin "+N" yükselişi (yoksa / bittiyse null).
func gain_feedback() -> Control:
	return _last_gain if _last_gain != null and is_instance_valid(_last_gain) else null


func section_header(period: StringName) -> Control:
	return _headers.get(period, null)


func close_button() -> Button:
	return _frame.get_meta(&"close_button")


func scroll() -> ScrollContainer:
	return _frame.get_meta(&"scroll")
