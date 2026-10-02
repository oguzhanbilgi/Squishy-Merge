extends Node
## TASK/047 — Günlük meydan okuma Main akışı + P1 yalıtım testi (gerçek Main, gerçek board). Headless.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_daily_challenge_flow/` altındaki
## bir yola yönlendirilir, sonda geri alınır; gerçek kayıt ailesi başta / sonda karşılaştırılır.
##
##   godot --headless --audio-driver Dummy --path . res://tools/daily_challenge_flow_test.tscn
##
## Bölümler:
##   yönlendirme  açık round türü (DAILY_CHALLENGE), kod içi level (nöbetçi 0) ama yönlendirme türden;
##                board'un round_finished'ı YALNIZ meydan okuma işleyicisine bağlı; dizi baştan, tam
##                bütçe; reddedilen başlatmalar (bugün tamam / gün gerçeği yok / onboarding bitmedi)
##   yalıtım      kazanma: tüm kayıt aynen, YALNIZ +20 Hamur + completed_day_key (bellek + disk);
##                kayıp (taşma / hamle bitti), terk, yeniden başlatma: kayıt baytı aynı, yazma YOK
##   akış         TEKRAR DENE → aynı gün baştan; mola Yeniden Başlat → meydan okuma (normal
##                `_start_level` DEĞİL); ANA SAYFA / Ana Menüye Dön → Ana Sayfa; normal round aynen
##   gece yarısı  deneme D'de başlar, D+1'de kazanır → D ödüllenir, D+1 ayrı; D+1'e geçen kayıp →
##                "YENİ MEYDAN OKUMA" → D+1; geri alınan saat tamamlanmış günü yeniden açmaz; gün
##                sonuç gecikmesinde değişirse gösterimde okunur; açık kayıp sonucu gece yarısını
##                geçerse TEKRAR DENE / öne dönüş önce "Gün değişti" kopyasına yeniler
##   eski sonuç   gecikmeli meydan okuma sonucu yeni denemenin / Ana Sayfa'nın / normal round'un
##                üstüne AÇILMAZ; gecikmedeki normal sonuç da meydan okumanın üstüne açılmaz
##   reklam       sahte arka uç: meydan okuma bitişinde geçiş reklamı denemesi / ödüllü istek YOK
##                (normal round aynı koşulda gösterir — kontrol); yaş UNKNOWN: SDK yok, oynanır
##   tutorial     onboarding bitmeden başlatma yok, onboarding alanları değişmez
##   kaynak       meydan okuma işleyicisi ilerleme / reklam yollarını çağırmaz; normal işleyici
##                meydan okumayı bilmez

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DUMPLING_VISUAL: GDScript = preload("res://scripts/game/dumpling_visual.gd")
const DIR: String = "user://qa_daily_challenge_flow"
const PATH: String = DIR + "/save.json"
const SECTIONS: int = 9
const MON: String = "2026-09-28"
const WED: String = "2026-09-30"
const THU: String = "2026-10-01"
const FRI: String = "2026-10-02"
const SAT: String = "2026-10-03"
const GOLDEN: Array[int] = [1, 3, 1, 1, 3, 2, 2, 3, 2, 1, 3, 3, 1, 2, 1, 2, 3, 2]

var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _finished: bool = false
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _main: Node2D
var _main_script: GDScript


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_main_script = load("res://scripts/main.gd")
	_owner_state = _owner_snapshot()
	_saved_data = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	SaveManager.save_path = PATH
	get_tree().create_timer(420.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 420 s'de bitmedi — SaveManager geri alındı")
			if _main != null and is_instance_valid(_main):
				_main.free()
			_teardown()
			get_tree().quit(2))
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame

	await _routing()
	await _isolation_win()
	await _isolation_fail()
	await _flow_paths()
	await _midnight()
	await _stale_results()
	await _ads()
	await _tutorial()
	_source_contract()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	print("-- kayıt")
	await _teardown_main()
	_teardown()
	_c("SaveManager gerçek yola döndü, test klasörü silindi, saat kancası / hata enjeksiyonu boş",
		SaveManager.save_path == SaveManager.SAVE_PATH and not DirAccess.dir_exists_absolute(DIR)
		and DailyRewards.clock_override == "" and SaveFile.fault == SaveFile.Fault.NONE)
	_c("sahibin gerçek kayıt ailesi (kanonik + .tmp + .bak) bayt-aynı", _owner_snapshot() == _owner_state)
	_finished = true
	print("\nSONUC: %d kontrol, %d hata" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _exit_tree() -> void:
	if _finished:
		return
	print("  [FAIL] test SONUC'tan önce ağaçtan çıktı — SaveManager geri alındı")
	_teardown()


func _teardown() -> void:
	SaveFile.fault = SaveFile.Fault.NONE
	DailyRewards.clock_override = ""
	DailyRewards.auto_popup_enabled = false
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	UiKit.set_banner_slot(0.0)
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- 1) Yönlendirme -----------------------------------------------------------------------------

