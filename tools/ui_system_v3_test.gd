extends Node
## TASK/057 — Squishy UI System V3 yapısal testi. Headless; Main kurmaz, kayda dokunmaz (kayıt ailesi yine de bayt
## bayt karşılaştırılır).
##   godot --headless --audio-driver Dummy --path . res://tools/ui_system_v3_test.tscn
##
## Bölümler:
##   A token       ölçüm temeli (A36 1 px = 0.571 dp; TOUCH_TARGET 84 = 48 dp), tipografi ölçeği (≥ 14, sıralı), boşluk /
##                 yarıçap / derinlik / kenar / renk rolleri; roller ayrık; okunurluk kontrastı
##   B tipografi   her V3 rolü Baloo / Nunito (varsayılan fonta düşüş yok), token boyutu, Türkçe büyük harf
##   C CTA         beş tür × boy sınıfları: yükseklik, dokunma hedefi, içerik yüzün içinde; durumlar (pasif / alındı /
##                 tükendi / yok / yetmiyor); basış görseli (yüz çöker, bırakınca döner; pasifte yok); sayaç / fiyat
##   D sahiplik    GestureGuard ile: taze dokunuş tam bir eylem, ACTION_CANCEL 0, kodla pressed 1, gizli düğme 0
##   E rozet       NONE / DOT / COUNT (0 → NONE, 99+) / NEW / CLAIM; köşeye oturtma ebeveyni büyütmez; konteynerde boy ister
##   F kartlar     FeatureCard (hedef, başlık / alt yazı / ilerleme / rozet / CTA / seçili / basış), OfferCard (ödül, süre,
##                 değer, premium, fiyat CTA), PowerCard (stok yalnız rakam, Türkçe ad, reklam CTA durumları, seçili)
##   G iskelet     bölüm başlığı V3 (aksesuar plakada, 24 px); onay penceresi (birincil + ikincil SquishyButton, mesaj, X)
##   H gezinme     NavItem durumları (seçili / değil / basılı / pasif / rozet), GlobalNav API (rozet, pasif, pay, ayak izi)
##   P kaynak      V3 bileşenleri ham renk / 14 px altı yazı / sahne başına stil YAZMAZ; ikinci tema / sistem yok
##   N kayıt       sahibin kayıt ailesi bayt-aynı

const SECTIONS: int = 9
const DIR: String = "user://qa_ui_system_v3"
const PATH: String = DIR + "/save.json"
const V3_FILES: Array[String] = ["res://scripts/ui/squishy_button.gd", "res://scripts/ui/attention_badge.gd",
	"res://scripts/ui/feature_card.gd", "res://scripts/ui/offer_card.gd", "res://scripts/ui/power_card.gd",
	"res://scripts/ui/nav_item.gd", "res://scripts/ui/global_nav.gd"]
const BALOO: Array[String] = ["res://assets/fonts/Baloo2-ExtraBold.ttf", "res://assets/fonts/Baloo2-Bold.ttf"]
const NUNITO: Array[String] = ["res://assets/fonts/Nunito-Bold.ttf", "res://assets/fonts/Nunito-SemiBold.ttf"]

var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _owner_state: Dictionary = {}
var _stage: Control
var _actions: int = 0


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	await get_tree().process_frame
	_owner_state = _owner_snapshot()
	# Hiçbir yol kayıt yazmaz; yine de yazarsa gerçek kayıt değil test yolu (sonda geri alınır).
	DirAccess.make_dir_recursive_absolute(DIR)
	SaveManager.save_path = PATH
	get_window().size = Vector2i(720, 1280)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	await get_tree().process_frame
	_tokens()
	await _typography()
	await _buttons()
	await _ownership()
	await _badges()
	await _cards()
	await _skeletons()
	await _navigation()
	_source()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)
	print("-- N: kayıt")
	SaveManager.save_path = SaveManager.SAVE_PATH
	var wrote: bool = FileAccess.file_exists(PATH)
	for p: String in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	DirAccess.remove_absolute(DIR)
	_c("V3 bileşenleri kayda hiç yazmadı (yönlendirilen yol boş kaldı)", not wrote)
	_c("sahibin gerçek kayıt ailesi (kanonik + .tmp + .bak) bayt-aynı", _owner_snapshot() == _owner_state)
	print("\nSONUC: %d kontrol, %d hata" % [_checks, _fails])
	# Bekleyen queue_free / basış tween'leri bitsin (çıkışta "kaynak hâlâ kullanımda" gürültüsü olmasın).
	for _i in 4:
		await get_tree().process_frame
	get_tree().quit(1 if _fails > 0 else 0)


# --- A: token ------------------------------------------------------------------------------------------------------------

