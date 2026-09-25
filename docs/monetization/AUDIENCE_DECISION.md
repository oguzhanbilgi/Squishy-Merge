# AUDIENCE_DECISION.md — Hedef kitle, COPPA (TFCD) ve TFUA kararı (M9-01)

> **Durum (2026-09-25, `task/039`, politika düzeltmesiyle):**
>
> - **Ürün kitlesi kararı: KAPALI (owner, FİNAL).** Squishy Merge **13+ genel
>   kitleye yönelik** bir casual oyundur; **13 yaş altı çocuklar için
>   tasarlanmadı ve onlara pazarlanmaz.** Karar kaydı §0. Kodda §3'teki **A
>   seçeneği** (`general_13_plus`): ek kod yok, reklam istekleri değişmedi,
>   kapının genel "kitle kararı yok" engeli kalktı.
> - **13–17 genç reklam işlemi / yargı bölgesi uyumu: ÜRETİM YAYININDAN ÖNCE
>   AÇIK** (§2.2). 13–15 ve 16–17 bazı yerlerde çocuk sayılabilir; GMA 24.9.0
>   TFAT `TEEN` gönderemez ve `unspecified` TEEN demek değil. Release kapısında
>   ayrı bir OWNER / uyum engeli ("UYUM:"); stratejiler A–D belgelendi,
>   hiçbiri seçilmedi.
>
> Karardan önceki durum (2026-09-22): kod kararı tahmin etmedi; sevimli / kawaii
> sanat tek başına "çocuklara yönelik" ya da "13+" demek için yeterli sayılmadı.
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
| Google Play Families politikası | 13 altı grup seçilmedi — ama bu "Families hiçbir yerde uygulanmaz" demek **DEĞİL**: Google'a göre 13–15 ve 16–17 bazı yerlerde çocuk sayılabilir; dağıtılan bölgelere göre Families / çocuk gizliliği / reklam yükümlülükleri değerlendirilmeli (hukuki not, §2.2) |
| `android_export.cfg [Audience] decision` | **`general_13_plus`** |
| TFCD / TFUA / en yüksek reklam derecesi | bu kararla **DEĞİŞTİRİLMEDİ**: `unspecified` / `unspecified` / `G` — reklam istekleri M8.9'dan beri aynı (TFCD/TFUA gönderilmez, derece G). Bunlar **TEEN işlemi DEĞİLDİR** ve 13–17 için uyumu kanıtlamaz (§2.2) |
| 13–17 genç reklam işlemi / yargı bölgesi uyumu | **AÇIK — üretim yayınından önce çözülmeli** (§2.2; kapıda ayrı OWNER "UYUM:" engeli). Stratejiler A–D belgelendi, hiçbiri seçilmedi |
| Nötr yaş ekranı | YOK — bu görevde eklenmez (§2.2 B stratejisi ileride bir yaş / yaş bandı düzeneği getirebilir; yalnız owner kararıyla) |
| 13 altına özel (child-directed) reklam mantığı | YOK — eklenmez |
| Families / karma kitle yeniden tasarımı | YOK |
| Google Mobile Ads / UMP | 24.9.0 / 3.2.0 aynen — task/039'da SDK geçişi YOK. 24.9.0 TFAT `TEEN` gönderemez (§2.1) → 13–17 stratejisi AÇIK (§2.2) |
| Oyun, ekonomi, reklam sıklığı, banner, ödüllü, geçiş zamanlaması, tutorial, günlük ödüller, ses, sanat, UI | DEĞİŞMEDİ |