func _routing() -> void:
	print("-- açık round türü + başlatma yolu")
	await _fresh(THU)
	_c("ön koşul: Ana Sayfa'da, board yok, round türü NORMAL", _main._board == null and _main._active_tab == 0
		and not _main.is_daily_challenge_round())
	var settle_before: int = _main._touch_settle_until
	_c("start_daily_challenge() → true", _main.start_daily_challenge())
	await _settle(3)
	var board: Node2D = _main._board
	_c("board meydan okuma kipinde: bütçe 15 (perşembe T5·420·15), kullanılan 0", board != null
		and board.is_daily_challenge() and board.drop_budget() == 15 and board.drops_used() == 0
		and is_equal_approx(board.level.container_width, 420.0) and board.level.target_tier == 5)
	_c("round türü AÇIK DAILY_CHALLENGE, denemenin günü 2026-10-01", _main.is_daily_challenge_round()
		and _main.round_kind() == int(_kind("DAILY_CHALLENGE")) and _main._challenge_day == THU)
	_c("level nöbetçi 0 ama yönlendirme türden: round_finished YALNIZ meydan okuma işleyicisine bağlı",
		_main._current_level.level_number == 0 and board.round_finished.is_connected(_main._on_challenge_round_finished)
		and not board.round_finished.is_connected(_main._on_round_finished))
	_c("dizi baştan: bekleyen 1, SIRADAKİ 3", board._pending_tier == GOLDEN[0] and board._next_tier == GOLDEN[1])
	_c("kabuk gizli, sonuç kapalı, başlangıç mevcut 300 ms parmak yatışmasını başlattı",
		not _main._screens[0].visible and not _main._result.visible and _main._touch_settle_until > settle_before)
	_main._start_level(_level(3))
	await _settle(3)
	_c("normal level aynen: tür NORMAL, gün boş, board meydan okuma değil, normal işleyiciye bağlı",
		not _main.is_daily_challenge_round() and _main._challenge_day == "" and not _main._board.is_daily_challenge()
		and _main._board.round_finished.is_connected(_main._on_round_finished)
		and not _main._board.round_finished.is_connected(_main._on_challenge_round_finished))
	await _home()
	SaveManager.data["daily_challenge"] = {"version": 1, "completed_day_key": THU}
	_c("bugün tamamlandı → başlatma REDDEDİLİR (tekrar oynanmaz), board yok", not _main.start_daily_challenge()
		and _main._board == null)
	SaveManager.data["daily_challenge"] = DailyChallenge.default_block()
	DailyRewards.clock_override = "bozuk-saat"
	SaveManager.data["daily_rewards"]["last_seen_day_key"] = ""
	_c("gün gerçeği yok → başlatma REDDEDİLİR", not _main.start_daily_challenge() and _main._board == null)
	DailyRewards.clock_override = THU
	SaveManager.data["onboarding_completed"] = false
	_c("onboarding bitmedi → başlatma REDDEDİLİR", not _main.start_daily_challenge() and _main._board == null)
	SaveManager.data["onboarding_completed"] = true
	_sections_done += 1


# --- 2) Yalıtım: kazanma --------------------------------------------------------------------------

func _isolation_win() -> void:
	print("-- P1 yalıtım: kazanma yalnız +20 Hamur + tamamlanma günü yazar")
	await _fresh(THU)
	var before: Dictionary = SaveManager.data.duplicate(true)
	var disk_before: Dictionary = _disk()
	_main.start_daily_challenge()
	await _settle(3)
	await _drop_twice()
	var merges_before_win: int = GameState.merge_count
	await _win()
	await _wait_result()
	var after: Dictionary = SaveManager.data.duplicate(true)
	_c("kazanma: Hamur tam +20 (335 → 355), completed_day_key = 2026-10-01", int(after["dough"]) == 355
		and SaveManager.daily_challenge_completed_day() == THU)
	_c("round içinde gerçek merge oldu (board-yerel GameState) ama kalıcı sayaçlara GEÇMEDİ",
		GameState.merge_count > merges_before_win and SaveManager.total_merges() == int(before["total_merges"]))
	var diff: Array[String] = _diff_keys(before, after)
	_c("bellekteki kayıtta değişen YALNIZ dough + daily_challenge (değişen: %s)" % str(diff),
		_same(diff, ["daily_challenge", "dough"]))
	var disk: Dictionary = _disk()
	# Disk, round öncesi BELLEK durumuyla karşılaştırılır: fixture dosyasında olmayan varsayılan / göç
	# alanlarını herhangi bir kayıt yazar (meydan okumaya özgü değil); sayılar JSON'da float.
	var disk_diff: Array[String] = _diff_keys(before, disk)
	_c("diskte de YALNIZ dough + daily_challenge (round öncesi kayda göre; değişen: %s)" % str(disk_diff),
		_same(disk_diff, ["daily_challenge", "dough"]) and not disk_before.is_empty())
	_c("  … XP / toplam merge / bonus sayaç / tur / en yüksek tier / yıldız / level / rekor / görev / başarım aynen",
		int(after["player_xp"]) == 400 and int(after["total_merges"]) == 40 and int(after["merges_since_bonus_chest"]) == 10
		and int(after["total_rounds_played"]) == 12 and int(after["highest_tier_created"]) == 4
		and after["level_stars"] == before["level_stars"] and int(after["highest_level_unlocked"]) == 5
		and int(after["endless_high_score"]) == 0 and after["missions"] == before["missions"]
		and after["unlocked_achievements"] == before["unlocked_achievements"] and after["powerups"] == before["powerups"])
	var result: CanvasLayer = _main._result
	_c("sonuç: meydan okuma kazanma ekranı, ödül kartı / sandık YOK, XP şeridi gizli", result.visible
		and result.mode() == _result_mode("CHALLENGE_WIN") and result.cards().is_empty()
		and result.progress_summary().is_empty())
	_c("  … 'MEYDAN OKUMA TAMAM!' · '+20 HAMUR' · HAMLE '2 / 15' · 'Yarın yenilenir' · tek buton ANA SAYFA",
		result.title_text() == "MEYDAN OKUMA TAMAM!" and result.challenge_body_text() == "+20 HAMUR"
		and result.challenge_moves_text() == "2 / 15" and result.challenge_footer_text() == "Yarın yenilenir"
		and result.primary_text() == "ANA SAYFA" and not result.secondary_button().visible
		and result.primary_action() == "exit")
	# Yinelenen bitiş sinyali (Main'in `_round_finalized` kapısı): sonuç ve ödül değişmez.
	var bytes_won: PackedByteArray = _bytes()
	_main._board.round_finished.emit(true)
	await _wait_result()
	_c("yinelenen round_finished(true): sonuç '+20 HAMUR' kalır, Hamur 355, kayıt baytı aynı",
		result.visible and result.challenge_body_text() == "+20 HAMUR" and SaveManager.dough() == 355
		and _bytes() == bytes_won)
	_c("Ana Sayfa'ya dönüş: tamamlandı görünümü, yeniden başlatma yok", await _exit_ok())
	_sections_done += 1


