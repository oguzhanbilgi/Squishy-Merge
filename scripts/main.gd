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
const DAILY_REWARDS_SCENE: PackedScene = preload("res://scenes/ui/daily_rewards_popup.tscn")
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
## GÜNLÜK ÖDÜLLER penceresi (M8.9-02): ücretsiz sandık + reklamlı Hamur +
## reklamlı sandık. Günlük giriş ödülü (`_daily`, GAME_DESIGN §5.4) ayrı ve
## DEĞİŞMEDİ; ikisi aynı anda açılmaz (giriş ödülü kapanınca sıra buna gelir).
var _daily_rewards: CanvasLayer
var _revive: CanvasLayer
var _refill: CanvasLayer
var _settings: CanvasLayer
var _pause: CanvasLayer
var _chest_info: CanvasLayer
## Android geri tusu debounce (bkz. _notification).
const BACK_DEBOUNCE_MSEC: int = 250
var _last_back_msec: int = -1000
var _board: Node2D
## Ödüllü reklam sağlayıcısı. null = sağlayıcı yok (masaüstü / eklentisiz).
## Production'da `MonetizationManager` (M8.9-01, AdMob); testlerde stub.
##
## Beklenen arayüz (hepsi opsiyonel, `has_method` ile kontrol ediliyor):
##   show_rewarded_revive(main: Node) -> void
##       ödül kazanılınca  main.grant_revive()
##       kazanılmayınca    main.notify_rewarded_unavailable(mesaj)
##   show_rewarded_power(main: Node, type: int, token: int) -> void
##       ödül kazanılınca  main.grant_rewarded_power(type, token)
##       kazanılmayınca    main.notify_power_rewarded_unavailable(mesaj)
##   show_rewarded_daily_chest(main, day_key, token) /
##   show_rewarded_daily_dough(main, day_key, token)        (M8.9-02)
##       ödül kazanılınca  main.grant_daily_chest / grant_daily_dough(day_key, token)
##       kazanılmayınca    main.notify_daily_rewarded_unavailable(kind, mesaj)
##   try_show_interstitial(break_name, callback) -> bool     (M8.9-02)
##       doğal molada geçiş reklamı; true = gösterildi, callback kapanınca
##   is_rewarded_ready() -> bool   yüklü reklam ŞİMDİ gösterilebilir mi
##                                 (yoksa sağlayıcı bağlı = hazır sayılır)
##   rewarded_note() -> String     hazır değilken pencerede yazan sebep
##   ensure_rewarded() -> void     pencere açıldı, hazırlanmaya başla
##   cancel_rewarded_request()     pencere kapandı / round bitti
var _rewarded_provider: Object = null
## Production reklam yöneticisi (M8.9-01). Eklenti yoksa (masaüstü, headless
## testler) null — sağlayıcısız eski davranış. Testler `ads_backend_override`
## ile sahte arka uç takıp aynı Main yollarını çalıştırır.
var _ads: MonetizationManager = null
static var ads_backend_override: AdBackend = null

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
## --- Günlük reklamlı ödül talebi (M8.9-02) — refill token deseninin aynısı ---
## Bağlam: tür ("daily_chest" / "daily_dough") + talebin GÜN anahtarı + token.
## Grant yalnız açık talebin token'ı VE günü eşleşirse; kabul edilir edilmez
## token sıfırlanır (çift/geç/eski callback ödül veremez).
var _daily_token: int = 0
var _daily_pending_token: int = 0
var _daily_pending_kind: String = ""
var _daily_pending_day: String = ""
## Sonuç ekranı geçişi (M8.9-02): round bitişi başına tam bir kez.
var _result_seq: int = 0
## _ready tamamlandı: otomatik günlük pencere ancak bundan sonra (açılış
## sırasındaki _show_tab günlük giriş ödülünün önüne geçmesin).
var _booted: bool = false
var _current_level: LevelData
## Ekran indeksi -> ekran: 0 Ana Sayfa, 1 Harita, 2 Koleksiyon, 3 Mağaza.
var _screens: Array[CanvasLayer] = []
var _active_tab: int = 0
## Ekran indeksi -> reklam yüzeyi (banner yalnız yöneticinin izin verdiği
## yüzeylerde; Harita v1'de banner dışı — ADS_SYSTEM §6).
const TAB_SURFACES: Array[int] = [MonetizationManager.Surface.HOME, MonetizationManager.Surface.MAP,
	MonetizationManager.Surface.COLLECTION, MonetizationManager.Surface.SHOP]


