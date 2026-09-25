<!-- M8.10 (2026-09-22): rıza (UMP) akışı artık onboarding tamamlanana kadar
     BAŞLAMIYOR — tutorial'ın üstüne gizlilik formu gelmesin. Rıza ŞARTI
     kaldırılmadı: `_ads_enabled()` hâlâ izin + SDK istiyor, yani ilk reklam
     talebinden ÖNCE akış mutlaka çalışıyor. Ayrıca tutorial'dan doğan ilk
     Level 1 round'unun ortasında banner yuvası açılmıyor (bir sonraki güvenli
     kabuk/round geçişinde açılıyor). Ayrıntı: ../TUTORIAL_SYSTEM.md §8.

     A36'DA DOĞRULANDI (M8.10.1, 2026-09-22): tutorial boyunca ve
     tamamlanmadan sonraki round boyunca UMP log satiri SIFIR; kabuga
     donuste 0 -> 16 satir (IABTCF_gdprApplies=0, TR/EEA disi ->
     NOT_REQUIRED), SDK basladi, test banner'i dogru yuvayla gorundu.
     Uc Ana Sayfa<->Harita turu + arka plan/on plan IKINCI bir riza
     guncellemesi uretmedi. -->

# ADS_SYSTEM.md — AdMob reklam sistemi (M8.9-01 / M8.9-02)

> Kanonik doküman. Kilitli ürün kuralları GAME_DESIGN §5.4.1 / §5.7.3 / §11 /
> §12'de; burada onların **uygulanma biçimi** ve teknik seçimler anlatılır.
> Rıza / gizlilik: [PRIVACY_CONSENT.md](PRIVACY_CONSENT.md); günlük ödüller,
> geçiş reklamı politikası ve onboarding dikişi: [DAILY_REWARDS.md](DAILY_REWARDS.md).
>
> **Durum (2026-09-22):** M8.9-01 temeli (ödüllü devam/refill + banner + UMP)
> A36'da doğrulandı ve main'de (33b6382); **M8.9-02 de main'de (9561a4c,
> ff-only, push edildi).**
>
> **M9-01 (2026-09-22, dal `task/036-production-release-readiness`; M9-01.1 A36
> kapısıyla birlikte 2026-09-24'te main'e ff-only alındı):** eklentinin UMP boşluğu + #120 KODDA kapandı (v6.0 + yama,
> deterministik yeniden derleme — `tools/admob_plugin/`); izin kapısı UMP
> `canRequestAds()` (SDK başlatma + her yükleme öncesi); gizlilik seçenekleri
> resmî durum/form; kimlikleri BUILD TÜRÜ seçer (debug = yalnız Google test,
> release = dört gerçek kimlik, fail-closed); `[Audience]` dikişi; release
> kapısı + pipeline (`tools/release/`, §9). **Hâlâ üretime hazır DEĞİL:**
> 13–17 genç reklam işlemi / yargı bölgesi uyum stratejisi, gerçek kimlikler,
> upload anahtarı, gizlilik politikası URL'i owner'da (paket kimliği
> 2026-09-24'te kilitlendi: `com.obappstudio.squishymerge`; ürün kitlesi
> kararı 2026-09-25: 13+ genel kitle, `general_13_plus` — [AUDIENCE_DECISION.md](AUDIENCE_DECISION.md) §0; 13–17 uyumu AÇIK — §2.2). Yamalı AAR'ın EEA / NOT_EEA / gizlilik seçenekleri
> akışı Samsung A36'da doğrulandı (M9-01.1, PRIVACY_CONSENT §7). **M8.9-02** (owner kararı): Harita +
> oyun banner'ı, geçiş reklamı (900 sn aktif süre, yalnız round bitişi molası,
> 60 sn tam ekran beklemesi), günlük ödüller (ücretsiz sandık 1/gün, reklamlı
> sandık 2/gün, reklamlı +150 Hamur 1/gün), otomatik günlük pencere, Mağaza
> girişi, `onboarding_completed` dikişi — deterministik testler + masaüstü
> görsel inceleme + TEST-reklam APK'sı + **A36 cihaz kapısı GEÇTİ (M8.9-02.2,
> §14)**. **Üretime hazır DEĞİL:** ~~eklentinin UMP yüzeyi (PRIVACY_CONSENT
> §4) + #120~~ (M9-01'de kapandı, M9-01.1'de A36'da doğrulandı), ~~COPPA/kitle kararı (§6) açık~~ (2026-09-25: ürün kitlesi 13+ KAPALI; 13–17 genç reklam işlemi / yargı bölgesi uyumu AÇIK — AUDIENCE_DECISION §2.2); üretim kimliği YOK (artık 3 birim).

## 1. Kapsam (v1 monetizasyon planı)

| ürün | durum | kural |
|---|---|---|
| Ödüllü devam (revive) | ✅ bağlı, test reklamı, A36'da doğrulandı | round başına en fazla 2 başarılı devam (board sayar) |
| Ödüllü güç refill'i | ✅ bağlı, test reklamı, A36'da doğrulandı | günde 1, DÖRT gücün toplamı; yalnız seçilen güce +1 |
| Ödüllü günlük sandık (M8.9-02) | ✅ bağlı, test reklamı, cihazda henüz değil | günde 2 BAŞARILI ödül; ayrı kota (DAILY_REWARDS §1) |
| Ödüllü günlük +150 Hamur (M8.9-02) | ✅ bağlı, test reklamı, cihazda henüz değil | günde 1 BAŞARILI ödül; ayrı kota |
| Ücretsiz günlük sandık (M8.9-02) | ✅ reklam yok | günde 1; loot reçetesi DAILY_REWARDS §4 |
| Banner (uyarlanabilir sabit, alt) | ✅ Ana Sayfa / Harita / Mağaza / Koleksiyon / oyun (M8.9-02 ile Harita + oyun eklendi; cihazda henüz değil) | sonuç ekranında GİZLİ; onboarding bitmeden yuva yok |
| Geçiş (interstitial) reklamı (M8.9-02) | ✅ bağlı, test birimi, cihazda henüz değil | 900 sn AKTİF süre → uygun; YALNIZ round bitişi molasında, sonuçtan önce; 60 sn tam ekran beklemesi (DAILY_REWARDS §8) |
| Rewarded interstitial / app-open / native / mediation | ❌ bilerek YOK | — |
| IAP / Billing, analitik sağlayıcı, üretim kimlikleri | ❌ bu milestone'da yok | sonraki adımlar |

Hamur satın alma yolu (`PowerUpEconomy.purchase`) reklamdan tamamen bağımsız
kaldı; skinler asla reklam/paraya bağlı değil.

