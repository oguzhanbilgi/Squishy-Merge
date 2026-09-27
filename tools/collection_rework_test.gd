extends Node
## TASK/044 — gameplay skin emekliliği + koleksiyon/vitrin kuralları testi.
## Headless; kayıt dosyasını byte-identical geri koyar.
##
##   godot --headless --audio-driver Dummy --path . res://tools/collection_rework_test.tscn
##
## Kontroller:
##   eski kayıt   `equipped_skin` → vitrinin ilk yuvası (yalnız sahip + katalog),
##                anahtar bellekten silinir, sahiplik aynen, yüklemede disk
##                yazması yok, idempotent; sahip olunmayan / bilinmeyen / boş /
##                biçimsiz id → boş vitrin; kayıtta vitrin varsa ona dokunulmaz;
##                biçimsiz vitrin alanı güvenle temizlenir; profil sayaçları
##                uydurulmaz ("güncellemeden beri").
##   gameplay     eski `equipped_skin` + dolu vitrin → parça KANONİK (materyal /
##                aura yok); gameplay kodu vitrini / eski anahtarı OKUMAZ
##                (kaynak taraması); SkinVisual / override_skin API'si yok.
##   vitrin       ekle / çıkar / en fazla 3 / tekrar / sahip olunmayan /
##                bilinmeyen / silinmiş katalog id'si / boş vitrin / değiştir
##                (yuva korunur) / avatar yap; her geçerli yazma TEK save +
##                TEK sinyal, her geçersiz işlem yazmasız ve sinyalsiz.
##   türetilmiş   SkinEntry vitrin bayrakları, avatar, en son keşfedilen, rarity
##                sayaçları.
##   dil/ekonomi  oyuncuya "TAKILI" / takma / "skin" dili yok; sandık metinleri
##                "Yeni Squishy keşfedildi!"; sandık oranları 60/25/12/3, %30
##                parça, fiyatlar 50/150/400/900 DEĞİŞMEDİ.

const VISUAL: GDScript = preload("res://scripts/game/dumpling_visual.gd")
const LEGACY_BASE: Dictionary = {
	"highest_level_unlocked": 4,
	"level_stars": {"1": 2, "2": 3, "3": 3},
	"endless_high_score": 0,
	"dough": 335,
	"total_merges": 120,
	"merges_since_bonus_chest": 45,
	"powerups": {"bomb": 2, "upgrade": 1, "shake": 0, "clear_small": 1},
	"powerup_starter_granted": true,
	"onboarding_completed": true,
	"age_ad_band": "ADULT",
}
## TASK/044'te silinen gameplay skin dosyaları (klasör değil DOSYA denetimi: yerel
## klonda izlenmeyen artık bir dosya klasörü tutsa da test yanlış alarm vermez).
const RETIRED_FILES: Array[String] = [
	"res://scripts/game/skin_visual.gd",
	"res://assets/visual/skins/skin_body.gdshader", "res://assets/visual/skins/skin_aura.gdshader",
	"res://assets/visual/skins/generated/body_mask_tier1.png", "res://assets/visual/skins/generated/body_mask_tier2.png",
	"res://assets/visual/skins/generated/body_mask_tier3.png", "res://assets/visual/skins/generated/body_mask_tier4.png",
	"res://assets/visual/skins/generated/body_mask_tier5.png", "res://assets/visual/skins/generated/body_mask_tier6.png",
	"res://assets/visual/skins/generated/body_mask_tier7.png", "res://assets/visual/skins/generated/body_mask_tier8.png",
	"res://tools/skin_gallery.gd", "res://tools/skin_gallery.tscn", "res://tools/make_skin_masks.py",
	"res://tools/skin_tier_contrast.py",
]
## Oyuncuya görünen metinde bulunmaması gereken eski takma / skin dili.
const BANNED_COPY: Array[String] = ["takılı", "takıldı", "koleksiyon'da tak", "şu an takılı",
	"skinler", "skin ·", "yeni skin", " skin", "skin'"]