func _tokens() -> void:
	print("-- A: token katmanı")
	_c("A36 ölçümü: 1 px = 0.571 dp (720 tuval / 1080 fiziksel / yoğunluk 2.625)",
		absf(UiTokens.DP_PER_PX_A36 - (1080.0 / 720.0) / 2.625) < 0.001)
	_c("TOUCH_TARGET %d px ≥ 48 dp A36'da (%.1f dp); TOUCH_COMPACT %d px ≥ 36 dp" % [UiTokens.TOUCH_TARGET,
		UiTokens.TOUCH_TARGET * UiTokens.DP_PER_PX_A36, UiTokens.TOUCH_COMPACT],
		UiTokens.TOUCH_TARGET * UiTokens.DP_PER_PX_A36 >= 47.9 and UiTokens.TOUCH_COMPACT * UiTokens.DP_PER_PX_A36 >= 36.0
		and UiTokens.TOUCH_TARGET > UiTokens.TOUCH_MIN)
	var sizes: Array[int] = [UiTokens.TYPE_HERO, UiTokens.TYPE_SCREEN_TITLE, UiTokens.TYPE_SECTION, UiTokens.TYPE_CARD_TITLE,
		UiTokens.TYPE_BODY, UiTokens.TYPE_SECONDARY, UiTokens.TYPE_META]
	var ordered: bool = true
	for i in range(1, sizes.size()):
		ordered = ordered and sizes[i] < sizes[i - 1]
	_c("tipografi ölçeği kesin azalan (kahraman > ekran > bölüm > kart > gövde > ikincil > meta): %s" % str(sizes), ordered)
	var all_min: bool = true
	for size: int in [UiTokens.TYPE_BUTTON_HERO, UiTokens.TYPE_BUTTON, UiTokens.TYPE_BUTTON_COMPACT, UiTokens.TYPE_BADGE,
			UiTokens.TYPE_NAV] + sizes:
		all_min = all_min and size >= UiTokens.TYPE_META
	_c("hiçbir V3 yazı boyutu TYPE_META (14) altında değil", all_min and UiTokens.TYPE_META == 14)
	var spaces: Array[int] = [UiTokens.SPACE_MICRO, UiTokens.SPACE_XS, UiTokens.SPACE_SM, UiTokens.SPACE_MD, UiTokens.SPACE_LG,
		UiTokens.SPACE_XL, UiTokens.SPACE_2XL]
	var spaced: bool = true
	for i in range(1, spaces.size()):
		spaced = spaced and spaces[i] > spaces[i - 1]
	_c("boşluk ölçeği micro < xs < sm < md < lg < xl < 2xl: %s" % str(spaces), spaced)
	_c("yarıçap aileleri kompakt < kontrol < özellik < pencere",
		UiTokens.RADIUS_COMPACT < UiTokens.RADIUS_CONTROL and UiTokens.RADIUS_CONTROL < UiTokens.RADIUS_FEATURE
		and UiTokens.RADIUS_FEATURE < UiTokens.RADIUS_MODAL)
	_c("derinlik: dinlenme dudağı > basılı dudak = düz dudak; üç gölge kademesi büyüyen",
		UiTokens.LIP_REST > UiTokens.LIP_PRESSED and is_equal_approx(UiTokens.LIP_PRESSED, UiTokens.LIP_FLAT)
		and int(UiTokens.DEPTH_RESTING["size"]) < int(UiTokens.DEPTH_ELEVATED["size"])
		and int(UiTokens.DEPTH_ELEVATED["size"]) < int(UiTokens.DEPTH_FLOATING["size"]))
	_c("kenar rolleri: standart < seçili; premium altın; pasif soluk",
		UiTokens.BORDER_STANDARD < UiTokens.BORDER_SELECTED and UiTokens.BORDER_COLOR_PREMIUM.r > 0.9
		and UiTokens.BORDER_COLOR_DISABLED.a < 0.5)
	var roles: Array[Color] = [UiTokens.ROLE_PRIMARY, UiTokens.ROLE_SECONDARY, UiTokens.ROLE_REWARD, UiTokens.ROLE_AD,
		UiTokens.ROLE_CURRENCY, UiTokens.ROLE_PREMIUM, UiTokens.ROLE_DANGER, UiTokens.ROLE_DISABLED, UiTokens.ATTENTION]
	var distinct: bool = true
	for i in roles.size():
		for j in range(i + 1, roles.size()):
			distinct = distinct and not roles[i].is_equal_approx(roles[j])
	_c("eylem rolleri (birincil / ikincil / ödül / reklam / fiyat / premium / yıkıcı / pasif / dikkat) birbirinden ayrık",
		distinct)
	_c("birincil rol = paletin cyan'ı, premium = altın (palet kuralı)", UiTokens.ROLE_PRIMARY == UiTokens.CYAN
		and UiTokens.ROLE_PREMIUM == UiTokens.GOLD)
	_c("seçili gezinme: krem karo üstünde mor ikon kontrastı ≥ 4.5:1 (%.1f)" % _contrast(UiTokens.NAV_SELECTED,
		UiTokens.NAV_ICON_SELECTED), _contrast(UiTokens.NAV_SELECTED, UiTokens.NAV_ICON_SELECTED) >= 4.5)
	_c("seçili gezinme etiketi (TEXT_PRIMARY) krem karoda ≥ 7:1 (%.1f)" % _contrast(UiTokens.NAV_SELECTED,
		UiTokens.TEXT_PRIMARY), _contrast(UiTokens.NAV_SELECTED, UiTokens.TEXT_PRIMARY) >= 7.0)
	_c("cyan / nane yüzde lacivert yazı ≥ 4.5:1", _contrast(UiTokens.ROLE_PRIMARY, UiTokens.TEXT_ON_ACCENT) >= 4.5
		and _contrast(UiTokens.ROLE_REWARD, UiTokens.TEXT_ON_ACCENT) >= 4.5)
	_c("pasif yüzde TEXT_DISABLED ≥ 4.5:1", _contrast(UiTokens.ROLE_DISABLED, UiTokens.TEXT_DISABLED) >= 4.5)
	_c("gezinme: seçili olmayan etiket tepside ≥ 4.5:1 (%.1f)" % _contrast(UiTokens.NAV_TRAY, UiTokens.NAV_LABEL_IDLE),
		_contrast(UiTokens.NAV_TRAY, UiTokens.NAV_LABEL_IDLE) >= 4.5)
	_c("gezinme: merkez Harita ikonu (lacivert) cyan dairede ≥ 4.5:1 (%.1f)" % _contrast(UiTokens.ROLE_PRIMARY,
		UiTokens.TEXT_ON_ACCENT), _contrast(UiTokens.ROLE_PRIMARY, UiTokens.TEXT_ON_ACCENT) >= 4.5)
	_c("özellik kartı: beyaz başlık / alt yazı hub yüzeyinde ≥ 4.5:1 (%.1f)" % _contrast(UiTokens.SURFACE_HUB,
		UiTokens.TEXT_ON_DARK), _contrast(UiTokens.SURFACE_HUB, UiTokens.TEXT_ON_DARK) >= 4.5)
	_c("Hamur yetmiyor: fiyat krem yüzde ≥ 4.5:1 ve yüz pasif griden ayrık", _contrast(UiTokens.ROLE_CURRENCY_MUTED,
		UiTokens.TEXT_INSUFFICIENT) >= 4.5 and absf(_luminance(UiTokens.ROLE_CURRENCY_MUTED)
		- _luminance(UiTokens.ROLE_DISABLED)) > 0.3)
	_c("gezinme etiketi ≥ 18 px (A36'da ≥ 10 dp)", UiTokens.TYPE_NAV >= 18)
	_sections_done += 1


