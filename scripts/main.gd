extends Node2D
## Akış kontrolü: ekranlar (Ana Sayfa hub / Harita / Koleksiyon / Mağaza / Profil) ->
## oyun -> sonuç -> ekranlar. Oyun kuralları GameBoard'da, ilerleme
## SaveManager'da, ödül kurası ChestSystem'de, fiyatlar Shop'ta; burada
## sadece bunlar birbirine bağlanıyor.
##
## Gezinme (M8.6): Ana Sayfa hub (madalyonlar + OYNA); Harita / Koleksiyon /
## Mağaza kendi `ScreenTopBar`'ıyla (geri -> Ana Sayfa). Eski M8.5-10 alt
## sekme çubuğu M8.6-06 ile tamamen kalktı (UI_VISUAL_SYSTEM §14.4).
## Profil (TASK/044): Ana Sayfa'nın sol üst avatarından; Ayarlar'a Profil'in
## dişli çarkından (aynı tek `SettingsPanel`), oyun içi HUD yolu değişmedi.
## Küresel gezinme kabuğu (TASK/057, `GlobalNav`): beş hub ekranı arasında Ana Sayfa'ya dönmeden
## geçiş; görünürlük ve seçili hedef YALNIZ burada (`_sync_nav`), hub dışı yüzeylerde gizli.

