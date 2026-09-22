extends Node
## Devam (revive) + stok 0 refill production pencereleri (M8.6-10) regresyon
## testi: SUNUM + İŞLEM SINIRI. Headless, kaydı byte olarak geri koyar.
##
##   godot --headless --audio-driver Dummy --path . res://tools/revive_refill_ui_test.tscn
##
## Kontroller:
##   KAYNAK    iki pencere de modal_shell'de; panel_candy / CandyButton /
##             UiPalette / ModalPanel / M8.5 rolleri yok; yasak kök yok;
##             `_process` yok; pencereler kayda YAZMAZ (SaveManager yazma /
##             RewardedPolicy.grant / PowerUpEconomy.purchase / grant_revive
##             çağrısı yok); fiyat PowerUpEconomy.price'tan, DOUGH_PRICES
##             kopyası yok.
##   DEVAM     ilk teklif 2/2 (iki renkli kalp), ikinci 1/2, hak yok savunma
##             durumu 0/2; sağlayıcı yokken DEVAM ET pasif + sebep, BİTİR açık;
##             sağlayıcı bağlıyken talep TAM BİR KEZ (çift dokunuş kilitli),
##             UI hak vermez (board sayacı 0), ödül callback'i tam bir kez
##             devam verir ve pencereyi kapatır (ikinci callback false);
##             sağlayıcı "olmadı" → sağlayıcı bağlıysa tekrar denenebilir,
##             değilse pasif kalır; Android geri yok sayılır (teklif açık, mola
##             yok, sonuç yok); BİTİR → teklif kapanır, sonuç RESULT_DELAY
##             sonra ve TEK round_finished, teselli tam bir kez; sonuç teklifin
##             altında hiç görünmez; 3. devam yok (hak bitince teklif açılmaz).
##   REFILL    dört güç: stok 0 doğru kahraman (gerçek sanat + ad), kanonik
##             fiyat (100/120/160/180 = PowerUpEconomy), yeterli / yetersiz
##             Hamur (pasif + sebep); ödüllü: sağlayıcı yok (pasif + sebep),
##             bağlı (aktif, 1/1), kota dolu (pasif, 0/1); kota DÖRT GÜCÜN
##             TOPLAMI (Bomba'ya ödül → diğer üçünde kullanılmış); satın alma:
##             Hamur tam bir kez düşer, stok tam +1, hızlı çift basış tek
##             satın alma, güç başına fiyat; talep sağlayıcı hatasında kota
##             tüketilmez; açıp kapamak / geri / karartma / vazgeçme kayda
##             YAZMAZ; geri = Kapat (yeni; oyun sürer, hiçbir şey alınmaz);
##             refill açıkken mola açılmaz, board donuk, ikinci güç isteği
##             yok sayılır; hiçbir güç aktive olmaz.
##   RESPONSİF 720×1280 / 720×1560 / 540×960 / 1080×2340 / A36 (safe 61):
##             çerçeve + tepelik/kurdele ekranda, altlık çerçevede, CTA'lar
##             ekranda, başlık kırpılmaz, güç sanatı görünür.
##   PERF      düğüm sayıları, sürekli tween yok (rapor).

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const LEVEL_04: String = "res://resources/levels/level_04.tres"
const LEVEL_10: String = "res://resources/levels/level_10.tres"
const VIEWS: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(720, 1560), Vector2i(540, 960), Vector2i(1080, 2340)]
const A36_SAFE_TOP: float = 61.0
const SOURCES: Array[String] = [
	"res://scripts/ui/revive_offer.gd", "res://scenes/ui/revive_offer.tscn",
	"res://scripts/ui/power_refill.gd", "res://scenes/ui/power_refill.tscn",
]
const LEGACY: Array[String] = ["panel_candy.png", "ModalPanel", "CandyButton", "UiPalette",
	"cta_button_normal", "SB_candy", "&\"Display\"", "&\"Stat\"", "&\"Caption\"", "&\"SecondaryButton\"",
	"UiType.apply"]
const FORBIDDEN: Array[String] = ["_visual_source", "layerlab_spike", "layerlab_casual_game", "unitypackage"]
const WRITE_CALLS: Array[String] = ["save_game", "add_dough", "spend_dough", "grant_powerup",
	"grant_rewarded_powerup", "purchase_powerup_with_dough", "consume_powerup", "RewardedPolicy.grant(",
	"PowerUpEconomy.purchase(", "grant_revive(", "DOUGH_PRICES"]
const CANONICAL_PRICES: Dictionary = {
	PowerUp.Type.SHAKE: 100, PowerUp.Type.BOMB: 120, PowerUp.Type.CLEAR_SMALL: 160, PowerUp.Type.UPGRADE: 180,
}


## Ödüllü sağlayıcı TEST ÇİFTİ: talebi sayar, cevabı test verir. Production'da
## böyle bir şey YOK.
class _StubProvider extends RefCounted:
	var revive_requests: int = 0
	var power_requests: int = 0
	var last_type: int = -1
	var last_token: int = 0

	func show_rewarded_revive(_main: Node) -> void:
		revive_requests += 1

	func show_rewarded_power(_main: Node, type: int, token: int) -> void:
		power_requests += 1
		last_type = type
		last_token = token