func _ready() -> void:
	# Android geri tusu: motor varsayilani (quit_on_go_back) GO_BACK bildirimini
	# gonderdikten sonra uygulamayi KAPATIR — mola/sekme mantigi calissa bile.
	# Cihaz kapisinda (A36, HUD v5) yakalandi: mola acikken geri = uygulama
	# kapandi. Kapanis yalniz asagidaki _notification'da, ana sekmede.
	get_tree().quit_on_go_back = false
	# Reklam yöneticisi EKRANLARDAN ÖNCE: banner yuvası (UiKit.bottom_inset)
	# açılışta bir kez hesaplanır, ekranlar ilk yerleşimde onu okur.
	_ads = MonetizationManager.create(ads_backend_override)
	if _ads != null:
		# Onboarding (tutorial, M8.10) bitmeden yuva 0 ve reklam yok; kayıt
		# karar verir (eski kayıt ilerleme kanıtıyla tamamlanmış sayılır).
		_ads.set_onboarding_completed(SaveManager.onboarding_completed())
		add_child(_ads)
		_ads.rewarded_availability_changed.connect(_on_rewarded_availability_changed)
		set_rewarded_provider(_ads)
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
	# Magaza GUNLUK ODULLER karti (M8.9-02): ayni pencere, gun boyu acilabilir.
	shop.daily_rewards_requested.connect(open_daily_rewards)
	_screens = [home, select, album, shop]
	for screen in _screens:
		add_child(screen)

	_daily = DAILY_POPUP_SCENE.instantiate()
	_daily.closed.connect(_on_daily_closed)
	add_child(_daily)

	_daily_rewards = DAILY_REWARDS_SCENE.instantiate()
	_daily_rewards.free_chest_requested.connect(_on_daily_free_chest_requested)
	_daily_rewards.ad_dough_requested.connect(_on_daily_ad_dough_requested)
	_daily_rewards.ad_chest_requested.connect(_on_daily_ad_chest_requested)
	_daily_rewards.closed.connect(_on_daily_rewards_closed)
	add_child(_daily_rewards)

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
	_settings.set_privacy_options_source(_ads)
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
	# Günlük ödüller (M8.9-02): görülen en yeni gün kayda işlenir (saat geri
	# alma koruması), sonra günlük giriş ödülü; o kapanınca (ya da yoksa
	# hemen) GÜNLÜK ÖDÜLLER penceresi günde bir kez.
	DailyRewards.observe_day()
	_check_daily_reward()
	_booted = true
	_maybe_auto_open_daily_rewards()


# --- Ekranlar ---

