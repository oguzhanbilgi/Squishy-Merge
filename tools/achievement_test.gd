extends Node
## TASK/045 — başarımlar + unvanlar testi. Headless; kayıt dosyasını byte-identical
## geri koyar.
##
##   godot --headless --audio-driver Dummy --path . res://tools/achievement_test.tscn
##
## Kontroller:
##   katalog     tam 12 başarım, kilitli id / ad / açıklama / metrik / hedef; tam 9
##               unvan (varsayılan + 8), unvan ↔ başarım eşlemesi brief'le birebir.
##   eşik        12 başarımın HER BİRİ için hedefin bir altı (kapalı), tam hedef
##               (açık), hedefin üstü (açık) — kanonik istatistikten.
##   monoton     açılan başarım istatistik düşse / kayıt bozulsa da KİLİTLENMEZ;
##               yeniden değerlendirme idempotent (ikinci çağrı boş).
##   kayıt       biçimsiz liste (dizi değil / sayı / null / boş öğe), tekrar, bilinmeyen
##               id güvenle süzülür; bilinmeyen id sayılmaz, unvan açmaz, sonraki
##               kayıtta düşer; ham liste tavanı.
##   geriye dönük  eski (TASK/045 öncesi) kayıt: gerçeklerin desteklediği başarımlar ve
##               unvanları SESSİZCE açılır (sinyal yok, disk yazması yok), unvan
##               varsayılan kalır; uydurma koleksiyon / yıldız yok.
##   canlı yollar  merge (add_merges) · yıldız (record_stars) · level (complete_level)
##               · koleksiyon: Mağaza satın alma, sandık (grant_skin / ChestSystem),
##               günlük ücretsiz sandık, reklamlı günlük sandık — başarım AYNI yazmada
##               dosyada; ekonomi (Hamur, fiyat) aynen; başarım Hamur / güç vermez.
##   unvan       varsayılan her zaman açık; kilitli / bilinmeyen reddedilir (yazma yok);
##               açık kabul (TEK yazma, kalıcı); aynı unvan yazma yok; yeni açılan
##               unvan otomatik seçilmez; bozuk seçim varsayılana düşer ve kayda geri
##               yazılmaz; kaynak başarımı kaybolan seçim (bozuk kayıt) varsayılana düşer.

const SECTIONS: int = 7
const LEGACY_BASE: Dictionary = {
	"highest_level_unlocked": 4,
	"level_stars": {"1": 3, "2": 2, "3": 1},
	"endless_high_score": 0,
	"dough": 900,
	"total_merges": 540,
	"merges_since_bonus_chest": 15,
	"powerups": {"bomb": 1, "upgrade": 1, "shake": 1, "clear_small": 1},
	"powerup_starter_granted": true,
	"onboarding_completed": true,
	"age_ad_band": "ADULT",
}
## Brief §9 — kilitli katalog (id, ad, açıklama, metrik, hedef, unvan).
const EXPECTED: Array = [
	["first_merge", "İlk Squish", "İlk birleşmeni yap.", "merges", 1, ""],
	["merge_100", "Hamur Isınıyor", "Toplam 100 birleşme yap.", "merges", 100, "hamur_ustasi"],
	["merge_500", "Birleşme Ustası", "Toplam 500 birleşme yap.", "merges", 500, "birlesme_ustasi"],
	["merge_1000", "Bin Bir Squish", "Toplam 1000 birleşme yap.", "merges", 1000, "efsane_birlestirici"],
	["stars_5", "İlk Parıltılar", "Toplam 5 yıldız kazan.", "stars", 5, ""],
	["stars_15", "Yıldız Avcısı", "Toplam 15 yıldız kazan.", "stars", 15, "yildiz_avcisi"],
	["stars_30", "Gökyüzü Tamam", "30 yıldızın tamamını kazan.", "stars", 30, "yildiz_ustasi"],
	["levels_3", "Yolculuk Başlıyor", "3 bölümü tamamla.", "levels", 3, ""],
	["levels_10", "Harita Ustası", "10 bölümün tamamını tamamla.", "levels", 10, "harita_ustasi"],
	["collection_5", "İlk Raf", "5 Squishy keşfet.", "collection", 5, ""],
	["collection_10", "Koleksiyoncu", "10 Squishy keşfet.", "collection", 10, "koleksiyoncu"],
	["collection_20", "Squishy Arşivcisi", "20 Squishy'nin tamamını keşfet.", "collection", 20, "squishy_arsivcisi"],
]
const EXPECTED_TITLES: Array = [
	["birlestirici", "Birleştirici"], ["hamur_ustasi", "Hamur Ustası"], ["birlesme_ustasi", "Birleşme Ustası"],
	["efsane_birlestirici", "Efsane Birleştirici"], ["yildiz_avcisi", "Yıldız Avcısı"],
	["yildiz_ustasi", "Yıldız Ustası"], ["harita_ustasi", "Harita Ustası"], ["koleksiyoncu", "Koleksiyoncu"],
	["squishy_arsivcisi", "Squishy Arşivcisi"],
]