# --- 3) Yalıtım: kayıp / terk ------------------------------------------------------------------------

func _isolation_fail() -> void:
	print("-- P1 yalıtım: kayıp / terk kayda YAZMAZ")
	await _fresh(THU)
	var bytes: PackedByteArray = _bytes()
	var before: Dictionary = SaveManager.data.duplicate(true)
	SaveFile.fault = SaveFile.Fault.TEMP_OPEN
	_main.start_daily_challenge()
	await _settle(3)
	await _drop_twice()
	await _pile_kings()
	await _until_finished(900)
	await _wait_result()
	var result: CanvasLayer = _main._result
	_c("taşma kaybı: meydan okuma kayıp ekranı 'OLMADI' + 'Kap taştı. Sıra aynı, tekrar dene!'",
		result.visible and result.mode() == _result_mode("CHALLENGE_FAIL") and result.title_text() == "OLMADI"
		and result.challenge_body_text() == "Kap taştı. Sıra aynı, tekrar dene!")
	_c("  … TEKRAR DENE + ANA SAYFA, devam teklifi hiç açılmadı", result.primary_text() == "TEKRAR DENE"
		and result.secondary_text() == "ANA SAYFA" and result.secondary_button().visible and not _main._revive.visible)
	_c("kayıp: kayıt baytı aynı, yazma girişimi YOK, bellek aynı", _bytes() == bytes
		and SaveFile.fault == SaveFile.Fault.TEMP_OPEN and _diff_keys(before, SaveManager.data).is_empty())
	# Hamle bitti kaybı (hedef ulaşılmaz kılınır — yalnız bütçe sınaması).
	_main._on_retry_pressed()
	await _settle(3)
	_main._board.level.target_tier = 8
	for i in 15:
		await _quick_drop(i)
	await _quick_drop(15)
	_c("16. bırakış (bütçe 15 doldu) REDDEDİLDİ: kullanılan 15", _main._board.drops_used() == 15
		and _main._board.drops_remaining() == 0)
	await _until_finished(600)
	await _wait_result()
	_c("hamle bitti kaybı: 'OLMADI' + 'Hamlen bitti. Sıra aynı, tekrar dene!' + HAMLE 15 / 15",
		result.visible and result.title_text() == "OLMADI"
		and result.challenge_body_text() == "Hamlen bitti. Sıra aynı, tekrar dene!"
		and result.challenge_moves_text() == "15 / 15" and _main._board.fail_reason() == DailyChallenge.FailReason.MOVES_EXHAUSTED)
	_c("  … kayıt baytı yine aynı, yazma girişimi YOK, bellek aynı", _bytes() == bytes
		and SaveFile.fault == SaveFile.Fault.TEMP_OPEN and _diff_keys(before, SaveManager.data).is_empty())
	# Terk + yeniden başlatma.
	_main._on_retry_pressed()
	await _settle(3)
	await _drop_twice()
	_main.open_pause_menu()
	await _settle(2)
	_main._on_pause_restart()
	await _settle(3)
	await _drop_twice()
	_main.open_pause_menu()
	await _settle(2)
	_main.abandon_run()
	await _settle(3)
	_c("yeniden başlatma + terk: kayıt baytı aynı, yazma YOK, bellek aynı, tamamlanma / Hamur yok", _bytes() == bytes
		and SaveFile.fault == SaveFile.Fault.TEMP_OPEN and SaveManager.daily_challenge_completed_day() == ""
		and SaveManager.dough() == 335 and _diff_keys(before, SaveManager.data).is_empty())
	SaveFile.fault = SaveFile.Fault.NONE
	_sections_done += 1


# --- 4) Akış yolları ---------------------------------------------------------------------------------

