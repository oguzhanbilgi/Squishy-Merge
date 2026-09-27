# tools/admob_plugin — AdMob eklentisi yamaları (M9-01 UMP + TASK/041 RequestConfiguration + TASK/042 GMA 25.3 / TFAT)

`addons/AdmobPlugin/` = `godot-sdk-integrations/godot-admob` **v6.0** + bu
klasördeki ÜÇ üretim yaması (`0001` + `0002` + `0003`, bu sırayla). Bu klasör
export'a girmez (`tools/*` preset dışında); yalnız yamaların kaynağı, yeniden
derleme betiği ve doğrulama aracı burada.

**Üretim yığını (TASK/042):** Google Mobile Ads SDK **25.3.0**, UMP **4.0.0**
(play-services-ads-api 25.3.0'ın geçişli bağımlılığı), TFAT
(`AgeRestrictedTreatment` UNSPECIFIED / CHILD / TEEN) teknik olarak hazır —
**üretim varsayılanı UNSPECIFIED**, yaş bandı yönlendirmesi YOK (TASK/043).
*(Sonra: TASK/043 — oyun kodu yaş bandına göre yönlendirir: 13–17 → TEEN + derece T,
18+ → UNSPECIFIED + MA, 13 altı / bilinmeyen → eklenti düğümü hiç kurulmaz. Eklenti ve
yamalar DEĞİŞMEDİ — docs/monetization/AGE_BAND_ROUTING.md.)*

| dosya | ne |
|---|---|
| `0001-ump-privacy-options-and-debug-geography.patch` | üretim yaması 1 (M9-01): upstream v6.0'a UMP gizlilik seçenekleri + #120 (3 dosya, +73/−2, LF) |
| `0002-fix-request-configuration-value-types.patch` | üretim yaması 2 (TASK/041): 0001'in ÜSTÜNE `AdmobConfiguration` Godot 4.6 Long / Object[] okuma + `set_request_configuration` hata logu ve SDK geri okuması (2 Java dosyası, +93/−21, LF) |
| `0003-gma25-age-restricted-treatment.patch` | üretim yaması 3 (TASK/042): 0001 + 0002'nin ÜSTÜNE `playads` 24.9.0 → 25.3.0, `setAgeRestrictedTreatment` (TFAT), SDK geri okuma API'si `get_applied_request_configuration()`, `MobileAds.initialize` öncesi geri okuma logu, reklam kimliği (AAID) artık loglanmıyor (5 dosya, LF) |
| `build_patched_plugin.sh` | deterministik yeniden derleme + doğrulama (`baseline` / `build` / `verify` / `install`); her yamalı modda çözülmüş sınıf yolunu denetler (GMA 25.3.0 / ads-api 25.3.0 / UMP 4.0.0) |
| `aar_equivalence.py` | iki AAR'ı girdi girdi, `classes.jar`'ı sınıf sınıf karşılaştırır |

## Neden yama (0001)

Üretim rızası (UMP) için gereken üç resmî SDK çağrısını v6.0 sarmalayıcısı
SUNMUYOR ve `debug_geography` cihazda hiç uygulanamıyordu:

| sorun | yama |
|---|---|
| `ConsentInformation.canRequestAds()` yok | `can_request_ads()` |
| `getPrivacyOptionsRequirementStatus()` yok | `get_privacy_options_requirement_status()` → `"REQUIRED"` / `"NOT_REQUIRED"` / `"UNKNOWN"` |
| `UserMessagingPlatform.showPrivacyOptionsForm()` yok | `show_privacy_options_form()` + sinyal `privacy_options_form_dismissed` |
| #120: Java `instanceof Integer`, Godot int'i `Long` gönderiyor → debug coğrafyası sessizce yok sayılıyor | `instanceof Number` + `intValue()` |

`Admob.gd` cephesi aynı üç metodu ve `has_privacy_options_api()`'yi (yamalı AAR
yeni sinyali kaydettiyse true) ekler. Upstream durumu (2026-09-22): v7.0 ve
`main` yalnız #120'yi düzeltiyor, üç çağrıyı sunmuyor; v7.0 Godot 4.7 hedefli —
bu proje 4.6.3'e kilitli. Başka sınıf, kaynak, bağımlılık ya da sürüm
DEĞİŞMEDİ (GMA 24.9.0 / UMP 3.2.0 aynı).

## Neden yama (0002 — TASK/041)