var _fails: int = 0
var _checks: int = 0
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _signals: Array = []
var _finished: bool = false
## Her bölüm sonunda +1: betik hatası bir bölümü sessizce yarıda keserse sonuç FAIL.
var _sections_done: int = 0
const SECTIONS: int = 5


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	await get_tree().process_frame
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	SaveManager.showcase_changed.connect(func(ids: Array) -> void: _signals.append(ids.duplicate()))

	_legacy_migration()
	_gameplay_canonical()
	_showcase_rules()
	_derived_entries()
	_copy_and_economy()
	_c("%d/%d bölüm sonuna kadar koştu (betik hatası yok)" % [_sections_done, SECTIONS], _sections_done == SECTIONS)

	print("-- kayıt")
	_restore_save_file()
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
	_restore_save_file()


# --- Eski kayıt göçü -----------------------------------------------------------

func _legacy_migration() -> void:
	print("-- eski kayıt: equipped_skin → vitrin")
	_write_save(_legacy({"unlocked_skins": ["common_01", "rare_02", "epic_01"], "equipped_skin": "rare_02"}))
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	SaveManager.load_game()
	_c("eski takılı sahip parça (rare_02) vitrinin ilk (avatar) yuvasına taşındı", _showcase_is(["rare_02"])
		and SkinEntry.avatar_entry().id == &"rare_02")
	_c("eski equipped_skin anahtarı bellekten silindi", not SaveManager.data.has("equipped_skin"))
	_c("sahiplik aynen korundu (3 parça, sıra aynı)", SaveManager.data["unlocked_skins"] == ["common_01", "rare_02", "epic_01"]
		and SkinEntry.owned_count() == 3)
	_c("yükleme diske YAZMADI (dosya byte-identical)", FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == bytes)
	_c("diğer alanlar dokunulmadı (Hamur 335, merge 120, level 4, onboarding true)", SaveManager.dough() == 335
		and SaveManager.total_merges() == 120 and SaveManager.highest_level_unlocked() == 4
		and SaveManager.onboarding_completed())
	_c("profil sayaçları uydurulmadı: tur 0, tier 0, 'güncellemeden beri' (partial) true",
		SaveManager.total_rounds_played() == 0 and SaveManager.highest_tier_created() == 0
		and SaveManager.profile_counters_partial())
	SaveManager.load_game()
	_c("idempotent: yazılmadan yeniden yükleme aynı sonucu verir", _showcase_is(["rare_02"])
		and not SaveManager.data.has("equipped_skin") and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == bytes)
	SaveManager.save_game()
	var written: Dictionary = _read_save_file()
	_c("doğal kayıt: profile_showcase ['rare_02'] yazıldı, equipped_skin YOK, sayaçlar + partial kalıcı",
		written.get("profile_showcase", []) == ["rare_02"] and not written.has("equipped_skin")
		and written.has("total_rounds_played") and written.get("profile_counters_partial", false) == true)
	SaveManager.load_game()
	_c("kalıcı kayıttan yeniden yükleme: vitrin aynı, partial aynı", _showcase_is(["rare_02"])
		and SaveManager.profile_counters_partial() and not SaveManager.data.has("equipped_skin"))

	_write_save(_legacy({"unlocked_skins": ["common_01"], "equipped_skin": "legendary_02"}))
	SaveManager.load_game()
	_c("eski takılı id SAHİP OLUNMAYAN → vitrin boş, avatar kanonik", _showcase_is([])
		and SkinEntry.avatar_entry().is_default() and not SaveManager.data.has("equipped_skin"))
	_write_save(_legacy({"unlocked_skins": ["zzz_99", "common_01"], "equipped_skin": "zzz_99"}))
	SaveManager.load_game()
	_c("eski takılı id KATALOGDA YOK → vitrin boş; bilinmeyen id sahiplik listesinde KORUNDU, sayaca girmedi",
		_showcase_is([]) and SaveManager.data["unlocked_skins"] == ["zzz_99", "common_01"] and SkinEntry.owned_count() == 1)
	_write_save(_legacy({"unlocked_skins": ["common_01"], "equipped_skin": ""}))
	SaveManager.load_game()
	_c("eski boş equipped_skin (varsayılan görünüm) → vitrin boş, anahtar silindi", _showcase_is([])
		and not SaveManager.data.has("equipped_skin"))
	_write_save(_legacy({"unlocked_skins": ["common_01"], "equipped_skin": 42}))
	SaveManager.load_game()
	_c("biçimsiz equipped_skin (sayı) → vitrin boş, çökme yok", _showcase_is([]) and not SaveManager.data.has("equipped_skin"))
	_write_save(_legacy({"unlocked_skins": ["common_01", "rare_02"], "equipped_skin": "common_01",
		"profile_showcase": ["rare_02"]}))
	SaveManager.load_game()
	_c("kayıtta vitrin zaten varsa göç ona DOKUNMAZ (rare_02 kalır), eski anahtar yine silinir", _showcase_is(["rare_02"])
		and not SaveManager.data.has("equipped_skin"))
	_write_save(_legacy({"unlocked_skins": ["common_01", "rare_02"], "profile_showcase": "rare_02"}))
	SaveManager.load_game()
	_c("biçimsiz vitrin (dizi değil) → güvenle boş", _showcase_is([]) and SaveManager.data["profile_showcase"] == [])
	_write_save(_legacy({"unlocked_skins": ["common_01", "rare_02", "epic_01", "epic_02", "legendary_01"],
		"profile_showcase": [1, "rare_02", "rare_02", "", null, "epic_01", "legendary_01", "epic_02"]}))
	SaveManager.load_game()
	_c("biçimsiz öğeler / tekrar / boş atlandı; en fazla 3 (rare_02, epic_01, legendary_01)",
		_showcase_is(["rare_02", "epic_01", "legendary_01"]))

	print("-- profil sayaçları göçü")
	_write_save(_legacy({"unlocked_skins": [], "total_rounds_played": 7, "highest_tier_created": 6}))
	SaveManager.load_game()
	_c("sayaçlı kayıt: tur 7, tier 6, partial false", SaveManager.total_rounds_played() == 7
		and SaveManager.highest_tier_created() == 6 and not SaveManager.profile_counters_partial())
	_write_save(_legacy({"unlocked_skins": [], "total_rounds_played": "abc", "highest_tier_created": 99}))
	SaveManager.load_game()
	_c("biçimsiz sayaç 0, tier 1..8'e kırpılır (99 → 8)", SaveManager.total_rounds_played() == 0
		and SaveManager.highest_tier_created() == TierConfig.MAX_TIER)
	_write_save({"highest_level_unlocked": 1, "dough": 15, "last_login_date": "2026-01-01"})
	SaveManager.load_game()
	_c("oynanmamış eski kayıt (yalnız giriş Hamuru): partial false (uydurma 'güncellemeden beri' yok)",
		not SaveManager.profile_counters_partial() and SaveManager.total_rounds_played() == 0)
	_delete_save()
	SaveManager.load_game()
	_c("yeni kurulum (dosya yok): vitrin boş, sayaçlar 0, partial false, equipped_skin anahtarı YOK",
		_showcase_is([]) and SaveManager.total_rounds_played() == 0 and not SaveManager.profile_counters_partial()
		and not SaveManager.data.has("equipped_skin") and not SaveManager.DEFAULT_DATA.has("equipped_skin")
		and SaveManager.DEFAULT_DATA.has("profile_showcase"))
	SaveManager.record_round_finished(0)
	SaveManager.record_round_finished(5)
	SaveManager.record_round_finished(3)
	_c("record_round_finished: tur +1 her çağrıda (3), rekor tier yalnız büyürse (5)", SaveManager.total_rounds_played() == 3
		and SaveManager.highest_tier_created() == 5 and int(_read_save_file().get("total_rounds_played", -1)) == 3)
	_sections_done += 1


