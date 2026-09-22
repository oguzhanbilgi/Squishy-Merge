# GAME_DESIGN.md — Squishy Merge

Bu doküman kilitli tasarım kararlarını içerir. Owner onayı olmadan buradaki
sayılar/kurallar değiştirilmez. Belirsizlik varsa owner'a sorulur, varsayım
uydurulmaz.

---

## 1. Çekirdek mekanik

- Dikey bir kap (rectangle/trapezoid container, cam kavanoz DEĞİL — düz
  duvarlı basit kap, fizik karmaşıklığını azaltmak için).
- Ekranın üstünde yatay bir "drop çizgisi" var; oyuncu parmağını sürükleyerek
  bir sonraki dumpling'in x-konumunu seçiyor, bıraktığında dumpling düşüyor.
- RigidBody2D tabanlı fizik. Aynı tier'daki iki dumpling çarpışınca:
  - İkisi de silinir, çarpışma noktasında bir üst tier dumpling'i spawn olur
  - Küçük bir "pop" parçacık efekti + squash-stretch tween (scale 1.0 →
    0.8/1.2 → 1.0, ~150ms) oynar
  - Ses: her tier için farklı, artan pitch'te tek bir "pop/squish" SFX
- Kap taşma çizgisine (üstten sabit bir Y değeri) bir dumpling X saniye
  (öneri: 1.5 sn) boyunca temas ederse level/round biter (fail state).
- Tier 8 (en üst) oluşunca özel bir efekt (konfeti + büyük ses) tetiklenir
  ama oyun devam eder (o dumpling normal bir parça gibi kalır).

> **Netleştirme (owner, M1):** Tier 8 oluşunca round otomatik bitmez, ama
> board'un taşmaya yaklaşması kasıtlı bir gerilim anıdır — bu, önlenmeye
> çalışılmayacak bir "çelişki" değil, tasarımın parçası. Tek şart:
> kesin/otomatik game-over olmamalı.

### 1.1 İlk açılış tutorial'ı (owner kararı, M8.10 — KİLİTLİ)

> **M8 art turundaki "Level 1'de sürükle • bırak ipucu" KALDIRILDI.** O ipucu
> onboarded bir oyuncu Level 1'i tekrar oynadığında da çıkıyordu ve gerçek
> bir onboarding değildi. Yerini M8.10'un etkileşimli tutorial'ı aldı; iki
> sistem aynı anda YAŞAMAZ.

**Yalnız GERÇEKTEN YENİ oyuncu** (`onboarding_completed == false`) açılışta
doğrudan gerçek Level 1 tutorial'ına girer — Ana Sayfa → OYNA → Harita
yolculuğu yok. Onboarded oyuncu Level 1'i tekrar oynadığında **hiçbir
tutorial öğesi görmez**; sonsuz mod ve Level 2+ hiç görmez.

Adımlar: karşılama (maskot + BAŞLA) → ilk bırakma (gerçek sürükle/bırak,
güvenli banda sınırlı) → eşleştirme (ikinci T1 birinciye hizalanır) →
**GERÇEK merge** (T2 production fizikten doğar; sahte merge YOK) → kısa
kutlama → hedef / tehlike çizgisi / güçler anlatımı → hazırsın. Küçük bir
**ATLA** kontrolü her an var (ana CTA değil). Rehberli kısım ~20–45 sn.

Tutorial **ÖDÜL VERMEZ** (Hamur, sandık, ekstra güç yok) ve başlangıç güç
stoğuna dokunmaz. Tutorial boyunca reklam, UMP formu ve günlük ödül
mutasyonu YOK. Tam akış, kalıcılık ve ilk gün kuralı:
[docs/TUTORIAL_SYSTEM.md](docs/TUTORIAL_SYSTEM.md).

## 2. Tier listesi (8 tier)

| # | İsim (placeholder) | Yarıçap (px) | Çap (px) | Not |
|---|---|---|---|---|
| 1 | Mini Dumpling | 22 | 44 | En küçük, en sık düşen |
| 2 | Küçük Dumpling | 27 | 54 |  |
| 3 | Dumpling | 34 | 68 |  |
| 4 | Şişkin Dumpling | 42 | 84 |  |
| 5 | Büyük Dumpling | 52 | 104 |  |
| 6 | Dev Dumpling | 65 | 130 |  |
| 7 | Jumbo Dumpling | 81 | 162 |  |
| 8 | Dumpling Kralı | 100 | 200 | Özel efekt tetikler |

> **Yarıçaplar M8'de ölçümle YENİDEN BELİRLENDİ.** Önceki merdiven
> (22/30/40/52/66/84/106/132) level 9-10'u fiilen kazanılamaz kılıyordu:
> owner elle doğruladı, ardından headless bot en dar kapta (370×400 px)
> 20 koşuda tier 8'e **bir kez bile** ulaşamadı.
>
> Kök sebep kap genişliği değil, üst tier'ların kaba göre büyüklüğüydü.
> Yalnızca tier 7-8'i küçültmek yetmedi (0/20 → en iyi 2/20): tepe doluluk
> tier 5-6 artıklarından da besleniyor, o yüzden merdivenin tamamı yeniden
> ölçeklendi. Tier 1 (22 px) korundu, büyüme oranı 1.26'dan **1.241**'e
> düştü — oran her adımda sabit olduğu için boyut farkı hâlâ net okunuyor.
>
> Doğrulama (`tools/bot_runner.gd`, n=40, gerçek fizik): aynı bot L10'u
> **16/40 (%40)**, L9'u **15/30 (%50)** kazanıyor. Ölçüm yöntemi M1/M2'deki ile aynı:
> `tools/tier_geometry.py` alan modeliyle adayları daraltıyor, headless bot
> gerçek fizikle karar veriyor.
>
> **Merge puan tablosuna DOKUNULMADI** — skor modeli geometriden bağımsız,
> dolayısıyla §5.1'deki yıldız eşikleri de geçerliliğini koruyor.

