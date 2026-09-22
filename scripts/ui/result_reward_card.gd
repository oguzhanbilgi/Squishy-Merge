class_name ResultRewardCard
extends Control
## Round sonu ödül kartı (M8.6-09). Sandık ödülü / skin ödülü / geri düşüş
## Hamur'u / teselli ödülü TEK bileşenden; Mağaza-Koleksiyon kartlarıyla aynı
## malzeme ailesi (krem `card_bevel_soft` gövde, açık halka, erik gölge, kart
## yüzü), yatay satır (528 × 128): solda sahne, sağda yazı sütunu.
##
## Sahne (116 px): rarity renginde düşük alfa hale → `RewardGem` (owner
## sandığı, kapalı → açık + kalibre rarity katmanları, 88 px). Skin
## ödülünde kart daha yüksek (176), sandık açıldıktan sonra sönerek küçülür ve
## yerine GERÇEK final skin sanatı (`SkinSwatch` 140 px, krem kaide) pop'lar —
## skin kartın kahramanı; altında "Koleksiyon'a eklendi".
## Teselli ödülünde sandık YOK (o bir sandık değil): lavanta kuyuda owner
## Hamur sanatı.
##
## Yazı sütunu (açılışa kadar görünmez): rarity etiketi Türkçe (YAYGIN /
## NADİR / EPİK / EFSANEVİ — `UiKit.rarity_tag`; teselli için lavanta
## "TESELLİ") → ana satır: "+25 HAMUR" (Hamur ikonu + koyu altın) ya da
## skin adı (Baloo) + pembe "YENİ SKİN" rozeti → not: geri düşüşte
## "Epik skinlerin tamamı sende" (iç terim yok, skin verildi denmez).
##
## Legendary: altın halka + sıcak altın-krem gövde + altın hale + 3 pırıltı
## (oyundaki tek altın anı). Kart dokunma hedefi DEĞİL (`MOUSE_FILTER_IGNORE`):
## bir eylemi yok; sürükleme doğrudan ScrollContainer'a gider. Kayda
## DOKUNMAZ: ödül kanonik yolda (`ChestSystem`) zaten yazılmış gelir.
##
## Akış (sahibi `RoundResult`): `appear()` kart belirir (kapalı sandık) →
## `open()` sandık açılır, içerik belirir → `settle()` sürekli efektler
## durur (Legendary yavaş ışın dönüşü hariç).

const REWARD_GEM := preload("res://scripts/ui/reward_gem.gd")
const DOUGH_ART: Texture2D = preload("res://assets/visual/ui/icon_dough.png")
const SPARKLE_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")

const CARD_HEIGHT: float = 128.0
## Skin kartı daha yüksek: skin kartın KAHRAMANI (brief §16) — sanat 140 px,
## krem kaide, büyük ad; Hamur kartı kompakt kalır.
const SKIN_CARD_HEIGHT: float = 176.0
const BODY_MARGIN: Vector4 = Vector4(14, 8, 18, 18)
const STAGE_SIZE: float = 116.0
const SKIN_STAGE_SIZE: float = 160.0
const GEM_SIZE: float = 88.0
const SKIN_SIZE: float = 140.0
const SKIN_WELL_SIZE: float = 122.0
const SKIN_GLOW_SIZE: float = 230.0
const CONSOLATION_WELL: float = 84.0
const CONSOLATION_ART: float = 60.0
const GLOW_SIZE: float = 168.0
const GLOW_ALPHA: Dictionary = {
	SkinData.Rarity.COMMON: 0.12, SkinData.Rarity.RARE: 0.18,
	SkinData.Rarity.EPIC: 0.22, SkinData.Rarity.LEGENDARY: 0.30,
}
## Legendary gövde: krem → parlak altın %14 (Mağaza / Koleksiyon ile aynı dil).
const LEGENDARY_BODY_MIX: float = 0.14
const AMOUNT_FONT_SIZE: int = 30
const NAME_FONT_SIZE: int = 30
const NEW_SKIN_TEXT: String = "YENİ SKİN"
const SKIN_NOTE_TEXT: String = "Koleksiyon'a eklendi"
const CONSOLATION_TEXT: String = "TESELLİ"
## Hareket süreleri.
const APPEAR_TIME: float = 0.26
const CONTENT_TIME: float = 0.22
const SKIN_SWAP_DELAY: float = 0.24
const SKIN_POP_TIME: float = 0.28
## Legendary pırıltıları (kart uzayı, sol üst / sağ üst / sağ alt).
const LEGENDARY_SPARKLES: Array = [
	[Vector2(14.0, 14.0), 18.0, 0.0],
	[Vector2(500.0, 18.0), 14.0, 1.9],
	[Vector2(492.0, 104.0), 18.0, 3.7],
]