# --- Gameplay: kanonik görünüm ---------------------------------------------------

func _gameplay_canonical() -> void:
	print("-- gameplay: eski takılı skin SIFIR görsel etki")
	var all_ids: Array = []
	for skin in SkinLibrary.all():
		all_ids.append(String(skin.id))
	_write_save(_legacy({"unlocked_skins": all_ids, "equipped_skin": "legendary_02"}))
	SaveManager.load_game()
	# En kötü durum: göç sonrası bile anahtar bellekte yeniden duruyor olsun.
	SaveManager.data["equipped_skin"] = "legendary_02"
	var visual: Node2D = VISUAL.new()
	add_child(visual)
	var ok: bool = true
	for tier in range(1, 9):
		visual.setup(tier)
		var sprite: Sprite2D = visual.sprite()
		if sprite.texture != VISUAL.TEXTURES[tier - 1] or sprite.material != null or sprite.get_child_count() != 0:
			ok = false
	_c("eski equipped_skin 'legendary_02' + vitrin başı legendary_02: 8 tier kanonik (doku, materyal yok, aura yok)",
		ok and SkinEntry.avatar_entry().id == &"legendary_02")
	visual.queue_free()
	SaveManager.data.erase("equipped_skin")
	var board_scene: PackedScene = load("res://scenes/game/game_board.tscn")
	var board: Node2D = board_scene.instantiate()
	board.setup(load("res://resources/levels/level_01.tres"))
	add_child(board)
	var spawned: Node = board._spawn_dumpling(4, Vector2(360, 600))
	var visuals: int = 0
	var board_ok: bool = true
	for node in _all_nodes(spawned):
		if node.get_script() == VISUAL:
			visuals += 1
			var s: Sprite2D = node.sprite()
			if s.material != null or s.texture != VISUAL.TEXTURES[3]:
				board_ok = false
	_c("gerçek GameBoard'da doğan parça (tier 4) kanonik: materyalsiz, tier dokusu (en az bir görsel bulundu)",
		board_ok and visuals >= 1)
	board.queue_free()
	var code_ok: bool = true
	var runtime: Array[String] = []
	runtime.append_array(_gd_files("res://scripts/game"))
	runtime.append_array(_gd_files("res://scripts/ui"))
	runtime.append("res://scripts/main.gd")
	for path in runtime:
		var code: String = _strip_comments(FileAccess.get_file_as_string(path))
		for word in ["SkinVisual", "override_skin", "use_equipped_skin", "skin_equipped", "equip_skin(",
				"equipped_skin", "equipped_entry", "clear_equipped"]:
			if code.contains(word):
				code_ok = false
				print("    eski skin API'si: ", path, " → ", word)
	_c("çalışma zamanı kodunda eski gameplay skin API'si YOK (SkinVisual / override_skin / equip_skin / equipped_skin…)", code_ok)
	var gameplay_ok: bool = true
	for path in ["res://scripts/game/game_board.gd", "res://scripts/game/dumpling.gd",
			"res://scripts/game/dumpling_visual.gd", "res://scripts/game/power_up_controller.gd",
			"res://scripts/game/gameplay_hud.gd"]:
		if not FileAccess.file_exists(path):
			continue
		var code: String = _strip_comments(FileAccess.get_file_as_string(path))
		for word in ["profile_showcase", "showcase", "avatar_entry", "SkinEntry", "SkinLibrary", "owned_skins"]:
			if code.contains(word):
				gameplay_ok = false
				print("    gameplay koleksiyonu okuyor: ", path, " → ", word)
	_c("gameplay dosyaları vitrini / koleksiyonu OKUMAZ (board, parça, görsel, güç, HUD)", gameplay_ok)
	var save_code: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/autoload/save_manager.gd"))
	_c("equipped_skin yalnız göçte okunur (SaveManager'da tek fonksiyon)", save_code.count("\"equipped_skin\"") == 3
		and save_code.contains("func _migrate_legacy_equip"))
	var gone: bool = true
	for path in RETIRED_FILES:
		if FileAccess.file_exists(path):
			gone = false
			print("    emekli dosya duruyor: ", path)
	_c("eski dosyalar yok (SkinVisual betiği, shader'lar, 8 gövde maskesi, skin_gallery, maske / kontrast betikleri)", gone)
	_sections_done += 1


