# PRIVACY_CONSENT.md — UMP rıza akışı ve gizlilik (M8.9-01 → M9-01 → TASK/042)

> Kanonik doküman. Reklam mimarisi: [ADS_SYSTEM.md](ADS_SYSTEM.md); kitle /
> COPPA: [AUDIENCE_DECISION.md](AUDIENCE_DECISION.md); Play hazırlığı:
> [../ANDROID_RELEASE_CHECKLIST.md](../ANDROID_RELEASE_CHECKLIST.md).
> Kaynaklar (2026-09-21 / 2026-09-22'de okundu): developers.google.com/admob/android/privacy,
> …/privacy/api/reference/…/ConsentInformation, …/ConsentDebugSettings.DebugGeography,
> …/privacy/release-notes, …/test-ads; eklenti kaynağı `godot-admob` v6.0.
>
> **M9-01 (2026-09-22):** eklenti boşluğu KODDA KAPANDI. `godot-admob` v6.0'a
> küçük, deterministik bir yama (tools/admob_plugin) UMP'nin resmî
> `canRequestAds()` / `getPrivacyOptionsRequirementStatus()` /
> `showPrivacyOptionsForm()` çağrılarını ekledi ve `debug_geography` #120
> hatasını (Long/Integer) düzeltti. İzin kapısı artık resmî `canRequestAds()`;
> gizlilik seçenekleri resmî durum + resmî form. M9-01'de telefon/ADB yoktu;
> **M9-01.1'de (2026-09-23) gerçek Samsung A36'da doğrulandı — GEÇTİ, runtime
> değişmedi** (§7; plan §8); M9-01 + M9-01.1 2026-09-24'te main'e ff-only alındı.
>
> **TASK/042 (2026-09-27; `task/042-gma25-production` — `83b86a9` + `3d15402` — main'e
> ff-only alındı 2026-09-27):** üretim eklentisi GMA **25.3.0**'a geçti; UMP
> SDK artık **4.0.0** (`play-services-ads-api:25.3.0` üzerinden geçişli, açık override
> yok; önce 3.2.0). UMP sarmalayıcısı (yama `0001`) ve bu dokümandaki rıza sözleşmesi
> DEĞİŞMEDİ; Samsung A36'da yeniden doğrulandı — **GEÇTİ** (§7). Yeni: istek
> yapılandırması (derece G, TFCD / TFUA unspecified, yaş işlemi UNSPECIFIED) artık
> `MobileAds.initialize()`'dan ÖNCE bir kez uygulanıyor, geri okunup doğrulanıyor;
> uyuşmazsa SDK başlatılmıyor (fail-closed). Başlatma hâlâ yalnız `canRequestAds()` true
> iken (§1, §3). Yaş bandı yönlendirmesi YOK (TASK/043, başlamadı); 13–17 genç reklam
> işlemi owner `UYUM:` engeli AÇIK (§6); Play Age Signals reklamda hiç kullanılmaz.
> RequestConfiguration kusuru KAPALI kalıyor (TASK/041). Release kapısı BLOCKED —
> CODE 0 · OWNER 9 · CONFIG 0.

## 1. İlke

- **SDK durumu tek gerçek.** Kendi GDPR/rıza önbelleğimiz yok; kayıt
  dosyasına rıza yazılmaz. Google'ın uyarısı aynen uygulanır: rıza durumunu
  uygulamanın önbelleğinden ya da saklanan rıza dizgesinden okuma.
- Her uygulama açılışında (onboarding bittikten sonra, M8.10)
  `requestConsentInfoUpdate` (eklenti: `update_consent_info`). Form
  gerekiyorsa SDK'nın formu gösterilir; ardından **karar UMP
  `canRequestAds()`'indir** (M9-01). Mobile Ads SDK ancak `canRequestAds()`
  true iken başlatılır ve **her reklam yüklemesinden hemen önce yeniden
  sorulur** (`MonetizationManager._request_permitted`). TASK/042: başlatma
  istek yapılandırmasını (yaş işlemi UNSPECIFIED dahil) `MobileAds.initialize()`'dan
  önce bir kez uygular, geri okuyup doğrular; uyuşmazsa SDK başlamaz (§3).
- Sonsuz bekleme yok: oyun rızayı beklemez, pencerelerde reklam CTA'sı
  pasif + gerçek sebep ("hazırlanıyor" / "şu anda kullanılamıyor").

## 2. Uygulama durumları (`MonetizationManager.AdsState`)

| durum | anlam | reklam |
|---|---|---|
| `UNAVAILABLE` | arka uç yok (masaüstü / eklenti yok / yapılandırma geçersiz) | hayır |
| `CONSENT_CHECKING` | `update_consent_info` cevap bekliyor | hayır |
| `CONSENT_FORM` | SDK "REQUIRED" + form var: form yükleniyor/gösteriliyor | hayır |
| `ADS_ALLOWED` | güncelleme başarılı ve `canRequestAds()` true | evet → SDK başlatılır |
| `ADS_NOT_ALLOWED` | `canRequestAds()` false (rıza gerekli/alınmadı, form yok, önceki durum yok) | hayır; sınırlı yeniden deneme |
| `ERROR_WITH_PREVIOUS_STATE` | güncelleme HATASI ama `canRequestAds()` true (önceki oturumun rızası) | evet |

`ERROR_WITH_PREVIOUS_STATE` Google'ın rehberine dayanır: hata olursa yine
`canRequestAds()`'e bakılır; UMP önceki oturumun rıza durumunu kullanır. Yani
**geçici bir ağ hatası geçerli bir önceki rızayı silmez** (testle:
`monetization_test` "update HATASI + önceki geçerli rıza").

Yeniden deneme (M8.9 aynen): hata/izinsizlikte 30 s ve 120 s sonra birer
güncelleme; sonra yalnız pencere açılışında (devam/refill/günlük) ve en az
20 s aralıkla bir güncelleme daha. Spam yok. Kullanıcının gizlilik
seçenekleri formunda verdiği ret için otomatik yeniden deneme YOK.

## 3. Akış (eklenti API'siyle, M9-01)

```
update_consent_info()
  ├─ consent_info_updated
  │      REQUIRED + is_consent_form_available() → load_consent_form → show_consent_form
  │           └─ consent_form_dismissed / consent_form_failed_to_load → can_request_ads()
  │      aksi hâlde → can_request_ads()
  │           true  → ADS_ALLOWED → initialize()   (canRequestAds yeniden sorulur)
  │           false → ADS_NOT_ALLOWED (+ sınırlı deneme)
  └─ consent_info_update_failed → can_request_ads()   (form DENENMEZ)
         true → ERROR_WITH_PREVIOUS_STATE → initialize();  false → ADS_NOT_ALLOWED (+ deneme)
initialization_completed → her yükleme (ödüllü / geçiş / banner) ÖNCESİ can_request_ads()
   false çıkarsa istek gitmez, durum ADS_NOT_ALLOWED (banner gizlenir)
```

**TASK/042 — şemadaki `initialize()`:** `_ensure_sdk()` (tek sefer; `_sdk_ready` /
`_sdk_initializing` / `_sdk_refused` korumalı) → `AdmobBackend.initialize()` =
`set_request_configuration()` → `get_applied_request_configuration()` geri okuması →
{yaş işlemi, derece, TFCD, TFUA} karşılaştırması → ANCAK eşleşirse
`MobileAds.initialize()` → `initialization_completed` → `_sdk_ready` → yüklemeler.
Uyuşmazlık / eksik geri okuma → `push_error`, SDK BAŞLATILMAZ, oturum reklamsız, yeniden
deneme yok (`sdk_refused`; ödüllü notu "Reklam şu anda kullanılamıyor."); onaylı AAR'la
bu yola hiç girilmedi. Yaş işlemi üretimde herkes için UNSPECIFIED, rıza / SDK'dan önce
arka uca verilir ve SDK yapılandırıldıktan sonra KİLİTLİ (farklı değer reddedilir). Rıza
kapısı değişmedi: zincir yalnız `canRequestAds()` true iken çalışır; onboarding ertelemesi
aynen.

Google ayrıca `requestConsentInfoUpdate()` çağrısından hemen sonra, önceki
oturumun rızasıyla SDK'yı paralel başlatmaya izin veriyor. **Bilerek
yapılmadı:** güncellemenin sonucu (başarı ya da hata) birkaç saniye içinde
geliyor ve M8.9/M8.10'da cihazda doğrulanmış sıra korunuyor; hata yolu zaten
önceki rızayı kullanıyor.

Test modunda (DEBUG build) eklenti cihazın hash'ini UMP test cihazı olarak
ekler (emülatörler otomatik test cihazıdır); `[Debug] debug_geography` yalnız
**DEBUG build'de** uygulanır (M9-01: release'te `AdConfig` coğrafyayı daima
boşaltır, eklenti cephesi `is_real` iken ve Java tarafı gerçek modda yok sayar
— üç kilit). v6.0'daki #120 hatası (Java `instanceof Integer`, Godot `Long`
gönderir → coğrafya sessizce yok sayılır) yama ile düzeldi (`instanceof Number`).
TASK/042 (yama `0003`): eklentinin DEBUG'a özel Mobile Ads test cihazı yolu reklam
kimliğini ve kimlik listesini artık LOGLAMIYOR (`Added Advertising ID as test device
(value not logged)`, `Set test device IDs: <n> (values not logged)`); release'te bu dal
hiç çalışmaz.

