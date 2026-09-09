# PROJECT_STATUS.md — Squishy Merge, tam proje raporu

**Son güncelleme:** 2026-09-09 · **Durum:** M0–M8 tamamlandı, M8.5
(release/product stabilization) sürüyor, M9 (Android export) sırada ·
**Branch:** `main`

---

## Bu dosya ne işe yarıyor

Bu, projenin **anlatı hâlindeki tam tarihçesi**: ne yapıldı, hangi kararlar
alındı, **neden** öyle karar verildi, ne ölçüldü ve ne ölçülmedi. Hedef, bu
dosyayı okuyan yeni bir geliştiricinin (insan ya da AI) projeye sıfırdan
hakim olabilmesi.

Diğer dokümanlarla ilişkisi — **bu dosya hiçbirinin yerine geçmiyor:**

| dosya | rolü |
|---|---|
| `PROJECT_CONTEXT.md` | **Kısa ve güncel durum.** Kapsam, non-goal'lar, blokajlar, sıradaki iş. Hızlı bakış için önce burası. |
| `GAME_DESIGN.md` | **Kilitli tasarım spec'i.** Sayılar ve kurallar burada; owner onayı olmadan değişmez. Çelişki olursa **GAME_DESIGN kazanır**, bu dosya değil. |
| `CLAUDE.md` | Çalışma disiplini, Godot sürüm uyarısı, git akışı. |
| `DEVLOG.md` | Milestone başına tek satır, kronolojik ham kayıt. |
| `assets/visual/CREDITS.md` | Görsel asset'lerin kaynağı ve teknik detayı (uzun, çok değerli). |
| `assets/audio/CREDITS.md` | Ses asset'lerinin kaynağı. |
| **`PROJECT_STATUS.md`** | **Bu dosya.** Tarihçe + gerekçeler + envanter + kalan işler. |

