extends CanvasLayer
## Stok 0 güç refill penceresi — GAME_DESIGN.md §5.7.3 / §5.7.3.1. TASK/060 V3 yeniden kurulum (TEXT-LIGHT /
## ICON-FIRST): eski M8.6-10 iki metin ağırlıklı seçenek kartı ("ÖDÜLLÜ REKLAM" / "HAMURLA AL", "STOK ×0",
## ortak "Bugünkü hakkın: 1/1") kalktı.
##
## ⚠️ BU PENCERE REKLAM OYNATMAZ, STOK VERMEZ, HAMUR DÜŞMEZ, KOTA TÜKETMEZ.
## Yalnızca sunar ve buton sinyali yayar:
##   İZLE   → `rewarded_refill_requested(type)` → Main → sağlayıcı → ödül kazanıldı →
##            `Main.grant_rewarded_power` → `RewardedPolicy.grant` (tek transaction: BU gücün stoğu + BU gücün kotası)
##   Hamur  → `dough_refill_requested(type)` → Main → `PowerUpEconomy.purchase` (tek transaction, Hamur + stok)
##   KAPAT / X / karartma / Android geri → `closed` (hiçbir şey alınmaz, oyun kaldığı yerden sürer —
##            Main `exit_refill_pending(false)`)
## Fiyat `PowerUpEconomy.price()` — mağazayla aynı tek kaynak, burada sayı yok.
## Kota `RewardedPolicy` — TASK/060: güç BAŞINA günde 2; düğmede BAŞARILI kullanım "0/2 → 1/2 → 2/2" (kalan hak
## değil). Bir gücün 2/2'si diğer güçlerin penceresini etkilemez.
##
## Kompozisyon (`UiKit.modal_shell`, kurdele = gücün adı, oturmuş X):
##   HERO   gücün GERÇEK sanatı büyük candy kuyuda (gücün vurgu rengi) + stok kabarcığı — YALNIZ rakam ("0")
##   BODY   iki yan yana seçenek karosu (aynı iskelet): film kuyusu + "+1" + `SquishyButton` REWARDED_AD "İZLE"
##          (sayaç cipi n/2) · Hamur kuyusu + "+1" + `SquishyButton` CURRENCY (gerçek fiyat) + bakiye
##   FOOTER Main'in kısa notu + KAPAT
## Pasif / tükenmiş / yetersiz durum = düğme durumu (V3 durum makinesi) + kısa, anlaşılır sebep (sessiz başarısızlık
## yok): "Bugünlük bitti — yarın yenilenir." · "Ödüllü reklam henüz bağlı değil." / sağlayıcının nedeni ·
## "Hamur yetersiz". Talep gönderilince İZLE cevap gelene kadar kilitli; Hamur düğmesi bir kez sinyal yayar,
## Main cevaplayana (kapanış ya da uyarı) kadar ikinci basış yok sayılır. Hamur yetmiyorsa düğme INSUFFICIENT
## (V3: dokunulabilir, soluk — basış kısa geri bildirim verir; hiçbir şey alınmaz).
##
## Gelecekteki üçüncü CTA (gerçek para Güç Paketi) için seam `power_pack_requested` sinyali duruyor ama HİÇBİR YERE
## BAĞLI DEĞİL ve buton gösterilmiyor (billing yok — sahte satın alma butonu yok).
##
## Sözleşme (Main / testler / çekim araçları): `show_refill(type, provider_ready[, provider_note])`,
## `refresh(provider_ready[, provider_note])`, `show_unavailable(message, provider_ready[, provider_note])`,
## `hide_refill()`, `current_type()`; düğümler `_ad`, `_dough`, `_note`, `_close`.

## Oyuncu ödüllü reklam CTA'sına bastı. Bu bir TALEP'tir, stok DEĞİL.
signal rewarded_refill_requested(type: int)
## Oyuncu Hamurla almayı seçti.
signal dough_refill_requested(type: int)
## ⚠️ KULLANILMIYOR — Google Play Billing kurulunca bağlanacak seam.
signal power_pack_requested(type: int)
signal closed

const DOUGH_ART: Texture2D = preload("res://assets/visual/ui/icon_dough.png")
const MODAL_WIDTH: float = 560.0
const HERO_WELL: float = 156.0
const HERO_ART: float = 116.0
const HERO_HOST_HEIGHT: float = 176.0
const STOCK_SIZE: float = 58.0
const OPTION_WELL: float = 64.0
const OPTION_ART: float = 42.0
const OPTION_GAP: float = 16.0
const REWARD_SIZE: int = 30
## Kopyalar (oyuncu dili Türkçe; TEXT-LIGHT: tek kelime + sayı).
const AD_BUTTON: String = "İZLE"
const REWARD_TEXT: String = "+1"
const CLOSE_TEXT: String = "KAPAT"
const NOTE_REQUESTING: String = "Reklam isteniyor…"
const NOTE_NO_PROVIDER: String = "Ödüllü reklam henüz bağlı değil."
const NOTE_QUOTA_USED: String = "Bugünlük bitti — yarın yenilenir."
const NOTE_NO_DOUGH: String = "Hamur yetersiz"
const AD_ACCENT: Color = UiTokens.ROLE_AD
const DOUGH_ACCENT: Color = UiTokens.GOLD

