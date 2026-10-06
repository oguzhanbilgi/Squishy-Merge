extends Node
## TASK/054 — Koleksiyon basılı dokunuş + Android GERİ: bir dokunuş yalnız basışın başladığı ve HÂLÂ ekranda olan
## Koleksiyon yüzeyine (albüm / detay penceresi / üst çubuk) aittir. GERİ, sekme değişimi, detay kapanışı ya da
## ACTION_CANCEL o yüzeyi geçersiz kılınca bayat bırakış HİÇBİR eylem üretmez (detay açılmaz, vitrine yazılmaz,
## Mağaza'ya / Ana Sayfa'ya gidilmez); asılı basış biter; sonraki taze dokunuş tam bir kez çalışır.
## Gerçek Main, gerçek ekranlar, gerçek parmak olayları (`Input.parse_input_event`, Android'deki gibi öykünülen fare).
## Headless.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_collection_hold/` altındaki bir yola
## yönlendirilir, sonda geri alınır; gerçek kayıt ailesi (kanonik + .tmp + .bak) başta / sonda bayt bayt karşılaştırılır.
##   godot --headless --audio-driver Dummy --path . res://tools/collection_hold_back_test.tscn
##
## Kök neden (taban 6a4a2b2; Godot 4.6.3 kaynağıyla doğrulandı): basılı bir düğme gizlenince (`Viewport::_gui_hide_control`
## → `_drop_mouse_focus`) — ya da pencere odağı gidince (FOCUS_OUT, aynı düşürme) — motor ona iç aygıtlı sentetik bir
## bırakış yollar; bu bırakış — son gerçek girdi işlenmemişse (cihazda GERİ tuşunun kendisi / bir ses tuşu; masaüstünde
## PASS kartta parmak titremesi) — BaseButton'a ulaşır ve `pressed` sayılır. BaseButton iptal edilen (ACTION_CANCEL)
## bırakışı da `pressed` sayar; paylaşılan karartma kapanışı da iptali ayırt etmez. Koleksiyon'un `pressed`
## işleyicileri dokunuşun sahibine bakmıyordu: gizli albümde detay açılıyor (yeniden açılışta ekranda bekliyor, ilk taze
## dokunuşu yutuyor, Ana Sayfa'nın günlük penceresini bastırıyor), kapanan detayın VİTRİNE EKLE / VİTRİNDEN ÇIKAR'ı
## kayda yazıyor, MAĞAZAYA GİT / üst çubuk "+" GERİ'den sonra Mağaza'ya gidiyordu. Bırakış düştüğünde ise BaseButton'ın
## basılı durumu asılı kalıyor, sonraki basış button_down (dokunuş sesi / basış ölçeği) yaymıyordu.
##
## Bölümler:
##   A kart + GERİ   basılı kart → GERİ → bırak (olay yok / işlenmeyen olay / parmak titremesi): detay açılmaz (gizlide
##                   de, bırakışta da), Ana Sayfa'da kalınır, yeniden açılışta bayat detay yok; pozitif kontrol: basış
##                   karta ulaştı, GERİ gerçekten çıktı
##   B kart + geçiş  basılı kart → sekme değişimi (Mağaza, Profil) → bırak: 0 eylem
##   C detay         birincil (VİTRİNE EKLE / MAĞAZAYA GİT), ikincil (VİTRİNDEN ÇIKAR), değiştirme kutusu, X basılı + GERİ
##                   → bırak: yazma yok, gezinme yok, yeniden açılış yok
##   D İPTAL         ACTION_CANCEL bırakışı: kart, birincil, ikincil, kutu, kabuk ANA SAYFA / üst çubuk "+", detay X,
##                   karartma → 0 eylem, basış biter; karartmada İPTAL + GERİ (hareketli gezinme geri kaydırması) → tek
##                   gezinme (TASK/057 Tur 2: üst çubukta geri oku yok — Ana Sayfa rotası küresel kabuğun ANA SAYFA öğesi)
##   E İPTAL + UP    iptalden sonra bayat UP (motor dokunuş odağını iptalde bırakmıştı) → 0 eylem; ardından taze dokunuş
##                   tam bir kez (kart, karartma)
##   F taze          bayat diziden sonra yeniden aç → AYNI karta taze dokunuş tam 1 detay (button_down 1), sonra da tek
##   G sıra          öykünülen fare + dokunuş sırası: normal dokunuş tek seçim, gerçek bırakış gui_input'ta `pressed`'ten
##                   ÖNCE (sahiplik kaydının dayandığı sıra); bayat dizide öykünülen bırakış karta hiç ulaşmaz
##   H çok parmak    ikinci parmak GUI düğmesine basamaz (fare öykünmesi yalnız 0. parmak); kartı tutan parmak GERİ'den
##                   sonra kalkarsa 0 eylem, GERİ'siz kalkarsa normal tek seçim
##   I hızlı GERİ    birincil basılı → GERİ (detay) → GERİ (Ana Sayfa) → bırak: tek kapanış, tek gezinme, 0 eylem
##   J basılı durum  gizlenen basılı düğmenin basışı biter: sonraki taze basış button_down yayar (kart, üst çubuk "+",
##                   birincil, kutu, detay X), ölçek 1.0. STOP düğmelerde motorun gizleme bırakışı deterministik DÜŞER
##                   (asılı durumu en iyi bunlar sınar); PASS kartta olay ScrollContainer'a da geçer → bırakışın düşüp
##                   düşmemesi motor durumuna bağlı. Kaydırmaya geçmiş kart + GERİ: koruma kontrolü (headless'ta dokunmatik
##                   ekran yok → gerçek sürükleme yok, bırakış tabanda da işlenir)
##   K kayıt         bayat dizilerden sonra Hamur / vitrin / açık parçalar bellekte ve diskte aynı
##   L normal        tek dokunuş tam bir kez: kart → detay, birincil → vitrine ekler, ikincil → çıkarır, kutu → değiştirir,
##                   kabuk ANA SAYFA → Ana Sayfa, üst çubuk "+" → Mağaza, detay X / karartma → kapanır; üst çubukta geri
##                   oku yok (TASK/057 Tur 2)
##   M gezinme       GERİ: detay → kapanır (Koleksiyon'da kalınır), değiştirme adımı → detaya, detay yok → Ana Sayfa;
##                   Ana Sayfa madalyonu → Koleksiyon
##   O odak kaybı    basılı düğmede pencere odağı gider (Android onPause): kart (önceki normal dokunuştan sonra), STOP
##                   birincil (bırakış düşer → basış odak kaybında biter / bırakış ulaşır → eylemsiz) → 0 eylem, taze
##                   dokunuş tam bir kez
##   R günlük pencere bugün gösterilmemişken basılı kart + GERİ → Ana Sayfa'da pencere normal açılır, bayat kalkış
##                   pencereye dokunmaz
##   S sahiplik      gizli düğmeye ulaşan `pressed` eylem üretmez: gizli albümde kart, üst çubuk "+"; detay
##                   KAPANIRKEN (düğmenin kendi gizlenme bildirimi, detay id'si / değiştirme adımı hâlâ dururken) VİTRİNE
##                   EKLE, MAĞAZAYA GİT, VİTRİNDEN ÇIKAR, değiştirme kutusu
##   P kaynak        sözleşme (bağlama, korumalar, basış bitirme, paylaşılan yardımcılar)
##   N kayıt         sahibin kayıt ailesi bayt-aynı

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_collection_hold"
const PATH: String = DIR + "/save.json"
const SECTIONS: int = 16
const MON: String = "2026-09-28"
const THU: String = "2026-10-01"
const BACK_GAP_MSEC: int = 320
const OWNED: StringName = &"common_01"
const OTHER: StringName = &"rare_02"
const LOCKED: StringName = &"epic_01"

var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _finished: bool = false
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _main: Node2D
## Sayaçlar ("etiket.sinyal" / albüm sinyalleri) — `_mark` sıfırlar.
var _n: Dictionary = {}
## Sıralı olay kaydı ("ad@+ms") — `_mark` sıfırlar.
var _events: Array[String] = []
var _t0: int = 0
var _last_back_msec: int = -100000
## `_main.nav_navigations` son `_mark` / `_open_fresh` anında (TASK/057 Tur 2).
var _nav_mark: int = 0


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
	get_tree().create_timer(420.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 420 s'de bitmedi — SaveManager geri alındı")
			if _main != null and is_instance_valid(_main):
				_main.free()
			_teardown()
			get_tree().quit(2))
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame

	await _card_back()
	await _card_transition()
	await _detail_back()
	await _cancel()
	await _cancel_then_up()
	await _fresh_after_stale()
	await _ordering()
	await _multi_touch()
	await _rapid_back()
	await _hold_state()
	await _economy()
	await _normal_taps()
	await _navigation()
	await _focus_out()
	await _daily_popup()
	await _hidden_pressed()
	_source_contract()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	print("-- N: kayıt")
	await _teardown_main()
	_teardown()
	_c("SaveManager gerçek yola döndü, test klasörü silindi, saat kancası boş",
		SaveManager.save_path == SaveManager.SAVE_PATH and not DirAccess.dir_exists_absolute(DIR)
		and DailyRewards.clock_override == "")
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
	DailyRewards.clock_override = ""
	DailyRewards.auto_popup_enabled = false
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data.duplicate(true)
	AudioManager.set_sfx_enabled(SaveManager.sfx_enabled())
	Haptics.set_enabled(SaveManager.haptics_enabled())
	UiKit.set_banner_slot(0.0)
	_clean()
	if DirAccess.dir_exists_absolute(DIR):
		DirAccess.remove_absolute(DIR)