var _fails: int = 0
var _checks: int = 0
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _saved: Dictionary = {}
var _finished: bool = false
var _sections_done: int = 0
var _meta_signals: int = 0


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
	SaveManager.player_meta_changed.connect(func() -> void: _meta_signals += 1)

	_catalog()
	_thresholds()
	_monotonic()
	_malformed()
	_retroactive()
	_live_paths()
	_titles()
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


# --- Katalog -----------------------------------------------------------------------

func _catalog() -> void:
	print("-- katalog")
	_c("tam 12 başarım", AchievementCatalog.count() == 12 and AchievementCatalog.ids().size() == 12)
	var mismatches: Array[String] = []
	for i in EXPECTED.size():
		var row: Array = EXPECTED[i]
		var entry: Dictionary = AchievementCatalog.ACHIEVEMENTS[i]
		if String(entry["id"]) != row[0] or String(entry["name"]) != row[1] or String(entry["description"]) != row[2] \
				or String(entry["metric"]) != row[3] or int(entry["target"]) != row[4] \
				or String(AchievementCatalog.title_for_achievement(entry["id"])) != row[5]:
			mismatches.append(row[0])
	_c("12 giriş brief'le birebir (sıra, id, ad, açıklama, metrik, hedef, unvan ödülü) %s" % str(mismatches),
		mismatches.is_empty())
	var title_mismatch: Array[String] = []
	for i in EXPECTED_TITLES.size():
		var entry: Dictionary = AchievementCatalog.TITLES[i]
		if String(entry["id"]) != EXPECTED_TITLES[i][0] or String(entry["name"]) != EXPECTED_TITLES[i][1]:
			title_mismatch.append(EXPECTED_TITLES[i][0])
	_c("9 unvan (varsayılan Birleştirici + 8), id / ad / sıra birebir %s" % str(title_mismatch),
		AchievementCatalog.TITLES.size() == 9 and title_mismatch.is_empty()
		and AchievementCatalog.DEFAULT_TITLE == &"birlestirici")
	var sources_ok: bool = true
	for entry in AchievementCatalog.TITLES:
		var source: StringName = entry["achievement"]
		if entry["id"] == AchievementCatalog.DEFAULT_TITLE:
			sources_ok = sources_ok and source == &""
		else:
			sources_ok = sources_ok and AchievementCatalog.is_known(source) \
				and AchievementCatalog.title_for_achievement(source) == entry["id"]
	_c("her unvanın TEK kaynak başarımı var (varsayılanın yok); başarım → unvan eşlemesi tutarlı", sources_ok)
	var unique_ids: Dictionary = {}
	for id in AchievementCatalog.ids():
		unique_ids[id] = true
	_c("başarım id'leri tekrarsız; ödül yalnız unvan (katalogda Hamur / güç / sandık / reklam alanı yok)",
		unique_ids.size() == 12 and not _catalog_has_economy_fields())
	_sections_done += 1


