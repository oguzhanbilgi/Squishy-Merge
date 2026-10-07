extends Node
## TASK/058 — Ana Sayfa V3 odak testi. Gerçek Main, gerçek ekranlar, gerçek parmak olayları (`Input.parse_input_event`,
## Android'deki gibi öykünülen fare). Headless.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_home_v3/` altındaki bir yola yönlendirilir, sonda
## geri alınır; gerçek kayıt ailesi (kanonik + .tmp + .bak) başta / sonda bayt bayt karşılaştırılır.
##   godot --headless --audio-driver Dummy --path . res://tools/home_v3_test.tscn
##   godot --headless --audio-driver Dummy --path . res://tools/home_v3_test.tscn -- daily-only
##
## `daily-only`: yalnız A bölümü — owner'ın "Ana Sayfa'daki Günlük'e basınca bir şey gelmiyor" bulgusunun taban farkı.
## A bölümü bilerek ekran API'sine bağlı DEĞİL (girişi adıyla bulur, gerçek dokunuşla basar) — kanonik `28a5bf1`'de de
## koşar ve orada açık FAIL verir. Owner'ın cihazda yaşadığı mekanizma A1'dir (ilk gün kapısı — QA kaydında
## `onboarding_completed_day = 2026-10-06`, test günü). A3 / A4 inceleme sırasında bulunan GİZLİ kusurlardır (etiket ölü
## bölgesi, yatışmasız pencere); owner'ın o gün gördüğü şey olduklarına dair kanıt yoktur.
##
## Bölümler:
##   A günlük girişi   ilk gün (tutorial bugün bitti): görünen giriş ya pencereyi açar ya da kilidini AÇIKÇA gösterir
##                     (pasif + "Yarın açılır") — sessiz ölü dokunuş YOK; ekonomi değişmez (Hamur / seri / kota). Açık gün:
##                     girişin ortasına VE etiket yazısına gerçek dokunuş GÜNLÜK ÖDÜLLER'i tam bir kez açar; açılışın
##                     hemen ardından karartmaya düşen dokunuş pencereyi KAPATMAZ, kapanışın hemen ardından girişe düşen
##                     dokunuş pencereyi YENİDEN AÇMAZ (300 ms yatışma — pozitif kontrollerle); hızlı çift dokunuş yığmaz;
##                     ACTION_CANCEL 0 açılış; GERİ kapatır; Ana Sayfa yeniden kullanılır; ekonomi aynen
##   B günlük durumu   yalnız gerçek veri: kilitli · giriş hazır · ücretsiz sandık hazır · sandık alındı · bugünlük tamam
##                     (alt yazı, "!" rozeti, etkinlik, kilit pictosu, ›); seri yalnız bugün alındıysa; kart yenilemesi
##                     kaydı DEĞİŞTİRMEZ; ertesi güne öne dönüşte kilitli kart kendiliğinden açılır
##   C OYNA            tek baskın V3 CTA (SquishyButton PRIMARY HERO, GestureGuard); taze dokunuş Harita'ya tam BİR kez;
##                     hızlı çift dokunuş tek gezinme + level başlamaz; ACTION_CANCEL 0; kabuğun HARİTA'sı etkilenmez
##   D meydan okuma    kart görünür, gerçek özet (hedef portresi + "… yap · N hamlede" + "+20 HAMUR"); dokunuş pencereyi tam
##                     bir kez; çift dokunuş yığmaz; iptal 0; GERİ kapatır; tamamlanınca nane TAMAM cipi, kart yine açar
##   E madalyonlar     GÖREVLER / BONUS SANDIK: gövdeye ve ETİKET plakasına dokunuş pencereyi tam bir kez açar; iptal 0;
##                     GERİ
##   F yinelenenler    Ana Sayfa'da Mağaza / Koleksiyon / Profil / Harita kısayolu YOK (düğüm, sinyal, buton, kaynak);
##                     üst satır ve level bilgisi DURUM (fare almaz); etkileşimli öğe tam 5; kabuğun MAĞAZA / KOLEKSİYON /
##                     PROFİL öğeleri gerçek dokunuşla tam bir gezinme; K9 terimleri ("SV. N", "SIRADAKİ BÖLÜM N", sonsuz aynen;
##                     görünen "LV." / "Level N" yok)
##   G yerleşim        720×1280 · 16:9 + banner 112 / 128 · 720×1600 · A36 benzeri (üst 61) banner'sız / banner'lı ·
##                     geniş tuval 960×1280: hiçbir öğe kabuğun ayak izine / banner yuvasına girmez; OYNA ile kabuk
##                     arasında iki kart (bitişik iki düğme yok); kartlar / OYNA / level bilgisi çakışmaz; madalyonlar
##                     maskotun opak pikselleriyle çakışmaz; maskot baskın; dokunma hedefleri ≥ 84; yazı ≥ 14 px; kart
##                     yazıları ve en uzun unvan kırpılmaz; kartlar tepsiden ≥ 28 px (kompakt kabukta da)
##   H teklif yuvası   TASK/062 yuvası boş + gizli, yer kaplamaz; sözleşme: içerik verilince (ayrı yerleşim çağrısı
##                     olmadan) kartlar yukarı kayar, çakışma yok (yalnız test içeriği — üründe teklif YOK)
##   I kalıcılık       Ana Sayfa'nın dört penceresini açıp kapatmak kayıt dosyasını DEĞİŞTİRMEZ; Ana Sayfa GERİ = çıkış

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_home_v3"
const PATH: String = DIR + "/save.json"
const MON: String = "2026-09-28"
const THU: String = "2026-10-01"
const WED: String = "2026-09-30"
const BACK_GAP_MSEC: int = 320
const SHOWCASE_ID: StringName = &"rare_02"
const SECTIONS: int = 9
const A36_SAFE_TOP: float = 61.0
const A36_SLOT: float = 112.0

