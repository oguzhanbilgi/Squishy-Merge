class_name AdPolicy
extends RefCounted
## Monetizasyon politikası — sayıların TEK ayar yeri (TASK/052). Kilitli ürün kuralı GAME_DESIGN §12.2'de; burada onun
## sayıları ve saf kararları durur. Uygulayan: MonetizationManager (aktif süre saati, round sayacı, bekleme, gösterim
## sırası) ve Main (doğal mola = normal round'un kesinleşmesi). Uzak yapılandırma YOK — ileride gerçek veriyle A/B ayarı
## yalnız bu sabitlerden yapılır; başka dosyada sayı tekrarlanmaz.
##
## ZORUNLU (oyuncunun seçmediği) GEÇİŞ REKLAMI — hepsi doğruyken, yalnız doğal molada (round KESİN bitti, devam kararları
## tamamlandı, sonuç ekranından ÖNCE; `Main._on_round_finished` tek çağrı noktası):
##   1. önceki gerçek geçiş reklamı gösteriminden (SDK "gösterildi") bu yana en az FORCED_INTERSTITIAL_MIN_ROUNDS
##      KESİNLEŞEN NORMAL round (sabit level / Sonsuz; meydan okuma ve tutorial'dan doğan round SAYILMAZ) — oturumun
##      ilk geçiş reklamı için de: bu süreçte monetizasyon açıldıktan sonra en az o kadar round
##   2. aynı andan bu yana en az FORCED_INTERSTITIAL_MIN_INTERVAL_SEC AKTİF ön plan saniyesi (sayılmaz: arka plan /
##      ekran kapalı, UMP formu, herhangi bir tam ekran reklam, onboarding tamamlanmamış, yaş bandı reklamsız)
##   3. herhangi bir tam ekran reklamın (ödüllü ya da geçiş) kapanışından bu yana FULLSCREEN_AD_COOLDOWN_SEC aktif sn
##   4. başka tam ekran reklam yok (ödüllü talep / geçiş molası), reklam HAZIR (yüklü, süresi dolmamış), yaş / rıza /
##      SDK reklama izin veriyor, UMP gizlilik formu açık değil, uygulama ön planda
## Hazır değilse sonuç HEMEN açılır (beklenmez); uygunluk korunur, sonraki doğal molada denenir. Sayaç ve saat SDK
## "gösterildi"de (geç gelen dahil, bir kez; gösterim sayılır) ve "gösterildi"si gelmemiş reklamın kapanışında (SDK
## kapanışı ya da örtülme kanıtlı mola kurtarması; gösterim SAYILMAZ) sıfırlanır; yükleme / gösterim hatası ve
## "gösterilmedi" kurtarması sıfırlamaz. Sayım kapsamı aktif süre saatiyle aynı: rıza reddi / SDK beklemesi sayımı
## durdurmaz (gösterimi durdurur).
##
## ÖDÜLLÜ KOTALAR — tek kaynaklarında tanımlı, burada yalnız okunur (kopya sayı YOK; `rewarded_caps()`):
##   devam GameBoard.MAX_REVIVES_PER_ROUND · güç refill'i RewardedPolicy.DAILY_GRANTS_PER_POWER (TASK/060: güç BAŞINA,
##   dört bağımsız sayaç) ·
##   reklamlı sandık DailyRewards.AD_CHESTS_PER_DAY · reklamlı +Hamur DailyRewards.AD_DOUGH_PER_DAY. Hepsi YALNIZ SDK'nın
##   "ödül kazanıldı" geri çağrısıyla tüketilir; ödüllü reklam her zaman oyuncunun açık seçimidir (CTA), kendiliğinden
##   açılmaz.
##
## APP-OPEN REKLAMI: YOK — v1 non-goal (PROJECT_CONTEXT); TASK/052 yeniden denetledi ve ertelendi
## (docs/monetization/ADS_SYSTEM.md §18.4): açılışta oyuncunun beklediği bir yükleme yüzeyi yok (Ana Sayfa hemen
## etkileşimli; rıza + yaş + SDK ondan SONRA açılır).

## Önceki gerçek geçiş reklamından bu yana gereken kesinleşen NORMAL round sayısı (TASK/052; altına inilmez).
const FORCED_INTERSTITIAL_MIN_ROUNDS: int = 2
## Önceki gerçek geçiş reklamından bu yana gereken AKTİF ön plan süresi (sn). TASK/052: 900 → 300 (altına inilmez).
const FORCED_INTERSTITIAL_MIN_INTERVAL_SEC: float = 300.0
## Herhangi bir tam ekran reklam kapanışından sonra geçiş reklamı beklemesi (aktif sn) — art arda iki tam ekran reklam
## yok. M8.9-02'den beri aynı.
const FULLSCREEN_AD_COOLDOWN_SEC: float = 60.0

const GAME_BOARD_SCRIPT: String = "res://scripts/game/game_board.gd"


## İki sayaç geçiş reklamına izin veriyor mu (aktif süre + kesinleşen normal round). Bekleme / hazırlık / rıza / tek
## tam ekran kuralı ayrıca yöneticide (`MonetizationManager._interstitial_block_reason`).
static func forced_interstitial_gates_met(active_elapsed_sec: float, normal_rounds: int) -> bool:
	return normal_rounds >= FORCED_INTERSTITIAL_MIN_ROUNDS and active_elapsed_sec >= FORCED_INTERSTITIAL_MIN_INTERVAL_SEC


## Kesinleşen bir round zorunlu geçiş reklamı sayacına girer mi: yalnız NORMAL round ve yalnız monetizasyon bu süreçte
## açıkken (onboarding tamam — tutorial ve tutorial'dan doğan round reklamsız kalır; yaş bandı reklama izinli). Meydan
## okuma (TASK/047) yöneticiye hiç ulaşmaz — yalıtım Main'in ayrı bitiş işleyicisindedir (suite'ler kaynakla
## denetler); ilk argüman kuralı yazılı tutar (bugünkü tek çağıran — yönetici — sabit false geçer).
static func round_counts(is_daily_challenge: bool, monetization_active: bool) -> bool:
	return monetization_active and not is_daily_challenge


## Ödüllü kotaların TEK kaynaklarından okunmuş görünümü (testler / teşhis / belge). Değer burada tanımlanmaz.
static func rewarded_caps() -> Dictionary:
	var board: GDScript = load(GAME_BOARD_SCRIPT)
	return {
		"revive_per_round": int(board.get_script_constant_map()["MAX_REVIVES_PER_ROUND"]),
		"power_refill_per_power_per_day": RewardedPolicy.DAILY_GRANTS_PER_POWER,
		"power_kinds": PowerUp.all().size(),
		"ad_chest_per_day": DailyRewards.AD_CHESTS_PER_DAY,
		"ad_dough_per_day": DailyRewards.AD_DOUGH_PER_DAY,
		"ad_dough_amount": DailyRewards.AD_DOUGH_AMOUNT,
	}