**Hukuki not (düzeltildi, 2026-09-25).** Google'ın hedef kitle sayfası 13–15 ve
16–17 grupları için aynı uyarıyı yapıyor: bu yaş grubu bazı yerlerde çocukları
kapsıyor sayılabilir. Uygulama 21 yaş altındaki kullanıcıları hedefliyorsa
geliştirici, onların yerel hukukta çocuk sayılıp sayılmadığını değerlendirmek
zorunda; çocukları hedefleyen uygulamalar Families şartlarına uymalı. Bu yüzden
"13+ ⇒ Families uygulanmaz" **denemez**. Ürün konumu (13 altı için tasarlanmadı
ve pazarlanmaz; 5 ve altı / 6–8 / 9–12 seçilmez) bir şey, dağıtılan bölgelerdeki
Families / çocuk gizliliği / reklam yükümlülükleri ayrı bir değerlendirme. Bu
karar ürün hedeflemesi ve Play hedef kitle beyanıdır; yerel rıza ya da reklam
işleme kurallarını **geçersiz kılmaz** ve reklam tarafında uyumu **kanıtlamaz**
(§2.2). Bugünkü UMP rıza akışı TFUA `unspecified` ile çalışır — yaşa özel işlem
uygulamaz; TFUA bu kararla `true` ya da `false` yapılmadı. *İlk task/039
kaydındaki (`4d3268c`) "Families uygulanmaz" ifadesi bu notla düzeltildi.*

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
| `decision` | `"general_13_plus"` (owner kararı, 2026-09-25; öncesi `""`) | yalnız release kapısı (+ `AdConfig.describe()` log satırı) | genel "kitle kararı yok" engeli YOK, kapı raporunda bilgi notu; 13–17 için ayrı OWNER "UYUM:" engeli (§2.2). Boş olsaydı OWNER, karma / çocuk olsaydı CODE engeli |
| `tag_for_child_directed_treatment` (TFCD, COPPA) | `unspecified` | Mobile Ads `RequestConfiguration` | **gönderilmez** — Google'a hiçbir şey söylenmez (TEEN işlemi DEĞİL) |
| `tag_for_under_age_of_consent` (TFUA) | `unspecified` | `RequestConfiguration` + UMP `ConsentRequestParameters` | **gönderilmez** (eklenti yalnız UNSPECIFIED değilse ekler; TEEN işlemi DEĞİL) |
| `max_ad_content_rating` | `G` | `RequestConfiguration` | yalnız "genel izleyici" reklamları (en muhafazakâr) |
| kişiselleştirme | SDK varsayılanı | — | EEA/UK/CH'de UMP rızasına göre; rıza yoksa sınırlı reklam |
| `AD_ID` izni | manifest'te VAR | Google Mobile Ads SDK + eklenti manifest birleştirmesi | reklam kimliği okunabilir |

Uygulanma sırası: eklenti `RequestConfiguration`'ı Mobile Ads SDK başlatması
**bittiğinde** (`initialization_completed`) kurar; bizim yönetici ilk reklam
yüklemesini ancak bu sinyalden SONRA yapar. Yani bugünkü değerler (G) her reklam
isteğinden önce etkin. Çocuğa yönelik / karma kitle seçilirse bu sıra
değişmeli (etiket SDK başlatmadan ÖNCE) — §4'teki ek işlerin parçası (ikisi de
seçilmedi, §0). §2.2'deki genç reklam işlemi stratejileri de bu sırayı
etkileyebilir.

Hepsi `tools/release_config_test` ile kilitli: karar `general_13_plus`,
TFCD/TFUA `unspecified`, derece G; SDK'ya giden eşleme UNSPECIFIED /
UNSPECIFIED / G; 24.9.0 yolunda TEEN yok; kapıda genel kitle engeli yok ama
ayrı 13–17 UYUM engeli var — hiçbir etiket değeri (unspecified, false, true ya
da derece T) onu kaldırmaz; boş karar OWNER, karma / çocuk CODE.

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
  (ebeveyn rehberliğiyle) · T (gençler ve üstü) · MA (yetişkin). Derece T bir
  İÇERİK derecesidir; TFAT `TEEN` (genç kullanıcı işlemi) ile aynı şey DEĞİL.
- Google, Mobile Ads SDK **25.3.0**'da (2026-05-21) bu iki etiketi tek
  `setAgeRestrictedTreatment()` (CHILD / TEEN / UNSPECIFIED) altında topladı ve
  eskileri kullanımdan kaldırdı. Bu projenin SDK'sı **24.9.0** (eklenti v6.0'a
  bağlı), dolayısıyla eski iki etiket hâlâ çalışan araç — ama genç (`TEEN`)
  işlemini ifade edemezler. Güncel durum: §2.1; 13–17 uyumu: §2.2.

