extends Node
## Stok 0 guc refill akisinin davranissal testi (M8.5-06; TASK/060: kota GUC BASINA gunde 2, dort bagimsiz
## sayac — senaryolar yeni kurala gore guncellendi, hicbiri silinmedi).
##
## Neden bir arac: reward callback guvenligi ("duplicate callback ikinci kez
## grant etmemeli", "stale token grant etmemeli", "yanlis guc icin gelen
## callback baska guce stok vermemeli") elle tiklayarak dogrulanamaz. Gunluk
## kota sifirlamasi da oyle — tarihi elle degistirmek gerekiyor.
##
## GERCEK REKLAM YOK: harness "odul kazanildi" callback'ini dogrudan
## Main.grant_rewarded_power(type, token) cagirarak simule ediyor.
## Production'da bu yol YOKTUR (bkz. scripts/ui/power_refill.gd).
##
## KAYIT DOSYASINA YAZAR. Calistirmadan once owner kaydini yedekle, sonra
## byte-identical geri yukle.
##
## Kullanim (cekim istenirse PENCERELI calismali):
##   godot --path . res://tools/refill_test.tscn -- <cikti_klasoru>
##   godot --headless --audio-driver Dummy --path . res://tools/refill_test.tscn

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

const SHOT_SIZE := Vector2i(540, 960)
const TEST_LEVEL: int = 1

var _out_dir: String = ""
var _shots: bool = false
var _main: Node2D
var _passed: int = 0
var _failed: int = 0
var _provider: TestProvider = null


## Rewarded saglayici TEST CIFTI (test double).
##
## GERCEK REKLAM DEGIL, zamanlayici da YOK: yalnizca Main'in provider'a
## hangi (type, token) ile gittigini kaydediyor. Harness "odul kazanildi"
## callback'ini bu token ile, gercek akisin uzerinden simule ediyor.
## Production'da boyle bir sinif YOKTUR — saglayici bagli degilse Main
## dogrudan notify_power_rewarded_unavailable() cagiriyor.
class TestProvider extends RefCounted:
	var calls: int = 0
	var last_type: int = -1
	var last_token: int = 0
	## Bos degilse: reklam gosterildi ama ODUL KAZANILMADI (ornegin oyuncu
	## kapatti ya da yuklenemedi).
	var fail_message: String = ""

	func show_rewarded_power(main: Node, type: int, token: int) -> void:
		calls += 1
		last_type = type
		last_token = token
		if not fail_message.is_empty():
			main.notify_power_rewarded_unavailable(fail_message)