var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _sections_total: int = 0
var _finished: bool = false
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _main: Node2D
var _last_back_msec: int = -100000
var _daily_only: bool = false


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	_daily_only = OS.get_cmdline_user_args().has("daily-only")
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_owner_state = _owner_snapshot()
	_saved_data = SaveManager.data.duplicate(true)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	SaveManager.save_path = PATH
	get_tree().create_timer(400.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 400 s'de bitmedi — SaveManager geri alındı")
			if _main != null and is_instance_valid(_main):
				_main.free()
			_teardown()
			get_tree().quit(2))
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame

	_sections_total = 1 if _daily_only else SECTIONS
	await _daily_entry()
	if not _daily_only:
		await _daily_states()
		await _play()
		await _challenge()
		await _medallions()
		await _removed_shortcuts()
		await _layout_matrix()
		await _offer_slot()
		await _persistence()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, _sections_total],
		_sections_done == _sections_total)

	print("-- Z: kayıt")
	await _teardown_main()
	_teardown()
	_c("SaveManager gerçek yola döndü, test klasörü silindi, saat kancası boş, banner yuvası 0",
		SaveManager.save_path == SaveManager.SAVE_PATH and not DirAccess.dir_exists_absolute(DIR)
		and DailyRewards.clock_override == "" and is_zero_approx(UiKit.banner_slot()))
	_c("sahibin gerçek kayıt ailesi (kanonik + .tmp + .bak) bayt-aynı", _owner_snapshot() == _owner_state)
	_finished = true
	# Son dokunuşun arayüz sesi bitsin (çalan AudioStreamPlayback çıkışta "kaynak hâlâ kullanımda" uyarısı üretmesin).
	await get_tree().create_timer(0.8).timeout
	print("\nSONUC: %d kontrol, %d hata" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _exit_tree() -> void:
	if not _finished:
		_teardown()


# --- A: günlük girişi (owner bulgusu A1 + inceleme sırasında bulunan gizli kusurlar A3 / A4 — taban farkı) ------------

func _daily_entry() -> void:
	print("-- A: Günlük girişi — sessiz ölü dokunuş yok (owner bulgusu, Issue #1 §4)")
	# A1 — ilk gün: tutorial BUGÜN (THU) bitti → M8.10 ilk gün kuralı (GAME_DESIGN §12.3, KİLİTLİ) günlük sistemi kapatır.
	await _boot({"onboarding_completed_day": THU})
	var home: CanvasLayer = _main._screens[0]
	var entry: Control = _daily_node(home)
	_c("A1 ilk gün: kural gerçekten etkin (Onboarding.daily_rewards_unlocked() = false)",
		not Onboarding.daily_rewards_unlocked())
	_c("A1 Ana Sayfa'da Günlük girişi var ve görünür ('Daily' düğümü)", entry != null and entry.is_visible_in_tree())
	if entry == null:
		_sections_done += 1
		return
	var dough0: int = SaveManager.dough()
	var streak0: int = SaveManager.daily_streak()
	var daily0: Dictionary = (SaveManager.data.get("daily_rewards", {}) as Dictionary).duplicate(true)
	var enabled: bool = not (entry is BaseButton and (entry as BaseButton).disabled)
	var texts: String = _texts(entry)
	await _tap(entry)
	var opened: bool = _main._daily_rewards.visible
	print("    giriş: sınıf=%s etkin=%s yazılar=[%s] dokunuş→pencere=%s" % [_class_of(entry), str(enabled), texts,
		str(opened)])
	_c("A1 ilk gün: görünen giriş SESSİZ ÖLÜ DEĞİL — dokunuş pencereyi açar YA DA giriş kilidini açıkça gösterir "
		+ "(pasif + 'Yarın açılır')", opened or (not enabled and texts.contains("Yarın açılır")))
	_c("A1 ilk gün: kilitli kural korunur — pencere AÇILMAZ (GAME_DESIGN §12.3), ödül / seri / kota değişmez",
		not opened and SaveManager.dough() == dough0 and SaveManager.daily_streak() == streak0
		and (SaveManager.data.get("daily_rewards", {}) as Dictionary) == daily0)
	if opened:
		_main._daily_rewards.close_popup()
		await _wait_settled()

	# A2 — açık gün (yerleşik oyuncu: tamamlanma günü boş): gerçek dokunuş girişin ortasına.
	await _boot()
	home = _main._screens[0]
	entry = _daily_node(home)
	_c("A2 açık gün: günlük sistem açık", Onboarding.daily_rewards_unlocked())
	_c("A2 açık gün: Günlük girişi görünür ve etkin", entry != null and entry.is_visible_in_tree()
		and not (entry is BaseButton and (entry as BaseButton).disabled))
	if entry == null:
		_sections_done += 1
		return
	var opens: Array[int] = [0]
	var counter := func(_name: StringName, event: Dictionary) -> void:
		if _name == &"daily_popup_shown" and not bool(event.get("auto", true)):
			opens[0] += 1
	AdEvents.subscribe(counter)
	await _tap(entry)
	_c("A2 girişin ortasına gerçek dokunuş → GÜNLÜK ÖDÜLLER penceresi tam BİR kez (otomatik değil)",
		_main._daily_rewards.visible and not _main._daily_rewards.is_auto_opened() and opens[0] == 1)
	_c("A2 pencere açıkken kabuk gizli (TASK/057 görünürlük matrisi)", not _main.global_nav().visible)
	await _back()
	_c("A2 GERİ pencereyi kapatır, Ana Sayfa'da kalınır, kabuk geri gelir", not _main._daily_rewards.visible
		and _main._active_tab == 0 and home.visible and _main.global_nav().visible)
	await _wait_settled()

	# A3 — doğal dokunuş: girişin ETİKET yazısına (madalyon plakası / kart başlığı). Gizli kusur (inceleme bulgusu).
	var label: Label = _label_with(entry, "GÜNLÜK")
	_c("A3 girişin 'GÜNLÜK' etiketi var", label != null)
	if label != null:
		var label_at: Vector2 = label.get_global_rect().get_center()
		await _tap_at(label_at)
		print("    etiket merkezi %s · giriş dikdörtgeni %s" % [str(label_at), str(entry.get_global_rect())])
		_c("A3 'GÜNLÜK' yazısına gerçek dokunuş da pencereyi açar (etiket ölü bölge değil)",
			_main._daily_rewards.visible and opens[0] == 2)
		if _main._daily_rewards.visible:
			await _back()
			await _wait_settled()

	# A4 — 300 ms yatışma (gizli kusur, inceleme bulgusu): açılışın hemen ardından KARARTMAYA düşen dokunuş pencereyi
	# kapatmaz; kapanışın hemen ardından GİRİŞE düşen dokunuş yeniden açmaz; ikisi de yatışmadan sonra çalışır (pozitif
	# kontrol). Sayaçlar göreli (A3'ün sonucu taşınmaz). Ekonomi aynen.
	var at: Vector2 = entry.get_global_rect().get_center()
	var base: int = opens[0]
	var dough_a4: int = SaveManager.dough()
	var daily_a4: Dictionary = (SaveManager.data.get("daily_rewards", {}) as Dictionary).duplicate(true)
	await _finger(_screen(at), true)
	await _finger(_screen(at), false)
	var popup: CanvasLayer = _main._daily_rewards
	var frame: Rect2 = (popup.call("frame") as Control).get_global_rect()
	var dim_at := Vector2(maxf(frame.position.x * 0.5, 8.0), frame.get_center().y)
	_c("A4 ön koşul: giriş açtı ve karartmada pencerenin dışında bir nokta var (%s, pencere %s)" % [str(dim_at),
		str(frame)], popup.visible and opens[0] == base + 1 and not frame.has_point(dim_at))
	await _tap_at(dim_at)
	_c("A4 açılışın HEMEN ardından karartmaya dokunuş yutuldu: pencere açık kaldı (çift dokunuş pencereyi kapatmaz)",
		popup.visible)
	await _wait_settled()
	await _tap_at(dim_at)
	_c("A4 (pozitif) yatışmadan sonra karartma dokunuşu pencereyi kapatır (UiKit sözleşmesi)", not popup.visible)
	await _tap(entry)
	_c("A4 kapanışın HEMEN ardından girişe dokunuş yutuldu: pencere yeniden AÇILMADI", not popup.visible
		and opens[0] == base + 1)
	# Her alt adım temiz durumdan başlar ve sayaçlar o adıma göreli (önceki adımın sonucu taşınmaz).
	await _close_daily_clean()
	var before: int = opens[0]
	await _finger(_screen(at), true)
	await _finger(_screen(at), false)
	await _finger(_screen(at), true)
	await _finger(_screen(at), false)
	await _settle(3)
	_c("A4 hızlı çift dokunuş (aynı nokta): pencere TEK ve açık", popup.visible and opens[0] == before + 1)
	_c("A4 ekonomi aynen (Hamur, günlük kota / talep durumu)", SaveManager.dough() == dough_a4
		and (SaveManager.data.get("daily_rewards", {}) as Dictionary) == daily_a4)
	await _close_daily_clean()
	before = opens[0]
	await _finger(_screen(at), true)
	await _cancel_finger(_screen(at))
	_c("A4 ACTION_CANCEL (bırakış canceled) → 0 açılış", not popup.visible and opens[0] == before)
	await _close_daily_clean()
	before = opens[0]
	await _tap(entry)
	_c("A4 iptalden sonra taze dokunuş tam bir kez açar (Ana Sayfa yeniden kullanılabilir)",
		popup.visible and opens[0] == before + 1)
	if _main._daily_rewards.visible:
		await _back()
	AdEvents.unsubscribe(counter)
	_sections_done += 1


# --- B: günlük kartının durumları -------------------------------------------------------------------------------------

func _daily_states() -> void:
	print("-- B: GÜNLÜK ÖDÜLLER kartı — yalnız gerçek durum")
	var today: String = Time.get_date_string_from_system()
	var specs: Array = [
		[{"onboarding_completed_day": THU}, &"locked", "Yarın açılır", false, false, "ilk gün (kural)"],
		[{"last_login_date": "2026-01-01"}, &"login", "Giriş ödülü hazır", true, true, "giriş ödülü bekliyor"],
		[{}, &"free_chest", "3 günlük seri · ücretsiz sandık hazır", true, true, "ücretsiz sandık hazır"],
		[{"daily_rewards": _daily_fixture(true, 1, false)}, &"free_taken", "3 günlük seri · bugünün sandığı alındı", true,
			false, "sandık alındı, reklamlı haklar duruyor"],
		[{"daily_rewards": _daily_fixture(true, 2, true)}, &"all_done", "3 günlük seri · bugünlük tamam",
			true, false, "bugünlük tamam"],
		[{"daily_streak": 0, "daily_rewards": _daily_fixture(true, 2, true)}, &"all_done",
			"Bugünlük tamam", true, false, "seri 0 → seri öneki yok (çıplak 0 yok), tek başına büyük harf"],
	]
	for spec: Array in specs:
		var extra: Dictionary = spec[0]
		await _boot(extra)
		if String(extra.get("last_login_date", today)) != today:
			# Açılışın giriş talebini geri al: kart "bekliyor" durumunu göstersin (Main açılışta zaten talep eder).
			SaveManager.data["last_login_date"] = "2026-01-01"
		var home: CanvasLayer = _main._screens[0]
		var bytes0: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		home.refresh()
		var card: FeatureCard = home.daily_card()
		var claim: bool = card.badge().visible and card.badge().text() == "!"
		_c("B %s: durum %s, alt yazı '%s', etkin=%s, '!' rozeti=%s" % [spec[5], String(home.daily_state()),
			card.subtitle_text(), str(card.is_enabled()), str(claim)], home.daily_state() == spec[1]
			and card.subtitle_text() == String(spec[2]) and card.is_enabled() == bool(spec[3]) and claim == bool(spec[4]))
		_c("B %s: kart yenilemesi kayıt dosyasını değiştirmez" % spec[5], FileAccess.get_file_as_bytes(PATH) == bytes0)
		var locked: bool = home.daily_state() == &"locked"
		_c("B %s: picto %s, › %s" % [spec[5], "kilit" if locked else "hediye", "gizli" if locked else "görünür"],
			card.art_texture() == UiKit.icon_texture("lock" if locked else "gift")
			and card.find_child("Chevron", true, false).visible == (not locked))
	_c("B kart başlığı GÜNLÜK ÖDÜLLER, gerçek pencere başlığıyla aynı aile (hediye pictosu, pembe kuyu)",
		(_main._screens[0].daily_card() as FeatureCard).title_text() == "GÜNLÜK ÖDÜLLER")
	# Ertesi güne öne dönüş: kilitli kart Ana Sayfa'dan ayrılmadan açılır (inceleme bulgusu — bayat kilit ölü düğme olurdu).
	await _boot({"onboarding_completed_day": THU})
	var home_r: CanvasLayer = _main._screens[0]
	var was_locked: bool = home_r.daily_state() == &"locked" and not home_r.daily_card().is_enabled()
	DailyRewards.clock_override = "2026-10-02"
	_main._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _settle(2)
	_c("B ertesi güne öne dönüş: kilit kendiliğinden açıldı (önce kilitli=%s, şimdi %s, etkin=%s)" % [str(was_locked),
		String(home_r.daily_state()), str(home_r.daily_card().is_enabled())], was_locked
		and home_r.daily_state() != &"locked" and home_r.daily_card().is_enabled()
		and home_r.daily_card().subtitle_text() != "Yarın açılır")
	DailyRewards.clock_override = THU
	_sections_done += 1


func _daily_fixture(free: bool, ad_chests: int, dough: bool) -> Dictionary:
	return {"day_key": THU, "free_chest_claimed": free, "ad_chests_claimed": ad_chests, "dough_ad_claimed": dough,
		"popup_seen_day": THU, "last_seen_day_key": THU}


# --- C: OYNA --------------------------------------------------------------------------------------------------------

func _play() -> void:
	print("-- C: OYNA — tek baskın CTA, tam bir gezinme")
	await _boot()
	var home: CanvasLayer = _main._screens[0]
	var play: SquishyButton = home.play_button()
	_c("C OYNA V3 SquishyButton PRIMARY HERO ('OYNA', ≥ %d px, GestureGuard'a ait)" % UiTokens.BUTTON_HEIGHT_HERO,
		play.kind() == SquishyButton.Kind.PRIMARY and play.title() == "OYNA"
		and play.get_global_rect().size.y >= float(UiTokens.BUTTON_HEIGHT_HERO) - 2.0
		and play.get_global_rect().size.x >= 420.0 and play.has_meta(&"gesture_guard"))
	var heroes: int = 0
	for node in home.find_children("*", "Button", true, false):
		if node is SquishyButton and (node as SquishyButton).size_class() == SquishyButton.SizeClass.HERO:
			heroes += 1
	_c("C Ana Sayfa'da tam BİR kahraman CTA (eşdeğer ağırlıkta ikinci CTA yok)", heroes == 1)
	var count: Array[int] = [0]
	home.play_pressed.connect(func() -> void: count[0] += 1)
	await _tap(play)
	_c("C taze dokunuş → Harita, tam BİR gezinme", count[0] == 1 and _main._active_tab == 1 and _main._screens[1].visible
		and not home.visible)
	await _tab(0)
	count[0] = 0
	var at: Vector2 = _screen(play.get_global_rect().get_center())
	await _finger(at, true)
	await _finger(at, false)
	await _finger(at, true)
	await _finger(at, false)
	await _settle(4)
	_c("C hızlı çift dokunuş → tek gezinme, Harita'da ikinci dokunuş level BAŞLATMAZ (300 ms yatışma)",
		count[0] == 1 and _main._active_tab == 1 and (_main._board == null or not is_instance_valid(_main._board)))
	await _tab(0)
	count[0] = 0
	await _finger(at, true)
	await _cancel_finger(at)
	_c("C ACTION_CANCEL → 0 gezinme, Ana Sayfa'da kalınır", count[0] == 0 and _main._active_tab == 0 and home.visible
		and not play.is_pressed_visual())
	await _wait_settled()
	var navs: int = int(_main.nav_navigations)
	await _tap(_main.global_nav().item_button(1))
	_c("C kabuğun merkez HARİTA'sı değişmedi: tam bir gezinme, OYNA sayacı oynamadı", int(_main.nav_navigations) == navs + 1
		and _main._active_tab == 1 and count[0] == 0)
	_sections_done += 1


# --- D: meydan okuma ------------------------------------------------------------------------------------------------

func _challenge() -> void:
	print("-- D: MEYDAN OKUMA kartı — gerçek özet, tam bir açılış")
	await _boot()
	var home: CanvasLayer = _main._screens[0]
	var card: FeatureCard = home.challenge_card()
	var view: Dictionary = DailyChallenge.current_view()
	_c("D kart görünür, GestureGuard'a ait, ≥ %d px" % UiTokens.TOUCH_TARGET, card.is_visible_in_tree()
		and card.has_meta(&"gesture_guard") and card.get_global_rect().size.y >= float(UiTokens.TOUCH_TARGET))
	_c("D gerçek özet: 'MEYDAN OKUMA' · '%s' · '+%d HAMUR' cipi · hedef portresi T%d" % [card.subtitle_text(),
		DailyChallenge.REWARD_DOUGH, int(view["target_tier"])], card.title_text() == DailyChallenge.TITLE
		and card.subtitle_text() == DailyChallenge.goal_text(view)
		and home.challenge_badge_text() == "+%d HAMUR" % DailyChallenge.REWARD_DOUGH
		and not home.is_challenge_done_shown()
		and home.challenge_portrait_texture() == home.DUMPLING_VISUAL.TEXTURES[int(view["target_tier"]) - 1])
	var opens: Array[int] = [0]
	_main._challenge_sheet.opened.connect(func() -> void: opens[0] += 1)
	await _tap(card)
	_c("D dokunuş → MEYDAN OKUMA penceresi tam BİR kez, kabuk gizli", _main._challenge_sheet.visible and opens[0] == 1
		and not _main.global_nav().visible)
	await _back()
	_c("D GERİ pencereyi kapatır, Ana Sayfa'da kalınır", not _main._challenge_sheet.visible and _main._active_tab == 0
		and home.visible and _main.global_nav().visible)
	await _wait_settled()
	var at: Vector2 = _screen(card.get_global_rect().get_center())
	await _finger(at, true)
	await _finger(at, false)
	await _finger(at, true)
	await _finger(at, false)
	await _settle(4)
	_c("D hızlı çift dokunuş → pencere TEK ve açık kalır (BAŞLA'ya düşmez, round yok)", opens[0] == 2
		and _main._challenge_sheet.visible and (_main._board == null or not is_instance_valid(_main._board)))
	await _back()
	await _wait_settled()
	await _finger(at, true)
	await _cancel_finger(at)
	_c("D ACTION_CANCEL → 0 açılış", opens[0] == 2 and not _main._challenge_sheet.visible)
	# Tamamlanmış gün: nane TAMAM cipi, kart yine açılır (pencere tamamlandı durumunu gösterir).
	await _boot({"daily_challenge": {"version": 1, "completed_day_key": DailyChallenge.current_day()}})
	home = _main._screens[0]
	card = home.challenge_card()
	_c("D tamamlandı: nane 'TAMAM' cipi, '+20 HAMUR' yok, alt yazı 'Bugün tamamlandı · yarın yenisi', kart etkin",
		home.is_challenge_done_shown() and home.challenge_badge_text() == "" and card.tag_text() == "TAMAM"
		and card.subtitle_text() == "Bugün tamamlandı · yarın yenisi" and card.is_enabled())
	await _tap(card)
	_c("D tamamlandı: dokunuş pencereyi yine açar", _main._challenge_sheet.visible)
	await _back()
	_sections_done += 1


# --- E: ikincil madalyonlar -----------------------------------------------------------------------------------------

func _medallions() -> void:
	print("-- E: GÖREVLER / SANDIK madalyonları — gövde VE etiket")
	await _boot()
	var home: CanvasLayer = _main._screens[0]
	var missions: HomeFeatureButton = home.missions_button()
	var chest: HomeFeatureButton = home.chest_button()
	_c("E iki madalyon HomeFeatureButton (GÖREVLER 0/6 · BONUS SANDIK 10/75 + altın halka), GestureGuard'a ait",
		missions.label_text() == "GÖREVLER" and home.missions_count_text() == "0/%d" % Missions.CATALOG.size()
		and chest.label_text() == "BONUS SANDIK" and chest.badge_text() == "10/%d" % ChestSystem.MERGES_PER_BONUS_CHEST
		and missions.has_meta(&"gesture_guard") and chest.has_meta(&"gesture_guard"))
	var opens: Array[int] = [0]
	_main._missions.opened.connect(func() -> void: opens[0] += 1)
	await _tap(missions)
	_c("E GÖREVLER gövdesi → GÖREVLER penceresi tam bir kez", _main._missions.visible and opens[0] == 1)
	await _back()
	await _wait_settled()
	var plaque: Rect2 = missions.plaque_rect_local()
	var label_at: Vector2 = missions.get_global_rect().position + plaque.get_center()
	_c("E etiket plakası madalyon dikdörtgeninin DIŞINA taşar (yazı ortası %.0f > alt %.0f)" % [label_at.y,
		missions.get_global_rect().end.y], label_at.y > missions.get_global_rect().end.y)
	await _tap_at(label_at)
	_c("E 'GÖREVLER' yazısına dokunuş da açar (etiket ölü bölge değil — TASK/058 inceleme bulgusu, madalyon ailesi)",
		_main._missions.visible and opens[0] == 2)
	await _back()
	await _wait_settled()
	var at: Vector2 = _screen(missions.get_global_rect().get_center())
	await _finger(at, true)
	await _cancel_finger(at)
	_c("E ACTION_CANCEL → 0 açılış", opens[0] == 2 and not _main._missions.visible)
	await _wait_settled()
	await _tap(chest)
	_c("E BONUS SANDIK → bonus sandık bilgisi (10/75), Ana Sayfa'da", _main._chest_info.visible
		and _main._chest_info.count_text() == "10/%d" % ChestSystem.MERGES_PER_BONUS_CHEST and _main._active_tab == 0)
	await _back()
	_c("E GERİ sandık bilgisini kapatır", not _main._chest_info.visible and home.visible)
	_sections_done += 1


# --- F: yinelenen kısayollar kaldırıldı --------------------------------------------------------------------------------

func _removed_shortcuts() -> void:
	print("-- F: kabukla yinelenen Ana Sayfa kısayolları YOK")
	await _boot()
	var home: CanvasLayer = _main._screens[0]
	_c("F Mağaza / Koleksiyon / Profil / Harita düğümleri yok (isim + AvatarButton)", home.find_child("Shop", true, false) == null
		and home.find_child("Collection", true, false) == null and home.find_child("Profile", true, false) == null
		and home.find_children("*", "AvatarButton", true, false).is_empty())
	_c("F Ana Sayfa'da shop / collection / profile / map sinyali yok", not home.has_signal(&"shop_requested")
		and not home.has_signal(&"collection_requested") and not home.has_signal(&"profile_requested")
		and not home.has_signal(&"map_requested"))
	_c("F feature_button: shop / collection → null (kabuk sahibi)", home.feature_button(&"shop") == null
		and home.feature_button(&"collection") == null)
	var dough: Control = home.dough_pill()
	_c("F Hamur pill'i DURUM: '+' kısayolu yok, buton yok", not dough.has_meta(&"add_button")
		and dough.find_children("*", "BaseButton", true, false).is_empty())
	_c("F oyuncu durumu ve level bilgisi DURUM: buton yok, fare almaz", home.player_status().find_children("*",
		"BaseButton", true, false).is_empty() and home.player_status().mouse_filter == Control.MOUSE_FILTER_IGNORE
		and home.level_info().mouse_filter == Control.MOUSE_FILTER_IGNORE
		and home.level_info().find_children("*", "BaseButton", true, false).is_empty())
	var buttons: Array[String] = []
	for node in home.find_children("*", "BaseButton", true, false):
		if (node as BaseButton).is_visible_in_tree():
			buttons.append(String(node.name))
	buttons.sort()
	_c("F etkileşimli öğe tam 5: %s" % str(buttons), buttons == ["Challenge", "Chest", "Daily", "Missions", "Play"])
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/home_screen.gd")
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_c("F kaynak: home_screen kısayol sinyali / AvatarButton / add düğmesi kurmuyor; Main bağlamıyor",
		not src.contains("signal shop_requested") and not src.contains("signal profile_requested")
		and not src.contains("signal collection_requested") and not src.contains("signal map_requested")
		and not src.contains("AvatarButton.new") and not src.contains("home_pill(UiIcons.DOUGH, \"\", true")
		and not main_src.contains("home.shop_requested") and not main_src.contains("home.profile_requested")
		and not main_src.contains("home.collection_requested") and not main_src.contains("home.map_requested"))
	for spec: Array in [[3, "MAĞAZA"], [2, "KOLEKSİYON"], [4, "PROFİL"]]:
		await _tab(0)
		var navs: int = int(_main.nav_navigations)
		await _tap(_main.global_nav().item_button(int(spec[0])))
		await _wait_settled()
		_c("F kabuk %s gerçek dokunuşla tam bir gezinme (rota korunuyor)" % spec[1],
			int(_main.nav_navigations) == navs + 1 and _main._active_tab == int(spec[0]) and _main._screens[int(spec[0])].visible)
	# K9 (owner, TASK/058 son tur): Ana Sayfa terimleri — oyuncu seviyesi "SV. N", sıradaki harita bölümü "SIRADAKİ BÖLÜM N";
	# Ana Sayfa'da İngilizce "LV." / "Level N" görünmez; sonsuz kip anlamı aynen.
	await _tab(0)
	_c("F K9 oyuncu seviyesi rozeti 'SV.' + seviye sayısı (PlayerProfile) — 'LV.' değil", home.status_caption_text() == "SV."
		and home.status_level() == PlayerProfile.player_level())
	_c("F K9 harita ilerlemesi 'SIRADAKİ' + 'BÖLÜM 5' (fikstür: sıradaki bölüm 5)", home.level_caption_text() == "SIRADAKİ"
		and home.level_title_text() == "BÖLÜM 5")
	var leaks: Array[String] = []
	for node in home.find_children("*", "Label", true, false):
		var label: Label = node
		if label.is_visible_in_tree() and (label.text == "LV." or label.text.begins_with("Level ")):
			leaks.append(label.text)
	_c("F K9 Ana Sayfa'da görünen 'LV.' / 'Level N' yok %s" % str(leaks), leaks.is_empty())
	_c("F K9 kaynak: home_screen 'Level %d' biçimi kullanmıyor, 'BÖLÜM %d' + 'SV.' sabitleri var",
		not src.contains("\"Level %d\"") and src.contains("\"BÖLÜM %d\"") and src.contains("\"SV.\""))
	await _boot({"highest_level_unlocked": 11, "level_stars": {"1": 3, "2": 3, "3": 3, "4": 3, "5": 3, "6": 3, "7": 3,
		"8": 3, "9": 3, "10": 3}, "endless_high_score": 12480})
	home = _main._screens[0]
	_c("F K9 sonsuz kip anlamı aynen: 'SONSUZ MOD' · 'Rekor 12 480' · 30/30; rozet yine 'SV.'",
		home.level_caption_text() == "SONSUZ MOD" and home.level_title_text() == "Rekor 12 480"
		and home.level_stars_text() == "30/30" and home.status_caption_text() == "SV.")
	_sections_done += 1


# --- G: yerleşim matrisi --------------------------------------------------------------------------------------------

func _layout_matrix() -> void:
	print("-- G: yerleşim — kabuk / banner / güvenli pay / dar ekran")
	var mascot_img: Image = (load("res://assets/visual/ui/hero_mascot.png") as Texture2D).get_image()
	for spec: Array in [[Vector2i(720, 1280), 0.0, 0.0, "720×1280"], [Vector2i(720, 1280), 0.0, A36_SLOT, "16:9 + banner 112"],
			[Vector2i(720, 1280), 0.0, 128.0, "16:9 + banner 128 (en dar)"], [Vector2i(720, 1600), 0.0, 0.0, "720×1600"],
			[Vector2i(720, 1560), A36_SAFE_TOP, 0.0, "A36 benzeri (üst 61), banner yok"],
			[Vector2i(720, 1560), A36_SAFE_TOP, A36_SLOT, "A36 benzeri (üst 61) + banner 112"],
			[Vector2i(960, 1280), 0.0, 0.0, "geniş tuval 960×1280"]]:
		get_window().size = spec[0]
		UiKit.set_banner_slot(float(spec[2]))
		await _boot()
		for screen: CanvasLayer in _main._screens:
			if screen.has_method("_layout_with_safe_top"):
				screen._layout_with_safe_top(float(spec[1]))
		_main._on_banner_slot_changed(float(spec[2]))
		await _settle(3)
		await _check_layout(String(spec[3]), float(spec[1]), mascot_img)
	get_window().size = Vector2i(720, 1280)
	UiKit.set_banner_slot(0.0)
	_sections_done += 1


func _check_layout(tag: String, safe_top: float, mascot_img: Image) -> void:
	await get_tree().process_frame
	var home: CanvasLayer = _main._screens[0]
	var nav: GlobalNav = _main.global_nav()
	var view: Vector2 = home.get_viewport().get_visible_rect().size
	var floor_y: float = nav.footprint().position.y
	var slot_top: float = view.y - UiKit.bottom_inset(view)
	var play: Rect2 = home.play_button().get_global_rect()
	var level: Rect2 = home.level_info().get_global_rect()
	var daily: Rect2 = home.daily_card().get_global_rect()
	var challenge: Rect2 = home.challenge_card().get_global_rect()
	var missions: Rect2 = home.missions_button().visual_rect()
	var chest: Rect2 = home.chest_button().visual_rect()
	var status: Rect2 = home.player_status().get_global_rect()
	var dough: Rect2 = home.dough_pill().get_global_rect()
	var logo: Rect2 = home.logo().get_global_rect()
	var mascot: Rect2 = home.mascot_rect()
	var rects: Array = [["OYNA", play], ["level", level], ["Günlük", daily], ["Meydan", challenge], ["Görevler", missions],
		["Sandık", chest], ["durum", status], ["Hamur", dough]]
	var inside: bool = true
	for pair: Array in rects:
		var r: Rect2 = pair[1]
		if r.position.y < safe_top - 0.5 or r.end.y > floor_y + 0.5 or r.end.y > slot_top + 0.5 or r.position.x < -0.5 \
				or r.end.x > view.x + 0.5:
			inside = false
			print("    dışarıda: %s %s (kabuk üstü %.0f, yuva üstü %.0f)" % [pair[0], str(r), floor_y, slot_top])
	_c("G %s: her öğe güvenli payın altında, kabuğun ayak izinin (%.0f) ve banner yuvasının üstünde" % [tag, floor_y], inside)
	var overlap: bool = false
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var inter: Rect2 = (rects[i][1] as Rect2).intersection(rects[j][1] as Rect2)
			if inter.size.x > 1.0 and inter.size.y > 1.0:
				overlap = true
				print("    çakışma: %s %s × %s %s" % [rects[i][0], str(rects[i][1]), rects[j][0], str(rects[j][1])])
	_c("G %s: OYNA / level / kartlar / madalyonlar / üst satır çakışmıyor" % tag, not overlap)
	_c("G %s: sıra — level bilgisi → OYNA → GÜNLÜK → MEYDAN OKUMA → kabuk" % tag, level.end.y <= play.position.y
		and play.end.y < daily.position.y and daily.end.y < challenge.position.y and challenge.end.y <= floor_y)
	_c("G %s: OYNA ile kabuğun merkez HARİTA'sı bitişik değil — arada iki kart (%.0f px)" % [tag, floor_y - play.end.y],
		floor_y - play.end.y >= 2.0 * FeatureCard.HEIGHT)
	_c("G %s: OYNA yatayda ortalı, ≥ 420 px geniş" % tag, absf(play.get_center().x - view.x * 0.5) <= 2.0 and play.size.x >= 420.0)
	var tray_top: float = nav.tray_rect().position.y
	_c("G %s: kartlar tepsinin üst kenarından ≥ 28 px yukarıda (kompakt=%s, ara %.0f) — seçili madalyon / dock solması karta binmez"
		% [tag, str(nav.is_compact()), tray_top - challenge.end.y], tray_top - challenge.end.y >= 28.0)
	_c("G %s: dokunma hedefleri — OYNA / kartlar ≥ %d yükseklik, madalyonlar ≥ %d" % [tag, UiTokens.TOUCH_TARGET,
		UiTokens.TOUCH_TARGET], play.size.y >= UiTokens.TOUCH_TARGET and daily.size.y >= UiTokens.TOUCH_TARGET
		and challenge.size.y >= UiTokens.TOUCH_TARGET and home.missions_button().get_global_rect().size.y >= UiTokens.TOUCH_TARGET
		and home.chest_button().get_global_rect().size.x >= UiTokens.TOUCH_TARGET)
	var hits: bool = _mascot_hits(mascot_img, mascot, missions) or _mascot_hits(mascot_img, mascot, chest)
	_c("G %s: madalyonlar (plaka dahil) maskotun opak pikselleriyle çakışmıyor" % tag, not hits)
	_c("G %s: maskot baskın (%.0f px) ve level bilgisinin üstünde, logonun altında" % [tag, mascot.size.y],
		mascot.size.y >= 340.0 and mascot.end.y <= level.position.y + 1.0 and mascot.position.y >= logo.position.y)
	_c("G %s: logo üst satırın altında, madalyonların üstünde" % tag, logo.position.y >= maxf(status.end.y, dough.end.y)
		and logo.end.y <= missions.position.y + 1.0 and logo.end.y <= chest.position.y + 1.0)
	_c("G %s: üst satır ortak optik merkez (±3 px)" % tag, absf(status.get_center().y - dough.get_center().y) <= 3.0)
	var sides_clear: bool = true
	for side: Control in home._sides:
		if side.get_global_rect().intersects(level) or side.get_global_rect().intersects(play):
			sides_clear = false
	_c("G %s: yan dumpling'ler level bilgisinin / OYNA'nın arkasına inmez" % tag, sides_clear)
	var small: Array[String] = []
	for node in home.find_children("*", "Label", true, false):
		var label: Label = node
		if label.is_visible_in_tree() and not label.text.is_empty() and label.get_theme_font_size("font_size") < UiTokens.TYPE_META:
			small.append("%s=%d" % [label.text, label.get_theme_font_size("font_size")])
	_c("G %s: görünen yazı ≥ %d px %s" % [tag, UiTokens.TYPE_META, str(small)], small.is_empty())
	var trimmed: Array[String] = []
	for card: FeatureCard in [home.daily_card(), home.challenge_card()]:
		for node in card.find_children("*", "Label", true, false):
			var label: Label = node
			if not label.is_visible_in_tree() or label.text.is_empty():
				continue
			var font: Font = label.get_theme_font("font")
			var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				label.get_theme_font_size("font_size")).x
			if width > label.size.x + 0.5:
				trimmed.append("%s (%.0f > %.0f)" % [label.text, width, label.size.x])
	_c("G %s: kart yazıları kırpılmadan sığar %s" % [tag, str(trimmed)], trimmed.is_empty())
	# En uzun unvan (katalog) üst satırda kırpılmaz; ölçü sonrası gerçek unvana dönülür.
	var longest: String = ""
	for row: Dictionary in AchievementCatalog.TITLES:
		if String(row["name"]).length() > longest.length():
			longest = String(row["name"])
	var title_label: Label = home._status_title
	title_label.text = longest
	home._layout()
	await _settle(1)
	var title_w: float = title_label.get_theme_font("font").get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		title_label.get_theme_font_size("font_size")).x
	_c("G %s: en uzun unvan '%s' (%.0f px) üst satırda kırpılmaz (%.0f px), Hamur pill'ine değmez" % [tag, longest,
		title_w, title_label.size.x], title_w <= title_label.size.x + 0.5
		and home.player_status().get_global_rect().end.x < home.dough_pill().get_global_rect().position.x - 8.0)
	home.refresh()


