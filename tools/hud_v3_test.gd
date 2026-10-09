extends Node
## TASK/060 — Gameplay HUD V3 (güç madalyonları) + refill penceresi TEXT-LIGHT sözleşmesi. Headless; gerçek
## `main.tscn` + gerçek board; kayıt `user://qa_hud_v3/`'e YÖNLENDİRİLİR (sahibin kayıt ailesi başta / sonda bayt
## bayt karşılaştırılır). Girdi GERÇEK parmak olayları (InputEventScreenTouch → dokunuştan fare öykünmesi → GUI).
##
##   godot --headless --audio-driver Dummy --path . res://tools/hud_v3_test.tscn
##
## Bölümler: A stok YALNIZ rakam · B dokunma alanı ≥ 84 + çakışma yok + görsel = dokunma (6 görünüm) · C board /
## kamera / hedef kartı TABAN ile birebir (fizik penceresi değişmedi) · D gerçek dokunuş: silahlanma, stok 0 →
## refill tek pencere, çift dokunuş, ACTION_CANCEL, sürükleyip çıkma, anında güç otomatik çalışmaz · E meydan
## okuma güçsüz · F refill penceresi TEXT-LIGHT (× / STOK yok, n/2 BAŞARILI kullanım).

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_hud_v3"
const PATH: String = DIR + "/save.json"
const DAY: String = "2026-10-01"
const SECTIONS: int = 6
## Taban (`75fe3f3`, `tools/hud_v3_shots` JSON'u): [görünüm, banner, üst güvenli pay, kamera zoom, board rect, hedef
## kartı rect, şerit rect, HUD sonu]. HUD V3 bu sayıları DEĞİŞTİRMEMELİ (ikili dışı eski tepsiyle aynı 178 px).
const BASELINE: Array = [
	[Vector2(720, 1280), 0.0, 0.0, 0.970986460348162, Rect2(0, 194, 720, 1004), Rect2(210, 82, 300, 104), Rect2(18, 1206, 684, 64), 186.0],
	[Vector2(720, 1280), 112.0, 0.0, 0.874274661508704, Rect2(0, 190, 720, 904), Rect2(210, 82, 300, 104), Rect2(18, 1098, 684, 64), 186.0],
	[Vector2(720, 1280), 128.0, 0.0, 0.858800773694391, Rect2(0, 190, 720, 888), Rect2(210, 82, 300, 104), Rect2(18, 1082, 684, 64), 186.0],
	[Vector2(720, 1600), 0.0, 0.0, 1.2, Rect2(0, 194, 720, 1324), Rect2(210, 82, 300, 104), Rect2(18, 1484.4, 684, 64), 186.0],
	[Vector2(720, 1560), 0.0, 61.0, 1.18858800773694, Rect2(0, 249, 720, 1229), Rect2(210, 137, 300, 104), Rect2(18, 1486, 684, 64), 241.0],
	[Vector2(720, 1560), 112.0, 61.0, 1.08027079303675, Rect2(0, 249, 720, 1117), Rect2(210, 137, 300, 104), Rect2(18, 1374, 684, 64), 241.0],
]