# --- A) Kart + GERİ ------------------------------------------------------------------------------------------------

func _card_back() -> void:
	print("-- A: basılı kart → Android GERİ → bırak: detay açılmaz, Ana Sayfa'da kalınır, yeniden açılışta bayat detay yok")
	for mode: String in ["none", "event", "jitter"]:
		var album: CanvasLayer = await _open_fresh()
		var card: Button = album.card(OWNED)
		_watch(card, "card")
		var econ: Dictionary = _econ()
		var pos: Vector2 = _center(card)
		_mark()
		await _hold(pos, mode)
		var reached: bool = _n.get("card.down", 0) == 1 and album.visible and not album.is_detail_open()
		await _back()
		_record("A[%s] GERİ" % mode, album)
		var at_back: bool = not album.is_detail_open() and _n.get("detail_opened", 0) == 0 and _main._active_tab == 0 \
			and not album.visible
		await _finger(pos, false)
		await _settle(3)
		_record("A[%s] bırakış" % mode, album)
		_c("A[%s] kurulum: basış karta ulaştı (button_down 1), GERİ Koleksiyon'dan Ana Sayfa'ya çıktı" % mode,
			reached and _main._active_tab == 0)
		_c("A[%s]: GERİ anında (gizlenirken) detay AÇILMADI, detail_opened 0, Ana Sayfa'da" % mode, at_back)
		_c("  … A[%s]: parmak kalkınca da detay yok, seçim / detay açılışı 0, kayıt aynı" % mode, not album.is_detail_open()
			and _n.get("detail_opened", 0) == 0 and _main._active_tab == 0 and _econ() == econ)
		_main._show_tab(2)
		await _wait_settled()
		_c("  … A[%s]: Koleksiyon yeniden açıldı — bayat detay EKRANDA DEĞİL (detay kapalı, id boş)" % mode, album.visible
			and not album.is_detail_open() and album.detail_id() == &"")
	_sections_done += 1


# --- B) Kart + geçiş -----------------------------------------------------------------------------------------------

func _card_transition() -> void:
	print("-- B: basılı kart → sekme değişimi (Mağaza / Profil) → bırak: 0 eylem")
	for target: int in [3, 4]:
		var album: CanvasLayer = await _open_fresh()
		var card: Button = album.card(OWNED)
		_watch(card, "card")
		var pos: Vector2 = _center(card)
		_mark()
		await _hold(pos, "event")
		_main._show_tab(target)
		await _settle(1)
		_record("B→%d geçiş" % target, album)
		var at_switch: bool = not album.is_detail_open() and _n.get("detail_opened", 0) == 0 and not album.visible
		await _finger(pos, false)
		await _settle(3)
		_c("B→%d: basılı kart (button_down 1) gizlenince detay açılmadı; parmak kalkınca da 0 eylem, sekme %d" % [target, target],
			_n.get("card.down", 0) == 1 and at_switch and not album.is_detail_open() and _n.get("detail_opened", 0) == 0
			and _main._active_tab == target)
	_sections_done += 1


# --- C) Detay penceresi -------------------------------------------------------------------------------------------

func _detail_back() -> void:
	print("-- C: detay düğmesi basılı → GERİ (detay kapanır) → bırak: yazma yok, gezinme yok, yeniden açılış yok")
	# C1 — sahip olunan, vitrinde olmayan parça: VİTRİNE EKLE.
	for mode: String in ["none", "event"]:
		var album: CanvasLayer = await _open_fresh()
		await _open_detail(album, OWNED)
		var primary: Button = album.detail_primary()
		_watch(primary, "primary")
		var label: String = album.detail_primary_text()
		var econ: Dictionary = _econ()
		var pos: Vector2 = _center(primary)
		_mark()
		await _hold(pos, mode)
		var reached: bool = _n.get("primary.down", 0) == 1 and album.is_detail_open()
		await _back()
		_record("C1[%s] GERİ" % mode, album)
		var at_back: bool = not album.is_detail_open() and album.visible and _main._active_tab == 2 and _econ() == econ
		await _finger(pos, false)
		await _settle(3)
		_c("C1[%s] kurulum: '%s' basılı (button_down 1), GERİ detayı kapattı, Koleksiyon'da kalındı" % [mode, label],
			reached and label == "VİTRİNE EKLE" and at_back)
		_c("  … C1[%s]: bırakışta vitrine YAZILMADI (bellek + disk aynı), detay yeniden açılmadı" % mode, _econ() == econ
			and not album.is_detail_open() and _n.get("detail_opened", 0) == 0 and _main._active_tab == 2)
	# C2 — kilitli parça: MAĞAZAYA GİT.
	var album: CanvasLayer = await _open_fresh()
	await _open_detail(album, LOCKED)
	var primary: Button = album.detail_primary()
	_watch(primary, "primary")
	var label: String = album.detail_primary_text()
	var pos: Vector2 = _center(primary)
	_mark()
	await _hold(pos, "event")
	await _back()
	await _finger(pos, false)
	await _settle(3)
	_c("C2: kilitli parça '%s' basılı (button_down 1) + GERİ → bırak: Mağaza'ya GİDİLMEDİ (istek 0, sekme 2)" % label,
		label == "MAĞAZAYA GİT" and _n.get("primary.down", 0) == 1 and _n.get("shop_skin_requested", 0) == 0
		and _main._active_tab == 2 and not album.is_detail_open())
	# C3 — vitrindeki (yuva > 0) parça: ikincil VİTRİNDEN ÇIKAR.
	album = await _open_fresh({"profile_showcase": [String(OTHER), String(OWNED)]})
	await _open_detail(album, OWNED)
	var secondary: Button = album.detail_secondary()
	_watch(secondary, "secondary")
	label = album.detail_secondary_text()
	var econ: Dictionary = _econ()
	pos = _center(secondary)
	_mark()
	await _hold(pos, "event")
	await _back()
	await _finger(pos, false)
	await _settle(3)
	_c("C3: '%s' basılı (button_down 1) + GERİ → bırak: vitrinden ÇIKARILMADI (bellek + disk aynı)" % label,
		label == "VİTRİNDEN ÇIKAR" and not secondary.is_visible_in_tree() and _n.get("secondary.down", 0) == 1 and _econ() == econ
		and SaveManager.profile_showcase().has(OWNED))
	# C4 — vitrin dolu → değiştirme adımı → yuva kutusu basılı + GERİ (adım kapanır, detay kalır).
	album = await _open_fresh(_full_showcase())
	await _open_detail(album, OWNED)
	await _tap(album.detail_primary())
	await _wait_settled()
	var tile: Button = album.replace_tiles()[0]
	_watch(tile, "tile")
	econ = _econ()
	var replacing: bool = album.is_replacing() and tile.is_visible_in_tree()
	pos = _center(tile)
	_mark()
	await _hold(pos, "event")
	await _back()
	_record("C4 GERİ", album)
	await _finger(pos, false)
	await _settle(3)
	_c("C4 kurulum: vitrin dolu → VİTRİNE EKLE değiştirme adımını açtı, kutu basılı (button_down 1)", replacing
		and _n.get("tile.down", 0) == 1)
	_c("  … C4: GERİ değiştirme adımını kapattı (detay açık), bırakışta yuva DEĞİŞMEDİ (bellek + disk aynı)",
		not album.is_replacing() and album.is_detail_open() and _econ() == econ)
	# C5 — detay X basılı + GERİ: tek kapanış, yeniden açılış yok.
	album = await _open_fresh()
	await _open_detail(album, OWNED)
	var close: Button = album.detail_frame().get_meta(&"close_button")
	_watch(close, "close")
	pos = _center(close)
	_mark()
	await _hold(pos, "event")
	await _back()
	await _finger(pos, false)
	await _settle(3)
	_c("C5: detay X basılı (button_down 1) + GERİ → bırak: detay kapalı kaldı, yeniden açılmadı, Koleksiyon'da",
		_n.get("close.down", 0) == 1 and not album.is_detail_open() and _n.get("detail_opened", 0) == 0
		and _main._active_tab == 2)
	_sections_done += 1


# --- D) ACTION_CANCEL ----------------------------------------------------------------------------------------------

