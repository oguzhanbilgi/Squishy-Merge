extends CanvasLayer
## Profil (TASK/044) — oyuncunun uzun vadeli kimliği / vitrini / istatistikleri.
## Candy dünyada dikey bir oyun profili; ayar tablosu ya da dashboard DEĞİL.
##
##   ÜST      `ScreenTopBar` (sabit): oturmuş geri (→ Ana Sayfa) · pembe
##            "PROFİL" kurdelesi · sağda dişli çark (→ Ayarlar: Main'in TEK
##            `SettingsPanel`'i açılır; ayar mantığı burada KOPYALANMADI).
##   KİMLİK   krem kart: büyük `AvatarButton` (vitrinin ilk parçası; boşsa
##            kanonik Squishy) · "Oyuncu" (nötr yerel ad — takma ad YOK) · altında
##            seçili UNVAN (TASK/045: dokununca unvan seçici açılır) · "Bu
##            cihazdaki profilin" · avatarın rarity etiketi + adı (ya da kural
##            ipucu) · tam genişlikte Oyuncu Seviyesi satırı (`PlayerLevelBar`:
##            LV. N rozeti + candy XP rayı + "84 / 180 XP" — bir sonraki seviyeye
##            ilerleme; kümülatif XP gösterilmez).
##   VİTRİN   üç `ProfileShowcaseSlot` (ilk yuva AVATAR); dolu yuva → Koleksiyon'da
##            o parçanın detayı, boş yuva → Koleksiyon. Gameplay'e etkisi YOK.
##   BAŞARIMLAR (TASK/045)  "7 / 12" + ray (12/12 altın + yıldız) · sıradaki en fazla
##            3 hedef (her kategorinin ilk açılmamış başarımı, hedefe en yakın önce)
##            · TÜM BAŞARIMLAR → Profil'e ait `AchievementsOverlay` (yeni sekme YOK).
##   İSTATİSTİKLER  2 sütun `ProfileStatTile`: sonsuz rekor · birleştirme ·
##            yıldız · tamamlanan level · oynanan tur · en yüksek tier. Hepsi
##            `PlayerProfile`'dan (kanonik alanlar + iki yeni sayaç); değer
##            yoksa "—", eski kayıtta sayaç "güncellemeden beri" notuyla.
##   GÜÇLER   dört gücün CANLI stoğu (salt okunur — satın alma butonu YOK).
##   KOLEKSİYON  N/20 + ray + rarity çipleri + KOLEKSİYONA GİT.
##
## Kayıt: Profil'in TEK yazma yolu unvan seçimidir (`TitleSelector` →
## `SaveManager.select_title`, açık + farklı unvanda tek yazma). Açılış başarımları
## yalnız BELLEKTE uzlaştırır (disk yazması yok); pencereleri açmak / kapatmak
## yazmaz. Reklam yüzeyi değil (Main: Surface.NONE — banner yok, pencereler de
## banner'sız; yeni reklam yüzeyi owner kararı ister).

signal home_requested
## Dişli çark → Main.open_settings (tek SettingsPanel).
signal settings_requested
signal collection_requested
## Dolu vitrin yuvası → Koleksiyon'da o parçanın detayı.
signal collectible_requested(skin_id: StringName)
## Başarımlar / unvan penceresi açıldı ya da kapandı (Main: 300 ms parmak yatışması —
## hızlı çift dokunuşun ikincisi yeni görünen kontrole düşmesin; TASK/044 koruması).
signal overlay_toggled
## TASK/057: ekran içi pencere (başarımlar / unvan) görünürlüğü değişti — Main gezinme kabuğunu gizler / gösterir.
signal overlay_changed