# --- Vitrin kuralları ------------------------------------------------------------

func _showcase_rules() -> void:
	print("-- vitrin: ekle / çıkar / sınır / değiştir / avatar")
	_write_save(_legacy({"unlocked_skins": ["common_01", "common_02", "rare_02", "epic_01", "legendary_01"]}))
	SaveManager.load_game()
	_c("vitrin sınırı 3, başlangıç boş", SaveManager.SHOWCASE_MAX == 3 and _showcase_is([]))
	_signals.clear()
	var bytes: PackedByteArray = _bytes()
	_c("ekle common_01 → ADDED, tek yazma + tek sinyal", SaveManager.showcase_add(&"common_01") == SaveManager.ShowcaseResult.ADDED
		and _showcase_is(["common_01"]) and _bytes() != bytes and _signals.size() == 1
		and _read_save_file().get("profile_showcase", []) == ["common_01"])
	_expect_no_write("aynı parçayı tekrar ekle → ALREADY (tekrar yok)", func() -> bool:
		return SaveManager.showcase_add(&"common_01") == SaveManager.ShowcaseResult.ALREADY and _showcase_is(["common_01"]))
	_expect_no_write("sahip olunmayan (rare_01) → NOT_OWNED", func() -> bool:
		return SaveManager.showcase_add(&"rare_01") == SaveManager.ShowcaseResult.NOT_OWNED)
	_expect_no_write("bilinmeyen id / boş id → UNKNOWN", func() -> bool:
		return (SaveManager.showcase_add(&"zzz_99") == SaveManager.ShowcaseResult.UNKNOWN
			and SaveManager.showcase_add(&"") == SaveManager.ShowcaseResult.UNKNOWN))
	SaveManager.showcase_add(&"rare_02")
	SaveManager.showcase_add(&"epic_01")
	_c("3 parça: [common_01, rare_02, epic_01], sıra korunur", _showcase_is(["common_01", "rare_02", "epic_01"]))
	_expect_no_write("dolu vitrin → FULL, SESSİZ değiştirme yok", func() -> bool:
		return (SaveManager.showcase_add(&"legendary_01") == SaveManager.ShowcaseResult.FULL
			and _showcase_is(["common_01", "rare_02", "epic_01"])))
	_signals.clear()
	_c("değiştir epic_01 → legendary_01: seçilen yuvaya girer (3. yuva), tek sinyal",
		SaveManager.showcase_replace(&"epic_01", &"legendary_01") and _showcase_is(["common_01", "rare_02", "legendary_01"])
		and _signals.size() == 1)
	_c("değiştir avatar yuvası (common_01 → epic_01): ilk yuvaya girer, avatar olur",
		SaveManager.showcase_replace(&"common_01", &"epic_01") and _showcase_is(["epic_01", "rare_02", "legendary_01"])
		and SkinEntry.avatar_entry().id == &"epic_01")
	_expect_no_write("geçersiz değiştirme (eski vitrinde değil / yeni zaten vitrinde / yeni sahip değil / bilinmeyen)", func() -> bool:
		return (not SaveManager.showcase_replace(&"common_02", &"common_01")
			and not SaveManager.showcase_replace(&"rare_02", &"legendary_01")
			and not SaveManager.showcase_replace(&"rare_02", &"rare_01")
			and not SaveManager.showcase_replace(&"rare_02", &"zzz_99")))
	_c("avatar yap legendary_01 → ilk yuva, diğerlerinin sırası korunur", SaveManager.showcase_make_first(&"legendary_01")
		and _showcase_is(["legendary_01", "epic_01", "rare_02"]) and SkinEntry.avatar_entry().id == &"legendary_01")
	_expect_no_write("avatar yap: zaten ilk / vitrinde değil → yazma yok", func() -> bool:
		return not SaveManager.showcase_make_first(&"legendary_01") and not SaveManager.showcase_make_first(&"common_02"))
	_c("çıkar ilk yuva → sonrakiler öne kayar, yeni avatar epic_01", SaveManager.showcase_remove(&"legendary_01")
		and _showcase_is(["epic_01", "rare_02"]) and SkinEntry.avatar_entry().id == &"epic_01")
	_expect_no_write("vitrinde olmayanı çıkar → yazma yok", func() -> bool:
		return not SaveManager.showcase_remove(&"legendary_01"))
	SaveManager.showcase_remove(&"epic_01")
	SaveManager.showcase_remove(&"rare_02")
	_c("boş vitrin geçerli; avatar kanonik Squishy (varsayılan)", _showcase_is([]) and SkinEntry.avatar_entry().is_default())
	_c("vitrin işlemleri sahipliği / Hamur'u DEĞİŞTİRMEDİ", SaveManager.owned_skins().size() == 5 and SaveManager.dough() == 335)

	print("-- vitrin: silinmiş katalog id'si / sahip olunmayan kayıt")
	SaveManager.data["unlocked_skins"] = ["deleted_99", "rare_02", "common_02"]
	SaveManager.data["profile_showcase"] = ["deleted_99", "rare_02", "rare_01"]
	_c("silinmiş katalog id'si + sahip olunmayan id okumada yok sayılır → [rare_02]", _showcase_is(["rare_02"])
		and SkinEntry.avatar_entry().id == &"rare_02" and not SaveManager.is_showcased(&"deleted_99")
		and SaveManager.showcase_slot(&"rare_02") == 0)
	_c("okuma kayda yazmaz (ham alan aynen duruyor)", SaveManager.data["profile_showcase"] == ["deleted_99", "rare_02", "rare_01"])
	_c("yok sayılan id yer kaplamaz: 2 parça daha eklenebilir", SaveManager.showcase_add(&"common_02") == SaveManager.ShowcaseResult.ADDED
		and _showcase_is(["rare_02", "common_02"]))
	_c("sonraki yazma yalnız doğrulanmış id'leri saklar", SaveManager.data["profile_showcase"] == ["rare_02", "common_02"])
	_sections_done += 1


