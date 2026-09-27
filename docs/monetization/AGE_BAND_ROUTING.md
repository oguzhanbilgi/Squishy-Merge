# AGE_BAND_ROUTING.md — Nötr yaş ekranı + yaş bandı reklam yönlendirmesi (TASK/043)

> **Durum (2026-09-27):** kod + deterministik testler tamam; dal `task/043-age-band-routing`,
> main'e alınması owner onayı bekliyor. Samsung A36 cihaz kapısı: §11 (bu dosyanın sonu).
> Bu doküman hukuki tavsiye DEĞİLDİR; Google'ın resmî sayfalarının sade Türkçe özetine
> dayanır (kaynaklar §12, 2026-09-27'de okundu; sözcüğü sözcüğüne alıntılar yerel kanıtta
> `build/qa_043/research/`). Mimari evrensel bir hukuki garanti DEĞİLDİR — §9'daki açık
> uyum maddeleri owner / hukuk kararıdır.

## 0. Owner iş kararı (2026-09-27, TASK/043 brifi)

| konu | karar |
|---|---|
| Dağıtım | dünya geneli |
| Ürün kitlesi | 13+ (değişmedi — AUDIENCE_DECISION §0) |
| 13–17 | reklam ALABİLİR — TFAT **TEEN** + en yüksek reklam derecesi **T** |
| 18+ | olağan yetişkin yolu — TFAT **UNSPECIFIED** + en yüksek derece **MA** (yetişkin envanteri korunur) |
| 13 yaş altı | ürün onlara yönelik değil — reklam SDK'sı **başlamaz**, UMP **yok**, reklam **yok**, kısıt ekranı |
| Yaş bilinmiyor | reklam SDK'sı **başlamaz**, UMP **yok**, reklam **yok** (ASLA yetişkin yoluna düşmez) |
| Yaş kaynağı | uygulamanın kendi **nötr doğum tarihi ekranı** — Play Age Signals reklamda **ASLA** |
| Ham doğum tarihi | saklanmaz, loglanmaz, hiçbir yere gönderilmez |

## 1. Resmî araştırmanın kullandığı gerçekler (özet — hukuki sonuç DEĞİL)

- **Nötr yaş ekranı (Play, Hedef kitle ve içerik).** Kullanıcıyı yaşını yanlış söylemeye
  teşvik etmeyen bir yaş doğrulama; Google'ın örneği kullanıcının doğum tarihini
  "freely enter their month, day, and year of birth" biçiminde girmesi. Yanlış kurulum:
  doğum tarihini gereken yaşa ayarlı getirmek ya da belli bir yaşın gerektiğini söylemek.
- **13–15 / 16–17** bazı yerlerde çocuk sayılabilir; 21 yaş altını hedefleyen uygulama yerel
  hukukta çocuk sayılıp sayılmadıklarını değerlendirmeli; hedef kitlesinde çocuk olan
  uygulama Families şartlarına uyar. "Çocuk" tanımı yere göre değişir — hukuk danışmanı.
- **TFAT (AdMob).** TEEN: kişiselleştirilmiş reklam + yeniden pazarlama kapalı, gençler için
  reklam sunma korumaları. CHILD ayrıca üçüncü taraf reklam isteklerini kapatır ve reklam
  kimliğini (AAID) göndermez. UNSPECIFIED varsayılan; UNSPECIFIED rıza dizgelerini (TCF / GPP)
  geçersiz kılmaz. Yapılandırma SDK başlatılmadan ÖNCE ayarlanmalı. TEEN'in eski TFCD / TFUA'da
  karşılığı yok; ikisi birden ayarlanırsa en muhafazakâr işlem. Google: yaş işlemi için hukuk
  danışmanına danışın.
- **En yüksek reklam derecesi.** SDK değeri AdMob arayüzündekini geçersiz kılar; etiketler:
  G genel, PG ebeveyn rehberliği, T genç ve üstü, MA yalnız yetişkin (alkol, kumar, cinsel
  içerik, silah gibi konular). AdMob etiket ↔ Google Play derecesi tablosu: **G 3+ · PG 7+ ·
  T 12+ · MA 16+ / 18+**. Etiket seçmek kategori hariç tutmalarını ve yasal kısıtları
  değiştirmez.
- **Play "Uygunsuz reklamlar" politikası.** Uygulamadaki reklamlar **uygulamanın içerik
  derecesine** uygun olmalı (örnek: "Everyone" uygulamada Teen reklam uygunsuz). → §6.