var _fails: int = 0
var _checks: int = 0
var _saved: Dictionary = {}
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _main: Node2D
var _finished_count: int = 0


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	# Otomatik GÜNLÜK ÖDÜLLER penceresi (M8.9-02) bu harness'in konusu değil.
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_saved = SaveManager.data.duplicate(true)
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	_apply_showcase()
	get_window().size = Vector2i(720, 1000)
	await get_tree().process_frame
	await _resize(VIEWS[0])

	_test_sources()

	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame

	await _test_revive_structure()
	await _test_revive_states()
	await _test_revive_back_and_decline()
	await _test_refill_structure()
	await _test_refill_powers()
	await _test_refill_rewarded()
	await _test_refill_quota_shared()
	await _test_refill_purchase()
	await _test_refill_close_paths()
	await _test_responsive()
	await _test_performance()

	_main.queue_free()
	await get_tree().process_frame
	SaveManager.data = _saved
	_restore_save_file()
	var restored: bool = not _had_save or FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == _save_bytes
	_c("kayıt dosyası test sonunda byte-identical geri kondu", restored)
	print("=== SONUC: %d/%d kontrol, %d kaldi ===" % [_checks - _fails, _checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


# --- Kaynak taraması --------------------------------------------------------------

func _test_sources() -> void:
	print("-- kaynak taraması")
	var all_src: String = ""
	for path in SOURCES:
		var text: String = FileAccess.get_file_as_string(path)
		_c("%s okunuyor" % path.get_file(), text.length() > 0)
		all_src += text
		for word in FORBIDDEN:
			_c("%s: yasak referans yok (%s)" % [path.get_file(), word], not text.contains(word))
	for word in LEGACY:
		_c("eski iskelet yok (%s)" % word, not all_src.contains(word))
	_c("iki pencere de UiKit.modal_shell", all_src.count("UiKit.modal_shell(") == 2)
	for word in WRITE_CALLS:
		_c("pencereler kayda / ekonomiye dokunmaz (%s yok)" % word, not all_src.contains(word))
	_c("_process yok", not all_src.contains("func _process"))
	_c("fiyat tek kaynaktan (PowerUpEconomy.price)", all_src.contains("PowerUpEconomy.price("))
	_c("kota tek kaynaktan (RewardedPolicy.remaining_today / daily_cap)",
		all_src.contains("RewardedPolicy.remaining_today(") and all_src.contains("RewardedPolicy.daily_cap("))
	_c("candy_button.gd runtime'da yok", not FileAccess.file_exists("res://scripts/ui/candy_button.gd"))
	_c("ui_palette.gd runtime'da yok", not FileAccess.file_exists("res://scripts/ui/ui_palette.gd"))
	_c("panel_candy.png runtime'da yok", not FileAccess.file_exists("res://assets/visual/ui/panel_candy.png"))
	_c("panel_candy_crown.png (tepelik) duruyor", FileAccess.file_exists("res://assets/visual/ui/panel_candy_crown.png"))
	_c("icon_heart_revive.png (owner tepeliğinden türev) var", FileAccess.file_exists("res://assets/visual/ui/icon_heart_revive.png"))
	# Tüm production ağacında eski parçalara referans kalmadı (tools hariç).
	var refs: int = 0
	for root in ["res://scripts", "res://scenes"]:
		refs += _count_refs(root, ["CandyButton", "UiPalette", "panel_candy.png", "cta_button_", "power_button_", "ui/icons/"])
	_c("production scripts/scenes: CandyButton / UiPalette / panel_candy / cta_button / power_button / ui/icons referansı 0", refs == 0)


func _count_refs(dir_path: String, words: Array[String]) -> int:
	var count: int = 0
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				count += _count_refs(full, words)
		elif entry.get_extension() in ["gd", "tscn", "tres"]:
			var text: String = FileAccess.get_file_as_string(full)
			for word in words:
				if text.contains(word):
					print("    referans: %s -> %s" % [full, word])
					count += 1
		entry = dir.get_next()
	dir.list_dir_end()
	return count


# --- Devam --------------------------------------------------------------------------

func _revive() -> CanvasLayer:
	return _main._revive


func _board() -> Node2D:
	return _main._board


func _start(level: String, detach: bool) -> void:
	_main._start_level(load(level))
	await get_tree().process_frame
	await get_tree().process_frame
	_board()._dismiss_tutorial()
	_finished_count = 0
	_board().round_finished.connect(func(_won: bool) -> void: _finished_count += 1)
	if detach:
		_board().round_finished.disconnect(_main._on_round_finished)
	await get_tree().process_frame


func _leave() -> void:
	_main._result.hide_result()
	_main.abandon_run()
	await get_tree().process_frame
	_main._show_tab(0)
	await _settle(2)


func _open_offer(used: int) -> void:
	_revive().hide_offer()
	_board()._is_fail_pending = false
	_board()._revives_used = used
	_board()._enter_fail_pending()
	await _settle(4)


func _test_revive_structure() -> void:
	print("-- devam: yapı")
	var offer: CanvasLayer = _revive()
	var frame: Control = offer.frame()
	_c("devam CanvasLayer katman 11 (değişmedi)", offer.layer == 11)
	_c("production iskelet: modal_shell meta (hero / body / footer / heading / topper)",
		frame.has_meta(&"hero") and frame.has_meta(&"footer") and frame.get_meta(&"heading") != null
		and frame.get_meta(&"topper") != null)
	_c("gövde PanelModal (krem)", (frame.get_meta(&"panel") as PanelContainer).theme_type_variation == &"PanelModal")
	# set_meta(null) metayi siler -> has_meta (get_meta null varsayilani hata verir).
	_c("kapat X yok (karar penceresi)", not frame.has_meta(&"close_button"))
	var dim: ColorRect = offer.dim()
	_c("karartma tam ekran, STOP, α .62", dim.mouse_filter == Control.MOUSE_FILTER_STOP
		and dim.anchor_right == 1.0 and dim.anchor_bottom == 1.0 and is_equal_approx(dim.color.a, 0.62))
	_c("karartmaya dokunuş kapatmaz (gui_input bağlı değil)", not dim.gui_input.get_connections().size() > 0)
	_c("başlık kanonik", (frame.get_meta(&"heading") as Label).text == offer.TITLE)
	_c("DEVAM ET kahraman CTA (ButtonCTA) + 'Reklam izle' + film pictosu",
		offer.continue_button().theme_type_variation == &"ButtonCTA"
		and (offer.continue_button().get_meta(&"title_label") as Label).text == "DEVAM ET"
		and offer.continue_button().has_meta(&"subtitle_label") and offer.continue_button().has_meta(&"picto"))
	_c("BİTİR ikincil (ButtonSecondary, kahramandan zayıf)", offer.decline_button().theme_type_variation == &"ButtonSecondary"
		and offer.decline_button().text == "BİTİR")
	_c("CTA ve BİTİR sabit altlıkta (kaydırılmaz)", (frame.get_meta(&"footer") as Control).is_ancestor_of(offer.continue_button())
		and (frame.get_meta(&"footer") as Control).is_ancestor_of(offer.decline_button()))


func _test_revive_states() -> void:
	print("-- devam: durumlar ve işlem sınırı")
	var offer: CanvasLayer = _revive()
	var stub := _StubProvider.new()
	await _start(LEVEL_10, false)
	var board: Node2D = _board()
	var bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	var requested: Array[int] = [0]
	offer.rewarded_revive_requested.connect(func() -> void: requested[0] += 1)

	# A. ilk teklif, sağlayıcı bağlı.
	_main.set_rewarded_provider(stub)
	await _open_offer(0)
	_c("A: teklif açık, sonuç kapalı", offer.visible and not _main._result.visible)
	_c("A: iki kalp, ikisi de renkli, '2 / 2'", offer.hearts().size() == 2 and offer.hearts_available() == 2
		and offer.remaining_text() == "2 / 2")
	_c("A: sahte üçüncü yuva yok (kalp sayısı = board tavanı)", offer.hearts().size() == board.max_revives())
	_c("A: DEVAM ET aktif, not yok, BİTİR aktif", not offer.continue_button().disabled and offer.note_text() == ""
		and not offer.decline_button().disabled)
	_c("A: board fail-pending, donuk, güç çubuğu kapalı", board.is_fail_pending() and board._is_paused()
		and not board._power_bar._enabled)

	# B. talep: tam bir kez, UI hak vermez.
	offer.continue_button().pressed.emit()
	await _settle(2)
	_c("B: talep sağlayıcıya tam bir kez gitti", stub.revive_requests == 1 and requested[0] == 1)
	_c("B: CTA kilitli + 'Reklam isteniyor…' (bekleme)", offer.continue_button().disabled and offer.is_request_pending()
		and offer.note_text() == offer.NOTE_REQUESTING)
	offer.continue_button().pressed.emit()
	offer._on_continue_pressed()
	await _settle(2)
	_c("B: ikinci dokunuş / çağrı ikinci talep üretmedi", stub.revive_requests == 1 and requested[0] == 1)
	_c("B: talep hak TÜKETMEDİ, board hâlâ fail-pending, round bitmedi", board.revives_used() == 0
		and board.is_fail_pending() and _finished_count == 0)
	_c("B: talep kayda yazmadı", FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == bytes_before)

	# C. ödül callback'i: tam bir kez devam.
	_c("C: grant_revive() → true", _main.grant_revive())
	await _settle(2)
	_c("C: pencere kapandı, board devam etti (1 kullanıldı)", not offer.visible and board.revives_used() == 1
		and not board.is_fail_pending())
	_c("C: ikinci callback devam VERMEDİ (false, sayaç 1)", not _main.grant_revive() and board.revives_used() == 1)
	_c("C: devam sonrası sonuç yok, kayıt aynı", not _main._result.visible
		and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == bytes_before)

	# D. ikinci teklif 1/2.
	await _open_offer(board.revives_used())
	_c("D: ikinci teklif '1 / 2', bir renkli bir soluk kalp", offer.visible and offer.remaining_text() == "1 / 2"
		and offer.hearts_available() == 1 and offer.hearts().size() == 2)
	_c("D: DEVAM ET aktif (hak var, sağlayıcı bağlı)", not offer.continue_button().disabled)
	# Sağlayıcı "olmadı" dedi: teklif açık, tekrar denenebilir, hak aynı.
	offer.continue_button().pressed.emit()
	await _settle(1)
	_main.notify_rewarded_unavailable("Reklam yüklenemedi.")
	await _settle(1)
	_c("D: sağlayıcı hatası → teklif açık, not mesaj, CTA yeniden aktif (tekrar dene)", offer.visible
		and offer.note_text() == "Reklam yüklenemedi." and not offer.continue_button().disabled
		and not offer.is_request_pending())
	_c("D: hata hak tüketmedi", board.revives_used() == 1 and board.is_fail_pending())

	# E. sağlayıcı yok (bugünkü production).
	_main.set_rewarded_provider(null)
	await _open_offer(0)
	_c("E: sağlayıcı yok → DEVAM ET PASİF + 'henüz bağlı değil', BİTİR aktif",
		offer.continue_button().disabled and offer.note_text() == offer.NOTE_NO_PROVIDER
		and not offer.decline_button().disabled and offer.hearts_available() == 2)
	var before_req: int = requested[0]
	offer._on_continue_pressed()
	offer.continue_button().pressed.emit()
	await _settle(1)
	_c("E: sağlayıcı yokken talep üretilmez (sinyal yok, bekleme yok)", requested[0] == before_req
		and not offer.is_request_pending())
	offer.show_unavailable("Ödüllü reklam henüz bağlı değil.")
	_c("E: 'olmadı' sonrası CTA pasif KALIR (çalışmayacak buton açılmaz)", offer.continue_button().disabled)
	_c("E: pasif CTA yazısı pasif renkte (basılabilir görünmez)",
		(offer.continue_button().get_meta(&"title_label") as Label).get_theme_color("font_color") == UiTokens.TEXT_DISABLED)
	_main.set_rewarded_provider(stub)
	await _open_offer(0)
	_c("E: sağlayıcı bağlanınca aynı pencere aktif CTA ile açılır",
		not offer.continue_button().disabled
		and (offer.continue_button().get_meta(&"title_label") as Label).get_theme_color("font_color") == UiTokens.TEXT_ON_ACCENT)

	# F. hak yok — savunma durumu (runtime bu pencereyi açmaz).
	offer.show_offer(0, board.max_revives(), true)
	await _settle(1)
	_c("F: 0/2 savunma: iki soluk kalp, CTA pasif, 'hakkın bitti'", offer.hearts_available() == 0
		and offer.remaining_text() == "0 / 2" and offer.continue_button().disabled
		and offer.note_text() == offer.NOTE_EXHAUSTED)
	offer._on_continue_pressed()
	_c("F: hak yokken talep yok", requested[0] == before_req)
	offer.hide_offer()
	_main.set_rewarded_provider(null)
	_c("devam durumları kayda yazmadı", FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == bytes_before)
	await _leave()


func _test_revive_back_and_decline() -> void:
	print("-- devam: Android geri, BİTİR → sonuç sırası, 3. devam yok")
	var offer: CanvasLayer = _revive()
	await _start(LEVEL_04, false)
	var board: Node2D = _board()
	GameState.reset_run()
	GameState.add_score(500)
	var dough_before: int = SaveManager.dough()
	_main.set_rewarded_provider(null)
	board._trigger_overflow_fail()
	await _settle(4)
	_c("gerçek taşma: teklif açık (2/2), sonuç kapalı", offer.visible and offer.remaining_text() == "2 / 2"
		and not _main._result.visible)

	# Android geri: yok sayılır.
	_main._last_back_msec = -1000
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(4)
	_c("geri: teklif hâlâ açık, board fail-pending", offer.visible and board.is_fail_pending())
	_c("geri: mola açılmadı, sonuç açılmadı, board silinmedi", not _main.is_pause_open()
		and not _main._result.visible and is_instance_valid(_main._board))
	_c("geri: hak tüketilmedi, round bitmedi", board.revives_used() == 0 and _finished_count == 0)
	_main.open_pause_menu()
	_c("teklif açıkken open_pause_menu mola AÇMAZ", not _main.is_pause_open())

	# BİTİR → sonuç (çift dokunuş: ikinci BİTİR ikinci bitiş/teselli üretmez).
	offer.decline_button().pressed.emit()
	offer.decline_button().pressed.emit()
	_main.decline_revive()
	await get_tree().process_frame
	_c("BİTİR: teklif aynı karede kapandı, sonuç henüz yok (altında pencere yok)", not offer.visible
		and not _main._result.visible)
	_c("BİTİR ×3: round_finished(false) TAM BİR KEZ, board bitti", _finished_count == 1 and board.is_finished())
	await get_tree().create_timer(0.3).timeout
	_c("BİTİR + 0.3 s: sonuç hâlâ yok (RESULT_DELAY), teklif yok", not _main._result.visible and not offer.visible)
	var waited: int = 0
	while not _main._result.visible and waited < 180:
		await get_tree().process_frame
		waited += 1
	_c("BİTİR → sonuç açıldı (KAYIP modu), teklif kapalı", _main._result.visible
		and _main._result.mode() == _main._result.Mode.FAIL and not offer.visible)
	_c("BİTİR → teselli tam bir kez (+%d)" % ChestSystem.CONSOLATION_DOUGH,
		SaveManager.dough() == dough_before + ChestSystem.CONSOLATION_DOUGH)
	_c("BİTİR → round_finished sayısı hâlâ 1", _finished_count == 1)
	_c("hak tüketilmedi (BİTİR ücretsiz)", board.revives_used() == 0)
	await _settle(30)
	await _leave()

	# 3. devam yok: iki devam kullanılmış board'da taşma → teklif AÇILMAZ.
	await _start(LEVEL_04, true)
	board = _board()
	board._revives_used = board.max_revives()
	board._trigger_overflow_fail()
	await _settle(4)
	_c("hak bitince taşma teklif açmaz, round doğrudan biter (3. devam yok)", not offer.visible
		and board.is_finished() and _finished_count == 1)
	_c("hak bitmişken grant_revive() false", not _main.grant_revive())
	await _leave()


# --- Refill ---------------------------------------------------------------------------

func _refill() -> CanvasLayer:
	return _main._refill


func _set_stock(bomb: int, upgrade: int, shake: int, clear: int) -> void:
	SaveManager.data["powerups"] = {"bomb": bomb, "upgrade": upgrade, "shake": shake, "clear_small": clear}
	if _main._board != null and is_instance_valid(_main._board):
		_main._board._refresh_power_bar()


func _set_quota_used(used: bool) -> void:
	SaveManager.data["rewarded_power_date"] = Time.get_date_string_from_system() if used else ""
	SaveManager.data["rewarded_power_grants"] = 1 if used else 0


func _open_refill(type: PowerUp.Type) -> void:
	_board()._on_power_refill_requested(int(type))
	await _settle(4)


func _close_refill() -> void:
	_main._on_refill_closed()
	await _settle(1)


func _test_refill_structure() -> void:
	print("-- refill: yapı")
	var refill: CanvasLayer = _refill()
	var frame: Control = refill.frame()
	_c("refill CanvasLayer katman 11 (değişmedi)", refill.layer == 11)
	_c("production iskelet: modal_shell meta (hero / body / footer / ribbon), oturmuş X",
		frame.has_meta(&"hero") and frame.has_meta(&"footer") and frame.get_meta(&"ribbon") != null
		and frame.get_meta(&"close_button") != null)
	_c("kurdele 'STOK BİTTİ'", refill.ribbon_text() == "STOK BİTTİ")
	_c("gövde PanelModal (krem)", (frame.get_meta(&"panel") as PanelContainer).theme_type_variation == &"PanelModal")
	_c("iki seçenek kartı gövdede, ayrı kimlik: REKLAM İZLE cyan ButtonPrimary + film, SATIN AL nane ButtonPurchase",
		refill._ad.theme_type_variation == &"ButtonPrimary" and refill._ad.text == "REKLAM İZLE" and refill._ad.icon != null
		and refill._dough.theme_type_variation == &"ButtonPurchase" and refill._dough.text == "SATIN AL"
		and (frame.get_meta(&"body") as Control).is_ancestor_of(refill.ad_card())
		and (frame.get_meta(&"body") as Control).is_ancestor_of(refill.dough_card()))
	_c("üç aynı CTA yok (üç ayrı variation)", refill._ad.theme_type_variation != refill._dough.theme_type_variation
		and refill._close.theme_type_variation == &"ButtonSecondary" and refill._close.text == "KAPAT")
	_c("KAPAT sabit altlıkta, kahraman sanatı sabit hero'da", (frame.get_meta(&"footer") as Control).is_ancestor_of(refill._close)
		and (frame.get_meta(&"hero") as Control).is_ancestor_of(refill.hero_art()))
	var dim: ColorRect = refill.dim()
	_c("karartma tam ekran, STOP, α .62, dokunuş kapatır", dim.mouse_filter == Control.MOUSE_FILTER_STOP
		and dim.anchor_right == 1.0 and is_equal_approx(dim.color.a, 0.62) and dim.gui_input.get_connections().size() > 0)
	_c("Güç Paketi seam'i bağlı değil ve butonu yok", refill.power_pack_requested.get_connections().is_empty()
		and _count_named(frame, "Pack") == 0)


func _test_refill_powers() -> void:
	print("-- refill: dört güç, fiyat, Hamur")
	var refill: CanvasLayer = _refill()
	await _start(LEVEL_04, true)
	var board: Node2D = _board()
	_main.set_rewarded_provider(null)
	_set_quota_used(false)
	for type in PowerUp.all():
		var canonical: int = CANONICAL_PRICES[type]
		_c("%s: kanonik fiyat %d = PowerUpEconomy.price" % [PowerUp.display_name(type), canonical],
			PowerUpEconomy.price(type) == canonical)
		_set_stock(0, 0, 0, 0)
		SaveManager.data["dough"] = 500
		await _open_refill(type)
		_c("%s: stok 0 → refill açık, doğru güç" % PowerUp.display_name(type), refill.visible and refill.current_type() == int(type))
		_c("%s: kahraman GERÇEK güç sanatı + ad + 'STOK ×0'" % PowerUp.display_name(type),
			refill.hero_art().texture == PowerUp.icon(type) and refill.power_name_text() == PowerUp.display_name(type)
			and refill.stock_text() == "STOK ×0")
		_c("%s: fiyat satırı '%d Hamur'" % [PowerUp.display_name(type), canonical], refill.price_text() == "%d Hamur" % canonical)
		_c("%s: '+1 %s' ödül satırları" % [PowerUp.display_name(type), PowerUp.display_name(type)],
			refill._ad_sub.text == "+1 %s" % PowerUp.display_name(type) and refill._dough_sub.text == "+1 %s" % PowerUp.display_name(type))
		_c("%s: 500 Hamur → SATIN AL aktif, bakiye satırı" % PowerUp.display_name(type), not refill._dough.disabled
			and refill.balance_text() == "Bakiyen: 500" and refill.dough_note_text() == "")
		_c("%s: sağlayıcı yok → REKLAM İZLE pasif + sebep" % PowerUp.display_name(type), refill._ad.disabled
			and refill.ad_note_text() == refill.NOTE_NO_PROVIDER)
		_c("%s: hiçbir güç aktive olmadı, board donuk, güç çubuğu kapalı" % PowerUp.display_name(type),
			not board._powerups.is_armed() and board.is_refill_pending() and board._is_paused() and not board._power_bar._enabled)
		# Yetersiz Hamur: fiyatın 1 altı.
		SaveManager.data["dough"] = canonical - 1
		refill.refresh(false)
		_c("%s: %d Hamur → SATIN AL PASİF + 'Hamur yetersiz'" % [PowerUp.display_name(type), canonical - 1],
			refill._dough.disabled and refill.dough_note_text().begins_with("Hamur yetersiz")
			and refill.balance_text() == "Bakiyen: %d" % (canonical - 1))
		SaveManager.data["dough"] = canonical
		refill.refresh(false)
		_c("%s: tam %d Hamur → SATIN AL aktif" % [PowerUp.display_name(type), canonical], not refill._dough.disabled)
		await _close_refill()
		_c("%s: Kapat → pencere kapalı, oyun sürüyor, stok/Hamur aynı" % PowerUp.display_name(type),
			not refill.visible and not board.is_refill_pending() and board._power_bar._enabled
			and SaveManager.powerup_count(type) == 0 and SaveManager.dough() == canonical)
	SaveManager.data["dough"] = 335
	await _leave()


func _test_refill_rewarded() -> void:
	print("-- refill: ödüllü seçenek")
	var refill: CanvasLayer = _refill()
	var stub := _StubProvider.new()
	await _start(LEVEL_04, true)
	_set_stock(0, 0, 0, 0)
	SaveManager.data["dough"] = 335
	var requested: Array[int] = [0]
	refill.rewarded_refill_requested.connect(func(_t: int) -> void: requested[0] += 1)

	_set_quota_used(false)
	_main.set_rewarded_provider(stub)
	await _open_refill(PowerUp.Type.BOMB)
	_c("sağlayıcı bağlı + kota 1/1 → REKLAM İZLE aktif, 'Bugünkü hakkın: 1/1', sebep yok",
		not refill._ad.disabled and refill._quota.text.contains("1/1") and refill.ad_note_text() == "")
	# Talep: tam bir kez, kota tüketilmez.
	var grants_before: int = RewardedPolicy.grants_today()
	var bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	refill._ad.pressed.emit()
	await _settle(1)
	_c("talep sağlayıcıya tam bir kez (tip Bomba, token > 0)", stub.power_requests == 1 and stub.last_type == int(PowerUp.Type.BOMB)
		and stub.last_token > 0 and requested[0] == 1)
	_c("talep: buton kilitli + 'Reklam isteniyor…'", refill._ad.disabled and refill.is_request_pending()
		and refill.ad_note_text() == refill.NOTE_REQUESTING)
	refill._ad.pressed.emit()
	refill._on_ad_pressed()
	await _settle(1)
	_c("ikinci dokunuş ikinci talep üretmedi", stub.power_requests == 1 and requested[0] == 1)
	_c("talep kota TÜKETMEDİ, stok vermedi, kayda yazmadı", RewardedPolicy.grants_today() == grants_before
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == 0
		and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == bytes_before)
	# Sağlayıcı hatası: kota tüketilmez, tekrar denenebilir.
	_main.notify_power_rewarded_unavailable("Reklam yüklenemedi.")
	await _settle(1)
	_c("sağlayıcı hatası → pencere açık, not, REKLAM İZLE yeniden aktif, kota aynı", refill.visible
		and refill.note_text() == "Reklam yüklenemedi." and not refill._ad.disabled
		and RewardedPolicy.grants_today() == grants_before)
	# Hata sonrası eski token'lı callback stok VERMEZ.
	_c("iptal edilmiş talebin callback'i stok vermez", not _main.grant_rewarded_power(int(PowerUp.Type.BOMB), stub.last_token)
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == 0)
	await _close_refill()

	# Kota dolu.
	_set_quota_used(true)
	await _open_refill(PowerUp.Type.BOMB)
	_c("kota dolu → REKLAM İZLE pasif, '0/1', 'yarın yenilenir'; SATIN AL aktif", refill._ad.disabled
		and refill._quota.text.contains("0/1") and refill.ad_note_text() == refill.NOTE_QUOTA_USED and not refill._dough.disabled)
	refill._on_ad_pressed()
	_c("kota doluyken talep üretilmez", requested[0] == 1)
	await _close_refill()

	# Sağlayıcı yok: talep yok.
	_set_quota_used(false)
	_main.set_rewarded_provider(null)
	await _open_refill(PowerUp.Type.BOMB)
	_c("sağlayıcı yok → pasif + sebep; kota 1/1 görünür ama buton kapalı", refill._ad.disabled
		and refill.ad_note_text() == refill.NOTE_NO_PROVIDER and refill._quota.text.contains("1/1"))
	refill._on_ad_pressed()
	_c("sağlayıcı yokken talep üretilmez", requested[0] == 1)
	await _close_refill()
	await _leave()


func _test_refill_quota_shared() -> void:
	print("-- refill: günlük kota DÖRT gücün toplamı")
	var refill: CanvasLayer = _refill()
	var stub := _StubProvider.new()
	await _start(LEVEL_04, true)
	_set_stock(0, 0, 0, 0)
	_set_quota_used(false)
	_main.set_rewarded_provider(stub)
	var dough_before: int = SaveManager.dough()
	await _open_refill(PowerUp.Type.BOMB)
	refill._ad.pressed.emit()
	await _settle(1)
	# Test sağlayıcısının "ödül kazanıldı" callback'i: kanonik tek yol.
	_c("Bomba: ödül callback'i → grant true", _main.grant_rewarded_power(stub.last_type, stub.last_token))
	await _settle(2)
	_c("Bomba: stok +1 tam bir kez, kota 1 kullanıldı, Hamur aynı", SaveManager.powerup_count(PowerUp.Type.BOMB) == 1
		and RewardedPolicy.grants_today() == 1 and SaveManager.dough() == dough_before)
	_c("Bomba: pencere kapandı, oyun sürüyor", not refill.visible and not _board().is_refill_pending())
	_c("aynı callback ikinci kez → false, stok 1 kalır", not _main.grant_rewarded_power(stub.last_type, stub.last_token)
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == 1)
	for type in [PowerUp.Type.UPGRADE, PowerUp.Type.SHAKE, PowerUp.Type.CLEAR_SMALL]:
		await _open_refill(type)
		_c("%s: kota Bomba'da kullanıldı → REKLAM İZLE pasif, '0/1', sebep 'doldu'" % PowerUp.display_name(type),
			refill.visible and refill.current_type() == int(type) and refill._ad.disabled
			and refill._quota.text.contains("0/1") and refill.ad_note_text() == refill.NOTE_QUOTA_USED)
		_c("%s: Hamur yolu hâlâ açık (kota Hamur'u kapatmaz)" % PowerUp.display_name(type), not refill._dough.disabled)
		refill._on_ad_pressed()
		_c("%s: kota doluyken talep gitmez" % PowerUp.display_name(type), stub.power_requests == 1)
		await _close_refill()
	_c("üç güçte de stok 0 kaldı (güç başına ayrı kota YOK)", SaveManager.powerup_count(PowerUp.Type.UPGRADE) == 0
		and SaveManager.powerup_count(PowerUp.Type.SHAKE) == 0 and SaveManager.powerup_count(PowerUp.Type.CLEAR_SMALL) == 0)
	_main.set_rewarded_provider(null)
	_set_quota_used(false)
	await _leave()


func _test_refill_purchase() -> void:
	print("-- refill: Hamur satın alma (kanonik tek transaction)")
	var refill: CanvasLayer = _refill()
	await _start(LEVEL_04, true)
	var board: Node2D = _board()
	_main.set_rewarded_provider(null)
	var requests: Array[int] = [0]
	refill.dough_refill_requested.connect(func(_t: int) -> void: requests[0] += 1)

	# Bomba: 600 → 480, stok 0 → 1, tam bir kez (600 = dört fiyat + 40 artik).
	_set_stock(0, 0, 0, 0)
	SaveManager.data["dough"] = 600
	await _open_refill(PowerUp.Type.BOMB)
	var bytes_open: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	refill._dough.pressed.emit()
	refill._dough.pressed.emit()
	refill._on_dough_pressed()
	await _settle(2)
	_c("Bomba: Hamur 600 → 480 (tam bir düşüş)", SaveManager.dough() == 480)
	_c("Bomba: stok 0 → 1 (tam bir artış)", SaveManager.powerup_count(PowerUp.Type.BOMB) == 1)
	_c("Bomba: hızlı çift basış tek satın alma sinyali", requests[0] == 1)
	_c("Bomba: pencere kapandı, oyun sürüyor, hedefleme yeniden açıldı (niyet geri dönüşü)",
		not refill.visible and not board.is_refill_pending() and board._powerups.is_armed())
	_c("Bomba: satın alma kayda TAM BİR KEZ yazdı (dosya değişti)", FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) != bytes_open
		and JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))["dough"] == 480)
	board._powerups.cancel()
	await _settle(1)
	# Bomba'dan sonra kapalı pencereye basış hiçbir şey yapmaz.
	refill._dough.pressed.emit()
	refill._on_dough_pressed()
	await _settle(1)
	_c("kapalı pencerede SATIN AL sinyal üretmez", requests[0] == 1 and SaveManager.dough() == 480)

	# Güç başına fiyat: diğer üçü.
	for type in [PowerUp.Type.UPGRADE, PowerUp.Type.SHAKE, PowerUp.Type.CLEAR_SMALL]:
		var before: int = SaveManager.dough()
		var stock_before: int = SaveManager.powerup_count(type)
		await _open_refill(type)
		refill._dough.pressed.emit()
		await _settle(2)
		_c("%s: Hamur %d → %d (fiyat %d)" % [PowerUp.display_name(type), before, before - CANONICAL_PRICES[type], CANONICAL_PRICES[type]],
			SaveManager.dough() == before - CANONICAL_PRICES[type])
		_c("%s: stok +1 tam" % PowerUp.display_name(type), SaveManager.powerup_count(type) == stock_before + 1)
		_c("%s: yanlış güce stok gitmedi" % PowerUp.display_name(type),
			SaveManager.powerup_count(PowerUp.Type.BOMB) == 1)
		board._powerups.cancel()
		await _settle(1)
	_c("dört satın alma toplamı = 120+180+100+160 (600 → 40)", SaveManager.dough() == 600 - 560)

	# Yeniden açılış güncel bakiyeyi gösterir (40 Hamur, stok 0 olan güç: Temizleyici).
	_set_stock(1, 1, 1, 0)
	await _open_refill(PowerUp.Type.CLEAR_SMALL)
	_c("yeniden açılış: güncel bakiye 40, 160 Hamur pasif + sebep", refill.balance_text() == "Bakiyen: 40"
		and refill._dough.disabled and refill.dough_note_text().begins_with("Hamur yetersiz"))
	var bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	refill._dough.pressed.emit()
	refill._on_dough_pressed()
	await _settle(1)
	_c("yetersiz Hamur: basış sinyal üretmez, hiçbir şey değişmez", requests[0] == 4 and SaveManager.dough() == 40
		and SaveManager.powerup_count(PowerUp.Type.CLEAR_SMALL) == 0 and refill.visible)
	# Yarış: buton aktifken Hamur düşmüş olsun → Main reddeder, pencere açık, yazma yok.
	SaveManager.data["dough"] = 200
	refill.refresh(false)
	SaveManager.data["dough"] = 10
	refill._dough.pressed.emit()
	await _settle(1)
	_c("yarış: Main satın almayı reddetti, pencere açık, uyarı, stok 0, yazma yok", refill.visible
		and refill.note_text().begins_with("Hamur yetmiyor") and SaveManager.powerup_count(PowerUp.Type.CLEAR_SMALL) == 0
		and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == bytes_before and refill._dough.disabled)
	await _close_refill()
	SaveManager.data["dough"] = 335
	await _leave()


