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
> **Hedef kitle KARARI (owner, 2026-09-25 — FİNAL, ürün kitlesi KAPALI):** 13+
> genel kitle, 13 yaş altı için tasarlanmadı — Play hedef yaş grupları 13–15 /
> 16–17 / 18+ (#13); `[Audience] decision=general_13_plus`, reklam istekleri
> değişmedi. Genel "kitle kararı yok" satırı kapandı; yerine ürün kitlesinden
> AYRI bir OWNER / uyum satırı geldi: **13–17 genç reklam işlemi / yargı bölgesi
> uyumu AÇIK** (#26). Kapı: **CODE 0 · OWNER 9 · CONFIG 0** (§1).
> **TASK/040 (2026-09-25; `task/040-global-teen-compliance` main'e ff-only alındı
> 2026-09-27):** GMA 25.3.0 TEEN fizibilitesi Godot 4.6.3'te Samsung A36'da
> kanıtlandı (yalnız spike, üretime alınmadı — #25, #26,
> [monetization/GLOBAL_TEEN_AD_TREATMENT.md](monetization/GLOBAL_TEEN_AD_TREATMENT.md))
> *(Sonra: TASK/042 — GMA 25.3.0 üretime taşındı, spike kaldırıldı; main'de, aşağıda)*.
> Yeni bulgu: üretim eklentisi RequestConfiguration'ı hiç uygulamıyor → derece G
> etkin değil (#27). Kapı: **CODE 1 · OWNER 9 · CONFIG 0** (§1). Play Age Signals
> reklam kararında KULLANILMAZ.
> **TASK/041 (2026-09-27; `task/041-fix-request-configuration` main'e ff-only alındı
> 2026-09-27):** #27 **KAPANDI** — üretim yaması `0002` + yeni AAR'lar
> (GMA 24.9.0 / UMP 3.2.0 aynı); Samsung A36'da derece G, TFCD / TFUA ve test
> cihazları ilk reklam yüklemesinden önce uygulanıyor, M9 UMP / gizlilik / reklam
> regresyonu geçti. Kapı: **CODE 0 · OWNER 9 · CONFIG 0** (§1). 13–17 uyumu (#26) AÇIK.
> **TASK/042 (2026-09-27; `task/042-gma25-production` — `83b86a9` + `3d15402` — main'e
> ff-only alındı 2026-09-27):** üretim AdMob yığını **GMA 25.3.0** + **UMP 4.0.0**
> (play-services-ads-api 25.3.0 üzerinden geçişli) — üretim yaması `0003` + yeni AAR'lar;
> **TFAT** (`AgeRestrictedTreatment` UNSPECIFIED / CHILD / TEEN) üretim eklentisinde
> teknik olarak hazır (#25). Üretim varsayılanı **herkes için UNSPECIFIED**; istek
> yapılandırması `MobileAds.initialize()` öncesi BİR kez uygulanıp geri okunuyor,
> uyuşmazsa SDK başlamıyor (fail-closed); SDK yapılandırılınca yaş işlemi kilitli.
> Samsung A36 kapısı GEÇTİ. **Yaş bandı yönlendirmesi YOK** — owner onaylı yönlendirme
> TASK/043'te (**BAŞLAMADI**); 13–17 uyumu (#26) AÇIK. Kapı: **CODE 0 · OWNER 9 ·
> CONFIG 0** (§1).
> **TASK/043 (2026-09-27; dal `task/043-age-band-routing`, main'e alınması owner onayı
> bekliyor):** nötr doğum tarihi ekranı + **yaş bandı reklam yönlendirmesi** (owner iş
> kararı; [monetization/AGE_BAND_ROUTING.md](monetization/AGE_BAND_ROUTING.md)): 13–17 →
> TFAT TEEN + derece T, 18+ → UNSPECIFIED + MA, 13 altı / bilinmeyen → reklam SDK'sı / UMP /
> reklam yok. Kapı: genç işlemi stratejisi (#26) owner kaydı + kod tablosuyla kalkar (A36
> kapısından sonra); resmî araştırmanın bulduğu iki somut madde ayrı OWNER / UYUM satırı:
> **#28** Play "Uygunsuz reklamlar" (uygulama içerik derecesi ↔ T / MA) ve **#29** yargı
> bölgesi yaş yükümlülükleri. Kapı ayrıca release preset'inde `user_data_backup/allow=false`
> ister (CONFIG — kayıt, yaş bandı + geçiş günü dahil, otomatik yedeğe gitmez; bugün üç preset'te
> de false). **Samsung A36 kapısı GEÇTİ** (A–F, 2026-09-27) → owner stratejisi kaydedildi
> (`teen_ad_treatment = "age_band_routing"`, #26'nın strateji satırı kalktı). Kapı (dalda):
> **CODE 0 · OWNER 10 · CONFIG 0** (§1; A36 öncesi OWNER 11).
>
> Kategoriler: ✅ **CODE COMPLETE** · 🟠 **OWNER ACTION** · 🟣 **PLAY CONSOLE
> ACTION** · 🔵 **EXTERNAL ACCOUNT ACTION**. Kaynak: Google resmî sayfaları
> (2026-09-22); doğrulanamayan her şey **UNVERIFIED** işaretli.

## 1. Bugünkü release kapısı çıktısı

**TASK/043 dalı (2026-09-27, A36 kapısı GEÇTİKTEN ve owner stratejisi kaydedildikten sonra)** — `tools/release/release_android.sh check`:

```
== release_check 'Android Release AAB': BLOCKED ==
  [OWNER] AdMob: release build ama [General] is_real=false (üretim kimlikleri onaylanmadı)
  [OWNER] AdMob: [Release] app_id boş
  [OWNER] AdMob: [Release] rewarded_id boş
  [OWNER] AdMob: [Release] banner_id boş
  [OWNER] AdMob: [Release] interstitial_id boş
  [OWNER] UYUM: yargı bölgesi yaş yükümlülükleri değerlendirmesi kayda geçmedi (android_export.cfg [Audience] jurisdiction_age_review boş) — dünya geneli dağıtımda: Brezilya Digital ECA (Google Play yardım sayfası: çocuk / ergenlerin erişmesi muhtemel uygulamalar mağazadan yaş aralığı almalı + bu oyunlarda loot box yasağı), ABD eyalet uygulama mağazası yasaları (ör. Teksas SB2420), AB / BK / İsviçre dijital rıza yaşı (rıza yaşının altı: Google TFUA / CHILD), Families 'bazı yerlerde çocuk' (13–15 / 16–17); Play Age Signals reklamda ASLA kullanılmaz — AGE_BAND_ROUTING.md §9
  [OWNER] UYUM (Play Uygunsuz Reklamlar): uygulamanın Play içerik derecesi kayda geçmedi (android_export.cfg [Audience] app_content_rating boş) — yaş bandı yönlendirmesi en yüksek MA reklam derecesi gönderiyor, Play reklamların UYGULAMANIN içerik derecesine uygun olmasını istiyor (AdMob etiketi MA ↔ en az 16+); IARC sonucu kaydedilmeli, daha düşükse yönlendirme dereceleri owner kararıyla düşürülmeli — AGE_BAND_ROUTING.md §6
  [OWNER] gizlilik politikası URL'i yok (project.godot squishy/privacy/policy_url)
  [OWNER] upload anahtar deposu verilmedi (GODOT_ANDROID_KEYSTORE_RELEASE_PATH ya da preset keystore/release)
  [OWNER] upload anahtarı takma adı / şifresi verilmedi (ortam değişkeni; dosyaya YAZILMAZ)
  not: ürün kitlesi kararı: general_13_plus (TFCD=unspecified, TFUA=unspecified — eski etiketler TEEN işlemi DEĞİL; yaş işlemi ve derece yaş bandından, TASK/043) — AUDIENCE_DECISION.md §0
  not: 13–17 genç reklam işlemi stratejisi: age_band_routing (nötr yaş ekranı; 13–17 TFAT TEEN + T, 18+ UNSPECIFIED + MA, 13 altı / bilinmeyen reklamsız; Play Age Signals reklamda YOK) — hukuki garanti DEĞİL, AGE_BAND_ROUTING.md
```

CODE 0 · OWNER 10 · CONFIG 0 — 13–17 strateji satırı kalktı (not satırı: "hukuki garanti DEĞİL"); #28 ve #29 AÇIK.

A36 kapısı öncesi (commit 1 anı, kayıt) — `tools/release/release_android.sh check`:

```
== release_check 'Android Release AAB': BLOCKED ==
  [OWNER] AdMob: release build ama [General] is_real=false (üretim kimlikleri onaylanmadı)
  [OWNER] AdMob: [Release] app_id boş
  [OWNER] AdMob: [Release] rewarded_id boş
  [OWNER] AdMob: [Release] banner_id boş
  [OWNER] AdMob: [Release] interstitial_id boş
  [OWNER] UYUM: 13–17 genç reklam işlemi stratejisi kayda geçmedi — TASK/043 yaş bandı yönlendirmesi kodda (13–17 TFAT TEEN + derece T, 18+ UNSPECIFIED + MA, 13 altı / bilinmeyen reklamsız); owner stratejisi A36 kapısından sonra android_export.cfg [Audience] teen_ad_treatment = age_band_routing ile kaydedilir — AGE_BAND_ROUTING.md
  [OWNER] UYUM: yargı bölgesi yaş yükümlülükleri değerlendirmesi kayda geçmedi (android_export.cfg [Audience] jurisdiction_age_review boş) — dünya geneli dağıtımda: Brezilya Digital ECA (Google Play yardım sayfası: çocuk / ergenlerin erişmesi muhtemel uygulamalar mağazadan yaş aralığı almalı + bu oyunlarda loot box yasağı), ABD eyalet uygulama mağazası yasaları (ör. Teksas SB2420), AB / BK / İsviçre dijital rıza yaşı (rıza yaşının altı: Google TFUA / CHILD), Families 'bazı yerlerde çocuk' (13–15 / 16–17); Play Age Signals reklamda ASLA kullanılmaz — AGE_BAND_ROUTING.md §9
  [OWNER] UYUM (Play Uygunsuz Reklamlar): uygulamanın Play içerik derecesi kayda geçmedi (android_export.cfg [Audience] app_content_rating boş) — yaş bandı yönlendirmesi en yüksek MA reklam derecesi gönderiyor, Play reklamların UYGULAMANIN içerik derecesine uygun olmasını istiyor (AdMob etiketi MA ↔ en az 16+); IARC sonucu kaydedilmeli, daha düşükse yönlendirme dereceleri owner kararıyla düşürülmeli — AGE_BAND_ROUTING.md §6
  [OWNER] gizlilik politikası URL'i yok (project.godot squishy/privacy/policy_url)
  [OWNER] upload anahtar deposu verilmedi (GODOT_ANDROID_KEYSTORE_RELEASE_PATH ya da preset keystore/release)
  [OWNER] upload anahtarı takma adı / şifresi verilmedi (ortam değişkeni; dosyaya YAZILMAZ)
  not: ürün kitlesi kararı: general_13_plus (TFCD=unspecified, TFUA=unspecified — eski etiketler TEEN işlemi DEĞİL; yaş işlemi ve derece yaş bandından, TASK/043) — AUDIENCE_DECISION.md §0
```

CODE 0 (kod tablosu owner tablosuyla birebir) · OWNER 11 · CONFIG 0. Aşağıdaki blok TASK/042
anındaki çıktıdır (kayıt).

2026-09-27, GMA 25.3 üretim eklentisi kurulup A36'da doğrulandıktan ve TASK/042 main'e
alındıktan sonra main'de (`tools/release/release_android.sh check`; dalda da aynı çıktı):

```
== release_check 'Android Release AAB': BLOCKED ==
  [OWNER]  AdMob: release build ama [General] is_real=false (üretim kimlikleri onaylanmadı)
  [OWNER]  AdMob: [Release] app_id / rewarded_id / banner_id / interstitial_id boş (4)
  [OWNER]  UYUM: 13–17 genç reklam işlemi / yargı bölgesi uyum stratejisi çözülmedi (TFAT TEEN teknik olarak hazır — GMA 25.3.0, TASK/042 — ama yaş bandı yönlendirmesi yok, üretim UNSPECIFIED; unspecified ≠ TEEN) — AUDIENCE_DECISION.md §2.2
  [OWNER]  gizlilik politikası URL'i yok (project.godot squishy/privacy/policy_url)
  [OWNER]  upload anahtar deposu verilmedi / takma adı-şifresi verilmedi (2)
  not: ürün kitlesi kararı: general_13_plus (TFCD=unspecified, TFUA=unspecified, en yüksek reklam derecesi G — bunlar TEEN işlemi DEĞİL) — AUDIENCE_DECISION.md §0
  bilgi: paket='com.obappstudio.squishymerge' versionCode=1 versionName='0.8.5' format=AAB arm64=true targetSdk=36
```

TASK/040'ın `[CODE]` satırı (#27: onaylı M9 AAR'ı RequestConfiguration'ı hiç
uygulamıyordu) **TASK/041'de kalktı**: `PATCHED_RELEASE_AAR_SHA256` artık düzeltilmiş
derlemeyi (v6.0 + 0001 + 0002, `14c745e9…`) onaylıyor. Kural silinmedi — eski kusurlu
SHA (`90d35992…`) `KNOWN_PLUGIN_DEFECTS`'te duruyor ve o AAR geri gelirse satır yine
çıkar; tanınmayan her AAR da CODE ("yamalı derleme değil"). *(Sonra: TASK/042 — onaylı
AAR değişti, aşağıda.)*

**TASK/042 (main'de, 2026-09-27):** `PATCHED_RELEASE_AAR_SHA256`
artık v6.0 + 0001 + 0002 + 0003 derlemesini onaylıyor — release `f5a563a7…`
(debug `a78acb22…`). TASK/041 AAR'ı (release `14c745e9…`, GMA 24.9.0 — kusurlu değil)
`SUPERSEDED_RELEASE_AARS`'ta: geri gelirse CODE ("artık onaylı değil"). Kusurlu M9 AAR'ı
(`90d35992…`) `KNOWN_PLUGIN_DEFECTS`'te kalıyor (CODE). Kapı ayrıca üretilen
`AdmobPlugin.gd`'den GMA **25.3.0**'ı (`REQUIRED_GMA_VERSION`) ve cephede TFAT'ı
(`plugin_facade_tfat`) ister. `UYUM:` satırının metni değişti (TFAT TEEN teknik olarak
hazır ama yaş bandı yönlendirmesi yok, üretim UNSPECIFIED); `teen_ad_treatment_resolved`
= false, satır kalıyor — TFAT'ın teknik olarak hazır olması onu kaldırmaz (#26).
`release_config_test` 182/182.

Önceki çıktıdaki genel kitle satırı (`[OWNER] kitle kararı yok …`) owner'ın 13+
kararıyla kapandı (2026-09-25); yerine ürün kitlesinden AYRI `[OWNER] UYUM:`
satırı geldi — 13–17 genç reklam işlemi stratejisi seçilip uygulanana kadar
kalır, hiçbir TFCD / TFUA / derece değeri onu kaldırmaz (#26). İki paket
satırı (`[OWNER]` kimlik seçilmedi · `[CONFIG]` preset
`com.example.squishymerge`) 2026-09-24'te karar + preset güncellemesiyle
kapanmıştı. Kapı hâlâ fail-closed: kitle kararı boşalırsa OWNER, karma / çocuk
kararı yazılırsa CODE engeli döner.

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
| 12 | **Reklam kimliği (AD_ID) beyanı** | 🟣 | Uygulama reklam kimliğini kullanıyor (GMA `AD_ID` izni). Konsol formunun ayrıntısı **UNVERIFIED**. Bugün izin **kalıyor** (yalnız çocuklara yönelik (C) kitlede çıkarılırdı, AUDIENCE_DECISION §3); 13–17 uyum stratejisi (#26) reklam kimliği kullanımını etkileyebilir. |
| 13 | **Hedef kitle ve içerik** | ✅🟣 | **KARAR (owner, 2026-09-25 — FİNAL, ürün kitlesi KAPALI): 13+ genel kitle, 13 yaş altı için tasarlanmadı ve pazarlanmaz.** Play Console hedef yaş grupları: **13–15, 16–17, 18+ SEÇİLİR**; 5 ve altı, 6–8, 9–12 **SEÇİLMEZ**. Bu, "Families hiçbir yerde uygulanmaz" demek **DEĞİL**: Google'a göre 13–15 ve 16–17 bazı yerlerde çocuk sayılabilir ve 21 yaş altını hedefleyen uygulama yerel hukuku değerlendirmeli — dağıtılan bölgelere göre Families / çocuk gizliliği / reklam yükümlülükleri değerlendirilir (#26). Repoda: `android_export.cfg [Audience] decision=general_13_plus` (kapı kabul eder). TFCD/TFUA gönderilmez, derece G — **değişmedi**, TEEN işlemi DEĞİL; yaş ekranı / çocuğa yönelik reklam mantığı yok. Karar yerel rıza / reklam kurallarını geçersiz kılmaz. Konsol formu owner'da (hesap açılınca); formdaki diğer sorular bu kararla cevaplanmadı. Ayrıntı: [monetization/AUDIENCE_DECISION.md](monetization/AUDIENCE_DECISION.md) §0. |
| 14 | **İçerik derecelendirme (IARC)** | 🟣 | Her yeni uygulama için zorunlu anket; reklamlar derecelendirmeye uygun olmalı (AdMob en yüksek derece G). *(Sonra: TASK/043 — derece yaş bandından: TEEN T, ADULT MA; IARC sonucu `[Audience] app_content_rating`'e yazılır ve kapı T / MA ile karşılaştırır — #28.)* |
| 15 | **Uygulama erişimi (App access)** | 🟣 | Giriş/hesap yok, özel erişim gerektiren içerik yok → "tüm işlevler özel erişim olmadan kullanılabilir" beyanı (owner doğrular). |
| 16 | **Mağaza girişi** | 🟠🟣 | Kısa açıklama (≤80), tam açıklama (≤4000), kategori (ör. Oyun → Bulmaca; owner seçer), iletişim e-postası, grafikler (#7, #8). Dil(ler) owner'ın. **Kitle kuralı (#13):** "çocuklar için" / "çocuk oyunu" / "yürümeye başlayan çocuklar için" / "okul öncesi" (*for kids / children's game / for toddlers / preschool*) gibi ifadeler yok, 13 yaş altına bilerek pazarlama yok; kawaii sanat kalır. Google: 13 altı için tasarlanmamış bir uygulamanın girişi aksini düşündüren öğeler (çocuksu animasyon, genç karakterler) içerirse uygulama reddedilebilir. |
| 17 | **Kapalı test kanalı + test kullanıcıları** | 🟣🔵 | Şart KOŞULLU: **13 Kasım 2023'ten sonra açılmış kişisel (personal) Play geliştirici hesapları** üretime erişimden önce en az 12 test kullanıcısının 14 gün kesintisiz katıldığı bir kapalı test yapmalı (erken ayrılan sayılmaz), sonra üretim erişimi başvurusu. Hesabın türü ve gerçek durumu **Play Console'da kontrol edilmeli** — kuruluş (organization) hesabı ya da daha eski hesap için şart farklı olabilir. |
| 18 | **Gerçek AdMob kimlikleri** | 🟠🔵 | AdMob'da uygulama + 3 reklam birimi (ödüllü, uyarlanabilir banner, geçiş) → `android_export.cfg [Release]` dört kimlik + `is_real=true`. Kapı biçim/yayıncı/tekrar/Google-örneği kontrollerini yapar. |
| 19 | **UMP / rıza (EEA)** | ✅🔵 | Kod: resmî `canRequestAds` + gizlilik seçenekleri (yamalı eklenti). Owner: AdMob Privacy & messaging'de **GDPR mesajı** (EEA/UK/CH'de kişiselleştirilmiş reklam için sertifikalı CMP gerekli; yoksa sınırlı reklam), isteğe bağlı ABD eyalet mesajı. EEA / NOT_EEA / gizlilik seçenekleri akışı önce emülatörde (ek kanıt), sonra **gerçek Samsung A36'da doğrulandı — GEÇTİ** (M9-01.1, 2026-09-23: yamalı AAR, #120, form öncesi 0 reklam isteği, gizlilik seçenekleri tek callback, onboarding ertelemesi; logcat temiz — PRIVACY_CONSENT §7). |
| 20 | **Mimari** | ✅🟠 | Yalnız **arm64-v8a** (Play 64-bit şartı karşılanır). `armeabi-v7a` eklemek (eski 32-bit telefonlar) owner kararı; AAB bölünmüş teslimatla 64-bit indirmeyi büyütmez ama test yükü getirir. |
| 21 | **İzinler** | ✅ | VIBRATE (oyun), INTERNET, ACCESS_NETWORK_STATE, AD_ID ×2, ACCESS_ADSERVICES_AD_ID/ATTRIBUTION/TOPICS, WAKE_LOCK, FOREGROUND_SERVICE, `…DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` — hepsi GMA/eklenti/androidx kaynaklı (debug APK + AAB `aapt2` ile aynı liste). Tehlikeli (runtime) izin yok. |
| 22 | **Android geliştirici doğrulaması / paket kaydı** | 🔵 | **Düzeltildi (M9-01.1):** 30 Eylül 2026, herkese uygulanan bir son tarih DEĞİL; **ilk bölgesel uygulama dalgası** — Brezilya, Endonezya, Singapur ve Tayland'da, katılımcı mağazalardan (Google Play dahil) kurulan uygulamalar için, Android 7+ sertifikalı cihazlarda. **2027'de** tüm sertifikalı cihazlara genişliyor. Google Play uygulamaların ~%99'unu **otomatik kaydediyor**; kalanlar Play Console'dan elle kaydediliyor (developer.android.com/developer-verification). Yayımlanmamış bu uygulama için bugün ayrı bir işlem yok: hesap açılıp uygulama oluşturulunca owner kayıt durumunu Play Console'da kontrol eder. |
| 23 | **Google Play Developer hesabı** | 🔵 | Açılmadı / kimlik doğrulaması bekliyor (PROJECT_CONTEXT). Diğer bütün Play maddelerinin önkoşulu. |
| 24 | **AdMob hesabı / ödeme profili / app-ads.txt** | 🔵 | AdMob hesabı + ödeme profili owner'da. app-ads.txt (geliştirici web sitesinde) AdMob'un önerdiği doğrulama — web sitesi gizlilik politikasıyla aynı yer olabilir (zorunluluk ayrıntısı **UNVERIFIED**). |
| 25 | **SDK sürümü (teknik borç)** | ✅ CODE (TASK/042, main'de; GMA Next-Gen hâlâ yok) | Bugün **GMA 24.9.0 legacy** (destek **2027-06-30**'a kadar) *(Sonra: TASK/042 — üretim GMA 25.3.0, main'de; aşağıda)*. TFCD/TFUA'nın yerine geçen **TFAT** (`setAgeRestrictedTreatment`) legacy **25.3.0+**'da; Google'ın bugün tercih ettiği Android SDK'sı **GMA Next-Gen**. Data safety beyanı yalnız en yeni sürümü (25.5.0) anlatıyor. SDK geçişinin kendisi eklenti güncellemesine bağlı ayrı bir modernizasyon işi (AUDIENCE_DECISION §2.1); M9-01.1'de ve task/039'da **YAPILMADI**. **Düzeltme (2026-09-25):** 24.9.0 TFAT `TEEN` gönderemez, bu yüzden 13–17 genç reklam işlemi yalnız teknik borç DEĞİL — ayrı, AÇIK bir release-uyum kararı (#26); SDK geçişi ancak seçilen strateji gerektirirse iş olur. **TASK/040 (spike, üretime alınmadı):** GMA **25.3.0** (ilk TEEN-yetenekli sürüm; UMP 4.0.0) vendored v6.0 + yamayla Godot 4.6.3'te derlendi ve A36'da çalıştı — banner / ödüllü / geçiş / UMP / gizlilik seçenekleri; 25.0.0'da kaldırılan API'leri eklenti kullanmıyor (`tools/admob_plugin/0002-…patch` — TASK/041'de `0003-spike-…` oldu, [GLOBAL_TEEN_AD_TREATMENT §C](monetization/GLOBAL_TEEN_AD_TREATMENT.md)). upstream v7.0 Godot 4.7 istiyor (bu projede yasak). **ÜRETİME ALINDI — TASK/042 (2026-09-27; `task/042-gma25-production` main'e ff-only alındı 2026-09-27):** üretim yığını **GMA 25.3.0** (`play-services-ads` + `play-services-ads-api` 25.3.0) + **UMP 4.0.0** (ads-api 25.3.0 üzerinden geçişli, ayrı geçersiz kılma yok) — üretim yaması `tools/admob_plugin/0003-gma25-age-restricted-treatment.patch` (v6.0 + 0001 + 0002 + 0003; 0002 değişmedi), onaylı AAR'lar debug `a78acb22…`, release `f5a563a7…` (iki temiz derleme bayt-aynı; derleme betiği çözülmüş sürümleri denetler). **TFAT** (`AgeRestrictedTreatment` UNSPECIFIED / CHILD / TEEN) üretim eklentisinde teknik olarak hazır; üretim varsayılanı herkes için **UNSPECIFIED** (yaş işlemi seçimi #26). `javac` 25.3.0'a karşı 11 kullanımdan kalkma uyarısı (TFCD / TFUA getter / setter'ları, sabit uyarlanabilir banner boyutu yardımcıları) — kaldırılmadılar, derleme sorunsuz. Samsung A36 kapısı GEÇTİ (UMP EEA / NOT_EEA / gizlilik seçenekleri, banner / ödüllü / geçiş, yaşam döngüsü, logcat temiz). Spike dosyaları ve `spike` modu KALDIRILDI (git geçmişinde `e152986` / `d32a4d3`). |
| 26 | **13–17 genç reklam işlemi / yargı bölgesi uyumu** | 🟠 | *(Sonra: TASK/043, 2026-09-27 — strateji B (yaş bandı yönlendirmesi) uygulandı, Samsung A36 kapısı GEÇTİ, `teen_ad_treatment = "age_band_routing"` kaydedildi → **strateji satırı KALKTI**; yargı bölgesi ve içerik derecesi ayrı satırlar #28 / #29 — AÇIK.)* **AÇIK — üretim yayınından önce çözülmeli.** Kapıda ayrı `[OWNER] UYUM:` satırı; bu açıkken yüklenebilir AAB (kapalı test yüklemesi dahil) üretilmez. Ürün kitlesi kararından (#13) AYRI. GMA 24.9.0 TFAT `TEEN` gönderemez (`TEEN`'in eski TFCD/TFUA'da karşılığı yok) *(Sonra: TASK/042 — üretim GMA 25.3.0'da TFAT teknik olarak hazır, main'de; üretim yine UNSPECIFIED)*; bugünkü `unspecified` / `unspecified` / G TEEN işlemi DEĞİL, uyum bunlardan iddia edilmez. Stratejiler (belgelendi, **seçilmedi**) *(Sonra: owner yönü 2026-09-27 — aşağıda TASK/042 / TASK/043)*: A) `TEEN` gönderebilen GMA / eklenti yolu, B) yaş / yaş bandı düzeneği, C) owner açıkça seçerse ileride başka ürün konumu, D) gerçek yayın bölgeleri için UNSPECIFIED'in yeterli olduğuna karar veren hukuki inceleme — [AUDIENCE_DECISION §2.2](monetization/AUDIENCE_DECISION.md). task/039'da yaş ekranı / GMA yükseltmesi / reklam değişikliği YOK. **TASK/040:** fizibilite + karar tablosu (A herkes için TEEN · B uygulamanın yaş bandı · C UNSPECIFIED + hukuki belirleme; D eski TRUE etiketleri REDDEDİLDİ; E 18+ seçilmedi) → [GLOBAL_TEEN_AD_TREATMENT §D–§G](monetization/GLOBAL_TEEN_AD_TREATMENT.md); TEEN A36'da kanıtlandı; **karar hâlâ owner'da**, engel açık. **Play Age Signals reklam kararında KULLANILMAZ** (Age Signals şartları reklam / pazarlama / profilleme / analitik kullanımını yasaklıyor). **TASK/042 (2026-09-27, main'de):** TFAT `TEEN` artık üretim eklentisinde teknik olarak gönderilebilir (GMA 25.3.0, #25), ama üretim herkes için **UNSPECIFIED** gönderir — `unspecified ≠ TEEN`, uyum bundan iddia edilmez; yaş bilgisi kullanılmıyor, **yaş bandı yönlendirmesi YOK**. İstek yapılandırması `MobileAds.initialize()` öncesi BİR kez uygulanır, geri okunup doğrulanır; uyuşmazsa SDK başlatılmaz (fail-closed); SDK yapılandırılınca yaş işlemi kilitlenir (sonraki farklı değer reddedilir). Derece G, TFCD / TFUA değişmedi. `teen_ad_treatment_resolved=false`; kapının `UYUM:` satırı kalıyor (metni güncellendi, §1). **Owner yönü (2026-09-27, TASK/042 brief'i):** owner onaylı, gelir odaklı yaş bandı yönlendirmesi — 13–17 → TEEN, 18+ → normal rıza kontrollü yetişkin yolu (UNSPECIFIED) — **TASK/043**'te uygulanacak; **TASK/043 BAŞLAMADI**. Bu yön OWNER `UYUM:` engelini KAPATMAZ; uyum / hukuki değerlendirme owner'da, AÇIK. TASK/043 yönlendirmeyi SDK başlamadan ÖNCE yapmalı (onboarding rızayı + SDK'yı zaten erteliyor) ya da başlatma sonrası anlamı kendisi tanımlamalı. |
| 28 | **Play "Uygunsuz reklamlar" — uygulama içerik derecesi ↔ reklam derecesi** (TASK/043) | 🟠🟣 | **AÇIK.** Play reklam politikası: uygulamadaki reklamlar **uygulamanın içerik derecesine** uygun olmalı (örnek: "Everyone" uygulamada Teen reklam uygunsuz). AdMob tablosu: G 3+ · PG 7+ · T 12+ · MA 16+ / 18+. Owner'ın yönlendirmesi TEEN'e T, ADULT'a MA gönderiyor → uygulamanın Play derecesi en az 16+ olmalı (yalnız T için 12+). IARC sonucu henüz yok; sevimli birleştirme oyunu için düşük (ör. 3+) çıkması olası. Owner: IARC sonucunu `android_export.cfg [Audience] app_content_rating`'e yazar; derece yetmiyorsa yönlendirme dereceleri owner kararıyla düşürülür (3+ → G, 7+ → PG, 12+ → T; kod değişikliği, TEEN / UNSPECIFIED ayrımı ve yetişkin kişiselleştirilmiş reklam yolu korunur). Kapı: `ad_content_rating_problem` (OWNER). [AGE_BAND_ROUTING §6](monetization/AGE_BAND_ROUTING.md). |
| 29 | **Yargı bölgesi yaş yükümlülükleri** (TASK/043) | 🟠 | **AÇIK — owner / hukuk.** Dünya geneli dağıtımda kendi beyanlı yaş ekranı şunları kendiliğinden karşılamaz: **Brezilya Digital ECA** (Google Play yardım sayfası: çocuk / ergenlere yönelik ya da erişmesi muhtemel uygulamalar mağazadan yaş aralığı almalı; bu oyunlarda loot box yasağı — bu oyunda rastgele içerikli sandıklar var, gerçek para yok), **ABD eyalet uygulama mağazası yasaları** (ör. Teksas SB2420; Google Play özellikleri zorunlu tutmuyor), **AB / BK / İsviçre dijital rıza yaşı** (rıza yaşının altı için Google TFUA / CHILD araçlarını gösteriyor; uygulama 13–17'yi ülkeden bağımsız TEEN + UMP rızasıyla yönlendiriyor), **Families "bazı yerlerde çocuk"** (13–15 / 16–17; çocuklardan AAID göndermemek — TEEN bunu kapatmaz). Play Age Signals reklamda ASLA kullanılmaz (yaşa uygun deneyim için ayrı değerlendirme owner'ın). Owner kararı AGE_BAND_ROUTING §9'a yazılır ve `[Audience] jurisdiction_age_review = "recorded"` yapılır (ör. hukuk incelemesi, ülke hariç tutma). Kapı: `JURISDICTION_REVIEW_BLOCKER` (OWNER). |
| 27 | **Eklenti RequestConfiguration kusuru** | ✅ CODE (TASK/041) | **TASK/040 bulgusu (A36 kanıtı):** Godot 4.6 Dictionary int'lerini `Long`, dizileri `Object[]` olarak geçiriyor; vendored v6.0 `AdmobConfiguration`'ın `(int)` / `(String[])` dönüşümleri `ClassCastException` atıyor → `MobileAds.setRequestConfiguration()` hiç çağrılmıyor (Godot istisnayı yutuyor). Etki: **derece G etkin değil**, TFCD / TFUA ve test cihazları uygulanmıyor, ileride seçilecek yaş işlemi de uygulanamaz. Spike yamasında düzeltildi (A36: G + TEEN uygulandı); **üretim AAR'ı değişmedi** → kapı CODE engeli (`ReleaseReadiness.KNOWN_PLUGIN_DEFECTS`). Düzeltilmiş eklenti derlemesi + M9 cihaz/gizlilik regresyonu ayrı görev (her strateji için gerekli). **KAPANDI — TASK/041 (2026-09-27; main'de):** üretim yaması `tools/admob_plugin/0002-fix-request-configuration-value-types.patch` + yeni AAR'lar (GMA 24.9.0 / UMP 3.2.0 aynı, iki temiz derleme bayt-aynı); Samsung A36'da her süreçte `applied max_ad_content_rating=G tag_for_child_directed_treatment=-1 tag_for_under_age_of_consent=-1 … test_device_ids=3` ilk reklam yüklemesinden ÖNCE, SDK test-cihazı ipucu 0, UMP EEA / NOT_EEA / gizlilik seçenekleri + banner / ödüllü / geçiş + yaşam döngüsü + logcat temiz ([ADS_SYSTEM §15](monetization/ADS_SYSTEM.md)). Kapı düzeltilmiş AAR'ı onaylar; eski SHA kayıtta kalır (geri gelirse CODE). *(Sonra: TASK/042, main'de — kusur KAPALI kalıyor: 0002 değişmeden 0003'ün altında, A36'da yapılandırma yine ilk yüklemeden önce uygulanıp geri okundu; onaylı AAR artık release `f5a563a7…`, TASK/041 AAR'ı `14c745e9…` SUPERSEDED — geri gelirse CODE "artık onaylı değil"; kusurlu `90d35992…` yine CODE.)* |

## 3. Owner girdileri gelince: yüklenebilir AAB

0. ~~**Kod (TASK/040 bulgusu, #27):** RequestConfiguration kusurunu düzelten eklenti
   derlemesi (ayrı görev, owner onayıyla; kapının `[CODE]` satırı ancak o zaman kalkar).~~
   ✅ TASK/041 (A36 kanıtı, 2026-09-27; main'de).
1. project.godot `[squishy]`: ~~`release/android_package_id`~~ ✅
   `com.obappstudio.squishymerge` (2026-09-24); `privacy/policy_url="https://…"`;
   gerekirse `release/android_version_code`.
2. Yerel `export_presets.cfg` (her makinede): "Android Release AAB" + "Android AAB
   NOT FOR UPLOAD" `package/unique_name` = `com.obappstudio.squishymerge`, "Android"
   (debug TEST-reklam) = `com.obappstudio.squishymerge.qa` — iş makinesinde yapıldı
   (2026-09-24); versionCode aynı sayı; `version/name` BOŞ.
3. `addons/AdmobPlugin/android_export.cfg`: `[Release]` dört kimlik,
   `[General] is_real=true`; ~~`[Audience]` kararı~~ ✅ `decision=general_13_plus`
   (2026-09-25, AUDIENCE_DECISION §0). 13–17 genç reklam işlemi stratejisi (#26)
   seçilip ayrı bir görevde uygulanmalı — kapının `UYUM:` satırı ancak o zaman kalkar.
   *(TASK/042, main'de: TFAT teknik olarak hazır, üretim UNSPECIFIED. Owner'ın 2026-09-27
   yönü — yaş bandı yönlendirmesi, TASK/043, BAŞLAMADI — bu engeli kendiliğinden
   kapatmaz; uyum değerlendirmesi owner'da.)* *(Sonra: TASK/043 — yönlendirme uygulandı;
   `[Audience] teen_ad_treatment = "age_band_routing"` A36 kapısından sonra yazıldı
   (2026-09-27, A–F geçti) — strateji satırı kalktı. Ayrıca
   `app_content_rating` (IARC sonucu, #28) ve `jurisdiction_age_review = "recorded"` (owner /
   hukuk kararı, #29) owner kayıtları.)*
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
- `[Audience]` dikişi (karar 2026-09-25: `general_13_plus`), gizlilik politikası satırı dikişi.
- Tek sürüm kaynağı, release kapısı (üç giriş noktası), pipeline, çıktı taraması.
- Testler: `release_config_test` 106, `monetization_test` 248; tam regresyon yeşil.