# --- B: tipografi --------------------------------------------------------------------------------------------------------

func _typography() -> void:
	print("-- B: tipografi rolleri")
	var holder := VBoxContainer.new()
	_stage.add_child(holder)
	var labels: Dictionary = {}
	for role: StringName in UiType.V3_ROLES:
		for dark: bool in [false, true]:
			var label: Label = UiType.v3_label("Çiçek İğne Şılar", role, dark)
			holder.add_child(label)
			labels["%s/%s" % [role, dark]] = label
	await get_tree().process_frame
	var fonts_ok: bool = true
	var sizes_ok: bool = true
	var detail: Array[String] = []
	for key: String in labels:
		var label: Label = labels[key]
		var role: StringName = StringName(key.get_slice("/", 0))
		var font: Font = label.get_theme_font("font")
		var path: String = font.resource_path if font != null else ""
		var family_ok: bool = path in BALOO or path in NUNITO
		if not family_ok:
			detail.append("%s=%s" % [key, path])
		fonts_ok = fonts_ok and family_ok
		var size: int = label.get_theme_font_size("font_size")
		sizes_ok = sizes_ok and size == int(UiType.V3_ROLES[role][2]) and size >= UiTokens.TYPE_META
	_c("her V3 rol (krem + koyu) Baloo 2 / Nunito ile — varsayılan fonta düşüş yok %s" % str(detail), fonts_ok)
	_c("her V3 rolün boyutu tokendan ve ≥ 14", sizes_ok)
	var heading_fonts: bool = true
	for role: StringName in [UiType.V3_HERO, UiType.V3_SCREEN_TITLE, UiType.V3_SECTION, UiType.V3_CARD_TITLE,
			UiType.V3_BUTTON, UiType.V3_BADGE, UiType.V3_NAV]:
		heading_fonts = heading_fonts and (labels["%s/false" % role] as Label).get_theme_font("font").resource_path in BALOO
	var body_fonts: bool = true
	for role: StringName in [UiType.V3_BODY, UiType.V3_SECONDARY, UiType.V3_META]:
		body_fonts = body_fonts and (labels["%s/false" % role] as Label).get_theme_font("font").resource_path in NUNITO
	_c("başlık / CTA / rozet / gezinme Baloo; gövde / ikincil / meta Nunito (UiType kuralı)", heading_fonts and body_fonts)
	_c("Türkçe büyük harf: Temizleyici → TEMİZLEYİCİ, ışık → IŞIK, Sarsıntı → SARSINTI",
		UiType.upper_tr("Temizleyici") == "TEMİZLEYİCİ" and UiType.upper_tr("ışık") == "IŞIK"
		and UiType.upper_tr("Sarsıntı") == "SARSINTI")
	_c("v3_label rol meta'sı taşır (tarama için)", (labels["body/false"] as Label).get_meta(&"v3_role") == UiType.V3_BODY)
	holder.queue_free()
	_sections_done += 1


# --- C: CTA ailesi ---------------------------------------------------------------------------------------------------------

