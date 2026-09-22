class_name GameplayHud
extends CanvasLayer
## Production oyun HUD'u (M8.6-02). Tek tasarlanmış üst bölge:
##
##   Satır 1:  [Geri][Ayarlar]    [★ SKOR 1 240]     [SIRADAKİ ●][Çıkış]
##   Satır 2:  [tepsi: Bomba Büyüt.] [4 | HEDEF ad ▮▮▮▯▯] [tepsi: Sarsıntı Temiz.]
##   ...  BOARD (kamera ile sığdırılmış fizik penceresi)  ...
##   Alt:      [ T1 T2 T3 T4 T5 T6 T7 T8 ]   evrim şeridi
##   Alt seam: gelecek banner (v1'de 0 px)
##
## Konumlar `GameplayLayout.compute()`'tan; burada sabit koordinat YOK.
## Bileşenler `UiKit`/`ui_theme.tres` (PanelPurple / PanelElevated /
## ButtonIcon / PowerSlot / Badge / ProgressBarMint). Eski serbest metin
## (Skor: / Sıradaki: / RichText hedef satırı) ve neon plaka KALKTI.
##
## Oyun MANTIĞI burada yok: GameBoard skor/hedef/tier'ı buraya yazar,
## güç basışları `power_bar.power_pressed` ile board'a döner.

signal settings_pressed
## Geri / Çıkış: ikisi de Main'de aynı "Mola" penceresini açar.
signal back_pressed
signal exit_pressed

const POWER_BAR_SCENE: PackedScene = preload("res://scenes/ui/power_bar.tscn")
const STAR_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
const CROWN_ART: Texture2D = preload("res://assets/visual/ui/icon_crown.png")
const FLAG_ART: Texture2D = preload("res://assets/visual/ui/icon_flag.png")
const BADGE_STARBURST: Texture2D = preload("res://assets/visual/ui/badge_starburst.png")
## Tier dokuları: gameplay sprite'larının kendisi (owner sanatı).
const DUMPLING_VISUAL: GDScript = preload("res://scripts/game/dumpling_visual.gd")

## Üst karartma: HUD bölgesini zeminden ayıran yumuşak gradyan (opak plaka
## değil — candy-night zemin görünmeye devam eder).
const SCRIM_ALPHA: float = 0.42
const SCRIM_TAIL: float = 56.0

var power_bar: PowerBar
var strip: EvolutionStrip
var settings_button: Button
var back_button: Button
var exit_button: Button
var tray_left: PanelContainer
var tray_right: PanelContainer
var score_plate: PanelContainer
var score_label: Label
var next_plate: PanelContainer
var next_art: TextureRect
var goal_plate: PanelContainer
var level_badge: PanelContainer
var level_label: Label
var goal_art: TextureRect
var goal_label: Label
var goal_caption: Label
var goal_portrait: PanelContainer
var goal_percent: Label
var goal_extra: Label
var goal_bar: ProgressBar
var status_label: Label
var status_plate: PanelContainer
var combo_label: Label
var combo_badge: TextureRect
var score_pop: Label
var scrim: TextureRect
var banner_seam: Control

var _score_center: CenterContainer
## Dekor katmanlari: plakalarin arkasindaki golge/halka (`_deco_back`) ve
## ustundeki gloss/yildiz (`_deco_front`) — PanelContainer'lar dis dekor
## cocuklarini iceriye alip minimum boyuta kattigi icin ayri.
var _deco_back: Control
var _deco_mid: Control
var _deco_front: Control
var _layout: Dictionary = {}
var _status_anchor: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_scrim()
	_deco_back = Control.new()
	_deco_back.name = "DecoBack"
	_deco_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_deco_back)
	_deco_front = Control.new()
	_deco_front.name = "DecoFront"
	_deco_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_deco_front)
	_build_row1()
	_build_row2()
	# On dekor katmani plakalarin USTUNE (siralama: sonra eklenen ustte).
	move_child(_deco_front, get_child_count() - 1)
	for type in PowerBar.SLOT_ORDER:
		UiKit.hud_socket(power_bar.slot(int(type)), _deco_mid)
	_build_strip()
	_build_overlays()
	_build_banner_seam()


# --- Kurulum ---------------------------------------------------------------