## Madalyon dikdörtgeni ile maskot sanatının opak pikselleri kesişiyor mu?
func _mascot_hits(img: Image, mascot: Rect2, rect: Rect2) -> bool:
	var inter: Rect2 = mascot.intersection(rect)
	if inter.size.x <= 0.0 or inter.size.y <= 0.0:
		return false
	var kx: float = float(img.get_width()) / mascot.size.x
	var ky: float = float(img.get_height()) / mascot.size.y
	var y: float = inter.position.y
	while y < inter.end.y:
		var x: float = inter.position.x
		while x < inter.end.x:
			var px: int = clampi(int((x - mascot.position.x) * kx), 0, img.get_width() - 1)
			var py: int = clampi(int((y - mascot.position.y) * ky), 0, img.get_height() - 1)
			if img.get_pixel(px, py).a > 0.15:
				return true
			x += 3.0
		y += 3.0
	return false


# --- H: teklif yuvası (TASK/062 sözleşmesi) ---------------------------------------------------------------------------

func _offer_slot() -> void:
	print("-- H: Başlangıç Paketi yuvası — bugün boş, yer kaplamaz")
	get_window().size = Vector2i(720, 1560)
	UiKit.set_banner_slot(0.0)
	await _boot()
	var home: CanvasLayer = _main._screens[0]
	var slot: Control = home.offer_slot()
	_c("H yuva var, GİZLİ ve BOŞ (sahte teklif / süre / fiyat yok), fare almaz", slot != null and not slot.visible
		and slot.get_child_count() == 0 and slot.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var offers: int = home.find_children("*", "OfferCard", true, false).size()
	var texts: String = _texts(home)
	_c("H Ana Sayfa'da OfferCard / 'BAŞLANGIÇ PAKETİ' / 'KALDI' / fiyat metni yok", offers == 0
		and not texts.contains("BAŞLANGIÇ") and not texts.contains("KALDI") and not texts.contains("₺"))
	var challenge_before: Rect2 = home.challenge_card().get_global_rect()
	var probe := Control.new()
	probe.custom_minimum_size = Vector2(0.0, 220.0)
	slot.add_child(probe)
	slot.visible = true
	# Ayrı yerleşim çağrısı YOK: yuva kendini korur (görünürlük / çocuk değişimi → ertelenmiş yerleşim).
	await _settle(2)
	var offer: Rect2 = slot.get_global_rect()
	var floor_y: float = _main.global_nav().footprint().position.y
	var challenge: Rect2 = home.challenge_card().get_global_rect()
	_c("H sözleşme: 220 px içerik kartlarla kabuk arasına girer, kartlar 220 + %d px yukarı kayar, çakışma yok" %
		int(home.OFFER_GAP), offer.end.y <= floor_y and offer.position.y >= challenge.end.y
		and is_equal_approx(challenge_before.position.y - challenge.position.y, 220.0 + home.OFFER_GAP)
		and home.play_button().get_global_rect().end.y < home.daily_card().get_global_rect().position.y
		and home.mascot_rect().size.y >= 300.0)
	slot.remove_child(probe)
	probe.free()
	slot.visible = false
	await _settle(2)
	_c("H içerik kalkınca yerleşim aynen geri döner", home.challenge_card().get_global_rect().position.is_equal_approx(
		challenge_before.position))
	get_window().size = Vector2i(720, 1280)
	_sections_done += 1


# --- I: kalıcılık ---------------------------------------------------------------------------------------------------

func _persistence() -> void:
	print("-- I: Ana Sayfa girişlerini açıp kapatmak kaydı değiştirmez")
	await _boot()
	var home: CanvasLayer = _main._screens[0]
	var bytes0: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var data0: Dictionary = SaveManager.data.duplicate(true)
	for entry: Control in [home.daily_card(), home.challenge_card(), home.missions_button(), home.chest_button()]:
		await _tap(entry)
		await _back()
		await _wait_settled()
		home.refresh()
	_main._show_tab(0)
	await _settle(2)
	_c("I dört pencere açıldı / kapandı: kayıt dosyası bayt-aynı", FileAccess.get_file_as_bytes(PATH) == bytes0)
	_c("I bellek kaydı da aynı (Hamur / seri / günlük / görev / meydan okuma)", SaveManager.data == data0)
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/home_screen.gd")
	_c("I home_screen save_game / add_dough / grant_ / claim çağırmıyor", not src.contains("save_game(")
		and not src.contains("add_dough(") and not src.contains("grant_") and not src.contains("claim_"))
	var quits: int = int(_main.quit_requests)
	await _back()
	_c("I Ana Sayfa'da pencere yokken GERİ → çıkış isteği (sözleşme değişmedi)", int(_main.quit_requests) == quits + 1)
	_sections_done += 1


func _tab(index: int) -> void:
	_main._show_tab(index)
	await _wait_settled()


# --- Yardımcılar --------------------------------------------------------------------------------------------------

## Günlük pencere açıksa kod yolundan kapatır, yatışma penceresini bekler (sonraki dokunuş temiz başlar).
func _close_daily_clean() -> void:
	if _main._daily_rewards.visible:
		_main._daily_rewards.close_popup()
	await _wait_settled()


## Ana Sayfa'nın Günlük girişi — sürümden bağımsız: adıyla ("Daily").
func _daily_node(home: Node) -> Control:
	return home.find_child("Daily", true, false) as Control


func _class_of(node: Node) -> String:
	var script: Script = node.get_script()
	if script != null and not script.get_global_name().is_empty():
		return script.get_global_name()
	return node.get_class()


## Girişin görünen tüm yazıları (" | " ile).
func _texts(root: Node) -> String:
	var out: PackedStringArray = PackedStringArray()
	for label in root.find_children("*", "Label", true, false):
		var l: Label = label
		if l.is_visible_in_tree() and not l.text.is_empty():
			out.append(l.text)
	return " | ".join(out)


func _label_with(root: Node, prefix: String) -> Label:
	for label in root.find_children("*", "Label", true, false):
		var l: Label = label
		if l.is_visible_in_tree() and l.text.begins_with(prefix):
			return l
	return null


func _fixture(extra: Dictionary = {}) -> Dictionary:
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 2},
		"endless_high_score": 640, "dough": 900, "total_merges": 40, "merges_since_bonus_chest": 10,
		"unlocked_skins": ["common_01", String(SHOWCASE_ID)], "profile_showcase": [String(SHOWCASE_ID)],
		"powerups": {"bomb": 0, "upgrade": 2, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "", "daily_streak": 3,
		"last_login_date": Time.get_date_string_from_system(), "age_ad_band": "ADULT", "next_age_transition_date": "",
		"player_meta_version": 1, "player_xp": 400, "total_rounds_played": 12, "highest_tier_created": 4,
		"unlocked_achievements": ["merge_10"], "daily_challenge": {"version": 1, "completed_day_key": ""},
		"daily_rewards": {"day_key": THU, "free_chest_claimed": false, "ad_chests_claimed": 0,
			"dough_ad_claimed": false, "popup_seen_day": THU, "last_seen_day_key": THU},
		"missions": {"version": 1, "day_key": THU, "week_start_day_key": MON,
			"daily_progress": {"daily_merges": 5, "daily_rounds": 0, "daily_clear": 0}, "daily_rewarded": [],
			"weekly_progress": {"weekly_merges": 30, "weekly_rounds": 4, "weekly_clears": 2}, "weekly_rewarded": []}}
	for key: String in extra:
		content[key] = extra[key]
	return content