> **Öncelik sırası (CLAUDE.md'den):** owner'ın en son açık talimatı >
> `GAME_DESIGN.md` (kilitli sayılar) > `PROJECT_CONTEXT.md` (durum) >
> `PROJECT_STATUS.md` / `DEVLOG.md` (tarihçe, otorite değil) >
> `OWNER_WORKING_PROFILE.md`.
>
> Yani **bu dosya kural koymaz.** Buradaki bir cümle kilitli bir sayıyla
> çelişirse GAME_DESIGN ve kod kazanır.

---

## 1. Proje konsepti ve hedef kitle

**Squishy Merge**, fizik tabanlı (Suika Game / watermelon-game tarzı) bir
dumpling birleştirme oyunu. Üstten kaba düşen dumpling'ler aynı tier'da
çarpışınca birleşip bir üst tier'a evriliyor.

- **Tema:** sevimli/kawaii squishy dumpling karakterleri, ASMR/rahatlatıcı his
- **Yapı:** 10 sabit level + level 10 sonrası açılan sonsuz mod
- **Platform:** Android (Google Play), portrait, 720×1280 viewport
- **Oturum:** 30-90 saniyelik kısa round'lar

**Hedef kitle:** casual mobil oyun oynayan geniş kitle; özellikle merge/idle/
ASMR-cozy oyun sevenler, kısa oturumları tercih edenler.

**Çözmeye çalıştığı boşluk:** mevcut merge oyunlarının çoğu ya karmaşık
grid-tabanlı sistemler (fazla UI/kural) ya da zayıf duyusal geri bildirim
sunuyor. Squishy Merge basit fizik + güçlü duyusal tatmin (squash-stretch,
escalating ses, combo efekti) + net/kısa level ilerlemesi ile bu boşluğu
hedefliyor.

### İş modeli

- **v1:** reklamsız, gerçek para yok, IAP yok. Amaç organik/ASO testi ve
  gerçek retention verisi toplamak.
- **v1'de oyun içi mağaza VAR** ama gerçek para geçmiyor — "Hamur" adlı soft
  currency ile kozmetik skin alınıyor. Bu bir para sink'i, IAP değil.
- **v1.1+ (şimdi YAPILMIYOR):** ödüllü reklam, muhtemel kozmetik IAP. Gerçek
  kullanıcı verisi olmadan bu katmana zaman harcanmıyor.

### Başarı ölçütü

v1 için başarı = **Play Console kapalı test track'inde canlı, crash'siz, tam
oynanabilir bir build.** Ticari/growth kararları v1.1'de gerçek veriyle
alınacak; şimdi tahmin veya vaat yok.

### Non-goal'lar (v1'de bilinçli olarak YAPILMIYOR)

Çoklu kavanoz/tema · IAP/reklam/ödeme · haptic feedback · leaderboard ·
bulut kayıt · hesap sistemi · backend/sunucu · **otomatik test framework'ü
(GUT vb.)** · iOS build.

> Otomatik test framework'ü bilinçli bir non-goal: bu ölçekte
> disproportionate overhead. Yerine **manuel playtest checklist**
> (GAME_DESIGN §9) ve **headless bot simülasyonu** (`tools/bot_runner.gd`)
> kullanılıyor. Bot, denge ölçümü için gerçek fizikle gerçek `GameBoard`
> oynatıyor — bu projede "test" denince kastedilen şey büyük ölçüde budur.

---

## 2. Teknoloji ve ortam

| | |
|---|---|
| Motor | **Godot 4.6.3-stable**, GDScript |
| Render | Mobile renderer, D3D12 (Windows) |
| Fizik | Godot 2D fizik, `RigidBody2D`, yerçekimi 1200 |
| Viewport | 720×1280, `canvas_items` stretch, `expand` aspect, portrait kilitli |
| Hedef | Android → Google Play (Play App Signing, AAB) |
| Repo | https://github.com/oguzhanbilgi/Squishy-Merge |
| Yerel yol | Makineye göre değişir (ev: `C:\dev\squishy-merge`, iş: `D:\dev\squishy-merge`) — **sabit yol varsayma** |

### ⚠️ Godot sürümü — kritik uyarı

Projeyi **SADECE 4.6.3** ile aç. İş makinesinde kanonik kopya:
`C:\Users\ledaj\AppData\Local\Godot463\Godot_v4.6.3-stable_win64.exe`

Başka bir Godot kurulumuyla açmak `project.godot`'u **sessizce 4.7'ye
çeviriyor** (`config/features` yeniden yazılıyor) ve o sürümün export
template'leri 4.6.3 ile uyumsuz olduğu için Android export'u bozuyor.
**Bu iki makinede de birer kez oldu** (M7'de yakalandı).

- **Belirti:** `git diff project.godot` içinde
  `config/features=PackedStringArray("4.7", ...)`
- **Çözüm:** `git checkout -- project.godot`, doğru binary ile tekrar aç

### Ortam durumu (2026-09-09'da iş makinesinde doğrulandı)

| bileşen | durum |
|---|---|
| Godot 4.6.3 | ✅ `4.6.3.stable.official.7d41c59c4` |
| Export template'leri | ✅ `4.6.3.stable` kurulu (`android_debug.apk`, `android_release.apk`, `android_source.zip`). `4.7.2.stable` seti de duruyor, zararsız. |
| Android SDK | ✅ `%LOCALAPPDATA%\Android\Sdk` — platform-tools, build-tools 36.0.0/36.1.0/37.0.0, platforms android-34/35/36/36.1, ndk 28.2.13676358, cmdline-tools |
| JDK | ✅ Godot **JDK 17**'yi kullanıyor (`C:\Program Files\Microsoft\jdk-17.0.16.8-hotspot`, editor settings'te tanımlı) |
| Debug keystore | ✅ `%APPDATA%\Godot\keystores\debug.keystore` |
| `ANDROID_HOME` / `ANDROID_SDK_ROOT` | ⚠️ **boş** — ama sorun değil, Godot yolu kendi editor settings'inden okuyor |
| PATH'teki `java` | ⚠️ Java **26** — Godot bunu kullanmadığı için çakışma yok |
| `export_presets.cfg` | ❌ **yok** (gitignore'lu, M9'da oluşturulacak) |
| Release/upload keystore | ❌ **yok** (sadece debug var) |

---

## 3. Milestone tarihçesi — M0'dan M8'e

Kaynak: `DEVLOG.md` + commit geçmişi + `GAME_DESIGN.md` içindeki karar
notları.

### M0 — Ortam ve iskelet (2026-09-05)

Ortam doğrulandı, proje iskeleti kuruldu: klasör yapısı, `main.tscn`, üç
autoload (`GameState` / `AudioManager` / `SaveManager`), mobil portrait
ayarları.

- **İlk blokaj:** dokümanlar Godot 4.7.2 diyordu, kurulu olan 4.6.3'tü.
  4.6.3'te karar kılındı, tüm doküman referansları düzeltildi.
- Export template'leri (4.6.3.stable) kuruldu, debug keystore oluşturuldu.

### M1 — Çekirdek fizik ve merge (2026-09-05)

8 tier config, `RigidBody2D` dumpling, drag-drop kontrolü, merge +
squash-stretch + pop efekti, tier 8 kutlaması, 1.5 sn taşma fail state.

**Ölçümle alınan kararlar:**

- **Oynanabilir yükseklik 880 → 400 px.** 880'de kap taşmıyordu, round
  bitmiyordu. 400 px'te ~11-12 adet tier 5 ile taşma oluyor — gerilim var
  ama adaletsiz değil. Bu değer o günden beri **tüm level'larda sabit**.
- **Squash-stretch çarpma hızına orantılı** (0.08-0.25 sapma, ~120 ms,
  130 ms debounce). İlk deneme (0.05-0.2) owner'a "cansız" geldi.
- **Duvar ve tabana da `PhysicsMaterial`** verildi (bounce 0.13, efektif
  ~0.24). Yoksa yalnızca dumpling-dumpling çarpışmaları zıplıyordu ve kap
  ölü hissettiriyordu.
- **Gövde fizikte serbest döner** — bu M1'de kilitlendi ve hâlâ geçerli.

**O zamanki açık sorun:** tier yarıçapları kaba göre küçüktü; M2'ye
devredildi (ve asıl olarak M8'de çözüldü).

### M2 — Level sistemi ve ilk balans (2026-09-05)

Level datası **data-driven** hâle geldi: `.tres` Resource'lar, klasör
tarayan `LevelLibrary`. Kod değiştirmeden yeni level eklenebiliyor. 10 level
+ sonsuz mod, level seçim ve sonuç ekranları.

- **Kap genişlikleri ölçümle belirlendi:** 600 / 540 / 480 / 420 / 370.
- **Merge puan tablosu kilitlendi:** tier 2:50, 3:70, 4:90, 5:110, 6:130,
  7:150, 8:200.
  **Neden:** önceki tablo (30/40/50/60/70/80/100) tier 8'de sadece ~2630
  puan veriyordu ve level 10'un "skor ≥ 5000" hedefini pratikte imkânsız
  kılıyordu. Yeni tabloyla tier 8'e ulaşan oyuncunun skoru medyan ~4740
  (p5 4360 / p95 5150) — hedefe 2-3 merge kalıyor, yani hedef anlamlı ama
  ikinci bir yığın kurmayı gerektirmiyor.

### M3 — Sandık, skin kataloğu, yıldızlar (2026-09-05)

Rarity kurası (60/25/12/3, **20.000 kurada doğrulandı**), 20 skinlik
data-driven katalog, duplicate→Hamur dedupe (bu kural M8.5'te değişti,
bkz. §4.8), her 75 merge'de bonus sandık,
teselli ödülü, gecikmeli yıldız + sandık reveal animasyonu.

**Yıldız formülü iki kez değişti:**

1. Önce deterministik çarpanlar (minimum × 1.15 / × 1.35).
2. Sonra **percentile tabanına** çevrildi: 2★ = p50, 3★ = p85.
   Dağılım Monte Carlo ile üretiliyor (`tools/star_thresholds.py`, 40.000
   örnek). **Neden geçerli:** bir tier'a ulaşmak için gereken merge sayısı
   oyuncu becerisinden bağımsız; beceri sadece hayatta kalıp kalmadığını
   belirliyor. Dolayısıyla "hedefe ulaşıldığı andaki skor" dağılımı
   simülasyonla doğru çıkıyor.

### M4 — Koleksiyon albümü (2026-09-05)

20 skinlik grid, açılmamışlar silüet, rarity çerçevesi, Hamur/ilerleme
sayacı.

### M5 — Günlük döngü (2026-09-05)

Günlük giriş ödülü (15 Hamur, sabit) + ardışık gün sayacı. Seri kırılırsa
sıfırlanıyor ve oyuncuya söyleniyor. **Cihaz saati geriye alınırsa ödül
verilmiyor** (basit exploit koruması).

### M6 — Ses (2026-09-06)

Kenney.nl CC0 placeholder SFX (7 dosya), Master → SFX/Music bus yapısı,
`AudioManager` kimlik tabanlı çalmaya geçti, combo zinciri ve danger sesi.

- **Tier başına pitch escalation tek sample üzerinden** yapılıyor, tier
  başına ayrı dosya yok.
- **Dosya isimleri sabit** — owner kendi seslerini aynı isimle üzerine
  yazarsa kod hiç değişmiyor.
- **Blokaj:** kazanma/kaybetme jingle seçimi kulakla doğrulanamadı (ortamda
  ses çözücü yok).

### M7 — İlk görsel geçiş (2026-09-07)

Kenney CC0 placeholder görselleri: tek gövde+yüz sprite'ı 8 tier'a
`TierConfig` paletiyle tint'lenerek uygulandı, UI Pack 9-patch teması 4
ekrana bağlandı, yıldızlar metin karakterinden sprite'a geçti.

- **Bu turda Godot 4.7.2 kazası oldu:** proje yanlışlıkla 4.7.2 ile açıldı,
  `project.godot` 4.7'ye çevrildi. Geri alındı ve `CLAUDE.md`'ye kalıcı
  uyarı eklendi.

### M8 — Büyük balans + juice + owner asset'leri (2026-09-08/09)

Projenin en yoğun milestone'u. Sırayla:

**a) Tier geometrisi yeniden ölçüldü.** Eski merdiven
(22/30/40/52/66/84/106/132) L9-L10'u fiilen kazanılamaz kılıyordu: headless
bot en dar kapta **20 koşuda tier 8'e bir kez bile ulaşamadı** (0/20).
Yalnızca tier 7-8'i küçültmek yetmedi (en iyi 2/20) — tepe doluluk tier 5-6
artıklarından da besleniyordu, o yüzden **merdivenin tamamı** yeniden
ölçeklendi: 22/27/34/42/52/65/81/100, büyüme oranı 1.26 → **1.241**.
Merge puan tablosuna dokunulmadı (skor modeli geometriden bağımsız), yıldız
eşikleri de geçerliliğini korudu.

**b) Juice/polish pası** (Kenney Particle Pack CC0): tier'a ölçekli merge
patlaması, kamera sarsıntısı, sprite parlama overlay'i, arka plan bokeh'i,
skor "+N" pop'u, sandık ışık patlaması, danger highlight'ı.

