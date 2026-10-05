extends Node
## TASK/055 — genel GUI ACTION_CANCEL sertleştirmesi: geçersiz bir dokunuş (Android ACTION_CANCEL; GERİ / gizleme / sekme
## değişimi / pencere kapanışı ile geçersizleşen yüzeyin bayat bırakışı; pencere odağı kaybı) uygulamanın sonuç doğuran
## hiçbir GUI eylemini çalıştırmaz: Hamur harcaması, ödül / talep, reklam, seviye / round başlangıcı ya da terki, tercih /
## uyum yazması, gezinme, pencere açma / kapama YOK; basış güvenle biter; sonraki taze dokunuş tam bir kez çalışır. Kod /
## klavye / erişilebilirlik etkinleştirmesi ve sonuçsuz doğal düğmeler aynen.
## Gerçek Main, gerçek ekranlar, gerçek parmak olayları (`Input.parse_input_event`, Android'deki gibi öykünülen fare).
## Headless. Taban (60f8b71) üzerinde de koşar: GestureGuard sınıfına statik başvuru YOK (sahiplik `gesture_guard`
## meta'sından okunur) — taban farkı betik hatasıyla değil, açık FAIL'lerle görünür.
## SAHİBİN GERÇEK KAYDINA DOKUNMAZ: SaveManager test boyunca `user://qa_gui_action_cancel/` altındaki bir yola
## yönlendirilir, sonda geri alınır; gerçek kayıt ailesi (kanonik + .tmp + .bak) başta / sonda bayt bayt karşılaştırılır.
##   godot --headless --audio-driver Dummy --path . res://tools/gui_action_cancel_test.tscn
##
## Kök neden (Faz A sondası, Godot 4.6.3): BaseButton ACTION_CANCEL bırakışını tıklama sayar (`canceled`a bakmaz); basılı
## bir düğme gizlenince ya da pencere odağı gidince Viewport ona iç aygıtlı bir bırakış yollar — son girdi işlenmemişse
## (cihazda GERİ tuşunun kendi olayı, bir ses tuşu) bu da tıklama olur, işlenmişse basış asılı kalır. Paylaşılan karartma
## kapanışı iptali ayırt etmiyordu. Uygulamanın `pressed` işleyicileri dokunuşun sahibine bakmıyordu.
##
## Geçersiz dizi kipleri (parmak 0, kontrolün ortası): "cancel" DOWN → ACTION_CANCEL → bayat UP · "back" DOWN → işlenmeyen
## olay (cihazdaki GERİ tuş olayı) → Android GERİ → bayat UP · "focus" DOWN → işlenmeyen olay → pencere odağı kaybı →
## dönüş → bayat UP · "focus_handled" DOWN → odak kaybı (son girdi işlenmiş) → dönüş → bayat UP. İptalden / odak
## kaybından sonraki bayat UP motor yolunda hiçbir kontrole ulaşmaz (fare / dokunuş odağı yok) — eksiksizlik için yollanır.
## GERİ ve odak bildirimleri cihaz yolu gibi dağıtılır (`_window_notify`: kökten aşağı, düğümleri meşgul işaretlemeden).
##
## Bölümler:
##   A Profil vitrini     dolu yuva iptal / GERİ / sekme değişimi → 0 gezinme, 0 detay; KOLEKSİYONA GİT, unvan, TÜM
##                        BAŞARIMLAR iptal / GERİ → 0; gizli Profil'de bayat pencere kalmaz; taze dokunuş tam bir kez
##   B Profil dişlisi     dişli / üst çubuk geri iptal / GERİ → Ayarlar açılmaz, gezinme yok; unvan satırı iptali unvan
##                        yazmaz; taze dokunuşlar tam bir kez
##   C Harita             düğüm iptal / GERİ → seviye başlamaz; "+" basılı + GERİ → Ana Sayfa görünür (boş ekran yok);
##                        Sonsuz iptali round başlatmaz; taze dokunuşlar tam bir kez
##   D Mağaza SATIN AL    kesin Hamur: kart iptali onay açmaz; onay SATIN AL iptal / odak kaybı / GERİ → 0 Hamur, stok
##                        aynı, kayıt dosyası bayt-aynı; geçerli dokunuş tam bir harcama (900 → 720); yinelenen fare +
##                        dokunuş bırakışı ikinci harcama yapmaz; kostüm onayı iptali; Vazgeç / X / karartma iptali
##                        pencereyi kapatmaz, karartma yalnız gerçek bırakışta kapatır
##   E İPTAL + bayat UP   Ana Sayfa düğmeleri, Görevler, günlük AÇ / REKLAM İZLE, MEYDAN OKUMA BAŞLA, yaş ONAYLA, Ayarlar
##                        anahtarı / Kapat, güç yuvası, HUD dişlisi, mola Yeniden Başlat / Çıkış, refill Hamur, devam
##                        reklamı, sonuç birincil, tutorial ATLA → 0 eylem, `pressed` / `toggled` doğmaz; taze tam bir kez
##   F gizleme / gezinme  basılı + GERİ (gizleyen ve gizlemeyen GERİ: Ana Sayfa'da çıkış isteği, oyunda mola) / sekme
##                        değişimi → bayat bırakış 0 eylem
##   G odak kaybı         motorun odak kaybındaki bayat tıklaması: Harita düğümü, vitrin yuvası, günlük AÇ, Ayarlar
##                        anahtarı (tercih yazılmaz, anahtar + topuz kayıttaki değerde kalır) → 0; işlenmiş girdide
##                        asılı basış biter, sonraki dokunuş button_down yayar
##   H taze dokunuş       gizlenen basılı STOP düğmede (son girdi işlenmiş) asılı basış kalmaz: dişli, onay SATIN AL
##   I doğal düğme        sonuçsuz düğmeler sahipsiz ve çalışır: Ayarlar Göster/Gizle, yaş ekranı DEVAM ET
##   J işaretçisiz        kodla `pressed` (erişilebilirlik tıklamasının yolu), klavye ui_accept, kodla anahtar → tam bir
##                        kez; gizli düğmeye ulaşan kod `pressed`'i eylemsiz
##   K çok parmak         düğmeler yalnız 0. parmağın öykünülen faresini görür; ikinci parmak düğmeye basamaz / başka
##                        düğmenin dokunuşunu bozmaz; tüm jest iptali (her parmağa, tek yığın) 0 harcama; tek-işaretçi
##                        iptali Android 13+'ta Godot'ya düz bırakış olarak gelir (motor sınırı — 2+ parmak, ör. avuç
##                        reddi); ikinci parmağın karartma dokunuşu basılı SATIN AL'ı geçersiz kılar; iki parmak tek kapanış
##   L ekonomi kaydı      iptal edilen refill / güç / Mağaza / günlük AÇ kayda dokunmaz; geçerli refill tam bir kez yazar
##   M gezinme            GERİ zinciri çalışır; karartma iptali + aynı jestin GERİ'si tek eylem (çıkış yok, ikinci
##                        gezinme yok); bayat pencere yeniden açılmaz
##   R çalışma anı        Faz A matrisinin her FIX düğmesi örneği sahipli, KEEP düğmeleri sahipsiz (gerçek Main ağacı)
##   P kaynak             sözleşme (yardımcı API, düğüm listesi, dokunulmayan yollar)
##   N kayıt              sahibin kayıt ailesi bayt-aynı

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DIR: String = "user://qa_gui_action_cancel"
const PATH: String = DIR + "/save.json"
const SECTIONS: int = 15
const MON: String = "2026-09-28"
const THU: String = "2026-10-01"
const BACK_GAP_MSEC: int = 320
const LEVEL_PATH: String = "res://resources/levels/level_08.tres"
const GUARD_META: StringName = &"gesture_guard"
const SHOWCASE_ID: StringName = &"rare_02"
const GUARD_PATH: String = "res://scripts/ui/gesture_guard.gd"

var _fails: int = 0
var _checks: int = 0
var _sections_done: int = 0
var _finished: bool = false
var _saved_data: Dictionary = {}
var _owner_state: Dictionary = {}
var _main: Node2D
## Sayaçlar ("etiket.sinyal") — `_mark` sıfırlar.
var _n: Dictionary = {}
## Sıralı olay kaydı ("ad@+ms") — `_mark` sıfırlar.
var _events: Array[String] = []
var _t0: int = 0
var _last_back_msec: int = -100000


## Ödüllü reklam sağlayıcısı test çifti: yalnız çağrıları sayar (reklam yok, ödül yok).
class StubProvider extends RefCounted:
	var calls: Array[String] = []

	func show_rewarded_daily_dough(_m: Variant, _day: Variant, _token: Variant) -> void:
		calls.append("daily_dough")

	func show_rewarded_daily_chest(_m: Variant, _day: Variant, _token: Variant) -> void:
		calls.append("daily_chest")

	func show_rewarded_revive(_m: Variant) -> void:
		calls.append("revive")

	func show_rewarded_power(_m: Variant, _type: Variant, _token: Variant) -> void:
		calls.append("power")


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
	get_tree().create_timer(600.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 600 s'de bitmedi — SaveManager geri alındı")
			if _main != null and is_instance_valid(_main):
				_main.free()
			_teardown()
			get_tree().quit(2))
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame

	await _profile_showcase()
	await _profile_gear()
	await _map()
	await _shop_buy()
	await _cancel_matrix()
	await _hide_navigation()
	await _focus_loss()
	await _fresh_after_hide()
	await _native_safe()
	await _non_pointer()
	await _multi_touch()
	await _economy()
	await _navigation()
	await _ownership_sweep()
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
	if not _finished:
		_teardown()


# --- A: Profil vitrini ---------------------------------------------------------------------------------------------

func _profile_showcase() -> void:
	print("-- A: Profil vitrin yuvası ve Profil eylemleri")
	await _boot()
	await _tab(4)
	var profile: CanvasLayer = _main._screens[4]
	var album: CanvasLayer = _main._screens[2]
	var slot: Button = profile.showcase_slots()[0]
	_watch(slot, "slot")
	_mark()
	await _gesture(slot, "cancel")
	_record("A1 yuva iptal")
	_c("A1 dolu vitrin yuvası ACTION_CANCEL + bayat UP: Profil'de kalındı, Koleksiyon / detay açılmadı, `pressed` doğmadı, basış bitti",
		_main._active_tab == 4 and not album.visible and not album.is_detail_open() and _count("slot.pressed") == 0
		and _count("slot.down") == 1 and _count("slot.up") >= 1)
	await _wait_settled()
	_mark()
	await _tap(slot)
	_c("A2 ardından taze dokunuş tam bir kez: Koleksiyon + parça detayı (button_down 1, detay 1)",
		_main._active_tab == 2 and album.is_detail_open() and album.detail_id() == SHOWCASE_ID
		and _count("slot.pressed") == 1 and _count("slot.down") == 1 and _count("album.detail_opened") == 1)

	await _boot()
	await _tab(4)
	profile = _main._screens[4]
	album = _main._screens[2]
	slot = profile.showcase_slots()[0]
	_watch(slot, "slot")
	_mark()
	await _gesture(slot, "back")
	_record("A3 yuva + GERİ")
	_c("A3 basılı yuva + GERİ + bırak: Ana Sayfa (GERİ çalıştı), Koleksiyon / detay açılmadı, `pressed` doğmadı",
		_main._active_tab == 0 and _main._screens[0].visible and not album.visible and not album.is_detail_open()
		and _count("slot.pressed") == 0)
	await _tab(4)
	_mark()
	await _tap(slot)
	_c("A4 yeniden açılan Profil'de taze dokunuş tam bir kez (button_down 1 — asılı basış yok)",
		_main._active_tab == 2 and album.is_detail_open() and _count("slot.down") == 1 and _count("album.detail_opened") == 1)

	await _boot()
	await _tab(4)
	profile = _main._screens[4]
	album = _main._screens[2]
	slot = profile.showcase_slots()[0]
	_watch(slot, "slot")
	_mark()
	await _finger(_center(slot), true)
	await _unhandled_key()
	_main._show_tab(3)
	await _settle(2)
	await _finger(_center(slot), false)
	await _settle(3)
	_record("A5 yuva + sekme değişimi")
	_c("A5 basılı yuva + sekme değişimi (Mağaza) + bırak: Mağaza'da kalındı, detay açılmadı, `pressed` doğmadı",
		_main._active_tab == 3 and not album.is_detail_open() and _count("slot.pressed") == 0)

	for mode: String in ["cancel", "back"]:
		await _boot()
		await _tab(4)
		profile = _main._screens[4]
		var cta: Button = profile.collection_cta()
		profile.scroll().ensure_control_visible(cta)
		await _wait_settled()
		_watch(cta, "cta")
		_pre("A6/A7 KOLEKSİYONA GİT [%s]" % mode, profile.visible and _main._active_tab == 4 and cta.is_visible_in_tree()
			and not profile.has_open_overlay())
		_mark()
		await _gesture(cta, mode)
		if mode == "cancel":
			_c("A6 KOLEKSİYONA GİT iptal + bayat UP: Profil'de kalındı", _main._active_tab == 4 and _count("cta.pressed") == 0)
		else:
			_c("A7 KOLEKSİYONA GİT basılı + GERİ + bırak: Ana Sayfa, Koleksiyon'a gidilmedi", _main._active_tab == 0
				and not _main._screens[2].visible and _count("cta.pressed") == 0)

	await _boot()
	await _tab(4)
	profile = _main._screens[4]
	var title: Button = profile.title_button()
	_watch(title, "title")
	_pre("A8 unvan", profile.visible and title.is_visible_in_tree() and not profile.has_open_overlay())
	_mark()
	await _gesture(title, "cancel")
	_c("A8 unvan düğmesi iptali: unvan seçici açılmadı", not profile.title_selector().visible and _count("title.pressed") == 0)

	await _boot()
	await _tab(4)
	profile = _main._screens[4]
	var achievements: Button = profile.achievements_cta()
	profile.scroll().ensure_control_visible(achievements)
	await _wait_settled()
	_watch(achievements, "achievements")
	_pre("A9 TÜM BAŞARIMLAR", profile.visible and achievements.is_visible_in_tree() and not profile.has_open_overlay())
	_mark()
	await _gesture(achievements, "cancel")
	_c("A9 TÜM BAŞARIMLAR iptali: başarım penceresi açılmadı", not profile.achievements_overlay().visible
		and _count("achievements.pressed") == 0)

	await _boot()
	await _tab(4)
	profile = _main._screens[4]
	title = profile.title_button()
	_watch(title, "title")
	_pre("A10 unvan", profile.visible and title.is_visible_in_tree() and not profile.has_open_overlay())
	_mark()
	await _gesture(title, "back")
	_c("A10 unvan düğmesi basılı + GERİ: Ana Sayfa, gizli Profil'de unvan seçici AÇILMADI", _main._active_tab == 0
		and not profile.title_selector().visible and not profile.has_open_overlay())
	await _tab(4)
	_c("A11 Profil'e dönüş: bayat pencere yok", not profile.has_open_overlay())
	_sections_done += 1


