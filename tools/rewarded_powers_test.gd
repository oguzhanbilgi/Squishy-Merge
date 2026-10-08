extends Node
## TASK/060 — Ödüllü güçler: güç BAŞINA günde 2 kota, tek-transaction grant, eski ortak sayaçtan göç, ödül geri
## çağrısı güvenliği (gerçek Main + gerçek MonetizationManager + sahte SDK arka ucu `FakeAdBackend`), yaş / rıza
## fail-closed, meydan okuma yalıtımı, diğer reklam kotaları DEĞİŞMEDİ. Headless.
##
##   godot --headless --audio-driver Dummy --path . res://tools/rewarded_powers_test.tscn
##
## Kayıt `user://qa_rewarded_powers/`'e YÖNLENDİRİLİR (sahibin kayıt ailesi başta / sonda bayt bayt karşılaştırılır);
## saat kancası sabit gün (`DailyRewards.clock_override`). Sahte reklam ÖDÜL VERMEZ: stok yalnız arka ucun "ödül
## kazanıldı" olayıyla (gerçek yönetici + Main yolları) gelir.
##
## Bölümler: A saf kurallar · B SaveManager transaction (tek yazma, okuma yazmaz, gün, yeniden açılış, saat geri) ·
## C eski kayıt göçü (dosyadan yükleme) · D gerçek Main + yönetici + sahte arka uç: bağımsız kotalar, ödül sıraları,
## yinelenen / bayat / iptal / round değişimi · E yaş / rıza / sağlayıcı yok · F meydan okuma · G kaynak sözleşmesi.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_rewarded_powers"
const PATH: String = DIR + "/save.json"
const DAY: String = "2026-10-01"
const NEXT_DAY: String = "2026-10-02"
const PREV_DAY: String = "2026-09-30"
const LEVEL_10: String = "res://resources/levels/level_10.tres"
const SECTIONS: int = 7
const B: PowerUp.Type = PowerUp.Type.BOMB
const U: PowerUp.Type = PowerUp.Type.UPGRADE
const S: PowerUp.Type = PowerUp.Type.SHAKE
const C: PowerUp.Type = PowerUp.Type.CLEAR_SMALL

