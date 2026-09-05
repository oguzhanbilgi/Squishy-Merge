class_name DailyReward
extends RefCounted
## Günlük giriş ödülü ve ardışık gün sayacı (GAME_DESIGN.md §5.4).
## Sabit ödül, seri kırılınca sayaç sıfırlanır. v1'de Hamur'un harcanacağı
## bir yer yok — bu sadece bir sayaç/gösterge, shop v1.1'de.

## GEÇİCİ değer — §5.2'deki Hamur oranlarıyla aynı gerekçe: v1.1 shop
## ekonomisi tasarlanınca gerçek bir değere göre revize edilecek.
const DAILY_DOUGH: int = 15


## Bugün ilk giriş ise ödülü verir ve seriyi ilerletir.
## Döner: {claimed, streak, reward, streak_broken}
static func claim_if_new_day() -> Dictionary:
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