- **UMP.** Rıza her açılışta güncellenir; reklam istemeden önce `canRequestAds()`. TFUA true →
  UMP rıza sormaz (karma kitlede çocuk kullanıcılar için önerilir); UMP TFUA'yı reklam
  isteklerine taşımaz — yaş işlemi ayrıca ayarlanmalı. **TEEN'in UMP'yi atladığına dair
  Google ifadesi YOK** → TEEN kullanıcılar da UMP'den geçer.
- **Play Age Signals.** Şartlar ve Play politikası reklam, pazarlama, kişiselleştirme,
  profilleme ve analitik kullanımını yasaklıyor; Google Play API'yi zorunlu tutmuyor.
- **Data safety.** "Toplama" = veriyi cihazdan göndermek; yalnız cihazda işlenen veri beyan
  edilmez. Doğum tarihi "Diğer kişisel bilgi" örneği. SDK'nın doğrudan üçüncü tarafa ilettiği
  veri "paylaşım".

## 2. Akış — nerede, ne zaman

```
yeni kurulum ──> tutorial (reklamsız) ──> tutorial kaynaklı Level 1 (reklamsız)
      └──> İLK güvenli kabuk (Harita / Ana Sayfa)  ──> NÖTR YAŞ EKRANI (zorunlu)
eski kayıt (onboarding tamam, yaş yok) ──> açılışta Ana Sayfa ──> NÖTR YAŞ EKRANI (zorunlu)

yaş ekranı ──> türetilmiş bant kaydedilir (tek yazma), ham tarih atılır
   UNDER_13 ──> kısıt ekranı (oyun durur; SDK / UMP / reklam YOK)
   TEEN     ──> rota TEEN + T ──┐
   ADULT    ──> rota UNSPECIFIED + MA ──┴─> attach ──> UMP (canRequestAds) ──> yapılandır +
                                             geri oku ──> MobileAds.initialize ──> yüklemeler
```

- **Yer (kesin):** `Main._maybe_request_age()` — yalnız reklam yöneticisi varken (Android +
  eklenti), `booted`, onboarding tamam, monetizasyon ertelenmemiş (`_monetization_deferred`
  false) ve board YOKKEN. Çağrı noktaları: açılışın sonu (eski kayıt → Ana Sayfa) ve
  `_show_tab()` (her kabuk geçişi, `_activate_monetization_if_safe()`'ten hemen sonra).
  Round ortasında, tutorial'da, sonuç ekranında ASLA. Tutorial kaynaklı round'un sonuç
  ekranından "Tekrar" ile yeni round'a geçen oyuncu kabuğu görene kadar reklamsız oynar (yaş
  kapısı kapalı; geçiş reklamı sebebi `age_gate`).
- **Günlük ödül sırası:** yaş bilinmiyorken (ve yaş / kısıt ekranı açıkken) GÜNLÜK ÖDÜLLER
  penceresi (reklamlı sandık / +150 Hamur girişleri var) otomatik de, madalyon / Mağaza
  kartından da AÇILMAZ; yaş çözülünce o gün görülmediyse açılır. Ücretsiz sandık, ilk gün
  kuralı, kotalar, +150 kuralı DEĞİŞMEDİ. Günlük giriş ödülü (+15, reklamsız) açılışta her
  zamanki gibi çözülür. Eski kayıtta yaş cevaplanınca pencere (o gün görülmediyse) hemen açılır
  — 13 altı dışındaki HER cevapta aynı (cevaba göre ödül farkı yok). İnceleme L2-F5 bunun
  "cevap ödülün anahtarı" gibi görünebileceğini not etti; pencereyi bir sonraki ekran
  değişimine ertelemek owner tercihi olarak açık.
- **Android geri:** zorunlu yaş ekranında ve kısıt ekranında = uygulamadan çıkış (pencere
  kapatılamaz; bir sonraki açılışta yine sorulur). Yeniden girişte = vazgeç / tamam.