func _catalog_has_economy_fields() -> bool:
	for entry in AchievementCatalog.ACHIEVEMENTS:
		for key in entry:
			if String(key) in ["dough", "reward", "powerup", "chest", "coins", "ad", "gems"]:
				return true
	return false


# --- Eşikler -----------------------------------------------------------------------

func _thresholds() -> void:
	print("-- eşikler (12 başarım × altı / tam / üstü)")
	var failures: Array[String] = []
	for entry in AchievementCatalog.ACHIEVEMENTS:
		var id: StringName = entry["id"]
		var metric: StringName = entry["metric"]
		var goal: int = int(entry["target"])
		for probe in [[goal - 1, false], [goal, true], [goal + 1, true]]:
			var stats: Dictionary = _stats({metric: probe[0]})
			if AchievementCatalog.is_satisfied(id, stats) != probe[1] \
					or AchievementCatalog.newly_satisfied(stats, []).has(id) != probe[1]:
				failures.append("%s@%d" % [id, probe[0]])
	_c("saf değerlendirme: hedefin bir altı kapalı, tam hedef ve üstü açık %s" % str(failures), failures.is_empty())

	# Aynı üç nokta, gerçek kayıt + kanonik istatistik üzerinden.
	var save_failures: Array[String] = []
	for entry in AchievementCatalog.ACHIEVEMENTS:
		var id: StringName = entry["id"]
		var goal: int = int(entry["target"])
		for probe in [[goal - 1, false], [goal, true], [goal + 1, true]]:
			_fresh()
			_set_metric(entry["metric"], probe[0])
			SaveManager.reconcile_achievements()
			if SaveManager.is_achievement_unlocked(id) != probe[1]:
				save_failures.append("%s@%d" % [id, probe[0]])
	_c("kanonik kayıt: 12 × (altı / tam / üstü) — merge, yıldız (10 level), tamamlanan level, katalog Squishy %s"
		% str(save_failures), save_failures.is_empty())
	_fresh()
	SaveManager.data["level_stars"] = {"1": 3, "2": 3, "3": 3, "4": 3, "5": 3, "6": 9, "99": 3, "7": -4}
	_c("yıldız toplamı kanonik: bozuk değerler kırpılır (9 → 3), olmayan level sayılmaz → 18",
		int(SaveManager.progression_stats()[AchievementCatalog.METRIC_STARS]) == 18)
	SaveManager.data["unlocked_skins"] = ["zzz_1", "zzz_2", "zzz_3", "zzz_4", "zzz_5", "common_01"]
	_c("koleksiyon kanonik: katalogda olmayan id'ler sayılmaz (6 kayıt → 1)",
		int(SaveManager.progression_stats()[AchievementCatalog.METRIC_COLLECTION]) == 1)
	_sections_done += 1


# --- Monoton -----------------------------------------------------------------------

func _monotonic() -> void:
	print("-- monoton / kilitlenmez")
	_fresh()
	SaveManager.data["total_merges"] = 150
	var first: Array[StringName] = SaveManager.reconcile_achievements()
	_c("150 merge: first_merge + merge_100 açıldı (katalog sırası)", first == [&"first_merge", &"merge_100"])
	_c("yeniden değerlendirme idempotent: ikinci çağrı boş, liste aynı", SaveManager.reconcile_achievements().is_empty()
		and SaveManager.unlocked_achievements() == [&"first_merge", &"merge_100"])
	SaveManager.data["total_merges"] = 0
	SaveManager.reconcile_achievements()
	_c("istatistik düşse de (merge 0) açılan başarımlar KİLİTLENMEDİ", SaveManager.is_achievement_unlocked(&"merge_100")
		and SaveManager.unlocked_achievements().size() == 2)
	SaveManager.save_game()
	SaveManager.load_game()
	_c("yükleme sonrası da açık (kalıcı monoton liste)", SaveManager.is_achievement_unlocked(&"merge_100")
		and SaveManager.is_achievement_unlocked(&"first_merge"))
	SaveManager.data["total_merges"] = 600
	SaveManager.reconcile_achievements()
	_c("liste yalnız SONUNA eklenir (açılma sırası korunur)", SaveManager.unlocked_achievements()
		== [&"first_merge", &"merge_100", &"merge_500"])
	_sections_done += 1


