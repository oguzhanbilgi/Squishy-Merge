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
## ses anahtari star_pat SFX'ini caliyor, Dummy surucude playback hic
## bitmiyor ve quit aninda OggPacketSequence acik kaliyor (--verbose ile
## dogrulandi). Bizim kodumuzda sizinti yok.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _fails: int = 0
func _c(name: String, ok: bool) -> void:
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok: _fails += 1

func _ready() -> void:
	await get_tree().process_frame
	var main: Node2D = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	if main._daily != null: main._daily.visible = false
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
	_c("bakiye cipi guncel", shop._dough_chip.get_meta("value_label").text == "%d Hamur" % SaveManager.dough())
	_c("onay kapandi", not shop._confirm.visible)
	main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_c("geri tusu ana sayfaya dondu", main._active_tab == 0)
	# Koleksiyon equip
	main._show_tab(2); await get_tree().process_frame
	var album: CanvasLayer = main._screens[2]
	if not SaveManager.owns_skin(&"common_01"):
		SaveManager.data["unlocked_skins"] = ["common_01"]
		album.refresh()
		await get_tree().process_frame
	album._try_equip(&"common_01")
	_c("equip kayda yazildi", SaveManager.equipped_skin_id() == &"common_01")
	var card: PanelContainer = album._cards[&"common_01"]
	_c("takili kart rozeti gorunur", card.find_child("State", true, false).modulate.a > 0.9)
	_c("takili kart nane cerceve", (card.get_theme_stylebox("panel") as StyleBoxFlat).border_color == UiPalette.SELECTED)
	# Sahip OLUNMAYAN bir skin: kayda gore degisir, ilk kilitliyi bul.
	var locked: StringName = &""
	for skin in SkinLibrary.all():
		if not SaveManager.owns_skin(skin.id):
			locked = skin.id
			break
	if locked != &"":
		album._try_equip(locked)
		_c("kilitli skin takilmadi", SaveManager.equipped_skin_id() == &"common_01")
	album._try_equip(&"")
	_c("varsayilan geri", SaveManager.equipped_skin_id() == &"")
	_c("eski kart rozeti gizlendi", card.find_child("State", true, false).modulate.a < 0.1)
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
	_c("harita 10 dugum", map_screen._nodes.size() == 10)
	_c("level 1-3 tamamlandi (acik)", not map_screen._nodes[0].disabled and not map_screen._nodes[2].disabled)
	_c("level 4 siradaki (acik, hale bagli)", not map_screen._nodes[3].disabled and map_screen._halo.get_meta("node") == map_screen._nodes[3])
	_c("level 5-10 kilitli", map_screen._nodes[4].disabled and map_screen._nodes[9].disabled)
	_c("sonsuz kapisi kilitli", map_screen._portal.disabled)
	_c("dugumler grid degil (x farkli)", map_screen._nodes[0].position.x != map_screen._nodes[1].position.x)
	var chosen: Array = []
	map_screen.level_chosen.connect(func(l: LevelData) -> void: chosen.append(l.level_number))
	map_screen._nodes[3].pressed.emit()
	_c("dugum basisi level_chosen(4) yaydi", chosen == [4])
	# Acilis: level 4 bitti -> 5 acildi, animasyon kaydi degistirmez
	SaveManager.data["highest_level_unlocked"] = 5
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3, "4": 3}
	map_screen.refresh()
	await get_tree().process_frame
	_c("acilis sonrasi level 5 siradaki", map_screen._halo.get_meta("node") == map_screen._nodes[4])
	SaveManager.data["highest_level_unlocked"] = 11
	map_screen.refresh()
	await get_tree().process_frame
	_c("sonsuz kapisi acik", not map_screen._portal.disabled)
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
