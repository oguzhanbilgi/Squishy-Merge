extends Node
## Devam (revive) + stok 0 refill pencereleri — production çekimleri
## (M8.6-10). Dev aracı — oyun çalışırken kullanılmaz. `--headless` İLE
## ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn` üstünde, gerçek board (yığın) ve gerçek pencere
## yolları ile:
##
##   01 revive_first_available     2/2, sağlayıcı (test çifti) bağlı
##   02 revive_second_available    1/2 (bir devam kullanılmış)
##   03 revive_provider_unavailable sağlayıcı yok (bugünkü production)
##   04 revive_pending             DEVAM ET basıldı, cevap bekleniyor
##   05 revive_exhausted           0/2 savunma durumu (runtime'da açılmaz:
##                                 hak yoksa board doğrudan kaybeder)
##   06 revive_decline_transition  BİTİR'den 0.3 s sonra: teklif kapalı,
##                                 sonuç HENÜZ yok (altında pencere yok)
##   07 result_after_decline       BİTİR'den 1.4 s sonra: GERÇEK kayıp yolu →
##                                 sonuç (teselli 5 Hamur kayda yazılır,
##                                 çıkışta byte geri konur)
##   08 refill_bomb_enough_dough   Bomba, 335 Hamur, sağlayıcı bağlı
##   09 refill_bomb_insufficient   Bomba, 10 Hamur
##   10 refill_upgrade             Büyütücü (180)
##   11 refill_shake               Sarsıntı (100)
##   12 refill_clear               Temizleyici (160)
##   13 refill_rewarded_eligible   sağlayıcı bağlı, kota 1/1
##   14 refill_rewarded_quota_used sağlayıcı bağlı, kota 0/1
##   15 refill_provider_unavailable sağlayıcı yok
##   16 refill_purchase_pressed    SATIN AL basılı tutuluyor (gerçek işaretçi)
##   17 refill_purchase_success    bırakıldı: kanonik satın alma, pencere
##                                 kapandı, slot ×1, Hamur 335 → 215
##                                 (bellek vitrin verisi; çıkışta byte geri)
##
## KAYIT: vitrin değerleri BELLEKTE verilir; yalnız 07 ve 17 gerçek yazma
## yolunu koşar. Araç kayıt dosyasını başta byte olarak okur, çıkışta AYNEN
## geri yazar. Sahte reklam YOK: `_StubProvider` yalnız "talep gönderildi"
## durumu için, hiçbir şey vermez.
##
## Kullanım:
##   godot --path . res://tools/revive_refill_shots.tscn -- <çıktı> [GxY] [safe=61] [only=01,08]

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SHOT_SIZE := Vector2i(720, 1280)
const LEVEL_04: String = "res://resources/levels/level_04.tres"
const LEVEL_10: String = "res://resources/levels/level_10.tres"
const PILE_MEDIUM: Array = [[5, 3, 4, 2, 1], [2, 4, 1, 3], [3, 1, 2]]
const PILE_DANGER: Array = [[7, 5, 6], [4, 6, 3, 5], [5, 2, 4, 1, 3], [1, 4, 2, 5, 2], [3, 1, 4, 1, 3, 2], [2, 3, 1, 2, 1]]


## Ödüllü sağlayıcı TEST ÇİFTİ: talebi alır, hiçbir zaman cevap vermez.
class _StubProvider extends RefCounted:
	var revive_requests: int = 0
	var power_requests: int = 0

	func show_rewarded_revive(_main: Node) -> void:
		revive_requests += 1

	func show_rewarded_power(_main: Node, _type: int, _token: int) -> void:
		power_requests += 1


var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _main: Node2D
var _saved_data: Dictionary = {}
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _safe_top: float = -1.0
var _shots: int = 0
var _only: PackedStringArray = PackedStringArray()


func _wants(id: String) -> bool:
	return _only.is_empty() or _only.has(id)