func _flow_paths() -> void:
	print("-- tekrar / yeniden başlat / çıkış yolları")
	await _fresh(THU)
	_main.start_daily_challenge()
	await _settle(3)
	var first_attempt: int = _main._challenge_attempt
	await _drop_twice()
	await _pile_kings()
	await _until_finished(900)
	await _wait_result()
	_main._on_retry_pressed()
	await _settle(3)
	var board: Node2D = _main._board
	_c("TEKRAR DENE → aynı gün, dizi BAŞTAN (1, 3), tam bütçe 15, yeni deneme", board.is_daily_challenge()
		and _main._challenge_day == THU and board._pending_tier == GOLDEN[0] and board._next_tier == GOLDEN[1]
		and board.drops_used() == 0 and board.drop_budget() == 15 and _main._challenge_attempt == first_attempt + 1
		and not _main._result.visible)
	await _drop_twice()
	_main.open_pause_menu()
	await _settle(2)
	_c("mola menüsü meydan okumada açılır (aynı pencere)", _main.is_pause_open())
	_main._on_pause_restart()
	await _settle(3)
	board = _main._board
	_c("mola Yeniden Başlat → MEYDAN OKUMA baştan (normal `_start_level` DEĞİL): tür, nöbetçi level, bütçe tam",
		_main.is_daily_challenge_round() and board.is_daily_challenge() and board.drops_used() == 0
		and board._pending_tier == GOLDEN[0] and board.round_finished.is_connected(_main._on_challenge_round_finished)
		and not board.round_finished.is_connected(_main._on_round_finished) and not _main.is_pause_open())
	_main.open_pause_menu()
	await _settle(2)
	_main.abandon_run()
	await _settle(3)
	_c("mola Ana Menüye Dön → Ana Sayfa (giriş yeri), board yok, tür NORMAL", _main._board == null
		and _main._active_tab == 0 and _main._screens[0].visible and not _main.is_daily_challenge_round())
	_main.start_daily_challenge()
	await _settle(3)
	await _drop_twice()
	await _pile_kings()
	await _until_finished(900)
	await _wait_result()
	_main._on_exit_pressed()
	await _settle(3)
	_c("sonuç ANA SAYFA → Ana Sayfa (Harita değil)", _main._board == null and _main._active_tab == 0
		and _main._screens[0].visible and not _main._result.visible)
	_main._start_level(_level(3))
	await _settle(3)
	_main._board._finish(false)
	await _wait_result()
	_main._on_exit_pressed()
	await _settle(3)
	_c("normal level çıkışı aynen Harita'ya (sekme 1)", _main._active_tab == 1)
	# Global RNG: Main'in meydan okuma yolları (pencere aç / kapat, başlat, bitiş işleyicisi, sonuç,
	# tekrar, kazanma yazması, çıkış, Ana Sayfa tazeleme — eşzamanlı, arada kare yok) global RNG'yi
	# YENİDEN TOHUMLAMAZ (farklı başlangıç tohumu → farklı sonraki akış) ve zamana bağlı tohumlamaz
	# (aynı tohum → aynı sonraki akış). Motorun parçacık yeniden başlatmaları gibi tüketimler
	# belirlenimli olduğu sürece serbest (normal round'larda da var); üretimde global RNG'yi yalnız
	# DropBag ve sandık kuraları kullanır.
	var a: Array[int] = await _rng_flow(4747)
	var b: Array[int] = await _rng_flow(4747)
	var c: Array[int] = await _rng_flow(9191)
	_c("global RNG: meydan okuma akışı sonrası aynı tohum → aynı 3 randi() (randomize / saat tohumu yok), farklı tohum → farklı (yeniden tohumlama yok)",
		_same(a, b) and not _same(a, c) and SaveManager.daily_challenge_completed_day() == THU and SaveManager.dough() == 355)
	_sections_done += 1


## Taze kayıt + Main, sonra `seed(k)` ve meydan okuma yollarının EŞZAMANLI turu; dönüş: sonraki 3 randi().
func _rng_flow(k: int) -> Array[int]:
	await _fresh(THU)
	seed(k)
	_main.open_daily_challenge()
	_main._challenge_sheet.close_sheet()
	_main.start_daily_challenge()
	_main._board._finish(false)
	_main._result.show_challenge_result({"won": false, "day_key": THU, "fail_reason": DailyChallenge.FailReason.OVERFLOW,
		"drops_used": 0, "drop_budget": 15, "target_tier": 5, "reached_tier": 1, "day_changed": false})
	_main._retry_daily_challenge()
	_main._board._finish(true)
	_main._result.show_challenge_result({"won": true, "day_key": THU, "rewarded": true, "reward": 20,
		"fail_reason": DailyChallenge.FailReason.NONE, "drops_used": 0, "drop_budget": 15, "target_tier": 5,
		"reached_tier": 5, "day_changed": false})
	_main._leave_daily_challenge()
	_main._screens[0].refresh_daily_challenge()
	var got: Array[int] = [randi(), randi(), randi()]
	# Bekleyen gecikmeli işleyiciler Main canlıyken döner (jeton onları zaten eler).
	await _wait_result()
	return got


# --- 5) Gece yarısı ----------------------------------------------------------------------------------