var _reward: ChestReward
var _rim: PanelContainer
var _body: PanelContainer
var _halo: NinePatchRect
var _glow: NinePatchRect
var _stage: Control
var _gem: Control
var _swatch: SkinSwatch
var _consolation_well: Control
var _text: VBoxContainer
var _tag: PanelContainer
var _amount: Label
var _name_label: Label
var _new_badge: PanelContainer
var _note: Label
var _sparkles: Array[TextureRect] = []
var _opened: bool = false
var _tweens: Array[Tween] = []


static func create(reward: ChestReward) -> ResultRewardCard:
	var card := ResultRewardCard.new()
	card.setup(reward)
	return card


func _init() -> void:
	name = "RewardCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, CARD_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Katmanlar (arkadan öne): Legendary hale → erik gölge → halka → gövde
	# (+ kart yüzü) → satır.
	_halo = UiKit.patch("popup_glow", Color(UiTokens.GOLD_BRIGHT, 0.0))
	UiKit.inset(_halo, -30.0, -26.0, -30.0, -34.0)
	_halo.visible = false
	add_child(_halo)
	var shadow := UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.26))
	UiKit.inset(shadow, -12.0, -2.0, -12.0, -18.0)
	add_child(shadow)
	_rim = UiKit.flat_plate("frame_round20", UiTokens.LAVENDER_LIGHT)
	UiKit.inset(_rim, -3.0, -3.0, -3.0, -3.0)
	add_child(_rim)
	_body = UiKit.panel(&"PanelCard")
	_body.name = "Body"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.add_theme_stylebox_override("panel",
		UiKit.style("card_bevel_soft", UiTokens.TRAY_CREAM, BODY_MARGIN))
	# Sandığın ışın/parıltı katmanları (gem'in 2.2 katı) kartın İÇİNDE
	# kalır; halka / gölge / Legendary hale kökte, kırpılmaz.
	_body.clip_contents = true
	add_child(_body)
	UiKit.card_face(_body, BODY_MARGIN)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	_body.add_child(row)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.custom_minimum_size = Vector2(STAGE_SIZE, 0)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_stage)
	_glow = UiKit.patch("popup_glow", Color(UiTokens.LAVENDER, 0.0))
	_center(_glow, GLOW_SIZE, 2.0)
	_stage.add_child(_glow)

	_text = VBoxContainer.new()
	_text.name = "Text"
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.alignment = BoxContainer.ALIGNMENT_CENTER
	_text.add_theme_constant_override("separation", 2)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.modulate.a = 0.0
	row.add_child(_text)

	for spec in LEGENDARY_SPARKLES:
		var spark := UiKit.art(SPARKLE_ART, float(spec[1]))
		spark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		spark.position = (spec[0] as Vector2) - Vector2(float(spec[1]), float(spec[1])) * 0.5
		spark.size = Vector2(float(spec[1]), float(spec[1]))
		spark.pivot_offset = spark.size * 0.5
		spark.visible = false
		add_child(spark)
		_sparkles.append(spark)
	modulate.a = 0.0