# --- B: Profil dişlisi ve benzer kontroller --------------------------------------------------------------------------

func _profile_gear() -> void:
	print("-- B: Profil dişlisi / üst çubuk / unvan satırı")
	await _boot()
	await _tab(4)
	var profile: CanvasLayer = _main._screens[4]
	var settings: CanvasLayer = _main._settings
	var gear: Button = profile.top_bar().action_button()
	_watch(gear, "gear")
	_mark()
	await _gesture(gear, "cancel")
	_record("B1 dişli iptal")
	_c("B1 dişli ACTION_CANCEL + bayat UP: Ayarlar açılmadı, Profil'de kalındı, `pressed` doğmadı", not settings.visible
		and _main._active_tab == 4 and _count("gear.pressed") == 0)
	await _gesture(gear, "back")
	_record("B2 dişli + GERİ")
	_c("B2 dişli basılı + GERİ + bırak: Ana Sayfa, Ayarlar AÇILMADI", _main._active_tab == 0 and not settings.visible
		and _count("gear.pressed") == 0)
	await _tab(4)
	_mark()
	await _tap(gear)
	_c("B3 taze dişli dokunuşu tam bir kez: Ayarlar açık (button_down 1)", settings.visible and _count("gear.down") == 1
		and _count("gear.pressed") == 1)
	_main.close_settings()
	await _wait_settled()
	var back: Button = profile.top_bar().back_button()
	_watch(back, "bar_back")
	_mark()
	await _gesture(back, "cancel")
	_c("B4 üst çubuk geri iptali: Profil'de kalındı", _main._active_tab == 4 and _count("bar_back.pressed") == 0)
	await _wait_settled()
	_mark()
	await _tap(back)
	_c("B5 taze üst çubuk geri: tam bir kez Ana Sayfa", _main._active_tab == 0 and _count("profile.home_requested") == 1)

	await _boot({"total_merges": 150, "unlocked_achievements": ["merge_10", "merge_100"]})
	await _tab(4)
	profile = _main._screens[4]
	profile.open_title_selector()
	await _wait_settled()
	var row: Button = profile.title_selector().row(&"hamur_ustasi")
	_watch(row, "row")
	var before: String = String(SaveManager.data.get("selected_title_id", ""))
	_mark()
	await _gesture(row, "cancel")
	_c("B6 unvan satırı iptali: unvan yazılmadı (bellek + disk), `pressed` doğmadı",
		String(SaveManager.data.get("selected_title_id", "")) == before and _disk("selected_title_id") != "hamur_ustasi"
		and _count("row.pressed") == 0)
	await _wait_settled()
	_mark()
	await _tap(row)
	_c("B7 taze satır dokunuşu tam bir kez: unvan Hamur Ustası (bellek + disk)",
		String(SaveManager.data.get("selected_title_id", "")) == "hamur_ustasi" and _disk("selected_title_id") == "hamur_ustasi"
		and _count("row.pressed") == 1)
	# Seçimden sonraki 350 ms seçici kilidi geçsin: aksi hâlde odak kaybı kontrolü kilide takılıp boşa geçerdi.
	await get_tree().create_timer(0.45).timeout
	var selector: Control = profile.title_selector()
	var default_row: Button = selector.row(&"birlestirici")
	_pre("B8 unvan satırı", selector.visible and default_row.is_visible_in_tree() and not default_row.disabled)
	await _gesture(default_row, "focus")
	_c("B8 unvan satırı basılı + odak kaybı: unvan yazılmadı (Hamur Ustası kaldı, bellek + disk)",
		String(SaveManager.data.get("selected_title_id", "")) == "hamur_ustasi" and _disk("selected_title_id") == "hamur_ustasi")
	var selector_x: Button = selector.frame().get_meta(&"close_button")
	_watch(selector_x, "selector_x")
	_mark()
	await _gesture(selector_x, "cancel")
	_c("B9 unvan seçici X iptali: seçici AÇIK kaldı, `pressed` doğmadı", selector.visible and _count("selector_x.pressed") == 0)
	selector.close()
	await _wait_settled()
	profile.open_achievements()
	await _wait_settled()
	var overlay: Control = profile.achievements_overlay()
	var overlay_x: Button = overlay.frame().get_meta(&"close_button")
	_watch(overlay_x, "overlay_x")
	_mark()
	await _gesture(overlay_x, "cancel")
	_c("B10 başarımlar penceresi X iptali: pencere AÇIK kaldı, `pressed` doğmadı", overlay.visible
		and _count("overlay_x.pressed") == 0)
	_sections_done += 1


# --- C: Harita -----------------------------------------------------------------------------------------------------------

func _map() -> void:
	print("-- C: Harita düğümü / üst çubuk / Sonsuz")
	await _boot()
	await _tab(1)
	var map: CanvasLayer = _main._screens[1]
	var node: Button = map.nodes()[0]
	_watch(node, "node")
	_mark()
	await _gesture(node, "cancel")
	_record("C1 düğüm iptal")
	_c("C1 Seviye 1 düğümü ACTION_CANCEL + bayat UP: seviye BAŞLAMADI, Harita'da kalındı, `pressed` doğmadı",
		not _board_live() and _main._active_tab == 1 and _count("node.pressed") == 0)
	await _gesture(node, "back")
	_record("C2 düğüm + GERİ")
	_c("C2 düğüm basılı + GERİ + bırak: Ana Sayfa, seviye başlamadı, `pressed` doğmadı", not _board_live()
		and _main._active_tab == 0 and _main._screens[0].visible and _count("node.pressed") == 0)
	await _tab(1)
	node = map.nodes()[0]
	_watch(node, "node")
	_mark()
	await _tap(node)
	_c("C3 taze düğüm dokunuşu tam bir kez: Seviye 1 başladı (level_chosen 1)", _board_live()
		and int(_main._current_level.level_number) == 1 and _count("map.level_chosen") == 1)

	await _boot()
	await _tab(1)
	map = _main._screens[1]
	var add: Button = map.top_bar().add_button()
	var back: Button = map.top_bar().back_button()
	_watch(add, "add")
	_watch(back, "map_back")
	_mark()
	await _gesture(add, "cancel")
	await _gesture(back, "cancel")
	_c("C4 üst çubuk \"+\" / geri iptali: Harita'da kalındı", _main._active_tab == 1 and _count("add.pressed") == 0
		and _count("map_back.pressed") == 0)

	await _boot()
	await _tab(1)
	map = _main._screens[1]
	add = map.top_bar().add_button()
	_watch(add, "add")
	_pre("C5 \"+\"", map.visible and _main._active_tab == 1 and add.is_visible_in_tree())
	_mark()
	await _gesture(add, "back")
	_record("C5 + basılı + GERİ")
	_c("C5 \"+\" basılı + GERİ + bırak: Ana Sayfa GÖRÜNÜR (boş ekran yok), Mağaza'ya gidilmedi", _main._active_tab == 0
		and _main._screens[0].visible and not _main._screens[3].visible and not map.visible)
	await _tab(1)
	_mark()
	await _tap(add)
	_c("C6 taze \"+\" dokunuşu tam bir kez: Mağaza", _main._active_tab == 3 and _count("map.shop_requested") == 1)

	await _boot({"highest_level_unlocked": 11, "level_stars": {"1": 3, "2": 3, "3": 3, "4": 3, "5": 3, "6": 3, "7": 3,
		"8": 3, "9": 3, "10": 3}})
	await _tab(1)
	map = _main._screens[1]
	var endless: Button = map.endless_node()
	_watch(endless, "endless")
	_mark()
	await _gesture(endless, "cancel")
	_c("C7 açık Sonsuz madalyonu iptali: round başlamadı", not _board_live() and _count("endless.pressed") == 0)
	await _gesture(endless, "back")
	_c("C9 Sonsuz basılı + GERİ + bırak: Ana Sayfa, round başlamadı", not _board_live() and _main._active_tab == 0
		and _count("endless.pressed") == 0)
	await _tab(1)
	endless = map.endless_node()
	_watch(endless, "endless")
	await _gesture(endless, "focus")
	_c("C10 Sonsuz basılı + odak kaybı: round başlamadı, Harita'da kalındı", not _board_live() and _main._active_tab == 1)
	await _wait_settled()
	await _tap(endless)
	_c("C8 taze Sonsuz dokunuşu: round başladı (pozitif kontrol)", _board_live() and _count("map.level_chosen") == 1)
	_sections_done += 1


# --- D: Mağaza SATIN AL ------------------------------------------------------------------------------------------------

func _shop_buy() -> void:
	print("-- D: Mağaza SATIN AL (Hamur)")
	await _boot()
	await _tab(3)
	var shop: CanvasLayer = _main._screens[3]
	var card_buy: Button = shop.power_card(PowerUp.Type.UPGRADE).buy_button()
	var yes: Button = shop.get("_confirm_yes")
	_watch(card_buy, "card_buy")
	_watch(yes, "yes")
	_c("D0 ön koşul: Hamur 900, Büyütücü 2 (bellek + disk)", SaveManager.dough() == 900
		and SaveManager.powerup_count(PowerUp.Type.UPGRADE) == 2 and _disk_dough() == 900)
	_mark()
	await _gesture(card_buy, "cancel")
	_c("D1 kart SATIN AL iptali: onay penceresi AÇILMADI", not shop.is_confirm_open() and _count("card_buy.pressed") == 0)
	await _wait_settled()
	await _tap(card_buy)
	await _wait_settled()
	_c("D2 (pozitif) gerçek kart dokunuşu onayı açtı: Bakiye 900 → 720", shop.is_confirm_open()
		and shop.confirm_balance_text().contains("900") and shop.confirm_balance_text().contains("720"))
	var bytes: PackedByteArray = _save_bytes()
	_mark()
	await _gesture(yes, "cancel")
	_record("D3 onay iptal")
	_c("D3 onay SATIN AL ACTION_CANCEL + bayat UP: Hamur 900 (bellek + disk), Büyütücü 2, kayıt dosyası bayt-aynı, pencere açık, `pressed` doğmadı",
		_econ_is(900, 2) and _save_bytes() == bytes and shop.is_confirm_open() and _count("yes.pressed") == 0)
	_mark()
	await _gesture(yes, "focus")
	_record("D4 onay odak kaybı")
	_c("D4 onay SATIN AL basılı + işlenmeyen olay + pencere odağı kaybı (motorun bayat tıklaması): harcama yok, dosya bayt-aynı",
		_econ_is(900, 2) and _save_bytes() == bytes)
	await _ensure_confirm(shop, card_buy)
	_mark()
	await _gesture(yes, "back")
	_record("D5 onay + GERİ")
	_c("D5 onay SATIN AL basılı + GERİ + bırak: pencere GERİ ile kapandı, Mağaza'da kalındı, harcama yok, dosya bayt-aynı",
		not shop.is_confirm_open() and _main._active_tab == 3 and _econ_is(900, 2) and _save_bytes() == bytes)
	await _ensure_confirm(shop, card_buy)
	_mark()
	await _tap(yes)
	_c("D6 taze geçerli SATIN AL tam bir harcama: Hamur 900 → 720 (−180), Büyütücü 2 → 3 (bellek + disk), pencere kapandı",
		_econ_is(720, 3) and not shop.is_confirm_open() and _count("yes.pressed") == 1)
	await _duplicate_release(_center(yes))
	_c("D7 aynı noktaya yinelenen fare + dokunuş bırakışı: ikinci harcama YOK (720 / 3)", _econ_is(720, 3)
		and _count("yes.pressed") == 1)
	await _ensure_confirm(shop, card_buy)
	var bytes2: PackedByteArray = _save_bytes()
	var no: Button = shop.get("_confirm_no")
	var x: Button = shop.confirm_frame().get_meta(&"close_button")
	_watch(no, "no")
	_watch(x, "x")
	_mark()
	await _gesture(no, "cancel")
	await _gesture(x, "cancel")
	_c("D8 Vazgeç / X iptali: pencere AÇIK kaldı, harcama yok", shop.is_confirm_open() and _count("no.pressed") == 0
		and _count("x.pressed") == 0 and _econ_is(720, 3))
	var dim_at: Vector2 = _shop_dim_point(shop)
	await _finger(dim_at, true)
	await _settle(2)
	var open_after_press: bool = shop.is_confirm_open()
	await _cancel_finger(dim_at)
	await _finger(dim_at, false)
	await _settle(3)
	_c("D9 karartma: basış kapatmaz, ACTION_CANCEL kapatmaz (bayat UP dahil)", open_after_press and shop.is_confirm_open())
	await _finger(dim_at, true)
	await _finger(dim_at, false)
	await _settle(3)
	_c("D10 (pozitif) karartmada gerçek dokunuş = Vazgeç: pencere kapandı, harcama yok, dosya aynı", not shop.is_confirm_open()
		and _econ_is(720, 3) and _save_bytes() == bytes2)

	var skin: SkinData = SkinLibrary.find(&"common_02")
	shop.call("_open_confirm", skin)
	await _wait_settled()
	_mark()
	await _gesture(yes, "cancel")
	_c("D11 kostüm onayı SATIN AL iptali: kostüm açılmadı, Hamur 720 (bellek + disk)",
		not SaveManager.owns_skin(&"common_02") and SaveManager.dough() == 720 and _disk_dough() == 720)
	await _wait_settled()
	await _tap(yes)
	_c("D12 taze kostüm SATIN AL tam bir kez: kostüm açık, Hamur 720 → 670 (−50, disk)",
		SaveManager.owns_skin(&"common_02") and SaveManager.dough() == 670 and _disk_dough() == 670)
	_sections_done += 1


