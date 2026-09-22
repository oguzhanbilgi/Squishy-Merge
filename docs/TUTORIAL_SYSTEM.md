# TUTORIAL_SYSTEM.md — İlk açılış tutorial'ı ve ilk gün kuralı (M8.10)

> Kanonik doküman (owner kararı, 2026-09-22). Reklam mimarisi
> [monetization/ADS_SYSTEM.md](monetization/ADS_SYSTEM.md), günlük ödüller
> [monetization/DAILY_REWARDS.md](monetization/DAILY_REWARDS.md), rıza
> [monetization/PRIVACY_CONSENT.md](monetization/PRIVACY_CONSENT.md).
> Kilitli oyun sayıları GAME_DESIGN.md'de; burada onboarding akışı ve
> onun günlük/reklam yaşam döngüsüne dikişi.
>
> **Durum (2026-09-22):** `task/035-first-run-tutorial` dalında UYGULANDI,
> masaüstü testleri + görsel QA tamam. **Cihaz kapısı (A36) HENÜZ
> ÇALIŞTIRILMADI**, main'e birleştirilmedi, push edilmedi.

## 1. Ne çözüyor

M8.9'a kadar `onboarding_completed` yalnız bir **dikişti**: yeni kayıtta
false, tutorial'ın kendisi yoktu ve hiçbir yerden true olmuyordu. Level 1'de
`tutorial_pose` + "sürükle • bırak" yazan küçük bir ipucu vardı; onboarded
bir oyuncu Level 1'i tekrar oynadığında da görünüyordu ve gerçek bir
onboarding değildi.

M8.10 şunu getiriyor:

- gerçekten **yeni** bir oyuncu açılışta doğrudan **etkileşimli Level 1
  tutorial'ına** girer (Ana Sayfa → OYNA → Harita yolculuğu yok),
- tutorial boyunca **reklam yok, UMP formu yok, günlük ödül mutasyonu yok**,
- tutorial bitince onboarding **tek transaction** ile kalıcılaşır ve o günün
  tarihi de yazılır,
- **tutorial'ın bitirildiği takvim günü günlük ödül sistemi tamamen
  kapalıdır**; ertesi yerel günde sıfırdan başlar,
- monetizasyon, tutorial'dan doğan Level 1 round'unun **ortasında** değil, bir
  sonraki güvenli geçişte açılır (banner yuvası oyunun ortasında açılıp kabı
  yeniden yerleştirmez).

Eski Level 1 ipucu **kaldırıldı** (iki tutorial sistemi yarışmıyor).

## 2. Bileşenler ve sorumluluk sınırı

| bileşen | dosya | sorumluluk |
|---|---|---|
| `TutorialController` | `scripts/game/tutorial_controller.gd` | adım sırası, girdi kapıları, deterministik ilk iki drop, GERÇEK merge beklemesi, geri onayı |
| `TutorialOverlay` | `scripts/ui/tutorial_overlay.gd` + `scenes/ui/tutorial_overlay.tscn` (katman 8) | coach-mark sunumu: spot + halka, candy konuşma kartı, maskot, sürükleme ipucu, ATLA |
| `Onboarding` | `scripts/game/onboarding.gd` | "tamamlandı mı", "hangi gün", "günlük ödüller açık mı" — **ilk gün kuralının TEK kapısı** |
| `SaveManager` | `scripts/autoload/save_manager.gd` | kalıcılık (`onboarding_completed`, `onboarding_completed_day`) |
| `TutorialEvents` | `scripts/game/tutorial_events.gd` | analitik olay dikişi (sağlayıcı YOK) |
| `GameBoard` | `scripts/game/game_board.gd` | GERÇEK fizik + pasif tutorial dikişleri |
| `Main` | `scripts/main.gd` | açılış dalı, geri tuşu, ertelenmiş monetizasyon |

Kural: **oyun fiziği ürün onboarding'ini bilmez, UI kalıcılığa karar vermez.**
Board yalnız "girdiyi kapat / dondur / şu tier'ı ver / bırakmayı şuraya
hizala" gibi mekanik kancalar sunar; hangi adımda hangisinin açılacağına
controller karar verir; tamamlanmayı yalnız `Onboarding.complete()` yazar.

## 3. Adımlar