> **Merge puan tablosu (M2'de KİLİTLENDİ):** bir tier'a birleşildiğinde
> kazanılan puan — tier 2: 50, 3: 70, 4: 90, 5: 110, 6: 130, 7: 150, 8: 200.
> M2 balans pasında modellendi: tier 8'e ulaşan oyuncunun skoru medyan ~4740
> (p5 4360 / p95 5150), yani level 10'un "skor ≥ 5000" hedefine 2-3 merge
> kalıyor — hedef anlamlı kalıyor ama ikinci bir yığın kurmayı gerektirmiyor.
> Önceki tablo (30/40/50/60/70/80/100) tier 8'de sadece ~2630 veriyordu ve
> level 10'u pratikte imkânsız kılıyordu.

Sadece tier 1-3 arası düşer (drop pool). Bu, Suika-tarzı oyunların standart
zorluk dengelemesi — üst tier'lar sadece merge ile elde edilir.

> **Çekim bağımsız rastgele DEĞİL — torba (bag randomizer), M8'de değişti.**
> Owner L9/L10'u bitirdi ama "adil hissetmedi" dedi. Kök sebep: her drop
> bağımsız uniform çekiliyordu, bu da oyuncunun elinden bağımsız şanssız
> seriler üretiyordu.
>
> Ölçüm (80 drop'luk bir round, 200.000 deneme) — en uzun aynı-tier serisi:
>
> | model | medyan | p95 | max | 5+ seri içeren round |
> |---|---|---|---|---|
> | bağımsız uniform (eski) | 4 | 7 | 16 | **%48** |
> | torba, tier başına 3 kopya (yeni) | 3 | 4 | 6 | %4.3 |
>
> Kompozisyon adaleti de düzeliyor: 80 drop'ta bir tier'i görme sayısı
> bağımsızda p5-p95 aralığı 20-34 iken torbada 26-27 (ideal 26.7).
>
> Torba 9 parçadan (tier 1/2/3'ten üçer kopya) oluşur, karılır, sırayla
> çekilir, boşalınca yeniden doldurulur. Torba başına 2 kopya 5+ serileri
> tamamen siler ama "iki tane gördüm, üçüncüsü gelmez" diye tahmin
> edilebilir hale gelir; 3 kopya adaletin neredeyse tamamını verirken
> çeşitliliği korur. Uygulama: `scripts/game/drop_bag.gd`, torba round
> başına sıfırlanır.

## 3. Level tablosu (v1 — 10 level)

| Level | Hedef | Kap genişliği |
|---|---|---|
| 1 | Tier 4'e ulaş | Geniş |
| 2 | Tier 4'e ulaş | Geniş |
| 3 | Tier 5'e ulaş | Geniş |
| 4 | Tier 6'ya ulaş | Orta-geniş |
| 5 | Tier 6'ya ulaş | Orta |
| 6 | Tier 7'ye ulaş | Orta |
| 7 | Tier 7'ye ulaş | Dar |
| 8 | Tier 7 + skor ≥ 6750 | Dar |
| 9 | Tier 8'e ulaş | Dar |
| 10 | Tier 8 + skor ≥ 5000 | En dar |

> **Süre baskısı YOK (owner kararı, M8).** Hiçbir level'da süre veya hamle
> limiti yok; tek başarısızlık koşulu taşma. Süre limiti konseptin
> "rahatlatıcı/ASMR" pozisyonuyla çelişiyordu — kasıtlı olarak kaldırıldı,
> tekrar sorulmasına gerek yok. Süre göstergesi de HUD'dan çıkarıldı.
>
> **Zorluk ayarı (M8):** L4 tier 5→6, L6 tier 6→7, L8'e L10 desenindeki gibi
> skor eşiği (6750) eklendi. Headless bot ölçümleri:
>
> | level | kap | hedef | kazanma |
> |---|---|---|---|
> | 4 | 540 | tier 6 | %97 (n=30) |
> | 5 | 480 | tier 6 | %100 (n=30) |
> | 6 | 480 | tier 7 | %100 (n=30) |
> | 7 | 420 | tier 7 | %97 (n=30) |
> | 8 | 420 | tier 7 + 6750 skor | **%70 (n=60)** |
> | 9 | 420 | tier 8 | %43 (n=30) |
> | 10 | 370 | tier 8 + 5000 skor | %43 (n=30) |
>
> **Ölçümün söylediği:** hedef tier'ı artırmak L4/L6'da neredeyse hiçbir şey
> değiştirmedi (%100 → %97/%100). Süre baskısı olmayan geniş kapta bot hedef
> tier 5 de olsa 7 de olsa kazanıyor — zorluğu belirleyen şey **kap genişliği**
> ve **skor eşiği**, hedef tier değil. L8'deki sıçrama (%97 → %70) bunu
> doğruluyor: tek etkili kaldıraç skor eşiği oldu.
>
> **L1-L7 zorluk kaldıracı olarak kap genişliği kullanılmadı — bilinçli,
> giriş/ısınma level'ları.** (owner kararı, M8: kolay kalmaları rahatlatıcı
> konseptle tutarlı; asıl zorluk L8-L10'da.)
>
> Ölçüm notu: süre limitleri zaten pratikte bağlayıcı değildi. Kaldırmadan önce/sonra
> headless bot sonuçları L9'da %50→%43, L10'da %40→%43 (fark gürültü içinde) —
> koşular saat dolmadan çok önce taşmayla bitiyordu. Yani bu değişiklik
> zorluğu değil, oyunun HİSSİNİ değiştiriyor.

Level datası bir Godot Resource (`.tres`) olarak tanımlanır — kod değişmeden
yeni level eklenebilmeli (data-driven, owner'ın istediği gibi).

> **Kap genişliği px karşılıkları (M2'de ölçümle belirlendi):**
> Geniş 600 · Orta-geniş 540 · Orta 480 · Dar 420 · En dar 370.
> Oynanabilir yükseklik (taban–taşma çizgisi) tüm level'larda 400 px
> (M1'de ölçülerek kilitlendi); GAME_DESIGN yüksekliği level başına
> değiştirmiyor. En dar kap (370 px) tier 8'in 200 px çapına 170 px,
> iki tier-7'nin yan yana 324 px'ine 46 px pay bırakıyor — M8'den önce
> bu paylar sırasıyla 106 px ve **-54 px** (yani sığmıyordu) idi.

## 4. Sonsuz mod

Level 10 tamamlanınca açılır. Hamle/süre limiti yok. Sadece skor ve kişisel
rekor (local save, bulut yok). Bu, asıl "bir tane daha" döngüsünün yaşadığı
yer.

> **Kap genişliği 720 px — §3'teki level genişliklerinden BAĞIMSIZ (M8).**
> Eskiden 600 idi, yani §3'ün "Geniş" etiketiyle aynı değer. Artık ayrı bir
> değer: level genişlikleri değişirse bu değişmez, bu değişirse onlar
> değişmez. `resources/levels/endless.tres` içinde duruyor.
>
> Neden: annihilation tek başına tipik oturumu uzatmıyordu (bkz. aşağıdaki
> annihilation notu). Kap genişliği medyanı gerçekten hareket ettiren
> kaldıraç çıktı. Ölçüm (annihilation açık, n=20 her genişlik için):
>
> | kap | süre medyan | süre p90 | merge medyan | medyana etki |
> |---|---|---|---|---|
> | 600 (eski) | 72 sn | 109 sn | 153 | — |
> | 680 | 79 sn | 124 sn | 168 | +%10 |
> | **720 (yeni)** | **91 sn** | **123 sn** | **199** | **+%27** |
> | 780 | 91 sn | 134 sn | 192 | +%26 |
> | 800 | 91 sn | 140 sn | 194 | +%27 |
>
> **Etki 720'de doyuyor** — 780 ve 800 medyana hiçbir şey eklemiyor, sadece
> üst dilimi uzatıyorlar. O yüzden daha genişi anlamsız.
>
> **Görsel bedeli:** viewport 720 px geniş ve duvarlar kabın DIŞINA
> çiziliyor, dolayısıyla 720'lik kapta yan duvarlar ekran dışında kalıyor —
> sonsuz modda oyun alanı ekranı kenardan kenara dolduruyor. Taban ve taşma
> çizgisi görünür durumda; danger state'in kırmızı duvarları görünmüyor ama
> çizgi ile çizginin altındaki kırmızı bant görünüyor, yani tehlike hâlâ
> okunuyor. Level modunda duvarlar aynen duruyor.
>
> **KARAR (owner, M8): duvarların görünmemesi KABUL EDİLDİ, kozmetik bir
> durum sayılıyor.** Sonsuz mod bilerek kenardan kenara dolu bir oyun alanı;
> tekrar sorulmasına gerek yok.
>
> Değerlendirilip ELENEN iki alternatif:
> - **680'e düşmek** (duvarlar tam ekran kenarına oturur): kazancın yalnızca
>   üçte birini veriyor, asıl hedef olan medyan uzamasını sağlamıyor.
> - **Sonsuz modda kamerayı ~%5 uzaklaştırmak** (hem 720 hem görünür duvar):
>   dokunmatik nişan alma koordinatlarının da dönüştürülmesini gerektiriyor.
>   Headless bot girdi yolunu hiç kullanmıyor (doğrudan `_set_aim` çağırıyor),
>   dolayısıyla eklenecek nişan düzeltmesi otomatik doğrulanamıyordu.
>   Risk/getiri dengesi olumsuz bulundu.

> **Tier 8 annihilation — YALNIZCA sonsuz modda (owner kararı, M8).**
> Sonsuz modda iki tier 8 çarpışınca **ikisi de yok olur**: büyük bir
> parçacık patlaması, güçlü ekran sarsıntısı, **+600 puan** bonus ve combo
> sayacına normal bir merge gibi katkı.
>
> Neden gerekli: tier 8'ler birikip yer açmıyordu, oturum erken bitiyordu.
> Neden 600: oyundaki en büyük tek seferlik ödül tier 8 oluşması (200) idi;
> annihilation bunun 3 katı olarak açık ara en büyük ödül oluyor ama tipik
> bir oturumun toplam skoru (~13.000) içinde baskın hale gelmiyor.
>
> **Level modunda BU KURAL YOK.** §1'deki "tier 8 oluşunca round otomatik
> bitmez, parça normal bir parça gibi kalır" kararı level'larda aynen
> geçerli; orada tier 8'ler birikmeye devam eder ve taşma riskinin parçası
> olur. Kod tarafında ayrım `LevelData.is_endless` üzerinden yapılıyor
> (`Dumpling.annihilates_at_max`). Doğrudan test edildi: aynı anda iki tier 8
> bırakıldığında sonsuz modda ikisi de yok oluyor (+600), level 10'da ikisi
> de tahtada kalıyor (+0).
>
> **Ölçüm — beklenen etkiyi TAM vermiyor** (headless bot, sonsuz mod, n=24
> her koşul için):
>
> | | kapalı | açık |
> |---|---|---|
> | süre medyan | 68 sn | 65 sn |
> | süre ortalama | 71 sn | 70 sn |
> | süre **p90** | 87 sn | **119 sn** |
> | en uzun oturum | 89 sn | 129 sn |
> | merge p90 | 194 | 265 |
> | skor p90 | 16.760 | 23.540 |
>
> Yani annihilation **tipik oturumu uzatmıyor**, üst dilimi belirgin biçimde
> uzatıyor. Sebep: kural ancak aynı anda İKİ tier 8 varken tetikleniyor, bu
> da zaten uzun süren oturumlarda oluyor. Kısa oturumlar tier 8'e hiç
> ulaşmadan bittiği için etkilenmiyor.
>
> Medyan oturumu da uzatmak istenirse kaldıraç bu kural değil; sonsuz modun
> kap genişliği (şu an 600) veya tek bir tier 8'i bir süre sonra eritmek gibi
> ayrı bir mekanik gerekir. Owner kararı, yapılmadı.

## 5. Ödül / bağımlılık sistemi

### 5.1 Level sonu akışı

> **Yıldız kriteri (M3'te tanımlandı):** Eşikler, o level'ın hedef tier'ına
> *ulaşan* oyuncuların o andaki skor dağılımından okunuyor. Dağılım Monte Carlo
> simülasyonuyla üretiliyor (`tools/star_thresholds.py`, 40.000 örnek): her drop
> tier 1-3'ten uniform gelir, aynı tier'dan iki parça olunca birleşir. Bir
> tier'a ulaşmak için gereken merge sayıları oyuncu becerisinden bağımsız
> olduğu için bu dağılım doğru; beceri sadece hayatta kalıp kalmadığını belirler.
>
> - **1★** — level hedefini tamamla (mevcut kazanma koşulu)
> - **2★** — kazan VE skor ≥ dağılımın **medyanı (p50)**
> - **3★** — kazan VE skor ≥ dağılımın **p85**'i
>
> | hedef tier | 2★ (p50) | 3★ (p85) |
> |---|---|---|
> | 4 | 160 | 210 |
> | 5 | 430 | 530 |
> | 6 | 1040 | 1190 |
> | 7 | 2260 | 2430 |
> | 8 | 4730 | 4990 |
>
> Sonsuz modda yıldız yok; sadece skor ve kişisel rekor.
>
> **Skor hedefli level'larda istisna (L8 ve L10):** bu iki level'ın bitirme
> koşulu ayrıca bir skor eşiği içeriyor ve ikisinde de bu eşik, hedef tier'ın
> p85 yıldız eşiğinin çok üstünde kalıyor:
>
> | level | bitirme koşulu | 3★ eşiği (p85) | sonuç |
> |---|---|---|---|
> | 8 | tier 7 + skor ≥ 6750 | 2430 | tamamlamak her zaman 3★ |
> | 10 | tier 8 + skor ≥ 5000 | 4990 | tamamlamak her zaman 3★ |
>
> Bu kasıtlı ve **formüle istisna eklenmedi.** İkisi de skor biriktirmeyi
> gerektiren level'lar; bitirmek başlı başına üst düzey başarı sayılıyor.
> Yıldız sistemi asıl ayırt edici işini diğer sekiz level'da yapıyor.
> (M8 notu: L8'e skor eşiği eklenirken bu çakışma tekrar ölçüldü, formülü
> zorlamak yerine istisna kapsamı genişletildi.)
>
> Eşikler `TierConfig.SCORE_P50` / `SCORE_P85` dizilerinde sabit duruyor —
> percentile kapalı formülle çıkmadığı için koddan hesaplanamıyor. **Merge puan
> tablosu değişirse script tekrar çalıştırılıp bu diziler güncellenmeli.**

1. Hedefe ulaşıldı/ulaşılamadı ekranı
2. 1-3 yıldız, TEK TEK gecikmeli reveal (her biri ~400ms arayla, "pat" sesiyle)
3. Sandık açılış animasyonu (aşağıya bakın)
4. Başarısız olunsa bile küçük bir teselli ödülü + hemen "tekrar dene" butonu

### 5.2 Sandık sistemi

**Sandık kaynağı:**
- Her level tamamlanışında 1 sandık
- Ayrıca her 75 merge işleminde bir "bonus sandık" (level'dan bağımsız —
  oyuncuyu sürekli oynamaya bağlar)

Sandık açılışı **iki bağımsız ruleden** oluşur. Bu ikisi ayrı kavramdır ve
karıştırılmamalıdır.

**Rule 1 — RARITY (sandığın kalitesi). KİLİTLİ, owner onaylı:**

| rarity | oran |
|---|---|
| Common | %60 |
| Rare | %25 |
| Epic | %12 |
| Legendary | %3 |

**Rule 2 — ÖDÜL TİPİ (o kalitede ne çıkacağı). KİLİTLİ, owner onaylı (M8.5):**

| ödül tipi | oran |
|---|---|
| Skin | **%30** |
| Hamur | **%70** |

Ödül tipi rarity'den **bağımsızdır**: Legendary bir sandık da %70 olasılıkla
Hamur verir — ama Legendary miktarında (150).

**Bir sandık her zaman TEK bir şey verir** — ya skin ya Hamur, ikisi birden
asla değil.

**Skin sonucu (deterministik kural):**
- O rarity'de oyuncunun **sahip olmadığı** skin varsa, onlardan biri
  rastgele seçilip verilir. Yani skin sonucu çıktıysa **gerçekten yeni bir
  skin açılır**; sahip olunanlar havuzdan baştan elenir.
- O rarity'de açılmamış skin kalmadıysa (bölüm tamamlanmış ya da hiç skin
  tanımlı değilse) aynı rarity'nin Hamur karşılığına düşülür.

**Hamur sonucu — rarity başına miktar:**

| rarity | Hamur |
|---|---|
| Common | 10 |
| Rare | 25 |
| Epic | 60 |
| Legendary | 150 |

Teselli ödülü (kaybedilen round): **5 Hamur** — rarity'den bağımsız.

- **Hamur harcanabilir: §5.6'daki mağaza v1 kapsamında.** (M8'de değişti;
  eski "v1'de harcanacak yer yok, shop v1.1'de" kararı geçersiz.)

> **M8.5 öncesi kural neydi (artık geçersiz):** sandık ödül tipi rulesi
> YOKTU. Sandık o rarity'den rastgele bir skin seçiyor, oyuncu ona zaten
> sahipse Hamur'a çeviriyordu ("duplicate → Hamur"). Bu, koleksiyon
> doldukça skin verme oranının kendiliğinden düşmesi demekti ve mağazayı
> fiilen işlevsiz bırakıyordu (`tools/shop_economy.py` ölçtü).
> Artık skin/Hamur ayrımı açık bir %30/%70 rulesi; "duplicate" kavramı ise
> yalnızca *o rarity'nin tamamı toplanmışsa* devreye giren bir geri düşüş.

### 5.3 Koleksiyon albümü
- Basit bir grid ekranı: kaç skin'den kaçı açıldı. Toplam skin sayısı:
  **20 (kilitlendi)**
- Açılmamış skin'ler silüet olarak görünür

**Skin seçimi (M8.5).** Albüm pasif bir vitrin değil: sahip olunan bir karta
dokunmak o skin'i **takıyor** ve seçim kayda yazılıyor. Grid'in ilk kartı her
zaman **"Varsayılan"** (orijinal dumpling görünümü) ve o da seçilebilir —
kayıtta boş string olarak tutulur. Kilitli karta dokunmak hiçbir şey yapmaz.
Takılı kart yeşil çerçeve + **"TAKILI"** etiketiyle işaretlenir.

Takılı skin oyunda hem yeni bırakılan parçalara hem merge sonucu oluşan yeni
tier'lara uygulanır.

> **DURUM (M8.5-14): final preview art complete / production gameplay
> render complete.** Kazan → koleksiyonda gör → seç → kaydet → oyunda
> uygulan döngüsü çalışıyor; koleksiyon/mağaza owner'ın 20 final önizleme
> görselini gösteriyor; gameplay'de 8 tier karakteri korunup yalnız hamur
> gövdesi skin'in rengi/deseni/malzemesiyle boyanıyor (gövde maskesi +
> shader, `scripts/game/skin_visual.gd`). Rarity: Common/Rare yalnız
> malzeme, Epic gövde içi sparkle, Legendary sparkle + kompakt aura —
> hepsi kozmetik, fizik/skor/RNG'ye dokunmaz. Ayrıntı: `SKIN_ART_AUDIT.md`.
> Bilinen sınır: Epic/Legendary önizlemelerindeki özel aksesuarlar
> gameplay tier'larında yok (ayrı overlay art turu gerekir).
>
> **M8.5-13 (ekran, kural değişmedi):** albümün üstünde bir **vitrin** var:
> takılı skin'in (ya da dokunulan kilitli kartın) büyük önizlemesi, ad,
> rarity, durum ve tek aksiyon ("Tak" / kilitliyse "Mağazaya Git").
> Kilitli kartlar silüet + kilit + **fiyat** gösteriyor; ad soluk ama
> okunur (mağazada zaten görünüyordu). Vitrin ve mağaza satırı kilitli
> skin'in GERÇEK önizlemesini gösterir (kilit rozetiyle) — grid silüet. Sahip olunan karta dokunmak yine
> doğrudan takıyor. Önizleme oyundaki render'la aynı materyali kullanıyor;
> skin başına hazır görsel için `SkinData.preview_texture` alanı var.
>
> **M8.6-06 (owner brief'i, ekran; kural değişmedi):** production
> gardırop. Grid kartı da kilitli skin'in **gerçek final sanatını** gösterir
> (buzlu gövde + kilit rozeti + fiyat; silüet yok — "arzu uyandırsın").
> Karta dokunmak artık yalnız **seçer** (vitrin güncellenir, kayıt
> değişmez); takma vitrindeki **TAK** ile (tek kanonik `equip_skin`).
> Takılı kart nane **TAKILI** plakası; ilk seçenek yine Varsayılan ve
> takılabilir — **06.1:** galerinin en üstünde YAYGIN plakasının ÜSTÜNDE
> ayrı bir "ORİJİNAL" taban şeridi (20 koleksiyon skininden biri değil,
> 0/20 sayacına girmez, fiyatsız); rarity adı oyuncuya Türkçe (YAYGIN /
> NADİR / EPİK / EFSANEVİ). Kilitli skin Mağaza'ya yönlendirilir; Koleksiyon
> satın almaz. Ayrıntı: `docs/UI_VISUAL_SYSTEM.md` §17.

### 5.4 Günlük döngü
- Günlük giriş ödülü (küçük, sabit) + ardışık gün sayacı (streak)
- Ödül miktarı: **15 Hamur** — §5.2'deki oranlarla aynı gerekçeyle GEÇİCİ
- Seri kırılırsa sayaç sıfırlanır — bu v1.1 reklam/monetizasyon kapısını
  açar ama v1'de sadece görüntülenir, işlevsel bir ödeme yok
- **M8.9-02 / 02.1 (owner kararı, KİLİTLİ):** giriş ödülü ekonomisi
  DEĞİŞMEDİ (+15, seri ilerleme/sıfırlama, geri saat koruması, günde tam bir
  kez). Oyuncuya **TEK günlük ödül penceresi** var: GÜNLÜK ÖDÜLLER (§5.4.1)
  üst bölgesinde "N. GÜN · +15 HAMUR · ALINDI" + seri şeridi olarak
  gösterilir; eski ayrı giriş ödülü penceresi kaldırıldı. Ödül pencereden
  ÖNCE tek işlemle (`DailyReward.claim_if_new_day`) yazılır; pencere yalnız
  gösterir, kapatıp açmak ikinci +15 vermez. **Onboarding tamamlanmadan VE
  tutorial'ın bitirildiği takvim GÜNÜNDE giriş ödülü işlemi HİÇ çalışmaz**
  (M8.10 ilk gün kuralı, §12.3) — Hamur, seri, tarih değişmez, geriye dönük
  telafi yok; ilk işlem tamamlanma gününden SONRAKİ ilk yerel günde.

### 5.4.1 Günlük ödüller — GÜNLÜK ÖDÜLLER (M8.9-02, owner kararı, KİLİTLİ)

Üç günlük sistem, her biri **AYRI kota**, yerel takvim gününe göre
(`YYYY-MM-DD`; cihaz saati geri alınırsa görülen en yeni gün geçerli kalır —
yeni ödül üretilmez; saati ileri almak çevrimdışı kayıtta engellenemez, bilinçli
kabul):

| sistem | kota | ne verir |
|---|---|---|
| **Ücretsiz sandık** | günde **1**, reklam yok | günlük sandık (aşağıda) |
| **Reklamlı +150 Hamur** | günde **1 BAŞARILI** ödüllü reklam | tam **+150 Hamur** |
| **Reklamlı sandık** | günde **2 BAŞARILI** ödüllü reklam | günlük sandık |

Bunlar mevcut ödüllü güç refill'i (§5.7.3, günde 1 DÖRT gücün toplamı) ve devam
hakkından (§11, round başına 2) **tamamen bağımsızdır**; hiçbiri diğerinin
kotasını tüketmez. Reklamlı ödül YALNIZ "ödül kazanıldı" callback'iyle; talep,
iptal, ödülsüz kapanış, yükleme/gösterim hatası kota tüketmez.

**Günlük sandık içeriği (DAILY profili — level sonu sandığından FARKLI, §5.2
DEĞİŞMEDİ):**

| adım | değer |
|---|---|
| garanti | **+15 Hamur** (`GUARANTEED_DOUGH`, bu milestone için kilitli başlangıç) |
| bağımsız skin kurası | **%30** |
| kura tuttuysa rarity | Common %60 / Rare %25 / Epic %12 / Legendary %3 (§5.2 ile aynı eşikler) |
| skin | o rarity'de **sahip olunmayan** koleksiyon skinlerinden biri; "Varsayılan" asla |
| rarity tükenmişse | skin yerine **+15 bonus Hamur** |

Sonuç: skin yok **+15** · yeni skin **+15 + skin** · kura tuttu/tükendi **+30**.
Ödül claim anında belirlenir ve kayda işlenir (tek transaction); reveal animasyonu
yeniden kura çekmez. Değerler `DailyChestLoot` / `DailyRewards` sabitlerinde,
veri odaklı tek yer.

**Pencere ve giriş:** "GÜNLÜK ÖDÜLLER" TEK penceredir: üstte günlük giriş
ödülü (§5.4: "N. GÜN · +15 HAMUR · ALINDI" + seri şeridi; ödül pencereden
önce yazılmış gelir), altında üç kart. Günde bir kez otomatik açılır
(onboarding tamamsa, kabuk ekranında; kapatmak hiçbir ödülü tüketmez, yalnız
"bugün görüldü") ve Ana Sayfa Günlük madalyonu ile Mağaza'nın en üstündeki
GÜNLÜK ÖDÜLLER kartından gün boyu yeniden açılır (ikisi AYNI pencere/durum).
Durumlar: HAZIR / ALINDI / REKLAM HAZIRLANIYOR / 2 / 2 · 1 / 2 / BUGÜNLÜK
BİTTİ. Ayrıntı: docs/monetization/DAILY_REWARDS.md.

### 5.5 Level haritası
- Level'lar bir yol üzerinde sıralı düğümler; kilitli level bulanık/gri,
  açılınca kısa bir "unlock" animasyonu
- **Görsel yol haritası M8.5-12'de GELDİ:** düğümler owner'ın harita
  art'ındaki patikayı takip ediyor, programatik candy patika, kısa açılış
  animasyonu, Sonsuz Mod patikanın sonundaki kalede ayrı kapı. Kurallar
  (unlock/yıldız) değişmedi — bkz. PROJECT_STATUS §4.15.

### 5.6 Mağaza (M8'de eklendi)

Sahip olunmayan skin'ler Hamur ile satın alınır. Tek para birimi oyun içi
Hamur.

> **GÜNCELLEME (owner, M8.5-05):** "Gerçek para / IAP YOK" ifadesi artık
> yalnızca SKİNLER için geçerli — skinler hiçbir zaman gerçek parayla
> satılmayacak. Güçler için gerçek para **Power Pack**'ler PLANLANDI ama
> **HENÜZ KURULMADI** (Google Play Billing yok, product ID yok, fiyat yok).
> Bkz. §5.7.4.

Fiyatlar (`scripts/game/shop.gd` → `PRICES`, tune edilebilir tek yer):

| rarity | fiyat | adet | toplam |
|---|---|---|---|
| Common | 50 | 8 | 400 |
| Rare | 150 | 6 | 900 |
| Epic | 400 | 4 | 1600 |
| Legendary | 900 | 2 | 1800 |
| | | **20** | **4700 Hamur** |

Ekran: rarity'e göre gruplanmış liste; sahip olunanlar "✓ Sahipsin" ile
işaretli ve soluk (listeden çıkarılmıyor — koleksiyonun ne kadarının
tamamlandığı görünsün). Hamur yetmiyorsa "Satın Al" pasif. Satın alma
onay diyaloğundan geçiyor.

> **DENGE ÖLÇÜMÜ (M8.5, `tools/shop_economy.py`, 5000 deneme/senaryo).**
> Simülatör artık production davranışını birebir modelliyor (%30 skin /
> %70 Hamur). Monte Carlo — sonuçlar yaklaşıktır.
>
> **Mağaza artık çalışıyor.** Medyan oyuncu koleksiyonun yaklaşık yarısını
> mağazadan satın alıyor (M8'deki eski kuralla bu sayı **0**'dı):
>
> | oyuncu | 20/20 tamamlanma (p25 / medyan / p75) | 30. günde mağazadan alınan | 30. günde artan Hamur |
> |---|---|---|---|
> | kasual (3 round/gün) | 14 / **17** / 20. gün | 11 / 20 | 2.610 |
> | orta (5 round/gün) | 9 / **11** / 12. gün | 10 / 20 | 6.115 |
> | yoğun (10 round/gün) | 5 / **6** / 6. gün | 9 / 20 | 14.815 |
>
> **Kalan iki sorun (fiyatlar bu turda DEĞİŞTİRİLMEDİ):**
>
> 1. **Koleksiyon hâlâ hızlı doluyor.** Üç senaryoda da 30 gün içinde
>    tamamlanma oranı %100. Yoğun oyuncu 6 günde bitiriyor.
> 2. **Tamamlandıktan sonra Hamur'un hiçbir alıcısı yok.** Tek sink mağaza,
>    mağaza da yalnızca 20 skin satıyor. Koleksiyonun tamamı 4.700 Hamur;
>    yoğun oyuncu 30. günde bunun **üç katından fazlasını** biriktirmiş
>    oluyor (14.815) ve harcayacak yer bulamıyor.
>
> Yani M8'deki "mağaza ölü" sorunu çözüldü, yerine "geç oyun Hamur enflasyonu"
> sorunu geçti. Çözüm alternatifleri (skin sayısını artırmak, fiyatları
> yükseltmek, Hamur gelirini düşürmek, ikinci bir sink eklemek) **owner
> kararı** — bu turda hiçbir fiyat veya gelir kaynağı değiştirilmedi.

> **ÇÖZÜLDÜ (M8.5-05): ikinci sink eklendi.** Güçler Hamur ile satılabilir
> hale geldi (§5.7). Skin fiyatlarına, sandık oranlarına ve Hamur gelir
> kaynaklarına DOKUNULMADI. Enflasyonun ne kadar emildiği §5.7.2'de.

### 5.7 Güç mağazası (M8.5-05)

Dört güç (§10) artık **Hamur ile satın alınabilir**. Bu, oyunun ikinci ve
ilk defa TEKRARLANABİLİR Hamur sink'i: skinler bir kez alınır ve biter,
güçler tükenir.

Güç edinmenin dört yolu:

| yol | durum |
|---|---|
| Başlangıç hediyesi — kayıt başına BİR KEZ her güçten ×1 | ✅ var (§10.1) |
| **Hamur ile satın alma** | ✅ **bu turda eklendi** |
| Ödüllü reklam ile sınırlı refill | ⚙️ **UX + kota HAZIR, SDK yok** (§5.7.3) |
| Gerçek para Power Pack | ⏳ PENDING — billing yok (§5.7.4) |

> **Revive AYRI bir sistemdir (§11).** Revive Hamurla satın alınmaz, güç
> envanteri VERMEZ ve buradaki hiçbir sayıya dahil değildir.

#### 5.7.1 Fiyatlar (KİLİTLİ)

`scripts/game/power_up_economy.gd` → `DOUGH_PRICES`. Tek tanım noktası; UI
hiçbir yerde sayı hardcode etmiyor.

| güç | fiyat | gerekçe |
|---|---|---|
| **Sarsıntı** | **100** | En ucuz: tek başına round kurtarmıyor, faydası kaotik |
| **Bomba** | **120** | Taban: tek parça siler, öngörülebilir |
| **Temizleyici** | **160** | Tüm tier 1-2'yi siler — en güçlü kurtarma aracı |
| **Büyütücü** | **180** | En pahalı: level'ın tier HEDEFİNİ doğrudan karşılayabilen tek güç (§10.3'teki istisna) |

Fiyatın **şekli** gameplay değerinden türetildi, kullanım sıklığından değil.
Fiyatın **seviyesi** simülasyonla tarandı (taban 80→200, `python
tools/shop_economy.py sweep`). Yoğun oyuncu (10 round/gün), 30. gün Hamur
medyanı ve karşılanmayan istek sayısı:

| taban | fiyat seti | gün30 | gün90 | karşılanmayan/30g |
|---|---|---|---|---|
| — | (güç sink'i yok) | 14.745 | 49.975 | — |
| 80 | [80,120,70,110] | 2.895 | 10.045 | 4 |
| 100 | [100,150,80,140] | 950 | 1.925 | 11 |
| **120** | **[120,180,100,160]** | **315** | **330** | **27** |
| 140 | [140,210,120,190] | 235 | 235 | 42 |
| 200 | [200,300,170,270] | 235 | 230 | 71 |

**120 seçildi.** 140 ve üstü DAHA FAZLA Hamur emmiyor — güce giden Hamur
16.200'de doyuyor, artan tek şey oyuncunun karşılanmayan isteği. Yani
pahalıya kaçmanın ekonomik getirisi yok, sadece mahrumiyet üretiyor.

Skin fiyatlarıyla tutarlılık: Sarsıntı 100 = iki Common skin (50), Büyütücü
180 > bir Rare skin (150), hepsi Legendary'nin (900) çok altında.
Tüketilebilir bir güç, kalıcı bir Common ile Rare skin arasında duruyor.

#### 5.7.2 Denge ölçümü

> `tools/shop_economy.py`, 4000 deneme/senaryo, 90 gün. Monte Carlo —
> sonuçlar yaklaşıktır.
>
> ⚠️ **Güç kullanım sıklıkları ÖLÇÜLMÜŞ DEĞİL, VARSAYIM** — gerçek
> telemetry yok. Üç profil modellendi: düşük (~her 5-6 roundda 1), orta
> (~her 3-4 roundda 1), yüksek (~her 2 roundda 1). Gerçek veri gelince
> yeniden kalibre edilmeli.

**Hamur enflasyonu — kalan Hamur medyanı:**

| oyuncu | | gün 30 | gün 60 | gün 90 |
|---|---|---|---|---|
| kasual (3/gün) | sink yok | 2.615 | 8.210 | 13.805 |
| | **sink açık** | **1.515** | **4.865** | **8.200** |
| orta (5/gün) | sink yok | 6.095 | 15.140 | 24.185 |
| | **sink açık** | **1.995** | **5.170** | **8.245** |
| yoğun (10/gün) | sink yok | 14.835 | 32.415 | 50.025 |
| | **sink açık** | **325** | **335** | **335** |

Yoğun oyuncunun 90 günlük fazlası **50.025 → 335 (%99,3 azalma)**; 51.220
Hamur güce gitti. Orta oyuncuda %66, kasualde %41 azalma.

**Koleksiyon tamamlanması (medyan gün):**

| oyuncu | sink yok | sink açık | + önerilen rewarded |
|---|---|---|---|
| kasual | 17 | 21 | 18 |
| orta | 11 | 15 | 12 |
| yoğun | 6 | 9 | 9 |

Koleksiyon hâlâ tamamlanıyor (30 gün içinde %92-99), sadece 1-4 gün
gecikiyor. Mağazadan alınan skin sayısı düşüyor (orta oyuncuda 10 → 4):
oyuncu artık gerçekten **skin mi güç mü** seçiyor.

**Kasual oyuncu fakirleşmiyor:** karşılanmayan istek 0, 7. günde ~335 Hamur
ile geziyor, ilk hafta bütün güç isteklerini karşılıyor.

#### 5.7.3 Ödüllü reklam refill — cap KİLİTLENDİ, SDK pending (M8.5-06)

> **KİLİTLİ: günde 1 ödüllü güç refill'i, dört gücün TOPLAMI için.**
> `scripts/game/rewarded_policy.gd` → `DAILY_POWER_REFILLS`.

**Kurallar:**

- Kota **dört gücün toplamı** içindir, **tip başına DEĞİL**.
- Kotayı **yalnızca başarılı reward grant** tüketir. Reklamın istenmesi,
  açılması, yüklenememesi ve **ödülsüz kapanması TÜKETMEZ**.
  *(§11.2'deki revive invariant'ının aynısı: `ad closed != reward earned`.)*
- Yeni gün kotayı sıfırlar. **Round değişimi ve uygulama yeniden başlatması
  sıfırlamaz** — kayıtta tarih + sayaç duruyor
  (`rewarded_power_date` / `rewarded_power_grants`).
- **Revive hakları (§11) bu kotadan TAMAMEN BAĞIMSIZDIR.** Aynı round'da hem
  bir güç refill'i hem iki revive reklamı görülebilir.
- Yalnızca **gameplay'de ve stok 0 iken** sunulur. Mağazada "bedava stok
  biriktir" butonu YOKTUR — amaç reklam izleyerek onlarca güç stoklamak
  değil, o anki ihtiyacı karşılamak.

**Neden 1 (ölçüldü, `python tools/shop_economy.py caps`, 3000 deneme/senaryo,
90 gün).** Yoğun oyuncu (10 round/gün, yüksek kullanım) — kararın verildiği
senaryo:

| cap | reklam/gün | bedava | Hamurla | bedava% | karşılanmayan | gün90 Hamur |
|---|---|---|---|---|---|---|
| yok | 0,00 | 0 | 379 | %0 | 67 | 330 |
| **1** | **1,00** | **90** | **348** | **%20,5** | **8** | **3.735** |
| 2 | 1,99 | 179 | 265 | %40,3 | 1 | 14.685 |
| 3 | 2,92 | 263 | 182 | %59,1 | 0 | 25.610 |
| cap yok (1/round) | 4,96 | 446 | 0 | %100 | 0 | 50.220 |

**1, "mağazayı en çok koruyan" olduğu için seçilmedi.** Gerekçe marjinal
fayda/maliyet:

- 1/gün, karşılanmayan güç isteğini zaten **67 → 8 (%88)** düşürüyor; yani
  oyuncunun yaşadığı mahrumiyetin neredeyse tamamını çözüyor.
- 2/gün bunun üstüne 90 günde yalnızca **7 istek** daha karşılıyor (günde
  0,08) ama 90. gün Hamur fazlasını **3.735 → 14.685'e (4 kat)** çıkarıyor.
- **3/gün elendi:** 90. gün Hamur'u **25.610** — güç sink'i olmayan referansın
  (50.025) yalnızca yarısı kadar aşağıda, yani M8.5-05'te çözülen geç oyun
  enflasyonuna yarı yola kadar geri dönüş. Ayrıca güçlerin **%59'u bedava**
  geliyor: rewarded artık ana kaynak, Hamur mağazası ikincil.

Reklam adedi ayırt edici değil: yoğun oyuncuda revive'ın **teorik** tavanı
zaten 20 reklam/gün (10 round × 2), güç capi 1 → 3 toplam tavanı yalnızca
21 → 23 yapıyor.

Kasual oyuncuda (3 round/gün) 1/gün zaten isteklerin %84'ünü bedava
karşılıyor; 2 ve 3'te bu %100 oluyor ve kasualdeki Hamur sink'i tamamen
kayboluyor. Yani daha yüksek cap'in kasualde de getirisi yok.

**Durum: cap KİLİTLİ, gerçek reklam PENDING.** AdMob SDK kurulmadı; sağlayıcı
`main.gd` → `set_rewarded_provider()` ile bağlanacak. Beklenen akış:
`rewarded_refill_requested(type)` → reklam → **reward earned** →
`Main.grant_rewarded_power(type, token)`. Ödül gelmezse
`Main.notify_power_rewarded_unavailable(mesaj)`.

**Callback güvenliği (token):** her talep artan bir token üretir; grant
yalnızca açık talebin token'ı VE tipi eşleşirse kabul edilir ve kabul edilir
edilmez token sıfırlanır. Böylece duplicate callback ikinci kez grant etmez,
stale/iptal edilmiş talebin callback'i grant etmez, yanlış güç için gelen
callback başka bir güce stok vermez. Başarısız reklam da token'ı geçersiz
kılar.

#### 5.7.3.1 Refill penceresi (stok 0 UX)

Stok 0 bir güce basınca **oyun DURUR** ve pencere açılır. Durdurma kozmetik
değil: ödüllü reklam 20–40 sn açık kalabiliyor ve board arka planda oynasaydı
oyuncu reklam izlerken taşıp round'u kaybederdi. Revive'ın (§11.3) dondurma
makinesinin aynısı kullanılıyor ama **round BİTMİYOR** — pencere kapanınca
oyun tam kaldığı yerden devam ediyor.

Pencerede hangi gücün istendiği açıkça yazıyor ve iki çalışan yol var:

| CTA | durum |
|---|---|
| **REKLAM İZLE → +1** | kota dolduysa veya sağlayıcı yoksa **pasif**, sebebi yazıyla açıklanıyor |
| **HAMURLA AL → §5.7.1 fiyatı** | Hamur yetmiyorsa **pasif** |
| Kapat | hiçbir şey alınmaz, oyun devam eder |

Fiyat UI'da hardcode DEĞİL — mağazayla aynı `PowerUpEconomy` kaynağı.
Hamur satın alması M8.5-05'teki tek mutasyon + tek save yolundan geçiyor.

**Niyet geri dönüşü:** refill başarılı olduğunda oyuncunun ilk niyetine
dönülür. **Hedefli** güçlerde (Bomba / Büyütücü) hedefleme yeniden açılır —
bu tamamen geri alınabilir, stok tüketmez. **Anında çalışan** güçlerde
(Sarsıntı / Temizleyici) bilerek **OTOMATİK ÇALIŞTIRILMIYOR**: pencereden
çıkar çıkmaz gücün kendiliğinden harcanması "yanlışlıkla harcama" olurdu.
Stok gelir, çubuk güncellenir, oyuncu bir kez daha basar.

> ⚠️ **Saat manipülasyonu:** günlük kota cihazın yerel tarihine bakıyor.
> Backend yok, doğrulanabilir sunucu saati yok; saatini ileri alan bir oyuncu
> kotayı tazeleyebilir. Bu, günlük giriş ödülünün (§5.4) zaten taşıdığı aynı
> açık ve **bilinçli kabul ediliyor**: v1'de backend bir non-goal ve
> kazanılabilecek şey tüketilebilir bir güç. Sunucu doğrulaması olmadan
> yapılacak her "önlem" güvenlik tiyatrosu olurdu.

> ⚠️ Pencerenin **final art'ı YOK**: mevcut kawaii UI temasının panel/buton
> stilini ve güç çubuğuyla aynı geçici metin işaretlerini kullanıyor.

> **Gerçek para Güç Paketi** üçüncü bir CTA olarak buraya eklenecek. Seam
> `power_pack_requested` sinyali olarak duruyor ama **hiçbir yere bağlı
> değil ve buton gösterilmiyor** — çalışmayan sahte bir satın alma butonu
> göstermek yanlış olurdu (§5.7.4).

#### 5.7.4 Gerçek para Power Pack — PENDING, sadece taslak

**Google Play Billing KURULMADI. Product ID YOK. TL/USD fiyat YOK.**
Aşağıdaki yalnızca içerik taslağı ve Hamur cinsinden değer ölçümü.

| pack | içerik | toplam güç | Hamur değeri | yoğun oyuncunun kaç günlük geliri | kaç round'a yeter |
|---|---|---|---|---|---|
| Mini Pack | her güçten ×3 | 12 | 1.680 | 3,1 gün | ~24 round |
| Power Pack | her güçten ×6 | 24 | 3.360 | 6,2 gün | ~48 round |
| Mega Pack | her güçten ×12 | 48 | 6.720 | 12,3 gün | ~96 round |

İlk taslak ×2/×5/×12 idi; ölçüm sonrası ×3/×6/×12'ye çekildi: ×2 Mini yoğun
oyuncunun yalnızca **2,1 günlük** gelirine denk geliyordu, yani satın alma
işlemine değmeyecek kadar küçüktü. Yeni ladder temiz bir 1:2:4 (3 / 6 / 12
günlük gelir).

**Spam riski:** Mega ×12, yoğun oyuncuda ~10 gün boyunca stok bitmemesi
demek — günlük rewarded cap'i o süre boyunca fiilen atlıyor. Sınırlı ve
ücretli olduğu için kabul edilebilir, ama ×12'nin üstüne çıkmak gating'i
tamamen anlamsızlaştırır.

#### 5.7.5 Mağaza ekranı

İki bölüm: **GÜÇLER** (üstte, tekrar alınabilir) ve **SKİNLER** (altta,
kalıcı). Üstte Hamur bakiyesi. Güç kartı: isim, `Stok: ×N`, fiyat, "Satın
Al". Hamur yetmiyorsa buton pasif. Satın alma onay diyaloğundan geçiyor;
sonrasında bakiye, stok ve toast anında güncelleniyor.

> ⚠️ Güç ikonları hâlâ geçici metin işaretleri (`PowerUp.GLYPHS`) — final
> power-up art'ı YOK (§10.7).

#### 5.7.6 Transaction kuralı

**INVARIANT: başarılı satın alma = para düşmesi + ödül verilmesi AYNI
logical transaction.**

Eski skin satın alma `spend_dough()` + `grant_skin()` şeklinde İKİ ayrı kayıt
yazması yapıyordu; aradaki bir çökme Hamur'u yakıp skin'i vermeyebilirdi.
Artık hem güç hem skin satın alma `SaveManager` içinde tek mutasyon + tek
`save_game()` ile yapılıyor (`purchase_powerup_with_dough`,
`purchase_skin_with_dough`).

Bu tam bir atomic-file/journaling sistemi DEĞİL — dosyanın kendisi hâlâ tek
`store_string` ile yazılıyor. Çözülen şey uygulama seviyesindeki "yarım
işlem" penceresi.

Başarısız satın alma (yetersiz Hamur, geçersiz tip, adet ≤ 0) **hiçbir alanı
değiştirmez ve diske yazmaz.** Envanter ve Hamur asla negatife inmez.

## 6. Ses tasarımı

> **Ses dosyaları (M8.5-15 → M8.8-02 production):** merkezi olay tablosu
> `AudioManager.EVENTS` (`scripts/autoload/audio_manager.gd`), dosyalar
> `assets/audio/sfx/<ui|gameplay|powers|rewards>/` — M8.8-02'den itibaren 35
> **owner onaylı production** WAV (Kenney CC0 + Sonniss GDC 2026, offline bir kez
> üretildi; `tools/audio_production_build.py`). Kanonik dokümanlar:
> `docs/audio/AUDIO_SYSTEM.md` (olay haritası), `docs/audio/MERGE_SOUND_FAMILY.md`
> (owner onaylı A merge ailesi), `docs/audio/HAPTIC_MAPPING.md`; kaynaklar
> `assets/audio/CREDITS.md`. `docs/AUDIO_AUDIT.md` / `AUDIO_ASSET_REQUIREMENTS.md`
> tarihsel. Bus yapısı: Master → SFX (HardLimiter) / Music (`default_bus_layout.tres`).
> Tier başına pitch escalation POP katmanında (`TierConfig.merge_pitch`, 0.85 → 1.48,
> kilitli), üstüne tier bandına göre gövde havuzu (T1–3 hafif / T4–6 dolu / T7–8
> büyük), tier ≥ 3 cam parıltısı, tier ≥ 5 çan; tier 8 = bell bloom + müzik kutusu
> notası + kısa parıltı kuyruğu (daha geniş/uzun, daha gürültülü değil).
> Titreşim (owner kararı, M8.5-15; eşleme M8.8-02): `scripts/haptics.gd`, Ayarlar →
> Titreşim; normal merge T1–T3 yok / T4–T5 LIGHT / T6–T7 MEDIUM / T8 SPECIAL —
> `docs/audio/HAPTIC_MAPPING.md`.

- Her tier'ın merge sesi bir öncekinden hafifçe yüksek pitch'te (escalation)
- Combo yapılırsa (kısa süre içinde art arda merge) ekstra "combo" sesi +
  ekranda büyüyen "xN" yazısı
- Danger state (taşmaya yakın): kap kenarında kırmızı titreşen highlight +
  gerilim hissi veren düşük bir drone/tık sesi

> **Arka plan müziği v1 non-goal** — bilinçli olarak eklenmedi, tekrar
> sorulmasına gerek yok. (Music bus'ı yapıda duruyor ama boş.)

> **Not:** combo şu an sadece görsel/işitsel, skora dahil değil. İleride
> combo'ya gerçek bir skor çarpanı eklenirse, `star_thresholds.py`'nin
> "beceriden bağımsız merge sayısı" varsayımı geçersiz kalır — yıldız
> eşikleri o noktada bot ölçümünden yeniden üretilmeli.

## 7. UI / HUD

> **Navigasyon: alt sekme çubuğu (M8).** Ana Sayfa / Harita / Koleksiyon /
> Mağaza. Oyun sırasında ve round sonucu ekranında gizleniyor.
> - **Ana Sayfa**: minimal — hoşgeldin, günlük seri, Hamur/koleksiyon
>   sayacı, "Oyna" butonu (haritaya götürür).
> - **Harita**: mevcut level seçim grid'i (§5.5'teki görsel yol haritası
>   henüz yok).
> - **Koleksiyon**: §5.3'teki albüm. Eski "Geri" butonu kaldırıldı.
> - **Mağaza**: §5.6.
>
> Koleksiyon'a eskiden level seçim ekranındaki bir butondan giriliyordu;
> o buton sekme çubuğuna taşındı.
Referans: owner'ın ürettiği moodboard görseli (skor, para, "next" önizleme,
taşma çizgisi, kap, alt sırada mevcut/gelecek dumpling sırası). Görsel stil
owner'ın kendi asset'leriyle uygulanacak; Claude Code için önemli olan
LAYOUT ve state binding — hangi UI elemanı hangi veriye bağlı.

## 8. Milestone / saat bütçesi (toplam ~20 saat)

| # | Milestone | Süre |
|---|---|---|
| 0 | Ortam doğrulama + proje iskeleti | dahil (M1'e) |
| 1 | Core fizik + merge mantığı (placeholder şekillerle) | 5 sa |
| 2 | Level sistemi (10 level, data-driven) + sonsuz mod | 3 sa |
| 3 | Sandık + rarity + reveal animasyonu | 2.5 sa |
| 4 | Koleksiyon albümü ekranı | 1.5 sa |
| 5 | Currency (Hamur) + günlük giriş/streak | 1.5 sa |
| 6 | Ses tasarımı entegrasyonu | 1.5 sa |
| 7 | Owner asset'lerini entegre etme | 1.5 sa |
| 8 | Polish / bug-fix | 1.5 sa |
| 9 | Android export + signing | 1 sa |
| 10 | Store listing + kapalı test track'e submit | 2 sa |

Her milestone sonunda: kısa playtest checklist + owner onayı beklenir,
bir sonraki milestone'a öyle geçilir.

## 9. Manuel playtest checklist (her milestone sonunda)
- [ ] Oyun crash vermeden açılıyor mu?
- [ ] O milestone'a ait yeni davranış beklendiği gibi çalışıyor mu?
- [ ] Önceki milestone'ların davranışı bozulmadı mı (hızlı regresyon kontrolü)?
- [ ] Mobil ekran oranında (dar/uzun) UI taşması var mı?

## 10. Güçler (consumable power-ups, M8.5-03)

Dört tüketilebilir güç. **Oranlar ve kurallar owner tarafından kilitlendi.**

| güç | ne yapar | hedefli mi |
|---|---|---|
| **Bomba** | Seçilen tek dumpling'i yok eder | evet |
| **Büyütücü** | Seçilen dumpling'i bir üst tier'a çıkarır | evet |
| **Sarsıntı** | Board'a kontrollü impulse uygular, parçalar karışır | hayır |
| **Temizleyici** | Tüm tier 1 ve tier 2 parçaları kaldırır | hayır |

### 10.1 Envanter

- Kayıt başına **başlangıç stoğu: her güçten 1 adet.**
- Bu **tek seferliktir** — her round'da veya her açılışta tekrar verilmez.
  Eski kayıtlar migration'da hediyeyi bir kez alır (`powerup_starter_granted`
  bayrağı tekrarı engeller).
- Stoklar **round'lar arasında kalıcıdır** (`SaveManager.data["powerups"]`).
- Envanter **asla negatife inmez.**

### 10.2 Tüketim kuralı (KRİTİK)

**Butona basmak güç tüketmez. Stok yalnızca efekt gerçekten gerçekleştiği
anda düşer.** Tüketmeyen durumlar:

- hedefleme açıldı, oyuncu vazgeçti (boşluğa dokundu / başka butona bastı)
- hedef geçersiz (Büyütücü ile tier 8 seçilmeye çalışıldı)
- Temizleyici basıldı ama board'da hiç tier 1/2 yok
- Sarsıntı basıldı ama board boş
- stok zaten 0

### 10.3 Puan ve sayaç etkisi

**Güçle yapılan silmeler ve dönüşümler skor, merge sayacı veya bonus-sandık
ilerlemesi ÜRETMEZ.** Yani güçlerle sandık farm'lanamaz.

Tek istisna **hedef takibi**: Büyütücü ile elde edilen tier, level'ın
"Tier X'e ulaş" hedefini karşılar ve tier 8'in normal görsel kutlaması
çalışır. (Skor hedefi olan L8/L10'da skor yine merge ile kazanılmalıdır.)

### 10.4 Hedefleme (Bomba ve Büyütücü)

Ortak, tekrar kullanılabilir bir durum makinesi
(`scripts/game/power_up_controller.gd`):

- hedefleme açıkken **normal sürükle-bırak devre dışı**
- geçerli hedefler nabız atarak vurgulanır; **geçersiz hedefler hiç
  vurgulanmaz**
- boş alana dokunmak iptal eder (stok tüketmez)
- başka bir güç butonuna basmak önceki hedeflemeyi temizler;
  **iki güç aynı anda aktif olamaz**
- round bittiyse hiçbir güç silahlanamaz

Geçerli hedef: canlı, board'da ve merge işleminde OLMAYAN dumpling.
Büyütücü için ek koşul: `tier < 8`.

> **Sunum zamanlaması (M8.5-07 Bomba, M8.7-02 Büyütücü):** hedef onaylandığı
> dokunuşta stok düşer ve hedef kilitlenir (başka merge / güç onu göremez);
> etki kısa bir sunum vuruşundan sonra uygulanır — Bomba'da merminin 0.28 s
> uçuşu, Büyütücü'de 0.15 s'lik kilitlenme halkası + yükleme sütunu
> ("anticipation"). Kural değişmedi: iptal ve geçersiz hedef yine stok
> tüketmez; pencere içinde ikinci bir dokunuş ikinci bir işlem üretmez.
> Büyütücü ile elde edilen tier 8, normal T7+T7 merge ile aynı kutlamayı
> (kral parıltısı + özel titreşim) alır — skor yine vermez (§10.3).

### 10.5 Sarsıntı — taşma koruması

Kap yeniden inşa edilmez, duvarlar oynamaz, hiçbir parça teleport edilmez.
Yalnızca canlı gövdelere impulse uygulanır; parçalar birbirine yaklaşırsa
merge **normal çarpışma yolundan** olur — kodda "eşleşenleri bul" mantığı
yoktur.

Güç uygulanırken taşma sayacı sıfırlanır ve **1.2 saniyelik bir koruma
penceresi** açılır. Pencere bitince normal 1.5 sn taşma kuralı aynen döner.
Pencere **stack etmez**: arka arkaya sarsıntı süreyi uzatmaz, aynı süreye
yeniden kurar.

> **Ölçüm (n=24, 15 parçalık oturmuş yığın, 3 sn gözlem):** sarsıntısız
> ortalama **0.00** merge, sarsıntılı **4.88** merge; yığın tepesi ortalama
> 56 px alçalıyor. Yani sarsıntı kaotik değil, gerçekten iş yapıyor.

### 10.6 Refill — henüz YOK

Stok 0 iken butona basmak `refill_requested(type)` sinyali yayar. Bu, ileride
**ödüllü reklam / Hamur ile satın alma / gerçek para Power Pack** akışlarının
bağlanacağı tek noktadır.

> **GÜNCELLENDİ (M8.5-05):** Hamurla satın alma artık BAĞLANDI ve güç
> fiyatları BELİRLENDİ — bkz. §5.7. Bu maddede hâlâ bağlı OLMAYAN iki yol
> kaldı: ödüllü reklam refill (§5.7.3) ve gerçek para Güç Paketi (§5.7.4).
> Sahte reklam yok, sahte satın alma yok, bedava stok yok.

### 10.7 Görsel durum

> **STATUS (M8.5-08): final power-up art BAĞLANDI.**
> Dört gücün de gerçek ikonu var (`PowerUp.ICON_PATHS`); geçici metin
> işaretleri (`PowerUp.GLYPHS`) UI'dan kalktı, sabit yalnızca son çare
> olarak duruyor. Güç çubuğu butonları owner'ın candy pill asset'lerini
> kullanıyor (normal / seçili / stok-0). Bombanın uçan mermisi ve
> patlaması AYRI asset'ler — `fx_dot` yeniden kullanımı kalktı.
> Güç çubuğu bilerek ekranın en altına sabitlenmedi — alt safe-area ileride
> AdMob banner'ına ayrılacak.

## 11. Devam etme — ödüllü reklamla revive (M8.5-04)

**Owner tarafından kilitlendi.** Taşma (overflow) artık round'u doğrudan
bitirmez; oyuncuya reklam izleyerek devam etme fırsatı sunulur.

Nihai akış:

```
FAIL → Devam #1 → FAIL → Devam #2 → FAIL → KESİN KAYIP
```

### 11.1 Devam hakkı

- **Round başına en fazla 2 devam.** (`GameBoard.MAX_REVIVES_PER_ROUND`)
- Sayaç **round-local**: kayda YAZILMAZ. Yeni round ve "tekrar dene" 0/2 ile
  başlar.
- Devam **Hamur, güç veya skorla ilişkili değildir**. Tek kaynağı ödüllü
  reklamdır.

### 11.2 Hak ne zaman düşer (KRİTİK)

**Yalnızca `grant_revive()` başarılı olduğunda +1.** Bu metodu YALNIZCA
"ödül kazanıldı" callback'i çağırabilir.

> **INVARIANT: "reklam kapandı" callback'i devam DEĞİLDİR.** Reklam ödülsüz
> de kapanabilir; devam hakkını yalnızca *reward earned* verir.

Hak TÜKETMEYEN durumlar:

- devam penceresinin açılması
- "DEVAM ET" (ödüllü CTA) butonuna basılması
- reklamın yüklenememesi / gösterilememesi
- reklamın kapatılması ama ödülün kazanılmaması
- oyuncunun "Bitir" demesi

Bu ayrım gelecekte reklam hatalarında kritik: yüklenmeyen bir reklam
oyuncunun hakkını yakmamalı.

### 11.3 Fail-pending: teklif açıkken ne olmaz

Grace dolduğunda ve hak varsa **`round_finished` YAYILMAZ.** Dolayısıyla
teklif açıkken şunların HİÇBİRİ çalışmaz:

- teselli ödülü / sandık
- round merge muhasebesi (`SaveManager.add_merges`)
- sonuç ekranı
- endless rekor kaydı

Ayrıca oyun tamamen durur: yeni drop yok, nişan/sürükleme kapalı, güç
butonları `disabled`, açık hedefleme iptal, taşma sayacı ilerlemiyor, combo
penceresi duruyor. Canlı `RigidBody2D` parçalar `FREEZE_MODE_STATIC` ile
dondurulur; hız ve açısal hız saklanıp devam edilince geri verilir. Reklam
ekranı 20–40 sn açık kalsa bile board arka planda oynamaz.

`round_finished(false)` **tam bir kez**, yalnızca şu iki durumda yayılır:
oyuncu devam istemedi, ya da devam hakkı kalmadı.

### 11.4 Devam edilince board'a ne olur

1. **Taşma temizliği.** Üst kenarı taşma çizgisinin **120 px altına** kadar
   uzanan, yerleşmiş (`has_landed`) ve merge işleminde olmayan parçalar kısa
   bir pop efektiyle kaldırılır. Board'un geri kalanı korunur — **tüm board
   temizlenmez.**
   - 120 px = oyun alanı yüksekliğinin (400) %30'u. Ölçüm ve elenen
     alternatifler `GameBoard.REVIVE_RESCUE_DEPTH` yorumunda.
   - Kaldırılan parçalar **skor, merge sayacı ve bonus sandık ilerlemesi
     ÜRETMEZ** (§10.3'teki kuralın aynısı) ve güç envanteriyle ilgisizdir.
     Kurtarma temizliği Bomba/Temizleyici kullanımı SAYILMAZ.
2. **Taşma sıfırlanır**: sayaç, danger durumu ve fail-pending temizlenir.
3. **1.5 saniyelik koruma penceresi** açılır; bu süre boyunca taşma
   birikmez. **STACK ETMEZ.** Bitince normal 1.5 sn `OVERFLOW_GRACE` kuralı
   aynen geri döner.
4. **Fizik ve girdi geri gelir**; güç çubuğu tekrar açılır, stoklar kaldığı
   yerden devam eder.

> **Ölçüm (level 10, rastgele oynayan bot, n=10):** devam olmadan bir round
> medyan **34 sn**. Devam sonrası median **12 sn** daha oynanıyor ve board'un
> %42'si kalkıyor — yani devam gerçek bir ikinci şans, ama round'u yeniden
> başlatmıyor.

### 11.5 Kazanma ve sonsuz mod

Devam kullanıldıktan sonra level kazanılırsa **normal kazanma**: normal
yıldız, normal sandık, normal merge ödülleri. **Devam cezası YOK.**

Sonsuz modda revive aynen çalışır (kodda `is_endless` dalı yoktur); rekor
kaydı yine tek `round_finished` sinyaline bağlı olduğu için mevcut endless
kuralları değişmez.

### 11.6 Durum: gerçek reklam BEKLİYOR

> **STATUS: revive foundation complete / real rewarded ad pending.**
>
> AdMob SDK **kurulmadı.** "DEVAM ET" butonu yalnızca
> `rewarded_revive_requested` sinyalini yayar; sağlayıcı bağlanana kadar
> pencerede "Ödüllü reklam henüz bağlı değil." yazar ve teklif açık kalır.
> **Sahte reklam ve otomatik bedava devam YOKTUR.**
>
> Sağlayıcı `main.gd` üzerinden bağlanacak (`set_rewarded_provider`); beklenen
> akış: `rewarded_revive_requested` → rewarded ad göster → *reward earned* →
> `Main.grant_revive()`. Ödül gelmezse `Main.notify_rewarded_unavailable()`.
>
> Devam penceresinin **final art'ı YOK**: mevcut kawaii UI temasının panel ve
> buton stilini kullanıyor, kendi asset'i yok.

---

## 12. Geçiş (interstitial) reklamı, banner yüzeyleri ve onboarding dikişi (M8.9-02, owner kararı)

> **STATUS:** test reklamıyla bağlı, deterministik testli, masaüstü görsel
> inceleme yapıldı; **A36 cihaz kapısı bekliyor**. Üretim engelleri (UMP
> sarmalayıcı boşluğu, COPPA, gerçek kimlikler) açık — docs/monetization/.

### 12.1 Banner yüzeyleri (KİLİTLİ)
GÖSTER: Ana Sayfa, Harita, Mağaza, Koleksiyon, oyun ekranı. GİZLE: sonuç ekranı,
tam ekran reklam anları, onboarding tamamlanmamış (yuva da yok). Banner gerçek
ayrılmış alandır (yuva): oyun kabı, güç butonları, nişan/bırakma kontrolleri,
Harita düğümleri ve OYNA plakasının üstüne ASLA binmez. Oyun: **fizik, kap
ölçüleri, FLOOR_Y, taşma çizgisi, yarıçaplar, güç davranışı DEĞİŞMEZ** —
yalnız kamera/yerleşim (16:9'da kompakt aralıklar + kap ölçeği −%10; A36'da
L1–L3 değişmez, L4+ ≤ −%6). Harita: dünya yuvanın üstünde biter (16:9'da zemin
dikeyde ≤ %4 sıkıştırılır, düğümler aynı dönüşümle).

### 12.2 Geçiş reklamı politikası (KİLİTLİ)
- **Uygunluk:** `INTERSTITIAL_INTERVAL_SEC = 900` saniye **AKTİF ön plan**
  süresi. Sayılmaz: arka plan / ekran kapalı, UMP formu, ödüllü ya da geçiş
  reklamı ekranda, onboarding tamamlanmamış. Oyun içi normal pencereler sayılır.
- **Gösterim yeri — yalnız doğal mola:** round KESİN bitti + devam kararları
  tamamlandı + sonuç ekranından ÖNCE. Aktif oyunun ortasında, devam teklifinde,
  ödüllü reklamda, sandık reveal'inde, UMP formunda, tutorial'da ASLA.
- **Hazır değilse sonuç HEMEN açılır**; sonuç asla reklam yüklemesi ya da
  bekleme için bekletilmez; uygunluk korunur, sonraki molada denenir.
- **Saat sıfırlama:** yalnız gerçek tam ekran gösterim başlayınca (SDK
  "gösterildi"); uygunluk, yükleme hatası, hazır olmayan mola sıfırlamaz.
- **Bekleme:** `FULLSCREEN_AD_COOLDOWN_SEC = 60` aktif saniye — herhangi bir
  tam ekran reklam (ödüllü ya da geçiş) kapanışından sonra geçiş reklamı
  bastırılır; art arda iki tam ekran reklam yok. Ödüllü ile geçiş aynı anda
  olamaz (tek tam ekran reklam).
- Test birimi Google'ın resmi interstitial test kimliği; gerçek kimlik YOK.

### 12.3 Onboarding dikişi ve ilk gün kuralı (M8.10 — UYGULANDI)
Kayıt alanları `onboarding_completed` + `onboarding_completed_day`: yeni kayıt
**false / ""**, eski kayıt ilerleme kanıtıyla (level > 1 / yıldız / merge /
sonsuz rekoru / açılmış skin) **true**, tamamlanma günü **UYDURULMAZ** (boş
kalır = yerleşik oyuncu, bastırma yok).

`onboarding_completed == false` iken: banner yok (tam düzen), geçiş reklamı
yok (saat durur), **UMP/rıza akışı hiç başlamaz** (tutorial'ın üstüne form
gelmesin; rıza şartı kaldırılmadı, yalnız ertelendi — ilk reklam talebinden
ÖNCE mutlaka çalışır), otomatik günlük pencere ve Mağaza günlük kartı yok,
Ana Sayfa Günlük madalyonu pencere açmaz, **günlük giriş ödülü işlemi
çalışmaz (kayıt mutasyonu yok)**, ödüllü devam/refill sunumu yok.

Tutorial bitince (ya da ATLA ile) **tek transaction**:
`onboarding_completed = true` + `onboarding_completed_day = <yerel gün>`
(+ `last_seen_day_key` ileriye). Ardından
`MonetizationManager.set_onboarding_completed(true)` — ama **tutorial'dan
doğan Level 1 round'unun ORTASINDA DEĞİL**: banner yuvası o anda açılıp kabı
yeniden yerleştirmez, monetizasyon bir sonraki güvenli geçişte (kabuk ekranı
ya da yeni round) açılır. Bu erteleme GEÇİCİ bir sunum bayrağıdır, kayda
yazılmaz.

**İlk gün kuralı (owner kararı, KİLİTLİ):** tutorial'ın bitirildiği takvim
gününde GÜNLÜK ÖDÜL SİSTEMİNİN TAMAMI kapalıdır — +15 giriş ödülü yok, seri
ilerlemez, otomatik pencere açılmaz, ücretsiz/reklamlı sandık ve reklamlı
+150 yok, Mağaza bölümü gizli, Ana Sayfa madalyonu nokta göstermez ve açmaz.
Kaçırılan ödül SONRADAN telafi edilmez. Ertesi yerel günde sistem sıfırdan
başlar: seri 1. gün, +15, tek otomatik pencere, tam kotalar. Tek yetkili
kapı `Onboarding.daily_rewards_unlocked()`; kontrol modeldedir, UI'da değil.
**Monetizasyonun açılması ≠ günlük ödüllerin açılması** — aynı gün reklamlar
çalışabilir, günlük sistem ertesi güne kadar kapalı kalır.
Ayrıntı: [docs/TUTORIAL_SYSTEM.md](docs/TUTORIAL_SYSTEM.md).