var _fails: int = 0
var _checks: int = 0
var _sections: int = 0
var _finished: bool = false
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _main: Node2D
var _main_script: GDScript = load("res://scripts/main.gd")


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_owner_state = _owner_snapshot()
	_saved_data = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	SaveManager.save_path = PATH
	DailyRewards.clock_override = DAY
	get_tree().create_timer(260.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 260 s'de bitmedi")
			if _main != null and is_instance_valid(_main):
				_main.free()
			_teardown()
			get_tree().quit(2))
	get_window().size = Vector2i(720, 1280)

	_pure()
	_transaction()
	_migration()
	await _end_to_end()
	await _age_consent()
	await _challenge()
	_sources()
	_c("%d/%d bölüm sonuna kadar koştu" % [_sections, SECTIONS], _sections == SECTIONS)

	await _teardown_main()
	_teardown()
	_c("SaveManager gerçek yola döndü, test klasörü silindi, saat kancası boş",
		SaveManager.save_path == SaveManager.SAVE_PATH and not DirAccess.dir_exists_absolute(DIR)
		and DailyRewards.clock_override == "")
	_c("sahibin gerçek kayıt ailesi (kanonik + .tmp + .bak) bayt-aynı", _owner_snapshot() == _owner_state)
	_finished = true
	print("\nSONUC: %d kontrol, %d hata" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


# --- A: saf kurallar ---------------------------------------------------------------------------------------------------

func _block(day: String, counts: Array) -> Dictionary:
	return {"version": 1, "day_key": day, "grants": {"bomb": counts[0], "upgrade": counts[1], "shake": counts[2],
		"clear_small": counts[3]}}


func _counts_of(block: Variant, day: String) -> Array:
	var view: Dictionary = RewardedPolicy.day_counts(block, day)
	return [view["bomb"], view["upgrade"], view["shake"], view["clear_small"]]


func _pure() -> void:
	print("-- A: saf kurallar (RewardedPolicy)")
	_c("tavan güç başına 2 (owner, Issue #1 §3)", RewardedPolicy.DAILY_GRANTS_PER_POWER == 2 and RewardedPolicy.daily_cap() == 2)
	_c("boş blok: dört sayaç 0", _counts_of(RewardedPolicy.empty_block(), DAY) == [0, 0, 0, 0])
	_c("kayıt yok (null) → 0", _counts_of(null, DAY) == [0, 0, 0, 0])
	var block: Dictionary = _block(DAY, [2, 1, 0, 0])
	_c("bugünün sayaçları aynen", _counts_of(block, DAY) == [2, 1, 0, 0])
	_c("yeni gün → dört sayaç 0 (okuma; blok değişmedi)", _counts_of(block, NEXT_DAY) == [0, 0, 0, 0]
		and block["day_key"] == DAY)
	_c("saat geri (kayıt günü bugünden ileride) → kayıttaki sayaçlar geçerli (yeni hak yok)",
		_counts_of(block, PREV_DAY) == [2, 1, 0, 0])
	var next: Dictionary = RewardedPolicy.after_grant(block, U, DAY)
	_c("grant sonrası: yalnız Büyütücü +1 (2), diğerleri aynen", _counts_of(next, DAY) == [2, 2, 0, 0] and next["day_key"] == DAY)
	_c("Bomba 2/2 → grant yok (boş sözlük)", RewardedPolicy.after_grant(block, B, DAY).is_empty())
	_c("Bomba 2/2 iken Sarsıntı grant'i serbest (bağımsız sayaç)", _counts_of(RewardedPolicy.after_grant(block, S, DAY), DAY)
		== [2, 1, 1, 0])
	var fresh: Dictionary = RewardedPolicy.after_grant(block, B, NEXT_DAY)
	_c("yeni günün ilk grant'i: yeni gün, yalnız o güç 1, diğerleri 0", fresh["day_key"] == NEXT_DAY
		and _counts_of(fresh, NEXT_DAY) == [1, 0, 0, 0])
	var rollback: Dictionary = RewardedPolicy.after_grant(_block(NEXT_DAY, [0, 0, 1, 0]), S, DAY)
	_c("saat geri iken grant ileri günü korur ve o günün sayacına yazar", rollback["day_key"] == NEXT_DAY
		and _counts_of(rollback, NEXT_DAY) == [0, 0, 2, 0])
	_c("geçersiz gün / tip → grant yok", RewardedPolicy.after_grant(block, S, "").is_empty()
		and RewardedPolicy.after_grant(block, S, "2026-13-01").is_empty()
		and RewardedPolicy.after_grant(block, 9 as PowerUp.Type, DAY).is_empty())
	_c("geçersiz bugün → okuma KAPALI (2)", RewardedPolicy.used_today(block, S, "") == 2)
	# Bozuk sayaçlar: fail-closed (o gün tükenmiş).
	var dirty: Dictionary = {"version": 1, "day_key": DAY, "grants": {"bomb": -1, "upgrade": 7, "shake": "abc",
		"extra": 1}}
	_c("bozuk sayaçlar (negatif / çok büyük / metin / eksik) → 2, bilinmeyen anahtar düşer",
		_counts_of(dirty, DAY) == [2, 2, 2, 2] and not RewardedPolicy.sanitize(dirty, DAY)["grants"].has("extra"))
	_c("tam float sayaç kabul (JSON), kesirli float → 2", _counts_of({"version": 1.0, "day_key": DAY,
		"grants": {"bomb": 1.0, "upgrade": 1.5, "shake": 0.0, "clear_small": 2.0}}, DAY) == [1, 2, 0, 2])
	var broken: Array = ["metin", 12, {"version": 2, "day_key": DAY, "grants": {}},
		{"version": 1, "day_key": "2026-02-30", "grants": {}}, {"version": 1, "day_key": DAY, "grants": "x"}]
	var all_closed: bool = true
	for raw in broken:
		var clean: Dictionary = RewardedPolicy.sanitize(raw, DAY)
		all_closed = all_closed and clean["day_key"] == DAY and _counts_of(clean, DAY) == [2, 2, 2, 2]
		all_closed = all_closed and _counts_of(raw, DAY) == [2, 2, 2, 2]
	_c("bozuk blok (sözlük değil / sürüm / gün / grants) → bugün KAPALI (okuma + yükleme), ertesi gün 0",
		all_closed and _counts_of(RewardedPolicy.sanitize("metin", DAY), NEXT_DAY) == [0, 0, 0, 0])
	_c("geçerli blok temizlenip aynen", RewardedPolicy.sanitize(_block(DAY, [1, 0, 2, 0]), DAY) == _block(DAY, [1, 0, 2, 0]))
	# Eski ortak sayaç → güç başına.
	_c("eski: bugün 1 → dört sayaç 1", _counts_of(RewardedPolicy.from_legacy(DAY, 1, DAY), DAY) == [1, 1, 1, 1])
	_c("eski: bugün 0 → 0", _counts_of(RewardedPolicy.from_legacy(DAY, 0, DAY), DAY) == [0, 0, 0, 0])
	_c("eski: bugün 5 → 0..1'e normalleşir (1)", _counts_of(RewardedPolicy.from_legacy(DAY, 5, DAY), DAY) == [1, 1, 1, 1])
	_c("eski: dün 1 → boş blok", RewardedPolicy.from_legacy(PREV_DAY, 1, DAY) == RewardedPolicy.empty_block())
	_c("eski: tarih yok / bozuk tarih → boş blok", RewardedPolicy.from_legacy("", 1, DAY) == RewardedPolicy.empty_block()
		and RewardedPolicy.from_legacy(null, null, DAY) == RewardedPolicy.empty_block()
		and RewardedPolicy.from_legacy("dün", 1, DAY) == RewardedPolicy.empty_block())
	_c("eski: bugün bozuk / negatif sayı → 1 (fail-closed)", _counts_of(RewardedPolicy.from_legacy(DAY, "abc", DAY), DAY)
		== [1, 1, 1, 1] and _counts_of(RewardedPolicy.from_legacy(DAY, -3, DAY), DAY) == [1, 1, 1, 1])
	_c("eski: JSON float 1.0 → 1", _counts_of(RewardedPolicy.from_legacy(DAY, 1.0, DAY), DAY) == [1, 1, 1, 1])
	_sections += 1


# --- B: SaveManager transaction ----------------------------------------------------------------------------------------

func _fresh_data(extra: Dictionary = {}) -> void:
	var data: Dictionary = SaveManager.DEFAULT_DATA.duplicate(true)
	data["powerups"] = {"bomb": 0, "upgrade": 0, "shake": 3, "clear_small": 1}
	data["powerup_starter_granted"] = true
	data["dough"] = 777
	data["highest_level_unlocked"] = 6
	data["level_stars"] = {"1": 3, "2": 2}
	data["onboarding_completed"] = true
	for key: String in extra:
		data[key] = extra[key]
	SaveManager.data = data


func _transaction() -> void:
	print("-- B: SaveManager transaction (tek yazma, okuma yazmaz, gün, yeniden açılış, saat geri)")
	_clean()
	_fresh_data()
	SaveManager.save_game()
	var before: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	_c("okuma yazmaz: grants_today / remaining_today / can_grant dosyayı değiştirmez",
		RewardedPolicy.grants_today(B) == 0 and RewardedPolicy.remaining_today(B) == 2 and RewardedPolicy.can_grant(B)
		and FileAccess.get_file_as_bytes(PATH) == before)
	_c("grant Bomba (0→1): true", RewardedPolicy.grant(B))
	var after1: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	_c("TEK yazma: .bak == grant öncesi kanonik (ara durum yok), kanonik == bellek", FileAccess.get_file_as_bytes(
		PATH + SaveFile.BACKUP_SUFFIX) == before and JSON.parse_string(after1.get_string_from_utf8()) == JSON.parse_string(
		JSON.stringify(SaveManager.data)))
	_c("yalnız Bomba stoğu +1 ve yalnız Bomba sayacı 1", SaveManager.powerup_count(B) == 1 and SaveManager.powerup_count(U) == 0
		and SaveManager.powerup_count(S) == 3 and SaveManager.powerup_count(C) == 1 and RewardedPolicy.grants_today(B) == 1
		and RewardedPolicy.grants_today(U) == 0 and RewardedPolicy.grants_today(S) == 0 and RewardedPolicy.grants_today(C) == 0)
	_c("diğer alanlar aynen (Hamur / level / yıldız)", SaveManager.dough() == 777
		and SaveManager.highest_level_unlocked() == 6 and SaveManager.stars_for_level(1) == 3)
	_c("grant Bomba (1→2): true", RewardedPolicy.grant(B) and SaveManager.powerup_count(B) == 2
		and RewardedPolicy.grants_today(B) == 2 and not RewardedPolicy.can_grant(B))
	var full: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var data_full: Dictionary = SaveManager.data.duplicate(true)
	_c("Bomba 3. grant reddedilir: stok / sayaç / dosya / bellek DEĞİŞMEZ", not RewardedPolicy.grant(B)
		and SaveManager.powerup_count(B) == 2 and FileAccess.get_file_as_bytes(PATH) == full and SaveManager.data == data_full)
	_c("Bomba 2/2 iken Büyütücü, Sarsıntı, Temizleyici serbest (dört bağımsız sayaç)", RewardedPolicy.can_grant(U)
		and RewardedPolicy.can_grant(S) and RewardedPolicy.can_grant(C))
	for type in [U, U, S, S, C, C]:
		RewardedPolicy.grant(type)
	_c("teorik günlük tavan: dört güç × 2 = 8 başarılı grant, dokuzuncu yok", RewardedPolicy.grants_today(U) == 2
		and RewardedPolicy.grants_today(S) == 2 and RewardedPolicy.grants_today(C) == 2 and not RewardedPolicy.grant(U)
		and not RewardedPolicy.grant(S) and not RewardedPolicy.grant(C) and SaveManager.powerup_count(U) == 2
		and SaveManager.powerup_count(S) == 5 and SaveManager.powerup_count(C) == 3)
	var invalid_bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	_c("geçersiz tip / gün → false, yazma yok", not SaveManager.grant_rewarded_powerup(7 as PowerUp.Type, DAY)
		and not SaveManager.grant_rewarded_powerup(B, "") and FileAccess.get_file_as_bytes(PATH) == invalid_bytes)
	# Yeniden açılış: aynı gün haklar yenilenmez.
	SaveManager.load_game()
	_c("yeniden açılış (aynı gün): sayaçlar kalıcı, hak yenilenmedi", RewardedPolicy.grants_today(B) == 2
		and RewardedPolicy.grants_today(C) == 2 and not RewardedPolicy.can_grant(S) and SaveManager.powerup_count(B) == 2)
	_c("kayıtta eski ortak anahtarlar yok", not SaveManager.data.has("rewarded_power_date")
		and not SaveManager.data.has("rewarded_power_grants"))
	# Yeni gün: okuma 0, dosya değişmez; ilk grant yeni günü yazar.
	DailyRewards.clock_override = NEXT_DAY
	var day_bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	_c("yeni gün: dört sayaç okumada 0, dosya DEĞİŞMEDİ", RewardedPolicy.grants_today(B) == 0
		and RewardedPolicy.grants_today(S) == 0 and FileAccess.get_file_as_bytes(PATH) == day_bytes)
	_c("yeni günün ilk grant'i (Sarsıntı): blok yeni gün, Sarsıntı 1, diğerleri 0", RewardedPolicy.grant(S)
		and SaveManager.rewarded_power_quota()["day_key"] == NEXT_DAY
		and _counts_of(SaveManager.rewarded_power_quota(), NEXT_DAY) == [0, 0, 1, 0])
	# Saat geri: kabul edilen gün geri gitmez (DailyRewards.day_key) ve kayıt günü ileride → yeni hak yok.
	SaveManager.record_daily_last_seen_day(NEXT_DAY)
	DailyRewards.clock_override = DAY
	_c("saat geri alındı: kabul edilen gün ileride kalır, Sarsıntı sayacı 1 (yeni hak üretilmez)",
		RewardedPolicy.today() == NEXT_DAY and RewardedPolicy.grants_today(S) == 1)
	DailyRewards.clock_override = DAY
	_sections += 1


# --- C: eski kayıt göçü ----------------------------------------------------------------------------------------------

func _write_file(content: Dictionary) -> PackedByteArray:
	_clean()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(content, "\t"))
	file.close()
	return FileAccess.get_file_as_bytes(PATH)


