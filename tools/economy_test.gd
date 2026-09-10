extends Node
## Guc/skin satin alma ekonomisinin davranissal testi (M8.5-05).
##
## Neden bir arac: para + odul iki ayri kayit yazmasi olarak yapilirsa
## aradaki bir cokme Hamur'u yakip odulu vermeyebilir. Bunu ve "yetersiz
## Hamur hicbir seyi degistirmemeli" gibi invariant'lari elle tiklayarak
## guvenilir dogrulamak mumkun degil.
##
## KAYIT DOSYASINA YAZAR: testler gercek SaveManager uzerinde calisiyor.
## Calistirmadan once owner kaydini yedekle, sonra byte-identical geri yukle.
##
## Kullanim:
##   godot --headless --audio-driver Dummy --path . res://tools/economy_test.tscn

const SHOP_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/shop_screen.tscn")
const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_scenario_prices()
	_scenario_purchase_happy_path()
	_scenario_insufficient_dough()
	_scenario_invalid_input()
	_scenario_single_grant()
	await _scenario_persistence()
	_scenario_skin_purchase()
	_scenario_chest_economy_untouched()
	_scenario_starter_not_regranted()
	await _scenario_shop_ui()
	await _scenario_power_bar()

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


## Testin bilinen bir noktadan baslamasi icin kaydi sifirdan kurar.
## Owner kaydi disaridan yedeklenip geri yuklendigi icin guvenli.
func _reset_save(dough: int = 0) -> void:
	SaveManager.data = SaveManager.DEFAULT_DATA.duplicate(true)
	SaveManager.data["powerup_starter_granted"] = false
	SaveManager._grant_starter_powerups()
	SaveManager.data["dough"] = dough
	SaveManager.save_game()


func _stock() -> Array[int]:
	var out: Array[int] = []
	for type in PowerUp.all():
		out.append(SaveManager.powerup_count(type))
	return out


# --- 1) Fiyatlar tek kaynaktan ---

func _scenario_prices() -> void:
	_section("Senaryo 1: fiyatlar tek tanim noktasindan geliyor")
	_check_eq("dort guc icin fiyat tanimli",
		PowerUpEconomy.DOUGH_PRICES.size(), PowerUp.all().size())
	for type in PowerUp.all():
		_check("%s fiyati pozitif (%d)" % [
			PowerUp.display_name(type), PowerUpEconomy.price(type)],
			PowerUpEconomy.price(type) > 0)
	# Simulatorle ayni set olmali (tools/shop_economy.py POWER_PRICES).
	var expected_prices: Array[int] = [120, 180, 100, 160]
	_check("production fiyat seti [120,180,100,160]",
		PowerUpEconomy.DOUGH_PRICES == expected_prices)
	# Deger siralamasi: Buyutucu en pahali, Sarsinti en ucuz.
	_check("Buyutucu en pahali guc",
		PowerUpEconomy.price(PowerUp.Type.UPGRADE)
			== PowerUpEconomy.DOUGH_PRICES.max())
	_check("Sarsinti en ucuz guc",
		PowerUpEconomy.price(PowerUp.Type.SHAKE)
			== PowerUpEconomy.DOUGH_PRICES.min())


# --- 2) Yeterli Hamur ---

func _scenario_purchase_happy_path() -> void:
	_section("Senaryo 2: yeterli Hamur -> stok +1, Hamur dogru duser")
	for type in PowerUp.all():
		var price: int = PowerUpEconomy.price(type)
		_reset_save(price + 37)          # 37 = artik, tam bolunmesin
		var before: int = SaveManager.powerup_count(type)

		_check("%s: satin alma basarili" % PowerUp.display_name(type),
			PowerUpEconomy.purchase(type))
		_check_eq("%s: stok +1" % PowerUp.display_name(type),
			SaveManager.powerup_count(type), before + 1)
		_check_eq("%s: Hamur tam fiyat kadar dustu" % PowerUp.display_name(type),
			SaveManager.dough(), 37)

	# Coklu adet: tek cagri, tek islem.
	var t: PowerUp.Type = PowerUp.Type.BOMB
	_reset_save(PowerUpEconomy.price(t) * 3)
	var start: int = SaveManager.powerup_count(t)
	_check("amount=3 satin alma", PowerUpEconomy.purchase(t, 3))
	_check_eq("amount=3 stok +3", SaveManager.powerup_count(t), start + 3)
	_check_eq("amount=3 Hamur 0'a indi", SaveManager.dough(), 0)


# --- 3) Yetersiz Hamur ---

