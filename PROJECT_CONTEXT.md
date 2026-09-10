# PROJECT_CONTEXT.md — Squishy Merge

> Bu dosya **kısa ve güncel durumu** tutar. Tarihçe, kararların gerekçeleri,
> asset envanteri ve ayrıntılı kalan iş listesi için:
> **[PROJECT_STATUS.md](PROJECT_STATUS.md)** — bu dosya oraya dönüşmesin.

## Product
Fizik tabanlı (Suika Game / watermelon-game tarzı) squishy dumpling
birleştirme mobil oyunu. Üstten kaba düşen dumpling'ler aynı tier'da
çarpışınca birleşip bir üst tier'a evriliyor. 10 sabit level + level 10
sonrası açılan sonsuz mod. Tema: sevimli/kawaii squishy dumpling
karakterleri, ASMR/rahatlatıcı his.

## User
Casual mobil oyun oynayan geniş kitle; özellikle merge/idle/ASMR-cozy oyun
sevenler. Kısa oturumlarla (30–90 sn round) oynamayı tercih eden kullanıcı.

## Business model
- v1: reklamsız, IAP yok. Amaç: organik/ASO testi, gerçek retention verisi
  toplamak.
- **Owner kararı (M8.5) bu tabloyu güncelledi:** ödüllü reklam ve gerçek para
  **Güç Paketi** artık PLANLANIYOR ama **HENÜZ KURULMADI** — AdMob SDK yok,
  Play Billing yok, fiyat/product ID yok. Skinler hiçbir zaman gerçek parayla
  satılmayacak. Bkz. GAME_DESIGN §5.7.
- v1'de **oyun içi mağaza VAR**: Hamur ile kozmetik skin satın alınıyor.
  Gerçek para geçmiyor — soft-currency sink'i, IAP değil. Bkz. GAME_DESIGN §5.6.
- v1.1+ (şimdi YAPILMIYOR): ödüllü reklam, muhtemel kozmetik IAP.

## Success metric
v1 için "başarı" = Play Console kapalı test track'inde canlı, crash'siz, tam
oynanabilir bir build. Ticari/growth kararları v1.1'de gerçek veriyle
alınacak — şimdi tahmin/vaat yok.

## Non-goals (v1 — bilinçli olarak YAPILMIYOR)
- Çoklu kavanoz/tema seçeneği (tek sabit tema)
- IAP, reklam, herhangi bir ödeme entegrasyonu **kurulumu** (tasarımı
  yapıldı, kod YOK — GAME_DESIGN §5.7.3 / §5.7.4 / §11)