TASK/040 A36'da buldu: Godot 4.6, facade'ın `set_request_configuration`
sözlüğündeki int'leri `java.lang.Long`, dizileri `Object[]` olarak veriyor; v6.0
`AdmobConfiguration` bunları `(int)` (= `checkcast Integer`) ve `(String[])` ile
okuyordu → `ClassCastException` (Godot JNI köprüsü log bile basmadan yutuyor) →
`MobileAds.setRequestConfiguration()` HİÇ çağrılmıyordu: derece G, TFCD / TFUA ve
(yalnız debug) test cihazları etkin DEĞİLDİ.

| değer (Godot → Java) | v6.0 | 0002 |
|---|---|---|
| TFCD / TFUA / kişiselleştirme (`Long`) | `(int)` → ClassCastException | `instanceof Number` → `intValue()` |
| `test_device_ids` (`Object[]`, facade boş diziyi de gönderir) | `(String[])` → ClassCastException | `Object[]` üzerinde döngü, yalnız boş olmayan `String` girdiler |
| `is_real` / `first_party_id_enabled` (`Boolean`), derece (`String`) | kör dönüşüm (eksikse NPE) | tip denetimi |
| okunamayan değer | istisna, hiçbir şey uygulanmaz | `Invalid request configuration value '<anahtar>' …` logu (yalnız tip, değer asla), o ayar atlanır — SDK mevcut değerini korur; `is_real` okunamazsa gerçek sayılır (test cihazı eklenmez) |
| `set_request_configuration()` istisnası | Godot'ta sessizce kaybolur | yakalanır: `request configuration NOT applied` + yığın izi |
| başarı kanıtı | yok | SDK'dan geri okuma, tek satır: `set_request_configuration(): applied max_ad_content_rating=… tag_for_child_directed_treatment=… tag_for_under_age_of_consent=… personalization_state=… test_device_ids=<sayı> sdk_initialized=…` |

Değerler ve çağrılan setter'lar DEĞİŞMEDİ (derece G, TFCD / TFUA unspecified = -1,
kişiselleştirme DEFAULT, test cihazları yalnız `is_real` false iken). 0002 yeni API,
TFAT / yaş işlemi, GDScript ya da sürüm değişikliği İÇERMEZ; GMA 24.9.0 / UMP 3.2.0.
Upstream v7.0 / `main` (4b4ddce, 2026-05-27) yalnız Long dönüşümlerini
(`((Long) x).intValue()`) düzeltti; `(String[])` orada hâlâ var.

## Neden yama (0003 — TASK/042)

TASK/040 spike'ı GMA 25.3.0 + TEEN'in Godot 4.6.3'te çalıştığını A36'da kanıtlamıştı;
TASK/042 bunun güvenli ve gerekli kısmını üretime taşıdı (spike'ın tanı logları —
`TFAT_DIAG`, her yüklemede log, `configure_before_initialize` — ALINMADI).

| konu | 0003 |
|---|---|
| SDK sürümü | `common/gradle/libs.versions.toml` `playads` 24.9.0 → **25.3.0** (TFAT'lı ilk sürüm); UMP **4.0.0** `play-services-ads-api:25.3.0` üzerinden geçişli — ayrı geçersiz kılma yok |
| TFAT | `AdmobConfiguration`: yeni anahtar `age_restricted_treatment` (Godot `Long`: 0 UNSPECIFIED, 1 CHILD, 2 TEEN; 0002'nin `getInt`'i ile okunur, bilinmeyen değer loglanır ve uygulanmaz). CHILD / TEEN → `builder.setAgeRestrictedTreatment(...)`; UNSPECIFIED → `setAgeRestrictedTreatment(null)` = yapıcının ayarlanmamış varsayılanı (parametre `@Nullable`; GMA 25.3.0 null için -1, açık `UNSPECIFIED` için 0 gönderir, geri okuma ikisini de UNSPECIFIED gösterir — javap ile bakıldı) → yaş işlemsiz istek, sıfırlamadan sonra da, tam SDK varsayılanı. TFCD / TFUA DEĞİŞMEDEN uygulanmaya devam eder — Google: ikisi birlikte verilirse en muhafazakâr işlem uygulanır |
| geri okuma | `AdmobPlugin.get_applied_request_configuration()` (`@UsedByGodot`): SDK'nın o anki `RequestConfiguration`'ı — yaş işlemi, derece, TFCD, TFUA, kişiselleştirme, test cihazı SAYISI, SDK sürümü, `initialized`. TASK/041 `applied …` satırına `age_restricted_treatment=` eklendi; `initialize()` başlatmadan önceki yapılandırmayı loglar |
| cephe | `Admob.gd`: `age_restricted_treatment` (varsayılan UNSPECIFIED) `create_request_configuration()`'a girer; `set_request_configuration()` aynı yapıcıyı kullanır; `get_applied_request_configuration()` native metodu `has_java_method()` ile arar (Godot 4.6 Android `JNISingleton` eklenti metotlarını `has_method()`'da göstermez). `model/AdmobConfig.gd`: `enum AgeRestrictedTreatment` |
| gizlilik | debug test-cihazı yolundaki upstream `Log.d` satırları reklam kimliğini ve kimlik listesini artık YAZMIYOR (`(value not logged)`, yalnız sayı) |