## 4. Eklenti: resmî UMP çağrıları (M9-01) ve geri düşüş

`addons/AdmobPlugin` = upstream v6.0 + `tools/admob_plugin/0001-…patch` (bu
bölüm) *(bugün + `0002` — TASK/041, RequestConfiguration dönüşümü + `0003` — TASK/042,
GMA 25.3.0 + yaş işlemi; `0001` değişmedi)* (deterministik yeniden derleme ve doğrulama:
`tools/admob_plugin/README.md`, `addons/AdmobPlugin/VERSION.md`). Upstream'de (v6.0,
v7.0, `main`; 2026-09-22) bu üç çağrı YOK; #120 yalnız v7.0'da (Godot 4.7 hedefli)
düzeltilmiş.

**UMP sürümü (TASK/042):** `com.google.android.ump:user-messaging-platform:4.0.0`,
`play-services-ads-api:25.3.0` üzerinden geçişli (açık override yok; önce 3.2.0). Derleme
betiği çözümlenen sınıf yolunu birebir doğrular (`play-services-ads:25.3.0` /
`-api:25.3.0` / `user-messaging-platform:4.0.0`, aksi hâlde başarısız). Kullandığımız UMP
sınıflarında 3.2.0 → 4.0.0 yalnız ekleme (`setConsentSyncId`), `DebugGeography` değerleri
aynı (TASK/040, §7); aşağıdaki tablo iki sürümde de aynı.

