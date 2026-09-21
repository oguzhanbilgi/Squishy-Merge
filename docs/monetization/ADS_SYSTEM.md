# ADS_SYSTEM.md — AdMob reklam sistemi (M8.9-01)

> Kanonik doküman. Kilitli ürün kuralları GAME_DESIGN §5.7.3 / §11'de;
> burada onların **uygulanma biçimi** ve teknik seçimler anlatılır. Rıza /
> gizlilik ayrıntısı: [PRIVACY_CONSENT.md](PRIVACY_CONSENT.md).
>
> **Durum (2026-09-21):** entegrasyon + Gradle export + deterministik sahte
> sağlayıcı testleri + TEST reklam APK'sı tamam; **A36 test-reklam cihaz kapısı
> GEÇTİ** (M8.9-01.1, §12) — gerçek Google test banner'ı (Ana Sayfa / Mağaza /
> Koleksiyon) ve gerçek test ödüllü reklamla devam + refill cihazda doğrulandı,
> owner görsel onayı PASS. **Üretime hazır DEĞİL:** eklentinin UMP yüzeyi
> (PRIVACY_CONSENT §4) ve COPPA/kitle kararı (§6) açık; üretim kimliği YOK.

## 1. Kapsam (v1 monetizasyon planı)

| ürün | durum | kural |
|---|---|---|
| Ödüllü devam (revive) | ✅ bağlı, test reklamı | round başına en fazla 2 başarılı devam (board sayar) |
| Ödüllü güç refill'i | ✅ bağlı, test reklamı | günde 1, DÖRT gücün toplamı; yalnız seçilen güce +1 |
| Banner (uyarlanabilir sabit, alt) | ✅ Ana Sayfa / Mağaza / Koleksiyon | oyun, sonuç, Harita ve pencereli tam ekranlarda GİZLİ |
| Interstitial / rewarded interstitial / app-open | ❌ bilerek YOK | gerçek retention verisi gelene kadar ertelendi |
| IAP / Billing, mediation, üretim kimlikleri | ❌ bu milestone'da yok | sonraki adımlar |

Hamur satın alma yolu (`PowerUpEconomy.purchase`) reklamdan tamamen bağımsız
kaldı; skinler asla reklam/paraya bağlı değil.

## 2. Seçilen eklenti ve SDK sürümleri (araştırma 2026-09-21)