Değeri eklenti değil proje seçer: `MonetizationManager.DEFAULT_AGE_RESTRICTED_TREATMENT`
= UNSPECIFIED; `AdmobBackend` yapılandırmayı `MobileAds.initialize()` ÖNCESİ bir kez
uygular, geri okur, uyuşmazsa SDK'yı başlatmaz (docs/monetization/ADS_SYSTEM.md).
GMA 25.3.0'a karşı `javac` 11 kullanımdan kalkma uyarısı verir (TFCD / TFUA — Google:
yerini yaş işlemi aldı; sabit uyarlanabilir banner boyutu yardımcıları) — kaldırılmadılar,
hata yok.

## Deterministiklik kanıtı — TASK/042 (iş makinesi, 2026-09-27)

- `build` iki kez, iki ayrı çalışma dizininde (mevcut upstream klonu + sıfırdan
  GitHub klonu), kuruluma GİRMEDEN: debug `a78acb22…15b6`, release `f5a563a7…20f8`
  ve üretilen `Admob.gd` / `AdmobPlugin.gd` / `model/AdmobConfig.gd` iki koşuda
  **bayt-aynı**. Sonra `install` (3. derleme) ve `verify` (4. derleme) aynı baytları
  üretti; `verify` depodaki AAR'ları BYTE-IDENTICAL buldu; `baseline` upstream v6.0
  AAR'larını hâlâ yeniden üretiyor.
- Her koşuda çözülmüş sınıf yolu: `play-services-ads:25.3.0`,
  `play-services-ads-api:25.3.0`, `user-messaging-platform:4.0.0` (başka sürüm yok).
- TASK/041 AAR'larıyla fark yalnız `AdmobConfiguration.class`, `AdmobPlugin.class` ve
  `AdmobPlugin$*.class`.

## Deterministiklik kanıtı — TASK/041 (iş makinesi, 2026-09-27; TARİHSEL)

- `build` iki kez, iki ayrı çalışma dizininde (mevcut upstream klonu + sıfırdan
  klon), kuruluma GİRMEDEN: debug `40ae0592…9e2c`, release `14c745e9…41a4` —
  iki koşu **bayt-aynı**. Sonra `install` (3. derleme) ve `verify` (4. derleme)
  aynı baytları üretti; `verify` depodaki AAR'ları BYTE-IDENTICAL buldu.
- M9-01 AAR'larıyla fark yalnız `AdmobConfiguration.class`, `AdmobPlugin.class`
  ve `AdmobPlugin$*.class` (javap: iç sınıfların bytecode'u aynı, yalnız satır
  numaraları kayıyor). Üretilen `Admob.gd` değişmedi.
- Gradle: `BUILD SUCCESSFUL`, uyarı / hata satırı yok.

## Deterministiklik kanıtı — M9-01 (iş makinesi, 2026-09-22; TARİHSEL)

- **`baseline`**: yamasız v6.0 bu makinede derlendi → `classes.jar`, `R.txt`,
  `res/`, `aar-metadata.properties` upstream release AAR'larıyla **birebir**;
  tek fark `AndroidManifest.xml` satır sonları (AGP kitaplık manifest'ini
  makinenin satır ayracıyla yazıyor: Windows CRLF, upstream CI Linux LF —
  XML içeriği aynı). İki bağımsız baseline derlemesi aynı SHA-256'yı verdi.
- **`install` / `verify`**: yamalı derleme üç kez (iki farklı Gradle
  başlatıcısıyla) **aynı bayt**: debug `e3ac9a6b…6eb2d`, release
  `90d35992…78284`; `verify` depodaki AAR'ları BYTE-IDENTICAL buldu. *(Bu
  AAR'lar TASK/040'ın RequestConfiguration kusurunu taşıyordu; TASK/041'de
  v6.0 + 0001 + 0002 derlemesiyle değiştirildi.)*