func _build_scrim() -> void:
	scrim = TextureRect.new()
	scrim.name = "Scrim"
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.04, 0.02, 0.09, SCRIM_ALPHA))
	gradient.set_color(1, Color(0.04, 0.02, 0.09, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 4
	tex.height = 64
	scrim.texture = tex
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)


func _build_row1() -> void:
	# Sol küme: geri + ayarlar (glossy kare candy butonlar).
	back_button = UiKit.hud_icon_button("back", GameplayLayout.SETTINGS_SIZE)
	back_button.name = "Back"
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back_button)
	settings_button = UiKit.hud_icon_button("settings", GameplayLayout.SETTINGS_SIZE)
	settings_button.name = "Settings"
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	add_child(settings_button)

	# Skor: glossy lavanta plaka, iki yanda yıldız, koyu erik başlık, beyaz
	# gölgeli rakam (candy premium).
	_score_center = CenterContainer.new()
	_score_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_score_center)
	# hud_target: mor kapsül, açık lavanta dış kenar, dış gölge, üst gloss,
	# solda büyük altın yıldız, beyaz "SKOR" + büyük beyaz rakam, uçlarda
	# minik yıldız aksanları.
	score_plate = UiKit.panel(&"PanelHudScore")
	score_plate.name = "ScorePlate"
	score_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_center.add_child(score_plate)
	# HUD v5: cok yumusak mor arka parilti (kapsulun etrafinda genis, dusuk
	# alfa) + erik golge + acik halka; iki minik altin pirilti aksani onde.
	var backing := UiKit.patch("popup_glow", Color(UiTokens.LAVENDER_DEEP, 0.30))
	UiKit.hud_attach(score_plate, backing, _deco_back, Vector4(30.0, 22.0, 30.0, 26.0))
	UiKit.hud_shadow(score_plate, 6.0, 0.26, _deco_back)
	UiKit.hud_rim(score_plate, UiTokens.LAVENDER_LIGHT, 5.0, _deco_back)
	UiKit.hud_gloss(score_plate, 24.0, 0.36, 12.0, _deco_front)
	var sparkles := Control.new()
	sparkles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for spec in [[0.0, 0.0, -6.0, -8.0, 14.0], [1.0, 1.0, 2.0, -2.0, 10.0]]:
		var spark := UiKit.art(STAR_ART, int(spec[4]))
		spark.anchor_left = spec[0]
		spark.anchor_right = spec[0]
		spark.anchor_top = spec[1]
		spark.anchor_bottom = spec[1]
		spark.offset_left = spec[2]
		spark.offset_top = spec[3]
		spark.offset_right = spec[2] + spec[4]
		spark.offset_bottom = spec[3] + spec[4]
		spark.modulate = Color(1, 1, 1, 0.9)
		sparkles.add_child(spark)
	UiKit.hud_attach(score_plate, sparkles, _deco_front, Vector4.ZERO)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_plate.add_child(row)
	var star := UiKit.art(STAR_ART, 40)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(star)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", -10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var score_caption := UiKit.hud_caption("Skor")
	score_caption.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	column.add_child(score_caption)
	score_label = UiKit.label("0", &"LabelHudScore", HORIZONTAL_ALIGNMENT_CENTER)
	score_label.custom_minimum_size.x = 108.0
	score_label.add_theme_font_size_override("font_size", 34)
	column.add_child(score_label)
	var accent_r := UiKit.art(STAR_ART, 12)
	accent_r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(accent_r)

	# Sağ küme: Sıradaki kartı (lavanta çerçeve + krem) + çıkış.
	next_plate = UiKit.hud_card(_deco_back, _deco_front, false, &"PanelHudPill")
	next_plate.name = "NextPlate"
	add_child(next_plate)
	var next_card: PanelContainer = next_plate.get_meta(&"card")
	var next_row := HBoxContainer.new()
	next_row.alignment = BoxContainer.ALIGNMENT_CENTER
	next_row.add_theme_constant_override("separation", UiTokens.SPACE_XS + 2)
	next_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_card.add_child(next_row)
	var next_col := VBoxContainer.new()
	next_col.alignment = BoxContainer.ALIGNMENT_CENTER
	next_col.add_theme_constant_override("separation", -2)
	next_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_row.add_child(next_col)
	var next_caption := UiKit.label("SIRADAKİ", &"LabelHudCaptionDark", HORIZONTAL_ALIGNMENT_CENTER)
	next_caption.add_theme_color_override("font_color", UiTokens.LAVENDER_DEEP.darkened(0.25))
	next_col.add_child(next_caption)
	next_art = UiKit.art(DUMPLING_VISUAL.TEXTURES[0], 42)
	next_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_row.add_child(next_art)
	exit_button = UiKit.hud_icon_button("home", GameplayLayout.SETTINGS_SIZE, &"ButtonHudExit")
	exit_button.name = "Exit"
	exit_button.pressed.connect(func() -> void: exit_pressed.emit())
	add_child(exit_button)