func setup(reward: ChestReward) -> void:
	_reward = reward
	var rarity: int = int(reward.rarity)
	var accent: Color = reward.color()
	name = "RewardCard_%s" % ("consolation" if reward.is_consolation else SkinData.rarity_name(reward.rarity))

	# --- Gövde / halka / hale: rarity dili (Koleksiyon kartıyla aynı kalibrasyon).
	var body_tint: Color = UiTokens.TRAY_CREAM
	var glow_tint: Color = UiTokens.LAVENDER
	if reward.is_consolation:
		_rim.self_modulate = UiTokens.LAVENDER_SURFACE
		body_tint = UiTokens.CREAM_DEEP
		_glow.self_modulate = Color(UiTokens.LAVENDER, 0.10)
	else:
		match rarity:
			SkinData.Rarity.RARE:
				_rim.self_modulate = accent.lerp(Color.WHITE, 0.25)
				glow_tint = accent
			SkinData.Rarity.EPIC:
				_rim.self_modulate = accent.lerp(Color.WHITE, 0.22)
				glow_tint = accent
			SkinData.Rarity.LEGENDARY:
				_rim.self_modulate = UiTokens.GOLD
				_halo.self_modulate = Color(UiTokens.GOLD_BRIGHT, 0.5)
				_halo.visible = true
				body_tint = UiTokens.CREAM.lerp(UiTokens.GOLD_BRIGHT, LEGENDARY_BODY_MIX)
				glow_tint = UiTokens.GOLD
			_:
				_rim.self_modulate = UiTokens.rarity_tint(rarity).lerp(Color.WHITE, 0.45)
				glow_tint = UiTokens.LAVENDER
		_glow.self_modulate = Color(glow_tint, float(GLOW_ALPHA.get(rarity, 0.12)))
	_body.add_theme_stylebox_override("panel", UiKit.style("card_bevel_soft", body_tint, BODY_MARGIN))
	for spark in _sparkles:
		spark.visible = rarity == SkinData.Rarity.LEGENDARY and not reward.is_consolation
	if reward.is_skin_reward():
		# Yüksek kartta alt-sağ pırıltı alt kenara yakın kalsın.
		_sparkles[2].position.y = SKIN_CARD_HEIGHT - 24.0 - _sparkles[2].size.y * 0.5

	# --- Sahne: sandık (ödül) ya da Hamur kuyusu (teselli).
	if reward.is_consolation:
		_consolation_well = UiKit.candy_well(DOUGH_ART, UiTokens.LAVENDER, CONSOLATION_WELL, CONSOLATION_ART)
		_consolation_well.name = "ConsolationWell"
		_center(_consolation_well, CONSOLATION_WELL, 0.0)
		_consolation_well.offset_bottom += 6.0
		_stage.add_child(_consolation_well)
	else:
		if reward.is_skin_reward():
			# Kahraman kart: daha yüksek gövde, geniş sahne, krem kaide + geniş hale.
			custom_minimum_size.y = SKIN_CARD_HEIGHT
			_stage.custom_minimum_size.x = SKIN_STAGE_SIZE
			_center(_glow, SKIN_GLOW_SIZE, 0.0)
			var well := UiKit.patch("item_circle_inner", UiTokens.TRAY_CREAM)
			well.name = "SkinWell"
			_center(well, SKIN_WELL_SIZE, 8.0)
			_stage.add_child(well)
			var well_shade := UiKit.patch("item_circle_inner", Color(0.35, 0.25, 0.5, 0.10))
			_center(well_shade, SKIN_WELL_SIZE - 8.0, 14.0)
			_stage.add_child(well_shade)
		_gem = REWARD_GEM.new()
		_gem.name = "Gem"
		_gem.setup(reward, GEM_SIZE)
		_center(_gem, GEM_SIZE, 4.0)
		_gem.pivot_offset = Vector2(GEM_SIZE, GEM_SIZE) * 0.5
		_stage.add_child(_gem)
		if reward.is_skin_reward():
			_swatch = SkinSwatch.new()
			_swatch.name = "SkinPreview"
			var entry: SkinEntry = SkinEntry.for_skin(reward.skin)
			# Kart ödülü SUNAR: skin kanonik yolda zaten verildi; vitrin her
			# zaman "senin" görünümü (kilit/buz yok) — harness'ta verilmemiş
			# olsa da kart yalan söylemez, yalnızca sanatı gösterir.
			entry.owned = true
			entry.equipped = false
			_swatch.setup(entry)
			_center(_swatch, SKIN_SIZE, 2.0)
			_swatch.pivot_offset = Vector2(SKIN_SIZE, SKIN_SIZE) * 0.5
			# Görünür ama saydam: gizli Control ilk yerleşimde `resized`
			# almıyor (SkinSwatch katmanları 0 boyutta kalıyordu — v1 çekimi).
			_swatch.modulate.a = 0.0
			_stage.add_child(_swatch)

	# --- Yazı sütunu.
	if reward.is_consolation:
		_tag = _plain_tag(CONSOLATION_TEXT, UiTokens.LAVENDER_DEEP)
	else:
		_tag = UiKit.rarity_tag(rarity)
	_tag.name = "Tag"
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_child(_tag)
	if reward.is_skin_reward():
		_name_label = UiKit.label(reward.skin.display_name, &"LabelSection")
		_name_label.name = "SkinName"
		_name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
		_name_label.clip_text = true
		_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_text.add_child(_name_label)
		var badge_row := HBoxContainer.new()
		badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_row.add_theme_constant_override("separation", 10)
		_text.add_child(badge_row)
		_new_badge = UiKit.badge(NEW_SKIN_TEXT, &"NewBadge")
		_new_badge.name = "NewSkinBadge"
		_new_badge.add_theme_stylebox_override("panel",
			UiKit.style("badge_round", UiTokens.PINK, Vector4(14, 4, 14, 6)))
		var badge_label: Label = _new_badge.get_child(0).get_child(0)
		badge_label.add_theme_font_size_override("font_size", 17)
		badge_row.add_child(_new_badge)
		_note = UiKit.label(SKIN_NOTE_TEXT, &"LabelCaption")
		_note.name = "Note"
		_note.add_theme_color_override("font_color", UiTokens.TEXT_TERTIARY)
		_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge_row.add_child(_note)
	else:
		var amount_row := HBoxContainer.new()
		amount_row.name = "AmountRow"
		amount_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		amount_row.add_theme_constant_override("separation", 8)
		_text.add_child(amount_row)
		var dough_icon := UiKit.art(DOUGH_ART, 34.0)
		dough_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		dough_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		amount_row.add_child(dough_icon)
		_amount = UiKit.label("+%d HAMUR" % reward.dough, &"LabelPrice")
		_amount.name = "Amount"
		_amount.add_theme_font_size_override("font_size", AMOUNT_FONT_SIZE)
		amount_row.add_child(_amount)
		var note_text: String = reward.note()
		if note_text != "":
			_note = UiKit.label(note_text, &"LabelCaption")
			_note.name = "Note"
			_note.add_theme_color_override("font_color", UiTokens.TEXT_TERTIARY)
			_note.clip_text = true
			_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			_text.add_child(_note)


