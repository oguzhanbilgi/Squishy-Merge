extends Node2D
## Akış kontrolü: sekmeler (Ana Sayfa / Harita / Koleksiyon / Mağaza) ->
## oyun -> sonuç -> sekmeler. Oyun kuralları GameBoard'da, ilerleme
## SaveManager'da, ödül kurası ChestSystem'de, fiyatlar Shop'ta; burada
## sadece bunlar birbirine bağlanıyor.

const TAB_BAR_SCENE: PackedScene = preload("res://scenes/ui/tab_bar.tscn")
const HOME_SCENE: PackedScene = preload("res://scenes/ui/home_screen.tscn")
const LEVEL_SELECT_SCENE: PackedScene = preload("res://scenes/ui/level_select.tscn")
const COLLECTION_SCENE: PackedScene = preload("res://scenes/ui/collection_album.tscn")
const SHOP_SCENE: PackedScene = preload("res://scenes/ui/shop_screen.tscn")
const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const ROUND_RESULT_SCENE: PackedScene = preload("res://scenes/ui/round_result.tscn")
const DAILY_POPUP_SCENE: PackedScene = preload("res://scenes/ui/daily_reward_popup.tscn")

## Round bitip sonuç ekranı açılmadan önceki kısa nefes payı — son merge'in
## efekti ekranda kalsın diye.
const RESULT_DELAY: float = 0.8

var _tabs: CanvasLayer
var _result: CanvasLayer
var _daily: CanvasLayer
var _board: Node2D
var _current_level: LevelData
## Sekme indeksi -> ekran. Sıra tab_bar.gd'deki Tab enum'u ile aynı.
var _screens: Array[CanvasLayer] = []
var _active_tab: int = 0


func _ready() -> void:
	_result = ROUND_RESULT_SCENE.instantiate()
	_result.retry_pressed.connect(_on_retry_pressed)
	_result.exit_pressed.connect(_on_exit_pressed)
	add_child(_result)

	var home: CanvasLayer = HOME_SCENE.instantiate()
	home.play_pressed.connect(_on_play_pressed)
	var select: CanvasLayer = LEVEL_SELECT_SCENE.instantiate()
	select.level_chosen.connect(_start_level)
	var album: CanvasLayer = COLLECTION_SCENE.instantiate()
	var shop: CanvasLayer = SHOP_SCENE.instantiate()
	_screens = [home, select, album, shop]
	for screen in _screens:
		add_child(screen)

	_tabs = TAB_BAR_SCENE.instantiate()
	_tabs.tab_selected.connect(_show_tab)
	add_child(_tabs)

	_daily = DAILY_POPUP_SCENE.instantiate()
	_daily.closed.connect(_on_daily_closed)
	add_child(_daily)

	_show_tab(0)
	_check_daily_reward()


# --- Sekmeler ---

## Tek bir ekran görünür kalır. Her geçişte refresh() çağrılıyor: Hamur ve
## koleksiyon sayacı dört ekranda da gösteriliyor, biri diğerini eskitmesin.
func _show_tab(tab: int) -> void:
	if tab < 0 or tab >= _screens.size():
		return
	_active_tab = tab
	for i in _screens.size():
		var screen: CanvasLayer = _screens[i]
		screen.visible = i == tab
		if i == tab and screen.has_method("refresh"):
			screen.refresh()
	_tabs.visible = true
	_tabs.set_active(tab)


## Oyun sırasında ve sonuç ekranında hiçbir sekme ekranı görünmemeli.
func _hide_shell() -> void:
	for screen in _screens:
		screen.visible = false
	_tabs.visible = false


func _on_play_pressed() -> void:
	_show_tab(1)
	_tabs.set_active(1)


## Günlük giriş ödülü (GAME_DESIGN.md §5.4). Günde bir kez, açılışta.
func _check_daily_reward() -> void:
	var result: Dictionary = DailyReward.claim_if_new_day()
	if result["claimed"]:
		_daily.show_reward(result)


func _on_daily_closed() -> void:
	_show_tab(_active_tab)


# --- Oyun ---

func _start_level(level: LevelData) -> void:
	_current_level = level
	_hide_shell()
	_result.hide_result()
	_clear_board()

	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(level)
	_board.round_finished.connect(_on_round_finished)
	add_child(_board)


func _clear_board() -> void:
	if _board != null:
		_board.queue_free()
		_board = null


func _on_round_finished(won: bool) -> void:
	var score: int = GameState.score
	var merges: int = GameState.merge_count
	var stars: int = _current_level.stars_earned(won, score)
	var new_record: bool = false

	if _current_level.is_endless:
		new_record = SaveManager.record_endless_score(score)
	elif won:
		SaveManager.complete_level(_current_level.level_number)
		SaveManager.record_stars(_current_level.level_number, stars)

	var rewards: Array[ChestReward] = _collect_rewards(won, merges)

	await get_tree().create_timer(RESULT_DELAY).timeout
	_result.show_result(_current_level, won, score, stars, rewards, new_record)


## GAME_DESIGN.md §5.2: level tamamlanınca 1 sandık, ayrıca her 75 merge'de
## level'dan bağımsız bir bonus sandık. §5.1: kaybedilse bile teselli ödülü.
func _collect_rewards(won: bool, merges: int) -> Array[ChestReward]:
	var rewards: Array[ChestReward] = []

	if won and not _current_level.is_endless:
		rewards.append(ChestSystem.open())

	for i in SaveManager.add_merges(merges):
		rewards.append(ChestSystem.open())

	if not won and not _current_level.is_endless:
		rewards.append(ChestSystem.consolation())

	return rewards


func _on_retry_pressed() -> void:
	_start_level(_current_level)


func _on_exit_pressed() -> void:
	_result.hide_result()
	_clear_board()
	# Oyundan çıkınca haritaya dönülür — oynanan yerin yanına.
	_show_tab(1)
	_tabs.set_active(1)
