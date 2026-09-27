extends Node
## UI kabugu davranis testi (M8.5-10). Dev araci — oyun calisirken kullanilmaz.
##
## Ekran goruntusu almaz; ayarlar anahtari, magaza onay diyalogu, Android
## geri tusu, sekme gecisi ve koleksiyon vitrini (TASK/044: detay + VITRINE
## EKLE; gameplay skinleri emekli) gorsel pastan sonra da DOGRU CALISTIGINI
## dogrular. Ekonomi/refill/revive testleri mantigi,
## bu test kabugu kapsiyor.
##
## KAYIT: SaveManager.data bellekte degistiriliyor ama satin alma ve
## ayar anahtari save_game() CAGIRIYOR — owner kaydi yedeklenip byte-identical
## geri yuklenmeli (diger testlerle ayni kural).
##
## Kullanim:
##   godot --headless --audio-driver Dummy --path . res://tools/ui_smoke_test.tscn
##
## Cikista "ObjectDB instances leaked" uyarisi BEKLENEN bir durum: vitrine ekleme
## ve ses anahtari ui_equip / ui_toggle_on SFX'ini caliyor, Dummy surucude playback hic
## bitmiyor ve quit aninda OggPacketSequence acik kaliyor (--verbose ile
## dogrulandi). Bizim kodumuzda sizinti yok.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _fails: int = 0
func _c(name: String, ok: bool) -> void:
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok: _fails += 1

## Kanonik vitrin (SaveManager.profile_showcase) beklenen id sirasi mi.
func _showcase_is(ids: Array) -> bool:
	var got: Array[StringName] = SaveManager.profile_showcase()
	if got.size() != ids.size():
		return false
	for i in ids.size():
		if got[i] != StringName(ids[i]):
			return false
	return true

## Kartin altindaki ilk SkinSwatch (onizleme kontrolu).
func _first_swatch(card: Control) -> SkinSwatch:
	return card.find_children("*", "SkinSwatch", true, false)[0] as SkinSwatch