**c) Süre limiti tamamen kaldırıldı** (owner kararı) — aşağıda "Kilitli
kararlar"a bakın.

**d) UI teması** Kenney'den **Wenrexa "UI Casual Game Interface"** (CC0)
paketine geçti: camgöbeği aksan + koyu panel, 5 durumlu buton, sandık kartı
için `CardPanel` varyantı.

**e) Zorluk ayarı:** L4 tier 5→6, L6 tier 6→7, L8'e skor eşiği (6750).
Ölçüm **hedef tier artışının işe yaramadığını** gösterdi (L4/L6 hâlâ
%97/%100) — asıl kaldıraç kap genişliği ve skor eşiği.

**f) Tier paleti doygunlaştırıldı** ("candy" hedefi, hue sabit, saturation
+0.22). Sonra tier 1 bir tık daha açıldı (`#ffc368` → `#ffd08a`): 44 px
çapta gövde gradyanı yüzünden çamurlu okunuyordu.

**g) Owner'ın 8 dumpling karakteri** entegre edildi (ChatGPT üretimi).
Tint kaldırıldı, ayrı yüz katmanı ve parlama overlay'i kaldırıldı (ikisi de
sprite'a gömülü).

**h) Drop havuzu bag randomizer'a çevrildi** — aşağıda.

**i) Sonsuz mod:** tier 8 annihilation + kap genişliği 600 → 720.

**j) Mağaza + alt sekme navigasyonu:** Ana Sayfa / Harita / Koleksiyon /
Mağaza.

**k) Owner'ın 9 UI asset'i** (harita zemini, logo, kilitli skin silueti,
tehlike şeridi, rozet, banner, tutorial pozu, 2 adaptive icon katmanı).

**l) `icon_sheet.png`'den 7 HUD ikonu** kesildi ve bağlandı.

---

## 4. Kilitli tasarım kararları ve gerekçeleri

> Bunlar `GAME_DESIGN.md`'de kilitli. Değiştirmeden önce owner'a sor.

### 4.1 Tier merdiveni: 22/27/34/42/52/65/81/100

Sabit büyüme oranı **1.241**. Oran her adımda sabit olduğu için boyut farkı
gözle net okunuyor.

**Neden bu değerler:** en dar kap (370 px) tier 8'in 200 px çapına 170 px,
iki tier-7'nin yan yana 324 px'ine 46 px pay bırakıyor. Eski merdivende bu
paylar 106 px ve **−54 px** idi (yani sığmıyordu).

**Doğrulama yöntemi:** `tools/tier_geometry.py` alan modeliyle adayları
daraltıyor, ardından `tools/bot_runner.gd` gerçek fizikle karar veriyor.
Sonuç: L10 %40 (16/40), L9 %50 (15/30) — süre limiti kaldırılınca ikisi de
%43'e oturdu.

### 4.2 Süre/hamle limiti YOK — tek fail state taşma

**Owner kararı, M8. Tekrar sorulmasına gerek yok.**

Süre limiti konseptin "rahatlatıcı/ASMR" pozisyonuyla çelişiyordu.
`LevelData.time_limit` alanı, saat UI'ı ve süre dolunca kaybetme yolu
tamamen silindi.