- Reklam yöneticisi yoksa (masaüstü / eklentisiz) yaş sorulmaz — eski davranış.
- **Bozuk cihaz saati** (modelin geldiği `AgeGate.MODEL_START_DAY` = 2026-09-27'den önceyi
  gösteriyor): yaş o saatle sınıflandırılamaz → yaş ekranı AÇILMAZ, bant UNKNOWN kalır (reklam /
  UMP / SDK yok, günlük pencere kapalı), oyun açık; saat düzelince ilk güvenli kabukta sorulur.
  Panel açıkken saat bozulursa giriş aynı nötr hatayı alır. (Aksi hâlde saat doğum tarihinden
  önceyi gösterdiğinde her tarih "gelecek" olur ve zorunlu pencere oyunu kilitlerdi.)
- **Bilinçli seçim — yaş tutorial'dan SONRA:** brifin tercih ettiği sıra (ilk açılış
  sürtünmesi). Bedeli: 13 altındaki bir oyuncu soruyu oyunu sevdikten sonra görür, yanlış
  beyan motivasyonu daha yüksek olabilir (inceleme L2-F6). Kendi beyanlı yaş ekranı bunu
  engelleyemez; not olarak kayıtta.

## 3. Nötr yaş ekranı (UI) — `scenes/ui/age_gate_panel.tscn`

- `UiKit.modal_shell` (gövde içi başlık, **tepelik YOK** — taç + yıldız sanatı sonuç / ödül
  ekranlarının dili), katman 14 (Ayarlar 13 ve günlük pencere 12 üstünde). Başlık **"Doğum
  tarihin"**, istem **"Lütfen doğum tarihini gir."**
- Giriş: **Gün / Ay / Yıl** alanları (yer tutucu GG / AA / YYYY — **hazır tarih YOK**,
  varsayılan yaş YOK) + oyun içi rakam tuş takımı (1–9, 0, Sil, Temizle; tuş ≥ 64 px). İşletim
  sistemi klavyesi kullanılmaz. Kendiliğinden ilerleme: gün 2 hane ya da 4–9 → ay; ay 2 hane
  ya da 2–9 → yıl; alana dokunarak seçme. **Düzeltme:** dolu bir alana dokunmak onu baştan
  yazdırır; taşan rakam yalnız dolu OLMAYAN bir sonraki alana gider (alanlar hiçbir zaman
  2 / 2 / 4 haneyi aşmaz — ay "012" olamaz); Sil seçili alanın son hanesini siler. Etkin alan
  dolgu rengiyle VE yazı parlaklığıyla (koyu zeminde açık / açık zeminde koyu) ayrılır.
- **DEVAM** yalnız tarih tamken; geçersiz / gelecek / 120 yıldan eski tarih → AYNI nötr mesaj
  "Bu tarih geçerli değil. Lütfen kontrol et." (sebep ayırt edilmez; 20 px, krem zeminde
  ≥ 4.5:1 koyu turuncu).
- **Onay adımı HER tarihte:** "Girdiğin tarih — 23 Temmuz 2009 — Doğru mu?" + DÜZELT / ONAYLA
  (yazım hatasına karşı; yalnız bazı yaşlara onay göstermek eşiği ele verirdi). **DÜZELT girişi
  boşaltır** (tarih baştan girilir — dolu alanlarda sessizce yok sayılan rakam kalmaz).
- Nötrlük: eşik yaş (13 / 18), "18+", reklam, ödül, kilit açma, oyun parası, sandık, yıldız,
  konfeti, yetişkin seçimini gösteren ok YOK; test bunu görünen bütün metinlerde tarar.
- Gizlilik notu (ekranda): "Doğum tarihin bu cihazdan çıkmaz; yalnızca sana uygun ayarları
  seçmek için kullanılır." (Ham tarih için doğru; türetilmiş yaş işlemi / derece reklam
  isteğiyle Google'a gider — bunu Ayarlar'daki gizlilik metni söyler, nötr ekran "reklam"
  diyemez. İki metin de owner / hukuk incelemesinde — §9.7.)
- Kipler: **ZORUNLU** (X yok, karartma kapatmaz) · **YENİDEN GİRİŞ** (Ayarlar → Yaş bilgisi;
  X / Vazgeç / karartma kapatır; alanlar HER ZAMAN boş açılır — ham doğum tarihi saklanmaz,
  saklanan geçiş günü de gösterilmez).
- 720×1280 (en kısa tuval), 320 / 360 / 390 dp oranları (640×1422, 720×1600, 780×1688), A36
  (1080×2340) ve 540×960'ta pencere ekranda, tuşlar / alanlar / DEVAM panelde, gövde
  kaydırılmıyor (`age_gate_test`). Dil yalnız Türkçe; oyunda RTL yok.

