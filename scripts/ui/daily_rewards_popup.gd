extends CanvasLayer
## GÜNLÜK ÖDÜLLER penceresi (M8.9-02 / 02.1, owner kararı — docs/monetization/
## DAILY_REWARDS.md §5-§6). Oyuncunun TEK günlük ödül penceresi: üstte günlük
## GİRİŞ ödülü (GAME_DESIGN §5.4, `DailyReward`), altında üç günlük sistem;
## production dil (`UiKit.modal_shell`, pembe kurdele, oturmuş X; Refill'in
## seçenek kartı reçetesi):
##
##   ÜST (hero, sabit)    "N. GÜN" altın rozet · "+15 HAMUR" · ALINDI çipi ·
##                        7 düğümlü seri şeridi (`StreakStrip`); az önce
##                        alındıysa bugünkü düğüm kutlanır (`daily_reward`
##                        cue'su), seri kırıldıysa uyarı notu. Ödül burada
##                        VERİLMEZ: `DailyReward.claim_if_new_day` Main'de,
##                        pencere açılmadan ÖNCE çalışır; bu alan yalnız sonucu
##                        gösterir. Eski `DailyRewardPopup` (M8.6-08) kalktı.
##   A) ÜCRETSİZ SANDIK   pembe candy kuyuda owner sandığı · "Günde 1 · reklam
##                        yok" · HAZIR / ALINDI · nane AÇ
##   B) +150 HAMUR        altın kuyuda Hamur · "Reklam izle · Günde 1" ·
##                        HAZIR / ALINDI / REKLAM HAZIRLANIYOR · cyan REKLAM İZLE
##   C) REKLAMLI SANDIK   lavanta film kuyusu · "Reklam izle · Günde 2" ·
##                        2/2 · 1/2 · BUGÜNLÜK BİTTİ · cyan REKLAM İZLE
##   altlık               sağlayıcı/işlem notu + KAPAT (her zaman)
##
## ⚠️ BU PENCERE ÖDÜL VERMEZ, KOTA TÜKETMEZ, KAYDA YAZMAZ. Yalnız sunar ve
## sinyal yayar:
##   AÇ           → `free_chest_requested` → Main → `DailyRewards.claim_free_chest`
##                  (tek transaction) → `show_reveal(reward)`
##   REKLAM İZLE  → `ad_dough_requested` / `ad_chest_requested` → Main →
##                  sağlayıcı → ödül kazanıldı → `Main.grant_daily_*` →
##                  `DailyRewards.grant_*` → `show_reveal` / `refresh`
##   KAPAT / X / karartma / Android geri → `closed` (hiçbir şey alınmaz;
##                  otomatik açılışta yalnız "bugün görüldü" işareti — Main)
## Talep gönderilince o kartın butonu cevap gelene kadar kilitli ("Reklam
## isteniyor…"); sağlayıcı hazır değilken buton PASİF + kartta gerçek sebep
## (sahte hazır yok — M8.6-10 sözleşmesi). Pencere açıkken reklam yüklenirse
## Main `refresh(true)` ile butonu açar.
##
## REVEAL (§6): ödül ZATEN kayda yazılmış gelir. Gövde kartları yerine
## owner sandığı (`RewardGem`) açılır → "+15 HAMUR" belirir → skin varsa
## `ResultRewardCard` (YENİ SKİN, gerçek final sanat) pop'lar; ~1,2 s'de
## DEVAM açılır; X her an kapatır (ödül kaybolmaz, yeniden kura YOK —
## `DailyChestReward` değişmez, pencere yalnız gösterir).

signal free_chest_requested
signal ad_dough_requested
signal ad_chest_requested
signal closed