| adım | metin | girdi | board | görsel |
|---|---|---|---|---|
| `WELCOME` | "Hoş geldin!" / "Hamurları birleştirip büyüt." · **BAŞLA** | kilitli | donuk | maskot (`tutorial_pose`) + karartma |
| `FIRST_DROP` | "Parmağını sağa–sola sürükle, sonra bırak." | normal nişan/bırakma | oynuyor | karartma YOK, sürükleme ipucu (ray + parmak + ok) |
| `MATCH_DROP` | "Aynı hamurları buluştur!" | normal nişan/bırakma | oynuyor | ilk T1'de altın halka + cyan kılavuz çizgisi |
| `MERGE_SUCCESS` | "Harika!" / "Aynılar birleşip büyür." | kilitli | donuk | kısa kutlama (1,25 s, sonra otomatik) |
| `GOAL` | "Hedefin burada." / "Birleştirerek gerekli büyüklüğe ulaş." · **DEVAM** | kilitli | donuk | HUD HEDEF plakası spot |
| `DANGER` | "Parçaların bu çizginin üstünde kalmasına izin verme!" · **DEVAM** | kilitli | donuk | taşma çizgisi bandı spot |
| `POWERS` | "Zorlanırsan güçler burada." / "Şimdilik sakla." · **DEVAM** | kilitli | donuk | dört güç slotu (iki tepsi) spot |
| `READY` | "Hazırsın!" / "Şimdi Level 1'i tamamla." · **DEVAM** | kilitli | donuk | maskot |

Normal bir oyuncu için rehberli kısım ~20–45 sn. Sert zamanlayıcı YOK:
`MERGE_SUCCESS` dışındaki her adım oyuncunun dokunuşunu bekler.

**Tutorial ÖDÜL VERMEZ**: ne Hamur, ne sandık, ne ekstra güç. Başlangıç güç
stoğu (`powerup_starter_granted`) kayıt başına bir kez, tutorial'dan
BAĞIMSIZ verilir; `POWERS` adımı yalnız görseldir ve stok tüketmez.

### Deterministik ilk merge