## 2. Seçilen eklenti ve SDK sürümleri (araştırma 2026-09-21)

| | |
|---|---|
| Eklenti | `godot-sdk-integrations/godot-admob` **v6.0** (2026-02-01), tag commit `90e3c616ea3c680e3875c31e6bcccffbebbe9d3b` |
| Lisans | MIT (`addons/AdmobPlugin/LICENSE`) |
| Kurulum | AssetLib ile aynı release zip'i (`AdmobPlugin-Android-v6.0.zip`, SHA-256 `9ec26002…973f24`) `addons/AdmobPlugin/` altına kopyalandı (M8.9-01). **M9-01:** tek kaynak yaması `tools/admob_plugin/0001-ump-privacy-options-and-debug-geography.patch` (3 dosya, +73/−2: `can_request_ads` / `get_privacy_options_requirement_status` / `show_privacy_options_form` + #120 `instanceof Number`); iki AAR + `Admob.gd` upstream derleme betikleriyle yeniden üretildi (`build_patched_plugin.sh verify` → BYTE-IDENTICAL); ayrıntı `addons/AdmobPlugin/VERSION.md` |
| Godot uyumu | eklenti `godot-lib 4.6.stable` ile derlendi; v7.0 (2026-05-27) **Godot 4.7 beta1** hedefli ve bakımcı issue #122'de "4.6.x için v6.0 kullanın" diyor → v6.0 |
| Google Mobile Ads SDK | `com.google.android.gms:play-services-ads:24.9.0` (eklentinin export'ta eklediği Maven bağımlılığı). Google'ın "Mobile Ads SDK (Legacy)" hattı; 24.x **Supported**, deprecation 2027-06-30, sunset 2028-06-30 (deprecation sayfası) |
| UMP SDK | `com.google.android.ump:user-messaging-platform:3.2.0` (play-services-ads-api 24.9.0 POM'undan geçişli) |
| Android | AAR minSdk 24; Godot 4.6.3 Gradle şablonu compileSdk 36 / targetSdk 36 / minSdk 24; Gradle 8.11.1, AGP 8.x; JDK 17 |
| Eklenti API'si | Godot Android plugin **v2** (`org.godotengine.plugin.v2.AdmobPlugin`) |

**Not — Google "GMA Next-Gen SDK":** Google 2026-01'de yeni nesil Android
SDK'sını (`com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk`, 1.4.0)
duyurdu; eski `play-services-ads` "maintenance mode"da ama 25.5.0 (2026-09-17)
hâlâ yayınlanıyor ve 24.x desteği 2027-06'ya kadar. Godot eklentisi legacy
SDK'yı sarıyor; Next-Gen'e geçiş eklentinin gelecek sürümlerine bağlı
(owner/ChatGPT kararı, v1 için gerekli değil).

## 3. Mimari

```
Main (scenes/main.tscn)
 ├─ MonetizationManager  (scripts/ads/monetization_manager.gd)  ← tek soyutlama
 │    └─ AdBackend       (scripts/ads/ad_backend.gd, soyut)
 │         ├─ AdmobBackend   (scripts/ads/admob_backend.gd) → Admob düğümü (addons/AdmobPlugin)
 │         └─ FakeAdBackend  (tools/fake_ad_backend.gd, yalnız test; export dışı)
 ├─ ReviveOffer / PowerRefill  (yalnız Main'in sağlayıcı dikişini görür)
 └─ SettingsPanel             (privacy_options_required / show_privacy_options)
AdEvents (scripts/ads/ad_events.gd)  — analitik olay dikişi, sağlayıcı yok
AdConfig (scripts/ads/ad_config.gd)  — android_export.cfg → is_real + kimlikler
```

- Oyun/UI eklenti içlerini bilmez. Main mevcut dikişi kullanır:
  `set_rewarded_provider(manager)` + `show_rewarded_revive(main)` /
  `show_rewarded_power(main, type, token)` (M8.5-04/06'dan beri aynı),
  M8.9-01'de eklenen `is_rewarded_ready()` / `rewarded_note()` /
  `ensure_rewarded()` / `cancel_rewarded_request()` / `set_surface()` ve
  M8.9-02'de eklenen `show_rewarded_daily_chest / _dough(main, day_key, token)`,
  `try_show_interstitial(break_name, callback)`, `set_onboarding_completed(done)`.
  Ödül türü talep bağlamından (`RewardedKind` REVIVE / REFILL / DAILY_CHEST /
  DAILY_DOUGH + güç / gün anahtarı + token); görünen pencereden çıkarılmaz.
  Test stub'ları (refill_test, revive_refill_ui_test…) bu yeni metotları
  sunmadığı için "bağlı = hazır" sayılır — eski testler değişmeden yeşil.
- **Eklenti yoksa** (masaüstü, headless) `MonetizationManager.create()` null
  döner; Main sağlayıcısız kalır (M8.6-10 davranışı: CTA pasif + "Ödüllü
  reklam henüz bağlı değil."). Dördüncü autoload EKLENMEDİ: yönetici Main'in
  çocuğu (Main uygulama ömrü boyunca yaşar), testler Main'i her kurduğunda
  kendi yöneticisini alır.
- Testler `Main.ads_backend_override` (static) ile sahte arka ucu takar.

## 4. Rıza ve başlatma yaşam döngüsü

Özet (ayrıntı PRIVACY_CONSENT.md):

```
onboarding tamam (M8.10) → CONSENT_CHECKING (update_consent_info)
   ├─ REQUIRED + form var → CONSENT_FORM (load→show) → kapanış → canRequestAds()
   ├─ başarı → canRequestAds() true → ADS_ALLOWED → MobileAds.initialize
   │           canRequestAds() false → ADS_NOT_ALLOWED (+ sınırlı yeniden deneme)
   └─ update HATASI → canRequestAds() (önceki oturumun rızası):
        true → ERROR_WITH_PREVIOUS_STATE (reklam istenir), false → ADS_NOT_ALLOWED
initialization_completed → sdk_ready → ödüllü + geçiş önyükleme + banner senkronu
her yükleme (ödüllü / geçiş / banner) ve SDK başlatma ÖNCESİ canRequestAds() yeniden
```

M9-01: karar resmî UMP `canRequestAds()` (yamalı eklenti); eklenti sunmuyorsa
M8.9 türetmesi + uyarı (PRIVACY_CONSENT §4). Reklam yalnız `ads_allowed() and
sdk_ready` iken VE istek anında `canRequestAds()` true iken istenir. Oyun
rızayı BEKLEMEZ (spinner yok): Ana Sayfa normal açılır, form üstte belirir.

## 5. Ödüllü reklam durum makinesi

`RewardedState`: `IDLE → LOADING → READY → SHOWING → REWARD_EARNED → DISMISSED
→ (önyükleme) LOADING …`, hata yolları `FAILED`.

| olay | davranış |
|---|---|
| SDK hazır / kapanış / iptal sonrası | `_preload_rewarded()` — tek yükleme, `LOADING` |
| `rewarded_loaded` | `READY`, deneme sayacı 0, `rewarded_availability_changed` → açık pencere CTA'sı açılır |
| `rewarded_failed_to_load` | `FAILED`, geri çekilme 5/15/45/120/300 sn (son değer tekrar), en çok 8 deneme/döngü; pencere açılışı (`ensure_rewarded`) ≥ 3 sn aralıkla döngüyü sıfırlayıp bir deneme daha yapar; 60 sn cevap yoksa zaman aşımı = hata (geç gelen yükleme yine kabul) |
| `show_rewarded_*` | yalnız `READY`: talep kaydı `{id, kind, type, token, ad_id, earned, cancelled, main}`; `SHOWING`; aynı anda ikinci tam ekran reklam yok (devam + refill birlikte olamaz, çift dokunuş reddedilir) |
| `rewarded_earned` | açık talep + aynı `ad_id` + daha önce ödül verilmemiş → `REWARD_EARNED` ve **tek ödül yolu**: devam `Main.grant_revive()`, refill `Main.grant_rewarded_power(type, token)`; çift/geç/eski/iptal edilmiş → `stale` olay, ödül yok |
| `rewarded_dismissed` | talep kapanır; ödül yoksa Main'e "Ödül için reklamın tamamını izlemen gerekiyor." (kota/hak TÜKETİLMEZ); sonraki reklam önyüklenir |
| `rewarded_failed_to_show` | "Reklam gösterilemedi, tekrar dene."; reklam önbellekten düşer; yenisi yüklenir |
| uygulama öne dönüşü | `SHOWING` sürüyorsa 3 sn pay; kapanış gelmezse ödülsüz kapanış varsayılır (sonsuz "gösteriliyor" yok) |

Kota/hak kontrolleri **yöneticide DEĞİL**, kilitli yerlerde: board (2/round),
`Main.grant_rewarded_power` (token + tip) ve `RewardedPolicy.grant` /
`SaveManager.grant_rewarded_powerup` (1/gün, tek transaction); günlük
`Main.grant_daily_chest / grant_daily_dough` (token + tür + gün) →
`DailyRewards.grant_*` → `SaveManager.grant_daily_*` (tek transaction).
Yönetici kayda hiç yazmaz. Tek tam ekran reklam kuralı geçiş reklamını da
kapsar: ödüllü talep açıkken geçiş gösterilmez, geçiş gösterilirken ödüllü
"hazır" değildir (talep "Reklam gösteriliyor…" ile reddedilir).

### 5.1 Pencere durumları (M8.6-10 sözleşmesi korunarak)

| sağlayıcı durumu | CTA | not |
|---|---|---|
| sağlayıcı yok (masaüstü) | pasif | "Ödüllü reklam henüz bağlı değil." |
| rıza/SDK/yükleme bekliyor | pasif | "Reklam hazırlanıyor…" |
| rıza yok / yükleme hatası (geri çekilmede) | pasif | "Reklam şu anda kullanılamıyor." |
| yüklü | **aktif** | — |
| talep gönderildi | kilitli | "Reklam isteniyor…" |
| gösteriliyor | kilitli | "Reklam gösteriliyor…" |
| ödülsüz kapandı | hazırsa aktif | "Ödül için reklamın tamamını izlemen gerekiyor." |
| hak/kota bitti | pasif | mevcut metinler (değişmedi) |

Pencere açıkken reklam yüklenirse CTA kendiliğinden açılır
(`Main._on_rewarded_availability_changed` → `refresh_provider` / `refresh`).
Oyuncu her durumda BİTİR / KAPAT / Hamurla al yollarına sahip.

## 6. Banner

- Biçim: **uyarlanabilir sabit (anchored adaptive)**, ekran genişliği, ALT
  kenar, `anchor_to_safe_area = true` (nav bar / cutout içinde).
- **Yüzeyler (M8.9-02 owner kararı): Ana Sayfa, Harita, Mağaza, Koleksiyon,
  oyun ekranı.** GİZLİ: sonuç ekranı (`Surface.RESULT`), tam ekran reklam
  anları (SDK zaten kaplar), onboarding tamamlanmamış (yuva da yok).
  Pencereler (Devam / Refill / Ayarlar / Mola / GÜNLÜK ÖDÜLLER) banner'ı
  gizlemez; bütün `modal_shell` pencereleri banner'ın **üstündeki** alanda
  ortalanır ve gövde tavanı `bottom_inset` ile hesaplanır — pencere altlığı
  hiçbir zaman AdView'un altına girmez (`UiKit._seat_modal_above_banner`).
  M8.9-01'in "Harita/oyun dışarıda" ertelemesi owner kararıyla kalktı.
  - *Oyun:* `GameplayLayout` BANNER dikişi (M8.6-02) artık
    `effective_banner_height(view) = max(test override, UiKit.bottom_inset)`
    ile dolar: STRIP ve BOARD yukarı kayar, hiçbir kontrol/kap yuvaya girmez
    (`gameplay_shell_test` seam kontrolleri). **Kompakt mod** (yuva varken
    kalan yükseklik < 1240, yani 16:9): önce dekoratif aralıklar 8→4 / dip 10→6
    (16 px), sonra kap ölçeği: 720×1280'de zoom 1,064 → 0,962 (−%10; T1 çapı
    46,8 → 42,3 tuval px), A36'da (720×1560) L1–L4 kap genişlik sınırlı → değişim
    0, L5+ 1,20 → 1,18. **Fizik, kap ölçüleri, FLOOR_Y, taşma çizgisi,
    yarıçaplar, güç davranışı DEĞİŞMEDİ** — yalnız kamera/yerleşim.
  - *Harita:* dünya dikdörtgeni yuva kadar kısalır (`_fit_world`). Cover
    ölçeğiyle kale üst satırın altında VE level 1 OYNA plakası yuvanın
    üstünde kalıyorsa (A36 ve uzun ekranlar) her şey aynen; 16:9'da iki uç
    birlikte sığmaz (gerekli 1106 doku px, mevcut ~1087) → zemin dikeyde
    %2,8 sıkıştırılır (atlas bölgesi + STRETCH_SCALE; gözle seçilmez,
    düğümler aynı dönüşümle), kırpma iki ucu kurtaracak şekilde dağıtılır.
    Yuva 0 iken eski cover yerleşimi birebir (map_ui_test 127).
- **Yuva:** `MonetizationManager._compute_banner_slot()` açılışta bir kez
  `AdSize.getPortraitAnchoredAdaptiveBannerAdSize(genişlik)` yüksekliğini
  (dp) × yoğunluk × (720 / pencere genişliği) tuval pikseline çevirir ve
  `UiKit.set_banner_slot()`'a yazar (A36: 64 dp × 2.625 → 168 px → 112
  tuval px; 16:9 720p telefonda ~112). Alt bütçe `UiKit.bottom_inset(view)
  = safe_bottom + slot` (Ana Sayfa OYNA yukarı, Mağaza/Koleksiyon kaydırma
  dip payı + Mağaza toast'u yukarı, Harita dünyası, oyun STRIP/BOARD).
  Yuva oturum boyunca SABİT: banner dolmasa da düzen zıplamaz, boşken zemin
  görünür. Eklenti yoksa 0 (masaüstü düzeni birebir eski); **onboarding
  tamamlanmamışsa 0** (tutorial tam düzen), tamamlanınca hesaplanır
  (`set_onboarding_completed(true)` → `banner_slot_changed`).
- **Yaşam döngüsü:** `set_surface()` her ekran geçişinde (Main `_show_tab`,
  `_start_level`, sonuç). `LOADED` banner yüzey dışında `hide`, yüzeye
  dönünce `show` (yeni yükleme yok); SDK'nın otomatik yenilemesi
  (`banner_ad_refreshed`) durumu değiştirmez. No-fill → 15/60/180/600 sn
  geri çekilme, en çok 6 deneme; sınır dolunca gezinme yeni istek açmaz.
  Uygulama öne dönünce senkron (çift gösterim yok). Yönetici silinirken
  banner gizlenir, yuva sıfırlanır. Gezinme döngüsü (Ana Sayfa → Harita →
  Mağaza → Koleksiyon → oyun → sonuç → Ana Sayfa) tek AdView, tek yükleme,
  yalnız sonuçta hide (monetization_test).

## 7. Analitik olay dikişi (`AdEvents`)

Sağlayıcı YOK (sonraki milestone). `AdEvents.emit(name, ctx)`; abone
`subscribe(callable)`; son 200 olay bellekte. **28 olay:**

- Ödüllü: `rewarded_requested` (oyuncu CTA), `rewarded_loaded`,
  `rewarded_load_failed`, `rewarded_showed`, `rewarded_impression`,
  `rewarded_earned`, `rewarded_dismissed`, `rewarded_show_failed`. Bağlam:
  `placement` (`revive` / `refill` / `daily_chest` / `daily_dough` /
  `preload`), refill'de `power` (kayıt anahtarı), günlükte `day_key`,
  `ad_id`, `code`, `message`, `stale`.
- Banner: `banner_loaded` (`refreshed` bayrağı), `banner_load_failed`,
  `banner_impression`, `banner_clicked` (+ `surface`).
- Geçiş (M8.9-02): `interstitial_loaded`, `interstitial_load_failed`,
  `interstitial_eligible`, `interstitial_showed`, `interstitial_impression`,
  `interstitial_dismissed`, `interstitial_show_failed`,
  `interstitial_skipped_not_ready` (`reason`: not_eligible / not_ready /
  failed / expired / cooldown / rewarded_active / showing / consent /
  disabled). Hepsinde `active_elapsed_sec`; gösterim yolunda `natural_break`
  (`round_finish`).
- Günlük (M8.9-02): `daily_popup_shown` (`auto`, `remaining`),
  `daily_popup_closed`, `daily_free_chest_claimed`, `daily_ad_chest_requested`,
  `daily_ad_chest_earned` (`remaining`), `daily_dough_requested`,
  `daily_dough_earned`, `daily_chest_result` (`source`, `dough`, `skin`,
  `rarity`, `skin_rolled`, `skin_exhausted`). Hepsinde `day_key`.
- Ortak: `t_msec`. Firebase / analitik SDK bilerek entegre edilmedi.

## 8. Test ve üretim yapılandırması

- Tek dosya: `addons/AdmobPlugin/android_export.cfg` — hem eklentinin export
  kancası (manifest `APPLICATION_ID`) hem `AdConfig` (çalışma zamanı reklam
  birimi kimlikleri) okur. Godot "all_resources" export'u `.cfg` dosyasını
  PAKETLEMEZ; proje eklentisi `addons/squishy_ads_export/` dosyayı
  `EditorExportPlugin.add_file` ile PCK'ye ekler ve export anında doğrular
  (log: `SquishyAdsExport: paketlendi -> AdConfig(...)`). Export edilmiş
  build'de dosya yoksa `AdConfig` KAPALI kalır (test varsayılanına düşmez). **Şimdi:** `is_real=false`, Google örnek
  kimlikleri (app `…~3347511713`, rewarded `…/5224354917`, adaptive banner
  `…/9214589741`, **interstitial `…/1033173712`** — M8.9-02). Eklentinin kendi
  varsayılan banner kimliği (`…/2014213617`) Google'ın *katlanabilir* banner
  örneğidir, kullanılmıyor.
- **M9-01 — kimlikleri BUILD TÜRÜ seçer** (`AdConfig.current_build_type()` =
  `OS.is_debug_build()`; elle çevrilen bayrak değil):
  - **DEBUG build** (editör, headless testler, debug APK, QA paketi): YALNIZ
    `[Debug]` Google örnek kimlikleri. Orada Google örnek yayıncısı
    (`ca-app-pub-3940256099942544`) dışında bir kimlik varsa yapılandırma
    GEÇERSİZ → reklam yok. Debug/QA build'i hiçbir koşulda canlı birim
    isteyemez; `[General] is_real=true` olsa bile.
  - **RELEASE build:** YALNIZ `[Release]` + `is_real=true`. Dört kimlik de
    dolu, biçimli (`ca-app-pub-<16>~<10>` / `…/<10>`), Google örneği değil, aynı
    yayıncıdan, birim kimlikleri birbirinden farklı olmalı; tek sorun bile →
    GEÇERSİZ → `AdmobBackend.create` null → reklam HİÇ yok (fail-closed; test
    kimliğine sessiz düşüş yok).
  - Tek doğrulayıcı `AdConfig.problems()`; export anında
    `addons/squishy_ads_export` export'un türüyle doğrular; release kapısı
    (§9) aynı listeyi OWNER engeli olarak raporlar.
- **Üretim adımı (owner):** AdMob konsolunda uygulama + **3 reklam birimi**
  (rewarded, banner, interstitial) → `[Release]` dört anahtar → `is_real=true`.
  Kimlikler sır değildir (her APK'da görünür). Manifest `APPLICATION_ID`'yi
  eklentinin export kancası `is_real`'e göre seçer: debug export'ta
  `is_real=true` ise gerçek App ID + test birimleri (Google'ın geliştirme
  önerisi), release export'ta gerçek App ID.
- `[Debug] debug_geography = eea | not_eea | regulated_us_state | other |
  disabled` — **yalnız DEBUG build'de uygulanır** (`effective_debug_geography()`;
  release'te daima boş; eklenti cephesi `is_real` iken ve Java tarafı gerçek
  modda da yok sayar). `not_eea` → UMP `OTHER` (NOT_EEA 3.1'de kullanımdan
  kalktı). QA kancası: `tools/ads_device` `remake real eea|not_eea`
  (`AdConfig.set_debug_geography`, release'te reddedilir).
- **Kitle/içerik (M9-01 `[Audience]`):** `decision="general_13_plus"` — owner
  kararı (2026-09-25, FİNAL): 13+ genel kitle, Play hedef yaş grupları 13–15 /
  16–17 / 18+ ([AUDIENCE_DECISION.md](AUDIENCE_DECISION.md) §0). TFCD / TFUA
  `unspecified` (gönderilmez), `max_ad_content_rating = G` — M8.9 değerleri;
  karar bunları DEĞİŞTİRMEDİ (reklam istekleri aynı, yaş ekranı / çocuğa yönelik
  reklam mantığı yok). Bu değerler **TEEN işlemi DEĞİL** (24.9.0 TFAT `TEEN`
  gönderemez): 13–17 genç reklam işlemi / yargı bölgesi uyumu AÇIK, üretimden
  önce çözülmeli (AUDIENCE_DECISION §2.2; release kapısında ayrı OWNER `UYUM:`
  satırı).
- **TASK/040 bulgusu — RequestConfiguration hiç uygulanmıyor (kapıda CODE):**
  facade'ın `set_request_configuration` Dictionary'si Java'ya Long / Object[] olarak
  geliyor; vendored v6.0 `AdmobConfiguration`'ın `(int)` / `(String[])` dönüşümleri
  ClassCastException atıyor ve Godot istisnayı yutuyor → `max_ad_content_rating = G`
  (ve TFCD / TFUA / test cihazları) **fiilen etkin değil** (A36 kanıtı + M9 logları).
  Spike yamasında düzeltildi; üretim AAR'ı değişmedi. Ayrıntı ve strateji karar
  tablosu: [GLOBAL_TEEN_AD_TREATMENT.md](GLOBAL_TEEN_AD_TREATMENT.md). **Play Age
  Signals reklam kararında KULLANILMAZ.**

## 9. Android / export

- `export_presets.cfg` (gitignore'lu, makine başına): `gradle_build/
  use_gradle_build=true` — Maven bağımlılığı (play-services-ads) yalnız
  Gradle build ile gelir. `godot --headless --path . --install-android-build-
  template --export-debug "Android" build/x.apk` şablonu (`android/build/`,
  gitignore'lu, 4.6.3.stable) kurdu; sonraki export'lar
  `--export-debug` yeter. İlk Gradle build ~3 dk (Maven indirir).
- Eklenti export kancaları: `_get_android_libraries` (AAR),
  `_get_android_dependencies` (appcompat 1.7.1, lifecycle-process 2.8.3,
  play-services-ads 24.9.0), `_get_android_manifest_application_element_contents`
  (`APPLICATION_ID` meta-data). Elle düzenlenen üretilmiş dosya YOK.
- Doğrulanan manifest (`aapt2`): minSdk 24, targetSdk 36, compileSdk 36,
  `com.google.android.gms.ads.APPLICATION_ID = ca-app-pub-3940256099942544~3347511713`,
  `org.godotengine.plugin.v2.AdmobPlugin` kayıtlı. İzinler: VIBRATE (bizim),
  INTERNET / ACCESS_NETWORK_STATE / AD_ID (eklenti), `com.google.android.gms.
  permission.AD_ID` + ACCESS_ADSERVICES_* (GMA SDK), WAKE_LOCK
  (play-services-measurement-sdk-api 20.1.2 + androidx.work 2.7.0, GMA'nın
  geçişli bağımlılıkları), FOREGROUND_SERVICE (androidx.work). Play Data
  safety formunda GMA SDK'nın beyanları kullanılacak (M10).
- Debug APK boyutu ~102 MB: Gradle **debug** şablonunun `libgodot_android.so`
  dosyası 75 MB (sembolleri strip edilmemiş); prebuilt debug APK 45 MB idi.
  Release/AAB'de strip edilir — beklenen, engel değil.
- Sızıntı kontrolü: `tools/*`, `_visual_source/*`, `docs/*`, `build/*`, `*.md`,
  `*.py` export dışında (preset `exclude_filter`); `tools/fake_ad_backend.gd`
  APK'da YOK; kimlik bilgisi/anahtar yok. Son test APK'sı:
  `build/squishy_merge_m8.9-01_testads_debug.apk` (yerel, gitignore'lu), 1267
  girdi, `assets/addons/AdmobPlugin/android_export.cfg` paketli, `scripts/ads/*.gdc`
  ve eklenti `.gdc`'leri içinde; sızıntı 0.
- **M9-01 release hattı** (ayrıntı [../ANDROID_RELEASE_CHECKLIST.md](../ANDROID_RELEASE_CHECKLIST.md)):
  yerel presetler `Android` (debug TEST-reklam APK, paket
  `com.obappstudio.squishymerge.qa`) · `Android Release AAB` (imzalı AAB, paket
  `com.obappstudio.squishymerge`, anahtar yalnız `GODOT_ANDROID_KEYSTORE_RELEASE_*`
  ortam değişkenlerinden) · `Android AAB NOT FOR UPLOAD` (imzasız); tek
  kaynaklar project.godot `[squishy]` (paket kimliği, versionCode, gizlilik
  URL'i) + `application/config/version` (versionName). Kapı
  `tools/release/release_readiness.gd` (tek doğrulayıcı) üç yerden:
  `tools/release/release_android.sh check|aab|non-publishable-aab|debug-apk`,
  `addons/squishy_release` (Godot release export'unda engel varsa Gradle'ı
  kendini anlatan çözülemeyen bir bağımlılıkla bilerek düşürür — Godot 4.6.3'te
  export eklentisi export'u veto edemiyor) ve `tools/release_config_test`.
  Çıktı taraması `tools/release/scan_artifact.py`.

## 10. Testler

- **M9-01:** `tools/monetization_test.tscn` **248** (222 → +26: `canRequestAds`
  kapısı — durum yerine SDK, mesaj yok, hata + önceki rıza, hata + rıza yok,
  form sonrası karar, istek öncesi yeniden sorgu/kayma, her karede sorulmama;
  gizlilik seçenekleri resmî durum/form/ret/yeniden izin/form hatası/geç sinyal,
  ABD eyalet mesajı, yamasız geri düşüş; build türü yapılandırması) ve yeni
  `tools/release_config_test.tscn` **106** (debug/release kimlik kuralları,
  debug coğrafyası kilitleri + EEA/NOT_EEA kancaları, kitle eşlemesi,
  ReleaseReadiness kuralları + bugünkü proje BLOCKED, sır hijyeni, UMP
  sarmalayıcıları arayüz düzeyinde, commit edilmiş AAR bytecode'u, gizlilik
  politikası satırı).
- `tools/daily_rewards_test.tscn` (**111** → M8.10'da 179) ve `tools/interstitial_test.tscn`
  (**60**) — M8.9-02; kapsam DAILY_REWARDS §11.
- `tools/monetization_test.tscn` — **191 kontrol** (M8.9-01: 181; M8.9-02: +
  interstitial kimliği fail-closed, 28 olay, yeni banner yüzeyleri, onboarding
  yuva, Harita düğüm/plaka/kale yuva geometrisi 128 px yuvada), internet/cihaz yok:
  yapılandırma korumaları; olay dikişi; kaynak taraması; rıza akışı
  (NOT_REQUIRED / REQUIRED+form / form hatası / form yok); rıza hataları
  (önceki durum, sınırlı deneme, talep üzerine yenileme); gizlilik
  seçenekleri (gerekli/gizli, form sonrası izin kaybı → banner gizli);
  ödüllü başarı (devam + refill, doğru güç + token), çift ödül, kapanış
  sonrası ödül, eski reklamın callback'i, iptal, silinmiş Main, aynı anda
  ikinci reklam, hazır değilken talep; yükleme hatası + geri çekilme + sınır
  + talep sıfırlaması, gösterim hatası, zaman aşımı; gösterim sırasında
  yükleme, arka plan/öne dönüş payı, izin kaybı; banner yuva/yüzey/gezinme/
  yenileme/olay/geri çekilme/sınır; Main entegrasyonu (gerçek pencereler +
  board: 2/round, kota 1/gün dört gücün toplamı, KAPAT iptali, round terki,
  Ayarlar satırı, gizlilik metni, yuva ↔ OYNA konumu). Kayıt byte-identical.
- Mevcut suite'ler değişmeden yeşil (gate: bkz. PROJECT_STATUS M8.9-01).

## 12. A36 test-reklam cihaz kapısı (M8.9-01.1, 2026-09-21) — GEÇTİ

Kanıt: `build/qa_m8.9-01/device/DEVICE_GATE_NOTES.md` (yerel, gitignore'lu) +
33 kare + `logcat_gate.txt`. Sürücü: `tools/ads_device.tscn` (ayrı QA paketi
`…squishymerge.qa`, komut/durum dosyası kanalı, gerçek dokunuşlar).

- **Cihaz:** SM-A366B / Android 16 / 1080×2340 / yoğunluk 450 (384 dp genişlik)
  / oyunda 120 Hz; GMA dynamite 260480602. Owner kaydı byte-identical geri kondu.
- **Rıza (TR, form yok):** update 5,6 s → NOT_REQUIRED → SDK init 1,5 s → banner
  + ödüllü 5–6 s içinde hazır; SDK rıza çözülmeden BAŞLATILMADI (log sırası).
  **EEA debug akışı cihazda ÇALIŞTIRILAMADI:** eklenti v6.0 `debug_geography`'yi
  Java'da `Integer` bekliyor, Godot `Long` gönderiyor (`Invalid debug_geography
  type: Long`) → coğrafya yok sayılıyor; upstream issue #120 (açık), yalnız v7.0
  kaynağında düzeltilmiş (Godot 4.7). Form yolu yalnız masaüstü sahte testlerle
  kapsanıyor (PRIVACY_CONSENT §4 / §7).
- **Banner:** gerçek "Test Reklamı" uyarlanabilir banner 384×60 dp = 1080×168 px,
  alt kenara sabit (inset T=92 / B=0, jest gezinme), yuva 113 tuval px = 169,5 px;
  Ana Sayfa OYNA / Mağaza son satır / Koleksiyon galerisi banner'ın üstünde; Harita
  / oyun / sonuç ekranında banner yok (alt bant beyaz oranı 0,00). Gezinme döngüsü
  ×3: tek AdView, aynı kimlik, yalnız show/hide (28 çağrı, 0 uyarı), sızıntı yok.
- **Ödüllü devam:** gerçek test videosu; ödül callback'i **reklam etkinliği hâlâ
  üstteyken** geldi (Godot bu cihazda AdActivity arkasında çalışmaya devam ediyor)
  → `Main.grant_revive` tam bir kez, kapanış → 4 s'de sonraki reklam önyüklendi.
  Çift dokunuş → tek gösterim. Reklam sırasında HOME → dönüş: SDK reklamı kapattı,
  tek kapanış callback'i, çift ödül yok, takılı SHOWING yok. 2/2 sonra üçüncü
  teklifte CTA pasif ("hakkın bitti"). Üretim paketinde gerçek taşma → gerçek
  teklif → test reklamı → devam (kurtarma temizliği) doğrulandı.
- **Ödüllü refill:** Bomba stok 0 → gerçek reklam → `grant_rewarded_power(BOMB,
  token)` tam bir kez (stok 1, kota 1→0); aynı reklamın ikinci "ödül"ü yok sayıldı;
  Sarsıntı'da CTA pasif + kota notu (reklam hazır olsa da); Hamur yolu bağımsız.
- **Hata yolları:** gerçek no-fill (geçersiz kimlikle SDK kod 3 "Publisher data not
  found") → FAILED + sınırlı geri çekilme, pencerede "Reklam hazırlanıyor…" →
  "Reklam şu anda kullanılamıyor.", BİTİR/KAPAT/Hamur yolu açık; sahte arka uçla
  gösterim hatası, round terki ve KAPAT yarışları: ödül/kota yok.
- **Logcat:** SCRIPT ERROR 0, FATAL 0, ANR 0, tombstone 0, res:// eksik 0, pencere
  sızıntısı 0; E/godot yalnız (a) bilerek geçersiz kimlik yükleme hataları ve (b)
  yönetici sökülürken eklentinin zaten kaldırdığı banner için `hide` → **dar
  düzeltme:** `AdmobBackend.show/hide_banner` eklenti önbelleğinde olmayan kimliği
  atlar (eklenti düğümü çocuk olduğu için yöneticiden önce çıkıyor). PSS 428 →
  467 MB (3 ödüllü + gezinme) → 448 MB; GMA WebView'ları reklamsız build'e göre
  ~100–150 MB ekliyor, ilerleyen büyüme yok.
- **UX notu (değişiklik YAPILMADI, owner kararı):** ödül `earned` anında verildiği
  için devam/refill'in görsel geri bildirimi (Devam! flaşı, +1 pop, MEDIUM titreşim)
  reklam kapanmadan, arka planda oynuyor. Veri doğru; istenirse grant kapanışa
  ertelenebilir (küçük değişiklik, testli olmalı).

## 11. Açık noktalar / owner kararları

1. **AdMob hesabı:** uygulama kaydı (App ID), rewarded + banner + interstitial
   reklam birimleri, Privacy & messaging'de GDPR (ve gerekiyorsa US state)
   mesajı. Bunlar olmadan üretim kimliği/rıza mesajı yok — bkz. §8.
2. **Kitle/COPPA:** ürün kitlesi ✅ **KARAR (owner, 2026-09-25):** 13+ genel
   kitle, `general_13_plus`; TFCD / TFUA / derece değişmedi (TEEN değil).
   **13–17 genç reklam işlemi / yargı bölgesi uyumu AÇIK** — üretimden önce
   (AUDIENCE_DECISION §2.2, PRIVACY_CONSENT §6).
3. ~~**Eklenti boşluğu (ÜRETİM ENGELİ)**~~ → **M9-01'de KODDA KAPANDI:** v6.0 +
   küçük yama (üç UMP çağrısı + #120), AAR deterministik yeniden derlendi,
   yönetici resmî değerleri kullanıyor (PRIVACY_CONSENT §4). **Açık kalan:**
   yamalı AAR'ın cihaz kapısı (EEA / NOT_EEA / gizlilik seçenekleri formu —
   PRIVACY_CONSENT §8) ve yamanın upstream'e PR olarak gönderilmesi (owner kararı).
4. ~~**Cihaz kapısı (A36, test reklamı)**~~ → **GEÇTİ (§12)**; EEA formu cihazda
   #120 yüzünden gösterilemedi.
5. ~~**Gameplay/Harita banner'ı**~~ → **M8.9-02'de owner kararıyla eklendi** (§6);
   A36'da doğrulandı (§14).
6. **Next-Gen SDK geçişi:** eklentiye bağlı, v1 için gerekmez (§2).
7. ~~**M8.9-02 A36 cihaz kapısı**~~ → **GEÇTİ (M8.9-02.2, §14).** Cihazda
   erişilemeyen tek yol: gerçek test ödüllü reklamında "ödülden ÖNCE kapatma"
   (Google test yaratıcıları ödülü ~8–9 sn'de veriyor ve öncesinde kapatma
   kontrolü göstermiyor) — sahte arka uçla cihazda ve masaüstünde kapsandı.
8. ~~**İki günlük pencere**~~ → M8.9-02.1'de tek pencerede birleştirildi
   (DAILY_REWARDS §6-§7).
9. **Üretim engelleri (M9-01 sonrası):** ~~UMP sarmalayıcı boşluğu + #120~~
   (kodda kapandı; A36 cihaz kapısı M9-01.1'de GEÇTİ — PRIVACY_CONSENT §7), COPPA/TFCD/TFUA kitle kararı
   (ürün kitlesi ✅ 13+, 2026-09-25; 13–17 genç reklam işlemi / yargı bölgesi uyumu AÇIK — [AUDIENCE_DECISION.md](AUDIENCE_DECISION.md) §2.2), gerçek App ID + banner +
   ödüllü + interstitial kimlikleri (4 değer, §8), ~~kalıcı paket kimliği~~
   (✅ `com.obappstudio.squishymerge`, 2026-09-24), upload anahtarı, gizlilik
   politikası URL'i. Release kapısı bunlar kapanmadan
   yüklenebilir AAB üretmez; tam liste
   [../ANDROID_RELEASE_CHECKLIST.md](../ANDROID_RELEASE_CHECKLIST.md).
10. **TASK/040 (2026-09-25, `task/040-global-teen-compliance` dalında):** GMA 25.3.0
    (UMP 4.0.0) + TEEN, Godot 4.6.3'te vendored v6.0 yamasıyla derlendi ve Samsung
    A36'da çalıştı (spike; üretim eklentisi GMA 24.9.0 kaldı). Yeni **CODE** engeli:
    üretim eklentisi RequestConfiguration'ı hiç uygulamıyor (checklist #27). Strateji
    kararı (A / B / C) owner'da — [GLOBAL_TEEN_AD_TREATMENT.md](GLOBAL_TEEN_AD_TREATMENT.md).

## 13. M8.9-02 masaüstü görsel inceleme (2026-09-22)

`tools/daily_ads_shots.tscn` (yalnız pencereli): 720×1280 · 1080×1920 ·
1080×2340 (A36 simülasyonu, `safe=61`), yuva 112 tuval px (magenta plaka
yalnız araçta): Harita + yuva (level 1 / OYNA plakası ve kale mesafeleri
stdout'ta), oyun + yuva (L4, kompakt mod ölçümleri), Mağaza günlük bölümü +
yuva, GÜNLÜK ÖDÜLLER penceresi (hazır / karışık durum), reveal (yalnız Hamur
/ Hamur + Common / Hamur + Legendary), yuvasız referanslar. Kanıt:
`build/qa_m8.9-02/shots/` + `M8.9-02_QA_NOTES.md` (yerel, gitignore'lu).

## 14. A36 günlük ödüller + genişletilmiş reklam cihaz kapısı (M8.9-02.2, 2026-09-22) — GEÇTİ

Kanıt: `build/qa_m8.9-02.2/device/DEVICE_GATE_NOTES.md` (yerel, gitignore'lu) +
38 kare (Q01–Q31 QA paketi, P01–P07 üretim paketi) + `logcat_gate*.txt` +
`qa_events_session1.txt`; APK taramaları `build/qa_m8.9-02.2/export/`. Sürücü:
`tools/ads_device.tscn` (QA paketi `…squishymerge.qa`, M8.9-02.2 komutları:
onboarding / login / dailyq / dayclock / fresh / relaunch / daily_open / daily_reveal
/ clock / inter_block / fake_i*), üretim paketi `tools/*` HARİÇ (aynı ağaç 6bfa97f;
üretim APK'sı byte-identical yeniden üretildi: sha256 `356b0501…18c5`).

- **Cihaz:** SM-A366B / Android 16 / 1080×2340 / yoğunluk 450 / üst inset 92, alt 0
  / 120 Hz; TR → rıza NOT_REQUIRED, form yok. Owner kaydı (671 B, md5 `942aa5c3…`)
  yalnız yedeklendi ve byte-identical geri kondu; tüm günlük / tarih / onboarding /
  kota / ekonomi mutasyonları QA paketinin kendi veri dizininde.
- **Birleşik günlük pencere:** mevcut oyuncu (giriş dün, seri 2, kotalar sıfır)
  açılışta **tam bir kez** otomatik pencere; giriş +15 tam bir kez (seri 3,
  "3. GÜN · +15 HAMUR · ALINDI", şerit 3. gün); kapat → gezin → yeniden açılmadı;
  Ana Sayfa madalyonu ve Mağaza kartı AYNI pencereyi açtı, ikinci +15 yok.
  Üretim paketinde eski biçimli kayıt (anahtar yok, level 11) migration ile aynı
  akışı verdi (500→515).
- **Ücretsiz sandık:** çift dokunuş → tek transaction (+15), reveal, kota ALINDI
  kalıcı; pasif dokunuş hiçbir şey yapmadı. **Reklamlı sandık ×2:** gerçek test
  ödüllü reklam, `earned` reklam hâlâ üstteyken → her biri tam bir kez (+15;
  ikincisinde gerçek skin kurası tuttu: common_05), 2/2 → BUGÜNLÜK BİTTİ, üçüncü
  istek imkânsız. **+150:** tam +150, ALINDI, sandık kotasına dokunmadı, ikinci
  istek imkânsız. Refill kotası (1/gün) ve devam hakkı (round başına 2) bağımsız.
  Efsanevi reveal (QA deterministik sunum): hale pencerenin içinde, banner ile
  çakışma yok.
- **Banner:** Harita (yeni oyuncu Level 1 OYNA plakası altı 2024 px, banner üstü
  2170,5 px → 146 px pay; kale başlığın altında; tekdüze kaplama, sıkıştırma yok)
  ve oyun (banner 1080×170 px en altta, şerit 2048–2147, kap tabanı şeridin
  üstünde, HUD/güç yuvaları en üstte); sol/orta/sağ bırakma + bir güç kullanımı
  gerçek dokunuşlarla Godot'a ulaştı, AdView dokunuş çalmadı. Yaşam döngüsü
  Home→Map→Oyun→Sonuç→Home→Mağaza→Koleksiyon→Map (+ döngü): tek AdView / aynı
  kimlik, sonuçta gizli, yeniden yükleme yok, sıçrama yok, sızıntı yok.
- **Geçiş reklamı (gerçek test birimi):** 892 sn → uygun değil; gerçek saniyelerle
  900,003 → `interstitial_eligible`; kabukta ve oyun sırasında gösterim YOK; doğal
  molada (devam kararı → BİTİR) **gerçek test interstitial'ı** → kapanış → Sonuç
  tam bir kez; saat yalnız SDK gösterimi başlayınca 0'a döndü (`showed`
  940,3 → `impression` 0,0); bekleme 60 sn; iki kez tekrarlandı. Uygun değil /
  bekleme (ödüllü devam kapanışı sonrası, uygunluk korundu) / hazır değil
  (`inter_block` → FAILED, talep üzerine yeniden yükleme) yollarında Sonuç HEMEN.
  Gösterim hatası (sahte arka uç, 5 sn onay zaman aşımı): Sonuç bir kez, saat
  sıfırlanmadı, uygunluk korundu, geç `show_failed` `stale=true`; toparlanma:
  sonraki molada gösterim → kapanış → Sonuç bir kez. Ödüllü reklam sırasında saat
  dondu (930,6 → 930,6); arka planda 25 sn sayılmadı; asla iki tam ekran reklam.
- **Onboarding false (yeni kayıt):** otomatik pencere yok, +15 yok, seri 0, yuva 0
  + banner yok (5 yüzey), interstitial yüklemesi yok, saat 0,0, Mağaza kartı gizli,
  ödüllü devam/refill "kullanılamıyor"; `onboarding 1` sonrası yüklemeler ve saat
  başladı, giriş 1. GÜN +15 bir kez, pencere bir kez (M8.10 ilk gün kuralı yalnız
  dokümante: DAILY_REWARDS §9).
- **Gün değişimi (QA sahte gün):** A günü tümü alınmış → B günü kotalar bir kez
  sıfırlandı + pencere bir kez; geri alınmış sahte gün → anahtar B'de kaldı, ikinci
  sıfırlama yok, `clock_behind` notu.
- **Logcat (558 177 satır):** SCRIPT ERROR 0 · FATAL 0 · ANR 0 · tombstone 0 ·
  res:// eksik 0 · pencere sızıntısı 0 · **E/godot 0** (M8.9-01'deki banner sökme
  hatası gitti); E/Ads yalnız Google'ın kendi JS konsol satırı; W/Ads bilinen
  (Firebase yok, test app settings). **PSS:** QA 484–501 MB (3 gerçek ödüllü + 2
  gerçek interstitial + 5 round + gezinme döngüsü), boşta 15 sn düğüm/statik sabit;
  üretim 431 → 501 MB; ilerleyen büyüme yok (M8.9-01 bandı).
- **Owner görsel kontrolü:** Harita+banner, oyun+banner, GÜNLÜK ÖDÜLLER penceresi,
  Efsanevi reveal, round sonu geçiş reklamı → **PASS (beşi de)**.
- **Olaylar (owner'ın günlük telefonu):** bildirim paneli, WhatsApp VoIP araması
  ve iki heads-up; hiçbirinde giriş yapılmadı. Samsung One UI heads-up'ları
  `EdgeLightingWindow`'da çiziyor (NotificationShade değil): kişisel heads-up
  içeren tek kare anında silindi, `dev.sh check` artık EdgeLighting/HeadsUp/
  Toast/Bubble pencerelerini de engel sayıyor (harness notu).
- **Gameplay dondurulmuş:** fizik / merge / güç / sandık kodu değişmedi (kapı
  yalnız `tools/ads_device.gd` + doküman commit'i ekledi).

