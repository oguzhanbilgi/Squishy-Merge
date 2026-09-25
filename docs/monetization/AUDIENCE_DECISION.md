# AUDIENCE_DECISION.md — Hedef kitle, COPPA (TFCD) ve TFUA kararı (M9-01)

> **Durum: OWNER KARARI VERİLDİ — FİNAL (2026-09-25, `task/039`).** Squishy
> Merge **13+ genel kitleye yönelik** bir casual oyundur; **13 yaş altı
> çocuklar için tasarlanmadı ve onlara pazarlanmaz.** Karar kaydı §0'da. Kod
> tarafında bu, §3'teki **A seçeneği** (`general_13_plus`): ek kod yok, reklam
> istekleri değişmedi, release kapısının kitle engeli kalktı (kapı diğer owner
> maddeleri yüzünden hâlâ BLOCKED). Karardan önceki durum (2026-09-22): kod
> kararı tahmin etmedi; sevimli / kawaii sanat tek başına "çocuklara yönelik" ya
> da "13+" demek için yeterli sayılmadı.
>
> Bu doküman hukuki tavsiye değildir. Google'ın resmî sayfalarının
> (2026-09-22'de okundu) sade Türkçe özetidir; son karar owner'ındır.
> Kaynaklar §7'de.

## 0. Karar kaydı (owner, 2026-09-25 — FİNAL)

Owner'ın sözleri: *"Target audience: 13+ general audience. Not designed for
children under 13."*

| konu | karar |
|---|---|
| Ürün konumu | 13+ genel kitleye yönelik casual oyun |
| Play Console hedef yaş grupları — **SEÇİLİR** | **13–15 · 16–17 · 18+** |
| Play Console hedef yaş grupları — **SEÇİLMEZ** | **5 ve altı · 6–8 · 9–12** |
| Google Play Families politikası | uygulanmaz — 13 altı hiçbir grup seçilmedi (§3) |
| `android_export.cfg [Audience] decision` | **`general_13_plus`** |
| TFCD / TFUA / en yüksek reklam derecesi | bu kararla **DEĞİŞTİRİLMEDİ**: `unspecified` / `unspecified` / `G` — reklam istekleri M8.9'dan beri aynı (TFCD/TFUA gönderilmez, derece G) |
| Nötr yaş ekranı | YOK — eklenmez |
| 13 altına özel (child-directed) reklam mantığı | YOK — eklenmez |
| Families / karma kitle yeniden tasarımı | YOK |
| Google Mobile Ads / UMP | 24.9.0 / 3.2.0 aynen; TFAT geçişi teknik borç olarak duruyor (§2.1) |
| Oyun, ekonomi, reklam sıklığı, banner, ödüllü, geçiş zamanlaması, tutorial, günlük ödüller, ses, sanat, UI | DEĞİŞMEDİ |

**Hukuki not (korunur).** 13–15 ve 16–17 yaş grubundaki kullanıcılar bazı yargı
bölgelerinde hukuken çocuk / reşit olmayan sayılabilir. Bu karar ürünün
hedeflemesi ve Google Play hedef kitle beyanı hakkındadır; yerel rıza ya da
reklam işleme kurallarını **geçersiz kılmaz**. (EEA / Birleşik Krallık /
İsviçre rızası bugün UMP akışıyla işleniyor — PRIVACY_CONSENT; TFUA bu kararla
`true` ya da `false` yapılmadı.)

**Mağaza girişi kuralı.** Mağaza girişi, açıklamalar, grafikler ve pazarlama
Squishy Merge'i "çocuklar için" (*for kids*), "çocuk oyunu" (*children's
game*), "yürümeye başlayan çocuklar için" (*for toddlers*), "okul öncesi"
(*preschool*) gibi ifadelerle anlatmaz ve 13 yaş altı çocuklara bilerek
pazarlamaz. Kawaii / şeker / sevimli sanat kalır; varlıklar yalnız sevimli
oldukları için yeniden tasarlanmaz. §3'teki inceleme riski (Google: 13 altı
için tasarlanmamış bir uygulamanın girişi aksini düşündüren öğeler — çocuksu
animasyon, genç karakterler — içerirse uygulama reddedilebilir) owner'ın
bilgisinde; mağaza görsellerini owner mağaza varlıkları adımında seçer.

**Uydurulmayanlar.** Bu kaydın dışında Play Console cevabı verilmedi: "Hedef
kitle ve içerik" formundaki diğer sorular (varsa), IARC, Data safety, reklam
kimliği formu owner'ın konsolda cevaplayacağı maddeler
(ANDROID_RELEASE_CHECKLIST §2). Play Console'a hiçbir şey girilmedi.

## 1. Bugün kod ne gönderiyor (kod gerçeği, M9-01)