func _cancel() -> void:
	print("-- D: ACTION_CANCEL (canceled bırakış) → 0 eylem: kart, birincil, ikincil, kutu, kabuk ANA SAYFA / üst çubuk \"+\"")
	var album: CanvasLayer = await _open_fresh()
	var card: Button = album.card(OWNED)
	_watch(card, "card")
	_mark()
	await _down_cancel(_center(card))
	_c("D kart: DOWN + CANCEL → detay AÇILMADI (detail_opened 0); basış bitti (button_up 1)", _n.get("card.down", 0) == 1
		and not album.is_detail_open() and _n.get("detail_opened", 0) == 0 and _n.get("card.up", 0) == 1)
	await _open_detail(album, OWNED)
	var primary: Button = album.detail_primary()
	_watch(primary, "primary")
	var econ: Dictionary = _econ()
	_mark()
	await _down_cancel(_center(primary))
	_c("D birincil (VİTRİNE EKLE): DOWN + CANCEL → vitrine YAZILMADI, detay açık kaldı", _n.get("primary.down", 0) == 1
		and _econ() == econ and album.is_detail_open())
	album = await _open_fresh({"profile_showcase": [String(OTHER), String(OWNED)]})
	await _open_detail(album, OWNED)
	var secondary: Button = album.detail_secondary()
	_watch(secondary, "secondary")
	econ = _econ()
	_mark()
	await _down_cancel(_center(secondary))
	_c("D ikincil (VİTRİNDEN ÇIKAR): DOWN + CANCEL → vitrinden ÇIKARILMADI", _n.get("secondary.down", 0) == 1
		and _econ() == econ)
	album = await _open_fresh(_full_showcase())
	await _open_detail(album, OWNED)
	await _tap(album.detail_primary())
	await _wait_settled()
	var tile: Button = album.replace_tiles()[1]
	_watch(tile, "tile")
	econ = _econ()
	_mark()
	await _down_cancel(_center(tile))
	_c("D kutu: değiştirme adımında DOWN + CANCEL → yuva DEĞİŞMEDİ, adım açık kaldı", _n.get("tile.down", 0) == 1
		and _econ() == econ and album.is_replacing())
	# TASK/057 Tur 2: üst çubukta geri oku yok — Ana Sayfa rotası küresel kabuğun ANA SAYFA öğesi (GlobalNav'da
	# GestureGuard sahipli); "+" üst çubukta kaldı.
	for which: String in ["nav_home", "bar_add"]:
		album = await _open_fresh()
		var bar: ScreenTopBar = album.top_bar()
		var button: Button = _main.global_nav().item_button(0) if which == "nav_home" else bar.add_button()
		_watch(button, which)
		_mark()
		await _down_cancel(_center(button))
		_c("D %s: DOWN + CANCEL → gezinme YOK (kabuk gezinmesi 0, Mağaza isteği 0, Koleksiyon'da)"
			% ("kabuk ANA SAYFA" if which == "nav_home" else "üst çubuk \"+\""),
			_n.get("%s.down" % which, 0) == 1 and _nav_delta() == 0 and _n.get("shop_requested", 0) == 0
			and _main._active_tab == 2 and album.visible)
	album = await _open_fresh()
	await _open_detail(album, OWNED)
	var close: Button = album.detail_frame().get_meta(&"close_button")
	_watch(close, "close")
	_mark()
	await _down_cancel(_center(close))
	_c("D detay X: DOWN + CANCEL → detay KAPANMADI (kapanış 0)", _n.get("close.down", 0) == 1 and album.is_detail_open()
		and _n.get("detail_off", 0) == 0)
	# Karartma özel bırakış yolu (Koleksiyon kendi kaydıyla süzer; TASK/055'ten beri paylaşılan `attach_dim_close` da iptali
	# süzer — iki katmanlı, davranış aynı).
	_mark()
	await _down_cancel(_dim_point(album))
	_c("D karartma: DOWN + CANCEL → detay KAPANMADI (dokunuş karartmaya ulaştı, kapanış 0)", _n.get("dim.down", 0) == 1
		and album.is_detail_open() and _n.get("detail_off", 0) == 0)
	# Hareketli gezinmenin geri kaydırması karartmadan başlarsa: önce ACTION_CANCEL, sonra GERİ — tek gezinme.
	_mark()
	await _down_cancel(_dim_point(album))
	await _back()
	await _settle(2)
	_c("D karartma İPTAL → GERİ: tek gezinme — detay bir kez kapandı, Koleksiyon'da kalındı (Ana Sayfa'ya düşmedi)",
		_n.get("dim.down", 0) == 1 and not album.is_detail_open() and _n.get("detail_off", 0) == 1
		and _main._active_tab == 2 and album.visible)
	_sections_done += 1


# --- E) İptal + bayat UP --------------------------------------------------------------------------------------------

func _cancel_then_up() -> void:
	print("-- E: DOWN + CANCEL + bayat UP → 0 eylem (motor dokunuş odağını iptalde bırakmıştı); ardından taze dokunuş tam bir kez")
	var album: CanvasLayer = await _open_fresh()
	var card: Button = album.card(OWNED)
	_watch(card, "card")
	var pos: Vector2 = _center(card)
	_mark()
	await _down_cancel(pos)
	await _finger(pos, false)
	await _settle(3)
	_c("E kart: CANCEL'dan sonra bayat UP → detay yok (detail_opened 0)", _n.get("card.down", 0) == 1
		and not album.is_detail_open() and _n.get("detail_opened", 0) == 0)
	await _wait_settled()
	_mark()
	await _tap(card)
	_c("  … E kart: sonraki taze dokunuş tam 1 detay (button_down 1, detail_opened 1, id doğru)", _n.get("card.down", 0) == 1
		and _n.get("detail_opened", 0) == 1 and album.detail_id() == OWNED)
	await _wait_settled()
	var dim_pos: Vector2 = _dim_point(album)
	_mark()
	await _down_cancel(dim_pos)
	await _finger(dim_pos, false)
	await _settle(3)
	_c("E karartma: CANCEL'dan sonra bayat UP → detay açık kaldı (kapanış 0)", _n.get("dim.down", 0) == 1
		and album.is_detail_open() and _n.get("detail_off", 0) == 0)
	_mark()
	await _finger_tap(dim_pos)
	await _settle(3)
	_c("  … E karartma: sonraki taze dokunuş tam 1 kapanış, Koleksiyon'da", _n.get("dim.down", 0) == 1
		and not album.is_detail_open() and _n.get("detail_off", 0) == 1 and _main._active_tab == 2)
	_sections_done += 1


# --- F) Bayat diziden sonra taze dokunuş ----------------------------------------------------------------------------

func _fresh_after_stale() -> void:
	print("-- F: bayat dizi (kart + işlenmeyen olay + GERİ + bırak) → yeniden aç → AYNI karta taze dokunuş tam bir kez")
	var album: CanvasLayer = await _open_fresh()
	var card: Button = album.card(OWNED)
	_watch(card, "card")
	var pos: Vector2 = _center(card)
	await _hold(pos, "event")
	await _back()
	await _finger(pos, false)
	await _settle(3)
	_main._show_tab(2)
	await _wait_settled()
	_mark()
	await _tap(card)
	_c("F: yeniden açılışta ilk taze dokunuş AYNI kartta tam 1 detay açtı (button_down 1, detail_opened 1, id doğru)",
		album.visible and _n.get("card.down", 0) == 1 and _n.get("detail_opened", 0) == 1 and album.detail_id() == OWNED)
	await _wait(0.45)
	await _settle(3)
	_c("  … F: tam BİR kez — geçiş yatışması / eylem kilidi süresi sonunda da ikinci seçim yok (pressed 1, detail_opened 1)",
		_n.get("card.pressed", 0) == 1 and _n.get("detail_opened", 0) == 1 and album.is_detail_open())
	_sections_done += 1


# --- G) Öykünülen fare sırası ---------------------------------------------------------------------------------------

func _ordering() -> void:
	print("-- G: öykünülen fare + dokunuş sırası — normal dokunuş tek seçim, gerçek bırakış `pressed`'ten önce görülür")
	var album: CanvasLayer = await _open_fresh()
	var card: Button = album.card(OWNED)
	_watch(card, "card")
	_mark()
	await _tap(card)
	var order: Array[String] = _gui_order()
	print("  [KAYIT] G normal dokunuş: %s" % " ".join(_events))
	_c("G: normal dokunuş — kart öykünülen fare (aygıt -1) ve dokunuş (aygıt 0) olaylarının İKİSİNİ de alır, tam 1 seçim",
		order.has("MouseButton:-1:DOWN") and order.has("ScreenTouch:0:DOWN") and order.has("MouseButton:-1:UP")
		and order.has("ScreenTouch:0:UP") and _n.get("card.pressed", 0) == 1 and _n.get("detail_opened", 0) == 1)
	_c("  … G: fare basışı dokunuştan ÖNCE işlenir (Android'deki öykünme sırası)",
		order.find("MouseButton:-1:DOWN") >= 0 and order.find("MouseButton:-1:DOWN") < order.find("ScreenTouch:0:DOWN"))
	var up_at: int = _event_index("card.gui:MouseButton:-1:UP")
	var pressed_at: int = _event_index("card.pressed")
	_c("  … G: gerçek fare bırakışı gui_input'ta `pressed`'ten ÖNCE görülür, dokunuş UP'ı sonra (sahiplik kaydı eylemden önce)",
		up_at >= 0 and pressed_at > up_at and _event_index("card.gui:ScreenTouch:0:UP") > pressed_at)
	album = await _open_fresh()
	card = album.card(OWNED)
	_watch(card, "card")
	var pos: Vector2 = _center(card)
	_mark()
	await _hold(pos, "event")
	await _back()
	await _finger(pos, false)
	await _settle(3)
	order = _gui_order()
	print("  [KAYIT] G bayat dizi: %s" % " ".join(_events))
	_c("G (motor gerçeği): bayat dizide öykünülen fare bırakışı karta HİÇ ulaşmadı — gizlenince fare odağı düştü, kalkış hedefsiz",
		order.has("MouseButton:-1:DOWN") and not order.has("MouseButton:-1:UP"))
	_c("  … G: gizli karta ulaşan dokunuş UP'ı (aygıt 0) seçim üretmedi; detay 0", order.has("ScreenTouch:0:UP")
		and _n.get("detail_opened", 0) == 0 and not album.is_detail_open())
	_sections_done += 1


