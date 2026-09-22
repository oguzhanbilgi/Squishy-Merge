# PROJECT_STATUS.md — Squishy Merge, tam proje raporu

**Son güncelleme:** 2026-09-22 · **Durum:** M0–M8 tamamlandı; M8.5–M8.9
(release/product stabilization: UI yeniden inşası, gameplay cilası, ses,
AdMob monetizasyonu + günlük ödüller) main'de ve TEST reklamlarıyla A36'da
doğrulandı; sırada M8.10 ilk açılış tutorial'ı, ardından M9 (Android export) ·
**Branch:** `main` (9561a4c)

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

> **Güncellendi (M8.9, 2026-09-21).** Eski "v1 reklamsız, ödüllü reklam
> v1.1'de" cümlesi ARTIK GEÇERSİZ.

- **v1 (soft-launch öncesi plan):** ödüllü devam (revive) + ödüllü güç
  refill'i + banner (Ana Sayfa / Harita / Mağaza / Koleksiyon / oyun) +
  **geçiş reklamı** (15 dk aktif süre, yalnız round bitişi molası, 60 sn
  bekleme) + **günlük ödüller** (ücretsiz sandık 1/gün, reklamlı sandık 2/gün,
  reklamlı +150 Hamur 1/gün) — Google AdMob, `M8.9-01` ve `M8.9-02` **ikisi de
  main'de** (33b6382 / 9561a4c) ve Samsung A36'da TEST reklamlarıyla doğrulandı
  (docs/monetization/); üretim kimlikleri/hesap kurulumu ayrı adım. App-open
  / rewarded interstitial / mediation yok. IAP / Play Billing hâlâ yok.
- **v1'de oyun içi mağaza VAR** ama gerçek para geçmiyor — "Hamur" adlı soft
  currency ile kozmetik skin alınıyor. Bu bir para sink'i, IAP değil.
- **Sonra:** gerçek para Güç Paketi (GAME_DESIGN §5.7.4, billing yok),
  muhtemel kozmetik IAP — gerçek kullanıcı verisiyle.

### Başarı ölçütü

v1 için başarı = **Play Console kapalı test track'inde canlı, crash'siz, tam
oynanabilir bir build.** Ticari/growth kararları v1.1'de gerçek veriyle
alınacak; şimdi tahmin veya vaat yok.

### Non-goal'lar (v1'de bilinçli olarak YAPILMIYOR)

Çoklu kavanoz/tema · IAP/ödeme (Billing) · **app-open / rewarded interstitial
reklam, mediation, analitik SDK** (ödüllü + banner + interstitial + günlük
ödüller M8.9'da v1'e alındı) · native haptik plugin
(yerleşik titreşim M8.5-15'te v1'e alındı) · leaderboard ·
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

> ### ✅ ÇÖZÜLDÜ — ikinci sink eklendi (M8.5-05)
>
> Yukarıdaki iki sorundan **ikincisi** (Hamur'un alıcısı yok) çözüldü:
> dört güç artık Hamur ile satın alınabiliyor (GAME_DESIGN §5.7). Bu,
> oyunun ilk **tekrarlanabilir** sink'i — skin bir kez alınır ve biter,
> güç tükenir.
>
> **Skin fiyatlarına, sandık oranlarına ve Hamur gelir kaynaklarına
> DOKUNULMADI.** Birinci sorun (koleksiyon hızlı doluyor) hâlâ owner
> kararına açık; güç sink'i onu yalnızca 1-4 gün geciktiriyor.
>
> **Seçilen güç fiyatları:** Sarsıntı 100 · Bomba 120 · Temizleyici 160 ·
> Büyütücü 180 (`scripts/game/power_up_economy.gd` → `DOUGH_PRICES`).
>
> Fiyatın **şekli** gameplay değerinden türetildi (Büyütücü en pahalı: level
> tier hedefini doğrudan karşılayabilen tek güç). Fiyatın **seviyesi**
> tarandı (taban 80→200, `python tools/shop_economy.py sweep`).
>
> **Neden taban 120:** 140 ve üstü daha fazla Hamur EMMİYOR — güce giden
> Hamur 16.200'de doyuyor, artan tek şey karşılanmayan istek sayısı
> (27 → 42 → 71). Pahalıya kaçmanın ekonomik getirisi yok.
>
> #### Yeni ölçüm (`tools/shop_economy.py`, 4000 deneme/senaryo, 90 gün)
>
> ⚠️ **Güç kullanım sıklıkları VARSAYIM** — gerçek telemetry yok. Üç profil:
> düşük (~her 5-6 roundda 1), orta (~her 3-4 roundda 1), yüksek (~her 2
> roundda 1). Gerçek veri gelince yeniden kalibre edilmeli.
>
> **Kalan Hamur medyanı — enflasyon:**
>
> | oyuncu | | gün 30 | gün 60 | gün 90 |
> |---|---|---|---|---|
> | kasual (3/gün) | sink yok | 2.615 | 8.210 | 13.805 |
> | | **sink açık** | **1.515** | **4.865** | **8.200** |
> | orta (5/gün) | sink yok | 6.095 | 15.140 | 24.185 |
> | | **sink açık** | **1.995** | **5.170** | **8.245** |
> | yoğun (10/gün) | sink yok | 14.835 | 32.415 | 50.025 |
> | | **sink açık** | **325** | **335** | **335** |
>
> Yoğun oyuncunun 90 günlük fazlası **50.025 → 335 (%99,3)**; 51.220 Hamur
> güce gitti. Orta oyuncuda %66, kasualde %41 azalma.
>
> **Koleksiyon tamamlanma medyanı:** kasual 17→21, orta 11→15, yoğun 6→9 gün
> (önerilen rewarded cap ile 18/12/9). 30 gün içinde tamamlanma %92-99.
> Mağazadan alınan skin sayısı düşüyor (orta oyuncuda 10 → 4): oyuncu artık
> gerçekten **skin mi güç mü** seçiyor.
>
> **Kasual fakirleşmiyor:** karşılanmayan istek 0, 7. günde ~335 Hamur.
>
> #### Rewarded refill cap — ÖNERİ, implement EDİLMEDİ
>
> **ÖNERİ: günde 1 ödüllü refill, dört gücün TOPLAMI için** (round başına
> değil, gün başına). Ölçüm (yoğun oyuncu, 30. gün):
>
> | politika | Hamurla alınan | reklam/gün | 30. gün Hamur |
> |---|---|---|---|
> | rewarded yok | 119 | 0 | 325 |
> | **1/gün** | **108** | **1,0** | **1.395** |
> | 2/gün | 86 | 2,0 | 4.280 |
> | Model A (1/round, cap yok) | **0** | 4,9 | **14.915** |
> | Model B (1/round HER TİP) | **0** | 4,9 | 14.990 |
>
> **Round başına refill Hamur mağazasını tamamen öldürüyor.** Model A ve B
> normal kullanımda ayırt edilemiyor (oyuncu round başına ~0,5 güç istiyor);
> fark yalnızca spam altında çıkıyor — round başına 2 güç isteyen oyuncuda
> Model B günde **17,3 reklam** gerektiriyor ve her isteği bedava
> karşılıyor. **Model B elendi.** Asıl kaldıraç günlük cap.
>
> #### Gerçek para Power Pack — TASLAK, billing YOK
>
> | pack | içerik | Hamur değeri | yoğun oyuncunun geliri | round |
> |---|---|---|---|---|
> | Mini | her güçten ×3 | 1.680 | 3,1 gün | ~24 |
> | Power | her güçten ×6 | 3.360 | 6,2 gün | ~48 |
> | Mega | her güçten ×12 | 6.720 | 12,3 gün | ~96 |
>
> İlk taslak ×2/×5/×12 idi; ×2 Mini yoğun oyuncunun yalnızca 2,1 günlük
> gelirine denk geldiği (işleme değmeyecek kadar küçük) için ×3/×6/×12'ye
> çekildi. **TL/USD fiyat, product ID ve Play Billing YOK.**

> ### 📌 ÖDÜLLÜ GÜÇ CAP'İ KİLİTLENDİ — 1/gün (M8.5-06)
>
> M8.5-05 raporu "günde 1" ÖNERMİŞTİ ama yalnızca 1 ve 2 ölçülmüştü. Bu turda
> 1 / 2 / 3 ve kontrol olarak per-round modeli tam metrik setiyle karşılaştırıldı
> (`python tools/shop_economy.py caps`, 3000 deneme/senaryo, 90 gün).
>
> **Karar: günde 1 refill, dört gücün TOPLAMI için.**
> `scripts/game/rewarded_policy.gd` → `DAILY_POWER_REFILLS`.
>
> Yoğun oyuncu (10 round/gün, yüksek kullanım) — kararın verildiği senaryo:
>
> | cap | reklam/gün | bedava | Hamurla | bedava% | karşılanmayan | gün30 | gün60 | gün90 |
> |---|---|---|---|---|---|---|---|---|
> | yok | 0,00 | 0 | 379 | %0 | 67 | 325 | 320 | 330 |
> | **1** | **1,00** | **90** | **348** | **%20,5** | **8** | **1.380** | **2.570** | **3.735** |
> | 2 | 1,99 | 179 | 265 | %40,3 | 1 | 4.235 | 9.440 | 14.685 |
> | 3 | 2,92 | 263 | 182 | %59,1 | 0 | 7.490 | 16.565 | 25.610 |
> | cap yok (1/round) | 4,96 | 446 | 0 | %100 | 0 | 15.000 | 32.550 | 50.220 |
>
> **1, "mağazayı en çok koruyan" olduğu için seçilmedi** — marjinal
> fayda/maliyet hesabı:
>
> - 1/gün karşılanmayan güç isteğini **67 → 8 (%88)** düşürüyor, yani
>   oyuncunun yaşadığı mahrumiyetin neredeyse tamamını çözüyor.
> - 2/gün bunun üstüne 90 günde yalnızca **7 istek** daha karşılıyor (günde
>   0,08) ama 90. gün Hamur fazlasını **3.735 → 14.685'e (4 kat)** çıkarıyor.
> - **3/gün elendi:** 90. gün Hamur'u 25.610 — güç sink'i olmayan referansın
>   (50.025) yalnızca yarısı kadar aşağıda. M8.5-05'te çözülen enflasyona
>   yarı yola kadar geri dönmek demek. Ayrıca güçlerin %59'u bedava geliyor,
>   yani Hamur mağazası ikincil kaynağa düşüyor.
>
> Kasual (3 round/gün) tarafında 1/gün zaten isteklerin %84'ünü bedava
> karşılıyor; 2 ve 3'te %100 oluyor ve kasualdeki Hamur sink'i tamamen
> kayboluyor — daha yüksek cap'in orada da getirisi yok.
>
> **Reklam adedi ayırt edici değil.** Yoğun oyuncuda revive'ın *teorik*
> tavanı zaten 20 reklam/gün (10 round × 2 revive); güç capi 1 → 3 toplam
> tavanı yalnızca 21 → 23 yapıyor. Karar ekonomiye göre verildi, reklam
> yüküne göre değil.
>
> | round/gün | güç capi | güç reklam/gün | revive TAVANI/gün | toplam tavan |
> |---|---|---|---|---|
> | 3 | 1 | 1 | 6 | 7 |
> | 5 | 1 | 1 | 10 | 11 |
> | 10 | 1 | 1 | 20 | 21 |
>
> (Revive sütunu ulaşılamaz bir tavandır: yalnızca fail olan round'larda ve
> oyuncu kabul ederse oynar.)
>
> **Pack taslağı DEĞİŞMEDİ.** Yeni cap analizi Mini/Power/Mega ×3/×6/×12
> ladder'ında bir sorun göstermedi, o yüzden sessizce dokunulmadı.

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

### 4.10 Oyun ekranı görsel pası (M8.5-07)

M8.5-03/04/05/06 mekaniği ve monetization altyapısını bitirdi ama oyun
ekranı hâlâ prototip gibi duruyordu: **düz koyu gri zemin, çamurlu kahverengi
(`#6b5a52`) duvarlar, koyu generic Wenrexa panelli pencereler.** Mağaza ve
harita ekranları candy görünürken oyun ekranı başka bir üründen gibiydi.

#### Bağlanan owner asset'leri

Üçü de repoda **zaten duruyordu ama hiçbir yerden kullanılmıyordu**
(`_visual_source/chatgpt_ui/`):

| kaynak | çıktı | nerede |
|---|---|---|
| `bg_scene.png` | `ui/board_background.png` | Oyun ekranı zemini |
| `panel_frame.png` | `ui/panel_candy.png` + `ui/panel_candy_crown.png` | Devam + refill pencereleri |

**Zemin karartılıyor.** Kaynak parlak bir GÜNDÜZ karnavalı; ham hâliyle
dumpling'lerden parlak kalıyor ve zeminin kendi dumpling çizimleri oyun
parçalarıyla karışıyordu. Çalışma zamanında `modulate` (0.38, 0.36, 0.50)
+ alfa 0.50 scrim ile akşam hissine çekildi. Fizik geometrisine
DOKUNULMADI — zemin ayrı bir `CanvasLayer` (layer −1).

**Panel ikiye bölündü.** `panel_frame.png` 9-patch'e uygun değil: tepesinde
ortalanmış kanatlı kalp var, üst-orta şerit onu yatayda ezerdi. Kaynak
ölçülüp (çerçevenin düz üst kenarı y=131, tacın tabanı y=150) çerçeve ve
taç ayrı dosyalara çıkarıldı; çerçeve modal dikdörtgenine geriliyor
(oran farkı %1, görünmez), taç üstüne ortalanıyor.

#### Kap görünümü

Duvarlar `#6b5a52` → `#e8bfa8` (krem-pembe), taban `#d8a891` + ince açık iç
şerit. Kabın içine hafif koyu bir dolgu kondu: zemin tüm ekranı kapladığı
için kabın içi ile dışı aynı parlaklıktaydı ve "kap" okunmuyordu.

**Görsel duvar ile fizik duvarı ayrıldı:** `_draw_walls()` yalnızca çiziyor,
collider'lar `_build_walls()` içinde ayrı kuruluyor. `WALL_THICKNESS`,
`FLOOR_Y`, `RIM_ABOVE_LINE` ve kap genişlikleri DEĞİŞMEDİ.

#### Güç efektleri

Mekanik hiç değişmedi (impulse, hedef kuralları, stok tüketimi, skor/merge
etkisi aynı). Eklenen yalnızca sunum ve dört güç artık birbirinden renkle de
ayrılıyor (`PowerUp.ACCENTS`):

| güç | eklenen | renk |
|---|---|---|
| Bomba | hedefe kapanan kilitlenme halkası → büyüyerek fırlayan, yay çizen ve dönen mermi → genişleyen şok halkası + duman | pembe |
| Büyütücü | eski çaptan yeni çapa AÇILAN halka + yukarı parıltı sütunu + daha güçlü squash | altın |
| Sarsıntı | taban boyunca üç toz bulutu + kap kenarının kısa parlaması + geniş halka | camgöbeği |
| Temizleyici | ortak süpürme halkası (≥3 parça) + parça başına kısa yukarı iz | yeşil |

Normal merge'de halka YOK — halka bilerek güçlerin imzası, ikisi
karışmasın diye.

**Performans:** her efekt tek atışlık, ömrü < 0.6 sn, parçacık sayısı sabit
tavanlı (`FX_DUST_MAX` 20, `FX_SPARKLE_MAX` 16, Temizleyici izi parça başına
4). Tier 8 merge'i + güç efekti aynı anda oynasa bile toplam birkaç yüz
parçacık.

**RNG:** görsel rastgelelik ayrı bir `_fx_rng` üzerinden. Gameplay RNG
akışına (drop_bag / kamera sarsıntısı) dokunulmadı; mevcut RNG coupling
teknik borcu bu turda da refactor EDİLMEDİ.

#### Üst HUD

Yeni zemin yer yer parlak olduğu için HUD yazılarının arkasına yumuşak koyu
bir plaka kondu (`HUD/TopPlate`). Ayrıca skor pop rozeti hedef satırının
üstüne biniyordu: rozet küçültülüp pop sağ üst köşeye çekildi.

#### Balans doğrulaması

Hiçbir gameplay sabiti değişmedi — `tier_config.gd`, `drop_bag.gd` ve level
`.tres` dosyalarına dokunulmadı, `dumpling.gd` fizik satırları aynı.

`bot_test` L10'da 6/20 (%30) verdi. GAME_DESIGN §3'teki kilitli değer %43
(n=30). **Bu bir regresyon DEĞİL, bilinen ölçüm gürültüsü:** M8.5-03'te
kaydedildiği gibi `bot_runner` deterministik değil (kamera sarsıntısı
`_process` içinde global RNG tüketiyor) ve aynı kod için tarihsel olarak
%22–%43 arası sonuç vermişti. n=20'de %43'ün güven aralığı zaten %30'u
kapsıyor.

#### ⚠️ OWNER ASSET NEEDED

Bu turda **üretilmedi ve placeholder final sayılmadı**:

1. **Dört güç ikonu** — `power_bomb.png` / `power_upgrade.png` /
   `power_shake.png` / `power_clear.png` (kare, ~128 px, saydam zemin).
   Güç çubuğu ve refill penceresi hâlâ `PowerUp.GLYPHS` metin işaretlerini
   (`✸ ▲ ≈ ⌫`) gösteriyor. **Mimari hazır:** dosyalar konup
   `PowerUp.ICON_PATHS` doldurulunca ikisi de otomatik gerçek `Texture2D`'ye
   geçer, kod değişikliği gerekmez.
2. **Pastel bambu/ahşap duvar dokusu** — kap duvarları şu an düz pastel
   RENK. Bu bir renk düzeltmesidir, doku taklidi değil; gerçek doku
   geldiğinde `_draw_walls()` içindeki iki `draw_rect` bir
   `draw_texture_rect`e dönecek.
3. **Koyu gece varyantı `bg_scene`** (opsiyonel) — mevcut gündüz sahnesi
   çalışma zamanında karartılıyor; owner koyu bir varyant üretirse
   karartma gevşetilebilir.
4. **Candy buton seti** (`btn_normal_a/b`, `btn_disabled`) repoda VAR ama
   bağlanmadı — tema butonu tüm ekranlarda ortak, değiştirmek her ekranı
   yeniden stillendirmek demek. Owner kararı.

---

### 4.11 Final asset entegrasyonu (M8.5-08)

M8.5-07 mimariyi kurmuş ama iki asset'i eksik bırakmıştı (dört güç ikonu,
bambu duvar dokusu). Owner ikinci bir ChatGPT partisi üretti; bu tur onu
bağladı. Türetme `tools/make_gameplay_art.py` ile yeniden üretilebilir —
çıktının diskteki dosyalarla **byte-identical** olduğu doğrulandı.