## 4. Veri azaltma — kayıt biçimi (SaveManager, geriye uyumlu)

| anahtar | değerler | not |
|---|---|---|
| `age_ad_band` | `"UNKNOWN"` · `"UNDER_13"` · `"TEEN"` · `"ADULT"` | eski kayıtta yok → `UNKNOWN` |
| `next_age_transition_date` | `"YYYY-MM-DD"` ya da `""` | UNDER_13 → 13. yaş günü · TEEN → 18. yaş günü · ADULT / UNKNOWN → boş |

- Ham doğum tarihi **saklanmaz**: panel rakamları yalnız bellekte tutar, onay / vazgeç /
  kapanışta siler; dışarı yalnız `resolved(band, transition)` çıkar. `SaveManager.store_age_band`
  doğum tarihi parametresi almaz. Başka anahtar eklenmedi, ilgisiz veri taşınmadı.
- **Dürüst not:** UNDER_13 / TEEN için saklanan geçiş günü doğum gününden türetilir (13. / 18.
  yıl dönümü) ve o bantta doğum tarihine matematiksel olarak eşdeğerdir (geçiş − 13 / 18 yıl).
  Yalnız bu cihazda, oyuncunun kayıt dosyasında durur; ADULT olunca silinir. Ayarlar'daki
  gizlilik metni bunu açıkça söyler: "Doğum tarihin saklanmaz; cihazda yalnızca yaş grubun ve
  bir sonraki gruba geçiş günün (doğum günün) tutulur; reklam isteğine yalnızca yaş grubuna uygun
  ayar eklenir." (640 px tavanlı pencerede de tek bakışta okunacak uzunlukta —
  `secondary_modal_ui_test`.)
- "Yalnız bu cihazda": release preset'lerinde `user_data_backup/allow=false` (Google otomatik
  yedeği kapalı) — kapı artık bunu CONFIG olarak denetler (§10). Android 12+ cihazdan cihaza
  aktarım (kullanıcının başlattığı taşıma) `allowBackup` ile kapanmaz; bu tüm kayıt için
  (ilerleme dahil, TASK/043'ten önce de) geçerli bir artık risk — §9.9.
- Kayıt silme / sıfırlama yok: UNDER_13 dahil ilerleme SİLİNMEZ.

## 5. Yaş hesabı + geçişler (`scripts/game/age_gate.gd` — saf, autoload'a dokunmaz)

- Tarih-yalnız takvim yaşı; "gün / 365" YOK. Yıl dönümü günü yaş dolar: **tam 13. yaş günü
  TEEN, tam 18. yaş günü ADULT**, bir gün öncesi alttaki bant. 29 Şubat doğumlular artık
  olmayan yıllarda **1 Mart**'ta yaş doldurur (koruyucu yön). Gün numarası tamsayı (proleptik
  Gregoryen), saat dilimi / işletim sistemi saatinden bağımsız.