| gereken (UMP) | eklenti (yamalı) | yönetici kullanımı |
|---|---|---|
| `ConsentInformation.canRequestAds()` | `can_request_ads()` | izin kararı + SDK başlatma + her yükleme öncesi |
| `getPrivacyOptionsRequirementStatus()` | `get_privacy_options_requirement_status()` → `"REQUIRED"`/`"NOT_REQUIRED"`/`"UNKNOWN"` | Ayarlar'daki "Gizlilik seçenekleri" satırı yalnız REQUIRED iken |
| `UserMessagingPlatform.showPrivacyOptionsForm()` | `show_privacy_options_form()` → `privacy_options_form_dismissed` | satırın "Aç" butonu; kapanınca `canRequestAds()` yeniden |
| `debug_geography` (int) | `instanceof Number` | yalnız DEBUG build |

**Geri düşüş (yamasız eklenti):** `AdmobBackend.has_privacy_api()` false
dönerse (yamalı AAR'ın kaydettiği `privacy_options_form_dismissed` sinyali
yoksa) yönetici M8.9'un SDK'dan türettiği eşdeğere düşer ve uyarı basar:
`canRequestAds` ≡ güncelleme sonrası durum NOT_REQUIRED/OBTAINED (Google'ın
tanımının kendisi); gizlilik seçenekleri ≡ güncelleme yapıldı + form var;
form ≡ `load_consent_form` + `show_consent_form`. Release kapısı yamasız
AAR'la yüklenebilir AAB üretmez (AAR SHA-256 kontrolü). *(TASK/042'den beri onaylı
release AAR `f5a563a7…` (v6.0 + 0001 + 0002 + 0003; debug `a78acb22…`); TASK/041 AAR'ı
`14c745e9…` artık onaylı değil, kusurlu M9 AAR'ı `90d35992…` — ikisi de dönerse CODE.)*