- Haptic feedback (v1.1'e bırakıldı)
- Leaderboard, bulut kayıt, hesap sistemi, backend/sunucu
- Otomatik test framework'ü (GUT vb.) — bu ölçekte disproportionate
  overhead; manuel playtest checklist + headless bot kullanılıyor
- iOS build

## Stack
- Godot **4.6.3** (stable), GDScript — **başka sürümle açma**, bkz. CLAUDE.md
- Android export → Google Play (Play App Signing, AAB format)
- Yerel repo: makineye göre değişir (ev: `C:\dev\squishy-merge`, iş:
  `D:\dev\squishy-merge`) — sabit yol varsayma
- GitHub: https://github.com/oguzhanbilgi/Squishy-Merge

## Current state
- **M0–M8 tamamlandı.** Oyun uçtan uca oynanabilir: 10 level + sonsuz mod,
  sandık/koleksiyon/mağaza, günlük ödül, 4 sekmeli navigasyon, owner'ın
  görsel asset'leri entegre.
- **Şimdi: M8.5 — release/product stabilization.**
  - `M8.5-01` ✅ sandık ödül modeli %30 skin / %70 Hamur olarak kilitlendi,
    simulator production ile eşitlendi.
  - `M8.5-02` ✅ skin equip altyapısı: kazan → koleksiyonda seç → kaydet →
    oyunda uygulan döngüsü çalışıyor. **functional equip complete / final
    skin art pending** — skin renkleri hâlâ placeholder, bkz.
    `SKIN_ART_AUDIT.md`.
  - `M8.5-03` ✅ dört tüketilebilir güç (Bomba / Büyütücü / Sarsıntı /
    Temizleyici), kalıcı envanter, hedefleme modu, stok-0 refill kancası.
    **functional power-ups complete / final power-up art pending** —
    ikonlar geçici, bkz. GAME_DESIGN §10.
  - `M8.5-04` ✅ iki aşamalı devam (revive) altyapısı: taşma artık round'u
    doğrudan bitirmiyor, round başına 2 devam hakkı sunuluyor
    (FAIL → Devam #1 → FAIL → Devam #2 → FAIL → kesin kayıp). Board
    donduruluyor, devam edilince taşma bandı temizlenip 1.5 sn koruma
    açılıyor. **revive foundation complete / real rewarded ad pending** —
    AdMob YOK, buton yalnızca sinyal yayıyor, bkz. GAME_DESIGN §11.
  - `M8.5-05` ✅ güç mağazası: dört güç Hamur ile alınabiliyor, fiyatlar
    simülasyonla seçildi (Sarsıntı 100 / Bomba 120 / Temizleyici 160 /
    Büyütücü 180). Yoğun oyuncunun 90 günlük Hamur fazlası 50.025 → 335.
    Satın almalar tek transaction. **Hamur mağazası tamam / rewarded refill
    ve IAP pending** — bkz. GAME_DESIGN §5.7.
  - `M8.5-06` ✅ stok 0 refill akışı: oyun içi refill penceresi (reklam / Hamur),
    board refill sırasında donuyor, günlük ödüllü kota **1/gün (dört gücün
    toplamı)** olarak kilitlendi ve token'lı callback güvenliği eklendi.
    **UX + kota hazır / AdMob SDK pending** — bkz. GAME_DESIGN §5.7.3.
  - `M8.5-07` ✅ oyun ekranı görsel pası: owner'ın kullanılmayan candy
    zemini oyun arkasına (karartılmış) ve candy paneli iki oyun içi
    pencereye bağlandı, kap duvarları pastel oldu, dört gücün efektleri
    (kilitlenme halkası / yükselme parıltısı / toz / süpürme) ayrıştırıldı.
    Ayrıntı: PROJECT_STATUS §4.10.
  - `M8.5-08` ✅ final asset entegrasyonu: owner'ın ikinci ChatGPT partisi
    bağlandı — dört gücün gerçek ikonu, candy buton durumları (normal /
    seçili / pasif), gerçek gece zemini, bambu duvar + taban, kanatlı kalp
    pencere tepeliği ve dört gücün efekt asset'leri (uçan bomba, patlama,
    yükselme sütunu, toz, yıldız girdabı). Geçici metin işaretleri
    (`PowerUp.GLYPHS`) UI'dan kalktı. **Mekanik, ekonomi, fizik ve reklam
    kuralları DEĞİŞMEDİ.** Ayrıntı: PROJECT_STATUS §4.11.
- **Sırada: M9 — Android export.** Ortam hazır (export template'leri, SDK,
  NDK, JDK 17, debug keystore mevcut); eksik olan `export_presets.cfg` ve
  release/upload keystore.
- **Sonra: M10 — Play Store submission / kapalı test.**

## Quality gates
- Her milestone sonunda GAME_DESIGN §9 manuel playtest checklist'i geçmeli
- Export alınan APK/AAB gerçek cihaz veya emulator'de crash vermeden açılmalı
- `git add .` kullanılmayacak — dosyalar açıkça isimlendirilerek stage edilecek
- Force push yok, local iş üzerine yazılmayacak

## Project-specific invariants
- Tier sayısı sabit: 8 · Level sayısı v1: 10 + sonsuz mod
- Sandık **rarity** oranları: Common %60 / Rare %25 / Epic %12 / Legendary %3
- Sandık **ödül tipi** oranı: %30 skin / %70 Hamur *(ayrı bir rule — rarity
  ile karıştırma, bkz. GAME_DESIGN §5.2)*
- Shop fiyatları — skin: 50 / 150 / 400 / 900
- Shop fiyatları — güç: Sarsıntı 100 / Bomba 120 / Temizleyici 160 /
  Büyütücü 180 (`power_up_economy.gd`; simülatördeki `POWER_PRICES` ile
  aynı tutulmalı)
- Satın alma invariant'ı: para düşmesi + ödül verilmesi TEK transaction
- Ödüllü güç kotası: **1/gün, dört gücün toplamı**, yalnızca reward-earned
  tüketir (`rewarded_policy.gd`). Revive hakları bundan BAĞIMSIZ
- Güç başlangıç stoğu: **kayıt başına 1'er adet, tek seferlik**. Stok
  yalnızca efekt gerçekleşince düşer; güçle yapılan silmeler skor/merge
  üretmez (GAME_DESIGN §10)
- Görsel asset üretimi owner'da — Claude Code final art üretmez.
  Owner kaynakları `_visual_source/` altında ARŞİV; runtime yalnızca
  `assets/visual/` altındaki türevleri okur. Türetme betiği:
  `tools/make_gameplay_art.py`
- Takılı skin kayıtta `equipped_skin` alanında; **boş string = varsayılan
  görünüm**. Skin'in nasıl çizildiği yalnızca `scripts/game/skin_visual.gd`
  içinde (değiştirilebilir katman)

## Repo notes
- `_visual_source/` **repoda takip ediliyor** (owner kararı): owner'ın
  ChatGPT ile ürettiği ve başka yedeği olmayan orijinaller burada.
  Godot'un ürettiği `.import` dosyaları hariç tutuluyor.
- `_audio_source/` gitignore'lu — Kenney'den yeniden indirilebilir.
- `export_presets.cfg` gitignore'lu; her makinede ayrı kurulur.

## Current blockers
- **Google Play Developer hesabı** henüz açılmadı / kimlik doğrulaması
  bekliyor (owner tarafından paralel yürütülmeli — bu repo işiyle ilgisiz).
  M10'u bloke ediyor, M9'u etmiyor.
- **Geç oyun Hamur enflasyonu ÇÖZÜLDÜ (M8.5-05):** güç mağazası ikinci ve
  tekrarlanabilir sink oldu. Skin fiyatlarına, sandık oranlarına ve Hamur
  gelir kaynaklarına dokunulmadı — hâlâ owner kararına açıklar.
- **Güç ekonomisi kısmen bağlandı (M8.5-05/06):** güçler Hamur ile satın
  alınabiliyor (100/120/160/180) ve stok 0 refill penceresi çalışıyor.
  Ödüllü kota **1/gün** olarak kilitli ama **AdMob SDK yok** — reklam CTA'sı
  sağlayıcı bağlanana kadar pasif. Gerçek para Güç Paketi hâlâ YOK.
- **Ödüllü reklam sağlayıcısı bağlı değil:** devam (revive) akışı uçtan uca
  çalışıyor ama `rewarded_revive_requested` sinyali boşta. AdMob SDK kurulumu
  ve `Main.set_rewarded_provider()` bağlanması ayrı bir iş. Sahte reklam ve
  bedava devam bilinçli olarak YOK — bkz. GAME_DESIGN §11.6.
- **Oyun ekranı asset'leri TAMAM (M8.5-08):** dört güç ikonu, buton
  durumları, gece zemini, bambu duvar/taban ve güç efektleri bağlandı.
  Oyun ekranında görünür placeholder kalmadı. Geriye kalan tek görsel
  borç skin renkleri (aşağıda) — o oyun ekranının değil koleksiyonun işi.
- **Skin sanatı owner kararı bekliyor:** 20 skin'in renkleri prosedürel
  üretilmiş ve isimleriyle uyuşmuyor (18/20 uyumsuz). Equip sistemi hazır,
  yalnızca veri düzeltmesi gerekiyor. Seçenekler: `SKIN_ART_AUDIT.md`.

## Next action
M9: Android export preset'i kur (`exclude_filter` → `tools/*`,
`_visual_source/*`), adaptive icon'ları bağla, `config/icon`'u değiştir,
release keystore oluştur, debug APK'yı cihazda doğrula.
Ayrıntılı liste: PROJECT_STATUS.md §8.