func _legacy_save(extra: Dictionary) -> Dictionary:
	var content: Dictionary = {"highest_level_unlocked": 4, "level_stars": {"1": 3, "2": 3, "3": 1}, "dough": 410,
		"powerups": {"bomb": 2, "upgrade": 0, "shake": 1, "clear_small": 0}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "",
		"daily_rewards": {"day_key": DAY, "free_chest_claimed": true, "ad_chests_claimed": 0, "dough_ad_claimed": false,
			"popup_seen_day": DAY, "last_seen_day_key": DAY}}
	for key: String in extra:
		content[key] = extra[key]
	return content


func _migration() -> void:
	print("-- C: eski kayıt göçü (dosyadan yükleme; bellekte, açılışta disk yazması yok)")
	DailyRewards.clock_override = DAY
	var cases: Array = [
		["eski bugün 1 → dört güç 1/2", {"rewarded_power_date": DAY, "rewarded_power_grants": 1}, [1, 1, 1, 1]],
		["eski bugün 0 → 0/2", {"rewarded_power_date": DAY, "rewarded_power_grants": 0}, [0, 0, 0, 0]],
		["eski dün 1 → 0/2", {"rewarded_power_date": PREV_DAY, "rewarded_power_grants": 1}, [0, 0, 0, 0]],
		["hiç anahtar yok (M8.5-06 öncesi) → 0/2", {}, [0, 0, 0, 0]],
		["eski bugün bozuk sayı → 1 (fail-closed)", {"rewarded_power_date": DAY, "rewarded_power_grants": "abc"}, [1, 1, 1, 1]],
		["V3 + eski birlikte → V3 önceliklidir", {"rewarded_power_date": DAY, "rewarded_power_grants": 1,
			"rewarded_power_quota": _block(DAY, [0, 2, 0, 1])}, [0, 2, 0, 1]],
		["V3 kısmi blok (eksik güç) → eksik güç kapalı", {"rewarded_power_quota": {"version": 1, "day_key": DAY,
			"grants": {"bomb": 1}}}, [1, 2, 2, 2]],
		["V3 bozuk blok (sürüm 9) → bugün kapalı", {"rewarded_power_quota": {"version": 9, "day_key": DAY, "grants": {}}},
			[2, 2, 2, 2]],
		["V3 anahtarı null (bozulma) → bugün kapalı, eski sayaç yok sayılır", {"rewarded_power_quota": null,
			"rewarded_power_date": DAY, "rewarded_power_grants": 0}, [2, 2, 2, 2]],
	]
	for case in cases:
		var bytes: PackedByteArray = _write_file(_legacy_save(case[1]))
		SaveManager.load_game()
		var got: Array = [RewardedPolicy.grants_today(B), RewardedPolicy.grants_today(U), RewardedPolicy.grants_today(S),
			RewardedPolicy.grants_today(C)]
		_c("%s (got %s); eski anahtarlar bellekten düştü; dosya yüklemede yazılmadı" % [case[0], str(got)], got == case[2]
			and not SaveManager.data.has("rewarded_power_date") and not SaveManager.data.has("rewarded_power_grants")
			and FileAccess.get_file_as_bytes(PATH) == bytes)
	# Diğer alanlar aynen + tekrar yükleme idempotent + ilk yeni gün grant'i.
	var legacy_bytes: PackedByteArray = _write_file(_legacy_save({"rewarded_power_date": DAY, "rewarded_power_grants": 1}))
	SaveManager.load_game()
	var first: Dictionary = SaveManager.rewarded_power_quota()
	_c("göç diğer alanlara dokunmaz (stok / Hamur / level / yıldız)", SaveManager.powerup_count(B) == 2
		and SaveManager.powerup_count(S) == 1 and SaveManager.dough() == 410 and SaveManager.highest_level_unlocked() == 4
		and SaveManager.stars_for_level(3) == 1)
	SaveManager.load_game()
	_c("tekrar yükleme aynı sonucu verir (idempotent), dosya hâlâ eski", SaveManager.rewarded_power_quota() == first
		and FileAccess.get_file_as_bytes(PATH) == legacy_bytes)
	_c("göç günü: güç başına bir hak daha (1/2 → 2/2), üçüncüsü yok", RewardedPolicy.grant(U)
		and not RewardedPolicy.grant(U) and SaveManager.powerup_count(U) == 1)
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_c("ilk grant: diskte güç başına blok, eski ortak anahtarlar YOK", disk.has("rewarded_power_quota")
		and not disk.has("rewarded_power_date") and not disk.has("rewarded_power_grants"))
	DailyRewards.clock_override = NEXT_DAY
	_c("ertesi gün göç edilmiş kayıtta dört güç 0/2", RewardedPolicy.grants_today(B) == 0 and RewardedPolicy.grants_today(U) == 0
		and RewardedPolicy.grants_today(S) == 0 and RewardedPolicy.grants_today(C) == 0)
	DailyRewards.clock_override = DAY
	# Yedekten kurtarma: kanonik bozuk, .bak eski biçim → göç yine uygulanır.
	_clean()
	var bak := FileAccess.open(PATH + SaveFile.BACKUP_SUFFIX, FileAccess.WRITE)
	bak.store_string(JSON.stringify(_legacy_save({"rewarded_power_date": DAY, "rewarded_power_grants": 1}), "\t"))
	bak.close()
	var canon := FileAccess.open(PATH, FileAccess.WRITE)
	canon.store_string("{bozuk")
	canon.close()
	SaveManager.load_game()
	_c("yedekten kurtarma: kaynak BACKUP, göç uygulandı (dört güç 1/2), stok korundu",
		SaveManager.load_source() == SaveFile.Source.BACKUP and RewardedPolicy.grants_today(S) == 1
		and SaveManager.powerup_count(B) == 2)
	_sections += 1