const TITLE: String = "PROFİL"
const SIDE_MARGIN: float = 24.0
## İlk kart haze bandının altında başlar (Mağaza deseni: boşluk = HAZE_FADE).
const CONTENT_TOP_GAP: float = 28.0
const SECTION_GAP: float = 14.0
const BOTTOM_PADDING: float = 56.0
const HAZE_FADE: float = 28.0
const IDENTITY_HEIGHT: float = 178.0
const AVATAR_SIZE: float = 136.0
const LOCAL_NOTE: String = "Bu cihazdaki profilin"
const AVATAR_HINT: String = "Vitrine eklediğin ilk Squishy avatarın olur."
const SHOWCASE_TITLE: String = "VİTRİN"
const SHOWCASE_NOTE: String = "Vitrin yalnız profilini süsler — oyundaki Squishy'lerin görünümü değişmez."
const STATS_TITLE: String = "İSTATİSTİKLER"
const POWERS_TITLE: String = "GÜÇLER"
const COLLECTION_TITLE: String = "KOLEKSİYON"
const COLLECTION_CTA: String = "KOLEKSİYONA GİT"
const COLLECTION_UNIT: String = "SQUISHY"
const PARTIAL_NOTE: String = "güncellemeden beri"
const ENDLESS_LOCKED_NOTE: String = "Sonsuz mod kilitli"
const ENDLESS_OPEN_NOTE: String = "Sonsuz mod açık"
const TIER_NOTE: String = "Tier %d"
const TIER_MIN_NOTE: String = "Tier %d · en az"
const POWER_TILE: Vector2 = Vector2(159.0, 182.0)
const POWER_WELL: float = 92.0
const POWER_ART: float = 70.0
# --- TASK/045: seviye / unvan / başarımlar ---
const TITLE_BUTTON_HEIGHT: float = 48.0
const TITLE_BUTTON_MARGIN: Vector4 = Vector4(16, 3, 14, 7)
const LEVEL_BADGE: float = 76.0
const LEVEL_RAIL: float = 22.0
const ACHIEVEMENTS_TITLE: String = "BAŞARIMLAR"
const ACHIEVEMENTS_UNIT: String = "BAŞARIM"
const ACHIEVEMENTS_CTA: String = "TÜM BAŞARIMLAR"
const NEXT_GOALS_TEXT: String = "SIRADAKİ HEDEFLERİN"
const ALL_DONE_TEXT: String = "Tüm başarımlar tamam — harikasın!"
const ACHIEVEMENT_PREVIEWS: int = 3
const STAR_ART: Texture2D = preload("res://assets/visual/ui/icon_star_filled.png")
const DUMPLING_VISUAL: GDScript = preload("res://scripts/game/dumpling_visual.gd")
const ENTRY_TIME: float = 0.18
const CHIP_HEIGHT: float = 34.0
const RARITY_TINTS: Dictionary = {
	SkinData.Rarity.COMMON: Color("8a8aa8"),
	SkinData.Rarity.RARE: Color("3f86d0"),
	SkinData.Rarity.EPIC: Color("8e4fc0"),
	SkinData.Rarity.LEGENDARY: Color("d99a2b"),
}

var _bar: ScreenTopBar
var _avatar: AvatarButton
var _name_label: Label
var _avatar_line: HBoxContainer
var _avatar_tag_slot: Control
var _avatar_tag: PanelContainer
var _avatar_name: Label
var _avatar_hint: Label
var _slots: Array[ProfileShowcaseSlot] = []
var _stat_tiles: Dictionary = {}
var _power_counts: Dictionary = {}
var _collection_count: Label
var _collection_star: TextureRect
var _collection_bar: ProgressBar
var _collection_chips: Dictionary = {}
var _collection_cta: Button
var _sections: Dictionary = {}
var _entry_tween: Tween
# TASK/045
var _title_button: Button
var _title_label: Label
var _level_bar: PlayerLevelBar
var _achievement_count: Label
var _achievement_star: TextureRect
var _achievement_bar: ProgressBar
var _achievement_caption: Label
var _achievement_rows: Array[AchievementCard] = []
var _achievement_dividers: Array[Control] = []
var _achievements_cta: Button
var _achievements: AchievementsOverlay
var _titles: TitleSelector
## Test kancası: cihaz üst güvenli payı (A36 punch-hole) masaüstünde okunamaz.
var _safe_top_override: float = -1.0
## TASK/057: küresel gezinme kabuğunun alt payı (Main `set_nav_inset`); kabuksuz 0.
var _nav_inset: float = 0.0

@onready var _root: Control = $Root
@onready var _backdrop: Control = $Root/Backdrop
@onready var _vignette: TextureRect = $Root/Vignette
@onready var _scroll: ScrollContainer = $Root/Scroll
@onready var _margin: MarginContainer = $Root/Scroll/Margin
@onready var _content: VBoxContainer = $Root/Scroll/Margin/Content
@onready var _haze: TextureRect = $Root/Haze


func _ready() -> void:
	_tune_backdrop()
	_vignette.texture = _radial_vignette()
	_haze.texture = _band_gradient(Color(UiTokens.WORLD_INDIGO, 0.78), Color(UiTokens.WORLD_INDIGO, 0.0))
	_bar = ScreenTopBar.new(TITLE, false, "settings")
	# TASK/055: üst çubuk (paylaşılan ScreenTopBar) Profil tarafında sahiplenilir — gezinme / Ayarlar yalnız geçerli
	# dokunuşla (bkz. GestureGuard).
	GestureGuard.own(_bar.back_button())
	GestureGuard.own(_bar.action_button())
	_bar.back_pressed.connect(func() -> void:
		if GestureGuard.allows(_bar.back_button()):
			home_requested.emit())
	_bar.action_pressed.connect(func() -> void:
		if GestureGuard.allows(_bar.action_button()):
			settings_requested.emit())
	_root.add_child(_bar)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_theme_constant_override("separation", int(SECTION_GAP))
	_build_identity()
	_build_showcase()
	_build_achievements()
	_build_stats()
	_build_powers()
	_build_collection()
	_build_overlays()
	_root.resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		if visible:
			_layout()
			_play_entry.call_deferred()
		else:
			# Sekmeden çıkınca Profil pencereleri sessizce kapanır (Koleksiyon detayı gibi).
			_achievements.close(false)
			_titles.close(false))
	SaveManager.showcase_changed.connect(func(_ids: Array) -> void:
		if visible:
			refresh())
	# TASK/045: XP / başarım / unvan yazıldı (unvan seçimi, arka planda açılan başarım):
	# kimlik + başarımlar tazelenir, kaydırma yerinde kalır.
	SaveManager.player_meta_changed.connect(func() -> void:
		if visible:
			_refresh_meta())
	_layout()
	refresh()


