extends CanvasLayer
## Stok 0 güç refill penceresi — GAME_DESIGN.md §5.7.3, production yeniden
## kurulum (M8.6-10). Eski M8.5-08 candy panel (%34 dikey gerilmiş
## `panel_candy`) + üç aynı candy pill CTA'sı kalktı.
##
## ⚠️ BU PENCERE REKLAM OYNATMAZ, STOK VERMEZ, HAMUR DÜŞMEZ, KOTA TÜKETMEZ.
## Yalnızca sunar ve buton sinyali yayar:
##   REKLAM İZLE → `rewarded_refill_requested(type)` → Main → sağlayıcı →
##                 ödül kazanıldı → `Main.grant_rewarded_power` →
##                 `RewardedPolicy.grant` (tek transaction, kota + stok)
##   SATIN AL    → `dough_refill_requested(type)` → Main →
##                 `PowerUpEconomy.purchase` (tek transaction, Hamur + stok)
##   KAPAT / X / karartma / Android geri → `closed` (hiçbir şey alınmaz, oyun
##                 kaldığı yerden sürer — Main `exit_refill_pending(false)`)
## Fiyat `PowerUpEconomy.price()` — mağazayla aynı tek kaynak, burada sayı yok.
## Kota `RewardedPolicy` — günde 1, DÖRT GÜCÜN TOPLAMI (güç başına değil).
##
## Kompozisyon (`UiKit.modal_shell`, pembe kurdele "STOK BİTTİ", oturmuş X):
##   HERO (sabit)  gücün GERÇEK sanatı büyük candy kuyuda (gücün vurgu rengi)
##                 + güç adı + "STOK ×0" rozeti — hangi güç bitti, tek bakışta
##   BODY          iki ayrı seçenek kartı (aynı iskelet, farklı kimlik):
##                 ÖDÜLLÜ REKLAM (lavanta film kuyusu, cyan REKLAM İZLE, kota
##                 satırı "Bugünkü hakkın: 1/1") · HAMURLA AL (altın Hamur
##                 kuyusu, fiyat + bakiye, nane SATIN AL)
##   FOOTER        sağlayıcı/işlem notu + KAPAT (lavanta ikincil)
## Pasif seçenek = pasif buton + kısa sebep (sessiz başarısızlık yok):
## "Ödüllü reklam henüz bağlı değil." / "Bugünkü reklam hakkın doldu, yarın
## yenilenir." / "Hamur yetersiz". Talep gönderilince reklam butonu cevap
## gelene kadar kilitli; SATIN AL bir kez sinyal yayar, Main cevaplayana
## (kapanış ya da uyarı) kadar ikinci basış yok sayılır.
##
## Gelecekteki üçüncü CTA (gerçek para Güç Paketi) için seam
## `power_pack_requested` sinyali duruyor ama HİÇBİR YERE BAĞLI DEĞİL ve
## buton gösterilmiyor (çalışmayan sahte satın alma butonu göstermek yanlış
## olurdu — billing yok).
##
## Sözleşme (Main / refill_test / secondary_ui_shots): `show_refill(type,
## provider_ready[, provider_note])`, `refresh(provider_ready[, provider_note])`,
## `show_unavailable(message, provider_ready[, provider_note])`, `hide_refill()`,
## `current_type()`; düğümler `_ad`, `_dough`, `_quota`, `_note`, `_close`.
## `provider_note` (M8.9-01): sağlayıcı hazır değilken kartta yazan gerçek sebep
## ("Reklam hazırlanıyor…" / "Reklam şu anda kullanılamıyor."); boşsa
## NOTE_NO_PROVIDER. Reklam pencere açıkken yüklenirse Main `refresh(true)` ile
## butonu açar — sahte "hazır" yok.

## Oyuncu ödüllü reklam CTA'sına bastı. Bu bir TALEP'tir, stok DEĞİL.
signal rewarded_refill_requested(type: int)
## Oyuncu Hamurla almayı seçti.
signal dough_refill_requested(type: int)
## ⚠️ KULLANILMIYOR — Google Play Billing kurulunca bağlanacak seam.
signal power_pack_requested(type: int)
signal closed

