extends Node
## TASK/045 — Oyuncu İlerlemesi UI testi. Headless; kayıt dosyasını byte-identical geri
## koyar.
##
##   godot --headless --audio-driver Dummy --path . res://tools/progression_ui_test.tscn
##
## Kontroller:
##   profil      kimlik: "Oyuncu" + altında seçili unvan (≥ 48 dokunma) + LV rozeti +
##               XP rayı ("84 / 180 XP", SONRAKİ: LV. 8) — yeni, kısmi, tam sınır, bir
##               eksik, LV 12 / 137 / bozukluk sınırı; BAŞARIMLAR "N / 12" + ray +
##               sıradaki hedefler (her kategorinin ilki, yakın olan önce) + 12/12
##               altın; açılış yalnız BELLEKTE uzlaştırır (disk yazması yok).
##   başarımlar  TÜM BAŞARIMLAR → Profil'e ait pencere (sekme değişmez): 12 kart katalog
##               sırasıyla + 4 kategori; kilitli / açık kart içerikleri, unvan satırı,
##               ilerleme; aç / kaydır / kapat YAZMAZ; X / Android geri kapatır.
##   unvanlar    9 satır, kilitliler pasif + koşul yazısı; kilitli (kod yolu) yazmaz;
##               açık TEK yazma + Profil hemen güncellenir; aynı unvan yazmaz; hızlı
##               ikinci dokunuş (eylem kilidi) ikinci yazma üretmez; Android geri
##               değişiklik yapmadan kapatır; seçim yeniden yüklemede kalıcı; seçim
##               pop'u gerçek basış sırasında (button_up'tan sonra) görünür.
##   yatışma     gerçek parmak (ScreenTouch): Profil → Başarımlar / Unvanlar açılışı,
##               pencere kapanışı ve seçim sonrası ikinci dokunuş EYLEMLİ bir kontrole
##               (açık satır, dişli, karartma, CTA) düşer ve yutulur; kod yolu ve masaüstü
##               fare etkilenmez; otomatik günlük pencere Profil penceresinin üstüne açılmaz.
##   sonuç       gerçek Main round'ları: +XP, seviye atlama (LV metni), başarım (tek /
##               çok), çok seviye; göç / geriye dönük açılış sonuç şeridine GİRMEZ;
##               eski çağıran (özetsiz) şeridi gizler; CTA'lar ilk kareden aktif.
##   yerleşim    320×568 · 360×640 · 390×844 · 360×800 · 720×1280 · 1080×2340 (+A36):
##               kimlik (uzun unvan + LV 137), pencereler (A36 güvenli payında kurdele / X
##               payın altında), rozet + hedef çipi kart dudağına binmez, şerit — kırpma /
##               taşma yok.
##   kaynak      yeni UI dosyaları kayda / ekonomiye / reklama dokunmaz; tek yazma
##               `TitleSelector` → `select_title`.
##   reklam      sahte arka uç: Profil + iki pencere banner'sız (yüzey NONE).

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const VIEWS: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(320, 568), Vector2i(360, 640),
	Vector2i(390, 844), Vector2i(360, 800), Vector2i(1080, 2340)]
const A36_SAFE_TOP: float = 61.0
const SECTIONS: int = 8
const NEW_UI_FILES: Array[String] = ["achievement_badge.gd", "achievement_card.gd", "achievements_overlay.gd",
	"player_level_badge.gd", "player_level_bar.gd", "result_progress_strip.gd", "title_row.gd", "title_selector.gd"]
const WRITE_CALLS: Array[String] = ["save_game(", "data[", "grant_", "purchase", "spend_dough", "add_dough",
	"record_", "showcase_add", "showcase_remove", "showcase_replace", "showcase_make_first", "complete_level",
	"add_merges", "reconcile_achievements"]
const AD_WORDS: Array[String] = ["MonetizationManager", "banner", "Banner", "interstitial", "rewarded", "_set_ad_surface"]