# --- Kurulum ------------------------------------------------------------------

func _tune_backdrop() -> void:
	var night: CanvasItem = _backdrop.get_node_or_null("Night")
	if night != null:
		night.modulate = Color(0.80, 0.78, 0.94, 1.0)
	var scrim: ColorRect = _backdrop.get_node_or_null("Scrim")
	if scrim != null:
		scrim.color = Color(0.07, 0.05, 0.18, 0.34)
	var fade: CanvasItem = _backdrop.get_node_or_null("BottomFade")
	if fade != null:
		fade.modulate = Color(1, 1, 1, 0.70)


## Krem kart kabuğu (Koleksiyon / Mağaza kartıyla aynı reçete): erik gölge →
## açık halka → krem gövde + kart yüzü. İçerik `body`'ye (PanelContainer).
## Gövde iç payı `margin` ile GERÇEKTEN uygulanır (`card_bevel_soft`'un pişmiş alt
## dudağı kartın alt kenarından 11–22 px yukarıda — alt pay ≥ 24, içerik dudağa
## binmesin; TASK/044 incelemesi) ve kart içeriğe göre uzar (`height` alt sınır).
func _card(height: float, margin: Vector4 = Vector4(18, 14, 18, 22)) -> PanelContainer:
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.custom_minimum_size = Vector2(0, height)
	var shadow := UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.30))
	UiKit.inset(shadow, -14.0, -6.0, -14.0, -20.0)
	wrap.add_child(shadow)
	var rim := UiKit.flat_plate("frame_round20", UiTokens.LAVENDER_LIGHT)
	UiKit.inset(rim, -4.0, -4.0, -4.0, -4.0)
	wrap.add_child(rim)
	var body := _card_body(margin)
	wrap.add_child(body)
	_fit_to_body(wrap, body, height)
	_content.add_child(wrap)
	body.set_meta(&"wrap", wrap)
	return body


## `PanelCollectionCard` gövdesi, iç payı kart yüzüyle AYNI (tema 10/8/10/12 değil).
static func _card_body(margin: Vector4) -> PanelContainer:
	var body := UiKit.panel(&"PanelCollectionCard")
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_theme_stylebox_override("panel", UiKit.style("card_bevel_soft", UiTokens.CREAM, margin))
	UiKit.card_face(body, margin)
	return body


## Sarmalayıcı en az `min_height`, içerik daha uzunsa gövdenin en küçük boyu kadar.
static func _fit_to_body(wrap: Control, body: PanelContainer, min_height: float) -> void:
	var fit := func() -> void:
		wrap.custom_minimum_size.y = maxf(min_height, body.get_combined_minimum_size().y)
	body.minimum_size_changed.connect(fit)
	fit.call()


func _section(key: StringName, title: String) -> void:
	var header := UiKit.section_header(title)
	header.name = "Header_%s" % String(key)
	_content.add_child(header)
	_sections[key] = header


func _build_identity() -> void:
	var body := _card(IDENTITY_HEIGHT, Vector4(18, 14, 20, 24))
	(body.get_meta(&"wrap") as Control).name = "Identity"
	var stack := VBoxContainer.new()
	stack.name = "IdentityStack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 12)
	body.add_child(stack)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 22)
	stack.add_child(row)
	var avatar_host := Control.new()
	avatar_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_host.custom_minimum_size = Vector2(AVATAR_SIZE + 8.0, AVATAR_SIZE)
	avatar_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(avatar_host)
	_avatar = AvatarButton.new(AVATAR_SIZE, false)
	_avatar.name = "Avatar"
	_avatar.position = Vector2(4.0, 0.0)
	_avatar.size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	avatar_host.add_child(_avatar)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_name_label = UiKit.label(PlayerProfile.display_name(), &"LabelTitle")
	_name_label.name = "PlayerName"
	_name_label.add_theme_font_size_override("font_size", 40)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_name_label)
	# TASK/045: seçili unvan adın hemen altında; dokununca unvan seçici.
	_title_button = _make_title_button()
	column.add_child(_title_button)
	var local := UiKit.label(LOCAL_NOTE, &"LabelCaption")
	local.add_theme_font_size_override("font_size", 15)
	local.add_theme_color_override("font_color", UiTokens.TEXT_TERTIARY)
	column.add_child(local)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size = Vector2(0, 2)
	column.add_child(gap)
	_avatar_line = HBoxContainer.new()
	_avatar_line.name = "AvatarLine"
	_avatar_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar_line.add_theme_constant_override("separation", 8)
	column.add_child(_avatar_line)
	_avatar_tag_slot = Control.new()
	_avatar_tag_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar_tag_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_avatar_line.add_child(_avatar_tag_slot)
	_avatar_name = UiKit.label("", &"LabelSection")
	_avatar_name.add_theme_font_size_override("font_size", 19)
	_avatar_name.clip_text = true
	_avatar_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_avatar_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_avatar_line.add_child(_avatar_name)
	_avatar_hint = UiKit.label(AVATAR_HINT, &"LabelCaption")
	_avatar_hint.name = "AvatarHint"
	_avatar_hint.add_theme_font_size_override("font_size", 15)
	_avatar_hint.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_avatar_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_avatar_hint)
	# TASK/045: Oyuncu Seviyesi — kartın tam genişliğinde, ince lavanta çizgiyle ayrık.
	stack.add_child(UiKit.settings_divider())
	_level_bar = PlayerLevelBar.new(LEVEL_BADGE, LEVEL_RAIL, false)
	stack.add_child(_level_bar)


