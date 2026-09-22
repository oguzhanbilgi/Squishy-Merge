extends Node
## Yerel kalıcı kayıt (bulut yok). JSON olarak user:// altında tutulur.

const SAVE_PATH: String = "user://squishy_merge_save.json"

## Skin durumu değişti (M8.5-13). Koleksiyon, mağaza ve ana sayfa bunlara
## abone: sekme geçişindeki refresh()'e ek olarak, ekran açıkken gelen bir
## değişiklik (aynı ekrandan satın alma / equip) de anında yansısın.
## Gameplay abone DEĞİL: parça skin'ini doğarken okuyor, round içinde equip
## mümkün değil.
signal skin_granted(id: StringName)
## Boş id = varsayılan görünüme dönüldü.
signal skin_equipped(id: StringName)

var data: Dictionary = {}

const DEFAULT_DATA: Dictionary = {
	"highest_level_unlocked": 1,
	"level_stars": {},
	"endless_high_score": 0,
	"dough": 0,
	"unlocked_skins": [],
	## Takılı skin'in id'si. BOŞ STRING = varsayılan/orijinal dumpling görünümü.
	## Eski kayıtlarda bu anahtar yok; load_game DEFAULT_DATA üzerine yazdığı
	## için otomatik olarak "" kalıyor (geriye dönük uyumlu).
	"equipped_skin": "",
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
	## Ödüllü güç refill kotası (M8.5-06). Günlük giriş ödülüyle aynı desen:
	## tarih + sayaç. Eski kayıtlarda bu anahtarlar yok; load_game
	## DEFAULT_DATA üzerine yazdığı için otomatik olarak "" / 0 kalıyor
	## (geriye dönük uyumlu, kimse hak kaybetmiyor).
	"rewarded_power_date": "",
	"rewarded_power_grants": 0,
	## Ayarlar (M8.5-10). Ses efektleri açık mı? Eski kayıtlarda anahtar yok,
	## load_game DEFAULT_DATA üzerine yazdığı için otomatik true kalıyor.
	"sfx_enabled": true,
	## Titreşim (M8.5-15). Mobilde varsayılan AÇIK; eski kayıtlarda anahtar
	## yok, DEFAULT_DATA üzerine yazıldığı için otomatik true kalıyor.
	"haptics_enabled": true,
	## İlk açılış / tutorial dikişi (M8.9-02; tutorial'ın kendisi M8.10).
	## YENİ kayıt: false — banner, interstitial, günlük ödül penceresi ve
	## ödüllü reklam sunumu tutorial bitene kadar kapalı. ESKİ kayıt (anahtar
	## yok): load_game ilerleme kanıtına bakar (bkz. _migrate_onboarding) —
	## gerçek oyuncular etkilenmez. Yalnız `complete_onboarding` true yapar.
	"onboarding_completed": false,
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
}


func _ready() -> void:
	load_game()


func load_game() -> void:
	data = DEFAULT_DATA.duplicate(true)
	if not FileAccess.file_exists(SAVE_PATH):
		_grant_starter_powerups()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Kayıt dosyası açılamadı: %s" % SAVE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Kayıt dosyası bozuk, varsayılanlara dönülüyor.")
		return
	for key: String in parsed:
		data[key] = parsed[key]
	_migrate_onboarding(parsed)
	_grant_starter_powerups()


## Eski kayıt (anahtar yok) için tek seferlik onboarding kararı (M8.9-02).
## Kural (docs/monetization/DAILY_REWARDS.md §9): kanonik ilerleme alanlarından
## herhangi biri oynanmışlık kanıtıysa tutorial TAMAMLANMIŞ sayılır —
## `highest_level_unlocked` > 1, en az bir level yıldızı, `total_merges` > 0,
## sonsuz mod rekoru ya da açılmış skin. Hamur miktarına BAKILMAZ (günlük giriş
## ödülü tek açılışta 15 Hamur veriyor; oynanmışlık kanıtı değil). Yalnız
## bellekte karar verilir, DİSKE YAZILMAZ: sonraki doğal kayıt anahtarı
## kalıcılaştırır (okuma sırasında beklenmedik yazma yok — rewarded_power ve
## equipped_skin ile aynı ilke). Dosyasız yeni oyuncu bu yola hiç girmez
## (DEFAULT_DATA false).
func _migrate_onboarding(parsed: Dictionary) -> void:
	if parsed.has("onboarding_completed"):
		return
	data["onboarding_completed"] = has_progress_evidence()


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


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Kayıt dosyası yazılamadı: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


# --- İlerleme (M2) ---

func highest_level_unlocked() -> int:
	return int(data.get("highest_level_unlocked", 1))


func is_level_unlocked(level_number: int) -> bool:
	return level_number <= highest_level_unlocked()


## Level tamamlandığında bir sonrakini açar. Geriye gitmez.
func complete_level(level_number: int) -> void:
	if level_number + 1 > highest_level_unlocked():
		data["highest_level_unlocked"] = level_number + 1
		save_game()


## Sonsuz mod level 10 bitince açılır (GAME_DESIGN.md §4).
func is_endless_unlocked(total_levels: int) -> bool:
	return highest_level_unlocked() > total_levels


func endless_high_score() -> int:
	return int(data.get("endless_high_score", 0))


## Yeni rekor kırıldıysa true döner.
func record_endless_score(score: int) -> bool:
	if score <= endless_high_score():
		return false
	data["endless_high_score"] = score
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


func owned_skins() -> Array:
	return data.get("unlocked_skins", [])


func owns_skin(id: StringName) -> bool:
	return owned_skins().has(String(id))