Öğretim kısmı **tutorial'a özel bir drop kuyruğu** kullanır: `[T1, T1]`
(`GameBoard.setup_tutorial_queue`, `add_child`'dan önce). Normal `DropBag`'e
DOKUNULMAZ — kuyruk bitince torba devralır ve torba round başına yeni olduğu
için tutorial'dan sonra **hiç çekilmemiş, tertemiz** bir torba çalışır.

İki bırakma yardımı (yalnız tutorial; normal oyunda `NONE`):

- **CLAMP** (`FIRST_DROP`): bırakma x'i kabın ortasında ±%24 kap genişliği
  bandına sınırlanır — ilk parça duvara yapışıp sekmez. Önizleme de sınırlı:
  oyuncu ne görüyorsa o düşer.
- **SNAP** (`MATCH_DROP`): bırakma x'i ilk T1'in x'ine hizalanır. Önizleme
  SERBEST kalır (sürükleme gerçek hissettirir); hizalama bırakma anında
  uygulanır ve parça görünür biçimde cyan kılavuz çizgisine süzülür.

**Merge sahte DEĞİL**: T2 doğrudan doğurulmaz. Oyuncu ikinci T1'i gerçekten
bırakır, production `_resolve_merge` T2'yi üretir, skor/merge sayacı/ses/
titreşim normal yoldan geçer ve adım ancak `GameState.merge_performed`
geldiğinde ilerler. Tutorial'ın ürettiği T2 board'da **kalır**.

Güvenlik ağı (§33): ikinci bırakmadan sonra `MERGE_TIMEOUT` (3 sn) içinde
merge gelmezse adım yeniden kurulur — bekleyen parça T1'e çevrilir, hedef
tazelenir, girdi açılır. Oyuncu asla takılı kalmaz.

## 4. Girdi ve dondurma kapıları

Board'da **ayrı** bir tutorial dikişi var; fail-pending / refill-pending /
menü dondurmasıyla KARIŞTIRILMAZ:

- `set_tutorial_input_locked(bool)` — nişan, bırakma ve güç hedeflemesi
  kapanır; önizleme gizlenir.
- `set_tutorial_paused(bool)` — `_is_tutorial_paused` bayrağı `_is_paused()`
  zincirine katılır; parçalar coach kartının altında sürüklenmez.

Karşılıklı koruma: tutorial donukken `set_menu_paused(true)` ikinci bir
dondurma katmanı açmaz; `_finish()` her üç bayrağı da temizler.

Tutorial açıkken **Mola ve Ayarlar pencereleri açılmaz** (oyun içi Geri/Çıkış
butonu tutorial'ın kendi onayını açar). Tutorial'ın kendi güvenli çıkışı
vardır; "Ana Menüye Dön" ile onboarding yarım kalamaz.

## 5. ATLA ve Android geri

**ATLA** (`skip`): küçük, gösterişsiz, üst sağ köşede, ana CTA DEĞİL.
`READY` adımında gizlenir (orada zaten DEVAM var). Atlama **aynı kanonik
tamamlanma yolundan** geçer — ayrı bir "sahte tamamlandı" bayrağı YOK:
onboarding true + tamamlanma günü + aynı ilk gün bastırması. Çift dokunuş
ikinci kez bitiremez.

**Android geri** (ve oyun içi Geri/Çıkış butonu): monetize edilmiş Ana
Sayfa'ya ASLA düşülmez. Küçük bir onay gösterilir — "Eğitimi bırakmak mı
istiyorsun?" · **DEVAM ET** / **ATLA**. DEVAM ET kaldığı adıma aynen döner;
ikinci geri basışı da onayı kapatır. Main'in 250 ms geri debounce'u aynen
geçerlidir.

## 6. Kalıcılık

```
onboarding_completed      : bool     yeni kayıt false
onboarding_completed_day  : String   "YYYY-MM-DD" ya da ""
```

**Tamamlanma TEK transaction** (`SaveManager.complete_onboarding(day_key)`):
`onboarding_completed = true` + `onboarding_completed_day = day_key` +
(ileriyse) `daily_rewards.last_seen_day_key = day_key` tek `save_game()` ile
diske iner. İdempotent: zaten true ise hiçbir alan değişmez ve **diske yazma
da olmaz**. Gün anahtarı `DailyRewards.day_key()` — saat geri alma
korumasıyla aynı efektif gün.

`onboarding_completed_day` **boş string** iki şeyi anlatır, ikisi de doğru
davranışı verir:

| durum | anlam | günlük sistem |
|---|---|---|
| `onboarding_completed = false`, gün `""` | tutorial bitmedi | kapalı (M8.9-02 davranışı) |
| `onboarding_completed = true`, gün `""` | **eski/yerleşik kayıt** (M8.10 öncesi) | **AÇIK — bastırma YOK** |
| `onboarding_completed = true`, gün dolu | M8.10 tutorial'ıyla tamamlandı | tamamlanma günü kapalı, ertesi gün açık |

**Eski kayıt migration'ı değişmedi** (DAILY_REWARDS §9): anahtar yoksa
ilerleme kanıtına bakılır ve onboarding true sayılır. `onboarding_completed_day`
burada **UYDURULMAZ** — boş kalır, yani mevcut gerçek oyuncuların günlük
davranışı birebir korunur ve hiçbiri aniden tutorial görmez.

**Çökme / yarıda kapanma:** adım adım kalıcılık YOK. Tamamlanmadan
kapatılırsa `onboarding_completed` false kalır, tutorial bir sonraki
açılışta **baştan** başlar. Günlük mutasyonu, reklam açılışı ve yarım
durum oluşmaz — yarım kalmış fizik durumunu diske yazmaktan daha sağlam.

## 7. İlk gün kuralı

Tek yetkili fonksiyon: **`Onboarding.daily_rewards_unlocked()`**.

```
onboarding bitmedi                        -> kapalı
tamamlanma günü ""  (yerleşik oyuncu)     -> AÇIK
efektif gün <= tamamlanma günü            -> kapalı   (ilk gün kuralı)
efektif gün  > tamamlanma günü            -> AÇIK
```

`today == onboarding_completed_day` karşılaştırması **UI'lara dağıtılmadı**;
aşağıdaki yüzeylerin hepsi bu tek fonksiyonu okur:

| yüzey | kapı |
|---|---|
| giriş ödülü (+15, seri) | `DailyReward.claim_if_new_day` / `is_claimable` |
| ücretsiz sandık | `DailyRewards.claim_free_chest` |
| reklamlı sandık | `DailyRewards.grant_ad_chest` |
| reklamlı +150 Hamur | `DailyRewards.grant_ad_dough` |
| otomatik pencere | `DailyRewards.popup_due` + `Main._maybe_auto_open_daily_rewards` |
| Mağaza / Ana Sayfa madalyonu | `Main.open_daily_rewards` |
| Mağaza GÜNLÜK ÖDÜLLER bölümü | `ShopScreen._refresh_daily` (gizli) |
| Ana Sayfa bildirim noktası | `DailyReward.is_claimable` → false |

Kapı **modelde**, UI'da değil: pencere bir şekilde açılsa bile ödül verilemez.

**Tamamlanma gününde:** +15 yok, seri ilerlemez, otomatik pencere açılmaz,
ücretsiz/reklamlı sandık ve +150 yok, Mağaza bölümü gizli, madalyon nokta
göstermez ve açmaz. **Kaçırılan ödül sonradan telafi EDİLMEZ.**

**Ertesi yerel günde** sistem sıfırdan başlar: seri **1. gün**, +15 tam bir
kez, tek otomatik pencere, 1 ücretsiz + 2 reklamlı sandık + 1 reklamlı +150.

**Saat geri alma:** tamamlanma anında o gün `last_seen_day_key` olarak da
işlendiği ve gate efektif günü (`DailyRewards.day_key()`) kullandığı için;
B gününe geçtikten sonra saati A'ya almak günlük sistemi **yeniden
kilitlemez** ve ikinci bir ödül döngüsü üretmez.

## 8. Reklam / UMP yaşam döngüsü

**Tutorial boyunca (`onboarding_completed == false`):**

- banner yuvası **0** (tam eski düzen — Harita ve oyun dahil),
- ödüllü ve geçiş reklamı **yüklenmez, gösterilmez**,
- geçiş reklamının **aktif süre saati saymaz** (`_counting_allowed` false),
- **UMP/rıza akışı hiç başlamaz** (M8.10 değişikliği): `MonetizationManager.
  _ready` artık `_maybe_start_consent()` çağırıyor ve onboarding bitmeden
  dönüyor. **Rıza şartı KALDIRILMADI, yalnız ertelendi** — `_ads_enabled()`
  hâlâ izin + SDK istiyor, yani ilk reklam talebinden ÖNCE rıza akışı mutlaka
  çalışır,
- ödüllü devam/refill CTA'sı pasif + dürüst sebep.

**Tutorial bitince — round ortasında değil:** `Main._on_tutorial_completed`
onboarding'i yazar ama `_monetization_deferred = true` bırakır. Banner
yuvası o anda açılıp kabı yeniden yerleştirmez; tutorial'dan doğan Level 1
round'unun kalanı **reklamsız** oynanır. Bu bayrak **GEÇİCİDİR, kayda
yazılmaz** (uygulama kapanırsa onboarding zaten kalıcıdır ve bir sonraki
açılış normal monetizasyon yoluna girer).

**Güvenli geçişte açılır** (`Main._activate_monetization_if_safe`): kabuk
ekranına dönüş (`_show_tab`) ya da yeni bir round kurulumu (`_start_level`,
board henüz yokken). O an `MonetizationManager.set_onboarding_completed(true)`
→ yuva hesaplanır, **rıza akışı başlar**, ödüllü + geçiş önyüklemeleri açılır.

Tutorial round'u bu erteleme sırasında kaybedilirse **ödüllü devam/refill
sunulmaz** — mevcut dürüst "kullanılamıyor" / Bitir / Hamur yolları çalışır,
kilitlenme olmaz.

**Monetizasyon açılması ≠ günlük ödül açılması.** Aynı gün reklamlar
çalışabilir, günlük sistem ertesi yerel güne kadar kapalı kalır.

## 9. Analitik dikişi

`TutorialEvents` (`AdEvents` ile aynı şekil, AYRI liste — M8.9 reklam olay
sözleşmesi donduruldu). **Sağlayıcı YOK**: Firebase/analytics SDK bilerek
entegre edilmedi.

```
tutorial_started     {source}
tutorial_step        {step, elapsed_ms, source}
tutorial_first_drop  {elapsed_ms}
tutorial_first_merge {tier, elapsed_ms}
tutorial_completed   {day_key, source, step, elapsed_ms}
tutorial_skipped     {day_key, source, step, elapsed_ms}
```

Tamamlanma/atlama olayı **yalnız `Onboarding.complete()`'ten** yayılır —
çift bitirme ikinci bir olay üretemez. Kişisel/cihaz verisi yok; kayda
hiçbir şey yazılmaz.

## 10. Görsel dil

Candy-night, kawaii; krem/lavanta/altın/cyan; Baloo 2 başlık + Nunito gövde;
mevcut `UiKit`/tema. Kompakt konuşma kartı (560 px, lavanta halka + gölge),
altın nabızlı spot halkası, `tutorial_pose` maskotu, prosedürel sürükleme
ipucu (ray + parmak + ok) — **yeni dış asset yok**.

**Kart açıkladığı hedefin üstünü ASLA kapatmaz:** hedef dikdörtgeni
verildiğinde kart hangi tarafta daha çok yer varsa oraya oturur, üst güvenli
alana ve alt banner payına kırpılır; hedefli adımlarda maskot gizlenir.
Karartma hedefin üstüne gelmez (delik dört dikdörtgenle bırakılır).
Sürükleme adımlarında karartma HİÇ yok — parmak board'a ulaşsın diye kart
gövdesi ve spot `MOUSE_FILTER_IGNORE`.

## 11. Ses / titreşim

Yeni ses paketi YOK, production denge DEĞİŞMEDİ. Tutorial mevcut olayları
kullanır: drop ve merge sesleri/titreşimleri board'un kendi production
yolundan gelir (tutorial ayrıca titretmez), CTA'lar tema buton sesini
kullanır.

## 11.1 Doğrulama kapıları (owner talebi, M8.10 kapanışı)

Dört ek kapı açıkça kanıtlandı; hepsi deterministik ve cihazsız.

### Kapı 1 — rıza (UMP) durum regresyonu

M8.10'un tek monetizasyon değişikliği rıza akışının **kick-off**'unu
ertelemek. Eklenen `_consent_kickoff_done` bir LATCH'tir, durum makinesi
değil: rızanın kendi durumu zaten `AdsState`'te (CONSENT_CHECKING = uçuşta;
ADS_ALLOWED / ADS_NOT_ALLOWED / ERROR_WITH_PREVIOUS_STATE = çözülmüş) ve
yeniden deneme sayacı `_consent_attempts`'te modelleniyor — latch yalnız
"açılış güncellemesi gönderildi mi" sorusunu yanıtlar.

**Latch YALNIZ iki kick-off noktasını kapatır** (`_ready`,
`set_onboarding_completed(true)`). M8.9'un kurtarma yolları
`_start_consent()`'i DOĞRUDAN çağırır ve latch'i hiç görmez:
`_on_consent_retry()` (planlı geri çekilme) ve `ensure_rewarded()`
(ADS_NOT_ALLOWED + `CONSENT_ON_DEMAND_MIN_INTERVAL`).

`monetization_test` kanıtlıyor:

| durum | beklenen | sonuç |
|---|---|---|
| onboarding false | sıfır `requestConsentInfoUpdate`, sıfır form | ✓ |
| onboarding false + sekme/öne dönüş/pencere açılışı | yine sıfır | ✓ |
| tutorial round'u sürerken tamamlanma | yine sıfır (form round'un üstüne gelmez) | ✓ |
| ilk güvenli kabuk aktivasyonu | TAM BİR akış başlar | ✓ |
| başarıdan sonra 18 yüzey değişimi + 3 duraklat/öne dönüş + 3 pencere açılışı + onboarding tekrarı | İKİNCİ update YOK, izin korunuyor | ✓ |
| güncelleme HATASI | sınırlı geri çekilme (30 s, 120 s) latch AÇIKKEN çalışıyor | ✓ |
| geri çekilme sınırı | M8.9'daki gibi 3 denemede duruyor | ✓ |
| talep üzerine tazeleme | aralık dolmadan spam yok, dolunca gidiyor | ✓ |
| yeni yönetici örneği (yeni açılış) | açılış güncellemesi yeniden yapılıyor | ✓ |