**Ölçüm ne dedi:** limitler zaten pratikte bağlayıcı değildi. Kaldırmadan
önce/sonra bot sonuçları L9 %50→%43, L10 %40→%43 — fark gürültü içinde.
Koşular saat dolmadan çok önce taşmayla bitiyordu. Yani bu değişiklik
zorluğu değil, oyunun **hissini** değiştirdi.

### 4.3 Zorluğun asıl kaldıracı: kap genişliği ve skor eşiği

M8'in en önemli ölçüm bulgusu. Bot kazanma oranları:

| level | kap | hedef | kazanma |
|---|---|---|---|
| 4 | 540 | tier 6 | %97 (n=30) |
| 5 | 480 | tier 6 | %100 (n=30) |
| 6 | 480 | tier 7 | %100 (n=30) |
| 7 | 420 | tier 7 | %97 (n=30) |
| 8 | 420 | tier 7 + 6750 skor | **%70 (n=60)** |
| 9 | 420 | tier 8 | %43 (n=30) |
| 10 | 370 | tier 8 + 5000 skor | %43 (n=30) |

Hedef tier'ı artırmak L4/L6'da neredeyse hiçbir şeyi değiştirmedi. Süre
baskısı olmayan geniş kapta bot hedef tier 5 de olsa 7 de olsa kazanıyor.
L8'deki sıçrama (%97 → %70) tek etkili kaldıracın **skor eşiği** olduğunu
gösteriyor.

**L1-L7'nin kolay kalması bilinçli** (owner kararı): giriş/ısınma
level'ları, kolay olmaları rahatlatıcı konseptle tutarlı. Asıl zorluk
L8-L10'da. **Kap genişliği zorluk kaldıracı olarak kullanılmayacak.**

### 4.4 Bag randomizer (torba) — bağımsız rastgele DEĞİL

Owner L9/L10'u bitirdi ama **"adil hissetmedi"** dedi. Kök sebep: her drop
bağımsız uniform çekiliyordu, bu da oyuncunun elinden bağımsız şanssız
seriler üretiyordu.

Ölçüm (80 drop'luk round, 200.000 deneme) — en uzun aynı-tier serisi:

| model | medyan | p95 | max | 5+ seri içeren round |
|---|---|---|---|---|
| bağımsız uniform (eski) | 4 | 7 | 16 | **%48** |
| torba, tier başına 3 kopya | 3 | 4 | 6 | **%4.3** |

Kompozisyon adaleti de düzeldi: 80 drop'ta bir tier'i görme sayısı bağımsızda
p5-p95 = 20-34 iken torbada 26-27 (ideal 26.7).

**Torba:** tier 1/2/3'ten üçer kopya = 9 parça, karılır, sırayla çekilir,
boşalınca yeniden doldurulur. Round başına yeni torba.

**Neden 3 kopya, 2 değil:** 2 kopya 5+ serileri tamamen siler ama
"iki tane gördüm, üçüncüsü gelmez" diye tahmin edilebilir hâle geliyor.

**Bot kazanma oranlarında belirgin değişim YOK** — beklenen, çünkü torba
şanssız serilerle birlikte şanslı serileri de siliyor. Kazanım **algılanan
adalette** ve bot bunu ölçemiyor.

### 4.5 Tier 8 annihilation — YALNIZCA sonsuz modda

Sonsuz modda iki tier 8 çarpışınca **ikisi de yok olur**: büyük patlama,
güçlü sarsıntı, **+600 puan**, combo sayacına normal merge gibi katkı.

**Neden gerekli:** tier 8'ler birikip yer açmıyordu, oturum erken bitiyordu.

**Neden 600:** oyundaki en büyük tek seferlik ödül tier 8 oluşması (200)
idi; annihilation bunun 3 katı olarak açık ara en büyük ödül ama tipik bir
oturumun toplam skoru (~13.000) içinde baskın hâle gelmiyor.

**Level modunda bu kural YOK.** §1'deki "tier 8 oluşunca round otomatik
bitmez, parça normal parça gibi kalır" kararı level'larda aynen geçerli;
orada tier 8'ler birikmeye devam eder ve taşma riskinin parçası olur.
Ayrım `LevelData.is_endless` → `Dumpling.annihilates_at_max`.

**Ölçüm — beklenen etkiyi TAM vermiyor** (bot, sonsuz mod, n=24):

| | kapalı | açık |
|---|---|---|
| süre medyan | 68 sn | 65 sn |
| süre **p90** | 87 sn | **119 sn** |
| merge p90 | 194 | 265 |
| skor p90 | 16.760 | 23.540 |

Yani annihilation **tipik oturumu uzatmıyor**, üst dilimi belirgin biçimde
uzatıyor.

### 4.6 Sonsuz mod kap genişliği 720 — level genişliklerinden bağımsız

Annihilation tek başına tipik oturumu uzatmıyordu; **genişlik medyanı
hareket ettiren kaldıraç** çıktı (medyan süre 72→91 sn, merge 153→199,
n=20). Etki 720'de doyuyor (780/800 ek katkı vermiyor).

**Bedeli kabul edildi (owner):** viewport 720 px olduğu için sonsuz modda
yan duvarlar ekran dışında kalıyor. Taban, taşma çizgisi ve danger bandı
görünür kalıyor; level modu etkilenmiyor.

**Elenen iki alternatif:** 680'e düşmek (kazancın sadece üçte birini
veriyor) ve kamerayı %5 uzaklaştırmak (dokunmatik nişan koordinatlarının da
dönüştürülmesi gerekiyordu; headless bot girdi yolunu hiç kullanmadığı için
—doğrudan `_set_aim` çağırıyor— eklenecek düzeltme otomatik doğrulanamazdı).

### 4.7 Yıldız eşikleri — percentile tabanlı

2★ = p50, 3★ = p85, hedef tier'a ulaşıldığı andaki skor dağılımından:

| hedef tier | 2★ (p50) | 3★ (p85) |
|---|---|---|
| 4 | 160 | 210 |
| 5 | 430 | 530 |
| 6 | 1040 | 1190 |
| 7 | 2260 | 2430 |
| 8 | 4730 | 4990 |

