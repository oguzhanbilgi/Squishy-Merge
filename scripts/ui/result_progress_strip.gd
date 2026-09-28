class_name ResultProgressStrip
extends PanelContainer
## Sonuç ekranının KOMPAKT oyuncu ilerlemesi şeridi (TASK/045) — ayrı bir sonuç
## sayfası DEĞİL, altlıktaki özet çipleriyle aynı malzeme (krem `label_round` +
## lavanta kontur). Oyuncu XP'nin varlığını her round Profil'e girmeden görür.
##
##   ÜST        kompakt `PlayerLevelBar` (LV rozeti + ray + "84 / 180 XP") + "+42 XP".
##   SEVİYE     yalnız seviye atlandıysa: altın "SEVİYE ATLADIN!" rozeti (rozetteki
##              LV sayısıyla birlikte "SEVİYE ATLADIN! · LV. 8"). Çok seviye: son seviye.
##   BAŞARIM    yalnız bu round başarım açtıysa: "Başarım açıldı: Yıldız Avcısı" /
##              "2 başarım açıldı".
##
## BLOKLAMAZ: dokunma almaz, sonuç CTA'ları ilk kareden aktif, geçiş reklamı ve
## round sonu akışı değişmedi. Veri yalnız `PlayerProgression.round_summary` (Main,
## round kesinleşince) — göç / geriye dönük açılışlar buraya hiç gelmez. Koşullu
## satırlar baştan yerleşir (şeffaf), akış sırasında belirir: altlık zıplamaz.

const PANEL_MARGIN: Vector4 = Vector4(18, 10, 18, 14)
const GAIN_FORMAT: String = "+%d XP"
const LEVEL_UP_TEXT: String = "SEVİYE ATLADIN! · LV. %d"
const ONE_ACHIEVEMENT: String = "Başarım açıldı: %s"
const MANY_ACHIEVEMENTS: String = "%d başarım açıldı"
const FLOW_DELAY: float = 0.35

var _bar: PlayerLevelBar
var _gain: Label
var _extras: HFlowContainer
var _level_up: PanelContainer
var _level_up_label: Label
var _achievement: PanelContainer
var _achievement_label: Label
var _summary: Dictionary = {}
var _reveal_tween: Tween
var _celebrated: bool = false


func _init() -> void:
	name = "ProgressStrip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiKit.style("label_round", UiTokens.CREAM_DEEP, PANEL_MARGIN))
	var outline := UiKit.flat_plate("label_round", Color(UiTokens.LAVENDER_SURFACE, 0.9))
	outline.show_behind_parent = true
	UiKit.inset(outline, -2.0, -2.0, -2.0, -2.0)
	add_child(outline)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var top := HBoxContainer.new()
	top.name = "Top"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 12)
	column.add_child(top)
	_bar = PlayerLevelBar.new(58.0, 16.0, true)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.level_crossed.connect(_on_level_crossed)
	top.add_child(_bar)
	_gain = UiKit.label("+0 XP", &"LabelTitle", HORIZONTAL_ALIGNMENT_RIGHT)
	_gain.name = "Gain"
	_gain.add_theme_font_size_override("font_size", 26)
	_gain.add_theme_color_override("font_color", UiTokens.MINT_DEEP)
	_gain.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_gain)
	_extras = HFlowContainer.new()
	_extras.name = "Extras"
	_extras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_extras.alignment = FlowContainer.ALIGNMENT_CENTER
	_extras.add_theme_constant_override("h_separation", 10)
	_extras.add_theme_constant_override("v_separation", 6)
	column.add_child(_extras)
	_level_up = _pill(UiTokens.GOLD, UiKit.icon_texture("arrow_up"), UiTokens.TEXT_ON_ACCENT)
	_level_up.name = "LevelUp"
	_level_up_label = _level_up.get_meta(&"label")
	_extras.add_child(_level_up)
	_achievement = _pill(UiTokens.LAVENDER_DEEP, UiKit.icon_texture("trophy"), UiTokens.TEXT_ON_DARK)
	_achievement.name = "Achievement"
	_achievement_label = _achievement.get_meta(&"label")
	_extras.add_child(_achievement)
	visible = false


