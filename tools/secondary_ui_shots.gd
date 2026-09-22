extends Node
## İkincil UI / pencere denetim çekimleri (M8.6-07). Dev aracı — oyun
## çalışırken kullanılmaz. `--headless` İLE ÇALIŞTIRILAMAZ (ekran görüntüsü).
##
## Gerçek `main.tscn` üstünde, birincil ekranlar (Home / Harita / Mağaza /
## Koleksiyon / Gameplay) DEĞİŞTİRİLMEDEN, kalan yedi ikincil yüzeyin bütün
## anlamlı durumları deterministik vitrin verisiyle çekilir:
##
##   daily_*     Günlük ödül penceresi (ilk alım / seri / kırık seri / uzun
##               seri / alınmış durum / açılıştaki GERÇEK claim yolu)
##   chest_*     Bonus sandık bilgi penceresi (0/75, 49/75, 74/75)
##   settings_*  Ayarlar (varsayılan / SFX kapalı / titreşim kapalı /
##               gizlilik açık / oyun içi)
##   pause_*     Mola penceresi (oyun içi)
##   result_*    Round sonu: kazanma (1–3 yıldız), kayıp + teselli, sonsuz
##               rekor / rekorsuz, sandık kapalı anı, her rarity'de Hamur,
##               skin ödülü, geri düşüş (rarity tamam → Hamur), çoklu sandık
##   revive_*    Devam teklifi (2/2, 1/2, talep gönderildi, sağlayıcı yok,
##               hak yok → gerçek kayıp yolu)
##   refill_*    Stok 0 refill (sağlayıcı yok / hazır / kota dolu / Hamur
##               yetmiyor / ikisi de kapalı / talep gönderildi / uzun ad)
##   generic_*   Mağaza satın alma onayı (referans üretim iskeleti)
##
## KAYIT: Vitrin değerleri BELLEKTE (SaveManager.data) verilir; sonuç
## ekranı doğrudan `show_result` ile hazır `ChestReward` nesneleriyle
## açılır (sandık RNG'si ve kayıt yazımı YOK). Yalnız iki durum gerçek yolu
## koşar ve kayda YAZAR: `daily_06_launch_real` (claim) ve
## `revive_05_none_left_real_fail` (teselli ödülü). Araç kayıt dosyasını başta
## byte olarak okur, çıkışta AYNEN geri yazar; bellek verisi de geri konur.
##
## Sahte reklam YOK: `_StubProvider` yalnızca "talep gönderildi, cevap
## bekleniyor" durumunu çekmek için var — hiçbir şey vermez.
##
## Kullanım:
##   godot --path . res://tools/secondary_ui_shots.tscn -- <çıktı_klasörü> [GxY] [safe=61] [groups=daily,chest]
## `safe=N`: A36 punch-hole payı simülasyonu (tuval px; dosya adına `_a36`).
## `groups=`: yalnız seçilen gruplar (daily, chest, settings, generic, pause,
## refill, revive, result); verilmezse hepsi.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SHOT_SIZE := Vector2i(720, 1280)
const LEVEL_04: String = "res://resources/levels/level_04.tres"
const LEVEL_08: String = "res://resources/levels/level_08.tres"
const LEVEL_10: String = "res://resources/levels/level_10.tres"
const ENDLESS: String = "res://resources/levels/endless.tres"


## Ödüllü sağlayıcı TEST ÇİFTİ: talebi alır, hiçbir zaman cevap vermez.
## "Reklam isteniyor…" durumunu çekmek için. Ödül/devam/stok VERMEZ.
class _StubProvider extends RefCounted:
	var revive_requests: int = 0
	var power_requests: int = 0

	func show_rewarded_revive(_main: Node) -> void:
		revive_requests += 1

	func show_rewarded_power(_main: Node, _type: int, _token: int) -> void:
		power_requests += 1


var _out_dir: String = ""
var _size: Vector2i = SHOT_SIZE
var _main: Node2D
var _saved_data: Dictionary = {}
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _safe_top: float = -1.0
var _shots: int = 0
## `groups=daily,chest,...` ile grup secimi (M8.6-08: yalniz tasinan
## pencereler yeniden cekilir, 240 denetim karesi bosuna uretilmez). Bos = hepsi.
var _groups: PackedStringArray = PackedStringArray()


