extends Node
## İlk açılış tutorial'ı görsel QA çekimleri (M8.10). Dev aracı.
## `--headless` İLE ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## GERÇEK `main.tscn` üstünde, gerçek Level 1 board'u ve gerçek
## `TutorialController` ile: adımlar sırayla sürülür (BAŞLA, gerçek iki
## bırakma, gerçek merge, açıklama adımları) ve her adımda kare alınır.
## Sahte bir sunum yok — ekranda görünen şey oyuncunun göreceği şeydir.
##
## Ölçüm de yapar: her adımda coach kartının hedefi ÖRTÜP örtmediği
## (`no-overlap`), kartın güvenli alan içinde kalıp kalmadığı ve banner
## yuvasının 0 olduğu rapor satırlarına basılır.
##
## KAYIT DOSYASINA DOKUNUR: başta yedekler, sonunda byte-identical geri koyar.
##
## Kullanım:
##   godot --path . res://tools/tutorial_shots.tscn -- <çıktı_klasörü> [GxY] [safe=61]

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SHOT_SIZE := Vector2i(720, 1280)

var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _safe_top: float = -1.0
var _main: Node2D
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _shots: int = 0
var _report: Array[String] = []


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	# Kutlama adımı otomatik geçiyor: çekim için gerçek süreyi koru.
	TutorialController.time_scale = 1.0
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://tutorial_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_size = _shot_size(args)
	for arg in args:
		if String(arg).begins_with("safe="):
			_safe_top = float(String(arg).trim_prefix("safe="))
	DisplayServer.window_set_size(_size)
	await get_tree().process_frame
	await get_tree().process_frame

	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	# SIFIRDAN oyuncu: kayıt dosyası yok -> Main tutorial'a girer.
	_delete_save()
	SaveManager.load_game()

	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	await _settle(0.4)

	await _run_steps()

	_restore_save_file()
	SaveManager.load_game()
	print("\n--- ÖLÇÜM ---")
	for line in _report:
		print(line)
	print("bitti -> ", _out_dir, " (", _shots, " çekim)")
	get_tree().quit()


# --- Adımlar --------------------------------------------------------------------

## Adım beklemesi SÜREYE değil DURUMA bağlı: gerçek fizik (parçanın oturması,
## merge'in gerçekleşmesi) makineye göre farklı sürüyor; sabit uyku kullanınca
## çekimler bir adım kayıyordu.
func _await_step(step: int, timeout: float = 6.0) -> bool:
	var waited: float = 0.0
	while waited < timeout:
		if _tutorial().current_step() == step:
			await _settle(0.35)
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
	print("UYARI: adım beklenirken zaman aşımı (beklenen=%d, olan=%d)" % [
		step, _tutorial().current_step()])
	return false


func _run_steps() -> void:
	await _await_step(TutorialController.Step.WELCOME)
	await _shot("01_welcome")
	_tutorial().advance()                       # BAŞLA
	await _await_step(TutorialController.Step.FIRST_DROP)
	await _shot("02_first_drop")

	# Gerçek ilk bırakma (uçtan: tutorial clamp'i çalışsın).
	var board: Node2D = _board()
	var center: float = board.get_viewport_rect().size.x * 0.5
	board._set_aim(center - 400.0)
	await _settle(0.25)
	board._drop()
	await _await_step(TutorialController.Step.MATCH_DROP)
	await _shot("03_match_drop")

	# Gerçek ikinci bırakma: yardım hizalar, GERÇEK merge olur.
	board._set_aim(center + 300.0)
	await _settle(0.2)
	board._drop()
	await _await_step(TutorialController.Step.MERGE_SUCCESS)
	await _shot("04_merge_success")

	await _await_step(TutorialController.Step.GOAL)
	await _shot("05_goal")
	_tutorial().advance()
	await _await_step(TutorialController.Step.DANGER)
	await _shot("06_danger")
	_tutorial().advance()
	await _await_step(TutorialController.Step.POWERS)
	await _shot("07_powers")
	_tutorial().advance()
	await _await_step(TutorialController.Step.READY)
	await _shot("08_ready")

	# Geri onayı (Android geri / oyun içi Geri).
	_tutorial().handle_back()
	await _settle(0.4)
	await _shot("09_back_prompt")
	_tutorial().advance()                       # DEVAM ET
	await _settle(0.4)

	# Tamamla: overlay kapanır, round reklamsız sürer.
	_tutorial().advance()
	await _settle(0.6)
	await _shot("10_after_complete")
	_measure_after_complete()


# --- Ölçüm ------------------------------------------------------------------------

func _measure(name: String) -> void:
	var overlay: TutorialOverlay = _main._tutorial_overlay
	if not overlay.is_open():
		_report.append("%-18s overlay kapalı" % name)
		return
	var card: Rect2 = overlay.card_rect()
	var target: Rect2 = overlay.target_rect()
	var view: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	var overlap: bool = target.size != Vector2.ZERO and GameplayLayout.overlaps(card, target)
	var top_ok: bool = card.position.y >= UiKit.safe_top(view) - 0.5
	var bottom_ok: bool = card.end.y <= view.y - UiKit.bottom_inset(view) + 0.5
	var in_x: bool = card.position.x >= 0.0 and card.end.x <= view.x
	# Güvenli bant (HUD'un altı ↔ şeridin üstü): kart ve ATLA buraya sığmalı.
	var band: Rect2 = _board().tutorial_safe_band() if _board() != null else Rect2()
	var skip: Rect2 = overlay.skip_button().get_global_rect()
	var band_ok: bool = band.size.y <= 0.0 or (card.position.y >= band.position.y - 0.5
		and card.end.y <= band.end.y + 0.5)
	var skip_ok: bool = band.size.y <= 0.0 or (skip.position.y >= band.position.y - 0.5
		and skip.end.y <= band.end.y + 0.5)
	_report.append("%-18s kart=%s hedef=%s | örtüşme=%s üst=%s alt=%s yatay=%s bant=%s atla=%s banner=%.0f" % [
		name, _r(card), _r(target), "VAR!" if overlap else "yok",
		"OK" if top_ok else "TAŞMA", "OK" if bottom_ok else "TAŞMA",
		"OK" if in_x else "TAŞMA", "OK" if band_ok else "TAŞMA",
		("OK" if skip_ok else "TAŞMA") if overlay.skip_button().visible else "gizli",
		UiKit.banner_slot()])


func _measure_after_complete() -> void:
	var board: Node2D = _board()
	_report.append("%-18s overlay=%s board_kilit=%s board_pause=%s banner=%.0f" % [
		"10_after_complete", str(_main._tutorial_overlay.is_open()),
		str(board.is_tutorial_input_locked()) if board != null else "-",
		str(board.is_tutorial_paused()) if board != null else "-",
		UiKit.banner_slot()])


func _r(rect: Rect2) -> String:
	if rect.size == Vector2.ZERO:
		return "(yok)"
	return "(%.0f,%.0f %.0fx%.0f)" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


# --- Altyapı ----------------------------------------------------------------------

func _tutorial() -> TutorialController:
	return _main._tutorial as TutorialController


func _board() -> Node2D:
	return _main._board


func _shot(name: String) -> void:
	_measure(name)
	await _capture(name)


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
		RenderingServer.force_draw(false)


func _settle(seconds: float = 0.45) -> void:
	await get_tree().create_timer(seconds).timeout
	await get_tree().process_frame


func _delete_save() -> void:
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))


func _restore_save_file() -> void:
	if not _had_save:
		_delete_save()
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()