func _expect_no_write(name: String, action: Callable) -> void:
	var bytes: PackedByteArray = _bytes()
	var before: int = _signals.size()
	var ok: bool = action.call()
	_c(name + " — yazma yok, sinyal yok", ok and _bytes() == bytes and _signals.size() == before)


# --- Türetilmiş durum -----------------------------------------------------------

func _derived_entries() -> void:
	print("-- SkinEntry: vitrin bayrakları / avatar / en son keşfedilen")
	_write_save(_legacy({"unlocked_skins": ["common_01", "zzz_99", "epic_02", "rare_03"],
		"profile_showcase": ["epic_02", "common_01"]}))
	SaveManager.load_game()
	var epic: SkinEntry = SkinEntry.find(&"epic_02")
	var common: SkinEntry = SkinEntry.find(&"common_01")
	var rare: SkinEntry = SkinEntry.find(&"rare_03")
	var locked: SkinEntry = SkinEntry.find(&"legendary_01")
	_c("vitrin bayrakları: epic_02 yuva 0, common_01 yuva 1, rare_03 sahip ama vitrinde değil, kilitli -1",
		epic.showcased and epic.showcase_slot == 0 and common.showcased and common.showcase_slot == 1
		and rare.owned and not rare.showcased and rare.showcase_slot == -1
		and locked.is_locked() and not locked.showcased and locked.showcase_slot == -1)
	_c("SkinEntry'de eski 'equipped' alanı yok", not ("equipped" in epic) and not SkinEntry.new().has_method("equipped_entry"))
	_c("showcase_entries yuva sırasıyla", SkinEntry.showcase_entries().size() == 2
		and SkinEntry.showcase_entries()[0].id == &"epic_02" and SkinEntry.showcase_entries()[1].id == &"common_01")
	_c("en son keşfedilen = listedeki son katalog parçası (rare_03; bilinmeyen id atlanır)", SkinEntry.newest_owned() != null
		and SkinEntry.newest_owned().id == &"rare_03")
	_c("rarity sayaçları: YAYGIN 1, NADİR 1, EPİK 1, EFSANEVİ 0; toplam 3 (bilinmeyen sayılmaz)",
		SkinEntry.owned_count_by_rarity(SkinData.Rarity.COMMON) == 1 and SkinEntry.owned_count_by_rarity(SkinData.Rarity.RARE) == 1
		and SkinEntry.owned_count_by_rarity(SkinData.Rarity.EPIC) == 1 and SkinEntry.owned_count_by_rarity(SkinData.Rarity.LEGENDARY) == 0
		and SkinEntry.owned_count() == 3)
	SaveManager.data["unlocked_skins"] = []
	SaveManager.data["profile_showcase"] = []
	_c("hiç parça yok: en son keşfedilen null, avatar kanonik (tier 3 dumpling sanatı)", SkinEntry.newest_owned() == null
		and SkinEntry.avatar_entry().is_default() and SkinEntry.avatar_entry().art_texture() == SkinEntry.PREVIEW_BASE_TEXTURE)
	_c("albüm girişleri: 20 parça (varsayılan albümde değil)", SkinEntry.all(false).size() == 20
		and not SkinEntry.all(false).any(func(e: SkinEntry) -> bool: return e.is_default()))
	_sections_done += 1


