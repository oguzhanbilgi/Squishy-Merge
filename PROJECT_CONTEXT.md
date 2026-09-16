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
- ~~Haptic feedback (v1.1'e bırakıldı)~~ → **owner kararıyla M8.5-15'te
  v1'e alındı** (yerleşik `Input.vibrate_handheld`, Ayarlar'da anahtar;
  native haptik plugin hâlâ non-goal)
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
  - `M8.5-09` ✅ tipografi ve görsel bütünlük pası: Baloo 2 (başlık/CTA)
    + Nunito (gövde/veri), OFL 1.1, resmi Google Fonts statik TTF'leri.
    Merkezi rol sistemi (`ui_theme.tres` type variation'ları +
    `scripts/ui/ui_type.gd`), tema proje geneli varsayılan oldu. Fontlarda
    olmayan Unicode işaretler (★☆ ✓ ●○ ve mağazada unutulmuş güç
    işaretleri) mevcut asset/metinle değiştirildi. **Mekanik, ekonomi,
    fizik ve reklam kuralları DEĞİŞMEDİ.** Ayrıntı: PROJECT_STATUS §4.12.
  - `M8.5-10` ✅ production UI kabuğu: tek tasarım sistemi
    (`ui_palette.gd` + `ui_theme.tres` StyleBoxFlat katmanları, candy-night
    zemin), commercial home (hero + cipler + büyük OYNA), ikonlu alt sekme
    çubuğu, kart tabanlı mağaza, albüm hissi veren koleksiyon, harita
    başlık/düğüm/cip pası, **Ayarlar** (gerçek ses efekti anahtarı,
    gizlilik, sürüm), mikro-etkileşimler (basış/pop/pencere/sekme geçişi),
    Android geri tuşu. Free Casual GUI paketinden yalnız 14 beyaz ikon
    alındı; butonlar/paneller reddedildi. **Gameplay, ekonomi, fizik,
    reklam kuralları DEĞİŞMEDİ.** Skin art hâlâ placeholder. Ayrıntı:
    PROJECT_STATUS §4.13.
  - `M8.5-11` ✅ dumpling teması + game feel: "fizik değiyor, sprite
    değmiyor" boşluğu ölçüldü (kök sebep: 1.3–1.4 en/boy sprite'ların
    geometrik-ortalama ölçeği dikeyde çapın %70–79'unu dolduruyordu;
    padding değil) ve **yalnızca görsel** tier başına scale/offset
    kalibrasyonuyla kapatıldı (yan yana −2 px, taban +1 px). **Collider,
    yarıçap, fizik, level, bag DEĞİŞMEDİ** — rig metrikleri before/after
    birebir. Düşüş gerilmesi, alt kenardan iniş squash + toz, merge
    çekim/parlama/açılış, "+N", tier 8 parıltısı, combo ısınması, tier ≤ 3
    sarsıntısız kamera, pembe rim-glow tehlike, hedef kutlaması. Kamera
    sarsıntısı global RNG'den ayrıldı (§7 #14 kapandı). Ayrıntı:
    PROJECT_STATUS §4.14.
  - `M8.5-12` ✅ level haritası patika yerleşimi: düz 5×2 grid kalktı, on
    düğüm harita art'ındaki yolu takip ediyor (aşağıdan yukarı zig-zag),
    programatik candy patika (tamamlanmış sıcak / gelecek soluk), dört
    düğüm durumu (kilitli / açık / sıradaki altın hale / tamamlanmış
    yıldızlı), açılış animasyonu (~0.7 s), Sonsuz Mod kalede altın kapı.
    **Level verisi, hedefler, yıldızlar, unlock kuralı DEĞİŞMEDİ.**
    Ayrıntı: PROJECT_STATUS §4.15.
  - `M8.5-13` ✅ skin sistemi temeli + koleksiyon vitrini: `SkinEntry`
    view model (owned/equipped/locked/price tek kaynak), `SaveManager`
    `skin_granted`/`skin_equipped` sinyalleri, `SkinData.preview_texture`
    (sanat için hazır kanca), önizleme artık gameplay materyaliyle gerçek
    dumpling (renkli daire placeholder'ı kalktı), koleksiyonda vitrin
    (büyük önizleme + Tak / Mağazaya Git), rarity parıltılı kartlar,
    kilitli kartta fiyat, mağazada "Sahipsin · Takılı". **Ekonomi, kayıt
    formatı, sandık, gameplay DEĞİŞMEDİ.** Tint verisi hâlâ placeholder ve
    önizlemede skinler birbirinden ayırt edilmiyor — owner kararı
    (SKIN_ART_AUDIT). Ayrıntı: PROJECT_STATUS §4.16.
  - `M8.5-14` ✅ final skin sanatı + production gameplay render: owner'ın
    20 önizleme PNG'si koleksiyon/vitrin/mağazaya bağlandı (512 px import,
    mipmap); gameplay'de tier sprite'ı korunup yalnız hamur gövdesi
    boyanıyor (8 üretilmiş gövde maskesi + `skin_body.gdshader`: luminans
    tabanlı recolor, 11 deterministik desen ailesi, gloss/pearl/sparkle,
    Legendary aura). 20 render profili `.tres` verisinde
    (`tools/make_skin_resources.py`). Eski hue-shift + `tint` silindi.
    QA: `tools/skin_gallery.gd`, `tools/skin_test.gd` 25/25. **Fizik,
    ekonomi, kayıt, id'ler DEĞİŞMEDİ.** Ayrıntı: PROJECT_STATUS §4.17,
    SKIN_ART_AUDIT.md.
  - `M8.5-15` ✅ final SFX + titreşim + ses game-feel: merkezi
    `AudioManager` olay tablosu (36 olay, gain/pitch/jitter/soğuma/kanal
    tavanı/öncelik/katman), 12 kanal + öncelikli kanal çalma (CRITICAL
    kesilmez), yerel ses RNG'si (global RNG'ye dokunmuyor — testle), SFX
    bus'ında HardLimiter, evrensel UI dokunuş ailesi, bırakma/iniş/merge
    gövde/tier 8/dört güç/ödül rarity'leri/pencereler için olaylar,
    `Haptics` statik servisi (LIGHT/MEDIUM/STRONG/SPECIAL, 70 ms spam
    penceresi, editor'de güvenli), Ayarlar → **Titreşim** anahtarı
    (kayıtta `haptics_enabled`), `tools/audio_test.gd` 45/45,
    `tools/audio_qa.tscn` dev sahnesi, `tools/audio_probe.gd` tepe ölçümü.
    **Ses SİSTEMİ production-ready; ÖRNEKLER DEĞİL:** 5 Kenney CC0 + 22
    sentez (`tools/make_sfx.gd`) GEÇİCİ, kulakla doğrulanmadı — şartname
    `docs/AUDIO_ASSET_REQUIREMENTS.md`. Android titreşimi cihazda
    doğrulanmadı (M9). **Fizik, ekonomi, skin, harita, kayıt semantiği
    DEĞİŞMEDİ** (yalnız `haptics_enabled` alanı eklendi). Ayrıntı:
    `docs/AUDIO_AUDIT.md`, PROJECT_STATUS §4.18.
  - `M8.5-16` ✅ ertelenmiş merge / round bitişi yarışı: aynı fizik
    adımında istenen merge (`_resolve_merge` call_deferred) round kesin
    bittikten ve `main._on_round_finished` merge_count'u örnekledikten
    SONRA çözülebiliyordu (kayıt ile GameState 1 farklı; revive_test
    aralıklı 102/103) — skor/yeni parça/efekt de üretiyordu. Düzeltme:
    `_resolve_merge` `_is_finished` iken çıkıyor; fail-pending (devam
    teklifi) bitiş DEĞİL, o yoldaki merge'ler aynen çözülüyor. revive_test
    +17 deterministik yarış kontrolü (**120/120**, 20 ardışık koşu).
    **Fizik, skor, ekonomi, kayıt formatı DEĞİŞMEDİ.**
  - `M8.5-17` ✅ skin render'ında tier kimliği: M8.5-14 shader'ı gövde
    rengini tamamen skin'den alıyordu (sprite yalnız luminans veriyordu)
    → skin takılıyken 8 tier tek renge dönüyordu (turuncu skin = turuncu
    kap). Düzeltme: **skin tier'ı değiştirir, yerine geçmez** — tier'ın
    kendi rengi çapa, skin `tint_strength` kadar karışır (Common 0.30 /
    Rare 0.35 / Epic 0.40 / Legendary 0.50; Gökkuşağı 0.40), ton kayması
    ≤ ~32°, uzak tonlarda ton çekimi söner (mavi tier altın skinde mavi
    kalır), doygunluk kısmen tier'a geri çekilir; desen/gloss/pearl/
    sparkle/aura skin kimliğini taşır. Gökkuşağı = tier tonu etrafında ince
    film salınımı (tek gradyan değil). **Sade = taban: materyal takılmaz,
    varsayılanla birebir.** `tools/skin_gallery.gd` 8 tier yan yana
    sayfaları + `tools/skin_tier_contrast.py` (ΔE ölçümü, 0 uyarı),
    skin_test 30/30. **İlk gerçek cihaz kapısı:** debug APK Samsung A36'ya
    kuruldu, Sade/Havuçlu/Ispanak/Altın/Gökkuşağı yığınları cihazda
    doğrulandı (build/qa_m8.5-17/). Bunun için
    `rendering/textures/vram_compression/import_etc2_astc=true` açıldı
    (Godot bu ayar kapalıyken Android export'u mesajsız reddediyor) ve
    yerel (gitignore'lu) `export_presets.cfg` yazıldı (paket adı geçici
    `com.example.squishymerge`, arm64, VIBRATE açık). **Fizik, ekonomi,
    kayıt, önizleme sanatı DEĞİŞMEDİ.** Ayrıntı: SKIN_ART_AUDIT §2.2,
    PROJECT_STATUS §4.19.
  - `M8.6-01` ✅ production UI temeli (Visual Cohesion Rebuild'in ilk
    işi): tek token kaynağı `scripts/ui/ui_tokens.gd`, LayerLab yapısal
    katmanı spike'tan **seçici** promote (`assets/visual/ui/core/`, 56 beyaz
    9-slice + 32 picto; renkli/RPG/brawler REJECT), `tools/make_ui_theme.gd`
    → `ui_theme.tres`'e 55 variation (M8.5 rolleri ve tipografi aynen),
    `UiKit` bileşen fabrikası, `tools/ui_system_gallery.tscn` (dev-only, 5
    sayfa), `tools/ui_foundation_test` 126/126, masaüstü 4 boyut + A36
    cihaz çekimleri. **Production ekranlar henüz sisteme geçmedi** — sırada
    M8.6-02 Gameplay Shell. Kaynak doküman: `docs/UI_VISUAL_SYSTEM.md`.
  - `M8.6-02` ✅ production gameplay shell: `GameplayLayout` bölge
    sözleşmesi (HUD 178 / BOARD esnek / STRIP 64 / BANNER seam v1'de 0) +
    fizik referans penceresinin Camera2D ile BOARD'a sığdırılması (zoom ≤
    1.2, **FLOOR_Y/fizik/kap ölçüleri DEĞİŞMEDİ**, girdi `screen_to_world`);
    tek parça HUD (`GameplayHud`: skor plakası, taç-level rozeti + hedef
    tier dokusu + nane ilerleme, krem Sıradaki plakası, ayarlar → board
    donar), `UiKit.power_slot` (bevel + owner güç sanatı + altın stok
    rozeti + cyan silahlı parıltı + stok 0'da nane "+"), iki sol + iki sağ
    slot, evrim şeridi (8 gerçek tier dokusu, ulaşılan/hedef işaretli),
    kap kabuğu (dış gölge, iç derinlik, 30 px görsel duvar, taban dudağı),
    danger rim aynı mekanikle kabuğa entegre; güç slotları `btn_circle`
    madalyon, evrim şeridi erik raf, sakin danger eşiği ince hat, "Taştı!"
    pembe candy plaka; cihaz üst güvenli payı (punch-hole) HUD'u aşağı
    iter. Eski serbest metin HUD /
    candy pill güç butonları gameplay'den kalktı (`CandyButton` diğer
    ekranlarda duruyor). `tools/gameplay_shell_test` 146/146,
    `tools/shell_shots` 10 durum × 4 boyut (build/qa_m8.6-02/). §7 #9
    (uzun ekran ölü alan / A36 örtüşmesi) kapandı. Samsung A36 cihaz
    kapısı geçti (build/qa_m8.6-02/device, logcat temiz). **Mekanik,
    ekonomi, fizik, skin render, ses DEĞİŞMEDİ.** Ayrıntı: UI_VISUAL_SYSTEM §13.
  - `M8.6-03` ✗ (dal `task/m8.6-03-home`, 7fbbb7b — **birleştirilmedi**):
    kart yığını + oyun-tarzı sekme çubuğu; owner "cilalı uygulama/dashboard,
    oyun hub'ı değil" dedi. Test/çekim altyapısı ve `hero_cta`/`card_button`/
    `safe_top` parçaları 03B'ye taşındı; görsel yön değişti.
  - `M8.6-03B` 🔶 production Home **hub** (PRE-DEVICE VISUAL REVIEW, dal
    `task/021-home-hub-redesign`): rakip referansın hub mimarisi, Squishy
    Merge'in kendi dünyası/karakterleri — **Home'da harita YOK**, sekme
    çubuğu Home'da GİZLİ. Üst: glossy ayarlar + seri pill'i · Hamur pill'i +
    nane "+". Logo. Sol/sağ yüzen candy madalyonlar (`HomeFeatureButton`,
    tek bileşen): Günlük (bildirim noktası → günlük penceresi; alınmışsa
    durum), Koleksiyon (takılı skin + 6/20 rozet + nane halka), Mağaza,
    Bonus sandık (owner sandığı + 49/75 rozet + altın halka → kural/ilerleme
    penceresi → OYNA). Büyük yüksek çözünürlüklü maskot (`hero_mascot.png`
    türevi) + hale/sahne ışığı/yer gölgesi + iki tier dumpling + pırıltılar;
    zemin Home'da daha az karartılır. Alt: kompakt level plakası (taç rozeti,
    Level N / 8/30 ★; sonsuzda rekor) + tek cyan OYNA → Harita. Uzun ekran:
    gök payı / sütun aralığı / maskot büyür. Para/reklam ürünü YOK (billing
    yok). `tools/home_ui_test` 129/129, ui_foundation 142/142, ui_smoke 72,
    shell 146; `tools/home_shots` 10 durum × 4 boyut (build/qa_m8.6-03b/).
    **Ekonomi, ilerleme, günlük ödül kuralı, kayıt şeması, gameplay HUD v5
    DEĞİŞMEDİ.** Cihaz kapısı (A36) owner görsel onayından sonra. Ayrıntı:
    UI_VISUAL_SYSTEM §14.
