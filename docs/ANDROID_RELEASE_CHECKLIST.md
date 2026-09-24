# ANDROID_RELEASE_CHECKLIST.md — Google Play KAPALI TEST öncesi (M9-01)

> **Durum (2026-09-22): Play'e yüklenebilir AAB YOK — kapalı teste HAZIR
> DEĞİL.** Kodda yapılabilecek her şey M9-01'de kapandı (✅); release kapısı
> (`tools/release/release_android.sh check`) bugün **BLOCKED**: 11 engel,
> hepsi owner / hesap kararı (§1). Play Console'a hiçbir şey yüklenmedi,
> hiçbir form doldurulmadı. **M9-01.1 (2026-09-23):** yamalı UMP eklentisinin
> EEA / NOT_EEA / gizlilik seçenekleri cihaz kapısı gerçek Samsung A36'da
> **GEÇTİ** (runtime değişmedi; #19, §5) — kapı çıktısı aynı: CODE 0, 11 OWNER/CONFIG.
> **Main (2026-09-24):** M9-01 + M9-01.1 main'e ff-only alındı (A36 doğrulanmış
> ağaç `2fd8a72`); kapı entegre main'de yeniden koşuldu — aynı çıktı (CODE 0 ·
> OWNER 10 · CONFIG 1), `aab` reddedildi, AAB üretilmedi. Kalan her madde owner /
> hesap / yapılandırma kararı.
> **Paket kimliği KİLİTLENDİ (owner kararı, 2026-09-24):** üretim / Play =
> `com.obappstudio.squishymerge`; QA / test = `com.obappstudio.squishymerge.qa`
> (#1). Kapı artık **CODE 0 · OWNER 9 · CONFIG 0** (§1) — paket satırları kapandı.
>
> Kategoriler: ✅ **CODE COMPLETE** · 🟠 **OWNER ACTION** · 🟣 **PLAY CONSOLE
> ACTION** · 🔵 **EXTERNAL ACCOUNT ACTION**. Kaynak: Google resmî sayfaları
> (2026-09-22); doğrulanamayan her şey **UNVERIFIED** işaretli.

## 1. Bugünkü release kapısı çıktısı

2026-09-24, paket kimliği kararından sonra (`tools/release/release_android.sh check`):

```
== release_check 'Android Release AAB': BLOCKED ==
  [OWNER]  AdMob: release build ama [General] is_real=false (üretim kimlikleri onaylanmadı)
  [OWNER]  AdMob: [Release] app_id / rewarded_id / banner_id / interstitial_id boş (4)
  [OWNER]  kitle kararı yok (android_export.cfg [Audience] decision — AUDIENCE_DECISION.md)
  [OWNER]  gizlilik politikası URL'i yok (project.godot squishy/privacy/policy_url)
  [OWNER]  upload anahtar deposu verilmedi / takma adı-şifresi verilmedi (2)
  bilgi: paket='com.obappstudio.squishymerge' versionCode=1 versionName='0.8.5' format=AAB arm64=true targetSdk=36
```

Önceki çıktıdaki iki paket satırı (`[OWNER]` kimlik seçilmedi · `[CONFIG]` preset
`com.example.squishymerge`) karar + preset güncellemesiyle kapandı.

`tools/release/release_android.sh aab` bu durumda export'u ÇALIŞTIRMADAN
reddeder (çıkış 2). Pipeline dışından yapılan bir Godot release export'unu da
`addons/squishy_release` Gradle aşamasında bilerek düşürür (doğrulandı: 21 sn,
AAB yok).

## 2. Madde madde

| # | madde | kat. | durum |
|---|---|---|---|
| 1 | **Kalıcı paket kimliği** (applicationId) | ✅ | **KARAR (owner, 2026-09-24): `com.obappstudio.squishymerge`** → project.godot `squishy/release/android_package_id` + yerel release presetlerinin ("Android Release AAB", "Android AAB NOT FOR UPLOAD") `package/unique_name`'i (kapı ikisinin eşit olmasını ister; preset her makinede ayrı güncellenir, eşit değilse CONFIG engeli). **QA / test = `com.obappstudio.squishymerge.qa`**: debug TEST-reklam preset'i ("Android") + cihaz harness paketleri — üretimle çakışmaz; kapı `.qa` kimliğini release'te reddeder, üretim kimliğiyle debug export'u raporda UYARI verir. Play'de paket adı **kalıcıdır**, ilk yüklemeden sonra değişmez, silinse de yeniden kullanılamaz. Eski geçici `com.example.squishymerge` kaldırıldı (`com.example.*` Play'de reddedilir — resmî belgede açık ifade **UNVERIFIED**). |
| 2 | **Play App Signing + upload anahtarı** | 🟠🟣 | Yeni uygulamalar için Play App Signing zorunlu (Google uygulama imza anahtarını üretir/saklar). Owner bir **upload anahtarı** oluşturur (§4) — Claude oluşturmadı. Şifre asla dosyaya/commit'e yazılmaz; export anında yalnız ortam değişkeni. |
| 3 | **Hedef API** | ✅ | targetSdk **36** (Godot 4.6.3 şablonu; Play şartı 2026-08-31'den beri 36), minSdk 24, compileSdk 36. Kapı <36'yı reddeder. |
| 4 | **AAB** | ✅ | Release = yalnız AAB (kapı APK'yı reddeder). Release biçimli AAB hattı doğrulandı: `NOT_FOR_UPLOAD_squishy_merge_0.8.5_vc1_unsigned.aab` — 47,7 MB, İMZASIZ (META-INF yok), arm64-v8a, versionCode 1 / 0.8.5, `debuggable` yok, `allowBackup=false`, oyun dosyaları install-time asset pack'te (741), sızıntı 0, yamalı eklenti dex'te, Google test yapılandırması (release'te reklam fail-closed KAPALI). **Play'e yüklenemez.** **2026-09-24 paket kararından sonra yeniden üretildi:** manifest paketi `com.obappstudio.squishymerge`, 47,7 MB, arm64, 741 oyun dosyası, yamalı eklenti dex'te, tarama 0 uyarı / 0 hata; aynı gün TEST-reklam debug APK'sının paketi `com.obappstudio.squishymerge.qa` (kanıt `build/qa_m9-package-id/`, yerel). |
| 5 | **Uygulama adı** | ✅🟠 | Cihazda "Squishy Merge" (project `config/name`). Mağaza adı (≤30 karakter) owner'ın Play girişinde. |
| 6 | **Sürüm kodu / adı** | ✅🟠 | Tek kaynak: versionName = project.godot `application/config/version` (**0.8.5**; presetlerde `version/name` BOŞ kalmalı), versionCode = project.godot `squishy/release/android_version_code` (**1**). Kapı presetle eşitliği ister. Her Play yüklemesinde owner versionCode'u +1 artırır (azalamaz). Debug ayrımı: paket `com.obappstudio.squishymerge.qa` (QA / test), `debuggable=true`, dosya adı `_testads_debug.apk`, Google test reklamlarının kendi "Test Ad" etiketi, kapı raporu DEBUG. |
| 7 | **İkon / adaptive icon** | ✅🟠 | `launcher_main_192` (192²) + adaptive ön/arka plan (432²) üç presette bağlı, manifest ikonu doğrulandı. Eksik: Play mağaza ikonu **512×512 PNG** (owner varlığı). Opsiyonel: Android 13 tek renk (monochrome) ikon. `config/icon` hâlâ `icon.svg` — yalnız masaüstü/editör; Android'i etkilemez. |
| 8 | **Feature graphic / ekran görüntüleri** | 🟠 | Feature graphic **1024×500** ve en az 2 telefon ekran görüntüsü YOK. `tools/*_shots` araçları kare üretir; mağaza seçimi owner'ın. |
| 9 | **Gizlilik politikası URL'i** | 🟠🟣 | Play: HER uygulama için zorunlu, hem Play Console alanında hem **uygulama içinde** (bağlantı ya da metin). Sayfa herkese açık, PDF değil, bölgeye kapalı değil; geliştiriciyi adlandırmalı, erişilen/toplanan/paylaşılan veriyi (AdMob dahil), saklama ve silmeyi anlatmalı. Kod hazır: Ayarlar → "Gizlilik politikası" satırı URL verilince görünür (§5 PRIVACY_CONSENT). Owner metni yazar, **barındırır**, `squishy/privacy/policy_url`'e `https://` adresini koyar. Claude URL uydurmadı/barındırmadı. |
| 10 | **Data safety** | 🟣 | Girdiler: [DATA_SAFETY_INVENTORY.md](DATA_SAFETY_INVENTORY.md) (cevap değil). Oyun verisi yalnız cihazda; Google Mobile Ads SDK üçüncü taraf verisi beyan edilmeli. |
| 11 | **Reklam beyanı ("Contains ads")** | 🟣 | **Evet** (banner, ödüllü, geçiş). Yanlış beyan askıya alma sebebi. |
| 12 | **Reklam kimliği (AD_ID) beyanı** | 🟣 | Uygulama reklam kimliğini kullanıyor (GMA `AD_ID` izni). Konsol formunun ayrıntısı **UNVERIFIED**. Yalnız-çocuk kitlesi seçilirse izin çıkarılmalı (AUDIENCE_DECISION). |
| 13 | **Hedef kitle ve içerik** | 🟠🟣 | **Owner kararı bekliyor** — [monetization/AUDIENCE_DECISION.md](monetization/AUDIENCE_DECISION.md). Kod bugün TFCD/TFUA göndermiyor, derece G. |
| 14 | **İçerik derecelendirme (IARC)** | 🟣 | Her yeni uygulama için zorunlu anket; reklamlar derecelendirmeye uygun olmalı (AdMob en yüksek derece G). |
| 15 | **Uygulama erişimi (App access)** | 🟣 | Giriş/hesap yok, özel erişim gerektiren içerik yok → "tüm işlevler özel erişim olmadan kullanılabilir" beyanı (owner doğrular). |
| 16 | **Mağaza girişi** | 🟠🟣 | Kısa açıklama (≤80), tam açıklama (≤4000), kategori (ör. Oyun → Bulmaca; owner seçer), iletişim e-postası, grafikler (#7, #8). Dil(ler) owner'ın. |
| 17 | **Kapalı test kanalı + test kullanıcıları** | 🟣🔵 | Şart KOŞULLU: **13 Kasım 2023'ten sonra açılmış kişisel (personal) Play geliştirici hesapları** üretime erişimden önce en az 12 test kullanıcısının 14 gün kesintisiz katıldığı bir kapalı test yapmalı (erken ayrılan sayılmaz), sonra üretim erişimi başvurusu. Hesabın türü ve gerçek durumu **Play Console'da kontrol edilmeli** — kuruluş (organization) hesabı ya da daha eski hesap için şart farklı olabilir. |
| 18 | **Gerçek AdMob kimlikleri** | 🟠🔵 | AdMob'da uygulama + 3 reklam birimi (ödüllü, uyarlanabilir banner, geçiş) → `android_export.cfg [Release]` dört kimlik + `is_real=true`. Kapı biçim/yayıncı/tekrar/Google-örneği kontrollerini yapar. |
| 19 | **UMP / rıza (EEA)** | ✅🔵 | Kod: resmî `canRequestAds` + gizlilik seçenekleri (yamalı eklenti). Owner: AdMob Privacy & messaging'de **GDPR mesajı** (EEA/UK/CH'de kişiselleştirilmiş reklam için sertifikalı CMP gerekli; yoksa sınırlı reklam), isteğe bağlı ABD eyalet mesajı. EEA / NOT_EEA / gizlilik seçenekleri akışı önce emülatörde (ek kanıt), sonra **gerçek Samsung A36'da doğrulandı — GEÇTİ** (M9-01.1, 2026-09-23: yamalı AAR, #120, form öncesi 0 reklam isteği, gizlilik seçenekleri tek callback, onboarding ertelemesi; logcat temiz — PRIVACY_CONSENT §7). |
| 20 | **Mimari** | ✅🟠 | Yalnız **arm64-v8a** (Play 64-bit şartı karşılanır). `armeabi-v7a` eklemek (eski 32-bit telefonlar) owner kararı; AAB bölünmüş teslimatla 64-bit indirmeyi büyütmez ama test yükü getirir. |
| 21 | **İzinler** | ✅ | VIBRATE (oyun), INTERNET, ACCESS_NETWORK_STATE, AD_ID ×2, ACCESS_ADSERVICES_AD_ID/ATTRIBUTION/TOPICS, WAKE_LOCK, FOREGROUND_SERVICE, `…DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` — hepsi GMA/eklenti/androidx kaynaklı (debug APK + AAB `aapt2` ile aynı liste). Tehlikeli (runtime) izin yok. |
| 22 | **Android geliştirici doğrulaması / paket kaydı** | 🔵 | **Düzeltildi (M9-01.1):** 30 Eylül 2026, herkese uygulanan bir son tarih DEĞİL; **ilk bölgesel uygulama dalgası** — Brezilya, Endonezya, Singapur ve Tayland'da, katılımcı mağazalardan (Google Play dahil) kurulan uygulamalar için, Android 7+ sertifikalı cihazlarda. **2027'de** tüm sertifikalı cihazlara genişliyor. Google Play uygulamaların ~%99'unu **otomatik kaydediyor**; kalanlar Play Console'dan elle kaydediliyor (developer.android.com/developer-verification). Yayımlanmamış bu uygulama için bugün ayrı bir işlem yok: hesap açılıp uygulama oluşturulunca owner kayıt durumunu Play Console'da kontrol eder. |
| 23 | **Google Play Developer hesabı** | 🔵 | Açılmadı / kimlik doğrulaması bekliyor (PROJECT_CONTEXT). Diğer bütün Play maddelerinin önkoşulu. |
| 24 | **AdMob hesabı / ödeme profili / app-ads.txt** | 🔵 | AdMob hesabı + ödeme profili owner'da. app-ads.txt (geliştirici web sitesinde) AdMob'un önerdiği doğrulama — web sitesi gizlilik politikasıyla aynı yer olabilir (zorunluluk ayrıntısı **UNVERIFIED**). |
| 25 | **SDK sürümü (teknik borç)** | 🟠 | Bugün **GMA 24.9.0 legacy** (destek **2027-06-30**'a kadar). TFCD/TFUA'nın yerine geçen **TFAT** (`setAgeRestrictedTreatment`) legacy **25.3.0+**'da; Google'ın bugün tercih ettiği Android SDK'sı **GMA Next-Gen**. Data safety beyanı yalnız en yeni sürümü (25.5.0) anlatıyor. Kapalı test için kendiliğinden engel DEĞİL; eklenti güncellemesine bağlı ayrı bir modernizasyon milestone'u (AUDIENCE_DECISION §2.1). M9-01.1'de geçiş yapılmadı. |

## 3. Owner girdileri gelince: yüklenebilir AAB

1. project.godot `[squishy]`: ~~`release/android_package_id`~~ ✅
   `com.obappstudio.squishymerge` (2026-09-24); `privacy/policy_url="https://…"`;
   gerekirse `release/android_version_code`.
2. Yerel `export_presets.cfg` (her makinede): "Android Release AAB" + "Android AAB
   NOT FOR UPLOAD" `package/unique_name` = `com.obappstudio.squishymerge`, "Android"
   (debug TEST-reklam) = `com.obappstudio.squishymerge.qa` — iş makinesinde yapıldı
   (2026-09-24); versionCode aynı sayı; `version/name` BOŞ.
3. `addons/AdmobPlugin/android_export.cfg`: `[Release]` dört kimlik,
   `[General] is_real=true`, `[Audience]` kararı (AUDIENCE_DECISION §5).
4. Upload anahtarı ortam değişkenleri (yalnız o kabuk oturumu; dosyaya yazma):
   `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`,
   `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`.
5. `tools/release/release_android.sh check` → **UPLOAD_CANDIDATE** görülmeli.
6. `tools/release/release_android.sh aab` → `build/release/squishy_merge_<ver>_vc<code>_release.aab`
   + `.scan.json` (sızıntı, manifest, paketlenen yapılandırma).
7. Önce Play **dahili test**, sonra kapalı test (13 Kasım 2023 sonrası açılmış
   kişisel hesapta ≥12 kişi / 14 gün — hesabın durumu Play Console'da).

Debug TEST-reklam APK her zaman: `tools/release/release_android.sh debug-apk`
(yalnız Google test kimlikleri; debug build canlı birim isteyemez).

## 4. Upload anahtarı — owner adımı (Claude OLUŞTURMADI)

Google'ın şartı: RSA, 2048 bit ya da daha büyük (örnekte 4096), Java keystore,
geçerlilik en az 25 yıl (Play: 2033-10-22 sonrasına geçerli olmalı). Android
Studio'nun "Generate Signed Bundle" sihirbazı ya da JDK `keytool`
(`C:\Program Files\Microsoft\jdk-17.0.16.8-hotspot\bin\keytool.exe` bu
makinede var). Örnek (şifreleri `keytool` KENDİSİ sorar; komut satırına
yazma):

```bash
keytool -genkeypair -v -keystore "<repo DIŞINDA güvenli bir yol>/squishy-merge-upload.jks" -alias <seçtiğin-takma-ad> -keyalg RSA -keysize 4096 -validity 10000
```

- Dosyayı ve şifreyi parola yöneticisinde + çevrimdışı yedekte tut; repoya
  koyma (`*.jks`, `*.keystore` zaten gitignore'lu).
- Kaybedilirse: yeni anahtar üret → PEM'e aktar → Play Console "upload key
  reset" (uygulama imza anahtarı etkilenmez).
- Bu makinede BAŞKA bir uygulamaya ait bir upload anahtarı var
  (`%USERPROFILE%\Bismillah-Signing\upload-keystore.jks`) — M9-01'de
  AÇILMADI, KULLANILMADI. Squishy Merge için ayrı anahtar önerilir (karar
  owner'ın).

## 5. Kapalı testten önce önerilen cihaz kapıları (owner onayıyla)

1. ~~**EEA / NOT_EEA rıza + gizlilik seçenekleri** — yamalı AAR'ın ilk cihaz
   doğrulaması (PRIVACY_CONSENT §8; debug build, telefonun coğrafyası
   değişmez).~~ ✅ **M9-01.1'de Samsung A36'da GEÇTİ** (2026-09-23, PRIVACY_CONSENT §7).
2. **Release adayı duman testi** — imzalı AAB Play dahili test kanalından
   yüklenip açılış/tutorial/reklam (gerçek kimliklerle canlı reklam: yalnız
   izleme, TIKLAMA YOK; ya da AdMob test cihazı kaydı).

## 6. Kod tarafında kapananlar (M9-01) — referans

- Eklenti UMP yaması + deterministik yeniden derleme (`tools/admob_plugin/`).
- `canRequestAds` kapısı + gizlilik seçenekleri resmî yolu (PRIVACY_CONSENT §2–§4).
- Build türüne göre kimlik seçimi + release fail-closed doğrulayıcısı (ADS_SYSTEM §8).
- Debug coğrafyası yalnız debug build; EEA / NOT_EEA QA kancaları.
- `[Audience]` dikişi (karar bekliyor), gizlilik politikası satırı dikişi.
- Tek sürüm kaynağı, release kapısı (üç giriş noktası), pipeline, çıktı taraması.
- Testler: `release_config_test` 106, `monetization_test` 248; tam regresyon yeşil.