func _buttons() -> void:
	print("-- C: SquishyButton türleri, boyları, durumları")
	var holder := VBoxContainer.new()
	holder.position = Vector2(20, 20)
	_stage.add_child(holder)
	var kinds: Array = [[SquishyButton.Kind.PRIMARY, "OYNA"], [SquishyButton.Kind.SECONDARY, "MEYDAN OKUMA"],
		[SquishyButton.Kind.REWARD, "ÖDÜLÜ AL"], [SquishyButton.Kind.REWARDED_AD, "REKLAM İZLE"],
		[SquishyButton.Kind.CURRENCY, "SATIN AL"]]
	var buttons: Array[SquishyButton] = []
	for spec in kinds:
		for size_class: int in [SquishyButton.SizeClass.HERO, SquishyButton.SizeClass.NORMAL, SquishyButton.SizeClass.COMPACT]:
			var button := SquishyButton.new(String(spec[1]), int(spec[0]), size_class)
			button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			if int(spec[0]) == SquishyButton.Kind.REWARDED_AD:
				button.set_ad_progress(1, 2)
			if int(spec[0]) == SquishyButton.Kind.CURRENCY:
				button.set_price(12480)
			holder.add_child(button)
			buttons.append(button)
	await _settle(3)
	var heights_ok: bool = true
	var targets_ok: bool = true
	var fit_ok: bool = true
	var bad: Array[String] = []
	for button: SquishyButton in buttons:
		var expected: float = SquishyButton.HEIGHTS[button.size_class()]
		heights_ok = heights_ok and is_equal_approx(button.size.y, expected)
		var minimum: float = UiTokens.TOUCH_COMPACT if button.size_class() == SquishyButton.SizeClass.COMPACT \
			else UiTokens.TOUCH_TARGET
		targets_ok = targets_ok and button.size.y >= minimum and button.size.x >= minimum
		var face: Rect2 = button.face_rect()
		var row_rect := Rect2(button.row().position, button.row().size)
		var row_min: float = button.row().get_combined_minimum_size().x
		var inside: bool = row_rect.position.y >= face.position.y - 0.5 and row_rect.end.y <= face.end.y + 0.5 \
			and row_min <= row_rect.size.x + 0.5 and button.title_label().get_minimum_size().x <= button.size.x
		if not inside:
			bad.append("%s/%d" % [button.title(), button.size_class()])
		fit_ok = fit_ok and inside
	_c("yükseklik = boy sınıfı (HERO 108 / NORMAL 84 / COMPACT 64), 15 örnek", heights_ok)
	_c("dokunma hedefi: NORMAL / HERO ≥ %d, COMPACT ≥ %d (her iki boyutta)" % [UiTokens.TOUCH_TARGET, UiTokens.TOUCH_COMPACT],
		targets_ok)
	_c("içerik (ikon + başlık + sayaç / fiyat) yüzün içinde, taşma yok %s" % str(bad), fit_ok)
	# Durumlar.
	var b := SquishyButton.new("BAŞLA")
	holder.add_child(b)
	await _settle(2)
	_c("NORMAL: etkin, dinlenme dudağı, yüz çökmemiş", not b.disabled and b.state() == SquishyButton.State.NORMAL
		and is_zero_approx(b.face_offset()))
	b.set_state(SquishyButton.State.DISABLED)
	_c("DISABLED: `disabled`, düz (yüz dinlenmede ofset 0)", b.disabled and is_zero_approx(b.face_offset()))
	b.set_state(SquishyButton.State.NORMAL)
	var reward := SquishyButton.new("ÖDÜLÜ AL", SquishyButton.Kind.REWARD)
	holder.add_child(reward)
	reward.set_state(SquishyButton.State.CLAIMED)
	await _settle(1)
	_c("REWARD CLAIMED: başlık ALINDI, `disabled`, tik ikonu", reward.title() == "ALINDI" and reward.disabled
		and (reward.row().get_node("Icon") as TextureRect).texture == UiKit.icon_texture("check"))
	reward.set_state(SquishyButton.State.NORMAL)
	_c("REWARD tekrar NORMAL: başlık geri ÖDÜLÜ AL, etkin", reward.title() == "ÖDÜLÜ AL" and not reward.disabled)
	var ad := SquishyButton.new("REKLAM İZLE", SquishyButton.Kind.REWARDED_AD, SquishyButton.SizeClass.COMPACT)
	holder.add_child(ad)
	ad.set_ad_progress(0, 2)
	var s0: bool = ad.counter_text() == "0/2" and not ad.disabled
	ad.set_ad_progress(1, 2)
	var s1: bool = ad.counter_text() == "1/2" and not ad.disabled
	ad.set_ad_progress(2, 2)
	var s2: bool = ad.counter_text() == "2/2" and ad.disabled and ad.state() == SquishyButton.State.EXHAUSTED
	_c("REWARDED_AD 0/2 → 1/2 → 2/2: sayaç cipi, 2/2'de EXHAUSTED + `disabled`", s0 and s1 and s2)
	_c("REWARDED_AD film pictosu varsayılan", (ad.row().get_node("Icon") as TextureRect).texture == UiKit.icon_texture("movie"))
	var na := SquishyButton.new("REKLAM YOK", SquishyButton.Kind.REWARDED_AD, SquishyButton.SizeClass.COMPACT)
	holder.add_child(na)
	na.set_state(SquishyButton.State.UNAVAILABLE)
	na.set_ad_progress(0, 2)
	_c("UNAVAILABLE (yaş / rıza / dolgu): ilerleme gelse de pasif kalır", na.disabled
		and na.state() == SquishyButton.State.UNAVAILABLE)
	var price := SquishyButton.new("", SquishyButton.Kind.CURRENCY, SquishyButton.SizeClass.COMPACT)
	holder.add_child(price)
	price.set_price(1240)
	price.set_state(SquishyButton.State.INSUFFICIENT)
	_c("CURRENCY: fiyat '1 240' + Hamur ikonu; INSUFFICIENT dokunulabilir (pasif değil)", price.price_text() == "1 240"
		and not price.disabled and (price.row().get_node("Icon") as TextureRect).texture == SquishyButton.DOUGH_ART)
	_c("INSUFFICIENT fiyatı mercan-koyu (yetmeyen fiyat okunur)", (price.row().get_node("Price") as Label)
		.get_theme_color("font_color").is_equal_approx(UiTokens.TEXT_INSUFFICIENT))
	await _settle(2)
	# Basış görseli (gerçek parmak).
	# Görünür alanda tek başına (yığın ekranın altına taşar — dokunuş oraya ulaşmaz).
	holder.visible = false
	var target := SquishyButton.new("BAS")
	target.position = Vector2(200, 300)
	_stage.add_child(target)
	await _settle(2)
	var pos: Vector2 = _center(target)
	await _finger(pos, true)
	var pressed_offset: float = target.face_offset()
	var row_y: float = target.row().position.y
	await _finger(pos, false)
	await _settle(2)
	_c("basılı: yüz %.0f px çöker (opaklık değil), içerik de iner; bırakınca 0" % pressed_offset,
		pressed_offset >= UiTokens.LIP_REST - UiTokens.LIP_PRESSED - 0.01 and row_y > 0.0
		and is_zero_approx(target.face_offset()) and not target.is_pressed_visual())
	_c("basış UiMotion ile (squash + ui_tap — tek animasyon sistemi)", target.has_meta(&"ui_motion_press"))
	target.set_state(SquishyButton.State.DISABLED)
	await _finger(pos, true)
	var disabled_pressed: bool = target.is_pressed_visual()
	await _finger(pos, false)
	_c("pasif düğmede basış görseli yok", not disabled_pressed)
	target.set_state(SquishyButton.State.NORMAL)
	target.set_scrollable(true)
	_c("kaydırılabilir kip: MOUSE_FILTER_PASS (M8.6-06.3 kuralı)", target.mouse_filter == Control.MOUSE_FILTER_PASS)
	_c("odak yok (dokunmatik oyun, FOCUS_NONE)", target.focus_mode == Control.FOCUS_NONE)
	holder.queue_free()
	target.queue_free()
	await _settle(1)
	_sections_done += 1