func _midnight() -> void:
	print("-- gece yarısı kuralı: deneme başladığı güne aittir")
	await _fresh(THU)
	_main.start_daily_challenge()
	await _settle(3)
	DailyRewards.clock_override = FRI
	await _win()
	await _wait_result()
	_c("D'de başlayıp D+1'de kazanılan deneme D'ye yazılır: completed = 2026-10-01, +20",
		SaveManager.daily_challenge_completed_day() == THU and SaveManager.dough() == 355)
	_c("  … sonuç: TAMAM + '+20 HAMUR' + 'Gün değişti · yeni meydan okuma hazır.' (yalnız ANA SAYFA)",
		_main._result.title_text() == "MEYDAN OKUMA TAMAM!" and _main._result.challenge_body_text() == "+20 HAMUR"
		and _main._result.challenge_footer_text() == "Gün değişti · yeni meydan okuma hazır."
		and not _main._result.secondary_button().visible)
	_main._on_exit_pressed()
	await _settle(3)
	var view: Dictionary = DailyChallenge.current_view()
	_c("Ana Sayfa: D+1 (cuma T6·540·36) ayrı, tamamlanmamış meydan okuma", String(view.get("day_key", "")) == FRI
		and not bool(view.get("completed", true)) and int(view.get("drop_budget", 0)) == 36)
	var home: CanvasLayer = _main._screens[0]
	_c("  … Ana Sayfa girişi de D+1: '+20' rozeti + T6 portresi (tamamlandı işareti yok)",
		home.visible and home.challenge_badge_text() == "+20" and not home.is_challenge_done_shown()
		and home.challenge_portrait_texture() == DUMPLING_VISUAL.TEXTURES[5])
	_c("D+1 başlatılabilir ve kendi bütçesiyle", _main.start_daily_challenge() and _main._challenge_day == FRI
		and _main._board.drop_budget() == 36)
	await _settle(3)
	DailyRewards.clock_override = SAT
	await _drop_twice()
	await _pile_kings()
	await _until_finished(900)
	await _wait_result()
	var result: CanvasLayer = _main._result
	_c("D+1'de başlayıp D+2'de biten kayıp: 'Gün değişti · yeni meydan okuma hazır.' + YENİ MEYDAN OKUMA + ANA SAYFA",
		result.title_text() == "OLMADI" and result.challenge_body_text() == "Gün değişti · yeni meydan okuma hazır."
		and result.primary_text() == "YENİ MEYDAN OKUMA" and result.secondary_text() == "ANA SAYFA")
	_main._on_retry_pressed()
	await _settle(3)
	_c("YENİ MEYDAN OKUMA → GÜNCEL günün (cumartesi T6·480·32) meydan okuması", _main._challenge_day == SAT
		and _main._board.drop_budget() == 32 and is_equal_approx(_main._board.level.container_width, 480.0)
		and _main._board.drops_used() == 0)
	_main.open_pause_menu()
	await _settle(2)
	_main.abandon_run()
	await _settle(3)
	_c("D+1 kaybı tamamlanma / Hamur yazmadı", SaveManager.daily_challenge_completed_day() == THU and SaveManager.dough() == 355)
	SaveManager.complete_daily_challenge(SAT)
	DailyRewards.clock_override = FRI
	_c("geri alınan saat (cuma) tamamlanmış cumartesiyi yeniden AÇMAZ: görünüm cumartesi + tamam, başlatma yok",
		String(DailyChallenge.current_view()["day_key"]) == SAT and bool(DailyChallenge.current_view()["completed"])
		and not _main.start_daily_challenge())
	# Gece yarısı SONUÇ GECİKMESİNDE geçerse: gün, sonuç gösterilirken okunur.
	await _fresh(THU)
	_main.start_daily_challenge()
	await _settle(3)
	await _drop_twice()
	await _pile_kings()
	await _until_finished(900)
	DailyRewards.clock_override = FRI
	await _wait_result()
	result = _main._result
	_c("taşma D'de, sonuç gecikmesinde D+1: 'Gün değişti · yeni meydan okuma hazır.' + YENİ MEYDAN OKUMA",
		result.visible and result.challenge_body_text() == "Gün değişti · yeni meydan okuma hazır."
		and result.primary_text() == "YENİ MEYDAN OKUMA")
	await _fresh(THU)
	_main.start_daily_challenge()
	await _settle(3)
	await _win()
	DailyRewards.clock_override = FRI
	await _wait_result()
	_c("kazanma D'de, sonuç gecikmesinde D+1: ödül D'ye (+20), dipnot 'Gün değişti · yeni meydan okuma hazır.'",
		SaveManager.daily_challenge_completed_day() == THU and SaveManager.dough() == 355
		and _main._result.challenge_footer_text() == "Gün değişti · yeni meydan okuma hazır.")
	# Kayıp sonucu AÇIKKEN gece yarısı geçerse: TEKRAR DENE önce yeniler (açık pencerenin BAŞLA'sı gibi).
	await _fresh(THU)
	_main.start_daily_challenge()
	await _settle(3)
	await _drop_twice()
	await _pile_kings()
	await _until_finished(900)
	await _wait_result()
	result = _main._result
	var failed_id: int = _main._board.get_instance_id()
	var attempt: int = _main._challenge_attempt
	_c("ön koşul: D'de taşma sonucu 'Kap taştı. Sıra aynı, tekrar dene!' + TEKRAR DENE",
		result.challenge_body_text() == "Kap taştı. Sıra aynı, tekrar dene!" and result.primary_text() == "TEKRAR DENE")
	_main._notification(NOTIFICATION_APPLICATION_RESUMED)
	await _settle(2)
	_c("kontrol: gün aynıyken öne dönüş sonucu DEĞİŞTİRMEZ", result.primary_text() == "TEKRAR DENE"
		and result.challenge_body_text() == "Kap taştı. Sıra aynı, tekrar dene!")
	DailyRewards.clock_override = FRI
	_main._on_retry_pressed()
	await _settle(3)
	_c("sonuç açıkken gece yarısı → TEKRAR DENE önce sonucu yeniler ('Gün değişti' + YENİ MEYDAN OKUMA), yeni deneme YOK",
		result.visible and result.challenge_body_text() == "Gün değişti · yeni meydan okuma hazır."
		and result.primary_text() == "YENİ MEYDAN OKUMA" and result.secondary_text() == "ANA SAYFA"
		and _main._board.get_instance_id() == failed_id and _main._challenge_attempt == attempt
		and _main._challenge_day == THU)
	_main._on_retry_pressed()
	await _settle(3)
	_c("  … ikinci basış GÜNCEL günün (cuma T6·540·36) meydan okumasını baştan başlatır", not result.visible
		and _main._challenge_day == FRI and _main._board.get_instance_id() != failed_id
		and _main._board.drop_budget() == 36 and _main._board.drops_used() == 0)
	await _fresh(THU)
	_main.start_daily_challenge()
	await _settle(3)
	await _drop_twice()
	await _pile_kings()
	await _until_finished(900)
	await _wait_result()
	DailyRewards.clock_override = FRI
	_main._notification(NOTIFICATION_APPLICATION_RESUMED)
	await _settle(2)
	result = _main._result
	_c("öne dönüşte (gün değişti) açık kayıp sonucu yerinde 'Gün değişti' + YENİ MEYDAN OKUMA'ya yenilenir",
		result.visible and result.challenge_body_text() == "Gün değişti · yeni meydan okuma hazır."
		and result.primary_text() == "YENİ MEYDAN OKUMA" and _main._challenge_day == THU)
	_sections_done += 1


# --- 6) Eski sonuç koruması ---------------------------------------------------------------------------