func _scenario_insufficient_dough() -> void:
	_section("Senaryo 3: yetersiz Hamur -> HICBIR sey degismez")
	for type in PowerUp.all():
		var price: int = PowerUpEconomy.price(type)
		_reset_save(price - 1)
		var stock_before: Array[int] = _stock()
		var dough_before: int = SaveManager.dough()

		_check("%s: 1 eksik Hamurla satin alma reddedildi"
			% PowerUp.display_name(type), not PowerUpEconomy.purchase(type))
		_check("%s: stok degismedi" % PowerUp.display_name(type),
			_stock() == stock_before)
		_check_eq("%s: Hamur degismedi" % PowerUp.display_name(type),
			SaveManager.dough(), dough_before)
		_check("%s: can_afford false" % PowerUp.display_name(type),
			not PowerUpEconomy.can_afford(type))

	# Hamur ASLA negatife inmemeli.
	_reset_save(0)
	for type in PowerUp.all():
		PowerUpEconomy.purchase(type)
		PowerUpEconomy.purchase(type, 5)
	_check_eq("sifir Hamurla tekrar tekrar denendi, Hamur hala 0",
		SaveManager.dough(), 0)
	_check("negatif Hamur yok", SaveManager.dough() >= 0)

	# Coklu adet parasi yetmiyorsa KISMEN de alinmamali.
	var t: PowerUp.Type = PowerUp.Type.UPGRADE
	_reset_save(PowerUpEconomy.price(t) * 2)
	var stock_before2: Array[int] = _stock()
	_check("3 adet icin para yetmiyor -> tamami reddedildi",
		not PowerUpEconomy.purchase(t, 3))
	_check("kismi grant YOK", _stock() == stock_before2)
	_check_eq("Hamur dokunulmadi", SaveManager.dough(),
		PowerUpEconomy.price(t) * 2)


# --- 4) Gecersiz girdi ---

func _scenario_invalid_input() -> void:
	_section("Senaryo 4: gecersiz tip / adet -> HICBIR sey degismez")
	_reset_save(10000)
	var stock_before: Array[int] = _stock()
	var dough_before: int = SaveManager.dough()

	_check("amount=0 reddedildi",
		not PowerUpEconomy.purchase(PowerUp.Type.BOMB, 0))
	_check("amount=-3 reddedildi",
		not PowerUpEconomy.purchase(PowerUp.Type.BOMB, -3))
	# Enum disi tip: UI sinyalleri int tasiyor, bu yol gercekten mumkun.
	_check("gecersiz tip (99) reddedildi",
		not SaveManager.purchase_powerup_with_dough(99 as PowerUp.Type, 1))
	_check("gecersiz tip (-1) reddedildi",
		not SaveManager.purchase_powerup_with_dough(-1 as PowerUp.Type, 1))
	_check("PowerUp.is_valid_type(99) false", not PowerUp.is_valid_type(99))
	_check("PowerUp.is_valid_type(0) true", PowerUp.is_valid_type(0))

	_check("gecersiz denemeler stogu bozmadi", _stock() == stock_before)
	_check_eq("gecersiz denemeler Hamur'u bozmadi",
		SaveManager.dough(), dough_before)


# --- 5) Bir satin alma = bir grant ---

func _scenario_single_grant() -> void:
	_section("Senaryo 5: bir satin alma yalnizca bir grant")
	var t: PowerUp.Type = PowerUp.Type.CLEAR_SMALL
	_reset_save(PowerUpEconomy.price(t) * 10)
	var start_stock: int = SaveManager.powerup_count(t)
	var start_dough: int = SaveManager.dough()

	for i in 4:
		PowerUpEconomy.purchase(t)
	_check_eq("4 satin alma -> stok tam +4",
		SaveManager.powerup_count(t), start_stock + 4)
	_check_eq("4 satin alma -> Hamur tam 4x fiyat dustu",
		SaveManager.dough(), start_dough - PowerUpEconomy.price(t) * 4)
	# Diger gucler etkilenmemeli.
	_check_eq("Bomba stogu etkilenmedi",
		SaveManager.powerup_count(PowerUp.Type.BOMB), 1)


# --- 6) Kalicilik: yeniden yukleme ---

func _scenario_persistence() -> void:
	_section("Senaryo 6: restart/load -> stok ve Hamur korunuyor")
	var t: PowerUp.Type = PowerUp.Type.SHAKE
	_reset_save(1000)
	PowerUpEconomy.purchase(t, 2)
	var expected_stock: Array[int] = _stock()
	var expected_dough: int = SaveManager.dough()

	# Diskten yeniden oku — oyunun yeniden acilmasinin karsiligi.
	SaveManager.load_game()
	await get_tree().process_frame

	_check("yeniden yukleme sonrasi stok ayni", _stock() == expected_stock)
	_check_eq("yeniden yukleme sonrasi Hamur ayni",
		SaveManager.dough(), expected_dough)
	_check_eq("satin alinan Sarsinti stogu korundu",
		SaveManager.powerup_count(t), 3)