Tam kaynak→çıktı tablosu ve reddedilenlerin gerekçesi:
`assets/visual/CREDITS.md` → "Final oyun ekranı asset'leri (M8.5-08)".

#### Bulunan asset sorunu: sahte şeffaflık

`board_wall_bamboo_vertical.png` **%100 opak** — satranç deseni gerçek
transparanlık değil, piksel olarak basılmış. Sıfır-alfa oranı ölçüldü:
**%0.0**. Ham hâliyle bağlansaydı kap duvarlarında gri-beyaz kareler
görünürdü. Desene değmeyen temiz sütun aralığı (x 350-677) ölçülüp
içinden yaprak süsü de içermeyen tek bir sütun kesildi (x 469-560).

#### Güç ikonları

Bomba / Büyütücü / Temizleyici tekil kaynak dosyalardan geldi. **Sarsıntı
tekil dosya olarak YOK**, yalnızca sheet'lerin içinde. 2×2 sheet'te temiz
bir dikey ayraç bulunmadığı (kesim komşu ikondan piksel taşırdı), 3'lü
sheet'te ise bulunduğu için (boş sütunlar 642-757 ve 1311-1408) kesit
oradan alındı. Sheet'lerin hiçbiri runtime'da kullanılmıyor.

#### Buton durumları: pill'ler aynı orana getirildi

Üç kaynak pill'in gövde oranı farklıydı: normal **2.45**, seçili **2.30**,
pasif **3.01**. Aynı dikdörtgene gerilselerdi uçlardaki yıldız süsleri
durum değiştikçe şekil değiştirirdi.

İki yaklaşım denendi ve **elendi**:

- **Düz alfa-bbox'a kırpma.** Dış parıltı gövdeden çok geniş ve neredeyse
  şeffaf; bbox onu da alınca pill butonun ancak **yarısını** dolduruyordu.
  Çözüm: gövde eşiği (alfa ≥ 150) + ölçülü parıltı payı (%7).
- **Kapak/orta sert kesimi.** Kesim yerinde görünür bir dikey Mach bandı
  kalıyordu, özellikle çok sıkışan gri pasif pill'de. Çözüm: sürekli bir
  sütun haritası — ölçek yıldız kapaklarında tam 1:1, farkın tamamı
  pill'in düz orta şeridinde soğuruluyor, arada smoothstep ile geçiyor.

Buton ölçüsü de kaynağın **doğal oranına** çekildi (172×86 = 2.0). İlk
denemede 164×104 (1.577) seçilmişti; pill'i ezip köşe yarıçaplarını
bozuyordu.

**Global tema DEĞİŞMEDİ.** `assets/visual/ui_theme.tres` beş ekranda ortak;
candy butonlar `scripts/ui/candy_button.gd` üzerinden yalnız oyun ekranına
ve iki penceresine tek tek uygulanıyor. Ana sayfa / harita / koleksiyon /
mağaza bu turda görsel olarak hiç değişmedi.

#### Stok-0 okunurluğu

İlk denemede stok 0 butonun TAMAMI `modulate` ile soldurulmuştu; yazı da
solunca "Bomba ×0" okunmaz hâle geldi (çekimle yakalandı). Solukluk artık
yalnızca pill dokusuna (`CandyButton.EMPTY_TINT`) ve ikona uygulanıyor,
yazı tam opak ve koyu kırmızı kalıyor.

#### Zemin: gündüz + ağır karartma → gerçek gece

Owner gerçek bir gece varyantı üretti (`gameplay_background_candy_night.png`,
941×1672 — 9:16'ya neredeyse tam oturuyor, merkezi koyu bir göl/yol, parlak
öğeler üstte ve kenarlarda). M8.5-07'nin ağır karartması **gevşetildi**:
`modulate` (0.38, 0.36, 0.50) → (0.82, 0.80, 0.92), scrim alfası
0.50 → 0.18. Kabın içindeki koyu dolgu (`WELL_COLOR`) **korundu** —
karakterlerin siluetini arka plandan ayıran şey o.

#### Kap: düz renk → bambu

`_draw_walls()` içindeki üç `draw_rect` iki `draw_texture_rect`e döndü.
**Fizik hiç değişmedi:** `WALL_THICKNESS`, `FLOOR_Y`, `RIM_ABOVE_LINE`,
kap genişlikleri ve `_build_walls()` aynı — diffle doğrulandı.

Görünür taban `FLOOR_APRON` (54 px) ile fizik tabanının **altına** iniyor:
yatay bambu rayı 20 px'e sıkıştırılsa boğumlar ve kalp süsleri okunmazdı.
Aşağı doğru büyüyor, oyun alanına girmiyor (FLOOR_Y 1180, viewport 1280).

> Sonsuz modda kap genişliği 720 = ekran genişliği, dolayısıyla dikey
> duvarlar ekran dışında kalıyor ve bambu görünmüyor. Bu M8'den beri
> böyle (düz renkte de görünmüyordu), regresyon DEĞİL.

#### VFX: prosedürel katman KALDIRILMADI

Owner asset'leri mevcut halka/toz/parıltı katmanlarının **yerine değil
üstüne** bindi: okunurluğu prosedürel katman taşıyor, karakteri asset
veriyor. Uçan bomba ile patlama **ayrı dosyalar** — uçan bomba görselini
"patlama" diye kullanmak yanlış olurdu.

Mermi çapı hedefe göre ölçekleniyor ama tavanlı (`tier 3` çapı): tier 8'e
atılan bomba hedefi kapatmasın. Büyütücünün yükselme sütunu `z_index = -1`
ile yeni parçanın ARKASINDA — dönüşen dumpling görünür kalmalı.

#### Taşma şeridi sakinleştirildi

`DANGER_STRIPE_ALPHA_IDLE` 0.55 → 0.34 ve sakin hâlde renk soğutuluyor
(`DANGER_STRIPE_IDLE_TINT`), tehlikede tam beyaza dönüyor. Yeni gece
zemininin üstünde eski değer sürekli alarm veriyordu ve şerit board'un en
parlak öğesiydi. **Mekanik değişmedi:** grace süresi, taşma alanı ve
`_danger_pulse` hesabı aynı; değişen yalnız çizim.

#### QA aracı

`tools/vfx_shots.gd` genişletildi: uçuştaki mermi, refill penceresi ve
devam penceresi çekimleri eklendi. Ayrıca `_fill_live()` eklendi — bot
bazen level 3'ün hedefini 10 bırakışta tamamlıyor, round bitince güç
çubuğu `set_enabled(false)` ile pasife düşüyor ve "normal güç çubuğu"
çekimi yanlışlıkla PASİF durumu gösteriyordu.

### 4.12 Tipografi sistemi (M8.5-09)

M8.5-08'e kadar oyunun HER yazısı Godot'un varsayılan fontu ve varsayılan
16 px'iydi — candy asset'lerin yanında "debug overlay" gibi duruyordu.
Bu tur iki font ailesi ve merkezi bir rol sistemi getirdi. **Mekanik,
ekonomi, fizik ve reklam kuralı DEĞİŞMEDİ**; diffte `tier_config`,
`drop_bag`, `dumpling`, `power_up_economy`, `rewarded_policy`,
`power_up_controller`, level `.tres` dosyaları YOK.

#### Font seçimi (kilitli art direction, owner)

| aile | ağırlık | iş |
|---|---|---|
| **Baloo 2** | ExtraBold 800 | pencere kahramanı ("Devam etmek ister misin?", "Bomba bitti", "Level 3 tamam!"), ekran başlığı |
| **Baloo 2** | Bold 700 | bölüm/kart başlığı, birincil CTA, level numarası |
| **Nunito** | Bold 700 | HUD, skor, stok, fiyat, "TAKILI", ikincil buton, sekme |
| **Nunito** | SemiBold 600 | gövde metni, kota/not satırları, rarity etiketi |

Kural: **başlık ve CTA Baloo, geri kalan her şey Nunito.** "Her şey Baloo"
bilinçli olarak yapılmadı — güç çubuğu ve koleksiyon kartı gibi dar
kutularda Baloo'nun tombulluğu okunurluğu düşürüyor. Kaynak resmi Google
Fonts (`fonts.gstatic.com` statik TTF'leri), lisans OFL 1.1, SHA ve
doğrulama `assets/fonts/CREDITS.md`.

#### Mimari: tema variation'ları + proje geneli varsayılan

- `assets/visual/ui_theme.tres` artık `default_font` (Nunito SemiBold 20)
  ve rol başına **type variation** tanımlıyor: `Display` 42, `ScreenTitle`
  38, `SectionTitle` 27, `CardTitle` 23, `Stat` 20, `Caption` 16,
  `HudPrimary` 25, `HudSecondary` 22, `HudObjective` (RichTextLabel) 25,
  `SecondaryButton` 22, `TabButton` 21; `Button` varsayılanı Baloo Bold 27.
- Tema `project.godot` → `gui/theme/custom` ile **proje geneli varsayılan**
  oldu. Sebep: oyun HUD'u (`game_board.tscn`) hiçbir temaya bağlı değildi;
  sahne başına `theme =` atamaları duruyor ama artık yalnızca belgeleyici.
- `scripts/ui/ui_type.gd` (`UiType`): rol adlarının tek tanımı. Kodla
  kurulan etiketler (mağaza, koleksiyon, güç çubuğu, sonuç kartı)
  `UiType.apply(label, UiType.CARD_TITLE)` diyor; string dağılmıyor.
- Sahnede boyut override'ı YALNIZCA rolün varsayılanının fiziksel olarak
  sığmadığı yerlerde ve her biri `tools/type_probe.gd` ölçümüyle
  gerekçeli (güç çubuğu 15, koleksiyon adı 16, level numarası 28, sonuç
  kartı 20/17).

#### Ölçümle bulunan ve düzeltilen şeyler

- **Fontlarda olmayan glyph'ler.** ★☆ (level düğümü), ✓ (mağaza
  "Sahipsin"), ●○ (günlük seri sayacı) ve mağaza güç kartında hâlâ duran
  eski metin işaretleri ✸▲≈⌫ — dördü de her iki ailede YOK (cmap okundu).
  Godot'un sistem fallback'i açık olduğu için masaüstünde "çalışıyor gibi"
  görünüyordu ama bambaşka bir yazı tipinden çiziliyordu; Android'de hangi
  fontun geleceği belirsiz. Yıldızlar mevcut `icon_star_*.png` asset'ine,
  güç işaretleri mevcut `power_*.png` ikonlarına (M8.5-08 güç çubuğunu
  çevirmiş, mağazayı atlamıştı), ✓ düz metne, ●○ ise iki renkli "•"ya
  (RichTextLabel) çevrildi. `PowerUp.GLYPHS` artık hiçbir yerde
  kullanılmıyor.
