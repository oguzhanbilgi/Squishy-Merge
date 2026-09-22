extends Node
## M8.9-01.1 — A36 AdMob TEST-AD cihaz kapısı sürücüsü. Dev aracı; üretim
## APK'sında YOK (`tools/*` preset dışında), ayrı QA paketiyle
## (`…squishymerge.qa`) yüklenir ve kendi veri dizininde çalışır (owner
## kaydına dokunamaz).
##
## Gerçek `main.tscn` + gerçek `MonetizationManager` + gerçek AdmobBackend
## (Google TEST kimlikleri). Sürücü yalnız GÖZLEMLER ve oyun durumunu kurar;
## reklam SDK'sını taklit etmez. Sahte arka uç (`FakeAdBackend`) yalnız
## `remake fake` ile, hata yolları (yüklenememe / gösterilememe) için.
##
## Komut kanalı: `user://qa_cmd.txt` (adb run-as ile yazılır, okunan komut
## silinir); durum `user://qa_state.txt` (buton dikdörtgenleri EKRAN
## pikseli); olaylar `user://qa_events.txt`. Bütün dokunuşlar CİHAZDA gerçek
## dokunuşla (adb input tap) yapılır.
##
## Komutlar:
##   state · quit · events · idle S
##   tab N                    0 Ana Sayfa · 1 Harita · 2 Koleksiyon · 3 Mağaza
##   level N                  level'ı başlat (tutorial kapalı)
##   fail                     board'u fail-pending'e al → gerçek Devam penceresi
##   refill bomb|upgrade|shake|clear
##   stock B U S C · dough N · quota 0|1 · unlock N
##   abandon · leave · settings · close_settings
##   remake real [geo] [rewarded_id]   Main'i gerçek arka uçla yeniden kur
##                            (geo: eea|disabled|other|regulated_us_state;
##                             rewarded_id: ör. geçersiz kimlik → gerçek no-fill)
##   remake fake              Main'i sahte arka uçla yeniden kur
##   reset_consent            UMP durumunu sıfırla (yalnız gerçek arka uç; test)
##   fake_consent ok|fail · fake_init · fake_load ok|fail · fake_show_fail
##   fake_earned · fake_dismiss · fake_banner ok|fail
##   ensure                   MonetizationManager.ensure_rewarded()
##
## M8.9-02.2 (günlük ödüller / geçiş reklamı / onboarding — yalnız QA):
##   onboarding 0|1           kayıt + yönetici onboarding bayrağı
##   login DAYS_AGO STREAK    giriş ödülü durumu (gerçek yerel güne göre; -1 = yarın)
##   dailyq FREE ADCHESTS DOUGH [POPUP_SEEN]  bugünkü günlük kotalar (0|1, 0..2, 0|1, 0|1)
##   dayclock YYYY-MM-DD|none DailyRewards.clock_override (cihaz saati DEĞİŞMEZ)
##   fresh                    yeni oyuncu kaydı (onboarding false) + Main yeniden
##   relaunch                 Main'i aynı arka uçla yeniden kur (uygulama açılışı gibi)
##   daily_open · daily_close · daily_reveal none|SKIN_ID [RARITY]   (reveal = yalnız sunum)
##   clock SECONDS            aktif süre saatine saniye enjekte (_tick_active)
##   inter_block              hazır geçiş reklamını at + döngüyü bitmiş say (hazır değil yolu)
##   fake_iload ok|fail · fake_ishowed · fake_ishow_fail · fake_idismiss
##   bitir                    Devam penceresinde BİTİR (kod yolu; cihazda gerçek dokunuş tercih)

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const CMD_PATH: String = "user://qa_cmd.txt"
const STATE_PATH: String = "user://qa_state.txt"
const EVENTS_PATH: String = "user://qa_events.txt"
const POLL: float = 0.2

var _main: Node2D = null
var _main_script: GDScript = load("res://scripts/main.gd")
var _fake: FakeAdBackend = null
var _backend_kind: String = "real"
var _idle: String = "-"
var _last: String = "-"
var _finished_count: int = 0
var _event_log: PackedStringArray = PackedStringArray()
## Sahte arka uçta sonlandırılmış (dismiss/show_fail) geçiş gösterimi sayısı.
var _fake_ishow_done: int = 0


