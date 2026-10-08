extends Node
## Yerel kalıcı kayıt (bulut yok). JSON olarak user:// altında tutulur. Disk işlemi
## (TASK/045.1) SaveFile'da: çökmeye dayanıklı yazma (geçici dosya + doğrulama + yer
## değiştirme) ve yarım kalan işlemden deterministik kurtarma.

const SAVE_PATH: String = "user://squishy_merge_save.json"
## Kayıt dosyasının yolu. Üretimde HER ZAMAN SAVE_PATH; yalnız testler bir test yoluna
## çevirir (TASK/045.1 — sahibin gerçek kaydına dokunmadan kayıt / kurtarma testleri).
var save_path: String = SAVE_PATH
## Son `load_game`'in kaynağı (SaveFile.Source) — teşhis / testler.
var _load_source: int = SaveFile.Source.NONE

## Koleksiyon parçası (Squishy) kazanıldı (M8.5-13; TASK/044'ten beri oyuncuya
## "Yeni Squishy keşfedildi"). Abone yalnız Koleksiyon (görünürken anında,
## görünmezken bir sonraki açılışta albümde öne alır); Ana Sayfa / Mağaza /
## Profil sekme geçişindeki refresh() ile tazelenir (Main). Gameplay abone DEĞİL
## ve koleksiyonu HİÇ okumaz (TASK/044: gameplay skinleri emekli).
signal skin_granted(id: StringName)
## Profil vitrini değişti (TASK/044). Argüman: doğrulanmış vitrin (en fazla 3 id,
## ilk eleman avatar).
signal showcase_changed(ids: Array)
## Oyuncu ilerlemesi (TASK/045) kayda yazıldı: XP, başarım listesi ya da seçili
## unvan değişti. Abone yalnız Profil (görünürken tazelenir); gameplay abone DEĞİL.
## Yükleme göçü ve Profil'in bellek içi uzlaştırması YAYMAZ (kutlama / bildirim yok).
signal player_meta_changed

## Vitrin yuvası sayısı (TASK/044, owner kararı).
const SHOWCASE_MAX: int = 3
## Kayıttaki ham vitrin listesinin tavanı (bozuk / oynanmış kayıtta binlerce öğe
## açılışı kilitlemesin). Geçerli liste en fazla SHOWCASE_MAX; pay, katalogdan
## geçici kalkan id'ler için.
const SHOWCASE_RAW_CAP: int = 32
## `showcase_add` sonucu. Yalnız ADDED kayda yazar.
enum ShowcaseResult { ADDED, ALREADY, FULL, NOT_OWNED, UNKNOWN }
## Oyuncu ilerlemesi kayıt şeması (TASK/045). Kayıtta yoksa kayıt TASK/045 öncesidir:
## load_game tek seferlik göç yapar (bkz. _migrate_player_meta).
const PLAYER_META_VERSION: int = 1
## Ham başarım listesinin okunan tavanı (bozuk kayıtta binlerce öğe açılışı
## kilitlemesin). Geçerli liste en fazla katalog kadar (12).
const ACHIEVEMENTS_RAW_CAP: int = 64
## `select_title` sonucu. Yalnız SELECTED kayda yazar.
enum TitleResult { SELECTED, ALREADY, LOCKED, UNKNOWN }
## Okunan tamsayı kayıt değerinin mutlak sınırı (int64 ~9.22e18'in altında): üstü bozuk
## sayılır — `int()` dönüşümü platforma bağlı olmasın, `x ± 1` sarmasın (TASK/045).
const SAFE_INT_LIMIT: float = 9.0e18

var data: Dictionary = {}

## Ödüllü güç kotası bloğu (TASK/060) ve göç eden eski M8.5-06 anahtarları.
const KEY_REWARDED_QUOTA: String = "rewarded_power_quota"
const LEGACY_REWARDED_DATE: String = "rewarded_power_date"
const LEGACY_REWARDED_GRANTS: String = "rewarded_power_grants"