func _test_refill_close_paths() -> void:
	print("-- refill: kapanış yolları, geri tuşu, odak")
	var refill: CanvasLayer = _refill()
	await _start(LEVEL_04, true)
	var board: Node2D = _board()
	_main.set_rewarded_provider(null)
	_set_stock(0, 2, 0, 0)
	SaveManager.data["dough"] = 335
	var bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)

	# X.
	await _open_refill(PowerUp.Type.BOMB)
	refill.close_button().pressed.emit()
	await _settle(1)
	_c("X: kapandı, oyun sürüyor, hiçbir şey alınmadı", not refill.visible and not board.is_refill_pending()
		and SaveManager.powerup_count(PowerUp.Type.BOMB) == 0 and SaveManager.dough() == 335)
	# KAPAT.
	await _open_refill(PowerUp.Type.BOMB)
	refill._close.pressed.emit()
	await _settle(1)
	_c("KAPAT: kapandı, oyun sürüyor", not refill.visible and not board.is_refill_pending())
	# Karartma bırakışı.
	await _open_refill(PowerUp.Type.BOMB)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.device = 0
	refill.dim().gui_input.emit(release)
	await _settle(1)
	_c("karartma bırakışı: kapandı", not refill.visible and not board.is_refill_pending())
	# Android geri = Kapat (yeni, M8.6-10).
	await _open_refill(PowerUp.Type.BOMB)
	_main._last_back_msec = -1000
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(2)
	_c("Android geri: refill kapandı (Kapat ile aynı), oyun sürüyor, mola AÇILMADI, board silinmedi",
		not refill.visible and not board.is_refill_pending() and not _main.is_pause_open()
		and is_instance_valid(_main._board) and board._power_bar._enabled)
	_c("Android geri: hiçbir şey alınmadı / harcanmadı", SaveManager.powerup_count(PowerUp.Type.BOMB) == 0
		and SaveManager.dough() == 335 and RewardedPolicy.grants_today() == 0)
	# Geri sonrası ikinci geri: mola (normal oyun içi davranış).
	_main._last_back_msec = -1000
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(2)
	_c("refill kapalıyken geri → mola (mevcut oyun içi politika)", _main.is_pause_open())
	_main.resume_game()
	await _settle(1)
	_c("açıp kapamak (X / KAPAT / karartma / geri) kayda YAZMADI",
		FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == bytes_before)

	# Odak: refill açıkken mola açılmaz, ikinci güç isteği yok sayılır, board donuk.
	await _open_refill(PowerUp.Type.BOMB)
	_main.open_pause_menu()
	_c("refill açıkken open_pause_menu mola AÇMAZ", not _main.is_pause_open())
	board._on_power_refill_requested(int(PowerUp.Type.SHAKE))
	await _settle(1)
	_c("refill açıkken ikinci güç isteği yok sayılır (pencere Bomba'da kalır, tek pencere)",
		refill.current_type() == int(PowerUp.Type.BOMB) and _count_named(refill.frame().get_parent(), "RefillShell") == 1)
	board._on_power_pressed(int(PowerUp.Type.UPGRADE))
	_c("refill açıkken stoklu güç de silahlanmaz (board donuk)", not board._powerups.is_armed() and board._is_paused())
	await _close_refill()
	# Devam teklifi ile refill birlikte açılamaz.
	board._enter_fail_pending()
	await _settle(2)
	board._on_power_refill_requested(int(PowerUp.Type.BOMB))
	await _settle(1)
	_c("fail-pending'de refill açılmaz (teklif karar bekler)", _revive().visible and not refill.visible)
	_main.set_rewarded_provider(null)
	_revive().hide_offer()
	board._is_fail_pending = false
	board._set_board_frozen(false)
	await _leave()


