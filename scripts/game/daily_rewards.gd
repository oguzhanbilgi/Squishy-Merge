class_name DailyRewards
extends RefCounted
## GÜNLÜK ÖDÜLLER modelinin TEK yetkili noktası (M8.9-02, owner kararı —
## docs/monetization/DAILY_REWARDS.md). Tarih/kota kontrolü UI düğümlerine
## dağılmaz; pencere ve Mağaza kartı yalnız `state()`'i okur, ödül yalnız
## buradaki transaction'larla verilir.
##
## Üç günlük sistem, her biri AYRI kota (yerel takvim gününe göre):
##   ÜCRETSİZ SANDIK     günde 1, reklam yok            → claim_free_chest()
##   REKLAMLI SANDIK     günde 2 BAŞARILI ödül          → grant_ad_chest()
##   REKLAMLI +150 HAMUR günde 1 BAŞARILI ödül          → grant_ad_dough()
## Mevcut ödüllü güç refill'i (RewardedPolicy, 1/gün dört gücün toplamı) ve
## devam hakkı (2/round, board) bunlardan TAMAMEN bağımsızdır.
##
## Reklamlı ödüller YALNIZ SDK'nın "ödül kazanıldı" callback'iyle
## (Main.grant_daily_chest / grant_daily_dough → burası) verilir; talep,
## iptal, kapanış, yükleme/gösterim hatası kota TÜKETMEZ.
##
## GÜN ANAHTARI: cihazın yerel takvim tarihi (YYYY-MM-DD). Kayıt görülen en
## yeni günü tutar (`last_seen_day_key`); saat GERİYE alınırsa efektif gün o
## en yeni gün kalır (yeni ödül üretilmez), tarih yetişince normale döner.
## Saati İLERİ almak çevrimdışı yerel kayıtta engellenemez (sunucu yok) —
## günlük giriş ödülü ve refill kotasıyla aynı bilinçli kabul (§7).
##
## Sonuç ödülü transaction ANINDA belirlenir ve kayda işlenir; pencere
## animasyonu sonradan oynar. Uygulama animasyon bitmeden kapansa da ödül
## tam bir kez verilmiş olur.
##
## ONBOARDING / İLK GÜN KAPISI (M8.10): `Onboarding.daily_rewards_unlocked()`
## false iken (tutorial bitmedi YA DA tutorial'ın bitirildiği takvim günü)
## ÜÇ transaction da no-op döner ve otomatik pencere "due" olmaz. Kapı UI'da
## değil BURADA: pencere bir şekilde açılsa bile ödül verilemez
## (docs/TUTORIAL_SYSTEM.md §5).

const FREE_CHESTS_PER_DAY: int = 1
const AD_CHESTS_PER_DAY: int = 2
const AD_DOUGH_PER_DAY: int = 1
const AD_DOUGH_AMOUNT: int = 150

## Test kancası: boş değilse "bugün" bu tarihtir (YYYY-MM-DD).
static var clock_override: String = ""
## Test kancası: harness'ler otomatik günlük pencereyi kapatır (production
## her zaman true; yalnız `popup_due` okur).
static var auto_popup_enabled: bool = true
## Kura RNG'si: global RNG'ye (drop bag) DOKUNULMAZ; testler seed verir.
static var _rng: RandomNumberGenerator = null


static func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


static func _rng_instance() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng


# --- Gün ---------------------------------------------------------------------------

## Cihazın yerel takvim tarihi (YYYY-MM-DD).
static func today_local() -> String:
	if not clock_override.is_empty():
		return clock_override
	return Time.get_date_string_from_system()


## Efektif gün anahtarı: bugün, ama görülen en yeni günden GERİ gitmez.
static func day_key() -> String:
	var today: String = today_local()
	var last: String = SaveManager.daily_last_seen_day_key()
	return last if (not last.is_empty() and today < last) else today


## Saat görülen en yeni günün gerisinde mi (geri alınmış / saat dilimi)?
static func is_clock_behind() -> bool:
	var last: String = SaveManager.daily_last_seen_day_key()
	return not last.is_empty() and today_local() < last


## Yeni bir gün görüldüyse kayda işler (tek yazma, yalnız ileri). Main açılışta
## ve öne dönüşte çağırır. Dönüş: efektif gün anahtarı.
static func observe_day() -> String:
	var today: String = today_local()
	if today > SaveManager.daily_last_seen_day_key():
		SaveManager.record_daily_last_seen_day(today)
	return day_key()


# --- Durum (yalnız okur) ----------------------------------------------------------------