const DEFAULT_DATA: Dictionary = {
	"highest_level_unlocked": 1,
	"level_stars": {},
	"endless_high_score": 0,
	"dough": 0,
	## Koleksiyon sahipliği. Anahtar adı TARİHSEL ("skin", M3–M9): TASK/044'ten beri
	## oyuncuya "koleksiyon parçası / Squishy" — eski kayıtlar okusun diye ad
	## DEĞİŞMEDİ, sahiplik aynen korunur. Sıra kazanılma sırası (yalnız sona eklenir).
	"unlocked_skins": [],
	## ESKİ "equipped_skin" (M8.5 gameplay skini) BURADA YOK — TASK/044'te emekli.
	## Eski kayıtta durursa gameplay onu HİÇ okumaz; load_game bir kez vitrine taşır
	## ve bellekten siler (bkz. _migrate_legacy_equip).
	##
	## Profil vitrini (TASK/044): en fazla 3 koleksiyon parçası id'si, sıralı; ilk
	## eleman profil avatarı. Gameplay'e HİÇBİR etkisi yok. Okuma her zaman
	## doğrulanır (`profile_showcase()`): sahip olunmayan / katalogda olmayan /
	## tekrar eden id yok sayılır.
	"profile_showcase": [],
	## Profil sayaçları (TASK/044) — kayıttan geri üretilemeyen iki istatistik,
	## ikisi de YALNIZ `record_round_finished` ile (Main._on_round_finished):
	##   total_rounds_played   round başına TAM +1 — GameBoard.round_finished (kazanma
	##                         ya da kaybetme; level ya da sonsuz; tutorial'ın gerçek
	##                         Level 1 round'u bittiyse o da bir kez). Terk edilen round
	##                         (Mola → Ana Menüye Dön / Yeniden Başla, yaş kısıtı) SAYILMAZ
	##                         — total_merges / yıldız / rekorla aynı an, aynı kural.
	##   highest_tier_created  bitmiş round'larda merge ya da Büyütücü ile OLUŞTURULAN en
	##                         yüksek tier (düşen parça sayılmaz; GAME_DESIGN §10.3).
	## Eski kayıtta geçmiş BİLİNMİYOR: uydurulmaz — 0'dan başlar ve
	## `profile_counters_partial` true olur (profil "güncellemeden beri" der).
	"total_rounds_played": 0,
	"highest_tier_created": 0,
	"profile_counters_partial": false,
	## Oyuncu Seviyesi + başarımlar + unvanlar (TASK/045 — GAME_DESIGN §5.9):
	##   player_xp              KÜMÜLATİF XP, tek gerçek. Seviye SAKLANMAZ (XP'den türetilir,
	##                          PlayerProgression). Yalnız `record_round_finished` artırır.
	##   unlocked_achievements  açılan başarım id'leri, açılma sırasıyla; yalnız sona eklenir,
	##                          HİÇ çıkarılmaz (monoton). Unvan açıkları SAKLANMAZ — buradan
	##                          türer (AchievementCatalog).
	##   selected_title_id      seçili unvan; okuma her zaman doğrulanır (bilinmeyen / kilitli →
	##                          varsayılan "birlestirici"). Yalnız `select_title` yazar.
	##   player_meta_version    şema sürümü; kayıtta yoksa kayıt TASK/045 öncesidir → tek
	##                          seferlik göç (bkz. _migrate_player_meta).
	"player_xp": 0,
	"unlocked_achievements": [],
	"selected_title_id": "birlestirici",
	"player_meta_version": 1,
	"total_merges": 0,
	"merges_since_bonus_chest": 0,
	"daily_streak": 0,
	"last_login_date": "",
	## Güç envanteri (M8.5-03). Anahtarlar PowerUp.SAVE_KEYS.
	## Başlangıç stoğu burada DEĞİL: _grant_starter_powerups() bir kez veriyor,
	## böylece eski kayıtlar da hediyeyi bir kez alıyor ve her açılışta
	## yeniden almıyor.
	"powerups": {},
	## Başlangıç hediyesi verildi mi? Kayıt başına tek sefer.
	"powerup_starter_granted": false,
	## Ödüllü güç refill kotası (TASK/060 — Issue #1 §3): güç BAŞINA günde 2 başarılı ödül, dört bağımsız sayaç.
	## Sürümlü blok {"version", "day_key", "grants": {PowerUp.SAVE_KEYS → 0..2}} — kurallar RewardedPolicy'de.
	## Eski M8.5-06 ortak sayacı (`rewarded_power_date` + tek sayı `rewarded_power_grants`) yüklemede BELLEKTE
	## bu bloğa göç eder ve düşer (`_migrate_rewarded_power_quota`; okumada disk yazması yok).
	"rewarded_power_quota": {"version": 1, "day_key": "", "grants": {}},
	## Ayarlar (M8.5-10). Ses efektleri açık mı? Eski kayıtlarda anahtar yok,
	## load_game DEFAULT_DATA üzerine yazdığı için otomatik true kalıyor.
	"sfx_enabled": true,
	## Titreşim (M8.5-15). Mobilde varsayılan AÇIK; eski kayıtlarda anahtar
	## yok, DEFAULT_DATA üzerine yazıldığı için otomatik true kalıyor.
	"haptics_enabled": true,
	## İlk açılış / tutorial dikişi (M8.9-02; tutorial M8.10).
	## YENİ kayıt: false — banner, interstitial, günlük ödül penceresi ve
	## ödüllü reklam sunumu tutorial bitene kadar kapalı. ESKİ kayıt (anahtar
	## yok): load_game ilerleme kanıtına bakar (bkz. _migrate_onboarding) —
	## gerçek oyuncular etkilenmez. Yalnız `complete_onboarding` true yapar.
	"onboarding_completed": false,
	## Tutorial'ın tamamlandığı YEREL TAKVİM GÜNÜ (YYYY-MM-DD) — M8.10 ilk gün
	## kuralı (docs/TUTORIAL_SYSTEM.md §5). O gün günlük ödül sistemi tamamen
	## kapalıdır; ertesi yerel günde sıfırdan başlar. BOŞ STRING iki farklı
	## şeyi anlatır ve ikisi de doğru davranışı verir:
	##   onboarding false -> tutorial henüz bitmedi (zaten her şey kapalı)
	##   onboarding true  -> ESKİ/YERLEŞİK kayıt (M8.10 öncesi tamamlanmış):
	##                       bastırma YOK, bugünün tarihi UYDURULMAZ.
	"onboarding_completed_day": "",
	## Yaş bandı (TASK/043, docs/monetization/AGE_BAND_ROUTING.md) — reklam yönlendirmesinin
	## tek girdisi (AgeGate). HAM DOĞUM TARİHİ BURADA YOK: yaş ekranında seçilen tarih
	## sınıflandırılıp atılır; yalnız türetilmiş bant ("UNKNOWN" / "TEEN" / "ADULT") ve TEEN
	## için 18. yaş günü (YYYY-MM-DD; ADULT'ta boş) saklanır. Eski kayıtlarda anahtar yok ->
	## "UNKNOWN": reklam SDK'sı başlamaz, yaş ilk güvenli kabukta sorulur; ilerleme SİLİNMEZ.
	## TASK/046.1: yaş ekranı yalnız 13+ tarih sunar; "UNDER_13" artık YAZILMAZ — TASK/043
	## döneminden kalan "UNDER_13" açılışta "UNKNOWN" + boş tarihe yazılır (reklam yok, yaş
	## yeniden sorulur; TEEN / ADULT'a çevrilmez, ilerleme silinmez).
	"age_ad_band": "UNKNOWN",
	"next_age_transition_date": "",
	## Günlük ödüller (M8.9-02, docs/monetization/DAILY_REWARDS.md): yerel
	## takvim günü anahtarı + o günün kotaları. Gün değişince sayaçlar
	## OKUMADA sıfır görünür (yazma yok); ilk işlem yeni günü yazar.
	## `last_seen_day_key`: görülen en yeni gün — saat geri alınırsa yeni
	## ödül üretilmez (DailyRewards.day_key). `popup_seen_day`: otomatik
	## pencerenin gösterildiği gün (ödül tüketmez).
	"daily_rewards": {
		"day_key": "",
		"free_chest_claimed": false,
		"ad_chests_claimed": 0,
		"dough_ad_claimed": false,
		"popup_seen_day": "",
		"last_seen_day_key": "",
	},
	## Günlük / haftalık görevler (TASK/046 — GAME_DESIGN §5.10): sürümlü TEK durum, kural /
	## doğrulama Missions'ta. Yeni kayıtta dönem YOK (gün boş) — ilk okuma kabul edilen günün
	## taze dönemini görür, ilk round kaydı yazar. Eski kayıt: load_game bellekte taze dönem
	## kurar (geriye dönük ilerleme / Hamur YOK). UI durumu (açık pencere, "görüldü") SAKLANMAZ.
	##   version              şema (1)
	##   day_key              görev günü (YYYY-MM-DD) — GÜNLÜK ÖDÜLLER'in kabul edilen günü
	##   week_start_day_key   o günün haftasının PAZARTESİ tarihi
	##   daily_progress / weekly_progress   görev id → 0..hedef
	##   daily_rewarded / weekly_rewarded   ödülü verilmiş görev id'leri (katalog sırası)
	"missions": {
		"version": 1,
		"day_key": "",
		"week_start_day_key": "",
		"daily_progress": {},
		"daily_rewarded": [],
		"weekly_progress": {},
		"weekly_rewarded": [],
	},
	## Günlük meydan okuma (TASK/047 — GAME_DESIGN §5.11): sürümlü EN KÜÇÜK blok, kural /
	## doğrulama DailyChallenge'da. `completed_day_key` = ilk başarısı ödüllendirilen EN YENİ gün
	## (+20 Hamur ile AYNI yazmada). Preset / hedef / bütçe / dizi / deneme / UI durumu
	## SAKLANMAZ. Eski kayıt: load_game bellekte varsayılan blok kurar (geriye dönük tamamlanma /
	## Hamur YOK, yalnız bu yüzden diske yazma YOK).
	"daily_challenge": {
		"version": 1,
		"completed_day_key": "",
	},
}


func _ready() -> void:
	load_game()


## Kanonik kayıt geçerliyse o; değilse yarım kalan kayıt işleminin geçerli ara dosyası
## (SaveFile kuralları). Kurtarılacak kayıt yoksa TASK/045.1 öncesi davranış: kanonik
## dosya hiç yoksa yeni oyuncu (başlangıç hediyesi + kayıt), varsa okunamıyor / bozuk →
## varsayılanlar, diske yazılmaz. Geçerli kanonik kayıtla yükleme kanonik dosyaya YAZMAZ.
func load_game() -> void:
	data = DEFAULT_DATA.duplicate(true)
	var loaded: Dictionary = SaveFile.read_save(save_path)
	_load_source = int(loaded["source"])
	var parsed: Variant = loaded["data"]
	if parsed == null:
		if not bool(loaded["canonical_exists"]):
			_grant_starter_powerups()
			return
		push_warning("Kayıt dosyası okunamadı ya da bozuk, varsayılanlara dönülüyor.")
		return
	if _load_source != SaveFile.Source.CANONICAL:
		push_warning("Kayıt, yarım kalan bir kayıt işleminden kurtarıldı (%s)." % SaveFile.source_name(_load_source))
	for key: String in parsed:
		data[key] = parsed[key]
	if _load_source == SaveFile.Source.BACKUP:
		# Bir önceki kuşaktan kurtarıldı: yaş bandı güncel olmayabilir (ör. son kayıt bir yeniden
		# girişti). TASK/043 fail-closed: bant UNKNOWN → reklam SDK'sı / UMP başlamaz,
		# yaş ilk güvenli kabukta yeniden sorulur; ilerleme kurtarılır. Bellekte; kanonik ad
		# `.bak`'tan kopyayla geri kurulduysa hemen kalıcılaşır (aşağıda).
		data["age_ad_band"] = "UNKNOWN"
		data["next_age_transition_date"] = ""
	_migrate_onboarding(parsed)
	_migrate_legacy_equip(parsed)
	_sanitize_showcase()
	_migrate_profile_counters(parsed)
	_migrate_player_meta(parsed)
	_migrate_missions(parsed)
	_migrate_daily_challenge(parsed)
	_migrate_rewarded_power_quota(parsed)
	_grant_starter_powerups()
	# A36 kapısı: kanonik ad boşken SaveFile `.bak`'ı kanonik ada KOPYALAR — kopya eski bandı
	# taşır ve bir sonraki açılış onu geçerli kanonik diye okurdu (yaş sorusunda çıkan oyuncuda
	# SDK eski bantla açılıyordu). UNKNOWN burada kalıcılaşır. Bozuk kanonik duruyorsa her açılış
	# yine `.bak`'tan kurtarır (UNKNOWN); ona yüklemede dokunulmaz (değişmedi).
	if _load_source == SaveFile.Source.BACKUP and not bool(loaded["canonical_exists"]):
		save_game()