func _ready() -> void:
	# Otomatik GÜNLÜK ÖDÜLLER penceresi (M8.9-02) bu harness'in konusu değil.
	DailyRewards.auto_popup_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_shots = args.size() >= 1
	if _shots:
		_out_dir = args[0]
		DirAccess.make_dir_recursive_absolute(_out_dir)
		DisplayServer.window_set_size(SHOT_SIZE)

	await get_tree().process_frame
	await _scenario_policy()
	await _scenario_modal_opens()
	await _scenario_dough_refill()
	await _scenario_dough_insufficient()
	await _scenario_rewarded_request_gives_nothing()
	await _scenario_valid_reward()
	await _scenario_callback_safety()
	await _scenario_quota_exhausted()
	await _scenario_quota_reset_and_restart()
	await _scenario_revive_and_shop_untouched()

	print("")
	print("=== SONUC: %d gecti / %d kaldi ===" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- Yardimcilar ---

func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("  [OK]   ", label)
	else:
		_failed += 1
		printerr("  [FAIL] ", label)


func _check_eq(label: String, actual: Variant, expected: Variant) -> void:
	_check("%s (beklenen %s, gelen %s)" % [label, expected, actual], actual == expected)


func _section(title: String) -> void:
	print("")
	print("--- ", title, " ---")


func _today() -> String:
	return RewardedPolicy.today()


## Kaydi bilinen bir noktadan baslatir; owner kaydi disaridan geri yukleniyor.
func _reset_save(dough: int = 0, stock: Dictionary = {}) -> void:
	SaveManager.data = SaveManager.DEFAULT_DATA.duplicate(true)
	SaveManager.data["powerup_starter_granted"] = false
	SaveManager._grant_starter_powerups()
	SaveManager.data["dough"] = dough
	# Tum stoklari istenen degere cek (varsayilan: hepsi 0).
	var powerups: Dictionary = {}
	for type in PowerUp.all():
		var key: String = PowerUp.save_key(type)
		powerups[key] = int(stock.get(key, 0))
	SaveManager.data["powerups"] = powerups
	SaveManager.data["rewarded_power_quota"] = RewardedPolicy.empty_block()
	# Gunluk giris odulunu BUGUN ALINMIS say: main.tscn her kurulusta
	# _check_daily_reward() calistiriyor ve aksi halde her _make_main()
	# cagrisi Hamur'a +15 ekleyip butun para olcumlerini kaydiriyor.
	SaveManager.data["last_login_date"] = _today()
	SaveManager.data["daily_streak"] = 1
	SaveManager.save_game()


func _stock() -> Array[int]:
	var out: Array[int] = []
	for type in PowerUp.all():
		out.append(SaveManager.powerup_count(type))
	return out


## `with_provider`: rewarded saglayici test cifti bagli olsun mu. false
## birakildiginda "saglayici yok" UI durumu test ediliyor.
func _make_main(with_provider: bool = false) -> void:
	await _free_main()
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	_provider = null
	if with_provider:
		_provider = TestProvider.new()
		_main.set_rewarded_provider(_provider)
	_main._start_level(load("res://resources/levels/level_%02d.tres" % TEST_LEVEL))
	await get_tree().process_frame


func _free_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null
	await get_tree().process_frame


func _board() -> Node2D:
	return _main._board


func _refill() -> CanvasLayer:
	return _main._refill


## Oyuncunun stok 0 bir guc butonuna basmasi.
func _press_power(type: PowerUp.Type) -> void:
	_board()._on_power_pressed(int(type))
	await get_tree().process_frame


func _capture(file_name: String) -> void:
	if not _shots:
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out_dir.path_join(file_name)
	var err: int = img.save_png(path)
	print(("  cekim  : " if err == OK else "  CEKIM HATASI: "), path)


# --- 1) Politika sabitleri ---

func _scenario_policy() -> void:
	_section("Senaryo 1: gunluk kota politikasi tek tanim noktasinda (TASK/060: guc basina 2)")
	_reset_save()
	_check_eq("gunluk cap guc basina 2", RewardedPolicy.daily_cap(), 2)
	var all_zero: bool = true
	for type in PowerUp.all():
		all_zero = all_zero and RewardedPolicy.grants_today(type) == 0 \
			and RewardedPolicy.remaining_today(type) == RewardedPolicy.daily_cap() and RewardedPolicy.can_grant(type)
	_check("yeni kayitta dort gucun her biri 0 grant, kalan hak = cap, can_grant true", all_zero)
	# Kota GUC BASINA (owner, Issue #1 §3), dort gucun toplami DEGIL.
	_check("kota guc basina (tek sabit), eski ortak sabit yok",
		RewardedPolicy.DAILY_GRANTS_PER_POWER == RewardedPolicy.daily_cap()
		and not FileAccess.get_file_as_string("res://scripts/game/rewarded_policy.gd").contains("const DAILY_POWER_REFILLS"))


# --- 2) Modal ne zaman acilir ---

func _scenario_modal_opens() -> void:
	_section("Senaryo 2: stok 0 -> modal acilir, stok > 0 -> acilmaz")
	# Stok > 0: normal guc akisi, modal YOK.
	_reset_save(0, {"bomb": 2})
	await _make_main()
	await _press_power(PowerUp.Type.BOMB)
	_check("stok>0: refill modali ACILMADI", not _refill().visible)
	_check("stok>0: board durmadi", not _board().is_refill_pending())
	_check("stok>0: hedefleme acildi (normal akis)",
		_board()._powerups.is_armed())
	_board()._powerups.cancel()

	# Stok 0: modal acilir ve oyun DURUR.
	_reset_save(500)
	await _make_main()
	_check_eq("stok gercekten 0",
		SaveManager.powerup_count(PowerUp.Type.BOMB), 0)
	await _press_power(PowerUp.Type.BOMB)
	_check("stok0: refill modali acildi", _refill().visible)
	_check("stok0: dogru guc gosteriliyor",
		_refill().current_type() == int(PowerUp.Type.BOMB))
	_check("stok0: board DURDU", _board().is_refill_pending())
	_check("stok0: guc cubugu kapali", not _board()._power_bar._enabled)
	_check("stok0: hicbir guc silahlanmadi", not _board()._powerups.is_armed())
	_check("stok0: stok hala 0", _stock() == ([0, 0, 0, 0] as Array[int]))
	await _capture("f01_refill_modal.png")

	# Reklam CTA'si saglayici olmadigi icin pasif, Hamur CTA'si aktif.
	_check("saglayici yok -> reklam CTA pasif", _refill()._ad.disabled)
	_check("Hamur yeterli -> Hamur CTA aktif", not _refill()._dough.disabled)
	_check("kota cipi BASARILI kullanim 0/2 gosteriyor", _refill().quota_text() == "0/2")
	# TASK/060: fiyat Hamur dugmesinde yalniz rakam (`price_text()`), tek kaynak PowerUpEconomy.
	_check("gercek fiyat gosteriliyor",
		_refill().price_text() == str(PowerUpEconomy.price(PowerUp.Type.BOMB)))
	await _capture("f02_saglayici_yok.png")

	# Board donmus mu: birkac yuz kare hicbir sey oynamamali.
	var before: Array = _positions()
	for i in 120:
		await get_tree().process_frame
	_check("modal acikken board hic oynamadi", _positions() == before)

	# Kapat -> oyun devam, hicbir sey alinmadi.
	_main._on_refill_closed()
	await get_tree().process_frame
	_check("kapat: modal kapandi", not _refill().visible)
	_check("kapat: board devam ediyor", not _board().is_refill_pending())
	_check("kapat: guc cubugu tekrar acik", _board()._power_bar._enabled)
	_check("kapat: stok degismedi", _stock() == ([0, 0, 0, 0] as Array[int]))
	_check_eq("kapat: kota tuketilmedi", RewardedPolicy.grants_today(PowerUp.Type.BOMB), 0)


func _positions() -> Array:
	var out: Array = []
	for node in _board()._dumpling_layer.get_children():
		var d := node as Dumpling
		if d != null and is_instance_valid(d) and not d.is_queued_for_deletion():
			out.append(d.global_position.snapped(Vector2(0.01, 0.01)))
	return out


# --- 3) Hamurla refill ---

func _scenario_dough_refill() -> void:
	_section("Senaryo 3: Hamurla refill calisiyor")
	var t: PowerUp.Type = PowerUp.Type.UPGRADE
	var price: int = PowerUpEconomy.price(t)
	_reset_save(price + 40)
	await _make_main()
	await _press_power(t)
	_check("modal acildi", _refill().visible)

	_main._on_dough_refill_requested(int(t))
	await get_tree().process_frame

	_check_eq("stok +1", SaveManager.powerup_count(t), 1)
	_check_eq("Hamur tam fiyat kadar dustu", SaveManager.dough(), 40)
	_check("modal kapandi", not _refill().visible)
	_check("board devam ediyor", not _board().is_refill_pending())
	_check_eq("kota TUKETILMEDI (Hamur yolu)",
		RewardedPolicy.grants_today(t), 0)
	# Niyet geri donusu: HEDEFLI guc -> hedefleme yeniden acilir.
	_check("hedefli guc: niyet korundu, hedefleme acildi",
		_board()._powerups.is_armed())
	_check_eq("hedefleme dogru guc icin",
		_board()._powerups.armed_type(), int(t))
	_check("power bar guncellendi",
		_board()._power_bar.displayed_count(int(t)) == 1)
	await _capture("f03_hamur_refill_sonrasi.png")
	_board()._powerups.cancel()

	# ANINDA calisan guc: stok geliyor ama OTOMATIK CALISMIYOR.
	var inst: PowerUp.Type = PowerUp.Type.CLEAR_SMALL
	_reset_save(PowerUpEconomy.price(inst))
	await _make_main()
	await _press_power(inst)
	_main._on_dough_refill_requested(int(inst))
	await get_tree().process_frame
	_check_eq("aninda guc: stok +1", SaveManager.powerup_count(inst), 1)
	_check("aninda guc: OTOMATIK HARCANMADI (stok duruyor)",
		SaveManager.powerup_count(inst) == 1)
	_check("aninda guc: hedefleme acilmadi", not _board()._powerups.is_armed())


# --- 4) Yetersiz Hamur ---

func _scenario_dough_insufficient() -> void:
	_section("Senaryo 4: yetersiz Hamur -> HICBIR sey degismez")
	var t: PowerUp.Type = PowerUp.Type.SHAKE
	_reset_save(PowerUpEconomy.price(t) - 1)
	await _make_main()
	await _press_power(t)
	var dough_before: int = SaveManager.dough()

	# TASK/060 V3: yetersiz Hamur = INSUFFICIENT (dokunulabilir, soluk; basis kisa geri bildirim verir, hicbir sey
	# alinmaz) + karoda "Hamur yetersiz".
	_check("yetersiz Hamur -> CTA INSUFFICIENT + sebep",
		_refill()._dough.state() == SquishyButton.State.INSUFFICIENT
		and _refill().dough_note_text() == _refill().NOTE_NO_DOUGH)
	_main._on_dough_refill_requested(int(t))
	await get_tree().process_frame

	_check("stok degismedi", _stock() == ([0, 0, 0, 0] as Array[int]))
	_check_eq("Hamur degismedi", SaveManager.dough(), dough_before)
	_check("modal ACIK kaldi", _refill().visible)
	_check("board hala durmus", _board().is_refill_pending())
	_check_eq("kota tuketilmedi", RewardedPolicy.grants_today(t), 0)
	# TASK/060: sebep tek yerde — Hamur karosunda "Hamur yetersiz" (+ ui_invalid); altlikta ikinci kopya yok.
	_check("basis geri bildirimi: karo sebebi 'Hamur yetersiz', altlik bos (tek sebep)",
		_refill().dough_note_text() == _refill().NOTE_NO_DOUGH and _refill().note_text() == "")
	await _capture("f04_hamur_yetmiyor.png")


# --- 5) Reklam TALEBI hicbir sey vermez ---

func _scenario_rewarded_request_gives_nothing() -> void:
	_section("Senaryo 5: reklam talebi / unavailable -> stok ve kota degismez")
	var t: PowerUp.Type = PowerUp.Type.BOMB

	# (a) SAGLAYICI YOK: talep aninda "unavailable"a dusuyor.
	_reset_save(0)
	await _make_main()
	await _press_power(t)
	_main._on_rewarded_power_requested(int(t))
	await get_tree().process_frame
	_check("saglayici yok: stok ARTMADI", _stock() == ([0, 0, 0, 0] as Array[int]))
	_check_eq("saglayici yok: kota tuketilmedi", RewardedPolicy.grants_today(t), 0)
	_check("saglayici yok: modal acik kaldi", _refill().visible)
	_check("saglayici yok: board hala durmus", _board().is_refill_pending())
	_check("saglayici yok: bekleyen talep temizlendi",
		_main._refill_pending_token == 0)

	# (b) SAGLAYICI VAR, reklam gosterildi ama ODUL KAZANILMADI.
	_reset_save(0)
	await _make_main(true)
	_provider.fail_message = "Reklam odulsuz kapandi."
	await _press_power(t)
	_main._on_rewarded_power_requested(int(t))
	await get_tree().process_frame

	_check_eq("reklam gosterildi", _provider.calls, 1)
	var shown_token: int = _provider.last_token
	_check("saglayiciya token gitti", shown_token > 0)
	_check("odulsuz kapanma: stok ARTMADI",
		_stock() == ([0, 0, 0, 0] as Array[int]))
	_check_eq("odulsuz kapanma: kota tuketilmedi",
		RewardedPolicy.grants_today(t), 0)
	_check("odulsuz kapanma: modal acik", _refill().visible)
	_check("odulsuz kapanma: board hala durmus", _board().is_refill_pending())
	# Basarisiz reklamin token'i artik gecersiz: gec gelen bir odul
	# callback'i stok VEREMEZ.
	_check("basarisiz reklamin token'i grant ETMIYOR",
		not _main.grant_rewarded_power(int(t), shown_token))
	_check("stok hala 0", _stock() == ([0, 0, 0, 0] as Array[int]))
	_check_eq("kota hala 0", RewardedPolicy.grants_today(t), 0)


# --- 6) Gecerli reward callback ---

func _scenario_valid_reward() -> void:
	_section("Senaryo 6: gecerli reward callback -> tam +1, BU gucun sayaci tam 1 artar")
	var t: PowerUp.Type = PowerUp.Type.CLEAR_SMALL
	_reset_save(0)
	await _make_main(true)
	await _press_power(t)
	# Saglayici bagliyken reklam CTA'si AKTIF olmali (f02'deki "bagli degil"
	# durumunun karsiti).
	_check("saglayici bagli -> reklam CTA aktif", not _refill()._ad.disabled)
	_check("kota cipi 0/2", _refill().quota_text() == "0/2")
	await _capture("f07_rewarded_musait.png")

	_main._on_rewarded_power_requested(int(t))
	var token: int = _provider.last_token
	_check("talep bir token uretti", token > 0)
	_check_eq("saglayiciya dogru guc gitti", _provider.last_type, int(t))

	_check("gecerli callback grant etti",
		_main.grant_rewarded_power(int(t), token))
	await get_tree().process_frame

	_check_eq("stok TAM +1", SaveManager.powerup_count(t), 1)
	_check("diger gucler etkilenmedi",
		SaveManager.powerup_count(PowerUp.Type.BOMB) == 0
			and SaveManager.powerup_count(PowerUp.Type.UPGRADE) == 0)
	_check_eq("bu gucun sayaci TAM 1", RewardedPolicy.grants_today(t), 1)
	_check_eq("bu gucun kalan hakki 1 (2 - 1)", RewardedPolicy.remaining_today(t), 1)
	_check("diger gucelerin sayaci 0", RewardedPolicy.grants_today(PowerUp.Type.BOMB) == 0
		and RewardedPolicy.grants_today(PowerUp.Type.SHAKE) == 0)
	_check("modal kapandi", not _refill().visible)
	_check("board devam ediyor", not _board().is_refill_pending())
	_check("power bar guncellendi",
		_board()._power_bar.displayed_count(int(t)) == 1)
	_check_eq("Hamur DEGISMEDI (reklam bedava)", SaveManager.dough(), 0)


# --- 7) Callback guvenligi: duplicate / stale / yanlis tip ---

func _scenario_callback_safety() -> void:
	_section("Senaryo 7: duplicate / stale / yanlis guc callback'i")
	var t: PowerUp.Type = PowerUp.Type.BOMB
	_reset_save(0)
	await _make_main(true)
	await _press_power(t)
	_main._on_rewarded_power_requested(int(t))
	var token: int = _provider.last_token

	_check("ilk callback grant etti", _main.grant_rewarded_power(int(t), token))
	_check_eq("stok 1", SaveManager.powerup_count(t), 1)

	# DUPLICATE: ayni callback ikinci kez.
	_check("DUPLICATE callback grant ETMEDI",
		not _main.grant_rewarded_power(int(t), token))
	_check_eq("duplicate sonrasi stok hala 1", SaveManager.powerup_count(t), 1)
	_check_eq("duplicate sonrasi kota hala 1", RewardedPolicy.grants_today(t), 1)

	# STALE: eski/uydurma token.
	_check("STALE token grant ETMEDI",
		not _main.grant_rewarded_power(int(t), token - 1))
	_check("token 0 grant ETMEDI", not _main.grant_rewarded_power(int(t), 0))
	_check("gelecekteki token grant ETMEDI",
		not _main.grant_rewarded_power(int(t), token + 99))
	_check_eq("stale denemeler sonrasi stok hala 1",
		SaveManager.powerup_count(t), 1)

	# YANLIS TIP: acik talep baska guc icinken gelen callback.
	_reset_save(0)
	await _make_main(true)
	await _press_power(PowerUp.Type.SHAKE)
	_main._on_rewarded_power_requested(int(PowerUp.Type.SHAKE))
	var token2: int = _provider.last_token
	_check("YANLIS guc callback'i grant ETMEDI",
		not _main.grant_rewarded_power(int(PowerUp.Type.UPGRADE), token2))
	_check("yanlis guc: hicbir stok artmadi",
		_stock() == ([0, 0, 0, 0] as Array[int]))
	_check("yanlis guc: hicbir gucun kotasi tuketilmedi", RewardedPolicy.grants_today(PowerUp.Type.UPGRADE) == 0
		and RewardedPolicy.grants_today(PowerUp.Type.SHAKE) == 0)
	_check("gecersiz tip (99) grant ETMEDI",
		not _main.grant_rewarded_power(99, token2))
	# Dogru tip hala calismali.
	_check("dogru tip callback'i hala calisiyor",
		_main.grant_rewarded_power(int(PowerUp.Type.SHAKE), token2))
	_check_eq("dogru guce +1",
		SaveManager.powerup_count(PowerUp.Type.SHAKE), 1)


# --- 8) Kota dolunca ---

func _scenario_quota_exhausted() -> void:
	_section("Senaryo 8: bir gucun gunluk kotasi (2) dolunca o gucun rewarded CTA'si kapali, Hamur acik, diger gucler acik")
	var t: PowerUp.Type = PowerUp.Type.BOMB
	_reset_save(PowerUpEconomy.price(t) + 10)
	await _make_main(true)

	# Bu gucun kotasini harca (iki basarili odul).
	for i in 2:
		await _press_power(t)
		_main._on_rewarded_power_requested(int(t))
		_main.grant_rewarded_power(int(t), _provider.last_token)
		await get_tree().process_frame
		SaveManager.consume_powerup(t)
		_board()._powerups.cancel()
	_check_eq("bu gucun kotasi doldu", RewardedPolicy.remaining_today(t), 0)
	_check("bu guc icin can_grant false", not RewardedPolicy.can_grant(t))
	_check("diger gucler icin can_grant hala true (bagimsiz sayac)", RewardedPolicy.can_grant(PowerUp.Type.SHAKE)
		and RewardedPolicy.can_grant(PowerUp.Type.UPGRADE) and RewardedPolicy.can_grant(PowerUp.Type.CLEAR_SMALL))

	# Stok 0, tekrar bas.
	_check_eq("stok tekrar 0", SaveManager.powerup_count(t), 0)
	await _press_power(t)
	_check("modal tekrar acildi", _refill().visible)
	_check("kota dolu -> reklam CTA PASIF", _refill()._ad.disabled)
	_check("kota dolu -> Hamur CTA hala AKTIF", not _refill()._dough.disabled)
	_check("kota cipi 2/2 + 'bugunluk bitti' notu", _refill().quota_text() == "2/2"
		and _refill().ad_note_text() == _refill().NOTE_QUOTA_USED)
	await _capture("f05_kota_dolu.png")

	# Kota dolu iken talep gelse bile grant olmamali.
	_main._on_rewarded_power_requested(int(t))
	await get_tree().process_frame
	_check_eq("kota dolu: stok artmadi", SaveManager.powerup_count(t), 0)
	_check_eq("kota dolu: grant sayaci 2'de kaldi",
		RewardedPolicy.grants_today(t), 2)

	# Hamur yolu hala calisiyor.
	_main._on_dough_refill_requested(int(t))
	await get_tree().process_frame
	_check_eq("kota dolu iken Hamurla alinabiliyor",
		SaveManager.powerup_count(t), 1)
	_check_eq("Hamur dustu", SaveManager.dough(), 10)
	await _capture("f06_hamur_refill_power_bar.png")
	_board()._powerups.cancel()
	# Bomba 2/2 iken Sarsinti penceresi: reklam CTA'si ACIK, kendi 0/2'si.
	await _press_power(PowerUp.Type.SHAKE)
	_check("Bomba 2/2 iken Sarsinti: reklam CTA aktif, 0/2", _refill().visible and not _refill()._ad.disabled
		and _refill().quota_text() == "0/2")
	_main._on_refill_closed()
	await get_tree().process_frame


# --- 9) Gun donusu ve restart ---

func _scenario_quota_reset_and_restart() -> void:
	_section("Senaryo 9: yeni gun kotayi sifirlar, restart korur")
	var t: PowerUp.Type = PowerUp.Type.BOMB
	_reset_save(0)
	await _make_main(true)
	for i in 2:
		SaveManager.data["powerups"]["bomb"] = 0
		await _press_power(t)
		_main._on_rewarded_power_requested(int(t))
		_main.grant_rewarded_power(int(t), _provider.last_token)
		await get_tree().process_frame
		_board()._powerups.cancel()
	_check_eq("bu gucun kotasi kullanildi (2/2)", RewardedPolicy.grants_today(t), 2)

	# RESTART: diskten yeniden oku — ayni gun, kota KORUNMALI.
	SaveManager.load_game()
	await get_tree().process_frame
	_check_eq("restart sonrasi kota KORUNDU (ayni gun)",
		RewardedPolicy.grants_today(t), 2)
	_check("restart sonrasi can_grant hala false", not RewardedPolicy.can_grant(t))
	_check_eq("restart sonrasi stok korundu", SaveManager.powerup_count(t), 1)

	# ROUND degisimi kotayi sifirlamamali.
	_main._start_level(load("res://resources/levels/level_%02d.tres" % TEST_LEVEL))
	await get_tree().process_frame
	_check_eq("yeni round kotayi SIFIRLAMADI",
		RewardedPolicy.grants_today(t), 2)

	# YENI GUN: kota blogunun gununu geriye al -> dort sayac okumada 0.
	SaveManager.data["rewarded_power_quota"]["day_key"] = "2020-01-01"
	_check_eq("baska gun -> kota 0", RewardedPolicy.grants_today(t), 0)
	_check("baska gun -> can_grant true", RewardedPolicy.can_grant(t))
	_check_eq("kalan hak tekrar cap", RewardedPolicy.remaining_today(t),
		RewardedPolicy.daily_cap())
	# Okuma kayda YAZMAMALI (beklenmedik disk yazmasi olmasin).
	_check_eq("kota okumasi kayda yazmadi",
		String(SaveManager.data["rewarded_power_quota"]["day_key"]), "2020-01-01")

	# Yeni gunde tekrar grant edilebilmeli.
	SaveManager.data["powerups"]["bomb"] = 0
	await _press_power(t)
	_main._on_rewarded_power_requested(int(t))
	_check("yeni gunde grant calisiyor",
		_main.grant_rewarded_power(int(t), _provider.last_token))
	_check_eq("yeni gun sayaci 1", RewardedPolicy.grants_today(t), 1)
	_check_eq("kayitta bugunun tarihi",
		String(SaveManager.data["rewarded_power_quota"]["day_key"]), _today())


# --- 10) Revive ve magaza bozulmadi ---

func _scenario_revive_and_shop_untouched() -> void:
	_section("Senaryo 10: revive haklari ve magaza satin alma etkilenmedi")
	_reset_save(5000)
	await _make_main(true)

	# Revive hakki guc kotasindan BAGIMSIZ.
	_check_eq("revive hakki hala 2", _board().max_revives(), 2)
	_check_eq("round basinda kullanilan revive 0", _board().revives_used(), 0)

	# Bir gucun kotasini tuket, revive etkilenmemeli.
	for i in 2:
		SaveManager.data["powerups"]["bomb"] = 0
		await _press_power(PowerUp.Type.BOMB)
		_main._on_rewarded_power_requested(int(PowerUp.Type.BOMB))
		_main.grant_rewarded_power(int(PowerUp.Type.BOMB), _provider.last_token)
		await get_tree().process_frame
		_board()._powerups.cancel()
	_check_eq("Bomba kotasi doldu", RewardedPolicy.remaining_today(PowerUp.Type.BOMB), 0)
	_check_eq("revive hakki DEGISMEDI", _board().revives_used(), 0)
	_check_eq("revive tavani DEGISMEDI", _board().max_revives(), 2)

	# Magazadan guc satin alma hala calisiyor ve kotaya DOKUNMUYOR.
	var before_quota: int = RewardedPolicy.grants_today(PowerUp.Type.UPGRADE)
	var before_stock: int = SaveManager.powerup_count(PowerUp.Type.UPGRADE)
	_check("magazadan guc alindi",
		PowerUpEconomy.purchase(PowerUp.Type.UPGRADE))
	_check_eq("magaza satin almasi stok verdi",
		SaveManager.powerup_count(PowerUp.Type.UPGRADE), before_stock + 1)
	_check_eq("magaza satin almasi kotaya DOKUNMADI",
		RewardedPolicy.grants_today(PowerUp.Type.UPGRADE), before_quota)

	# Skin satin alma bozulmadi.
	var skins: Array[SkinData] = SkinLibrary.all()
	if not skins.is_empty():
		var skin: SkinData = skins[0]
		_check("skin satin alma calisiyor", Shop.purchase(skin))
		_check("skin koleksiyonda", SaveManager.owns_skin(skin.id))

	# Starter hediyesi tekrar verilmiyor.
	var stock_before: Array[int] = _stock()
	for i in 3:
		SaveManager.load_game()
	_check("3 kez load: starter x1 TEKRAR VERILMEDI", _stock() == stock_before)

	await _free_main()
