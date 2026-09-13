extends Control
## Ses + titreşim QA sahnesi (M8.5-15). DEV ARACI — production navigasyonunda
## YOK, yalnızca doğrudan açılır:
##
##   godot --path . res://tools/audio_qa.tscn
##   (Android'de test etmek için M9'da geçici olarak main scene yapılabilir)
##
## Her olayı 20 dakika oynamadan tetiklemek için: UI, iniş, tier tier merge,
## combo, Tier 8, dört güç, tehlike, fail, devam, satın alma, sandık ve dört
## rarity, titreşim seviyeleri, spam/stres senaryoları. Alt satırda kanal
## sayacı ve atılan çağrılar (soğuma/tavan politikası görünür olsun).

const BUTTON_HEIGHT: float = 52.0

var _status: Label
var _stress_running: bool = false


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_bottom = -60.0
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	scroll.add_child(column)

	_section(column, "UI")
	_button(column, "Buton (ui_tap)", func() -> void: AudioManager.play(&"ui_tap"))
	_button(column, "Sekme (ui_tab)", func() -> void: AudioManager.play(&"ui_tab"))
	_button(column, "Pencere aç / kapat", func() -> void:
		AudioManager.play(&"ui_modal_open")
		get_tree().create_timer(0.6).timeout.connect(func() -> void: AudioManager.play(&"ui_modal_close")))
	_button(column, "Satın alma (ui_purchase) + MEDIUM", func() -> void:
		AudioManager.play(&"ui_purchase"); Haptics.medium())
	_button(column, "Yetersiz Hamur (ui_invalid)", func() -> void: AudioManager.play(&"ui_invalid"))
	_button(column, "Skin tak (ui_equip) + LIGHT", func() -> void:
		AudioManager.play(&"ui_equip"); Haptics.light())
	_button(column, "Anahtar açıldı (ui_toggle_on)", func() -> void: AudioManager.play(&"ui_toggle_on"))

	_section(column, "Çekirdek oyun")
	_button(column, "Bırakma (drop)", func() -> void: AudioManager.play_drop())
	_button(column, "İniş hafif (tier 1, 450 px/s)", func() -> void: AudioManager.play_landing(1, 450.0))
	_button(column, "İniş sert (tier 8, 950 px/s)", func() -> void: AudioManager.play_landing(8, 950.0))
	_button(column, "İniş spam: 10 parça aynı karede", func() -> void:
		for i in 10:
			AudioManager.play_landing(1 + i % 8, 500.0 + 50.0 * i))
	for tier in range(1, 9):
		var t: int = tier
		_button(column, "Merge -> tier %d%s" % [t, "  (premium kutlama + SPECIAL)" if t == 8 else ""],
			func() -> void:
				AudioManager.play_merge(t)
				if t >= TierConfig.MAX_TIER:
					Haptics.special()
				elif t >= AudioManager.MERGE_HIGH_MIN_TIER:
					Haptics.medium()
				else:
					Haptics.light())
	_button(column, "Combo zinciri x2..x6 (0.25 s arayla)", func() -> void: _combo_chain())
	_button(column, "Hızlı merge stresi: 12 merge / 1.2 s", func() -> void: _merge_stress())
	_button(column, "Sonsuz: tier 8 yok oluşu (annihilation) + STRONG", func() -> void:
		AudioManager.play(&"annihilation"); Haptics.strong())
	_button(column, "Tehlike tik'i (danger) x4", func() -> void: _repeat(&"danger", 4, 0.5))
	_button(column, "Taşma (fail) + MEDIUM", func() -> void:
		AudioManager.play(&"fail"); Haptics.medium())
	_button(column, "Round kaybedildi (round_lose)", func() -> void: AudioManager.play(&"round_lose"))
	_button(column, "Round kazanıldı (round_win)", func() -> void: AudioManager.play(&"round_win"))
	_button(column, "Devam (revive) + MEDIUM", func() -> void:
		AudioManager.play(&"revive"); Haptics.medium())

	_section(column, "Güçler")
	_button(column, "Güç seçildi (power_arm)", func() -> void: AudioManager.play(&"power_arm"))
	_button(column, "Bomba: whoosh -> patlama (+STRONG)", func() -> void:
		AudioManager.play(&"bomb_whoosh")
		get_tree().create_timer(0.28).timeout.connect(func() -> void:
			AudioManager.play(&"bomb_impact"); Haptics.strong()))
	_button(column, "Büyütücü (upgrade + merge tier 5) + MEDIUM", func() -> void:
		AudioManager.play(&"upgrade"); AudioManager.play_merge(5); Haptics.medium())
	_button(column, "Sarsıntı (shake) + MEDIUM", func() -> void:
		AudioManager.play(&"shake"); Haptics.medium())
	_button(column, "Temizleyici: 12 puf (40 ms arayla) + LIGHT", func() -> void:
		Haptics.light()
		for i in 12:
			get_tree().create_timer(0.04 * i).timeout.connect(func() -> void:
				AudioManager.play(&"clear_puff", 1.0 + 0.04 * float(1 + i % 2))))

	_section(column, "İlerleme / ödül")
	_button(column, "Yıldızlar x3 (star_reveal)", func() -> void: _stars())
	_button(column, "Sandık açılış (chest_open)", func() -> void: AudioManager.play(&"chest_open"))
	_button(column, "Ödül Common + LIGHT", func() -> void:
		AudioManager.play_reward(SkinData.Rarity.COMMON); Haptics.light())
	_button(column, "Ödül Rare + MEDIUM", func() -> void:
		AudioManager.play_reward(SkinData.Rarity.RARE); Haptics.medium())
	_button(column, "Ödül Epic + MEDIUM", func() -> void:
		AudioManager.play_reward(SkinData.Rarity.EPIC); Haptics.medium())
	_button(column, "Ödül Legendary + SPECIAL", func() -> void:
		AudioManager.play_reward(SkinData.Rarity.LEGENDARY); Haptics.special())
	_button(column, "Günlük ödül (daily_reward)", func() -> void: AudioManager.play(&"daily_reward"))
	_button(column, "Level açıldı (level_unlock)", func() -> void: AudioManager.play(&"level_unlock"))

	_section(column, "Titreşim (yalnızca cihazda hissedilir)")
	_button(column, "LIGHT", func() -> void: Haptics.light())
	_button(column, "MEDIUM", func() -> void: Haptics.medium())
	_button(column, "STRONG", func() -> void: Haptics.strong())
	_button(column, "SPECIAL (iki darbe)", func() -> void: Haptics.special())
	_button(column, "Spam: 20 x LIGHT aynı anda (1 darbe beklenir)", func() -> void:
		for i in 20:
			Haptics.light())

	_section(column, "Ayarlar")
	_button(column, "SFX aç/kapat", func() -> void:
		SaveManager.set_sfx_enabled(not SaveManager.sfx_enabled()))
	_button(column, "Titreşim aç/kapat", func() -> void:
		SaveManager.set_haptics_enabled(not SaveManager.haptics_enabled()))
	_button(column, "Sayaçları sıfırla", func() -> void:
		AudioManager.play_count.clear(); AudioManager.drop_count.clear(); Haptics.reset_counters())

	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status.offset_top = -60.0
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.add_theme_font_size_override("font_size", 14)
	add_child(_status)