# --- Dil / ekonomi ---------------------------------------------------------------

func _copy_and_economy() -> void:
	print("-- oyuncu dili")
	var hits: Array[String] = []
	var files: Array[String] = []
	files.append_array(_gd_files("res://scripts/ui"))
	files.append_array(_gd_files("res://scripts/game"))
	files.append("res://scripts/main.gd")
	files.append_array(_files("res://scenes/ui", ".tscn"))
	for path in files:
		var code: String = _strip_log_lines(_strip_comments(FileAccess.get_file_as_string(path))) if path.ends_with(".gd") \
			else FileAccess.get_file_as_string(path)
		for literal in _string_literals(code):
			# Eski durum etiketleri tek kelime: kimlik atlamasından ÖNCE yakalanır.
			if literal == "TAK" or literal == "TAKILI" or literal == "SKİN" or literal == "SKİNLER":
				hits.append("%s: \"%s\"" % [path.get_file(), literal])
				continue
			# Yol / düğüm-id adı (yalnız [A-Za-z0-9_]) / hata ayıklama metni (key=value)
			# oyuncuya görünmez.
			if literal.begins_with("res://") or literal.contains("/") or literal.contains("=") \
					or _IDENT.search(literal) != null:
				continue
			var low: String = _tr_lower(literal)
			# İngilizce "SKIN" (noktasız I) Türkçe küçültmede "skın" olur: ASCII
			# küçültmeyle de ara.
			var ascii_low: String = literal.to_lower()
			var flagged: bool = ascii_low.contains("skin")
			for banned in BANNED_COPY:
				if low.contains(banned):
					flagged = true
			if flagged:
				hits.append("%s: \"%s\"" % [path.get_file(), literal])
	for hit in hits:
		print("    eski dil: ", hit)
	_c("oyuncuya görünen metinlerde TAKILI / takma / 'skin' dili yok (UI + oyun + sahneler)", hits.is_empty())
	_c("sandık / günlük ödül: 'Yeni Squishy keşfedildi!' + sonuç kartı 'YENİ SQUISHY' / 'keşfedildi!'",
		DailyRewardsPopup_caption() == "Yeni Squishy keşfedildi!"
		and load("res://scripts/ui/result_reward_card.gd").get_script_constant_map().get("NEW_SKIN_TEXT") == "YENİ SQUISHY"
		and load("res://scripts/ui/result_reward_card.gd").get_script_constant_map().get("SKIN_NOTE_TEXT") == "keşfedildi!")
	var dup := ChestReward.new()
	dup.rarity = SkinData.Rarity.EPIC
	dup.is_duplicate = true
	dup.dough = ChestSystem.RARITY_DOUGH[SkinData.Rarity.EPIC]
	_c("tüm parçalar sendeyken not: 'Epik Squishy'lerin tamamı sende'", dup.note() == "Epik Squishy'lerin tamamı sende")
	print("-- ekonomi (DONDURULMUŞ)")
	_c("sandık rarity oranları 60/25/12/3 (eşikler 60/85/97/100)", ChestSystem.RARITY_THRESHOLDS == [60, 85, 97, 100])
	_c("sandıkta parça şansı %30 (Hamur %70)", ChestSystem.SKIN_REWARD_PERCENT == 30)
	_c("parça fiyatları 50/150/400/900", Shop.PRICES == [50, 150, 400, 900])
	_c("sandık Hamur karşılıkları 10/25/60/150, teselli 5, 75 merge'de bonus sandık",
		ChestSystem.RARITY_DOUGH == [10, 25, 60, 150] and ChestSystem.CONSOLATION_DOUGH == 5
		and ChestSystem.MERGES_PER_BONUS_CHEST == 75)
	var power_prices: Array[int] = []
	for type in PowerUp.all():
		power_prices.append(PowerUpEconomy.price(type))
	_c("güç fiyatları 120/180/100/160 (Bomba/Büyütücü/Sarsıntı/Temizleyici)", power_prices == [120, 180, 100, 160])
	_sections_done += 1