var _fails: int = 0
var _checks: int = 0
var _saved: Dictionary = {}
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _main: Node2D
var _finished: bool = false
var _sections_done: int = 0
var _main_script: GDScript = load("res://scripts/main.gd")


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	_saved = SaveManager.data.duplicate(true)
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	get_tree().create_timer(360.0).timeout.connect(func() -> void:
		if not _finished:
			print("  [FAIL] bekçi: test 360 s'de bitmedi — kayıt geri kondu")
			SaveManager.data = _saved
			_restore_save_file()
			get_tree().quit(2))
	_state(0, 0, 0, 0, 0)
	get_window().size = Vector2i(720, 1000)
	await get_tree().process_frame
	await _resize(VIEWS[0])
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _settle(2)
	var profile: CanvasLayer = _main._screens[4]

	await _profile_level(profile)
	await _achievements_ui(profile)
	await _titles_ui(profile)
	await _touch_settle(profile)
	await _result_strip()
	await _layout_all(profile)
	_source_scan()
	await _ads_no_banner()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	print("-- kayıt")
	SaveManager.data = _saved
	_restore_save_file()
	# Diğer suitlerle aynı: geri konan dosya yeniden yüklenir, yükleme de yazmamalı.
	SaveManager.load_game()
	var restored: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) if _had_save else PackedByteArray()
	_c("kayıt dosyası byte-identical geri kondu (%d bayt)" % _save_bytes.size(), restored == _save_bytes
		and FileAccess.file_exists(SaveManager.SAVE_PATH) == _had_save)
	_finished = true
	print("\nSONUC: %d kontrol, %d hata" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _exit_tree() -> void:
	if _finished:
		return
	print("  [FAIL] test SONUC'tan önce ağaçtan çıktı — kayıt geri kondu")
	SaveManager.data = _saved
	_restore_save_file()


# --- Profil: seviye / unvan / başarım özeti ----------------------------------------------------

func _profile_level(profile: CanvasLayer) -> void:
	print("-- Profil: seviye / unvan / başarım özeti")
	# Açılış yazmaz: ÖNCE uzlaştırma gerektiren kayıt (150 merge, boş başarım listesi) diske,
	# anlık görüntü Profil'e GEÇMEDEN alınır (lens 8: görüntü açılıştan sonra alınıyordu).
	_state(0, 150, 0, 0, 0)
	SaveManager.save_game()
	_main._show_tab(0)
	await _settle(2)
	var opened_before: PackedByteArray = _bytes()
	_main._show_tab(4)
	await _settle(2)
	_c("uzlaştırma gerektiren kayıtla Profil'e geçmek kayda YAZMADI (açılış yalnız bellekte uzlaştırır)",
		_bytes() == opened_before and profile.achievements_count_text() == "2 / 12")
	_state(0, 0, 0, 0, 0)
	SaveManager.save_game()
	await _show_profile()
	var file_before: PackedByteArray = _bytes()
	var bar: PlayerLevelBar = profile.level_bar()
	_c("yeni oyuncu: LV. 1, '0 / 60 XP', ray boş, 'SONRAKİ: LV. 2'", bar.level_text() == "LV. 1"
		and bar.xp_text() == "0 / 60 XP" and is_zero_approx(bar.rail().value) and bar.next_text() == "SONRAKİ: LV. 2")
	var name_rect: Rect2 = profile.content().get_node("Identity").find_child("PlayerName", true, false).get_global_rect()
	var title_rect: Rect2 = profile.title_button().get_global_rect()
	_c("unvan 'Birleştirici' adın hemen altında, dokunma ≥ 48", profile.title_text() == "Birleştirici"
		and title_rect.size.y >= 48.0 and title_rect.position.y >= name_rect.end.y - 1.0
		and title_rect.position.y - name_rect.end.y < 24.0)
	_c("seviye satırı kimlik kartının içinde, avatar satırının altında", profile.content().get_node("Identity")
		.get_global_rect().encloses(bar.get_global_rect()) and bar.get_global_rect().position.y > title_rect.end.y)
	_c("başarım özeti '0 / 12', ray 0, 'SIRADAKİ HEDEFLERİN'", profile.achievements_count_text() == "0 / 12"
		and is_zero_approx(profile.achievements_bar().value) and profile.achievements_caption_text() == "SIRADAKİ HEDEFLERİN")
	_c("yeni oyuncu sıradaki hedefler: İlk Squish · İlk Parıltılar · Yolculuk Başlıyor (kategori başına ilki)",
		_preview_ids(profile) == [&"first_merge", &"stars_5", &"levels_3"])
	_c("Profil kontrolleri okurken kayda YAZMADI", _bytes() == file_before)

	for probe in [[744, "LV. 7", "84 / 180 XP", 84.0 / 180.0, "SONRAKİ: LV. 8"],
			[839, "LV. 7", "179 / 180 XP", 179.0 / 180.0, "SONRAKİ: LV. 8"],
			[840, "LV. 8", "0 / 200 XP", 0.0, "SONRAKİ: LV. 9"],
			[PlayerProgression.total_xp_for_level(12) + 150, "LV. 12", "150 / 280 XP", 150.0 / 280.0, "SONRAKİ: LV. 13"],
			[PlayerProgression.total_xp_for_level(137) + 222, "LV. 137", "222 / 400 XP", 222.0 / 400.0, "SONRAKİ: LV. 138"]]:
		_state(probe[0], 0, 0, 0, 0)
		profile.refresh()
		_c("%d XP: %s, '%s', ray %.3f (bir sonraki seviyeye ilerleme)" % [probe[0], probe[1], probe[2], probe[3]],
			bar.level_text() == probe[1] and bar.xp_text() == probe[2] and is_equal_approx(bar.rail().value, probe[3])
			and bar.next_text() == probe[4])
	_state(PlayerProgression.MAX_XP, 0, 0, 0, 0)
	profile.refresh()
	await _settle(1)
	var number: Label = bar.badge().number_label()
	_c("bozukluk sınırı (LV. %s): rakamlar rozete sığıyor (punto küçüldü)" % bar.badge().number_text(),
		_text_width(number, number.text) <= bar.badge().size.x and number.get_theme_font_size("font_size") < 20)

	_state(0, 150, 0, 0, 0)
	SaveManager.save_game()
	var bytes: PackedByteArray = _bytes()
	profile.refresh()
	_c("uzlaştırma: 150 merge'lük kayıt boş listeyle → Profil 2 / 12 (İlk Squish + Hamur Isınıyor), disk yazılmadı",
		profile.achievements_count_text() == "2 / 12" and SaveManager.is_achievement_unlocked(&"merge_100")
		and _bytes() == bytes)
	_c("uzlaştırılan sıradaki hedef merge kategorisinde bir sonrakine geçti (Birleşme Ustası 150 / 500)",
		_preview_ids(profile).has(&"merge_500") and not _preview_ids(profile).has(&"merge_100"))

	_state(40000, 98765, 30, 10, 20)
	profile.refresh()
	_c("12 / 12: altın ray + yıldız, 'Tüm başarımlar tamam — harikasın!', sıradaki hedef yok",
		profile.achievements_count_text() == "12 / 12" and profile.achievements_bar().theme_type_variation == &"ProgressBarGold"
		and profile.achievements_caption_text() == "Tüm başarımlar tamam — harikasın!" and profile.achievement_previews().is_empty())
	_sections_done += 1


func _preview_ids(profile: CanvasLayer) -> Array[StringName]:
	var out: Array[StringName] = []
	for card: AchievementCard in profile.achievement_previews():
		out.append(card.achievement_id())
	return out


# --- Başarımlar penceresi ---------------------------------------------------------------------------

func _achievements_ui(profile: CanvasLayer) -> void:
	print("-- TÜM BAŞARIMLAR penceresi")
	_state(3000, 540, 16, 4, 11)
	SaveManager.save_game()
	await _show_profile()
	var bytes: PackedByteArray = _bytes()
	profile.achievements_cta().pressed.emit()
	await _settle(2)
	var overlay: AchievementsOverlay = profile.achievements_overlay()
	_c("TÜM BAŞARIMLAR → Profil'e ait pencere açık, sekme değişmedi (yeni alt sekme yok)", overlay.visible
		and _main._active_tab == 4 and profile.visible)
	var ids: Array[StringName] = []
	for card in overlay.cards():
		ids.append(card.achievement_id())
	_c("12 kart katalog sırasıyla + 4 kategori başlığı", ids == AchievementCatalog.ids() and overlay.group_headers().size() == 4)
	_c("sayı '8 / 12' (Profil ile aynı kaynak)", overlay.count_text() == "8 / 12"
		and profile.achievements_count_text() == "8 / 12")
	var locked: AchievementCard = overlay.card(&"merge_1000")
	_c("kilitli kart GÖRÜNÜR: ad, açıklama, '540 / 1000', 'Unvan: Efsane Birleştirici', kilit, AÇILDI yok",
		locked.visible and locked.name_text() == "Bin Bir Squish" and locked.description_text() == "Toplam 1000 birleşme yap."
		and locked.progress_text() == "540 / 1000" and locked.title_text() == "Unvan: Efsane Birleştirici"
		and locked.badge().lock_visible() and not locked.is_open_shown() and locked.rail().theme_type_variation == &"ProgressBarMint")
	var open: AchievementCard = overlay.card(&"merge_100")
	_c("açık kart: '100 / 100', AÇILDI çipi, altın ray, rozet renkli (kilit yok)", open.progress_text() == "100 / 100"
		and open.is_open_shown() and open.rail().theme_type_variation == &"ProgressBarGold"
		and open.badge().is_unlocked() and not open.badge().lock_visible())
	_c("unvansız başarım (İlk Squish) unvan satırı göstermez; rozet hedef çipi '1'",
		overlay.card(&"first_merge").title_text() == "" and overlay.card(&"first_merge").badge().pip_text() == "1")
	_c("12 rozetin sanatı + hedef çipi ayırt edilir (aynı sanat + aynı çip ikilisi yok)", _badges_distinct(overlay))
	var scroll: ScrollContainer = overlay.scroll()
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _settle(2)
	var host: Rect2 = (overlay.frame().get_meta(&"body_host") as Control).get_global_rect()
	var last: AchievementCard = overlay.cards()[overlay.cards().size() - 1]
	_c("kaydırma sonu: son kart (Squishy Arşivcisi) gövdede tamamen görünür", host.grow(1.0).encloses(last.get_global_rect()))
	_c("açmak / kaydırmak kayda YAZMADI", _bytes() == bytes)
	_main._last_back_msec = -1000
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("Android geri → pencere kapandı, Profil'de kalındı (Ana Sayfa'ya düşmedi)", not overlay.visible
		and _main._active_tab == 4 and profile.visible)
	profile.open_achievements()
	await _settle(1)
	(overlay.frame().get_meta(&"close_button") as Button).pressed.emit()
	_c("X → kapandı; kapatmak kayda yazmadı", not overlay.visible and _bytes() == bytes)
	_main._last_back_msec = -1000
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("pencere yokken Android geri → Ana Sayfa (Profil davranışı aynen)", _main._active_tab == 0)
	_sections_done += 1


func _badges_distinct(overlay: AchievementsOverlay) -> bool:
	var seen: Dictionary = {}
	for card in overlay.cards():
		var key: String = "%s|%s" % [str(card.badge().art_texture().get_rid()), card.badge().pip_text()]
		if seen.has(key):
			return false
		seen[key] = true
	return true


# --- Unvan seçici --------------------------------------------------------------------------------

func _titles_ui(profile: CanvasLayer) -> void:
	print("-- unvan seçici")
	_state(200, 120, 3, 1, 2)
	SaveManager.save_game()
	await _show_profile()
	profile.title_button().pressed.emit()
	await _settle(2)
	var selector: TitleSelector = profile.title_selector()
	var ids: Array[StringName] = []
	for row in selector.rows():
		ids.append(row.title_id())
	_c("unvan eylemi → seçici açık, 9 satır katalog sırasıyla", selector.visible and ids == AchievementCatalog.title_ids())
	_c("varsayılan satır SEÇİLİ ('SEÇİLİ UNVAN'), etkin", selector.row(&"birlestirici").is_selected_shown()
		and selector.row(&"birlestirici").status_text() == "SEÇİLİ UNVAN" and not selector.row(&"birlestirici").disabled)
	var disabled: int = 0
	for row in selector.rows():
		if row.disabled:
			disabled += 1
	_c("kilitliler PASİF (7), açık Hamur Ustası etkin ('Açıldı · Hamur Isınıyor')", disabled == 7
		and not selector.row(&"hamur_ustasi").disabled and selector.row(&"hamur_ustasi").status_text() == "Açıldı · Hamur Isınıyor")
	_c("kilitli satır koşulu gösterir: 'Kilitli · Toplam 1000 birleşme yap.'",
		selector.row(&"efsane_birlestirici").status_text() == "Kilitli · Toplam 1000 birleşme yap.")
	var bytes: PackedByteArray = _bytes()
	selector.row(&"efsane_birlestirici").pressed.emit()
	await _settle(1)
	_c("kilitli unvan (kod yolunda bile) seçilmez: yazma yok, seçim varsayılan", _bytes() == bytes
		and SaveManager.selected_title_id() == &"birlestirici")
	selector.row(&"hamur_ustasi").pressed.emit()
	await _settle(1)
	_c("açık unvan seçildi: kayıt yazıldı, dosyada 'hamur_ustasi'", _bytes() != bytes
		and String(_read_save_file().get("selected_title_id", "")) == "hamur_ustasi")
	_c("Profil HEMEN güncellendi (pencere açıkken): unvan 'Hamur Ustası'", profile.title_text() == "Hamur Ustası")
	_c("satırlar güncellendi: Hamur Ustası SEÇİLİ, varsayılan değil", selector.row(&"hamur_ustasi").is_selected_shown()
		and not selector.row(&"birlestirici").is_selected_shown() and selector.visible)
	await get_tree().create_timer(0.45).timeout
	bytes = _bytes()
	selector.row(&"hamur_ustasi").pressed.emit()
	await _settle(1)
	_c("aynı unvana yeniden basmak: gereksiz yazma YOK", _bytes() == bytes)
	selector.row(&"birlestirici").pressed.emit()
	selector.row(&"hamur_ustasi").pressed.emit()
	await _settle(1)
	_c("seçimin hemen ardından ikinci dokunuş (350 ms eylem kilidi) ikinci yazma üretmedi",
		SaveManager.selected_title_id() == &"birlestirici")
	bytes = _bytes()
	_main._last_back_msec = -1000
	_main._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("Android geri → seçici kapandı, değişiklik yok, Profil'de", not selector.visible and _bytes() == bytes
		and _main._active_tab == 4)
	SaveManager.load_game()
	_c("seçim yeniden yüklemede kalıcı (Birleştirici)", SaveManager.selected_title_id() == &"birlestirici")
	# Gerçek dokunuş sırası button_down → pressed → button_up: seçim pop'u bırakışın basış
	# geri dönüşünden SONRA oynar (lens 5: aynı olaydaki button_up pop'u öldürüyordu).
	profile.open_title_selector()
	await get_tree().create_timer(UiMotion.MODAL_TIME + 0.08).timeout
	var pop_row: TitleRow = selector.row(&"hamur_ustasi")
	pop_row.button_down.emit()
	pop_row.pressed.emit()
	pop_row.button_up.emit()
	var peak: float = 0.0
	var until: int = Time.get_ticks_msec() + 350
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		peak = maxf(peak, pop_row.scale.x)
	_c("seçim pop'u gerçek basış sırasında görünür (tepe ölçek %.3f > 1)" % peak, peak > 1.005
		and SaveManager.selected_title_id() == &"hamur_ustasi")
	selector.close(false)
	_state(200, 1200, 3, 1, 2)
	SaveManager.data["selected_title_id"] = "hamur_ustasi"
	SaveManager.save_game()
	await _show_profile()
	_c("yeni açılan unvan (Efsane Birleştirici) otomatik SEÇİLMEDİ — seçim Hamur Ustası kaldı",
		AchievementCatalog.is_title_unlocked(&"efsane_birlestirici", SaveManager.unlocked_achievements())
		and profile.title_text() == "Hamur Ustası")
	_sections_done += 1


# --- Parmak yatışması (hızlı çift dokunuş) -------------------------------------------------------

func _touch_settle(profile: CanvasLayer) -> void:
	print("-- parmak yatışması: pencere açılış / kapanış / seçim")
	_state(200, 1200, 3, 1, 2)
	SaveManager.save_game()
	await _show_profile()
	await _wait_settled()
	var overlay: AchievementsOverlay = profile.achievements_overlay()
	var selector: TitleSelector = profile.title_selector()
	# 1) Profil → Unvanlar: açılışın hemen ardından gelen ikinci dokunuş EYLEM yapan bir
	#    satıra (açık + seçili değil → seçer ve yazar) düşer ve yutulmalı. (Lens 8: eskiden
	#    ikinci dokunuş zaten eylemsiz başlığa / seçili satıra düşüyordu — kontrol düşemezdi.)
	var title_pos: Vector2 = _screen_center(profile.title_button())
	await _finger_tap(title_pos)
	_c("parmak: unvan eylemi → seçici açık", selector.visible)
	var target_row: TitleRow = selector.row(&"hamur_ustasi")
	var target_pos: Vector2 = _screen_center(target_row)
	_c("ön koşul: ikinci dokunuşun hedefi eylem yapar (Hamur Ustası açık, seçili değil, noktada o satır)",
		not target_row.disabled and not target_row.is_selected_shown() and _row_at(selector, target_pos) == target_row)
	var bytes: PackedByteArray = _bytes()
	await _finger_tap(target_pos)
	_c("açılışın hemen ardından açık satıra dokunuş yutuldu: seçim / yazma yok",
		_bytes() == bytes and SaveManager.selected_title_id() == &"birlestirici" and selector.visible)
	await _wait_settled()
	# 2) Seçim → aynı karede başka satır.
	var row_a: TitleRow = selector.row(&"hamur_ustasi")
	var row_b: TitleRow = selector.row(&"birlesme_ustasi")
	await _finger_tap(_screen_center(row_a))
	_c("parmak: açık satır seçildi (Hamur Ustası)", SaveManager.selected_title_id() == &"hamur_ustasi")
	bytes = _bytes()
	await _finger_tap(_screen_center(row_b))
	_c("seçimin hemen ardından başka satıra dokunuş ikinci yazma üretmedi", SaveManager.selected_title_id() == &"hamur_ustasi"
		and _bytes() == bytes)
	await _wait_settled()
	# 3) Kapat (X) → hemen ardından Profil'in EYLEM yapan bir kontrolüne (dişli → Ayarlar)
	#    düşen dokunuş yutulmalı.
	var close: Button = selector.frame().get_meta(&"close_button")
	var close_pos: Vector2 = _screen_center(close)
	await _finger_tap(close_pos)
	_c("parmak: X → seçici kapandı", not selector.visible)
	var gear: Button = profile.top_bar().action_button()
	_c("ön koşul: dişli görünür ve etkin (dokunuş Ayarlar'ı açardı)", gear != null and gear.is_visible_in_tree()
		and not gear.disabled)
	await _finger_tap(_screen_center(gear))
	_c("kapanışın hemen ardından dişliye dokunuş yutuldu: Ayarlar / başka ekran açılmadı", not _main._settings.visible
		and _main._active_tab == 4 and not overlay.visible and not selector.visible)
	await _wait_settled()
	await _finger_tap(_screen_center(gear))
	_c("yatışmadan sonra dişli Ayarlar'ı açar (kontrol gerçekten eylemli)", _main._settings.visible)
	_main._settings.close_panel()
	await _wait_settled()
	# 4) Profil → Başarımlar: CTA'nın yerine düşen ikinci dokunuş karartmaya / karta.
	var scroll: ScrollContainer = profile.scroll()
	var cta: Button = profile.achievements_cta()
	# CTA ekranın ortasına (içerik koordinatı − 400 px) kaydırılır.
	scroll.scroll_vertical = int(cta.global_position.y - scroll.global_position.y + scroll.scroll_vertical - 400.0)
	await _settle(2)
	await _wait_settled()
	var cta_pos: Vector2 = _screen_center(cta)
	await _finger_tap(cta_pos)
	_c("parmak: TÜM BAŞARIMLAR → pencere açık", overlay.visible)
	var dim_pos: Vector2 = _dim_point(overlay.frame())
	await _finger_tap(dim_pos)
	_c("açılışın hemen ardından karartmaya dokunuş yutuldu: pencere açık", overlay.visible)
	await _wait_settled()
	await _finger_tap(dim_pos)
	_c("yatışmadan sonra karartma kapatır (UiKit sözleşmesi aynen)", not overlay.visible)
	await _finger_tap(cta_pos)
	_c("kapanışın hemen ardından CTA'ya dokunuş yutuldu: yeniden açılmadı", not overlay.visible)
	await _wait_settled()
	await _finger_tap(cta_pos)
	_c("yatışmadan sonra CTA yine açar", overlay.visible)
	overlay.close(false)
	await _wait_settled()
	print("-- yatışma kod yolunu / masaüstü fareyi etkilemez")
	profile.open_achievements()
	(overlay.frame().get_meta(&"close_button") as Button).pressed.emit()
	profile.title_button().pressed.emit()
	_c("kod yolu: kapanışın hemen ardından pressed.emit() → seçici açıldı", selector.visible)
	selector.close(false)
	profile.open_title_selector()
	# Açılış tween'i (0.2 s, ölçek 0.92 → 1) bitsin; sonra yatışma penceresi yeniden
	# kurulur — fare olayı tam o pencerede verilir.
	await get_tree().create_timer(UiMotion.MODAL_TIME + 0.12).timeout
	_main.settle_touch_input()
	await _mouse_click(_screen_center(selector.frame().get_meta(&"close_button")))
	_c("masaüstü fare tıklaması (device 0) yatışma penceresi içinde çalışır → X kapattı", not selector.visible)
	await _wait_settled()

	# 5) Otomatik günlük pencere Profil penceresinin ÜSTÜNE açılmaz (lens 6: kapanınca Profil
	#    tazelenip pencerenin altında başa kayıyordu); pencere kapanınca aynı çağrı açar.
	print("-- otomatik günlük pencere Profil penceresinin üstüne açılmaz")
	var band_before: int = _main._age_band
	_main._age_band = AgeGate.Band.ADULT
	var daily_raw: Dictionary = (SaveManager.data.get("daily_rewards", {}) as Dictionary).duplicate()
	daily_raw["popup_seen_day"] = ""
	SaveManager.data["daily_rewards"] = daily_raw
	DailyRewards.auto_popup_enabled = true
	_c("ön koşul: otomatik günlük pencere bugün due, yaş kapısı açık", DailyRewards.popup_due()
		and not _main._age_blocks_monetizable_surfaces())
	profile.open_achievements()
	await _settle(1)
	_main._maybe_auto_open_daily_rewards()
	await _settle(1)
	_c("Başarımlar açıkken otomatik günlük pencere açılmadı (hâlâ due)", not _main._daily_rewards.visible
		and overlay.visible and DailyRewards.popup_due())
	overlay.close(false)
	profile.open_title_selector()
	await _settle(1)
	_main._maybe_auto_open_daily_rewards()
	await _settle(1)
	_c("Unvanlar açıkken de açılmadı", not _main._daily_rewards.visible and selector.visible)
	selector.close(false)
	_main._maybe_auto_open_daily_rewards()
	await _settle(1)
	_c("pencereler kapanınca aynı çağrı günlük pencereyi açar (kapı yalnız pencere varken)", _main._daily_rewards.visible)
	_main._daily_rewards.close_popup()
	DailyRewards.auto_popup_enabled = false
	_main._age_band = band_before
	await _wait_settled()
	_sections_done += 1


func _row_at(selector: TitleSelector, screen_pos: Vector2) -> TitleRow:
	var canvas: Vector2 = get_viewport().get_screen_transform().affine_inverse() * screen_pos
	for row in selector.rows():
		if row.get_global_rect().has_point(canvas):
			return row
	return null


## Pencerenin altında / üstünde karartmaya düşen bir nokta (pencere piksel). Açılış
## tween'i ölçeği merkez etrafında değiştirir: SON dikdörtgen merkez + ölçeksiz boyuttan
## (ölçekli `get_global_rect` tween ortasında küçük çıkar). Geniş olan boşluğun ortası.
func _dim_point(frame: Control) -> Vector2:
	var center: Vector2 = frame.get_global_rect().get_center()
	var final_rect := Rect2(center - frame.size * 0.5, frame.size)
	var view_h: float = get_viewport().get_visible_rect().size.y
	var below: float = view_h - final_rect.end.y
	# Üstte kurdele 34 px taşar.
	var above: float = final_rect.position.y - UiKit.MODAL_RIBBON_OVERHANG
	var point := Vector2(center.x, final_rect.end.y + below * 0.5) if below >= above \
		else Vector2(center.x, above * 0.5)
	return get_viewport().get_screen_transform() * point


# --- Sonuç şeridi ---------------------------------------------------------------------------------

func _result_strip() -> void:
	print("-- sonuç ekranı: kompakt XP / seviye / başarım şeridi")
	# +XP (seviye atlamaz, başarım yok).
	_state(PlayerProgression.total_xp_for_level(3) + 30, 40, 0, 2, 2)
	await _play(2, true, 14, "star2")
	var strip: ResultProgressStrip = _main._result.progress_strip()
	_c("+XP: şerit görünür, '+54 XP' (14 + 20 + 2 yeni yıldız·10), LV. 3, '84 / 100 XP'", strip.visible
		and strip.gain_text() == "+54 XP" and strip.level_bar().level_text() == "LV. 3"
		and strip.level_bar().xp_text() == "84 / 100 XP")
	_c("seviye atlamadı → 'SEVİYE ATLADIN!' yok; başarım yok", not strip.level_up_visible() and strip.achievement_text() == "")
	_c("şerit altlıkta, çerçevenin ve ekranın içinde; CTA'lar etkin", _strip_inside(strip)
		and not _main._result.primary_button().disabled)
	await _leave()
	# Seviye atlama.
	_state(PlayerProgression.total_xp_for_level(5) - 8, 60, 12, 3, 2)
	await _play(4, true, 12, "star3")
	strip = _main._result.progress_strip()
	_c("seviye atlama: 'SEVİYE ATLADIN! · LV. 5', rozet LV. 5", strip.level_up_visible()
		and strip.level_up_text() == "SEVİYE ATLADIN! · LV. 5" and strip.level_bar().level_text() == "LV. 5")
	await _leave()
	# Tek başarım.
	_state(PlayerProgression.total_xp_for_level(6) + 10, 95, 12, 3, 2)
	await _play(4, false, 5, "")
	strip = _main._result.progress_strip()
	_c("başarım: 'Başarım açıldı: Hamur Isınıyor' (+5 XP, seviye yok)", strip.achievement_text() == "Başarım açıldı: Hamur Isınıyor"
		and strip.gain_text() == "+5 XP" and not strip.level_up_visible())
	await _leave()
	# Seviye + çok başarım.
	_state(PlayerProgression.total_xp_for_level(4) - 5, 95, 4, 2, 2)
	await _play(3, true, 9, "star3")
	strip = _main._result.progress_strip()
	_c("seviye + başarım birlikte: 'SEVİYE ATLADIN! · LV. 4' + '3 başarım açıldı'", strip.level_up_visible()
		and strip.level_up_text() == "SEVİYE ATLADIN! · LV. 4" and strip.achievement_text() == "3 başarım açıldı")
	_c("iki rozet şeritte (kırpma yok)", _strip_inside(strip) and _labels_fit(strip))
	await _leave()
	# Çok seviye.
	_state(50, 480, 0, 0, 2)
	await _play(1, true, 150, "star3")
	strip = _main._result.progress_strip()
	var summary: Dictionary = strip.summary()
	_c("çok seviye: +200 XP, LV. 1 → 4 (3 seviye), son seviye gösterilir", strip.gain_text() == "+200 XP"
		and int(summary["levels_gained"]) == 3 and strip.level_bar().level_text() == "LV. 4"
		and strip.level_up_text() == "SEVİYE ATLADIN! · LV. 4")
	await _leave()
	# Göç / geriye dönük açılış şeride GİRMEZ.
	_write_save({"highest_level_unlocked": 4, "level_stars": {"1": 2, "2": 2, "3": 2}, "total_merges": 812,
		"unlocked_skins": ["common_01"], "powerups": {"bomb": 1, "upgrade": 1, "shake": 1, "clear_small": 1},
		"powerup_starter_granted": true, "onboarding_completed": true, "age_ad_band": "ADULT",
		"last_login_date": Time.get_date_string_from_system()})
	SaveManager.load_game()
	_c("ön koşul: eski kayıt bootstrap 932 XP + geriye dönük başarımlar (bellekte)", SaveManager.player_xp() == 932
		and SaveManager.is_achievement_unlocked(&"merge_500"))
	await _play(2, false, 3, "")
	strip = _main._result.progress_strip()
	_c("göçten sonraki ilk round: şerit yalnız round'un +3 XP'si; göç XP'si / geriye dönük başarım GÖSTERİLMEDİ",
		strip.gain_text() == "+3 XP" and strip.achievement_text() == "" and not strip.level_up_visible()
		and int(strip.summary()["xp_before"]) == 932)
	await _leave()
	# Özetsiz eski çağıran.
	_main._start_level(_level(2))
	await _settle(2)
	_main._board.round_finished.disconnect(_main._on_round_finished)
	_main._board._finish(true)
	var no_rewards: Array[ChestReward] = []
	_main._result.show_result(_level(2), true, 100, 1, no_rewards, false)
	await _settle(2)
	_c("özetsiz eski çağıran (araç / test): şerit gizli, sonuç aynen", not _main._result.progress_strip().visible
		and _main._result.visible)
	await _leave()
	_sections_done += 1


func _play(level_number: int, won: bool, merges: int, stars: String) -> void:
	var level: LevelData = _level(level_number)
	seed(4545)
	_main._start_level(level)
	await _settle(2)
	for i in merges:
		GameState.register_merge(2 + (i % 3), Vector2(360, 700))
	match stars:
		"star3":
			GameState.add_score(level.star_3_threshold())
		"star2":
			GameState.add_score(level.star_2_threshold())
		_:
			GameState.add_score(10)
	_main._board._finish(won)
	await get_tree().create_timer(_main.RESULT_DELAY + 0.2).timeout
	var result: CanvasLayer = _main._result
	var waited: int = 0
	while (not result.is_reveal_done() or result.progress_strip().level_bar().is_animating()) and waited < 60 * 14:
		await get_tree().process_frame
		waited += 1
	await get_tree().create_timer(0.3).timeout


func _leave() -> void:
	_main._result.hide_result()
	_main.abandon_run()
	await _settle(1)
	_main._show_tab(0)
	await _settle(1)


func _strip_inside(strip: ResultProgressStrip) -> bool:
	var frame: Rect2 = _main._result.frame().get_global_rect()
	var view: Rect2 = get_viewport().get_visible_rect()
	var r: Rect2 = strip.get_global_rect()
	return frame.grow(1.0).encloses(r) and view.encloses(r)


func _labels_fit(root: Node) -> bool:
	for node in _all_nodes(root):
		if node is Label and (node as Label).is_visible_in_tree() and not (node as Label).autowrap_mode:
			var l: Label = node
			if _text_width(l, l.text) > l.size.x + 0.5:
				print("    kırpılan: '%s' (%.0f > %.0f)" % [l.text, _text_width(l, l.text), l.size.x])
				return false
	return true


# --- Yerleşim -------------------------------------------------------------------------------------

func _layout_all(profile: CanvasLayer) -> void:
	print("-- yerleşim")
	for view in VIEWS:
		await _resize(view)
		await _layout_view(profile, view, 0.0)
	await _resize(VIEWS[5])
	profile._layout_with_safe_top(A36_SAFE_TOP)
	await _layout_view(profile, VIEWS[5], A36_SAFE_TOP)
	profile._layout_with_safe_top(-1.0)
	await _resize(VIEWS[0])
	_sections_done += 1


func _layout_view(profile: CanvasLayer, view_size: Vector2i, safe_top: float) -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var tag: String = "%dx%d (tuval %dx%d)%s" % [view_size.x, view_size.y, roundi(view.x), roundi(view.y),
		" +A36" if safe_top > 0.0 else ""]
	_state(PlayerProgression.total_xp_for_level(137) + 222, 1204, 30, 10, 20)
	SaveManager.data["selected_title_id"] = "efsane_birlestirici"
	SaveManager.data["profile_showcase"] = ["legendary_02", "epic_03", "rare_02"]
	await _show_profile()
	profile.scroll().scroll_vertical = 0
	await _settle(2)
	var identity: Control = profile.content().get_node("Identity")
	var card: Rect2 = identity.get_global_rect()
	var title: Rect2 = profile.title_button().get_global_rect()
	var avatar: Rect2 = profile.avatar().get_global_rect()
	_c("%s uzun unvan 'Efsane Birleştirici' hapı kartın içinde, avatarla çakışmıyor, yazı kırpılmadı" % tag,
		profile.title_text() == "Efsane Birleştirici" and card.encloses(title) and not title.intersects(avatar)
		and _labels_fit(profile.title_button()))
	var bar: PlayerLevelBar = profile.level_bar()
	_c("%s LV. 137 satırı kartın içinde, yazılar sığıyor ('222 / 400 XP', 'SONRAKİ: LV. 138')" % tag,
		card.encloses(bar.get_global_rect()) and _labels_fit(bar) and bar.xp_text() == "222 / 400 XP")
	_c("%s kimlik kartı üst satırın altında, güvenli payda" % tag, card.position.y >= safe_top + 4.0)
	var ach_card: Control = profile.content().get_node("AchievementsCard")
	_c("%s BAŞARIMLAR kartı yazıları sığıyor" % tag, _labels_fit(ach_card))
	# Pencereler — güvenli üst payla da (lens 6: tam boy pencerenin kurdelesi / X'i A36
	# benzeri payda durum çubuğuna giriyordu). Açılış tween'i bitince ölçülür.
	profile.open_achievements()
	await get_tree().create_timer(UiMotion.MODAL_TIME + 0.08).timeout
	var overlay: AchievementsOverlay = profile.achievements_overlay()
	await _check_modal(overlay.frame(), overlay.scroll(), overlay.cards()[overlay.cards().size() - 1],
		tag + " başarımlar", safe_top)
	_c("%s başarım kartı yazıları sığıyor (ad / ilerleme / unvan)" % tag, _cards_fit(overlay.cards()))
	var lip_ok: bool = true
	for ach in overlay.cards():
		lip_ok = lip_ok and _badge_clear_of_lip(ach, ach.badge())
	_c("%s 12 kartta rozet + hedef çipi kartın pişmiş dudağına binmiyor (≥ 22 px)" % tag, lip_ok)
	overlay.close(false)
	profile.open_title_selector()
	await get_tree().create_timer(UiMotion.MODAL_TIME + 0.08).timeout
	var selector: TitleSelector = profile.title_selector()
	await _check_modal(selector.frame(), selector.scroll(), selector.rows()[selector.rows().size() - 1],
		tag + " unvanlar", safe_top)
	var rows_ok: bool = true
	var rows_lip_ok: bool = true
	for row in selector.rows():
		if row.get_global_rect().size.y < 48.0 or not _labels_fit(row):
			rows_ok = false
		rows_lip_ok = rows_lip_ok and _badge_clear_of_lip(row, row.badge())
	_c("%s unvan satırları ≥ 48, adlar kırpılmadı (seçili uzun unvan dahil)" % tag, rows_ok
		and selector.row(&"efsane_birlestirici").is_selected_shown())
	_c("%s 9 unvan satırında rozet + hedef çipi dudağa binmiyor (≥ 22 px)" % tag, rows_lip_ok)
	selector.close(false)
	if safe_top > 0.0:
		return
	# Sonuç şeridi: seviye + başarım birlikte.
	_state(PlayerProgression.total_xp_for_level(4) - 5, 95, 4, 2, 2)
	await _play(3, true, 9, "star3")
	var strip: ResultProgressStrip = _main._result.progress_strip()
	var footer: Control = _main._result.frame().get_meta(&"footer")
	_c("%s sonuç şeridi (seviye + başarım) çerçevede ve ekranda, kırpma yok; CTA'lar ekranda" % tag,
		_strip_inside(strip) and _labels_fit(strip) and get_viewport().get_visible_rect().encloses(footer.get_global_rect()))
	await _leave()


func _check_modal(frame: Control, scroll: ScrollContainer, last: Control, tag: String, safe_top: float = 0.0) -> void:
	var view: Rect2 = get_viewport().get_visible_rect()
	var close: Button = frame.get_meta(&"close_button")
	_c("%s: pencere ekranda, X ≥ 48 ve ekranda" % tag, view.encloses(frame.get_global_rect())
		and close.get_global_rect().size.x >= 48.0 and view.encloses(close.get_global_rect()))
	var ribbon_top: float = frame.get_global_rect().position.y - UiKit.MODAL_RIBBON_OVERHANG
	_c("%s: kurdele (%.0f) ve X (%.0f) üst güvenli payın (%.0f) altında" % [tag, ribbon_top,
		close.get_global_rect().position.y, safe_top], ribbon_top >= safe_top and close.get_global_rect().position.y >= safe_top)
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _settle(2)
	var host: Rect2 = (frame.get_meta(&"body_host") as Control).get_global_rect()
	_c("%s: kaydırma sonunda son öğe gövdede tamamen görünür" % tag, host.grow(1.0).encloses(last.get_global_rect()))
	scroll.scroll_vertical = 0


## Rozet kutusu (hedef çipi dahil) kartın alt kenarından ≥ 22 px yukarıda ve çip kutunun
## içinde — `card_bevel_soft`'un pişmiş dudağı alt kenardan 11–22 px (TASK/044 kuralı).
func _badge_clear_of_lip(card: Control, badge: AchievementBadge) -> bool:
	var box: Rect2 = badge.get_global_rect()
	var pip := badge.find_child("Pip", false, false) as Control
	var pip_inside: bool = pip == null or not pip.visible or box.grow(0.5).encloses(pip.get_global_rect())
	return pip_inside and card.get_global_rect().end.y - box.end.y >= 22.0 - 0.5


func _cards_fit(cards: Array[AchievementCard]) -> bool:
	for card in cards:
		if not _labels_fit(card):
			return false
	return true


# --- Kaynak taraması ------------------------------------------------------------------------------

func _source_scan() -> void:
	print("-- kaynak: yeni UI kayda / ekonomiye / reklama dokunmaz")
	var writes: Array[String] = []
	var ads: Array[String] = []
	var select_calls: int = 0
	for file_name in NEW_UI_FILES:
		var src: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/" + file_name))
		for word in WRITE_CALLS:
			if src.contains(word):
				writes.append("%s:%s" % [file_name, word])
		for word in AD_WORDS:
			if src.contains(word):
				ads.append("%s:%s" % [file_name, word])
		select_calls += src.count("select_title(")
	_c("yeni UI dosyaları kayda / ekonomiye yazmaz %s" % str(writes), writes.is_empty())
	_c("yeni UI dosyalarında reklam / banner API'si yok %s" % str(ads), ads.is_empty())
	var selector_src: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/title_selector.gd"))
	_c("tek yazma yolu: yalnız TitleSelector, tek `select_title(` çağrısı", select_calls == 1
		and selector_src.count("SaveManager.select_title(") == 1)
	var profile_src: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/profile_screen.gd"))
	_c("Profil ekranı yalnız bellek uzlaştırması çağırır (reconcile), kayıt yazmaz",
		profile_src.contains("SaveManager.reconcile_achievements()") and not profile_src.contains("save_game(")
		and not profile_src.contains("select_title("))
	_sections_done += 1


# --- Reklam: pencereler banner'sız -----------------------------------------------------------------

func _ads_no_banner() -> void:
	print("-- reklam: Profil + başarımlar + unvanlar banner'sız (sahte arka uç)")
	_main.queue_free()
	_main = null
	await _settle(2)
	_state(200, 1200, 3, 1, 2)
	SaveManager.data["age_ad_band"] = "ADULT"
	SaveManager.data["next_age_transition_date"] = ""
	SaveManager.save_game()
	var fake := FakeAdBackend.new()
	fake.status = AdBackend.ConsentStatus.NOT_REQUIRED
	_main_script.set("ads_backend_override", fake)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _settle(3)
	_main_script.set("ads_backend_override", null)
	fake.complete_consent_update(true)
	fake.complete_init()
	await _settle(2)
	var ads: MonetizationManager = _main._ads
	if fake.banner_loads > 0:
		fake.complete_banner_load(true)
	await _settle(2)
	_c("ön koşul: Ana Sayfa'da banner gösterildi", ads != null and ads.banner_state() == MonetizationManager.BannerState.SHOWN)
	var profile: CanvasLayer = _main._screens[4]
	# TASK/058: Ana Sayfa avatarı kaldırıldı — Profil girişi kabuğun PROFİL öğesi.
	_main.global_nav().item_button(4).pressed.emit()
	await _settle(2)
	var shows: int = fake.banner_shows.size()
	profile.open_achievements()
	await _settle(2)
	_c("başarımlar penceresi: yüzey NONE, banner gizli, yeni banner gösterimi yok", ads.surface() == MonetizationManager.Surface.NONE
		and ads.banner_state() != MonetizationManager.BannerState.SHOWN and fake.banner_shows.size() == shows)
	profile.achievements_overlay().close(false)
	profile.open_title_selector()
	await _settle(2)
	_c("unvan seçici: yüzey NONE, banner gizli", ads.surface() == MonetizationManager.Surface.NONE
		and ads.banner_state() != MonetizationManager.BannerState.SHOWN and fake.banner_shows.size() == shows)
	var interstitials: int = fake.interstitial_shows.size()
	var rewarded: int = fake.rewarded_shows.size()
	profile.title_selector().row(&"hamur_ustasi").pressed.emit()
	profile.title_selector().close(false)
	_c("unvan seçimi / pencereler geçiş ya da ödüllü reklam açmadı", fake.interstitial_shows.size() == interstitials
		and fake.rewarded_shows.size() == rewarded)
	_main.queue_free()
	_main = null
	await _settle(2)
	UiKit.set_banner_slot(0.0)
	_sections_done += 1


# --- Kayıt durumları -------------------------------------------------------------------------------

## xp · merge · yıldız (10 level'a dağıtılır) · tamamlanan level · sahip olunan Squishy.
## Başarım listesi / unvan sıfırdan (Profil gerçeklerden uzlaştırır).
func _state(xp: int, merges: int, stars: int, completed: int, owned: int) -> void:
	var star_map: Dictionary = {}
	var left: int = stars
	for n in range(1, 11):
		var give: int = mini(left, 3)
		if give > 0:
			star_map[str(n)] = give
		left -= give
	var owned_ids: Array = []
	for skin in SkinLibrary.all():
		if owned_ids.size() < owned:
			owned_ids.append(String(skin.id))
	SaveManager.data["player_xp"] = xp
	SaveManager.data["player_meta_version"] = 1
	SaveManager.data["unlocked_achievements"] = []
	SaveManager.data["selected_title_id"] = "birlestirici"
	SaveManager.data["total_merges"] = merges
	SaveManager.data["merges_since_bonus_chest"] = 0
	SaveManager.data["level_stars"] = star_map
	SaveManager.data["highest_level_unlocked"] = completed + 1
	SaveManager.data["unlocked_skins"] = owned_ids
	SaveManager.data["profile_showcase"] = []
	SaveManager.data["dough"] = 335
	SaveManager.data["powerups"] = {"bomb": 1, "upgrade": 1, "shake": 1, "clear_small": 1}
	SaveManager.data["powerup_starter_granted"] = true
	SaveManager.data["onboarding_completed"] = true
	SaveManager.data["onboarding_completed_day"] = ""
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()


# --- Yardımcılar ------------------------------------------------------------------------------------

func _show_profile() -> void:
	_main._show_tab(0)
	await get_tree().process_frame
	_main._show_tab(4)
	await _settle(2)


func _level(number: int) -> LevelData:
	for level in LevelLibrary.load_levels():
		if level.level_number == number:
			return level
	return null


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


## Main'in geçiş sonrası parmak yatışması geçene kadar GERÇEK süre bekler.
func _wait_settled() -> void:
	var settle_msec: int = int(_main_script.get_script_constant_map().get("TOUCH_SETTLE_MSEC", 300))
	await get_tree().create_timer(float(settle_msec) / 1000.0 + 0.12).timeout
	await get_tree().process_frame


func _screen_center(control: Control) -> Vector2:
	return get_viewport().get_screen_transform() * control.get_global_rect().get_center()


## Gerçek parmak dokunuşu: ScreenTouch (device 0) bas → bir kare → bırak.
func _finger_tap(pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = pos
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await get_tree().process_frame


## Masaüstü fare tıklaması (device 0).
func _mouse_click(pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = pos
		click.global_position = pos
		if pressed:
			click.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(click)
		await get_tree().process_frame


func _resize(view: Vector2i) -> void:
	get_window().size = view
	await get_tree().process_frame
	await get_tree().process_frame


func _bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) if FileAccess.file_exists(SaveManager.SAVE_PATH) \
		else PackedByteArray()


func _read_save_file() -> Dictionary:
	if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	return parsed if parsed is Dictionary else {}


func _write_save(content: Dictionary) -> void:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(content, "\t"))
	file.close()


func _restore_save_file() -> void:
	if not _had_save:
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()


func _strip_comments(code: String) -> String:
	var out: PackedStringArray = []
	for line in code.split("\n"):
		var hash: int = line.find("#")
		out.append(line if hash < 0 else line.substr(0, hash))
	return "\n".join(out)


func _text_width(label: Label, text: String) -> float:
	return label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		label.get_theme_font_size("font_size")).x


func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	for child in root.get_children():
		out.append_array(_all_nodes(child))
	return out