# --- Biçimsiz liste ------------------------------------------------------------------

func _malformed() -> void:
	print("-- biçimsiz / tekrar / bilinmeyen")
	for bad: Variant in ["first_merge", 7, null, {"a": 1}]:
		_fresh()
		SaveManager.data["unlocked_achievements"] = bad
		_c("liste dizi değil (%s) → boş okunur, çökme yok" % str(bad), SaveManager.unlocked_achievements().is_empty())
	_fresh()
	SaveManager.data["unlocked_achievements"] = ["stars_5", "stars_5", "", 3, null, "merge_100", "zzz_future",
		&"levels_3", "merge_100", "FIRST_MERGE"]
	_c("tekrar / boş / sayı / null / bilinmeyen / büyük-küçük harf farkı süzüldü → stars_5, merge_100, levels_3",
		SaveManager.unlocked_achievements() == [&"stars_5", &"merge_100", &"levels_3"])
	_c("bilinmeyen id sayılmaz ve unvan açmaz (3 / 12)", PlayerProfile.achievements_unlocked_count() == 3
		and AchievementCatalog.unlocked_title_ids(SaveManager.unlocked_achievements()) == [&"birlestirici", &"hamur_ustasi"])
	_write_save(_legacy({"player_meta_version": 1, "player_xp": 10,
		"unlocked_achievements": ["zzz_future", "levels_3", "levels_3", 42]}))
	SaveManager.load_game()
	SaveManager.save_game()
	var written: Array = _read_save_file().get("unlocked_achievements", [])
	_c("bilinmeyen id / tekrar / sayı sonraki kayıtta düştü; geçerli + geriye dönük açılanlar kaldı %s" % str(written),
		not written.has("zzz_future") and written.count("levels_3") == 1 and not written.has(42.0)
		and written.has("levels_3"))
	_fresh()
	var huge: Array = []
	for i in 5000:
		huge.append("zzz_%d" % i)
	huge.append("first_merge")
	SaveManager.data["unlocked_achievements"] = huge
	# Ortalama süre (tek çağrı duvar saati yük altında oynar — lens 8). Tavansız okuma 5001
	# öğeyi her çağrıda tarardı; sınır cömert ama o maliyetin çok altında.
	var started: int = Time.get_ticks_usec()
	var read: Array[StringName] = []
	for i in 50:
		read = SaveManager.unlocked_achievements()
	var avg_ms: float = float(Time.get_ticks_usec() - started) / 50.0 / 1000.0
	_c("5001 öğelik bozuk liste: ham tavan (%d) sonrası okunmaz, hızlı (ort. %.2f ms)" % [SaveManager.ACHIEVEMENTS_RAW_CAP,
		avg_ms], read.is_empty() and avg_ms < 20.0)
	_sections_done += 1


# --- Geriye dönük (eski kayıt) -----------------------------------------------------------