## Eski kayıt (anahtar yok) için tek seferlik onboarding kararı (M8.9-02).
## Kural (docs/monetization/DAILY_REWARDS.md §9): kanonik ilerleme alanlarından
## herhangi biri oynanmışlık kanıtıysa tutorial TAMAMLANMIŞ sayılır —
## `highest_level_unlocked` > 1, en az bir level yıldızı, `total_merges` > 0,
## sonsuz mod rekoru ya da açılmış skin. Hamur miktarına BAKILMAZ (günlük giriş
## ödülü tek açılışta 15 Hamur veriyor; oynanmışlık kanıtı değil). Yalnız
## bellekte karar verilir, DİSKE YAZILMAZ: sonraki doğal kayıt anahtarı
## kalıcılaştırır (okuma sırasında beklenmedik yazma yok — rewarded_power ve
## profil vitrini migration'ıyla aynı ilke). Dosyasız yeni oyuncu bu yola hiç
## girmez (DEFAULT_DATA false).
##
## M8.10: `onboarding_completed_day` burada UYDURULMAZ — boş kalır ve
## `Onboarding.daily_rewards_unlocked()` bunu "yerleşik oyuncu, ilk gün
## bastırması YOK" diye okur (docs/TUTORIAL_SYSTEM.md §6). Eski oyuncuların
## günlük ödül davranışı böylece birebir korunur.
func _migrate_onboarding(parsed: Dictionary) -> void:
	if parsed.has("onboarding_completed"):
		return
	data["onboarding_completed"] = has_progress_evidence()


## Eski takılı skin (`equipped_skin`, M8.5–M9) — TASK/044'te gameplay skinleri
## EMEKLİ; gameplay bu anahtarı HİÇ okumaz. Tek seferlik ve yalnız bellekte: kayıtta
## henüz `profile_showcase` yoksa ve eski id sahip olunan bir KATALOG parçasıysa
## vitrinin ilk (avatar) yuvasına taşınır — oyuncunun eski favorisi profilinde
## görünür. Sonra anahtar bellekten silinir; bir sonraki doğal kayıt ikisini birlikte
## kalıcılaştırır (göçün kendisi diske yazmaz; yalnız M8.5-03 öncesi kayıtta aynı
## yüklemedeki başlangıç güç hediyesi kaydı onu da yazar — sonuç aynı). Yazılmadan
## kapanırsa bir sonraki açılışta aynı sonuç (idempotent). Sahiplik
## (`unlocked_skins`) DEĞİŞMEZ.
## Boş / sahip olunmayan / katalogda olmayan / biçimsiz id → vitrin boş kalır.
func _migrate_legacy_equip(parsed: Dictionary) -> void:
	if not parsed.has("equipped_skin"):
		return
	var raw: Variant = parsed["equipped_skin"]
	data.erase("equipped_skin")
	if parsed.has("profile_showcase"):
		return
	if typeof(raw) != TYPE_STRING or String(raw).is_empty():
		return
	var id := StringName(String(raw))
	if owns_skin(id) and SkinLibrary.find(id) != null:
		data["profile_showcase"] = [String(id)]


## Kayıttaki vitrin alanını güvenli BİÇİME indirir (dizi değilse boş; yalnız boş
## olmayan metin id'ler, tekrarsız, en fazla SHOWCASE_RAW_CAP) — yalnız bellekte.
## Sahiplik / katalog / 3 sınırı okumada süzülür (`profile_showcase`): katalogdan
## geçici kalkan bir id yüklemede silinmez; bir sonraki VİTRİN yazması ise yalnız
## doğrulanmış id'leri saklar (brief: "yok say" — 3 sınırı geri dönüşte de korunur).
func _sanitize_showcase() -> void:
	var raw: Variant = data.get("profile_showcase", [])
	var clean: Array = []
	var seen: Dictionary = {}
	if raw is Array:
		for item: Variant in raw:
			if clean.size() >= SHOWCASE_RAW_CAP:
				break
			if typeof(item) != TYPE_STRING or String(item).is_empty() or seen.has(String(item)):
				continue
			seen[String(item)] = true
			clean.append(String(item))
	data["profile_showcase"] = clean


## Profil sayaçları (TASK/044) eski kayıtta yok: geçmiş bilinmiyor ve UYDURULMAZ.
## Sayaçlar 0'dan başlar; oynanmışlık kanıtı olan kayıtta `profile_counters_partial`
## true (profil "güncellemeden beri" notunu gösterir). Yalnız bellekte.
func _migrate_profile_counters(parsed: Dictionary) -> void:
	if parsed.has("total_rounds_played"):
		return
	data["total_rounds_played"] = 0
	data["highest_tier_created"] = 0
	data["profile_counters_partial"] = has_progress_evidence()


## Oyuncu ilerlemesi (TASK/045): deterministik, idempotent, YALNIZ bellekte — yüklemede
## disk yazması yok, sonraki doğal kayıt kalıcılaştırır (diğer göçlerle aynı ilke;
## yazılmadan kapanırsa bir sonraki açılışta aynı sonuç).
##   - İlerleme alanı YOKSA (TASK/045 öncesi kayıt): XP kayıttaki gerçeklerden BİR KEZ
##     türetilir — merge + 10·yıldız + 20·tamamlanan level (PlayerProgression.bootstrap_xp).
##     Round yeniden kurulmaz; skor / güç kullanımı / geçmiş UYDURULMAZ.
##   - Varsa XP doğrulanır; bozuksa (negatif / metin / NaN / saçma büyük) aynı bootstrap'la
##     KURTARILIR — kayıttaki gerçeklerin kanıtladığı XP, fazlası değil.
##   - Başarım listesi biçim olarak temizlenir (yalnız katalogdaki id'ler, tekrarsız);
##     kayıttaki gerçeklerin desteklediği başarımlar SESSİZCE açılır (sinyal / kutlama yok).
##     Bilinmeyen id: yok sayılır ve bir sonraki kayıtta düşer — V1'in her başarımı kanonik
##     istatistikten yeniden türetilebildiği için gerçek bir açılış kaybolamaz; Play sürüm
##     düşürmeye izin vermediğinden ileri uyumluluk için saklamanın güçlü bir sebebi yok.
##   - Seçili unvan doğrulanır: bilinmeyen / kilitli → varsayılan (geçersiz unvan kayda
##     geri yazılmaz).
func _migrate_player_meta(parsed: Dictionary) -> void:
	var stored_xp: int = -1
	if parsed.has("player_meta_version") or parsed.has("player_xp"):
		stored_xp = PlayerProgression.sanitize_xp(parsed.get("player_xp"))
	data["player_xp"] = stored_xp if stored_xp >= 0 else _bootstrap_xp()
	data["player_meta_version"] = PLAYER_META_VERSION
	_store_achievement_ids(unlocked_achievements())
	_unlock_satisfied_achievements()
	data["selected_title_id"] = String(selected_title_id())


## Görevler (TASK/046): kayıtta geçerli görev durumu yoksa (TASK/046 öncesi kayıt, bozuk yapı,
## bilinmeyen sürüm) kabul edilen günün TAZE dönemi — ilerleme 0, ödül işareti yok, Hamur
## verilmez, geçmiş round'lardan geriye dönük ilerleme UYDURULMAZ. Varsa biçim olarak
## doğrulanır (bilinmeyen id / tekrar / aralık dışı değer temizlenir); dönemi okuma ve round
## kaydı ilerletir. YALNIZ bellekte (diğer göçlerle aynı ilke: sonraki doğal kayıt
## kalıcılaştırır; yazılmadan kapanırsa bir sonraki açılışta aynı sonuç).
func _migrate_missions(parsed: Dictionary) -> void:
	var state: Dictionary = Missions.sanitize(parsed.get("missions"))
	if state.is_empty():
		var day: String = Missions.accepted_day()
		state = Missions.fresh_state(day) if Missions.is_day_key(day) else DEFAULT_DATA["missions"].duplicate(true)
	data["missions"] = state


## Günlük meydan okuma (TASK/047): blok yoksa (TASK/047 öncesi kayıt) varsayılan — tamamlanma yok,
## Hamur verilmez; bozuk yapı / bilinmeyen sürüm / geçersiz gün de varsayılana iner. YALNIZ
## bellekte (diğer göçlerle aynı ilke: sonraki doğal kayıt kalıcılaştırır).
func _migrate_daily_challenge(parsed: Dictionary) -> void:
	data["daily_challenge"] = DailyChallenge.sanitize(parsed.get("daily_challenge"))


## Ödüllü güç kotası (TASK/060): güç başına blok varsa doğrulanır (V3 önceliklidir; bozuk blok bugün için kapalı —
## RewardedPolicy.sanitize). Yoksa eski M8.5-06 ortak sayacı muhafazakâr göçle aktarılır (RewardedPolicy.from_legacy:
## eski tarih bugünse dört sayaç da eski kullanımla — 0..1 — başlar, değilse 0). Eski iki anahtar bellekten düşer.
## YALNIZ bellekte (diğer göçlerle aynı ilke: sonraki doğal kayıt kalıcılaştırır; yazılmadan kapanırsa bir sonraki
## açılışta aynı sonuç). Stok / Hamur / level / yıldız ve diğer alanlara dokunmaz.
func _migrate_rewarded_power_quota(parsed: Dictionary) -> void:
	var today: String = Missions.accepted_day()
	if parsed.has(KEY_REWARDED_QUOTA):
		data[KEY_REWARDED_QUOTA] = RewardedPolicy.sanitize(parsed[KEY_REWARDED_QUOTA], today)
	else:
		data[KEY_REWARDED_QUOTA] = RewardedPolicy.from_legacy(parsed.get(LEGACY_REWARDED_DATE),
			parsed.get(LEGACY_REWARDED_GRANTS), today)
	data.erase(LEGACY_REWARDED_DATE)
	data.erase(LEGACY_REWARDED_GRANTS)