M8.9 rıza/hata davranışı ZAYIFLATILMADI; `_test_consent_errors` bölümü
olduğu gibi geçiyor.

### Kapı 2 — "oturdu" niteliğinin izolasyonu

Hata: yeni doğmuş parçanın `linear_velocity`'si SIFIRDIR (fizik henüz
işlemedi), yalnız hıza bakmak "anında oturdu" diyordu.

Düzeltme **tamamen `TutorialController`'ın içinde** — ilk rehberli T1'i
GÖZLEMLEME kuralı. `scripts/game/dumpling.gd` DEĞİŞMEDİ;
`scripts/game/game_board.gd`'de bu konuya dair hiçbir değişiklik yok.

Üç şart birden gerekiyor (`TutorialController.piece_settled` + gözlem
penceresi): parça en az `SETTLE_MIN` (0,45 sn) yaşamış olmalı, taşma
çizgisinin ALTINDA olmalı (gerçekten kaba inmiş) ve hızı `SETTLE_SPEED`
(34 px/sn) altında olmalı. `SETTLE_TIMEOUT` (2,4 sn) sonunda yine de devam
edilir — oyuncu beklemede kalmaz.

`tutorial_test` ayrı bir ÜRETİM board'unda (level 4, tutorial yok) ölçüyor:
doğuş karesinde "oturdu" DEĞİL, düşerken DEĞİL, kaba inip durunca ÖYLE;
ayrıca üretim board'unda kuyruk boş, girdi kilidi/pause kapalı, kılavuz yok,
nişan yalnız duvar payıyla sınırlı, bırakma tam nişan x'inde doğuyor, drop
cooldown 0,4 sn ve cooldown içindeki ikinci bırakma engelleniyor.

