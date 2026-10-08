extends Node
## TASK/060 — Gameplay HUD V3 + ödüllü güç refill penceresi: production çekimleri (taban ve aday AYNI araçla).
## Dev aracı — `--headless` İLE ÇALIŞTIRILAMAZ (ekran görüntüsü). Gerçek `main.tscn`, gerçek board, gerçek HUD /
## refill yolları; vitrin durumları YALNIZ yönlendirilmiş test kaydında (`user://qa_hud_v3_shots/`) — sahibin kayıt
## ailesi başta / sonda bayt bayt karşılaştırılır (fark varsa çıkış kodu 3).
##
##   godot --path . res://tools/hud_v3_shots.tscn -- <çıktı> [GxY] [banner=N] [safe=N] [only=h01,r02]
##
## Çekimler (her biri ayrıca `<ad>.json`: HUD yerleşim dikdörtgenleri + güç slotlarının ekran dikdörtgenleri):
##   h01_stock_mixed     L5, stok Bomba 3 · Büyütücü 1 · Sarsıntı 0 · Temizleyici 2
##   h02_armed_bomb      Bomba hedeflemede (silahlı)
##   h03_armed_upgrade   Büyütücü hedeflemede
##   h04_disabled        güç çubuğu kapalı (mola / pencere dondurması ile aynı görünüm)
##   h05_target_l8       L8: uzun hedef adı (T7) + skor hedefi
##   h06_target_l3       L3: T5 "Büyük Dumpling" (TASK/056)
##   h07_daily_challenge günlük meydan okuma board'u (güçler yok)
##   r01_refill_q0       Bomba stok 0, bugünkü Bomba reklamı 0 (sağlayıcı test çifti — hiçbir şey vermez)
##   r02_refill_q1       Bomba reklamı 1 kez kullanıldı
##   r03_refill_q2       Bomba reklamı 2 kez kullanıldı (tükendi)
##   r04_refill_other    Bomba tükenmişken Sarsıntı (kendi kotası 0)
##   r05_refill_noprov   sağlayıcı yok
##   r06_refill_nodough  Hamur 10
##   r07_refill_pending  REKLAM İZLE basıldı, cevap bekleniyor
## Kota vitrini iki biçimde birden yazılır (taban: `rewarded_power_date/grants` ortak sayaç; aday: güç başına blok) —
## her kod kendi okuduğunu görür. Sahte reklam YOK: test çifti talebi alır, ödül vermez.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_hud_v3_shots"
const PATH: String = DIR + "/save.json"
const DAY: String = "2026-10-01"
const SHOT_SIZE := Vector2i(720, 1280)
const PILE: Array = [[5, 3, 4, 2, 1], [2, 4, 1, 3], [3, 1, 2]]


class _StubProvider extends RefCounted:
	var power_requests: int = 0

	func show_rewarded_power(_main: Node, _type: int, _token: int) -> void:
		power_requests += 1

	func is_rewarded_ready() -> bool:
		return true

	func rewarded_note() -> String:
		return ""


var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _banner: float = 0.0
var _safe_top: float = -1.0
var _only: PackedStringArray = PackedStringArray()
var _main: Node2D
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _shots: int = 0