var _fails: int = 0
var _checks: int = 0
var _sections: int = 0
var _finished: bool = false
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _main: Node2D


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_owner_state = _owner_snapshot()
	_saved_data = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	SaveManager.save_path = PATH
	DailyRewards.clock_override = DAY
	get_tree().create_timer(200.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 200 s'de bitmedi")
			if _main != null and is_instance_valid(_main):
				_main.free()
			_teardown()
			get_tree().quit(2))
	get_window().size = Vector2i(720, 1280)
	await _boot({"bomb": 3, "upgrade": 1, "shake": 0, "clear_small": 12})
	_main._start_level(load("res://resources/levels/level_05.tres"))
	await _settle(4)

	_stock_numbers()
	_touch_targets()
	_baseline_layout()
	await _input_section()
	await _challenge()
	await _refill_text()
	_c("%d/%d bölüm sonuna kadar koştu" % [_sections, SECTIONS], _sections == SECTIONS)

	await _teardown_main()
	_teardown()
	_c("SaveManager gerçek yola döndü, test klasörü silindi, saat kancası boş", SaveManager.save_path == SaveManager.SAVE_PATH
		and not DirAccess.dir_exists_absolute(DIR) and DailyRewards.clock_override == "")
	_c("sahibin gerçek kayıt ailesi (kanonik + .tmp + .bak) bayt-aynı", _owner_snapshot() == _owner_state)
	_finished = true
	print("\nSONUC: %d kontrol, %d hata" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


# --- A ---------------------------------------------------------------------------------------------------------------

func _medallion(type: PowerUp.Type) -> PowerMedallion:
	return _main._board._power_bar.slot(int(type)) as PowerMedallion


func _stock_numbers() -> void:
	print("-- A: stok YALNIZ rakam (0 / 1 / 3 / 12 — 'x1' / '×1' yok)")
	var expect: Dictionary = {PowerUp.Type.BOMB: "3", PowerUp.Type.UPGRADE: "1", PowerUp.Type.SHAKE: "0",
		PowerUp.Type.CLEAR_SMALL: "12"}
	var ok: bool = true
	for type in PowerUp.all():
		var m: PowerMedallion = _medallion(type)
		ok = ok and m != null and m.count_text() == expect[type] and not m.count_text().contains("×") \
			and not m.count_text().to_lower().contains("x") and m.count() == int(expect[type])
	_c("dört madalyon kabarcığı: 3 / 1 / 0 / 12 (yalnız rakam)", ok)
	var twelve: PowerMedallion = _medallion(PowerUp.Type.CLEAR_SMALL)
	var label: Label = twelve.get_meta(&"badge_label")
	var text_w: float = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1,
		label.get_theme_font_size("font_size")).x
	_c("çok haneli stok (12): kabarcık rakamı sığdırır (hap biçiminde genişler), dokunma alanından ≤ 4 px taşar",
		twelve.stock_rect().size.x >= text_w + 8.0 and Rect2(Vector2.ZERO, twelve.size).grow(4.0).encloses(twelve.stock_rect()))
	_c("stok 0 kabarcığında koyu rakam (gri üstünde okunur)", (_medallion(PowerUp.Type.SHAKE).get_meta(&"badge_label") as Label)
		.get_theme_color("font_color") == UiTokens.TEXT_DISABLED)
	_c("stok 0 (Sarsıntı) PowerSlotEmpty, rakam '0' görünür, sanat soluk ama renkli", _medallion(PowerUp.Type.SHAKE)
		.theme_type_variation == &"PowerSlotEmpty" and _medallion(PowerUp.Type.SHAKE).count_text() == "0"
		and (_medallion(PowerUp.Type.SHAKE).get_meta(&"art") as TextureRect).self_modulate.a > 0.5)
	_c("sıra korunur: Bomba · Büyütücü | Sarsıntı · Temizleyici, owner ikonları", PowerBar.SLOT_ORDER == [PowerUp.Type.BOMB,
		PowerUp.Type.UPGRADE, PowerUp.Type.SHAKE, PowerUp.Type.CLEAR_SMALL]
		and (_medallion(PowerUp.Type.UPGRADE).get_meta(&"art") as TextureRect).texture == PowerUp.icon(PowerUp.Type.UPGRADE))
	_c("HUD'da metin etiketi yok (TEXT-LIGHT: ikon + rakam)", _labels_under(_main._board._power_bar).all(
		func(l: Label) -> bool: return l.text.is_valid_int()))
	_sections += 1


