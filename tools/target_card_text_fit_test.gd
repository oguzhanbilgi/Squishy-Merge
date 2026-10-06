extends Node
## TASK/056 — HUD hedef kartı ad sığdırma testi (gerçek GameBoard + production GameplayHud yerleşimi).
## Headless. SAHİBİN KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_target_card_fit/` altına
## yönlendirilir; gerçek kayıt ailesinin (kanonik + .tmp + .bak) baytları başta / sonda karşılaştırılır.
##
##   godot --headless --audio-driver Dummy --path . res://tools/target_card_text_fit_test.tscn
##
## "Kırpılmadı" kanıtı kaynak metni değil: etiketin kapsayıcıdan aldığı GERÇEK genişlik, kendi tema
## fontu / puntosu ile TextServer'da Label'ın kendi kırpma geçişi (`shaped_text_overrun_trim_to_width`)
## yeniden koşulur — trim / üç nokta konumu -1 olmalı. Sözleşme (TASK/056): ad 20 px tasarım
## puntosunda, sığmazsa 1 px adımlarla en az 16 px'e iner (ölçülen genişlik + 2 px pay <= etiket
## genişliği, punto en büyük uygun değer); tabanda da sığmayan metin kartın içinde üç noktayla
## kesilir; skor hedefi ("+N skor") başlık satırında, ad satırında yer tutmaz; kart geometrisi aynen.
##
## Bölümler:
##   A  kanonik Türkçe T5   L03 + günlük meydan okuma (BUGÜN rozeti): "Büyük Dumpling" tam görünür
##   B  T1–T8 + L1–L10      sekiz tier adı ve on gerçek level; L8 / L10 skor hedefi başlık satırında
##   C  İngilizce           ürün tek dilli (çeviri kaynağı yok) → Latin harfli TEST metni vekili
##   D  Arapça / RTL        ürün RTL yerelleştirmesi yok → kart `layout_direction = RTL` TEST vekili;
##                          üretim yönü zorlamıyor (INHERITED / AUTO)
##   E  dar genişlik        720 tuval en dar genişlik (expand); 720x1280 / 1560 + üst pay 61 (A36) /
##                          1600 / banner 100 kompakt; geniş tuvalde (960) ad taban puntoya döner
##   F  hiyerarşi           kart / rozet / portre / satır y'leri / çubuk aynen; ad satırı yüksekliği
##                          taban puntoda sabit
##   G  uzun metin stresi   T5'ten biraz uzun → sığar; aşırı uzun → taban 16 px + kart içinde üç nokta
##   H  komşu bağlamlar     sonsuz (REKOR), meydan okuma T6, tutorial board (spot dikdörtgeni aynen),
##                          aynı HUD'da yeniden set_level anında yeniden sığdırma
##   I  kayıt               sahibin kayıt ailesi bayt-aynı

const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const DIR: String = "user://qa_target_card_fit"
const PATH: String = DIR + "/save.json"
const THU: String = "2026-10-01"
const SECTIONS: int = 9
## TASK/056 ürün sözleşmesi (testin kendi kopyası; üretim sabitleri ayrıca karşılaştırılır).
const BASE_SIZE: int = 20
const MIN_SIZE: int = 16
const SLACK: float = 2.0
const CANON_NAMES: Array[String] = ["Mini Dumpling", "Küçük Dumpling", "Dumpling", "Şişkin Dumpling",
	"Büyük Dumpling", "Dev Dumpling", "Jumbo Dumpling", "Dumpling Kralı"]
const VIEW: Vector2 = Vector2(720, 1280)

