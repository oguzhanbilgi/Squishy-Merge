extends Node
## Koleksiyon parçası katalogu + önizleme bileşeni + KANONİK gameplay görünümü
## testi (M8.5-14; TASK/044'te yeniden yazıldı). Headless.
##
##   godot --headless --audio-driver Dummy --path . res://tools/skin_test.tscn
##
## Kayda YAZMAZ (SaveManager.data yalnız bellekte değiştirilir ve sonunda geri
## konur). Kontroller: 20 parça, sabit id'ler, rarity dağılımı, adlar, fiyatlar,
## 20 final önizleme yükleniyor; SkinSwatch (sahip / kilitli / reveal /
## varsayılan) materyalsiz; TASK/044: gameplay skinleri EMEKLİ — her parça ×
## her tier için (sahip + vitrinde + eski `equipped_skin` bellekte) parça
## kanonik tier sprite'ıyla, materyalsiz ve aurasız çizilir; ghost da öyle;
## eski SkinVisual / maske / shader dosyaları yok.

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

	# Önizleme bileşeni (koleksiyon + mağaza + profil aynı bileşeni kullanıyor)
	var saved: Dictionary = SaveManager.data.duplicate(true)
	var sw := SkinSwatch.new()
	add_child(sw)
	sw.size = Vector2(90, 90)
	SaveManager.data["unlocked_skins"] = ["common_02"]
	sw.setup(SkinEntry.find(&"common_02"))
	_c("SkinSwatch sahip parça: final önizleme dokusu, materyal yok",
		sw._image.texture == SkinLibrary.find(&"common_02").preview_texture and sw._image.material == null)
	sw.setup(SkinEntry.find(&"rare_01"))
	_c("SkinSwatch kilitli (grid): siluet + kilit", sw._image.texture == SkinSwatch.LOCKED_TEXTURE and sw._lock.visible)
	sw.setup(SkinEntry.find(&"legendary_01"), true)
	_c("SkinSwatch kilitli (mağaza/detay, reveal): final önizleme + kilit",
		sw._image.texture == SkinLibrary.find(&"legendary_01").preview_texture and sw._lock.visible and sw._image.material == null)
	sw.setup(SkinEntry.default_entry())
	_c("SkinSwatch varsayılan: kanonik dumpling, materyal yok",
		sw._image.texture == SkinEntry.PREVIEW_BASE_TEXTURE and sw._image.material == null)

	# TASK/044: gameplay skinleri emekli. En kötü durum: her parça sahip,
	# vitrinin başında VE eski `equipped_skin` anahtarı bellekte — parça yine
	# de tier'ın kanonik sprite'ıyla, materyalsiz ve aurasız çizilir.
	var all_ids: Array = []
	for s in skins:
		all_ids.append(String(s.id))
	SaveManager.data["unlocked_skins"] = all_ids
	var visual: Node2D = VISUAL.new()
	add_child(visual)
	var canonical_ok: bool = true
	for s in skins:
		SaveManager.data["profile_showcase"] = [String(s.id)]
		SaveManager.data["equipped_skin"] = String(s.id)
		for tier in range(1, 9):
			visual.setup(tier)
			var sprite: Sprite2D = visual.sprite()
			if sprite.texture != VISUAL.TEXTURES[tier - 1] or sprite.material != null \
					or sprite.get_child_count() != 0 or sprite.modulate != Color.WHITE \
					or sprite.self_modulate != Color.WHITE:
				canonical_ok = false
	_c("20 parça × 8 tier (sahip + vitrinde + eski equipped_skin): kanonik sprite, materyal/aura/tint YOK",
		canonical_ok)
	var fresh: Node2D = VISUAL.new()
	add_child(fresh)
	fresh.setup(5)
	_c("yeni doğan parça (tier 5) kanonik: doğru doku, materyal yok, çocuk düğüm yok",
		fresh.sprite().texture == VISUAL.TEXTURES[4] and fresh.sprite().material == null
		and fresh.sprite().get_child_count() == 0)
	var ghost: Sprite2D = fresh.make_ghost()
	_c("ghost (merge çekimi) kanonik: aynı doku, materyal yok", ghost.texture == VISUAL.TEXTURES[4] and ghost.material == null)
	ghost.free()
	_c("DumplingVisual skin API'si yok (override_skin / use_equipped_skin)",
		not fresh.has_method("override_skin") and not fresh.has_method("use_equipped_skin"))
	var masks_gone: bool = true
	for tier in range(1, 9):
		if FileAccess.file_exists("res://assets/visual/skins/generated/body_mask_tier%d.png" % tier):
			masks_gone = false
	_c("eski SkinVisual / shader / 8 gövde maskesi dosyası yok",
		not ResourceLoader.exists("res://scripts/game/skin_visual.gd")
		and not ResourceLoader.exists("res://assets/visual/skins/skin_body.gdshader")
		and not ResourceLoader.exists("res://assets/visual/skins/skin_aura.gdshader") and masks_gone)
	_c("SkinData önizleme dokusu hâlâ koleksiyon sanatı (20/20 yüklü)", previews_ok)

	SaveManager.data = saved
	print("=== SONUC: %d kaldi ===" % _fails)
	get_tree().quit()