func _process(_delta: float) -> void:
	var playing: int = 0
	for voice in AudioManager._voices:
		if voice.playing:
			playing += 1
	var dropped: int = 0
	for v in AudioManager.drop_count.values():
		dropped += int(v)
	var played: int = 0
	for v in AudioManager.play_count.values():
		played += int(v)
	_status.text = "kanal %d/%d · çalındı %d · atıldı (soğuma/tavan) %d · SFX %s · titreşim %s (%s) · darbe %d / bastırılan %d" % [
		playing, AudioManager.VOICE_COUNT, played, dropped,
		"açık" if SaveManager.sfx_enabled() else "KAPALI",
		"açık" if SaveManager.haptics_enabled() else "KAPALI",
		"destekli" if Haptics.is_supported() else "bu platformda yok",
		Haptics.dispatch_count, Haptics.suppressed_count]


# --- Senaryolar ---

func _combo_chain() -> void:
	for i in 5:
		var count: int = i + 2
		get_tree().create_timer(0.25 * i).timeout.connect(func() -> void:
			AudioManager.play_merge(2 + i % 3)
			AudioManager.play_combo(count)
			Haptics.light())


func _merge_stress() -> void:
	if _stress_running:
		return
	_stress_running = true
	for i in 12:
		get_tree().create_timer(0.1 * i).timeout.connect(func() -> void:
			AudioManager.play_landing(1 + i % 4, 600.0)
			AudioManager.play_merge(1 + i % 7)
			Haptics.light()
			if i == 11:
				_stress_running = false)


func _repeat(id: StringName, times: int, gap: float) -> void:
	for i in times:
		get_tree().create_timer(gap * i).timeout.connect(func() -> void: AudioManager.play(id))


func _stars() -> void:
	for i in 3:
		get_tree().create_timer(0.4 * i).timeout.connect(func() -> void:
			AudioManager.play(&"star_reveal", 1.0 + 0.12 * float(i)))


# --- Yapı ---

func _section(parent: Control, title: String) -> void:
	var label := Label.new()
	label.text = "— %s —" % title
	label.add_theme_font_size_override("font_size", 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)


func _button(parent: Control, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.pressed.connect(action)
	parent.add_child(button)