# --- D: gerçek Main + yönetici + sahte arka uç ---------------------------------------------------------------------------

func _settle(frames: int = 2) -> void:
	for i in maxi(frames, 1):
		await get_tree().process_frame


func _boot_main(fake: FakeAdBackend, band: String = "ADULT") -> void:
	await _teardown_main()
	_clean()
	_fresh_data({"powerups": {"bomb": 0, "upgrade": 0, "shake": 0, "clear_small": 0}, "dough": 500,
		"age_ad_band": band, "next_age_transition_date": "2029-06-15" if band == "TEEN" else "", "last_login_date": DAY,
		"daily_rewards": {"day_key": DAY, "free_chest_claimed": true, "ad_chests_claimed": 2, "dough_ad_claimed": true,
			"popup_seen_day": DAY, "last_seen_day_key": DAY}})
	SaveManager.save_game()
	SaveManager.load_game()
	MonetizationManager.time_scale = 0.05
	_main_script.ads_backend_override = fake
	_main = MAIN_SCENE.instantiate()
	_main.set("quit_suppressed", true)
	add_child(_main)
	await _settle(3)
	_main_script.ads_backend_override = null
	if fake != null:
		fake.complete_consent_update(true)
		fake.complete_init()
		await _settle(2)


func _open(board: Node2D, type: PowerUp.Type) -> void:
	board._on_power_refill_requested(int(type))
	await _settle(3)