func _retroactive() -> void:
	print("-- geriye dönük açılış (TASK/045 öncesi kayıt)")
	var owned: Array = []
	for skin in SkinLibrary.all():
		if owned.size() < 11:
			owned.append(String(skin.id))
	var stars: Dictionary = {}
	for n in range(1, 11):
		stars[str(n)] = 2 if n <= 8 else 0
	_write_save(_legacy({"total_merges": 1204, "level_stars": stars, "highest_level_unlocked": 11,
		"unlocked_skins": owned}))
	var bytes: PackedByteArray = _bytes()
	var signals_before: int = _meta_signals
	SaveManager.load_game()
	var got: Array[StringName] = SaveManager.unlocked_achievements()
	var expected: Array[StringName] = [&"first_merge", &"merge_100", &"merge_500", &"merge_1000", &"stars_5",
		&"stars_15", &"levels_3", &"levels_10", &"collection_5", &"collection_10"]
	_c("gerçekler (1204 merge · 16 yıldız · 10 level · 11 Squishy) → 10 başarım sessizce açıldı %s" % str(got), got == expected)
	_c("desteklenmeyenler kapalı: stars_30 (16/30), collection_20 (11/20)", not got.has(&"stars_30")
		and not got.has(&"collection_20"))
	_c("geriye dönük açılış SESSİZ: player_meta_changed yayılmadı, disk yazılmadı",
		_meta_signals == signals_before and _bytes() == bytes)
	_c("unvanlar açıldı (hamur / birleşme / efsane / yıldız avcısı / harita / koleksiyoncu) ama seçim varsayılan",
		AchievementCatalog.unlocked_title_ids(got) == [&"birlestirici", &"hamur_ustasi", &"birlesme_ustasi",
			&"efsane_birlestirici", &"yildiz_avcisi", &"harita_ustasi", &"koleksiyoncu"]
		and SaveManager.selected_title_id() == &"birlestirici")
	_c("uydurma yok: sahiplik 11, yıldız 16, merge 1204 aynen", PlayerProfile.collection_count() == 11
		and PlayerProfile.total_stars() == 16 and SaveManager.total_merges() == 1204)
	SaveManager.load_game()
	_c("idempotent: yeniden yükleme aynı liste, dosya aynı", SaveManager.unlocked_achievements() == expected and _bytes() == bytes)
	_write_save(_legacy({"total_merges": 0, "level_stars": {}, "highest_level_unlocked": 1, "unlocked_skins": []}))
	SaveManager.load_game()
	_c("oynanmamış eski kayıt: başarım yok, unvan varsayılan", SaveManager.unlocked_achievements().is_empty()
		and SaveManager.selected_title_id() == &"birlestirici")
	_sections_done += 1


# --- Canlı yollar ----------------------------------------------------------------------

