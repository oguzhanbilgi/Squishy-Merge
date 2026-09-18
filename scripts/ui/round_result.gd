extends CanvasLayer
## Round sonu ekranı — production yeniden kurulum (M8.6-09; GAME_DESIGN §5.1).
## Oyundaki son koyu M8.5-10 sayfası (yarı saydam lacivert plaka + koyu kart
## satırları + neon varsayılan buton + eski "level listesi" etiketi) kalktı.
##
## YALNIZCA SUNAR. Bütün ilerleme / ekonomi yazımı bu ekran açılmadan ÖNCE
## `Main._on_round_finished` + `ChestSystem`'de bitmiştir (yıldız, level
## tamamlama, kilit, Hamur, skin — her biri tam bir kez). Buradaki hiçbir
## şey (açılış, reveal, kaydırma, buton) kayda yazmaz; ödüller gösterilen
## `ChestReward` nesnelerinden okunur, Hamur bakiyesi kanonik
## `SaveManager.dough()`'a sayılarak varır. Aynı sonucun ikinci kez açılması
## kopya pencere / kopya ödül üretmez (tek çerçeve, kartlar yeniden kurulur).
##
## İki duygusal mod, tek parametreli bileşen (+ Sonsuz):
##   WIN      owner kanatlı-kalp tepeliği (1.18×), altın kontur + sıcak
##            parıltı, gövde içi ALTIN kurdele "LEVEL 4 TAMAM!", yay üstünde
##            üç yıldız (tek tek pop + pırıltı), yeni kilit rozeti ("LEVEL 5
##            AÇILDI" / "SONSUZ MOD AÇILDI" — yalnız BU round açtıysa),
##            ödül kartları, altlıkta SKOR / HEDEF / HAMUR çipleri,
##            HARİTA kahraman CTA (kanonik rota: Harita, sıradaki düğüm
##            orada açılış animasyonuyla) + TEKRAR OYNA ikincil.
##   FAIL     tepelik yok, lavanta kurdele "OLMADI" (cezalandırmaz), üç
##            yumuşak lavanta yıldız (sahte kazanım yok), teşvik satırı
##            ("Hedefe çok yaklaştın!" — ulaşılan tier'a göre), teselli /
##            bonus kartları, TEKRAR DENE kahraman CTA + HARİTA ikincil.
##   ENDLESS  yıldız yok; "YENİ REKOR!" (altın, tepelikli) ya da "TUR
##            BİTTİ" (lavanta); skor kahraman çipi, REKOR + HAMUR çipleri,
##            varsa bonus sandıklar; TEKRAR OYNA + HARİTA.
##
## İskelet `UiKit.modal_shell` (shell v2, 600 geniş, X yok — karar ekranı):
## başlık/yıldız/rozet SABİT `hero` bölgesinde, ödül kartları kaydırılan
## `body`'de, çipler + CTA'lar SABİT altlıkta. 5+ ödülde gövde kaydırılır,
## altlık yerinde kalır; reveal sırasında gövde açılan karta kayar. Kartlar
## dokunma hedefi değil (eylemleri yok) → karttan başlayan sürükleme
## doğrudan kaydırır. Karartma α .74: HUD okunmaz ama tanınır kalır; gövde
## opak krem — eski "Hedef tamam!" plakası artık içinden okunmaz.
##
## Zamanlama: yıldızlar 0.2 s arayla (owner brief'i §10; `star_reveal`
## pitch rampası), kartlar 0.45 s arayla belirir, 0.35 s sonra sandık
## açılır (4+ ödülde 0.30 / 0.25 — uzun tur dizisi sıkışır;
## `chest_open` → `AudioManager.play_reward(rarity)` + titreşim).
## Butonlar İLK KAREDEN aktif ("hemen tekrar dene" — GAME_DESIGN §5.1/4).
## `_sequence_id` gizleme / yeniden açılışta eski reveal'i geçersiz kılar.
## Android geri tuşu yok sayılır (Main: karar bekleyen uç durum).
##
## Sözleşme (Main / revive_test / refill_test / bot_runner / ui_smoke_test):
## `show_result(level, won, score, stars, rewards, new_record[, newly_unlocked,
## reached_tier])`, `hide_result()`, `retry_pressed`, `exit_pressed`.

signal retry_pressed
signal exit_pressed

enum Mode { WIN, FAIL, ENDLESS }

