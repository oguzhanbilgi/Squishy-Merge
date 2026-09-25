# tools/admob_plugin — AdMob eklentisi UMP yaması (M9-01)

`addons/AdmobPlugin/` = `godot-sdk-integrations/godot-admob` **v6.0** + bu
klasördeki TEK yama. Bu klasör export'a girmez (`tools/*` preset dışında);
yalnız yamanın kaynağı, yeniden derleme betiği ve doğrulama aracı burada.

| dosya | ne |
|---|---|
| `0001-ump-privacy-options-and-debug-geography.patch` | upstream v6.0 kaynağına uygulanan yama (3 dosya, +73/−2, LF) |
| `build_patched_plugin.sh` | deterministik yeniden derleme + doğrulama (`baseline` / `verify` / `install`) |
| `aar_equivalence.py` | iki AAR'ı girdi girdi, `classes.jar`'ı sınıf sınıf karşılaştırır |

## Neden yama

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

## Deterministiklik kanıtı (iş makinesi, 2026-09-22)

- **`baseline`**: yamasız v6.0 bu makinede derlendi → `classes.jar`, `R.txt`,
  `res/`, `aar-metadata.properties` upstream release AAR'larıyla **birebir**;
  tek fark `AndroidManifest.xml` satır sonları (AGP kitaplık manifest'ini
  makinenin satır ayracıyla yazıyor: Windows CRLF, upstream CI Linux LF —
  XML içeriği aynı). İki bağımsız baseline derlemesi aynı SHA-256'yı verdi.
- **`install` / `verify`**: yamalı derleme üç kez (iki farklı Gradle
  başlatıcısıyla) **aynı bayt**: debug `e3ac9a6b…6eb2d`, release
  `90d35992…78284`; `verify` depodaki AAR'ları BYTE-IDENTICAL buldu.
- Yamalı ile yamasız arasındaki tek fark `AdmobPlugin*.class` (anonim iç
  sınıflarda yalnız satır numaraları kayıyor) ve `ConsentConfiguration.class`;
  diğer 66 sınıf aynı.

## Nasıl çalıştırılır

Repo kökünden, Git Bash (Windows) / Linux / macOS:

```bash
tools/admob_plugin/build_patched_plugin.sh baseline
tools/admob_plugin/build_patched_plugin.sh verify
```

`install` yalnız yama bilerek değiştirildiğinde (sonra `VERSION.md` +
betikteki beklenen hash'ler + `PATCH_SHA256` güncellenir).

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

## TASK/040 — GMA 25.3.0 TEEN fizibilite spike'ı (ÜRETİM DEĞİL)

| dosya | ne |
|---|---|
| `0002-spike-gma25-age-restricted-treatment.patch` | 0001'in ÜSTÜNE: `playads` 24.9.0 → **25.3.0** (UMP 4.0.0 geçişli), `AgeRestrictedTreatment` (TFAT) desteği, facade'da `age_restricted_treatment` + `configure_before_initialize` (yapılandırma MobileAds.initialize ÖNCESİ), `AdmobConfiguration` dönüşüm düzeltmesi (Godot 4.6 Long / Object[]), `TFAT_DIAG` tanı logları + `get_request_configuration_diagnostics()` |
| `build_patched_plugin.sh spike` | v6.0 + 0001 + 0002 → `build/admob_plugin_spike/out/spike/` (AAR'lar + üretilen addon); **`addons/AdmobPlugin`'e ASLA kurmaz**; yama SHA-256'sı betikte sabit; aynı girdiyle iki derleme bayt-aynı |
| `spike_qa_export.sh` + `spike_qa_preset.py` | `tools/ads_device` QA sürücüsünü yalnız `com.obappstudio.squishymerge.qa` paketiyle, spike eklentisiyle export eder; `project.godot` / `export_presets.cfg` / `addons/AdmobPlugin` yalnız export süresince değişir ve SHA-256 ile birebir geri konur (değiştirilmiş dosya varsa başlamaz) |

QA sürücüsü: `qa_boot.txt` içinde `teen` → TEEN + başlatma öncesi yapılandırma;
`tfat teen|child|unspecified [apply]`, `tfat_diag`, durum satırı `tfat:`. Samsung A36
kanıtı ve karar tablosu: `docs/monetization/GLOBAL_TEEN_AD_TREATMENT.md`.
**Play Age Signals hiçbir reklam koduna bağlanmaz.**

**Üretim eklentisindeki bilinen kusur (spike'ın bulgusu):** v6.0 `AdmobConfiguration`
`(int)` / `(String[])` dönüşümleri Godot 4.6'nın Long / Object[] değerlerinde
ClassCastException atıyor → üretim AAR'ı (`90d35992…`) RequestConfiguration'ı hiç
uygulamıyor; release kapısı bunu CODE engeli olarak gösterir
(`ReleaseReadiness.KNOWN_PLUGIN_DEFECTS`). Düzeltme 0002'de; üretime alınması ayrı görev.

## Eklentiyi güncellerken

Yeni bir release zip'ini `addons/AdmobPlugin/` üstüne KOPYALAMA — yama
sessizce kaybolur ve üretim rıza yolu eski türetme davranışına düşer (runtime
`has_privacy_options_api()` false görür, uyarı basar). Yamayı yeni etikete
taşı, betikle derle, `VERSION.md`'yi güncelle. Upstream'e PR göndermek owner
kararı (docs/monetization/PRIVACY_CONSENT.md §4).
