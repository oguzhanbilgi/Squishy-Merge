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
>
> **TASK/041 (2026-09-27; `task/041-fix-request-configuration` main'e ff-only alındı
> 2026-09-27):** TASK/040'ın RequestConfiguration kusuru **KAPANDI** —
> üretim yaması `0002` (Godot 4.6 Long / Object[]-güvenli okuma + hata logu + SDK
> geri okuması); Samsung A36'da derece G, TFCD / TFUA `-1` ve (debug) test cihazları
> İLK reklam yüklemesinden önce uygulanıyor; yığın GMA 24.9.0 / UMP 3.2.0, TFAT / TEEN
> yok (§15) *(Sonra: TASK/042 — GMA 25.3.0 / UMP 4.0.0 + TFAT, §16)*. Release kapısı
> CODE 0 · OWNER 9 · CONFIG 0.
>
> **TASK/042 (2026-09-27; `task/042-gma25-production` — `83b86a9` + `3d15402` — main'e
> ff-only alındı 2026-09-27):** üretim yığını Google Mobile Ads SDK **25.3.0** + UMP **4.0.0**
> (`play-services-ads-api` 25.3.0 üzerinden geçişli), üretim yaması `0003`. TFAT
> (`AgeRestrictedTreatment` UNSPECIFIED / CHILD / TEEN) üretim eklentisinde teknik olarak
> hazır; **üretim varsayılanı herkes için UNSPECIFIED** ve yaş işlemi SDK yapılandırıldıktan
> sonra kilitli. İstek yapılandırması `MobileAds.initialize()` ÖNCESİ bir kez uygulanıyor,
> SDK'dan geri okunup doğrulanıyor; uyuşmazsa SDK başlamıyor (fail-closed). Yaş bandı
> yönlendirmesi YOK (TASK/043, başlamadı); 13–17 `UYUM:` OWNER engeli AÇIK. Samsung A36
> kapısı GEÇTİ (§16). Release kapısı hâlâ BLOCKED — CODE 0 · OWNER 9 · CONFIG 0.
>
> **TASK/043 (2026-09-27; owner onayıyla main'e ff-only alındı):** nötr doğum tarihi ekranı + **yaş bandı reklam yönlendirmesi** (owner iş
> kararı): 13–17 → TFAT **TEEN** + en yüksek derece **T**; 18+ → **UNSPECIFIED** + **MA**;
> 13 yaş altı ve bilinmeyen yaş → eklenti düğümü kurulmaz, UMP sorulmaz, SDK başlamaz,
> reklam yok (13 altı: kısıt ekranı). Rota rızadan ve attach'ten ÖNCE arka uca verilir;
> yapılandırma + geri okuma yine `MobileAds.initialize()` öncesi (TASK/042 sözleşmesi).
> SDK yapılandırıldıktan sonra bant değişirse işlem değişmez — reklam o oturumda kapanır,
> yeni bant sonraki soğuk açılışta. Ham doğum tarihi saklanmaz / loglanmaz. Kullanıcıya görünen
> reklam sözleşmesi (yüzeyler, kotalar, geçiş cadence'ı) TEEN / ADULT için DEĞİŞMEDİ.
> Ayrıntı: [AGE_BAND_ROUTING.md](AGE_BAND_ROUTING.md), §17.
>
> **TASK/052 (2026-10-04; `task/052-fullscreen-break-recovery-monetization` owner onayıyla main'e ff-only alındı
> `1d2fb28 → c7e3ccc`, merge commit yok, dal duruyor):** bitmeyen tam ekran molası DÜZELTİLDİ — geçiş molası ve
> ödüllü talep token'lı bir tam ekran kirasına bağlı; SDK kapanış / hata geri çağrısı gelmezse kira yalnız örtülmeme
> kanıtıyla (öne dönüş + 3 sn, hiç örtülmeden 5 sn, kayıp öne dönüşte yeni dokunuş + 5 sn; Android'de gerçek öne
> dönüş = onResume'un odağı — Godot Vulkan'ın onStart RESUMED'ı reklam üstteyken sayılmaz; ödüllüde "gösterildi"
> sonrası süreye bağlı bırakma yok) biter, ödül asla bu yolla verilmez, SDK reklamı kapatılmaz. Geçiş politikası
> `AdPolicy`'de: önceki gerçek gösterimden bu yana ≥ 2 kesinleşen NORMAL round VE ≥ 300 aktif sn (önce 900 sn), 60 sn
> bekleme aynen — owner kabulüyle ilk üretim varsayılanı; ödüllü kotalar DEĞİŞMEDİ; app-open eklenmedi (ertelendi).
> Banner PAUSED'da gizlenir / duraklatılır. Ayrıntı, owner kararları ve hesap tarafı kontrol listesi: §18, §18.7, §19.

## 1. Kapsam (v1 monetizasyon planı)

| ürün | durum | kural |
|---|---|---|
| Ödüllü devam (revive) | ✅ bağlı, test reklamı, A36'da doğrulandı | round başına en fazla 2 başarılı devam (board sayar) |
| Ödüllü güç refill'i | ✅ bağlı, test reklamı, A36'da doğrulandı (güç başına kota: TASK/060 gerçek A36 kapısı, 2026-10-09) | **güç BAŞINA günde 2 başarılı ödül, dört bağımsız sayaç** (TASK/060, main'de); yalnız seçilen güce +1 (§20) — ~~günde 1, DÖRT gücün toplamı~~ (M8.5-06, tarihsel) |
| Ödüllü günlük sandık (M8.9-02) | ✅ bağlı, test reklamı, cihazda henüz değil | günde 2 BAŞARILI ödül; ayrı kota (DAILY_REWARDS §1) |
| Ödüllü günlük +150 Hamur (M8.9-02) | ✅ bağlı, test reklamı, cihazda henüz değil | günde 1 BAŞARILI ödül; ayrı kota |
| Ücretsiz günlük sandık (M8.9-02) | ✅ reklam yok | günde 1; loot reçetesi DAILY_REWARDS §4 |
| Banner (uyarlanabilir sabit, alt) | ✅ Ana Sayfa / Harita / Mağaza / Koleksiyon / oyun (M8.9-02 ile Harita + oyun eklendi; cihazda henüz değil) | sonuç ekranında GİZLİ; onboarding bitmeden yuva yok |
| Geçiş (interstitial) reklamı (M8.9-02) | ✅ bağlı, test birimi, cihazda henüz değil | ~~900 sn AKTİF süre~~ → **TASK/052: önceki gerçek gösterimden bu yana ≥ 2 kesinleşen NORMAL round VE ≥ 300 sn AKTİF süre** (`AdPolicy`, §18) → uygun; YALNIZ round bitişi molasında, sonuçtan önce; 60 sn tam ekran beklemesi (DAILY_REWARDS §8) |
| Rewarded interstitial / app-open / native / mediation | ❌ bilerek YOK | — (app-open TASK/052'de değerlendirildi, ertelendi — §18.4) |
| IAP / Billing, analitik sağlayıcı, üretim kimlikleri | ❌ bu milestone'da yok | sonraki adımlar |

Hamur satın alma yolu (`PowerUpEconomy.purchase`) reklamdan tamamen bağımsız
kaldı; skinler asla reklam/paraya bağlı değil.

> **TASK/047 Günlük meydan okuma (MEYDAN OKUMA — GAME_DESIGN §5.11):** yeni reklam yerleşimi
> DEĞİL. Meydan okuma round'unun bitişi (başarı / kayıp) round-sonu geçiş reklamı denemesini
> (`try_show_interstitial("round_finish")`) ÇAĞIRMAZ (owner kararı — temiz tekrar döngüsü);
> devam, güç refill'i, ekstra hamle, tekrar, ödül ikiye katlama / yeniden çekme için ödüllü istek
> YOK. Oyun banner'ı mevcut oyun yüzeyi kuralıyla (GAMEPLAY), sonuç ekranında gizli (RESULT);
> yaş / rıza / SDK yönlendirmesi DEĞİŞMEDİ; yaş UNKNOWN'da normal oyunla aynı — SDK / UMP açılmaz,
> meydan okuma reklam yoluna dokunmaz (üretimde UNKNOWN önce zorunlu yaş ekranını gösterir). Normal
> round'ların geçiş reklamı davranışı aynen. Meydan okumada geçen süre mevcut 15 dakikalık aktif süre
> uygunluğuna sayılır (mevcut sözleşme, yeni yerleşim değil). *(TASK/052: aktif süre eşiği 300 sn; meydan okuma
> süresi yine sayılır ama meydan okuma round'u 2 round şartına SAYILMAZ — §18.3.)*

> **TASK/048 (main'de, `b9ae345`) — doğal mola round'a aittir (GAME_DESIGN §12.2):** yeni yerleşim / politika DEĞİL.
> Round kesinleştikten sonraki RESULT_DELAY (0,8 sn) içinde round değiştirilirse (mola "Yeniden Başlat" /
> "Ana Menüye Dön" → yeni level / Sonsuz / meydan okuma) eski round `try_show_interstitial("round_finish")`
> DENEMEZ (olay bile yok; uygunluk, hazır reklam ve aktif saat korunur) ve eski sonuç açılmaz; reklam
> açıkken round değişirse kapanış / gösterim hatası geri çağrısı da eski sonucu açmaz. Sahipliği süren
> round'da davranış birebir aynı (Samsung A36'da gerçek Google TEST geçiş reklamıyla doğrulandı).
> **Fırlatma aralığı (TASK/048 son engel):** `try_show_interstitial` → `_backend.show_interstitial` → JNI
> `Interstitial.show()` (ana Looper'a `interstitialAd.show(activity)`) — Google Mobile Ads'te iptal / kapatma API'si
> YOK, geri dönülmez nokta arka uç gösterim çağrısıdır. Main o round'un sahipliğini yönetici molayı bitirene dek
> tutar (`_round_break_generation`): mola sürerken molanın "Yeniden Başlat" / "Ana Menüye Dön"ü ertelenir, mola
> bitince (kapanış / gösterim hatası / onay zaman aşımı / öne dönüş payı — tek geri çağrı) eski sonucun YERİNE
> çalışır. Yönetici politikası AYNEN (onay zaman aşımı 5 sn, öne dönüş payı 3 sn, 60 sn bekleme, 900 sn uygunluk).
> *(Sonra — TASK/052, §18: onay zaman aşımı + öne dönüş payları tek token'lı tam ekran kirasında birleşti (aynı
> 5 sn / 3 sn değerleri; artık "gösterildi"den sonra ve ödüllüde de); uygunluk 2 round + 300 sn.)*
> Sınır: SDK yönetici vazgeçtikten SONRA reklamı yine açarsa (sözleşme dışı) geç reklam o anki durumu örtebilir.

> **TASK/049 (main'de, `f6cd072`) — round bitişi pencere sahipliği:** yeni yerleşim / politika DEĞİL. Normal round
> mola (ya da stok 0 refill penceresi) açıkken meşru biçimde biterse (Büyütücü dönüşümü özel board dondurmasında da
> tamamlanır) Main kesinleşmede — round'un ilerlemesi yazıldıktan sonra, RESULT_DELAY'den önce — molayı / refill
> penceresini eylemsiz kapatır; geçerli geçiş reklamı ve
> ardından sonuç artık eski pencerenin ALTINDA açılmaz, mola reklamdan sonra geri gelmez. Refill penceresinin
> kapanması bekleyen bir ödüllü refill talebini iptal etmez / ödüllendirmez (kendi token yolu sürer). Reklam yolu
> (`try_show_interstitial`, uygunluk, 60 sn / 900 sn, yaş / rıza) ve TASK/048 sahipliği (nesil, `_round_break_generation`,
> erteleme) AYNEN — mola artık kesinleşmeden sağ çıkmadığından erteleme savunma olarak durur. Samsung A36'da gerçek
> Google TEST geçiş reklamıyla doğrulandı (PROJECT_STATUS §4.29).

> **TASK/050 (main'de, `8f9e259`) — meydan okuma bitişi pencere sahipliği:** yeni
> yerleşim / politika DEĞİL. Aynı karede merge meydan okumayı açık molada bitirirse mola kesinleşmede (ödül /
> tamamlanma işleminden sonra, RESULT_DELAY'den önce) TASK/049'un temizliğiyle eylemsiz kapanır. Meydan okuma yine
> geçiş reklamı DENEMEZ, ödüllü istek yok (TASK/047 aynen); Samsung A36'da Google TEST geçiş reklamı hazır + uygunken
> meydan okuma bitişlerinde sıfır geçiş reklamı olayı, banner kuralı (GAMEPLAY / sonuçta gizli) aynen; normal round
> geçiş reklamı yolu (TASK/049) değişmedi (PROJECT_STATUS §4.30).

## 2. Seçilen eklenti ve SDK sürümleri (araştırma 2026-09-21)

> **Güncel (TASK/042, 2026-09-27, main'de):** GMA **25.3.0** /
> UMP **4.0.0** + üretim yaması `0003` (§16). 24.9.0 / 3.2.0 değerleri M8.9-01 – TASK/041
> yığınıdır (TARİHSEL).

| | |
|---|---|
| Eklenti | `godot-sdk-integrations/godot-admob` **v6.0** (2026-02-01), tag commit `90e3c616ea3c680e3875c31e6bcccffbebbe9d3b` |
| Lisans | MIT (`addons/AdmobPlugin/LICENSE`) |
| Kurulum | AssetLib ile aynı release zip'i (`AdmobPlugin-Android-v6.0.zip`, SHA-256 `9ec26002…973f24`) `addons/AdmobPlugin/` altına kopyalandı (M8.9-01). **M9-01:** tek kaynak yaması `tools/admob_plugin/0001-ump-privacy-options-and-debug-geography.patch` (3 dosya, +73/−2: `can_request_ads` / `get_privacy_options_requirement_status` / `show_privacy_options_form` + #120 `instanceof Number`); iki AAR + `Admob.gd` upstream derleme betikleriyle yeniden üretildi (`build_patched_plugin.sh verify` → BYTE-IDENTICAL); **TASK/041:** ikinci üretim yaması `0002-fix-request-configuration-value-types.patch` (yalnız Java: RequestConfiguration değer dönüşümü, §15), AAR'lar v6.0 + 0001 + 0002'den yeniden derlendi; **TASK/042:** üçüncü üretim yaması `0003-gma25-age-restricted-treatment.patch` (`playads` 24.9.0 → 25.3.0, TFAT, SDK geri okuma API'si, reklam kimliği artık loglanmıyor — §16), AAR'lar v6.0 + 0001 + 0002 + 0003'ten yeniden derlendi (debug `a78acb22…`, release `f5a563a7…`); ayrıntı `addons/AdmobPlugin/VERSION.md` |
| Godot uyumu | eklenti `godot-lib 4.6.stable` ile derlendi; v7.0 (2026-05-27) **Godot 4.7 beta1** hedefli ve bakımcı issue #122'de "4.6.x için v6.0 kullanın" diyor → v6.0 |
| Google Mobile Ads SDK | **TASK/042:** `com.google.android.gms:play-services-ads:25.3.0` (eklentinin export'ta eklediği Maven bağımlılığı; `play-services-ads-api:25.3.0`'ı çözer, derleme betiği çözülmüş sürümü birebir denetler) — `setAgeRestrictedTreatment`'lı (TFAT) ilk sürüm, TASK/040'ta seçildi. Google'ın "Mobile Ads SDK (Legacy)" hattı (`play-services-ads`). *M8.9-01 – TASK/041: `24.9.0`; 24.x **Supported**, deprecation 2027-06-30, sunset 2028-06-30 (deprecation sayfası, 2026-09-21).* |
| UMP SDK | **TASK/042:** `com.google.android.ump:user-messaging-platform:4.0.0` (`play-services-ads-api` 25.3.0'dan geçişli; ayrı geçersiz kılma yok). *M8.9-01 – TASK/041: 3.2.0 (play-services-ads-api 24.9.0 POM'undan geçişli).* |
| Yaş işlemi (TFAT) | **TASK/042:** `AgeRestrictedTreatment` UNSPECIFIED / CHILD / TEEN üretim eklentisinde teknik olarak var; üretim değeri TASK/043 yaş bandından gelir: TEEN → **TEEN + T**, ADULT → **UNSPECIFIED + MA**; UNKNOWN / UNDER_13 → reklam SDK'sı yok — §17 |
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
   ├─ başarı → canRequestAds() true → ADS_ALLOWED → SDK başlatma (bir kez, aşağıda)
   │           canRequestAds() false → ADS_NOT_ALLOWED (+ sınırlı yeniden deneme)
   └─ update HATASI → canRequestAds() (önceki oturumun rızası):
        true → ERROR_WITH_PREVIOUS_STATE (reklam istenir), false → ADS_NOT_ALLOWED
SDK başlatma (TASK/042): set_request_configuration() → geri okuma + doğrulama
   ├─ uyuşuyor → MobileAds.initialize → initialization_completed → sdk_ready
   │             → ödüllü + geçiş önyükleme + banner senkronu
   └─ uyuşmuyor / geri okuma yok → SDK BAŞLATILMAZ (sdk_refused, oturum reklamsız)
her yükleme (ödüllü / geçiş / banner) ve SDK başlatma ÖNCESİ canRequestAds() yeniden
```

M9-01: karar resmî UMP `canRequestAds()` (yamalı eklenti); eklenti sunmuyorsa
M8.9 türetmesi + uyarı (PRIVACY_CONSENT §4). Reklam yalnız `ads_allowed() and
sdk_ready` iken VE istek anında `canRequestAds()` true iken istenir. Oyun
rızayı BEKLEMEZ (spinner yok): Ana Sayfa normal açılır, form üstte belirir.

**TASK/042 (dal `task/042-gma25-production`, §16):** istek yapılandırması (derece G,
TFCD / TFUA, yaş işlemi, yalnız debug'da test cihazları) `MobileAds.initialize()`
ÖNCESİ, tam bir kez uygulanır (`AdmobBackend.initialize()`; facade'ın
`auto_configure_on_initialize = false` — SDK hazır sinyalinde yeniden uygulama YOK),
`get_applied_request_configuration()` ile geri okunur ve {yaş işlemi, derece, TFCD,
TFUA} beklenenle karşılaştırılır. Uyuşmazlık ya da eksik geri okuma → `push_error`,
SDK başlatılmaz, yönetici terminal `sdk_refused` durumuna geçer (yeniden deneme yok,
reklam yok). Yaş işlemi üretimde herkes için UNSPECIFIED
(`MonetizationManager.DEFAULT_AGE_RESTRICTED_TREATMENT`, `attach` hemen sonrası, rıza /
SDK'dan önce) ve SDK yapılandırıldıktan sonra kilitli. *(Sonra: TASK/043 — sabit kaldırıldı; yaş işlemi + derece yaş bandından (`AgeGate.ad_route`): TEEN → TEEN + T, ADULT → UNSPECIFIED + MA; UNKNOWN / UNDER_13 → eklenti / UMP / SDK yok — §17, AGE_BAND_ROUTING.md.)* *(M8.9-01 – TASK/041: facade
yapılandırmayı SDK hazır olunca, `initialization_completed`'tan hemen önce
uyguluyordu — §15.)*

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
| uygulama öne dönüşü | `SHOWING` sürüyorsa 3 sn pay; kapanış gelmezse ödülsüz kapanış varsayılır (sonsuz "gösteriliyor" yok) — *TASK/052: token'lı tam ekran kirası; gerçek öne dönüş FOCUS_IN'le, "gösterildi" sonrası süreye bağlı bırakma yok, ödül kazanıldıysa "kapandı" (§18.2)* |
| süre dolumu (TASK/052) | hazır ödüllü reklam 3300 sn'de (motor saati VEYA duvar saati) atılır, yenisi yüklenir; pencere açılışı (`ensure_rewarded`) tazeler, CTA süresi dolmuş reklamı göstermez |

Kota/hak kontrolleri **yöneticide DEĞİL**, kilitli yerlerde: board (2/round),
`Main.grant_rewarded_power` (token + tip) ve `RewardedPolicy.grant` /
`SaveManager.grant_rewarded_powerup` (TASK/060: güç başına 2/gün, tek transaction); günlük
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
| rıza yok / yükleme hatası (geri çekilmede) / SDK reddedildi (TASK/042, §4) | pasif | "Reklam şu anda kullanılamıyor." |
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
  **TASK/044:** yeni Profil ekranı (ve üstünde açılan Ayarlar) yüzey DEĞİL —
  `TAB_SURFACES[4] = Surface.NONE`, banner gizlenir, yuva korunur (düzen
  zıplamaz); `profile_test` sahte arka uçla doğrular. Yeni yüzey owner kararı ister.
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
  disabled / sdk_refused — TASK/042; age_gate — TASK/043; app_paused /
  consent_form — TASK/052). Hepsinde `active_elapsed_sec`; gösterim yolunda `natural_break`
  (`round_finish`). TASK/052 bağlam alanları (yeni olay ADI yok): `rounds`
  (`interstitial_eligible` / `interstitial_showed`), `recovered` (kira kurtarması:
  `resume_grace` / `uncovered_lease` / `input_evidence`), `late` (kurtarmadan sonra geç
  gerçek gösterim), `stale`.
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
  gönderemez *(Sonra: TASK/042 — üretim eklentisi GMA 25.3.0 ile TFAT gönderebiliyor,
  ama üretim yaş işlemi herkes için UNSPECIFIED, yaş bandı yönlendirmesi yok — §16)*):
  13–17 genç reklam işlemi / yargı bölgesi uyumu AÇIK, üretimden
  önce çözülmeli (AUDIENCE_DECISION §2.2; release kapısında ayrı OWNER `UYUM:`
  satırı).
- **Yaş işlemi (TFAT, TASK/042 — §16):** `android_export.cfg`'de anahtar YOK; değeri
  kod seçer — `MonetizationManager.DEFAULT_AGE_RESTRICTED_TREATMENT` = **UNSPECIFIED**,
  herkes için (yaş bilgisi yok; **Play Age Signals reklamda ASLA kullanılmaz**). Yapılandırma
  `MobileAds.initialize()` ÖNCESİ bir kez uygulanır, geri okunup doğrulanır (§4); SDK
  yapılandırıldıktan sonra yaş işlemi kilitli. TEEN / CHILD'a yönlendirme (yaş bandı)
  TASK/043'ün işi — BAŞLAMADI; release kapısında `teen_ad_treatment_resolved=false`,
  `UYUM:` engeli AÇIK. *(Sonra: TASK/043 — sabit kaldırıldı; yaş işlemi + derece yaş bandından (`AgeGate.ad_route`): TEEN → TEEN + T, ADULT → UNSPECIFIED + MA; UNKNOWN / UNDER_13 → eklenti / UMP / SDK yok — §17, AGE_BAND_ROUTING.md.)*
- **TASK/040 bulgusu — RequestConfiguration hiç uygulanmıyor (kapıda CODE):**
  facade'ın `set_request_configuration` Dictionary'si Java'ya Long / Object[] olarak
  geliyor; vendored v6.0 `AdmobConfiguration`'ın `(int)` / `(String[])` dönüşümleri
  ClassCastException atıyor ve Godot istisnayı yutuyor → `max_ad_content_rating = G`
  (ve TFCD / TFUA / test cihazları) **fiilen etkin değil** (A36 kanıtı + M9 logları).
  Spike yamasında düzeltildi; üretim AAR'ı değişmedi. Ayrıntı ve strateji karar
  tablosu: [GLOBAL_TEEN_AD_TREATMENT.md](GLOBAL_TEEN_AD_TREATMENT.md). **Play Age
  Signals reklam kararında KULLANILMAZ.** *(Sonra kapandı: TASK/041 üretim yaması
  0002 + yeni AAR'lar; A36'da derece G / TFCD / TFUA / test cihazları uygulanıyor — §15.)*

## 9. Android / export

- `export_presets.cfg` (gitignore'lu, makine başına): `gradle_build/
  use_gradle_build=true` — Maven bağımlılığı (play-services-ads) yalnız
  Gradle build ile gelir. `godot --headless --path . --install-android-build-
  template --export-debug "Android" build/x.apk` şablonu (`android/build/`,
  gitignore'lu, 4.6.3.stable) kurdu; sonraki export'lar
  `--export-debug` yeter. İlk Gradle build ~3 dk (Maven indirir).
- Eklenti export kancaları: `_get_android_libraries` (AAR),
  `_get_android_dependencies` (appcompat 1.7.1, lifecycle-process 2.8.3,
  play-services-ads **25.3.0** — TASK/042; önce 24.9.0), `_get_android_manifest_application_element_contents`
  (`APPLICATION_ID` meta-data). Elle düzenlenen üretilmiş dosya YOK.
- Doğrulanan manifest (`aapt2`; M8.9-01, GMA 24.9.0 — TASK/042 statik APK kontrolü:
  minSdk 24 / targetSdk 36, arm64-v8a, §16): minSdk 24, targetSdk 36, compileSdk 36,
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

- **TASK/042 (§16):** `release_config_test` 150 → **182**, `monetization_test` 248 →
  **256** (yapılandırma init öncesi + bir kez + geri okuma, yaş işlemi UNSPECIFIED,
  uyuşmazlıkta SDK reddi / yükleme yok / yeniden deneme yok); interstitial 60,
  daily_rewards 179, tutorial 199 yeşil.
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
   kitle, `general_13_plus`; TFCD / TFUA / derece değişmedi (TEEN değil; TASK/042:
   TFAT teknik olarak hazır, üretim yaş işlemi UNSPECIFIED — §16).
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
10. **TASK/040 (2026-09-25; main'de 2026-09-27):** GMA 25.3.0
    (UMP 4.0.0) + TEEN, Godot 4.6.3'te vendored v6.0 yamasıyla derlendi ve Samsung
    A36'da çalıştı (spike; üretim eklentisi GMA 24.9.0 kaldı *(Sonra: TASK/042 — üretim
    eklentisi GMA 25.3.0 / UMP 4.0.0 + TFAT, varsayılan UNSPECIFIED, §16)*). Yeni **CODE** engeli:
    üretim eklentisi RequestConfiguration'ı hiç uygulamıyor (checklist #27)
    *(sonra kapandı: TASK/041, §15)*. Strateji
    kararı (A / B / C) owner'da — [GLOBAL_TEEN_AD_TREATMENT.md](GLOBAL_TEEN_AD_TREATMENT.md).
11. **TASK/042 (2026-09-27; dal `task/042-gma25-production`, main'e alınması owner onayı
    bekliyor):** üretim GMA 25.3.0 / UMP 4.0.0 + TFAT, varsayılan UNSPECIFIED, yapılandırma
    `MobileAds.initialize()` öncesi + geri okuma doğrulaması; A36 GEÇTİ (§16). **Sıradaki
    (owner yönü, TASK/042 brief'i): TASK/043** owner onaylı, gelir odaklı yaş bandı
    yönlendirmesi (13–17 → TEEN; 18+ → olağan, rızayla yönetilen yetişkin yolu,
    UNSPECIFIED) — **BAŞLAMADI**. Bu yön 13–17 `UYUM:` OWNER engelini KAPATMAZ; uyum
    değerlendirmesi owner'da, AÇIK.

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

## 15. TASK/041 — üretim RequestConfiguration düzeltmesi + A36 kapısı (2026-09-27) — GEÇTİ

**Kapsam:** yalnız TASK/040'ın CODE bulgusu. TEEN / TFAT, GMA 25 / UMP 4 üretim geçişi,
yaş ekranı, gerçek kimlik, imza YOK; gameplay / ekonomi / UI / ses ve `scripts/` DEĞİŞMEDİ.
Dal `task/041-fix-request-configuration` (`7e1e378` + `d32a4d3`) owner onayıyla main'e
ff-only alındı (2026-09-27; ağaç eşit, A36 kanıtı geçerli).

**Kök neden (TASK/040):** facade `set_request_configuration` sözlüğünü Java'ya
TFCD / TFUA / kişiselleştirme = `java.lang.Long`, `test_device_ids` = `Object[]`
(boş dizi bile), derece = `String`, `is_real` = `Boolean` olarak veriyor. v6.0
`AdmobConfiguration` `(int)` (= `checkcast Integer`) ve `(String[])` ile okuyordu →
`ClassCastException` → `MobileAds.setRequestConfiguration()` hiç çağrılmıyordu; Godot'un
JNI köprüsü istisnayı log satırı bile basmadan yutuyordu (M9-01.1 üretim logları:
`set_request_configuration()` girişinden sonra hiçbir şey, her yüklemede SDK'nın
"setTestDeviceIds… to get test ads on this device" ipucu). Upstream v7.0 / `main`
(4b4ddce) yalnız Long dönüşümlerini düzeltti; `(String[])` hâlâ orada.

**Düzeltme (`tools/admob_plugin/0002-fix-request-configuration-value-types.patch`, yalnız
Java, 2 dosya +93/−21):**

| değer | v6.0 | 0002 |
|---|---|---|
| TFCD, TFUA, kişiselleştirme | `(int)` | `instanceof Number` → `intValue()` |
| `test_device_ids` | `(String[])` | `Object[]` üzerinde döngü; yalnız boş olmayan `String` girdiler |
| `is_real`, `first_party_id_enabled`, derece | kör dönüşüm | tip denetimi |
| okunamayan değer | istisna → hiçbir şey uygulanmaz | `Invalid request configuration value '<anahtar>' …` (yalnız tip) + o ayar atlanır (SDK mevcut değerini korur); `is_real` okunamazsa gerçek sayılır |
| `set_request_configuration()` istisnası | sessizce kaybolur | yakalanır: `request configuration NOT applied` + yığın izi |
| kanıt | yok | SDK'dan geri okuma: `set_request_configuration(): applied max_ad_content_rating=… tag_for_child_directed_treatment=… tag_for_under_age_of_consent=… personalization_state=… test_device_ids=<sayı> sdk_initialized=…` |

Değerler ve setter'lar aynı: derece **G**, TFCD / TFUA **unspecified (-1)**, kişiselleştirme
DEFAULT, test cihazları yalnız `is_real=false` (DEBUG) iken (emülatör kimliği + cihazın hash'i +
reklam kimliği — upstream mantığı; release'te bu dal hiç çalışmaz). 0002 API, GDScript, sürüm
değiştirmez; TFAT / yaş işlemi içermez. TASK/040 spike'ı `0003` olarak 0002'nin üstüne taşındı
*(Sonra: TASK/042 — spike araçları kaldırıldı; `0003` artık üretim yaması
`0003-gma25-age-restricted-treatment.patch`, 0002 aynen korundu — §16)*.

**Sıra (§5 — yeniden tasarım gerekmedi):** `MonetizationManager` SDK'yı yalnız
`canRequestAds()` true iken başlatır → SDK hazır olunca facade ÖNCE
`set_request_configuration()` çağırır, SONRA `initialization_completed` yayar → yönetici
yüklemeleri yalnız `_sdk_ready` sonrası başlatır. Yani yapılandırma her zaman ilk reklam
yüklemesinden önce uygulanıyor (`release_config_test` bunu kaynaktan kilitler; A36 logu
zaman damgalarıyla gösterir): SDK'nın geri okuması ilk yükleme çağrısından önce G
gösteriyor ve SDK'nın test cihazı ipucu ilk istekte bile çıkmıyor — aynı
`setRequestConfiguration` çağrısı ilk istekte etkin. Yapılandırmayı `MobileAds.initialize`
ÖNCESİNE almak (Google'ın önerdiği sıra; spike'taki `configure_before_initialize`) bu
görevde yapılmadı — TEEN / TFAT geçişi seçilirse o görevde ele alınır. *(Sonra: TASK/042 —
yapılandırma artık MobileAds.initialize ÖNCESİ, §16)*

**Derleme / kapı / testler:** iki temiz derleme bayt-aynı (debug `40ae0592…`, release
`14c745e9…`), `verify` OK; kapı düzeltilmiş AAR'ı onaylar *(Sonra: TASK/042 — `14c745e9…`
artık onaylı değil, `SUPERSEDED_RELEASE_AARS`; onaylı AAR `f5a563a7…`, §16)*, eski M9 SHA'sı
`KNOWN_PLUGIN_DEFECTS`'te kalır → **CODE 0 · OWNER 9 · CONFIG 0** (13–17 `UYUM:` açık).
`release_config_test` 132 → 150; monetization 248, interstitial 60, daily_rewards 179,
tutorial 199 — hepsi yeşil, SCRIPT ERROR 0, owner kaydı bayt-aynı.

**A36 cihaz kapısı (SM-A366B / Android 16, yalnız `com.obappstudio.squishymerge.qa`,
Google TEST kimlikleri, reklama tıklanmadı, her dokunuş güvenlik kontrolünden geçti):**
QA APK `7e1e378`'den, `b5d5bc85…`; dex kimlikleri `play-services-ads@@24.9.0`,
`play-services-ads-api@@24.9.0`, `user-messaging-platform@@3.2.0` — 25.x / UMP 4.x /
`AgeRestrictedTreatment` / TFAT dizgeleri YOK.

| kontrol | sonuç |
|---|---|
| RequestConfiguration uygulandı + geri okuma | ✅ her süreçte bir kez `applied max_ad_content_rating=G tag_for_child_directed_treatment=-1 tag_for_under_age_of_consent=-1 personalization_state=DEFAULT test_device_ids=3`; `NOT applied` / `Invalid …` 0 |
| test cihazları (DEBUG) | ✅ `test_device_ids=3`; SDK'nın "…to get test ads on this device" ipucu 0 (düzeltme öncesi her yüklemede) |
| sıra | ✅ EEA: initialize 12:13:03.345 → applied 04.587 → ödüllü 04.590 / geçiş 04.592 / banner 04.594 (aynı iş parçacığı; uygulama 13 ms). NOT_EEA: applied 12:19:59.785 → ilk yükleme 59.788 |
| UMP EEA | ✅ form; rızadan önce `can_request_ads=false`, `initialize()` 0, yükleme 0; Consent → OBTAINED → SDK + reklamlar |
| UMP NOT_EEA | ✅ NOT_REQUIRED, form yok, gizlilik satırı gizli |
| gizlilik seçenekleri | ✅ Ayarlar satırı → gerçek dokunuş → form → Do not consent → geri çağrı tam bir kez (code 0), `can_request_ads` true |
| banner | ✅ Ana Sayfa'da görünür, GAMEPLAY'de aynı kimlik, RESULT'ta gizli; süreç başına `load_banner_ad()` 1 |
| ödüllü | ✅ günlük +150: ödül bir kez (335 → 485), ✕, yeniden yükleme, 60 sn tam ekran beklemesi başladı |
| geçiş | ✅ 900 sn + fail + BİTİR: round sonu molasında bir kez, ✕, Result bir kez, aktif saat sıfırlandı, bekleme yeniden başladı |
| yaşam döngüsü | ✅ HOME → başlatıcı → yeniden açılış: aynı süreç, aynı banner; `initialize()` 1; boşta 15 sn düğüm 3014 → 3014, orphan 0 |
| logcat (10 206 QA satırı + crash tamponu + sistem ANR) | ✅ ClassCast / FATAL / ANR / JNI / NoSuchMethod / SCRIPT ERROR / E-godot = 0 |

QA paketi kapıdan sonra kaldırıldı; owner'ın `com.example.squishymerge` paketi (kayıt dahil)
dokunulmadı (meta veri önce = sonra). Debug yolundaki upstream `Log.d` satırları reklam
kimliğini ve cihaz hash'ini yazdığı için saklanan loglar redakte edildi *(Sonra: TASK/042 —
0003 reklam kimliğini ve test kimliği listesini artık loglamıyor, §16)*. Yerel kanıt:
`build/qa_041/` (`A36_DEVICE_GATE.md`, `device/`, `plugin/`, `tests/`).

## 16. TASK/042 — üretim GMA 25.3 / UMP 4 / TFAT geçişi + A36 kapısı (2026-09-27) — GEÇTİ

**Kapsam:** TASK/040 spike'ının güvenli ve gerekli kısmını üretime almak — Google Mobile Ads
SDK 24.9.0 → **25.3.0**, UMP 3.2.0 → **4.0.0** (geçişli), TFAT (`AgeRestrictedTreatment`)
üretim eklentisinde, istek yapılandırması `MobileAds.initialize()` ÖNCESİ + geri okuma
doğrulaması. Kullanıcıya görünen monetizasyon davranışı DEĞİŞMEDİ (banner yüzeyleri, Result'ta
banner yok, ödüllü kuralları, geçiş 900 sn aktif süre / yalnız `round_finish` molası / 60 sn tam
ekran beklemesi, tutorial reklamsız). Yaş bandı yönlendirmesi, yaş bilgisi / yaş ekranı, Play Age
Signals, gerçek kimlik, imza YOK; gameplay / ekonomi / UI / ses DEĞİŞMEDİ; Godot 4.6.3 aynı. Dal
`task/042-gma25-production` (`83b86a9` kod + `3d15402` kapı / doküman kaydı) owner onayıyla
main'e ff-only alındı (2026-09-27; ağaç eşit, A36 kanıtı geçerli).

**Owner yönü (TASK/042 brief'i, 2026-09-27):** TASK/043 owner onaylı, gelir odaklı yaş bandı
yönlendirmesini uygulayacak (13–17 → TEEN; 18+ → olağan, rızayla yönetilen yetişkin yolu,
UNSPECIFIED). TASK/043 **BAŞLAMADI**. Bu yön 13–17 `UYUM:` OWNER engelini KAPATMAZ: TFAT'ın
teknik olarak hazır olması bir uyum sonucu değildir; değerlendirme owner'da, AÇIK
([AUDIENCE_DECISION.md](AUDIENCE_DECISION.md) §2.2,
[GLOBAL_TEEN_AD_TREATMENT.md](GLOBAL_TEEN_AD_TREATMENT.md)).

**Yama (`tools/admob_plugin/0003-gma25-age-restricted-treatment.patch`, SHA-256
`6767e1aa…ec3f`, 5 dosya; 0001 + 0002'nin ÜSTÜNE — 0002 DONDURULMUŞ, aynen korundu):**

| konu | 0003 |
|---|---|
| SDK sürümü | `libs.versions.toml` `playads` 24.9.0 → **25.3.0** (TFAT'lı ilk sürüm); `play-services-ads-api:25.3.0` + `user-messaging-platform:4.0.0` geçişli, ayrı UMP geçersiz kılması yok; derleme betiği çözülmüş sınıf yolunu birebir denetler |
| TFAT | `AdmobConfiguration`: anahtar `age_restricted_treatment` (Godot `Long` 0 / 1 / 2 → UNSPECIFIED / CHILD / TEEN, 0002'nin `getInt`'i ile; bilinmeyen değer loglanır, uygulanmaz). CHILD / TEEN → `builder.setAgeRestrictedTreatment(…)`; UNSPECIFIED → `setAgeRestrictedTreatment(null)` = yapıcının ayarlanmamış varsayılanı (`@Nullable`; GMA null için -1, açık UNSPECIFIED için 0 gönderir, geri okuma ikisini de UNSPECIFIED gösterir — javap) → istek SDK varsayılanıyla aynı |
| TFCD / TFUA | değişmeden uygulanmaya devam (Google: yaş işlemi ile TFCD / TFUA birlikte verilirse en muhafazakâr işlem uygulanır) |
| geri okuma | `get_applied_request_configuration()` (`@UsedByGodot`): yaş işlemi, derece, TFCD, TFUA, kişiselleştirme, test cihazı SAYISI, `sdk_version`, `initialized`. TASK/041 `applied …` satırına `age_restricted_treatment=` eklendi; `initialize()` → `initialize(): request configuration before MobileAds.initialize …` |
| cephe | `Admob.gd`: `age_restricted_treatment` export'u (varsayılan UNSPECIFIED) `create_request_configuration()`'da; `set_request_configuration()` aynı yapıcıyı kullanır; `get_applied_request_configuration()` native metodu `has_java_method()` ile arar (Godot 4.6 `JNISingleton.has_method()` eklenti metotları için false). `model/AdmobConfig.gd`: `enum AgeRestrictedTreatment { UNSPECIFIED = 0, CHILD = 1, TEEN = 2 }` |
| gizlilik | debug test-cihazı yolu reklam kimliğini (AAID) ve kimlik listesini artık loglamıyor (`(value not logged)`, yalnız sayı) |

Spike'ın tanı logları (`TFAT_DIAG`, her yüklemede log, `configure_before_initialize`) ALINMADI;
spike araçları (`0003-spike-gma25-age-restricted-treatment.patch`, `spike` modu,
`spike_qa_export.sh`, `spike_qa_preset.py`) KALDIRILDI (git geçmişi: `e152986` / `d32a4d3`).
QA sürücüsünün (`tools/ads_device.gd`) `teen` / `tfat` / `tfat_diag` komutları üretim API'sini
kullanır ve YALNIZ QA teşhisidir. `javac`: GMA 25.3.0'a karşı 11 kullanımdan kalkma uyarısı
(TFCD / TFUA getter / setter'ları, sabit uyarlanabilir banner boyutu yardımcıları) —
kaldırılmadılar, derleme OK.

**Çalışma zamanı sırası (§4):**

```
attach → set_age_restricted_treatment(DEFAULT = UNSPECIFIED)          (rıza / SDK'dan önce)
UMP canRequestAds() true → _ensure_sdk (bir kez; _sdk_ready / _sdk_initializing / _sdk_refused korur)
  → AdmobBackend.initialize():
       set_request_configuration()          (derece G, TFCD / TFUA -1, yaş işlemi, debug test cihazları)
       → get_applied_request_configuration()                       (SDK geri okuması)
       → {age_restricted_treatment, max_ad_content_rating, TFCD, TFUA} == beklenen?
            evet → MobileAds.initialize() → initialization_completed → _sdk_ready → yüklemeler
            hayır / geri okuma yok → push_error, false → SDK BAŞLATILMAZ (fail-closed)
```

- `auto_configure_on_initialize = false`: facade SDK hazır sinyalinde yapılandırmayı YENİDEN
  uygulamaz (tek uygulama, tek doğrulama). Onboarding rızayı + reklamları hâlâ erteliyor.
- **Varsayılan:** `MonetizationManager.DEFAULT_AGE_RESTRICTED_TREATMENT` = **UNSPECIFIED**, herkes
  için; yaş bilgisi yok, Play Age Signals reklamda ASLA kullanılmaz, yönlendirme yok. Derece **G**,
  TFCD / TFUA unspecified — DEĞİŞMEDİ; kitle `general_13_plus` değişmedi. *(Sonra: TASK/043 — sabit kaldırıldı; yaş işlemi + derece yaş bandından (`AgeGate.ad_route`): TEEN → TEEN + T, ADULT → UNSPECIFIED + MA; UNKNOWN / UNDER_13 → eklenti / UMP / SDK yok — §17, AGE_BAND_ROUTING.md.)*
- **Kilit:** yaş işlemi SDK yapılandırıldıktan sonra değiştirilemez —
  `set_age_restricted_treatment()` farklı bir değer için `false` + `push_error` döner, doğrulanmış
  yapılandırma geçerli kalır (aynı değer `true`). Gerekçe (çekişmeli inceleme): init sonrası
  yeniden uygulama fail-open olabilirdi. TASK/043 yönlendirmeyi SDK başlamadan ÖNCE yapmalı
  (onboarding zaten rızayı + SDK'yı erteliyor) ya da init sonrası anlambilimini kendisi tanımlamalı.

**SDK reddi (terminal durum):** `initialize()` false → `MonetizationManager._sdk_refused`: yeniden
deneme yok, yapılandırma yeniden denenmez, hiçbir reklam yüklenmez; ödüllü notu "Reklam şu anda
kullanılamıyor." (`NOTE_UNAVAILABLE` — sonsuz "hazırlanıyor" yok), geçiş atlama sebebi
`sdk_refused`, `sdk_refused()` getter. Onaylı AAR'la bu yola düşülmez (A36).

**Derleme / belirlenirlik / kapı / testler:**

- İki temiz `build` (mevcut klon + sıfırdan GitHub klonu) bayt-aynı: debug `a78acb22…15b6`, release
  `f5a563a7…20f8` + üretilen üç `.gd`; `install` (3.) + `verify` (4.) aynı baytlar, `verify`
  BYTE-IDENTICAL; `baseline` hâlâ upstream v6.0'a eşit.
- Kapı (`tools/release/release_readiness.gd`): `PATCHED_RELEASE_AAR_SHA256` = `f5a563a7…`; TASK/041
  AAR'ı `14c745e9…` artık onaylı DEĞİL (`SUPERSEDED_RELEASE_AARS` — kusurlu değil, geri gelirse
  CODE "artık onaylı değil"); kusurlu M9 AAR'ı `90d35992…` `KNOWN_PLUGIN_DEFECTS`'te kalır (CODE);
  `REQUIRED_GMA_VERSION` 25.3.0 üretilmiş `AdmobPlugin.gd`'den okunur; `plugin_facade_tfat` şart.
  `TEEN_TREATMENT_BLOCKER`: "TFAT TEEN teknik olarak hazır — GMA 25.3.0, TASK/042 — ama yaş bandı
  yönlendirmesi yok, üretim UNSPECIFIED"; `teen_ad_treatment_resolved=false`. RequestConfiguration
  kusuru (TASK/041) KAPALI kalıyor.
- `tools/release/release_android.sh check` (`83b86a9`, 2026-09-27): **BLOCKED — CODE 0 · OWNER 9 ·
  CONFIG 0** (AdMob 5 + `UYUM:` 1 + gizlilik URL'i 1 + upload anahtarı 2); `aab` hâlâ reddediliyor.
- Testler (commit edilmiş kodda, 2026-09-27 13:48): `release_config_test` 150 → **182**,
  monetization 248 → **256**, interstitial 60, daily_rewards 179, tutorial 199 — hepsi yeşil,
  SCRIPT ERROR 0, masaüstü owner kaydı dokunulmadı.

**Çekişmeli inceleme (iş akışı: 4 mercek + bulgu başına 1 şüpheci, 2026-09-27):** 7 bulgu, hepsi
düşük; 2'si gerçek (QA TEEN açılış kanıtı init öncesi sırayı kanıtlayamıyordu; CHILD bytecode
kontrolü boş geçiyordu), 5'i erişilemez / bilerek böyle diye çürütüldü. **Yedisi de ele alındı:**
yaş işlemi kilidi, SDK-reddi terminal durumu, harness kanıtı native init öncesi satırı + `accepted`
bayrağıyla, UNSPECIFIED / CHILD / TEEN için tam `CONSTANT_Utf8` + yama metni kontrolleri,
UNSPECIFIED → null (javap), çözülmüş sürüm için birebir bağımlılık kontrolü, 0003 yaması commit'e
alındı.

**A36 cihaz kapısı (2026-09-27 13:52–14:03; SM-A366B / Android 16, yalnız
`com.obappstudio.squishymerge.qa`, Google TEST kimlikleri, reklama tıklanmadı — yalnız ✕ —, her
dokunuş / kare / kurulum `device/dev.sh` güvenlik kontrolünden geçti):** QA APK `83b86a9`'dan,
`eb764436…0261` (103 391 164 B). Statik kontrol **PASS**: dex kimlikleri
`play-services-ads@@25.3.0`, `play-services-ads-api@@25.3.0`, `user-messaging-platform@@4.0.0`
(her biri tam bir tane; 24.x / UMP 3.x YOK); `AgeRestrictedTreatment` + `setAgeRestrictedTreatment`
+ TEEN / CHILD / UNSPECIFIED; spike dizgeleri, ham AAID log biçimi, Play Age Signals YOK; paketli
yapılandırma `is_real=false`, yalnız örnek kimlikler, `[Audience]` G / unspecified / unspecified,
yaş işlemi anahtarı yok.

| kontrol | sonuç |
|---|---|
| UMP EEA — rızadan önce (`pm clear`, geo=eea) | ✅ form; `can_request_ads=false`, SDK yapılandırılmadı (geri okuma derece "", test cihazı 0), `initialize()` 0, `set_request_configuration()` 0, yükleme 0 |
| UMP EEA — Consent sonrası sıra | ✅ OBTAINED → `applied … age_restricted_treatment=UNSPECIFIED … sdk_initialized=false` 13:53:20.958 → `initialize()` + `initialize(): request configuration before MobileAds.initialize … UNSPECIFIED` 20.959 → yüklemeler 22.664–22.667; geri okuma G / -1 / -1 / UNSPECIFIED / DEFAULT / `test_device_ids` 3 / sdk 25.3.0 / initialized true; süreç boyunca `initialize()` 1, `set_request_configuration()` 1 |
| UMP NOT_EEA | ✅ debug coğrafyası 4 (OTHER), NOT_REQUIRED, form çağrısı 0, gizlilik NOT_REQUIRED, Ayarlar satırı gizli; applied UNSPECIFIED 14:00:01.536 → init öncesi satır 01.537 → yüklemeler 03.559 |
| gizlilik seçenekleri | ✅ Ayarlar satırı (REQUIRED) → gerçek dokunuş → form → Do not consent → `privacy_options_form_dismissed` tam bir kez (code 0); `can_request_ads` true (sınırlı reklam) |
| banner | ✅ Ana Sayfa'da görünür, GAMEPLAY'de aynı kimlik, RESULT'ta gizli (LOADED), Ana Sayfa'da yeniden görünür; süreç başına `load_banner_ad()` 1 |
| ödüllü | ✅ günlük +150: gerçek dokunuş → ödül bir kez (335 → 485, `rewarded_earned` 1) → ✕ → yeniden yükleme; 60 sn tam ekran beklemesi başladı |
| geçiş | ✅ 900 sn + level + fail + gerçek BİTİR: `natural_break=round_finish`'te bir kez → ✕ → Result bir kez; aktif saat sıfırlandı, bekleme yeniden başladı, sonraki önyüklendi, shows=1 |
| yaşam döngüsü | ✅ boşta 15 sn düğüm 3014 → 3014, orphan 0; HOME → başlatıcı → yeniden açılış: aynı pid, aynı banner, reklamlar READY; `initialize()` 1 (çift init / AdView yok) |
| TFAT varsayılanı | ✅ her üretim yolu sürecinde geri okuma `age_restricted_treatment=UNSPECIFIED` (applied satırı, init öncesi satır, `get_applied_request_configuration()`) |
| QA-only TEEN yeteneği + kilit (EEA + açılış kelimesi `teen`) | ✅ TEEN hiçbir yapılandırmadan önce kabul (`configured_before=false`); Consent sonrası `applied … TEEN … sdk_initialized=false` 14:02:10.949 → init öncesi satır TEEN 10.950 → yüklemeler 12.488; geri okuma TEEN, derece G; banner / ödüllü / geçiş yüklendi. Sonra `tfat unspecified` → REDDEDİLDİ (kilit), geri okuma TEEN kaldı |
| QA-only yarış (NOT_EEA + `teen`) | ✅ UMP harness'ten önce çözüldü → SDK UNSPECIFIED ile yapılandırıldı → TEEN REDDEDİLDİ (`accepted=false configured_before=true`), geri okuma UNSPECIFIED — kilit sessiz bir "TEEN" iddiasını önlüyor |
| logcat (11 761 QA satırı, 4 süreç + crash tamponu + system / events) | ✅ varsayılan yol TEMİZ: SCRIPT ERROR / E-godot / FATAL / ANR / ClassCast / NoSuchMethod / NoSuchField / JNI / pencere sızıntısı / çift init / `NOT applied` / geçersiz değer / geri okuma uyuşmazlığı / SDK test cihazı ipucu / spike dizgeleri / ham AAID / ham kimlik listesi = 0. QA TEEN süreçlerinde yalnız bilerek tetiklenen kilit reddi (`push_error` + backtrace) |

QA-only TEEN satırları yalnız QA teşhisidir: üretim varsayılanını değiştirmez, üretim yolunda
yaş bandı yönlendirmesi yoktur.

**Gizlilik:** eklenti reklam kimliğini ve test kimliği listesini artık loglamıyor (`Added
Advertising ID as test device (value not logged)`, `Set test device IDs: 3 (values not logged)`);
`g.sh dump` eski biçimli satırları, uuid'leri ve 32-hex kimlikleri yazmadan önce yine redakte ediyor
(derinlemesine savunma) — saklanan loglarda tanımlayıcı yok. QA paketi kapıdan sonra kaldırıldı;
üretim paketi `com.obappstudio.squishymerge` hiç kurulmadı; owner'ın `com.example.squishymerge`
paketi (kayıt dahil) dokunulmadı (meta veri önce = sonra). Masaüstü owner kaydı,
`default_bus_layout.tres`, `export_presets.cfg`, `project.godot`, `_visual_source/` kapı öncesi =
sonrası. Yerel kanıt: `build/qa_042/` (`A36_DEVICE_GATE.md`, `FACTS.md`, `device/`, `plugin/`,
`tests/`, `integrity/`).


## 17. TASK/043 — nötr yaş ekranı + yaş bandı reklam yönlendirmesi (2026-09-27)

Kanonik ayrıntı: [AGE_BAND_ROUTING.md](AGE_BAND_ROUTING.md). Özet (kod gerçeği):

- **Tek girdi:** `MonetizationManager.set_age_band(band)` — Main soğuk açılışta bandı
  `SaveManager.resolve_age_band_at_launch(AgeGate.today())` ile (geçişler dahil) yöneticiyi
  ağaca eklemeden ÖNCE verir; bilinmiyorsa İLK güvenli kabukta nötr yaş ekranı
  (`scenes/ui/age_gate_panel.tscn`) çözer. Doğum tarihi yöneticiye / Main'e hiç gelmez.
- **Rota (`AgeGate.ad_route`):** UNKNOWN / UNDER_13 → kapı KAPALI (attach yok, UMP yok, SDK
  yok, yükleme yok, yuva 0, aktif süre saymaz, geçiş sebebi `age_gate`, ödüllü notu
  "Reklam şu anda kullanılamıyor."); TEEN → `set_age_restricted_treatment(TEEN)` +
  `set_max_ad_content_rating("T")`; ADULT → UNSPECIFIED + `"MA"`. CHILD hiçbir banda verilmez.
- **Sıra:** rota → rota geri doğrulaması (arka ucun tuttuğu değer = tablo; değilse oturum
  reklamsız) → `attach` → UMP (`canRequestAds`) → rota yeniden doğrulanır →
  `AdmobBackend.initialize()` (yapılandırma + geri okuma: yaş işlemi, derece, TFCD, TFUA) →
  `MobileAds.initialize()` → yüklemeler. Native uygulama + geri okuma TASK/042'nin kanıtlanmış
  yerinde (UMP izninden sonra — debug test cihazı yolu AAID okur); AGE_BAND_ROUTING §7. Rıza
  güncellemesi / form yüklemesi yoldayken oturum kapanırsa (ör. 13 altı beyanı) açılış rıza
  formu yüklenmez / gösterilmez. `[Audience] max_ad_content_rating` kaldırıldı (geri gelirse yapılandırma
  geçersiz); arka ucun rota verilmemiş varsayılanı en muhafazakâr UNSPECIFIED + G.
- **Kilit:** derece de yaş işlemi gibi SDK yapılandırılınca kilitli
  (`AdBackend.request_configured()`). Bant sonradan değişirse: SDK yapılandırılmadıysa bekleyen
  rota güncellenir (`APPLIED`); yapılandırıldıysa işlem değişmez, `_block_age_session()` —
  banner gizlenir, ödüllü / geçiş gösterilmez, yeni yükleme / yeniden deneme yok, yuva sabit,
  gizlilik seçenekleri açık — `NEXT_LAUNCH` (panelin "kaydedildi" adımı her cevapta AYNI nötr
  metni gösterir); 13 altına geçiş `ADS_STOPPED` + kısıt ekranı. Yuva ilk kez açılınca görünür
  kabuk ekranı hemen yeniden yerleşir (`Main._on_banner_slot_changed`).
- **Değişmeyenler (TEEN / ADULT):** banner yüzeyleri (Ana Sayfa / Harita / Mağaza /
  Koleksiyon / oyun; Sonuç bannersız), ödüllü kotalar (+150 Hamur 1/gün, reklamlı sandık 2/gün,
  refill 1/gün toplam — *o tarihte; TASK/060'tan beri güç başına 2/gün, §20* —, devam 2/round), geçiş (900 sn aktif süre, yalnız doğal mola, Sonuç hemen,
  uygunluk korunur, 60 sn bekleme), tutorial + tutorial kaynaklı Level 1 reklamsız, ilk gün
  kuralı, ekonomi.
- **Testler:** `age_ad_routing_test` 112 (yönetici + UMP matrisi + bant değişimi + yoldaki
  rıza + rota doğrulaması + Main akışları + bozuk saat + yeniden yerleşim), `age_gate_test` 137
  (takvim / sınırlar / kayıt / gizlilik / UI / düzeltme); `monetization_test` 257,
  `interstitial_test` 60, `daily_rewards_test` 179 ve görsel harness'ler olağan (ADULT) yolu
  sürer; `tutorial_test` 200 (kabukta yaş ekranı); `release_config_test` 201 yönlendirme /
  kapı kurallarını kilitler.
- **A36 (2026-09-27): GEÇTİ** — yalnız QA paketi; A bilinmeyen yaş (sıfır SDK çağrısı), B 15 yaş
  EEA (TEEN + T init öncesi; banner / ödüllü / geçiş), C 36 yaş NOT_EEA (UNSPECIFIED + MA), D 10 yaş
  (kısıt ekranı, sıfır SDK), E Ayarlar'dan iki yön (oturum reklamsız, aktif SDK'da işlem değişmez,
  sonraki soğuk açılış yeni rota), F tam 18. yaş günü (SDK'dan önce ADULT); 9 / 9 log temiz.
  Ayrıntı AGE_BAND_ROUTING §11.

## 18. TASK/052 — tam ekran mola kurtarma + gelir odaklı geçiş politikası (2026-10-04)

Dal `task/052-fullscreen-break-recovery-monetization` (temel `1d2fb28`); **✅ main'de** — owner onayıyla ff-only
`1d2fb28 → c7e3ccc` (2026-10-04; merge commit / rebase / squash / cherry-pick / force push yok; dal duruyor). Doğrulamanın
tamamı (§18.6) entegrasyondan ÖNCE tamamlandı; entegrasyon ve doküman eşitlemesi sırasında kapı yeniden koşulmadı.
Faz A izi (kod değişmeden önce): `build/qa_052/trace/TRACE.md`; temelde deterministik yeniden üretim:
`build/qa_052/baseline/`.

### 18.1 Kök neden — bitmeyen tam ekran molası

Uygulamanın kendi molası (`_break_done == false`, geçiş `SHOWING`, Main `_round_break_generation`) yalnız dört yoldan
bitiyordu: SDK kapanışı, SDK gösterim hatası, 5 sn onay zamanlayıcısı (SDK "gösterildi" gelince İPTAL) ve 3 sn öne
dönüş payı (yalnız APPLICATION_RESUMED kurar). **"Gösterildi" gelip kapanış hiç gelmezse ve ardından RESUMED de
gelmezse** (uygulama hiç duraklamadı ya da RESUMED kayboldu) hiçbir zamanlayıcı kurulmuyordu: sonuç hiç açılmıyor,
bitmiş board'da mola / BACK açılmıyor, ertelenen Yeniden Başlat / Ana Menü sonsuza dek bekliyor, `fullscreen_ad_active()`
true kalıyor (ödüllü hiç hazır değil, geçiş "showing" ile engelli), aktif saat süreç boyunca donuk — tek çıkış uygulamayı
öldürmek. Ödüllüde onay zamanlayıcısı hiç yoktu: aynı sınıf (talep sonsuza dek "Reklam gösteriliyor…", sonraki her
ödüllü / geçiş reddedilir). Yol üstünde bulunanlar: onay zamanlayıcısı uygulama DURAKLATILMIŞKEN de doluyordu (arka
plana atmak molayı erken bitirebiliyordu); ödüllü öne dönüş payı token'sızdı (iki RESUMED → iki zamanlayıcı, ikincisi
YENİ bir talebi kapatabiliyordu); onay zaman aşımından sonra gelen gerçek "gösterildi" ne sayılıyor ne sıklık saatini
sıfırlıyordu; eklentinin yetim yeniden yüklemesinin `interstitial_failed_to_load(eski_id)` sinyali yoldaki önyüklemeye
yazılıyordu.

### 18.2 Çözüm — token'lı tam ekran kirası (`MonetizationManager`, geçiş + ödüllü)

- Geçiş molası ya da ödüllü talep SDK'ya verildiği an (geri dönülmez nokta — GMA'da iptal API'si yok) uygulamanın
  KENDİ engelleyici durumu bir **kiraya** bağlanır: `LeaseKind`, token, TEK zamanlayıcı (`_lease_timer`). SDK'nın uç
  geri çağrıları (kapanış / gösterim hatası) **yetkili kalır**; gelmezse kira yalnız uygulamanın örtülmediğine dair
  kanıtla bırakılır:
  - gerçek öne dönüş → `SHOW_RESUME_GRACE` = 3 sn (mevcut değer). **Gerçek öne dönüş** = APPLICATION_RESUMED, ama
    Android'de onPause'un FOCUS_OUT'u ile onResume'un FOCUS_IN'i arasında gelen RESUMED sayılmaz: Godot 4.6.3 Vulkan
    oluşturucusu RESUMED'ı Activity.onStart'ta (oluşturucu iş parçacığı yeniden başlarken) da gönderir — HOME / kilit /
    arama sonrası dönüşte reklam hâlâ üstteyken (şablon bayt kodundan doğrulandı; inceleme L1-1). Bu durumda pay
    onResume'un FOCUS_IN'iyle başlar; banner ve aktif saat de o ana dek duraklatılmış kalır;
  - gösterim isteğinden beri hiç PAUSED gelmedi ("gösterildi" öncesi) → `FULLSCREEN_UNCOVERED_LEASE_SEC` = 5 sn (=
    TASK/048'in 5 sn onay süresi; SDK'nın gösterimi sessizce düşürdüğü kök neden yolu);
  - geçiş: SDK "gösterildi" dedi ama hiç PAUSED yok → "gösterildi"den 5 sn (sonuç reklamın altında açılabilir; ucuz
    yanlış tahmin, ödül yok);
  - ödüllü: SDK "gösterildi" dedi ama hiç PAUSED yok → **süreye bağlı bırakma YOK**; yalnız "gösterildi"den ≥ 5 sn sonra
    uygulamaya ulaşan YENİ bir dokunuş (reklam üstteyse dokunuş ona gider) → 5 sn. Böylece etkinliği duraklatmayan bir
    gösterim yolunda bile oyuncunun hak ettiği ödül süreyle kesilmez (inceleme L3-1);
  - PAUSED geldi, RESUMED kayboldu → son PAUSED'dan ≥ 5 sn sonra uygulamaya ulaşan YENİ bir dokunuş kanıttır → 5 sn; bu
    dokunuş kira olsun olmasın uygulama düzeyinde öne dönüş sayılır (duraklatma düşer — banner, aktif saat, doğal mola
    takılı kalmaz; inceleme L6-3);
  - PAUSED iken (girdi kanıtı yoksa) **süreye bağlı bırakma YOK**: gerçekten görüntülenen tam ekran reklam uygulamayı
    duraklatır (A36, TASK/048: istek → PAUSED 55–65 ms → "gösterildi" 91–149 ms), dolayısıyla uzun bir reklam kesilmez.
    Örtülme kanıtı yalnız gösterim çağrısından SONRAKİ PAUSED'dır (önceden duraklatılmış uygulama sayılmaz).
- **Sonuç:** "kapandı" (gösterildi, örtülme görüldü ya da — ödüllüde — "ödül kazanıldı" geldi) = kapanış anlamı (60 sn
  bekleme, önyükleme, mola geri çağrısı TAM bir kez, eklenti nesnesi önbellekten düşer); "gösterilmedi" = gösterim
  hatası anlamı (mesaj `show confirm timeout`, bekleme yok, uygunluk korunur). Olaylara `recovered` = `resume_grace` /
  `uncovered_lease` / `input_evidence` eklenir; `describe()` `lease=` / `recov=` / `inres=` gösterir.
- **Ödül asla kurtarmayla verilmez:** ödül yalnız mevcut "ödül kazanıldı" geri çağrısıyla, o anda verilir (tek yol,
  Main token'ları + kotalar aynen). Kurtarmadan önce kazanılmadıysa not "Ödül için reklamın tamamını izlemen
  gerekiyor." (gösterilmediyse "Reklam gösterilemedi, tekrar dene."), teklif açık kalır. Uygulama SDK reklamını
  "kapatmaz"; sahte kapanış / sahte ödül / sahte gösterim sayımı YOK.
- **Emekli kimlikler** (`RETIRED_ID_MEMORY` = 4 / biçim): kapanan / kurtarılan reklamın geç ya da yinelenen kapanış /
  hata / ödül geri çağrısı eskidir (sahiplik değişmez; ikinci sonuç, ikinci mola geri çağrısı, ikinci ödül, süren
  önyüklemenin bozulması yok). Kendi reklamımızın kurtarmadan SONRA gelen geç gerçek "gösterildi"si gösterimi bir kez
  sayar ve sıklık sayaçlarını sıfırlar; yinelenen "gösterildi" iki kez sayılmaz. Eklentinin yetim yeniden yüklemesinin
  hata sinyali yoldaki önyüklemeye yazılmaz.
- **Banner yaşam döngüsü:** APPLICATION_PAUSED'da gizlenir (eklenti: `GONE` + `AdView.pause()`), gerçek öne dönüşte
  yeniden gösterilir (`VISIBLE` + `resume()`); aynı AdView, yeni yükleme yok. Google'ın BaseAdView referansı `pause()`'un
  etkinliğin onPause'unda, `resume()`'un onResume'unda çağrılmasını söyler
  (developers.google.com/android/reference/com/google/android/gms/ads/BaseAdView).
- **Aktif saat:** arka plandan / uykudan dönüşteki ilk karenin dev delta'sı en çok `ACTIVE_TICK_MAX_SEC` = 1 sn sayılır
  (durdurulan süre 300 sn kapısına sızmaz; inceleme L8-1).
- **TASK/048 sahipliği aynen:** kira sürerken Main `_round_break_generation`'ı tutar; mola kurtarmayla bitse de
  ertelenen Yeniden Başlat / Ana Menü eski sonucun YERİNE tam bir kez çalışır; eski sonuç açılmaz.

### 18.3 Politika — `scripts/ads/ad_policy.gd` (sayıların tek ayar yeri)

Zorunlu (oyuncunun seçmediği) geçiş reklamı yalnız doğal molada — normal round KESİN bitti, devam kararları tamamlandı,
sonuç ekranından ÖNCE (`Main._on_round_finished` tek çağrı noktası) — ve hepsi doğruyken:

| kural | değer |
|---|---|
| önceki gerçek gösterimden bu yana kesinleşen NORMAL round (oturumun ilk geçişi için de) | `FORCED_INTERSTITIAL_MIN_ROUNDS` = **2** |
| önceki gerçek gösterimden bu yana AKTİF ön plan süresi | `FORCED_INTERSTITIAL_MIN_INTERVAL_SEC` = **300 sn** (önce 900) |
| herhangi bir tam ekran reklam kapanışından sonra bekleme | `FULLSCREEN_AD_COOLDOWN_SEC` = **60 sn** (aynı) |
| başka tam ekran yok, reklam HAZIR (süresi dolmamış), yaş / rıza / onboarding izinli, UMP gizlilik formu açık değil, uygulama ön planda | yeni engel sebepleri `app_paused`, `consent_form` |

- Main kesinleşen her normal round'u bir kez bildirir (`_ads.note_normal_round_finalized()`, RESULT_DELAY'den önce);
  yönetici yalnız arka uç + onboarding tamam + reklamlı yaş bandında sayar → tutorial ve tutorial'dan doğan round
  sayılmaz (tutorial'dan "yetişme" yok), meydan okuma (TASK/047) yöneticiye hiç ulaşmaz. Gecikmede round değiştirilse
  de kesinleşen round sayılmış kalır.
- Sayaçlar SDK "gösterildi"de (geç gelen dahil, bir kez; gösterim sayılır) ve "gösterildi"si gelmemiş reklamın
  kapanışında (SDK kapanışı ya da örtülme kanıtlı kurtarma; gösterim SAYILMAZ — tek kural, inceleme L4-02) sıfırlanır;
  yükleme / gösterim hatası, hazır olmayan mola, "gösterilmedi" kurtarması sıfırlamaz. Hazır değilse sonuç HEMEN açılır
  (beklenmez); uygun mola hangi sebeple atlanırsa atlansın tükenmiş yükleme döngüsü sınırlı biçimde yeniden tetiklenir.
  **2 round + 300 sn'nin altına inilmez**; uzak yapılandırma yok.
- Aktif süre tanımı aynı (arka plan / ekran kapalı, UMP formu, tam ekran reklam, onboarding öncesi, reklamsız yaş bandı
  sayılmaz; meydan okuma oynanışı da dahil her ön plan süresi sayılır — yalnız ROUND sayacına girmez).
- Envanter simülasyonu (`tools/ad_inventory_sim.gd`, gerçek Main + FakeAdBackend, 7 oturum tipi; deterministik,
  sentetik): 46 doğal moladan uygun zorunlu geçiş fırsatı — TASK/052 **19**, temel (900 sn) **4** → toplam fırsat
  **4,75 kat**, **+15** mutlak, **%375** göreli artış. Bu yalnız UYGUN ENVANTERDİR — gerçek gösterim, gelir, ARPDAU ya da
  para garantisi DEĞİLDİR. Oturum dökümü — TASK/052 (temel): S1 5 dk / 2 round 1 (0), S2 10 dk / 4 round 2 (0), S3 20
  dk / 8 round 4 (1), S4 + ödüllü devam 3 (1), S5 + meydan okuma 4 (1; meydan okuma bitişinde deneme yok), S6 60 sn'lik 10
  round 2 (0), S7 taze kurulum (tutorial + Level 1 sayılmaz) 3 (1). Ayrıntı `build/qa_052/policy/`. Çekinceler (inceleme L7-5): üst sınırdır — %100 doluluk, ADULT bandı (üretimdeki yaş ekranı S7'de atlanır), çoğu oturumda 150 sn'lik round, sonuç / kabuk süresi sayılmaz; gerçek 30–90 sn'lik round'larda etkin kural 300 sn saatidir.
- Google'ın "Disallowed interstitial implementations" sayfası (support.google.com/admob/answer/6201362) her iki
  kullanıcı eyleminden sonra en fazla bir geçiş reklamı önerir ve art arda geçişi uygunsuz örnek sayar; kural aynı yönde
  tasarlandı. Bu bir **uyum beyanı değildir** — politika uyumu owner incelemesinde AÇIK.

### 18.4 Denetimler

Yerleşim matrisi (biçim, uygunluk, kota, doğal mola, opt-in, kaldıraç, elde tutma / politika riski, öneri): `build/qa_052/policy/PLACEMENT_MATRIX.md`.

- **Önyükleme (düzeltildi):** kapanış / gösterim hatası / kurtarma sonrası yeniden önyükleme; 60 sn yükleme zaman
  aşımı, 15 / 60 / 180 / 600 sn yeniden deneme (döngü başına 6). Google'ın Android geçiş / ödüllü rehberi reklamların
  bir saatte sona erdiğini, önbelleğin saatlik yenilenmesini söyler: hazır ödüllü reklamın da artık 3300 sn yaş sınırı
  var (önce yalnız geçişte vardı) ve yaş motor saati VEYA duvar saatiyle ölçülür (motor saati cihaz uykusunda durur);
  süresi dolan hazır reklam aktif saat adımında, öne dönüşte, ödüllü pencere açılışında ve CTA'da atılıp yenisi yüklenir
  (devam CTA'sı süresi dolmuş reklamı göstermez). Kurtarılan kapanış eklenti nesnesini önbellekten düşürür. **Eklentinin yetim otomatik yeniden yüklemesi**
  (`Interstitial.onAdDismissedFullScreenContent` aynı nesnede `load()`; cephe nesneyi haritadan siler) gösterim başına
  bir boşa istek üretir → gösterim oranını (show rate) düşürür; yalnız native eklenti yeniden derlemesiyle düzelir —
  owner takibi (bu görevde native değişiklik YOK).
- **Banner:** yenileme hesap tarafında (§19); uygulama kodu yenileme isteği göndermez. Sonuç ekranında gizli,
  onboarding öncesi yuva yok (aynen); TASK/052 yalnız PAUSED / RESUMED gizle / göster ekledi.
- **Telemetri:** `AdEvents` sabit olay adları + bellek içi halka (200), sağlayıcı YOK; TASK/052 yeni olay adı eklemedi,
  mevcut olaylara alan ekledi (`rounds`, `recovered`, `late`, `reason`). Firebase / üçüncü taraf analitik eklenmedi;
  kullanıcı kimliği / rıza dizesi loglanmaz.
- **Ödüllü kotalar DEĞİŞMEDİ** (TASK/052 anında; devam 2 / round, güç refill'i 1 / gün dört gücün toplamı — *sonra TASK/060: güç başına 2 / gün, §20* —, reklamlı sandık 2 / gün,
  +150 Hamur 1 / gün) — `AdPolicy.rewarded_caps()` yalnız tek kaynaklarından okur. GAME_DESIGN §5.7.3 refill kotası
  simülasyonla kilitli; ekonomi kanıtı olmadan değiştirilmez. Owner için kaba değer (günlük, reklamlı yol): +150 Hamur +
  sandıklar ≈ 115 Hamur-eşdeğeri (erken) / ≈ 39 (geç) + refill ≈ 140 Hamur-eşdeğeri.
- **App-open: UYGULANMADI (ertelendi).** Google'ın app-open rehberi bu biçimi kullanıcının uygulamanın yüklenmesini
  BEKLEDİĞİ anlara, oyunlarda bir yükleme ekranına bağlar ve ilk app-open reklamını kullanıcı uygulamayı birkaç kez
  kullandıktan sonra önerir (developers.google.com/admob/android/app-open); Help Center sayfası app-open reklamının hemen
  öncesi / sonrasında başka reklam gösterilmemesini ister (support.google.com/admob/answer/9341964). Oyunda oyuncunun
  beklediği bir yükleme yüzeyi yok (Ana Sayfa hemen etkileşimli), rıza + yaş + SDK Ana Sayfa'dan SONRA açılıyor, ilk
  açılışlar tutorial ile reklamsız; round sonu geçişiyle ayrı çakışma yönetimi gerekirdi. 10 ön koşulun hepsi
  sağlanmadığı için eklenmedi (PROJECT_CONTEXT non-goal ile de uyumlu).
- **Mediation / bidding:** eklenmedi (adaptör yok). Eklenirse Google'ın mediation rehberi SDK'nın açıkça başlatılmasını
  ve ortakların Privacy & messaging GDPR / ABD eyaletleri listelerine eklenmesini ister (hesap tarafı, §19).

### 18.5 Kalan riskler ve owner seçenekleri (dürüst)

1. SDK, yönetici molayı bitirdikten SONRA reklamı yine açarsa (sözleşme dışı) geç reklam o anki ekranı örtebilir —
   geç "gösterildi" bir kez sayılır, sahiplik değişmez (TASK/048'den beri bilinen sınır).
2. RESUMED kaybolmuş ve oyuncu hiç dokunmuyorsa mola oyuncu dokunana dek sürer — dokunuş kanıtı olmadan PAUSED iken
   süreye bağlı bırakma bilerek yok (kesilen gerçek reklam = sahte kapanış / geçersiz trafik riski).
3. **"Tam ekran reklam uygulamayı duraklatır" varsayımı** A36 + GMA 25.3 AdActivity'de doğrulandı. SDK / eklenti
   değişirse ya da mediation eklenirse (etkinliği duraklatmayan, ör. diyalog tabanlı bir tam ekran) yeniden
   doğrulanmalı: aksi hâlde ödüllüde "gösterildi"den 5 sn sonra kapanış sayılır ve sonra gelen "ödül kazanıldı" eski
   kalır (oyuncu ödülü alamaz); geçişte sonuç reklamın arkasında açılır.
4. **Native eklenti takipleri — not, aktif görev DEĞİL (owner kararı 2026-10-04, §18.7):** (a) eklentinin yetim yeniden
   yüklemesi (18.4) — temizliği native düzeltme ister; (b) **banner iş parçacığı yarışı** (inceleme L6-4, LOW, zamanlamaya
   bağlı, DOĞRULANMADI): eklentinin önceden var olan native `Banner.show()` / `hide()` görünürlük denetimi Godot iş
   parçacığında okunur, değişiklik sonra UI iş parçacığında çalışır; TASK/052'nin her PAUSED / RESUMED'daki gizle / göster
   çağrısı bu yolu daha sık tetikler. Çok kısa bir duraklat / sürdür arasında banner bir sonraki yüzey / yaşam döngüsü
   değişimine dek görünmez kalabilir; ters sırada iki `addView` gönderilebilir, ikincisi UI iş parçacığında
   `IllegalStateException` atar (kuramsal). Önerilen düzeltme (a) ile aynı native yamada (denetimleri UI
   çalıştırılabilirinin içinde yapmak, `addView`'u `getParent() == null` ile korumak); GDScript değişikliği gerekmez.
   A36 kapısında çökme / ANR 0.
5. **Sıklık ve elde tutma (inceleme L7-1 / L7-2):** 30–90 sn'lik round'larda 2 round şartı nadiren bağlar, etkin kural
   300 sn saatidir → aktif saatte tam dolulukta ≈ 10–12 zorunlu geçiş (önce ≈ 4) — bu, round süresi varsayımına (30–90
   sn) dayanan AYRI bir saatlik tahmindir, §18.3'teki 4 → 19 sentetik simülasyon sonucu değildir; 5–15 dk'lık
   oturumlar 0'dan 1–2 reklama çıkar; ilk zorunlu geçiş yaş ekranından ≈ 5–6 aktif dakika sonra (önce ≈ 15). Bu,
   owner brifinin "ilk gelir odaklı varsayılanı"dır (altına inilmez); geri alınabilir (tek sabit çifti, önceki 900
   sn). Uygulamada analitik SDK yok (non-goal) — etki kapalı / açık testte Play Console elde tutma + AdMob
   raporlarıyla, önceden belirlenen bir inceleme noktasında değerlendirilmeli. Owner seçenekleri (her biri §12.2'yi
   değiştirir): ilk gün koruması (`onboarding_completed_day` ile ertesi güne dek 900 sn ya da zorunlu geçiş yok), uzun
   arka plandan dönüşü soğuk açılış gibi saymak (sayaçlar sıfır — bugün sayaçlar sıcak dönüşe taşınır, 900 sn'de de
   öyleydi), yalnız geçiş öncesi daha uzun "dokunmayı bırak" aralığı (bugün RESULT_DELAY 0,8 sn), reklamı sonuç
   ekranından sonra (Sonraki / Ana Sayfa'da) göstermek, reddedilen devam teklifinden hemen sonra ya da hızlı
   kayıp-tekrar döngüsünde atlamak, ödüllüden sonra daha uzun reklamsız pencere. *(Owner kararı 2026-10-04 — §18.7: 2
   round + 300 sn ilk üretim varsayılanı olarak kabul edildi; ayrı bir ilk gün yasağı şimdi eklenmedi, daha güçlü ilk
   gün koruması ileride A/B testiyle denenebilir; bu listedeki diğer seçenekler uygulanmadı.)*
6. **TEEN bandı:** yeni cadence 13–17 için de geçerli (bantlar arası sözleşme aynı); AGE_BAND_ROUTING §9'daki açık UYUM
   maddeleri 900 sn'ye göre yazılmıştı — owner yeniden değerlendirmeli (hukuki sonuç çıkarılmadı). *(Owner kararı
   2026-10-04 — §18.7: TEEN / rıza / gizlilik yönlendirmesi herkese açık yayından ÖNCE yeniden incelenir; uyum onayı
   tamamlanmadı.)*
7. Kurtarma yolunda ödülsüz kapanış notu mevcut metindir ("Ödül için reklamın tamamını izlemen gerekiyor."; kota
   tüketilmez) — geri çağrıları kaybolan nadir bir tam izlemede oyuncuya haksız gelebilir; nötr metin owner seçeneği.

### 18.6 Testler ve kapılar

- **Temel yeniden üretim (düzeltmesiz `1d2fb28`):** sonda (`build/qa_052/baseline/`) "gösterildi" + kapanış / yaşam
  döngüsü yok → mola hiç bitmiyor; `fullscreen_break_recovery_test`'in temel-güvenli ilk sürümü 43 OK / 38 FAIL / 0
  SCRIPT ERROR; son sürüm süitler aynı kodda kurtarma 63 FAIL + politika 18 FAIL (yalnız düzeltilmiş kodda var olan
  API'lerden 19 SCRIPT ERROR — negatif kontrol).
- **Yeni / uyarlanan süitler:** `fullscreen_break_recovery_test` (18 bölüm, 117 kontrol: kapanış, hata, kayıp kapanış,
  arka plan / öne dönüş, geç / yinelenen geri çağrılar, TASK/048 ertelemesi, ödüllü ödül + kayıp kapanış / ödülsüz,
  yalnız arka plan, sonraki reklam, yaş / rıza, meydan okuma, girdi / sonuç sahipliği, jeton, yetim yükleme, inceleme
  sertleştirmesi U1–U13, kaynak sözleşmesi), `ad_policy_test` (12 bölüm, 54 kontrol: round / süre kapısı, gösterim
  sonrası sıfırlama, bekleme, tutorial, meydan okuma, hazır değil / duraklatılmış / gizlilik formu, app-open N/A, ödüllü
  kotalar, banner, sabitler), `ad_inventory_sim` (rapor, 7 oturum). Uyarlanan: interstitial, monetization,
  result_delay_race, round_finish_modal, start_level_touch_settle, daily_challenge_flow, daily_challenge_terminal_modal,
  age_ad_routing, `ads_device`.
- **Mutasyon (son aday `e16da5a`):** 47 aday — brif #1–#19, #22, #23 + 26 ek (kira, emekli kimlik, `app_paused`, yetim
  filtre, geç gösterim, inceleme sertleştirmesi M33–M50); #20 / #21 app-open N/A. **47 / 47 açık FAIL kontrolleriyle
  öldü, yalnız betik hatasıyla ölen yok, 47 geri koyma bayt-aynı** (`build/qa_052/mutations/final3`).
- **İnceleme:** 8 mercek (dört salt okunur gözden geçirme) + sertleştirme takip incelemesi. BLOCKER 0. HIGH: L1-1 (Godot
  Vulkan'ın onStart RESUMED'ı reklam üstteyken kirayı bırakabiliyordu — giderildi), L5-1 (kilitli doküman — bu doküman
  güncellemesi). MEDIUM'lar giderildi ya da owner kararı olarak belgelendi (sıklık / elde tutma, ilk gün; yerli eklenti
  yetim yüklemesi). Kararlar: `build/qa_052/review/DISPOSITIONS.md`.
- **Kontrollü tam masaüstü kapısı (`e16da5a`):** 49 / 49 koşu temiz — 6100 kontrol, 0 FAIL, 0 SCRIPT ERROR, bot 2 / 2
  (Level 3, ikisi de kazandı), envanter simülasyonu 19 / 46; sahibin kaydı bayt-aynı, kullanıcı verisi listesi değişmedi.
- **Odak suite'ler (son aday `e16da5a`; hepsi 0 FAIL / 0 SCRIPT ERROR):** fullscreen_break_recovery 117 · ad_policy 54 ·
  interstitial 62 · monetization 258 · daily_rewards 179 · result_delay_race 197 · round_finish_modal 164 ·
  start_level_touch_settle 126 · daily_challenge_flow 76 · daily_challenge_terminal_modal 178 · age_ad_routing 122 ·
  tutorial 205 · refill 119 · revive_refill_ui 266 · revive 120.
- **Samsung A36 (yalnız QA paketi, Google TEST / örnek kimlikler):** **GEÇTİ** (2026-10-04; QA APK `e16da5a`'dan, `verify_apk` PASS; telefonun gezinme kipi ve saati değişmedi). **A:** 2. normal round + 300 sn'de gerçek TEST geçiş reklamı — FOCUS_OUT +68 ms, PAUSED +72 ms, SDK "gösterildi" +128 ms; gerçek GERİ ile kapanış → sonuç bir kez, sıradaki reklam önyüklendi. **E:** ilk round (332 sn) yok · gösterimden hemen sonraki round yok · 2 round ama 37 sn yok · 2 round + 300 sn uygun · meydan okuma bitişinde sıfır deneme (sayaç değişmedi; TASK/050 molası bitişte kapandı) · tutorial ve tutorial'dan doğan Level 1 sayılmadı, tutorial sonrası ilk normal round 412 sn'de bile yok, ikinci round'da reklam. **B1** (sahte arka uç — temel hatanın birebiri): "gösterildi", kapanış yok → 4,99 sn'de `uncovered_lease`; mola sırasında ertelenen üretim "Yeniden Başlat"ı eski sonucun YERİNE çalıştı; geç kapanış eski; gerçek dokunuş 1 bırakış. **B2** (gerçek TEST reklamı, kapanış saklı): gerçek öne dönüşten 3,0 sn sonra `resume_grace`, sonuç bir kez. **C1:** sahte molada gerçek HOME → 15 sn arka planda bitiş yok → dönüşte RESUMED (onStart) sonra FOCUS_IN, pay FOCUS_IN'den 2,98 sn sonra. **C2:** kayıp öne dönüş (yalnız yöneticiye simüle) + gerçek dokunuş → 5 sn sonra `input_evidence`, duraklatma düştü. **C3 (inceleme L1-1):** gerçek reklam üstteyken HOME + Son Uygulamalar dönüşü → Vulkan onStart RESUMED focus_in'siz geldi; kira ~27 sn, SDK kapanışına dek korundu, kurtarma 0. **D1:** gerçek devam CTA'sı → PAUSED "gösterildi"den önce, ödül ~8 sn'de tam bir kez. **D2:** kapanış saklı → ödül bir kez, 2,97 sn'de kurtarma. **D3:** ödül + kapanış saklı — TEST reklamının açtığı Play Store yarım sayfası nedeniyle girdi durduruldu, ~47 dk yalnız okuma yoklaması; bu sürede kira hiç süreyle bırakılmadı; owner reklamı kapattıktan sonra (QA uygulamasına tek dokunuş) `resume_grace`, devam 0 (sahte ödül yok). **G:** TASK/049 / 050 / 051 korundu. **F:** app-open N/A. Logcat: SCRIPT ERROR / çökme / ANR 0, yalnız Google örnek yayıncısı; QA kaldırıldı, üretim paketi hiç kurulmadı, `com.example` dokunulmadı. Kayıt: `build/qa_052-gate/device/GATE_LOG.md`.

### 18.7 Owner kararları — main entegrasyonu (2026-10-04, güncel)

TASK/052 owner onayıyla ff-only main'e alınırken (`1d2fb28 → c7e3ccc`) kabul edilen, bugün geçerli kararlar:

- **Zorunlu geçiş:** ilk üretim varsayılanı **2 kesinleşen normal round + 300 aktif sn** + mevcut 60 sn genel tam ekran
  beklemesi (`AdPolicy`, GAME_DESIGN §12.2). Matematiksel olarak sonsuza dek en iyi ilan EDİLMEDİ; ileride ayar ancak
  canlı metrikle (§19 madde 7).
- **İlk gün koruması:** ayrı bir tam gün zorunlu reklam yasağı şimdi EKLENMEDİ. Mevcut yeni oyuncu koruması: tutorial
  reklamsız; tutorial (ve tutorial'dan doğan round) sayılmaz; ilk normal round uygun olamaz; 2 round ve 300 sn
  kapılarının ikisi de gerekir. Daha güçlü bir ilk gün politikası ileride A/B testiyle denenebilir.
- **Ödüllü:** kotalar / ödüller DEĞİŞMEDİ (devam, refill, ödüllü sandık, +150 Hamur — mevcut sözleşmeler); daha çok
  izletmek için ödül azaltılmaz. Ödüllü envanter artırılmadı.
- **App-open:** ERTELENDİ / uygulanmadı (§18.4) — ancak ürün ileride gerçek bir yükleme / bekleme yüzeyi edinirse yeniden
  düşünülür; onboarding / tutorial / rıza sırası aynen.
- **Native eklenti takipleri — not, aktif görev DEĞİL:** yetim yeniden yükleme temizliği; banner iş parçacığı yarışı
  incelemesi (§18.5 madde 4).
- **Uyum — yayın şartı:** monetizasyon sıklığı değiştiği için TEEN / rıza / gizlilik yönlendirmesi herkese açık
  yayından ÖNCE yeniden incelenir (§18.5 madde 6). Hukuki / uyum onayı TAMAMLANMADI.
- **Takip gözlemleri — yalnız not, görev DEĞİL:** trafik sonrası canlı elde tutma / ARPDAU incelemesi; isteğe bağlı daha
  güçlü ilk gün koruması A/B testi; native yetim yeniden yükleme temizliği; native banner iş parçacığı yarışı incelemesi;
  yayından önce üretim TEEN / uyum yeniden incelemesi; mediation / bidding / hesap tarafı iyileştirme (§19); App Open
  yalnız ileride gerçek bir yükleme / bekleme yüzeyi olursa.

## 19. Hesap tarafı AdMob kontrol listesi (owner — TASK/052)

Bu görev AdMob hesabına **GİRMEDİ, hiçbir hesap ayarı değiştirilmedi**; geliştirme / testte yalnız Google TEST / örnek
kimlikleri kullanıldı. Aşağıdakiler owner'ın hesapta yapacağı / doğrulayacağı işler; her madde resmî Google sayfasına
bağlanır (2026-10-04'te okundu). Uyum değerlendirmeleri owner incelemesinde AÇIK.

**Durum (2026-10-04, main entegrasyonu):** owner bu repo görevinde AdMob hesap ayarlarını henüz DEĞİŞTİRMEDİ —
aşağıdakiler uygulanmış DEĞİL, önerilen işlerdir (yalnız doküman).

1. **eCPM tabanı — başlangıç Google optimize taban (her reklam birimi için).** Varsayılan Google optimize taban (tüm
   fiyatlar); yüksek / orta taban (Beta) ve elle taban seçenekleri var; yüksek taban doluluğu düşürebilir
   (support.google.com/admob/answer/3418058). Trafik olmadan elle para birimi değeri TAHMİN EDİLMEZ; deneme veriyle
   (mediation gruplarında A/B, sonuç için en az 10.000 istek — answer/9572326).
2. **Bidding / mediation — uygun ağ ve bölgeler için değerlendir, körlemesine ekleme.** Bidding ortakları gerçek
   zamanlı açık artırmayla yarışır; ek kurulum + mediation grubu gerekir (answer/9234488). Kod tarafında adaptör
   YOK; eklenirse Google'ın mediation rehberi SDK'nın açıkça başlatılmasını ister
   (developers.google.com/admob/android/mediation) ve §18.5 madde 3 (yaşam döngüsü varsayımı) yeniden doğrulanır.
3. **Üçüncü taraf ortaklar yalnız hesap eşlemesi + SDK / adaptör + gizlilik / rıza ortak yapılandırmasından sonra:**
   ortaklar Privacy & messaging'in GDPR / ABD eyaletleri listelerine eklenmezse reklam sunmayabilir (mediation
   rehberi); GDPR ortak listesi (answer/10113004). UMP mesajlarının hesapta yayında olduğunu doğrula.
4. **Banner yenilemeyi konsolda doğrula:** Google optimize otomatik yenileme önerilir, özel değer 30–150 sn
   (answer/3245199); kod yenileme isteği göndermez. Mediation eklenirse üçüncü taraf arayüzlerinde banner yenilemesi
   kapatılmalı (mediation rehberi).
5. **App-open:** UYGULANMADI (§18.4) — hesapta app-open birimi GEREKMEZ. İleride uygulanırsa: ayrı üretim app-open
   birimi + sıklık sınırı; QA'da yalnız Google TEST kimliği.
6. **QA / üretim kimlikleri ayrı kalır:** debug / QA derlemesi yalnız Google örnek kimlikleri (`AdConfig`, BUILD TÜRÜ);
   4 gerçek kimlik (App ID + Banner + Rewarded + Interstitial) yalnız release yapılandırmasına owner girer; kaynakta yer
   tutucu üretim kimliği YOK. Kendi gerçek reklamlarına tıklanmaz.
7. **Sıklığı sıkılaştırmadan / gevşetmeden önce yeterli trafikle izle:** match rate (yanıt alan istek oranı), show rate
   (dönen reklamların gösterilme oranı) — glossary table/16327896 — eCPM, gösterim / DAU, ödüllü katılım (opt-in) oranı,
   ARPDAU, oturum süresi, D1 / D7 elde tutma (Play Console), çökme / ANR, reklamla ilgili olumsuz yorumlar. Yetim
   yeniden yükleme (§18.4) show rate'i düşürür. 2 round + 300 sn yalnız `AdPolicy` sabitlerinden ayarlanır (altına
   inilmez).
8. **İsteğe bağlı sunucu tarafı yedek sınır:** gerçek geçiş birimi oluşturulunca gevşek bir birim sıklık sınırı
   (Google ve üçüncü taraf kaynaklara uygulanır; kısa sunucu gecikmesi sınırı zaman zaman aşabilir; sayfada önerilen
   değer YOK — answer/6244508). İstemci kuralını ezmeyecek gevşeklikte.
9. **Yaş / içerik / ödüllü politika:** TEEN → TFAT TEEN + en yüksek derece T, ADULT → UNSPECIFIED + MA (TASK/043, kodda);
   ödüllü reklam açık seçimle, eylem ve ödül önceden yazılı, ödül tamamlanınca teslim (answer/7313578) — kodda CTA'lar
   açık seçim, ödül yalnız SDK "ödül kazanıldı" geri çağrısıyla. Hesapta içerik / engelleme ayarları ve 13–17 uyum
   incelemesi owner'da AÇIK (AGE_BAND_ROUTING, AUDIENCE_DECISION).

## 20. TASK/060 — güç BAŞINA ödüllü refill kotası + Gameplay HUD V3 (TAMAM + MAIN, 2026-10-09)

**Durum (2026-10-09):** **TAMAM + MAIN** — owner görsel onayı + elle Samsung A36 testi APPROVED / PASS; owner onayıyla ff-only
`75fe3f3 → 27b60e5` (merge commit YOK; dal `task/060-gameplay-hud-v3-rewarded-powers` duruyor); entegrasyonda testler yeniden
koşulmadı. *(Dal aşaması 2026-10-08: dal, taban `75fe3f3`, main'de değildi — tarihsel.)* Owner kararı (Product Vision
V3, GitHub Issue #1 §3): her gücün kendi günlük ödüllü kotası **2 başarılı ödül**; dört bağımsız sayaç (GAME_DESIGN §5.7.3).
Diğer reklam sayıları DEĞİŞMEDİ: devam 2 / round, reklamlı sandık 2 / gün, +150 Hamur 1 / gün, zorunlu geçiş ≥ 2 normal
round + ≥ 300 aktif sn (+ 60 sn tam ekran bekleme), banner yüzeyleri, yaş / rıza yönlendirmesi.

- **Tek kaynak:** `RewardedPolicy.DAILY_GRANTS_PER_POWER = 2`; API tip-bazlı (`grants_today(type)` / `remaining_today(type)` /
  `can_grant(type)` / `grant(type)`); eski argümansız ortak kota API'si KALDIRILDI. `AdPolicy.rewarded_caps()` artık
  `power_refill_per_power_per_day = 2`, `power_kinds = 4` okur.
- **Kayıt:** sürümlü blok `rewarded_power_quota` {version 1, day_key, grants {bomb, upgrade, shake, clear_small}}; gün = kabul
  edilen yerel gün (`Missions.accepted_day()` — Günlük / Görevler ile aynı, saat geri alınırsa geri gitmez). Grant: tip +
  gün + o gücün kotası → YALNIZ o gücün stoğu +1 + YALNIZ o gücün sayacı +1 → TEK `save_game()`. Red / yinelenen / yanlış tip:
  değişim ve disk yazması YOK. Okuma yazmaz (yeni gün okumada 0). Bozuk blok / sayaç / gün / sürüm → o gün KAPALI.
- **Göç (yüklemede, bellekte):** eski `rewarded_power_date` + tek sayı `rewarded_power_grants` → eski tarih bugünse dört sayaç
  eski kullanımın 0..1'e normalleşmiş değeriyle başlar (geçiş gününde fazladan hak yok), değilse 0/2; V3 bloğu varsa öncelik
  onun; eski anahtarlar düşer; stok / Hamur / level / yıldız aynen; açılışta disk yazması yok.
- **Ödül zinciri DEĞİŞMEDİ:** pencere İZLE → `Main._on_rewarded_power_requested(type)` (BU gücün kotası) → token + tip →
  `MonetizationManager.show_rewarded_power` → SDK **"ödül kazanıldı"** (açık talep + aynı reklam kimliği + ilk ödül + iptal
  değil) → `Main.grant_rewarded_power(type, token)` (token grant'ten ÖNCE temizlenir) → `RewardedPolicy.grant(type)`. İstek /
  yükleme / gösterim / tıklama / ödülsüz kapanış / gösterim hatası / iptal / round değişimi = 0 grant, 0 kota. Gerçek SDK sırası
  (ödül kapanıştan önce, A36 §14) aynen; kapanış ödül vermez.
- **Fail-closed:** sağlayıcı yok / SDK hazır değil / yaş UNKNOWN–13 altı / rıza yok / reklam yok → İZLE pasif + kısa sebep;
  TEEN / ADULT mevcut yaş yönlendirmesinden geçer. QA'da yalnız Google TEST reklamları; gerçek üretim kimlikleri ayrı release işi.
- **Ekonomi (ölçüm, `python tools/shop_economy.py quota`, deterministik):** yoğun oyuncu (10 round/gün) her fırsatta izlerse
  güç reklamı ~1,0 → ~4,3 / gün, gün-90 Hamur medyanı 3.730 → 43.070 (sink'siz referans ~50.000); %50 izleme varsayımında
  ~2,4 / gün ve 19.445; orta oyuncu 17.275 → 24.145 (hep izler). Fiyat / sandık / revive / zorluk DEĞİŞTİRİLMEDİ.
  **Owner kararı (2026-10-09):** güç başına 2/gün ve dört bağımsız sayaç KORUNUYOR; güç fiyatları, Hamur ödülleri ve oyun
  dengesi değişmedi; reklam kaynaklı Hamur enflasyonu değerlendirmesi **TASK/062 Mağaza V3'e ertelendi (PENDING)**.
- **Testler:** `rewarded_powers_test` (saf kurallar, tek yazma, göç, gerçek Main + yönetici + `FakeAdBackend` geri çağrı
  sıraları, yaş / rıza, meydan okuma, kaynak sözleşmesi), `hud_v3_test`, uyarlanan `refill_test`, `revive_refill_ui_test`,
  `monetization_test`, `ad_policy_test`, `save_persistence_test`, `daily_rewards_test`, `fullscreen_break_recovery_test`,
  `round_finish_modal_test` (kanıt: PROJECT_STATUS §4.40).
- **Gerçek Samsung A36 cihaz kanıtı (2026-10-09; QA paketi `.qa`, üretim kodu `8924974`, yalnız Google TEST kimlikleri;
  `build/qa_060-gate/device/A36_GATE_SUMMARY.txt`)** — üç kanıt türü AYRI:
  - *Gerçek SDK (Google TEST ödüllü reklam):* 4 gösterim / 4 "ödül kazanıldı" (~9 sn) / 4 kapanış (tek GERİ) → her biri yalnız
    kendi gücüne +1 ve kendi sayacına +1 (Bomba 0/2 → 1/2 → 2/2; Bomba 2/2 iken Sarsıntı 0/2 → 1/2; Büyütücü 0/2 → 1/2);
    2/2'de İZLE EXHAUSTED ve SDK isteği yok; gerçek SDK yükleme hatası (geçersiz test birimi, kod 3) → İZLE UNAVAILABLE,
    istek / stok / kota yok; reklam üstteyken Hamur düğmesi kilitli; soğuk yeniden açılışta kota + stok kalıcı; gerçek TEST
    banner oyun yuvasında. Loglar: SCRIPT ERROR 0, çökme / ANR 0, yalnız Google TEST yayıncı kimliği.
  - *Sentetik cihaz-içi probe (gerçek SDK geri çağrısı DEĞİL):* son gerçek "kazanıldı"nın aynı reklam kimliğiyle yeniden
    oynatılması → yönetici "stale", `Main.grant_rewarded_power` false; açık gerçek talep sırasında yanlış tip / yanlış token →
    ikisi de reddedildi, açık token korundu, ardından gerçek ödül doğru güce.
  - *Yalnız QA sahte arka uç (`FakeAdBackend`; gerçek SDK kanıtı DEĞİL):* ödülsüz kapanış → stok / kota yok + "tamamını izle"
    notu; gösterim onayı zaman aşımı → stok / kota yok; bekleyen talep + 1 sn sonra Hamur dokunuşu → satın alma yok; sağlayıcı
    hazır değil → İZLE UNAVAILABLE.
  - *Sınır:* gerçek reklamı ödülden ÖNCE kapatmak ulaşılamadı — Google TEST ödüllü reklamı ödüle kadar GERİ'yi yok saydı
    (M8.9-02 bulgusuyla aynı); bu yol masaüstünde ve sahte arka uçla kanıtlı.
  - *Owner:* elle A36 oynanış testi PASS (ayrı `com.obappstudio.squishymerge.qa060` uygulaması, yalnız TEST reklamları).
- **Masaüstü:** tam kapı `27b60e5` 59 / 59, 7601 kontrol, 0 FAIL, 0 SCRIPT ERROR (`27b60e5` yalnız test kodu; önceki tek kapı
  `20f1b27` 58 / 59 — `revive_test` zamanlama kararsızlığı, sonra test-only düzeltildi; PROJECT_STATUS §4.40).