func _wants(group: String) -> bool:
	return _groups.is_empty() or _groups.has(group)


func _ready() -> void:
	# Otomatik GÜNLÜK ÖDÜLLER penceresi (M8.9-02) bu harness'in konusu değil.
	DailyRewards.auto_popup_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() >= 1 else ProjectSettings.globalize_path("user://secondary_ui_shots")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_size = _shot_size(args)
	for arg in args:
		if String(arg).begins_with("safe="):
			_safe_top = float(String(arg).trim_prefix("safe="))
		elif String(arg).begins_with("groups="):
			_groups = String(arg).trim_prefix("groups=").split(",", false)
	DisplayServer.window_set_size(_size)
	await get_tree().process_frame
	await get_tree().process_frame

	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	_saved_data = SaveManager.data.duplicate(true)
	# main._ready günlük ödülü bugün alınmış saysın (kayda yazmasın).
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()

	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_showcase()
	_apply_safe_top_to_shell()

	if _wants("daily"): await _group_daily()
	if _wants("chest"): await _group_chest()
	if _wants("settings"): await _group_settings()
	if _wants("generic"): await _group_generic()
	if _wants("pause"): await _group_pause()
	if _wants("refill"): await _group_refill()
	if _wants("revive"): await _group_revive()
	if _wants("result"): await _group_result()

	SaveManager.data = _saved_data
	_restore_save_file()
	print("bitti -> ", _out_dir, " (", _shots, " çekim)")
	get_tree().quit()


# --- Altyapı -----------------------------------------------------------------

func _restore_save_file() -> void:
	if not _had_save:
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()


func _shot_size(args: PackedStringArray) -> Vector2i:
	if args.size() < 2:
		return SHOT_SIZE
	var parts: PackedStringArray = args[1].split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return SHOT_SIZE
	return Vector2i(int(parts[0]), int(parts[1]))


func _tag() -> String:
	return "%dx%d%s" % [_size.x, _size.y, "_a36" if _safe_top >= 0.0 else ""]


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var file: String = "%s_%s.png" % [name, _tag()]
	var err: int = img.save_png(_out_dir.path_join(file))
	if err == OK:
		_shots += 1
	print(("kaydedildi : " if err == OK else "HATA       : "), file)


func _settle(seconds: float = 0.45) -> void:
	await get_tree().create_timer(seconds).timeout
	await get_tree().process_frame


## Gerçek işaretçi olayı (shop_ui_test ile aynı): basış görseli ve gerçek
## `pressed` yolu için.
func _pointer(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	if pressed:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(ev)


## Yerel takvimde "dün" (DailyReward yerel günü okur).
func _yesterday() -> String:
	var local_unix: int = Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system())
	return Time.get_date_string_from_unix_time(local_unix - 86400)


func _home() -> CanvasLayer:
	return _main._screens[0]


func _shop() -> CanvasLayer:
	return _main._screens[3]


func _show_home() -> void:
	_main._show_tab(0)
	await _settle()


## A36 payı: kabuk ekranları kendi yerleşim kancasıyla, board `_apply_layout`
## ile (her `_start_level` sonrası yeniden uygulanır).
func _apply_safe_top_to_shell() -> void:
	if _safe_top < 0.0:
		return
	for screen in _main._screens:
		if screen.has_method("_layout_with_safe_top"):
			screen._layout_with_safe_top(_safe_top)


func _apply_safe_top_to_board() -> void:
	if _safe_top < 0.0 or _main._board == null:
		return
	_main._board._apply_layout(get_viewport().get_visible_rect().size, _safe_top)


# --- Vitrin kayıt durumu (yalnızca bellekte) ---------------------------------

