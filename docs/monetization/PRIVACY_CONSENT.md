# PRIVACY_CONSENT.md — UMP rıza akışı ve gizlilik (M8.9-01 → M9-01)

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
> gizlilik seçenekleri resmî durum + resmî form. **Cihazda doğrulanmadı** —
> M9-01'de telefon/ADB yok; EEA / NOT_EEA cihaz kapısı planı §8.

## 1. İlke

- **SDK durumu tek gerçek.** Kendi GDPR/rıza önbelleğimiz yok; kayıt
  dosyasına rıza yazılmaz. Google'ın uyarısı aynen uygulanır: rıza durumunu
  uygulamanın önbelleğinden ya da saklanan rıza dizgesinden okuma.
- Her uygulama açılışında (onboarding bittikten sonra, M8.10)
  `requestConsentInfoUpdate` (eklenti: `update_consent_info`). Form
  gerekiyorsa SDK'nın formu gösterilir; ardından **karar UMP
  `canRequestAds()`'indir** (M9-01). Mobile Ads SDK ancak `canRequestAds()`
  true iken başlatılır ve **her reklam yüklemesinden hemen önce yeniden
  sorulur** (`MonetizationManager._request_permitted`).
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

## 4. Eklenti: resmî UMP çağrıları (M9-01) ve geri düşüş

`addons/AdmobPlugin` = upstream v6.0 + `tools/admob_plugin/0001-…patch`
(deterministik yeniden derleme ve doğrulama: `tools/admob_plugin/README.md`,
`addons/AdmobPlugin/VERSION.md`). Upstream'de (v6.0, v7.0, `main`; 2026-09-22)
bu üç çağrı YOK; #120 yalnız v7.0'da (Godot 4.7 hedefli) düzeltilmiş.

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
AAR'la yüklenebilir AAB üretmez (AAR SHA-256 kontrolü).

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
| Kitle / COPPA / TFCD / TFUA / içerik derecesi | **KARAR BEKLİYOR** | [AUDIENCE_DECISION.md](AUDIENCE_DECISION.md) |
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

**Cihazda HENÜZ doğrulanmadı (M9-01'de telefon/ADB yok):** gerçek EEA formu,
gerçek `canRequestAds()` değerleri, gerçek gizlilik seçenekleri formu, yamalı
AAR'ın cihazda yüklenmesi. Plan §8.

## 8. EEA / NOT_EEA cihaz kapısı planı (owner onayıyla, sonraki adım)

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