| | |
|---|---|
| Eklenti | `godot-sdk-integrations/godot-admob` **v6.0** (2026-02-01), tag commit `90e3c616ea3c680e3875c31e6bcccffbebbe9d3b` |
| Lisans | MIT (`addons/AdmobPlugin/LICENSE`) |
| Kurulum | AssetLib ile aynı release zip'i (`AdmobPlugin-Android-v6.0.zip`, SHA-256 `9ec26002…973f24`) `addons/AdmobPlugin/` altına kopyalandı, kaynak DEĞİŞTİRİLMEDİ; ayrıntı `addons/AdmobPlugin/VERSION.md` |
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
  `show_rewarded_power(main, type, token)` (M8.5-04/06'dan beri aynı) ve
  M8.9-01'de eklenen `is_rewarded_ready()` / `rewarded_note()` /
  `ensure_rewarded()` / `cancel_rewarded_request()` / `set_surface()`.
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
_ready → CONSENT_CHECKING (update_consent_info)
   ├─ NOT_REQUIRED / OBTAINED ─────────────────────→ ADS_ALLOWED → MobileAds.initialize
   ├─ REQUIRED + form var → CONSENT_FORM (load→show) → kapanış → durum yeniden okunur
   ├─ REQUIRED + form yok / UNKNOWN ────────────────→ ADS_NOT_ALLOWED (+ sınırlı yeniden deneme)
   └─ update HATASI → SDK'nın önceki oturum durumu:
        izin veriyorsa ERROR_WITH_PREVIOUS_STATE (reklam istenir), vermiyorsa ADS_NOT_ALLOWED
initialization_completed → sdk_ready → ödüllü önyükleme + banner senkronu
```

Reklam yalnız `ads_allowed() and sdk_ready` iken istenir. Oyun rızayı
BEKLEMEZ (spinner yok): Ana Sayfa normal açılır, form üstte belirir.

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
`SaveManager.grant_rewarded_powerup` (1/gün, tek transaction). Yönetici
kayda hiç yazmaz.

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
- **Yüzeyler (v1): Ana Sayfa, Mağaza, Koleksiyon.** Oyun ekranı, sonuç
  penceresi ve Harita banner DIŞI:
  - *Oyun:* `GameplayLayout` BANNER dikişi (M8.6-02) hâlâ 0 px. Banner
    koymak 16:9'da BOARD'u küçültüp kamera zoom'unu düşürür (parça/dokunma
    hedefi küçülür); "gelir için zorlama" yok — gerçek retention/eCPM verisi
    gelene kadar ertelendi. Dikiş duruyor, yeniden yazım gerekmez.
  - *Harita:* level 1 düğümü + "OYNA" plakası + patika başı cover-fit
    edilmiş zemin sanatının alt %12'sinde; alt pay ayırmak zemini yeniden
    kırpmayı gerektirir. v1'de dışarıda, veriyle yeniden değerlendirilir.
- **Yuva:** `MonetizationManager._compute_banner_slot()` açılışta bir kez
  `AdSize.getPortraitAnchoredAdaptiveBannerAdSize(genişlik)` yüksekliğini
  (dp) × yoğunluk × (720 / pencere genişliği) tuval pikseline çevirir ve
  `UiKit.set_banner_slot()`'a yazar (A36: 64 dp × 2.625 → 168 px → 112
  tuval px; 16:9 720p telefonda ~112). Ana Sayfa / Mağaza / Koleksiyon alt
  bütçesi `UiKit.bottom_inset(view) = safe_bottom + slot` (Ana Sayfa OYNA
  yukarı çıkar, Mağaza/Koleksiyon kaydırma dip payı + Mağaza toast'u
  yukarı). Yuva oturum boyunca SABİT: banner dolmasa da düzen zıplamaz,
  boşken zemin görünür. Eklenti yoksa 0 (masaüstü düzeni birebir eski).
- **Yaşam döngüsü:** `set_surface()` her ekran geçişinde (Main `_show_tab`,
  `_start_level`, sonuç). `LOADED` banner yüzey dışında `hide`, yüzeye
  dönünce `show` (yeni yükleme yok); SDK'nın otomatik yenilemesi
  (`banner_ad_refreshed`) durumu değiştirmez. No-fill → 15/60/180/600 sn
  geri çekilme, en çok 6 deneme; sınır dolunca gezinme yeni istek açmaz.
  Uygulama öne dönünce senkron (çift gösterim yok). Yönetici silinirken
  banner gizlenir, yuva sıfırlanır.

## 7. Analitik olay dikişi (`AdEvents`)

Sağlayıcı YOK (sonraki milestone). `AdEvents.emit(name, ctx)`; abone
`subscribe(callable)`; son 200 olay bellekte.

Olaylar: `rewarded_requested` (oyuncu CTA), `rewarded_loaded`,
`rewarded_load_failed`, `rewarded_showed`, `rewarded_impression`,
`rewarded_earned`, `rewarded_dismissed`, `rewarded_show_failed`,
`banner_loaded` (`refreshed` bayrağı), `banner_load_failed`,
`banner_impression`, `banner_clicked`. Bağlam: `placement`
(`revive` / `refill` / `preload`), refill'de `power` (kayıt anahtarı:
`bomb` / `upgrade` / `shake` / `clear_small`), `ad_id`, `code`, `message`,
`stale`, `surface`, `t_msec`. Firebase bilerek entegre edilmedi (rıza
mimarisi gerektirmiyor).

## 8. Test ve üretim yapılandırması

- Tek dosya: `addons/AdmobPlugin/android_export.cfg` — hem eklentinin export
  kancası (manifest `APPLICATION_ID`) hem `AdConfig` (çalışma zamanı reklam
  birimi kimlikleri) okur. Godot "all_resources" export'u `.cfg` dosyasını
  PAKETLEMEZ; proje eklentisi `addons/squishy_ads_export/` dosyayı
  `EditorExportPlugin.add_file` ile PCK'ye ekler ve export anında doğrular
  (log: `SquishyAdsExport: paketlendi -> AdConfig(...)`). Export edilmiş
  build'de dosya yoksa `AdConfig` KAPALI kalır (test varsayılanına düşmez). **Şimdi:** `is_real=false`, Google örnek
  kimlikleri (app `…~3347511713`, rewarded `…/5224354917`, adaptive banner
  `…/9214589741`). Eklentinin kendi varsayılan banner kimliği (`…/2014213617`)
  Google'ın *katlanabilir* banner örneğidir, kullanılmıyor.
- **Üretim adımı (owner):** AdMob konsolunda uygulama + 2 reklam birimi
  (rewarded, banner) oluştur → `[Release]` anahtarlarını doldur →
  `is_real=true`. `AdConfig.is_valid()` gerçek modda boş/örnek kimlik görürse
  reklamı HİÇ başlatmaz (sessiz test kimliğine düşüş yok). Test cihazları:
  `is_real=false` iken eklenti cihazın hash'ini otomatik test cihazı yapar;
  gerçek modda `Admob.test_device_hashed_ids` gerekir (henüz bağlı değil).
- `[Debug] debug_geography = eea | regulated_us_state | other | disabled`
  (yalnız test modunda; A36 kapısında rıza formunu görmek için `eea`).
- Kitle/içerik: `max_ad_content_rating = G`; TFCD / TFUA **UNSPECIFIED** —
  owner politika kararı bekliyor (PRIVACY_CONSENT §6).

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

## 10. Testler

- `tools/monetization_test.tscn` — **181 kontrol**, internet/cihaz yok:
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

1. **AdMob hesabı:** uygulama kaydı (App ID), rewarded + banner reklam
   birimleri, Privacy & messaging'de GDPR (ve gerekiyorsa US state) mesajı.
   Bunlar olmadan üretim kimliği/rıza mesajı yok — bkz. §8.
2. **Kitle/COPPA:** PRIVACY_CONSENT §6.
3. **Eklenti boşluğu (ÜRETİM ENGELİ):** v6.0 UMP'nin `canRequestAds()` /
   `getPrivacyOptionsRequirementStatus()` / `showPrivacyOptionsForm()`'unu
   sarmaz VE `debug_geography` cihazda uygulanamıyor (upstream #120, Long/Integer);
   eşdeğer türetme ve seçenekler PRIVACY_CONSENT §4. Üretim öncesi küçük bir
   eklenti yaması (AAR yeniden derleme) ya da upstream PR kararı gerekiyor.
4. ~~**Cihaz kapısı (A36, test reklamı)**~~ → **GEÇTİ (§12)**; EEA formu cihazda
   #120 yüzünden gösterilemedi.
5. **Gameplay/Harita banner'ı:** veriyle yeniden değerlendirme (§6).
6. **Next-Gen SDK geçişi:** eklentiye bağlı, v1 için gerekmez (§2).
