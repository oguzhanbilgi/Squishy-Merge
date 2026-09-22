# DAILY_REWARDS.md — Günlük ödüller, geçiş reklamı ve onboarding dikişi (M8.9-02)

> Kanonik doküman (owner kararı, 2026-09-22). Reklam mimarisi
> [ADS_SYSTEM.md](ADS_SYSTEM.md), rıza [PRIVACY_CONSENT.md](PRIVACY_CONSENT.md).
> Kilitli sayılar GAME_DESIGN §5.4.1 / §5.7.3 / §11'de; burada uygulanma biçimi.
>
> **Durum:** uygulama + deterministik testler + masaüstü görsel inceleme +
> TEST-reklam APK'sı tamam; **A36 cihaz kapısı henüz YOK** (owner/ChatGPT
> incelemesi sonrası ayrı adım). Üretim engelleri (UMP sarmalayıcı boşluğu,
> #120, COPPA, gerçek kimlikler) AÇIK — ADS_SYSTEM §11.

## 1. Dört bağımsız kota ailesi

| aile | kota | tüketen | nerede |
|---|---|---|---|
| **Ücretsiz günlük sandık** | günde **1** | `DailyRewards.claim_free_chest()` (tek transaction) | `SaveManager.daily_rewards.free_chest_claimed` |
| **Reklamlı günlük sandık** | günde **2 BAŞARILI** ödül | `DailyRewards.grant_ad_chest(day_key)` — yalnız "ödül kazanıldı" | `daily_rewards.ad_chests_claimed` (0..2) |
| **Reklamlı +150 Hamur** | günde **1 BAŞARILI** ödül | `DailyRewards.grant_ad_dough(day_key)` — yalnız "ödül kazanıldı" | `daily_rewards.dough_ad_claimed` |
| Ödüllü güç refill'i (M8.5-06, değişmedi) | günde 1, DÖRT gücün toplamı | `RewardedPolicy.grant` | `rewarded_power_date/grants` |
| Devam hakkı (M8.5-04, değişmedi) | round başına 2 | `GameBoard.grant_revive` | board sayacı |

Hiçbiri diğerinin kotasını tüketmez (`daily_rewards_test` "bağımsızlık").
Talep, reklamın açılması, yüklenememesi, ödülsüz kapanması, iptal ve gösterim
hatası hiçbir kotayı tüketmez ve hiçbir ödül vermez.

## 2. Gün anahtarı ve sıfırlama semantiği

- **Gün = cihazın yerel takvim tarihi**, `YYYY-MM-DD` (`Time.get_date_string_from_system`).
  Kayıt `daily_rewards.day_key` + o günün sayaçlarını tutar; başka bir gün
  okunduğunda sayaçlar **yazmadan** sıfır görünür, ilk işlem yeni günü yazar.
- **Geri alma koruması:** `daily_rewards.last_seen_day_key` görülen en yeni
  gün (yalnız ileri gider; `DailyRewards.observe_day()` açılışta ve öne
  dönüşte). Saat geriye alınırsa efektif gün = en yeni görülen gün → yeni
  ödül üretilmez, tarih yetişince normale döner; pencere bunu söyler
  ("Cihaz saati geri alınmış görünüyor…"). Saat dilimi yolculuğu aynı
  yoldan geçer: çökme/sürekli sıfırlama yok.
- **Saati ileri almak engellenemez.** Çevrimdışı yerel kayıt, sunucu yok;
  günlük giriş ödülü ve refill kotasıyla aynı bilinçli kabul. Sunucu
  doğrulaması olmadan yapılacak her "önlem" güvenlik tiyatrosu olurdu.
- Popup işareti `daily_rewards.popup_seen_day` ayrı alandır; ödül tüketmez.

## 3. Reklamlı akış (ödül yalnız callback'le)

```
pencere REKLAM İZLE → Main._request_daily_rewarded(kind)   (token++, gün anahtarı saklanır)
  → MonetizationManager.show_rewarded_daily_chest / _dough(main, day_key, token)
  → SDK rewarded_earned (aynı ad_id, açık talep)
  → Main.grant_daily_chest / grant_daily_dough(day_key, token)   (token + tür + gün eşleşmeli; token ÖNCE tüketilir)
  → DailyRewards.grant_ad_chest / grant_ad_dough(day_key)        (gün hâlâ aynı mı, kota var mı → TEK yazma)
  → pencere reveal / "+150 Hamur eklendi!"
```
Ödül türü **talep bağlamından** gelir (`RewardedKind.DAILY_CHEST` /
`DAILY_DOUGH` + `day_key` + `token`); görünen pencereden ASLA çıkarılmaz.
Çift callback (token sıfır), KAPAT/iptal (talep `cancelled`), gün değişimi
(A talebi, B ödülü → `grant_*` null), kota yarışı → ödül yok.

## 4. Günlük sandık loot reçetesi (DAILY profili — `DailyChestLoot`)

| adım | değer |
|---|---|
| garanti Hamur | **+15** (`GUARANTEED_DOUGH`) |
| bağımsız skin kurası | **%30** (`SKIN_CHANCE_PERCENT`) |
| kura tuttuysa rarity | Common %60 / Rare %25 / Epic %12 / Legendary %3 (`ChestSystem.RARITY_THRESHOLDS` — aynı kilitli eşikler) |
| skin seçimi | o rarity'de **sahip olunmayan** koleksiyon skinlerinden rastgele biri |
| rarity tükenmişse | skin yok; **+15 BONUS** Hamur (`EXHAUSTED_BONUS_DOUGH`) |

Sonuçlar: skin yok **+15** · yeni skin **+15 + skin** · kura tuttu/tükendi
**+30**. "Varsayılan" görünüm koleksiyon skini değildir ve havuza hiç girmez
(`SkinLibrary` yalnız 20 `.tres`). Level sonu / bonus sandık reçetesi
(`ChestSystem`: ya skin YA Hamur, 10/25/60/150, teselli 5) **DEĞİŞMEDİ**;
kod paylaşılmadı (`chest_system.gd` günlük reçeteyi bilmez — testle).

Kura verilen `RandomNumberGenerator` ile çekilir (`DailyRewards.set_rng`, testler
seed verir; production randomize). Global RNG'ye (drop bag) dokunulmaz.

## 5. Transaction / RNG kuralları

- Sonuç **claim transaction'ında** belirlenir: kura → `SaveManager.claim_daily_free_chest`
  / `grant_daily_ad_chest` / `grant_daily_ad_dough` (kota kontrolü BURADA da;
  kota + Hamur + skin tek `save_game()`); `DailyChestReward` değişmez nesne.
- Pencere yalnız gösterir: animasyon tekrarı, yeniden açılış, ikinci sinyal
  yeniden kura çekmez; ödül reveal'den ÖNCE diskte. Uygulama animasyon
  bitmeden kapansa da ödül tam bir kez verilmiş olur.
- Çift dokunuş: ücretsiz AÇ tek sinyal (pencere kilidi) + model ikinci
  çağrıya null; reklamlı butonlar talep açıkken kilitli.

## 6. GÜNLÜK ÖDÜLLER penceresi ve Mağaza girişi

- `scenes/ui/daily_rewards_popup.tscn` (`DailyRewardsPopup`): `UiKit.modal_shell`
  pembe kurdele "GÜNLÜK ÖDÜLLER" + oturmuş X; üç seçenek kartı (Refill kartı
  reçetesi): **ÜCRETSİZ SANDIK** (pembe kuyu, "Günde 1 · reklam yok", nane
  AÇ) · **+150 HAMUR** (altın kuyu, "Reklam izle · Günde 1", cyan REKLAM
  İZLE) · **REKLAMLI SANDIK** (lavanta film kuyusu, "Reklam izle · Günde 2",
  cyan REKLAM İZLE). Durum rozetleri: **HAZIR** (altın) / **ALINDI** /
  **REKLAM HAZIRLANIYOR** / **2 / 2 · 1 / 2** / **BUGÜNLÜK BİTTİ**. Sağlayıcı
  hazır değilken buton PASİF + kartta gerçek sebep ("Reklam hazırlanıyor…" /
  "Reklam şu anda kullanılamıyor." / "henüz bağlı değil"); pencere açıkken
  reklam yüklenince buton kendiliğinden açılır. Altlıkta not + **KAPAT**
  (her zaman; X / karartma / Android geri aynı).
- **Reveal:** kartlar yerine owner sandığı (`RewardGem`, skin rarity'sine
  göre efekt) açılır (0,32 s) → "+15 HAMUR" (0,58 s) → skin varsa
  `ResultRewardCard` (YENİ SKİN, gerçek final sanat, 0,92 s) → **DEVAM**
  1,2 s'de açılır; X her an kapatır. Ses/titreşim round sonuyla aynı eşleme
  (`chest_open` → `play_reward(rarity)`, Legendary SPECIAL).
- **Mağaza:** kaydırılan içeriğin EN ÜSTÜNDE "GÜNLÜK ÖDÜLLER" bölüm plakası +
  tek geniş kart (owner sandığı, başlık, alt satır, durum rozeti **HAZIR** /
  **N ödül kaldı** / **BUGÜNLÜK TAMAMLANDI**, cyan AÇ → aynı pencere). Kart
  ScrollContainer içinde `MOUSE_FILTER_PASS` (06.3 kuralı). Kaydırma dip
  payı `UiKit.bottom_inset` → banner ile örtüşmez.
- Banner yuvası varken bütün `modal_shell` pencereleri banner'ın **üstündeki**
  alanda ortalanır ve gövde tavanı `bottom_inset` ile hesaplanır (pencere
  altlığı hiçbir zaman AdView'un altına girmez) — `UiKit._seat_modal_above_banner`.

## 7. Otomatik günlük pencere

Günde **en fazla bir kez**: `Main._maybe_auto_open_daily_rewards()` —
`_ready` sonunda, günlük giriş ödülü penceresi kapanınca, her `_show_tab`'da
ve öne dönüşte (`NOTIFICATION_APPLICATION_RESUMED` → `DailyRewards.observe_day`).
Koşullar: onboarding tamam, `popup_seen_day != day_key`, kabuk ekranında
(oyun / sonuç yok), başka pencere açık değil, tam ekran reklam yok. Gösterim
anında `popup_seen_day` yazılır; **kapatmak hiçbir ödül tüketmez**;
Mağaza'dan gün boyu yeniden açılır. Oyun içinde gün değişirse pencere kabuğa
dönünce açılır (oyun ortasında asla).

**Sıra (owner dikkatine):** mevcut günlük giriş ödülü penceresi (M8.6-08,
"+15 HAMUR / N. GÜN", GAME_DESIGN §5.4) DEĞİŞMEDİ ve önce açılır; kapanınca
GÜNLÜK ÖDÜLLER gelir. İki penceredir — birleştirme owner kararı (§10).

## 8. Geçiş (interstitial) reklamı

- **Aktif süre saati** (`MonetizationManager._tick_active`, `PROCESS_MODE_ALWAYS`):
  yalnız uygulama ön planda ve kullanılabilirken sayar. SAYILMAZ: arka plan /
  ekran kapalı (`APPLICATION_PAUSED`), UMP/gizlilik formu kaplarken, ödüllü
  reklam ekranda (ödül alındı ama etkinlik hâlâ üstte dahil), geçiş reklamı
  ekranda, onboarding tamamlanmamış. Mola, Ayarlar, Devam, Refill gibi
  oyun içi pencereler SAYILIR. `INTERSTITIAL_INTERVAL_SEC = 900` → `eligible`
  (olay `interstitial_eligible`); **hemen gösterilmez**.
- **Doğal mola — tek gösterim noktası:** `Main._on_round_finished` → round
  KESİN bitti, devam kararları tamamlandı, `RESULT_DELAY` (0,8 s) sonra,
  sonuç ekranından ÖNCE `_ads.try_show_interstitial("round_finish", present)`.
  Uygun + READY + bekleme yok + başka tam ekran reklam yok → gösterilir;
  sonuç reklam kapanınca `present` ile **tam bir kez** açılır (`_result_seq`
  sırası: geç/çift callback ikinci sonuç üretemez, sonuç kaybolmaz). Aksi
  hâlde (hazır değil / hata / rıza yok / bekleme) **sonuç HEMEN** açılır ve
  uygunluk korunur; sonuç asla reklam yüklemesi ya da bekleme için bekletilmez.
  Asla: aktif drop/merge, devam teklifi, ödüllü reklam, sandık reveal'i
  (sonuç ekranı), UMP formu, tutorial (onboarding false).
- **Saat sıfırlama:** yalnız SDK `interstitial_showed` (gerçek tam ekran
  gösterim) → `active_elapsed = 0`, `eligible = false`. Yükleme hatası,
  gösterim hatası, onay zaman aşımı, hazır olmayan mola sıfırlamaz.
- **Bekleme:** herhangi bir tam ekran reklam (ödüllü ya da geçiş)
  kapanışından sonra `FULLSCREEN_AD_COOLDOWN_SEC = 60` aktif saniye boyunca
  geçiş reklamı bastırılır (art arda iki tam ekran reklam yok; Google
  "başka bir interstitial'dan hemen sonra" yasağı). Bekleme sırasında biten
  round: mola atlanır (`interstitial_skipped_not_ready` reason=cooldown),
  uygunluk kalır, sonuç hemen.
- **Dışlama:** ödüllü talep/gösterim varken geçiş gösterilmez; geçiş
  gösterilirken `is_rewarded_ready()` false, ödüllü talep "Reklam
  gösteriliyor…" ile reddedilir.
- **Yükleme:** SDK hazır + rıza + onboarding sonrası tek reklam önyüklenir;
  kapanış/hata sonrası sıradaki; no-fill → 15/60/180/600 sn, en çok 6 deneme;
  uygun olunca ve hazırsız molada talep üzerine bir deneme daha (≥ 3 s);
  60 s yükleme zaman aşımı; Google'ın 1 saatlik süresi için yüklü reklam
  55 dk'yı geçince atılıp tazelenir. Eklenti `show` sonrası "gösterildi"
  demezse (yüklenmemiş reklamda sinyalsiz uyarı) 5 s onay zaman aşımı →
  mola sürer, saat sıfırlanmaz; geç gelen gösterim yalnız beklemeyi başlatır.
  Öne dönüşte kapanış gelmezse 3 s pay.
- **Test birimi:** `ca-app-pub-3940256099942544/1033173712` (Google'ın resmi
  Android interstitial test birimi; `android_export.cfg [Debug]`), `[Release]
  interstitial_id=""` — gerçek modda boş/örnek kimlik `AdConfig`'i geçersiz
  kılar (reklam hiç başlamaz).

## 9. Onboarding dikişi (tutorial M8.10)

- Kayıt alanı `onboarding_completed` (`SaveManager`): **yeni kayıt false**;
  **eski kayıt (anahtar yok)** `load_game` migration'ı: `highest_level_unlocked
  > 1` VEYA en az bir level yıldızı VEYA `total_merges > 0` VEYA sonsuz
  rekoru VEYA açılmış skin → **true** (oynanmışlık kanıtı); yalnız Hamur /
  giriş tarihi kanıt DEĞİL (günlük giriş ödülü tek açılışta 15 Hamur verir).
  Karar bellekte, diske sonraki doğal kayıtla iner (okumada yazma yok).
  Anahtar açıkça false ise migration dokunmaz.
- **Sözleşme (M8.10):** tutorial bitince `SaveManager.complete_onboarding()`
  (tek yazma, geri alınmaz) + `MonetizationManager.set_onboarding_completed(true)`
  → yuva hesaplanır, banner/ödüllü/geçiş yüklemeleri başlar, günlük pencere
  ve Mağaza kartı görünür. Tutorial UX'i bu milestone'da YOK.
- **false iken bastırılanlar:** banner (yuva 0 — tam eski düzen, Harita ve
  oyun dahil), geçiş reklamı (yükleme yok, saat durur), otomatik günlük
  pencere, Mağaza GÜNLÜK ÖDÜLLER bölümü (gizli; pencere de açılmaz), ödüllü
  devam/refill sunumu (CTA pasif + "Reklam şu anda kullanılamıyor.", reklam
  yüklenmez). Günlük GİRİŞ ödülü penceresi (M8.6-08) bu listede değil —
  M8.10 tutorial akışı karar verir.

## 10. Açık noktalar / owner kararları

1. **İki günlük pencere:** giriş ödülü (M8.6-08, +15/streak) + GÜNLÜK ÖDÜLLER
   art arda açılıyor. Birleştirme (streak şeridi GÜNLÜK ÖDÜLLER'e taşınır,
   eski pencere emekli) ayrı bir karar/milestone.
2. **Ödül callback'i reklam kapanmadan geliyor** (A36 gözlemi, ADS_SYSTEM §12):
   günlük reveal de reklam hâlâ üstteyken başlayabilir; veri doğru.
3. A36 cihaz kapısı: gerçek test interstitial'ı doğal molada, gerçek banner
   Harita/oyun, günlük reklamlı akış, arka plan/öne dönüş.
4. Üretim engelleri değişmedi: UMP sarmalayıcı boşluğu + #120, COPPA/TFCD/
   TFUA, gerçek AdMob kimlikleri (interstitial birimi dahil: artık 3 birim).

## 11. Testler

- `tools/daily_rewards_test.tscn` — **111 kontrol:** migration (dosyasız /
  kanıtlı / kanıtsız / açık false / complete tek yazma), gün anahtarı (ileri,
  geri, aynı gün yeniden açılış, observe), kotalar (ücretsiz 1 + ikinci bloke,
  reklamlı 2 + üçüncü bloke, +150 bir kez, eski gün callback'i, bağımsızlık
  refill/devam), loot (4000 kura: ≥ 15, ~%30, rarity dağılımı, yalnız sahip
  olunmayan, Varsayılan asla, tükenmiş +30, yalnız Legendary tükenmiş,
  determinizm, level sandığı değişmedi), Mağaza kartı + pencere (durumlar,
  çift dokunuş tek transaction, reveal öncesi disk, DEVAM ~1,2 s, kura
  tekrarı yok, Android geri, saat notu), Main + sahte SDK (talep bağlamı,
  çift ödül, iptal, gösterim hatası, ödülsüz kapanış, gün değişimi),
  otomatik pencere (giriş ödülünden sonra, günde bir, oyun içinde ertelenir),
  onboarding false (yuva 0, yükleme yok, pencere/kart yok, devam CTA pasif) →
  `complete_onboarding` ile açılış. Kayıt byte-identical.
- `tools/interstitial_test.tscn` — **60 kontrol:** önyükleme, 899/900, dışlanan
  anlar (arka plan, ödüllü, form, onboarding), doğal mola (uygun değil / oyun
  ortası / hazır / hazır değil / gösterildi → saat 0 / kapanış → callback bir
  kez / çift callback), bekleme 60 (ödüllü sonrası, 59/60), dışlama, yükleme
  hatası + sınır + talep, gösterim hatası, onay zaman aşımı + geç gösterim,
  süresi dolma, yükleme zaman aşımı, öne dönüş payı; Main: sonuç hemen /
  reklam → sonuç bir kez / geri yok sayılır / bekleme atlar / gösterim hatası.
- `tools/monetization_test.tscn` — **191 kontrol** (yeni yüzeyler, interstitial
  kimliği fail-closed, 28 olay, onboarding yuva).
- Görsel: `tools/daily_ads_shots.tscn` (§ ADS_SYSTEM §13).
