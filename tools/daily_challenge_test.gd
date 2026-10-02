extends Node
## TASK/047 — Günlük Merge Challenge (MEYDAN OKUMA) model + kayıt testi. Headless.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_daily_challenge/` altındaki
## bir yola yönlendirilir (`save_path`, TASK/045.1 test dikişi) ve sonda geri alınır; gerçek kayıt
## ailesinin (kanonik + .tmp + .bak) baytları başta / sonda karşılaştırılır.
##
##   godot --headless --audio-driver Dummy --path . res://tools/daily_challenge_test.tscn
##
## Kontroller:
##   preset      sabitler (+20, sürüm 1, "sm-dc-v1", 400, 1.5 / 5.0, nöbetçi 0) ve yedi KİLİTLİ preset;
##               hedef adı TierConfig'ten ("Büyük Dumpling yap · 18 hamlede"); yedi gün en fazla +140
##   hafta günü  bilinen günler, ay / yıl sınırı, artık yıl, 1200 ardışık gün (Missions pazartesisiyle
##               çapraz), geçersiz gün → -1 / boş tanım / null level
##   dizi        2026-10-01 kilitli test vektörü (ilk 18), bağımsız (Python) vektörler, her 9'luk torba
##               3·T1 + 3·T2 + 3·T3 (400 gün × 6 torba), tekrar = aynı, kaynak nesnesi = saf dizi;
##               global RNG kontrol noktası ve production DropBag akışı DEĞİŞMEZ; kaynakta seed yok
##   level       kodda kurulan LevelData (hedef / genişlik / 400 / sonsuz değil / skor hedefi yok /
##               nöbetçi 0); LevelLibrary aynen 10 level + sonsuz, resources/levels'e .tres eklenmedi
##   blok        doğrulama (sözlük değil / sürüm / bozuk gün / fazla anahtar), saf kurallar
##               (can_complete / is_completed / effective_day)
##   kayıt       eski kayıt → varsayılan blok (geriye dönük ödül YOK, yüklemede yazma YOK); bozuk blok;
##               ilk tamamlanma tam +20 + gün TEK yazmada (tek atımlık hata dedektörü); çökme
##               pencereleri gün ile Hamur'u ayırmaz; yinelenen / eski / aynı gün +0 (yazma yok);
##               yeni gün +20; yedi gün +140; .tmp / .bak kurtarması bloğu taşır; ayrı dosya yok
##   saat        gün = Missions.accepted_day (DailyRewards saat gerçeği); geri alınan saat geri gitmez;
##               ileri gün yeni meydan okuma; tamamlanma günü taban; gün gerçeği yoksa görünüm boş

const DIR: String = "user://qa_daily_challenge"
const PATH: String = DIR + "/save.json"
const TMP: String = PATH + SaveFile.TEMP_SUFFIX
const BAK: String = PATH + SaveFile.BACKUP_SUFFIX
const SECTIONS: int = 9
## Takvim: 2026-09-28 pazartesi.
const MON: String = "2026-09-28"
const TUE: String = "2026-09-29"
const WED: String = "2026-09-30"
const THU: String = "2026-10-01"
const FRI: String = "2026-10-02"
const SAT: String = "2026-10-03"
const SUN: String = "2026-10-04"
const NEXT_MON: String = "2026-10-05"
## Owner'ın kilitlediği test vektörü (2026-10-01, ilk iki torba).
const GOLDEN: Array[int] = [1, 3, 1, 1, 3, 2, 2, 3, 2, 1, 3, 3, 1, 2, 1, 2, 3, 2]
## Aynı algoritmanın BAĞIMSIZ (Python hashlib) uygulamasıyla hesaplanan ilk torbalar.
const INDEPENDENT: Dictionary = {
	"2026-09-28": [1, 2, 1, 2, 1, 3, 2, 3, 3],
	"2026-12-31": [1, 2, 3, 2, 3, 1, 1, 2, 3],
	"2027-01-01": [1, 1, 3, 1, 2, 3, 2, 2, 3],
	"2028-02-29": [2, 3, 2, 3, 1, 1, 2, 3, 1],
}
## Kilitli preset tablosu (pazartesi → pazar): hedef tier, kap genişliği, bırakış bütçesi.
const LOCKED: Array = [[5, 600.0, 18], [5, 480.0, 16], [6, 600.0, 38], [5, 420.0, 15], [6, 540.0, 36],
	[6, 480.0, 32], [6, 420.0, 30]]

var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _finished: bool = false
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}


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
	_c("başlangıç: SaveManager gerçek kayıt yolunda, hata enjeksiyonu kapalı",
		SaveManager.save_path == SaveManager.SAVE_PATH and SaveFile.fault == SaveFile.Fault.NONE)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	SaveManager.save_path = PATH
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 240 s'de bitmedi — SaveManager geri alındı")
			_teardown()
			get_tree().quit(2))

	_presets()
	_weekdays()
	_invalid_days()
	_sequence()
	_level_data()
	_block_rules()
	_persistence()
	_clock()
	_source_contract()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	print("-- kayıt")
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
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	randomize()
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- 1) Sabitler + preset tablosu -----------------------------------------------------------