## Pencere / Mağaza kartı için tam durum. Anahtarlar: day_key,
## free_chest_claimed, ad_chests_claimed, dough_ad_claimed, popup_seen_day,
## free_chest_available, ad_chests_remaining, ad_dough_available,
## remaining_total (üç sistemde kalan ödül sayısı), all_done, clock_behind.
static func state() -> Dictionary:
	var key: String = day_key()
	var s: Dictionary = SaveManager.daily_rewards_state(key)
	s["free_chest_available"] = not bool(s["free_chest_claimed"])
	s["ad_chests_remaining"] = maxi(0, AD_CHESTS_PER_DAY - int(s["ad_chests_claimed"]))
	s["ad_dough_available"] = not bool(s["dough_ad_claimed"])
	s["remaining_total"] = (1 if s["free_chest_available"] else 0) \
		+ int(s["ad_chests_remaining"]) + (1 if s["ad_dough_available"] else 0)
	s["all_done"] = int(s["remaining_total"]) == 0
	s["clock_behind"] = is_clock_behind()
	return s


static func free_chest_available() -> bool:
	return not bool(SaveManager.daily_rewards_state(day_key())["free_chest_claimed"])


static func ad_chests_remaining() -> int:
	return maxi(0, AD_CHESTS_PER_DAY - int(SaveManager.daily_rewards_state(day_key())["ad_chests_claimed"]))


static func ad_dough_available() -> bool:
	return not bool(SaveManager.daily_rewards_state(day_key())["dough_ad_claimed"])


## Otomatik pencere bugün henüz gösterilmedi mi? Günlük sistem kilitliyken
## (onboarding / ilk gün) ASLA. Main ayrıca kabuk/pencere koşullarına bakar.
static func popup_due() -> bool:
	if not Onboarding.daily_rewards_unlocked():
		return false
	return auto_popup_enabled and SaveManager.daily_popup_seen_day() != day_key()


static func mark_popup_seen() -> void:
	SaveManager.mark_daily_popup_seen(day_key())


# --- Transaction'lar --------------------------------------------------------------------

## Ücretsiz sandık: kota var → kura → kayıt (tek yazma) → değişmez sonuç.
## Kota yoksa null; hiçbir şey değişmez. Çift dokunuş: ikinci çağrı null.
static func claim_free_chest() -> DailyChestReward:
	if not Onboarding.daily_rewards_unlocked():
		return null
	var key: String = day_key()
	if bool(SaveManager.daily_rewards_state(key)["free_chest_claimed"]):
		return null
	var reward: DailyChestReward = DailyChestLoot.roll(_rng_instance(), SaveManager.owned_skins())
	reward.source = "free"
	reward.day_key = key
	if not SaveManager.claim_daily_free_chest(key, reward.dough(), reward.skin.id if reward.skin != null else &""):
		return null
	AdEvents.emit(&"daily_free_chest_claimed", {"day_key": key, "dough": reward.dough()})
	_emit_result(reward)
	return reward


## Reklamlı sandık — YALNIZ "ödül kazanıldı" callback'inden (Main). `day_key`
## talebin günü: eski güne ait geç callback (gün değişti) ödül vermez. Kota
## doluysa null; kayıt değişmez.
static func grant_ad_chest(request_day_key: String) -> DailyChestReward:
	if not Onboarding.daily_rewards_unlocked():
		return null
	var key: String = day_key()
	if request_day_key != key:
		return null
	if int(SaveManager.daily_rewards_state(key)["ad_chests_claimed"]) >= AD_CHESTS_PER_DAY:
		return null
	var reward: DailyChestReward = DailyChestLoot.roll(_rng_instance(), SaveManager.owned_skins())
	reward.source = "ad"
	reward.day_key = key
	if not SaveManager.grant_daily_ad_chest(key, reward.dough(),
			reward.skin.id if reward.skin != null else &"", AD_CHESTS_PER_DAY):
		return null
	AdEvents.emit(&"daily_ad_chest_earned", {"day_key": key, "dough": reward.dough(),
		"remaining": ad_chests_remaining()})
	_emit_result(reward)
	return reward


## Reklamlı +150 Hamur — YALNIZ "ödül kazanıldı" callback'inden (Main).
static func grant_ad_dough(request_day_key: String) -> bool:
	if not Onboarding.daily_rewards_unlocked():
		return false
	var key: String = day_key()
	if request_day_key != key:
		return false
	if not SaveManager.grant_daily_ad_dough(key, AD_DOUGH_AMOUNT):
		return false
	AdEvents.emit(&"daily_dough_earned", {"day_key": key, "dough": AD_DOUGH_AMOUNT})
	return true


static func _emit_result(reward: DailyChestReward) -> void:
	var ctx: Dictionary = {"day_key": reward.day_key, "source": reward.source,
		"dough": reward.dough(), "skin_rolled": reward.skin_rolled,
		"skin_exhausted": reward.skin_exhausted}
	if reward.skin != null:
		ctx["skin"] = String(reward.skin.id)
		ctx["rarity"] = SkinData.rarity_name(reward.rarity as SkinData.Rarity)
	elif reward.rarity >= 0:
		ctx["rarity"] = SkinData.rarity_name(reward.rarity as SkinData.Rarity)
	AdEvents.emit(&"daily_chest_result", ctx)
