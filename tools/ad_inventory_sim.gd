extends Node
## TASK/052 — zorunlu geçiş reklamı ENVANTER simülasyonu (rapor aracı, kontrol suite'i değil). Gerçek Main + gerçek
## board + sahte SDK; her round'un aktif süresi yöneticinin saatine deterministik verilir, round üretim yoluyla (devam
## teklifi → reddet) kesinleşir. Çıktı: oturum başına round / doğal mola / gösterim / atlama sebebi. Gelir (para)
## tahmini DEĞİLDİR — yalnız uygun doğal mola fırsatı sayar. Düzeltmesiz kodda da koşar (yalnız eski API'ler):
## temel (900 sn) ile TASK/052 (2 round + 300 sn) aynı oturumlarla karşılaştırılır.
## SAHİBİN KAYDINA DOKUNMAZ: SaveManager `user://qa_ad_inventory_sim/` altına yönlendirilir; sahibin kayıt ailesi
## başta / sonda bayt karşılaştırılır.
##
##   godot --headless --audio-driver Dummy --path . res://tools/ad_inventory_sim.tscn

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_ad_inventory_sim"
const PATH: String = DIR + "/save.json"
const MON: String = "2026-09-28"
const THU: String = "2026-10-01"
## Oturumlar: ad, round sayısı, round başına aktif sn, ödüllü devamın alındığı round (0 = yok), meydan okumanın
## araya girdiği round (0 = yok; meydan okumada geçen aktif sn MEYDAN_SEC), taze kurulum (tutorial + tutorial'dan doğan
## Level 1 önce).
const SESSIONS: Array[Dictionary] = [
	{"name": "S1 5 dk / 2 round", "rounds": 2, "sec": 150.0, "rewarded": 0, "challenge": 0, "fresh": false},
	{"name": "S2 10 dk / 4 round", "rounds": 4, "sec": 150.0, "rewarded": 0, "challenge": 0, "fresh": false},
	{"name": "S3 20 dk / 8 round", "rounds": 8, "sec": 150.0, "rewarded": 0, "challenge": 0, "fresh": false},
	{"name": "S4 20 dk / 8 round + ödüllü devam (4. round sonu)", "rounds": 8, "sec": 150.0, "rewarded": 4,
		"challenge": 0, "fresh": false},
	{"name": "S5 22 dk / 8 round + meydan okuma (4. round'dan sonra, 120 sn)", "rounds": 8, "sec": 150.0,
		"rewarded": 0, "challenge": 4, "fresh": false},
	{"name": "S6 kısa round'lar 10 dk / 10 round (60 sn)", "rounds": 10, "sec": 60.0, "rewarded": 0, "challenge": 0,
		"fresh": false},
	{"name": "S7 taze kurulum: tutorial + Level 1, sonra 6 round (150 sn)", "rounds": 6, "sec": 150.0, "rewarded": 0,
		"challenge": 0, "fresh": true},
]
const CHALLENGE_SEC: float = 120.0

var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _main: Node2D
var _main_script: GDScript
var _fake: FakeAdBackend


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_main_script = load("res://scripts/main.gd")
	_owner_state = _owner_snapshot()
	_saved_data = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	SaveManager.save_path = PATH
	get_window().size = Vector2i(720, 1280)
	var consts: Dictionary = (load("res://scripts/ads/monetization_manager.gd") as GDScript).get_script_constant_map()
	var tree: String = "baseline (900 sn aktif)" if consts.has("INTERSTITIAL_INTERVAL_SEC") \
		else "TASK/052 (%d round + %d sn aktif)" % [_policy("FORCED_INTERSTITIAL_MIN_ROUNDS"),
			int(_policy("FORCED_INTERSTITIAL_MIN_INTERVAL_SEC"))]
	print("SIM politika: %s, tam ekran beklemesi %d sn" % [tree, int(MonetizationManager.FULLSCREEN_AD_COOLDOWN_SEC)])
	var total_breaks: int = 0
	var total_shows: int = 0
	for session in SESSIONS:
		var row: Dictionary = await _run(session)
		total_breaks += int(row["breaks"])
		total_shows += int(row["shows"])
		print("SIM %-62s | normal mola %2d | zorunlu gösterim %d | %s" % [session["name"], row["breaks"], row["shows"],
			" ".join(row["log"])])
	print("SIM TOPLAM normal mola %d, zorunlu gösterim %d" % [total_breaks, total_shows])
	await _teardown_main()
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	DailyRewards.clock_override = ""
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)
	print("SIM sahibin kayıt ailesi bayt-aynı: %s" % str(_owner_snapshot() == _owner_state))
	get_tree().quit(0)