- **Sırada: M8.6 — Visual Cohesion Rebuild** (ekranlar `UiKit`/`UiTokens`
  sistemine geçirilecek: ~~gameplay shell~~ ✅ → ~~home~~ 🔶 (owner görsel
  onayı + cihaz kapısı bekliyor) → shop → collection →
  map → result/reward/revive), ardından **M9 — Android export.** Ortam hazır (export template'leri, SDK,
  NDK, JDK 17, debug keystore mevcut, ETC2/ASTC import açık, iş
  makinesinde debug `export_presets.cfg` var — gitignore'lu, her makinede
  ayrı); eksik olan kalıcı paket adı ve release/upload keystore (uzun
  ekran HUD düzeni M8.6-02'de çözüldü). Paralel owner işi: `tools/audio_qa.tscn` ile sesleri dinleyip
  final örnekleri sağlamak.
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
  içinde (gövde maskesi + `assets/visual/skins/skin_body.gdshader`); skin
  verisi `resources/skins/*.tres` = `tools/make_skin_resources.py` çıktısı,
  gövde maskeleri `tools/make_skin_masks.py` çıktısı — elle düzenleme yok
- **Skin tier'ı değiştirir, yerine geçmez (M8.5-17):** tier gövde rengi
  çapa, skin `tint_strength` ≤ rarity tavanı (0.30/0.35/0.40/0.50); her
  skinde 8 tier ayırt edilebilir kalmalı (`tools/skin_tier_contrast.py`
  0 uyarı). Sade = taban, materyal yok
- **Büyük iş akışı kapısı (M8.5-17'den itibaren):** gameplay/render/skin/
  UI/ses/güç/Android işleri → otomatik testler → masaüstü QA → Android
  debug APK → USB'deki telefona kur → başlat → cihaz QA → rapor → commit.
  Yalnız doküman/ufak test temizliği bundan muaf

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
- **Tipografi TAMAM (M8.5-09), production UI kabuğu TAMAM (M8.5-10):**
  bütün production ekranlar aynı font ailesinde ve aynı tasarım
  sisteminde (zemin/yüzey/kart/CTA/seçili/pasif katmanları, candy modal,
  ikonlu sekme çubuğu, ayarlar). Harita patikası M8.5-12'de geldi. Kalan
  görsel borç: skin renkleri (aşağıda).
- **Unity Asset Store paketi repoda DEĞİL:** `_visual_source/
  unity_free_casual_gui/` owner'ın makinesinde; EULA ham paketin yeniden
  dağıtımına izin vermeyebilir. Türetilmiş 14 ikon `assets/visual/ui/icons/`
  altında repoda. Owner paketi de eklemek isterse karar onun.
- **Oyun ekranı asset'leri TAMAM (M8.5-08):** dört güç ikonu, buton
  durumları, gece zemini, bambu duvar/taban ve güç efektleri bağlandı.
  Oyun ekranında görünür placeholder kalmadı.
- **Ses örnekleri GEÇİCİ (M8.5-15):** sistem hazır, 22 sentez + 5 Kenney
  örnek kulakla doğrulanmadı; final örnekler owner'dan bekleniyor
  (`docs/AUDIO_ASSET_REQUIREMENTS.md`). Titreşim Android'de cihazda
  doğrulanmadı.
- **Skin sanatı TAMAM (M8.5-14):** 20 final önizleme bağlı, gameplay
  render production. Kalan tek sanat borcu opsiyonel: Epic/Legendary
  önizlemelerindeki özel aksesuar/ifadeler gameplay tier'larında yok
  (tier başına overlay art gerekir, bkz. SKIN_ART_AUDIT §4). Android'de
  shader/aura performans ölçümü M9'da.

## Next action
M9: Android export preset'i kur (`exclude_filter` → `tools/*`,
`_visual_source/*`), adaptive icon'ları bağla, `config/icon`'u değiştir,
release keystore oluştur, debug APK'yı cihazda doğrula.
Ayrıntılı liste: PROJECT_STATUS.md §8.
