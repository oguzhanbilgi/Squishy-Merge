extends Node
## Round sonu / level tamam / kayıp / ödül reveal (M8.6-09) regresyon testi.
## Headless, kaydı byte olarak geri koyar.
##
##   godot --headless --audio-driver Dummy --path . res://tools/result_ui_test.tscn
##
## Kontroller:
##   YAPI      eski koyu sayfa yok (SB_surface / CardPanel / neon Button /
##             "Level listesi" / banner_new kaynakta yok), production iskelet
##             (`modal_shell`: hero + body + footer, PanelModal krem, X yok),
##             karartma tam ekran STOP ve α ≥ .7, tek çerçeve (ikinci açılış
##             kopya üretmez), kart başına `_process` yok, yasak kaynak yok.
##   KAZANMA   başlık, tepelik + altın kurdele, yıldız sayısı / dokusu /
##             reveal, skor / hedef / Hamur çipleri, HARİTA kahraman +
##             TEKRAR OYNA ikincil, yeni kilit rozeti yalnız bu round açtıysa.
##   KAYIP     "OLMADI", tepelik yok, lavanta kurdele, 0 yıldız (hepsi yumuşak),
##             teşvik satırı ulaşılan tier'a göre, TEKRAR DENE kahraman >
##             HARİTA ikincil, teselli kartı (sandık yok).
##   ÖDÜLLER   Hamur kartı (rarity etiketi Türkçe, "+N HAMUR"), skin kartı
##             (gerçek sanat görünür, ad, YENİ SKİN), geri düşüş ("Epik
##             skinlerin tamamı sende", skin denmez), İngilizce rarity /
##             iç terim taraması, çoklu ödül sırası, 6 ödülde gövde
##             kaydırılır + altlık yerinde + bütün kartlar erişilebilir +
##             karttan sürükleme kaydırır + kart dokunma hedefi değil.
##   KAYIT     sahte ödüllerle açılış / sürükleme / dokunuş kayda yazmaz;
##             gerçek kayıp yolu: teselli +5 TAM BİR KEZ, retry ikinci yazma
##             yapmaz; iki kez açılış kopya kart üretmez.
##   ROTA      kazanma: kahraman → Harita, ikincil → tekrar; kayıp / sonsuz:
##             kahraman → tekrar, ikincil → Harita; Android geri sonuçta yok
##             sayılır (board canlı, mola kapalı); RESULT_DELAY aralığında mola
##             açılmaz; devam teklifi açıkken sonuç yok, Bitir → sonuç.
##   L10/SONSUZ L10 kazanma → "SONSUZ MOD AÇILDI" (yalnız yeni kilit); Sonsuz
##             yeni rekor / rekorsuz başlıkları, yıldız yok, skor kahraman,
##             REKOR çipi, ödülsüz gövde gizli.
##   RESPONSIVE 720×1280 / 720×1560 / 540×960 / 1080×2340 / A36 (safe 61):
##             çerçeve + tepelik ekranda, altlık çerçevede, CTA ekranda.
##   PERFORMANS düğüm sayısı raporu; reveal sonrası sürekli efekt yalnız
##             Legendary'de (≤ 1), diğerlerinde 0.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const LEVEL_04: String = "res://resources/levels/level_04.tres"
const LEVEL_08: String = "res://resources/levels/level_08.tres"
const LEVEL_10: String = "res://resources/levels/level_10.tres"
const ENDLESS: String = "res://resources/levels/endless.tres"
const VIEWS: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(720, 1560), Vector2i(540, 960), Vector2i(1080, 2340)]
const A36_SAFE_TOP: float = 61.0
const RESULT_SOURCES: Array[String] = [
	"res://scripts/ui/round_result.gd", "res://scenes/ui/round_result.tscn",
	"res://scripts/ui/result_reward_card.gd", "res://scripts/ui/result_star_strip.gd",
	"res://scripts/ui/reward_gem.gd", "res://scripts/game/chest_reward.gd",
]
const LEGACY: Array[String] = ["SB_surface", "CardPanel", "Level listesi", "banner_new",
	"SecondaryButton", "UiPalette", "CandyButton", "UiType.apply"]
const FORBIDDEN: Array[String] = ["_visual_source", "layerlab_spike", "layerlab_casual_game", "unitypackage"]
const ENGLISH_RARITY: Array[String] = ["Common", "Rare", "Epic", "Legendary"]
const INTERNAL_TERMS: Array[String] = ["fallback", "duplicate", "Teselli ödülü", "tamamlandı →"]

var _fails: int = 0
var _checks: int = 0
var _saved: Dictionary = {}
var _save_bytes: PackedByteArray = PackedByteArray()
var _had_save: bool = false
var _main: Node2D


func _c(name: String, ok: bool) -> void:
	_checks += 1
	print(("  [OK]   " if ok else "  [FAIL] ") + name)
	if not ok:
		_fails += 1