func _stale_results() -> void:
	print("-- gecikmeli sonuç yalnız kendi denemesine (RESULT_DELAY)")
	await _fresh(THU)
	_main.start_daily_challenge()
	await _settle(3)
	await _drop_twice()
	await _pile_kings()
	await _until_finished(900)
	# Gecikme sürerken kendi yeniden başlatma yolu (mola Yeniden Başlat — QA kancası).
	_main._on_pause_restart()
	await _settle(3)
	var replacement: Node2D = _main._board
	await _wait_result()
	_c("kayıp sonucu beklerken yeni deneme: ESKİ sonuç yeni denemenin üstüne AÇILMADI", not _main._result.visible
		and _main._board == replacement and replacement.is_daily_challenge() and not replacement.is_finished())
	await _pile_kings()
	await _until_finished(900)
	_main.open_pause_menu()
	_main.abandon_run()
	await _settle(3)
	await _wait_result()
	_c("kayıp sonucu beklerken Ana Sayfa'ya çıkış: sonuç Ana Sayfa'nın üstüne AÇILMADI", not _main._result.visible
		and _main._screens[0].visible and _main._board == null)
	_main.start_daily_challenge()
	await _settle(3)
	await _win()
	_main._start_level(_level(3))
	await _settle(3)
	await _wait_result()
	_c("kazanma sonucu beklerken normal round: meydan okuma sonucu normal round'un üstüne AÇILMADI (ödül yine tam bir kez)",
		not _main._result.visible and not _main._board.is_daily_challenge() and SaveManager.dough() == 355
		and SaveManager.daily_challenge_completed_day() == THU)
	# Ters yön (gecikmedeki NORMAL sonuç → meydan okuma) BİLEREK sınanmaz: o, normal round'un ayrı,
	# AÇIK RESULT_DELAY yarışıdır (PROJECT_STATUS §4.24 / §4.27 — bu işte düzeltilmez, normal yol
	# değişmez). Gerçek dokunuşla pratikte zor ama kuramsal olarak mümkün: Mola → Ana Menüye Dön →
	# Android GERİ (yatışmasız) → pill (+300 ms) → BAŞLA (+300 ms) ≈ 600 ms + tepki < 800 ms olabilir.
	await _fresh(THU)
	_main.start_daily_challenge()
	await _settle(3)
	# Kontrol: araya bir şey girmezse sonuç açılır.
	await _pile_kings()
	await _until_finished(900)
	await _wait_result()
	_c("kontrol: araya giren yoksa meydan okuma sonucu gecikmeden sonra açılır", _main._result.visible
		and _main._result.mode() == _result_mode("CHALLENGE_FAIL"))
	# Değiştirilen board'un GEÇ round_finished'ı (aynı kare — board henüz serbest değil): `_clear_board`
	# meydan okuma işleyicisini ayırır → ödül / tamamlanma / kayıt / sonuç YOK, yeni deneme kesinleşmez.
	await _fresh(THU)
	_main.start_daily_challenge()
	await _settle(3)
	var bytes_late: PackedByteArray = _bytes()
	var old: Node2D = _main._board
	_main._on_pause_restart()
	old.round_finished.emit(true)
	await _wait_result()
	_c("değiştirilen board'un geç round_finished(true)'u: +20 / tamamlanma / kayıt / sonuç YOK, yeni deneme sürüyor",
		SaveManager.dough() == 335 and SaveManager.daily_challenge_completed_day() == "" and _bytes() == bytes_late
		and not _main._round_finalized and not _main._result.visible and _main._board != null
		and _main._board.is_daily_challenge() and not _main._board.is_finished())
	_sections_done += 1


# --- 7) Reklam --------------------------------------------------------------------------------------------

func _ads() -> void:
	print("-- reklam: meydan okuma yeni bir yerleşim değil")
	await _fresh(THU, true)
	var fake: FakeAdBackend = _main._ads._backend
	var ads: MonetizationManager = _main._ads
	_c("ön koşul: geçiş reklamı UYGUN + HAZIR (normal round bitişi gösterirdi)", ads.interstitial_eligible()
		and ads.is_interstitial_ready())
	# Bekleyen ödüllü yükleme tamamlanır (READY): sonraki yükleme ancak bir gösterim / istek tetiklerse.
	while not fake.pending_rewarded.is_empty():
		fake.complete_rewarded_load(true)
	await _settle(2)
	var shows: int = fake.interstitial_shows.size()
	var rewarded: int = fake.rewarded_shows.size()
	var rewarded_loads: int = fake.rewarded_loads
	AdEvents.clear_recent()
	_main.start_daily_challenge()
	await _settle(3)
	_c("meydan okuma round'u: yüzey GAMEPLAY (oyun banner'ı mevcut sözleşmeyle)", ads.surface() == MonetizationManager.Surface.GAMEPLAY)
	await _drop_twice()
	await _pile_kings()
	await _until_finished(900)
	await _wait_result()
	_c("taşma kaybı: devam teklifi / ödüllü istek YOK, geçiş reklamı denemesi YOK (olay bile yok)",
		fake.rewarded_shows.size() == rewarded and AdEvents.count(&"rewarded_requested") == 0
		and fake.interstitial_shows.size() == shows and AdEvents.count(&"interstitial_skipped_not_ready") == 0
		and AdEvents.count(&"interstitial_showed") == 0 and ads.interstitial_eligible() and ads.is_interstitial_ready())
	_c("  … devam / refill penceresi hiç görünmedi, yeni ödüllü YÜKLEME yok", not _main._revive.visible
		and not _main._refill.visible and fake.rewarded_loads == rewarded_loads)
	_c("  … sonuç ekranı yüzeyi RESULT (banner gizli)", ads.surface() == MonetizationManager.Surface.RESULT)
	_main._on_retry_pressed()
	await _settle(3)
	await _win()
	await _wait_result()
	_c("kazanma (+20): geçiş reklamı denemesi YOK, ödüllü istek YOK", fake.interstitial_shows.size() == shows
		and AdEvents.count(&"interstitial_skipped_not_ready") == 0 and fake.rewarded_shows.size() == rewarded
		and AdEvents.count(&"rewarded_requested") == 0 and SaveManager.dough() == 355)
	_main._on_exit_pressed()
	await _settle(3)
	_main._start_level(_level(3))
	await _settle(3)
	_main._board._finish(false)
	await _wait_result(0.4)
	_c("kontrol: normal round bitişi AYNI koşulda geçiş reklamını gösterir (davranış aynen)",
		fake.interstitial_shows.size() == shows + 1)
	await _teardown_main()
	# Yaş UNKNOWN: reklam SDK'sı hiç açılmaz, meydan okuma oynanır.
	_clean()
	DailyRewards.clock_override = THU
	_write_fixture({"age_ad_band": "UNKNOWN"})
	SaveManager.load_game()
	var unknown := FakeAdBackend.new()
	_main_script.set("ads_backend_override", unknown)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _settle(3)
	_main_script.set("ads_backend_override", null)
	if _main.age_panel().visible:
		_main.age_panel().visible = false
	_c("yaş UNKNOWN: SDK init / rıza YOK", unknown.init_calls == 0 and unknown.consent_update_calls == 0)
	_c("  … meydan okuma oynanır", _main.start_daily_challenge() and _main._board.is_daily_challenge())
	await _settle(3)
	await _win()
	await _wait_result()
	_c("  … kazanma +20, reklam arka ucuna hiç dokunulmadı", SaveManager.dough() == 355 and unknown.init_calls == 0
		and unknown.interstitial_shows.is_empty() and unknown.rewarded_shows.is_empty())
	await _teardown_main()
	_sections_done += 1


