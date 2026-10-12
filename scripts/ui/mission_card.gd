class_name MissionCard
extends Control
## Görev kartı (TASK/046 → TASK/061 V3) — GÜNLÜK ÖDÜLLER seçenek kartının malzemesi (bir ton geri krem
## `card_bevel_soft` gövde) + gövdeyi çevreleyen 3 px durum halkası. Solda metrik kuyusu (`candy_well`: merge → owner
## dumpling'i · tur → oyna pictosu · level → owner bayrağı), ortada görev metni (Baloo) + ilerleme rayı + "7 / 15",
## sağda SABİT genişlikte ödül yuvası — ödül üç durumda da AYNI yerde görünür:
##
##   AKTİF       krem gövde, lavanta halka, nane ray kısmi; yuvada pasif ödül kutusu (owner Hamur sanatı + "+10"),
##               buton YOK (kutu dokunma almaz — basılabilir görünmez: düz, gömük).
##   ALINABİLİR  açık altın gövde + altın halka, ray dolu, sayaç + nane tik; yuvada nane candy CTA "ÖDÜLÜ AL" + altında
##               Hamur sanatı "+10" (SquishyButton REWARD / COMPACT — dokunma alanı TOUCH_TARGET 84 px = A36'da 48 dp).
##   ALINDI      açık nane gövde + nane halka, ray dolu, sayaç + nane tik; yuvada düz "✓ ALINDI" (SquishyButton
##               CLAIMED, pasif). Durumlar yalnız renkle değil: metin (ÖDÜLÜ AL / ALINDI) + ikon (tik) + ilerleme.
## Sayaç sabit genişlikte sağa yaslı ve ödül yuvası sabit genişlikte: altı kartın rayları her durumda aynı boyda hizalanır.
##
## Yapı: kök düz Control → halka (kökün tam dikdörtgeni) → gövde PanelContainer (her yandan RING_WIDTH içeride). Halka
## gövdenin çocuğu OLAMAZ (PanelContainer çocuklarını içerik payına oturtur, opak gövdenin altında kalırdı) ve kökün
## DIŞINA taşamaz (pencere gövdesi bir ScrollContainer: taşan yan kenarlar kırpılırdı). Kök yüksekliği gövdenin
## içeriğini izler.
##
## Veri yalnız `Missions.rows()` satırından; kayda YAZMAZ. Kartın kendisi dokunma ALMAZ (kaydırma kartın üstünden de
## başlar); tek dokunma hedefi CTA'dır: kaydırılan içerikte PASS (`set_scrollable`) — kaydırma başlayınca basış iptal,
## talep YOK; eylem `GestureGuard.on_pressed` (TASK/055: ACTION_CANCEL / gizlenme / odak kaybı eylemsiz). CTA yalnız
## `claim_pressed(id, period_key)` yayar — ödülü SaveManager verir (Main → claim_mission_reward).

signal claim_pressed(id: StringName, period_key: String)

const BODY_MARGIN: Vector4 = Vector4(16, 12, 14, 14)
const WELL_SIZE: float = 56.0
const WELL_ART: float = 38.0
const MIN_HEIGHT: float = 100.0
## "120 / 120" sığar; bütün kartlarda aynı → raylar hizalı.
const PROGRESS_WIDTH: float = 84.0
const RING_WIDTH: float = 3.0
## Ödül yuvası: üç durumda aynı genişlik (raylar hizalı), CTA görsel boyu TOUCH_COMPACT.
const SLOT_WIDTH: float = 156.0
const SLOT_HEIGHT: float = float(UiTokens.TOUCH_COMPACT)
const RING_OPEN: Color = Color("dccbe8")
## Alınabilir kartın gövdesi: krem → hafif altın (ödül bekliyor; liste içinde seçilir, bağırmaz).
const BODY_CLAIMABLE: Color = Color("fff1cf")
## Alınmış kartın gövdesi: krem → hafif nane (başarı, sakin).
const BODY_CLAIMED: Color = Color("e3f5e6")
const CLAIM_TEXT: String = "ÖDÜLÜ AL"
const PROGRESS_FORMAT: String = "%d / %d"
const REWARD_FORMAT: String = "+%d"
const DOUGH_ART: Texture2D = preload("res://assets/visual/ui/icon_dough.png")
const MERGE_ART: Texture2D = preload("res://assets/visual/dumpling_tier3.png")
const CLEAR_ART: Texture2D = preload("res://assets/visual/ui/icon_flag.png")


