extends CanvasLayer
## Günlük giriş ödülü penceresi (GAME_DESIGN.md §5.4) — production yeniden
## kurulum (M8.6-08). SADECE GÖSTERGE: ödül `DailyReward.claim_if_new_day`
## ile (Main'in açılış / madalyon yolu) kayda ZATEN işlenmiş olarak buraya
## gelir; bu pencere kayda dokunmaz, ödül VERMEZ, ikinci kez VERMEZ.
##
## İki durum (Main çağırır):
##   show_reward(result)  bugünkü ödül şimdi alındı — "+15 HAMUR", N. GÜN,
##                        seri şeridi (bugün altın halka), AL kahraman CTA'sı;
##                        AL = kutlama (bugünkü düğüm yıldız + pop + kısa
##                        pırıltı) → pencere kapanır → Ana Sayfa yenilenir
##                        (Hamur pill'i kanonik `closed` yolundan güncellenir)
##   show_status(streak)  bugünkü ödül daha önce alınmış — "Bugünkü ödülünü
##                        aldın", seri şeridi (bugün altın + yıldız), TAMAM
##
## Kapanış yolları aynı: AL/TAMAM, X, karartma dokunuşu (M8.6-08'de eklendi —
## diğer Ana Sayfa pencereleriyle aynı), Android geri (main.gd
## `close_popup`). `show_reward` / `show_status` / `close_popup` imzaları
## DEĞİŞMEDİ (Main, home_shots, home_ui_test).
##
## Görsel: `UiKit.modal_shell` (tepelik + GÜNLÜK ÖDÜL başlığı + oturmuş X),
## owner Hamur sanatı pembe candy kuyuda + altın pırıltılar, `StreakStrip`.
## Sürekli işlem yok: yalnız kuyu sanatının yavaş süzülmesi (tween), kapanınca
## durur.

signal closed

const DOUGH_ART: Texture2D = preload("res://assets/visual/ui/icon_dough.png")
const STAR_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
const MODAL_WIDTH: float = 560.0
## Kuyu Mağaza onayının ürün sunumuyla aynı ölçekte (164 / 118).
const WELL_SIZE: float = 164.0
const WELL_ART: float = 118.0
const WELL_HOST_HEIGHT: float = 188.0
## Kuyunun etrafındaki sabit altın pırıltılar: (kuyu merkezine göre px, kutu).
const SPARKLES: Array = [
	[Vector2(-112, -48), 22.0],
	[Vector2(104, -62), 18.0],
	[Vector2(120, 32), 14.0],
	[Vector2(-124, 44), 16.0],
]
## Kutlama: AL'a basılınca patlayan yıldız sayısı / süre / mesafe; pencere
## bundan kısa bir süre sonra kapanır. Geri tuşu beklemez (close_popup).
const BURST_STARS: int = 8
const BURST_TIME: float = 0.42
const BURST_RADIUS: float = 96.0
const CLAIM_CLOSE_DELAY: float = 0.48
const FLOAT_AMPLITUDE: float = 4.0
const FLOAT_TIME: float = 1.6

var _frame: Control
var _well_host: Control
var _well: Control
var _reward: Label
var _day_badge: PanelContainer
var _day_label: Label
var _strip: StreakStrip
var _note: Label
## Kahraman CTA (ödül durumu, "AL") ve durum butonu ("TAMAM"). Testler
## `cta_text()` ile okur.
var _claim: Button
var _ok: Button
var _close: Button
var _closing: bool = false
var _float_tween: Tween = null

@onready var _dim: ColorRect = $Center/Dim
@onready var _anchor: CenterContainer = $Center/Anchor


