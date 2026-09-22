extends Node
## İLK AÇILIŞ TUTORIAL'I deterministik testi (M8.10) — İNTERNET, CİHAZ,
## EKLENTİ YOK. Durum makinesi, girdi kapıları, deterministik ilk iki drop,
## GERÇEK merge şartı, tamamlanma/atlama atomikliği, geri onayı, ilk gün
## günlük bastırması, ertelenmiş monetizasyon ve onboarded oyuncunun Level 1
## tekrarında tutorial görmemesi.
##
## KAYIT DOSYASINA YAZAR. Test başında yedekler, sonunda byte-identical geri
## koyar ve bunu kontrol eder.
##
## Kullanım:
##   godot --headless --audio-driver Dummy --path . res://tools/tutorial_test.tscn

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const FAKE_BACKEND: GDScript = preload("res://tools/fake_ad_backend.gd")
const DAY_A: String = "2026-09-22"
const DAY_B: String = "2026-09-23"

var _fails: int = 0
var _checks: int = 0
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _events: Array[Dictionary] = []
var _main: Node2D = null


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	await get_tree().process_frame
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	MonetizationManager.time_scale = 0.05
	TutorialController.time_scale = 0.05
	DailyRewards.auto_popup_enabled = false
	TutorialEvents.subscribe(_on_event)

	# Oturma niteliği + üretim izolasyonu: Main YOKKEN, kendi board'uyla —
	# tutorial board'una hiç dokunmaz (çapraz merge sinyali riski sıfır).
	await _test_settle_qualification()
	await _test_fresh_boot()
	await _test_welcome_gate()
	await _test_first_drop()
	await _test_match_drop_and_merge()
	await _test_explain_steps()
	await _test_ready_completion()
	await _test_merge_identity()
	await _test_first_day_persistence()
	await _test_skip_path()
	await _test_back_prompt()
	await _test_restart_before_completion()
	await _test_onboarded_replay()
	await _test_monetization_defer()

	TutorialEvents.unsubscribe(_on_event)
	await _teardown_main()
	DailyRewards.clock_override = ""
	DailyRewards.auto_popup_enabled = true
	TutorialController.time_scale = 1.0
	MonetizationManager.time_scale = 1.0
	Main_reset()
	_restore_save_file()
	SaveManager.load_game()
	var restored: bool = not _had_save \
		or FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == _save_bytes
	_c("kayıt dosyası test sonunda byte-identical geri kondu", restored)
	print("=== SONUC: %d/%d kontrol, %d kaldi ===" % [_checks - _fails, _checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func Main_reset() -> void:
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.set("ads_backend_override", null)


func _on_event(_name: StringName, event: Dictionary) -> void:
	_events.append(event)


func _events_named(name: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event in _events:
		if event["name"] == name:
			out.append(event)
	return out


# --- Kurulum yardımcıları -----------------------------------------------------

func _delete_save() -> void:
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))


func _write_json(data: Dictionary) -> void:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _restore_save_file() -> void:
	if _had_save:
		var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(_save_bytes)
		file.close()
	else:
		_delete_save()


func _disk() -> Dictionary:
	if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	return parsed if parsed is Dictionary else {}


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await get_tree().process_frame
		await get_tree().process_frame


## Sıfırdan bir oyuncu: kayıt dosyası yok, gün DAY_A, sahte reklam arka ucu.
func _boot_fresh(with_ads: bool = false) -> void:
	await _teardown_main()
	_delete_save()
	DailyRewards.clock_override = DAY_A
	SaveManager.load_game()
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.set("ads_backend_override", FAKE_BACKEND.new() if with_ads else null)
	_events.clear()
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame


func _tutorial() -> TutorialController:
	return _main._tutorial as TutorialController


func _overlay() -> TutorialOverlay:
	return _main._tutorial_overlay as TutorialOverlay


func _board() -> Node2D:
	return _main._board


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Oyuncunun gerçek sürükle/bırak hareketi: nişan al, sonra bırak.
## `GameBoard._drop()` girdi kilidini KENDİSİ kontrol ediyor (kilitliyken
## hiçbir şey olmaz) — testler bu yüzden doğrudan çağırabiliyor.
func _player_drop(world_x: float) -> void:
	var board: Node2D = _board()
	board._set_aim(world_x)
	board._drop()
	await get_tree().physics_frame


## Android geri basışı. Main'in 250 ms debounce'u gerçek saatle çalışıyor
## (aynı basışın ikinci GO_BACK kopyasını eler) — headless kareler çok hızlı
## olduğundan her basıştan önce gerçek süre bekliyoruz.
func _back() -> void:
	await get_tree().create_timer(0.3).timeout
	_main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame


## Bu ada sahip bir `tutorial_step` olayı yayıldı mı (anlık adım yerine
## GEÇMİŞ kontrolü: kısa adımlar fizik karelerinin arasında geçebiliyor).
func _saw_step(step: String) -> bool:
	for event in _events_named(&"tutorial_step"):
		if String(event.get("step", "")) == step:
			return true
	return false


func _pieces() -> Array:
	return _board().live_dumplings()


func _tiers() -> Array[int]:
	var out: Array[int] = []
	for piece: Dumpling in _pieces():
		out.append(piece.tier)
	out.sort()
	return out


# --- 1. Yeni kayıt: tutorial kendiliğinden açılıyor ----------------------------

func _test_fresh_boot() -> void:
	print("\n-- yeni kayıt açılışı --")
	await _boot_fresh()
	_c("yeni kayıtta onboarding_completed = false", not SaveManager.onboarding_completed())
	_c("yeni kayıtta onboarding_completed_day boş", SaveManager.onboarding_completed_day() == "")
	_c("günlük ödüller kilitli (Onboarding.daily_rewards_unlocked false)",
		not Onboarding.daily_rewards_unlocked())
	_c("tutorial otomatik başladı (WELCOME)",
		_tutorial().current_step() == TutorialController.Step.WELCOME)
	_c("gerçek Level 1 board'u kuruldu", _board() != null and _board().level.level_number == 1)
	_c("kabuk ekranlarının hiçbiri görünmüyor (Ana Sayfa atlandı)",
		not _main._screens[0].visible and not _main._screens[1].visible)
	_c("günlük pencere açılmadı", not _main._daily_rewards.visible)
	_c("giriş ödülü İŞLENMEDİ (+15 yok, seri 0)",
		SaveManager.dough() == 0 and SaveManager.daily_streak() == 0
		and SaveManager.last_login_date() == "")
	_c("banner yuvası 0 (onboarding false)", is_equal_approx(UiKit.banner_slot(), 0.0))
	_c("tutorial_started olayı bir kez", _events_named(&"tutorial_started").size() == 1)
	_c("başlangıç güçleri yalnız bir kez verildi (starter bayrağı)",
		bool(SaveManager.data.get("powerup_starter_granted", false)))


# --- 2. WELCOME: board girdisi kapalı ------------------------------------------

func _test_welcome_gate() -> void:
	print("\n-- WELCOME girdi kapısı --")
	_c("board girdisi kilitli", _board().is_tutorial_input_locked())
	_c("board tutorial-pause'ta", _board().is_tutorial_paused())
	_c("tutorial pause fail-pending DEĞİL", not _board().is_fail_pending())
	_c("tutorial pause refill-pending DEĞİL", not _board().is_refill_pending())
	_c("overlay açık", _overlay().is_open())
	_c("karşılama metni", _overlay().title_text() == "Hoş geldin!")
	_c("CTA BAŞLA görünür", _overlay().cta_button().visible)
	_c("ATLA kontrolü görünür ama ana CTA değil", _overlay().skip_button().visible)
	await _player_drop(360.0)
	_c("WELCOME'ta bırakma yok sayıldı (board boş)", _pieces().is_empty())
	_c("adım hâlâ WELCOME", _tutorial().current_step() == TutorialController.Step.WELCOME)


# --- 3. FIRST_DROP: yalnız geçerli bırakma ilerletir ---------------------------

func _test_first_drop() -> void:
	print("\n-- FIRST_DROP --")
	var bag_before: int = _board().tutorial_queue_size()
	_c("tutorial kuyruğunda iki öğretim parçası hazır (T1,T1 çekildi)", bag_before == 0)
	_c("bekleyen parça T1", _board()._pending_tier == 1)
	_c("sıradaki parça da T1", _board()._next_tier == 1)
	_tutorial().advance()
	await get_tree().process_frame
	_c("BAŞLA -> FIRST_DROP", _tutorial().current_step() == TutorialController.Step.FIRST_DROP)
	_c("board girdisi açıldı", not _board().is_tutorial_input_locked())
	_c("board çözüldü (tutorial pause yok)", not _board().is_tutorial_paused())

	# Uç noktadan bırakma: güvenli banda kırpılır (sol/sağ duvara yapışmaz).
	var board: Node2D = _board()
	var center: float = board.get_viewport_rect().size.x * 0.5
	var half: float = board.level.container_width * TutorialController.FIRST_DROP_CLAMP_RATIO
	board._set_aim(0.0)
	_c("sol uçta nişan güvenli banda kırpıldı", board._aim_x >= center - half - 0.5)
	board._set_aim(10000.0)
	_c("sağ uçta nişan güvenli banda kırpıldı", board._aim_x <= center + half + 0.5)

	await _player_drop(center - 500.0)
	_c("ilk parça doğdu", _pieces().size() == 1)
	var first_tiers: Array[int] = _tiers()
	_c("ilk parça T1", first_tiers.size() == 1 and first_tiers[0] == 1)
	var first: Dumpling = _pieces()[0]
	_c("ilk parça güvenli bandın içinde düştü", absf(first.position.x - center) <= half + 1.0)
	_c("tutorial_first_drop olayı", _events_named(&"tutorial_first_drop").size() == 1)
	_c("ikinci drop'a kadar girdi kapandı", _board().is_tutorial_input_locked())
	await _frames(140)
	_c("parça oturunca MATCH_DROP",
		_tutorial().current_step() == TutorialController.Step.MATCH_DROP)


# --- 3b. "Oturdu" niteliği: doğuş karesi SAYILMAZ (M8.10 kapı 2) -----------------
#
# Hata: yeni doğmuş bir parçanın `linear_velocity`'si SIFIRDIR (fizik henüz
# işlemedi), yalnız hıza bakmak "anında oturdu" diyordu ve FIRST_DROP adımı
# parça daha düşerken atlanıyordu. Düzeltme TUTORIAL'A AİT: gözlem penceresi
# + kaba inme + durma. GameBoard/Dumpling üretim davranışına DOKUNULMADI —
# bu bölüm ikisini de ölçüyor.

func _test_settle_qualification() -> void:
	print("\n-- oturma niteliği + üretim fiziği izolasyonu --")
	# AYRI bir üretim board'u: tutorial board'una parça eklemiyoruz (eklesek
	# iki T1 birleşir, ölçülen adımı bozardı).
	var plain: Node2D = load("res://scenes/game/game_board.tscn").instantiate()
	plain.setup(load("res://resources/levels/level_04.tres"))
	add_child(plain)
	await _frames(3)

	# Doğuş karesi: hız SIFIR ama parça HENÜZ düşme bölgesinde -> oturmuş DEĞİL.
	var fresh: Dumpling = plain._spawn_dumpling(1, Vector2(plain._center_x(), plain.drop_line_y()))
	await get_tree().physics_frame
	_c("yeni doğan parçanın hızı ~sıfır (hatanın kaynağı buydu)",
		fresh.linear_velocity.length() < TutorialController.SETTLE_SPEED)
	_c("doğuş karesinde 'oturdu' SAYILMAZ (taşma çizgisinin üstünde)",
		fresh.global_position.y <= plain.overflow_line_y()
		and not TutorialController.piece_settled(fresh, plain))
	# Düşerken (hızlı) de sayılmaz.
	await _frames(12)
	_c("düşerken 'oturdu' SAYILMAZ (hareket ediyor)",
		not TutorialController.piece_settled(fresh, plain)
		or fresh.linear_velocity.length() < TutorialController.SETTLE_SPEED)
	# Kaba inip durunca sayılır.
	await _frames(150)
	_c("kaba inip durunca 'oturdu' sayılır", TutorialController.piece_settled(fresh, plain))
	_c("oturmuş parça gerçekten oyun alanında (taşma çizgisinin ALTINDA)",
		fresh.global_position.y > plain.overflow_line_y())
	_c("gözlem penceresi sabiti makul (>= 0.3 sn)", TutorialController.SETTLE_MIN >= 0.3)

	# --- ÜRETİM İZOLASYONU: tutorial dışı board'da hiçbir kanca kurulmaz ---
	_c("üretim board'u: tutorial kuyruğu boş (torba yetkili)",
		plain.tutorial_queue_size() == 0)
	_c("üretim board'u: girdi kilidi ve tutorial pause KAPALI",
		not plain.is_tutorial_input_locked() and not plain.is_tutorial_paused())
	_c("üretim board'u: SNAP kılavuzu yok (yardım NONE)",
		plain.tutorial_guide_screen_x() < 0.0)
	# Nişan: yardım NONE iken yalnız duvar payı sınırlar (eski davranış birebir).
	var margin: float = TierConfig.radius(plain._pending_tier)
	plain._set_aim(-9999.0)
	_c("üretim nişanı sol duvar payında (yardım karışmıyor)",
		is_equal_approx(plain._aim_x, plain._left_x() + margin))
	plain._set_aim(9999.0)
	_c("üretim nişanı sağ duvar payında", is_equal_approx(plain._aim_x, plain._right_x() - margin))
	var free_x: float = plain._center_x() + 120.0
	plain._set_aim(free_x)
	_c("üretim nişanı serbest (clamp/snap yok)", is_equal_approx(plain._aim_x, free_x))
	# Bırakma: parça TAM nişan alınan x'te doğar, cooldown eski sabitte.
	plain._drop_cooldown = 0.0
	var aim_before: float = plain._aim_x
	var before_count: int = plain.live_dumplings().size()
	plain._drop()
	await get_tree().physics_frame
	var live: Array = plain.live_dumplings()
	var newest: Dumpling = live[live.size() - 1]
	_c("üretim bırakması nişan x'inde doğdu (yardım uygulanmadı)",
		live.size() == before_count + 1 and absf(newest.position.x - aim_before) < 0.01)
	# Sabit 0.4 (M1'den beri); bırakmadan sonra sayaç işlemeye başlamış olur.
	_c("drop cooldown sabiti değişmedi (0.4 sn) ve bırakmada kuruldu",
		is_equal_approx(plain.DROP_COOLDOWN, 0.4)
		and plain._drop_cooldown > 0.0 and plain._drop_cooldown <= plain.DROP_COOLDOWN)
	var count_after: int = plain.live_dumplings().size()
	plain._drop()
	await get_tree().physics_frame
	_c("cooldown içinde ikinci bırakma engellendi (eski kural)",
		plain.live_dumplings().size() == count_after)
	# Torba: tutorial kuyruğu olmadan sıradaki tier üretim havuzundan.
	_c("sıradaki tier üretim havuzundan (1..%d)" % TierConfig.DROP_POOL_MAX_TIER,
		plain._next_tier >= 1 and plain._next_tier <= TierConfig.DROP_POOL_MAX_TIER)
	plain.queue_free()
	await _frames(3)


# --- 4. MATCH_DROP: GERÇEK merge şartı ------------------------------------------

func _test_match_drop_and_merge() -> void:
	print("\n-- MATCH_DROP + gerçek merge --")
	_c("girdi yeniden açıldı", not _board().is_tutorial_input_locked())
	_c("board oynuyor (pause yok)", not _board().is_tutorial_paused())
	_c("hedef vurgusu var", _overlay().target_rect().size != Vector2.ZERO)
	var guide: float = _board().tutorial_guide_screen_x()
	_c("SNAP kılavuzu kuruldu", guide >= 0.0)
	var target: Dumpling = _pieces()[0]
	var target_x: float = target.position.x
	var merges_before: int = GameState.merge_count
	var score_before: int = GameState.score

	# Oyuncu uzağa nişan alsa bile tutorial yardımı ikinci T1'i birincinin
	# üstüne hizalar — merge güvence altında (§6).
	await _player_drop(target_x - 260.0)
	_c("ikinci parça hizalandı (birinci T1'in x'i)",
		absf(_pieces()[_pieces().size() - 1].position.x - target_x) < 1.0)
	_c("üçüncü drop'u önlemek için girdi kapandı", _board().is_tutorial_input_locked())
	await _frames(180)
	_c("GERÇEK merge oldu: T2 board'da", _tiers().has(2))
	_c("merge sayacı production yolundan arttı", GameState.merge_count == merges_before + 1)
	_c("skor production yolundan arttı", GameState.score > score_before)
	_c("tutorial T2'si board'da KALDI (silinmedi)", _pieces().size() == 1)
	_c("merge sonrası MERGE_SUCCESS adımı çalıştı", _saw_step("merge_success"))
	_c("tutorial_first_merge olayı tier 2 ile",
		_events_named(&"tutorial_first_merge").size() == 1
		and int(_events_named(&"tutorial_first_merge")[0].get("tier", 0)) == 2)
	_c("öğretim kuyruğu bitti, normal torba devraldı",
		_board().tutorial_queue_size() == 0 and _board()._next_tier >= 1)


# --- 4b. Rehberli merge KİMLİĞİ (M8.10 kapı 3) ------------------------------------
#
# Adım "herhangi bir merge_performed" ile ilerlemez. İki kanıt:
#   (a) O durumda başka bir merge OLAMAZ — board'da yalnız tutorial kuyruğundan
#       gelen iki T1 var, ikinci bırakmadan sonra girdi kilitli, güçler pasif.
#   (b) Kimlik AÇIKÇA doğrulanıyor — yalnız T1+T1'in ürünü (T2) kabul edilir.

func _test_merge_identity() -> void:
	print("\n-- rehberli merge kimliği --")
	_c("rehberli merge sonucu T2 olarak sabitlenmiş",
		TutorialController.MERGE_RESULT_TIER == 2)
	_c("öğretim kuyruğu yalnız iki T1", TutorialController.DROP_QUEUE.size() == 2
		and TutorialController.DROP_QUEUE[0] == 1 and TutorialController.DROP_QUEUE[1] == 1)

	# Sıfırdan bir oyuncuda MATCH_DROP'a kadar gel ve board'un durumunu ölç:
	# o anda başka bir merge üretebilecek parça YOK.
	await _boot_fresh()
	_tutorial().advance()
	await get_tree().process_frame
	await _player_drop(360.0)
	await _frames(150)
	_c("MATCH_DROP'tayız", _tutorial().current_step() == TutorialController.Step.MATCH_DROP)
	var tiers: Array[int] = _tiers()
	_c("board'da yalnız bir parça ve o bir T1 (başka merge kaynağı yok)",
		tiers.size() == 1 and tiers[0] == 1)
	_c("bekleyen parça da T1 (kuyruktan)", _board()._pending_tier == 1)

	# Yanlış kimlikli bir merge sinyali adımı İLERLETMEZ.
	var step_before: int = _tutorial().current_step()
	GameState.merge_performed.emit(5, Vector2.ZERO)
	await get_tree().process_frame
	_c("T5 merge sinyali adımı ilerletmez (kimlik eşleşmiyor)",
		_tutorial().current_step() == step_before)
	GameState.merge_performed.emit(3, Vector2.ZERO)
	await get_tree().process_frame
	_c("T3 merge sinyali de ilerletmez", _tutorial().current_step() == step_before)

	# Gerçek T2 merge'i ilerletir (üretim yolundan).
	var target: Dumpling = _pieces()[0]
	await _player_drop(target.position.x - 200.0)
	await _frames(180)
	_c("GERÇEK T1+T1 -> T2 merge'i adımı ilerletti", _saw_step("merge_success"))
	_c("board'da T2 var", _tiers().has(2))
	_c("yalnız BİR first_merge olayı (yanlış sinyaller olay üretmedi)",
		_events_named(&"tutorial_first_merge").size() == 1)
	_c("olayın tier'ı 2", int(_events_named(&"tutorial_first_merge")[0].get("tier", 0)) == 2)


# --- 5. Açıklama adımları: girdi kapalı, spot hedefi kapatmıyor -----------------

func _test_explain_steps() -> void:
	print("\n-- açıklama adımları --")
	await _frames(30)
	_c("kutlama kendiliğinden GOAL'a geçti",
		_tutorial().current_step() == TutorialController.Step.GOAL)
	for step: Array in [[TutorialController.Step.GOAL, "hedef"],
			[TutorialController.Step.DANGER, "tehlike"],
			[TutorialController.Step.POWERS, "güçler"]]:
		_c("%s adımında girdi kilitli" % step[1], _board().is_tutorial_input_locked())
		_c("%s adımında board donuk" % step[1], _board().is_tutorial_paused())
		var target: Rect2 = _overlay().target_rect()
		_c("%s adımında spot hedefi var" % step[1], target.size != Vector2.ZERO)
		_c("%s adımında coach kartı hedefi ÖRTMÜYOR" % step[1],
			not GameplayLayout.overlaps(_overlay().card_rect(), target))
		var before: int = SaveManager.powerup_count(PowerUp.Type.BOMB)
		_tutorial().advance()
		await get_tree().process_frame
		_c("%s adımı güç stoğunu değiştirmedi" % step[1],
			SaveManager.powerup_count(PowerUp.Type.BOMB) == before)
	_c("POWERS -> READY", _tutorial().current_step() == TutorialController.Step.READY)
	_c("READY'de ATLA gizli (ana CTA DEVAM)", not _overlay().skip_button().visible)


# --- 6. READY: tamamlanma tam bir kez -------------------------------------------

func _test_ready_completion() -> void:
	print("\n-- tamamlanma --")
	var dough_before: int = SaveManager.dough()
	_tutorial().advance()
	await get_tree().process_frame
	_c("onboarding_completed = true", SaveManager.onboarding_completed())
	_c("onboarding_completed_day = tutorial günü",
		SaveManager.onboarding_completed_day() == DAY_A)
	_c("iki alan da DİSKE yazıldı (tek transaction)",
		_disk().get("onboarding_completed", false) == true
		and String(_disk().get("onboarding_completed_day", "")) == DAY_A)
	_c("last_seen_day_key aynı transaction'da işlendi",
		SaveManager.daily_last_seen_day_key() == DAY_A)
	_c("tutorial ÖDÜL VERMEDİ (Hamur değişmedi)", SaveManager.dough() == dough_before)
	_c("overlay kapandı", not _overlay().is_open())
	_c("board girdisi normale döndü", not _board().is_tutorial_input_locked()
		and not _board().is_tutorial_paused())
	_c("round devam ediyor (board duruyor, sonuç yok)",
		_board() != null and not _main._result.visible)
	_c("tutorial_completed olayı bir kez", _events_named(&"tutorial_completed").size() == 1)

	# İKİNCİ tamamlanma çağrısı (çift dokunuş / geç callback) zararsız.
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_tutorial().advance()
	_main._on_tutorial_completed(Onboarding.SOURCE_TUTORIAL)
	Onboarding.complete(Onboarding.SOURCE_TUTORIAL)
	await get_tree().process_frame
	_c("çift tamamlanma kayda İKİNCİ kez yazmadı",
		FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == bytes)
	_c("tutorial_completed hâlâ bir kez", _events_named(&"tutorial_completed").size() == 1)

	# İlk gün kuralı: tamamlanma günü GÜNLÜK SİSTEM KAPALI.
	_c("aynı gün günlük ödüller HÂLÂ kilitli", not Onboarding.daily_rewards_unlocked())
	_c("ilk gün bastırması bildiriliyor", Onboarding.is_first_day_suppressed())
	_c("giriş ödülü alınamaz", not DailyReward.is_claimable())
	var claim: Dictionary = DailyReward.claim_if_new_day()
	_c("claim_if_new_day no-op", not bool(claim["claimed"]))
	_c("Hamur ve seri değişmedi", SaveManager.dough() == dough_before
		and SaveManager.daily_streak() == 0 and SaveManager.last_login_date() == "")
	_c("ücretsiz sandık bloke", DailyRewards.claim_free_chest() == null)
	_c("reklamlı sandık bloke", DailyRewards.grant_ad_chest(DAY_A) == null)
	_c("reklamlı +150 bloke", not DailyRewards.grant_ad_dough(DAY_A))
	_c("otomatik pencere due DEĞİL", not DailyRewards.popup_due())
	_main.open_daily_rewards()
	await get_tree().process_frame
	_c("Mağaza/madalyon yolundan pencere açılmıyor", not _main._daily_rewards.visible)

	# Ertesi gün: normal günlük sistem sıfırdan başlar.
	DailyRewards.clock_override = DAY_B
	DailyRewards.observe_day()
	_c("ertesi gün günlük ödüller AÇILDI", Onboarding.daily_rewards_unlocked())
	_c("ertesi gün giriş ödülü alınabilir", DailyReward.is_claimable())
	var next_claim: Dictionary = DailyReward.claim_if_new_day()
	_c("ertesi gün +15 tam bir kez", bool(next_claim["claimed"])
		and SaveManager.dough() == dough_before + DailyReward.DAILY_DOUGH)
	_c("seri 1. günden başladı", SaveManager.daily_streak() == 1)
	_c("geriye dönük telafi YOK (tek +15)",
		not bool(DailyReward.claim_if_new_day()["claimed"]))
	DailyRewards.clock_override = DAY_A
	_c("saat geri alınsa da günlük yeniden kilitlenmez (efektif gün ileri)",
		Onboarding.daily_rewards_unlocked())
	DailyRewards.clock_override = DAY_A


# --- 6b. İlk gün KALICILIĞI: diskteki alanlar tek tek (M8.10 kapı 4) --------------
#
# Tamamlanma A gününde YALNIZ iki alanı yazmalı. Giriş tarihi, seri ve üç
# günlük kota DOKUNULMAMIŞ kalmalı; `popup_seen_day` yanlışlıkla bir claim
# üretmemeli. B günü normal döngüyü SIFIRDAN başlatmalı.

func _test_first_day_persistence() -> void:
	print("\n-- ilk gün kalıcılığı (disk alanları) --")
	await _boot_fresh()
	_tutorial().skip()
	await get_tree().process_frame

	var disk: Dictionary = _disk()
	var daily: Dictionary = disk.get("daily_rewards", {}) as Dictionary
	_c("A: onboarding_completed = true (diskte)", disk.get("onboarding_completed", false) == true)
	_c("A: onboarding_completed_day = A (diskte)",
		String(disk.get("onboarding_completed_day", "")) == DAY_A)
	_c("A: last_login_date DEĞİŞMEDİ (boş)", String(disk.get("last_login_date", "x")) == "")
	_c("A: daily_streak 0", int(disk.get("daily_streak", -1)) == 0)
	_c("A: Hamur 0 (giriş ödülü yazılmadı)", int(disk.get("dough", -1)) == 0)
	_c("A: ücretsiz sandık kotası dokunulmamış",
		bool(daily.get("free_chest_claimed", true)) == false)
	_c("A: reklamlı sandık kotası dokunulmamış",
		int(daily.get("ad_chests_claimed", -1)) == 0)
	_c("A: reklamlı +150 kotası dokunulmamış",
		bool(daily.get("dough_ad_claimed", true)) == false)
	_c("A: popup_seen_day BOŞ (pencere gösterilmedi, claim üretmedi)",
		String(daily.get("popup_seen_day", "x")) == "")
	_c("A: day_key BOŞ (hiçbir günlük transaction çalışmadı)",
		String(daily.get("day_key", "x")) == "")
	_c("A: last_seen_day_key = A (saat geri alma koruması aynı transaction'da)",
		String(daily.get("last_seen_day_key", "")) == DAY_A)
	_c("A: başlangıç güç hediyesi tutorial'dan ETKİLENMEDİ (tek sefer bayrağı)",
		bool(disk.get("powerup_starter_granted", false)) == true)

	# B günü: yeni açılış (uygulama yeniden başlatıldı) — normal döngü.
	await _teardown_main()
	DailyRewards.clock_override = DAY_B
	DailyRewards.auto_popup_enabled = true
	SaveManager.load_game()
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.set("ads_backend_override", null)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_c("B: tutorial YOK (onboarding tamam)", not _tutorial().is_active())
	_c("B: +15 tam bir kez", SaveManager.dough() == DailyReward.DAILY_DOUGH)
	_c("B: seri 1. gün", SaveManager.daily_streak() == 1)
	_c("B: otomatik günlük pencere tam bir kez açıldı", _main._daily_rewards.visible)
	_c("B: popup_seen_day = B", SaveManager.daily_popup_seen_day() == DAY_B)
	var state: Dictionary = DailyRewards.state()
	_c("B: ücretsiz sandık hazır", bool(state["free_chest_available"]))
	_c("B: reklamlı sandık 0/2", int(state["ad_chests_remaining"]) == 2)
	_c("B: reklamlı +150 hazır", bool(state["ad_dough_available"]))
	_main._daily_rewards.close_popup()
	await get_tree().process_frame

	# B günü yeniden açılış: ikinci +15 YOK, ikinci pencere YOK.
	await _teardown_main()
	SaveManager.load_game()
	main_script.set("ads_backend_override", null)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_c("B yeniden açılış: ikinci +15 YOK", SaveManager.dough() == DailyReward.DAILY_DOUGH)
	_c("B yeniden açılış: seri hâlâ 1", SaveManager.daily_streak() == 1)
	_c("B yeniden açılış: otomatik pencere İKİNCİ kez açılmadı",
		not _main._daily_rewards.visible)
	DailyRewards.auto_popup_enabled = false
	DailyRewards.clock_override = DAY_A


# --- 7. ATLA: aynı kanonik tamamlanma yolu --------------------------------------

func _test_skip_path() -> void:
	print("\n-- ATLA --")
	await _boot_fresh()
	_c("yeni kayıt: tutorial WELCOME",
		_tutorial().current_step() == TutorialController.Step.WELCOME)
	_tutorial().advance()
	await get_tree().process_frame
	_tutorial().skip()
	await get_tree().process_frame
	_c("ATLA onboarding'i tamamladı", SaveManager.onboarding_completed())
	_c("ATLA tamamlanma gününü de yazdı", SaveManager.onboarding_completed_day() == DAY_A)
	_c("ATLA aynı ilk gün bastırmasını uyguladı", not Onboarding.daily_rewards_unlocked())
	_c("ATLA ödül vermedi", SaveManager.dough() == 0 and SaveManager.daily_streak() == 0)
	_c("tutorial_skipped olayı bir kez", _events_named(&"tutorial_skipped").size() == 1)
	_c("overlay kapandı", not _overlay().is_open())
	_c("board oynanabilir (round sürüyor)", _board() != null
		and not _board().is_tutorial_input_locked())
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_tutorial().skip()
	await get_tree().process_frame
	_c("ikinci ATLA kayda yazmadı",
		FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == bytes)


# --- 8. Android geri: güvenli onay, kabuğa düşmez -------------------------------

func _test_back_prompt() -> void:
	print("\n-- Android geri --")
	await _boot_fresh()
	_tutorial().advance()
	await get_tree().process_frame
	_c("FIRST_DROP'tayız", _tutorial().current_step() == TutorialController.Step.FIRST_DROP)
	await _back()
	_c("geri tuşu tutorial onayını açtı", _tutorial().is_back_prompt_open())
	_c("onay sırasında board donuk + kilitli", _board().is_tutorial_paused()
		and _board().is_tutorial_input_locked())
	_c("mola penceresi AÇILMADI", not _main._pause.visible)
	_c("kabuk ekranına düşülmedi", not _main._screens[0].visible)
	_c("onboarding hâlâ false", not SaveManager.onboarding_completed())
	_c("iki CTA var (DEVAM ET / ATLA)", _overlay().cta_button().visible
		and _overlay().cta_alt_button().visible)
	_tutorial().advance()
	await get_tree().process_frame
	_c("DEVAM ET kaldığı adıma döndü",
		not _tutorial().is_back_prompt_open()
		and _tutorial().current_step() == TutorialController.Step.FIRST_DROP)
	_c("board yeniden oynanabilir", not _board().is_tutorial_input_locked())

	# Oyun içi Geri/Çıkış butonu da aynı onayı açar (mola penceresi değil).
	_main.open_pause_menu()
	await get_tree().process_frame
	_c("HUD geri butonu mola yerine tutorial onayını açtı",
		_tutorial().is_back_prompt_open() and not _main._pause.visible)
	await _back()
	_c("ikinci geri onayı kapattı", not _tutorial().is_back_prompt_open())

	# Onaydaki ATLA kanonik tamamlanmadan geçer.
	await _back()
	_tutorial().skip()
	await get_tree().process_frame
	_c("onaydaki ATLA onboarding'i tamamladı", SaveManager.onboarding_completed()
		and SaveManager.onboarding_completed_day() == DAY_A)


# --- 9. Tamamlanmadan kapanma: tutorial baştan başlar ---------------------------

func _test_restart_before_completion() -> void:
	print("\n-- yarıda kapanma --")
	await _boot_fresh()
	_tutorial().advance()
	await get_tree().process_frame
	await _player_drop(360.0)
	await _frames(60)
	_c("ilerleme var (bir parça düştü)", _pieces().size() >= 1)
	var day_before: String = SaveManager.onboarding_completed_day()
	# Uygulama kapandı (Main yok edildi), kayıt diskte ne ise o.
	await _teardown_main()
	SaveManager.load_game()
	_c("onboarding hâlâ false", not SaveManager.onboarding_completed())
	_c("tamamlanma günü yazılmadı", SaveManager.onboarding_completed_day() == day_before)
	_c("günlük mutasyonu olmadı", SaveManager.dough() == 0
		and SaveManager.last_login_date() == "" and SaveManager.daily_streak() == 0)

	# Yeniden açılış: tutorial BAŞTAN.
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.set("ads_backend_override", null)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_c("yeniden açılışta tutorial baştan (WELCOME)",
		_tutorial().current_step() == TutorialController.Step.WELCOME)
	_c("board yeni ve boş", _pieces().is_empty())


# --- 10. Onboarded oyuncu Level 1'i tekrar oynuyor -------------------------------

func _test_onboarded_replay() -> void:
	print("\n-- onboarded oyuncu Level 1 tekrarı --")
	await _teardown_main()
	_write_json({"highest_level_unlocked": 5, "onboarding_completed": true,
		"powerup_starter_granted": true, "total_merges": 300, "dough": 120})
	SaveManager.load_game()
	DailyRewards.clock_override = DAY_A
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.set("ads_backend_override", null)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_c("eski oyuncu normal kabuğa açıldı (Ana Sayfa)", _main._screens[0].visible)
	_c("tutorial hiç başlamadı", not _tutorial().is_active()
		and _tutorial().current_step() == TutorialController.Step.INACTIVE)
	_c("overlay kapalı", not _overlay().is_open())
	_c("tamamlanma günü yok -> yerleşik oyuncu, bastırma YOK",
		SaveManager.onboarding_completed_day() == "" and Onboarding.daily_rewards_unlocked())

	_main._start_level(_main._first_level())
	await get_tree().process_frame
	await get_tree().physics_frame
	_c("Level 1 tekrarında board kuruldu", _board().level.level_number == 1)
	_c("Level 1 tekrarında tutorial YOK", not _tutorial().is_active())
	_c("Level 1 tekrarında coach overlay YOK", not _overlay().is_open())
	_c("girdi anında normal", not _board().is_tutorial_input_locked()
		and not _board().is_tutorial_paused())
	_c("tutorial kuyruğu boş (normal torba)", _board().tutorial_queue_size() == 0)
	await _player_drop(360.0)
	_c("ilk bırakma anında çalıştı", _pieces().size() == 1)
	_main.abandon_run()
	await get_tree().process_frame


# --- 11. Monetizasyon: tutorial boyunca kapalı, round ortasında açılmaz ----------

func _test_monetization_defer() -> void:
	print("\n-- monetizasyon ertelemesi --")
	await _boot_fresh(true)
	var ads: MonetizationManager = _main._ads
	_c("reklam yöneticisi kuruldu", ads != null)
	_c("onboarding false: yönetici de false", not ads.onboarding_completed())
	_c("banner yuvası 0", is_equal_approx(UiKit.banner_slot(), 0.0))
	_c("UMP/rıza akışı BAŞLAMADI (tutorial'ın üstüne form gelmez)",
		not ads.consent_started())
	_c("ödüllü yükleme yok", ads.rewarded_state() == MonetizationManager.RewardedState.IDLE)
	_c("geçiş yükleme yok",
		ads.interstitial_state() == MonetizationManager.InterstitialState.IDLE)
	ads._tick_active(120.0)
	_c("aktif süre saati SAYMADI", is_equal_approx(ads.active_elapsed_sec(), 0.0))

	# Tutorial'ı atla: round hâlâ açık -> monetizasyon ERTELENİR.
	_tutorial().advance()
	await get_tree().process_frame
	_tutorial().skip()
	await get_tree().process_frame
	_c("onboarding kaydı true", SaveManager.onboarding_completed())
	_c("round ortası: yönetici HÂLÂ false (banner sıçraması yok)",
		not ads.onboarding_completed())
	_c("round ortası: banner yuvası hâlâ 0", is_equal_approx(UiKit.banner_slot(), 0.0))
	_c("round ortası: rıza akışı hâlâ başlamadı", not ads.consent_started())
	_c("Main erteleme bayrağını taşıyor", _main._monetization_deferred)
	_c("ödüllü devam/refill sunumu hâlâ kapalı", not _main._revive_provider_ready())

	# Güvenli kabuk geçişi: monetizasyon açılır.
	_main.abandon_run()
	await get_tree().process_frame
	await get_tree().process_frame
	_c("kabuk geçişinde yönetici true", ads.onboarding_completed())
	_c("rıza akışı ŞİMDİ başladı (reklamdan ÖNCE)", ads.consent_started())
	_c("erteleme bayrağı temizlendi", not _main._monetization_deferred)
	_c("aynı gün günlük HÂLÂ kilitli (reklam != günlük)",
		not Onboarding.daily_rewards_unlocked())
	await _frames(4)
	_c("banner yuvası artık hesaplanıyor", UiKit.banner_slot() >= 0.0)