## Tek bir ekran görünür kalır. Her geçişte refresh() çağrılıyor: Hamur ve
## koleksiyon sayacı dört ekranda da gösteriliyor, biri diğerini eskitmesin.
## (Ad tarihsel: "sekme" = ekran indeksi; alt sekme çubuğu artık yok.)
func _show_tab(tab: int) -> void:
	if tab < 0 or tab >= _screens.size():
		return
	var changed: bool = tab != _active_tab or not _screens[tab].visible
	_active_tab = tab
	_set_ad_surface(TAB_SURFACES[tab])
	for i in _screens.size():
		var screen: CanvasLayer = _screens[i]
		screen.visible = i == tab
		if i == tab and screen.has_method("refresh"):
			screen.refresh()
	# Kısa giriş geçişi (0.16 sn, solma + hafif kayma). Aynı sekme yeniden
	# istenirse (günlük ödül kapanışı gibi) oynatılmıyor.
	if changed:
		UiMotion.screen_in(_screens[tab])
	# Oyundan / sonuçtan kabuğa dönüldü: günlük pencere bugün hiç
	# gösterilmediyse (açılış oyun içindeyken ertelenmişse) şimdi.
	_maybe_auto_open_daily_rewards()


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
	if what == NOTIFICATION_APPLICATION_RESUMED:
		# Öne dönüş (M8.9-02): gün değişmiş olabilir — en yeni gün kayda işlenir,
		# günlük pencere o gün için henüz gösterilmediyse uygun ekranda açılır.
		DailyRewards.observe_day()
		_maybe_auto_open_daily_rewards()
		return
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
	if _daily_rewards != null and _daily_rewards.visible:
		_daily_rewards.close_popup()
		return
	# Sonuç ekranı karar bekler: geri tuşu yok sayılır (mola açılmaz, çıkılmaz).
	if _result != null and _result.visible:
		return
	# Stok 0 refill penceresi terminal DEĞİL: geri = Kapat (hiçbir şey alınmaz,
	# oyun kaldığı yerden sürer) — diğer terminal olmayan pencerelerle aynı
	# (M8.6-07 denetiminin tek boşluğu, M8.6-10'da kapandı). Devam teklifi
	# ise karar bekler: aşağıda open_pause_menu fail-pending'de çıkar → yok
	# sayılır (ölü board'a dönüş / çıkış / sonuç atlama yok).
	if _refill != null and _refill.visible:
		_on_refill_closed()
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


# --- GÜNLÜK ÖDÜLLER (M8.9-02) — docs/monetization/DAILY_REWARDS.md ---
#
# Sorumluluk dağılımı:
#   DailyRewards      : gün anahtarı, üç ayrı kota, kura, TEK transaction grant
#   DailyRewardsPopup : pencere; ödül VERMEZ, yalnız talep yayar ve sonucu gösterir
#   Main (bu)         : ikisini ve sağlayıcıyı bağlayan kanca + token güvenliği
#
# INVARIANT: reklamlı günlük ödül YALNIZCA grant_daily_chest / grant_daily_dough
# ile verilir ve bu metotları yalnızca "ödül kazanıldı" callback'i çağırmalıdır.
# Talep, açılış, yüklenememe, ödülsüz kapanış NE ödül verir NE kota tüketir.
# Ücretsiz sandık reklamsız: AÇ → tek transaction → reveal.

## Otomatik günlük pencere: günde bir kez, onboarding bitmişse, kabuk
## ekranındayken (oyun / sonuç / başka pencere yokken). Gösterildiği an
## "bugün görüldü" işaretlenir — kapatmak hiçbir ödül tüketmez; Mağaza'dan
## gün boyu yeniden açılır.
func _maybe_auto_open_daily_rewards() -> void:
	if not _booted or _daily_rewards == null or not SaveManager.onboarding_completed():
		return
	if not DailyRewards.popup_due():
		return
	if _board != null and is_instance_valid(_board):
		return
	if _result.visible or _daily.visible or _daily_rewards.visible \
			or (_settings != null and _settings.visible) or (_pause != null and _pause.visible) \
			or (_chest_info != null and _chest_info.visible) or _revive.visible or _refill.visible:
		return
	if _ads != null and _ads.fullscreen_ad_active():
		return
	DailyRewards.mark_popup_seen()
	_open_daily_rewards_window(true)


## Mağaza kartı (gün boyu). Onboarding bitmeden açılmaz.
func open_daily_rewards() -> void:
	if _daily_rewards == null or not SaveManager.onboarding_completed():
		return
	if _daily_rewards.visible:
		return
	_open_daily_rewards_window(false)


func _open_daily_rewards_window(auto: bool) -> void:
	_clear_daily_request()
	_daily_rewards.open_popup(_daily_provider_ready(), _provider_note(), auto)
	_ensure_rewarded()
	AdEvents.emit(&"daily_popup_shown", {"day_key": DailyRewards.day_key(), "auto": auto,
		"remaining": DailyRewards.state()["remaining_total"]})


func _daily_provider_ready() -> bool:
	return _provider_ready("show_rewarded_daily_chest")