var _type: int = -1
var _provider_ready: bool = false
## Sağlayıcı hazır değilken reklam karosunda yazan sebep (M8.9-01); boşsa NOTE_NO_PROVIDER.
var _provider_note: String = ""
var _request_pending: bool = false
var _purchase_sent: bool = false

var _frame: Control
var _ribbon_label: Label
var _hero_host: Control
var _well: Control
var _stock_bubble: Control
var _stock_label: Label
var _stock: int = 0
var _ad_card: PanelContainer
var _ad_note: Label
var _ad: SquishyButton
var _dough_card: PanelContainer
var _balance: Label
var _balance_row: HBoxContainer
var _dough_note: Label
var _dough: SquishyButton
var _note: Label
var _close_button: Button
var _close: SquishyButton

@onready var _dim: ColorRect = $Center/Dim
@onready var _anchor: CenterContainer = $Center/Anchor


func _ready() -> void:
	visible = false
	_frame = UiKit.modal_shell("GÜÇ", MODAL_WIDTH, &"ribbon", false, true)
	_frame.name = "RefillShell"
	_anchor.add_child(_frame)
	_ribbon_label = (_frame.get_meta(&"ribbon") as PanelContainer).get_meta(&"title_label")
	_build_hero()
	_build_options()
	_build_footer()
	_close_button = _frame.get_meta(&"close_button")
	GestureGuard.on_pressed(_close_button, _on_close_pressed)
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
	# Stok kabarcığı (PowerCard ile aynı dil): kuyunun sağ üst omzunda, YALNIZ rakam.
	_stock_bubble = Control.new()
	_stock_bubble.name = "Stock"
	_stock_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stock_bubble.size = Vector2(STOCK_SIZE, STOCK_SIZE)
	_stock_bubble.draw.connect(_draw_stock)
	_well.add_child(_stock_bubble)
	_stock_bubble.position = Vector2(HERO_WELL - STOCK_SIZE * 0.62, -STOCK_SIZE * 0.08)
	_stock_label = UiType.v3_label("0", UiType.V3_BUTTON, true, HORIZONTAL_ALIGNMENT_CENTER, 34)
	_stock_label.name = "Count"
	_stock_label.position = Vector2(0.0, -4.0)
	_stock_label.size = Vector2(STOCK_SIZE, STOCK_SIZE)
	_stock_bubble.add_child(_stock_label)