func _wants(id: String) -> bool:
	return _only.is_empty() or _only.has(id)


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://hud_v3_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	if args.size() >= 2 and args[1].contains("x"):
		var parts: PackedStringArray = args[1].split("x")
		_size = Vector2i(int(parts[0]), int(parts[1]))
	for arg in args:
		if arg.begins_with("banner="):
			_banner = float(arg.trim_prefix("banner="))
		elif arg.begins_with("safe="):
			_safe_top = float(arg.trim_prefix("safe="))
		elif arg.begins_with("only="):
			_only = arg.trim_prefix("only=").split(",", false)
	DisplayServer.window_set_size(_size)
	await get_tree().process_frame
	await get_tree().process_frame

	_owner_state = _owner_snapshot()
	_saved_data = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	SaveManager.save_path = PATH
	DailyRewards.clock_override = DAY
	GameplayLayout.set_banner_height(_banner)
	# Cihazdaki gibi gerçek banner yuvası da (pencereler `UiKit.bottom_inset` ile yuvanın üstüne oturur).
	UiKit.set_banner_slot(_banner)
	_showcase()
	SaveManager.save_game()

	_main = MAIN_SCENE.instantiate()
	_main.set("quit_suppressed", true)
	add_child(_main)
	await _settle(0.6)

	await _hud_group()
	await _refill_group()
	if _wants("h07"):
		await _challenge()

	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await get_tree().process_frame
	GameplayLayout.set_banner_height(0.0)
	UiKit.set_banner_slot(0.0)
	DailyRewards.clock_override = ""
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)
	var intact: bool = _owner_snapshot() == _owner_state
	print("bitti -> ", _out_dir, " (", _shots, " çekim) sahibin kaydı bayt-aynı: ", intact)
	get_tree().quit(0 if intact else 3)


# --- Kayıt vitrini ---------------------------------------------------------------------

func _showcase() -> void:
	var data: Dictionary = SaveManager.DEFAULT_DATA.duplicate(true)
	data["highest_level_unlocked"] = 11
	data["level_stars"] = {"1": 3, "2": 3, "3": 2, "4": 3, "5": 2, "6": 3, "7": 2, "8": 2, "9": 3, "10": 2}
	data["dough"] = 335
	data["onboarding_completed"] = true
	data["onboarding_completed_day"] = ""
	data["powerup_starter_granted"] = true
	data["age_ad_band"] = "ADULT"
	data["last_login_date"] = DAY
	data["daily_rewards"] = {"day_key": DAY, "free_chest_claimed": true, "ad_chests_claimed": 2,
		"dough_ad_claimed": true, "popup_seen_day": DAY, "last_seen_day_key": DAY}
	data["daily_challenge"] = {"version": 1, "completed_day_key": ""}
	SaveManager.data = data
	_set_stock({"bomb": 3, "upgrade": 1, "shake": 0, "clear_small": 2})
	_set_quota({})


func _set_stock(stock: Dictionary) -> void:
	SaveManager.data["powerups"] = stock.duplicate()


## Güç başına bugünkü başarılı ödül sayısı (anahtar = kayıt anahtarı). İki biçim birden: taban ortak sayaç
## (toplam > 0 → 1 = tükendi), aday güç başına blok.
func _set_quota(used: Dictionary) -> void:
	var total: int = 0
	var grants: Dictionary = {}
	for type in PowerUp.all():
		var key: String = PowerUp.save_key(type)
		grants[key] = int(used.get(key, 0))
		total += grants[key]
	SaveManager.data["rewarded_power_date"] = Time.get_date_string_from_system() if total > 0 else ""
	SaveManager.data["rewarded_power_grants"] = mini(total, 1)
	SaveManager.data["rewarded_power_quota"] = {"version": 1, "day_key": DailyRewards.day_key(), "grants": grants}


# --- Altyapı -----------------------------------------------------------------------------

func _tag() -> String:
	var tag: String = "%dx%d" % [_size.x, _size.y]
	if _safe_top >= 0.0:
		tag += "_safe%d" % int(_safe_top)
	if _banner > 0.0:
		tag += "_banner%d" % int(_banner)
	return tag


