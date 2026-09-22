extends Node
## UI kabugu davranis testi (M8.5-10). Dev araci — oyun calisirken kullanilmaz.
##
## Ekran goruntusu almaz; ayarlar anahtari, magaza onay diyalogu, Android
## geri tusu, sekme gecisi ve koleksiyon equip'inin gorsel pastan sonra da
## DOGRU CALISTIGINI dogrular. Ekonomi/refill/revive testleri mantigi,
## bu test kabugu kapsiyor.
##
## KAYIT: SaveManager.data bellekte degistiriliyor ama satin alma ve
## ayar anahtari save_game() CAGIRIYOR — owner kaydi yedeklenip byte-identical
## geri yuklenmeli (diger testlerle ayni kural).
##
## Kullanim:
##   godot --headless --audio-driver Dummy --path . res://tools/ui_smoke_test.tscn
##
## Cikista "ObjectDB instances leaked" uyarisi BEKLENEN bir durum: equip ve
## ses anahtari ui_equip / ui_toggle_on SFX'ini caliyor, Dummy surucude playback hic
## bitmiyor ve quit aninda OggPacketSequence acik kaliyor (--verbose ile
## dogrulandi). Bizim kodumuzda sizinti yok.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _fails: int = 0
func _c(name: String, ok: bool) -> void:
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok: _fails += 1

## Kartin altindaki ilk SkinSwatch (onizleme kontrolu).
func _first_swatch(card: Control) -> SkinSwatch:
	return card.find_children("*", "SkinSwatch", true, false)[0] as SkinSwatch