### Kapı 3 — rehberli merge kimliği

Adım "herhangi bir `merge_performed`" ile ilerlemiyor. İki kat koruma:

1. **Başka bir merge olamaz:** board'da yalnız tutorial kuyruğundan gelen iki
   T1 var (`tutorial_test` MATCH_DROP anında ölçüyor: tam bir parça, tier 1,
   bekleyen parça da T1), ikinci bırakmadan sonra girdi kilitli ve güçler
   pasif.
2. **Kimlik açıkça doğrulanıyor:** yalnız `MERGE_RESULT_TIER` (T1+T1 → T2)
   kabul edilir. Test, T5 ve T3 merge sinyallerinin adımı İLERLETMEDİĞİNİ,
   gerçek T2 merge'inin ilerlettiğini ve yalnız BİR `tutorial_first_merge`
   olayı yayıldığını gösteriyor.

### Kapı 4 — ilk gün kalıcılığı (disk alanları tek tek)

A gününde tamamlanmadan sonra DİSKTE: `onboarding_completed = true`,
`onboarding_completed_day = A`, `last_seen_day_key = A`; buna karşılık
`last_login_date` BOŞ, `daily_streak` 0, Hamur 0, `free_chest_claimed`
false, `ad_chests_claimed` 0, `dough_ad_claimed` false, `popup_seen_day`
BOŞ (pencere gösterilmedi, yanlışlıkla claim üretmedi), `day_key` BOŞ
(hiçbir günlük transaction çalışmadı), `powerup_starter_granted` true
(tutorial hediye vermedi/tüketmedi).