## Unvan eylemi (TASK/045): lavanta `title_oval` hap — taç (owner sanatı) + unvan adı +
## ok. Genişlik içeriğe göre; ≥ 48 dokunma. Kaydırma hapın üstünden de başlar (PASS).
func _make_title_button() -> Button:
	var button := Button.new()
	button.name = "TitleButton"
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.custom_minimum_size = Vector2(0, TITLE_BUTTON_HEIGHT)
	var normal := UiKit.style("title_oval", UiTokens.LAVENDER_SURFACE, TITLE_BUTTON_MARGIN)
	var pressed := UiKit.style("title_oval", UiTokens.LAVENDER, TITLE_BUTTON_MARGIN)
	for style_name in ["normal", "hover", "focus", "disabled"]:
		button.add_theme_stylebox_override(style_name, normal)
	button.add_theme_stylebox_override("pressed", pressed)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = TITLE_BUTTON_MARGIN.x
	row.offset_right = -TITLE_BUTTON_MARGIN.z
	row.offset_top = TITLE_BUTTON_MARGIN.y
	row.offset_bottom = -TITLE_BUTTON_MARGIN.w
	button.add_child(row)
	var crown := UiKit.art(UiIcons.CROWN, 26.0)
	crown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(crown)
	_title_label = UiKit.label(AchievementCatalog.title_name(AchievementCatalog.DEFAULT_TITLE), &"LabelSection")
	_title_label.name = "Title"
	_title_label.add_theme_font_size_override("font_size", 21)
	row.add_child(_title_label)
	var arrow := UiKit.icon("arrow_next", 20.0, UiTokens.TEXT_SECONDARY)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrow)
	var fit := func() -> void:
		button.custom_minimum_size.x = row.get_combined_minimum_size().x + TITLE_BUTTON_MARGIN.x + TITLE_BUTTON_MARGIN.z
	row.minimum_size_changed.connect(fit)
	fit.call()
	GestureGuard.on_pressed(button, open_title_selector)
	UiMotion.attach_press(button)
	_scroll.scroll_started.connect(func() -> void: UiMotion.release(button))
	return button


## BAŞARIMLAR bölümü (TASK/045): krem kart — kupa + "7 / 12" + ray, sıradaki en fazla 3
## hedef (düz satırlar; kart içinde kart yok), TÜM BAŞARIMLAR → pencere.
func _build_achievements() -> void:
	_section(&"achievements", ACHIEVEMENTS_TITLE)
	var body := _card(180.0, Vector4(20, 14, 20, 24))
	(body.get_meta(&"wrap") as Control).name = "AchievementsCard"
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	body.add_child(column)
	var head := HBoxContainer.new()
	head.name = "Head"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 8)
	column.add_child(head)
	var trophy := UiKit.icon("trophy", 30.0, UiTokens.GOLD_DEEP)
	trophy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(trophy)
	_achievement_count = UiKit.label("0 / 12", &"LabelTitle")
	_achievement_count.name = "Count"
	_achievement_count.add_theme_font_size_override("font_size", 32)
	head.add_child(_achievement_count)
	var unit := UiKit.label(ACHIEVEMENTS_UNIT, &"LabelBadge")
	unit.add_theme_font_size_override("font_size", 15)
	unit.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	unit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(unit)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_achievement_star = UiKit.art(STAR_ART, 28)
	_achievement_star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_achievement_star.visible = false
	head.add_child(_achievement_star)
	_achievement_bar = UiKit.progress_bar(0.0, &"ProgressBarMint", 14.0)
	_achievement_bar.name = "ProgressBar"
	column.add_child(_achievement_bar)
	_achievement_caption = UiKit.label(NEXT_GOALS_TEXT, &"LabelBadge")
	_achievement_caption.name = "Caption"
	_achievement_caption.add_theme_font_size_override("font_size", 15)
	_achievement_caption.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	column.add_child(_achievement_caption)
	for i in ACHIEVEMENT_PREVIEWS:
		if i > 0:
			var line := UiKit.settings_divider()
			column.add_child(line)
			_achievement_dividers.append(line)
		var row := AchievementCard.new(true)
		row.name = "Preview%d" % (i + 1)
		column.add_child(row)
		_achievement_rows.append(row)
	_achievements_cta = UiKit.candy_button(ACHIEVEMENTS_CTA, &"ButtonPrimary", 58.0)
	_achievements_cta.name = "AchievementsCta"
	UiKit.make_candy_button_scrollable(_achievements_cta)
	GestureGuard.on_pressed(_achievements_cta, open_achievements)
	_scroll.scroll_started.connect(func() -> void: UiKit.release_candy_button(_achievements_cta))
	column.add_child(_achievements_cta)