## Candy rozet: `frame_round20` gövde + picto + Baloo yazı (sonuç kilit rozeti dili).
func _pill(fill: Color, icon_tex: Texture2D, text_color: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", UiKit.style("frame_round20", fill, Vector4(12, 3, 14, 5)))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	pill.add_child(row)
	var picto := UiKit.art(icon_tex, 22.0, text_color)
	picto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(picto)
	# Kırpma YOK: `clip_text` etiketin en küçük genişliğini 0 yapar ve akış kabı rozeti
	# yalnız ikona indirir. En uzun metin ("Başarım açıldı: Squishy Arşivcisi") ~290 px,
	# şerit ~520 px; iki rozet sığmazsa akış alt satıra kaydırır.
	var label := UiKit.label("", &"LabelBadge")
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", text_color)
	row.add_child(label)
	pill.set_meta(&"label", label)
	return pill


## Özeti yerleştirir (akış başlamadan). Boş özet → şerit gizli (eski çağıranlar).
func present(summary: Dictionary) -> void:
	_kill_reveal()
	_summary = summary.duplicate(true)
	_celebrated = false
	visible = not summary.is_empty()
	if summary.is_empty():
		return
	var gained: int = int(summary.get("xp_gained", 0))
	_gain.text = GAIN_FORMAT % gained
	_gain.add_theme_color_override("font_color", UiTokens.MINT_DEEP if gained > 0 else UiTokens.TEXT_TERTIARY)
	_bar.show_xp(int(summary.get("xp_before", 0)))
	var leveled: bool = int(summary.get("levels_gained", 0)) > 0
	_level_up.visible = leveled
	_level_up.modulate.a = 0.0
	_level_up_label.text = LEVEL_UP_TEXT % int(summary.get("level_after", 1))
	var fresh: Array = summary.get("new_achievements", [])
	_achievement.visible = not fresh.is_empty()
	_achievement.modulate.a = 0.0
	if fresh.size() == 1:
		_achievement_label.text = ONE_ACHIEVEMENT % String(AchievementCatalog.find(fresh[0]).get("name", ""))
	elif fresh.size() > 1:
		_achievement_label.text = MANY_ACHIEVEMENTS % fresh.size()
	_extras.visible = leveled or not fresh.is_empty()


## Akışı başlatır: XP sayarak dolar (seviye sınırlarında rozet kutlar), sonra
## koşullu rozetler belirir. Bloklamaz.
func play() -> void:
	if _summary.is_empty():
		return
	_bar.animate_xp(int(_summary.get("xp_before", 0)), int(_summary.get("xp_after", 0)), FLOW_DELAY)
	_kill_reveal()
	_reveal_tween = create_tween()
	_reveal_tween.tween_interval(FLOW_DELAY)
	_reveal_tween.tween_callback(func() -> void: UiMotion.pop(_gain, 1.18))
	var flow: float = 0.0
	if int(_summary.get("xp_after", 0)) > int(_summary.get("xp_before", 0)):
		var crossed: int = int(_summary.get("levels_gained", 0))
		flow = minf(PlayerLevelBar.FLOW_BASE + PlayerLevelBar.FLOW_PER_LEVEL * float(mini(crossed, 4)),
			PlayerLevelBar.FLOW_MAX)
	_reveal_tween.tween_interval(flow)
	_reveal_tween.tween_callback(_reveal_extras)


## Anında son durum (gizleme / yeniden açma / test).
func settle() -> void:
	_kill_reveal()
	_bar.settle()
	if _summary.is_empty():
		return
	_bar.show_xp(int(_summary.get("xp_after", 0)))
	_level_up.modulate.a = 1.0
	_achievement.modulate.a = 1.0


func _reveal_extras() -> void:
	for pill in [_level_up, _achievement]:
		var control: Control = pill
		if control.visible and control.modulate.a < 1.0:
			control.modulate.a = 1.0
			UiMotion.pop(control, 1.12)


func _on_level_crossed(_level: int) -> void:
	# Tek ses / titreşim (çok seviye atlamada her sınırda tekrar etmez).
	if _celebrated:
		return
	_celebrated = true
	AudioManager.play(&"level_unlock")
	Haptics.light()
	if _level_up.visible:
		_level_up.modulate.a = 1.0
		UiMotion.pop(_level_up, 1.14)


func _kill_reveal() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null


# --- Testler / çekim aracı ----------------------------------------------------

func level_bar() -> PlayerLevelBar:
	return _bar


func gain_text() -> String:
	return _gain.text


func level_up_visible() -> bool:
	return visible and _level_up.visible


func level_up_text() -> String:
	return _level_up_label.text if _level_up.visible else ""


func achievement_text() -> String:
	return _achievement_label.text if _achievement.visible else ""


func summary() -> Dictionary:
	return _summary