func _build_options() -> void:
	var body: VBoxContainer = _frame.get_meta(&"body")
	body.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	var row := HBoxContainer.new()
	row.name = "Options"
	row.add_theme_constant_override("separation", int(OPTION_GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(row)

	# Ödüllü reklam karosu: film kuyusu + "+1" + İZLE (BAŞARILI kullanım cipi n/2).
	_ad = SquishyButton.new(AD_BUTTON, SquishyButton.Kind.REWARDED_AD, SquishyButton.SizeClass.COMPACT)
	_ad.name = "Ad"
	_ad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GestureGuard.on_pressed(_ad, _on_ad_pressed)
	var ad_parts: Dictionary = _option_card("AdCard", UiKit.icon_texture("movie"), AD_ACCENT, _ad)
	_ad_card = ad_parts["card"]
	_ad_note = ad_parts["note"]
	row.add_child(_ad_card)

	# Hamur karosu: Hamur kuyusu + "+1" + gerçek fiyat düğmesi + bakiye (ikon + rakam).
	_dough = SquishyButton.new("", SquishyButton.Kind.CURRENCY, SquishyButton.SizeClass.COMPACT)
	_dough.name = "Dough"
	_dough.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GestureGuard.on_pressed(_dough, _on_dough_pressed)
	var dough_parts: Dictionary = _option_card("DoughCard", DOUGH_ART, DOUGH_ACCENT, _dough)
	_dough_card = dough_parts["card"]
	_dough_note = dough_parts["note"]
	_balance_row = HBoxContainer.new()
	_balance_row.name = "Balance"
	_balance_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_balance_row.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	_balance_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := UiKit.art(DOUGH_ART, 22.0)
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_balance_row.add_child(coin)
	_balance = UiType.v3_label("0", UiType.V3_SECONDARY, false, HORIZONTAL_ALIGNMENT_LEFT)
	_balance.name = "BalanceValue"
	_balance_row.add_child(_balance)
	var column: VBoxContainer = dough_parts["column"]
	column.add_child(_balance_row)
	column.move_child(_balance_row, column.get_child_count() - 2)
	row.add_child(_dough_card)


## Seçenek karosu: yumuşak düz krem-lavanta yüzey (çerçeve-içinde-çerçeve yok) — üstte kimlik kuyusu (candy_well),
## altında büyük "+1", en altta tam genişlik V3 düğme, gerekirse kısa sebep. Meta: card / column / note.
func _option_card(card_name: String, well_tex: Texture2D, accent: Color, button: SquishyButton) -> Dictionary:
	var card := PanelContainer.new()
	card.name = card_name
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face: StyleBoxFlat = UiKit.v3_box(UiTokens.SURFACE_NEUTRAL_DEEP, UiTokens.RADIUS_FEATURE)
	face.content_margin_left = 14.0
	face.content_margin_right = 14.0
	face.content_margin_top = 12.0
	face.content_margin_bottom = 14.0
	card.add_theme_stylebox_override("panel", face)
	var column := VBoxContainer.new()
	column.name = "Column"
	# Üstten hizalı: iki karonun kuyusu / "+1" / düğmesi aynı yükseklikte (sebep notu yalnız altta uzar).
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", UiTokens.SPACE_SM)
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
	var reward := UiType.v3_label(REWARD_TEXT, UiType.V3_SCREEN_TITLE, false, HORIZONTAL_ALIGNMENT_LEFT, REWARD_SIZE)
	reward.name = "Reward"
	reward.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	head.add_child(reward)
	column.add_child(button)
	var note := UiType.v3_label("", UiType.V3_SECONDARY, false, HORIZONTAL_ALIGNMENT_CENTER)
	note.name = "Note"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.visible = false
	column.add_child(note)
	return {"card": card, "column": column, "note": note}


func _build_footer() -> void:
	var footer: VBoxContainer = _frame.get_meta(&"footer")
	footer.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_note = UiKit.label("", &"LabelWarning", HORIZONTAL_ALIGNMENT_CENTER)
	_note.name = "Note"
	_note.add_theme_color_override("font_color", UiTokens.TEXT_WARNING_STRONG)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.visible = false
	footer.add_child(_note)
	_close = SquishyButton.new(CLOSE_TEXT, SquishyButton.Kind.SECONDARY, SquishyButton.SizeClass.COMPACT)
	_close.name = "Close"
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	GestureGuard.on_pressed(_close, _on_close_pressed)
	footer.add_child(_close)


# --- Sözleşme ------------------------------------------------------------------

func current_type() -> int:
	return _type


## `provider_ready`: ödüllü reklam ŞİMDİ gösterilebilir mi (Main söyler); `provider_note`: değilse karoda yazan sebep
## (boşsa "henüz bağlı değil"). Reklam pencere açıkken hazır olursa Main `refresh(true)` ile düğmeyi açar.
func show_refill(type: PowerUp.Type, provider_ready: bool, provider_note: String = "") -> void:
	_type = int(type)
	_request_pending = false
	_purchase_sent = false
	_provider_note = provider_note
	var picture: TextureRect = _well.get_meta(&"art")
	picture.texture = PowerUp.icon(type)
	UiKit.set_candy_well_accent(_well, PowerUp.accent(type))
	_ribbon_label.text = UiType.upper_tr(PowerUp.display_name(type))
	_note.text = ""
	_note.visible = false
	refresh(provider_ready, provider_note)
	visible = true
	UiKit.modal_relayout(_frame)
	UiMotion.modal_open(_frame, _dim)
	AudioManager.play(&"ui_modal_open")


## Düğme durumlarını, BU gücün kota cipini, stok kabarcığını, fiyatı ve bakiyeyi tazeler. Satın alma sonrası, kota
## değişince ve sağlayıcı hazırlığı değişince tekrar çağrılır. Hiçbir şey yazmaz.
func refresh(provider_ready: bool, provider_note: String = "") -> void:
	if _type < 0:
		return
	_provider_ready = provider_ready
	_provider_note = provider_note
	_purchase_sent = false
	var type: PowerUp.Type = _type as PowerUp.Type
	_stock = SaveManager.powerup_count(type)
	_stock_label.text = str(_stock)
	_stock_label.add_theme_color_override("font_color", UiTokens.TEXT_ON_DARK if _stock > 0 else UiTokens.TEXT_DISABLED)
	_stock_bubble.queue_redraw()

	# Ödüllü karo: BU gücün başarılı kullanımı n/2. Tükendiyse EXHAUSTED; sağlayıcı yoksa / talep açıksa pasif — sebep
	# karoda yazar.
	var used: int = RewardedPolicy.grants_today(type)
	var cap: int = RewardedPolicy.daily_cap()
	_ad.set_ad_progress(used, cap)
	var exhausted: bool = used >= cap
	var ad_reason: String = ""
	if _request_pending:
		_ad.set_state(SquishyButton.State.DISABLED)
		ad_reason = NOTE_REQUESTING
	elif exhausted:
		_ad.set_state(SquishyButton.State.EXHAUSTED)
		ad_reason = NOTE_QUOTA_USED
	elif not provider_ready:
		_ad.set_state(SquishyButton.State.UNAVAILABLE)
		ad_reason = provider_note if provider_note != "" else NOTE_NO_PROVIDER
	else:
		_ad.set_state(SquishyButton.State.NORMAL)
	_set_note(_ad_note, ad_reason, _request_pending)

	# Hamur karosu: fiyat tek kaynaktan; yetmiyorsa INSUFFICIENT + sebep. Ödüllü talep açıkken KİLİTLİ (TASK/060
	# incelemesi): reklam açılırken Hamur'la alıp pencereyi kapatmak açık talebin token'ını yaşatıp geç ödülü kapanmış
	# pencereye stok olarak düşürmesin.
	var balance: int = SaveManager.dough()
	_dough.set_price(PowerUpEconomy.price(type))
	var affordable: bool = PowerUpEconomy.can_afford(type)
	if _request_pending:
		_dough.set_state(SquishyButton.State.DISABLED)
	else:
		_dough.set_state(SquishyButton.State.NORMAL if affordable else SquishyButton.State.INSUFFICIENT)
	_balance.text = GameplayHud._thousands(balance)
	_balance.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY if affordable else UiTokens.TEXT_WARNING_STRONG)
	_set_note(_dough_note, "" if affordable else NOTE_NO_DOUGH, false)


func _set_note(note: Label, text: String, quiet: bool) -> void:
	note.text = text
	note.visible = text != ""
	# TASK/060 A36: küçük uyarı yazısı açık karoda okunur kontrastla (TEXT_WARNING_STRONG, ~4.8:1; eski ton 2.34:1).
	note.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY if quiet else UiTokens.TEXT_WARNING_STRONG)