## Profil'e ait iki pencere (TASK/045): üst satırın ÜSTÜNDE, ekranın tamamını kaplar.
func _build_overlays() -> void:
	_achievements = AchievementsOverlay.new()
	_achievements.opened.connect(func() -> void: overlay_toggled.emit())
	_achievements.closed.connect(func() -> void: overlay_toggled.emit())
	_achievements.visibility_changed.connect(func() -> void: overlay_changed.emit())
	_root.add_child(_achievements)
	_titles = TitleSelector.new()
	_titles.opened.connect(func() -> void: overlay_toggled.emit())
	_titles.closed.connect(func() -> void: overlay_toggled.emit())
	_titles.visibility_changed.connect(func() -> void: overlay_changed.emit())
	_titles.title_selected.connect(func(_id: StringName) -> void: _refresh_identity())
	_root.add_child(_titles)


func _build_showcase() -> void:
	_section(&"showcase", SHOWCASE_TITLE)
	var row := HBoxContainer.new()
	row.name = "ShowcaseRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	# Yuva rozetleri kartın üst kenarından taşar: satır üstünde nefes payı.
	var top_room := Control.new()
	top_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_room.custom_minimum_size = Vector2(0, 4)
	_content.add_child(top_room)
	_content.add_child(row)
	for i in SaveManager.SHOWCASE_MAX:
		var slot := ProfileShowcaseSlot.new(i)
		GestureGuard.on_pressed(slot, _on_slot_pressed.bind(i))
		row.add_child(slot)
		_slots.append(slot)
	var note := UiKit.label(SHOWCASE_NOTE, &"LabelCaption", HORIZONTAL_ALIGNMENT_CENTER)
	note.name = "ShowcaseNote"
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", UiTokens.TEXT_ON_DARK_MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(note)


func _build_stats() -> void:
	_section(&"stats", STATS_TITLE)
	var grid := GridContainer.new()
	grid.name = "StatsGrid"
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 14)
	_content.add_child(grid)
	var specs: Array = [
		[&"endless", "SONSUZ REKOR", UiIcons.CROWN, UiTokens.GOLD],
		[&"merges", "BİRLEŞTİRME", DUMPLING_VISUAL.TEXTURES[1], UiTokens.PINK],
		[&"stars", "YILDIZ", UiIcons.STAR_FILLED, UiTokens.GOLD_BRIGHT],
		[&"levels", "TAMAMLANAN LEVEL", UiIcons.FLAG, UiTokens.CYAN],
		[&"rounds", "OYNANAN TUR", UiKit.icon_texture("play"), UiTokens.MINT],
		[&"tier", "EN YÜKSEK TIER", DUMPLING_VISUAL.TEXTURES[0], UiTokens.LAVENDER],
	]
	for spec in specs:
		var tile := ProfileStatTile.new(String(spec[1]), spec[2] as Texture2D, spec[3] as Color)
		tile.name = "Stat_%s" % String(spec[0])
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(tile)
		_stat_tiles[spec[0]] = tile


func _build_powers() -> void:
	_section(&"powers", POWERS_TITLE)
	var row := HBoxContainer.new()
	row.name = "PowerRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_content.add_child(row)
	for type in PowerUp.all():
		row.add_child(_make_power_tile(type))