func _ready() -> void:
	_remove(CMD_PATH)
	AdEvents.subscribe(_on_event)
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_showcase()
	SaveManager.save_game()
	await _make_main(null)
	print("[qa] ready view=", DisplayServer.window_get_size())
	_write_state("ready")
	while true:
		await get_tree().create_timer(POLL).timeout
		var cmd: String = _read_cmd()
		if cmd == "":
			continue
		if cmd == "quit":
			break
		await _handle(cmd)
	_write_state("quit")
	get_tree().quit()


func _on_event(name: StringName, event: Dictionary) -> void:
	var extra: Array[String] = []
	for key in ["placement", "power", "ad_id", "code", "message", "stale", "earned", "refreshed", "surface", "reward_type", "amount", "cancelled",
			"natural_break", "reason", "eligible", "active_elapsed_sec", "day_key", "auto", "dough", "pending", "remaining", "kind", "source", "skin", "cooldown_sec"]:
		if event.has(key):
			extra.append("%s=%s" % [key, str(event[key])])
	_event_log.append("%s %s %s" % [Time.get_time_string_from_system(), name, " ".join(extra)])
	var file := FileAccess.open(EVENTS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_event_log))
		file.close()


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _read_cmd() -> String:
	if not FileAccess.file_exists(CMD_PATH):
		return ""
	var cmd: String = FileAccess.get_file_as_string(CMD_PATH).strip_edges()
	_remove(CMD_PATH)
	return cmd


func _settle(seconds: float = 0.3) -> void:
	await get_tree().create_timer(seconds).timeout
	await get_tree().process_frame


func _type_of(word: String) -> int:
	match word:
		"bomb": return int(PowerUp.Type.BOMB)
		"upgrade": return int(PowerUp.Type.UPGRADE)
		"shake": return int(PowerUp.Type.SHAKE)
		"clear": return int(PowerUp.Type.CLEAR_SMALL)
	return -1


func _board() -> Node2D:
	if _main == null:
		return null
	return _main._board if _main._board != null and is_instance_valid(_main._board) else null


func _ads() -> MonetizationManager:
	return _main._ads if _main != null else null


## Vitrin kayıt durumu (QA paketinin KENDİ kaydı): her level açık, orta bakiye.
func _apply_showcase() -> void:
	SaveManager.data["highest_level_unlocked"] = 11
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3}
	SaveManager.data["dough"] = 335
	SaveManager.data["daily_streak"] = 2
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.data["unlocked_skins"] = ["common_01", "common_02", "rare_02"]
	SaveManager.data["equipped_skin"] = "rare_02"
	SaveManager.data["powerups"] = {"bomb": 2, "upgrade": 1, "shake": 0, "clear_small": 1}
	SaveManager.data["powerup_starter_granted"] = true
	SaveManager.data["rewarded_power_date"] = ""
	SaveManager.data["rewarded_power_grants"] = 0
	# M8.9-02: mevcut (migrate edilmiş) oyuncu; günlük kotalar taze.
	SaveManager.data["onboarding_completed"] = true
	SaveManager.data["daily_rewards"] = SaveManager.DAILY_REWARDS_DEFAULT.duplicate()


## Yerel takvimde bugünden `days` gün önce (negatif = ileri).
func _days_ago(days: int) -> String:
	var unix: int = Time.get_unix_time_from_datetime_string(Time.get_date_string_from_system() + "T12:00:00") - days * 86400
	return Time.get_date_string_from_unix_time(unix).substr(0, 10)


func _make_main(backend: AdBackend) -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await get_tree().process_frame
		await get_tree().process_frame
	_main_script.ads_backend_override = backend
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_main_script.ads_backend_override = null
	_finished_count = 0


func _hook_finished() -> void:
	_finished_count = 0
	if _board() != null:
		_main._board.round_finished.connect(func(_won: bool) -> void: _finished_count += 1)