# --- 7) Skin satin alma bozulmadi ---

func _scenario_skin_purchase() -> void:
	_section("Senaryo 7: skin satin alma bozulmadi (transactional yol)")
	var skins: Array[SkinData] = SkinLibrary.all()
	if skins.is_empty():
		_check("skin kutuphanesi bos DEGIL", false)
		return
	var skin: SkinData = skins[0]
	var price: int = Shop.price_of(skin)

	_reset_save(price + 20)
	_check("skin baslangicta sahip degil", not SaveManager.owns_skin(skin.id))
	_check("skin satin alindi", Shop.purchase(skin))
	_check("skin koleksiyonda", SaveManager.owns_skin(skin.id))
	_check_eq("skin Hamur'u dogru dustu", SaveManager.dough(), 20)

	# Ayni skin tekrar alinamaz ve para gitmez.
	var dough_before: int = SaveManager.dough()
	_check("sahip olunan skin tekrar alinamaz", not Shop.purchase(skin))
	_check_eq("tekrar denemede Hamur gitmedi", SaveManager.dough(), dough_before)

	# Yetersiz Hamur: ne skin ne para.
	var other: SkinData = null
	for candidate in skins:
		if not SaveManager.owns_skin(candidate.id):
			other = candidate
			break
	if other != null:
		_reset_save(Shop.price_of(other) - 1)
		var d: int = SaveManager.dough()
		_check("yetersiz Hamurla skin alinamaz", not Shop.purchase(other))
		_check("skin verilmedi", not SaveManager.owns_skin(other.id))
		_check_eq("Hamur degismedi", SaveManager.dough(), d)

	# Guc satin alma skin koleksiyonuna DOKUNMAMALI.
	_reset_save(5000)
	var owned_before: int = SaveManager.owned_skins().size()
	PowerUpEconomy.purchase(PowerUp.Type.BOMB, 2)
	_check_eq("guc satin alma skin koleksiyonunu degistirmedi",
		SaveManager.owned_skins().size(), owned_before)


# --- 8) Sandik ekonomisi degismedi ---

func _scenario_chest_economy_untouched() -> void:
	_section("Senaryo 8: sandik ekonomisi degismedi")
	_check_eq("rarity esikleri", str(ChestSystem.RARITY_THRESHOLDS),
		str([60, 85, 97, 100]))
	_check_eq("skin odul yuzdesi", ChestSystem.SKIN_REWARD_PERCENT, 30)
	_check_eq("rarity Hamur tablosu", str(ChestSystem.RARITY_DOUGH),
		str([10, 25, 60, 150]))
	_check_eq("teselli odulu", ChestSystem.CONSOLATION_DOUGH, 5)
	_check_eq("bonus sandik esigi", ChestSystem.MERGES_PER_BONUS_CHEST, 75)
	_check_eq("skin fiyatlari", str(Shop.PRICES), str([50, 150, 400, 900]))
	_check_eq("gunluk Hamur", DailyReward.DAILY_DOUGH, 15)

	# Sandik gercekten Hamur veriyor ve guc stogunu DEGISTIRMIYOR.
	_reset_save(0)
	var stock_before: Array[int] = _stock()
	for i in 40:
		ChestSystem.open()
	_check("40 sandik acildi, guc stogu degismedi", _stock() == stock_before)
	ChestSystem.consolation()
	_check("teselli odulu Hamur verdi", SaveManager.dough() > 0)


# --- 9) Baslangic hediyesi tekrar verilmiyor ---

func _scenario_starter_not_regranted() -> void:
	_section("Senaryo 9: baslangic x1 hediyesi tekrar verilmiyor")
	_reset_save(1000)
	var starter: Array[int] = [1, 1, 1, 1]
	_check("yeni kayitta her gucten x1", _stock() == starter)
	_check("starter bayragi kalkti",
		bool(SaveManager.data.get("powerup_starter_granted", false)))

	PowerUpEconomy.purchase(PowerUp.Type.BOMB, 2)
	SaveManager.consume_powerup(PowerUp.Type.SHAKE)
	var expected: Array[int] = _stock()

	# Tekrar tekrar load: migration hediyeyi yeniden vermemeli.
	for i in 3:
		SaveManager.load_game()
	_check("3 kez yeniden yuklendi, stok degismedi", _stock() == expected)
	_check_eq("harcanan Sarsinti geri gelmedi",
		SaveManager.powerup_count(PowerUp.Type.SHAKE), 0)