func _capture(name: String) -> void:
	await _drawn_frame()
	await _drawn_frame()
	var img: Image = get_viewport().get_texture().get_image()
	var file: String = "%s__%s" % [name, _tag()]
	var err: int = img.save_png(_out_dir.path_join(file + ".png"))
	if err == OK:
		_shots += 1
	var info: Dictionary = {"name": name, "tag": _tag(), "window": [_size.x, _size.y],
		"canvas": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"screen_scale": get_viewport().get_screen_transform().get_scale().x}
	if _main._board != null and is_instance_valid(_main._board):
		var hud: Dictionary = _main._board._hud.layout()
		var rects: Dictionary = {}
		for key: String in hud:
			var value: Variant = hud[key]
			if value is Rect2:
				rects[key] = _rect(value)
			elif value is Array:
				var list: Array = []
				for item in value:
					if item is Rect2:
						list.append(_rect(item))
				rects[key] = list
		info["layout"] = rects
		var slots: Dictionary = {}
		for type in PowerUp.all():
			var slot: Control = _main._board._power_bar.slot(int(type))
			if slot != null:
				slots[PowerUp.save_key(type)] = _rect(slot.get_global_rect())
		info["slots"] = slots
		info["zoom"] = _main._board._camera_zoom
	var json := FileAccess.open(_out_dir.path_join(file + ".json"), FileAccess.WRITE)
	json.store_string(JSON.stringify(info, "\t"))
	json.close()
	print(("kaydedildi : " if err == OK else "HATA       : "), file)


func _rect(r: Rect2) -> Array:
	return [snappedf(r.position.x, 0.01), snappedf(r.position.y, 0.01), snappedf(r.size.x, 0.01), snappedf(r.size.y, 0.01)]


func _drawn_frame() -> void:
	var drawn: Array[bool] = [false]
	var mark := func() -> void: drawn[0] = true
	RenderingServer.frame_post_draw.connect(mark, CONNECT_ONE_SHOT)
	var frames: int = 0
	while not drawn[0] and frames < 30:
		await get_tree().process_frame
		frames += 1
	if not drawn[0]:
		if RenderingServer.frame_post_draw.is_connected(mark):
			RenderingServer.frame_post_draw.disconnect(mark)
		RenderingServer.force_draw()


func _settle(seconds: float = 0.45) -> void:
	await get_tree().create_timer(seconds).timeout
	await get_tree().process_frame


func _relayout() -> void:
	if _main._board == null:
		return
	_main._board._apply_layout(get_viewport().get_visible_rect().size, _safe_top if _safe_top >= 0.0 else 0.0)
	# Araç: güvenli pay board kurulduktan SONRA verildiği için kapsayıcı içindeki plakaların (skor kartı) dekorları
	# kendi dikdörtgeni değişmediğinden eşitlenmiyordu (cihazda pay ilk yerleşimde bilinir — yok). Eşitlemeyi tetikle.
	await get_tree().process_frame
	_resync(_main._board._hud)


func _resync(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).item_rect_changed.emit()
		_resync(child)


func _start(level_path: String) -> void:
	_main._start_level(load(level_path))
	await get_tree().process_frame
	await get_tree().process_frame
	_main._board.round_finished.disconnect(_main._on_round_finished)
	await _relayout()
	await _settle(0.5)


func _leave() -> void:
	_main._refill.hide_refill()
	_main._result.hide_result()
	_main.abandon_run()
	await get_tree().process_frame
	_main._show_tab(0)
	await _settle(0.3)


func _pile() -> void:
	var board: Node2D = _main._board
	var left: float = board._left_x()
	var right: float = board._right_x()
	var y: float = board.FLOOR_Y - 40.0
	for row in PILE:
		var tiers: Array = row
		var total_w: float = 0.0
		for t in tiers:
			total_w += TierConfig.radius(t) * 2.0 + 6.0
		var x: float = (left + right) * 0.5 - total_w * 0.5
		var row_h: float = 0.0
		for t in tiers:
			var r: float = TierConfig.radius(t)
			x += r + 3.0
			board._spawn_dumpling(t, Vector2(clampf(x, left + r, right - r), y - r))
			x += r + 3.0
			row_h = maxf(row_h, r * 2.0)
		y -= row_h + 4.0
		for i in 12:
			await get_tree().physics_frame
	for i in 150:
		await get_tree().physics_frame


func _refresh_bar() -> void:
	_main._board._refresh_power_bar()
	await get_tree().process_frame


# --- HUD -----------------------------------------------------------------------------------