func _handle(line: String) -> void:
	var parts: PackedStringArray = line.split(" ", false)
	var cmd: String = parts[0]
	print("[qa] cmd ", line)
	match cmd:
		"state", "events":
			pass
		"tab":
			_main._show_tab(int(parts[1]) if parts.size() > 1 else 0)
			await _settle()
		"level":
			var n: int = int(parts[1]) if parts.size() > 1 else 10
			_main._start_level(load("res://resources/levels/level_%02d.tres" % n))
			await get_tree().process_frame
			await get_tree().process_frame
			_hook_finished()
			await _settle()
		"fail":
			if _board() != null:
				_main._board._enter_fail_pending()
				await _settle(0.4)
		"refill":
			if _board() != null and parts.size() > 1:
				var t: int = _type_of(parts[1])
				if t >= 0:
					_main._board._on_power_refill_requested(t)
					await _settle(0.4)
		"stock":
			SaveManager.data["powerups"] = {"bomb": int(parts[1]), "upgrade": int(parts[2]),
				"shake": int(parts[3]), "clear_small": int(parts[4])}
			SaveManager.save_game()
			if _board() != null:
				_main._board._refresh_power_bar()
		"dough":
			SaveManager.data["dough"] = int(parts[1])
			SaveManager.save_game()
		"quota":
			var used: bool = parts.size() > 1 and parts[1] == "1"
			SaveManager.data["rewarded_power_date"] = Time.get_date_string_from_system() if used else ""
			SaveManager.data["rewarded_power_grants"] = 1 if used else 0
			SaveManager.save_game()
		"unlock":
			SaveManager.data["highest_level_unlocked"] = int(parts[1])
			SaveManager.save_game()
		"abandon":
			_main.abandon_run()
			await _settle()
		"leave":
			_main._result.hide_result()
			_main.abandon_run()
			await get_tree().process_frame
			_main._show_tab(0)
			await _settle()
		"settings":
			_main.open_settings()
			await _settle()
		"close_settings":
			_main.close_settings()
			await _settle()
		"remake":
			var kind: String = parts[1] if parts.size() > 1 else "real"
			if kind == "fake":
				_fake = FakeAdBackend.new()
				_fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
				_fake_ishow_done = 0
				_backend_kind = "fake"
				await _make_main(_fake)
			else:
				var config: AdConfig = AdConfig.load_project()
				if parts.size() > 2:
					config.debug_geography = parts[2] if parts[2] != "none" else ""
				if parts.size() > 3:
					config.rewarded_id = parts[3]
				var real: AdmobBackend = AdmobBackend.create(config)
				_backend_kind = "real geo=%s rewarded=%s" % [config.debug_geography, config.rewarded_id]
				_fake = null
				await _make_main(real)
		"reset_consent":
			var ads: MonetizationManager = _ads()
			if ads != null and ads.backend() is AdmobBackend:
				(ads.backend() as AdmobBackend)._admob.reset_consent_info()
				_last = "reset_consent"
		"ensure":
			if _ads() != null:
				_ads().ensure_rewarded()
		"fake_consent":
			if _fake != null:
				_fake.complete_consent_update(parts.size() > 1 and parts[1] == "ok")
		"fake_init":
			if _fake != null:
				_fake.complete_init()
		"fake_load":
			if _fake != null:
				_last = "fake_load -> %s" % _fake.complete_rewarded_load(parts.size() > 1 and parts[1] == "ok")
		"fake_show_fail":
			if _fake != null and not _fake.rewarded_shows.is_empty():
				_fake.emit_rewarded_show_failed(_fake.rewarded_shows[-1])
		"fake_earned":
			if _fake != null and not _fake.rewarded_shows.is_empty():
				_fake.emit_rewarded_earned(_fake.rewarded_shows[-1])
		"fake_dismiss":
			if _fake != null and not _fake.rewarded_shows.is_empty():
				_fake.emit_rewarded_dismissed(_fake.rewarded_shows[-1])
		"fake_banner":
			if _fake != null:
				_last = "fake_banner -> %s" % _fake.complete_banner_load(parts.size() > 1 and parts[1] == "ok")
		"idle":
			await _idle_probe(float(parts[1]) if parts.size() > 1 else 15.0)
		# --- M8.9-02.2 ---
		"onboarding":
			var done: bool = parts.size() > 1 and parts[1] == "1"
			if done:
				SaveManager.complete_onboarding()
			else:
				SaveManager.data["onboarding_completed"] = false
				SaveManager.save_game()
			if _ads() != null:
				_ads().set_onboarding_completed(done)
			_main._show_tab(_main._active_tab)
			await _settle()
		"login":
			var days: int = int(parts[1]) if parts.size() > 1 else 1
			SaveManager.data["last_login_date"] = _days_ago(days) if days < 999 else ""
			SaveManager.data["daily_streak"] = int(parts[2]) if parts.size() > 2 else 0
			SaveManager.save_game()
			_main._show_tab(_main._active_tab)
			await _settle()
		"dailyq":
			var raw: Dictionary = SaveManager.DAILY_REWARDS_DEFAULT.duplicate()
			var key: String = DailyRewards.day_key()
			raw["day_key"] = key
			raw["free_chest_claimed"] = parts.size() > 1 and parts[1] == "1"
			raw["ad_chests_claimed"] = int(parts[2]) if parts.size() > 2 else 0
			raw["dough_ad_claimed"] = parts.size() > 3 and parts[3] == "1"
			raw["popup_seen_day"] = key if (parts.size() > 4 and parts[4] == "1") else ""
			raw["last_seen_day_key"] = SaveManager.daily_last_seen_day_key()
			SaveManager.data["daily_rewards"] = raw
			SaveManager.save_game()
			_main._show_tab(_main._active_tab)
			await _settle()
		"dayclock":
			DailyRewards.clock_override = "" if (parts.size() < 2 or parts[1] == "none") else parts[1]
			DailyRewards.observe_day()
			_main._show_tab(_main._active_tab)
			await _settle()
		"fresh":
			SaveManager.data = SaveManager.DEFAULT_DATA.duplicate(true)
			SaveManager.data["powerup_starter_granted"] = false
			SaveManager._grant_starter_powerups()
			SaveManager.save_game()
			await _remake_current()
		"relaunch":
			await _remake_current()
		"daily_open":
			_main.open_daily_rewards()
			await _settle()
		"daily_close":
			_main._daily_rewards.close_popup()
			await _settle()
		"daily_reveal":
			var reward := DailyChestReward.new()
			reward.source = "free"
			reward.day_key = DailyRewards.day_key()
			reward.base_dough = DailyChestLoot.GUARANTEED_DOUGH
			if parts.size() > 1 and parts[1] != "none":
				reward.skin = SkinLibrary.find(StringName(parts[1]))
				reward.skin_rolled = reward.skin != null
				reward.rarity = int(reward.skin.rarity) if reward.skin != null else -1
			if not _main._daily_rewards.visible:
				_main.open_daily_rewards()
				await _settle()
			_main._daily_rewards.show_reveal(reward)
			await _settle()
		"clock":
			if _ads() != null:
				_ads()._tick_active(float(parts[1]) if parts.size() > 1 else 0.0)
		"inter_block":
			if _ads() != null:
				_ads()._cancel_timer(_ads()._interstitial_retry_timer)
				_ads()._interstitial_retry_timer = null
				_ads()._discard_ready_interstitial()
				_ads()._interstitial_attempts = MonetizationManager.INTERSTITIAL_MAX_ATTEMPTS
				_ads()._interstitial_last_attempt_msec = Time.get_ticks_msec()
				_ads()._set_interstitial_state(MonetizationManager.InterstitialState.FAILED)
		"fake_iload":
			if _fake != null:
				_last = "fake_iload -> %s" % _fake.complete_interstitial_load(parts.size() > 1 and parts[1] == "ok")
		"fake_ishowed":
			if await _fake_ishow_pending():
				_fake.emit_interstitial_showed(_fake.interstitial_shows[-1])
		"fake_ishow_fail":
			if await _fake_ishow_pending():
				_fake_ishow_done = _fake.interstitial_shows.size()
				_fake.emit_interstitial_show_failed(_fake.interstitial_shows[-1])
		"fake_idismiss":
			if await _fake_ishow_pending():
				_fake_ishow_done = _fake.interstitial_shows.size()
				_fake.emit_interstitial_dismissed(_fake.interstitial_shows[-1])
		"bitir":
			_main.decline_revive()
			await _settle()
		_:
			print("[qa] bilinmeyen komut: ", line)
	await get_tree().process_frame
	_write_state(line)