func _ready() -> void:
	# Otomatik GÜNLÜK ÖDÜLLER penceresi (M8.9-02) bu harness'in konusu değil.
	DailyRewards.auto_popup_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://revive_refill_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_size = _shot_size(args)
	for arg in args:
		if String(arg).begins_with("safe="):
			_safe_top = float(String(arg).trim_prefix("safe="))
		elif String(arg).begins_with("only="):
			_only = String(arg).trim_prefix("only=").split(",", false)
	DisplayServer.window_set_size(_size)
	await get_tree().process_frame
	await get_tree().process_frame

	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_saved_data = SaveManager.data.duplicate(true)
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()

	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	if _main._daily != null:
		_main._daily.visible = false
	_apply_showcase()
	_apply_safe_top_to_shell()

	await _group_revive()
	await _group_refill()

	SaveManager.data = _saved_data
	_restore_save_file()
	print("bitti -> ", _out_dir, " (", _shots, " çekim)")
	get_tree().quit()


# --- Altyapı -----------------------------------------------------------------

func _restore_save_file() -> void:
	if not _had_save:
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()


func _shot_size(args: PackedStringArray) -> Vector2i:
	if args.size() < 2:
		return SHOT_SIZE
	var parts: PackedStringArray = args[1].split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return SHOT_SIZE
	return Vector2i(int(parts[0]), int(parts[1]))


func _tag() -> String:
	return "%dx%d%s" % [_size.x, _size.y, "_a36" if _safe_top >= 0.0 else ""]


func _capture(name: String) -> void:
	await _drawn_frame()
	await _drawn_frame()
	var img: Image = get_viewport().get_texture().get_image()
	var file: String = "%s_%s.png" % [name, _tag()]
	var err: int = img.save_png(_out_dir.path_join(file))
	if err == OK:
		_shots += 1
	print(("kaydedildi : " if err == OK else "HATA       : "), file)


## Bir çizilmiş kare bekler; 30 karede çizim gelmezse (pencere görünmez)
## kareyi zorla çizdirir (result_shots ile aynı).
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


## Gerçek işaretçi olayı: basış görseli ve gerçek `pressed` yolu için. `pos`
## tuval (canvas) koordinatı; olay pencere pikseliyle beslenir — 540×960 /
## 1080×2340 gibi ölçeklenen pencerelerde `get_screen_transform` ile çevrilir
## (aksi hâlde basış butonun dışına düşüyordu: ilk final koşusunda iki boyutta
## satın alma gerçekleşmedi).
func _pointer(pos: Vector2, pressed: bool) -> void:
	var window_pos: Vector2 = get_viewport().get_screen_transform() * pos
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = window_pos
	ev.global_position = window_pos
	if pressed:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(ev)


func _apply_safe_top_to_shell() -> void:
	if _safe_top < 0.0:
		return
	for screen in _main._screens:
		if screen.has_method("_layout_with_safe_top"):
			screen._layout_with_safe_top(_safe_top)


func _apply_safe_top_to_board() -> void:
	if _safe_top < 0.0 or _main._board == null:
		return
	_main._board._apply_layout(get_viewport().get_visible_rect().size, _safe_top)


func _apply_showcase() -> void:
	SaveManager.data["highest_level_unlocked"] = 11
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3}
	SaveManager.data["dough"] = 335
	SaveManager.data["daily_streak"] = 2
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.data["unlocked_skins"] = ["common_01", "common_02", "rare_02", "common_04", "rare_05", "epic_01"]
	SaveManager.data["equipped_skin"] = "rare_02"
	SaveManager.data["merges_since_bonus_chest"] = 49
	SaveManager.data["endless_high_score"] = 0
	SaveManager.data["powerups"] = {"bomb": 0, "upgrade": 0, "shake": 0, "clear_small": 0}
	SaveManager.data["powerup_starter_granted"] = true
	SaveManager.data["rewarded_power_date"] = ""
	SaveManager.data["rewarded_power_grants"] = 0
	SaveManager.data["sfx_enabled"] = true
	SaveManager.data["haptics_enabled"] = true


