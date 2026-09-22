class_name Onboarding
extends RefCounted
## İlk açılış (onboarding / tutorial) durumunun TEK yetkili noktası (M8.10 —
## docs/TUTORIAL_SYSTEM.md). Kalıcılık SaveManager'da, akış
## TutorialController'da; "tamamlandı mı", "hangi gün tamamlandı" ve
## "günlük ödüller açıldı mı" sorularının cevabı YALNIZ burada.
##
## NEDEN AYRI BİR SINIF: ilk gün kuralı (§15) en az beş yüzeyi ilgilendiriyor
## (giriş ödülü, otomatik pencere, Ana Sayfa madalyonu, Mağaza bölümü,
## pencere içi kotalar). `today == onboarding_completed_day` karşılaştırması
## UI'lara dağılsaydı biri unutulurdu; hepsi `daily_rewards_unlocked()`
## okuyor.
##
## ÜRÜN KURALI (owner kararı, M8.10):
##   yeni oyuncu tutorial'ı bitirdiği TAKVİM GÜNÜ günlük ödül sistemi
##   KAPALIDIR — +15 giriş ödülü yok, seri ilerlemez, otomatik pencere
##   açılmaz, ücretsiz/reklamlı sandık ve +150 Hamur yok, Ana Sayfa
##   madalyonu ve Mağaza bölümü görünmez. Kaçırılan ödül SONRADAN da
##   verilmez (geriye dönük telafi yok). Ertesi yerel günde sistem
##   sıfırdan başlar: seri 1. gün, +15, tek otomatik pencere, tam kotalar.
##
## ESKİ KAYITLAR: `onboarding_completed` true ama `onboarding_completed_day`
## boşsa oyuncu "yerleşik" sayılır ve HİÇBİR bastırma uygulanmaz — bugünün
## tarihi UYDURULMAZ (§14). Mevcut gerçek oyuncuların günlük davranışı
## değişmez.

## Tutorial nasıl bitti (analitik bağlamı + `complete` çağrısının kaynağı).
const SOURCE_TUTORIAL: String = "tutorial"
const SOURCE_SKIP: String = "skip"


static func is_completed() -> bool:
	return SaveManager.onboarding_completed()


## Tutorial'ın tamamlandığı yerel takvim günü (YYYY-MM-DD), ya da boş:
## "tamamlanmadı" (onboarding false) ya da "eski/yerleşik kayıt" (§14).
static func completed_day() -> String:
	return SaveManager.onboarding_completed_day()


## Tutorial bitti/atlandı. TEK yazma, geri alınmaz, IDEMPOTENT: ikinci çağrı
## hiçbir alanı değiştirmez ve false döner (çift dokunuş / çift callback
## güvenliği, §26). Tamamlanma günü aynı transaction'da yazılır; gün
## anahtarı `DailyRewards.day_key()` (saat geri alma korumasıyla aynı
## efektif gün — ileride geri alınan saat ilk günü "geçmiş" yapamaz).
##
## `context`: olaya eklenecek ek bağlam (adım, süre) — tamamlanma olayı
## YALNIZ buradan yayılır, böylece çift çağrı ikinci bir olay üretemez.
##
## Dönüş: bu çağrı gerçekten tamamladıysa true.
static func complete(source: String = SOURCE_TUTORIAL, context: Dictionary = {}) -> bool:
	if SaveManager.onboarding_completed():
		return false
	var day: String = DailyRewards.day_key()
	SaveManager.complete_onboarding(day)
	var event: Dictionary = context.duplicate()
	event["day_key"] = day
	event["source"] = source
	TutorialEvents.emit(&"tutorial_skipped" if source == SOURCE_SKIP
		else &"tutorial_completed", event)
	return true


## GÜNLÜK ÖDÜLLER sistemi şu an açık mı? İlk gün kuralının TEK kapısı.
##
##   onboarding bitmedi                       -> kapalı (M8.9-02 davranışı)
##   tamamlanma günü boş (eski/yerleşik kayıt) -> AÇIK (bastırma yok, §14)
##   efektif gün <= tamamlanma günü           -> kapalı (ilk gün kuralı)
##   efektif gün  > tamamlanma günü           -> açık
##
## Efektif gün `DailyRewards.day_key()`: cihaz saati geri alınırsa görülen en
## yeni günün gerisine DÜŞMEZ, yani ertesi güne geçtikten sonra saati geri
## almak günlük sistemi yeniden kilitlemez (§17).
static func daily_rewards_unlocked() -> bool:
	if not SaveManager.onboarding_completed():
		return false
	var day: String = SaveManager.onboarding_completed_day()
	if day.is_empty():
		return true
	return DailyRewards.day_key() > day


## Bugün "tutorial gününde bastırma" yüzünden mi kapalı (pencere/rozet
## metinleri ayırt edebilsin diye; kayda dokunmaz).
static func is_first_day_suppressed() -> bool:
	if not SaveManager.onboarding_completed():
		return false
	var day: String = SaveManager.onboarding_completed_day()
	return not day.is_empty() and DailyRewards.day_key() <= day