func _apply_showcase() -> void:
	SaveManager.data["highest_level_unlocked"] = 4
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3}
	SaveManager.data["dough"] = 335
	SaveManager.data["daily_streak"] = 2
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.data["unlocked_skins"] = ["common_01", "common_02", "rare_02", "common_04", "rare_05", "epic_01"]
	SaveManager.data["equipped_skin"] = "rare_02"
	SaveManager.data["merges_since_bonus_chest"] = 49
	SaveManager.data["endless_high_score"] = 0
	SaveManager.data["powerups"] = {"bomb": 4, "upgrade": 1, "shake": 0, "clear_small": 0}
	SaveManager.data["rewarded_power_date"] = ""
	SaveManager.data["rewarded_power_grants"] = 0
	SaveManager.data["sfx_enabled"] = true
	SaveManager.data["haptics_enabled"] = true


# --- Board yardımcıları (shell_shots ile aynı desen) -------------------------

## `detach_main`: board'un `round_finished`'ı main'e GİTMEZ — yığın kendi
## kendine merge yapsa bile gerçek ödül/kayıt/RNG yolu çalışmaz; sonuç
## ekranı yalnız bu aracın verdiği hazır ödüllerle açılır.
func _start_board(level_path: String, detach_main: bool = true) -> void:
	_main._start_level(load(level_path))
	await get_tree().process_frame
	await get_tree().process_frame
	_main._board._dismiss_tutorial()
	if detach_main:
		_main._board.round_finished.disconnect(_main._on_round_finished)
	_apply_safe_top_to_board()
	await get_tree().process_frame


## Round'u terk et ve Ana Sayfa'ya dön (board silinir, pencereler kapanır).
func _leave_board() -> void:
	_main._result.hide_result()
	_main.abandon_run()
	await get_tree().process_frame
	await _show_home()


func _spawn(tier: int, at: Vector2) -> Dumpling:
	return _main._board._spawn_dumpling(tier, at)


func _settle_physics(max_frames: int = 240) -> void:
	for i in max_frames:
		await get_tree().physics_frame
		var moving: bool = false
		for child in _main._board._dumpling_layer.get_children():
			var d := child as Dumpling
			if d != null and d.linear_velocity.length() > 4.0:
				moving = true
				break
		if not moving and i > 30:
			return


## Satır satır yığın: `rows` alttan üste tier listeleri.
func _pile(rows: Array) -> void:
	var board: Node2D = _main._board
	var left: float = board._left_x()
	var right: float = board._right_x()
	var y: float = board.FLOOR_Y - 40.0
	for row in rows:
		var tiers: Array = row
		var total_w: float = 0.0
		for t in tiers:
			total_w += TierConfig.radius(t) * 2.0 + 6.0
		var x: float = (left + right) * 0.5 - total_w * 0.5
		var row_h: float = 0.0
		for t in tiers:
			var r: float = TierConfig.radius(t)
			x += r + 3.0
			_spawn(t, Vector2(clampf(x, left + r, right - r), y - r))
			x += r + 3.0
			row_h = maxf(row_h, r * 2.0)
		y -= row_h + 4.0
		for i in 12:
			await get_tree().physics_frame
	await _settle_physics()


## Birleşmeyen yığınlar: komşu tier'lar farklı — board kendi kendine merge
## yapıp round'u bitirmesin (skor ve hedef vitrin değeriyle tutarlı kalsın).
const PILE_MEDIUM: Array = [[5, 3, 4, 2, 1], [2, 4, 1, 3], [3, 1, 2]]
const PILE_DANGER: Array = [[7, 5, 6], [4, 6, 3, 5], [5, 2, 4, 1, 3], [1, 4, 2, 5, 2], [3, 1, 4, 1, 3, 2], [2, 3, 1, 2, 1]]


# --- Günlük ödül (M8.9-02.1: tek pencere GÜNLÜK ÖDÜLLER, giriş ödülü üstte) ---

func _daily_login(streak: int, broken: bool, just_claimed: bool = false) -> Dictionary:
	return {"streak": streak, "reward": DailyReward.DAILY_DOUGH, "claimed_today": true,
		"just_claimed": just_claimed, "streak_broken": broken}


func _open_daily(login: Dictionary) -> void:
	_main._daily_rewards.open_popup(false, "", false, login)


