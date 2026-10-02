class_name DailyChallenge
extends RefCounted
## Günlük Merge Challenge V1 — oyuncuya "MEYDAN OKUMA" (TASK/047 — owner kararı, KİLİTLİ;
## GAME_DESIGN §5.11) — SAF model katmanı. Kayda YAZMAZ (tek transaction
## `SaveManager.complete_daily_challenge`); UI, reklam ve oyuncu ilerlemesi BİLMEZ.
##
##   Mod      Günde bir meydan okuma: hedef tier'ı sınırlı sayıda GERÇEK bırakışla oluştur.
##            Süre yok. Fizik / TierConfig / merge / T1–T3 havuzu / önizleme / taşma production.
##            Güç, devam, XP, görev, başarım, bonus sandık, yıldız, level / rekor / round
##            istatistiği YOK — izole mod (Main'in ayrı round-sonu yolu).
##   Preset   Haftanın gününe göre SABİT tablo (PRESETS) — üretilmez, otomatik ayarlanmaz.
##            Oynanabilir yükseklik her zaman 400.
##   Gün      Görevlerin kabul edilen günü (`Missions.accepted_day()` → `DailyRewards.day_key()`:
##            saat geri alınırsa görülen en yeni gün) — ayrı saat gerçeği YOK. Ayrıca kayıttaki
##            tamamlanma günü bir taban: meydan okuma hiçbir zaman ondan geriye gitmez.
##            Geçersiz gün → meydan okuma yok (gizli / reddedilir).
##   Dizi     `sequence_bag`: her 9'luk torba [1,1,1,2,2,2,3,3,3], SHA-256("sm-dc-v1|gün|torba")
##            baytlarıyla Fisher–Yates (j = 8..1, k = bayt[8 − j] % (j + 1)). Gün + torba
##            indeksinin SAF fonksiyonu: global RNG'ye dokunmaz, seed() yok, saklanan seed yok.
##   Ödül     Kabul edilen günün İLK başarısı: +20 Hamur, otomatik, günde en fazla bir kez.
##   Kayıt    `daily_challenge {version, completed_day_key}` — preset / hedef / bütçe / dizi /
##            deneme / en iyi sonuç / UI durumu SAKLANMAZ (türetilir ya da geçicidir).

## Kayıt bloğunun şema sürümü. Bilinmeyen sürüm `sanitize`'da varsayılan blok sayılır.
const VERSION: int = 1
## İlk başarının otomatik Hamur ödülü (kilitli). Yedi farklı günde en fazla 7 × 20 = 140.
const REWARD_DOUGH: int = 20
## Dizinin sürüm öneki — değişirse her günün dizisi değişir (owner onayı gerekir).
const SEQUENCE_PREFIX: String = "sm-dc-v1"
## Oynanabilir yükseklik (taban → taşma çizgisi), tüm level'larla aynı (GAME_DESIGN §3).
const PLAYABLE_HEIGHT: float = 400.0
## Meydan okuma LevelData'sının level numarası. YÖNLENDİRME BUNDAN ÇIKARILMAZ — Main açık round
## türünü (`RoundKind.DAILY_CHALLENGE`) kullanır; 0 hiçbir sabit level değildir.
const LEVEL_SENTINEL: int = 0
## Son izinli bırakıştan sonra yatışma (yalnız bitiş algılayıcı; oyuncu sayacı DEĞİL): bu kadar
## süre gerçek merge olmazsa ya da mutlak tavan dolarsa (hedef yoksa) "hamle bitti".
const SETTLE_QUIET_SEC: float = 1.5
const SETTLE_CAP_SEC: float = 5.0
## 9'luk torba: tier 1 / 2 / 3'ten üçer kopya (production DropBag ile aynı bileşim).
const BAG_TEMPLATE: Array[int] = [1, 1, 1, 2, 2, 2, 3, 3, 3]
const BAG_SIZE: int = 9

## Haftalık preset tablosu (KİLİTLİ), pazartesiden pazara. Değerler owner onayı olmadan değişmez.
const PRESETS: Array[Dictionary] = [
	{"target_tier": 5, "container_width": 600.0, "drop_budget": 18},
	{"target_tier": 5, "container_width": 480.0, "drop_budget": 16},
	{"target_tier": 6, "container_width": 600.0, "drop_budget": 38},
	{"target_tier": 5, "container_width": 420.0, "drop_budget": 15},
	{"target_tier": 6, "container_width": 540.0, "drop_budget": 36},
	{"target_tier": 6, "container_width": 480.0, "drop_budget": 32},
	{"target_tier": 6, "container_width": 420.0, "drop_budget": 30},
]