- **İki satırlı CTA.** "HAMURLA AL / 120 Hamur" tek `Button.text` iken iki
  satır aynı ağırlıkta çıkıyordu. `CandyButton.set_cta_text()` butonun
  üstüne Baloo başlık + Nunito alt satır bindiriyor (güç çubuğu deseni).
  Godot `font_disabled_color`u çocuk Label'a uygulamadığı için pasif
  kontrast `refresh_cta()` ile elle tazeleniyor — `power_refill.gd` ve
  `revive_offer.gd` her `disabled` değişiminde çağırıyor.
- **Pencere çerçeveleri büyüdü.** Refill 660→770 px, devam 580→650 px,
  sonuç paneli üst kenarı -300→-380: yeni satır yükseklikleriyle içerik
  eski çerçeveden taşıyordu ("Kapat" pencere dışına düşmüştü, çekimle
  yakalandı).
- **Buton dokusu gölgesi.** Level düğümü ve güç pill'i içeriği tam
  dikdörtgene yayılınca yazı/yıldız alt kenara yapışıyordu; kutular
  temanın kendi content margin'leriyle (üst 12 / alt 20) içeri alındı.
- **Harita başlığı** eklendi ("Harita", ScreenTitle + gölge): dört
  sekmenin üçünün kimliği vardı, haritanın yoktu. Parlak harita zemininde
  başlık ve rekor satırına gölge verildi.

#### CTA yazım kuralı (§14 tutarlılık)

Büyük harf yalnızca **ekranı kilitleyen pencerenin birincil eylemi**:
DEVAM ET, REKLAM İZLE, HAMURLA AL, SATIN AL (onay diyaloğu), TEKRAR DENE,
OYNA, AL. Liste satırındaki "Satın Al" ve tüm ikincil butonlar ("Kapat",
"Vazgeç", "Bitir", "Level listesi", "Sonsuz Mod") başlık/cümle düzeninde.
Düzeltilen gerçek tutarsızlık: onay diyaloğunda "Satın al" ile liste
satırında "Satın Al" farklıydı.

#### Araçlar

