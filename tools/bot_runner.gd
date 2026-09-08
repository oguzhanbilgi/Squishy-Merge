extends Node
## Headless oynanabilirlik testi: gercek GameBoard'u gercek fizikle oynatir.
##
## Neden gerekli: tools/tier_geometry.py sadece ALAN hesabi yapiyor ve
## "zor ama mumkun" diyor. Gercek blokaj paketleme + yigin YUKSEKLIGI; bunu
## kagit uzerinde modellemek guvenilir degil. Bu bot ayni sahneyi, ayni
## RigidBody2D fizigini ve ayni tasma kuralini kullanarak N kosu oynar.
##
## Kullanim:
##   godot --headless --audio-driver Dummy --path . res://tools/bot_test.tscn -- <level> <kosu>
## <level>: 1-10, ya da 0 = sonsuz mod (genis kap — botun kendi tavanini olcmek icin)

const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
## Oyun sezgisi ekran goruntusu araciyla paylasiliyor.
const BOT_BRAIN = preload("res://tools/bot_brain.gd")

## Gercek zamanda 90 saniyelik bir round'u 90 saniye beklemek istemiyoruz.
## time_scale'i TEK BASINA yukseltmek fizik delta'sini buyutur ve fizigi
## bozar. Bunun yerine physics_ticks_per_second ile birlikte olcekleniyor:
##   delta = (1 / (60 * N)) * N = 1/60
## yani fizik adimi uretimdekiyle AYNEN ayni kaliyor, sadece saniyede N kat
## daha cok adim atiliyor. Hizli ama ayni fizik.
const SPEEDUP: int = 8

## Bir kosu icin oyun-ici ust sinir (guvenlik freni), saniye. Sonsuz modun
## ve suresiz level'larin bir yerde bitmesi icin.
const MAX_ROUND_SECONDS: float = 150.0

var _level: LevelData
var _trials: int = 20
var _trial_index: int = 0
var _board: Node2D
var _results: Array[Dictionary] = []
var _max_tier_this_run: int = 0
var _steps: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var level_number: int = 10
	if args.size() >= 1:
		level_number = int(args[0])
	if args.size() >= 2:
		_trials = int(args[1])

	var path: String = "res://resources/levels/endless.tres"
	if level_number > 0:
		path = "res://resources/levels/level_%02d.tres" % level_number
	_level = load(path)
	if _level == null:
		push_error("Level bulunamadi: %d" % level_number)
		get_tree().quit(1)
		return

	Engine.physics_ticks_per_second = 60 * SPEEDUP
	Engine.time_scale = float(SPEEDUP)
	Engine.max_physics_steps_per_frame = 16 * SPEEDUP

	print("=== headless bot | level %d | %d kosu ===" % [level_number, _trials])
	var objective: String = "hedef yok"
	if not _level.is_endless:
		objective = "tier %d" % _level.target_tier
		if _level.has_score_target():
			objective += " + %d skor" % _level.target_score
	# Sure limiti M8'de kaldirildi (GAME_DESIGN §3): tek fail state tasma.
	print("kap: %d x %d px | hedef: %s" % [
		int(_level.container_width), int(_level.playable_height), objective])
	print("yaricaplar: %s" % _radii_text())
	_start_trial()


func _radii_text() -> String:
	var parts: PackedStringArray = []
	for tier in range(1, TierConfig.MAX_TIER + 1):
		parts.append("%d" % int(TierConfig.radius(tier)))
	return ", ".join(parts)


func _start_trial() -> void:
	if _board != null and is_instance_valid(_board):
		_board.queue_free()
	_board = null
	_max_tier_this_run = 0
	_steps = 0
	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(_level)
	_board.round_finished.connect(_on_round_finished)
	add_child(_board)
	if not GameState.merge_performed.is_connected(_on_merge):
		GameState.merge_performed.connect(_on_merge)


func _on_merge(tier: int, _position: Vector2) -> void:
	_max_tier_this_run = maxi(_max_tier_this_run, tier)


func _on_round_finished(won: bool) -> void:
	print("  kosu %d/%d: %s | skor %d | ulasilan tier %d | %d merge | %d sn" % [
		_trial_index + 1, _trials, "KAZANDI" if won else "kaybetti",
		GameState.score, _max_tier_this_run, GameState.merge_count,
		int(float(_steps) / 60.0)])
	_results.append({
		"won": won,
		"score": GameState.score,
		"max_tier": _max_tier_this_run,
	})
	if GameState.merge_performed.is_connected(_on_merge):
		GameState.merge_performed.disconnect(_on_merge)
	_trial_index += 1
	if _trial_index < _trials:
		_start_trial.call_deferred()
	else:
		_report.call_deferred()


func _physics_process(_delta: float) -> void:
	if _board == null or not is_instance_valid(_board) or _board._is_finished:
		return
	# Guvenlik freni oyun zamanina bagli (her adim 1/60 oyun saniyesi).
	_steps += 1
	if float(_steps) / 60.0 > MAX_ROUND_SECONDS:
		_board._finish(false)
		return
	_play_turn()


func _play_turn() -> void:
	if _board._drop_cooldown > 0.0:
		return
	_board._set_aim(BOT_BRAIN.pick_x(_board, _board._pending_tier))
	_board._drop()


func _report() -> void:
	var wins: int = 0
	var scores: Array[int] = []
	var tiers: Array[int] = []
	for r in _results:
		if r["won"]:
			wins += 1
		scores.append(r["score"])
		tiers.append(r["max_tier"])
	scores.sort()
	tiers.sort()

	var tier_hist: Dictionary = {}
	for t in tiers:
		tier_hist[t] = int(tier_hist.get(t, 0)) + 1
	var hist_parts: PackedStringArray = []
	for t in range(1, TierConfig.MAX_TIER + 1):
		if tier_hist.has(t):
			hist_parts.append("t%d:%d" % [t, tier_hist[t]])

	print("")
	print("--- SONUC (%d kosu) ---" % _results.size())
	print("kazanma orani : %d/%d (%d%%)" % [wins, _results.size(),
		int(round(100.0 * float(wins) / float(_results.size())))])
	print("skor          : min %d | medyan %d | max %d" % [
		scores[0], scores[scores.size() / 2], scores[-1]])
	print("ulasilan tier : min %d | medyan %d | max %d" % [
		tiers[0], tiers[tiers.size() / 2], tiers[-1]])
	print("tier dagilimi : %s" % " ".join(hist_parts))
	get_tree().quit(0)