# --- Responsive -------------------------------------------------------------------------

func _test_responsive() -> void:
	print("-- responsive")
	var stub := _StubProvider.new()
	for view_size in VIEWS:
		await _resize(view_size)
		await _check_both("%dx%d" % [view_size.x, view_size.y], 0.0, stub)
	await _resize(Vector2i(720, 1560))
	for screen in _main._screens:
		if screen.has_method("_layout_with_safe_top"):
			screen._layout_with_safe_top(A36_SAFE_TOP)
	await _check_both("A36 (720x1560 safe 61)", A36_SAFE_TOP, stub)
	await _resize(VIEWS[0])


func _check_both(label: String, safe_top: float, stub: _StubProvider) -> void:
	var view: Rect2 = get_viewport().get_visible_rect()
	# Devam.
	await _start(LEVEL_10, true)
	if safe_top > 0.0:
		_board()._apply_layout(view.size, safe_top)
	_main.set_rewarded_provider(stub)
	await _open_offer(0)
	var offer: CanvasLayer = _revive()
	var frame: Control = offer.frame()
	var frame_rect: Rect2 = frame.get_global_rect()
	var top: float = minf(frame_rect.position.y, (frame.get_meta(&"topper") as Control).get_global_rect().position.y)
	_c("%s devam: çerçeve + tepelik ekranda, üst ≥ güvenli pay" % label, view.encloses(frame_rect) and top >= safe_top
		and frame_rect.end.y <= view.size.y - 24.0)
	_c("%s devam: altlık çerçevede, DEVAM ET ve BİTİR ekranda" % label,
		frame_rect.encloses((frame.get_meta(&"footer") as Control).get_global_rect().grow(-1.0))
		and view.encloses(offer.continue_button().get_global_rect()) and view.encloses(offer.decline_button().get_global_rect()))
	_c("%s devam: başlık tek satır sığıyor, kalpler çerçevede" % label, _label_fits(frame.get_meta(&"heading"))
		and frame_rect.encloses(offer.hearts()[0].get_global_rect()) and frame_rect.encloses(offer.hearts()[1].get_global_rect()))
	_c("%s devam: not ve açıklama kırpılmadı" % label, _label_fits_wrapped(offer._detail))
	offer.hide_offer()
	_board()._is_fail_pending = false
	_board()._set_board_frozen(false)
	_main.set_rewarded_provider(null)
	await _leave()
	# Refill (en uzun ad + sağlayıcı yok + Hamur yetmiyor: en çok satır).
	await _start(LEVEL_04, true)
	if safe_top > 0.0:
		_board()._apply_layout(view.size, safe_top)
	_set_stock(0, 0, 0, 0)
	SaveManager.data["dough"] = 10
	await _open_refill(PowerUp.Type.CLEAR_SMALL)
	var refill: CanvasLayer = _refill()
	var rframe: Control = refill.frame()
	var rrect: Rect2 = rframe.get_global_rect()
	var rtop: float = minf(rrect.position.y, (rframe.get_meta(&"ribbon") as Control).get_global_rect().position.y)
	_c("%s refill: çerçeve + kurdele ekranda, üst ≥ güvenli pay" % label, view.encloses(rrect) and rtop >= safe_top
		and rrect.end.y <= view.size.y - 24.0)
	_c("%s refill: altlık çerçevede, KAPAT ekranda, X ekranda" % label,
		rrect.encloses((rframe.get_meta(&"footer") as Control).get_global_rect().grow(-1.0))
		and view.encloses(refill._close.get_global_rect()) and view.encloses(refill.close_button().get_global_rect()))
	_c("%s refill: güç sanatı görünür ve çerçevede" % label, refill.hero_art().visible
		and rrect.encloses(refill.hero_art().get_global_rect()) and refill.hero_art().get_global_rect().size.x >= 96.0)
	var scrolls: bool = bool(rframe.get_meta(&"body_scrolls", false))
	_c("%s refill: iki kart çerçevede (ya da gövde kaydırılır)" % label, scrolls
		or (rrect.encloses(refill.ad_card().get_global_rect()) and rrect.encloses(refill.dough_card().get_global_rect())))
	_c("%s refill: butonlar ekranda" % label, view.encloses(refill._ad.get_global_rect()) and view.encloses(refill._dough.get_global_rect()))
	_c("%s refill: durum yazıları kırpılmadı" % label, _label_fits_wrapped(refill._ad_note) and _label_fits_wrapped(refill._dough_note)
		and _label_fits(refill._quota) and _label_fits(refill._price))
	await _close_refill()
	SaveManager.data["dough"] = 335
	await _leave()