# --- E: İPTAL + bayat UP ---------------------------------------------------------------------------------------------

func _cancel_matrix() -> void:
	print("-- E: ACTION_CANCEL + bayat UP (sonra taze dokunuş)")
	await _boot()
	await _tab(0)
	var home: CanvasLayer = _main._screens[0]
	for spec: Array in [["OYNA", home.play_button(), 1, "home.play_pressed"],
			["Mağaza madalyonu", home.feature_button(&"shop"), 3, "home.shop_requested"],
			["avatar", home.profile_button(), 4, "home.profile_requested"],
			["Hamur +", home.dough_pill().get_meta(&"add_button"), 3, "home.shop_requested"],
			["Koleksiyon madalyonu", home.feature_button(&"collection"), 2, "home.collection_requested"],
			["seviye hapı", home.level_button(), 1, "home.map_requested"]]:
		var button: Button = spec[1]
		var tag: String = "home_%s" % String(spec[0])
		_watch(button, tag)
		_mark()
		await _gesture(button, "cancel")
		var stayed: bool = _main._active_tab == 0 and _count(String(spec[3])) == 0 and _count(tag + ".pressed") == 0
		await _wait_settled()
		_mark()
		await _tap(button)
		_c("E Ana Sayfa %s: iptal + bayat UP → Ana Sayfa'da kalındı; taze dokunuş tam bir kez → sekme %d" % [spec[0], spec[2]],
			stayed and _main._active_tab == int(spec[2]) and _count(String(spec[3])) == 1)
		await _tab(0)
	var missions: Button = home.missions_button()
	_watch(missions, "missions")
	_mark()
	await _gesture(missions, "cancel")
	var closed: bool = not _main._missions.visible and _count("missions.pressed") == 0
	await _wait_settled()
	await _tap(missions)
	_c("E Ana Sayfa GÖREVLER: iptal → pencere açılmadı; taze → açıldı", closed and _main._missions.visible)

	await _boot(_daily_fixture())
	await _tab(0)
	_main.open_daily_rewards()
	await _wait_settled()
	var free: Button = _main._daily_rewards.free_button()
	_watch(free, "free")
	_mark()
	await _gesture(free, "cancel")
	var unclaimed: bool = not _free_claimed() and _disk_free_claimed() != true and _count("free.pressed") == 0
	await _wait_settled()
	await _tap(free)
	_c("E günlük AÇ (ücretsiz sandık): iptal → talep YOK (bellek + disk); taze → tam bir talep", unclaimed
		and _free_claimed() and _disk_free_claimed() == true and _count("free.pressed") == 1)

	await _boot(_daily_fixture())
	var stub := StubProvider.new()
	_main.set_rewarded_provider(stub)
	await _tab(0)
	_main.open_daily_rewards()
	await _wait_settled()
	var ad: Button = _main._daily_rewards.dough_button()
	_watch(ad, "ad")
	_mark()
	await _gesture(ad, "cancel")
	var no_ad: bool = stub.calls.is_empty() and _count("ad.pressed") == 0
	await _gesture(ad, "focus")
	no_ad = no_ad and stub.calls.is_empty()
	await _wait_settled()
	await _tap(ad)
	_c("E günlük REKLAM İZLE (+Hamur): iptal / odak kaybı → reklam isteği YOK; taze → tam bir istek", no_ad
		and stub.calls == ["daily_dough"])

	await _boot()
	await _tab(0)
	_main.open_daily_challenge()
	await _wait_settled()
	var start: Button = _main._challenge_sheet.start_button()
	_watch(start, "start")
	_mark()
	await _gesture(start, "cancel")
	var no_round: bool = not _board_live() and _main._challenge_sheet.visible and _count("start.pressed") == 0
	await _wait_settled()
	await _tap(start)
	_c("E MEYDAN OKUMA BAŞLA: iptal → round başlamadı, pencere açık; taze → meydan okuma başladı", no_round and _board_live())

	await _boot()
	await _tab(4)
	var panel: CanvasLayer = await _age_to_confirm()
	var confirm: Button = panel.confirm_button()
	_watch(confirm, "age_confirm")
	_mark()
	await _gesture(confirm, "cancel")
	var adult: bool = String(SaveManager.data.get("age_ad_band", "")) == "ADULT" and _disk("age_ad_band") == "ADULT" \
		and _count("age_confirm.pressed") == 0
	await _wait_settled()
	await _tap(confirm)
	_c("E yaş ONAYLA (yeniden giriş): iptal → bant YAZILMADI (ADULT, disk); taze → TEEN tam bir kez (disk)", adult
		and String(SaveManager.data.get("age_ad_band", "")) == "TEEN" and _disk("age_ad_band") == "TEEN"
		and _count("age_confirm.pressed") == 1)

	await _boot()
	await _tab(4)
	_main.open_settings()
	await _wait_settled()
	var settings: CanvasLayer = _main._settings
	var sfx: Button = settings.get("_sfx_toggle")
	_watch(sfx, "sfx")
	_mark()
	await _gesture(sfx, "cancel")
	var kept: bool = SaveManager.sfx_enabled() and sfx.button_pressed and _count("sfx.toggled") == 0 \
		and _disk("sfx_enabled") != false
	await _wait_settled()
	await _tap(sfx)
	_c("E Ayarlar Ses Efektleri anahtarı: iptal → tercih yazılmadı, anahtar dönmedi (`toggled` yok); taze → kapandı (disk)",
		kept and not SaveManager.sfx_enabled() and not sfx.button_pressed and _disk("sfx_enabled") == false
		and _count("sfx.toggled") == 1)
	var close: Button = settings.get("_close")
	_watch(close, "settings_close")
	_mark()
	await _gesture(close, "cancel")
	var still_open: bool = settings.visible
	await _wait_settled()
	await _tap(close)
	_c("E Ayarlar Kapat: iptal → pencere açık kaldı; taze → kapandı", still_open and not settings.visible)

	await _boot()
	var board: Node2D = await _start_round()
	_spawn(board)
	var slot: Button = board.get_node("HUD").power_bar.slot(PowerUp.Type.SHAKE)
	var hud_gear: Button = board.get_node("HUD").settings_button
	_watch(slot, "shake")
	_watch(hud_gear, "hud_gear")
	_mark()
	await _gesture(slot, "cancel")
	var stock_kept: bool = SaveManager.powerup_count(PowerUp.Type.SHAKE) == 1 and _count("shake.pressed") == 0
	await _gesture(hud_gear, "cancel")
	var no_settings: bool = not _main._settings.visible and _count("hud_gear.pressed") == 0
	_c("E güç yuvası (Sarsıntı) + HUD dişlisi iptali: stok 1 (harcanmadı), Ayarlar açılmadı", stock_kept and no_settings)
	await _wait_settled()
	await _tap(slot)
	_c("E taze Sarsıntı dokunuşu: güç tam bir kez kullanıldı (stok 1 → 0)", SaveManager.powerup_count(PowerUp.Type.SHAKE) == 0
		and _count("shake.pressed") == 1)
	await get_tree().create_timer(0.6).timeout
	_main.open_pause_menu()
	await _wait_settled()
	var restart: Button = _main._pause.get("_restart")
	var exit: Button = _main._pause.get("_exit")
	_watch(restart, "restart")
	_watch(exit, "exit")
	_mark()
	await _gesture(restart, "cancel")
	await _gesture(exit, "cancel")
	_c("E mola Yeniden Başlat / Ana Menüye Dön iptali: round terk edilmedi (aynı board), mola açık",
		_main._board == board and _board_live() and _main.is_pause_open() and _count("restart.pressed") == 0
		and _count("exit.pressed") == 0)
	await _gesture(restart, "back")
	_c("E mola Yeniden Başlat basılı + GERİ (mola kapanır) + bırak: round yeniden başlamadı (aynı board)",
		_main._board == board and _board_live() and not _main.is_pause_open() and _count("restart.pressed") == 0)
	_main.open_pause_menu()
	await _wait_settled()
	await _tap(restart)
	_c("E taze Yeniden Başlat: tam bir yeniden başlatma (yeni board)", _board_live() and _main._board != board)

	await _boot({"powerups": {"bomb": 0, "upgrade": 0, "shake": 0, "clear_small": 0}})
	board = await _start_round()
	_spawn(board)
	await _tap(board.get_node("HUD").power_bar.slot(PowerUp.Type.SHAKE))
	await _wait_settled()
	var dough_buy: Button = _main._refill.get("_dough")
	_watch(dough_buy, "refill_dough")
	_mark()
	await _gesture(dough_buy, "cancel")
	var refill_kept: bool = SaveManager.dough() == 900 and SaveManager.powerup_count(PowerUp.Type.SHAKE) == 0 \
		and _disk_dough() == 900 and _main._refill.visible and _count("refill_dough.pressed") == 0
	await _wait_settled()
	await _tap(dough_buy)
	_c("E refill Hamur ile SATIN AL: iptal → 0 Hamur (bellek + disk), stok 0, pencere açık; taze → tam bir alım (900 → 800, stok 1)",
		refill_kept and SaveManager.dough() == 800 and SaveManager.powerup_count(PowerUp.Type.SHAKE) == 1 and _disk_dough() == 800)

	await _boot()
	stub = StubProvider.new()
	_main.set_rewarded_provider(stub)
	board = await _start_round()
	_main._on_revive_offered(1)
	await _wait_settled()
	var cont: Button = _main._revive.continue_button()
	_watch(cont, "revive")
	_mark()
	await _gesture(cont, "cancel")
	var no_revive_ad: bool = stub.calls.is_empty() and _main._revive.visible and _count("revive.pressed") == 0
	await _gesture(cont, "focus")
	no_revive_ad = no_revive_ad and stub.calls.is_empty() and _main._revive.visible
	await _wait_settled()
	await _tap(cont)
	_c("E devam teklifi DEVAM ET: iptal / odak kaybı → reklam isteği YOK, teklif açık; taze → tam bir istek", no_revive_ad
		and stub.calls == ["revive"])

	await _boot()
	board = await _start_round()
	_main._on_round_finished(true)
	await get_tree().create_timer(1.6).timeout
	await _wait_settled()
	var primary: Button = _main._result.primary_button()
	_watch(primary, "primary")
	_mark()
	await _gesture(primary, "cancel")
	var result_kept: bool = _main._result.visible and _count("primary.pressed") == 0
	await _wait_settled()
	await _tap(primary)
	_c("E sonuç birincil düğmesi: iptal → karar ekranı açık kaldı; taze → tam bir kez işledi", result_kept
		and not _main._result.visible and _count("primary.pressed") == 1)

	await _boot({"onboarding_completed": false, "highest_level_unlocked": 1, "total_rounds_played": 0, "level_stars": {}})
	await _wait_settled()
	await _wait_settled()
	var skip: Button = _main._tutorial_overlay.skip_button()
	_watch(skip, "skip")
	_mark()
	await _gesture(skip, "cancel")
	var still_tutorial: bool = not SaveManager.onboarding_completed() and _main.is_tutorial_active() \
		and _count("skip.pressed") == 0
	await _wait_settled()
	await _tap(skip)
	_c("E tutorial ATLA: iptal → onboarding tamamlanmadı (tutorial sürüyor); taze → atlandı (disk)", still_tutorial
		and SaveManager.onboarding_completed() and _disk("onboarding_completed") == true)
	_sections_done += 1