func _group_daily() -> void:
	await _show_home()
	_open_daily(_daily_login(1, false, true))
	await _settle()
	await _capture("daily_01_first_claim")
	_main._daily_rewards.close_popup()
	await _show_home()

	_open_daily(_daily_login(4, false))
	await _settle()
	await _capture("daily_02_mid_streak")
	_main._daily_rewards.close_popup()
	await _show_home()

	_open_daily(_daily_login(1, true, true))
	await _settle()
	await _capture("daily_03_streak_broken")
	_main._daily_rewards.close_popup()
	await _show_home()

	_open_daily(_daily_login(12, false))
	await _settle()
	await _capture("daily_04_long_streak")
	_main._daily_rewards.close_popup()
	await _show_home()

	# Alınmış durum: Ana Sayfa madalyonundan (gerçek yol; bugün alınmış).
	_home().feature_button(&"daily").pressed.emit()
	await _settle()
	await _capture("daily_05_status_claimed")
	_main._daily_rewards.close_popup()
	await _show_home()

	# GERÇEK açılış yolu (kayda yazar; çıkışta byte'ı geri konur): dün giriş
	# yapılmış → madalyon → DailyReward.claim_if_new_day → pencere (kutlama).
	SaveManager.data["last_login_date"] = _yesterday()
	_home().refresh()
	await _settle()
	await _capture("daily_06_launch_home_claimable")
	_home().feature_button(&"daily").pressed.emit()
	await _settle()
	await _capture("daily_06_launch_real")
	_main._daily_rewards.close_popup()
	_apply_showcase()
	await _show_home()


# --- Bonus sandık bilgisi ----------------------------------------------------

func _group_chest() -> void:
	await _show_home()
	_main._on_chest_requested()
	await _settle()
	await _capture("chest_01_info_mid_49")
	_main._chest_info.close_info()
	await _show_home()

	SaveManager.data["merges_since_bonus_chest"] = 0
	_main._on_chest_requested()
	await _settle()
	await _capture("chest_02_info_fresh_0")
	_main._chest_info.close_info()
	await _show_home()

	SaveManager.data["merges_since_bonus_chest"] = 74
	_main._on_chest_requested()
	await _settle()
	await _capture("chest_03_info_almost_74")
	_main._chest_info.close_info()
	_apply_showcase()
	await _show_home()


# --- Ayarlar -----------------------------------------------------------------

func _group_settings() -> void:
	await _show_home()
	_main.open_settings()
	await _settle()
	await _capture("settings_01_default")
	# Anahtar görselleri `set_on` ile (sinyalsiz → kayda yazmaz).
	_main._settings._sfx_toggle.set_on(false)
	await _settle(0.2)
	await _capture("settings_02_sfx_off")
	_main._settings._sfx_toggle.set_on(true)
	_main._settings._haptics_toggle.set_on(false)
	await _settle(0.2)
	await _capture("settings_03_haptics_off")
	_main._settings._haptics_toggle.set_on(true)
	_main._settings._toggle_privacy()
	await _settle(0.2)
	await _capture("settings_04_privacy_open")
	_main.close_settings()
	await _show_home()

	# Oyun içi ayarlar: HUD ayarlar butonu → board donar.
	await _start_board(LEVEL_04)
	await _pile(PILE_MEDIUM)
	GameState.reset_run()
	GameState.add_score(1240)
	_main._on_board_settings_requested()
	await _settle()
	await _capture("settings_05_ingame")
	_main.close_settings()
	await _leave_board()


# --- Genel pencereler (Mağaza onayı — referans iskelet) ----------------------

func _group_generic() -> void:
	_main._show_tab(3)
	await _settle()
	_shop()._open_power_confirm(PowerUp.Type.BOMB)
	await _settle()
	await _capture("generic_01_shop_confirm_power")
	_shop()._close_confirm()
	await _settle(0.2)
	# Gerçek yol onayı yalnız Hamur yetiyorken açar (kart tarafındaki kapı);
	# doğrudan çağrıda da aynı şart sağlansın: 150 Hamur'luk sahip olunmayan
	# Nadir skin (vitrin 335 Hamur).
	var skin: SkinData = null
	for candidate in SkinLibrary.by_rarity(SkinData.Rarity.RARE):
		if not SaveManager.owns_skin(candidate.id) and Shop.price_of(candidate) <= SaveManager.dough():
			skin = candidate
			break
	_shop()._open_confirm(skin)
	await _settle()
	await _capture("generic_02_shop_confirm_skin")
	_shop()._close_confirm()
	await _show_home()