func _ready() -> void:
	await get_tree().process_frame
	_saved = SaveManager.data.duplicate(true)
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_bytes = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	_apply_showcase()
	get_window().size = Vector2i(720, 1000)
	await get_tree().process_frame
	await _resize(VIEWS[0])

	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_main._daily.visible = false

	_test_sources()
	await _test_structure()
	await _test_win()
	await _test_fail()
	await _test_rewards()
	await _test_overflow()
	await _test_save_safety()
	await _test_real_path()
	await _test_navigation()
	await _test_level10_endless()
	await _test_revive_order()
	await _test_responsive()
	await _test_performance()

	_main.queue_free()
	await get_tree().process_frame
	SaveManager.data = _saved
	_restore_save_file()
	var restored: bool = not _had_save or FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == _save_bytes
	_c("kayıt dosyası test sonunda byte-identical geri kondu", restored)
	print("=== SONUC: %d/%d kontrol, %d kaldi ===" % [_checks - _fails, _checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


# --- Kaynak ------------------------------------------------------------------------

func _test_sources() -> void:
	print("-- kaynak taraması")
	for path in RESULT_SOURCES:
		var text: String = FileAccess.get_file_as_string(path)
		_c("%s okunuyor" % path.get_file(), text.length() > 0)
		for word in FORBIDDEN:
			_c("%s: yasak referans yok (%s)" % [path.get_file(), word], not text.contains(word))
	var result_src: String = FileAccess.get_file_as_string("res://scripts/ui/round_result.gd") \
		+ FileAccess.get_file_as_string("res://scenes/ui/round_result.tscn")
	for word in LEGACY:
		_c("round_result: eski iskelet yok (%s)" % word, not result_src.contains(word))
	for path in ["res://scripts/ui/round_result.gd", "res://scripts/ui/result_reward_card.gd",
			"res://scripts/ui/result_star_strip.gd"]:
		_c("%s: _process yok" % path.get_file(), not FileAccess.get_file_as_string(path).contains("func _process"))
	_c("round_result kayda yazmaz (SaveManager yazma çağrısı yok)",
		not result_src.contains("add_dough") and not result_src.contains("grant_skin")
		and not result_src.contains("complete_level") and not result_src.contains("record_stars")
		and not result_src.contains("save_game") and not result_src.contains("ChestSystem.open"))
	var card_src: String = FileAccess.get_file_as_string("res://scripts/ui/result_reward_card.gd")
	_c("ödül kartı kayda yazmaz", not card_src.contains("SaveManager.add") and not card_src.contains("grant_")
		and not card_src.contains("save_game"))
	_c("ödül kartı dokunma hedefi değil (MOUSE_FILTER_IGNORE)", card_src.contains("mouse_filter = Control.MOUSE_FILTER_IGNORE"))


# --- Yapı ----------------------------------------------------------------------------

func _test_structure() -> void:
	print("-- yapı")
	var result: CanvasLayer = _main._result
	var frame: Control = result.frame()
	_c("sonuç CanvasLayer katman 10 (değişmedi)", result.layer == 10)
	_c("production iskelet: modal_shell meta (hero / body / footer / scroll)",
		frame.has_meta(&"hero") and frame.has_meta(&"body") and frame.has_meta(&"footer") and frame.has_meta(&"scroll"))
	var panel: PanelContainer = frame.get_meta(&"panel")
	_c("gövde PanelModal (krem popup_body) — koyu SB_surface değil", panel.theme_type_variation == &"PanelModal")
	_c("kapat X yok (karar ekranı)", frame.get_meta(&"close_button") == null)
	var dim: ColorRect = result.dim()
	_c("karartma α ≥ .7 (HUD okunmaz, tanınır)", dim.color.a >= 0.7 and dim.color.a <= 0.9)
	_c("karartma tam ekran ve STOP (arkadaki HUD'a dokunuş sızmaz)",
		dim.mouse_filter == Control.MOUSE_FILTER_STOP and dim.anchor_right == 1.0 and dim.anchor_bottom == 1.0)
	await _open(LEVEL_04, true, 1230, [_dough(SkinData.Rarity.RARE)], false, false, 0, true)
	var anchor: Control = frame.get_parent()
	_c("tek çerçeve (kopya ModalShell yok)", _count_named(anchor, "ResultShell") == 1)
	var panel_rect: Rect2 = panel.get_global_rect()
	_c("gövde ekranda opak krem: panel dikdörtgeni HUD durum plakasını örter",
		panel_rect.size.x >= 590.0 and panel_rect.position.y < 640.0 and panel_rect.end.y > 640.0)
	_c("altlık görünür ve çerçevenin içinde", (frame.get_meta(&"footer") as Control).visible
		and frame.get_global_rect().encloses((frame.get_meta(&"footer") as Control).get_global_rect().grow(-1.0)))
	# İkinci açılış: aynı sonuç yeniden tetiklenirse kopya kart / çerçeve yok.
	var again: Array[ChestReward] = [_dough(SkinData.Rarity.RARE)]
	result.show_result(load(LEVEL_04), true, 1230, 3, again, false)
	await _settle(4)
	_c("ikinci show_result: tek çerçeve", _count_named(anchor, "ResultShell") == 1)
	_c("ikinci show_result: kart sayısı ödül sayısına eşit (kopya yok)", result.cards().size() == 1
		and (frame.get_meta(&"body") as Control).get_child_count() == 1)
	await _leave()


# --- Kazanma -------------------------------------------------------------------------

func _test_win() -> void:
	print("-- kazanma")
	var result: CanvasLayer = _main._result
	await _open(LEVEL_04, true, 1230, [_dough(SkinData.Rarity.RARE)], false, false, 6, true)
	_c("görünür", result.visible)
	_c("mod WIN", result.mode() == result.Mode.WIN)
	_c("başlık 'LEVEL 4 TAMAM!'", result.title_text() == "LEVEL 4 TAMAM!")
	_c("tepelik görünür (kutlama)", result.topper().visible)
	_c("altın kontur görünür", result.celebration_rim().visible)
	_c("altın kurdele gövdede, lavanta kurdele gizli", result._hero_ribbon_host.visible and not result._ribbon.visible)
	var strip: ResultStarStrip = result.star_strip()
	_c("yıldız şeridi görünür, 3 kazanılan", strip.visible and strip.earned() == 3)
	_c("üç yıldız reveal sonrası tam ölçekte", strip.all_revealed())
	var stars: Array[TextureRect] = strip.stars()
	_c("kazanılan yıldızlar dolu altın doku", stars[0].texture == ResultStarStrip.STAR_FILLED
		and stars[1].texture == ResultStarStrip.STAR_FILLED and stars[2].texture == ResultStarStrip.STAR_FILLED)
	_c("orta yıldız daha büyük ve yukarıda (yay)", stars[1].size.x > stars[0].size.x
		and stars[1].position.y < stars[0].position.y)
	_c("skor çipi '1 230'", result.score_text() == "1 230")
	_c("hedef çipi 'Dev Dumpling' (ek satır yok)", result.target_text() == TierConfig.tier_name(6)
		and result.target_extra_text() == "")
	_c("Hamur çipi kanonik bakiye (335)", result.dough_text() == "335")
	_c("kahraman CTA 'HARİTA' (kanonik rota), ikincil 'TEKRAR OYNA'",
		result.primary_text() == "HARİTA" and result.secondary_text() == "TEKRAR OYNA")
	_c("kahraman = ButtonCTA, ikincil = ButtonSecondary", result.primary_button().theme_type_variation == &"ButtonCTA"
		and result.secondary_button().theme_type_variation == &"ButtonSecondary")
	_c("yeni kilit rozeti yok (tekrar oynanan level)", result.unlock_badge() == null and result.unlock_text() == "")
	_c("teşvik satırı yok", result.encourage_text() == "")
	_c("Hamur kartı: 'NADİR' + '+25 HAMUR'", result.cards()[0].tag_text() == "NADİR"
		and result.cards()[0].amount_text() == "+25 HAMUR")
	_c("kart açıldı, sandık açık", result.cards()[0].is_opened() and result.cards()[0].gem().is_opened())
	await _leave()

	# L4 eşikleri (TierConfig p50/p85, tier 6): 2★ 1040, 3★ 1190.
	await _open(LEVEL_04, true, 1100, [_dough(SkinData.Rarity.COMMON)], false, false, 6, true)
	_c("2 yıldız: iki dolu + bir yumuşak lavanta", result.star_strip().earned() == 2
		and result.star_strip().stars()[2].texture == ResultStarStrip.STAR_EMPTY_SOFT
		and result.star_strip().stars()[2].self_modulate != Color.WHITE)
	await _leave()
	await _open(LEVEL_04, true, 500, [_dough(SkinData.Rarity.COMMON)], false, false, 6, true)
	_c("1 yıldız", result.star_strip().earned() == 1 and result.star_strip().all_revealed())
	await _leave()

	# Yeni kilit: yalnız Main'in "önce/sonra" bayrağıyla.
	await _open(LEVEL_04, true, 1230, [_dough(SkinData.Rarity.RARE)], false, true, 6, true)
	_c("yeni kilit rozeti 'LEVEL 5 AÇILDI'", result.unlock_text() == "LEVEL 5 AÇILDI")
	_c("rozet hero bölgesinde (kaydırılmaz)", result.unlock_badge() != null
		and (result.frame().get_meta(&"hero") as Control).is_ancestor_of(result.unlock_badge()))
	await _leave()

	# Uzun hedef metni (L8: tier + skor).
	await _open(LEVEL_08, true, 6980, [_dough(SkinData.Rarity.COMMON)], false, false, 7, false)
	_c("L8 hedef çipi tier + '+6 750 skor' ek satırı", result.target_text() == TierConfig.tier_name(7)
		and result.target_extra_text() == "+6 750 skor")
	_c("L8 skor '6 980'", result.score_text() == "6 980")
	var summary: Control = result._summary
	_c("özet çipleri gövde genişliğinde (taşma yok)", summary.get_combined_minimum_size().x <= 528.0)
	await _leave()


# --- Kayıp -----------------------------------------------------------------------------

func _test_fail() -> void:
	print("-- kayıp")
	var result: CanvasLayer = _main._result
	await _open(LEVEL_04, false, 640, [_consolation()], false, false, 5, true)
	_c("mod FAIL, başlık 'OLMADI'", result.mode() == result.Mode.FAIL and result.title_text() == "OLMADI")
	_c("tepelik ve altın kontur yok", not result.topper().visible and not result.celebration_rim().visible)
	_c("lavanta kurdele görünür", result._ribbon.visible and not result._hero_ribbon_host.visible)
	var strip: ResultStarStrip = result.star_strip()
	_c("yıldız şeridi görünür, 0 kazanılan", strip.visible and strip.earned() == 0)
	var all_soft: bool = true
	for star in strip.stars():
		if star.texture != ResultStarStrip.STAR_EMPTY_SOFT or not star.scale.is_equal_approx(Vector2.ONE):
			all_soft = false
	_c("üç yıldız yumuşak lavanta kontur, tam ölçek (sahte kazanım yok)", all_soft)
	_c("teşvik: tier 5 / hedef 6 → 'Hedefe çok yaklaştın!'", result.encourage_text() == "Hedefe çok yaklaştın!")
	_c("kahraman 'TEKRAR DENE', ikincil 'HARİTA'", result.primary_text() == "TEKRAR DENE"
		and result.secondary_text() == "HARİTA")
	_c("tekrar dene kahraman > Harita ikincil (yükseklik + variation)",
		result.primary_button().size.y > result.secondary_button().size.y
		and result.primary_button().theme_type_variation == &"ButtonCTA")
	var card: ResultRewardCard = result.cards()[0]
	_c("teselli kartı: 'TESELLİ' + '+5 HAMUR', sandık yok", card.tag_text() == "TESELLİ"
		and card.amount_text() == "+5 HAMUR" and card.gem() == null)
	_c("skor / hedef çipleri kayıpta da var", result.score_text() == "640"
		and result.target_text() == TierConfig.tier_name(6))
	await _leave()
	await _open(LEVEL_04, false, 120, [_consolation()], false, false, 3, false)
	_c("teşvik: uzak → 'Bir dahaki sefere!'", result.encourage_text() == "Bir dahaki sefere!")
	await _leave()
	await _open(LEVEL_08, false, 4120, [_consolation()], false, false, 7, false)
	_c("teşvik: L8 tier tamam skor eksik → 'Hedef tier tamam, skor az kaldı!'",
		result.encourage_text() == "Hedef tier tamam, skor az kaldı!")
	await _leave()
	await _open(LEVEL_04, false, 120, [_consolation()], false, false, 0, false)
	_c("teşvik: bilinmeyen tier → varsayılan", result.encourage_text() == "Bir dahaki sefere!")
	await _leave()


# --- Ödüller ---------------------------------------------------------------------------

func _test_rewards() -> void:
	print("-- ödüller")
	var result: CanvasLayer = _main._result
	# Skin ödülü.
	var skin_reward: ChestReward = _skin(SkinData.Rarity.RARE, 3)
	await _open(LEVEL_04, true, 1230, [skin_reward], false, false, 6, true)
	var card: ResultRewardCard = result.cards()[0]
	_c("skin kartı: swatch var, açıldıktan sonra görünür (α 1)", card.swatch() != null
		and card.swatch().modulate.a > 0.99 and card.swatch().visible)
	var image_sized: bool = false
	for child in card.swatch().get_children():
		var rect := child as TextureRect
		if rect != null and rect.texture == skin_reward.skin.preview_texture and rect.size.x > 60.0:
			image_sized = true
	_c("skin kartı: GERÇEK final önizleme sanatı ölçülü çizildi", image_sized)
	_c("skin kartı: sandık kalktı (skin kahraman)", card.gem() != null and not card.gem().visible)
	_c("skin kartı: ad + 'YENİ SKİN' rozeti", card.name_text() == skin_reward.skin.display_name
		and card.new_badge() != null and card.new_badge().visible and card.amount_text() == "")
	_c("skin kartı: rarity etiketi Türkçe (NADİR)", card.tag_text() == "NADİR")
	_c("skin kartı satın alma CTA'sı yok", not _tree_has_button(card))
	await _leave()
	# Dört rarity Hamur — etiket Türkçe, İngilizce yok.
	for rarity in [SkinData.Rarity.COMMON, SkinData.Rarity.RARE, SkinData.Rarity.EPIC, SkinData.Rarity.LEGENDARY]:
		await _open(LEVEL_04, true, 1230, [_dough(rarity)], false, false, 6, true)
		var c: ResultRewardCard = result.cards()[0]
		_c("%s Hamur kartı: etiket '%s', '+%d HAMUR'" % [SkinData.rarity_name(rarity),
			SkinData.rarity_display_upper(rarity), ChestSystem.RARITY_DOUGH[int(rarity)]],
			c.tag_text() == SkinData.rarity_display_upper(rarity)
			and c.amount_text() == "+%d HAMUR" % ChestSystem.RARITY_DOUGH[int(rarity)])
		_c("%s: sonuç ağacında İngilizce rarity / iç terim yok" % SkinData.rarity_name(rarity),
			_no_english(result.all_texts()))
		await _leave()
	# Geri düşüş (Epik tamam → 60 Hamur).
	await _open(LEVEL_04, true, 1230, [_dough(SkinData.Rarity.EPIC, true)], false, false, 6, true)
	var fb: ResultRewardCard = result.cards()[0]
	_c("geri düşüş: Hamur kartı olarak ('EPİK' + '+60 HAMUR')", fb.tag_text() == "EPİK" and fb.amount_text() == "+60 HAMUR")
	_c("geri düşüş notu: 'Epik skinlerin tamamı sende'", fb.note_text() == "Epik skinlerin tamamı sende")
	_c("geri düşüş: skin verildi denmez (swatch / YENİ SKİN yok)", fb.swatch() == null and fb.new_badge() == null)
	_c("geri düşüş: iç terim yok", _no_english(result.all_texts()))
	await _leave()
	# Çoklu ödül: sıra + hepsi görünür, kaydırma yok (3 kart 1280'e sığar).
	var three: Array[ChestReward] = [_dough(SkinData.Rarity.RARE), _skin(SkinData.Rarity.EPIC, 1), _dough(SkinData.Rarity.COMMON)]
	await _open(LEVEL_04, true, 1230, three, false, false, 6, true)
	_c("üç kart, ödül sırasıyla", result.cards().size() == 3 and result.cards()[0].reward() == three[0]
		and result.cards()[1].reward() == three[1] and result.cards()[2].reward() == three[2])
	_c("üç kart 720×1280'de kaydırmasız sığar", not bool(result.frame().get_meta(&"body_scrolls", false)))
	var host: Control = result.frame().get_meta(&"body_host")
	var all_inside: bool = true
	for c in result.cards():
		if not host.get_global_rect().grow(1.0).encloses(c.get_global_rect()):
			all_inside = false
	_c("üç kart gövde yuvasının içinde", all_inside)
	_c("üç kart açıldı, hepsi α 1", result.cards()[0].modulate.a > 0.99 and result.cards()[2].modulate.a > 0.99
		and result.cards()[2].is_opened())
	_c("kartlar dokunma hedefi değil", result.cards()[0].mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_c("Hamur çipi reveal sonunda kanonik bakiye", result.dough_text() == GameplayHud._thousands(SaveManager.dough()))
	await _leave()


# --- Taşma / kaydırma -----------------------------------------------------------------

func _test_overflow() -> void:
	print("-- 6 ödül: taşma regresyonu")
	var result: CanvasLayer = _main._result
	var six: Array[ChestReward] = [_dough(SkinData.Rarity.COMMON), _skin(SkinData.Rarity.COMMON, 4),
		_dough(SkinData.Rarity.RARE), _dough(SkinData.Rarity.EPIC), _skin(SkinData.Rarity.RARE, 5),
		_dough(SkinData.Rarity.LEGENDARY)]
	var before: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	await _open(LEVEL_04, true, 1230, six, false, false, 6, true)
	var frame: Control = result.frame()
	var view: Rect2 = get_viewport().get_visible_rect()
	var scroll: ScrollContainer = frame.get_meta(&"scroll")
	var host: Control = frame.get_meta(&"body_host")
	var footer: Control = frame.get_meta(&"footer")
	_c("6 kart: gövde kaydırılıyor", bool(frame.get_meta(&"body_scrolls", false)))
	_c("6 kart: çerçeve + tepelik ekranda", view.encloses(frame.get_global_rect())
		and result.topper().get_global_rect().position.y >= 0.0)
	_c("6 kart: altlık çerçevede ve ekranda", frame.get_global_rect().encloses(footer.get_global_rect().grow(-1.0))
		and view.encloses(footer.get_global_rect()))
	_c("6 kart: kahraman CTA ekranda ve alt kenardan ≥ 36 px", view.encloses(result.primary_button().get_global_rect())
		and result.secondary_button().get_global_rect().end.y <= view.size.y - 36.0)
	_c("6 kart: reveal gövdeyi son karta kaydırdı", scroll.scroll_vertical > 0)
	var last: Control = result.cards()[5]
	_c("6 kart: son kart kaydırma sonunda gövde yuvasında", host.get_global_rect().grow(1.0).encloses(last.get_global_rect()))
	scroll.scroll_vertical = 0
	await _settle(2)
	_c("6 kart: başa kaydırınca ilk kart yuvada", host.get_global_rect().grow(1.0).encloses(result.cards()[0].get_global_rect()))
	var overlap: bool = false
	for i in 5:
		if result.cards()[i].get_global_rect().intersects(result.cards()[i + 1].get_global_rect()):
			overlap = true
	_c("6 kart: kartlar birbirine binmiyor", not overlap)
	_c("6 kart: altlık kaydırılan gövdenin içinde DEĞİL", not scroll.is_ancestor_of(footer))
	# Karttan başlayan sürükleme kaydırır (kart IGNORE → olay ScrollContainer'a).
	var drag_from: Vector2 = result.cards()[1].get_global_rect().get_center()
	var pos: Vector2 = drag_from
	_pointer(pos, true)
	await get_tree().process_frame
	for i in 8:
		pos.y -= 30.0
		_pointer_motion(pos, Vector2(0.0, -30.0))
		await get_tree().process_frame
	var during: int = scroll.scroll_vertical
	_pointer(pos, false)
	await _settle(4)
	_c("karttan sürükleme gövdeyi kaydırdı (> 0 px)", during > 0)
	_c("sürükleme kayda yazmadı", FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == before)
	_c("sürükleme sonuç kararı üretmedi (sonuç hâlâ açık, board canlı)", result.visible
		and _main._board != null and is_instance_valid(_main._board))
	# Dokunuş kartın üstünde: eylem yok.
	var tap: Vector2 = result.cards()[2].get_global_rect().get_center()
	_pointer(tap, true)
	await get_tree().process_frame
	_pointer(tap, false)
	await _settle(4)
	_c("karta dokunuş: eylem / yazma yok", result.visible and FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == before)
	await _leave()

	# 5 ödül (Sonsuz gerçekçi en çok): kaydırma var mı bilgi amaçlı; altlık ekranda.
	SaveManager.data["endless_high_score"] = 12480
	var five: Array[ChestReward] = [_dough(SkinData.Rarity.COMMON), _skin(SkinData.Rarity.RARE, 4),
		_dough(SkinData.Rarity.RARE), _dough(SkinData.Rarity.EPIC), _dough(SkinData.Rarity.LEGENDARY)]
	await _open(ENDLESS, false, 12480, five, true, false, 8, true)
	print("    bilgi: Sonsuz 5 ödül 720×1280 body_scrolls=%s" % str(frame.get_meta(&"body_scrolls", false)))
	_c("Sonsuz 5 ödül: altlık + CTA ekranda", view.encloses(footer.get_global_rect())
		and view.encloses(result.primary_button().get_global_rect()))
	_c("Sonsuz 5 ödül: bütün kartlar erişilebilir (son kart yuvada)",
		host.get_global_rect().grow(1.0).encloses(result.cards()[4].get_global_rect()))
	await _leave()
	SaveManager.data["endless_high_score"] = 0


# --- Kayıt güvenliği ---------------------------------------------------------------------

func _test_save_safety() -> void:
	print("-- kayıt güvenliği (sunum yazmaz)")
	var result: CanvasLayer = _main._result
	var before: PackedByteArray = FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH)
	var dough_before: int = SaveManager.dough()
	var skins_before: int = SaveManager.owned_skins().size()
	var rewards: Array[ChestReward] = [_skin(SkinData.Rarity.LEGENDARY, 1), _dough(SkinData.Rarity.EPIC), _consolation()]
	await _open(LEVEL_04, true, 1230, rewards, false, true, 6, true)
	_c("sahte ödüllerle açılış: dosya byte-identical", FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == before)
	_c("sahte ödüllerle açılış: Hamur / skin sayısı değişmedi", SaveManager.dough() == dough_before
		and SaveManager.owned_skins().size() == skins_before)
	result.show_result(load(LEVEL_04), true, 1230, 3, rewards, false, true, 6)
	await _wait_reveal(result)
	_c("aynı sonucu ikinci kez açmak: yazma yok, kopya kart yok",
		FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == before and result.cards().size() == 3)
	_c("bakiye çipi kanonik bakiyeyi gösterir (sayarak varır)", result.dough_text() == GameplayHud._thousands(SaveManager.dough()))
	await _leave()
	_c("kapanış: yazma yok", FileAccess.get_file_as_bytes(SaveManager.SAVE_PATH) == before)


## Gerçek kayıp yolu: main bağlı, hak yok → round_finished(false) → teselli
## +5 TAM BİR KEZ → 0.8 s sonra sonuç; retry ikinci yazma yapmaz.
func _test_real_path() -> void:
	print("-- gerçek kayıp yolu (kanonik yazım tam bir kez)")
	var result: CanvasLayer = _main._result
	_main._start_level(load(LEVEL_04))
	await get_tree().process_frame
	await get_tree().process_frame
	_main._board._dismiss_tutorial()
	var board: Node2D = _main._board
	board._revives_used = board.MAX_REVIVES_PER_ROUND
	GameState.reset_run()
	GameState.add_score(410)
	var dough_before: int = SaveManager.dough()
	var merges_before: int = int(SaveManager.data.get("total_merges", 0))
	board._trigger_overflow_fail()
	await get_tree().process_frame
	_c("gerçek kayıp: board bitti, teklif yok", board.is_finished() and not _main._revive.visible)
	_c("gerçek kayıp: RESULT_DELAY içinde sonuç henüz yok", not result.visible)
	# RESULT_DELAY aralığında Android geri / mola: mola AÇILMAZ.
	_main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	_c("RESULT_DELAY aralığında Android geri mola açmadı", not _main._pause.visible)
	_main.open_pause_menu()
	_c("RESULT_DELAY aralığında open_pause_menu mola açmadı", not _main._pause.visible)
	var waited: int = 0
	while not result.visible and waited < 180:
		await get_tree().process_frame
		waited += 1
	_c("gerçek kayıp: sonuç ekranı açıldı", result.visible)
	_c("gerçek kayıp: teselli +5 Hamur TAM BİR KEZ", SaveManager.dough() == dough_before + ChestSystem.CONSOLATION_DOUGH)
	_c("gerçek kayıp: merge sayacı değişmedi (0 merge)", int(SaveManager.data.get("total_merges", 0)) == merges_before)
	await _wait_reveal(result)
	_c("gerçek kayıp: teselli kartı + skor '410'", result.cards().size() == 1
		and result.cards()[0].reward().is_consolation and result.score_text() == "410")
	_c("gerçek kayıp: Hamur çipi = kayıt", result.dough_text() == GameplayHud._thousands(SaveManager.dough()))
	var dough_after_open: int = SaveManager.dough()
	# Android geri sonuçta yok sayılır.
	_main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(2)
	_c("Android geri: sonuç açık kalır, mola açılmaz, board canlı", result.visible and not _main._pause.visible
		and _main._board != null and is_instance_valid(_main._board))
	# TEKRAR DENE (gerçek işaretçi) → level yeniden başlar, yazma yok.
	await _tap(result.primary_button())
	_c("TEKRAR DENE: sonuç kapandı, yeni board", not result.visible and _main._board != null
		and is_instance_valid(_main._board) and _main._board != board)
	_c("TEKRAR DENE: ikinci ödül yazımı yok", SaveManager.dough() == dough_after_open)
	_c("TEKRAR DENE: aynı level", _main._current_level.level_number == 4)
	_main.abandon_run()
	await _settle(2)
	_c("terk sonrası sonuç kapalı, harita", not result.visible and _main._active_tab == 1)
	_main._show_tab(0)
	await _settle(2)


# --- Rotalar ---------------------------------------------------------------------------

func _test_navigation() -> void:
	print("-- rotalar")
	var result: CanvasLayer = _main._result
	# Kazanma: kahraman HARİTA → çıkış (harita), ikincil → tekrar.
	await _open(LEVEL_04, true, 1230, [_dough(SkinData.Rarity.RARE)], false, false, 6, false)
	_c("kazanma kahraman eylemi = exit", result.primary_action() == "exit")
	await _tap(result.primary_button())
	_c("HARİTA: sonuç kapalı, board yok, harita sekmesi", not result.visible and _main._board == null and _main._active_tab == 1)
	_main._show_tab(0)
	await _settle(2)
	await _open(LEVEL_04, true, 1230, [_dough(SkinData.Rarity.RARE)], false, false, 6, false)
	var old_board: Node2D = _main._board
	await _tap(result.secondary_button())
	_c("TEKRAR OYNA: aynı level yeniden başladı", not result.visible and _main._board != null
		and _main._board != old_board and _main._current_level.level_number == 4)
	await _leave()
	# Kayıp: ikincil HARİTA → çıkış.
	await _open(LEVEL_04, false, 640, [_consolation()], false, false, 5, false)
	_c("kayıp kahraman eylemi = retry", result.primary_action() == "retry")
	await _tap(result.secondary_button())
	_c("kayıp HARİTA: harita, board yok", not result.visible and _main._board == null and _main._active_tab == 1)
	_main._show_tab(0)
	await _settle(2)
	# Sonsuz: kahraman TEKRAR OYNA → sonsuz yeniden; ikincil → harita.
	await _open(ENDLESS, false, 7410, [], false, false, 8, false)
	var endless_board: Node2D = _main._board
	await _tap(result.primary_button())
	_c("Sonsuz TEKRAR OYNA: sonsuz yeniden başladı", not result.visible and _main._board != null
		and _main._board != endless_board and _main._current_level.is_endless)
	await _leave()
	await _open(ENDLESS, false, 7410, [], false, false, 8, false)
	await _tap(result.secondary_button())
	_c("Sonsuz HARİTA: harita", not result.visible and _main._active_tab == 1)
	_main._show_tab(0)
	await _settle(2)
	# Sonuç açıkken Android geri (sahte ödül, board canlı).
	await _open(LEVEL_04, true, 1230, [_dough(SkinData.Rarity.RARE)], false, false, 6, false)
	_main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle(2)
	_c("Android geri sonuçta yok sayılır (kazanma)", result.visible and not _main._pause.visible
		and _main._board != null and is_instance_valid(_main._board))
	# Karartmaya dokunuş: hiçbir şey olmaz (karar ekranı).
	_pointer(Vector2(40.0, 40.0), true)
	await get_tree().process_frame
	_pointer(Vector2(40.0, 40.0), false)
	await _settle(2)
	_c("karartma dokunuşu sonucu kapatmaz, HUD'a sızmaz", result.visible and not _main._pause.visible
		and not _main._settings.visible)
	await _leave()


# --- Level 10 / Sonsuz ------------------------------------------------------------------

func _test_level10_endless() -> void:
	print("-- Level 10 / Sonsuz")
	var result: CanvasLayer = _main._result
	await _open(LEVEL_10, true, 5210, [_dough(SkinData.Rarity.RARE)], false, true, 8, true)
	_c("L10 kazanma başlığı 'LEVEL 10 TAMAM!'", result.title_text() == "LEVEL 10 TAMAM!")
	_c("L10 yeni kilit → 'SONSUZ MOD AÇILDI' (Level 11 yok)", result.unlock_text() == "SONSUZ MOD AÇILDI")
	_c("L10 kahraman HARİTA (sonraki level rotası icat edilmedi)", result.primary_text() == "HARİTA")
	_c("L10 3 yıldız (tamamlamak her zaman 3★)", result.star_strip().earned() == 3)
	_c("L10 hedef çipi 'Dumpling Kralı' + '+5 000 skor'", result.target_text() == TierConfig.tier_name(8)
		and result.target_extra_text() == "+5 000 skor")
	await _leave()
	await _open(LEVEL_10, true, 5210, [_dough(SkinData.Rarity.RARE)], false, false, 8, false)
	_c("L10 tekrar oynanışta rozet yok", result.unlock_text() == "")
	await _leave()
	# Sonsuz yeni rekor.
	SaveManager.data["endless_high_score"] = 9860
	await _open(ENDLESS, false, 9860, [], true, false, 8, true)
	_c("Sonsuz rekor başlığı 'YENİ REKOR!' (level dili yok)", result.title_text() == "YENİ REKOR!"
		and result.mode() == result.Mode.ENDLESS)
	_c("Sonsuz: yıldız şeridi gizli", not result.star_strip().visible)
	_c("Sonsuz: skor kahraman çipi '9 860'", result._endless_host.visible and result.endless_score_text() == "9 860")
	_c("Sonsuz: REKOR çipi kayıttan '9 860', hedef çipi gizli", result._record_chip.visible
		and result.record_text() == "9 860" and not result._target_chip.visible)
	_c("Sonsuz rekor: tepelik + altın (kutlama)", result.topper().visible and result.celebration_rim().visible)
	_c("Sonsuz: ödül yok → gövde gizli", not (result.frame().get_meta(&"body_host") as Control).visible)
	_c("Sonsuz: TEKRAR OYNA kahraman, HARİTA ikincil", result.primary_text() == "TEKRAR OYNA"
		and result.secondary_text() == "HARİTA")
	await _leave()
	SaveManager.data["endless_high_score"] = 12480
	await _open(ENDLESS, false, 7410, [_dough(SkinData.Rarity.COMMON)], false, false, 8, true)
	_c("Sonsuz rekorsuz başlığı 'TUR BİTTİ', tepelik yok", result.title_text() == "TUR BİTTİ"
		and not result.topper().visible)
	_c("Sonsuz rekorsuz: REKOR '12 480', skor '7 410'", result.record_text() == "12 480"
		and result.endless_score_text() == "7 410")
	_c("Sonsuz bonus sandık kartı var", result.cards().size() == 1 and result.cards()[0].tag_text() == "YAYGIN")
	_c("Sonsuz: İngilizce rarity yok", _no_english(result.all_texts()))
	await _leave()
	SaveManager.data["endless_high_score"] = 0


# --- Devam / sonuç sırası -----------------------------------------------------------------

func _test_revive_order() -> void:
	print("-- devam teklifi / sonuç sırası")
	var result: CanvasLayer = _main._result
	_main._start_level(load(LEVEL_04))
	await get_tree().process_frame
	await get_tree().process_frame
	_main._board._dismiss_tutorial()
	var board: Node2D = _main._board
	GameState.reset_run()
	GameState.add_score(500)
	var dough_before: int = SaveManager.dough()
	board._trigger_overflow_fail()
	await _settle(4)
	_c("hak varken taşma: devam teklifi açık, sonuç KAPALI", _main._revive.visible and not result.visible)
	await _settle(60)
	_c("teklif açıkken 1 s sonra da sonuç yok, ödül yazılmadı", not result.visible and SaveManager.dough() == dough_before)
	_main.decline_revive()
	var waited: int = 0
	while not result.visible and waited < 180:
		await get_tree().process_frame
		waited += 1
	_c("Bitir → sonuç açıldı, teklif kapalı (altında görünmez)", result.visible and not _main._revive.visible)
	_c("Bitir → teselli tam bir kez", SaveManager.dough() == dough_before + ChestSystem.CONSOLATION_DOUGH)
	_c("Bitir → sonuç KAYIP modunda", result.mode() == result.Mode.FAIL)
	await _wait_reveal(result)
	_main.abandon_run()
	await _settle(2)
	_main._show_tab(0)
	await _settle(2)


# --- Responsive ----------------------------------------------------------------------------

func _test_responsive() -> void:
	print("-- responsive")
	var result: CanvasLayer = _main._result
	var three: Array[ChestReward] = [_dough(SkinData.Rarity.RARE), _skin(SkinData.Rarity.EPIC, 1), _dough(SkinData.Rarity.LEGENDARY)]
	for view_size in VIEWS:
		await _resize(view_size)
		await _open(LEVEL_04, true, 1230, three, false, true, 6, false)
		await _settle(6)
		_check_fit("%dx%d kazanma 3 ödül" % [view_size.x, view_size.y], result, 0.0)
		await _leave()
		await _open(LEVEL_04, false, 640, [_dough(SkinData.Rarity.RARE), _consolation()], false, false, 5, false)
		await _settle(6)
		_check_fit("%dx%d kayıp 2 ödül" % [view_size.x, view_size.y], result, 0.0)
		await _leave()
	# A36 simülasyonu: 720×1560 + üst güvenli pay 61 (tepelik bandın altında).
	await _resize(Vector2i(720, 1560))
	for screen in _main._screens:
		if screen.has_method("_layout_with_safe_top"):
			screen._layout_with_safe_top(A36_SAFE_TOP)
	await _open(LEVEL_04, true, 1230, three, false, true, 6, false)
	_main._board._apply_layout(get_viewport().get_visible_rect().size, A36_SAFE_TOP)
	await _settle(6)
	_check_fit("A36 (720x1560 safe 61) kazanma 3 ödül", result, A36_SAFE_TOP)
	await _leave()
	await _resize(VIEWS[0])


func _check_fit(label: String, result: CanvasLayer, safe_top: float) -> void:
	var view: Rect2 = get_viewport().get_visible_rect()
	var frame: Control = result.frame()
	var frame_rect: Rect2 = frame.get_global_rect()
	var top: float = frame_rect.position.y
	if result.topper().visible:
		top = minf(top, result.topper().get_global_rect().position.y)
	elif result._ribbon.visible:
		top = minf(top, result._ribbon.get_global_rect().position.y)
	_c("%s: çerçeve ve tepelik ekranda, üst ≥ güvenli pay" % label, view.encloses(frame_rect)
		and top >= safe_top and frame_rect.end.y <= view.size.y - 24.0)
	_c("%s: altlık çerçevede, CTA'lar ekranda" % label,
		frame_rect.encloses((frame.get_meta(&"footer") as Control).get_global_rect().grow(-1.0))
		and view.encloses(result.primary_button().get_global_rect())
		and view.encloses(result.secondary_button().get_global_rect()))
	_c("%s: yıldız şeridi hero'da (kaydırılmaz) ve çerçevede" % label,
		frame_rect.encloses(result.star_strip().get_global_rect().grow(-2.0))
		and (frame.get_meta(&"hero") as Control).is_ancestor_of(result.star_strip()))
	_c("%s: başlık çerçeveye sığıyor (Türkçe metin kırpılmadı)" % label, _title_fits(result))


func _title_fits(result: CanvasLayer) -> bool:
	var label: Label = result._hero_ribbon_label if result._hero_ribbon_host.visible else result._ribbon_label
	var font: Font = label.get_theme_font("font")
	var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0,
		label.get_theme_font_size("font_size")).x
	return width <= label.size.x + 0.5


# --- Performans ----------------------------------------------------------------------------

func _test_performance() -> void:
	print("-- performans")
	var result: CanvasLayer = _main._result
	var three: Array[ChestReward] = [_dough(SkinData.Rarity.RARE), _skin(SkinData.Rarity.EPIC, 1), _dough(SkinData.Rarity.LEGENDARY)]
	await _open(LEVEL_04, true, 1230, three, false, false, 6, true)
	await _settle(30)
	var nodes: int = _count_nodes(result.frame())
	print("    bilgi: 3 ödüllü sonuç çerçevesi düğüm sayısı = %d" % nodes)
	_c("düğüm sayısı makul (< 400)", nodes < 400)
	var loops: Array[int] = []
	for card in result.cards():
		loops.append(card.gem().continuous_effects() if card.gem() != null and card.gem().visible else 0)
	_c("reveal sonrası: Nadir kartı sürekli efekt 0", loops[0] == 0)
	_c("reveal sonrası: Legendary kartı en çok 1 (yavaş ışın)", loops[2] <= 1)
	_c("reveal sonrası: FxLayer temiz (patlama düğümleri silindi)", result.fx_layer().get_child_count() == 0)
	_c("skin kartı: sandık parçacığı gizli (swatch kahraman)", not result.cards()[1].gem().visible)
	await _leave()
	_c("kapanış: kartlar serbest (gövde boş)", (result.frame().get_meta(&"body") as Control).get_child_count() == 0)


# --- Yardımcılar ------------------------------------------------------------------------------

func _dough(rarity: SkinData.Rarity, duplicate: bool = false) -> ChestReward:
	var r := ChestReward.new()
	r.rarity = rarity
	r.dough = ChestSystem.RARITY_DOUGH[int(rarity)]
	r.is_duplicate = duplicate
	return r


func _skin(rarity: SkinData.Rarity, index: int = 0) -> ChestReward:
	var r := ChestReward.new()
	r.rarity = rarity
	var pool: Array[SkinData] = SkinLibrary.by_rarity(rarity)
	r.skin = pool[mini(index, pool.size() - 1)]
	return r


func _consolation() -> ChestReward:
	var r := ChestReward.new()
	r.is_consolation = true
	r.dough = ChestSystem.CONSOLATION_DOUGH
	return r


## Board'u kur (main'e sinyal GİTMEZ), bitmiş göster, sonucu hazır ödüllerle aç.
func _open(level_path: String, won: bool, score: int, rewards: Array[ChestReward],
		new_record: bool, newly_unlocked: bool, reached_tier: int, wait_reveal: bool) -> void:
	_main._start_level(load(level_path))
	await get_tree().process_frame
	await get_tree().process_frame
	_main._board._dismiss_tutorial()
	_main._board.round_finished.disconnect(_main._on_round_finished)
	GameState.reset_run()
	GameState.add_score(score)
	var level: LevelData = _main._current_level
	_main._board._finish(won)
	_main._revive.hide_offer()
	_main._result.show_result(level, won, score, level.stars_earned(won, score), rewards,
		new_record, newly_unlocked, reached_tier)
	await _settle(4)
	if wait_reveal:
		await _wait_reveal(_main._result)


func _wait_reveal(result: CanvasLayer) -> void:
	var waited: int = 0
	while not result.is_reveal_done() and waited < 60 * 12:
		await get_tree().process_frame
		waited += 1
	# Son kartın açılış tween'leri (skin swap 0.24 + pop 0.28) bitsin.
	await get_tree().create_timer(0.7).timeout
	await get_tree().process_frame


func _leave() -> void:
	_main._result.hide_result()
	_main.abandon_run()
	await get_tree().process_frame
	_main._show_tab(0)
	await _settle(2)


func _restore_save_file() -> void:
	if not _had_save:
		if FileAccess.file_exists(SaveManager.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
		return
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_save_bytes)
		file.close()


func _resize(view: Vector2i) -> void:
	get_window().size = view
	await get_tree().process_frame
	await get_tree().process_frame


func _settle(frames: int) -> void:
	for i in maxi(frames, 1):
		await get_tree().process_frame
	if frames >= 4:
		await get_tree().create_timer(0.25).timeout
		await get_tree().process_frame


func _pointer(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	if pressed:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(ev)


func _pointer_motion(pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = rel
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(ev)


func _tap(button: Button) -> void:
	var pos: Vector2 = button.get_global_rect().get_center()
	_pointer(pos, true)
	await get_tree().process_frame
	_pointer(pos, false)
	await _settle(4)


func _no_english(texts: Array[String]) -> bool:
	for text in texts:
		for word in ENGLISH_RARITY:
			# Tam kelime: "Rare" → "Karabiber" gibi Türkçe adların içinde geçmez ama
			# yine de kelime sınırı arayalım.
			var regex := RegEx.new()
			regex.compile("\\b%s\\b" % word)
			if regex.search(text) != null:
				print("    İngilizce rarity bulundu: '%s'" % text)
				return false
		for term in INTERNAL_TERMS:
			if text.contains(term):
				print("    iç terim bulundu: '%s'" % text)
				return false
	return true


func _tree_has_button(root: Node) -> bool:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is BaseButton:
			return true
		for child in node.get_children():
			stack.append(child)
	return false


func _count_named(root: Node, name_part: String) -> int:
	var n: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if String(node.name).contains(name_part):
			n += 1
		for child in node.get_children():
			stack.append(child)
	return n


func _count_nodes(root: Node) -> int:
	var n: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		n += 1
		for child in node.get_children():
			stack.append(child)
	return n


func _apply_showcase() -> void:
	SaveManager.data["highest_level_unlocked"] = 4
	SaveManager.data["level_stars"] = {"1": 2, "2": 3, "3": 3}
	SaveManager.data["dough"] = 335
	SaveManager.data["daily_streak"] = 2
	SaveManager.data["last_login_date"] = Time.get_date_string_from_system()
	SaveManager.data["unlocked_skins"] = ["common_01", "common_02", "rare_02", "common_04", "rare_05", "epic_01"]
	SaveManager.data["equipped_skin"] = "rare_02"
	SaveManager.data["merges_since_bonus_chest"] = 49
	SaveManager.data["endless_high_score"] = 0
	SaveManager.data["powerups"] = {"bomb": 4, "upgrade": 1, "shake": 0, "clear_small": 0}
	SaveManager.data["rewarded_power_date"] = ""
	SaveManager.data["rewarded_power_grants"] = 0
	SaveManager.data["sfx_enabled"] = true
	SaveManager.data["haptics_enabled"] = true