## Başarısızlık sebebi (board belirler, sonuç ekranı gösterir).
enum FailReason { NONE, OVERFLOW, MOVES_EXHAUSTED }

## Kayıt bloğu anahtarları.
const KEY_VERSION: String = "version"
const KEY_COMPLETED: String = "completed_day_key"

## Oyuncu dili (tek üretim dili Türkçe).
const TITLE: String = "MEYDAN OKUMA"
const GOAL_FORMAT: String = "%s yap · %d hamlede"
const SECONDS_PER_DAY: int = 86400


# --- Gün / preset ---------------------------------------------------------------------

## Günün hafta içi sırası: pazartesi 0 … pazar 6; geçersiz gün -1. Takvim tarihi UTC gece
## yarısı olarak çevrilir (saat dilimi / yaz saati kayması yok — `Missions.week_start` ile aynı).
static func weekday_index(day_key: String) -> int:
	if not Missions.is_day_key(day_key):
		return -1
	var unix: int = Time.get_unix_time_from_datetime_string(day_key + "T00:00:00")
	# Godot: 0 = pazar … 6 = cumartesi.
	return (int(Time.get_date_dict_from_unix_time(unix)["weekday"]) + 6) % 7


## Günün preset'i (kopya); geçersiz gün boş.
static func preset_for(day_key: String) -> Dictionary:
	var index: int = weekday_index(day_key)
	if index < 0:
		return {}
	return PRESETS[index].duplicate()


## Günün meydan okuma tanımı — SAF: day_key, weekday (0 = pazartesi), target_tier,
## container_width, drop_budget, playable_height. Geçersiz gün boş.
static func descriptor(day_key: String) -> Dictionary:
	var preset: Dictionary = preset_for(day_key)
	if preset.is_empty():
		return {}
	preset["day_key"] = day_key
	preset["weekday"] = weekday_index(day_key)
	preset["playable_height"] = PLAYABLE_HEIGHT
	return preset


## Meydan okumanın günü — SAF: kabul edilen gün, kayıttaki tamamlanma gününün GERİSİNE düşmez
## (geri alınan saat tamamlanmış bir günü yeniden açamaz). Kabul edilen gün geçersizse boş.
static func effective_day(accepted: String, completed: String) -> String:
	if not Missions.is_day_key(accepted):
		return ""
	if Missions.is_day_key(completed) and completed > accepted:
		return completed
	return accepted


## Kayıt bloğuna göre `day_key` tamamlanmış mı (o gün ya da daha eskisi) — SAF.
static func is_completed(block: Dictionary, day_key: String) -> bool:
	var completed: String = String(sanitize(block)[KEY_COMPLETED])
	return not completed.is_empty() and Missions.is_day_key(day_key) and day_key <= completed


## Bugünün meydan okumasının günü (kabul edilen gün + kayıttaki taban). Boş = gün gerçeği yok.
## Monoton gün: meydan okuma bir günü kabul ettiği AN (Ana Sayfa girişi, pencere, BAŞLA, tekrar, sonuç
## bu fonksiyondan okur) o gün GÜNLÜK ÖDÜLLER'in mevcut gözlem API'siyle kayda işlenir —
## `DailyRewards.observe_day()`: yalnız ileri, yalnız `last_seen_day_key`, açılış / öne dönüş yazmasının
## aynısı (ödül / seri / görev / pencere / onboarding YOK). Uygulama gece yarısını ön planda geçip saat
## geri alınınca meydan okuma kabul ettiği en yeni günün gerisine düşmez. Geçersiz saat kaydedilmez.
static func current_day() -> String:
	if Missions.is_day_key(DailyRewards.today_local()):
		DailyRewards.observe_day()
	return effective_day(Missions.accepted_day(), SaveManager.daily_challenge_completed_day())


## Ekranların okuduğu güncel görünüm: `descriptor` + completed (bool). Tek yazma `current_day`'in
## gün gözlemidir (yeni bir gün ilk kez görüldüğünde). Boş = meydan okuma yok (gün gerçeği yok) —
## giriş gizlenir, başlatma reddedilir.
static func current_view() -> Dictionary:
	var day: String = current_day()
	var view: Dictionary = descriptor(day)
	if view.is_empty():
		return {}
	view["completed"] = is_completed(SaveManager.daily_challenge_state(), day)
	return view