const DOUGH_ART: Texture2D = preload("res://assets/visual/ui/icon_dough.png")
const MODAL_WIDTH: float = 560.0
## Kahraman kuyu: Mağaza onayının sunumundan (190/118) biraz büyük — pencerenin
## konusu bu güç.
const HERO_WELL: float = 156.0
const HERO_ART: float = 112.0
const HERO_HOST_HEIGHT: float = 176.0
const OPTION_WELL: float = 60.0
const OPTION_ART: float = 38.0
const OPTION_BUTTON_HEIGHT: float = 58.0
## Kopyalar (oyuncu dili Türkçe; kanonik metinler korunur).
const RIBBON: String = "STOK BİTTİ"
const STOCK_BADGE: String = "STOK ×%d"
const AD_TITLE: String = "ÖDÜLLÜ REKLAM"
const AD_BUTTON: String = "REKLAM İZLE"
const DOUGH_TITLE: String = "HAMURLA AL"
const DOUGH_BUTTON: String = "SATIN AL"
const REWARD_LINE: String = "+1 %s"
const QUOTA_LINE: String = "Bugünkü hakkın: %d/%d"
const PRICE_LINE: String = "%d Hamur"
const BALANCE_LINE: String = "Bakiyen: %d"
const CLOSE_TEXT: String = "KAPAT"
const NOTE_REQUESTING: String = "Reklam isteniyor…"
const NOTE_NO_PROVIDER: String = "Ödüllü reklam henüz bağlı değil."
const NOTE_QUOTA_USED: String = "Bugünkü reklam hakkın doldu, yarın yenilenir."
const NOTE_NO_DOUGH: String = "Hamur yetersiz"
## Kart kimliği: film kuyusu koyu lavanta, Hamur kuyusu altın.
const AD_ACCENT: Color = UiTokens.LAVENDER_DEEP
const DOUGH_ACCENT: Color = UiTokens.GOLD

var _type: int = -1
var _provider_ready: bool = false
## Sağlayıcı hazır değilken reklam kartında yazan sebep (M8.9-01); boşsa
## NOTE_NO_PROVIDER.
var _provider_note: String = ""
var _request_pending: bool = false
var _purchase_sent: bool = false

var _frame: Control
var _ribbon_label: Label
var _hero_host: Control
var _well: Control
var _title: Label
var _stock_badge: PanelContainer
var _stock_label: Label
var _ad_card: PanelContainer
var _ad_sub: Label
var _quota: Label
var _ad_note: Label
var _ad: Button
var _dough_card: PanelContainer
var _dough_sub: Label
var _price: Label
var _balance: Label
var _dough_note: Label
var _dough: Button
var _note: Label
var _close_button: Button
var _close: Button

@onready var _dim: ColorRect = $Center/Dim
@onready var _anchor: CenterContainer = $Center/Anchor


func _ready() -> void:
	visible = false
	_frame = UiKit.modal_shell(RIBBON, MODAL_WIDTH, &"ribbon", false, true)
	_frame.name = "RefillShell"
	_anchor.add_child(_frame)
	_ribbon_label = (_frame.get_meta(&"ribbon") as PanelContainer).get_meta(&"title_label")
	_build_hero()
	_build_options()
	_build_footer()
	_close_button = _frame.get_meta(&"close_button")
	_close_button.pressed.connect(_on_close_pressed)
	UiKit.attach_dim_close(_dim, _on_close_pressed)
	UiKit.modal_relayout(_frame)


# --- Kurulum ---------------------------------------------------------------------