func _live_paths() -> void:
	print("-- canlı yollar (aynı transaction'da açılış)")
	# Merge: add_merges.
	_fresh()
	SaveManager.data["total_merges"] = 99
	var signals: int = _meta_signals
	SaveManager.add_merges(1)
	_c("merge yolu: 99 + 1 → merge_100 açıldı, AYNI yazmada dosyada, sinyal 1",
		SaveManager.is_achievement_unlocked(&"merge_100") and _file_achievements().has("merge_100")
		and _meta_signals == signals + 1)
	# Yıldız: record_stars.
	_fresh()
	SaveManager.data["level_stars"] = {"1": 3, "2": 3, "3": 3, "4": 3, "5": 2}
	SaveManager.record_stars(5, 3)
	_c("yıldız yolu: 14 → 15 → stars_15 (ve stars_5) açıldı, dosyada", SaveManager.is_achievement_unlocked(&"stars_15")
		and _file_achievements().has("stars_15") and _file_achievements().has("stars_5"))
	SaveManager.record_stars(5, 3)
	_c("tekrar oynanış (aynı yıldız) yeni başarım üretmez", SaveManager.unlocked_achievements().size() == 2)
	# Level: complete_level.
	_fresh()
	SaveManager.data["highest_level_unlocked"] = 3
	SaveManager.complete_level(3)
	_c("level yolu: 3. level tamam → levels_3 açıldı, dosyada", SaveManager.is_achievement_unlocked(&"levels_3")
		and _file_achievements().has("levels_3"))
	SaveManager.complete_level(1)
	_c("eski level'ı yeniden bitirmek tamamlanan sayısını / başarımı değiştirmez",
		PlayerProfile.completed_levels() == 3 and SaveManager.unlocked_achievements() == [&"levels_3"])

	# Koleksiyon: dört edinme yolu.
	_fresh()
	var catalog: Array[SkinData] = SkinLibrary.all()
	SaveManager.data["dough"] = 5000
	for i in 4:
		SaveManager.grant_skin(catalog[i].id)
	_c("ön koşul: 4 Squishy, collection_5 kapalı", PlayerProfile.collection_count() == 4
		and not SaveManager.is_achievement_unlocked(&"collection_5"))
	var dough_before: int = SaveManager.dough()
	var bought: bool = Shop.purchase(catalog[4])
	_c("Mağaza satın alma: 5. Squishy → collection_5 AYNI transaction'da (dosyada); Hamur tam fiyat kadar düştü",
		bought and SaveManager.is_achievement_unlocked(&"collection_5") and _file_achievements().has("collection_5")
		and SaveManager.dough() == dough_before - Shop.price_of(catalog[4]))
	for i in range(5, 9):
		SaveManager.grant_skin(catalog[i].id)
	SaveManager.grant_skin(catalog[9].id)
	_c("sandık (grant_skin): 10. Squishy → collection_10 dosyada", SaveManager.is_achievement_unlocked(&"collection_10")
		and _file_achievements().has("collection_10"))
	for i in range(10, 18):
		SaveManager.grant_skin(catalog[i].id)
	var day: String = "2026-09-28"
	SaveManager.claim_daily_free_chest(day, 15, catalog[18].id)
	_c("günlük ücretsiz sandık: 19. Squishy, collection_20 hâlâ kapalı", PlayerProfile.collection_count() == 19
		and not SaveManager.is_achievement_unlocked(&"collection_20"))
	var dough_ad: int = SaveManager.dough()
	SaveManager.grant_daily_ad_chest(day, 15, catalog[19].id, DailyRewards.AD_CHESTS_PER_DAY)
	_c("reklamlı günlük sandık: 20. Squishy → collection_20 dosyada; sandık Hamuru aynen (+15)",
		SaveManager.is_achievement_unlocked(&"collection_20") and _file_achievements().has("collection_20")
		and SaveManager.dough() == dough_ad + 15)
	_c("başarım ödülü yok: Hamur / güç stoğu başarım yüzünden değişmedi (güç 1'er)",
		SaveManager.powerup_count(PowerUp.Type.BOMB) == 1 and SaveManager.powerup_count(PowerUp.Type.UPGRADE) == 1)

	# ChestSystem gerçek kurası: sahiplik değiştikçe başarım durumu tutarlı.
	_fresh()
	seed(4545)
	var consistent: bool = true
	for i in 120:
		ChestSystem.open()
		var count: int = PlayerProfile.collection_count()
		for id in [&"collection_5", &"collection_10", &"collection_20"]:
			if SaveManager.is_achievement_unlocked(id) != (count >= AchievementCatalog.target(id)):
				consistent = false
	_c("ChestSystem.open × 120 (seed): her sandıktan sonra koleksiyon başarımları sahiplikle tutarlı (%d Squishy)"
		% PlayerProfile.collection_count(), consistent and PlayerProfile.collection_count() >= 5)
	# DailyRewards gerçek yolu (onboarding tamam, yerleşik oyuncu). Kura TOHUMLU; Squishy
	# çıkaran ilk tohum kullanılır — parça yolu her koşuda sınanır (lens 8: tohumsuz kurada
	# yalnız ~%30 koşuda sınanıyordu, gerisi Hamur çıkıp kontrolü boşa geçiriyordu).
	var reward: DailyChestReward = null
	var rng := RandomNumberGenerator.new()
	for s in range(1, 80):
		_fresh()
		SaveManager.data["onboarding_completed"] = true
		SaveManager.data["onboarding_completed_day"] = ""
		for i in 4:
			SaveManager.grant_skin(catalog[i].id)
		rng.seed = s
		DailyRewards.set_rng(rng)
		reward = DailyRewards.claim_free_chest()
		if reward != null and reward.skin != null:
			break
	DailyRewards.set_rng(null)
	_c("DailyRewards.claim_free_chest (tohumlu, Squishy çıktı): 5. parça → collection_5 AYNI yazmada, dosyada",
		reward != null and reward.skin != null and PlayerProfile.collection_count() == 5
		and SaveManager.is_achievement_unlocked(&"collection_5") and _file_achievements().has("collection_5"))
	_sections_done += 1