## Güç kutucuğu (salt okunur): krem kart → candy kuyuda owner güç sanatı →
## "×N" stok → güç adı. Stok 0'da sayı soluk (bilgi; satın alma YOK).
func _make_power_tile(type: PowerUp.Type) -> Control:
	var tile := Control.new()
	tile.name = "Power_%s" % PowerUp.save_key(type)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.custom_minimum_size = POWER_TILE
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shadow := UiKit.patch("popup_glow", Color(0.22, 0.09, 0.36, 0.28))
	UiKit.inset(shadow, -12.0, -4.0, -12.0, -18.0)
	tile.add_child(shadow)
	var rim := UiKit.flat_plate("frame_round20", PowerUp.accent(type).lerp(Color.WHITE, 0.45))
	UiKit.inset(rim, -4.0, -4.0, -4.0, -4.0)
	tile.add_child(rim)
	var body := _card_body(Vector4(8, 12, 8, 24))
	tile.add_child(body)
	_fit_to_body(tile, body, POWER_TILE.y)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	body.add_child(column)
	var well := UiKit.candy_well(PowerUp.icon(type), PowerUp.accent(type), POWER_WELL, POWER_ART)
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(well)
	var count := UiKit.label("×0", &"LabelStat", HORIZONTAL_ALIGNMENT_CENTER)
	count.name = "Count"
	count.add_theme_font_size_override("font_size", 28)
	column.add_child(count)
	var title := UiKit.label(PowerUp.display_name(type), &"LabelBadge", HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(title)
	_power_counts[type] = count
	return tile


func _build_collection() -> void:
	_section(&"collection", COLLECTION_TITLE)
	var body := _card(198.0, Vector4(20, 14, 20, 24))
	(body.get_meta(&"wrap") as Control).name = "CollectionCard"
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	body.add_child(column)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	_collection_count = UiKit.label("0/20", &"LabelTitle")
	_collection_count.name = "Count"
	_collection_count.add_theme_font_size_override("font_size", 32)
	row.add_child(_collection_count)
	var unit := UiKit.label(COLLECTION_UNIT, &"LabelBadge")
	unit.add_theme_font_size_override("font_size", 15)
	unit.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	unit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(unit)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_collection_star = UiKit.art(STAR_ART, 28)
	_collection_star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_collection_star.visible = false
	row.add_child(_collection_star)
	_collection_bar = UiKit.progress_bar(0.0, &"ProgressBarMint", 14.0)
	_collection_bar.name = "ProgressBar"
	column.add_child(_collection_bar)
	var chips := HBoxContainer.new()
	chips.name = "RarityChips"
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_theme_constant_override("separation", 8)
	column.add_child(chips)
	for rarity in [SkinData.Rarity.COMMON, SkinData.Rarity.RARE,
			SkinData.Rarity.EPIC, SkinData.Rarity.LEGENDARY]:
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# `badge_round` (dikey 9-dilim payı 33): çip ≥ 34 px — `label_round`'un 66 px
		# payı 28 px'lik çipte sekme gibi çiziliyordu (TASK/044 incelemesi).
		chip.add_theme_stylebox_override("panel",
			UiKit.style("badge_round", RARITY_TINTS[rarity], Vector4(8, 6, 8, 8)))
		chip.custom_minimum_size = Vector2(0, CHIP_HEIGHT)
		var chip_label := UiKit.label("", &"LabelBadgeOnDark", HORIZONTAL_ALIGNMENT_CENTER)
		chip_label.add_theme_font_size_override("font_size", 14)
		chip_label.clip_text = true
		chip_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		chip.add_child(chip_label)
		chips.add_child(chip)
		_collection_chips[rarity] = chip_label
	_collection_cta = UiKit.candy_button(COLLECTION_CTA, &"ButtonPrimary", 58.0)
	_collection_cta.name = "CollectionCta"
	UiKit.make_candy_button_scrollable(_collection_cta)
	GestureGuard.on_pressed(_collection_cta, func() -> void: collection_requested.emit())
	# Parmak CTA'da başlayıp kaydırırsa BaseButton basışı iptal eder ama
	# button_up yaymaz: basış görseli burada bırakılır (Mağaza 06.3 deseni).
	_scroll.scroll_started.connect(func() -> void: UiKit.release_candy_button(_collection_cta))
	column.add_child(_collection_cta)


# --- Yerleşim -----------------------------------------------------------------

func _safe_top() -> float:
	if _safe_top_override >= 0.0:
		return _safe_top_override
	return UiKit.safe_top(_root.size)


func _layout() -> void:
	if _root == null or _bar == null:
		return
	var view: Vector2 = _root.size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	_bar.layout(view.x, _safe_top())
	_vignette.position = Vector2.ZERO
	_vignette.size = view
	_haze.position = Vector2.ZERO
	_haze.size = Vector2(view.x, _bar.height() + HAZE_FADE)
	var band: GradientTexture2D = _haze.texture as GradientTexture2D
	if band != null and band.gradient != null:
		band.gradient.offsets = PackedFloat32Array([0.0, _bar.height() / _haze.size.y, 1.0])
	# İçerik tam ekran kayar; üst pay = sabit satır + boşluk (Mağaza deseni).
	_scroll.position = Vector2.ZERO
	_scroll.size = view
	_margin.add_theme_constant_override("margin_left", int(SIDE_MARGIN))
	_margin.add_theme_constant_override("margin_right", int(SIDE_MARGIN))
	_margin.add_theme_constant_override("margin_top", int(_bar.height() + CONTENT_TOP_GAP))
	_margin.add_theme_constant_override("margin_bottom", int(BOTTOM_PADDING + UiKit.bottom_inset(view) + _nav_inset))


# --- Tazeleme -----------------------------------------------------------------

## Sekmeye her girişte (main._show_tab) ve vitrin değişince: hepsi kanonik
## modelden (PlayerProfile / SkinEntry). Kaydırma en üste. TASK/045: önce kanonik
## istatistiğin desteklediği başarımlar BELLEKTE uzlaştırılır (güvenli yedek; disk
## yazması yok, kutlama yok) — sonra her şey aynı kaynaktan okunur.
func refresh() -> void:
	SaveManager.reconcile_achievements()
	_refresh_identity()
	var showcase: Array[SkinEntry] = PlayerProfile.showcase_entries()
	for i in _slots.size():
		_slots[i].set_entry(showcase[i] if i < showcase.size() else null)
	_refresh_achievements()
	_refresh_stats()
	var powers: Dictionary = PlayerProfile.power_counts()
	for type in _power_counts:
		var count: int = int(powers.get(type, 0))
		var label: Label = _power_counts[type]
		label.text = "×%d" % count
		label.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY if count > 0 else UiTokens.TEXT_TERTIARY)
	_refresh_collection()
	_refresh_overlays()
	_scroll.scroll_vertical = 0