const HOME_SCENE: PackedScene = preload("res://scenes/ui/home_screen.tscn")
const LEVEL_SELECT_SCENE: PackedScene = preload("res://scenes/ui/level_select.tscn")
const COLLECTION_SCENE: PackedScene = preload("res://scenes/ui/collection_screen.tscn")
const SHOP_SCENE: PackedScene = preload("res://scenes/ui/shop_screen.tscn")
const PROFILE_SCENE: PackedScene = preload("res://scenes/ui/profile_screen.tscn")
const GAME_BOARD_SCENE: PackedScene = preload("res://scenes/game/game_board.tscn")
const ROUND_RESULT_SCENE: PackedScene = preload("res://scenes/ui/round_result.tscn")
const DAILY_REWARDS_SCENE: PackedScene = preload("res://scenes/ui/daily_rewards_popup.tscn")
const REVIVE_OFFER_SCENE: PackedScene = preload("res://scenes/ui/revive_offer.tscn")
const POWER_REFILL_SCENE: PackedScene = preload("res://scenes/ui/power_refill.tscn")
const SETTINGS_SCENE: PackedScene = preload("res://scenes/ui/settings_panel.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
const CHEST_INFO_SCENE: PackedScene = preload("res://scenes/ui/bonus_chest_info.tscn")
const MISSIONS_SCENE: PackedScene = preload("res://scenes/ui/missions_overlay.tscn")
const DAILY_CHALLENGE_SCENE: PackedScene = preload("res://scenes/ui/daily_challenge_overlay.tscn")
const TUTORIAL_OVERLAY_SCENE: PackedScene = preload("res://scenes/ui/tutorial_overlay.tscn")
const AGE_GATE_SCENE: PackedScene = preload("res://scenes/ui/age_gate_panel.tscn")

## Round bitip sonuç ekranı açılmadan önceki kısa nefes payı — son merge'in
## efekti ekranda kalsın diye.
const RESULT_DELAY: float = 0.8

var _result: CanvasLayer
## GÜNLÜK ÖDÜLLER penceresi (M8.9-02 / 02.1): oyuncunun TEK günlük ödül
## penceresi — üstte günlük giriş ödülü (+15 / seri, GAME_DESIGN §5.4;
## ödül `DailyReward.claim_if_new_day` ile pencereden ÖNCE yazılır, pencere
## yalnız gösterir), altında ücretsiz sandık + reklamlı Hamur + reklamlı
## sandık. Eski `DailyRewardPopup` (M8.6-08) kaldırıldı.
var _daily_rewards: CanvasLayer
## Son giriş ödülü işleminin görünümü (`DailyReward.view()` + az önce alındı /
## seri kırıldı bilgisi). Pencere bunu yalnız gösterir; "az önce" bilgisi ilk
## açılışta tüketilir (yeniden açılışta kutlama yok, ödül zaten bir kez).
var _login_view: Dictionary = {}
var _revive: CanvasLayer
var _refill: CanvasLayer
var _settings: CanvasLayer
var _pause: CanvasLayer
var _chest_info: CanvasLayer
## GÖREVLER penceresi (TASK/046): Ana Sayfa'nın GÖREVLER girişi açar; GÜNLÜK ÖDÜLLER /
## Bonus Sandık gibi Main'e ait ikincil pencere (reklam yüzeyi değil, kayda yazmaz).
var _missions: MissionsOverlay
## MEYDAN OKUMA penceresi (TASK/047): Ana Sayfa'nın MEYDAN OKUMA girişi açar; GÖREVLER ile aynı aile
## (Main'e ait ikincil pencere, reklam yüzeyi değil, kayda yazmaz — BAŞLA yalnız talep yayar).
var _challenge_sheet: DailyChallengeOverlay
## Android geri tusu debounce (bkz. _notification).
const BACK_DEBOUNCE_MSEC: int = 250
var _last_back_msec: int = -1000
## Geçiş sonrası parmak yatışması (TASK/044 A36 kapısı, bkz. _input): hızlı çift
## dokunuşun ikinci yarısı yeni açılan ekranda / pencerede aynı noktadaki kontrole
## düşmesin. 300 ms = Android'in çift dokunuş penceresi.
const TOUCH_SETTLE_MSEC: int = 300
var _touch_settle_until: int = -1
## Yatışmanın yuttuğu parmak dizileri (TASK/045.2): dizi anahtarı → true. Anahtar gerçek
## dokunuşta parmak indeksi, dokunuştan öykünen farede EMULATED_MOUSE_SEQUENCE. Kayıt yalnız
## dizinin bırakışıyla (iptal dahil) ya da aynı anahtarın yeni basışıyla kapanır; odak kaybı /
## duraklatma / pencere bitişinde TEMİZLENMEZ — kuyruktaki bırakış tahtaya basışsız düşerdi.
const EMULATED_MOUSE_SEQUENCE: int = -1
const NO_FINGER_SEQUENCE: int = -2
var _settled_sequences: Dictionary = {}
var _board: Node2D
## --- İlk açılış tutorial'ı (M8.10 — docs/TUTORIAL_SYSTEM.md) ---
## Yeni kayıtta (onboarding false) açılışta otomatik olarak GERÇEK Level 1
## başlar ve `TutorialController` adımları sürer. Onboarding tamamsa ikisi de
## hiç devreye girmez (eski oyuncu normal kabuğa açılır).
var _tutorial: TutorialController
var _tutorial_overlay: TutorialOverlay
## Tutorial round'un ORTASINDA bitti: monetizasyon açılışı bir sonraki güvenli
## geçişe (kabuk ekranı / yeni round) ertelendi — banner yuvası açılıp board
## yeniden yerleşmesin (§19). GEÇİCİ bir sunum bayrağı: KAYDA YAZILMAZ,
## uygulama kapanırsa onboarding zaten kalıcı, açılışta normal yol işler.
var _monetization_deferred: bool = false
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

## --- Nötr yaş ekranı + yaş bandı yönlendirmesi (TASK/043 — AGE_BAND_ROUTING.md) ---
## Yalnız reklam yöneticisi varken (Android + eklenti) devrededir: yaş, reklam
## yönlendirmesinin girdisidir. Bant soğuk açılışta kayıttan çözülür (geçişler dahil) ve
## yöneticiye SDK'ya dokunmadan ÖNCE verilir; bilinmiyorsa İLK güvenli kabukta sorulur
## (tutorial + tutorial kaynaklı Level 1 reklamsız biter, sonra). Doğum tarihi Main'e
## HİÇ gelmez — panel yalnız türetilmiş bandı yayar.
var _age_band: int = AgeGate.Band.UNKNOWN
var _age_panel: CanvasLayer
## TASK/046.1: yaş ekranı açılırken bırakılan reklam yüzeyi (kapanınca geri gelir); -1 = yok.
var _surface_before_age: int = -1
## Test kancası: true iken `_quit_app` uygulamayı kapatmaz (yalnız sayar). TASK/046.1: tek
## çıkış yolu Ana Sayfa'da (açık pencere yokken) Android geri — yaş ekranı çıkış YAPTIRMAZ.
static var quit_suppressed: bool = false
var quit_requests: int = 0

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
## Round kesinleştirme koruması (TASK/045): `_on_round_finished` round başına TAM bir
## kez işler — yinelenen bir round_finished sinyali / geri çağrısı XP'yi, turu,
## merge'leri ve sandıkları ikinci kez yazamaz. Yeni round (`_begin_round`) sıfırlar. TASK/053: Ayarlar kapısının
## (`_terminal_round_owns_screen`) da girdisi.
var _round_finalized: bool = false
## Round sahipliği (TASK/048): board'un her değişiminde (yeni round, yeniden başlatma, terk, çıkış —
## hepsi `_clear_board`'dan geçer) +1. Kesinleşen normal round nesli gecikmeden ÖNCE yakalar; gecikmeli
## sonuç ve geçiş reklamı yalnız nesil hâlâ aynıysa sunulur — eski round'un sonucu yeni round'un / Ana
## Sayfa'nın / başka bir kipin üstüne açılmaz. Yalnız bellekte (kayda yazılmaz).
var _round_generation: int = 0
## Fırlatma aralığı (TASK/048): geçiş reklamı yerel SDK'ya verilen normal round'un nesli (-1 = yok). Gösterim
## çağrısından sonra reklam GERİ ALINAMAZ (Google SDK'da iptal yok) — o round, yönetici molayı bitirene dek
## (kapanış / gösterim hatası; SDK susarsa TASK/052 tam ekran kirası: öne dönüş payı / örtülmemiş sınır / girdi
## kanıtı — uygulama duraklatılmışken bırakma yok) ekranın sahibi kalır. Sınır: SDK yöneticinin vazgeçmesinden SONRA
## reklamı yine de açarsa (sözleşme dışı) o geç reklam o anki durumu örtebilir.
var _round_break_generation: int = -1
## Mola sürerken basılan round değişimi (mola "Yeniden Başlat" / "Ana Menüye Dön") — molanın sonunda eski
## sonucun YERİNE çalışır. TASK/049'dan beri mola penceresi kesinleşmede kapanır: savunma (bkz. `_defer_round_change`).
var _deferred_round_change: Callable = Callable()
## --- Günlük meydan okuma (TASK/047 — GAME_DESIGN §5.11) ---
## Round türü AÇIK tutulur: board'un hangi akışa ait olduğu meydan okumanın level numarasından
## (nöbetçi 0) ÇIKARILMAZ. NORMAL = sabit level / sonsuz / tutorial (mevcut akış, değişmedi);
## DAILY_CHALLENGE = ayrı başlatma / bitiş / tekrar / çıkış yolu (P1 yalıtım).
enum RoundKind { NORMAL, DAILY_CHALLENGE }
var _round_kind: RoundKind = RoundKind.NORMAL
## Meydan okuma denemesinin BAŞLADIĞI kabul edilen gün — gece yarısını geçen deneme bu güne
## yazılır; tekrar dene ise her zaman o anki günün meydan okumasını başlatır.
var _challenge_day: String = ""
## Deneme kimliği: her meydan okuma başlangıcında +1. Gecikmeli (RESULT_DELAY) meydan okuma sonucu
## yalnız kendi denemesi hâlâ ekrandayken açılır (normal round'un gecikmeli sonucu TASK/048'de ayrıca
## round nesliyle korunur — `_round_generation`).
var _challenge_attempt: int = 0
## _ready tamamlandı: otomatik günlük pencere ancak bundan sonra (açılış
## sırasındaki _show_tab günlük giriş ödülünün önüne geçmesin).
var _booted: bool = false
var _current_level: LevelData
## Ekran indeksi -> ekran: 0 Ana Sayfa, 1 Harita, 2 Koleksiyon, 3 Mağaza,
## 4 Profil (TASK/044).
var _screens: Array[CanvasLayer] = []
var _active_tab: int = 0
## Küresel gezinme kabuğu (TASK/057). Testler `global_nav()` ile okur.
var _nav: GlobalNav
## Test sayacı: kabuktan gelen ve GERÇEKTEN ekran değiştiren gezinmeler (aynı hedef / bayat dokunuş sayılmaz).
var nav_navigations: int = 0
## `_show_tab` ekran döngüsü sürerken ara görünürlük değişimleri kabuğu senkronlamaz.
var _nav_sync_suspended: bool = false
## Ekran indeksi -> reklam yüzeyi (banner yalnız yöneticinin izin verdiği
## yüzeylerde; Harita v1'de banner dışı — ADS_SYSTEM §6). Profil reklam yüzeyi
## DEĞİL (Surface.NONE — TASK/044 yeni reklam yüzeyi açmaz).
const TAB_SURFACES: Array[int] = [MonetizationManager.Surface.HOME, MonetizationManager.Surface.MAP,
	MonetizationManager.Surface.COLLECTION, MonetizationManager.Surface.SHOP,
	MonetizationManager.Surface.NONE]


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
		# TASK/043: yaş bandı reklam SDK'sına dokunulmadan ÖNCE çözülür — kayıt doğrulanır,
		# soğuk açılış geçişi (18. yaş günü -> ADULT) burada kalıcılaşır; bozuk kayıt -> UNKNOWN
		# (reklam yok, yaş yeniden sorulur). TASK/046.1: eski UNDER_13 -> UNKNOWN (tarih silinir).
		_age_band = SaveManager.resolve_age_band_at_launch(AgeGate.today())
		# Onboarding (tutorial, M8.10) bitmeden yuva 0 ve reklam yok; kayıt
		# karar verir (eski kayıt ilerleme kanıtıyla tamamlanmış sayılır).
		_ads.set_onboarding_completed(SaveManager.onboarding_completed())
		# Yaş kapısı: UNKNOWN / UNDER_13 -> eklenti, UMP ve SDK hiç açılmaz.
		_ads.set_age_band(_age_band)
		add_child(_ads)
		_ads.rewarded_availability_changed.connect(_on_rewarded_availability_changed)
		_ads.banner_slot_changed.connect(_on_banner_slot_changed)
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
	# TASK/044: sol üst avatar -> Profil (Ayarlar artık Profil'in dişli çarkında).
	home.profile_requested.connect(_on_profile_requested)
	# Home hub (M8.6-03B): yuzen ozellik madalyonlari ve level plakasi.
	home.map_requested.connect(_on_play_pressed)
	home.shop_requested.connect(_on_shop_requested)
	home.collection_requested.connect(_on_collection_requested)
	home.daily_requested.connect(_on_daily_requested)
	home.chest_requested.connect(_on_chest_requested)
	# TASK/046: GÖREVLER girişi → Main'in GÖREVLER penceresi.
	home.missions_requested.connect(open_missions)
	# TASK/047: MEYDAN OKUMA girişi → Main'in MEYDAN OKUMA penceresi.
	home.challenge_requested.connect(open_daily_challenge)
	var select: CanvasLayer = LEVEL_SELECT_SCENE.instantiate()
	select.level_chosen.connect(_start_level)
	# Harita (M8.6-04): kendi ust satiri — Hamur "+" -> Magaza. TASK/057 Tur 2: hub ekranlarinda geri oku yok;
	# Ana Sayfa'ya donus kuresel gezinme kabugunda + Android geri.
	select.shop_requested.connect(_on_shop_requested)
	var album: CanvasLayer = COLLECTION_SCENE.instantiate()
	# Koleksiyon (M8.6-06): kendi ust satiri — Hamur "+" ve kilitli skin'in MAGAZAYA GIT'i -> Magaza.
	album.shop_requested.connect(_on_shop_requested)
	album.shop_skin_requested.connect(_on_shop_skin_requested)
	# Parça detayı açıldı (TASK/044): çift dokunuşun ikincisi karartmaya düşüp kapatmasın.
	album.detail_opened.connect(settle_touch_input)
	var shop: CanvasLayer = SHOP_SCENE.instantiate()
	# Magaza (M8.6-05): kendi ust satiri (yalniz bakiye).
	# Magaza GUNLUK ODULLER karti (M8.9-02): ayni pencere, gun boyu acilabilir.
	shop.daily_rewards_requested.connect(open_daily_rewards)
	var profile: CanvasLayer = PROFILE_SCENE.instantiate()
	# Profil (TASK/044): dişli çark -> Ayarlar (tek panel), vitrin yuvası / KOLEKSİYONA GİT -> Koleksiyon (dolu
	# yuva: o parçanın detayı).
	profile.settings_requested.connect(open_settings)
	profile.collection_requested.connect(_on_collection_requested)
	profile.collectible_requested.connect(_on_collectible_requested)
	# TASK/045: başarımlar / unvan penceresi açılış-kapanışında aynı parmak yatışması.
	profile.overlay_toggled.connect(settle_touch_input)
	_screens = [home, select, album, shop, profile]
	for screen in _screens:
		add_child(screen)
	_build_global_nav()

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

	# TASK/046: açılış ve kapanış aynı 300 ms parmak yatışmasını başlatır (Profil pencereleri
	# gibi): girişe çift dokunuşun ikincisi pencereye, X'e çift dokunuşun ikincisi Ana
	# Sayfa'ya düşmez.
	_missions = MISSIONS_SCENE.instantiate()
	_missions.opened.connect(settle_touch_input)
	_missions.closed.connect(settle_touch_input)
	add_child(_missions)

	# TASK/047: MEYDAN OKUMA penceresi — GÖREVLER ile aynı 300 ms açılış / kapanış yatışması.
	_challenge_sheet = DAILY_CHALLENGE_SCENE.instantiate()
	_challenge_sheet.opened.connect(settle_touch_input)
	_challenge_sheet.closed.connect(settle_touch_input)
	_challenge_sheet.start_requested.connect(_on_challenge_start_requested)
	add_child(_challenge_sheet)

	_tutorial_overlay = TUTORIAL_OVERLAY_SCENE.instantiate()
	_tutorial_overlay.visibility_changed.connect(_sync_nav)
	add_child(_tutorial_overlay)
	_tutorial = TutorialController.new()
	_tutorial.name = "TutorialController"
	_tutorial.setup(_tutorial_overlay)
	_tutorial.completed.connect(_on_tutorial_completed)
	add_child(_tutorial)

	# TASK/043 → TASK/046.1: yaş ekranı (katman 14; yalnız 13+ doğum tarihi seçilebilir). 13 yaş
	# altı kısıt / çıkış ekranı EMEKLİ. Panelin açılış / kapanış / adım değişimleri TASK/045.2
	# dizi bazlı 300 ms parmak yatışmasını başlatır (seçimde çift dokunuş sızmaz). Panel açıkken
	# banner YOK (yeniden girişte de).
	_age_panel = AGE_GATE_SCENE.instantiate()
	_age_panel.resolved.connect(_on_age_resolved)
	_age_panel.closed.connect(_on_age_panel_closed)
	_age_panel.opened.connect(settle_touch_input)
	_age_panel.settle_requested.connect(settle_touch_input)
	_age_panel.visibility_changed.connect(_on_age_panel_visibility_changed)
	_age_panel.visibility_changed.connect(_sync_nav)
	add_child(_age_panel)
	# TASK/057: Main'in engelleyici pencereleri açılınca / kapanınca gezinme kabuğu yeniden değerlendirilir.
	for layer in [_result, _daily_rewards, _revive, _refill, _settings, _pause, _chest_info, _missions,
			_challenge_sheet]:
		(layer as CanvasLayer).visibility_changed.connect(_sync_nav)
	_settings.age_info_requested.connect(_open_age_reentry)
	_refresh_age_settings_row()

	# İlk açılış (M8.10): yeni oyuncu Ana Sayfa'yı, günlük pencereyi, banner'ı
	# ve UMP formunu GÖRMEDEN doğrudan Level 1 tutorial'ına girer (§4).
	var fresh: bool = not Onboarding.is_completed()
	if fresh:
		_hide_shell()
	else:
		_show_tab(0)
	# Günlük ödüller (M8.9-02 / 02.1): görülen en yeni gün kayda işlenir (saat
	# geri alma koruması), günlük giriş ödülü BİR KEZ çözülür (onboarding
	# bitmişse), sonra TEK pencere (GÜNLÜK ÖDÜLLER) günde bir kez.
	DailyRewards.observe_day()
	_resolve_daily_login()
	_booted = true
	# TASK/046.1: eski kayıttaki UNDER_13 kısıt ekranı AÇMAZ — `SaveManager` onu UNKNOWN'a indirir
	# (reklam yok), aşağıdaki yol zorunlu yaş ekranını yeniden sorar.
	if fresh:
		_begin_first_run_tutorial()
	elif not _maybe_request_age():
		# Yaş biliniyor (ya da reklam yok): günlük pencere her zamanki gibi. Bilinmiyorsa
		# pencere yaş ekranı çözülene kadar bekler (reklamlı sandık / Hamur girişleri var).
		_maybe_auto_open_daily_rewards()


# --- İlk açılış tutorial'ı (M8.10) ---
#
# SÖZLEŞME: tutorial GERÇEK Level 1 board'unda çalışır (sahte fizik yok);
# yalnız ilk iki drop tutorial kuyruğundan gelir. Tamamlanma/atlama TEK
# kanonik yoldan (`Onboarding.complete`) geçer ve aynı gün günlük ödülleri
# kapalı tutar (ilk gün kuralı, §5).

func _begin_first_run_tutorial() -> void:
	var level: LevelData = _first_level()
	if level == null:
		# Level 1 resource'u yoksa oyuncuyu kilitli bırakma: onboarding'i
		# kapat ve normal kabuğa aç (savunma; production'da olmaz).
		push_error("Tutorial: Level 1 bulunamadı, onboarding atlanıyor.")
		_on_tutorial_completed(Onboarding.SOURCE_SKIP)
		_show_tab(0)
		return
	_start_level(level, TutorialController.DROP_QUEUE)
	_tutorial.begin(_board)


func _first_level() -> LevelData:
	for level in LevelLibrary.load_levels():
		if level.level_number == 1:
			return level
	return null


## Tutorial bitti ya da atlandı — İKİSİ DE buradan geçer (ayrı "sahte
## tamamlandı" bayrağı YOK, §11). `Onboarding.complete` idempotent: çift
## çağrı tek kayıt mutasyonu yapar.
func _on_tutorial_completed(source: String) -> void:
	Onboarding.complete(source, _tutorial.completion_context() if _tutorial != null else {})
	# §19: bu round tutorial'dan doğdu — kalanı reklamsız oynansın. Banner
	# yuvası ancak bir sonraki güvenli geçişte açılır.
	_monetization_deferred = true
	_activate_monetization_if_safe()


## Ertelenmiş monetizasyon açılışı: board yokken (kabuk ekranı) ya da yeni
## bir round kurulurken. Round ORTASINDA asla — banner yuvası açılıp kap
## yeniden yerleşmesin. Tekrar çağrılması zararsız.
func _activate_monetization_if_safe() -> void:
	if not _monetization_deferred:
		return
	if _board != null and is_instance_valid(_board):
		return
	_monetization_deferred = false
	if _ads != null:
		_ads.set_onboarding_completed(SaveManager.onboarding_completed())


## Banner yuvası, görünür kabuk ekranı yerleştikten SONRA değişti (tutorial sonrası ilk
## güvenli geçiş; TASK/043: yaş ilk güvenli kabukta girilince kapı açılır): ekran yeni
## alt payla hemen yeniden yerleşir — banner içeriğin altına binmez. Board varken
## yuva değişmez (§19); yeni round zaten güncel payla kurulur.
func _on_banner_slot_changed(_px: float) -> void:
	# TASK/057: gezinme kabuğu yuvanın ÜSTÜNDE (banner aralığıyla) durur — yuva kesinleşince (oturumda bir kez)
	# yeniden yerleşir ve hub ekranlarının payı yenilenir.
	if _nav != null:
		_nav.relayout()
		_apply_nav_insets()
	if _board != null and is_instance_valid(_board):
		return
	if _active_tab < 0 or _active_tab >= _screens.size():
		return
	var screen: CanvasLayer = _screens[_active_tab]
	if screen.visible and screen.has_method("_layout"):
		screen.call("_layout")


## Tutorial şu an ekranda mı (mola/ayarlar bastırması ve geri tuşu için).
func is_tutorial_active() -> bool:
	return _tutorial != null and _tutorial.is_active()


# --- Nötr yaş ekranı + yaş bandı yönlendirmesi (TASK/043) ---
#
# SÖZLEŞME (docs/monetization/AGE_BAND_ROUTING.md): yaş yalnız reklam yöneticisi varken
# sorulur; İLK güvenli kabukta (tutorial ve tutorial kaynaklı Level 1 reklamsız bittikten
# sonra; eski kayıtta açılıştaki Ana Sayfa), round ortasında ASLA. Yaş çözülene kadar
# reklam SDK'sı, UMP ve reklamlı yüzeyler (günlük pencere) kapalı. Doğum tarihi buraya
# GELMEZ: panel yalnız türetilmiş bandı + geçiş gününü yayar; burada log / analitik YOK.

## Yaş ekranı (bant bilinmiyorsa — eski UNDER_13 kaydı da buraya iner) şu an gerekli mi —
## gerekiyorsa açar. true = yaş ekranı ekranda (çağıran günlük pencereyi açmaz).
func _maybe_request_age() -> bool:
	if _ads == null or not _booted:
		return false
	if _age_band != AgeGate.Band.UNKNOWN and _age_band != AgeGate.Band.UNDER_13:
		return false
	if not SaveManager.onboarding_completed() or _monetization_deferred:
		return false
	if _board != null and is_instance_valid(_board):
		return false
	if not _age_panel.visible and not AgeGate.clock_plausible(AgeGate.today()):
		# Cihaz saati modelden önceyi gösteriyor (bozuk): yaş bu saatle sınıflandırılamaz.
		# Bant UNKNOWN kalır (reklam / UMP / SDK yok), oyun açık; saat düzelince sorulur.
		return false
	if not _age_panel.visible:
		# Yaş sorusu kabuğun tek odağı: açık ikincil pencereler kapanır.
		_close_secondary_windows()
		if not _age_panel.visible:
			_age_panel.open_required()
	return true


## Reklam başlatabilecek yüzeyler (günlük pencere: reklamlı sandık / +150 Hamur) yaş
## çözülmeden açılmaz: bant bilinmiyor (eski UNDER_13 dahil) / yaş ekranı açık.
func _age_blocks_monetizable_surfaces() -> bool:
	if _ads == null:
		return false
	return _age_band == AgeGate.Band.UNKNOWN or _age_band == AgeGate.Band.UNDER_13 \
		or (_age_panel != null and _age_panel.visible)


## Panel sonucu (zorunlu ilk giriş ya da Ayarlar'dan yeniden giriş): TEK kayıt yazması
## (yalnız türetilmiş durum), sonra yönetici. Yönetici SDK'yı bu süreçte eski bantla
## yapılandırdıysa işlemi DEĞİŞTİRMEZ — reklam oturum boyunca kapanır, yeni bant bir
## sonraki soğuk açılışta; oyuncu kısa bir not görür.
func _on_age_resolved(band: int, transition: String) -> void:
	# TASK/046.1: panel yalnız TEEN / ADULT yayar (13+ seçim). Başka bir bant gelirse hiçbir şey
	# yazılmaz, reklam açılmaz — fail-closed (yaş sorusu açık kalır).
	if band != AgeGate.Band.TEEN and band != AgeGate.Band.ADULT:
		return
	var reentry: bool = _age_panel.is_reentry()
	SaveManager.store_age_band(band, transition)
	_age_band = band
	var change: int = MonetizationManager.AgeBandChange.APPLIED
	if _ads != null:
		change = _ads.set_age_band(band)
	_refresh_age_settings_row()
	if reentry:
		_age_panel.show_done(change == MonetizationManager.AgeBandChange.NEXT_LAUNCH)
		return
	_age_panel.close_panel()
	# İlk çözüm, kabukta: rıza + reklam şimdi başlayabilir; günlük pencere bugün
	# gösterilmediyse şimdi (ilk gün kuralı Onboarding'de, değişmedi).
	_maybe_auto_open_daily_rewards()


## Yeniden giriş penceresi kapandı (vazgeç / tamam): Ayarlar açık kalır.
func _on_age_panel_closed() -> void:
	_refresh_age_settings_row()


## TASK/046.1: yaş sorusu ekrandayken banner gösterilmez — yüzey NONE; panel kapanınca
## bırakılan yüzey (sekme / oyun ekranı — Ayarlar oyun içinden de açılır) geri gelir. Yuva
## SABİT kalır (düzen zıplamaz).
func _on_age_panel_visibility_changed() -> void:
	if _ads == null:
		return
	if _age_panel.visible:
		if _surface_before_age < 0:
			_surface_before_age = _ads.surface()
		_ads.set_surface(MonetizationManager.Surface.NONE)
	elif _surface_before_age >= 0:
		var surface: int = _surface_before_age
		_surface_before_age = -1
		_set_ad_surface(surface)


## Ayarlar → "Yaş bilgisi". Yalnız bant biliniyorken (TEEN / ADULT).
func _open_age_reentry() -> void:
	if _ads == null or (_age_band != AgeGate.Band.TEEN and _age_band != AgeGate.Band.ADULT):
		return
	_age_panel.open_reentry()


func _refresh_age_settings_row() -> void:
	if _settings != null:
		_settings.set_age_info_visible(_ads != null
			and (_age_band == AgeGate.Band.TEEN or _age_band == AgeGate.Band.ADULT))


func _close_secondary_windows() -> void:
	if _settings != null and _settings.visible:
		close_settings()
	if _chest_info != null and _chest_info.visible:
		_chest_info.close_info()
	if _daily_rewards != null and _daily_rewards.visible:
		_daily_rewards.close_popup()
	if _missions != null and _missions.visible:
		_missions.close_missions(false)
	if _challenge_sheet != null and _challenge_sheet.visible:
		_challenge_sheet.close_sheet(false)


## Uygulamadan çıkış — TEK yol: Ana Sayfa'da, kapatılacak pencere yokken Android geri.
## (TASK/046.1: 13 altı kısıt ekranı ve zorunlu yaş sorusundaki "geri = çık" emekli.) Testler
## bastırır ve sayar.
func _quit_app() -> void:
	quit_requests += 1
	if not quit_suppressed:
		get_tree().quit()


## Testler / QA sürücüsü.
func age_band() -> int:
	return _age_band


func age_panel() -> CanvasLayer:
	return _age_panel


# --- Ekranlar ---

## Tek bir ekran görünür kalır. Her geçişte refresh() çağrılıyor: Hamur ve
## koleksiyon sayacı dört ekranda da gösteriliyor, biri diğerini eskitmesin.
## (Ad tarihsel: "sekme" = ekran indeksi; alt sekme çubuğu artık yok.)
## `auto_daily` false: geçiş hemen bir pencere açacak (Profil vitrini → parça detayı);
## otomatik günlük pencere bu geçişte denenmez, "due" kalır (TASK/045.1).
func _show_tab(tab: int, auto_daily: bool = true) -> void:
	if tab < 0 or tab >= _screens.size():
		return
	var changed: bool = tab != _active_tab or not _screens[tab].visible
	# TASK/046: GÖREVLER penceresi Ana Sayfa'nındır — başka ekrana geçişte sessizce kapanır.
	if tab != 0 and _missions != null and _missions.visible:
		_missions.close_missions(false)
	# TASK/047: MEYDAN OKUMA penceresi de Ana Sayfa'nın.
	if tab != 0 and _challenge_sheet != null and _challenge_sheet.visible:
		_challenge_sheet.close_sheet(false)
	_active_tab = tab
	_set_ad_surface(TAB_SURFACES[tab])
	# TASK/057: ekranlar sırayla gizlenip gösterilirken kabuk ara durumda yanıp sönmesin — tek senkron sonda.
	_nav_sync_suspended = true
	for i in _screens.size():
		var screen: CanvasLayer = _screens[i]
		screen.visible = i == tab
		if i == tab and screen.has_method("refresh"):
			screen.refresh()
	# Kısa giriş geçişi (0.16 sn, solma + hafif kayma). Aynı sekme yeniden
	# istenirse (günlük ödül kapanışı gibi) oynatılmıyor.
	if changed:
		UiMotion.screen_in(_screens[tab])
		# TASK/044 A36: Ana Sayfa avatarı ile Profil geri AYNI dikdörtgende; çift
		# dokunuş ekranlar arasında sıçramasın (KOLEKSİYONA GİT → albüm kartı da).
		settle_touch_input()
	# TASK/057: kabuk seçili hedefi ve görünürlüğü (avatar vitrin değişmiş olabilir).
	_nav_sync_suspended = false
	if _nav != null:
		_nav.refresh()
	_sync_nav()
	# Güvenli kabuk geçişi: tutorial round'u sırasında ertelenmiş
	# monetizasyon açılışı (rıza + yükleme + banner yuvası) burada başlar.
	_activate_monetization_if_safe()
	# TASK/043: yaş bilinmiyorsa İLK güvenli kabukta nötr yaş ekranı — günlük pencereden
	# (reklamlı girişler) ve rızadan ÖNCE.
	if _maybe_request_age():
		return
	# Oyundan / sonuçtan kabuğa dönüldü: günlük pencere bugün hiç
	# gösterilmediyse (açılış oyun içindeyken ertelenmişse) şimdi.
	if auto_daily:
		_maybe_auto_open_daily_rewards()


# --- Ayarlar (M8.5-10) ---

## Ayarlar'ı açar; açıldıysa true. TASK/053: terminal sahiplikte reddedilir → false (çağıran donduracak bir şey yapmaz).
func open_settings() -> bool:
	# TASK/053: kabul edilen round bitişi ön planın sahibi — sonuç beklenirken (RESULT_DELAY / geçiş reklamı molası;
	# HUD dişlisi bu aralıkta hâlâ dokunulabilir) ve sonuç açıkken Ayarlar açılmaz (katman 13, sonucun 10'unun üstüne
	# çıkardı). Tek açma noktası: HUD dişlisi, Profil dişlisi, QA yolları buradan geçer.
	if _terminal_round_owns_screen():
		return false
	_settings.open_panel()
	# TASK/044 A36: Profil dişlisine çift dokunuşun ikincisi Ayarlar'ın karartmasına
	# düşüp pencereyi hemen kapatmasın.
	settle_touch_input()
	return true


## TASK/053: kesinleşen round'un board'u hâlâ ekranda — sonuç bekleniyor ya da açık. Yeni round (`_begin_round`) bayrağı
## indirir; çıkış / terk board'u kaldırır (Profil / kabuk yolu etkilenmez).
func _terminal_round_owns_screen() -> bool:
	return _round_finalized and _board != null and is_instance_valid(_board)


## Ekran / pencere geçişinden sonraki TOUCH_SETTLE_MSEC boyunca BAŞLAYAN parmak dizileri
## yutulur (bkz. _input).
func settle_touch_input() -> void:
	_touch_settle_until = Time.get_ticks_msec() + TOUCH_SETTLE_MSEC


## Geçiş sonrası parmak yatışması (TASK/044 A36 kapısı). GUI'den ÖNCE çalışır. Yalnız
## PARMAK olayları: gerçek ScreenTouch / ScreenDrag (device ≠ -1) ve dokunuştan öykünülen
## fare (device -1, Android `emulate_mouse_from_touch`). Kod yolu / `pressed.emit()`,
## masaüstü fare tıklaması ve ondan öykünülen dokunuş ETKİLENMEZ.
##
## TASK/045.2 — dizi bazında: basışı yatışma penceresinde gelen dizinin TAMAMI (basış +
## sürükleme + bırakış, pencere bitse de) yutulur; pencereden ÖNCE başlamış dizi hiç
## bölünmez. Kök neden (A36): dişlinin öykünen fare bırakışı Ayarlar'ı açıp yatışmayı
## başlatıyor, aynı dokunuşun hemen ardından gelen ScreenTouch bırakışı yutuluyordu —
## Viewport'un parmak odağı (`touch_focus`) dişlide kalıyor, dokunuşsuz Android geri
## kapanışından sonra ilk tahta dokunuşunun sürüklemesi ve bırakışı dişliye gidiyordu
## (parça düşmüyordu). KAPAT / karartma dokunuşu odağı yeni basışla eziyordu. Süre aynen.
func _input(event: InputEvent) -> void:
	var key: int = _finger_sequence_key(event)
	if key == NO_FINGER_SEQUENCE:
		return
	var motion: bool = event is InputEventScreenDrag or event is InputEventMouseMotion
	if not motion and event.is_pressed():
		# Yeni dizi. Aynı anahtarın eski dizisi kapanır (bırakışı hiç gelmediyse bastırma
		# takılı kalmaz); yalnız pencerede başlayan dizi yutulur.
		_settled_sequences.erase(key)
		if Time.get_ticks_msec() < _touch_settle_until:
			_settled_sequences[key] = true
			get_viewport().set_input_as_handled()
		return
	if _settled_sequences.has(key):
		# Yutulan dizinin sürüklemesi / bırakışı; bırakış (iptal dahil) diziyi kapatır.
		if not motion:
			_settled_sequences.erase(key)
		get_viewport().set_input_as_handled()


## Parmak dizisinin anahtarı; parmak olayı değilse NO_FINGER_SEQUENCE.
func _finger_sequence_key(event: InputEvent) -> int:
	if event.device != InputEvent.DEVICE_ID_EMULATION:
		var touch := event as InputEventScreenTouch
		if touch != null:
			return touch.index
		var drag := event as InputEventScreenDrag
		if drag != null:
			return drag.index
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		return EMULATED_MOUSE_SEQUENCE
	return NO_FINGER_SEQUENCE


func close_settings() -> void:
	_settings.close_panel()


## Oyun içi HUD'daki ayarlar butonu (M8.6-02): pencere açılırken board
## donar (fail/refill dondurmasıyla aynı makine), kapanınca çözülür.
## TASK/053: board YALNIZ pencere gerçekten açıldıysa donar — reddedilen açılışın kapanışı gelmez, board'a dokunulmaz.
func _on_board_settings_requested() -> void:
	if is_tutorial_active():
		# Tutorial sırasında ikincil pencere açılmaz: tutorial dondurması
		# ile menü dondurması birbirini bozmasın (§10).
		return
	if open_settings() and _board != null and is_instance_valid(_board):
		_board.set_menu_paused(true)


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
	if is_tutorial_active():
		# Tutorial'ın kendi güvenli çıkışı var (DEVAM ET / ATLA): mola
		# penceresi açılmaz, "Ana Menüye Dön" ile onboarding yarım kalamaz.
		_tutorial.handle_back()
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
	# TASK/048: bu round'un geçiş reklamı açılırken / açıkken round değişmez — reklam bitince baştan.
	if _defer_round_change(_on_pause_restart):
		return
	# TASK/047: meydan okuma kendi başlatma yolundan (o anki günün meydan okuması, baştan).
	if _round_kind == RoundKind.DAILY_CHALLENGE:
		_retry_daily_challenge()
		return
	if _current_level != null:
		_start_level(_current_level)


## Round'u terk et: board silinir, harita sekmesine dönülür.
func abandon_run() -> void:
	_pause.close_menu()
	# TASK/048: bu round'un geçiş reklamı açılırken / açıkken round terk edilmez — reklam bitince.
	if _defer_round_change(abandon_run):
		return
	# TASK/047: meydan okumadan çıkış Ana Sayfa'ya (giriş yeri); terk edilen deneme yazmaz.
	if _round_kind == RoundKind.DAILY_CHALLENGE:
		_leave_daily_challenge()
		return
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
		# TASK/046: görev dönemi de değişmiş olabilir — görünen GÖREVLER rozeti / penceresi
		# yalnız okuyarak tazelenir (kayıt yazılmaz).
		_refresh_missions_views()
		# TASK/047: meydan okuma günü de — giriş / açık pencere yalnız okuyarak tazelenir.
		_refresh_daily_challenge_views()
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
	# TASK/046.1: yaş ekranında geri UYGULAMADAN ÇIKMAZ — panel tüketir: seçim ızgarası / onay
	# açıksa bir adım geri, yeniden girişte (Ayarlar) vazgeç / tamam, zorunlu kipte yok sayılır.
	if _age_panel != null and _age_panel.visible:
		_age_panel.handle_back()
		return
	# Tutorial açıkken geri: küçük onay (DEVAM ET / ATLA). Onboarding false
	# iken monetize edilmiş Ana Sayfa'ya ASLA düşülmez (§12).
	if is_tutorial_active():
		_tutorial.handle_back()
		return
	if _settings != null and _settings.visible:
		close_settings()
		return
	if _chest_info != null and _chest_info.visible:
		_chest_info.close_info()
		return
	if _daily_rewards != null and _daily_rewards.visible:
		_daily_rewards.close_popup()
		return
	# TASK/046: GÖREVLER penceresi — geri kapatır, Ana Sayfa'da kalınır.
	if _missions != null and _missions.handle_back():
		return
	# TASK/047: MEYDAN OKUMA penceresi — aynı.
	if _challenge_sheet != null and _challenge_sheet.handle_back():
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
	_quit_app()


## Oyun sırasında ve sonuç ekranında hiçbir kabuk ekranı görünmemeli (Ana Sayfa'nın GÖREVLER
## penceresi de kapanır — TASK/046).
func _hide_shell() -> void:
	for screen in _screens:
		screen.visible = false
	if _missions != null and _missions.visible:
		_missions.close_missions(false)
	if _challenge_sheet != null and _challenge_sheet.visible:
		_challenge_sheet.close_sheet(false)
	_sync_nav()


# --- Küresel gezinme kabuğu (TASK/057) ---
#
# SÖZLEŞME: kabuk YALNIZ bir hub ekranı (Ana Sayfa / Harita / Mağaza / Koleksiyon / Profil) ön plandayken
# ve engelleyici hiçbir yüzey yokken görünür. Gizli: oyun (board — tutorial dahil), sonuç, devam / refill,
# mola, Ayarlar, günlük ödüller, sandık bilgisi, GÖREVLER, MEYDAN OKUMA, yaş ekranı, tutorial katmanı ve
# ekranın kendi penceresi (Mağaza onayı, Koleksiyon detayı, Profil başarımlar / unvan). Gizlenen kabukta
# basılı öğenin basışı eylemsiz biter — öğelerin dokunuş sahipliği GlobalNav'da (TASK/055); Main yalnız
# hedef isteğini alır. Android GERİ zinciri DEĞİŞMEDİ.

func _build_global_nav() -> void:
	_nav = GlobalNav.new()
	_nav.destination_requested.connect(_on_nav_destination)
	# Kompakt kip (kısa ekran + banner) payı değiştirir: hub ekranları yeni payı alır.
	_nav.layout_changed.connect(_apply_nav_insets)
	add_child(_nav)
	# Profil öğesi avatarı vitrin değişince (Koleksiyon detayı) hemen tazelenir. Metot bağlantısı: Main serbest
	# kalınca motor bağlantıyı koparır (autoload'da bayat lambda kalmaz).
	SaveManager.showcase_changed.connect(_on_showcase_changed_for_nav)
	for screen in _screens:
		screen.visibility_changed.connect(_sync_nav)
		if screen.has_signal(&"overlay_changed"):
			screen.connect(&"overlay_changed", _sync_nav)
	_apply_nav_insets()
	_nav.visible = false


func _on_showcase_changed_for_nav(_ids: Array) -> void:
	if _nav != null:
		_nav.refresh()


## Hub ekranlarına kabuğun payı (banner yuvası değişince yeniden). Harita: zemin tepsinin üst kenarına kadar,
## düğümler payın tamamının üstünde.
func _apply_nav_insets() -> void:
	for screen in _screens:
		if not screen.has_method("set_nav_inset"):
			continue
		if screen == _screens[1]:
			screen.set_nav_inset(_nav.reserve(), _nav.center_rise())
		else:
			screen.set_nav_inset(_nav.reserve())


## Kabuğun görünürlüğü + seçili hedef (tek karar noktası). Sinyallerle çağrılır (yoklama yok).
func _sync_nav() -> void:
	if _nav == null or _nav_sync_suspended:
		return
	var hub: bool = _active_tab >= 0 and _active_tab < _screens.size() and _screens[_active_tab].visible
	_nav.set_current(_active_tab)
	_nav.visible = hub and not _nav_blocked()


## Kabuğun görünmemesi gereken bir yüzey açık mı (bkz. sözleşme).
func _nav_blocked() -> bool:
	if _board != null and is_instance_valid(_board):
		return true
	for layer in [_result, _revive, _refill, _settings, _pause, _chest_info, _daily_rewards, _missions,
			_challenge_sheet, _age_panel, _tutorial_overlay]:
		if layer != null and (layer as CanvasLayer).visible:
			return true
	if _active_tab >= 0 and _active_tab < _screens.size():
		var screen: CanvasLayer = _screens[_active_tab]
		if screen.has_method("has_open_overlay") and screen.has_open_overlay():
			return true
	return false


## Kabuk öğesi (GlobalNav'ın TASK/055 sahipliğinden geçmiş geçerli dokunuş): hedef ekran. Görünmeyen kabuktan gelen istek
## (kodla / bayat) ve zaten açık hedef yok sayılır — yinelenen rota, ikinci giriş animasyonu yok.
func _on_nav_destination(tab: int) -> void:
	if _nav == null or not _nav.visible or _nav_blocked():
		return
	if tab < 0 or tab >= _screens.size():
		return
	if tab == _active_tab and _screens[tab].visible:
		return
	nav_navigations += 1
	_show_tab(tab)


## Testler / çekim aracı.
func global_nav() -> GlobalNav:
	return _nav


func _on_play_pressed() -> void:
	_show_tab(1)


## Koleksiyon vitrinindeki kilitli skin'in "MAĞAZAYA GİT" kısayolu, Ana
## Sayfa / Harita / Koleksiyon Hamur pill'inin "+" butonu ve Mağaza madalyonu.
func _on_shop_requested() -> void:
	_show_tab(3)


## Koleksiyon'da kilitli skin'in MAĞAZAYA GİT'i: Mağaza açılır ve o skin'in
## kartına kaydırılır (satın alma yine yalnız Mağaza'da). TASK/045.1: buton parça
## detayının içinde — detay açıkken ertelenen otomatik günlük pencere bu hedefli
## geçişte açılmaz (kapanış tazelemesi Mağaza'yı başa kaydırıp hedef kartı
## kaybettiriyordu); "due" kalır, sonraki geçişte açılır.
func _on_shop_skin_requested(skin_id: StringName) -> void:
	_show_tab(3, false)
	_screens[3].focus_skin(skin_id)


## Ana Sayfa'daki Koleksiyon madalyonu; Profil'in boş vitrin yuvası ve
## KOLEKSİYONA GİT'i.
func _on_collection_requested() -> void:
	_show_tab(2)


## Ana Sayfa'nın sol üst avatarı (TASK/044): Profil.
func _on_profile_requested() -> void:
	_show_tab(4)


## Profil'in dolu vitrin yuvası (TASK/044): Koleksiyon açılır ve o parçanın
## detayı gösterilir (vitrin eylemleri yalnız orada; Profil kayda yazmaz).
func _on_collectible_requested(skin_id: StringName) -> void:
	_show_tab(2, false)
	_screens[2].open_detail(skin_id)
	# Günlük pencere geçişin SON durumunda denenir: detay açıldıysa kapı tutar (due kalır);
	# açılmadıysa (bilinmeyen id) sıradan bir sekme geçişi.
	_maybe_auto_open_daily_rewards()


## Ana Sayfa'daki Günlük madalyonu (M8.9-02.1): GÜNLÜK ÖDÜLLER penceresini
## açar (Mağaza kartıyla AYNI pencere/durum). Bugünkü giriş ödülü henüz
## alınmadıysa (nadir — açılışta zaten alınır; cihaz tarihi ilerlemişse) aynı
## claim yolu pencereden önce çalışır. Onboarding bitmeden hiçbir şey olmaz.
func _on_daily_requested() -> void:
	open_daily_rewards()


## Ana Sayfa'daki Bonus sandık madalyonu: kural + ilerleme penceresi
## (GAME_DESIGN §5.2), OYNA → harita.
func _on_chest_requested() -> void:
	# TASK/046: aynı katmandaki GÖREVLER penceresinin altına açılmasın (dokunuş yolu zaten kapalı).
	# TASK/047: MEYDAN OKUMA penceresi de aynı katmanda.
	if (_missions != null and _missions.visible) or (_challenge_sheet != null and _challenge_sheet.visible):
		return
	_chest_info.open_info()


## Ana Sayfa'nın GÖREVLER girişi (TASK/046): görev penceresi — yalnız okur, kayda yazmaz,
## reklam çağırmaz. Tutorial koçluğunu bölmez; round / yaş ekranı / başka pencere açıkken
## açılmaz (dokunma yolu zaten karartmalı; bu kod yollarını da kapatır).
func open_missions() -> void:
	if _missions == null or _missions.visible or is_tutorial_active():
		return
	if _board != null and is_instance_valid(_board):
		return
	if _active_tab != 0 or not _screens[0].visible:
		return
	if _age_panel != null and _age_panel.visible:
		return
	if _daily_rewards.visible or _chest_info.visible or (_settings != null and _settings.visible):
		return
	# TASK/047: MEYDAN OKUMA penceresinin altına açılmaz.
	if _challenge_sheet != null and _challenge_sheet.visible:
		return
	# Pencere ve Ana Sayfa rozeti AYNI dönemi göstersin (gün uygulama açıkken değişmiş olabilir).
	_screens[0].refresh_missions()
	_missions.open_missions()


## Görünen GÖREVLER rozeti / penceresi yeniden okunur (öne dönüş — gün değişmiş olabilir).
func _refresh_missions_views() -> void:
	if _missions != null and _missions.visible:
		_missions.refresh()
	if not _screens.is_empty() and _screens[0].visible:
		_screens[0].refresh_missions()


## Ana Sayfa'nın MEYDAN OKUMA girişi (TASK/047): bugünün meydan okuma penceresi — yalnız okur, kayda
## yazmaz, reklam çağırmaz. Onboarding / tutorial / round / yaş ekranı / başka pencere açıkken ya da
## gün gerçeği yokken açılmaz (dokunma yolu zaten karartmalı; bu, kod yollarını da kapatır).
func open_daily_challenge() -> void:
	if _challenge_sheet == null or _challenge_sheet.visible or is_tutorial_active():
		return
	if not Onboarding.is_completed():
		return
	if _board != null and is_instance_valid(_board):
		return
	if _active_tab != 0 or not _screens[0].visible:
		return
	if _age_panel != null and _age_panel.visible:
		return
	if _daily_rewards.visible or _chest_info.visible or (_settings != null and _settings.visible) \
			or (_missions != null and _missions.visible):
		return
	var view: Dictionary = DailyChallenge.current_view()
	if view.is_empty():
		return
	# Pencere ve Ana Sayfa girişi AYNI günü göstersin.
	_screens[0].refresh_daily_challenge()
	_challenge_sheet.open_sheet(view)


## Pencerenin BAŞLA'sı: gün YENİDEN okunur. Gösterilen gün artık bugün değilse (pencere gece
## yarısını açık geçti) ya da bugün tamamlandıysa pencere bugüne tazelenir ve round BAŞLAMAZ —
## eski günün meydan okuması asla başlamaz; oyuncu yeni günü görüp yeniden basar (tazelenen pencere
## mevcut 300 ms parmak yatışmasını yeniden kurar — hızlı ikinci dokunuş yeni günü görmeden başlatmaz).
func _on_challenge_start_requested(shown_day: String) -> void:
	var view: Dictionary = DailyChallenge.current_view()
	if view.is_empty():
		_challenge_sheet.close_sheet()
		_screens[0].refresh_daily_challenge()
		return
	if String(view["day_key"]) != shown_day or bool(view["completed"]):
		_challenge_sheet.show_view(view)
		_screens[0].refresh_daily_challenge()
		settle_touch_input()
		return
	_challenge_sheet.close_sheet(false)
	start_daily_challenge()


## Öne dönüş (gün değişmiş olabilir): giriş ve açık pencere yalnız okuyarak tazelenir.
func _refresh_daily_challenge_views() -> void:
	if _challenge_sheet != null and _challenge_sheet.visible:
		var view: Dictionary = DailyChallenge.current_view()
		if view.is_empty():
			_challenge_sheet.close_sheet(false)
		elif view != _challenge_sheet.view():
			_challenge_sheet.show_view(view)
	if _round_kind == RoundKind.DAILY_CHALLENGE and _result.challenge_fail_day_stale(DailyChallenge.current_day()):
		_result.refresh_challenge_day_changed()
	if not _screens.is_empty() and _screens[0].visible:
		_screens[0].refresh_daily_challenge()


## Günlük giriş ödülü (GAME_DESIGN.md §5.4): yetkili tek işlem
## `DailyReward.claim_if_new_day` (günde bir kez; onboarding bitmeden
## no-op). Sonuç değişmez görünüm olarak saklanır ve TEK pencerede
## (GÜNLÜK ÖDÜLLER üst bölgesi) gösterilir; pencere ödül VERMEZ. Dönüş:
## bu çağrıda +15 verildi mi.
func _resolve_daily_login() -> bool:
	var result: Dictionary = DailyReward.claim_if_new_day()
	var view: Dictionary = DailyReward.view()
	if bool(result["claimed"]):
		view["just_claimed"] = true
		view["streak_broken"] = bool(result["streak_broken"])
		_refresh_shell_dough()
	else:
		# Daha önce alınmış ama henüz gösterilmemiş kutlama/uyarı korunur
		# (açılışta çözülür, pencere sonra açılır); gösterilince tüketilir.
		view["just_claimed"] = bool(_login_view.get("just_claimed", false))
		view["streak_broken"] = bool(_login_view.get("streak_broken", false))
	_login_view = view
	return bool(result["claimed"])


## Test/araç kancası (eski `_check_daily_reward` adı): giriş ödülünü çözer.
func _check_daily_reward() -> void:
	_resolve_daily_login()


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
	# M8.10: kapı artık `Onboarding.daily_rewards_unlocked()` — tutorial'ın
	# bitirildiği takvim gününde de kapalı (ilk gün kuralı).
	if not _booted or _daily_rewards == null or not Onboarding.daily_rewards_unlocked():
		return
	# TASK/043: pencerede reklamlı giriş noktaları var — yaş çözülmeden açılmaz.
	if _age_blocks_monetizable_surfaces():
		return
	if not DailyRewards.popup_due():
		return
	if _board != null and is_instance_valid(_board):
		return
	if _result.visible or _daily_rewards.visible \
			or (_settings != null and _settings.visible) or (_pause != null and _pause.visible) \
			or (_chest_info != null and _chest_info.visible) or _revive.visible or _refill.visible:
		return
	# TASK/046: GÖREVLER penceresi de bir pencere — günlük pencere üstüne açılmaz, "due" kalır.
	# TASK/047: MEYDAN OKUMA penceresi de.
	if (_missions != null and _missions.visible) or (_challenge_sheet != null and _challenge_sheet.visible):
		return
	# TASK/045: Profil'in Başarımlar / Unvanlar penceresi de bir pencere.
	if _screens.size() > 4 and _screens[4].has_open_overlay():
		return
	# TASK/045.1: Koleksiyon'un parça detayı da (TASK/044 artığı). Pencere "due" kalır —
	# bugün görüldü işaretlenmez; bir sonraki güvenli fırsatta açılır.
	if _screens.size() > 2 and _screens[2].is_detail_open():
		return
	if _ads != null and _ads.fullscreen_ad_active():
		return
	DailyRewards.mark_popup_seen()
	_open_daily_rewards_window(true)


## Mağaza kartı / Ana Sayfa madalyonu (gün boyu). Günlük sistem kilitliyken
## (onboarding bitmedi YA DA tutorial günü) hiçbir şey yapmaz.
func open_daily_rewards() -> void:
	if _daily_rewards == null or not Onboarding.daily_rewards_unlocked():
		return
	if _daily_rewards.visible or _age_blocks_monetizable_surfaces():
		return
	# TASK/046: aynı katmandaki GÖREVLER penceresinin altına açılmaz (dokunuş yolu zaten kapalı).
	# TASK/047: MEYDAN OKUMA penceresi de aynı katmanda.
	if (_missions != null and _missions.visible) or (_challenge_sheet != null and _challenge_sheet.visible):
		return
	_open_daily_rewards_window(false)


func _open_daily_rewards_window(auto: bool) -> void:
	_clear_daily_request()
	# Giriş ödülü pencereden ÖNCE çözülür (gün değiştiyse tam bir kez +15);
	# pencere yalnız sonucu gösterir. "Az önce alındı" kutlaması tek sefer.
	_resolve_daily_login()
	var login: Dictionary = _login_view.duplicate()
	_login_view["just_claimed"] = false
	_login_view["streak_broken"] = false
	_daily_rewards.open_popup(_daily_provider_ready(), _provider_note(), auto, login)
	# TASK/058 (Ana Sayfa Günlük girişi incelemesinde bulunan gizli kusur): GÖREVLER / MEYDAN OKUMA pencereleriyle aynı
	# 300 ms parmak yatışması — girişe hızlı çift dokunuşun ikincisi yeni açılan pencerenin karartmasına düşüp onu anında
	# KAPATMASIN (pencere "hiç açılmadı" gibi okunurdu).
	settle_touch_input()
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
	# TASK/058: kapanış da yatışır — X'e çift dokunuşun ikincisi alttaki Ana Sayfa kartına düşüp pencereyi yeniden açmasın.
	settle_touch_input()
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

## `tutorial_queue`: yalnız ilk açılış tutorial'ı doldurur (T1, T1). Normal
## akışta boş — DropBag birebir eskisi gibi çalışır.
func _start_level(level: LevelData, tutorial_queue: Array[int] = []) -> void:
	_begin_round(level, RoundKind.NORMAL)
	if not tutorial_queue.is_empty():
		_board.setup_tutorial_queue(tutorial_queue)
	_board.round_finished.connect(_on_round_finished)
	add_child(_board)
	# TASK/051: mevcut 300 ms geçiş yatışması (yeni kural değil; meydan okuma başlangıcıyla aynı nokta: board girdiye
	# hazır olduğu an) — Yeniden Başlat / TEKRAR / Harita düğmesine hızlı ikinci dokunuş, basılı tutulsa da, yeni board'a
	# bırakış ya da HUD dokunuşu olarak düşmez. Değişimden ÖNCE başlamış parmağı GameBoard'un dizi sahipliği eler. Tek
	# kurma: çağıranlar (mola, sonuç, Harita, tutorial, ertelenen değişim) ayrıca kurmaz.
	settle_touch_input()


## Round sınırı — normal round ve meydan okuma ORTAK (TASK/047'de `_start_level`'dan çıkarıldı,
## davranış aynen): kabuk / sonuç / eski board / pencereler temizlenir, yeni board kurulur ve
## ortak sinyalleri bağlanır. Round türüne özel kurulum + round_finished bağı + add_child
## ÇAĞIRANDA.
func _begin_round(level: LevelData, kind: RoundKind) -> void:
	_round_kind = kind
	if kind != RoundKind.DAILY_CHALLENGE:
		_challenge_day = ""
	_current_level = level
	_round_finalized = false
	_hide_shell()
	_result.hide_result()
	_clear_board()
	# Yeni round sınırı: ertelenmiş monetizasyon açılışı için güvenli an
	# (board henüz yok; yuva bu round'un ilk yerleşiminde okunur).
	_activate_monetization_if_safe()
	if _pause != null:
		_pause.close_menu()

	_revive.hide_offer()
	_refill.hide_refill()
	_clear_refill_request()

	_set_ad_surface(MonetizationManager.Surface.GAMEPLAY)
	_board = GAME_BOARD_SCENE.instantiate()
	_board.setup(level)
	_board.revive_offered.connect(_on_revive_offered)
	_board.power_refill_offered.connect(_on_power_refill_offered)
	_board.settings_requested.connect(_on_board_settings_requested)
	_board.pause_requested.connect(open_pause_menu)


# --- Günlük meydan okuma (TASK/047 — GAME_DESIGN §5.11) ---
#
# Sorumluluk dağılımı:
#   DailyChallenge  : preset / gün / dizi / level / kayıt bloğu kuralları (SAF)
#   GameBoard       : bütçe, yatışma, sebep, güç ve devam kapalı (mekanik dikiş)
#   SaveManager     : ilk başarı → +20 Hamur + tamamlanma günü, TEK işlem
#   Main (bu)       : açık round türü, başlatma / bitiş / tekrar / çıkış yönlendirmesi, gece yarısı,
#                     gecikmeli sonucun deneme kimliği
#
# P1 YALITIM: meydan okuma round'u normal `_on_round_finished`'a HİÇ girmez — XP, tur, merge /
# bonus sandık sayacı, görev, başarım, yıldız, level, rekor, en yüksek tier, sandık, teselli ve
# geçiş reklamı denemesi YOK. Tek kalıcı etki ilk başarının +20 Hamur'u + tamamlanma günü.

## Kabul edilen GÜNÜN meydan okuması (şimdi okunur) — dizinin başından, tam bütçeyle. Girişler:
## Ana Sayfa sayfasının BAŞLA'sı, sonuç TEKRAR DENE / YENİ MEYDAN OKUMA, mola Yeniden Başlat.
## Gün gerçeği yok / bugün tamamlandı (tekrar oynanmaz) / onboarding bitmedi → başlamaz (false).
func start_daily_challenge() -> bool:
	if not Onboarding.is_completed() or is_tutorial_active():
		return false
	var view: Dictionary = DailyChallenge.current_view()
	if view.is_empty() or bool(view["completed"]):
		return false
	var day: String = String(view["day_key"])
	var level: LevelData = DailyChallenge.make_level(day)
	if level == null:
		return false
	_challenge_attempt += 1
	_begin_round(level, RoundKind.DAILY_CHALLENGE)
	_challenge_day = day
	_board.setup_challenge(DailyChallenge.Sequence.new(day), int(view["drop_budget"]))
	_board.round_finished.connect(_on_challenge_round_finished)
	add_child(_board)
	# Mevcut 300 ms geçiş yatışması (yeni kural değil): BAŞLA / TEKRAR DENE dokunuşunun bırakışı ya da
	# hızlı ikinci dokunuşu yeni board'a bırakış olarak düşmez.
	settle_touch_input()
	return true


## TEKRAR DENE / YENİ MEYDAN OKUMA / mola Yeniden Başlat: o anki günün meydan okuması baştan (gün
## değiştiyse yeni günün). Başlatılamazsa (gün gerçeği yok / bugün tamamlandı) Ana Sayfa.
func _retry_daily_challenge() -> void:
	if not start_daily_challenge():
		_leave_daily_challenge()


## Meydan okumadan çıkış (sonuç ANA SAYFA / mola Ana Menüye Dön): board gider, Ana Sayfa (giriş
## yeri). Terk edilen deneme hiçbir şey yazmaz.
func _leave_daily_challenge() -> void:
	_result.hide_result()
	_clear_board()
	_round_kind = RoundKind.NORMAL
	_challenge_day = ""
	_show_tab(0)


## Meydan okuma round'u KESİN bitti — normal `_on_round_finished`'ın YERİNE (bkz. P1 yalıtım). İlk
## başarı ödülü sonuç gecikmesinden ÖNCE yazılır (süreç ölse de tam bir kez); kayıp kayda yazmaz.
## Gece yarısı: ödül denemenin BAŞLADIĞI güne.
func _on_challenge_round_finished(won: bool) -> void:
	if _round_finalized:
		return
	_round_finalized = true
	_revive.hide_offer()
	var board: Node2D = _board
	var attempt: int = _challenge_attempt
	var day: String = _challenge_day
	var outcome: Dictionary = {"won": won, "day_key": day, "rewarded": false, "reward": 0,
		"fail_reason": DailyChallenge.FailReason.NONE, "drops_used": 0, "drop_budget": 0,
		"target_tier": 0, "reached_tier": 0, "day_changed": false}
	if board != null and is_instance_valid(board):
		outcome["fail_reason"] = board.fail_reason()
		outcome["drops_used"] = board.drops_used()
		outcome["drop_budget"] = board.drop_budget()
		outcome["target_tier"] = board.level.target_tier
		outcome["reached_tier"] = board.max_tier_reached()
	if won:
		var rewarded: bool = SaveManager.complete_daily_challenge(day)
		outcome["rewarded"] = rewarded
		outcome["reward"] = DailyChallenge.REWARD_DOUGH if rewarded else 0
	# TASK/050: kabul edilen meydan okuma bitişi ekranın sahibi — aynı karede merge denemeyi açık molada bitirebilir;
	# mola meydan okuma sonucunun üstünde kalmaz. TASK/049'un paylaşılan temizliği (eylemsiz; ödül / kayıt / gün /
	# gezinme / reklam yok), ödül / tamamlanma işleminden SONRA, gecikmeden ÖNCE. İş mantığı ayrı kalır.
	_dismiss_terminal_gameplay_overlays()
	await get_tree().create_timer(RESULT_DELAY).timeout
	if not _challenge_result_current(attempt, board):
		return
	# Gün, sonuç GÖSTERİLİRKEN okunur (gecikme gece yarısını geçebilir).
	var today: String = DailyChallenge.current_day()
	outcome["day_changed"] = not today.is_empty() and today != day
	_set_ad_surface(MonetizationManager.Surface.RESULT)
	# "Hamle bitti" yatışmasında reddedilen dokunuşlar sürerken açılan sonucun düğmeleri, açılış
	# görünmeden yeni başlayan bir dokunuşla basılmasın: mevcut 300 ms parmak yatışması.
	settle_touch_input()
	_result.show_challenge_result(outcome)


## Gecikmeli meydan okuma sonucu hâlâ geçerli mi: aynı deneme, aynı board ekranda, round türü meydan
## okuma. Arada yeniden başlatma / tekrar / çıkış / normal round → eski sonuç AÇILMAZ.
## (`board` Variant: serbest bırakılmış düğüm Node tipli parametreye verilemez.)
func _challenge_result_current(attempt: int, board: Variant) -> bool:
	if attempt != _challenge_attempt or _round_kind != RoundKind.DAILY_CHALLENGE:
		return false
	if board == null or not is_instance_valid(board):
		return false
	return _board == board


## Testler / QA sürücüsü.
func round_kind() -> int:
	return _round_kind


func is_daily_challenge_round() -> bool:
	return _round_kind == RoundKind.DAILY_CHALLENGE


func _clear_board() -> void:
	# Round terk ediliyor: tutorial yarıdaysa overlay kapanır ve KAYIT
	# DEĞİŞMEZ (onboarding false kalır, bir sonraki açılışta baştan, §25).
	if _tutorial != null and _tutorial.is_active():
		_tutorial.abort()
	if _revive != null:
		_revive.hide_offer()
	if _refill != null:
		_refill.hide_refill()
	_clear_refill_request()
	# Board giderken açık bir reklam talebi varsa (pencere kapanmadan terk)
	# iptal: geç gelen ödül callback'i hiçbir şey vermez.
	_cancel_rewarded_request()
	if _board != null:
		# TASK/045: giden board kare sonuna kadar yaşar; geç bir round_finished'i yeni
		# round'un kesinleştirme korumasını tüketmesin (terk edilen round zaten sayılmaz).
		if _board.round_finished.is_connected(_on_round_finished):
			_board.round_finished.disconnect(_on_round_finished)
		if _board.round_finished.is_connected(_on_challenge_round_finished):
			_board.round_finished.disconnect(_on_challenge_round_finished)
		_board.queue_free()
		_board = null
	# TASK/048: board'un sahipliği bitti — bekleyen gecikmeli normal sonuç / geçiş reklamı (ve molaya
	# ertelenen round değişimi) artık eski. En sonda (bağlar koptuktan sonra): yukarıdaki adımlardan biri
	# ileride round_finished'i eşzamanlı yayarsa yakalanan nesil yine eski kalır.
	_deferred_round_change = Callable()
	_round_generation += 1


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
	if _ads == null:
		return
	# TASK/046.1: yaş ekranı açıkken gelen yüzey değişimi (NONE dahil) yalnız hatırlanır —
	# kapanınca uygulanır.
	if _age_panel != null and _age_panel.visible:
		_surface_before_age = surface
		return
	_ads.set_surface(surface as MonetizationManager.Surface)


## Board devam teklifi açtı: round HENÜZ BİTMEDİ, hiçbir ödül/sonuç akışı
## çalışmadı.
func _on_revive_offered(remaining: int) -> void:
	# Board aynı karede terk edilmiş olabilir (queue_free sonrası son fizik
	# adımı): ölü board için teklif açılmaz (harness'ta görüldü; production
	# yolları board'u yalnız duraklatılmışken siler).
	if _board == null or not is_instance_valid(_board):
		return
	# TASK/047: meydan okumada devam YOK (board hak 0 verir; bu ikinci kapı) — teklif / ödüllü istek
	# açılmaz, round kesin kayıpla biter (board donuk kalmaz).
	if _round_kind == RoundKind.DAILY_CHALLENGE:
		_board.decline_revive()
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
	# TASK/047: meydan okumada güç / refill / ödüllü güç isteği YOK (board güçleri kilitler; ikinci
	# kapı) — pencere açılmaz, board donuk kalmaz.
	if _round_kind == RoundKind.DAILY_CHALLENGE:
		if _board != null and is_instance_valid(_board):
			_board.exit_refill_pending(false)
		return
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
	# TASK/045: yinelenen kesinleştirme (aynı round için ikinci sinyal / çağrı) hiçbir
	# şey yazmaz — XP, tur, merge, yıldız, sandık round başına tam bir kez.
	if _round_finalized:
		return
	_round_finalized = true
	# TASK/048: gecikmeli sonuç / geçiş reklamı BU round'un — nesil gecikmeden ÖNCE yakalanır.
	var generation: int = _round_generation
	# Round gerçekten bitti: teklif penceresi her hâlükârda kapanır (kazanma
	# fail-pending sırasında da gerçekleşebiliyor).
	_revive.hide_offer()

	# Savunma (M8.10): tutorial hâlâ açıkken round biterse (Level 1 hedefi
	# tier 4 olduğu için öğretim merge'i round'u BİTİREMEZ — bu, taşma gibi
	# beklenmedik bir yol için ağ) onboarding yarım bırakılmaz: oyuncu bir
	# round'u tamamladı, kanonik tamamlanma yolundan geçirilir ve coach
	# yüzeyi sonuç ekranından ÖNCE kapanır.
	if is_tutorial_active():
		_tutorial.finish_for_round_end()

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
	# Oyuncu ilerlemesi (TASK/045): önce bekleyen başarım varsa SESSİZCE uzlaşır (bu
	# round'a mal edilmez), sonra "önce" görüntüsü alınır. Yıldız farkı yazımdan ÖNCEKİ
	# kalıcı en iyiye göre — tekrar oynanan level'da sahip olunan yıldız XP vermez.
	SaveManager.reconcile_achievements()
	var xp_before: int = SaveManager.player_xp()
	var achievements_before: Array[StringName] = SaveManager.unlocked_achievements()
	var fixed_cleared: bool = won and not _current_level.is_endless
	var stars_before: int = SaveManager.stars_for_level(_current_level.level_number) if fixed_cleared else 0

	# TASK/045: rekor / level açılışı / yıldız yalnız bellekte (`save = false`) — hemen
	# aşağıdaki round kaydı hepsini XP ile TEK yazmada diske indirir; arada bir çökme
	# yıldızı kaydedip XP'yi kaybettiremez (yıldız farkı kalıcı en iyiye göre ölçülür).
	if _current_level.is_endless:
		new_record = SaveManager.record_endless_score(score, false)
	elif won:
		SaveManager.complete_level(_current_level.level_number, false)
		SaveManager.record_stars(_current_level.level_number, stars, false)
	var newly_unlocked: bool = SaveManager.highest_level_unlocked() > unlocked_before
	# Profil sayaçları (TASK/044): round başına TAM bir kez, burada — terk edilen
	# round (abandon_run / yeniden başlat) bu yola girmez, sayılmaz. TASK/045: round'un
	# XP'si (merge + sabit level bitişi + yeni yıldız) AYNI yazmada.
	var xp_award: int = PlayerProgression.round_xp_award(merges, fixed_cleared, stars_before,
		stars if fixed_cleared else 0)
	# TASK/046: günlük / haftalık görevler — bu round'un AYNI kesin gerçekleri (gerçek merge /
	# tur / sabit level bitişi) ve otomatik görev Hamur'u yalnız bellekte (`save = false`);
	# hemen aşağıdaki round kaydı hepsini XP ile TEK yazmada diske indirir. XP / başarım /
	# sandık / reklam YOK; terk edilen round bu yola hiç girmez.
	var missions: Dictionary = SaveManager.record_mission_round(merges, fixed_cleared, false)
	SaveManager.record_round_finished(GameState.highest_tier_created, xp_award)

	var rewards: Array[ChestReward] = _collect_rewards(won, merges)
	# Sonuç ekranının kompakt ilerleme özeti: yalnız BU round'un XP'si ve bu round'un
	# (merge / yıldız / level / sandıktan gelen koleksiyon) açtığı başarımlar.
	var progress: Dictionary = PlayerProgression.round_summary(xp_before, SaveManager.player_xp(),
		achievements_before, SaveManager.unlocked_achievements())
	# TASK/046: aynı şeritte kompakt görev satırı — bu round'da tamamlanan görevler + Hamur'u.
	progress["missions"] = missions
	# TASK/052: zorunlu geçiş reklamı sıklığı (AdPolicy: önceki gerçek gösterimden bu yana 2 kesinleşen NORMAL round
	# + 300 aktif sn) — kesinleşen round gecikmeden ÖNCE, round başına tam bir kez (`_round_finalized`) sayılır;
	# gecikmede round değiştirilse de sayılmış kalır. Tutorial'dan doğan round ve monetizasyon kapalıyken yönetici
	# saymaz; meydan okuma bu işleyiciye hiç girmez (ayrı bitiş işleyicisi).
	if _ads != null:
		_ads.note_normal_round_finalized()
	# TASK/049: kabul edilen bitiş ekranın sahibi — bu round'un mola / refill penceresi sonuç ve geçiş reklamı
	# akışının üstünde kalmaz: gecikmeden ÖNCE, eylemsiz ve round'un ilerlemesi yazıldıktan SONRA (kapanış,
	# round'un kazandığını hiçbir yoldan etkileyemez).
	_dismiss_terminal_gameplay_overlays()

	await get_tree().create_timer(RESULT_DELAY).timeout
	# TASK/048: gecikmede round değiştirildiyse (yeniden başlatma / terk / yeni round / başka kip) eski
	# sonuç ve geçiş reklamı SUNULMAZ. İlerleme yukarıda bir kez yazıldı — geri alınmaz, yinelenmez.
	if not _round_still_owned(generation):
		return
	# Doğal mola (M8.9-02): round KESİN bitti, devam kararları tamamlandı,
	# sonuç henüz açılmadı. Geçiş reklamı uygun + hazırsa ŞİMDİ gösterilir ve
	# sonuç reklam kapanınca (tam bir kez) açılır; değilse sonuç HEMEN —
	# reklam yüklemesi ya da bekleme için sonuç asla bekletilmez.
	_result_seq += 1
	var present: Callable = _present_result.bind(_result_seq, generation, won, score, stars, rewards,
		new_record, newly_unlocked, reached_tier, progress)
	# Fırlatma aralığı (TASK/048): reklam SDK'ya verildiği an geri alınamaz — bu round, mola `_present_result`'ta
	# bitene dek ekranın sahibi kalır; aradaki round değişimi ertelenir (`_defer_round_change`).
	_round_break_generation = generation
	if _ads != null and _ads.try_show_interstitial("round_finish", present):
		return
	present.call()


## TASK/049 — kesinleşen round'un oyun içi engelleyici pencereleri sonucun / geçiş reklamının üstünde KALMAZ.
## Büyütücü dönüşümü board'a bağlı bir tween'dir; mola / refill dondurması ağaç duraklatması değil, özel board
## dondurmasıdır — dönüşüm o pencere açıkken tamamlanıp round'u bitirebilir. Bitiş kabul edilince mola ve stok 0
## refill penceresi EYLEMSİZ kapanır: Devam Et / Yeniden Başlat / Ana Menüye Dön, satın alma, ödüllü istek, refill,
## bırakış, board değişimi, kayıt YOK (board'un menü / refill dondurması `GameBoard._finish`'te bırakıldı). Açık
## bir ödüllü refill talebine dokunulmaz: iptal edilmez, ödül verilmez — kendi token yolu sürer. TASK/053: açık Ayarlar
## da kendi kapanış yoluyla kapanır (katman 13 — sonucun üstünde kalırdı); kapanış işleyicisi bitmiş board'da hiçbir
## şey yapmaz, tercih yazılmaz. Ayarlar'dan açılan alt pencereler (yaş bilgisi paneli, gizlilik formu, tarayıcı) bu
## temizliğin dışında: menü dondurmasında round yalnız Büyütücü dönüşümüyle (0,15 sn) ya da aynı karedeki merge ile
## biter, `open_settings` ise 300 ms parmak yatışması kurar — bitişte Ayarlar'ın hiçbir kontrolüne dokunulmuş olamaz;
## gizli Ayarlar da onları açmaz (SettingsPanel). Pencere yoksa ya da tekrar çağrılırsa hiçbir şey yapmaz.
## TASK/050: meydan okuma bitişi de çağırır (`_on_challenge_round_finished`) — ortak pencere temizliği, ayrı iş mantığı.
func _dismiss_terminal_gameplay_overlays() -> void:
	if _pause != null and _pause.visible:
		_pause.close_menu()
	if _refill != null and _refill.visible:
		_refill.hide_refill()
	if _settings != null and _settings.visible:
		close_settings()


## Sonuç ekranını açar — round bitişi başına tam bir kez (`seq`; geç gelen
## reklam callback'i ikinci bir sonuç üretemez, sonuç kaybolmaz). `progress`:
## TASK/045 kompakt XP / seviye / başarım özeti (PlayerProgression.round_summary).
## `generation` (TASK/048): sonucu zamanlayan round'un nesli — reklam açıkken / sonrasında round
## değiştiyse eski sonuç yeni durumun üstüne açılmaz; mola sürerken ertelenen round değişimi
## sonucun YERİNE burada çalışır.
func _present_result(seq: int, generation: int, won: bool, score: int, stars: int, rewards: Array[ChestReward],
		new_record: bool, newly_unlocked: bool, reached_tier: int, progress: Dictionary = {}) -> void:
	# TASK/048: mola bitti (reklam kapandı / gösterilemedi / onay gelmedi) — round'un reklam sahipliği serbest.
	if _round_break_generation == generation:
		_round_break_generation = -1
	if not _round_still_owned(generation):
		return
	# Mola sürerken basılan round değişimi ŞİMDİ, eski sonucun yerine (ilerleme kesinleşmede bir kez yazıldı).
	if _deferred_round_change.is_valid():
		var change: Callable = _deferred_round_change
		_deferred_round_change = Callable()
		change.call()
		return
	if seq != _result_seq or _current_level == null:
		return
	if _board == null or not is_instance_valid(_board):
		# Round bu arada terk edildi (harness); sonuç açılmaz.
		return
	_result_seq += 1
	_set_ad_surface(MonetizationManager.Surface.RESULT)
	_result.show_result(_current_level, won, score, stars, rewards, new_record,
		newly_unlocked, reached_tier, progress)


## TASK/048: gecikmeli normal sonuç hâlâ kendisini zamanlayan round'a mı ait — arada board değişmedi mi
## (nesil yalnız `_clear_board`'da ilerler: yeni round, yeniden başlatma, terk, çıkış).
func _round_still_owned(generation: int) -> bool:
	return generation == _round_generation


## TASK/048 fırlatma aralığı: bu round'un geçiş reklamı SDK'ya verildi ve mola sürüyorsa round'u değiştiren
## eylem (`change`) molanın sonuna ertelenir (true) — reklam, mola sürdükçe yalnız onu isteyen round'un üstünde
## görünür; round şimdi değişseydi açılan reklam yeni round'un / Harita'nın üstünde kalırdı. TASK/049'dan beri
## mola penceresi kesinleşmede kapandığından düğmeleri bu aralığa ulaşamaz — erteleme savunma olarak kalır
## (işleyiciyi doğrudan çağıran yollar, ör. QA kancaları, yine buradan geçer).
func _defer_round_change(change: Callable) -> bool:
	if _round_break_generation != _round_generation:
		return false
	_deferred_round_change = change
	return true


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
	# TASK/047: meydan okuma tekrarı normal `_start_level` yoluna GİRMEZ (level 0 normal ilerlemeye
	# hiç düşmez) — o anki günün meydan okuması baştan.
	if _round_kind == RoundKind.DAILY_CHALLENGE:
		# Açık kayıp sonucu gece yarısını geçtiyse önce "Gün değişti" kopyasına yenilenir (açık
		# pencerenin BAŞLA'sı gibi): bayat "Sıra aynı" kopyasının altından yeni günün meydan okuması
		# sessizce başlamaz; ikinci basış (YENİ MEYDAN OKUMA) başlatır.
		if _result.challenge_fail_day_stale(DailyChallenge.current_day()):
			_result.refresh_challenge_day_changed()
			settle_touch_input()
			return
		_retry_daily_challenge()
		return
	_start_level(_current_level)


func _on_exit_pressed() -> void:
	if _round_kind == RoundKind.DAILY_CHALLENGE:
		_leave_daily_challenge()
		return
	_result.hide_result()
	_clear_board()
	# Oyundan çıkınca haritaya dönülür — oynanan yerin yanına.
	_show_tab(1)