func _label_fits(label: Label) -> bool:
	var font: Font = label.get_theme_font("font")
	var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0,
		label.get_theme_font_size("font_size")).x
	return width <= label.size.x + 0.5


## Sarılan etiket: yükseklik minimuma eşit (kırpılmadı) ve gövde/çerçeve içinde.
func _label_fits_wrapped(label: Label) -> bool:
	if not label.visible:
		return true
	return label.size.y + 0.5 >= label.get_combined_minimum_size().y and label.get_line_count() <= 3


# --- Performans ---------------------------------------------------------------------

func _test_performance() -> void:
	print("-- performans")
	var offer: CanvasLayer = _revive()
	var refill: CanvasLayer = _refill()
	var n_offer: int = _count_nodes(offer)
	var n_refill: int = _count_nodes(refill)
	print("    düğüm: devam %d, refill %d" % [n_offer, n_refill])
	_c("devam ağacı ≤ 90 düğüm", n_offer <= 90)
	_c("refill ağacı ≤ 130 düğüm", n_refill <= 130)
	_c("parçacık düğümü yok", _count_class(offer, "GPUParticles2D") + _count_class(offer, "CPUParticles2D")
		+ _count_class(refill, "GPUParticles2D") + _count_class(refill, "CPUParticles2D") == 0)
	# Açılıp yerleştikten sonra süren tween yok (kalp pop'u 0.22 s tek seferlik).
	await _start(LEVEL_04, true)
	_main.set_rewarded_provider(null)
	await _open_offer(0)
	await get_tree().create_timer(0.6).timeout
	var running: int = _running_tweens(offer)
	_c("devam: dinlenmede süren tween yok (%d)" % running, running == 0)
	offer.hide_offer()
	_board()._is_fail_pending = false
	_board()._set_board_frozen(false)
	_set_stock(0, 1, 1, 1)
	await _open_refill(PowerUp.Type.BOMB)
	await get_tree().create_timer(0.6).timeout
	running = _running_tweens(refill)
	_c("refill: dinlenmede süren tween yok (%d)" % running, running == 0)
	await _close_refill()
	await _leave()