# --- H) Çok parmak --------------------------------------------------------------------------------------------------

func _multi_touch() -> void:
	print("-- H: çok parmak — ikinci parmak GUI düğmesine basamaz; kartı tutan parmak GERİ'den sonra kalkarsa 0 eylem")
	var album: CanvasLayer = await _open_fresh()
	var card: Button = album.card(OWNED)
	_watch(card, "card")
	# TASK/057 Tur 2: üst çubukta geri oku yok — Ana Sayfa rotası kabuğun ANA SAYFA öğesi.
	var home_item: Button = _main.global_nav().item_button(0)
	var pos: Vector2 = _center(card)
	_mark()
	await _finger(pos, true, 0)
	await _finger_tap(_center(home_item), 1)
	await _settle(2)
	_c("H: parmak 0 kartı tutarken parmak 1 kabuk ANA SAYFA'ya dokundu → gezinme YOK (fare öykünmesi yalnız 0. parmak)",
		_main._active_tab == 2 and album.visible and _nav_delta() == 0)
	await _finger(pos, false, 0)
	await _settle(3)
	_c("  … H: GERİ olmadan parmak 0 GÖRÜNÜR kartta kalktı → normal tek seçim (bayat değil)", _n.get("detail_opened", 0) == 1
		and album.detail_id() == OWNED)
	album = await _open_fresh()
	card = album.card(OWNED)
	_watch(card, "card")
	pos = _center(card)
	_mark()
	await _finger(pos, true, 0)
	await _unhandled_key()
	await _back()
	await _finger_tap(_screen(Vector2(360.0, 900.0)), 1)
	await _finger(pos, false, 0)
	await _settle(3)
	_c("H: parmak 0 kartı tutuyor → GERİ → parmak 1 Ana Sayfa'da dokunur → parmak 0 kalkar: 0 eylem, Ana Sayfa'da",
		_n.get("detail_opened", 0) == 0 and not album.is_detail_open() and _main._active_tab == 0)
	_sections_done += 1


# --- I) Hızlı GERİ --------------------------------------------------------------------------------------------------

func _rapid_back() -> void:
	print("-- I: birincil basılı → GERİ (detay kapanır) → GERİ (Ana Sayfa) → bırak: tek kapanış, tek gezinme, 0 eylem")
	var album: CanvasLayer = await _open_fresh()
	await _open_detail(album, OWNED)
	var primary: Button = album.detail_primary()
	_watch(primary, "primary")
	var econ: Dictionary = _econ()
	var pos: Vector2 = _center(primary)
	_mark()
	await _hold(pos, "event")
	await _back()
	var first: bool = not album.is_detail_open() and _main._active_tab == 2
	await _back()
	var second: bool = _main._active_tab == 0 and not album.visible
	await _finger(pos, false)
	await _settle(3)
	_c("I: 1. GERİ detayı kapattı (Koleksiyon'da), 2. GERİ Ana Sayfa'ya çıktı", first and second)
	_c("  … I: bırakışta vitrin aynı, detay yeniden açılmadı, ek gezinme / çıkış isteği yok", _econ() == econ
		and _n.get("detail_opened", 0) == 0 and _main._active_tab == 0 and int(_main.get("quit_requests")) == 0
		and _n.get("shop_requested", 0) == 0 and _nav_delta() == 0)
	_sections_done += 1


# --- J) Basılı durum gizlenince biter --------------------------------------------------------------------------------

func _hold_state() -> void:
	print("-- J: gizlenen basılı düğmenin basışı biter — sonraki taze basış button_down yayar (dokunuş sesi / basış ölçeği)")
	# Olay YOK: motorun sentetik bırakışı düşer (son girdi işlenmişti) → BaseButton basılı durumu asılı kalırdı.
	var album: CanvasLayer = await _open_fresh()
	var card: Button = album.card(OWNED)
	_watch(card, "card")
	var pos: Vector2 = _center(card)
	_mark()
	await _hold(pos, "none")
	await _back()
	await _finger(pos, false)
	await _settle(3)
	var ended: bool = _n.get("card.up", 0) == 1
	_main._show_tab(2)
	await _wait_settled()
	_c("J kart: gizlenince basış bitti (button_up 1), ölçek 1.0, çizim kipi normal", ended
		and card.scale.is_equal_approx(Vector2.ONE) and card.get_draw_mode() == BaseButton.DRAW_NORMAL)
	_mark()
	await _tap(card)
	_c("  … J kart: sonraki taze basış button_down YAYDI (1) ve tam 1 detay", _n.get("card.down", 0) == 1
		and _n.get("detail_opened", 0) == 1)
	# Kart [kaydırma] — KORUMA kontrolü: basılıyken galeri kaydırmaya geçti (SCROLL_BEGIN: BaseButton press_attempt'i
	# bırakır, button_up YOK) → GERİ → bırak → yeniden aç → taze dokunuş. Cihazda sürükleme olayları işlenir → gizleme
	# bırakışı düşer (basışı `_end_press` bitirir); headless'ta dokunmatik ekran yok → ScrollContainer sürüklemez, bırakış
	# tabanda da işlenir — burada ayırt edici değil, düzeltmenin bu yolu bozmadığını sınar.
	album = await _open_fresh()
	card = album.card(OWNED)
	_watch(card, "card")
	pos = _center(card)
	_mark()
	await _finger(pos, true)
	album.scroll().propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	await _settle(1)
	var scrolled: bool = _n.get("card.down", 0) == 1 and _n.get("card.up", 0) == 0
	await _back()
	var scroll_ended: bool = _n.get("card.up", 0) == 1 and not album.visible
	await _finger(pos, false)
	await _settle(3)
	_main._show_tab(2)
	await _wait_settled()
	_mark()
	await _tap(card)
	_c("J kart [kaydırma] (koruma): kaydırmaya geçen basılı kartın basışı GERİ'de bitti (button_up 1); yeniden açılışta taze basış button_down 1, tam 1 detay",
		scrolled and scroll_ended and _n.get("card.down", 0) == 1 and _n.get("detail_opened", 0) == 1)
	# Üst çubuk "+": basılı + GERİ (olay yok) → yeniden aç → "+"ya taze dokunuş. (TASK/057 Tur 2: üst çubukta geri oku
	# yok — kalan üst çubuk düğmesi "+".)
	album = await _open_fresh()
	var add_button: Button = album.top_bar().add_button()
	_watch(add_button, "bar_add")
	pos = _center(add_button)
	await _hold(pos, "none")
	await _back()
	await _finger(pos, false)
	await _settle(3)
	var add_ended: bool = _n.get("shop_requested", 0) == 0 and _main._active_tab == 0
	_main._show_tab(2)
	await _wait_settled()
	_mark()
	await _tap(add_button)
	_c("J üst çubuk \"+\": GERİ'de 0 gezinme; yeniden açılışta taze basış button_down 1, tek gezinme (Mağaza)", add_ended
		and _n.get("bar_add.down", 0) == 1 and _n.get("shop_requested", 0) == 1 and _main._active_tab == 3)
	# Birincil: basılı + GERİ (detay kapanır, olay yok) → detayı yeniden aç → taze dokunuş.
	album = await _open_fresh()
	await _open_detail(album, OWNED)
	var primary: Button = album.detail_primary()
	_watch(primary, "primary")
	pos = _center(primary)
	await _hold(pos, "none")
	await _back()
	await _finger(pos, false)
	await _settle(3)
	await _open_detail(album, OWNED)
	var before: int = SaveManager.profile_showcase().size()
	_mark()
	await _tap(primary)
	_c("J birincil: detay kapanınca basış bitti; yeniden açılan detayda taze basış button_down 1, vitrine tam 1 ekleme",
		_n.get("primary.down", 0) == 1 and SaveManager.profile_showcase().size() == before + 1)
	# Kutu: değiştirme adımı, kutu basılı + GERİ (adım kapanır, olay yok) → adımı yeniden aç → taze dokunuş.
	album = await _open_fresh(_full_showcase())
	await _open_detail(album, OWNED)
	await _tap(album.detail_primary())
	await _wait_settled()
	var tile: Button = album.replace_tiles()[2]
	_watch(tile, "tile")
	pos = _center(tile)
	await _hold(pos, "none")
	await _back()
	await _finger(pos, false)
	await _settle(3)
	await _wait_settled()
	await _tap(album.detail_primary())
	await _wait_settled()
	_mark()
	await _tap(tile)
	_c("J kutu: adım kapanınca basış bitti; yeniden açılan adımda taze basış button_down 1, tam 1 değiştirme",
		_n.get("tile.down", 0) == 1 and SaveManager.profile_showcase().has(OWNED)
		and SaveManager.profile_showcase().size() == 3)
	# Detay X: basılı + GERİ (detay kapanır, olay yok) → detayı yeniden aç → X'e taze dokunuş.
	album = await _open_fresh()
	await _open_detail(album, OWNED)
	var close: Button = album.detail_frame().get_meta(&"close_button")
	_watch(close, "close")
	pos = _center(close)
	await _hold(pos, "none")
	await _back()
	await _finger(pos, false)
	await _settle(3)
	await _open_detail(album, OWNED)
	_mark()
	await _tap(close)
	_c("J detay X: detay kapanınca basış bitti; yeniden açılan detayda X'e taze basış button_down 1, detay kapandı",
		_n.get("close.down", 0) == 1 and not album.is_detail_open())
	_sections_done += 1