## Kayıtta oynanmışlık kanıtı var mı (onboarding migration kuralı).
func has_progress_evidence() -> bool:
	if highest_level_unlocked() > 1:
		return true
	if not (data.get("level_stars", {}) as Dictionary).is_empty():
		return true
	if int(data.get("total_merges", 0)) > 0:
		return true
	if endless_high_score() > 0:
		return true
	return not owned_skins().is_empty()


## Kaydı çökmeye dayanıklı işlemle yazar (SaveFile; biçim aynı: sekme girintili JSON).
## true = yeni kayıt kanonik dosyada. false = yazma başarısız: ÖNCEKİ geçerli kayıt diskte
## aynen duruyor, hata push_error ile bildirildi (içerik loglanmaz); bellekteki `data`
## değişmez — bir sonraki kayıt yeniden dener.
func save_game() -> bool:
	return SaveFile.write_save(save_path, JSON.stringify(data, "\t"))


## Son yüklemenin kaynağı (SaveFile.Source): CANONICAL normal açılış, TEMP / BACKUP
## yarım kalan bir kayıt işleminden kurtarma, NONE kayıt yok / bozuk.
func load_source() -> int:
	return _load_source


# --- İlerleme (M2) ---

func highest_level_unlocked() -> int:
	return _safe_int(data.get("highest_level_unlocked", 1), 1)


func is_level_unlocked(level_number: int) -> bool:
	return level_number <= highest_level_unlocked()


## Level tamamlandığında bir sonrakini açar. Geriye gitmez. Tamamlanan level
## başarımları (TASK/045) AYNI yazmada açılır. `save = false`: yalnız Main'in round
## kesinleştirmesi — yazma aynı round'un `record_round_finished` yazmasına katlanır
## (level + yıldız + XP tek yazmada; araya giren çökme XP'yi yıldızdan ayıramaz).
func complete_level(level_number: int, save: bool = true) -> void:
	if level_number + 1 > highest_level_unlocked():
		data["highest_level_unlocked"] = level_number + 1
		var unlocked: bool = not _unlock_satisfied_achievements().is_empty()
		if save:
			save_game()
		if unlocked:
			player_meta_changed.emit()


## Sonsuz mod level 10 bitince açılır (GAME_DESIGN.md §4).
func is_endless_unlocked(total_levels: int) -> bool:
	return highest_level_unlocked() > total_levels


func endless_high_score() -> int:
	return int(data.get("endless_high_score", 0))


## Yeni rekor kırıldıysa true döner. `save = false`: `complete_level` ile aynı
## (round kaydına katlanır).
func record_endless_score(score: int, save: bool = true) -> bool:
	if score <= endless_high_score():
		return false
	data["endless_high_score"] = score
	if save:
		save_game()
	return true


# --- Koleksiyon, para ve sandık sayacı (M3) ---

func dough() -> int:
	return int(data.get("dough", 0))


func add_dough(amount: int) -> void:
	data["dough"] = dough() + amount
	save_game()


## Hamur harcar. Yetmiyorsa hiçbir şey yapmaz ve false döner — çağıran
## tarafın ayrıca kontrol etmesine gerek kalmasın diye burada da bakılıyor.
func spend_dough(amount: int) -> bool:
	if amount <= 0 or dough() < amount:
		return false
	data["dough"] = dough() - amount
	save_game()
	return true


## Sahiplik listesi; biçimsiz kayıt değeri (dizi değil) boş sayılır (TASK/045:
## koleksiyon başarımı her yüklemede okur — bozuk kayıt açılışı düşürmesin).
func owned_skins() -> Array:
	var raw: Variant = data.get("unlocked_skins", [])
	return raw if raw is Array else []


func owns_skin(id: StringName) -> bool:
	return owned_skins().has(String(id))


## Sandıktan parça. Koleksiyon başarımları (TASK/045) AYNI yazmada açılır.
func grant_skin(id: StringName) -> void:
	if owns_skin(id):
		return
	var owned: Array = owned_skins().duplicate()
	owned.append(String(id))
	data["unlocked_skins"] = owned
	var unlocked: bool = not _unlock_satisfied_achievements().is_empty()
	save_game()
	skin_granted.emit(id)
	if unlocked:
		player_meta_changed.emit()


# --- Profil vitrini (TASK/044) ---
#
# Koleksiyon parçaları gameplay'i DEĞİŞTİRMEZ (M8.5 "takılı skin" emekli). Sahip
# olunan en fazla 3 parça profilde sergilenir; ilk yuva avatar. Kural tek yerde
# (burada): yalnız sahip olunan + katalogda bulunan id, en fazla 3, tekrar yok.
# Doluyken sessiz / rastgele değiştirme YOK — değiştirme yalnız oyuncunun seçtiği
# yuvaya (`showcase_replace`). Her yazma TEK `save_game()` + `showcase_changed`.

## Doğrulanmış vitrin: sıralı, en fazla SHOWCASE_MAX, tekrarsız; yalnız sahip olunan
## ve katalogda bulunan parçalar. Katalogdan kalkan ya da sahipliği olmayan id sessizce
## yok sayılır. YAZMAZ (okuma sırasında disk yazması yok).
func profile_showcase() -> Array[StringName]:
	var out: Array[StringName] = []
	var raw: Variant = data.get("profile_showcase", [])
	if not raw is Array:
		return out
	for item: Variant in raw:
		if out.size() >= SHOWCASE_MAX:
			break
		if typeof(item) != TYPE_STRING:
			continue
		var id := StringName(String(item))
		if id == &"" or out.has(id):
			continue
		if not owns_skin(id) or SkinLibrary.find(id) == null:
			continue
		out.append(id)
	return out


func is_showcased(id: StringName) -> bool:
	return profile_showcase().has(id)


## Vitrindeki yuva (0 = avatar) ya da -1.
func showcase_slot(id: StringName) -> int:
	return profile_showcase().find(id)


## Vitrine ekler (sona). Dolu, sahip olunmayan, bilinmeyen ya da zaten vitrindeki
## id hiçbir alanı değiştirmez ve diske yazmaz.
func showcase_add(id: StringName) -> ShowcaseResult:
	if id == &"" or SkinLibrary.find(id) == null:
		return ShowcaseResult.UNKNOWN
	if not owns_skin(id):
		return ShowcaseResult.NOT_OWNED
	var current: Array[StringName] = profile_showcase()
	if current.has(id):
		return ShowcaseResult.ALREADY
	if current.size() >= SHOWCASE_MAX:
		return ShowcaseResult.FULL
	current.append(id)
	_store_showcase(current)
	return ShowcaseResult.ADDED


## Vitrinden çıkarır; sonrakiler bir yuva öne kayar (ilk yuva çıkarsa ikinci avatar
## olur). Vitrinde değilse hiçbir şey yazılmaz.
func showcase_remove(id: StringName) -> bool:
	var current: Array[StringName] = profile_showcase()
	if not current.has(id):
		return false
	current.erase(id)
	_store_showcase(current)
	return true


## Vitrin doluyken BİLİNÇLİ değiştirme: `new_id` oyuncunun seçtiği `old_id`'nin
## yuvasına girer (yuva sırası — avatar yuvası dahil — korunur). Geçersiz her
## kombinasyon hiçbir şey yazmaz.
func showcase_replace(old_id: StringName, new_id: StringName) -> bool:
	if new_id == &"" or SkinLibrary.find(new_id) == null or not owns_skin(new_id):
		return false
	var current: Array[StringName] = profile_showcase()
	var slot: int = current.find(old_id)
	if slot < 0 or current.has(new_id):
		return false
	current[slot] = new_id
	_store_showcase(current)
	return true


## "Avatar yap": vitrindeki parçayı ilk yuvaya taşır, diğerlerinin sırası korunur.
## Zaten ilk yuvadaysa ya da vitrinde değilse yazılmaz.
func showcase_make_first(id: StringName) -> bool:
	var current: Array[StringName] = profile_showcase()
	var slot: int = current.find(id)
	if slot <= 0:
		return false
	current.remove_at(slot)
	current.insert(0, id)
	_store_showcase(current)
	return true


func _store_showcase(ids: Array[StringName]) -> void:
	var raw: Array = []
	for id in ids:
		raw.append(String(id))
	data["profile_showcase"] = raw
	save_game()
	showcase_changed.emit(ids.duplicate())


