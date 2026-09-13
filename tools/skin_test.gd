extends Node
## Skin katalogu + gameplay render pipeline testi (M8.5-14). Headless.
##
##   godot --headless --audio-driver Dummy --path . res://tools/skin_test.tscn
##
## Kayda YAZMAZ (SaveManager.data yalniz bellekte degistirilir, sonunda
## load_game ile diskten geri okunur). Kontroller: 20 skin, sabit id'ler,
## rarity dagilimi, fiyatlar, 20 final onizleme yukleniyor, her (skin x tier)
## materyali kuruluyor ve paylasiliyor, skin degisince materyal/aura
## temizleniyor, Sade/varsayilan temiz donus, kozmetikler global RNG'yi
## TUKETMIYOR.

const EXPECTED_IDS: Array[String] = [
	"common_01", "common_02", "common_03", "common_04", "common_05", "common_06", "common_07", "common_08",
	"rare_01", "rare_02", "rare_03", "rare_04", "rare_05", "rare_06",
	"epic_01", "epic_02", "epic_03", "epic_04",
	"legendary_01", "legendary_02",
]
const EXPECTED_NAMES: Dictionary = {
	"common_01": "Sade", "common_02": "Susamlı", "common_03": "Kepekli", "common_04": "Havuçlu",
	"common_05": "Yeşil Soğan", "common_06": "Mısır", "common_07": "Peynirli", "common_08": "Sarımsaklı",
	"rare_01": "Karabiber", "rare_02": "Kırmızı Biber", "rare_03": "Mantar", "rare_04": "Ispanak",
	"rare_05": "Deniz Tuzu", "rare_06": "Zencefil",
	"epic_01": "Acı Sos", "epic_02": "Yosun", "epic_03": "Kakao", "epic_04": "Safran",
	"legendary_01": "Altın Hamur", "legendary_02": "Gökkuşağı",
}
const VISUAL: GDScript = preload("res://scripts/game/dumpling_visual.gd")

var _fails: int = 0