const BURST_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_burst.png")
const SPARKLE_TEXTURE: Texture2D = preload("res://assets/visual/fx/fx_sparkle.png")
const DOUGH_ART: Texture2D = preload("res://assets/visual/ui/icon_dough.png")
const REWARD_GEM := preload("res://scripts/ui/reward_gem.gd")

const MODAL_WIDTH: float = 600.0
const TOPPER_SCALE: float = 1.18
const TITLE_FONT_SIZE: int = 34
const TITLE_MIN_WIDTH: float = 400.0
const TITLE_HOST_HEIGHT: float = 78.0
## Kutlama parıltısı: pembe pencere parıltısıyla altın premium parıltının
## ortası — kazanma anı sıcak ama Legendary altını değil.
const GLOW_WIN: Color = Color(0.98, 0.72, 0.42, 0.5)
const RIM_WIN: Color = UiTokens.GOLD
const RIBBON_FAIL: Color = UiTokens.LAVENDER_DEEP
const RIBBON_WIN: Color = UiTokens.GOLD
const TITLE_OUTLINE_WIN: Color = UiTokens.GOLD_DEEP
const DIM_ALPHA: float = 0.74
## Zamanlama (sn).
const STAR_FIRST_DELAY: float = 0.30
const STAR_REVEAL_DELAY: float = 0.20
const CARD_REVEAL_DELAY: float = 0.45
const CHEST_OPEN_DELAY: float = 0.35
## 4+ ödülde (uzun Sonsuz turu) dizi sıkışır: kart başına 0.55 s yerine
## 0.8 s ile 6 kart ~5 s sürerdi. Butonlar zaten ilk kareden aktif.
const MANY_REWARDS: int = 4
const CARD_REVEAL_DELAY_MANY: float = 0.30
const CHEST_OPEN_DELAY_MANY: float = 0.25
const SCROLL_TIME: float = 0.28
const CARD_GAP: int = 12
## Çip ölçüleri (altlık özet satırı).
const CHIP_HEIGHT: float = 60.0
const CHIP_CAPTION_SIZE: int = 12
const CHIP_VALUE_SIZE: int = 22
const CHIP_EXTRA_SIZE: int = 13
const ENDLESS_SCORE_SIZE: int = 44
## Kopyalar (oyuncu dili Türkçe).
const TITLE_WIN: String = "LEVEL %d TAMAM!"
const TITLE_FAIL: String = "OLMADI"
const TITLE_RECORD: String = "YENİ REKOR!"
const TITLE_ENDLESS: String = "TUR BİTTİ"
const UNLOCK_LEVEL: String = "LEVEL %d AÇILDI"
const UNLOCK_ENDLESS: String = "SONSUZ MOD AÇILDI"
const ENCOURAGE_CLOSE: String = "Hedefe çok yaklaştın!"
const ENCOURAGE_SCORE: String = "Hedef tier tamam, skor az kaldı!"
const ENCOURAGE_DEFAULT: String = "Bir dahaki sefere!"
const PRIMARY_WIN: String = "HARİTA"
const SECONDARY_WIN: String = "TEKRAR OYNA"
const PRIMARY_FAIL: String = "TEKRAR DENE"
const SECONDARY_FAIL: String = "HARİTA"
const PRIMARY_ENDLESS: String = "TEKRAR OYNA"
const SECONDARY_ENDLESS: String = "HARİTA"
const CHIP_SCORE: String = "SKOR"
const CHIP_TARGET: String = "HEDEF"
const CHIP_RECORD: String = "REKOR"
const CHIP_DOUGH: String = "HAMUR"

var _frame: Control
var _glow: NinePatchRect
var _rim: NinePatchRect
var _topper: TextureRect
var _ribbon: PanelContainer
var _ribbon_label: Label
var _hero_ribbon_host: CenterContainer
var _hero_ribbon: PanelContainer
var _hero_ribbon_label: Label
var _unlock_host: CenterContainer
var _unlock_badge: PanelContainer
var _stars: ResultStarStrip
var _encourage: Label
var _endless_host: CenterContainer
var _endless_chip: PanelContainer
var _body: VBoxContainer
var _summary: HBoxContainer
var _score_chip: PanelContainer
var _target_chip: PanelContainer
var _record_chip: PanelContainer
var _dough_chip: PanelContainer
var _primary: Button
var _secondary: Button
var _mode: Mode = Mode.WIN
var _level: LevelData = null
var _cards: Array[ResultRewardCard] = []
var _rewards: Array[ChestReward] = []
var _sequence_id: int = 0
var _balance_shown: int = 0
var _reveal_done: bool = false
var _sparkle_tween: Tween = null
var _scroll_tween: Tween = null