const RIBBON: String = "GÜNLÜK ÖDÜLLER"
const MODAL_WIDTH: float = 560.0
## Giriş ödülü üst bölgesi (M8.9-02.1).
const LOGIN_DAY: String = "%d. GÜN"
const LOGIN_REWARD: String = "+%d HAMUR"
const LOGIN_CLAIMED: String = "ALINDI"
const LOGIN_PENDING: String = "BUGÜN"
const LOGIN_BROKEN_NOTE: String = "Serin kırılmıştı, sayaç sıfırlandı."
const DOUGH_ART_SMALL: float = 30.0
## Skin kartının halesi kartın dışına taşar (ResultRewardCard: −30/−26/−30/−34);
## reveal'de kart bu paylarla sarılır — hale kırpılmaz (M8.9-02.1).
const SKIN_CARD_MARGIN: Vector4 = Vector4(30.0, 26.0, 30.0, 34.0)
const SKIN_CAPTION: String = "Koleksiyon'a eklendi"
const CHEST_ART: Texture2D = preload("res://assets/visual/ui/chest_closed.png")
const DOUGH_ART: Texture2D = preload("res://assets/visual/ui/icon_dough.png")
const SPARKLE_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
const REWARD_GEM := preload("res://scripts/ui/reward_gem.gd")
const OPTION_WELL: float = 60.0
const OPTION_ART: float = 40.0
const OPTION_BUTTON_HEIGHT: float = 58.0
const FREE_TITLE: String = "ÜCRETSİZ SANDIK"
const FREE_SUB: String = "Günde 1 · reklam yok"
const FREE_BUTTON: String = "AÇ"
const DOUGH_TITLE: String = "+%d HAMUR"
const DOUGH_SUB: String = "Reklam izle · Günde 1"
const CHEST_TITLE: String = "REKLAMLI SANDIK"
const CHEST_SUB: String = "Reklam izle · Günde 2"
const AD_BUTTON: String = "REKLAM İZLE"
const CLOSE_TEXT: String = "KAPAT"
const CONTINUE_TEXT: String = "DEVAM"
const STATUS_READY: String = "HAZIR"
const STATUS_CLAIMED: String = "ALINDI"
const STATUS_PREPARING: String = "REKLAM HAZIRLANIYOR"
const STATUS_DONE: String = "BUGÜNLÜK BİTTİ"
const STATUS_REMAINING: String = "%d / %d"
const STATUS_REMAINING_SUB: String = "%d hak kaldı"
const NOTE_REQUESTING: String = "Reklam isteniyor…"
const NOTE_NO_PROVIDER: String = "Ödüllü reklam henüz bağlı değil."
const NOTE_CLOCK_BEHIND: String = "Cihaz saati geri alınmış görünüyor; ödüller tarih yetişince yenilenir."
const REVEAL_DOUGH: String = "+%d HAMUR"
const REVEAL_BONUS_NOTE: String = "%s skinlerin tamamı sende — yerine bonus Hamur"
const REVEAL_TITLE_FREE: String = "ÜCRETSİZ SANDIK"
const REVEAL_TITLE_AD: String = "REKLAMLI SANDIK"
## Reveal zamanlaması (s): sandık belirir → açılır → Hamur → skin → DEVAM.
const REVEAL_OPEN_DELAY: float = 0.32
const REVEAL_DOUGH_DELAY: float = 0.58
const REVEAL_SKIN_DELAY: float = 0.92
const REVEAL_CONTINUE_DELAY: float = 1.2
const GEM_SIZE: float = 128.0
const GEM_HOST_HEIGHT: float = 190.0
const FREE_ACCENT: Color = UiTokens.PINK
const DOUGH_ACCENT: Color = UiTokens.GOLD
const CHEST_ACCENT: Color = UiTokens.LAVENDER_DEEP

var _provider_ready: bool = false
var _provider_note: String = ""
## Açık talep: "" / "daily_dough" / "daily_chest".
var _pending_kind: String = ""
var _free_sent: bool = false
var _revealing: bool = false
var _reveal_tween: Tween = null
var _reward: DailyChestReward = null
## Otomatik açılış mı (Main olay bağlamı için okur).
var _auto_opened: bool = false

var _frame: Control
var _login_day: PanelContainer
var _login_day_label: Label
var _login_reward: Label
var _login_chip: PanelContainer
var _login_chip_label: Label
var _strip: StreakStrip
var _login_note: Label
var _login: Dictionary = {}
var _cards_host: VBoxContainer
var _free_card: PanelContainer
var _free_status: PanelContainer
var _free_status_label: Label
var _free_note: Label
var _free: Button
var _dough_card: PanelContainer
var _dough_status: PanelContainer
var _dough_status_label: Label
var _dough_note: Label
var _dough: Button
var _chest_card: PanelContainer
var _chest_status: PanelContainer
var _chest_status_label: Label
var _chest_sub: Label
var _chest_note: Label
var _chest: Button
var _reveal_host: VBoxContainer
var _reveal_title: Label
var _gem_host: Control
var _gem: Control
var _reveal_dough: Label
var _reveal_note: Label
var _reveal_skin_host: VBoxContainer
var _reveal_skin_margin: MarginContainer
var _reveal_skin_caption: Label
var _skin_card: ResultRewardCard
var _note: Label
var _close: Button
var _continue: Button
var _close_button: Button