## Ücretsiz sandık: kota → kura → kayıt (tek transaction, DailyRewards) →
## reveal. İkinci basış / yarış: null → yalnız tazelenir.
func _on_daily_free_chest_requested() -> void:
	var reward: DailyChestReward = DailyRewards.claim_free_chest()
	if reward == null:
		_daily_rewards.refresh(_daily_provider_ready(), _provider_note())
		return
	_daily_rewards.show_reveal(reward)
	_refresh_shell_dough()


func _on_daily_ad_dough_requested() -> void:
	_request_daily_rewarded("daily_dough")


func _on_daily_ad_chest_requested() -> void:
	_request_daily_rewarded("daily_chest")


func _request_daily_rewarded(kind: String) -> void:
	var day_key: String = DailyRewards.day_key()
	var quota_ok: bool = DailyRewards.ad_dough_available() if kind == "daily_dough" \
		else DailyRewards.ad_chests_remaining() > 0
	if not quota_ok:
		_daily_rewards.show_unavailable(kind, "Bugünkü hakkın doldu, yarın yenilenir.",
			_daily_provider_ready(), _provider_note())
		return
	# Yeni talep = yeni token. Önceki talebin callback'i artık geçersiz.
	_daily_token += 1
	_daily_pending_token = _daily_token
	_daily_pending_kind = kind
	_daily_pending_day = day_key
	AdEvents.emit(&"daily_dough_requested" if kind == "daily_dough" else &"daily_ad_chest_requested",
		{"day_key": day_key})
	if not _daily_provider_ready():
		notify_daily_rewarded_unavailable(kind, _unavailable_note())
		return
	if kind == "daily_dough":
		_rewarded_provider.call("show_rewarded_daily_dough", self, day_key, _daily_pending_token)
	else:
		_rewarded_provider.call("show_rewarded_daily_chest", self, day_key, _daily_pending_token)


## Sağlayıcının "ödül kazanıldı" callback'i (reklamlı sandık). Üç kapı: açık
## talep, token, tür + gün. Token ÖNCE tüketilir. Kota/kayıt DailyRewards'ta.
func grant_daily_chest(day_key: String, token: int) -> bool:
	if _daily_pending_token == 0 or token != _daily_pending_token:
		return false
	if _daily_pending_kind != "daily_chest" or day_key != _daily_pending_day:
		return false
	_clear_daily_request()
	var reward: DailyChestReward = DailyRewards.grant_ad_chest(day_key)
	if reward == null:
		# Kota dolu / gün değişti (yarış): ödül yok, pencere açık kalır.
		_daily_rewards.show_unavailable("daily_chest", "Bugünkü hakkın doldu, yarın yenilenir.",
			_daily_provider_ready(), _provider_note())
		return false
	_daily_rewards.show_reveal(reward)
	_refresh_shell_dough()
	return true


## Sağlayıcının "ödül kazanıldı" callback'i (+150 Hamur).
func grant_daily_dough(day_key: String, token: int) -> bool:
	if _daily_pending_token == 0 or token != _daily_pending_token:
		return false
	if _daily_pending_kind != "daily_dough" or day_key != _daily_pending_day:
		return false
	_clear_daily_request()
	if not DailyRewards.grant_ad_dough(day_key):
		_daily_rewards.show_unavailable("daily_dough", "Bugünkü hakkın doldu, yarın yenilenir.",
			_daily_provider_ready(), _provider_note())
		return false
	AudioManager.play(&"daily_reward")
	Haptics.medium()
	_daily_rewards.show_unavailable("daily_dough", "+%d Hamur eklendi!" % DailyRewards.AD_DOUGH_AMOUNT,
		_daily_provider_ready(), _provider_note())
	_refresh_shell_dough()
	return true


## Reklam yüklenemedi / gösterilemedi / ödül kazanılmadı. Pencere AÇIK KALIR,
## kota tüketilmez.
func notify_daily_rewarded_unavailable(kind: String, message: String) -> void:
	_clear_daily_request()
	if _daily_rewards != null and _daily_rewards.visible:
		_daily_rewards.show_unavailable(kind, message, _daily_provider_ready(), _provider_note())