@onready var _dim: ColorRect = $Center/Dim
@onready var _anchor: CenterContainer = $Center/Anchor
@onready var _fx: Control = $FxLayer


func _ready() -> void:
	visible = false
	_dim.color.a = DIM_ALPHA
	_frame = UiKit.modal_shell("", MODAL_WIDTH, &"ribbon", true, false, UiTokens.GLOW_SUBTLE, TOPPER_SCALE)
	_frame.name = "ResultShell"
	_anchor.add_child(_frame)
	_glow = _frame.get_meta(&"glow")
	_topper = _frame.get_meta(&"topper")
	_ribbon = _frame.get_meta(&"ribbon")
	_ribbon_label = _ribbon.get_meta(&"title_label")
	_ribbon_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	# Kutlama konturu: gövdenin AYNI 9-slice'ı (popup_body) altın boyalı, 4 px
	# dışarı taşar ve panelin arkasında durur → eşit kalınlıkta altın çerçeve.
	var panel: PanelContainer = _frame.get_meta(&"panel")
	_rim = UiKit.patch("popup_body", RIM_WIN)
	_rim.name = "CelebrationRim"
	UiKit.inset(_rim, -4.0, -4.0, -4.0, 5.0)
	_frame.add_child(_rim)
	_frame.move_child(_rim, panel.get_index())

	_build_hero()
	_body = _frame.get_meta(&"body")
	_body.add_theme_constant_override("separation", CARD_GAP)
	_build_footer()
	UiKit.modal_relayout(_frame)


# --- Kurulum -------------------------------------------------------------------

func _build_hero() -> void:
	var hero: VBoxContainer = _frame.get_meta(&"hero")
	hero.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	# Kazanma başlığı: gövde İÇİNDE altın kurdele (tepelik üst kenarı aldı).
	_hero_ribbon_host = CenterContainer.new()
	_hero_ribbon_host.name = "TitleHost"
	_hero_ribbon_host.custom_minimum_size = Vector2(0, TITLE_HOST_HEIGHT)
	_hero_ribbon_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(_hero_ribbon_host)
	_hero_ribbon = UiKit.header_ribbon("", RIBBON_WIN)
	_hero_ribbon.name = "TitleRibbon"
	_hero_ribbon.custom_minimum_size = Vector2(TITLE_MIN_WIDTH, 0)
	_hero_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_ribbon_label = _hero_ribbon.get_meta(&"title_label")
	_hero_ribbon_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	# Altın kurdele üstünde beyaz Baloo + koyu altın kontur (candy başlık dili).
	_hero_ribbon_label.add_theme_color_override("font_outline_color", TITLE_OUTLINE_WIN)
	_hero_ribbon_label.add_theme_constant_override("outline_size", 6)
	_hero_ribbon_host.add_child(_hero_ribbon)

	_unlock_host = CenterContainer.new()
	_unlock_host.name = "UnlockHost"
	_unlock_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unlock_host.visible = false
	hero.add_child(_unlock_host)

	_stars = ResultStarStrip.new()
	_stars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(_stars)

	_encourage = UiKit.label("", &"LabelBody", HORIZONTAL_ALIGNMENT_CENTER)
	_encourage.name = "Encourage"
	_encourage.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_encourage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_encourage.visible = false
	hero.add_child(_encourage)

	# Sonsuz: skor kahraman çipi (yıldız yerine).
	_endless_host = CenterContainer.new()
	_endless_host.name = "EndlessScoreHost"
	_endless_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_endless_host.visible = false
	hero.add_child(_endless_host)
	_endless_chip = _chip(CHIP_SCORE, "0")
	_endless_chip.name = "EndlessScore"
	(_endless_chip.get_meta(&"value_label") as Label).add_theme_font_size_override("font_size", ENDLESS_SCORE_SIZE)
	_endless_chip.custom_minimum_size = Vector2(260.0, 96.0)
	_endless_host.add_child(_endless_chip)