# --- K) Kayıt / ekonomi ---------------------------------------------------------------------------------------------

func _economy() -> void:
	print("-- K: bayat diziler kayda dokunmaz — Hamur / vitrin / açık parçalar bellekte ve diskte aynı")
	var album: CanvasLayer = await _open_fresh(_full_showcase())
	var econ: Dictionary = _econ()
	# Ardışık bayat diziler: kart, birincil (VİTRİNE EKLE → değiştirme), kutu, üst çubuk "+".
	var card: Button = album.card(OWNED)
	await _hold(_center(card), "event")
	await _back()
	await _finger(_center(card), false)
	await _settle(2)
	_main._show_tab(2)
	await _wait_settled()
	await _open_detail(album, OWNED)
	await _hold(_center(album.detail_primary()), "event")
	await _back()
	await _finger(_center(album.detail_primary()), false)
	await _settle(2)
	await _wait_settled()
	await _open_detail(album, OWNED)
	await _tap(album.detail_primary())
	await _wait_settled()
	var tile: Button = album.replace_tiles()[0]
	await _hold(_center(tile), "event")
	await _back()
	await _finger(_center(tile), false)
	await _settle(2)
	await _back()
	await _wait_settled()
	var add: Button = album.top_bar().add_button()
	await _hold(_center(add), "event")
	await _back()
	await _finger(_center(add), false)
	await _settle(3)
	_c("K: dört bayat dizi sonunda Hamur / vitrin / açık parçalar bellekte ve diskte AYNI, Ana Sayfa'da", _econ() == econ
		and _main._active_tab == 0)
	_sections_done += 1


# --- L) Normal tek dokunuşlar ---------------------------------------------------------------------------------------

func _normal_taps() -> void:
	print("-- L: normal tek dokunuş tam bir kez — kart, birincil, ikincil, kutu, kabuk ANA SAYFA / üst çubuk \"+\"")
	var album: CanvasLayer = await _open_fresh()
	var card: Button = album.card(OWNED)
	_watch(card, "card")
	_mark()
	await _tap(card)
	_c("L kart: dokunuş → tam 1 detay (id doğru)", _n.get("detail_opened", 0) == 1 and album.detail_id() == OWNED)
	await _wait_settled()
	var before: Array = SaveManager.profile_showcase().duplicate()
	await _tap(album.detail_primary())
	_c("L birincil: VİTRİNE EKLE → vitrine tam 1 ekleme (bellek + disk)", SaveManager.profile_showcase().size()
		== before.size() + 1 and SaveManager.profile_showcase().has(OWNED) and (_disk("profile_showcase") as Array).has(String(OWNED)))
	album = await _open_fresh({"profile_showcase": [String(OTHER), String(OWNED)]})
	await _open_detail(album, OWNED)
	await _tap(album.detail_secondary())
	_c("L ikincil: VİTRİNDEN ÇIKAR → tam 1 çıkarma (bellek + disk)", not SaveManager.profile_showcase().has(OWNED)
		and not (_disk("profile_showcase") as Array).has(String(OWNED)))
	album = await _open_fresh(_full_showcase())
	await _open_detail(album, OWNED)
	await _tap(album.detail_primary())
	await _wait_settled()
	var old: StringName = (album.replace_tiles()[1] as Button).get_meta(&"skin_id")
	await _tap(album.replace_tiles()[1])
	_c("L kutu: değiştirme adımında 2. yuva → tam 1 değiştirme (yeni parça girdi, eskisi çıktı, boyut 3)",
		SaveManager.profile_showcase().has(OWNED) and not SaveManager.profile_showcase().has(old)
		and SaveManager.profile_showcase().size() == 3)
	# TASK/057 Tur 2: üst çubukta geri oku yok — Ana Sayfa'ya dönüş kabuğun ANA SAYFA öğesi.
	album = await _open_fresh()
	_c("TASK/057 Tur 2: Koleksiyon üst çubuğunda geri oku yok (back_button() null)", album.top_bar().back_button() == null)
	_mark()
	await _tap(_main.global_nav().item_button(0))
	_c("L kabuk ANA SAYFA: tam 1 gezinme → Ana Sayfa", _nav_delta() == 1 and _main._active_tab == 0
		and not album.visible)
	album = await _open_fresh()
	_mark()
	await _tap(album.top_bar().add_button())
	_c("L üst çubuk \"+\": tam 1 gezinme → Mağaza", _n.get("shop_requested", 0) == 1 and _main._active_tab == 3)
	album = await _open_fresh()
	await _open_detail(album, OWNED)
	_mark()
	await _tap(album.detail_frame().get_meta(&"close_button"))
	_c("L detay X: dokunuş → tam 1 kapanış, Koleksiyon'da", not album.is_detail_open() and _n.get("detail_off", 0) == 1
		and _main._active_tab == 2 and album.visible)
	await _open_detail(album, OWNED)
	_mark()
	await _finger_tap(_dim_point(album))
	await _settle(3)
	_c("L karartma: dokunuş → tam 1 kapanış, Koleksiyon'da", _n.get("dim.down", 0) == 1 and not album.is_detail_open()
		and _n.get("detail_off", 0) == 1 and _main._active_tab == 2 and album.visible)
	_sections_done += 1


# --- M) Gezinme / GERİ (basılı dokunuş yokken) ------------------------------------------------------------------------

func _navigation() -> void:
	print("-- M: GERİ (basılı dokunuş yokken) aynen — detay, değiştirme adımı, Koleksiyon; Ana Sayfa madalyonu")
	var album: CanvasLayer = await _open_fresh(_full_showcase())
	await _open_detail(album, OWNED)
	await _tap(album.detail_primary())
	await _wait_settled()
	var replacing: bool = album.is_replacing()
	await _back()
	_c("M: değiştirme adımında GERİ → adım kapandı, detay açık kaldı", replacing and not album.is_replacing()
		and album.is_detail_open() and _main._active_tab == 2)
	await _back()
	_c("  … M: detay açıkken GERİ → detay kapandı, Koleksiyon'da kalındı", not album.is_detail_open()
		and _main._active_tab == 2 and album.visible)
	await _back()
	_c("  … M: detay kapalıyken GERİ → Ana Sayfa (çıkış isteği yok)", _main._active_tab == 0 and not album.visible
		and int(_main.get("quit_requests")) == 0)
	await _wait_settled()
	var home: CanvasLayer = _main._screens[0]
	await _tap(home.feature_button(&"collection"))
	await _wait_settled()
	_c("  … M: Ana Sayfa KOLEKSİYON madalyonuna gerçek dokunuş → Koleksiyon (detay kapalı)", _main._active_tab == 2
		and album.visible and not album.is_detail_open())
	_sections_done += 1


# --- O) Pencere odağı kaybı -------------------------------------------------------------------------------------------