func _on_daily_rewards_closed() -> void:
	AdEvents.emit(&"daily_popup_closed", {"day_key": DailyRewards.day_key(),
		"pending": _daily_pending_kind != ""})
	_clear_daily_request()
	_cancel_rewarded_request()
	_show_tab(_active_tab)


func _clear_daily_request() -> void:
	_daily_pending_token = 0
	_daily_pending_kind = ""
	_daily_pending_day = ""


## Hamur değişti (günlük ödül): görünen kabuk ekranı bakiyesini tazeler.
func _refresh_shell_dough() -> void:
	if _active_tab < _screens.size() and _screens[_active_tab].has_method("refresh"):
		_screens[_active_tab].refresh()


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

	_set_ad_surface(MonetizationManager.Surface.GAMEPLAY)
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
	# Board giderken açık bir reklam talebi varsa (pencere kapanmadan terk)
	# iptal: geç gelen ödül callback'i hiçbir şey vermez.
	_cancel_rewarded_request()
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

## Sağlayıcı gerçekten bağlı ve ödüllü devam ŞİMDİ gösterebiliyor mu? Pencere
## buna göre DEVAM ET'i açar ya da pasif + sebepli gösterir (M8.6-10):
## sağlayıcı yokken ya da reklam yüklenmemişken çalışacakmış gibi duran bir
## reklam butonu yok. Hazırlık değişince `_on_rewarded_availability_changed`
## açık pencereyi tazeler (M8.9-01).
func _revive_provider_ready() -> bool:
	return _provider_ready("show_rewarded_revive")


func _provider_ready(method: String) -> bool:
	if _rewarded_provider == null or not _rewarded_provider.has_method(method):
		return false
	if _rewarded_provider.has_method("is_rewarded_ready"):
		return _rewarded_provider.is_rewarded_ready()
	return true


## Sağlayıcı hazır değilken pencerede yazan sebep; boş = pencerenin kendi
## "henüz bağlı değil" metni (sağlayıcı yok).
func _provider_note() -> String:
	if _rewarded_provider != null and _rewarded_provider.has_method("rewarded_note"):
		return _rewarded_provider.rewarded_note()
	return ""


## Sağlayıcısız / hazır değilken gelen talebe cevap: sağlayıcının kendi sebebi,
## yoksa pencerenin "henüz bağlı değil" metni.
func _unavailable_note() -> String:
	var note: String = _provider_note()
	return note if note != "" else "Ödüllü reklam henüz bağlı değil."


## Pencere açıldı: sağlayıcı hazırlanmaya başlasın (önyükleme / yeniden dene).
func _ensure_rewarded() -> void:
	if _rewarded_provider != null and _rewarded_provider.has_method("ensure_rewarded"):
		_rewarded_provider.ensure_rewarded()


## Pencere kapandı / round bitti: açık reklam talebi iptal (geç ödül yok).
func _cancel_rewarded_request() -> void:
	if _rewarded_provider != null and _rewarded_provider.has_method("cancel_rewarded_request"):
		_rewarded_provider.cancel_rewarded_request()


## Sağlayıcı "hazır" durumu değişti (reklam yüklendi / yüklenemedi / rıza):
## açık Devam / Refill penceresi CTA'sını ve notunu tazeler. Bekleyen talep
## ve kayıt/kota bu yoldan DEĞİŞMEZ.
func _on_rewarded_availability_changed() -> void:
	if _revive != null and _revive.visible:
		_revive.refresh_provider(_revive_provider_ready(), _provider_note())
	if _refill != null and _refill.visible and not _refill.is_request_pending():
		_refill.refresh(_power_provider_ready(), _provider_note())
	if _daily_rewards != null and _daily_rewards.visible and not _daily_rewards.is_request_pending():
		_daily_rewards.refresh(_daily_provider_ready(), _provider_note())


func _set_ad_surface(surface: int) -> void:
	if _ads != null:
		_ads.set_surface(surface as MonetizationManager.Surface)