func _ready() -> void:
	visible = false
	_frame = UiKit.modal_shell("GÜNLÜK ÖDÜL", MODAL_WIDTH, &"heading", true, true)
	_anchor.add_child(_frame)
	var body: VBoxContainer = _frame.get_meta(&"body")
	body.add_theme_constant_override("separation", UiTokens.SPACE_SM)

	# Ödül sunumu: pembe candy kuyu (Ana Sayfa Günlük madalyonuyla aynı
	# aile) içinde owner Hamur sanatı, etrafında altın pırıltılar.
	_well_host = Control.new()
	_well_host.name = "RewardHost"
	_well_host.custom_minimum_size = Vector2(0, WELL_HOST_HEIGHT)
	_well_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_well_host)
	_well = UiKit.candy_well(DOUGH_ART, UiTokens.PINK, WELL_SIZE, WELL_ART)
	_well.name = "Well"
	_well.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_well.offset_left = -WELL_SIZE * 0.5
	_well.offset_right = WELL_SIZE * 0.5
	_well.offset_top = -(WELL_SIZE + 6.0) * 0.5
	_well.offset_bottom = (WELL_SIZE + 6.0) * 0.5
	_well_host.add_child(_well)
	var well_art: Control = _well.get_meta(&"art")
	well_art.set_meta(&"float_home_top", well_art.offset_top)
	well_art.set_meta(&"float_home_bottom", well_art.offset_bottom)
	for spec in SPARKLES:
		var spark := UiKit.art(STAR_ART, float(spec[1]))
		spark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		spark.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		var half: float = float(spec[1]) * 0.5
		var at: Vector2 = spec[0]
		spark.offset_left = at.x - half
		spark.offset_right = at.x + half
		spark.offset_top = at.y - half
		spark.offset_bottom = at.y + half
		_well_host.add_child(spark)

	_reward = UiKit.label("", &"LabelPrice", HORIZONTAL_ALIGNMENT_CENTER)
	_reward.name = "Reward"
	body.add_child(_reward)

	# "4. GÜN" altın rozet (level/stok rozetiyle aynı aile), ortalı.
	_day_badge = UiKit.badge("1. GÜN")
	_day_badge.name = "DayBadge"
	_day_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_day_label = _day_badge.get_child(0).get_child(0)
	_day_label.add_theme_font_size_override("font_size", 18)
	body.add_child(_day_badge)

	_strip = StreakStrip.new()
	_strip.name = "Streak"
	_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_strip)
	var strip_gap := Control.new()
	strip_gap.custom_minimum_size = Vector2(0, UiTokens.SPACE_XS)
	strip_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(strip_gap)

	# Not: seri kırıldıysa sebebi (uyarı), alınmış durumda "yarın tekrar gel".
	_note = UiKit.label("", &"LabelWarning", HORIZONTAL_ALIGNMENT_CENTER)
	_note.name = "Note"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.visible = false
	body.add_child(_note)

	var footer: VBoxContainer = _frame.get_meta(&"footer")
	_claim = UiKit.cta("AL", "", &"ButtonCTA")
	_claim.name = "Claim"
	_claim.pressed.connect(_on_claim_pressed)
	footer.add_child(_claim)
	_ok = UiKit.button("TAMAM", &"ButtonPrimary")
	_ok.name = "Ok"
	_ok.pressed.connect(close_popup)
	_ok.visible = false
	footer.add_child(_ok)

	_close = _frame.get_meta(&"close_button")
	_close.pressed.connect(close_popup)
	UiKit.attach_dim_close(_dim, close_popup)
	UiKit.modal_relayout(_frame)


## Kapat: AL/TAMAM, X, karartma ve Android geri tuşu (main.gd) aynı yol.
func close_popup() -> void:
	if not visible:
		return
	visible = false
	_closing = false
	_stop_float()
	AudioManager.play(&"ui_modal_close")
	closed.emit()


func show_reward(result: Dictionary) -> void:
	var streak: int = result["streak"]
	_reward.text = "+%d HAMUR" % int(result["reward"])
	_reward.theme_type_variation = &"LabelPrice"
	_reward.add_theme_font_size_override("font_size", 38)
	_set_day(streak)
	_strip.set_streak(streak, false)
	# Seri kırıldıysa oyuncuya sebebini söyle, sessizce sıfırlama.
	_set_note("Serin kırılmıştı, sayaç sıfırlandı." if result["streak_broken"] else "", true)
	_claim.visible = true
	_ok.visible = false
	_open()
	# Neşeli ödül cue'su pencerenin açılış sesi yerine geçiyor.
	AudioManager.play(&"daily_reward")


## Bugünkü ödül zaten alınmışsa (Ana Sayfa'daki Günlük madalyonundan
## açılınca, M8.6-03B): aynı pencere, ödül satırı "alındı" der, bugünkü
## düğüm yıldızlı. Kayda dokunmaz, ödül VERMEZ — yalnızca durum.
func show_status(streak: int) -> void:
	_reward.text = "Bugünkü ödülünü aldın"
	_reward.theme_type_variation = &"LabelPositive"
	_reward.add_theme_font_size_override("font_size", 24)
	_set_day(streak)
	_strip.set_streak(streak, true)
	_set_note("Yarın tekrar gel, seri devam etsin.", false)
	_claim.visible = false
	_ok.visible = true
	_open()
	AudioManager.play(&"ui_modal_open")


func _open() -> void:
	_closing = false
	visible = true
	UiKit.modal_relayout(_frame)
	UiMotion.modal_open(_frame, _dim)
	_start_float()