func _build_row2() -> void:
	# Güç tepsileri: erik bevel, içinde ikişer madalyon (PowerBar slotları
	# tepsinin üstüne yerleşir; tepsi yalnız görsel).
	# hud_target: iki madalyonu birleştiren sığ krem tepsi, koyu lavanta dış
	# halka, dış gölge, üst gloss.
	# HUD v5: tepsi = krem `title_oval` pill (kose/cizgi yok); altinda ayni
	# pill'in lavanta-mor surumu asagi kaydirilmis (tek parca candy taban:
	# ust yuzey krem, alt derinlik mor) + erik yumusak golge.
	tray_left = UiKit.panel(&"PanelTray")
	tray_left.name = "TrayLeft"
	tray_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray_left)
	tray_right = UiKit.panel(&"PanelTray")
	tray_right.name = "TrayRight"
	tray_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray_right)
	for tray in [tray_left, tray_right]:
		UiKit.hud_shadow(tray, 7.0, 0.26, _deco_back)
		var base := UiKit.patch("title_oval", UiTokens.LAVENDER_DEEP)
		UiKit.hud_attach(tray, base, _deco_back, Vector4(4.0, 2.0, 4.0, 9.0))
		var base_light := UiKit.patch("title_oval", UiTokens.LAVENDER_LIGHT)
		UiKit.hud_attach(tray, base_light, _deco_back, Vector4(4.0, 3.0, 4.0, 3.0))
	# Orta dekor katmani: tepsilerin USTUNDE, madalyonlarin ALTINDA (tepsi
	# gloss'u + madalyon yuvalari).
	_deco_mid = Control.new()
	_deco_mid.name = "DecoMid"
	_deco_mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_deco_mid)
	UiKit.hud_gloss(tray_left, 18.0, 0.45, 12.0, _deco_mid)
	UiKit.hud_gloss(tray_right, 18.0, 0.45, 12.0, _deco_mid)
	power_bar = POWER_BAR_SCENE.instantiate()
	power_bar.name = "PowerBar"
	add_child(power_bar)

	# Hedef kartı: lavanta çerçeve + krem kart — ana bilgi modülü.
	goal_plate = UiKit.hud_card(_deco_back, _deco_front, true)
	goal_plate.name = "GoalPlate"
	add_child(goal_plate)
	var goal_card: PanelContainer = goal_plate.get_meta(&"card")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.SPACE_SM + 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_card.add_child(row)
	# Level rozeti (hud_target): büyük altın yuvarlak plaka, owner tacı üstte,
	# altında büyük Baloo numara.
	level_badge = UiKit.panel(&"PanelHudBadge")
	level_badge.custom_minimum_size = Vector2(60.0, 0.0)
	level_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(level_badge)
	var badge_col := VBoxContainer.new()
	badge_col.add_theme_constant_override("separation", -8)
	badge_col.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_badge.add_child(badge_col)
	var crown := UiKit.art(CROWN_ART, 30)
	crown.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge_col.add_child(crown)
	level_label = UiKit.label("1", &"LabelSectionOnAccent", HORIZONTAL_ALIGNMENT_CENTER)
	level_label.add_theme_font_size_override("font_size", 24)
	badge_col.add_child(level_label)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	# Hiyerarşi: küçük başlık (HEDEF / REKOR) → hedef adı → ilerleme.
	goal_caption = UiKit.hud_caption("Hedef")
	goal_caption.theme_type_variation = &"LabelHudCaptionDark"
	goal_caption.add_theme_color_override("font_color", UiTokens.LAVENDER_DEEP.darkened(0.15))
	goal_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(goal_caption)
	var goal_row := HBoxContainer.new()
	goal_row.add_theme_constant_override("separation", UiTokens.SPACE_XS + 2)
	goal_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(goal_row)
	# Hedef portresi: küçük krem-derin pill içinde (hud_target).
	goal_portrait = UiKit.panel(&"PanelHudPortrait")
	goal_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	goal_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_row.add_child(goal_portrait)
	goal_art = UiKit.art(DUMPLING_VISUAL.TEXTURES[3], 28)
	goal_portrait.add_child(goal_art)
	goal_label = UiKit.label("Hedef", &"LabelSection")
	goal_label.add_theme_font_size_override("font_size", 20)
	goal_label.add_theme_color_override("font_color", UiTokens.LAVENDER_DEEP.darkened(0.35))
	goal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_label.clip_text = true
	goal_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	goal_row.add_child(goal_label)
	# Kalın nane çubuk + sağında kendi koyu-mor yüzde pili (çubuğun içine
	# sıkışmış beyaz yazı yok).
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bar_row)
	goal_bar = UiKit.progress_bar(0.0, &"ProgressBarHud", 22.0)
	bar_row.add_child(goal_bar)
	var percent_pill := UiKit.panel(&"PanelHudPercent")
	percent_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	percent_pill.custom_minimum_size = Vector2(56.0, 0.0)
	percent_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_child(percent_pill)
	goal_percent = UiKit.label("0%", &"LabelBadgeOnDark", HORIZONTAL_ALIGNMENT_CENTER)
	percent_pill.add_child(goal_percent)
	UiKit.hud_gloss(goal_bar, 9.0, 0.32, 6.0, _deco_front)
	# Skor hedefi ("+5 000 skor") çubuğun sağ ucunda küçük yazı — hedef adı
	# ile yer için yarışmaz.
	goal_extra = UiKit.label("", &"LabelHudCaptionDark", HORIZONTAL_ALIGNMENT_RIGHT)
	goal_extra.add_theme_font_size_override("font_size", 12)
	goal_extra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	goal_row.add_child(goal_extra)