# --- D: sahiplik ------------------------------------------------------------------------------------------------------------

func _ownership() -> void:
	print("-- D: GestureGuard ile eylem (TASK/055 korunur)")
	var button := SquishyButton.new("ONAYLA")
	button.position = Vector2(200, 400)
	_stage.add_child(button)
	GestureGuard.on_pressed(button, func() -> void: _actions += 1)
	await _settle(3)
	var pos: Vector2 = _center(button)
	_actions = 0
	await _finger(pos, true)
	await _finger(pos, false)
	await _settle(2)
	_c("taze dokunuş: tam bir eylem", _actions == 1)
	_actions = 0
	await _finger(pos, true)
	var cancel := _touch(pos, false)
	cancel.canceled = true
	Input.parse_input_event(cancel)
	Input.flush_buffered_events()
	await _settle(2)
	await _finger(pos, false)
	await _settle(2)
	_c("ACTION_CANCEL: 0 eylem, basış görseli bitti", _actions == 0 and not button.is_pressed_visual())
	_actions = 0
	button.pressed.emit()
	_c("kodla pressed (erişilebilirlik): tam bir eylem", _actions == 1)
	_actions = 0
	button.visible = false
	button.pressed.emit()
	_c("gizli düğmeye ulaşan kod pressed: 0 eylem", _actions == 0)
	button.queue_free()
	var card := FeatureCard.new("GÜNLÜK", "", UiTokens.PINK)
	card.position = Vector2(40, 600)
	card.size = Vector2(640, FeatureCard.HEIGHT)
	_stage.add_child(card)
	GestureGuard.on_pressed(card, func() -> void: _actions += 1)
	await _settle(3)
	_actions = 0
	pos = _center(card)
	await _finger(pos, true)
	var card_pressed: bool = card.is_pressed_visual() and card.face_offset() > 0.0
	await _finger(pos, false)
	await _settle(2)
	_c("özellik kartı: tek dokunma hedefi, basınca yüz çöker, bırakınca tam bir eylem", card_pressed and _actions == 1
		and not card.is_pressed_visual())
	card.queue_free()
	await _settle(1)
	_sections_done += 1


# --- E: rozet ---------------------------------------------------------------------------------------------------------------