# --- F: gizleme / gezinme ile geçersizleşme ------------------------------------------------------------------------

func _hide_navigation() -> void:
	print("-- F: basılı + GERİ / sekme değişimi → bayat bırakış")
	await _boot()
	await _tab(0)
	var home: CanvasLayer = _main._screens[0]
	var play: Button = home.play_button()
	_watch(play, "play")
	var quits: int = _main.quit_requests
	_mark()
	await _gesture(play, "back")
	_record("F1 OYNA + GERİ")
	_c("F1 OYNA basılı + GERİ (Ana Sayfa'da çıkış isteği, ekran gizlenmez) + bırak: Harita'ya GİDİLMEDİ",
		_main.quit_requests == quits + 1 and _main._active_tab == 0 and _count("home.play_pressed") == 0)

	await _boot()
	await _tab(3)
	var shop: CanvasLayer = _main._screens[3]
	var card_buy: Button = shop.power_card(PowerUp.Type.UPGRADE).buy_button()
	_watch(card_buy, "card_buy")
	_mark()
	await _gesture(card_buy, "back")
	_c("F2 kart SATIN AL basılı + GERİ: Ana Sayfa, gizli Mağaza'da onay açılmadı", _main._active_tab == 0
		and not shop.is_confirm_open() and _count("card_buy.pressed") == 0)
	await _tab(3)
	_c("F3 Mağaza'ya dönüş: bayat onay penceresi yok", not shop.is_confirm_open())

	await _boot(_daily_fixture())
	await _tab(0)
	_main.open_daily_rewards()
	await _wait_settled()
	var free: Button = _main._daily_rewards.free_button()
	_mark()
	await _gesture(free, "back")
	_c("F4 günlük AÇ basılı + GERİ: pencere kapandı, ücretsiz sandık TALEP EDİLMEDİ (bellek + disk)",
		not _main._daily_rewards.visible and not _free_claimed() and _disk_free_claimed() != true)

	await _boot()
	var board: Node2D = await _start_round()
	_spawn(board)
	var hud_gear: Button = board.get_node("HUD").settings_button
	var slot: Button = board.get_node("HUD").power_bar.slot(PowerUp.Type.SHAKE)
	_watch(hud_gear, "hud_gear")
	_watch(slot, "shake")
	_mark()
	await _gesture(hud_gear, "back")
	_record("F5 HUD dişlisi + GERİ")
	_c("F5 HUD dişlisi basılı + GERİ (mola açılır, HUD gizlenmez) + bırak: Ayarlar AÇILMADI",
		_main.is_pause_open() and not _main._settings.visible and _count("hud_gear.pressed") == 0)
	_main.resume_game()
	await _wait_settled()
	_mark()
	await _gesture(slot, "back")
	_c("F6 güç yuvası basılı + GERİ (mola) + bırak: güç kullanılmadı (stok 1)",
		SaveManager.powerup_count(PowerUp.Type.SHAKE) == 1 and _count("shake.pressed") == 0)

	await _boot({"onboarding_completed": false, "highest_level_unlocked": 1, "total_rounds_played": 0, "level_stars": {}})
	await _wait_settled()
	await _wait_settled()
	var skip: Button = _main._tutorial_overlay.skip_button()
	_mark()
	await _gesture(skip, "back")
	_c("F7 tutorial ATLA basılı + GERİ + bırak: onboarding tamamlanmadı (disk), tutorial sürüyor",
		not SaveManager.onboarding_completed() and _disk("onboarding_completed") != true and _main.is_tutorial_active())

	await _boot()
	await _tab(4)
	_main.open_settings()
	await _wait_settled()
	var sfx: Button = _main._settings.get("_sfx_toggle")
	_watch(sfx, "sfx")
	_mark()
	await _gesture(sfx, "back")
	_c("F8 Ayarlar anahtarı basılı + GERİ: pencere kapandı, tercih yazılmadı, `toggled` doğmadı", not _main._settings.visible
		and SaveManager.sfx_enabled() and _disk("sfx_enabled") != false and _count("sfx.toggled") == 0)

	await _boot()
	await _tab(1)
	var node: Button = _main._screens[1].nodes()[0]
	_watch(node, "node")
	_mark()
	await _finger(_center(node), true)
	await _unhandled_key()
	_main._show_tab(0)
	await _settle(2)
	await _finger(_center(node), false)
	await _settle(3)
	_c("F9 düğüm basılı + sekme değişimi (Ana Sayfa) + bırak: seviye başlamadı", not _board_live()
		and _main._active_tab == 0 and _count("node.pressed") == 0)
	_sections_done += 1


# --- G: pencere odağı kaybı --------------------------------------------------------------------------------------------

func _focus_loss() -> void:
	print("-- G: pencere odağı kaybı (Android onPause) — motorun bayat tıklaması")
	await _boot()
	await _tab(1)
	var node: Button = _main._screens[1].nodes()[0]
	_watch(node, "node")
	_mark()
	await _gesture(node, "focus")
	_record("G1 düğüm odak")
	_c("G1 Harita düğümü basılı + işlenmeyen olay + odak kaybı + bırak: seviye başlamadı", not _board_live())
	await _tab(4)
	var profile: CanvasLayer = _main._screens[4]
	var slot: Button = profile.showcase_slots()[0]
	await _gesture(slot, "focus")
	_c("G2 vitrin yuvası odak kaybı: Koleksiyon'a gidilmedi, detay yok", _main._active_tab == 4
		and not _main._screens[2].is_detail_open())

	await _boot(_daily_fixture())
	await _tab(0)
	_main.open_daily_rewards()
	await _wait_settled()
	await _gesture(_main._daily_rewards.free_button(), "focus")
	_c("G3 günlük AÇ odak kaybı: talep yok (bellek + disk)", not _free_claimed() and _disk_free_claimed() != true)

	await _boot()
	await _tab(4)
	_main.open_settings()
	await _wait_settled()
	var sfx: Button = _main._settings.get("_sfx_toggle")
	_mark()
	await _gesture(sfx, "focus")
	await get_tree().create_timer(0.3).timeout
	_c("G4 Ayarlar anahtarı odak kaybı: tercih yazılmadı (bellek + disk), anahtar ve topuz kayıttaki değerde (açık)",
		SaveManager.sfx_enabled() and _disk("sfx_enabled") != false and sfx.button_pressed
		and is_equal_approx(float(sfx.get("_knob")), 1.0))
	await _wait_settled()
	await _tap(sfx)
	_c("G5 ardından taze anahtar dokunuşu tam bir kez: kapandı (disk)", not SaveManager.sfx_enabled()
		and _disk("sfx_enabled") == false and not sfx.button_pressed)
	await get_tree().create_timer(0.3).timeout
	await _gesture(sfx, "focus")
	await get_tree().create_timer(0.3).timeout
	_c("G6 geçerli dokunuştan SONRA aynı anahtarda odak kaybı: önceki bırakış yeni basışa geçmez — tercih yazılmadı (kapalı, disk), anahtar + topuz kapalı",
		not SaveManager.sfx_enabled() and _disk("sfx_enabled") == false and not sfx.button_pressed
		and is_equal_approx(float(sfx.get("_knob")), 0.0))
	var probe: UiToggle = UiKit.switch_toggle(true)
	add_child(probe)
	await _settle(1)
	probe.button_pressed = false
	probe.set_on(true)
	await get_tree().create_timer(0.3).timeout
	_c("G7 UiToggle.set_on süren topuz animasyonunu durdurur (bağlantı sırasından bağımsız geri alma): anahtar + topuz açık",
		probe.button_pressed and is_equal_approx(float(probe.get("_knob")), 1.0))
	probe.queue_free()

	await _boot({"powerups": {"bomb": 0, "upgrade": 2, "shake": 2, "clear_small": 1}})
	var board: Node2D = await _start_round()
	_spawn(board)
	var shake: Button = board.get_node("HUD").power_bar.slot(PowerUp.Type.SHAKE)
	await _tap(shake)
	var used_once: bool = SaveManager.powerup_count(PowerUp.Type.SHAKE) == 1
	await get_tree().create_timer(0.6).timeout
	_spawn(board)
	await _settle(2)
	_pre("G8 Sarsıntı yuvası", shake.is_visible_in_tree() and not shake.disabled)
	await _gesture(shake, "focus")
	var powerups: Variant = _disk("powerups")
	_c("G8 geçerli Sarsıntı dokunuşundan SONRA aynı yuvada odak kaybı: ikinci kullanım YOK (stok 2 → 1, disk 1)", used_once
		and SaveManager.powerup_count(PowerUp.Type.SHAKE) == 1 and powerups is Dictionary
		and int((powerups as Dictionary).get("shake", -1)) == 1)

	await _boot()
	await _tab(4)
	var gear: Button = _main._screens[4].top_bar().action_button()
	_watch(gear, "gear")
	_mark()
	await _gesture(gear, "focus_handled")
	_record("G9 dişli odak (işlenmiş)")
	_c("G9 dişli basılı + odak kaybı (son girdi işlenmiş) + bırak: Ayarlar açılmadı", not _main._settings.visible
		and _count("gear.pressed") == 0)
	await _wait_settled()
	_mark()
	await _tap(gear)
	_c("G10 ardından taze dişli dokunuşu: button_down 1 (asılı basış yok) ve Ayarlar tam bir kez",
		_count("gear.down") == 1 and _main._settings.visible and _count("gear.pressed") == 1)

	# Paylaşılan üst çubuk tüketici tarafında sahipli (own + allows): odak kaybının bayat tıklaması röleden geçse de gezinmez.
	await _boot()
	await _tab(4)
	await _gesture(_main._screens[4].top_bar().back_button(), "focus")
	_c("G11 Profil üst çubuk geri odak kaybı: Profil'de kalındı", _main._active_tab == 4)
	await _tab(1)
	await _gesture(_main._screens[1].top_bar().add_button(), "focus")
	await _gesture(_main._screens[1].top_bar().back_button(), "focus")
	_c("G12 Harita üst çubuk \"+\" / geri odak kaybı: Harita'da kalındı", _main._active_tab == 1)
	await _tab(3)
	await _gesture(_main._screens[3].top_bar().back_button(), "focus")
	_c("G13 Mağaza üst çubuk geri odak kaybı: Mağaza'da kalındı", _main._active_tab == 3)
	_sections_done += 1


# --- H: gizlenen basılı düğmede asılı basış kalmaz ------------------------------------------------------------------

func _fresh_after_hide() -> void:
	print("-- H: gizlenen basılı STOP düğme (son girdi işlenmiş) → sonraki dokunuş tam bir kez")
	await _boot()
	await _tab(4)
	var gear: Button = _main._screens[4].top_bar().action_button()
	_watch(gear, "gear")
	_mark()
	await _finger(_center(gear), true)
	_main._show_tab(0)
	await _settle(2)
	await _finger(_center(gear), false)
	await _settle(3)
	_record("H1 dişli gizleme")
	_c("H1 dişli basılı + Profil gizlendi (işlenmiş son girdi) + bırak: Ayarlar açılmadı", not _main._settings.visible)
	await _tab(4)
	_mark()
	await _tap(gear)
	_c("H2 Profil'e dönüş, taze dişli dokunuşu: button_down 1 (basış asılı kalmadı), Ayarlar tam bir kez",
		_count("gear.down") == 1 and _main._settings.visible and _count("gear.pressed") == 1)

	await _boot()
	await _tab(3)
	var shop: CanvasLayer = _main._screens[3]
	var card_buy: Button = shop.power_card(PowerUp.Type.UPGRADE).buy_button()
	await _ensure_confirm(shop, card_buy)
	var yes: Button = shop.get("_confirm_yes")
	_watch(yes, "yes")
	_mark()
	await _finger(_center(yes), true)
	shop.handle_back()
	await _settle(2)
	await _finger(_center(yes), false)
	await _settle(3)
	_c("H3 onay SATIN AL basılı + pencere kapandı + bırak: harcama yok", _econ_is(900, 2) and not shop.is_confirm_open())
	await _ensure_confirm(shop, card_buy)
	_mark()
	await _tap(yes)
	_c("H4 yeniden açılan onayda taze SATIN AL: button_down 1, tam bir harcama (900 → 720)", _count("yes.down") == 1
		and _econ_is(720, 3))

	# Açık geçersizleştirme API'si (statik başvuru yok: taban ağacında yardımcı yoksa açık FAIL).
	var guard_script: Script = load(GUARD_PATH) if ResourceLoader.exists(GUARD_PATH) else null
	await _boot()
	await _tab(1)
	var node: Button = _main._screens[1].nodes()[0]
	await _finger(_center(node), true)
	if guard_script != null:
		guard_script.invalidate(node)
	await _finger(_center(node), false)
	await _settle(3)
	var invalidated: bool = guard_script != null and not _board_live() and _main._active_tab == 1
	await _wait_settled()
	await _tap(node)
	_c("H5 GestureGuard.invalidate (açık geçersizleştirme): basılı düğüm bırakılınca seviye başlamadı; taze dokunuş tam bir kez",
		invalidated and _board_live() and _count("map.level_chosen") == 1)

	# Basılıyken ağaçtan çıkıp dönen sahipli düğme: motor basışı çıkışta sıfırlar (button_up yaymadan) — sahiplik de.
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var plain := Button.new()
	plain.position = Vector2(260.0, 560.0)
	plain.size = Vector2(200.0, 80.0)
	layer.add_child(plain)
	var fired: Array[int] = [0]
	if guard_script != null:
		guard_script.on_pressed(plain, func() -> void: fired[0] += 1)
	await _settle(2)
	var at: Vector2 = _center(plain)
	await _finger(at, true)
	layer.remove_child(plain)
	await _settle(1)
	layer.add_child(plain)
	await _settle(1)
	plain.pressed.emit()
	await _settle(1)
	await _finger(at, false)
	await _settle(2)
	_c("H6 basılıyken ağaçtan çıkıp dönen sahipli düğme: kod / erişilebilirlik `pressed`'i tam bir kez çalışır (asılı sahiplik kalmaz)",
		guard_script != null and fired[0] == 1)
	layer.queue_free()
	_sections_done += 1