func _build_hero() -> void:
	var hero: VBoxContainer = _frame.get_meta(&"hero")
	hero.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	_hero_host = Control.new()
	_hero_host.name = "HeroHost"
	_hero_host.custom_minimum_size = Vector2(0, HERO_HOST_HEIGHT)
	_hero_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(_hero_host)
	_well = UiKit.candy_well(null, UiTokens.PINK, HERO_WELL, HERO_ART)
	_well.name = "Well"
	_well.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_well.offset_left = -HERO_WELL * 0.5
	_well.offset_right = HERO_WELL * 0.5
	_well.offset_top = -(HERO_WELL + 6.0) * 0.5
	_well.offset_bottom = (HERO_WELL + 6.0) * 0.5
	_hero_host.add_child(_well)
	_title = UiKit.label("", &"LabelTitle", HORIZONTAL_ALIGNMENT_CENTER)
	_title.name = "PowerName"
	_title.add_theme_font_size_override("font_size", 28)
	hero.add_child(_title)
	var badge_host := CenterContainer.new()
	badge_host.name = "StockHost"
	badge_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(badge_host)
	_stock_badge = UiKit.badge(STOCK_BADGE % 0, &"LockBadge")
	_stock_badge.name = "StockBadge"
	_stock_label = _stock_badge.get_child(0).get_child(0)
	_stock_label.add_theme_font_size_override("font_size", 15)
	badge_host.add_child(_stock_badge)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, UiTokens.SPACE_XS)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(gap)


func _build_options() -> void:
	var body: VBoxContainer = _frame.get_meta(&"body")
	body.add_theme_constant_override("separation", UiTokens.SPACE_MD)

	# Ödüllü reklam kartı.
	_ad = UiKit.button(AD_BUTTON, &"ButtonPrimary", "movie")
	_ad.name = "Ad"
	_ad.custom_minimum_size = Vector2(0, OPTION_BUTTON_HEIGHT)
	_ad.pressed.connect(_on_ad_pressed)
	var ad_parts: Dictionary = _option_card("AdCard", UiKit.icon_texture("movie"), AD_ACCENT,
		AD_TITLE, _ad)
	_ad_card = ad_parts["card"]
	_ad_sub = ad_parts["sub"]
	_quota = UiKit.label("", &"LabelCaption", HORIZONTAL_ALIGNMENT_LEFT)
	_quota.name = "Quota"
	_quota.add_theme_font_size_override("font_size", 15)
	(ad_parts["status"] as HBoxContainer).add_child(_quota)
	_ad_note = ad_parts["note"]
	body.add_child(_ad_card)

	# Hamur kartı.
	_dough = UiKit.button(DOUGH_BUTTON, &"ButtonPurchase")
	_dough.name = "Dough"
	_dough.custom_minimum_size = Vector2(0, OPTION_BUTTON_HEIGHT)
	_dough.pressed.connect(_on_dough_pressed)
	var dough_parts: Dictionary = _option_card("DoughCard", DOUGH_ART, DOUGH_ACCENT,
		DOUGH_TITLE, _dough)
	_dough_card = dough_parts["card"]
	_dough_sub = dough_parts["sub"]
	var status: HBoxContainer = dough_parts["status"]
	var coin := UiKit.art(DOUGH_ART, 24.0)
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(coin)
	_price = UiKit.label("", &"LabelPrice", HORIZONTAL_ALIGNMENT_LEFT)
	_price.name = "Price"
	_price.add_theme_font_size_override("font_size", 22)
	status.add_child(_price)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(spacer)
	_balance = UiKit.label("", &"LabelCaption", HORIZONTAL_ALIGNMENT_RIGHT)
	_balance.name = "Balance"
	_balance.add_theme_font_size_override("font_size", 15)
	status.add_child(_balance)
	_dough_note = dough_parts["note"]
	body.add_child(_dough_card)