func _focus_out() -> void:
	print("-- O: basılı düğmede pencere odağı kaybı (Android onPause: arka plan / ekran kilidi / arama) → 0 eylem, basış biter")
	# O1 — kart: önce AYNI karta normal bir dokunuş (önceki dokunuşun gerçek bırakışı yeni basışa sızmamalı), sonra basılı
	# kart + işlenmeyen olay (cihazda ör. ses tuşu) + odak kaybı: motorun bırakışı karta ULAŞIR ve `pressed` sayılır.
	var album: CanvasLayer = await _open_fresh()
	var card: Button = album.card(OWNED)
	_watch(card, "card")
	await _tap(card)
	var first: bool = album.detail_id() == OWNED
	await _back()
	await _wait_settled()
	var econ: Dictionary = _econ()
	var pos: Vector2 = _center(card)
	_mark()
	await _hold(pos, "event")
	await _window_focus(false)
	_record("O1 odak kaybı", album)
	var at_out: bool = not album.is_detail_open() and _n.get("detail_opened", 0) == 0 and _n.get("card.up", 0) == 1
	await _window_focus(true)
	await _finger(pos, false)
	await _settle(3)
	_c("O1 kart: önceki normal dokunuş detay açtı; basılı kart + odak kaybı → detay AÇILMADI, basış bitti (button_up 1)",
		first and _n.get("card.down", 0) == 1 and at_out)
	_c("  … O1: odak dönüp parmak kalkınca da 0 eylem (detay yok, kayıt aynı), Koleksiyon'da", not album.is_detail_open()
		and _n.get("detail_opened", 0) == 0 and _econ() == econ and _main._active_tab == 2 and album.visible)
	await _wait_settled()
	_mark()
	await _tap(card)
	_c("  … O1: sonraki taze dokunuş tam 1 detay (button_down 1)", _n.get("card.down", 0) == 1
		and _n.get("detail_opened", 0) == 1 and album.detail_id() == OWNED)
	# O2 — STOP birincil (VİTRİNE EKLE), olay yok (son girdi işlenmiş): motorun odak bırakışı DÜŞER → basış odak kaybı
	# bildiriminde biter (yoksa düğme basılı çizilir, sonraki basış button_down / dokunuş sesi üretmez).
	album = await _open_fresh()
	await _open_detail(album, OWNED)
	var primary: Button = album.detail_primary()
	_watch(primary, "primary")
	econ = _econ()
	pos = _center(primary)
	_mark()
	await _hold(pos, "none")
	await _window_focus(false)
	var ended: bool = _n.get("primary.up", 0) == 1 and primary.get_draw_mode() != BaseButton.DRAW_PRESSED
	await _window_focus(true)
	await _finger(pos, false)
	await _settle(3)
	_c("O2 birincil [olay yok]: odak kaybında basış bitti (button_up 1, basılı çizim yok); kalkışta vitrin aynı, detay açık",
		_n.get("primary.down", 0) == 1 and ended and _econ() == econ and album.is_detail_open())
	await _wait_settled()
	_mark()
	await _tap(primary)
	_c("  … O2: sonraki taze basış button_down 1, vitrine tam 1 ekleme", _n.get("primary.down", 0) == 1
		and SaveManager.profile_showcase().has(OWNED) and SaveManager.profile_showcase().size() == 2)
	# O3 — STOP birincil + işlenmeyen olay + odak kaybı: motorun bırakışı düğmeye ULAŞIR, `pressed` sayılır (TASK/054
	# incelemesi: ses tuşu + güç tuşu / gelen arama).
	album = await _open_fresh()
	await _open_detail(album, OWNED)
	primary = album.detail_primary()
	_watch(primary, "primary")
	econ = _econ()
	pos = _center(primary)
	_mark()
	await _hold(pos, "event")
	await _window_focus(false)
	var at_out3: bool = _econ() == econ and _n.get("primary.up", 0) == 1
	await _window_focus(true)
	await _finger(pos, false)
	await _settle(3)
	_c("O3 birincil [işlenmeyen olay]: odak kaybı bırakışı → vitrine YAZILMADI (bellek + disk), basış bitti, detay açık",
		_n.get("primary.down", 0) == 1 and at_out3 and _econ() == econ and album.is_detail_open())
	_sections_done += 1


# --- R) Ana Sayfa günlük penceresi -----------------------------------------------------------------------------------

func _daily_popup() -> void:
	print("-- R: günlük pencere bugün gösterilmemiş + basılı kart + GERİ → Ana Sayfa'da pencere açılır, bayat kalkış dokunmaz")
	var daily: Dictionary = (_fixture()["daily_rewards"] as Dictionary).duplicate()
	daily["popup_seen_day"] = ""
	var album: CanvasLayer = await _open_fresh({"daily_rewards": daily})
	var popup: CanvasLayer = _main._daily_rewards
	DailyRewards.auto_popup_enabled = true
	var due: bool = DailyRewards.popup_due() and not popup.visible
	var card: Button = album.card(OWNED)
	_watch(card, "card")
	var econ: Dictionary = _econ()
	var pos: Vector2 = _center(card)
	_mark()
	await _hold(pos, "event")
	await _back()
	_record("R GERİ", album)
	var at_back: bool = _main._active_tab == 0 and popup.visible and not album.is_detail_open()
	await _finger(pos, false)
	await _settle(3)
	_c("R: ön koşul pencere due; basılı kart (button_down 1) + GERİ → Ana Sayfa'da günlük pencere AÇILDI (gizli detay yok)",
		due and _n.get("card.down", 0) == 1 and at_back)
	_c("  … R: parmak kalkınca pencere açık kaldı, detay / seçim 0, Hamur / vitrin aynı (bellek + disk)", popup.visible
		and not album.is_detail_open() and _n.get("detail_opened", 0) == 0 and _econ() == econ and _main._active_tab == 0)
	DailyRewards.auto_popup_enabled = false
	_sections_done += 1


# --- S) Gizli düğmeye ulaşan `pressed` -------------------------------------------------------------------------------

func _hidden_pressed() -> void:
	print("-- S: gizli düğmeye ulaşan `pressed` eylem üretmez — gizli albüm; detay KAPANIRKEN (id / adım hâlâ dururken)")
	var album: CanvasLayer = await _open_fresh()
	var card: Button = album.card(OWNED)
	var bar: ScreenTopBar = album.top_bar()
	_main._show_tab(0)
	await _settle(2)
	_mark()
	card.pressed.emit()
	# TASK/057 Tur 2: üst çubukta geri oku yok — kalan üst çubuk düğmesi "+".
	bar.add_button().pressed.emit()
	await _settle(2)
	_c("S: Koleksiyon gizliyken karta / üst çubuk \"+\"ya gelen pressed → detay 0, gezinme 0 (Mağaza isteği 0, kabuk 0), Ana Sayfa'da",
		not album.is_detail_open() and _n.get("detail_opened", 0) == 0 and _nav_delta() == 0
		and _n.get("shop_requested", 0) == 0 and _main._active_tab == 0)
	album = await _open_fresh()
	await _open_detail(album, OWNED)
	var econ: Dictionary = _econ()
	var hook: Dictionary = _press_mid_hide(album, album.detail_primary())
	album.close_detail(false)
	await _settle(2)
	_c("S: detay kapanırken (id hâlâ %s) VİTRİNE EKLE'ye gelen pressed → vitrine yazılmadı (bellek + disk)" % hook["id"],
		hook["fired"] and hook["id"] == OWNED and _econ() == econ)
	album = await _open_fresh()
	await _open_detail(album, LOCKED)
	hook = _press_mid_hide(album, album.detail_primary())
	_mark()
	album.close_detail(false)
	await _settle(2)
	_c("S: detay kapanırken (id hâlâ %s) MAĞAZAYA GİT'e gelen pressed → Mağaza isteği 0, Koleksiyon'da" % hook["id"],
		hook["fired"] and hook["id"] == LOCKED and _n.get("shop_skin_requested", 0) == 0 and _main._active_tab == 2)
	album = await _open_fresh({"profile_showcase": [String(OTHER), String(OWNED)]})
	await _open_detail(album, OWNED)
	econ = _econ()
	hook = _press_mid_hide(album, album.detail_secondary())
	album.close_detail(false)
	await _settle(2)
	_c("S: detay kapanırken (id hâlâ %s) VİTRİNDEN ÇIKAR'a gelen pressed → vitrinden çıkarılmadı" % hook["id"],
		hook["fired"] and hook["id"] == OWNED and _econ() == econ and SaveManager.profile_showcase().has(OWNED))
	album = await _open_fresh(_full_showcase())
	await _open_detail(album, OWNED)
	await _tap(album.detail_primary())
	await _wait_settled()
	econ = _econ()
	var replacing: bool = album.is_replacing()
	hook = _press_mid_hide(album, album.replace_tiles()[0])
	album.close_detail(false)
	await _settle(2)
	_c("S: detay kapanırken (değiştirme adımı hâlâ açık) kutuya gelen pressed → yuva değişmedi (bellek + disk)",
		replacing and hook["fired"] and hook["replacing"] and _econ() == econ)
	_sections_done += 1


# --- P) Kaynak sözleşmesi --------------------------------------------------------------------------------------------

