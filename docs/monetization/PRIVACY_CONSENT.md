# PRIVACY_CONSENT.md — UMP rıza akışı ve gizlilik (M8.9-01)

> Kanonik doküman. Reklam mimarisi: [ADS_SYSTEM.md](ADS_SYSTEM.md).
> Kaynaklar (2026-09-21'de okundu): developers.google.com/admob/android/privacy,
> …/privacy/api/reference/…/ConsentInformation, …/quick-start, …/test-ads,
> …/deprecation; eklenti kaynağı `godot-admob` v6.0 (`AdmobPlugin.java`).

## 1. İlke

- **SDK durumu tek gerçek.** Kendi GDPR/rıza önbelleğimiz yok; kayıt
  dosyasına rıza yazılmaz. Google'ın uyarısı aynen uygulanır: "We don't
  recommend that you check consent status in another way, such as the cache
  in your app or a previously saved consent string."
- Her uygulama açılışında `requestConsentInfoUpdate` (eklenti:
  `update_consent_info`). Form gerekiyorsa SDK'nın formu gösterilir; reklam
  yalnız izinden sonra istenir; Mobile Ads SDK **rıza tamamlanmadan
  başlatılmaz** (Google: "ensure you do so before initializing").
- Sonsuz bekleme yok: oyun rızayı beklemez, pencerelerde reklam CTA'sı
  pasif + gerçek sebep ("hazırlanıyor" / "şu anda kullanılamıyor").

## 2. Uygulama durumları (`MonetizationManager.AdsState`)

| durum | anlam | reklam |
|---|---|---|
| `UNAVAILABLE` | arka uç yok (masaüstü / eklenti yok / yapılandırma geçersiz) | hayır |
| `CONSENT_CHECKING` | `update_consent_info` cevap bekliyor | hayır |
| `CONSENT_FORM` | SDK "REQUIRED" dedi, form yükleniyor/gösteriliyor | hayır |
| `ADS_ALLOWED` | `NOT_REQUIRED` ya da `OBTAINED` | evet → SDK başlatılır |
| `ADS_NOT_ALLOWED` | `REQUIRED` (form yok / hata) ya da `UNKNOWN` | hayır; sınırlı yeniden deneme |
| `ERROR_WITH_PREVIOUS_STATE` | update hatası, SDK'nın önceki oturumdan taşıdığı durum izin veriyor | evet |

`ERROR_WITH_PREVIOUS_STATE` Google'ın ConsentInformation referansına dayanır:
`getConsentStatus()` "defaults to the previous session's value until
requestConsentInfoUpdate completes successfully", ve rehber "If an error
occurs during the consent gathering process, check if you can request ads.
The UMP SDK uses the consent status from the previous app session."

Yeniden deneme: hata/izinsizlikte 30 s ve 120 s sonra birer güncelleme;
sonra yalnız pencere açılışında (devam/refill) ve en az 20 s aralıkla bir
güncelleme daha (ağ dönmüş olabilir). Spam yok.

## 3. Akış (eklenti API'siyle)

```
update_consent_info()
  ├─ consent_info_updated ──► get_consent_status()
  │      NOT_REQUIRED/OBTAINED → ADS_ALLOWED → initialize()
  │      REQUIRED + is_consent_form_available() → load_consent_form()
  │           ├─ consent_form_loaded → show_consent_form()
  │           │      └─ consent_form_dismissed(err) → durum yeniden okunur
  │           │            OBTAINED/NOT_REQUIRED → ADS_ALLOWED → initialize()
  │           │            REQUIRED (hata/kapatma) → ADS_NOT_ALLOWED (+deneme)
  │           └─ consent_form_failed_to_load → ADS_NOT_ALLOWED (+deneme)
  │      REQUIRED + form yok / UNKNOWN → ADS_NOT_ALLOWED (+deneme)
  └─ consent_info_update_failed ──► get_consent_status() (önceki oturum)
         izin veriyorsa ERROR_WITH_PREVIOUS_STATE → initialize(); değilse ADS_NOT_ALLOWED
```

Test modunda (`is_real=false`) eklenti cihazın hash'ini UMP test cihazı
olarak ekler; `android_export.cfg` → `[Debug] debug_geography` (örn. `eea`)
ile bölge zorlanması AMAÇLANDI ama **v6.0'da çalışmıyor**: Java tarafı
(`ConsentConfiguration.java`) değeri `instanceof Integer` ile kontrol ediyor,
Godot GDScript int'ini `Long` olarak geçiriyor → `Invalid debug_geography
type: Long` → coğrafya yok sayılır (A36 kapısında görüldü; upstream issue #120,
2026-06-01, açık; v7.0 kaynağında `instanceof Number` ile düzeltilmiş ama v7.0
Godot 4.7 hedefli). Sonuç: gerçek EEA cihazı olmadan rıza formu cihazda
gösterilemiyor.

## 4. Eklenti boşluğu: `canRequestAds` ve gizlilik seçenekleri

`godot-admob` v6.0 sarmalayıcısı UMP'nin üç yeni API'sini sunmuyor:
`canRequestAds()`, `getPrivacyOptionsRequirementStatus()`,
`showPrivacyOptionsForm()` (ve `loadAndShowConsentFormIfRequired()`).
Uygulanan eşdeğerler — hepsi SDK'dan türetilir, hiçbiri icat değildir:

| gereken | eşdeğer | dayanak |
|---|---|---|
| `canRequestAds()` | `update_consent_info` çağrıldıktan sonra `get_consent_status() ∈ {NOT_REQUIRED, OBTAINED}` | Referans: "Once requestConsentInfoUpdate is called, this method returns true when getConsentStatus returns NOT_REQUIRED or OBTAINED." Birebir aynı tanım. |
| `loadAndShowConsentFormIfRequired()` | `REQUIRED and is_consent_form_available()` → `load_consent_form` → `show_consent_form` | UMP'nin eski (2.0) rehberindeki açık akış; aynı SDK metotları. |
| `getPrivacyOptionsRequirementStatus() == REQUIRED` | rıza güncellemesi yapıldı **ve** `is_consent_form_available()` | GDPR/TCF mesajı yalnız düzenlenen bölgede form sunar; rıza alındıktan sonra form "değiştirmek için" kullanılabilir kalır (UMP 2.0 rehberi: OBTAINED iken formu yeniden sunma). Düzenlenmeyen bölgede form yok → satır gizli. |
| `showPrivacyOptionsForm()` | `load_consent_form` → `show_consent_form` → kapanışta durum yeniden okunur; izin kalkarsa banner gizlenir, ödüllü "hazır" sayılmaz | aynı SDK formu |

**Cihaz kapısı bulgusu (M8.9-01.1):** aynı Java dosyasındaki `debug_geography`
Long/Integer hatası (#120) yüzünden EEA formu A36'da gösterilemedi; TR
coğrafyasında NOT_REQUIRED → ADS_ALLOWED → SDK init sırası ve "Gizlilik
seçenekleri" satırının gizli kalması doğrulandı. Eklentinin
`load_consent_form` / `show_consent_form` / `consent_form_dismissed` yolu cihazda
HİÇ çalışmadı; yalnız masaüstü sahte arka uç testleriyle kapsanıyor.

**Açık nokta (unverified):** ABD eyalet düzenlemesi (CPRA vb.) mesajında
UMP `getConsentStatus()` NOT_REQUIRED döner ve gizlilik seçenekleri
yalnız `getPrivacyOptionsRequirementStatus()` ile REQUIRED olur;
`isConsentFormAvailable()`'ın bu mesaj için true dönüp dönmediği cihazda
doğrulanmadı. Bugünkü kapsam (Türkiye + AB odaklı v1) için GDPR eşdeğeri
yeterli. Kesin çözüm seçenekleri (owner/ChatGPT kararı):

1. Eklentiye üç küçük `@UsedByGodot` metot (`can_request_ads`,
   `get_privacy_options_requirement_status`, `show_privacy_options_form`) +
   #120 için `instanceof Number` düzeltmesini ekleyip AAR'ı v6.0 kaynağından
   derlemek (fork; Gradle + JDK 17 + Android SDK bu makinede var) — bilerek
   YAPILMADI (özel Android köprüsü / fork onayı gerekir). **Üretim öncesi
   önerilen yol** — hem doğru privacy-options davranışı hem de rıza formunun
   cihazda test edilebilmesi için.
2. Aynı değişiklikleri upstream'e PR olarak göndermek ve 4.6 uyumlu bir
   sürüm beklemek (v7.0 yalnız Godot 4.7).
3. Mevcut eşdeğerle devam — v1 testleri için yeterli; ÜRETİM için 1 ya da 2
   şart (Google'ın rehberi `getPrivacyOptionsRequirementStatus`'ü zorunlu
   giriş noktası kararının kaynağı sayıyor).

## 5. Ayarlar penceresi

- **Gizlilik metni** güncellendi (eski metin "reklam yok" diyordu, artık
  yanlış olurdu): hesap/sunucu/analitik yok; ilerleme cihazda; ödüllü ve
  banner reklam için Google AdMob; reklam SDK'sı reklam kimliği gibi cihaz
  verilerini Google'ın politikasına göre işleyebilir; uygulama içi satın alma
  yok. Metin `SettingsPanel.PRIVACY_TEXT` — kod ile aynı gerçeği anlatır.
- **"Gizlilik seçenekleri" satırı** (`UiKit.settings_row("lock", …)` + "Aç"
  butonu) yalnız `MonetizationManager.privacy_options_required()` true iken
  görünür; sinyalle güncellenir. Görünmüyorsa yer de tutmaz (ayırıcı dahil).
  Tasarım değişmedi (M8.6-08 kabuğu, aynı satır bileşeni).

## 6. Owner / ChatGPT politika kararları (bekliyor)

Kod tahmin ETMEDİ; eklenti/SDK varsayılanlarında bırakıldı:

| ayar | şimdi | soru |
|---|---|---|
| `setTagForChildDirectedTreatment` (COPPA, TFCD) | UNSPECIFIED | Play Console "Hedef kitle ve içerik" beyanı ne olacak? Uygulama çocuklara yönelik mi, karma mı, 13+ mi? Çocuklara yönelik/karma ise TFCD=TRUE + Families politikası (kişiselleştirilmiş reklam yok, sertifikalı ağlar); 13+ ise FALSE. Proje dokümanı "casual geniş kitle" diyor, çocuk hedefi belirtmiyor — açık karar gerek. |
| `setTagForUnderAgeOfConsent` (TFUA, AB) | UNSPECIFIED | Aynı kararın AB karşılığı. Google 25.3.0'da her ikisini tek `setAgeRestrictedTreatment()` altında topladı (eklenti 24.9.0'da eski API). |
| `max_ad_content_rating` | **G** (eklenti varsayılanı; en muhafazakâr) | Kawaii tema için uygun görünüyor; onaylanmalı. |
| Privacy & messaging | yok | AdMob konsolunda GDPR mesajı (zorunlu, AB/UK/CH) + gerekirse US state mesajı; "Gizlilik seçenekleri" davranışı buna bağlı (§4). |
| Play Data safety | yok (M10) | GMA SDK'nın veri beyanı + AD_ID izni; WAKE_LOCK/FOREGROUND_SERVICE geçişli bağımlılıklardan (ADS_SYSTEM §9). |
| Gizlilik politikası URL'i | yok (M10) | Metin AdMob kullanımını ve reklam kimliğini anmalı. |

## 7. Cihaz kapısı sonrası durum (M8.9-01.1, A36, 2026-09-21)

Doğrulandı: TR'de `NOT_REQUIRED` → `ADS_ALLOWED` → SDK init sırası; rıza
çözülmeden reklam istenmedi; Ayarlar'da gizlilik satırı gizli; gerçek SDK ile
ödül→kapanış sinyal sırası (ödül önce, reklam hâlâ üstteyken), arka plana
gidip dönüşte tek kapanış; banner nav bar üstü hizası (inset B=0, jest
gezinme) ve yuva ölçüsü (168 px ↔ 169,5 px).

Doğrulanmadı / doğrulanamaz (üretim engeli olarak açık):
- Gerçek UMP formu ve `consent_form_dismissed` sonrası durum — v6.0 #120
  (debug_geography uygulanamıyor); gerçek EEA cihazı yok.
- Uçak modunda `consent_info_update_failed` → önceki durum — owner'ın günlük
  telefonunda ağ kapatılmadı; masaüstü sahte testlerle kapsanıyor.
- `getPrivacyOptionsRequirementStatus` eşdeğerinin ABD eyalet mesajıyla
  davranışı (§4).