func _badges() -> void:
	print("-- E: AttentionBadge API")
	var parent := Control.new()
	parent.custom_minimum_size = Vector2(80, 80)
	parent.size = Vector2(80, 80)
	_stage.add_child(parent)
	var badge := AttentionBadge.new()
	parent.add_child(badge)
	badge.place_at(Vector2(70, 10))
	await _settle(1)
	_c("NONE: görünmez", not badge.visible and badge.mode() == AttentionBadge.Mode.NONE)
	badge.show_dot()
	_c("DOT: görünür, metinsiz, %d px daire, merkez köşede" % int(AttentionBadge.DOT_SIZE), badge.visible
		and badge.text() == "" and is_equal_approx(badge.size.x, AttentionBadge.DOT_SIZE)
		and (badge.position + badge.size * 0.5).is_equal_approx(Vector2(70, 10)))
	badge.show_count(3)
	_c("COUNT 3: '3'", badge.visible and badge.text() == "3" and badge.count() == 3)
	badge.show_count(150)
	_c("COUNT 150: '99+' (taşma yok, hap genişler, merkez korunur)", badge.text() == "99+" and badge.size.x > badge.size.y
		and (badge.position + badge.size * 0.5).is_equal_approx(Vector2(70, 10)))
	badge.show_count(0)
	_c("COUNT 0 → NONE (boş rozet yok)", not badge.visible and badge.mode() == AttentionBadge.Mode.NONE)
	badge.show_new()
	_c("NEW: 'YENİ'", badge.visible and badge.text() == "YENİ")
	badge.show_claim()
	_c("CLAIM (al-hazır): '!'", badge.visible and badge.text() == "!")
	_c("köşeye oturtulan rozet ebeveynin minimumunu büyütmez", parent.get_combined_minimum_size() == Vector2(80, 80)
		and badge.custom_minimum_size == Vector2.ZERO and badge.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	badge.clear()
	_c("clear: görünmez", not badge.visible)
	# Çağrı sırası: kip AĞACA GİRMEDEN verilir (etiket henüz temalanmamış) — hap yine metne göre genişlemeli.
	var early_new := AttentionBadge.new()
	early_new.show_new()
	var early_count := AttentionBadge.new()
	early_count.show_count(150)
	var holder := Control.new()
	_stage.add_child(holder)
	holder.add_child(early_new)
	holder.add_child(early_count)
	await _settle(3)
	var new_label: Label = early_new.get_node("Text")
	var count_label: Label = early_count.get_node("Text")
	_c("ağaca girmeden verilen YENİ / 99+: hap metni sarar (%.0f ≥ %.0f, %.0f ≥ %.0f)" % [early_new.size.x,
		new_label.get_minimum_size().x + 12.0, early_count.size.x, count_label.get_minimum_size().x + 12.0],
		early_new.size.x >= new_label.get_minimum_size().x + 12.0
		and early_count.size.x >= count_label.get_minimum_size().x + 12.0)
	holder.queue_free()
	var row := HBoxContainer.new()
	_stage.add_child(row)
	var inline := AttentionBadge.new()
	row.add_child(inline)
	inline.show_count(12)
	await _settle(2)
	_c("konteyner içindeki rozet kendi boyunu ister (bölüm başlığı aksesuarı)", inline.size.x >= AttentionBadge.PILL_HEIGHT
		and is_equal_approx(inline.size.y, AttentionBadge.PILL_HEIGHT))
	parent.queue_free()
	row.queue_free()
	await _settle(1)
	_sections_done += 1


# --- F: kartlar -------------------------------------------------------------------------------------------------------------

func _cards() -> void:
	print("-- F: FeatureCard · OfferCard · PowerCard")
	var column := VBoxContainer.new()
	column.position = Vector2(24, 24)
	column.custom_minimum_size = Vector2(672, 0)
	_stage.add_child(column)
	var feature := FeatureCard.new("MEYDAN OKUMA", "Büyük Dumpling yap · 16 hamle", UiTokens.ROLE_SECONDARY,
		load("res://assets/visual/dumpling_tier5.png"))
	column.add_child(feature)
	feature.set_progress(0.6, "3/5")
	feature.badge().show_new()
	await _settle(2)
	_c("FeatureCard: yükseklik ≥ TOUCH_TARGET, başlık + alt yazı + ilerleme + rozet", feature.size.y >= UiTokens.TOUCH_TARGET
		and feature.title_text() == "MEYDAN OKUMA" and feature.subtitle_text() != "" and is_equal_approx(feature.progress_ratio(), 0.6)
		and feature.badge().text() == "YENİ")
	feature.set_progress(-1.0)
	feature.set_subtitle("")
	_c("FeatureCard: ilerleme / alt yazı gizlenebilir (tek satır kart)", feature.progress_ratio() < 0.0
		and feature.subtitle_text() == "")
	feature.set_cta("AÇ")
	await _settle(1)
	_c("FeatureCard CTA: kompakt SquishyButton, fare almaz (kart tek hedef)", feature.cta() != null
		and feature.cta().mouse_filter == Control.MOUSE_FILTER_IGNORE and feature.cta().title() == "AÇ")
	feature.set_selected(true)
	_c("FeatureCard seçili durumu", feature.is_selected())
	await _settle(2)
	var badge_rect := Rect2(feature.badge().position, feature.badge().size)
	_c("FeatureCard YENİ hapı kartın sağ kenarının içinde (%.0f ≤ %.0f)" % [badge_rect.end.x, feature.size.x],
		badge_rect.end.x <= feature.size.x and badge_rect.size.x > badge_rect.size.y)
	var offer := OfferCard.new("BAŞLANGIÇ PAKETİ", "FİYAT")
	column.add_child(offer)
	for type: int in PowerUp.all():
		offer.add_reward(PowerUp.icon(type), "3")
	offer.add_reward(load("res://assets/visual/ui/icon_dough.png"), "500")
	offer.set_timer_text("2g 23s KALDI")
	offer.set_value_tag("ÖRNEK")
	await _settle(2)
	_c("OfferCard: 5 ödül karosu, süre + değer etiketi, fiyat CTA SquishyButton, premium varsayılan",
		offer.reward_count() == 5 and offer.timer_text() == "2g 23s KALDI" and offer.value_tag_text() == "ÖRNEK"
		and offer.price_button() is SquishyButton and offer.is_premium())
	offer.set_premium(false)
	offer.set_timer_text("")
	_c("OfferCard: premium kapatılabilir, süre gizlenebilir", not offer.is_premium() and offer.timer_text() == "")
	_c("OfferCard metin ve fiyat ÇAĞIRANDAN — bileşen ekonomi / satın alma çağırmaz",
		not FileAccess.get_file_as_string("res://scripts/ui/offer_card.gd").contains("purchase("))
	var powers := HBoxContainer.new()
	column.add_child(powers)
	var bomb := PowerCard.new(PowerUp.Type.BOMB, 3)
	var clear := PowerCard.new(PowerUp.Type.CLEAR_SMALL, 0)
	powers.add_child(bomb)
	powers.add_child(clear)
	await _settle(2)
	_c("PowerCard stok YALNIZ rakam ('3' / '0' — 'x' / '×' / 'stok' yok)", bomb.stock_text() == "3"
		and clear.stock_text() == "0" and bomb.stock_text().is_valid_int())
	_c("PowerCard adı Türkçe büyük harf (BOMBA, TEMİZLEYİCİ)", bomb.name_text() == "BOMBA"
		and clear.name_text() == "TEMİZLEYİCİ")
	_c("PowerCard reklam yuvası kota VARSAYMAZ (sayaç boş; kota çağırandan — GAME_DESIGN §5.7.3 / TASK/060)",
		clear.ad_button().counter_text() == "" and clear.ad_button().title() == "REKLAM İZLE")
	clear.ad_button().set_ad_progress(0, 2)
	bomb.ad_button().set_ad_progress(2, 2)
	_c("PowerCard reklam yuvası çağıranın sayacını gösterir: 0/2; 2/2 tükendi", clear.ad_button().counter_text() == "0/2"
		and bomb.ad_button().state() == SquishyButton.State.EXHAUSTED)
	_c("PowerCard kaynakta sabit kota yok", not FileAccess.get_file_as_string("res://scripts/ui/power_card.gd")
		.contains("set_ad_progress("))
	_c("PowerCard reklam CTA kompakt dokunma hedefi (≥ %d px)" % UiTokens.TOUCH_COMPACT,
		clear.ad_button().size.y >= UiTokens.TOUCH_COMPACT)
	bomb.set_stock(1)
	bomb.set_selected(true)
	_c("PowerCard stok güncellenir ve seçilebilir", bomb.stock() == 1 and bomb.stock_text() == "1" and bomb.is_selected())
	var no_ad := PowerCard.new(PowerUp.Type.SHAKE, 2, false)
	_c("PowerCard reklam yuvası isteğe bağlı", no_ad.ad_button() == null)
	no_ad.free()
	column.queue_free()
	await _settle(1)
	_sections_done += 1


# --- G: iskelet --------------------------------------------------------------------------------------------------------------

func _skeletons() -> void:
	print("-- G: bölüm başlığı V3 + onay penceresi")
	var badge := AttentionBadge.new()
	badge.show_count(2)
	var header: HBoxContainer = UiKit.section_header_v3("GÜÇLER", badge)
	_stage.add_child(header)
	await _settle(2)
	var label: Label = header.get_meta(&"title_label")
	_c("bölüm başlığı V3: aynı M8.6 plakası (plate meta), başlık 24 px, aksesuar plakanın içinde",
		header.has_meta(&"plate") and label.get_theme_font_size("font_size") == UiTokens.TYPE_SECTION
		and (header.get_meta(&"plate") as Node).is_ancestor_of(badge))
	header.queue_free()
	var plain: HBoxContainer = UiKit.section_header_v3("KOLEKSİYON")
	_c("aksesuarsız bölüm başlığı: aksesuar meta'sı yok", not plain.has_meta(&"accessory"))
	plain.free()
	var anchor := CenterContainer.new()
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(anchor)
	var frame: Control = UiKit.confirm_shell("EMİN MİSİN?", "Mesaj", "ONAYLA", "VAZGEÇ")
	anchor.add_child(frame)
	await _settle(3)
	var primary: SquishyButton = frame.get_meta(&"primary_button")
	var secondary: SquishyButton = frame.get_meta(&"secondary_button")
	_c("onay penceresi: birincil (ONAYLA, PRIMARY) + ikincil (VAZGEÇ, SECONDARY) SquishyButton, mesaj, oturmuş X",
		primary.kind() == SquishyButton.Kind.PRIMARY and secondary.kind() == SquishyButton.Kind.SECONDARY
		and primary.title() == "ONAYLA" and secondary.title() == "VAZGEÇ"
		and (frame.get_meta(&"message_label") as Label).text == "Mesaj" and frame.get_meta(&"close_button") is Button)
	_c("onay altlığı görünür, düğmeler ≥ TOUCH_TARGET yükseklik", (frame.get_meta(&"footer") as Control).visible
		and primary.size.y >= UiTokens.TOUCH_TARGET and secondary.size.y >= UiTokens.TOUCH_TARGET)
	var single: Control = UiKit.confirm_shell("BİLGİ", "Mesaj", "TAMAM", "")
	# get_meta(ad, null) varsayılansız sayılır ve hata basar — önce has_meta.
	_c("ikincil eylemsiz onay: yalnız birincil", not single.has_meta(&"secondary_button")
		or single.get_meta(&"secondary_button") == null)
	single.free()
	anchor.queue_free()
	await _settle(1)
	_sections_done += 1


# --- H: gezinme bileşenleri ----------------------------------------------------------------------------------------------------

func _navigation() -> void:
	print("-- H: NavItem / GlobalNav bileşen API'si")
	var nav := GlobalNav.new()
	add_child(nav)
	await _settle(3)
	_c("GlobalNav: beş öğe, merkez Harita (1)", nav.items().size() == 5 and nav.item_button(1).is_center())
	nav.set_current(3)
	var selected: Array = nav.items().filter(func(i: NavItem) -> bool: return i.is_selected())
	_c("set_current(3): yalnız Mağaza seçili", selected.size() == 1 and (selected[0] as NavItem).tab() == 3)
	_c("seçili yan öğe: etiket koyu (krem karo üstü), seçili değil: açık", (nav.item_button(3).label_node()
		.get_theme_color("font_color")).is_equal_approx(UiTokens.TEXT_PRIMARY) and (nav.item_button(0).label_node()
		.get_theme_color("font_color")).is_equal_approx(UiTokens.NAV_LABEL_IDLE))
	nav.set_current(1)
	# TASK/057 Tur 2: seçili durum TEK aile — merkez de yan öğeyle aynı krem malzemeyi uygular (etiket aynı krem hapta
	# koyu); cyan dairede ikon lacivert kalır, merkeze özgü ek katman yalnız ince altın dış halka.
	_c("merkez seçili: seçili aileyi uygular (etiket koyu krem hapta, yan öğeyle aynı); ikon cyan üstünde lacivert",
		nav.item_button(1).is_selected() and nav.item_button(1).applied_selection() == NavItem.selected_family()
		and nav.item_button(1).label_node().get_theme_color("font_color").is_equal_approx(UiTokens.TEXT_PRIMARY)
		and (nav.item_button(1).icon_node() as CanvasItem).self_modulate.is_equal_approx(UiTokens.TEXT_ON_ACCENT))
	_c("seçili olmayan öğeler hiçbir seçili malzeme uygulamaz", nav.items().all(func(i: NavItem) -> bool:
		return i.is_selected() or i.applied_selection().is_empty()))
	# Çizim de tek aileden: NavItem._draw seçili dolgu / dudak / ışımayı YALNIZ `_applied`'dan okur (doğrudan seçili
	# token yazmaz) — `applied_selection()` sözleşmesi çizimle ayrışamaz.
	var nav_src: String = FileAccess.get_file_as_string("res://scripts/ui/nav_item.gd")
	var draw_body: String = nav_src.substr(nav_src.find("func _draw() -> void:"),
		nav_src.find("func _set_pressed_visual") - nav_src.find("func _draw() -> void:"))
	_c("NavItem._draw seçili malzemeyi yalnız `_applied`'dan çizer (NAV_SELECTED* tokenı doğrudan yok)",
		not draw_body.is_empty() and draw_body.contains("_applied[\"fill\"]") and draw_body.contains("_applied[\"glow\"]")
		and not draw_body.contains("NAV_SELECTED"))
	nav.set_current(99)
	_c("bilinmeyen hedef: hiçbir öğe seçili değil", nav.items().all(func(i: NavItem) -> bool: return not i.is_selected()))
	nav.badge(0).show_dot()
	nav.badge(2).show_count(4)
	nav.badge(4).show_new()
	_c("rozetler öğe başına: nokta / sayı / YENİ, tepsi düzeni değişmez", nav.badge(0).mode() == AttentionBadge.Mode.DOT
		and nav.badge(2).text() == "4" and nav.badge(4).text() == "YENİ" and nav.badge(9) == null)
	nav.set_item_enabled(4, false)
	_c("pasif öğe: `disabled`, soluk", nav.item_button(4).disabled and nav.item_button(4).modulate.a < 0.6)
	nav.set_item_enabled(4, true)
	_c("pay = %.0f; ayak izi tepsiden merkez taşması kadar yüksek" % nav.reserve(),
		is_equal_approx(nav.footprint().size.y - nav.tray_rect().size.y, NavItem.CENTER_RISE)
		and nav.reserve() > GlobalNav.TRAY_HEIGHT)
	var item: NavItem = nav.item_button(2)
	var pos: Vector2 = _center(item)
	await _finger(pos, true)
	var pressed: bool = item.is_pressed_visual() and item.face_offset() > 0.0
	var cancel := _touch(pos, false)
	cancel.canceled = true
	Input.parse_input_event(cancel)
	Input.flush_buffered_events()
	await _settle(2)
	await _finger(pos, false)
	_c("NavItem basılı görsel (yüz çöker); iptalde biter", pressed and not item.is_pressed_visual())
	nav.queue_free()
	await _settle(1)
	_sections_done += 1


# --- P: kaynak sözleşmesi -----------------------------------------------------------------------------------------------------

func _source() -> void:
	print("-- P: kaynak sözleşmesi")
	var raw_colors: Array[String] = []
	var tiny_fonts: Array[String] = []
	var regex := RegEx.create_from_string("font_size\", (\\d+)")
	for path: String in V3_FILES:
		var src: String = FileAccess.get_file_as_string(path)
		if src.contains("Color(\"") or src.contains("Color8("):
			raw_colors.append(path.get_file())
		for m: RegExMatch in regex.search_all(src):
			if int(m.get_string(1)) < UiTokens.TYPE_META:
				tiny_fonts.append(path.get_file())
	_c("V3 bileşenleri ham hex renk YAZMAZ (yalnız UiTokens) %s" % str(raw_colors), raw_colors.is_empty())
	_c("V3 bileşenlerinde 14 px altı yazı yok %s" % str(tiny_fonts), tiny_fonts.is_empty())
	var kit: String = FileAccess.get_file_as_string("res://scripts/ui/ui_kit.gd")
	var tokens: String = FileAccess.get_file_as_string("res://scripts/ui/ui_tokens.gd")
	_c("V3 = mevcut katmanın evrimi: UiTokens V3 bölümü + UiKit V3 çizicisi + UiType V3 rolleri (yeni sistem dosyası yok)",
		tokens.contains("Squishy UI System V3") and kit.contains("static func draw_candy(")
		and FileAccess.get_file_as_string("res://scripts/ui/ui_type.gd").contains("const V3_ROLES")
		and not FileAccess.file_exists("res://scripts/ui/ui_tokens_v3.gd") and not FileAccess.file_exists("res://scripts/ui/ui_kit_v3.gd"))
	var themes: Array[String] = []
	var dir := DirAccess.open("res://assets/visual")
	for file: String in dir.get_files():
		if file.ends_with(".tres") and file.contains("theme"):
			themes.append(file)
	_c("tek proje teması (ikinci tema yok): %s" % str(themes), themes == ["ui_theme.tres"])
	var nav_src: String = FileAccess.get_file_as_string("res://scripts/ui/global_nav.gd")
	_c("GlobalNav öğeleri GestureGuard.on_pressed ile (doğrudan pressed bağlantısı yok)",
		nav_src.contains("GestureGuard.on_pressed(item,") and not nav_src.contains(".pressed.connect("))
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_c("Main: kabuk görünürlüğü tek noktada (_sync_nav), hedef işleyici aynı hedefi yok sayar",
		main_src.contains("func _sync_nav()") and main_src.contains("if tab == _active_tab and _screens[tab].visible:"))
	_sections_done += 1


# --- Ortak -----------------------------------------------------------------------------------------------------------------------

## Göreli parlaklık kontrastı (WCAG).
func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luminance(c: Color) -> float:
	var channels: Array[float] = []
	for v: float in [c.r, c.g, c.b]:
		channels.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


func _touch(pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = pos
	touch.pressed = pressed
	return touch


func _finger(pos: Vector2, pressed: bool) -> void:
	Input.parse_input_event(_touch(pos, pressed))
	Input.flush_buffered_events()
	await get_tree().process_frame


func _center(control: Control) -> Vector2:
	return get_viewport().get_screen_transform() * control.get_global_rect().get_center()


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for p: String in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null
	return out