## Board devam teklifi açtı: round HENÜZ BİTMEDİ, hiçbir ödül/sonuç akışı
## çalışmadı.
func _on_revive_offered(remaining: int) -> void:
	# Board aynı karede terk edilmiş olabilir (queue_free sonrası son fizik
	# adımı): ölü board için teklif açılmaz (harness'ta görüldü; production
	# yolları board'u yalnız duraklatılmışken siler).
	if _board == null or not is_instance_valid(_board):
		return
	_revive.show_offer(remaining, _board.max_revives(), _revive_provider_ready(), _provider_note())
	_ensure_rewarded()


## Oyuncu ödüllü CTA'ya bastı.
##
## ⚠️ BURADA REKLAM YOK ve DEVAM VERİLMİYOR. Sağlayıcı bağlanana kadar tek
## yaptığı şey oyuncuya durumu söylemek. Sahte reklam oynatmak ya da bedava
## devam vermek bilinçli olarak YAPILMIYOR (GAME_DESIGN.md §11).
func _on_rewarded_revive_requested() -> void:
	if _revive_provider_ready():
		_rewarded_provider.call("show_rewarded_revive", self)
		return
	notify_rewarded_unavailable(_unavailable_note())


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
	_cancel_rewarded_request()
	if _board != null and is_instance_valid(_board):
		_board.decline_revive()


## Reklam yüklenemedi / gösterilemedi / ödül kazanılmadı. Teklif AÇIK KALIR,
## hak tüketilmez, oyunun fail-pending durumu sürer.
func notify_rewarded_unavailable(message: String) -> void:
	_revive.show_unavailable(message)


## Sağlayıcıyı bağlar (production: MonetizationManager, M8.9-01; testler:
## stub). Beklenen arayüz için `_rewarded_provider`
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

## Sağlayıcı gerçekten bağlı ve ödüllü güç ŞİMDİ gösterebiliyor mu?
func _power_provider_ready() -> bool:
	return _provider_ready("show_rewarded_power")


## Board stok 0 bir güç istedi ve oyunu dondurdu.
func _on_power_refill_offered(type: int) -> void:
	_clear_refill_request()
	_refill.show_refill(type as PowerUp.Type, _power_provider_ready(), _provider_note())
	_ensure_rewarded()


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
	notify_power_rewarded_unavailable(_unavailable_note())


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
			% SaveManager.dough(), _power_provider_ready(), _provider_note())
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
	_refill.show_unavailable(message, _power_provider_ready(), _provider_note())


## Oyuncu pencereyi kapattı: hiçbir şey alınmadı, oyun kaldığı yerden
## devam ediyor. Niyet geri dönüşü YOK (oyuncu vazgeçti).
func _on_refill_closed() -> void:
	_clear_refill_request()
	_cancel_rewarded_request()
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
	# Doğal mola (M8.9-02): round KESİN bitti, devam kararları tamamlandı,
	# sonuç henüz açılmadı. Geçiş reklamı uygun + hazırsa ŞİMDİ gösterilir ve
	# sonuç reklam kapanınca (tam bir kez) açılır; değilse sonuç HEMEN —
	# reklam yüklemesi ya da bekleme için sonuç asla bekletilmez.
	_result_seq += 1
	var present: Callable = _present_result.bind(_result_seq, won, score, stars, rewards,
		new_record, newly_unlocked, reached_tier)
	if _ads != null and _ads.try_show_interstitial("round_finish", present):
		return
	present.call()


## Sonuç ekranını açar — round bitişi başına tam bir kez (`seq`; geç gelen
## reklam callback'i ikinci bir sonuç üretemez, sonuç kaybolmaz).
func _present_result(seq: int, won: bool, score: int, stars: int, rewards: Array[ChestReward],
		new_record: bool, newly_unlocked: bool, reached_tier: int) -> void:
	if seq != _result_seq or _current_level == null:
		return
	if _board == null or not is_instance_valid(_board):
		# Round bu arada terk edildi (harness); sonuç açılmaz.
		return
	_result_seq += 1
	_set_ad_surface(MonetizationManager.Surface.RESULT)
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
