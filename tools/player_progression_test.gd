extends Node
## TASK/045 — Oyuncu Seviyesi + XP testi. Headless; kayıt dosyasını byte-identical
## geri koyar.
##
##   godot --headless --audio-driver Dummy --path . res://tools/player_progression_test.tscn
##
## Kontroller:
##   eğri        0 XP = seviye 1; her erken eşik (tam sınır / bir eksik / seviye içi);
##               gereksinim min(400, 60 + 20·(L−1)) — kaba kuvvet toplamıyla birebir;
##               gereksinim 400'de durur, seviye durmaz (L 100 / 1000 / MAX_XP);
##               ray oranı sınırda 0.
##   doğrulama   bozuk XP (negatif / metin / bool / null / NaN / sonsuz / 1e300 /
##               MAX_XP üstü / dizi) geçersiz; ödül taşmaz; negatif ödül yok sayılır.
##   ödül        merge başına +1 · sabit level bitişi +20 · YENİ yıldız başına +10 ·
##               tekrar oynanan yıldız 0 · kayıp +0 bitiş · sonsuz bitiş yok · çok
##               seviye atlama özeti.
##   göç         TASK/045 öncesi kayıt → bootstrap (812 + 6·10 + 3·20 = 932), yükleme
##               diske yazmaz, idempotent (yazılmadan / yazılıp yeniden yükleme),
##               sürüm 1; kayıtlı geçerli XP korunur; bozuk XP gerçeklerden kurtarılır;
##               biçimsiz kapsayıcılar çökme yapmaz; yeni kurulum 0 XP / seviye 1.
##   round       gerçek Main: kazanma (merge + 20 + yeni yıldız), tekrar (yıldız yok),
##               kayıp, sonsuz, Büyütücü notu XP vermez; yinelenen kesinleştirme XP /
##               tur / merge'i İKİNCİ KEZ yazmaz, yeni round korumayı sıfırlar; XP
##               aynı kayıt yazmasında dosyada.
##   kaynak yok  Mağaza (parça / güç), Hamur ekle / harca, sandık, günlük ücretsiz /
##               reklamlı sandık, reklamlı Hamur, ödüllü güç, güç tüketimi XP VERMEZ;
##               kaynak taraması: XP'yi yalnız SaveManager yazar, round ödülünü yalnız
##               Main hesaplar.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SECTIONS: int = 6
const LEGACY_BASE: Dictionary = {
	"highest_level_unlocked": 4,
	"level_stars": {"1": 2, "2": 2, "3": 2},
	"endless_high_score": 0,
	"dough": 335,
	"total_merges": 812,
	"merges_since_bonus_chest": 62,
	"unlocked_skins": ["common_01", "rare_02"],
	"powerups": {"bomb": 2, "upgrade": 1, "shake": 0, "clear_small": 1},
	"powerup_starter_granted": true,
	"onboarding_completed": true,
	"total_rounds_played": 40,
	"highest_tier_created": 6,
	"age_ad_band": "ADULT",
}