func _build_footer() -> void:
	var footer: VBoxContainer = _frame.get_meta(&"footer")
	footer.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_summary = HBoxContainer.new()
	_summary.name = "Summary"
	_summary.alignment = BoxContainer.ALIGNMENT_CENTER
	_summary.add_theme_constant_override("separation", 10)
	_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(_summary)
	_score_chip = _chip(CHIP_SCORE, "0")
	_score_chip.name = "ScoreChip"
	_summary.add_child(_score_chip)
	_target_chip = _chip(CHIP_TARGET, "-")
	_target_chip.name = "TargetChip"
	_summary.add_child(_target_chip)
	_record_chip = _chip(CHIP_RECORD, "0")
	_record_chip.name = "RecordChip"
	_summary.add_child(_record_chip)
	_dough_chip = _chip(CHIP_DOUGH, "0", DOUGH_ART)
	_dough_chip.name = "DoughChip"
	_summary.add_child(_dough_chip)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, UiTokens.SPACE_XS)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(gap)
	_primary = UiKit.cta(PRIMARY_WIN, "", &"ButtonCTA", "map")
	_primary.name = "Primary"
	_primary.pressed.connect(_on_primary_pressed)
	footer.add_child(_primary)
	_secondary = UiKit.button(SECONDARY_WIN, &"ButtonSecondary", "refresh")
	_secondary.name = "Secondary"
	_secondary.pressed.connect(_on_secondary_pressed)
	footer.add_child(_secondary)