func _ready() -> void:
	# Otomatik GÜNLÜK ÖDÜLLER penceresi (M8.9-02) bu harness'in konusu değil.
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	# M8.10: bu harness KABUGU olcuyor — onboarding tamamlanmis olmali,
	# yoksa Main dogrudan ilk acilis tutorial'ina girer. Kayit dosyasini
	# geri koymayan baska bir suite diske `false` birakmis olabilir.
	SaveManager.data["onboarding_completed"] = true
	var main: Node2D = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	SaveManager.data["dough"] = 1000
	# Sekmeler (TASK/044: 4 = Profil)
	for t in 5:
		main._show_tab(t)
		await get_tree().process_frame
		_c("sekme %d gorunur" % t, main._screens[t].visible and main._active_tab == t)
	# Ayarlar
	main._show_tab(0); await get_tree().process_frame
	main.open_settings(); await get_tree().process_frame
	_c("ayarlar acildi", main._settings.visible)
	var toggle: UiToggle = main._settings._sfx_toggle
	_c("toggle acik basliyor", toggle.button_pressed)
	toggle.button_pressed = false
	await get_tree().process_frame
	_c("sfx bus mute", AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")))
	_c("kayitta sfx_enabled=false", SaveManager.data["sfx_enabled"] == false)
	toggle.button_pressed = true
	await get_tree().process_frame
	_c("sfx bus unmute", not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")))
	main._settings._privacy_button.pressed.emit(); await get_tree().process_frame
	_c("gizlilik metni acildi", main._settings._privacy.visible)
	main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("geri tusu ayarlari kapatti", not main._settings.visible)
	# Magaza onayi
	main._show_tab(3); await get_tree().process_frame
	var shop: CanvasLayer = main._screens[3]
	var before_stock: int = SaveManager.powerup_count(PowerUp.Type.BOMB)
	var before_dough: int = SaveManager.dough()
	shop._open_power_confirm(PowerUp.Type.BOMB); await get_tree().process_frame
	_c("onay acildi", shop._confirm.visible)
	_c("onay fiyat metni", shop._confirm_price.text.contains("120 Hamur"))
	_c("geri tusu onayi kapatir", shop.handle_back() and not shop._confirm.visible)
	shop._open_power_confirm(PowerUp.Type.BOMB); await get_tree().process_frame
	shop._confirm_yes.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_c("satin alma stok +1", SaveManager.powerup_count(PowerUp.Type.BOMB) == before_stock + 1)
	_c("satin alma Hamur -120", SaveManager.dough() == before_dough - 120)
	_c("bakiye pill'i guncel", shop.top_bar().pill().get_meta("value_label").text == str(SaveManager.dough()))
	_c("onay kapandi", not shop._confirm.visible)
	# Main geri tusunu 250 ms debounce'lar (Godot 4.6 Android cift iletim).
	await get_tree().create_timer(0.3).timeout
	main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("geri tusu ana sayfaya dondu", main._active_tab == 0)
	# Koleksiyon (TASK/044): kart dokunusu DETAY acar (kayda yazmaz); detaydaki
	# VITRINE EKLE vitrine yazar. "TAK" / "TAKILI" / Varsayilan karti YOK.
	var saved_skins: Variant = (SaveManager.data.get("unlocked_skins", []) as Array).duplicate()
	var saved_showcase: Variant = (SaveManager.data.get("profile_showcase", []) as Array).duplicate()
	var saved_dough: int = SaveManager.dough()
	main._show_tab(2); await get_tree().process_frame
	var album: CanvasLayer = main._screens[2]
	SaveManager.data["unlocked_skins"] = []
	SaveManager.data["profile_showcase"] = []
	album.refresh(); await get_tree().process_frame
	_c("fresh: owned_count 0, 20 kart (Varsayilan karti yok)", SkinEntry.owned_count() == 0
		and album.cards().size() == SkinLibrary.total_count() and album.card(&"") == null)
	_c("fresh: baslik 0/20, VITRIN 0/3", album.header_count_text() == "0/%d" % SkinLibrary.total_count()
		and album.showcase_chip_text() == "VİTRİN 0/3")
	var locked_entry: SkinEntry = SkinEntry.find(&"rare_02")
	_c("entry: kilitli/fiyat 150, vitrinde degil", locked_entry.is_locked() and locked_entry.price == 150 and not locked_entry.showcased)
	var fresh_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	album.card(&"rare_02").pressed.emit(); await get_tree().process_frame
	_c("kilitli dokunus: detay acildi, KILITLI + MAGAZAYA GIT", album.is_detail_open() and album.detail_id() == &"rare_02"
		and album.detail_state_text() == "KİLİTLİ" and album.detail_primary_text() == "MAĞAZAYA GİT"
		and album.detail_secondary_text() == "")
	_c("kilitli detay: ad + fiyat notu", album.detail_name_text() == locked_entry.display_name
		and album.detail_note_text().contains("150 Hamur"))
	_c("kilitli grid karti GERCEK final sanat + kilit (M8.6-06: siluet yok)", album.card(&"rare_02").swatch()._image.texture == SkinLibrary.find(&"rare_02").preview_texture and album.card(&"rare_02").swatch()._lock.visible)
	_c("kilitli detay sahnesi: FINAL sanat + kilit", album.detail_stage().swatch()._image.texture == SkinLibrary.find(&"rare_02").preview_texture and album.detail_stage().swatch()._lock.visible)
	_c("kilitli dokunus kayda YAZMADI", FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == fresh_bytes)
	album.detail_primary().pressed.emit(); await get_tree().process_frame
	var shop2: CanvasLayer = main._screens[3]
	_c("MAGAZAYA GIT -> magaza sekmesi, almadi/yazmadi", main._active_tab == 3 and shop2.visible
		and not SaveManager.owns_skin(&"rare_02") and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == fresh_bytes)
	# Magazadan parca satin al (koleksiyon gorunmezken) -> tek transaction
	SaveManager.data["dough"] = 500
	shop2.refresh(); await get_tree().process_frame
	_c("magaza: kilitli kartta Satin Al", shop2._cards.has("rare_02") and shop2.skin_card(&"rare_02").buy_button().visible)
	_c("magaza: kilitli kart FINAL onizleme + kilit", _first_swatch(shop2._cards["rare_02"])._image.texture == SkinLibrary.find(&"rare_02").preview_texture and _first_swatch(shop2._cards["rare_02"])._lock.visible)
	_c("magaza: kilitli Legendary gercek sanat", _first_swatch(shop2._cards["legendary_01"])._image.texture == SkinLibrary.find(&"legendary_01").preview_texture)
	_c("magaza: kilitli kart fiyat metni", shop2.skin_card(&"rare_02").price_text() == "150 Hamur")
	shop2._open_confirm(SkinLibrary.find(&"rare_02")); await get_tree().process_frame
	shop2._confirm_yes.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_c("parca satin alindi", SaveManager.owns_skin(&"rare_02"))
	_c("parca Hamur -150", SaveManager.dough() == 350)
	_c("satin alinan vitrine OTOMATIK eklenmedi", SaveManager.profile_showcase().is_empty())
	_c("magaza karti SAHIPSIN (TAKILI durumu yok)", shop2.skin_card(&"rare_02").state_text() == "SAHİPSİN"
		and not shop2.skin_card(&"rare_02").has_method("is_equipped"))
	# Koleksiyona don -> sahip kart, detay VITRINE EKLE
	main._show_tab(2); await get_tree().process_frame
	_c("koleksiyon: ilerleme 1/20, kart sahip", album.header_count_text() == "1/%d" % SkinLibrary.total_count()
		and album.card(&"rare_02").is_owned() and not album.card(&"rare_02").is_showcased())
	album.card(&"rare_02").pressed.emit(); await get_tree().process_frame
	_c("sahip detay: SAHIPSIN + VITRINE EKLE", album.detail_state_text() == "SAHİPSİN"
		and album.detail_primary_text() == "VİTRİNE EKLE")
	album.detail_primary().pressed.emit(); await get_tree().process_frame
	_c("VITRINE EKLE -> kayda yazildi", _showcase_is([&"rare_02"]))
	_c("VITRINE EKLE -> detay VITRINDE + VITRINDEN CIKAR", album.detail_state_text() == "VİTRİNDE"
		and album.detail_primary_text() == "VİTRİNDEN ÇIKAR")
	_c("VITRINE EKLE -> kart VITRINDE plakasi, baslik VITRIN 1/3", album.card(&"rare_02").is_showcased()
		and album.card(&"rare_02").showcase_plate().visible and album.showcase_chip_text() == "VİTRİN 1/3")
	_c("avatar = vitrin basi", SkinEntry.avatar_entry().id == &"rare_02")
	# Gameplay: yeni dogan parca KANONIK (vitrin gameplay'i degistirmez)
	var visual: Node2D = preload("res://scripts/game/dumpling_visual.gd").new()
	add_child(visual); visual.setup(3); await get_tree().process_frame
	_c("gameplay: parca kanonik (materyal yok, tier dokusu)", visual.sprite().material == null
		and visual.sprite().texture == visual.TEXTURES[2])
	visual.queue_free()
	# Save/restore: diskten geri oku
	SaveManager.load_game()
	_c("restore: parca sahipligi kalici", SaveManager.owns_skin(&"rare_02"))
	_c("restore: vitrin kalici", _showcase_is([&"rare_02"]))
	_c("restore: Hamur kalici", SaveManager.dough() == 350)
	album.close_detail(false)
	# Owner kaydini geri koy (test sonunda dosya zaten yedekten geri yuklenmeli)
	SaveManager.data["unlocked_skins"] = saved_skins
	SaveManager.data["profile_showcase"] = saved_showcase
	SaveManager.data["dough"] = saved_dough
	SaveManager.save_game()
	main._show_tab(2); await get_tree().process_frame
	main._show_tab(0); await get_tree().process_frame
	# Harita (M8.5-12): patika dugumleri, durumlar, kapi, secim sinyali
	main._show_tab(1)
	await get_tree().process_frame
	var map_screen: CanvasLayer = main._screens[1]
	var saved_high: Variant = SaveManager.data.get("highest_level_unlocked", 1)
	var saved_stars: Variant = (SaveManager.data.get("level_stars", {}) as Dictionary).duplicate()
	SaveManager.data["highest_level_unlocked"] = 4
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3}
	map_screen.refresh()
	await get_tree().process_frame
	_c("harita 10 dugum", map_screen.nodes().size() == 10)
	_c("level 1-3 tamamlandi (acik)", not map_screen.nodes()[0].is_locked() and not map_screen.nodes()[2].is_locked())
	_c("level 4 siradaki (acik, odak/hale)", not map_screen.nodes()[3].is_locked() and map_screen.focus_node() == map_screen.nodes()[3])
	_c("level 5-10 kilitli", map_screen.nodes()[4].is_locked() and map_screen.nodes()[9].is_locked())
	_c("sonsuz kapisi kilitli", map_screen.endless_node().is_locked())
	_c("dugumler grid degil (x farkli)", map_screen.nodes()[0].position.x != map_screen.nodes()[1].position.x)
	var chosen: Array = []
	map_screen.level_chosen.connect(func(l: LevelData) -> void: chosen.append(l.level_number))
	map_screen.nodes()[3].pressed.emit()
	_c("dugum basisi level_chosen(4) yaydi", chosen == [4])
	# level_chosen main._start_level'i tetikledi (kanonik yol): board'u terk et.
	main.abandon_run()
	await get_tree().process_frame
	# Acilis: level 4 bitti -> 5 acildi, animasyon kaydi degistirmez
	SaveManager.data["highest_level_unlocked"] = 5
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3, "4": 3}
	map_screen.refresh()
	await get_tree().process_frame
	_c("acilis sonrasi level 5 siradaki", map_screen.focus_node() == map_screen.nodes()[4])
	SaveManager.data["highest_level_unlocked"] = 11
	map_screen.refresh()
	await get_tree().process_frame
	_c("sonsuz kapisi acik", not map_screen.endless_node().is_locked())
	SaveManager.data["highest_level_unlocked"] = saved_high
	SaveManager.data["level_stars"] = saved_stars
	map_screen.refresh()
	# Home refresh & hint
	main._show_tab(0); await get_tree().process_frame
	_c("home hint dolu", not main._screens[0]._play_hint.text.is_empty())
	main.queue_free()
	await get_tree().process_frame
	print("=== SONUC: %d kaldi ===" % _fails)
	get_tree().quit()