func _set_quota_used(used: bool) -> void:
	SaveManager.data["rewarded_power_date"] = Time.get_date_string_from_system() if used else ""
	SaveManager.data["rewarded_power_grants"] = 1 if used else 0


# --- Board yardımcıları (secondary_ui_shots ile aynı desen) -------------------

func _start_board(level_path: String, detach_main: bool = true) -> void:
	_main._start_level(load(level_path))
	await get_tree().process_frame
	await get_tree().process_frame
	_main._board._dismiss_tutorial()
	if detach_main:
		_main._board.round_finished.disconnect(_main._on_round_finished)
	_apply_safe_top_to_board()
	await get_tree().process_frame


func _leave_board() -> void:
	_main._result.hide_result()
	_main.abandon_run()
	await get_tree().process_frame
	_main._show_tab(0)
	await _settle()


func _spawn(tier: int, at: Vector2) -> Dumpling:
	return _main._board._spawn_dumpling(tier, at)


func _settle_physics(max_frames: int = 240) -> void:
	for i in max_frames:
		await get_tree().physics_frame
		var moving: bool = false
		for child in _main._board._dumpling_layer.get_children():
			var d := child as Dumpling
			if d != null and d.linear_velocity.length() > 4.0:
				moving = true
				break
		if not moving and i > 30:
			return


func _pile(rows: Array) -> void:
	var board: Node2D = _main._board
	var left: float = board._left_x()
	var right: float = board._right_x()
	var y: float = board.FLOOR_Y - 40.0
	for row in rows:
		var tiers: Array = row
		var total_w: float = 0.0
		for t in tiers:
			total_w += TierConfig.radius(t) * 2.0 + 6.0
		var x: float = (left + right) * 0.5 - total_w * 0.5
		var row_h: float = 0.0
		for t in tiers:
			var r: float = TierConfig.radius(t)
			x += r + 3.0
			_spawn(t, Vector2(clampf(x, left + r, right - r), y - r))
			x += r + 3.0
			row_h = maxf(row_h, r * 2.0)
		y -= row_h + 4.0
		for i in 12:
			await get_tree().physics_frame
	await _settle_physics()


# --- Devam (revive) ----------------------------------------------------------

func _open_offer(used: int) -> void:
	_main._revive.hide_offer()
	_main._board._is_fail_pending = false
	_main._board._revives_used = used
	_main._board._enter_fail_pending()
	await _settle()


func _group_revive() -> void:
	await _start_board(LEVEL_10)
	await _pile(PILE_DANGER)
	GameState.reset_run()
	GameState.add_score(3120)
	var stub := _StubProvider.new()

	if _wants("01"):
		_main.set_rewarded_provider(stub)
		await _open_offer(0)
		await _capture("01_revive_first_available")
	if _wants("02"):
		_main.set_rewarded_provider(stub)
		await _open_offer(1)
		await _capture("02_revive_second_available")
	if _wants("03"):
		_main.set_rewarded_provider(null)
		await _open_offer(0)
		await _capture("03_revive_provider_unavailable")
	if _wants("04"):
		_main.set_rewarded_provider(stub)
		await _open_offer(0)
		_main._revive.continue_button().pressed.emit()
		await _settle()
		await _capture("04_revive_pending")
	if _wants("05"):
		# Savunma durumu: runtime hak yokken teklif AÇMAZ (board doğrudan
		# kaybeder); pencere yine de dürüst: iki kalp soluk, CTA pasif.
		_main.set_rewarded_provider(null)
		_main._revive.hide_offer()
		_main._revive.show_offer(0, _main._board.max_revives(), false)
		await _settle()
		await _capture("05_revive_exhausted")
		_main._revive.hide_offer()
	if _wants("06") or _wants("07"):
		# Gerçek yol: teklif açık → BİTİR → round_finished(false) → RESULT_DELAY
		# → sonuç. 06 aradaki kare (teklif kapalı, sonuç yok), 07 sonuç.
		_main.set_rewarded_provider(null)
		_main._board._is_fail_pending = false
		_main._board._set_board_frozen(false)
		_main._board._revives_used = 0
		_main._board.round_finished.connect(_main._on_round_finished)
		GameState.reset_run()
		GameState.add_score(3120)
		await _open_offer(0)
		_main._revive.decline_button().pressed.emit()
		await _settle(0.3)
		if _wants("06"):
			await _capture("06_revive_decline_transition")
		await _settle(1.1)
		if _wants("07"):
			await _capture("07_result_after_decline")
	_main.set_rewarded_provider(null)
	_apply_showcase()
	await _leave_board()