var _fails: int = 0
var _checks: int = 0
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _saved: Dictionary = {}
var _finished: bool = false
var _sections_done: int = 0
var _main: Node2D


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_saved = SaveManager.data.duplicate(true)
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 240 s'de bitmedi — kayıt geri kondu")
			_restore_save_file()
			get_tree().quit(2))

	_curve()
	_sanitize()
	_awards()
	_migration()
	await _round_flow()
	_no_xp_sources()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	print("-- kayıt")
	_restore_save_file()
	SaveManager.load_game()
	var restored: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) if _had_save else PackedByteArray()
	_c("kayıt dosyası byte-identical geri kondu (%d bayt)" % _save_bytes.size(), restored == _save_bytes
		and FileAccess.file_exists(SaveManager.SAVE_PATH) == _had_save)
	_finished = true
	print("\nSONUC: %d kontrol, %d hata" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _exit_tree() -> void:
	if _finished:
		return
	print("  [FAIL] test SONUC'tan önce ağaçtan çıktı — kayıt geri kondu")
	_restore_save_file()


# --- Eğri ------------------------------------------------------------------------

## Gereksinim formülünün testteki BAĞIMSIZ kopyası (brief: min(400, 60 + 20·(L−1))).
static func _spec_to_next(level: int) -> int:
	return mini(400, 60 + 20 * (level - 1))


func _curve() -> void:
	print("-- eğri")
	_c("0 XP = seviye 1, seviye içi 0, gereksinim 60, oran 0", PlayerProgression.level_for_xp(0) == 1
		and PlayerProgression.xp_into_level(0) == 0 and PlayerProgression.xp_required_for_next(0) == 60
		and is_zero_approx(PlayerProgression.level_ratio(0)))
	var to_next_ok: bool = true
	for level in range(1, 61):
		if PlayerProgression.xp_to_next(level) != _spec_to_next(level):
			to_next_ok = false
			print("    xp_to_next(%d) = %d, beklenen %d" % [level, PlayerProgression.xp_to_next(level), _spec_to_next(level)])
	_c("gereksinim 1..60: 60, 80, 100 … 380, sonra 400 (formülle birebir)", to_next_ok)
	_c("örnekler: 1→2 60 · 2→3 80 · 3→4 100 · 17→18 380 · 18→19 400 · 1000→1001 400",
		PlayerProgression.xp_to_next(1) == 60 and PlayerProgression.xp_to_next(2) == 80
		and PlayerProgression.xp_to_next(3) == 100 and PlayerProgression.xp_to_next(17) == 380
		and PlayerProgression.xp_to_next(18) == 400 and PlayerProgression.xp_to_next(1000) == 400)
	_c("tavan sabitleri: CAP_LEVEL 18, XP_AT_CAP_LEVEL 3740 (60 + 80 + … + 380)",
		PlayerProgression.CAP_LEVEL == 18 and PlayerProgression.XP_AT_CAP_LEVEL == 3740)
	var cumulative: int = 0
	var totals_ok: bool = true
	var boundary_ok: bool = true
	for level in range(1, 301):
		if PlayerProgression.total_xp_for_level(level) != cumulative:
			totals_ok = false
			print("    total_xp_for_level(%d) = %d, kaba kuvvet %d" % [level, PlayerProgression.total_xp_for_level(level), cumulative])
		# Tam sınır, bir eksik, seviye içi son XP.
		if PlayerProgression.level_for_xp(cumulative) != level or PlayerProgression.xp_into_level(cumulative) != 0:
			boundary_ok = false
			print("    sınır: %d XP → %d (beklenen %d)" % [cumulative, PlayerProgression.level_for_xp(cumulative), level])
		if level > 1 and PlayerProgression.level_for_xp(cumulative - 1) != level - 1:
			boundary_ok = false
			print("    bir eksik: %d XP → %d (beklenen %d)" % [cumulative - 1, PlayerProgression.level_for_xp(cumulative - 1), level - 1])
		var last: int = cumulative + _spec_to_next(level) - 1
		if PlayerProgression.level_for_xp(last) != level or PlayerProgression.xp_into_level(last) != _spec_to_next(level) - 1 \
				or PlayerProgression.xp_required_for_next(last) != _spec_to_next(level):
			boundary_ok = false
			print("    seviye içi son: %d XP" % last)
		cumulative += _spec_to_next(level)
	_c("kümülatif eşikler 1..300 kaba kuvvet toplamıyla birebir (kapalı form)", totals_ok)
	_c("1..300 her sınır: tam sınır → seviye (içi 0), bir eksik → önceki seviye, 'gereksinim − 1' → aynı seviye", boundary_ok)
	_c("erken eşikler: 59 → 1, 60 → 2, 139 → 2, 140 → 3, 239 → 3, 240 → 4", PlayerProgression.level_for_xp(59) == 1
		and PlayerProgression.level_for_xp(60) == 2 and PlayerProgression.level_for_xp(139) == 2
		and PlayerProgression.level_for_xp(140) == 3 and PlayerProgression.level_for_xp(239) == 3
		and PlayerProgression.level_for_xp(240) == 4)
	_c("örnek 'LV. 7 · 84 / 180': seviye 7 = 660 XP'de başlar → 744 XP = içi 84, gereksinim 180",
		PlayerProgression.total_xp_for_level(7) == 660 and PlayerProgression.level_for_xp(744) == 7
		and PlayerProgression.xp_into_level(744) == 84 and PlayerProgression.xp_required_for_next(744) == 180)
	_c("sınırda oran 0 ('0 / gereksinim'), yarıda 0.5", is_zero_approx(PlayerProgression.level_ratio(140))
		and is_equal_approx(PlayerProgression.level_ratio(140 + 50), 0.5))
	var level_100: int = PlayerProgression.total_xp_for_level(100)
	_c("yüksek seviye: L100 = 3740 + 400·82 = %d XP; L1000; seviye tavanı YOK" % level_100,
		level_100 == 36540 and PlayerProgression.level_for_xp(level_100) == 100
		and PlayerProgression.level_for_xp(level_100 - 1) == 99
		and PlayerProgression.level_for_xp(PlayerProgression.total_xp_for_level(1000)) == 1000)
	var top: int = PlayerProgression.level_for_xp(PlayerProgression.MAX_XP)
	# Sabit süre: 200 çağrının ortalaması (tek çağrı duvar saati yük altında oynar — lens 8).
	# 2,5 milyon adımlık bir döngü çağrı başına onlarca ms sürerdi; sınır bunun çok altında.
	var start: int = Time.get_ticks_usec()
	for i in 200:
		PlayerProgression.level_for_xp(PlayerProgression.MAX_XP - i)
	var took: float = float(Time.get_ticks_usec() - start) / 200.0
	_c("MAX_XP'de seviye %d (> 2 milyon, sonlu, pozitif) ve sabit süre (ort. %.1f µs)" % [top, took], top > 2_000_000
		and top == 18 + (PlayerProgression.MAX_XP - 3740) / 400 and took < 1000.0)
	_c("saçma büyük seviye sorgusu int taşırmaz (INT64_MAX → tavan seviyenin toplamı, pozitif)",
		PlayerProgression.total_xp_for_level(9223372036854775807) == PlayerProgression.total_xp_for_level(PlayerProgression.LEVEL_QUERY_CAP)
		and PlayerProgression.total_xp_for_level(9223372036854775807) > PlayerProgression.MAX_XP
		and PlayerProgression.level_for_xp(PlayerProgression.total_xp_for_level(PlayerProgression.LEVEL_QUERY_CAP) - 1)
		== PlayerProgression.LEVEL_QUERY_CAP - 1)
	_c("negatif XP seviye 1 okunur (döngü / taşma yok)", PlayerProgression.level_for_xp(-50) == 1
		and PlayerProgression.xp_into_level(-50) == 0)
	_sections_done += 1


# --- Doğrulama -------------------------------------------------------------------

func _sanitize() -> void:
	print("-- doğrulama")
	_c("geçerli int / JSON float kabul (0, 932, 932.0, MAX_XP)", PlayerProgression.sanitize_xp(0) == 0
		and PlayerProgression.sanitize_xp(932) == 932 and PlayerProgression.sanitize_xp(932.0) == 932
		and PlayerProgression.sanitize_xp(PlayerProgression.MAX_XP) == PlayerProgression.MAX_XP)
	var bad: Array = [-1, -0.5, "123", "abc", true, null, NAN, INF, -INF, 1e300, PlayerProgression.MAX_XP + 1,
		float(PlayerProgression.MAX_XP) * 2.0, [5], {"xp": 5}]
	var rejected: bool = true
	for value in bad:
		if PlayerProgression.sanitize_xp(value) != -1:
			rejected = false
			print("    kabul edildi: ", value)
	_c("bozuk XP geçersiz: negatif, metin, bool, null, NaN, ±sonsuz, 1e300, MAX_XP üstü, dizi, sözlük", rejected)
	_c("ödül MAX_XP'de durur (int taşması yok); negatif ödül yok sayılır",
		PlayerProgression.add_xp(PlayerProgression.MAX_XP - 5, 100) == PlayerProgression.MAX_XP
		and PlayerProgression.add_xp(100, -40) == 100 and PlayerProgression.add_xp(-10, 5) == 5)
	_sections_done += 1


# --- Ödül ------------------------------------------------------------------------

func _awards() -> void:
	print("-- round ödülü (saf)")
	_c("merge başına +1 (kayıp: 17 merge → 17, bitiş bonusu YOK)", PlayerProgression.round_xp_award(17, false, 0, 0) == 17)
	_c("sabit level bitişi +20 (0 merge, yıldız yok → 20)", PlayerProgression.round_xp_award(0, true, 3, 3) == 20)
	_c("yeni yıldız: önceki 0 → 2 = +20 (+ bitiş 20 + 5 merge = 45)", PlayerProgression.round_xp_award(5, true, 0, 2) == 45)
	_c("yeni yıldız: önceki 2 → 3 = +10", PlayerProgression.round_xp_award(0, true, 2, 3) == 30)
	_c("tekrar oynanış 3 → 3 = +0 yıldız; daha kötü tekrar 3 → 1 = +0", PlayerProgression.round_xp_award(0, true, 3, 3) == 20
		and PlayerProgression.round_xp_award(0, true, 3, 1) == 20)
	_c("bozuk önceki yıldız (9 → 3'e kırpılır) yeni yıldız saymaz; negatif merge 0",
		PlayerProgression.round_xp_award(-4, true, 9, 3) == 20)
	_c("sonsuz / kayıp: fixed_level_cleared false → yalnız merge (yıldız verilse de)",
		PlayerProgression.round_xp_award(40, false, 0, 3) == 40)
	var summary: Dictionary = PlayerProgression.round_summary(50, 300, [], [])
	_c("çok seviye atlama: 50 → 300 XP = seviye 1 → 4 (3 seviye), +250", int(summary["level_before"]) == 1
		and int(summary["level_after"]) == 4 and int(summary["levels_gained"]) == 3 and int(summary["xp_gained"]) == 250)
	var same: Dictionary = PlayerProgression.round_summary(60, 60, [&"first_merge"], [&"first_merge"])
	_c("0 XP'lik round: seviye atlama yok, yeni başarım yok (önceden açık olan sayılmaz)",
		int(same["xp_gained"]) == 0 and int(same["levels_gained"]) == 0 and (same["new_achievements"] as Array).is_empty())
	var fresh: Dictionary = PlayerProgression.round_summary(0, 5, [], [&"stars_5", &"first_merge"])
	_c("özet yeni başarımları KATALOG sırasıyla verir (first_merge, stars_5)",
		fresh["new_achievements"] == [&"first_merge", &"stars_5"])
	var backwards: Dictionary = PlayerProgression.round_summary(500, 100, [], [])
	_c("özet XP'yi asla geri saymaz (bozuk 'sonra' < 'önce' → +0)", int(backwards["xp_gained"]) == 0
		and int(backwards["level_after"]) == int(backwards["level_before"]))
	_sections_done += 1


# --- Göç ---------------------------------------------------------------------------

func _migration() -> void:
	print("-- göç (TASK/045 öncesi kayıt)")
	_write_save(_legacy({}))
	var bytes: PackedByteArray = _bytes()
	SaveManager.load_game()
	var expected: int = 812 + 6 * 10 + 3 * 20
	_c("bootstrap = 812 merge + 6 yıldız·10 + 3 level·20 = 932", SaveManager.player_xp() == expected
		and PlayerProgression.bootstrap_xp(812, 6, 3) == 932)
	_c("seviye XP'den türetildi (932 → %d), 'player_level' kayıt alanı YOK" % PlayerProgression.level_for_xp(932),
		SaveManager.player_level() == PlayerProgression.level_for_xp(932) and not SaveManager.data.has("player_level")
		and not SaveManager.DEFAULT_DATA.has("player_level"))
	_c("sürüm 1 ve unvan varsayılan 'birlestirici' (bellekte)", int(SaveManager.data["player_meta_version"]) == 1
		and SaveManager.selected_title_id() == &"birlestirici")
	_c("yükleme diske YAZMADI (dosya byte-identical)", _bytes() == bytes)
	_c("geçmiş uydurulmadı: merge / yıldız / tur / tier / Hamur aynen", SaveManager.total_merges() == 812
		and PlayerProfile.total_stars() == 6 and SaveManager.total_rounds_played() == 40
		and SaveManager.highest_tier_created() == 6 and SaveManager.dough() == 335)
	SaveManager.load_game()
	_c("idempotent: yazılmadan yeniden yükleme → yine 932, dosya aynı", SaveManager.player_xp() == expected and _bytes() == bytes)
	SaveManager.save_game()
	var written: Dictionary = _read_save_file()
	_c("doğal kayıt: player_xp 932 + sürüm 1 kalıcı, seviye alanı yok", int(written.get("player_xp", -1)) == expected
		and int(written.get("player_meta_version", -1)) == 1 and not written.has("player_level"))
	SaveManager.load_game()
	_c("kalıcı kayıttan yeniden yükleme: 932 (ikinci bootstrap yok)", SaveManager.player_xp() == expected)
	SaveManager.data["total_merges"] = 5000
	SaveManager.save_game()
	SaveManager.load_game()
	_c("göç bir kez: sonradan artan gerçekler XP'yi yeniden TÜRETMEZ (kayıtlı 932 korunur)",
		SaveManager.player_xp() == expected)

	_write_save(_legacy({"player_meta_version": 1, "player_xp": 5000}))
	SaveManager.load_game()
	_c("sürümlü kayıt: kayıtlı geçerli XP (5000) korunur, bootstrap uygulanmaz", SaveManager.player_xp() == 5000)
	for bad: Variant in [-5, "abc", 1e300, null, [3], true]:
		_write_save(_legacy({"player_meta_version": 1, "player_xp": bad}))
		SaveManager.load_game()
		_c("bozuk XP (%s) → gerçeklerden kurtarıldı (932), çökme yok" % str(bad), SaveManager.player_xp() == expected
			and PlayerProgression.sanitize_xp(SaveManager.data["player_xp"]) == expected)
	_write_save(_legacy({"player_meta_version": 1}))
	SaveManager.load_game()
	_c("sürüm var ama XP yok → gerçeklerden kurtarıldı (932)", SaveManager.player_xp() == expected)
	_write_save(_legacy({"player_xp": 77}))
	SaveManager.load_game()
	_c("XP var, sürüm yok → kayıtlı XP (77) korunur, sürüm 1 eklenir", SaveManager.player_xp() == 77
		and int(SaveManager.data["player_meta_version"]) == 1)
	SaveManager.data["player_xp"] = "bozuk"
	_c("çalışma anında bozulan XP okumada kurtarılır (yazma yok)", SaveManager.player_xp() == expected)

	_write_save(_legacy({"level_stars": [3, 3], "unlocked_skins": "rare_02", "highest_level_unlocked": null,
		"total_merges": "çok"}))
	SaveManager.load_game()
	_c("biçimsiz kapsayıcılar (yıldız dizi, sahiplik metin, level null, merge metin) → çökme yok, bootstrap 0",
		SaveManager.player_xp() == 0 and SaveManager.player_level() == 1 and PlayerProfile.total_stars() == 0
		and PlayerProfile.collection_count() == 0)
	# Lens 1: int64 dışı float'ın `int()` çevirisi platforma bağlı (x86 INT64_MIN, ARM doygun
	# INT64_MAX) — okuyucu bunu BOZUK sayar: her platformda 0 merge, bootstrap = 60 + 60.
	for huge: Variant in [1e300, -1e300, 9.5e18]:
		_write_save(_legacy({"total_merges": huge}))
		SaveManager.load_game()
		_c("int64 dışı merge (%s) bozuk sayılır: 0 merge, XP = 6·10 + 3·20 = 120, merge başarımı yok" % str(huge),
			SaveManager.total_merges() == 0 and SaveManager.player_xp() == 120
			and not SaveManager.is_achievement_unlocked(&"first_merge"))
	_write_save(_legacy({"total_merges": "812"}))
	SaveManager.load_game()
	SaveManager.add_merges(12)
	_c("metin merge ('812') okuyucu ve add_merges için AYNI (0 → 12): 12 merge'lük round 100 / 500 başarımı açamaz",
		SaveManager.total_merges() == 12 and not SaveManager.is_achievement_unlocked(&"merge_100"))
	_write_save(_legacy({"highest_level_unlocked": "-99999999999999999999"}))
	SaveManager.load_game()
	_c("taşan metin level ('-9999…') INT64 ucunda sarmaz: 0 tamamlanan level, Harita Ustası yok",
		PlayerProfile.completed_levels() == 0 and not SaveManager.is_achievement_unlocked(&"levels_10")
		and SaveManager.player_xp() == 812 + 60)

	_delete_save()
	SaveManager.load_game()
	_c("yeni kurulum: 0 XP, seviye 1, sürüm 1, unvan varsayılan, başarım yok", SaveManager.player_xp() == 0
		and SaveManager.player_level() == 1 and int(SaveManager.data["player_meta_version"]) == 1
		and SaveManager.selected_title_id() == &"birlestirici" and SaveManager.unlocked_achievements().is_empty())
	_c("yeni kurulum dosyası (başlangıç hediyesi kaydı) player_xp 0 + sürüm 1 taşıyor",
		int(_read_save_file().get("player_xp", -1)) == 0 and int(_read_save_file().get("player_meta_version", -1)) == 1)
	_sections_done += 1


# --- Gerçek Main: round kesinleştirme ------------------------------------------------

func _round_flow() -> void:
	print("-- round (gerçek Main)")
	_delete_save()
	SaveManager.load_game()
	SaveManager.data["onboarding_completed"] = true
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.data["highest_level_unlocked"] = 11
	SaveManager.save_game()
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _settle(2)
	var level_2: LevelData = _level(2)

	# 1) Kazanma: 12 merge, skor 3★ eşiğinde (önceki en iyi 0).
	var xp0: int = SaveManager.player_xp()
	var rounds0: int = SaveManager.total_rounds_played()
	var merges0: int = SaveManager.total_merges()
	await _play_round(level_2, true, 12, level_2.star_3_threshold())
	var gained: int = SaveManager.player_xp() - xp0
	_c("kazanma: 12 merge + 20 bitiş + 3 yeni yıldız·10 = 62 XP (aldı %d)" % gained, gained == 62)
	_c("XP aynı round kaydında dosyada (player_xp %d)" % SaveManager.player_xp(),
		int(_read_save_file().get("player_xp", -1)) == SaveManager.player_xp())
	_c("tur +1, merge +12 (kanonik sayaçlar aynen)", SaveManager.total_rounds_played() == rounds0 + 1
		and SaveManager.total_merges() == merges0 + 12)

	# 2) Yinelenen kesinleştirme: aynı round için ikinci sinyal / çağrı.
	var xp1: int = SaveManager.player_xp()
	var rounds1: int = SaveManager.total_rounds_played()
	var merges1: int = SaveManager.total_merges()
	var file1: PackedByteArray = _bytes()
	_main._on_round_finished(true)
	_main._on_round_finished(true)
	_main._board._finish(true)
	_c("yinelenen kesinleştirme (2× _on_round_finished + 2. _finish) XP / tur / merge'i İKİNCİ KEZ yazmadı",
		SaveManager.player_xp() == xp1 and SaveManager.total_rounds_played() == rounds1
		and SaveManager.total_merges() == merges1)
	_c("yinelenen kesinleştirme diske de yazmadı (dosya aynı)", _bytes() == file1)
	await _leave_round()

	# 3) Tekrar oynanış, yine 3★: yıldız XP'si YOK, bitiş +20 var.
	var xp2: int = SaveManager.player_xp()
	await _play_round(level_2, true, 5, level_2.star_3_threshold())
	_c("yeni round korumayı sıfırladı; tekrar 3★: 5 merge + 20 bitiş + 0 yıldız = 25",
		SaveManager.player_xp() - xp2 == 25)
	await _leave_round()

	# 4) Kayıp: yalnız merge.
	var xp3: int = SaveManager.player_xp()
	await _play_round(level_2, false, 9, 0)
	_c("kayıp: 9 merge = 9 XP (bitiş bonusu yok)", SaveManager.player_xp() - xp3 == 9)
	await _leave_round()

	# 5) Sonsuz: yalnız merge (bitiş bonusu yok).
	var xp4: int = SaveManager.player_xp()
	await _play_round(LevelLibrary.load_endless(), false, 30, 5000)
	_c("sonsuz: 30 merge = 30 XP (sabit level bitiş bonusu yok)", SaveManager.player_xp() - xp4 == 30)
	await _leave_round()

	# 6) Büyütücü notu XP vermez (yalnız istatistik).
	var xp5: int = SaveManager.player_xp()
	_main._start_level(level_2)
	await _settle(2)
	GameState.note_tier_created(6)
	_main._board._finish(false)
	await _settle(1)
	_c("Büyütücü tier'ı (merge değil) XP vermedi; 0 merge'lük kayıp = 0 XP", SaveManager.player_xp() == xp5)
	await _leave_round()

	# 7) Terk edilen round XP almaz.
	var xp6: int = SaveManager.player_xp()
	_main._start_level(level_2)
	await _settle(2)
	for i in 8:
		GameState.register_merge(3, Vector2(360, 700))
	_main.abandon_run()
	await _settle(1)
	_c("terk edilen round (Mola → Ana Menüye Dön) XP almadı", SaveManager.player_xp() == xp6)

	# 8) Çok seviye atlama + sonuç ekranı özeti.
	SaveManager.data["player_xp"] = 50
	SaveManager.data["level_stars"] = {}
	await _play_round(_level(3), true, 150, _level(3).star_3_threshold(), true)
	var shown: Dictionary = _main._result.progress_summary()
	_c("çok seviye: 50 + 150 + 20 + 30 = 250 XP → seviye 1 → 4; sonuç özeti aynı (%s)" % str(shown),
		SaveManager.player_xp() == 250 and int(shown.get("level_before", -1)) == 1 and int(shown.get("level_after", -1)) == 4
		and int(shown.get("xp_gained", -1)) == 200 and int(shown.get("levels_gained", -1)) == 3)
	await _leave_round()

	# 9) Tek yazma (lens 1-2): level açılışı / yıldız / rekor round kaydına katlanır — XP ile
	#    dayandığı yıldız farkı ayrı yazmalara bölünmez; arada bir çökme yıldızı kaydedip
	#    XP'yi kaybettiremez (sonraki tekrar yıldızı "sahip olunan" sayardı).
	SaveManager.data["highest_level_unlocked"] = 5
	SaveManager.data["level_stars"] = {}
	SaveManager.save_game()
	var disk_before: PackedByteArray = _bytes()
	var xp_w: int = SaveManager.player_xp()
	SaveManager.complete_level(5, false)
	SaveManager.record_stars(5, 2, false)
	SaveManager.record_endless_score(SaveManager.endless_high_score() + 1, false)
	_c("save=false: level / yıldız / rekor bellekte, disk DOKUNULMADI", _bytes() == disk_before
		and SaveManager.highest_level_unlocked() == 6 and SaveManager.stars_for_level(5) == 2)
	SaveManager.record_round_finished(0, 30)
	var disk: Dictionary = _read_save_file()
	_c("round kaydı level + yıldız + rekor + XP'yi TEK yazmada diske indirdi", int(disk.get("highest_level_unlocked", 0)) == 6
		and int((disk.get("level_stars", {}) as Dictionary).get("5", 0)) == 2
		and int(disk.get("endless_high_score", -1)) == SaveManager.endless_high_score()
		and int(disk.get("player_xp", -1)) == xp_w + 30)
	var main_src: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/main.gd"))
	_c("Main round kesinleştirmesi level / yıldız / rekoru save=false ile işler (yazma round kaydında)",
		main_src.contains("complete_level(_current_level.level_number, false)")
		and main_src.contains("record_stars(_current_level.level_number, stars, false)")
		and main_src.contains("record_endless_score(score, false)"))

	# 10) Giden board'un geç round_finished'i (queue_free karesi) yeni round'un kesinleştirme
	#     korumasını tüketemez — yoksa yeni round'un gerçek bitişi sonuçsuz kalırdı.
	_main._start_level(level_2)
	await _settle(2)
	var old_board: Node = _main._board
	_main._start_level(level_2)
	var xp_s: int = SaveManager.player_xp()
	var rounds_s: int = SaveManager.total_rounds_played()
	var disk_s: PackedByteArray = _bytes()
	old_board.round_finished.emit(true)
	_c("eski board'un geç round_finished'i yok sayıldı: XP / tur / disk aynı, yeni round kesinleşmedi",
		SaveManager.player_xp() == xp_s and SaveManager.total_rounds_played() == rounds_s and _bytes() == disk_s
		and not _main._round_finalized)
	await _settle(2)
	_main._board._finish(false)
	await _settle(1)
	_c("yeni round'un gerçek bitişi yine kesinleşti (tur +1)", SaveManager.total_rounds_played() == rounds_s + 1)
	await _leave_round()
	_main.queue_free()
	_main = null
	await _settle(2)
	_sections_done += 1


## Round kur, `merges` gerçek merge kaydı, skor, bitir. `wait_result`: sonuç ekranı
## açılana kadar bekle (RESULT_DELAY; masaüstünde geçiş reklamı yok).
func _play_round(level: LevelData, won: bool, merges: int, score: int, wait_result: bool = false) -> void:
	_main._start_level(level)
	await _settle(2)
	for i in merges:
		GameState.register_merge(2 + (i % 3), Vector2(360, 700))
	GameState.add_score(score)
	_main._board._finish(won)
	await _settle(1)
	if wait_result:
		await get_tree().create_timer(_main.RESULT_DELAY + 0.3).timeout
		await _settle(2)


func _leave_round() -> void:
	_main._result.hide_result()
	_main.abandon_run()
	await _settle(1)


# --- Kaynak yok --------------------------------------------------------------------

func _no_xp_sources() -> void:
	print("-- XP vermeyen yollar")
	_delete_save()
	SaveManager.load_game()
	SaveManager.data["dough"] = 100000
	SaveManager.data["player_xp"] = 321
	var day: String = "2026-09-28"
	# Her işlemin GERÇEKTEN gerçekleştiği de doğrulanır (lens 8: sessizce no-op olan bir
	# işlem "XP vermedi" kontrolünü yanlış sebeple geçirirdi).
	var skin: SkinData = SkinLibrary.by_rarity(SkinData.Rarity.COMMON)[0]
	var bought: bool = SaveManager.purchase_skin_with_dough(skin.id, Shop.price_of(skin))
	_c("Mağaza parça satın alma gerçekleşti ve XP vermedi", bought and SaveManager.owns_skin(skin.id)
		and SaveManager.player_xp() == 321)
	var bombs: int = SaveManager.powerup_count(PowerUp.Type.BOMB)
	var bought_power: bool = SaveManager.purchase_powerup_with_dough(PowerUp.Type.BOMB, 3)
	_c("Mağaza güç satın alma gerçekleşti ve XP vermedi", bought_power
		and SaveManager.powerup_count(PowerUp.Type.BOMB) > bombs and SaveManager.player_xp() == 321)
	var dough: int = SaveManager.dough()
	SaveManager.add_dough(500)
	var spent: bool = SaveManager.spend_dough(200)
	_c("Hamur ekle / harca gerçekleşti ve XP vermedi", spent and SaveManager.dough() == dough + 300
		and SaveManager.player_xp() == 321)
	var rewards: Array = []
	for i in 6:
		rewards.append(ChestSystem.open())
	rewards.append(ChestSystem.consolation())
	_c("sandık (level / bonus / teselli) açıldı (7 ödül) ve XP vermedi", rewards.size() == 7
		and not rewards.has(null) and SaveManager.player_xp() == 321)
	var daily_skin: SkinData = SkinLibrary.by_rarity(SkinData.Rarity.RARE)[1]
	var free_ok: bool = SaveManager.claim_daily_free_chest(day, 15, daily_skin.id)
	var ad_chest_ok: bool = SaveManager.grant_daily_ad_chest(day, 15, &"", 2)
	var ad_dough_ok: bool = SaveManager.grant_daily_ad_dough(day, 150)
	_c("günlük ücretsiz / reklamlı sandık + reklamlı +150 Hamur gerçekleşti ve XP vermedi", free_ok and ad_chest_ok
		and ad_dough_ok and SaveManager.owns_skin(daily_skin.id) and SaveManager.player_xp() == 321)
	var refill_ok: bool = SaveManager.grant_rewarded_powerup(PowerUp.Type.SHAKE, day)
	var used: bool = SaveManager.consume_powerup(PowerUp.Type.BOMB)
	var upgrades: int = SaveManager.powerup_count(PowerUp.Type.UPGRADE)
	SaveManager.grant_powerup(PowerUp.Type.UPGRADE, 2)
	_c("ödüllü güç refill / güç tüketimi / güç hediyesi gerçekleşti ve XP vermedi", refill_ok and used
		and SaveManager.powerup_count(PowerUp.Type.UPGRADE) == upgrades + 2 and SaveManager.player_xp() == 321)
	SaveManager.record_daily_login(day, 3)
	var record: bool = SaveManager.record_endless_score(99999)
	_c("günlük giriş ödülü ve sonsuz rekor kaydı gerçekleşti ve XP vermedi", record
		and SaveManager.daily_streak() == 3 and SaveManager.endless_high_score() == 99999 and SaveManager.player_xp() == 321)

	var writers: Array[String] = []
	var awarders: Array[String] = []
	for path in _script_files("res://scripts"):
		var src: String = _strip_comments(FileAccess.get_file_as_string(path))
		if src.contains("\"player_xp\"] =") or src.contains("\"player_xp\"]="):
			writers.append(path.get_file())
		if src.contains("round_xp_award("):
			awarders.append(path.get_file())
	_c("kaynak: XP'yi yalnız SaveManager yazar %s" % str(writers), writers == ["save_manager.gd"])
	_c("kaynak: round ödülünü yalnız Main hesaplar (+ tanım) %s" % str(awarders),
		awarders.size() == 2 and awarders.has("main.gd") and awarders.has("player_progression.gd"))
	var save_src: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/autoload/save_manager.gd"))
	var xp_lines: int = save_src.count("data[\"player_xp\"] =")
	_c("SaveManager'da XP yalnız iki yerde yazılır: göç + record_round_finished (%d)" % xp_lines, xp_lines == 2)
	var main_src: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/main.gd"))
	_c("Main round başına TEK kayıt çağrısı: record_round_finished bir kez, XP ile",
		main_src.count("record_round_finished(") == 1 and main_src.contains("record_round_finished(GameState.highest_tier_created, xp_award)"))
	_sections_done += 1


# --- Yardımcılar ---------------------------------------------------------------------

func _legacy(extra: Dictionary) -> Dictionary:
	var out: Dictionary = LEGACY_BASE.duplicate(true)
	out["last_login_date"] = Time.get_date_string_from_system()
	for key in extra:
		out[key] = extra[key]
	return out


func _level(number: int) -> LevelData:
	for level in LevelLibrary.load_levels():
		if level.level_number == number:
			return level
	return null


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _script_files(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for sub in dir.get_directories():
		out.append_array(_script_files(root.path_join(sub)))
	for file_name in dir.get_files():
		if file_name.ends_with(".gd"):
			out.append(root.path_join(file_name))
	return out


## Yorum satırları / satır sonu yorumları çıkarılır (yalnız kod taranır).
func _strip_comments(src: String) -> String:
	var out: PackedStringArray = []
	for line in src.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		var cut: int = line.find(" # ")
		out.append(line.substr(0, cut) if cut >= 0 else line)
	return "\n".join(out)


func _write_save(content: Dictionary) -> void:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(content, "\t"))
	file.close()


func _delete_save() -> void:
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))


func _bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) if FileAccess.file_exists(SaveManager.SAVE_PATH) \
		else PackedByteArray()


func _read_save_file() -> Dictionary:
	if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	return parsed if parsed is Dictionary else {}


func _restore_save_file() -> void:
	SaveManager.data = _saved.duplicate(true)
	if not _had_save:
		_delete_save()
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()
