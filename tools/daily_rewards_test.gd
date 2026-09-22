extends Node
## GÜNLÜK ÖDÜLLER deterministik testi (M8.9-02) — İNTERNET, CİHAZ, EKLENTİ YOK.
## Model (`DailyRewards`, gün anahtarı, üç ayrı kota), loot reçetesi
## (`DailyChestLoot`, seed'li RNG), kayıt transaction'ları (tek yazma),
## onboarding migration'ı, Mağaza kartı, GÜNLÜK ÖDÜLLER penceresi ve Main +
## sahte reklam arka ucu entegrasyonu (reklamlı sandık / Hamur ödülü yalnız
## "ödül kazanıldı" ile, iptal/hata/çift/eski gün ödül vermez, otomatik
## pencere günde bir kez, onboarding bastırması).
##
## KAYIT DOSYASINA YAZAR. Test başında yedekler, sonunda byte-identical geri
## koyar ve bunu kontrol eder.
##
## Kullanım:
##   godot --headless --audio-driver Dummy --path . res://tools/daily_rewards_test.tscn

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DAY_A: String = "2026-09-22"
const DAY_B: String = "2026-09-23"
const DAY_BEFORE: String = "2026-09-21"

var _fails: int = 0
var _checks: int = 0
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _events: Array[Dictionary] = []
var _main_script: GDScript = load("res://scripts/main.gd")


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
	AdEvents.subscribe(_on_event)

	_test_migration()
	_test_day_key()
	_test_quotas_and_transactions()
	_test_loot()
	await _test_shop_and_modal()
	await _test_main_integration()
	await _test_auto_popup_and_onboarding()

	AdEvents.unsubscribe(_on_event)
	DailyRewards.clock_override = ""
	DailyRewards.auto_popup_enabled = true
	DailyRewards.set_rng(null)
	MonetizationManager.time_scale = 1.0
	_restore_save_file()
	SaveManager.load_game()
	var restored: bool = not _had_save or FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == _save_bytes
	_c("kayıt dosyası test sonunda byte-identical geri kondu", restored)
	print("=== SONUC: %d/%d kontrol, %d kaldi ===" % [_checks - _fails, _checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _on_event(_name: StringName, event: Dictionary) -> void:
	_events.append(event)


func _events_named(name: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in _events:
		if e["name"] == name:
			out.append(e)
	return out


func _settle(frames: int = 2) -> void:
	for i in maxi(frames, 1):
		await get_tree().process_frame


## Bilinen bir noktadan: bellekte + diskte taze kayıt (onboarding tamam).
func _fresh_save(onboarding: bool = true, dough: int = 0) -> void:
	SaveManager.data = SaveManager.DEFAULT_DATA.duplicate(true)
	SaveManager.data["powerup_starter_granted"] = true
	SaveManager.data["dough"] = dough
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.data["onboarding_completed"] = onboarding
	SaveManager.save_game()


func _write_json(dict: Dictionary) -> void:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(dict, "\t"))
	file.close()


func _disk() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	return parsed if parsed is Dictionary else {}


# --- Onboarding migration ------------------------------------------------------------

func _test_migration() -> void:
	print("-- onboarding dikişi + eski kayıt migration'ı")
	# Dosyasız yeni oyuncu.
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	SaveManager.load_game()
	_c("yeni kayıt (dosya yok): onboarding_completed = false", not SaveManager.onboarding_completed())
	_c("yeni kayıt diske yazıldı ve anahtar false", FileAccess.file_exists(SaveManager.SAVE_PATH)
		and _disk().get("onboarding_completed", true) == false)
	# Eski kayıt (anahtar yok) + ilerleme kanıtı.
	_write_json({"highest_level_unlocked": 3, "dough": 50, "powerup_starter_granted": true})
	SaveManager.load_game()
	_c("eski kayıt + level ilerlemesi -> onboarding TAMAM (migration)", SaveManager.onboarding_completed())
	_c("migration okuma sırasında diske YAZMADI (anahtar hâlâ yok)", not _disk().has("onboarding_completed"))
	SaveManager.add_dough(1)
	_c("sonraki doğal kayıt anahtarı kalıcılaştırdı", _disk().get("onboarding_completed", false) == true)
	_write_json({"highest_level_unlocked": 1, "total_merges": 7, "powerup_starter_granted": true})
	SaveManager.load_game()
	_c("eski kayıt + total_merges > 0 -> tamam", SaveManager.onboarding_completed())
	_write_json({"highest_level_unlocked": 1, "unlocked_skins": ["common_01"], "powerup_starter_granted": true})
	SaveManager.load_game()
	_c("eski kayıt + açılmış skin -> tamam", SaveManager.onboarding_completed())
	_write_json({"highest_level_unlocked": 1, "endless_high_score": 120, "powerup_starter_granted": true})
	SaveManager.load_game()
	_c("eski kayıt + sonsuz rekoru -> tamam", SaveManager.onboarding_completed())
	_write_json({"highest_level_unlocked": 1, "level_stars": {"1": 2}, "powerup_starter_granted": true})
	SaveManager.load_game()
	_c("eski kayıt + yıldız -> tamam", SaveManager.onboarding_completed())
	# Eski kayıt, yalnız Hamur (günlük giriş) — kanıt DEĞİL.
	_write_json({"highest_level_unlocked": 1, "dough": 15, "last_login_date": "2026-09-01",
		"daily_streak": 1, "powerup_starter_granted": true})
	SaveManager.load_game()
	_c("eski kayıt, yalnız 15 Hamur + giriş tarihi (oynanmamış) -> onboarding false (Hamur kanıt değil)",
		not SaveManager.onboarding_completed())
	# Anahtar açıkça false ise migration DOKUNMAZ (ilerleme olsa da).
	_write_json({"highest_level_unlocked": 5, "onboarding_completed": false, "powerup_starter_granted": true})
	SaveManager.load_game()
	_c("anahtar açıkça false + ilerleme -> false kalır (kayıt otorite)", not SaveManager.onboarding_completed())
	SaveManager.complete_onboarding()
	_c("complete_onboarding -> true ve diske yazıldı (tek yazma)", SaveManager.onboarding_completed()
		and _disk().get("onboarding_completed", false) == true)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	SaveManager.complete_onboarding()
	_c("ikinci complete_onboarding yazmaz", FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == bytes)


# --- Gün anahtarı ------------------------------------------------------------------------

func _test_day_key() -> void:
	print("-- gün anahtarı / saat")
	_fresh_save()
	DailyRewards.clock_override = DAY_A
	_c("gün anahtarı yerel tarih (YYYY-MM-DD)", DailyRewards.day_key() == DAY_A and DailyRewards.today_local() == DAY_A)
	_c("görülen gün henüz kayıtta yok", SaveManager.daily_last_seen_day_key() == "")
	var key: String = DailyRewards.observe_day()
	_c("observe_day yeni günü kayda işledi", key == DAY_A and SaveManager.daily_last_seen_day_key() == DAY_A
		and _disk()["daily_rewards"]["last_seen_day_key"] == DAY_A)
	var st: Dictionary = DailyRewards.state()
	_c("taze gün: ücretsiz 1, reklamlı sandık 2, Hamur 1, toplam 4, bitmedi", st["free_chest_available"]
		and st["ad_chests_remaining"] == 2 and st["ad_dough_available"] and st["remaining_total"] == 4
		and not st["all_done"] and not st["clock_behind"])
	# Saat geriye: en yeni gün geçerli kalır.
	DailyRewards.clock_override = DAY_BEFORE
	_c("saat GERİ alındı -> gün anahtarı en yeni görülen gün (yeni ödül yok)", DailyRewards.day_key() == DAY_A
		and DailyRewards.is_clock_behind() and DailyRewards.state()["clock_behind"])
	DailyRewards.observe_day()
	_c("geri saat görülen günü DEĞİŞTİRMEZ (yalnız ileri)", SaveManager.daily_last_seen_day_key() == DAY_A)
	# Aynı gün: kota kalıcı.
	DailyRewards.clock_override = DAY_A
	var reward: DailyChestReward = DailyRewards.claim_free_chest()
	_c("ücretsiz sandık alındı", reward != null and not DailyRewards.free_chest_available())
	DailyRewards.clock_override = DAY_BEFORE
	_c("geri saatte ücretsiz sandık hâlâ alınmış (aynı efektif gün)", not DailyRewards.free_chest_available())
	SaveManager.load_game()
	DailyRewards.clock_override = DAY_A
	_c("aynı gün yeniden açılış: kota diskten aynı", not DailyRewards.free_chest_available()
		and DailyRewards.ad_chests_remaining() == 2)
	# İleri gün: sayaçlar yazmadan sıfır görünür, observe yeni günü işler.
	DailyRewards.clock_override = DAY_B
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_c("gün değişti: durum sıfır (okuma), diske yazılmadı", DailyRewards.free_chest_available()
		and DailyRewards.state()["remaining_total"] == 4 and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == bytes)
	DailyRewards.observe_day()
	_c("observe_day ileri günü işledi", SaveManager.daily_last_seen_day_key() == DAY_B)
	DailyRewards.clock_override = DAY_A
	_c("sonra geri gidince B geçerli kalır (tarih yetişene kadar)", DailyRewards.day_key() == DAY_B)
	DailyRewards.clock_override = DAY_B


# --- Kotalar / transaction'lar --------------------------------------------------------------

func _test_quotas_and_transactions() -> void:
	print("-- üç ayrı kota + tek transaction + bağımsızlık")
	_fresh_save(true, 100)
	DailyRewards.clock_override = DAY_A
	DailyRewards.observe_day()
	_events.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	DailyRewards.set_rng(rng)

	# Ücretsiz sandık.
	var dough_before: int = SaveManager.dough()
	var r1: DailyChestReward = DailyRewards.claim_free_chest()
	_c("ücretsiz sandık: ödül nesnesi, kaynak free, gün A", r1 != null and r1.source == "free" and r1.day_key == DAY_A)
	_c("Hamur >= 15 eklendi, kota tüketildi", SaveManager.dough() >= dough_before + 15 and not DailyRewards.free_chest_available()
		and SaveManager.dough() == dough_before + r1.dough())
	var disk: Dictionary = _disk()
	_c("tek yazma: diskte Hamur VE kota birlikte", int(disk["dough"]) == SaveManager.dough()
		and disk["daily_rewards"]["free_chest_claimed"] == true and disk["daily_rewards"]["day_key"] == DAY_A)
	_c("ikinci ücretsiz sandık BLOKE (null), kayıt değişmedi", DailyRewards.claim_free_chest() == null
		and SaveManager.dough() == dough_before + r1.dough())
	_c("olaylar: daily_free_chest_claimed + daily_chest_result", _events_named(&"daily_free_chest_claimed").size() == 1
		and _events_named(&"daily_chest_result").size() == 1 and _events_named(&"daily_chest_result")[0]["source"] == "free")

	# Reklamlı sandık ×2, üçüncü bloke, eski gün bloke.
	var before2: int = SaveManager.dough()
	var a1: DailyChestReward = DailyRewards.grant_ad_chest(DAY_A)
	var a2: DailyChestReward = DailyRewards.grant_ad_chest(DAY_A)
	_c("reklamlı sandık 2 başarılı (2 -> 0 kaldı), her biri >= 15 Hamur", a1 != null and a2 != null
		and a1.source == "ad" and DailyRewards.ad_chests_remaining() == 0
		and SaveManager.dough() == before2 + a1.dough() + a2.dough())
	_c("üçüncü reklamlı sandık BLOKE", DailyRewards.grant_ad_chest(DAY_A) == null
		and SaveManager.dough() == before2 + a1.dough() + a2.dough())
	_c("ücretsiz sandık kotası reklamlı sandıktan etkilenmedi (ayrı aile)", not DailyRewards.free_chest_available())
	_c("olay: daily_ad_chest_earned ×2 (remaining 1, 0)", _events_named(&"daily_ad_chest_earned").size() == 2
		and _events_named(&"daily_ad_chest_earned")[0]["remaining"] == 1 and _events_named(&"daily_ad_chest_earned")[1]["remaining"] == 0)

	# +150 Hamur.
	var before3: int = SaveManager.dough()
	_c("reklamlı +150: ilk başarı tam 150", DailyRewards.grant_ad_dough(DAY_A) and SaveManager.dough() == before3 + 150
		and not DailyRewards.ad_dough_available())
	_c("ikinci +150 BLOKE, Hamur değişmedi", not DailyRewards.grant_ad_dough(DAY_A) and SaveManager.dough() == before3 + 150)
	DailyRewards.clock_override = DAY_B
	DailyRewards.observe_day()
	var before4: int = SaveManager.dough()
	_c("gün B: A gününün geç sandık callback'i -> null, Hamur yok", DailyRewards.grant_ad_chest(DAY_A) == null
		and not DailyRewards.grant_ad_dough(DAY_A) and SaveManager.dough() == before4)
	_c("gün B: kotalar yenilendi (1 / 2 / 1)", DailyRewards.free_chest_available() and DailyRewards.ad_chests_remaining() == 2
		and DailyRewards.ad_dough_available())
	_c("bütün gün B durumu all_done değil; A'da bittiydi", not DailyRewards.state()["all_done"])
	DailyRewards.clock_override = DAY_A

	# Bağımsızlık: refill kotası ve devam hakları.
	DailyRewards.clock_override = DAY_B
	_c("ön koşul: ödüllü güç refill kotası 1/1", RewardedPolicy.remaining_today() == 1)
	DailyRewards.grant_ad_chest(DAY_B)
	DailyRewards.grant_ad_dough(DAY_B)
	DailyRewards.claim_free_chest()
	_c("günlük ödüller refill kotasını TÜKETMEDİ", RewardedPolicy.remaining_today() == 1)
	_c("refill grant günlük kotaları TÜKETMEDİ", RewardedPolicy.grant(PowerUp.Type.BOMB) and RewardedPolicy.remaining_today() == 0
		and DailyRewards.ad_chests_remaining() == 1 and not DailyRewards.ad_dough_available() and not DailyRewards.free_chest_available())
	_c("günlük kota anahtarları kayıtta bağımsız alanlar", _disk()["daily_rewards"]["ad_chests_claimed"] == 1
		and _disk()["rewarded_power_grants"] == 1)
	# Popup işareti ödül tüketmez.
	var st_before: Dictionary = DailyRewards.state()
	DailyRewards.mark_popup_seen()
	var st_after: Dictionary = DailyRewards.state()
	_c("popup_seen_day işareti hiçbir kotayı değiştirmez", SaveManager.daily_popup_seen_day() == DAY_B
		and st_before["remaining_total"] == st_after["remaining_total"] and not DailyRewards.popup_due())
	DailyRewards.set_rng(null)


# --- Loot ---------------------------------------------------------------------------------

func _test_loot() -> void:
	print("-- günlük sandık loot reçetesi (seed'li RNG)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var owned: Array = ["common_01", "rare_01"]
	var n: int = 4000
	var skin_hits: int = 0
	var min_dough: int = 999
	var rarity_seen: Dictionary = {}
	var only_unowned: bool = true
	var no_skin_dough_ok: bool = true
	var skin_dough_ok: bool = true
	var valid_ids: bool = true
	for i in n:
		var r: DailyChestReward = DailyChestLoot.roll(rng, owned)
		min_dough = mini(min_dough, r.dough())
		if r.skin_rolled:
			skin_hits += 1
			rarity_seen[r.rarity] = int(rarity_seen.get(r.rarity, 0)) + 1
			if r.skin != null:
				only_unowned = only_unowned and not owned.has(String(r.skin.id)) and r.skin.rarity == r.rarity
				valid_ids = valid_ids and SkinLibrary.find(r.skin.id) != null and String(r.skin.id) != ""
				skin_dough_ok = skin_dough_ok and r.dough() == 15 and r.bonus_dough == 0
			else:
				# Bu sahiplikte hiçbir rarity tükenmiş değil.
				skin_dough_ok = false
		else:
			no_skin_dough_ok = no_skin_dough_ok and r.dough() == 15 and r.rarity == -1 and r.skin == null
	var share: float = float(skin_hits) / float(n)
	_c("her sandık >= 15 Hamur (min %d)" % min_dough, min_dough >= 15)
	_c("skin kurası ~%%30 (ölçülen %.1f%%)" % (share * 100.0), share > 0.26 and share < 0.34)
	_c("skin yok dalı: tam +15, rarity yok", no_skin_dough_ok)
	_c("skin dalı: +15 Hamur + skin (bonus yok), dört rarity de görüldü", skin_dough_ok
		and rarity_seen.has(0) and rarity_seen.has(1) and rarity_seen.has(2) and rarity_seen.has(3))
	var c: float = float(rarity_seen.get(0, 0)) / float(maxi(skin_hits, 1))
	var l: float = float(rarity_seen.get(3, 0)) / float(maxi(skin_hits, 1))
	_c("rarity dağılımı kilitli eşikler (Common ~%%60: %.1f%%, Legendary ~%%3: %.1f%%)" % [c * 100.0, l * 100.0],
		c > 0.54 and c < 0.66 and l > 0.01 and l < 0.06)
	_c("yalnız sahip OLUNMAYAN, aynı rarity'de, katalogda olan skin verildi", only_unowned and valid_ids)
	_c("Varsayılan (boş id) hiçbir zaman verilmez (havuz yalnız 20 koleksiyon skini)",
		valid_ids and SkinLibrary.total_count() == 20 and SkinLibrary.find(&"") == null)
	# Tükenmiş rarity: hepsine sahip -> kura tutunca +30.
	var all_ids: Array = []
	for skin in SkinLibrary.all():
		all_ids.append(String(skin.id))
	var exhausted_hits: int = 0
	var exhausted_ok: bool = true
	rng.seed = 99
	for i in 500:
		var r: DailyChestReward = DailyChestLoot.roll(rng, all_ids)
		if r.skin_rolled:
			exhausted_hits += 1
			exhausted_ok = exhausted_ok and r.skin == null and r.skin_exhausted and r.dough() == 30 \
				and r.base_dough == 15 and r.bonus_dough == 15 and r.rarity >= 0
		else:
			exhausted_ok = exhausted_ok and r.dough() == 15
	_c("tükenmiş rarity: skin yerine +15 bonus = +30 toplam (%d kez), skin YOK" % exhausted_hits, exhausted_hits > 100 and exhausted_ok)
	# Yalnız Legendary tükenmiş: Legendary kurası +30, diğerleri skin.
	var leg_owned: Array = ["legendary_01", "legendary_02"]
	rng.seed = 2024
	var leg_fallback: int = 0
	var leg_ok: bool = true
	for i in 3000:
		var r: DailyChestReward = DailyChestLoot.roll(rng, leg_owned)
		if r.skin_rolled and r.rarity == int(SkinData.Rarity.LEGENDARY):
			leg_fallback += 1
			leg_ok = leg_ok and r.skin == null and r.dough() == 30
		elif r.skin_rolled:
			leg_ok = leg_ok and r.skin != null and r.dough() == 15
	_c("yalnız Legendary tükenmiş: Legendary kurası +30, diğer rarity'ler skin (%d geri düşüş)" % leg_fallback,
		leg_fallback > 0 and leg_ok)
	# Determinizm: aynı seed aynı dizi.
	var s1 := RandomNumberGenerator.new()
	var s2 := RandomNumberGenerator.new()
	s1.seed = 5
	s2.seed = 5
	var same: bool = true
	for i in 200:
		var a: DailyChestReward = DailyChestLoot.roll(s1, owned)
		var b: DailyChestReward = DailyChestLoot.roll(s2, owned)
		same = same and a.dough() == b.dough() and a.rarity == b.rarity \
			and ((a.skin == null and b.skin == null) or (a.skin != null and b.skin != null and a.skin.id == b.skin.id))
	_c("aynı seed -> aynı ödül dizisi (deterministik)", same)
	_c("reçete sabitleri: 15 garanti, %30 skin, +15 bonus", DailyChestLoot.GUARANTEED_DOUGH == 15
		and DailyChestLoot.SKIN_CHANCE_PERCENT == 30 and DailyChestLoot.EXHAUSTED_BONUS_DOUGH == 15
		and DailyRewards.AD_DOUGH_AMOUNT == 150 and DailyRewards.AD_CHESTS_PER_DAY == 2
		and DailyRewards.FREE_CHESTS_PER_DAY == 1 and DailyRewards.AD_DOUGH_PER_DAY == 1)
	_c("level sonu sandık reçetesi DEĞİŞMEDİ (%%30 skin / 60-85-97-100, 10/25/60/150, teselli 5)",
		ChestSystem.SKIN_REWARD_PERCENT == 30 and ChestSystem.RARITY_THRESHOLDS == [60, 85, 97, 100]
		and ChestSystem.RARITY_DOUGH == [10, 25, 60, 150] and ChestSystem.CONSOLATION_DOUGH == 5
		and ChestSystem.MERGES_PER_BONUS_CHEST == 75)
	var src: String = FileAccess.get_file_as_string("res://scripts/game/chest_system.gd")
	_c("chest_system.gd günlük reçeteyi bilmez (paylaşılan kod yok)", not src.contains("Daily"))


# --- Mağaza kartı + pencere -----------------------------------------------------------------

func _test_shop_and_modal() -> void:
	print("-- Mağaza günlük kartı + GÜNLÜK ÖDÜLLER penceresi (sağlayıcısız)")
	_fresh_save(true, 200)
	DailyRewards.clock_override = DAY_A
	DailyRewards.observe_day()
	DailyRewards.auto_popup_enabled = false
	get_window().size = Vector2i(720, 1280)
	_main_script.ads_backend_override = null
	var main: Node2D = MAIN_SCENE.instantiate()
	add_child(main)
	await _settle(3)
	main._daily.visible = false
	var shop: CanvasLayer = main._screens[3]
	main._show_tab(3)
	await _settle(2)
	_c("Mağaza: GÜNLÜK ÖDÜLLER bölümü + kart görünür, durum HAZIR, üç bölüm plakası",
		shop.daily_card().visible and shop.daily_status_text() == shop.DAILY_STATUS_READY
		and shop.section_headers().size() == 3
		and (shop.section_headers()[0].get_meta(&"title_label") as Label).text == "GÜNLÜK ÖDÜLLER")
	_c("kart en üstte, güç kartlarının üstünde", shop.daily_card().get_global_rect().end.y
		<= shop.power_cards()[0].get_global_rect().position.y)
	var popup: CanvasLayer = main._daily_rewards
	shop.daily_button().pressed.emit()
	await _settle(2)
	_c("AÇ -> pencere açıldı (Mağaza kartı aynı pencere)", popup.visible and not popup.is_revealing())
	_c("sağlayıcısız: ücretsiz AÇ aktif; reklamlı butonlar PASİF + 'henüz bağlı değil'; rozetler HAZIR / REKLAM HAZIRLANIYOR / 2 / 2 (kalan hak görünür)",
		not popup.free_button().disabled and popup.dough_button().disabled and popup.chest_button().disabled
		and popup.free_status_text() == popup.STATUS_READY and popup.dough_status_text() == popup.STATUS_PREPARING
		and popup.chest_status_text() == "2 / 2" and popup.dough_note_text() == popup.NOTE_NO_PROVIDER
		and popup.chest_note_text() == popup.NOTE_NO_PROVIDER)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	popup.dough_button().pressed.emit()
	popup.chest_button().pressed.emit()
	await _settle(1)
	_c("pasif reklam butonları talep üretmez, kayıt değişmez", not popup.is_request_pending()
		and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == bytes)
	# Ücretsiz sandık: çift dokunuş tek transaction.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	DailyRewards.set_rng(rng)
	var dough_before: int = SaveManager.dough()
	popup.free_button().pressed.emit()
	popup.free_button().pressed.emit()
	await _settle(2)
	var gained: int = SaveManager.dough() - dough_before
	_c("AÇ (çift dokunuş) -> TEK transaction (+%d), kota tüketildi, reveal açık" % gained, (gained == 15 or gained == 30)
		and not DailyRewards.free_chest_available() and popup.is_revealing())
	_c("reveal: sandık görseli + '+N HAMUR' kayıtla aynı, DEVAM önce kilitli, X görünür",
		popup.gem() != null and popup.reveal_dough_text() == "+%d HAMUR" % gained
		and popup.continue_button().visible and popup.continue_button().disabled
		and popup.close_button() != null and not popup.close_button().visible)
	var disk: Dictionary = _disk()
	_c("ödül reveal'den ÖNCE diskte", int(disk["dough"]) == SaveManager.dough() and disk["daily_rewards"]["free_chest_claimed"] == true)
	await get_tree().create_timer(popup.REVEAL_CONTINUE_DELAY + 0.3).timeout
	await _settle(1)
	_c("~1,2 s sonra DEVAM açık (uzun kilitli dizi yok)", not popup.continue_button().disabled)
	var dough_after_reveal: int = SaveManager.dough()
	popup.continue_button().pressed.emit()
	await _settle(2)
	_c("DEVAM -> kartlara dönüş, ücretsiz ALINDI, ikinci kura YOK (Hamur aynı)", not popup.is_revealing()
		and popup.free_status_text() == popup.STATUS_CLAIMED and popup.free_button().disabled
		and SaveManager.dough() == dough_after_reveal)
	popup.free_button().pressed.emit()
	await _settle(1)
	_c("ALINDI durumunda AÇ hiçbir şey yapmaz", SaveManager.dough() == dough_after_reveal and not popup.is_revealing())
	popup.close_popup()
	await _settle(2)
	_c("KAPAT -> pencere kapandı, Mağaza kartı '3 ödül kaldı'", not popup.visible
		and shop.daily_status_text() == shop.DAILY_STATUS_LEFT % 3)
	# Bütün gün bitti -> kart BUGÜNLÜK TAMAMLANDI; pencerede BUGÜNLÜK BİTTİ / ALINDI.
	DailyRewards.grant_ad_chest(DAY_A)
	DailyRewards.grant_ad_chest(DAY_A)
	DailyRewards.grant_ad_dough(DAY_A)
	main._show_tab(3)
	await _settle(2)
	_c("hepsi alındı -> Mağaza kartı BUGÜNLÜK TAMAMLANDI", shop.daily_status_text() == shop.DAILY_STATUS_DONE)
	main.open_daily_rewards()
	await _settle(2)
	_c("pencere: ALINDI / ALINDI / BUGÜNLÜK BİTTİ, bütün butonlar pasif, KAPAT var", popup.visible
		and popup.free_status_text() == popup.STATUS_CLAIMED and popup.dough_status_text() == popup.STATUS_CLAIMED
		and popup.chest_status_text() == popup.STATUS_DONE and popup.free_button().disabled
		and popup.dough_button().disabled and popup.chest_button().disabled and popup.close_button().visible)
	# Android geri kapatır.
	main._last_back_msec = -100000
	main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(1)
	_c("Android geri -> pencere kapanır (ödül yok)", not popup.visible)
	# Saat geri alınmış notu.
	DailyRewards.clock_override = DAY_BEFORE
	main.open_daily_rewards()
	await _settle(1)
	_c("saat geride: pencerede açıklama notu, ödüller yenilenmedi", popup.note_text() == popup.NOTE_CLOCK_BEHIND
		and popup.free_status_text() == popup.STATUS_CLAIMED)
	popup.close_popup()
	DailyRewards.clock_override = DAY_A
	DailyRewards.set_rng(null)
	main.queue_free()
	await _settle(2)


# --- Main + sahte reklam arka ucu ---------------------------------------------------------

func _test_main_integration() -> void:
	print("-- Main + FakeAdBackend: reklamlı sandık / +150 Hamur yalnız 'ödül kazanıldı' ile")
	_fresh_save(true, 100)
	DailyRewards.clock_override = DAY_A
	DailyRewards.observe_day()
	DailyRewards.auto_popup_enabled = false
	_events.clear()
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	_main_script.ads_backend_override = fake
	var main: Node2D = MAIN_SCENE.instantiate()
	add_child(main)
	await _settle(3)
	_main_script.ads_backend_override = null
	main._daily.visible = false
	var m: MonetizationManager = main._ads
	m.set_process(false)
	fake.complete_consent_update(true)
	fake.complete_init()
	var popup: CanvasLayer = main._daily_rewards
	main.open_daily_rewards()
	await _settle(2)
	_c("pencere açık, reklam henüz yüklenmedi -> reklamlı butonlar pasif + 'hazırlanıyor'", popup.visible
		and popup.dough_button().disabled and popup.dough_note_text() == MonetizationManager.NOTE_PREPARING
		and popup.dough_status_text() == popup.STATUS_PREPARING)
	var ad1: String = fake.complete_rewarded_load(true)
	await _settle(1)
	_c("reklam yüklendi -> pencere tazelendi: REKLAM İZLE aktif, HAZIR / 2 / 2", not popup.dough_button().disabled
		and not popup.chest_button().disabled and popup.dough_status_text() == popup.STATUS_READY
		and popup.chest_status_text() == "2 / 2")

	# +150 Hamur: talep -> show -> earned -> +150; çift/geç ödül yok.
	var before: int = SaveManager.dough()
	popup.dough_button().pressed.emit()
	await _settle(2)
	var req: Dictionary = m.request_info()
	_c("+150 talebi: yönetici talebi daily_dough + gün anahtarı + Main token'ı, backend show 1",
		req["active"] and req["kind"] == MonetizationManager.RewardedKind.DAILY_DOUGH and req["day_key"] == DAY_A
		and req["token"] == main._daily_pending_token and fake.rewarded_shows == [ad1] and popup.is_request_pending())
	popup.dough_button().pressed.emit()
	popup.chest_button().pressed.emit()
	await _settle(1)
	_c("talep açıkken ikinci dokunuşlar (aynı ve diğer kart) yeni talep üretmez", fake.rewarded_shows.size() == 1
		and popup.chest_button().disabled)
	_c("olay: rewarded_requested placement=daily_dough + daily_dough_requested", _events_named(&"daily_dough_requested").size() == 1
		and _events_named(&"rewarded_requested")[-1]["placement"] == "daily_dough")
	_c("gösterim sırasında Hamur/kota değişmedi", SaveManager.dough() == before and DailyRewards.ad_dough_available())
	fake.emit_rewarded_showed(ad1)
	fake.emit_rewarded_earned(ad1)
	await _settle(2)
	_c("ödül -> +150 tam bir kez, kota tüketildi, pencere açık ve tazelendi (ALINDI)", SaveManager.dough() == before + 150
		and not DailyRewards.ad_dough_available() and popup.visible and popup.dough_status_text() == popup.STATUS_CLAIMED
		and not popup.is_request_pending())
	fake.emit_rewarded_earned(ad1)
	_c("çift ödül callback'i ikinci +150 VERMEZ", SaveManager.dough() == before + 150)
	fake.emit_rewarded_dismissed(ad1)
	await _settle(1)
	_c("kapanış -> sonraki reklam yükleniyor, olay daily_dough_earned 1", fake.rewarded_loads == 2
		and _events_named(&"daily_dough_earned").size() == 1)

	# Reklamlı sandık: earned -> sandık + reveal.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	DailyRewards.set_rng(rng)
	var ad2: String = fake.complete_rewarded_load(true)
	await _settle(1)
	before = SaveManager.dough()
	popup.chest_button().pressed.emit()
	await _settle(1)
	_c("reklamlı sandık talebi: kind daily_chest, show(ad2)", m.request_info()["kind"] == MonetizationManager.RewardedKind.DAILY_CHEST
		and fake.rewarded_shows == [ad1, ad2])
	fake.emit_rewarded_earned(ad2)
	await _settle(2)
	var gained: int = SaveManager.dough() - before
	_c("ödül -> sandık (+%d), kota 2 -> 1, reveal açık" % gained, (gained == 15 or gained == 30)
		and DailyRewards.ad_chests_remaining() == 1 and popup.is_revealing())
	fake.emit_rewarded_dismissed(ad2)
	await _settle(1)
	var ad3: String = fake.complete_rewarded_load(true)
	await get_tree().create_timer(popup.REVEAL_CONTINUE_DELAY + 0.3).timeout
	popup.continue_button().pressed.emit()
	await _settle(2)
	_c("DEVAM -> kartlar: sandık 1 / 2 (yeni reklam hazır), ikinci kura yok", popup.chest_status_text() == "1 / 2"
		and SaveManager.dough() == before + gained)

	# İptal: talep açıkken KAPAT -> geç ödül vermez, kota tüketmez.
	before = SaveManager.dough()
	popup.chest_button().pressed.emit()
	await _settle(1)
	popup.close_popup()
	await _settle(1)
	_c("KAPAT: yönetici talebi iptal, Main token'ı sıfır", m.request_info()["cancelled"] and main._daily_pending_token == 0)
	fake.emit_rewarded_earned(ad3)
	fake.emit_rewarded_dismissed(ad3)
	await _settle(1)
	_c("iptalden sonra gelen ödül sandık VERMEZ, kota 1 kaldı", SaveManager.dough() == before and DailyRewards.ad_chests_remaining() == 1)

	# Gösterim hatası: not, kota yok.
	var ad4: String = fake.complete_rewarded_load(true)
	await _settle(1)
	main.open_daily_rewards()
	await _settle(2)
	popup.chest_button().pressed.emit()
	await _settle(1)
	fake.emit_rewarded_show_failed(ad4)
	await _settle(2)
	_c("gösterim hatası -> 'gösterilemedi' notu, kota 1, buton yeni reklamla açılır", popup.note_text() == MonetizationManager.NOTE_SHOW_FAILED
		and DailyRewards.ad_chests_remaining() == 1 and not popup.is_request_pending() and SaveManager.dough() == before)
	# Ödülsüz kapanış.
	var ad5: String = fake.complete_rewarded_load(true)
	await _settle(1)
	popup.dough_button().pressed.emit()
	await _settle(1)
	_c("kota dolu Hamur kartı talep üretmez (ALINDI)", fake.rewarded_shows.size() == 4 and not popup.is_request_pending())
	popup.chest_button().pressed.emit()
	await _settle(1)
	fake.emit_rewarded_dismissed(ad5)
	await _settle(2)
	_c("ödülsüz kapanış -> 'tamamını izle' notu, kota 1, Hamur aynı", popup.note_text() == MonetizationManager.NOTE_NOT_EARNED
		and DailyRewards.ad_chests_remaining() == 1 and SaveManager.dough() == before)
	# Eski güne ait geç ödül: talep A gününde, ödül B gününde.
	var ad6: String = fake.complete_rewarded_load(true)
	await _settle(1)
	popup.chest_button().pressed.emit()
	await _settle(1)
	DailyRewards.clock_override = DAY_B
	DailyRewards.observe_day()
	fake.emit_rewarded_earned(ad6)
	fake.emit_rewarded_dismissed(ad6)
	await _settle(2)
	_c("gün değişti (A -> B) sonra gelen A talebi ödülü: sandık YOK, B kotası 2/2 dokunulmadı, Hamur aynı",
		SaveManager.dough() == before and DailyRewards.ad_chests_remaining() == 2 and not popup.is_revealing())
	DailyRewards.clock_override = DAY_A
	# Kaynak kuralı: ödül yalnız kilitli yollardan.
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var popup_src: String = FileAccess.get_file_as_string("res://scripts/ui/daily_rewards_popup.gd")
	var shop_src: String = FileAccess.get_file_as_string("res://scripts/ui/shop_screen.gd")
	_c("pencere ve Mağaza kartı kayda yazmaz / ödül vermez (claim/grant çağrısı yok, save_game yok)",
		not popup_src.contains("save_game") and not popup_src.contains("claim_free_chest()")
		and not popup_src.contains("grant_ad_chest(") and not popup_src.contains("grant_ad_dough(")
		and not popup_src.contains("add_dough(") and not shop_src.contains("claim_free_chest()")
		and not shop_src.contains("grant_ad_chest(") and not shop_src.contains("grant_ad_dough("))
	_c("Main günlük ödülü yalnız DailyRewards transaction'larıyla verir", main_src.contains("DailyRewards.claim_free_chest()")
		and main_src.contains("DailyRewards.grant_ad_chest(") and main_src.contains("DailyRewards.grant_ad_dough(")
		and not main_src.contains("add_dough(150"))
	DailyRewards.set_rng(null)
	main.queue_free()
	await _settle(2)


# --- Otomatik pencere + onboarding -----------------------------------------------------------

func _test_auto_popup_and_onboarding() -> void:
	print("-- otomatik günlük pencere (günde bir) + onboarding bastırması")
	_fresh_save(true, 0)
	SaveManager.data["last_login_date"] = "2026-09-01"
	SaveManager.save_game()
	DailyRewards.clock_override = DAY_A
	DailyRewards.auto_popup_enabled = true
	_events.clear()
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	_main_script.ads_backend_override = fake
	var main: Node2D = MAIN_SCENE.instantiate()
	add_child(main)
	await _settle(3)
	_main_script.ads_backend_override = null
	var popup: CanvasLayer = main._daily_rewards
	_c("açılış: günlük giriş ödülü penceresi ÖNCE, GÜNLÜK ÖDÜLLER henüz değil", main._daily.visible and not popup.visible
		and DailyRewards.popup_due())
	main._daily.close_popup()
	await _settle(2)
	_c("giriş ödülü kapandı -> GÜNLÜK ÖDÜLLER otomatik açıldı (auto), bugün görüldü işaretlendi", popup.visible
		and popup.is_auto_opened() and SaveManager.daily_popup_seen_day() == DAY_A and not DailyRewards.popup_due())
	_c("olay: daily_popup_shown auto=true", _events_named(&"daily_popup_shown").size() == 1
		and _events_named(&"daily_popup_shown")[0]["auto"] == true)
	var st: Dictionary = DailyRewards.state()
	popup.close_popup()
	await _settle(2)
	_c("kapatmak hiçbir ödül tüketmez (4 ödül duruyor), olay daily_popup_closed", DailyRewards.state()["remaining_total"] == 4
		and st["remaining_total"] == 4 and _events_named(&"daily_popup_closed").size() == 1)
	main._show_tab(3)
	main._show_tab(0)
	await _settle(2)
	_c("aynı gün gezinmede yeniden AÇILMAZ (günde bir)", not popup.visible)
	main.queue_free()
	await _settle(2)
	# Yeniden açılış aynı gün: gösterilmez.
	_main_script.ads_backend_override = fake
	main = MAIN_SCENE.instantiate()
	add_child(main)
	await _settle(3)
	_main_script.ads_backend_override = null
	main._daily.visible = false
	main._show_tab(0)
	await _settle(2)
	_c("aynı gün ikinci açılış: otomatik pencere yok, Mağaza'dan açılabilir", not main._daily_rewards.visible)
	main.open_daily_rewards()
	await _settle(1)
	_c("Mağaza yolu gün boyu açık", main._daily_rewards.visible)
	main._daily_rewards.close_popup()
	main.queue_free()
	await _settle(2)
	# Oyun içindeyken gün değişti: pencere kabuğa dönünce.
	_fresh_save(true, 0)
	DailyRewards.clock_override = DAY_A
	_main_script.ads_backend_override = fake
	main = MAIN_SCENE.instantiate()
	add_child(main)
	await _settle(3)
	_main_script.ads_backend_override = null
	main._daily_rewards.close_popup()
	await _settle(1)
	main._start_level(load("res://resources/levels/level_10.tres"))
	await _settle(2)
	DailyRewards.clock_override = DAY_B
	main._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _settle(1)
	_c("oyun içinde öne dönüş + yeni gün: pencere oyunun ortasında AÇILMAZ (gün işlendi)", not main._daily_rewards.visible
		and SaveManager.daily_last_seen_day_key() == DAY_B)
	main.abandon_run()
	await _settle(2)
	_c("kabuğa (Harita) dönünce açıldı", main._daily_rewards.visible and main._active_tab == 1)
	main._daily_rewards.close_popup()
	main.queue_free()
	await _settle(2)
	DailyRewards.clock_override = DAY_A

	# Onboarding tamamlanmamış: yuva yok, reklam yok, pencere yok, kart yok.
	_fresh_save(false, 0)
	DailyRewards.clock_override = DAY_A
	fake = FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	_main_script.ads_backend_override = fake
	main = MAIN_SCENE.instantiate()
	add_child(main)
	await _settle(3)
	_main_script.ads_backend_override = null
	main._daily.visible = false
	var m: MonetizationManager = main._ads
	fake.complete_consent_update(true)
	fake.complete_init()
	await _settle(1)
	_c("onboarding false: banner yuvası 0 (tam düzen), banner yüklenmedi", m.banner_slot_px() == 0.0
		and UiKit.banner_slot() == 0.0 and fake.banner_loads == 0)
	_c("onboarding false: ödüllü/geçiş reklamı yüklenmedi, hazır değil, not 'kullanılamıyor'", fake.rewarded_loads == 0
		and fake.interstitial_loads == 0 and not m.is_rewarded_ready() and m.rewarded_note() == MonetizationManager.NOTE_UNAVAILABLE)
	_c("onboarding false: otomatik günlük pencere yok", not main._daily_rewards.visible and DailyRewards.popup_due())
	main._show_tab(3)
	await _settle(2)
	main.open_daily_rewards()
	await _settle(1)
	_c("onboarding false: Mağaza günlük kartı GİZLİ, open_daily_rewards açmaz", not main._screens[3].daily_card().visible
		and not main._daily_rewards.visible)
	m._tick_active(1000.0)
	_c("onboarding false: aktif süre sayılmaz, uygunluk yok", m.active_elapsed_sec() == 0.0 and not m.interstitial_eligible())
	# Devam teklifi: sağlayıcı hazır değil -> CTA pasif (reklam sunumu yok).
	main._start_level(load("res://resources/levels/level_10.tres"))
	await _settle(2)
	main._board._dismiss_tutorial()
	main._board._enter_fail_pending()
	await _settle(3)
	_c("onboarding false: devam teklifinde DEVAM ET pasif + 'kullanılamıyor' (reklam sunulmaz)", main._revive.visible
		and main._revive.continue_button().disabled and main._revive.note_text() == MonetizationManager.NOTE_UNAVAILABLE
		and fake.rewarded_loads == 0)
	main.decline_revive()
	await _settle(2)
	main._result.hide_result()
	main.abandon_run()
	await _settle(2)
	# Tutorial bitti (M8.10 sözleşmesi): tek yazma ile true -> reklamlar + yuva + pencere.
	SaveManager.complete_onboarding()
	m.set_onboarding_completed(true)
	await _settle(1)
	_c("complete_onboarding + yönetici bildirimi: yuva hesaplandı, ödüllü + geçiş + banner yüklemeleri başladı",
		m.banner_slot_px() > 0.0 and UiKit.banner_slot() > 0.0 and fake.rewarded_loads == 1
		and fake.interstitial_loads == 1 and fake.banner_loads == 1)
	main._show_tab(3)
	await _settle(2)
	_c("onboarding sonrası Mağaza kartı görünür", main._screens[3].daily_card().visible)
	main.queue_free()
	await _settle(2)
	DailyRewards.auto_popup_enabled = true


func _restore_save_file() -> void:
	if not _had_save:
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()