func _end_to_end() -> void:
	print("-- D: gerçek Main + MonetizationManager + FakeAdBackend (ödül yalnız 'kazanıldı' olayıyla)")
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	await _boot_main(fake)
	var m: MonetizationManager = _main._ads
	_c("ön koşul: yönetici sağlayıcı, ADULT, reklamlar açık", m != null and _main._rewarded_provider == m and m.ads_allowed())
	_main._start_level(load(LEVEL_10))
	await _settle(3)
	var board: Node2D = _main._board
	var refill: CanvasLayer = _main._refill
	fake.complete_rewarded_load(true)
	await _settle(1)
	await _open(board, B)
	_c("Bomba stok 0 → pencere: kurdele BOMBA, stok '0', İZLE etkin, kota 0/2", refill.visible
		and refill.ribbon_text() == "BOMBA" and refill.stock_text() == "0" and not refill._ad.disabled
		and refill.quota_text() == "0/2")
	# 1) Ödül kapanıştan ÖNCE (SDK gerçek sırası, ADS_SYSTEM §18): tam bir grant.
	refill._ad.pressed.emit()
	await _settle(2)
	var req: Dictionary = m.request_info()
	_c("İZLE → talep: tip Bomba + Main token'ı, SDK gösterimi 1", req["active"] and req["type"] == int(B)
		and req["token"] == _main._refill_pending_token and fake.rewarded_shows.size() == 1)
	var dough_before: int = SaveManager.dough()
	refill._on_dough_pressed()
	await _settle(1)
	_c("talep açıkken Hamur düğmesi KİLİTLİ: satın alma yok, pencere ve token açık (geç ödül kapanmış pencereye düşemez)",
		refill._dough.disabled and SaveManager.dough() == dough_before and SaveManager.powerup_count(B) == 0
		and refill.visible and _main._refill_pending_token == req["token"])
	var bytes0: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	fake.emit_rewarded_showed(req["ad_id"])
	fake.emit_rewarded_impression(req["ad_id"])
	await _settle(1)
	_c("gösterim / izlenim: stok 0, kota 0, kayıt yazılmadı", SaveManager.powerup_count(B) == 0
		and RewardedPolicy.grants_today(B) == 0 and FileAccess.get_file_as_bytes(PATH) == bytes0)
	fake.emit_rewarded_earned(req["ad_id"])
	await _settle(2)
	_c("ödül → yalnız Bomba +1, Bomba 1/2, pencere kapandı, board sürüyor", SaveManager.powerup_count(B) == 1
		and RewardedPolicy.grants_today(B) == 1 and SaveManager.powerup_count(U) == 0 and SaveManager.powerup_count(S) == 0
		and SaveManager.powerup_count(C) == 0 and not refill.visible and not board.is_refill_pending())
	fake.emit_rewarded_earned(req["ad_id"])
	await _settle(1)
	_c("aynı reklamın ikinci 'kazanıldı'sı (yinelenen) ikinci stok VERMEZ", SaveManager.powerup_count(B) == 1
		and RewardedPolicy.grants_today(B) == 1)
	_c("bayat / yanlış tip / yanlış token doğrudan çağrısı → false", not _main.grant_rewarded_power(int(B), req["token"])
		and not _main.grant_rewarded_power(int(S), 999))
	fake.emit_rewarded_dismissed(req["ad_id"])
	await _settle(1)
	_c("kapanış (ödülden sonra) ikinci grant üretmez", SaveManager.powerup_count(B) == 1)
	# 2) Ödülsüz kapanış: 0 grant, pencere açık, kısa sebep.
	SaveManager.data["powerups"]["bomb"] = 0
	fake.complete_rewarded_load(true)
	await _open(board, B)
	_c("ikinci açılış: Bomba kota 1/2, İZLE etkin", refill.quota_text() == "1/2" and not refill._ad.disabled)
	refill._ad.pressed.emit()
	await _settle(2)
	var ad2: String = m.request_info()["ad_id"]
	fake.emit_rewarded_dismissed(ad2)
	await _settle(2)
	_c("ödülsüz kapanış: stok 0, kota 1/2 (tüketilmedi), pencere açık + 'tamamını izle' notu",
		SaveManager.powerup_count(B) == 0 and RewardedPolicy.grants_today(B) == 1 and refill.visible
		and refill.note_text() == MonetizationManager.NOTE_NOT_EARNED)
	# 3) Gösterim hatası: 0 grant.
	var ad3: String = fake.complete_rewarded_load(true)
	await _settle(1)
	refill.refresh(_main._power_provider_ready(), _main._provider_note())
	refill._ad.pressed.emit()
	await _settle(2)
	fake.emit_rewarded_show_failed(m.request_info()["ad_id"] if m.request_info()["active"] else ad3)
	await _settle(2)
	_c("gösterim hatası: stok 0, kota 1/2", SaveManager.powerup_count(B) == 0 and RewardedPolicy.grants_today(B) == 1)
	# 4) İkinci başarılı ödül → 2/2; üçüncü talep SDK'ya gitmez.
	fake.complete_rewarded_load(true)
	await _settle(1)
	refill.refresh(_main._power_provider_ready(), _main._provider_note())
	refill._ad.pressed.emit()
	await _settle(2)
	var ad4: String = m.request_info()["ad_id"]
	fake.emit_rewarded_earned(ad4)
	fake.emit_rewarded_dismissed(ad4)
	await _settle(2)
	_c("ikinci başarılı ödül → Bomba 2/2, stok 1", RewardedPolicy.grants_today(B) == 2 and SaveManager.powerup_count(B) == 1)
	SaveManager.data["powerups"]["bomb"] = 0
	fake.complete_rewarded_load(true)
	await _open(board, B)
	var shows: int = fake.rewarded_shows.size()
	_c("Bomba 2/2: İZLE EXHAUSTED (pasif) + 'Bugünlük bitti' notu, reklam hazır olsa da", refill.visible
		and refill._ad.disabled and refill.quota_text() == "2/2" and refill.ad_note_text() == refill.NOTE_QUOTA_USED
		and m.is_rewarded_ready())
	refill._on_ad_pressed()
	_main._on_rewarded_power_requested(int(B))
	await _settle(1)
	_c("2/2 iken talep (UI + Main) SDK'ya gitmez", fake.rewarded_shows.size() == shows)
	_c("kota sebebi TEK yerde: İZLE karosu 'Bugünlük bitti', altlık boş", refill.ad_note_text() == refill.NOTE_QUOTA_USED
		and refill.note_text() == "")
	_main._on_refill_closed()
	await _settle(1)
	# 5) Bağımsızlık: Bomba 2/2 iken Sarsıntı tam çalışır.
	await _open(board, S)
	_c("Bomba 2/2 iken Sarsıntı: İZLE etkin, 0/2", refill.visible and not refill._ad.disabled and refill.quota_text() == "0/2")
	refill._ad.pressed.emit()
	await _settle(2)
	var ad5: String = m.request_info()["ad_id"]
	_c("Sarsıntı talebi SDK'ya gitti, tip Sarsıntı", m.request_info()["type"] == int(S) and fake.rewarded_shows.size() == shows + 1)
	fake.emit_rewarded_earned(ad5)
	fake.emit_rewarded_dismissed(ad5)
	await _settle(2)
	_c("Sarsıntı +1 (1/2); Bomba 2/2 aynen; Sarsıntı anında güç OTOMATİK ÇALIŞMADI (stok 1 duruyor)",
		SaveManager.powerup_count(S) == 1 and RewardedPolicy.grants_today(S) == 1 and RewardedPolicy.grants_today(B) == 2)
	# 6) Hedefli güç: refill sonrası hedefleme geri gelir, stok tüketilmez.
	SaveManager.data["powerups"]["upgrade"] = 0
	fake.complete_rewarded_load(true)
	await _open(board, U)
	refill._ad.pressed.emit()
	await _settle(2)
	var ad6: String = m.request_info()["ad_id"]
	fake.emit_rewarded_earned(ad6)
	await _settle(2)
	_c("Büyütücü ödülü → stok 1, hedefleme yeniden açık (niyet dönüşü), stok TÜKETİLMEDİ",
		SaveManager.powerup_count(U) == 1 and board._powerups.is_armed() and board._powerups.armed_type() == int(U))
	fake.emit_rewarded_dismissed(ad6)
	board._powerups.cancel()
	await _settle(1)
	# 7) Pencere kapandıktan sonra gelen ödül: 0.
	SaveManager.data["powerups"]["clear_small"] = 0
	fake.complete_rewarded_load(true)
	await _open(board, C)
	refill._ad.pressed.emit()
	await _settle(2)
	var ad7: String = m.request_info()["ad_id"]
	_main._on_refill_closed()
	await _settle(1)
	fake.emit_rewarded_earned(ad7)
	fake.emit_rewarded_dismissed(ad7)
	await _settle(2)
	_c("KAPAT sonrası gelen ödül: Temizleyici stok 0, kota 0/2", SaveManager.powerup_count(C) == 0
		and RewardedPolicy.grants_today(C) == 0)
	# 8) Round değişimi (terk) sırasında açık talep: 0.
	fake.complete_rewarded_load(true)
	await _open(board, C)
	refill._ad.pressed.emit()
	await _settle(2)
	var ad8: String = m.request_info()["ad_id"]
	_main.abandon_run()
	await _settle(2)
	fake.emit_rewarded_earned(ad8)
	fake.emit_rewarded_dismissed(ad8)
	await _settle(2)
	_c("round terk edildi: geç ödül Temizleyici stoğu vermez, kota 0/2", SaveManager.powerup_count(C) == 0
		and RewardedPolicy.grants_today(C) == 0 and _main._refill_pending_token == 0)
	# Diğer reklam kotaları değişmedi.
	var caps: Dictionary = AdPolicy.rewarded_caps()
	_c("diğer kotalar AYNEN: devam 2/round, reklamlı sandık 2/gün, +150 Hamur 1/gün; güç 2/güç/gün × 4 güç",
		caps["revive_per_round"] == 2 and caps["ad_chest_per_day"] == 2 and caps["ad_dough_per_day"] == 1
		and caps["ad_dough_amount"] == 150 and caps["power_refill_per_power_per_day"] == 2 and caps["power_kinds"] == 4)
	_c("zorunlu geçiş reklamı AYNEN: 2 round + 300 sn + 60 sn bekleme", AdPolicy.FORCED_INTERSTITIAL_MIN_ROUNDS == 2
		and AdPolicy.FORCED_INTERSTITIAL_MIN_INTERVAL_SEC == 300.0 and AdPolicy.FULLSCREEN_AD_COOLDOWN_SEC == 60.0)
	_sections += 1