func _hud_group() -> void:
	if not (_wants("h01") or _wants("h02") or _wants("h03") or _wants("h04") or _wants("h05") or _wants("h06")):
		return
	await _start("res://resources/levels/level_05.tres")
	await _pile()
	GameState.reset_run()
	GameState.add_score(1240)
	_set_stock({"bomb": 3, "upgrade": 1, "shake": 0, "clear_small": 2})
	await _refresh_bar()
	if _wants("h01"):
		await _capture("h01_stock_mixed")
	if _wants("h02"):
		_main._board._on_power_pressed(int(PowerUp.Type.BOMB))
		await _settle(0.35)
		await _capture("h02_armed_bomb")
		_main._board._on_power_pressed(int(PowerUp.Type.BOMB))
		await _settle(0.2)
	if _wants("h03"):
		_main._board._on_power_pressed(int(PowerUp.Type.UPGRADE))
		await _settle(0.35)
		await _capture("h03_armed_upgrade")
		_main._board._on_power_pressed(int(PowerUp.Type.UPGRADE))
		await _settle(0.2)
	if _wants("h04"):
		_main._board._power_bar.set_enabled(false)
		await _settle(0.2)
		await _capture("h04_disabled")
		_main._board._power_bar.set_enabled(true)
	await _leave()
	if _wants("h05"):
		await _start("res://resources/levels/level_08.tres")
		await _pile()
		await _refresh_bar()
		await _capture("h05_target_l8")
		await _leave()
	if _wants("h06"):
		await _start("res://resources/levels/level_03.tres")
		await _pile()
		await _refresh_bar()
		await _capture("h06_target_l3")
		await _leave()


# --- Refill penceresi ------------------------------------------------------------------------

func _open_refill(type: PowerUp.Type) -> void:
	_main._on_refill_closed()
	await get_tree().process_frame
	_main._board._on_power_refill_requested(int(type))
	await _settle(0.55)


func _refill_group() -> void:
	var ids: Array[String] = ["r01", "r02", "r03", "r04", "r05", "r06", "r07"]
	var any: bool = false
	for id in ids:
		any = any or _wants(id)
	if not any:
		return
	await _start("res://resources/levels/level_04.tres")
	await _pile()
	GameState.reset_run()
	GameState.add_score(860)
	_set_stock({"bomb": 0, "upgrade": 1, "shake": 0, "clear_small": 2})
	await _refresh_bar()
	var stub := _StubProvider.new()
	_main.set_rewarded_provider(stub)
	var cases: Array = [
		["r01", "r01_refill_q0", PowerUp.Type.BOMB, {}, 335, true],
		["r02", "r02_refill_q1", PowerUp.Type.BOMB, {"bomb": 1}, 335, true],
		["r03", "r03_refill_q2", PowerUp.Type.BOMB, {"bomb": 2}, 335, true],
		["r04", "r04_refill_other", PowerUp.Type.SHAKE, {"bomb": 2}, 335, true],
		["r05", "r05_refill_noprov", PowerUp.Type.BOMB, {}, 335, false],
		["r06", "r06_refill_nodough", PowerUp.Type.BOMB, {}, 10, true],
	]
	for case in cases:
		if not _wants(case[0]):
			continue
		_set_quota(case[3])
		SaveManager.data["dough"] = case[4]
		_main.set_rewarded_provider(stub if case[5] else null)
		await _open_refill(case[2])
		await _capture(case[1])
	if _wants("r07"):
		_set_quota({})
		SaveManager.data["dough"] = 335
		_main.set_rewarded_provider(stub)
		await _open_refill(PowerUp.Type.BOMB)
		(_main._refill._ad as BaseButton).pressed.emit()
		await _settle(0.3)
		await _capture("r07_refill_pending")
	_main.set_rewarded_provider(null)
	_main._on_refill_closed()
	await _leave()


# --- Günlük meydan okuma ---------------------------------------------------------------------

func _challenge() -> void:
	if not _main.start_daily_challenge():
		print("HATA       : meydan okuma başlatılamadı")
		return
	await get_tree().process_frame
	await _relayout()
	await _settle(0.6)
	await _capture("h07_daily_challenge")
	_main._leave_daily_challenge()
	await _settle(0.3)


# --- Sahibin kaydı ----------------------------------------------------------------------------

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