## Sahte arka uçta bir geçiş reklamı gösterim isteği bekler (round bitişi
## RESULT_DELAY sonrası ister); yoksa false.
func _fake_ishow_pending() -> bool:
	if _fake == null:
		return false
	for i in 30:
		if _fake.interstitial_shows.size() > _fake_ishow_done:
			return true
		await get_tree().create_timer(0.1).timeout
	_last = "fake_ishow: gösterim isteği YOK"
	return false


## Main'i mevcut arka uç türüyle yeniden kurar (uygulama açılışı: _ready →
## observe_day → giriş ödülü → otomatik pencere).
func _remake_current() -> void:
	if _backend_kind == "fake":
		_fake = FakeAdBackend.new()
		_fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
		_fake_ishow_done = 0
		await _make_main(_fake)
	else:
		var real: AdmobBackend = AdmobBackend.create(AdConfig.load_project())
		_fake = null
		await _make_main(real)


func _idle_probe(seconds: float) -> void:
	var n0: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var m0: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var fps_min: int = 999
	var fps_max: int = 0
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		await get_tree().create_timer(0.5).timeout
		var fps: int = int(Performance.get_monitor(Performance.TIME_FPS))
		fps_min = mini(fps_min, fps)
		fps_max = maxi(fps_max, fps)
	var n1: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var m1: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	_idle = "idle %.0fs: nodes %d->%d orphans %d static_mb %.1f->%.1f fps %d..%d" % [
		seconds, n0, n1, int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), m0, m1, fps_min, fps_max]