# --- Mola --------------------------------------------------------------------

func _group_pause() -> void:
	await _start_board(LEVEL_04)
	await _pile(PILE_MEDIUM)
	GameState.reset_run()
	GameState.add_score(1240)
	_main._board.get_node("HUD").back_button.pressed.emit()
	await _settle()
	await _capture("pause_01_open")
	# Ayarlar mola üstünde (iki pencere yığını).
	_main.open_settings()
	await _settle()
	await _capture("pause_02_settings_over_pause")
	_main.close_settings()
	await _settle(0.2)
	await _leave_board()


# --- Stok 0 refill -----------------------------------------------------------

func _open_refill(type: PowerUp.Type) -> void:
	_main._board._on_power_refill_requested(int(type))
	await _settle()


func _close_refill() -> void:
	_main._on_refill_closed()
	await _settle(0.2)


func _group_refill() -> void:
	await _start_board(LEVEL_04)
	await _pile(PILE_MEDIUM)
	GameState.reset_run()
	GameState.add_score(860)
	SaveManager.data["powerups"] = {"bomb": 0, "upgrade": 1, "shake": 0, "clear_small": 0}
	_main._board._refresh_power_bar()
	await get_tree().process_frame

	# 01 sağlayıcı yok (bugünkü gerçek durum): reklam pasif, Hamur açık.
	_main.set_rewarded_provider(null)
	await _open_refill(PowerUp.Type.BOMB)
	await _capture("refill_01_no_provider")
	await _close_refill()

	# 02 sağlayıcı hazır (test çifti): reklam açık, kota 1/1.
	var stub := _StubProvider.new()
	_main.set_rewarded_provider(stub)
	await _open_refill(PowerUp.Type.BOMB)
	await _capture("refill_02_provider_ready")
	await _close_refill()

	# 03 günlük hak tüketilmiş: reklam pasif, sebep yazılı.
	SaveManager.data["rewarded_power_date"] = Time.get_date_string_from_system()
	SaveManager.data["rewarded_power_grants"] = 1
	await _open_refill(PowerUp.Type.BOMB)
	await _capture("refill_03_quota_used")
	await _close_refill()
	SaveManager.data["rewarded_power_date"] = ""
	SaveManager.data["rewarded_power_grants"] = 0

	# 04 Hamur yetmiyor: Hamur butonu pasif.
	SaveManager.data["dough"] = 10
	await _open_refill(PowerUp.Type.BOMB)
	await _capture("refill_04_no_dough")
	await _close_refill()

	# 05 ikisi de kapalı: sağlayıcı yok + Hamur yok.
	_main.set_rewarded_provider(null)
	await _open_refill(PowerUp.Type.BOMB)
	await _capture("refill_05_both_blocked")
	await _close_refill()
	SaveManager.data["dough"] = 335

	# 06 talep gönderildi (test çifti cevap vermez): "Reklam isteniyor…".
	_main.set_rewarded_provider(stub)
	await _open_refill(PowerUp.Type.BOMB)
	_main._refill._ad.pressed.emit()
	await _settle()
	await _capture("refill_06_requesting")
	await _close_refill()

	# 07 Hamur yolu başarısız (yetersiz): pencere açık kalır, uyarı satırı.
	SaveManager.data["dough"] = 10
	_main.set_rewarded_provider(null)
	await _open_refill(PowerUp.Type.BOMB)
	_main._on_dough_refill_requested(int(PowerUp.Type.BOMB))
	await _settle()
	await _capture("refill_07_dough_rejected")
	await _close_refill()
	SaveManager.data["dough"] = 335

	# 08 en uzun güç adı (Temizleyici) + en pahalı (Büyütücü) — metin sığması.
	SaveManager.data["powerups"] = {"bomb": 2, "upgrade": 0, "shake": 0, "clear_small": 0}
	_main._board._refresh_power_bar()
	await get_tree().process_frame
	await _open_refill(PowerUp.Type.CLEAR_SMALL)
	await _capture("refill_08_clear_small_no_provider")
	await _close_refill()
	await _open_refill(PowerUp.Type.UPGRADE)
	await _capture("refill_09_upgrade_no_provider")
	await _close_refill()
	# 10 Sarsıntı (M8.6-10 before seti: dört gücün de stok 0 kahramanı).
	await _open_refill(PowerUp.Type.SHAKE)
	await _capture("refill_10_shake_no_provider")
	await _close_refill()

	_main.set_rewarded_provider(null)
	_apply_showcase()
	await _leave_board()