func _build_strip() -> void:
	strip = EvolutionStrip.new()
	strip.name = "EvolutionStrip"
	add_child(strip)


func _build_overlays() -> void:
	# Durum yazısı ("Taştı!", "Hedef tamam!"): board bölgesinin ortasında,
	# pembe candy oval (`title_oval`) içinde; metin boşken gizli.
	status_plate = UiKit.panel(&"PanelBase")
	status_plate.name = "StatusPlate"
	status_plate.add_theme_stylebox_override("panel",
		UiKit.style("title_oval", UiTokens.PINK, Vector4(34, 6, 34, 12)))
	status_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_plate.visible = false
	add_child(status_plate)
	status_label = UiKit.label("", &"LabelDisplayOnDark", HORIZONTAL_ALIGNMENT_CENTER)
	status_label.name = "StatusLabel"
	status_plate.add_child(status_label)

	combo_label = UiKit.label("", &"LabelDisplayOnDark", HORIZONTAL_ALIGNMENT_CENTER)
	combo_label.name = "ComboLabel"
	combo_label.size = Vector2(160.0, 60.0)
	combo_label.pivot_offset = combo_label.size * 0.5
	add_child(combo_label)
	combo_badge = TextureRect.new()
	combo_badge.texture = BADGE_STARBURST
	combo_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	combo_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	combo_badge.show_behind_parent = true
	combo_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_badge.offset_left = -10.0
	combo_badge.offset_top = -55.0
	combo_badge.offset_right = 170.0
	combo_badge.offset_bottom = 116.0
	combo_label.add_child(combo_badge)

	# Skor pop'u: plakanın sağ kenarından çıkıp hafif yükselen küçük altın
	# "+N" (dünyadaki birleşme noktası "+N"si ayrı; yıldız rozeti yok).
	# Konumu `score_pop_home()` her seferinde plakanın gerçek kenarından okur.
	score_pop = UiKit.label("", &"LabelSectionOnDark", HORIZONTAL_ALIGNMENT_RIGHT)
	score_pop.name = "ScorePop"
	score_pop.size = Vector2(96.0, 32.0)
	score_pop.add_theme_color_override("font_color", UiTokens.GOLD_BRIGHT)
	score_pop.add_theme_color_override("font_shadow_color", Color(0.25, 0.1, 0.35, 0.9))
	score_pop.modulate.a = 0.0
	add_child(score_pop)



## Gelecek banner bölgesi: görünmez, sadece yerleşim sözleşmesinin somut
## düğümü (testler ölçer). v1'de yüksekliği 0.
func _build_banner_seam() -> void:
	banner_seam = Control.new()
	banner_seam.name = "BannerSeam"
	banner_seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner_seam)


# --- Yerleşim -----------------------------------------------------------------