func _presets() -> void:
	print("-- sabitler + kilitli preset tablosu")
	_c("ödül +20 Hamur, blok sürümü 1, dizi öneki 'sm-dc-v1', oynanabilir yükseklik 400",
		DailyChallenge.REWARD_DOUGH == 20 and DailyChallenge.VERSION == 1
		and DailyChallenge.SEQUENCE_PREFIX == "sm-dc-v1" and is_equal_approx(DailyChallenge.PLAYABLE_HEIGHT, 400.0))
	_c("yatışma sabitleri: 1.5 s merge'siz, 5.0 s mutlak tavan; level nöbetçisi 0",
		is_equal_approx(DailyChallenge.SETTLE_QUIET_SEC, 1.5) and is_equal_approx(DailyChallenge.SETTLE_CAP_SEC, 5.0)
		and DailyChallenge.LEVEL_SENTINEL == 0)
	_c("torba şablonu [1,1,1,2,2,2,3,3,3] (production DropBag bileşimi: tier başına 3 kopya)",
		_same(DailyChallenge.BAG_TEMPLATE, [1, 1, 1, 2, 2, 2, 3, 3, 3]) and DailyChallenge.BAG_SIZE == 9
		and _drop_bag_script().COPIES_PER_TIER == 3)
	var table_ok: bool = DailyChallenge.PRESETS.size() == 7
	for i in mini(DailyChallenge.PRESETS.size(), LOCKED.size()):
		var row: Dictionary = DailyChallenge.PRESETS[i]
		var want: Array = LOCKED[i]
		if int(row["target_tier"]) != int(want[0]) or not is_equal_approx(float(row["container_width"]), float(want[1])) \
				or int(row["drop_budget"]) != int(want[2]) or row.size() != 3:
			table_ok = false
			print("    uyuşmuyor: ", row, " ≠ ", want)
	_c("yedi preset birebir: Pzt T5·600·18 · Sal T5·480·16 · Çar T6·600·38 · Per T5·420·15 · Cum T6·540·36 · Cmt T6·480·32 · Paz T6·420·30",
		table_ok)
	var days: Array[String] = [MON, TUE, WED, THU, FRI, SAT, SUN]
	var desc_ok: bool = true
	for i in days.size():
		var view: Dictionary = DailyChallenge.descriptor(days[i])
		var want: Array = LOCKED[i]
		if view.is_empty() or int(view["weekday"]) != i or String(view["day_key"]) != days[i] \
				or int(view["target_tier"]) != int(want[0]) or not is_equal_approx(float(view["container_width"]), float(want[1])) \
				or int(view["drop_budget"]) != int(want[2]) or not is_equal_approx(float(view["playable_height"]), 400.0):
			desc_ok = false
			print("    tanım: ", days[i], " ", view)
	_c("2026-09-28 … 2026-10-04 (Pzt … Paz) tanımları tablonun satırları + yükseklik 400", desc_ok)
	_c("ana satır hedef adını TierConfig'ten alır: Pzt 'Büyük Dumpling yap · 18 hamlede', Çar 'Dev Dumpling yap · 38 hamlede'",
		DailyChallenge.goal_text(DailyChallenge.descriptor(MON)) == "Büyük Dumpling yap · 18 hamlede"
		and DailyChallenge.goal_text(DailyChallenge.descriptor(WED)) == "Dev Dumpling yap · 38 hamlede"
		and TierConfig.tier_name(5) == "Büyük Dumpling" and TierConfig.tier_name(6) == "Dev Dumpling")
	_c("T6 günlerinde 'Büyük Dumpling' yazmaz (Cum / Cmt / Paz → Dev Dumpling)",
		DailyChallenge.goal_text(DailyChallenge.descriptor(FRI)).begins_with("Dev Dumpling")
		and DailyChallenge.goal_text(DailyChallenge.descriptor(SAT)).begins_with("Dev Dumpling")
		and DailyChallenge.goal_text(DailyChallenge.descriptor(SUN)).begins_with("Dev Dumpling"))
	_c("yedi farklı gün en fazla 7 × 20 = 140 Hamur", 7 * DailyChallenge.REWARD_DOUGH == 140)
	var copy: Dictionary = DailyChallenge.preset_for(MON)
	copy["drop_budget"] = 99
	_c("preset kopya döner (tablo dışarıdan bozulamaz)", int(DailyChallenge.PRESETS[0]["drop_budget"]) == 18)
	_sections_done += 1


func _drop_bag_script() -> GDScript:
	return load("res://scripts/game/drop_bag.gd")


# --- 2) Hafta günü --------------------------------------------------------------------------