# --- 8) Tutorial ------------------------------------------------------------------------------------------

func _tutorial() -> void:
	print("-- tutorial / onboarding: meydan okuma yok")
	_clean()
	DailyRewards.clock_override = THU
	SaveManager.load_game()
	_c("ön koşul: dosyasız yeni oyuncu (onboarding false)", not SaveManager.onboarding_completed())
	await _boot()
	_c("tutorial açık: meydan okuma başlatılamaz, board tutorial'ın Level 1'i", _main.is_tutorial_active()
		and not _main.start_daily_challenge() and _main._board != null and not _main._board.is_daily_challenge())
	_main._screens[0].refresh_daily_challenge()
	_main.open_daily_challenge()
	await _settle(2)
	_c("tutorial sırasında: Ana Sayfa girişi gizli, pencere kendiliğinden açılmadı, kod yolu da açmadı",
		not _main._screens[0].challenge_button().visible and not _main._challenge_sheet.visible)
	_c("onboarding alanları değişmedi, meydan okuma bloğu varsayılan", not SaveManager.onboarding_completed()
		and SaveManager.onboarding_completed_day() == "" and SaveManager.daily_challenge_completed_day() == "")
	# Gerçek tamamlanma yolu (ATLA → Onboarding.complete) → ilk normal Ana Sayfa: giriş GÖRÜNÜR (ilk gün
	# kuralı yok), pencere kendiliğinden açılmaz, blok varsayılan.
	_main._tutorial.skip()
	await _settle(3)
	await _home()
	var home: CanvasLayer = _main._screens[0]
	_c("tutorial bitti → ilk normal Ana Sayfa: giriş GÖRÜNÜR ('+20'), pencere kendiliğinden AÇILMADI, blok varsayılan",
		SaveManager.onboarding_completed() and home.visible and home.challenge_button().is_visible_in_tree()
		and home.challenge_badge_text() == "+20" and not _main._challenge_sheet.visible
		and SaveManager.daily_challenge_completed_day() == "")
	await _teardown_main()
	_sections_done += 1


# --- 9) Kaynak sözleşmesi ---------------------------------------------------------------------------------

func _source_contract() -> void:
	print("-- kaynak sözleşmesi")
	var main_src: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/main.gd"))
	var handler: String = _function(main_src, "func _on_challenge_round_finished(")
	var forbidden: Array[String] = ["try_show_interstitial", "record_round_finished", "add_merges", "record_mission_round",
		"complete_level", "record_stars", "record_endless_score", "_collect_rewards", "ChestSystem", "reconcile_achievements",
		"PlayerProgression", "show_rewarded", "_ensure_rewarded", "_on_round_finished"]
	var hits: Array[String] = []
	for token in forbidden:
		if handler.contains(token):
			hits.append(token)
	_c("meydan okuma işleyicisi ilerleme / ödül / reklam yollarını çağırmaz (bulunan: %s)" % str(hits),
		hits.is_empty() and handler.contains("complete_daily_challenge") and handler.length() > 0)
	var normal: String = _function(main_src, "func _on_round_finished(")
	_c("normal round işleyicisi meydan okumayı bilmez (koşul eklenmedi)", normal.length() > 0
		and not normal.contains("challenge") and not normal.contains("DailyChallenge") and not normal.contains("_round_kind"))
	_c("meydan okuma başlatması board'u meydan okuma kipine kurar (sequence + bütçe)",
		_function(main_src, "func start_daily_challenge(").contains("setup_challenge"))
	_sections_done += 1


# --- Yardımcılar ------------------------------------------------------------------------------------------

func _fixture(extra: Dictionary = {}) -> Dictionary:
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 2},
		"endless_high_score": 0, "dough": 335, "total_merges": 40, "merges_since_bonus_chest": 10,
		"unlocked_skins": ["common_01", "rare_02"], "profile_showcase": ["rare_02"],
		"powerups": {"bomb": 2, "upgrade": 1, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "", "daily_streak": 3,
		"last_login_date": Time.get_date_string_from_system(), "age_ad_band": "ADULT", "next_age_transition_date": "",
		"player_meta_version": 1, "player_xp": 400, "total_rounds_played": 12, "highest_tier_created": 4,
		"unlocked_achievements": ["merge_10"],
		"daily_rewards": {"day_key": THU, "free_chest_claimed": true, "ad_chests_claimed": 2,
			"dough_ad_claimed": true, "popup_seen_day": THU, "last_seen_day_key": THU},
		"missions": {"version": 1, "day_key": THU, "week_start_day_key": MON,
			"daily_progress": {"daily_merges": 5, "daily_rounds": 1, "daily_clear": 0}, "daily_rewarded": [],
			"weekly_progress": {"weekly_merges": 30, "weekly_rounds": 4, "weekly_clears": 2}, "weekly_rewarded": []}}
	for key: String in extra:
		content[key] = extra[key]
	return content