func _source_contract() -> void:
	print("-- P: kaynak sözleşmesi")
	var code: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/collection_screen.gd"))
	var own: String = _function(code, "func _own_gesture(")
	_c("_own_gesture: gerçek (iptal edilmemiş) bırakış kaydı gui_input'tan, basılı durum button_down / button_up'tan; gizlenince basılıysa _end_press",
		own.contains("gui_input.connect(") and own.contains("META_GESTURE_RELEASED, not click.pressed and not click.canceled")
		and own.contains("button_down.connect(") and own.contains("button_up.connect(")
		and own.contains("visibility_changed.connect(") and own.contains("_end_press(button)")
		and own.contains("is_visible_in_tree()"))
	var ok_fn: String = _function(code, "func _gesture_ok(")
	_c("  … _gesture_ok = düğme ekranda (is_visible_in_tree) VE (basış yok YA DA gerçek bırakışı görüldü)",
		ok_fn.contains("is_visible_in_tree()") and ok_fn.contains("not button.get_meta(META_GESTURE_HELD, false)")
		and ok_fn.contains("or button.get_meta(META_GESTURE_RELEASED, false)"))
	var focus_fn: String = _function(code, "func _notification(")
	_c("  … pencere odağı kaybı (NOTIFICATION_WM_WINDOW_FOCUS_OUT) hâlâ basılı sahipli düğmelerin basışını _end_press ile bitirir",
		focus_fn.contains("NOTIFICATION_WM_WINDOW_FOCUS_OUT") and focus_fn.contains("META_GESTURE_HELD")
		and focus_fn.contains("_end_press("))
	var end_fn: String = _function(code, "func _end_press(")
	_c("  … _end_press basışı genel API'yle bitirir: disabled true → false (zaten devre dışıysa dokunmaz), eylem yaymaz",
		end_fn.contains("button.disabled = true") and end_fn.contains("button.disabled = false")
		and end_fn.find("button.disabled = true") < end_fn.find("button.disabled = false") and not end_fn.contains("emit"))
	var wired: Array[String] = []
	for token: String in ["_own_gesture(card)", "_own_gesture(_bar.add_button())",
			"_own_gesture(_detail_primary)", "_own_gesture(_detail_secondary)", "_own_gesture(tile)",
			"_own_gesture(close_button)"]:
		if not code.contains(token):
			wired.append(token)
	_c("Koleksiyon'un TÜM düğmeleri sahipliğe bağlı (kart, üst çubuk +, birincil, ikincil, kutu, X)%s"
		% ("" if wired.is_empty() else " (eksik: %s)" % ", ".join(wired)), wired.is_empty())
	_c("TASK/057 Tur 2: Koleksiyon üst çubuğunda geri oku yok — kaynakta back_button() sahipliği / koruması ve home_requested yok",
		not code.contains("back_button()") and not code.contains("home_requested"))
	var guarded: Array[String] = []
	for pair: Array in [["func _on_card_selected(", "_gesture_ok(card)"], ["func _on_detail_primary(", "_gesture_ok(_detail_primary)"],
			["func _on_detail_secondary(", "_gesture_ok(_detail_secondary)"],
			["func _on_replace_slot(", "_gesture_ok(_replace_tiles[slot])"]]:
		var fn: String = _function(code, String(pair[0]))
		var guard_at: int = fn.find(String(pair[1]))
		if guard_at < 0:
			guarded.append(String(pair[0]).trim_prefix("func ").trim_suffix("("))
	_c("eylem işleyicileri sahiplik korumasından geçer (kart seçimi, birincil, ikincil, kutu)%s"
		% ("" if guarded.is_empty() else " (korumasız: %s)" % ", ".join(guarded)), guarded.is_empty())
	var ready_fn: String = _function(code, "func _ready(")
	_c("  … üst çubuk gezinmesi korumalı: shop_requested (\"+\") yalnız _gesture_ok'tan sonra",
		ready_fn.find("_gesture_ok(_bar.add_button())") >= 0
		and ready_fn.find("_gesture_ok(_bar.add_button())") < ready_fn.find("shop_requested.emit()"))
	var primary_fn: String = _function(code, "func _on_detail_primary(")
	_c("  … birincil: koruma vitrin yazmasından / Mağaza isteğinden ÖNCE", primary_fn.find("_gesture_ok(_detail_primary)") >= 0
		and primary_fn.find("_gesture_ok(_detail_primary)") < primary_fn.find("SaveManager.")
		and primary_fn.find("_gesture_ok(_detail_primary)") < primary_fn.find("shop_skin_requested.emit("))
	var detail_fn: String = _function(code, "func _build_detail(")
	var recorder_at: int = detail_fn.find("_dim_release_canceled = event.is_canceled()")
	_c("  … detay X yalnız _gesture_ok'tan sonra kapatır; karartmanın iptal kaydı paylaşılan attach_dim_close'tan ÖNCE bağlı, kapanış iptalde yok",
		detail_fn.find("if _gesture_ok(close_button):") >= 0
		and detail_fn.find("if _gesture_ok(close_button):") < detail_fn.find("close_detail()")
		and recorder_at >= 0 and recorder_at < detail_fn.find("UiKit.attach_dim_close(")
		and detail_fn.contains("if not _dim_release_canceled:"))
	var card_src: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/collection_skin_card.gd"))
	var bar_src: String = FileAccess.get_file_as_string("res://scripts/ui/screen_top_bar.gd")
	_c("kart sınıfı ve paylaşılan yardımcılar: kart yalnız selected yayar, ScreenTopBar \"+\" aynen (TASK/057 Tur 2: geri oku yok — back_pressed yok), attach_dim_close kapanışı çağırır (TASK/055: iptali de süzer)",
		card_src.contains("pressed.connect(func() -> void: selected.emit(_id))")
		and bar_src.contains("pressed.connect(func() -> void: add_pressed.emit())") and not bar_src.contains("back_pressed")
		and _function(_strip_comments(FileAccess.get_file_as_string("res://scripts/ui/ui_kit.gd")), "static func attach_dim_close(")
			.contains("on_close.call()"))
	_c("Main'in geri yönlendirmesi / geçiş yatışması değişmedi (Koleksiyon handle_back, 300 ms)",
		_function(_strip_comments(FileAccess.get_file_as_string("res://scripts/main.gd")), "func _notification(")
			.contains("active.handle_back()")
		and int(load("res://scripts/main.gd").get_script_constant_map()["TOUCH_SETTLE_MSEC"]) == 300)


# --- Ortak ---------------------------------------------------------------------------------------------------------

func _fixture(extra: Dictionary = {}) -> Dictionary:
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 2},
		"endless_high_score": 640, "dough": 335, "total_merges": 40, "merges_since_bonus_chest": 10,
		"unlocked_skins": [String(OWNED), String(OTHER)], "profile_showcase": [String(OTHER)],
		"powerups": {"bomb": 0, "upgrade": 9, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "", "daily_streak": 3,
		"last_login_date": Time.get_date_string_from_system(), "age_ad_band": "ADULT", "next_age_transition_date": "",
		"player_meta_version": 1, "player_xp": 400, "total_rounds_played": 12, "highest_tier_created": 4,
		"unlocked_achievements": ["merge_10"],
		"daily_challenge": {"version": 1, "completed_day_key": ""},
		"daily_rewards": {"day_key": THU, "free_chest_claimed": true, "ad_chests_claimed": 2,
			"dough_ad_claimed": true, "popup_seen_day": THU, "last_seen_day_key": THU},
		"missions": {"version": 1, "day_key": THU, "week_start_day_key": MON,
			"daily_progress": {"daily_merges": 5, "daily_rounds": 0, "daily_clear": 0}, "daily_rewarded": [],
			"weekly_progress": {"weekly_merges": 30, "weekly_rounds": 4, "weekly_clears": 2}, "weekly_rewarded": []}}
	for key: String in extra:
		content[key] = extra[key]
	return content


## Vitrin dolu (3): OWNED sahip ama vitrinde değil → VİTRİNE EKLE değiştirme adımını açar.
func _full_showcase() -> Dictionary:
	return {"unlocked_skins": [String(OWNED), String(OTHER), "common_02", "common_03"],
		"profile_showcase": [String(OTHER), "common_02", "common_03"]}


## Temiz kayıt + Main + Koleksiyon açık (Ana Sayfa'dan Main'in kendi geçişiyle) + 300 ms geçiş yatışması bitti.
func _open_fresh(extra: Dictionary = {}) -> CanvasLayer:
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
	_n = {}
	_events = []
	var album: CanvasLayer = _main._screens[2]
	album.detail_opened.connect(func() -> void: _bump("detail_opened"))
	# TASK/057 Tur 2: albümde home_requested yok (geri oku kalktı) — Ana Sayfa gezinmesi `_nav_delta()` ile sayılır.
	album.shop_requested.connect(func() -> void: _bump("shop_requested"))
	album.shop_skin_requested.connect(func(_id: StringName) -> void: _bump("shop_skin_requested"))
	album.visibility_changed.connect(func() -> void: _ev("album:%s" % ("on" if album.visible else "off")))
	var detail: Control = album.get("_detail")
	detail.visibility_changed.connect(func() -> void:
		_bump("detail_on" if detail.visible else "detail_off")
		_ev("detail:%s" % ("on" if detail.visible else "off")))
	var dim: Control = album.get("_detail_dim")
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			_bump("dim.down" if event.is_pressed() else "dim.up")
			_ev("dim.gui:ScreenTouch:%s%s" % ["DOWN" if event.is_pressed() else "UP", ":CANCELED" if event.is_canceled() else ""]))
	_main._show_tab(2)
	await _wait_settled()
	_nav_mark = int(_main.get("nav_navigations"))
	return album


## Detay kod yoluyla (Profil vitrini yolu) açılır: kilitli kart albümün görünmeyen kısmında olabilir.
func _open_detail(album: CanvasLayer, id: StringName) -> void:
	album.open_detail(id)
	await _wait_settled()


## Detay karartmasında, pencerenin (çerçeve) DIŞINDA bir nokta (ekran px): çerçevenin üstündeki / altındaki geniş boşluk.
func _dim_point(album: CanvasLayer) -> Vector2:
	var frame: Rect2 = album.detail_frame().get_global_rect()
	var dim: Rect2 = (album.get("_detail_dim") as Control).get_global_rect()
	var above: float = frame.position.y - dim.position.y
	var below: float = dim.end.y - frame.end.y
	var y: float = dim.position.y + above * 0.5 if above >= below else frame.end.y + below * 0.5
	return _screen(Vector2(dim.get_center().x, y))