# --- I: sonuçsuz doğal düğmeler -----------------------------------------------------------------------------------------

func _native_safe() -> void:
	print("-- I: sonuçsuz doğal düğmeler sahipsiz kalır ve çalışır")
	await _boot()
	await _tab(4)
	_main.open_settings()
	await _wait_settled()
	var settings: CanvasLayer = _main._settings
	var privacy_button: Button = settings.get("_privacy_button")
	var privacy: Control = settings.get("_privacy")
	_c("I1 Ayarlar Göster/Gizle (pencere içi metin) sahipsiz: gesture_guard meta'sı / bileşeni yok", not _owned(privacy_button))
	await _tap(privacy_button)
	var opened: bool = privacy.visible
	await _wait_settled()
	await _tap(privacy_button)
	_c("I2 Göster/Gizle normal dokunuşla çalışır: açıldı, sonra kapandı", opened and not privacy.visible)
	var sfx: Button = settings.get("_sfx_toggle")
	_c("I3 karşılaştırma: sonuç doğuran anahtar sahipli (gesture_guard)", _owned(sfx))
	_main.close_settings()
	await _wait_settled()
	var panel: CanvasLayer = await _age_to_entry_complete()
	var cont: Button = panel.continue_button()
	_c("I4 yaş ekranı DEVAM ET (pencere içi adım; kayıt ONAYLA'da) sahipsiz", not _owned(cont))
	await _tap(cont)
	_c("I5 DEVAM ET normal dokunuşla çalışır: onay adımı", int(panel.stage()) == 2)
	_sections_done += 1


# --- J: işaretçisiz etkinleştirme -------------------------------------------------------------------------------------

func _non_pointer() -> void:
	print("-- J: kod / erişilebilirlik / klavye etkinleştirmesi")
	await _boot()
	await _tab(0)
	var home: CanvasLayer = _main._screens[0]
	var play: Button = home.play_button()
	_mark()
	play.pressed.emit()
	await _settle(3)
	_c("J1 görünür OYNA'ya kodla `pressed` (erişilebilirlik tıklamasının yolu): tam bir kez Harita", _main._active_tab == 1
		and _count("home.play_pressed") == 1)
	await _tab(0)
	play.focus_mode = Control.FOCUS_ALL
	play.grab_focus()
	await _settle(1)
	_mark()
	for down: bool in [true, false]:
		var action := InputEventAction.new()
		action.action = &"ui_accept"
		action.pressed = down
		Input.parse_input_event(action)
		Input.flush_buffered_events()
		await _settle(1)
	await _settle(2)
	_c("J2 klavye ui_accept (odaklanabilir yapılan OYNA): tam bir kez Harita", _main._active_tab == 1
		and _count("home.play_pressed") == 1)
	play.focus_mode = Control.FOCUS_NONE
	var node: Button = _main._screens[1].nodes()[0]
	await _tab(0)
	node.pressed.emit()
	await _settle(3)
	_c("J3 GİZLİ Harita düğümüne kodla `pressed`: seviye başlamadı", not _board_live())
	var slot: Button = _main._screens[4].showcase_slots()[0]
	slot.pressed.emit()
	await _settle(3)
	_c("J4 GİZLİ Profil yuvasına kodla `pressed`: gezinme yok", _main._active_tab == 0)

	await _boot()
	await _tab(3)
	var shop: CanvasLayer = _main._screens[3]
	await _ensure_confirm(shop, shop.power_card(PowerUp.Type.UPGRADE).buy_button())
	(shop.get("_confirm_yes") as Button).pressed.emit()
	await _settle(3)
	_c("J5 açık onayda SATIN AL'a kodla `pressed`: tam bir harcama (900 → 720)", _econ_is(720, 3))
	_main.open_settings()
	await _wait_settled()
	var sfx: Button = _main._settings.get("_sfx_toggle")
	sfx.button_pressed = false
	await _settle(2)
	_c("J6 Ayarlar anahtarı kodla (`button_pressed`): tercih yazıldı (disk)", not SaveManager.sfx_enabled()
		and _disk("sfx_enabled") == false)
	_sections_done += 1


# --- K: çok parmak ------------------------------------------------------------------------------------------------------

func _multi_touch() -> void:
	print("-- K: çok parmak (düğmeler yalnız 0. parmağın öykünülen faresini görür)")
	await _boot()
	await _tab(1)
	var map: CanvasLayer = _main._screens[1]
	var node: Button = map.nodes()[0]
	var back: Button = map.top_bar().back_button()
	_watch(node, "node")
	_watch(back, "map_back")
	_mark()
	await _finger(_center(node), true, 0)
	await _finger(_center(back), true, 1)
	await _finger(_center(back), false, 1)
	await _settle(2)
	var held: bool = _main._active_tab == 1 and not _board_live() and _count("map_back.down") == 0
	await _finger(_center(node), false, 0)
	await _settle(3)
	_c("K1 parmak 0 düğümde, parmak 1 üst çubuk geride dokunup kalkar: geri basılmadı (fare öykünmesi yalnız 0. parmak); parmak 0 kalkınca tam bir seviye",
		held and _board_live() and _count("node.pressed") == 1 and _count("map_back.pressed") == 0)

	await _boot()
	await _tab(3)
	var shop: CanvasLayer = _main._screens[3]
	await _ensure_confirm(shop, shop.power_card(PowerUp.Type.UPGRADE).buy_button())
	var yes: Button = shop.get("_confirm_yes")
	var frame: Rect2 = shop.confirm_frame().get_global_rect()
	var inside: Vector2 = _screen(Vector2(frame.get_center().x, frame.position.y + 40.0))
	await _finger(_center(yes), true, 0)
	await _finger(inside, true, 1)
	# Android ACTION_CANCEL: motor izlenen HER parmağa iptal edilen bırakış yollar — tek yığında (aynı kare).
	for pair: Array in [[_center(yes), 0], [inside, 1]]:
		var cancel := _touch_event(pair[0], false, int(pair[1]))
		cancel.canceled = true
		Input.parse_input_event(cancel)
	Input.flush_buffered_events()
	await _settle(2)
	await _finger(_center(yes), false, 0)
	await _settle(3)
	_c("K2 iki parmak + tüm jest ACTION_CANCEL (her parmağa, tek yığın) + bayat UP: harcama yok, pencere açık",
		_econ_is(900, 2) and shop.is_confirm_open())
	await _wait_settled()
	await _finger(_center(yes), true, 0)
	await _finger(inside, true, 1)
	await _finger(inside, false, 1)
	await _finger(_center(yes), false, 0)
	await _settle(3)
	_c("K3 parmak 0 SATIN AL'da, parmak 1 pencere içinde (düğme dışı) kalkar — Android 13+ tek-işaretçi iptalinin Godot'daki düz bırakışı: parmak 0'ın gerçek kalkışıyla tam bir harcama (900 → 720)",
		_econ_is(720, 3))

	await _boot()
	await _tab(3)
	shop = _main._screens[3]
	var card_buy: Button = shop.power_card(PowerUp.Type.UPGRADE).buy_button()
	await _ensure_confirm(shop, card_buy)
	yes = shop.get("_confirm_yes")
	var dim_at: Vector2 = _shop_dim_point(shop)
	await _finger(_center(yes), true, 0)
	await _finger(dim_at, true, 1)
	# Parmak 1'in karartma bırakışı ve parmak 0'ın SATIN AL bırakışı AYNI girdi yığınında (tek kare): pencere birincisinde
	# eşzamanlı kapanır (CanvasLayer görünürlüğü çocuklara anında yayılır), ikincisi işlenirken basış çoktan bitmiştir.
	Input.parse_input_event(_touch_event(dim_at, false, 1))
	Input.parse_input_event(_touch_event(_center(yes), false, 0))
	Input.flush_buffered_events()
	await _settle(3)
	var closed_by_dim: bool = not shop.is_confirm_open()
	_c("K5 parmak 0 SATIN AL'da basılıyken parmak 1 karartmaya dokunur, iki bırakış aynı yığında: pencere kapandı, parmak 0'ın kalkışı harcamaz (900 / 2)",
		closed_by_dim and _econ_is(900, 2))
	await _ensure_confirm(shop, card_buy)
	var confirm: Control = shop.get("_confirm")
	var closes: Array[int] = [0]
	confirm.visibility_changed.connect(func() -> void:
		if not confirm.visible:
			closes[0] += 1)
	var second: Vector2 = dim_at + Vector2(60.0, 0.0)
	await _finger(dim_at, true, 0)
	await _finger(second, true, 1)
	await _finger(second, false, 1)
	await _finger(dim_at, false, 0)
	await _settle(3)
	_c("K6 iki parmak aynı karartmada: tek kapanış, harcama yok, Mağaza'da kalındı", not shop.is_confirm_open()
		and closes[0] == 1 and _econ_is(900, 2) and _main._active_tab == 3)

	# Sahiplik düğme başına: bir düğmenin basılı durumu başka bir sahipli düğmenin etkinleştirmesini engellemez.
	await _boot()
	await _tab(1)
	map = _main._screens[1]
	node = map.nodes()[0]
	_mark()
	await _finger(_center(node), true, 0)
	map.top_bar().back_button().pressed.emit()
	await _settle(3)
	var went_home: bool = _main._active_tab == 0 and _count("map.home_requested") == 1
	await _finger(_center(node), false, 0)
	await _settle(3)
	_c("K4 düğüm basılıyken başka sahipli düğmeye (üst çubuk geri) erişilebilirlik / kod `pressed`'i: tam bir kez Ana Sayfa; düğümün sonraki kalkışı eylemsiz",
		went_home and not _board_live() and _main._active_tab == 0)
	_sections_done += 1


# --- L: ekonomi kaydı ---------------------------------------------------------------------------------------------------

func _economy() -> void:
	print("-- L: iptal edilen harcama / ödül kayda dokunmaz; geçerli olan tam bir kez yazar")
	await _boot({"powerups": {"bomb": 0, "upgrade": 0, "shake": 0, "clear_small": 0}})
	var board: Node2D = await _start_round()
	_spawn(board)
	await _tap(board.get_node("HUD").power_bar.slot(PowerUp.Type.SHAKE))
	await _wait_settled()
	var bytes: PackedByteArray = _save_bytes()
	var dough_buy: Button = _main._refill.get("_dough")
	await _gesture(dough_buy, "cancel")
	await _gesture(dough_buy, "focus")
	_c("L1 refill Hamur ile SATIN AL iptal + odak kaybı: kayıt dosyası bayt-aynı (Hamur 900, stok 0)", _save_bytes() == bytes
		and SaveManager.dough() == 900 and SaveManager.powerup_count(PowerUp.Type.SHAKE) == 0)
	await _wait_settled()
	await _tap(dough_buy)
	var disk_powerups: Variant = _disk("powerups")
	_c("L2 geçerli refill tam bir kez yazdı: Hamur 800, Sarsıntı 1 (disk)", _disk_dough() == 800 and disk_powerups is Dictionary
		and int((disk_powerups as Dictionary).get("shake", -1)) == 1)

	await _boot()
	board = await _start_round()
	_spawn(board)
	var slot: Button = board.get_node("HUD").power_bar.slot(PowerUp.Type.SHAKE)
	bytes = _save_bytes()
	await _gesture(slot, "cancel")
	await _gesture(slot, "focus")
	_c("L3 güç yuvası iptal + odak kaybı: stok diskte aynı (dosya bayt-aynı)", _save_bytes() == bytes
		and SaveManager.powerup_count(PowerUp.Type.SHAKE) == 1)
	_sections_done += 1