- **Soğuk açılış (SDK'dan ÖNCE):** `SaveManager.resolve_age_band_at_launch(AgeGate.today())`
  — TEEN ve bugün ≥ 18. yaş günü → ADULT (geçiş temizlenir); UNDER_13 ve bugün ≥ 13. yaş günü →
  TEEN (yeni geçiş = 13. yaş günü + 5 yıl; 13. yaş günü hiçbir zaman 29 Şubat olmadığından tam),
  gerekirse zincirle ADULT. Tek yazma. Oturum ortasında geçiş YOK (bir sonraki soğuk açılış).
- **UNDER_13 → TEEN denetimi:** saklanan 13. yaş günü, girişle AYNI (kendi beyanı) standartla
  13 yaşı kanıtlar → tek seferlik yeniden sorma yerine otomatik TEEN seçildi. Yeniden sormak,
  kısıt ekranındaki oyuncuya tam kapının açıldığı anda başka bir tarih girme fırsatı verirdi
  (nötr ekran ilkesi: yaşı değiştirmeye teşvik etmemek); kayıt kanıtlayamıyorsa (bozuk) geçiş
  olmaz → UNKNOWN → yaş yeniden sorulur, reklam yok.
- `AgeGate.clock_override` yalnız test / QA kancası (üretim kodu yazmaz).
- **Saat kuralları (cihaz saati kimlik doğrulaması DEĞİLDİR — kabul edilen sınırlar):**
  - Saat **ileri** alınırsa geçişler erken olur (UNDER_13 → TEEN → ADULT); ADULT'ta tarih
    silindiği için geri alınamaz. Yeniden kurup başka tarih girmek gibi engellenemez (kendi
    beyanı).
  - Saat **geri** alınırsa: saklanan geçiş günü "bugün + bant süresi (13 / 5 yıl)" sınırını
    `TRANSITION_SLACK_DAYS` = 2 günden fazla aşarsa kayıt tutarsız → UNKNOWN (reklam yok, yaş
    yeniden sorulur, ASLA ADULT). Pay yıl dönümünden ÖNCE eklenir (29 Şubat kenarında da tam 2
    gün — saat dilimi değişimi / küçük geri alma).
  - Geçiş günü `EARLIEST_POSSIBLE_TRANSITION` (2026-09-28) öncesiyse kayıt bozuktur (sınıflandırma
    yalnız model gününden sonra yapılır → gerçek geçiş günü her zaman sonraki gündür).
  - Saat **model gününden önce** (bozuk): sınıflandırma yapılmaz (§2); kayıtlı bant sınırlar
    içindeyse korunur (ör. UNDER_13 kısıtı sürer), değilse UNKNOWN.

## 6. Reklam yönlendirmesi (owner tablosu — `AgeGate.ad_route`)

| bant | SDK | UMP | TFAT | en yüksek derece | reklam |
|---|---|---|---|---|---|
| UNKNOWN | başlamaz (eklenti düğümü bile kurulmaz) | yok | — | — | yok |
| UNDER_13 | başlamaz | yok | — | — | yok (kısıt ekranı) |
| TEEN | rotadan sonra | var | **TEEN** | **T** | banner + ödüllü + geçiş (kotalar aynı) |
| ADULT | rotadan sonra | var | **UNSPECIFIED** | **MA** | banner + ödüllü + geçiş (kotalar aynı) |

- CHILD hiçbir banda verilmez (13 altı = reklam yok). TEEN'e MA verilmez. Eski TFCD / TFUA
  `unspecified` (kullanımdan kalkan yol nötr; TEEN onlarla verilmez).
- `android_export.cfg [Audience] max_ad_content_rating` **kaldırıldı**; geri gelirse
  yapılandırma GEÇERSİZ (yanıltıcı, kullanılmayan ayar kalmasın). Özel reklam kategorisi
  kısıtı kodda YOK; Google / platform / yasal kısıtlar ayrıca uygulanır.
- **Play "Uygunsuz reklamlar" uyarısı (AÇIK, release kapısında OWNER):** reklamlar uygulamanın
  Play içerik derecesine uygun olmalı; AdMob tablosuna göre T reklam en az **12+**, MA reklam en
  az **16+** uygulama derecesi ister. Squishy Merge'ün IARC derecesi henüz alınmadı; sevimli bir
  birleştirme oyunu için daha düşük (ör. 3+) çıkması olası. Kapı, owner uygulamanın derecesini
  `[Audience] app_content_rating`'e yazana ve derece yönlendirmenin T / MA reklamlarına izin
  verene kadar engeller. Derece daha düşükse karar owner'ın: yönlendirme dereceleri
  düşürülür (3+ → G, 7+ → PG, 12+ → T; kod değişikliği, TEEN / UNSPECIFIED ayrımı ve
  yetişkin kişiselleştirilmiş reklam yolu yine korunur).

## 7. Sıra ve kilit (MonetizationManager)

1. Soğuk açılış: bant kayıttan (geçişler dahil) → `set_age_band()` ağaca girmeden.
2. `_ready`: bant reklamlıysa **rota** (`set_age_restricted_treatment` + `set_max_ad_content_rating`)
   → **rota geri doğrulaması** (arka ucun tuttuğu yaş işlemi + derece = `AgeGate.ad_route`;
   değilse oturum reklamsız, attach / UMP YOK) → **attach** (eklenti düğümü) → gizlilik API
   algısı → yuva → onboarding tamamsa **UMP**. UNKNOWN / UNDER_13: hiçbiri; başıboş rıza sinyali
   yok sayılır.
3. UMP `canRequestAds()` → rota bir kez daha doğrulanır (sapma → oturum reklamsız) →
   `AdmobBackend.initialize()`: istek yapılandırması SDK'ya uygulanır, SDK'dan **geri okunur**
   (yaş işlemi, derece, TFCD, TFUA) → uyuşursa `MobileAds.initialize()`; yoksa SDK başlamaz
   (`sdk_refused`, oturum reklamsız).
4. SDK hazır + onboarding + yaş kapısı açık → yüklemeler.

**Brif §7 sırasıyla ilişki (bilinçli, belgelenmiş):** brif "yaş → bant → TFAT → derece →
RequestConfiguration geri okuması → UMP → initialize → yüklemeler" sırasını verir ve "tam UMP /
yapılandırma sırası M9 / TASK/042'nin kanıtlanmış gizlilik sözleşmesini korumalı" der. Yaş
kararı, bant, TFAT ve derece UMP'den ÖNCE sabitlenir ve geri doğrulanır (adım 2); SDK'ya **native
uygulama + SDK geri okuması** ise TASK/042'de A36'da kanıtlanan yerde — UMP izninden sonra,
`MobileAds.initialize()`'dan hemen önce — kalır. Sebep: eklenti yapılandırmayı kurarken debug
derlemede test cihazı için reklam kimliğini (AAID) okur; bunu rızadan önce yapmak M9 / TASK/042
sözleşmesini bozardı. Hiçbir reklam isteği bilinen bant + doğru yapılandırma + UMP izni + SDK
hazırlığı + onboarding olmadan gitmez (brif değişmezi).

**Rıza yoldayken oturum kapanırsa** (ör. Ayarlar'dan 13 altı beyanı, güncelleme / form yüklemesi
sürerken): geç gelen UMP sonucu işlenmez — açılış rıza formu YÜKLENMEZ / GÖSTERİLMEZ, SDK
başlamaz (inceleme L3-F1 / L5-F1; `age_ad_routing_test`).

**Yaş bandı sonradan değişirse (`set_age_band`):**
- SDK henüz yapılandırılmadıysa (ör. rıza bekliyor): bekleyen rota güncellenir → `APPLIED`.
- SDK bu süreçte başka rotayla yapılandırıldıysa: işlem DEĞİŞTİRİLMEZ (TEEN ↔ ADULT gevşetme /
  sıkılaştırma YOK) → oturumun geri kalanında reklam YOK: banner gizlenir, ödüllü / geçiş
  gösterilmez, yeni yükleme yok, yeniden denemeler durur, yuva sabit kalır; gizlilik
  seçenekleri formu açık kalır → `NEXT_LAUNCH`; bir sonraki soğuk açılış yeni bandı SDK'dan önce
  uygular. SDK'yı yeniden başlatma yolu kullanılmadı (kanıtlanmış güvenli bir yol yok).
- Reklamsız banda (UNDER_13) geçiş: eklenti kurulduysa `ADS_STOPPED` (oturum reklamsız) + kısıt
  ekranı.

## 8. Ayarlar → "Yaş bilgisi"

- Satır (`calendar` ikon, "Güncelle") yalnız reklam yöneticisi varken ve bant TEEN / ADULT iken
  görünür (UNKNOWN zorunlu ekranla çözülür; UNDER_13 Ayarlar'a ulaşamaz). Kayıtlı yaş / tarih
  GÖSTERİLMEZ.
- Yeniden giriş sonucu tek yazmayla kaydedilir; 13 altı → kısıt ekranı; diğer HER cevapta AYNI
  nötr adım: "Yaş bilgin kaydedildi." + "Bazı ayarlar uygulama yeniden açıldığında
  güncellenebilir." (brif §11'in "sonraki açılışta uygulanır" mesajı; metin cevaba göre
  DEĞİŞMEZ, "reklam" demez — hangi cevabın bir şeyi değiştirdiği ekrandan okunamaz).
- Artık sinyal (brifin gereği, owner'ın seçimi): SDK yapılandırılmışken TEEN ↔ ADULT değişirse
  oturumun geri kalanında reklam kapanır — banner hemen kaybolur. Bu görünür değişiklik aynı
  bant cevabında olmaz (inceleme L2-F1). Kaldırmak için owner seçenekleri: her yeniden girişten
  sonra reklamı oturum boyunca durdurmak ya da TEEN → ADULT'ta daha sıkı TEEN rotasını sonraki
  açılışa kadar sürdürmek (bugünkü brif davranışı değil) — §9.8.

## 9. AÇIK uyum maddeleri (owner / hukuk — bu görev ÇÖZMEDİ, gizlenmedi)

Release kapısında iki ayrı OWNER / UYUM engeli bunları görünür tutar (§10). Hukuki sonuç
çıkarılmadı; "X uygulanmaz" DENMEDİ.

1. **Uygulama içerik derecesi ↔ reklam derecesi** (Play "Uygunsuz reklamlar") — §6.
2. **AB / Birleşik Krallık / İsviçre dijital rıza yaşı.** Google, rıza yaşının altındaki
   kullanıcılar için TFUA (UMP rıza sormaz; GMA 25'te karşılığı CHILD) araçlarını gösteriyor;
   gençlere ait korumaları "dijital rıza yaşının üstü, 18 altı" için tarif ediyor. Rıza yaşı ülkeye
   göre 13–16. Bu uygulama 13–17'yi ülkeden bağımsız TEEN + UMP rızası ile yönlendiriyor (owner
   kararı). 13–15 yaşındaki bir kullanıcının kendi rızasının geçerliliği ülkeye göre hukuki soru.
3. **Families "bazı yerlerde çocuk".** 13–15 / 16–17 bazı yerlerde çocuk sayılırsa Families
   şartları (ör. çocuklardan reklam kimliği göndermemek — TEEN bunu kapatmaz, yalnız CHILD
   kapatır; reklamların çocuğa uygunluğu) o yerlerde gündeme gelebilir.
4. **Brezilya Digital ECA** (Google Play yardım sayfası): çocuk / ergenlere yönelik ya da onların
   erişmesi muhtemel uygulamaların uygulama mağazasından yaş aralığı alması ve bu oyunlarda loot
   box yasağı. Bu uygulama mağaza yaş aralığı ALMAZ (kendi ekranı; Age Signals reklamda yasak) ve
   rastgele içerikli sandıkları var (gerçek para yok). Uygulanabilirlik ve kapsam hukuki soru;
   Brezilya'yı dağıtımdan çıkarmak da bir owner seçeneği.
5. **ABD eyalet uygulama mağazası yasaları** (ör. Teksas SB2420): Google Play özellikleri zorunlu
   tutmuyor; yükümlülüklerin nasıl uygulandığını belirlemek geliştiricinin sorumluluğu.
6. **Data safety + gizlilik politikası:** ham doğum tarihi cihazdan çıkmaz (Data safety
   anlamında "toplanmıyor" olabilir — owner doğrular); ama yaşa bağlı işlem / derece sinyalleri
   (TFAT TEEN / UNSPECIFIED, derece T / MA) her reklam isteğiyle Google'a gider — bunun formda
   nasıl beyan edileceği owner kararı (DATA_SAFETY_INVENTORY §6). Gizlilik politikası metni
   yaş sorusunu ve kullanımını anlatmalı (owner'ın politika metni, checklist #4).

7. **Oyuncuya görünen gizlilik metinleri** (owner / hukuk incelemesi): yaş ekranı notu
   "Doğum tarihin bu cihazdan çıkmaz; yalnızca sana uygun ayarları seçmek için kullanılır." ve
   Ayarlar gizlilik metni (§4). İnceleme L6: ham tarih için doğru; türetilmiş sinyal Google'a
   gider (Ayarlar metni söylüyor). Gizlilik politikası metni bunlarla tutarlı olmalı.
8. **13 altı yazım hatası uygulamada geri alınamaz** (inceleme L2-F4, owner kararı): onaylanmış
   yanlış bir tarih (ör. 2009 yerine 2019) UNDER_13 kısıt ekranına götürür; tasarım gereği
   uygulama içi "tekrar dene" YOK (yaşı değiştirmeye teşvik etmemek). Çıkış yolu uygulama
   verisini temizlemek — ilerleme de silinir. Onay adımı tarihi sözcükle gösterir; DÜZELT /
   ONAYLA ağırlığı ve olası destek yolu owner'ın.
9. **Artık riskler (belgelendi, bu görevde çözülmedi):** (a) kayıt yazımı atomik değil ve
   sonucu denetlenmiyor — koruyucu bir yeniden giriş (ADULT → UNDER_13) yazılamazsa sonraki
   açılış eski bandı okur (depolama hatası; TASK/043 öncesi kayıt tasarımı); (b) Android "Son
   uygulamalar" anlık görüntüsü onay ekranını (tarih sözcükle) cihazda tutabilir — işletim
   sistemi, cihaz dışına çıkmaz; (c) Android 12+ cihazdan cihaza aktarım kaydı yeni cihaza
   taşıyabilir (`allowBackup=false` bunu kapatmaz); (d) GMA'nın manifest başlatma sağlayıcısı
   her süreçte bant ne olursa olsun çalışır — `initialize()` öncesi ağ etkinliğine dair birinci
   taraf ifade bulunmadı (UNKNOWN / UNDER_13 soğuk açılışında A36 logcat'i bakılır, §11);
   (e) kısıt ekranındaki oyuncunun günlük giriş ödülü (+15, reklamsız) açılışta yine yazılır
   (ekonomi etkisi yok, oyun kilitli); (f) `AdEvents` geçiş reklamı atlama sebebi `age_gate`
   bugün hiçbir sağlayıcıya gitmiyor — ileride analitik eklenirse sebep değerleri yaş sinyali
   taşımayacak biçimde gözden geçirilmeli.

Owner bir yargı bölgesi kararı verince (ör. hukuk incelemesi, dağıtım dışı ülkeler) bunu bu
bölüme yazar ve `android_export.cfg [Audience] jurisdiction_age_review = "recorded"` yapar.

## 10. Release kapısı (`tools/release/release_readiness.gd`)

| engel | kategori | ne kaldırır |
|---|---|---|
| 13–17 genç reklam işlemi stratejisi (UYUM) | OWNER | `[Audience] teen_ad_treatment = "age_band_routing"` **VE** kod tablosu owner tablosuyla birebir (`AgeGate.routing_contract_problems()` boş). Kodda yazılı bayrak YOK. Kayıt A36 kapısından sonra yapılır. |
| Yargı bölgesi yaş yükümlülükleri (UYUM) | OWNER | owner / hukuk kararı §9'a yazılır + `jurisdiction_age_review = "recorded"` |
| Play Uygunsuz Reklamlar — uygulama içerik derecesi (UYUM) | OWNER | `app_content_rating` (3+ … 18+) yönlendirmenin T / MA reklamlarına izin veriyor (T ≥ 12+, MA ≥ 16+) ya da owner yönlendirme derecelerini düşürür |
| Kod tablosu owner tablosundan sapıyor | CODE | tablo düzeltilir |
| Release preset'inde `user_data_backup/allow=true` (kayıt otomatik yedeğe) | CONFIG | preset'te `false` (bugün üç preset'te de `false`) |

Üç değer de yalnız kapı içindir; çalışma zamanı davranışını DEĞİŞTİRMEZ. Kapı bunları
eksik / geçersiz girdide engelli sayar (fail-closed).

## 11. A36 cihaz kapısı

*(Commit 1 anında: yapılmadı — commit 2'de bu bölüm doldurulur.)*

## 12. Kaynaklar (2026-09-27'de okundu)

| # | kaynak | URL |
|---|---|---|
| 1 | Play Console Help — Target audience and content (nötr yaş ekranı, 13–15 / 16–17, 21 yaş altı yerel hukuk) | support.google.com/googleplay/android-developer/answer/9867159 |
| 2 | Play — Families policies; Families data practices; Self-Certified Ads SDK | …/answer/9893335 · …/answer/11043825 · …/answer/12955712 · …/answer/17517561 |
| 3 | Play — Data safety | …/answer/10787469 |
| 4 | Play — Ads policy ("Inappropriate ads") | …/answer/9857753 |
| 5 | Play — Age Signals API and User Data; US state laws FAQ; Brazil Digital ECA | …/answer/16585319 · …/answer/16569691 · …/answer/6223646 |
| 6 | Play Age Signals overview + ToS + release notes | developer.android.com/google/play/age-signals/overview |
| 7 | AdMob Android (Legacy) — Targeting (TFAT, derece, sıra) | developers.google.com/admob/android/targeting |
| 8 | RequestConfiguration / Builder / AgeRestrictedTreatment / MobileAds referansları | developers.google.com/admob/android/reference/com/google/android/gms/ads/… |
| 9 | AdMob Help — TFAT; max ad content rating (hesap / istek); digital content labels; teen protections; GDPR araçları | support.google.com/admob/answer/6219315 · /9009425 · /7562142 · /10477886 · /10478094 · /12171027 · /7666366 |
| 10 | UMP — kurulum, EEA (TFUA), GMA / UMP sürüm notları | developers.google.com/admob/android/privacy · …/privacy/gdpr · …/rel-notes · …/privacy/release-notes |
