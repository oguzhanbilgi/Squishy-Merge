class_name RewardedPolicy
extends RefCounted
## Ödüllü reklamla güç refill politikasının TEK tanım noktası (GAME_DESIGN.md §5.7.3).
##
## KİLİTLİ KURALLAR (TASK/060 — Product Vision V3 Issue #1 §3, owner kararı):
##
##   - Kota **güç BAŞINA**: her güç için günde en çok DAILY_GRANTS_PER_POWER (2) başarılı ödül. Dört güç dört
##     BAĞIMSIZ sayaç — birinde 2/2 olması diğerlerini kapatmaz (teorik tavan 4 × 2 = 8 / gün; yalnız hak VE
##     stok-0 refill koşulu gerçekleşirse).
##   - Her doğrulanmış "ödül kazanıldı" → YALNIZ ilgili güçten +1 ve YALNIZ o gücün sayacı +1, TEK kayıt yazması.
##   - Kotayı yalnızca **başarılı reward grant** tüketir. Reklam isteği, açılması, yüklenememesi, gösterim, tıklama
##     ve ödülsüz kapanması TÜKETMEZ (`ad closed != reward earned`, §11.2).
##   - Gün = kabul edilen yerel gün (`Missions.accepted_day()` = `DailyRewards.day_key()`: görülen en yeni günden
##     geri gitmez — Günlük / Görevler / Meydan Okuma ile aynı). Yeni gün dört sayacı sıfırlar (okumada 0; kalıcı
##     sıfırlama bir sonraki başarılı grant'te). Round değişimi ve uygulama yeniden başlatması sıfırlamaz.
##   - Revive hakları (§11), günlük reklamlı sandık / +150 Hamur (§5.4.1) bu kotadan TAMAMEN BAĞIMSIZDIR.
##
## Kayıt bloğu (`SaveManager.data["rewarded_power_quota"]`):
##   {"version": 1, "day_key": "YYYY-MM-DD" | "", "grants": {PowerUp.SAVE_KEYS → 0..DAILY_GRANTS_PER_POWER}}
## Okuma her seferinde doğrular (`used_today`); bozuk / eksik / negatif / çok büyük sayaç ya da geçersiz gün /
## sürüm → o gün için KAPALI (fail-closed: tükenmiş sayılır), başka alana dokunulmaz.
##
## TARİHSEL (M8.5-06): kota "günde 1, dört gücün TOPLAMI" idi (tek ortak sabit = 1, kayıtta
## `rewarded_power_date` + tek sayı `rewarded_power_grants`). Seçim gerekçesi ölçülmüştü (`python
## tools/shop_economy.py caps`, 3000 deneme/senaryo, 90 gün, yoğun oyuncu 10 round/gün): cap 1 → reklam/gün 1,00,
## bedava %20,5, karşılanmayan 8, gün90 Hamur 3.735; cap 2 → 1,99 / %40,3 / 1 / 14.685; cap 3 → 2,92 / %59,1 / 0 /
## 25.610. Owner Product Vision V3'te (2026-10-06, Issue #1 §3) güç başına günde 2'yi seçti; eski ortak sayaç
## yüklemede bellekte göç eder (`from_legacy`). Yeni kuralın ekonomi ölçümü: docs/monetization/ADS_SYSTEM.md
## (TASK/060) ve `tools/shop_economy.py quota`.

## Güç başına günlük başarılı ödül sınırı (owner, Issue #1 §3).
const DAILY_GRANTS_PER_POWER: int = 2
## Kayıt bloğu sürümü.
const QUOTA_VERSION: int = 1
const KEY_VERSION: String = "version"
const KEY_DAY: String = "day_key"
const KEY_GRANTS: String = "grants"


static func daily_cap() -> int:
	return DAILY_GRANTS_PER_POWER


## Bugün bu güç için kaç başarılı ödül verildi (0..daily_cap).
static func grants_today(type: PowerUp.Type) -> int:
	return SaveManager.rewarded_power_grants_today(type, today())


static func remaining_today(type: PowerUp.Type) -> int:
	return maxi(0, DAILY_GRANTS_PER_POWER - grants_today(type))


