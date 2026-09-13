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

## Bir kartin altindaki tum Label metinlerini birlestirir (durum satiri kontrolu).
func _row_text(card: Control) -> String:
	var out: String = ""
	for label in card.find_children("*", "Label", true, false):
		out += (label as Label).text + "|"
	return out


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
	_c("fresh: 21 kart", album._cards.size() == SkinLibrary.total_count() + 1)
	_c("fresh: vitrin Varsayilan", album._showcase_name.text == SkinEntry.DEFAULT_NAME)
	_c("fresh: vitrin aksiyon gizli (takili)", not album._showcase_action.visible)
	_c("fresh: ilerleme 0/20", album._count.text == "0/%d" % SkinLibrary.total_count())
	var locked_entry: SkinEntry = SkinEntry.find(&"rare_02")
	_c("entry: kilitli/fiyat 150", locked_entry.is_locked() and locked_entry.price == 150 and not locked_entry.equipped)
	# Kilitli karta dokun -> vitrin kilitli skin, Magazaya Git
	album._on_card_tapped(&"rare_02"); await get_tree().process_frame
	_c("kilitli dokunus takmadi", SaveManager.equipped_skin_id() == &"")
	_c("vitrin kilitli skin adi", album._showcase_name.text == locked_entry.display_name)
	_c("vitrin fiyat metni", album._showcase_detail.text.contains("150 Hamur"))
	_c("vitrin Magazaya Git", album._showcase_action.visible and album._showcase_action.text == "Mağazaya Git")
	_c("kilitli kart fiyat bandi", album._cards[&"rare_02"].find_child("Price", true, false) != null)
	album._showcase_action.pressed.emit(); await get_tree().process_frame
	_c("Magazaya Git -> magaza sekmesi", main._active_tab == 3 and shop.visible)
	# Magazadan skin satin al (koleksiyon gorunmezken) -> tek transaction
	SaveManager.data["dough"] = 500
	shop.refresh(); await get_tree().process_frame
	_c("magaza: kilitli satirda Satin Al", shop._cards.has("rare_02"))
	shop._open_confirm(SkinLibrary.find(&"rare_02")); await get_tree().process_frame
	shop._confirm_yes.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_c("skin satin alindi", SaveManager.owns_skin(&"rare_02"))
	_c("skin Hamur -150", SaveManager.dough() == 350)
	_c("satin alinan takili DEGIL", SaveManager.equipped_skin_id() == &"")
	_c("entry: sahip, takili degil", SkinEntry.find(&"rare_02").owned and not SkinEntry.find(&"rare_02").equipped)
	_c("magaza satiri Sahipsin", _row_text(shop._cards["rare_02"]).contains("Sahipsin") and not _row_text(shop._cards["rare_02"]).contains("Takılı"))
	# Koleksiyona don -> yeni skin vitrinde, YENI + Tak
	main._show_tab(2); await get_tree().process_frame
	_c("koleksiyon: yeni skin vitrinde", album._showcase_name.text == locked_entry.display_name)
	_c("koleksiyon: Tak aksiyonu", album._showcase_action.visible and album._showcase_action.text == "Tak")
	_c("koleksiyon: ilerleme 1/20", album._count.text == "1/%d" % SkinLibrary.total_count())
	album._showcase_action.pressed.emit(); await get_tree().process_frame
	_c("Tak -> kayda yazildi", SaveManager.equipped_skin_id() == &"rare_02")
	_c("Tak -> vitrin TAKILI, aksiyon gizli", not album._showcase_action.visible)
	_c("Tak -> kart nane cerceve", (album._cards[&"rare_02"].get_theme_stylebox("panel") as StyleBoxFlat).border_color == UiPalette.SELECTED)
	_c("equipped_entry dogru", SkinEntry.equipped_entry().id == &"rare_02")
	# Magaza takili durumu gosteriyor
	main._show_tab(3); await get_tree().process_frame
	_c("magaza satiri Sahipsin · Takili", _row_text(shop._cards["rare_02"]).contains("Takılı"))
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