Eşikler `TierConfig.SCORE_P50` / `SCORE_P85` dizilerinde **sabit** duruyor —
percentile kapalı formülle çıkmadığı için koddan hesaplanamıyor.
**Merge puan tablosu değişirse `tools/star_thresholds.py` tekrar
çalıştırılıp bu diziler güncellenmeli.**

**Bilinen istisna (kasıtlı):** L8 ve L10'un bitirme koşulundaki skor eşiği,
3★ eşiğinin çok üstünde. Yani **bu iki level'ı bitirmek her zaman 3★
veriyor.** Formüle istisna eklenmedi; ikisi de skor biriktirmeyi gerektiren
level'lar ve bitirmek başlı başına üst düzey başarı sayılıyor.

### 4.8 Sandık ve mağaza ekonomisi

**Sandık (kilitli, owner onaylı):**

- Her level tamamlanışında 1 sandık + her 75 merge'de bonus sandık
- Rarity: Common %60 / Rare %25 / Epic %12 / Legendary %3
  (20.000 kurada doğrulandı)
- İçerik: kozmetik skin **veya** Hamur. Duplicate skin otomatik Hamur'a
  çevrilir: 10/25/60/150 (rarity'e göre). Teselli ödülü 5 Hamur.
- Günlük giriş ödülü: 15 Hamur

**Mağaza fiyatları** (`scripts/game/shop.gd` → `PRICES`, tune edilebilir tek yer):

| rarity | fiyat | adet | toplam |
|---|---|---|---|
| Common | 50 | 8 | 400 |
| Rare | 150 | 6 | 900 |
| Epic | 400 | 4 | 1600 |
| Legendary | 900 | 2 | 1800 |
| | | **20** | **4700 Hamur** |

> ### ⚠️ AÇIK DENGE SORUNU — geç oyun Hamur enflasyonu (M8.5'te güncellendi)
>
> **M8'deki sorun çözüldü.** O zamanki kural "sandık, o rarity'de açılmamış
> skin varsa her zaman skin verir" idi ve mağaza **hiçbir şey satmıyordu**
> (üç senaryoda da 30. günde satın alınan: 0). M8.5'te sandık ödül tipi
> açık bir **%30 skin / %70 Hamur** rulesine çevrildi (GAME_DESIGN §5.2).
>
> Yeni ölçüm (`tools/shop_economy.py`, 5000 deneme/senaryo, Monte Carlo —
> sonuçlar yaklaşıktır):
>
> | oyuncu | 20/20 (p25 / medyan / p75) | 30. günde mağazadan alınan | 30. günde artan Hamur |
> |---|---|---|---|
> | kasual (3 round/gün) | 14 / **17** / 20. gün | 11 / 20 | 2.610 |
> | orta (5 round/gün) | 9 / **11** / 12. gün | 10 / 20 | 6.115 |
> | yoğun (10 round/gün) | 5 / **6** / 6. gün | 9 / 20 | 14.815 |
>
> **Mağaza artık çalışıyor** — medyan oyuncu koleksiyonun yaklaşık yarısını
> satın alıyor. Ama iki sorun kaldı:
>
> 1. **Koleksiyon hâlâ hızlı doluyor** — üç senaryoda da 30 gün içinde
>    tamamlanma %100; yoğun oyuncu 6 günde bitiriyor.
> 2. **Tamamlandıktan sonra Hamur'un alıcısı yok.** Tek sink mağaza ve o da
>    yalnızca 20 skin satıyor. Koleksiyonun tamamı 4.700 Hamur; yoğun oyuncu
>    30. günde bunun üç katından fazlasını biriktiriyor.
>
> Çözüm alternatifleri (skin sayısı, fiyat, gelir, ikinci sink) **owner
> kararı**. M8.5'te hiçbir fiyat veya gelir kaynağı değiştirilmedi.

### 4.9 Görsel/fizik ayrımı: sprite dönüşü ±20°

Gövde fizikte serbest dönmeye devam ediyor (M1 kararı) ama yüz sprite'ın
içine gömülü olduğu için, gövdeyle tam dönerse karakter baş aşağı kalıyor.

- Önce **tam ters dönüş** denendi (sprite dimdik): yüz okunuyordu ama yığın
  robotik ve cansız görünüyordu.
- Şimdiki hâl: sprite gövdeyi **±20°'ye kadar takip ediyor**, sonra
  sabitleniyor. `lerp_angle` ile yumuşatılıyor (gövde 180°'yi geçerken hedef
  açı +20°'den −20°'ye atlıyor; doğrudan atansa görünür sıçrama olurdu).
- **Fizik davranışı hiç değişmedi.**

---

## 5. Dosya/klasör yapısı ve script envanteri

```
squishy-merge/
├── project.godot            # 3 autoload, 720x1280 portrait, mobile renderer
├── scenes/
│   ├── main.tscn            # akış kontrolü (tek gerçek "sahne")
│   ├── game/                # dumpling, game_board, pop_effect
│   └── ui/                  # home_screen, level_select, collection_album,
│                            #   shop_screen, round_result, daily_reward_popup, tab_bar
├── scripts/
│   ├── autoload/            # GameState, AudioManager, SaveManager
│   ├── game/                # oyun mantığı
│   └── ui/                  # ekran mantığı
├── resources/
│   ├── levels/              # level_01..10.tres + endless.tres  (data-driven)
│   └── skins/               # 20 skin .tres                      (data-driven)
├── assets/
│   ├── audio/               # 7 SFX + CREDITS.md
│   └── visual/              # sprite'lar, fx/, ui/, icon/, ui_theme.tres, CREDITS.md
├── tools/                   # ⚠️ SADECE geliştirme araçları — export'ta filtrelenmeli
└── _visual_source/          # ⚠️ ham kaynaklar — export'ta filtrelenmeli
```

### Autoload'lar (sadece üç tane — dördüncüyü eklemeden gerekçelendir)

| script | işi |
|---|---|
| `autoload/game_state.gd` | Koşu-anı durumu: skor, merge sayısı, aktif level. Sinyal yayar (`score_changed`, `merge_performed`). |
| `autoload/audio_manager.gd` | Tüm SFX çalma noktası. Kimlik tabanlı (`play_sfx(&"merge", pitch)`). Bus: Master → SFX/Music. |
| `autoload/save_manager.gd` | Yerel kalıcı kayıt, JSON, `user://`. Bulut yok. |

### Oyun mantığı

| script | işi |
|---|---|
| `game/game_board.gd` | **En büyük dosya.** Kap geometrisi, drop kontrolü, merge çözümü, hedef takibi, taşma kontrolü, combo, sarsıntı, danger şeridi, level 1 tutorial ipucu. |
| `game/dumpling.gd` | Tek parça. Aynı tier çarpışınca `merge_requested` yayar. |
| `game/dumpling_visual.gd` | Görsel katman: tier sprite'ı, ±20° eğim, squash-stretch. |
| `game/tier_config.gd` | 8 tier'ın veri tablosu: yarıçap, isim, renk, merge puanı, yıldız eşikleri. |
| `game/level_data.gd` / `level_library.gd` | `.tres` level verisi + klasör tarayıcı. |
| `game/skin_data.gd` / `skin_library.gd` | Skin verisi + klasör tarayıcı. |
| `game/drop_bag.gd` | Bag randomizer (§4.4). |
| `game/chest_system.gd` / `chest_reward.gd` | Sandık kurası ve ödül nesnesi. |
| `game/shop.gd` | Fiyatlar ve satın alma. **Fiyat tune edilecek tek yer.** |
| `game/daily_reward.gd` | Günlük ödül + streak. |
| `game/pop_effect.gd` | Merge parçacık patlaması. |

### UI

| script | işi |
|---|---|
| `main.gd` | Sekmeler ↔ oyun ↔ sonuç akışını bağlar. Kurallar burada DEĞİL. |
| `ui/tab_bar.gd` | Alt sekme çubuğu (4 sekme). |
| `ui/home_screen.gd` | Ana sayfa: logo, streak, Hamur, "Oyna". |
| `ui/level_select.gd` | Harita: level grid + kilit rozetleri + sonsuz mod. |
| `ui/collection_album.gd` | Koleksiyon albümü. |
| `ui/shop_screen.gd` | Mağaza listesi + onay diyaloğu + toast. |
| `ui/round_result.gd` | Round sonu: yıldız reveal → sandık reveal. |
| `ui/reward_gem.gd` | Sandık ödül görseli: kapalı → açılış → rarity katmanları. |
| `ui/skin_swatch.gd` | Skin kartı görseli (açık: renkli daire, kilitli: silüet + kilit). |
| `ui/ui_icons.gd` | HUD ikonlarının tek tanımı, BBCode `[img]` üretir. |

### Geliştirme araçları (`tools/` — oyun çalışırken hiçbiri kullanılmaz)

| araç | işi |
|---|---|
| `bot_runner.gd` + `bot_brain.gd` | **Headless denge testi.** Gerçek `GameBoard`'u gerçek fizikle oynatır. Bu projedeki tüm kazanma oranı ölçümlerinin kaynağı. |
| `screenshot_runner.gd` + `screenshot_test.tscn` | Ekran görüntüsü üretir (merge, combo, skor pop, tutorial, danger, sandık, 4 sekme, kilitli harita). İkinci argümanla pencere ölçüsü verilebilir (`540x1170` → dar/uzun telefon testi). **`--headless` ile çalışmaz.** |
| `make_owner_sprites.gd` | Owner'ın ChatGPT görsellerini hazırlar: kırpma, küçültme, adaptive icon düzeltmeleri, `icon_sheet.png` parçalama. |
| `make_ui_sprites.gd` | Wenrexa UI paketinden tema sprite'ları. |
| `make_fx_sprites.gd` | Kenney Particle Pack'ten efekt parçacıkları. |
| `make_placeholder_sprites.gd` | Kenney Shape Characters (**artık kullanılmıyor**). |
| `tier_geometry.py` | Tier yarıçapı aday daraltma (alan modeli). |
| `star_thresholds.py` | Yıldız eşiği Monte Carlo. |
| `shop_economy.py` | Mağaza ekonomisi simülasyonu. |

---

## 6. Asset envanteri

Detay için **`assets/visual/CREDITS.md`** (uzun ve teknik olarak değerli) ve
`assets/audio/CREDITS.md`.

### Owner'ın kendi ürettiği (ChatGPT) — telifi owner'da

| ne | adet | nerede |
|---|---|---|
| Dumpling karakterleri (8 tier) | 8 | `assets/visual/dumpling_tier1..8.png` |
| Sandık (kapalı/açık) | 2 | `assets/visual/ui/chest_*.png` |
| UI asset'leri | 7 | harita zemini, logo, kilitli skin silueti, tehlike şeridi, rozet, banner, tutorial pozu |
| Adaptive icon katmanları | 2 | `assets/visual/icon/adaptive_*_432.png` (+ türetilmiş `launcher_main_192.png`) |
| HUD ikonları (`icon_sheet.png`'den kesildi) | 7 | dolu/boş yıldız, Hamur, kilit, taç, alev, bayrak |

**Ham kaynakları artık repoda:** `_visual_source/chatgpt_characters/` ve
`_visual_source/chatgpt_ui/`. Bu klasör 2026-09-09'da bilinçli olarak
gitignore'dan çıkarıldı — **başka hiçbir yerde yedeği olmayan** orijinaller
böylece GitHub'da yedeklenmiş oluyor.

### CC0 üçüncü taraf

| kaynak | ne | durum |
|---|---|---|
| **Wenrexa** — "Assets FREE: UI Casual Game Interface" | Buton + panel teması | ✅ kullanımda (`ui_theme.tres`) |
| **Kenney** — Particle Pack | fx parçacıkları (dot, sparkle, burst, ring) | ✅ kullanımda |
| **Kenney** — UI Pack | yıldızlar | ⚠️ **artık kullanılmıyor** (owner'ın sheet'iyle değiştirildi), dosyalar geri dönüş için duruyor |
| **Kenney** — Shape Characters | eski placeholder karakterler | ❌ kullanılmıyor |
| **Kenney** — ses paketleri | 7 SFX | ✅ kullanımda, owner değiştirecek |

> Lisans notu: Wenrexa paketinde lisans dosyası yok; CC0 bilgisi itch.io
> ürün sayfasındaki "Asset license" alanından geliyor. Kenney paketlerinde
> `License.txt` var.

### Henüz entegre EDİLMEMİŞ owner asset'leri

`_visual_source/chatgpt_ui/` altında duruyor, hiçbir yerden referans
verilmiyor:

| dosya | ne olabilir |
|---|---|
| `bg_scene.png` (1.7 MB) | Tam sahne arka planı — oyun tahtasının arkasına konabilir |
| `panel_frame.png` (932 KB) | Panel çerçevesi — `ui_theme.tres`'teki Wenrexa panelinin yerine |
| `btn_normal_a.png`, `btn_normal_b.png`, `btn_disabled.png` | Buton durumları — Wenrexa butonunun yerine |

**Bunlar için bir talimat gelmedi.** Kap duvarları hâlâ düz renk
(`Color("6b5a52")`), oyun arka planı düz koyu gri.

---

## 7. Bilinen açık sorunlar ve teknik borç

### Tasarım/ürün

| # | sorun | durum |
|---|---|---|
| 1 | **Geç oyun Hamur enflasyonu** (§4.8). M8.5'te mağaza çalışır hâle geldi (medyan oyuncu koleksiyonun ~yarısını satın alıyor) ama koleksiyon hâlâ 6-17 günde doluyor ve sonrasında Hamur'un alıcısı kalmıyor. | 🔴 **Owner kararı bekliyor.** Fiyat/gelir değiştirilmedi. |
| 2 | **L8 ve L10 bitirilince her zaman 3★** veriyor (§4.7). | 🟡 Kasıtlı, kabul edildi. |
| 3 | **Görsel yol haritası yok.** Harita zemininde çizili bir patika var ama **level düğümleri onu takip etmiyor** — düğümler hâlâ düz bir grid, zemin dekoratif. GAME_DESIGN §5.5'teki "yol üzerinde sıralı düğümler + unlock animasyonu" yapılmadı. | 🟡 Bilinçli ertelendi. |
| 4 | Açılmış skin'ler hâlâ placeholder (renkli daire). Skin başına ayrı görsel owner'dan gelmedi; sadece kilitli silüet gerçek asset. | 🟡 Asset bekliyor. |
| 5 | Sandık görseli her rarity'de aynı; Common-Legendary farkı yalnızca efekt katmanlarında. | 🟢 Owner'a soruldu, şimdilik böyle kalsın denmedi/denildi — düşük öncelik. |

### Teknik

| # | sorun | durum |
|---|---|---|
| 6 | **`danger_stripe.png` seamless değil** (kenar farkı ort. 0.16, en kötü 1.20). Bu yüzden tile edilmiyor, kap genişliğine **tek parça geriliyor**. Kap genişliği level'a göre değiştiği için germe zaten gerekliydi, ama yeni bir şerit gelirse aynı kısıt geçerli. | 🟡 Kabul edilmiş kısıt. |
| 7 | **Duvar dokusu yok.** Kap duvarları düz `Color("6b5a52")` dikdörtgen. `bg_scene.png`/`panel_frame.png` entegre edilirse buraya da doku gelebilir. | 🟡 Yapılmadı. |
| 8 | **`map_background.png` 1.8 MB** — tek başına kalan tüm görsellerden büyük. Fotoğrafik illüstrasyon PNG'de kötü sıkışıyor. Import ayarında lossy (WebP) yapılabilir. | 🟡 M9 APK bütçesi notu. |
| 9 | **Uzun ekranda oyun tahtasının altında boş alan.** `FLOOR_Y` sabit 1180, viewport 9:19.5'te 1560'a çıkıyor. Kap yukarıda kalıyor. | 🟡 M9 cihaz testinde görünecek. |
| 10 | **`tools/` ve `_visual_source/` export'ta filtrelenmeli.** Aksi hâlde AAB'ye ~73 MB gereksiz veri giriyor. `_visual_source/` artık repoda olduğu için bu **daha kritik**. | 🔴 **M9'da mutlaka yapılacak.** |
| 11 | Proje ikonu hâlâ Godot'un varsayılan robotu (`config/icon="res://icon.svg"`). Kompozit ikon üretildi ama `project.godot`'a bağlanmadı. | 🔴 M9/M10 öncesi. |
| 12 | `_visual_source/` içinde 4 zip (~17.6 MB) var ve bunlar yanlarındaki açılmış klasörlerin **birebir kopyası**. Repo boyutunun dörtte biri. | 🟡 Silinebilir; git geçmişinden çıkarmak history rewrite gerektirir. |
| 13 | Kazanma/kaybetme jingle'ı kulakla doğrulanmadı (M6 blokajı, hiç kapanmadı). | 🟡 Owner playtest'inde kontrol edilmeli. |
| 14 | **Gameplay/tooling RNG coupling (pre-existing).** Kamera sarsıntısı `_process` içinde `randf_range` çağırıyor — tamamen görsel ama `drop_bag.shuffle()` ile **aynı global RNG akışını** tüketiyor ve fizik kareleri arasında değişken sayıda çalışıyor. Sonuç: `tools/bot_runner.gd` tekrarlanabilir değil, aynı seed farklı sonuç veriyor ve ölçümler kararsız. M8.5-03'te keşfedildi; bot_runner'ın L10'da %22 vermesi bunun artefaktıydı (kontrollü harness'ta %43). | 🟡 **Bu turda DEĞİŞTİRİLMEDİ** (kapsam dışı). Kalıcı çözüm: drop_bag'e kendi `RandomNumberGenerator`'ını vermek. O zamana kadar denge ölçümleri seedli/`set_process(false)` harness ile yapılmalı. |

---

## 8. Kalan işler

### M9 — Android export

**Ortam neredeyse hazır** (§2'deki tabloya bakın). Godot, export
template'leri, Android SDK, NDK, JDK 17 ve debug keystore mevcut.

**Yapılacaklar:**

1. **`export_presets.cfg` oluştur** (Android preset). Dosya gitignore'lu,
   yani her makinede ayrı kurulacak.
2. **`exclude_filter` ayarla:** `tools/*, _visual_source/*`
   — bu olmadan AAB'ye ~73 MB gereksiz veri girer.
3. **Adaptive icon'ları bağla:**

   | preset alanı | dosya |
   |---|---|
   | `launcher_icons/adaptive_background_432x432` | `res://assets/visual/icon/adaptive_background_432.png` |
   | `launcher_icons/adaptive_foreground_432x432` | `res://assets/visual/icon/adaptive_foreground_432.png` |
   | `launcher_icons/main_192x192` | `res://assets/visual/icon/launcher_main_192.png` |

4. **`project.godot`'taki `config/icon`'u değiştir** — hâlâ Godot robotu.
5. **Release/upload keystore oluştur.** Şu an sadece debug var.
   **Şifre asla dosyaya/commit'e yazılmayacak**, owner'ın yerel makinesinde
   kalacak (`*.keystore`, `*.jks`, `keystore.properties` zaten gitignore'lu).
6. **Debug APK al, gerçek cihazda/emulatörde aç.** Crash olmamalı.
7. Dokunmatik girdiyi gerçek cihazda doğrula — bot girdi yolunu hiç
   kullanmıyor (`_set_aim`'i doğrudan çağırıyor), yani **sürükle-bırak
   gerçek parmakla hiç otomatik test edilmedi.**
8. Uzun ekran (9:19.5+) ve çentikli cihazlarda düzeni kontrol et (§7 #9).
9. APK/AAB boyutunu ölç; gerekirse `map_background` lossy import (§7 #8).

### M10 — Play Store submission

**🔴 Blokaj:** Google Play Developer hesabı henüz açılmadı / kimlik
doğrulaması bekliyor. Bu repo işinden bağımsız, owner tarafından paralel
yürütülmeli.

**Eksik olanların net listesi:**

| # | ne | durum |
|---|---|---|
| 1 | Play Console hesabı + kimlik doğrulama (25 USD tek seferlik) | ❌ |
| 2 | Uygulama kaydı, paket adı kesinleştirme (`com.<owner>.squishymerge` gibi) | ❌ |
| 3 | **Play App Signing** kurulumu + upload keystore | ❌ |
| 4 | İmzalı **AAB** | ❌ (M9'a bağlı) |
| 5 | Mağaza listesi: başlık, kısa/uzun açıklama | ❌ |
| 6 | **Feature graphic** (1024×500) | ❌ |
| 7 | **Telefon ekran görüntüleri** (en az 2, 16:9-9:16) — `screenshot_runner.gd` üretebilir ama mağaza için elle seçilmeli | ❌ |
| 8 | Uygulama ikonu (512×512 PNG, mağaza için ayrı) | ❌ |
| 9 | **Gizlilik politikası URL'i** — Play zorunlu tutuyor. Oyun veri toplamıyor (backend yok, analitik yok) ama yine de bir sayfa gerekiyor. | ❌ |
| 10 | Data safety formu | ❌ |
| 11 | İçerik derecelendirme anketi (IARC) | ❌ |
| 12 | Hedef kitle + içerik beyanı | ❌ |
| 13 | Kapalı test track'i + en az 12 test kullanıcısı (yeni hesaplar için Google'ın şartı) | ❌ |

> **Not:** Google, 2023 sonrası açılan bireysel geliştirici hesapları için
> production'a çıkmadan önce **kapalı testte 12 test kullanıcısıyla 14 gün**
> şartı arıyor. Başarı ölçütü zaten "kapalı test track'inde canlı build"
> olduğu için bu v1 hedefiyle uyumlu — ama takvim planlanırken hesaba
> katılmalı.

---

## 9. Yeni geliştirici için hızlı başlangıç

1. **Önce `CLAUDE.md`'yi oku** — özellikle Godot sürüm uyarısını.
2. Projeyi **4.6.3** ile aç. `git diff project.godot` boş kalmalı.
3. `PROJECT_CONTEXT.md` → güncel durum ve blokajlar.
4. `GAME_DESIGN.md` → kilitli sayılar. **Değiştirmeden önce owner'a sor.**
5. `assets/visual/CREDITS.md` → asset'lerin nasıl üretildiği, hangi
   teknik tuzakların ölçülerek çözüldüğü.

**Çalışma kuralları (CLAUDE.md'den, kısaca):**

- `git add .` **KULLANMA** — dosyaları açıkça isimlendirerek stage et.
- Force push yok, local geçmişi yok etme.
- `main` üzerinde direkt çalışılabilir (tek geliştirici).
- Commit formatı: `[M<no>] <kısa açıklama>`
- Milestone bitince `DEVLOG.md`'ye **tek satır** ekle.
- Final sanat üretmeye çalışma — owner kendi asset'lerini veriyor.
- Otomatik test framework'ü kurma.
- Milestone'u "bitti" demeden önce GAME_DESIGN §9 checklist'ini
  **gerçekten çalıştır.**

**Faydalı komutlar:**

Ekran görüntüsü üret (pencereli çalışır, `--headless` ile ÇALIŞMAZ):

```bash
godot --path . res://tools/screenshot_test.tscn -- <cikti_klasoru>
```

Dar/uzun telefon oranında kontrol:

```bash
godot --path . res://tools/screenshot_test.tscn -- <cikti_klasoru> 540x1170
```

Owner'ın görsellerini yeniden işle (kırpma, küçültme, ikon parçalama):

```bash
godot --headless --path . --script res://tools/make_owner_sprites.gd
```

Denge ölçümü (headless bot, gerçek fizik). `<level>`: 1-10, ya da `0` =
sonsuz mod. `<kosu>`: koşu sayısı — örnek, level 10'u 30 kez oyna:

```bash
godot --headless --audio-driver Dummy --path . res://tools/bot_test.tscn -- 10 30
```

Yıldız eşiklerini yeniden üret (merge puanları değiştiyse ZORUNLU):

```bash
python tools/star_thresholds.py
```