# --- Profil sayaçları (TASK/044) ---
#
# Yalnız kayıttan GERİ ÜRETİLEMEYEN iki istatistik saklanır (DEFAULT_DATA notu);
# yıldız / koleksiyon / güç stoğu / rekor kanonik alanlardan türetilir
# (PlayerProfile). Biçimsiz değer (eski / bozuk kayıt) 0 okunur.

func total_rounds_played() -> int:
	return maxi(_as_int(data.get("total_rounds_played", 0)), 0)


func highest_tier_created() -> int:
	return clampi(_as_int(data.get("highest_tier_created", 0)), 0, TierConfig.MAX_TIER)


## Kayıt sayaçlardan ÖNCEKİ bir sürümden geliyor: sayaçlar "güncellemeden beri".
func profile_counters_partial() -> bool:
	return data.get("profile_counters_partial", false) == true


## Round KESİN bitti — yalnız Main._on_round_finished, round başına TAM bir kez
## (GameBoard._finish + Main kesinleştirme koruması). Tur sayacı +1, bu round'da
## oluşturulan en yüksek tier rekoru ve (TASK/045) round'un XP'si
## (`PlayerProgression.round_xp_award`) — HEPSİ bu TEK yazmada; Main'in `save = false`
## ile hemen önce bellekte işlediği level açılışı / yıldız / sonsuz rekoru da bu yazmayla
## diske iner (XP ile dayandığı yıldız farkı ayrı yazmalara bölünmez). `created_tier`
## 0 = merge / Büyütücü yok (rekor değişmez); `xp_award` ≤ 0 XP'ye dokunmaz.
func record_round_finished(created_tier: int, xp_award: int = 0) -> void:
	data["total_rounds_played"] = total_rounds_played() + 1
	var tier: int = clampi(created_tier, 0, TierConfig.MAX_TIER)
	if tier > highest_tier_created():
		data["highest_tier_created"] = tier
	var xp_before: int = player_xp()
	if xp_award > 0:
		data["player_xp"] = PlayerProgression.add_xp(xp_before, xp_award)
	var unlocked: bool = not _unlock_satisfied_achievements().is_empty()
	save_game()
	if unlocked or player_xp() != xp_before:
		player_meta_changed.emit()


# --- Günlük / haftalık görevler (TASK/046 — GAME_DESIGN §5.10) ---
#
# Kural / doğrulama / dönem SAF Missions'ta; burada yalnız doğrulanmış okuma ve round başına
# TEK mutasyon. Görev XP, başarım, unvan, sandık, güç ya da reklam ÜRETMEZ; tek ekonomi etkisi
# otomatik görev Hamur'u.

## Görevlerin kabul edilen gündeki durumu (Missions.for_day): dönem değişimi okumada görünür,
## kayıttaki dönemin gerisine düşmez. YAZMAZ.
func missions_state() -> Dictionary:
	return Missions.for_day(data.get("missions"), Missions.accepted_day())


## Round KESİN bitti — yalnız Main._on_round_finished, round başına TAM bir kez (kesinleştirme
## korumalı): görev ilerlemesi (bu round'un gerçek merge'leri · tur +1 · sabit level başarıyla
## bittiyse +1) ve hedefine İLK kez ulaşan görevlerin OTOMATİK Hamur ödülü — ilerleme, ödül
## işareti ve Hamur AYNI mutasyonda. `save = false`: yazma aynı round'un `record_round_finished`
## yazmasına katlanır (XP / yıldız / level ile TEK yazma). Döner: {completed: Array[StringName]
## (katalog sırası), dough: int}. Kabul edilen gün yoksa (bozuk saat) yeni dönem açılmaz: kayıtlı
## dönem varsa round ona işlenir (ödül işaretleri geçerli — ikinci ödül yok), yoksa hiçbir şey
## değişmez.
func record_mission_round(merges: int, fixed_level_cleared: bool, save: bool = true) -> Dictionary:
	var state: Dictionary = missions_state()
	var none: Array[StringName] = []
	if state.is_empty():
		return {"completed": none, "dough": 0}
	var result: Dictionary = Missions.advance(state, merges, 1, 1 if fixed_level_cleared else 0)
	data["missions"] = result["state"]
	var reward: int = int(result["dough"])
	if reward > 0:
		data["dough"] = dough() + reward
	if save:
		save_game()
	return {"completed": result["completed"], "dough": reward}


# --- Günlük meydan okuma (TASK/047 — GAME_DESIGN §5.11) ---
#
# Kural / doğrulama SAF DailyChallenge'da; burada yalnız doğrulanmış okuma ve TEK mutasyon. Meydan
# okuma XP, görev, başarım, sandık, yıldız, level, istatistik ya da reklam ÜRETMEZ; tek ekonomi
# etkisi ilk başarının +20 Hamur'u.

## Doğrulanmış blok (kopya) — YAZMAZ.
func daily_challenge_state() -> Dictionary:
	return DailyChallenge.sanitize(data.get("daily_challenge"))


## İlk başarısı ödüllendirilen en yeni gün (YYYY-MM-DD) ya da boş.
func daily_challenge_completed_day() -> String:
	return String(daily_challenge_state()[DailyChallenge.KEY_COMPLETED])


## İlk başarı — TEK, idempotent işlem: gün geçerli ve kayıttaki tamamlanma gününden YENİ ise
## `completed_day_key` = `day_key` + tam DailyChallenge.REWARD_DOUGH Hamur, AYNI `save_game()`
## yazmasında (ayrı "ödül verildi" bayrağı YOK — tamamlanma günü ödülün kendisidir). Aynı / eski
## gün, geçersiz gün → hiçbir alan değişmez, diske yazılmaz, false. `day_key` = denemenin
## BAŞLADIĞI kabul edilen gün (gece yarısı kuralı: Main).
func complete_daily_challenge(day_key: String) -> bool:
	var block: Dictionary = daily_challenge_state()
	if not DailyChallenge.can_complete(block, day_key):
		return false
	block[DailyChallenge.KEY_COMPLETED] = day_key
	data["daily_challenge"] = block
	data["dough"] = dough() + DailyChallenge.REWARD_DOUGH
	save_game()
	return true


## Sayı değilse 0. TASK/045: int64 dışı / NaN float da 0 — `int()` bunu platforma göre
## farklı çevirir (x86 INT64_MIN, ARM doygun INT64_MAX); değer XP göçüne ve başarımlara girer.
static func _as_int(value: Variant) -> int:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			return _safe_int(value, 0)
	return 0


## `int()` ile aynı sonuç, ama biçimsiz kayıt değeri (null / dizi / sözlük / NaN /
## int64 dışı float ya da metin) betik hatası ya da INT64 uç değeri yerine `fallback`
## (TASK/045: ilerleme istatistikleri her yüklemede okunur).
static func _safe_int(value: Variant, fallback: int) -> int:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			var number: float = value
			if is_nan(number) or is_inf(number) or absf(number) >= SAFE_INT_LIMIT:
				return fallback
			return int(number)
		TYPE_STRING:
			# 19+ basamaklı metni `to_int()` motor hatası basıp INT64 ucuna doyurur ("-999…" →
			# INT64_MIN; sonraki `- 1` sarar). 18 basamak her zaman SAFE_INT_LIMIT'in altında.
			var text: String = String(value).strip_edges()
			if text.trim_prefix("-").length() > 18:
				return fallback
			return int(text)
		TYPE_BOOL:
			return int(value)
	return fallback


## Kanonik toplam merge sayısı (profil istatistiği; biçimsiz değer 0).
func total_merges() -> int:
	return maxi(_as_int(data.get("total_merges", 0)), 0)


## Round sonunda çağrılır. Toplam merge sayacını ilerletir ve hak edilen
## bonus sandık sayısını döner (GAME_DESIGN.md §5.2: her 75 merge'de bir).
## Merge başarımları (TASK/045) AYNI yazmada açılır.
func add_merges(count: int) -> int:
	if count <= 0:
		return 0
	# TASK/045: taban, Profil / XP göçü / başarımların okuduğu AYNI doğrulanmış değer.
	data["total_merges"] = total_merges() + count
	var pending: int = int(data.get("merges_since_bonus_chest", 0)) + count
	var chests: int = pending / ChestSystem.MERGES_PER_BONUS_CHEST
	data["merges_since_bonus_chest"] = pending % ChestSystem.MERGES_PER_BONUS_CHEST
	var unlocked: bool = not _unlock_satisfied_achievements().is_empty()
	save_game()
	if unlocked:
		player_meta_changed.emit()
	return chests


