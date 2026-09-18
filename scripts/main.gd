extends Node2D
## Akış kontrolü: ekranlar (Ana Sayfa hub / Harita / Koleksiyon / Mağaza) ->
## oyun -> sonuç -> ekranlar. Oyun kuralları GameBoard'da, ilerleme
## SaveManager'da, ödül kurası ChestSystem'de, fiyatlar Shop'ta; burada
## sadece bunlar birbirine bağlanıyor.
##
## Gezinme (M8.6): Ana Sayfa hub (madalyonlar + OYNA); Harita / Koleksiyon /
## Mağaza kendi `ScreenTopBar`'ıyla (geri -> Ana Sayfa). Eski M8.5-10 alt
## sekme çubuğu M8.6-06 ile tamamen kalktı (UI_VISUAL_SYSTEM §14.4).

const HOME_SCENE: PackedScene = preload("res://scenes/ui/home_screen.tscn")
const LEVEL_SELECT_SCENE: PackedScene = preload("res://scenes/ui/level_select.tscn")
const COLLECTION_SCENE: PackedScene = preload("res://scenes/ui/collection_screen.tscn")
const SHOP_SCENE: PackedScene = preload("res://scenes/ui/shop_screen.tscn")
const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const ROUND_RESULT_SCENE: PackedScene = preload("res://scenes/ui/round_result.tscn")
const DAILY_POPUP_SCENE: PackedScene = preload("res://scenes/ui/daily_reward_popup.tscn")
const REVIVE_OFFER_SCENE: PackedScene = preload("res://scenes/ui/revive_offer.tscn")
const POWER_REFILL_SCENE: PackedScene = preload("res://scenes/ui/power_refill.tscn")
const SETTINGS_SCENE: PackedScene = preload("res://scenes/ui/settings_panel.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
const CHEST_INFO_SCENE: PackedScene = preload("res://scenes/ui/bonus_chest_info.tscn")

## Round bitip sonuç ekranı açılmadan önceki kısa nefes payı — son merge'in
## efekti ekranda kalsın diye.
const RESULT_DELAY: float = 0.8

var _result: CanvasLayer
var _daily: CanvasLayer
var _revive: CanvasLayer
var _refill: CanvasLayer
var _settings: CanvasLayer
var _pause: CanvasLayer
var _chest_info: CanvasLayer
## Android geri tusu debounce (bkz. _notification).
const BACK_DEBOUNCE_MSEC: int = 250
var _last_back_msec: int = -1000
var _board: Node2D
## Ödüllü reklam sağlayıcısı (M9+ AdMob). null = sağlayıcı yok.
##
## Beklenen arayüz (ikisi de opsiyonel, `has_method` ile kontrol ediliyor):
##   show_rewarded_revive(main: Node) -> void
##       ödül kazanılınca  main.grant_revive()
##       kazanılmayınca    main.notify_rewarded_unavailable(mesaj)
##   show_rewarded_power(main: Node, type: int, token: int) -> void
##       ödül kazanılınca  main.grant_rewarded_power(type, token)
##       kazanılmayınca    main.notify_power_rewarded_unavailable(mesaj)
var _rewarded_provider: Object = null

## --- Ödüllü güç refill talebi (M8.5-06) ---
##
## Stale/duplicate reward callback'lerine karşı token. Her yeni talep
## token'ı artırıyor; grant yalnızca AÇIK talebin token'ıyla eşleşirse
## kabul ediliyor ve kabul edilir edilmez token sıfırlanıyor. Böylece:
##   - aynı callback iki kez gelirse ikincisi eşleşmez  (çift grant yok)
##   - eski/iptal edilmiş bir talebin callback'i eşleşmez (stale grant yok)
##   - başka bir güç için gelen callback tip kontrolüne takılır
var _refill_token: int = 0
var _refill_pending_token: int = 0
var _refill_pending_type: int = -1
var _current_level: LevelData
## Ekran indeksi -> ekran: 0 Ana Sayfa, 1 Harita, 2 Koleksiyon, 3 Mağaza.
var _screens: Array[CanvasLayer] = []
var _active_tab: int = 0


func _ready() -> void:
	# Android geri tusu: motor varsayilani (quit_on_go_back) GO_BACK bildirimini
	# gonderdikten sonra uygulamayi KAPATIR — mola/sekme mantigi calissa bile.
	# Cihaz kapisinda (A36, HUD v5) yakalandi: mola acikken geri = uygulama
	# kapandi. Kapanis yalniz asagidaki _notification'da, ana sekmede.
	get_tree().quit_on_go_back = false
	_result = ROUND_RESULT_SCENE.instantiate()
	_result.retry_pressed.connect(_on_retry_pressed)
	_result.exit_pressed.connect(_on_exit_pressed)
	add_child(_result)

	# Kayıttaki ses ayarı açılışta uygulanır (AudioManager SaveManager'dan
	# önce yükleniyor, kendisi okuyamıyor).
	AudioManager.set_sfx_enabled(SaveManager.sfx_enabled())
	Haptics.set_enabled(SaveManager.haptics_enabled())

	var home: CanvasLayer = HOME_SCENE.instantiate()
	home.play_pressed.connect(_on_play_pressed)
	home.settings_pressed.connect(open_settings)
	# Home hub (M8.6-03B): yuzen ozellik madalyonlari ve level plakasi.
	home.map_requested.connect(_on_play_pressed)
	home.shop_requested.connect(_on_shop_requested)
	home.collection_requested.connect(_on_collection_requested)
	home.daily_requested.connect(_on_daily_requested)
	home.chest_requested.connect(_on_chest_requested)
	var select: CanvasLayer = LEVEL_SELECT_SCENE.instantiate()
	select.level_chosen.connect(_start_level)
	# Harita (M8.6-04): kendi ust satiri — geri -> Ana Sayfa, Hamur "+" -> Magaza.
	select.home_requested.connect(_on_home_requested)
	select.shop_requested.connect(_on_shop_requested)
	var album: CanvasLayer = COLLECTION_SCENE.instantiate()
	# Koleksiyon (M8.6-06): kendi ust satiri — geri -> Ana Sayfa, Hamur "+" ve
	# kilitli skin'in MAGAZAYA GIT'i -> Magaza.
	album.home_requested.connect(_on_home_requested)
	album.shop_requested.connect(_on_shop_requested)
	album.shop_skin_requested.connect(_on_shop_skin_requested)
	var shop: CanvasLayer = SHOP_SCENE.instantiate()
	# Magaza (M8.6-05): kendi ust satiri — geri -> Ana Sayfa; sekme cubugu yok.
	shop.home_requested.connect(_on_home_requested)
	_screens = [home, select, album, shop]
	for screen in _screens:
		add_child(screen)

	_daily = DAILY_POPUP_SCENE.instantiate()
	_daily.closed.connect(_on_daily_closed)
	add_child(_daily)

	_revive = REVIVE_OFFER_SCENE.instantiate()
	_revive.rewarded_revive_requested.connect(_on_rewarded_revive_requested)
	_revive.decline_pressed.connect(decline_revive)
	add_child(_revive)

	_refill = POWER_REFILL_SCENE.instantiate()
	_refill.rewarded_refill_requested.connect(_on_rewarded_power_requested)
	_refill.dough_refill_requested.connect(_on_dough_refill_requested)
	_refill.closed.connect(_on_refill_closed)
	add_child(_refill)

	_settings = SETTINGS_SCENE.instantiate()
	_settings.closed.connect(_on_settings_closed)
	add_child(_settings)

	_pause = PAUSE_MENU_SCENE.instantiate()
	_pause.resume_pressed.connect(resume_game)
	_pause.restart_pressed.connect(_on_pause_restart)
	_pause.exit_pressed.connect(abandon_run)
	add_child(_pause)

	_chest_info = CHEST_INFO_SCENE.instantiate()
	_chest_info.play_pressed.connect(_on_play_pressed)
	add_child(_chest_info)

	_show_tab(0)
	_check_daily_reward()


# --- Ekranlar ---

## Tek bir ekran görünür kalır. Her geçişte refresh() çağrılıyor: Hamur ve
## koleksiyon sayacı dört ekranda da gösteriliyor, biri diğerini eskitmesin.
## (Ad tarihsel: "sekme" = ekran indeksi; alt sekme çubuğu artık yok.)
func _show_tab(tab: int) -> void:
	if tab < 0 or tab >= _screens.size():
		return
	var changed: bool = tab != _active_tab or not _screens[tab].visible
	_active_tab = tab
	for i in _screens.size():
		var screen: CanvasLayer = _screens[i]
		screen.visible = i == tab
		if i == tab and screen.has_method("refresh"):
			screen.refresh()
	# Kısa giriş geçişi (0.16 sn, solma + hafif kayma). Aynı sekme yeniden
	# istenirse (günlük ödül kapanışı gibi) oynatılmıyor.
	if changed:
		UiMotion.screen_in(_screens[tab])


# --- Ayarlar (M8.5-10) ---

func open_settings() -> void:
	_settings.open_panel()


func close_settings() -> void:
	_settings.close_panel()


## Oyun içi HUD'daki ayarlar butonu (M8.6-02): pencere açılırken board
## donar (fail/refill dondurmasıyla aynı makine), kapanınca çözülür.
func _on_board_settings_requested() -> void:
	if _board != null and is_instance_valid(_board):
		_board.set_menu_paused(true)
	open_settings()


func _on_settings_closed() -> void:
	# Mola penceresi hâlâ açıksa board donuk kalır.
	if _board != null and is_instance_valid(_board) and not _pause.visible:
		_board.set_menu_paused(false)


# --- Mola / çıkış (M8.6-02 HUD v2) ---
#
# Oyun içi Geri, Çıkış ve Android geri tuşu aynı pencereyi açar. Round
# YALNIZCA "Ana Menüye Dön" ile terk edilir: sonuç ekranı, ödül ve kayıt
# akışı ÇALIŞMAZ (terk edilen round tamamlanmış sayılmaz).

func open_pause_menu() -> void:
	if _board == null or not is_instance_valid(_board):
		return
	if _board.is_fail_pending() or _board.is_refill_pending():
		# Devam/refill penceresi açıkken mola açılmaz — o pencere karar bekliyor.
		return
	if _board.is_finished():
		# Round bitti, sonuç ekranı RESULT_DELAY sonra açılacak (M8.6-09): bu
		# aralıkta mola açılmaz — açılsaydı "Ana Menüye Dön" board'u silip
		# haritaya dönerken sonuç ekranı haritanın üstünde belirirdi; Android
		# geri de sonuç ekranıyla aynı şekilde yok sayılır.
		return
	if _settings != null and _settings.visible:
		# Ayarlar açıkken mola açılmaz (M8.6-08 z-order kuralı: aynı anda tek
		# ikincil pencere odakta; Ayarlar katman 13, Mola 12). Dokunma yolu
		# zaten karartmayla kapalı; bu, kod yollarını da kapatır.
		return
	_board.set_menu_paused(true)
	_pause.open_menu()


func resume_game() -> void:
	_pause.close_menu()
	if _board != null and is_instance_valid(_board) and not _settings.visible:
		_board.set_menu_paused(false)


func _on_pause_restart() -> void:
	_pause.close_menu()
	if _current_level != null:
		_start_level(_current_level)


## Round'u terk et: board silinir, harita sekmesine dönülür.
func abandon_run() -> void:
	_pause.close_menu()
	_result.hide_result()
	_clear_board()
	_show_tab(1)


func is_pause_open() -> bool:
	return _pause != null and _pause.visible


## Android geri tuşu (M8.5-10 UX). Sıra: açık pencere kapanır → sekme
## ekranındaysa Ana Sayfa'ya dönülür → Ana Sayfa'da hiçbir şey olmaz.
## Oyun sırasında bilerek YOK SAYILIYOR: yanlışlıkla round kaybettirmek
## ya da uygulamadan çıkmak istemiyoruz.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	# Godot 4.6 Android tek geri basisinda GO_BACK'i IKI kez gonderebiliyor
	# (AKEYCODE_BACK tus yolu + OnBackPressedDispatcher): mola acilip aninda
	# kapaniyordu (A36 cihaz kapisi, 3 tuslu gezinme / adb keyevent). Ayni
	# basisin ikinci kopyasi yok sayilir.
	var now: int = Time.get_ticks_msec()
	if now - _last_back_msec < BACK_DEBOUNCE_MSEC:
		return
	_last_back_msec = now
	if _settings != null and _settings.visible:
		close_settings()
		return
	if _chest_info != null and _chest_info.visible:
		_chest_info.close_info()
		return
	if _daily != null and _daily.visible:
		_daily.close_popup()
		return
	# Sonuç ekranı karar bekler: geri tuşu yok sayılır (mola açılmaz, çıkılmaz).
	if _result != null and _result.visible:
		return
	# Oyun sırasında: uygulama KAPANMAZ, mola penceresi açılır/kapanır.
	if _board != null and is_instance_valid(_board):
		if _pause.visible:
			resume_game()
		else:
			open_pause_menu()
		return
	var active: CanvasLayer = _screens[_active_tab] if _active_tab < _screens.size() else null
	if active != null and active.has_method("handle_back") and active.handle_back():
		return
	if _active_tab != 0:
		_show_tab(0)
		return
	# Ana sayfada, kapatacak pencere yok: uygulamadan cik (Android beklentisi).
	get_tree().quit()


## Oyun sırasında ve sonuç ekranında hiçbir kabuk ekranı görünmemeli.
func _hide_shell() -> void:
	for screen in _screens:
		screen.visible = false


func _on_play_pressed() -> void:
	_show_tab(1)


## Harita (M8.6-04), Magaza (M8.6-05) ve Koleksiyon (M8.6-06) ust
## satirindaki geri butonu: Ana Sayfa.
func _on_home_requested() -> void:
	_show_tab(0)


## Koleksiyon vitrinindeki kilitli skin'in "MAĞAZAYA GİT" kısayolu, Ana
## Sayfa / Harita / Koleksiyon Hamur pill'inin "+" butonu ve Mağaza madalyonu.
func _on_shop_requested() -> void:
	_show_tab(3)


## Koleksiyon'da kilitli skin'in MAĞAZAYA GİT'i: Mağaza açılır ve o skin'in
## kartına kaydırılır (satın alma yine yalnız Mağaza'da).
func _on_shop_skin_requested(skin_id: StringName) -> void:
	_show_tab(3)
	_screens[3].focus_skin(skin_id)


## Ana Sayfa'daki Koleksiyon madalyonu.
func _on_collection_requested() -> void:
	_show_tab(2)


## Ana Sayfa'daki Günlük madalyonu: bugünkü ödül henüz alınmadıysa (nadir —
## açılışta zaten alınır; cihaz tarihi ilerlemişse) AYNI claim yolu; alınmışsa
## durum penceresi. Ödül mantığı DailyReward'da, burada değil.
func _on_daily_requested() -> void:
	if DailyReward.is_claimable():
		_check_daily_reward()
		if _screens[0].has_method("refresh"):
			_screens[0].refresh()
		if not _daily.visible:
			_daily.show_status(SaveManager.daily_streak())
		return
	_daily.show_status(SaveManager.daily_streak())


## Ana Sayfa'daki Bonus sandık madalyonu: kural + ilerleme penceresi
## (GAME_DESIGN §5.2), OYNA → harita.
func _on_chest_requested() -> void:
	_chest_info.open_info()


## Günlük giriş ödülü (GAME_DESIGN.md §5.4). Günde bir kez, açılışta.
func _check_daily_reward() -> void:
	var result: Dictionary = DailyReward.claim_if_new_day()
	if result["claimed"]:
		_daily.show_reward(result)


func _on_daily_closed() -> void:
	_show_tab(_active_tab)


# --- Oyun ---

func _start_level(level: LevelData) -> void:
	_current_level = level
	_hide_shell()
	_result.hide_result()
	_clear_board()
	if _pause != null:
		_pause.close_menu()

	_revive.hide_offer()
	_refill.hide_refill()
	_clear_refill_request()

	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(level)
	_board.round_finished.connect(_on_round_finished)
	_board.revive_offered.connect(_on_revive_offered)
	_board.power_refill_offered.connect(_on_power_refill_offered)
	_board.settings_requested.connect(_on_board_settings_requested)
	_board.pause_requested.connect(open_pause_menu)
	add_child(_board)


func _clear_board() -> void:
	if _revive != null:
		_revive.hide_offer()
	if _refill != null:
		_refill.hide_refill()
	_clear_refill_request()
	if _board != null:
		_board.queue_free()
		_board = null


# --- Devam etme (revive) — GAME_DESIGN.md §11 ---
#
# Sorumluluk dağılımı:
#   GameBoard  : fail-pending state'i, board'u dondurma, kurtarma temizliği
#   ReviveOffer: pencere ve CTA; devam HAKKI VERMEZ, yalnızca talep yayar
#   Main (bu)  : ikisini bağlayan sağlayıcı kancası
#
# INVARIANT: devam hakkı YALNIZCA grant_revive() ile verilir ve bu metodu
# yalnızca "ödül kazanıldı" callback'i çağırmalıdır. "Reklam kapandı"
# callback'i devam DEĞİLDİR — kapanma ödülsüz de olabilir.

## Board devam teklifi açtı: round HENÜZ BİTMEDİ, hiçbir ödül/sonuç akışı
## çalışmadı.
func _on_revive_offered(remaining: int) -> void:
	_revive.show_offer(remaining, _board.max_revives())


## Oyuncu ödüllü CTA'ya bastı.
##
## ⚠️ BURADA REKLAM YOK ve DEVAM VERİLMİYOR. Sağlayıcı bağlanana kadar tek
## yaptığı şey oyuncuya durumu söylemek. Sahte reklam oynatmak ya da bedava
## devam vermek bilinçli olarak YAPILMIYOR (GAME_DESIGN.md §11).
func _on_rewarded_revive_requested() -> void:
	if _rewarded_provider != null \
			and _rewarded_provider.has_method("show_rewarded_revive"):
		_rewarded_provider.call("show_rewarded_revive", self)
		return
	notify_rewarded_unavailable("Ödüllü reklam henüz bağlı değil.")


## Sağlayıcının "ödül kazanıldı" callback'i buraya bağlanır. Tek devam
## verme yolu budur.
##
## Dönüş: devam gerçekten verildiyse true (teklif kapalıysa ya da hak
## bittiyse false ve hiçbir şey değişmez).
func grant_revive() -> bool:
	if _board == null or not is_instance_valid(_board):
		return false
	if not _board.grant_revive():
		return false
	_revive.hide_offer()
	return true


## Oyuncu "Bitir" dedi ya da sağlayıcı devreden çıktı: round kesin biter.
## Devam hakkı TÜKETİLMEZ.
func decline_revive() -> void:
	_revive.hide_offer()
	if _board != null and is_instance_valid(_board):
		_board.decline_revive()


## Reklam yüklenemedi / gösterilemedi / ödül kazanılmadı. Teklif AÇIK KALIR,
## hak tüketilmez, oyunun fail-pending durumu sürer.
func notify_rewarded_unavailable(message: String) -> void:
	_revive.show_unavailable(message)


## Sağlayıcıyı bağlar (M9+). Beklenen arayüz için `_rewarded_provider`
## tanımına bakın.
func set_rewarded_provider(provider: Object) -> void:
	_rewarded_provider = provider


# --- Stok 0 güç refill'i — GAME_DESIGN.md §5.7.3 ---
#
# Sorumluluk dağılımı:
#   GameBoard   : oyunu dondurma, niyeti hatırlama, çözülme
#   PowerRefill : pencere ve iki CTA; STOK VERMEZ, yalnızca talep yayar
#   RewardedPolicy : günlük kota + tek transaction grant
#   Main (bu)   : hepsini bağlayan sağlayıcı kancası ve token güvenliği
#
# INVARIANT: ödüllü stok YALNIZCA `grant_rewarded_power()` ile verilir ve bu
# metodu yalnızca "ödül kazanıldı" callback'i çağırmalıdır. Reklamın
# istenmesi, açılması, yüklenememesi ve ödülsüz kapanması NE stok verir NE
# kota tüketir — revive'daki (§11.2) invariant'ın aynısı.

## Sağlayıcı gerçekten bağlı ve ödüllü güç gösterebiliyor mu?
func _power_provider_ready() -> bool:
	return (_rewarded_provider != null
		and _rewarded_provider.has_method("show_rewarded_power"))


## Board stok 0 bir güç istedi ve oyunu dondurdu.
func _on_power_refill_offered(type: int) -> void:
	_clear_refill_request()
	_refill.show_refill(type as PowerUp.Type, _power_provider_ready())


## Oyuncu ödüllü CTA'ya bastı.
##
## ⚠️ BURADA REKLAM YOK ve STOK VERİLMİYOR. Sağlayıcı bağlanana kadar tek
## yaptığı şey oyuncuya durumu söylemek. Sahte reklam oynatmak ya da bedava
## stok vermek bilinçli olarak YAPILMIYOR.
func _on_rewarded_power_requested(type: int) -> void:
	if not PowerUp.is_valid_type(type):
		return
	# Kota kontrolü talep anında da yapılıyor: buton zaten pasif olmalı ama
	# tek savunma hattı UI olmasın.
	if not RewardedPolicy.can_grant():
		notify_power_rewarded_unavailable(
			"Bugünkü reklam hakkın doldu, yarın yenilenir.")
		return

	# Yeni talep = yeni token. Önceki talebin callback'i artık geçersiz.
	_refill_token += 1
	_refill_pending_token = _refill_token
	_refill_pending_type = type

	if _power_provider_ready():
		_rewarded_provider.call("show_rewarded_power", self, type,
			_refill_pending_token)
		return
	notify_power_rewarded_unavailable("Ödüllü reklam henüz bağlı değil.")


## Sağlayıcının "ödül kazanıldı" callback'i. Ödüllü stok vermenin TEK yolu.
##
## Üç kapı: açık bir talep olmalı, token eşleşmeli, tip eşleşmeli. Token
## kabul edilir edilmez sıfırlanıyor — aynı callback ikinci kez gelirse
## artık eşleşmez.
##
## Dönüş: stok gerçekten verildiyse true.
func grant_rewarded_power(type: int, token: int) -> bool:
	if _refill_pending_token == 0 or token != _refill_pending_token:
		# Stale ya da duplicate callback: sessizce yok sayılır.
		return false
	if type != _refill_pending_type or not PowerUp.is_valid_type(type):
		# Yanlış güç için gelen callback başka bir güce stok VERMEZ.
		return false

	# Token'ı ÖNCE tüket: grant başarısız olsa bile aynı callback tekrar
	# denenemesin.
	_clear_refill_request()

	if not RewardedPolicy.grant(type as PowerUp.Type):
		# Kota dolmuş (yarış durumu): stok verilmedi, pencere açık kalıyor.
		notify_power_rewarded_unavailable(
			"Bugünkü reklam hakkın doldu, yarın yenilenir.")
		return false

	_finish_refill(type as PowerUp.Type, "%s ×1 kazandın!")
	return true


## Oyuncu Hamurla almayı seçti. Fiyat `PowerUpEconomy`'den — mağazayla
## AYNI source-of-truth, UI'da hardcode yok. Satın alma M8.5-05'teki tek
## mutasyon + tek save yolundan geçiyor.
func _on_dough_refill_requested(type: int) -> void:
	if not PowerUp.is_valid_type(type):
		return
	if not PowerUpEconomy.purchase(type as PowerUp.Type):
		# Yetersiz Hamur: HİÇBİR state değişmez, pencere açık kalır.
		AudioManager.play(&"ui_invalid")
		_refill.show_unavailable("Hamur yetmiyor (%d Hamur'un var)."
			% SaveManager.dough(), _power_provider_ready())
		return
	_finish_refill(type as PowerUp.Type, "%s ×1 alındı!")


## Refill başarılı: pencereyi kapat, oyunu sürdür ve oyuncunun ilk
## niyetine dön (hedefli güçlerde hedefleme yeniden açılır — bkz.
## GameBoard.exit_refill_pending).
func _finish_refill(type: PowerUp.Type, message: String) -> void:
	AudioManager.play(&"ui_purchase")
	Haptics.medium()
	_refill.hide_refill()
	if _board != null and is_instance_valid(_board):
		_board.exit_refill_pending(true)
	print_verbose(message % PowerUp.display_name(type))


## Reklam yüklenemedi / gösterilemedi / ödül kazanılmadı. Pencere AÇIK
## KALIR, kota tüketilmez, stok değişmez.
func notify_power_rewarded_unavailable(message: String) -> void:
	_clear_refill_request()
	_refill.show_unavailable(message, _power_provider_ready())


## Oyuncu pencereyi kapattı: hiçbir şey alınmadı, oyun kaldığı yerden
## devam ediyor. Niyet geri dönüşü YOK (oyuncu vazgeçti).
func _on_refill_closed() -> void:
	_clear_refill_request()
	_refill.hide_refill()
	if _board != null and is_instance_valid(_board):
		_board.exit_refill_pending(false)


func _clear_refill_request() -> void:
	_refill_pending_token = 0
	_refill_pending_type = -1


func _on_round_finished(won: bool) -> void:
	# Round gerçekten bitti: teklif penceresi her hâlükârda kapanır (kazanma
	# fail-pending sırasında da gerçekleşebiliyor).
	_revive.hide_offer()

	var score: int = GameState.score
	var merges: int = GameState.merge_count
	var stars: int = _current_level.stars_earned(won, score)
	var new_record: bool = false
	# Sonuç ekranı için salt-okunur bağlam (M8.6-09): "LEVEL N AÇILDI /
	# SONSUZ MOD AÇILDI" rozeti yalnız BU round yeni bir kilit açtıysa
	# (yazımdan önceki değerle karşılaştırılır — tekrar oynanan level'da
	# yok), kayıp notu için ulaşılan tier. İkisi de kayda dokunmaz.
	var unlocked_before: int = SaveManager.highest_level_unlocked()
	var reached_tier: int = _board.max_tier_reached() \
		if _board != null and is_instance_valid(_board) else 0

	if _current_level.is_endless:
		new_record = SaveManager.record_endless_score(score)
	elif won:
		SaveManager.complete_level(_current_level.level_number)
		SaveManager.record_stars(_current_level.level_number, stars)
	var newly_unlocked: bool = SaveManager.highest_level_unlocked() > unlocked_before

	var rewards: Array[ChestReward] = _collect_rewards(won, merges)

	await get_tree().create_timer(RESULT_DELAY).timeout
	_result.show_result(_current_level, won, score, stars, rewards, new_record,
		newly_unlocked, reached_tier)


## GAME_DESIGN.md §5.2: level tamamlanınca 1 sandık, ayrıca her 75 merge'de
## level'dan bağımsız bir bonus sandık. §5.1: kaybedilse bile teselli ödülü.
func _collect_rewards(won: bool, merges: int) -> Array[ChestReward]:
	var rewards: Array[ChestReward] = []

	if won and not _current_level.is_endless:
		rewards.append(ChestSystem.open())

	for i in SaveManager.add_merges(merges):
		rewards.append(ChestSystem.open())

	if not won and not _current_level.is_endless:
		rewards.append(ChestSystem.consolation())

	return rewards


func _on_retry_pressed() -> void:
	_start_level(_current_level)


func _on_exit_pressed() -> void:
	_result.hide_result()
	_clear_board()
	# Oyundan çıkınca haritaya dönülür — oynanan yerin yanına.
	_show_tab(1)