# --- E: yaş / rıza / sağlayıcı ---------------------------------------------------------------------------------------

func _age_consent() -> void:
	print("-- E: yaş / rıza / sağlayıcı — fail-closed")
	# Sağlayıcı yok (eklentisiz masaüstü): İZLE pasif + kısa sebep, talep stok vermez.
	await _boot_main(null)
	_main._start_level(load(LEVEL_10))
	await _settle(3)
	await _open(_main._board, B)
	var refill: CanvasLayer = _main._refill
	_c("sağlayıcı yok: İZLE pasif (UNAVAILABLE), sebep 'henüz bağlı değil', Hamur yolu açık", refill._ad.disabled
		and refill.ad_note_text() == refill.NOTE_NO_PROVIDER and not refill._dough.disabled)
	_main._on_rewarded_power_requested(int(B))
	await _settle(1)
	_c("sağlayıcısız talep: stok 0, kota 0, pencere notu", SaveManager.powerup_count(B) == 0
		and RewardedPolicy.grants_today(B) == 0 and refill.note_text() != "")
	_main._on_refill_closed()
	# Yaş UNKNOWN: SDK / UMP başlamaz, ödüllü hazır değil.
	for band in ["UNKNOWN", "UNDER_13"]:
		var fake := FakeAdBackend.new()
		fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
		await _boot_main(fake, band)
		var m: MonetizationManager = _main._ads
		fake.complete_rewarded_load(true)
		_main._start_level(load(LEVEL_10))
		await _settle(3)
		await _open(_main._board, B)
		refill = _main._refill
		_c("yaş %s: ödüllü hazır DEĞİL, İZLE pasif, nötr not; SDK gösterimi 0" % band, m != null
			and not m.is_rewarded_ready() and refill._ad.disabled and refill.ad_note_text() != ""
			and fake.rewarded_shows.is_empty())
		_main._on_rewarded_power_requested(int(B))
		await _settle(1)
		_c("yaş %s: talep reklam açmaz, stok 0" % band, fake.rewarded_shows.is_empty() and SaveManager.powerup_count(B) == 0)
		_main._on_refill_closed()
	# Rıza reddi: ADS_NOT_ALLOWED → hazır değil.
	var denied := FakeAdBackend.new()
	denied.status = AdBackend.ConsentStatus.REQUIRED
	denied.can_request_override = 0
	await _boot_main(denied)
	var md: MonetizationManager = _main._ads
	_main._start_level(load(LEVEL_10))
	await _settle(3)
	await _open(_main._board, B)
	_c("rıza yok / reklam isteğine izin yok: ödüllü hazır değil, İZLE pasif", md != null and not md.is_rewarded_ready()
		and _main._refill._ad.disabled)
	_main._on_refill_closed()
	# TEEN: mevcut SDK sınırlarından geçer (bypass yok) — yönetici reklama izinli bant olarak açar.
	var teen := FakeAdBackend.new()
	teen.status = AdBackend.ConsentStatus.NOT_REQUIRED
	await _boot_main(teen, "TEEN")
	var mt: MonetizationManager = _main._ads
	teen.complete_rewarded_load(true)
	await _settle(1)
	_c("TEEN: yaş yönlendirmesi reklamlara izin verir (TFAT / derece yöneticide), ödüllü hazır", mt != null
		and mt.age_ads_allowed() and mt.is_rewarded_ready())
	_sections += 1