func _weekdays() -> void:
	print("-- kabul edilen gün → hafta günü (pazartesi 0)")
	var known: Dictionary = {MON: 0, TUE: 1, WED: 2, THU: 3, FRI: 4, SAT: 5, SUN: 6, NEXT_MON: 0,
		"2026-01-01": 3, "2026-12-27": 6, "2026-12-28": 0, "2026-12-31": 3, "2027-01-01": 4, "2027-01-03": 6,
		"2028-02-29": 1, "2000-01-01": 5, "2099-12-31": 3}
	var ok: bool = true
	for day: String in known:
		if DailyChallenge.weekday_index(day) != int(known[day]):
			ok = false
			print("    ", day, " → ", DailyChallenge.weekday_index(day), " (beklenen ", known[day], ")")
	_c("bilinen günler: hafta / ay / yıl sınırı, artık yıl, 2000, 2099", ok)
	var brute: bool = true
	var unix: int = Time.get_unix_time_from_datetime_string(MON + "T00:00:00")
	for i in 1200:
		var day: String = Time.get_date_string_from_unix_time(unix + i * Missions.SECONDS_PER_DAY)
		var index: int = DailyChallenge.weekday_index(day)
		if index != i % 7 or (index == 0) != (Missions.week_start(day) == day):
			brute = false
			print("    kaba kuvvet: ", day, " → ", index)
			break
	_c("1200 ardışık gün: sıra her gün +1 (mod 7), pazartesi = Missions.week_start günü", brute)
	_c("2026-10-01 perşembe → T5 · 420 · 15 (owner'ın test vektörü günü)",
		DailyChallenge.weekday_index(THU) == 3 and int(DailyChallenge.descriptor(THU)["drop_budget"]) == 15)
	_sections_done += 1


# --- 3) Geçersiz gün ---------------------------------------------------------------------------

func _invalid_days() -> void:
	print("-- geçersiz gün gerçeği → meydan okuma yok")
	var bad: Array = ["", "2026-02-29", "2026-13-01", "2026-9-28", "abc", "1999-12-31", "2026-04-31"]
	var ok: bool = true
	for day: String in bad:
		if DailyChallenge.weekday_index(day) != -1 or not DailyChallenge.descriptor(day).is_empty() \
				or not DailyChallenge.preset_for(day).is_empty() or DailyChallenge.make_level(day) != null \
				or DailyChallenge.can_complete(DailyChallenge.default_block(), day) \
				or DailyChallenge.effective_day(day, "") != "" or DailyChallenge.goal_text(DailyChallenge.descriptor(day)) != "":
			ok = false
			print("    geçersiz gün kabul edildi: '", day, "'")
	_c("boş / 29 Şubat 2026 / ay 13 / tek haneli ay / metin / 2000 öncesi / 31 Nisan: tanım yok, level yok, ödül yok",
		ok)
	_c("geçerli gün + bozuk tamamlanma günü → kabul edilen gün aynen", DailyChallenge.effective_day(THU, "bozuk") == THU
		and DailyChallenge.effective_day(THU, "") == THU)
	_sections_done += 1


# --- 4) Deterministik dizi + RNG yalıtımı -----------------------------------------------------