## Özet çipi: bir ton geri krem plaka + ince lavanta kontur; içinde küçük
## büyük-harf başlık ve Nunito değer (isteğe bağlı ikon, ek satır).
## Meta: "value_label", "caption_label", "extra_label".
func _chip(caption: String, value: String, icon_tex: Texture2D = null) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.custom_minimum_size = Vector2(0, CHIP_HEIGHT)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel",
		UiKit.style("label_round", UiTokens.CREAM_DEEP, Vector4(18, 6, 18, 8)))
	var outline := UiKit.flat_plate("label_round", Color(UiTokens.LAVENDER_SURFACE, 0.9))
	outline.show_behind_parent = true
	UiKit.inset(outline, -2.0, -2.0, -2.0, -2.0)
	chip.add_child(outline)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	if icon_tex != null:
		var picture := UiKit.art(icon_tex, 30.0)
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(picture)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", -4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var caption_label := UiKit.label(caption, &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
	caption_label.add_theme_font_size_override("font_size", CHIP_CAPTION_SIZE)
	caption_label.add_theme_color_override("font_color", UiTokens.TEXT_TERTIARY)
	column.add_child(caption_label)
	var value_label := UiKit.label(value, &"LabelStat", HORIZONTAL_ALIGNMENT_CENTER)
	value_label.add_theme_font_size_override("font_size", CHIP_VALUE_SIZE)
	column.add_child(value_label)
	var extra_label := UiKit.label("", &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
	extra_label.add_theme_font_size_override("font_size", CHIP_EXTRA_SIZE)
	extra_label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	extra_label.visible = false
	column.add_child(extra_label)
	chip.set_meta(&"value_label", value_label)
	chip.set_meta(&"caption_label", caption_label)
	chip.set_meta(&"extra_label", extra_label)
	return chip


static func _set_chip(chip: PanelContainer, value: String, extra: String = "") -> void:
	(chip.get_meta(&"value_label") as Label).text = value
	var extra_label: Label = chip.get_meta(&"extra_label")
	extra_label.text = extra
	extra_label.visible = extra != ""


# --- Sözleşme ----------------------------------------------------------------

func hide_result() -> void:
	# Devam eden reveal varsa geçersiz kıl — tekrar dene'ye basılırsa eski
	# animasyon yeni ekrana yazmasın; sürekli efektler durur, kartlar silinir.
	_sequence_id += 1
	visible = false
	_stop_ambient()
	_clear_cards()


## `newly_unlocked`: bu round yeni bir level / Sonsuz kilidi açtı (Main
## yazımdan önce-sonra karşılaştırır). `reached_tier`: round'da ulaşılan en
## yüksek tier (kayıp notu). İkisi de isteğe bağlı — eski çağıranlar
## (testler, araçlar) altı parametreyle çalışmaya devam eder.
func show_result(level: LevelData, won: bool, score: int, stars: int,
		rewards: Array[ChestReward], new_record: bool,
		newly_unlocked: bool = false, reached_tier: int = 0) -> void:
	_sequence_id += 1
	var sequence: int = _sequence_id
	_stop_ambient()
	_clear_cards()
	_level = level
	_rewards = rewards.duplicate()
	_configure(level, won, score, stars, rewards, new_record, newly_unlocked, reached_tier)
	_build_cards(rewards)
	visible = true
	UiKit.modal_relayout(_frame)
	(_frame.get_meta(&"scroll") as ScrollContainer).scroll_vertical = 0
	UiMotion.modal_open(_frame, _dim)
	_start_ambient()
	await _run_reveal(sequence, stars)


func _configure(level: LevelData, won: bool, score: int, stars: int,
		rewards: Array[ChestReward], new_record: bool,
		newly_unlocked: bool, reached_tier: int) -> void:
	if level.is_endless:
		_mode = Mode.ENDLESS
	else:
		_mode = Mode.WIN if won else Mode.FAIL
	var celebrate: bool = _mode == Mode.WIN or (_mode == Mode.ENDLESS and new_record)
	var title: String
	match _mode:
		Mode.WIN: title = TITLE_WIN % level.level_number
		Mode.FAIL: title = TITLE_FAIL
		_: title = TITLE_RECORD if new_record else TITLE_ENDLESS

	# Başlık yeri: kutlamada tepelik + gövde içi altın kurdele; diğerlerinde
	# üst kenardan taşan lavanta kurdele (Mola / Sandık dili, sakin).
	_topper.visible = celebrate
	_rim.visible = celebrate
	_glow.self_modulate = GLOW_WIN if celebrate else UiTokens.GLOW_SUBTLE
	_hero_ribbon_host.visible = celebrate
	_hero_ribbon_label.text = title
	_ribbon.visible = not celebrate
	_ribbon_label.text = title
	_tint_ribbon(_ribbon, RIBBON_FAIL)
	# Tepelik/kurdele taşması kadar aşağı: bileşik (tepelik + gövde) ortalanır,
	# kısa ekranda tepelik üst kenara/çentiğe yaslanmaz.
	var overhang: float = UiKit.MODAL_TOPPER_OVERHANG * TOPPER_SCALE if celebrate else UiKit.MODAL_RIBBON_OVERHANG
	_anchor.offset_top = overhang

	# Yeni kilit rozeti — yalnız kazanmada ve yalnız bu round açtıysa.
	_set_unlock_badge(level, _mode == Mode.WIN and newly_unlocked)

	# Yıldızlar (sonsuzda yok); kazanılanlar reveal'e kadar gizli.
	_stars.visible = _mode != Mode.ENDLESS
	_stars.set_stars(stars if _mode == Mode.WIN else 0, true)

	# Kayıp teşviki: ulaşılan tier'a göre, suçlamaz.
	_encourage.visible = _mode == Mode.FAIL
	if _mode == Mode.FAIL:
		_encourage.text = _encouragement(level, reached_tier)

	# Sonsuz: skor kahraman.
	_endless_host.visible = _mode == Mode.ENDLESS
	if _mode == Mode.ENDLESS:
		_set_chip(_endless_chip, GameplayHud._thousands(score))

	# Altlık çipleri.
	_score_chip.visible = _mode != Mode.ENDLESS
	_target_chip.visible = _mode != Mode.ENDLESS
	_record_chip.visible = _mode == Mode.ENDLESS
	_set_chip(_score_chip, GameplayHud._thousands(score))
	if _mode != Mode.ENDLESS:
		_set_chip(_target_chip, TierConfig.tier_name(level.target_tier),
			("+%s skor" % GameplayHud._thousands(level.target_score)) if level.has_score_target() else "")
	_set_chip(_record_chip, GameplayHud._thousands(SaveManager.endless_high_score()))
	# Hamur bakiyesi: reveal sırasında kanonik bakiyeye SAYARAK varır
	# (açılmamış sandıkların Hamur'u henüz gösterilmez; son değer = kayıt).
	var pending: int = 0
	for reward in rewards:
		if not reward.is_skin_reward():
			pending += reward.dough
	# maxi: kanonik yolda bakiye >= bekleyen (ödüller zaten yazıldı); yalnız
	# sahte ödüllü araçlarda negatife düşebilirdi.
	_balance_shown = maxi(0, SaveManager.dough() - pending)
	_set_chip(_dough_chip, GameplayHud._thousands(_balance_shown))

	# Eylemler: kazanmada Harita kahraman (kanonik rota), kayıpta tekrar dene.
	match _mode:
		Mode.WIN:
			_set_button_texts(PRIMARY_WIN, "map", SECONDARY_WIN, "refresh")
		Mode.FAIL:
			_set_button_texts(PRIMARY_FAIL, "refresh", SECONDARY_FAIL, "map")
		_:
			_set_button_texts(PRIMARY_ENDLESS, "refresh", SECONDARY_ENDLESS, "map")
	_reveal_done = false


func _set_unlock_badge(level: LevelData, show: bool) -> void:
	if _unlock_badge != null:
		_unlock_badge.queue_free()
		_unlock_badge = null
	_unlock_host.visible = show
	if not show:
		return
	var total: int = LevelLibrary.load_levels().size()
	if level.level_number >= total:
		_unlock_badge = UiKit.badge(UNLOCK_ENDLESS, &"Badge", "trophy")
	else:
		_unlock_badge = UiKit.badge(UNLOCK_LEVEL % (level.level_number + 1), &"EquippedBadge", "unlock")
	_unlock_badge.name = "UnlockBadge"
	var text_label: Label = _unlock_badge.get_child(0).get_child(_unlock_badge.get_child(0).get_child_count() - 1)
	text_label.add_theme_font_size_override("font_size", 17)
	_unlock_badge.add_theme_stylebox_override("panel", UiKit.style(
		"badge_round" if level.level_number >= total else "frame_round20",
		UiTokens.GOLD if level.level_number >= total else UiTokens.MINT, Vector4(14, 3, 16, 5)))
	_unlock_host.add_child(_unlock_badge)


func _encouragement(level: LevelData, reached_tier: int) -> String:
	if reached_tier <= 0:
		return ENCOURAGE_DEFAULT
	if reached_tier >= level.target_tier:
		return ENCOURAGE_SCORE if level.has_score_target() else ENCOURAGE_DEFAULT
	if reached_tier == level.target_tier - 1:
		return ENCOURAGE_CLOSE
	return ENCOURAGE_DEFAULT


func _set_button_texts(primary: String, primary_icon: String,
		secondary: String, secondary_icon: String) -> void:
	(_primary.get_meta(&"title_label") as Label).text = primary
	var row: HBoxContainer = (_primary.get_meta(&"title_label") as Label).get_parent().get_parent()
	for child in row.get_children():
		if child is TextureRect:
			(child as TextureRect).texture = UiKit.icon_texture(primary_icon)
	_secondary.text = secondary
	_secondary.icon = UiKit.icon_texture(secondary_icon)


static func _tint_ribbon(ribbon: PanelContainer, tint: Color) -> void:
	var box: StyleBoxTexture = UiKit.theme().get_stylebox("panel", &"HeaderRibbon").duplicate()
	box.modulate_color = tint
	ribbon.add_theme_stylebox_override("panel", box)


# --- Ödül kartları -------------------------------------------------------------

func _build_cards(rewards: Array[ChestReward]) -> void:
	for reward in rewards:
		var card := ResultRewardCard.create(reward)
		_body.add_child(card)
		_cards.append(card)


func _clear_cards() -> void:
	for card in _cards:
		if is_instance_valid(card):
			card.kill_tweens()
			_body.remove_child(card)
			card.queue_free()
	_cards.clear()
	_rewards.clear()


# --- Reveal ---------------------------------------------------------------------

func _run_reveal(sequence: int, stars: int) -> void:
	await get_tree().process_frame
	await get_tree().create_timer(STAR_FIRST_DELAY).timeout
	if sequence != _sequence_id:
		return
	if _mode == Mode.WIN:
		for i in stars:
			_stars.reveal(i)
			# "Pat" sesi (GAME_DESIGN §5.1), pitch her yıldızda biraz yükselir.
			AudioManager.play(&"star_reveal", 1.0 + 0.12 * float(i))
			await get_tree().create_timer(STAR_REVEAL_DELAY).timeout
			if sequence != _sequence_id:
				return
	var many: bool = _cards.size() >= MANY_REWARDS
	var card_delay: float = CARD_REVEAL_DELAY_MANY if many else CARD_REVEAL_DELAY
	var open_delay: float = CHEST_OPEN_DELAY_MANY if many else CHEST_OPEN_DELAY
	for i in _cards.size():
		await get_tree().create_timer(card_delay).timeout
		if sequence != _sequence_id or i >= _cards.size():
			return
		var card: ResultRewardCard = _cards[i]
		_scroll_to_card(card)
		card.appear()
		# İki aşamalı ses (M8.5-15): sandık belirirken "açılış" (beklenti),
		# açılınca rarity'e göre ödül cue'su. Teselli sandık değil: yalnız cue.
		if not card.reward().is_consolation:
			AudioManager.play(&"chest_open")
		await get_tree().create_timer(open_delay).timeout
		if sequence != _sequence_id or i >= _cards.size():
			return
		card.open()
		var reward: ChestReward = card.reward()
		_burst_at(card.burst_center(), reward.color(), REWARD_GEM.fx_level(reward))
		_play_reveal_feedback(reward)
		_bump_balance(reward)
	# Sayaç ne gösterdiyse göstersin, son söz kayıtta: çip kanonik bakiyede biter.
	_balance_shown = SaveManager.dough()
	UiKit.set_pill_value(_dough_chip, GameplayHud._thousands(_balance_shown), false)
	_reveal_done = true
	for card in _cards:
		card.settle()


## Gövde kaydırılabiliyorsa açılan kartı görünür bölgeye getirir.
func _scroll_to_card(card: Control) -> void:
	if not bool(_frame.get_meta(&"body_scrolls", false)):
		return
	var scroll: ScrollContainer = _frame.get_meta(&"scroll")
	var host: Control = _frame.get_meta(&"body_host")
	var bottom: float = card.position.y + card.size.y + 6.0
	var target: int = int(maxf(0.0, bottom - host.size.y))
	if target <= scroll.scroll_vertical:
		return
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	_scroll_tween = scroll.create_tween()
	_scroll_tween.tween_property(scroll, "scroll_vertical", target, SCROLL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _bump_balance(reward: ChestReward) -> void:
	if reward.is_skin_reward() or reward.dough <= 0:
		return
	_balance_shown += reward.dough
	UiKit.set_pill_value(_dough_chip, GameplayHud._thousands(_balance_shown), true)


## Ödül reveal'inin ses + titreşimi (M8.5-15 eşlemesi DEĞİŞMEDİ). Teselli
## Common gibi; Legendary premium desen, Epic / yeni skin orta, Hamur hafif.
func _play_reveal_feedback(reward: ChestReward) -> void:
	var rarity: int = SkinData.Rarity.COMMON if reward.is_consolation else int(reward.rarity)
	AudioManager.play_reward(rarity)
	match rarity:
		SkinData.Rarity.LEGENDARY:
			Haptics.special()
		SkinData.Rarity.EPIC:
			Haptics.medium()
		_:
			if reward.is_skin_reward():
				Haptics.medium()
			else:
				Haptics.light()


## Sandık açılışı: rarity renginde ışık patlaması + parıltı parçacıkları
## (FxLayer: kaydırma kırpmasının dışında; bitince silinir).
func _burst_at(center: Vector2, tint: Color, fx_level: int = 3) -> void:
	var t: float = float(fx_level) / 3.0
	var flash := TextureRect.new()
	flash.texture = BURST_TEXTURE
	flash.custom_minimum_size = Vector2(256, 256)
	flash.size = Vector2(256, 256)
	flash.pivot_offset = flash.size * 0.5
	flash.position = center - flash.size * 0.5
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate = Color(tint.r, tint.g, tint.b, lerpf(0.45, 0.95, t))
	flash.scale = Vector2(0.25, 0.25)
	_fx.add_child(flash)
	var tween := flash.create_tween()
	tween.set_parallel(true)
	var peak: float = lerpf(0.8, 1.5, t)
	tween.tween_property(flash, "scale", Vector2(peak, peak), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "rotation", 0.6, 0.45)
	tween.tween_property(flash, "modulate:a", 0.0, 0.45).set_delay(0.08)
	tween.chain().tween_callback(flash.queue_free)

	var sparks := CPUParticles2D.new()
	sparks.texture = SPARKLE_TEXTURE
	sparks.position = center
	sparks.emitting = false
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.lifetime = 0.7
	sparks.amount = int(lerpf(8.0, 24.0, t))
	sparks.direction = Vector2.UP
	sparks.spread = 180.0
	sparks.gravity = Vector2(0.0, 420.0)
	sparks.initial_velocity_min = 120.0
	sparks.initial_velocity_max = 340.0
	sparks.scale_amount_min = 0.12
	sparks.scale_amount_max = 0.34
	sparks.color = tint.lerp(Color.WHITE, 0.5)
	_fx.add_child(sparks)
	sparks.emitting = true
	var cleanup := sparks.create_tween()
	cleanup.tween_interval(sparks.lifetime + 0.3)
	cleanup.tween_callback(sparks.queue_free)


## Legendary kart pırıltıları: TEK tween bütün kartları tıklar (kart başına
## `_process` yok); Legendary kart yoksa hiç çalışmaz.
func _start_ambient() -> void:
	_stop_ambient()
	var has_legendary: bool = false
	for card in _cards:
		if card.reward().rarity == SkinData.Rarity.LEGENDARY and not card.reward().is_consolation:
			has_legendary = true
			break
	if not has_legendary:
		return
	_sparkle_tween = create_tween().set_loops()
	_sparkle_tween.tween_method(_tick_sparkles, 0.0, 100.0, 100.0)


func _tick_sparkles(time: float) -> void:
	for card in _cards:
		if is_instance_valid(card):
			card.tick_sparkles(time)


func _stop_ambient() -> void:
	if _sparkle_tween != null and _sparkle_tween.is_valid():
		_sparkle_tween.kill()
	_sparkle_tween = null
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	_scroll_tween = null


# --- Eylemler -------------------------------------------------------------------

## Kahraman CTA: kazanmada Harita (çıkış), kayıpta / sonsuzda tekrar.
func _on_primary_pressed() -> void:
	if not visible:
		return
	if _mode == Mode.WIN:
		exit_pressed.emit()
	else:
		retry_pressed.emit()


func _on_secondary_pressed() -> void:
	if not visible:
		return
	if _mode == Mode.WIN:
		retry_pressed.emit()
	else:
		exit_pressed.emit()


# --- Okuma (test / araç) --------------------------------------------------------

func frame() -> Control:
	return _frame


func mode() -> Mode:
	return _mode


func title_text() -> String:
	return _hero_ribbon_label.text if _hero_ribbon_host.visible else _ribbon_label.text


func star_strip() -> ResultStarStrip:
	return _stars


func cards() -> Array[ResultRewardCard]:
	return _cards


func primary_button() -> Button:
	return _primary


func secondary_button() -> Button:
	return _secondary


func primary_text() -> String:
	return (_primary.get_meta(&"title_label") as Label).text


func secondary_text() -> String:
	return _secondary.text


## Görünür eylemin anlamı: "retry" / "exit".
func primary_action() -> String:
	return "exit" if _mode == Mode.WIN else "retry"


func score_text() -> String:
	return (_score_chip.get_meta(&"value_label") as Label).text


func target_text() -> String:
	return (_target_chip.get_meta(&"value_label") as Label).text


func target_extra_text() -> String:
	return (_target_chip.get_meta(&"extra_label") as Label).text


func record_text() -> String:
	return (_record_chip.get_meta(&"value_label") as Label).text


func endless_score_text() -> String:
	return (_endless_chip.get_meta(&"value_label") as Label).text


func dough_text() -> String:
	return (_dough_chip.get_meta(&"value_label") as Label).text


func unlock_badge() -> PanelContainer:
	return _unlock_badge if _unlock_host.visible else null


func unlock_text() -> String:
	if _unlock_badge == null or not _unlock_host.visible:
		return ""
	var row: Control = _unlock_badge.get_child(0)
	return (row.get_child(row.get_child_count() - 1) as Label).text


func encourage_text() -> String:
	return _encourage.text if _encourage.visible else ""


func is_reveal_done() -> bool:
	return _reveal_done


func topper() -> TextureRect:
	return _topper


func celebration_rim() -> NinePatchRect:
	return _rim


func dim() -> ColorRect:
	return _dim


func fx_layer() -> Control:
	return _fx


## Sonuç ağacındaki bütün Label metinleri (oyuncu dili taraması).
func all_texts() -> Array[String]:
	var out: Array[String] = []
	var stack: Array[Node] = [_frame]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var label := node as Label
		if label != null and label.is_visible_in_tree():
			out.append(label.text)
		for child in node.get_children():
			stack.append(child)
	return out