func _labels_under(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Label:
			out.append(child)
		out.append_array(_labels_under(child))
	return out


# --- B ---------------------------------------------------------------------------------------------------------------

func _touch_targets() -> void:
	print("-- B: dokunma alanı >= %d (her iki boyut), çakışma yok, görsel = dokunma (6 görünüm)" % UiTokens.TOUCH_TARGET)
	for spec in BASELINE:
		var view: Vector2 = spec[0]
		var rects: Dictionary = GameplayLayout.compute(view, spec[1], spec[2])
		var slots: Array = rects["slots"]
		var tag: String = "%dx%d b%d s%d" % [int(view.x), int(view.y), int(spec[1]), int(spec[2])]
		var big: bool = true
		for r: Rect2 in slots:
			big = big and r.size.x >= UiTokens.TOUCH_TARGET and r.size.y >= UiTokens.TOUCH_TARGET
		var clear: bool = true
		for i in slots.size():
			for j in range(i + 1, slots.size()):
				clear = clear and not GameplayLayout.overlaps(slots[i], slots[j])
		var others: bool = true
		for key in ["goal", "back", "settings", "exit", "next", "board", "strip", "banner"]:
			for r: Rect2 in slots:
				others = others and not GameplayLayout.overlaps(r, rects[key])
		var inside: bool = true
		for r: Rect2 in slots:
			inside = inside and Rect2(Vector2.ZERO, view).encloses(r) and rects["row2"].grow(0.5).encloses(r)
		_c("%s: 4 dokunma alanı >= 84×84, birbirine ve diğer kontrollere / board'a / banner'a değmez, satır 2'de" % tag,
			big and clear and others and inside)
	# Gerçek düğme: dokunma alanı = düğme dikdörtgeni; görsel gövde + kabarcık onun içinde.
	var aligned: bool = true
	for type in PowerUp.all():
		var m: PowerMedallion = _medallion(type)
		var hit := Rect2(Vector2.ZERO, m.size)
		aligned = aligned and m.size.x >= UiTokens.TOUCH_TARGET and m.size.y >= UiTokens.TOUCH_TARGET
		aligned = aligned and hit.encloses(m.body_rect()) and hit.grow(4.0).encloses(m.stock_rect())
		aligned = aligned and m.mouse_filter == Control.MOUSE_FILTER_STOP and m.focus_mode == Control.FOCUS_NONE
	_c("gerçek madalyon: düğme ≥ 84, gövde dokunma alanının içinde, kabarcık ≤ 4 px taşar (görsel = dokunma)", aligned)
	_sections += 1


# --- C ---------------------------------------------------------------------------------------------------------------

func _baseline_layout() -> void:
	print("-- C: board / kamera / hedef kartı / şerit TABAN ile birebir (fizik penceresi değişmedi)")
	var frame: Rect2 = _main._board.reference_frame()
	for spec in BASELINE:
		var view: Vector2 = spec[0]
		var rects: Dictionary = GameplayLayout.compute(view, spec[1], spec[2])
		var fit: Dictionary = GameplayLayout.fit_board(frame, rects["board"], view)
		rects = GameplayLayout.hug_strip(rects, (fit["screen_rect"] as Rect2).end.y)
		var tag: String = "%dx%d b%d s%d" % [int(view.x), int(view.y), int(spec[1]), int(spec[2])]
		_c("%s: zoom %.4f (taban %.4f), board / hedef kartı (300 px) / şerit / HUD sonu aynı" % [tag, fit["zoom"], spec[3]],
			absf(float(fit["zoom"]) - float(spec[3])) < 0.0005 and _same(rects["board"], spec[4])
			and _same(rects["goal"], spec[5]) and _same(rects["strip"], spec[6])
			and absf((rects["hud"] as Rect2).end.y - float(spec[7])) < 0.01)
	_c("fizik sabitleri aynen (FLOOR_Y 1180)", is_equal_approx(_main._board.FLOOR_Y, 1180.0))
	_sections += 1


func _same(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) < 0.06 and a.size.distance_to(b.size) < 0.06


# --- D ---------------------------------------------------------------------------------------------------------------

func _center(m: Control) -> Vector2:
	return get_viewport().get_screen_transform() * m.get_global_rect().get_center()


func _touch(pos: Vector2, pressed: bool, canceled: bool = false) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = pos
	t.pressed = pressed
	t.canceled = canceled
	Input.parse_input_event(t)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _move(pos: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = pos
	Input.parse_input_event(d)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _tap(m: Control) -> void:
	var p: Vector2 = _center(m)
	await _touch(p, true)
	await _touch(p, false)
	await _settle(2)


func _input_section() -> void:
	print("-- D: gerçek dokunuş (GestureGuard, TASK/055)")
	var board: Node2D = _main._board
	await get_tree().create_timer(0.4).timeout
	var bomb: PowerMedallion = _medallion(PowerUp.Type.BOMB)
	await _tap(bomb)
	_c("Bomba (stok 3) dokunuşu → hedefleme (silahlı), stok TÜKETİLMEDİ", board._powerups.is_armed()
		and board._powerups.armed_type() == int(PowerUp.Type.BOMB) and bomb.is_armed() and SaveManager.powerup_count(PowerUp.Type.BOMB) == 3)
	_c("silahlı madalyon: PowerSlotArmed + cyan hale görünür", bomb.theme_type_variation == &"PowerSlotArmed"
		and (bomb.get_meta(&"glow") as Control).visible)
	await _tap(bomb)
	_c("ikinci dokunuş hedeflemeyi kapatır (vazgeç), stok aynı", not board._powerups.is_armed()
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == 3)
	await _tap(_medallion(PowerUp.Type.UPGRADE))
	_c("Büyütücü (stok 1) → hedefleme; Bomba silahı kalktı (iki güç aynı anda yok)", board._powerups.armed_type()
		== int(PowerUp.Type.UPGRADE) and not bomb.is_armed())
	board._powerups.cancel()
	await _settle(1)
	# Stok 0 → refill tek pencere; çift dokunuş tek pencere.
	var shake: PowerMedallion = _medallion(PowerUp.Type.SHAKE)
	var opened: Array[int] = [0]
	var counter := func(_t: int) -> void: opened[0] += 1
	board.power_refill_offered.connect(counter)
	var p: Vector2 = _center(shake)
	await _touch(p, true)
	await _touch(p, false)
	await _touch(p, true)
	await _touch(p, false)
	await _settle(3)
	_c("stok 0 Sarsıntı: çift dokunuş → TEK refill penceresi, board donuk (açılış %d, görünür %s)" % [opened[0],
		str(_main._refill.visible)], opened[0] == 1 and _main._refill.visible
		and _main._refill.current_type() == int(PowerUp.Type.SHAKE) and board.is_refill_pending())
	# KAPAT'a hızlı çift dokunuş: pencere kapanır, ikinci dokunuş alttaki board'a BIRAKIŞ olarak düşmez (300 ms yatışma).
	await get_tree().create_timer(0.35).timeout
	var drops: Array[int] = [0]
	var drop_counter := func(_tier: int) -> void: drops[0] += 1
	board.dumpling_dropped.connect(drop_counter)
	var close_pos: Vector2 = _center(_main._refill._close)
	await _touch(close_pos, true)
	await _touch(close_pos, false)
	await _touch(close_pos, true)
	await _touch(close_pos, false)
	await _settle(3)
	_c("KAPAT'a çift dokunuş: pencere kapandı, board sürüyor, ikinci dokunuş parça BIRAKMADI", not _main._refill.visible
		and not board.is_refill_pending() and drops[0] == 0)
	# Hamur düğmesine hızlı çift dokunuş: tek satın alma, Bomba hedeflemesi geri gelir, ikinci dokunuş gücü HARCAMAZ.
	await get_tree().create_timer(0.35).timeout
	SaveManager.data["powerups"]["bomb"] = 0
	SaveManager.data["dough"] = 335
	board._refresh_power_bar()
	await _tap(bomb)
	await get_tree().create_timer(0.35).timeout
	var buy_pos: Vector2 = _center(_main._refill._dough)
	await _touch(buy_pos, true)
	await _touch(buy_pos, false)
	await _touch(buy_pos, true)
	await _touch(buy_pos, false)
	await _settle(3)
	_c("Hamur düğmesine çift dokunuş: TEK satın alma (335 → 215), Bomba stok 1, hedefleme açık, ikinci dokunuş gücü HARCAMADI / parça bırakmadı",
		SaveManager.dough() == 335 - PowerUpEconomy.price(PowerUp.Type.BOMB) and SaveManager.powerup_count(PowerUp.Type.BOMB) == 1
		and board._powerups.is_armed() and drops[0] == 0 and not _main._refill.visible)
	board._powerups.cancel()
	board.dumpling_dropped.disconnect(drop_counter)
	await _settle(1)
	# ACTION_CANCEL: basılı madalyon iptal edilen dokunuşla eylem üretmez.
	await get_tree().create_timer(0.35).timeout
	var opened_before: int = opened[0]
	await _touch(p, true)
	await _touch(p, false, true)
	await _settle(2)
	_c("ACTION_CANCEL (iptal edilen dokunuş) → refill açılmaz, eylem yok", opened[0] == opened_before and not _main._refill.visible)
	# Sürükleyip madalyondan çıkma → eylem yok.
	await _touch(_center(bomb), true)
	await _move(_center(bomb) + Vector2(0.0, 220.0))
	await _touch(_center(bomb) + Vector2(0.0, 220.0), false)
	await _settle(2)
	_c("madalyondan sürükleyip dışarıda bırakma → hedefleme açılmaz", not board._powerups.is_armed())
	# Anında güç (Temizleyici stok 12): refill sonrası OTOMATİK ÇALIŞMAZ (rewarded_powers_test) — burada basış = kullanım.
	var clear_before: int = SaveManager.powerup_count(PowerUp.Type.CLEAR_SMALL)
	var smalls: int = 0
	for child in board._dumpling_layer.get_children():
		var d := child as Dumpling
		if d != null and is_instance_valid(d) and d.tier <= PowerUp.CLEAR_SMALL_MAX_TIER:
			smalls += 1
	await _tap(_medallion(PowerUp.Type.CLEAR_SMALL))
	await _settle(4)
	_c("Temizleyici dokunuşu: anında güç kendi kuralıyla (board'da tier 1-2 %d parça → stok %s)" % [smalls,
		"tüketildi" if smalls > 0 else "aynı"], SaveManager.powerup_count(PowerUp.Type.CLEAR_SMALL)
		== (clear_before - 1 if smalls > 0 else clear_before) and not board._powerups.is_armed())
	board.power_refill_offered.disconnect(counter)
	# Kapalı çubuk (mola / pencere dondurması): dokunuş eylemsiz.
	board._power_bar.set_enabled(false)
	await _tap(bomb)
	_c("çubuk kapalı (dondurma): madalyon disabled %55, dokunuş eylem üretmez", bomb.disabled
		and is_equal_approx(bomb.modulate.a, 0.55) and not board._powerups.is_armed())
	board._power_bar.set_enabled(true)
	await _settle(1)
	_sections += 1


# --- E ---------------------------------------------------------------------------------------------------------------

func _challenge() -> void:
	print("-- E: günlük meydan okuma — güç madalyonları yok, kilitli")
	_main.abandon_run()
	await _settle(2)
	_c("meydan okuma başladı", _main.start_daily_challenge())
	await _settle(4)
	var hud: GameplayHud = _main._board._hud
	var hidden: bool = not hud.power_bar.visible and not hud.tray_left.visible and not hud.tray_right.visible
	for type in PowerUp.all():
		hidden = hidden and not hud.power_bar.slot(int(type)).visible
	_c("meydan okuma: dört madalyon + ikili kutuları gizli, çubuk kilitli; yeni reklam girişi yok", hidden
		and hud.power_bar.is_locked() and not _main._refill.visible)
	_main._leave_daily_challenge()
	await _settle(2)
	_sections += 1


# --- F ---------------------------------------------------------------------------------------------------------------

func _refill_text() -> void:
	print("-- F: refill penceresi TEXT-LIGHT (gerçek pencere, tüm durumlar)")
	SaveManager.data["powerups"] = {"bomb": 0, "upgrade": 0, "shake": 0, "clear_small": 0}
	_main._start_level(load("res://resources/levels/level_04.tres"))
	await _settle(4)
	var refill: CanvasLayer = _main._refill
	var states: Array = [[{}, 335, "0/2"], [{"bomb": 1}, 335, "1/2"], [{"bomb": 2}, 335, "2/2"], [{}, 10, "0/2"]]
	var all_ok: bool = true
	for st in states:
		var grants: Dictionary = {"bomb": 0, "upgrade": 0, "shake": 0, "clear_small": 0}
		for k: String in st[0]:
			grants[k] = st[0][k]
		SaveManager.data["rewarded_power_quota"] = {"version": 1, "day_key": RewardedPolicy.today(), "grants": grants}
		SaveManager.data["dough"] = st[1]
		_main._board._on_power_refill_requested(int(PowerUp.Type.BOMB))
		await _settle(3)
		var texts: Array[String] = []
		for l in _labels_under(refill.frame()):
			if (l as Label).is_visible_in_tree() and (l as Label).text != "":
				texts.append((l as Label).text)
		var joined: String = " | ".join(texts)
		var ok: bool = refill.quota_text() == st[2] and not joined.contains("×") and not joined.contains("STOK") \
			and refill.stock_text() == "0" and refill.price_text() == str(PowerUpEconomy.price(PowerUp.Type.BOMB))
		print("      %s / %d Hamur → %s" % [st[2], st[1], joined])
		all_ok = all_ok and ok
		_main._on_refill_closed()
		await _settle(2)
	_c("refill dört durumda: kota cipi BAŞARILI kullanım (0/2 · 1/2 · 2/2), stok '0', fiyat rakamı; '×' / 'STOK' yok", all_ok)
	# 16:9 + gerçek banner yuvası (112 / 128): pencere ve KAPAT yuvanın ÜSTÜNDE, ekranda.
	var fits: bool = true
	var note_ok: bool = false
	for slot_px in [112.0, 128.0]:
		UiKit.set_banner_slot(slot_px)
		SaveManager.data["dough"] = 10
		_main._board._on_power_refill_requested(int(PowerUp.Type.CLEAR_SMALL))
		await _settle(4)
		var view: Rect2 = get_viewport().get_visible_rect()
		var limit: float = view.size.y - slot_px
		var frame_rect: Rect2 = refill.frame().get_global_rect()
		var ok_size: bool = frame_rect.position.y >= 0.0 and frame_rect.end.y <= limit \
			and refill._close.get_global_rect().end.y <= limit and refill._ad.get_global_rect().end.y <= limit
		print("      banner %d: çerçeve %s, KAPAT alt %d, sınır %d" % [int(slot_px), str(frame_rect),
			int(refill._close.get_global_rect().end.y), int(limit)])
		fits = fits and ok_size
		if slot_px == 112.0:
			# TASK/060 A36: Hamur 10 + Temizleyici → "Hamur yetersiz" + bakiye uyarı tonunda (TEXT_WARNING_STRONG).
			note_ok = refill.dough_note_text() == refill.NOTE_NO_DOUGH 				and refill._dough_note.get_theme_color("font_color") == UiTokens.TEXT_WARNING_STRONG 				and refill._balance.get_theme_color("font_color") == UiTokens.TEXT_WARNING_STRONG 				and refill._note.get_theme_color("font_color") == UiTokens.TEXT_WARNING_STRONG
		_main._on_refill_closed()
		await _settle(2)
	UiKit.set_banner_slot(0.0)
	_c("16:9 + banner 112 / 128: refill penceresi + KAPAT + İZLE yuvanın üstünde, ekranda", fits)
	var contrast: float = _contrast(UiTokens.TEXT_WARNING_STRONG, UiTokens.SURFACE_NEUTRAL_DEEP)
	_c("küçük uyarı yazıları (karo sebebi + bakiye + altlık) TEXT_WARNING_STRONG, açık karoda %.2f:1 >= 4.5 (A36: eski ton 2.34:1)"
		% contrast, note_ok and contrast >= 4.5)
	_sections += 1


# --- ortak -------------------------------------------------------------------------------------------------------------

func _boot(stock: Dictionary) -> void:
	await _teardown_main()
	_clean()
	var data: Dictionary = SaveManager.DEFAULT_DATA.duplicate(true)
	data["powerups"] = stock.duplicate()
	data["powerup_starter_granted"] = true
	data["dough"] = 335
	data["highest_level_unlocked"] = 11
	data["onboarding_completed"] = true
	data["last_login_date"] = DAY
	data["daily_rewards"] = {"day_key": DAY, "free_chest_claimed": true, "ad_chests_claimed": 2, "dough_ad_claimed": true,
		"popup_seen_day": DAY, "last_seen_day_key": DAY}
	SaveManager.data = data
	SaveManager.save_game()
	_main = MAIN_SCENE.instantiate()
	_main.set("quit_suppressed", true)
	add_child(_main)
	await _settle(3)


func _settle(frames: int = 2) -> void:
	for i in maxi(frames, 1):
		await get_tree().process_frame


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _settle(3)


func _teardown() -> void:
	DailyRewards.clock_override = ""
	DailyRewards.auto_popup_enabled = false
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


func _clean() -> void:
	for p: String in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for p: String in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null
	return out


func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luminance(c: Color) -> float:
	var channels: Array[float] = []
	for v: float in [c.r, c.g, c.b]:
		channels.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