## ÖDÜLÜ AL düğmesi: V3 REWARD CTA (SquishyButton — görsel / basış / durum makinesi aynen), iki satır içerik ("ÖDÜLÜ AL"
## + Hamur "+10") ve görsel boyundan büyük dokunma alanı: kompakt görsel (64) dikeyde TOUCH_TARGET'a (84 = A36'da 48 dp)
## tamamlanır, yanlara HIT_PAD_X — alan kartın içinde kalır (komşu karta / başka kontrole taşmaz).
class ClaimButton extends SquishyButton:
	const HIT_PAD_X: float = 8.0

	var _content: VBoxContainer
	var _caption: Label
	var _amount: Label

	func _init() -> void:
		super("", SquishyButton.Kind.REWARD, SquishyButton.SizeClass.COMPACT)
		name = "ClaimButton"
		set_scrollable(true)
		_content = VBoxContainer.new()
		_content.name = "Content"
		_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.alignment = BoxContainer.ALIGNMENT_CENTER
		_content.add_theme_constant_override("separation", -4)
		row().add_child(_content)
		_caption = UiType.v3_label(CLAIM_TEXT, UiType.V3_BUTTON, false, HORIZONTAL_ALIGNMENT_CENTER, 19)
		_caption.name = "Caption"
		_caption.add_theme_color_override("font_color", UiTokens.TEXT_ON_ACCENT)
		_content.add_child(_caption)
		var amount_row := HBoxContainer.new()
		amount_row.name = "Amount"
		amount_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		amount_row.alignment = BoxContainer.ALIGNMENT_CENTER
		amount_row.add_theme_constant_override("separation", 3)
		_content.add_child(amount_row)
		var coin := UiKit.art(DOUGH_ART, 22.0)
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		amount_row.add_child(coin)
		_amount = UiType.v3_label("", UiType.V3_BUTTON, false, HORIZONTAL_ALIGNMENT_CENTER, 19)
		_amount.name = "AmountLabel"
		_amount.add_theme_color_override("font_color", UiTokens.TEXT_ON_ACCENT)
		amount_row.add_child(_amount)
		set_state(SquishyButton.State.NORMAL)

	func set_amount(value: int) -> void:
		_amount.text = REWARD_FORMAT % value
		set_state(state())

	## ALINDI'da başlık "ALINDI" + tik (SquishyButton); iki satırlık içerik gizlenir.
	func set_state(value: int, reason: String = "") -> void:
		if _content != null:
			_content.visible = value != SquishyButton.State.CLAIMED
		super(value, reason)

	func caption_text() -> String:
		return _caption.text if _content.visible else ""

	func amount_text() -> String:
		return _amount.text if _content.visible else ""

	## Görselden büyük dokunma alanı (TOUCH_TARGET yüksekliği, yanlarda HIT_PAD_X).
	func hit_rect() -> Rect2:
		var pad_y: float = maxf((float(UiTokens.TOUCH_TARGET) - size.y) * 0.5, 0.0)
		return Rect2(Vector2(-HIT_PAD_X, -pad_y), size + Vector2(HIT_PAD_X * 2.0, pad_y * 2.0))

	func _has_point(point: Vector2) -> bool:
		return hit_rect().has_point(point)


var _ring: PanelContainer
var _panel: PanelContainer
var _body_active: StyleBoxTexture
var _body_claimable: StyleBoxTexture
var _body_claimed: StyleBoxTexture
var _well_host: Control
var _well: Control
var _title: Label
var _rail: ProgressBar
var _check: TextureRect
var _progress: Label
var _slot: Control
var _reward_box: PanelContainer
var _reward: Label
var _claim: ClaimButton
var _row: Dictionary = {}
var _status: StringName = Missions.STATUS_ACTIVE