## Kart belirir: solma + hafif yay (kapalı sandık görünür, yazı henüz yok).
func appear() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(0.86, 0.86)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, APPEAR_TIME * 0.7)
	tween.tween_property(self, "scale", Vector2.ONE, APPEAR_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tweens.append(tween)


## Sandık açılır (rarity katmanları + owner sandığı), yazı sütunu belirir;
## skin ödülünde sandık sönerek küçülür ve skin sanatı pop'lar.
func open() -> void:
	if _opened:
		return
	_opened = true
	if _gem != null:
		_gem.open()
	# Yazı sütunu HBox çocuğu: konumu container verir, o yüzden kayma değil
	# yalnız solma + etiket pop'u.
	var text_tween: Tween = create_tween()
	text_tween.tween_property(_text, "modulate:a", 1.0, CONTENT_TIME).set_delay(0.06)
	text_tween.tween_callback(func() -> void: UiMotion.pop(_tag, 1.10))
	_tweens.append(text_tween)
	if _swatch != null and _gem != null:
		var swap: Tween = create_tween()
		swap.tween_interval(SKIN_SWAP_DELAY)
		swap.tween_property(_gem, "modulate:a", 0.0, 0.18)
		swap.parallel().tween_property(_gem, "scale", Vector2(0.6, 0.6), 0.2).set_trans(Tween.TRANS_SINE)
		swap.tween_callback(_show_skin)
		_tweens.append(swap)
	if _new_badge != null:
		var badge_tween: Tween = create_tween()
		badge_tween.tween_interval(SKIN_SWAP_DELAY + 0.16)
		badge_tween.tween_callback(func() -> void: UiMotion.pop(_new_badge, 1.16))
		_tweens.append(badge_tween)


func _show_skin() -> void:
	if _swatch == null or not is_instance_valid(_swatch):
		return
	if _gem != null and is_instance_valid(_gem):
		_gem.visible = false
	_swatch.modulate.a = 1.0
	_swatch.scale = Vector2(0.4, 0.4)
	var pop: Tween = _swatch.create_tween()
	pop.tween_property(_swatch, "scale", Vector2(1.12, 1.12), SKIN_POP_TIME * 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_swatch, "scale", Vector2.ONE, SKIN_POP_TIME * 0.4)
	_tweens.append(pop)


## Reveal bitti: sürekli parçacık/nabız durur (Legendary'de yalnız yavaş
## ışın dönüşü kalır). Bir kart için `_process` YOK.
func settle() -> void:
	if _gem != null and is_instance_valid(_gem) and _gem.visible:
		_gem.settle()


## Sahnenin ekran merkezi (ışık patlaması için).
func burst_center() -> Vector2:
	return _stage.global_position + _stage.size * 0.5


## Legendary pırıltıları (sahibin tek tween'inden; sinüs, RNG yok).
func tick_sparkles(time: float) -> void:
	for i in _sparkles.size():
		if not _sparkles[i].visible:
			continue
		var phase: float = float(LEGENDARY_SPARKLES[i][2])
		var twinkle: float = 0.30 + 0.60 * (0.5 + 0.5 * sin(TAU * time / 2.8 + phase))
		_sparkles[i].modulate.a = twinkle
		_sparkles[i].scale = Vector2.ONE * (0.75 + 0.35 * twinkle)


func kill_tweens() -> void:
	for tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()


# --- Okuma (test / ekran) ----------------------------------------------------

func reward() -> ChestReward:
	return _reward


func is_opened() -> bool:
	return _opened


func gem() -> Control:
	return _gem


func swatch() -> SkinSwatch:
	return _swatch


func tag_text() -> String:
	return (_tag.get_meta(&"title_label") as Label).text


func amount_text() -> String:
	return _amount.text if _amount != null else ""


func name_text() -> String:
	return _name_label.text if _name_label != null else ""


## Kart içi notu gizler (M8.9-02.1: GÜNLÜK ÖDÜLLER reveal'i dar gövdede
## "Koleksiyon'a eklendi"yi kartın altında tam genişlik yazar; kart kısalır,
## hale için yan pay kalır). Round sonu kartlarında çağrılmaz.
func hide_note() -> void:
	if _note != null and is_instance_valid(_note):
		_note.visible = false


func note_text() -> String:
	return _note.text if _note != null else ""


func new_badge() -> PanelContainer:
	return _new_badge


func text_column() -> Control:
	return _text


## Kart içindeki bütün Label metinleri (dil taraması).
func all_texts() -> Array[String]:
	var out: Array[String] = []
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Label:
			out.append((node as Label).text)
		for child in node.get_children():
			stack.append(child)
	return out


# --- Yardımcılar -------------------------------------------------------------

## Teselli etiketi: rarity trapeziyle aynı biçim, lavanta (rarity rengi DEĞİL).
static func _plain_tag(text: String, tint: Color) -> PanelContainer:
	var tag := PanelContainer.new()
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tag.add_theme_stylebox_override("panel",
		UiKit.style("label_trapezoid", tint, Vector4(14, 0, 18, 4)))
	var text_label := UiKit.label(text, &"LabelBadgeOnDark", HORIZONTAL_ALIGNMENT_CENTER)
	tag.add_child(text_label)
	tag.set_meta(&"title_label", text_label)
	return tag


static func _center(node: Control, box: float, down: float) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	node.offset_left = -box * 0.5
	node.offset_right = box * 0.5
	node.offset_top = -box * 0.5 + down
	node.offset_bottom = box * 0.5 + down