func _policy(key: String) -> Variant:
	var script: GDScript = load("res://scripts/ads/ad_policy.gd")
	return script.get_script_constant_map()[key] if script != null else 0


## Bir oturum: her normal round'un sonunda doğal mola; gösterim olursa SDK "gösterildi" + kapanış (oyuncu izledi).
func _run(session: Dictionary) -> Dictionary:
	await _boot(bool(session["fresh"]))
	var ads: MonetizationManager = _main._ads
	var log: Array[String] = []
	var shows: int = 0
	var breaks: int = 0
	if session["fresh"]:
		# Tutorial (reklamsız) → ATLA → tutorial'dan doğan Level 1 round'u biter (monetizasyon ertelemesi sürer) —
		# zorunlu reklam molası DEĞİL, round sayılmaz.
		var tutorial: TutorialController = _main._tutorial
		if tutorial != null and tutorial.is_active():
			tutorial.skip()
			await _settle(2)
		ads._tick_active(session["sec"])
		var fresh_shows: int = _fake.interstitial_shows.size()
		await _finish(_main._board)
		log.append("T+L1:%s" % ("GÖSTERİM!" if _fake.interstitial_shows.size() > fresh_shows else "yok"))
	for i in int(session["rounds"]):
		var round_no: int = i + 1
		_main._start_level(_level(3))
		await _settle(3)
		await _ready_ads()
		var board: Node2D = _main._board
		ads._tick_active(session["sec"])
		if int(session["rewarded"]) == round_no:
			await _rewarded_revive(board)
		var before: int = _fake.interstitial_shows.size()
		AdEvents.clear_recent()
		await _finish(board)
		breaks += 1
		if _fake.interstitial_shows.size() == before + 1:
			var id: String = _fake.interstitial_shows[-1]
			_fake.emit_interstitial_showed(id)
			_fake.emit_interstitial_dismissed(id)
			await _settle(3)
			shows += 1
			log.append("r%d:GÖSTERİM" % round_no)
		else:
			log.append("r%d:%s" % [round_no, str(AdEvents.last(&"interstitial_skipped_not_ready").get("reason", "?"))])
		await _ready_ads()
		if int(session["challenge"]) == round_no:
			var challenge_shows: int = _fake.interstitial_shows.size()
			var played: bool = await _challenge(ads)
			log.append("MO:%s" % ("yok-oynanmadı" if not played else ("GÖSTERİM!"
				if _fake.interstitial_shows.size() > challenge_shows else "deneme-yok")))
	return {"breaks": breaks, "shows": shows, "log": log}


## Monetizasyon (yeniden) açıldıysa rıza güncellemesini cevapla; bekleyen yüklemeleri tamamla (reklam her molada hazır).
func _ready_ads() -> void:
	var ads: MonetizationManager = _main._ads
	if ads.ads_state() == MonetizationManager.AdsState.CONSENT_CHECKING:
		_fake.complete_consent_update(true)
		await _settle(1)
	if not ads.sdk_ready():
		_fake.complete_init()
		await _settle(1)
	while not _fake.pending_interstitial.is_empty():
		_fake.complete_interstitial_load(true)
	while not _fake.pending_rewarded.is_empty():
		_fake.complete_rewarded_load(true)
	while not _fake.pending_banner.is_empty():
		_fake.complete_banner_load(true)
	await _settle(1)