func _sequence() -> void:
	print("-- deterministik günlük dizi")
	_c("KİLİTLİ test vektörü: 2026-10-01 → 1,3,1,1,3,2,2,3,2 | 1,3,3,1,2,1,2,3,2",
		_same(DailyChallenge.sequence(THU, 18), GOLDEN))
	_c("  … torba 0 ve 1 ayrı ayrı aynı", DailyChallenge.sequence_bag(THU, 0) == GOLDEN.slice(0, 9)
		and DailyChallenge.sequence_bag(THU, 1) == GOLDEN.slice(9, 18))
	var independent_ok: bool = true
	for day: String in INDEPENDENT:
		if not _same(DailyChallenge.sequence_bag(day, 0), INDEPENDENT[day]):
			independent_ok = false
			print("    ", day, " → ", DailyChallenge.sequence_bag(day, 0))
	_c("bağımsız (Python hashlib) uygulamayla aynı: 4 gün, ay / yıl sınırı + artık yıl", independent_ok)
	var composition_ok: bool = true
	var unix: int = Time.get_unix_time_from_datetime_string(MON + "T00:00:00")
	var first_bags: Dictionary = {}
	for i in 400:
		var day: String = Time.get_date_string_from_unix_time(unix + i * Missions.SECONDS_PER_DAY)
		for b in 6:
			var bag: Array[int] = DailyChallenge.sequence_bag(day, b)
			if bag.size() != 9 or bag.count(1) != 3 or bag.count(2) != 3 or bag.count(3) != 3:
				composition_ok = false
			if b == 0:
				first_bags[str(bag)] = true
	_c("400 gün × 6 torba: her 9'luk torba tam 3·T1 + 3·T2 + 3·T3", composition_ok)
	_c("günler farklı diziler üretir (400 günün ilk torbalarında ≥ 300 farklı permütasyon)", first_bags.size() >= 300)
	_c("aynı gün tekrar = aynı dizi (60 parça, iki çağrı)", DailyChallenge.sequence(SAT, 60) == DailyChallenge.sequence(SAT, 60))
	var source := DailyChallenge.Sequence.new(THU)
	var drawn: Array[int] = []
	for i in 60:
		drawn.append(source.next_tier())
	_c("GameBoard kaynağı (next_tier) saf diziyle birebir; çekilen sayısı izlenir", drawn == DailyChallenge.sequence(THU, 60)
		and source.drawn() == 60 and source.day_key == THU)
	var again := DailyChallenge.Sequence.new(THU)
	_c("her deneme yeni kaynak = diziyi BAŞTAN verir", again.next_tier() == GOLDEN[0] and again.next_tier() == GOLDEN[1])
	_c("dizi uzunluğu tam (0 / 5 / 9 / 23)", DailyChallenge.sequence(THU, 0).is_empty()
		and DailyChallenge.sequence(THU, 5).size() == 5 and DailyChallenge.sequence(THU, 9).size() == 9
		and DailyChallenge.sequence(THU, 23).size() == 23)
	# Global RNG kontrol noktası: dizi üretimi global RNG'yi ne tüketir ne yeniden tohumlar.
	seed(424242)
	var expected: Array[int] = [randi(), randi(), randi()]
	seed(424242)
	for i in 50:
		DailyChallenge.sequence(Time.get_date_string_from_unix_time(unix + i * Missions.SECONDS_PER_DAY), 40)
	var src2 := DailyChallenge.Sequence.new(FRI)
	for i in 40:
		src2.next_tier()
	DailyChallenge.make_level(FRI)
	DailyChallenge.descriptor(SUN)
	_c("global RNG kontrol noktası DEĞİŞMEDİ (50 gün × 40 parça + kaynak + level sonrası aynı randi() akışı)",
		_same([randi(), randi(), randi()], expected))
	# Production DropBag: aynı tohum → aynı çekim; meydan okuma araya girse de.
	var bag_script: GDScript = _drop_bag_script()
	seed(77)
	var reference: Array[int] = _draw_bag(bag_script.new(), 30)
	seed(77)
	DailyChallenge.sequence(THU, 90)
	var src3 := DailyChallenge.Sequence.new(THU)
	for i in 27:
		src3.next_tier()
	var after: Array[int] = _draw_bag(bag_script.new(), 30)
	seed(78)
	var other: Array[int] = _draw_bag(bag_script.new(), 30)
	_c("production DropBag akışı meydan okumadan etkilenmez (aynı tohum → aynı 30 çekim)", after == reference)
	_c("  … DropBag hâlâ global RNG ile karıyor (farklı tohum → farklı akış; normal oyun taze rastgelelik)",
		other != reference)
	randomize()
	var fresh: Array[int] = _draw_bag(bag_script.new(), 27)
	var fresh_ok: bool = true
	for b in 3:
		var part: Array[int] = fresh.slice(b * 9, b * 9 + 9)
		if part.count(1) != 3 or part.count(2) != 3 or part.count(3) != 3:
			fresh_ok = false
	_c("  … DropBag bileşimi aynen (her 9 çekimde 3/3/3)", fresh_ok)
	_sections_done += 1


## Dizi karşılaştırması tür bilgisinden bağımsız (Array[int] ↔ düz dizi): metin biçimi.
func _same(a: Array, b: Array) -> bool:
	return str(a) == str(b)


## Yorumlar atılmış kaynak (belirteç taraması yalnız koda bakar; açıklamalar "seed()" diyebilir).
func _code_only(text: String) -> String:
	var out: PackedStringArray = []
	for line in text.split("\n"):
		var cut: int = line.find("#")
		out.append(line if cut < 0 else line.substr(0, cut))
	return "\n".join(out)


func _draw_bag(bag: RefCounted, count: int) -> Array[int]:
	var out: Array[int] = []
	for i in count:
		out.append(bag.next_tier())
	return out


# --- 5) Kodda kurulan LevelData -------------------------------------------------------------