# --- 10) Magaza ekrani ---

func _scenario_shop_ui() -> void:
	_section("Senaryo 10: magaza ekrani dogru stok/fiyat gosteriyor")
	_reset_save(5000)
	var shop: CanvasLayer = SHOP_SCREEN_SCENE.instantiate()
	add_child(shop)
	await get_tree().process_frame
	shop.refresh()
	await get_tree().process_frame

	var text: String = _collect_text(shop)
	_check("GUCLER bolumu var", text.contains("GÜÇLER"))
	_check("SKINLER bolumu var", text.contains("SKİNLER"))
	for type in PowerUp.all():
		_check("%s karti var" % PowerUp.display_name(type),
			text.contains(PowerUp.display_name(type)))
		_check("%s fiyati gorunuyor" % PowerUp.display_name(type),
			text.contains("%d Hamur" % PowerUpEconomy.price(type)))
	_check("stok x1 gorunuyor", text.contains("Stok: ×1"))
	_check("Hamur bakiyesi gorunuyor", text.contains("Hamur: 5000"))

	# Satin alma sonrasi refresh stogu ve bakiyeyi guncelliyor mu?
	PowerUpEconomy.purchase(PowerUp.Type.BOMB, 2)
	shop.refresh()
	await get_tree().process_frame
	var after: String = _collect_text(shop)
	_check("satin alma sonrasi stok x3 gorunuyor", after.contains("Stok: ×3"))
	_check("satin alma sonrasi bakiye guncellendi",
		after.contains("Hamur: %d" % SaveManager.dough()))

	# Parasi yetmeyince buton pasif olmali.
	_reset_save(0)
	shop.refresh()
	await get_tree().process_frame
	_check("Hamur 0 iken tum Satin Al butonlari pasif",
		_all_buy_buttons_disabled(shop))

	shop.queue_free()
	await get_tree().process_frame


## Bir alt agactaki tum gorunur metni toplar.
##
## Button DA dahil: guc cubugu stogunu buton yazisinda gosteriyor
## ("⌫\nTemizleyici ×5"), yalnizca Label'lara bakmak onu kaciriyordu.
func _collect_text(node: Node) -> String:
	var parts: PackedStringArray = []
	for child in node.get_children():
		var label := child as Label
		if label != null:
			parts.append(label.text)
		var rich := child as RichTextLabel
		if rich != null:
			parts.append(rich.text)
		var button := child as Button
		if button != null:
			parts.append(button.text)
		parts.append(_collect_text(child))
	return "\n".join(parts)


func _all_buy_buttons_disabled(node: Node) -> bool:
	for child in node.get_children():
		var button := child as Button
		if button != null and button.text == "Satın Al" and not button.disabled:
			return false
		if not _all_buy_buttons_disabled(child):
			return false
	return true


# --- 11) Satin alinan guc oyun ici cubuga yansiyor ---

func _scenario_power_bar() -> void:
	_section("Senaryo 11: satin alinan guc gameplay power bar'a yansiyor")
	_reset_save(5000)
	PowerUpEconomy.purchase(PowerUp.Type.CLEAR_SMALL, 4)
	var expected: int = SaveManager.powerup_count(PowerUp.Type.CLEAR_SMALL)
	_check_eq("satin alma sonrasi stok 5", expected, 5)

	var board: Node2D = GAME_BOARD_SCENE.instantiate()
	board.setup(load("res://resources/levels/level_01.tres"))
	add_child(board)
	await get_tree().process_frame

	var text: String = _collect_text(board._power_bar)
	_check("power bar satin alinan stogu gosteriyor (x5)",
		text.contains("%s ×%d" % [
			PowerUp.display_name(PowerUp.Type.CLEAR_SMALL), expected]))
	# Kullanildiginda stok dusuyor ve cubuk guncelleniyor.
	board._powerups.consume(PowerUp.Type.CLEAR_SMALL)
	board._power_bar.refresh()
	await get_tree().process_frame
	_check("kullanim sonrasi power bar x4 gosteriyor",
		_collect_text(board._power_bar).contains("%s ×4"
			% PowerUp.display_name(PowerUp.Type.CLEAR_SMALL)))
	_check_eq("kayitta da 4", SaveManager.powerup_count(PowerUp.Type.CLEAR_SMALL), 4)

	board.queue_free()
	await get_tree().process_frame