## Round'un sonunda ödüllü devam (oyuncu seçti): reklam izlendi, ödül, kapanış → 60 sn tam ekran beklemesi.
func _rewarded_revive(board: Node2D) -> void:
	board._enter_fail_pending()
	await _settle(2)
	_main._revive.continue_button().pressed.emit()
	await _settle(1)
	var rid: String = _main._ads.request_info()["ad_id"]
	_fake.emit_rewarded_showed(rid)
	_fake.emit_rewarded_earned(rid)
	_fake.emit_rewarded_dismissed(rid)
	await _settle(2)


## Araya giren meydan okuma: aktif süre sayar, gerçek merge ile başarı; geçiş reklamı denemesi yok.
func _challenge(ads: MonetizationManager) -> bool:
	if not _main.start_daily_challenge():
		return false
	await _settle(3)
	ads._tick_active(CHALLENGE_SEC)
	var board: Node2D = _main._board
	var tier: int = board.level.target_tier - 1
	var r: float = TierConfig.radius(tier)
	var x: float = board._right_x() - r - 12.0
	var floor_y: float = float(board.get_script().get_script_constant_map()["FLOOR_Y"])
	board._spawn_dumpling(tier, Vector2(x, floor_y - r - 1.0))
	board._spawn_dumpling(tier, Vector2(x, floor_y - 3.0 * r - 30.0))
	var guard: int = 0
	while not board.is_finished() and guard < 600:
		await get_tree().physics_frame
		guard += 1
	await _wait(_delay() + 0.15)
	await _settle(2)
	return board.is_finished()


func _finish(board: Node2D) -> void:
	board._enter_fail_pending()
	await _settle(2)
	_main.decline_revive()
	await _wait(_delay() + 0.15)
	await _settle(2)


func _boot(fresh: bool) -> void:
	await _teardown_main()
	_clean()
	DailyRewards.clock_override = THU
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 2},
		"endless_high_score": 0, "dough": 335, "total_merges": 40, "merges_since_bonus_chest": 10,
		"unlocked_skins": ["common_01"], "profile_showcase": [], "powerups": {"bomb": 2, "upgrade": 9, "shake": 1,
		"clear_small": 1}, "powerup_starter_granted": true, "onboarding_completed": not fresh,
		"onboarding_completed_day": "", "daily_streak": 3, "last_login_date": Time.get_date_string_from_system(),
		"age_ad_band": "ADULT", "next_age_transition_date": "", "player_meta_version": 1, "player_xp": 400,
		"total_rounds_played": 12, "highest_tier_created": 4,
		"daily_rewards": {"day_key": THU, "free_chest_claimed": true, "ad_chests_claimed": 2,
			"dough_ad_claimed": true, "popup_seen_day": THU, "last_seen_day_key": THU},
		"missions": {"version": 1, "day_key": THU, "week_start_day_key": MON,
			"daily_progress": {"daily_merges": 5, "daily_rounds": 0, "daily_clear": 0}, "daily_rewarded": [],
			"weekly_progress": {"weekly_merges": 30, "weekly_rounds": 4, "weekly_clears": 2}, "weekly_rewarded": []}}
	if fresh:
		for key in ["highest_level_unlocked", "level_stars", "total_merges", "player_xp", "total_rounds_played"]:
			content.erase(key)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(content, "\t"))
	file.close()
	SaveManager.load_game()
	_fake = FakeAdBackend.new()
	_fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	_main_script.set("ads_backend_override", _fake)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _settle(3)
	_main_script.set("ads_backend_override", null)
	_main._ads.set_process(false)
	_fake.complete_consent_update(true)
	_fake.complete_init()
	await _settle(2)
	while not _fake.pending_banner.is_empty():
		_fake.complete_banner_load(true)
	while not _fake.pending_interstitial.is_empty():
		_fake.complete_interstitial_load(true)
	while not _fake.pending_rewarded.is_empty():
		_fake.complete_rewarded_load(true)
	await _settle(2)


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _settle(3)


func _level(number: int) -> LevelData:
	for level in LevelLibrary.load_levels():
		if level.level_number == number:
			return level
	return null


func _delay() -> float:
	return float(_main_script.get_script_constant_map()["RESULT_DELAY"])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _clean() -> void:
	for path in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for path in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out