## Biçimsiz kayıt (sözlük değil / sayı değil) 0 yıldız okunur (TASK/045: yıldız
## başarımı ve XP göçü her yüklemede okur).
func stars_for_level(level_number: int) -> int:
	var all_stars: Variant = data.get("level_stars", {})
	if not all_stars is Dictionary:
		return 0
	return _safe_int((all_stars as Dictionary).get(str(level_number), 0), 0)


## Yıldız sadece yukarı gider — daha kötü bir tekrar oynayış eskisini silmez.
## Yıldız başarımları (TASK/045) AYNI yazmada açılır. `save = false`: `complete_level`
## ile aynı (round kaydına katlanır — XP'nin dayandığı yıldız farkı XP ile tek yazmada).
func record_stars(level_number: int, stars: int, save: bool = true) -> void:
	if stars <= stars_for_level(level_number):
		return
	var raw: Variant = data.get("level_stars", {})
	var all_stars: Dictionary = (raw as Dictionary).duplicate() if raw is Dictionary else {}
	all_stars[str(level_number)] = stars
	data["level_stars"] = all_stars
	var unlocked: bool = not _unlock_satisfied_achievements().is_empty()
	if save:
		save_game()
	if unlocked:
		player_meta_changed.emit()


# --- Oyuncu ilerlemesi (TASK/045 — GAME_DESIGN §5.9) ---
#
# Tek gerçek `player_xp` (seviye türetilir), monoton `unlocked_achievements`, doğrulanan
# `selected_title_id`. Kural katmanı saf: PlayerProgression (XP eğrisi / ödül / göç) ve
# AchievementCatalog (başarım + unvan). Burada yalnız doğrulanmış okuma ve mutasyon.
#
# Başarımlar kanonik istatistik DEĞİŞTİREN her transaction'ın KENDİ yazmasında açılır
# (merge / yıldız / level / koleksiyon: add_merges, record_stars, complete_level,
# grant_skin, purchase_skin_with_dough, günlük sandık) — ek disk yazması yok. XP yalnız
# `record_round_finished`'da. Yükleme göçü ve Profil'in uzlaştırması yalnız bellekte.

## Doğrulanmış kümülatif XP. Bozuk değer (negatif / metin / NaN / saçma büyük) kayıttaki
## gerçeklerden kurtarılır (bootstrap) — okuma YAZMAZ.
func player_xp() -> int:
	var xp: int = PlayerProgression.sanitize_xp(data.get("player_xp", 0))
	return xp if xp >= 0 else _bootstrap_xp()


## XP'den türetilir; SAKLANMAZ.
func player_level() -> int:
	return PlayerProgression.level_for_xp(player_xp())


## Açık başarımlar: yalnız katalogdaki id'ler, tekrarsız, açılma sırasıyla (bozuk öğe /
## bilinmeyen id yok sayılır). YAZMAZ.
func unlocked_achievements() -> Array[StringName]:
	var out: Array[StringName] = []
	var raw: Variant = data.get("unlocked_achievements", [])
	if not raw is Array:
		return out
	var scanned: int = 0
	for item: Variant in raw:
		scanned += 1
		if scanned > ACHIEVEMENTS_RAW_CAP:
			break
		if typeof(item) != TYPE_STRING and typeof(item) != TYPE_STRING_NAME:
			continue
		var id := StringName(String(item))
		if out.has(id) or not AchievementCatalog.is_known(id):
			continue
		out.append(id)
	return out


func is_achievement_unlocked(id: StringName) -> bool:
	return unlocked_achievements().has(id)


## Seçili unvan: bilinen ve AÇIK değilse varsayılan "birlestirici". YAZMAZ.
func selected_title_id() -> StringName:
	return AchievementCatalog.resolve_title(data.get("selected_title_id", ""), unlocked_achievements())


## Unvan seçimi — Profil'in unvan seçicisi. Yalnız bilinen + AÇIK ve şu an seçili
## OLMAYAN unvan TEK yazmayla kaydedilir; kilitli / bilinmeyen / aynı seçim hiçbir
## alanı değiştirmez ve diske yazmaz. Yeni açılan unvan asla otomatik seçilmez.
func select_title(id: StringName) -> TitleResult:
	if not AchievementCatalog.is_title(id):
		return TitleResult.UNKNOWN
	if not AchievementCatalog.is_title_unlocked(id, unlocked_achievements()):
		return TitleResult.LOCKED
	if selected_title_id() == id and String(data.get("selected_title_id", "")) == String(id):
		return TitleResult.ALREADY
	data["selected_title_id"] = String(id)
	save_game()
	player_meta_changed.emit()
	return TitleResult.SELECTED


## Güvenli yedek uzlaştırma (Profil açılışı, Main round kesinleşmeden önce): kanonik
## istatistiğin desteklediği ama listede olmayan başarımları BELLEKTE açar ve döner.
## DİSKE YAZMAZ, sinyal / kutlama yaymaz — sonraki doğal kayıt kalıcılaştırır.
## Monoton + idempotent: ikinci çağrı boş döner.
func reconcile_achievements() -> Array[StringName]:
	return _unlock_satisfied_achievements()


## Başarım değerlendirmesinin kanonik girdileri (PlayerProfile ile AYNI kaynaklar —
## kopya sayaç yok): toplam merge, 10 level'daki kalıcı yıldız toplamı, tamamlanan
## sabit level, sahip olunan katalog Squishy'si.
func progression_stats() -> Dictionary:
	return {
		AchievementCatalog.METRIC_MERGES: total_merges(),
		AchievementCatalog.METRIC_STARS: PlayerProfile.total_stars(),
		AchievementCatalog.METRIC_LEVELS: PlayerProfile.completed_levels(),
		AchievementCatalog.METRIC_COLLECTION: PlayerProfile.collection_count(),
	}


## Kayıttaki gerçeklerin kanıtladığı XP (göç + bozuk XP kurtarma).
func _bootstrap_xp() -> int:
	return PlayerProgression.bootstrap_xp(total_merges(), PlayerProfile.total_stars(),
		PlayerProfile.completed_levels())


## Desteklenen yeni başarımları listenin SONUNA ekler (yalnız bellek); eklenenleri döner.
func _unlock_satisfied_achievements() -> Array[StringName]:
	var current: Array[StringName] = unlocked_achievements()
	var fresh: Array[StringName] = AchievementCatalog.newly_satisfied(progression_stats(), current)
	if not fresh.is_empty():
		current.append_array(fresh)
		_store_achievement_ids(current)
	return fresh


func _store_achievement_ids(ids: Array[StringName]) -> void:
	var raw: Array = []
	for id in ids:
		raw.append(String(id))
	data["unlocked_achievements"] = raw


# --- Güç envanteri (M8.5-03) ---
#
# Stoklar round'lar arasında kalıcı. Başlangıç hediyesi KAYIT BAŞINA BİR KEZ:
# `powerup_starter_granted` bayrağı hem yeni kayıtta hem eski kayıtların
# migration'ında hediyeyi tek sefere kilitliyor. Her açılışta yeniden
# verilmiyor.

## Başlangıç stoğunu bir kez verir. load_game'in iki dalından da çağrılıyor
## (dosya yok = yeni oyuncu, dosya var = eski kayıt migration'ı).
func _grant_starter_powerups() -> void:
	if bool(data.get("powerup_starter_granted", false)):
		return
	var stock: Dictionary = _powerup_stock().duplicate()
	for type in PowerUp.all():
		var key: String = PowerUp.save_key(type)
		stock[key] = int(stock.get(key, 0)) + PowerUp.STARTER_COUNT
	data["powerups"] = stock
	data["powerup_starter_granted"] = true
	save_game()


func _powerup_stock() -> Dictionary:
	var raw: Variant = data.get("powerups", {})
	return raw if raw is Dictionary else {}


func powerup_count(type: PowerUp.Type) -> int:
	return int(_powerup_stock().get(PowerUp.save_key(type), 0))


func has_powerup(type: PowerUp.Type) -> bool:
	return powerup_count(type) > 0


func grant_powerup(type: PowerUp.Type, amount: int = 1) -> void:
	if amount <= 0:
		return
	var stock: Dictionary = _powerup_stock().duplicate()
	var key: String = PowerUp.save_key(type)
	stock[key] = int(stock.get(key, 0)) + amount
	data["powerups"] = stock
	save_game()