### 2.1 Güncel Google durumu (Eylül 2026, M9-01.1 düzeltmesi; 2026-09-25 düzeltmesi)

- **TFCD ve TFUA kullanımdan kaldırıldı (deprecated).** Yerine geçen:
  **TFAT — Tag for Age Treatment**, API'si `setAgeRestrictedTreatment()`
  (`AgeRestrictedTreatment.CHILD` / `TEEN` / `UNSPECIFIED`); Google Mobile Ads
  SDK (Legacy) reklam isteğine `tfat` parametresini ekliyor
  (developers.google.com/admob/android/targeting, son güncelleme 2026-09-21).
- TFAT **GMA legacy 25.3.0** ile geldi. Bu proje **GMA 24.9.0**'da kalıyor,
  çünkü Godot 4.6 uyumlu eklenti (godot-admob v6.0) o sürüme sabit; 24.x hattı
  **2027-06-30'a kadar destekleniyor** (deprecation sayfası).
- M9-01.1 sonucu (2026-09-23, **2026-09-25'te düzeltildi**): "TFAT'a geçiş bu
  kapalı test milestone'u için kendiliğinden bir engel değil; belgelenmiş bir
  modernizasyon maddesi". SDK tarafı için doğru kalan kısım: SDK 25.3.0+ (ya
  da Google'ın bugün tercih ettiği **GMA Next-Gen SDK**) eklentinin
  güncellenmesini gerektiriyor ve bu geçiş **YAPILMADI** — ne M9-01.1'de ne
  task/039'da. Düzeltilen kısım: 13–17'yi hedefleyen bir kitlede konu yalnız
  sonraki teknik borç **DEĞİL** — aşağıdaki iki madde ve §2.2.
- **24.9.0 TFAT `TEEN` gönderemez.** Google'ın hedefleme sayfası (son güncelleme
  2026-09-24) `TEEN`'in eski TFCD / TFUA'da karşılığı olmadığını söylüyor.
  Bugünkü `unspecified` değerleri "özel işlem yok" demektir — **TEEN demek
  DEĞİL**; derece G ya da T de genç işlemi değildir. Bu değerlerden 13–17 için
  uyum sessizce çıkarılmaz ya da iddia edilmez.
- **13–17 genç reklam işlemi stratejisi AÇIK bir release-uyum kararıdır** —
  üretim yayınından önce çözülmeli (§2.2). SDK geçişinin kendisi ancak seçilen
  strateji gerektirirse iş olur. *İlk task/039 kaydındaki "değerlendirme TFAT
  geçişinde / teknik borç" ifadesi bu maddeyle düzeltildi.*

### 2.2 13–17 genç reklam işlemi / yargı bölgesi uyumu — AÇIK (üretim yayınından önce)