## Bu güç için ödüllü refill hakkı kaldı mı? (Sağlayıcının hazır olup olmadığından BAĞIMSIZ — o ayrı bir kontrol.)
static func can_grant(type: PowerUp.Type) -> bool:
	return remaining_today(type) > 0


## Ödül GERÇEKTEN kazanıldığında çağrılır: yalnız bu güçten +1 ve yalnız bu gücün sayacı +1 — tek transaction
## (tek mutasyon + tek save; kota kontrolü SaveManager'da, çağırana güvenilmez).
##
## Dönüş: verildiyse true. Kota dolmuşsa, gün belirsizse ya da tip geçersizse hiçbir şey değişmez.
##
## ⚠️ Bu metodu YALNIZCA "reward earned" callback'i (Main.grant_rewarded_power) çağırmalı.
static func grant(type: PowerUp.Type) -> bool:
	return SaveManager.grant_rewarded_powerup(type, today())


## Kabul edilen yerel gün ("" = belirsiz → grant yok).
##
## ⚠️ SAAT: backend yok, doğrulanabilir sunucu saati yok. Saati İLERİ alan oyuncu kotayı tazeleyebilir (günlük giriş
## ödülünün §5.4 taşıdığı aynı, bilinçli kabul edilen açık); saati GERİ almak yeni hak üretmez (kabul edilen gün
## geri gitmez, kayıttaki gün bugünden ilerideyse o günün sayaçları geçerli kalır).
static func today() -> String:
	return Missions.accepted_day()


# --- Saf kurallar (kayıt bloğu) ------------------------------------------------------------------

## Boş blok (hiç ödül alınmamış).
static func empty_block() -> Dictionary:
	return {KEY_VERSION: QUOTA_VERSION, KEY_DAY: "", KEY_GRANTS: _counts(0)}


## `block` kaydında `today` günü için bu gücün kullanılmış ödül sayısı (YAZMAZ). Kayıttaki gün bugünse YA DA
## bugünden ilerideyse (saat geri alınmış) kayıttaki sayaçlar geçerlidir; daha eski gün → 0. Bozuk blok / sürüm /
## gün / sayaç → DAILY_GRANTS_PER_POWER (o gün kapalı). `today` geçersizse grant zaten yapılmaz; okuma kapalı döner.
static func used_today(block: Variant, type: PowerUp.Type, today_key: String) -> int:
	if not Missions.is_day_key(today_key):
		return DAILY_GRANTS_PER_POWER
	var view: Dictionary = day_counts(block, today_key)
	return int(view[PowerUp.save_key(type)])


## `today_key` günü için dört sayaç (doğrulanmış; bkz. `used_today`). Dönüş: {save_key: 0..cap}.
static func day_counts(block: Variant, today_key: String) -> Dictionary:
	if block == null:
		return _counts(0)
	if not _block_shape_valid(block):
		return _counts(DAILY_GRANTS_PER_POWER)
	var day: String = (block as Dictionary)[KEY_DAY]
	if day.is_empty() or day < today_key:
		return _counts(0)
	return _clean_counts((block as Dictionary)[KEY_GRANTS])


## Yükleme doğrulaması (yalnız bellekte; Main / SaveManager.load_game): geçerli blok → biçimi temizlenmiş blok;
## bozuk blok (sözlük değil / sürüm / gün geçersiz) → bugün için dört sayaç DOLU (fail-closed, ertesi gün kendiliğinden
## 0/2) — `today_key` de belirsizse boş blok (grant zaten yapılamaz).
static func sanitize(raw: Variant, today_key: String) -> Dictionary:
	if raw == null:
		return empty_block()
	if not _block_shape_valid(raw):
		if Missions.is_day_key(today_key):
			return {KEY_VERSION: QUOTA_VERSION, KEY_DAY: today_key, KEY_GRANTS: _counts(DAILY_GRANTS_PER_POWER)}
		return empty_block()
	var block: Dictionary = raw
	var day: String = block[KEY_DAY]
	if day.is_empty():
		return empty_block()
	return {KEY_VERSION: QUOTA_VERSION, KEY_DAY: day, KEY_GRANTS: _clean_counts(block[KEY_GRANTS])}