- `tools/type_probe.gd` (headless): glyph kapsamı (`has_char`), dar
  kutularda en büyük sığan boyut, en kötü durum metinleri ("Temizleyici
  ×99", "Hamur: 99999", level 10 hedef satırı). 0 uyarı.
- `tools/type_shots.gd` (pencereli): Türkçe glyph tablosu dört ağırlıkta,
  günlük ödül penceresi, en kötü durum değerleriyle HUD/sekmeler/refill.
  Kayda YAZMAZ (bellekte değiştirip geri koyar).

Bilinçli olarak YAPILMAYANLAR: skin art/tint, HUD ikon sistemi, logo,
copywriting, variable font, font subset (bkz. `assets/fonts/CREDITS.md`).

### 4.13 Production UI kabuğu (M8.5-10)

**Production UI shell TAMAMLANDI** — dört sekme, alt sekme çubuğu,
ayarlar, günlük ödül ve mağaza onayı tek tasarım sisteminde. Gameplay
ekranı, güç butonları, devam/refill pencereleri, logo ve tipografi
DEĞİŞMEDİ (owner'ın final kimliği referans alındı).

#### Tasarım sistemi (`scripts/ui/ui_palette.gd` + `assets/visual/ui_theme.tres`)

| katman | uygulama |
|---|---|
| BACKGROUND | `scenes/ui/shell_backdrop.tscn` — owner'ın gece zemini karartılmış (tint 0.62/0.60/0.78 + erik scrim 0.5 + alt gradyan). Harita kendi art'ını koruyor |
| SURFACE | tema `PanelContainer` — erik/lacivert yarı saydam, radius 26 |
| CARD | tema `CardPanel` / `QuietCardPanel` — biraz açık, ince pastel/rarity kenar, radius 20 |
| CHIP | tema `ChipPanel` — ikon + değer pill'i (Hamur, seri, koleksiyon, rekor) |
| PRIMARY CTA | owner'ın candy pill dokusu (OYNA, pencere CTA'ları) ya da tema `Button` (candy cyan StyleBoxFlat + koyu alt dudak) |
| SECONDARY | tema `SecondaryButton` (beyaz hayalet pill); krem panelde `UiPalette.style_ghost_on_cream` (erik hayalet) |
| SELECTED | nane (`UiPalette.SELECTED`, koleksiyon TAKILI) / altın (sekme, sıradaki level halkası) |
| DISABLED | lavanta-gri gövde + koyu okunur yazı |
| MODAL | candy panel + kanatlı kalp tepeliği (revive/refill ile aynı) — ayarlar, günlük ödül, mağaza onayı |

Renkler owner asset'lerinden ölçüldü (`cta_button_normal` #5eddf9,
logo #fee85f/#c694fa/#84d7fc/#d9799e, gece zemini #0d153f/#2d2a6c).
Wenrexa buton/panel dokuları temadan çıktı (dosyalar duruyor).
Dekorasyon bütçesi: hero/CTA yoğun (~%10), kartlar orta (~%30), yüzeyler
sakin (~%60).

#### Ekranlar

- **Ana Sayfa:** üst çubuk (seri cipi · ayarlar dişlisi), hero (logo +
  owner'ın `tutorial_pose` maskotu, hafif nefes animasyonu), Hamur +
  koleksiyon cipleri, OYNA (610 px candy pill, Display 40) + "Sıradaki:
  Level N" satırı.
- **Alt sekme çubuğu:** ikon + etiket, seçili altın + arkasında yumuşak
  pill + ikon pop. 112 px, tek `TabBarPanel` yüzeyi. **AdMob seam:**
  `TabBar.AD_SAFE_INSET` (şu an 0) — banner gelince çubuk yukarı kayar,
  ekran payları `TabBar.bottom_inset()` ile büyür.
- **Mağaza:** başlık + Hamur cipi; bölüm başlıkları ikon+başlık+not;
  güç kartı = vurgu renkli yuvarlak ikon kuyusu → ad → fiyat (Hamur
  ikonu, altın) → stok (sakin) → candy "Satın Al"; skin kartı rarity
  kenarlı, sahip olunan sakin yüzey + nane tik. Onay diyaloğu candy modal
  (başlık / detay / fiyat / SATIN AL / Vazgeç, karartmaya dokunma =
  vazgeç). Başarıda kart pop + bakiye cipi pop + cip toast.
- **Koleksiyon:** başlık + Hamur cipi, altın ilerleme çubuğu kartı
  (`ProgressBar`), 4 sütun kart: açık = rarity kenar, kilitli = koyu sakin
  yüzey + silüet, takılı = nane 3 px çerçeve + "TAKILI" nane rozeti + pop.
  Skin önizlemesi hâlâ placeholder (dokunulmadı).
- **Harita:** art korundu; başlık + Hamur cipi, düğümler tema candy
  butonu (kilitli lavanta + kilit rozeti), **sıradaki level altın halka +
  nabız**, Sonsuz Mod butonu, rekor + seri cipleri.
- **Ayarlar (yeni, `scenes/ui/settings_panel.tscn`):** Ses Efektleri
  (gerçek — `AudioManager.set_sfx_enabled` SFX bus mute, kayıtta
  `sfx_enabled`), Gizlilik (kısa doğru metin), "Squishy Merge · Sürüm
  0.8.5" (`config/version`), Kapat + sağ üst X + karartmaya dokunma.
  **Müzik anahtarı bilerek YOK** — Music bus'ı boş, çalışmayan anahtar
  koymadık. Müzik gelirse `_add_toggle_row` ile tek satır.
- **Android geri tuşu** (`main.gd` `_notification`): açık pencereyi
  kapatır → Ana Sayfa'ya döner → oyun sırasında yok sayılır.

#### Mikro-etkileşimler (`scripts/ui/ui_motion.gd`)

| ne | süre |
|---|---|
| buton basışı: 0.94 scale, TRANS_BACK ile geri | 0.06 s / 0.18 s |
| pop (sekme ikonu, satın alınan kart, bakiye cipi, TAKILI) | 0.22 s |
| pencere açılışı: karartma fade + panel 0.92→1.0 scale + fade | 0.20 s |
| sekme geçişi: içerik 14 px alttan solarak | 0.16 s |
| toast: yükselip sönen cip | 1.0 s |
| sıradaki level nabzı / maskot nefesi | 0.9 s / 1.2 s döngü |

Hepsi kesilebilir (`UiMotion._restart` eski tween'i öldürür). Sekme
geçişi yalnızca `Container` çocuklara uygulanır (zemin kaymaz, alfa 0
toast ellenmez — ilk denemede toast görünür olmuştu, çekimle yakalandı).

#### Free Casual GUI paketi

Yalnızca 14 beyaz ikon alındı (`tools/make_pack_icons.gd`, beyaz maske
olarak). Butonlar (neon-glass), paneller (krem), HUD, rozetler, lekeler
REJECT/REFERENCE — tablo ve gerekçeler `assets/visual/CREDITS.md`.
**Kaynak paket repoya EKLENMEDİ:** Unity Asset Store EULA ham paketin
yeniden dağıtımına izin vermiyor olabilir; `_visual_source/` politikasının
tek istisnası. Owner isterse `.gitignore`'a açık istisna yazılıp eklenir.

#### QA

- `tools/ui_shots.gd` (yeni): dört sekme, takılı koleksiyon, mağaza
  üst/alt, ayarlar, en kötü durum (Hamur 99999, 20/20, stok ×99, seri
  365), oyun ekranı — BEFORE (d214f63) ve AFTER aynı kayıtla üç ölçüde
  (720×1280, 720×1560, 540×960). Taşma/kırpılma yok.
- `tools/ui_smoke_test.gd` (yeni, headless): 26 davranış kontrolü —
  sekmeler, ayar anahtarı (bus mute + kayıt), gizlilik, geri tuşu, onay
  diyaloğu, satın alma sonrası stok/Hamur/cip, equip/rozet/kilitli skin.
- Regresyon: economy 100/100 (4 metin kalıbı "Stok ×N" / "N Hamur"a
  güncellendi — mantık değil, kopya), refill 119/119, revive 103/103,
  smoke boot temiz.
- `type_shots.gd` ve `screenshot_runner.gd` sekme/pencere çekimlerine 0.3 s
  bekleme eklendi (geçiş animasyonu bitmeden çekim yarı saydam çıkıyordu).

#### Kalan görsel borç

1. Skin art (placeholder daireler) — koleksiyon ve mağaza kartlarının tek
   zayıf noktası.
2. Harita düğümleri hâlâ düz grid (§7 #3) — patika takip etmiyor.
3. Round sonuç paneli koyu yüzey (candy krem modal değil) — bilinçli:
   sandık reveal katmanları koyu zeminde okunuyor; owner isterse modal
   şablonuna geçer.
4. Ayarlarda müzik satırı yok (müzik yok).

### 4.14 Dumpling teması ve game feel (M8.5-11)

**Physics collider DEĞİŞMEDİ. Çözüm yalnızca görsel.** `TierConfig`
yarıçapları, `CircleShape2D`, kütle, sürtünme, sekme, level `.tres`,
drop bag — hiçbirine dokunulmadı. Kanıt: `tools/contact_rig.gd` BEFORE
(55b0152 worktree) ve AFTER aynı deterministik sahnelerde **birebir aynı**
settle süresi / yığın yüksekliği / merge sayısı / kaçan gövde / overlap
verdi.

#### Kök sebep (ölçüldü, `tools/contact_audit.py`)

Owner'ın "fizik değiyor ama sprite'lar değmiyor" gözlemi doğru; sebep
**şeffaf padding DEĞİL** (sekiz dokunun alfa>0 bbox'ı tam doku). Sebep:
sprite'lar ~1.3–1.4 en/boy oranlı geniş bloblar, collider daire; M8'in
geometrik-ortalama ölçeği (`2r / sqrt(w·h)`) görsel gövdeyi dikeyde çapın
yalnızca **%70–79**'una sığdırıyordu.

| tier | r | eski yatay boşluk (A) | eski taban boşluğu (B) | eski duvar (C) | eski üst boşluk |
|---|---|---|---|---|---|
| 1 | 22 | +1.1 | +3.3 | +0.6 | 9.5 |
| 2 | 27 | −0.4 | +4.4 | −0.2 | 10.8 |
| 3 | 34 | +8.6 | +3.1 | +4.3 | 5.5 |
| 4 | 42 | +1.1 | +6.1 | +0.6 | 18.3 |
| 5 | 52 | +0.4 | +8.3 | +0.2 | 17.3 |
| 6 | 65 | +1.4 | +9.8 | +0.3 | 21.3 |
| 7 | 81 | −1.9 | +12.7 | −3.6 | 24.3 |
| 8 | 100 | +19.4 | +8.1 | +7.7 | 34.0 |

(px, dünya; + boşluk / − overlap; "üst boşluk" = collider üst kenarı ile
görsel gövde üstü arası — yığındaki dikey/çapraz temaslarda görünen boşluk
bunun ~iki katı.) Yani yan yana zeminde bile T3/T8 açık, taban her tier'da
havada, yığında 10–30 px boşluk.

#### Kalibrasyon (`DumplingVisual.CONTACT_FIT`, tier başına)

Aksesuarsız gövde silueti (satır/sütun genişliği en genişin %42'sinin
altına düşen şeritler — yaprak, taç, fiyonk ucu, gölge — hariç) esas alındı:

- `scale.x`: gövde genişliği = **2r + 2 px** (hafif overlap, yumuşak his)
- `scale.y`: gövde yüksekliği 2r'nin %90'ına yaklaşır; dikey uzama en fazla
  **1.25×** (T1 1.18, T2 1.22, T3 1.00, T4 1.22, T5 1.17, T6 1.15, T7 1.17,
  T8 1.02). Daire yapmak karakteri bozardı; "biraz daha tombul" kabul.
- `offset`: gövde yatayda collider merkezine, gövde alt kenarı collider alt
  kenarının **1 px** üstüne.

Sonuç sekiz tier'da: yan yana **−2 px**, taban **+1 px**, duvar **−1 px**;
üst boşluk T1 3.4 → T8 19 px (T3'te −3, yaprak taşıyor). Çapraz (45°)
temasta kalan boşluk ≈ 0.1r.

Elenen alternatifler: (a) uniform büyütme — yatay %25 overlap, "iç içe";
(b) padding kırpma — padding yok; (c) collider küçültme (0.90–0.97) —
gerekmedi, balans kalibrasyonuna dokunmamak için yapılmadı.

#### Game feel (yalnızca sunum)

| an | eklenen | süre |
|---|---|---|
| düşüş | hıza bağlı dikey gerilme (en fazla %10, `FALL_STRETCH`), dünya dikeyinde | sürekli, yumuşatılmış |
| iniş | mevcut hız-orantılı squash **alt kenardan basılıyor** (sprite lift telafisi); ≥ 420 px/sn'de 3–6 parçacık toz pufu (`impact_landed`) | 0.12 s / 0.28 s |
| merge | iki kaynağın hayaleti birleşme noktasına çekilir (80 ms) → yumuşak parlama (0.18 s, halka DEĞİL — halka güçlerin imzası) → yeni tier 0.7→1.12→1.0 açılış (`play_reveal`, 190 ms) → mevcut parçacık patlaması + HUD skor pop; tier ≥ 4'te birleşme noktasında "+N" | ~200 ms |
| tier 8 | ek altın parıltı yıldızı (dönerek açılır) + ikinci çapraz beyaz | 0.55 s |
| combo | mevcut xN rozeti; x2→x6 arası rozet altına/beyaza ısınır, x3+ çok hafif kamera darbesi (1.5–4 px) | — |
| kamera | tier ≤ 3 merge **sarsıntısız**, 4–6 hafif (2–5 px), 7–8 kısa belirgin (≤ 14 px); annihilation eski gibi | `SHAKE_DECAY` aynı |
| tehlike | düz kırmızı duvar dikdörtgeni yerine taşma çizgisinden solan pembe rim glow + duvar üst yarısı; nabız hızı sayaç doldukça 1.9 → 4.5 Hz | alfa 0.16–0.62 |
| hedef | "Hedef tamam!" pop + kap ağzından parıltı yağmuru (22+14 parçacık) + 5 px sarsıntı; `RESULT_DELAY` 0.8 s zaten okunabilir an veriyor | 0.3 s |

**RNG:** kamera sarsıntısı artık `_fx_rng` kullanıyor — GLOBAL RNG'yi
tüketen tek görsel kod buydu (§7 #14). Drop bag'e dokunulmadı; global RNG'yi
artık yalnızca o tüketiyor. Yeni efektlerin tamamı deterministik tween ya
da `_fx_rng`.

#### Ölçüm ve QA araçları

- `tools/contact_audit.py [--fit]` — alfa/gövde/collider tablosu + GDScript
  tablosu üretimi.
- `tools/contact_rig.gd` — deterministik temas/yığın rig'i (lineup T1/T2/T4,
  pile_contact/pile_merge en dar kapta, wall T1/T5, large T7+T7+T8, stress
  35 parça + zincir); settle/yükseklik/merge/kaçan/overlap raporu.
- `tools/feel_shots.gd` — düşüş, iniş, merge (temas/pop/açılış), zincir,
  tehlike, hedef, tier 7→8 kare dizileri.
- Stress (35 gövde + 17 zincir merge + parçacıklar): masaüstünde en kötü
  kare ~22 ms (spawn karesi), yerleşince < 8 ms. Android ölçümü M9'da.

#### Balans

Collider değişmediği için zorunlu regresyon yok; `contact_rig` fizik
metrikleri BEFORE/AFTER birebir aynı. Sanity: headless bot L10 n=40 (aşağıda
DEVLOG'da sayılar) — kamera RNG değişimi drop sırasını farklı örnekliyor,
oran gürültü bandında.

### 4.15 Level haritası: patika yerleşimi (M8.5-12)

> **M8.6-04 notu:** aşağıdaki sunum (düz cipli başlık, StyleBoxFlat kare
> düğümler, dört durum, tam ekran karartma, alt sekme çubuğu) production
> yolculuk haritasıyla DEĞİŞTİRİLDİ — düğüm konumları düzeltildi (2/4/5
> yola, 8/9/10 aralığı), `MapLevelNode` beş durum, `ScreenTopBar`, çubuk
> Harita'da gizli. Güncel kaynak: `docs/UI_VISUAL_SYSTEM.md` §15. Patika
> (Catmull-Rom), açılış animasyonu ve unlock/yıldız kuralı aynen.

Düz 5×2 grid kalktı; on düğüm owner'ın harita art'ındaki pembe kaldırım
taşı yolun orta hattını takip ediyor. **Level verisi, hedefler, yıldızlar,
unlock kuralı (`SaveManager.highest_level_unlocked`) DEĞİŞMEDİ** — yalnızca
yerleşim ve sunum (`scripts/ui/level_select.gd`, `scripts/ui/map_trail.gd`).

#### Yerleşim (doku uzayı, 720×1280 zemin)

| level | (x, y) | not |
|---|---|---|
| 1 | 420, 1120 | yolun alt geniş bölümü, sağ |
| 2 | 300, 1030 | sol |
| 3 | 440, 940 | sağ |
| 4 | 310, 850 | sol |
| 5 | 300, 740 | yolun sola kıvrımı (sol köprünün sağında) |
| 6 | 395, 645 | |
| 7 | 470, 555 | yolun sağa dönüşü |
| 8 | 410, 465 | |
| 9 | 475, 385 | lamba direğinin solunda |
| 10 | 440, 296 | kapı kemeri |
| Sonsuz | 445, 150 | kale (patikanın sonu) |

Zemin `KEEP_ASPECT_COVERED` çizildiği için uzun ekranda büyüyüp kırpılıyor;
düğümler aynı dönüşümle (`_map_to_screen`: ölçek = max(vw/720, vh/1280),
merkezleme) taşınıyor — 720×1560'ta patika hizası korunuyor, kesilme yok.
Düğüm 88 px (96'da on düğüm + kapı 1000 px'lik yola sığmıyordu), kapı
116 px. Dekoratif karakterler (sol alt sarı, sağ alt pembe), köprüler ve
başlık satırıyla çakışma yok.

#### Düğüm durumları

| durum | görünüm |
|---|---|
| LOCKED | tema pasif (lavanta), alfa 0.78, kilit rozeti, **yıldız sırası yok** |
| AVAILABLE | candy cyan + ince krem kenar (teorik — unlock sıralı olduğu için pratikte NEXT ile aynı düğüm) |
| NEXT | altın 3 px halka + arkasında nabız atan altın hale (`fx_dot`, 210 px, alfa 0.7↔1.0) + 1.05 ölçek nabzı |
| COMPLETED | candy cyan + 1/2/3 yıldız |

#### Patika (`MapTrail`)

Programatik, asset yok: düğüm merkezlerinden Catmull-Rom eğrisi, 6 px
krem çizgi + 10 px koyu gölge çizgisi, 26 px aralıklı noktalar (düğüm
altında kalanlar atlanır). Tamamlanmış segment sıcak krem-altın (alfa
0.95), gelecek segment beyaz alfa 0.32. `highest = H` → H−1 segment sıcak.

#### Açılış animasyonu

Bellek içi `_last_unlocked` (kayda yazılmaz): tazelemede `highest`
arttıysa yeni segment 0→1 yanar (0.4 s), yeni düğüm 0.4→1.15→1.0 pop
(0.32 s, 0.24 s gecikmeli), 12 parıltı. Toplam ~0.7 s, kesilebilir.
Sonsuz Mod açılışında aynı animasyon kapıya uygulanır.

#### Sonsuz Mod kapısı

Normal düğüm değil: kalenin önünde 116 px yuvarlak altın kapı (kupa +
"Sonsuz" içeride, dış altın parıltı gölgesi), altında tek cip — açıksa
"Rekor N" (kupa), kilitliyse "Level 10'u bitir" (kilit). Unlock kuralı
`is_endless_unlocked` aynı. Rekor/seri cipleri artık alt satırda değil:
seri + Hamur başlıkta, rekor kapının altında.

#### QA

`tools/map_shots.gd`: owner kaydı (10/10), orta ilerleme (1-3 tamam,
sıradaki 4), sıfır kayıt, açılış animasyonu ortası/sonu — 720×1280,
720×1560, 540×960. `ui_smoke_test` +9 kontrol (35/35): düğüm sayısı,
durumlar, kapı kilidi, grid olmadığı, `level_chosen`, açılış sonrası
sıradaki, sonsuz açılışı.

### 4.16 Skin sistemi temeli + koleksiyon vitrini (M8.5-13)

Amaç: "gerçek ürün gibi dursun" — sanat gelmeden önce **sistem** ve
**koleksiyon hissi** tamam olsun. **Gameplay, ekonomi (fiyatlar 50/150/
400/900), sandık oranları, kayıt formatı (`unlocked_skins` + `equipped_skin`,
boş string = varsayılan) DEĞİŞMEDİ.**

- **Veri modeli.** `SkinData` (katalog: id, ad, rarity, tint, **yeni**
  `preview_texture` — boşsa önizleme orijinal dumpling + SkinVisual'dan
  türetilir; owner'ın görseli gelince yalnız bu alan dolar) + **yeni
  `SkinEntry`** (oyuncuya göre durum: price / owned / equipped / locked,
  `SkinEntry.all(with_default)`, `find`, `equipped_entry`, `owned_count`).
  Koleksiyon, mağaza, ana sayfa ve sonuç ekranı skin durumunu artık tek
  kaynaktan okuyor — "sahip değil ama takılı" yapısal olarak imkânsız.
- **Sinyaller.** `SaveManager.skin_granted(id)` / `skin_equipped(id)`;
  `grant_skin`, `purchase_skin_with_dough`, `equip_skin`,
  `clear_equipped_skin` yayıyor. Koleksiyon abone: görünürken anında,
  görünmezken (mağazadan satın alma) bir sonraki açılışta yeni skin'i
  vitrine alıyor ("YENİ" + "Tak"). Gameplay abone değil — parça skin'ini
  doğarken okuyor, round içinde equip mümkün değil.
- **Önizleme.** `SkinSwatch` yeniden yazıldı: renkli daire placeholder'ı
  kalktı; sahip olunan skin **gameplay'deki materyalin aynısıyla**
  (`SkinVisual.apply` artık `CanvasItem` alıyor — Sprite2D ve TextureRect)
  tier-3 dumpling'i çiziyor, arkada rarity renginde radyal parıltı
  (GradientTexture2D, rarity başına önbellek); kilitli: silüet + kilit
  rozeti + soluk parıltı; varsayılan: nötr.
- **Koleksiyon ekranı.** Vitrin (150 px önizleme + ad + rarity pill +
  TAKILI/KİLİTLİ/YENİ pill + bağlam satırı + tek aksiyon: "Tak" candy CTA
  ya da kilitliyse "Mağazaya Git" ikincil buton → `shop_requested` →
  main.gd Mağaza sekmesi), ince albüm ilerleme şeridi, grid. Kartlar:
  sahip olunan plum + rarity kenar (Legendary altın 3 px), kilitli koyu +
  ad soluk + **fiyat bandı** (oyuncu neye ne kadar uzak olduğunu görsün),
  takılı nane + rozet, vitrindeki kilitli kart beyaz kenar. **Karar:**
  kilitli kartta ad artık "???" değil soluk ad — mağaza zaten adı
  gösteriyordu, iki ekran çelişiyordu; owner isterse tek satırlık geri alım.
- **Mağaza.** Skin satırları `SkinEntry`'den: sahip olunan "Sahipsin",
  takılıysa "Sahipsin · Takılı" + nane kenar; önizleme koleksiyonla aynı
  bileşen (72 px). Satın alma transaction'ı, onay diyaloğu, güç bölümü
  DEĞİŞMEDİ.
- **Dürüst sınır.** 20 skin'in tint verisi hâlâ placeholder
  (SKIN_ART_AUDIT.md): pastel dumpling üstünde luminans koruyan hue
  kaydırması **tüm rarity'lerde neredeyse görünmez** — koleksiyon
  önizlemeleri artık oyunu doğru yansıttığı için bu gerçek olarak ortaya
  çıktı (eski daireler bunu gizliyordu). Bilerek `STRENGTH` / tint
  DEĞİŞTİRİLMEDİ (owner kararı bekliyor, audit seçenek A/D). Sistem tarafı
  bu turla tamam; görsel ayrım tamamen veri/sanat işi.
- **QA.** `ui_smoke_test` +32 kontrol (67/67): fresh save (bozuk
  `equipped_skin` → güvenli fallback, 0/20, 21 kart, vitrin Varsayılan),
  kilitli dokunuş → vitrin/fiyat/"Mağazaya Git" → mağaza sekmesi, mağazadan
  satın alma (tek transaction, Hamur −150, takılı DEĞİL), koleksiyona dönüş
  → "Tak" → kayıt/kart/vitrin/mağaza "Takılı", **gameplay parçası skin
  materyalini taşıyor** (shader param = skin.tint), `load_game()` ile
  restore. `ui_shots` +1 kare (kilitli vitrin). Regresyon: economy
  100/100, refill 119/119, revive 103/103, bot L5 n=3 sanity. Owner kaydı
  byte-identical geri yüklendi (c46b9c80...).
- Yeni class_name'ler için `.godot/global_script_class_cache.cfg`
  yenilenmesi gerekti (`godot --headless --editor --quit`); editor
  açılmadan headless koşan test bunu kendisi yapmıyor.

### 4.17 Final skin sanatı + production gameplay skin render'ı (M8.5-14)

Owner'ın 20 final önizleme PNG'si bağlandı ve gameplay skin render'ı
placeholder hue-shift'ten production pipeline'a geçti. **Fizik, collider,
CONTACT_FIT, merge/skor, bag, level, ekonomi (50/150/400/900), sandık,
kayıt formatı, skin id'leri DEĞİŞMEDİ.** Ayrıntı: `SKIN_ART_AUDIT.md`
(yeniden yazıldı — artık "placeholder" demiyor).

- **Önizleme:** `assets/visual/skins/previews/skin_<rarity>_<ad>.png`
  (1254², saydam), import `size_limit=512` + mipmap (VRAM ~5 MB / 20 doku).
  `SkinData.preview_texture` ext_resource; `SkinSwatch` mipmap'li filtre.
  Kaynak PNG'ler ve arşiv zip'i (`_visual_source/`) dokunulmadı.
- **Veri:** `SkinData` render profili alanları (body/shade/highlight,
  pattern + renk/yoğunluk/ölçek/güç, gloss/pearl/sparkle, aura_color,
  anim_speed); `tint` alanı ve `skin_tint.gdshader` silindi. 20 `.tres`
  `tools/make_skin_resources.py` tablosundan üretiliyor (elle düzenleme
  yok). Adlar Türkçe diyakritikli ("Susamlı", "Gökkuşağı").
- **Gövde maskeleri:** `tools/make_skin_masks.py` → 8 gri maske
  (`assets/visual/skins/generated/`). Ton + V eşiği + elle dışlama elipsleri
  (tier 2/7 yanak, 6 yıldız, 7 fiyonk), `--debug` kontrol kareleri.
- **Shader:** `assets/visual/skins/skin_body.gdshader` — luminans tabanlı
  shade/body/highlight, 11 deterministik desen ailesi (sprite UV'si, hash/sin,
  TIME dışında rastgelelik yok), tier'a göre `detail_scale`, gloss/pearl/
  sparkle. Legendary aura `skin_aura.gdshader` (sprite çocuğu, arkada,
  paylaşılan doku+materyal). `SkinVisual.apply(item, skin, tier)` +
  `attach_fx`; (skin,tier) başına tek paylaşılan materyal.
- **Bulunan kök sebep:** Godot 4 canvas_item'da `COLOR` zaten doku×modulate;
  eski shader `src * COLOR` ile dokuyu iki kez çarpıyordu → hue-shift
  "görünmüyor"du. Yeni shader modulate'i vertex'ten varying ile alıyor.
- **QA araçları:** `tools/skin_gallery.gd` (rarity sayfaları tier 1/4/8 +
  final önizleme, tier 1 ×3, tier 8 detay, 8 skin gerçek gameplay merge anı
  — pencereli), `tools/skin_test.gd` (headless, 25 kontrol: 20 skin / sabit
  id / 8-6-4-2 / adlar / 20 önizleme / fiyatlar / 160 materyal + paylaşım /
  aura ekleme-kaldırma / varsayılan-Sade temiz dönüş / ghost materyali /
  global RNG tüketmiyor / takılı skin → yeni parça).
- **Sonuçlar:** skin_test 25/25, ui_smoke 67/67, economy 100/100, refill
  119/119, revive 103/103. Görsel: 20 skin birbirinden ayrılıyor, yüz/yanak/
  aksesuar boyanmıyor, aura kompakt, merge/parçacık/combo uyumlu; koleksiyon
  + mağaza 540×960 / 720×1280 / 720×1560 kırpılma yok.
- **Bilinen sınır:** Epic/Legendary önizlemelerindeki özel aksesuar/ifade
  gameplay'e taşınmadı (tier başına overlay art gerekir, 6×8 parça) —
  placeholder ile taklit edilmedi, `SkinVisual.attach_fx` takılma noktası.

### 4.18 Final SFX + titreşim + ses game-feel (M8.5-15)

Ses, görsel game-feel'in kalitesine çekildi. **Fizik, merge, bag, skor,
ekonomi, skin, harita, tipografi, reklam/billing DEĞİŞMEDİ.** Kayıt
formatına yalnız `haptics_enabled` (varsayılan true) eklendi. Ayrıntı ve
ölçümler: `docs/AUDIO_AUDIT.md`; eksik örnek şartnamesi:
`docs/AUDIO_ASSET_REQUIREMENTS.md`.

- **Denetim:** M6'nın 7 Kenney CC0 dosyası ölçüldü (`tools/audio_probe.gd`,
  AudioEffectCapture). Eski mimari 8 kanal round-robin idi: ödül sesi bir
  sonraki inişle kesilebiliyor, olay başına soğuma/tavan yok, bırakma /
  iniş / UI / güç aktivasyonu sessiz, `chest_open` ve `danger` üçer anlamda.
  `pluck_001` +0.4 dBFS (kırpıyor); `lowDown` 0.84 s tepe −0.6 dB ve 0.5
  s'de bir tekrar (siren etkisi). Digital Audio paketinden iki dosya
  (`sfx_danger`, `sfx_combo`) kaldırıldı; beşi `kenney_*` adıyla kategorili
  klasörlere taşındı.
- **Mimari:** `AudioManager.EVENTS` (olay → varyant havuzu, gain_db, pitch,
  jitter, cooldown_ms, max_voices, steal_self, priority, layers, fallback);
  12 kanal; kanal çalma LOW<NORMAL<HIGH<CRITICAL, CRITICAL asla kesilmez;
  yerel `RandomNumberGenerator` (global RNG'ye dokunmuyor — test `seed()`
  dizisiyle doğruluyor); eksik dosya → fallback → sessiz, tek uyarı; SFX
  bus'ında `AudioEffectHardLimiter` (−0.5 dB). Yardımcılar
  `play_drop/play_landing(tier, hız)/play_merge(tier)/play_combo/play_reward`.
- **Olaylar (36):** UI (tap/tab/modal open-close/toggle/select/purchase/
  invalid/equip), gameplay (drop, land hız+tier'a göre, merge + tier'a göre
  pesleşen gövde katmanı + tier ≥ 6 parıltı + tier 8 CRITICAL kutlama,
  annihilation, combo, danger, fail, round_win/lose, revive), güçler
  (power_arm, bomb_whoosh → bomb_impact, upgrade, shake, clear_puff), ödül
  (star_reveal, chest_open → reward_common/rare/epic/legendary,
  daily_reward, level_unlock). Evrensel buton sesi `UiMotion.attach_press`
  / `attach_tap` (`button_down`); sekme ve anahtar kendi sesini kullanır.
- **Sentez (geçici):** `tools/make_sfx.gd` → 22 `sfx_*.wav` (sinüs/gürültü,
  deterministik, tepe −3…−9 dBFS, kırpma 0, PCM 16-bit mono). Kulakla
  DOĞRULANMADI; final değil. Aynı adla üzerine yazılınca kod değişmez.
- **Titreşim:** `scripts/haptics.gd` (`class_name Haptics`, statik; autoload
  eklenmedi). LIGHT 18 / MEDIUM 32 / STRONG 55 ms, SPECIAL 35+60+60 ms,
  amplitude 0.35/0.65/1.0, `MIN_GAP_MS` 70 (yalnız daha güçlü darbe geçer).
  Editor/masaüstü: `is_supported()` false, platform çağrısı yok. Politika:
  buton/bırakma/iniş/combo/tehlike YOK; merge LIGHT, tier 6–7 / güç
  aktivasyon / satın alma / devam / taşma MEDIUM; bomba STRONG; tier 8 ve
  Legendary SPECIAL; temizleyici tek LIGHT. Ayarlar → Titreşim (`vibration`
  ikonu paketin `icon_bell`'inden türetildi). Android VIBRATE izni M9
  preset'inde açılmalı. **Cihazda doğrulanmadı.**
- **QA / test:** `tools/audio_test.gd` 45/45 (yükleme, olay eşlemesi, eksik
  akış çökmez, RNG izolasyonu, iniş spam 10→≤2, soğuma, merge steal_self,
  CRITICAL korunması, SFX/haptics kalıcılık, haptics kapalı → çağrı yok,
  editor güvenli, spam penceresi, SPECIAL, ≤60 ms, gameplay durumu sabit).
  `tools/audio_qa.tscn` (48 düğme: her olay, rarity, titreşim seviyesi,
  spam/stres senaryoları, kanal/atılan sayaçları). Mevcut testler: ui_smoke
  72/72, economy 100/100, refill 119/119, revive 103/103, skin 26/26, bot L3
  2/2. Pencereli gerçek sürücüde `ui_shots` hatasız.
- **Doğrulanmayan:** hiçbir ses kulakla dinlenmedi; Android titreşimi
  fiziksel olarak doğrulanmadı.

### 4.19 Skin render'ında tier kimliği + ilk gerçek cihaz kapısı (M8.5-17)

- **Kök sebep:** `skin_body.gdshader` gövde rengini
  `mix(shade, body, luminans)` ile TAMAMEN skin profilinden alıyordu; tier
  sprite'ından yalnız gölge/ışık dağılımı (luminans) geliyordu. Skin
  takılıyken 8 tier aynı gövde rengine dönüyordu (Havuçlu = turuncu kap);
  siluet/aksesuar farklı kalsa da renk okunurluğu ve ilerleme hissi
  gidiyordu. Sade de gereksiz yere krem recolor uyguluyordu.
- **Model:** `final = tier_blend(tier_rgb, skin_rgb, tint_strength)`:
  RGB karışım → HSV'de ton kayması tier tonundan en fazla ~32° (sabit,
  rarity'den bağımsız), skin tonu tier tonundan ≥ ~72° uzaksa ton çekimi
  sönüyor (162°+ → sıfır; mavi tier altında altın = "sırlanmış" mavi, yeşil
  tier değil), doygunluğun %60'ı tier'dan geri alınıyor (tamamlayıcı
  karışım griye düşmesin); değer karışımdan. Desen/gloss/pearl/sparkle/
  aura katmanları aynen; Gökkuşağı IRIDESCENT deseni tier tonu etrafında
  ±36° ince-film salınımı + %30 pastel gökkuşağı, kısmi kapsama (eski: %85
  tam gökkuşağı gradyanı → 8 tier aynı).
- **Veri:** `SkinData.tint_strength` (yeni alan; `make_skin_resources.py`
  `TINT_BY_RARITY` 0.30/0.35/0.40/0.50, Gökkuşağı 0.40, Sade 0.0). Kakao
  MARBLE 0.85→0.6, Safran SWIRL 0.85→0.7 (pastel gövdede aşırı baskındı).
  `SkinData.is_baseline()` → `SkinVisual.apply` materyal takmaz (Sade =
  varsayılan; test "Sade: materyal yok"). 152 materyal (19×8).
- **QA:** `skin_gallery.gd` iki yeni sayfa (varsayılan + 9 temsilci skin,
  8 tier yan yana, gameplay ×0.6), hücre yerleşimi JSON;
  `skin_tier_contrast.py` yüz/aksesuar dışı üç yamadan CIE Lab ΔE76:
  komşu tier min ΔE — varsayılan 25.5, Havuçlu 21.9, Ispanak 24.1,
  K.Biber 29.0, D.Tuzu 20.2, Kakao 15.9, Safran 19.7, Altın 22.9,
  Gökkuşağı 18.3 (eşik 12; aynı aile 1/6, 2/7, 4/8 tasarım gereği aynı
  renk, sayılmıyor). Gameplay kareleri artık ≥12 parçalı yığında.
- **Android (ilk kez):** `import_etc2_astc=true` (Godot 4.6.3
  `has_valid_project_configuration` bu kapalıyken export'u BOŞ hata
  mesajıyla reddediyor — not düşüldü), yerel `export_presets.cfg`
  (prebuilt template, arm64-v8a, VIBRATE, adaptive ikonlar, exclude
  `tools/* _visual_source/* docs/* *.md *.py`, paket
  `com.example.squishymerge` GEÇİCİ). Debug APK 44.7 MB, Samsung SM-A366B
  (Android 16, Adreno 710, Vulkan Forward Mobile): kurulum/başlatma temiz,
  logcat'te Godot hatası yok. Cihazda 5 skin ile 60 parçalık sonsuz mod
  yığını: tier'lar ayrışıyor, yüz/aksesuar korunuyor, merge/squash normal.
  Kareler `build/qa_m8.5-17/` (gitignore'lu). Gözlenen ama bu işin dışı:
  9:19.5 ekranda güç butonları "Sıradaki: …" satırını örtüyor (§7 #9),
  sonsuz mod kabı ekran kenarını aşıyor.
- **Değişmeyen:** fizik, collider, CONTACT_FIT, bag, merge, skor, revive,
  güçler, ekonomi, kayıt formatı, önizleme sanatı, maskeler.

## 5. Dosya/klasör yapısı ve script envanteri

```
squishy-merge/
├── project.godot            # 3 autoload, 720x1280 portrait, mobile renderer
├── scenes/
│   ├── main.tscn            # akış kontrolü (tek gerçek "sahne")
│   ├── game/                # dumpling, game_board, pop_effect
│   └── ui/                  # home_screen, level_select, collection_screen,
│                            #   shop_screen, round_result, daily_rewards_popup
│                            #   (M8.9-02; eski daily_reward_popup 02.1'de kalktı),
│                            #   settings_panel, shell_backdrop (M8.5-10)
├── addons/AdmobPlugin/      # godot-admob v6.0 release (kaynak değişmedi) + android_export.cfg (M8.9-01)
├── addons/squishy_ads_export/ # proje export eklentisi: android_export.cfg'yi PCK'ye ekler + doğrular
├── scripts/
│   ├── autoload/            # GameState, AudioManager, SaveManager
│   ├── ads/                 # MonetizationManager (+ interstitial M8.9-02), AdBackend/AdmobBackend, AdConfig, AdEvents (M8.9-01)
│   ├── game/                # oyun mantığı
│   └── ui/                  # ekran mantığı
├── resources/
│   ├── levels/              # level_01..10.tres + endless.tres  (data-driven)
│   └── skins/               # 20 skin .tres                      (data-driven)
├── assets/
│   ├── audio/               # sfx/{ui,gameplay,powers,rewards}/ (27 dosya) + CREDITS.md
│   └── visual/              # sprite'lar, fx/, ui/, icon/, ui_theme.tres, CREDITS.md
├── tools/                   # ⚠️ SADECE geliştirme araçları — export'ta filtrelenmeli
└── _visual_source/          # ⚠️ ham kaynaklar — export'ta filtrelenmeli
```

### Autoload'lar (sadece üç tane — dördüncüyü eklemeden gerekçelendir)

| script | işi |
|---|---|
| `autoload/game_state.gd` | Koşu-anı durumu: skor, merge sayısı, aktif level. Sinyal yayar (`score_changed`, `merge_performed`). |
| `autoload/audio_manager.gd` | Tüm SFX çalma noktası (M8.5-15): `EVENTS` olay tablosu, 12 kanal + öncelikli kanal çalma, soğuma/tavan, yerel RNG, fallback. `play(&"merge")`, `play_merge(tier)`, `play_landing(tier, hız)`. Bus: Master → SFX (limiter) / Music. |
| `haptics.gd` | `Haptics` statik servisi (M8.5-15): LIGHT/MEDIUM/STRONG/SPECIAL, spam penceresi, editor'de güvenli, test sink'i. |
| `autoload/save_manager.gd` | Yerel kalıcı kayıt, JSON, `user://`. Bulut yok. |

### Reklam (M8.9-01 — `scripts/ads/`)

| script | işi |
|---|---|
| `ads/monetization_manager.gd` | `MonetizationManager` — tek üretim reklam soyutlaması: UMP rıza yaşam döngüsü, SDK başlatma, ödüllü durum makinesi (devam + refill + günlük sandık + günlük Hamur, talep bağlamı, önyükleme, geri çekilme), **geçiş reklamı durum makinesi + aktif süre saati + doğal mola (`try_show_interstitial`) + 60 sn tam ekran beklemesi (M8.9-02)**, banner yaşam döngüsü + yuva (5 yüzey), onboarding kapısı, olaylar. Main'in çocuğu (autoload değil); eklentisiz platformda yaratılmaz. |
| `ads/ad_backend.gd` | `AdBackend` — SDK'ya bakan soyut arayüz (düz tipli sinyaller). |
| `ads/admob_backend.gd` | `AdmobBackend` — eklentinin `Admob` düğümünü sarar; kimlikler `AdConfig`'ten; banner uyarlanabilir/alt/güvenli alan; TFCD/TFUA UNSPECIFIED, içerik G. |
| `ads/ad_config.gd` | `AdConfig` — `addons/AdmobPlugin/android_export.cfg` → is_real + app/rewarded/banner kimlikleri + debug_geography; gerçek modda eksik/örnek kimlikte geçersiz. |
| `ads/ad_events.gd` | `AdEvents` — analitik olay dikişi (28 olay: ödüllü / banner / interstitial / günlük; abone/son 200); sağlayıcı sonraki milestone. |

### Oyun mantığı

| script | işi |
|---|---|
| `game/game_board.gd` | **En büyük dosya.** Kap geometrisi, drop kontrolü, merge çözümü, hedef takibi, taşma kontrolü, combo, sarsıntı, danger şeridi, level 1 tutorial ipucu. |
| `game/dumpling.gd` | Tek parça. Aynı tier çarpışınca `merge_requested` yayar. |
| `game/dumpling_visual.gd` | Görsel katman: tier sprite'ı, ±20° eğim, squash-stretch. |
| `game/tier_config.gd` | 8 tier'ın veri tablosu: yarıçap, isim, renk, merge puanı, yıldız eşikleri. |
| `game/level_data.gd` / `level_library.gd` | `.tres` level verisi + klasör tarayıcı. |
| `game/skin_data.gd` / `skin_library.gd` / `skin_entry.gd` | Skin kataloğu (final önizleme + gameplay render profili, M8.5-14) + klasör tarayıcı + oyuncuya göre durum view model'i (M8.5-13). |
| `game/skin_visual.gd` | Gameplay skin render katmanı (M8.5-14): gövde maskesi + `skin_body.gdshader` materyali (skin×tier paylaşımlı), Legendary aura. |
| `game/drop_bag.gd` | Bag randomizer (§4.4). |
| `game/chest_system.gd` / `chest_reward.gd` | Sandık kurası ve ödül nesnesi; `ChestReward.title/description/note` oyuncuya Türkçe (M8.6-09), iç ad `rarity_name` değişmedi. |
| `game/shop.gd` | Fiyatlar ve satın alma. **Fiyat tune edilecek tek yer.** |
| `game/daily_reward.gd` | Günlük GİRİŞ ödülü + streak (GAME_DESIGN §5.4; ekonomi değişmedi). M8.9-02.1: onboarding false iken `claim_if_new_day` / `is_claimable` no-op (kayıt mutasyonu yok); `claimed_today()` / `view()` pencere görünümü. |
| `game/daily_rewards.gd` | `DailyRewards` (M8.9-02) — GÜNLÜK ÖDÜLLER modelinin tek yetkili noktası: yerel gün anahtarı + geri alma koruması, üç ayrı kota (ücretsiz sandık 1 / reklamlı sandık 2 / reklamlı +150 Hamur 1), tek transaction grant'ler, otomatik pencere işareti; RNG enjekte edilir. |
| `game/daily_chest_loot.gd` / `daily_chest_reward.gd` | `DailyChestLoot` (DAILY reçetesi: +15 garanti, %30 skin, 60/25/12/3, sahip olunmayan skin, tükenmişse +15 bonus) + `DailyChestReward` (değişmez sonuç). Level sandığı reçetesi (`chest_system.gd`) DEĞİŞMEDİ. |
| `game/pop_effect.gd` | Merge parçacık patlaması. |

### UI

| script | işi |
|---|---|
| `main.gd` | Ekranlar (Ana Sayfa hub / Harita / Koleksiyon / Mağaza) ↔ oyun ↔ sonuç akışını bağlar. Kurallar burada DEĞİL. Alt sekme çubuğu M8.6-06'da kalktı. |
| `ui/home_screen.gd` | Ana sayfa: logo, streak, Hamur, "Oyna"; Günlük madalyonu → GÜNLÜK ÖDÜLLER penceresi (M8.9-02.1). |
| `ui/level_select.gd` | Harita: patika üstünde 10 düğüm + durumlar + açılış animasyonu + Sonsuz Mod kapısı (M8.5-12); banner yuvası varken dünya yuvanın üstünde biter (`_fit_world`, 16:9'da ≤ %4 dikey sıkıştırma — M8.9-02). |
| `ui/map_trail.gd` | Düğümleri bağlayan programatik candy patika (Catmull-Rom + noktalar, tamamlanmış/gelecek). |
| `ui/collection_screen.gd` | Koleksiyon (M8.6-06): `ScreenTopBar` + sabit vitrin (candy kaide üstünde büyük skin sanatı, tek eylem TAK / MAĞAZAYA GİT / TAKILI, N/20 pill'i) + kaydırılan 3 sütun galeri. Yalnız `SaveManager.equip_skin` yazar; satın alma yok. |
| `ui/collection_skin_card.gd` | `CollectionSkinCard` — galeri kartı (Button; rarity halkası/hale, final sanat, TAKILI / fiyat, seçim halkası). |
| `ui/shop_screen.gd` | Mağaza (M8.6-05): `ScreenTopBar` + kaydırılan içerik: **GÜNLÜK ÖDÜLLER kartı (M8.9-02, en üstte; HAZIR / N ödül kaldı / BUGÜNLÜK TAMAMLANDI, AÇ → pencere; onboarding bitmeden gizli)** + 2 sütun kart gridi + onay penceresi (`UiKit.modal_frame`) + candy geri bildirim plakası. Satın alma yalnız kanonik yoldan. |
| `ui/shop_power_card.gd` | `ShopPowerCard` — güç ürün kartı (candy kuyu + owner sanatı, amaç, fiyat, SATIN AL, stok rozeti; yetmiyor/başarı durumları). |
| `ui/shop_skin_card.gd` | `ShopSkinCard` — skin ürün kartı (SkinSwatch önizleme, rarity halkası/hale/pırıltı, fiyat veya SAHİPSİN/TAKILI). |
| `ui/round_result.gd` | Round sonu (M8.6-09 production yeniden kurulum, shell v2 `hero` + kaydırılan gövde + sabit altlık): WIN / FAIL / ENDLESS modları, yıldız reveal → ödül kartı reveal, SKOR/HEDEF/HAMUR çipleri, HARİTA / TEKRAR DENE rotaları; yalnız sunar, kayda yazmaz. **A36'da doğrulandı (M8.6-09.1)**. |
| `ui/result_reward_card.gd` | `ResultRewardCard` — Hamur / skin (gerçek final sanat, YENİ SKİN) / geri düşüş / teselli kartı; dokunma hedefi değil (M8.6-09). |
| `ui/result_star_strip.gd` | `ResultStarStrip` — yay üstünde üç owner yıldızı, yumuşak lavanta kontur (türev `icon_star_empty_soft`), pop + pırıltı reveal (M8.6-09). |
| `ui/reward_gem.gd` | Sandık ödül görseli: kapalı → açılış → rarity katmanları; `setup(reward, size)`, reveal sonrası `settle()` (M8.6-09). |
| `ui/skin_swatch.gd` | Skin önizlemesi (M8.5-13): final önizleme sanatı + rarity parıltısı; kilitli = `reveal_locked` ile final sanat + kilit (Koleksiyon/Mağaza, M8.6-06) ya da silüet; varsayılan = orijinal dumpling. |
| `ui/ui_icons.gd` | HUD ikonlarının tek tanımı, BBCode `[img]` üretir. |
| `ui/ui_type.gd` | Tipografi rol adları (M8.5-09). |
| ~~`ui/ui_palette.gd`~~ | **Silindi (M8.6-10):** M8.5-10 tasarım sistemi; tek kaynak artık `ui_tokens.gd` + `ui_kit.gd`. |
| `ui/ui_motion.gd` | Mikro-etkileşimler: basış, pop, pencere açılışı, sekme geçişi, toast (M8.5-10). |
| `ui/ui_toggle.gd` | Ayarlar anahtarı (M8.5-10); `UiKit.switch_toggle` ile LayerLab ray/topuz; ScrollContainer içinde kaydırma başlayınca basış ölçeğini bırakır (M8.6-08). |
| `ui/ui_kit.gd` | Production UI bileşen fabrikası (M8.6-01+): `modal_frame` (Mağaza onayı), **`modal_shell` iskelet v2** (kurdele/başlık+tepelik, oturmuş X, kaydırılan gövde + sabit altlık, tavan sistemi, `attach_dim_close`, `settings_row`) (M8.6-08). |
| `ui/streak_strip.gd` | `StreakStrip` — Günlük ödül seri şeridi: 7 düğüm (alınmış / bugün / gelecek), bağlantı çizgileri, gün numaraları, "+N" rozeti (M8.6-08). |
| `ui/settings_panel.gd` | Ayarlar penceresi (M8.6-08 yeniden kurulum, shell v2): ses efektleri, titreşim (M8.5-15), gizlilik (gövdede açılır, taşmaz; metin M8.9-01'de AdMob'u anlatır), **"Gizlilik seçenekleri" satırı yalnız UMP form sunuyorsa** (M8.9-01), sürüm; yalnız `set_sfx_enabled` / `set_haptics_enabled` yazar. |
| ~~`ui/daily_reward_popup.gd`~~ | **Silindi (M8.9-02.1):** M8.6-08 giriş ödülü penceresi; işlevi birleşik GÜNLÜK ÖDÜLLER penceresinin üst bölgesine taşındı (`StreakStrip` yeniden kullanılıyor). |
| `ui/daily_rewards_popup.gd` | GÜNLÜK ÖDÜLLER penceresi (M8.9-02 / 02.1, shell v2 kurdele + X) — oyuncunun TEK günlük ödül penceresi: üst bölge "N. GÜN · +15 HAMUR · ALINDI" + seri şeridi (giriş ödülü pencereden önce `DailyReward` ile yazılmış gelir; ilk açılışta kutlama), üç seçenek kartı (ücretsiz sandık AÇ / +150 Hamur REKLAM İZLE / reklamlı sandık REKLAM İZLE), durum rozetleri, sağlayıcı notları, in-modal reveal (RewardGem → +N HAMUR → YENİ SKİN kartı hale payıyla, DEVAM). Ödül vermez, kayda yazmaz; yalnız sinyal. |
| `ui/pause_menu.gd` / `ui/bonus_chest_info.gd` | Mola ve Bonus Sandık bilgi pencereleri — shell v2, oturmuş X (M8.6-08 cila; eylemler/kural değişmedi). |
| ~~`ui/candy_button.gd`~~ | **Silindi (M8.6-10):** M8.5-08 candy pill CTA'ları; son kullanıcıları Devam + Refill `UiKit`e geçti. Dokuları (`cta_button_*`, `power_button_*`, `panel_candy.png`) ve M8.5 ikon klasörü (`ui/icons/`) de kaldırıldı. |
| `ui/revive_offer.gd` | Devam (revive) teklifi (M8.6-10 production yeniden kurulum, shell v2 + tepelik): DEVAM HAKKI plakası (iki kalp, `icon_heart_revive`), DEVAM ET kahraman / BİTİR; sağlayıcı yokken CTA pasif + sebep; talep kilidi; yalnız sinyal yayar, hak vermez. |
| `ui/power_refill.gd` | Stok 0 refill penceresi (M8.6-10 production yeniden kurulum, shell v2 kurdele + X): güç sanatı kahraman + STOK ×0, ÖDÜLLÜ REKLAM / HAMURLA AL kartları, KAPAT; fiyat `PowerUpEconomy`, kota `RewardedPolicy`; yalnız sinyal yayar, stok/Hamur/kota'ya dokunmaz. |

### Geliştirme araçları (`tools/` — oyun çalışırken hiçbiri kullanılmaz)

| araç | işi |
|---|---|
| `bot_runner.gd` + `bot_brain.gd` | **Headless denge testi.** Gerçek `GameBoard`'u gerçek fizikle oynatır. Bu projedeki tüm kazanma oranı ölçümlerinin kaynağı. |
| `fake_ad_backend.gd` | `FakeAdBackend` — reklam SDK'sı test çifti (M8.9-01): çağrı sayar, her SDK olayı testten elle tetiklenir. Export dışı. |
| `monetization_test.gd` + `.tscn` | **Headless monetizasyon testi** (M8.9-01/02, 191 kontrol): yapılandırma korumaları (interstitial kimliği fail-closed), olay dikişi (28), kaynak taraması, rıza akışı/hataları/gizlilik seçenekleri, ödüllü başarı + callback güvenliği (çift/geç/eski/iptal/yanlış güç) + hata/geri çekilme/zaman aşımı + arka plan, banner yuva/5 yüzey/gezinme/hata/onboarding, Main entegrasyonu (gerçek pencereler + board + kota + Ayarlar). Kaydı byte'ı geri koyar. |
| `daily_rewards_test.gd` + `.tscn` | **Headless günlük ödüller testi** (M8.9-02/02.1, 134 kontrol): onboarding migration'ı, gün anahtarı (ileri/geri/aynı gün), üç kota + tek transaction + bağımsızlık, loot (4000 seed'li kura), Mağaza kartı + pencere + reveal, Main + sahte SDK (talep/çift/iptal/hata/gün değişimi), birleşik giriş ödülü (yeni gün / yeniden açılış / ertesi gün / kırık seri / geri saat / bağımsızlık / onboarding false no-op), otomatik pencere, onboarding bastırması. Kaydı byte'ı geri koyar. |
| `tutorial_test.gd` + `.tscn` | **Headless ilk açılış tutorial'ı testi** (M8.10, 149 kontrol): yeni kayıt açılışında otomatik tutorial, WELCOME girdi kapısı, FIRST_DROP clamp'i + yalnız geçerli bırakmanın ilerletmesi, MATCH_DROP hizalaması, GERÇEK merge şartı (T2 + skor + merge sayacı + tutorial T2'si board'da kalıyor + torba tüketilmedi), açıklama adımlarında girdi/dondurma + "coach kartı hedefi örtmüyor", tamamlanma atomikliği (iki alan tek transaction, çift tamamlanma yazmıyor), ilk gün bastırmasının tamamı + ertesi gün +15/seri, ATLA'nın aynı kanonik yoldan geçmesi, Android geri onayı (mola açılmıyor, kabuğa düşülmüyor), yarıda kapanma → baştan, onboarded oyuncunun Level 1 tekrarında tutorial görmemesi, monetizasyon ertelemesi (round ortası yuva 0 + rıza başlamadı → kabuk geçişinde açılıyor). Kaydı byte'ı geri koyar. |
| `tutorial_shots.gd` + `.tscn` | **M8.10 tutorial çekimleri** (pencereli): gerçek `main.tscn` + gerçek board üstünde 10 durum (karşılama, ilk bırakma, eşleştirme, merge kutlaması, hedef/tehlike/güçler spot'ları, hazırsın, geri onayı, tamamlanma sonrası); her adımda kart/hedef dikdörtgenleri, örtüşme, güvenli alan ve banner yuvası ölçümü stdout'ta. Adım beklemesi SÜREYE değil DURUMA bağlı. `--headless` ile çalışmaz. |
| `interstitial_test.gd` + `.tscn` | **Headless geçiş reklamı testi** (M8.9-02, 60 kontrol): 899/900 saat, dışlanan anlar, doğal mola / hazır değil / gösterim → saat 0 / callback bir kez, 60 sn bekleme, ödüllü dışlaması, yükleme/gösterim hataları, onay zaman aşımı, süresi dolma, Main: sonuç tam bir kez. Kaydı byte'ı geri koyar. |
| `daily_ads_shots.gd` + `.tscn` | **M8.9-02 düzen çekimleri** (pencereli): Harita/oyun + banner yuvası (orta ve yeni oyuncu), Mağaza günlük kartı, GÜNLÜK ÖDÜLLER penceresi (hazır/karışık), reveal (Hamur / Common / Legendary), yuvasız referanslar; ölçümler stdout'ta. `--headless` ile çalışmaz. |
| `ads_device.gd` + `.tscn` | **Reklam cihaz kapısı sürücüsü** (M8.9-01.1 / M8.9-02.2): gerçek `main.tscn`'i gerçek ya da sahte arka uçla kurar, `user://qa_cmd.txt` komut kanalı + `user://qa_state.txt` durum dosyası (reklam/ödüllü/geçiş/banner/günlük/pencere/harita/oyun dikdörtgenleri ekran px, son olaylar). M8.9-02.2 QA komutları: onboarding, login, dailyq, dayclock, fresh, relaunch, daily_open/close/reveal, clock (aktif süre enjeksiyonu), inter_block, fake_i*. **Yalnız ayrı QA paketinde** (`…squishymerge.qa`); üretim export'u `tools/*` hariç — üretim sabitlerine dokunmaz. |
| `ui_shots.gd` + `ui_shots.tscn` | **Production UI kabuğu çekimleri** (M8.5-10): dört sekme, ayarlar, en kötü durum, oyun ekranı; üç ölçü. `--headless` ile çalışmaz. |
| `ui_smoke_test.gd` + `ui_smoke_test.tscn` | **Headless UI davranış testi** (74 kontrol): ayar anahtarı, onay diyaloğu, geri tuşu, equip. |
| `secondary_modal_ui_test.gd` + `.tscn` | **Headless ikincil pencere testi** (M8.6-08 / M8.9-02.1, 100 kontrol): shell v2 iskeleti (oturmuş X, gövde/altlık sınırları, tavan + kaydırma, karartma), Ayarlar (kanonik yazma yolu, taşma regresyonu 5 yapılandırma), Günlük = birleşik GÜNLÜK ÖDÜLLER (claim pencereden önce tam bir kez, üst bölge, yeniden açılış +15 yok, kapanış yolları, 540×960), Mola/Sandık (hiyerarşi, z-order, rota). Kaydı byte'ı geri koyar. |
| `secondary_ui_shots.gd` + `.tscn` | **İkincil pencere çekimleri** (M8.6-07/08): 48 durum × pencere boyutu + A36 simülasyonu; `groups=` ile alt küme. `--headless` ile çalışmaz. |
| `result_ui_test.gd` + `.tscn` | **Headless round sonu testi** (M8.6-09, 226 kontrol): yapı (eski iskelet yok, kayda yazma çağrısı yok), kazanma / kayıp / ödül kartları / dil taraması, 6 ödül taşma + sürükleme, kayıt güvenliği + gerçek kayıp yolu (teselli tam bir kez), rotalar + Android geri, L10 / Sonsuz, devam sırası, 5 yapılandırma, performans. Kaydı byte'ı geri koyar. |
| `result_shots.gd` + `.tscn` | **Round sonu çekimleri** (M8.6-09): 31 kare (kazanma/kayıp, yıldızlar, 4 rarity Hamur + skin, geri düşüş, çoklu/5/6 ödül + kaydırma, L10, Sonsuz, retry/Harita basış) × pencere boyutu + A36; `only=` ile alt küme. `--headless` ile çalışmaz. |
| `result_device.gd` + `.tscn` | **Cihaz kapısı sürücüsü** (M8.6-09.1): `result_shots`'ı miras alır, cihazda gerçek çözünürlükte her durumda DURUR (`user://qa_cmd.txt` komut kanalı, `user://qa_state.txt` durum/istatistik: kart sayısı, kaydırma, kare profili, yıldız/kart ms'leri, kayıt özeti). Komutlar: start/next/stats/scroll_top/scroll_end/dup_show/dup_finish/timeline/quit. Ek durumlar: D4 (4 ödül), R1/R2 (gerçek kanonik kazanma ve gerçek taşma → Devam → sonuç). **Ayrı pakette** (`…squishymerge.qa`) export edilir — owner kaydına dokunamaz. |
| `make_result_art.py` | Owner kontur yıldızından yeniden boyanabilir `icon_star_empty_soft.png` türetir (M8.6-09). |
| ~~`make_pack_icons.gd`~~ | **Silindi (M8.6-10):** Free Casual GUI ikon türetmesi; çıktı klasörü de kaldırıldı. |
| `revive_refill_ui_test.gd` + `.tscn` | **Headless Devam + Refill testi** (M8.6-10, 266 kontrol): kaynak taraması (eski iskelet / yazma çağrısı yok, emeklilik kanıtı), devam durumları + işlem sınırı (talep tam bir kez, UI hak vermez, callback tam bir kez, sağlayıcısız pasif), Android geri + BİTİR→sonuç sırası, dört güç + kanonik fiyat + Hamur, ödüllü (sağlayıcı yok / bağlı / kota dolu / DÖRT gücün toplamı), satın alma tek transaction + çift basış, kapanış yolları (X/KAPAT/karartma/geri) kayda yazmaz, 5 yapılandırma, performans. Kaydı byte'ı geri koyar. |
| `revive_refill_shots.gd` + `.tscn` | **Devam + Refill çekimleri** (M8.6-10): 17 durum (devam 2/2, 1/2, sağlayıcı yok, talep, 0/2, BİTİR geçişi, sonuç; refill Bomba yeterli/yetersiz, Büyütücü, Sarsıntı, Temizleyici, ödüllü uygun/kota dolu/sağlayıcı yok, SATIN AL basış/başarı) × pencere boyutu + A36; `only=` ile alt küme. `--headless` ile çalışmaz. |
| `make_revive_art.py` | Owner kanatlı-kalp tepeliğinden izole kalp `icon_heart_revive.png` türetir (M8.6-10). |
| `audio_test.gd` + `audio_test.tscn` | **Headless ses + titreşim davranış testi** (M8.5-15, 45 kontrol): eşleme, RNG izolasyonu, soğuma/tavan/öncelik, ayar kalıcılığı, haptik politikası. Kaydı kendi yedekler. |
| `audio_qa.gd` + `audio_qa.tscn` | **Ses/titreşim QA sahnesi** (pencereli): her olay, rarity, güç, titreşim seviyesi, spam/stres düğmeleri; kanal ve atılan çağrı sayaçları. Production navigasyonunda yok. |
| `audio_probe.gd` | Eşlenmiş her ses dosyasının süre / tepe dBFS / RMS / sessizlik / kırpma ölçümü (AudioEffectCapture, headless). |
| `make_sfx.gd` | GEÇİCİ sentez SFX üretici (22 dosya, deterministik). Final örnek gelince gereksizleşir. |
| `contact_audit.py` | **Temas geometrisi denetimi** (M8.5-11): alfa bbox, gövde silueti, collider, dünya boşlukları; `--fit` kalibrasyon tablosu. |
| `contact_rig.gd` + `contact_rig.tscn` | **Deterministik temas/yığın rig'i**: lineup, pile, wall, large, stress; settle/yükseklik/merge/kaçan/overlap. |
| `feel_shots.gd` + `feel_shots.tscn` | Game-feel kare dizileri: düşüş, iniş, merge, zincir, tehlike, hedef, tier 8. |
| `map_shots.gd` + `map_shots.tscn` | Harita QA çekimleri: owner / orta / sıfır kayıt (bellekte), açılış animasyonu. |
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
| **Kenney** — ses paketleri | 5 SFX (`kenney_*`) | ✅ kullanımda, owner kulakla onaylayacak / değiştirecek |
| **Sentez** — `tools/make_sfx.gd` | 22 SFX (`sfx_*.wav`) | ⚠️ GEÇİCİ, kulakla doğrulanmadı — final örnekler bekleniyor (`docs/AUDIO_ASSET_REQUIREMENTS.md`) |

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
| 3 | Görsel yol haritası. | 🟢 **M8.5-12'de yapıldı** (§4.15): düğümler patikayı takip ediyor, candy patika, açılış animasyonu, Sonsuz Mod kapısı. |
| 4 | Açılmış skin'ler hâlâ placeholder (renkli daire). Skin başına ayrı görsel owner'dan gelmedi; sadece kilitli silüet gerçek asset. | 🟡 Asset bekliyor. |
| 5 | Sandık görseli her rarity'de aynı; Common-Legendary farkı yalnızca efekt katmanlarında. | 🟢 Owner'a soruldu, şimdilik böyle kalsın denmedi/denildi — düşük öncelik. |

### Teknik

| # | sorun | durum |
|---|---|---|
| 6 | **`danger_stripe.png` seamless değil** (kenar farkı ort. 0.16, en kötü 1.20). Bu yüzden tile edilmiyor, kap genişliğine **tek parça geriliyor**. Kap genişliği level'a göre değiştiği için germe zaten gerekliydi, ama yeni bir şerit gelirse aynı kısıt geçerli. | 🟡 Kabul edilmiş kısıt. |
| 7 | **Duvar dokusu yok.** Kap duvarları düz `Color("6b5a52")` dikdörtgen. `bg_scene.png`/`panel_frame.png` entegre edilirse buraya da doku gelebilir. | 🟡 Yapılmadı. |
| 8 | **`map_background.png` 1.8 MB** — tek başına kalan tüm görsellerden büyük. Fotoğrafik illüstrasyon PNG'de kötü sıkışıyor. Import ayarında lossy (WebP) yapılabilir. | 🟡 M9 APK bütçesi notu. |
| 9 | **Uzun ekranda oyun tahtasının altında boş alan.** `FLOOR_Y` sabit 1180, viewport 9:19.5'te 1560'a çıkıyor. Kap yukarıda kalıyor. | 🟢 **M8.6-02'de çözüldü:** `GameplayLayout` bölge sözleşmesi (HUD / BOARD / STRIP / BANNER seam) + kamera ile referans fizik penceresini BOARD bölgesine sığdırma (zoom ≤ 1.2, fizik değişmedi); 720×1280 / 1560 / 1440 / 1600 + banner 0/100 çakışmasız (`tools/gameplay_shell_test`, 146). Bkz. docs/UI_VISUAL_SYSTEM.md §13. |
| 10 | **`tools/` ve `_visual_source/` export'ta filtrelenmeli.** Aksi hâlde AAB'ye ~73 MB gereksiz veri giriyor. `_visual_source/` artık repoda olduğu için bu **daha kritik**. | 🔴 **M9'da mutlaka yapılacak.** |
| 11 | Proje ikonu hâlâ Godot'un varsayılan robotu (`config/icon="res://icon.svg"`). Kompozit ikon üretildi ama `project.godot`'a bağlanmadı. | 🔴 M9/M10 öncesi. |
| 12 | `_visual_source/` içinde 4 zip (~17.6 MB) var ve bunlar yanlarındaki açılmış klasörlerin **birebir kopyası**. Repo boyutunun dörtte biri. | 🟡 Silinebilir; git geçmişinden çıkarmak history rewrite gerektirir. |
| 13 | Kazanma/kaybetme jingle'ı kulakla doğrulanmadı (M6 blokajı, hiç kapanmadı). | 🟡 Owner playtest'inde kontrol edilmeli. |
| 15 | **AdMob eklentisi UMP boşluğu (M8.9-01) — ÜRETİM ENGELİ:** godot-admob v6.0 `canRequestAds` / `getPrivacyOptionsRequirementStatus` / `showPrivacyOptionsForm` sarmaz (SDK'dan türeyen eşdeğerler kullanılıyor, PRIVACY_CONSENT §4) VE `debug_geography` cihazda uygulanamıyor (upstream #120: Java `Integer` bekliyor, Godot `Long` gönderiyor; v7.0 kaynağında düzeltilmiş ama v7.0 Godot 4.7) → EEA rıza formu A36'da gösterilemedi. Üretim öncesi küçük AAR yaması ya da upstream PR. | 🔴 Owner/ChatGPT kararı. |
| 17 | **Ödül callback'i reklam kapanmadan geliyor (A36 gözlemi, M8.9-01.1):** Godot AdActivity arkasında çalışmaya devam ettiği için `grant_revive` / `grant_rewarded_power` (ve M8.9-02 günlük reveal'i) reklam hâlâ üstteyken uygulanıyor; veri doğru ama "Devam!" flaşı, +1 pop ve MEDIUM titreşim reklamın arkasında oynuyor. İstenirse grant kapanışa ertelenebilir. | 🟡 UX; owner kararı, değişiklik yapılmadı. |
| 18 | **İki günlük pencere (M8.9-02):** günlük GİRİŞ ödülü (M8.6-08) ve GÜNLÜK ÖDÜLLER günün ilk açılışında art arda açılıyordu. | 🟢 **M8.9-02.1'de birleştirildi:** tek pencere, eski pencere silindi, giriş ödülü üst bölgede; onboarding false iken giriş işlemi de kapalı. |
| 19 | **16:9'da oyun kabı banner ile −%10 (M8.9-02):** 720×1280'de kamera zoom 0,971 → 0,874 (T1 çapı 42,7 → 38,5 tuval px) — aralıklar daraltıldıktan sonra kalan tek kaldıraç. A36'da L1–L3 değişmez, L4+ ≤ −%6. Fizik değişmedi. | 🟡 Kabul edildi; cihazda okunurluk kontrolü A36 kapısında. |
| 16 | **Gradle debug APK 102 MB** — `android_source` şablonunun debug `libgodot_android.so` 75 MB (strip'siz). Release/AAB'de küçülür; prebuilt debug 45 MB idi. | 🟢 Beklenen; M9'da release boyutu ölçülecek. |
| 14 | **Gameplay/tooling RNG coupling.** Kamera sarsıntısı `_process` içinde `randf_range` çağırıyordu — görsel ama `drop_bag.shuffle()` ile aynı global RNG akışını tüketiyor ve fizik kareleri arasında değişken sayıda çalışıyordu; `bot_runner` tekrarlanamazdı. | 🟢 **M8.5-11'de kaldırıldı:** sarsıntı `_fx_rng` kullanıyor; global RNG'yi artık yalnızca drop bag tüketiyor. Bot hâlâ seed'siz (rastgele başlangıç); seedli harness istenirse `seed()` eklemek yeter, drop_bag'e dokunmak gerekmiyor. |

---

## 8. Kalan işler

### M8.9 — Monetizasyon (AdMob) — kalanlar

`M8.9-01` temel main'de (33b6382, A36'da doğrulandı); `M8.9-02` genişletme
(Harita/oyun banner'ı, geçiş reklamı, günlük ödüller, onboarding dikişi) dal
`task/034`'te, test reklamı. Kalan:

1. **Owner: AdMob hesabı** — uygulama kaydı (App ID), rewarded + banner +
   interstitial reklam birimleri, Privacy & messaging GDPR mesajı →
   `addons/AdmobPlugin/android_export.cfg [Release]` + `is_real=true` (yalnız
   release adımında).
2. **Owner/ChatGPT: kitle politikası** — Play "Hedef kitle" beyanı ↔ TFCD /
   TFUA / içerik derecesi (PRIVACY_CONSENT §6).
3. ~~**A36 test reklamı cihaz kapısı**~~ → **GEÇTİ (M8.9-01.1, 2026-09-21)**;
   rıza formu #120 yüzünden gösterilemedi (yukarıda §7 #15), uçak modu owner'ın
   günlük telefonunda denenmedi (gerçek no-fill + masaüstü testleri kapsıyor).
4. ~~**M8.9-02 A36 cihaz kapısı**~~ → **GEÇTİ (M8.9-02.2, 2026-09-22;
   ADS_SYSTEM §14):** gerçek test interstitial'ı doğal molada (gösterim →
   sonuç bir kez, saat yalnız SDK gösteriminde sıfır, 60 sn bekleme; uygun
   değil / bekleme / hazır değil / gösterim hatası yollarında sonuç hemen),
   Harita/oyun banner'ı, günlük reklamlı sandık ×2 + +150 + ücretsiz sandık,
   otomatik pencere tam bir kez, onboarding false bastırması, gün değişimi,
   arka plan, logcat temiz, PSS düz; owner görsel kontrolü 5/5 PASS. Cihazda
   erişilemeyen tek yol: test ödüllü reklamında ödülden önce kapatma (Google
   test yaratıcısı ~8 sn'de ödül verip öncesinde kapatma göstermiyor) — sahte
   arka uçla kapsandı. `task/034` push edildi, **main'e merge kararı owner'da.**
5. ~~İki günlük pencere kararı~~ → M8.9-02.1'de birleştirildi (§7 #18).
6. **Analitik sağlayıcı** — `AdEvents` dikişine bağlanır (28 olay hazır).
7. Eklenti UMP boşluğu kararı (§7 #15).
8. ~~M8.10 ilk açılış tutorial'ı~~ → **UYGULANDI + A36 KAPISI GEÇTİ**
   (dal `task/035-first-run-tutorial`, base `d72fde5`, push edildi) —
   aşağıya ve `docs/TUTORIAL_SYSTEM.md` §12.1'e bakın. **Main'e
   birleştirilmedi; merge kararı owner'da.**

### M8.10 — İlk açılış tutorial'ı + ilk gün kuralı

Dal `task/035-first-run-tutorial`. Kanonik doküman
[docs/TUTORIAL_SYSTEM.md](docs/TUTORIAL_SYSTEM.md).

**Neden bu tasarım.** Onboarding dikişi M8.9-02'de hazırlanmıştı ama
tutorial'ın kendisi yoktu; Level 1'de duran "sürükle • bırak" ipucu ise
onboarded oyuncuya da çıkıyordu. İki sistem yan yana yaşayamayacağı için
eski ipucu KALDIRILDI (`gameplay_hud.tutorial` widget'ı ve
`GameBoard._setup_tutorial/_place_tutorial/_dismiss_tutorial` silindi;
harness'lerdeki `_dismiss_tutorial()` çağrıları temizlendi).

**Sahte fizik yok.** Tutorial gerçek `GameBoard` + gerçek `Dumpling` +
gerçek `_resolve_merge` üstünde çalışıyor. T2 doğrudan doğurulmuyor: iki T1
gerçekten bırakılıyor ve adım ancak `GameState.merge_performed` geldiğinde
ilerliyor. Öğretim kuyruğu (`[T1, T1]`) `DropBag` RNG'sine dokunmuyor
(kuyruk bitince torba devralıyor; torba round başına yeni, yani tutorial'dan
sonra hiç çekilmemiş oluyor). İki bırakma yardımı tutorial'a özel: ilk drop
kabın ortasında ±%24 banda CLAMP (önizleme de sınırlı), ikinci drop ilk
T1'in x'ine SNAP (önizleme serbest, hizalama bırakma anında + cyan kılavuz
çizgisi). Merge 3 sn içinde gelmezse adım güvenle yeniden kuruluyor —
oyuncu takılı kalmıyor.

**Sorumluluk sınırı.** Board ürün onboarding'ini bilmiyor: yalnız pasif
dikişler sunuyor (`setup_tutorial_queue`, `set_tutorial_input_locked`,
`set_tutorial_paused`, `set_tutorial_drop_clamp/snap`, spot dikdörtgenleri).
Tutorial pause'u fail-pending / refill-pending / menü dondurmasından AYRI
bayrak; karşılıklı koruma var ve `_finish()` üçünü de temizliyor. Tutorial
açıkken Mola ve Ayarlar açılmıyor (oyun içi Geri butonu tutorial'ın kendi
onayını açıyor), Android geri "DEVAM ET / ATLA" gösteriyor — monetize edilmiş
Ana Sayfa'ya onboarding false iken ASLA düşülmüyor.

**Kalıcılık.** Yeni `Onboarding` servisi (tek yetkili nokta) + kayıt alanı
`onboarding_completed_day`. `SaveManager.complete_onboarding(day_key)` iki
alanı ve `last_seen_day_key`'i TEK `save_game()` ile yazıyor; idempotent
(ikinci çağrıda diske yazma DA yok). Eski kayıtta tamamlanma günü
UYDURULMUYOR — boş kalıyor ve "yerleşik oyuncu, bastırma yok" demek. Yarıda
kapanırsa onboarding false kalıyor ve tutorial baştan başlıyor (adım adım
kalıcılık bilinçli olarak YOK).

**İlk gün kuralı.** Tek kapı `Onboarding.daily_rewards_unlocked()`; kontrol
UI'da değil MODELDE (üç transaction + `popup_due` + giriş ödülü içinde).
Tamamlanma gününde günlük sistemin tamamı kapalı, telafi yok; ertesi yerel
günde sıfırdan (seri 1, +15, tek pencere, tam kotalar). Saat geri alma
korumasıyla tutarlı: B gününe geçtikten sonra A'ya dönmek yeniden
kilitlemiyor.

**Monetizasyon.** UMP/rıza akışı onboarding'e kadar hiç başlamıyor
(`_maybe_start_consent`); şart kaldırılmadı, yalnız ertelendi. Tutorial'dan
doğan Level 1 round'unun ORTASINDA banner yuvası açılmıyor — `Main` geçici
(kayda yazılmayan) bir erteleme bayrağı tutuyor ve ilk güvenli geçişte
(`_show_tab` / `_start_level`) açıyor. Bu sırada bulunan bir hata da
düzeltildi: `_consent_attempts` başarıda sıfırlandığı için "rıza başladı mı"
sorusuna cevap veremiyordu (ikinci `request_consent_update` izni geçici
olarak kaybettiriyordu) → ayrı `_consent_started` bayrağı.

**Testler (ilk geçerli koşu).** `tutorial_test` 149/149, `daily_rewards_test`
179/179, `monetization_test` 207/207, `interstitial_test` 60/60. Görsel QA:
`tools/tutorial_shots.tscn` 3 boyut × 10 durum, her adımda "kart hedefi
örtmüyor" ölçümü.

**A36 cihaz kapısı (M8.10.1, 2026-09-22): GEÇTİ.** SM-A366B / Android 16 /
1080×2340; aynı ağaçtan üretim biçimli TEST-reklam APK'sı + ayrı QA paketi.
Gerçek dokunuşla ilk açılış → gerçek T1+T1 → T2 merge'i → coach mark'lar →
tamamlanma; tamamlanmada diske yalnız iki alan + `last_seen_day_key`; round
ortasında banner yuvası 0 ve UMP 0; kabuğa dönüşte UMP 0 → 16 ve banner
göründü; aynı gün günlük tam bastırma, ertesi gün +15/seri 1/tek pencere,
saat geri alınca ikinci ödül yok; yarıda kapanma WELCOME'dan baştan; ATLA ve
Android geri kanonik yoldan; mevcut/eski oyuncu tutorial görmedi; logcat
temiz, orphan 0, PSS 475 MB; **owner görsel kontrolü PASS (5/5)**. Cihazda
runtime defekti YOK. Owner telefon kaydı byte-identical geri kondu.
Kanıt: `build/qa_m8.10.1/DEVICE_GATE_NOTES.md`.

**Bir olay kaydedildi (üretim kodu DEĞİL, araç kullanımı):** geri yükleme
yolu doğrulanırken `run-as PKG sh -c 'cat /sdcard/… > files/…'` denendi;
`run-as` /sdcard'ı okuyamadığı için yönlendirme hedefi okuma başarısız
olmadan önce SIFIRLADI ve owner telefon kaydı 0 bayta düştü. Doğrulanmış
yedekten anında geri yüklendi (md5 eşleşti, veri kaybı yok). Kalan tüm
yazmalar stdin + `base64 -d` ile yapıldı. Kural artık notlarda.

**Açık:** tutorial metinleri yalnız Türkçe; üretim engelleri (UMP
sarmalayıcı + #120, COPPA/TFCD/TFUA, gerçek AdMob kimlikleri) değişmedi —
tutorial kapısının geçmesi bunları kapatmaz.

### M9 — Android export

**Ortam neredeyse hazır** (§2'deki tabloya bakın). Godot, export
template'leri, Android SDK, NDK, JDK 17 ve debug keystore mevcut.
**M8.9-01'den itibaren export Gradle build ister** (`gradle_build/
use_gradle_build=true`, `android/build/` şablonu `--install-android-build-
template` ile; her makinede ayrı).

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