# --- Devam (revive) ----------------------------------------------------------

func _group_revive() -> void:
	await _start_board(LEVEL_10)
	await _pile(PILE_DANGER)
	GameState.reset_run()
	GameState.add_score(3120)

	# 01 ilk teklif: 2/2.
	_main.set_rewarded_provider(null)
	_main._board._enter_fail_pending()
	await _settle()
	await _capture("revive_01_first_offer_2of2")

	# 02 sağlayıcı yok: DEVAM ET → "Ödüllü reklam henüz bağlı değil."
	_main._revive._continue.pressed.emit()
	await _settle()
	await _capture("revive_02_no_provider_note")

	# 03 talep gönderildi (test çifti): "Reklam isteniyor…", buton pasif.
	var stub := _StubProvider.new()
	_main.set_rewarded_provider(stub)
	_main._revive.show_offer(_main._board.revives_remaining(), _main._board.max_revives(), true)
	_main._revive._continue.pressed.emit()
	await _settle()
	await _capture("revive_03_requesting")
	_main.set_rewarded_provider(null)

	# 04 ikinci teklif: 1/2 (bir devam kullanılmış).
	_main._board._is_fail_pending = false
	_main._board._revives_used = 1
	_main._board._enter_fail_pending()
	await _settle()
	await _capture("revive_04_second_offer_1of2")

	# 05 hak kalmadı → devam penceresi YOK, GERÇEK kayıp yolu (teselli 5
	# Hamur kayda yazılır; çıkışta byte'ı geri konur). Sonuç 0.8 sn sonra.
	_main._revive.hide_offer()
	_main._board._is_fail_pending = false
	_main._board._set_board_frozen(false)
	_main._board._revives_used = 2
	GameState.reset_run()
	GameState.add_score(3120)
	_main._board.round_finished.connect(_main._on_round_finished)
	_main._board._trigger_overflow_fail()
	await _settle(1.4)
	await _capture("revive_05_none_left_real_fail")
	_apply_showcase()
	await _leave_board()


# --- Round sonu --------------------------------------------------------------

func _reward_dough(rarity: SkinData.Rarity, duplicate: bool = false) -> ChestReward:
	var r := ChestReward.new()
	r.rarity = rarity
	r.dough = ChestSystem.RARITY_DOUGH[int(rarity)]
	r.is_duplicate = duplicate
	return r


func _reward_skin(rarity: SkinData.Rarity, index: int = 0) -> ChestReward:
	var r := ChestReward.new()
	r.rarity = rarity
	var pool: Array[SkinData] = SkinLibrary.by_rarity(rarity)
	r.skin = pool[mini(index, pool.size() - 1)]
	return r


func _reward_consolation() -> ChestReward:
	var r := ChestReward.new()
	r.is_consolation = true
	r.dough = ChestSystem.CONSOLATION_DOUGH
	return r


## Board'u bitmiş göster (main'e sinyal GİTMEZ: kayıt/RNG yok) ve sonuç
## ekranını hazır ödüllerle aç. `wait`: yıldız + sandık reveal'i için bekleme.
func _show_result(level_path: String, won: bool, score: int,
		rewards: Array[ChestReward], new_record: bool, name: String,
		wait: float = 2.6, pile: Array = PILE_MEDIUM) -> void:
	await _start_board(level_path)
	await _pile(pile)
	# Yığın yerleşirken olası bir merge skoru şişirmesin: HUD = sonuç.
	GameState.reset_run()
	GameState.add_score(score)
	var board: Node2D = _main._board
	var level: LevelData = _main._current_level
	board._is_finished = false
	board._finish(won)
	_main._result.show_result(level, won, score, level.stars_earned(won, score), rewards, new_record)
	await _settle(wait)
	await _capture(name)