func _c(name: String, ok: bool) -> void:
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	await get_tree().process_frame
	var skins: Array[SkinData] = SkinLibrary.all()
	_c("tam 20 skin", skins.size() == 20)
	var ids: Array[String] = []
	for s in skins:
		ids.append(String(s.id))
	_c("id'ler sabit", ids == EXPECTED_IDS)
	var by_rarity: Array[int] = [0, 0, 0, 0]
	var previews_ok: bool = true
	var names_ok: bool = true
	var rarity_ok: bool = true
	var unique_previews: Dictionary = {}
	for s in skins:
		by_rarity[int(s.rarity)] += 1
		if s.preview_texture == null or s.preview_texture.get_size().x < 256:
			previews_ok = false
		else:
			unique_previews[s.preview_texture.resource_path] = true
		if EXPECTED_NAMES.get(String(s.id), "") != s.display_name:
			names_ok = false
		if SkinData.rarity_name(s.rarity).to_lower() != String(s.id).get_slice("_", 0):
			rarity_ok = false
	_c("rarity dagilimi 8/6/4/2", by_rarity == [8, 6, 4, 2])
	_c("rarity id onekiyle uyumlu", rarity_ok)
	_c("adlar katalogla ayni", names_ok)
	_c("20 final onizleme yuklendi (>=256 px)", previews_ok)
	_c("20 onizleme birbirinden farkli dosya", unique_previews.size() == 20)
	_c("fiyatlar 50/150/400/900", Shop.PRICES == [50, 150, 400, 900])
	_c("SkinEntry fiyat rarity'den", SkinEntry.find(&"epic_01").price == 400 and SkinEntry.find(&"legendary_02").price == 900)

	# Onizleme bileseni (koleksiyon + magaza ayni bileseni kullaniyor)
	var saved_skins: Variant = (SaveManager.data.get("unlocked_skins", []) as Array).duplicate()
	var saved_equipped: Variant = SaveManager.data.get("equipped_skin", "")
	var sw := SkinSwatch.new()
	add_child(sw)
	sw.size = Vector2(90, 90)
	SaveManager.data["unlocked_skins"] = ["common_02"]
	sw.setup(SkinEntry.find(&"common_02"))
	_c("SkinSwatch sahip skin: final onizleme dokusu, materyal yok",
		sw._image.texture == SkinLibrary.find(&"common_02").preview_texture and sw._image.material == null)
	sw.setup(SkinEntry.find(&"rare_01"))
	_c("SkinSwatch kilitli (grid): siluet + kilit", sw._image.texture == SkinSwatch.LOCKED_TEXTURE and sw._lock.visible)
	sw.setup(SkinEntry.find(&"legendary_01"), true)
	_c("SkinSwatch kilitli (magaza/vitrin, reveal): final onizleme + kilit",
		sw._image.texture == SkinLibrary.find(&"legendary_01").preview_texture and sw._lock.visible and sw._image.material == null)
	sw.setup(SkinEntry.default_entry())
	_c("SkinSwatch varsayilan: orijinal dumpling, materyal yok",
		sw._image.texture == SkinEntry.PREVIEW_BASE_TEXTURE and sw._image.material == null)

	# Gameplay: her skin x her tier materyali hatasiz kuruluyor
	var visual: Node2D = VISUAL.new()
	add_child(visual)
	var all_ok: bool = true
	var mats: Dictionary = {}
	for s in skins:
		for tier in range(1, 9):
			visual.setup(tier)
			visual.override_skin(s)
			var mat: ShaderMaterial = visual._sprite.material as ShaderMaterial
			if mat == null or mat.shader != SkinVisual.SHADER:
				all_ok = false
			elif mat.get_shader_parameter("body_mask") != SkinVisual.BODY_MASKS[tier - 1]:
				all_ok = false
			elif mat.get_shader_parameter("body_color") != s.body_color:
				all_ok = false
			elif int(mat.get_shader_parameter("pattern_type")) != int(s.pattern):
				all_ok = false
			mats[mat] = true
	_c("20 skin x 8 tier materyal kuruldu, maske tier'a gore", all_ok)
	_c("materyal (skin,tier) basina bir kez (160)", mats.size() == 160)
	visual.setup(4)
	visual.override_skin(SkinLibrary.find(&"common_02"))
	var v2: Node2D = VISUAL.new()
	add_child(v2)
	v2.setup(4)
	v2.override_skin(SkinLibrary.find(&"common_02"))
	_c("ayni skin+tier iki parcada AYNI materyal", v2._sprite.material == visual._sprite.material)
	v2.queue_free()

	# Rarity efektleri
	visual.override_skin(SkinLibrary.find(&"legendary_01"))
	var aura: Node = visual._sprite.get_node_or_null("SkinAura")
	_c("legendary: aura eklendi (arkada)", aura != null and (aura as Sprite2D).show_behind_parent)
	visual.override_skin(SkinLibrary.find(&"epic_01"))
	await get_tree().process_frame
	_c("epic'e gecince aura kalkti", visual._sprite.get_node_or_null("SkinAura") == null)
	var epic: SkinData = SkinLibrary.find(&"epic_01")
	_c("epic: sparkle > 0, aura yok", epic.sparkle > 0.0 and epic.aura_color.a == 0.0)
	var rare: SkinData = SkinLibrary.find(&"rare_02")
	_c("rare: sparkle 0, aura yok", rare.sparkle == 0.0 and rare.aura_color.a == 0.0)
	var common: SkinData = SkinLibrary.find(&"common_04")
	_c("common: sparkle 0, pearl 0, aura yok", common.sparkle == 0.0 and common.pearl == 0.0 and common.aura_color.a == 0.0)
	visual.override_skin(SkinLibrary.find(&"legendary_02"))
	visual.override_skin(null)
	await get_tree().process_frame
	_c("varsayilana donus: materyal ve aura yok",
		visual._sprite.material == null and visual._sprite.get_node_or_null("SkinAura") == null)
	visual.override_skin(SkinLibrary.find(&"common_01"))
	_c("Sade: materyal var, desen NONE, aura yok",
		visual._sprite.material != null and int(SkinLibrary.find(&"common_01").pattern) == 0
		and visual._sprite.get_node_or_null("SkinAura") == null)
	var ghost: Sprite2D = visual.make_ghost()
	_c("ghost skin materyalini tasiyor (merge cekimi)", ghost.material == visual._sprite.material)
	ghost.free()

	# Global RNG determinizmi: kozmetik uygulamak RNG'yi tuketmemeli
	seed(12345)
	var before: int = randi()
	seed(12345)
	for s in skins:
		visual.override_skin(s)
	visual.override_skin(null)
	visual.override_skin(SkinLibrary.find(&"legendary_01"))
	var after: int = randi()
	_c("skin kozmetigi global RNG'yi tuketmiyor", before == after)

	# Takili skin -> yeni dogan parca (kayda yazmadan)
	SaveManager.data["unlocked_skins"] = ["epic_02"]
	SaveManager.data["equipped_skin"] = "epic_02"
	var v3: Node2D = VISUAL.new()
	add_child(v3)
	v3.setup(2)
	_c("yeni parca takili skin profilini aliyor",
		(v3._sprite.material as ShaderMaterial).get_shader_parameter("body_color") == SkinLibrary.find(&"epic_02").body_color)
	SaveManager.data["unlocked_skins"] = saved_skins
	SaveManager.data["equipped_skin"] = saved_equipped
	print("=== SONUC: %d kaldi ===" % _fails)
	get_tree().quit()