func _ready() -> void:
	# Otomatik GÜNLÜK ÖDÜLLER penceresi (M8.9-02) bu harness'in konusu değil.
	DailyRewards.auto_popup_enabled = false
	await get_tree().process_frame
	var main: Node2D = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	SaveManager.data["dough"] = 1000
	# Sekmeler
	for t in 4:
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
	# Koleksiyon equip (M8.6-06: kart dokunusu SECER, vitrindeki TAK takar)
	main._show_tab(2); await get_tree().process_frame
	var album: CanvasLayer = main._screens[2]
	if not SaveManager.owns_skin(&"common_01"):
		SaveManager.data["unlocked_skins"] = ["common_01"]
		album.refresh()
		await get_tree().process_frame
	var raw_before: String = str(SaveManager.data.get("equipped_skin", ""))
	album.select(&"common_01"); await get_tree().process_frame
	_c("secim kayda YAZMADI", str(SaveManager.data.get("equipped_skin", "")) == raw_before and album.selected_id() == &"common_01")
	album.cta().pressed.emit(); await get_tree().process_frame
	_c("TAK kayda yazildi", SaveManager.equipped_skin_id() == &"common_01")
	var card: CollectionSkinCard = album.card(&"common_01")
	_c("takili kart TAKILI plakasi gorunur", card.is_equipped() and card.equipped_plate().visible)
	_c("vitrin TAKILI, TAK gizli", album.showcase_state_text() == "TAKILI" and not album.cta().visible)
	# Sahip OLUNMAYAN bir skin: kayda gore degisir, ilk kilitliyi bul.
	var locked: StringName = &""
	for skin in SkinLibrary.all():
		if not SaveManager.owns_skin(skin.id):
			locked = skin.id
			break
	if locked != &"":
		album.select(locked); await get_tree().process_frame
		var locked_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
		_c("kilitli skin secili: MAGAZAYA GIT", album.cta_text() == "MAĞAZAYA GİT")
		album.cta().pressed.emit(); await get_tree().process_frame
		_c("kilitli CTA: Magaza'ya gitti, almadi/takmadi/yazmadi", main._active_tab == 3 and shop.visible
			and not SaveManager.owns_skin(locked) and SaveManager.equipped_skin_id() == &"common_01"
			and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == locked_bytes)
		main._show_tab(2); await get_tree().process_frame
	album.select(&""); await get_tree().process_frame
	album.cta().pressed.emit(); await get_tree().process_frame
	_c("varsayilan geri", SaveManager.equipped_skin_id() == &"")
	_c("eski kart plakasi gizlendi", not card.equipped_plate().visible and album.card(&"").is_equipped())
	# --- Skin sistemi (M8.5-13): SkinEntry, vitrin, magaza -> koleksiyon senkronu ---
	var saved_skins: Variant = (SaveManager.data.get("unlocked_skins", []) as Array).duplicate()
	var saved_equipped: Variant = SaveManager.data.get("equipped_skin", "")
	var saved_dough: int = SaveManager.dough()
	# Fresh save: hicbir skin yok, varsayilan takili, 21 kart (varsayilan + 20)
	SaveManager.data["unlocked_skins"] = []
	SaveManager.data["equipped_skin"] = "common_03"  # sahip olunmayan id -> guvenli fallback
	album.refresh(); await get_tree().process_frame
	_c("fresh: takili id varsayilana duser", SaveManager.equipped_skin_id() == &"")
	_c("fresh: varsayilan entry equipped", SkinEntry.default_entry().equipped)
	_c("fresh: owned_count 0", SkinEntry.owned_count() == 0)
	_c("fresh: 21 kart", album.cards().size() == SkinLibrary.total_count() + 1)
	_c("fresh: vitrin Varsayilan", album.showcase_name_text() == SkinEntry.DEFAULT_NAME)
	_c("fresh: vitrin aksiyon gizli (takili)", not album.cta().visible and album.showcase_state_text() == "TAKILI")
	_c("fresh: ilerleme 0/20", album.progress_text() == "0/%d" % SkinLibrary.total_count())
	var locked_entry: SkinEntry = SkinEntry.find(&"rare_02")
	_c("entry: kilitli/fiyat 150", locked_entry.is_locked() and locked_entry.price == 150 and not locked_entry.equipped)
	# Kilitli karta dokun -> vitrin kilitli skin, Magazaya Git
	album.card(&"rare_02").pressed.emit(); await get_tree().process_frame
	_c("kilitli dokunus takmadi", SaveManager.equipped_skin_id() == &"")
	_c("vitrin kilitli skin adi", album.showcase_name_text() == locked_entry.display_name)
	_c("vitrin fiyat metni", album.showcase_state_text() == "150 Hamur")
	_c("vitrin Magazaya Git", album.cta().visible and album.cta_text() == "MAĞAZAYA GİT")
	_c("kilitli kart fiyati vitrinde (kartta fiyat metni yok, M8.6-06)", album.card(&"rare_02").price() == 150)
	_c("kilitli grid karti GERCEK final sanat + kilit (M8.6-06: siluet yok)", album.card(&"rare_02").swatch()._image.texture == SkinLibrary.find(&"rare_02").preview_texture and album.card(&"rare_02").swatch()._lock.visible)
	_c("kilitli vitrin: FINAL onizleme + kilit", album.showcase_swatch()._image.texture == SkinLibrary.find(&"rare_02").preview_texture and album.showcase_swatch()._lock.visible)
	album.cta().pressed.emit(); await get_tree().process_frame
	_c("Magazaya Git -> magaza sekmesi", main._active_tab == 3 and shop.visible)
	# Magazadan skin satin al (koleksiyon gorunmezken) -> tek transaction
	SaveManager.data["dough"] = 500
	shop.refresh(); await get_tree().process_frame
	# M8.6-05: kart tabanli magaza (ShopSkinCard); kilitli kartta SATIN AL gorunur.
	_c("magaza: kilitli kartta Satin Al", shop._cards.has("rare_02") and shop.skin_card(&"rare_02").buy_button().visible)
	_c("magaza: kilitli kart FINAL onizleme + kilit", _first_swatch(shop._cards["rare_02"])._image.texture == SkinLibrary.find(&"rare_02").preview_texture and _first_swatch(shop._cards["rare_02"])._lock.visible)
	_c("magaza: kilitli Legendary gercek sanat", _first_swatch(shop._cards["legendary_01"])._image.texture == SkinLibrary.find(&"legendary_01").preview_texture)
	_c("magaza: kilitli kart fiyat metni", shop.skin_card(&"rare_02").price_text() == "150 Hamur")
	shop._open_confirm(SkinLibrary.find(&"rare_02")); await get_tree().process_frame
	shop._confirm_yes.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_c("skin satin alindi", SaveManager.owns_skin(&"rare_02"))
	_c("skin Hamur -150", SaveManager.dough() == 350)
	_c("satin alinan takili DEGIL", SaveManager.equipped_skin_id() == &"")
	_c("entry: sahip, takili degil", SkinEntry.find(&"rare_02").owned and not SkinEntry.find(&"rare_02").equipped)
	_c("magaza karti SAHIPSIN (TAKILI degil)", shop.skin_card(&"rare_02").state_text() == "SAHİPSİN" and not shop.skin_card(&"rare_02").is_equipped())
	# Koleksiyona don -> yeni skin vitrinde, SAHIPSIN + TAK
	main._show_tab(2); await get_tree().process_frame
	_c("koleksiyon: yeni skin vitrinde", album.showcase_name_text() == locked_entry.display_name)
	_c("koleksiyon: TAK aksiyonu", album.cta().visible and album.cta_text() == "TAK" and album.showcase_state_text() == "SAHİPSİN")
	_c("koleksiyon: ilerleme 1/20", album.progress_text() == "1/%d" % SkinLibrary.total_count())
	album.cta().pressed.emit(); await get_tree().process_frame
	_c("TAK -> kayda yazildi", SaveManager.equipped_skin_id() == &"rare_02")
	_c("TAK -> vitrin TAKILI, aksiyon gizli", not album.cta().visible and album.showcase_state_text() == "TAKILI")
	_c("TAK -> kart TAKILI plakasi", album.card(&"rare_02").is_equipped() and album.card(&"rare_02").equipped_plate().visible)
	_c("equipped_entry dogru", SkinEntry.equipped_entry().id == &"rare_02")
	# Magaza takili durumu gosteriyor
	main._show_tab(3); await get_tree().process_frame
	_c("magaza karti TAKILI", shop.skin_card(&"rare_02").state_text() == "TAKILI" and shop.skin_card(&"rare_02").is_equipped())
	# Gameplay: yeni dogan parca takili skin materyalini tasiyor
	var visual: Node2D = preload("res://scripts/game/dumpling_visual.gd").new()
	add_child(visual); visual.setup(3); await get_tree().process_frame
	var mat: Material = visual._sprite.material
	_c("gameplay: parca skin materyali", mat is ShaderMaterial and (mat as ShaderMaterial).get_shader_parameter("body_color") == SkinLibrary.find(&"rare_02").body_color)
	visual.queue_free()
	# Save/restore: diskten geri oku
	SaveManager.load_game()
	_c("restore: skin sahiplik kalici", SaveManager.owns_skin(&"rare_02"))
	_c("restore: takili skin kalici", SaveManager.equipped_skin_id() == &"rare_02")
	_c("restore: Hamur kalici", SaveManager.dough() == 350)
	# Owner kaydini geri koy (test sonunda dosya zaten yedekten geri yuklenmeli)
	SaveManager.data["unlocked_skins"] = saved_skins
	SaveManager.data["equipped_skin"] = saved_equipped
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