M8.9'un açık noktası kapandı: ABD eyalet mesajında rıza NOT_REQUIRED iken
gizlilik seçenekleri REQUIRED olabiliyor — türetme bunu göremiyordu; resmî
durum görüyor (`monetization_test` "ABD eyalet mesajı").

## 5. Ayarlar penceresi

- **Gizlilik metni** (`SettingsPanel.PRIVACY_TEXT`, değişmedi): hesap/sunucu/
  analitik yok; ilerleme cihazda; ödüllü, banner ve geçiş reklamları için
  Google AdMob; reklam SDK'sı reklam kimliği gibi cihaz verilerini Google'ın
  politikasına göre işleyebilir; uygulama içi satın alma yok. Bu bir ÖZET;
  Play'in istediği tam gizlilik politikası değildir (§6).
- **"Gizlilik seçenekleri" satırı** (`lock`): yalnız
  `MonetizationManager.privacy_options_required()` true iken görünür — M9-01:
  UMP `getPrivacyOptionsRequirementStatus() == REQUIRED`. "Aç" →
  `showPrivacyOptionsForm()`. Google: REQUIRED iken görünür bir giriş noktası
  ZORUNLU, değilse gizli.
- **"Gizlilik politikası" satırı** (`help`, M9-01, YENİ ama bugün GİZLİ):
  project.godot `squishy/privacy/policy_url` bir `https://` adresiyse görünür,
  "Aç" → `OS.shell_open(url)`. Boşken satır hiç görünmez (sahte bağlantı yok).
  URL owner'da; release kapısı boş/https-dışı URL'le yüklenebilir AAB
  üretmez. Görsel olarak cihazda henüz görülmedi (URL yok).

## 6. Owner / Play politika kararları