Tek kaynak: `addons/AdmobPlugin/android_export.cfg` → `[Audience]`
(`scripts/ads/ad_config.gd` okur, `scripts/ads/admob_backend.gd` eklentiye verir).

| ayar | bugünkü değer | nereye gider | etkisi |
|---|---|---|---|
| `decision` | `"general_13_plus"` (owner kararı, 2026-09-25; öncesi `""`) | yalnız release kapısı (+ `AdConfig.describe()` log satırı) | kitle engeli YOK, kapı raporunda bilgi notu. Boş olsaydı OWNER, karma / çocuk olsaydı CODE engeli |
| `tag_for_child_directed_treatment` (TFCD, COPPA) | `unspecified` | Mobile Ads `RequestConfiguration` | **gönderilmez** — Google'a hiçbir şey söylenmez |
| `tag_for_under_age_of_consent` (TFUA) | `unspecified` | `RequestConfiguration` + UMP `ConsentRequestParameters` | **gönderilmez** (eklenti yalnız UNSPECIFIED değilse ekler) |
| `max_ad_content_rating` | `G` | `RequestConfiguration` | yalnız "genel izleyici" reklamları (en muhafazakâr) |
| kişiselleştirme | SDK varsayılanı | — | EEA/UK/CH'de UMP rızasına göre; rıza yoksa sınırlı reklam |
| `AD_ID` izni | manifest'te VAR | Google Mobile Ads SDK + eklenti manifest birleştirmesi | reklam kimliği okunabilir |

Uygulanma sırası: eklenti `RequestConfiguration`'ı Mobile Ads SDK başlatması
**bittiğinde** (`initialization_completed`) kurar; bizim yönetici ilk reklam
yüklemesini ancak bu sinyalden SONRA yapar. Yani bugünkü değerler (G) her reklam
isteğinden önce etkin. Çocuğa yönelik / karma kitle seçilirse bu sıra
değişmeli (etiket SDK başlatmadan ÖNCE) — §4'teki ek işlerin parçası (ikisi de
seçilmedi, §0).

Hepsi `tools/release_config_test` ile kilitli: karar `general_13_plus`,
TFCD/TFUA `unspecified`, derece G; SDK'ya giden eşleme UNSPECIFIED /
UNSPECIFIED / G; kapıda kitle engeli yok, boş karar OWNER, karma / çocuk CODE.

## 2. Terimler — sade Türkçe

- **COPPA:** ABD'nin 13 yaş altı çocukların çevrimiçi verisini koruyan yasası.
- **TFCD** (`tagForChildDirectedTreatment`): reklam isteğine "bunu çocuğa
  yönelik içerik gibi işle" etiketi. `true` → ilgi alanına göre
  (kişiselleştirilmiş) reklam ve yeniden pazarlama KAPALI, reklam kimliği
  gönderilmez, çocuk için güvenli reklam kuralları. `false` → "çocuğa yönelik
  değil". `unspecified` → hiçbir şey söylenmez (bugünkü durum).
- **TFUA** (`tagForUnderAgeOfConsent`): AB/EEA, Birleşik Krallık ve İsviçre'de
  "bu kullanıcı dijital rıza yaşının altında" işareti. `true` →
  kişiselleştirilmiş reklam KAPALI, üçüncü taraf reklam satıcılarına istek
  KAPALI. TFCD ile ikisi birden true ise çocuk etiketi kazanır.
- **İçerik derecesi** (`maxAdContentRating`): G (genel, aileler dahil) · PG
  (ebeveyn rehberliğiyle) · T (gençler ve üstü) · MA (yetişkin).
- Google, Mobile Ads SDK **25.3.0**'da (2026-05-21) bu iki etiketi tek
  `setAgeRestrictedTreatment()` (CHILD / TEEN / UNSPECIFIED) altında topladı ve
  eskileri kullanımdan kaldırdı. Bu projenin SDK'sı **24.9.0** (eklenti v6.0'a
  bağlı), dolayısıyla eski iki etiket hâlâ doğru araç. Güncel durum ve teknik
  borç notu: §2.1.

### 2.1 Güncel Google durumu (Eylül 2026, M9-01.1 düzeltmesi)

- **TFCD ve TFUA kullanımdan kaldırıldı (deprecated).** Yerine geçen:
  **TFAT — Tag for Age Treatment**, API'si `setAgeRestrictedTreatment()`
  (`AgeRestrictedTreatment.CHILD` / `TEEN` / `UNSPECIFIED`); Google Mobile Ads
  SDK (Legacy) reklam isteğine `tfat` parametresini ekliyor
  (developers.google.com/admob/android/targeting, son güncelleme 2026-09-21).
- TFAT **GMA legacy 25.3.0** ile geldi. Bu proje **GMA 24.9.0**'da kalıyor,
  çünkü Godot 4.6 uyumlu eklenti (godot-admob v6.0) o sürüme sabit; 24.x hattı
  **2027-06-30'a kadar destekleniyor** (deprecation sayfası).