## Seçenek kartı: bir ton geri krem gövde (`card_bevel_soft`) + ince lavanta
## halka; sol üstte kimlik kuyusu (candy_well, küçük), yanında Baloo başlık +
## "+1 Bomba" satırı; altında durum satırı (kota / fiyat + bakiye), gerekirse
## sebep notu, en altta tam genişlik buton. Meta: card / sub / status / note.
func _option_card(card_name: String, well_tex: Texture2D, accent: Color,
		title: String, button: Button) -> Dictionary:
	var card := PanelContainer.new()
	card.name = card_name
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel",
		UiKit.style("card_bevel_soft", UiTokens.CREAM_DEEP, Vector4(16, 14, 16, 16)))
	var ring := UiKit.flat_plate("frame_round20", Color(UiTokens.LAVENDER_SURFACE, 0.95))
	ring.show_behind_parent = true
	UiKit.inset(ring, -2.0, -2.0, -2.0, -2.0)
	card.add_child(ring)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	var well_host := Control.new()
	well_host.custom_minimum_size = Vector2(OPTION_WELL + 8.0, OPTION_WELL + 10.0)
	well_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(well_host)
	var well := UiKit.candy_well(well_tex, accent, OPTION_WELL, OPTION_ART)
	well.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	well.offset_left = -OPTION_WELL * 0.5
	well.offset_right = OPTION_WELL * 0.5
	well.offset_top = -(OPTION_WELL + 6.0) * 0.5
	well.offset_bottom = (OPTION_WELL + 6.0) * 0.5
	well_host.add_child(well)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", -2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(text)
	var title_label := UiKit.label(title, &"LabelSection")
	title_label.add_theme_font_size_override("font_size", 20)
	text.add_child(title_label)
	var sub := UiKit.label("", &"LabelBody")
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	text.add_child(sub)
	var status := HBoxContainer.new()
	status.name = "Status"
	status.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(status)
	var note := UiKit.label("", &"LabelWarning", HORIZONTAL_ALIGNMENT_LEFT)
	note.name = "Note"
	note.add_theme_font_size_override("font_size", 14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.visible = false
	column.add_child(note)
	column.add_child(button)
	return {"card": card, "sub": sub, "status": status, "note": note}


func _build_footer() -> void:
	var footer: VBoxContainer = _frame.get_meta(&"footer")
	footer.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_note = UiKit.label("", &"LabelWarning", HORIZONTAL_ALIGNMENT_CENTER)
	_note.name = "Note"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.visible = false
	footer.add_child(_note)
	_close = UiKit.button(CLOSE_TEXT, &"ButtonSecondary")
	_close.name = "Close"
	_close.pressed.connect(_on_close_pressed)
	footer.add_child(_close)


# --- Sözleşme ------------------------------------------------------------------

func current_type() -> int:
	return _type


## `provider_ready`: ödüllü reklam ŞİMDİ gösterilebilir mi (Main söyler);
## `provider_note`: değilse kartta yazan sebep (boşsa "henüz bağlı değil").
## Reklam pencere açıkken hazır olursa Main `refresh(true)` ile butonu açar.
func show_refill(type: PowerUp.Type, provider_ready: bool, provider_note: String = "") -> void:
	_type = int(type)
	_request_pending = false
	_purchase_sent = false
	_provider_note = provider_note
	var art: Texture2D = PowerUp.icon(type)
	var picture: TextureRect = _well.get_meta(&"art")
	picture.texture = art
	UiKit.set_candy_well_accent(_well, PowerUp.accent(type))
	_title.text = PowerUp.display_name(type)
	_ad_sub.text = REWARD_LINE % PowerUp.display_name(type)
	_dough_sub.text = REWARD_LINE % PowerUp.display_name(type)
	_note.text = ""
	_note.visible = false
	refresh(provider_ready)
	visible = true
	UiKit.modal_relayout(_frame)
	UiMotion.modal_open(_frame, _dim)
	AudioManager.play(&"ui_modal_open")


## Butonların açık/kapalı durumunu, kota ve fiyat satırlarını tazeler. Satın
## alma sonrası, kota değişince ve sağlayıcı hazırlığı değişince tekrar
## çağrılıyor. Hiçbir şey yazmaz.
func refresh(provider_ready: bool, provider_note: String = "") -> void:
	if _type < 0:
		return
	_provider_ready = provider_ready
	_provider_note = provider_note
	_purchase_sent = false
	var type: PowerUp.Type = _type as PowerUp.Type
	_stock_label.text = STOCK_BADGE % SaveManager.powerup_count(type)

	# Ödüllü kart: kota dolduysa VEYA sağlayıcı yoksa VEYA talep açıksa pasif;
	# sebep kartın içinde yazıyor.
	var quota_left: int = RewardedPolicy.remaining_today()
	_quota.text = QUOTA_LINE % [quota_left, RewardedPolicy.daily_cap()]
	_quota.add_theme_color_override("font_color",
		UiTokens.TEXT_WARNING if quota_left <= 0 else UiTokens.TEXT_POSITIVE)
	var ad_enabled: bool = quota_left > 0 and provider_ready and not _request_pending
	_ad.disabled = not ad_enabled
	var ad_reason: String = ""
	if _request_pending:
		ad_reason = NOTE_REQUESTING
	elif quota_left <= 0:
		ad_reason = NOTE_QUOTA_USED
	elif not provider_ready:
		ad_reason = provider_note if provider_note != "" else NOTE_NO_PROVIDER
	_set_note(_ad_note, ad_reason, _request_pending)

	# Hamur kartı: fiyat tek kaynaktan; yetmiyorsa pasif + sebep.
	var price: int = PowerUpEconomy.price(type)
	var balance: int = SaveManager.dough()
	_price.text = PRICE_LINE % price
	_balance.text = BALANCE_LINE % balance
	var affordable: bool = PowerUpEconomy.can_afford(type)
	_dough.disabled = not affordable
	_balance.add_theme_color_override("font_color",
		UiTokens.TEXT_SECONDARY if affordable else UiTokens.TEXT_WARNING)
	_set_note(_dough_note, "" if affordable else "%s (%d Hamur'un var)." % [NOTE_NO_DOUGH, balance], false)


func _set_note(note: Label, text: String, quiet: bool) -> void:
	note.text = text
	note.visible = text != ""
	note.add_theme_color_override("font_color",
		UiTokens.TEXT_SECONDARY if quiet else UiTokens.TEXT_WARNING)


## Sağlayıcı talebi reddetti / reklam hazır değil / ödül kazanılmadı, ya da
## Hamur işlemi yarışta başarısız oldu. Pencere AÇIK KALIR, kota tüketilmez,
## stok değişmez; mesaj altlıkta.
func show_unavailable(message: String, provider_ready: bool, provider_note: String = "") -> void:
	_request_pending = false
	refresh(provider_ready, provider_note)
	_note.text = message
	_note.visible = message != ""


func hide_refill() -> void:
	_type = -1
	_request_pending = false
	_purchase_sent = false
	if visible:
		AudioManager.play(&"ui_modal_close")
	visible = false


func _on_ad_pressed() -> void:
	if _type < 0 or _request_pending or _ad.disabled:
		return
	# Çift dokunuşa karşı: cevap gelene kadar ikinci talep gitmesin.
	_request_pending = true
	_note.text = ""
	_note.visible = false
	refresh(_provider_ready, _provider_note)
	rewarded_refill_requested.emit(_type)


func _on_dough_pressed() -> void:
	if _type < 0 or _purchase_sent or _dough.disabled:
		return
	# Tek sinyal: Main cevaplayana (kapanış ya da uyarı → refresh) kadar
	# ikinci basış yok sayılır — çift satın alma yok.
	_purchase_sent = true
	dough_refill_requested.emit(_type)


func _on_close_pressed() -> void:
	if not visible:
		return
	closed.emit()


# --- Testler / araçlar ----------------------------------------------------------

func frame() -> Control:
	return _frame


func dim() -> ColorRect:
	return _dim


func hero_art() -> TextureRect:
	return _well.get_meta(&"art")


func power_name_text() -> String:
	return _title.text


func stock_text() -> String:
	return _stock_label.text


func ribbon_text() -> String:
	return _ribbon_label.text


## Oyuncuya görünen fiyat satırı ("120 Hamur").
func price_text() -> String:
	return _price.text


func balance_text() -> String:
	return _balance.text


func ad_note_text() -> String:
	return _ad_note.text if _ad_note.visible else ""


func dough_note_text() -> String:
	return _dough_note.text if _dough_note.visible else ""


func note_text() -> String:
	return _note.text if _note.visible else ""


func ad_card() -> PanelContainer:
	return _ad_card


func dough_card() -> PanelContainer:
	return _dough_card


func close_button() -> Button:
	return _close_button


func is_request_pending() -> bool:
	return _request_pending


func is_purchase_sent() -> bool:
	return _purchase_sent


func provider_ready() -> bool:
	return _provider_ready


func provider_note() -> String:
	return _provider_note