## Temiz kayıt + Main (Ana Sayfa).
func _boot(extra: Dictionary = {}) -> void:
	await _teardown_main()
	_clean()
	DailyRewards.clock_override = THU
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(_fixture(extra), "\t"))
	file.close()
	SaveManager.load_game()
	_main = MAIN_SCENE.instantiate()
	_main.set("quit_suppressed", true)
	add_child(_main)
	await _settle(3)
	_main.set("quit_suppressed", true)
	await _wait_settled()


func _touch_event(pos: Vector2, pressed: bool, index: int) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = pos
	touch.pressed = pressed
	return touch


func _finger(pos: Vector2, pressed: bool, index: int = 0) -> void:
	Input.parse_input_event(_touch_event(pos, pressed, index))
	Input.flush_buffered_events()
	await get_tree().process_frame


func _tap(control: Control) -> void:
	await _tap_at(control.get_global_rect().get_center())


## Tuval noktasına gerçek dokunuş (basış + bırakış).
func _tap_at(canvas: Vector2) -> void:
	var pos: Vector2 = _screen(canvas)
	await _finger(pos, true)
	await _finger(pos, false)
	await _settle(3)


## Android ACTION_CANCEL: bırakış `canceled == true`.
func _cancel_finger(pos: Vector2, index: int = 0) -> void:
	var cancel := _touch_event(pos, false, index)
	cancel.canceled = true
	Input.parse_input_event(cancel)
	Input.flush_buffered_events()
	await _settle(2)


func _window_notify(what: int) -> void:
	_notify_tree(get_tree().root, what)


func _notify_tree(node: Node, what: int) -> void:
	node.notification(what)
	var i: int = 0
	while i < node.get_child_count(true):
		var child: Node = node.get_child(i, true)
		if not (child is Window):
			_notify_tree(child, what)
		i += 1


## Android geri (Main'in 250 ms debounce'u gerçek saatle).
func _back() -> void:
	var gap: int = maxi(_last_back_msec + BACK_GAP_MSEC, int(_main.get("_last_back_msec")) + BACK_GAP_MSEC) \
		- Time.get_ticks_msec()
	if gap > 0:
		await get_tree().create_timer(float(gap) / 1000.0).timeout
	_last_back_msec = Time.get_ticks_msec()
	_window_notify(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(1)


func _screen(canvas: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * canvas


func _wait_settled() -> void:
	await get_tree().create_timer(0.45).timeout
	await _settle(1)


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _settle(2)


func _teardown() -> void:
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