## `pressed`'i düğmenin KENDİ gizlenme bildirimi sırasında bir kez yayar: `close_detail` detayı gizlerken detay id'si /
## değiştirme adımı henüz temizlenmemiştir (motorun basış bitmeden bırakış verdiği en kötü an). Dönen kayıt: tetiklendi
## mi, o anki id ve adım.
func _press_mid_hide(album: CanvasLayer, button: BaseButton) -> Dictionary:
	var hook: Dictionary = {"fired": false, "id": &"", "replacing": false}
	button.visibility_changed.connect(func() -> void:
		if hook["fired"] or button.is_visible_in_tree():
			return
		hook["fired"] = true
		hook["id"] = album.detail_id()
		# Ham bayrak: `is_replacing()` detayın görünürlüğünü de ister (bu anda zaten gizli).
		hook["replacing"] = bool(album.get("_replacing"))
		button.pressed.emit())
	return hook


func _watch(button: Button, tag: String) -> void:
	if button.has_meta(&"qa_watch"):
		return
	button.set_meta(&"qa_watch", true)
	button.gui_input.connect(func(event: InputEvent) -> void:
		var kind: String = event.get_class().trim_prefix("InputEvent")
		if event is InputEventMouseButton or event is InputEventScreenTouch:
			_ev("%s.gui:%s:%d:%s%s" % [tag, kind, event.device, "DOWN" if event.is_pressed() else "UP",
				":CANCELED" if event.is_canceled() else ""]))
	button.button_down.connect(func() -> void:
		_bump("%s.down" % tag)
		_ev("%s.down" % tag))
	button.button_up.connect(func() -> void:
		_bump("%s.up" % tag)
		_ev("%s.up" % tag))
	button.pressed.connect(func() -> void:
		_bump("%s.pressed" % tag)
		_ev("%s.pressed" % tag))


func _bump(key: String) -> void:
	_n[key] = int(_n.get(key, 0)) + 1


func _mark() -> void:
	_n = {}
	_events = []
	_t0 = Time.get_ticks_msec()
	if _main != null and is_instance_valid(_main):
		_nav_mark = int(_main.get("nav_navigations"))


## Son `_mark` / `_open_fresh`'ten beri kabuğun (GlobalNav) yaptığı gezinme sayısı (TASK/057 Tur 2: Ana Sayfa'ya dönüş
## kabuğun ANA SAYFA öğesinden — eski `home_requested` sayacının yerine).
func _nav_delta() -> int:
	return int(_main.get("nav_navigations")) - _nav_mark


func _ev(tag: String) -> void:
	_events.append("%s@%+d" % [tag, Time.get_ticks_msec() - _t0])


## Olay kaydında `prefix` ile başlayan ilk olayın sırası (yoksa -1).
func _event_index(prefix: String) -> int:
	for i in _events.size():
		if _events[i].begins_with(prefix + "@"):
			return i
	return -1


## Kartın gui_input kayıtlarından "Tür:aygıt:YÖN" dizisi.
func _gui_order() -> Array[String]:
	var out: Array[String] = []
	for event in _events:
		var at: int = event.find(".gui:")
		if at >= 0:
			out.append(event.substr(at + 5).get_slice("@", 0))
	return out


## Kayıt satırı (sayılmaz): sekme, albüm / detay görünürlüğü, sayaçlar, olay sırası.
func _record(tag: String, album: CanvasLayer) -> void:
	print("  [KAYIT] %s: sekme=%d albüm=%s detay=%s id=%s değiştirme=%s sayaç=%s | %s" % [tag, _main._active_tab,
		str(album.visible), str(album.is_detail_open()), str(album.detail_id()), str(album.is_replacing()), str(_n),
		" ".join(_events)])


## Ekonomi / vitrin görüntüsü (bellek + disk).
func _econ() -> Dictionary:
	return {"dough": SaveManager.dough(), "showcase": SaveManager.profile_showcase().duplicate(),
		"unlocked": (SaveManager.data.get("unlocked_skins", []) as Array).duplicate(),
		"disk_showcase": _disk("profile_showcase"), "disk_dough": _disk("dough"), "disk_unlocked": _disk("unlocked_skins")}


## Parmak bir kontrolde BASILI kalır; `mode`: "none" (başka olay yok — motorun gizleme bırakışı düşer), "event" (ardından
## hiçbir şeyin işlemediği bir girdi olayı — gerçek cihazdaki işlenmeyen olayın deterministik karşılığı), "jitter" (1 px
## ScreenDrag — PASS kartta gerçek parmak titremesi; zamanlamaya bağlı).
func _hold(pos: Vector2, mode: String) -> void:
	await _finger(pos, true)
	match mode:
		"event":
			await _unhandled_key()
		"jitter":
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = pos + Vector2(1, 0)
			drag.relative = Vector2(1, 0)
			Input.parse_input_event(drag)
			Input.flush_buffered_events()
			await get_tree().process_frame


## Hiçbir şeyin işlemediği bir girdi olayı (eşlenmemiş tuş, basış + bırakış): Viewport'un "işlendi" bayrağı kapalı kalır.
func _unhandled_key() -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_F13
		key.physical_keycode = KEY_F13
		key.pressed = pressed
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		await get_tree().process_frame


## DOWN → Android ACTION_CANCEL (canceled bırakış) — Godot'nun Android yolu gibi.
func _down_cancel(pos: Vector2) -> void:
	await _finger(pos, true)
	var cancel := _touch_event(pos, false, 0)
	cancel.canceled = true
	_ev("finger0:cancel")
	Input.parse_input_event(cancel)
	Input.flush_buffered_events()
	await _settle(3)


## Gerçek dokunuş + karesi.
func _tap(control: Control) -> void:
	await _finger_tap(_center(control))
	await _settle(3)


func _teardown_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _settle(2)


## Pencere odağı (Android onPause → FOCUS_OUT, onResume → FOCUS_IN): kök pencereden aşağı, motorun sırasıyla (önce kök
## Viewport — fare odağını düşürür — sonra ekranlar).
func _window_focus(focused: bool) -> void:
	_ev("FOCUS_%s" % ("IN" if focused else "OUT"))
	get_tree().root.propagate_notification(NOTIFICATION_WM_WINDOW_FOCUS_IN if focused else NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await _settle(2)


## Android geri (Main'in 250 ms debounce'u gerçek saatle — iki basış arasında boşluk).
func _back() -> void:
	var gap: int = maxi(_last_back_msec + BACK_GAP_MSEC, int(_main.get("_last_back_msec")) + BACK_GAP_MSEC) \
		- Time.get_ticks_msec()
	if gap > 0:
		await _wait(float(gap) / 1000.0)
	_last_back_msec = Time.get_ticks_msec()
	_ev("BACK")
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(1)


func _touch_event(pos: Vector2, pressed: bool, index: int) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = pos
	touch.pressed = pressed
	return touch


## Parmak olayı Input'a verilir ve HEMEN dağıtılır (tampon boşaltılır — sıra deterministik).
func _finger(pos: Vector2, pressed: bool, index: int = 0) -> void:
	_ev("finger%d:%s" % [index, "down" if pressed else "up"])
	Input.parse_input_event(_touch_event(pos, pressed, index))
	Input.flush_buffered_events()
	await get_tree().process_frame


func _finger_tap(pos: Vector2, index: int = 0) -> void:
	await _finger(pos, true, index)
	await _finger(pos, false, index)


func _screen(canvas: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * canvas


func _center(control: Control) -> Vector2:
	if control == null:
		return Vector2.ZERO
	return _screen(control.get_global_rect().get_center())


func _disk(key: String) -> Variant:
	if not FileAccess.file_exists(PATH):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return (parsed as Dictionary).get(key) if parsed is Dictionary else null


func _wait_settled() -> void:
	var settle_msec: int = int(load("res://scripts/main.gd").get_script_constant_map().get("TOUCH_SETTLE_MSEC", 300))
	await _wait(float(settle_msec) / 1000.0 + 0.12)
	await _settle(1)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _strip_comments(code: String) -> String:
	var lines: PackedStringArray = []
	for line in code.split("\n"):
		var at: int = line.find("#")
		lines.append(line if at == -1 else line.substr(0, at))
	return "\n".join(lines)


## Fonksiyon gövdesi: başlıktan bir sonraki üst düzey `func` / `static func`'a kadar.
func _function(code: String, header: String) -> String:
	var start: int = code.find(header)
	if start < 0:
		return ""
	var end: int = code.find("\nfunc ", start + header.length())
	var end_static: int = code.find("\nstatic func ", start + header.length())
	if end < 0 or (end_static >= 0 and end_static < end):
		end = end_static
	return code.substr(start, (end if end >= 0 else code.length()) - start)


func _clean() -> void:
	for path in [PATH, PATH + SaveFile.TEMP_SUFFIX, PATH + SaveFile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _owner_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for path in [SaveManager.SAVE_PATH, SaveManager.SAVE_PATH + SaveFile.TEMP_SUFFIX,
			SaveManager.SAVE_PATH + SaveFile.BACKUP_SUFFIX]:
		out[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out