## Oyuncu ilerlemesi değişti (unvan seçimi / başarım): kaydırmaya dokunmadan kimlik,
## başarımlar ve açık pencere tazelenir.
func _refresh_meta() -> void:
	SaveManager.reconcile_achievements()
	_refresh_identity()
	_refresh_achievements()
	_refresh_overlays()


func _refresh_overlays() -> void:
	if _achievements != null and _achievements.visible:
		_achievements.refresh()
	if _titles != null and _titles.visible:
		_titles.refresh()


func _refresh_identity() -> void:
	_name_label.text = PlayerProfile.display_name()
	_title_label.text = PlayerProfile.selected_title_name()
	_level_bar.show_xp(PlayerProfile.player_xp())
	var avatar: SkinEntry = PlayerProfile.avatar_entry()
	_avatar.set_entry(avatar)
	if _avatar_tag != null:
		_avatar_tag_slot.remove_child(_avatar_tag)
		_avatar_tag.queue_free()
		_avatar_tag = null
	var has_avatar: bool = not avatar.is_default()
	_avatar_line.visible = has_avatar
	_avatar_hint.visible = not has_avatar
	if has_avatar:
		_avatar_tag = UiKit.rarity_tag(int(avatar.rarity))
		(_avatar_tag.get_meta(&"title_label") as Label).add_theme_font_size_override("font_size", 14)
		_avatar_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_avatar_tag_slot.add_child(_avatar_tag)
		_avatar_tag_slot.custom_minimum_size = _avatar_tag.get_combined_minimum_size()
		_avatar_tag.size = _avatar_tag_slot.custom_minimum_size
		_avatar_name.text = avatar.display_name


func _refresh_achievements() -> void:
	var unlocked: int = PlayerProfile.achievements_unlocked_count()
	var total: int = PlayerProfile.achievements_total()
	var complete: bool = total > 0 and unlocked >= total
	_achievement_count.text = "%d / %d" % [unlocked, total]
	_achievement_count.add_theme_color_override("font_color", UiTokens.GOLD_DEEP if complete else UiTokens.TEXT_PRIMARY)
	_achievement_bar.value = float(unlocked) / float(maxi(total, 1))
	_achievement_bar.theme_type_variation = &"ProgressBarGold" if complete else &"ProgressBarMint"
	_achievement_star.visible = complete
	_achievement_caption.text = ALL_DONE_TEXT if complete else NEXT_GOALS_TEXT
	_achievement_caption.add_theme_color_override("font_color", UiTokens.GOLD_DEEP if complete else UiTokens.TEXT_SECONDARY)
	var goals: Array[Dictionary] = PlayerProfile.next_goal_rows(ACHIEVEMENT_PREVIEWS)
	for i in _achievement_rows.size():
		var shown: bool = i < goals.size()
		if shown:
			_achievement_rows[i].setup(goals[i])
		_achievement_rows[i].visible = shown
		if i > 0:
			_achievement_dividers[i - 1].visible = shown


func _refresh_stats() -> void:
	var record: int = PlayerProfile.endless_high_score()
	var endless_open: bool = PlayerProfile.is_endless_unlocked()
	(_stat_tiles[&"endless"] as ProfileStatTile).set_value(
		GameplayHud._thousands(record) if record > 0 else "",
		"" if endless_open else ENDLESS_LOCKED_NOTE)
	(_stat_tiles[&"merges"] as ProfileStatTile).set_value(GameplayHud._thousands(PlayerProfile.total_merges()))
	(_stat_tiles[&"stars"] as ProfileStatTile).set_value("%d/%d" % [PlayerProfile.total_stars(), PlayerProfile.max_stars()])
	(_stat_tiles[&"levels"] as ProfileStatTile).set_value(
		"%d/%d" % [PlayerProfile.completed_levels(), PlayerProfile.level_count()],
		ENDLESS_OPEN_NOTE if endless_open else "")
	(_stat_tiles[&"rounds"] as ProfileStatTile).set_value(GameplayHud._thousands(PlayerProfile.rounds_played()),
		PARTIAL_NOTE if PlayerProfile.counters_partial() else "")
	var tier: int = PlayerProfile.highest_tier()
	var tier_tile: ProfileStatTile = _stat_tiles[&"tier"]
	if tier > 0:
		# Sayaçlardan önceki ilerlemeden türetilen değer bir alt sınır: "en az".
		tier_tile.set_value(TierConfig.tier_name(tier),
			(TIER_MIN_NOTE if PlayerProfile.highest_tier_is_lower_bound() else TIER_NOTE) % tier)
		tier_tile.set_art(DUMPLING_VISUAL.TEXTURES[tier - 1], TierConfig.color(tier))
	else:
		tier_tile.set_value("")
		tier_tile.set_art(DUMPLING_VISUAL.TEXTURES[0], UiTokens.LAVENDER)


