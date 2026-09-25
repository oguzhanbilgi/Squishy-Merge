# GLOBAL_TEEN_AD_TREATMENT.md — Dünya geneli 13+ genç reklam işlemi: fizibilite ve karar dosyası (TASK/040)

> **Durum (2026-09-25, `task/040-global-teen-compliance`, main'e ALINMADI):**
> teknik fizibilite çalışması. **Owner kararı gereken tek konu AÇIK kalıyor:**
> 13–17 genç reklam işlemi stratejisi (§D). Bu doküman bir strateji SEÇMEZ,
> hukuki tavsiye DEĞİLDİR ve Google'ın resmî sayfalarının sade Türkçe özetidir
> (kaynaklar §H, 2026-09-25'te okundu). Release kapısının 13–17 `UYUM:` engeli
> açık kalır; teknik yapılabilirlik owner politikası seçimi değildir.
>
> **Sonuç özeti:** Godot 4.6.3 + godot-admob v6.0 + GMA **25.3.0** (UMP 4.0.0)
> üzerinde `AgeRestrictedTreatment.TEEN` **Samsung A36'da kanıtlandı** (başlatmadan
> önce + her reklam yüklemesinde; UMP / banner / ödüllü / geçiş / gizlilik
> seçenekleri çalışıyor) — yalnız spike, üretime alınmadı (§C). **Yeni bulgu:**
> bugünkü üretim eklentisi RequestConfiguration'ı hiç uygulamıyor → derece G etkin
> değil; kapı artık bunu **CODE** engeli olarak gösteriyor (§C4).

## ⚠ Mimari kısıt — Play Age Signals reklam kararında KULLANILMAZ

Google Play Age Signals API'sinin hizmet şartları (overview sayfası, "Last
modified: October 2025") verinin yalnız yasalara uygun **yaşa uygun içerik ve
deneyim** sağlamak için kullanılabileceğini, **reklam, pazarlama, kullanıcı
profilleme ya da analitik** dahil başka hiçbir amaçla kullanılamayacağını
söylüyor; ihlal API erişiminin kesilmesi ve uygulamanın Play'den kaldırılmasıyla
sonuçlanabilir. Play Geliştirici Politikası'nın "Age Signals API and User Data"
bölümü de (1 Ocak 2026'dan beri) hedefli reklam dahil reklam / pazarlama /
kişiselleştirme ve analitik / profilleme kullanımını açıkça yasaklıyor.

Bu yüzden şu mimari **YASAK** (bu projede hiçbir zaman kurulmaz):

```
Play Age Signals (ageLower / ageUpper / ageRangeSource)
    -> AdMob TEEN / UNSPECIFIED seçimi -> reklam yükleme          ← YASAK
```

Age Signals verisi şunlara **girmez**: `MonetizationManager`, `AdBackend`,
`AdmobBackend`, `RequestConfiguration`, kişiselleştirilmiş / kişiselleştirilmemiş
reklam kararı, reklam birimi seçimi, reklam sıklığı / aralığı, gelir analitiği.
Age Signals verisi reklam hedeflemesi için saklanmaz.

Durum (kodla kilitli): projede Age Signals bağımlılığı ya da kodu **YOK**
(`release_config_test` "Play Age Signals reklam / runtime koduna BAĞLI DEĞİL":
`scripts/` + `addons/` + `project.godot` taranır). TASK/040'ta Age Signals
bağımlılığı eklenmedi. Age Signals ileride yalnız reklamla ilgisi olmayan
yaşa uygun deneyim / yargı bölgesi uyumu için ayrıca araştırılabilir (owner
kararı; bu görevin kapsamı dışında).

## A. Owner kararları — KAPALI

| karar | değer |
|---|---|
| Android paket kimliği | üretim `com.obappstudio.squishymerge` · QA `com.obappstudio.squishymerge.qa` |
| Ürün kitlesi | `general_13_plus` — 13+ genel kitle |
| Play hedef yaş grupları | 13–15 · 16–17 · 18+ |
| Hedeflenmeyen / pazarlanmayan | 5 ve altı · 6–8 · 9–12 |
| Dağıtım | **dünya geneli** (sınırlı ülke soft launch'ı DEĞİL) |

## B. Resmî gerçekler (kaynaklı, sade özet)

**B1 · Play hedef kitle (kaynak 1).** Seçilebilir gruplar 5 ve altı / 6–8 /
9–12 / 13–15 / 16–17 / 18+. 13–15 ve 16–17 için aynı not var: bu yaş grubu bazı
yerlerde çocukları kapsıyor sayılabilir. 21 yaş altını hedefleyen uygulama,
kullanıcıların yerel hukukta çocuk sayılıp sayılmadığını değerlendirmeli.
Hedef kitlesinde çocuk olan uygulamalar Families şartlarına uymalı.

**B2 · Families reklam kuralları (kaynak 2).** Çocuklara ya da yaşı bilinmeyen
kullanıcılara reklam gösteren uygulama: yalnız Families sertifikalı reklam
SDK'ları, ilgi alanına dayalı reklam ve yeniden pazarlama yok, çocuğa uygun
içerik, Families reklam biçimi kuralları. Karma kitlede nötr yaş ekranı.
(Bu proje 13 altını hedeflemiyor; B1'deki 13–17 notu yüzünden kural yargı
bölgesine göre değerlendirilecek bir risk olarak kayıtta.)

**B3 · Play Age Signals (kaynak 3–6).** Güncel kütüphane `age-signals:0.0.4`
(Temmuz 2026). Yaş aralığı (`ageLower` / `ageUpper`, varsayılan bantlar 0-12 /
13-15 / 16-17 / 18+) ve kaynağını (`ageRangeSource`: TIER_A = kullanıcının kendi
beyanı … TIER_D = kimlik + selfie ya da dijital kimlik) döndürür. Brezilya
(17 Mart 2026, Digital ECA) ve Teksas (SB2420) için sinyal veriyor; Google
Avustralya / Kanada'ya ve ardından dünya geneline genişleme duyurdu (blog,
29 Temmuz 2026 — ileriye dönük ifade). Google Play API'yi zorunlu tutmuyor;
yasaların uygulamaya nasıl uygulandığını belirlemek geliştiricinin sorumluluğu.
Kullanım şartları: yukarıdaki ⚠ bölüm.

**B4 · TFAT — Tag for Age Treatment (kaynak 7–9).**
- API: `RequestConfiguration.Builder.setAgeRestrictedTreatment(AgeRestrictedTreatment)`;
  değerler `CHILD` / `TEEN` / `UNSPECIFIED`. Ayar kullanılınca SDK reklam
  isteklerine `tfat` parametresi ekler.
- **TEEN** (AdMob Help, kaynak 8): kişiselleştirilmiş reklam ve yeniden pazarlama
  kapalı; gençler için reklam sunma korumaları uygulanır. Google TEEN için
  **başka** bir kısıt yazmıyor (reklam kimliği / üçüncü taraf istekleri hakkında
  TEEN için ifade YOK — çıkarım yapılmadı).
- **CHILD**: kişiselleştirilmiş reklam + yeniden pazarlama kapalı, üçüncü taraf
  reklam satıcılarına istek kapalı, çocuk korumaları, reklam kimliği (AAID)
  gönderilmez. TFCD/TFUA "çocuk" etiketleriyle işlevsel olarak eş.
- **UNSPECIFIED**: özel yaş işlemi yok; varsayılan.
- **Geçiş tablosu** (kaynak 7): `TAG_FOR_CHILD_DIRECTED_TREATMENT_TRUE` →
  **CHILD**; FALSE / UNSPECIFIED / hiç ayarlanmamış → UNSPECIFIED; TFUA için
  aynısı; **TEEN'in eski TFCD / TFUA'da karşılığı YOK.**
- İkisi birden ayarlanırsa Google **en muhafazakâr** işlemi uygular.
- Zamanlama: bütün isteklerin değişikliği uygulaması için yapılandırma
  **SDK başlatılmadan ÖNCE** ayarlanmalı (kaynak 7).
- AdMob Help: yaş işlemi ayarları için hukuk danışmanına danışılması öneriliyor.

**B5 · SDK sürümleri (kaynak 10–13, ikili doğrulama §C).**
- `setAgeRestrictedTreatment` ilk kez **GMA Android 25.3.0**'da (2026-05-21);
  24.9.0 / 25.0.0 / 25.1.0 / 25.2.0 AAR'larında sınıf YOK (javap ile doğrulandı).
- 25.0.0 (2026-02-17) büyük sürüm: mediation `VersionInfo`, `RtbSignalData.getConfiguration`,
  eski `onFailure(String)` / `onAdFailedToShow(String)` geri çağrıları,
  `NativeAdViewHolder`, `MediationUtils` oranları kaldırıldı; uyarlanabilir
  banner boyut yöntemleri kullanımdan kalktı (hâlâ var); **UMP 4.0.0**'a geçildi.
- 25.4.0: yeni geçişli bağımlılık `com.google.android.play:hsdp:2.0.1`
  (sürüm notunda açıklaması yok). 25.5.0 (2026-09-17): minSdk **24**,
  `onInitializationFailed()` eklendi.
- TFCD / TFUA 2026 boyunca çalışıyor; Google bir büyük sürümde kaldırılmalarını
  bekliyor (tahmini 2027 ilk yarı).
- Destek: v24.x ve v25.x "Supported", kullanımdan kalkma 2027-06-30, gün batımı
  2028-06-30. Eski SDK "bakım modunda"; Google **GMA Next-Gen SDK**'ya geçişi
  öneriyor (Next-Gen 1.1.0'da `setAgeRestrictedTreatment` var).

**B6 · godot-admob upstream (kaynak 14).** v6.0'dan sonra tek sürüm v7.0
(2026-05-27; Godot **4.7 beta1**'e karşı derlenmiş; bakımcı #122'de v7.0'ın
Godot 4.7+ istediğini, 4.6.x için v6.0'ın kullanılmasını söylüyor). Hiçbir
upstream ref'te GMA 25.x, TFAT ya da bizim UMP gizlilik-seçenekleri yamamız yok;
4.6 bakım dalı yok. Yani Godot 4.6.3'te TEEN'in tek yolu vendored v6.0'ı
yamalamak (ya da ileride Godot 4.7 + v7.x + ayrı yama — Godot 4.7 bu projede
YASAK).

## C. Teknik fizibilite — Godot 4.6.3 + godot-admob v6.0 + GMA 25.3.0

**C1 · Spike sürümü: GMA 25.3.0.** İlk TEEN-yetenekli sürüm; 25.4.0 ile aynı
UMP (4.0.0) ve minSdk (23) ama 25.4.0'ın açıklamasız yeni `hsdp` bağımlılığı
yok; 25.5.0'ın minSdk 24 artışı ve yeni geri çağrısı yok → en küçük geçiş
yüzeyi. **Bu üretim geçişi izni DEĞİL**; üretime geçilecekse 25.3.x ↔ güncel
25.x hata düzeltmeleri o görevde yeniden değerlendirilmeli.

**C2 · API uyumluluk matrisi** (eklentinin kullandığı çağrılar; derleme +
`javap` ile):

| kullanım | GMA 24.9.0 | GMA 25.3.0 |
|---|---|---|
| `MobileAds.initialize / setAppVolume / setAppMuted / getInitializationStatus` | ✅ | ✅ |
| `MobileAds.setRequestConfiguration / getRequestConfiguration` | ✅ | ✅ |
| `RequestConfiguration.Builder.setTagForChildDirectedTreatment / setTagForUnderAgeOfConsent` | ✅ | ⚠ deprecated (var) |
| `setMaxAdContentRating / setTestDeviceIds / setPublisherPrivacyPersonalizationState` | ✅ | ✅ |
| `setAgeRestrictedTreatment(AgeRestrictedTreatment)` + `getAgeRestrictedTreatment()` | ❌ yok | ✅ |
| `AdSize.get*AnchoredAdaptiveBannerAdSize` (banner) | ✅ | ⚠ deprecated (var) |
| 25.0.0'da kaldırılan API'ler (mediation VersionInfo, RtbSignalData.getConfiguration, eski mediation geri çağrıları, NativeAdViewHolder, MediationUtils oranları) | — | eklenti KULLANMIYOR (derleme temiz) |
| UMP `canRequestAds / getPrivacyOptionsRequirementStatus / showPrivacyOptionsForm / requestConsentInfoUpdate / DebugGeography` | 3.2.0 ✅ | 4.0.0 ✅ (public API farkı yalnız yeni `setConsentSyncId`; DebugGeography değerleri aynı) |
| minSdk (proje 24) | ads-api 23 · UMP 21 | ads-api 23 · UMP 23 |
| Kotlin ≥ 2.1.0 (GMA 24.1.0'dan beri) | şablon 2.1.21 ✅ | ✅ |

**C3 · Derleme.** `tools/admob_plugin/build_patched_plugin.sh spike` = v6.0 +
`0001` (M9 UMP yaması) + `0002-spike-gma25-age-restricted-treatment.patch`,
projenin Godot 4.6.3 şablon Gradle'ı (8.11.1, AGP 8.6.1) → **BAŞARILI**,
yalnız kullanımdan kalkma uyarıları; aynı girdiyle iki bağımsız derleme
bayt-aynı. Çıktı `build/admob_plugin_spike/out/spike/` — `addons/AdmobPlugin`'e
**KURULMAZ** (üretim eklentisi GMA 24.9.0 / UMP 3.2.0 olarak kaldı; kod testle
kilitli). QA APK: `tools/admob_plugin/spike_qa_export.sh` (yalnız
`com.obappstudio.squishymerge.qa`, Google TEST kimlikleri; üretim dosyaları
yalnız export süresince değişir ve SHA-256 ile birebir geri konur).

**C4 · Bulunan üretim hatası — RequestConfiguration hiç uygulanmıyor (YENİ CODE engeli).**
- **Kök neden (A36 native log, spike):** Godot 4.6, `set_request_configuration`
  Dictionary'sindeki değerleri Java'ya şu tiplerle veriyor:
  TFCD / TFUA / kişiselleştirme / yaş işlemi = `java.lang.Long`,
  `test_device_ids` = `Object[]`, derece = `String`, `is_real` = `Boolean`.
  Vendored v6.0 `AdmobConfiguration` bunları `(int)` (= `checkcast Integer`) ve
  `(String[])` ile okuyor → `ClassCastException` → `createRequestConfiguration()`
  hiç dönmüyor, `MobileAds.setRequestConfiguration()` **hiç çağrılmıyor**. Spike'ın
  ara sürümü (yalnız int düzeltmesiyle) A36'da ikinci istisnayı logladı:
  `java.lang.Object[] cannot be cast to java.lang.String[]` (facade `test_device_ids`
  anahtarını her zaman — boş dizi olarak bile — gönderiyor).
- **Üretim eklentisinde de aynı (M9-01.1 A36 logları, 2026-09-23):**
  `set_request_configuration()` girişinden sonra tek bir `AdmobConfiguration` satırı
  yok ve SDK "setTestDeviceIds… to get test ads on this device" ipucunu basıyor —
  yapılandırma uygulanmamış. Godot JNI istisnayı sessizce yutuyor (logcat'te
  ClassCast satırı çıkmıyor; bu yüzden M9 kapısı "ClassCast 0" gördü).
- **Etki (bugün main):** `max_ad_content_rating = G` fiilen **etkin değil** (önceki
  dokümanlardaki "derece G her istekten önce etkin" ifadesi yanlıştı — düzeltildi);
  TFCD / TFUA `unspecified` zaten SDK varsayılanı (fark yok); test cihazı kaydı
  (yalnız debug) etkin değil; ileride seçilecek **herhangi** bir yaş işlemi / etiket
  değeri de bu yol düzelmeden uygulanmaz.
- **Spike düzeltmesi (0002):** Number-güvenli int okuma + `Object[]` → `String[]`
  dönüşümü + hata/tip loglama → A36'da `set_request_configuration:applied
  {… max_ad_content_rating=G, test_device_ids=3, age_restricted_treatment=TEEN}`.
  Upstream 953df5e aynı Long sorununu `((Long) x).intValue()` ile düzeltmiş.
- **Üretim düzeltmesi bu görevde YAPILMADI** (üretim AAR'ı `90d35992…` değişmedi).
  Release kapısı bunu **CODE** engeli olarak raporlar (`ReleaseReadiness.KNOWN_PLUGIN_DEFECTS`,
  AAR SHA-256'sına bağlı; girdi yoksa SHA'dan türetilir — fail-closed). Düzeltilmiş
  derleme + M9 UMP/gizlilik cihaz regresyonu ayrı görev (hangi strateji seçilirse
  seçilsin gerekli).

**C5 · Cihaz kanıtı (Samsung A36, 2026-09-25) — GEÇTİ.** SM-A366B / Android 16;
yalnız QA paketi `com.obappstudio.squishymerge.qa` (kapı için kuruldu, sonra
kaldırıldı); owner'ın üretim paketi (`com.example.squishymerge`) dokunulmadı
(meta veri önce = sonra); yalnız Google TEST kimlikleri, reklama tıklanmadı; her
dokunuş / ekran görüntüsü güvenlik kontrolünden (arama / kilit / bildirim / ön
plan) geçti. APK: `play-services-ads@@25.3.0`, `user-messaging-platform@@4.0.0`,
minSdk 24 / target 36.

| # | kontrol | sonuç |
|---|---|---|
| A | soğuk açılış (`pm clear`, `geo=eea teen`) | ✅ SDK 25.3.0 |
| B | UMP EEA formu (UMP 4.0.0) | ✅ form → Consent → OBTAINED |
| C | `canRequestAds` kapısı | ✅ rıza öncesi false, başlatma / yükleme 0; sonra true |
| L | **TEEN başlatmadan ÖNCE + her yüklemede** | ✅ `set_request_configuration:applied {G, test_device_ids=3, TEEN} initialized=false` → `initialize:before_MobileAds.initialize {TEEN}` → `load_rewarded_ad / load_interstitial_ad / load_banner_ad {TEEN}` |
| D | banner | ✅ Ana Sayfa'da gösterildi; oyunda aynı kimlik; sonuç ekranında gizli |
| E | ödüllü (günlük +150) | ✅ gösterildi, ödül tam bir kez (335 → 485), ✕ kapanış, yeniden yükleme |
| F | geçiş (doğal mola) | ✅ BİTİR → reklam → ✕ → Sonuç bir kez; aktif saat sıfırlandı; 60 sn bekleme başladı |
| G | gizlilik seçenekleri formu | ✅ Ayarlar satırı (REQUIRED) → gerçek dokunuş → form → Do not consent → geri çağrı tam bir kez; `canRequestAds` true (sınırlı reklam) |
| I | tek AdView | ✅ `load_banner_ad` ×1, tüm oturumda aynı banner kimliği |
| J | orphan | ✅ 15 sn boşta düğüm 3014 → 3014, orphan 0, statik bellek sabit |
| K | arka plan / ön plan | ✅ aynı süreç, aynı banner, reklamlar hazır |
| — | NOT_EEA eski yol (TEEN yok) | ✅ NOT_REQUIRED; native `UNSPECIFIED` + G (**UNSPECIFIED ≠ TEEN**) |
| H | logcat (8 248 QA satırı) | ✅ SCRIPT ERROR / E-godot / crash / ANR / ClassCast / NoSuchMethod / JNI / pencere sızıntısı = 0 |

Sayaçlar: `update_consent_info` 1, rıza formu yükle/göster 1/1,
`show_privacy_options_form` 1, `initialize` 1. PSS 520 MB (M9 aralığı 365–506 MB;
GMA 25 + WebView). Yerel kanıt: `build/qa_040/A36_SPIKE_GATE.md`,
`build/qa_040/device/` (loglar, kareler).

**C6 · Spike'ın sınırları.** Spike üretim politikası DEĞİL: yaş işlemi yalnız
QA komutuyla (`teen` açılış sözcüğü / `tfat`) seçilir; `AdConfig` /
`AdmobBackend` / `MonetizationManager` değişmedi. Üretime geçiş (hangi strateji
seçilirse) ayrı görev: eklenti yamasının üretime alınması + `AdConfig`
`[Audience]` alanı + kapı + tam M9 cihaz / gizlilik regresyonu.

## D. Owner kararı — HÂLÂ AÇIK: 13–17 genç reklam işlemi stratejisi

Etiketler TASK/040'ın; AUDIENCE_DECISION §2.2'deki eski etiketlerle eşleme:
task/039 A → **A**, B → **B**, D (hukuki inceleme) → **C**, C (başka ürün
kitlesi) → **E**; **D** (eski etiketler) TASK/040'ta eklendi.

**Strateji A — herkes için TEEN.** Bütün Squishy Merge reklam istekleri
`AgeRestrictedTreatment.TEEN`; yaş toplanmaz, yaş sorusu / doğum tarihi yok,
Age Signals reklamda yok. Teknik olarak basit ve tekdüze; kullanıcı yaş verisi
ve sınıflandırma mantığı yok. Bedeli: 18+ kullanıcılar da TEEN işlemi alır →
onlar için de kişiselleştirilmiş reklam ve yeniden pazarlama kapanır. Gerekli
iş: GMA 25.3+ üretim geçişi (spike yaması + düzeltilmiş RequestConfiguration
yolu), `[Audience]` alanı, başlatma ÖNCESİ yapılandırma, kapı, cihaz/gizlilik
regresyonu.

**Strateji B — uygulamanın kendi yaş bandı (13–17 / 18+).** Uygulama yalnız
gerekeni sorar; 13–17 → TEEN, 18+ → UNSPECIFIED (normal rıza denetimli yol).
**Play Age Signals kullanılmaz.** Araştırma notları (hukuki sonuç DEĞİL):
- Kendi beyanı en düşük güvence türü: Google'ın kendi Age Signals'ında bile
  "kullanıcı kendi beyan etti" en alt kademe (TIER_A).
- Bazı yargı bölgelerinde mağaza / geliştirici tarafında yaş bilgisi yükümlülüğü
  var (ör. Brezilya Digital ECA — çocuk ve ergenlerin erişmesi muhtemel
  uygulamaların mağazadan yaş aralığı alması; Teksas SB2420). Kendi beyanlı bir
  bant bu yükümlülüklerin yerine geçer mi — **belirsiz, hukuki değerlendirme
  gerekir**; "her yargı bölgesini çözer" DENEMEZ.
- Veri beyanı: yaş bandı yeni bir kullanıcı verisi; Data safety / gizlilik
  politikası etkisi owner + hukuk değerlendirmesi (kategori UNVERIFIED).
  Cihazda saklanır (kayıt); kaldırınca silinir, yeniden kurulumda yeniden
  sorulur; cevap değiştirme davranışı (nötr yaş ekranı ilkesi: yalan söylemeye
  teşvik etmemek) tasarım kararı.
- UX: ilk açılışta tutorial + rıza ertelemesiyle birlikte konumlandırılmalı
  (ilk reklam isteğinden ÖNCE).
- Uygulanmadı; yaş ekranı eklenmedi.

**Strateji C — bugünkü GMA 24.9.0 / UNSPECIFIED + dış hukuki belirleme.**
TFCD / TFUA `unspecified` kalır. Resmî belgeler bunu 13–17 için yeterli saymak
için dayanak **vermiyor** (Play: yerel hukuku değerlendir; AdMob: hukuk
danışmanına danış). `UNSPECIFIED` TEEN DEĞİLDİR. Engel ancak gerçek yayın
bölgelerini kapsayan belgelenmiş bir hukuki inceleme ile kapanabilir.
**Not:** bugünkü üretim eklentisinde RequestConfiguration zaten uygulanmıyor
(§C4) — C seçilse bile bu hata düzeltilmeli.

**Strateji D — eski TRUE etiketleri TEEN yerine (REDDEDİLDİ, kanıtla).**
Google'ın geçiş tablosu TFCD `TRUE` ve TFUA `TRUE`'yu **CHILD**'a eşliyor, TEEN'e
değil. CHILD, TEEN'den daha kısıtlayıcı (ek olarak üçüncü taraf reklam satıcısı
istekleri kapanır, AAID gönderilmez, çocuk korumaları) ve "çocuğa yönelik"
anlamı taşır — 13+ ürün konumu ve "çocuğa yönelik reklam mantığı ekleme"
kuralıyla çelişir; herkese uygulanınca en büyük gelir etkisi. TEEN'in yerine
geçmez.

**Strateji E — ürünü 18+'ya çevirmek (SEÇİLMEDİ).** 13+ kilitli; yalnız owner'ın
elindeki bir alternatif olarak listelendi, uygulanmadı.

## E. Monetizasyon etkisi (niteliksel — ölçüm YOK)

Bilinen: TEEN işlemi alan isteklerde kişiselleştirilmiş reklam ve yeniden
pazarlama kapalı (Google). A'da bu herkes için geçerli; B'de yalnız 13–17 bandı
için; C'de (hukuken kabul edilirse) değişiklik yok; D'de herkese CHILD (daha da
kısıtlı). EEA/UK/CH'de rıza vermeyen kullanıcılar bugün zaten sınırlı reklam
alıyor (UMP). Bilinmeyen: eCPM, doluluk ve gelir farkı — güvenilir yayımlanmış
bir oran bu dokümanda kullanılmadı; gerçek trafik olmadan **ölçülemez**.

## F. Karar tablosu

| | **A · herkes için TEEN** | **B · uygulamanın yaş bandı** | **C · UNSPECIFIED + dış hukuki belirleme** |
|---|---|---|---|
| Teknik olarak mümkün mü? | EVET — A36'da kanıtlandı | EVET (TEEN yolu aynı; yaş ekranı yazılmadı) | EVET (bugünkü yol; §C4 düzeltmesi gerekli) |
| Godot / eklenti işi | 0002'nin üretime alınması (GMA 25.3.0, TFAT, dönüşüm düzeltmesi, başlatma öncesi yapılandırma) + `[Audience]` alanı + kapı + M9 cihaz/gizlilik regresyonu | A'nın hepsi + yaş bandı ekranı + kayıt alanı + istek başına işlem + tutorial / rıza sırası + testler | GMA değişmez; yalnız dönüşüm düzeltmesi + hukuki kayıt |
| Yaş verisi toplanıyor mu? | HAYIR | EVET (kendi beyanı: 13–17 / 18+) | HAYIR |
| UX sürtünmesi | yok | yeni ekran (ilk reklamdan önce) | yok |
| 18+ için kişiselleştirilmiş reklam | HAYIR (herkese TEEN) | EVET (rıza denetimli) | EVET (rıza denetimli) |
| 13–17 için kişiselleştirilmiş reklam | HAYIR | HAYIR (bant doğru beyan edilirse) | EVET (rıza denetimli) |
| Kalan dünya geneli belirsizlik | TEEN'in her hedef bölgede yeterliliği hukuken teyit edilmeli | kendi beyanının yeterliliği bölgeye göre değişir (yaş güvencesi isteyen yerler) | en yüksek — belgelenmiş hukuki inceleme olmadan engel kapanmaz |
| Play Age Signals reklamda mı? | **HAYIR** | **HAYIR** | **HAYIR** |
| Tahmini kapsam | orta | büyük | küçük kod + dış hukuk işi |
| Cihaz kanıtı | ✅ A36 (TEEN, UMP 4.0.0, 3 reklam türü) | kısmi (TEEN yolu ✅, yaş ekranı yok) | UNSPECIFIED yolu ✅ (spike NOT_EEA koşusu) |
| Teknik öneri | **teknik olarak en basit, en düşük risk** | mümkün; en yüksek karmaşıklık | en küçük kod; engeli kapatan şey teknik değil |

(D eski TRUE etiketleri: reddedildi — CHILD'a eşleniyor. E 18+: seçilmedi.)

## G. Teknik öneri (hukuki belirleme ve iş kararı DEĞİL)

**Teknik öneri:** önce §C4'teki RequestConfiguration kusurunu düzelten eklenti
derlemesini üretime al (her strateji için gerekli — C dahil); owner TEEN'i
seçerse bunu kanıtlanmış GMA 25.3.0 yoluyla (0002: TFAT + dönüşüm düzeltmesi +
başlatma öncesi yapılandırma) yap. A / B / C arasında teknik olarak en basit ve en
düşük riskli uygulama **A**: Godot 4.6.3'te A36'da kanıtlandı, yaş verisi ve yeni
UI gerektirmiyor, Age Signals'a ihtiyaç yok ve B'nin de altyapısı (B = A'nın yolu +
yaş bandı).

- **Hukuki belirleme (owner + hukuk danışmanı):** TEEN'in / UNSPECIFIED'in hedef
  bölgelerde yeterli olup olmadığı; kendi beyanlı yaş bandının yeterliliği. Bu
  doküman bunu belirlemez.
- **İş / gelir dengesi (owner):** A, 18+ kullanıcılar için de kişiselleştirilmiş
  reklam ve yeniden pazarlamayı kapatır; B bunu korur ama yaş verisi, UX ve
  hukuki belirsizlik getirir; C'nin gelir etkisi yok ama engeli teknik iş
  kapatmaz. Gelir farkı gerçek trafik olmadan ölçülemez.

## H. Kaynaklar (2026-09-25'te okundu)

| # | kaynak | URL | güncelleme |
|---|---|---|---|
| 1 | Play Console Help — Target audience and content | support.google.com/googleplay/android-developer/answer/9867159 | tarih yok |
| 2 | Play Console Help — Google Play Families Policies | support.google.com/googleplay/android-developer/answer/9893335 | tarih yok |
| 3 | Play Age Signals overview (+ Terms of service, "Last modified: October 2025") | developer.android.com/google/play/age-signals/overview | 2026-07-20 |
| 4 | Play Age Signals — request / responses / release notes | developer.android.com/google/play/age-signals/{request-age-signals, understand-age-signals-responses, release-notes} | 2026-09-22 / 2026-07-21 / 2026-09-16 |
| 5 | Play policy — Age Signals API and User Data | support.google.com/googleplay/android-developer/answer/16585319 | tarih yok (politika 2026-01-01'den beri) |
| 6 | Play — US state app store bills / Digital ECA | support.google.com/googleplay/android-developer/answer/16569691 · …/answer/6223646 | tarih yok |
| 7 | AdMob Android (Legacy) — Targeting | developers.google.com/admob/android/targeting | 2026-09-24 |
| 8 | AdMob Help — Tag an ad request for age restricted treatment | support.google.com/admob/answer/6219315 | tarih yok |
| 9 | AgeRestrictedTreatment / RequestConfiguration reference | developers.google.com/admob/android/reference/… | 2026-05-21 |
| 10 | GMA Android (Legacy) release notes | developers.google.com/admob/android/rel-notes | 2026-09-24 |
| 11 | Migrate SDK versions (v24 → v25) | developers.google.com/admob/android/migration | 2026-09-24 |
| 12 | UMP release notes | developers.google.com/admob/android/privacy/release-notes | 2026-09-24 |
| 13 | Deprecation and sunset | developers.google.com/admob/android/deprecation | 2026-09-24 |
| 14 | godot-admob releases / #122 | github.com/godot-sdk-integrations/godot-admob | v7.0 2026-05-27 |
| — | Google Maven metadata + POM'lar + AAR sınıfları (javap) | dl.google.com/dl/android/maven2/… | 2026-09-25 yerel doğrulama |
