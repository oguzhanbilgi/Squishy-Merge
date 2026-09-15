class_name GameplayHud
extends CanvasLayer
## Production oyun HUD'u (M8.6-02). Tek tasarlanmış üst bölge:
##
##   Satır 1:  [Geri][Ayarlar]    [★ SKOR 1 240]     [SIRADAKI ●][Çıkış]
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
const TUTORIAL_POSE: Texture2D = preload("res://assets/visual/ui/tutorial_pose.png")
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
var goal_extra: Label
var goal_bar: ProgressBar
var status_label: Label
var status_plate: PanelContainer
var combo_label: Label
var combo_badge: TextureRect
var score_pop: Label
var tutorial: VBoxContainer
var scrim: TextureRect
var banner_seam: Control

var _score_center: CenterContainer
var _layout: Dictionary = {}
var _status_anchor: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_scrim()
	_build_row1()
	_build_row2()
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
	score_plate = UiKit.panel(&"PanelHudScore")
	score_plate.name = "ScorePlate"
	score_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rim := UiKit.patch("frame_round20", UiTokens.NAVY_PURPLE)
	rim.show_behind_parent = true
	rim.offset_left = -3.0
	rim.offset_top = -3.0
	rim.offset_right = 3.0
	rim.offset_bottom = -6.0
	score_plate.add_child(rim)
	var gloss := UiKit.patch("panel_bevel_light", Color(1, 1, 1, 0.36))
	gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_bottom = 26.0
	score_plate.add_child(gloss)
	_score_center.add_child(score_plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_plate.add_child(row)
	var star := UiKit.art(STAR_ART, 34)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(star)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", -10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var score_caption := UiKit.hud_caption("Skor")
	score_caption.theme_type_variation = &"LabelHudCaptionDark"
	score_caption.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	column.add_child(score_caption)
	score_label = UiKit.label("0", &"LabelHudScore", HORIZONTAL_ALIGNMENT_CENTER)
	score_label.custom_minimum_size.x = 124.0
	# Lavanta üstünde beyaz düşük kontrastlı: rakam koyu erik, açık gölge.
	score_label.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	score_label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.45))
	score_label.add_theme_font_size_override("font_size", 32)
	column.add_child(score_label)
	var star2 := UiKit.art(STAR_ART, 22, Color(1, 1, 1, 0.9))
	star2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(star2)

	# Sağ küme: Sıradaki kartı (lavanta çerçeve + krem) + çıkış.
	next_plate = UiKit.hud_card()
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
	next_col.add_child(UiKit.label("SIRADAKI", &"LabelHudCaptionDark", HORIZONTAL_ALIGNMENT_CENTER))
	next_art = UiKit.art(DUMPLING_VISUAL.TEXTURES[0], 34)
	next_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_row.add_child(next_art)
	exit_button = UiKit.hud_icon_button("home", GameplayLayout.SETTINGS_SIZE)
	exit_button.name = "Exit"
	exit_button.pressed.connect(func() -> void: exit_pressed.emit())
	add_child(exit_button)