static var _IDENT: RegEx = _ident_regex()


static func _ident_regex() -> RegEx:
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9_%]+$")
	return re


func DailyRewardsPopup_caption() -> String:
	return str(load("res://scripts/ui/daily_rewards_popup.gd").get_script_constant_map().get("SKIN_CAPTION", ""))


# --- Yardımcılar -----------------------------------------------------------------

func _legacy(extra: Dictionary) -> Dictionary:
	var out: Dictionary = LEGACY_BASE.duplicate(true)
	out["last_login_date"] = Time.get_date_string_from_system()
	for key in extra:
		out[key] = extra[key]
	return out


func _write_save(content: Dictionary) -> void:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(content, "\t"))
	file.close()


func _delete_save() -> void:
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))


func _bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) if FileAccess.file_exists(SaveManager.SAVE_PATH) \
		else PackedByteArray()


func _read_save_file() -> Dictionary:
	if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	return parsed if parsed is Dictionary else {}


func _restore_save_file() -> void:
	if not _had_save:
		_delete_save()
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()


func _showcase_is(ids: Array) -> bool:
	var got: Array[StringName] = SaveManager.profile_showcase()
	if got.size() != ids.size():
		return false
	for i in ids.size():
		if got[i] != StringName(ids[i]):
			return false
	return true