# --- Unvanlar -----------------------------------------------------------------------------

func _titles() -> void:
	print("-- unvanlar")
	_fresh()
	SaveManager.save_game()
	_c("varsayılan Birleştirici her zaman açık ve seçili (başarım yokken)", SaveManager.selected_title_id() == &"birlestirici"
		and AchievementCatalog.is_title_unlocked(&"birlestirici", []) and PlayerProfile.selected_title_name() == "Birleştirici")
	var bytes: PackedByteArray = _bytes()
	var signals: int = _meta_signals
	_c("kilitli unvan reddedildi (LOCKED), yazma yok, sinyal yok", SaveManager.select_title(&"hamur_ustasi")
		== SaveManager.TitleResult.LOCKED and _bytes() == bytes and _meta_signals == signals
		and SaveManager.selected_title_id() == &"birlestirici")
	_c("bilinmeyen unvan reddedildi (UNKNOWN), yazma yok", SaveManager.select_title(&"kral") == SaveManager.TitleResult.UNKNOWN
		and SaveManager.select_title(&"") == SaveManager.TitleResult.UNKNOWN and _bytes() == bytes)
	_c("zaten seçili varsayılan: ALREADY, yazma yok", SaveManager.select_title(&"birlestirici")
		== SaveManager.TitleResult.ALREADY and _bytes() == bytes and _meta_signals == signals)
	SaveManager.data["total_merges"] = 120
	SaveManager.add_merges(0)
	SaveManager.reconcile_achievements()
	_c("merge_100 açıldı → Hamur Ustası açık ama OTOMATİK SEÇİLMEDİ", AchievementCatalog.is_title_unlocked(&"hamur_ustasi",
		SaveManager.unlocked_achievements()) and SaveManager.selected_title_id() == &"birlestirici")
	SaveManager.save_game()
	bytes = _bytes()
	signals = _meta_signals
	_c("açık unvan kabul (SELECTED): TEK yazma + tek sinyal", SaveManager.select_title(&"hamur_ustasi")
		== SaveManager.TitleResult.SELECTED and _bytes() != bytes and _meta_signals == signals + 1
		and String(_read_save_file().get("selected_title_id", "")) == "hamur_ustasi")
	bytes = _bytes()
	_c("aynı unvanı yeniden seçmek: ALREADY, gereksiz yazma yok", SaveManager.select_title(&"hamur_ustasi")
		== SaveManager.TitleResult.ALREADY and _bytes() == bytes and _meta_signals == signals + 1)
	SaveManager.load_game()
	_c("seçim yeniden yüklemede kalıcı (Hamur Ustası)", SaveManager.selected_title_id() == &"hamur_ustasi"
		and PlayerProfile.selected_title_name() == "Hamur Ustası")
	SaveManager.data["selected_title_id"] = "kral_squishy"
	_c("bozuk seçim (bilinmeyen) okumada varsayılana düşer", SaveManager.selected_title_id() == &"birlestirici")
	SaveManager.data["selected_title_id"] = 42
	_c("bozuk seçim (sayı) okumada varsayılana düşer", SaveManager.selected_title_id() == &"birlestirici")
	for bad: Variant in ["kral_squishy", 42, null, "yildiz_ustasi"]:
		_write_save(_legacy({"player_meta_version": 1, "player_xp": 10, "total_merges": 150,
			"unlocked_achievements": ["first_merge", "merge_100"], "selected_title_id": bad}))
		SaveManager.load_game()
		SaveManager.save_game()
		_c("kayıtta bozuk / kilitli seçim (%s) → yüklemede varsayılan, geçersiz unvan kayda GERİ YAZILMADI" % str(bad),
			SaveManager.selected_title_id() == &"birlestirici"
			and String(_read_save_file().get("selected_title_id", "")) == "birlestirici")
	_write_save(_legacy({"player_meta_version": 1, "player_xp": 10, "total_merges": 0, "level_stars": {},
		"unlocked_achievements": [], "selected_title_id": "efsane_birlestirici"}))
	SaveManager.load_game()
	_c("kaynak başarımı olmayan seçim (Efsane Birleştirici, 0 merge) → varsayılan", SaveManager.selected_title_id()
		== &"birlestirici")
	_write_save(_legacy({"player_meta_version": 1, "player_xp": 10, "total_merges": 1000,
		"unlocked_achievements": [], "selected_title_id": "efsane_birlestirici"}))
	SaveManager.load_game()
	_c("kaynak başarımı gerçeklerden geri gelen seçim korunur (1000 merge → Efsane Birleştirici)",
		SaveManager.selected_title_id() == &"efsane_birlestirici"
		and PlayerProfile.selected_title_name() == "Efsane Birleştirici")
	var rows: Array[Dictionary] = PlayerProfile.title_rows()
	_c("unvan satırları: 9, sıra katalogla aynı, tek seçili, kilitli olanlar kaynak başarımını taşır",
		rows.size() == 9 and rows[0]["id"] == &"birlestirici" and rows[3]["selected"] == true
		and _count_selected(rows) == 1 and rows[8]["unlocked"] == false and rows[8]["source_name"] == "Squishy Arşivcisi")
	_sections_done += 1