func _refresh_collection() -> void:
	var owned: int = PlayerProfile.collection_count()
	var total: int = PlayerProfile.collection_total()
	_collection_count.text = "%d/%d" % [owned, total]
	_collection_bar.value = float(owned) / float(maxi(total, 1))
	var complete: bool = total > 0 and owned >= total
	_collection_bar.theme_type_variation = &"ProgressBarGold" if complete else &"ProgressBarMint"
	_collection_star.visible = complete
	for row in PlayerProfile.collection_by_rarity():
		var label: Label = _collection_chips[row["rarity"]]
		label.text = "%s %d/%d" % [SkinData.rarity_display_upper(row["rarity"]), row["owned"], row["total"]]


func _play_entry() -> void:
	if not is_inside_tree() or not visible:
		return
	if _entry_tween != null and _entry_tween.is_valid():
		_entry_tween.kill()
	_scroll.modulate.a = 0.0
	_entry_tween = create_tween()
	_entry_tween.tween_property(_scroll, "modulate:a", 1.0, ENTRY_TIME)


# --- Eylemler -----------------------------------------------------------------

func _on_slot_pressed(slot: int) -> void:
	var entry: SkinEntry = _slots[slot].entry()
	# Dokunuş sesi basışta (UiMotion.attach_press) — burada ikinci kez çalınmaz.
	if entry != null and not entry.is_default():
		collectible_requested.emit(entry.id)
	else:
		collection_requested.emit()


## TÜM BAŞARIMLAR (TASK/045): Profil'e ait pencere; kayda yazmaz.
func open_achievements() -> void:
	if _titles.visible:
		return
	SaveManager.reconcile_achievements()
	_achievements.open()


## Unvan eylemi (TASK/045): unvan seçici; tek yazma yolu seçicinin kendisinde.
func open_title_selector() -> void:
	if _achievements.visible:
		return
	SaveManager.reconcile_achievements()
	_titles.open()


## Başarımlar ya da unvan penceresi açık mı (Main: otomatik günlük pencere bunun
## üstüne açılmaz — kapanınca Profil tazelenip pencerenin altında başa kayıyordu).
func has_open_overlay() -> bool:
	return (_achievements != null and _achievements.visible) or (_titles != null and _titles.visible)


## Android geri: açık unvan seçici / başarımlar penceresi kapanır (değişiklik yok) →
## true; pencere yoksa false (Main Ana Sayfa'ya döner; Ayarlar Main'de).
func handle_back() -> bool:
	if _titles.handle_back():
		return true
	return _achievements.handle_back()


# --- Dokular ------------------------------------------------------------------

static func _band_gradient(top: Color, bottom: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([top, top, bottom])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 8
	tex.height = 128
	return tex


static func _radial_vignette() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	gradient.colors = PackedColorArray([Color(0.2, 0.08, 0.32, 0.0),
		Color(0.2, 0.08, 0.32, 0.0), Color(0.2, 0.08, 0.32, 0.30)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 128
	tex.height = 128
	return tex


# --- Testler / çekim aracı ----------------------------------------------------

## TASK/057: küresel gezinme kabuğunun alt payı (tuval px): son içerik kabuğun üstüne kayar.
func set_nav_inset(px: float) -> void:
	_nav_inset = maxf(px, 0.0)
	_layout()


func _layout_with_safe_top(safe_top: float) -> void:
	_safe_top_override = safe_top
	_layout()
	# TASK/045: Profil'in pencereleri de aynı üst payın altında ortalanır.
	_achievements.layout_with_safe_top(safe_top)
	_titles.layout_with_safe_top(safe_top)


func top_bar() -> ScreenTopBar:
	return _bar


func settings_button() -> Button:
	return _bar.action_button()


func scroll() -> ScrollContainer:
	return _scroll


func content() -> VBoxContainer:
	return _content


func avatar() -> AvatarButton:
	return _avatar


func player_name_text() -> String:
	return _name_label.text


func avatar_line_text() -> String:
	return _avatar_name.text if _avatar_line.visible else ""


func avatar_hint_visible() -> bool:
	return _avatar_hint.visible


func showcase_slots() -> Array[ProfileShowcaseSlot]:
	return _slots


func stat_tile(key: StringName) -> ProfileStatTile:
	return _stat_tiles.get(key)


func power_count_text(type: PowerUp.Type) -> String:
	return (_power_counts[type] as Label).text


func collection_count_text() -> String:
	return _collection_count.text


func collection_chip_text(rarity: SkinData.Rarity) -> String:
	return (_collection_chips[rarity] as Label).text


func collection_cta() -> Button:
	return _collection_cta


func section(key: StringName) -> Control:
	return _sections.get(key)


# TASK/045

func title_button() -> Button:
	return _title_button


func title_text() -> String:
	return _title_label.text


func level_bar() -> PlayerLevelBar:
	return _level_bar


func achievements_count_text() -> String:
	return _achievement_count.text


func achievements_bar() -> ProgressBar:
	return _achievement_bar


func achievements_caption_text() -> String:
	return _achievement_caption.text


func achievement_previews() -> Array[AchievementCard]:
	var out: Array[AchievementCard] = []
	for row in _achievement_rows:
		if row.visible:
			out.append(row)
	return out


func achievements_cta() -> Button:
	return _achievements_cta


func achievements_overlay() -> AchievementsOverlay:
	return _achievements


func title_selector() -> TitleSelector:
	return _titles