# --- Stok 0 refill -----------------------------------------------------------

func _open_refill(type: PowerUp.Type) -> void:
	_main._board._on_power_refill_requested(int(type))
	await _settle()


func _close_refill() -> void:
	_main._on_refill_closed()
	await _settle(0.2)


func _group_refill() -> void:
	await _start_board(LEVEL_04)
	await _pile(PILE_MEDIUM)
	GameState.reset_run()
	GameState.add_score(860)
	_apply_showcase()
	_main._board._refresh_power_bar()
	await get_tree().process_frame
	var stub := _StubProvider.new()

	if _wants("08"):
		_main.set_rewarded_provider(stub)
		await _open_refill(PowerUp.Type.BOMB)
		await _capture("08_refill_bomb_enough_dough")
		await _close_refill()
	if _wants("09"):
		_main.set_rewarded_provider(stub)
		SaveManager.data["dough"] = 10
		await _open_refill(PowerUp.Type.BOMB)
		await _capture("09_refill_bomb_insufficient")
		await _close_refill()
		SaveManager.data["dough"] = 335
	_main.set_rewarded_provider(null)
	if _wants("10"):
		await _open_refill(PowerUp.Type.UPGRADE)
		await _capture("10_refill_upgrade")
		await _close_refill()
	if _wants("11"):
		await _open_refill(PowerUp.Type.SHAKE)
		await _capture("11_refill_shake")
		await _close_refill()
	if _wants("12"):
		await _open_refill(PowerUp.Type.CLEAR_SMALL)
		await _capture("12_refill_clear")
		await _close_refill()
	if _wants("13"):
		_main.set_rewarded_provider(stub)
		_set_quota_used(false)
		await _open_refill(PowerUp.Type.CLEAR_SMALL)
		await _capture("13_refill_rewarded_eligible")
		await _close_refill()
	if _wants("14"):
		_main.set_rewarded_provider(stub)
		_set_quota_used(true)
		await _open_refill(PowerUp.Type.CLEAR_SMALL)
		await _capture("14_refill_rewarded_quota_used")
		await _close_refill()
		_set_quota_used(false)
	if _wants("15"):
		_main.set_rewarded_provider(null)
		await _open_refill(PowerUp.Type.BOMB)
		await _capture("15_refill_provider_unavailable")
		await _close_refill()
	if _wants("16") or _wants("17"):
		# Gerçek işaretçi: SATIN AL basılı tutulurken kare (16), bırakınca
		# kanonik satın alma (PowerUpEconomy.purchase → tek yazma) → pencere
		# kapanır, board sürer, slot ×1 (17).
		_main.set_rewarded_provider(null)
		SaveManager.data["dough"] = 335
		await _open_refill(PowerUp.Type.BOMB)
		var button: Button = _main._refill._dough
		var center: Vector2 = button.get_global_rect().get_center()
		_pointer(center, true)
		await _settle(0.12)
		if _wants("16"):
			await _capture("16_refill_purchase_pressed")
		_pointer(center, false)
		await _settle(0.6)
		if _wants("17"):
			await _capture("17_refill_purchase_success")
		print("satin alma sonrasi: Hamur=", SaveManager.dough(), " bomba=", SaveManager.powerup_count(PowerUp.Type.BOMB))
	_main.set_rewarded_provider(null)
	_apply_showcase()
	await _leave_board()