# --- M: gezinme -----------------------------------------------------------------------------------------------------------

func _navigation() -> void:
	print("-- M: GERİ zinciri, tek gezinme, bayat pencere yok")
	await _boot()
	await _tab(4)
	await _back()
	await _settle(3)
	var profile_back: bool = _main._active_tab == 0
	await _tab(1)
	await _back()
	await _settle(3)
	var map_back: bool = _main._active_tab == 0
	await _tab(3)
	var shop: CanvasLayer = _main._screens[3]
	await _ensure_confirm(shop, shop.power_card(PowerUp.Type.UPGRADE).buy_button())
	await _back()
	await _settle(3)
	var confirm_closed: bool = not shop.is_confirm_open() and _main._active_tab == 3
	await _back()
	await _settle(3)
	_c("M1 GERİ zinciri: Profil → Ana Sayfa, Harita → Ana Sayfa, Mağaza onayı → kapanır (Mağaza'da), sonra → Ana Sayfa",
		profile_back and map_back and confirm_closed and _main._active_tab == 0)

	await _boot()
	await _tab(0)
	_main.open_missions()
	await _wait_settled()
	var quits: int = _main.quit_requests
	var edge: Vector2 = _screen(Vector2(10.0, 640.0))
	await _finger(edge, true)
	await _cancel_finger(edge)
	var open_after_cancel: bool = _main._missions.visible
	await _back()
	await _settle(3)
	_c("M2 Görevler karartmasında ACTION_CANCEL + aynı jestin GERİ'si (kenar geri kaydırması): iptal kapatmadı, GERİ tek kez kapattı, uygulamadan ÇIKILMADI",
		open_after_cancel and not _main._missions.visible and _main.quit_requests == quits and _main._active_tab == 0
		and _main._screens[0].visible)

	await _boot()
	await _tab(4)
	_main.open_settings()
	await _wait_settled()
	edge = _screen(Vector2(10.0, 640.0))
	await _finger(edge, true)
	await _cancel_finger(edge)
	var settings_after_cancel: bool = _main._settings.visible
	await _back()
	await _settle(3)
	_c("M3 Profil üstünde Ayarlar: karartma iptali + GERİ → yalnız Ayarlar kapandı, Profil'de kalındı (tek gezinme)",
		settings_after_cancel and not _main._settings.visible and _main._active_tab == 4)
	await _finger(edge, true)
	await _settle(1)
	_main.open_settings()
	await _wait_settled()
	await _finger(edge, false)
	await _settle(2)
	await _wait_settled()
	await _finger(edge, true)
	await _finger(edge, false)
	await _settle(3)
	_c("M4 (pozitif) karartmada gerçek dokunuş Ayarlar'ı kapatır", not _main._settings.visible and _main._active_tab == 4)

	await _boot()
	await _tab(4)
	var profile: CanvasLayer = _main._screens[4]
	await _gesture(profile.title_button(), "back")
	await _tab(4)
	var slot: Button = profile.showcase_slots()[0]
	_watch(slot, "slot")
	_mark()
	await _tap(slot)
	_c("M5 unvan düğmesi basılı + GERİ sonrası Profil: bayat pencere yok, ilk taze yuva dokunuşu yutulmadı (Koleksiyon + detay)",
		_main._active_tab == 2 and _main._screens[2].is_detail_open() and _count("slot.pressed") == 1)
	_sections_done += 1


# --- R: çalışma anı sahiplik taraması -------------------------------------------------------------------------------

func _ownership_sweep() -> void:
	print("-- R: gerçek Main ağacında FIX düğmeleri sahipli, KEEP düğmeleri sahipsiz")
	await _boot({"highest_level_unlocked": 11, "level_stars": {"1": 3, "2": 3, "3": 3, "4": 3, "5": 3, "6": 3, "7": 3,
		"8": 3, "9": 3, "10": 3}})
	var home: CanvasLayer = _main._screens[0]
	var map: CanvasLayer = _main._screens[1]
	var shop: CanvasLayer = _main._screens[3]
	var profile: CanvasLayer = _main._screens[4]
	var settings: CanvasLayer = _main._settings
	var age: CanvasLayer = _main._age_panel
	var daily: CanvasLayer = _main._daily_rewards
	var challenge: CanvasLayer = _main._challenge_sheet
	var refill: CanvasLayer = _main._refill
	var fixed: Dictionary = {
		"Ana Sayfa avatar": home.profile_button(), "Ana Sayfa Hamur +": home.dough_pill().get_meta(&"add_button"),
		"Ana Sayfa GÜNLÜK": home.feature_button(&"daily"), "Ana Sayfa KOLEKSİYON": home.feature_button(&"collection"),
		"Ana Sayfa MAĞAZA": home.feature_button(&"shop"), "Ana Sayfa SANDIK": home.feature_button(&"chest"),
		"Ana Sayfa GÖREVLER": home.missions_button(), "Ana Sayfa MEYDAN OKUMA": home.challenge_button(),
		"Ana Sayfa OYNA": home.play_button(), "Ana Sayfa seviye hapı": home.level_button(),
		"Harita Sonsuz": map.endless_node(), "Harita üst çubuk geri": map.top_bar().back_button(),
		"Harita üst çubuk +": map.top_bar().add_button(),
		"Mağaza üst çubuk geri": shop.top_bar().back_button(), "Mağaza günlük AÇ": shop.daily_button(),
		"Mağaza onay SATIN AL": shop.get("_confirm_yes"), "Mağaza onay Vazgeç": shop.get("_confirm_no"),
		"Mağaza onay X": shop.confirm_frame().get_meta(&"close_button"),
		"Profil üst çubuk geri": profile.top_bar().back_button(), "Profil dişli": profile.top_bar().action_button(),
		"Profil unvan": profile.title_button(), "Profil TÜM BAŞARIMLAR": profile.achievements_cta(),
		"Profil KOLEKSİYONA GİT": profile.collection_cta(),
		"unvan seçici X": profile.title_selector().frame().get_meta(&"close_button"),
		"başarımlar X": profile.achievements_overlay().frame().get_meta(&"close_button"),
		"Ayarlar Ses": settings.get("_sfx_toggle"), "Ayarlar Titreşim": settings.get("_haptics_toggle"),
		"Ayarlar gizlilik seçenekleri": settings.get("_privacy_options_button"),
		"Ayarlar politika": settings.get("_privacy_policy_button"), "Ayarlar yaş Güncelle": settings.get("_age_info_button"),
		"Ayarlar Kapat": settings.get("_close"), "Ayarlar X": settings.frame().get_meta(&"close_button"),
		"yaş X": age.close_x(), "yaş ONAYLA": age.confirm_button(), "yaş Vazgeç": age.cancel_button(),
		"yaş TAMAM": age.done_button(),
		"günlük X": daily.get("_close_button"), "günlük AÇ": daily.free_button(), "günlük REKLAM +Hamur": daily.dough_button(),
		"günlük REKLAM sandık": daily.chest_button(), "günlük KAPAT": daily.close_button(),
		"sandık OYNA": _main._chest_info.play_button(), "sandık X": _main._chest_info.frame().get_meta(&"close_button"),
		"görevler X": _main._missions.close_button(),
		"meydan okuma X": challenge.close_button(), "meydan okuma BAŞLA": challenge.start_button(),
		"meydan okuma KAPAT": challenge.close_cta(),
		"mola DEVAM": _main._pause.buttons()[0], "mola Yeniden Başlat": _main._pause.buttons()[1],
		"mola Ana Menü": _main._pause.buttons()[2], "mola X": _main._pause.frame().get_meta(&"close_button"),
		"refill X": refill.close_button(), "refill reklam": refill.get("_ad"), "refill Hamur": refill.get("_dough"),
		"refill KAPAT": refill.get("_close"),
		"devam DEVAM ET": _main._revive.continue_button(), "devam vazgeç": _main._revive.decline_button(),
		"sonuç birincil": _main._result.primary_button(), "sonuç ikincil": _main._result.secondary_button(),
		"tutorial ATLA": _main._tutorial_overlay.skip_button(), "tutorial CTA": _main._tutorial_overlay.cta_button(),
		"tutorial alt CTA": _main._tutorial_overlay.cta_alt_button()}
	var index: int = 0
	for node: Button in map.nodes():
		index += 1
		fixed["Harita düğümü %d" % index] = node
	for i in profile.showcase_slots().size():
		fixed["Profil vitrin yuvası %d" % (i + 1)] = profile.showcase_slots()[i]
	for i in shop.power_cards().size():
		fixed["Mağaza güç kartı %d" % (i + 1)] = shop.power_cards()[i].buy_button()
	for card: Control in shop.skin_cards():
		fixed["Mağaza kostüm kartı %s" % String(card.skin_id())] = card.buy_button()
	for i in profile.title_selector().rows().size():
		fixed["unvan satırı %d" % (i + 1)] = profile.title_selector().rows()[i]
	var board: Node2D = await _start_round()
	var hud: Node = board.get_node("HUD")
	fixed["HUD geri"] = hud.back_button
	fixed["HUD dişli"] = hud.settings_button
	fixed["HUD çıkış"] = hud.exit_button
	for type: int in [PowerUp.Type.BOMB, PowerUp.Type.UPGRADE, PowerUp.Type.SHAKE, PowerUp.Type.CLEAR_SMALL]:
		fixed["güç yuvası %d" % type] = hud.power_bar.slot(type)
	var unowned: Array[String] = []
	for label: String in fixed:
		var button: Variant = fixed[label]
		if not (button is BaseButton) or not _owned(button as BaseButton):
			unowned.append(label)
	_c("R1 Faz A matrisinin %d FIX düğmesi örneğinin HEPSİ sahipli (GestureGuard)%s" % [fixed.size(),
		"" if unowned.is_empty() else " (sahipsiz: %s)" % ", ".join(unowned)], unowned.is_empty() and fixed.size() >= 90)
	var keep: Dictionary = {"Ayarlar Göster/Gizle": settings.get("_privacy_button"), "yaş DEVAM ET": age.continue_button(),
		"yaş DÜZELT": age.fix_button(), "yaş seçim Geri": age.picker_back_button(), "yaş gün seçici": age.selector_button(0),
		"günlük DEVAM": daily.continue_button()}
	var wrapped: Array[String] = []
	for label: String in keep:
		var button: Variant = keep[label]
		if not (button is BaseButton) or _owned(button as BaseButton):
			wrapped.append(label)
	_c("R2 sonuçsuz KEEP düğmeleri sahipsiz (gereksiz sarmalayıcı yok)%s" % ("" if wrapped.is_empty()
		else " (sarılmış: %s)" % ", ".join(wrapped)), wrapped.is_empty())
	var album: CanvasLayer = _main._screens[2]
	var collection_owned: int = 0
	for card: Control in album.cards():
		if _owned(card as BaseButton):
			collection_owned += 1
	_c("R3 TASK/054 Koleksiyon kartları paylaşılan yardımcıya taşınmadı (kendi sahipliği aynen)", collection_owned == 0
		and album.cards().size() > 0)
	_sections_done += 1


# --- P: kaynak sözleşmesi ---------------------------------------------------------------------------------------------