func _set_day(streak: int) -> void:
	_day_label.text = "%d. GÜN" % maxi(streak, 1)


func _set_note(text: String, warning: bool) -> void:
	_note.text = text
	_note.visible = text != ""
	_note.theme_type_variation = &"LabelWarning" if warning else &"LabelCaption"


## AL: kutlama — bugünkü düğüm yıldız + kuyu pop + yıldız patlaması — sonra
## pencere kapanır. KAYDA DOKUNMAZ: ödül zaten claim yolunda yazıldı; burada
## ikinci bir `add_dough` / `record_daily_login` YOK. İkinci basış yok sayılır.
func _on_claim_pressed() -> void:
	if _closing or not visible:
		return
	_closing = true
	_strip.mark_today()
	UiMotion.pop(_well, 1.12)
	_burst()
	# Gecikme düğüme bağlı tween ile: pencere serbest bırakılırsa geri çağrı
	# hiç gelmez (SceneTreeTimer coroutine'i serbest nesneye dönebilirdi).
	var delay: Tween = create_tween()
	delay.tween_interval(CLAIM_CLOSE_DELAY)
	delay.tween_callback(_finish_claim)


func _finish_claim() -> void:
	if _closing and visible:
		close_popup()


## Kısa yıldız patlaması (deterministik açılar; parçacık düğümü yok, dinlenme
## halinde hiçbir şey çalışmaz). Yıldızlar çerçeveye eklenir (gövde kaydırma
## kırpmasının dışında) ve bitince silinir.
func _burst() -> void:
	var center: Vector2 = _well.global_position - _frame.global_position + _well.size * 0.5
	for i in BURST_STARS:
		var angle: float = TAU * float(i) / float(BURST_STARS) - PI * 0.5 + 0.18
		var box: float = 22.0 if i % 2 == 0 else 15.0
		var star := UiKit.art(STAR_ART, box)
		star.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		star.position = center - Vector2(box, box) * 0.5
		star.size = Vector2(box, box)
		star.pivot_offset = star.size * 0.5
		_frame.add_child(star)
		var target: Vector2 = star.position + Vector2.from_angle(angle) * BURST_RADIUS * (1.0 if i % 2 == 0 else 0.78)
		var tween: Tween = star.create_tween()
		tween.set_parallel(true)
		tween.tween_property(star, "position", target, BURST_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(star, "scale", Vector2.ONE * 0.35, BURST_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(star, "modulate:a", 0.0, BURST_TIME * 0.6).set_delay(BURST_TIME * 0.4)
		tween.chain().tween_callback(star.queue_free)


## Kuyu sanatı yavaşça süzülür (ödül ikonu "canlı"; sürekli zıplama yok).
## Ev konumu ilk çağrıda saklanır; durunca oraya döner (kayma birikmez).
func _start_float() -> void:
	_stop_float()
	var picture: Control = _well.get_meta(&"art")
	# Sanat kuyuda ANCHOR'lu: konum degil offset'ler animasyonlanir (ebeveyn
	# yeniden boyutlanınca anchor hesabı offset'lerden gider, kayma olmaz).
	var top: float = float(picture.get_meta(&"float_home_top"))
	var bottom: float = float(picture.get_meta(&"float_home_bottom"))
	_float_tween = picture.create_tween().set_loops()
	_float_tween.tween_method(func(dy: float) -> void:
		picture.offset_top = top + dy
		picture.offset_bottom = bottom + dy, 0.0, -FLOAT_AMPLITUDE, FLOAT_TIME * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_method(func(dy: float) -> void:
		picture.offset_top = top + dy
		picture.offset_bottom = bottom + dy, -FLOAT_AMPLITUDE, 0.0, FLOAT_TIME * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_float() -> void:
	if _float_tween != null and _float_tween.is_valid():
		_float_tween.kill()
	_float_tween = null
	var picture: Control = _well.get_meta(&"art")
	picture.offset_top = float(picture.get_meta(&"float_home_top"))
	picture.offset_bottom = float(picture.get_meta(&"float_home_bottom"))


# --- Testler / araçlar -------------------------------------------------------

func frame() -> Control:
	return _frame


func strip() -> StreakStrip:
	return _strip


## Görünen birincil butonun yazısı ("AL" / "TAMAM").
func cta_text() -> String:
	if _claim.visible:
		return (_claim.get_meta(&"title_label") as Label).text
	return _ok.text


func cta_button() -> Button:
	return _claim if _claim.visible else _ok


func is_claim_pending() -> bool:
	return _closing