func apply_layout(rects: Dictionary) -> void:
	_layout = rects
	var hud: Rect2 = rects["hud"]
	var view: Rect2 = rects["view"]
	scrim.position = Vector2.ZERO
	scrim.size = Vector2(view.size.x, hud.end.y + SCRIM_TAIL)

	for pair in [[back_button, rects["back"]], [settings_button, rects["settings"]],
			[exit_button, rects["exit"]], [next_plate, rects["next"]],
			[tray_left, rects["tray_left"]], [tray_right, rects["tray_right"]],
			[goal_plate, rects["goal"]]]:
		var control: Control = pair[0]
		var rect: Rect2 = pair[1]
		control.position = rect.position
		control.size = rect.size
		control.pivot_offset = rect.size * 0.5
	var span: Rect2 = rects["score_span"]
	_score_center.position = span.position
	_score_center.size = span.size

	power_bar.apply_layout(rects["slots"])

	var strip_rect: Rect2 = rects["strip"]
	strip.position = strip_rect.position
	strip.size = strip_rect.size
	strip.pivot_offset = strip_rect.size * 0.5

	var board: Rect2 = rects["board"]
	_status_anchor = Vector2(board.get_center().x, board.position.y + board.size.y * 0.46)
	_place_status()
	combo_label.position = Vector2(board.get_center().x - combo_label.size.x * 0.5,
		board.position.y + board.size.y * 0.30)

	var banner: Rect2 = rects["banner"]
	banner_seam.position = banner.position
	banner_seam.size = banner.size


func layout() -> Dictionary:
	return _layout


## Skor pop'unun başlangıç noktası: plakanın sağ kenarı, dikey orta.
func score_pop_home() -> Vector2:
	# Skor kartının sağ omzu: kartın üst kenarına yakın, sağ uç hizası —
	# karta bağlı okunur, Sıradaki'ye değmez.
	var plate: Rect2 = score_plate.get_global_rect()
	return Vector2(plate.end.x - score_pop.size.x - 6.0, plate.position.y - 12.0)


## Durum plakası: metin boşsa gizlenir, doluysa ortalanıp pop'lanır.
func set_status(text: String) -> void:
	status_label.text = text
	if text.is_empty():
		status_plate.visible = false
		return
	status_plate.visible = true
	_place_status()
	UiMotion.pop(status_plate, 1.12)


func _place_status() -> void:
	status_plate.reset_size()
	var size: Vector2 = status_plate.get_combined_minimum_size()
	status_plate.size = size
	status_plate.position = _status_anchor - size * 0.5
	status_plate.pivot_offset = size * 0.5


# --- Veri -----------------------------------------------------------------------

func set_score(value: int) -> void:
	score_label.text = _thousands(value)


func set_next_tier(tier: int) -> void:
	next_art.texture = DUMPLING_VISUAL.TEXTURES[clampi(tier, 1, TierConfig.MAX_TIER) - 1]


## Level başlığı + hedef satırı. Sonsuz modda rozet "SONSUZ", hedef
## satırı rekor; ilerleme çubuğu rekora yaklaşmayı gösterir.
func set_level(level: LevelData, record: int = 0) -> void:
	if level.is_endless:
		level_label.text = "SONSUZ"
		level_label.add_theme_font_size_override("font_size", 15)
		goal_portrait.visible = false
		goal_caption.text = "REKOR"
		goal_label.text = _thousands(record)
		goal_extra.text = ""
		strip.set_target(0)
	else:
		level_label.text = str(level.level_number)
		level_label.add_theme_font_size_override("font_size", 24)
		goal_caption.text = "HEDEF"
		goal_portrait.visible = true
		goal_art.texture = DUMPLING_VISUAL.TEXTURES[clampi(level.target_tier, 1, TierConfig.MAX_TIER) - 1]
		goal_label.text = TierConfig.tier_name(level.target_tier)
		goal_extra.text = "+%s skor" % _thousands(level.target_score) \
			if level.has_score_target() else ""
		strip.set_target(level.target_tier)


func set_goal_progress(ratio: float) -> void:
	goal_bar.value = clampf(ratio, 0.0, 1.0)
	goal_percent.text = "%d%%" % int(round(goal_bar.value * 100.0))


func set_reached_tier(tier: int) -> void:
	strip.set_reached(tier)


static func _thousands(value: int) -> String:
	var text: String = str(absi(value))
	var out: String = ""
	var count: int = 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = " " + out
	return ("-" if value < 0 else "") + out