func _count_selected(rows: Array[Dictionary]) -> int:
	var n: int = 0
	for row in rows:
		if row["selected"]:
			n += 1
	return n


# --- Yardımcılar ----------------------------------------------------------------------

## Temiz bellek kaydı (disk: sonraki yazma). Başarım listesi / XP / unvan da sıfır.
func _fresh() -> void:
	SaveManager.data = SaveManager.DEFAULT_DATA.duplicate(true)
	SaveManager.data["powerups"] = {"bomb": 1, "upgrade": 1, "shake": 1, "clear_small": 1}
	SaveManager.data["powerup_starter_granted"] = true
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()


func _stats(overrides: Dictionary) -> Dictionary:
	var stats: Dictionary = {}
	for metric in AchievementCatalog.METRICS:
		stats[metric] = 0
	for key in overrides:
		stats[key] = int(overrides[key])
	return stats


## Kanonik kayıt alanlarını istenen metrik değerine getirir.
func _set_metric(metric: StringName, value: int) -> void:
	match metric:
		AchievementCatalog.METRIC_MERGES:
			SaveManager.data["total_merges"] = value
		AchievementCatalog.METRIC_STARS:
			var stars: Dictionary = {}
			var left: int = value
			for level in LevelLibrary.load_levels():
				var give: int = mini(left, 3)
				if give > 0:
					stars[str(level.level_number)] = give
				left -= give
			SaveManager.data["level_stars"] = stars
		AchievementCatalog.METRIC_LEVELS:
			SaveManager.data["highest_level_unlocked"] = value + 1
		AchievementCatalog.METRIC_COLLECTION:
			var owned: Array = []
			for skin in SkinLibrary.all():
				if owned.size() < value:
					owned.append(String(skin.id))
			SaveManager.data["unlocked_skins"] = owned


func _file_achievements() -> Array:
	return _read_save_file().get("unlocked_achievements", [])


func _legacy(extra: Dictionary) -> Dictionary:
	var out: Dictionary = LEGACY_BASE.duplicate(true)
	out["last_login_date"] = Time.get_date_string_from_system()
	for key in extra:
		out[key] = extra[key]
	return out


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