func _running_tweens(root: Node) -> int:
	var n: int = 0
	for tween in get_tree().get_processed_tweens():
		if tween.is_running():
			n += 1
	return n


# --- Yardımcılar --------------------------------------------------------------------

func _apply_showcase() -> void:
	SaveManager.data["highest_level_unlocked"] = 11
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3}
	SaveManager.data["dough"] = 335
	SaveManager.data["daily_streak"] = 2
	SaveManager.data["unlocked_skins"] = ["common_01", "common_02", "rare_02"]
	SaveManager.data["equipped_skin"] = "rare_02"
	SaveManager.data["merges_since_bonus_chest"] = 10
	SaveManager.data["endless_high_score"] = 0
	SaveManager.data["powerups"] = {"bomb": 0, "upgrade": 0, "shake": 0, "clear_small": 0}
	SaveManager.data["powerup_starter_granted"] = true
	SaveManager.data["rewarded_power_date"] = ""
	SaveManager.data["rewarded_power_grants"] = 0
	SaveManager.data["sfx_enabled"] = true
	SaveManager.data["haptics_enabled"] = true


func _restore_save_file() -> void:
	if not _had_save:
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()


func _resize(view: Vector2i) -> void:
	get_window().size = view
	await get_tree().process_frame
	await get_tree().process_frame


func _settle(frames: int) -> void:
	for i in maxi(frames, 1):
		await get_tree().process_frame
	if frames >= 4:
		await get_tree().create_timer(0.25).timeout
		await get_tree().process_frame


func _count_named(root: Node, name_part: String) -> int:
	var n: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if String(node.name).contains(name_part):
			n += 1
		for child in node.get_children():
			stack.append(child)
	return n


func _count_nodes(root: Node) -> int:
	var n: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		n += 1
		for child in node.get_children():
			stack.append(child)
	return n


func _count_class(root: Node, klass: String) -> int:
	return root.find_children("*", klass, true, false).size()