func _write_fixture(extra: Dictionary = {}) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(_fixture(extra), "\t"))
	file.close()


## Temiz kayıt + Main (isteğe bağlı sahte reklam arka ucu: rıza + init + geçiş reklamı hazır + uygun).
func _fresh(day: String, with_ads: bool = false) -> void:
	await _teardown_main()
	_clean()
	DailyRewards.clock_override = day
	_write_fixture()
	SaveManager.load_game()
	if not with_ads:
		await _boot()
		return
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	await _boot(fake)
	fake.complete_consent_update(true)
	fake.complete_init()
	await _settle(2)
	if not fake.pending_banner.is_empty():
		fake.complete_banner_load(true)
	_main._ads._tick_active(MonetizationManager.INTERSTITIAL_INTERVAL_SEC)
	await _settle(2)
	while not fake.pending_interstitial.is_empty():
		fake.complete_interstitial_load(true)
	await _settle(2)


func _boot(fake: FakeAdBackend = null) -> void:
	await _teardown_main()
	_main_script.set("ads_backend_override", fake)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _settle(3)
	_main_script.set("ads_backend_override", null)


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _settle(2)


func _home() -> void:
	if _main._board != null:
		_main.open_pause_menu()
		await _settle(1)
		_main.abandon_run()
	_main._show_tab(0)
	await _settle(2)


func _exit_ok() -> bool:
	_main._on_exit_pressed()
	await _settle(3)
	return _main._board == null and _main._active_tab == 0 and _main._screens[0].visible \
		and not _main.start_daily_challenge()


func _level(number: int) -> LevelData:
	for level in LevelLibrary.load_levels():
		if level.level_number == number:
			return level
	return null


func _kind(name: String) -> int:
	return int((_main_script.get_script_constant_map()["RoundKind"] as Dictionary)[name])


func _result_mode(name: String) -> int:
	var script: GDScript = load("res://scripts/ui/round_result.gd")
	return int((script.get_script_constant_map()["Mode"] as Dictionary)[name])


## İki gerçek bırakış (bekleme süresi atlanır), kenarlara — hedefe katkısı yok.
func _drop_twice() -> void:
	for i in 2:
		await _quick_drop(i)


func _quick_drop(i: int) -> void:
	var board: Node2D = _main._board
	board._drop_cooldown = 0.0
	board._set_aim(board._left_x() + 40.0 + float((i * 131) % int(board.level.container_width - 80.0)))
	board._drop()
	await _physics(4)


## Gerçek merge ile hedef: sağ kenarda tabandaki (hedef − 1) tier parçasının üstüne aynısı düşer.
func _win() -> void:
	var board: Node2D = _main._board
	var tier: int = board.level.target_tier - 1
	var r: float = TierConfig.radius(tier)
	var floor_y: float = float(board.get_script().get_script_constant_map()["FLOOR_Y"])
	var x: float = board._right_x() - r - 12.0
	board._spawn_dumpling(tier, Vector2(x, floor_y - r - 1.0))
	board._spawn_dumpling(tier, Vector2(x, floor_y - 3.0 * r - 30.0))
	var guard: int = 0
	while not board.is_finished() and guard < 400:
		await get_tree().physics_frame
		guard += 1


## Tier 8 ızgarası (level modunda birleşmez): 400'lük alan kesin taşar.
func _pile_kings() -> void:
	var board: Node2D = _main._board
	var left: float = board._left_x()
	var width: float = board.level.container_width
	var floor_y: float = float(board.get_script().get_script_constant_map()["FLOOR_Y"])
	for row in 3:
		for column in 2:
			board._spawn_dumpling(8, Vector2(left + width * (0.25 if column == 0 else 0.75),
				floor_y - 101.0 - 205.0 * float(row)))
	await _physics(4)


func _until_finished(max_frames: int) -> void:
	var guard: int = 0
	while _main._board != null and is_instance_valid(_main._board) and not _main._board.is_finished() \
			and guard < max_frames:
		await get_tree().physics_frame
		guard += 1


func _wait_result(extra: float = 0.25) -> void:
	var delay: float = float(_main_script.get_script_constant_map()["RESULT_DELAY"])
	await get_tree().create_timer(delay + extra).timeout
	await _settle(2)


func _diff_keys(a: Dictionary, b: Dictionary) -> Array[String]:
	var keys: Dictionary = {}
	for key: String in a:
		keys[key] = true
	for key: String in b:
		keys[key] = true
	var out: Array[String] = []
	for key: String in keys:
		if JSON.stringify(_norm(a.get(key))) != JSON.stringify(_norm(b.get(key))):
			out.append(key)
	out.sort()
	return out


## JSON sayı normalizasyonu: tam değerli float → int (bellek int, disk float okunur).
func _norm(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number: float = value
			return int(number) if is_equal_approx(number, roundf(number)) else number
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key: Variant in value:
				out[str(key)] = _norm(value[key])
			return out
		TYPE_ARRAY:
			var items: Array = []
			for item: Variant in value:
				items.append(_norm(item))
			return items
	return value


func _disk() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if parsed is Dictionary else {}


func _bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(PATH) if FileAccess.file_exists(PATH) else PackedByteArray()


func _same(a: Array, b: Array) -> bool:
	return str(a) == str(b)


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _strip_comments(code: String) -> String:
	var lines: PackedStringArray = []
	for line in code.split("\n"):
		var at: int = line.find("#")
		lines.append(line if at == -1 else line.substr(0, at))
	return "\n".join(lines)


## Fonksiyon gövdesi: başlıktan bir sonraki üst düzey `func`'a kadar.
func _function(code: String, header: String) -> String:
	var start: int = code.find(header)
	if start < 0:
		return ""
	var end: int = code.find("\nfunc ", start + header.length())
	return code.substr(start, (end if end >= 0 else code.length()) - start)


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