func _build_row2() -> void:
	# Güç tepsileri: erik bevel, içinde ikişer madalyon (PowerBar slotları
	# tepsinin üstüne yerleşir; tepsi yalnız görsel).
	tray_left = UiKit.plate(&"PanelTray")
	tray_left.name = "TrayLeft"
	tray_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray_left)
	tray_right = UiKit.plate(&"PanelTray")
	tray_right.name = "TrayRight"
	tray_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray_right)
	power_bar = POWER_BAR_SCENE.instantiate()
	power_bar.name = "PowerBar"
	add_child(power_bar)

	# Hedef kartı: lavanta çerçeve + krem kart — ana bilgi modülü.
	goal_plate = UiKit.hud_card()
	goal_plate.name = "GoalPlate"
	add_child(goal_plate)
	var goal_card: PanelContainer = goal_plate.get_meta(&"card")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.SPACE_SM + 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_card.add_child(row)
	# Level rozeti: altın yuvarlak etiket, içinde owner tacı + numara.
	level_badge = UiKit.panel(&"Badge")
	level_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(level_badge)
	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_badge.add_child(badge_row)
	badge_row.add_child(UiKit.art(CROWN_ART, 22))
	level_label = UiKit.label("1", &"LabelBadge")
	badge_row.add_child(level_label)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	# Hiyerarşi: küçük başlık (HEDEF / REKOR) → hedef adı → ilerleme.
	goal_caption = UiKit.hud_caption("Hedef")
	goal_caption.theme_type_variation = &"LabelHudCaptionDark"
	goal_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(goal_caption)
	var goal_row := HBoxContainer.new()
	goal_row.add_theme_constant_override("separation", UiTokens.SPACE_XS + 2)
	goal_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(goal_row)
	goal_art = UiKit.art(DUMPLING_VISUAL.TEXTURES[3], 26)
	goal_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	goal_row.add_child(goal_art)
	goal_label = UiKit.label("Hedef", &"LabelSection")
	goal_label.add_theme_font_size_override("font_size", 21)
	goal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_label.clip_text = true
	goal_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	goal_row.add_child(goal_label)
	goal_bar = UiKit.progress_bar(0.0, &"ProgressBarMint", 14.0)
	column.add_child(goal_bar)
	# Skor hedefi ("+5 000 skor") çubuğun sağ ucunda küçük yazı — hedef adı
	# ile yer için yarışmaz.
	goal_extra = UiKit.label("", &"LabelHudCaption", HORIZONTAL_ALIGNMENT_RIGHT)
	goal_extra.add_theme_color_override("font_color", UiTokens.TEXT_ON_DARK)
	goal_extra.add_theme_font_size_override("font_size", 12)
	goal_extra.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	goal_extra.offset_left = -160.0
	goal_extra.offset_right = -8.0
	goal_extra.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	goal_bar.add_child(goal_extra)


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
	score_pop = UiKit.label("", &"LabelStatOnDark", HORIZONTAL_ALIGNMENT_RIGHT)
	score_pop.name = "ScorePop"
	score_pop.size = Vector2(90.0, 32.0)
	score_pop.add_theme_color_override("font_color", UiTokens.GOLD_BRIGHT)
	score_pop.modulate.a = 0.0
	add_child(score_pop)

	tutorial = VBoxContainer.new()
	tutorial.name = "Tutorial"
	tutorial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial.alignment = BoxContainer.ALIGNMENT_CENTER
	tutorial.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	tutorial.visible = false
	add_child(tutorial)
	var pose := TextureRect.new()
	pose.texture = TUTORIAL_POSE
	pose.custom_minimum_size = Vector2(0, 168)
	pose.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pose.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pose.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial.add_child(pose)
	tutorial.add_child(UiKit.label("sürükle • bırak", &"LabelSectionOnDark", HORIZONTAL_ALIGNMENT_CENTER))


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
	# Plakanın SOL kenarından (sağda Sıradaki kartı var), sağa hizalı metin.
	var plate: Rect2 = score_plate.get_global_rect()
	return Vector2(plate.position.x - score_pop.size.x - 4.0,
		plate.get_center().y - score_pop.size.y * 0.5 + 4.0)


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
		goal_art.visible = false
		goal_caption.text = "REKOR"
		goal_label.text = _thousands(record)
		goal_extra.text = ""
		strip.set_target(0)
	else:
		level_label.text = str(level.level_number)
		goal_caption.text = "HEDEF"
		goal_art.visible = true
		goal_art.texture = DUMPLING_VISUAL.TEXTURES[clampi(level.target_tier, 1, TierConfig.MAX_TIER) - 1]
		goal_label.text = TierConfig.tier_name(level.target_tier)
		goal_extra.text = "+%s skor" % _thousands(level.target_score) \
			if level.has_score_target() else ""
		strip.set_target(level.target_tier)


func set_goal_progress(ratio: float) -> void:
	goal_bar.value = clampf(ratio, 0.0, 1.0)


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