**Durum:** ürün kitlesi kararından (§0, KAPALI) **AYRI**, **AÇIK** bir owner /
uyum kararı. Release kapısında ayrı OWNER engeli ("UYUM: 13–17 genç reklam
işlemi / yargı bölgesi uyum stratejisi çözülmedi …"); kapı bu engel açıkken
yüklenebilir AAB (kapalı test yüklemesi dahil) üretmez. CODE engeli DEĞİL:
uygulama, seçilecek stratejiye bağlı.

Neden açık:

- Hedef yaş grupları 13–15 ve 16–17'yi içeriyor; Google bu grupların bazı
  yerlerde çocuk sayılabileceğini söylüyor (§0 hukuki not).
- GMA 24.9.0 TFAT `TEEN` gönderemez; `TEEN`'in eski TFCD / TFUA'da karşılığı yok.
- Bugünkü `unspecified` / `unspecified` / G değerleri TEEN işlemi değildir;
  uyum bu değerlerden sessizce iddia edilmez.

Olası stratejiler — **belgelendi, HİÇBİRİ SEÇİLMEDİ, HİÇBİRİ UYGULANMADI**
(§3'teki A/B/C ürün kitlesi seçeneklerinden ayrı):

| strateji | ne demek | ne gerektirir |
|---|---|---|
| **A** | 13+ hedef kalır; TFAT `TEEN` gönderebilen bir GMA / eklenti yoluna geçilir; `TEEN` işlemi muhtemelen muhafazakâr biçimde kullanılır | GMA 25.3.0+ (ya da Next-Gen) + Godot eklentisinin güncellenmesi / yamalanması; kod milestone'u |
| **B** | 13+ hedef kalır; bir yaş / yaş bandı düzeneği eklenir: 13–17 genç işlemi alır, yetişkinler yetişkin işlemini korur | yeni UI + yaş bilgisinin işlenmesi + genç işleminin reklam isteğinde nasıl ifade edileceği (24.9.0'da `TEEN` yok); kod milestone'u |
| **C** | Owner açıkça başka bir konumlandırma seçerse beyan edilen ürün kitlesi ileride değiştirilir | yeni owner kararı (§0 ürün kararı bugün KAPALI; bu görevde yeniden açılmadı) |
| **D** | Hukuki olarak incelenmiş bir strateji, gerçek yayın bölgeleri için bugünkü UNSPECIFIED işleminin yeterli olduğuna karar verir | hukuki inceleme + yayın bölgeleri listesi + kayıt; kod gerekmeyebilir |

task/039'da yapılmayanlar: yaş ekranı YOK, GMA yükseltmesi YOK, reklam
davranışı değişikliği YOK. Strateji seçilince ayrı bir görevde uygulanır ve kapı
ona göre güncellenir (A/B için kod; D için kayıt). Bugün engel yapılandırmayla
kapanmaz: `ReleaseReadiness.project_inputs` → `teen_ad_treatment_resolved =
false`.

## 3. Play Console "Hedef kitle ve içerik" ile ilişki

Play Console'da uygulamanın hedef yaş grupları seçilir (5 ve altı, 6–8, 9–12,
13–15, 16–17, 18+). **Hedef kitlesinde çocuk olan her uygulama Google Play
Aileler (Families) şartlarına uymalı.** 13 yaş altı bir grup seçmek çocuğu
hedef kitleye açıkça koyar; ama Google 13–15 ve 16–17 gruplarının da bazı
yerlerde çocuk sayılabileceğini ve 21 yaş altını hedefleyen uygulamada yerel
hukukun değerlendirilmesi gerektiğini söylüyor — yani yalnız 13+ grupları
seçmek Families'i her yerde dışarıda **bırakmaz** (§0 hukuki not, §2.2). AdMob,
Families kendinden sertifikalı reklam SDK'ları arasında (play-services-ads 19.0.0+).

| seçim | Play beyanı | kod tarafında ne gerekir |
|---|---|---|
| **A · yalnız 13+** (`general_13_plus`) — **SEÇİLDİ (owner, 2026-09-25)** | 13 altı grup seçilmez (seçilen: 13–15, 16–17, 18+) | 13 altı gruplar Families'i tetiklemez; ama 13–15 / 16–17 bazı yerlerde çocuk sayılabilir → dağıtım bölgelerine göre Families / çocuk gizliliği / reklam yükümlülükleri değerlendirilir (§2.2, AÇIK). TFCD/TFUA değerleri owner'ın (çoğunlukla `false` ya da `unspecified`; karar bunları değiştirmedi — ikisi de `unspecified`, TEEN değil). **Ürün kararı için ek kod YOK** — kapı `general_13_plus`'ı kabul eder; 13–17 uyumu ayrı OWNER engeli. |
| **B · karma** (`mixed_audience`) | 13 altı + üstü | Families. Nötr **yaş ekranı** zorunlu; çocuk (ya da yaşı bilinmeyen) kullanıcıya yalnız TFCD=true etiketli, sertifikalı reklam; bu kullanıcılardan reklam kimliği gönderilmez; en yüksek derece G. **Kodda YOK** → kapı CODE engeli verir. |
| **C · yalnız çocuklar** (`child_directed`) | yalnız 13 altı | Families. HER istekte TFCD=true, reklam kimliği yok (API 33+ için **AD_ID izni manifest'ten çıkarılmalı**), kişiselleştirilmiş/yeniden pazarlama yok, açılışta geçiş reklamı yok, akışı kesen reklam 5 sn sonra kapatılabilir olmalı. **Kodda YOK** → kapı CODE engeli verir. |

**A seçeneğinin gerçek riski:** 13 altı grup seçilmese de Google mağaza girişini
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
| Play Families politikası | 13 altı gruplardan dolayı yok; 13–17 bazı yerlerde çocuk sayılabilir → bölgeye göre değerlendirilir (§2.2) | VAR | VAR |
| Kişiselleştirilmiş reklam (EEA dışı) | bugün var (rızaya bağlı); 13–17 için §2.2 AÇIK | çocuğa yok | yok |
| Reklam geliri beklentisi | en yüksek | orta | en düşük |
| Yaş ekranı | yok | ZORUNLU (yeni UI) | yok |
| AD_ID izni | kalır | kalır (çocuktan kimlik gönderilmez) | ÇIKARILIR |
| TFCD | owner (bugün unspecified — TEEN değil) | çocuk için true | her zaman true |
| RequestConfiguration sırası | ürün kararı için bugünkü yeterli; 13–17 stratejisine göre değişebilir (§2.2) | SDK başlatmadan ÖNCE olmalı | SDK başlatmadan ÖNCE olmalı |
| Mağaza "çocuklara hitap" incelemesi | risk (kawaii sanat) | beklenen | beklenen |
| Bu milestone'dan sonra kod işi | ürün kararı için yok; 13–17 stratejisi A/B seçilirse var (§2.2) | yaş ekranı + istek başına TFCD + sıra | TFCD her yerde + AD_ID çıkarma + sıra + interstitial kuralı denetimi |

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
   G (reklam istekleri aynı). Bu değerler TEEN işlemi değildir; 13–17 reklam
   işlemi §2.2'de AÇIK. İleride değiştirmek ayrı bir owner kararıdır.
4. Ürün kitlesi için uygulanmaz — B/C seçilmedi, bu yüzden ürün kararı yaş
   ekranı, AD_ID kaldırma ya da SDK başlatma sırası işi getirmedi. 13–17 uyum
   stratejisi (§2.2) ileride kod gerektirebilir (A: SDK yolu, B: yaş bandı) —
   seçilmedi.
5. Kawaii sanat kalır; mağaza girişi ve pazarlama 13 altına hitap etmez (§0
   mağaza girişi kuralı); mağaza görsellerini owner seçer.

Karar kaydı: bu doküman §0 + `android_export.cfg [Audience]` (`task/039`).
Play Console "Hedef kitle ve içerik" formu owner'ın — hesap açılınca §0'daki
yaş gruplarıyla doldurulur. Kapı (`tools/release/release_readiness.gd`) karar
yokken OWNER, B/C'de CODE engeli verir; A'da bu engel kalkar (2026-09-25'te
kalktı; A kararı rapora bilgi notu olarak düşer). Ondan bağımsız olarak 13–17
genç reklam işlemi için ayrı OWNER "UYUM:" engeli verir (§2.2).

## 6. Karardan sonra da değişmeyenler (2026-09-25)

- Reklam istekleri: TFCD/TFUA gönderilmez, derece G (M8.9 davranışı; 13+
  kararı değiştirmedi — bu TEEN işlemi değildir, §2.2).
- Play'e yüklenebilir AAB üretilmez — genel kitle engeli kalktı; release
  kapısı 13–17 uyum engeli (§2.2) ve kalan owner maddeleri (gerçek AdMob
  kimlikleri, gizlilik politikası URL'i, upload anahtarı) yüzünden BLOCKED.
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
- Karar kaydı ve düzeltmesi için 2026-09-25'te yeniden okundu:
  support.google.com/googleplay/android-developer/answer/9867159 (hedef yaş
  grupları; 13–15 ve 16–17 grupları bazı yerlerde çocukları kapsıyor
  sayılabilir; 21 yaş altını hedefleyen uygulama yerel hukuku değerlendirmeli;
  hedef kitlesinde çocuk olan uygulama → Families şartları; 13 altı için
  tasarlanmamış uygulamanın girişinde çocuksu pazarlama öğeleri → ret riski) ·
  developers.google.com/admob/android/targeting (son güncelleme 2026-09-24:
  TFCD/TFUA kullanımdan kalktı → `setAgeRestrictedTreatment`; `TEEN`'in eski
  etiketlerde karşılığı yok)