func _source_contract() -> void:
	print("-- P: kaynak sözleşmesi")
	var guard_path: String = "res://scripts/ui/gesture_guard.gd"
	var guard: String = _strip_comments(FileAccess.get_file_as_string(guard_path)) if FileAccess.file_exists(guard_path) else ""
	_c("paylaşılan GUI yardımcısı scripts/ui/gesture_guard.gd: class_name GestureGuard, açık API (own / on_pressed / allows / invalidate)",
		guard.contains("class_name GestureGuard") and guard.contains("static func own(") and guard.contains("static func on_pressed(")
		and guard.contains("static func allows(") and guard.contains("static func invalidate("))
	_c("  … iptal edilen sol bırakışta basış gui_input SİNYALİNDE biter; gizleme / odak kaybı / GERİ basışı bitirir; eylem allows'tan geçer",
		guard.contains("click.canceled") and guard.contains("end_press()") and guard.contains("visibility_changed")
		and guard.contains("NOTIFICATION_WM_WINDOW_FOCUS_OUT") and guard.contains("NOTIFICATION_WM_GO_BACK_REQUEST")
		and _function(guard, "func _run(").contains("allows_activation()"))
	_c("  … yalnız İŞARETÇİ basışı sahiplenilir (klavye / erişilebilirlik basışı serbest)", guard.contains("_held = _pointer_press"))
	var globals: Array[String] = []
	for word: String in ["Input.", "set_input_as_handled", "accept_event", "create_timer", "func _process", "func _input",
			"func _unhandled_input", "Time.get_ticks", "GameBoard", "get_tree()"]:
		if guard.contains(word):
			globals.append(word)
	_c("  … global girdi yutma / zaman aşımı / Input / GameBoard bağı YOK %s" % str(globals), globals.is_empty() and guard != "")
	var missing: Array[String] = []
	for pair: Array in _fixed_sites():
		var code: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/%s" % String(pair[0])))
		if not code.contains(String(pair[1])):
			missing.append("%s: %s" % [pair[0], pair[1]])
	_c("sonuç doğuran %d düğme sahipli bağlanır (GestureGuard.on_pressed / own)%s" % [_fixed_sites().size(),
		"" if missing.is_empty() else " (eksik: %s)" % ", ".join(missing)], missing.is_empty())
	var leftover: Array[String] = []
	for pair: Array in [["home_screen.gd", "_play.pressed.connect("], ["shop_screen.gd", "_confirm_yes.pressed.connect("],
			["level_select.gd", "node.pressed.connect("], ["profile_screen.gd", "slot.pressed.connect("],
			["power_bar.gd", "slot.pressed.connect("], ["daily_rewards_popup.gd", "_free.pressed.connect("],
			["power_refill.gd", "_dough.pressed.connect("], ["age_gate_panel.gd", "_confirm.pressed.connect("]]:
		if FileAccess.get_file_as_string("res://scripts/ui/%s" % String(pair[0])).contains(String(pair[1])):
			leftover.append("%s: %s" % [pair[0], pair[1]])
	_c("  … korumasız doğrudan bağlama kalmadı %s" % str(leftover), leftover.is_empty())
	var relay_gaps: Array[String] = []
	for path: String in _scripts_under("res://scripts"):
		if path.ends_with("/screen_top_bar.gd"):
			continue
		var src: String = _strip_comments(FileAccess.get_file_as_string(path))
		if not src.contains("ScreenTopBar"):
			continue
		for sig: String in ["back", "add", "action"]:
			if src.contains("_bar.%s_pressed.connect(" % sig) and not (src.contains("GestureGuard.allows(_bar.%s_button())" % sig)
					or src.contains("_gesture_ok(_bar.%s_button())" % sig)):
				relay_gaps.append("%s: %s" % [path.get_file(), sig])
	_c("her ScreenTopBar tüketicisi rölesini sahiplik kapısından geçirir (GestureGuard.allows / Koleksiyon _gesture_ok) %s"
		% str(relay_gaps), relay_gaps.is_empty())
	var settings_code: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/settings_panel.gd"))
	for name: String in ["func _on_sfx_toggled(", "func _on_haptics_toggled("]:
		var fn: String = _function(settings_code, name)
		var write: int = fn.find("SaveManager.set_")
		_c("  … %s: TASK/053 görünürlük kapısı + sahiplik kapısı yazmadan ÖNCE, reddedilen anahtar kayıttan geri kurulur"
			% name.trim_prefix("func ").trim_suffix("("), fn.find("not visible") >= 0 and fn.find("not visible") < write
			and fn.find("GestureGuard.allows(") >= 0 and fn.find("GestureGuard.allows(") < write and fn.contains(".set_on(SaveManager."))
	var toggle_code: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/ui_toggle.gd"))
	_c("UiToggle topuzu anahtarın şu anki durumuna kayar; set_on süren topuz animasyonunu durdurur",
		_function(toggle_code, "func _on_toggled(").contains("1.0 if button_pressed else 0.0")
		and _function(toggle_code, "func set_on(").contains(".kill()"))
	var dim: String = _function(_strip_comments(FileAccess.get_file_as_string("res://scripts/ui/ui_kit.gd")),
		"static func attach_dim_close(")
	_c("paylaşılan karartma kapanışı iptal edilen bırakışta kapatmaz (dokunuş + fare)", dim.contains("not touch.canceled")
		and dim.contains("not click.canceled") and dim.contains("on_close.call()"))
	var shop_code: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/shop_screen.gd"))
	_c("Mağaza onay karartması paylaşılan bırakış kapanışını kullanır (eski basışta kapatan yerel işleyici yok)",
		shop_code.contains("UiKit.attach_dim_close(_confirm_dim, _close_confirm)") and not shop_code.contains("_on_dim_input"))
	var native: Array[String] = []
	for pair: Array in [["settings_panel.gd", "_privacy_button.pressed.connect(_toggle_privacy)"],
			["age_gate_panel.gd", "_continue.pressed.connect(press_continue)"], ["age_gate_panel.gd", "_fix.pressed.connect(press_fix)"],
			["age_gate_panel.gd", "_pick_back.pressed.connect(close_picker)"],
			["age_gate_panel.gd", "selector.pressed.connect(open_picker.bind(i))"],
			["age_gate_panel.gd", "option.pressed.connect(choose.bind(value))"],
			["daily_rewards_popup.gd", "_continue.pressed.connect(_on_continue_pressed)"]]:
		if not FileAccess.get_file_as_string("res://scripts/ui/%s" % String(pair[0])).contains(String(pair[1])):
			native.append("%s: %s" % [pair[0], pair[1]])
	_c("sonuçsuz doğal düğmeler aynen (gereksiz sarmalayıcı yok) %s" % str(native), native.is_empty())
	var untouched: Array[String] = []
	for path: String in ["res://scripts/ui/screen_top_bar.gd", "res://scripts/ui/collection_screen.gd",
			"res://scripts/ui/collection_skin_card.gd", "res://scripts/main.gd", "res://scripts/game/game_board.gd"]:
		if FileAccess.get_file_as_string(path).contains("GestureGuard"):
			untouched.append(path.get_file())
	_c("paylaşılan ScreenTopBar, TASK/054 Koleksiyon, Main gezinmesi ve GameBoard bu yardımcıya bağlanmadı %s" % str(untouched),
		untouched.is_empty() and FileAccess.get_file_as_string("res://scripts/ui/screen_top_bar.gd")
			.contains("_back.pressed.connect(func() -> void: back_pressed.emit())")
		and FileAccess.get_file_as_string("res://scripts/ui/collection_screen.gd").contains("func _own_gesture("))
	_c("Main geri yönlendirmesi / 300 ms geçiş yatışması değişmedi",
		_function(_strip_comments(FileAccess.get_file_as_string("res://scripts/main.gd")), "func _notification(")
			.contains("active.handle_back()")
		and int(load("res://scripts/main.gd").get_script_constant_map()["TOUCH_SETTLE_MSEC"]) == 300)
	_sections_done += 1


## (dosya, beklenen sahipli bağlama) — Faz A matrisinin FIX satırları.
func _fixed_sites() -> Array:
	return [
		["home_screen.gd", "GestureGuard.on_pressed(_avatar_button,"], ["home_screen.gd", "GestureGuard.on_pressed(_dough_pill.get_meta("],
		["home_screen.gd", "GestureGuard.on_pressed(daily,"], ["home_screen.gd", "GestureGuard.on_pressed(collection,"],
		["home_screen.gd", "GestureGuard.on_pressed(shop,"], ["home_screen.gd", "GestureGuard.on_pressed(chest,"],
		["home_screen.gd", "GestureGuard.on_pressed(_missions,"], ["home_screen.gd", "GestureGuard.on_pressed(_challenge,"],
		["home_screen.gd", "GestureGuard.on_pressed(_play,"], ["home_screen.gd", "GestureGuard.on_pressed(_level,"],
		["profile_screen.gd", "GestureGuard.own(_bar.back_button())"], ["profile_screen.gd", "GestureGuard.own(_bar.action_button())"],
		["profile_screen.gd", "GestureGuard.allows(_bar.back_button())"], ["profile_screen.gd", "GestureGuard.allows(_bar.action_button())"],
		["profile_screen.gd", "GestureGuard.on_pressed(button, open_title_selector)"],
		["profile_screen.gd", "GestureGuard.on_pressed(_achievements_cta, open_achievements)"],
		["profile_screen.gd", "GestureGuard.on_pressed(slot, _on_slot_pressed.bind(i))"],
		["profile_screen.gd", "GestureGuard.on_pressed(_collection_cta,"],
		["title_selector.gd", "GestureGuard.on_pressed(row, _on_row_pressed.bind(id))"],
		["title_selector.gd", "GestureGuard.on_pressed(_frame.get_meta(&\"close_button\") as Button, close)"],
		["achievements_overlay.gd", "GestureGuard.on_pressed(_frame.get_meta(&\"close_button\") as Button, close)"],
		["level_select.gd", "GestureGuard.own(_bar.back_button())"], ["level_select.gd", "GestureGuard.own(_bar.add_button())"],
		["level_select.gd", "GestureGuard.allows(_bar.back_button())"], ["level_select.gd", "GestureGuard.allows(_bar.add_button())"],
		["level_select.gd", "GestureGuard.on_pressed(node, _on_node_pressed.bind(node, level))"],
		["level_select.gd", "GestureGuard.on_pressed(_endless, _on_endless_pressed)"],
		["shop_screen.gd", "GestureGuard.own(_bar.back_button())"], ["shop_screen.gd", "GestureGuard.allows(_bar.back_button())"],
		["shop_screen.gd", "GestureGuard.on_pressed(_daily_button,"], ["shop_screen.gd", "GestureGuard.on_pressed(_confirm_yes, _on_confirm_yes)"],
		["shop_screen.gd", "GestureGuard.on_pressed(_confirm_no, _close_confirm)"],
		["shop_screen.gd", "GestureGuard.on_pressed(_frame.get_meta(&\"close_button\") as Button, _close_confirm)"],
		["shop_power_card.gd", "GestureGuard.on_pressed(_buy,"], ["shop_skin_card.gd", "GestureGuard.on_pressed(_buy,"],
		["settings_panel.gd", "GestureGuard.own(_sfx_toggle)"], ["settings_panel.gd", "GestureGuard.own(_haptics_toggle)"],
		["settings_panel.gd", "GestureGuard.on_pressed(_privacy_options_button,"],
		["settings_panel.gd", "GestureGuard.on_pressed(_privacy_policy_button,"],
		["settings_panel.gd", "GestureGuard.on_pressed(_age_info_button,"], ["settings_panel.gd", "GestureGuard.on_pressed(_close, close_panel)"],
		["settings_panel.gd", "GestureGuard.on_pressed(_frame.get_meta(&\"close_button\") as Button, close_panel)"],
		["age_gate_panel.gd", "GestureGuard.on_pressed(_close_x, _on_cancel)"], ["age_gate_panel.gd", "GestureGuard.on_pressed(_confirm, press_confirm)"],
		["age_gate_panel.gd", "GestureGuard.on_pressed(_cancel, _on_cancel)"], ["age_gate_panel.gd", "GestureGuard.on_pressed(_done, press_done)"],
		["daily_rewards_popup.gd", "GestureGuard.on_pressed(_close_button, close_popup)"],
		["daily_rewards_popup.gd", "GestureGuard.on_pressed(_free, _on_free_pressed)"],
		["daily_rewards_popup.gd", "GestureGuard.on_pressed(_dough, _on_dough_pressed)"],
		["daily_rewards_popup.gd", "GestureGuard.on_pressed(_chest, _on_chest_pressed)"],
		["daily_rewards_popup.gd", "GestureGuard.on_pressed(_close, close_popup)"],
		["bonus_chest_info.gd", "GestureGuard.on_pressed(_play,"],
		["bonus_chest_info.gd", "GestureGuard.on_pressed(_frame.get_meta(&\"close_button\") as Button, close_info)"],
		["missions_overlay.gd", "GestureGuard.on_pressed(_frame.get_meta(&\"close_button\") as Button, close_missions)"],
		["daily_challenge_overlay.gd", "GestureGuard.on_pressed(_frame.get_meta(&\"close_button\") as Button, close_sheet)"],
		["daily_challenge_overlay.gd", "GestureGuard.on_pressed(_start, _on_start_pressed)"],
		["daily_challenge_overlay.gd", "GestureGuard.on_pressed(_close_cta, close_sheet)"],
		["pause_menu.gd", "GestureGuard.on_pressed(_resume, _emit_if_open.bind(resume_pressed))"],
		["pause_menu.gd", "GestureGuard.on_pressed(_restart, _emit_if_open.bind(restart_pressed))"],
		["pause_menu.gd", "GestureGuard.on_pressed(_exit, _emit_if_open.bind(exit_pressed))"],
		["pause_menu.gd", "GestureGuard.on_pressed(_frame.get_meta(&\"close_button\") as Button, _emit_if_open.bind(resume_pressed))"],
		["power_refill.gd", "GestureGuard.on_pressed(_close_button, _on_close_pressed)"],
		["power_refill.gd", "GestureGuard.on_pressed(_ad, _on_ad_pressed)"], ["power_refill.gd", "GestureGuard.on_pressed(_dough, _on_dough_pressed)"],
		["power_refill.gd", "GestureGuard.on_pressed(_close, _on_close_pressed)"],
		["revive_offer.gd", "GestureGuard.on_pressed(_continue, _on_continue_pressed)"], ["revive_offer.gd", "GestureGuard.on_pressed(_decline,"],
		["round_result.gd", "GestureGuard.on_pressed(_primary, _on_primary_pressed)"],
		["round_result.gd", "GestureGuard.on_pressed(_secondary, _on_secondary_pressed)"],
		["tutorial_overlay.gd", "GestureGuard.on_pressed(_cta_alt,"], ["tutorial_overlay.gd", "GestureGuard.on_pressed(_cta,"],
		["tutorial_overlay.gd", "GestureGuard.on_pressed(_skip,"],
		["gameplay_hud.gd", "GestureGuard.on_pressed(back_button,"], ["gameplay_hud.gd", "GestureGuard.on_pressed(settings_button,"],
		["gameplay_hud.gd", "GestureGuard.on_pressed(exit_button,"], ["power_bar.gd", "GestureGuard.on_pressed(slot,"]]