var _board: Node2D
var _hud: GameplayHud
var _owner: Dictionary = {}
var _saved: Dictionary = {}
var _popup_flag_before: bool = true
var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _finished: bool = false


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	_popup_flag_before = DailyRewards.auto_popup_enabled
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_owner = _owner_snapshot()
	_saved = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)
	SaveManager.save_path = PATH
	SaveManager.data = {"highest_level_unlocked": 10, "dough": 335, "powerup_starter_granted": true,
		"onboarding_completed": true, "age_ad_band": "ADULT",
		"powerups": {"bomb": 2, "upgrade": 1, "shake": 1, "clear_small": 3}}
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 240 s'de bitmedi")
			_teardown()
			get_tree().quit(2))
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame

	await _a_canonical_t5()
	await _b_all_tiers_and_levels()
	await _c_latin_proxy()
	await _d_rtl_proxy()
	await _e_widths()
	await _f_hierarchy()
	await _g_stress()
	await _h_neighbours()
	await _free_board()
	_teardown()
	_c("I: sahibin gerçek kaydı ve kardeş .tmp / .bak adları DEĞİŞMEDİ", _owner_snapshot() == _owner)
	_c("I: SaveManager gerçek yola döndü, test klasörü silindi", SaveManager.save_path == SaveManager.SAVE_PATH
		and not DirAccess.dir_exists_absolute(DIR))
	_sections_done += 1
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)
	_finished = true
	print("\nSONUC: %d kontrol, %d hata" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _exit_tree() -> void:
	if not _finished:
		_teardown()


func _teardown() -> void:
	DailyRewards.auto_popup_enabled = _popup_flag_before
	GameplayLayout.set_banner_height(0.0)
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved
	var dir: DirAccess = DirAccess.open(DIR)
	if dir != null:
		for f in dir.get_files():
			dir.remove(f)
		DirAccess.remove_absolute(DIR)


# --- A) Kanonik Türkçe T5 ------------------------------------------------------------------------

func _a_canonical_t5() -> void:
	print("-- A: kanonik Türkçe T5")
	var names: Array[String] = []
	for t in range(1, TierConfig.MAX_TIER + 1):
		names.append(TierConfig.tier_name(t))
	_c("A: kanonik tier adları aynen (kopya kısaltılmadı / değişmedi)", names == CANON_NAMES)
	var constants: Dictionary = _hud_constants()
	_c("A: üretim sözleşme sabitleri: 20 px taban, 16 px okunur taban, 2 px pay",
		constants.get("GOAL_NAME_FONT_SIZE") == BASE_SIZE and constants.get("GOAL_NAME_MIN_FONT_SIZE") == MIN_SIZE
		and is_equal_approx(float(constants.get("GOAL_NAME_FIT_SLACK", -1.0)), SLACK))
	await _make_level(3)
	_c("A: L03 hedef kartı metni tam kanonik 'Büyük Dumpling'", _hud.goal_label.text == "Büyük Dumpling"
		and _hud.goal_label.text == TierConfig.tier_name(5) and _hud.goal_caption.text == "HEDEF")
	_check_fit("A: L03 720x1280", true)
	await _make_challenge(5)
	_c("A: meydan okuma (BUGÜN rozeti) T5 metni tam kanonik", _hud.goal_label.text == "Büyük Dumpling"
		and _hud.level_label.text == "BUGÜN")
	_check_fit("A: meydan okuma T5", true)
	_sections_done += 1


# --- B) T1–T8 + L1–L10 ---------------------------------------------------------------------------

func _b_all_tiers_and_levels() -> void:
	print("-- B: T1–T8 Türkçe + gerçek L1–L10")
	for t in range(1, TierConfig.MAX_TIER + 1):
		var level: LevelData = (load("res://resources/levels/level_03.tres") as LevelData).duplicate()
		level.target_tier = t
		await _make(level)
		_c("B: T%d metni kanonik '%s'" % [t, CANON_NAMES[t - 1]], _hud.goal_label.text == CANON_NAMES[t - 1])
		_check_fit("B: T%d" % t, false)
	var widths: Dictionary = {}
	for n in range(1, 11):
		await _make_level(n)
		var level: LevelData = _board.level
		_check_fit("B: L%02d (%s)" % [n, _hud.goal_label.text], false)
		widths[n] = _hud.goal_label.size.x
		if level.has_score_target():
			var expected: String = "+%s skor" % GameplayHud._thousands(level.target_score)
			_c("B: L%02d skor hedefi '%s' başlık satırında (ad satırında değil)" % [n, expected],
				_hud.goal_extra.text == expected and _hud.goal_extra.get_parent() == _hud.goal_caption.get_parent()
				and _hud.goal_extra.get_parent() != _hud.goal_label.get_parent() and _hud.goal_extra.is_visible_in_tree())
			_c("B: L%02d skor hedefi yazısı HEDEF yazısına / ada / çubuğa değmiyor" % n, _extra_clear())
	_c("B: skor hedefli L8 / L10 ad genişliği skorsuz L7 / L9 ile aynı (yan kardeş yer ayırmıyor)",
		is_equal_approx(widths[8], widths[7]) and is_equal_approx(widths[10], widths[9]))
	_sections_done += 1


# --- C) İngilizce: ürün tek dilli → Latin TEST metni vekili ---------------------------------------

func _c_latin_proxy() -> void:
	print("-- C: İngilizce (ürün tek dilli; Latin TEST metni vekili)")
	var translations: Variant = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	_c("C: üretim dili tek (Türkçe): çeviri kaynağı / yüklü yerel yok — İngilizce kopya yok (N/A)",
		(translations as PackedStringArray).is_empty() and TranslationServer.get_loaded_locales().is_empty())
	await _make_level(3)
	_set_name("Big Dumpling")
	await _frames(2)
	_check_fit("C: Latin vekil 'Big Dumpling'", false)
	_c("C: kısa Latin metin taban puntoda (gereksiz küçültme yok)", _font_size() == BASE_SIZE)
	_set_name("Gigantic Dumpling")
	await _frames(2)
	_check_fit("C: Latin vekil 'Gigantic Dumpling' (T5'ten uzun)", false)
	_sections_done += 1


# --- D) Arapça / RTL vekili ----------------------------------------------------------------------

func _d_rtl_proxy() -> void:
	print("-- D: Arapça / RTL (ürün RTL yerelleştirmesi yok; kart RTL TEST vekili)")
	for n in [3, 8]:
		await _make_level(n)
		var nodes: Array[Control] = [_hud.goal_plate, _hud.goal_label, _hud.goal_caption, _hud.goal_extra]
		var inherited: bool = true
		for node in nodes:
			inherited = inherited and node.layout_direction == Control.LAYOUT_DIRECTION_INHERITED
		_c("D: L%02d üretim yönü zorlamıyor (kart / ad / başlık / skor hedefi INHERITED, ad AUTO)" % n,
			inherited and _hud.goal_label.text_direction == Control.TEXT_DIRECTION_AUTO
			and not _hud.goal_plate.is_layout_rtl())
		_hud.goal_plate.layout_direction = Control.LAYOUT_DIRECTION_RTL
		await _frames(3)
		_c("D: L%02d RTL vekili etkin (ad etiketi RTL yerleşimde)" % n, _hud.goal_label.is_layout_rtl())
		_check_fit("D: L%02d RTL" % n, false)
		var badge: Rect2 = _hud.level_badge.get_global_rect()
		var name_rect: Rect2 = _hud.goal_label.get_global_rect()
		var portrait: Rect2 = _hud.goal_portrait.get_global_rect()
		_c("D: L%02d RTL aynalı sıra: rozet sağda, portre adın sağında" % n,
			badge.position.x > name_rect.end.x and portrait.position.x >= name_rect.end.x)
		if n == 8:
			_c("D: L08 RTL skor hedefi başlığın solunda, değmiyor",
				_hud.goal_extra.get_global_rect().end.x <= _hud.goal_caption.get_global_rect().position.x + 0.5
				and _extra_clear())
		_hud.goal_plate.layout_direction = Control.LAYOUT_DIRECTION_INHERITED
		await _frames(3)
	_sections_done += 1


# --- E) Dar desteklenen genişlik / kompozisyonlar ---------------------------------------------------

func _e_widths() -> void:
	print("-- E: dar desteklenen genişlik (720 tuval) + kompozisyonlar")
	var specs: Array = [[Vector2(720, 1280), 0.0, 0.0], [Vector2(720, 1560), 61.0, 0.0],
		[Vector2(720, 1600), 0.0, 0.0], [Vector2(720, 1440), 0.0, 0.0], [Vector2(720, 1280), 0.0, 100.0]]
	for n in [3, 6, 1]:
		await _make_level(n)
		var width0: float = _hud.goal_label.size.x
		for spec in specs:
			GameplayLayout.set_banner_height(spec[2])
			_board._apply_layout(spec[0], spec[1])
			await _frames(3)
			var tag: String = "E: L%02d %dx%d üst %d banner %d" % [n, int(spec[0].x), int(spec[0].y), int(spec[1]), int(spec[2])]
			_check_fit(tag, false)
			_c(tag + ": ad genişliği 720 tuvalde sabit", is_equal_approx(_hud.goal_label.size.x, width0))
		GameplayLayout.set_banner_height(0.0)
	await _make_level(3)
	var narrow_size: int = _font_size()
	_board._apply_layout(Vector2(960, 1280), 0.0)
	await _frames(3)
	_c("E: geniş tuval (960): ad etiketi genişledi ve T5 taban puntoya döndü (sığdırma genişliğe bağlı)",
		_hud.goal_label.size.x > 200.0 and _font_size() == BASE_SIZE)
	_check_fit("E: L03 960x1280", false)
	_board._apply_layout(VIEW, 0.0)
	await _frames(3)
	_c("E: 720'ye dönüş: yeniden sığdırıldı (aynı punto)", _font_size() == narrow_size)
	_check_fit("E: L03 720x1280 dönüş", false)
	_sections_done += 1


# --- F) Kanonik genişlikte görsel hiyerarşi -----------------------------------------------------------

func _f_hierarchy() -> void:
	print("-- F: kanonik genişlik / görsel hiyerarşi")
	await _make_level(4)
	var unfitted: Dictionary = _geometry()
	var unfitted_size: int = _font_size()
	await _make_level(3)
	var fitted: Dictionary = _geometry()
	var fitted_size: int = _font_size()
	_c("F: karşılaştırma geçerli (L04 adı taban puntoda, L03 adı küçültülmüş)",
		unfitted_size == BASE_SIZE and fitted_size < BASE_SIZE)
	var rects: Dictionary = GameplayLayout.compute(VIEW)
	var goal: Rect2 = rects["goal"]
	_c("F: hedef plakası GameplayLayout dikdörtgeninde (konum + genişlik aynen)",
		_hud.goal_plate.position.is_equal_approx(goal.position) and is_equal_approx(_hud.goal_plate.size.x, goal.size.x))
	var same: bool = true
	for key in unfitted.keys():
		if key == "label_font":
			continue
		same = same and (unfitted[key] as Rect2).is_equal_approx(fitted[key])
	_c("F: küçültülmüş ad kartın hiçbir dikdörtgenini oynatmıyor (rozet / sütun / başlık / ad satırı / portre / çubuk)", same)
	_c("F: level rozeti 60 px, portre 38x32, yüzde pili 56 px (bileşenler küçültülmedi)",
		is_equal_approx(fitted["badge"].size.x, 60.0) and fitted["portrait"].size.is_equal_approx(Vector2(38.0, 32.0))
		and is_equal_approx(fitted["percent"].size.x, 56.0))
	_c("F: ad satırı yüksekliği küçültülmüş adda taban puntodaki adla aynı (dikey düzen oynamaz)",
		is_equal_approx(fitted["goal_row"].size.y, unfitted["goal_row"].size.y)
		and is_equal_approx(fitted["label"].size.y, unfitted["label"].size.y))
	_c("F: sıra aynen: başlık satırı → ad satırı → çubuk satırı", fitted["caption_row"].end.y <= fitted["goal_row"].position.y + 0.5
		and fitted["goal_row"].end.y <= fitted["bar_row"].position.y + 0.5)
	_c("F: başlık satırı skor hedefiyle uzamıyor (başlık etiketinin yüksekliği)",
		is_equal_approx(fitted["caption_row"].size.y, _hud.goal_caption.get_combined_minimum_size().y))
	_sections_done += 1


# --- G) Uzun metin stresi (yalnız TEST metni) -----------------------------------------------------------

func _g_stress() -> void:
	print("-- G: uzun metin stresi (TEST metni, sevkiyat kopyası değil)")
	await _make_level(3)
	var shipped_size: int = _font_size()
	_set_name("Büyük Dumplingler")
	await _frames(2)
	_check_fit("G: T5'ten biraz uzun 'Büyük Dumplingler'", false)
	_set_name("Büyük Dumpling Kralının Tacı")
	await _frames(2)
	var label: Label = _hud.goal_label
	var card: Rect2 = (_hud.goal_plate.get_meta(&"card") as Control).get_global_rect()
	_c("G: aşırı uzun metin okunur tabanın altına inmiyor (tam 16 px)", _font_size() == MIN_SIZE)
	_c("G: tabanda sığmayan metin sınırlı: kırpma + üç nokta etiketin içinde",
		label.clip_text and label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS
		and _shown(label)["ellipsis"] >= 0)
	_c("G: aşırı uzun metin kartın dışına / portreye taşmıyor", card.grow(0.5).encloses(label.get_global_rect())
		and not GameplayLayout.overlaps(label.get_global_rect(), _hud.goal_portrait.get_global_rect()))
	_set_name("Büyük Dumpling")
	await _frames(2)
	_c("G: kanonik ada dönüş anında yeniden sığdırır (aynı punto, kırpma yok)",
		_font_size() == shipped_size and _shown(label)["trim"] < 0)
	_sections_done += 1


# --- H) Komşu bağlamlar ---------------------------------------------------------------------------------

func _h_neighbours() -> void:
	print("-- H: komşu bağlamlar (sonsuz / meydan okuma / tutorial / yeniden set_level)")
	await _make(load("res://resources/levels/endless.tres"))
	_c("H: sonsuz: REKOR + rakam, portre gizli, skor hedefi boş", _hud.goal_caption.text == "REKOR"
		and not _hud.goal_portrait.visible and _hud.goal_extra.text == "" and _hud.level_label.text == "SONSUZ")
	_check_fit("H: sonsuz rekor", false)
	_c("H: sonsuz rekor taban puntoda", _font_size() == BASE_SIZE)
	await _make_challenge(6)
	_check_fit("H: meydan okuma T6 'Dev Dumpling'", false)
	_c("H: meydan okuma T6 taban puntoda", _font_size() == BASE_SIZE)
	await _free_board()
	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(load("res://resources/levels/level_01.tres"))
	var queue: Array[int] = [1, 1, 2]
	_board.setup_tutorial_queue(queue)
	add_child(_board)
	await _frames(2)
	_board._apply_layout(VIEW, 0.0)
	await _frames(3)
	_hud = _board.get_node("HUD")
	_check_fit("H: tutorial board (L01 'Şişkin Dumpling')", false)
	_c("H: tutorial GOAL spot dikdörtgeni = hedef plakası = yerleşim dikdörtgeni",
		_board.tutorial_goal_rect().is_equal_approx(_hud.goal_plate.get_global_rect())
		and _board.tutorial_goal_rect().position.is_equal_approx((GameplayLayout.compute(VIEW)["goal"] as Rect2).position))
	await _make_level(3)
	var before: int = _font_size()
	_hud.set_level(load("res://resources/levels/level_04.tres"))
	_c("H: aynı HUD'da yeniden set_level anında yeniden sığdırır (T5 küçük → T6 taban, yeniden boyut beklemeden)",
		before < BASE_SIZE and _font_size() == BASE_SIZE and _hud.goal_label.text == "Dev Dumpling")
	_hud.set_level(load("res://resources/levels/level_03.tres"))
	_c("H: ve geri T5 (anında küçültülür)", _font_size() == before and _shown(_hud.goal_label)["trim"] < 0)
	_sections_done += 1


# --- Yardımcılar ------------------------------------------------------------------------------------------

## Ad etiketinin sözleşmesi: Label'ın kendi kırpma geçişi kırpmıyor; punto [16, 20] ve en büyük uygun
## değer; ölçülen genişlik + pay sığıyor; ad portreye / rozete / çubuğa / skor hedefine değmiyor, kartın
## içinde. `exact`: metin tam kanonik.
func _check_fit(tag: String, exact: bool) -> void:
	var label: Label = _hud.goal_label
	var shown: Dictionary = _shown(label)
	var size: int = _font_size()
	var avail: float = shown["avail"]
	_c("%s: Label kırpma geçişi kırpmıyor — görünen '%s' (trim %d, üç nokta %d, doğal %.1f / %.1f px)"
		% [tag, shown["text"], shown["trim"], shown["ellipsis"], shown["natural"], avail],
		shown["trim"] < 0 and shown["ellipsis"] < 0 and float(shown["natural"]) <= avail and avail > 0.0)
	_c("%s: punto %d okunur aralıkta [%d, %d] ve en büyük uygun değer" % [tag, size, MIN_SIZE, BASE_SIZE],
		size >= MIN_SIZE and size <= BASE_SIZE
		and (size == BASE_SIZE or _width(label, size + 1) + SLACK > avail))
	_c("%s: ölçülen genişlik + %.0f px pay etikete sığıyor" % [tag, SLACK], _width(label, size) + SLACK <= avail)
	var name_rect: Rect2 = label.get_global_rect()
	var card: Rect2 = (_hud.goal_plate.get_meta(&"card") as Control).get_global_rect()
	var others: Array[Rect2] = [_hud.level_badge.get_global_rect(), _hud.goal_bar.get_parent().get_global_rect(),
		_hud.goal_extra.get_global_rect(), _hud.goal_caption.get_global_rect()]
	if _hud.goal_portrait.visible:
		others.append(_hud.goal_portrait.get_global_rect())
	var clear: bool = card.grow(0.5).encloses(name_rect)
	for rect in others:
		clear = clear and not GameplayLayout.overlaps(name_rect, rect)
	_c("%s: ad kartın içinde, portre / rozet / çubuk / başlık / skor hedefiyle çakışmıyor" % tag, clear)
	if exact:
		_c("%s: görünen metin = kanonik metin" % tag, shown["text"] == label.text)


## Label'ın kırpma geçişinin yeniden koşulması (Godot 4.6 Label: genişlik = boyut − stil minimumu,
## OVERRUN_TRIM_ELLIPSIS = TRIM + ADD_ELLIPSIS; altı karakterden azı kalırsa üç nokta EKLENMEDEN kırpar).
func _shown(label: Label) -> Dictionary:
	var font: Font = label.get_theme_font("font")
	var avail: float = label.size.x - label.get_theme_stylebox("normal").get_minimum_size().x
	var ts: TextServer = TextServerManager.get_primary_interface()
	var rid: RID = ts.create_shaped_text()
	ts.shaped_text_add_string(rid, label.text, font.get_rids(), _font_size(), font.get_opentype_features())
	var natural: float = ts.shaped_text_get_width(rid)
	ts.shaped_text_overrun_trim_to_width(rid, avail, TextServer.OVERRUN_TRIM | TextServer.OVERRUN_ADD_ELLIPSIS)
	var trim: int = ts.shaped_text_get_trim_pos(rid)
	var ellipsis: int = ts.shaped_text_get_ellipsis_pos(rid)
	ts.free_rid(rid)
	var text: String = label.text
	if trim >= 0:
		text = label.text.substr(0, trim) + ("…" if ellipsis >= 0 else "")
	return {"natural": natural, "avail": avail, "trim": trim, "ellipsis": ellipsis, "text": text}


func _width(label: Label, size: int) -> float:
	return label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _font_size() -> int:
	return _hud.goal_label.get_theme_font_size("font_size")


## Skor hedefi yazısının mürekkep alanı HEDEF yazısına, ada ve çubuk satırına değmiyor.
func _extra_clear() -> bool:
	var extra: Rect2 = _hud.goal_extra.get_global_rect()
	var caption: Label = _hud.goal_caption
	var caption_ink: float = caption.get_theme_font("font").get_string_size(caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		caption.get_theme_font_size("font_size")).x
	var extra_ink: float = _hud.goal_extra.get_theme_font("font").get_string_size(_hud.goal_extra.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _hud.goal_extra.get_theme_font_size("font_size")).x
	var c: Rect2 = caption.get_global_rect()
	var ink_gap: bool
	if caption.is_layout_rtl():
		ink_gap = extra.position.x + extra_ink <= c.end.x - caption_ink
	else:
		ink_gap = c.position.x + caption_ink <= extra.end.x - extra_ink
	return (ink_gap and not GameplayLayout.overlaps(extra, _hud.goal_label.get_global_rect())
		and not GameplayLayout.overlaps(extra, _hud.goal_bar.get_parent().get_global_rect()))


func _geometry() -> Dictionary:
	var card: PanelContainer = _hud.goal_plate.get_meta(&"card")
	var column: Control = _hud.goal_caption.get_parent()
	while column != null and not (column is VBoxContainer):
		column = column.get_parent()
	return {
		"plate": _hud.goal_plate.get_global_rect(), "card": card.get_global_rect(),
		"badge": _hud.level_badge.get_global_rect(), "column": column.get_global_rect(),
		"caption_row": _hud.goal_caption.get_parent().get_global_rect() if _hud.goal_caption.get_parent() != column
			else _hud.goal_caption.get_global_rect(),
		"goal_row": _hud.goal_label.get_parent().get_global_rect(),
		"portrait": _hud.goal_portrait.get_global_rect(),
		"bar_row": _hud.goal_bar.get_parent().get_global_rect(),
		"percent": _hud.goal_percent.get_parent().get_global_rect(),
		"label": _hud.goal_label.get_global_rect(),
		"label_font": _font_size(),
	}


func _hud_constants() -> Dictionary:
	return (load("res://scripts/ui/gameplay_hud.gd") as GDScript).get_script_constant_map()


## Üretim ad yazma yolu (`set_goal_name`); düzeltmesiz tabanda yok → açık FAIL + doğrudan metin.
func _set_name(text: String) -> void:
	var ok: bool = _hud.has_method("set_goal_name")
	if not ok:
		_c("üretim ad yazma yolu GameplayHud.set_goal_name var", false)
		_hud.goal_label.text = text
		return
	_hud.call("set_goal_name", text)


func _make_level(number: int) -> void:
	await _make(load("res://resources/levels/level_%02d.tres" % number))


func _make_challenge(tier: int) -> void:
	await _free_board()
	var level: LevelData = DailyChallenge.make_level(THU)
	level.target_tier = tier
	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(level)
	_board.setup_challenge(DailyChallenge.Sequence.new(THU), 18)
	add_child(_board)
	await _frames(2)
	_board._apply_layout(VIEW, 0.0)
	await _frames(3)
	_hud = _board.get_node("HUD")


func _make(level: LevelData) -> void:
	await _free_board()
	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(level)
	add_child(_board)
	await _frames(2)
	_board._apply_layout(VIEW, 0.0)
	await _frames(3)
	_hud = _board.get_node("HUD")


func _free_board() -> void:
	if _board != null and is_instance_valid(_board):
		_board.queue_free()
		_board = null
		_hud = null
		await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for path in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out
