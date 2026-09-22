# AUDIENCE_DECISION.md — Hedef kitle, COPPA (TFCD) ve TFUA kararı (M9-01)

> **Durum: OWNER KARARI BEKLİYOR.** Kod bu kararı TAHMİN ETMEDİ. Sevimli /
> kawaii sanat tek başına "çocuklara yönelik" ya da "13+" demek için yeterli
> değildir. Karar verilene kadar reklam istekleri M8.9'daki değerlerle gider ve
> release kapısı **Play'e yüklenebilir AAB üretmeyi reddeder**.
>
> Bu doküman hukuki tavsiye değildir. Google'ın resmî sayfalarının
> (2026-09-22'de okundu) sade Türkçe özetidir; son karar owner'ındır.
> Kaynaklar §7'de.

## 1. Bugün kod ne gönderiyor (kod gerçeği, M9-01)

Tek kaynak: `addons/AdmobPlugin/android_export.cfg` → `[Audience]`
(`scripts/ads/ad_config.gd` okur, `scripts/ads/admob_backend.gd` eklentiye verir).

| ayar | bugünkü değer | nereye gider | etkisi |
|---|---|---|---|
| `decision` | `""` (karar yok) | yalnız release kapısı | release export'u REDDEDİLİR |
| `tag_for_child_directed_treatment` (TFCD, COPPA) | `unspecified` | Mobile Ads `RequestConfiguration` | **gönderilmez** — Google'a hiçbir şey söylenmez |
| `tag_for_under_age_of_consent` (TFUA) | `unspecified` | `RequestConfiguration` + UMP `ConsentRequestParameters` | **gönderilmez** (eklenti yalnız UNSPECIFIED değilse ekler) |
| `max_ad_content_rating` | `G` | `RequestConfiguration` | yalnız "genel izleyici" reklamları (en muhafazakâr) |
| kişiselleştirme | SDK varsayılanı | — | EEA/UK/CH'de UMP rızasına göre; rıza yoksa sınırlı reklam |
| `AD_ID` izni | manifest'te VAR | Google Mobile Ads SDK + eklenti manifest birleştirmesi | reklam kimliği okunabilir |

Uygulanma sırası: eklenti `RequestConfiguration`'ı Mobile Ads SDK başlatması
**bittiğinde** (`initialization_completed`) kurar; bizim yönetici ilk reklam
yüklemesini ancak bu sinyalden SONRA yapar. Yani bugünkü değerler (G) her reklam
isteğinden önce etkin. Çocuğa yönelik / karma kitle seçilirse bu sıra
değişmeli (etiket SDK başlatmadan ÖNCE) — §4'teki ek işlerin parçası.

Hepsi `tools/release_config_test` ile kilitli ("bugün: karar YOK, TFCD/TFUA
unspecified, derece G").

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
  bağlı), dolayısıyla eski iki etiket hâlâ doğru araç.

## 3. Play Console "Hedef kitle ve içerik" ile ilişki

Play Console'da uygulamanın hedef yaş grupları seçilir (5 ve altı, 6–8, 9–12,
13–15, 16–17, 18+). **13 yaş altı herhangi bir grup seçilirse Google Play
Aileler (Families) politikası uygulanır.** AdMob, Families kendinden
sertifikalı reklam SDK'ları arasında (play-services-ads 19.0.0+).

| seçim | Play beyanı | kod tarafında ne gerekir |
|---|---|---|
| **A · yalnız 13+** (`general_13_plus`) | 13 altı grup seçilmez | Families uygulanmaz. TFCD/TFUA değerleri owner'ın (çoğunlukla `false` ya da `unspecified`). **Ek kod YOK** — kapı bu kararı hemen kabul eder. |
| **B · karma** (`mixed_audience`) | 13 altı + üstü | Families. Nötr **yaş ekranı** zorunlu; çocuk (ya da yaşı bilinmeyen) kullanıcıya yalnız TFCD=true etiketli, sertifikalı reklam; bu kullanıcılardan reklam kimliği gönderilmez; en yüksek derece G. **Kodda YOK** → kapı CODE engeli verir. |
| **C · yalnız çocuklar** (`child_directed`) | yalnız 13 altı | Families. HER istekte TFCD=true, reklam kimliği yok (API 33+ için **AD_ID izni manifest'ten çıkarılmalı**), kişiselleştirilmiş/yeniden pazarlama yok, açılışta geçiş reklamı yok, akışı kesen reklam 5 sn sonra kapatılabilir olmalı. **Kodda YOK** → kapı CODE engeli verir. |

**A seçeneğinin gerçek riski:** Families uygulanmasa da Google mağaza girişini
inceler; grafik varlıklarda "genç karakterler / çocuksu animasyon" gibi
öğeler varsa uygulama "çocuklara da hitap ediyor" sayılıp reddedilebilir ya da
ek soru gelebilir. Önerilen çözüm ya bu öğeleri mağaza girişinden çıkarmak ya
da 13 altı grupları ekleyip Families kurallarını kabul etmek. Squishy Merge'in
sevimli dumpling karakterleri bu açıdan **gerçek bir risk** — owner kararı
bunu da hesaba katmalı.

## 4. Seçimlerin sonuçları

| | A · 13+ | B · karma | C · çocuk |
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

Karar kaydı: Play Console formu + `android_export.cfg [Audience]` (dört
alan) aynı commit'te. Kapı (`tools/release/release_readiness.gd`) karar yokken
OWNER, B/C'de CODE engeli verir; A'da bu engel kalkar.

## 6. Owner kararına kadar değişmeyenler

- Reklam istekleri: TFCD/TFUA gönderilmez, derece G (M8.9 davranışı, tahmin yok).
- Play'e yüklenebilir AAB üretilmez (release kapısı).
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