# --- Ortak ---------------------------------------------------------------------------------------------------------

func _fixture(extra: Dictionary = {}) -> Dictionary:
	var content: Dictionary = {"highest_level_unlocked": 5, "level_stars": {"1": 3, "2": 3, "3": 2, "4": 2},
		"endless_high_score": 640, "dough": 900, "total_merges": 40, "merges_since_bonus_chest": 10,
		"unlocked_skins": ["common_01", String(SHOWCASE_ID)], "profile_showcase": [String(SHOWCASE_ID)],
		"powerups": {"bomb": 0, "upgrade": 2, "shake": 1, "clear_small": 1}, "powerup_starter_granted": true,
		"onboarding_completed": true, "onboarding_completed_day": "", "daily_streak": 3,
		"last_login_date": Time.get_date_string_from_system(), "age_ad_band": "ADULT", "next_age_transition_date": "",
		"player_meta_version": 1, "player_xp": 400, "total_rounds_played": 12, "highest_tier_created": 4,
		"unlocked_achievements": ["merge_10"], "daily_challenge": {"version": 1, "completed_day_key": ""},
		"daily_rewards": {"day_key": THU, "free_chest_claimed": true, "ad_chests_claimed": 2,
			"dough_ad_claimed": true, "popup_seen_day": THU, "last_seen_day_key": THU},
		"missions": {"version": 1, "day_key": THU, "week_start_day_key": MON,
			"daily_progress": {"daily_merges": 5, "daily_rounds": 0, "daily_clear": 0}, "daily_rewarded": [],
			"weekly_progress": {"weekly_merges": 30, "weekly_rounds": 4, "weekly_clears": 2}, "weekly_rewarded": []}}
	for key: String in extra:
		content[key] = extra[key]
	return content


func _daily_fixture() -> Dictionary:
	return {"daily_rewards": {"day_key": THU, "free_chest_claimed": false, "ad_chests_claimed": 0,
		"dough_ad_claimed": false, "popup_seen_day": THU, "last_seen_day_key": THU}}


## Temiz kayıt + Main (Ana Sayfa) + sinyal sayaçları.
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
	_n = {}
	_events = []
	var home: CanvasLayer = _main._screens[0]
	for sig: String in ["play_pressed", "shop_requested", "profile_requested", "map_requested", "missions_requested",
			"collection_requested"]:
		home.connect(sig, func() -> void: _bump("home.%s" % sig))
	var map: CanvasLayer = _main._screens[1]
	map.connect("level_chosen", func(_level: Variant) -> void: _bump("map.level_chosen"))
	map.connect("shop_requested", func() -> void: _bump("map.shop_requested"))
	map.connect("home_requested", func() -> void: _bump("map.home_requested"))
	var album: CanvasLayer = _main._screens[2]
	album.connect("detail_opened", func() -> void: _bump("album.detail_opened"))
	var profile: CanvasLayer = _main._screens[4]
	profile.connect("home_requested", func() -> void: _bump("profile.home_requested"))
	profile.connect("settings_requested", func() -> void: _bump("profile.settings_requested"))


func _tab(index: int) -> void:
	_main._show_tab(index)
	await _wait_settled()


func _start_round() -> Node2D:
	_main._start_level(load(LEVEL_PATH))
	await _settle(3)
	await _wait_settled()
	return _main._board


## Sarsıntı'nın etkili olması için board'da bir parça.
func _spawn(board: Node2D) -> void:
	board._spawn_dumpling(3, Vector2(board._center_x(), board.FLOOR_Y - 38.0))


func _board_live() -> bool:
	var board: Variant = _main.get("_board")
	return board != null and is_instance_valid(board) and (board as Node).is_inside_tree()


## Yaş ekranı (yeniden giriş) → 15 Haziran 2011 (13–17) → onay adımı.
func _age_to_confirm() -> CanvasLayer:
	var panel: CanvasLayer = await _age_to_entry_complete()
	panel.press_continue()
	await _wait_settled()
	return panel


func _age_to_entry_complete() -> CanvasLayer:
	var panel: CanvasLayer = _main._age_panel
	panel.open_reentry()
	await _wait_settled()
	panel.open_picker(2)
	panel.choose(2011)
	panel.open_picker(1)
	panel.choose(6)
	panel.open_picker(0)
	panel.choose(15)
	await _wait_settled()
	return panel


## Mağaza onayı açık değilse kartın gerçek dokunuşuyla açar.
func _ensure_confirm(shop: CanvasLayer, card_buy: Button) -> void:
	await _wait_settled()
	if not shop.is_confirm_open():
		await _tap(card_buy)
		await _wait_settled()


## Onay karartmasında pencerenin (çerçeve) DIŞINDA bir nokta: çerçevenin üstündeki boşluğun ortası.
func _shop_dim_point(shop: CanvasLayer) -> Vector2:
	var frame: Rect2 = shop.confirm_frame().get_global_rect()
	return _screen(Vector2(frame.get_center().x, frame.position.y * 0.5))


## Aynı noktaya basışsız fare (aygıt 0) + dokunuş bırakışı (çift teslim).
func _duplicate_release(pos: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	click.position = pos
	click.global_position = pos
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await _settle(1)
	await _finger(pos, false)
	await _settle(3)


func _gesture(control: Control, mode: String) -> void:
	var pos: Vector2 = _center(control)
	await _finger(pos, true)
	match mode:
		"cancel":
			await _cancel_finger(pos)
		"back":
			await _unhandled_key()
			await _back()
		"focus":
			await _unhandled_key()
			await _window_focus(false)
			await _window_focus(true)
		"focus_handled":
			await _window_focus(false)
			await _window_focus(true)
	await _finger(pos, false)
	await _settle(3)


func _tap(control: Control) -> void:
	var pos: Vector2 = _center(control)
	await _finger(pos, true)
	await _finger(pos, false)
	await _settle(3)


func _touch_event(pos: Vector2, pressed: bool, index: int) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = pos
	touch.pressed = pressed
	return touch


func _finger(pos: Vector2, pressed: bool, index: int = 0) -> void:
	_ev("finger%d:%s" % [index, "down" if pressed else "up"])
	Input.parse_input_event(_touch_event(pos, pressed, index))
	Input.flush_buffered_events()
	await get_tree().process_frame


## Android ACTION_CANCEL: bırakış `canceled == true` (Godot'nun Android yolu gibi).
func _cancel_finger(pos: Vector2, index: int = 0) -> void:
	var cancel := _touch_event(pos, false, index)
	cancel.canceled = true
	_ev("finger%d:CANCEL" % index)
	Input.parse_input_event(cancel)
	Input.flush_buffered_events()
	await _settle(2)


## Hiçbir şeyin işlemediği bir girdi olayı (eşlenmemiş tuş, basış + bırakış): Viewport'un "işlendi" bayrağı kapalı kalır —
## cihazda GERİ tuşunun kendi KeyEvent'inin deterministik karşılığı.
func _unhandled_key() -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_F13
		key.physical_keycode = KEY_F13
		key.pressed = pressed
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		await get_tree().process_frame


## Pencere odağı (Android onPause → FOCUS_OUT, onResume → FOCUS_IN): kök pencereden aşağı, motorun sırasıyla.
func _window_focus(focused: bool) -> void:
	_ev("FOCUS_%s" % ("IN" if focused else "OUT"))
	_window_notify(NOTIFICATION_WM_WINDOW_FOCUS_IN if focused else NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await _settle(2)


## Pencere bildirimini motorun cihaz yolu gibi dağıtır (`Window::_propagate_window_notification`): önce kök, sonra
## çocuklar sırayla (iç düğümler dahil, alt pencereler hariç), düğümleri MEŞGUL işaretlemeden — `propagate_notification`
## bildirim sırasında çocuk eklemeyi reddeder, cihazda öyle değildir (GERİ işleyicisi bir board ekleyebilir).
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


## Android geri (Main'in 250 ms debounce'u gerçek saatle — iki basış arasında boşluk).
func _back() -> void:
	var gap: int = maxi(_last_back_msec + BACK_GAP_MSEC, int(_main.get("_last_back_msec")) + BACK_GAP_MSEC) \
		- Time.get_ticks_msec()
	if gap > 0:
		await get_tree().create_timer(float(gap) / 1000.0).timeout
	_last_back_msec = Time.get_ticks_msec()
	_ev("BACK")
	_window_notify(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(1)


func _watch(button: BaseButton, tag: String) -> void:
	if button == null or button.has_meta(&"qa_watch"):
		return
	button.set_meta(&"qa_watch", true)
	button.button_down.connect(func() -> void:
		_bump("%s.down" % tag)
		_ev("%s.down" % tag))
	button.button_up.connect(func() -> void:
		_bump("%s.up" % tag)
		_ev("%s.up" % tag))
	button.pressed.connect(func() -> void:
		_bump("%s.pressed" % tag)
		_ev("%s.pressed:vis=%s" % [tag, str(button.is_visible_in_tree())]))
	button.toggled.connect(func(_on: bool) -> void:
		_bump("%s.toggled" % tag)
		_ev("%s.toggled" % tag))


## Düğme bir GestureGuard'a ait mi (statik sınıf başvurusu yok — taban da çalışır).
func _owned(button: BaseButton) -> bool:
	return button.has_meta(GUARD_META) or button.get_node_or_null("GestureGuard") != null


func _count(key: String) -> int:
	return int(_n.get(key, 0))


## Senaryonun ön koşulu (kurulum gerçekten hedef durumu kurdu mu) — tabanda da geçmeli; geçmezse senaryo boşa koşmuştur.
func _pre(tag: String, ok: bool) -> void:
	_c("  … %s (ön koşul): hedef ekranda ve etkileşime hazır, açık pencere yok" % tag, ok)


func _scripts_under(dir: String) -> Array[String]:
	var out: Array[String] = []
	var access := DirAccess.open(dir)
	if access == null:
		return out
	for file: String in access.get_files():
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	for sub: String in access.get_directories():
		out.append_array(_scripts_under(dir.path_join(sub)))
	return out


func _bump(key: String) -> void:
	_n[key] = int(_n.get(key, 0)) + 1


func _mark() -> void:
	_n = {}
	_events = []
	_t0 = Time.get_ticks_msec()


func _ev(tag: String) -> void:
	_events.append("%s@%+d" % [tag, Time.get_ticks_msec() - _t0])


## Kayıt satırı (sayılmaz): sekme, board, sayaçlar, olay sırası.
func _record(tag: String) -> void:
	print("  [KAYIT] %s: sekme=%d board=%s sayaç=%s | %s" % [tag, _main._active_tab, str(_board_live()), str(_n),
		" ".join(_events)])


func _econ_is(dough: int, upgrade: int) -> bool:
	var powerups: Variant = _disk("powerups")
	return SaveManager.dough() == dough and SaveManager.powerup_count(PowerUp.Type.UPGRADE) == upgrade \
		and _disk_dough() == dough and powerups is Dictionary and int((powerups as Dictionary).get("upgrade", -1)) == upgrade


func _free_claimed() -> bool:
	return bool((SaveManager.data.get("daily_rewards", {}) as Dictionary).get("free_chest_claimed", false))


func _disk_free_claimed() -> Variant:
	var daily: Variant = _disk("daily_rewards")
	return (daily as Dictionary).get("free_chest_claimed") if daily is Dictionary else null


func _disk_dough() -> int:
	var dough: Variant = _disk("dough")
	return int(dough) if dough != null else -1


func _disk(key: String) -> Variant:
	if not FileAccess.file_exists(PATH):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return (parsed as Dictionary).get(key) if parsed is Dictionary else null


func _save_bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(PATH) if FileAccess.file_exists(PATH) else PackedByteArray()


func _screen(canvas: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * canvas


func _center(control: Control) -> Vector2:
	return _screen(control.get_global_rect().get_center())


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


## Yorumları atar (## / # satırları ve satır sonu yorumları — dizgi içindeki # korunur).
func _strip_comments(src: String) -> String:
	var out: PackedStringArray = []
	for line: String in src.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


## `header` ile başlayan fonksiyonun gövdesi (bir sonraki üst düzey `func` / `static func` satırına kadar).
func _function(code: String, header: String) -> String:
	var at: int = code.find(header)
	if at < 0:
		return ""
	var rest: String = code.substr(at)
	var lines: PackedStringArray = rest.split("\n")
	var out: PackedStringArray = [lines[0]]
	for i in range(1, lines.size()):
		var line: String = lines[i]
		if line.begins_with("func ") or line.begins_with("static func ") or line.begins_with("class "):
			break
		out.append(line)
	return "\n".join(out)