func _rect_px(control: Control) -> String:
	if control == null or not control.is_visible_in_tree():
		return "-"
	var xf: Transform2D = get_viewport().get_screen_transform()
	var r: Rect2 = control.get_global_rect()
	var a: Vector2 = xf * r.position
	var b: Vector2 = xf * r.end
	var c: Vector2 = (a + b) * 0.5
	return "px[%d,%d-%d,%d c=%d,%d]" % [int(a.x), int(a.y), int(b.x), int(b.y), int(c.x), int(c.y)]


func _write_state(label: String) -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("label: %s" % label)
	lines.append("time: %s" % Time.get_time_string_from_system())
	lines.append("view: %s canvas: %s scale: %s backend: %s" % [str(DisplayServer.window_get_size()),
		str(get_viewport().get_visible_rect().size), str(get_viewport().get_screen_transform().get_scale()),
		_backend_kind])
	var ads: MonetizationManager = _ads()
	if ads == null:
		lines.append("ads: NONE (manager yok)")
	else:
		var backend: AdBackend = ads.backend()
		lines.append("ads: state=%s allowed=%s sdk_ready=%s consent=%s form_available=%s privacy_required=%s consent_attempts=%d consent_retry=%s" % [
			MonetizationManager.AdsState.keys()[ads.ads_state()], str(ads.ads_allowed()), str(ads.sdk_ready()),
			AdBackend.ConsentStatus.keys()[backend.consent_status()] if backend != null else "-",
			str(backend.is_consent_form_available()) if backend != null else "-",
			str(ads.privacy_options_required()), ads.consent_attempts(), str(ads.has_pending_consent_retry())])
		var req: Dictionary = ads.request_info()
		lines.append("rewarded: state=%s ready=%s note='%s' attempts=%d retry=%s request={active=%s id=%d kind=%s type=%d token=%d day=%s ad_id=%s earned=%s cancelled=%s}" % [
			MonetizationManager.RewardedState.keys()[ads.rewarded_state()], str(ads.is_rewarded_ready()),
			ads.rewarded_note(), ads.rewarded_attempts(), str(ads.has_pending_rewarded_retry()),
			str(req["active"]), req["id"], MonetizationManager.RewardedKind.keys()[req["kind"]], req["type"],
			req["token"], str(req["day_key"]), req["ad_id"], str(req["earned"]), str(req["cancelled"])])
		lines.append("interstitial: state=%s ready=%s ready_id=%s showing_id=%s eligible=%s active=%.1f cooldown=%.1f attempts=%d retry=%s shows=%d break_pending=%s onboarding=%s interval=%.0f cooldown_const=%.0f" % [
			MonetizationManager.InterstitialState.keys()[ads.interstitial_state()], str(ads.is_interstitial_ready()),
			ads.interstitial_ready_id(), ads.interstitial_showing_id(), str(ads.interstitial_eligible()),
			ads.active_elapsed_sec(), ads.fullscreen_cooldown_sec(), ads.interstitial_attempts(),
			str(ads.has_pending_interstitial_retry()), ads.interstitial_shows(), str(ads.break_pending()),
			str(ads.onboarding_completed()), MonetizationManager.INTERSTITIAL_INTERVAL_SEC,
			MonetizationManager.FULLSCREEN_AD_COOLDOWN_SEC])
		lines.append("banner: state=%s ad_id=%s surface=%s slot_px=%d attempts=%d retry=%s uikit_slot=%d" % [
			MonetizationManager.BannerState.keys()[ads.banner_state()], ads.banner_ad_id(),
			MonetizationManager.Surface.keys()[ads.surface()], int(ads.banner_slot_px()), ads.banner_attempts(),
			str(ads.has_pending_banner_retry()), int(UiKit.banner_slot())])
		if _fake != null:
			lines.append("fake: init=%d consent_updates=%d loads=%d shows=%s pending=%s banner_loads=%d banner_shows=%d hides=%d iloads=%d ishows=%s ipending=%s" % [
				_fake.init_calls, _fake.consent_update_calls, _fake.rewarded_loads, str(_fake.rewarded_shows),
				str(_fake.pending_rewarded), _fake.banner_loads, _fake.banner_shows.size(), _fake.banner_hides.size(),
				_fake.interstitial_loads, str(_fake.interstitial_shows), str(_fake.pending_interstitial)])
	var b: Node2D = _board()
	lines.append("board: exists=%s fail_pending=%s revives_used=%d remaining=%d refill_pending=%s finished=%s finished_count=%d tab=%d" % [
		str(b != null), str(b != null and b.is_fail_pending()), b.revives_used() if b != null else -1,
		b.revives_remaining() if b != null else -1, str(b != null and b.is_refill_pending()),
		str(b != null and b.is_finished()), _finished_count, _main._active_tab])
	lines.append("save: dough=%d stock=%s quota_remaining=%d grants_today=%d date=%s refill_token=%d pending_type=%d onboarding=%s" % [
		SaveManager.dough(), str(SaveManager.data.get("powerups", {})), RewardedPolicy.remaining_today(),
		RewardedPolicy.grants_today(), str(SaveManager.data.get("rewarded_power_date", "")),
		_main._refill_pending_token, _main._refill_pending_type, str(SaveManager.onboarding_completed())])
	var ds: Dictionary = DailyRewards.state()
	lines.append("daily: day=%s clock_override='%s' last_seen=%s free_claimed=%s ad_chests=%d dough_ad=%s remaining=%d popup_seen=%s popup_due=%s clock_behind=%s login: date=%s streak=%d claimed_today=%s claimable=%s pending={kind=%s token=%d day=%s}" % [
		ds["day_key"], DailyRewards.clock_override, ds["last_seen_day_key"], str(ds["free_chest_claimed"]),
		ds["ad_chests_claimed"], str(ds["dough_ad_claimed"]), ds["remaining_total"], ds["popup_seen_day"],
		str(DailyRewards.popup_due()), str(ds["clock_behind"]), SaveManager.last_login_date(),
		SaveManager.daily_streak(), str(DailyReward.claimed_today()), str(DailyReward.is_claimable()),
		_main._daily_pending_kind, _main._daily_pending_token, _main._daily_pending_day])
	var dp: CanvasLayer = _main._daily_rewards
	lines.append("dailypopup: visible=%s auto=%s revealing=%s login='%s|%s|%s' note='%s' free='%s' dough='%s' chest='%s' dough_note='%s' chest_note='%s' footnote='%s' free_disabled=%s dough_disabled=%s chest_disabled=%s pending=%s reveal_dough='%s' rects: free=%s dough=%s chest=%s continue=%s close=%s x=%s" % [
		str(dp.visible), str(dp.is_auto_opened()), str(dp.is_revealing()), dp.login_day_text(), dp.login_reward_text(),
		dp.login_chip_text(), dp.login_note_text(), dp.free_status_text(), dp.dough_status_text(), dp.chest_status_text(),
		dp.dough_note_text(), dp.chest_note_text(), dp.note_text(), str(dp.free_button().disabled),
		str(dp.dough_button().disabled), str(dp.chest_button().disabled), dp.pending_kind(), dp.reveal_dough_text(),
		_rect_px(dp.free_button()), _rect_px(dp.dough_button()), _rect_px(dp.chest_button()),
		_rect_px(dp.continue_button()), _rect_px(dp.close_button()), _rect_px(dp.frame().get_meta(&"close_button"))])
	var shop: CanvasLayer = _main._screens[3]
	lines.append("shop: daily_card_visible=%s status='%s' rects: open=%s" % [str(shop.daily_card().visible),
		shop.daily_status_text(), _rect_px(shop.daily_button())])
	var rv: CanvasLayer = _main._revive
	var rf: CanvasLayer = _main._refill
	lines.append("revive: visible=%s text='%s' cta_disabled=%s pending=%s provider_ready=%s note='%s' rects: continue=%s decline=%s" % [
		str(rv.visible), rv.remaining_text(), str(rv.continue_button().disabled), str(rv.is_request_pending()),
		str(rv.provider_ready()), rv.note_text(), _rect_px(rv.continue_button()), _rect_px(rv.decline_button())])
	lines.append("refill: visible=%s type=%d name='%s' stock='%s' quota='%s' ad_disabled=%s ad_note='%s' dough_disabled=%s note='%s' pending=%s rects: ad=%s dough=%s close=%s x=%s" % [
		str(rf.visible), rf.current_type(), rf.power_name_text(), rf.stock_text(), rf._quota.text,
		str(rf._ad.disabled), rf.ad_note_text(), str(rf._dough.disabled), rf.note_text(), str(rf.is_request_pending()),
		_rect_px(rf._ad), _rect_px(rf._dough), _rect_px(rf._close), _rect_px(rf.close_button())])
	var st: CanvasLayer = _main._settings
	lines.append("settings: visible=%s privacy_row=%s rects: privacy_btn=%s close=%s" % [
		str(st.visible), str(st.privacy_options_row() != null and st.privacy_options_row().visible),
		_rect_px(st.privacy_options_button()), _rect_px(st._close)])
	lines.append("result: visible=%s pause: %s" % [str(_main._result.visible), str(_main._pause.visible)])
	var home: CanvasLayer = _main._screens[0]
	lines.append("home: play=%s settings=%s daily_medal=%s daily_dot=%s" % [_rect_px(home._play), _rect_px(home._settings_button),
		_rect_px(home.feature_button(&"daily")), str(home.is_daily_claimable())])
	var mapscr: CanvasLayer = _main._screens[1]
	if mapscr.nodes().size() > 0:
		var n1: Control = mapscr.nodes()[0]
		lines.append("map: world=%s scale=%s crop=%.1f node1=%s plaque1=%s endless=%s" % [str(mapscr.world_rect()),
			str(mapscr.world_scale()), mapscr.crop_top(), _rect_px(n1), _rect_px(n1._plaque), _rect_px(mapscr.endless_node())])
	if b != null:
		var lay: Dictionary = b.layout()
		lines.append("gameplay: compact=%s zoom=%.3f board=%s banner=%s strip=%s seam=%s slot0=%s slot3=%s" % [str(lay.get("compact", false)),
			b._camera_zoom, str(lay["board"]), str(lay["banner"]), _rect_px(b._hud.strip), _rect_px(b._hud.banner_seam),
			_rect_px(b._hud.power_bar.slot(0)), _rect_px(b._hud.power_bar.slot(3))])
	lines.append("last: %s" % _last)
	lines.append("idle: %s" % _idle)
	var tail: int = mini(_event_log.size(), 14)
	lines.append("events(%d, son %d):" % [_event_log.size(), tail])
	for i in range(_event_log.size() - tail, _event_log.size()):
		lines.append("  " + _event_log[i])
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