@onready var _dim: ColorRect = $Center/Dim
@onready var _anchor: CenterContainer = $Center/Anchor


func _ready() -> void:
	visible = false
	_frame = UiKit.modal_shell(RIBBON, MODAL_WIDTH, &"ribbon", false, true)
	_frame.name = "DailyRewardsShell"
	_anchor.add_child(_frame)
	_build_login_hero()
	_build_cards()
	_build_reveal()
	_build_footer()
	_close_button = _frame.get_meta(&"close_button")
	_close_button.pressed.connect(close_popup)
	UiKit.attach_dim_close(_dim, close_popup)
	UiKit.modal_relayout(_frame)


# --- Kurulum ---------------------------------------------------------------------

## Üst bölge: günlük giriş ödülü (sabit, kaydırılmaz). Satır: [N. GÜN] [Hamur
## ikonu +15 HAMUR] [ALINDI]; altında seri şeridi; gerekirse uyarı notu.
func _build_login_hero() -> void:
	var hero: VBoxContainer = _frame.get_meta(&"hero")
	hero.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	var row := HBoxContainer.new()
	row.name = "LoginRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(row)
	_login_day = UiKit.badge(LOGIN_DAY % 1)
	_login_day.name = "LoginDay"
	_login_day_label = _login_day.get_child(0).get_child(0)
	_login_day_label.add_theme_font_size_override("font_size", 17)
	row.add_child(_login_day)
	var reward_row := HBoxContainer.new()
	reward_row.add_theme_constant_override("separation", 6)
	reward_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(reward_row)
	var coin := UiKit.art(DOUGH_ART, DOUGH_ART_SMALL)
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reward_row.add_child(coin)
	_login_reward = UiKit.label(LOGIN_REWARD % DailyReward.DAILY_DOUGH, &"LabelPrice")
	_login_reward.name = "LoginReward"
	_login_reward.add_theme_font_size_override("font_size", 30)
	reward_row.add_child(_login_reward)
	_login_chip = UiKit.badge(LOGIN_CLAIMED, &"LockBadge")
	_login_chip.name = "LoginChip"
	_login_chip_label = _login_chip.get_child(0).get_child(0)
	_login_chip_label.add_theme_font_size_override("font_size", 14)
	row.add_child(_login_chip)
	_strip = StreakStrip.new()
	_strip.name = "Streak"
	_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(_strip)
	_login_note = UiKit.label("", &"LabelWarning", HORIZONTAL_ALIGNMENT_CENTER)
	_login_note.name = "LoginNote"
	_login_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_login_note.visible = false
	hero.add_child(_login_note)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, UiTokens.SPACE_XS)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(gap)


func _build_cards() -> void:
	var body: VBoxContainer = _frame.get_meta(&"body")
	body.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	_cards_host = VBoxContainer.new()
	_cards_host.name = "Cards"
	_cards_host.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	_cards_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_cards_host)

	_free = UiKit.button(FREE_BUTTON, &"ButtonPurchase")
	_free.name = "Free"
	_free.custom_minimum_size = Vector2(0, OPTION_BUTTON_HEIGHT)
	_free.pressed.connect(_on_free_pressed)
	var free_parts: Dictionary = _option_card("FreeCard", CHEST_ART, FREE_ACCENT, FREE_TITLE, FREE_SUB, _free)
	_free_card = free_parts["card"]
	_free_status = free_parts["status"]
	_free_status_label = free_parts["status_label"]
	_free_note = free_parts["note"]
	_cards_host.add_child(_free_card)

	_dough = UiKit.button(AD_BUTTON, &"ButtonPrimary", "movie")
	_dough.name = "Dough"
	_dough.custom_minimum_size = Vector2(0, OPTION_BUTTON_HEIGHT)
	_dough.pressed.connect(_on_dough_pressed)
	var dough_parts: Dictionary = _option_card("DoughCard", DOUGH_ART, DOUGH_ACCENT,
		DOUGH_TITLE % DailyRewards.AD_DOUGH_AMOUNT, DOUGH_SUB, _dough)
	_dough_card = dough_parts["card"]
	_dough_status = dough_parts["status"]
	_dough_status_label = dough_parts["status_label"]
	_dough_note = dough_parts["note"]
	_cards_host.add_child(_dough_card)

	_chest = UiKit.button(AD_BUTTON, &"ButtonPrimary", "movie")
	_chest.name = "AdChest"
	_chest.custom_minimum_size = Vector2(0, OPTION_BUTTON_HEIGHT)
	_chest.pressed.connect(_on_chest_pressed)
	var chest_parts: Dictionary = _option_card("AdChestCard", CHEST_ART, CHEST_ACCENT, CHEST_TITLE, CHEST_SUB, _chest)
	_chest_card = chest_parts["card"]
	_chest_status = chest_parts["status"]
	_chest_status_label = chest_parts["status_label"]
	_chest_sub = chest_parts["sub"]
	_chest_note = chest_parts["note"]
	_cards_host.add_child(_chest_card)


