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

## 2. Tier listesi (8 tier)

| # | İsim (placeholder) | Not |
|---|---|---|
| 1 | Mini Dumpling | En küçük, en sık düşen |
| 2 | Küçük Dumpling | |
| 3 | Dumpling | |
| 4 | Şişkin Dumpling | |
| 5 | Büyük Dumpling | |
| 6 | Dev Dumpling | |
| 7 | Jumbo Dumpling | |
| 8 | Dumpling Kralı | Özel efekt tetikler |

> **Merge puan tablosu (M2'de KİLİTLENDİ):** bir tier'a birleşildiğinde
> kazanılan puan — tier 2: 50, 3: 70, 4: 90, 5: 110, 6: 130, 7: 150, 8: 200.
> M2 balans pasında modellendi: tier 8'e ulaşan oyuncunun skoru medyan ~4740
> (p5 4360 / p95 5150), yani level 10'un "skor ≥ 5000" hedefine 2-3 merge
> kalıyor — hedef anlamlı kalıyor ama ikinci bir yığın kurmayı gerektirmiyor.
> Önceki tablo (30/40/50/60/70/80/100) tier 8'de sadece ~2630 veriyordu ve
> level 10'u pratikte imkânsız kılıyordu.

Sadece tier 1-3 arası rastgele düşer (drop pool). Bu, Suika-tarzı oyunların
standart zorluk dengelemesi — üst tier'lar sadece merge ile elde edilir.

## 3. Level tablosu (v1 — 10 level)

| Level | Hedef | Kap genişliği | Hamle/süre limiti |
|---|---|---|---|
| 1 | Tier 4'e ulaş | Geniş | Yok (tutorial) |
| 2 | Tier 4'e ulaş | Geniş | Yok |
| 3 | Tier 5'e ulaş | Geniş | Yok |
| 4 | Tier 5'e ulaş | Orta-geniş | Süre: 90 sn |
| 5 | Tier 6'ya ulaş | Orta | Süre: 90 sn |
| 6 | Tier 6'ya ulaş | Orta | Süre: 75 sn |
| 7 | Tier 7'ye ulaş | Dar | Süre: 75 sn |
| 8 | Tier 7'ye ulaş | Dar | Süre: 60 sn |
| 9 | Tier 8'e ulaş | Dar | Süre: 60 sn |
| 10 | Tier 8 + skor ≥ 5000 | En dar | Süre: 90 sn |

Level datası bir Godot Resource (`.tres`) olarak tanımlanır — kod değişmeden
yeni level eklenebilmeli (data-driven, owner'ın istediği gibi).

> **Kap genişliği px karşılıkları (M2'de ölçümle belirlendi):**
> Geniş 600 · Orta-geniş 540 · Orta 480 · Dar 420 · En dar 370.
> Oynanabilir yükseklik (taban–taşma çizgisi) tüm level'larda 400 px
> (M1'de ölçülerek kilitlendi); GAME_DESIGN yüksekliği level başına
> değiştirmiyor. En dar kap tier 8'in 264 px çapına 106 px pay bırakıyor.

## 4. Sonsuz mod

Level 10 tamamlanınca açılır. Sabit geniş kap, hamle/süre limiti yok. Sadece
skor ve kişisel rekor (local save, bulut yok). Bu, asıl "bir tane daha"
döngüsünün yaşadığı yer.

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
> **L10 istisnası:** bitirme koşulu (tier 8 + skor ≥5000) zaten p85 eşiğinin
> (4990) üstünde olduğu için L10'u tamamlamak her zaman 3★ verir. Bu kasıtlı —
> L10 oyunun finali, bitirmek başlı başına üst düzey başarı sayılıyor. Formüle
> istisna eklenmedi.
>
> Eşikler `TierConfig.SCORE_P50` / `SCORE_P85` dizilerinde sabit duruyor —
> percentile kapalı formülle çıkmadığı için koddan hesaplanamıyor. **Merge puan
> tablosu değişirse script tekrar çalıştırılıp bu diziler güncellenmeli.**

1. Hedefe ulaşıldı/ulaşılamadı ekranı
2. 1-3 yıldız, TEK TEK gecikmeli reveal (her biri ~400ms arayla, "pat" sesiyle)
3. Sandık açılış animasyonu (aşağıya bakın)
4. Başarısız olunsa bile küçük bir teselli ödülü + hemen "tekrar dene" butonu

### 5.2 Sandık sistemi
- Her level tamamlanışında 1 sandık
- Ayrıca her 75 merge işleminde bir "bonus sandık" (level'dan bağımsız —
  oyuncuyu sürekli oynamaya bağlar)
- Rarity oranları (KİLİTLİ, owner onaylı):
  - Common: %60
  - Rare: %25
  - Epic: %12
  - Legendary: %3
- Sandık içeriği: kozmetik dumpling skin'i VEYA "Hamur" (soft currency).
  Duplicate skin çıkarsa otomatik Hamur'a çevrilir (dedupe).
- Duplicate→Hamur oranları (10/25/60/150) ve teselli ödülü (5 Hamur)
  **GEÇİCİ** — v1.1 shop ekonomisi tasarlanınca gerçek değerlere göre
  revize edilecek.
- Hamur v1'de harcanacak bir yer YOK (shop v1.1'de) — şimdilik sadece
  toplanan/gösterilen bir sayaç. Bunu şimdiden fazla şişirmiyoruz.

### 5.3 Koleksiyon albümü
- Basit bir grid ekranı: kaç skin'den kaçı açıldı. Toplam skin sayısı:
  **20 (kilitlendi)**
- Açılmamış skin'ler silüet olarak görünür

### 5.4 Günlük döngü
- Günlük giriş ödülü (küçük, sabit) + ardışık gün sayacı (streak)
- Ödül miktarı: **15 Hamur** — §5.2'deki oranlarla aynı gerekçeyle GEÇİCİ
- Seri kırılırsa sayaç sıfırlanır — bu v1.1 reklam/monetizasyon kapısını
  açar ama v1'de sadece görüntülenir, işlevsel bir ödeme yok

### 5.5 Level haritası
- Level'lar bir yol üzerinde sıralı düğümler; kilitli level bulanık/gri,
  açılınca kısa bir "unlock" animasyonu

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

## 7. UI / HUD
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