func _init() -> void:
	name = "MissionCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, MIN_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_active = UiKit.style("card_bevel_soft", UiTokens.CREAM_DEEP, BODY_MARGIN)
	_body_claimable = UiKit.style("card_bevel_soft", BODY_CLAIMABLE, BODY_MARGIN)
	_body_claimed = UiKit.style("card_bevel_soft", BODY_CLAIMED, BODY_MARGIN)
	_ring = UiKit.flat_plate("frame_round20", Color.WHITE)
	_ring.name = "Ring"
	_ring.self_modulate = RING_OPEN
	add_child(_ring)
	_panel = PanelContainer.new()
	_panel.name = "Body"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.inset(_panel, RING_WIDTH, RING_WIDTH, RING_WIDTH, RING_WIDTH)
	_panel.add_theme_stylebox_override("panel", _body_active)
	add_child(_panel)
	_panel.minimum_size_changed.connect(func() -> void:
		custom_minimum_size.y = maxf(MIN_HEIGHT, _panel.get_combined_minimum_size().y + RING_WIDTH * 2.0))
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiTokens.SPACE_MD)
	_panel.add_child(row)
	_well_host = Control.new()
	_well_host.name = "WellHost"
	_well_host.custom_minimum_size = Vector2(WELL_SIZE + 8.0, WELL_SIZE + 10.0)
	_well_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_well_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_well_host)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_title = UiKit.label("", &"LabelSection")
	_title.name = "Title"
	_title.add_theme_font_size_override("font_size", 20)
	# Uzun metin kartı taşırmaz (tek satır, üç nokta); katalog metinleri sığar.
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_title)
	var bar_row := HBoxContainer.new()
	bar_row.name = "ProgressRow"
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_theme_constant_override("separation", 8)
	column.add_child(bar_row)
	_rail = UiKit.progress_bar(0.0, &"ProgressBarMint", 14.0)
	_rail.name = "Rail"
	_rail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(_rail)
	# Sayaç: tamamlanınca nane tik (tik genişliği hep ayrılmış — raylar kaymaz); sayı birincil erik (okunurluk).
	var count := HBoxContainer.new()
	count.name = "Count"
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.alignment = BoxContainer.ALIGNMENT_END
	count.add_theme_constant_override("separation", 2)
	count.custom_minimum_size = Vector2(PROGRESS_WIDTH, 0)
	bar_row.add_child(count)
	_check = UiKit.icon("check", 18, UiTokens.MINT_DEEP)
	_check.name = "Check"
	_check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	count.add_child(_check)
	_progress = UiKit.label("", &"LabelStat", HORIZONTAL_ALIGNMENT_RIGHT)
	_progress.name = "Progress"
	_progress.add_theme_font_size_override("font_size", 16)
	count.add_child(_progress)
	# Ödül yuvası (sabit): pasif ödül kutusu YA DA CTA (alınabilir / alındı).
	_slot = Control.new()
	_slot.name = "RewardSlot"
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.custom_minimum_size = Vector2(SLOT_WIDTH, SLOT_HEIGHT)
	_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_slot)
	_reward_box = PanelContainer.new()
	_reward_box.name = "RewardBox"
	_reward_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Düz pasif kutu (basılabilir CTA'dan ayrı dil): krem yüz + 2 px lavanta kenar, gölge / dudak / gloss YOK. Krem yüz
	# altın "+10"un okunurluğunu korur (koyu krem / lavanta-gri zeminde ~2,7:1 kalıyordu — kremde ~3,6:1, büyük yazı).
	_reward_box.add_theme_stylebox_override("panel", UiKit.v3_box(UiTokens.CREAM, 14.0, UiTokens.LAVENDER_SURFACE, 2))
	_slot.add_child(_reward_box)
	var reward := HBoxContainer.new()
	reward.name = "Reward"
	reward.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward.alignment = BoxContainer.ALIGNMENT_CENTER
	reward.add_theme_constant_override("separation", 4)
	_reward_box.add_child(reward)
	var coin := UiKit.art(DOUGH_ART, 34.0)
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reward.add_child(coin)
	_reward = UiKit.label("", &"LabelPrice")
	_reward.name = "RewardLabel"
	_reward.add_theme_font_size_override("font_size", 22)
	_reward.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reward.add_child(_reward)
	_claim = ClaimButton.new()
	_claim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_claim.visible = false
	_slot.add_child(_claim)
	GestureGuard.on_pressed(_claim, _on_claim_pressed)


## `row`: Missions.rows() satırı.
func setup(row: Dictionary) -> void:
	_row = row
	if row.is_empty():
		visible = false
		return
	visible = true
	name = "Mission_%s" % String(row["id"])
	var goal: int = maxi(int(row["target"]), 1)
	var value: int = clampi(int(row["progress"]), 0, goal)
	_status = row.get("status", Missions.STATUS_ACTIVE)
	var claimable: bool = _status == Missions.STATUS_CLAIMABLE
	var claimed: bool = _status == Missions.STATUS_CLAIMED
	var done: bool = claimable or claimed
	_set_well(row.get("metric", &""))
	_title.text = String(row["title"])
	_panel.add_theme_stylebox_override("panel", _body_claimable if claimable else (_body_claimed if claimed
		else _body_active))
	_ring.self_modulate = UiTokens.GOLD if claimable else (UiTokens.MINT if claimed else RING_OPEN)
	_rail.value = float(value) / float(goal)
	_progress.text = PROGRESS_FORMAT % [value, goal]
	# Sayı her durumda birincil erik (16 px küçük yazı: nane koyu açık zeminde ~3:1 kalıyordu); "tamam" anlamı nane tik.
	_progress.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	_check.modulate.a = 1.0 if done else 0.0
	_reward.text = REWARD_FORMAT % int(row["reward"])
	_reward_box.visible = not done
	_claim.visible = done
	_claim.set_amount(int(row["reward"]))
	_claim.set_state(SquishyButton.State.CLAIMED if claimed else SquishyButton.State.NORMAL)


## Başarılı talep geri bildirimi (çağıran sonucu doğruladıktan sonra): kart candy pop'u.
func play_claimed() -> void:
	UiMotion.pop(self, 1.05)


func _on_claim_pressed() -> void:
	if _status != Missions.STATUS_CLAIMABLE or _row.is_empty():
		return
	claim_pressed.emit(_row["id"], String(_row.get("period_key", "")))


## Metrik kuyusu (kart yeniden kurulmaz; metrik değişirse kuyu yenilenir).
func _set_well(metric: StringName) -> void:
	if _well != null and _well.get_meta(&"metric", &"") == metric:
		return
	if _well != null:
		_well.queue_free()
	var art: Texture2D = MERGE_ART
	var accent: Color = UiTokens.PINK
	match metric:
		Missions.METRIC_ROUNDS:
			art = UiKit.icon_texture("play")
			accent = UiTokens.CYAN
		Missions.METRIC_CLEARS:
			art = CLEAR_ART
			accent = UiTokens.GOLD
	_well = UiKit.candy_well(art, accent, WELL_SIZE, WELL_ART)
	_well.name = "Well"
	_well.set_meta(&"metric", metric)
	_well.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_well.offset_left = -WELL_SIZE * 0.5
	_well.offset_right = WELL_SIZE * 0.5
	_well.offset_top = -(WELL_SIZE + 6.0) * 0.5
	_well.offset_bottom = (WELL_SIZE + 6.0) * 0.5
	_well_host.add_child(_well)


# --- Testler / çekim aracı ----------------------------------------------------

func row() -> Dictionary:
	return _row


func mission_id() -> StringName:
	return _row.get("id", &"")


func status() -> StringName:
	return _status


func title_text() -> String:
	return _title.text


func progress_text() -> String:
	return _progress.text


## Ödül miktarı (her durumda görünen yuvadan: kutu, CTA ya da — ALINDI'da — kayıttaki satır).
func reward_text() -> String:
	if _reward_box.visible:
		return _reward.text
	return _claim.amount_text() if not _claim.amount_text().is_empty() else REWARD_FORMAT % int(_row.get("reward", 0))


## Tamamlanma göstergesi (tik) görünür mü — alınabilir ya da alınmış.
func is_done_shown() -> bool:
	return _check.modulate.a > 0.5


## CTA'nın görünen metni: "ÖDÜLÜ AL" (alınabilir), "ALINDI" (alınmış), aktifte boş.
func cta_text() -> String:
	if not _claim.visible:
		return ""
	return SquishyButton.CLAIMED_TEXT if _claim.state() == SquishyButton.State.CLAIMED else _claim.caption_text()


func claim_button() -> ClaimButton:
	return _claim


func reward_box() -> PanelContainer:
	return _reward_box


func reward_slot() -> Control:
	return _slot


func rail() -> ProgressBar:
	return _rail


func title_label() -> Label:
	return _title


func check_icon() -> TextureRect:
	return _check


func ring() -> PanelContainer:
	return _ring


func body() -> PanelContainer:
	return _panel