func _group_result() -> void:
	var l4: LevelData = load(LEVEL_04)
	var s1: int = maxi(50, l4.star_2_threshold() - 60)
	var s2: int = l4.star_2_threshold() + 10
	var s3: int = l4.star_3_threshold() + 40

	# Sandık kapalı anı (reveal başlamadan, yıldızlar gizli).
	await _show_result(LEVEL_04, true, s3, [_reward_dough(SkinData.Rarity.RARE)], false,
		"result_00_reveal_pending", 0.05)
	await _leave_board()

	await _show_result(LEVEL_04, true, s3, [_reward_dough(SkinData.Rarity.COMMON)], false,
		"result_01_win_3star_common_dough")
	await _leave_board()
	await _show_result(LEVEL_04, true, s2, [_reward_dough(SkinData.Rarity.RARE)], false,
		"result_02_win_2star_rare_dough")
	await _leave_board()
	await _show_result(LEVEL_04, true, s1, [_reward_dough(SkinData.Rarity.EPIC)], false,
		"result_03_win_1star_epic_dough")
	await _leave_board()
	await _show_result(LEVEL_04, true, s3, [_reward_dough(SkinData.Rarity.LEGENDARY)], false,
		"result_04_win_legendary_dough")
	await _leave_board()
	await _show_result(LEVEL_04, true, s3, [_reward_skin(SkinData.Rarity.RARE, 2)], false,
		"result_05_win_rare_skin")
	await _leave_board()
	await _show_result(LEVEL_04, true, s3, [_reward_skin(SkinData.Rarity.LEGENDARY, 1)], false,
		"result_06_win_legendary_skin")
	await _leave_board()
	await _show_result(LEVEL_04, true, s3, [_reward_dough(SkinData.Rarity.EPIC, true)], false,
		"result_07_win_fallback_epic_complete")
	await _leave_board()
	await _show_result(LEVEL_04, true, s3,
		[_reward_dough(SkinData.Rarity.COMMON), _reward_skin(SkinData.Rarity.EPIC, 2)], false,
		"result_08_win_two_chests", 3.4)
	await _leave_board()
	await _show_result(LEVEL_04, false, 420, [_reward_consolation()], false,
		"result_09_fail_consolation", 1.6, PILE_DANGER)
	await _leave_board()
	await _show_result(LEVEL_04, false, 420,
		[_reward_dough(SkinData.Rarity.RARE), _reward_consolation()], false,
		"result_10_fail_bonus_plus_consolation", 2.2, PILE_DANGER)
	await _leave_board()
	# Uzun hedef metni (tier + skor) ve yüksek skor.
	await _show_result(LEVEL_08, true, 6980, [_reward_dough(SkinData.Rarity.COMMON)], false,
		"result_11_win_l8_score_objective")
	await _leave_board()
	# Sonsuz: rekor / rekorsuz (yıldız yok).
	SaveManager.data["endless_high_score"] = 9860
	await _show_result(ENDLESS, false, 9860, [], true, "result_12_endless_new_record", 0.8, PILE_DANGER)
	await _leave_board()
	SaveManager.data["endless_high_score"] = 12480
	await _show_result(ENDLESS, false, 7410, [_reward_dough(SkinData.Rarity.COMMON)], false,
		"result_13_endless_no_record", 1.6, PILE_DANGER)
	await _leave_board()
	# Üç sandık (level + bonus + …) — dikey sığma stres testi.
	await _show_result(LEVEL_04, true, s3,
		[_reward_dough(SkinData.Rarity.COMMON), _reward_skin(SkinData.Rarity.RARE, 3),
			_reward_dough(SkinData.Rarity.LEGENDARY)], false,
		"result_14_win_three_chests", 4.2)
	await _leave_board()
	_apply_showcase()