# --- F: meydan okuma ------------------------------------------------------------------------------------------------

func _challenge() -> void:
	print("-- F: günlük meydan okuma — güç / refill / ödüllü güç YOK")
	await _boot_main(null)
	_c("meydan okuma başladı", _main.start_daily_challenge())
	await _settle(3)
	var board: Node2D = _main._board
	board._on_power_refill_requested(int(B))
	await _settle(2)
	_main._on_power_refill_offered(int(B))
	await _settle(2)
	_c("refill açılmaz, board donmaz, güç çubuğu kilitli ve gizli", not _main._refill.visible
		and not board.is_refill_pending() and board._power_bar.is_locked() and not board._hud.power_bar.visible)
	_c("meydan okumada açık ödüllü talep yok; doğrudan grant false", _main._refill_pending_token == 0
		and not _main.grant_rewarded_power(int(B), 1) and RewardedPolicy.grants_today(B) == 0)
	_main._leave_daily_challenge()
	await _settle(2)
	_sections += 1


# --- G: kaynak sözleşmesi -----------------------------------------------------------------------------------------------

func _sources() -> void:
	print("-- G: kaynak sözleşmesi")
	var leftovers: Array[String] = []
	for path in _scripts("res://scripts"):
		var text: String = FileAccess.get_file_as_string(path)
		for needle in ["DAILY_POWER_REFILLS", "RewardedPolicy.grants_today()", "RewardedPolicy.remaining_today()",
				"RewardedPolicy.can_grant()", "rewarded_power_grants_today(today)"]:
			if text.contains(needle):
				leftovers.append("%s: %s" % [path.get_file(), needle])
	_c("eski argümansız / ortak kota API'si hiçbir üretim betiğinde yaşamıyor (%s)" % str(leftovers), leftovers.is_empty())
	var manager: String = FileAccess.get_file_as_string("res://scripts/ads/monetization_manager.gd")
	var earned: String = manager.get_slice("func _on_rewarded_earned(", 1).get_slice("\nfunc ", 0)
	var closed: String = manager.get_slice("func _rewarded_closed(", 1).get_slice("\nfunc ", 0)
	_c("ödül yalnız 'kazanıldı' işleyicisinden Main'e: kapanış / hata yolunda grant çağrısı YOK",
		earned.contains("main.grant_rewarded_power(") and not closed.contains("grant_rewarded_power")
		and manager.count("main.grant_rewarded_power(") == 1)
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var grant_fn: String = main_src.get_slice("func grant_rewarded_power(", 1).get_slice("\nfunc ", 0)
	_c("Main.grant_rewarded_power: token + tip kapısı, token grant'ten ÖNCE temizlenir, kota RewardedPolicy.grant(type)",
		grant_fn.contains("token != _refill_pending_token") and grant_fn.contains("type != _refill_pending_type")
		and grant_fn.find("_clear_refill_request()") < grant_fn.find("RewardedPolicy.grant(type"))
	var refill_src: String = _code_only(FileAccess.get_file_as_string("res://scripts/ui/power_refill.gd"))
	var medal_src: String = _code_only(FileAccess.get_file_as_string("res://scripts/ui/power_medallion.gd"))
	_c("refill / HUD madalyonu KODUNDA (yorum hariç) '×' / 'STOK' stok biçimi yok", not refill_src.contains("×")
		and not refill_src.contains("STOK") and not medal_src.contains("×"))
	var dough_fn: String = main_src.get_slice("func _on_dough_refill_requested(", 1).get_slice("\nfunc ", 0)
	_c("Hamur satın alması açık ödüllü talebi kapatır (token + sağlayıcı iptali, kapanıştan ÖNCE)",
		dough_fn.find("_clear_refill_request()") >= 0 and dough_fn.find("_cancel_rewarded_request()") >= 0
		and dough_fn.find("_cancel_rewarded_request()") < dough_fn.find("_finish_refill("))
	_sections += 1


## Yorum satırları atılmış kaynak (## / # ile başlayan satırlar ve satır sonu yorumları).
func _code_only(text: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	for line in text.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		var hash: int = line.find(" # ")
		out.append(line.substr(0, hash) if hash >= 0 else line)
	return "\n".join(out)


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir + "/" + d))
	return out


# --- ortak ---------------------------------------------------------------------------------------------------------------

func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _settle(3)


func _teardown() -> void:
	MonetizationManager.time_scale = 1.0
	_main_script.ads_backend_override = null
	DailyRewards.clock_override = ""
	DailyRewards.auto_popup_enabled = false
	UiKit.set_banner_slot(0.0)
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


func _clean() -> void:
	for p: String in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for p: String in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null
	return out