## Ana satır: "Büyük Dumpling yap · 18 hamlede" (hedef adı TierConfig'ten).
static func goal_text(view: Dictionary) -> String:
	if view.is_empty():
		return ""
	return GOAL_FORMAT % [TierConfig.tier_name(int(view["target_tier"])), int(view["drop_budget"])]


# --- Deterministik dizi ----------------------------------------------------------------

## `bag_index`. torbanın (0'dan) karılmış 9 parçası — SAF. Her torba tam 3 × T1, 3 × T2, 3 × T3.
static func sequence_bag(day_key: String, bag_index: int) -> Array[int]:
	var bag: Array[int] = BAG_TEMPLATE.duplicate()
	var digest: PackedByteArray = ("%s|%s|%d" % [SEQUENCE_PREFIX, day_key, bag_index]).sha256_buffer()
	var step: int = 0
	for j in range(BAG_SIZE - 1, 0, -1):
		var k: int = int(digest[step]) % (j + 1)
		step += 1
		var held: int = bag[j]
		bag[j] = bag[k]
		bag[k] = held
	return bag


## Dizinin ilk `count` parçası (torbalar art arda) — SAF.
static func sequence(day_key: String, count: int) -> Array[int]:
	var out: Array[int] = []
	var bag_index: int = 0
	while out.size() < count:
		out.append_array(sequence_bag(day_key, bag_index))
		bag_index += 1
	out.resize(maxi(count, 0))
	return out


## GameBoard'a verilen parça kaynağı — production DropBag'in arayüzü (`next_tier()`), ama
## rastgelelik YOK: dizinin sıradaki parçası. Her deneme yeni bir kaynak alır (baştan başlar).
class Sequence extends RefCounted:
	var day_key: String = ""
	var _bag: Array[int] = []
	var _bag_index: int = 0
	var _drawn: int = 0

	func _init(key: String) -> void:
		day_key = key

	func next_tier() -> int:
		if _bag.is_empty():
			_bag = DailyChallenge.sequence_bag(day_key, _bag_index)
			_bag_index += 1
		_drawn += 1
		return _bag.pop_front()

	## Kaynaktan çekilen parça sayısı (board önizleme için iki fazla çeker).
	func drawn() -> int:
		return _drawn


# --- LevelData ---------------------------------------------------------------------------

## Günün meydan okuma LevelData'sı — KODDA kurulur (resources/levels/ altında dosya YOK;
## LevelLibrary sabit level kütüphanesi kalır). Sonsuz değil, skor hedefi yok, level numarası
## LEVEL_SENTINEL. Geçersiz gün null.
static func make_level(day_key: String) -> LevelData:
	var view: Dictionary = descriptor(day_key)
	if view.is_empty():
		return null
	var level := LevelData.new()
	level.level_number = LEVEL_SENTINEL
	level.target_tier = int(view["target_tier"])
	level.target_score = 0
	level.container_width = float(view["container_width"])
	level.playable_height = PLAYABLE_HEIGHT
	level.is_endless = false
	return level


# --- Kayıt bloğu (SAF) -------------------------------------------------------------------

static func default_block() -> Dictionary:
	return {KEY_VERSION: VERSION, KEY_COMPLETED: ""}


## Kayıttaki ham bloğu güvenli biçime indirir — SAF, deterministik. Sözlük değil / bilinmeyen
## sürüm / geçersiz gün → varsayılan (tamamlanma yok); fazla anahtarlar düşer.
static func sanitize(raw: Variant) -> Dictionary:
	var out: Dictionary = default_block()
	if not raw is Dictionary:
		return out
	var src: Dictionary = raw
	if not _is_current_version(src.get(KEY_VERSION)):
		return out
	var completed: Variant = src.get(KEY_COMPLETED)
	if Missions.is_day_key(completed):
		out[KEY_COMPLETED] = String(completed)
	return out


## `day_key` gününün ilk başarısı ödül alabilir mi — SAF: gün geçerli ve kayıttaki tamamlanma
## gününden YENİ (aynı ya da eski gün → hayır; geri alınan saat ikinci ödül üretemez).
static func can_complete(block: Dictionary, day_key: String) -> bool:
	if not Missions.is_day_key(day_key):
		return false
	var completed: String = String(sanitize(block)[KEY_COMPLETED])
	return completed.is_empty() or day_key > completed


static func _is_current_version(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return value == VERSION
		TYPE_FLOAT:
			return value == float(VERSION)
	return false