## Sağlayıcı talebi reddetti / reklam hazır değil / ödül kazanılmadı, ya da Hamur işlemi başarısız oldu. Pencere AÇIK
## KALIR, kota tüketilmez, stok değişmez; kısa mesaj altlıkta.
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
	if _type < 0 or _purchase_sent or _dough.disabled or _request_pending:
		return
	# Tek sinyal: Main cevaplayana (kapanış ya da uyarı → refresh) kadar ikinci basış yok sayılır — çift satın alma
	# yok. Hamur yetmiyorsa (INSUFFICIENT) Main satın almayı reddeder ve kısa geri bildirim verir.
	_purchase_sent = true
	dough_refill_requested.emit(_type)


func _on_close_pressed() -> void:
	if not visible:
		return
	closed.emit()


func _draw_stock() -> void:
	var color: Color = UiTokens.NAVY_PURPLE if _stock > 0 else UiTokens.ROLE_DISABLED
	UiKit.draw_candy_circle(_stock_bubble, Vector2(STOCK_SIZE, STOCK_SIZE) * 0.5 - Vector2(0.0, 1.0),
		STOCK_SIZE - 4.0, color, color.darkened(0.35), 4.0, 4.0, UiTokens.DEPTH_RESTING, Color.WHITE, 3.5, 0.24)


# --- Testler / araçlar ----------------------------------------------------------

func frame() -> Control:
	return _frame


func dim() -> ColorRect:
	return _dim


func hero_art() -> TextureRect:
	return _well.get_meta(&"art")


## Gücün kanonik adı (kurdele bunun Türkçe büyük harfidir).
func power_name_text() -> String:
	return PowerUp.display_name(_type as PowerUp.Type) if _type >= 0 else ""


## Stok kabarcığının metni — YALNIZ rakam ("0"; "×" / "STOK" yok).
func stock_text() -> String:
	return _stock_label.text


func ribbon_text() -> String:
	return _ribbon_label.text


## Hamur düğmesinin fiyatı ("120") — `PowerUpEconomy.price` ile aynı.
func price_text() -> String:
	return _dough.price_text()


## Bakiye (rakam).
func balance_text() -> String:
	return _balance.text


## Ödüllü düğmenin kota cipi ("0/2" · "1/2" · "2/2" — BAŞARILI kullanım).
func quota_text() -> String:
	return _ad.counter_text()


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