func grant_skin(id: StringName) -> void:
	if owns_skin(id):
		return
	var owned: Array = owned_skins().duplicate()
	owned.append(String(id))
	data["unlocked_skins"] = owned
	save_game()
	skin_granted.emit(id)


# --- Takılı skin (M8.5) ---
#
# Boş string = varsayılan görünüm. Bu bilinçli: "hiç skin seçilmemiş" ile
# "varsayılanı seçtim" aynı şey, ayrı bir sentinel id'ye gerek yok.

## Takılı skin'in id'si, DOĞRULANMIŞ hâliyle. Kayıtta duran id artık
## SkinLibrary'de yoksa ya da oyuncu ona sahip değilse boş string döner —
## yani güvenli biçimde varsayılana düşer.
##
## Bu getter kayda YAZMAZ: okuma sırasında beklenmedik disk yazması olmasın.
## Kalıcı temizlik equip_skin/clear_equipped_skin üzerinden yapılır.
func equipped_skin_id() -> StringName:
	var raw: String = str(data.get("equipped_skin", ""))
	if raw.is_empty():
		return &""
	var id := StringName(raw)
	if not owns_skin(id):
		return &""
	if SkinLibrary.find(id) == null:
		return &""
	return id


## Takılı SkinData, ya da varsayılan görünümde null.
func equipped_skin() -> SkinData:
	var id: StringName = equipped_skin_id()
	if id == &"":
		return null
	return SkinLibrary.find(id)


## Skin takar. Sahip olunmayan ya da tanımsız id reddedilir (false döner).
## Boş string geçerlidir ve varsayılana döner.
func equip_skin(id: StringName) -> bool:
	if id == &"":
		clear_equipped_skin()
		return true
	if not owns_skin(id) or SkinLibrary.find(id) == null:
		return false
	if StringName(str(data.get("equipped_skin", ""))) == id:
		return true
	data["equipped_skin"] = String(id)
	save_game()
	skin_equipped.emit(id)
	return true


## Varsayılan görünüme döner.
func clear_equipped_skin() -> void:
	if str(data.get("equipped_skin", "")).is_empty():
		return
	data["equipped_skin"] = ""
	save_game()
	skin_equipped.emit(&"")


## Round sonunda çağrılır. Toplam merge sayacını ilerletir ve hak edilen
## bonus sandık sayısını döner (GAME_DESIGN.md §5.2: her 75 merge'de bir).
func add_merges(count: int) -> int:
	if count <= 0:
		return 0
	data["total_merges"] = int(data.get("total_merges", 0)) + count
	var pending: int = int(data.get("merges_since_bonus_chest", 0)) + count
	var chests: int = pending / ChestSystem.MERGES_PER_BONUS_CHEST
	data["merges_since_bonus_chest"] = pending % ChestSystem.MERGES_PER_BONUS_CHEST
	save_game()
	return chests


func stars_for_level(level_number: int) -> int:
	return int(data.get("level_stars", {}).get(str(level_number), 0))


## Yıldız sadece yukarı gider — daha kötü bir tekrar oynayış eskisini silmez.
func record_stars(level_number: int, stars: int) -> void:
	if stars <= stars_for_level(level_number):
		return
	var all_stars: Dictionary = data.get("level_stars", {}).duplicate()
	all_stars[str(level_number)] = stars
	data["level_stars"] = all_stars
	save_game()


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
# Bu, tam bir atomic-file/journaling sistemi DEĞİL — dosyanın kendisi hâlâ
# tek `store_string` ile yazılıyor. Çözülen şey uygulama seviyesindeki
# "yarım işlem" penceresi: bellekteki durum tek seferde tutarlı hale
# getiriliyor ve tek seferde diske iniyor.

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


## Bugün kaç ödüllü güç refill'i verildi.
##
## Tarih değiştiyse 0 döner ve KAYDA YAZMAZ: okuma sırasında beklenmedik
## disk yazması olmasın (equipped_skin_id ile aynı yaklaşım). Kalıcı sıfırlama
## bir sonraki grant'te yapılıyor.
func rewarded_power_grants_today(today: String) -> int:
	if String(data.get("rewarded_power_date", "")) != today:
		return 0
	return int(data.get("rewarded_power_grants", 0))


## Ödüllü reklam ödülü: +1 güç ve kotadan bir düşüş, TEK transaction.
##
## Kota kontrolü BURADA yapılıyor (çağıranın ayrıca kontrol etmesine
## güvenilmiyor) — böylece stale/duplicate bir callback kota dolmuşken
## stok veremez.
##
## Dönüş: verildiyse true. Kota dolmuşsa ya da tip geçersizse hiçbir alan
## değişmez ve diske yazma da olmaz.
func grant_rewarded_powerup(type: PowerUp.Type, today: String) -> bool:
	if not PowerUp.is_valid_type(type):
		return false
	var used: int = rewarded_power_grants_today(today)
	if used >= RewardedPolicy.DAILY_POWER_REFILLS:
		return false

	# Üç mutasyon, tek yazma.
	var stock: Dictionary = _powerup_stock().duplicate()
	var key: String = PowerUp.save_key(type)
	stock[key] = int(stock.get(key, 0)) + 1
	data["powerups"] = stock
	data["rewarded_power_date"] = today
	data["rewarded_power_grants"] = used + 1
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
	save_game()
	skin_granted.emit(id)
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


## Tutorial bitti: tek yazma, geri alınmaz. M8.10 tutorial akışının sonunda
## çağrılacak; testler de bunu kullanır. Zaten true ise yazmaz.
func complete_onboarding() -> void:
	if onboarding_completed():
		return
	data["onboarding_completed"] = true
	save_game()


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
	save_game()
	if granted_skin:
		skin_granted.emit(skin_id)