func _level_data() -> void:
	print("-- meydan okuma LevelData (kodda, .tres yok)")
	var days: Array[String] = [MON, TUE, WED, THU, FRI, SAT, SUN]
	var ok: bool = true
	for i in days.size():
		var level: LevelData = DailyChallenge.make_level(days[i])
		var want: Array = LOCKED[i]
		if level == null or level.target_tier != int(want[0]) or not is_equal_approx(level.container_width, float(want[1])) \
				or not is_equal_approx(level.playable_height, 400.0) or level.is_endless or level.has_score_target() \
				or level.target_score != 0 or level.level_number != DailyChallenge.LEVEL_SENTINEL or level.resource_path != "":
			ok = false
			print("    ", days[i], " → ", level)
	_c("yedi gün: hedef / genişlik / yükseklik 400 / sonsuz değil / skor hedefi yok / nöbetçi 0 / diskte yolu yok", ok)
	_c("her çağrı YENİ örnek (paylaşılan / önbellekli level yok)", DailyChallenge.make_level(MON) != DailyChallenge.make_level(MON))
	var levels: Array[LevelData] = LevelLibrary.load_levels()
	var numbers: Array[int] = []
	for level in levels:
		numbers.append(level.level_number)
	_c("LevelLibrary aynen: 10 sabit level (1..10, 0 yok) + sonsuz", _same(numbers, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
		and LevelLibrary.load_endless() != null)
	var files: Array[String] = []
	for file_name in DirAccess.get_files_at(LevelLibrary.LEVELS_DIR):
		var clean: String = file_name.trim_suffix(".remap")
		if clean.ends_with(".tres"):
			files.append(clean)
	files.sort()
	_c("resources/levels'e meydan okuma .tres'i EKLENMEDİ (endless + level_01..10)", _same(files, ["endless.tres",
		"level_01.tres", "level_02.tres", "level_03.tres", "level_04.tres", "level_05.tres", "level_06.tres",
		"level_07.tres", "level_08.tres", "level_09.tres", "level_10.tres"]))
	_sections_done += 1


# --- 6) Blok doğrulama + saf kurallar ----------------------------------------------------------

func _block_rules() -> void:
	print("-- blok doğrulama + saf kurallar")
	var default: Dictionary = {"version": 1, "completed_day_key": ""}
	_c("varsayılan blok {version 1, completed_day_key ''}", DailyChallenge.default_block() == default)
	var junk: Array = [null, [], "x", 42, 1.5, {}, {"version": 2, "completed_day_key": THU},
		{"version": "1", "completed_day_key": THU}, {"version": 1.5, "completed_day_key": THU},
		{"completed_day_key": THU}]
	var junk_ok: bool = true
	for raw: Variant in junk:
		if DailyChallenge.sanitize(raw) != default:
			junk_ok = false
			print("    bozuk kabul edildi: ", raw)
	_c("sözlük değil / boş / sürüm yok / bilinmeyen sürüm (2, '1', 1.5) → varsayılan", junk_ok)
	_c("JSON float sürüm 1.0 kabul", DailyChallenge.sanitize({"version": 1.0, "completed_day_key": THU})
		== {"version": 1, "completed_day_key": THU})
	var bad_days: Array = ["2026-13-01", "2026-02-29", 20261001, null, "", "dün", ["2026-10-01"]]
	var day_ok: bool = true
	for value: Variant in bad_days:
		if String(DailyChallenge.sanitize({"version": 1, "completed_day_key": value})["completed_day_key"]) != "":
			day_ok = false
	_c("bozuk tamamlanma günü (ay 13 / 29 Şubat / sayı / null / metin / dizi) → tamamlanma yok", day_ok)
	var extra: Dictionary = DailyChallenge.sanitize({"version": 1, "completed_day_key": WED, "preset": {"t": 5},
		"drop_budget": 18, "seed": 99, "attempts": 4, "best": 17, "seen": true})
	_c("fazla anahtarlar (preset / bütçe / seed / deneme / en iyi / görüldü) düşer: tam 2 anahtar",
		extra == {"version": 1, "completed_day_key": WED})
	var block: Dictionary = {"version": 1, "completed_day_key": WED}
	_c("can_complete: boş blok + geçerli gün → evet; tamamlanan gün / eskisi → hayır; ertesi gün → evet",
		DailyChallenge.can_complete(DailyChallenge.default_block(), WED) and not DailyChallenge.can_complete(block, WED)
		and not DailyChallenge.can_complete(block, TUE) and not DailyChallenge.can_complete(block, MON)
		and DailyChallenge.can_complete(block, THU))
	_c("is_completed: tamamlanan gün ve eskisi tamam, ertesi gün değil, boş blok hiçbiri",
		DailyChallenge.is_completed(block, WED) and DailyChallenge.is_completed(block, MON)
		and not DailyChallenge.is_completed(block, THU) and not DailyChallenge.is_completed(DailyChallenge.default_block(), WED))
	_c("effective_day: kabul edilen gün tamamlanma gününün gerisine düşmez; ileri gün aynen",
		DailyChallenge.effective_day(TUE, WED) == WED and DailyChallenge.effective_day(THU, WED) == THU
		and DailyChallenge.effective_day(WED, WED) == WED)
	_sections_done += 1


# --- 7) Kayıt ------------------------------------------------------------------------------------

func _persistence() -> void:
	print("-- kayıt: göç, tek işlem, kurtarma")
	DailyRewards.clock_override = THU
	# a) Eski kayıt (blok yok): bellekte varsayılan, Hamur aynen, yüklemede yazma YOK.
	_write_fixture({})
	var before: PackedByteArray = _bytes()
	SaveFile.fault = SaveFile.Fault.TEMP_OPEN
	SaveManager.load_game()
	_c("eski kayıt → bellekte varsayılan blok (tamamlanma yok)", SaveManager.data.get("daily_challenge")
		== {"version": 1, "completed_day_key": ""} and SaveManager.daily_challenge_completed_day() == "")
	_c("  … geriye dönük ödül YOK (Hamur 335 aynen), yüklemede disk yazması / yazma girişimi YOK",
		SaveManager.dough() == 335 and _bytes() == before and SaveFile.fault == SaveFile.Fault.TEMP_OPEN)
	SaveFile.fault = SaveFile.Fault.NONE
	SaveManager.load_game()
	_c("  … ikinci yükleme aynı sonuç (idempotent)", SaveManager.daily_challenge_state() == DailyChallenge.default_block()
		and SaveManager.dough() == 335 and _bytes() == before)
	# b) Bozuk bloklar.
	var broken: Array = ["bozuk", [1, 2], {"version": 99, "completed_day_key": WED},
		{"version": 1, "completed_day_key": "2026-02-30"}, {"version": 1, "completed_day_key": 17}]
	var broken_ok: bool = true
	for raw: Variant in broken:
		_write_fixture({"daily_challenge": raw})
		before = _bytes()
		SaveManager.load_game()
		if SaveManager.daily_challenge_state() != DailyChallenge.default_block() or _bytes() != before \
				or SaveManager.data.get("daily_challenge") != DailyChallenge.default_block():
			broken_ok = false
			print("    bozuk blok: ", raw, " → ", SaveManager.data.get("daily_challenge"))
	_c("bozuk blok (metin / dizi / sürüm 99 / 30 Şubat / sayı) → varsayılan, yüklemede yazma yok", broken_ok)
	_write_fixture({"daily_challenge": {"version": 1, "completed_day_key": TUE, "seed": 5}})
	SaveManager.load_game()
	_c("geçerli blok aynen okunur, fazla anahtar bellekte düşer", SaveManager.daily_challenge_completed_day() == TUE
		and SaveManager.data["daily_challenge"] == {"version": 1, "completed_day_key": TUE})

	# c) İlk tamamlanma: tam +20 + gün, TEK yazma.
	_write_fixture({})
	SaveManager.load_game()
	before = _bytes()
	SaveFile.fault = SaveFile.Fault.TEMP_OPEN
	var granted: bool = SaveManager.complete_daily_challenge(THU)
	_c("tek atımlık yazma hatası: işlem TEK yazma denedi (hata tüketildi) ve disk değişmedi — gün ile +20 ayrı yazılmaz",
		granted and SaveFile.fault == SaveFile.Fault.NONE and _bytes() == before)
	SaveManager.load_game()
	_c("  … diskten yeniden yükleme: ne gün ne Hamur (işlem bölünmedi)", SaveManager.daily_challenge_completed_day() == ""
		and SaveManager.dough() == 335)
	granted = SaveManager.complete_daily_challenge(THU)
	var disk: Dictionary = _disk()
	_c("ilk tamamlanma: true, Hamur tam +20 (335 → 355), gün = 2026-10-01", granted and SaveManager.dough() == 355
		and SaveManager.daily_challenge_completed_day() == THU)
	var disk_block: Dictionary = disk.get("daily_challenge", {})
	_c("  … diskte ikisi birlikte (Hamur 355 + completed_day_key; JSON sürüm 1.0)", int(disk.get("dough", -1)) == 355
		and String(disk_block.get("completed_day_key", "")) == THU and int(disk_block.get("version", 0)) == 1)
	_c("  … ayrı 'ödül verildi' bayrağı / başka alan YOK (blok tam iki anahtar)",
		(disk.get("daily_challenge") as Dictionary).size() == 2)
	# d) Yinelenen / aynı / eski gün → +0, yazma YOK.
	before = _bytes()
	SaveFile.fault = SaveFile.Fault.TEMP_OPEN
	var dup: bool = SaveManager.complete_daily_challenge(THU)
	var older: bool = SaveManager.complete_daily_challenge(WED)
	var oldest: bool = SaveManager.complete_daily_challenge(MON)
	var invalid: bool = SaveManager.complete_daily_challenge("2026-13-01")
	_c("aynı gün tekrar / eski gün / geçersiz gün → false, +0, yazma girişimi YOK",
		not dup and not older and not oldest and not invalid and SaveManager.dough() == 355 and _bytes() == before
		and SaveFile.fault == SaveFile.Fault.TEMP_OPEN and SaveManager.daily_challenge_completed_day() == THU)
	SaveFile.fault = SaveFile.Fault.NONE
	# e) Yeni gün → +20.
	_c("ertesi gün → +20 (355 → 375), gün ilerler", SaveManager.complete_daily_challenge(FRI)
		and SaveManager.dough() == 375 and SaveManager.daily_challenge_completed_day() == FRI)
	# f) Yedi farklı gün en fazla +140.
	_write_fixture({})
	SaveManager.load_game()
	var unix: int = Time.get_unix_time_from_datetime_string(MON + "T00:00:00")
	var grants: int = 0
	for i in 7:
		var day: String = Time.get_date_string_from_unix_time(unix + i * Missions.SECONDS_PER_DAY)
		if SaveManager.complete_daily_challenge(day):
			grants += 1
		SaveManager.complete_daily_challenge(day)
	_c("yedi farklı gün (her biri iki kez): tam 7 ödül, +140 (335 → 475)", grants == 7 and SaveManager.dough() == 475)
	# g) Çökme pencereleri: gün ile Hamur hiçbir zaman ayrılmaz.
	var crash_ok: bool = true
	for fault in [SaveFile.Fault.CRASH_AFTER_TEMP, SaveFile.Fault.CRASH_AFTER_BACKUP, SaveFile.Fault.COMMIT,
			SaveFile.Fault.COMMIT_AND_ROLLBACK, SaveFile.Fault.BACKUP_MOVE, SaveFile.Fault.TEMP_SHORT]:
		_clean()
		_write_fixture({})
		SaveManager.load_game()
		SaveFile.fault = fault
		SaveManager.complete_daily_challenge(THU)
		SaveFile.fault = SaveFile.Fault.NONE
		SaveManager.load_game()
		var has_day: bool = SaveManager.daily_challenge_completed_day() == THU
		var has_dough: bool = SaveManager.dough() == 355
		if has_day != has_dough or (not has_day and SaveManager.dough() != 335):
			crash_ok = false
			print("    çökme ", fault, ": gün=", has_day, " Hamur=", SaveManager.dough())
	_c("çökme / yazma hatası pencerelerinde (6 aşama) yeniden açılış: gün ve +20 ya ikisi birden ya hiçbiri", crash_ok)
	# h) .tmp / .bak kurtarması bloğu taşır.
	_clean()
	_write_text(TMP, JSON.stringify(_fixture({"daily_challenge": {"version": 1, "completed_day_key": WED}}), "\t"))
	SaveManager.load_game()
	_c(".tmp kurtarması (kanonik yok) bloğu taşır", SaveManager.load_source() == SaveFile.Source.TEMP
		and SaveManager.daily_challenge_completed_day() == WED)
	_clean()
	_write_text(PATH, "{ bozuk")
	_write_text(BAK, JSON.stringify(_fixture({"daily_challenge": {"version": 1, "completed_day_key": TUE}}), "\t"))
	SaveManager.load_game()
	_c(".bak kurtarması (kanonik bozuk) bloğu taşır", SaveManager.load_source() == SaveFile.Source.BACKUP
		and SaveManager.daily_challenge_completed_day() == TUE)
	# i) Ayrı kayıt dosyası yok — ne test klasöründe ne user:// kökünde.
	_clean()
	_write_fixture({})
	SaveManager.load_game()
	var root_before: Array = Array(DirAccess.get_files_at("user://"))
	SaveManager.complete_daily_challenge(THU)
	SaveManager.complete_daily_challenge(FRI)
	var names: Array = Array(DirAccess.get_files_at(DIR))
	var only_family: bool = true
	for file_name: String in names:
		if not file_name in ["save.json", "save.json.bak", "save.json.tmp"]:
			only_family = false
	var root_after: Array = Array(DirAccess.get_files_at("user://"))
	root_before.sort()
	root_after.sort()
	_c("ayrı meydan okuma dosyası YOK (klasörde yalnız kayıt ailesi; user:// kökünde yeni dosya yok)",
		only_family and names.has("save.json") and root_after == root_before)
	DailyRewards.clock_override = ""
	_sections_done += 1


# --- 8) Saat gerçeği ------------------------------------------------------------------------------

func _clock() -> void:
	print("-- kabul edilen gün (tek saat gerçeği)")
	_clean()
	_write_fixture({})
	SaveManager.load_game()
	DailyRewards.clock_override = THU
	_c("gün = Missions.accepted_day() = DailyRewards.day_key() → 2026-10-01", DailyChallenge.current_day() == THU
		and DailyChallenge.current_day() == Missions.accepted_day())
	var view: Dictionary = DailyChallenge.current_view()
	_c("görünüm: perşembe preset'i, tamamlanmadı", not view.is_empty() and int(view["target_tier"]) == 5
		and int(view["drop_budget"]) == 15 and not bool(view["completed"]))
	_c("aynı gün yeniden okuma aynı meydan okuma", DailyChallenge.current_view() == view)
	# Saat geri: görülen en yeni gün (DailyRewards) korunur.
	SaveManager.record_daily_last_seen_day(SAT)
	DailyRewards.clock_override = THU
	_c("saat geri alındı (en yeni görülen cumartesi) → meydan okuma cumartesinin, geri gitmez",
		DailyChallenge.current_day() == SAT and int(DailyChallenge.current_view()["drop_budget"]) == 32)
	DailyRewards.clock_override = NEXT_MON
	_c("saat ileri → yeni gün açılır (pazartesi T5·600·18)", DailyChallenge.current_day() == NEXT_MON
		and int(DailyChallenge.current_view()["drop_budget"]) == 18)
	# Monoton gün (açık oturum): meydan okuma ileri günü KABUL edince gün gözlemi kayda işlenir; saat geri
	# alınınca meydan okuma kabul ettiği günün gerisine düşmez.
	_clean()
	_write_fixture({})
	SaveManager.load_game()
	DailyRewards.clock_override = THU
	DailyChallenge.current_day()
	var seen_before: String = SaveManager.daily_last_seen_day_key()
	DailyRewards.clock_override = FRI
	_c("açık oturumda saat D+1: meydan okuma D+1'i kabul etti ve gün gözlemi kayda işlendi (last_seen %s → cuma)"
		% seen_before, DailyChallenge.current_day() == FRI and SaveManager.daily_last_seen_day_key() == FRI)
	DailyRewards.clock_override = THU
	_c("  … saat D'ye geri: meydan okuma (ve gün gerçeği) D+1'de kalır, preset cuma T6·540·36",
		DailyChallenge.current_day() == FRI and Missions.accepted_day() == FRI
		and int(DailyChallenge.current_view()["drop_budget"]) == 36)
	DailyRewards.clock_override = "bozuk-saat"
	DailyChallenge.current_view()
	_c("  … geçersiz saat kayda yazılmaz (last_seen cuma kalır)", SaveManager.daily_last_seen_day_key() == FRI)
	# Tamamlanma günü taban: saat (ve en yeni gün) gerideyken tamamlanmış gün yeniden açılmaz.
	_clean()
	_write_fixture({"daily_challenge": {"version": 1, "completed_day_key": FRI}})
	SaveManager.load_game()
	DailyRewards.clock_override = THU
	view = DailyChallenge.current_view()
	_c("geri alınan saat tamamlanmış günü yeniden AÇMAZ: görünüm cuma, tamamlandı",
		String(view.get("day_key", "")) == FRI and bool(view.get("completed", false)))
	DailyRewards.clock_override = FRI
	_c("aynı gün: tamamlandı (tekrar oynanmaz)", bool(DailyChallenge.current_view()["completed"]))
	DailyRewards.clock_override = SAT
	_c("ertesi gün: yeni, tamamlanmamış meydan okuma", DailyChallenge.current_day() == SAT
		and not bool(DailyChallenge.current_view()["completed"]))
	DailyRewards.clock_override = "bozuk-saat"
	_c("gün gerçeği yok (cihaz saati + en yeni gün geçersiz) → görünüm boş, meydan okuma gizli",
		DailyChallenge.current_day() == "" and DailyChallenge.current_view().is_empty())
	DailyRewards.clock_override = ""
	_sections_done += 1


# --- 9) Kaynak sözleşmesi -------------------------------------------------------------------------

func _source_contract() -> void:
	print("-- kaynak sözleşmesi")
	var model: String = _code_only(FileAccess.get_file_as_string("res://scripts/game/daily_challenge.gd"))
	var forbidden: Array[String] = ["seed(", "randomize(", "randi", "randf", "shuffle(", "RandomNumberGenerator"]
	var clean: bool = model.length() > 0
	for token in forbidden:
		if model.contains(token):
			clean = false
			print("    yasak belirteç: ", token)
	_c("model rastgelelik kullanmaz: seed / randomize / randi / randf / shuffle / RandomNumberGenerator YOK", clean)
	_c("model ilerleme / ödül yazmaz, UI / reklam bilmez (save_game / add_dough / Monetization / AdEvents / XP yok)",
		not model.contains("save_game") and not model.contains("add_dough") and not model.contains("Monetization")
		and not model.contains("AdEvents") and not model.contains("player_xp") and not model.contains("record_round"))
	var day_fn: String = model.substr(model.find("static func current_day("))
	day_fn = day_fn.substr(0, day_fn.find("\nstatic func ", 1))
	_c("modelin TEK kayıt yolu gün gözlemi: `DailyRewards.observe_day()` bir kez, yalnız current_day içinde",
		model.count("observe_day(") == 1 and day_fn.contains("DailyRewards.observe_day()")
		and not model.contains("record_daily_") and not model.contains("mark_daily_"))
	var writers: Array[String] = []
	for path in _scripts("res://scripts"):
		var text: String = FileAccess.get_file_as_string(path)
		if text.contains("data[\"daily_challenge\"] =") or text.contains("completed_day_key\"] ="):
			writers.append(path.get_file())
	_c("blok yalnız SaveManager'da yazılır", _same(writers, ["save_manager.gd"]))
	_sections_done += 1


# --- Yardımcılar ----------------------------------------------------------------------------------

func _fixture(extra: Dictionary) -> Dictionary:
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 2},
		"endless_high_score": 0, "dough": 335, "total_merges": 40, "merges_since_bonus_chest": 10,
		"unlocked_skins": ["common_01"], "profile_showcase": [],
		"powerups": {"bomb": 2, "upgrade": 1, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "", "daily_streak": 3,
		"last_login_date": THU, "age_ad_band": "ADULT", "next_age_transition_date": "",
		"player_meta_version": 1, "player_xp": 400, "total_rounds_played": 12, "highest_tier_created": 5,
		"daily_rewards": {"day_key": THU, "free_chest_claimed": false, "ad_chests_claimed": 0,
			"dough_ad_claimed": false, "popup_seen_day": THU, "last_seen_day_key": THU}}
	for key: String in extra:
		content[key] = extra[key]
	return content


func _write_fixture(extra: Dictionary) -> void:
	_clean()
	_write_text(PATH, JSON.stringify(_fixture(extra), "\t"))


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _disk() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if parsed is Dictionary else {}


func _bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(PATH) if FileAccess.file_exists(PATH) else PackedByteArray()


func _scripts(root: String) -> Array[String]:
	var out: Array[String] = []
	for dir_name in DirAccess.get_directories_at(root):
		out.append_array(_scripts(root + "/" + dir_name))
	for file_name in DirAccess.get_files_at(root):
		if file_name.ends_with(".gd"):
			out.append(root + "/" + file_name)
	return out


func _clean() -> void:
	for path in [PATH, TMP, BAK]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for path in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out
