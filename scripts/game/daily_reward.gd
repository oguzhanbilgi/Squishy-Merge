class_name DailyReward
extends RefCounted
## Günlük giriş ödülü ve ardışık gün sayacı (GAME_DESIGN.md §5.4).
## Sabit ödül, seri kırılınca sayaç sıfırlanır. Hamur mağazada harcanır
## (§5.6); bu ödül GÜNLÜK ÖDÜLLER'in (§5.4.1: ücretsiz sandık / reklamlı
## sandık / reklamlı +150) kotalarından tamamen AYRIDIR.
##
## M8.9-02.1: oyuncuya tek pencerede gösterilir (`DailyRewardsPopup` üst
## bölgesi: "N. GÜN · +15 HAMUR · ALINDI" + seri şeridi); pencere yalnız
## gösterir, ödülü YALNIZ `claim_if_new_day` (Main açılış / Günlük madalyonu
## / Mağaza kartı yolunda, açılıştan ÖNCE) yazar. ONBOARDING KAPISI
## (M8.10 — `Onboarding.daily_rewards_unlocked()`): tutorial bitmeden VE
## tutorial'ın bitirildiği takvim GÜNÜNDE bu sınıf kaydı HİÇ değiştirmez —
## ne Hamur ne seri ne tarih; gizli/geriye dönük ödül yok. İlk giriş işlemi
## tamamlanma gününden SONRAKİ ilk yerel günün ilk çalışmasında olur
## (docs/TUTORIAL_SYSTEM.md §5).

## GEÇİCİ değer — §5.2'deki Hamur oranlarıyla aynı gerekçe: v1.1 shop
## ekonomisi tasarlanınca gerçek bir değere göre revize edilecek.
const DAILY_DOUGH: int = 15


## Bugün ilk giriş ise ödülü verir ve seriyi ilerletir. Günlük sistem kapalıysa
## (onboarding bitmedi ya da tutorial günü, M8.10) hiçbir şey yapmaz — kayıt
## mutasyonu YOK. Döner: {claimed, streak, reward, streak_broken}
static func claim_if_new_day() -> Dictionary:
	if not Onboarding.daily_rewards_unlocked():
		return _result(false, SaveManager.daily_streak(), 0, false)
	var today: String = Time.get_date_string_from_system()
	var last: String = SaveManager.last_login_date()

	if last == today:
		return _result(false, SaveManager.daily_streak(), 0, false)

	var streak: int = 1
	var broken: bool = false

	if last != "":
		var elapsed_days: int = days_between(last, today)
		if elapsed_days == 1:
			streak = SaveManager.daily_streak() + 1
		elif elapsed_days > 1:
			# Seri kırıldı (GAME_DESIGN.md §5.4), sayaç sıfırdan başlar.
			broken = SaveManager.daily_streak() > 1
		else:
			# Cihaz saati geriye alınmış: ödül verme, kaydı da bozma.
			return _result(false, SaveManager.daily_streak(), 0, false)

	SaveManager.record_daily_login(today, streak)
	SaveManager.add_dough(DAILY_DOUGH)
	return _result(true, streak, DAILY_DOUGH, broken)


## Bugün ödül alınabilir mi? YALNIZCA okur — `claim_if_new_day` ile aynı
## kapılar (günlük sistem kapalı → hayır; aynı gün → hayır; saat geri alınmış
## → hayır). Ana Sayfa'daki Günlük madalyonunun bildirim noktası bunu
## gösterir (M8.6-03B).
static func is_claimable() -> bool:
	if not Onboarding.daily_rewards_unlocked():
		return false
	var today: String = Time.get_date_string_from_system()
	var last: String = SaveManager.last_login_date()
	if last == today:
		return false
	if last == "":
		return true
	return days_between(last, today) >= 1


## Bugünkü giriş ödülü zaten alınmış mı (yalnız okur; pencere durumu).
static func claimed_today() -> bool:
	return SaveManager.last_login_date() == Time.get_date_string_from_system()


## Pencere için görünüm (yalnız okur, kayda dokunmaz):
## {streak, reward, claimed_today, just_claimed=false, streak_broken=false}.
## Main "az önce alındı" bilgisini claim sonucundan ekler.
static func view() -> Dictionary:
	return {
		"streak": SaveManager.daily_streak(),
		"reward": DAILY_DOUGH,
		"claimed_today": claimed_today(),
		"just_claimed": false,
		"streak_broken": false,
	}


## İki "YYYY-MM-DD" tarihi arasındaki gün farkı.
static func days_between(from_date: String, to_date: String) -> int:
	var from_unix: int = Time.get_unix_time_from_datetime_string(from_date + "T00:00:00")
	var to_unix: int = Time.get_unix_time_from_datetime_string(to_date + "T00:00:00")
	return int(roundf(float(to_unix - from_unix) / 86400.0))


static func _result(claimed: bool, streak: int, reward: int, broken: bool) -> Dictionary:
	return {
		"claimed": claimed,
		"streak": streak,
		"reward": reward,
		"streak_broken": broken,
	}