- Sonuç: TFAT'a geçiş bu kapalı test milestone'u için **kendiliğinden bir engel
  DEĞİL** — 24.9.0'da TFCD/TFUA hâlâ çalışan araçlar. Ama **belgelenmiş bir
  modernizasyon maddesi**: SDK 25.3.0+ (ya da Google'ın bugün tercih ettiği
  **GMA Next-Gen SDK**) eklentinin güncellenmesini gerektiriyor; o gün
  `[Audience]` değerleri TFAT'a eşlenecek. Bu teknik borç sessizce kapatılmadı;
  M9-01.1 cihaz kapısında GMA / Next-Gen geçişi **YAPILMADI**.
- **13+ kararından sonra (2026-09-25):** borç aynen duruyor; karar GMA / UMP'yi,
  TFCD / TFUA'yı ve bu geçişi DEĞİŞTİRMEDİ. Google'ın hedefleme sayfası (son
  güncelleme 2026-09-24) TFAT'taki `TEEN` değerinin eski TFCD / TFUA'da
  karşılığı olmadığını söylüyor — 24.9.0'da "genç kullanıcı" işlemi ifade
  edilemiyor. Kitle 13–15 ve 16–17'yi kapsadığı için (§0 hukuki not) TFAT
  geçişinde `[Audience]` eşlemesi ve `TEEN`'in gerekip gerekmediği o
  milestone'da owner ile değerlendirilir; bugün TFAT değeri seçilmedi.

## 3. Play Console "Hedef kitle ve içerik" ile ilişki

Play Console'da uygulamanın hedef yaş grupları seçilir (5 ve altı, 6–8, 9–12,
13–15, 16–17, 18+). **13 yaş altı herhangi bir grup seçilirse Google Play
Aileler (Families) politikası uygulanır.** AdMob, Families kendinden
sertifikalı reklam SDK'ları arasında (play-services-ads 19.0.0+).