## Eski M8.5-06 ortak sayacından (`rewarded_power_date` + tek sayı `rewarded_power_grants`) güç başına bloğa geçiş
## (TASK/060, muhafazakâr): eski tarih bugünse (ya da ileride) eski TOPLAM kullanım 0..1'e normalleşir (eski tavan 1)
## ve DÖRT sayaca da aynı başlangıç verilir — geçiş gününde fazladan hak üretmemek için kota hesabı; "dört reklam
## izlendi" anlamına gelmez. Bozuk / negatif eski sayı bugün → 1 (fail-closed). Eski gün / tarih yok → boş blok
## (ertesi gün herkes 0/2). Stok / Hamur / level / yıldız gibi diğer alanlara dokunmaz.
static func from_legacy(legacy_date: Variant, legacy_grants: Variant, today_key: String) -> Dictionary:
	if not Missions.is_day_key(legacy_date) or not Missions.is_day_key(today_key):
		return empty_block()
	var day: String = legacy_date
	if day < today_key:
		return empty_block()
	var used: int = 1
	match typeof(legacy_grants):
		TYPE_INT:
			used = 1 if int(legacy_grants) < 0 else mini(int(legacy_grants), 1)
		TYPE_FLOAT:
			var number: float = legacy_grants
			if not is_nan(number) and not is_inf(number) and number >= 0.0 and number == floorf(number):
				used = mini(int(number), 1)
	return {KEY_VERSION: QUOTA_VERSION, KEY_DAY: day, KEY_GRANTS: _counts(used)}


## Başarılı grant sonrası blok (saf): `today_key` gününün sayaçları + bu güç +1. Kayıttaki gün bugünden
## ilerideyse o gün korunur. Kota doluysa / bozuksa / gün geçersizse boş sözlük (grant YOK).
static func after_grant(block: Variant, type: PowerUp.Type, today_key: String) -> Dictionary:
	if not Missions.is_day_key(today_key) or not PowerUp.is_valid_type(type):
		return {}
	var counts: Dictionary = day_counts(block, today_key)
	var key: String = PowerUp.save_key(type)
	if int(counts[key]) >= DAILY_GRANTS_PER_POWER:
		return {}
	counts[key] = int(counts[key]) + 1
	var day: String = today_key
	if _block_shape_valid(block):
		var stored: String = (block as Dictionary)[KEY_DAY]
		if not stored.is_empty() and stored > today_key:
			day = stored
	return {KEY_VERSION: QUOTA_VERSION, KEY_DAY: day, KEY_GRANTS: counts}


static func _counts(value: int) -> Dictionary:
	var out: Dictionary = {}
	for type in PowerUp.all():
		out[PowerUp.save_key(type)] = value
	return out


## Blok iskeleti geçerli mi: sözlük, sürüm == 1 (int ya da tam float), gün "" ya da gerçek gün anahtarı, grants
## sözlük. (Sayaçlar ayrı, `_clean_counts`.)
static func _block_shape_valid(raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	var block: Dictionary = raw
	var version: Variant = block.get(KEY_VERSION)
	if not ((typeof(version) == TYPE_INT and int(version) == QUOTA_VERSION)
			or (typeof(version) == TYPE_FLOAT and float(version) == float(QUOTA_VERSION))):
		return false
	var day: Variant = block.get(KEY_DAY)
	if typeof(day) != TYPE_STRING or not (String(day).is_empty() or Missions.is_day_key(day)):
		return false
	return block.get(KEY_GRANTS) is Dictionary


## Dört sayaç: geçerli tam sayı 0..cap aynen; eksik / metin / NaN / kesirli / negatif / cap üstü → cap (fail-closed).
## Bilinmeyen anahtarlar düşer.
static func _clean_counts(raw: Variant) -> Dictionary:
	var source: Dictionary = raw if raw is Dictionary else {}
	var out: Dictionary = {}
	for type in PowerUp.all():
		var key: String = PowerUp.save_key(type)
		var value: Variant = source.get(key)
		var count: int = DAILY_GRANTS_PER_POWER
		match typeof(value):
			TYPE_INT:
				if int(value) >= 0 and int(value) <= DAILY_GRANTS_PER_POWER:
					count = int(value)
			TYPE_FLOAT:
				var number: float = value
				if not is_nan(number) and number == floorf(number) and number >= 0.0 \
						and number <= float(DAILY_GRANTS_PER_POWER):
					count = int(number)
		out[key] = count
	return out