## Stok düşürür. Yetmiyorsa HİÇBİR ŞEY yapmaz ve false döner — envanter asla
## negatife inemez. Çağıran taraf yalnızca efekt gerçekten gerçekleştiğinde
## çağırmalı (GAME_DESIGN.md §10: "başarılı kullanımda tüketim").
func consume_powerup(type: PowerUp.Type, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	var current: int = powerup_count(type)
	if current < amount:
		return false
	var stock: Dictionary = _powerup_stock().duplicate()
	stock[PowerUp.save_key(type)] = current - amount
	data["powerups"] = stock
	save_game()
	return true


# --- Satın alma işlemleri (M8.5-05) ---
#
# ORTAK KURAL: bir satın alma "para düş" + "ödülü ver" adımlarının İKİSİNİ
# birden, TEK `save_game()` ile yazar. Ayrı ayrı yazılsaydı (eski Shop
# davranışı: spend_dough() sonra grant_skin()) aradaki bir çökme Hamur'u
# yakıp ödülü vermeyebilirdi.
#
# Buradaki kural uygulama seviyesindeki "yarım işlem" penceresi: bellekteki
# durum tek seferde tutarlı hale getiriliyor ve tek seferde diske iniyor.
# Dosya seviyesi (TASK/045.1): o tek yazma da SaveFile işlemiyle — kanonik
# kayıt ya eski ya yeni haliyle, hiçbir zaman yarım yazılmış olarak kalmaz.

## Hamur ile güç satın alır (GAME_DESIGN.md §5.7).
##
## Dönüş: başarılıysa true. Hamur yetmiyorsa, amount <= 0 ise ya da tip
## geçersizse HİÇBİR alan değişmez ve diske yazma DA olmaz.
func purchase_powerup_with_dough(type: PowerUp.Type, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	if not PowerUp.is_valid_type(type):
		return false
	var cost: int = PowerUpEconomy.price(type) * amount
	if dough() < cost:
		return false

	# İki mutasyon, tek yazma.
	var stock: Dictionary = _powerup_stock().duplicate()
	var key: String = PowerUp.save_key(type)
	stock[key] = int(stock.get(key, 0)) + amount
	data["powerups"] = stock
	data["dough"] = dough() - cost
	save_game()
	return true


## Bugün BU güç için kaç başarılı ödüllü refill verildi (TASK/060: güç başına sayaç).
##
## Gün değiştiyse 0 döner ve KAYDA YAZMAZ: okuma sırasında beklenmedik disk yazması olmasın (profile_showcase ile
## aynı yaklaşım). Kalıcı sıfırlama bir sonraki başarılı grant'te. Bozuk blok / sayaç → kapalı (RewardedPolicy).
func rewarded_power_grants_today(type: PowerUp.Type, today: String) -> int:
	if not PowerUp.is_valid_type(type):
		return RewardedPolicy.DAILY_GRANTS_PER_POWER
	return RewardedPolicy.used_today(data.get(KEY_REWARDED_QUOTA), type, today)


## Kayıttaki kota bloğunun doğrulanmış kopyası (testler / teşhis; yazmaz).
func rewarded_power_quota() -> Dictionary:
	var block: Variant = data.get(KEY_REWARDED_QUOTA)
	return (block as Dictionary).duplicate(true) if block is Dictionary else {}


## Ödüllü reklam ödülü (TASK/060): YALNIZ bu güçten +1 ve YALNIZ bu gücün bugünkü sayacı +1 (+ gün), TEK transaction.
##
## Kota kontrolü BURADA yapılıyor (çağıranın ayrıca kontrol etmesine güvenilmiyor) — stale / duplicate bir callback
## kota dolmuşken stok veremez; bir gücün dolu kotası diğer güçleri etkilemez.
##
## Dönüş: verildiyse true. O gücün kotası doluysa, gün belirsizse ya da tip geçersizse hiçbir alan değişmez ve diske
## yazma da olmaz.
func grant_rewarded_powerup(type: PowerUp.Type, today: String) -> bool:
	if not PowerUp.is_valid_type(type):
		return false
	var next: Dictionary = RewardedPolicy.after_grant(data.get(KEY_REWARDED_QUOTA), type, today)
	if next.is_empty():
		return false

	# İki mutasyon (stok + kota bloğu), tek yazma.
	var stock: Dictionary = _powerup_stock().duplicate()
	var key: String = PowerUp.save_key(type)
	stock[key] = int(stock.get(key, 0)) + 1
	data["powerups"] = stock
	data[KEY_REWARDED_QUOTA] = next
	save_game()
	return true


## Hamur ile skin satın alır. Aynı transactional kural: tek yazma.
##
## Dönüş: başarılıysa true. Sahip olunan skin, tanımsız id ya da yetersiz
## Hamur durumunda hiçbir şey değişmez.
func purchase_skin_with_dough(id: StringName, cost: int) -> bool:
	if cost < 0 or owns_skin(id):
		return false
	if dough() < cost:
		return false

	var owned: Array = owned_skins().duplicate()
	owned.append(String(id))
	data["unlocked_skins"] = owned
	data["dough"] = dough() - cost
	# Koleksiyon başarımları (TASK/045) aynı transaction'da — ekonomi aynen.
	var unlocked: bool = not _unlock_satisfied_achievements().is_empty()
	save_game()
	skin_granted.emit(id)
	if unlocked:
		player_meta_changed.emit()
	return true


# --- Günlük giriş (M5) ---

func daily_streak() -> int:
	return int(data.get("daily_streak", 0))


func last_login_date() -> String:
	return String(data.get("last_login_date", ""))


func record_daily_login(date: String, streak: int) -> void:
	data["last_login_date"] = date
	data["daily_streak"] = streak
	save_game()


# --- Ayarlar (M8.5-10) ---

func sfx_enabled() -> bool:
	return bool(data.get("sfx_enabled", true))


## Kaydeder ve AudioManager'a uygular — ayarın tek yazma noktası.
func set_sfx_enabled(enabled: bool) -> void:
	data["sfx_enabled"] = enabled
	AudioManager.set_sfx_enabled(enabled)
	save_game()


func haptics_enabled() -> bool:
	return bool(data.get("haptics_enabled", true))


## Kaydeder ve Haptics'e uygular — ayarın tek yazma noktası (M8.5-15).
func set_haptics_enabled(enabled: bool) -> void:
	data["haptics_enabled"] = enabled
	Haptics.set_enabled(enabled)
	save_game()


# --- Onboarding dikişi (M8.9-02; tutorial M8.10) ---

func onboarding_completed() -> bool:
	return bool(data.get("onboarding_completed", false))


## Tutorial'ın tamamlandığı yerel gün (YYYY-MM-DD) ya da boş — bkz.
## DEFAULT_DATA notu ve `Onboarding.daily_rewards_unlocked()`.
func onboarding_completed_day() -> String:
	return String(data.get("onboarding_completed_day", ""))


## Tutorial bitti (ya da atlandı): TEK yazma, geri alınmaz, idempotent —
## zaten true ise hiçbir alan değişmez ve diske yazma DA olmaz (§26).
##
## `day_key` verilirse (M8.10 tutorial akışı) tamamlanma günü AYNI
## transaction'da yazılır; ayrıca o gün `last_seen_day_key` olarak da
## işlenir — böylece ilk gün kuralı ile saat geri alma koruması aynı
## efektif günü görür (tutorial'dan hemen sonra saati geri almak günlük
## sistemi "yeni gün" gibi açamaz). `day_key` boş bırakılırsa yalnız
## bayrak yazılır: M8.10 ÖNCESİ sözleşme (testler / eski çağrılar) ve
## "yerleşik oyuncu" semantiği (bastırma yok) korunur.
func complete_onboarding(day_key: String = "") -> void:
	if onboarding_completed():
		return
	data["onboarding_completed"] = true
	if not day_key.is_empty():
		data["onboarding_completed_day"] = day_key
		var raw: Dictionary = _daily_raw()
		if day_key > String(raw["last_seen_day_key"]):
			raw["last_seen_day_key"] = day_key
			data["daily_rewards"] = raw
	save_game()


# --- Yaş bandı (TASK/043 — docs/monetization/AGE_BAND_ROUTING.md) ---
#
# Doğrulama, geçişler ve reklam rotası AgeGate'te (saf; bozuk değer -> UNKNOWN, ASLA
# ADULT). Burada yalnız okuma / tek-yazma. Doğum tarihi parametresi HİÇBİR yerde yok.

func age_ad_band_raw() -> Variant:
	return data.get("age_ad_band", "UNKNOWN")


func next_age_transition_raw() -> Variant:
	return data.get("next_age_transition_date", "")


## Kayıttaki bant (yazmaz). Bozuk kayıt -> UNKNOWN.
func stored_age_band(on_day: Dictionary) -> int:
	return int(AgeGate.resolve_stored(age_ad_band_raw(), next_age_transition_raw(), on_day)["band"])


## Soğuk açılış (Main._ready, reklam yöneticisi SDK'ya dokunmadan ÖNCE): kaydı doğrular,
## geçişi (18. yaş günü -> ADULT) TEK yazmayla kalıcılaştırır, bandı döner. Bozuk kayıt ->
## UNKNOWN, yazma YOK (bir sonraki giriş üzerine yazar). Eski UNDER_13 (TASK/046.1) -> UNKNOWN,
## TEK yazmayla "UNKNOWN" + tarih boş (13. yaş günü silinir; ilerleme aynen).
func resolve_age_band_at_launch(on_day: Dictionary) -> int:
	var result: Dictionary = AgeGate.resolve_stored(age_ad_band_raw(), next_age_transition_raw(), on_day)
	if bool(result["changed"]):
		store_age_band(int(result["band"]), String(result["transition"]))
	elif bool(result.get("legacy_under_13", false)):
		# TASK/046.1: eski UNDER_13 → UNKNOWN + tarih boş, TEK yazma (`.bak` de atılır): artık
		# okunmayan 13. yaş günü (doğum gününe eşdeğer) kayıtta kalmaz. Dönüşüm DEĞİL — yaş
		# yeniden sorulur, reklam yok, ilerleme aynen.
		store_age_band(AgeGate.Band.UNKNOWN, "")
	return int(result["band"])


## Yaş ekranının sonucu ya da soğuk açılış geçişi: iki alan, TEK yazma. Yalnız türetilmiş
## bant + (TEEN için) 18. yaş günü; ADULT / UNKNOWN'da tarih boş.
func store_age_band(band: int, transition: String) -> void:
	var pair: Array[String] = AgeGate.stored_pair(band, transition)
	# `.bak`'tan kurtarılan oturumda bellekteki tarih bilerek boşaltıldı, ama `.bak` o kuşağın
	# geçiş gününü hâlâ taşıyabilir (bozuk kanonik döndürülmeden ezilir) — tarihli sayılır.
	var had_date: bool = (not String(data.get("next_age_transition_date", "")).is_empty()
		or _load_source == SaveFile.Source.BACKUP)
	# TASK/046.1: eski UNDER_13'ün 13. yaş günü (bellekte hâlâ UNDER_13 ise) ya da `.bak`'tan
	# kurtarılmış oturumun eski kuşağı (bellek UNKNOWN'a zorlanmış, `.bak` eski bandı + tarihi
	# taşıyabilir) yeni girişten sonra `.bak` kopyasında da kalmaz.
	var drop_old_generation: bool = str(data.get("age_ad_band", "")) == "UNDER_13" \
		or _load_source == SaveFile.Source.BACKUP
	data["age_ad_band"] = pair[0]
	data["next_age_transition_date"] = pair[1]
	# TASK/045.1: geçiş günü (doğum gününe eşdeğer) silinince bir önceki kayıt kopyası (`.bak`)
	# da atılır — "ADULT olunca silinir" sözü o kopya için de geçerli.
	if save_game() and had_date and (pair[1].is_empty() or drop_old_generation):
		SaveFile.discard_backup(save_path)


# --- Günlük ödüller (M8.9-02 — docs/monetization/DAILY_REWARDS.md) ---
#
# Dört bağımsız kota ailesi: ücretsiz sandık (1/gün), reklamlı sandık (2/gün,
# BAŞARILI ödül), reklamlı +150 Hamur (1/gün, BAŞARILI ödül); mevcut ödüllü
# güç refill'i (1/gün, dört gücün toplamı, yukarıda) ve devam hakkı (2/round,
# board) bunlardan tamamen ayrı. Hiçbiri diğerinin kotasını tüketmez.
#
# Her grant TEK transaction: kota kontrolü BURADA (çağıranın kontrolüne
# güvenilmez — stale/duplicate callback dolu kotada ödül veremez), kota +
# Hamur + skin tek `save_game()` ile diske iner.

const DAILY_REWARDS_DEFAULT: Dictionary = {
	"day_key": "", "free_chest_claimed": false, "ad_chests_claimed": 0,
	"dough_ad_claimed": false, "popup_seen_day": "", "last_seen_day_key": "",
}


func _daily_raw() -> Dictionary:
	var raw: Variant = data.get("daily_rewards", {})
	var out: Dictionary = DAILY_REWARDS_DEFAULT.duplicate()
	if raw is Dictionary:
		for key: String in raw:
			out[key] = raw[key]
	return out


## `day_key` gününün durumu (yalnız OKUR). Kayıttaki gün başka bir günse
## sayaçlar sıfır döner ve diske yazılmaz.
func daily_rewards_state(day_key: String) -> Dictionary:
	var raw: Dictionary = _daily_raw()
	var same_day: bool = String(raw["day_key"]) == day_key
	return {
		"day_key": day_key,
		"free_chest_claimed": bool(raw["free_chest_claimed"]) if same_day else false,
		"ad_chests_claimed": int(raw["ad_chests_claimed"]) if same_day else 0,
		"dough_ad_claimed": bool(raw["dough_ad_claimed"]) if same_day else false,
		"popup_seen_day": String(raw["popup_seen_day"]),
		"last_seen_day_key": String(raw["last_seen_day_key"]),
	}


## Kayıttaki günü `day_key`'e taşır (sayaçlar sıfırdan); aynı günse dokunmaz.
## Yalnız transaction'lar çağırır — diske onlar yazar.
func _daily_for_write(day_key: String) -> Dictionary:
	var raw: Dictionary = _daily_raw()
	if String(raw["day_key"]) != day_key:
		raw["day_key"] = day_key
		raw["free_chest_claimed"] = false
		raw["ad_chests_claimed"] = 0
		raw["dough_ad_claimed"] = false
	return raw


func daily_last_seen_day_key() -> String:
	return String(_daily_raw()["last_seen_day_key"])


## Görülen en yeni gün (saat geri alma koruması). Yalnız ileri gider.
func record_daily_last_seen_day(day_key: String) -> void:
	var raw: Dictionary = _daily_raw()
	if day_key <= String(raw["last_seen_day_key"]):
		return
	raw["last_seen_day_key"] = day_key
	data["daily_rewards"] = raw
	save_game()


func daily_popup_seen_day() -> String:
	return String(_daily_raw()["popup_seen_day"])


## Otomatik günlük pencere bugün gösterildi — ödül TÜKETMEZ, yalnız işaret.
func mark_daily_popup_seen(day_key: String) -> void:
	var raw: Dictionary = _daily_raw()
	if String(raw["popup_seen_day"]) == day_key:
		return
	raw["popup_seen_day"] = day_key
	data["daily_rewards"] = raw
	save_game()


## Ücretsiz günlük sandık: kota (1/gün) + Hamur + (varsa) skin, TEK yazma.
## Dönüş: verildiyse true; o gün zaten alınmışsa hiçbir alan değişmez.
func claim_daily_free_chest(day_key: String, dough_amount: int, skin_id: StringName) -> bool:
	var raw: Dictionary = _daily_for_write(day_key)
	if bool(raw["free_chest_claimed"]):
		return false
	raw["free_chest_claimed"] = true
	_apply_daily_chest(raw, dough_amount, skin_id)
	return true


## Reklamlı günlük sandık (BAŞARILI ödül callback'i): kota (`cap`/gün) + Hamur
## + (varsa) skin, TEK yazma. Kota doluysa hiçbir alan değişmez
## (stale/duplicate callback koruması).
func grant_daily_ad_chest(day_key: String, dough_amount: int, skin_id: StringName, cap: int) -> bool:
	var raw: Dictionary = _daily_for_write(day_key)
	if int(raw["ad_chests_claimed"]) >= cap:
		return false
	raw["ad_chests_claimed"] = int(raw["ad_chests_claimed"]) + 1
	_apply_daily_chest(raw, dough_amount, skin_id)
	return true


## Reklamlı günlük Hamur (BAŞARILI ödül callback'i): kota (1/gün) + Hamur,
## TEK yazma.
func grant_daily_ad_dough(day_key: String, amount: int) -> bool:
	var raw: Dictionary = _daily_for_write(day_key)
	if bool(raw["dough_ad_claimed"]) or amount <= 0:
		return false
	raw["dough_ad_claimed"] = true
	data["daily_rewards"] = raw
	data["dough"] = dough() + amount
	save_game()
	return true


## Sandık içeriğini kayda işler ve diske yazar (çağıran kota alanını zaten
## güncelledi). Skin sahiplik kontrolü: zaten sahip olunan id verilmez.
func _apply_daily_chest(raw: Dictionary, dough_amount: int, skin_id: StringName) -> void:
	data["daily_rewards"] = raw
	data["dough"] = dough() + maxi(dough_amount, 0)
	var granted_skin: bool = false
	if skin_id != &"" and not owns_skin(skin_id):
		var owned: Array = owned_skins().duplicate()
		owned.append(String(skin_id))
		data["unlocked_skins"] = owned
		granted_skin = true
	# Koleksiyon başarımları (TASK/045) aynı transaction'da (ücretsiz + reklamlı sandık).
	var unlocked: bool = not _unlock_satisfied_achievements().is_empty()
	save_game()
	if granted_skin:
		skin_granted.emit(skin_id)
	if unlocked:
		player_meta_changed.emit()