## Seçenek kartı (Refill reçetesi): bir ton geri krem gövde + ince lavanta
## halka; solda kimlik kuyusu (candy_well), yanında Baloo başlık + alt satır;
## sağda durum rozeti; altında gerekirse sebep notu ve tam genişlik buton.
func _option_card(card_name: String, well_tex: Texture2D, accent: Color, title: String,
		sub_text: String, button: Button) -> Dictionary:
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
	title_label.name = "Title"
	title_label.add_theme_font_size_override("font_size", 21)
	text.add_child(title_label)
	var sub := UiKit.label(sub_text, &"LabelBody")
	sub.name = "Sub"
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	text.add_child(sub)
	var status_host := CenterContainer.new()
	status_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(status_host)
	var status := UiKit.badge(STATUS_READY)
	status.name = "Status"
	var status_label: Label = status.get_child(0).get_child(0)
	status_label.add_theme_font_size_override("font_size", 14)
	status_host.add_child(status)
	var note := UiKit.label("", &"LabelWarning", HORIZONTAL_ALIGNMENT_LEFT)
	note.name = "Note"
	note.add_theme_font_size_override("font_size", 14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.visible = false
	column.add_child(note)
	column.add_child(button)
	return {"card": card, "sub": sub, "status": status, "status_label": status_label, "note": note}


func _build_reveal() -> void:
	var body: VBoxContainer = _frame.get_meta(&"body")
	_reveal_host = VBoxContainer.new()
	_reveal_host.name = "Reveal"
	_reveal_host.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_reveal_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_host.visible = false
	body.add_child(_reveal_host)
	_reveal_title = UiKit.label("", &"LabelSection", HORIZONTAL_ALIGNMENT_CENTER)
	_reveal_title.name = "RevealTitle"
	_reveal_title.add_theme_font_size_override("font_size", 20)
	_reveal_host.add_child(_reveal_title)
	_gem_host = Control.new()
	_gem_host.name = "GemHost"
	_gem_host.custom_minimum_size = Vector2(0, GEM_HOST_HEIGHT)
	_gem_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_host.add_child(_gem_host)
	_reveal_dough = UiKit.label("", &"LabelPrice", HORIZONTAL_ALIGNMENT_CENTER)
	_reveal_dough.name = "RevealDough"
	_reveal_dough.add_theme_font_size_override("font_size", 38)
	_reveal_host.add_child(_reveal_dough)
	_reveal_note = UiKit.label("", &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
	_reveal_note.name = "RevealNote"
	_reveal_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reveal_note.add_theme_color_override("font_color", UiTokens.TEXT_TERTIARY)
	_reveal_note.visible = false
	_reveal_host.add_child(_reveal_note)
	# Skin kartı gövde genişliğine yayılır (round sonuyla aynı: kart
	# SIZE_EXPAND_FILL; ortalayıcı container kartı minimum genişliğe sıkıştırıp
	# sağdan kırpıyordu). Kartın dışına taşan hale/gölge için kart
	# SKIN_CARD_MARGIN paylarıyla sarılır (gövde kaydırma alanı kırpmasın);
	# "Koleksiyon'a eklendi" kartın altında tam genişlik yazılır (dar kartta
	# rozet satırı sıkışmasın).
	_reveal_skin_host = VBoxContainer.new()
	_reveal_skin_host.name = "RevealSkin"
	_reveal_skin_host.add_theme_constant_override("separation", 0)
	_reveal_skin_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_skin_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reveal_skin_host.visible = false
	_reveal_host.add_child(_reveal_skin_host)
	_reveal_skin_margin = MarginContainer.new()
	_reveal_skin_margin.name = "SkinCardMargin"
	_reveal_skin_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_skin_margin.add_theme_constant_override("margin_left", int(SKIN_CARD_MARGIN.x))
	_reveal_skin_margin.add_theme_constant_override("margin_top", int(SKIN_CARD_MARGIN.y))
	_reveal_skin_margin.add_theme_constant_override("margin_right", int(SKIN_CARD_MARGIN.z))
	_reveal_skin_margin.add_theme_constant_override("margin_bottom", int(SKIN_CARD_MARGIN.w))
	_reveal_skin_host.add_child(_reveal_skin_margin)
	_reveal_skin_caption = UiKit.label(SKIN_CAPTION, &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
	_reveal_skin_caption.name = "SkinCaption"
	_reveal_skin_caption.add_theme_color_override("font_color", UiTokens.TEXT_TERTIARY)
	_reveal_skin_caption.modulate.a = 0.0
	_reveal_skin_host.add_child(_reveal_skin_caption)


func _build_footer() -> void:
	var footer: VBoxContainer = _frame.get_meta(&"footer")
	footer.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_note = UiKit.label("", &"LabelWarning", HORIZONTAL_ALIGNMENT_CENTER)
	_note.name = "Note"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.visible = false
	footer.add_child(_note)
	_continue = UiKit.button(CONTINUE_TEXT, &"ButtonPrimary")
	_continue.name = "Continue"
	_continue.visible = false
	_continue.pressed.connect(_on_continue_pressed)
	footer.add_child(_continue)
	_close = UiKit.button(CLOSE_TEXT, &"ButtonSecondary")
	_close.name = "Close"
	_close.pressed.connect(close_popup)
	footer.add_child(_close)


# --- Sözleşme (Main) --------------------------------------------------------------

## Pencereyi kart görünümünde açar. `provider_ready`: ödüllü reklam ŞİMDİ
## gösterilebilir mi (Main söyler); `provider_note`: değilse kartlarda yazan
## gerçek sebep. `auto`: otomatik günlük açılış (olay bağlamı). `login`:
## günlük giriş ödülü görünümü (`DailyReward.view()` + Main'in
## `just_claimed` / `streak_broken` bilgisi) — ödül ZATEN yazılmış gelir.
func open_popup(provider_ready: bool, provider_note: String = "", auto: bool = false,
		login: Dictionary = {}) -> void:
	_auto_opened = auto
	_pending_kind = ""
	_free_sent = false
	_end_reveal(false)
	_note.text = ""
	_note.visible = false
	var just_claimed: bool = _apply_login(login)
	refresh(provider_ready, provider_note)
	visible = true
	UiKit.modal_relayout(_frame)
	UiMotion.modal_open(_frame, _dim)
	if just_claimed:
		# Az önce alınan giriş ödülü: neşeli cue + bugünkü düğüm kutlanır.
		AudioManager.play(&"daily_reward")
		_strip.mark_today()
		UiMotion.pop(_login_reward, 1.12)
	else:
		AudioManager.play(&"ui_modal_open")


## Giriş ödülü üst bölgesini kurar; "az önce alındı" ise true döner.
func _apply_login(login: Dictionary) -> bool:
	_login = login.duplicate() if not login.is_empty() else DailyReward.view()
	var streak: int = int(_login.get("streak", 0))
	var claimed: bool = bool(_login.get("claimed_today", false))
	var just_claimed: bool = bool(_login.get("just_claimed", false)) and claimed
	_login_day_label.text = LOGIN_DAY % maxi(streak, 1)
	_login_reward.text = LOGIN_REWARD % int(_login.get("reward", DailyReward.DAILY_DOUGH))
	_login_chip_label.text = LOGIN_CLAIMED if claimed else LOGIN_PENDING
	_login_chip.theme_type_variation = &"LockBadge" if claimed else &"Badge"
	_login_chip_label.theme_type_variation = &"LabelBadgeOnDark" if claimed else &"LabelBadge"
	_login_chip_label.add_theme_font_size_override("font_size", 14)
	# Kutlama açılışta oynar (mark_today); zaten alınmışsa bugün yıldızlı.
	_strip.set_streak(streak, claimed and not just_claimed)
	var broken: bool = bool(_login.get("streak_broken", false))
	_login_note.text = LOGIN_BROKEN_NOTE if broken else ""
	_login_note.visible = broken
	return just_claimed


## Kartların durumunu kanonik modelden (`DailyRewards.state()`) tazeler.
## Hiçbir şey yazmaz. Açık talep varsa o kartın butonu kilitli kalır.
func refresh(provider_ready: bool, provider_note: String = "") -> void:
	_provider_ready = provider_ready
	_provider_note = provider_note
	var state: Dictionary = DailyRewards.state()
	var clock_behind: bool = bool(state["clock_behind"])

	# A) Ücretsiz sandık.
	var free_ok: bool = bool(state["free_chest_available"])
	_set_status(_free_status, _free_status_label, STATUS_READY if free_ok else STATUS_CLAIMED, free_ok)
	_free.disabled = not free_ok or _free_sent
	_set_note(_free_note, "", false)

	# B) +150 Hamur (reklam).
	var dough_ok: bool = bool(state["ad_dough_available"])
	_apply_ad_card(_dough, _dough_status, _dough_status_label, _dough_note, dough_ok,
		STATUS_READY if dough_ok else STATUS_CLAIMED, "daily_dough")

	# C) Reklamlı sandık (2/gün).
	var left: int = int(state["ad_chests_remaining"])
	var chest_ok: bool = left > 0
	_chest_sub.text = CHEST_SUB
	_apply_ad_card(_chest, _chest_status, _chest_status_label, _chest_note, chest_ok,
		(STATUS_REMAINING % [left, DailyRewards.AD_CHESTS_PER_DAY]) if chest_ok else STATUS_DONE, "daily_chest", true)

	if clock_behind:
		_note.text = NOTE_CLOCK_BEHIND
		_note.visible = true


## Reklamlı kart: kota yoksa ALINDI/BİTTİ; kota var ama sağlayıcı hazır
## değilse REKLAM HAZIRLANIYOR (sandık kartında kalan hak "1 / 2" rozette
## kalır, sebep notta) + kartta gerçek sebep; talep açıksa kilitli.
func _apply_ad_card(button: Button, status: PanelContainer, status_label: Label, note: Label,
		quota_ok: bool, ready_text: String, kind: String, keep_count: bool = false) -> void:
	var pending: bool = _pending_kind == kind
	var enabled: bool = quota_ok and _provider_ready and not pending and _pending_kind == ""
	button.disabled = not enabled
	var reason: String = ""
	if pending:
		reason = NOTE_REQUESTING
	elif quota_ok and not _provider_ready:
		reason = _provider_note if _provider_note != "" else NOTE_NO_PROVIDER
	if not quota_ok:
		_set_status(status, status_label, ready_text, false)
	elif pending or not _provider_ready:
		_set_status(status, status_label, ready_text if keep_count else STATUS_PREPARING, false)
	else:
		_set_status(status, status_label, ready_text, true)
	_set_note(note, reason, pending)


func _set_status(status: PanelContainer, status_label: Label, text: String, ready: bool) -> void:
	status_label.text = text
	status.theme_type_variation = &"Badge" if ready else &"LockBadge"
	status_label.theme_type_variation = &"LabelBadge" if ready else &"LabelBadgeOnDark"
	status_label.add_theme_font_size_override("font_size", 14)


func _set_note(note: Label, text: String, quiet: bool) -> void:
	note.text = text
	note.visible = text != ""
	note.add_theme_color_override("font_color",
		UiTokens.TEXT_SECONDARY if quiet else UiTokens.TEXT_WARNING)


## Sağlayıcı talebi reddetti / reklam hazır değil / ödül kazanılmadı / kota
## yarışı. Pencere AÇIK KALIR, hiçbir kota tüketilmez; mesaj altlıkta.
func show_unavailable(_kind: String, message: String, provider_ready: bool, provider_note: String = "") -> void:
	_pending_kind = ""
	_free_sent = false
	refresh(provider_ready, provider_note)
	_note.text = message
	_note.visible = message != ""


## Ödül ZATEN kayda işlendi; burada yalnız gösterilir (yeniden kura yok).
func show_reveal(reward: DailyChestReward) -> void:
	_pending_kind = ""
	_free_sent = false
	_reward = reward
	_note.text = ""
	_note.visible = false
	if not visible:
		visible = true
		UiMotion.modal_open(_frame, _dim)
	_start_reveal(reward)


## Kapat: KAPAT/X/karartma/Android geri (main.gd) aynı yol. Ödül vermez,
## reveal sürüyorsa keser (ödül zaten kayıtta).
func close_popup() -> void:
	if not visible:
		return
	visible = false
	_pending_kind = ""
	_free_sent = false
	_end_reveal(false)
	AudioManager.play(&"ui_modal_close")
	closed.emit()


func is_request_pending() -> bool:
	return _pending_kind != ""


func pending_kind() -> String:
	return _pending_kind


func is_auto_opened() -> bool:
	return _auto_opened


## Giriş ödülü bölgesi (yalnız görünüm; Main claim sonucunu verir).
func set_login(login: Dictionary) -> void:
	_apply_login(login)
	UiKit.modal_relayout(_frame)


# --- Butonlar ------------------------------------------------------------------------

func _on_free_pressed() -> void:
	if _free_sent or _free.disabled or _revealing:
		return
	# Tek sinyal: Main cevaplayana (reveal ya da refresh) kadar ikinci basış yok.
	_free_sent = true
	_free.disabled = true
	free_chest_requested.emit()


func _on_dough_pressed() -> void:
	if _pending_kind != "" or _dough.disabled or _revealing:
		return
	_pending_kind = "daily_dough"
	_note.text = ""
	_note.visible = false
	refresh(_provider_ready, _provider_note)
	ad_dough_requested.emit()


func _on_chest_pressed() -> void:
	if _pending_kind != "" or _chest.disabled or _revealing:
		return
	_pending_kind = "daily_chest"
	_note.text = ""
	_note.visible = false
	refresh(_provider_ready, _provider_note)
	ad_chest_requested.emit()


func _on_continue_pressed() -> void:
	if not _revealing:
		return
	_end_reveal(true)


# --- Reveal ---------------------------------------------------------------------------

func _start_reveal(reward: DailyChestReward) -> void:
	_end_reveal(false)
	_revealing = true
	_cards_host.visible = false
	_close.visible = false
	_continue.visible = true
	_continue.disabled = true
	_reveal_title.text = REVEAL_TITLE_AD if reward.source == "ad" else REVEAL_TITLE_FREE
	_reveal_dough.text = REVEAL_DOUGH % reward.dough()
	_reveal_dough.modulate.a = 0.0
	_reveal_note.visible = false
	_reveal_note.modulate.a = 0.0
	if reward.skin_exhausted and reward.rarity >= 0:
		_reveal_note.text = REVEAL_BONUS_NOTE % SkinData.rarity_display_name(reward.rarity as SkinData.Rarity)
		_reveal_note.visible = true
	# Sandık: efekt kademesi skin varsa onun rarity'si (Legendary altın an).
	var gem_view := ChestReward.new()
	gem_view.rarity = reward.fx_rarity() as SkinData.Rarity
	_gem = REWARD_GEM.new()
	_gem.name = "Gem"
	_gem.setup(gem_view, GEM_SIZE)
	_gem.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_gem.offset_left = -GEM_SIZE * 0.5
	_gem.offset_right = GEM_SIZE * 0.5
	_gem.offset_top = -GEM_SIZE * 0.5 - 6.0
	_gem.offset_bottom = GEM_SIZE * 0.5 - 6.0
	_gem.pivot_offset = Vector2(GEM_SIZE, GEM_SIZE) * 0.5
	_gem.scale = Vector2(0.6, 0.6)
	_gem.modulate.a = 0.0
	_gem_host.add_child(_gem)
	_reveal_skin_host.visible = false
	_reveal_skin_caption.modulate.a = 0.0
	if reward.has_skin():
		_skin_card = ResultRewardCard.create(reward.as_skin_chest_reward())
		_skin_card.name = "SkinCard"
		_skin_card.hide_note()
		_reveal_skin_margin.add_child(_skin_card)
		_reveal_skin_host.visible = true
	_reveal_host.visible = true
	UiKit.modal_relayout(_frame)
	AudioManager.play(&"ui_modal_open")

	_reveal_tween = create_tween()
	_reveal_tween.set_parallel(true)
	_reveal_tween.tween_property(_gem, "modulate:a", 1.0, 0.18)
	_reveal_tween.tween_property(_gem, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reveal_tween.chain().tween_interval(maxf(REVEAL_OPEN_DELAY - 0.26, 0.0))
	_reveal_tween.chain().tween_callback(_open_gem)
	_reveal_tween.chain().tween_interval(REVEAL_DOUGH_DELAY - REVEAL_OPEN_DELAY)
	_reveal_tween.chain().tween_callback(_show_dough)
	if reward.has_skin():
		_reveal_tween.chain().tween_interval(REVEAL_SKIN_DELAY - REVEAL_DOUGH_DELAY)
		_reveal_tween.chain().tween_callback(_show_skin)
		_reveal_tween.chain().tween_interval(REVEAL_CONTINUE_DELAY - REVEAL_SKIN_DELAY)
	else:
		_reveal_tween.chain().tween_interval(REVEAL_CONTINUE_DELAY - REVEAL_DOUGH_DELAY)
	_reveal_tween.chain().tween_callback(_enable_continue)


## Sandık açılır: iki aşamalı ses (round sonuyla aynı eşleme, M8.5-15):
## `chest_open` beklenti, ardından Hamur satırında rarity cue'su.
func _open_gem() -> void:
	if _gem != null and is_instance_valid(_gem):
		_gem.open()
	AudioManager.play(&"chest_open")


func _show_dough() -> void:
	var t: Tween = create_tween()
	t.tween_property(_reveal_dough, "modulate:a", 1.0, 0.18)
	UiMotion.pop(_reveal_dough, 1.08)
	if _reveal_note.visible:
		var n: Tween = create_tween()
		n.tween_property(_reveal_note, "modulate:a", 1.0, 0.2)
	# Skin yoksa ödül cue'su + hafif titreşim burada (Hamur = Common kademe).
	if _reward == null or not _reward.has_skin():
		AudioManager.play_reward(int(SkinData.Rarity.COMMON))
		Haptics.light()


func _show_skin() -> void:
	if _skin_card == null or not is_instance_valid(_skin_card):
		return
	_skin_card.appear()
	var t: Tween = create_tween()
	t.tween_interval(ResultRewardCard.APPEAR_TIME)
	t.tween_callback(func() -> void:
		if _skin_card != null and is_instance_valid(_skin_card):
			_skin_card.open())
	t.tween_property(_reveal_skin_caption, "modulate:a", 1.0, 0.2)
	var rarity: int = _reward.rarity if _reward != null else int(SkinData.Rarity.COMMON)
	AudioManager.play_reward(rarity)
	match rarity:
		SkinData.Rarity.LEGENDARY:
			Haptics.special()
		_:
			Haptics.medium()


func _enable_continue() -> void:
	if not _revealing:
		return
	_continue.disabled = false
	if _gem != null and is_instance_valid(_gem):
		_gem.settle()
	if _skin_card != null and is_instance_valid(_skin_card):
		_skin_card.settle()


## Reveal biter; kartlara dönülür (tazelenir). `back_to_cards` false: pencere
## kapanıyor, yalnız temizlik.
func _end_reveal(back_to_cards: bool) -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null
	_revealing = false
	if _gem != null and is_instance_valid(_gem):
		_gem.queue_free()
	_gem = null
	if _skin_card != null and is_instance_valid(_skin_card):
		_skin_card.kill_tweens()
		_skin_card.queue_free()
	_skin_card = null
	_reveal_host.visible = false
	_reveal_skin_host.visible = false
	_cards_host.visible = true
	_continue.visible = false
	_close.visible = true
	if back_to_cards:
		refresh(_provider_ready, _provider_note)
		UiKit.modal_relayout(_frame)
		AudioManager.play(&"ui_tap")


# --- Testler / araçlar ----------------------------------------------------------------

func frame() -> Control:
	return _frame


func free_button() -> Button:
	return _free


func dough_button() -> Button:
	return _dough


func chest_button() -> Button:
	return _chest


func continue_button() -> Button:
	return _continue


func close_button() -> Button:
	return _close


func free_status_text() -> String:
	return _free_status_label.text


func dough_status_text() -> String:
	return _dough_status_label.text


func chest_status_text() -> String:
	return _chest_status_label.text


func dough_note_text() -> String:
	return _dough_note.text if _dough_note.visible else ""


func chest_note_text() -> String:
	return _chest_note.text if _chest_note.visible else ""


func note_text() -> String:
	return _note.text if _note.visible else ""


func is_revealing() -> bool:
	return _revealing


func reveal_dough_text() -> String:
	return _reveal_dough.text


func reveal_note_text() -> String:
	return _reveal_note.text if _reveal_note.visible else ""


func reveal_skin_card() -> ResultRewardCard:
	return _skin_card


func gem() -> Control:
	return _gem


func cards_host() -> Control:
	return _cards_host


func login_day_text() -> String:
	return _login_day_label.text


func login_reward_text() -> String:
	return _login_reward.text


func login_chip_text() -> String:
	return _login_chip_label.text


func login_note_text() -> String:
	return _login_note.text if _login_note.visible else ""


func strip() -> StreakStrip:
	return _strip


func skin_card_margin() -> MarginContainer:
	return _reveal_skin_margin


func skin_caption() -> Label:
	return _reveal_skin_caption
