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

### 1.1 Onboarding ipucu (owner onayı, M8 art turu)

Level 1'de ilk drop'a kadar `tutorial_pose` karakteri + "sürükle • bırak"
ipucu gösterilir, ilk bırakışta söner.

Yalnızca level 1'de; sonsuz modda ve diğer level'larda hiç görünmez.
Konumu kabın ağzı ile taşma çizgisi arasında hesaplanır (kap genişliği
level'a göre değiştiği için sabit koordinat değil). Kalıcı bir tutorial
akışı değil — tek ekranlık, tek seferlik bir ipucu.

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

> **DURUM: functional equip complete / final skin art pending.**
> Kazan → koleksiyonda gör → seç → kaydet → oyunda uygulan döngüsü uçtan uca
> çalışıyor. Ancak `resources/skins/*.tres` içindeki renkler **prosedürel
> placeholder** (20 skin boyunca sabit 49.3° hue spirali) ve yiyecek
> isimleriyle örtüşmüyorlar — "Kırmızı Biber" sarı-yeşil, "Altın Hamur"
> turkuaz. Ayrıntılı envanter ve karar seçenekleri: `SKIN_ART_AUDIT.md`.
>
> Skin'in nasıl çizildiği tek bir değiştirilebilir katmanda
> (`scripts/game/skin_visual.gd`): sanat turu geldiğinde kayıt formatı,
> equip akışı ve oyun kodu değişmeden yalnızca o dosya güncellenecek.
> **"Skin sistemi tamamlandı" DENMEZ** — işlevsel altyapı tamam, sanat değil.

### 5.4 Günlük döngü
- Günlük giriş ödülü (küçük, sabit) + ardışık gün sayacı (streak)
- Ödül miktarı: **15 Hamur** — §5.2'deki oranlarla aynı gerekçeyle GEÇİCİ
- Seri kırılırsa sayaç sıfırlanır — bu v1.1 reklam/monetizasyon kapısını
  açar ama v1'de sadece görüntülenir, işlevsel bir ödeme yok

### 5.5 Level haritası
- Level'lar bir yol üzerinde sıralı düğümler; kilitli level bulanık/gri,
  açılınca kısa bir "unlock" animasyonu
- **Görsel yol haritası henüz YOK** — "Harita" sekmesi şimdilik mevcut
  grid'i gösteriyor, ayrı bir art entegrasyon turunda gelecek.

### 5.6 Mağaza (M8'de eklendi)

Sahip olunmayan skin'ler Hamur ile satın alınır. **Gerçek para / IAP YOK** —
PROJECT_CONTEXT'teki non-goal aynen geçerli, tek para birimi oyun içi Hamur.

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

## 6. Ses tasarımı

> **Ses dosyaları (M6):** Kenney.nl CC0 placeholder — owner kendi asset'leriyle
> değiştirecek. **Dosya isimleri sabit tutulmalı** ki değişim kod dokunmadan
> olsun; `assets/audio/` altındaki dosyanın üzerine aynı isimle yazmak yeterli.
> Eşleşme tablosu ve kaynaklar: `assets/audio/CREDITS.md`.
> Bus yapısı: Master → SFX / Music (`default_bus_layout.tres`).
> Tier başına pitch escalation tek sample üzerinden yapılıyor, ayrı dosya yok.

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