func _gd_files(dir: String) -> Array[String]:
	return _files(dir, ".gd")


func _files(dir: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_files(dir.path_join(sub), ext))
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	return out


## Yorumları at (satırdaki ilk '#' sonrası; dize içindeki '#' renk kodu gibi
## değerler bu taramalar için önemsiz).
func _strip_comments(code: String) -> String:
	var out: PackedStringArray = []
	for line in code.split("\n"):
		var hash: int = line.find("#")
		out.append(line if hash < 0 else line.substr(0, hash))
	return "\n".join(out)


## Geliştirici günlük satırları (push_error / push_warning / print…) oyuncuya görünmez.
func _strip_log_lines(code: String) -> String:
	var out: PackedStringArray = []
	for line in code.split("\n"):
		var t: String = line.strip_edges()
		if t.begins_with("push_error(") or t.begins_with("push_warning(") or t.begins_with("print(") \
				or t.begins_with("printerr(") or t.begins_with("print_rich("):
			continue
		out.append(line)
	return "\n".join(out)


func _string_literals(code: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.new()
	re.compile("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
	for m in re.search_all(code):
		out.append(m.get_string(1))
	return out


## Türkçe büyük harf → küçük (Godot to_lower İ/I'yı bilmez).
func _tr_lower(text: String) -> String:
	return text.replace("İ", "i").replace("I", "ı").to_lower()


func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	for child in root.get_children():
		out.append_array(_all_nodes(child))
	return out