| konu | durum | nerede |
|---|---|---|
| Kitle / COPPA / TFCD / TFUA / içerik derecesi | **Ürün kitlesi KARARI (owner, 2026-09-25):** 13+ genel kitle (Play 13–15 / 16–17 / 18+), `general_13_plus`; TFCD / TFUA `unspecified`, derece G — değişmedi. **13–17 genç reklam işlemi / yargı bölgesi uyumu AÇIK** — üretimden önce çözülmeli: 13–15 / 16–17 bazı yerlerde çocuk sayılabilir, GMA 24.9.0 TFAT `TEEN` gönderemez, `unspecified` TEEN değil. *(Sonra: TASK/042 — üretim GMA 25.3.0; TFAT UNSPECIFIED / CHILD / TEEN eklentide teknik olarak var, üretim varsayılanı herkes için UNSPECIFIED, SDK yapılandırıldıktan sonra kilitli; yaş bandı yönlendirmesi YOK. Owner yönü (2026-09-27): TASK/043 — 13–17 → TEEN, 18+ → olağan rıza denetimli yetişkin yolu (UNSPECIFIED); BAŞLAMADI ve `UYUM:` engelini kapatmaz — `teen_ad_treatment_resolved=false`, uyum AÇIK, owner'da.)* Karar yerel rıza / reklam kurallarını geçersiz kılmaz; bugünkü UMP akışı TFUA `unspecified` ile çalışır (yaşa özel işlem yok). TASK/040: strateji karar tablosu + TEEN fizibilitesi (A36); Play Age Signals reklam kararında KULLANILMAZ | [AUDIENCE_DECISION.md](AUDIENCE_DECISION.md) §0, §2.2 · [GLOBAL_TEEN_AD_TREATMENT.md](GLOBAL_TEEN_AD_TREATMENT.md) |
| AdMob Privacy & messaging: GDPR (EEA/UK/CH) mesajı | owner, AdMob konsolu — kişiselleştirilmiş reklam için sertifikalı CMP (UMP) mesajı gerekli; mesaj yoksa bu bölgelerde sınırlı reklam | checklist §E |
| ABD eyalet mesajı | isteğe bağlı araç (yasal uyum owner'da); yoksa sınırlı veri işleme seçeneği | checklist §E |
| Gerçek reklam birimleri (App ID + 3 birim) | owner, AdMob konsolu | ADS_SYSTEM §8 |
| Gizlilik politikası URL'i | owner barındırır (Play: konsolda VE uygulama içinde) | checklist §B, §5 |
| Play Data safety | owner, Play Console | [../DATA_SAFETY_INVENTORY.md](../DATA_SAFETY_INVENTORY.md) |

## 7. Cihaz doğrulama durumu

**M8.9-01.1 (A36, TR):** `NOT_REQUIRED` → `ADS_ALLOWED` → SDK init sırası;
rıza çözülmeden reklam istenmedi; Ayarlar'da gizlilik satırı gizli; ödül →
kapanış sinyal sırası; banner yuvası. **M8.10.1:** onboarding'e kadar UMP 0
satır, kabukta tek güncelleme.

**M9-01 (masaüstü, deterministik):** `canRequestAds` kapısı, hata + önceki
rıza, hata + rıza yok, form sonrası karar, istek öncesi yeniden sorgu (kayma),
her karede sorulmama, gizlilik seçenekleri resmî durum/form/ret/yeniden
izin/form hatası, ABD eyalet mesajı, yamasız geri düşüş, debug coğrafyası üç
kilidi, AAR bytecode'unda yeni çağrılar (`monetization_test`,
`release_config_test`).

**M9-01.1 (2026-09-23) — EK KANIT, emülatör (Pixel_8 AVD, Android 16 / API 36,
Google Play servisleri):** yamalı AAR yüklendi (`api=true`), üç yeni JNI çağrısı
çalıştı, `showPrivacyOptionsForm` gerekli değilken tek callback verdi (`code=3
"Privacy options form is not required."`); #120 düzeldi (`Setting debug geography
to: 4` / `… to: 1`, `Invalid debug_geography` 0); NOT_EEA → NOT_REQUIRED,
`canRequestAds` true, test banner/ödüllü/geçiş hazır; EEA → Google'ın örnek GDPR
formu göründü, form açıkken `canRequestAds` false + SDK başlatılmadı + 0 reklam
yüklemesi, "Consent" → OBTAINED / true / privacy REQUIRED, ardından `initialize()`
ve her yükleme öncesi yeniden `canRequestAds()`; Ayarlar'da "Gizlilik seçenekleri"
satırı yalnız REQUIRED iken, "Gizlilik politikası" satırı yok (URL yok); Aç →
yerel `show_privacy_options_form()` → Google'ın formu → "Do not consent" → callback
tam bir kez, SDK OBTAINED + `canRequestAds` true (TCF seçimi var → sınırlı reklam) →
izin SDK'yı izledi; onboarding ertelemesi aynen (tutorial ve Level 1 round'u
boyunca 0 rıza çağrısı, banner sıçraması yok, kabukta tek çağrı). Logcat: 0
SCRIPT ERROR / JNI / ClassCast / IllegalArgument / NoSuchMethod / FATAL / ANR.
Not: Vulkan'lı üretim biçimli QA build'i x86_64 emülatörde (ARM çevirisiyle)
ekrana çizemediği için emülatöre ÖZEL GL Compatibility varyantı kullanıldı —
çalışma zamanı kodu aynı. Ayrıntı: `build/qa_m9-01.1/DEVICE_GATE_NOTES.md`.

O oturumda Samsung A36 adb'de hiç görünmedi; owner kuralı gereği emülatör gerçek
cihaz kanıtının YERİNE geçmedi (kapı BLOCKED kaydedildi). Yukarıdaki emülatör
kanıtı ek tarihçe olarak duruyor.

**M9-01.1 — GERÇEK CİHAZ, Samsung A36 (2026-09-23): GEÇTİ, runtime değişmedi.**
SM-A366B / Android 16 (SDK 36, BP4A…CCZH1) / 1080×2340 / yoğunluk 450. `368c60d`
çalışma zamanıyla ayrı QA paketi (`…squishymerge.qa`, yalnız Google test kimlikleri,
`is_real=false`); her coğrafya yolu YENİ süreçte, Mobile Ads SDK hiç başlatılmamışken
(`pm clear` = UMP sıfırlama + QA açılış seçeneği `qa_boot.txt`); bütün dokunuşlar
gerçek. Bulgular:
- **Yamalı AAR:** `api=true`, yönetici resmî yolda; `canRequestAds`,
  `getPrivacyOptionsRequirementStatus`, `showPrivacyOptionsForm` A36'da çalıştı
  (TR, gerekli değilken tek callback `code=3 "Privacy options form is not required."`);
  JNI / Variant / ClassCast / NoSuchMethod hatası 0.
- **#120:** `update_consent_info(… debug_geography=4 …)` → Java `Setting debug geography
  to: 4` (NOT_EEA → OTHER) ve `… to: 1` (EEA); `Invalid debug_geography` 0. Test modunda
  Java cihazın kendi hash'ini test cihazı olarak ekliyor — gerçek telefonda da çalışıyor.
- **NOT_EEA:** NOT_REQUIRED, `canRequestAds` true, gizlilik NOT_REQUIRED → SDK init → test
  banner / ödüllü / geçiş hazır. Ayarlar'da "Gizlilik seçenekleri" ve "Gizlilik politikası"
  satırı YOK.
- **EEA:** Google'ın örnek GDPR formu gerçek A36'da; form açıkken `canRequestAds` false,
  SDK başlatılmadı, eklentide `initialize()` 0 ve `load_*` 0 (GMA `Ads` satırı 0).
  "Consent" → OBTAINED / `canRequestAds` true / gizlilik REQUIRED → ANCAK ondan sonra
  `initialize()`, her yükleme öncesi `can_request_ads(): true`.
- **Gizlilik seçenekleri (gerçek UI):** Ayarlar → "Gizlilik seçenekleri — Aç" (URL boş →
  "Gizlilik politikası" satırı yok) → yerel `show_privacy_options_form()` (consent form
  yolu değil) → Google formu → "Do not consent" → callback TAM BİR KEZ (`code=0`) → SDK:
  OBTAINED + `canRequestAds` true + REQUIRED → yönetici SDK'yı izledi (sınırlı reklam).
  İlk EEA formunda "Do not consent" da aynı sonucu verdi (`CONSENT_SIGNAL_SUFFICIENT`).
- **Onboarding ertelemesi (soğuk açılış, yeni oyuncu + EEA):** tutorial boyunca ve
  tutorial'dan doğan Level 1 round'unda (gerçek T1+T1 → T2, sonra dört drop, level
  kazanıldı) `update_consent_info` 0, form yok, banner yuvası 0, kap geometrisi aynı;
  arka plan/öne dönüş güvenli. İlk güvenli kabukta (Harita) TAM BİR rıza başlatması →
  EEA formu → Consent → banner Harita'da. Sonra 4 kabuk geçişi + arka plan/öne dönüş:
  ikinci başlatma yok, tek AdView, düğüm 2992 → 2992, orphan 0.
- **Logcat** (yalnız QA süreçleri, 6 süreç, 18 360 satır): SCRIPT ERROR / E-godot /
  AndroidRuntime / FATAL / ANR / ClassCast / IllegalArgument / NoSuchMethod / JNI /
  pencere sızıntısı / `Invalid debug_geography` → 0. PSS 365–506 MB, büyüme yok.
Owner'ın üretim paketine ve kaydına dokunulmadı (paket meta verisi önce/sonra aynı), QA
paketi kaldırıldı. Ayrıntı: `build/qa_m9-01.1/A36_DEVICE_GATE.md` (yerel).

**TASK/040 (2026-09-25) — UMP 4.0.0 ile SPIKE (üretim değil), Samsung A36: GEÇTİ.**
GMA 25.3.0 bağımlılığı UMP'yi 3.2.0'dan **4.0.0**'a taşıyor. Kullandığımız UMP
sınıflarının public API'si 3.2.0 → 4.0.0 arasında yalnız ekleme aldı
(`setConsentSyncId`); `DebugGeography` değerleri aynı; UMP minSdk 21 → 23 (proje 24).
Yamalı sarmalayıcı (canRequestAds / getPrivacyOptionsRequirementStatus /
showPrivacyOptionsForm / #120) yeniden derlemeden sonra A36'da aynı sözleşmeyi verdi:
EEA formu → Consent → OBTAINED; form öncesi `canRequestAds` false, başlatma ve yükleme
0; gizlilik seçenekleri formu gerçek dokunuşla → Do not consent → geri çağrı tam bir kez,
sınırlı reklam; NOT_EEA → NOT_REQUIRED; `update_consent_info` tek sefer. Üretim hâlâ
UMP 3.2.0. *(Sonra: TASK/042 — üretim UMP 4.0.0; spike araçları emekliye ayrıldı; aşağıda.)*
Ayrıntı [GLOBAL_TEEN_AD_TREATMENT.md](GLOBAL_TEEN_AD_TREATMENT.md) §C5.

**TASK/042 (2026-09-27) — ÜRETİM yığını GMA 25.3.0 / UMP 4.0.0, Samsung A36: GEÇTİ.**
SM-A366B / Android 16; yalnız QA paketi (`…squishymerge.qa`, kapıdan sonra kaldırıldı),
yalnız Google test kimlikleri, reklama tıklanmadı; üretim paketi hiç kurulmadı, owner'ın
eski `com.example` paketine ve kaydına dokunulmadı. QA APK `83b86a9`'dan (`eb764436…`);
statik kontrol GEÇTİ: dex'te `play-services-ads@@25.3.0`, `play-services-ads-api@@25.3.0`,
`user-messaging-platform@@4.0.0` (her biri tam bir; 24.x ve UMP 3.x YOK), spike dizgesi /
ham reklam kimliği log biçimi / Play Age Signals YOK. Bulgular (her coğrafya YENİ süreçte):
- **EEA (`pm clear`, debug coğrafyası EEA):** form; rıza öncesi `can_request_ads=false`,
  CONSENT_FORM, SDK yapılandırılmamış, `set_request_configuration()` 0, `initialize()` 0,
  yükleme 0. "Consent" → OBTAINED / `can_request_ads=true` → ANCAK ondan sonra `applied …
  age_restricted_treatment=UNSPECIFIED … sdk_initialized=false` (13:53:20.958) →
  `initialize()` + `initialize(): request configuration before MobileAds.initialize …
  UNSPECIFIED` (20.959) → yüklemeler (22.664). Geri okuma G / -1 / -1 / UNSPECIFIED, SDK
  25.3.0; süreç boyunca `set_request_configuration()` 1, `initialize()` 1. Sıra: rıza
  güncellemesi → form → `canRequestAds` → yapılandırma + doğrulama → başlatma → yükleme.
- **NOT_EEA:** debug coğrafyası 4 (OTHER), NOT_REQUIRED, rıza formu çağrısı 0, gizlilik
  NOT_REQUIRED, Ayarlar'da "Gizlilik seçenekleri" satırı gizli; UNSPECIFIED uygulandı →
  başlatma öncesi satır → yüklemeler.
- **Gizlilik seçenekleri (gerçek UI):** Ayarlar satırı (REQUIRED) → gerçek dokunuş →
  `show_privacy_options_form()` → Google formu → "Do not consent" →
  `privacy_options_form_dismissed` TAM BİR KEZ (`code=0`); `can_request_ads` true (sınırlı
  reklam).
- **Yaşam döngüsü:** arka plan → öne dönüş aynı süreç, `initialize()` 1 (ikinci başlatma
  yok).
- **QA'ya özel TEEN teşhisi** (üretim yolu değil): TEEN de aynı sırayla — rıza sonrası,
  `MobileAds.initialize()` öncesi — uygulanıp geri okundu; sonraki değişiklik reddedildi
  (kilit). SDK önce yapılandırılmışsa TEEN reddedildi, UNSPECIFIED kaldı. Üretimde yaş
  bandı yönlendirmesi YOK (TASK/043, başlamadı).
- **Logcat:** varsayılan yol temiz — SCRIPT ERROR / FATAL / ANR / ClassCast / JNI /
  NoSuchMethod / ikinci başlatma / geri okuma uyuşmazlığı / ham kimlik 0. Eklenti reklam
  kimliğini ve test kimliği listesini artık loglamıyor (§3); `g.sh dump` eski biçimli
  satırları yine redakte ediyor (derinlemesine savunma).
Ayrıntı: `build/qa_042/A36_DEVICE_GATE.md` (yerel), [ADS_SYSTEM.md](ADS_SYSTEM.md).

## 8. EEA / NOT_EEA cihaz kapısı planı (M9-01.1'de A36'da UYGULANDI — GEÇTİ; TASK/042'de UMP 4.0.0 ile yeniden — GEÇTİ, §7)

Telefonun gerçek coğrafyası DEĞİŞMEZ: DEBUG build'de UMP debug coğrafyası +
test cihazı (eklenti cihazın hash'ini otomatik ekler; emülatörde de çalışır).
Sürücü: `tools/ads_device.tscn` (ayrı QA paketi, `…squishymerge.qa`, owner
kaydına dokunmaz) — durum satırı `ump: api=… can_request_ads=…
privacy_status=…`, `ads: state=… privacy_required=…`.

| adım | komut | beklenen |
|---|---|---|
| 1 | `reset_consent` → `remake real eea` | Google örnek uygulamasının GDPR formu açılır; `ads: state=CONSENT_FORM` |
| 2 | formda "Kabul" | `consent_form_dismissed` → `can_request_ads=true` → `ADS_ALLOWED`, SDK init, test banner/ödüllü |
| 3 | `reset_consent` → `remake real eea` → formda "Reddet"/"Yönet" | `can_request_ads` UMP'nin verdiği değer; reklam kararı ona göre (sınırlı reklam) |
| 4 | Ayarlar | `privacy_status=REQUIRED` → "Gizlilik seçenekleri" satırı GÖRÜNÜR |
| 5 | satır → Aç (gerçek dokunuş) ya da `privacy` | gizlilik seçenekleri formu açılır; kapanınca `can_request_ads` yeniden okunur |
| 6 | `reset_consent` → `remake real not_eea` | form YOK, `NOT_REQUIRED`, `privacy_status=NOT_REQUIRED`, satır GİZLİ, reklam izinli |
| 7 | `remake real` (coğrafya yok, TR) | M8.9 davranışı aynen |
| 8 | üretim biçimli TEST-reklam APK'sı | yamalı AAR yüklü (`api=true`), logcat'te `Invalid debug_geography` YOK |

Kısıt: yalnız Google test kimlikleri; canlı reklama tıklama yok; owner'ın
günlük telefonunda güvenlik kontrolleri (A36 kapı kuralları) ve kayıt yedeği.