- Yamalı ile yamasız arasındaki tek fark `AdmobPlugin*.class` (anonim iç
  sınıflarda yalnız satır numaraları kayıyor) ve `ConsentConfiguration.class`;
  diğer 66 sınıf aynı.

## Nasıl çalıştırılır

Repo kökünden, Git Bash (Windows) / Linux / macOS:

```bash
tools/admob_plugin/build_patched_plugin.sh baseline
tools/admob_plugin/build_patched_plugin.sh verify
```

`install` yalnız bir üretim yaması bilerek değiştirildiğinde: önce `build`'i iki
kez (biri `SQUISHY_PLUGIN_WORK` ile sıfırdan bir dizinde) koşup bayt-aynı
olduğunu göster, SONRA `install`; ardından `VERSION.md`, betikteki
`PATCHED_*_SHA256_WINDOWS` + `PATCH_SHA256` / `CONFIG_PATCH_SHA256` /
`GMA25_PATCH_SHA256` ve release kapısının `PATCHED_RELEASE_AAR_SHA256`'sı
güncellenir (release_config_test hepsini çapraz denetler; eski onaylı SHA
`SUPERSEDED_RELEASE_AARS`'a girer) ve yeni AAR gerçek cihazda doğrulanır.

Sistem geneli kurulum YOK. Araçlar Godot editörünün kendi ayarlarından okunur:
JDK 17 (`export/android/java_sdk_path`), Android SDK
(`export/android/android_sdk_path`; build-tools **36.1.0** ve platform
**android-35** kurulu olmalı — eksikse betik durur, indirmez), Gradle =
projenin Godot 4.6.3 Android build şablonundaki `android/build/gradlew`
(Gradle 8.11.1), `godot-lib` = aynı şablonun AAR'ı. İnternet yalnız upstream
kaynağını ve (önbellekte yoksa) Gradle eklenti/Maven bağımlılıklarını çekmek
için gerekir. Çalışma dizini `build/admob_plugin/` (gitignore + `.gdignore`).
Geçersiz kılma: `SQUISHY_JAVA_HOME`, `SQUISHY_ANDROID_SDK`,
`SQUISHY_PLUGIN_WORK`, `PYTHON`.

Linux/macOS'ta derlenen AAR'ın SHA-256'sı Windows'takinden yalnız manifest
satır sonları yüzünden farklı çıkar; `verify` bunu `aar_equivalence.py` ile
"EQUIVALENT" olarak kabul eder, başka her farkta durur.

## TASK/040 spike'ı (TARİHSEL — TASK/042'de kaldırıldı)

TASK/040 fizibilite spike'ı (`0002-spike-…` → TASK/041'de `0003-spike-gma25-age-restricted-treatment.patch`,
`build_patched_plugin.sh spike`, `spike_qa_export.sh`, `spike_qa_preset.py`) GMA 25.3.0 +
TEEN'i A36'da kanıtladı (`docs/monetization/GLOBAL_TEEN_AD_TREATMENT.md`). TASK/042 aynı
yeteneği üretim yaması `0003-gma25-age-restricted-treatment.patch`'e taşıdı ve iki
çelişen uygulama tutulmasın diye spike dosyalarını ve `spike` modunu KALDIRDI (git
geçmişinde: `e152986`, `d32a4d3`). Spike'ın A36 kanıtı ve AAR'ları o yamalara aittir;
üretim yığınının kendi A36 kanıtı TASK/042'de (ADS_SYSTEM.md). QA sürücüsünün
(`tools/ads_device.gd`) `teen` / `tfat` / `tfat_diag` komutları artık üretim API'sini
kullanır ve YALNIZ QA teşhisidir — üretim varsayılanını değiştirmez. **Play Age Signals
hiçbir reklam koduna bağlanmaz.**

## Eklentiyi güncellerken

Yeni bir release zip'ini `addons/AdmobPlugin/` üstüne KOPYALAMA — yamalar
sessizce kaybolur: üretim rıza yolu eski türetme davranışına düşer (runtime
`has_privacy_options_api()` false görür, uyarı basar), RequestConfiguration
yine uygulanmaz ve GMA 24.9.0'a (TFAT yok) dönülür; `AdmobBackend` geri okumayı
doğrulayamaz ve SDK'yı başlatmaz. 0001 + 0002 + 0003'ü yeni etikete taşı, betikle
derle, `VERSION.md`'yi ve kapının SHA'sını güncelle. Upstream'e PR göndermek owner
kararı (docs/monetization/PRIVACY_CONSENT.md §4).