| seçim | Play beyanı | kod tarafında ne gerekir |
|---|---|---|
| **A · yalnız 13+** (`general_13_plus`) — **SEÇİLDİ (owner, 2026-09-25)** | 13 altı grup seçilmez (seçilen: 13–15, 16–17, 18+) | Families uygulanmaz. TFCD/TFUA değerleri owner'ın (çoğunlukla `false` ya da `unspecified`; karar bunları değiştirmedi — ikisi de `unspecified`). **Ek kod YOK** — kapı bu kararı hemen kabul eder. |
| **B · karma** (`mixed_audience`) | 13 altı + üstü | Families. Nötr **yaş ekranı** zorunlu; çocuk (ya da yaşı bilinmeyen) kullanıcıya yalnız TFCD=true etiketli, sertifikalı reklam; bu kullanıcılardan reklam kimliği gönderilmez; en yüksek derece G. **Kodda YOK** → kapı CODE engeli verir. |
| **C · yalnız çocuklar** (`child_directed`) | yalnız 13 altı | Families. HER istekte TFCD=true, reklam kimliği yok (API 33+ için **AD_ID izni manifest'ten çıkarılmalı**), kişiselleştirilmiş/yeniden pazarlama yok, açılışta geçiş reklamı yok, akışı kesen reklam 5 sn sonra kapatılabilir olmalı. **Kodda YOK** → kapı CODE engeli verir. |

**A seçeneğinin gerçek riski:** Families uygulanmasa da Google mağaza girişini
inceler; grafik varlıklarda "genç karakterler / çocuksu animasyon" gibi
öğeler varsa uygulama "çocuklara da hitap ediyor" sayılıp reddedilebilir ya da
ek soru gelebilir. Önerilen çözüm ya bu öğeleri mağaza girişinden çıkarmak ya
da 13 altı grupları ekleyip Families kurallarını kabul etmek. Squishy Merge'in
sevimli dumpling karakterleri bu açıdan **gerçek bir risk** — owner kararı
bunu da hesaba katmalı. **Owner kararı (2026-09-25, §0):** kawaii / sevimli
sanat kalır, yalnız sevimli olduğu için yeniden tasarlanmaz; mağaza girişi ve
pazarlama 13 yaş altına hitap etmez. İnceleme riski ortadan kalkmadı; bir ret
ya da ek soru gelirse değerlendirme owner'ındır.

## 4. Seçimlerin sonuçları

| | A · 13+ (**seçildi**) | B · karma | C · çocuk |
|---|---|---|---|
| Play Families politikası | yok | VAR | VAR |
| Kişiselleştirilmiş reklam (EEA dışı) | var (rızaya bağlı) | çocuğa yok | yok |
| Reklam geliri beklentisi | en yüksek | orta | en düşük |
| Yaş ekranı | yok | ZORUNLU (yeni UI) | yok |
| AD_ID izni | kalır | kalır (çocuktan kimlik gönderilmez) | ÇIKARILIR |
| TFCD | owner (false / unspecified) | çocuk için true | her zaman true |
| RequestConfiguration sırası | bugünkü yeterli | SDK başlatmadan ÖNCE olmalı | SDK başlatmadan ÖNCE olmalı |
| Mağaza "çocuklara hitap" incelemesi | risk (kawaii sanat) | beklenen | beklenen |
| Bu milestone'dan sonra kod işi | yok | yaş ekranı + istek başına TFCD + sıra | TFCD her yerde + AD_ID çıkarma + sıra + interstitial kuralı denetimi |

## 5. Owner'dan istenen TAM karar

1. **Play Console hedef yaş grupları** — A (yalnız 13+), B (13 altı dahil
   karma) ya da C (yalnız 13 altı)?
2. Buna karşılık `android_export.cfg [Audience] decision` =
   `general_13_plus` · `mixed_audience` · `child_directed`.
3. **TFCD** (`tag_for_child_directed_treatment`): `true` / `false` /
   `unspecified`; **TFUA** (`tag_for_under_age_of_consent`): `true` / `false` /
   `unspecified`; **içerik derecesi**: G (bugün) / PG / T.
4. B ya da C seçilirse: yaş ekranı, AD_ID kaldırma ve SDK başlatma sırası için
   ayrı bir uygulama milestone'u onayı (kapı o zamana kadar CODE engeli verir).
5. A seçilirse: mağaza görsellerinin "çocuklara hitap" riski için owner'ın
   değerlendirmesi (hangi görseller mağaza girişine konacak).

**Cevap (owner, 2026-09-25 — ayrıntı §0):**

1. **A** — Play hedef yaş grupları 13–15, 16–17, 18+; 5 ve altı, 6–8, 9–12
   seçilmez.
2. `decision = general_13_plus`.
3. Bu kararla DEĞİŞTİRİLMEDİ: TFCD `unspecified`, TFUA `unspecified`, derece
   G (reklam istekleri aynı). İleride değiştirmek ayrı bir owner kararıdır.
4. Uygulanmaz — B/C seçilmedi; yaş ekranı, AD_ID kaldırma ya da SDK başlatma
   sırası işi yok.
5. Kawaii sanat kalır; mağaza girişi ve pazarlama 13 altına hitap etmez (§0
   mağaza girişi kuralı); mağaza görsellerini owner seçer.

Karar kaydı: bu doküman §0 + `android_export.cfg [Audience]` (`task/039`).
Play Console "Hedef kitle ve içerik" formu owner'ın — hesap açılınca §0'daki
yaş gruplarıyla doldurulur. Kapı (`tools/release/release_readiness.gd`) karar
yokken OWNER, B/C'de CODE engeli verir; A'da bu engel kalkar (2026-09-25'te
kalktı; A kararı rapora bilgi notu olarak düşer).

## 6. Karardan sonra da değişmeyenler (2026-09-25)

- Reklam istekleri: TFCD/TFUA gönderilmez, derece G (M8.9 davranışı; 13+
  kararı değiştirmedi).
- Play'e yüklenebilir AAB üretilmez — kitle engeli kalktı ama release kapısı
  kalan owner maddeleri (gerçek AdMob kimlikleri, gizlilik politikası URL'i,
  upload anahtarı) yüzünden BLOCKED.
- Debug/test build'ler yalnız Google test reklamı gösterir (canlı birim imkânsız).

## 7. Kaynaklar (2026-09-22)

- AdMob hedefleme / TFCD / TFUA / içerik derecesi:
  developers.google.com/admob/android/targeting ·
  developers.google.com/admob/android/reference/com/google/android/gms/ads/RequestConfiguration ·
  support.google.com/admob/answer/6219315 · support.google.com/admob/answer/6223431
- Google Play Families ve hedef kitle: support.google.com/googleplay/android-developer/answer/9893335 ·
  …/answer/12955712 · …/answer/9867159
- AD_ID izni: support.google.com/googleplay/android-developer/answer/6048248 ·
  developer.android.com/about/versions/13/behavior-changes-13
- SDK sürümleri: developers.google.com/admob/android/rel-notes
- Karar kaydı için 2026-09-25'te yeniden okundu:
  support.google.com/googleplay/android-developer/answer/9867159 (hedef yaş
  grupları; 13 altı herhangi bir grup → Families şartları; 13 altı için
  tasarlanmamış uygulamanın girişinde çocuksu pazarlama öğeleri → ret riski) ·
  developers.google.com/admob/android/targeting (son güncelleme 2026-09-24:
  TFCD/TFUA kullanımdan kalktı → `setAgeRestrictedTreatment`; `TEEN`'in eski
  etiketlerde karşılığı yok)