B gününde (yeniden açılış): +15 tam bir kez, seri 1, otomatik pencere tam
bir kez, `popup_seen_day = B`, üç kota da tam. B gününde ikinci açılış:
ikinci +15 YOK, ikinci pencere YOK.

## 12. Testler

- **`tools/tutorial_test.tscn`** — oturma niteliği + üretim izolasyonu,
  rehberli merge kimliği, ilk gün disk alanları, yeni kayıt açılışı, WELCOME girdi kapısı,
  FIRST_DROP clamp'i ve tek geçerli bırakma, MATCH_DROP hizalaması,
  GERÇEK merge şartı (T2 + skor + sayaç + tutorial T2'si board'da kalıyor),
  açıklama adımlarında girdi/dondurma ve "kart hedefi örtmüyor", tamamlanma
  atomikliği (iki alan tek transaction, çift tamamlanma yazmıyor), ilk gün
  bastırmasının tamamı, ertesi gün +15/seri, ATLA'nın aynı yoldan geçmesi,
  Android geri onayı, yarıda kapanma → baştan başlama, onboarded oyuncunun
  Level 1 tekrarında tutorial görmemesi, monetizasyon ertelemesi
  (round ortası yuva 0 + rıza başlamadı → kabuk geçişinde açılıyor).
- **`tools/daily_rewards_test.tscn`** — ilk gün kuralı bölümü eklendi
  (A günü bastırma, B günü normal döngü, migration'da bastırma yok).
- **`tools/monetization_test.tscn`** — onboarding öncesi rıza ertelemesi.
- **`tools/tutorial_shots.tscn`** — üç boyutta (720×1280, 1080×1920,
  1080×2340 → tuval 720×1280 / 720×1280 / 720×1560) adım çekimleri.

## 13. Açık noktalar

1. **A36 cihaz kapısı ÇALIŞTIRILMADI** — bu milestone masaüstünde kapandı.
2. Üretim engelleri değişmedi (ADS_SYSTEM §11): UMP sarmalayıcı boşluğu +
   `debug_geography` #120, COPPA/TFCD/TFUA kitle kararı, gerçek AdMob
   kimlikleri (App ID + banner + ödüllü + geçiş).
3. Tutorial metinleri yalnız Türkçe (v1 kapsamı; lokalizasyon non-goal).
